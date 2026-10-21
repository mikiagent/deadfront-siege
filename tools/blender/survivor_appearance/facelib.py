# P4 face helpers: the head's texels with their bind-pose positions, the skin fill that removes painted hair from
# the face, and the builders for face pieces. Every piece is made of the head's own triangles, so it carries the
# head's joints and weights vertex for vertex and moves with the skin in every clip:
#   overlay  - opaque, offset 0.4 mm, on the head's own atlas UVs (a repainted copy of the atlas: clean jaw, no
#              brows). Its texture name keeps the atlas id, so CHARCREATE's look masks tint it like the head.
#   decal    - alpha-blended, offset 0.8 mm, its own UVs and a 512 texture baked from 3D (shade in RGB, coverage
#              in A). Hair decals ("*_hairtint") take the hair colour as the material colour, so a hair-colour
#              choice is one albedo_color.
import bpy, os
import numpy as np
from mathutils import Vector
import glb
from paintlib import load_atlas, save_atlas, raster, vnoise, smooth_field, smoothstep, dilate_into, weld, scalp_field

LUM = np.array([0.2126, 0.7152, 0.0722])
ATLAS_ID = "82d5db79-577f-4f8f-b6bf-930a520b5272"
# Landmarks in glTF bind space (y up, the face looks down +z, +x is the man's left), read from head.glb's texels
# with a height grid painted on renders (scratch probes, see the report).
EYE_X, EYE_Y = 0.0305, 1.6430      # iris centres
BROW_LOW, BROW_HIGH = 1.6465, 1.6630
LIP_TOP_C, LIP_BOTTOM, MOUTH_HALF = 1.5855, 1.5655, 0.0305   # upper lip top at the centre
NOSE_BASE = 1.6010
CHIN_Y, CHIN_UNDER_Y = 1.5466, 1.5150
OVERLAY_OFFSET, DECAL_OFFSET, FEATURE_OFFSET = 0.0004, 0.0008, 0.0010   # features sit over brow decals
DECAL_TEX = 512


class Head:
    def __init__(self, hair_dir):
        self.js, self.bn = glb.read(f"{hair_dir}/head.glb")
        self.A = glb.mesh_arrays(self.js, self.bn)
        rjs, rbn = glb.read(f"{hair_dir}/hair_current.glb")
        self.tris = self.A["indices"].reshape(-1, 3)
        self.wid, self.wpos, self.wn, self.field, self.wtris = scalp_field(self.A, glb.mesh_arrays(rjs, rbn))
        self.atlas_path = os.path.join(hair_dir, self.js["images"][1]["uri"])
        self.atlas = load_atlas(self.atlas_path)
        AH, AW = self.atlas.shape[:2]
        self.T = raster(self.A["TEXCOORD_0"], self.tris, AW, AH)
        b, t = self.T["bary"], self.T["tri"]
        self.P = np.einsum("nk,nkj->nj", b, self.A["POSITION"][self.tris[t]])
        self.C = self.atlas[self.T["row"], self.T["col"], :3]
        self.N = np.einsum("nk,nkj->nj", b, self.wn[self.wtris[t]])
        self.N /= np.linalg.norm(self.N, axis=1, keepdims=True)
        nw = len(self.wpos)
        self.near = self.wid[self.tris[t, np.argmax(b, 1)]]
        self.vcol = np.zeros((nw, 3)); np.add.at(self.vcol, self.near, self.C)
        self.vcnt = np.bincount(self.near, minlength=nw).astype(float)
        self.vcol /= np.maximum(self.vcnt, 1)[:, None]
        e = np.concatenate([self.wtris[:, [0, 1]], self.wtris[:, [1, 2]], self.wtris[:, [2, 0]]])
        self.edges = np.unique(np.sort(e, 1), axis=0)
        self.deg = np.bincount(self.edges.ravel(), minlength=nw).astype(float)

    def at_texels(self, v):
        """A per-welded-vertex field at every head texel (barycentric)."""
        return np.einsum("nk,nk->n", self.T["bary"], v[self.wtris[self.T["tri"]]])

    def harmonic(self, fixed, iters=900):
        """Vertex colours relaxed to the mean of their neighbours, `fixed` vertices held at their painted colour."""
        c = np.where(fixed[:, None], self.vcol, np.median(self.vcol[fixed], 0))
        e = self.edges
        for _ in range(iters):
            s = np.zeros_like(c); np.add.at(s, e[:, 0], c[e[:, 1]]); np.add.at(s, e[:, 1], c[e[:, 0]])
            c = np.where(fixed[:, None], self.vcol, s / np.maximum(self.deg, 1)[:, None])
        return c

    @staticmethod
    def lips(p):
        """Lips, measured per column from the paint: the lower lip's red, the mouth line, the upper lip under the
        stubble (lighter than it), and the mouth corners. 0..1, soft over about a millimetre."""
        ax, y = np.abs(p[:, 0]), p[:, 1]
        top = LIP_TOP_C - 0.0095 * np.minimum(ax / 0.027, 1.2) ** 0.8
        bot = LIP_BOTTOM + 0.006 * np.minimum(ax / 0.03, 1.2) ** 2
        band = smoothstep(0.0001, 0.0011, np.minimum(y - bot, top - y)) * (1 - smoothstep(0.028, 0.0315, ax))
        corner = 1 - smoothstep(0.5, 1.0, ((ax - MOUTH_HALF + 0.001) / 0.0025) ** 2 + ((y - 1.5735) / 0.0015) ** 2)
        return np.maximum(band, corner) * (p[:, 2] > 0.03)


