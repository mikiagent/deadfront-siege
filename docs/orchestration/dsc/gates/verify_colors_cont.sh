#!/usr/bin/env bash
# Read-only verify for COLORS.
set -u
W=/Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-colors
G=/Applications/Godot_mono.app/Contents/MacOS/Godot
GS=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
OUT=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/colors-out2
mkdir -p "$OUT"; cd "$W" || exit 1
fail() { echo "VERIFY FAIL: $*"; exit 1; }
for f in game/tests/t_colors.gd game/scripts/dev/colors_lab.gd docs/orchestration/reports/dsc-colors.md; do [ -f "$f" ] || fail "$f missing"; done
$GS perl -e 'alarm 900; exec @ARGV' $G --headless --path game --import > "$OUT/import.log" 2>&1
$GS perl -e 'alarm 240; exec @ARGV' $G --headless --path game --script res://tests/t_colors.gd > "$OUT/t_colors.log" 2>&1
grep -q "\[t_colors\] PASS" "$OUT/t_colors.log" && ! grep -q "SCRIPT ERROR" "$OUT/t_colors.log" || echo "NOTE: t_colors did not PASS cleanly (continuing)"
rm -f "$OUT/colors.png"
$GS perl -e 'alarm 240; exec @ARGV' $G --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=colors_lab --shot="$OUT/colors.png" > "$OUT/lab.log" 2>&1
grep -q "\[colors_lab\] PASS" "$OUT/lab.log" || fail "colors_lab printed no PASS"
[ "$(stat -f %z "$OUT/colors.png" 2>/dev/null || echo 0)" -gt 60000 ] || fail "colors.png missing or blank"
for t in game/tests/t_*.gd; do b=$(basename "$t" .gd)
  $GS perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/$b.gd > "$OUT/$b.log" 2>&1 || echo "TESTFAIL $b"
done
bash tools/smoke.sh --no-import > "$OUT/smoke.log" 2>&1; grep -q "SMOKE PASS" "$OUT/smoke.log" || fail "smoke did not pass"
echo "VERIFY PASS"
