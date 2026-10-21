#!/usr/bin/env bash
# verify_eyeglow.sh [1|2]: EYEGLOW gate, run from the work tree. 1 = t_eyeglow; 2 = + windowed lab numbers and shots;
# no argument = full gate (+ related tests, smoke, report, scope).
T=$(git rev-parse --show-toplevel); cd "$T" || exit 1
S=${1:-3}
G=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
GD=/Applications/Godot_mono.app/Contents/MacOS/Godot
OUT=/tmp/eyeglow_verify; mkdir -p "$OUT"
fail() { echo "VERIFY FAIL: $*"; exit 1; }
GLOW="tyrannosaurus utahraptor deinonychus velociraptor coelophysis compsognathus"
for s in $GLOW; do
  python3 -c "import json,sys;e=json.load(open('game/data/creatures/$s.json')).get('eyes');sys.exit(0 if isinstance(e,dict) and e.get('bone') and e.get('color') else 1)" \
    || fail "game/data/creatures/$s.json has no eyes block with bone and color"
done
"$G" perl -e 'alarm 400; exec @ARGV' "$GD" --headless --path game --script res://tests/t_eyeglow.gd > "$OUT/t_eyeglow.log" 2>&1
grep -q "\[t_eyeglow\] PASS" "$OUT/t_eyeglow.log" && ! grep -q "SCRIPT ERROR" "$OUT/t_eyeglow.log" || fail "t_eyeglow did not PASS cleanly (see $OUT/t_eyeglow.log)"
[ "$S" -lt 2 ] && { echo "VERIFY STAGE 1 PASS"; exit 0; }
rm -rf "$OUT/shots"; mkdir -p "$OUT/shots"
"$G" perl -e 'alarm 500; exec @ARGV' "$GD" --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=eyeglow_lab --shot-dir="$OUT/shots" > "$OUT/lab.log" 2>&1
grep -qE "SCRIPT ERROR|SHADER ERROR|Unknown character" "$OUT/lab.log" && fail "SCRIPT or SHADER ERROR in eyeglow_lab (see $OUT/lab.log)"
grep -q "\[eyeglow\] PASS" "$OUT/lab.log" || fail "eyeglow_lab printed no PASS (see $OUT/lab.log)"
for s in $GLOW; do
  L=$(grep "\[eyeglow\] $s " "$OUT/lab.log" | tail -1)
  [ -n "$L" ] || fail "lab has no line for $s"
  python3 - "$L" <<'PY' || fail "$s eye brightness out of range: $L"
import re, sys
l = sys.argv[1]
n = float(re.search(r"night_peak=([0-9.]+)", l).group(1)); d = float(re.search(r"day_peak=([0-9.]+)", l).group(1))
bg = float(re.search(r"night_head=([0-9.]+)", l).group(1))
sys.exit(0 if n >= 0.6 and n >= bg + 0.3 and d <= 0.6 * n else 1)
PY
  for v in night_side day_side night_game; do [ -s "$OUT/shots/${s}_$v.png" ] || fail "missing shot ${s}_$v.png"; done
done
grep -q "\[eyeglow\] none " "$OUT/lab.log" || fail "lab must also show a species without eyes (e.g. zebraceratops) and print '[eyeglow] none <id>'"
[ "$S" -lt 3 ] && { echo "VERIFY STAGE 2 PASS"; exit 0; }
[ -s docs/orchestration/reports/dsc-eyeglow.md ] || fail "report docs/orchestration/reports/dsc-eyeglow.md missing"
base=$(git merge-base HEAD claude/mmo-overhaul)
bad=$(git diff --name-only "$base" | grep -vE '^(game/scripts/creatures/creature_eyes\.gd(\.uid)?|game/scripts/creatures/creature_view\.gd|game/scripts/world/world_lighting\.gd|game/data/creatures/[a-z]+\.json|game/shaders/eye_glow\.gdshader|game/tests/t_eyeglow\.gd(\.uid)?|game/scripts/dev/eyeglow_lab\.gd(\.uid)?|game/scenes/dev/eyeglow_lab\.tscn|docs/orchestration/reports/dsc-eyeglow.*|docs/orchestration/dsc/eyeglow-TASK\.md)$')
[ -z "$bad" ] || fail "files outside your scope changed: $(echo $bad | head -c 400)"
for t in t_lighting t_mounts t_canim; do
  "$G" perl -e 'alarm 600; exec @ARGV' "$GD" --headless --path game --script res://tests/$t.gd > "$OUT/$t.log" 2>&1 || fail "$t failed (see $OUT/$t.log)"
done
"$G" perl -e 'alarm 900; exec @ARGV' bash tools/smoke.sh --no-import > "$OUT/smoke.log" 2>&1; grep -q "SMOKE PASS" "$OUT/smoke.log" || fail "smoke did not pass"
echo "VERIFY PASS"
