#!/usr/bin/env bash
# Build the saddle for one species (or all of them) and finish its mount.json.
#   tools/blender/saddles/build.sh protoceratops
#   tools/blender/saddles/build.sh --all
# Needs Blender 5.x with the glTF importer (headless, --factory-startup) and python3.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
B=/Applications/Blender.app/Contents/MacOS/Blender
SPECIES="$1"
if [ "$SPECIES" = "--all" ]; then
  SPECIES="$(python3 - "$HERE/saddles.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(" ".join(s for s in d["species"]))
PY
)"
fi
for s in $SPECIES; do
  h="$(python3 - "$ROOT/game/data/creatures/$s.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["height_meters"])
PY
)"
  "$B" -b --factory-startup -P "$HERE/build_saddles.py" -- --species="$s" --height="$h" \
    2>&1 | grep -E '^\[saddle\]|^\[part\]|Error|Traceback' || true
  "$B" -b --factory-startup -P "$HERE/mount_to_model_space.py" -- \
    "$ROOT/game/assets/creatures/$s/$s.glb" "$ROOT/game/assets/creatures/$s/mount/mount.json" \
    2>&1 | grep -E 'RIDER_IN_MOUNT|Error|Traceback' || true
done
