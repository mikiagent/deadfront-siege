"""Rig a raw Tripo biped mesh with a hand-placed T. rex-style skeleton (no donor, no warp).

Why (PACHY 2026-10-31): the landmark warp of a donor raptor put the pachycephalosaurus' hips, spine and tail 25 cm
off the body and the legs on a 3-bone raptor chain, so every clip crumpled the legs ("the legs are mangled"). Here
every joint is placed by hand from ortho renders of the mesh, the legs get the 4-bone dinosaur chain
(Thigh -> Shin -> Metatarsal -> Toe, as tools/gait/tyrannosaurus.json and check_rex_clips.py expect), and the skin is
bone-heat weighted on the repaired mesh (voxel proxy when heat leaves verts unweighted), then
- side-cleaned: a vertex left of the midline keeps no weight on .R bones and vice versa (the T. rex claw bug),
- leg-split: below --belly-z only the leg chain on the vertex's own side (and Hips) may hold weight, so a stride never
  drags belly or tail skin, and the toes/claws never ride the shin,
- capped at 4 influences and normalised.

The spec JSON (mesh units after orienting: head -Y, centred, feet on z=0; left = +x) gives joint points:
  {"spine": [[y,z] Hips, Spine1, Chest, Neck1, Neck2, Head, HeadTip],  "tail": [[y,z] Tail1 head ... tip],
   "leg": [[x,y,z] hip, knee, ankle, ball, toe tip],  "arm": [[x,y,z] shoulder, elbow, wrist, finger tip(, claw tip)],
   "jaw": [[y,z] pivot, tip], "belly_z": 0.17, "jaw_split": ...}
usage: Blender -b -P tools/gait/rig_biped.py -- <tripo.glb> <spec.json> <out.glb>
"""
import json
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC, SPEC, OUT = a[:3]
spec = json.load(open(SPEC))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
mesh = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
M0 = mesh.matrix_world.copy()
mesh.parent = None
mesh.matrix_world = Matrix.Identity(4)
mesh.data.transform(M0)
for o in list(bpy.data.objects):
    if o is not mesh:
        bpy.data.objects.remove(o)
for vg in list(mesh.vertex_groups):
    mesh.vertex_groups.remove(vg)


def bbox():
    vs = [v.co for v in mesh.data.vertices]
    return Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)])


# orient: Tripo multiview faces +X; the head goes to -Y (the transplant rigs' frame, glTF +Z forward)
mesh.data.transform(Matrix.Rotation(math.radians(spec.get("turn_deg", -90.0)), 4, "Z"))
lo, hi = bbox()
mesh.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
lo, hi = bbox()
print("RIG bbox", [round(v, 3) for v in lo], [round(v, 3) for v in hi])

# repair: weld duplicate seam verts so bone heat sees one surface (UVs stay on the loops)
bm = bmesh.new()
bm.from_mesh(mesh.data)
n0 = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=(hi.y - lo.y) * 2e-4)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh.data)
bm.free()
print("RIG welded", n0 - len(mesh.data.vertices), "verts left", len(mesh.data.vertices))
# spec "foot_level": z (mesh units): a foot whose lowest point floats above the floor (the allosaurus' right foot stood
# 0.0039 above the left in the Tripo mesh, 5.6 cm in game) is lowered onto it, fading out up to this height
if spec.get("foot_level"):
    top = float(spec["foot_level"])
    for sgn in (1, -1):
        vs = [v for v in mesh.data.vertices if v.co.x * sgn > 0.01]
        dz = min(v.co.z for v in vs)
        for v in vs:
            if v.co.z < top:
                v.co.z -= dz * (1.0 - v.co.z / top)
        print("RIG foot_level", "L" if sgn > 0 else "R", round(dz, 4))
if "--orient-only" in a:
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True)
    sys.exit(0)

# ---------------------------------------------------------------- skeleton
ad = bpy.data.armatures.new("Armature")
arm = bpy.data.objects.new("Armature", ad)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = ad.edit_bones


def bone(name, head, tail, parent=None, deform=True, connect=False):
    b = eb.new(name)
    b.head, b.tail = Vector(head), Vector(tail)
    b.roll = 0.0
    if parent:
        b.parent = eb[parent]
        b.use_connect = connect
    b.use_deform = deform
    return b


def yz(p):
    return Vector((0.0, p[0], p[1]))


