#!/bin/bash
# SP-MEGALOCEROS: rebuild both megaloceros bodies (stag, doe), their rigs and every clip.
# Inputs (gitignored, re-download with the Tripo task ids in megaloceros.json pipeline): work/megaloceros_{stag,doe}_tripo.glb
set -euo pipefail
cd "$(dirname "$0")/../../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
D=game/assets/creatures/megaloceros; M=tools/gait/megaloceros
T=${T:-$(mktemp -d)}
run() { "$BL" -b "$@" > "$T/log_$RANDOM.txt" 2>&1 || { echo "FAILED: $*"; exit 1; }; }
for v in stag doe; do
  if [ $v = stag ]; then base=$D/megaloceros.glb; anim=$D/anim; else mkdir -p $D/doe/anim; base=$D/doe/megaloceros_doe.glb; anim=$D/doe/anim; fi
  run -P $M/build_rig.py -- $D/work/megaloceros_${v}_tripo.glb $M/$v.json $T/$v.blend $base
  run -P $M/clips.py -- $T/$v.blend $T/${v}_anim $v
  # a frame whose skin dips under the floor lifts the root by the deficit (STEGOFIX tool)
  mkdir -p $T/${v}_g
  for f in $T/${v}_anim/*.glb; do c=$(basename $f .glb); run -P tools/gait/ground_clip.py -- $base $f $T/${v}_g/$c.glb; done
  rm -f $anim/*.glb; cp $T/${v}_g/*.glb $anim/
  echo "$v: $(ls $anim/*.glb | wc -l) clips"
done
echo "BUILD OK ($T)"
# saddles (both bodies; the doe's lives in doe/mount, model_variants.doe.mount)
tools/blender/saddles/build.sh megaloceros
"$BL" -b --factory-startup -P tools/blender/saddles/build_saddles.py -- --species=megaloceros --height=3.70 \
  --glb=$PWD/$D/doe/megaloceros_doe.glb --out-dir=$PWD/$D/doe/mount > "$T/log_saddle_doe.txt" 2>&1
"$BL" -b --factory-startup -P tools/blender/saddles/mount_to_model_space.py -- $PWD/$D/doe/megaloceros_doe.glb $PWD/$D/doe/mount/mount.json | grep RIDER_IN_MOUNT
