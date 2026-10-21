# Minimal GLB reader/writer for the stegosaurus art fix. The edit is done at glTF level so the skeleton nodes,
# inverse bind matrices, joints, weights and UVs stay byte-identical (a Blender import/export round trip
# re-derives bone rest frames, which would break the 9 separate clip GLBs keyed on them).
import json, struct
import numpy as np

COMP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read(path):
    b = open(path, "rb").read()
    assert b[:4] == b"glTF"
    off, j, binc = 12, None, None
    while off < len(b):
        ln, ty = struct.unpack_from("<II", b, off)
        c = b[off + 8: off + 8 + ln]
        if ty == 0x4E4F534A: j = json.loads(c)
        elif ty == 0x004E4942: binc = bytearray(c)
        off += 8 + ln
    return j, binc


def view_bytes(j, binc, vi):
    v = j["bufferViews"][vi]
    o = v.get("byteOffset", 0)
    return bytes(binc[o: o + v["byteLength"]])


def accessor(j, binc, ai):
    a = j["accessors"][ai]
    v = j["bufferViews"][a["bufferView"]]
    dt = np.dtype(COMP[a["componentType"]])
    n = NCOMP[a["type"]]
    stride = v.get("byteStride", dt.itemsize * n)
    base = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    raw = np.frombuffer(bytes(binc), dtype=np.uint8, count=stride * (a["count"] - 1) + dt.itemsize * n, offset=base)
    out = np.lib.stride_tricks.as_strided(raw, shape=(a["count"], dt.itemsize * n), strides=(stride, 1)).copy()
    return out.view(dt).reshape(a["count"], n) if n > 1 else out.view(dt).reshape(a["count"])


def write(path, j, views):
    """views: list of bytes, one per bufferView, in order. Rebuilds the single buffer with 4-byte alignment."""
    blob = bytearray()
    for i, data in enumerate(views):
        while len(blob) % 4: blob.append(0)
        j["bufferViews"][i]["byteOffset"] = len(blob)
        j["bufferViews"][i]["byteLength"] = len(data)
        blob += data
    while len(blob) % 4: blob.append(0)
    j["buffers"] = [{"byteLength": len(blob)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4: js += b" "
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(blob), 0x004E4942)); f.write(blob)
