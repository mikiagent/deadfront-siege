#!/bin/bash
# ZEBRAWALK: rebuild the zebraceratops locomotion clips (walk, run, strafes, walk_back) on its base GLB.
# The base's leg skin was repaired once with tools/gait/fix_foot_weights.py --full 0.15 --top 0.30 --radius 0.19
# (not rerun here: it reads the pre-fix weights). Gate: tools/gait/check_zebra.py, then tools/bake_clip_speeds.py.
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/zebraceratops; G=tools/gait/zebraceratops.json
T=$(mktemp -d); mkdir -p $T/x $T/g
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run -P tools/gait/make_gait.py -- $D/zebraceratops.glb $G walk $T/x/walk.glb
run -P tools/gait/make_gait.py -- $D/zebraceratops.glb $G run $T/x/run.glb
# sidesteps and backing up: the trot's foot plan carried sideways / backwards with a shorter stride (0.3, natural ~1.03 m/s)
run -P tools/gait/make_gait.py -- $D/zebraceratops.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0 --set stride=0.3
run -P tools/gait/make_gait.py -- $D/zebraceratops.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0 --set stride=0.3
run -P tools/gait/make_gait.py -- $D/zebraceratops.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.3
# a frame whose toe-roll dips the skin under the floor lifts the root by the deficit (STEGOFIX tool)
for f in $T/x/*.glb; do run -P tools/gait/ground_clip.py -- $D/zebraceratops.glb $f $T/g/$(basename $f); done
cp $T/g/*.glb $D/anim/
"$BL" -b -P tools/gait/check_zebra.py -- $D/zebraceratops.glb $D/anim --height 1.8 2>&1 | grep -E '^(CLIP|ZEBRA_CHECK)'
