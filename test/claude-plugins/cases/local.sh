#!/usr/bin/env bash
# Machine-local state: plugins and marketplaces enabled only by the local
# overlay stay out of the shared (version-controlled) lock files
# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

echo "# local overlay"

# mkt-c and its plugin pc are installed, and pc is enabled only in the overlay
enable_pc_locally() {
  stub plugin marketplace add owner/mkt-c
  stub plugin install pc@mkt-c
  edit_json "$OVERLAY" '
    .enabledPlugins["pc@mkt-c"] = true
    | .extraKnownMarketplaces["mkt-c"] = {source: {source: "github", repo: "owner/mkt-c"}}'
  render_fixture_settings
}

snapshot_case local-install enable_pc_locally install
snapshot_case local-verify enable_pc_locally verify
snapshot_case local-update enable_pc_locally update

begin overlay-plugin-install
enable_pc_locally
cp "$ML" "$ROOT/ml-before"
cp "$PL" "$ROOT/pl-before"
run install
assert_eq "exits 0" "$EC" 0
assert_same_file "overlay plugin's marketplace is not added to the lock" "$ML" "$ROOT/ml-before"
assert_same_file "overlay plugin is not added to the lock" "$PL" "$ROOT/pl-before"
assert_contains "reports the plugin as local" "$OUTPUT" "Local only: pc@mkt-c"
assert_contains "reports the marketplace as local" "$OUTPUT" "Local only: mkt-c"
assert_not_contains "leaves the local plugin alone" "$CALLS" "pc@mkt-c"

begin overlay-plugin-verify
enable_pc_locally
run verify
assert_eq "verify passes with local-only plugins" "$EC" 0
assert_not_contains "local items are not drift" "$OUTPUT" "DRIFT"
assert_contains "lists the local plugin" "$OUTPUT" "Local only: pc@mkt-c"
assert_contains "lists the local marketplace" "$OUTPUT" "Local: mkt-c"

begin overlay-plugin-update
enable_pc_locally
run update
assert_eq "exits 0" "$EC" 0
assert_eq "update does not lock the overlay plugin" "$(json_keys "$PL")" "p1,urlp"
assert_eq "update does not lock its marketplace" "$(json_keys "$ML")" "mkt-a,mkt-b"

begin overlay-disables-base-plugin
edit_json "$OVERLAY" '.enabledPlugins["p1@mkt-a"] = false'
render_fixture_settings
run install
assert_eq "exits 0" "$EC" 0
assert_eq "a base plugin disabled locally stays in the shared lock" "$(json_keys "$PL")" "p1,urlp"
run verify
assert_not_contains "and is not drift" "$OUTPUT" "DRIFT"

begin base-declared-marketplace
stub plugin marketplace add owner/mkt-c
edit_json "$BASE" '.extraKnownMarketplaces["mkt-c"] = {source: {source: "github", repo: "owner/mkt-c"}}'
run install
assert_eq "a marketplace declared in the base is locked" "$(json_keys "$ML")" "mkt-a,mkt-b,mkt-c"
assert_eq "at its installed commit" "$(lock_commit "$ML" mkt-c)" "$(remote_head mkt-c)"

begin missing-base
rm "$BASE"
cp "$ML" "$ROOT/ml-before"
cp "$PL" "$ROOT/pl-before"
run install
assert_eq "install fails without settings.base.json" "$EC" 1
assert_same_file "marketplace lock is untouched" "$ML" "$ROOT/ml-before"
assert_same_file "plugin lock is untouched" "$PL" "$ROOT/pl-before"

echo "# live settings (model)"

begin live-model-kept
edit_json "$OVERLAY" '.model = "opus"'
render_fixture_settings
edit_json "$SETTINGS" '.model = "sonnet"'
run render
assert_eq "render keeps the model Claude Code last saved" "$(jq -r .model "$SETTINGS")" sonnet
assert_not_contains "a model change is not reported as live drift" "$OUTPUT" \
  "settings has changes since the last render"

begin overlay-model-default
rm "$SETTINGS" "$SNAPSHOT"
edit_json "$OVERLAY" '.model = "opus"'
run render
assert_eq "without a live model, the overlay's model is used" "$(jq -r .model "$SETTINGS")" opus

begin model-not-drift
edit_json "$SETTINGS" '.model = "haiku"'
run verify
assert_eq "verify passes after a model change" "$EC" 0
assert_contains "settings still match the render" "$OUTPUT" \
  "OK: settings file matches base + local overlay"

begin model-change-not-captured
edit_json "$SETTINGS" '.model = "haiku"'
run capture
assert_contains "capture has nothing to route for a model change" "$OUTPUT" \
  "no divergent changes to capture"

begin other-live-change-still-drift
edit_json "$SETTINGS" '.model = "haiku" | .theme = "light"'
run verify
assert_eq "other setting changes are still drift" "$EC" 1

finish
