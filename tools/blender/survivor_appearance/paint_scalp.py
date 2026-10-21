# P2 scalp repaints for the bald and buzz options. Headless:
#   Blender -b --factory-startup -P paint_scalp.py -- <hair_dir>
# Reads <hair_dir>/head.glb and hair_current.glb (from split_hair.py) and the survivor's Color atlas, and writes
#   head_bald.glb + head_bald_Color.jpg  - scalp repainted to the surrounding skin tone
#   head_buzz.glb + head_buzz_Color.jpg  - skin with a dense stubble shadow and a clean hairline
# The UVs are Tripo's auto-unwrap (islands all over the atlas), so nothing is painted in UV space by hand:
# every head triangle is rasterised into the atlas with its bind-pose 3D position, and colour comes from 3D.
# Scalp = head surface the hair shell covers (ray along the normal hits the hair within 5 cm), smoothed over
# the mesh so the hairline is soft and follows the head rather than the shell's jagged strand ends.
import sys, os, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb
from paintlib import load_atlas, save_atlas, raster, vnoise, dilate_into, scalp_field, smoothstep

argv = sys.argv[sys.argv.index("--") + 1:]
D = argv[0]
js, bn = glb.read(f"{D}/head.glb")
H = glb.mesh_arrays(js, bn)
hjs, hbn = glb.read(f"{D}/hair_current.glb")
R = glb.mesh_arrays(hjs, hbn)
tris = H["indices"].reshape(-1, 3)
pos, nrm, uv = H["POSITION"], H["NORMAL"], H["TEXCOORD_0"]
atlas = load_atlas(os.path.join(D, js["images"][1]["uri"]))   # Color, top row first, float 0-1
AH, AW = atlas.shape[:2]

# --- scalp field on welded head vertices ---------------------------------------------------------------
wid, wpos, wn, field, wtris = scalp_field(H, R)
nw = len(field)
vfield = field[wid]

# --- rasterise the head into the atlas ------------------------------------------------------------------
T = raster(uv, tris, AW, AH)            # texel rows/cols, triangle id, barycentrics
bary, tri = T["bary"], T["tri"]
P = np.einsum("nk,nkj->nj", bary, pos[tris[tri]])
F = np.einsum("nk,nk->n", bary, vfield[tris[tri]])
orig = atlas[T["row"], T["col"], :3]

# Skin fill = harmonic continuation of the skin around the scalp: every welded vertex gets the mean colour of
# the texels nearest to it; vertices clear of the hair (field < 0.06) and not dark (brows, eyes) are fixed,
# the rest are relaxed to the average of their neighbours, so the crown takes the forehead tone in front and
# the nape tone behind with no seam at the old hairline.
near = wid[tris[tri, np.argmax(bary, 1)]]
vcol = np.zeros((nw, 3)); np.add.at(vcol, near, orig)
vcnt = np.bincount(near, minlength=nw).astype(float)
vcol /= np.maximum(vcnt, 1)[:, None]
vl = vcol @ np.array([0.2126, 0.7152, 0.0722])
med = np.median(vl[(vcnt > 0) & (field < 0.06)])
fixed = (vcnt > 0) & (field < 0.06) & (vl > 0.6 * med)    # all skin but the brows/eyes/lashes
e = np.unique(np.sort(np.concatenate([wtris[:, [0, 1]], wtris[:, [1, 2]], wtris[:, [2, 0]]]), 1), axis=0)
deg = np.bincount(e.ravel(), minlength=nw).astype(float)
c = np.where(fixed[:, None], vcol, med)
for _ in range(800):
    s_ = np.zeros((nw, 3)); np.add.at(s_, e[:, 0], c[e[:, 1]]); np.add.at(s_, e[:, 1], c[e[:, 0]])
    c = np.where(fixed[:, None], vcol, s_ / np.maximum(deg, 1)[:, None])

scalp = F > 0.03
SP = P[scalp]
fill = np.einsum("nk,nkj->nj", bary[scalp], c[wid[tris[tri[scalp]]]])
mottle = 1.0 + 0.03 * (vnoise(SP, 22.0, 3) - 0.5) * 2 + 0.015 * (vnoise(SP, 70.0, 5) - 0.5) * 2
fill *= mottle[:, None]
Fs, Os = F[scalp], orig[scalp]
Ls = Os @ np.array([0.2126, 0.7152, 0.0722])
Lf = fill @ np.array([0.2126, 0.7152, 0.0722])
dark = np.clip((Lf - Ls) / (0.3 * Lf), 0, 1)        # how much darker than skin the original paint is
stats = {"scalp_vertices": int((field > 0.5).sum()), "fixed_skin_vertices": int(fixed.sum()),
         "scalp_texels": int(scalp.sum())}


def write(name, new, w):
    out = atlas.copy()
    rr, cc = T["row"][scalp], T["col"][scalp]
    out[rr, cc, :3] = Os * (1 - w[:, None]) + new * w[:, None]
    changed = np.zeros((AH, AW), bool); changed[rr, cc] = True
    covered = np.zeros((AH, AW), bool); covered[T["row"], T["col"]] = True
    dilate_into(out, changed, covered, 6)
    img = f"{name}_Color.jpg"
    save_atlas(out, f"{D}/{img}")
    images = [dict(js["images"][0]), {"uri": img, "name": "Color"}, dict(js["images"][2])]
    arr = {k: v for k, v in H.items()}
    glb.write_piece(js, bn, f"{D}/{name}.glb", arr, name, images)
    stats[name] = {"texels_changed": int(changed.sum()), "mean_weight": round(float(w.mean()), 3)}


# Bald: everything the hair covered becomes skin; along the hairline (and the fringe's baked shadow just below
# it) dark paint goes and skin stays.
w_bald = np.maximum(smoothstep(0.10, 0.40, Fs), smoothstep(0.03, 0.25, Fs) * dark)
write("head_bald", fill, w_bald)
# Buzz: the original hair paint (so the real hairline shape) thinned to a stubble shadow over the skin tone,
# with a fine even grain.
grain = vnoise(SP, 420.0, 11)
dens = np.clip(0.62 + 0.10 * (grain - 0.5) * 2, 0, 1)
stub = fill * (1 - dens[:, None]) + Os * dens[:, None]
w_buzz = smoothstep(0.03, 0.25, Fs)
write("head_buzz", stub, w_buzz)

man = f"{D}/hair.json"
data = json.load(open(man)) if os.path.exists(man) else {}
data["scalp_paint"] = stats
json.dump(data, open(man, "w"), indent=1)
print("PAINT", json.dumps(stats))
