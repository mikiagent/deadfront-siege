#!/usr/bin/env bash
# verify_blender.sh <key> [m1|m2|1]: shared gate for headless-Blender model jobs; settings in blender_<key>.conf next to
# this script (M1, M2, NAMES, REPORT_SHEET). m1/m2 check the models due by that milestone; 1 checks all models; no
# stage = + props_manifest rows, contact sheet, report, scope and a Godot import with 0 errors on the new files.
K=$1; S=${2:-3}
D=$(cd "$(dirname "$0")" && pwd); . "$D/blender_$K.conf" || { echo "VERIFY FAIL: no blender_$K.conf"; exit 1; }
T=$(git rev-parse --show-toplevel); cd "$T" || exit 1
fail() { echo "VERIFY FAIL: $*"; exit 1; }
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
            tris += g["accessors"][pr["indices"]]["count"] // 3 if "indices" in pr else g["accessors"][pr["attributes"]["POSITION"]]["count"] // 3
            acc = g["accessors"][pr["attributes"]["POSITION"]]
            if "min" in acc: ymin = min(ymin, acc["min"][1])
    mats = len(g.get("materials", []))
    if not (36 <= tris <= 3000): bad.append(f"{n}: {tris} tris (36..3000)")
    if mats > 2: bad.append(f"{n}: {mats} materials (use the shared atlas; at most 2)")
    if ymin < -0.6 or ymin > 0.25: bad.append(f"{n}: lowest vertex y={ymin:.2f} (origin at the ground; foundations may sink at most 0.6 m)")
    print(f"[blender] {n} tris={tris} mats={mats} ymin={ymin:.2f}")
for x in bad: print("VERIFY FAIL:", x)
sys.exit(1 if bad else 0)
PY
[ "$S" -lt 3 ] && { echo "VERIFY STAGE 1 PASS"; exit 0; }
python3 -c "
import json,sys
s=json.dumps(json.load(open('game/data/props_manifest.json')))
miss=[n for n in sys.argv[1:] if n+'.glb' not in s]
print('manifest missing:',miss) if miss else None; sys.exit(1 if miss else 0)" $NAMES || fail "props_manifest.json lacks rows for the new models (run tools/blender/structures/check_manifest.py)"
[ "$(stat -f %z docs/orchestration/reports/dsc-$K-sheet.png 2>/dev/null || echo 0)" -gt 50000 ] || fail "contact sheet docs/orchestration/reports/dsc-$K-sheet.png missing or tiny"
[ -s docs/orchestration/reports/dsc-$K.md ] || fail "report docs/orchestration/reports/dsc-$K.md missing"
base=$(git merge-base HEAD claude/mmo-overhaul)
bad=$( { git diff --name-only "$base"; git ls-files --others --exclude-standard; } | sort -u | grep -vE '\.(import|uid)$|_Image_[0-9]+\.jpg$|^game/assets/props/meshy/' | grep -vE '^(tools/blender/structures/|game/assets/props/blender/|game/data/props_manifest\.json$|docs/orchestration/)')
[ -z "$bad" ] || fail "files outside your scope: $(echo $bad | head -c 300)"
G=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
"$G" perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/${K}_import.log 2>&1
n=$(grep -E "ERROR" /tmp/${K}_import.log | grep -ciE "props/blender/($(echo $NAMES | tr ' ' '|'))")
[ "$n" -eq 0 ] || fail "Godot import: $n errors on the new models (see /tmp/${K}_import.log)"
echo "VERIFY PASS"
