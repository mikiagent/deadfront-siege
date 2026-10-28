"""Raw and refined materials: wood, stone, ore, metal, bone, hide, fibre and rare finds."""
from kit import *  # noqa: F401,F403


# ---------------------------------------------------------------- wood

def branch():
    w = bark("#6b4a2c", "#4a3019")
    tube([(0, 0, -1.3), (0.05, 0, -0.5), (-0.04, 0, 0.3), (0.05, 0, 1.2)], 0.09, w, segs=10, taper=(1.0, 0.55))
    tube([(0.0, 0, 0.0), (0.3, 0, 0.45), (0.62, 0, 0.75)], 0.055, w, segs=8, taper=(1.0, 0.5))
    tube([(-0.03, 0, -0.55), (-0.3, 0, -0.3), (-0.5, 0, -0.05)], 0.045, w, segs=8, taper=(1.0, 0.5))
    leaf(0.55, 0.2, loc=(0.62, 0, 0.75), rot=(0, 35, 0), curl=0.1)
    leaf(0.5, 0.18, loc=(0.05, 0, 1.2), rot=(0, -15, 0), curl=0.1)
    leaf(0.45, 0.17, loc=(-0.5, 0, -0.05), rot=(0, -60, 0), curl=0.1)
    lean(-25)


def _log(r, length, bark_m, end_c, loc=(0, 0, 0), rot=(0, 90, 0), parent=None, stub=False):
    g = group(loc=loc, rot=rot, parent=parent)
    cyl(r, length, m=bark_m, segs=22, parent=g)
    end = mat(end_c, 0.7, color2="#7a5530", tex="rings", scale=3.5, bump=0.1)
    for s in (-1, 1):
        cyl(r * 0.9, 0.04, loc=(0, 0, s * length / 2), m=end, segs=22, parent=g)
    if stub:
        cyl(r * 0.28, r * 0.9, loc=(r * 0.9, 0, length * 0.15), rot=(0, 75, 0), m=bark_m, segs=10, r2=r * 0.2, parent=g)
    return g


def wood_log():
    _log(0.5, 1.9, bark("#5b3d24", "#3a2614"), "#d4a066")
    turn(52)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def pine_log():
    """Pine log: one thick log of orange-red scaly pine bark, its cut ends showing pale rings, with a
    sprig of pine needles tied to it: orange bark, unlike the wood log's grey-brown stack."""
    b = mat("#a85a30", 0.9, color2="#6a3214", tex="voronoi", scale=12.0, bump=0.8, ramp=(0.1, 0.5))
    _log(0.42, 1.9, b, "#f0d0a0", loc=(0, 0.1, 0.0), stub=True)
    needle = mat("#2e5a3a", 0.6, color2="#1e4028", tex="wave", scale=14.0)
    tw = wood("#8a5a33", "#5e3a1e")
    g = group(loc=(0.15, -0.35, 0.3), rot=(0, 0, 12))
    tube([(-0.7, 0, 0), (0, 0, 0.1), (0.7, 0, 0.0)], 0.035, tw, segs=6, parent=g)
    for k in range(9):
        x = -0.6 + 0.15 * k
        for s2 in (-1, 1):
            tube([(x, 0, 0.05), (x + 0.1, s2 * 0.12, 0.2)], 0.012, needle, segs=3, parent=g)
    tube(arc((0, 0, 0), 0.47, 0, 360, 20, plane="xz", y=0)[:-1], 0.035, rope_m(), segs=5, closed=True,
         parent=group(loc=(0.55, 0, 0), rot=(0, 0, 90)))
    turn(48)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def plank():
    w = wood("#c48d55", "#93602f")
    box((2.6, 0.13, 0.55), loc=(0, 0.12, 0.12), m=w, bev=0.025)
    box((2.6, 0.13, 0.55), loc=(0.12, -0.08, -0.12), rot=(0, 0, 0), m=w, bev=0.025)
    turn(10)
    lean(-28)


def split_wood():
    """Quartered firewood: light split faces with ring grain, bark on the round side."""
    inner = mat("#e0b07a", 0.7, color2="#a87440", tex="rings", scale=4.0, bump=0.1)
    b = bark("#5b3d24", "#3a2614")
    for y, z, spin in ((-0.4, 0.0, 0), (0.4, 0.0, 10), (0.0, 0.62, 180)):
        g = group(loc=(0, y, z), rot=(spin, 0, 90))
        arc_pts = [(math.cos(math.radians(a)) * 0.62, math.sin(math.radians(a)) * 0.62) for a in range(45, 136, 9)]
        prism([(0, 0)] + arc_pts, 1.9, m=inner, bev=0.02, parent=g)
        outer = [(math.cos(math.radians(a)) * 0.7, math.sin(math.radians(a)) * 0.7) for a in range(45, 136, 9)]
        prism(arc_pts + outer[::-1], 1.86, m=b, bev=0.0, parent=g)
    turn(-55)
    turn(10, "X")


def pillar():
    """Pillar: a squared timber post with a carved ring at the top, a lap-joint notch cut in each
    face, iron bands with bolts near both ends and rope wrapped round the middle."""
    w = mat("#a8743f", 0.75, color2="#6f4520", tex="wave", scale=5.0, bump=0.35)
    box((0.5, 0.5, 2.6), m=w, bev=0.035)
    # Lap-joint notches: a shallow cut on the front and the side, where a beam would sit.
    for (x, y, sx, sy) in ((0, -0.25, 0.5, 0.01), (-0.25, 0, 0.01, 0.5)):
        box((sx, sy, 0.3), loc=(x, y, 0.42), m=mat("#7a5226", 0.85, color2="#4e3214", tex="noise", scale=9.0), bev=0.0)
    iron = metal("#6a6e74", 0.4)
    for z in (-0.98, 0.98):
        box((0.58, 0.58, 0.13), loc=(0, 0, z), m=iron, bev=0.02)
        for (x, y) in ((0.3, 0), (-0.3, 0), (0, 0.3), (0, -0.3)):
            ball(0.05, loc=(x, y, z + 0.01), m=mat("#94989e", 0.3, metal=0.9), sub=2)
    # Carved ring under the top band.
    cyl(0.36, 0.08, loc=(0, 0, 0.8), m=w, segs=4, smooth=False, rot=(0, 0, 45))
    # Rope wrapped round the middle.
    for k in range(4):
        tube(arc((0, 0, 0), 0.36, 0, 360, 24, plane="xy", y=-0.15 + 0.1 * k)[:-1], 0.035, rope_m(), segs=5,
             closed=True)
    turn(28)
    lean(-15)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def bamboo():
    g_m = mat("#86b83f", 0.35, color2="#5e8f2a", tex="wave", scale=6.0, coat=0.4)
    node = mat("#c9c86a", 0.45)
    for x, h, tilt in ((-0.25, 2.3, 4), (0.25, 2.0, -6), (0.0, 1.6, 2)):
        g = group(loc=(x, -abs(x) * 0.6, 0), rot=(0, tilt, 0))
        n = int(h / 0.55)
        for i in range(n):
            cyl(0.17, 0.53, loc=(0, 0, -h / 2 + 0.55 * i + 0.27), m=g_m, segs=16, parent=g)
            cyl(0.19, 0.05, loc=(0, 0, -h / 2 + 0.55 * i + 0.55), m=node, segs=16, parent=g)
    leaf(0.7, 0.16, loc=(0.25, -0.1, 0.65), rot=(0, 50, 0), m=mat("#6fae3a", 0.5))
    leaf(0.6, 0.14, loc=(-0.25, 0, 0.9), rot=(0, -45, 0), m=mat("#6fae3a", 0.5))


# ---------------------------------------------------------------- stone and ore

def stone_item():
    m = stone()
    rock(1.0, scl=(1.25, 0.95, 0.72), m=m, jitter=0.16, sub=2)
    rock(0.45, loc=(1.05, -0.35, -0.25), m=m, jitter=0.2, sub=1)


def flint():
    m = mat("#4a4f5c", 0.25, color2="#2d313a", tex="voronoi", scale=3.0, bump=0.5, spec=0.7)
    cortex = mat("#d9d2c0", 0.9, color2="#b8af98", tex="noise", scale=6.0, bump=0.3)
    rock(0.9, scl=(1.2, 0.8, 0.9), m=m, jitter=0.3, sub=1)
    rock(0.5, loc=(-0.2, 0.1, 0.65), scl=(1.0, 0.9, 0.5), m=cortex, jitter=0.25, sub=1)
    rock(0.38, loc=(1.05, -0.3, -0.35), scl=(1.3, 0.6, 0.8), m=m, jitter=0.35, sub=0)


def obsidian():
    """Obsidian: black volcanic glass, sharp faceted shards with bright chipped edges and a violet
    sheen, stood on a pale grey stone so the black glass does not vanish into the dark slot."""
    glass = mat("#1e1c26", 0.05, color2="#3e3852", tex="voronoi", scale=6.0, bump=0.15, coat=1.0, spec=0.9,
                emit="#6a5aa0", emit_strength=0.35)
    edge = mat("#8a82b0", 0.1, color2="#5a5480", tex="noise", scale=3.0, coat=1.0)
    for (p_, r, scl, rot_) in (((0, 0, 0.35), 0.55, (0.75, 0.6, 2.0), (0, 8, 0)),
                                ((-0.5, 0.1, -0.05), 0.45, (0.8, 0.6, 1.5), (0, -28, 0)),
                                ((0.5, -0.05, -0.2), 0.4, (0.85, 0.6, 1.2), (0, 35, 0))):
        rock(r, loc=p_, scl=scl, m=glass, jitter=0.18, sub=1, rot=rot_)
        tube([(p_[0], p_[1] - r * 0.5, p_[2] - r * scl[2] * 0.85),
              (p_[0] + 0.05, p_[1] - r * 0.58, p_[2] + r * scl[2] * 0.85)], 0.024, edge, segs=4)
    rock(0.72, loc=(0, 0.28, -0.9), scl=(1.35, 0.9, 0.35), m=stone("#a8a8a2", "#74746e"), jitter=0.1, sub=2)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def sandstone():
    cols = ("#dcb47c", "#c99a5e", "#e3c08a")
    for i, z in enumerate((-0.5, -0.1, 0.3)):
        box((1.6 - 0.25 * i, 1.1 - 0.12 * i, 0.4), loc=(0.08 * i, 0, z), rot=(0, 0, 6 * i),
            m=stone(cols[i], "#b07f45"), bev=0.07)
    turn(22)


def lava():
    m = mat("#2b2522", 0.8, color2="#3d332c", tex="noise", scale=4.0, bump=0.6,
            emit="#ff5a14", emit_strength=10.0, emit_mask=2.5)
    rock(1.0, scl=(1.2, 0.95, 0.8), m=m, jitter=0.18, sub=2)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def _ore(nug_m, host=None, n=5, big=0.24):
    rock(1.0, scl=(1.25, 0.95, 0.75), m=host or stone("#7a736a", "#4f4a44"), jitter=0.15, sub=2)
    spots = [(-0.5, -0.62, 0.25), (0.3, -0.7, 0.1), (0.75, -0.4, 0.4), (-0.1, -0.45, 0.6), (0.55, -0.15, 0.7),
             (-0.75, -0.3, -0.1)]
    for i, p in enumerate(spots[:n]):
        rock(big * (1.0 - 0.12 * (i % 3)), loc=p, m=nug_m, jitter=0.3, sub=0)


