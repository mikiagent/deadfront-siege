# STEGO-ART step 1: the thagomizer keeps FOUR spikes (two pairs, up and back); the other four are cut off flush
# with the tail knob and each hole is closed with a cap that follows the knob.
#   Blender -b --factory-startup -P fix_thagomizer.py -- <in.glb> <out.glb> [--no-cap]
# Works on the glTF arrays (glb_io) so every kept vertex keeps its position, normal, UV, joints and weights
# byte-for-byte and the skeleton, skin and inverse bind matrices are copied untouched. Cap vertices are new:
# joints/weights copied from the nearest hole-edge vertex (the cut stays on tail_04..07, asserted), UVs laid on
# plain tail skin at that skin's own texel density.
import os, sys, collections
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_io

args = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = args[0], args[1]
NO_CAP = "--no-cap" in args

R_SPIKE = 0.40    # beyond this distance from the tail axis only spike shafts exist (8 separate shells)
# Tail core (what stays of the knob): a capsule of radius R_CORE along the tail axis up to CORE_MID, then tapering
# to R_END while its axis lifts by LIFT_END at CORE_END, because the knob's underside rises to the tip (measured
# straight down from the axis: 0.15 m at -0.3, 0.08 at 0, 0.04 at +0.2 m along the tail from the tail_05 joint;
# sideways 0.11-0.14 m at +0.2).
R_CORE, R_END = 0.21, 0.12
CORE_MID, CORE_END, LIFT_END = -0.30, 0.30, 0.10
MARGIN = 0.05     # surface within this of the core capsule is tail, not spike (tail skin reaches 0.24-0.26)
R_KEEP = 0.10     # a kept spike keeps its shaft (radius 0.08-0.12 at the base; the webs to cut spikes reach beyond)
ZONE = -0.45      # nothing ahead of this (metres along the tail from the tail_05 joint) is cut
GROW = 2          # extra vertex rings cut round each hole over knob that stands proud of the core
RINGS = 4         # cap rings between the hole edge and the centre

j, b = glb_io.read(SRC)
prim = j["meshes"][0]["primitives"][0]
A = prim["attributes"]
P = glb_io.accessor(j, b, A["POSITION"])
N = glb_io.accessor(j, b, A["NORMAL"])
UV = glb_io.accessor(j, b, A["TEXCOORD_0"])
JN = glb_io.accessor(j, b, A["JOINTS_0"])
WT = glb_io.accessor(j, b, A["WEIGHTS_0"])
I = glb_io.accessor(j, b, prim["indices"]).reshape(-1, 3).astype(np.int64)
names = [j["nodes"][n]["name"] for n in j["skins"][0]["joints"]]

# Weld split (UV seam) vertices by position: topology lives on welded ids, attributes on glTF ids.
_, wid = np.unique(np.round(P / 1e-5).astype(np.int64), axis=0, return_inverse=True)
wid = wid.ravel(); nW = wid.max() + 1
PW = np.zeros((nW, 3)); PW[wid] = P
IW = wid[I]
def edge_counts(T):
    E = np.sort(np.concatenate([T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]]), 1)
    return np.unique(E, axis=0, return_counts=True)[1]
assert (edge_counts(IW) == 2).all(), "source mesh is expected to be closed"

# Tail axis from the tail_05 joint (rest pose): head position and +Y direction in model space.
def node_world(name):
    from mathutils import Matrix, Quaternion
    parent = {c: i for i, n in enumerate(j["nodes"]) for c in n.get("children", [])}
    def M(i):
        n = j["nodes"][i]; t = n.get("translation", [0, 0, 0]); r = n.get("rotation", [0, 0, 0, 1]); s = n.get("scale", [1, 1, 1])
        m = Matrix.Translation(t) @ Quaternion((r[3], r[0], r[1], r[2])).to_matrix().to_4x4() @ Matrix.Diagonal((*s, 1))
        return M(parent[i]) @ m if i in parent else m
    m = M(next(i for i, n in enumerate(j["nodes"]) if n.get("name") == name))
    d = np.array(m.to_3x3().col[1]).ravel()
    return np.array(m.translation), d / np.linalg.norm(d)
