#!/usr/bin/env python3
"""Give a closed-mouth creature mesh a mouth that can open: cut the lips apart and add a mouth bag.

Generated meshes (Tripo, Meshy) come with the mouth shut, so upper and lower lips are one surface. A Jaw bone
on top of that only stretches the lip faces into a sheet ("tape") when the mouth opens. This script:

  1. welds UV-seam duplicates so the mesh topology is real again,
  2. makes every small island in the head (teeth) rigid to Head or Jaw, whichever holds most of it,
  3. makes lip skin forward of the mouth corner 100 % Head or 100 % Jaw (no half-and-half sagging),
  4. rips the lips apart along the mouth line forward of the corner (they still meet when shut),
  5. adds a mouth bag built in slices along the jaw: a palate arch on the Head, a floor trough on the Jaw
     and a throat at the corner that stretches between them, plus a short lining wall behind every torn lip edge,
  6. gives the bag its own flat gum-red material (a second surface; the game's colour shader keeps its colour),
  7. exports the same GLB layout (armature + skinned mesh, no animations).

Only the mesh and its weights change; bone names, rest pose and every existing clip stay valid.

  Blender -b --python tools/jaw/open_mouth.py -- <in.glb> <out.glb> [--corner 0.125] [--depth 0.04]
      [--inset 0.55] [--teeth-max 400] [--head Head] [--jaw Jaw]

--corner: distance (x jaw length) along the jaw bone from its pivot where the cut starts; skin behind it stays a
blended web (the rictus), which stretches only a little because it is near the pivot.
"""
import argparse, sys
import bpy, bmesh
from mathutils import Vector
from mathutils.kdtree import KDTree

ap = argparse.ArgumentParser()
ap.add_argument("inp"); ap.add_argument("out")
ap.add_argument("--corner", type=float, default=0.125)
ap.add_argument("--depth", type=float, default=0.04, help="how far the palate/floor sink into the head (x jaw length)")
ap.add_argument("--lining", type=float, default=0.02, help="depth of the wall behind each torn lip edge (x jaw length)")
ap.add_argument("--band", type=float, default=0.15, help="skin this close to the lip line is re-sided by height (x jaw length)")
ap.add_argument("--inset", type=float, default=0.55, help="palate/floor edges pull x toward the midline by this factor")
ap.add_argument("--teeth-max", type=int, default=400, help="islands with fewer verts are treated as teeth")
ap.add_argument("--head", default="Head"); ap.add_argument("--jaw", default="Jaw")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.parent == arm), key=lambda o: len(o.data.vertices))
HI, JI = ob.vertex_groups[a.head].index, ob.vertex_groups[a.jaw].index
jb = arm.data.bones[a.jaw]
piv = arm.matrix_world @ jb.head_local
jvec = arm.matrix_world.to_3x3() @ (jb.tail_local - jb.head_local)
jdir = jvec.normalized()
mw = ob.matrix_world

ref = ob.copy(); ref.data = ob.data.copy(); bpy.context.scene.collection.objects.link(ref)  # keeps the shading normals
bm = bmesh.new(); bm.from_mesh(ob.data)
n0 = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
dl = bm.verts.layers.deform.active
uvl = bm.loops.layers.uv.active
print(f"weld: {n0} -> {len(bm.verts)} verts")

def jw(v): return v[dl].get(JI, 0.0)
def hw(v): return v[dl].get(HI, 0.0)
def t_of(v): return (mw @ v.co - piv).dot(jdir)

# lengths are fractions of the measured lower jaw (bone lengths are arbitrary), so one setting fits a T. rex and a raptor
JL = max(t_of(v) for v in bm.verts if jw(v) > 0.5)
a.corner *= JL; a.depth *= JL; a.lining *= JL; a.band *= JL
print(f"lower jaw length {JL:.3f} m")

