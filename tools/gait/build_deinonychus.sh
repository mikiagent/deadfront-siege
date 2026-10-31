#!/bin/bash
# SP-DEINONYCHUS (v4): the deinonychus rebuilt from the owner's turnaround sheet (owner: "this is deinonychus, fix";
# "dude turn this into a new deinonychus model. The current one is messed up"). Tripo multiview mesh
# (task 18b9c322-1d35-48ed-beec-632399315f00, work/deinonychus_tripo_v4.glb, gitignored; the task id re-downloads it).
#   1 transplant the Quaternius Velociraptor donor (same skeleton as the Raptor and the old deinonychus)
#   2 add_jaw.py + open_mouth.py (a real Jaw bone, lips cut, mouth bag), raptor_leg_weights.py (thigh follows the leg),
#     deino_wing_weights.py (the folded-wing shells skinned to the arms), add_claw_tips.py (ClawTip.L/R hit markers)
#   3 the OLD deinonychus clips the owner likes (3-hit chomp combo, pounce, leap_back, and the rest of its pack set)
#     moved onto the new rig from work/v3/ (the v3 rig and clips, kept as the source) with transfer_clips.py
#   4 gaits on the new rig: make_gait.py + tools/gait/deinonychus.json (raptor gaits, bigger strafe steps)
#   5 raptor_overlay.py: the arms (and so the wings) grab, rake and flare in every attack and leap; tail counter-balance
#   6 make_raptor_moves.py: pin_stab (pounce-pin-and-bite), attack_heavy (sickle slash), alert (wing-and-fan display), sleep
#   7 velociraptor feed; ground_clip.py on the loops
# Gate: Blender -b -P tools/gait/check_deinonychus.py -- $D/deinonychus.glb $D/anim --height 2.87
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/deinonychus; W=$D/work; V3=$W/v3; VR=game/assets/creatures/velociraptor
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
if [[ "${1:-}" != "--clips-only" ]]; then
  run --python tools/transplant_rig.py -- --mesh $W/deinonychus_tripo_v4.glb --donor tools/standins/quaternius/Velociraptor.fbx \
    --species deinonychus --output-root $T/tp --map Attack=attack_primary Jump=attack_heavy Death=death Idle=idle Run=run Walk=walk
  run --python tools/jaw/add_jaw.py -- $T/tp/deinonychus/deinonychus.glb $T/jaw.glb --blend 0.008
  run --python tools/jaw/open_mouth.py -- $T/jaw.glb $T/mouth.glb --corner 0.03
  run -P tools/gait/raptor_leg_weights.py -- $T/mouth.glb $T/legw.glb
  run -P tools/gait/deino_wing_weights.py -- $T/legw.glb $T/wingw.glb
  run -P tools/gait/add_claw_tips.py -- $T/wingw.glb $D/deinonychus.glb
fi
mkdir -p $T/x $T/g $T/o
LOOPS="idle"
SHOTS="attack_primary bite_combo pounce hop_back leap_back dodge_left dodge_right hit_react knockdown death"
run -P tools/gait/transfer_clips.py -- $V3/deinonychus.glb $D/deinonychus.glb $T/x $(for c in $LOOPS; do echo $V3/anim/$c.glb; done) --floor-feet
run -P tools/gait/transfer_clips.py -- $V3/deinonychus.glb $D/deinonychus.glb $T/x $(for c in $SHOTS; do echo $V3/anim/$c.glb; done) --floor-feet --pin-toes
run -P tools/gait/transfer_clips.py -- $VR/velociraptor.glb $D/deinonychus.glb $T/x $VR/anim/feed.glb --floor-feet
for c in $LOOPS; do run -P tools/gait/ground_clip.py -- $D/deinonychus.glb $T/x/$c.glb $T/g/$c.glb; cp $T/g/$c.glb $T/x/; done
for c in walk run charge; do run -P tools/gait/make_gait.py -- $D/deinonychus.glb tools/gait/deinonychus.json $c $T/x/$c.glb; done
run -P tools/gait/ground_clip.py -- $D/deinonychus.glb $T/x/charge.glb $T/g/charge.glb --fps 24; cp $T/g/charge.glb $T/x/
run -P tools/gait/make_gait.py -- $D/deinonychus.glb tools/gait/deinonychus.json strafe $T/x/strafe_left.glb --as strafe_left --travel 1,0,0
run -P tools/gait/make_gait.py -- $D/deinonychus.glb tools/gait/deinonychus.json strafe $T/x/strafe_right.glb --as strafe_right --travel -1,0,0
run -P tools/gait/make_gait.py -- $D/deinonychus.glb tools/gait/deinonychus.json walk $T/x/walk_back.glb --as walk_back --travel 0,1,0
for c in idle attack_primary bite_combo pounce hop_back leap_back dodge_left dodge_right hit_react knockdown death; do
  run -P tools/gait/raptor_overlay.py -- $D/deinonychus.glb $T/x/$c.glb $T/o/$c.glb; cp $T/o/$c.glb $T/x/; done
for c in pin_stab attack_heavy alert sleep; do run -P tools/gait/make_raptor_moves.py -- $D/deinonychus.glb $c $T/x/$c.glb; done
for c in sleep knockdown death; do run -P tools/gait/ground_clip.py -- $D/deinonychus.glb $T/x/$c.glb $T/g/$c.glb; cp $T/g/$c.glb $T/x/; done  # the v3 fall put a foot 10 cm under
rm -f $D/anim/*.glb; cp $T/x/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
