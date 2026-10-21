"""Mineral and water-edge props (Milestone 3): crystal clusters (blue, obsidian, sulphur), a steam
vent rim, a hot-spring travertine terrace rim and a pebble patch.

Headless:  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P build_all.py -- minerals
Budget: <= 1500 tris each # ASSUMPTION: the task sets no budget for these; they are small ground props
like the vegetation, so they get 2x the vegetation budget.
The crystal clusters become the ore-node visuals (spec 26): pale blue in sandstone, black obsidian and
yellow sulphur in volcanic rock.
"""
import math

import bmesh
from mathutils import Matrix, Vector

import bp_lib as L


# ---------------------------------------------------------------- crystals

def _prism6(bm, base, tip, radius, taper=0.72, twist=0.0):
    """A hexagonal crystal prism with a flat-tapered point: six sides plus a 6-triangle point."""
    base, tip = Vector(base), Vector(tip)
    axis = tip - base
    if axis.length < 1e-4:
        return
    a = axis.normalized()
    side = Vector((0, 0, 1)).cross(a)
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    other = a.cross(side).normalized()
    body = 0.80  # the shaft ends here; the last 20 % is the point
    ring0, ring1 = [], []
    for k in range(6):
        ang = twist + k * math.pi / 3
        off = side * (math.cos(ang) * radius) + other * (math.sin(ang) * radius)
        ring0.append(bm.verts.new(base + off))
        ring1.append(bm.verts.new(base + axis * body + off * taper))
    point = bm.verts.new(tip)
    for k in range(6):
        bm.faces.new((ring0[k], ring0[(k + 1) % 6], ring1[(k + 1) % 6], ring1[k]))
        bm.faces.new((ring1[k], ring1[(k + 1) % 6], point))
    bm.faces.new(list(reversed(ring0)))


def _crystal_cluster(name, seed, colour_low, colour_high, count=6, height=0.55, spread=0.35,
                     needles=3, hue_shift=0.0, host=(0.30, 0.27, 0.24), metallic=0.1,
                     rough=0.30):
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    # host rock the crystals grow out of, half buried
    for k in range(2):
        a = rng.uniform(0, 6.28)
        d = spread * rng.uniform(0.5, 0.9)
        L.add_ico(bm, (math.cos(a) * d, math.sin(a) * d, 0.06), spread * rng.uniform(0.6, 0.9),
                  subdiv=1, scale=(1.3, 1.0, 0.65), wob=0.08, seed=seed + k, sink=-0.05)
    tips = []
    for i in range(count):
        for _try in range(10):
            a = rng.uniform(0, 6.28)
            d = spread * math.sqrt(rng.random())
            x, y = math.cos(a) * d, math.sin(a) * d
            leant = rng.uniform(0.15, 0.85)  # lean outward from the cluster centre
            h = height * rng.uniform(0.45, 1.0) * (1.0 - 0.3 * d / max(spread, 1e-3))
            r = h * rng.uniform(0.16, 0.26)
            base = Vector((x, y, -0.03))
            tip = base + Vector((x * leant, y * leant, h)) + Vector((rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), 0))
            _prism6(bm, base, tip, r, taper=0.7, twist=rng.uniform(0, 1.0))
            tips.append((base, tip, r))
    # small needle sprays at the foot
    for k in range(needles):
        a = rng.uniform(0, 6.28)
        d = spread * rng.uniform(0.9, 1.5)
        base = Vector((math.cos(a) * d, math.sin(a) * d, -0.02))
        tip = base + Vector((math.cos(a) * 0.10, math.sin(a) * 0.10, height * rng.uniform(0.10, 0.25)))
        _prism6(bm, base, tip, 0.025, taper=0.6)

    def col(co):
        # crystals cool/warm from base to tip; the host rock stays rock
        if co.z < 0.08 and math.hypot(co.x, co.y) > spread * 0.35:
            return L.mix(host, L.shade(host, 1.25), L.noise3(co, 0.2, seed) * 0.5)
        t = max(0.0, min(1.0, co.z / max(height, 1e-3)))
        c = L.mix(colour_low, colour_high, t ** 0.7)
        # facet variation so each prism face reads separately
        c = L.shade(c, 0.9 + 0.2 * L.hash01(round(co.x, 2), round(co.y, 2)))
        if hue_shift:
            c = (min(1.0, c[0] + hue_shift * 0.05), c[1], max(0.0, c[2] - hue_shift * 0.04))
        return c

    L.paint(bm, col)
    # glassy crystals: low roughness and a little metallic, so the facets catch the sun
    return [L.finalize(bm, name, smooth=False, rough=rough, metallic=metallic)]


