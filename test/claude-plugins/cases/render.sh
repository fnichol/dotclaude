#!/usr/bin/env bash
# render: settings.json from settings.base.json + the local overlay
# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

echo "# render"

remove_base() { rm "$BASE"; }
remove_overlay() { rm "$OVERLAY"; }
enable_p2_in_overlay() { edit_json "$OVERLAY" '.enabledPlugins["p2@mkt-a"] = true'; }

snapshot_case render-clean noop render
snapshot_case render-no-base remove_base render
snapshot_case render-no-overlay remove_overlay render
snapshot_case render-live-drift drift_live_settings render
snapshot_case render-overlay-merge enable_p2_in_overlay render

begin missing-base
remove_base
run render
assert_eq "missing base exits 1" "$EC" 1
assert_contains "missing base is reported" "$OUTPUT" "Base settings file not found"

begin missing-overlay
remove_overlay
run render
assert_eq "exits 0" "$EC" 0
assert_eq "creates an empty overlay stub" "$(jq -c . "$OVERLAY")" \
  '{"enabledPlugins":{},"extraKnownMarketplaces":{}}'

begin live-drift
drift_live_settings
run render
assert_contains "warns about uncaptured live changes, naming the keys" "$OUTPUT" \
  "settings has changes since the last render in: enabledPlugins"
assert_not_contains "without a redundant 'Warning:' prefix" "$OUTPUT" "Warning:"
assert_eq "overwrites live changes with the render" \
  "$(jq '.enabledPlugins["p2@mkt-a"]' "$SETTINGS")" false

begin overlay-merge
enable_p2_in_overlay
run render
assert_eq "overlay values override base" "$(jq '.enabledPlugins["p2@mkt-a"]' "$SETTINGS")" true
assert_eq "base-only values are kept" "$(jq -r .theme "$SETTINGS")" dark
assert_same_file "records the render snapshot" "$SNAPSHOT" "$SETTINGS"

finish
