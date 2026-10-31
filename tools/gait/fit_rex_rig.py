"""SP-TYRANNOSAURUS: put the T. rex's 30-bone rig onto a new Tripo mesh (the open-mouth remodel), same bone names,
so every rex tool (make_rex_moves, make_gait + tyrannosaurus.json, check_rex_clips, the howdah) carries over.

  1. the Tripo mesh is turned head-to-+Y, scaled to 8 m and centred (frame A, where JOINTS were measured);
  2. Tripo modelled it mid-stride (left foot forward under the hips, right leg trailing 2 m back with a longer
     thigh). Posing that into a square stance stretched the thigh skin into a sheet, so the left half is mirrored
     onto the right instead: a symmetric animal standing square, left sole lowered onto the floor (frame B);
  3. each bone gets the joint positions measured in frame A (from ortho grid renders), carried into frame B, with the
     old bone's roll turned with it (local pitch/yaw axes stay the same for the keyed tools);
  4. weights: distance to the bone segments, side- and arm-limited, smoothed over the welded skin (the old rig's
     legs were bound to the opposite side; here a leg can only take its own side's bones, checked below);
  5. the old stub Jaw is removed (its skin goes back to Head); tools/jaw/add_jaw.py --open adds the real jaw next.

usage: Blender -b -P tools/gait/fit_rex_rig.py -- <old_base.glb> <tripo.glb> <out.glb>
"""
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

OLD, NEW, OUT = sys.argv[sys.argv.index("--") + 1:][:3]
HEIGHT = 8.0

# Joint positions in frame A (Blender, +Y forward, metres, left = -X), measured on grid renders: side ortho, the left
# leg alone (the right half cut away), head close-up. The left leg is the one kept.
J = {
    "root": ((0, 0, 0), (0, 5.78, 0)),
    "Hips": ((0, 0.9, 5.4), (0, 1.7, 5.5)),
    "Spine1": ((0, 1.7, 5.5), (0, 2.4, 5.7)),
    "Spine2": ((0, 2.4, 5.7), (0, 3.0, 5.9)),
    "Chest": ((0, 3.0, 5.9), (0, 3.75, 6.15)),
    "Neck1": ((0, 3.75, 6.15), (0, 4.35, 6.4)),
    "Neck2": ((0, 4.35, 6.4), (0, 4.9, 6.6)),
    "Head": ((0, 4.9, 6.6), (0, 5.1, 6.58)),
    "Jaw": ((0, 5.2, 5.95), (0, 5.4, 5.9)),  # removed below; add_jaw.py measures the real one
    "Arm.L": ((-1.2, 2.9, 4.4), (-1.5, 2.6, 3.5)),
    "Forearm.L": ((-1.5, 2.6, 3.5), (-1.15, 3.4, 3.1)),
    "Hand.L": ((-1.15, 3.4, 3.1), (-0.9, 3.6, 2.6)),
    "Thigh.L": ((-1.5, 0.9, 4.0), (-1.85, -0.1, 2.45)),
    "Shin.L": ((-1.85, -0.1, 2.45), (-1.95, 0.8, 1.0)),
    "Metatarsal.L": ((-1.95, 0.8, 1.0), (-2.1, 1.75, 0.35)),
    "Toe.L": ((-2.1, 1.75, 0.35), (-2.25, 2.55, 0.25)),
}
for b in ("Arm", "Forearm", "Hand", "Thigh", "Shin", "Metatarsal", "Toe"):  # mirrored
    h, t = J[b + ".L"]
    J[b + ".R"] = ((-h[0], h[1], h[2]), (-t[0], t[1], t[2]))
# tail: 7 even segments from the hips to the tip along the measured centreline (mid of the top and bottom skin)
TAIL_TIP = (-8.4, 4.3)
CL = {0.9: 5.4, -1.35: 5.2, -2.5: 5.05, -3.5: 4.95, -4.5: 4.85, -5.5: 4.9, -6.5: 4.88, -7.5: 4.75, -8.4: 4.3}


def cl_z(y):
    ks = sorted(CL)
    for a, b in zip(ks, ks[1:]):
        if a <= y <= b:
            return CL[a] + (CL[b] - CL[a]) * (y - a) / (b - a)
    return CL[ks[0]] if y < ks[0] else CL[ks[-1]]