T0, TD = node_world("tail_05")
def dist_seg(X, a, bb):
    d = bb - a; t = np.clip(((X - a) @ d) / (d @ d), 0, 1)
    return np.linalg.norm(X - (a + np.outer(t, d)), axis=1), a + np.outer(t, d)
CORE_A, CORE_B = T0 - TD * 1.5, T0 + TD * CORE_END   # straight tail axis segment (cap frames, outward checks)
UPV = np.array([0.0, 1.0, 0.0]) - TD[1] * TD; UPV /= np.linalg.norm(UPV)
CORE_SEGS = [(T0 - TD * 1.5, T0 + TD * CORE_MID, R_CORE, R_CORE),
             (T0 + TD * CORE_MID, T0 + TD * CORE_END + UPV * LIFT_END, R_CORE, R_END)]
def core_sdf(X):
    out = []
    for a, bb, ra, rb in CORE_SEGS:
        d = bb - a; t = np.clip(((X - a) @ d) / (d @ d), 0, 1)
        out.append(np.linalg.norm(X - (a + np.outer(t, d)), axis=1) - (ra + t * (rb - ra)))
    return np.min(out, 0)
r_tail = np.linalg.norm((PW - T0) - np.outer((PW - T0) @ TD, TD), axis=1)
d_core = core_sdf(PW)

# Spike shells: faces wholly beyond R_SPIKE (and not ahead of the knob) form one component per spike.
fm = (r_tail[IW].min(1) > R_SPIKE) & (((PW[IW] - T0) @ TD).min(1) > -0.5)
par = np.arange(nW)
def find(x):
    while par[x] != x:
        par[x] = par[par[x]]; x = par[x]
    return x
for a, c, d in IW[fm]:
    for u, v in ((a, c), (c, d)):
        ru, rv = find(u), find(v)
        if ru != rv: par[ru] = rv
roots = np.array([find(t[0]) for t in IW[fm]])
spikes = []
for root in sorted(set(roots.tolist())):
    vs = np.unique(IW[fm][roots == root]); X = PW[vs]
    c = X.mean(0); ax = np.linalg.svd(X - c)[2][0]
    tip = X[np.argmax(r_tail[vs])]
    if (tip - c) @ ax < 0: ax = -ax
    # root: where the spike axis passes closest to the tail axis
    w0 = c - T0; bq = ax @ TD; s = (bq * (w0 @ TD) - (w0 @ ax)) / (1 - bq * bq)
    spikes.append(dict(seed=vs, c=c, ax=ax, tip=tip, root=c + s * ax, up=float(ax[1]), side="L" if c[0] < 0 else "R"))
assert len(spikes) == 8, f"expected 8 spike shells, found {len(spikes)}"
order = sorted(range(8), key=lambda i: -spikes[i]["up"])
for k, i in enumerate(order): spikes[i]["keep"] = k < 4
kept = [i for i in range(8) if spikes[i]["keep"]]
assert collections.Counter(spikes[i]["side"] for i in kept) == {"L": 2, "R": 2}, "kept spikes must be two pairs"
assert all(spikes[i]["up"] > 0.3 for i in kept) and all(spikes[i]["up"] < 0.1 for i in order[4:]), "up/down split unclear"

# Ownership: outside the tail core (MARGIN beyond the capsule, behind ZONE) every vertex goes to the spike whose
# shell is nearest along the surface (multi-source Dijkstra over mesh edges), so a spike's base and the webs
# and slivers hanging off it go with it. Surface not connected to any shell outside the core (the last little
# tail plate on top of the knob) stays.
import heapq
z_rel = (PW - T0) @ TD
outside = (d_core > MARGIN) & (z_rel > ZONE)
adj = [[] for _ in range(nW)]
for a, c, d in IW:
    for u, v in ((a, c), (c, d), (d, a)):
        adj[u].append(v); adj[v].append(u)
