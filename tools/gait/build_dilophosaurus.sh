#!/bin/bash
# SP-DILOPHOSAURUS (owner 2026-10-30: "build some of the models ... be creative with what moves"): build the
# dilophosaurus from the Tripo v1 mesh (task edf6ddcc-0972-4860-800b-c2bc732cab43, frill-less views; kept as
# work/dilophosaurus_tripo_v1.glb, gitignored; the task id re-downloads it):
#   1. tools/gait/rig_biped.py: hand-placed theropod skeleton (tools/gait/dilophosaurus_rig.json), heat weights
#   2. tools/jaw/add_jaw.py: Jaw bone + lower-jaw skin (the mesh was modelled mouth open)
#   3. tools/gait/dilophosaurus_frill.py: the neck frill (membrane + 7 rib bones a side, folded at rest), the atlas
#      strip with its paint; writes tools/gait/dilophosaurus_frill.json (the open rotations)
#   4. gaits from tools/gait/dilophosaurus.json (walk, run, strafes, walk_back)
#   5. one-shots, idle, feed, sleep, spit, pounce from tools/gait/make_dilo_moves.py (jaw and frill keyed there)
#   6. ground_clip.py lifts any frame whose skin dips under the floor (not the pounce: the game flies it)
#   7. the alpha albedo (tools/gait/dilophosaurus_alpha_skin.py)
# Gate: Blender -b -P tools/gait/check_dilophosaurus.py -- $D/dilophosaurus.glb $D/anim --height 3.6
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/dilophosaurus; G=tools/gait/dilophosaurus.json
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run -P tools/gait/rig_biped.py -- $D/work/dilophosaurus_tripo_v1.glb tools/gait/dilophosaurus_rig.json $T/rig.glb
run -P tools/jaw/add_jaw.py -- $T/rig.glb $T/jaw.glb --open --snout 0.108 --pivot 0.049 0.273 --reach 1.0
run -P tools/gait/dilophosaurus_frill.py -- $T/jaw.glb $D/dilophosaurus.glb tools/gait/dilophosaurus_frill.json
mkdir -p $T/x $T/g
run -P tools/gait/make_gait.py -- $D/dilophosaurus.glb $G walk $T/x/walk.glb
run -P tools/gait/make_gait.py -- $D/dilophosaurus.glb $G run $T/x/run.glb
run -P tools/gait/make_gait.py -- $D/dilophosaurus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0 --set stride=0.16
run -P tools/gait/make_gait.py -- $D/dilophosaurus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0 --set stride=0.16
run -P tools/gait/make_gait.py -- $D/dilophosaurus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.16
pids=()
for c in idle alert attack_primary attack_heavy spit pounce hit_react knockdown death sleep feed; do
  run -P tools/gait/make_dilo_moves.py -- $D/dilophosaurus.glb $c $T/x/$c.glb & pids+=($!)
done
for p in "${pids[@]}"; do wait $p; done
for f in $T/x/*.glb; do
  c=$(basename $f .glb)
  if [ "$c" = pounce ]; then cp $f $T/g/$c.glb; else run -P tools/gait/ground_clip.py -- $D/dilophosaurus.glb $f $T/g/$c.glb; fi
done
rm -f $D/anim/*.glb
cp $T/g/*.glb $D/anim/
run -P tools/gait/dilophosaurus_alpha_skin.py -- $D/dilophosaurus.glb $D/dilophosaurus_alpha_albedo.jpg
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
