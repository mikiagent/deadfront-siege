"""Repair auto-rig skin weights so legs can take a real stride, writing only JOINTS_0/WEIGHTS_0.

Auto-rigged creatures (Meshy) weight belly, rump and hoof vertices to far-away bones (hind shin on
the mid-belly, tail tip on a hoof). Short shuffling clips hide it; a real stride tears those spots.
Per vertex this:
  1. drops weights listed in --strip-bones prefixes below --strip-below (height) (e.g. Tail on hooves),
  2. drops shin/foot weights above their own joint (--low-margin, --foot-margin), e.g. a forearm
     bone skinning the chest,
  3. drops a leg bone's weight when the vertex is far outside that bone's own flesh: further from the
     bone segment than --radius-mult x the 90th-percentile distance of the vertices it dominates,
  4. smooths every weight over mesh neighbours (--smooth passes), keeps the top 4, renormalises.
Everything else in the GLB (positions, joints list, rest pose, textures) is byte-identical.

usage: Blender -b -P tools/gait/fix_weights.py -- <in.glb> <out.glb> [--strip-bones Tail] [--strip-below 0.8]
           [--radius-mult 1.6] [--smooth 3] [--leg-keys UpLeg,LowLeg,Foot,Thigh,Shin,Toe,Metatarsal]
"""
import json
import struct
import sys
from collections import defaultdict

import bpy
from mathutils import Vector
from mathutils.geometry import intersect_point_line

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = a[0], a[1]


def opt(name, default):
    return type(default)(a[a.index(name) + 1]) if name in a else default


STRIP = tuple(x for x in opt("--strip-bones", "Tail").split(",") if x)
STRIP_BELOW = opt("--strip-below", 0.8)
RMULT = opt("--radius-mult", 1.6)
SMOOTH = opt("--smooth", 3)
LEG_KEYS = tuple(opt("--leg-keys", "UpLeg,LowLeg,Foot,Thigh,Shin,Toe,Metatarsal").split(","))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
me = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
if "--heat" in a:  # throw the auto-rig weights away and let Blender's bone heat re-skin the mesh
    orig_co = [v.co.copy() for v in me.data.vertices]
    me.vertex_groups.clear()
    for m in list(me.modifiers):
        me.modifiers.remove(m)
    me.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    me.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    print("HEAT groups", len(me.vertex_groups))
gname = {g.index: g.name for g in me.vertex_groups}
co = [me.matrix_world @ v.co for v in me.data.vertices]
W = [{gname[g.group]: g.weight for g in v.groups if g.weight > 0} for v in me.data.vertices]
seg = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}


def dist(p, bone):
    h, t = seg[bone]
    q, f = intersect_point_line(p, h, t)
    f = max(0.0, min(1.0, f))
    return (p - (h + (t - h) * f)).length


legs = [b for b in seg if any(k in b for k in LEG_KEYS)]
radius = {}
for b in legs:
    ds = sorted(dist(co[i], b) for i, w in enumerate(W) if w.get(b, 0) > 0.8)
    radius[b] = ds[int(len(ds) * 0.9)] if len(ds) > 10 else None
for b in list(radius):  # a broken side inflates its own radius: trust the tighter of the pair
    m = b[:-2] + (".R" if b.endswith(".L") else ".L")
    if radius.get(b) and radius.get(m):
        radius[b] = min(radius[b], radius[m])
print("RADIUS", {b: round(r, 3) for b, r in radius.items() if r})

LOW_M = opt("--low-margin", 0.04)  # shin bones only skin what hangs below their knee
FOOT_M = opt("--foot-margin", 0.15)
nbr = defaultdict(set)
for e in me.data.edges:
    i, j = e.vertices
    nbr[i].add(j)
    nbr[j].add(i)
orig = [dict(w) for w in W]
stripped = 0
for i, w in enumerate(W):
    for b in list(w):
        if any(k in b for k in ("LowLeg", "Shin")) and co[i].z > seg[b][0].z + LOW_M and len(w) > 1:
            del w[b]
            stripped += 1
            continue
        if any(k in b for k in ("Foot", "Toe", "Metatarsal")) and co[i].z > seg[b][0].z + FOOT_M and len(w) > 1:
            del w[b]
            stripped += 1
            continue
        if (b.startswith(STRIP) and co[i].z < STRIP_BELOW) or (b in radius and radius[b] and dist(co[i], b) > RMULT * radius[b] and w[b] < 0.8):
            del w[b]
            stripped += 1
# a vertex stripped bare borrows its neighbours' weights (grown inward from the kept ones)
empty = {i for i, w in enumerate(W) if not w}
for _ in range(50):
    if not empty:
        break
    filled = {}
    for i in empty:
        acc = defaultdict(float)
        for j in nbr[i]:
            if j not in empty:
                for b, x in W[j].items():
                    acc[b] += x
        if acc:
            filled[i] = dict(acc)
    for i, w in filled.items():
        W[i] = w
    empty -= set(filled)
for i in empty:  # an island with nothing kept: leave it as it was
    W[i] = orig[i]
print("STRIPPED", stripped, "left as before", len(empty))

for _ in range(SMOOTH):
    new = []
    for i, w in enumerate(W):
        acc = defaultdict(float)
        for b, x in w.items():
            acc[b] += x
        ns = nbr[i]
        for j in ns:
            for b, x in W[j].items():
                acc[b] += x / max(1, len(ns))
        new.append(acc)
    W = new

final = []
for w in W:
    top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
    s = sum(x for _, x in top) or 1.0
    final.append([(b, x / s) for b, x in top])

# write back into the original GLB by position (glTF seam duplicates share one Blender vertex)
data = bytearray(open(SRC, "rb").read())
jlen = struct.unpack_from("<I", data, 12)[0]
gj = json.loads(data[20:20 + jlen])
bin_off = 20 + jlen + 8
attr = gj["meshes"][0]["primitives"][0]["attributes"]
joints = [gj["nodes"][k]["name"] for k in gj["skins"][0]["joints"]]
jidx = {n: k for k, n in enumerate(joints)}


def view(acc_i):
    acc = gj["accessors"][acc_i]
    bv = gj["bufferViews"][acc["bufferView"]]
    return acc, bin_off + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)


pos, po = view(attr["POSITION"])
_, jo = view(attr["JOINTS_0"])
_, wo = view(attr["WEIGHTS_0"])
assert gj["accessors"][attr["JOINTS_0"]]["componentType"] == 5121
from mathutils.kdtree import KDTree
kd = KDTree(len(co))
for i, c in enumerate(co):
    kd.insert(c, i)
kd.balance()
far = 0
for v in range(pos["count"]):
    x, y, z = struct.unpack_from("<3f", data, po + 12 * v)
    _, i, d = kd.find(Vector((x, -z, y)))  # glTF Y-up -> Blender Z-up
    far += d > 1e-4
    js = [jidx[b] for b, _ in final[i]] + [0] * (4 - len(final[i]))
    ws = [x for _, x in final[i]] + [0.0] * (4 - len(final[i]))
    struct.pack_into("<4B", data, jo + 4 * v, *js)
    struct.pack_into("<4f", data, wo + 16 * v, *ws)
open(DST, "wb").write(data)
print("WROTE", DST, "matched by nearest vertex; further than 0.1 mm:", far, "of", pos["count"])
