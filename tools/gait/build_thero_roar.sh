#!/bin/bash
# THERO-ROAR: author the shared rearing roar (anim/roar.glb) for every big theropod in tools/gait/thero_roar.json, or the
# species named: make_thero_roar.py, then ground_clip.py (a no-op unless the skin dips), then the gate.
# usage: tools/gait/build_thero_roar.sh [species ...]
set -euo pipefail
cd "$(dirname "$0")/../.."
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
T=$(mktemp -d)
SP=("$@")
[ ${#SP[@]} -eq 0 ] && SP=($(python3 -c "import json;print(' '.join(json.load(open('tools/gait/thero_roar.json'))['species']))"))
fail=0
for s in "${SP[@]}"; do
  D=game/assets/creatures/$s
  H=$(python3 -c "import json;print(json.load(open('game/data/creatures/$s.json'))['height_meters'])")
  "$BL" -b -P tools/gait/make_thero_roar.py -- $D/$s.glb $s $T/$s.glb > $T/make_$s.log 2>&1 || { echo "FAILED make $s"; tail -5 $T/make_$s.log; exit 1; }
  grep THEROROAR $T/make_$s.log
  "$BL" -b -P tools/gait/ground_clip.py -- $D/$s.glb $T/$s.glb $D/anim/roar.glb --fps 24 > $T/ground_$s.log 2>&1 || { echo "FAILED ground $s"; exit 1; }
  "$BL" -b -P tools/gait/check_thero_roar.py -- $D/$s.glb $D/anim/roar.glb --height $H 2>&1 | grep THEROROAR_CHECK | sed "s/^/$s: /"
  "$BL" -b -P tools/gait/check_thero_roar.py -- $D/$s.glb $D/anim/roar.glb --height $H 2>&1 | grep -q "CHECK PASS" || fail=1
done
[ $fail = 0 ] && echo "BUILD OK" || { echo "BUILD FAIL"; exit 1; }
