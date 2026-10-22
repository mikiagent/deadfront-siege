#!/usr/bin/env bash
# Headless boot check for the Godot project. Exit 0 = the main scene loaded,
# the player exists and is standing on the floor after 2 s.
# Usage: tools/smoke.sh            (import + run)
#        tools/smoke.sh --no-import
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$($ROOT/tools/find_godot.sh)"
# Godot keeps user:// and its log book under $HOME/Library/Application Support; a sandbox that lets the
# project be written but not $HOME makes the engine segfault at startup before it prints anything.
# Point HOME at a scratch dir in that case, exactly as gslot.sh does. The check itself is unchanged.
if ! ( : > "$HOME/Library/Application Support/.smoke-probe" ) 2>/dev/null; then
  export HOME="${TMPDIR:-/tmp}/deadfront-smoke-home"
  mkdir -p "$HOME/Library/Application Support"
fi
rm -f "$HOME/Library/Application Support/.smoke-probe" 2>/dev/null
if [[ "${1:-}" != "--no-import" ]]; then
  perl -e 'alarm 180; exec @ARGV' "$G" --headless --path "$ROOT/game" --import >/dev/null 2>&1
fi
out="$(perl -e 'alarm 90; exec @ARGV' "$G" --headless --path "$ROOT/game" -- --smoke 2>&1)"
code=$?
echo "$out" | grep -E '^\[(boot|smoke)\]|ERROR|SCRIPT ERROR|Parse Error' 
if echo "$out" | grep -q '^\[smoke\] ok' && [[ $code -eq 0 ]]; then echo "SMOKE PASS"; exit 0; fi
echo "SMOKE FAIL (exit $code)"; exit 1
