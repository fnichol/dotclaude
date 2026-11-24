#!/usr/bin/env bash
# Runs the claude-plugins test suite. Case files run in parallel, each in its
# own sandbox, and their output is printed in order once all have finished.
#
# Usage: test/claude-plugins/run.sh [CASE...]
#
#   CASE  name of a file in cases/ without .sh (default: all of them)
#
# Environment:
#   CLAUDE_PLUGINS  script under test (default: home/.local/bin/claude-plugins)
#   UPDATE_GOLDEN   set to 1 to re-record golden files (review the diff!)
#   KEEP_SANDBOX    set to 1 to keep each case file's sandbox for inspection
#   RUN_TIMEOUT     seconds before a single script run is killed (default: 120)
set -u

dir="$(cd "$(dirname "$0")" && pwd)"

if [ "$#" -eq 0 ]; then
  set -- "$dir"/cases/*.sh
else
  cases=()
  for name in "$@"; do
    cases+=("$dir/cases/${name%.sh}.sh")
  done
  set -- "${cases[@]}"
fi

for file in "$@"; do
  if [ ! -f "$file" ]; then
    echo "error: no such case file: $file" >&2
    exit 2
  fi
done

logs="$(mktemp -d "${TMPDIR:-/tmp}/claude-plugins-run.XXXXXX")"
trap 'rm -rf "$logs"' EXIT

pids=()
for file in "$@"; do
  name="$(basename "$file" .sh)"
  bash "$file" >"$logs/$name.log" 2>&1 &
  pids+=("$!")
done

failed=()
i=0
for file in "$@"; do
  name="$(basename "$file" .sh)"
  wait "${pids[$i]}" || failed+=("$name")
  cat "$logs/$name.log"
  echo
  i=$((i + 1))
done

if [ "${#failed[@]}" -eq 0 ]; then
  echo "All claude-plugins tests passed"
else
  echo "Failed: ${failed[*]}"
  exit 1
fi
