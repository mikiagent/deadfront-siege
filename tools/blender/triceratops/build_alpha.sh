#!/usr/bin/env bash
# SP-TRIKEALPHA: rebuild the Alpha triceratops body, rig, 16 clips and saddle from its Tripo mesh.
# Input (gitignored, re-download with Tripo task b48de3cb-10cd-4302-a5f8-591494609b18): $1 = tripo_alpha.glb
#   tools/blender/triceratops/build_alpha.sh <tripo_alpha.glb> [workdir]
# Same scripts as the regular triceratops, switched by env: joints_alpha.py (joints + weighting tunables),
# clips_alpha.py (the nine regular clips plus walk_back, strafes, charge, feed, sleep, toss).
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../.." && pwd)"
B=/Applications/Blender.app/Contents/MacOS/Blender
SRC="$1"; W="${2:-$(mktemp -d)}"; D="$ROOT/game/assets/creatures/triceratops/alpha"
export TRIKE_JOINTS=joints_alpha TRIKE_CLIPS=clips_alpha TRIKE_NAME=triceratops_alpha
"$B" -b --factory-startup -P "$HERE/prep.py" -- "$SRC" "$W/prep.blend" 10.927 | grep PREP   # 4.645 m to the frill top
"$B" -b "$W/prep.blend" --factory-startup -P "$HERE/build_rig.py" -- "$W/rig.blend" | grep -E "SAVED|Error"
"$B" -b "$W/rig.blend" --factory-startup -P "$HERE/bake.py" -- "$W/anim.blend" "$W/stats.json" | grep -E "^CLIP|Error"
"$B" -b "$W/anim.blend" --factory-startup -P "$HERE/matte.py" -- "$W/anim_m.blend" "$W/ORM_alpha_matte.jpg" | grep MATTE
"$B" -b "$W/anim_m.blend" --factory-startup -P "$HERE/export.py" -- "$D" | grep -c WROTE
for c in knockdown death sleep; do   # the lying clips dip a toe 1-3 cm while falling
  "$B" -b -P "$ROOT/tools/gait/ground_clip.py" -- "$D/triceratops_alpha.glb" "$D/anim/$c.glb" "$W/$c.glb" | grep WROTE; cp "$W/$c.glb" "$D/anim/$c.glb"
done
mkdir -p "$D/mount"
"$B" -b --factory-startup -P "$ROOT/tools/blender/saddles/build_saddles.py" -- --species=triceratops --height=4.645 \
  --glb="$D/triceratops_alpha.glb" --out-dir="$D/mount" | grep -E '^\[saddle\]'
"$B" -b --factory-startup -P "$ROOT/tools/blender/saddles/mount_to_model_space.py" -- "$D/triceratops_alpha.glb" "$D/mount/mount.json" | grep RIDER_IN_MOUNT
"$B" -b -P "$ROOT/tools/gait/check_trike.py" -- "$D/triceratops_alpha.glb" "$D/anim" --height 4.645 | grep TRIKE_CHECK
echo "BUILD OK ($W)"
