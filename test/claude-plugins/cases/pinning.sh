#!/usr/bin/env bash
# What install can and cannot pin: a local plugin is always at its
# marketplace's commit, a URL plugin is installed at its source's current
# commit, and newer Claude Code records a gitCommitSha for local plugins too
# shellcheck disable=SC2016
# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

echo "# pinning"

# Newer Claude Code: local plugins record their marketplace's commit
record_local_plugin_shas() {
  touch "$REMOTES/.local-plugin-sha"
  stub plugin remove p1@mkt-a
  stub plugin install p1@mkt-a
}

# Like obsidian on a real machine: the plugin lock pins p1 to a commit its
# marketplace is not at, so no reinstall can reach it
stale_local_plugin_lock() {
  record_local_plugin_shas
  edit_json "$PL" '.p1.commit = "1111111111111111111111111111111111111111"'
}

# mkt-a was updated to the locked a2 outside of claude-plugins, but the p1 copy
# still records a1
stale_local_plugin_copy() {
  record_local_plugin_shas
  upstream_commit mkt-a "a2"
  stub plugin marketplace update mkt-a
  edit_json "$ML" --arg c "$(remote_head mkt-a)" '.["mkt-a"].commit = $c'
  edit_json "$PL" --arg c "$(remote_head mkt-a)" '.p1.commit = $c'
}

# urlp is not installed and upstream has moved past its locked commit
url_plugin_upstream_moved() {
  stub plugin remove urlp@mkt-b
  upstream_commit urlp "u2"
}

# The URL plugin's source can't be reached
url_plugin_unreachable() {
  mv "$REMOTES/urlp.git" "$REMOTES/urlp.git.offline"
}

snapshot_case pinning-stale-local-lock stale_local_plugin_lock install
snapshot_case pinning-stale-local-copy stale_local_plugin_copy install
snapshot_case pinning-url-upstream-moved url_plugin_upstream_moved install
snapshot_case pinning-url-unreachable-update url_plugin_unreachable update

# Regression: with a recorded gitCommitSha a local plugin was no longer
# recognized as following its marketplace, so install reinstalled it, printed
# the locked commit as if it had worked, and did it again on every run
begin stale-local-plugin-lock
stale_local_plugin_lock
run install
assert_eq "exits 0" "$EC" 0
assert_not_contains "a reinstall that cannot help is not attempted" "$CALLS" "p1@mkt-a"
assert_contains "the stale lock commit is flagged" "$OUTPUT" \
  "Lock commit for p1 (1111111111111111111111111111111111111111) differs from its marketplace"
run update
run install
assert_eq "after update, install is quiet" "$CALLS" ""
assert_not_contains "and has nothing to flag" "$OUTPUT" "differs from its marketplace"

begin stale-local-plugin-copy
stale_local_plugin_copy
run install
assert_eq "exits 0" "$EC" 0
assert_eq "the stale copy is refreshed from its already-updated marketplace" "$CALLS" \
  "$(printf 'claude plugin remove p1@mkt-a\nclaude plugin install p1@mkt-a')"
assert_eq "and now records the locked commit" \
  "$(jq -r '.plugins["p1@mkt-a"][0].gitCommitSha' "$IP")" "$(remote_head mkt-a)"
assert_not_contains "without warnings" "$OUTPUT" "!!!"
run install
assert_eq "the next install makes no claude calls" "$CALLS" ""

begin local-plugin-sha-marketplace-moved
record_local_plugin_shas
lock_mkt_a_ahead
edit_json "$PL" --arg c "$(remote_head mkt-a)" '.p1.commit = $c'
run install
assert_contains "a moved marketplace still refreshes its local plugin" "$CALLS" \
  "claude plugin install p1@mkt-a"
run verify
assert_eq "verify afterwards passes" "$EC" 0

begin url-plugin-upstream-moved
url_plugin_upstream_moved
run install
assert_eq "exits 0 (Claude Code cannot install a URL plugin at an old commit)" "$EC" 0
assert_contains "reports where the plugin really landed" "$OUTPUT" "@ $(remote_head urlp)"
assert_contains "warns it is not at its locked commit" "$OUTPUT" \
  "urlp installed at $(remote_head urlp), not its locked $(lock_commit "$PL" urlp)"
assert_contains "the summary does not claim everything matches" "$OUTPUT" \
  "1 could not be put at their locked versions"
assert_not_contains "and does not say it does" "$OUTPUT" \
  "All installations now match lock file versions."

begin synced-summary
run install
assert_contains "a fully pinned install says so" "$OUTPUT" \
  "All installations now match lock file versions."

# Regression: a failed remote check returned "" instead of "unknown", which
# looked like a newer version and reinstalled the plugin
begin url-plugin-unreachable
url_plugin_unreachable
cp "$PL" "$ROOT/pl-before"
run update
assert_eq "exits 0" "$EC" 0
assert_not_contains "the plugin is not reinstalled" "$CALLS" "urlp@mkt-b"
assert_contains "the failed check is reported" "$OUTPUT" \
  "Could not check https://example.invalid/urlp.git for a newer urlp"
assert_eq "its locked commit is kept" "$(lock_commit "$PL" urlp)" \
  "$(lock_commit "$ROOT/pl-before" urlp)"

finish
