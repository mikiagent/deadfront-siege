#!/usr/bin/env bash
# Lab gate: runs every row of tools/labs.txt headless with its timeout and prints one table row
# per lab. A row PASSes only with exit 0, a "] PASS" line and no "] FAIL" / "] PARTIAL" /
# 'SCRIPT ERROR' / 'Parse Error' line. Exit 1 if any row fails. Every row gets a throwaway HOME,
# so no lab reads another lab's save (run order cannot matter) and none touches a real save.
# NOISE counts engine ERROR/WARNING lines in a passing log (they used to be ignored silently).
#
# Usage: tools/labs.sh [name-filter]              headless gate, logs in $LABS_LOG_DIR (or a temp dir)
#        tools/labs.sh --shots DIR [name-filter]  rows flagged "shot": windowed web renderer
#            (gl_compatibility, 1600x900) still into DIR/<name>.png, then an exposure check
#            (black, blank or blown frames fail). Needs a display (xvfb-run on Linux CI). Silent.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$($ROOT/tools/find_godot.sh)" || exit 127
LIST="${LABS_LIST:-$ROOT/tools/labs.txt}"
shots=""; filter=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --shots) shots="$2"; shift 2 ;;
    *) filter="$1"; shift ;;
  esac
done
LOGS="${LABS_LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOGS"
[[ -n "$shots" ]] && mkdir -p "$shots" && shots="$(cd "$shots" && pwd)"

run_godot() {  # run_godot <timeout> <log> <args...>: fresh HOME, no stdin (labs.txt is on stdin)
  local secs="$1" log="$2"; shift 2
  local h; h="$(mktemp -d)"
  HOME="$h" XDG_DATA_HOME="$h/.local/share" XDG_CONFIG_HOME="$h/.config" \
    perl -e "alarm $secs; exec @ARGV" "$G" "$@" > "$log" 2>&1 < /dev/null
  local code=$?
  rm -rf "$h"
  return $code
}

bad=0; total=0
printf '%-24s %-6s %5s %5s  %s\n' LAB RESULT SECS NOISE DETAIL
while IFS= read -r line; do
  line="${line%%#*}"
  IFS='|' read -r name secs args flags <<< "$line"
  name="$(echo $name)"; secs="$(echo $secs)"; flags=" $(echo $flags) "
  [[ -z "$name" ]] && continue
  [[ -n "$filter" && "$name" != *"$filter"* ]] && continue
  if [[ -n "$shots" ]]; then
    [[ "$flags" == *" shot "* ]] || continue
    total=$((total + 1))
    t0=$SECONDS
    # shellcheck disable=SC2086  # args are plain flags, split on purpose
    run_godot "$secs" "$LOGS/$name.shot.log" --audio-driver Dummy --path "$ROOT/game" --rendering-method gl_compatibility \
      --resolution 1600x900 $args "--shot=$shots/$name.png"
    code=$?
    if [[ -s "$shots/$name.png" ]]; then r=SHOT; d="$shots/$name.png"; else r=FAIL; d="no still (exit $code)"; bad=$((bad + 1)); fi
    printf '%-24s %-6s %5d %5s  %s\n' "$name" "$r" $((SECONDS - t0)) - "$d"
    continue
  fi
  total=$((total + 1))
  log="$LOGS/$name.log"
  t0=$SECONDS
  # shellcheck disable=SC2086
  run_godot "$secs" "$log" --headless --path "$ROOT/game" $args
  code=$?
  took=$((SECONDS - t0))
  why=""
  grep -qE '\] PASS' "$log" || why="no PASS line"
  hit="$(grep -m1 -E '\] (FAIL|PARTIAL)|SCRIPT ERROR|Parse Error' "$log")" && why="$hit"
  crash="$(grep -m1 -E 'SCRIPT ERROR|Parse Error' "$log")"
  if [[ $code -eq 142 ]]; then why="timeout ${secs}s${why:+; $why}"
  elif [[ $code -ne 0 ]]; then why="exit $code${why:+; $why}"; fi
  noise="$(grep -cE '^ *(USER )?(ERROR|WARNING):' "$log")"
  xfail=""; [[ "$flags" =~ \ xfail:([^ ]+)\  ]] && xfail="${BASH_REMATCH[1]}"
  verdict="$(grep -E '\] (PASS|FAIL|PARTIAL)' "$log" | tail -1 | cut -c1-110)"
  if [[ -n "$xfail" ]]; then
    # Strict: an expected failure must be the lab's own FAIL/PARTIAL verdict or its timeout, not a crash.
    if [[ -n "$why" && -z "$crash" ]]; then r=XFAIL; d="$xfail owns it: ${why:0:100}"
    elif [[ -n "$why" ]]; then r=FAIL; d="crashed: ${why:0:100}"; bad=$((bad + 1))
    else r=XPASS; d="passes now: drop xfail:$xfail from labs.txt"; bad=$((bad + 1)); fi
  elif [[ -n "$why" ]]; then r=FAIL; d="${why:0:110}"; bad=$((bad + 1))
  else r=PASS; d="$verdict"; fi
  printf '%-24s %-6s %5d %5s  %s\n' "$name" "$r" "$took" "$noise" "$d"
done < "$LIST"

if [[ -n "$shots" && $total -gt 0 ]]; then
  run_godot 120 "$LOGS/shot_check.log" --headless --path "$ROOT/game" --script res://scripts/dev/shot_check.gd -- "$shots"/*.png
  code=$?
  grep -E '^\[shot\]|SCRIPT ERROR' "$LOGS/shot_check.log"
  [[ $code -ne 0 ]] && bad=$((bad + 1))
fi
echo "logs: $LOGS"
if [[ $bad -eq 0 ]]; then echo "[labs] PASS rows=$total"; exit 0; fi
echo "[labs] FAIL $bad/$total rows"; exit 1
