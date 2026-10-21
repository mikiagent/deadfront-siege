#!/usr/bin/env bash
# Read-only verify for ISLANDGEN (light: the job's own test, lab and smoke; full gates run at merge).
set -u
W=/Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-islandgen; G=/Applications/Godot_mono.app/Contents/MacOS/Godot; GS=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh; OUT=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/islandgen-out
mkdir -p "$OUT"; cd "$W" || exit 1
fail() { echo "VERIFY FAIL: $*"; exit 1; }
[ -f docs/orchestration/reports/dsc-islandgen.md ] || fail "report missing"
$GS perl -e 'alarm 900; exec @ARGV' $G --headless --path game --import > "$OUT/import.log" 2>&1
$GS perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/t_islandgen.gd > "$OUT/t_islandgen.log" 2>&1
grep -q "\[t_islandgen\] PASS" "$OUT/t_islandgen.log" && ! grep -q "SCRIPT ERROR" "$OUT/t_islandgen.log" || fail "t_islandgen did not PASS cleanly (see $OUT/t_islandgen.log)"
$GS perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/t_save.gd > "$OUT/t_save.log" 2>&1
grep -q "\[t_save\] PASS" "$OUT/t_save.log" || fail "t_save did not PASS (it prints 5 deliberate SCRIPT ERRORs; only PASS counts) (see $OUT/t_save.log)"
$GS perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/t_harbour.gd > "$OUT/t_harbour.log" 2>&1
grep -q "\[t_harbour\] PASS" "$OUT/t_harbour.log" && ! grep -q "SCRIPT ERROR" "$OUT/t_harbour.log" || fail "t_harbour did not PASS cleanly (see $OUT/t_harbour.log)"
$GS perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/t_water.gd > "$OUT/t_water.log" 2>&1
grep -q "\[t_water\] PASS" "$OUT/t_water.log" && ! grep -q "SCRIPT ERROR" "$OUT/t_water.log" || fail "t_water did not PASS cleanly (see $OUT/t_water.log)"
rm -rf "$OUT/shots"; mkdir -p "$OUT/shots"
$GS perl -e 'alarm 900; exec @ARGV' $G --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=islandgen_lab --shot-dir="$OUT/shots" > "$OUT/islandgen_lab.log" 2>&1
grep -q "\[islandgen\]" "$OUT/islandgen_lab.log" || fail "islandgen_lab printed no [islandgen] lines"
grep -q "SCRIPT ERROR" "$OUT/islandgen_lab.log" && fail "SCRIPT ERROR in islandgen_lab"
[ "$(ls "$OUT/shots"/*.png 2>/dev/null | wc -l)" -ge 15 ] || fail "fewer than 15 shots in $OUT/shots"
n=$(grep -c "\[islandgen\] id=" "$OUT/islandgen_lab.log"); [ "$n" -ge 15 ] || fail "islandgen_lab measured $n islands, need 15"
python3 - "$OUT/islandgen_lab.log" <<'PY' || fail "island numbers out of range"
import re,sys
rows=[dict(re.findall(r'(\w+)=([^ ]+)', l)) for l in open(sys.argv[1]) if '[islandgen] id=' in l]
bad=[]
for r in rows:
  if int(r.get('peninsulas',0))<2: bad.append(r['id']+' peninsulas')
  if not (0.55<=float(r.get('aspect',0))<=0.9): bad.append(r['id']+' aspect')
  if int(r.get('cliff_cells',0))<1: bad.append(r['id']+' no cliffs')
home=[r for r in rows if r['id']=='home_grassland']
if not home or float(home[0]['land'])<60000: bad.append('home too small')
print(bad); sys.exit(1 if bad else 0)
PY
bash tools/smoke.sh --no-import > "$OUT/smoke.log" 2>&1; grep -q "SMOKE PASS" "$OUT/smoke.log" || fail "smoke did not pass"
echo "VERIFY PASS"
