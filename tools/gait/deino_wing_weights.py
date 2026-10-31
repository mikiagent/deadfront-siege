"""SP-DEINONYCHUS: skin the folded wings to the arms.

The Tripo mesh from the owner's sheet carries each folded wing (dark barred feathers on the tucked arm) as its own
shell lying on the flank; the transplant gave those shells torso and thigh weights, so the arm bones moved nothing
(FrontLeg/FrontUpLeg/FrontLowLeg/FrontFoot together held 54 of 17k vertices). Here every vertex of the wing shells
(the big islands off the main body, centred at |x| > --mid and ahead of Tail2) goes to its side's arm: FrontUpLeg at
the shoulder edge blending to FrontLowLeg toward the wing tip, so an arm swing or flare swings the whole wing, and an
elbow fold bends it. Vertices the transplant left unweighted copy their nearest weighted neighbour. Main-body skin within --hand of the forearm/hand bones goes to those bones (the claws).

usage: Blender -b -P tools/gait/deino_wing_weights.py -- <in.glb> <out.glb> [--mid 0.035] [--min-verts 150] [--hand 0.03]
"""
import sys

import bmesh
import bpy
from mathutils.geometry import intersect_point_line

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = a[0], a[1]
opt = lambda k, d: float(a[a.index(k) + 1]) if k in a else d
MID, MINV, HAND = opt("--mid", 0.035), int(opt("--min-verts", 150)), opt("--hand", 0.03)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm), key=lambda o: len(o.data.vertices))
bones = arm.data.bones
tail_y = bones["Tail2"].head_local.y  # this rig faces -Y: the wings sit ahead of the tail; the fan shells behind it
inv = arm.matrix_world.inverted()
P = [inv @ (ob.matrix_world @ v.co) for v in ob.data.vertices]

# islands by shared position (UV-seam duplicates are separate vertices with the same position)
bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table()
key = lambda co: (round(co.x, 6), round(co.y, 6), round(co.z, 6))
parent = list(range(len(bm.verts)))
def find(i):
    while parent[i] != i:
        parent[i] = parent[parent[i]]; i = parent[i]
    return i
first = {}
for v in bm.verts:
    k = key(v.co)
    if k in first: parent[find(v.index)] = find(first[k])
    else: first[k] = v.index
for e in bm.edges:
    parent[find(e.verts[0].index)] = find(e.verts[1].index)
comps = {}
for i in range(len(bm.verts)): comps.setdefault(find(i), []).append(i)
main = max(comps.values(), key=len)
groups = {n: (ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n)) for s in "LR" for n in
          ("FrontUpLeg." + s, "FrontLowLeg." + s, "FrontFoot." + s)}


def set_only(i, ws):
    for g in list(ob.data.vertices[i].groups):
        ob.vertex_groups[g.group].remove([i])
    for k, w in ws.items():
        if w > 1e-4: groups[k].add([i], w, "REPLACE")


wing = 0
for c in comps.values():
    if c is main or len(c) < MINV: continue
    cx = sum(P[i].x for i in c) / len(c); cy = sum(P[i].y for i in c) / len(c)
    if abs(cx) < MID or cy > tail_y: continue  # the tail fan and spine shells stay as they are
    s = "L" if cx > 0 else "R"
    ys = [P[i].y for i in c]; y0, y1 = min(ys), max(ys)
    for i in c:
        t = (P[i].y - y0) / max(y1 - y0, 1e-6)  # 0 at the shoulder (front) edge, 1 at the wing tip (rear)
        t = t * t * (3 - 2 * t)
        set_only(i, {"FrontUpLeg." + s: 1 - t, "FrontLowLeg." + s: t})
    wing += len(c)
    print("WING", s, len(c), "verts, y", round(y0, 3), round(y1, 3))
hand = 0
for i in main:
    p = P[i]
    for s in "LR":
        best = None
        for n in ("FrontLowLeg." + s, "FrontFoot." + s):
            b = bones[n]
            q, t = intersect_point_line(p, b.head_local, b.tail_local)
            t = min(max(t, 0.0), 1.0); d = (p - (b.head_local + (b.tail_local - b.head_local) * t)).length
            if d < HAND and (best is None or d < best[1]): best = (n, d)
        if best and abs(p.x) > 0.02:
            set_only(i, {best[0]: 1.0}); hand += 1
# vertices the transplant left unweighted (the importer's neutral_bone; they tore off the tail fan 60-130x in every
# clip) take the weights of the nearest weighted vertex
from mathutils.kdtree import KDTree
nb = ob.vertex_groups.get("neutral_bone")
bare = lambda v: not any(g.weight > 0 and (nb is None or g.group != nb.index) for g in v.groups)
kd = KDTree(len(P)); n = 0
for v in ob.data.vertices:
    if not bare(v): kd.insert(P[v.index], v.index); n += 1
kd.balance(); fixed = 0
for v in ob.data.vertices:
    if bare(v):
        j = kd.find(P[v.index])[1]
        set_only(v.index, {})
        for g in ob.data.vertices[j].groups:
            ob.vertex_groups[g.group].add([v.index], g.weight, "REPLACE")
        fixed += 1
print("WING WEIGHTS wing", wing, "hand", hand, "unweighted fixed", fixed)
for o in list(bpy.data.objects):
    if o not in (arm, ob):
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", DST)
