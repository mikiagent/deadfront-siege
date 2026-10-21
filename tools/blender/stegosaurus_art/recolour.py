# STEGO-ART step 2: grade the albedo toward the approved concept sheet's palette
# (assets/concept-art/creatures/stegosaurus/concept-sheet-v01.png): olive green-brown hide with dark mottling,
# pale cream belly, rust-red plates darkening at the rims, ivory spikes.
#   Blender -b --factory-startup -P recolour.py -- <in.glb> <out.glb> [--stats] [--masks <png>]
# Hue/saturation/value only, per region; the regions come from the mesh (rasterised into UV space and grown into
# the island padding so mip levels do not bleed the old colour): plates = vertices bound rigidly to one
# spine/neck/hips/tail_01..04 bone (the rig made plates rigid; skin is blended), spikes = tail_05-rigid beyond
# the tail. Normal and ORM maps, UVs and geometry are not touched; only the base colour image bytes change.
import os, sys, colorsys
import numpy as np
import bpy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_io

args = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = args[0], args[1]
STATS = "--stats" in args
MASKS = args[args.index("--masks") + 1] if "--masks" in args else None
TMP = os.path.join(os.path.dirname(os.path.abspath(DST)), "_stego_albedo_tmp")

# Targets read off the sheet (hue in degrees, saturation, value of the region's median texel):
#   hide 40-42 deg / 0.22-0.27 / 0.45-0.55, plates 18-22 deg / 0.33-0.46 / 0.36-0.45, spikes ivory.
HIDE = dict(hue=44.0, sat=0.26, val_gain=1.00, hue_keep=0.25)
BELLY_SAT = 0.13          # pale texels (value above BELLY_V) fade toward a cream with this saturation
BELLY_V = 0.62
PLATE = dict(hue=19.0, sat=0.46, val_gain=0.78, hue_keep=0.25)
SPIKE = dict(hue=38.0, sat=0.13, val_gain=1.18, hue_keep=0.0)

j, b = glb_io.read(SRC)
prim = j["meshes"][0]["primitives"][0]
A = prim["attributes"]
P = glb_io.accessor(j, b, A["POSITION"])
UV = glb_io.accessor(j, b, A["TEXCOORD_0"])
JN = glb_io.accessor(j, b, A["JOINTS_0"])
WT = glb_io.accessor(j, b, A["WEIGHTS_0"])
I = glb_io.accessor(j, b, prim["indices"]).reshape(-1, 3)
names = [j["nodes"][n]["name"] for n in j["skins"][0]["joints"]]
mat = j["materials"][prim["material"]]
tex_i = mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]
img_i = j["textures"][tex_i]["source"]
view_i = j["images"][img_i]["bufferView"]
mime = j["images"][img_i]["mimeType"]

# Load the albedo through Blender (JPEG/PNG decode), as display (sRGB) values.
os.makedirs(TMP, exist_ok=True)
src_img = os.path.join(TMP, "src." + ("jpg" if mime == "image/jpeg" else "png"))
open(src_img, "wb").write(glb_io.view_bytes(j, b, view_i))
im = bpy.data.images.load(src_img)
im.colorspace_settings.name = "Non-Color"   # keep the stored sRGB numbers as they are
W, H = im.size
RGB = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1, :, :3].copy()   # row 0 = top (glTF v=0)

# Region per vertex, then per triangle (all three corners agree), rasterised in UV space.
dom = np.array(names)[JN[np.arange(len(JN)), WT.argmax(1)]]
rigid = WT.max(1) > 0.999
plate_bones = {"hips", "spine_01", "spine_02", "spine_03", "neck_01", "neck_02", "tail_01", "tail_02", "tail_03", "tail_04"}
t5 = next(i for i, n in enumerate(j["nodes"]) if n.get("name") == "tail_05")
def tail_axis():
    from mathutils import Matrix, Quaternion
    parent = {c: i for i, n in enumerate(j["nodes"]) for c in n.get("children", [])}
    def M(i):
        n = j["nodes"][i]; t = n.get("translation", [0, 0, 0]); r = n.get("rotation", [0, 0, 0, 1]); s = n.get("scale", [1, 1, 1])
        m = Matrix.Translation(t) @ Quaternion((r[3], r[0], r[1], r[2])).to_matrix().to_4x4() @ Matrix.Diagonal((*s, 1))
        return M(parent[i]) @ m if i in parent else m
    m = M(t5); d = np.array(m.to_3x3().col[1]).ravel()
    return np.array(m.translation), d / np.linalg.norm(d)
T0, TD = tail_axis()
r_tail = np.linalg.norm((P - T0) - np.outer((P - T0) @ TD, TD), axis=1)
vreg = np.zeros(len(P), np.int8)                                   # 0 hide
vreg[rigid & np.isin(dom, list(plate_bones))] = 1                  # 1 plate
vreg[rigid & (dom == "tail_05") & (r_tail > 0.28)] = 2             # 2 spike
treg = np.where((vreg[I] == vreg[I][:, :1]).all(1), vreg[I][:, 0], 0)

