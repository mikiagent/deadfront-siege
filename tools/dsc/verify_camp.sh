#!/bin/zsh
# Gate for the dsc camp-pieces task. ./tools/dsc/verify_camp.sh [--fast]
# --fast skips Godot (milestones); the full run is "done".
cd "$(dirname "$0")/../.." || exit 1
rc=0; SP=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad
G=/Applications/Godot_mono.app/Contents/MacOS/Godot
KINDS=(campfire_stand technical_workbench grindstone tent_canvas bedroll large_box chest barrel bucket fence_fortified signpost fishing_stand field_small field_large stone_grill straw_roll log_shelter cabin_bed)
# 1. Every kind has its own Blender GLB, mapped in KIND_GLB, with a manifest row that check_manifest wrote.
python3 -I - ${KINDS[@]} <<'PY' || rc=1
import json, os, sys, importlib.util
spec = importlib.util.spec_from_file_location("cm", "tools/blender/structures/check_manifest.py")
cm = importlib.util.module_from_spec(spec); kinds = sys.argv[1:]; sys.argv = ["check_manifest"]; spec.loader.exec_module(cm)
rows = json.load(open("game/data/props_manifest.json"))["buildings"]
bad = 0; seen = {}
for k in kinds:
    g = cm.KIND_GLB.get(k)
    row = rows.get(k, {})
    path = "game/assets/props/blender/%s.glb" % g if g else ""
    if not g: print("FAIL %s not in KIND_GLB" % k); bad += 1; continue
    if not os.path.exists(path): print("FAIL %s: %s missing (run build.py)" % (k, path)); bad += 1; continue
    if row.get("glb") != "res://assets/props/blender/%s.glb" % g or not row.get("aabb_m"): print("FAIL %s manifest row has no glb/aabb_m (run check_manifest.py --write)" % k); bad += 1; continue
    if row.get("art_status") == "REPLACE": print("FAIL %s still art_status REPLACE" % k); bad += 1; continue
    seen.setdefault(g, []).append(k)
    print("PASS %s -> %s" % (k, g))
# Each kind gets its own model unless two kinds are genuinely the same object (allowed: none in this list).
dup = {g: ks for g, ks in seen.items() if len(ks) > 1}
if dup: print("FAIL kinds share one GLB: %s (each kind needs its own model)" % dup); bad += 1
sys.exit(1 if bad else 0)
PY
# 2. The manifest checker (tris <= 4000, one atlas material, no embedded image, origin, footprint, aabb).
python3 -I tools/blender/structures/check_manifest.py > /tmp/camp_cm.$$ 2>&1 || { grep FAIL /tmp/camp_cm.$$ | head -20; echo "FAIL check_manifest"; rc=1; }; rm -f /tmp/camp_cm.$$
# 3. The shared atlas and the 24 merged models must not change (other kinds and the whole camp use them).
[[ "$(shasum -a 256 game/assets/props/blender/structures_atlas.png | cut -d' ' -f1)" == 37cf68797f74e39e1adc8b69b384d13ae9a3d7b306b9ed8ab0c9d5589f9f9440 ]] || { echo "FAIL structures_atlas.png changed: use the existing tiles (lib.TILES)"; rc=1; }
(cd game/assets/props/blender && shasum -a 256 -c ../../../../tools/dsc/camp_base_glbs.sha256 --quiet) || { echo "FAIL an existing GLB changed"; rc=1; }
# 4. Scope: only the builder, the new GLBs, the manifest, the report and the preview sheets.
for f in $(git diff --name-only claude/mmo-overhaul; git ls-files --others --exclude-standard); do
  case $f in tools/blender/structures/*.py|game/assets/props/blender/*|game/data/props_manifest.json|docs/orchestration/reports/dsc-camp-pieces.md|work/*|tools/dsc/*|TASK.md|.dsc.json) ;;
    game/scripts/world/prop_visuals.gd) ;;  # brief: ensure_foundation skips the disc for the fields
    *.import|*.uid) ;;
    *) echo "FAIL out of scope: $f"; rc=1;; esac
done
# 5. A preview sheet per kind, rendered with tools/blender/structures/preview.py.
for k in $KINDS; do [[ -f work/sheets/$k.png ]] || { echo "FAIL work/sheets/$k.png missing (preview.py)"; rc=1; }; done
[[ "$1" == --fast ]] && { (( rc == 0 )) && echo "VERIFY FAST PASS"; exit $rc; }
# 6. Godot: import the new GLBs, then the structure, build and full suites, the build lab and smoke.
$SP/gslot.sh perl -e 'alarm 900; exec @ARGV' $G --headless --path game --import > /tmp/camp_imp.$$ 2>&1 || { echo "FAIL import"; rc=1; }
for t in t_structart t_build run_all; do
  out=$($SP/gslot.sh perl -e 'alarm 500; exec @ARGV' $G --headless --path game --script res://tests/$t.gd 2>&1)
  echo "$out" | grep -qE "\[(t_structart|t_build|tests)\] PASS" && echo "PASS $t" || { echo "$out" | grep -E "FAIL|SCRIPT ERROR" | head -10; echo "FAIL $t"; rc=1; }
done
out=$($SP/gslot.sh perl -e 'alarm 400; exec @ARGV' $G --headless --path game -- --lab=build_lab 2>&1)
echo "$out" | grep -q "\[build\] PASS" && ! echo "$out" | grep -q "SCRIPT ERROR" && echo "PASS build_lab" || { echo "FAIL build_lab"; rc=1; }
$SP/gslot.sh perl -e 'alarm 400; exec @ARGV' tools/smoke.sh --no-import 2>&1 | grep -q "SMOKE PASS" && echo "PASS smoke" || { echo "FAIL smoke"; rc=1; }
[[ -f docs/orchestration/reports/dsc-camp-pieces.md ]] || { echo "FAIL report missing"; rc=1; }
rm -f /tmp/camp_imp.$$
(( rc == 0 )) && echo "VERIFY PASS"
exit $rc
