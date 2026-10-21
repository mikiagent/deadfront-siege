# P3 helmet shells. Headless:
#   Blender -b --factory-startup -P tools/blender/survivor_appearance/shell_helmet.py -- <helmet_src.glb> <out.glb> <head.glb> <body_chest.glb> <report.json>
# Tripo's armoured helmets carry the man's own head inside them: his face, eyes, mouth, neck and hair are their own
# connected surfaces (welded by position), apart from the helmet's. This keeps:
#  1. the largest surface (the helmet) and every surface that touches it (within TOUCH) and stands clear of the bald
#     head (median CLEAR out): straps, a twig, the forager's crown plug. The face, eyes, mouth and loose debris go, so
#     the survivor's own head, skin, scalp and beard show under the helmet.
#  2. Fit: helmet surface a little under the bald scalp (Tripo's head sat lower than the base head in places) comes out
#     to FIT over it, so the chosen scalp never shows through the helmet (the forager's crown gaps), and helmet close to
#     the skin (head or chest) takes the skin's weights there, so the two move together in every clip.
#  3. Closed crown, in the helmet's darkest paint: helmet faces Tripo painted with the face's skin are repainted, and
#     small holes in the helmet are capped (the forager's band had one in front of the forehead). The skull's eye
#     sockets stay open: they show the wearer's own forehead and scalp, as a worn skull would.
# The embedded maps are the source's, unchanged; only repainted faces and caps get new UVs.
import sys, os, json, tempfile, colorsys
import numpy as np
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb, paintlib

TOUCH = 0.003   # a surface this close to the helmet is part of it
CLEAR = 0.005   # median height over the bald head below which a surface is the man's own head (face, eyes, hair)
FIT = 0.0015    # least height of the helmet over the bald head...
DEEP = 0.006    # ...for helmet up to this far under it
NEAR = 0.03     # skin-painted helmet faces this close to the head get the dark paint
SKIN_W = (0.015, 0.05)  # helmet this close to the skin takes the skin's weights, blending to its own by the far end
CAP_SIDES = 40  # holes in the helmet up to this many edges get capped (the head opening has more)
WELD = 0.0005   # vertices this close count as one when looking for holes

argv = sys.argv[sys.argv.index("--") + 1:]
src, out, head_path, chest_path, report = argv[:5]
js, bn = glb.read(src)
A = glb.mesh_arrays(js, bn)
tris = A["indices"].reshape(-1, 3)
P = A["POSITION"].astype(float)
comp = glb.tri_components(glb.weld_ids(A["POSITION"])[tris])
labs, cnt = np.unique(comp, return_counts=True)
order = np.argsort(-cnt, kind="stable")

hjs, hbn = glb.read(head_path)
H = glb.mesh_arrays(hjs, hbn)
htris = H["indices"].reshape(-1, 3)
assert [hjs["nodes"][j]["name"] for j in hjs["skins"][0]["joints"]] == [js["nodes"][j]["name"] for j in js["skins"][0]["joints"]]


def bvh(pos, t):
    return BVHTree.FromPolygons([tuple(map(float, p)) for p in pos], [tuple(map(int, x)) for x in t])


head = bvh(H["POSITION"], htris)


def over_head(p):  # signed distance over the bald head (+ outside) and the head normal there
    loc, n, _, _ = head.find_nearest(Vector(p))
    return (Vector(p) - loc).dot(n), np.array(n)


# 1. The helmet's own surfaces.
main = bvh(P, tris[comp == labs[order[0]]])
keep = np.zeros(len(tris), bool)
rows = []
for r, k in enumerate(order):
    m = comp == labs[k]
    pts = P[np.unique(tris[m])]
    out_m = float(np.median([over_head(p)[0] for p in pts]))
    gap = 0.0 if r == 0 else min(main.find_nearest(Vector(p))[3] for p in pts)
    kept = r == 0 or (gap < TOUCH and out_m > CLEAR)
    keep |= m if kept else False
    rows.append({"triangles": int(cnt[k]), "kept": bool(kept), "touch_mm": round(gap * 1000, 1),
                 "median_over_head_mm": round(out_m * 1000, 1), "y_range": [round(float(pts[:, 1].min()), 3), round(float(pts[:, 1].max()), 3)]})
