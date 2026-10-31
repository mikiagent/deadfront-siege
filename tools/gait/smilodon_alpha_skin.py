"""SP-SMILODON: the alpha's brown-maned skin (owner's sheet 2) as a recolour of the regular Tripo albedo.

Same mesh, rig and clips; CreatureView model_variants "alpha" swaps the base colour map (Creature.spawn gives it to
alphas only). Luminance is mapped onto the sheet's browns: black stripes and mane -> dark umber, grey -> chestnut,
white fur -> tawny; the ivory sabres keep their colour, the glowing blue eyes turn amber like the sheet's.

usage: Blender -b -P tools/gait/smilodon_alpha_skin.py -- <smilodon.glb> <out_dir>   (writes smilodon_albedo.png and
       smilodon_alpha_albedo.png: the regular map is written too, so both variants are files the same size)
"""
import os
import sys

import bpy
import numpy as np

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.data.materials), key=lambda o: len(o.data.vertices))
bsdf = next(n for n in ob.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
img = bsdf.inputs["Base Color"].links[0].from_node.image
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
rgb = px[..., :3]
lum = rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
lum_m = 0.22 + 0.78 * lum  # the alpha is mottled, not boldly striped: the black stripes come out mid umber
stops = np.array([0.0, 0.18, 0.45, 0.75, 1.0], dtype=np.float32)
cols = np.array([[0.07, 0.045, 0.03], [0.16, 0.09, 0.05], [0.36, 0.21, 0.11], [0.58, 0.40, 0.24], [0.78, 0.66, 0.50]], dtype=np.float32)
out = np.stack([np.interp(lum_m, stops, cols[:, c]) for c in range(3)], -1)
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
ivory = (r > b + 0.08) & (lum > 0.38)
eye = (b > r + 0.15) & (b > 0.35)
out[ivory] = rgb[ivory]
out[eye] = np.array([0.95, 0.62, 0.16], dtype=np.float32) * (0.6 + 0.6 * lum[eye, None])
os.makedirs(OUT, exist_ok=True)
for name, data in (("smilodon_albedo.png", rgb), ("smilodon_alpha_albedo.png", out)):
    im = bpy.data.images.new(name, W, H)
    im.pixels[:] = np.concatenate([np.clip(data, 0, 1), px[..., 3:]], -1).ravel()
    im.filepath_raw = os.path.join(OUT, name); im.file_format = "PNG"; im.save()
    print("WROTE", im.filepath_raw, W, H, "ivory", int(ivory.sum()), "eye", int(eye.sum()))
