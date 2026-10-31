"""SP-RAPTOR palettes: recolour the Raptor's albedo into its colour morphs (one mesh, variants by texture).

Owner 2026-10-30: "black and gold is the original raptor ... it comes in different colors including green and
different feathers". # ASSUMPTION (the palette list is not in the PRD): each morph recolours the hide (the near-black
scales) and the feathers (the gold crest, quills and arm fans, plus the gold flecks) separately, keeping every pixel's
shading, so the scale and feather detail of the Tripo texture carries over. Red/pink (the mouth) is left alone.
Wild spawns pick one per animal (CreatureView.pick_variant); the lab's Body button steps through them.

  black_gold    the original (the GLB's own albedo, no file)
  black_crimson black hide, crimson feathers (the feather morph)
  green         dark olive-green hide, amber-yellow feathers
  rust          rust-brown hide, cream feathers
  slate         dark olive-grey hide with darker bands across the back, flanks and tail, muted bronze feathers
                (RAPTORFLANK 2026-10-31, owner: "Slate was such a weird color"; it was blue-grey with ice-blue feathers.
                The id stays "slate" so saved pets keep their morph.)

usage: Blender -b -P tools/gait/raptor_palettes.py -- <raptor.glb> <out_dir>   (writes raptor_<id>_albedo.jpg)
"""
import colorsys  # noqa: F401  (documentation of the hsv convention below)
import os
import sys

import bpy
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
GLB, OUT = a[0], a[1]
# id: (hide hue deg, hide saturation, hide value gain, hide value lift, feather hue deg, feather sat mult, feather val mult)
PALETTES = {
    "black_crimson": (0, 0.0, 1.0, 0.0, 352, 1.05, 0.85),
    "green": (98, 0.50, 1.9, 0.035, 52, 1.0, 1.0),
    "rust": (18, 0.62, 2.2, 0.05, 38, 0.30, 1.12),
    "slate": (80, 0.22, 1.55, 0.05, 36, 0.40, 0.72),
}
# Morphs with dark bands (# ASSUMPTION, the look of the owner's black-gold sheet): the band strength multiplies the
# hide value down by up to this share, strongest along the back and fading toward the belly.
BANDS = {"slate": 0.6}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
img = None
for m in bpy.data.materials:
    if not m.use_nodes:
        continue
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    link = bsdf.inputs["Base Color"].links[0] if bsdf and bsdf.inputs["Base Color"].links else None
    if link and link.from_node.type == "TEX_IMAGE":
        img = link.from_node.image
        break
assert img is not None, "no base colour texture"
W, H = img.size
px = np.empty(W * H * 4, dtype=np.float32)
img.pixels.foreach_get(px)
px = px.reshape(H, W, 4)
rgb = px[..., :3]


def rgb_to_hsv(c):
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    mx, mn = c.max(-1), c.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rr = m & (mx == r)
    gg = m & (mx == g) & ~rr
    bb = m & ~rr & ~gg
    h[rr] = ((g - b)[rr] / d[rr]) % 6
    h[gg] = (b - r)[gg] / d[gg] + 2
    h[bb] = (r - g)[bb] / d[bb] + 4
    return h * 60.0, np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0), mx


def hsv_to_rgb(h, s, v):
    h = (h % 360.0) / 60.0
    i = np.floor(h).astype(int) % 6
    f = h - np.floor(h)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    out = np.stack([np.choose(i, [v, q, p, p, t, v]), np.choose(i, [t, v, v, q, p, p]), np.choose(i, [p, p, t, v, v, q])], -1)
    return np.clip(out, 0.0, 1.0)


