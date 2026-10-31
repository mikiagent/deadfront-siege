"""Colour masks for the survivor's look (CHARCREATE): which texels of an albedo atlas belong to which
colour slot, so character creation can tint each slot without touching the rest.

Headless, deterministic, no network:
  Blender -b --factory-startup --python tools/blender/survivor_look_masks.py -- \
      game/assets/characters/survivor game/assets/characters/survivor/look [--debug DIR]

Writes into the output folder (2048, the albedo atlases' size; opaque PNGs, Non-Color):
  survivor_look_base.png    base atlas RGBA: R T-shirt, G shorts, B skin, A hair and brows
  survivor_look_face.png    base atlas RGB:  R iris, G lips (B unused)
  survivor_look_<kit>.png   one per armour kit atlas, RGBA: R chest piece, G legs piece, B arms piece and
                            helmet (sleeves/trim), A skin the kit kept from its Tripo body (hands, face
                            under a helmet, a forearm), so the chosen skin tone carries into the kit
  survivor_look_masks.json  per atlas and channel: the region, its mean colour (sRGB hex), mean linear
                            luminance (the shader scales a tint by texel/mean, keeping the painted folds)
                            and texel count; plus the dilation and the source files

How a texel is classified. Geometry decides the region, never a colour key: hair and clothes are both
near-neutral greys, so a colour threshold cannot tell them apart. Every triangle is rasterised into UV
space and each texel takes its region from its own interpolated bind-pose position:
  base:  above the T-shirt hem -> top, below -> bottoms; inside the eye or lip box on the front of the
         face -> iris / lips; above the collar -> head. Hair is the shell over the scalp: a head triangle
         whose inward ray meets another outward-facing surface within 3 cm (the scalp under it).
  kits:  the piece the triangle belongs to (chest.glb, legs.glb, arms.glb, helmet.glb).
Inside a region the texel's colour only separates skin (warm, lit) from what is not skin; it never decides
between garments. Iris and lips are tightened from their boxes by a colour test (not skin, not white of the
eye; lips redder than the face). A kit texel counts as skin only when it is skin-coloured AND its triangle
lies on the base body's surface (within KIT_SKIN_DIST) over a base polygon that is itself bare skin; skin-coloured means near the chromaticity of the base
body's own skin texels, since tan cloth, leather and bone are warm too.
Every mask is dilated DILATE texels into empty atlas space, so filtering and mips do not pull untinted
texels in at island edges.
"""
import json
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

# Bind-pose landmarks of survivor.glb (Blender Z up, the face looks down -Y), measured from orthographic
# renders with height rings (see the CHARCREATE report).
HEM_Z = 0.943              # T-shirt hem; the shorts' waistband sits under the shirt
FRONT_Y = -0.05            # eye, brow and lip triangles are in front of this
EYES = [((-0.050, -0.019), (1.633, 1.650)), ((0.016, 0.047), (1.633, 1.650))]  # (x range, z range)
BROWS = ((-0.062, 0.062), (1.650, 1.684))
LIPS = ((-0.028, 0.031), (1.566, 1.589))
NECK_Z = 1.53              # above the T-shirt collar nothing is cloth (dark hair reads as grey cloth)
SKULL = Vector((0.0, -0.005, 1.63))
HAIR_MIN_Z = 1.56
FACE_TOP_Z = 1.685         # the front of the face below this (brows, eyes, nose, lips) holds no hair shell
TOP, BOTTOM, EYE, LIP, HEAD, HAIR, BROW = 1, 2, 3, 4, 5, 6, 7
DILATE = 8                 # texels of padding grown into empty atlas space (the gate asks for >= 2)
KIT_SKIN_DIST = 0.012      # a kit triangle within 1.2 cm of the base body can be kept skin
KIT_SKIN_FRACTION = 0.65   # a near-skin kit triangle is skin when this share of its texels is skin-coloured
KIT_CHANNEL = {"chest": 0, "legs": 1, "arms": 2, "helmet": 2}
KITS = ("forager", "hide_and_bone", "travel_clothes")


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type == "MESH" and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o)
    return next(o for o in bpy.data.objects if o not in before and o.type == "MESH" and o.data.uv_layers)


def albedo(ob):
    img = next(n.image for n in ob.active_material.node_tree.nodes
               if n.type == "TEX_IMAGE" and n.image and "Color" in n.image.name)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return img, px.reshape(h, w, 4)[:, :, :3]  # rows bottom-up, sRGB


