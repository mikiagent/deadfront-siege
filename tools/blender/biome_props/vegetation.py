"""Vegetation props for the biomes (Milestone 1): reed clumps, plume grass, ferns, lily pads, aloe.

Headless:  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P build_all.py -- vegetation
Budget: <= 800 tris per clump (task BIOMEASSETS). Colour is baked per vertex (bp_lib.paint).
"""
import math

import bmesh
from mathutils import Matrix

import bp_lib as L
from bp_lib import Vector


def _prism(bm, p0, p1, r0, r1, segments=3):
    """A cheap closed prism from p0 to p1 (stems)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    if d.length < 1e-5:
        return
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                          radius1=r0, radius2=r1, depth=d.length,
                          matrix=Matrix.Translation((p0 + p1) * 0.5) @ rot)


# ---------------------------------------------------------------- reeds and plume grass

def _leaf_plane(ang):
    """The plane a blade faces: roughly perpendicular to the radial direction `ang`, tipped up."""
    return Vector((-math.sin(ang) * 0.5, math.cos(ang) * 0.5, 0.86)).normalized()


def _reed(bm, base, height, rng, plume=False):
    base = Vector(base)
    lean_dir = rng.uniform(0, 2 * math.pi)
    lean = rng.uniform(0.14, 0.34) * height
    tip = base + Vector((math.cos(lean_dir) * lean, math.sin(lean_dir) * lean, height))
    _prism(bm, base, tip, 0.016 if plume else 0.011, 0.006)
    # blades: a broad one at the base of the stem and one higher up, both facing the camera side
    for k in range(2 if not plume else 3):
        u = rng.uniform(0.18, 0.62) + k * 0.1
        start = base + (tip - base) * u
        ang = lean_dir + (k - 1) * 1.9 + rng.uniform(-0.3, 0.3)
        reach = rng.uniform(0.22, 0.38) * height
        end = start + Vector((math.cos(ang) * reach, math.sin(ang) * reach, 0.42 * height * (1 - u)))
        L.leaf(bm, start, end, 0.055 if not plume else 0.075, normal=_leaf_plane(ang),
               bend=0.05, steps=3, taper=0.9)
    if plume:
        # feathery white seed head: a spindle of small leaflets off the top 0.3 m
        axis = (tip - base).normalized()
        for k in range(9):
            t = k / 8.0
            p = tip - axis * (0.30 * (1.0 - t)) - Vector((0, 0, 0.02))
            a = k * 2.4 + lean_dir
            wob = 0.075 * math.sin(t * math.pi)
            end = p + Vector((math.cos(a) * wob, math.sin(a) * wob, 0.09 + 0.04 * math.sin(t * math.pi)))
            L.leaf(bm, p, end, 0.06, normal=(math.cos(a), math.sin(a), 0.5), bend=0.02, steps=2, taper=0.4)


def build_reed_clump(name, count, h_lo, h_hi, seed, plume=False, radius=0.5):
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    for _ in range(count):
        ang = rng.uniform(0, 2 * math.pi)
        r = radius * math.sqrt(rng.random())
        h = rng.uniform(h_lo, h_hi) * (1.0 - 0.25 * r / max(radius, 0.01))
        _reed(bm, (math.cos(ang) * r, math.sin(ang) * r, 0.0), h, rng, plume=plume)
    if plume:
        low, high = (0.42, 0.50, 0.26), (0.92, 0.90, 0.80)  # green stem -> cream plume
    else:
        low, high = (0.33, 0.45, 0.20), (0.60, 0.66, 0.33)  # deep reed green -> dry tips
    L.paint(bm, lambda co: L.mix(low, high, co.z / h_hi + L.wobble(co, 2, 0.3, seed) * 0.18))
    return [L.finalize(bm, name, smooth=True, double_sided=True)]


# ---------------------------------------------------------------- ferns

def build_fern(name, height, spread, seed, heads=7):
    """Arching fronds: a rachis rising then bending over, pinnae in opposite pairs either side.

    Each pinna is a small ribbon tilted about 22 deg above the frond plane so it catches light from
    the fixed camera; pairs shrink towards the tip so the frond reads as a fern, not a stick.
    """
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    green_a, green_b = (0.16, 0.30, 0.13), (0.42, 0.58, 0.24)
    for h in range(heads):
        ang = 2 * math.pi * h / heads + rng.uniform(-0.20, 0.20)
        out = Vector((math.cos(ang), math.sin(ang), 0))
        sidev = Vector((-math.sin(ang), math.cos(ang), 0))
        reach = spread * rng.uniform(0.70, 1.0)
        rise = height * rng.uniform(0.65, 1.0)

        def rachis(u, _out=out, _reach=reach, _rise=rise):
            # rises steeply, then flattens out towards the tip (cartesian oval)
            return _out * (_reach * math.sin(u * math.pi * 0.5)) + Vector((0, 0, 0.03 + _rise * math.sin(u * math.pi * 0.62)))

        _prism(bm, rachis(0.0), rachis(0.75), 0.018, 0.007, segments=3)
        for k in range(1, 12):
            u = k / 12.0
            p = rachis(u)
            along = (rachis(min(1.0, u + 0.02)) - p).normalized()
            pinna = (sidev * along.dot(along) * 0 + sidev).normalized()
            size = (0.20 * math.sin(u * math.pi * 0.92) * (1.05 - 0.35 * u)) * height * 1.35
            for s in (-1, 1):
                b = p
                t = p + pinna * (s * size) + along * (size * 0.40) + Vector((0, 0, size * 0.26))
                L.leaf(bm, b, t, size * 0.78, normal=(0, 0, 1), bend=0.02, steps=2, taper=0.50)
    L.paint(bm, lambda co: L.mix(green_a, green_b, L.wobble(co, 2, 0.3, seed) * 0.5 + 0.5))
    return [L.finalize(bm, name, smooth=True, double_sided=True)]


# ---------------------------------------------------------------- lily pads

def build_lily_cluster(name, seed):
    L.new_scene(name)
    bm = bmesh.new()
    pads = [(-0.42, -0.26, 0.44), (0.34, -0.18, 0.36), (0.0, 0.34, 0.50), (0.56, 0.38, 0.24),
            (-0.20, 0.50, 0.22)]
    flower_pad = 1
    z = 0.0
    for i, (x, y, r) in enumerate(pads):
        notch = L.hash01(name, i) * 2 * math.pi
        segs = 9
        top = [bm.verts.new((x, y, 0.02))]
        bot = [bm.verts.new((x, y, 0.0))]
        for k in range(segs + 1):
            a = notch + 0.5 + (2 * math.pi - 1.0) * k / segs
            rr = r * (1.0 + 0.04 * math.sin(k * 1.7))
            top.append(bm.verts.new((x + math.cos(a) * rr, y + math.sin(a) * rr, 0.03 + 0.01 * math.sin(k / segs * math.pi))))
            bot.append(bm.verts.new((x + math.cos(a) * rr, y + math.sin(a) * rr, 0.0)))
        for k in range(segs):
            bm.faces.new((top[0], top[k + 1], top[k + 2]))
            bm.faces.new((bot[0], bot[k + 2], bot[k + 1]))
            bm.faces.new((top[k + 1], bot[k + 1], bot[k + 2], top[k + 2]))
        z = max(z, 0.03)
    x, y, r = pads[flower_pad]
    cz = 0.03
    for p in range(9):
        a = 2 * math.pi * p / 7
        L.leaf(bm, (x, y, cz),
               (x + math.cos(a) * 0.14, y + math.sin(a) * 0.14, cz + 0.16),
               0.10, normal=(math.cos(a), math.sin(a), 0.7), bend=-0.01, steps=2, taper=0.4)
    L.add_ico(bm, (x, y, cz + 0.08), 0.06, subdiv=1, scale=(1, 1, 0.6))
    base_pad, light_pad = (0.22, 0.42, 0.17), (0.40, 0.56, 0.22)

    def col(co):
        if co.z > 0.06:  # flower: white petals with a warm yellow centre
            return (0.62, 0.32, 0.40) if math.hypot(co.x - x, co.y - y) < 0.05 else (0.95, 0.93, 0.88)
        if co.z < 0.012:  # underside, wet dark
            return (0.22, 0.34, 0.16)
        return L.mix(base_pad, light_pad, L.wobble(co, 2, 0.25, seed) * 0.5 + 0.5)

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=False, double_sided=True)]


# ---------------------------------------------------------------- aloe

def build_aloe(name, seed):
    """A 1.2-1.5 m aloe rosette: thick triangular leaves in four staggered rings arcing up and out
    from a short trunk, with a red-flowered raceme rising past the leaf tips."""
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    leaf_a, leaf_b = (0.26, 0.40, 0.28), (0.52, 0.62, 0.46)
    # (base z, outward reach, tip z, count): inner rings stand up, outer rings arch out and down
    rings = [(0.30, 0.26, 1.30, 11), (0.22, 0.42, 1.16, 12), (0.14, 0.55, 0.96, 13), (0.06, 0.64, 0.70, 14)]
    for ring_i, (z0, reach, tip_z, n) in enumerate(rings):
        for i in range(n):
            ang = 2 * math.pi * i / n + ring_i * 0.42
            rad = reach * rng.uniform(0.88, 1.12)
            base = Vector((math.cos(ang) * 0.09, math.sin(ang) * 0.09, z0 + rng.uniform(-0.03, 0.03)))
            tip = Vector((math.cos(ang) * rad, math.sin(ang) * rad,
                          tip_z + rng.uniform(-0.06, 0.06)))
            normal = Vector((-math.sin(ang), math.cos(ang), 0)).cross(tip - base).normalized()
            # thick triangular blade: wide at the base, tapering to a point, folded along the midrib
            L.leaf(bm, base, tip, 0.20 if ring_i > 1 else 0.16, normal=normal,
                   bend=0.05, steps=4, taper=1.5, fold=0.55)
    # a short woody trunk the rosette sits on
    L.add_cylinder(bm, (0, 0, -0.06), (0, 0, 0.34), 0.15, 0.11, segments=7)
    # raceme: a bare stalk with red flowers along its upper third, taller than the leaf tips
    sx, sy = 0.05, -0.04
    L.add_cylinder(bm, (sx, sy, 1.05), (sx, sy, 1.44), 0.022, 0.014, segments=4)
    for k in range(16):
        t = k / 15.0
        z = 1.16 + t * 0.30
        a = k * 2.4
        r = 0.07 * (1.0 - 0.5 * t)
        p = Vector((sx + math.cos(a) * r * 0.5, sy + math.sin(a) * r * 0.5, z))
        end = p + Vector((math.cos(a) * r, math.sin(a) * r, 0.075))
        L.leaf(bm, p, end, 0.10, normal=(math.cos(a), math.sin(a), 0.3), bend=0.0, steps=2, taper=0.3)

    def col(co):
        if co.z > 1.10 and math.hypot(co.x - sx, co.y - sy) < 0.16:
            return L.mix((0.72, 0.16, 0.08), (0.95, 0.46, 0.15), L.hash01(round(co.z, 2), round(co.x, 2)))
        if math.hypot(co.x, co.y) < 0.17 and co.z < 0.36:
            return L.mix((0.36, 0.26, 0.18), (0.50, 0.40, 0.28), L.noise3(co, 0.1, seed) * 0.6)
        t = max(0.0, min(1.0, co.z / 1.30))
        return L.mix(leaf_a, leaf_b, 0.25 + 0.6 * t * (0.5 + 0.5 * L.wobble(co, 2, 0.25, seed)))

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=True, double_sided=True)]


BUILDERS = {
    "reed_clump_a": lambda: build_reed_clump("reed_clump_a", 34, 1.1, 2.0, 1, radius=0.55),
    "reed_clump_b": lambda: build_reed_clump("reed_clump_b", 22, 0.9, 1.6, 2, radius=0.42),
    "plume_grass": lambda: build_reed_clump("plume_grass", 12, 1.2, 1.9, 3, plume=True, radius=0.40),
    "fern_clump_a": lambda: build_fern("fern_clump_a", 0.85, 0.75, 4, heads=8),
    "fern_clump_b": lambda: build_fern("fern_clump_b", 1.25, 1.00, 5, heads=8),
    "lily_pad_cluster": lambda: build_lily_cluster("lily_pad_cluster", 6),
    "aloe_flower": lambda: build_aloe("aloe_flower", 7),
}
