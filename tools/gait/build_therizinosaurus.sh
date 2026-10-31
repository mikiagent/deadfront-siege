#!/bin/bash
# SP-THERIZINOSAURUS (owner 2026-10-31, sheet: "use this for the therezino"): build the therizinosaurus from the Tripo v1
# mesh (task 65b2aab3-3547-48b0-a1c2-923f7cb395e0, kept as work/therizinosaurus_tripo_v1.glb, gitignored; the task id
# re-downloads it):
#   1. tools/gait/rig_biped.py: hand-placed skeleton (tools/gait/therizinosaurus_rig.json) incl. Claw bones, heat weights
#   2. tools/jaw/add_jaw.py: Jaw bone + lower-beak skin (the beak is modelled parted; --split -8 keeps the upper beak whole)
#   3. gaits from tools/gait/therizinosaurus.json (walk, run, strafes, walk_back)
#   4. fight moves, idle, feed, sleep from tools/gait/make_theri_moves.py (jaw keyed there)
#   5. ground_clip.py lifts any frame whose skin dips under the floor
# Gate: Blender -b -P tools/gait/check_theri.py -- $D/therizinosaurus.glb $D/anim --height 8.0
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/therizinosaurus; G=tools/gait/therizinosaurus.json
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run -P tools/gait/rig_biped.py -- $D/work/therizinosaurus_tripo_v1.glb tools/gait/therizinosaurus_rig.json $T/rig.glb
run -P tools/jaw/add_jaw.py -- $T/rig.glb $D/therizinosaurus.glb --open --pivot 0.07 0.545 --split -8 --mid 0.3 --reach 1.0
mkdir -p $T/x $T/g
pids=()
run -P tools/gait/make_gait.py -- $D/therizinosaurus.glb $G walk $T/x/walk.glb & pids+=($!)
run -P tools/gait/make_gait.py -- $D/therizinosaurus.glb $G run $T/x/run.glb & pids+=($!)
run -P tools/gait/make_gait.py -- $D/therizinosaurus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0 --set stride=0.2 & pids+=($!)
run -P tools/gait/make_gait.py -- $D/therizinosaurus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0 --set stride=0.2 & pids+=($!)
run -P tools/gait/make_gait.py -- $D/therizinosaurus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.2 & pids+=($!)
for c in idle alert attack_primary attack_heavy bite_combo hit_react knockdown death sleep feed; do
  run -P tools/gait/make_theri_moves.py -- $D/therizinosaurus.glb $c $T/x/$c.glb & pids+=($!)
done
for p in "${pids[@]}"; do wait $p; done
for f in $T/x/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/therizinosaurus.glb $f $T/g/$c.glb --fps 24; done
rm -f $D/anim/*.glb
cp $T/g/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