def ore():
    _ore(metal("#c9a85a", 0.3))
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def copper_ore():
    _ore(metal("#d07a3e", 0.3))
    for p in [(-0.2, -0.75, -0.2), (0.9, -0.1, 0.0)]:
        rock(0.16, loc=p, m=mat("#3fae8c", 0.5), jitter=0.3, sub=0)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def silver_ore():
    _ore(metal("#e4e8ee", 0.15), host=stone("#5c6068", "#3a3d44"), n=6)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def black_iron():
    """Black iron: a rust-red host rock with big blocky gunmetal crystals growing out of it, cubic
    like magnetite, their polished faces catching a cold blue-white glint against the dark slot.
    Unlike obsidian's violet glass shards (review: dark crystal, not told from obsidian; the first
    redo's crystals were too small and too dark to read)."""
    host = mat("#7a4030", 0.9, color2="#4a241a", tex="noise", scale=6.0, bump=0.6)
    rock(0.9, loc=(0, 0.15, -0.25), scl=(1.3, 1.0, 0.7), m=host, jitter=0.16, sub=2)
    xtal = mat("#4a505c", 0.18, metal=1.0, color2="#8a94a8", tex="noise", scale=4.0, bump=0.1)
    for (x, y, z, e, rot) in ((-0.2, -0.25, 0.35, 0.62, (20, 35, 15)), (0.45, -0.3, 0.1, 0.44, (-10, 20, 40)),
                               (-0.65, -0.15, -0.05, 0.36, (30, -15, 10)), (0.2, -0.55, -0.35, 0.3, (15, 45, -20)),
                               (0.75, 0.0, 0.35, 0.26, (40, 10, 30))):
        box((e, e, e), loc=(x, y, z), rot=rot, m=xtal, bev=0.02)
    rust = mat("#c86a2a", 0.7, color2="#8a3e14", tex="noise", scale=9.0, bump=0.3)
    for p_ in ((0.75, -0.35, -0.3), (-0.85, -0.25, -0.35), (-0.3, -0.6, -0.4)):
        rock(0.11, loc=p_, m=rust, jitter=0.3, sub=0)
    turn(10)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def metal_shard():
    """Metal shard: a jagged piece torn off a riveted plate, its ripped edge bright bare metal, a
    line of rivets down the clean edge, lying over a smaller torn-off corner."""
    plate = mat("#d2d8de", 0.3, metal=0.9, color2="#9aa2aa", tex="noise", scale=4.0, bump=0.08)
    bare = mat("#ffffff", 0.12, metal=0.95, color2="#d8e0e8", tex="noise", scale=4.0, bump=0.03)
    rivet = mat("#5e666e", 0.35, metal=0.9, tex="noise", scale=8.0)
    edge_pts = [(-0.35, 1.1), (-0.32, 0.55), (-0.38, 0.0), (-0.32, -0.55), (-0.36, -0.95)]
    rip_pts = [(0.1, -1.0), (0.5, -0.72), (0.22, -0.48), (0.68, -0.15), (0.32, 0.1), (0.75, 0.45),
               (0.38, 0.6), (0.62, 0.9), (0.15, 1.05), (-0.1, 1.22)]
    prism(edge_pts + rip_pts, 0.12, m=plate, bev=0.02,
          deform=lambda co: co.__setitem__(1, co.y + 0.05 * math.sin(co.z * 5.0)))
    for z in (0.8, 0.3, -0.2, -0.7):
        cyl(0.075, 0.06, loc=(-0.24, -0.07, z), rot=(90, 0, 0), m=rivet, segs=10)
    rip = [(0.1, -1.0), (0.5, -0.72), (0.22, -0.48), (0.68, -0.15), (0.32, 0.1), (0.75, 0.45), (0.38, 0.6),
           (0.62, 0.9), (0.15, 1.05), (-0.1, 1.22)]
    tube([(x, -0.02, z) for x, z in rip], 0.04, bare, segs=5)
    prism([(-0.55, 0.3), (-0.05, 0.45), (0.25, 0.1), (0.1, -0.25), (-0.4, -0.3)], 0.1, loc=(0.15, -0.3, -0.5),
          rot=(0, 0, 18), m=plate, bev=0.02)
    lean(-18)
    turn(20)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def _ingot(c, rough=0.28, shape="bar"):
    """An ingot stack. shape: 'bar' (tapered cast bar), 'loaf' (a flat rounded cast loaf, the
    generic ingot)."""
    m = metal(c, rough)
    if shape == "loaf":
        # Two loaves side by side, one on top: low, rounded, cast in a shallow hollow.
        for loc in ((0, -0.33, 0), (0, 0.33, 0), (0, 0, 0.24)):
            box((1.15, 0.58, 0.22), loc=loc, m=m, bev=0.1, taper=(0.94, 0.92))
        for loc in ((0, -0.33, 0), (0, 0.33, 0), (0, 0, 0.24)):
            box((0.9, 0.4, 0.02), loc=(loc[0], loc[1], loc[2] + 0.11), m=mat("#7a808a", 0.6), bev=0.02)
    else:
        for loc, rot_ in (((0, -0.32, 0), 0), ((0, 0.32, 0), 0), ((0, 0, 0.36), 12)):
            box((1.2, 0.56, 0.3), loc=loc, rot=(0, 0, rot_), m=m, bev=0.05, taper=(0.8, 0.72))
    turn(24)
def ingot():
    """A generic ingot: a rounded loaf of pale grey metal, cast in a hollow, without sharp edges, so
    it reads apart from the iron and steel bars."""
    _ingot("#9ea4ae", 0.42, shape="loaf")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def copper_ingot():
    _ingot("#c8743c")


def bronze_ingot():
    _ingot("#c99a3e", 0.3)


def iron_ingot():
    """Rough-cast iron: three dark blue-grey bars, mottled cast faces and blunt, uneven ends."""
    m = mat("#5a5e66", 0.6, metal=0.8, color2="#40444c", tex="noise", scale=14.0, bump=0.45, ramp=(0.3, 0.7))
    for loc in ((0, -0.3, 0.0), (0, 0.3, 0.0), (0, 0, 0.3)):
        box((1.2, 0.56, 0.3), loc=loc, m=m, bev=0.06, taper=(0.84, 0.76))
        for s in (-1, 1):
            box((0.18, 0.5, 0.24), loc=(loc[0] + s * 0.56, loc[1], loc[2] - 0.01), m=m, bev=0.07)
    turn(24)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def steel_ingot():
    """Steel: bright polished bars, sharp true edges, a cold blue sheen and a stamped mark on top."""
    m = mat("#dfe8f2", 0.1, metal=0.95, color2="#8fa0b4", tex="noise", scale=5.0, bump=0.03)
    for loc in ((0, -0.33, 0), (0, 0.33, 0), (0, 0, 0.36)):
        box((1.24, 0.56, 0.3), loc=loc, m=m, bev=0.012, taper=(0.9, 0.88))
        tube([(-0.56, loc[1] - 0.26, loc[2] + 0.16), (0.56, loc[1] - 0.26, loc[2] + 0.16)], 0.012,
             mat("#f4f8ff", 0.05, metal=1.0), segs=4)
    box((0.4, 0.2, 0.02), loc=(0, 0, 0.53), m=mat("#4e5a68", 0.3), bev=0.004)
    turn(24)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def charcoal():
    m = mat("#1e1e20", 0.55, color2="#3a3a3e", tex="voronoi", scale=5.0, bump=0.4, spec=0.6)
    for p, r, s in (((0, 0, 0), 0.6, (1.3, 0.9, 0.8)), ((0.85, -0.1, -0.15), 0.4, (1.2, 1.0, 0.8)),
                    ((-0.7, 0.1, -0.2), 0.42, (1.0, 1.0, 0.9))):
        rock(r, loc=p, scl=s, m=m, jitter=0.2, sub=1)
    ember = mat("#2a1e1a", 0.6, emit="#ff5a14", emit_strength=6.0, emit_mask=4.0)
    rock(0.3, loc=(0.2, -0.45, 0.35), m=ember, jitter=0.2, sub=1)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


# ---------------------------------------------------------------- bone and creature parts

def _bone(length, r, knob, m, loc=(0, 0, 0), rot=(0, 0, 0), bend=0.0, parent=None):
    g = group(loc=loc, rot=rot, parent=parent)
    pts = [(0, 0, -length / 2), (bend, 0, 0), (0, 0, length / 2)]
    tube(pts, r, m, segs=14, parent=g)
    for z in (-length / 2, length / 2):
        for dx in (-knob * 0.7, knob * 0.7):
            ball(knob, loc=(dx, 0, z + (0.1 if z > 0 else -0.1) * knob), m=m, sub=3, parent=g)
    return g


def bone():
    _bone(1.8, 0.16, 0.26, bonem())
    lean(-45)


def raptor_bone():
    _bone(2.2, 0.13, 0.22, bonem("#d8c7a2"), bend=0.18)
    lean(-40)


def dense_bone():
    """Dense bone: a heavy, short limb bone with thick knobbly ends, pitted and grey-brown, visibly
    heavier and stubbier than the slim white bone."""
    m = mat("#c0aa80", 0.8, color2="#8a7248", tex="noise", scale=5.0, bump=0.8, ramp=(0.3, 0.75))
    cyl(0.24, 1.2, m=m, rot=(0, 90, 0))
    for s in (-1, 1):
        for (dy, dz) in ((-0.2, 0.14), (0.2, 0.14), (0.0, -0.22)):
            blob(0.24, loc=(s * 0.62, dy, dz), m=m, scl=(1.0, 1.0, 1.0), amp=0.28, sub=2)
        blob(0.2, loc=(s * 0.76, 0, 0), m=m, scl=(0.8, 1.2, 1.1), amp=0.3, sub=2)
    for k in range(6):  # pits and scars
        rock(0.05, loc=(-0.4 + 0.16 * k, -0.2, 0.1 * (k % 2) - 0.05), m=mat("#7a6440", 0.9), jitter=0.4, sub=0)
    lean(-40)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def raptor_talon():
    """Sickle Claw (velociraptor, deinonychus, utahraptor): the raptor's hooked second-toe claw,
    a tight blade-thin sickle of dark keratin on its pale toe bone (BONEPARTS: the old talon read as
    a horn)."""
    pts = arc((0.0, 0, 0.0), 1.0, 200, 20, 18)
    claw = mat("#2e2620", 0.3, color2="#cbb48a", tex="noise", scale=1.5, coat=0.6, ramp=(0.35, 0.9))
    ob = tube(pts, 0.3, claw, segs=14, taper=(1.0, 0.03))
    ob.scale = (1.0, 0.55, 1.0)  # blade-thin side to side
    toe = bonem("#e2d2b0")
    blob(0.3, loc=(pts[0][0] - 0.05, 0, pts[0][2] - 0.05), scl=(1.0, 0.8, 0.9), m=toe, amp=0.08)
    tube([(pts[0][0] - 0.1, 0, pts[0][2] - 0.1), (pts[0][0] - 0.25, 0, pts[0][2] - 0.75)], 0.17, toe, segs=12)
    ball(0.21, loc=(pts[0][0] - 0.27, 0, pts[0][2] - 0.82), m=toe, sub=3)
    lean(-20)


def armor_scute():
    """Armor scute: an osteoderm off a big animal's back: a thick oval bone plate, pitted, with a
    tall keel fin along its length rising to a blunt point and a darker horn-brown rim; a smaller
    scute overlaps behind it (review: a flat plate, no bony texture; the first redo read as a pale
    stone, a hexagon with radial ridges as a game tile)."""
    bone = mat("#e2d4b0", 0.6, color2="#a8946c", tex="noise", scale=9.0, bump=0.9, ramp=(0.35, 0.75))
    rim = mat("#7a5a36", 0.7, color2="#5a3e22", tex="noise", scale=8.0, bump=0.3)
    keel = mat("#f0e4c4", 0.5, color2="#d0c09a", tex="noise", scale=10.0, bump=0.2)

    def scute(loc, sc, rz):
        g = group(loc=loc, rot=(0, 0, rz))
        oval = [(math.cos(2 * math.pi * k / 12) * (1.0 + 0.06 * ((k * 5) % 3)) * sc,
                 math.sin(2 * math.pi * k / 12) * 0.68 * sc) for k in range(12)]
        # No bevel modifier here: on these 12-gon prisms it put out faces in a different order each run
        # (and moved two verts by 1e-9), which flipped a pixel or three. The rim sits 0.01 in from the
        # bone's back face so no two faces are coplanar (a coplanar pair is a ray-hit tie).
        prism([(x * 1.07, z * 1.1) for x, z in oval], 0.12 * sc, loc=(0, 0.03 * sc, 0), m=rim, bev=0, parent=g)
        prism(oval, 0.2 * sc, m=bone, bev=0, parent=g)
        # Keel fin: a thick wedge along the long axis, highest just behind the middle.
        prism([(-0.85 * sc, 0.0), (-0.1 * sc, 0.5 * sc), (0.25 * sc, 0.55 * sc), (0.85 * sc, 0.0)], 0.16 * sc,
              loc=(0, -0.12 * sc, 0), rot=(90, 0, 0), m=keel, bev=0, parent=g)
    scute((0.5, 0.35, 0.55), 0.7, 14)
    scute((-0.1, 0, -0.15), 1.0, -6)
    turn(-30, "X")
    turn(-50)  # three-quarter view so the keel stands out in profile
    upright()  # flat item: diagonal so the slot can lift it above its top edge



# BONEPARTS: species bone parts, each shaped like the real piece (owner 2026-10-28: "the shrimp-like
# skeleton symbols have to go"). Natural bone, horn and keratin colours (spec 35), never rarity colours.

def _limb(length, r, m, head=0.34, flare=1.0):
    """A limb bone: a shaft with a ball head on a short neck at the top and two condyles at the foot."""
    tube([(0, 0, -length / 2), (0.05 * length, 0, 0), (0, 0, length / 2)], r, m, segs=14)
    blob(head, loc=(-0.16, 0, length / 2 + head * 0.55), m=m, amp=0.06, sub=3)  # head on the neck
    blob(head * 0.7, loc=(0.2, 0, length / 2 + head * 0.15), m=m, amp=0.12, sub=2)  # trochanter
    for dx in (-0.6, 0.6):
        blob(head * 0.8 * flare, loc=(dx * head, 0, -length / 2 - head * 0.25), m=m, scl=(1.0, 1.1, 0.9), amp=0.08, sub=3)


def hollow_bone():
    """Hollow Bone (compsognathus, coelophysis, gallimimus, dilophosaurus): a thin-walled theropod
    shin bone snapped across, the open end showing the hollow inside."""
    m = mat("#efe6cf", 0.5, color2="#d6c8a4", tex="noise", scale=6.0, bump=0.15)
    tube([(0, 0, -1.1), (0.08, 0, 0), (0, 0, 1.0)], 0.15, m, segs=16)
    for dx in (-0.12, 0.12):
        ball(0.17, loc=(dx, 0, -1.15), m=m, sub=3)
    tube([(0, 0, 0.98), (0, 0, 1.1)], 0.15, m, segs=16)  # the snapped rim
    cyl(0.1, 0.03, loc=(0, 0, 1.1), m=mat("#3a2c22", 0.9), segs=16)  # the hollow, dark and dry
    lean(-38)


