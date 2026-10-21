# P4 face: clean-shaven jaw, facial-hair decals, brow shapes and feature decals. Headless:
#   Blender -b --factory-startup -P face_paint.py -- <hair_dir> <face_dir>
# Reads hair/head.glb, hair_current.glb (split_hair.py) and the survivor's Color atlas. Writes into <face_dir>:
#   face_clean_Color_<atlas id>.jpg  the atlas with the stubble and the brows painted out (only the texels the
#                                    overlays show; the rest is flat). The atlas id stays in the name so
#                                    CHARCREATE's look masks tint it as the head.
#   fh_<id>.glb   facial hair: "shave" overlay (+ a hair decal)   brows_<id>.glb: "browless" overlay + brow decal
#   ft_<id>.glb   feature decals                                    face.json: what each piece holds, the rows
# Beards (beard_shell.py) reuse the shave overlay and the heavy-stubble decal. Every decal is painted from 3D
# positions on the head (the atlas UVs are Tripo's 1125 scattered islands), on its own UVs.
import sys, os, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb
from paintlib import save_atlas, vnoise, smoothstep, dilate_into
import facelib as F

argv = sys.argv[sys.argv.index("--") + 1:]
HD, FD = argv[0], argv[1]
os.makedirs(FD, exist_ok=True)
H = F.Head(HD)
stats = {}

# --- clean shave -----------------------------------------------------------------------------------------------
# Where the jaw can carry stubble: below the cheekbones, the front half of the head and neck, clear of the scalp
# hair and sideburns (P2's scalp field), the nose and the ears. The paint itself then says where stubble is.
def beard_prior(p, field):
    x, y, z = p.T
    ax = np.abs(x)
    return ((1 - F.smoothstep(1.618, 1.634, y)) * F.smoothstep(1.468, 1.49, y) * F.smoothstep(-0.035, 0.0, z)
            * (1 - F.smoothstep(0.2, 0.6, field)) * (1 - F.smoothstep(0.072, 0.080, ax))
            * (1 - (1 - F.smoothstep(0.022, 0.028, ax)) * F.smoothstep(F.NOSE_BASE - 0.003, F.NOSE_BASE, y) * (z > 0.1)))


# Brows: the band over each eye on the front of the face; the lids and lashes under it stay.
def brow_prior(p, field):
    x, y, z = p.T
    ax = np.abs(x)
    return (F.smoothstep(F.BROW_LOW - 0.0012, F.BROW_LOW + 0.0005, y) * (1 - F.smoothstep(F.BROW_HIGH - 0.004, F.BROW_HIGH + 0.006, y))
            * F.smoothstep(0.003, 0.007, ax) * (1 - F.smoothstep(0.062, 0.068, ax)) * F.smoothstep(0.035, 0.05, z)
            * (1 - F.smoothstep(0.2, 0.6, field)))


lips_v = H.lips(H.wpos) > 0.5
w_shave, fill_shave = F.remove_paint(H, beard_prior(H.wpos, H.field), keep=lips_v)
w_brow, fill_brow = F.remove_paint(H, brow_prior(H.wpos, H.field), dark_lo=0.03, dark_hi=0.14)
# The beard field: where this man's stubble grows (the shave weight, soft). The decals and shells follow it.
beard = F.smooth_field(w_shave, H.wtris, 2)

P = H.P
field_t = H.at_texels(H.field)
# The mesh is coarse (a lip-to-nose triangle spans the whole upper lip), so the weight is finished per texel: the
# vertex weight, or any texel darker than the skin fill where the vertex weight says stubble is near, times the
# prior and the lips at the texel's own position.
def sat(c):
    return (c.max(1) - c.min(1)) / np.maximum(c.max(1), 1e-3)


def weight(w, fill, prior_t, near_lo, near_hi):
    vw = H.at_texels(w)
    near = F.smoothstep(near_lo, near_hi, H.at_texels(F.smooth_field(w, H.wtris, 2)))
    ft = np.einsum("nk,nkj->nj", H.T["bary"], fill[H.wtris[H.T["tri"]]])
    dark = np.maximum(F.smoothstep(0.015, 0.07, ft @ F.LUM - H.C @ F.LUM), F.smoothstep(0.02, 0.06, sat(ft) - sat(H.C)))  # darker or greyer
    return np.clip(np.maximum(vw * 1.3, dark * near), 0, 1) * prior_t, ft