arr, used = glb.subset(A, keep)
kt = arr["indices"].reshape(-1, 3)
kw = glb.weld_ids(arr["POSITION"])
wp = np.zeros((kw.max() + 1, 3))
wp[kw] = arr["POSITION"]

# 2. Fit: helmet a little under the bald scalp (down to DEEP) comes out to FIT over it, every layer, so the scalp
# never shows through the helmet or into its holes. Deeper parts (lips tucked into the head) stay hidden in it.
need = np.zeros(len(wp))
nrm = np.zeros((len(wp), 3))
for w in range(len(wp)):
    h, n = over_head(wp[w])
    nrm[w] = n
    if -DEEP < h < FIT:
        need[w] = FIT - h
push = np.maximum(need, paintlib.smooth_field(need, kw[kt], 2))  # the neighbours follow part of the way
wp += nrm * push[:, None]
arr["POSITION"] = wp[kw].astype(np.float32)
fit = {"vertices_pushed": int((need > 0).sum()), "max_push_mm": round(float(need.max()) * 1000, 1)}
# Helmet close to the body takes the skin's own weights there (head or chest, blended out by SKIN_W), so it rides
# with the skin under it (the temples carry some Neck, the nape Spine2) instead of sliding into it in clips.
cjs, cbn = glb.read(chest_path)
C = glb.mesh_arrays(cjs, cbn)
assert [cjs["nodes"][j]["name"] for j in cjs["skins"][0]["joints"]] == [js["nodes"][j]["name"] for j in js["skins"][0]["joints"]]
SP = np.concatenate([H["POSITION"], C["POSITION"]]).astype(float)
ST = np.concatenate([htris, C["indices"].reshape(-1, 3) + len(H["POSITION"])])
SJ = np.concatenate([H["JOINTS_0"], C["JOINTS_0"]]).astype(int)
SW = np.concatenate([H["WEIGHTS_0"], C["WEIGHTS_0"]]).astype(float)
skin_bvh = bvh(SP, ST)
J, W = arr["JOINTS_0"].astype(int), arr["WEIGHTS_0"].astype(float)
taken = 0
for i, p in enumerate(arr["POSITION"].astype(float)):
    loc, _, f, dist = skin_bvh.find_nearest(Vector(p))
    t = paintlib.smoothstep(SKIN_W[0], SKIN_W[1], dist)
    if t >= 1.0:
        continue
    corners = SP[ST[f]]
    bary = 1.0 / (np.linalg.norm(corners - np.array(loc), axis=1) + 1e-6)
    mix = {}
    for c, bw in zip(ST[f], bary / bary.sum()):
        for j, w in zip(SJ[c], SW[c]):
            mix[j] = mix.get(j, 0.0) + (1 - t) * bw * w
    for j, w in zip(J[i], W[i]):
        mix[j] = mix.get(j, 0.0) + t * w
    top = sorted(mix.items(), key=lambda kv: -kv[1])[:4]
    tot = sum(w for _, w in top)
    J[i] = [j for j, _ in top] + [0] * (4 - len(top))
    W[i] = [w / tot for _, w in top] + [0.0] * (4 - len(top))
    taken += 1
arr["JOINTS_0"], arr["WEIGHTS_0"] = J.astype(arr["JOINTS_0"].dtype), W.astype(arr["WEIGHTS_0"].dtype)
fit["vertices_with_head_weights"] = taken

# 3a. The helmet's darkest paint: a small patch inside its darkest wide UV triangle. Repainted faces and caps map into it
# (planar, never degenerate, so tangents stay valid).
img = glb.embedded_images(js, bn)[[i["name"].split("_")[0] for i in js["images"]].index("Color")]
with tempfile.NamedTemporaryFile(suffix=".jpg" if img["mimeType"] == "image/jpeg" else ".png", delete=False) as f:
    f.write(img["bytes"])