def ramp(x, a, b):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def body_coords():
    """Per texel: the rest-pose position along the body (y, 0 at the snout) and the height share (0 belly .. 1 back),
    rasterised from the mesh UVs (-1 where no triangle covers the texel)."""
    me_obj = max((o for o in bpy.data.objects if o.type == "MESH" and o.data.uv_layers), key=lambda o: len(o.data.vertices))
    me = me_obj.data
    me.calc_loop_triangles()
    uv = np.array([d.uv[:] for d in me.uv_layers.active.data], dtype=np.float64)
    co = np.array([me_obj.matrix_world @ v.co for v in me.vertices], dtype=np.float64)
    ly = np.full((H, W), -1.0)
    lz = np.full((H, W), -1.0)
    zmin, zmax = co[:, 2].min(), co[:, 2].max()
    for t in me.loop_triangles:
        p = uv[list(t.loops)] * [W, H]
        q = co[list(t.vertices)]
        x0, y0 = np.floor(p.min(0)).astype(int)
        x1, y1 = np.ceil(p.max(0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, W - 1), min(y1, H - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(d) < 1e-12:
            continue
        a = ((p[1, 1] - p[2, 1]) * (gx - p[2, 0]) + (p[2, 0] - p[1, 0]) * (gy - p[2, 1])) / d
        b = ((p[2, 1] - p[0, 1]) * (gx - p[2, 0]) + (p[0, 0] - p[2, 0]) * (gy - p[2, 1])) / d
        c = 1 - a - b
        m = (a >= -0.02) & (b >= -0.02) & (c >= -0.02)
        if not m.any():
            continue
        yy = a * q[0, 1] + b * q[1, 1] + c * q[2, 1]
        zz = a * q[0, 2] + b * q[1, 2] + c * q[2, 2]
        sub_y = ly[y0:y1 + 1, x0:x1 + 1]
        sub_z = lz[y0:y1 + 1, x0:x1 + 1]
        sub_y[m] = yy[m] - co[:, 1].min()
        sub_z[m] = (zz[m] - zmin) / (zmax - zmin)
    for _ in range(4):  # bleed into the seam padding
        for arr in (ly, lz):
            empty = arr < 0
            for sh in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                nb = np.roll(arr, sh, (0, 1))
                fill = empty & (nb >= 0)
                arr[fill] = nb[fill]
                empty = arr < 0
    return ly, lz


h, s, v = rgb_to_hsv(rgb)
red = ((h < 12) | (h > 330)) & (s > 0.3)  # the mouth bag, gums and tongue: untouched
feather = ramp(s, 0.30, 0.55) * ramp(v, 0.18, 0.40) * ((h > 12) & (h < 60))
feather = np.where(red, 0.0, feather)
hide = np.where(red, 0.0, 1.0 - feather)
print(f"albedo {W}x{H}: feather share {feather.mean():.3f}, hide share {hide.mean():.3f}, red {red.mean():.3f}")
os.makedirs(OUT, exist_ok=True)
for pid, (hh, hs, hg, hl, fh, fs, fv) in PALETTES.items():
    hv = np.clip(v * hg + hl, 0, 1)
    if pid in BANDS:
        ly, lz = body_coords()
        # bands across the body every ~0.3 m (0.042 mesh units at 3.5 m), wavy so they do not read as rulings, thin and
        # broken on the flank, gone on the belly and the head (the first 0.18 units from the snout)
        ph = ly / 0.042 + 0.35 * np.sin(lz * 9.0) + 0.15 * np.sin(ly * 160.0)
        band = ramp(np.cos(2 * np.pi * ph), 0.25, 0.85) * ramp(lz, 0.25, 0.55) * ramp(ly, 0.17, 0.24) * (ly >= 0)
        hv = hv * (1.0 - BANDS[pid] * band)
    hide_rgb = hsv_to_rgb(np.full_like(h, hh), np.full_like(s, hs) if hs else s, hv) if hs else rgb
    feat_rgb = hsv_to_rgb(fh + (h - 36.0) * 0.5, np.clip(s * fs, 0, 1), np.clip(v * fv, 0, 1))
    out = rgb * (1 - hide[..., None] - feather[..., None]) + hide_rgb * hide[..., None] + feat_rgb * feather[..., None]
    res = px.copy()
    res[..., :3] = out
    im = bpy.data.images.new(pid, W, H)
    im.pixels.foreach_set(res.ravel())
    path = os.path.join(OUT, f"raptor_{pid}_albedo.jpg")
    im.filepath_raw = path
    im.file_format = "JPEG"
    bpy.context.scene.render.image_settings.quality = 90
    im.save()
    print("WROTE", path)
