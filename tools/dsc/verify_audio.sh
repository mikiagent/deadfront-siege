#!/bin/zsh
# Gate for the dsc audio fixes: tests, audio lab, smoke, true peak <= -1 dBTP on every shipped file, settings + mute present.
cd "$(dirname "$0")/../.."
SP=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad
G=/Applications/Godot_mono.app/Contents/MacOS/Godot; rc=0; L=$(mktemp)
$SP/gslot.sh perl -e 'alarm 900; exec @ARGV' $G --headless --path game --import >/dev/null 2>&1
$SP/gslot.sh perl -e 'alarm 400; exec @ARGV' $G --headless --path game --script res://tests/run_all.gd > $L 2>&1; grep -q "^\[tests\] PASS" $L && echo "PASS run_all" || { echo "FAIL run_all"; rc=1; }
$SP/gslot.sh perl -e 'alarm 300; exec @ARGV' $G --headless --path game -- --lab=audio_lab > $L 2>&1; grep -q "\[audio_lab\] PASS" $L && echo "PASS audio_lab" || { echo "FAIL audio_lab"; rc=1; }
$SP/gslot.sh perl -e 'alarm 300; exec @ARGV' $G --headless --path game -- --mute --smoke > $L 2>&1; grep -qi "master muted\|mute.*on\|\[audio\].*mute" $L && echo "PASS --mute logged" || { echo "FAIL --mute not logged (print a line like '[audio] master muted (flag)')"; rc=1; }
$SP/gslot.sh perl -e 'alarm 200; exec @ARGV' tools/smoke.sh --no-import | tail -1 | grep -q "SMOKE PASS" && echo "PASS smoke" || { echo "FAIL smoke"; rc=1; }
hot=0; for f in game/assets/audio/**/*.ogg(N); do tp=$(/opt/homebrew/bin/ffmpeg -nostats -hide_banner -i "$f" -af ebur128=peak=true -f null - 2>&1 | awk '/True peak:/{getline; print $2}' | tail -1); [[ -n "$tp" ]] && (( $(echo "$tp > -1.0" | bc -l) )) && { hot=$((hot+1)); echo "HOT $tp $f"; }; done
[[ $hot -eq 0 ]] && echo "PASS true peak" || { echo "FAIL $hot files above -1 dBTP"; rc=1; }
ls game/scripts/audio/*settings* >/dev/null 2>&1 && echo "PASS settings panel" || { echo "FAIL no sound settings panel"; rc=1; }
[[ -f docs/orchestration/reports/dsc-audio-fixes.md ]] || { echo "FAIL report missing"; rc=1; }
rm -f $L; exit $rc