def large_leg_bone():
    """Large Leg Bone (big dinosaurs): a massive weathered thighbone with a ball head and two
    condyles, tan and pitted, thicker and darker than the small ivory Leg Bone."""
    m = mat("#d9c39a", 0.75, color2="#9c8259", tex="noise", scale=5.0, bump=0.6, ramp=(0.3, 0.8))
    _limb(2.0, 0.22, m, head=0.36)
    for k in range(5):
        rock(0.04, loc=(0.24, -0.16, -0.6 + 0.28 * k), m=mat("#7a6440", 0.9), jitter=0.4, sub=0)
    lean(-42)


def stout_leg_bone():
    """Stout Leg Bone (protoceratops, zebraceratops): a short, thick ceratopsian limb bone with
    wide flared ends."""
    m = mat("#e8dabc", 0.6, color2="#bfa97f", tex="noise", scale=6.0, bump=0.3)
    lathe([(0.0, -0.95), (0.42, -0.92), (0.46, -0.75), (0.3, -0.5), (0.22, 0.0), (0.3, 0.5),
           (0.48, 0.78), (0.44, 0.94), (0.0, 0.97)], m=m, scl=(1.0, 0.8, 1.0))
    lean(-40)


def brow_horn():
    """Brow Horn (triceratops, styracosaurus, zebraceratops): a long curved keratin horn, dark at the
    tip, on its rough bony horn-core base."""
    sheath = mat("#4e4034", 0.4, color2="#b19a76", tex="noise", scale=1.2, bump=0.2, coat=0.3, ramp=(0.3, 0.7))
    pts = arc((-1.6, 0, -0.9), 1.9, 0, 52, 14)
    tube(pts, 0.36, sheath, segs=18, taper=(1.0, 0.03))
    core = mat("#d8c8a4", 0.85, color2="#9c8660", tex="noise", scale=7.0, bump=0.9)
    blob(0.42, loc=pts[0], scl=(1.1, 1.1, 0.55), m=core, amp=0.25, sub=3)
    lean(-8)


def tail_spike():
    """Tail Spike (stegosaurus): a thagomizer pair, two long bony spikes splayed from one knobbed base."""
    m = mat("#e2d2ae", 0.55, color2="#8f7650", tex="noise", scale=4.0, bump=0.4, ramp=(0.25, 0.85))
    for a in (-13, 13):
        r = math.radians(a)
        tube([(0, 0, -0.9), (1.1 * math.sin(r), 0, -0.9 + 1.1 * math.cos(r)),
              (2.1 * math.sin(r) * 1.1, 0, -0.9 + 2.1 * math.cos(r))], 0.33, m, segs=16, taper=(1.0, 0.03))
    blob(0.42, loc=(0, 0, -0.95), scl=(1.4, 0.9, 0.8), m=mat("#c7b088", 0.8, color2="#8a7250", tex="noise",
                                                             scale=6.0, bump=0.8), amp=0.2, sub=3)
    lean(-24)


def tail_club():
    """Tail Club (ankylosaurus): the bony tail knob, two fused lobes, pitted and brown, on the stiff
    vertebral handle."""
    club = mat("#a68d68", 0.8, color2="#5e4a32", tex="voronoi", scale=7.0, bump=1.0, ramp=(0.2, 0.7))
    for dx in (-0.42, 0.42):
        blob(0.55, loc=(dx, 0, 0.45), scl=(1.0, 0.8, 0.85), m=club, amp=0.12, sub=3)
    blob(0.42, loc=(0, -0.05, 0.75), scl=(1.0, 0.8, 0.7), m=club, amp=0.12, sub=3)
    shaft = mat("#cdb58e", 0.7, color2="#8e7550", tex="noise", scale=6.0, bump=0.4)
    tube([(0, 0, 0.1), (0, 0, -1.4)], 0.2, shaft, segs=14, taper=(1.0, 0.75))
    for k in range(4):  # vertebra rings
        cyl(0.22 - 0.012 * k, 0.07, loc=(0, 0, -0.2 - 0.32 * k), m=shaft, segs=14)
    lean(-35)


def _plate(outline, depth, face, rim, grooves, groove_m):
    prism([(x * 1.05, z * 1.04) for x, z in outline], depth * 0.6, loc=(0, 0.02, 0), m=rim, bev=0)
    prism(outline, depth, m=face, bev=0)
    for (p0, p1) in grooves:  # blood-vessel grooves, seated on the face the camera sees
        tube([(p0[0], -depth / 2 - 0.005, p0[1]), (p1[0], -depth / 2 - 0.005, p1[1])], 0.025, groove_m, segs=6,
             taper=(1.0, 0.3))


def dorsal_plate():
    """Dorsal Plate (stegosaurus): a tall, thin, rounded-diamond back plate with a rough root and
    radiating vessel grooves, bone cream warming to a rust-brown rim."""
    out = [(-0.3, -1.0), (0.3, -1.0), (0.8, -0.3), (0.85, 0.2), (0.5, 0.75), (0.0, 1.25),
           (-0.5, 0.75), (-0.85, 0.2), (-0.8, -0.3)]
    face = mat("#e8d4aa", 0.6, color2="#a8683e", tex="noise", scale=2.0, bump=0.3, ramp=(0.4, 0.75))
    rim = mat("#8c5a36", 0.7, color2="#6a3e22", tex="noise", scale=6.0, bump=0.2)
    gr = [((0.0, -0.75), (dx, 0.75)) for dx in (-0.55, -0.2, 0.2, 0.55)]
    _plate(out, 0.16, face, rim, gr, mat("#9a6a44", 0.7))
    blob(0.3, loc=(0, 0, -1.0), scl=(1.4, 0.6, 0.45), m=mat("#cbb48a", 0.9, color2="#8a7250", tex="noise",
                                                             scale=8.0, bump=0.8), amp=0.25, sub=2)
    turn(-20)
    upright()


def frill_plate():
    """Frill Plate (ceratopsians): a fan of frill bone with a row of pointed epoccipital knobs along
    its rim, cream with an olive-brown edge."""
    n = 14
    out = [(math.cos(math.pi * k / n) * 1.0, math.sin(math.pi * k / n) * 0.8 - 0.35) for k in range(n + 1)]
    out += [(-0.35, -0.55), (0.35, -0.55)]
    face = mat("#e6d6b2", 0.6, color2="#a89062", tex="noise", scale=4.0, bump=0.4, ramp=(0.4, 0.85))
    rim = mat("#7a6a44", 0.7, color2="#584a2c", tex="noise", scale=6.0, bump=0.2)
    _plate(list(reversed(out)), 0.16, face, rim, [((0, -0.45), (dx, 0.3)) for dx in (-0.6, 0.0, 0.6)],
           mat("#a08a62", 0.7))
    knob = mat("#d2bd92", 0.6, color2="#7a6444", tex="noise", scale=5.0)
    for k in range(1, n, 2):  # epoccipitals: cones standing out from the rim
        a = math.pi * k / n
        x, z = math.cos(a) * 1.03, math.sin(a) * 0.83 - 0.35
        cyl(0.11, 0.3, loc=(x * 1.08, 0, z + 0.06 * math.sin(a)), rot=(0, math.degrees(math.atan2(math.cos(a), math.sin(a) * 0.8)), 0),
            r2=0.0, m=knob, segs=10)
    turn(-15)
    upright()


def skull_plate():
    """Skull Plate (tarbosaurus, tyrannosaurus): a thick slab of tyrant skull, rugose on top, with a
    deep eye socket and a ridge of bony bumps."""
    out = [(-1.0, -0.35), (-0.4, -0.55), (0.5, -0.5), (1.0, -0.2), (0.95, 0.2), (0.4, 0.5), (-0.3, 0.55),
           (-0.9, 0.25)]
    face = mat("#d7c39c", 0.8, color2="#8e7854", tex="noise", scale=6.0, bump=0.9, ramp=(0.3, 0.8))
    rim = mat("#6e5a3c", 0.8, color2="#4e3e28", tex="noise", scale=6.0, bump=0.3)
    _plate(out, 0.3, face, rim, [], rim)
    cyl(0.26, 0.04, loc=(0.35, -0.16, 0.0), rot=(90, 0, 0), m=mat("#2c2018", 0.95), segs=20)  # eye socket
    ring = mat("#c4ad84", 0.8, color2="#8a7250", tex="noise", scale=6.0, bump=0.6)
    tube(arc((0.35, -0.16, 0.0), 0.29, 0, 360, 20), 0.06, ring, segs=8)
    for k in range(5):  # rugose bumps along the top
        blob(0.11, loc=(-0.75 + 0.3 * k, -0.12, 0.32 - 0.04 * k), m=ring, amp=0.25, sub=2)
    turn(-25)
    upright()


def venom_gland():
    m = mat("#9ad83a", 0.12, color2="#3a6a1a", tex="voronoi", scale=3.0, bump=0.3, coat=1.0, emit="#8cff4a",
            emit_strength=0.5)
    lathe([(0, -0.95), (0.35, -0.85), (0.62, -0.5), (0.7, -0.1), (0.6, 0.35), (0.38, 0.7), (0.18, 0.95), (0.12, 1.15)],
          m=m, scl=(1.0, 0.85, 1.0), rot=(0, 18, 0))
    duct = mat("#c87a8a", 0.4, coat=0.5)
    tube([(0.35, 0, 1.05), (0.45, 0, 1.35), (0.75, 0, 1.5), (1.0, 0, 1.45)], 0.08, duct, segs=8, taper=(1.0, 0.6))
    drop = mat("#c8ff6a", 0.08, coat=1.0, emit="#aaff44", emit_strength=2.0)
    for p, r in (((1.05, -0.05, 1.25), 0.07), ((1.06, -0.05, 0.95), 0.09)):
        ball(r, loc=p, scl=(1, 1, 1.4), m=drop, sub=2)


def predator_tendon():
    m = mat("#e3b4a6", 0.35, color2="#b97a6a", tex="wave", scale=10.0, coat=0.6)
    pts = []
    for i in range(70):
        a = i * 0.22
        r = 0.95 - 0.009 * i
        pts.append((r * math.cos(a), 0.06 * math.sin(a * 0.5), r * math.sin(a) * 0.75))
    tube(pts, 0.085, m, segs=8)
    tube([pts[-1], (0.3, -0.2, -0.6), (0.9, -0.3, -0.9)], 0.07, m, segs=8, taper=(1.0, 0.6))


def pearl():
    shell = mat("#d8b0c8", 0.35, color2="#8a5a7a", tex="wave", scale=9.0, bump=0.4, ramp=(0.2, 0.9))
    nacre = mat("#eef0ff", 0.15, color2="#d8c8f0", tex="noise", scale=3.0, coat=1.0)
    prof = [(0, 0.0), (0.5, 0.05), (0.9, 0.2), (1.0, 0.3), (0.94, 0.3), (0.5, 0.12), (0, 0.08)]
    lathe(prof, m=shell, segs=12, smooth=False, scl=(1.0, 0.85, 1.0))
    cyl(0.85, 0.02, loc=(0, 0, 0.1), m=nacre, segs=24)
    top = group(loc=(0, 0.75, 0.25), rot=(-84, 0, 0))  # wide open: taller, so it rises above the slot
    lathe([(0, 0.0), (0.5, -0.05), (0.9, -0.2), (1.0, -0.3), (0.94, -0.3), (0.5, -0.12), (0, -0.08)], m=shell, segs=12,
          smooth=False, scl=(1.0, 0.85, 1.0), parent=top)
    ball(0.42, loc=(0, -0.05, 0.45), m=mat("#f6f2ff", 0.1, color2="#ffd8ec", tex="noise", scale=2.0, coat=1.0), sub=4)
    turn(15)
    turn(18, "X")


def coral():
    m = mat("#ff6b5a", 0.5, color2="#ff9b7a", tex="noise", scale=4.0, bump=0.3)
    tube([(0, 0, -1.0), (0.05, 0, -0.3), (-0.05, 0, 0.4), (0.0, 0, 0.95)], 0.16, m, segs=10, taper=(1.0, 0.5))
    for (sx, z, h, ang) in ((1, -0.4, 0.8, 50), (-1, -0.1, 0.7, 45), (1, 0.3, 0.55, 35), (-1, 0.55, 0.45, 40)):
        a = math.radians(ang)
        p0 = (0, 0, z)
        p1 = (sx * h * 0.5 * math.sin(a), 0, z + h * 0.3)
        p2 = (sx * h * math.sin(a), 0, z + h * 0.9)
        tube([p0, p1, p2], 0.11, m, segs=8, taper=(1.0, 0.55))
        ball(0.065, loc=p2, m=m, sub=2)
    ball(0.09, loc=(0, 0, 0.95), m=m, sub=2)
    rock(0.45, loc=(0, 0.0, -1.1), scl=(1.4, 1.0, 0.4), m=stone("#cfc7b5", "#a39a85"), jitter=0.2)


