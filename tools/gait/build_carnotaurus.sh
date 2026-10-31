#!/bin/bash
# SP-CARNOTAURUS: rebuild the carnotaurus base (jaw), its alpha skin and every clip. Inputs under
# game/assets/creatures/carnotaurus/work/ (gitignored): carnotaurus_tripo_v2.glb (Tripo task 489df448) and the transplant
#   tools/transplant_rig.py --mesh work/carnotaurus_tripo_v2.glb --donor tools/standins/quaternius/Velociraptor.fbx
#     --species carnotaurus --leg 0.075,-0.125,0.235 0.076,-0.10,0.11 0.08,-0.095,0.012 0.085,-0.215,0.008
#     --map Attack=attack_primary Jump=attack_heavy Death=death Idle=idle Run=run Walk=walk
# saved as work/transplant_base.glb + work/transplant_anim/*.glb. The --leg joints are read off the mesh: hip in the
# thigh, the hock where the shin meets the near-vertical metatarsus, the heel under that column (so the whole sole is the foot bone: an ankle at the ball left the heel pad on the metatarsus, which pushed it 0.1 m into the floor whenever the hock bent) and the toe tip.
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/carnotaurus; G=tools/gait/carnotaurus.json; V=game/assets/creatures/velociraptor
T=$(mktemp -d)
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
# base: a Jaw bone. The Tripo mouth is modelled open; --x-side keeps +X opening (a level jaw came out with X flipped)
run --python tools/jaw/add_jaw.py -- $D/work/transplant_base.glb $D/carnotaurus.glb --open --x-side --pivot 0.071 0.36 --split -5 --blend 0.01
# alpha skin (owner sheet 2): rust and black, baked from the regular map
run -P tools/gait/make_carno_alpha_skin.py -- $D/carnotaurus.glb $D/carnotaurus_alpha_albedo.jpg
mkdir -p $T/x $T/j $T/g
# donor clips: knockdown and death (the collapse); the donor idle/hit_react kept the raptor's feet off this rig's prints
cp $D/work/transplant_anim/{knockdown,death}.glb $T/x/
# sleep: the velociraptor's (same donor skeleton)
run -P tools/gait/transfer_clips.py -- $V/velociraptor.glb $D/carnotaurus.glb $T/x $V/anim/sleep.glb
# gaits: walk, run, the head-low horn charge, strafes and walk_back
run -P tools/gait/make_gait.py -- $D/carnotaurus.glb $G walk $T/x/walk.glb
run -P tools/gait/make_gait.py -- $D/carnotaurus.glb $G run $T/x/run.glb
run -P tools/gait/make_gait.py -- $D/carnotaurus.glb $G charge $T/x/charge.glb
run -P tools/gait/make_gait.py -- $D/carnotaurus.glb $G walk $T/x/strafe_left.glb --as strafe_left --travel 1,0,0
run -P tools/gait/make_gait.py -- $D/carnotaurus.glb $G walk $T/x/strafe_right.glb --as strafe_right --travel -1,0,0
run -P tools/gait/make_gait.py -- $D/carnotaurus.glb $G walk $T/x/walk_back.glb --as walk_back --travel 0,1,0 --set stride=0.14
# the fight one-shots (snap bite, horn ram, the charge's sharp turn, roar) and idle, hit_react, feed (jaw keyed inside)
for c in attack_primary attack_heavy charge_turn alert idle hit_react feed; do run -P tools/gait/make_carno_moves.py -- $D/carnotaurus.glb $c $T/x/$c.glb; done
# any frame whose skin dips under the floor lifts the root by the deficit (STEGOFIX tool)
for f in $T/x/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/carnotaurus.glb $T/x/$c.glb $T/g/$c.glb --fps 24; cp $T/g/$c.glb $T/x/; done
cp $T/x/*.glb $D/anim/
ls $D/anim/*.glb | wc -l
echo "BUILD OK ($T)"