wt_s, fill_s = weight(w_shave, fill_shave, beard_prior(P, field_t) * (1 - H.lips(P)), 0.05, 0.3)
wt_b, fill_b = weight(w_brow, fill_brow, brow_prior(P, field_t), 0.3, 0.7)
fill_t = np.where((wt_b > wt_s)[:, None], fill_b, fill_s)
mottle = 1.0 + 0.035 * (vnoise(P, 24.0, 31) - 0.5) * 2 + 0.02 * (vnoise(P, 90.0, 32) - 0.5) * 2 + 0.012 * (vnoise(P, 400.0, 33) - 0.5) * 2
wt = np.maximum(wt_s, wt_b)
clean = H.C * (1 - wt[:, None]) + fill_t * mottle[:, None] * wt[:, None]
# The stubble also greyed the upper lip: inside the lips, grey texels take the lower lip's colour at
# their own brightness (the mouth line stays dark).
lip_t = H.lips(P)
lipc = np.median(H.C[(lip_t > 0.9) & (P[:, 1] < 1.5725) & (H.C @ F.LUM > 0.5)], 0)
rg = lambda c: c[..., 0] / np.maximum(c[..., 1], 1e-3)  # lips are redder than skin; the stubble greyed them
wl = F.smoothstep(0.0, 0.5, lip_t) * F.smoothstep(0.04, 0.12, rg(lipc) - rg(H.C)) * (P[:, 1] > 1.5745)
recol = lipc[None] * np.clip((H.C @ F.LUM) / (lipc @ F.LUM), 0.55, 1.05)[:, None]
clean = clean * (1 - wl[:, None]) + recol * wl[:, None]
wt = np.maximum(wt, wl)
stats["shave"] = {"vertices": int((w_shave > 0.5).sum()), "texels": int((np.maximum(wt_s, wl) > 0.02).sum()), "upper_lip_texels": int((wl > 0.02).sum())}
stats["browless"] = {"vertices": int((w_brow > 0.5).sum()), "texels": int((wt_b > 0.02).sum())}

shave_tris = F.tris_touching(H, np.maximum(wt_s, wl), 0.002, 1)
brow_tris = F.tris_touching(H, wt_b, 0.002, 1) & ~shave_tris
CLEAN = f"face_clean_Color_{F.ATLAS_ID}.jpg"
# Only the overlay triangles' texels matter; the rest of the atlas is flat skin, grown 8 px into from the islands.
AH, AW = H.atlas.shape[:2]
img = np.ones((AH, AW, 4), np.float32)
img[..., :3] = np.median(H.C[wt > 0.5], 0)
show = shave_tris[H.T["tri"]] | brow_tris[H.T["tri"]]
img[H.T["row"][show], H.T["col"][show], :3] = clean[show]
done = np.zeros((AH, AW), bool); done[H.T["row"][show], H.T["col"][show]] = True
dilate_into(img, done, np.zeros_like(done), 8)
save_atlas(img, f"{FD}/{CLEAN}")
if os.environ.get("FACE_DEBUG"):  # the whole atlas with the face repaint, for inspection renders
    dbg = H.atlas.copy(); dbg[H.T["row"], H.T["col"], :3] = clean
    save_atlas(dbg, os.environ["FACE_DEBUG"])
shave = F.overlay_part(H, "shave", shave_tris, CLEAN)
browless = F.overlay_part(H, "browless", brow_tris, CLEAN)
stats["shave"]["triangles"], stats["browless"]["triangles"] = int(shave_tris.sum()), int(brow_tris.sum())

# --- decals ----------------------------------------------------------------------------------------------------
# Each design maps texel positions on the head (P, normals N, `at` for per-vertex fields) to (shade or colour,
# coverage). Front-of-face shapes are drawn in the front projection (x, y); the beard ones follow `beard`.
def soft(d, s=0.0006):
    return F.smoothstep(s, -s, d)                    # 1 inside a signed distance, soft over 2 s


