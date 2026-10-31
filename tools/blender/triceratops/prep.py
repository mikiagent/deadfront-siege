# Tripo mesh -> contract frame: head +Y (glTF -Z), feet on z=0, centred on the feet, 9.0 m from beak tip to tail tip
# (the approved sheet's scale), UV seams welded, face winding made to agree with Tripo's own vertex normals (the
# Deinonychus had 7.5 % of faces wound against them and read blue-grey in Godot), Tripo's shading normals kept.
# Blender -b --factory-startup -P prep.py -- <tripo model.glb> <out.blend> [beak_to_tail_m]
import bpy, bmesh, sys, math, numpy as np
from mathutils import Matrix, kdtree
a = sys.argv[sys.argv.index("--") + 1:]
L_TARGET = float(a[2]) if len(a) > 2 else 9.0
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
o = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
me0 = o.data
cn = np.empty(len(me0.loops) * 3); me0.corner_normals.foreach_get("vector", cn); cn = cn.reshape(-1, 3)
lv = np.empty(len(me0.loops), np.int64); me0.loops.foreach_get("vertex_index", lv)
vn = np.zeros((len(me0.vertices), 3)); np.add.at(vn, lv, cn)
me = o.data.copy(); me.transform(o.matrix_world); vn = vn @ np.array(o.matrix_world.to_3x3()).T
o.data = me; o.parent = None; o.matrix_world = Matrix.Identity(4)
for x in list(bpy.data.objects):
    if x is not o: bpy.data.objects.remove(x, do_unlink=True)
rot = Matrix.Rotation(math.pi / 2, 4, "Z")  # Tripo multiview faces +X; the contract wants +Y (glTF -Z)
me.transform(rot); vn = vn @ np.array(rot.to_3x3()).T
P = np.array([v.co[:] for v in me.vertices])
H0 = P[:, 2].max() - P[:, 2].min(); z = (P[:, 2] - P[:, 2].min()) / H0
# the head end carries the brow horns: its outer tenth reaches far higher than the tail tip
yn = (P[:, 1] - P[:, 1].min()) / (P[:, 1].max() - P[:, 1].min())
assert z[yn > 0.9].max() > z[yn < 0.1].max() + 0.15, "head is not at +Y"
beak = P[z < 0.6, 1].max(); tail = P[:, 1].min()  # beak tip: the front-most point below the nose horn
k = L_TARGET / (beak - tail)
me.transform(Matrix.Translation((0, 0, -P[:, 2].min()))); me.transform(Matrix.Scale(k, 4))
V = np.array([v.co[:] for v in me.vertices])
feet = V[V[:, 2] < 0.08]
cx = (V[:, 0].max() + V[:, 0].min()) / 2; cy = (feet[:, 1].max() + feet[:, 1].min()) / 2
me.transform(Matrix.Translation((-cx, -cy, 0)))
P0 = np.array([v.co[:] for v in me.vertices])
kd = kdtree.KDTree(len(P0))
for i, p in enumerate(P0): kd.insert(p, i)
kd.balance()
bm = bmesh.new(); bm.from_mesh(me); n0 = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0015)
bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
ref = np.array([sum((vn[j] for (_, j, _) in kd.find_range(v.co, 0.0016)), np.zeros(3)) for v in bm.verts])
flipped = 0
for f in bm.faces:
    if np.dot(sum((ref[v.index] for v in f.verts), np.zeros(3)), np.array(f.normal[:])) < 0:
        f.normal_flip(); flipped += 1
bm.normal_update()
bad = sum(1 for f in bm.faces if np.dot(sum((ref[v.index] for v in f.verts), np.zeros(3)), np.array(f.normal[:])) < 0)
bm.to_mesh(me); bm.free()
vnn = vn / np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-9)
cand = [[j for (_, j, _) in kd.find_range(v.co, 0.0016)] for v in me.vertices]
loop_n = []
for poly in me.polygons:
    fn = np.array(poly.normal[:])
    for li in range(poly.loop_start, poly.loop_start + poly.loop_total):
        js = cand[me.loops[li].vertex_index]
        best = max(js, key=lambda j: np.dot(vnn[j], fn)) if js else None
        loop_n.append(tuple(vnn[best] if best is not None and np.dot(vnn[best], fn) > 0 else fn))
me.normals_split_custom_set(loop_n)
print("PREP welded", n0, "->", len(me.vertices), "faces", len(me.polygons), "flipped to match Tripo normals", flipped,
      f"({100 * flipped / len(me.polygons):.1f} %)", "still disagreeing", bad)
o.name = me.name = "SM_Triceratops"
if me.materials: me.materials[0].name = "M_Triceratops"
col = bpy.data.collections.new("COL_Export"); bpy.context.scene.collection.children.link(col)
for c in o.users_collection: c.objects.unlink(o)
col.objects.link(o)
V = np.array([v.co[:] for v in me.vertices]); z = V[:, 2]
print("PREP scale", round(k, 4), "beak-to-tail", L_TARGET, "height", round(z.max(), 3), "min", V.min(0).round(3), "max", V.max(0).round(3))
for im in bpy.data.images: im.pack()
bpy.ops.wm.save_as_mainfile(filepath=a[1])
