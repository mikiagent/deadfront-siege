"""SP-CERATOSAURUS: the alpha's camo skin (owner's sheet 2: olive, dark brown, cream and orange camo, orange throat and
belly) as a recolour of the regular Tripo albedo. Same mesh, rig and clips; CreatureView model_variants "alpha" swaps the
base colour map (Creature.spawn gives it to alphas only).

- Hide: the regular map's dark bands and rust blotches already make a coherent blotch pattern across UV seams, so its
  luminance is mapped onto the sheet's camo: black-brown -> dark brown -> olive green -> khaki -> cream.
- Throat and belly: faces of the underside (normal pointing down, between the legs' tops and the jaw, ahead of the tail
  base) are rasterised into a UV mask; there the pale skin turns the sheet's orange.
- Claws, teeth and the mouth bag keep their colours (pale islands outside the mask stay cream, the bag has its own
  material). # ASSUMPTION: the sheet's bigger nasal crest and brow horns are not carried (texture swap only, no second
  Tripo generation; Open Questions CE5).

usage: Blender -b -P tools/gait/ceratosaurus_alpha_skin.py -- <ceratosaurus.glb> <out.png>
"""
import sys

import bpy
import numpy as np

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.data.materials), key=lambda o: len(o.data.vertices))
mat = next(m for m in ob.data.materials if m and m.node_tree and any(n.type == "TEX_IMAGE" for n in m.node_tree.nodes))
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
img = bsdf.inputs["Base Color"].links[0].from_node.image
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
rgb = px[..., :3]
lum = rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
mx, mn = rgb.max(-1), rgb.min(-1)
sat = (mx - mn) / np.maximum(mx, 1e-4)

# underside mask in UV space (rest pose, Blender z-up, head -Y)
me = ob.data
me.calc_loop_triangles()
uv = me.uv_layers.active.data
mw = ob.matrix_world
mask = np.zeros((H, W), dtype=bool)
zs = [(mw @ v.co).z for v in me.vertices]
top = max(zs)
for t in me.loop_triangles:
    c = mw @ t.center
    n = (mw.to_3x3() @ t.normal).normalized()
    # underside: throat, chest and belly (not the legs below the belly line, not the tail underside)
    if n.z > -0.25 or c.y > 0.05 or c.z < 0.42 * top or c.z > 0.83 * top or (abs(c.x) > 0.05 and c.z < 0.5 * top):
        continue
    p = np.array([[uv[i].uv[0] * (W - 1), uv[i].uv[1] * (H - 1)] for i in t.loops])
    x0, y0 = np.floor(p.min(0)).astype(int)
    x1, y1 = np.ceil(p.max(0)).astype(int)
    if x1 - x0 > W // 4 or y1 - y0 > H // 4:
        continue
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
    a, b, cc = p
    d = (b[1] - cc[1]) * (a[0] - cc[0]) + (cc[0] - b[0]) * (a[1] - cc[1])
    if abs(d) < 1e-9:
        continue
    l1 = ((b[1] - cc[1]) * (xs - cc[0]) + (cc[0] - b[0]) * (ys - cc[1])) / d
    l2 = ((cc[1] - a[1]) * (xs - cc[0]) + (a[0] - cc[0]) * (ys - cc[1])) / d
    ins = (l1 >= -0.02) & (l2 >= -0.02) & (1 - l1 - l2 >= -0.02)
    yy, xx = ys[ins].clip(0, H - 1), xs[ins].clip(0, W - 1)
    mask[yy, xx] = True
print("underside texels", int(mask.sum()), "of", W * H)

# stops at luminance quantiles of the used texels, so the camo shares come out like the sheet's whatever the map's
# exposure: about a third dark brown-black blotches, a third olive, the rest khaki and cream
used = lum[px[..., 3] > 0.5]
q = np.quantile(used, [0.0, 0.2, 0.36, 0.52, 0.7, 0.86, 1.0]).astype(np.float32)
print("lum quantiles", np.round(q, 3))
stops = q
cols = np.array([[0.04, 0.03, 0.02], [0.10, 0.07, 0.04], [0.17, 0.13, 0.07], [0.27, 0.30, 0.12],
                 [0.40, 0.42, 0.18], [0.66, 0.58, 0.36], [0.88, 0.82, 0.64]], dtype=np.float32)
out = np.stack([np.interp(lum, stops, cols[:, c]) for c in range(3)], -1)
# rust blotches (saturated orange mid tones) become olive-khaki camo patches
rust = (sat > 0.55) & (lum > 0.22) & (lum < 0.5) & (rgb[..., 0] > rgb[..., 2] + 0.15)
out[rust] = (np.array([0.50, 0.50, 0.24], dtype=np.float32) * (0.7 + 0.9 * lum[rust, None])).clip(0, 1)  # olive-khaki
hot = rust & (sat > 0.8) & (lum > 0.3)  # only the hottest rust flecks stay orange, like the sheet's scattered orange spots
out[hot] = (np.array([0.80, 0.46, 0.16], dtype=np.float32) * (0.8 + 0.6 * lum[hot, None])).clip(0, 1)
pale = mask & (lum > 0.2)
out[pale] = (np.array([0.93, 0.45, 0.14], dtype=np.float32) * (0.55 + 0.7 * lum[pale, None])).clip(0, 1)
print("rust", int(rust.sum()), "hot", int(hot.sum()), "orange underside", int(pale.sum()))
im = bpy.data.images.new("alpha", W, H)
im.pixels[:] = np.concatenate([np.clip(out, 0, 1), px[..., 3:]], -1).ravel()
im.filepath_raw = OUT
im.file_format = "JPEG"
im.save()
print("WROTE", OUT, W, H)
