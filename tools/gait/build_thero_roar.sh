#!/bin/bash
# THERO-ROAR: author the shared rearing roar (anim/roar.glb) and the spacing stomp (anim/spacing_stomp.glb) for every big theropod in tools/gait/thero_roar.json, or the
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
  for c in roar spacing_stomp; do
    "$BL" -b -P tools/gait/make_thero_roar.py -- $D/$s.glb $s $T/${s}_$c.glb $c > $T/make_${s}_$c.log 2>&1 || { echo "FAILED make $s $c"; tail -5 $T/make_${s}_$c.log; exit 1; }
    grep THEROROAR $T/make_${s}_$c.log
    "$BL" -b -P tools/gait/ground_clip.py -- $D/$s.glb $T/${s}_$c.glb $D/anim/$c.glb --fps 24 > $T/ground_${s}_$c.log 2>&1 || { echo "FAILED ground $s $c"; exit 1; }
    out=$("$BL" -b -P tools/gait/check_thero_roar.py -- $D/$s.glb $D/anim/$c.glb --height $H 2>&1 | grep THEROROAR_CHECK)
    echo "$s: $out"
    echo "$out" | grep -q "CHECK PASS" || fail=1
  done
done
[ $fail = 0 ] && echo "BUILD OK" || { echo "BUILD FAIL"; exit 1; }
