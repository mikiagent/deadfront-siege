# Minimal glTF-binary reader/writer for the survivor appearance pieces (numpy only, runs in Blender's Python).
# Pieces are written from the body_helmet.glb template: same nodes, skin, inverse bind matrices and material,
# so they bind to the game skeleton exactly like the body regions (kit-verify: 0 mm drift).
import json, struct, copy
import numpy as np

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read(path):
    b = open(path, "rb").read()
    off, js, bn = 12, None, b""
    while off < len(b):
        ln, ty = struct.unpack("<II", b[off:off + 8])
        chunk = b[off + 8:off + 8 + ln]
        if ty == 0x4E4F534A:
            js = json.loads(chunk)
        elif ty == 0x004E4942:
            bn = chunk
        off += 8 + ln
    return js, bn


def accessor(js, bn, i):
    a = js["accessors"][i]
    v = js["bufferViews"][a["bufferView"]]
    dt, n = np.dtype(CT[a["componentType"]]), NC[a["type"]]
    start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = v.get("byteStride", 0) or dt.itemsize * n
    raw = np.frombuffer(bn, np.uint8, count=stride * (a["count"] - 1) + dt.itemsize * n, offset=start)
    rows = np.lib.stride_tricks.as_strided(raw, (a["count"], dt.itemsize * n), (stride, 1))
    return np.ascontiguousarray(rows).view(dt).reshape(a["count"], n) if n > 1 else np.ascontiguousarray(rows).view(dt).reshape(-1)


def mesh_arrays(js, bn, mesh=0, prim=0):
    p = js["meshes"][mesh]["primitives"][prim]
    out = {k: accessor(js, bn, i) for k, i in p["attributes"].items()}
    out["indices"] = accessor(js, bn, p["indices"]).astype(np.int64)
    return out


def write_piece(template_js, template_bn, path, arrays, name, images=None, material=None):
    """Write one skinned piece. arrays: POSITION/NORMAL/TEXCOORD_0/JOINTS_0/WEIGHTS_0 (+indices) as numpy.
    Keeps the template's nodes/skin/IBMs. images: list of {"uri"|"bytes"+"mimeType", "name"} replacing the
    template's images in order; material: replaces the template material (dict) when given."""
    js = copy.deepcopy(template_js)
    blob = bytearray()
    views, accs = [], []

    def add(arr, target=None, ctype=None, typ=None, minmax=False):
        while len(blob) % 4:
            blob.append(0)
        data = np.ascontiguousarray(arr)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": data.nbytes, **({"target": target} if target else {})})
        blob.extend(data.tobytes())
        acc = {"bufferView": len(views) - 1, "componentType": ctype, "count": int(data.shape[0]), "type": typ}
        if minmax:
            acc["min"] = data.min(0).tolist()
            acc["max"] = data.max(0).tolist()
        accs.append(acc)
        return len(accs) - 1

    # Keep the template's non-mesh accessors (inverse bind matrices) first.
    ibm_old = js["skins"][0]["inverseBindMatrices"]
    ibm = accessor(template_js, template_bn, ibm_old).astype(np.float32)
    js["skins"][0]["inverseBindMatrices"] = add(ibm, None, 5126, "MAT4")
    attrs = {
        "POSITION": add(arrays["POSITION"].astype(np.float32), 34962, 5126, "VEC3", True),
        "NORMAL": add(arrays["NORMAL"].astype(np.float32), 34962, 5126, "VEC3"),
        "TEXCOORD_0": add(arrays["TEXCOORD_0"].astype(np.float32), 34962, 5126, "VEC2"),
    }
    j = arrays["JOINTS_0"]
    attrs["JOINTS_0"] = add(j.astype(j.dtype), 34962, 5121 if j.dtype == np.uint8 else 5123, "VEC4")
    attrs["WEIGHTS_0"] = add(arrays["WEIGHTS_0"].astype(np.float32), 34962, 5126, "VEC4")
    idx = add(arrays["indices"].astype(np.uint32), 34963, 5125, "SCALAR")
    js["meshes"] = [{"name": name, "primitives": [{"attributes": attrs, "indices": idx, "material": 0}]}]
    for n in js["nodes"]:
        if "mesh" in n:
            n["name"] = name
    if material is not None:
        js["materials"] = [material]
    if images is not None:
        js["images"], js["textures"] = [], []
        for k, im in enumerate(images):
            if "uri" in im:
                js["images"].append({"uri": im["uri"], "name": im["name"]})
            else:
                while len(blob) % 4:
                    blob.append(0)
                views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(im["bytes"])})
                blob.extend(im["bytes"])
                js["images"].append({"bufferView": len(views) - 1, "mimeType": im["mimeType"], "name": im["name"]})
            js["textures"].append({"source": k, **({"sampler": 0} if js.get("samplers") else {})})
    js["accessors"], js["bufferViews"] = accs, views
    while len(blob) % 4:
        blob.append(0)
    js["buffers"] = [{"byteLength": len(blob)}]
    jb = json.dumps(js, separators=(",", ":")).encode()
    jb += b" " * ((4 - len(jb) % 4) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(blob))
    out += struct.pack("<II", len(jb), 0x4E4F534A) + jb + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    open(path, "wb").write(out)