reg = np.full((H, W), -1, np.int8)
UVp = UV.astype(np.float64) * [W, H]
for t, r in zip(I, treg):
    q = UVp[t]
    x0, y0 = np.floor(q.min(0)).astype(int); x1, y1 = np.ceil(q.max(0)).astype(int)
    x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, W - 1), min(y1, H - 1)
    if x1 < x0 or y1 < y0: continue
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    (ax, ay), (bx, by), (cx, cy) = q
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-12: continue
    l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
    l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
    inside = (l1 >= -0.02) & (l2 >= -0.02) & (1 - l1 - l2 >= -0.02)
    sub = reg[y0:y1 + 1, x0:x1 + 1]
    # a plate/spike texel wins over hide where triangles of both touch (rims)
    sub[inside] = np.maximum(sub[inside], r)
# Grow regions into the padding between islands (nearest island wins), so filtering never mixes in old colour.
for _ in range(64):
    un = reg < 0
    if not un.any(): break
    grow = reg.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        sh = np.roll(reg, (dy, dx), (0, 1))
        take = un & (grow < 0) & (sh >= 0)
        grow[take] = sh[take]
    reg = grow
reg[reg < 0] = 0

def rgb2hsv(X):
    mx = X.max(-1); mn = X.min(-1); d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    r, g, bb = X[..., 0], X[..., 1], X[..., 2]
    i0 = m & (mx == r); i1 = m & (mx == g) & ~i0; i2 = m & ~i0 & ~i1
    h[i0] = ((g - bb)[i0] / d[i0]) % 6; h[i1] = (bb - r)[i1] / d[i1] + 2; h[i2] = (r - g)[i2] / d[i2] + 4
    return h * 60.0, np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0), mx
def hsv2rgb(h, s, v):
    h = (h % 360) / 60.0; c = v * s; x = c * (1 - np.abs(h % 2 - 1)); m = v - c
    z = np.zeros_like(h); k = np.floor(h).astype(int) % 6
    rgb = np.select([k[..., None] == i for i in range(6)],
                    [np.stack(t, -1) for t in ((c, x, z), (x, c, z), (z, c, x), (z, x, c), (x, z, c), (c, z, x))])
    return rgb + m[..., None]

Hh, S, V = rgb2hsv(RGB)
def med_hue(h, w):
    a = np.radians(h); return np.degrees(np.arctan2((np.sin(a) * w).sum(), (np.cos(a) * w).sum())) % 360
def stats(tag, Hx, Sx, Vx):
    for k, nm in enumerate(("hide", "plate", "spike")):
        m = reg == k
        print(f"[recolour] {tag} {nm:6s} {m.mean() * 100:5.1f}% of texels  hue {med_hue(Hx[m], Sx[m] + 1e-3):5.1f}  "
              f"sat median {np.median(Sx[m]):.2f}  value median {np.median(Vx[m]):.2f} (p10 {np.percentile(Vx[m], 10):.2f}, p90 {np.percentile(Vx[m], 90):.2f})")
stats("before", Hh, S, V)

H2, S2, V2 = Hh.copy(), S.copy(), V.copy()
for k, T in enumerate((HIDE, PLATE, SPIKE)):
    m = reg == k
    hc = med_hue(Hh[m], S[m] + 1e-3)
    dh = ((Hh[m] - hc + 180) % 360) - 180
    H2[m] = T["hue"] + dh * T["hue_keep"]                       # move the region's hue, keep a little of its spread
    S2[m] = np.clip(S[m] * (T["sat"] / max(np.median(S[m]), 1e-3)), 0, 1)   # scale saturation to the target median
    V2[m] = np.clip(V[m] * T["val_gain"], 0, 1)
# pale hide (belly, throat, inner legs) fades to cream instead of turning bright olive
pale = (reg == 0) & (V > BELLY_V)
f = np.clip((V[pale] - BELLY_V) / 0.15, 0, 1)
S2[pale] = S2[pale] * (1 - f) + np.minimum(S2[pale], BELLY_SAT) * f
H2[pale] = H2[pale] * (1 - f) + 40.0 * f
# plate rims: the sheet's plates darken toward their edges; their darkest texels lose saturation toward charcoal
pm = reg == 1
dark = np.clip((0.40 - V[pm]) / 0.25, 0, 1)
S2[pm] = S2[pm] * (1 - 0.45 * dark)
out = np.clip(hsv2rgb(H2, S2, V2), 0, 1).astype(np.float32)
stats("after ", *rgb2hsv(out))

if MASKS:
    pal = np.array([[0.45, 0.45, 0.4], [0.8, 0.3, 0.1], [0.95, 0.95, 0.85]], np.float32)
    mi = bpy.data.images.new("masks", W, H); mi.colorspace_settings.name = "Non-Color"
    mi.pixels = np.concatenate([pal[reg][::-1], np.ones((H, W, 1), np.float32)], -1).ravel()
    mi.filepath_raw = MASKS; mi.file_format = "PNG"; mi.save()
if STATS:
    sys.exit(0)

oi = bpy.data.images.new("graded", W, H); oi.colorspace_settings.name = "Non-Color"
oi.pixels = np.concatenate([out[::-1], np.ones((H, W, 1), np.float32)], -1).ravel()
out_img = os.path.join(TMP, "graded.jpg")
oi.filepath_raw = out_img; oi.file_format = "JPEG"
oi.save(quality=92)
data = open(out_img, "rb").read()
views = [glb_io.view_bytes(j, b, i) for i in range(len(j["bufferViews"]))]
views[view_i] = data
j["images"][img_i]["mimeType"] = "image/jpeg"
glb_io.write(DST, j, views)
print(f"[recolour] wrote {DST} (albedo {len(data)} bytes; image name kept so Godot re-extracts the same file)")
