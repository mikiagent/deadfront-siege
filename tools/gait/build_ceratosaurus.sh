#!/bin/bash
# SP-CERATOSAURUS (owner 2026-10-31, species brief): build the ceratosaurus from the Tripo v1 mesh (task
# 402c6567-0c34-488c-9128-03352078ebe6, kept as work/ceratosaurus_tripo_v1.glb, gitignored; the task id re-downloads it):
#   1. tools/gait/rig_biped.py: hand-placed theropod skeleton (tools/gait/ceratosaurus_rig.json), heat weights
#   2. tools/jaw/add_jaw.py --x-side: Jaw bone + lower-jaw skin; tools/jaw/open_mouth.py rips the lips apart (Tripo
#      bridged the parted lips with 2 mm faces that stretched 29x at a 30 deg gape) and adds the mouth bag
#   3. gaits from tools/gait/ceratosaurus.json (walk, run, strafes, walk_back)
#   4. one-shots, idle, feed, sleep, the tail swipe (kick) and the water-edge lunge (pounce) from make_cerato_moves.py
#   5. ground_clip.py lifts any frame whose skin dips under the floor
# Gate: Blender -b -P tools/gait/check_cerato.py -- $D/ceratosaurus.glb $D/anim --height 4.0
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/ceratosaurus; G=tools/gait/ceratosaurus.json
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run -P tools/gait/rig_biped.py -- $D/work/ceratosaurus_tripo_v1.glb tools/gait/ceratosaurus_rig.json $T/rig.glb
run -P tools/jaw/add_jaw.py -- $T/rig.glb $T/jaw.glb --pivot 0.035 0.33 --split -4 --blend 0.008 --snout 0.149 --x-side
run -P tools/jaw/open_mouth.py -- $T/jaw.glb $D/ceratosaurus.glb
mkdir -p $T/x $T/g $D/anim
run -P tools/gait/make_gait.py -- $D/ceratosaurus.glb $G walk $T/x/walk.glb
run -P tools/gait/make_gait.py -- $D/ceratosaurus.glb $G run $T/x/run.glb
run -P tools/gait/make_gait.py -- $D/ceratosaurus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0 --set stride=0.2
run -P tools/gait/make_gait.py -- $D/ceratosaurus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0 --set stride=0.2
run -P tools/gait/make_gait.py -- $D/ceratosaurus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.2
pids=()
for c in idle alert attack_primary attack_heavy kick pounce hit_react knockdown death sleep feed; do
  run -P tools/gait/make_cerato_moves.py -- $D/ceratosaurus.glb $c $T/x/$c.glb & pids+=($!)
done
for p in "${pids[@]}"; do wait $p; done
for f in $T/x/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/ceratosaurus.glb $f $T/g/$c.glb --fps 24; done
rm -f $D/anim/*.glb
cp $T/g/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