def set_side(v, jaw):
    tot = jw(v) + hw(v)
    if tot <= 0: return
    d = v[dl]
    for k in (JI, HI):
        if k in d: del d[k]
    d[JI if jaw else HI] = tot

# 2. teeth: small islands in the mouth become rigid, 100 % on the Head or the Jaw. Side: the majority of their own
# Head/Jaw weight, or for islands an auto-rig left on some other bone (Tripo's neutral_bone), the nearest skin.
comps, seen = [], set()
for v in bm.verts:
    if v.index in seen: continue
    comp, st = [], [v]; seen.add(v.index)
    while st:
        x = st.pop(); comp.append(x)
        for e in x.link_edges:
            o = e.other_vert(x)
            if o.index not in seen: seen.add(o.index); st.append(o)
    comps.append(comp)
skin = [v for c in comps if len(c) >= a.teeth_max for v in c if jw(v) + hw(v) > 0.5]
kd = KDTree(len(skin))
for i, v in enumerate(skin): kd.insert(v.co, i)
kd.balance()
teeth = 0; roots = []; tooth_verts = set()  # roots: (t, gum z, is_jaw) per tooth
for comp in comps:
    if len(comp) >= a.teeth_max: continue
    mine = sum(jw(x) + hw(x) for x in comp)
    centre = sum((x.co for x in comp), Vector()) / len(comp)
    if mine > 0.05:
        side = sum(jw(x) for x in comp) > sum(hw(x) for x in comp)
    elif skin and t_of(comp[0]) > 0 and kd.find(centre)[2] < 0.1 * (max(t_of(v) for v in skin) or 1):
        n = skin[kd.find(centre)[1]]; side = jw(n) > hw(n)
    else:
        continue
    for x in comp:  # one rigid piece on one bone, or its tips drift off under other bones' shares
        x[dl].clear(); x[dl][JI if side else HI] = 1.0
    teeth += 1; tooth_verts.update(comp)
    zs = [(mw @ x.co).z for x in comp]
    roots.append((sum(t_of(x) for x in comp) / len(comp), min(zs) if side else max(zs), side))
print(f"teeth islands made rigid: {teeth}")

# 3+4. lips forward of the corner: binarise, then rip along the mouth line. Every edge that crosses it is split
# where it crosses, the new points are joined inside each face, and that seam is torn apart, so the lips still
# meet with the mouth shut (no gap) and separate cleanly when it opens.
# where the lips meet: halfway between the upper and lower gum lines, taken from the teeth roots near each point.
# The weight contour alone sits too low at the chin, so the cut ran across visible chin skin.
def lip_z(t):
    up = [z for tt, z, j in roots if not j and abs(tt - t) < a.band]
    lo = [z for tt, z, j in roots if j and abs(tt - t) < a.band]
    return (sum(up) / len(up) + sum(lo) / len(lo)) / 2 if up and lo else None
mouth = [v for v in bm.verts if jw(v) + hw(v) > 0.05 and t_of(v) > a.corner]  # raptors share head skin with Neck
if not roots:  # painted teeth (Meshy): fit a straight lip line through the weight boundary so the cut is not a staircase
    wside = {v: jw(v) >= 0.5 * (jw(v) + hw(v)) for v in mouth}
    ms = [((t_of(e.verts[0]) + t_of(e.verts[1])) / 2, ((mw @ e.verts[0].co).z + (mw @ e.verts[1].co).z) / 2)
          for e in bm.edges if all(v in wside for v in e.verts) and wside[e.verts[0]] != wside[e.verts[1]]]
    n = len(ms); mt = sum(t for t, _ in ms) / n; mz = sum(z for _, z in ms) / n
    c1 = sum((t - mt) * (z - mz) for t, z in ms) / max(sum((t - mt) ** 2 for t, _ in ms), 1e-9); c0 = mz - c1 * mt
    lip_z = lambda t: c0 + c1 * t
    print(f"lip line fitted through {n} weight-boundary edges")
