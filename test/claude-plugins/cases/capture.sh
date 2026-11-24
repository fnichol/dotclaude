#!/usr/bin/env bash
# capture: route live settings.json changes into base or the local overlay
# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

echo "# capture"

remove_settings() { rm "$SETTINGS"; }
remove_snapshot() { rm "$SNAPSHOT"; }
change_live_settings() {
  edit_json "$SETTINGS" '
    .enabledPlugins["p2@mkt-a"] = true
    | .enabledPlugins["x@mkt-z"] = true
    | .extraKnownMarketplaces["mkt-c"] = {source: {source: "github", repo: "owner/mkt-c"}}'
}

snapshot_case capture-clean noop capture
snapshot_case capture-no-settings remove_settings capture
snapshot_case capture-no-snapshot remove_snapshot capture
snapshot_case capture-drift-notty change_live_settings capture

begin no-changes
run capture
assert_eq "exits 0" "$EC" 0
assert_contains "reports nothing to capture" "$OUTPUT" "no divergent changes to capture"

begin missing-snapshot
remove_snapshot
run capture
assert_eq "exits 1" "$EC" 1
assert_contains "asks for a render first" "$OUTPUT" "Run 'claude-plugins render' first"

begin no-terminal
change_live_settings
cp "$BASE" "$ROOT/base-before"
cp "$OVERLAY" "$ROOT/overlay-before"
run capture
assert_eq "exits 0" "$EC" 0
assert_same_file "without a terminal every change is skipped (base)" "$BASE" "$ROOT/base-before"
assert_same_file "without a terminal every change is skipped (overlay)" "$OVERLAY" "$ROOT/overlay-before"
assert_eq "settings are re-rendered without the live changes" \
  "$(jq '.enabledPlugins["p2@mkt-a"]' "$SETTINGS")" false

begin interactive
if ! command -v expect >/dev/null 2>&1; then
  skip "expect not found on PATH"
else
  change_live_settings
  run_tty "nope base local skip" capture
  assert_eq "exits 0" "$EC" 0
  assert_contains "re-prompts on an invalid answer" "$OUTPUT" \
    "Please answer base, local, or skip."
  assert_contains "prompt stays on the answer's line" "$OUTPUT" \
    "Capture into [base/local/skip]? base"
  assert_contains "shows JSON values on one line" "$OUTPUT" \
    'extraKnownMarketplaces[mkt-c] => {"source":{"source":"github","repo":"owner/mkt-c"}}'
  assert_eq "'base' captures into settings.base.json" \
    "$(jq '.enabledPlugins["p2@mkt-a"]' "$BASE")" true
  assert_eq "'local' captures into the overlay" \
    "$(jq '.enabledPlugins["x@mkt-z"]' "$OVERLAY")" true
  assert_eq "'skip' captures nowhere" \
    "$(jq -c '[.extraKnownMarketplaces["mkt-c"], input.extraKnownMarketplaces["mkt-c"]]' \
      "$BASE" "$OVERLAY")" "[null,null]"
  assert_eq "settings are re-rendered with the captured changes" \
    "$(jq -c '[.enabledPlugins["p2@mkt-a"], .enabledPlugins["x@mkt-z"]]' "$SETTINGS")" \
    "[true,true]"
  assert_same_file "render snapshot matches the new settings" "$SNAPSHOT" "$SETTINGS"
fi

finish
