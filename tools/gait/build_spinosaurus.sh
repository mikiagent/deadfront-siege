#!/bin/bash
# SP-SPINOSAURUS (owner 2026-10-31, species brief): build the spinosaurus from the Tripo v1 mesh (task
# a83eaa9c-8129-4dd0-8031-5dfce167a2c4, kept as work/spinosaurus_tripo_v1.glb, gitignored; the task id re-downloads it).
# Tripo kept the sail whole (one continuous membrane on the back), so it is skinned with the body: rig_biped's bone heat
# gives it to Spine1/Chest/Hips/Tail1-2 in vertical bands, sail_weights.py smooths them, and it rides the spine (no separate Blender sail needed).
#   1. tools/gait/rig_biped.py: hand-placed theropod skeleton (tools/gait/spinosaurus_rig.json), heat weights;
#      tools/gait/sail_weights.py smooths the sail's weights along the back (crest noise tore the spikes 11x in the run)
#   2. tools/jaw/add_jaw.py --x-side: Jaw bone (local +X opens it) + lower-jaw skin; tools/jaw/open_mouth.py rips the lips
#      apart and adds the mouth bag
#   3. gaits from tools/gait/spinosaurus.json (walk, run, strafes, walk_back, stalk = the low wading creep)
#   4. one-shots, idle, feed, sleep, the snap-and-shake (bite_shake), the tail swipe (kick) and the water lunge (pounce)
#      from make_spino_moves.py
#   5. ground_clip.py lifts any frame whose skin dips under the floor
# Gate: Blender -b -P tools/gait/check_spino.py -- $D/spinosaurus.glb $D/anim --height 9.0
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/spinosaurus; G=tools/gait/spinosaurus.json
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run -P tools/gait/rig_biped.py -- $D/work/spinosaurus_tripo_v1.glb tools/gait/spinosaurus_rig.json $T/rig.glb
run -P tools/gait/sail_weights.py -- $T/rig.glb $T/sail.glb
run -P tools/jaw/add_jaw.py -- $T/sail.glb $T/jaw.glb --pivot 0.033 0.285 --split -14 --blend 0.008 --snout 0.145 --x-side
run -P tools/jaw/open_mouth.py -- $T/jaw.glb $D/spinosaurus.glb
mkdir -p $T/x $T/g $D/anim
run -P tools/gait/make_gait.py -- $D/spinosaurus.glb $G walk $T/x/walk.glb
run -P tools/gait/make_gait.py -- $D/spinosaurus.glb $G run $T/x/run.glb
run -P tools/gait/make_gait.py -- $D/spinosaurus.glb $G stalk $T/x/stalk.glb
run -P tools/gait/make_gait.py -- $D/spinosaurus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0 --set stride=0.18
run -P tools/gait/make_gait.py -- $D/spinosaurus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0 --set stride=0.18
run -P tools/gait/make_gait.py -- $D/spinosaurus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.18
pids=()
for c in idle alert attack_primary attack_heavy bite_shake kick pounce hit_react knockdown death sleep feed; do
  run -P tools/gait/make_spino_moves.py -- $D/spinosaurus.glb $c $T/x/$c.glb & pids+=($!)
done
for p in "${pids[@]}"; do wait $p; done
for f in $T/x/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/spinosaurus.glb $f $T/g/$c.glb --fps 24; done
rm -f $D/anim/*.glb
cp $T/g/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
