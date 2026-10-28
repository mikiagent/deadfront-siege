"""Convert a mount.json rider_offset (relative to the socket bone as Blender imports the mount) into
rider_in_mount: the rider's armature root in the mount's glTF model space (Y-up), rest pose. Run headless:

  Blender -b --python mount_to_model_space.py -- <mount.glb> <mount.json>

Blender's glTF importer re-orients bones, so a bone-relative offset measured in Blender is wrong in an engine
that uses the file's joint frames. Model space is the same everywhere; the engine derives the socket offset
itself from the bone's rest pose (see clip-viewer/mount.gd). Writes rider_in_mount (16 numbers,
column-major) into mount.json and prints it.
"""
import bpy, sys, json
from mathutils import Matrix
a = sys.argv[sys.argv.index("--") + 1:]; glb, mj = a[0], a[1]
m = json.load(open(mj))
bpy.ops.import_scene.gltf(filepath=glb)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
S = arm.matrix_world @ arm.data.bones[m["socket"]].matrix_local
o = m["rider_offset"]; O = Matrix([[o[c * 4 + r] for c in range(4)] for r in range(4)])
Rb = S @ O
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))  # Blender Z-up -> glTF Y-up
Rg = C @ Rb @ C.inverted()
m["rider_in_mount"] = [Rg[r][c] for c in range(4) for r in range(4)]
m["rider_in_mount_note"] = "rider armature root in the mount's glTF model space (Y-up), mount rest pose; preferred over rider_offset"
json.dump(m, open(mj, "w"), indent=1)
print("RIDER_IN_MOUNT pos", [round(Rg[i][3], 3) for i in range(3)])
