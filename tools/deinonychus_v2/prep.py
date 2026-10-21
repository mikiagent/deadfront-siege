# Tripo mesh -> contract frame: head +Y (glTF -Z), feet on z=0, centred on the feet, 3.6 m tall (game height_meters),
# seams welded. Blender -b --factory-startup -P prep.py -- <in.glb> <out.blend>
import bpy, bmesh, sys, math
from mathutils import Matrix, Vector
a = sys.argv[sys.argv.index("--") + 1:]
H = 3.6
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
o = next(o for o in bpy.data.objects if o.type == "MESH")
me = o.data.copy(); me.transform(o.matrix_world); o.data = me; o.parent = None; o.matrix_world = Matrix.Identity(4)
for x in list(bpy.data.objects):
    if x is not o: bpy.data.objects.remove(x, do_unlink=True)
me.transform(Matrix.Rotation(math.pi / 2, 4, "Z"))  # Tripo multiview faces +X; the contract wants +Y (glTF -Z)
zs = [v.co.z for v in me.vertices]; k = H / (max(zs) - min(zs))
me.transform(Matrix.Translation((0, 0, -min(zs)))); me.transform(Matrix.Scale(k, 4))
feet = [v.co for v in me.vertices if v.co.z < 0.08]
cx = (max(v.co.x for v in me.vertices) + min(v.co.x for v in me.vertices)) / 2
cy = (max(v.y for v in feet) + min(v.y for v in feet)) / 2
me.transform(Matrix.Translation((-cx, -cy, 0)))
bm = bmesh.new(); bm.from_mesh(me); n0 = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0015); bm.to_mesh(me); bm.free()
print("welded", n0, "->", len(me.vertices))
o.name = me.name = "SM_Deinonychus"
if me.materials: me.materials[0].name = "M_Deinonychus"
col = bpy.data.collections.new("COL_Export"); bpy.context.scene.collection.children.link(col)
for c in o.users_collection: c.objects.unlink(o)
col.objects.link(o)
V = [v.co for v in me.vertices]
print("PREP scale", round(k, 4), "verts", len(V), "x", round(min(v.x for v in V), 3), round(max(v.x for v in V), 3),
      "y", round(min(v.y for v in V), 3), round(max(v.y for v in V), 3), "z", round(min(v.z for v in V), 3), round(max(v.z for v in V), 3))
# metallic check (Tripo PBR carries metallic): mean of the ORM blue channel
import numpy as np
for im in bpy.data.images:
    if im.name.startswith("ORM") and im.size[0]:
        px = np.array(im.pixels[:]).reshape(-1, 4)
        print("ORM mean R(ao) G(rough) B(metal)", px[:, 0].mean().round(3), px[:, 1].mean().round(3), px[:, 2].mean().round(3), "metal>0.5 frac", (px[:, 2] > 0.5).mean().round(4))
for im in bpy.data.images: im.pack()
bpy.ops.wm.save_as_mainfile(filepath=a[1])
