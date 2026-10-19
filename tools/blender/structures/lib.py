"""Shared kit for the DEADFRONT structure set: one painted 1024 atlas, bmesh primitives that
UV themselves into atlas tiles, and a GLB exporter. Every structure script imports this.

Runs inside Blender (live via MCP, or headless: Blender -b -P build.py -- <names>).
Blender is Z up, metres; glTF export turns it into Y up. Models are built with their base at
z = 0 and centred on x = y = 0 so the GLB origin is the ground centre.
"""
import math
import os
import random
import zlib

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_DIR = os.path.join(REPO, "game", "assets", "props", "blender")
ATLAS_PATH = os.path.join(OUT_DIR, "structures_atlas.png")  # also the Godot material texture
ATLAS = 1024
GRID = 8  # 8x8 tiles of 128 px
TILE_PX = ATLAS // GRID
INSET = 6.0 / TILE_PX  # keep UVs off tile borders so mips do not bleed neighbours
MAT_NAME = "structures_atlas"
SCENE_PREFIX = "STRUCTART_"

# Tile name -> (column, row) in the 8x8 grid. Row 0 is the top of the image.
TILES = [
    "wood", "wood_dark", "plank", "bark", "log_end", "char", "wheel", "weathered",
    "canvas", "hide", "rope", "thatch", "weave", "steamer_weave", "leather_dark", "fiber",
    "stone", "stone_dark", "cobble", "clay", "clay_dark", "iron", "ash", "ember",
    "meat_raw", "meat_drying", "meat_dried", "water", "soot", "sign_board", "dirt", "bone",
    "meat_fat",
]
TILE_INDEX = {n: i for i, n in enumerate(TILES)}


# ---------------------------------------------------------------- atlas painting (numpy)

def _rng(seed):
    return np.random.default_rng(seed)


def _value_noise(rng, n, cells_u, cells_v):
    """Smooth tileable value noise, n x n, in 0..1."""
    g = rng.random((cells_v, cells_u))
    ys = np.linspace(0, cells_v, n, endpoint=False)
    xs = np.linspace(0, cells_u, n, endpoint=False)
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    y1 = (y0 + 1) % cells_v
    x1 = (x0 + 1) % cells_u
    a = g[y0][:, x0]
    b = g[y0][:, x1]
    c = g[y1][:, x0]
    d = g[y1][:, x1]
    return a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy


def _fbm(rng, n, base=4, octaves=4):
    out = np.zeros((n, n))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = base * (2 ** o)
        out += amp * _value_noise(rng, n, c, c)
        tot += amp
        amp *= 0.5
    return out / tot


def _rgb(c):
    return np.array(c, dtype=float)[None, None, :]


def _mix(a, b, t):
    t = t[..., None] if t.ndim == 2 else t
    return a * (1 - t) + b * t


def _grain(seed, base, dark, rings=9.0, knots=True):
    """Wood: grain runs along U (horizontal in the tile), varying in V."""
    n = TILE_PX
    r = _rng(seed)
    warp = _fbm(r, n, 3, 3)
    v = np.linspace(0, 1, n)[:, None] + 0.25 * warp
    stripes = 0.5 + 0.5 * np.sin(v * rings * 2 * math.pi + 3 * _fbm(r, n, 2, 2))
    fine = _fbm(r, n, 16, 2)
    t = np.clip(0.55 * stripes ** 3 + 0.35 * fine, 0, 1)
    img = _mix(_rgb(base), _rgb(dark), t)
    if knots:
        for _ in range(2):
            cx, cy = r.integers(16, n - 16, 2)
            yy, xx = np.mgrid[0:n, 0:n]
            d = np.sqrt(((xx - cx) / 2.2) ** 2 + (yy - cy) ** 2)
            img = _mix(img, _rgb(dark) * 0.75, np.clip(1 - d / 5.0, 0, 1))
    return img