label = np.full(nW, -1); dist = np.full(nW, np.inf); heap = []
for i, s in enumerate(spikes):
    for v in s["seed"]:
        dist[v] = 0.0; label[v] = i; heapq.heappush(heap, (0.0, int(v), i))
while heap:
    dv, v, i = heapq.heappop(heap)
    if dv > dist[v]: continue
    for w in adj[v]:
        if not outside[w]: continue
        nd = dv + float(np.linalg.norm(PW[w] - PW[v]))
        if nd < dist[w]:
            dist[w] = nd; label[w] = i; heapq.heappush(heap, (nd, w, i))
# a kept spike's own shaft is never cut, even where a cut neighbour's region reaches round its base
D_keep = np.stack([dist_seg(PW, spikes[i]["root"], spikes[i]["tip"])[0] for i in kept], 1).min(1)
cut_v = (label >= 0) & ~np.isin(label, kept) & (D_keep > R_KEEP)
# Grow each hole by up to GROW rings over whatever of the knob still stands proud of the core (d_core > 0),
# so flaps of old spike base just inside MARGIN go too and the caps start from clean knob skin. Never into a
# kept spike (its shaft or its own region) or ahead of ZONE, and never so that two holes come within two rings of each other (they would
# merge into one hole wrapping round the tail end, which no cap can close cleanly).
comp = np.full(nW, -1)
for v0 in np.where(cut_v)[0]:
    if comp[v0] >= 0: continue
    q = [v0]; comp[v0] = v0
    while q:
        v = q.pop()
        for w in adj[v]:
            if cut_v[w] and comp[w] < 0: comp[w] = v0; q.append(w)
for _ in range(GROW):
    front = [v for v in range(nW) if not cut_v[v] and d_core[v] > 0 and D_keep[v] > R_KEEP and z_rel[v] > ZONE
             and label[v] not in kept
             and any(cut_v[w] for w in adj[v])]
    for v in front:
        near2 = {u for w in adj[v] for u in adj[w]} | set(adj[v])
        labs = {comp[u] for u in near2 if cut_v[u]}
        if len(labs) == 1:
            cut_v[v] = True; comp[v] = labs.pop()
removed_f = cut_v[IW].any(1)   # any: a sliver with one corner out on a cut spike goes too; the hole edge is core

# Make every hole a clean disc: fill notches (a kept face with 2+ removed edge-neighbours) and pinches (a vertex
# where the removed region touches itself), until each boundary vertex has exactly one boundary edge out.
ef = collections.defaultdict(list)
vf = [[] for _ in range(nW)]
for t_i, (a, c, d) in enumerate(IW):
    for u, v in ((a, c), (c, d), (d, a)): ef[(min(u, v), max(u, v))].append(t_i)
    for w in (a, c, d): vf[w].append(t_i)
def other(t_i, u, v): return next(f for f in ef[(min(u, v), max(u, v))] if f != t_i)
for _ in range(50):
    changed = False
    for t_i in np.where(~removed_f)[0]:
        a, c, d = IW[t_i]
        if sum(removed_f[other(t_i, *e)] for e in ((a, c), (c, d), (d, a))) >= 2:
            removed_f[t_i] = True; changed = True
    out = collections.Counter()
    for t_i in np.where(~removed_f)[0]:
        a, c, d = IW[t_i]
        for u, v in ((a, c), (c, d), (d, a)):
            if removed_f[other(t_i, u, v)]: out[v] += 1
    for w, k in out.items():
        if k > 1:
            for f in vf[w]: removed_f[f] = True
            changed = True
    if not changed: break
tail_joints = [names.index(n) for n in ("tail_04", "tail_05", "tail_06", "tail_07")]
gcut = np.unique(I[removed_f])
assert np.isin(JN[gcut, WT[gcut].argmax(1)], tail_joints).all() and (z_rel[IW[removed_f]] > ZONE).all(), \
    "the cut reached beyond the thagomizer"

