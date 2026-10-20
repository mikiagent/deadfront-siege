#!/usr/bin/env bash
# Read-only gate for the hit_react free-window check (TASK.md). Exit 0 only when every check holds.
set -u
cd "$(dirname "$0")"
G=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
GD=/Applications/Godot_mono.app/Contents/MacOS/Godot
BASE=c5c1158
EV=game/data/creatures/anim_events.json
T=game/tests/t_canim.gd
OUT=$(mktemp -d /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/hitwin.XXXX)
fail=0
bad() { echo "VERIFY FAIL: $*"; fail=1; }

# 1. Only t_canim.gd changed (committed or not) since the base.
changed=$( { git diff --name-only $BASE; git diff --name-only --cached; git ls-files --others --exclude-standard; } | sort -u \
  | grep -v -x -e "$T" -e TASK.md -e verify_hitwin.sh -e .dsc.json )
[[ -z "$changed" ]] || bad "files other than $T changed: $(echo $changed)"
git diff --quiet $BASE -- "$EV" || bad "$EV differs from the base"

# 2. The function exists, is called, and drives the real damage path and the real busy flag.
body=$(awk '/^func _test_hit_react_window\(\)/{f=1;print;next} f&&/^func /{f=0} f' "$T")
[[ -n "$body" ]] || bad "no func _test_hit_react_window() in $T"
awk '/^func _process/{f=1;next} f&&/^func /{f=0} f' "$T" | grep -q '_test_hit_react_window()' || bad "_process does not call _test_hit_react_window()"
for need in '_on_damaged(' '_stagger_immune_until' 'is_busy()' 'stagger_left' 'tree.advance(' 'clip_speed(&"hit_react"'; do
  grep -qF "$need" <<<"$body" || bad "_test_hit_react_window does not use $need"
done
grep -qF 'play_clip(&"hit_react")' <<<"$body" && bad "_test_hit_react_window calls play_clip(hit_react) itself; it must go through _on_damaged"

run_canim() { "$G" perl -e 'alarm 600; exec @ARGV' "$GD" --headless --path game --script res://tests/t_canim.gd > "$1" 2>&1; echo $?; }

# 3. With the fix: PASS, one ok line per authored species, real numbers.
rc=$(run_canim "$OUT/fixed.log")
[[ "$rc" == 0 ]] || bad "t_canim exit $rc with the fix (log $OUT/fixed.log)"
grep -q '^\[t_canim\] PASS' "$OUT/fixed.log" || bad "t_canim did not print [t_canim] PASS"
grep -q "couldn't resolve track" "$OUT/fixed.log" && bad "couldn't resolve track warnings"
grep -qE 'SCRIPT ERROR|Parse Error' "$OUT/fixed.log" && bad "script errors in t_canim"
species=$(python3 -I -c '
import json, glob, os
for p in sorted(glob.glob("game/data/creatures/*.json")):
    try: d = json.load(open(p))
    except Exception: continue
    if isinstance(d, dict) and "hit_react" in d.get("pipeline", {}).get("authored_clips", {}): print(os.path.basename(p)[:-5])')
n=0
for id in $species; do
  n=$((n+1))
  line=$(grep -E "^\[t_canim\] ok   $id hit_react [0-9.]+ s at x2\.00 under a 1\.0 s hit cadence: free to attack [0-9.]+ s of each second" "$OUT/fixed.log")
  [[ -n "$line" ]] || bad "no ok hit_react line at x2.00 for $id"
done
[[ $n -ge 9 ]] || bad "only $n species with an authored hit_react found"
grep -qE '^\[t_canim\] ok   zebraceratops hit_react 1\.125 s at x2\.00' "$OUT/fixed.log" || bad "zebraceratops line does not report the 1.125 s clip"
grep -qE '^\[t_canim\] ok   velociraptor hit_react 1\.250 s at x2\.00' "$OUT/fixed.log" || bad "velociraptor line does not report the 1.250 s clip"

# 4. Without the fix the check must fail (the stunlock the review measured).
cp "$EV" "$OUT/anim_events.json.bak"
trap 'cp "$OUT/anim_events.json.bak" "$EV"' EXIT
python3 -I - "$EV" <<'EOF'
import json, sys
p = sys.argv[1]
s = open(p).read()
line = '    "hit_react": { "speed": 2.0 },\n'
assert line in s, "hit_react speed line not found"
open(p, "w").write(s.replace(line, "", 1))
json.load(open(p))
EOF
rc=$(run_canim "$OUT/broken.log")
cp "$OUT/anim_events.json.bak" "$EV"
[[ "$rc" != 0 ]] || bad "t_canim still exits 0 with the hit_react speed removed"
for id in zebraceratops velociraptor; do
  grep -qE "^\[t_canim\] FAIL $id hit_react [0-9.]+ s at x1\.00 .*free to attack 0\.[0-2][0-9] s" "$OUT/broken.log" || bad "no FAIL line (free < 0.30) for $id without the fix"
done
git diff --quiet $BASE -- "$EV" || bad "$EV not restored"

# 5. No new Godot crash report.
newips=$(find ~/Library/Logs/DiagnosticReports -name 'Godot-*.ips' -newer "$OUT" 2>/dev/null | head -3)
[[ -z "$newips" ]] || bad "Godot crashed: $newips"

if [[ $fail == 0 ]]; then echo "VERIFY PASS (logs $OUT)"; exit 0; fi
exit 1
