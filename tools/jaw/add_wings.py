#!/usr/bin/env python3
"""Give a feathered raptor real wings: two fans of feather blades on new Wing.L / Wing.R bones.

Generated meshes fuse folded wing feathers into the chest, so rotating the arm bones only balloons the body. These
fans are separate geometry: at rest they lie flat over the painted wing (and take its texture from the hide right
under them), and a clip rotates Wing.* to flare them out. Existing clips have no Wing keys, so they stay folded.

  Blender -b --python tools/jaw/add_wings.py -- <in.glb> <out.glb> [--root FrontUpLeg] [--parent FrontLeg]
      [--feathers 11] [--length 0.30] [--width 0.05]

Lengths are in mesh units. The fans are joined into the body mesh with its own material, as thin solid blades so both sides render.
"""
import argparse, math, sys
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ap = argparse.ArgumentParser()
ap.add_argument("inp"); ap.add_argument("out")
ap.add_argument("--root", default="FrontUpLeg", help="the fan grows from this bone's head (the shoulder)")
ap.add_argument("--parent", default="FrontLeg")
ap.add_argument("--feathers", type=int, default=11)
ap.add_argument("--length", type=float, default=0.30)
ap.add_argument("--width", type=float, default=0.05)
ap.add_argument("--pale", type=float, default=0.45, help="hide brighter than this is belly/leg skin, not feathers")
ap.add_argument("--lift", type=float, default=0.012, help="gap between the folded fan and the hide")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm), key=lambda o: len(o.data.vertices))
mw = ob.matrix_world; inv = mw.inverted()

# body surface for placing the folded fan and borrowing its texture
dg = bpy.context.evaluated_depsgraph_get()
bm0 = bmesh.new(); bm0.from_mesh(ob.data); bm0.transform(mw)
bvh = BVHTree.FromBMesh(bm0)
uvl0 = bm0.loops.layers.uv.active
bm0.faces.ensure_lookup_table()

def surface(p):
    """Nearest hide point, its normal and the UV there."""
    loc, nrm, idx, _ = bvh.find_nearest(p)
    f = bm0.faces[idx]
    lo = min(f.loops, key=lambda l: (l.vert.co - loc).length)  # shortcut: nearest corner's UV, fine for feather texture
    return loc, nrm, lo[uvl0].uv.copy()

# the body texture: feathers must not borrow the pale belly or leg skin they hang over
img = next((n.image for m in ob.data.materials if m and m.use_nodes for n in m.node_tree.nodes
            if n.type == "TEX_IMAGE" and n.image), None)
PX = img.pixels[:] if img else None
def lum(uv):
    if PX is None: return 0.0
    W, H = img.size; k = (int(min(max(uv.y, 0), .9999) * H) * W + int(min(max(uv.x, 0), .9999) * W)) * 4
    return 0.3 * PX[k] + 0.6 * PX[k + 1] + 0.1 * PX[k + 2]
FEATHER_UV = []  # dark (feathered) UVs met so far, reused where the hide underneath is pale

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
wing_bones = {}
for side, sgn in (("L", 1), ("R", -1)):
    r = eb[f"{a.root}.{side}"]
    head = r.head.copy()
    b = eb.new(f"Wing.{side}")
    b.head = head
    b.tail = head + Vector((0, 0.6, -0.5)).normalized() * a.length  # folded: back and down along the flank
    b.roll = 0
    b.parent = eb[f"{a.parent}.{side}"]
    wing_bones[side] = (arm.matrix_world @ head.copy(), sgn)
bpy.ops.object.mode_set(mode="OBJECT")

fan = bmesh.new()
uvl = fan.loops.layers.uv.new("UVMap")
dl = fan.verts.layers.deform.new()
gidx = {}
for side in ("L", "R"):
    g = ob.vertex_groups.get(f"Wing.{side}") or ob.vertex_groups.new(name=f"Wing.{side}")
    gidx[side] = g.index
for side, (root, sgn) in wing_bones.items():
    n = a.feathers
    for k in range(n):
        # feathers splay from pointing down-back (k=0) to pointing straight back (k=n-1); outer ones longer
        ang = math.radians(-70 + 62 * k / (n - 1))
        d = Vector((0, math.cos(ang), math.sin(ang)))
        length = a.length * (0.75 + 0.35 * math.sin(math.pi * (k + 0.5) / n))
        width = a.width * (1.0 - 0.3 * k / n)
        perp = Vector((0, -math.sin(ang), math.cos(ang)))
        rows = []
        for t in (0.0, 0.33, 0.66, 1.0):
            centre = root + d * (length * t)
            w = width * (0.35 + 0.65 * math.sin(math.pi * min(t, 0.95) * 0.9 + 0.3)) * (0.12 if t == 1.0 else 1.0)  # pointed tip
            row = []
            for e in (-0.5, 0.5):
                p = centre + perp * (w * e)
                loc, nrm, uv = surface(p)
                if t == 0.0 and e < 0:  # one coherent texture strip per feather, taken where it leaves the arm
                    base = uv if lum(uv) < a.pale or not FEATHER_UV else FEATHER_UV[k % len(FEATHER_UV)]
                    if lum(uv) < a.pale: FEATHER_UV.append(uv.copy())
                uv = base + Vector((0.03 * t, 0.006 * (e + 0.5)))
                q = loc + nrm.normalized() * (a.lift + 0.002 * k)  # layered, outer feathers on top
                if (q.x - 0) * sgn < 0.01: q.x = 0.01 * sgn  # never cross the midline
                v = fan.verts.new(inv @ q)
                v[dl][gidx[side]] = 1.0
                row.append((v, uv))
            rows.append(row)
        for r0, r1 in zip(rows, rows[1:]):
            quad = [r0[0], r0[1], r1[1], r1[0]]
            f = fan.faces.new([v for v, _ in quad])
            for lo, (_, uv) in zip(f.loops, quad): lo[uvl].uv = uv
fan_me = bpy.data.meshes.new("wings"); fan.to_mesh(fan_me); fan.free()
wo = bpy.data.objects.new("wings", fan_me); bpy.context.scene.collection.objects.link(wo)
for g in ob.vertex_groups: wo.vertex_groups.new(name=g.name)
# copy weights from the bmesh deform layer: vertex groups by index match because names were added in order
fan_me.materials.append(ob.data.materials[0])
bm = bmesh.new(); bm.from_mesh(fan_me); bm.to_mesh(fan_me); bm.free()
bpy.context.view_layer.objects.active = wo
sol = wo.modifiers.new("thick", "SOLIDIFY"); sol.thickness = 0.003; sol.offset = 0  # a thin blade: both sides render
bpy.ops.object.modifier_apply(modifier=sol.name)
wo.parent = arm; mod = wo.modifiers.new("Armature", "ARMATURE"); mod.object = arm
bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); wo.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.object.join()
print(f"WINGS {2 * a.feathers} feathers, {len(fan_me.vertices) if fan_me.users else 'joined'}; bones Wing.L Wing.R under {a.parent}.*")

for o in list(bpy.data.objects):
    if o.type == "MESH" and o.parent is None: bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", a.out)
