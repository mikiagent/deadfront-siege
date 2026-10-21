# P2 short crop: the scalp pushed out into a thin hair shell with its own strand texture. Headless:
#   Blender -b --factory-startup -P crop_hair.py -- <hair_dir>
# Reads head.glb / hair_current.glb (split_hair.py), writes hair_crop.glb + hair_crop_Color.jpg (1024).
# Shape: the head triangles under the old hair, each cut into 16, offset along the smooth normal by how much
# hair the head's own paint shows there: 0.8 mm where the painted hairline fades out, 8.5 mm over the crown.
# So the crop's edge follows the painted hairline, not the coarse triangles. A skirt drops the open edge back
# into the scalp so no gap shows. Joints/weights are blended from the source triangle's vertices, so the crop
# deforms with the scalp in every clip. Colour: the head's paint under each texel, broken into short strands
# flowing out from the crown where that paint is hair.
import bpy, sys, os, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb
from paintlib import load_atlas, save_atlas, raster, vnoise, scalp_field, smoothstep, smooth_field, dilate_into

argv = sys.argv[sys.argv.index("--") + 1:]
D = argv[0]
TEX = 1024
LUM = np.array([0.2126, 0.7152, 0.0722])
js, bn = glb.read(f"{D}/head.glb")
H = glb.mesh_arrays(js, bn)
hjs, hbn = glb.read(f"{D}/hair_current.glb")
R = glb.mesh_arrays(hjs, hbn)
tris = H["indices"].reshape(-1, 3)
wid, wpos, wn, field, wtris = scalp_field(H, R)
atlas = load_atlas(os.path.join(D, js["images"][1]["uri"]))
AH, AW = atlas.shape[:2]


def sample(uv):
    return atlas[np.clip((uv[:, 1] * AH).astype(int), 0, AH - 1), np.clip((uv[:, 0] * AW).astype(int), 0, AW - 1), :3]


# Paint "hairness": 0 at the skin around the old hair, 1 at the painted scalp.
T0 = raster(H["TEXCOORD_0"], tris, AW, AH)
F0 = np.einsum("nk,nk->n", T0["bary"], field[wtris[T0["tri"]]])
L0 = atlas[T0["row"], T0["col"], :3] @ LUM
L_skin, L_hair = float(np.median(L0[F0 < 0.06])), float(np.median(L0[F0 > 0.8]))


def hairness(rgb):
    return np.clip((L_skin - rgb @ LUM) / (L_skin - L_hair), 0, 1)


# --- subdivide the scalp triangles (barycentric template, 16 per source triangle) --------------------------
def split(b):
    a, c_, d = b
    ab, bc, ca = (a + c_) / 2, (c_ + d) / 2, (d + a) / 2
    return [np.array(x) for x in ((a, ab, ca), (ab, c_, bc), (ca, bc, d), (ab, bc, ca))]


sub = [np.eye(3)]
for _ in range(2):
    sub = [s for b in sub for s in split(b)]
sub = np.array(sub)                                  # (16, 3 corners, 3 weights)
srcs = np.nonzero(field[wtris].max(1) > 0.2)[0]
cb = np.repeat(sub[None], len(srcs), 0).reshape(-1, 3, 3)     # corner barycentrics
cs = np.repeat(srcs, len(sub))                                 # source head triangle per sub-triangle
cpos = np.einsum("tkj,tjd->tkd", cb, H["POSITION"][tris[cs]])
cuv = np.einsum("tkj,tjd->tkd", cb, H["TEXCOORD_0"][tris[cs]])  # head UVs per corner (seam-safe)
cn = np.einsum("tkj,tjd->tkd", cb, wn[wtris[cs]])
key = np.round(cpos.reshape(-1, 3) / 1e-7).astype(np.int64)
_, first, vid = np.unique(key, axis=0, return_index=True, return_inverse=True)
vid = vid.reshape(-1, 3)
nv = len(first)
vpos = cpos.reshape(-1, 3)[first]
vnrm = cn.reshape(-1, 3)[first]; vnrm /= np.linalg.norm(vnrm, axis=1, keepdims=True)
ch = hairness(sample(cuv.reshape(-1, 2))).reshape(-1)
vh = np.zeros(nv); np.add.at(vh, vid.reshape(-1), ch); vh /= np.bincount(vid.reshape(-1), minlength=nv)
vh = smooth_field(vh, vid, 4)
# Joints/weights: blend the three source vertices' influences by barycentric weight, keep the top four.
J, W = H["JOINTS_0"].astype(np.int64), H["WEIGHTS_0"].astype(np.float64)
fb = cb.reshape(-1, 3)[first]; fs = np.repeat(cs, 3)[first]
vj = np.zeros((nv, 4), H["JOINTS_0"].dtype); vw = np.zeros((nv, 4), np.float32)
for i in range(nv):
    acc = {}
    for k in range(3):
        sv = tris[fs[i], k]
        for j, w in zip(J[sv], W[sv]):
            if w > 0:
                acc[j] = acc.get(j, 0.0) + w * fb[i, k]
    top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
    tot = sum(w for _, w in top)
    for n, (j, w) in enumerate(top):
        vj[i, n], vw[i, n] = j, w / tot

