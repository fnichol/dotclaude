#!/usr/bin/env sh
# verify-plugin-versions - Verify installed plugins match expected versions
# Usage: verify-plugin-versions

set -e

CACHE_DIR="$HOME/.claude/plugins/cache"
VERSIONS_FILE="$HOME/.claude/plugins/.plugin-versions"

# Check dependencies
if ! command -v jq >/dev/null 2>&1; then
  printf "Error: jq is required but not installed\n" >&2
  exit 1
fi

# Check if versions file exists
if [ ! -f "$VERSIONS_FILE" ]; then
  printf "Error: Plugin versions file not found: %s\n" "$VERSIONS_FILE" >&2
  printf "Run sync-plugin-versions first to create it.\n" >&2
  exit 1
fi

# Check if cache directory exists
if [ ! -d "$CACHE_DIR" ]; then
  printf "Warning: Plugin cache directory not found: %s\n" "$CACHE_DIR" >&2
  printf "Plugins will be downloaded on first Claude Code run.\n" >&2
  exit 0
fi

exit_code=0
missing_count=0
mismatch_count=0
extra_count=0
match_count=0

printf "Verifying plugin versions...\n\n"

# Check expected plugins
expected_plugins=$(jq -r 'keys[]' "$VERSIONS_FILE")

for plugin_name in $expected_plugins; do
  plugin_dir="$CACHE_DIR/$plugin_name"
  expected_commit=$(jq -r --arg name "$plugin_name" '.[$name].commit' "$VERSIONS_FILE")

  if [ ! -d "$plugin_dir" ]; then
    printf "MISSING: %s (expected @ %s)\n" "$plugin_name" "$expected_commit"
    missing_count=$((missing_count + 1))
    exit_code=1
    continue
  fi

  # Get actual commit
  actual_commit="unknown"
  if [ -d "$plugin_dir/.git" ]; then
    cd "$plugin_dir"
    actual_commit=$(git rev-parse HEAD 2>/dev/null || printf "unknown")
    cd - >/dev/null 2>&1
  fi

  if [ "$actual_commit" = "$expected_commit" ]; then
    printf "OK: %s @ %s\n" "$plugin_name" "$actual_commit"
    match_count=$((match_count + 1))
  else
    printf "MISMATCH: %s\n" "$plugin_name"
    printf "  Expected: %s\n" "$expected_commit"
    printf "  Actual:   %s\n" "$actual_commit"
    mismatch_count=$((mismatch_count + 1))
    exit_code=1
  fi
done

# Check for extra plugins not in versions file
if [ -d "$CACHE_DIR" ]; then
  for plugin_dir in "$CACHE_DIR"/*; do
    if [ ! -d "$plugin_dir" ]; then
      continue
    fi

    plugin_name=$(basename "$plugin_dir")
    is_expected=$(jq -r --arg name "$plugin_name" 'has($name)' "$VERSIONS_FILE")

    if [ "$is_expected" = "false" ]; then
      printf "EXTRA: %s (not in versions file)\n" "$plugin_name"
      extra_count=$((extra_count + 1))
      # Don't set exit_code for extras - they're informational
    fi
  done
fi

printf "\n=== Summary ===\n"
printf "Matching: %d\n" "$match_count"
printf "Missing:  %d\n" "$missing_count"
printf "Mismatch: %d\n" "$mismatch_count"
printf "Extra:    %d\n" "$extra_count"

if [ $exit_code -eq 0 ]; then
  printf "\nAll plugins match expected versions.\n"
else
  printf "\nSome plugins need attention.\n"
fi

exit $exit_code
