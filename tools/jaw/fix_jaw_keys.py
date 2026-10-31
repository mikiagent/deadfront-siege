#!/usr/bin/env python3
"""Rewrite only the Jaw rotation keys of clip GLBs in place; every other byte of the clip stays as it was.

REXJAW (owner 2026-10-31, "tyrannosaurus rex jaw is not moving correctly in bite animations"): make_rex_moves.py
turned the jaw about the Jaw bone's own +X, which on the regular T. rex rig swings the lower jaw UP through the
skull, so the bite, stomp, roar-alert and idle keys were all inverted. The jaw's delta from its rest rotation is a
pure hinge, so mirroring it (rotation by -angle about the same axis) opens the mouth by exactly the authored amount.

  python3 tools/jaw/fix_jaw_keys.py <base.glb> <clip.glb> [...] [--flip] [--max DEG]

--flip  mirror every key about the hinge (closing becomes opening, the authored clench past shut stays a clench)
--max   scale the whole jaw curve so its widest opening is at most DEG (the shape and timing are kept)
"""
import argparse
import json
import math
import struct

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("clips", nargs="+")
ap.add_argument("--flip", action="store_true"); ap.add_argument("--max", type=float, default=None)
a = ap.parse_args()


def qmul(p, q):  # (x, y, z, w)
    px, py, pz, pw = p; qx, qy, qz, qw = q
    return (pw * qx + px * qw + py * qz - pz * qy, pw * qy - px * qz + py * qw + pz * qx,
            pw * qz + px * qy - py * qx + pz * qw, pw * qw - px * qx - py * qy - pz * qz)


def conj(q): return (-q[0], -q[1], -q[2], q[3])


def qpow(q, s):  # rotation scaled to s times its angle, about the same axis
    w = max(-1.0, min(1.0, q[3])); ang = 2 * math.acos(w); sn = math.sin(ang / 2)
    if sn < 1e-9: return (0.0, 0.0, 0.0, 1.0)
    ax = [c / sn for c in q[:3]]; h = ang * s / 2
    return (ax[0] * math.sin(h), ax[1] * math.sin(h), ax[2] * math.sin(h), math.cos(h))


def load(p):
    b = bytearray(open(p, "rb").read())
    n = struct.unpack("<I", b[12:16])[0]
    return b, json.loads(b[20:20 + n]), 20 + n + 8  # bin chunk data offset


_, bj, _ = load(a.base)
r0 = tuple(next(n for n in bj["nodes"] if n["name"] == "Jaw")["rotation"])

for path in a.clips:
    b, j, off = load(path)
    ji = next(i for i, n in enumerate(j["nodes"]) if n["name"] == "Jaw")
    an = j["animations"][0]
    ch = next(c for c in an["channels"] if c["target"]["node"] == ji and c["target"]["path"] == "rotation")
    acc = j["accessors"][an["samplers"][ch["sampler"]]["output"]]
    bv = j["bufferViews"][acc["bufferView"]]
    start = off + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    keys = [struct.unpack_from("<4f", b, start + 16 * i) for i in range(acc["count"])]
    deltas = [qmul(conj(r0), q) for q in keys]
    if a.flip:
        deltas = [conj(d) for d in deltas]
    # signed angle: the delta axis is one hinge; a key is "open" when its axis matches the widest key's axis
    angs = [2 * math.degrees(math.acos(max(-1.0, min(1.0, abs(d[3]))))) for d in deltas]
    s = 1.0
    if a.max is not None and max(angs) > a.max:
        s = a.max / max(angs)
    out = [qmul(r0, qpow(d, s)) for d in deltas]
    for i, q in enumerate(out):
        struct.pack_into("<4f", b, start + 16 * i, *q)
    open(path, "wb").write(b)
    print(f"FIXJAW {path.split('/')[-1]}: {len(out)} keys, flip={a.flip}, widest {max(angs):.1f} -> {max(angs) * s:.1f} deg")
