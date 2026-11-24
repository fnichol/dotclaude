#!/usr/bin/env bash
# verify: read-only checks of settings, lock files, and installed versions
# shellcheck source=../lib.sh
. "$(dirname "$0")/../lib.sh"

echo "# verify"

remove_settings() { rm "$SETTINGS"; }
remove_overlay() { rm "$OVERLAY"; }
# The lock moves ahead of the installed mkt-a checkout
rewind_mkt_a() { lock_mkt_a_ahead; }
remove_mkt_b_dir() { rm -rf "$CP/marketplaces/mkt-b"; }
remove_urlp_dir() { rm -rf "$CP/cache/mkt-b/urlp"; }
add_stray_cache_dir() { mkdir -p "$CP/cache/stray-plugin"; }
remove_marketplaces_lock() { rm "$ML"; }
remove_plugins_lock() { rm "$PL"; }
remove_cache() { rm -rf "$CP/cache"; }
remove_marketplaces_dir() { rm -rf "$CP/marketplaces"; }

snapshot_case verify-clean noop verify
snapshot_case verify-settings-drift drift_live_settings verify
snapshot_case verify-no-settings remove_settings verify
snapshot_case verify-no-overlay remove_overlay verify
snapshot_case verify-mkt-extra-installed install_mkt_c verify
snapshot_case verify-mkt-lock-extra lock_ghost_marketplace verify
snapshot_case verify-mkt-behind rewind_mkt_a verify
snapshot_case verify-mkt-missing-dir remove_mkt_b_dir verify
snapshot_case verify-plugin-mismatch lock_wrong_urlp_commit verify
snapshot_case verify-plugin-missing remove_urlp_dir verify
snapshot_case verify-cache-extra add_stray_cache_dir verify
snapshot_case verify-no-mlock remove_marketplaces_lock verify
snapshot_case verify-no-plock remove_plugins_lock verify
snapshot_case verify-no-cache remove_cache verify
snapshot_case verify-no-mdir remove_marketplaces_dir verify

begin clean
run verify
assert_eq "a synced machine passes" "$EC" 0
assert_not_contains "no drift reported" "$OUTPUT" "DRIFT"
assert_eq "verify makes no claude calls" "$CALLS" ""

# Regression: an installed-but-disabled plugin (p2) used to count as drift,
# so verify failed on every synced machine
begin disabled-plugin-is-not-drift
run verify
assert_contains "plugin lock is up to date despite disabled p2" "$OUTPUT" \
  "OK: Plugin lock file is up to date"

begin settings-drift
drift_live_settings
run verify
assert_eq "exits 1" "$EC" 1
assert_contains "reports settings drift" "$OUTPUT" "DRIFT: settings file differs"

begin new-items-not-locked
install_unlocked_plugin
render_fixture_settings
run verify
assert_eq "exits 1" "$EC" 1
assert_contains "reports unlocked marketplace" "$OUTPUT" \
  "DRIFT: Marketplace 'mkt-c' is in Claude but not in lock file"
assert_contains "reports unlocked plugin" "$OUTPUT" \
  "DRIFT: Plugin 'pc' is in Claude but not in lock file"
run install
run verify
assert_eq "install fixes what verify reported" "$EC" 0

begin unneeded-locked-marketplace
lock_ghost_marketplace
run verify
assert_contains "reports marketplace nobody needs" "$OUTPUT" \
  "DRIFT: Marketplace 'ghost' is in lock file but neither installed nor used"

begin locked-plugin-disabled
edit_json "$BASE" '.enabledPlugins["urlp@mkt-b"] = false'
render_fixture_settings
run verify
assert_contains "reports locked plugin disabled in settings" "$OUTPUT" \
  "DRIFT: Plugin 'urlp' is in lock file but not enabled in settings"

begin fresh-machine
fresh_machine
render_fixture_settings
run verify
assert_contains "enabled+locked plugins not yet installed are not drift" "$OUTPUT" \
  "OK: Plugin lock file is up to date"
assert_contains "marketplaces needed by enabled plugins are not drift" "$OUTPUT" \
  "OK: Marketplace lock file is up to date"

begin marketplace-mismatch
rewind_mkt_a
run verify
assert_eq "exits 1" "$EC" 1
assert_contains "reports marketplace mismatch" "$OUTPUT" "Mismatch: mkt-a"

begin plugin-mismatch
lock_wrong_urlp_commit
run verify
assert_eq "exits 1" "$EC" 1
assert_contains "reports plugin mismatch" "$OUTPUT" "Mismatch: urlp"

begin read-only
cp -R "$H" "$ROOT/home-before"
lock_ghost_marketplace
cp "$ML" "$ROOT/ml-before"
run verify
assert_same_file "verify does not change the marketplace lock" "$ML" "$ROOT/ml-before"
assert_same_file "verify does not change the plugin lock" "$PL" "$ROOT/home-before/.claude/plugins/.plugins.lock.json"
assert_same_file "verify does not change settings" "$SETTINGS" "$ROOT/home-before/.claude/settings.json"

finish
