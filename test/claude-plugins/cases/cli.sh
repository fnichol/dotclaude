#!/usr/bin/env bash
# Command-line parsing, help, and startup checks
# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

echo "# cli"

snapshot_case cli-noargs noop
snapshot_case cli-help noop help
snapshot_case cli-h noop -h
snapshot_case cli-long-help noop --help
snapshot_case cli-unknown noop bogus
snapshot_case cli-badflag noop --bogus
snapshot_case cli-dashdash noop -- verify

begin no-arguments
run
assert_eq "no arguments exits 0" "$EC" 0
assert_contains "no arguments prints usage" "$OUTPUT" "USAGE:"

begin help
run help
assert_eq "help exits 0" "$EC" 0
assert_contains "help lists subcommands" "$OUTPUT" "SUBCOMMANDS:"

begin unknown-subcommand
run bogus
assert_eq "unknown subcommand exits 1" "$EC" 1
assert_contains "unknown subcommand is named" "$OUTPUT" "unknown subcommand: bogus"
assert_contains "unknown subcommand prints usage" "$OUTPUT" "USAGE:"

begin invalid-flag
run --bogus
assert_eq "invalid flag exits 1" "$EC" 1
assert_contains "invalid flag is named" "$OUTPUT" "invalid argument --bogus"

for alias in "c:Capturing any current settings changes" \
  "h:USAGE:" \
  "i:Syncing marketplaces lock file" \
  "r:Rendering settings" \
  "u:Updating marketplaces" \
  "v:Verifying marketplaces"; do
  begin "alias-${alias%%:*}"
  run "${alias%%:*}"
  assert_contains "alias '${alias%%:*}' runs its subcommand" "$OUTPUT" "${alias#*:}"
done

echo "# startup checks"

begin no-claude-on-path
RUN_PATH="$TOOLS_BIN:/usr/bin:/bin:/usr/sbin:/sbin" run verify
assert_eq "missing claude exits 1" "$EC" 1
assert_contains "missing claude is reported" "$OUTPUT" "Required command 'claude' not found on PATH"

begin bad-known-marketplaces
echo '{"mkt-a": {"nope": 1}}' >"$KM"
run verify
assert_eq "unexpected known_marketplaces.json shape exits 1" "$EC" 1
assert_contains "names the bad file" "$OUTPUT" "Unexpected shape in $KM"
assert_contains "explains why" "$OUTPUT" "internal marketplace metadata format may have changed"

begin bad-installed-plugins
echo '{"plugins": {"p1@mkt-a": {"installPath": "x"}}}' >"$IP"
run verify
assert_eq "unexpected installed_plugins.json shape exits 1" "$EC" 1
assert_contains "names the bad file" "$OUTPUT" "Unexpected shape in $IP"
assert_contains "explains why" "$OUTPUT" "internal plugin metadata format may have changed"

finish
