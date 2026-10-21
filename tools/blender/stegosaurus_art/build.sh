#!/usr/bin/env bash
# STEGO-ART: rebuild game/assets/creatures/stegosaurus/stegosaurus.glb from the committed Stegosaurus v2 GLB
# (four-spike thagomizer + sheet palette), check it, render the review shots and redo sheet.png. Headless Blender only.
#   tools/blender/stegosaurus_art/build.sh [out_dir_for_renders]
# Then import in Godot (it re-extracts stegosaurus_tex_graded_albedo.jpg from the GLB).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(git -C "$HERE" rev-parse --show-toplevel)
BL=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
V2_COMMIT=662dc0d2   # "Add survivor v2, three armor kits, Stegosaurus v2 ..." (the v2 GLB as shipped)
ASSET=game/assets/creatures/stegosaurus/stegosaurus.glb
OUT=${1:-$(mktemp -d)}
mkdir -p "$OUT"
git -C "$ROOT" show "$V2_COMMIT:$ASSET" > "$OUT/v2.glb"
run() { "$BL" -b --factory-startup --python-exit-code 1 -P "$HERE/$1" -- "${@:2}" 2>&1 | { grep -E '^\[|PASS|FAIL|CHECK|Error|Traceback|line [0-9]' || true; }; }
run fix_thagomizer.py "$OUT/v2.glb" "$OUT/spikes.glb"
run recolour.py "$OUT/spikes.glb" "$OUT/stegosaurus.glb"
run verify.py "$OUT/v2.glb" "$OUT/stegosaurus.glb"
cp "$OUT/stegosaurus.glb" "$ROOT/$ASSET"
run render_tail.py "$ROOT/$ASSET" "$OUT/steg"
run sheet.py "$ROOT/$ASSET" "$ROOT/game/assets/creatures/stegosaurus/anim" "$ROOT/game/assets/creatures/stegosaurus/sheet.png"
echo "build.sh: wrote $ROOT/$ASSET; renders in $OUT"
