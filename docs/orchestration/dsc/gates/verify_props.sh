#!/usr/bin/env bash
# Read-only verify for PROPS (light: the job's own test, lab and smoke; full gates run at merge).
set -u
W=/Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-props; G=/Applications/Godot_mono.app/Contents/MacOS/Godot; GS=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh; OUT=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/props-out
mkdir -p "$OUT"; cd "$W" || exit 1
fail() { echo "VERIFY FAIL: $*"; exit 1; }
[ -f docs/orchestration/reports/dsc-props.md ] || fail "report missing"
$GS perl -e 'alarm 900; exec @ARGV' $G --headless --path game --import > "$OUT/import.log" 2>&1
$GS perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/t_props.gd > "$OUT/t_props.log" 2>&1
grep -q "\[t_props\] PASS" "$OUT/t_props.log" && ! grep -q "SCRIPT ERROR" "$OUT/t_props.log" || fail "t_props did not PASS cleanly (see $OUT/t_props.log)"
$GS perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/t_stepover.gd > "$OUT/t_stepover.log" 2>&1
grep -q "\[t_stepover\] PASS" "$OUT/t_stepover.log" && ! grep -q "SCRIPT ERROR" "$OUT/t_stepover.log" || fail "t_stepover did not PASS cleanly (see $OUT/t_stepover.log)"
rm -rf "$OUT/shots"; mkdir -p "$OUT/shots"
$GS perl -e 'alarm 900; exec @ARGV' $G --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=props_lab --shot-dir="$OUT/shots" > "$OUT/props_lab.log" 2>&1
grep -q "\[props\]" "$OUT/props_lab.log" || fail "props_lab printed no [props] lines"
grep -q "SCRIPT ERROR" "$OUT/props_lab.log" && fail "SCRIPT ERROR in props_lab"
[ "$(ls "$OUT/shots"/*.png 2>/dev/null | wc -l)" -ge 3 ] || fail "fewer than 3 shots in $OUT/shots"
bash tools/smoke.sh --no-import > "$OUT/smoke.log" 2>&1; grep -q "SMOKE PASS" "$OUT/smoke.log" || fail "smoke did not pass"
echo "VERIFY PASS"
