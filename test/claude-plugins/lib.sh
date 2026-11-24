# shellcheck shell=bash
# shellcheck disable=SC2034
#
# Test harness for claude-plugins. Sourced by every file in cases/.
#
# Each test runs the script in a throwaway sandbox: a fake $HOME, local bare
# git repos standing in for GitHub marketplaces, and a stub `claude` CLI (see
# bin/claude). The real ~/.claude is never touched.
#
# Environment:
#   CLAUDE_PLUGINS  script under test (default: home/.local/bin/claude-plugins)
#   UPDATE_GOLDEN   when set to 1, rewrite golden files instead of comparing
#   KEEP_SANDBOX    when set to 1, keep the sandbox directory after the run
#   RUN_TIMEOUT     seconds before a single script run is killed (default: 120)

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
SUT="${CLAUDE_PLUGINS:-$REPO_ROOT/home/.local/bin/claude-plugins}"
GOLDEN_DIR="$TEST_DIR/golden"
STUB_BIN="$TEST_DIR/bin"
TODAY="$(date -u +%Y-%m-%d)"

# Make fixture commit SHAs identical on every run and machine
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_AUTHOR_DATE="2020-01-01T00:00:00Z"
export GIT_COMMITTER_DATE="2020-01-01T00:00:00Z"

if [ ! -f "$SUT" ]; then
  echo "error: script under test not found: $SUT" >&2
  exit 2
fi

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/claude-plugins-test.XXXXXX")"
SANDBOX="$(cd "$SANDBOX" && pwd -P)"
cleanup_sandbox() {
  if [ "${KEEP_SANDBOX:-}" = 1 ]; then
    echo "sandbox kept: $SANDBOX" >&2
  else
    rm -rf "$SANDBOX"
  fi
}
trap cleanup_sandbox EXIT

ROOT="$SANDBOX/root"
H="$ROOT/home"
CP="$H/.claude/plugins"
REMOTES="$ROOT/remotes"
WORK="$ROOT/work"
FIXTURE_TAR="$SANDBOX/fixture.tar"

# Fixture content must not contain sandbox paths or commit SHAs would change on
# every run, so URL plugins use a fixed URL that git rewrites to the local remote
URL_BASE="https://example.invalid/"
GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig"
export GIT_CONFIG_GLOBAL
git config --file "$GIT_CONFIG_GLOBAL" "url.file://$REMOTES/.insteadOf" "$URL_BASE"

SETTINGS="$H/.claude/settings.json"
BASE="$H/.claude/settings.base.json"
OVERLAY="$H/.claude/settings.local-overlay.json"
SNAPSHOT="$H/.claude/.settings.rendered.json"
ML="$CP/.marketplaces.lock.json"
PL="$CP/.plugins.lock.json"
KM="$CP/known_marketplaces.json"
IP="$CP/installed_plugins.json"

# Tools the script needs on PATH. Resolve them to real binaries because a
# version-manager shim (such as mise) may not work under the sandboxed $HOME.
real_cmd() {
  local entry resolved
  local IFS=:
  for entry in $PATH; do
    [ -x "$entry/$1" ] || continue
    case "$entry" in
      */mise/shims | */.asdf/shims)
        resolved="$(mise which "$1" 2>/dev/null)" || continue
        printf "%s\n" "$resolved"
        ;;
      *)
        printf "%s\n" "$entry/$1"
        ;;
    esac
    return 0
  done
  return 1
}
TOOLS_BIN="$SANDBOX/tools"
mkdir -p "$TOOLS_BIN"
for _tool in jq git; do
  _path="$(real_cmd "$_tool")" || {
    echo "error: required tool not found: $_tool" >&2
    exit 2
  }
  ln -s "$_path" "$TOOLS_BIN/$_tool"
done
unset _tool _path
BASE_PATH="$TOOLS_BIN:/usr/bin:/bin:/usr/sbin:/sbin"

# ---- results ----------------------------------------------------------------

PASS=0
FAIL=0
SKIP=0
CURRENT=""

