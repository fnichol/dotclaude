#!/usr/bin/env bash
# update: move marketplaces and plugins forward and re-lock them
# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

echo "# update"

remove_mkt_b_dir() { rm -rf "$CP/marketplaces/mkt-b"; }
remove_marketplaces_lock() { rm "$ML"; }
remove_installed_plugins() { rm "$IP"; }

snapshot_case update-noop noop update
snapshot_case update-upstream-moved move_upstreams update
snapshot_case update-non-github lock_non_github_marketplace update
snapshot_case update-mkt-not-known remove_mkt_b_dir update
snapshot_case update-no-mlock remove_marketplaces_lock update
snapshot_case update-no-installed remove_installed_plugins update

begin nothing-upstream
run update
assert_eq "exits 0" "$EC" 0
assert_not_contains "no plugin is reinstalled" "$CALLS" "plugin remove"
assert_eq "marketplace commits unchanged" "$(lock_commit "$ML" mkt-a)" "$(remote_head mkt-a)"

begin upstream-moved
move_upstreams
run update
assert_eq "exits 0" "$EC" 0
assert_eq "mkt-a is locked at its new upstream commit" \
  "$(lock_commit "$ML" mkt-a)" "$(remote_head mkt-a)"
assert_eq "local plugin p1 follows mkt-a" "$(lock_commit "$PL" p1)" "$(remote_head mkt-a)"
assert_eq "URL plugin urlp is locked at its new upstream commit" \
  "$(lock_commit "$PL" urlp)" "$(remote_head urlp)"
assert_contains "p1 is refreshed because mkt-a moved" "$CALLS" \
  "claude plugin install p1@mkt-a"
assert_not_contains "disabled p2 is not touched" "$CALLS" "p2@mkt-a"
assert_not_contains "disabled p2 is not locked" "$(json_keys "$PL")" "p2"
run install
assert_eq "install afterwards makes no claude calls" "$CALLS" ""
run verify
assert_eq "verify afterwards passes" "$EC" 0

# Regression: update rebuilt the lock files from scratch and silently dropped
# entries it could not refresh
begin non-github-marketplace
lock_non_github_marketplace
run update
assert_contains "warns about the unsupported source" "$OUTPUT" \
  "Skipping weird - only 'github' source is supported"
assert_eq "its lock entry is kept" "$(json_keys "$ML")" "mkt-a,mkt-b,weird"
assert_eq "its lock entry is unchanged" "$(jq -c .weird "$ML")" \
  '{"commit":"abc","repo":"https://example.com/y.git","source":"git","updated":"x"}'

begin enabled-plugin-not-installed
uninstall_urlp
run update
assert_eq "its lock entry is kept" "$(json_keys "$PL")" "p1,urlp"
assert_contains "warns that it was kept" "$OUTPUT" \
  "Keeping urlp - enabled but not installed on this machine"

begin missing-marketplaces-lock
remove_marketplaces_lock
cp "$PL" "$ROOT/pl-before"
run update
assert_eq "exits 1" "$EC" 1
assert_same_file "plugin lock is unchanged when commits cannot be determined" \
  "$PL" "$ROOT/pl-before"

begin new-marketplace-in-lock
edit_json "$ML" \
  '.["mkt-c"] = {source: "github", repo: "owner/mkt-c", commit: "unknown", updated: "x"}'
run update
assert_contains "adds a locked marketplace that is not installed" "$CALLS" \
  "claude plugin marketplace add owner/mkt-c"
assert_eq "and locks its current commit" "$(lock_commit "$ML" mkt-c)" "$(remote_head mkt-c)"

finish