def subset(arrays, tri_mask):
    """Triangles where tri_mask is True, with only the vertices they use (attribute bytes unchanged)."""
    tris = arrays["indices"].reshape(-1, 3)[tri_mask]
    used = np.unique(tris)
    remap = np.full(len(arrays["POSITION"]), -1, np.int64)
    remap[used] = np.arange(len(used))
    out = {k: v[used] for k, v in arrays.items() if k != "indices"}
    out["indices"] = remap[tris].reshape(-1)
    return out, used


def weld_ids(pos, eps=1e-5):
    """Same id for vertices at the same position (UV-seam duplicates)."""
    key = np.round(pos / eps).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    return inv.reshape(-1)


def tri_components(tris_w):
    """Connected components of triangles sharing an edge (welded vertex ids)."""
    n = len(tris_w)
    parent = np.arange(n)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    edge_owner = {}
    for t, (a, b, c) in enumerate(tris_w):
        for e in ((a, b), (b, c), (c, a)):
            k = (min(e), max(e))
            o = edge_owner.setdefault(k, t)
            if o != t:
                ra, rb = find(o), find(t)
                if ra != rb:
                    parent[ra] = rb
    return np.array([find(t) for t in range(n)])


def embedded_images(js, bn):
    """The file's embedded images as write_piece `images` entries (same bytes, names and order)."""
    out = []
    for im in js["images"]:
        v = js["bufferViews"][im["bufferView"]]
        o = v.get("byteOffset", 0)
        out.append({"bytes": bn[o:o + v["byteLength"]], "mimeType": im["mimeType"], "name": im["name"]})
    return out


def write_parts(template_js, template_bn, path, parts):
    """Write several skinned meshes into one file, each its own node on the template's skin (P4 face pieces: an
    opaque overlay, an alpha-blended decal, a beard shell). parts: list of {"name", "arrays" (as write_piece),
    "material" (glTF dict, its textures as {"index": i} into "images"), "images": [{"uri", "name"}]}."""
    js = copy.deepcopy(template_js)
    blob = bytearray()
    views, accs = [], []

    def add(arr, target, ctype, typ, minmax=False):
        while len(blob) % 4:
            blob.append(0)
        data = np.ascontiguousarray(arr)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": data.nbytes, **({"target": target} if target else {})})
        blob.extend(data.tobytes())
        acc = {"bufferView": len(views) - 1, "componentType": ctype, "count": int(data.shape[0]), "type": typ}
        if minmax:
            acc["min"], acc["max"] = data.min(0).tolist(), data.max(0).tolist()
        accs.append(acc)
        return len(accs) - 1

    ibm = accessor(template_js, template_bn, js["skins"][0]["inverseBindMatrices"]).astype(np.float32)
    js["skins"][0]["inverseBindMatrices"] = add(ibm, None, 5126, "MAT4")
    mesh_node = next(i for i, n in enumerate(js["nodes"]) if "mesh" in n)
    parent = next(n for n in js["nodes"] if mesh_node in n.get("children", []))
    js["meshes"], js["materials"], js["images"], js["textures"] = [], [], [], []
    for k, p in enumerate(parts):
        a = p["arrays"]
        j = a["JOINTS_0"]
        attrs = {"POSITION": add(a["POSITION"].astype(np.float32), 34962, 5126, "VEC3", True),
                 "NORMAL": add(a["NORMAL"].astype(np.float32), 34962, 5126, "VEC3"),
                 "TEXCOORD_0": add(a["TEXCOORD_0"].astype(np.float32), 34962, 5126, "VEC2"),
                 "JOINTS_0": add(j, 34962, 5121 if j.dtype == np.uint8 else 5123, "VEC4"),
                 "WEIGHTS_0": add(a["WEIGHTS_0"].astype(np.float32), 34962, 5126, "VEC4")}
        idx = add(a["indices"].astype(np.uint32), 34963, 5125, "SCALAR")
        mat = copy.deepcopy(p["material"])
        base = len(js["images"])
        for im in p.get("images", []):
            js["textures"].append({"source": len(js["images"]), **({"sampler": 0} if js.get("samplers") else {})})
            js["images"].append({"uri": im["uri"], "name": im["name"]})

        def shift(d):  # texture indices are per part: move them past the earlier parts' textures
            for key, v in d.items():
                if isinstance(v, dict):
                    if key.endswith("Texture") and "index" in v:
                        v["index"] += base
                    else:
                        shift(v)
        shift(mat)
        js["materials"].append(mat)
        js["meshes"].append({"name": p["name"], "primitives": [{"attributes": attrs, "indices": idx, "material": k}]})
        if k == 0:
            js["nodes"][mesh_node].update({"name": p["name"], "mesh": 0})
        else:
            js["nodes"].append({"name": p["name"], "mesh": k, "skin": 0})
            parent["children"].append(len(js["nodes"]) - 1)
    if not js["images"]:
        for key in ("images", "textures", "samplers"):
            js.pop(key, None)
    js["accessors"], js["bufferViews"] = accs, views
    while len(blob) % 4:
        blob.append(0)
    js["buffers"] = [{"byteLength": len(blob)}]
    jb = json.dumps(js, separators=(",", ":")).encode()
    jb += b" " * ((4 - len(jb) % 4) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(blob))
    out += struct.pack("<II", len(jb), 0x4E4F534A) + jb + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    open(path, "wb").write(out)
