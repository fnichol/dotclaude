#!/usr/bin/env bash
# Snapshot marketplaces: Claude Code installs some marketplaces (such as
# claude-plugins-official) as snapshots with no .git, recording the commit in
# a .gcs-sha file. These cannot be pinned with git.
# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

echo "# snapshot marketplaces"

mkt_a_snapshot() { make_snapshot_marketplace mkt-a; }
mkt_a_snapshot_lock_ahead() {
  make_snapshot_marketplace mkt-a
  lock_mkt_a_ahead
}
# The snapshot has moved past the commit the lock pins it to
mkt_a_snapshot_past_lock() {
  make_snapshot_marketplace mkt-a
  upstream_commit mkt-a "a2"
  stub plugin marketplace update mkt-a
}
mkt_a_snapshot_upstream_moved() {
  make_snapshot_marketplace mkt-a
  upstream_commit mkt-a "a2"
}
fresh_machine_snapshot() {
  fresh_machine
  touch "$REMOTES/mkt-a.snapshot"
}

snapshot_case snapshot-verify mkt_a_snapshot verify
snapshot_case snapshot-install-synced mkt_a_snapshot install
snapshot_case snapshot-install-lock-ahead mkt_a_snapshot_lock_ahead install
snapshot_case snapshot-install-past-lock mkt_a_snapshot_past_lock install
snapshot_case snapshot-update mkt_a_snapshot_upstream_moved update
snapshot_case snapshot-install-fresh fresh_machine_snapshot install

begin verify
mkt_a_snapshot
run verify
assert_eq "a snapshot at its locked commit verifies" "$EC" 0
assert_contains "its commit is read from .gcs-sha" "$OUTPUT" \
  "Ok: mkt-a @ $(lock_commit "$ML" mkt-a)"

begin install-synced
mkt_a_snapshot
run install
assert_eq "exits 0" "$EC" 0
assert_eq "a synced snapshot makes no claude calls" "$CALLS" ""

begin install-lock-ahead
mkt_a_snapshot_lock_ahead
run install
assert_eq "exits 0" "$EC" 0
assert_contains "refreshes the snapshot through claude" "$CALLS" \
  "claude plugin marketplace update mkt-a"
assert_eq "the snapshot reaches the locked commit" \
  "$(cat "$CP/marketplaces/mkt-a/.gcs-sha")" "$(lock_commit "$ML" mkt-a)"
assert_contains "its local plugin is refreshed" "$CALLS" "claude plugin install p1@mkt-a"
assert_not_contains "no pinning warning" "$OUTPUT" "Cannot pin"
assert_eq "no .git is created" "$([ -e "$CP/marketplaces/mkt-a/.git" ] && echo yes || echo no)" no

begin install-past-lock
mkt_a_snapshot_past_lock
run install
assert_eq "exits 0 (pinning a snapshot is best effort)" "$EC" 0
assert_contains "warns that the snapshot cannot be pinned" "$OUTPUT" \
  "Cannot pin mkt-a to $(lock_commit "$ML" mkt-a)"
assert_contains "points at update" "$OUTPUT" \
  "Run 'claude-plugins update' to lock the current snapshot"
assert_eq "the snapshot stays where Claude Code put it" \
  "$(cat "$CP/marketplaces/mkt-a/.gcs-sha")" "$(remote_head mkt-a)"

begin update
mkt_a_snapshot_upstream_moved
run update
assert_eq "exits 0" "$EC" 0
assert_eq "the new snapshot commit is locked" "$(lock_commit "$ML" mkt-a)" "$(remote_head mkt-a)"
assert_eq "its local plugin follows it" "$(lock_commit "$PL" p1)" "$(remote_head mkt-a)"
run install
assert_eq "install afterwards makes no claude calls" "$CALLS" ""
run verify
assert_eq "verify afterwards passes" "$EC" 0

begin install-fresh
fresh_machine_snapshot
run install
assert_eq "exits 0" "$EC" 0
assert_eq "installs the snapshot at its locked commit" \
  "$(cat "$CP/marketplaces/mkt-a/.gcs-sha")" "$(lock_commit "$ML" mkt-a)"
assert_eq "installs its plugins" "$(installed_keys)" "p1@mkt-a,urlp@mkt-b"
run verify
assert_eq "verify afterwards passes" "$EC" 0

finish