def remove_paint(head, prior, dark_lo=0.02, dark_hi=0.10, keep=None):
    """Skin where the painted face is darker or greyer than the skin around it, inside `prior` (welded 0..1).
    The skin around is a harmonic fill from the lit skin outside the prior; the new colour is the cheeks' skin
    colour at the fill's local tone (84-115 % of the cheeks, a little less under the jaw), so stubble that fed the
    fill cannot leave it grey. Returns (weight per welded vertex, colour per welded vertex)."""
    vl = head.vcol @ LUM
    sat = (head.vcol.max(1) - head.vcol.min(1)) / np.maximum(head.vcol.max(1), 1e-3)
    keep = np.zeros(len(vl), bool) if keep is None else keep   # never a fill source (lips); the caller masks them per texel
    # Skin reference: the lit front of the face (cheeks, forehead). Shaded skin (the nose's underside) is no fill
    # source, or the upper lip would keep its stubble as "skin".
    y = head.wpos[:, 1]
    cheeks = (prior < 0.05) & (head.vcnt > 0) & (head.field < 0.05) & (head.wn[:, 2] > 0.5) & (y > 1.60) & (y < 1.72)
    skin_ref = np.median(vl[cheeks])
    light = (head.vcnt > 0) & (vl > 0.86 * skin_ref) & ~keep
    skin_col = np.median(head.vcol[cheeks & light], 0)
    fill = head.harmonic((prior < 0.05) & light & (head.field < 0.05))
    fl = fill @ LUM
    fs = (fill.max(1) - fill.min(1)) / np.maximum(fill.max(1), 1e-3)
    score = np.maximum(smoothstep(dark_lo, dark_hi, fl - vl), smoothstep(0.03, 0.12, fs - sat) * smoothstep(0.0, 0.04, fl - vl))
    tone = np.clip(fl / skin_ref, 0.84, 1.15) * (1 - 0.10 * np.maximum(0, -head.wn[:, 1]))
    w = np.clip(smooth_field(prior * score, head.wtris, 2) * 1.6, 0, 1) * prior
    return w, skin_col[None, :] * tone[:, None]


def tangent_flow(p, n, down):
    """Unit flow along the surface: `down` (per point) projected onto the tangent plane."""
    f = down - n * (down * n).sum(1, keepdims=True)
    return f / (np.linalg.norm(f, axis=1, keepdims=True) + 1e-9)


def strands(p, n, flow, seed, scale=1.0, k=7.0):
    """Hair grain: noise stretched k times along `flow` (0..1, about 0.5 mean)."""
    q = p - flow * (flow * p).sum(1, keepdims=True) * (1 - 1 / k)
    return 0.55 * vnoise(q, 900.0 / scale, seed) + 0.3 * vnoise(q, 330.0 / scale, seed + 1) + 0.15 * vnoise(p, 80.0, seed + 2)


