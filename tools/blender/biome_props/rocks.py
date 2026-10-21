"""Rock landforms and wood (Milestone 2): termite mounds, fallen logs, rock spires, mesas/cliffs,
basalt column cluster, boulder piles.

Headless:  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P build_all.py -- rocks
Budgets: mounds/logs/boulders <= 2500 tris, spires/mesas/cliffs <= 6000 tris (task BIOMEASSETS).
Sizes follow the task: mounds 2-3.5 m, logs 4-7 m, spires 5-9 m, mesa/cliff chunks 8-15 m wide.

Colours are baked per vertex from the concept art (docs/reference/biome-concept-*.webp): red sandstone
with darker bedding bands and pale caliche tops, black basalt with a blue-grey sheen on fresh
fractures, granite grey-brown with lichen, red laterite earth for the termite mounds.
"""
import math

import bmesh

import bp_lib as L
from bp_lib import Vector

# ---------------------------------------------------------------- colour sets (sRGB)
SANDSTONE = {"base": (0.62, 0.38, 0.27), "dark": (0.40, 0.24, 0.18), "light": (0.80, 0.62, 0.45),
             "top": (0.70, 0.56, 0.40)}
BASALT = {"base": (0.26, 0.26, 0.27), "dark": (0.14, 0.14, 0.15), "light": (0.44, 0.45, 0.47),
          "top": (0.40, 0.39, 0.36)}
GRANITE = {"base": (0.68, 0.66, 0.62), "dark": (0.50, 0.49, 0.47), "light": (0.82, 0.80, 0.76),
           "top": (0.72, 0.71, 0.66)}
TERMITE = {"base": (0.56, 0.30, 0.19), "dark": (0.36, 0.18, 0.12), "light": (0.74, 0.50, 0.34),
           "top": (0.52, 0.32, 0.22)}


def rock_colour(palette, seed, strata=0.0, moss=None):
    """Bedding bands (strata > 0 gives horizontal bands every ~0.55 m), noise blotches, a pale top."""
    def fn(co):
        t = L.wobble(co, 3, 1.1, seed) * 0.5 + 0.5
        c = L.mix(palette["base"], palette["dark"], t * 0.85)
        speck = L.noise3(co, 0.22, seed + 3.3)
        c = L.mix(c, palette["light"], max(0.0, speck - 0.72) * 1.6)
        if strata:
            # straight horizontal bedding: one dark seam every ~0.8 m, a pale ledge above it
            band = math.sin((co.z + L.wobble(co, 2, 3.0, seed + 1.1) * 0.06) / 0.80 * math.pi)
            c = L.mix(c, palette["dark"], max(0.0, band - 0.75) * 1.4 * strata)
            c = L.mix(c, palette["light"], max(0.0, -band - 0.90) * 2.0 * strata)
        # dust/lichen on up-facing surfaces: a pale wash where the face points up (not the walls)
        if co.z > 0.0:
            c = L.mix(c, palette["top"], max(0.0, L.wobble(co, 2, 0.7, seed + 7.7)) * 0.35)
        if moss:
            m = L.wobble(Vector((co.x, co.y, 0.0)), 2, 0.6, seed + 11) * 0.5 + 0.5
            c = L.mix(c, moss, max(0.0, m - 0.45) * 1.1 * max(0.0, min(1.0, (0.9 - co.z) / 0.9)))
        return c
    return fn


# ---------------------------------------------------------------- termite mound

