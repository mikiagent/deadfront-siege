#!/bin/bash
# SP-MAJUNGASAURUS (owner 2026-10-31: approved sheet, named Majungasaurus): build the majungasaurus from the Tripo v1
# mesh (task 6480a614-155b-4fe6-b906-f572daf7ea62, kept as work/majungasaurus_tripo_v1.glb, gitignored; the task id
# re-downloads it). Same route as build_pachycephalosaurus.sh:
#   1. tools/gait/rig_biped.py: hand-placed theropod skeleton (tools/gait/majungasaurus_rig.json), heat weights
#   2. tools/jaw/add_jaw.py: Jaw bone + lower-jaw skin (--x-side: this level jaw needs +X to open)
#   3. gaits from tools/gait/majungasaurus.json (walk, run, charge, strafes, walk_back)
#   4. one-shots (crushing bite, grab-and-shake pin_stab, skull-knob headbutt, low tail swipe "kick", roar), idle,
#      feed, sleep from tools/gait/make_majunga_moves.py (jaw keyed there)
#   5. ground_clip.py lifts any frame whose skin dips under the floor
# Gate: Blender -b -P tools/gait/check_majunga.py -- $D/majungasaurus.glb $D/anim --height 5.0
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/majungasaurus; G=tools/gait/majungasaurus.json
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run -P tools/gait/rig_biped.py -- $D/work/majungasaurus_tripo_v1.glb tools/gait/majungasaurus_rig.json $T/rig.glb
run -P tools/jaw/add_jaw.py -- $T/rig.glb $D/majungasaurus.glb --open --x-side --pivot 0.05 0.385 --mid 0.3 --reach 1.0 --blend 0.01
mkdir -p $T/x $T/g $D/anim
run -P tools/gait/make_gait.py -- $D/majungasaurus.glb $G walk $T/x/walk.glb
run -P tools/gait/make_gait.py -- $D/majungasaurus.glb $G run $T/x/run.glb
run -P tools/gait/make_gait.py -- $D/majungasaurus.glb $G charge $T/x/charge.glb
run -P tools/gait/make_gait.py -- $D/majungasaurus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0 --set stride=0.2
run -P tools/gait/make_gait.py -- $D/majungasaurus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0 --set stride=0.2
run -P tools/gait/make_gait.py -- $D/majungasaurus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.2
pids=()
for c in idle alert attack_primary attack_heavy kick pin_stab hit_react knockdown death sleep feed; do
  run -P tools/gait/make_majunga_moves.py -- $D/majungasaurus.glb $c $T/x/$c.glb & pids+=($!)
done
for p in "${pids[@]}"; do wait $p; done
for f in $T/x/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/majungasaurus.glb $f $T/g/$c.glb --fps 24; done
rm -f $D/anim/*.glb
cp $T/g/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