def grain(P, N, flow, seed, k=7.0, scale=1.0, lo=0.35, hi=0.75):
    return F.smoothstep(lo, hi, F.strands(P, N, flow, seed, scale, k))


def down_flow(P, N, out=0.35):
    """Beard growth: down the face, a little outward from the middle."""
    d = np.stack([np.sign(P[:, 0]) * out, -np.ones(len(P)), np.zeros(len(P))], 1)
    return F.tangent_flow(P, N, d)


def lip_top(ax):
    return F.LIP_TOP_C - 0.0095 * np.minimum(ax / 0.027, 1.2) ** 0.8


def hairy(P, N, density, flow, seed, k=8.0, fringe=0.9, scale=1.0):
    """Hair from a soft density: strands everywhere, but where the density thins only the strongest strands are
    left, so edges fray into hairs instead of ending in a line. Returns (shade, coverage)."""
    st = F.smoothstep(0.3, 0.7, F.strands(P, N, flow, seed, scale, k))      # sharpened: strands and gaps
    a = np.clip(density * 1.5 - (1 - st) * fringe, 0, 0.94)
    return np.repeat(0.55 + 0.45 * st, 3).reshape(-1, 3), a        # sRGB shade: the strands' mean is near the tint


def heavy_stubble(P, N, at):
    dens = np.clip(at(beard) * 1.3, 0, 1) * (1 - H.lips(P))
    sh, a = hairy(P, N, dens * 0.78, down_flow(P, N), 41, k=3.5, fringe=0.8, scale=0.7)
    return sh * np.array([0.55, 0.6, 0.68]), a           # stubble in the skin reads cooler and darker than the hair


def moustache(P, N, at):
    ax, y = np.abs(P[:, 0]), P[:, 1]
    top = F.NOSE_BASE - 0.0012 - 0.009 * F.smoothstep(0.004, 0.032, ax)       # a chevron under the nose
    bot = lip_top(ax) - 0.0006 - 0.0025 * F.smoothstep(0.024, 0.033, ax)       # just over the lip, ends dip past it
    d = np.maximum.reduce([y - top, bot - y, ax - 0.0335])
    dens = F.smoothstep(0.0022, -0.0016, d) * (P[:, 2] > 0.06) * (1 - 0.85 * H.lips(P) * (y < bot))
    return hairy(P, N, dens, down_flow(P, N, out=0.9), 43, k=11.0, fringe=1.1)


def goatee(P, N, at):
    """Soul patch and chin beard, drawn in (x, s): s is the arc length around the chin (a horizontal axis 3 cm
    inside it), so the shape runs on from the front of the chin to underneath it without a seam."""
    ax = np.abs(P[:, 0])
    s_ = 0.03 * np.arctan2(P[:, 1] - 1.535, P[:, 2] - 0.085)
    half = 0.0032 + 0.0145 * F.smoothstep(0.0235, 0.0165, s_)              # narrow under the lip, full on the chin
    d = np.maximum.reduce([ax - half, s_ - 0.0262, -0.034 - s_])
    d = np.where(s_ < -0.024, np.hypot(np.maximum(ax - half + 0.006, 0), -0.024 - s_) - 0.01 + np.minimum(0, ax - half), d)
    dens = F.smoothstep(0.0024, -0.0016, d) * (P[:, 2] > 0.05) * (1 - H.lips(P))
    return hairy(P, N, dens, down_flow(P, N, out=0.12), 47, k=11.0, fringe=1.1)


BROWS = {  # centre line from the inner end outward (x, y on the man's left; mirrored) and full width there
    "straight": ([(0.010, 1.6512), (0.025, 1.6532), (0.040, 1.6542), (0.055, 1.6518)], [0.0060, 0.0058, 0.0048, 0.0022]),
    "arched": ([(0.011, 1.6505), (0.026, 1.6558), (0.040, 1.6585), (0.053, 1.6545)], [0.0036, 0.0033, 0.0028, 0.0012]),
    "bushy": ([(0.008, 1.6498), (0.022, 1.6528), (0.038, 1.6543), (0.056, 1.6502)], [0.0078, 0.0082, 0.0070, 0.0030]),
}


