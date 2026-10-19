#!/usr/bin/env bash
# Headless boot check. Two runs, both must be clean (exit 0, no 'SCRIPT ERROR' / 'Parse Error'):
#  1. the main scene with --smoke: the player exists and stands on the floor after 2 s;
#  2. island_lab: World.load_island builds the real temperate_25 island (the --smoke boot skips
#     World._boot, so run 1 alone never built a world) and prints "[island] PASS mm= nodes=
#     creatures= gathered=" with every count above zero.
# Each run gets a throwaway HOME, so smoke never reads or writes a real save.
# Usage: tools/smoke.sh            (import + run)
#        tools/smoke.sh --no-import
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$($ROOT/tools/find_godot.sh)" || exit 127
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME" XDG_DATA_HOME="$TMP_HOME/.local/share" XDG_CONFIG_HOME="$TMP_HOME/.config"
if [[ "${1:-}" != "--no-import" ]]; then
  perl -e 'alarm 400; exec @ARGV' "$G" --headless --path "$ROOT/game" --import >/dev/null 2>&1
fi
fail=""
check() {  # check <label> <pass-regex> <output> <exit-code>
  echo "$3" | grep -E '^\[(boot|smoke|island|world)\]|SCRIPT ERROR|Parse Error'
  local err; err="$(echo "$3" | grep -m1 -E 'SCRIPT ERROR|Parse Error')"
  if [[ -n "$err" ]]; then fail="$fail $1:script-error"
  elif ! echo "$3" | grep -qE "$2"; then fail="$fail $1:no-pass-line"
  elif [[ $4 -ne 0 ]]; then fail="$fail $1:exit-$4"; fi
}
out="$(perl -e 'alarm 90; exec @ARGV' "$G" --headless --path "$ROOT/game" -- --smoke 2>&1)"
check main '^\[smoke\] ok' "$out" $?
out="$(perl -e 'alarm 120; exec @ARGV' "$G" --headless --path "$ROOT/game" -- --lab=island_lab 2>&1)"
check island '^\[island\] PASS mm=[1-9][0-9]* nodes=[1-9][0-9]* creatures=[1-9][0-9]* gathered=[1-9]' "$out" $?
if [[ -z "$fail" ]]; then echo "SMOKE PASS"; exit 0; fi
echo "SMOKE FAIL ($fail )"; exit 1