def build_termite_mound(name, height, radius, seed, towers=2):
    """Red laterite mounds: a broad fluted cone with a blunt crown, flanked by 1-3 shorter finger
    towers, each open at the top (the chimney mouth). Clay blobs settle around the foot."""
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    # (x, y, own height, own base radius, own top radius): one main cone plus flanking fingers
    parts = [(0.0, 0.0, height, radius, radius * 0.34)]
    for i in range(towers):
        a = 2 * math.pi * i / max(1, towers) + rng.uniform(-0.5, 0.5)
        d = radius * rng.uniform(0.55, 0.80)
        parts.append((math.cos(a) * d, math.sin(a) * d, height * rng.uniform(0.62, 0.84),
                      radius * rng.uniform(0.52, 0.68), radius * rng.uniform(0.22, 0.34)))
    levels = 12
    for (x, y, h, r0, r1) in parts:
        seg = 18
        rings = []
        phase = rng.uniform(0, 6.28)
        for j in range(levels + 1):
            t = j / levels
            # a pinnacle: the wall steepens quickly from a broad base, then rolls over into a
            # blunt, rounded crown (the last ring closes the top)
            prof = r1 + (r0 - r1) * (1.0 - t) ** 1.9 if t < 0.94 else r1 * (1.0 - (t - 0.94) / 0.06 * 0.55)
            z = h * t
            ring = []
            for k in range(seg):
                a = phase + 2 * math.pi * k / seg
                # ribs: 7 narrow fins that fade out towards the crown, plus a slow plan wobble
                fin = 0.16 * max(0.0, math.sin(a * 7 + 0.6)) ** 2 * (1.0 - t * 0.7)
                rr = prof * (1.0 + 0.06 * math.sin(a * 3 + t * 2.0) + fin)
                lean = 0.06 * h * t * t
                ring.append((x + math.cos(a) * rr + lean * math.cos(phase),
                             y + math.sin(a) * rr + lean * math.sin(phase),
                             z + L.wobble(Vector((a * 0.5, t, 3)), 2, 0.5, seed) * 0.05))
            rings.append(ring)
        L.loft(bm, rings, close_top=True)  # the crown rolls over; chimney mouth is a shallow dimple
        # lumpy crown: a few clay blobs settle on the top, as on real mounds
        for b in range(2):
            aa = phase + b * 2.1
            L.add_ico(bm, (x + math.cos(aa) * r1 * 0.35, y + math.sin(aa) * r1 * 0.35, h * 0.93),
                      r1 * rng.uniform(0.35, 0.5), subdiv=1, scale=(1.2, 1.0, 0.9), wob=0.03, seed=b)
    # clay blobs at the foot, half in the ground
    for k in range(6):
        a = 2 * math.pi * k / 6 + rng.uniform(-0.35, 0.35)
        d = radius * rng.uniform(0.85, 1.05)
        sz = radius * rng.uniform(0.18, 0.28)
        L.add_ico(bm, (math.cos(a) * d, math.sin(a) * d, sz * 0.10), sz,
                  subdiv=1, scale=(1.3, 1.1, 0.55), wob=0.05, seed=k, sink=-sz * 0.2)

    def col(co):
        c = rock_colour(TERMITE, seed, strata=0.0, moss=(0.42, 0.40, 0.22))(co)
        # deep vertical grooves between the fins, plus termite-cement mottling
        ang = math.atan2(co.y, co.x)
        rib = math.sin(ang * 7 + 0.6)
        c = L.mix(c, TERMITE["dark"], max(0.0, -rib) ** 1.5 * 0.55)   # shadowed grooves between fins
        c = L.mix(c, TERMITE["light"], max(0.0, rib) ** 3 * 0.35)      # lit fin crests
        # termite cement speckle
        c = L.mix(c, TERMITE["light"], max(0.0, L.noise3(co, 0.12, seed + 6) - 0.72) * 1.2)
        c = L.mix(c, TERMITE["light"], max(0.0, L.noise3(co, 0.18, seed + 2) - 0.6) * 1.1)
        # pale dry-grass dust collecting on the upper surfaces
        return L.mix(c, (0.66, 0.56, 0.36), max(0.0, co.z / max(1e-3, 3.5) - 0.55) * 0.6)

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=False)]


# ---------------------------------------------------------------- fallen log

