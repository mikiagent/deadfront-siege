#!/usr/bin/env python3
"""Remove stray skin weights (e.g. tail bones on a hoof) from a GLB in place, then renormalise.

Auto-rigged meshes sometimes weight leg and hoof vertices to tail bones. Clips that barely move
the feet hide it; a real stride drags those vertices into spikes. This edits only the WEIGHTS_0
bytes (same size, same layout), so mesh, textures, joints and the rest pose stay identical.

A vertex loses its weights on bones whose name starts with any --strip prefix when it sits below
--below (height, metres) or is mostly a leg vertex (>= --leg-min on bones containing UpLeg, LowLeg
or Foot) at least --xmin off the midline.

usage: tools/gait/clean_leg_weights.py <in.glb> <out.glb> --strip Tail [--below 0.8] [--leg-min 0.5] [--xmin 0.04]
"""
import argparse
import json
import struct

p = argparse.ArgumentParser()
p.add_argument("src")
p.add_argument("dst")
p.add_argument("--strip", default="Tail")
p.add_argument("--below", type=float, default=0.8)
p.add_argument("--leg-min", type=float, default=0.5)
p.add_argument("--xmin", type=float, default=0.04)
a = p.parse_args()

data = bytearray(open(a.src, "rb").read())
jlen = struct.unpack_from("<I", data, 12)[0]
gj = json.loads(data[20:20 + jlen])
bin_off = 20 + jlen + 8  # BIN chunk payload
prim = gj["meshes"][0]["primitives"][0]["attributes"]
skin = gj["skins"][0]
names = [gj["nodes"][i]["name"] for i in skin["joints"]]
strip = tuple(x for x in a.strip.split(",") if x)
is_strip = [n.startswith(strip) for n in names]
is_leg = [any(k in n for k in ("UpLeg", "LowLeg", "Foot")) for n in names]


def view(acc_i):
    acc = gj["accessors"][acc_i]
    bv = gj["bufferViews"][acc["bufferView"]]
    return acc, bin_off + bv.get("byteOffset", 0) + acc.get("byteOffset", 0), bv.get("byteStride")


pos, pos_off, _ = view(prim["POSITION"])
jnt, jnt_off, _ = view(prim["JOINTS_0"])
wgt, wgt_off, _ = view(prim["WEIGHTS_0"])
assert jnt["componentType"] == 5121 and wgt["componentType"] == 5126, "expects u8 joints, float weights"
changed = 0
for v in range(pos["count"]):
    x, y, _z = struct.unpack_from("<3f", data, pos_off + 12 * v)  # glTF is Y-up: y is height
    js = struct.unpack_from("<4B", data, jnt_off + 4 * v)
    ws = list(struct.unpack_from("<4f", data, wgt_off + 16 * v))
    leg = sum(w for j, w in zip(js, ws) if is_leg[j])
    if not (y < a.below or (leg >= a.leg_min and abs(x) >= a.xmin)):
        continue
    new = [0.0 if is_strip[j] else w for j, w in zip(js, ws)]
    s = sum(new)
    if s <= 1e-6 or new == ws:
        continue
    struct.pack_into("<4f", data, wgt_off + 16 * v, *[w / s for w in new])
    changed += 1
open(a.dst, "wb").write(data)
print("cleaned %d of %d vertices" % (changed, pos["count"]))
