#!/usr/bin/env python3
"""Hand leg skin that the transplant gave to body bones back to the legs, in place of the GLB's JOINTS_0/WEIGHTS_0.

ZEBRAWALK (2026-10-30): the zebraceratops v2 transplant skinned the inner toes and inner shin of the front-left and
hind-right legs (~700 vertices at floor level, more up the shin) to Shoulders and Tail1/Tail2. When the foot lifted
they stayed behind and stretched into a flat grey sheet under the belly, and the body bob pushed them 11 cm into the
floor. Per vertex lower than --full (share of the mesh height above its lowest point: feet and shins, no body
there), or lower than --top and within --radius x height of a leg bone segment (UpLeg, LowLeg, Foot; heads from the inverse bind matrices):
  leg = its own leg weights renormalised, or 100 % on the nearest leg segment's bone when it has none (shin and toes:
        LowLeg blended into that leg's Foot from 1.5x to 0.5x --foot above the floor),
  new = f * leg + (1 - f) * old, with f = 1 below --full and fading smoothly to 0 at --top (no seam at the belly).
Positions, the joint list, rest pose and textures stay byte-identical. Pure python (no numpy).

usage: python3 tools/gait/fix_foot_weights.py <in.glb> <out.glb> [--full 0.15] [--top 0.27] [--radius 0.11] [--foot 0.075]
"""
import json
import math
import struct
import sys

a = sys.argv[1:]
src, dst = a[0], a[1]


def opt(k, d):
    return float(a[a.index(k) + 1]) if k in a else d


FULL, TOP, RAD, FOOT = opt("--full", 0.15), opt("--top", 0.27), opt("--radius", 0.11), opt("--foot", 0.075)
blob = bytearray(open(src, "rb").read())
jlen = struct.unpack_from("<I", blob, 12)[0]
doc = json.loads(blob[20:20 + jlen])
bin_off = 20 + jlen + 8
CT = {5121: ("B", 1), 5123: ("H", 2), 5126: ("f", 4)}


def view(acc_i):
    acc = doc["accessors"][acc_i]
    bv = doc["bufferViews"][acc["bufferView"]]
    fmt, size = CT[acc["componentType"]]
    n = {"VEC3": 3, "VEC4": 4, "MAT4": 16}[acc["type"]]
    stride = bv.get("byteStride", size * n)
    base = bin_off + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    return acc["count"], base, stride, fmt, size, n


def inv_translation(m):
    """Translation of the inverse of a column-major affine 4x4 (the joint's head in bind space)."""
    A = [[m[c * 4 + r] for c in range(3)] for r in range(3)]
    t = [m[12], m[13], m[14]]
    det = (A[0][0] * (A[1][1] * A[2][2] - A[1][2] * A[2][1]) - A[0][1] * (A[1][0] * A[2][2] - A[1][2] * A[2][0])
           + A[0][2] * (A[1][0] * A[2][1] - A[1][1] * A[2][0]))
    inv = [[(A[(j + 1) % 3][(i + 1) % 3] * A[(j + 2) % 3][(i + 2) % 3] - A[(j + 1) % 3][(i + 2) % 3] * A[(j + 2) % 3][(i + 1) % 3]) / det
            for j in range(3)] for i in range(3)]
    return [-sum(inv[r][k] * t[k] for k in range(3)) for r in range(3)]


def seg_dist(p, a0, b0):
    ab = [b0[i] - a0[i] for i in range(3)]
    ap = [p[i] - a0[i] for i in range(3)]
    L = sum(x * x for x in ab) or 1e-12
    s = max(0.0, min(1.0, sum(ap[i] * ab[i] for i in range(3)) / L))
    return math.dist(p, [a0[i] + s * ab[i] for i in range(3)])


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


changed = 0
for si, skin in enumerate(doc.get("skins", [])):
    names = [doc["nodes"][j]["name"] for j in skin["joints"]]
    cnt_m, mb, ms, _, _, _ = view(skin["inverseBindMatrices"])
    head = [inv_translation(struct.unpack_from("<16f", blob, mb + i * ms)) for i in range(cnt_m)]
    J = {nm: i for i, nm in enumerate(names)}
    is_leg = [("Leg" in nm or "Foot" in nm) for nm in names]
    segs = []  # (bone index, head, tail)
    foot_of = {}  # any leg bone -> that leg's Foot (the foot bone sits on the floor, the toes are its skin)
    for end in ("Back", "Front"):
        for s in (".L", ".R"):
            up, low, foot, tip = (J[f"{end}{b}{s}"] for b in ("UpLeg", "LowLeg", "Foot", "Foot"))
            tip = J[f"{end}Foot{s}_end"]
            segs += [(up, head[up], head[low]), (low, head[low], head[foot]), (foot, head[foot], head[tip])]
            foot_of.update({low: (foot, low), foot: (foot, low)})
    for mi in {n["mesh"] for n in doc["nodes"] if n.get("skin") == si and "mesh" in n}:
        for prim in doc["meshes"][mi]["primitives"]:
            at = prim["attributes"]
            if "JOINTS_0" not in at:
                continue
            cnt, pb, ps, _, _, _ = view(at["POSITION"])
            _, jb, js, jf, _, jn = view(at["JOINTS_0"])
            _, wb, ws, wf, _, _ = view(at["WEIGHTS_0"])
            assert wf == "f" and jn == 4, "float WEIGHTS_0 and 4 joints expected"
            pos = [struct.unpack_from("<3f", blob, pb + v * ps) for v in range(cnt)]
            ys = [p[1] for p in pos]  # glTF Y is up
            h = max(ys) - min(ys)
            full, top = min(ys) + FULL * h, min(ys) + TOP * h
            for v in range(cnt):
                p = pos[v]
                if p[1] >= top:
                    continue
                jj = struct.unpack_from("<" + jf * 4, blob, jb + v * js)
                ww = struct.unpack_from("<4f", blob, wb + v * ws)
                old = {}
                for j, w in zip(jj, ww):
                    if w > 0:
                        old[j] = old.get(j, 0.0) + w
                if all(is_leg[j] for j in old):
                    continue
                d, bone = min((seg_dist(p, a0, b0), b) for b, a0, b0 in segs)
                if p[1] >= full and d > RAD * h:  # below --full every body-skinned vertex is toe or shin
                    continue
                leg = {j: w for j, w in old.items() if is_leg[j]}
                if not leg and bone in foot_of:  # shin or toe: blend LowLeg into Foot over the --foot band
                    foot, low = foot_of[bone]
                    t = smooth((p[1] - min(ys) - 0.5 * FOOT * h) / (FOOT * h))
                    leg = {j: w for j, w in ((foot, 1 - t), (low, t)) if w > 0}
                leg = leg or {bone: 1.0}
                tl, to = sum(leg.values()), sum(old.values())
                f = 1.0 - smooth((p[1] - full) / (top - full))
                new = {j: (1 - f) * w / to for j, w in old.items()}
                for j, w in leg.items():
                    new[j] = new.get(j, 0.0) + f * w / tl
                top4 = sorted(new.items(), key=lambda x: -x[1])[:4]
                t = sum(w for _, w in top4)
                top4 = (top4 + [(0, 0.0)] * 4)[:4]
                struct.pack_into("<" + jf * 4, blob, jb + v * js, *[j for j, _ in top4])
                struct.pack_into("<4f", blob, wb + v * ws, *[w / t for _, w in top4])
                changed += 1
open(dst, "wb").write(blob)
print(f"FOOTFIX {changed} leg vertices moved off body bones -> {dst}")