# Boundary loops, in the cap's winding: a kept face's half-edge (u,v) whose twin is removed -> cap edge v->u.
nxt = {}
for t_i in np.where(~removed_f)[0]:
    a, c, d = IW[t_i]
    for u, v in ((a, c), (c, d), (d, a)):
        if removed_f[other(t_i, u, v)]:
            assert v not in nxt; nxt[v] = u
loops, seen = [], set()
for s0 in list(nxt):
    if s0 in seen: continue
    loop = [s0]; seen.add(s0); x = nxt[s0]
    while x != s0:
        loop.append(x); seen.add(x); x = nxt[x]
    loops.append(loop)
print("[thagomizer] spikes: " + "; ".join(f"{s['side']} up={s['up']:+.2f} {'KEEP' if s['keep'] else 'cut'}" for s in spikes))
print(f"[thagomizer] faces removed {removed_f.sum()} of {len(IW)}; holes {len(loops)} (edge verts {[len(l) for l in loops]})")

keep_tris = I[~removed_f]
newP, newN, newUV, newJ, newW, new_tris = [], [], [], [], [], []
n0 = len(P)
if not NO_CAP:
    g_of_w = {}
    for t, tw in zip(keep_tris, IW[~removed_f]):
        for g, w in zip(t, tw): g_of_w.setdefault(w, g)
    # UV donor: the largest UV island of plain tail skin just ahead of the thagomizer; caps are laid on it at
    # that island's own texel density, centred on its middle triangle (same skin texture as the knob).
    upar = np.arange(len(P))
    def ufind(x):
        while upar[x] != x:
            upar[x] = upar[upar[x]]; x = upar[x]
        return x
    for a, c, d in I:
        for u, v in ((a, c), (c, d)):
            ru, rv = ufind(u), ufind(v)
            if ru != rv: upar[ru] = rv
    tri_island = np.array([ufind(t[0]) for t in I])
    zt = ((PW[IW].mean(1) - T0) @ TD)
    cand = np.where((zt > -1.2) & (zt < ZONE) & (r_tail[IW].max(1) < 0.3))[0]
    donor_island = collections.Counter(tri_island[cand].tolist()).most_common(1)[0][0]
    isl = np.where(tri_island == donor_island)[0]
    X3 = P[I[isl]].astype(np.float64); U2 = UV[I[isl]].astype(np.float64)
    a3 = np.linalg.norm(np.cross(X3[:, 1] - X3[:, 0], X3[:, 2] - X3[:, 0]), axis=1).sum() / 2
    e1, e2 = U2[:, 1] - U2[:, 0], U2[:, 2] - U2[:, 0]
    a2 = np.abs(e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0]).sum() / 2
    dens = (a2 / a3) ** 0.5
    uv_c = U2[np.argmin(np.linalg.norm(U2.mean(1) - U2.reshape(-1, 2).mean(0), axis=1))].mean(0)
    print(f"[thagomizer] cap UV donor island: {len(isl)} tris, {dens:.4f} uv/m, centre {uv_c.round(4).tolist()}")

    # Each hole is closed by rings of new vertices from its edge to a centre vertex, started on straight lines
    # to the centroid and relaxed into a smooth membrane (Laplacian, edge fixed); where the membrane cuts into
    # the knob it is pushed back out onto the core surface, so the cap reads as rounded skin, never as a dent
    # and never hanging below the tail (it is only ever pushed out to the core, not beyond).
    cap_edge_counts = []
    for loop in loops:
        L = np.array(loop); X = PW[L]; c = X.mean(0); nb = len(L)
        g_b = [g_of_w[w] for w in loop]
        vid = lambda k, m: k * nb + (m % nb)
        ic = (RINGS + 1) * nb
        V = np.concatenate([X + (c - X) * (k / (RINGS + 1)) for k in range(RINGS + 1)] + [c[None]])
        frac = np.array([k / (RINGS + 1) for k in range(RINGS + 1) for _ in range(nb)] + [1.0])
        lt = []
        for k in range(RINGS):
            for m in range(nb):
                lt += [(vid(k, m), vid(k, m + 1), vid(k + 1, m + 1)), (vid(k, m), vid(k + 1, m + 1), vid(k + 1, m))]
        lt += [(vid(RINGS, m), vid(RINGS, m + 1), ic) for m in range(nb)]
        nbr = [set() for _ in range(len(V))]
        for t in lt:
            for x in t: nbr[x].update(t)
        nbr = [sorted(n_ - {i}) for i, n_ in enumerate(nbr)]
        for _ in range(400):
            V[nb:] = np.array([V[n_].mean(0) for n_ in nbr[nb:]])
        # Push out: alternate a half relaxation step with pushing every inner point that lies inside the knob
        # (closer than 0.01 m to the core) back out along the core's gradient, easing in from the edge.
        ease = (1 - (1 - frac) ** 2)
        lift = 0.0
        for _ in range(80):
            V[nb:] = 0.5 * V[nb:] + 0.5 * np.array([V[n_].mean(0) for n_ in nbr[nb:]])
            f0 = core_sdf(V)
            g = np.stack([(core_sdf(V + 1e-4 * e) - f0) / 1e-4 for e in np.eye(3)], 1)
            g /= np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-9)
            push = np.clip(0.01 - f0, 0, None) * ease
            V[nb:] += (g * push[:, None])[nb:]
            lift = max(lift, float(push.max()))
        u = (V[ic] - T0) - ((V[ic] - T0) @ TD) * TD; u /= np.linalg.norm(u)
        # UVs: planar map on the donor skin, in the cap's own tangent plane
        dc = (V[ic] - c); dc = dc / np.linalg.norm(dc) if np.linalg.norm(dc) > 1e-6 else u
        t1 = np.cross(dc, TD); t1 /= np.linalg.norm(t1); t2 = np.cross(dc, t1)
        src = g_b * (RINGS + 1) + [g_b[int(np.argmin(np.linalg.norm(X - V[ic], axis=1)))]]
        start = n0 + len(newP)
        for i, x_ in enumerate(V):
            newP.append(x_); newUV.append(uv_c + np.array([(x_ - V[ic]) @ t1, (x_ - V[ic]) @ t2]) * dens)
            newJ.append(JN[src[i]]); newW.append(WT[src[i]]); newN.append(N[src[i]].astype(np.float64))
        new_tris += [(start + t[0], start + t[1], start + t[2]) for t in lt]
        cap_edge_counts.append((nb, len(V)))
        rt = lambda Y: np.linalg.norm((Y - T0) - np.outer((Y - T0) @ TD, TD), axis=1)
        print(f"[thagomizer] cap: {nb} edge verts, hole radius {np.linalg.norm(X - c, axis=1).mean():.2f} m, "
              f"{((X - T0) @ TD).min():+.2f}..{((X - T0) @ TD).max():+.2f} m along the tail, largest push-out step {lift:.3f} m")
    # Inner cap normals from the cap faces; the edge ring keeps the skin's own normals (no shading seam).
    NP = np.array(newP); NT = np.array(new_tris) - n0
    fn = np.cross(NP[NT[:, 1]] - NP[NT[:, 0]], NP[NT[:, 2]] - NP[NT[:, 0]])
    acc = np.zeros_like(NP)
    for k in range(3): np.add.at(acc, NT[:, k], fn)
    acc /= np.linalg.norm(acc, axis=1, keepdims=True)
    edge = np.zeros(len(NP), bool); o = 0
    for nb, nv in cap_edge_counts:
        edge[o:o + nb] = True; o += nv
    NN = np.array(newN); NN[~edge] = acc[~edge]
    # the caps must face outwards (along the core's gradient), not fold over themselves
    grad = np.stack([(core_sdf(NP + 1e-4 * e) - core_sdf(NP)) / 1e-4 for e in np.eye(3)], 1)
    outward = (np.einsum("ij,ij->i", acc, grad) > 0).mean()
    print(f"[thagomizer] cap vertex normals facing out: {outward:.1%}")
    assert outward > 0.9, "cap faces inwards or folds"   # 0.9: where a cap runs onto a spike flank the core gradient is only roughly its normal
    newN = list(NN)

