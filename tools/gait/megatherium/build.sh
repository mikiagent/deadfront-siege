#!/bin/bash
# SP-MEGATHERIUM: rebuild the giant ground sloth body, rig and every clip, then gate them.
# Input (gitignored, re-download with the Tripo task id in megatherium.json pipeline): work/megatherium_tripo_v1.glb
set -euo pipefail
cd "$(dirname "$0")/../../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/megatherium; M=tools/gait/megatherium
T=${T:-$(mktemp -d)}; mkdir -p "$T"
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run -P $M/build_rig.py -- $D/work/megatherium_tripo_v1.glb $M/sloth.json $T/rig.blend $D/megatherium.glb
run -P $M/clips.py -- $T/rig.blend $T/anim
# a frame whose skin dips under the floor lifts the root by the deficit (STEGOFIX tool)
mkdir -p $T/g $D/anim
for f in $T/anim/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/megatherium.glb $f $T/g/$c.glb --fps 24; done
rm -f $D/anim/*.glb; cp $T/g/*.glb $D/anim/
echo "clips: $(ls $D/anim/*.glb | wc -l) ($T)"
"$BL" -b -P tools/gait/check_megatherium.py -- $D/megatherium.glb $D/anim --height 3.39 2>&1 | grep -E "^CLIP|SLOTH_CHECK"
