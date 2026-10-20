# Task: re-export the quadruped clips skeleton-only

The game's clip loader rejected every clip in out/<species>/anim/ ("missing idle", "missing walk", ...).
Cause: each clip GLB embeds the mesh, materials and textures (43 nodes and image data), while the game's
clips are armature-only (the input clips in input/<species>/anim/ have 40 nodes, no meshes, no images).
The raptor job exported armature-only and loaded fine.

Do: for protoceratops and megaloceros, re-export every clip in out/<species>/anim/*.glb so each file holds
ONLY the armature (same node names and hierarchy as the matching input clip) and its single animation.
No mesh, no skin, no materials, no images. Do not change any keyframe, timing or the mesh file
out/<species>/<species>.glb. Use headless Blender only. Then run ./verify2.sh until it exits 0, and add a
short "Re-export" section to out/REPORT.md.
