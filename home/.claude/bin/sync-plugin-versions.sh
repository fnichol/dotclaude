#!/usr/bin/env sh
# sync-plugin-versions - Capture current plugin versions from cache
# Usage: sync-plugin-versions

set -e

CACHE_DIR="$HOME/.claude/plugins/cache"
VERSIONS_FILE="$HOME/.claude/plugins/.plugin-versions"

# Check dependencies
if ! command -v jq >/dev/null 2>&1; then
  printf "Error: jq is required but not installed\n" >&2
  exit 1
fi

# Check if cache directory exists
if [ ! -d "$CACHE_DIR" ]; then
  printf "Error: Plugin cache directory not found: %s\n" "$CACHE_DIR" >&2
  exit 1
fi

# Initialize empty JSON object
printf "{}\n" >"$VERSIONS_FILE.tmp"

# Scan each plugin in cache
for plugin_dir in "$CACHE_DIR"/*; do
  if [ ! -d "$plugin_dir" ]; then
    continue
  fi

  plugin_name=$(basename "$plugin_dir")
  plugin_json="$plugin_dir/.claude-plugin/plugin.json"

  # Check if plugin.json exists
  if [ ! -f "$plugin_json" ]; then
    printf "Warning: Skipping %s - no plugin.json found\n" "$plugin_name" >&2
    continue
  fi

  # Try to get git commit hash
  commit="unknown"
  if [ -d "$plugin_dir/.git" ]; then
    cd "$plugin_dir"
    commit=$(git rev-parse HEAD 2>/dev/null || printf "unknown")
    cd - >/dev/null 2>&1
  fi

  # Extract homepage/repository from plugin.json
  marketplace=$(jq -r '.homepage // .repository // "unknown"' "$plugin_json")

  # Get current date
  updated=$(date +%Y-%m-%d)

  # Build the entry
  entry=$(jq -n \
    --arg marketplace "$marketplace" \
    --arg commit "$commit" \
    --arg updated "$updated" \
    '{marketplace: $marketplace, commit: $commit, updated: $updated}')

  # Add to versions file
  jq --arg name "$plugin_name" --argjson entry "$entry" \
    '. + {($name): $entry}' "$VERSIONS_FILE.tmp" >"$VERSIONS_FILE.tmp.new"
  mv "$VERSIONS_FILE.tmp.new" "$VERSIONS_FILE.tmp"

  printf "Captured: %s @ %s\n" "$plugin_name" "$commit"
done

# Move temp file to final location
mv "$VERSIONS_FILE.tmp" "$VERSIONS_FILE"

printf "\nPlugin versions saved to: %s\n" "$VERSIONS_FILE"
printf "Total plugins: %s\n" "$(jq 'length' "$VERSIONS_FILE")"
