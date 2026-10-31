#!/bin/bash
# PACHY (owner 2026-10-31: "the Pachy's model is completely ruined. the legs are mangled. And the color is off"):
# rebuild the pachycephalosaurus from the Tripo v2 mesh (task c890b902-ab1d-4a89-b997-fc74254abcf7, kept as
# work/pachycephalosaurus_tripo_v2.glb, gitignored; the task id re-downloads it):
#   1. tools/gait/rig_biped.py: hand-placed T. rex-style skeleton (tools/gait/pachycephalosaurus_rig.json), heat weights
#   2. tools/jaw/add_jaw.py: Jaw bone + lower-beak skin
#   3. gaits from tools/gait/pachycephalosaurus.json (walk, run, charge, strafes, walk_back)
#   4. one-shots, idle, feed, sleep from tools/gait/make_pachy_moves.py (jaw keyed there)
#   5. ground_clip.py lifts any frame whose skin dips under the floor
# Gate: Blender -b -P tools/gait/check_pachy.py -- $D/pachycephalosaurus.glb $D/anim --height 1.8
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/pachycephalosaurus; G=tools/gait/pachycephalosaurus.json
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run -P tools/gait/rig_biped.py -- $D/work/pachycephalosaurus_tripo_v2.glb tools/gait/pachycephalosaurus_rig.json $T/rig.glb
run -P tools/jaw/add_jaw.py -- $T/rig.glb $D/pachycephalosaurus.glb --open --snout 0.142 --pivot 0.075 0.38 --mid 0.3 --reach 1.0
mkdir -p $T/x $T/g
run -P tools/gait/make_gait.py -- $D/pachycephalosaurus.glb $G walk $T/x/walk.glb
run -P tools/gait/make_gait.py -- $D/pachycephalosaurus.glb $G run $T/x/run.glb
run -P tools/gait/make_gait.py -- $D/pachycephalosaurus.glb $G charge $T/x/charge.glb
run -P tools/gait/make_gait.py -- $D/pachycephalosaurus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0 --set stride=0.2
run -P tools/gait/make_gait.py -- $D/pachycephalosaurus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0 --set stride=0.2
run -P tools/gait/make_gait.py -- $D/pachycephalosaurus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.2
pids=()
for c in idle alert attack_primary attack_heavy kick hit_react knockdown death sleep feed; do
  run -P tools/gait/make_pachy_moves.py -- $D/pachycephalosaurus.glb $c $T/x/$c.glb & pids+=($!)
done
for p in "${pids[@]}"; do wait $p; done
for f in $T/x/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/pachycephalosaurus.glb $f $T/g/$c.glb; done
rm -f $D/anim/*.glb
cp $T/g/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
