#!/usr/bin/env python3
"""Spread the mouth-corner and throat stretch of a ripped jaw over the cheek and throat (REXJAW, regular T. rex).

open_mouth.py leaves the skin at the mouth corner 100 % Head on one vertex and 100 % Jaw on the next, so at a 40 deg
gape a few 2 cm edges become 40 cm slivers; under the jaw the throat skin jumps from Jaw straight to Neck1 (and partly
to the arms), so the roar's head throw stretches it 1.4 m. Seeds are the skin edges that stretch past 3x at the gape
(and in any --seed-clip pose). Within --radius of a seed, each head/jaw/neck vertex's whole weight vector is averaged
with its neighbours (within 8 cm and along edges; UV-seam copies alike), fading to the authored weights at the edge of
the zone, so the corner opens like a cheek fold and the throat stretches evenly. Teeth islands stay rigid.
Only the JOINTS_0/WEIGHTS_0 bytes of changed vertices are rewritten in the GLB; every other byte stays as it was.

  Blender -b -P tools/jaw/blend_corner.py -- <in.glb> <out.glb> [--radius 0.3] [--iters 40] [--gape 40]
      [--arm-reach M] [--seed-clip clip.glb@frame ...]
  T. rex (REXJAW): --radius 0.5 --arm-reach 0.8 --seed-clip anim/roar.glb@58
"""Spread the mouth-corner stretch of a ripped jaw over the cheek (REXJAW, regular T. rex).

open_mouth.py leaves the skin at the mouth corner 100 % Head on one vertex and 100 % Jaw on the next, so at a
40 deg gape a few 2 cm edges become 40 cm slivers. This diffuses the weights (Head, Jaw and the neck bones under the throat) between
neighbours by position (UV-seam copies stay together) within --radius of every edge that stretches past 3x at the gape, fading to the authored
weights at its edge, so the corner opens like a cheek fold. Teeth islands and vertices with other bones are left
alone. Only JOINTS_0/WEIGHTS_0 bytes of those vertices change in the GLB; every other byte stays as it was.

  Blender -b -P tools/jaw/blend_corner.py -- <in.glb> <out.glb> [--radius 0.45] [--iters 40] [--gape 40]