side = {}
for v in mouth:
    lz = None if v in tooth_verts else lip_z(t_of(v))
    z = (mw @ v.co).z
    side[v] = z < lz if lz is not None and abs(z - lz) < a.band else jw(v) >= 0.5 * (jw(v) + hw(v))
for v, s in side.items(): set_side(v, s)  # only the Head/Jaw shares swap; other bones' blend stays or the throat tears
tape = [f for f in bm.faces if all(v in side for v in f.verts) and len({side[v] for v in f.verts}) == 2]
old_verts = set(bm.verts)
cross = {e for f in tape for e in f.edges if side[e.verts[0]] != side[e.verts[1]]}
mids = set()
for e in cross:
    z0, z1 = ((mw @ v.co).z for v in e.verts)
    lz = lip_z(t_of(e.verts[0]))
    fac = 0.5 if lz is None or abs(z1 - z0) < 1e-6 else min(0.9, max(0.1, (lz - z0) / (z1 - z0)))
    _, nv = bmesh.utils.edge_split(e, e.verts[0], fac)
    mids.add(nv)
seam = []
for f in list({f for v in mids for f in v.link_faces}):
    m = [v for v in f.verts if v in mids]
    if len(m) == 2:
        res = bmesh.ops.connect_verts(bm, verts=m)
        seam += res["edges"]
bmesh.ops.split_edges(bm, edges=seam)
cut_verts = {v for v in bm.verts if v not in old_verts}
for v in cut_verts:  # a torn point belongs to the side of the faces it still has
    olds = [o for f in v.link_faces for o in f.verts if o in side]
    if not olds: continue
    side[v] = sum(side[o] for o in olds) * 2 > len(olds)
    set_side(v, side[v])
cut_verts = {v for v in cut_verts if v in side}
print(f"tape faces ripped: {len(tape)}, seam edges: {len(seam)}, torn points: {len(cut_verts)}")

# 5. mouth bag, built in slices along the jaw: a palate arch on the Head, a floor trough on the Jaw,
# each spanning left lip edge -> midline -> right lip edge, and a throat at the corner that stretches between them
X = Vector((1, 0, 0))
nrm = (Vector((0, 0, 1)) - jdir * jdir.z).normalized()
def frame(v):
    d = mw @ v.co - piv
    return d.dot(jdir), d.dot(X), d.dot(nrm)
pts = [(frame(v), side[v]) for v in cut_verts if v.is_valid]
tmax = max(t for (t, _, _), _ in pts) - 0.08 * JL  # stop short of the snout tip so the bag never pokes out of the chin
K = max(4, int((tmax - a.corner) / (0.05 * JL)))
rows_h, rows_j = [], []
for k in range(K + 1):
    tk = a.corner + (tmax - a.corner) * k / K
    near = [(x, z, s) for (t, x, z), s in pts if abs(t - tk) < (tmax - a.corner) / K]
    up = [(x, z) for x, z, s in near if not s]; lo = [(x, z) for x, z, s in near if s]
    if not up or not lo: continue
    wu = max(abs(x) for x, _ in up) * a.inset; zu = min(z for _, z in up)
    wl = max(abs(x) for x, _ in lo) * a.inset; zl = max(z for _, z in lo)
    lz = lip_z(tk)  # the measured lip line is smoother than per-slice extremes (which made a sawtooth rim)
    if lz is not None: zu = zl = (lz - piv.z - jdir.z * tk) / nrm.z  # world height -> the jaw frame's height
    taper = min(1.0, (tmax - tk) / (0.17 * JL))  # shallower toward the tip, where the snout is thin
    rows_h.append((tk, [(-wu, zu), (0, zu + a.depth * taper), (wu, zu)]))
    rows_j.append((tk, [(-wl, zl + 0.008 * JL), (0, zl - a.depth * 0.5 * taper), (wl, zl + 0.008 * JL)]))
