"""SP-DILOPHOSAURUS: the alpha's skin (owner's sheet 2: olive hide with rust spots, a fiery orange and yellow frill)
as a recolour of the regular albedo.

Same mesh, rig and clips; CreatureView model_variants "alpha" swaps the base colour map (Creature.spawn gives it to
alphas only). The body part of the atlas (top 80 %) maps luminance onto the sheet's olives and lays soft rust blotches
over the mid tones; reddish pixels (the feet, the mouth) keep some of their own colour. The frill strip is repainted
with dilophosaurus_frill.paint("alpha").

usage: Blender -b -P tools/gait/dilophosaurus_alpha_skin.py -- <dilophosaurus.glb> <out.jpg>
"""
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dilophosaurus_frill import STRIP, paint  # noqa: E402

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.data.materials), key=lambda o: len(o.data.vertices))
bsdf = next(n for n in ob.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
img = bsdf.inputs["Base Color"].links[0].from_node.image
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
rgb = px[..., :3].copy()
lum = rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
keys = np.array([0.0, 0.12, 0.35, 0.6, 0.85, 1.0], dtype=np.float32)
pal = np.array([[0.05, 0.05, 0.02], [0.14, 0.14, 0.06], [0.33, 0.33, 0.15], [0.52, 0.5, 0.29], [0.74, 0.68, 0.46], [0.92, 0.88, 0.75]], dtype=np.float32)
out = np.stack([np.interp(lum, keys, pal[:, c]) for c in range(3)], -1)
# rust blotches: low-frequency noise from a few hundred soft dots, on the mid tones only
rng = np.random.default_rng(11)
small = np.zeros((H // 16, W // 16), np.float32)
yy, xx = np.mgrid[0:H // 16, 0:W // 16]
for _ in range(260):
    cy, cx, r = rng.uniform(0, H // 16), rng.uniform(0, W // 16), rng.uniform(0.8, 2.6)
    small += np.exp(-((yy - cy) ** 2 + (xx - cx) ** 2) / (2 * r * r))
mask = np.kron(np.clip((small - 0.45) / 0.5, 0, 1), np.ones((16, 16), np.float32))[:H, :W]
mask *= np.clip(1 - np.abs(lum - 0.4) / 0.3, 0, 1)
rust = np.array([0.58, 0.26, 0.09], np.float32)
out = out * (1 - 0.7 * mask[..., None]) + rust * (0.7 * mask[..., None]) * (0.6 + lum[..., None])
red = np.clip((rgb[..., 0] - rgb[..., 1] - 0.1) / 0.15, 0, 1)[..., None]
out = out * (1 - 0.6 * red) + rgb * 0.6 * red
strip = int(round(H * STRIP))
out[:strip] = paint("alpha", W, strip)  # Blender rows run bottom-up: the frill strip is the first rows
px[..., :3] = np.clip(out, 0, 1)
new = bpy.data.images.new("alpha", W, H)
new.pixels[:] = px.ravel()
new.filepath_raw = OUT
new.file_format = "JPEG"
bpy.context.scene.render.image_settings.quality = 90
new.save()
print("ALPHA wrote", OUT, W, H)