atlas = paintlib.load_atlas(f.name)
os.unlink(f.name)
AH, AW = atlas.shape[:2]
uvpx = arr["TEXCOORD_0"].astype(float) * [AW, AH]
cands = []
for t in kt:
    a, b, c = uvpx[t]
    la, lb, lc = np.linalg.norm(b - c), np.linalg.norm(c - a), np.linalg.norm(a - b)
    s = la + lb + lc
    area = 0.5 * abs((b - a)[0] * (c - a)[1] - (b - a)[1] * (c - a)[0])
    if s > 0 and area > 0:
        inc = (la * a + lb * b + lc * c) / s
        col = atlas[min(int(inc[1]), AH - 1), min(int(inc[0]), AW - 1), :3]
        cands.append((float(col @ [0.2126, 0.7152, 0.0722]), 2 * area / s, inc, col))
lum = np.array([c[0] for c in cands])
_, rad, inc, col = max([c for c in cands if c[0] <= np.percentile(lum, 15)], key=lambda c: c[1])


def patch_uv(pos):
    if len(pos) == 0:
        return np.zeros((0, 2), np.float32)
    q = pos[:, [0, 2]] - pos[:, [0, 2]].mean(0)
    return ((inc + q / (np.abs(q).max() + 1e-9) * rad * 0.6) / [AW, AH]).astype(np.float32)


# 3b. Skin paint: Tripo painted some helmet faces next to the face it was made around with skin. Those faces near the
# head get the dark paint instead, on their own vertex copies so their neighbours keep their UVs. SKIN is
# tools/render_icons.py's skin colour.
SKIN = {"hue": (10.0, 26.0), "sat": (0.28, 0.60), "val": 0.58}


def is_skin(rgb):
    hu, sa, va = colorsys.rgb_to_hsv(*rgb)
    return SKIN["hue"][0] <= hu * 360 <= SKIN["hue"][1] and SKIN["sat"][0] <= sa <= SKIN["sat"][1] and va >= SKIN["val"]


skin = np.zeros(len(kt), bool)
for i, t in enumerate(kt):
    sp = np.vstack([uvpx[t], uvpx[t].mean(0)])
    c = np.mean([atlas[min(int(y), AH - 1), min(int(x), AW - 1), :3] for x, y in sp], 0)
    skin[i] = is_skin(c) and abs(over_head(arr["POSITION"][t].astype(float).mean(0))[0]) < NEAR
sv = np.unique(kt[skin])
copy = np.full(len(arr["POSITION"]), -1, np.int64)
copy[sv] = len(arr["POSITION"]) + np.arange(len(sv))
for key in ("POSITION", "NORMAL", "JOINTS_0", "WEIGHTS_0"):
    arr[key] = np.concatenate([arr[key], arr[key][sv]])
arr["TEXCOORD_0"] = np.concatenate([arr["TEXCOORD_0"], patch_uv(arr["POSITION"][sv].astype(float))])
kt[skin] = copy[kt[skin]]
arr["indices"] = kt.reshape(-1)

# 3c. Caps: every hole in the kept helmet up to CAP_SIDES edges (not the opening the head goes through) gets a fan,
# unless the head itself fills it (the fan's centre under the scalp). Holes are the simple cycles of boundary edges;
# Tripo pinches some onto the opening at a vertex or two, so a hole is the shortest boundary cycle through an edge.
bm = bmesh.new()
bv = [bm.verts.new(p) for p in arr["POSITION"].astype(float)]
for t in kt.tolist():
    try:
        bm.faces.new([bv[i] for i in t])
    except ValueError:  # degenerate, or the same triangle twice in the source
        pass
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD)  # Tripo leaves near-coincident seams that break hole rims
bm.verts.ensure_lookup_table()
nbr = {}
for x in bm.edges:
    if x.is_boundary:
        e_ = (x.verts[0].index, x.verts[1].index)
        nbr.setdefault(e_[0], []).append((e_[1], x.index))
        nbr.setdefault(e_[1], []).append((e_[0], x.index))