sp = [yz(p) for p in spec["spine"]]
hip = sp[0]
bone("root", (0, hip.y, 0), (0, hip.y, 0.1), deform=False)
names = ["Hips", "Spine1", "Chest", "Neck1", "Neck2", "Head"]
for i, n in enumerate(names):
    bone(n, sp[i], sp[i + 1], "root" if i == 0 else names[i - 1], connect=i > 0)
tl = [yz(p) for p in spec["tail"]]
for i in range(len(tl) - 1):
    bone("Tail%d" % (i + 1), tl[i], tl[i + 1], "Hips" if i == 0 else "Tail%d" % i, connect=i > 0)
if "jaw" in spec:  # else tools/jaw/add_jaw.py adds the Jaw and splits the beak skin afterwards
    jw = [yz(p) for p in spec["jaw"]]
    bone("Jaw", jw[0], jw[1], "Head")
for side, sx in (("L", 1.0), ("R", -1.0)):
    lg = [Vector((p[0] * sx, p[1], p[2])) for p in spec["leg"]]
    chain = ["Thigh", "Shin", "Metatarsal", "Toe"]
    for i, n in enumerate(chain):
        bone("%s.%s" % (n, side), lg[i], lg[i + 1], "Hips" if i == 0 else "%s.%s" % (chain[i - 1], side), connect=i > 0)
    am = [Vector((p[0] * sx, p[1], p[2])) for p in spec["arm"]]
    chain = ["Arm", "Forearm", "Hand", "Claw"][:len(am) - 1]  # a 5th arm point adds a Claw bone (therizinosaurus)
    for i, n in enumerate(chain):
        bone("%s.%s" % (n, side), am[i], am[i + 1], "Chest" if i == 0 else "%s.%s" % (chain[i - 1], side), connect=i > 0)
    if len(am) == 5:  # a non-deforming marker at the claw tip: the game's hit check (Creature.part_hit) reads bone origins
        tip = am[4] + (am[4] - am[3]).normalized() * 0.01
        bone("ClawTip.%s" % side, am[4], tip, "Claw.%s" % side, deform=False, connect=True)
# bone rolls: every bone's local X along the animal's left (+x), so a local-X rotation is a pitch for spine/legs
for b in eb:
    b.align_roll(Vector((0, 0, 1)) if abs(b.vector.normalized().z) < 0.9 else Vector((0, -1, 0)))
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------- weights
mesh.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def unweighted():
    return sum(1 for v in mesh.data.vertices if not any(g.weight > 0.01 for g in v.groups))


