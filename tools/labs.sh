#!/usr/bin/env bash
# Lab gate: runs every row of tools/labs.txt headless with its timeout and prints one table row
# per lab (headless, or windowed for rows flagged "window"). A row PASSes only with exit 0, a "] PASS" line and no "] FAIL" / "] PARTIAL" /
# 'SCRIPT ERROR' / 'Parse Error' line. Exit 1 if any row fails. Every row gets a throwaway HOME,
# so no lab reads another lab's save (run order cannot matter) and none touches a real save.
# NOISE counts engine WARNING lines. Engine ERROR lines are gated: a row fails on more of them
# than its "errors:N" flag allows (default 0, the baseline measured on 2026-10-19).
#
# Usage: tools/labs.sh [name-filter]              headless gate, logs in $LABS_LOG_DIR (or a temp dir)
#        tools/labs.sh --shots DIR [name-filter]  rows flagged "shot": windowed web renderer
#            (gl_compatibility, 1600x900) still into DIR/<name>.png, then an exposure check
#            (black, blank or blown frames fail; so does a shot run that exits non-zero or logs a
#            SCRIPT ERROR). Needs a display (xvfb-run on Linux CI). Silent.
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
  # Subshell with stderr dropped: bash's "Alarm clock" job notice on a timeout stays out of the table.
  # LABS_LOG_DIR: LabResult.capture_path writes windowed stills there, so they outlive the HOME.
  ( HOME="$h" XDG_DATA_HOME="$h/.local/share" XDG_CONFIG_HOME="$h/.config" LABS_LOG_DIR="$LOGS" \
    perl -e "alarm $secs; exec @ARGV" "$G" "$@" > "$log" 2>&1 < /dev/null; exit $? ) 2>/dev/null
  local code=$?
  rm -rf "$h"
  return $code
}

bad=0; total=0; gated=(); known=()
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
    crash="$(grep -m1 -E 'SCRIPT ERROR|Parse Error' "$LOGS/$name.shot.log")"
    if [[ ! -s "$shots/$name.png" ]]; then r=FAIL; d="no still (exit $code)"; bad=$((bad + 1))
    elif [[ $code -ne 0 || -n "$crash" ]]; then r=FAIL; d="exit $code${crash:+; ${crash:0:90}}"; bad=$((bad + 1))
    else r=SHOT; d="$shots/$name.png"; fi
    if [[ "$r" == SHOT ]]; then
      if [[ "$flags" =~ \ shotxfail:([^ ]+)\  ]]; then known+=("$name:${BASH_REMATCH[1]}"); else gated+=("$shots/$name.png"); fi
    fi
    printf '%-24s %-6s %5d %5s  %s\n' "$name" "$r" $((SECONDS - t0)) - "$d"
    continue
  fi
  total=$((total + 1))
  log="$LOGS/$name.log"
  t0=$SECONDS
  mode="--headless"
  # "window" rows need a real viewport (desktop mouse picking); silent, so still gate-safe.
  [[ "$flags" == *" window "* ]] && mode="--audio-driver Dummy --resolution 1600x900"
  # shellcheck disable=SC2086
  run_godot "$secs" "$log" $mode --path "$ROOT/game" $args
  code=$?
  took=$((SECONDS - t0))
  why=""
  grep -qE '\] PASS' "$log" || why="no PASS line"
  hit="$(grep -m1 -E '\] (FAIL|PARTIAL)|SCRIPT ERROR|Parse Error' "$log")" && why="$hit"
  crash="$(grep -m1 -E 'SCRIPT ERROR|Parse Error' "$log")"
  if [[ $code -eq 142 ]]; then why="timeout ${secs}s${why:+; $why}"
  elif [[ $code -ne 0 ]]; then why="exit $code${why:+; $why}"; fi
  noise="$(grep -cE '^ *(USER )?WARNING:' "$log")"
  errs="$(grep -cE '^ *(USER )?ERROR:' "$log")"
  allowed=0; [[ "$flags" =~ \ errors:([0-9]+)\  ]] && allowed="${BASH_REMATCH[1]}"
  [[ $errs -gt $allowed ]] && why="${why:+$why; }$errs engine ERROR lines (allowed $allowed): $(grep -m1 -E '^ *(USER )?ERROR:' "$log" | cut -c1-60)"
  xfail=""; [[ "$flags" =~ \ xfail:([^ ]+)\  ]] && xfail="${BASH_REMATCH[1]}"
  verdict="$(grep -E '\] (PASS|FAIL|PARTIAL)' "$log" | tail -1 | cut -c1-110)"
  own="$(grep -m1 -E '\] (FAIL|PARTIAL)' "$log")"
  if [[ -n "$xfail" ]]; then
    # Strict: an expected failure must be the lab's own FAIL/PARTIAL verdict line; a timeout, crash
    # or native abort without one fails the gate (same rule as tools/test.sh).
    if [[ -n "$why" && -z "$crash" && -n "$own" ]]; then r=XFAIL; d="$xfail owns it: ${why:0:100}"
    elif [[ -n "$why" ]]; then r=FAIL; d="no own FAIL/PARTIAL verdict: ${why:0:90}"; bad=$((bad + 1))
    else r=XPASS; d="passes now: drop xfail:$xfail from labs.txt"; bad=$((bad + 1)); fi
  elif [[ -n "$why" ]]; then r=FAIL; d="${why:0:110}"; bad=$((bad + 1))
  else r=PASS; d="$verdict"; fi
  printf '%-24s %-6s %5d %5s  %s\n' "$name" "$r" "$took" "$noise" "$d"
done < "$LIST"

if [[ ${#gated[@]} -gt 0 ]]; then
  run_godot 120 "$LOGS/shot_check.log" --headless --path "$ROOT/game" --script res://tests/t_qa.gd -- --shots "${gated[@]}"
  code=$?
  grep -E '^\[shot\]|SCRIPT ERROR' "$LOGS/shot_check.log"
  [[ $code -ne 0 ]] && bad=$((bad + 1))
fi
# Strict known-bad stills: each must still fail the exposure check (owner named in labs.txt).
for k in ${known[@]+"${known[@]}"}; do
  n="${k%%:*}"; owner="${k#*:}"
  run_godot 120 "$LOGS/shot_check.$n.log" --headless --path "$ROOT/game" --script res://tests/t_qa.gd -- --shots "$shots/$n.png"
  if [[ $? -ne 0 ]] && ! grep -q 'SCRIPT ERROR' "$LOGS/shot_check.$n.log"; then
    echo "[shot] XFAIL $n.png $owner owns it: $(grep -m1 '\] FAIL ' "$LOGS/shot_check.$n.log" | cut -c1-90)"
  else
    echo "[shot] XPASS $n.png passes now: drop shotxfail:$owner from labs.txt"; bad=$((bad + 1))
  fi
done
echo "logs: $LOGS"
if [[ $bad -eq 0 ]]; then echo "[labs] PASS rows=$total"; exit 0; fi
echo "[labs] FAIL $bad/$total rows"; exit 1
