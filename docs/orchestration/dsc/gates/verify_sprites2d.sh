#!/usr/bin/env bash
# verify_sprites2d.sh [1|2]: SPRITES2D gate, run from the work tree. 1 = cut-outs, 2 = + mapping, no argument = full gate
# (+ contact sheet, report, scope, Godot import with 0 errors for the new files).
T=$(git rev-parse --show-toplevel); cd "$T" || exit 1
S=${1:-3}
SP=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad
PY=/Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13
stage=1; [ "$S" -ge 2 ] && stage=2
"$PY" -I "$SP/dsc/check_sprites2d.py" "$T" "$stage" || exit 1
[ "$S" -lt 3 ] && { echo "VERIFY STAGE $S PASS"; exit 0; }
rc=0
for f in docs/orchestration/reports/dsc-sprites2d.md docs/orchestration/reports/dsc-sprites2d-sheet.png; do
  [ -s "$f" ] || { echo "FAIL $f is missing"; rc=1; }
done
base=$(git merge-base HEAD claude/mmo-overhaul)
bad=$(git diff --name-only "$base" | grep -vE '^(tools/sprites2d/|game/assets/nature/sprites2d/|game/data/world/sprites2d\.json$|docs/orchestration/reports/dsc-sprites2d|docs/orchestration/dsc/sprites2d-TASK\.md$)')
[ -n "$bad" ] && { echo "FAIL files outside your scope changed:"; echo "$bad" | head -20; rc=1; }
G=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
L=/tmp/sprites2d_verify_import.log
"$G" perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > "$L" 2>&1
n=$(grep -E "ERROR" "$L" | grep -ci "sprites2d")
[ "$n" -gt 0 ] && { echo "FAIL Godot import: $n errors on sprites2d files (see $L)"; rc=1; }
[ $rc -eq 0 ] && echo "VERIFY PASS"
exit $rc