def build_fallen_log(name, length, radius, seed, mossy=True, broken=True):
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    bark = (0.36, 0.29, 0.22) if not mossy else (0.30, 0.27, 0.20)
    bark_d = (0.20, 0.16, 0.13)
    bark_l = (0.48, 0.40, 0.31)
    moss = (0.36, 0.43, 0.21)
    wood_end = (0.68, 0.55, 0.36)

    # a trunk lying along +x, slightly wavy, sagging into the ground
    seg = 11
    rings = []
    axis0 = Vector((-length * 0.5, 0.0, radius * 0.82))
    for j in range(seg + 1):
        t = j / seg
        cx = -length * 0.5 + length * t
        cy = math.sin(t * 2.6) * 0.10 * length * 0.3
        # sags on the ground at both ends, lifts in the middle over a stone
        cz = radius * (0.98 + 0.10 * math.sin(t * math.pi) ** 2.0)
        r = radius * (0.82 + 0.30 * math.sin(t * math.pi) ** 0.5)
        ring = []
        for k in range(9):
            a = 2 * math.pi * k / 9
            rr = r * (1.0 + 0.05 * math.sin(k * 5 + t * 9))
            ring.append((cx, cy + math.cos(a) * rr, cz + math.sin(a) * rr * 0.92))
        rings.append(ring)
    L.loft(bm, rings, close_top=not broken, close_bottom=True)
    # splintered end: a jagged fan of shards where the trunk broke
    if broken:
        cx = length * 0.5
        for k in range(4):
            a = k * 1.6
            base = Vector((cx - 0.05, math.sin(a) * radius * 0.4, radius * 0.72 + math.cos(a) * radius * 0.35))
            tip = base + Vector((rng.uniform(0.15, 0.35), math.sin(a) * radius * 0.5, rng.uniform(-0.1, 0.2)))
            L.leaf(bm, base, tip, radius * 0.5, normal=(0, 0, 1), steps=2, taper=0.2)
    # a broken branch stub
    stub_base = Vector((length * 0.08, -radius * 0.5, radius * 1.1))
    L.add_cylinder(bm, stub_base, stub_base + Vector((0.12, -radius * 0.7, radius * 0.9)), radius * 0.30,
                   radius * 0.20, segments=6)
    # a stone under the middle so the sag reads as resting on it, not floating
    L.add_ico(bm, (length * 0.02, 0.0, 0.02), radius * 0.75, subdiv=1, scale=(1.5, 1.2, 0.5), wob=0.05, seed=seed + 21)

    # mossy cap: overgrown ico blobs on the top side
    if mossy:
        n = max(5, int(length * 1.6))
        for k in range(n):
            if L.hash01("moss", k, seed) < 0.42:
                continue  # bare bark between the patches
            t = (k + 0.5) / n
            x = -length * 0.45 + length * 0.9 * t + rng.uniform(-0.1, 0.1)
            a = rng.uniform(-0.7, 0.7)
            z = radius * 1.55
            L.add_ico(bm, (x, math.sin(a) * radius * 0.6, z - radius * 0.30), radius * rng.uniform(0.14, 0.26),
                      subdiv=1, scale=(1.3, 1.2, 0.30), wob=0.03, seed=k)

    def col(co):
        # bark, ring by ring, with a pale saw-cut on the end faces and moss on top
        # (the moss blobs sit outside the bark radius; they are the only green)
        t = L.wobble(co, 3, 0.5, seed) * 0.5 + 0.5
        c = L.mix(bark, bark_d, t * 0.7)
        c = L.mix(c, bark_l, max(0.0, L.noise3(co, 0.15, seed + 2) - 0.7) * 1.5)
        # bark ridges: darker in the grooves, lighter on the ribs
        ridge = math.sin(co.x * 5.5 + math.sin(co.y * 3.0) * 1.2 + co.z * 2.0)
        c = L.mix(c, bark_d, max(0.0, -ridge) * 0.45)
        radial = math.hypot(co.y, (co.z - radius * 1.25) * 2.0) if abs(co.x) < length * 0.5 else 0.0
        if mossy and radial < radius * 0.75 and co.z > radius * 1.35:
            return L.mix(moss, (0.30, 0.38, 0.15), L.noise3(co, 0.3, seed + 8))
        if mossy:
            # moss grows on the upper half and in the low damp patches
            # moss grows in clumps on the upper bark: a patchy mask, not a blanket
            m = (max(0.0, (co.z - radius * 1.0) / max(radius, 1e-3)) * 0.35
                 + (L.noise3(co, 0.45, seed + 5) - 0.5) * 0.9)
            if m > 0.36:
                c = L.mix(c, moss, min(1.0, (m - 0.36) * 2.0) * 0.8)
        if abs(co.x) > length * 0.5 - 0.03:
            c = L.mix(wood_end, (0.50, 0.38, 0.24), L.noise3(Vector((co.y, co.z, 0)), 0.04, seed) * 0.6)
        return c

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=True)]


# ---------------------------------------------------------------- spire and mesa profiles

def _profile(mode, t, top_flat):
    """Radius multiplier (1.0 = the base radius) at height fraction t.

    mesa/cliff: a talus skirt (0-0.28), a near-vertical sandstone wall, then a flat top with a
    slightly overhanging rim cap; spire: a flared foot and an eroded head. `ledge` adds the
    horizontal bedding steps that read as strata in the silhouette.
    """
    if mode in ("mesa", "cliff"):
        if t < 0.16:
            r = 1.0 - 0.10 * (t / 0.16)          # talus skirt
        elif t < 0.93:
            r = 0.90 - 0.02 * (t - 0.16) / 0.77  # near-vertical wall
        else:
            r = top_flat                            # flat top plateau
    else:
        # a tower, not a cone: a short flared foot, a long near-vertical shaft, a broken head
        if t < 0.06:
            r = 1.0 - 0.10 * (t / 0.06)
        elif t < 0.88:
            r = 0.90 - 0.22 * (t - 0.06) / 0.82   # long near-vertical shaft
        elif t < 0.94:
            r = 0.68 + 0.06 * (t - 0.88) / 0.06   # cap slab overhang
        else:
            r = 0.74 - 0.14 * (t - 0.94) / 0.06   # blunt, broken shaft top (no pyramid point)
    return max(r, 0.03)