def base_regions(x, y, z):
    reg = np.where(z > HEM_Z, TOP, BOTTOM).astype(np.uint8)
    front = y < FRONT_Y
    reg[(z > NECK_Z)] = HEAD
    (bx0, bx1), (bz0, bz1) = BROWS
    reg[front & (x >= bx0) & (x <= bx1) & (z >= bz0) & (z <= bz1)] = BROW
    for (x0, x1), (z0, z1) in EYES:
        reg[front & (x >= x0) & (x <= x1) & (z >= z0) & (z <= z1)] = EYE
    (x0, x1), (z0, z1) = LIPS
    reg[front & (x >= x0) & (x <= x1) & (z >= z0) & (z <= z1)] = LIP
    return reg


def rasterise(ob, w, h, reg, region_of, face_region=None):
    """Writes a region id into `reg` for every texel a triangle covers. `region_of(x, y, z)` maps the texel's
    own bind-pose position (so a hem is a straight cut, not a row of triangle teeth); `face_region[poly]`
    overrides it per triangle when given (hair shell, kit piece, triangle id)."""
    me = ob.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    mw = ob.matrix_world
    co = [mw @ v.co for v in me.vertices]
    for t in me.loop_triangles:
        pa, pb, pc = (co[i] for i in t.vertices)
        p = np.array([uv[li].uv[:] for li in t.loops], dtype=np.float64) * (w, h) - 0.5
        x0, y0 = np.floor(p.min(axis=0)).astype(int)
        x1, y1 = np.ceil(p.max(axis=0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, w - 1), min(y1, h - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = p
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        inside = (l1 >= -0.02) & (l2 >= -0.02) & (1.0 - l1 - l2 >= -0.02)  # a hair conservative
        if not inside.any():
            continue
        sub = reg[y0:y1 + 1, x0:x1 + 1]
        fixed = face_region.get(t.polygon_index) if face_region else None
        if fixed is not None:
            sub[inside] = fixed
            continue
        a, b = l1[inside], l2[inside]
        c = 1.0 - a - b
        sub[inside] = region_of(a * pa.x + b * pb.x + c * pc.x, a * pa.y + b * pb.y + c * pc.y,
                                a * pa.z + b * pb.z + c * pc.z)
    return reg


def hair_shell(ob):
    """Polygons of the baked hair: head faces with an outward-facing surface (the scalp) under them, found by
    an inward ray along -normal or a radial ray from the skull centre. Ears pass this test too; the colour
    test below keeps their skin-coloured texels as skin."""
    me = ob.data
    mw = ob.matrix_world
    co = [mw @ v.co for v in me.vertices]
    bvh = BVHTree.FromPolygons([c.to_tuple() for c in co], [tuple(p.vertices) for p in me.polygons])
    rot = mw.to_3x3()
    out = set()
    for p in me.polygons:
        c = sum((co[i] for i in p.vertices), Vector()) / len(p.vertices)
        if c.z < HAIR_MIN_Z or (c.y < FRONT_Y and c.z < FACE_TOP_Z):
            continue  # the mouth and eyelids fold over inner surfaces too
        nw = (rot @ p.normal).normalized()
        loc, n_in, _, _ = bvh.ray_cast(c - nw * 2e-4, -nw, 0.03)
        inward = loc is not None and n_in.dot(nw) > 0.3
        d = c - SKULL
        loc2, _, idx2, dist2 = bvh.ray_cast(SKULL, d.normalized(), d.length)
        radial = loc2 is not None and idx2 != p.index and dist2 < d.length - 0.002
        if inward or radial:
            out.add(p.index)
    return out, bvh


def classify(px):
    mx, mn = px.max(axis=2), px.min(axis=2)
    sat = np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0.0)
    r, g, b = px[:, :, 0], px[:, :, 1], px[:, :, 2]
    warm = smooth(0.0, 0.04, r - b) * smooth(-0.02, 0.02, r - g)       # skin is redder than it is blue
    skin = smooth(0.12, 0.22, sat) * smooth(0.24, 0.38, mx) * warm      # hair and brows are too dark
    sclera = smooth(0.5, 0.65, mx) * (1.0 - smooth(0.15, 0.3, sat))
    redness = smooth(0.06, 0.13, (r - g) / np.maximum(mx, 1e-4) - 0.18)  # lips: redder than the face skin
    return skin, sclera, redness


def chroma(px):
    return px[..., :2] / np.maximum(px.sum(axis=-1, keepdims=True), 1e-4)


def skin_model(px, skin):
    """Chromaticity mean and inverse covariance of the base body's skin texels."""
    c = chroma(px[skin > 0.5]).astype(np.float64)
    return c.mean(axis=0), np.linalg.inv(np.cov(c.T))


def skin_like(px, model):
    """Kit skin by colour: close to the base skin's chromaticity (Mahalanobis) and lit. Tan cloth, leather
    and bone are warm too but sit off the skin's red-green balance."""
    mean, inv = model
    d = chroma(px) - mean
    d2 = np.einsum("...i,ij,...j->...", d, inv, d)
    return (1.0 - smooth(6.0, 12.0, d2)) * smooth(0.22, 0.34, px.max(axis=2))


def dilate(mask, covered, n):
    out = mask.copy()
    have = covered.copy()
    for _ in range(n):
        grown = out.copy()
        filled = have.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(out, (dy, dx), axis=(0, 1))
            shh = np.roll(have, (dy, dx), axis=(0, 1))
            take = ~filled & shh
            grown[take] = sh[take]
            filled |= take
        out, have = grown, filled
    return out


def save_png(path, channels, w, h):
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"  # before the pixels: changing it reloads (blanks) the buffer
    rgba = np.zeros((h, w, 4), dtype=np.float32)
    rgba[:, :, 3] = 1.0
    for i, ch in enumerate(channels):
        rgba[:, :, i] = ch
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def stats(px, wgt):
    tot = float((wgt > 0.5).sum())
    if tot < 1.0:
        return None
    sel = wgt > 0.5
    mean = px[sel].mean(axis=0)
    lum = srgb_to_linear(px[sel]) @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    return {"mean": "#%02x%02x%02x" % tuple(int(round(c * 255)) for c in mean),
            "lum": round(float(lum.mean()), 4), "texels": int(tot)}


def overlap(a, b):
    return int(((a > 0.5) & (b > 0.5)).sum())


def bake_base(src, out_dir, debug):
    ob = import_glb(os.path.join(src, "survivor.glb"))
    img, px = albedo(ob)
    h, w = px.shape[:2]
    shell, bvh = hair_shell(ob)
    reg = rasterise(ob, w, h, np.zeros((h, w), dtype=np.uint8), base_regions, {i: HAIR for i in shell})
    covered = reg > 0
    skin, sclera, redness = classify(px)
    mx = px.max(axis=2)
    eye = (reg == EYE) * (1.0 - skin) * (1.0 - sclera)  # iris (and lash line): neither skin nor white
    lip = (reg == LIP) * redness * smooth(0.2, 0.3, mx)
    skin = skin * covered * (1.0 - eye) * (1.0 - lip)
    not_skin = 1.0 - skin
    top = (reg == TOP) * not_skin
    bottom = (reg == BOTTOM) * not_skin
    hair = ((reg == HAIR) | (reg == BROW)) * not_skin * (1.0 - smooth(0.45, 0.6, mx))  # dark: no sclera
    channels = {"outfit1": top, "outfit2": bottom, "skin": skin, "hair": hair}
    meta = {"texture": img.name, "file": "survivor_look_base.png", "regions": {}}
    for i, (name, m) in enumerate(channels.items()):
        s = stats(px, m)
        if s:
            meta["regions"][name] = dict(channel="rgba"[i], **s)
    face = {"file": "survivor_look_face.png", "texture": img.name, "regions": {}}
    for i, (name, m) in enumerate((("eyes", eye), ("lips", lip))):
        s = stats(px, m)
        if s:
            face["regions"][name] = dict(channel="rgba"[i], **s)
    checks = {"skin_in_outfit1": overlap(skin, top), "skin_in_outfit2": overlap(skin, bottom),
              "skin_in_hair": overlap(skin, hair), "hair_shell_faces": len(shell)}
    base = [dilate(m, covered, DILATE) for m in channels.values()]
    save_png(os.path.join(out_dir, meta["file"]), base, w, h)
    save_png(os.path.join(out_dir, face["file"]), [dilate(m, covered, DILATE) for m in (eye, lip)], w, h)
    if debug:
        vis = px.copy()
        for m, col in zip(base + [eye, lip], ((0, 1, 0), (0, 0.3, 1), (1, 0.5, 0), (0.5, 0.2, 0.05), (1, 0, 1), (1, 0, 0))):
            vis = vis * (1 - m[:, :, None] * 0.7) + np.array(col) * m[:, :, None] * 0.7
        save_png(os.path.join(debug, "base_regions.png"), [vis[:, :, 0], vis[:, :, 1], vis[:, :, 2]], w, h)
    return meta, face, checks, bvh, skin_model(px, skin), face_skin(ob, skin)


def face_skin(ob, skin):
    """Per base polygon: is it bare skin (its UV corners and centre mostly in the skin mask)?"""
    h, w = skin.shape
    uv = ob.data.uv_layers.active.data
    out = np.zeros(len(ob.data.polygons), dtype=bool)
    for p in ob.data.polygons:
        pts = [uv[li].uv for li in p.loop_indices]
        pts.append(sum(pts, Vector((0.0, 0.0))) / len(pts))
        vals = [skin[min(int(q.y * h), h - 1), min(int(q.x * w), w - 1)] for q in pts]
        out[p.index] = float(np.mean(vals)) > 0.5
    return out


def bake_kit(src, kit, out_dir, base_bvh, model, base_skin, debug):
    kit_dir = os.path.join(src, "armor", kit)
    pieces = [p for p in ("chest", "legs", "arms", "helmet") if os.path.exists(os.path.join(kit_dir, p + ".glb"))]
    px = None
    img_name = ""
    reg = None
    face_id = None
    near_faces = [False]  # by face id; 0 = no face
    for piece in pieces:
        ob = import_glb(os.path.join(kit_dir, piece + ".glb"))
        img, ppx = albedo(ob)
        if px is None:
            px, img_name = ppx, img.name
            h, w = px.shape[:2]
            reg = np.zeros((h, w), dtype=np.uint8)
            face_id = np.zeros((h, w), dtype=np.int32)
        elif not np.array_equal(ppx, px):
            raise SystemExit(f"{kit}/{piece}: its albedo differs from the kit's first piece; one mask per atlas assumes copies")
        me = ob.data
        mw = ob.matrix_world
        ids = {}
        for p in me.polygons:
            hit = base_bvh.find_nearest(mw @ p.center)
            # Kept skin lies on the base body where the base shows bare skin (a forearm, a knee through torn
            # jeans, the face under a helmet), never over the base's T-shirt or shorts.
            near_faces.append(hit[0] is not None and hit[3] < KIT_SKIN_DIST and bool(base_skin[hit[2]]))
            ids[p.index] = len(near_faces) - 1
        rasterise(ob, w, h, reg, None, {i: KIT_CHANNEL[piece] + 1 for i in ids})
        rasterise(ob, w, h, face_id, None, ids)
        bpy.data.objects.remove(ob)
    covered = reg > 0
    # One decision per triangle (Tripo's atlas is >1000 small islands: texel morphology would erase whole
    # islands): a near-skin triangle whose texels are mostly skin-coloured is skin, all of it.
    like = skin_like(px, model)
    n = len(near_faces)
    counts = np.bincount(face_id.ravel(), minlength=n)
    frac = np.bincount(face_id.ravel(), weights=like.ravel(), minlength=n) / np.maximum(counts, 1)
    skin_face = (frac > KIT_SKIN_FRACTION) & np.array(near_faces)
    skin_face[0] = False
    skin = skin_face[face_id].astype(np.float32)
    not_skin = 1.0 - skin
    chans = {"outfit1": (reg == 1) * not_skin, "outfit2": (reg == 2) * not_skin, "outfit3": (reg == 3) * not_skin, "skin": skin}
    meta = {"texture": img_name, "file": f"survivor_look_{kit}.png", "pieces": pieces, "regions": {}}
    for i, (name, m) in enumerate(chans.items()):
        s = stats(px, m)
        if s:
            meta["regions"][name] = dict(channel="rgba"[i], **s)
    out = [dilate(m, covered, DILATE) for m in chans.values()]
    save_png(os.path.join(out_dir, meta["file"]), out, w, h)
    if debug:
        vis = px.copy()
        for m, col in zip(out, ((0, 1, 0), (0, 0.3, 1), (1, 0, 1), (1, 0.5, 0))):
            vis = vis * (1 - m[:, :, None] * 0.7) + np.array(col) * m[:, :, None] * 0.7
        save_png(os.path.join(debug, f"{kit}_regions.png"), [vis[:, :, 0], vis[:, :, 1], vis[:, :, 2]], w, h)
    return meta


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, out_dir = argv[0], argv[1]
    debug = argv[argv.index("--debug") + 1] if "--debug" in argv else ""
    os.makedirs(out_dir, exist_ok=True)
    if debug:
        os.makedirs(debug, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base, face, checks, bvh, model, base_skin = bake_base(src, out_dir, debug)
    atlases = {"base": base, "face": face}
    for kit in KITS:
        if os.path.isdir(os.path.join(src, "armor", kit)):
            atlases[kit] = bake_kit(src, kit, out_dir, bvh, model, base_skin, debug)
    meta = {"source": "assets/characters/survivor (survivor.glb and armor/<kit>/*.glb)", "size": 2048,
            "dilate_texels": DILATE, "checks": checks, "atlases": atlases}
    with open(os.path.join(out_dir, "survivor_look_masks.json"), "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
        f.write("\n")
    print("[masks]", json.dumps(checks), json.dumps({k: sorted(v["regions"]) for k, v in atlases.items()}))


main()
