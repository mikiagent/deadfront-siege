# Matte hide: Tripo's roughness (ORM green, mean 0.57) lets the hide mirror the blue sky in Godot (the Deinonychus coat
# read blue-grey until the same fix). Remap roughness to 0.55 + 0.45 * r on every texel; colour and normal maps unchanged.
# Blender -b anim.blend --factory-startup -P matte.py -- <out.blend> <orm_out.jpg>
import bpy, sys, numpy as np
a = sys.argv[sys.argv.index("--") + 1:]
orm = next(i for i in bpy.data.images if i.name.startswith("ORM"))
op = np.array(orm.pixels[:]).reshape(-1, 4); r0 = op[:, 1].mean()
op[:, 1] = 0.55 + 0.45 * op[:, 1]
tag = orm.name.split("_", 1)[1][:8] if "_" in orm.name else "tripo"
og = bpy.data.images.new(f"ORM_{tag}_matte", orm.size[0], orm.size[1], alpha=False)
og.pixels[:] = op.ravel(); og.filepath_raw = a[1]; og.file_format = "JPEG"
bpy.context.scene.render.image_settings.quality = 92
og.save(); bpy.data.images.remove(og)
og = bpy.data.images.load(a[1]); og.name = f"ORM_{tag}_matte"; og.colorspace_settings.name = "Non-Color"; og.pack()
n = 0
for m in bpy.data.materials:
    if not m.use_nodes: continue
    for nd in m.node_tree.nodes:
        if nd.type == "TEX_IMAGE" and nd.image == orm: nd.image = og; n += 1
print("MATTE nodes", n, "roughness mean %.3f -> %.3f" % (r0, np.array(og.pixels[:]).reshape(-1, 4)[:, 1].mean()))
bpy.ops.wm.save_as_mainfile(filepath=a[0])
