"""RHINOHOLE: close the holes left in the woolly rhino's exported hide, editing the .glb in place.
  Blender -b -P tools/gait/woolly_rhino/patch_holes.py -- <in.glb> <out.glb>
The glb is edited as bytes (no Blender import/export: a glTF round trip through Blender re-orients the bones, and
the 16 clips key them in local space). Only the hide primitive grows: new triangles over every closed hole, on
new vertices that copy the rim vertex's position and skin weights (so the patch deforms exactly with its rim) and
take a UV fitted from the neighbouring fur (so the texture carries on across the patch). Bones, skin, clips and
images are untouched.
Holes between the left and right legs stay open: build_rig cuts that webbing on purpose (it tore when legs swung).
"""
import bmesh, json, struct, sys
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
src, dst = a[0], a[1]
CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}

def patch(raw):
    """One pass over the glb bytes: the patched bytes, or None when no hole is left to fill."""
    jlen = struct.unpack("<I", raw[12:16])[0]
    J = json.loads(raw[20:20 + jlen])
    bin0 = 20 + jlen + 8
    BIN = raw[bin0:bin0 + struct.unpack("<I", raw[20 + jlen:24 + jlen])[0]]

    def read(i):
        acc = J["accessors"][i]; bv = J["bufferViews"][acc["bufferView"]]
        assert "byteStride" not in bv, "interleaved buffers not handled"
        off = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
        return np.frombuffer(BIN, CT[acc["componentType"]], acc["count"] * NC[acc["type"]], off).reshape(acc["count"], -1).copy()

    prim = J["meshes"][0]["primitives"][0]
    att = prim["attributes"]
    P, N, UV, JT, W = (read(att[k]) for k in ("POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"))
    T = read(prim["indices"]).reshape(-1, 3).astype(np.int64)
    joints = [J["nodes"][j]["name"] for j in J["skins"][0]["joints"]]

    # weld the glTF split vertices (UV seams) by position into one manifold-ish surface
    key = np.round(P / 1e-5).astype(np.int64)
    _, weld, = np.unique(key, axis=0, return_inverse=True)[:2]
    weld = weld.ravel()
    nw = weld.max() + 1
    rep = np.zeros(nw, np.int64); rep[weld] = np.arange(len(P))  # one glb vertex per welded vertex
    wn = np.zeros((nw, 3)); np.add.at(wn, weld, N)
    wn /= np.maximum(np.linalg.norm(wn, axis=1, keepdims=True), 1e-9)

    # UV islands: triangles joined through shared glb vertices (seams split vertices, so islands do not touch)
    par = np.arange(len(P))
    def find(x):
        while par[x] != x: par[x] = par[par[x]]; x = par[x]
        return x
    for t in T:
        r = [find(x) for x in t]
        for x in r[1:]: par[x] = r[0]
    island = np.array([find(x) for x in range(len(P))])

    bm = bmesh.new()
    for i in range(nw): bm.verts.new(P[rep[i]])
    bm.verts.ensure_lookup_table(); bm.verts.index_update()  # new BMVerts carry index -1 until this
    orig = {}
    for ti, t in enumerate(T):
        vs = [bm.verts[weld[x]] for x in t]
        if len(set(vs)) < 3: continue
        try: orig[bm.faces.new(vs)] = ti
        except ValueError: pass  # duplicate face (fur fin glued on twice): skip
    bm.faces.ensure_lookup_table()
    holes = [e for e in bm.edges if e.is_boundary]
    print("open edges before", len(holes))
    # leg side of a welded vertex = side of its strongest joint if that joint is a leg bone
    dom = [joints[JT[rep[i], np.argmax(W[rep[i]])]] for i in range(nw)]
    side = [("L" if n.endswith(".L") else "R") if any(k in n for k in ("Front", "Hind", "Foot")) and "Scapula" not in n
            else "" for n in dom]  # the scapulas ride on top of the hump: not legs here
    belly = 0.45 * P[:, 1].max()  # glTF is Y-up; the webbing build_rig cuts hangs below the belly line

    extra = {}  # centre vertices made here: position, normal, joints, weights (blended from the rim)

    def skin(v): return extra[v][2:] if v in extra else (JT[rep[v.index]], W[rep[v.index]])
    def nrm(v): return extra[v][1] if v in extra else wn[v.index]

    def fan(comp, vs):
        c = np.mean([v.co[:] for v in vs], 0); n = sum(nrm(v) for v in vs); n /= max(np.linalg.norm(n), 1e-9)
        acc = {}
        for v in vs:
            for j, w in zip(*skin(v)): acc[int(j)] = acc.get(int(j), 0.0) + float(w)
        top = sorted(acc.items(), key=lambda kv: -kv[1])[:4] + [(0, 0.0)] * 4
        jw = np.array([w for _, w in top[:4]]); jw /= jw.sum()
        cv = bm.verts.new(c); bm.verts.index_update(); extra[cv] = (c, n, [j for j, _ in top[:4]], jw)
        for e in comp:
            try: new.append(bm.faces.new([e.verts[0], e.verts[1], cv]))
            except ValueError: pass

    # a hole rim = a closed loop of open edges, or an open chain whose two ends meet through a few closed edges
    # (Tripo glued a fur fin across the rim there; holes_fill skips both kinds, so walk the rim and make the face)
    new = []
    while True:  # filling one rim can turn a neighbouring tangle into a simple rim: repeat until none
        rim = {e for e in bm.edges if e.is_boundary}
        n0 = len(new); seen = set()
        for e0 in list(rim):
            if e0 in seen: continue
            comp, st = {e0}, [e0]
            while st:
                for v in st.pop().verts:
                    for y in v.link_edges:
                        if y in rim and y not in comp: comp.add(y); st.append(y)
            seen |= comp
            vs = {v for e in comp for v in e.verts}
            deg = {v: sum(x in comp for x in v.link_edges) for v in vs}
            ends = [v for v in vs if deg[v] == 1]
            if len({side[v.index] for v in vs if v not in extra} - {""}) > 1 and np.mean([v.co.y for v in vs]) < belly:
                continue  # webbing between the left and right legs stays cut
            if any(d > 2 for d in deg.values()) or len(ends) not in (0, 2):
                if len(comp) >= 5: fan(comp, vs)  # a tangle of rims around fur fins: fan every open edge to a centre
                continue
            start = ends[0] if ends else e0.verts[0]
            ring, prev = [start], None
            while True:
                prev = next((x for x in ring[-1].link_edges if x in comp and x is not prev), None)
                if prev is None or prev.other_vert(ring[-1]) is start: break
                ring.append(prev.other_vert(ring[-1]))
            if ends:  # close the chain: shortest path of at most 6 closed edges from its last vertex back to its first
                paths, back = {ring[-1]: [ring[-1]]}, None
                for _ in range(6):
                    for v, pth in list(paths.items()):
                        for x in v.link_edges:
                            w = x.other_vert(v)
                            if w is start: back = pth; break
                            if w not in vs and w not in paths: paths[w] = pth + [w]
                        if back: break
                    if back: break
                if not back:
                    if len(comp) >= 5: fan(comp, vs)
                    continue
                ring += back[1:]
            if len(ring) < 3: continue
            try: new.append(bm.faces.new(ring))
            except ValueError: pass
        if len(new) == n0: break
    tri = bmesh.ops.triangulate(bm, faces=new, quad_method="BEAUTY", ngon_method="BEAUTY")["faces"]

    # patches = connected groups of new triangles
    left = set(tri); patches = []
    while left:
        f = left.pop(); comp = [f]; st = [f]
        while st:
            x = st.pop()
            for e in x.edges:
                for g in e.link_faces:
                    if g in left: left.remove(g); comp.append(g); st.append(g)
        patches.append(comp)

    have = {frozenset(weld[t]) for t in T}
    addP, addN, addUV, addJ, addW, addT = [], [], [], [], [], []
    nxt = len(P)
    for comp in patches:
        vs = {v for f in comp for v in f.verts}
        ring = {g for v in vs for g in v.link_faces if g in orig}
        for _ in range(2):  # grow the neighbourhood two rings
            ring |= {h for g in list(ring) for v in g.verts for h in v.link_faces if h in orig}
        if not ring: continue
        # the dominant fur island around the patch, by area
        area = {}
        for g in ring:
            isl = island[T[orig[g]][0]]; area[isl] = area.get(isl, 0.0) + g.calc_area()
        isl = max(area, key=area.get)
        corners = np.unique([c for g in ring if island[T[orig[g]][0]] == isl for c in T[orig[g]]])
        # each patch corner takes the UV of the nearest hide vertex in that island: the patch samples only fur that
        # surrounds it (a plane fit extrapolated past the island's edge and pulled in tan horn texture)
        def uv_at(pos): return UV[corners[np.argmin(((P[corners] - pos) ** 2).sum(1))]]
        vmap = {}
        for v in vs:
            pos, vn, jj, ww = extra[v] if v in extra else (P[rep[v.index]], wn[v.index], JT[rep[v.index]], W[rep[v.index]])
            vmap[v] = nxt + len(addP)
            addP.append(pos); addN.append(vn); addUV.append(uv_at(pos)); addJ.append(jj); addW.append(ww)
        for f in comp:
            if frozenset(v.index for v in f.verts) in have and not any(v in extra for v in f.verts): continue  # Tripo already has it (a doubled fin face)
            ids = [vmap[v] for v in f.verts]
            q = [np.asarray(f.verts[k].co) for k in range(3)]
            fn = np.cross(q[1] - q[0], q[2] - q[0])
            if fn @ sum(nrm(v) for v in f.verts) < 0: ids = ids[::-1]  # face the same way as the hide around it
            addT.append(ids)
    print("patches", len(patches), "triangles", len(addT), "new vertices", len(addP))
    bm.free()
    if not addT: return None

    def cat(old, add, dt): return np.concatenate([old, np.array(add, dt).reshape(-1, old.shape[1])]).astype(dt)
    data = {att["POSITION"]: cat(P, addP, np.float32), att["NORMAL"]: cat(N, addN, np.float32),
            att["TEXCOORD_0"]: cat(UV, addUV, np.float32), att["JOINTS_0"]: cat(JT, addJ, JT.dtype),
            att["WEIGHTS_0"]: cat(W, addW, np.float32)}
    idx = np.concatenate([T.ravel(), np.array(addT).ravel()])
    assert idx.max() < 65536 or J["accessors"][prim["indices"]]["componentType"] == 5125
    data[prim["indices"]] = idx.astype(CT[J["accessors"][prim["indices"]]["componentType"]])
    for i, arr in data.items():
        acc = J["accessors"][i]; acc["count"] = int(arr.shape[0]) if arr.ndim > 1 else int(arr.size)
        if "min" in acc: acc["min"] = arr.min(0).tolist(); acc["max"] = arr.max(0).tolist()
    by_view = {J["accessors"][i]["bufferView"]: arr for i, arr in data.items()}
    out = bytearray()
    for vi, bv in enumerate(J["bufferViews"]):
        chunk = by_view[vi].tobytes() if vi in by_view else BIN[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        out += b"\0" * (-len(out) % 4)
        bv["byteOffset"] = len(out); bv["byteLength"] = len(chunk); out += chunk
    out += b"\0" * (-len(out) % 4)
    J["buffers"][0]["byteLength"] = len(out)
    js = json.dumps(J, separators=(",", ":")).encode(); js += b" " * (-len(js) % 4)
    glb = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(out)) + struct.pack("<II", len(js), 0x4E4F534A) + js \
        + struct.pack("<II", len(out), 0x004E4942) + bytes(out)
    return glb

raw = open(src, "rb").read()
for it in range(6):  # a filled rim can leave a smaller simple hole beside a fur fin: repeat until nothing is left
    out = patch(raw)
    if out is None: break
    raw = out
open(dst, "wb").write(raw)
print("PATCH_HOLES wrote", dst, "after", it, "passes")