pass() {
  PASS=$((PASS + 1))
  printf "  ok    %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf "  FAIL  %s: %s\n" "$CURRENT" "$1"
  if [ -n "${2:-}" ]; then
    printf "%s\n" "$2" | sed 's/^/          /'
  fi
}

skip() {
  SKIP=$((SKIP + 1))
  printf "  skip  %s: %s\n" "$CURRENT" "$1"
}

finish() {
  printf "  -- %d passed, %d failed, %d skipped\n" "$PASS" "$FAIL" "$SKIP"
  [ "$FAIL" -eq 0 ]
}

# ---- fixture ----------------------------------------------------------------
#
# The base fixture is a fully synced machine:
#
#   marketplace mkt-a: local plugins p1 (enabled) and p2 (installed, disabled)
#   marketplace mkt-b: URL plugin urlp (enabled), cloned from remotes/urlp.git
#   marketplace mkt-c: local plugin pc; exists upstream but is not installed
#
# Both lock files, settings.json, and the render snapshot all agree.

fixture_commit() {
  local name="$1" message="$2" dir="$WORK/$1"
  echo "$message" >"$dir/CHANGES"
  git -C "$dir" add -A
  git -C "$dir" commit -qm "$message"
  git -C "$dir" push -q origin HEAD
}

fixture_remote() {
  local name="$1" builder="$2" dir="$WORK/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  "$builder" "$dir"
  git -C "$dir" add -A
  git -C "$dir" commit -qm init
  git clone -q --bare "$dir" "$REMOTES/$name.git"
  git -C "$dir" remote add origin "$REMOTES/$name.git"
  git -C "$dir" fetch -q origin
  git -C "$dir" branch -q -u origin/main
}

build_urlp() { echo urlp >"$1/README"; }

build_mkt_a() {
  mkdir -p "$1/.claude-plugin" "$1/plugins/p1" "$1/plugins/p2"
  echo p1 >"$1/plugins/p1/README"
  echo p2 >"$1/plugins/p2/README"
  jq -n '{name: "mkt-a", plugins: [
    {name: "p1", source: "./plugins/p1", version: "1.0.0"},
    {name: "p2", source: "./plugins/p2", version: "2.0.0"}
  ]}' >"$1/.claude-plugin/marketplace.json"
}

build_mkt_b() {
  mkdir -p "$1/.claude-plugin"
  jq -n --arg u "${URL_BASE}urlp.git" \
    '{name: "mkt-b", plugins: [{name: "urlp", source: {source: "url", url: $u}}]}' \
    >"$1/.claude-plugin/marketplace.json"
}

build_mkt_c() {
  mkdir -p "$1/.claude-plugin" "$1/plugins/pc"
  echo pc >"$1/plugins/pc/README"
  jq -n '{name: "mkt-c", plugins: [{name: "pc", source: "./plugins/pc"}]}' \
    >"$1/.claude-plugin/marketplace.json"
}

build_fixture() {
  rm -rf "$ROOT"
  mkdir -p "$REMOTES" "$WORK" "$CP"

  fixture_remote urlp build_urlp
  fixture_remote mkt-a build_mkt_a
  fixture_remote mkt-b build_mkt_b
  fixture_remote mkt-c build_mkt_c

  stub plugin marketplace add owner/mkt-a
  stub plugin marketplace add owner/mkt-b
  stub plugin install p1@mkt-a
  stub plugin install p2@mkt-a
  stub plugin install urlp@mkt-b

  jq -n '{
    theme: "dark",
    enabledPlugins: {"p1@mkt-a": true, "p2@mkt-a": false, "urlp@mkt-b": true},
    extraKnownMarketplaces: {
      "mkt-a": {source: {source: "github", repo: "owner/mkt-a"}},
      "mkt-b": {source: {source: "github", repo: "owner/mkt-b"}}
    }
  }' >"$BASE"
  jq -n '{enabledPlugins: {}, extraKnownMarketplaces: {}}' >"$OVERLAY"
  render_fixture_settings

  jq -n --sort-keys \
    --arg a "$(remote_head mkt-a)" --arg b "$(remote_head mkt-b)" --arg d "$TODAY" '{
      "mkt-a": {source: "github", repo: "owner/mkt-a", commit: $a, updated: $d},
      "mkt-b": {source: "github", repo: "owner/mkt-b", commit: $b, updated: $d}
    }' >"$ML"
  jq -n --sort-keys \
    --arg a "$(remote_head mkt-a)" --arg u "$(remote_head urlp)" --arg d "$TODAY" '{
      "p1": {marketplace: "mkt-a", commit: $a, updated: $d},
      "urlp": {marketplace: "mkt-b", commit: $u, updated: $d}
    }' >"$PL"

  tar -C "$SANDBOX" -cf "$FIXTURE_TAR" root
}

