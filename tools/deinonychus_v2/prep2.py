# Tripo mesh -> contract frame (head +Y = glTF -Z, feet on z=0, 3.6 m tall, centred on the feet), UV seams welded,
# and face winding made to agree with Tripo's own vertex normals. 7.5 % of Tripo's faces are wound against its
# normals; after the weld Blender rebuilt normals from that winding and 13 % of vertex normals pointed inward, so
# Godot (double-sided material, normal flipped on back faces) lit the coat from the wrong side: it read blue-grey.
# Blender -b --factory-startup -P prep2.py -- <tripo model.glb> <out.blend>
import bpy, bmesh, sys, math, numpy as np
from mathutils import Matrix, Vector, kdtree
a = sys.argv[sys.argv.index("--") + 1:]
H = 3.6
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
o = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
me0 = o.data
# Tripo's per-vertex normals (corner normals averaged per vertex), in the import frame
cn = np.empty(len(me0.loops) * 3); me0.corner_normals.foreach_get("vector", cn); cn = cn.reshape(-1, 3)
lv = np.empty(len(me0.loops), np.int64); me0.loops.foreach_get("vertex_index", lv)
vn = np.zeros((len(me0.vertices), 3)); np.add.at(vn, lv, cn)
me = o.data.copy(); me.transform(o.matrix_world); o.data = me; o.parent = None; o.matrix_world = Matrix.Identity(4)
R = (Matrix.Rotation(math.pi / 2, 3, "Z") @ o.matrix_world.to_3x3())
for x in list(bpy.data.objects):
    if x is not o: bpy.data.objects.remove(x, do_unlink=True)
rot = Matrix.Rotation(math.pi / 2, 4, "Z")  # Tripo multiview faces +X; the contract wants +Y (glTF -Z)
me.transform(rot)
vn = vn @ np.array(rot.to_3x3()).T
zs = [v.co.z for v in me.vertices]; k = H / (max(zs) - min(zs))
me.transform(Matrix.Translation((0, 0, -min(zs)))); me.transform(Matrix.Scale(k, 4))
feet = [v.co for v in me.vertices if v.co.z < 0.08]
cx = (max(v.co.x for v in me.vertices) + min(v.co.x for v in me.vertices)) / 2
cy = (max(v.y for v in feet) + min(v.y for v in feet)) / 2
me.transform(Matrix.Translation((-cx, -cy, 0)))
P0 = np.array([v.co[:] for v in me.vertices])
kd = kdtree.KDTree(len(P0))
for i, p in enumerate(P0): kd.insert(p, i)
kd.balance()
bm = bmesh.new(); bm.from_mesh(me); n0 = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0015)
bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
# reference normal per welded vertex: sum of Tripo normals of every original vertex merged into it
ref = []
for v in bm.verts:
    s = np.zeros(3)
    for (co, j, d) in kd.find_range(v.co, 0.0016): s += vn[j]
    ref.append(s)
ref = np.array(ref)
flipped = 0
for f in bm.faces:
    r = sum((ref[v.index] for v in f.verts), np.zeros(3))
    if np.dot(r, np.array(f.normal[:])) < 0:
        f.normal_flip(); flipped += 1
bm.normal_update()
bad = sum(1 for f in bm.faces if np.dot(sum((ref[v.index] for v in f.verts), np.zeros(3)), np.array(f.normal[:])) < 0)
bm.to_mesh(me); bm.free()
# Keep Tripo's own shading normals as custom split normals (the weld merged front and back faces of the feather
# shards, whose averaged vertex normals cancel): each corner takes the merged source normal that best faces its face.
vnn = vn / np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-9)
cand = [[j for (co, j, d) in kd.find_range(v.co, 0.0016)] for v in me.vertices]
loop_n = []
for poly in me.polygons:
    fn = np.array(poly.normal[:])
    for li in range(poly.loop_start, poly.loop_start + poly.loop_total):
        js = cand[me.loops[li].vertex_index]
        best = max(js, key=lambda j: np.dot(vnn[j], fn)) if js else None
        n = vnn[best] if best is not None and np.dot(vnn[best], fn) > 0 else fn
        loop_n.append(tuple(n))
me.normals_split_custom_set(loop_n)
print("PREP custom normals set on", len(loop_n), "corners")
print("PREP welded", n0, "->", len(me.vertices), "faces flipped to match Tripo normals", flipped, "still disagreeing", bad)
o.name = me.name = "SM_Deinonychus"
if me.materials: me.materials[0].name = "M_Deinonychus"
col = bpy.data.collections.new("COL_Export"); bpy.context.scene.collection.children.link(col)
for c in o.users_collection: c.objects.unlink(o)
col.objects.link(o)
V = np.array([v.co[:] for v in me.vertices])
print("PREP scale", round(k, 4), "verts", len(V), "min", V.min(0).round(3), "max", V.max(0).round(3))
for im in bpy.data.images: im.pack()
bpy.ops.wm.save_as_mainfile(filepath=a[1])