def unwrap(verts, faces):
    """Smart UV Project in Blender; returns (vertex ids, glTF UVs, triangle indices into them) per unique corner."""
    me = bpy.data.meshes.new("piece")
    me.from_pydata([tuple(map(float, (p[0], -p[2], p[1]))) for p in verts], [], [tuple(map(int, f)) for f in faces])
    me.update()
    ob = bpy.data.objects.new("piece", me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.008, area_weight=0.0, correct_aspect=True, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    luv = np.array([d.uv[:] for d in me.uv_layers.active.data])
    lv = np.array([l.vertex_index for l in me.loops])
    loops = np.array([[p.loop_start + k for k in range(3)] for p in me.polygons])
    pairs = np.round(np.concatenate([lv[:, None], luv * 1e6], 1)).astype(np.int64)
    _, first, inv = np.unique(pairs, axis=0, return_index=True, return_inverse=True)
    guv = luv[first].copy(); guv[:, 1] = 1.0 - guv[:, 1]
    bpy.data.objects.remove(ob); bpy.data.meshes.remove(me)
    return lv[first], guv, inv.reshape(-1)[loops]


def head_patch(head, tri_mask, offset):
    """The head triangles in `tri_mask`, pushed out `offset` along the welded normal; the head's own vertex attributes."""
    sub, used = glb.subset(head.A, tri_mask)
    sub["POSITION"] = sub["POSITION"] + head.wn[head.wid[used]] * offset
    return sub, used


def tris_touching(head, texel_cov, thr=0.002, ring=1):
    """Head triangles holding any texel with coverage over `thr`, grown by `ring` rings of welded neighbours."""
    m = np.zeros(len(head.tris), bool)
    m[np.unique(head.T["tri"][texel_cov > thr])] = True
    for _ in range(ring):
        vs = np.zeros(len(head.wpos), bool); vs[head.wtris[m].ravel()] = True
        m |= vs[head.wtris].any(1)
    return m


def decal_part(head, name, tri_mask, shade_alpha, out_dir, tint=None, tex=DECAL_TEX, offset=DECAL_OFFSET):
    """An alpha-blended decal over the head triangles in tri_mask. shade_alpha(P, N, at) -> (rgb (n,3), alpha (n,))
    at texel positions on the head's surface; at(field) gives a per-welded-vertex field at those texels. With `tint`
    (sRGB triple) the material colour is the tint and RGB the shade it multiplies (hair decals); without, RGB is
    the colour."""
    sub, used = head_patch(head, tri_mask, offset)
    t = sub["indices"].reshape(-1, 3)
    gv, guv, gidx = unwrap(sub["POSITION"], t)
    arr = {k: v[gv] for k, v in sub.items() if k != "indices"}
    arr["TEXCOORD_0"] = guv
    arr["indices"] = gidx.reshape(-1)
    gt = gidx.reshape(-1, 3)
    T = raster(guv, gt, tex, tex)
    base = head.A["POSITION"][used][gv]                   # on the head surface, not the offset copy
    P = np.einsum("nk,nkj->nj", T["bary"], base[gt[T["tri"]]])
    N = np.einsum("nk,nkj->nj", T["bary"], head.wn[head.wid[used]][gv][gt[T["tri"]]])
    N /= np.linalg.norm(N, axis=1, keepdims=True)
    ht = np.nonzero(tri_mask)[0][T["tri"]]                # the head triangle under each texel (same corner order)
    rgb, a = shade_alpha(P, N, lambda f: np.einsum("nk,nk->n", T["bary"], f[head.wtris[ht]]))
    rgb = np.where(a[:, None] > 0.003, rgb, 0.8)          # flat where nothing shows: the PNG compresses
    img = np.zeros((tex, tex, 4), np.float32)
    img[T["row"], T["col"], :3] = rgb
    img[T["row"], T["col"], 3] = a
    done = np.zeros((tex, tex), bool); done[T["row"], T["col"]] = True
    alpha = np.repeat(img[..., 3:], 3, 2); d2 = done.copy()
    dilate_into(img, done, np.zeros_like(done), 8)          # RGB and, below, A grown 8 px past the islands
    dilate_into(alpha, d2, np.zeros_like(d2), 8)
    img[..., 3] = alpha[..., 0]
    fn = f"{name}.png"
    save_atlas(img, f"{out_dir}/{fn}", alpha=True)
    mat = {"name": name, "doubleSided": True, "alphaMode": "BLEND",
           "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "baseColorFactor": [*(_lin(tint) if tint else (1, 1, 1)), 1.0],
                                    "metallicFactor": 0.0, "roughnessFactor": 0.85}}
    stats = {"triangles": int(tri_mask.sum()), "texels": int(len(a)), "covered": int((a > 0.05).sum())}
    return {"name": name + ("_hairtint" if tint else ""), "arrays": arr, "material": mat, "images": [{"uri": fn, "name": name}]}, stats


def _lin(c):
    """glTF factors are linear; the tint is given in sRGB."""
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4).tolist()


def overlay_part(head, name, tri_mask, uri):
    """Opaque copy of the head triangles in tri_mask on the head's atlas UVs, showing the repainted atlas `uri`."""
    sub, _ = head_patch(head, tri_mask, OVERLAY_OFFSET)
    mat = {"name": name, "doubleSided": True,
           "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 0.82}}
    return {"name": name, "arrays": sub, "material": mat, "images": [{"uri": uri, "name": "Color"}]}


def seg_dist(p, a, b):
    """Distance from 2D points p (n,2) to segment ab, and the parameter t along it."""
    ab = np.asarray(b, float) - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(p - (np.asarray(a, float) + t[:, None] * ab), axis=1), t


def polyline(p, pts, widths):
    """Coverage-ready distance to a polyline with a width per point: returns (d - halfwidth) (negative inside)."""
    best = np.full(len(p), 1e9)
    for i in range(len(pts) - 1):
        d, t = seg_dist(p, np.asarray(pts[i], float), np.asarray(pts[i + 1], float))
        best = np.minimum(best, d - (widths[i] * (1 - t) + widths[i + 1] * t) / 2)
    return best