def _planks(seed, base, dark, count=4):
    img = _grain(seed, base, dark, rings=14.0, knots=False)
    n = TILE_PX
    r = _rng(seed + 1)
    for i in range(count):
        tint = 0.85 + 0.3 * r.random()
        y0 = i * n // count
        img[y0:y0 + n // count] *= tint
        img[y0:y0 + 2] *= 0.45  # seam
        for x in r.integers(6, n - 6, 2):  # nail heads
            img[y0 + 5:y0 + 8, x:x + 3] = _rgb((0.16, 0.15, 0.14))
    return img


def _speckle(seed, base, dark, light=None, scale=6, crack=0.0):
    n = TILE_PX
    r = _rng(seed)
    t = _fbm(r, n, scale, 4)
    img = _mix(_rgb(base), _rgb(dark), np.clip((t - 0.3) * 1.8, 0, 1))
    if light is not None:
        s = _fbm(r, n, 24, 2)
        img = _mix(img, _rgb(light), np.clip((s - 0.62) * 4, 0, 1))
    if crack > 0:
        c = np.abs(_value_noise(r, n, 5, 5) - 0.5)
        img = _mix(img, _rgb(dark) * 0.6, np.clip(1 - c / (0.03 * crack), 0, 1) * 0.8)
    return img


def _cobble(seed, base, dark):
    """Stones with dark mortar: nearest-point cells."""
    n = TILE_PX
    r = _rng(seed)
    pts = r.random((22, 2)) * n
    yy, xx = np.mgrid[0:n, 0:n]
    d = np.full((n, n), 1e9)
    d2 = np.full((n, n), 1e9)
    idx = np.zeros((n, n), dtype=int)
    for i, (px, py) in enumerate(pts):
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                dd = np.sqrt((xx - px - ox) ** 2 + (yy - py - oy) ** 2)
                closer = dd < d
                d2 = np.where(closer, d, np.minimum(d2, dd))
                idx = np.where(closer, i, idx)
                d = np.where(closer, dd, d)
    edge = np.clip((d2 - d) / 4.0, 0, 1)
    shade = 0.8 + 0.35 * r.random(len(pts))[idx]
    img = _speckle(seed + 3, base, dark, scale=10) * shade[..., None]
    return _mix(_rgb(dark) * 0.45, img, edge)


def _weave(seed, base, dark, cell=10):
    n = TILE_PX
    yy, xx = np.mgrid[0:n, 0:n]
    cu = (xx // cell) % 2
    cv = (yy // cell) % 2
    over = (cu ^ cv).astype(float)
    fu = (xx % cell) / cell
    fv = (yy % cell) / cell
    bulge = np.where(over > 0, np.sin(fv * math.pi), np.sin(fu * math.pi))
    t = 0.65 * (1 - bulge) + 0.2 * _fbm(_rng(seed), n, 12, 2)
    return _mix(_rgb(base), _rgb(dark), np.clip(t, 0, 1))


def _stripes(seed, base, dark, freq=10, angle=0.0, sharp=2.0, noise=0.3):
    n = TILE_PX
    yy, xx = np.mgrid[0:n, 0:n] / n
    p = xx * math.sin(angle) + yy * math.cos(angle)
    s = 0.5 + 0.5 * np.sin(p * freq * 2 * math.pi)
    t = np.clip(s ** sharp + noise * _fbm(_rng(seed), n, 8, 3) - noise * 0.5, 0, 1)
    return _mix(_rgb(base), _rgb(dark), t)


def _meat(seed, base, dark, fat, fat_amt):
    """Muscle fibre streaks along U with fat marbling."""
    img = _stripes(seed, base, dark, freq=18, angle=math.pi / 2 * 0 + 0.0, sharp=1.5, noise=0.5)
    n = TILE_PX
    r = _rng(seed + 9)
    m = _fbm(r, n, 5, 3)
    streak = np.clip((m - (1 - fat_amt)) * 6, 0, 1)
    return _mix(img, _rgb(fat), streak)


def _wheel():
    """Cart wheel seen face on: planked disc, iron rim, hub with bolts."""
    n = TILE_PX
    yy, xx = np.mgrid[0:n, 0:n] + 0.5
    c = n / 2
    d = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c
    img = _planks(71, (0.55, 0.38, 0.22), (0.33, 0.22, 0.12), count=5)
    ang = np.arctan2(yy - c, xx - c)
    spokes = np.clip(1 - np.abs(np.sin(ang * 3)) * 8 * d, 0, 1) * (d < 0.85)
    img = _mix(img, _rgb((0.42, 0.28, 0.16)), spokes * 0.7)
    img = _mix(img, _rgb((0.2, 0.2, 0.22)), ((d > 0.84) & (d < 1.01)).astype(float))
    img = _mix(img, _rgb((0.24, 0.17, 0.11)), (d < 0.24).astype(float))
    img = _mix(img, _rgb((0.18, 0.18, 0.2)), ((d > 0.22) & (d < 0.27)).astype(float))
    for k in range(6):
        a = k * math.pi / 3
        bx, by = c + math.cos(a) * c * 0.92, c + math.sin(a) * c * 0.92
        bolt = np.sqrt((xx - bx) ** 2 + (yy - by) ** 2) < 2.6
        img = _mix(img, _rgb((0.45, 0.45, 0.47)), bolt.astype(float))
    return img


def _log_end():
    n = TILE_PX
    yy, xx = np.mgrid[0:n, 0:n] + 0.5
    c = n / 2
    d = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c
    w = _fbm(_rng(55), n, 4, 3)
    rings = 0.5 + 0.5 * np.sin((d + 0.05 * w) * 9 * 2 * math.pi)
    img = _mix(_rgb((0.78, 0.6, 0.38)), _rgb((0.55, 0.38, 0.22)), rings ** 2)
    return _mix(img, _rgb((0.3, 0.2, 0.12)), (d > 0.88).astype(float))


def _sign_board():
    img = _planks(81, (0.56, 0.4, 0.24), (0.36, 0.24, 0.13), count=2)
    n = TILE_PX
    r = _rng(82)
    for row in (0.32, 0.62):  # carved glyph strokes, unreadable on purpose
        y = int(row * n)
        x = 16
        while x < n - 20:
            w = int(r.integers(6, 14))
            img[y:y + 9, x:x + w] *= 0.35
            x += w + int(r.integers(4, 9))
    return img


def _ember():
    img = _speckle(91, (0.12, 0.1, 0.09), (0.05, 0.04, 0.04), scale=8)
    n = TILE_PX
    glow = _fbm(_rng(92), n, 6, 3)
    hot = np.clip((glow - 0.5) * 4, 0, 1)
    img = _mix(img, _rgb((0.95, 0.42, 0.08)), hot)
    return _mix(img, _rgb((1.0, 0.78, 0.3)), np.clip((glow - 0.68) * 6, 0, 1))


def _water():
    n = TILE_PX
    t = _fbm(_rng(101), n, 4, 4)
    img = _mix(_rgb((0.1, 0.24, 0.28)), _rgb((0.2, 0.38, 0.42)), t)
    return _mix(img, _rgb((0.55, 0.7, 0.72)), np.clip((_fbm(_rng(102), n, 12, 2) - 0.72) * 5, 0, 1))


def paint_atlas():
    p = {
        "wood": _grain(1, (0.58, 0.45, 0.31), (0.38, 0.28, 0.17)),
        "wood_dark": _grain(2, (0.42, 0.29, 0.17), (0.25, 0.16, 0.09)),
        "plank": _planks(3, (0.56, 0.44, 0.3), (0.37, 0.27, 0.17)),
        "bark": _stripes(4, (0.36, 0.27, 0.18), (0.18, 0.13, 0.08), freq=14, sharp=3, noise=0.6),
        "log_end": _log_end(),
        "char": _speckle(6, (0.13, 0.11, 0.1), (0.05, 0.04, 0.04), light=(0.3, 0.28, 0.26), crack=1),
        "wheel": _wheel(),
        "weathered": _grain(8, (0.55, 0.49, 0.41), (0.36, 0.31, 0.26), rings=12),
        "canvas": _mix(_weave(9, (0.72, 0.65, 0.51), (0.6, 0.53, 0.4), cell=3),
                       _rgb((0.55, 0.47, 0.35)), np.clip(_fbm(_rng(10), TILE_PX, 3, 3) - 0.45, 0, 1)),
        "hide": _speckle(11, (0.62, 0.45, 0.31), (0.45, 0.31, 0.2), light=(0.72, 0.56, 0.4), scale=5),
        "rope": _stripes(12, (0.74, 0.62, 0.42), (0.45, 0.36, 0.22), freq=12, angle=0.7, sharp=2, noise=0.2),
        "thatch": _stripes(13, (0.66, 0.55, 0.33), (0.42, 0.32, 0.17), freq=30, angle=0.03, sharp=3, noise=0.6),
        "weave": _weave(14, (0.72, 0.58, 0.36), (0.42, 0.31, 0.17), cell=9),
        "steamer_weave": _weave(15, (0.78, 0.7, 0.46), (0.52, 0.45, 0.26), cell=5),
        "leather_dark": _speckle(16, (0.36, 0.24, 0.15), (0.22, 0.14, 0.08), scale=6),
        "fiber": _stripes(17, (0.62, 0.6, 0.38), (0.42, 0.4, 0.22), freq=24, angle=0.2, noise=0.5),
        "stone": _speckle(18, (0.56, 0.56, 0.54), (0.38, 0.38, 0.38), light=(0.68, 0.67, 0.64), crack=1),
        "stone_dark": _speckle(19, (0.38, 0.38, 0.39), (0.22, 0.22, 0.23), light=(0.48, 0.48, 0.48), crack=1),
        "cobble": _cobble(20, (0.56, 0.55, 0.52), (0.36, 0.35, 0.33)),
        "clay": _speckle(21, (0.7, 0.42, 0.26), (0.55, 0.3, 0.18), light=(0.78, 0.52, 0.34), scale=5),
        "clay_dark": _speckle(22, (0.42, 0.25, 0.16), (0.2, 0.13, 0.09), scale=5),
        "iron": _speckle(23, (0.27, 0.27, 0.29), (0.16, 0.16, 0.17), light=(0.42, 0.33, 0.25), scale=7),
        "ash": _speckle(24, (0.48, 0.46, 0.43), (0.28, 0.27, 0.26), light=(0.62, 0.6, 0.57), scale=9),
        "ember": _ember(),
        # Drying-rack stages separate by value as well as hue (tile-mean Rec.709 luma, checked by
        # t_structart): wet bright red ~65 -> deep maroon ~33 -> near-black brown ~20 with pale
        # salt/fat edges so the finished strips do not vanish against the dark dirt disc.
        "meat_raw": _meat(25, (0.86, 0.17, 0.15), (0.62, 0.08, 0.08), (0.95, 0.74, 0.68), 0.2),
        "meat_drying": _meat(26, (0.46, 0.08, 0.065), (0.3, 0.045, 0.04), (0.56, 0.24, 0.18), 0.16),
        "meat_dried": _meat(27, (0.18, 0.085, 0.05), (0.09, 0.04, 0.025), (0.62, 0.46, 0.32), 0.14),
        "meat_fat": _speckle(33, (0.6, 0.38, 0.22), (0.44, 0.26, 0.14), light=(0.72, 0.52, 0.34), scale=6),
        "water": _water(),
        "soot": _speckle(29, (0.17, 0.15, 0.14), (0.08, 0.07, 0.07), scale=5),
        "sign_board": _sign_board(),
        "dirt": _speckle(31, (0.45, 0.34, 0.24), (0.3, 0.22, 0.15), light=(0.55, 0.44, 0.32), scale=8),
        "bone": _speckle(32, (0.88, 0.84, 0.74), (0.7, 0.65, 0.55), scale=6),
    }
    img = np.zeros((ATLAS, ATLAS, 4))
    img[..., 3] = 1.0
    img[..., :3] = 0.5
    for name, tile in p.items():
        i = TILE_INDEX[name]
        cx, cy = i % GRID, i // GRID
        img[cy * TILE_PX:(cy + 1) * TILE_PX, cx * TILE_PX:(cx + 1) * TILE_PX, :3] = np.clip(tile, 0, 1)
    return img


def atlas_image():
    """Paint (deterministic) and save the atlas PNG; return the bpy image."""
    os.makedirs(OUT_DIR, exist_ok=True)
    pix = paint_atlas()
    name = "structures_atlas.png"
    im = bpy.data.images.get(name)
    if im is None:
        im = bpy.data.images.new(name, ATLAS, ATLAS, alpha=False)
    # bpy images are bottom-up.
    im.pixels.foreach_set(np.flipud(pix).astype(np.float32).ravel())
    im.filepath_raw = ATLAS_PATH
    im.file_format = "PNG"
    im.save()
    return im


def atlas_material():
    mat = bpy.data.materials.get(MAT_NAME)
    if mat is not None:
        return mat
    im = atlas_image()
    mat = bpy.data.materials.new(MAT_NAME)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = im
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.88
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


# ---------------------------------------------------------------- mesh building

def _tile_rect(tile):
    i = TILE_INDEX[tile]
    cx, cy = i % GRID, i // GRID
    u0 = cx / GRID
    v_top = 1.0 - cy / GRID  # UV v=1 is the image top
    return u0, v_top - 1.0 / GRID


class Part:
    """One output node: a bmesh that primitives append into, each UV'd into its own tile."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.seed = 1

    # -- UVs
    def _uv_faces(self, faces, tile, tile_m=1.0, fit=False):
        u0, v0 = _tile_rect(tile)
        span = (1.0 - 2 * INSET) / GRID
        rnd = random.Random(zlib.crc32(("%s/%d" % (self.name, self.seed)).encode()))
        self.seed += 1
        for f in faces:
            n = f.normal.normalized() if f.normal.length > 1e-6 else Vector((0, 0, 1))
            edges = [(f.verts[(i + 1) % len(f.verts)].co - f.verts[i].co) for i in range(len(f.verts))]
            ud = max(edges, key=lambda e: e.length).normalized()
            vd = n.cross(ud).normalized()
            pts = [(l.vert.co.dot(ud), l.vert.co.dot(vd)) for l in f.loops]
            mu = min(p[0] for p in pts)
            mv = min(p[1] for p in pts)
            eu = max(p[0] for p in pts) - mu
            ev = max(p[1] for p in pts) - mv
            if fit:
                s = 1.0 / max(eu, ev, 1e-6)
                ou = (1 - eu * s) * 0.5
                ov = (1 - ev * s) * 0.5
            else:
                s = 1.0 / tile_m
                big = max(eu, ev) * s
                if big > 1.0:
                    s /= big
                ou = rnd.random() * max(0.0, 1 - eu * s)
                ov = rnd.random() * max(0.0, 1 - ev * s)
            for l, (pu, pv) in zip(f.loops, pts):
                lu = ou + (pu - mu) * s
                lv = ov + (pv - mv) * s
                l[self.uv].uv = (u0 + INSET / GRID + lu * span, v0 + INSET / GRID + lv * span)

    def _finish(self, verts, tile, smooth=False, tile_m=1.0, cap_tile=None, axis_faces=None):
        faces = list({f for v in verts for f in v.link_faces})
        for f in faces:
            f.smooth = smooth
        if cap_tile and axis_faces is not None:
            caps = [f for f in faces if abs(f.normal.dot(axis_faces)) > 0.9]
            sides = [f for f in faces if f not in caps]
            self._uv_faces(sides, tile, tile_m)
            self._uv_faces(caps, cap_tile, fit=True)
            for f in caps:
                f.smooth = False
                for e in f.edges:
                    e.smooth = False
        else:
            self._uv_faces(faces, tile, tile_m)
        return verts

    # -- primitives (positions in metres, rot in degrees XYZ)
    @staticmethod
    def _mat(loc, rot, scale=(1, 1, 1)):
        r = Matrix.Identity(4)
        if rot:
            from mathutils import Euler
            r = Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
        s = Matrix.Diagonal((*scale, 1))
        return Matrix.Translation(loc) @ r @ s

    def box(self, size, loc, tile, rot=None, tile_m=1.0):
        m = self._mat(loc, rot, size)
        v = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)["verts"]
        self.bm.normal_update()
        return self._finish(v, tile, tile_m=tile_m)

    def cyl(self, r, h, loc, tile, rot=None, seg=8, r2=None, cap_tile=None, smooth=True, tile_m=1.0):
        """Cylinder along local Z, centred on loc."""
        m = self._mat(loc, rot)
        v = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                  radius1=r, radius2=r if r2 is None else r2, depth=h, matrix=m)["verts"]
        self.bm.normal_update()
        axis = (m.to_3x3() @ Vector((0, 0, 1))).normalized()
        return self._finish(v, tile, smooth=smooth, tile_m=tile_m, cap_tile=cap_tile or tile, axis_faces=axis)

    def log(self, a, b, r, tile="bark", seg=7, end_tile="log_end"):
        """Cylinder from point a to point b."""
        a, b = Vector(a), Vector(b)
        d = b - a
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        m = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
        v = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                  radius1=r, radius2=r, depth=d.length, matrix=m)["verts"]
        self.bm.normal_update()
        return self._finish(v, tile, smooth=True, cap_tile=end_tile, axis_faces=d.normalized())

    def plank(self, a, b, w, t, tile="wood", up=(0, 0, 1)):
        """Rectangular beam from a to b, width w, thickness t (thickness along `up`)."""
        a, b, up = Vector(a), Vector(b), Vector(up)
        x = (b - a).normalized()
        z = (up - x * up.dot(x)).normalized()
        y = z.cross(x)
        rot = Matrix((x, y, z)).transposed().to_4x4()
        m = Matrix.Translation((a + b) / 2) @ rot @ Matrix.Diagonal(((b - a).length, w, t, 1))
        v = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)["verts"]
        self.bm.normal_update()
        return self._finish(v, tile)

    def rock(self, r, loc, tile="stone", squash=(1, 1, 0.7), seed=0, sub=1):
        rng = random.Random(seed)
        m = self._mat(loc, (0, 0, rng.uniform(0, 360)), (r * squash[0], r * squash[1], r * squash[2]))
        v = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=1.0, matrix=m)["verts"]
        c = Vector(loc)
        for vv in v:
            vv.co = c + (vv.co - c) * rng.uniform(0.82, 1.12)
        self.bm.normal_update()
        return self._finish(v, tile, tile_m=0.6)

    def prism(self, pts, offset, tile, tile_m=1.0):
        """Extrude a flat convex polygon (list of xyz, any winding) by the vector `offset`."""
        off = Vector(offset)
        front = [self.bm.verts.new(p) for p in pts]
        back = [self.bm.verts.new(Vector(p) + off) for p in pts]
        n = len(pts)
        self.bm.faces.new(front)
        self.bm.faces.new(list(reversed(back)))
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((front[i], back[i], back[j], front[j]))
        faces = list({f for v in front for f in v.link_faces})
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        self.bm.normal_update()
        return self._finish(front + back, tile, tile_m=tile_m)

    def to_object(self, coll, origin=(0, 0, 0)):
        me = bpy.data.meshes.new(self.name)
        bmesh.ops.translate(self.bm, verts=self.bm.verts, vec=-Vector(origin))
        self.bm.to_mesh(me)
        self.bm.free()
        me.materials.append(atlas_material())
        ob = bpy.data.objects.new(self.name, me)
        ob.location = origin
        coll.objects.link(ob)
        return ob


# ---------------------------------------------------------------- scene + export

def new_scene(name):
    """Empty the current scene of a headless (-b --factory-startup) Blender and return it.

    Building is headless-only: switching the live window to a temporary scene and exporting it
    segfaulted the user's Blender 5.2 in the depsgraph (2026-10-19), so live sessions only
    import the finished GLBs for a look.
    """
    if not bpy.app.background:
        raise RuntimeError("structart builds run headless: Blender -b --factory-startup -P build.py")
    scn = bpy.context.scene
    clear_scene(scn)
    return scn


def clear_scene(scn):
    for ob in list(scn.objects):
        data = ob.data
        bpy.data.objects.remove(ob)
        if data is not None and data.users == 0 and isinstance(data, bpy.types.Mesh):
            bpy.data.meshes.remove(data)


def tri_count(objs):
    t = 0
    for ob in objs:
        if ob.type == "MESH":
            for p in ob.data.polygons:
                t += len(p.vertices) - 2
    return t


def export(scn, objs, name):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".glb")
    for ob in scn.objects:
        ob.select_set(ob in objs)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_image_format="JPEG", export_jpeg_quality=88,
        export_animations=False, export_cameras=False, export_lights=False,
        export_extras=False)
    print("[structart] wrote %s tris=%d" % (path, tri_count(objs)))
    return path
