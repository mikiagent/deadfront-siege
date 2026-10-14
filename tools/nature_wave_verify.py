#!/usr/bin/env python3
"""Independent GLB check for the nature wave (no Blender): mesh count, material count, triangles, texture formats and
sizes, and the bounding box from the position accessor. Usage: nature_wave_verify.py file.glb ... -> JSON lines."""
import json, struct, sys, io

def read(path):
    data = open(path, "rb").read()
    magic, ver, total = struct.unpack("<4sII", data[:12])
    assert magic == b"glTF", path
    off, js, bins = 12, None, None
    while off < total:
        ln, typ = struct.unpack("<II", data[off:off + 8])
        chunk = data[off + 8:off + 8 + ln]
        if typ == 0x4E4F534A: js = json.loads(chunk)
        elif typ == 0x004E4942: bins = chunk
        off += 8 + ln
    return js, bins, len(data)

def png_jpg_size(blob):
    if blob[:2] == b"\xff\xd8":
        i = 2
        while i < len(blob):
            if blob[i] != 0xFF: i += 1; continue
            m = blob[i + 1]
            if m in (0xC0, 0xC1, 0xC2):
                h, w = struct.unpack(">HH", blob[i + 5:i + 9]); return "jpeg", w, h
            i += 2 + struct.unpack(">H", blob[i + 2:i + 4])[0]
    if blob[:8] == b"\x89PNG\r\n\x1a\n":
        w, h = struct.unpack(">II", blob[16:24]); return "png", w, h
    return "unknown", 0, 0

for path in sys.argv[1:]:
    js, bins, size = read(path)
    tris = 0; lo = [1e9] * 3; hi = [-1e9] * 3
    for m in js["meshes"]:
        for p in m["primitives"]:
            tris += js["accessors"][p["indices"]]["count"] // 3
            a = js["accessors"][p["attributes"]["POSITION"]]
            lo = [min(x, y) for x, y in zip(lo, a["min"])]; hi = [max(x, y) for x, y in zip(hi, a["max"])]
    imgs = []
    for im in js.get("images", []):
        bv = js["bufferViews"][im["bufferView"]]
        fmt, w, h = png_jpg_size(bins[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])
        imgs.append({"mime": im.get("mimeType"), "format": fmt, "w": w, "h": h})
    mats = js.get("materials", [])
    print(json.dumps({"file": path.split("/")[-1], "bytes": size, "meshes": len(js["meshes"]), "nodes": len(js["nodes"]),
        "primitives": sum(len(m["primitives"]) for m in js["meshes"]), "materials": len(mats),
        "alphaMode": sorted({m.get("alphaMode", "OPAQUE") for m in mats}),
        "triangles": tris, "min": [round(v, 3) for v in lo], "max": [round(v, 3) for v in hi],
        "size_xyz": [round(h - l, 3) for l, h in zip(lo, hi)], "images": imgs}))