# Keep the covered interior whole (the scalp paint has lighter patches) and let the paint decide only the rim.
inner = field[wtris[cs]].min(1) > 0.5
keep = inner | ((vh[vid].max(1) > 0.3) & (vh[vid].mean(1) > 0.2))
ct, cuv_k = vid[keep], cuv[keep]
used = np.unique(ct)
loc = np.full(nv, -1); loc[used] = np.arange(len(used))
ct = loc[ct]
off = 0.0008 + 0.0077 * smoothstep(0.2, 0.85, vh[used])
top = vpos[used] + vnrm[used] * off[:, None]
# Skirt: each open edge of the crop drops back to 0.5 mm under the scalp.
e = np.concatenate([ct[:, [0, 1]], ct[:, [1, 2]], ct[:, [2, 0]]])
eu, cnt = np.unique(np.sort(e, 1), axis=0, return_counts=True)
open_e = set(map(tuple, eu[cnt == 1]))
bnd = np.array([ed for ed in e if tuple(sorted(ed)) in open_e])
bv = np.unique(bnd)
bl = {v: len(used) + i for i, v in enumerate(bv)}
verts = np.concatenate([top, vpos[used[bv]] - vnrm[used[bv]] * 0.0005])
skirt = []
for a, b in bnd:
    skirt += [[b, a, bl[a]], [b, bl[a], bl[b]]]
faces = np.concatenate([ct, np.array(skirt)])
vsrc = np.concatenate([used, used[bv]])             # subdivided vertex each crop vertex copies skin from
# Head UVs per face corner for the paint underneath (skirt corners use their top vertex's corner UV).
fuv = np.zeros((len(faces), 3, 2)); fuv[:len(ct)] = cuv_k
cuv_of = {}
for t in range(len(ct)):
    for k in range(3):
        cuv_of.setdefault(ct[t, k], cuv_k[t, k])
inv_bl = {v: k for k, v in bl.items()}
used_of_bottom = {v: k for k, v in bl.items()}      # skirt bottom vertex -> rim vertex
for t in range(len(ct), len(faces)):
    for k in range(3):
        v = faces[t, k]
        fuv[t, k] = cuv_of[v if v < len(used) else inv_bl[v]]

# --- new UVs (Smart UV Project; Blender is Z-up and flips V against glTF) ---------------------------------
me = bpy.data.meshes.new("crop")
me.from_pydata([tuple(map(float, (p[0], -p[2], p[1]))) for p in verts], [], [tuple(map(int, f)) for f in faces])
me.update()
ob = bpy.data.objects.new("crop", me)
bpy.context.scene.collection.objects.link(ob)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01, area_weight=0.0, correct_aspect=True, scale_to_bounds=True)
bpy.ops.object.mode_set(mode="OBJECT")
luv = np.array([d.uv[:] for d in me.uv_layers.active.data])
lv = np.array([l.vertex_index for l in me.loops])
poly_loops = np.array([[p.loop_start + k for k in range(3)] for p in me.polygons])
# Skirt strips are too thin for their own UV islands: they take the UV of the rim vertex they hang from.
rim_uv = {}
for t in range(len(ct)):
    for L in poly_loops[t]:
        rim_uv.setdefault(lv[L], luv[L])