# ---------------------------------------------------------------- steam vent

def build_steam_vent(name, seed):
    """A sinter ring around a dark hole: a squashed torus of pale silica crust with radiating rim
    stones, the hole's inside a near-black pit. Smoke is a particle/vfx job, not geometry."""
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    ring_r = 0.72
    seg = 16
    inner, outer, top = [], [], []
    for k in range(seg + 1):
        a = 2 * math.pi * k / seg
        w = 1.0 + 0.10 * math.sin(a * 3 + seed) + 0.05 * math.sin(a * 7 - seed)
        ri = ring_r * 0.45 * w
        ro = ring_r * 1.08 * w
        hi = 0.24 + 0.12 * L.noise3(Vector((math.cos(a), math.sin(a), 1)), 0.5, seed) + 0.05 * math.sin(a * 9 + seed)
        inner.append(bm.verts.new((math.cos(a) * ri, math.sin(a) * ri, 0.0)))
        # the crust is a wide sinter shelf: a raised shoulder, not a thin ridge
        mid = ri * 0.55 + ro * 0.45
        top.append(bm.verts.new((math.cos(a) * mid, math.sin(a) * mid, hi)))
        top.append(bm.verts.new((math.cos(a) * mid, math.sin(a) * mid, hi)))
        outer.append(bm.verts.new((math.cos(a) * ro, math.sin(a) * ro, 0.0)))
    for k in range(seg):
        bm.faces.new((inner[k], inner[k + 1], top[(k + 1) * 2], top[k * 2]))
        bm.faces.new((top[k * 2], top[(k + 1) * 2], outer[k + 1], outer[k]))
    # the pit: a dark bowl sunk inside the inner ring
    pit = [bm.verts.new((math.cos(2 * math.pi * k / seg) * ring_r * 0.55, math.sin(2 * math.pi * k / seg) * ring_r * 0.55, 0.0)) for k in range(seg)]
    ctr = bm.verts.new((0.0, 0.0, 0.02))  # the pit floor stays at ground level: a dark hole, not a bowl under the terrain
    for k in range(seg):
        bm.faces.new((pit[(k + 1) % seg], pit[k], ctr))
    # rim stones and a sulphur-crust splash on one side
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-0.3, 0.3)
        d = ring_r * rng.uniform(1.0, 1.35)
        L.add_ico(bm, (math.cos(a) * d, math.sin(a) * d, 0.02), ring_r * rng.uniform(0.10, 0.18),
                  subdiv=1, scale=(1.3, 1.1, 0.5), wob=0.05, seed=k, sink=-0.02)
    L.add_ico(bm, (ring_r * 0.95, ring_r * 0.2, 0.03), ring_r * 0.30, subdiv=1, scale=(1.4, 1.0, 0.18),
              wob=0.06, seed=seed + 5, sink=-0.01)
    crust, crust_d = (0.80, 0.77, 0.66), (0.55, 0.52, 0.45)
    sulphur = (0.86, 0.72, 0.20)

    def col(co):
        d = math.hypot(co.x, co.y)
        if d < ring_r * 0.58:
            c = L.mix((0.09, 0.08, 0.07), (0.30, 0.26, 0.22), L.noise3(co, 0.25, seed + 9) * 0.7)
            return L.mix(c, sulphur, 0.30 * max(0.0, L.noise3(co, 0.3, seed) - 0.45))
        c = L.mix(crust, crust_d, L.noise3(co, 0.25, seed + 1) * 0.8)
        if d > ring_r * 0.8 and co.x > ring_r * 0.3:
            c = L.mix(c, sulphur, max(0.0, L.noise3(co, 0.35, seed + 4) - 0.45) * 1.3)
        if d < ring_r * 0.5:
            c = L.mix(c, (0.20, 0.18, 0.16), 0.6)
        return c

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=False)]