def _crag(bm, name, height, radius_x, radius_y, seed, mode="spire", layers=13, top_flat=0.0,
          tilt=0.03):
    """A stack of eroded rings: talus skirt, stratified wall, weathered cap.

    Radius follows _profile, the cross-section is an irregular ellipse, and two low-frequency
    radial wobbles give buttresses and fissures. Every second ring is pinched in by 3 % so the
    silhouette steps like bedding planes."""
    rng = L.rng_for(name, seed)
    seg = 22
    rings = []
    for j in range(layers + 1):
        t = j / layers
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            if mode in ("mesa", "cliff"):
                w = 1.0 + 0.13 * math.sin(a * 3 + seed * 0.7) + 0.05 * math.sin(a * 7 + seed)
                w *= 1.0 + 0.04 * math.sin(a * 11 + t * 1.3 + seed)
            else:
                w = 1.0 + 0.17 * math.sin(a * 3 + seed * 0.7 + t * 0.8) + 0.09 * math.sin(a * 7 - t * 3.0 + seed)
            w += 0.05 * L.wobble(Vector((math.cos(a) * 2, math.sin(a) * 2, t * 3)), 2, 0.8, seed)
            if mode in ("mesa", "cliff"):
                w *= 0.96 if j in (5, 9) else 1.0  # two bedding ledges up the wall
            else:
                # a hoodoo: ledges and undercuts all the way up (erosion picks the soft beds out)
                # irregular ledges that are not mirrored front-to-back: erosion is lopsided
                w *= (1.08, 0.95, 0.90, 0.99, 0.86, 1.02, 0.88, 0.94, 0.91, 1.05, 0.95, 1.00, 0.87, 0.97)[j % 14]
            rx = radius_x * _profile(mode, t, top_flat) * w
            ry = radius_y * _profile(mode, t, top_flat) * w
            if mode in ("mesa", "cliff"):
                ox, oy = tilt * height * t * t, tilt * height * t * t * 0.5
            else:
                step = math.floor(t * 3) / 3.0  # leans as three stacked blocks
                ox = tilt * height * (step + 0.15 * (t - step) * 3) * 1.6
                oy = tilt * height * (step * 0.4)
            x = math.cos(a) * rx + ox
            y = math.sin(a) * ry + oy
            z = height * t
            if mode in ("mesa", "cliff") and t > 0.93:
                z = height
            ring.append((x, y, z))
        rings.append(ring)
    L.loft(bm, rings)
    if mode in ("mesa", "cliff"):
        # a small butte on the top and a few eroded blocks along the rim sell the scale
        L.add_ico(bm, (rng.uniform(-0.35, 0.35) * radius_x, rng.uniform(-0.35, 0.35) * radius_y, height - radius_x * 0.06),
                  radius_x * 0.13, subdiv=1, scale=(1.4, 1.0, 0.55), wob=0.12, seed=seed + 2)
        for k in range(4):
            a = 2 * math.pi * k / 4 + rng.uniform(-0.5, 0.5)
            d = 0.72 + rng.uniform(0, 0.1)
            L.add_ico(bm, (math.cos(a) * radius_x * d, math.sin(a) * radius_y * d, height - 0.05),
                      radius_x * rng.uniform(0.06, 0.10), subdiv=1, scale=(1.5, 1.1, 0.55),
                      wob=0.10, seed=seed + 5 + k)
    else:
        # a tilted slab crown: the cap of the tower leans like a falling card
        slab_c = Vector((tilt * height * 1.5, tilt * height * 0.65, height * 0.985))
        # three tilted cap slabs, each leaning a different way: a broken, jagged crown
        for si, (dx, dy, rk, lean) in enumerate(((0.10, 0.0, 0.44, 0.22), (-0.16, 0.10, 0.30, -0.30),
                                                (0.02, -0.14, 0.26, 0.10))):
            verts = L.add_ico(bm, slab_c + Vector((radius_x * dx, radius_y * dy, radius_x * 0.12 * si)),
                              radius_x * rk, subdiv=1, scale=(1.1, 0.85, 0.28), wob=0.05, seed=seed + 9 + si)
            # shear the slab so it leans over the edge of the shaft
            for v in verts:
                v.co.x += (v.co.z - slab_c.z) * lean
    return rings


def build_spire(name, height, radius, seed, palette, strata=1.0):
    L.new_scene(name)
    bm = bmesh.new()
    _crag(bm, name, height, radius, radius * 0.85, seed, mode="spire", layers=14, tilt=0.07)
    # fallen slabs around the foot
    rng = L.rng_for(name, seed + 1)
    for k in range(5):
        a = 2 * math.pi * k / 5 + rng.uniform(-0.4, 0.4)
        d = radius * rng.uniform(1.15, 1.55)
        sz = radius * rng.uniform(0.26, 0.44)
        L.add_ico(bm, (math.cos(a) * d, math.sin(a) * d, sz * 0.25), sz,
                  subdiv=1, scale=(1.4, 1.1, 0.60), wob=0.10, seed=k + seed, sink=-sz * 0.15)
    # no green wash on the spires: they are bare sandstone; pale sun-bleached crowns, dark seams
    def col(co):
        c = rock_colour(palette, seed, strata=0.0)(co)
        band = math.sin((co.z + L.wobble(Vector((co.x, co.y, 0)), 2, 3.0, seed) * 0.06) / 1.1 * math.pi)
        c = L.mix(c, palette["dark"], max(0.0, band - 0.7) * 1.4)
        c = L.mix(c, palette["light"], max(0.0, -band - 0.6) * 0.8)
        t = co.z / max(height, 1e-3)
        if t > 0.85:  # the crown catches the light
            c = L.mix(c, palette["light"], (t - 0.85) * 2.5)
        return c

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=False)]