ys = [0.9 + (TAIL_TIP[0] - 0.9) * i / 7 for i in range(8)]
for i in range(7):
    J["Tail%d" % (i + 1)] = ((0, ys[i], cl_z(ys[i])), (0, ys[i + 1], cl_z(ys[i + 1])))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=OLD)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
old = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes), key=lambda o: len(o.data.vertices))
for o in list(bpy.data.objects):
    if o.type == "MESH" and o is not old:
        bpy.data.objects.remove(o)
AW = arm.matrix_world.copy()
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=NEW)
new = max((o for o in set(bpy.data.objects) - before if o.type == "MESH"), key=lambda o: len(o.data.vertices))
new.data.transform(new.matrix_world)
new.parent = None
new.matrix_world = Matrix.Identity(4)
for o in set(bpy.data.objects) - before:
    if o is not new:
        bpy.data.objects.remove(o)
new.data.transform(Matrix.Rotation(math.pi / 2, 4, "Z"))  # Tripo faces +X
P = [v.co for v in new.data.vertices]
z0, z1 = min(p.z for p in P), max(p.z for p in P)
cx = (max(p.x for p in P) + min(p.x for p in P)) / 2
cy = (max(p.y for p in P) + min(p.y for p in P)) / 2
new.data.transform(Matrix.Scale(HEIGHT / (z1 - z0), 4) @ Matrix.Translation((-cx, -cy, -z0)))  # frame A

# ---- mirror the left half. The midline is the mean x of the back (the spine ridge and skull top are symmetric).
mid = [v.co.x for v in new.data.vertices if v.co.z > 6.4]
c = sum(mid) / len(mid)
bm = bmesh.new()
bm.from_mesh(new.data)
bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(c, 0, 0), plane_no=(1, 0, 0),
                       clear_outer=True, dist=1e-5)
bmesh.ops.translate(bm, verts=bm.verts[:], vec=(-c, 0, 0))
for v in bm.verts:
    if abs(v.co.x) < 1e-4:
        v.co.x = 0.0
bmesh.ops.mirror(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], axis="X", merge_dist=1e-4)
n0 = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.002)  # Tripo splits the skin at every UV seam; weld it (UVs are per loop) so it bends as one sheet
print(f"welded {n0 - len(bm.verts)} seam vertices")
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])  # the mirrored copy comes out inside-out
bm.to_mesh(new.data)
bm.free()
new.data.update()
bpy.context.view_layer.objects.active = new
if new.data.has_custom_normals:  # the import's split normals were not mirrored with the faces
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
new.data.shade_smooth()
# lower the kept (left) sole onto the floor and rescale to the height: frame B
zs = min(v.co.z for v in new.data.vertices)
zt = max(v.co.z for v in new.data.vertices)
B = Matrix.Scale(HEIGHT / (zt - zs), 4) @ Matrix.Translation((0, 0, -zs))
new.data.transform(B)
A2B = B @ Matrix.Translation((-c, 0, 0))
SB = HEIGHT / (zt - zs)


def a2b(q):
    """frame A -> B; the joint x values were measured from the midline, so only the scale applies to x"""
    r = A2B @ Vector(q)
    r.x = q[0] * SB
    return tuple(r)


J = {k: ((a2b(h), a2b(t)) if k != "root" else (h, t)) for k, (h, t) in J.items()}
print(f"mirror: midline x {c:+.3f}, sole was {zs:+.3f} m, scale {HEIGHT / (zt - zs):.4f}, verts {len(new.data.vertices)}")
new.name = "TRex"
new.data.name = "TRexMesh"
for g in list(new.vertex_groups):
    new.vertex_groups.remove(g)

# ------------------------------------------------------------------ move the bones onto the new joints
oldb = {b.name: (AW @ b.head_local, AW @ b.tail_local, (AW.to_3x3() @ b.z_axis).normalized()) for b in arm.data.bones}
bpy.data.objects.remove(old)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
inv = AW.inverted()
for eb in arm.data.edit_bones:
    eb.use_connect = False
for eb in arm.data.edit_bones:
    oh, ot, oz = oldb[eb.name]
    h, t = (Vector(x) for x in J[eb.name])
    q = (ot - oh).normalized().rotation_difference((t - h).normalized())
    eb.head, eb.tail = inv @ h, inv @ t
    eb.align_roll(inv.to_3x3() @ (q @ oz))  # keep the old local axes, turned with the bone
bpy.ops.object.mode_set(mode="OBJECT")

