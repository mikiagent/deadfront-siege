#!/bin/bash
# SP-WOOLLY_RHINO: rebuild the woolly rhino body, rig and every clip, then gate them.
# Input (gitignored, re-download with the Tripo task id in woolly_rhino.json pipeline): work/woolly_rhino_tripo_v1.glb
set -euo pipefail
cd "$(dirname "$0")/../../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/woolly_rhino; M=tools/gait/woolly_rhino
T=${T:-$(mktemp -d)}; mkdir -p "$T"
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
run -P $M/build_rig.py -- $D/work/woolly_rhino_tripo_v1.glb $M/rhino.json $T/rig.blend $D/woolly_rhino.glb
run -P $M/clips.py -- $T/rig.blend $T/anim
# a frame whose skin dips under the floor lifts the root by the deficit (STEGOFIX tool)
mkdir -p $T/g $D/anim
for f in $T/anim/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $D/woolly_rhino.glb $f $T/g/$c.glb; done
rm -f $D/anim/*.glb; cp $T/g/*.glb $D/anim/
echo "clips: $(ls $D/anim/*.glb | wc -l) ($T)"
"$BL" -b -P tools/gait/check_woolly_rhino.py -- $D/woolly_rhino.glb $D/anim --height 2.95 2>&1 | grep -E "^CLIP|RHINO_CHECK"
