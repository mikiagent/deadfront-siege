#!/usr/bin/env bash
# Read-only verify for BIOMEASSETS.
set -u
W=/Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-biomeassets; G=/Applications/Godot_mono.app/Contents/MacOS/Godot; GS=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh; OUT=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/biomeassets-out
mkdir -p "$OUT"; cd "$W" || exit 1
fail() { echo "VERIFY FAIL: $*"; exit 1; }
[ -f docs/orchestration/reports/dsc-biomeassets.md ] || fail "report missing"
[ -f docs/orchestration/reports/dsc-biomeassets-sheet.png ] || fail "contact sheet missing"
n=$(ls game/assets/nature/biome/*.glb 2>/dev/null | wc -l | tr -d ' '); [ "$n" -ge 20 ] || fail "only $n GLBs (need 20+)"
python3 -c "import json,sys;d=json.load(open('game/data/world/biome_assets.json'));rows=d if isinstance(d,list) else d.get('assets',[]);sys.exit(0 if len(rows)>=20 and all('path' in r and 'collide' in r for r in rows) else 1)" || fail "biome_assets.json rows missing path/collide"
ls tools/blender/biome_props/*.py >/dev/null 2>&1 || fail "no Blender scripts committed"
$GS perl -e 'alarm 900; exec @ARGV' $G --headless --path game --import > "$OUT/import.log" 2>&1
grep -i "error" "$OUT/import.log" | grep -i "biome" && fail "import errors for biome assets"
echo "VERIFY PASS: $n GLBs"
