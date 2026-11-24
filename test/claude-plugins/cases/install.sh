#!/usr/bin/env bash
# install: sync lock files, then marketplaces and plugins to the lock files
# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

echo "# install"

remove_marketplaces_lock() { rm "$ML"; }
remove_plugins_lock() { rm "$PL"; }
fresh_machine_upstream_moved() {
  fresh_machine
  upstream_commit mkt-a "a2"
}
# Claude Code moved the installed (shallow) mkt-a past its locked commit
mkt_a_past_lock() {
  upstream_commit mkt-a "a2"
  stub plugin marketplace update mkt-a
}

snapshot_case install-synced noop install
snapshot_case install-fresh fresh_machine install
snapshot_case install-fresh-other-mkt fresh_machine_with_other_marketplace install
snapshot_case install-mkt-behind lock_mkt_a_ahead install
snapshot_case install-not-in-lock install_unlocked_plugin install
snapshot_case install-lock-has-removed lock_ghost_plugin install
snapshot_case install-plugin-not-installed uninstall_urlp install
snapshot_case install-no-mlock remove_marketplaces_lock install
snapshot_case install-no-plock remove_plugins_lock install
snapshot_case install-plugin-mismatch lock_wrong_urlp_commit install
snapshot_case install-fresh-upstream-moved fresh_machine_upstream_moved install
snapshot_case install-mkt-past-lock mkt_a_past_lock install

begin synced
run install
assert_eq "exits 0" "$EC" 0
assert_contains "renders settings first" "$OUTPUT" "Rendering settings"
# Regression: local plugins (no gitCommitSha) were reinstalled on every run
assert_eq "a synced machine makes no claude calls" "$CALLS" ""
assert_contains "local plugin p1 is already synced" "$OUTPUT" "Already synced: p1"

# Regression: the lock sync ran before installing and removed every lock entry
# that was not installed yet, so a new machine lost its lock entries
begin fresh-machine
fresh_machine
run install
assert_eq "exits 0" "$EC" 0
assert_eq "marketplace lock is unchanged" "$(json_keys "$ML")" "mkt-a,mkt-b"
assert_eq "plugin lock is unchanged" "$(json_keys "$PL")" "p1,urlp"
assert_eq "locked plugins are installed" "$(installed_keys)" "p1@mkt-a,urlp@mkt-b"
assert_eq "mkt-a is at its locked commit" \
  "$(local_head "$CP/marketplaces/mkt-a")" "$(lock_commit "$ML" mkt-a)"
assert_same_file "settings are rendered" "$SNAPSHOT" "$SETTINGS"

begin fresh-machine-with-other-marketplace
fresh_machine_with_other_marketplace
run install
assert_eq "exits 0" "$EC" 0
assert_eq "locked marketplaces are kept; undeclared mkt-c stays local" \
  "$(json_keys "$ML")" "mkt-a,mkt-b"
assert_eq "plugin lock is unchanged" "$(json_keys "$PL")" "p1,urlp"
assert_eq "locked plugins are installed" "$(installed_keys)" "p1@mkt-a,urlp@mkt-b"
run verify
assert_eq "verify passes afterwards" "$EC" 0

begin disabled-plugin-leaves-lock
edit_json "$BASE" '.enabledPlugins["urlp@mkt-b"] = false'
run install
assert_eq "plugin disabled in settings is removed from the lock" "$(json_keys "$PL")" "p1"
assert_eq "its marketplace stays locked while installed" "$(json_keys "$ML")" "mkt-a,mkt-b"

begin unneeded-marketplace-leaves-lock
lock_ghost_marketplace
run install
assert_eq "marketplace neither installed nor needed is removed" \
  "$(json_keys "$ML")" "mkt-a,mkt-b"

begin enabled-but-unknown-plugin
edit_json "$BASE" '.enabledPlugins["pc@mkt-c"] = true'
run install
assert_eq "exits 1" "$EC" 1
assert_contains "warns about the plugin" "$OUTPUT" \
  "Plugin pc@mkt-c is enabled in the base but neither installed nor locked"
