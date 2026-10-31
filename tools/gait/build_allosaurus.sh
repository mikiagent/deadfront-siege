#!/bin/bash
# SP-ALLOSAURUS: rebuild the allosaurus from the Tripo mesh (task d5b0362a-ca5a-46f2-9736-8d5c0efeaa73, kept as
# work/allosaurus_tripo_v1.glb, gitignored; the task id re-downloads it):
#   1. tools/gait/rig_biped.py: hand-placed theropod skeleton (tools/gait/allosaurus_rig.json), heat weights
#   2. tools/jaw/add_jaw.py --open --x-side: Jaw bone, the open-mouthed mesh closed in the bind pose (+X opens)
#   3. gaits from tools/gait/allosaurus.json (walk, run, strafes, walk_back)
#   4. moves, idle, feed, sleep from tools/gait/make_allo_moves.py (hatchet bite, grab_bite, shoulder ram as kick;
#      ALLOFEEL: arms in every attack, claw_rake, slash_bite, check_left/right)
#   5. ground_clip.py lifts any frame whose skin dips under the floor
# Gate: Blender -b -P tools/gait/check_allo.py -- $D/allosaurus.glb $D/anim --height 6.5
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/allosaurus; G=tools/gait/allosaurus.json
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run -P tools/gait/rig_biped.py -- $D/work/allosaurus_tripo_v1.glb tools/gait/allosaurus_rig.json $T/rig.glb
run --python tools/jaw/add_jaw.py -- $T/rig.glb $D/allosaurus.glb --open --x-side --snout 0.135 --pivot 0.03 0.365 --blend 0.008
mkdir -p $T/x $T/g
run -P tools/gait/make_gait.py -- $D/allosaurus.glb $G walk $T/x/walk.glb
run -P tools/gait/make_gait.py -- $D/allosaurus.glb $G run $T/x/run.glb
run -P tools/gait/make_gait.py -- $D/allosaurus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0 --set stride=0.16
run -P tools/gait/make_gait.py -- $D/allosaurus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0 --set stride=0.16
run -P tools/gait/make_gait.py -- $D/allosaurus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.16
pids=()
for c in idle alert attack_primary attack_heavy grab_bite kick hit_react knockdown death sleep feed claw_rake slash_bite check_left check_right bite_combo; do
  run -P tools/gait/make_allo_moves.py -- $D/allosaurus.glb $c $T/x/$c.glb & pids+=($!)
done
for p in "${pids[@]}"; do wait $p; done
for f in $T/x/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/allosaurus.glb $f $T/g/$c.glb --fps 24; done
rm -f $D/anim/*.glb
cp $T/g/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
