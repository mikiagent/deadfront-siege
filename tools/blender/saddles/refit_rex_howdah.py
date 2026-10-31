"""SP-TYRANNOSAURUS: carry the T. rex howdah (mount/saddle.glb, hand-built for the v1 rig) onto the v2 rig.

Each saddle vertex moves with the bones it is weighted to, from the old rest pose to the new one (the bones keep
their names and roll), then the howdah slides back off the v2 neck hump and rises until it rests on the back.
The rider offset (relative to the socket bone) gets the same shift, and
rider_in_mount is rewritten in the new mount's model space (as mount_to_model_space.py does).

  Blender -b -P tools/blender/saddles/refit_rex_howdah.py -- <old_base.glb> <new_base.glb> <saddle.glb> <mount.json>
"""
import json
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

OLD, NEW, SADDLE, MJ = sys.argv[sys.argv.index("--") + 1:][:4]
bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = set(bpy.data.objects) - before
    arm = next(o for o in objs if o.type == "ARMATURE")
    shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
    meshes = [o for o in objs if o.type == "MESH" and o not in shapes]
    for o in objs:
        if o in shapes or (o.type == "MESH" and o.name.startswith("Icosphere")):
            bpy.data.objects.remove(o)
    return arm, meshes


def bvh(o):
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg)
    me = e.to_mesh()
    t = BVHTree.FromPolygons([o.matrix_world @ v.co for v in me.vertices], [p.vertices[:] for p in me.polygons])
    e.to_mesh_clear()
    return t


old_arm, old_m = load(OLD)
new_arm, new_m = load(NEW)
sad_arm, sad_m = load(SADDLE)
saddle = max(sad_m, key=lambda o: len(o.data.vertices))
old_skin = max(old_m, key=lambda o: len(o.data.vertices))
new_skin = max(new_m, key=lambda o: len(o.data.vertices))


def rest(arm, n):
    return arm.matrix_world @ arm.data.bones[n].matrix_local


move = {b.name: rest(new_arm, b.name) @ rest(old_arm, b.name).inverted() for b in old_arm.data.bones if b.name in new_arm.data.bones}
names = {g.index: g.name for g in saddle.vertex_groups}
mw = saddle.matrix_world.copy()
pts = []
for v in saddle.data.vertices:
    p = mw @ v.co
    acc, tot = Vector(), 0.0
    for g in v.groups:
        n = names[g.group]
        if g.weight > 0 and n in move:
            acc += g.weight * (move[n] @ p)
            tot += g.weight
    pts.append(acc / tot if tot > 0 else p)

# seat clearance: straight down from the saddle's centre to the back, old and new
new_bvh = bvh(new_skin)
# The v2 neck rises into a hump right behind the head, so the howdah carried to the new Spine2 sits half inside it:
# slide it BACK m along the spine to the flat of the back, then lift it until no part of it within LIFT_BAND of the
# back top is under the skin (straps hanging down the flanks are ignored), plus CLEAR.
BACK, LIFT_BAND, CLEAR, MID = 0.8, 0.45, 0.03, 0.9  # MID: only the pad over the spine counts (the girth hugs the flanks)
pts = [p - Vector((0, BACK, 0)) for p in pts]


def top(x, y):
    hit = new_bvh.ray_cast(Vector((x, y, 30)), Vector((0, 0, -1)))
    return hit[0].z if hit[0] is not None else -1e9


dz, worst = 0.0, None
for i, p in enumerate(pts):
    t = top(p.x, p.y)
    if names[max(saddle.data.vertices[i].groups, key=lambda g: g.weight).group].startswith("Neck"):
        continue  # the neck collar hugs the neck
    if abs(p.x) < MID and p.z > t - LIFT_BAND and t - p.z + CLEAR > dz:
        dz, worst = t - p.z + CLEAR, i
if worst is not None:
    g = max(saddle.data.vertices[worst].groups, key=lambda g: g.weight)
    print(f"howdah: deepest {tuple(round(x, 2) for x in pts[worst])} on {names[g.group]}")
print(f"howdah: slid back {BACK} m, lifted {dz:+.3f} m")
inv = mw.inverted()
for v, p in zip(saddle.data.vertices, pts):
    v.co = inv @ (p + Vector((0, 0, dz)))
SHIFT = Vector((0, -BACK, dz))

# put the saddle on the new armature and export like build_saddles.py
saddle.parent = new_arm
saddle.matrix_world = mw
for m in saddle.modifiers:
    if m.type == "ARMATURE":
        m.object = new_arm
bpy.data.objects.remove(sad_arm)
for o in old_m + [old_arm] + [m for m in new_m]:
    bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
new_arm.select_set(True)
saddle.select_set(True)
bpy.context.view_layer.objects.active = new_arm
bpy.ops.export_scene.gltf(filepath=SADDLE, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)

m = json.load(open(MJ))
o = m["rider_offset"]
O = Matrix([[o[c * 4 + r] for c in range(4)] for r in range(4)])
S = rest(new_arm, m["socket"])
O2 = S.inverted() @ Matrix.Translation(SHIFT) @ S @ O
m["rider_offset"] = [round(O2[r][c], 6) for c in range(4) for r in range(4)]
Rb = S @ O2
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))  # Blender Z-up -> glTF Y-up
Rg = C @ Rb @ C.inverted()
m["rider_in_mount"] = [Rg[r][c] for c in range(4) for r in range(4)]
m["notes"] = (m.get("notes", "") + "; SP-TYRANNOSAURUS: carried onto the v2 rig by tools/blender/saddles/refit_rex_howdah.py "
              "(each vertex with its bones, then %.1f m back off the neck hump and %+.2f m up onto the back)" % (BACK, dz))
json.dump(m, open(MJ, "w"), indent=1)
print("RIDER_IN_MOUNT pos", [round(Rg[i][3], 3) for i in range(3)])
