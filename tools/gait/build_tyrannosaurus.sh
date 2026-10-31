#!/bin/bash
# SP-TYRANNOSAURUS: rebuild the T. rex v2 (open-mouth Tripo remodel) base and every clip.
# Inputs (gitignored, under work/): tyrannosaurus_tripo_v2.glb (Tripo task 7270b4be-bf0b-4ce6-ab92-bbceb3a48eea) and
# tyrannosaurus_v1_base.glb (the previous rigged base, the weight and bone-roll donor).
#   build_tyrannosaurus.sh base    -> fit the rig, add the jaw, write tyrannosaurus.glb
#   build_tyrannosaurus.sh clips   -> author every clip on it, ground them, gate them
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/tyrannosaurus; G=tools/gait/tyrannosaurus.json
T=${REX_TMP:-$(mktemp -d)}
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
if [ "${1:-all}" != clips ]; then
  run -P tools/gait/fit_rex_rig.py -- $D/work/tyrannosaurus_v1_base.glb $D/work/tyrannosaurus_tripo_v2.glb $T/fit.glb
  # mouth corner by hand (head close-up grid): 0.35 m ahead of the head joint at 5.89 m; the split line runs 24 deg down
  # between the upper and the lower teeth; closed 20 of the modelled ~24 deg so the lips never fuse
  run -P tools/jaw/add_jaw.py -- $T/fit.glb $D/tyrannosaurus.glb --open --weld --pivot 0.349 5.887 --split -24 --close 20 --blend 0.25
  echo "BASE OK"
fi
[ "${1:-all}" = base ] && exit 0
mkdir -p $T/x $T/g
for c in idle alert attack_primary attack_heavy tail_swipe bite_shake hit_react feed knockdown death sleep; do
  run -P tools/gait/make_rex_moves.py -- $D/tyrannosaurus.glb $c $T/x/$c.glb &
done
run -P tools/gait/make_gait.py -- $D/tyrannosaurus.glb $G walk $T/x/walk.glb &
run -P tools/gait/make_gait.py -- $D/tyrannosaurus.glb $G run $T/x/run.glb &
run -P tools/gait/make_gait.py -- $D/tyrannosaurus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel -1,0,0 &
run -P tools/gait/make_gait.py -- $D/tyrannosaurus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel 1,0,0 &
run -P tools/gait/make_gait.py -- $D/tyrannosaurus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,-1,0 &
wait
# any frame whose skin dips under the floor lifts the root by the deficit (STEGOFIX tool)
for f in $T/x/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/tyrannosaurus.glb $f $T/g/$c.glb & done
wait
cp $T/g/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
"$BL" -b -P tools/gait/check_rex_clips.py -- $D/tyrannosaurus.glb $D/anim/*.glb 2>&1 | grep -E "REXCHECK|FAIL|PASS" || true
echo "BUILD OK ($T)"