def brow(kind):
    pts, wd = BROWS[kind]

    def f(P, N, at):
        ax = np.abs(P[:, 0])
        d = F.polyline(np.stack([ax, P[:, 1]], 1), pts, wd)
        flow = F.tangent_flow(P, N, np.stack([np.sign(P[:, 0]), 0.35 - 0.6 * F.smoothstep(0.01, 0.05, ax), np.zeros(len(P))], 1))
        dens = F.smoothstep(0.0012, -0.0010, d) * (P[:, 2] > 0.04) * (N[:, 2] > 0.0)
        sh, a = hairy(P, N, dens, flow, 51, k=6.0, fringe=1.3 if kind == "bushy" else 1.1)
        return sh, a * 0.9
    return f


SCAR_IN, SCAR_RIM = np.array([0.86, 0.68, 0.62]), np.array([0.62, 0.40, 0.36])


def scar(pts, widths):
    def f(P, N, at):
        d = F.polyline(np.stack([P[:, 0], P[:, 1]], 1), pts, widths)
        core, rim = soft(d + 0.0003, 0.0003), soft(d - 0.0004, 0.0005)
        col = SCAR_IN[None] * core[:, None] + SCAR_RIM[None] * (1 - core[:, None])
        tex = 0.9 + 0.1 * F.vnoise(P, 900.0, 61)
        return col * tex[:, None], np.maximum(core * 0.85, rim * 0.45) * (P[:, 2] > 0.04)
    return f


def freckles(P, N, at):
    x, y = P[:, 0], P[:, 1]
    region = (1 - F.smoothstep(0.6, 1.0, (x / 0.062) ** 2 + ((y - 1.624) / 0.019) ** 2)) * (P[:, 2] > 0.05) * (1 - H.lips(P))
    n = F.vnoise(P, 800.0, 71) * 0.7 + F.vnoise(P, 1900.0, 72) * 0.3
    dots = F.smoothstep(0.64, 0.71, n)
    col = np.array([0.52, 0.30, 0.19]) * (0.9 + 0.2 * F.vnoise(P, 300.0, 73))[:, None]
    return col, dots * region * 0.45


def face_paint(P, N, at):
    p2 = np.stack([np.abs(P[:, 0]), P[:, 1]], 1)
    d = np.minimum(F.polyline(p2, [(0.017, 1.6315), (0.040, 1.6300), (0.062, 1.6330)], [0.0058, 0.0062, 0.0040]),
                   F.polyline(p2, [(0.022, 1.6185), (0.042, 1.6180), (0.060, 1.6215)], [0.0036, 0.0040, 0.0024]))
    brush = 0.75 + 0.25 * F.smoothstep(0.3, 0.6, F.strands(P, N, F.tangent_flow(P, N, np.tile([1.0, 0, 0], (len(P), 1))), 81, k=12.0))
    col = np.array([0.11, 0.10, 0.095]) * np.ones((len(P), 1))
    return col, soft(d + 0.0004 * (F.vnoise(P, 400.0, 82) - 0.5), 0.0006) * brush * (P[:, 2] > 0.03) * (N[:, 2] > 0.0)


def age_lines(P, N, at):
    p2 = np.stack([np.abs(P[:, 0]), P[:, 1]], 1)
    lines = [([(0.0, 1.6905), (0.022, 1.6915), (0.042, 1.6950)], 0.0008),        # forehead
             ([(0.0, 1.7020), (0.024, 1.7030), (0.044, 1.7065)], 0.0007),
             ([(0.004, 1.7135), (0.022, 1.7140), (0.038, 1.7170)], 0.0006),
             ([(0.0205, 1.6045), (0.0280, 1.5930), (0.0350, 1.5800), (0.0375, 1.5705)], 0.0011),   # nose to mouth
             ([(0.020, 1.6335), (0.031, 1.6305), (0.043, 1.6330)], 0.0006),         # under the eyes
             ([(0.0555, 1.6455), (0.0630, 1.6490)], 0.0006),                        # crow's feet
             ([(0.0555, 1.6420), (0.0635, 1.6415)], 0.0006),
             ([(0.0550, 1.6390), (0.0620, 1.6345)], 0.0006)]
    d = np.min([F.polyline(p2, pts, [w] * len(pts)) for pts, w in lines], 0)
    col = np.array([0.33, 0.19, 0.13]) * np.ones((len(P), 1))
    return col, soft(d, 0.0005) * 0.42 * (P[:, 2] > 0.02) * (N[:, 2] > -0.2)


