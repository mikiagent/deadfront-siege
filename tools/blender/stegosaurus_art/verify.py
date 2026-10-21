# STEGO-ART check: what must not change did not change, and the thagomizer has exactly four spikes.
#   Blender -b --factory-startup --python-exit-code 1 -P verify.py -- <v2.glb> <fixed.glb>
# Exit 1 on any failure.
import os, sys, json, collections
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_io

SRC, DST = sys.argv[sys.argv.index("--") + 1:][:2]
ja, ba = glb_io.read(SRC); jb, bb = glb_io.read(DST)
fails = 0
def check(ok, msg):
    global fails
    print(("PASS  " if ok else "FAIL  ") + msg); fails += 0 if ok else 1

check(ja["nodes"] == jb["nodes"], "nodes (34 joints: names, rest TRS, hierarchy) identical")
check(ja["skins"] == jb["skins"], "skin identical")
ibm = ja["skins"][0]["inverseBindMatrices"]
check(glb_io.view_bytes(ja, ba, ja["accessors"][ibm]["bufferView"]) == glb_io.view_bytes(jb, bb, jb["accessors"][ibm]["bufferView"]),
      "inverse bind matrices byte-identical")
check(ja["materials"] == jb["materials"] and ja["textures"] == jb["textures"] and ja["images"] == jb["images"], "material, textures, image list identical")
mat = ja["materials"][0]
for key, idx in (("normal", mat["normalTexture"]["index"]), ("ORM", mat["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"])):
    v = ja["images"][ja["textures"][idx]["source"]]["bufferView"]
    check(glb_io.view_bytes(ja, ba, v) == glb_io.view_bytes(jb, bb, jb["images"][jb["textures"][idx]["source"]]["bufferView"]),
          f"{key} map byte-identical (roughness unchanged)")
cv = ja["images"][ja["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]]["bufferView"]
check(glb_io.view_bytes(ja, ba, cv) != glb_io.view_bytes(jb, bb, cv), "base colour map regraded")

def arrays(j, b):
    A = j["meshes"][0]["primitives"][0]["attributes"]
    return {k: glb_io.accessor(j, b, A[k]) for k in ("POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0")}, \
        glb_io.accessor(j, b, j["meshes"][0]["primitives"][0]["indices"]).reshape(-1, 3)
A0, I0 = arrays(ja, ba); A1, I1 = arrays(jb, bb)
key = lambda Ar, i: (Ar["POSITION"][i].tobytes(), Ar["TEXCOORD_0"][i].tobytes())
src = {key(A0, i): i for i in range(len(A0["POSITION"]))}
same, new, diff = 0, 0, 0
for i in range(len(A1["POSITION"])):
    k = key(A1, i)
    if k not in src: new += 1; continue
    s = src[k]
    if all(np.array_equal(A0[a][s], A1[a][i]) for a in ("NORMAL", "JOINTS_0", "WEIGHTS_0")): same += 1
    else: diff += 1
check(diff == 0, f"kept vertices: {same} with position, UV, normal, joints, weights byte-identical; {diff} changed; {new} new cap vertices")
kept_tris = {tuple(sorted((A0['POSITION'][v].tobytes() for v in t))) for t in I0}
is_new = np.array([key(A1, i) not in src for i in range(len(A1["POSITION"]))])
unchanged = np.array([tuple(sorted((A1['POSITION'][v].tobytes() for v in t))) in kept_tris for t in I1])
check((unchanged | is_new[I1].any(1)).all(), f"triangles: {len(I0)} -> {len(I1)}: {unchanged.sum()} unchanged from v2, "
      f"{(~unchanged).sum()} cap triangles (each uses a new cap vertex), {len(I0) - unchanged.sum()} v2 triangles removed")

# geometry: closed, one piece, four spike shafts beyond 0.6 m from the tail axis, two per side, pointing up
P = A1["POSITION"].astype(np.float64)
_, w = np.unique(np.round(P / 1e-5).astype(np.int64), axis=0, return_inverse=True); w = w.ravel()
T = w[I1]
E = np.sort(np.concatenate([T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]]), 1)
check(set(np.unique(E, axis=0, return_counts=True)[1].tolist()) == {2}, "mesh closed (every edge shared by two triangles): no holes")
par = np.arange(w.max() + 1)
def find(x):
    while par[x] != x:
        par[x] = par[par[x]]; x = par[x]
    return x
def union(tris):
    for a, b_, c in tris:
        for u, v in ((a, b_), (b_, c)):
            ru, rv = find(u), find(v)
            if ru != rv: par[ru] = rv
union(T)
check(len({find(t[0]) for t in T}) == 1, "one connected piece: no floating fragments")
PW = np.zeros((w.max() + 1, 3)); PW[w] = P
# tail axis: tail_05 joint in model space (computed as in fix_thagomizer.py via the node chain)
from mathutils import Matrix, Quaternion
parent = {c: i for i, n in enumerate(jb["nodes"]) for c in n.get("children", [])}
def M(i):
    n = jb["nodes"][i]; t = n.get("translation", [0, 0, 0]); r = n.get("rotation", [0, 0, 0, 1]); s = n.get("scale", [1, 1, 1])
    m = Matrix.Translation(t) @ Quaternion((r[3], r[0], r[1], r[2])).to_matrix().to_4x4() @ Matrix.Diagonal((*s, 1))
    return M(parent[i]) @ m if i in parent else m
m5 = M(next(i for i, n in enumerate(jb["nodes"]) if n["name"] == "tail_05")); T0 = np.array(m5.translation); TD = np.array(m5.to_3x3().col[1]).ravel(); TD /= np.linalg.norm(TD)
r = np.linalg.norm((PW - T0) - np.outer((PW - T0) @ TD, TD), axis=1)
fm = (r[T].min(1) > 0.6) & (((PW[T] - T0) @ TD).min(1) > -0.5)
par = np.arange(w.max() + 1); union(T[fm])
roots = collections.defaultdict(list)
for t in T[fm]: roots[find(t[0])].append(t)
tips = []
for ts in roots.values():
    vs = np.unique(np.array(ts)); tip = PW[vs[np.argmax(r[vs])]]; tips.append(tip)
sides = collections.Counter("L" if t[0] < 0 else "R" for t in tips)
check(len(tips) == 4 and sides == {"L": 2, "R": 2} and all(t[1] > T0[1] + 0.3 for t in tips) and all((t - T0) @ TD > 0.5 for t in tips),
      f"thagomizer: {len(tips)} spikes beyond 0.6 m (L {sides['L']}, R {sides['R']}), tips " +
      ", ".join(f"({t[0]:+.2f}, {t[1]:.2f}, {t[2]:.2f})" for t in sorted(tips, key=lambda t: t[0])) + " all up and back")
lo, hi = P.min(0), P.max(0)
check(abs(lo[1]) < 1e-4 and abs(hi[1] - 6.4) < 1e-3, f"bounds {lo.round(3).tolist()} .. {hi.round(3).tolist()} (feet at 0, plates at 6.4 m)")
print(f"{'ALL CHECKS PASSED' if fails == 0 else f'{fails} CHECK(S) FAILED'}")
sys.exit(1 if fails else 0)