# Assemble: kept triangles + cap triangles, then drop vertices nothing references (compact, order kept).
allP = np.concatenate([P, np.array(newP, np.float32).reshape(-1, 3)])
allN = np.concatenate([N, np.array(newN, np.float32).reshape(-1, 3)])
allUV = np.concatenate([UV, np.array(newUV, np.float32).reshape(-1, 2)])
allJ = np.concatenate([JN, np.array(newJ, JN.dtype).reshape(-1, 4)])
allW = np.concatenate([WT, np.array(newW, WT.dtype).reshape(-1, 4)])
tris = np.concatenate([keep_tris, np.array(new_tris, np.int64).reshape(-1, 3)])
used = np.zeros(len(allP), bool); used[tris.ravel()] = True
tris = (np.cumsum(used) - 1)[tris]
allP, allN, allUV, allJ, allW = allP[used], allN[used], allUV[used], allJ[used], allW[used]
print(f"[thagomizer] verts {len(P)} -> {len(allP)} (cap verts {len(newP)}), tris {len(I)} -> {len(tris)}")

# Result checks: closed (every welded edge used twice), one connected piece, four spike shafts beyond 0.6 m.
_, w2 = np.unique(np.round(allP / 1e-5).astype(np.int64), axis=0, return_inverse=True)
T2 = w2.ravel()[tris]
ec = collections.Counter(edge_counts(T2).tolist())
par = np.arange(w2.max() + 1)
for a, c, d in T2:
    for u, v in ((a, c), (c, d)):
        ru, rv = find(u), find(v)
        if ru != rv: par[ru] = rv