def decal(name, fn, tint=None, offset=F.DECAL_OFFSET, tex=F.DECAL_TEX):
    cov = fn(H.P, H.N, H.at_texels)[1]
    tris = F.tris_touching(H, cov, 0.004, 1)
    part, st = F.decal_part(H, name, tris, fn, FD, tint=tint, offset=offset, tex=tex)
    stats[name] = st
    return part


def write(name, parts):
    glb.write_parts(H.js, H.bn, f"{FD}/{name}.glb", parts)


# The tint every hair piece takes: the scalp hair's lit tone (the brighter half of the painted hair, where the hair
# shell covers the head), so strands can be darker than it but not lighter. A hair-colour choice replaces it.
hair_t = H.C[H.at_texels(H.field) > 0.8]
hl = hair_t @ F.LUM
HAIR = tuple(float(c) for c in np.median(hair_t[hl > np.median(hl)], 0))
stats["hair_tint"] = "#%02x%02x%02x" % tuple(int(round(c * 255)) for c in HAIR)
hs = decal("heavy_stubble", heavy_stubble, HAIR, tex=1024)   # the whole beard zone: twice the texels
write("fh_clean", [shave])
write("fh_heavy_stubble", [shave, hs])
write("fh_moustache", [shave, decal("moustache", moustache, HAIR)])
write("fh_goatee", [shave, decal("goatee", goatee, HAIR)])
for kind in BROWS:
    write(f"br_{kind}", [browless, decal(f"brows_{kind}", brow(kind), HAIR)])
FEATURES = {
    "brow_scar": scar([(0.0345, 1.6700), (0.0385, 1.6585), (0.0410, 1.6490)], [0.0015, 0.0025, 0.0013]),
    "cheek_scar": scar([(-0.0600, 1.6290), (-0.0530, 1.6120), (-0.0455, 1.5930)], [0.0016, 0.0032, 0.0018]),
    "freckles": freckles, "face_paint": face_paint, "age_lines": age_lines,
}
for name, fn in FEATURES.items():
    write(f"ft_{name}", [decal(name, fn, offset=F.FEATURE_OFFSET)])


# --- shell beards ---------------------------------------------------------------------------------------------
# The beard zone's head triangles, cut 16 ways, pushed out along the normal by the beard's length times how
# thick this man's stubble grows there (thinning to 0.8 mm at the rim and to nothing at the lips), with a skirt
# that drops the open edge 0.5 mm into the skin. The texture is strands flowing down; its alpha frays the rim.
def split4(b):
    a_, c_, d_ = b
    ab, bc, ca = (a_ + c_) / 2, (c_ + d_) / 2, (d_ + a_) / 2
    return [np.array(x) for x in ((a_, ab, ca), (ab, c_, bc), (ca, bc, d_), (ab, bc, ca))]


SUB = [np.eye(3)]
for _ in range(2):
    SUB = [q for b in SUB for q in split4(b)]
SUB = np.array(SUB)
lipprox = F.smooth_field(lips_v.astype(float), H.wtris, 3)


