#!/bin/bash
# SP-RAPTOR: the Raptor (owner: "black and gold is the original raptor") from the Tripo multiview mesh
# (task 98abc3e6-8f7f-4002-8354-282eb7759663, work/raptor_tripo_v1.glb, gitignored; the task id re-downloads it).
#   1 transplant the Quaternius Velociraptor donor (the deinonychus/utahraptor skeleton)
#   2 add_jaw.py (texture-fit mouth line) + open_mouth.py (lips ripped, mouth bag; corner 0.03 keeps the gape web short)
#     + raptor_leg_weights.py (the thigh skin follows the leg, not the hip socket)
#   3 deinonychus clips moved across with transfer_clips.py (its whole pack_flanker set), velociraptor feed
#   4 make_raptor_moves.py: pin_stab (the pounce-pin-and-bite signature), the sickle slash (attack_heavy), crest-flare display (alert), sleep
#   5 ground_clip.py on the loops
#   6 raptor_palettes.py: the colour/feather palette albedos (pipeline.model_variants)
# RAPTORFLANK (owner 2026-10-31: arms in every attack, "the animations are weird"): the gaits are the raptor's own
#   (make_gait.py + raptor.json: feet that lift, strafes that do not cross or slide), the transferred one-shots get
#   raptor_overlay.py (arms glued to the chest and keyed with claw grabs/rakes/balance flares, the scorpion tail
#   flick replaced), and make_raptor_moves.py adds charge_turn (the flank's skid-turn) and flank_rake.
# Gate: Blender -b -P tools/gait/check_raptor.py -- $D/raptor.glb $D/anim --height <height_meters>
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/raptor; W=$D/work; DE=game/assets/creatures/deinonychus; VR=game/assets/creatures/velociraptor
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
if [[ "${1:-}" != "--clips-only" ]]; then
  run --python tools/transplant_rig.py -- --mesh $W/raptor_tripo_v1.glb --donor tools/standins/quaternius/Velociraptor.fbx \
    --species raptor --output-root $T/tp --map Attack=attack_primary Jump=attack_heavy Death=death Idle=idle Run=run Walk=walk
  run --python tools/jaw/add_jaw.py -- $T/tp/raptor/raptor.glb $T/jaw.glb --blend 0.008
  run --python tools/jaw/open_mouth.py -- $T/jaw.glb $T/mouth.glb --corner 0.03
  run -P tools/gait/raptor_leg_weights.py -- $T/mouth.glb $D/raptor.glb
fi
mkdir -p $T/x $T/g
LOOPS="idle"
SHOTS="alert attack_primary attack_heavy bite_combo pounce hop_back leap_back dodge_left dodge_right hit_react knockdown death"
run -P tools/gait/transfer_clips.py -- $DE/deinonychus.glb $D/raptor.glb $T/x $(for c in $LOOPS; do echo $DE/anim/$c.glb; done) --floor-feet
run -P tools/gait/transfer_clips.py -- $DE/deinonychus.glb $D/raptor.glb $T/x $(for c in $SHOTS; do echo $DE/anim/$c.glb; done) --floor-feet --pin-toes
run -P tools/gait/transfer_clips.py -- $VR/velociraptor.glb $D/raptor.glb $T/x $VR/anim/feed.glb --floor-feet
for c in $LOOPS; do run -P tools/gait/ground_clip.py -- $D/raptor.glb $T/x/$c.glb $T/g/$c.glb; cp $T/g/$c.glb $T/x/; done
for c in walk run charge; do run -P tools/gait/make_gait.py -- $D/raptor.glb tools/gait/raptor.json $c $T/x/$c.glb; done
run -P tools/gait/ground_clip.py -- $D/raptor.glb $T/x/charge.glb $T/g/charge.glb --fps 24; cp $T/g/charge.glb $T/x/  # the lean put a shin 9 cm under
run -P tools/gait/make_gait.py -- $D/raptor.glb tools/gait/raptor.json strafe $T/x/strafe_left.glb --as strafe_left --travel 1,0,0
run -P tools/gait/make_gait.py -- $D/raptor.glb tools/gait/raptor.json strafe $T/x/strafe_right.glb --as strafe_right --travel -1,0,0
run -P tools/gait/make_gait.py -- $D/raptor.glb tools/gait/raptor.json walk $T/x/walk_back.glb --as walk_back --travel 0,1,0
mkdir -p $T/o
for c in idle attack_primary bite_combo pounce hop_back leap_back dodge_left dodge_right hit_react knockdown death; do
  run -P tools/gait/raptor_overlay.py -- $D/raptor.glb $T/x/$c.glb $T/o/$c.glb; cp $T/o/$c.glb $T/x/; done
if [[ -f tools/gait/make_raptor_moves.py ]]; then
  for c in pin_stab attack_heavy alert sleep charge_turn flank_rake; do run -P tools/gait/make_raptor_moves.py -- $D/raptor.glb $c $T/x/$c.glb; done
  run -P tools/gait/ground_clip.py -- $D/raptor.glb $T/x/sleep.glb $T/g/sleep.glb; cp $T/g/sleep.glb $T/x/
fi
rm -f $D/anim/*.glb; cp $T/x/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
