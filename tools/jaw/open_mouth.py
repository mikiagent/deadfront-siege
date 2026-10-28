#!/usr/bin/env python3
"""Give a closed-mouth creature mesh a mouth that can open: cut the lips apart and add a mouth bag.

Generated meshes (Tripo, Meshy) come with the mouth shut, so upper and lower lips are one surface. A Jaw bone
on top of that only stretches the lip faces into a sheet ("tape") when the mouth opens. This script:

  1. welds UV-seam duplicates so the mesh topology is real again,
  2. makes every small island in the head (teeth) rigid to Head or Jaw, whichever holds most of it,
  3. makes lip skin forward of the mouth corner 100 % Head or 100 % Jaw (no half-and-half sagging),
  4. rips the lips apart along the mouth line forward of the corner (they still meet when shut),
  5. adds a mouth bag built in slices along the jaw: a palate arch on the Head, a floor trough on the Jaw
     and a throat at the corner that stretches between them,
  6. textures the bag from a gum-red texel of the creature's own texture (one material, no game change),
  7. exports the same GLB layout (armature + skinned mesh, no animations).

Only the mesh and its weights change; bone names, rest pose and every existing clip stay valid.

  Blender -b --python tools/jaw/open_mouth.py -- <in.glb> <out.glb> [--corner 0.30] [--depth 0.10]
      [--inset 0.55] [--teeth-max 400] [--head Head] [--jaw Jaw]

--corner: distance (m) along the jaw bone from its pivot where the cut starts; skin behind it stays a
blended web (the rictus), which stretches only a little because it is near the pivot.
"""
import argparse, sys
import bpy, bmesh
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument("inp"); ap.add_argument("out")
ap.add_argument("--corner", type=float, default=0.30)
ap.add_argument("--depth", type=float, default=0.10, help="how far the gum wall goes into the head (m)")
ap.add_argument("--inset", type=float, default=0.55, help="gum wall pulls x toward the midline by this factor")
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
jdir = (arm.matrix_world.to_3x3() @ (jb.tail_local - jb.head_local)).normalized()
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

def set_side(v, jaw):
    tot = jw(v) + hw(v)
    if tot <= 0: return
    d = v[dl]
    for k in (JI, HI):
        if k in d: del d[k]
    d[JI if jaw else HI] = tot

# 2. teeth: small islands with any Head/Jaw weight become rigid
seen = set(); teeth = 0
for v in bm.verts:
    if v.index in seen: continue
    comp, st = [], [v]; seen.add(v.index)
    while st:
        x = st.pop(); comp.append(x)
        for e in x.link_edges:
            o = e.other_vert(x)
            if o.index not in seen: seen.add(o.index); st.append(o)
    if len(comp) < a.teeth_max and any(jw(x) + hw(x) > 0.5 for x in comp):
        side = sum(jw(x) for x in comp) > sum(hw(x) for x in comp)
        for x in comp: set_side(x, side)
        teeth += 1
print(f"teeth islands made rigid: {teeth}")

# 3+4. lips forward of the corner: binarise, then rip along the mouth line. Every edge that crosses it is split
# at its middle, the new points are joined inside each face, and that seam is torn apart, so the lips still
# meet with the mouth shut (no gap) and separate cleanly when it opens.
mouth = [v for v in bm.verts if jw(v) + hw(v) > 0.5 and t_of(v) > a.corner]
side = {v: jw(v) >= 0.5 * (jw(v) + hw(v)) for v in mouth}
for v, s in side.items(): set_side(v, s)
tape = [f for f in bm.faces if all(v in side for v in f.verts) and len({side[v] for v in f.verts}) == 2]
old_verts = set(bm.verts)
cross = {e for f in tape for e in f.edges if side[e.verts[0]] != side[e.verts[1]]}
mids = set()
for e in cross:
    _, nv = bmesh.utils.edge_split(e, e.verts[0], 0.5)
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

# bag texel: the reddest mid-dark UV the old lip faces used, which is gum / mouth interior
img = next((n.image for m in ob.data.materials if m and m.use_nodes for n in m.node_tree.nodes
            if n.type == "TEX_IMAGE" and n.image), None)
bag_uv = None
if img and uvl:
    W, H = img.size; px = img.pixels[:]
    best = 9
    for f in bm.faces:
        if not any(v in cut_verts for v in f.verts): continue
        for lo in f.loops:
            u, w = lo[uvl].uv
            i = (int(min(max(w, 0), 0.9999) * H) * W + int(min(max(u, 0), 0.9999) * W)) * 4
            r, g, b = px[i:i + 3]; lum = 0.3 * r + 0.6 * g + 0.1 * b
            score = -(r - (g + b) / 2) + abs(lum - 0.22)  # gum-red, mid-dark (pure black reads as torn holes)
            if score < best: best, bag_uv = score, (u, w)
print("bag uv:", bag_uv)

# 5. mouth bag, built in slices along the jaw: a palate arch on the Head, a floor trough on the Jaw,
# each spanning left lip edge -> midline -> right lip edge, and a throat at the corner that stretches between them
X = Vector((1, 0, 0))
nrm = (Vector((0, 0, 1)) - jdir * jdir.z).normalized()
def frame(v):
    d = mw @ v.co - piv
    return d.dot(jdir), d.dot(X), d.dot(nrm)
pts = [(frame(v), side[v]) for v in cut_verts if v.is_valid]
tmax = max(t for (t, _, _), _ in pts) - 0.2  # stop short of the snout tip so the bag never pokes out of the chin
K = max(4, int((tmax - a.corner) / 0.12))
rows_h, rows_j = [], []
for k in range(K + 1):
    tk = a.corner + (tmax - a.corner) * k / K
    near = [(x, z, s) for (t, x, z), s in pts if abs(t - tk) < (tmax - a.corner) / K]
    up = [(x, z) for x, z, s in near if not s]; lo = [(x, z) for x, z, s in near if s]
    if not up or not lo: continue
    wu = max(abs(x) for x, _ in up) * a.inset; zu = min(z for _, z in up)
    wl = max(abs(x) for x, _ in lo) * a.inset; zl = max(z for _, z in lo)
    taper = min(1.0, (tmax - tk) / 0.4)  # shallower toward the tip, where the snout is thin
    rows_h.append((tk, [(-wu, zu), (0, zu + a.depth * taper), (wu, zu)]))
    rows_j.append((tk, [(-wl, zl + 0.02), (0, zl - a.depth * 0.5 * taper), (wl, zl + 0.02)]))
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

for f in new_faces:
    f.smooth = True
    if bag_uv and uvl:
        for lo in f.loops: lo[uvl].uv = bag_uv
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
