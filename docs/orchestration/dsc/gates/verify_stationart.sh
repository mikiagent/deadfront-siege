#!/usr/bin/env bash
# verify_stationart.sh [1|m1|m2|m3]: STATIONART gate, run from the work tree. 1 = the GLBs and their budgets; no argument = + manifest,
# contact sheet, report, scope and a Godot import with 0 errors on the new files.
T=$(git rev-parse --show-toplevel); cd "$T" || exit 1
S=${1:-3}
fail() { echo "VERIFY FAIL: $*"; exit 1; }
M1="makeshift_workbench basic_workbench journeyman_workbench expert_workbench"
M2="$M1 kiln loom large_loom oven large_drying_rack"
NAMES="$M2 site_small_0 site_small_1 site_small_2 site_large_0 site_large_1 site_large_2"
# Milestone gates: "m1" checks the workbench tiers, "m2" adds the stations, anything else (m3, 1) checks all 15.
case "$S" in m1) NAMES=$M1; S=1;; m2) NAMES=$M2; S=1;; m*) S=1;; esac
python3 - $NAMES <<'PY' || exit 1
import json, struct, sys, os
bad = []
for n in sys.argv[1:]:
    p = f"game/assets/props/blender/{n}.glb"
    if not os.path.isfile(p):
        bad.append(f"{p} missing"); continue
    b = open(p, "rb").read()
    if b[:4] != b"glTF": bad.append(f"{p} is not a GLB"); continue
    ln = struct.unpack("<I", b[12:16])[0]; g = json.loads(b[20:20 + ln])
    tris = 0; ymin = 1e9
    for m in g.get("meshes", []):
        for pr in m["primitives"]:
            if "indices" in pr: tris += g["accessors"][pr["indices"]]["count"] // 3
            else: tris += g["accessors"][pr["attributes"]["POSITION"]]["count"] // 3
            acc = g["accessors"][pr["attributes"]["POSITION"]]
            if "min" in acc: ymin = min(ymin, acc["min"][1])
    mats = len(g.get("materials", []))
    if not (36 <= tris <= 2500): bad.append(f"{n}: {tris} tris (36..2500)")
    if mats > 2: bad.append(f"{n}: {mats} materials (use the shared atlas; at most 2)")
    if ymin < -0.05 or ymin > 0.25: bad.append(f"{n}: lowest vertex y={ymin:.2f} (origin must sit at the ground)")
    print(f"[stationart] {n} tris={tris} mats={mats} ymin={ymin:.2f}")
for x in bad: print("VERIFY FAIL:", x)
sys.exit(1 if bad else 0)
PY
[ "$S" -lt 3 ] && { echo "VERIFY STAGE 1 PASS"; exit 0; }
python3 -c "
import json,sys
m=json.load(open('game/data/props_manifest.json')); s=json.dumps(m)
miss=[n for n in sys.argv[1:] if n+'.glb' not in s]
print('manifest missing:',miss) if miss else None; sys.exit(1 if miss else 0)" $NAMES || fail "props_manifest.json lacks rows for the new models (run tools/blender/structures/check_manifest.py)"
[ "$(stat -f %z docs/orchestration/reports/dsc-stationart-sheet.png 2>/dev/null || echo 0)" -gt 50000 ] || fail "contact sheet docs/orchestration/reports/dsc-stationart-sheet.png missing or tiny"
[ -s docs/orchestration/reports/dsc-stationart.md ] || fail "report missing"
base=$(git merge-base HEAD claude/mmo-overhaul)
bad=$( { git diff --name-only "$base"; git ls-files --others --exclude-standard; } | sort -u | grep -vE '\.(import|uid)$|_Image_[0-9]+\.jpg$|^game/assets/props/meshy/' | grep -vE '^(tools/blender/structures/|game/assets/props/blender/|game/data/props_manifest\.json$|docs/orchestration/)')
[ -z "$bad" ] || fail "files outside your scope: $(echo $bad | head -c 300)"
G=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
"$G" perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/stationart_import.log 2>&1
n=$(grep -E "ERROR" /tmp/stationart_import.log | grep -ciE "props/blender/($(echo $NAMES | tr ' ' '|'))")
[ "$n" -eq 0 ] || fail "Godot import: $n errors on the new models (see /tmp/stationart_import.log)"
echo "VERIFY PASS"
