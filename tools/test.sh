#!/usr/bin/env bash
# Unit gate: import, then run game/tests/run_all.gd and every game/tests/t_*.gd headless.
# A file passes only with exit 0, a PASS verdict ("[tests] PASS" for run_all, "[t_<name>] PASS"
# and no "[t_<name>] FAIL" for t_*.gd) and no 'SCRIPT ERROR' / 'Parse Error' line: GDScript keeps
# running after a runtime error, so a crashed test used to print PASS. Every run gets a throwaway
# HOME, so tests never share a save with each other or touch the owner's real user:// data.
# Usage: tools/test.sh [--no-import]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$($ROOT/tools/find_godot.sh)" || exit 127
# Strict expected failures (" t_x t_y "): listed files must FAIL; one that passes (XPASS) fails
# the gate so the entry gets removed. Empty: t_rules passes since W1-TAME merged.
XFAIL=" "
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME" XDG_DATA_HOME="$TMP_HOME/.local/share" XDG_CONFIG_HOME="$TMP_HOME/.config"
if [[ "${1:-}" != "--no-import" ]]; then
  perl -e 'alarm 400; exec @ARGV' "$G" --headless --path "$ROOT/game" --import >/dev/null 2>&1
fi
# run_one <log> <script>: a test that crashes inside _init/_process never quits, so stop it as soon
# as a SCRIPT ERROR / Parse Error line appears (1 s grace for the backtrace) instead of waiting out
# the 120 s alarm. The subshell keeps bash's "Terminated" / "Alarm clock" job notices out of the output.
# A test may cause a script error on purpose if it says so first: each "[t_x] the next SCRIPT ERROR"
# line (t_save counts its own errors this way) excuses one engine "SCRIPT ERROR:" line.
crash_line() {  # crash_line <log>: the first Parse Error or unannounced SCRIPT ERROR line, if any
  local said; said="$(grep -cE '^\[t_[a-z0-9_]+\] the next SCRIPT ERROR' "$1")"
  grep -m1 -E 'Parse Error' "$1" || grep -E '^SCRIPT ERROR' "$1" | sed -n "$((said + 1))p" | grep .
}
run_one() {
  ( perl -e 'alarm 120; exec @ARGV' "$G" --headless --path "$ROOT/game" --script "$2" > "$1" 2>&1 < /dev/null &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
      if crash_line "$1" >/dev/null; then sleep 1; kill "$pid" 2>/dev/null; break; fi
      sleep 0.3
    done
    wait "$pid"; exit $? ) 2>/dev/null
}
LOG="$TMP_HOME/test.log"
bad=0; total=0
for f in "$ROOT/game/tests/run_all.gd" "$ROOT"/game/tests/t_*.gd; do
  [[ -f "$f" ]] || continue
  name="$(basename "$f" .gd)"
  # Verdict tag: "[tests]" for run_all; any "[t_*]" for t_*.gd (t_lighting.gd prints "[t_light]").
  tag='t_[a-z0-9_]+'; [[ "$name" == run_all ]] && tag=tests
  total=$((total + 1))
  run_one "$LOG" "res://tests/$name.gd"
  code=$?
  out="$(cat "$LOG")"
  why=""
  echo "$out" | grep -qE "^\[$tag\] PASS" || why="no [$tag] PASS line"
  [[ -z "$why" ]] && echo "$out" | grep -qE "^\[$tag\] FAIL" && why="$(echo "$out" | grep -m1 -E "^\[$tag\] FAIL")"
  err="$(crash_line "$LOG")" && why="$err"
  [[ $code -ne 0 ]] && why="exit $code${why:+; $why}"
  if [[ "$XFAIL" == *" $name "* ]]; then
    # An expected failure must be the test's own FAIL verdict, never a crash or compile error.
    if [[ -n "$why" && -z "$err" ]] && echo "$out" | grep -qE "^\[$tag\] FAIL"; then echo "[test] XFAIL $name ($(echo "$out" | grep -m1 -E "^\[$tag\] FAIL"))"
    elif [[ -n "$why" ]]; then echo "[test] FAIL $name (expected-fail file crashed: $why)"; bad=$((bad + 1)); else echo "[test] XPASS $name (passes now: remove it from XFAIL in tools/test.sh)"; bad=$((bad + 1)); fi
  elif [[ -n "$why" ]]; then
    echo "$out" | grep -E "^\[($tag)\]|^SCRIPT ERROR|Parse Error|^ +at: " | head -20
    echo "[test] FAIL $name ($why)"; bad=$((bad + 1))
  else
    echo "[test] PASS $name"
  fi
done
if [[ $bad -eq 0 ]]; then echo "[tests] PASS files=$total"; exit 0; fi
echo "[tests] FAIL $bad/$total files"; exit 1
