#!/usr/bin/env python3
"""Move leg weights that sit on the wrong side of the body to the same bone on the right side, in place.

The T. rex base had claw and heel vertices of one foot skinned to the other foot's bones (a left-foot claw
100 % on Toe.R, a right inner toe 81 % on Metatarsal.L). Clips that move both feet together hide it; a stomp or a
lunge step drags those vertices 18 cm into the ground. Only the JOINTS_0 indices change (weights, positions and
everything else in the GLB stay byte-identical). A vertex counts as left/right by the sign of its rest x
(glTF x = the animal's right); vertices within --mid of the centre line are left alone.

usage: python3 tools/gait/fix_side_weights.py <in.glb> <out.glb> [--mid 0.15] [--bones Thigh,Shin,Metatarsal,Toe]
"""
import json
import struct
import sys

a = sys.argv[1:]
src, dst = a[0], a[1]
MID = float(a[a.index("--mid") + 1]) if "--mid" in a else 0.15
KEYS = (a[a.index("--bones") + 1] if "--bones" in a else "Thigh,Shin,Metatarsal,Toe").split(",")

blob = bytearray(open(src, "rb").read())
jlen = struct.unpack_from("<I", blob, 12)[0]
doc = json.loads(blob[20:20 + jlen])
bin_off = 20 + jlen + 8
CT = {5121: ("B", 1), 5123: ("H", 2), 5126: ("f", 4)}


def view(acc_i):
    acc = doc["accessors"][acc_i]
    bv = doc["bufferViews"][acc["bufferView"]]
    fmt, size = CT[acc["componentType"]]
    n = {"VEC3": 3, "VEC4": 4}[acc["type"]]
    stride = bv.get("byteStride", size * n)
    base = bin_off + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    return acc["count"], base, stride, fmt, size, n


moved = 0
for skin in doc.get("skins", []):
    names = [doc["nodes"][j]["name"] for j in skin["joints"]]
    idx = {nm: i for i, nm in enumerate(names)}
    mesh_ids = {n["mesh"] for n in doc["nodes"] if n.get("skin") == doc["skins"].index(skin) and "mesh" in n}
    for mi in mesh_ids:
        for prim in doc["meshes"][mi]["primitives"]:
            at = prim["attributes"]
            if "JOINTS_0" not in at:
                continue
            cnt, pb, ps, pf, psz, _ = view(at["POSITION"])
            _, jb, js, jf, jsz, jn = view(at["JOINTS_0"])
            for v in range(cnt):
                x = struct.unpack_from("<f", blob, pb + v * ps)[0]
                if abs(x) < MID:
                    continue
                want, other = (".R", ".L") if x > 0 else (".L", ".R")
                for k in range(jn):
                    o = jb + v * js + k * jsz
                    j = struct.unpack_from("<" + jf, blob, o)[0]
                    nm = names[j]
                    if nm.endswith(other) and any(nm.startswith(key) for key in KEYS):
                        mirror = idx.get(nm[:-2] + want)
                        if mirror is not None:
                            struct.pack_into("<" + jf, blob, o, mirror)
                            moved += 1
open(dst, "wb").write(blob)
print(f"SIDEFIX moved {moved} joint slots to the vertex's own side -> {dst}")
