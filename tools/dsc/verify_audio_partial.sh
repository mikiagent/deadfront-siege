#!/bin/zsh
# Fast per-milestone gate for the dsc audio fixes: unit tests and the audio lab. The full gate runs at the end.
cd "$(dirname "$0")/../.."
SP=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad
G=/Applications/Godot_mono.app/Contents/MacOS/Godot; rc=0; L=$(mktemp)
$SP/gslot.sh perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/run_all.gd > $L 2>&1; grep -q "^\[tests\] PASS" $L && echo "PASS run_all" || { echo "FAIL run_all: $(grep -E 'FAIL|SCRIPT ERROR' $L | head -3)"; rc=1; }
$SP/gslot.sh perl -e 'alarm 300; exec @ARGV' $G --headless --path game -- --lab=audio_lab > $L 2>&1; grep -q "\[audio_lab\] PASS" $L && echo "PASS audio_lab" || { echo "FAIL audio_lab"; rc=1; }
rm -f $L; exit $rc
