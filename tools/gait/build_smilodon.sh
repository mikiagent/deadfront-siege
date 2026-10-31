#!/bin/bash
# SP-SMILODON: rebuild the smilodon base and every clip from the Tripo mesh (work/ is gitignored; the Tripo task
# aad4a28f-718f-4e91-ad56-27300a8e3246 re-downloads work/smilodon_tripo_v1.glb).
#   1 transplant the Triceratops donor skeleton (its knockdown/death are kept)
#   2 smilodon_rig.py: cat leg joints (hock/wrist digitigrade) and leg weights
#   3 add_jaw.py by hand + smilodon_sabres.py: the sabres ride the skull
#   4 gaits (make_gait.py + smilodon.json), moves (make_cat_moves.py), donor knockdown/death moved across
#   5 ground_clip.py on the ground clips
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/smilodon; G=tools/gait/smilodon.json; W=$D/work
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run --python tools/transplant_rig.py -- --mesh $W/smilodon_tripo_v1.glb --donor tools/standins/quaternius/Triceratops.fbx \
  --species smilodon --output-root $T/tp --map Attack=attack_primary Jump=attack_heavy Death=death Idle=idle Run=run Walk=walk
cp $T/tp/smilodon/smilodon.glb $W/transplant_base.glb; mkdir -p $W/transplant_anim; cp $T/tp/smilodon/anim/*.glb $W/transplant_anim/
run -P tools/gait/smilodon_rig.py -- $W/transplant_base.glb $T/rig.glb
run --python tools/jaw/add_jaw.py -- $T/rig.glb $T/jaw.glb --pivot 0.03 0.393 --split -6 --chin-depth 0.35 --blend 0.008
run -P tools/gait/smilodon_sabres.py -- $T/jaw.glb $D/smilodon.glb
mkdir -p $T/x
run -P tools/gait/transfer_clips.py -- $W/transplant_base.glb $D/smilodon.glb $T/x $W/transplant_anim/knockdown.glb $W/transplant_anim/death.glb
run -P tools/gait/make_gait.py -- $D/smilodon.glb $G walk $T/x/walk.glb
run -P tools/gait/make_gait.py -- $D/smilodon.glb $G run $T/x/run.glb
run -P tools/gait/make_gait.py -- $D/smilodon.glb $G stalk $T/x/stalk.glb
run -P tools/gait/make_gait.py -- $D/smilodon.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0 --set stride=0.3
run -P tools/gait/make_gait.py -- $D/smilodon.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0 --set stride=0.3
run -P tools/gait/make_gait.py -- $D/smilodon.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.3
run -P tools/gait/make_cat_moves.py -- $D/smilodon.glb $T/x
mkdir -p $T/g
for c in knockdown death walk run stalk strafe_left strafe_right walk_back; do
  run -P tools/gait/ground_clip.py -- $D/smilodon.glb $T/x/$c.glb $T/g/$c.glb; cp $T/g/$c.glb $T/x/
done
mkdir -p $D/anim; cp $T/x/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