# ------------------------------------------------------------------ weights: distance to the bones, then smoothed
# Two things failed first: the old skin warped onto the new joints and copied by nearest point left shards (knee skin
# on the thigh flew off in folded poses), and Blender bone heat on the mirrored mesh leaked Arm.R down to the right
# foot. So: each vertex weighs the bones it may belong to by 1/d^4 to the bone segment (the Head bone is a stub, so
# its segment runs on to the snout tip), arms only within ARM_R of the arm, legs and arms only on their own side,
# then the weights are averaged over the welded skin's neighbours a few times so joints bend smoothly.
ARM_R, POW, SMOOTH = 0.7, 4.0, 4
SNOUT = Vector(a2b((0, 8.45, 6.0)))


def seg_d(p, h, t):
    d = t - h
    x = max(0.0, min(1.0, (p - h).dot(d) / max(d.length_squared, 1e-9)))
    return (p - (h + d * x)).length


segs = {}
for b in arm.data.bones:
    if b.name == "root":
        continue
    h, t = AW @ b.head_local, AW @ b.tail_local
    segs[b.name] = (h, SNOUT if b.name == "Head" else t)
W = []
for v in new.data.vertices:
    p = v.co
    w = {}
    for n, (h, t) in segs.items():
        if n.endswith(".L") and p.x > 0.15 or n.endswith(".R") and p.x < -0.15:
            continue
        d = seg_d(p, h, t)
        if n.startswith(("Arm", "Forearm", "Hand")) and d > ARM_R:
            continue
        w[n] = 1.0 / (d + 0.05) ** POW
    W.append(w)
nbr = [[] for _ in new.data.vertices]
for e in new.data.edges:
    i, j = e.vertices
    nbr[i].append(j)
    nbr[j].append(i)
for i, w in enumerate(W):
    s_ = sum(w.values())
    W[i] = {k: x / s_ for k, x in w.items()}
for _ in range(SMOOTH):
    NW = []
    for i, w in enumerate(W):
        acc = {k: 0.5 * x for k, x in w.items()}
        if nbr[i]:
            f = 0.5 / len(nbr[i])
            for j in nbr[i]:
                for k, x in W[j].items():
                    acc[k] = acc.get(k, 0.0) + f * x
        else:
            acc = dict(w)
        NW.append(acc)
    W = NW
groups = {n: new.vertex_groups.new(name=n) for n in segs}
for i, w in enumerate(W):
    p = new.data.vertices[i].co
    if p.z < 0.5 and any(k.startswith(("Metatarsal", "Toe")) for k in w):  # soles ride the foot alone, or a bending shin pushes the heel through the floor
        w = {k: x for k, x in w.items() if k.startswith(("Metatarsal", "Toe"))}
    top = [(k, x) for k, x in sorted(w.items(), key=lambda t: -t[1]) if not (k.endswith(".L") and p.x > 0.15 or k.endswith(".R") and p.x < -0.15)][:4]
    s_ = sum(x for _, x in top)
    for k, x in top:
        if x / s_ > 0.02:
            groups[k].add([i], x / s_, "REPLACE")
new.parent = arm
mod = new.modifiers.new("Armature", "ARMATURE")
mod.object = arm
bpy.context.view_layer.update()

# ------------------------------------------------------------------ drop the stub Jaw: its skin back to Head
jg, hg = new.vertex_groups.get("Jaw"), new.vertex_groups["Head"]
if jg:
    for v in new.data.vertices:
        jw = next((g.weight for g in v.groups if g.group == jg.index), 0.0)
        if jw > 0:
            hw = next((g.weight for g in v.groups if g.group == hg.index), 0.0)
            hg.add([v.index], hw + jw, "REPLACE")
    new.vertex_groups.remove(jg)
bpy.ops.object.mode_set(mode="EDIT")
arm.data.edit_bones.remove(arm.data.edit_bones["Jaw"])
bpy.ops.object.mode_set(mode="OBJECT")

lo = min((new.matrix_world @ v.co).z for v in new.data.vertices)
print(f"lowest skin z {lo:.3f}")
side_bad = sum(1 for v in new.data.vertices if v.co.x < -0.5 and any(new.vertex_groups[g.group].name.endswith(".R") and g.weight > 0 for g in v.groups))
print(f"left-side verts on .R groups: {side_bad}")
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
new.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", OUT)