miss = unweighted()
print("RIG heat unweighted", miss, "of", len(mesh.data.vertices))
if miss > spec.get("proxy_frac", 0.02) * len(mesh.data.vertices):  # the voxel proxy weighted nothing on the therizinosaurus: proxy_frac 0.05 keeps heat
    proxy = mesh.copy()
    proxy.data = mesh.data.copy()
    bpy.context.scene.collection.objects.link(proxy)
    for vg in list(proxy.vertex_groups):
        proxy.vertex_groups.remove(vg)
    for m in list(proxy.modifiers):
        proxy.modifiers.remove(m)
    proxy.parent = None
    rm = proxy.modifiers.new("remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = (hi.y - lo.y) / 160.0
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = proxy
    proxy.select_set(True)
    bpy.ops.object.modifier_apply(modifier="remesh")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    print("RIG proxy unweighted", sum(1 for v in proxy.data.vertices if not v.groups), "of", len(proxy.data.vertices))
    for vg in list(mesh.vertex_groups):
        mesh.vertex_groups.remove(vg)
    for vg in proxy.vertex_groups:
        mesh.vertex_groups.new(name=vg.name)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    dt = mesh.modifiers.new("dt", "DATA_TRANSFER")
    dt.object = proxy
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    while mesh.modifiers.find("dt") > 0:
        bpy.ops.object.modifier_move_up(modifier="dt")
    bpy.ops.object.modifier_apply(modifier="dt")
    bpy.data.objects.remove(proxy)
    print("RIG after proxy unweighted", unweighted())

# clean-up passes on plain dicts, then write back
gi = {vg.index: vg.name for vg in mesh.vertex_groups}
gn = {vg.name: vg.index for vg in mesh.vertex_groups}
W = [{gi[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in mesh.data.vertices]
MID = spec.get("mid", 0.012)
BELLY = spec["belly_z"]
LEG = ["Thigh", "Shin", "Metatarsal", "Toe"]
legs = spec["leg"]
toe_top = spec.get("toe_top", legs[3][2] + 0.6 * (legs[2][2] - legs[3][2]))
ankle_top = legs[2][2]
moved = 0
for i, v in enumerate(mesh.data.vertices):
    p = v.co
    w = W[i]
    side = "L" if p.x > MID else ("R" if p.x < -MID else "")
    if side:
        other = "R" if side == "L" else "L"
        for n in [n for n in w if n.endswith("." + other)]:
            mine = n[:-1] + side
            w[mine] = w.get(mine, 0.0) + w.pop(n)
            moved += 1
    # leg zone: below the belly line and out to the side, only this side's leg chain (plus Hips near the top)
    # leg_zone_y [y0, y1] (optional): only there, so long hanging claws ahead of the legs keep their arm weights
    if side and p.z < BELLY and abs(p.x) > spec.get("leg_inner_x", 0.03) and spec.get("leg_zone_y", [-9, 9])[0] < p.y < spec.get("leg_zone_y", [-9, 9])[1]:
        keep = {}
        for n, x in w.items():
            if n.split(".")[0] in LEG and n.endswith("." + side):
                keep[n] = x
        if keep:
            # rigid foot: claws and pads below toe_top on Toe/Metatarsal only, never the shin
            if p.z < toe_top:
                keep = {n: x for n, x in keep.items() if n.startswith(("Toe", "Metatarsal"))} or {"Toe." + side: 1.0}
            elif p.z < ankle_top - 0.01:
                keep = {n: x for n, x in keep.items() if not n.startswith("Thigh")} or keep
            W[i] = keep
    top = sorted(W[i].items(), key=lambda kv: -kv[1])[:4]
    s = sum(x for _, x in top)
    W[i] = {n: x / s for n, x in top} if s > 0 else {}
# loose shells (Tripo's spikes and scales float off the hide) ride rigidly on the hide vertex nearest to them:
# heat/proxy weights gave a head spike Hips weight, and it shot out of the head in every tucked pose.
from mathutils.kdtree import KDTree
nv = len(mesh.data.vertices)
link = [[] for _ in range(nv)]
for e in mesh.data.edges:
    i, j = e.vertices
    link[i].append(j)
    link[j].append(i)
comp, islands = [-1] * nv, []
for s0 in range(nv):
    if comp[s0] >= 0:
        continue
    stack, isl = [s0], []
    comp[s0] = len(islands)
    while stack:
        c = stack.pop()
        isl.append(c)
        for o in link[c]:
            if comp[o] < 0:
                comp[o] = len(islands)
                stack.append(o)
    islands.append(isl)
BIG = 0.1 * nv  # the hide; anything smaller (spike rings, scales, claws shells) is a loose shell
print("RIG islands", sorted((len(i) for i in islands), reverse=True)[:8])
main = [i for isl in islands if len(isl) > BIG for i in isl]
kd = KDTree(len(main))
for i in main:
    kd.insert(mesh.data.vertices[i].co, i)
kd.balance()
shells = 0
for isl in islands:
    if len(isl) > BIG:
        continue
    best = min((kd.find(mesh.data.vertices[i].co) for i in isl), key=lambda r: r[2])
    for i in isl:
        W[i] = dict(W[best[1]])
    shells += 1
print("RIG loose shells pinned", shells)
# skin that neither heat nor the proxy reached (a spike root fused to the hide) takes its nearest weighted neighbour's
empty = [i for i, w in enumerate(W) if not w]
kd = KDTree(nv - len(empty))
for i, w in enumerate(W):
    if w:
        kd.insert(mesh.data.vertices[i].co, i)
kd.balance()
for i in empty:
    W[i] = dict(W[kd.find(mesh.data.vertices[i].co)[1]])
print("RIG empty filled", len(empty))
for vg in list(mesh.vertex_groups):
    mesh.vertex_groups.remove(vg)
groups = {b.name: mesh.vertex_groups.new(name=b.name) for b in arm.data.bones if b.use_deform}
for i, w in enumerate(W):
    for n, x in w.items():
        groups[n].add([i], x, "REPLACE")
print("RIG side moves", moved)
counts = {n: sum(1 for w in W if w.get(n, 0) > 0.3) for n in groups}
print("RIG counts", json.dumps(counts))

bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True, export_image_format="AUTO", export_materials="EXPORT")
print("RIG wrote", OUT)
