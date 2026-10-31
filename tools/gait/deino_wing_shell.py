"""DEINOARMS: build each folded wing as its own skinned piece on the arm.

The v5 Tripo mesh (task 88864bcb) fuses the folded wings into the flank skin, so no shell can be picked out and an arm
swing would only drag the flank. Here the wing region (the side-view outline WING below, mesh units of the transplanted
rig, which faces -Y with z up, on both flanks at |x| > --xmin) is duplicated as a separate shell pushed --off out along
the normals and skinned to the arm: FrontUpLeg at the shoulder edge, blending to FrontLowLeg toward the wing tip, so a
flare lifts the whole wing off the flank and an elbow fold bends it. The flank under it keeps its torso weights (and the
painted feathers), so nothing tears open when the wing lifts.

usage: Blender -b -P tools/gait/deino_wing_shell.py -- <in.glb> <out.glb> [--xmin 0.035] [--off 0.004]
"""
import sys

import bmesh
import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = a[0], a[1]
opt = lambda k, d: float(a[a.index(k) + 1]) if k in a else d
XMIN, OFF = opt("--xmin", 0.035), opt("--off", 0.004)
# ASSUMPTION: the folded wing's outline in the side view (y, z), read off a render of the v5 rig.
WING = [(-0.314, 0.322), (-0.212, 0.358), (-0.164, 0.31), (-0.11, 0.232), (-0.164, 0.184), (-0.248, 0.202), (-0.308, 0.25)]
ROOT, TIP = Vector((-0.31, 0.33)), Vector((-0.11, 0.23))  # shoulder edge -> wing tip


def inside(y, z):
    c = False
    for (y0, z0), (y1, z1) in zip(WING, WING[1:] + WING[:1]):
        if (z0 > z) != (z1 > z) and y < (y1 - y0) * (z - z0) / (z1 - z0) + y0:
            c = not c
    return c


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm), key=lambda o: len(o.data.vertices))
bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
mw = ob.matrix_world
sel = {s: [f for f in bm.faces if all(inside((mw @ v.co).y, (mw @ v.co).z) and (mw @ v.co).x * sg > XMIN for v in f.verts)]
       for s, sg in (("L", 1.0), ("R", -1.0))}
dl = bm.verts.layers.deform.verify()
gidx = {n: (ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n)).index for s in "LR" for n in ("FrontUpLeg." + s, "FrontLowLeg." + s)}
axis = TIP - ROOT
for s, faces in sel.items():
    out = bmesh.ops.duplicate(bm, geom=faces)
    nv = [g for g in out["geom"] if isinstance(g, bmesh.types.BMVert)]
    bm.normal_update()
    for v in nv:
        v.co += v.normal * OFF
        w = mw @ v.co
        t = max(0.0, min(1.0, (Vector((w.y, w.z)) - ROOT).dot(axis) / axis.length_squared))
        t = t * t * (3 - 2 * t)
        d = v[dl]; d.clear()
        d[gidx["FrontUpLeg." + s]] = 1.0 - t
        if t > 1e-4:
            d[gidx["FrontLowLeg." + s]] = t
    print("WING SHELL", s, len(faces), "faces", len(nv), "verts")
    assert len(faces) > 100, "wing outline found too little skin on " + s
bm.to_mesh(ob.data); bm.free()
for o in list(bpy.data.objects):
    if o not in (arm, ob):
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", DST)
