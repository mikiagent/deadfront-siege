#!/bin/bash
# ANKYLO3D: rebuild the ankylosaurus clips on game/assets/creatures/ankylosaurus/ankylosaurus.glb (the rigged, jawed,
# re-jointed base). Inputs kept under work/ (gitignored): transplant_base.glb + transplant_anim/ from
#   tools/transplant_rig.py --mesh work/ankylosaurus_tripo_v1.glb --donor tools/standins/quaternius/Triceratops.fbx
#     --species ankylosaurus --hip-z 0.10 --shoulder-z 0.105 --map Attack=attack_primary Jump=attack_heavy Death=death
#     Idle=idle Run=run Walk=walk
# then tools/jaw/add_jaw.py --open --reach 0.6 --pivot -0.02 0.118 --split -13 --close 26 --blend 0.03
# then tools/gait/rejoint_legs.py --front 0.17,-0.295,0.10 0.205,-0.282,0.056 0.205,-0.33,0.004
#   --hind 0.13,0.05,0.10 0.16,0.035,0.056 0.16,0.065,0.004 --paw-top 0.026
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/ankylosaurus; G=tools/gait/ankylosaurus.json
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
# idle, hit_react, knockdown, death: the transplant's, moved onto the re-jointed legs
run -P tools/gait/transfer_clips.py -- $D/work/transplant_base.glb $D/ankylosaurus.glb $T/x \
  $D/work/transplant_anim/idle.glb $D/work/transplant_anim/hit_react.glb $D/work/transplant_anim/knockdown.glb $D/work/transplant_anim/death.glb
# feed: the styracosaurus graze (same donor skeleton)
run -P tools/gait/transfer_clips.py -- game/assets/creatures/styracosaurus/styracosaurus.glb $D/ankylosaurus.glb $T/x \
  game/assets/creatures/styracosaurus/anim/feed.glb
# gaits
run -P tools/gait/make_gait.py -- $D/ankylosaurus.glb $G walk $T/x/walk.glb
run -P tools/gait/make_gait.py -- $D/ankylosaurus.glb $G run $T/x/run.glb
run -P tools/gait/make_gait.py -- $D/ankylosaurus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0
run -P tools/gait/make_gait.py -- $D/ankylosaurus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0
run -P tools/gait/make_gait.py -- $D/ankylosaurus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.12
# tail club attacks (whip, smash, sweep: planted feet + steps, ANKYLOAI), alert, sleep, and the close moves (stomp,
# shove_left/right, tackle coil: ANKYLOCLOSE)
run -P tools/gait/make_tail_club.py -- $D/ankylosaurus.glb $T/x
# jaw keys (grunt on the swing, roar on alert and the heavy telegraph, chew on feed, breathing on idle)
run --python tools/jaw/key_jaw.py -- $D/ankylosaurus.glb $T/x $T/j --bite 14 --lunge 0 --roar 24 --heavy 26 --chew 12 --hit 0.58 --heavy-hit 0.65
cp $T/j/*.glb $T/x/
# any frame whose skin dips under the floor (the transplant roll pushes a paw under, run and walk_back a knee) lifts the root by the deficit (STEGOFIX tool)
mkdir -p $T/g
for f in $T/x/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/ankylosaurus.glb $T/x/$c.glb $T/g/$c.glb; cp $T/g/$c.glb $T/x/; done
cp $T/x/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
