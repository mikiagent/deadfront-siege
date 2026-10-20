#!/bin/zsh
# Gate for dsc minor-fix batches: every test file, smoke and key labs must pass with no unexpected SCRIPT ERROR.
cd "$(dirname "$0")/../.."
SP=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad
G=/Applications/Godot_mono.app/Contents/MacOS/Godot; rc=0; L=$(mktemp)
$SP/gslot.sh perl -e 'alarm 900; exec @ARGV' $G --headless --path game --import >/dev/null 2>&1
for t in run_all $(ls game/tests/t_*.gd | xargs -n1 basename | sed 's/\.gd$//'); do
  $SP/gslot.sh perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/$t.gd > $L 2>&1
  if grep -qE "^\[(tests|t_[a-z_]+)\] PASS" $L && ! grep -qE "^\[(tests|t_[a-z_]+)\] FAIL" $L; then echo "PASS $t"; else echo "FAIL $t: $(grep -E 'FAIL|SCRIPT ERROR' $L | head -3)"; rc=1; fi
done
for l in island_lab combat_rules_lab ai_validation_lab wild_ai_sweep_lab build_lab hunt_lab capture_lab pets_lab; do
  $SP/gslot.sh perl -e 'alarm 300; exec @ARGV' $G --headless --path game -- --lab=$l > $L 2>&1; c=$?
  if [[ $c -eq 0 ]] && grep -qE "PASS|\[world\] island" $L; then echo "PASS lab $l"; else echo "FAIL lab $l rc=$c"; rc=1; fi
done
$SP/gslot.sh perl -e 'alarm 200; exec @ARGV' tools/smoke.sh --no-import | tail -1 | grep -q "SMOKE PASS" && echo "PASS smoke" || { echo "FAIL smoke"; rc=1; }
[[ -f docs/orchestration/reports/dsc-minors-wave1.md ]] || { echo "FAIL report missing"; rc=1; }
rm -f $L; exit $rc