def beard_shell(name, length, drop):
    src = np.nonzero(beard[H.wtris].max(1) > 0.3)[0]
    cb = np.repeat(SUB[None], len(src), 0).reshape(-1, 3, 3)
    cs = np.repeat(src, len(SUB))
    cpos = np.einsum("tkj,tjd->tkd", cb, H.A["POSITION"][H.tris[cs]])
    key = np.round(cpos.reshape(-1, 3) / 1e-7).astype(np.int64)
    _, first, vid = np.unique(key, axis=0, return_index=True, return_inverse=True)
    vid = vid.reshape(-1, 3)
    fb, fs = cb.reshape(-1, 3)[first], np.repeat(cs, 3)[first]
    vpos = cpos.reshape(-1, 3)[first]
    interp = lambda f: np.einsum("nk,nk->n", fb, f[H.wtris[fs]])
    vn = np.einsum("nk,nkj->nj", fb, H.wn[H.wtris[fs]]); vn /= np.linalg.norm(vn, axis=1, keepdims=True)
    g = F.smoothstep(0.3, 0.75, interp(beard)) * (1 - F.smoothstep(0.02, 0.3, interp(lipprox))) * (1 - H.lips(vpos))
    keep = (g[vid] > 0.04).all(1)
    ct = vid[keep]
    used = np.unique(ct)
    loc = np.full(len(vpos), -1); loc[used] = np.arange(len(used)); ct = loc[ct]
    gu, pu, nu = g[used], vpos[used], vn[used]
    off = 0.0008 + (length - 0.0008) * F.smoothstep(0.04, 0.7, gu)
    ax, y = np.abs(pu[:, 0]), pu[:, 1]
    chin = (1 - F.smoothstep(0.012, 0.04, ax)) * F.smoothstep(1.575, 1.535, y) * F.smoothstep(0.04, 0.7, gu)
    top = pu + nu * off[:, None] + np.array([0.0, -1.0, 0.25]) * (drop * chin)[:, None]
    e = np.concatenate([ct[:, [0, 1]], ct[:, [1, 2]], ct[:, [2, 0]]])
    eu, cnt = np.unique(np.sort(e, 1), axis=0, return_counts=True)
    open_e = set(map(tuple, eu[cnt == 1]))
    bnd = np.array([ed for ed in e if tuple(sorted(ed)) in open_e])
    bv = np.unique(bnd)
    bl = {v: len(used) + i for i, v in enumerate(bv)}
    verts = np.concatenate([top, pu[bv] - nu[bv] * 0.0005])
    faces = np.concatenate([ct, np.array([f for a_, b_ in bnd for f in ([b_, a_, bl[a_]], [b_, bl[a_], bl[b_]])])])
    vsrc = np.concatenate([used, used[bv]])
    # The skin's weights (blend the three source vertices, keep the top four). The plan said rigid on Head: in the clip
    # gate that sank the shells up to 30 mm into the jaw and chest (the chin skin carries 20-30 % Neck); these stay
    # under 2 mm.
    Jh, Wh = H.A["JOINTS_0"].astype(np.int64), H.A["WEIGHTS_0"].astype(np.float64)
    J = np.zeros((len(verts), 4), H.A["JOINTS_0"].dtype); Wt = np.zeros((len(verts), 4), np.float32)
    for i, sv in enumerate(vsrc):
        acc = {}
        for k in range(3):
            for j, w in zip(Jh[H.tris[fs[sv], k]], Wh[H.tris[fs[sv], k]]):
                if w > 0:
                    acc[j] = acc.get(j, 0.0) + w * fb[sv, k]
        topw = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(w for _, w in topw)
        for n_, (j, w) in enumerate(topw):
            J[i, n_], Wt[i, n_] = j, w / tot
    fn = np.cross(verts[ct[:, 1]] - verts[ct[:, 0]], verts[ct[:, 2]] - verts[ct[:, 0]])
    nrm = np.zeros_like(verts)
    for k in range(3):
        np.add.at(nrm, ct[:, k], fn)
    nrm[len(used):] = nu[bv]
    nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-12
    gv, guv, gidx = F.unwrap(verts, faces)
    arr = {"POSITION": verts[gv], "NORMAL": nrm[gv], "TEXCOORD_0": guv, "JOINTS_0": J[gv], "WEIGHTS_0": Wt[gv],
           "indices": gidx.reshape(-1)}
    # texture: strands down the beard; the rim (thin growth) and the skirt fray to nothing
    TEX = 1024
    gt = gidx.reshape(-1, 3)
    T = F.raster(guv, gt, TEX, TEX)
    gfull = np.concatenate([gu, np.zeros(len(bv))])[gv]
    Pt = np.einsum("nk,nkj->nj", T["bary"], verts[gv][gt[T["tri"]]])
    Nt = np.einsum("nk,nkj->nj", T["bary"], nrm[gv][gt[T["tri"]]]); Nt /= np.linalg.norm(Nt, axis=1, keepdims=True)
    Gt = np.einsum("nk,nk->n", T["bary"], gfull[gt[T["tri"]]])
    sh, a_ = hairy(Pt, Nt, F.smoothstep(0.0, 0.35, Gt), down_flow(Pt, Nt, out=0.2), 91, k=12.0, fringe=1.2, scale=1.4)
    img = np.zeros((TEX, TEX, 4), np.float32)
    a_ = np.where(Gt > 0.5, 1.0, a_)
    img[T["row"], T["col"], :3] = np.where(a_[:, None] > 0.3, 0.4 + 0.6 * (sh - 0.55) / 0.45, 0.8)  # more contrast than a decal
    img[T["row"], T["col"], 3] = a_
    done = np.zeros((TEX, TEX), bool); done[T["row"], T["col"]] = True
    alpha = np.repeat(img[..., 3:], 3, 2); d2 = done.copy()
    F.dilate_into(img, done, np.zeros_like(done), 8); F.dilate_into(alpha, d2, np.zeros_like(d2), 8)
    img[..., 3] = alpha[..., 0]
    F.save_atlas(img, f"{FD}/{name}.png", alpha=True)
    mat = {"name": name, "doubleSided": True, "alphaMode": "MASK", "alphaCutoff": 0.5,
           "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "baseColorFactor": [*F._lin(HAIR), 1.0],
                                    "metallicFactor": 0.0, "roughnessFactor": 0.85}}
    stats[name] = {"triangles": int(len(faces)), "skirt_triangles": int(len(faces) - len(ct)), "length_mm": length * 1000,
                   "chin_drop_mm": drop * 1000}
    return {"name": name + "_hairtint", "arrays": arr, "material": mat, "images": [{"uri": f"{name}.png", "name": name}]}