# ---------------------------------------------------------------- hot-spring terraces

def build_hot_spring_rim(name, seed):
    """Cream travertine terraces: three stepped scalloped pools cascading in one direction, each a
    raised crusted lip with a shallow basin (the game's water plane fills the basins)."""
    L.new_scene(name)
    bm = bmesh.new()
    # (centre x, centre y, radius, lip height, basin depth): a staircase of pools, each lower and
    # further out than the last, so the cascade reads from the fixed camera
    # stepped down and sideways so the cascade reads from the fixed camera, not as one crater
    # a staircase down to the camera: each pool lower, smaller and further forward than the last
    # a staircase toward the camera: each pool lower, smaller and further forward, so every basin
    # and lip is visible from the fixed 50 deg view
    tiers = [(-0.55, 1.15, 1.10, 0.55, 0.40),
             (0.50, 0.20, 0.88, 0.38, 0.28),
             (1.45, -0.45, 0.62, 0.22, 0.16)]

    def scalloped(cx, cy, r, z, phase, nseg=22, grow=0.0):
        out = []
        for k in range(nseg):
            a = 2 * math.pi * k / nseg
            rr = r * (1.0 + 0.06 * math.sin(a * 7 + phase) + 0.04 * math.sin(a * 3 - phase) + grow)
            out.append(bm.verts.new((cx + math.cos(a) * rr, cy + math.sin(a) * rr, z)))
        return out

    for ti, (cx, cy, r, h, depth) in enumerate(tiers):
        phase = seed + ti * 2.1
        lip = scalloped(cx, cy, r, h, phase)
        inner = scalloped(cx, cy, r * 0.94, h - 0.02, phase, grow=0.04)
        floor = scalloped(cx, cy, r * 0.90, h - depth, phase + 0.7)
        base = scalloped(cx, cy, r * 1.06, -0.04, phase, grow=0.04)
        n = len(lip)
        for k in range(n):
            k2 = (k + 1) % n
            bm.faces.new((lip[k], lip[k2], inner[k2], inner[k]))   # the crusted lip
            bm.faces.new((inner[k], inner[k2], floor[k2], floor[k]))  # inner wall into the basin
            bm.faces.new((base[k], base[k2], lip[k2], lip[k]))     # outer wall
        ctr = bm.verts.new((cx, cy, h - depth))
        for k in range(n):
            bm.faces.new((floor[k], floor[(k + 1) % n], ctr))
        bm.faces.new(list(reversed(base)))
    # cascade: a thin crust sheet spilling from each lip to the next, plus crust blobs
    rng = L.rng_for(name, seed)
    for k in range(5):
        a = rng.uniform(-0.9, 0.9)
        x = -0.60 + math.cos(a) * 1.0
        y = 1.05 + math.sin(a) * 1.0
        L.add_ico(bm, (x, y, 0.15), rng.uniform(0.12, 0.22), subdiv=1, scale=(1.5, 1.0, 0.45),
                  wob=0.05, seed=k, sink=-0.02)
    for k in range(8):
        a = rng.uniform(0, 6.28)
        d = rng.uniform(1.1, 1.5)
        L.add_ico(bm, (-0.60 + math.cos(a) * d, 1.05 + math.sin(a) * d, 0.04), rng.uniform(0.12, 0.22),
                  subdiv=1, scale=(1.3, 1.1, 0.6), wob=0.06, seed=k + 11, sink=-0.04)
    cream, cream_d = (0.90, 0.84, 0.68), (0.66, 0.58, 0.44)
    wet = (0.45, 0.52, 0.44)

    def col(co):
        c = L.mix(cream, cream_d, L.noise3(co, 0.30, seed) * 0.85)
        if co.z > 0.02:
            # crust ridges: pale on the lip tops
            c = L.mix(c, (0.96, 0.92, 0.80), max(0.0, L.noise3(co, 0.18, seed + 7) - 0.55) * 1.2)
        # algae tint in the basins (just above the water line) and a damp dark line on the outer walls
        if co.z > 0.02 and co.z < 0.55:
            c = L.mix(c, wet, max(0.0, L.noise3(co, 0.25, seed + 3) - 0.30) * 0.75)
            # mineral crust band on the lip itself
            c = L.mix(c, (0.97, 0.94, 0.84), max(0.0, L.noise3(co, 0.9, seed + 8) - 0.55) * 0.9)
        # basin floors are warm and damp: a mineral-stained tint just above the water line
        c = L.mix(c, (0.72, 0.66, 0.52), min(1.0, max(0.0, 0.9 - co.z)) * 0.25)
        return c

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=False)]


