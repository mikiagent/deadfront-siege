#!/usr/bin/env bash
# Milestone gate for CARD2D round 2 (under 2 min): t_card2d passes with no SCRIPT ERROR. The full verify runs at the end.
cd /Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-card2d || exit 1
L=/tmp/card2d_ms_t.log
/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 300; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/t_card2d.gd > "$L" 2>&1
grep -q "PASS" "$L" && ! grep -q "SCRIPT ERROR" "$L" && { echo "MILESTONE GATE PASS (milestone $1)"; exit 0; }
echo "MILESTONE GATE FAIL: t_card2d (see $L)"; tail -15 "$L"; exit 1