pieces = len({find(t[0]) for t in T2})
P2 = np.zeros((w2.max() + 1, 3)); P2[w2.ravel()] = allP
r2 = np.linalg.norm((P2 - T0) - np.outer((P2 - T0) @ TD, TD), axis=1)
f2 = (r2[T2].min(1) > 0.6) & (((P2[T2] - T0) @ TD).min(1) > -0.5)
par = np.arange(len(P2))
for a, c, d in T2[f2]:
    for u, v in ((a, c), (c, d)):
        ru, rv = find(u), find(v)
        if ru != rv: par[ru] = rv
shells = len({find(t[0]) for t in T2[f2]})
print(f"[thagomizer] result: edge use {dict(ec)}, connected pieces {pieces}, spike shells {shells}")
if not NO_CAP:
    assert set(ec) == {2} and pieces == 1 and shells == 4, "result must be closed, one piece, four spikes"

views = [glb_io.view_bytes(j, b, i) for i in range(len(j["bufferViews"]))]
def put(acc_i, arr):
    a = j["accessors"][acc_i]
    assert a.get("byteOffset", 0) == 0 and "byteStride" not in j["bufferViews"][a["bufferView"]]
    assert sum(x["bufferView"] == a["bufferView"] for x in j["accessors"]) == 1, "shared bufferView"
    arr = np.ascontiguousarray(arr.astype(glb_io.COMP[a["componentType"]]))
    a["count"] = int(arr.shape[0])
    if "min" in a: a["min"] = arr.reshape(a["count"], -1).min(0).tolist()
    if "max" in a: a["max"] = arr.reshape(a["count"], -1).max(0).tolist()
    views[a["bufferView"]] = arr.tobytes()
assert len(allP) <= 65535 or j["accessors"][prim["indices"]]["componentType"] == 5125
put(A["POSITION"], allP); put(A["NORMAL"], allN); put(A["TEXCOORD_0"], allUV)
put(A["JOINTS_0"], allJ); put(A["WEIGHTS_0"], allW)
put(prim["indices"], tris.ravel())
glb_io.write(DST, j, views)
print(f"[thagomizer] wrote {DST}")
