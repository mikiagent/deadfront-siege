#!/bin/bash
# SP-GALLIMIMUS (owner 2026-10-31: "Gallimimus is fast but the model isn't great, animations aren't great and its behavior
# sucks"): rebuild the gallimimus from the Tripo v1 mesh of the owner's sheet (task e0cba9ee-23e6-4fe0-8b93-2899cffb2d5e,
# kept as work/gallimimus_tripo_v1.glb, gitignored; the task id re-downloads it):
#   1. tools/gait/rig_biped.py: hand-placed skeleton with a 3-bone neck (tools/gait/gallimimus_rig.json), heat weights
#   2. tools/jaw/add_jaw.py: Jaw bone + lower-beak skin (the beak is modelled gaping: --close shuts it in the bind pose)
#   3. gaits from tools/gait/gallimimus.json (walk, run, charge, strafes, walk_back)
#   4. fight moves, bounds, idle, feed, sleep from tools/gait/make_galli_moves.py (jaw keyed there)
#   5. ground_clip.py lifts any frame whose skin dips under the floor
# Gate: Blender -b -P tools/gait/check_galli.py -- $D/gallimimus.glb $D/anim --height 3.8
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/gallimimus; G=tools/gait/gallimimus.json
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run -P tools/gait/rig_biped.py -- $D/work/gallimimus_tripo_v1.glb tools/gait/gallimimus_rig.json $T/rig.glb
run -P tools/jaw/add_jaw.py -- $T/rig.glb $D/gallimimus.glb --open --pivot 0.035 0.6 --split -12 --mid 0.3 --reach 1.0 --close 36
mkdir -p $T/x $T/g
pids=()
run -P tools/gait/make_gait.py -- $D/gallimimus.glb $G walk $T/x/walk.glb & pids+=($!)
run -P tools/gait/make_gait.py -- $D/gallimimus.glb $G run $T/x/run.glb & pids+=($!)
run -P tools/gait/make_gait.py -- $D/gallimimus.glb $G charge $T/x/charge.glb & pids+=($!)
run -P tools/gait/make_gait.py -- $D/gallimimus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0 --set stride=0.22 & pids+=($!)
run -P tools/gait/make_gait.py -- $D/gallimimus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0 --set stride=0.22 & pids+=($!)
run -P tools/gait/make_gait.py -- $D/gallimimus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.25 & pids+=($!)
for c in idle alert attack_primary attack_heavy bite_combo hop_back leap_back dodge_left dodge_right hit_react knockdown death sleep feed; do
  run -P tools/gait/make_galli_moves.py -- $D/gallimimus.glb $c $T/x/$c.glb & pids+=($!)
done
for p in "${pids[@]}"; do wait $p; done
for f in $T/x/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/gallimimus.glb $f $T/g/$c.glb --fps 24; done
rm -f $D/anim/*.glb
cp $T/g/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