for t in range(len(ct), len(faces)):
    for L in poly_loops[t]:
        v = lv[L]
        luv[L] = rim_uv[v if v < len(used) else used_of_bottom[v]]
pairs = np.round(np.concatenate([lv[:, None], luv * 1e6], 1)).astype(np.int64)
_, first, inv = np.unique(pairs, axis=0, return_index=True, return_inverse=True)
inv = inv.reshape(-1)
gv = lv[first]
guv = luv[first].copy(); guv[:, 1] = 1.0 - guv[:, 1]
gidx = inv[poly_loops].reshape(-1)

fn = np.cross(verts[ct[:, 1]] - verts[ct[:, 0]], verts[ct[:, 2]] - verts[ct[:, 0]])
vn = np.zeros_like(verts)
for k in range(3):                                   # crop faces only: the skirt must not tilt the rim
    np.add.at(vn, ct[:, k], fn)
vn[len(used):] = vnrm[used[bv]]
vn /= np.linalg.norm(vn, axis=1, keepdims=True) + 1e-12
arr = {"POSITION": verts[gv], "NORMAL": vn[gv], "TEXCOORD_0": guv,
       "JOINTS_0": vj[vsrc[gv]], "WEIGHTS_0": vw[vsrc[gv]], "indices": gidx}

# --- strand texture -----------------------------------------------------------------------------------------
gt = gidx.reshape(-1, 3)
T = raster(guv, gt, TEX, TEX)
bary, tri = T["bary"], T["tri"]
P = np.einsum("nk,nkj->nj", bary, arr["POSITION"][gt[tri]])
N = np.einsum("nk,nkj->nj", bary, arr["NORMAL"][gt[tri]])
N /= np.linalg.norm(N, axis=1, keepdims=True)
under = sample(np.einsum("nk,nkj->nj", bary, fuv[tri]))
# ASSUMPTION: crown whorl at the back of the top of the head; the crop flows out from it along the surface.
C = np.array([0.0, wpos[np.unique(wtris)][:, 1].max() - 0.025, -0.03])
flow = P - C
flow -= N * (flow * N).sum(1, keepdims=True)
flow /= np.linalg.norm(flow, axis=1, keepdims=True) + 1e-9
k = 6.0                                              # strands 6x longer than wide
Q = P - flow * (flow * P).sum(1, keepdims=True) * (1 - 1 / k)
strands = 0.55 * vnoise(Q, 600.0, 21) + 0.3 * vnoise(Q, 220.0, 22) + 0.15 * vnoise(P, 60.0, 23)
mod = 0.62 + 0.75 * strands                          # dark gaps between lighter strands
w = smoothstep(0.15, 0.6, hairness(under))
col = under * (1 + w * (mod - 1))[:, None]
img = np.ones((TEX, TEX, 4), np.float32); img[..., :3] = np.median(col[w < 0.1], 0)   # rim colour behind islands
img[T["row"], T["col"], :3] = col
done = np.zeros((TEX, TEX), bool); done[T["row"], T["col"]] = True
dilate_into(img, done, np.zeros_like(done), 8)
save_atlas(img, f"{D}/hair_crop_Color.jpg")

mat = {"name": "hair_crop", "doubleSided": True,
       "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 0.85}}
glb.write_piece(js, bn, f"{D}/hair_crop.glb", arr, "hair_crop", [{"uri": "hair_crop_Color.jpg", "name": "Color"}], mat)
stats = {"triangles": int(len(faces)), "skirt_triangles": int(len(skirt)), "vertices": int(len(gv)),
         "offset_mm": [round(float(off.min()) * 1000, 2), round(float(off.max()) * 1000, 2)], "texture": TEX,
         "paint_luminance": {"skin": round(L_skin, 4), "hair": round(L_hair, 4)}}
man = f"{D}/hair.json"
data = json.load(open(man)) if os.path.exists(man) else {}
data["crop"] = stats
json.dump(data, open(man, "w"), indent=1)
print("CROP", json.dumps(stats))
