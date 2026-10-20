#!/usr/bin/env bash
# Read-only gate for the ragdoll profile task (TASK.md). Exit 0 only when every check holds.
# Usage: ./verify_ragdoll.sh            all 11 species x flat/slope/rock (the real gate)
#        ./verify_ragdoll.sh a,b        only those species (a quick milestone check, not the gate)
set -u
cd "$(dirname "$0")"
G=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
GD=/Applications/Godot_mono.app/Contents/MacOS/Godot
BASE=abd7f58e
J=game/data/creatures/ragdoll.json
ALL=coelophysis,compsognathus,deinonychus,gallimimus,megaloceros,protoceratops,stegosaurus,tyrannosaurus,utahraptor,velociraptor,zebraceratops
SPECIES=${1:-$ALL}
OUT=$(mktemp -d /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/ragverify.XXXX)
fail=0
bad() { echo "VERIFY FAIL: $*"; fail=1; }

# 1. Only the profile file changed since the base (committed or not).
changed=$( { git diff --name-only $BASE; git diff --name-only --cached; git ls-files --others --exclude-standard; } | sort -u \
  | grep -v -x -e "$J" -e TASK.md -e verify_ragdoll.sh -e .dsc.json -e REPORT.md )
[[ -z "$changed" ]] || bad "files other than $J changed: $(echo $changed)"

# 2. Valid JSON, the shared sections untouched, every species profiled with hips, feet and <= 16 bodies.
python3 -I - "$J" "$BASE" "$ALL" <<'PY' || bad "profile file checks failed (see above)"
import json, subprocess, sys
path, base, allsp = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
now = json.load(open(path))
old = json.loads(subprocess.check_output(["git", "show", f"{base}:game/data/creatures/ragdoll.json"]))
ok = True
for k in old:
    if k != "species" and now.get(k) != old[k]:
        print(f"shared section '{k}' changed"); ok = False
for k in now:
    if k not in old:
        print(f"new top-level key '{k}'"); ok = False
sp = now.get("species", {})
for s in allsp:
    p = sp.get(s)
    if not isinstance(p, dict):
        print(f"no profile for {s}"); ok = False; continue
    if not p.get("hips") or not p.get("feet"):
        print(f"{s}: hips and feet are required"); ok = False
    n = len(p.get("bodies", []))
    if n < 6 or n > 16:
        print(f"{s}: {n} bodies (want 6-16)"); ok = False
sys.exit(0 if ok else 1)
PY

# 3. The lab: every case must pass (settle, skin contact, lying down, no raised limb, no stretch, no NaN,
#    peak speed, joint limits, frozen corpse costs nothing, corpse placed with loot).
"$G" perl -e 'alarm 1500; exec @ARGV' "$GD" --headless --fixed-fps 60 --path game -- --lab=ragdoll_lab --rl-species=$SPECIES > "$OUT/lab.log" 2>&1
rc=$?
grep -E '^\[ragdoll_lab\] (ok  |FAIL)' "$OUT/lab.log"
n=$(tr ',' '\n' <<<"$SPECIES" | grep -c .)
want=$((n * 3))
[[ $rc == 0 ]] || bad "ragdoll_lab exit $rc (log $OUT/lab.log)"
grep -qE "^\[ragdoll_lab\] PASS cases=$want ok=$want" "$OUT/lab.log" || bad "ragdoll_lab did not print PASS cases=$want ok=$want"
grep -qE 'SCRIPT ERROR|Parse Error' "$OUT/lab.log" && bad "script errors in the lab (log $OUT/lab.log)"

# 4. The ragdoll test still passes (budget, fallbacks, corpse loot and seam).
"$G" perl -e 'alarm 600; exec @ARGV' "$GD" --headless --fixed-fps 60 --path game --script res://tests/t_ragdoll.gd > "$OUT/t.log" 2>&1
grep -q '^\[t_ragdoll\] PASS' "$OUT/t.log" || bad "t_ragdoll did not PASS (log $OUT/t.log)"

# 5. No new Godot crash report.
newips=$(find ~/Library/Logs/DiagnosticReports -name 'Godot-*.ips' -newer "$OUT" 2>/dev/null | head -3)
[[ -z "$newips" ]] || bad "Godot crashed: $newips"

if [[ $fail == 0 ]]; then echo "VERIFY PASS species=$SPECIES (logs $OUT)"; exit 0; fi
exit 1