# ---------------------------------------------------------------- pebbles

def build_pebbles(name, seed):
    """A patch of small flat pebbles and grit, 2.2 m across, no collision expected."""
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    palette = [(0.55, 0.52, 0.46), (0.68, 0.62, 0.52), (0.42, 0.38, 0.34), (0.60, 0.48, 0.36)]
    placed = []
    for i in range(64):
        for _try in range(24):
            a = rng.uniform(0, 6.28)
            d = 1.05 * math.sqrt(rng.random())
            x, y = math.cos(a) * d, math.sin(a) * d
            s = rng.uniform(0.035, 0.11) * (1.15 - 0.45 * d)
            if all(math.hypot(x - px, y - py) > (s + ps) * 0.75 for (px, py, ps) in placed):
                L.add_ico(bm, (x, y, s * 0.25), s, subdiv=1,
                          scale=(rng.uniform(0.9, 1.3), rng.uniform(0.7, 1.0), rng.uniform(0.40, 0.55)),
                          wob=0.02, seed=i, sink=-s * 0.1)
                placed.append((x, y, s))
                break
    def rng_pick(co):
        return palette[int(L.hash01(round(co.x, 1), round(co.y, 1)) * len(palette)) % len(palette)]

    def col(co):
        # each pebble keeps one colour: the palette pick is keyed on its own position band
        t = rng_pick(co)
        return L.mix(t, L.shade(t, 1.15), L.noise3(co, 0.05, seed + 2) * 0.8)

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=False)]


BUILDERS = {
    "crystal_blue": lambda: _crystal_cluster("crystal_blue", 71, (0.35, 0.60, 0.86), (0.62, 0.84, 0.96),
                                             count=6, height=0.75, spread=0.40, host=(0.55, 0.34, 0.24)),
    "crystal_obsidian": lambda: _crystal_cluster("crystal_obsidian", 72, (0.07, 0.07, 0.09), (0.26, 0.24, 0.30),
                                                 count=6, height=0.55, spread=0.32, host=(0.18, 0.18, 0.19),
                                                 metallic=0.25, rough=0.25),
    "crystal_sulphur": lambda: _crystal_cluster("crystal_sulphur", 73, (0.72, 0.58, 0.14), (0.95, 0.86, 0.32),
                                                count=5, height=0.36, spread=0.42, host=(0.36, 0.33, 0.22),
                                                metallic=0.0, rough=0.45),
    "steam_vent": lambda: build_steam_vent("steam_vent", 81),
    "hot_spring_rim": lambda: build_hot_spring_rim("hot_spring_rim", 82),
    "pebble_patch": lambda: build_pebbles("pebble_patch", 91),
}
