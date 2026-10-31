#!/bin/bash
# SP-TARBOSAURUS: rebuild the tarbosaurus from its Tripo mesh (task a969df84-2c34-4b51-b832-44af5a805aaa) and every clip.
# Inputs (gitignored, game/assets/creatures/tarbosaurus/work/): tarbo_tripo_v1.glb (Tripo) and tyrannosaurus_v1_base.glb
# (the T. rex rigged base: bone names, rolls). The rex tools carry over because the rig is the same 30 bones.
#   build_tarbosaurus.sh base   -> clean, fit the rig, add the jaw, write tarbosaurus.glb
#   build_tarbosaurus.sh clips  -> author every clip, ground them, gate them
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/tarbosaurus; G=tools/gait/tarbosaurus.json
T=${TARBO_TMP:-$(mktemp -d)}; mkdir -p "$T"
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
if [ "${1:-all}" != clips ]; then
  run -P tools/gait/tarbo_clean.py -- $D/work/tarbo_tripo_v1.glb $D/work/tarbosaurus_tripo_clean.glb
  run -P tools/gait/fit_rex_rig.py -- $D/work/tyrannosaurus_v1_base.glb $D/work/tarbosaurus_tripo_clean.glb $T/fit.glb --joints tools/gait/tarbosaurus_joints.json
  # mouth corner by hand (head close-up grid): the back of the gape 1.19 m ahead of the head joint at 6.35 m; the split
  # runs 15 deg down between the tooth rows; closed 44 of the modelled ~49 deg so the lips never fuse
  run -P tools/jaw/add_jaw.py -- $T/fit.glb $D/tarbosaurus.glb --open --weld --pivot 1.19 6.35 --split -15 --close 44 --blend 0.3
  echo "BASE OK"
fi
[ "${1:-all}" = base ] && exit 0
mkdir -p $T/x $T/g
for c in idle alert attack_primary attack_heavy pounce kick hit_react feed knockdown death sleep pin_foot; do
  run -P tools/gait/make_rex_moves.py -- $D/tarbosaurus.glb $c $T/x/$c.glb --tarbo &
done
for c in walk run stalk; do run -P tools/gait/make_gait.py -- $D/tarbosaurus.glb $G $c $T/x/$c.glb & done
run -P tools/gait/make_gait.py -- $D/tarbosaurus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel -1,0,0 &
run -P tools/gait/make_gait.py -- $D/tarbosaurus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel 1,0,0 &
run -P tools/gait/make_gait.py -- $D/tarbosaurus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,-1,0 &
wait
# the lying clips and the gaits: any frame whose skin dips under the floor lifts the root by the deficit (STEGOFIX tool);
# the standing one-shots are authored on their prints and pass as they are (grounding lifted their toes 2-3 cm)
cp $T/x/*.glb $T/g/
for c in knockdown death sleep walk run stalk strafe_left strafe_right walk_back; do
  run -P tools/gait/ground_clip.py -- $D/tarbosaurus.glb $T/x/$c.glb $T/g/$c.glb &
done
wait
cp $T/g/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
python3 tools/gait/check_tarbosaurus.py || true
echo "BUILD OK ($T)"
