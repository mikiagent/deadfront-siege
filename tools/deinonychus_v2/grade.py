# Global value lift of Tripo's colour map toward the approved sheet (median V 0.243 -> ~0.33, the sheet's 0.333):
# every texel's RGB is scaled by v'/v with v' = v^0.78 (v = max channel), so hue and saturation are unchanged.
# Blender -b anim.blend -P grade.py -- <out.blend> <graded.jpg>
import bpy, sys, numpy as np
a = sys.argv[sys.argv.index("--") + 1:]
src = next(i for i in bpy.data.images if i.name.startswith("Color"))
w, h = src.size
px = np.array(src.pixels[:]).reshape(-1, 4)
v = px[:, :3].max(1); k = np.where(v > 1e-4, np.power(np.maximum(v, 1e-4), 0.78) / np.maximum(v, 1e-4), 1.0)
px[:, :3] = np.clip(px[:, :3] * k[:, None], 0, 1)
g = bpy.data.images.new("Color_f346e472_graded", w, h, alpha=False)
g.pixels[:] = px.ravel(); g.filepath_raw = a[1]; g.file_format = "JPEG"
bpy.context.scene.render.image_settings.quality = 92
g.save(); bpy.data.images.remove(g)
g = bpy.data.images.load(a[1]); g.name = "Color_f346e472_graded"; g.pack()
n = 0
for m in bpy.data.materials:
    if not m.use_nodes: continue
    for nd in m.node_tree.nodes:
        if nd.type == "TEX_IMAGE" and nd.image == src: nd.image = g; n += 1
# Matte feathers: Tripo's roughness (ORM green, mean 0.65) let the feather shards mirror the blue sky in Godot, so the
# brown-black coat read blue-grey next to the warm velociraptor. Remap roughness to 0.55 + 0.45 * r (mean ~0.84).
orm = next(i for i in bpy.data.images if i.name.startswith("ORM"))
op = np.array(orm.pixels[:]).reshape(-1, 4); r0 = op[:, 1].mean()
op[:, 1] = 0.55 + 0.45 * op[:, 1]
og = bpy.data.images.new("ORM_f346e472_matte", orm.size[0], orm.size[1], alpha=False)
og.pixels[:] = op.ravel(); og.filepath_raw = a[1].replace("Color_f346e472_graded", "ORM_f346e472_matte"); og.file_format = "JPEG"; og.save(); bpy.data.images.remove(og)
og = bpy.data.images.load(a[1].replace("Color_f346e472_graded", "ORM_f346e472_matte")); og.name = "ORM_f346e472_matte"; og.colorspace_settings.name = "Non-Color"; og.pack()
for m in bpy.data.materials:
    if not m.use_nodes: continue
    for nd in m.node_tree.nodes:
        if nd.type == "TEX_IMAGE" and nd.image == orm: nd.image = og; n += 1
print("MATTE roughness mean %.3f -> %.3f" % (r0, np.array(og.pixels[:]).reshape(-1, 4)[:, 1].mean()))
v2 = np.array(g.pixels[:]).reshape(-1, 4)[:, :3].max(1)
print("GRADED nodes", n, "V median %.3f -> %.3f p10 %.3f p90 %.3f" % (np.median(v), np.median(v2), np.percentile(v2, 10), np.percentile(v2, 90)))
bpy.ops.wm.save_as_mainfile(filepath=a[0])