def _skirt(bm, rx, ry, depth, n=14, seed=0.0):
    """A thin apron of rock below z = 0 so the landform sits into a slope instead of on a plane."""
    ring = []
    for k in range(n):
        a = 2 * math.pi * k / n
        r = 1.0 + 0.10 * math.sin(a * 4 + seed)
        ring.append((math.cos(a) * rx * 0.96 * r, math.sin(a) * ry * 0.96 * r, -depth))
    return ring


def _talus(bm, rx, ry, seed, count=10, start=1.04, size_lo=0.06, size_hi=0.11):
    rng = L.rng_for("talus", seed)
    for k in range(count):
        a = 2 * math.pi * k / count + rng.uniform(-0.3, 0.3)
        d = rng.uniform(start, start + 0.20)
        L.add_ico(bm, (math.cos(a) * rx * d, math.sin(a) * ry * d, 0.0),
                  max(rx, ry) * rng.uniform(size_lo, size_hi), subdiv=1, scale=(1.5, 1.2, 0.65),
                  wob=0.12, seed=seed + k)


def _canyon_wall(name, height, width, depth, seed, palette, skirt=0.7):
    """A red canyon wall as a ridge of joined sandstone buttresses: 6 towers along x, each 5-7 sides,
    different heights and lean, interpenetrating so they read as one broken cliff face, with
    stratified colour and a talus foot. 2-3k tris."""
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    towers = 7
    step = width / towers
    for i in range(towers):
        sides = rng.choice((11, 12, 12, 13))
        cx = -width * 0.5 + step * (i + 0.5) + rng.uniform(-0.15, 0.15) * step
        cy = rng.uniform(-0.25, 0.25) * depth
        r = step * rng.uniform(1.05, 1.20)
        ry = r * rng.uniform(1.20, 1.55)   # deep enough to join the next tower into a ridge
        h = height * rng.uniform(0.955, 1.0) * (1.0 - 0.06 * abs(i - (towers - 1) * 0.5) / towers)
        lean = (rng.uniform(-0.04, 0.04), rng.uniform(-0.03, 0.03))
        phase = rng.uniform(0, 6.28)
        # a slight twist per level gives ledges; the crown rolls to a blunt top
        rings = []
        for t, sc in ((-skirt / max(h, 1e-3), 1.06), (0.0, 1.0), (0.18, 0.995), (0.35, 0.99),
                      (0.50, 0.985), (0.68, 1.04), (0.72, 0.98), (0.84, 0.965), (0.95, 0.95),
                      (0.97, 0.86), (1.0, 0.72)):
            ring = []
            for k in range(sides):
                a = phase + 2 * math.pi * k / sides + t * 0.05
                rr = (1.0 + 0.075 * math.sin(a * 5 + seed + i) + 0.04 * math.sin(a * 9)
                      + 0.035 * (L.hash01(seed, i, k, round(t, 2)) - 0.5))
                z = h * t
                ring.append((cx + math.cos(a) * r * sc * rr + lean[0] * max(z, 0.0),
                             cy + math.sin(a) * ry * sc * rr + lean[1] * max(z, 0.0), z))
            rings.append(ring)
        L.loft(bm, rings, close_top=True, close_bottom=False)
    _talus(bm, width * 0.5, depth, seed, count=14, start=0.92, size_lo=0.07, size_hi=0.13)
    base_col = rock_colour(palette, seed, strata=0.0, moss=(0.44, 0.45, 0.26))

    def col(co):
        c = base_col(co)
        t = co.z / max(height, 1e-3)
        if t > 0.93:  # dusty crowns
            top_c = L.mix(palette["top"], palette["light"], 0.4)
            return L.mix(top_c, (0.44, 0.45, 0.26), max(0.0, L.noise3(co, 1.6, seed + 5) - 0.6) * 0.8)
        # strata: broad bands of lighter/darker sandstone, one pair per ~1.2 m
        band = math.sin((co.z + L.wobble(Vector((co.x, co.y, 0)), 2, 3.0, seed) * 0.08) / 1.2 * math.pi)
        c = L.mix(c, palette["dark"], max(0.0, band) * 0.35)
        c = L.mix(c, palette["light"], max(0.0, -band) * 0.35)
        # vertical desert varnish streaks and pale sand washes
        streak = L.noise3(Vector((co.x * 1.6, co.y * 1.6, co.z * 0.25)), 1.0, seed + 3)
        c = L.mix(c, palette["dark"], max(0.0, streak - 0.55) * 0.9)
        c = L.mix(c, palette["light"], max(0.0, 0.40 - streak) * 0.5)
        return c

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=False)]