cycles, seen_c = [], set()
for u in sorted(nbr):  # the shortest boundary cycle through each boundary edge
    for v, j in nbr[u]:
        prev, frontier = {v: None}, [v]
        while frontier and u not in prev and len(prev) < 4 * CAP_SIDES:
            nxt = []
            for x in frontier:
                for y, jj in nbr[x]:
                    if jj != j and y not in prev:
                        prev[y] = x
                        nxt.append(y)
            frontier = nxt
        if u not in prev:
            continue
        loop, x = [], u
        while x is not None:
            loop.append(x)
            x = prev[x]
        if len(loop) <= CAP_SIDES and frozenset(loop) not in seen_c:
            seen_c.add(frozenset(loop))
            cycles.append(loop)
kd = KDTree(len(arr["POSITION"]))
for i, p in enumerate(arr["POSITION"]):
    kd.insert(Vector(p), i)
kd.balance()
caps = {k: [] for k in ("POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0")}
cap_idx, capped, skipped = [], [], []
for loop in cycles:
    if len(loop) < 3:
        continue
    pts = np.array([bm.verts[x].co for x in loop])
    c = pts.mean(0)
    per = float(np.linalg.norm(pts - np.roll(pts, -1, 0), axis=1).sum())
    hole = {"edges": len(loop), "perimeter_m": round(per, 3), "centre": [round(float(x), 3) for x in c]}
    if over_head(c)[0] < 0.001:
        skipped.append(dict(hole, why="head fills it"))
        continue
    ring = np.vstack([pts, c])
    n = np.cross(pts - c, np.roll(pts, -1, 0) - c).sum(0)
    base = sum(len(v) for v in caps["POSITION"])
    caps["POSITION"].append(ring.astype(np.float32))
    caps["NORMAL"].append(np.tile(n / (np.linalg.norm(n) + 1e-12), (len(ring), 1)).astype(np.float32))
    caps["TEXCOORD_0"].append(patch_uv(ring))
    src_v = [kd.find(Vector(p))[1] for p in ring]  # attributes of the helmet vertex nearest each cap corner
    caps["JOINTS_0"].append(arr["JOINTS_0"][src_v])
    caps["WEIGHTS_0"].append(arr["WEIGHTS_0"][src_v])
    m = len(loop)
    cap_idx += [[base + m, base + i, base + (i + 1) % m] for i in range(m)]
    capped.append(hole)
bm.free()

n0 = len(arr["POSITION"])
for k in caps:
    arr[k] = np.concatenate([arr[k]] + [x.astype(arr[k].dtype) for x in caps[k]])
arr["indices"] = np.concatenate([arr["indices"], np.array(cap_idx, np.int64).reshape(-1) + n0])
glb.write_piece(js, bn, out, arr, "helmet", glb.embedded_images(js, bn))

stats = {"source_triangles": int(len(tris)), "shell_triangles": int(keep.sum()), "skin_painted_triangles": int(skin.sum()),
         "cap_triangles": len(cap_idx), "triangles": int(len(arr["indices"]) // 3), "vertices": int(len(arr["POSITION"])),
         "fit": fit, "dark_paint_srgb": [round(float(x), 3) for x in col], "dark_patch_px": round(float(rad * 0.6), 1),
         "caps": capped, "holes_left": skipped, "surfaces": rows}
data = json.load(open(report)) if os.path.exists(report) else {}
data[os.path.basename(os.path.dirname(out))] = stats
json.dump(data, open(report, "w"), indent=1)
# The kit's helmet slot: the head now shows under the helmet, only the hair piece hides (it would poke through).
kit_path = os.path.join(os.path.dirname(out), "kit.json")
if os.path.exists(kit_path):
    kit = json.load(open(kit_path))
    kit["slots"]["helmet"].update({"triangles": stats["triangles"], "hides": ["hair"]})
    kit["provenance"]["helmet_shell"] = "tools/blender/survivor_appearance/shell_helmet.py (see ../helmet_shells.json)"
    json.dump(kit, open(kit_path, "w"), indent=1)
print("SHELL", out, json.dumps({k: v for k, v in stats.items() if k not in ("surfaces", "caps", "holes_left")}),
      [(s["triangles"], s["kept"]) for s in rows], "caps", len(capped), "left", [(s["edges"], s["why"]) for s in skipped])