def salt():
    m = mat("#f5f3ef", 0.3, color2="#dcdad6", tex="noise", scale=6.0, spec=0.7)
    for i in range(9):
        a = i * 2.4
        r = 0.2 + 0.08 * i
        box((0.42, 0.42, 0.42), loc=(r * math.cos(a), r * math.sin(a), 0.3 - 0.05 * i), rot=(rnd(0, 40), rnd(0, 40), rnd(0, 90)),
            m=m, bev=0.02)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def sulphur():
    m = mat("#ecd43a", 0.3, color2="#c8a81a", tex="noise", scale=4.0, coat=0.4)
    rock(0.6, loc=(0, 0, -0.4), scl=(1.6, 1.2, 0.6), m=stone("#9a8f6a", "#6a6046"), jitter=0.2)
    for (x, y, h, tx, ty) in ((0, 0, 1.4, 0, 0), (0.35, -0.1, 1.0, 0, 28), (-0.4, 0.05, 1.1, 0, -25),
                              (0.1, -0.35, 0.8, -25, 10), (-0.1, 0.35, 0.9, 25, -8)):
        cyl(0.16, h, loc=(x + math.sin(math.radians(ty)) * h / 2, y, -0.2 + h / 2), rot=(tx, ty, 0), m=m, segs=6,
            r2=0.05, smooth=False)