restore_fixture() {
  [ -f "$FIXTURE_TAR" ] || build_fixture
  rm -rf "$ROOT"
  tar -C "$SANDBOX" -xf "$FIXTURE_TAR"
  mkdir -p "$ROOT/tmp"
}

# Runs the stub claude CLI directly, for arranging fixture state
stub() {
  HOME="$H" REMOTES="$REMOTES" STUB_LOG="$ROOT/fixture.log" \
    PATH="$STUB_BIN:$BASE_PATH" "$STUB_BIN/claude" "$@"
}

# Edits a JSON file in place with a jq program
edit_json() {
  local file="$1"
  shift
  jq "$@" "$file" >"$file.edit" && mv "$file.edit" "$file"
}

render_fixture_settings() {
  jq -s --sort-keys '.[0] * .[1]' "$BASE" "$OVERLAY" >"$SETTINGS"
  cp "$SETTINGS" "$SNAPSHOT"
}

remote_head() { git --git-dir "$REMOTES/$1.git" rev-parse HEAD; }
local_head() { git -C "$1" rev-parse HEAD; }
lock_commit() { jq -r --arg n "$2" '.[$n].commit' "$1"; }
json_keys() { jq -r 'keys | join(",")' "$1"; }
installed_keys() { jq -r '.plugins | keys | join(",")' "$IP"; }

# Pushes a new commit to a fixture remote
upstream_commit() { fixture_commit "$1" "$2"; }

# ---- running the script -----------------------------------------------------

# begin <name>: starts a test from a fresh copy of the base fixture
begin() {
  CURRENT="$1"
  restore_fixture
}

# detach <command...>: runs a command in a new session with no controlling
# terminal, killing it with SIGALRM (exit 142) after RUN_TIMEOUT seconds.
#
# Without this, a test run from a terminal lets the script open /dev/tty (as
# capture does to prompt), and the test silently waits for an answer forever.
RUN_TIMEOUT="${RUN_TIMEOUT:-120}"
if command -v perl >/dev/null 2>&1; then
  detach() {
    perl -MPOSIX -e '
      my $timeout = shift @ARGV;
      unless (defined POSIX::setsid()) {
        # Already a process group leader: setsid from a forked child instead
        defined(my $pid = fork) or die "fork: $!\n";
        if ($pid) {
          waitpid($pid, 0);
          exit(($? & 127) ? 128 + ($? & 127) : $? >> 8);
        }
        defined POSIX::setsid() or die "setsid: $!\n";
      }
      alarm $timeout;
      exec { $ARGV[0] } @ARGV or die "exec: $!\n";
    ' "$RUN_TIMEOUT" "$@"
  }
elif command -v python3 >/dev/null 2>&1; then
  detach() {
    python3 -I -c '
import os, signal, sys
timeout, argv = int(sys.argv[1]), sys.argv[2:]
try:
    os.setsid()
except OSError:
    # Already a process group leader: setsid from a forked child instead
    pid = os.fork()
    if pid:
        _, status = os.waitpid(pid, 0)
        code = os.waitstatus_to_exitcode(status)
        sys.exit(128 - code if code < 0 else code)
    os.setsid()
signal.alarm(timeout)
os.execvp(argv[0], argv)
' "$RUN_TIMEOUT" "$@"
  }
else
  echo "error: perl or python3 is required to run tests without a terminal" >&2
  exit 2
