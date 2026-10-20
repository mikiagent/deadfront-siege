"""Pure-Python GLB reader: triangle count, materials, images and world AABB (no Blender needed)."""
import json
import math
import struct


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, _ver, _length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError("not a GLB: %s" % path)
    off = 12
    doc, binchunk = None, b""
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            doc = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            binchunk = chunk
        off += 8 + clen
    return doc, binchunk


def _mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def _node_matrix(node):
    if "matrix" in node:
        m = node["matrix"]  # column-major
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    tx, ty, tz = node.get("translation", [0, 0, 0])
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    r = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]
    return [
        [r[0][0] * sx, r[0][1] * sy, r[0][2] * sz, tx],
        [r[1][0] * sx, r[1][1] * sy, r[1][2] * sz, ty],
        [r[2][0] * sx, r[2][1] * sy, r[2][2] * sz, tz],
        [0, 0, 0, 1],
    ]


def summary(path):
    """{'tris', 'materials', 'material_names', 'images', 'image_uris', 'aabb_min', 'aabb_max', 'nodes'} in glTF axes (Y up)."""
    doc, _ = read_glb(path)
    acc = doc.get("accessors", [])
    meshes = doc.get("meshes", [])
    nodes = doc.get("nodes", [])
    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    tris = 0

    def walk(idx, parent):
        nonlocal tris
        node = nodes[idx]
        world = _mat_mul(parent, _node_matrix(node))
        if "mesh" in node:
            for prim in meshes[node["mesh"]]["primitives"]:
                if "indices" in prim:
                    tris += acc[prim["indices"]]["count"] // 3
                else:
                    tris += acc[prim["attributes"]["POSITION"]]["count"] // 3
                pa = acc[prim["attributes"]["POSITION"]]
                mn, mx = pa["min"], pa["max"]
                for cx in (mn[0], mx[0]):
                    for cy in (mn[1], mx[1]):
                        for cz in (mn[2], mx[2]):
                            p = [sum(world[r][c] * v for c, v in enumerate((cx, cy, cz, 1))) for r in range(3)]
                            for k in range(3):
                                lo[k] = min(lo[k], p[k])
                                hi[k] = max(hi[k], p[k])
        for ch in node.get("children", []):
            walk(ch, world)

    ident = [[1 if i == j else 0 for j in range(4)] for i in range(4)]
    scene = doc.get("scenes", [{}])[doc.get("scene", 0)]
    for root in scene.get("nodes", []):
        walk(root, ident)
    return {
        "tris": tris,
        "materials": len(doc.get("materials", [])),
        "material_names": [m.get("name", "") for m in doc.get("materials", [])],
        "images": len(doc.get("images", [])),
        "image_uris": [im.get("uri", "<embedded>") for im in doc.get("images", [])],
        "aabb_min": lo,
        "aabb_max": hi,
        "nodes": [n.get("name", "") for n in nodes],
    }


if __name__ == "__main__":
    import sys
    for p in sys.argv[1:]:
        s = summary(p)
        print(p.split("/")[-1], s["tris"], "tris", s["materials"], "mat",
              "min", [round(v, 2) for v in s["aabb_min"]], "max", [round(v, 2) for v in s["aabb_max"]])
