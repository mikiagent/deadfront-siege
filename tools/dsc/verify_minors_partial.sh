#!/bin/zsh
# Fast per-milestone gate for the dsc minor-fix batch: run_all plus every t_*.gd. The full gate (labs, smoke, report) runs at the end.
cd "$(dirname "$0")/../.."
SP=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad
G=/Applications/Godot_mono.app/Contents/MacOS/Godot; rc=0; L=$(mktemp)
for t in run_all $(ls game/tests/t_*.gd | xargs -n1 basename | sed 's/\.gd$//'); do
  $SP/gslot.sh perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/$t.gd > $L 2>&1
  if grep -qE "^\[(tests|t_[a-z_]+)\] PASS" $L && ! grep -qE "^\[(tests|t_[a-z_]+)\] FAIL" $L; then echo "PASS $t"; else echo "FAIL $t: $(grep -E 'FAIL|SCRIPT ERROR' $L | head -3)"; rc=1; fi
done
rm -f $L; exit $rc