fi

# run <args...>: runs the script under test in the sandbox and sets:
#   EC      exit code
#   OUTPUT  stdout and stderr
#   CALLS   the `claude` invocations it made, one per line
run() {
  : >"$ROOT/run.log"
  detach env -i \
    HOME="$H" \
    PATH="${RUN_PATH:-$STUB_BIN:$BASE_PATH}" \
    TERM=dumb \
    TMPDIR="$ROOT/tmp" \
    REMOTES="$REMOTES" \
    STUB_LOG="$ROOT/run.log" \
    GIT_CONFIG_GLOBAL="$GIT_CONFIG_GLOBAL" \
    GIT_CONFIG_NOSYSTEM=1 \
    sh "$SUT" "$@" </dev/null >"$ROOT/run.out" 2>&1
  EC=$?
  OUTPUT="$(cat "$ROOT/run.out")"
  CALLS="$(cat "$ROOT/run.log")"
  if [ "$EC" -eq 142 ]; then
    fail "timed out after ${RUN_TIMEOUT}s: claude-plugins $*" "$OUTPUT"
  fi
}

# run_tty <answers> <args...>: like run, but under a pseudo-terminal (needs
# expect), answering each "Capture into" prompt with the next word of answers
run_tty() {
  local answers="$1"
  shift
  local script="log_user 1; set timeout 20
    spawn env -i HOME=$H PATH=$STUB_BIN:$BASE_PATH TERM=dumb TMPDIR=$ROOT/tmp \
      REMOTES=$REMOTES STUB_LOG=$ROOT/run.log GIT_CONFIG_GLOBAL=$GIT_CONFIG_GLOBAL \
      GIT_CONFIG_NOSYSTEM=1 sh $SUT $*"
  local answer
  for answer in $answers; do
    script="$script
    expect {Capture into} { send \"$answer\\r\" } timeout { exit 98 }"
  done
  script="$script
    expect eof
    catch wait result
    exit [lindex \$result 3]"
  : >"$ROOT/run.log"
  expect -c "$script" >"$ROOT/run.out" 2>&1
  EC=$?
  OUTPUT="$(tr -d '\r' <"$ROOT/run.out")"
  CALLS="$(cat "$ROOT/run.log")"
}

# ---- state snapshots --------------------------------------------------------

# Prints everything a command could change, with sandbox paths and today's
# date normalized so the output is stable across runs and machines
state() {
  state_raw 2>&1 | sed -e "s|$ROOT|@ROOT@|g" -e "s|$TODAY|@TODAY@|g"
}

state_raw() {
  local file dir
  for file in "$SETTINGS" "$SNAPSHOT" "$BASE" "$OVERLAY" "$ML" "$PL" "$KM" "$IP"; do
    echo "== ${file#"$H/"}"
    if [ -f "$file" ]; then jq -S . "$file" 2>&1; else echo MISSING; fi
  done
  echo "== marketplace HEADs"
  for dir in "$CP"/marketplaces/*; do
    [ -d "$dir" ] && echo "$(basename "$dir") $(local_head "$dir")"
  done
  echo "== cache"
  [ -d "$CP/cache" ] && (cd "$CP/cache" && find . -mindepth 1 -maxdepth 3 -type d | sort)
  echo "== leftover temp files"
  find "$H" -name '*.tmp' | sort
  ls "$ROOT/tmp"
}

# snapshot_case <name> <setup-fn> <args...>
#
# Arranges the fixture with setup-fn, runs the script, and compares the exit
# code, the `claude` calls it made, and what it changed on disk against
# golden/<name>.golden. Run with UPDATE_GOLDEN=1 to (re)record golden files,
# then review the diff before committing.
snapshot_case() {
  local name="$1" setup="$2"
  shift 2
  begin "$name"
  "$setup"
  local before after actual golden="$GOLDEN_DIR/$name.golden"
  before="$(state)"
  run "$@"
  after="$(state)"
  actual="$(
    echo "command: claude-plugins $*"
    echo "exit: $EC"
    echo "claude calls:"
    printf "%s\n" "$CALLS" | sed '/^$/d; s/^/  /'
    echo "changes:"
    diff -U2 <(printf "%s\n" "$before") <(printf "%s\n" "$after") | tail -n +3
  )"

  if [ "${UPDATE_GOLDEN:-}" = 1 ]; then
    printf "%s\n" "$actual" >"$golden"
    pass "$name (golden updated)"
  elif [ ! -f "$golden" ]; then
    fail "no golden file; run with UPDATE_GOLDEN=1 to record it"
  elif [ "$(cat "$golden")" = "$actual" ]; then
    pass "$name"
  else
    fail "differs from golden/$name.golden" \
      "$(diff -u "$golden" <(printf "%s\n" "$actual") | tail -n +3)"
  fi
}

# ---- assertions -------------------------------------------------------------

assert_eq() { # <description> <actual> <expected>
  if [ "$2" = "$3" ]; then
    pass "$1"
  else
    fail "$1" "expected: $3
actual:   $2"
  fi
}

assert_contains() { # <description> <haystack> <needle>
  if printf "%s" "$2" | grep -Fq -- "$3"; then
    pass "$1"
  else
    fail "$1" "missing: $3"
  fi
}

assert_not_contains() { # <description> <haystack> <needle>
  if printf "%s" "$2" | grep -Fq -- "$3"; then
    fail "$1" "unexpected: $3"
  else
    pass "$1"
  fi
}

assert_same_file() { # <description> <file> <expected-file>
  if cmp -s "$2" "$3"; then
    pass "$1"
  else
    fail "$1" "$(diff -u "$3" "$2" | tail -n +3)"
  fi
}

# ---- fixture arrangements -----------------------------------------------------
# Small setup functions shared by the case files.

noop() { :; }
drift_live_settings() { edit_json "$SETTINGS" '.enabledPlugins["p2@mkt-a"] = true'; }
install_mkt_c() { stub plugin marketplace add owner/mkt-c; }
lock_ghost_marketplace() {
  edit_json "$ML" \
    '.ghost = {source: "github", repo: "owner/ghost", commit: "deadbeef", updated: "x"}'
}
lock_mkt_a_ahead() {
  upstream_commit mkt-a "a2"
  # shellcheck disable=SC2016
  edit_json "$ML" --arg c "$(remote_head mkt-a)" '.["mkt-a"].commit = $c'
}
lock_wrong_urlp_commit() {
  edit_json "$PL" '.urlp.commit = "0000000000000000000000000000000000000000"'
}
fresh_machine() {
  rm -rf "$CP/marketplaces" "$CP/cache" "$KM" "$IP" "$SETTINGS" "$SNAPSHOT"
}
fresh_machine_with_other_marketplace() {
  fresh_machine
  stub plugin marketplace add owner/mkt-c
}
install_unlocked_plugin() {
  stub plugin marketplace add owner/mkt-c
  stub plugin install pc@mkt-c
  edit_json "$BASE" '.enabledPlugins["pc@mkt-c"] = true'
}
lock_ghost_plugin() {
  edit_json "$PL" '.ghostp = {marketplace: "mkt-a", commit: "abc", updated: "x"}'
}
uninstall_urlp() { stub plugin remove urlp@mkt-b; }
move_upstreams() {
  upstream_commit mkt-a "a2"
  upstream_commit urlp "u2"
}
lock_non_github_marketplace() {
  edit_json "$ML" \
    '.weird = {source: "git", repo: "https://example.com/y.git", commit: "abc", updated: "x"}'
}
# Turns an installed marketplace into a snapshot install, the way Claude Code
# installs claude-plugins-official: no .git, its commit recorded in .gcs-sha.
# Later adds and updates of it (via the stub) stay snapshots.
make_snapshot_marketplace() {
  local name="$1" dir="$CP/marketplaces/$1"
  touch "$REMOTES/$name.snapshot"
  if [ -d "$dir/.git" ]; then
    local_head "$dir" >"$dir/.gcs-sha"
    rm -rf "$dir/.git"
  fi
}