assert_eq "plugin lock is unchanged" "$(json_keys "$PL")" "p1,urlp"

begin no-settings
rm "$SETTINGS" "$BASE"
cp "$ML" "$ROOT/ml-before"
cp "$PL" "$ROOT/pl-before"
run install
assert_eq "exits 1 without any settings" "$EC" 1
assert_same_file "marketplace lock is untouched" "$ML" "$ROOT/ml-before"
assert_same_file "plugin lock is untouched" "$PL" "$ROOT/pl-before"

begin new-local-plugin
install_unlocked_plugin
run install
assert_eq "new plugin is added to the lock" "$(json_keys "$PL")" "p1,pc,urlp"
# Regression: local plugins were locked as "unknown" and then always skipped
assert_eq "local plugin is locked at its marketplace's commit" \
  "$(lock_commit "$PL" pc)" "$(lock_commit "$ML" mkt-c)"
run install
assert_not_contains "it is not reinstalled on the next run" "$CALLS" "pc@mkt-c"

begin uninstalled-plugin
uninstall_urlp
run install
assert_eq "enabled+locked plugin stays locked" "$(json_keys "$PL")" "p1,urlp"
assert_contains "and is installed again" "$CALLS" "claude plugin install urlp@mkt-b"

begin marketplace-moved
lock_mkt_a_ahead
run install
assert_eq "exits 0" "$EC" 0
assert_eq "mkt-a moves to its new locked commit" \
  "$(local_head "$CP/marketplaces/mkt-a")" "$(remote_head mkt-a)"
assert_eq "local plugin p1 is refreshed because mkt-a moved" "$CALLS" \
  "$(printf 'claude plugin remove p1@mkt-a\nclaude plugin install p1@mkt-a')"
assert_contains "the refresh reason is shown" "$OUTPUT" "Reason: marketplace mkt-a moved"
run install
assert_eq "the next install makes no claude calls" "$CALLS" ""
assert_contains "the stale p1 lock commit is flagged" "$OUTPUT" \
  "Run 'claude-plugins update' to re-lock it"
run update
run install
assert_not_contains "after update re-locks p1, install is quiet" "$OUTPUT" \
  "differs from its marketplace"
assert_eq "and makes no claude calls" "$CALLS" ""

begin url-plugin-mismatch
lock_wrong_urlp_commit
run install
assert_contains "URL plugin at the wrong commit is reinstalled" "$CALLS" \
  "claude plugin install urlp@mkt-b"

# Regression: Claude Code clones marketplaces shallow (depth 1), so a locked
# commit behind upstream was missing and `git reset` to it failed
begin fresh-marketplace-behind-upstream
fresh_machine_upstream_moved
run install
assert_eq "exits 0" "$EC" 0
assert_not_contains "no reset failure" "$OUTPUT" "Could not reset"
assert_eq "mkt-a is pinned to its older locked commit" \
  "$(local_head "$CP/marketplaces/mkt-a")" "$(lock_commit "$ML" mkt-a)"
assert_eq "the clone stays shallow" \
  "$(git -C "$CP/marketplaces/mkt-a" rev-parse --is-shallow-repository)" true
run verify
assert_eq "verify afterwards passes" "$EC" 0

begin marketplace-past-lock
mkt_a_past_lock
run install
assert_eq "exits 0" "$EC" 0
assert_eq "mkt-a is moved back to its locked commit" \
  "$(local_head "$CP/marketplaces/mkt-a")" "$(lock_commit "$ML" mkt-a)"
assert_contains "its local plugin is refreshed" "$CALLS" "claude plugin install p1@mkt-a"

begin missing-marketplaces-lock
remove_marketplaces_lock
run install
assert_eq "exits 1" "$EC" 1
assert_contains "reports the missing lock" "$OUTPUT" "Marketplaces lock file not found"
assert_contains "says to restore it rather than run update" "$OUTPUT" \
  "It is version-controlled; restore it from your dotfiles"

finish