# ASSUMPTION: the long beard is the full beard at 12 mm with the chin carried 22 mm further down.
write("fh_beard_short", [shave, hs, beard_shell("beard_short", 0.006, 0.0)])
write("fh_beard_long", [shave, hs, beard_shell("beard_long", 0.012, 0.022)])
# Rows for CHARCREATE's appearance.json, parts "facial_hair", "brows" (a new slot) and "face" (its "Facial Features"):
# its option shape (id, name, scene, attach_bone, genders) plus "region", the PlayerEquipment region the piece fills
# (PlayerEquipment.set_part(region, scene)). The first row of each part is today's look: nothing attached.
# ASSUMPTION: genders ["m"]: the pieces are drawn on the v2 base, a man; the base rows keep CHARCREATE's ["m", "f"].
R = "res://assets/characters/survivor/face/"


def rows(region, items):
    return [{"id": i, "name": n, "scene": (R + f + ".glb") if f else "", "attach_bone": "Head", "region": region,
             "genders": ["m"] if f else ["m", "f"]} for i, n, f in items]


stats["options"] = {
    "facial_hair": rows("facial_hair", [("base_stubble", "Stubble", ""), ("clean", "Clean-shaven", "fh_clean"),
                                        ("heavy_stubble", "Heavy stubble", "fh_heavy_stubble"), ("moustache", "Moustache", "fh_moustache"),
                                        ("goatee", "Goatee", "fh_goatee"), ("beard_short", "Short beard", "fh_beard_short"),
                                        ("beard_long", "Long beard", "fh_beard_long")]),
    "brows": rows("brows", [("base_brows", "Natural", ""), ("straight", "Straight", "br_straight"),
                            ("arched", "Arched", "br_arched"), ("bushy", "Bushy", "br_bushy")]),
    "face": rows("features", [("base_face", "None", ""), ("brow_scar", "Brow scar", "ft_brow_scar"),
                              ("cheek_scar", "Cheek scar", "ft_cheek_scar"), ("freckles", "Freckles", "ft_freckles"),
                              ("face_paint", "Face paint", "ft_face_paint"), ("age_lines", "Age lines", "ft_age_lines")]),
}
json.dump(stats, open(f"{FD}/face.json", "w"), indent=1)
print("FACE", json.dumps(stats))