def _jointed_cliff(name, width, depth, height, seed, palette, skirt=0.6):
    """A natural jointed sandstone cliff: two or three big irregular rock masses of different heights
    that overlap and step back into each other (not a staircase), deep vertical joints notching every
    wall, ragged broken rims (no flat steps, no block on top) and a talus foot."""
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    # (scale, centre offset, top height, plan phase, corner count): the tiers are offset in x and y and
    # differ in size, so no tier sits centred on the one below it.
    tiers = [(1.00, (-0.22, 0.10), height * 1.00, 0.0, 18),
             (0.86, (0.34, -0.16), height * 0.72, 1.3, 16),
             (0.62, (-0.52, 0.30), height * 0.52, 2.7, 14)]
    rims = []
    for ti, (sc, off, top, ph, corners) in enumerate(tiers):
        n = corners * 2   # corner + notch pair, so joints cut into the wall between corners
        plan = []
        for k in range(n):
            a = ph + 2 * math.pi * k / n
            # irregular outline plus a hard notch every ~3 m along the wall: the vertical joint
            notch = 1.0 - 0.16 * max(0.0, math.sin(a * 7 + ph * 3 + seed * 0.3)) ** 5
            rr = (1.0 + 0.20 * math.sin(a * 2 + ph) + 0.09 * math.sin(a * 5 - ph)
                  + 0.06 * (L.hash01(seed, ti, k) - 0.5)) * notch
            plan.append((a, rr))
        z0 = -skirt if ti == 0 else top * 0.30
        # the rim height wanders 1.5 m so the silhouette is broken, never a level step
        rim_z = [top * (1.0 - 0.18 * L.hash01(seed, ti, k, 7)) - 0.25 * math.sin(2 * math.pi * k / n * 3 + ph)
                 for k in range(n)]

        def ring(z_at, shrink, extra=0.0):
            out = []
            for k, (a, rr) in enumerate(plan):
                z = z_at(k) if callable(z_at) else z_at
                tw = 0.04 * ti
                out.append(bm.verts.new((off[0] + math.cos(a + tw) * width * 0.5 * sc * rr * shrink,
                                         off[1] + math.sin(a + tw) * depth * 0.5 * sc * rr * shrink,
                                         z - extra * (1.0 - rr))))
            return out

        low = ring(z0, 1.03)
        mid = ring(z0 + (top - z0) * 0.45, 1.00)
        up = ring(top - 0.55, 0.975)
        rim = ring(lambda k: rim_z[k], 0.965)
        for ra, rb in ((low, mid), (mid, up), (up, rim)):
            for k in range(n):
                bm.faces.new((ra[k], ra[(k + 1) % n], rb[(k + 1) % n], rb[k]))
        c = bm.verts.new((off[0], off[1], top - 0.9))
        for k in range(n):
            bm.faces.new((rim[k], rim[(k + 1) % n], c))
        rims.append((off, width * 0.5 * sc, depth * 0.5 * sc, top))
    # broken blocks fallen off the joints at the foot
    for k in range(9):
        a = rng.uniform(0, 6.28)
        d = rng.uniform(0.95, 1.15)
        L.add_ico(bm, (math.cos(a) * width * 0.5 * d, math.sin(a) * depth * 0.5 * d, 0.0),
                  rng.uniform(0.22, 0.55), subdiv=1, scale=(1.6, 1.1, 0.75), wob=0.10,
                  seed=k, sink=-0.10)
    base_col = rock_colour(palette, seed, strata=0.0, moss=(0.44, 0.45, 0.26))

    def col(co):
        c = base_col(co)
        t = co.z / max(height, 1e-3)
        band = math.sin((co.z + L.wobble(Vector((co.x, co.y, 0)), 2, 3.0, seed) * 0.08) / 1.15 * math.pi)
        c = L.mix(c, palette["dark"], max(0.0, band) * 0.38)
        c = L.mix(c, palette["light"], max(0.0, -band) * 0.34)
        # desert varnish in the joints: dark vertical streaks keyed on the plan angle
        ang = math.atan2(co.y, co.x)
        joint = max(0.0, math.sin(ang * 7 + seed * 0.3)) ** 5
        c = L.mix(c, palette["dark"], joint * 0.55)
        streak = L.noise3(Vector((co.x * 1.7, co.y * 1.7, co.z * 0.22)), 1.0, seed + 3)
        c = L.mix(c, palette["dark"], max(0.0, streak - 0.55) * 0.9)
        if t > 0.80:
            c = L.mix(c, palette["top"], (t - 0.80) * 1.6)
            c = L.mix(c, (0.44, 0.45, 0.26), max(0.0, L.noise3(co, 1.6, seed + 5) - 0.62) * 0.7)
        return c

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=False)]


