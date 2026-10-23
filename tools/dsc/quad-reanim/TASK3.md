# Task: re-export the quadruped clips WITH the skin, skeleton-only

The previous re-export removed the mesh correctly but also removed the glTF skin. Without a skin Godot imports
the bones as plain nodes, so in the game every track ("Armature/root/...") fails to resolve and the clip plays as a
frozen rest pose. The input clips (input/<species>/anim/*.glb) have exactly 1 skin, 0 meshes, 0 images.

Do: for protoceratops and megaloceros, re-export every clip in out/<species>/anim/*.glb (except walk.glb and
run.glb, which the game keeps from the input; copy the input walk/run over yours) so that each file has the SAME
structure as the matching input clip: 1 skin with the same joint count, the same node count and names, 0 meshes,
0 materials, 0 images, exactly 1 animation. Keep every keyframe and timing. Easiest route: import the input clip
to get the skinned armature, transfer your Action onto it, export with skins on and mesh export off (the input
clip's own export already has this shape). Headless Blender only. Run ./verify3.sh until it exits 0, then add a
"Re-export with skin" note to out/REPORT.md.
