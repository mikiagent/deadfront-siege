#!/usr/bin/env bash
# verify_job.sh <key> [1|2]: shared staged gate for DeepSeek jobs, run from the job's work tree. Settings: job_<key>.conf here.
#   BASE     = optional: the commit the job's worktree was cut from (scope diff base). Defaults to the
#              merge-base with claude/mmo-overhaul.
#   1        = the job's unit test passes with no SCRIPT ERROR
#   2        = + its lab, windowed at 1600x900 and 844x390, prints "[<key>] RESULT k=v ..." whose numbers pass the conf's
#              LAB_ASSERT (python over dict v and string res), and saves at least MIN_SHOTS PNGs in --shot-dir
#              When $D/HEADLESS_ONLY exists, the owner has reserved the machine for multitasking: visual labs are
#              explicitly deferred and the remaining headless checks still run. The orchestrator must not treat that as
#              visual approval.
#   no stage = + the related tests (exit 0 and their PASS line), smoke, the report and the scope check
K=$1; S=${2:-3}
D=$(cd "$(dirname "$0")" && pwd)
. "$D/job_$K.conf" || { echo "VERIFY FAIL: no $D/job_$K.conf"; exit 1; }
T=$(git rev-parse --show-toplevel); cd "$T" || exit 1
G=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
GD=/Applications/Godot_mono.app/Contents/MacOS/Godot
OUT=/tmp/${K}_verify; mkdir -p "$OUT"
fail() { echo "VERIFY FAIL: $*"; exit 1; }
for f in $REQUIRE_FILES; do [ -e "$f" ] || fail "$f is missing (the task names it as a file to create)"; done
"$G" perl -e 'alarm 600; exec @ARGV' "$GD" --headless --path game --script "res://tests/$TEST.gd" > "$OUT/$TEST.log" 2>&1
grep -q "\[$TEST\] PASS" "$OUT/$TEST.log" && ! grep -q "SCRIPT ERROR" "$OUT/$TEST.log" || fail "$TEST did not PASS cleanly (see $OUT/$TEST.log)"
[ "$S" -lt 2 ] && { echo "VERIFY STAGE 1 PASS"; exit 0; }
if [ -e "$D/HEADLESS_ONLY" ]; then
  echo "VERIFY HEADLESS-ONLY: visual lab deferred by owner"
else
for res in 1600x900 844x390; do
  rm -rf "$OUT/shots_$res"; mkdir -p "$OUT/shots_$res"
  "$G" perl -e "alarm ${LAB_ALARM:-400}; exec @ARGV" "$GD" --path game --resolution "$res" --rendering-method gl_compatibility -- \
    "--lab=$LAB" "--shot-dir=$OUT/shots_$res" $LAB_ARGS > "$OUT/lab_$res.log" 2>&1
  grep -qE "SCRIPT ERROR|SHADER ERROR|Unknown character" "$OUT/lab_$res.log" && fail "SCRIPT or SHADER ERROR in $LAB at $res (see $OUT/lab_$res.log)"
  L=$(grep "^\[$K\] RESULT" "$OUT/lab_$res.log" | tail -1)
  [ -n "$L" ] || fail "$LAB printed no '[$K] RESULT k=v ...' line at $res (see $OUT/lab_$res.log)"
  LAB_ASSERT="$LAB_ASSERT" python3 - "$L" "$res" <<'PY' || fail "$LAB numbers fail the gate at $res: $L"
import os, re, sys
l, res = sys.argv[1], sys.argv[2]
v = {k: float(x) for k, x in re.findall(r"(\w+)=(-?[0-9]+(?:\.[0-9]+)?)", l)}
try:
    ok = eval(os.environ["LAB_ASSERT"], {}, {"v": v, "res": res})
except KeyError as e:
    print("missing key in RESULT line:", e); sys.exit(1)
sys.exit(0 if ok else 1)
PY
  n=$(ls "$OUT/shots_$res"/*.png 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -ge "${MIN_SHOTS:-1}" ] || fail "only $n screenshots at $res in $OUT/shots_$res (need ${MIN_SHOTS:-1})"
done
fi
[ "$S" -lt 3 ] && { echo "VERIFY STAGE 2 PASS"; exit 0; }
[ -s "docs/orchestration/reports/dsc-$K.md" ] || fail "report docs/orchestration/reports/dsc-$K.md is missing"
base=${BASE:-$(git merge-base HEAD claude/mmo-overhaul)}
bad=$( { git diff --name-only "$base"; git ls-files --others --exclude-standard; } | sort -u | grep -vE '\.(uid|import)$|_Image_[0-9]+\.jpg$|^game/assets/props/meshy/' | grep -vE "$SCOPE")
[ -z "$bad" ] || fail "files outside your scope changed: $(echo $bad | head -c 400)"
for t in $RELATED; do
  if [ "$t" = "t_save" ]; then
    # All gslot slots share one Godot user-data directory. Serialize save tests so
    # parallel jobs cannot quarantine or overwrite each other's fixtures.
    lockf -s /tmp/deadfront-dsc-t_save.lock "$G" perl -e 'alarm 600; exec @ARGV' "$GD" --headless --path game --script "res://tests/$t.gd" > "$OUT/$t.log" 2>&1 || fail "$t exited non-zero (see $OUT/$t.log)"
  else
    "$G" perl -e 'alarm 600; exec @ARGV' "$GD" --headless --path game --script "res://tests/$t.gd" > "$OUT/$t.log" 2>&1 || fail "$t exited non-zero (see $OUT/$t.log)"
  fi
  grep -qE "\] PASS" "$OUT/$t.log" || fail "$t printed no PASS line (see $OUT/$t.log)"
done
# run_all is left to the integrator: dsc's runner kills a verify after 20 min, and slot waits add up.
"$G" perl -e 'alarm 900; exec @ARGV' bash tools/smoke.sh --no-import > "$OUT/smoke.log" 2>&1
grep -q "SMOKE PASS" "$OUT/smoke.log" || fail "smoke did not pass (see $OUT/smoke.log)"
echo "VERIFY PASS"