def _basalt_face(name, width, height, seed, palette, skirt=0.6):
    """A columnar basalt face: a wall of 5/6/7-sided vertical columns of unequal heights packed in
    three rows (about 3 m deep), bevelled broken tops, cooling-joint rings; rubble at the foot."""
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    cols = []
    for ri, y in enumerate((-1.10, -0.36, 0.36, 1.10)):
        x = -width * 0.5 + (0.35 if ri % 2 else 0.0)
        while x < width * 0.5:
            sides = rng.choice((5, 6, 6, 6, 7))
            r = rng.uniform(0.66, 0.95)
            h = height * (1.0 - 0.14 * ri) * rng.uniform(0.35, 1.0)
            tilt = (rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03))
            cx = x + rng.uniform(-0.05, 0.05)
            cy = y + rng.uniform(-0.12, 0.12)
            phase = rng.uniform(0, 6.28)
            rings = []
            # the column shuts with a flat, close-fitting top plate (a deep inset cap read as a hollow
            # pipe from the 50 degree camera), the plate 4 cm above the last shaft ring
            for t, inset in ((-skirt, 1.0), (h * 0.55, 1.0), (h - r * 0.08, 1.0),
                             (h + 0.02, 0.90), (h + 0.04, 0.55)):
                ring = []
                for k in range(sides):
                    a = phase + 2 * math.pi * k / sides
                    rr = r * inset * (1.0 + 0.05 * math.sin(a * 3 + seed))
                    ring.append((cx + math.cos(a) * rr + tilt[0] * max(t, 0.0),
                                 cy + math.sin(a) * rr + tilt[1] * max(t, 0.0), t))
                rings.append(ring)
            L.loft(bm, rings, close_top=True, close_bottom=False)
            cols.append((cx, cy, r, h))
            x += r * 1.52
    # a backing rock mass: a coarse irregular ridge just behind the column rows, so the gaps between
    # columns show basalt instead of the sky, and the face reads as one cliff
    back = []
    n = 16
    for j, (z, sc) in enumerate(((-skirt, 1.06), (height * 0.30, 1.02), (height * 0.62, 0.96),
                                 (height * 0.80, 0.82), (height * 0.84, 0.55))):
        row = []
        for k in range(n):
            a = 2 * math.pi * k / n
            rr = 1.0 + 0.05 * math.sin(a * 4 + seed)
            row.append((math.cos(a) * width * 0.52 * sc * rr,
                        -0.55 + math.sin(a) * 1.55 * sc * rr, z))
        back.append(row)
    L.loft(bm, back, close_top=True, close_bottom=False)
    for k in range(8):
        c = rng.choice(cols)
        L.add_ico(bm, (c[0] + rng.uniform(-0.6, 0.6), c[1] + rng.uniform(-0.5, 0.5), 0.0),
                  0.16, subdiv=1, scale=(1.6, 1.2, 0.7), wob=0.06, seed=k, sink=-0.04)

    def col(co):
        c = rock_colour(BASALT, seed, strata=0.0)(co)
        joint = abs(math.sin(co.z / 0.38 * math.pi))
        c = L.mix(c, BASALT["dark"], max(0.0, joint - 0.85) * 1.6)     # cooling joints
        # pale volcanic ash settles on the upper third of every column and on the broken tops
        ash = min(1.0, max(0.0, (co.z - height * 0.35) / (height * 0.65)))
        c = L.mix(c, (0.60, 0.60, 0.60), ash * 0.45)
        moss = L.noise3(co, 0.5, seed + 4)
        if moss > 0.66:
            c = L.mix(c, (0.34, 0.40, 0.20), (moss - 0.66) * 1.5)      # lichen in the damp joints
        return c

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=False)]


# ---------------------------------------------------------------- basalt columns

def build_basalt_columns(name, seed, count=7, spread=1.6, h_lo=0.8, h_hi=2.6):
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    cells = []
    for i in range(count):
        a = 2 * math.pi * i / count * 0.62 * 3 + rng.uniform(-0.3, 0.3)
        d = spread * (0.30 + 0.70 * math.sqrt((i * 0.618) % 1.0)) * rng.uniform(0.7, 1.0)
        x, y = math.cos(a) * d, math.sin(a) * d
        h = rng.uniform(h_lo, h_hi) * (0.35 + 0.65 * (i % 5) / 4.0)
        sides = rng.choice((5, 6, 6, 7))
        r = rng.uniform(0.32, 0.50)
        phase = rng.uniform(0, 6.28)
        tilt = (rng.uniform(-0.035, 0.035), rng.uniform(-0.035, 0.035))
        ring0, ring1 = [], []
        for k in range(sides):
            ang = phase + 2 * math.pi * k / sides
            rr = r * (1.0 + 0.06 * math.sin(ang * 3))
            ring0.append((x + math.cos(ang) * rr, y + math.sin(ang) * rr, -0.05))
            ring1.append((x + math.cos(ang) * rr + tilt[0] * h, y + math.sin(ang) * rr + tilt[1] * h, h))
        L.loft(bm, [ring0, ring1], close_top=True, close_bottom=False)
        cells.append((x, y, r, h))
    # shards at the foot
    for k in range(4):
        c = rng.choice(cells)
        L.add_ico(bm, (c[0] + rng.uniform(-0.4, 0.4), c[1] + rng.uniform(-0.4, 0.4), 0.05),
                  0.12, subdiv=1, scale=(1.6, 1.0, 0.5), wob=0.06, seed=k)

    def col(co):
        c = rock_colour(BASALT, seed, strata=0.4)(co)
        # horizontal cooling joints: dark rings every ~0.4 m
        joint = abs(math.sin(co.z / 0.4 * math.pi))
        c = L.mix(c, BASALT["dark"], max(0.0, joint - 0.85) * 2.5)
        # a cool blue-grey sheen on up-facing fracture planes
        # tops of the columns catch pale ash and the cool light; the shafts stay near-black
        c = L.mix(c, (0.47, 0.48, 0.50), min(1.0, max(0.0, co.z - 0.3) * 0.25))
        if co.z > 0.1:
            c = L.mix(c, (0.42, 0.44, 0.47), max(0.0, L.noise3(co, 0.7, seed + 4) - 0.75) * 1.2)
        return c

    L.paint(bm, col)
    return [L.finalize(bm, name, smooth=False)]