def clay():
    """Clay: a hand-pressed brick of wet clay, its top scored with finger grooves and one corner
    pressed down, a thumbprint dent in the middle. Orange-brown, matte, no lumps."""
    m = mat("#b8643a", 0.8, color2="#8e4622", tex="noise", scale=7.0, bump=0.5)
    box((1.6, 1.05, 0.75), loc=(0, 0, -0.15), m=m, bev=0.14)
    # Finger grooves pressed across the top.
    for k in range(3):
        y = -0.28 + 0.28 * k
        tube([(-0.62, y, 0.24), (0.0, y + 0.02, 0.28), (0.62, y, 0.24)], 0.06, m, segs=6, taper=(0.7, 0.7))
    blob(0.24, loc=(0.3, 0.15, 0.3), scl=(1.2, 1.0, 0.35), m=m, amp=0.1, sub=2)  # a pressed wall rising
    # A second, smaller brick behind.
    box((0.8, 0.6, 0.45), loc=(-0.75, 0.35, 0.2), rot=(0, 0, -14), m=m, bev=0.1)
    blob(0.32, loc=(0.75, -0.4, -0.45), scl=(1.3, 1.0, 0.4), m=m, amp=0.3, sub=2)  # a pinch of trimmings
    turn(14)
    turn(10, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def resin():
    m = mat("#e8941e", 0.08, color2="#c8641a", tex="noise", scale=2.0, coat=1.0, emit="#ff9a2a", emit_strength=0.8)
    lathe([(0, 1.2), (0.12, 1.0), (0.4, 0.6), (0.62, 0.25), (0.66, 0.0), (0.55, -0.25), (0.3, -0.4), (0, -0.42)], m=m)
    blob(0.32, loc=(0.75, -0.2, -0.25), m=m, amp=0.1)


def ice():
    m = mat("#bfe6ff", 0.05, color2="#7cc4f0", tex="noise", scale=2.5, coat=1.0, emit="#9fd8ff", emit_strength=0.5)
    rock(0.8, scl=(1.0, 0.85, 1.25), m=m, jitter=0.2, sub=1)
    rock(0.45, loc=(0.75, -0.25, -0.4), m=m, jitter=0.25, sub=0)
    rock(0.35, loc=(-0.7, 0.0, -0.5), m=m, jitter=0.25, sub=0)


# ---------------------------------------------------------------- hide, fibre and textiles

_PELT = [(0.0, 1.1), (0.25, 0.95), (0.55, 1.15), (0.6, 0.8), (0.5, 0.35), (0.7, -0.2), (0.85, -0.65), (0.45, -0.6),
         (0.2, -1.15), (-0.15, -0.65), (-0.6, -0.75), (-0.62, -0.25), (-0.5, 0.3), (-0.65, 0.85), (-0.3, 1.05)]


def _pelt(m, roll=False):
    def wave(co):
        co.y += 0.08 * math.sin(co.x * 4.0) + 0.06 * math.cos(co.z * 3.0)
    prism(_PELT, 0.07, m=m, bev=0.02, deform=wave)
    turn(-20)
    turn(-25, "X")


def raw_hide():
    """Raw hide: a fresh hide stretched out, flesh side up, wet pink-brown with pale fat and sinew
    streaks, the fur still on along the edges (raptor_hide is the striped, feathered one)."""
    flesh = mat("#c08870", 0.45, color2="#a06248", tex="voronoi", scale=6.0, bump=0.35, spec=0.3)
    fat = mat("#f2e0c4", 0.55, color2="#d8c09a", tex="noise", scale=9.0, bump=0.25)
    fur = mat("#7a5a3a", 0.9, color2="#4a3420", tex="noise", scale=14.0, bump=0.8)
    _pelt(flesh)
    # Fur along the edge: a soft band of tufts, not spikes.
    P = _PELT
    for k in range(len(P)):
        x0, z0 = P[k]
        x1, z1 = P[(k + 1) % len(P)]
        for t in (0.15, 0.5, 0.85):
            x = x0 + (x1 - x0) * t
            z = z0 + (z1 - z0) * t
            blob(0.1, loc=(x * 1.02, 0.05, z * 1.02), scl=(1.2, 0.9, 1.2), m=fur, amp=0.3, sub=2)
    # Pale fat and sinew streaks on the flesh side.
    for (x0, z0, x1, z1) in ((-0.45, 0.55, 0.25, 0.7), (-0.35, -0.25, 0.3, -0.1), (0.05, 0.25, 0.5, 0.35),
                              (-0.2, -0.6, 0.1, -0.5)):
        tube([(x0, -0.06, z0), ((x0 + x1) / 2, -0.09, (z0 + z1) / 2 + 0.06), (x1, -0.06, z1)], 0.035, fat, segs=4)
    turn(-8)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def raptor_hide():
    """Raptor hide: a feathered pelt in the raptor's tawny brown (items.json tint #6b5a3e): rows of
    overlapping feathers laid like shingles, banded tan and near-black, with long quills fringing
    the torn edge (raw_hide is the bare, wet flesh side). Review: a flat striped cut-out; the
    first redo's green skin and bead tufts read as a cactus pad."""
    skin = mat("#6b5a3e", 0.8, color2="#4a3c26", tex="noise", scale=8.0, bump=0.4)
    tan = mat("#b8955c", 0.6, color2="#8a6c3e", tex="wave", scale=18.0, bump=0.3)
    dark = mat("#3a2e1c", 0.6, color2="#241a0e", tex="wave", scale=18.0, bump=0.3)
    prism(_PELT, 0.07, m=skin, bev=0.02)
    rows = [(0.78, 2), (0.5, 3), (0.22, 3), (-0.06, 3), (-0.34, 3), (-0.6, 2)]
    for r, (z, n) in enumerate(rows):
        fm = dark if r % 2 else tan
        for k in range(n):
            x = (k - (n - 1) / 2.0) * 0.36 + 0.06 * (r % 2)
            leaf(0.5, 0.2, loc=(x, -0.05 - 0.012 * (len(rows) - r), z + 0.2), rot=(0, 180 + 8 * (k - 1), 0),
                 m=fm, curl=0.06)
    # Long quills fringing the edge.
    P = _PELT
    for k in range(0, len(P), 2):
        x, z = P[k]
        leaf(0.35, 0.08, loc=(x * 0.9, -0.02, z * 0.9), rot=(0, -math.degrees(math.atan2(x, z)), 0), m=tan, curl=0.04)
    turn(-25, "X")
    turn(22)  # face the camera (it looks in from +x)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def dried_hide():
    """Dried hide: a stiff amber rawhide laced into a square drying frame of lashed sticks, the
    lacing cords running from its edge to the poles (review: a flat slab with painted stripes; a
    bare sheet still read as a slab, the frame is what says 'dried')."""
    m = mat("#e0b070", 0.75, color2="#b07a3e", tex="noise", scale=5.0, bump=0.3, ramp=(0.35, 0.8))
    w = wood("#7a5634", "#55391e")
    cord = rope_m("#d8c08a")
    outline = [(-0.72, -0.62), (-0.3, -0.75), (0.15, -0.66), (0.62, -0.74), (0.75, -0.3), (0.68, 0.2),
               (0.76, 0.62), (0.3, 0.72), (-0.15, 0.64), (-0.66, 0.74), (-0.75, 0.3), (-0.68, -0.15)]

    def ripple(co):
        co.y += 0.04 * math.sin(co.x * 6.0) * math.cos(co.z * 5.0) - 0.08 * (1 - co.x * co.x) * (1 - co.z * co.z)
    prism(outline, 0.04, m=m, bev=0.012, deform=ripple)
    F = 0.98
    for (p0, p1) in (((-F - 0.12, 0, F), (F + 0.12, 0, F)), ((-F - 0.12, 0, -F), (F + 0.12, 0, -F)),
                     ((-F, 0, F + 0.12), (-F, 0, -F - 0.12)), ((F, 0, F + 0.12), (F, 0, -F - 0.12))):
        tube([p0, p1], 0.055, w, segs=8)
    for (x, z) in ((-F, F), (F, F), (-F, -F), (F, -F)):
        tube(arc((x, 0, z), 0.08, 0, 360, 10, plane="xy")[:-1], 0.02, cord, segs=4, closed=True)
    for (x, z) in outline:  # lacing from each point of the hide out to the nearest pole
        if abs(x) > abs(z):
            tube([(x, 0.0, z), (math.copysign(F, x), 0.0, z * 1.05)], 0.018, cord, segs=4)
        else:
            tube([(x, 0.0, z), (x * 1.05, 0.0, math.copysign(F, z))], 0.018, cord, segs=4)
    turn(-14)
    turn(8, "X")
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def hide_strap():
    m = hidem("#7a4a2a", "#5a3218")
    pts = []
    for i in range(60):
        a = i * 0.24
        r = 0.9 - 0.011 * i
        pts.append((r * math.cos(a), 0.0, r * math.sin(a)))
    ob = tube(pts, 0.1, m, segs=8)
    ob.scale = (1.0, 2.2, 1.0)
    tube([pts[0], (1.0, -0.1, -0.5), (0.8, -0.2, -1.0)], 0.1, m, segs=8)
    turn(35, "X")


def rope():
    m = rope_m()
    pts = []
    for i in range(110):
        a = i * 0.2
        r = 0.95 - 0.0045 * i
        pts.append((r * math.cos(a), r * math.sin(a), 0.05 * math.sin(a * 0.5) + i * 0.004))
    tube(pts, 0.11, m, segs=8)
    tube([pts[-1], (0.1, -0.3, 0.6), (0.6, -0.6, 0.65), (1.1, -0.8, 0.5)], 0.11, m, segs=8)
    turn(40, "X")


def twine():
    m = rope_m("#d7c08a")
    ball(0.75, m=m, sub=3)
    for i in range(10):
        g = group(rot=(i * 37 % 180, i * 61 % 180, i * 23 % 180))
        tube(arc((0, 0, 0), 0.77, 0, 360, 28, plane="xz")[:-1], 0.03, m, segs=5, closed=True, parent=g)
    tube([(0.7, 0, -0.3), (1.0, -0.2, -0.7), (1.3, -0.1, -0.9)], 0.03, m, segs=5)


def thread():
    w = wood("#c9965a", "#9a6a35")
    lathe([(0, 0.0), (0.55, 0.0), (0.55, 0.14), (0.3, 0.14), (0.3, 1.06), (0.55, 1.06), (0.55, 1.2), (0, 1.2)],
          m=w, smooth=False)
    cyl(0.48, 0.92, loc=(0, 0, 0.6), m=mat("#d23c3c", 0.6, color2="#a82828", tex="wave", scale=25.0), segs=28)
    tube([(0.48, 0, 0.9), (0.8, -0.2, 0.6), (1.0, -0.3, 0.1)], 0.025, mat("#d23c3c", 0.6), segs=5)
    turn(20)
    turn(-10, "X")


def cloth_item():
    """Cloth: a stack of three folded lengths (linen on rust on indigo), each with a soft rolled fold
    toward the camera and the weave showing; the top length's end hangs
    down over the front (review: the old art was stacked coloured slabs with no fold or weave)."""
    linen = _weave("#e2d8bc", "#c4b692", scale=44.0, bump=0.3)
    rust = _weave("#c0683e", "#94482a", scale=44.0, bump=0.3)
    blue = _weave("#5c7cb0", "#3e5888", scale=44.0, bump=0.3)
    for (z, m, rz) in ((-0.42, blue, -4), (-0.08, rust, 5), (0.26, linen, -2)):
        g = group(loc=(0, 0, z), rot=(0, 0, rz))
        box((1.7, 1.15, 0.3), m=m, bev=0.13, parent=g)
        # The fold: a soft roll along the front edge, so each length reads as folded fabric.
        cyl(0.15, 1.66, loc=(0, -0.56, 0), rot=(0, 90, 0), m=m, segs=16, parent=g)

    def hang(u, v):
        x = (u * 2.0 - 1.0) * 0.62
        return (x + 0.1, -0.72 - 0.05 * math.sin(x * 5.0) - 0.05 * v,
                0.36 - 0.95 * v + 0.06 * math.sin(u * math.pi * 3.0) * v)
    _sheet(10, 9, hang, linen, thick=0.05)
    turn(-24)
    turn(12, "X")
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def _bundle(stalk_m, n=11, h=2.2, tops=None, spread=0.5):
    for i in range(n):
        x = (i - (n - 1) / 2) / ((n - 1) / 2)
        top = (x * spread, -0.05 * (i % 3), h / 2)
        tube([(x * 0.1, 0.03 * (i % 3), -h / 2), (x * 0.08, 0, 0), top], 0.04, stalk_m, segs=6)
        if tops:
            tops(top, x)
    tube(arc((0, 0, 0), 0.2, 0, 360, 16, plane="xy", y=-0.1)[:-1], 0.05, rope_m(), segs=6, closed=True)
    lean(-25)


def fibre_stalk():
    _bundle(mat("#9ab84a", 0.6, color2="#6e8a2a", tex="wave", scale=10.0))


def flax():
    blue = mat("#5a7cff", 0.4)
    _bundle(mat("#8aa84a", 0.6), n=9, tops=lambda p, x: ball(0.1, loc=p, m=blue, sub=2))


def wheat():
    gold = mat("#e2b94c", 0.5, color2="#c0902a", tex="voronoi", scale=20.0, bump=0.4)
    _bundle(mat("#d8b45a", 0.55), n=9, tops=lambda p, x: ball(0.13, loc=(p[0], p[1], p[2] + 0.15), scl=(0.8, 0.8, 2.2),
                                                                    m=gold, sub=2))


def dry_grass():
    _bundle(mat("#d8bf72", 0.7, color2="#b0954a", tex="wave", scale=12.0), n=15, spread=0.8)


def palm_frond():
    rib = mat("#9aa04a", 0.5)
    g_m = mat("#4fa04a", 0.45, color2="#3a8a3a", tex="wave", scale=6.0)
    pts = arc((-1.0, 0, -1.2), 2.2, 10, 75, 12)
    tube(pts, 0.05, rib, segs=6, taper=(1.0, 0.4))
    for i in range(2, 12):
        p = pts[i]
        for s in (-1, 1):
            leaf(0.7 - 0.03 * i, 0.09, loc=p, rot=(0, s * 70 - 20 + i * 2, 0), m=g_m, curl=0.12)
    lean(-10)


def herb_leaf():
    g_m = mat("#5fb04a", 0.5, color2="#3d8a32", tex="wave", scale=8.0)
    tube([(0, 0, -1.0), (0.05, 0, 0.0), (0, 0, 0.9)], 0.04, mat("#6a8a3a", 0.5), segs=6)
    for i, (z, ang) in enumerate(((-0.6, 55), (-0.2, -55), (0.2, 50), (0.55, -45), (0.9, 0))):
        leaf(0.75 - 0.08 * i, 0.3 - 0.03 * i, loc=(0, 0, z), rot=(0, ang, 0), m=g_m, curl=0.12)
    lean(-15)


def blue_dye():
    pot = mat("#b06a44", 0.7, color2="#8a4a2a", tex="noise", scale=4.0)
    lathe([(0, 0), (0.55, 0.0), (0.8, 0.45), (0.7, 0.95), (0.5, 1.1), (0.55, 1.2), (0.48, 1.2), (0.42, 1.1), (0, 1.1)],
          m=pot, segs=28)
    cyl(0.44, 0.02, loc=(0, 0, 1.12), m=mat("#2a5cd8", 0.05, coat=1.0), segs=24)
    tube([(0.5, -0.05, 1.18), (0.66, -0.25, 0.85), (0.72, -0.4, 0.45)], 0.06, mat("#2a5cd8", 0.05, coat=1.0), segs=8,
         taper=(1.0, 0.6))
    turn(20)
    turn(15, "X")


# ---------------------------------------------------------------- missing set (dsc icons2): raw materials
# One distinct silhouette and material per raw material: two woods differ by bark colour and grain,
# herbs by leaf shape, earths by colour and chunkiness.

def acacia_wood():
    """Pale gold acacia: thin bark, two slender logs crossed, one split face showing heartwood."""
    b = mat("#8a5a2e", 0.8, color2="#5e3a16", tex="wave", scale=8.0, bump=0.5, ramp=(0.3, 0.75))
    _log(0.27, 2.2, b, "#e8b864", loc=(0, 0.18, 0.0), stub=True)
    _log(0.22, 1.9, b, "#e8b864", loc=(0.12, -0.34, 0.05))
    heart = mat("#e8bc6e", 0.7, color2="#b8843c", tex="rings", scale=5.5, bump=0.1)
    prism([(0, 0)] + [(math.cos(math.radians(a)) * 0.34, math.sin(math.radians(a)) * 0.34) for a in range(10, 171, 16)],
          1.3, loc=(0.1, -0.05, -0.55), rot=(0, 0, -140), m=heart, bev=0.015)
    turn(62)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def willow_wood():
    """Willow: a smooth yellow-green trunk piece with drooping twigs and long narrow leaves."""
    b = mat("#8f8a5c", 0.7, color2="#6a6640", tex="noise", scale=7.0, bump=0.15)
    g = group(rot=(0, 0, 18))
    cyl(0.3, 2.0, m=b, segs=20, parent=g)
    end = mat("#d8cf9a", 0.65, color2="#a89e68", tex="rings", scale=5.0)
    for s in (-1, 1):
        cyl(0.27, 0.04, loc=(0, 0, s * 1.0), m=end, segs=20, parent=g)
    twig = mat("#9a8a4a", 0.6, color2="#6e6230", tex="noise", scale=10.0)
    for i, (x, yv, dz) in enumerate(((0.28, 0.0, 0.55), (0.24, 0.1, 0.05), (-0.26, -0.1, 0.3))):
        pts = [(x * 0.8, yv, dz), (x * 1.8, yv, dz + 0.5), (x * 2.4, yv + 0.1, dz + 0.35), (x * 2.8, yv + 0.15, dz - 0.35)]
        tube(pts, 0.045, twig, segs=6, parent=g)
    g_m = mat("#a8c060", 0.55, color2="#7a9640", tex="wave", scale=7.0)
    for i, (x, z, ang) in enumerate(((0.62, 1.0, 30), (0.72, 0.35, 55), (-0.6, 0.8, -35), (-0.62, 0.25, -60))):
        leaf(0.62, 0.09, loc=(x, 0.06, z), rot=(0, ang, 0), m=g_m, curl=0.12, parent=g)
    lean(-22)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def snow_pine():
    """Snow pine: two pine logs, one on top of the other, each carrying a lumpy ridge of snow along
    its top and a sprig of dark needles at its end. Snow flakes still cling to the bark."""
    b = mat("#7a4428", 0.9, color2="#4a2414", tex="voronoi", scale=10.0, bump=0.6, ramp=(0.15, 0.5))
    snow = mat("#f2f6ff", 0.65, color2="#cddcee", tex="noise", scale=4.0, bump=0.25)
    _log(0.3, 2.0, b, "#c08650", loc=(0, 0.2, -0.1))
    _log(0.24, 1.7, b, "#c08650", loc=(0.05, -0.3, 0.28))
    for (cy, cz, ln, r) in ((0.2, 0.18, 1.85, 0.26), (-0.3, 0.5, 1.6, 0.2)):
        # Lumpy snow ridge: overlapping soft lumps along the log's top, thicker in the middle.
        for i in range(9):
            t = i / 8.0
            s_ = 0.35 + 0.65 * math.sin(math.pi * (0.15 + 0.7 * t))
            blob(0.17 * s_ + 0.05, loc=(-ln / 2 + ln * t, cy, cz + 0.03),
                 scl=(1.5, 1.1, 0.55 + 0.25 * s_), m=snow, amp=0.2, freq=3.0, sub=2)
    # Snow caught on the bark: pale patches on the underside and the near side.
    for (x, y, z) in ((-0.6, 0.02, 0.02), (0.15, 0.06, 0.05), (0.55, 0.0, 0.0)):
        blob(0.1, loc=(x, y, z), scl=(1.4, 1.0, 0.4), m=snow, amp=0.3, sub=2)
    needle = mat("#2e5a3a", 0.6, color2="#1e4028", tex="wave", scale=14.0)
    tube([(0.7, -0.35, 0.4), (0.95, -0.4, 0.62)], 0.03, needle, segs=5)
    for k in range(5):
        a = -1.0 + 0.5 * k
        tube([(0.95, -0.4, 0.6), (0.95 + 0.22 * math.cos(a), -0.4 + 0.12 * math.sin(a), 0.62 + 0.26 + 0.08 * math.sin(a))],
             0.022, needle, segs=4)
    turn(58)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def ash():
    """Cold ash gathered in a wooden scoop: a bowl of pale grey powder heaped above the rim, a
    charred stick and a couple of cinders lying in it."""
    scoop = mat("#8a6a44", 0.8, color2="#6a4c2c", tex="noise", scale=18.0, bump=0.3)
    lathe([(0, -0.1), (0.5, -0.12), (0.95, 0.05), (1.15, 0.45), (1.22, 0.62), (1.12, 0.62), (1.02, 0.42),
           (0.85, 0.12), (0.45, 0.02), (0, 0.02)], m=scoop, segs=36, scl=(1.15, 0.85, 1.0))
    # The scoop's handle, sticking up and back.
    tube([(0.9, 0.25, 0.45), (1.35, 0.35, 0.7), (1.65, 0.4, 0.95)], 0.11, scoop, segs=10, taper=(1.0, 0.8))
    ball(0.13, loc=(1.68, 0.4, 0.98), m=scoop, sub=2)
    # The ash: a soft heaped mound inside the bowl, well above the rim.
    dust = mat("#9a968e", 1.0, color2="#726e66", tex="noise", scale=26.0, bump=0.6, spec=0.2, ramp=(0.35, 0.65))
    dust2 = mat("#b0aca4", 1.0, color2="#8a867e", tex="noise", scale=30.0, bump=0.55, spec=0.2, ramp=(0.35, 0.65))
    blob(0.95, loc=(0, 0, 0.35), scl=(1.1, 0.85, 0.5), m=dust, amp=0.08, freq=4.0, sub=3)
    for (x, y, r) in ((0.5, -0.15, 0.35), (-0.45, 0.1, 0.38), (0.1, 0.35, 0.3)):
        blob(r, loc=(x, y, 0.45), scl=(1.1, 1.0, 0.6), m=dust2, amp=0.12, freq=4.0, sub=3)
    # A pinch spilled over the rim and a charred stick lying across the heap.
    blob(0.3, loc=(1.05, -0.3, 0.1), scl=(1.4, 0.8, 0.3), m=dust2, amp=0.2, sub=2)
    char = mat("#26221e", 0.95, color2="#464038", tex="noise", scale=10.0, bump=0.6)
    tube([(-0.7, -0.1, 0.55), (-0.2, -0.05, 0.68), (0.35, 0.0, 0.62), (0.7, 0.05, 0.5)], 0.055, char, segs=6,
         taper=(1.0, 0.7))
    for p_ in ((-0.3, 0.25, 0.6), (0.15, -0.3, 0.58)):
        blob(0.09, loc=p_, scl=(1.2, 1.0, 0.7), m=char, amp=0.2, sub=2)
    ember = mat("#6a6058", 0.8, color2="#8a7e72", tex="noise", scale=12.0, emit="#ff7a2a", emit_strength=0.8)
    blob(0.06, loc=(0.05, 0.2, 0.66), m=ember, amp=0.2, sub=2)
    turn(15)
    turn(18, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def bark_strip():
    """Bark strips: a piece of bark rolled up like a scroll (its pale inner face and its ridged dark
    outer face both showing) and a second flat strip lying against it."""
    outer = mat("#6e4a2a", 0.9, color2="#3a2412", tex="wave", scale=7.0, bump=0.6, ramp=(0.25, 0.7))
    inner = mat("#e6bc84", 0.85, color2="#bc8a52", tex="noise", scale=12.0, bump=0.2)
    ridge = mat("#4a3018", 0.9, color2="#2a1a0c", tex="noise", scale=14.0, bump=0.4)
    # The scroll: a spiral band, its outer face dark and ridged, its cut edges pale.
    turns, n = 1.6, 60
    band_o, band_i = [], []
    for i in range(n + 1):
        a = turns * 2 * math.pi * i / n
        r = 0.72 - 0.26 * (i / n)
        band_o.append((r * math.cos(a), 0.0, r * math.sin(a)))
        band_i.append(((r - 0.09) * math.cos(a), 0.0, (r - 0.09) * math.sin(a)))
    tube(band_o, 0.045, outer, segs=6)
    tube(band_i, 0.04, inner, segs=6)
    for k in range(n):
        if k % 2 == 0:
            tube([band_o[k], band_i[k]], 0.035, ridge, segs=4)
    # A second, flat strip: a long curved sheet leaning on the scroll, ridged outer face up.
    pts = [(-1.0 + 2.0 * i / 10.0, 0.0, 0.25 * math.sin(math.pi * i / 10.0)) for i in range(11)]
    tube(pts, 0.11, outer, segs=8, taper=(1.0, 0.8))
    for k in range(1, 10, 2):
        p = pts[k]
        tube([(p[0], -0.09, p[2]), (p[0], 0.09, p[2])], 0.02, ridge, segs=4)
    turn(-12)
    turn(22, "X")
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def cactus_spine():
    """A fan of long ivory cactus spines, fanned from one small green base, two of them hooked."""
    m = mat("#f6f0dc", 0.35, color2="#d8cba8", tex="noise", scale=8.0, bump=0.1, spec=0.6)
    for (ang, ln, hook) in ((-48, 1.9, 0.0), (-18, 2.2, 0.25), (8, 2.0, 0.0), (34, 1.7, -0.2), (58, 1.4, 0.0)):
        a = math.radians(ang)
        p0 = (0.0, 0.0, -0.9)
        p1 = (0.75 * math.sin(a), 0.05, -0.9 + 0.8 * math.cos(a))
        p2 = (1.35 * math.sin(a) + hook * 0.4, 0.08, -0.9 + 1.55 * math.cos(a))
        p3 = (1.6 * math.sin(a) + hook, 0.1, -0.9 + ln * math.cos(a) * 0.95)
        tube([p0, p1, p2, p3], 0.075, m, segs=8, taper=(1.0, 0.03))
    base = mat("#5aa04a", 0.45, color2="#3e7a32", tex="noise", scale=5.0)
    blob(0.36, loc=(0, 0.05, -0.95), scl=(1.5, 1.0, 0.75), m=base, amp=0.18)
    for k in range(5):
        a = -1.0 + k * 0.5
        cyl(0.02, 0.16, loc=(0.3 * math.cos(a), 0.1, -0.82 + 0.1 * math.sin(a)), rot=(20, 0, 70 * math.cos(a)),
            r2=0.0, m=m, segs=5)
    lean(-30)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def _weave(c, c2, scale=60.0, bump=0.45):
    """Cloth material: a linen colour ramped by noise, with a woven cross-hatch bump (two wave
    textures at right angles multiplied). Reads as fabric at slot size by its texture, not its shape."""
    import bpy
    m = mat(c, 1.0, color2=c2, tex="noise", scale=6.0, bump=0.0, spec=0.15, ramp=(0.35, 0.65))
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    coord = next(n for n in nt.nodes if n.type == "TEX_COORD")
    waves, facs = [], []
    for rot in (0.0, math.pi / 2):
        t = nt.nodes.new("ShaderNodeTexWave")
        t.wave_type = "BANDS"
        t.bands_direction = "Z"
        t.inputs["Scale"].default_value = scale
        t.inputs["Distortion"].default_value = 1.6
        t.inputs["Detail"].default_value = 1.0
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Rotation"].default_value = (0.0, rot, 0.0)
        nt.links.new(coord.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], t.inputs["Vector"])
        waves.append(t)
        facs.append(t.outputs["Fac"])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    nt.links.new(facs[0], mul.inputs[0])
    nt.links.new(facs[1], mul.inputs[1])
    bn = nt.nodes.new("ShaderNodeBump")
    bn.inputs["Strength"].default_value = bump
    bn.inputs["Distance"].default_value = 0.03
    nt.links.new(mul.outputs["Value"], bn.inputs["Height"])
    nt.links.new(bn.outputs["Normal"], bsdf.inputs["Normal"])
    # Thread lines in the colour as well, so the weave survives the 2x downsample.
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 0.3
    # Mix lerps A -> A*B: the cloth colour is A, so the threads only darken it where they cross.
    mix.inputs[7].default_value = srgb("#8a7c60")
    src = next(n for n in nt.nodes if n.type == "VALTORGB")
    nt.links.new(src.outputs["Color"], mix.inputs[6])
    nt.links.new(mul.outputs["Value"], mix.inputs[0])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return m


def _sheet(nu, nv, fn, m, thick=0.03):
    """A grid surface (nu x nv quads) from fn(u, v) -> (x, y, z), given thickness. Cloth needs real
    drape: folds only read if the surface curves, so a folded sheet is a displaced grid, not a prism."""
    import bmesh
    import bpy
    bm = bmesh.new()
    grid = [[bm.verts.new(fn(i / (nu - 1), j / (nv - 1))) for j in range(nv)] for i in range(nu)]
    for i in range(nu - 1):
        for j in range(nv - 1):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("sheet")
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(m)
    ob = bpy.data.objects.new("sheet", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = __import__("kit").ROOT  # not the ROOT name bound at import: reset() makes a new one
    md = ob.modifiers.new("solid", "SOLIDIFY")
    md.thickness = thick
    return ob


def cloth_scrap():
    """Torn linen: a scrap of pale woven cloth with a faded red band, hung over a stick so it falls
    in soft folds on both sides, its hem torn uneven with loose threads trailing (review: a flat
    or heaped scrap read as paper or pastry; a hanging drape only reads as cloth)."""
    face = _weave("#e4dbc0", "#c8bb98", scale=44.0, bump=0.3)
    band = _weave("#b8503c", "#8e3a2a", scale=44.0, bump=0.3)
    thread = mat("#dcd0b0", 0.95)
    R = 0.09  # stick radius

    def path(v, u, off=0.0):
        # v 0..1: front hem -> up the front -> over the stick -> down the back to a shorter hem.
        x = (u * 2.0 - 1.0) * 0.85
        hem = 0.16 * (((u * 6.0 + 0.3) % 1.0)) + 0.05 * math.sin(u * 19.0)
        front, back = 1.25 - hem, 0.8 - 0.6 * hem
        L = front + math.pi * R + back
        d = v * L
        fold = 0.09 * math.sin(x * 8.0 + 0.5)
        if d < front:
            depth = front - d
            return (x, -(R + off) - fold * depth - 0.12 * depth * depth, -depth)
        if d < front + math.pi * R:
            t = (d - front) / R
            return (x, -(R + off) * math.cos(t), (R + off) * math.sin(t))
        depth = d - front - math.pi * R
        return (x, (R + off) + fold * depth + 0.08 * depth * depth, -depth)
    _sheet(18, 26, lambda u, v: path(v, u), face, thick=0.03)
    _sheet(18, 3, lambda u, v: path(0.14 + 0.07 * v, u, 0.045), band, thick=0.005)
    cyl(R, 2.2, rot=(0, 90, 0), m=wood("#8a6a44", "#6a4c2c"), segs=12)
    for i in range(5):   # loose threads off the torn front hem
        u = 0.1 + 0.2 * i
        x, y, z = path(0.0, u)
        tube([(x, y, z + 0.02), (x + 0.02, y - 0.02, z - 0.12 - 0.04 * (i % 3)),
              (x - 0.02, y - 0.03, z - 0.2 - 0.03 * (i % 2))], 0.016, thread, segs=4)
    turn(-30)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def leech():
    """A fat blood leech: dark red, ringed, arched over the ground with a sucker at each end."""
    body = mat("#7a2634", 0.3, color2="#4a1220", tex="noise", scale=12.0, bump=0.3, coat=0.6, spec=0.7)
    ring = mat("#4a1220", 0.35, color2="#2a0a12", tex="noise", scale=14.0, bump=0.2, coat=0.6)
    pts = []
    for i in range(19):
        t = i / 18
        a = math.pi * (0.12 + 0.76 * t)
        pts.append((1.3 * math.cos(math.pi - a), 0.0, -1.0 + 1.9 * math.sin(a) + 0.1 * t))
    tube(pts, 0.3, body, segs=16, taper=(0.5, 1.0))
    for i in range(1, 10):  # rings: thin darker bands around the body
        u = i / 10
        k = int(u * (len(pts) - 1))
        p = pts[k]
        q = pts[min(k + 1, len(pts) - 1)]
        r = 0.3 * (0.5 + 0.5 * u) * 1.02
        d = (q[0] - p[0], q[2] - p[2])
        n = math.hypot(*d) or 1.0
        band = [(p[0] + r * math.cos(t) * (-d[1] / n), r * math.sin(t),
                 p[2] + r * math.cos(t) * (d[0] / n)) for t in (j * 0.4 for j in range(16))]
        tube(band, 0.035, ring, segs=5, closed=True)
    for p in (pts[0], pts[-1]):  # suckers
        cyl(0.15, 0.07, loc=(p[0], p[1], p[2]), rot=(90, 0, 0), m=ring, segs=16)
        cyl(0.08, 0.09, loc=(p[0], p[1] - 0.02, p[2]), rot=(90, 0, 0), m=mat("#2a0a12", 0.3), segs=12)
    turn(-6)
    turn(8, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def marsh_herb():
    """Marsh herb: broad flat leaves on a low rosette with a pale umbel of tiny flowers."""
    g_m = mat("#4e8a46", 0.55, color2="#2e6234", tex="wave", scale=6.0, bump=0.15)
    stem = mat("#6a8a44", 0.6)
    for i in range(5):
        a = math.radians(72 * i)
        leaf(0.8, 0.36, loc=(0, 0, -0.1), rot=(28, 0, 0),
             m=g_m, curl=0.16,
             parent=group(loc=(0, 0, -0.2), rot=(0, 0, math.degrees(a))))
    tube([(0, 0, -0.3), (0.05, 0, 0.4), (0.0, 0, 0.95)], 0.04, stem, segs=6)
    fl = mat("#f2ecd8", 0.5, color2="#d8cfae", tex="noise", scale=10.0)
    for k in range(9):
        a = k * 0.7
        ball(0.075, loc=(0.22 * math.cos(a), 0.22 * math.sin(a) * 0.6, 1.05 + 0.03 * (k % 2)), m=fl, sub=1)
    for k in range(4):
        a = 1.6 + k * 1.4
        tube([(0, 0, 0.6 + 0.08 * k), (0.4 * math.cos(a), 0.15 * math.sin(a), 0.85 + 0.05 * k)], 0.02, stem, segs=4)
    turn(12)
    lean(-8)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def spice_herb():
    """Spice herb: feathery dark-green fronds and orange-red seed pods on a tall stalk."""
    g_m = mat("#3e7a5a", 0.5, color2="#24503a", tex="wave", scale=11.0, bump=0.25)
    stem = mat("#5a7a3a", 0.6)
    tube([(0, 0, -1.1), (-0.05, 0, -0.2), (0.05, 0, 0.6), (0, 0, 1.15)], 0.055, stem, segs=8)
    for i, (z, ang, ln) in enumerate(((-0.75, 60, 0.6), (-0.45, -60, 0.58), (-0.1, 55, 0.55), (0.25, -55, 0.5),
                                      (0.5, 50, 0.45))):
        base = (0, 0, z)
        g = group(loc=base, rot=(0, ang, 0))
        for k in range(3):
            leaf(ln * (1.0 - 0.18 * k), 0.08, loc=(0, 0.03 * k * (1 if ang > 0 else -1), 0), rot=(0, 0, -10 + 12 * k),
                 m=g_m, curl=0.14, parent=g)
    pod = mat("#e8642a", 0.35, color2="#b83a12", tex="noise", scale=20.0, coat=0.4, bump=0.3)
    for k in range(7):
        a = k * 0.9
        z = 0.95 + 0.05 * (k % 3)
        ball(0.11, loc=(0.2 * math.cos(a), 0.12 * math.sin(a), z), scl=(1, 1, 1.5), rot=(10 * (k % 2), 0, 0), m=pod, sub=2)
    for k in range(3):
        a = 0.5 + k * 2.0
        tube([(0, 0, 1.1), (0.3 * math.cos(a), 0.1, 1.3)], 0.02, stem, segs=4)
        ball(0.07, loc=(0.33 * math.cos(a), 0.1, 1.33), scl=(1, 1, 1.6), m=pod, sub=1)
    lean(-18)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def petals():
    """A scatter of thin rose petals: dusty rose, blush and deep crimson, each a flat petal with a
    crease down its middle and a curled tip."""
    pinks = (mat("#c05a72", 0.85, color2="#9a3a52", tex="noise", scale=3.0, bump=0.3, spec=0.25),
             mat("#d88094", 0.85, color2="#b05c70", tex="noise", scale=3.0, bump=0.3, spec=0.25),
             mat("#9a2848", 0.85, color2="#741634", tex="noise", scale=3.0, bump=0.3, spec=0.25))

    def outline(length, width):
        pts = []
        n = 12
        for i in range(n + 1):
            t = i / n
            pts.append((width * math.sin(math.pi * t ** 0.62) ** 0.75, length * t))
        for i in range(n - 1, 0, -1):
            t = i / n
            pts.append((-width * 0.94 * math.sin(math.pi * t ** 0.62) ** 0.75, length * t))
        return pts

    def curled(co):
        co.y += 0.35 * max(0.0, co.z - 0.55) ** 1.5 - 0.06 * (co.x / 0.4) ** 2   # tip lifts, petal cups
    spots = (((-0.55, 0.2, -0.4), (86, 25, 0), 0.95, pinks[0]), ((0.08, 0.3, -0.3), (92, -8, 0), 1.0, pinks[1]),
             ((0.58, -0.05, -0.4), (86, -45, 0), 0.9, pinks[2]), ((-0.2, -0.3, -0.42), (92, 12, 0), 0.9, pinks[1]),
             ((0.38, -0.45, -0.45), (94, 60, 0), 0.8, pinks[0]), ((0.0, -0.02, -0.25), (80, 45, 0), 0.85, pinks[2]))
    for (loc, rot_, ln, m) in spots:
        prism(outline(ln, 0.36), 0.022, loc=loc, rot=rot_, m=m, bev=0.004, deform=curled)
    turn(15)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def reed():
    """Reed: two jointed green canes with narrow blades and one tall feathery seed plume."""
    cane = mat("#8a9a4a", 0.55, color2="#5e6e2a", tex="wave", scale=8.0, bump=0.2)
    node = mat("#c8c48a", 0.5)
    for x, h, tilt in ((-0.2, 2.2, 5), (0.22, 1.8, -7)):
        g = group(loc=(x, -abs(x) * 0.5, 0), rot=(0, tilt, 0))
        cyl(0.08, h, loc=(0, 0, h / 2 - 1.1), m=cane, segs=12, parent=g)
        for k in range(3):
            cyl(0.095, 0.05, loc=(0, 0, -1.1 + 0.52 * (k + 1)), m=node, segs=12, parent=g)
        cyl(0.05, 0.45, loc=(0, 0, h - 0.78), r2=0.0, m=cane, segs=8, parent=g)
    plume = mat("#d8c49a", 0.95, color2="#b89a68", tex="noise", scale=16.0, bump=0.8)
    base = (-0.07, 0.0, 1.05)
    for k in range(26):
        t = k / 25.0
        a = k * 2.399
        rr = 0.16 * math.sin(math.pi * min(0.15 + t * 1.1, 1.0))
        tube([base, (base[0] + rr * math.cos(a), base[1] + rr * math.sin(a), base[2] + 0.2),
              (base[0] + rr * 1.6 * math.cos(a), base[1] + rr * 1.6 * math.sin(a), base[2] + 0.55 + 0.5 * t)],
             0.02, plume, segs=4, taper=(1.0, 0.3))
    cyl(0.025, 0.85, loc=(base[0], base[1], base[2] + 0.35), m=cane, segs=6)
    blade = mat("#7a9a3a", 0.55, color2="#4e6e24", tex="wave", scale=7.0)
    leaf(1.3, 0.12, loc=(-0.15, -0.1, -0.1), rot=(0, 38, 0), m=blade, curl=0.2)
    leaf(1.0, 0.1, loc=(0.18, -0.1, -0.25), rot=(0, -42, 0), m=blade, curl=0.15)
    tie = rope_m("#b85a2a")
    tube(arc((0, 0, 0), 0.27, 0, 360, 16, plane="xy", y=-0.12)[:-1], 0.045, tie, segs=6, closed=True)
    lean(-16)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def root():
    """A dug-up taproot with claw-like branches, dirt still clinging to the fibres."""
    m = mat("#6a4a2e", 0.9, color2="#3e2a18", tex="noise", scale=5.0, bump=0.5)
    tube([(0.0, 0, 1.15), (-0.1, 0, 0.6), (0.05, 0, 0.0), (-0.05, 0, -0.7), (0.1, 0, -1.15)], 0.19, m, segs=12,
         taper=(1.0, 0.35))
    tube([(0.0, 0, 0.4), (0.45, 0.05, 0.0), (0.8, 0.1, -0.45), (1.05, 0.1, -0.95)], 0.1, m, segs=8, taper=(1.0, 0.2))
    tube([(-0.05, 0, 0.1), (-0.5, -0.05, -0.25), (-0.85, -0.1, -0.6), (-1.0, -0.12, -1.0)], 0.09, m, segs=8,
         taper=(1.0, 0.2))
    tube([(0.04, 0, -0.5), (0.4, 0.06, -0.8), (0.6, 0.1, -1.15)], 0.07, m, segs=6, taper=(1.0, 0.25))
    for k in range(7):
        a = k * 1.1
        tube([(0.0, 0.02 * k, 0.9 - 0.05 * k), (0.35 * math.cos(a), 0.1, 0.75 + 0.1 * math.sin(a))], 0.018,
             mat("#c8a878", 0.8), segs=4, taper=(1.0, 0.3))
    soil = mat("#4a3a28", 0.95, color2="#2e2418", tex="noise", scale=9.0, bump=0.4)
    for p in ((0.25, -0.15, 0.35), (-0.3, -0.1, -0.15), (0.15, 0.15, -0.35)):
        rock(0.14, loc=p, m=soil, jitter=0.3, sub=1)
    lean(-20)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def vine():
    """Jungle vine: a long thin liana looped twice like a lashing, bark ridges along it, three leaves."""
    m = mat("#566e30", 0.65, color2="#32421a", tex="wave", scale=14.0, bump=0.5)
    pts = []
    for i in range(120):
        a = i * 0.16
        r = 0.95 - 0.0045 * i
        pts.append((r * math.cos(a), r * math.sin(a) * 0.55, 0.05 * math.sin(a * 0.5) + i * 0.004))
    tube(pts, 0.1, m, segs=8)
    tip = pts[-1]
    tube([tip, (tip[0] + 0.25, tip[1] - 0.2, tip[2] + 0.45), (tip[0] + 0.5, tip[1] - 0.35, tip[2] + 0.6)], 0.08, m,
         segs=6, taper=(1.0, 0.5))
    g_m = mat("#78a840", 0.45, color2="#54802a", tex="wave", scale=6.0, bump=0.1)
    for k, ang, ln in ((6, 35, 0.8), (34, -40, 0.75), (64, 25, 0.7), (90, -20, 0.6)):
        p = pts[k]
        leaf(ln, 0.3, loc=(p[0], p[1] + 0.04, p[2] + 0.08), rot=(20, ang, 0), m=g_m, curl=0.14)
    turn(35, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def mud():
    """Wet mud: a rough, matte clod of brown soil with cracks across it and a couple of grass blades
    stuck in it; wet dark rims where the water has soaked in, but no shine."""
    wet = mat("#6a4e2c", 0.9, color2="#46301a", tex="noise", scale=9.0, bump=0.9, spec=0.3)
    wet2 = mat("#7e6038", 0.9, color2="#55391c", tex="noise", scale=11.0, bump=0.9, spec=0.3)
    dark = mat("#3a2814", 0.8, color2="#26180a", tex="noise", scale=12.0, bump=0.6)
    rock(0.85, loc=(0, 0, -0.05), scl=(1.15, 0.95, 0.85), m=wet, jitter=0.26, sub=2, smooth=True)
    rock(0.4, loc=(0.75, -0.3, -0.45), scl=(1.2, 1.0, 0.8), m=wet2, jitter=0.3, sub=2, smooth=True)
    rock(0.34, loc=(-0.75, 0.1, -0.45), scl=(1.1, 1.0, 0.85), m=wet2, jitter=0.3, sub=1, smooth=True)
    for (x0, y0, x1, y1, z) in ((-0.55, -0.45, 0.2, 0.1, 0.5), (0.1, 0.35, 0.55, 0.1, 0.0), (-0.2, 0.55, -0.3, 0.2, 0.1)):
        pts = [(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z - 0.45 + 0.03 * math.sin(t * 11)) for t in (i / 6 for i in range(7))]
        tube(pts, 0.02, dark, segs=4)
    blade = mat("#6a9a3a", 0.5, color2="#4a7a28", tex="wave", scale=7.0)
    leaf(0.95, 0.1, loc=(0.2, -0.1, 0.5), rot=(0, 40, 0), m=blade, curl=0.2)
    leaf(0.8, 0.09, loc=(-0.25, -0.15, 0.45), rot=(0, -50, 0), m=blade, curl=0.15)
    turn(12)
    turn(10, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def ochre():
    """Chalky yellow-red ochre: rough angular chunks with a dusty smear of pigment on the ground."""
    m = mat("#d07c32", 0.98, color2="#a0561e", tex="noise", scale=7.0, bump=0.9, ramp=(0.25, 0.85))
    rock(0.6, loc=(-0.1, 0.0, 0.05), scl=(1.15, 1.0, 0.95), m=m, jitter=0.18, sub=2, smooth=True, rot=(10, 20, 0))
    rock(0.32, loc=(0.75, -0.15, -0.2), scl=(1.1, 1.0, 0.85), m=m, jitter=0.22, sub=2, smooth=True)
    rock(0.22, loc=(-0.7, -0.25, -0.3), scl=(1.1, 1.0, 0.9), m=m, jitter=0.2, sub=1, smooth=True)
    powder = mat("#f0a850", 0.98, color2="#c87a30", tex="noise", scale=16.0, bump=0.5)
    for (x, y, r) in ((0.35, -0.4, 0.45), (-0.45, -0.35, 0.3), (0.05, 0.45, 0.25)):
        blob(r, loc=(x, y, -0.55), scl=(1.3, 1.0, 0.14), m=powder, amp=0.25, sub=2)
    turn(12)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def peat():
    """Peat: a cut turf brick, dark brown fibrous soil with a mossy green top, beside a half brick;
    the chopped end shows the tight pale fibre layers and a few crumbs lie around."""
    m = mat("#4a3420", 0.98, color2="#2a1a0a", tex="noise", scale=40.0, bump=1.0, ramp=(0.35, 0.7))
    moss = mat("#4c5a2a", 0.95, color2="#333e18", tex="noise", scale=30.0, bump=0.5)
    cut = mat("#8a6a3e", 0.98, color2="#5a4022", tex="noise", scale=44.0, bump=0.7)
    box((1.5, 1.0, 0.7), m=m, bev=0.07)
    box((1.42, 0.92, 0.06), loc=(0, 0, 0.36), m=moss, bev=0.03)
    box((0.95, 0.9, 0.6), loc=(0.38, 0.12, 0.62), rot=(0, 0, 14), m=m, bev=0.07)
    box((0.88, 0.82, 0.05), loc=(0.38, 0.12, 0.93), rot=(0, 0, 14), m=moss, bev=0.02)
    box((0.04, 0.92, 0.62), loc=(-0.72, 0.0, 0.0), m=cut, bev=0.0)
    for k in range(6):
        z = -0.2 + 0.08 * k
        tube([(-0.74, -0.4, z), (-0.74, 0.0, z + 0.01), (-0.74, 0.4, z - 0.01)], 0.022,
             mat("#3e2a12", 0.98, color2="#2a1a08", tex="noise", scale=40.0), segs=4)
    crumb = mat("#4a3420", 0.98, color2="#2a1a0a", tex="voronoi", scale=12.0, bump=0.6)
    for p_ in ((-0.95, -0.3, -0.42), (-0.78, -0.5, -0.45), (0.95, -0.2, -0.43), (0.9, 0.2, -0.45)):
        rock(0.09, loc=p_, m=crumb, jitter=0.35, sub=1)
    turn(15)
    turn(12, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


# ---------------------------------------------------------------- ICONS4: materials, ingot, planks
# Same palette, parts and framing as the set above: an ingot is _ingot, a hide is _pelt, a herb is
# leaves on a stem. Only the silhouette each item needs is new.

def moss():
    """Moss: a cushion of moss on a broken stone slab, lumpy clumps with paler crowns, a few upright
    sprigs and two seed capsules on hair-thin stalks."""
    m = mat("#4e7a34", 0.95, color2="#2e5220", tex="noise", scale=26.0, bump=0.8, spec=0.15)
    m2 = mat("#6f9a40", 0.95, color2="#43702a", tex="noise", scale=30.0, bump=0.9, spec=0.15)
    rock(1.0, scl=(1.35, 1.0, 0.42), loc=(0, 0.1, -0.6), m=stone("#7a7a74", "#54544e"), jitter=0.12, sub=2)
    for (x, y, r, mm) in ((-0.35, 0.02, 0.5, m), (0.3, -0.1, 0.46, m2), (0.62, 0.2, 0.28, m),
                          (-0.62, 0.22, 0.3, m2), (0.0, 0.32, 0.4, m), (0.05, -0.38, 0.32, m2)):
        blob(r, loc=(x, y, -0.22 + 0.2 * r), scl=(1.25, 1.0, 0.72), m=mm, amp=0.32, freq=3.2, sub=3)
    sprig = mat("#7fb04c", 0.9, color2="#5a8a34", tex="noise", scale=20.0)
    for (x, y, h, lean_) in ((-0.2, -0.15, 0.85, 6.0), (0.22, 0.05, 0.7, -8.0), (0.0, -0.3, 0.6, 3.0),
                             (0.5, -0.2, 0.5, -5.0)):
        g = group(loc=(x, y, 0.05), rot=(0, lean_, 0))
        tube([(0, 0, 0), (0.02, 0, h * 0.6), (0.05, 0, h)], 0.018, sprig, segs=5, parent=g)
        for k in range(4):
            z = h * (0.25 + 0.18 * k)
            leaf(0.17, 0.05, loc=(0.03, 0, z), rot=(0, (k % 2) * 150 - 75, 0), m=sprig, curl=0.03, parent=g)
    for (x, y, h) in ((-0.42, -0.05, 1.15), (0.34, 0.22, 1.0)):
        cyl(0.012, h, loc=(x, y, h / 2), m=sprig, segs=4)
        blob(0.075, loc=(x, y, h + 0.05), scl=(0.8, 0.8, 1.3), m=mat("#b8843c", 0.85, color2="#8a5c22",
                                                                     tex="noise", scale=14.0), amp=0.18, sub=2)
    turn(12)
    turn(14, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def cactus_flower():
    """Cactus flower: a spineless green pad with a magenta bloom on its crown, a second bud beside
    it, the petals curled outward, the pad's rim fringed with short spines."""
    pad = mat("#5aa04a", 0.42, color2="#3e7a32", tex="noise", scale=4.0, coat=0.35, bump=0.12)
    g = group(rot=(0, -12, 0))
    blob(1.0, scl=(0.85, 0.3, 1.05), m=pad, amp=0.05, parent=g)
    ring = mat("#4e8a40", 0.45, color2="#356a2a", tex="noise", scale=6.0)
    tube(arc((0, 0, 0), 0.92, 0, 360, 26, plane="xz", y=0.0)[:-1], 0.035, ring, segs=4, closed=True, parent=g)
    sp = mat("#f6f0dc", 0.4)
    for k in range(14):
        a = math.radians(k * 25.7)
        cyl(0.02, 0.13, loc=(0.9 * math.cos(a) * 0.85, -0.3, 0.9 * math.sin(a) * 1.03),
            rot=(90, 0, -math.degrees(a)), r2=0.0, m=sp, segs=5, parent=g)
    petal_m = mat("#c83c78", 0.45, color2="#8a1a4e", tex="noise", scale=7.0, bump=0.2, coat=0.3)
    petal_m2 = mat("#e0609a", 0.45, color2="#a83468", tex="noise", scale=7.0, bump=0.2, coat=0.3)
    for i in range(9):  # bloom: two petal rings, the older ones curled back
        a = math.radians(40 * i)
        outer = i % 3 != 0
        r0 = 0.16
        ln = 0.68 if outer else 0.52
        leaf(ln, 0.2, loc=(r0 * math.cos(a), -0.42 - 0.05 * outer, 0.62 + r0 * math.sin(a)),
             rot=(38 if outer else 20, -math.degrees(a) + 90, 0), m=petal_m2 if outer else petal_m,
             curl=-0.22 if outer else -0.1, parent=g)
    blob(0.14, loc=(0, -0.44, 0.66), scl=(1.0, 0.7, 1.0), m=mat("#f2c22a", 0.5, color2="#c89a1a",
                                                                tex="noise", scale=12.0), amp=0.15, parent=g)
    bud = mat("#b8306c", 0.5, color2="#7e1a48", tex="noise", scale=8.0)
    for k in range(4):
        a = math.radians(90 * k + 40)
        leaf(0.34, 0.13, loc=(0.55 + 0.1 * math.cos(a), -0.35, -0.3 + 0.1 * math.sin(a)),
             rot=(30, -math.degrees(a) + 90, 0), m=bud, curl=-0.18, parent=g)
    turn(14)
    turn(10, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def tin_ore():
    """Tin ore: pale tin-white nuggets in a dark slate host, the nuggets blunt and matte (not the
    gold of plain ore, not the copper of copper ore)."""
    _ore(metal("#cfd8de", 0.45), host=stone("#575b60", "#35383c"), n=5, big=0.26)
    turn(12)
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def tin_ingot():
    """Tin ingot: three dull pale-grey bars, softer and lighter than iron's, with a faint hammered
    top rather than steel's polish."""
    m = mat("#c2ccd4", 0.5, metal=0.75, color2="#8e9aa4", tex="noise", scale=9.0, bump=0.25)
    for loc in ((0, -0.32, 0), (0, 0.32, 0), (0, 0, 0.34)):
        box((1.2, 0.56, 0.28), loc=loc, m=m, bev=0.05, taper=(0.86, 0.8))
        for k in range(3):  # hammer dimples along the cast face
            ball(0.075, loc=(loc[0] - 0.35 + 0.35 * k, loc[1], loc[2] + 0.14), scl=(1.3, 1.0, 0.25), m=m, sub=2)
    turn(24)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def fine_plank():
    """Fine plank: a planed, knot-free board with a chamfered edge, its sawn end showing tight ring
    grain, a curled shaving lying on it: the dressed board, not the rough plank pair."""
    w = mat("#e2b478", 0.4, color2="#c08a48", tex="wave", scale=3.5, bump=0.06, spec=0.6, coat=0.25)
    end = mat("#f0d49a", 0.55, color2="#cca468", tex="rings", scale=7.0, bump=0.06)
    # One wide dressed board, its top face oiled to a sheen: no second board, no offcuts.
    box((2.6, 0.72, 0.16), m=w, bev=0.014)
    for s in (-1, 1):
        box((0.03, 0.7, 0.15), loc=(s * 1.31, 0, 0), m=end, bev=0.0)
    for y in (-0.36, 0.36):  # chamfered long edges catch a lighter line
        tube([(-1.3, y, 0.075), (0, y, 0.08), (1.3, y, 0.075)], 0.028, end, segs=4)
    # Shaving: a broad curl of planed wood standing on the board, well in front of it.
    sh = mat("#f6e2b4", 0.45, color2="#d0aa74", tex="wave", scale=6.0, bump=0.1)
    pts = [(math.cos(t * 0.5) * r, 0.0, math.sin(t * 0.5) * r)
           for t in (i * 0.42 for i in range(16)) for r in (0.24,)]
    ob = tube([(p[0] * (1 - 0.018 * i), p[1], p[2] * (1 - 0.018 * i)) for i, p in enumerate(pts)], 0.035, sh, segs=5)
    ob.location = (0.35, -0.42, 0.3)
    ob.rotation_euler = (math.radians(70), 0, math.radians(25))
    turn(6)
    turn(16, "X")
    lean(-26)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def trimmed_plank():
    """Trimmed plank: a board with its ends cut square and a bead moulded along one edge, the two
    offcuts lying under it and sawdust at the cut."""
    w = mat("#c48d55", 0.65, color2="#93602f", tex="wave", scale=3.5, bump=0.18)
    end = mat("#dcb37a", 0.65, color2="#b08a52", tex="rings", scale=6.0, bump=0.1)
    box((2.5, 0.15, 0.6), m=w, bev=0.012)
    for s in (-1, 1):
        box((0.04, 0.16, 0.58), loc=(s * 1.27, 0, 0), m=end, bev=0.0)
        # mitre chamfer on the corner
        box((0.16, 0.15, 0.16), loc=(s * 1.19, 0, 0.24), rot=(0, 0, 0), m=w, bev=0.0)
    tube([(-1.2, -0.1, 0.34), (0, -0.11, 0.35), (1.2, -0.1, 0.34)], 0.055, w, segs=6)  # bead along the edge
    for (x, y, rot_) in ((-0.55, 0.42, 12), (0.62, 0.4, -8)):  # offcuts
        box((0.5, 0.14, 0.2), loc=(x, y, -0.32), rot=(0, 0, rot_), m=w, bev=0.01)
    dust = mat("#d8b878", 0.95, color2="#b08a4a", tex="noise", scale=40.0, bump=0.5)
    for x in (-1.15, -1.05, -0.95, 1.05, 1.15):
        blob(0.055, loc=(x, -0.3, -0.38), scl=(1.3, 1.0, 0.5), m=dust, amp=0.3, sub=2)
    turn(-6)
    lean(-24)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def plank_shape():
    """Plank shape: a cut component board with a lap-joint notch at one end and a cut tenon at the
    other, the grain running its length: a plank-shaped part, not a finished plank."""
    w = mat("#b8814a", 0.7, color2="#8a5a2c", tex="wave", scale=4.0, bump=0.2)
    end = mat("#cf9c62", 0.7, color2="#a87440", tex="rings", scale=7.0, bump=0.1)
    # Body: a full-width board in two steps, the upper one shorter, so the lap notch reads.
    box((2.5, 0.52, 0.3), loc=(0, 0, -0.14), m=w, bev=0.014)
    box((1.7, 0.5, 0.3), loc=(0.4, 0, 0.16), m=w, bev=0.014)
    # Cut faces: sawn end grain at every step, so the notches are unambiguous.
    for (x, z, sx, sz) in ((1.24, -0.14, 0.012, 0.6), (-1.24, -0.14, 0.012, 0.6), (1.24, 0.16, 0.012, 0.3),
                           (-0.44, 0.16, 0.012, 0.3), (0.4, 0.31, 0.5, 0.012), (0.4, -0.02, 0.9, 0.012),
                           (0.82, 0.16, 0.012, 0.3)):
        box((max(sx, 0.012), 0.525, max(sz, 0.012)), loc=(x, 0, z), m=end, bev=0.0)
    box((0.3, 0.525, 0.02), loc=(0.98, 0, 0.16), m=end, bev=0.0)  # the tongue left by the cut
    turn(10)
    lean(-22)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def pillar_shape():
    """Pillar shape: a squared timber blank for a pillar, with a tenon cut on the top end and a
    mortise hole through the bottom, no iron bands or rope (the pillar kit is the finished post)."""
    w = mat("#b07c44", 0.75, color2="#7a5026", tex="wave", scale=5.0, bump=0.3)
    end = mat("#d8a868", 0.7, color2="#b0824a", tex="rings", scale=6.0, bump=0.12)
    box((0.66, 0.66, 2.3), m=w, bev=0.02)
    cyl(0.17, 0.3, loc=(0, 0, 1.3), m=w, segs=4, smooth=False, rot=(0, 0, 45))  # tenon
    box((0.2, 0.54, 0.2), loc=(0, 0, -0.62), m=end, bev=0.0)  # mortise bore, dark
    box((0.54, 0.2, 0.2), loc=(0, 0, -0.62), m=end, bev=0.0)
    for z in (-1.15, 1.05):
        box((0.54, 0.54, 0.02), loc=(0, 0, z), m=end, bev=0.0)
    turn(26)
    lean(-14)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def strap():
    """Strap: a cut leather belt coiled on itself, an iron buckle on the loose end and punched holes
    down it (hide_strap is the uncut length; this is the finished strap)."""
    lea = hidem("#8a5a32", "#6a4020")
    lea2 = hidem("#734826", "#523014")
    punch = mat("#241608", 1.0)

    def loop(r_out, r_in, y, a0, a1, m, thick=0.11):
        n = 44
        pts = []
        for i in range(n + 1):
            a = math.radians(a0 + (a1 - a0) * i / n)
            pts.append((r_out * math.cos(a), r_out * math.sin(a)))
        for i in range(n, -1, -1):
            a = math.radians(a0 + (a1 - a0) * i / n)
            pts.append((r_in * math.cos(a), r_in * math.sin(a)))
        prism(pts, thick, loc=(0, y, 0), m=m, bev=0.008)
    loop(1.02, 0.86, 0.09, 20, 400, lea)         # the outer turn, overlapping its own start
    loop(0.82, 0.66, 0.0, 150, 505, lea2)        # the inner turn, offset the other way
    loop(0.62, 0.46, -0.09, 250, 560, lea)       # a third, shorter turn so the spiral steps down
    # The loose end runs off the coil, with punched holes and the buckle on it.
    tail = [(1.0, 0.02, -0.12), (1.22, 0.02, -0.24), (1.42, 0.02, -0.36)]
    tube(tail, 0.085, lea2, segs=6)
    for t in (0.4, 0.7, 0.95):
        p = (1.0 + 0.42 * t, 0.02, -0.12 - 0.24 * t)
        cyl(0.04, 0.18, loc=p, rot=(90, 0, 0), m=punch, segs=8)
    iron = metal("#8a8e94", 0.4)
    b = group(loc=(1.5, 0.05, -0.42), rot=(0, 40, 0))
    for sz in (0.2, -0.2):
        box((0.3, 0.07, 0.06), loc=(0, 0, sz), m=iron, bev=0.01, parent=b)
    for sx in (-0.14, 0.14):
        box((0.06, 0.07, 0.4), loc=(sx, 0, 0), m=iron, bev=0.01, parent=b)
    box((0.28, 0.06, 0.04), loc=(0.02, -0.03, 0), m=iron, bev=0.008, parent=b)
    turn(-58, "X")
    turn(-16)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


ITEMS = {
    "branch": branch, "wood_log": wood_log, "pine_log": pine_log, "plank": plank, "pillar": pillar,
    "bamboo": bamboo, "stone": stone_item, "flint": flint, "obsidian": obsidian, "sandstone": sandstone,
    "lava": lava, "ore": ore, "copper_ore": copper_ore, "silver_ore": silver_ore, "black_iron": black_iron,
    "metal_shard": metal_shard, "ingot": ingot, "copper_ingot": copper_ingot, "bronze_ingot": bronze_ingot,
    "iron_ingot": iron_ingot, "steel_ingot": steel_ingot, "charcoal": charcoal, "bone": bone,
    "raptor_bone": raptor_bone, "dense_bone": dense_bone, "raptor_talon": raptor_talon, "armor_scute": armor_scute,
    # BONEPARTS: species bone parts.
    "hollow_bone": hollow_bone, "large_leg_bone": large_leg_bone, "stout_leg_bone": stout_leg_bone,
    "brow_horn": brow_horn, "tail_spike": tail_spike, "tail_club": tail_club, "dorsal_plate": dorsal_plate,
    "frill_plate": frill_plate, "skull_plate": skull_plate,
    "venom_gland": venom_gland, "predator_tendon": predator_tendon, "pearl": pearl, "coral": coral, "salt": salt,
    "sulphur": sulphur, "clay": clay, "resin": resin, "ice": ice, "raw_hide": raw_hide, "raptor_hide": raptor_hide,
    "dried_hide": dried_hide, "hide_strap": hide_strap, "rope": rope, "twine": twine, "thread": thread,
    "cloth": cloth_item, "fibre_stalk": fibre_stalk, "flax": flax, "wheat": wheat, "dry_grass": dry_grass,
    "palm_frond": palm_frond, "herb_leaf": herb_leaf, "blue_dye": blue_dye, "split_wood": split_wood,
    # dsc icons2: the raw materials that had no render.
    "acacia_wood": acacia_wood, "willow_wood": willow_wood, "snow_pine": snow_pine, "ash": ash,
    "bark_strip": bark_strip, "cactus_spine": cactus_spine, "cloth_scrap": cloth_scrap, "leech": leech,
    "marsh_herb": marsh_herb, "spice_herb": spice_herb, "petals": petals, "reed": reed, "root": root,
    "vine": vine, "mud": mud, "ochre": ochre, "peat": peat,
    # dsc icons4: the first-hour materials and boards.
    "moss": moss, "cactus_flower": cactus_flower, "tin_ore": tin_ore, "tin_ingot": tin_ingot,
    "fine_plank": fine_plank, "trimmed_plank": trimmed_plank, "plank_shape": plank_shape,
    "pillar_shape": pillar_shape, "strap": strap,
}
