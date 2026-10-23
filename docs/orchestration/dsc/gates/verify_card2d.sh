#!/usr/bin/env bash
# Read-only verify for the CARD2D dsc task. Exit 0 only when every check passes.
set -u
W=/Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-card2d
G=/Applications/Godot_mono.app/Contents/MacOS/Godot
GS=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
OUT=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/card2d-out
mkdir -p "$OUT"; cd "$W" || exit 1
fail() { echo "VERIFY FAIL: $*"; exit 1; }
[ -f game/data/card2d.json ] || fail "game/data/card2d.json missing"
[ -s docs/orchestration/reports/dsc-card2d.md ] || fail "report docs/orchestration/reports/dsc-card2d.md missing"
base=$(git merge-base HEAD claude/mmo-overhaul)
git diff --quiet "$base" -- game/scripts/camera/iso_camera.gd || fail "iso_camera.gd changed (claude/mmo-camera owns it; revert it)"
bad=$(git diff --name-only "$base" | grep -E '^game/assets/props/meshy/'); [ -z "$bad" ] || fail "junk in the diff (drop it): $(echo $bad | head -c 300)"
grep -q "parallax" game/tests/t_card2d.gd && grep -qi "empty" game/tests/t_card2d.gd && grep -qi "fade\|occlu" game/tests/t_card2d.gd || fail "t_card2d lacks the parallax-bound, empty-card or fade asserts"
n=$(python3 -c "import json;print(len(json.load(open('game/data/card2d.json')).get('cards',json.load(open('game/data/card2d.json')))))" 2>/dev/null || echo 0)
[ "${n:-0}" -ge 8 ] || fail "card2d.json lists fewer than 8 cards ($n)"
ls game/assets/nature/cards/*_albedo.png >/dev/null 2>&1 || fail "no baked albedo cards"
ls game/assets/nature/cards/*_normal.png >/dev/null 2>&1 || fail "no baked normal cards"
for f in game/shaders/card_sway.gdshader game/scripts/world/card_prop.gd game/scripts/dev/card2d_lab.gd game/tests/t_card2d.gd; do [ -f "$f" ] || fail "$f missing"; done
grep -q '"resource_render"' game/data/world/rules.json || fail "rules.json has no resource_render key"
python3 -c "import json,sys;sys.exit(0 if json.load(open('game/data/world/rules.json')).get('resource_render')=='model' else 1)" || fail "resource_render default must stay \"model\""
$GS perl -e 'alarm 900; exec @ARGV' $G --headless --path game --import > "$OUT/import.log" 2>&1
$GS perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/t_card2d.gd > "$OUT/t_card2d.log" 2>&1
grep -q "PASS" "$OUT/t_card2d.log" && ! grep -q "SCRIPT ERROR" "$OUT/t_card2d.log" || fail "t_card2d did not PASS cleanly (see $OUT/t_card2d.log)"
rm -f "$OUT"/split_1600.png "$OUT"/cards_844.png; rm -rf "$OUT/frames"
$GS perl -e 'alarm 300; exec @ARGV' $G --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=card2d_lab --mode=split --shot="$OUT/split_1600.png" --frames="$OUT/frames" > "$OUT/lab1600.log" 2>&1
grep -q "\[card2d\] PASS" "$OUT/lab1600.log" || fail "card2d_lab printed no PASS line (see $OUT/lab1600.log)"
L=$(grep "\[card2d\] PASS" "$OUT/lab1600.log" | tail -1)
c=$(python3 -c "import re,sys;m=re.search(r'\bcards=(\d+)',sys.argv[1]);print(m.group(1) if m else 0)" "$L"); m=$(python3 -c "import re,sys;m=re.search(r'\bmodels=(\d+)',sys.argv[1]);print(m.group(1) if m else 0)" "$L")
[ "${c:-0}" -gt 0 ] && [ "$c" = "$m" ] || fail "lab must place the same number of cards and models (cards=$c models=$m)"
python3 -c "import re,sys;l=sys.argv[1];a=float(re.search(r'ms_cards=([0-9.]+)',l).group(1));b=float(re.search(r'ms_models=([0-9.]+)',l).group(1));sys.exit(0 if a<b else 1)" "$L" || fail "cards are not cheaper than models: $L"
grep -qE "SCRIPT ERROR|SHADER ERROR|Unknown character" "$OUT/lab1600.log" && fail "SCRIPT or SHADER ERROR in card2d_lab"
[ "$(stat -f %z "$OUT/split_1600.png" 2>/dev/null || echo 0)" -gt 60000 ] || fail "split_1600.png missing or blank"
[ "$(ls "$OUT/frames"/*.png 2>/dev/null | wc -l)" -ge 20 ] || fail "fewer than 20 sway frames in $OUT/frames"
$GS perl -e 'alarm 300; exec @ARGV' $G --path game --resolution 844x390 --rendering-method gl_compatibility -- --lab=card2d_lab --mode=cards --shot="$OUT/cards_844.png" > "$OUT/lab844.log" 2>&1
grep -q "\[card2d\] PASS" "$OUT/lab844.log" || fail "card2d_lab at 844x390 printed no PASS line"
[ "$(stat -f %z "$OUT/cards_844.png" 2>/dev/null || echo 0)" -gt 30000 ] || fail "cards_844.png missing or blank"
for t in game/tests/t_*.gd; do b=$(basename "$t" .gd)
  $GS perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/$b.gd > "$OUT/$b.log" 2>&1 || fail "$b exited non-zero (see $OUT/$b.log)"
done
bash tools/smoke.sh --no-import > "$OUT/smoke.log" 2>&1; grep -q "SMOKE PASS" "$OUT/smoke.log" || fail "smoke did not pass"
echo "VERIFY PASS: $(grep '\[card2d\] PASS' "$OUT/lab1600.log" | tail -1)"
