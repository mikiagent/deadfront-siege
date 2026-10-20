#!/bin/zsh
# Gate for the dsc icons2 task. ./tools/dsc/verify_icons2.sh [--fast] [--stage missing|flagged]
# --fast skips Blender re-render checks and Godot; the full run (no flags) is "done".
cd "$(dirname "$0")/../.." || exit 1
rc=0; SP=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad
G=/Applications/Godot_mono.app/Contents/MacOS/Godot; B=/Applications/Blender.app/Contents/MacOS/Blender
fast=0; stage=all; [[ "$1" == --fast ]] && { fast=1; shift; }; [[ "$1" == --stage ]] && stage=$2
python3 -I - $stage <<'PY' || rc=1
import json, hashlib, os, struct, sys
stage = sys.argv[1]
base = json.load(open("tools/dsc/icons2_base.json"))
m = json.load(open("game/assets/icons/render/manifest.json"))
items = m["items"]; bad = 0
def png_ok(path):
    b = open(path, "rb").read()
    if b[:8] != b"\x89PNG\r\n\x1a\n": return "not a PNG"
    w, h = struct.unpack(">II", b[16:24]); ct = b[25]
    if (w, h) != (256, 256) or ct != 6: return "want 256x256 RGBA, got %dx%d type %d" % (w, h, ct)
    if len(b) > 65536: return "%d bytes > 64 KB" % len(b)
    return ""
def check(ids, must_change):
    global bad
    for k in ids:
        e = items.get(k)
        if not isinstance(e, dict): print("FAIL %s has no render in the manifest" % k); bad += 1; continue
        p = "game/" + e["png"][len("res://"):]
        if not os.path.exists(p): print("FAIL %s png missing: %s" % (k, p)); bad += 1; continue
        err = png_ok(p)
        if err: print("FAIL %s %s" % (k, err)); bad += 1; continue
        sha = hashlib.sha256(open(p, "rb").read()).hexdigest()
        if sha != e.get("sha256"): print("FAIL %s manifest sha256 is stale" % k); bad += 1; continue
        if must_change and sha == must_change.get(k): print("FAIL %s flagged render unchanged" % k); bad += 1; continue
        print("PASS %s" % k)
if stage in ("all", "missing"):
    check(base["missing"], None)
    left = [k for k in m.get("missing", []) if k in base["missing"]]
    if left: print("FAIL manifest 'missing' still lists %s" % left); bad += 1
if stage in ("all", "flagged"):
    check(base["flagged"], base["flag_sha"])
for k, sha in base["keep_sha"].items():
    e = items.get(k)
    if not isinstance(e, dict) or e.get("sha256") != sha: print("FAIL %s was not flagged and must stay byte-identical" % k); bad += 1
sys.exit(1 if bad else 0)
PY
for f in $(git diff --name-only claude/mmo-overhaul; git ls-files --others --exclude-standard); do
  case $f in tools/blender/items/*|tools/render_icons.py|game/assets/icons/render/*|docs/orchestration/reports/dsc-icons2.md|work/*|tools/dsc/*|TASK.md) ;;
    *) echo "FAIL out of scope: $f"; rc=1;; esac
done
[[ -f work/sheets/all.png ]] || { echo "FAIL work/sheets/all.png contact sheet missing (tools/blender/items/contact_sheet.py)"; rc=1; }
(( fast )) && { (( rc == 0 )) && echo "VERIFY FAST PASS $stage"; exit $rc; }
ids=$(python3 -I -c "import json;b=json.load(open('tools/dsc/icons2_base.json'));print(','.join(b['missing']+b['flagged']))")
out=$($B -b --factory-startup -P tools/render_icons.py -- --verify $ids 2>&1 | grep -E "REPRO")
echo "$out" | grep -q "REPRO PASS" && echo "PASS re-render byte-identical" || { echo "$out" | tail -5; echo "FAIL --verify re-render"; rc=1; }
$SP/gslot.sh perl -e 'alarm 900; exec @ARGV' $G --headless --path game --import > /dev/null 2>&1 || { echo "FAIL import"; rc=1; }
for t in t_iconart run_all; do
  o=$($SP/gslot.sh perl -e 'alarm 500; exec @ARGV' $G --headless --path game --script res://tests/$t.gd 2>&1)
  echo "$o" | grep -qE "\[(t_iconart|tests)\] PASS" && echo "PASS $t" || { echo "$o" | grep -E "FAIL|SCRIPT ERROR" | head -10; echo "FAIL $t"; rc=1; }
done
[[ -f docs/orchestration/reports/dsc-icons2.md ]] || { echo "FAIL report missing"; rc=1; }
(( rc == 0 )) && echo "VERIFY PASS"
exit $rc