def mk(t, x, z, bone):
    v = bm.verts.new(mw.inverted() @ (piv + jdir * t + X * x + nrm * z))
    v[dl][bone] = 1.0
    bag_verts.append(v)
    return v
new_faces, bag_verts = [], []
def strip(rows, bone, flip):
    vs = [[mk(t, x, z, bone) for x, z in r] for t, r in rows]
    for a_, b_ in zip(vs, vs[1:]):
        for i in range(len(a_) - 1):
            q = (a_[i], a_[i + 1], b_[i + 1], b_[i])
            new_faces.append(bm.faces.new(q[::-1] if flip else q))
    return vs
vh = strip(rows_h, HI, False); vj = strip(rows_j, JI, True)
if vh and vj:  # throat: palate back row to floor back row, half-and-half so it stretches like skin
    for v in vh[0] + vj[0]:
        v[dl][HI] = 0.5; v[dl][JI] = 0.5
    for i in range(2):
        new_faces.append(bm.faces.new((vh[0][i], vh[0][i + 1], vj[0][i + 1], vj[0][i])))
print(f"mouth bag: {len(rows_h)} slices, {len(new_faces)} faces")
# lip lining: every torn edge gets a short wall turned into the head, so a slightly open mouth shows gum, not a crack
bm.normal_update()
inward = {}
for v in cut_verts:
    n = (mw.to_3x3() @ v.normal).normalized()
    p = mw @ v.co
    nv = bm.verts.new(mw.inverted() @ (p - n * a.lining))
    for k, w in v[dl].items(): nv[dl][k] = w
    bag_verts.append(nv); inward[v] = nv
lining = 0
for e in [e for e in bm.edges if e.is_boundary and all(v in inward for v in e.verts)]:
    v1, v2 = e.verts
    f0 = e.link_faces[0]
    # wind the wall like the skin face it hangs from
    l = next(l for l in f0.loops if l.edge == e)
    a1, a2 = (v1, v2) if l.vert == v1 else (v2, v1)
    new_faces.append(bm.faces.new((a2, a1, inward[a1], inward[a2]))); lining += 1
print(f"lip lining: {lining} faces")

# the bag gets its own flat gum-red material: textures rarely hold a usable mouth colour (raptors have none), and the
# game's colour shader keeps a texture-less surface's albedo colour
mouth_mat = bpy.data.materials.new("mouth")
mouth_mat.use_nodes = True
bsdf = mouth_mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.20, 0.045, 0.045, 1.0); bsdf.inputs["Roughness"].default_value = 0.55
ob.data.materials.append(mouth_mat)
MI = len(ob.data.materials) - 1
for f in new_faces:
    f.smooth = True; f.material_index = MI
bm.verts.index_update(); bag_idx = {v.index for v in bag_verts}
bm.to_mesh(ob.data); bm.free()
ob.data.update()
# welding drops the imported split normals; copy them back from the untouched mesh so the skin shades as before
bpy.context.view_layer.objects.active = ob
dt = ob.modifiers.new("normals", "DATA_TRANSFER")
skin = ob.vertex_groups.new(name="_skin")  # the bag keeps its own normals (borrowed skin normals shade it black)
skin.add([i for i in range(len(ob.data.vertices)) if i not in bag_idx], 1.0, "REPLACE")
dt.vertex_group = skin.name
dt.object = ref; dt.use_loop_data = True; dt.data_types_loops = {"CUSTOM_NORMAL"}; dt.loop_mapping = "POLYINTERP_NEAREST"
bpy.ops.object.modifier_move_to_index(modifier=dt.name, index=0)
bpy.ops.object.modifier_apply(modifier=dt.name)
ob.vertex_groups.remove(ob.vertex_groups["_skin"])
for o in list(bpy.data.objects):
    if o not in (arm, ob): bpy.data.objects.remove(o)  # also the normals reference and the bone-shape sphere
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", a.out)