"""
import argparse, json, math, struct, sys
import bpy
from mathutils import Quaternion, Vector
from mathutils.kdtree import KDTree

ap = argparse.ArgumentParser()
ap.add_argument("inp"); ap.add_argument("out")
ap.add_argument("--radius", type=float, default=0.3, help="fade-out distance from the nearest stretched edge, m")
ap.add_argument("--iters", type=int, default=40); ap.add_argument("--gape", type=float, default=40)
ap.add_argument("--teeth-max", type=int, default=400)
ap.add_argument("--arm-reach", type=float, default=None,
                help="head/neck skin (forward of Neck1) farther than this (m) from every arm bone loses its arm weights")
ap.add_argument("--seed-clip", action="append", default=[], help="clip.glb@frame: also seed from the edges stretched in that pose")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes), key=lambda o: len(o.data.vertices))
me = ob.data; mw = ob.matrix_world
HI, JI = ob.vertex_groups["Head"].index, ob.vertex_groups["Jaw"].index
rest = [mw @ v.co for v in me.vertices]
W = [{g.group: g.weight for g in v.groups if g.weight > 1e-4} for v in me.vertices]
stripped = set()
if a.arm_reach is not None:
    # the throat skin under the jaw is partly bound to the arms (Arm.L 0.47 at 1.2 m from it), so when the roar throws
    # the arms the throat stretches 1.4 m; give that share to the vertex's other bones
    gname = [g.name for g in ob.vertex_groups]
    segs = [(arm.data.bones[n].head_local, arm.data.bones[n].tail_local) for n in gname if n.split(".")[0] in ("Arm", "Forearm", "Hand")]
    def dseg(p, s0, s1):
        d = s1 - s0; u = max(0.0, min(1.0, (p - s0).dot(d) / max(d.length_squared, 1e-9))); return (p - (s0 + d * u)).length
    y0 = arm.data.bones["Neck1"].head_local.y
    for i, p in enumerate(rest):
        armw = {g: w for g, w in W[i].items() if gname[g].split(".")[0] in ("Arm", "Forearm", "Hand")}
        if not armw or p.y < y0 or min(dseg(p, *sg) for sg in segs) < a.arm_reach: continue
        rest_w = {g: w for g, w in W[i].items() if g not in armw}
        if not rest_w: continue
        tot = sum(rest_w.values())
        for g in armw: ob.vertex_groups[g].remove([i])
        for g, w in rest_w.items(): ob.vertex_groups[g].add([i], w / tot, "REPLACE")
        W[i] = {g: w / tot for g, w in rest_w.items()}; stripped.add(i)
    print(f"REXJAW arm weights stripped from {len(stripped)} head/neck verts farther than {a.arm_reach} m from the arms")


def open_jaw(deg):
    """Open the jaw by deg, whichever local-X sign swings its tip down on this rig."""
    pb = arm.pose.bones["Jaw"]; pb.rotation_mode = "QUATERNION"
    for s in (1, -1):
        pb.rotation_quaternion = Quaternion((1, 0, 0), math.radians(s * deg))
        bpy.context.view_layer.update()
        if (arm.matrix_world @ pb.tail).z < (arm.matrix_world @ pb.bone.tail_local).z:
            return


def posed():
    m = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    P = [mw @ v.co for v in m.vertices]; ob.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
    return P


def stretch(P, idx=None):
    worst, n3 = 0.0, 0
    for e in me.edges:
        i, k = e.vertices
        if W[i].get(HI, 0) + W[i].get(JI, 0) < 0.5: continue
        r = (P[i] - P[k]).length / max((rest[i] - rest[k]).length, 1e-6)
        worst = max(worst, r); n3 += r > 3
    return worst, n3


side = {1: [], -1: []}


def seed(P):
    """Skin edges past 3x in pose P, with at least one end held by Head/Jaw only."""
    for e in me.edges:
        i, k = e.vertices
        if max(W[i].get(HI, 0) + W[i].get(JI, 0), W[k].get(HI, 0) + W[k].get(JI, 0)) < 0.99: continue
        if (P[i] - P[k]).length / max((rest[i] - rest[k]).length, 1e-6) > 3:
            m = (rest[i] + rest[k]) / 2
            side[1 if m.x > 0 else -1].append(m)


poses = []  # (label, how to pose)
for sc in a.seed_clip:
    path, fr = sc.rsplit("@", 1)
    acts = set(bpy.data.actions); before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    for o in set(bpy.data.objects) - before: bpy.data.objects.remove(o)
    poses.append((sc, next(iter(set(bpy.data.actions) - acts)), int(fr)))


def pose_clip(act, fr):
    arm.animation_data_create(); arm.animation_data.action = act
    if len(act.slots): arm.animation_data.action_slot = act.slots[0]
    bpy.context.scene.frame_set(fr)


before_stats = []
for label, act, fr in poses:
    pose_clip(act, fr); P = posed(); before_stats.append((label, *stretch(P))); seed(P)
if arm.animation_data: arm.animation_data.action = None
for pb in arm.pose.bones: pb.matrix_basis.identity()
open_jaw(a.gape)
P0 = posed()
w0, n0 = stretch(P0)
seed(P0)
corners = side[1] + side[-1]  # every stretched edge seeds the fold
print("REXJAW seeds", len(corners), [tuple(round(c, 2) for c in sum(v, Vector()) / len(v)) for v in side.values() if v])

# islands (teeth stay rigid)
parent = list(range(len(rest)))
def find(x):
    while parent[x] != x: parent[x] = parent[parent[x]]; x = parent[x]
    return x
def union(x, y):
    ra, rb = find(x), find(y)
    if ra != rb: parent[ra] = rb
for e in me.edges: union(*e.vertices)
kd0 = KDTree(len(rest))
for i, p in enumerate(rest): kd0.insert(p, i)
kd0.balance()
for i, p in enumerate(rest):  # UV-seam copies are one surface
    for (_, k, _) in kd0.find_range(p, 1e-5): union(i, k)
size = {}
for i in range(len(rest)): r = find(i); size[r] = size.get(r, 0) + 1

NECKHEAD = {HI, JI} | {ob.vertex_groups[n].index for n in ("Neck1", "Neck2") if n in ob.vertex_groups}
zone = {}
for i, p in enumerate(rest):
    if size[find(i)] < a.teeth_max: continue
    if not any(g in NECKHEAD for g in W[i]): continue  # head, jaw and the throat skin under them
    d = min((p - c).length for c in corners)
    if d < a.radius:
        x = 1 - d / a.radius
        zone[i] = x * x * (3 - 2 * x)  # how far this vertex follows the diffusion
# neighbours: everything within 8 cm, plus the vertex's edge neighbours (sparse throat skin has 17 cm edges);
# UV-seam copies sit at the same spot, so they average alike
ring = {}
for e in me.edges:
    for x, y in (e.vertices, e.vertices[::-1]): ring.setdefault(x, set()).add(y)
nbrs = {}
for i in zone:
    s = {k for (_, k, _) in kd0.find_range(rest[i], 0.08)}
    for (_, c, _) in kd0.find_range(rest[i], 1e-5): s |= ring.get(c, set())
    nbrs[i] = list(s | {i})
# diffuse the whole weight vector (Head, Jaw and the neck bones under the throat), fading to the authored weights
w = [dict(x) for x in W]
for _ in range(a.iters):
    nw = {}
    for i, f in zone.items():
        acc = {}
        for k in nbrs[i]:
            for g, x in w[k].items(): acc[g] = acc.get(g, 0.0) + x / len(nbrs[i])
        mix = {g: (1 - f) * W[i].get(g, 0.0) + f * acc.get(g, 0.0) for g in set(acc) | set(W[i])}
        nw[i] = {g: x for g, x in mix.items() if x > 1e-4}
    for i, d in nw.items(): w[i] = d
print("REXJAW zone", len(zone))
def top4(d):
    t = sorted(d.items(), key=lambda kv: -kv[1])[:4]; s_ = sum(x for _, x in t); return {g: x / s_ for g, x in t}
changed = []
for i in zone:
    d = top4(w[i])
    if max(abs(d.get(g, 0.0) - W[i].get(g, 0.0)) for g in set(d) | set(W[i])) <= 1e-3: continue
    changed.append(i)
    for g in list(W[i]): ob.vertex_groups[g].remove([i])
    for g, x in d.items(): ob.vertex_groups[g].add([i], x, "REPLACE")
w1, n1 = stretch(posed())
for (label, wb, nb), (_, act, fr) in zip(before_stats, poses):
    arm.pose.bones["Jaw"].rotation_quaternion = Quaternion()
    pose_clip(act, fr); wa, na = stretch(posed())
    print(f"REXJAW {label}: stretch {wb:.1f}x ({nb} edges >3x) -> {wa:.1f}x ({na} edges >3x)")
print(f"REXJAW corner blend: {len(changed)} verts, stretch at {a.gape:.0f} deg {w0:.1f}x ({n0} edges >3x) -> {w1:.1f}x ({n1} edges >3x)")

# write only those vertices' JOINTS_0 / WEIGHTS_0 into a byte copy of the GLB (Blender imports primitives in order)
b = bytearray(open(a.inp, "rb").read())
n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + n]); off = 20 + n + 8
names = [j["nodes"][x]["name"] for x in j["skins"][0]["joints"]]
gname = [g.name for g in ob.vertex_groups]
def where(acc):
    A = j["accessors"][acc]; bv = j["bufferViews"][A["bufferView"]]
    return off + bv.get("byteOffset", 0) + A.get("byteOffset", 0), A
base = 0; todo = set(changed) | stripped
for pr in j["meshes"][0]["primitives"]:
    ps, PA = where(pr["attributes"]["POSITION"]); js, JA = where(pr["attributes"]["JOINTS_0"]); ws, _ = where(pr["attributes"]["WEIGHTS_0"])
    assert JA["componentType"] == 5121, "JOINTS_0 must be unsigned bytes"
    for li in range(PA["count"]):
        gi = base + li
        if gi not in todo: continue
        x, y, z = struct.unpack_from("<3f", b, ps + 12 * li)  # glTF Y-up, -Z forward vs Blender Z-up, +Y forward
        assert (Vector((x, -z, y)) - rest[gi]).length < 1e-4, "vertex order differs from the import"
        top = sorted(((g.weight, names.index(gname[g.group])) for g in me.vertices[gi].groups if g.weight > 1e-4), reverse=True)[:4]
        tot = sum(w for w, _ in top); top += [(0.0, 0)] * (4 - len(top))
        struct.pack_into("<4B", b, js + 4 * li, *[k for _, k in top])
        struct.pack_into("<4f", b, ws + 16 * li, *[w / tot for w, _ in top])
    base += PA["count"]
open(a.out, "wb").write(b)
print("WROTE", a.out)