# ---------------------------------------------------------------- boulder piles

def build_boulder_pile(name, seed, count=7, spread=1.3, size=0.9, flat=True):
    rng = L.rng_for(name, seed)
    L.new_scene(name)
    bm = bmesh.new()
    placed = []
    for i in range(count):
        for _try in range(40):
            a = rng.uniform(0, 2 * math.pi)
            d = spread * 0.85 * (rng.random() ** 0.8)
            s = size * rng.uniform(0.35, 1.0) * (1.0 - 0.30 * d / max(spread, 1e-3))
            x, y = math.cos(a) * d, math.sin(a) * d
            ok = True
            for (px, py, ps) in placed:
                if math.hypot(px - x, py - y) < (ps + s) * 0.50:
                    ok = False
                    break
            if not ok:
                continue
            if ok:
                z = s * (0.30 if flat else 0.6)
                if placed and rng.random() < 0.7:  # stack one on a neighbour: it is a pile
                    px, py, ps = rng.choice(placed)
                    x, y, z = px + rng.uniform(-0.15, 0.15), py + rng.uniform(-0.15, 0.15), ps * 0.9 + s * 0.15
                    s *= 0.65
                L.add_ico(bm, (x, y, z), s, subdiv=2 if s > size * 0.7 else 1,
                          scale=(1.0, rng.uniform(0.75, 1.0), rng.uniform(0.55, 0.85)),
                          wob=0.12 * s, seed=i * 3.1)
                placed.append((x, y, s))
                break
    L.paint(bm, rock_colour(GRANITE, seed, strata=0.0, moss=(0.46, 0.50, 0.32)))
    return [L.finalize(bm, name, smooth=False)]


# ---------------------------------------------------------------- registry
# Sizes: task ranges. Mounds 2-3.5 m tall; logs 4-7 m long; spires 5-9 m; mesas 8-15 m wide.
BUILDERS = {
    "termite_mound_a": lambda: build_termite_mound("termite_mound_a", 3.0, 0.95, 21, towers=2),
    "termite_mound_b": lambda: build_termite_mound("termite_mound_b", 3.38, 1.05, 22, towers=3),
    "fallen_log_moss": lambda: build_fallen_log("fallen_log_moss", 4.5, 0.34, 23, mossy=True),
    "fallen_log_dry": lambda: build_fallen_log("fallen_log_dry", 5.8, 0.40, 24, mossy=False),
    "rock_spire_a": lambda: build_spire("rock_spire_a", 5.5, 1.15, 31, SANDSTONE, strata=1.0),
    "rock_spire_b": lambda: build_spire("rock_spire_b", 8.6, 1.55, 32, SANDSTONE, strata=1.0),
    # widths measured through the buttress wobble (~2.9x the radius parameter): 12.2, 12.5, 13.4 m
    # three different silhouettes (spec 26): fluted red canyon wall, stepped terrace, columnar basalt
    "mesa_sandstone": lambda: _canyon_wall("mesa_sandstone", 9.0, 11.0, 5.4, 41, SANDSTONE, skirt=0.7),
    "cliff_chunk_red": lambda: _jointed_cliff("cliff_chunk_red", 12.5, 6.8, 7.4, 43, SANDSTONE, skirt=0.6),
    "mesa_basalt": lambda: _basalt_face("mesa_basalt", 10.5, 8.5, 42, BASALT, skirt=0.7),
    "basalt_columns": lambda: build_basalt_columns("basalt_columns", 51, count=9, spread=1.7, h_lo=0.55, h_hi=2.4),
    "boulder_pile_a": lambda: build_boulder_pile("boulder_pile_a", 61, count=9, spread=1.15, size=0.75),
    "boulder_pile_b": lambda: build_boulder_pile("boulder_pile_b", 62, count=14, spread=1.55, size=0.95),
}
