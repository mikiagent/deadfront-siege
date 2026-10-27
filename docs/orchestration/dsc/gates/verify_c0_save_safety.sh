#!/usr/bin/env bash
set -uo pipefail

report="docs/orchestration/reports/dsc-c0-save-safety.md"
lab="game/scenes/dev/save_recovery_lab.tscn"
if [[ ! -s "$report" || ! -s "$lab" ]]; then
  echo "C0 pending: save recovery lab and report are required" >&2
  exit 1
fi

slot="/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh"
export GODOT_PATH="/Applications/Godot_mono.app/Contents/MacOS/Godot"
"$slot" perl -e 'alarm 300; exec @ARGV' bash tools/test.sh || exit 1
"$slot" perl -e 'alarm 180; exec @ARGV' bash tools/smoke.sh --no-import || exit 1
lab_output="$("$slot" perl -e 'alarm 120; exec @ARGV' "$GODOT_PATH" --headless --path game -- --lab=save_recovery_lab 2>&1)"
lab_status=$?
printf '%s\n' "$lab_output"
if [[ $lab_status -ne 0 || "$lab_output" != *"SAVE RECOVERY LAB PASS"* || "$lab_output" == *"SCRIPT ERROR"* ]]; then
  echo "C0 save recovery lab failed" >&2
  exit 1
fi
echo "C0 VERIFY PASS"
