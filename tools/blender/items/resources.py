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
    """Black iron: a dark rust-red host rock studded with purple-black metallic crystals: one large
    cluster and a few small ones, their faces catching a violet sheen. Unlike obsidian's unhosted
    glass shards."""
    host = mat("#6a3a2c", 0.9, color2="#402018", tex="noise", scale=6.0, bump=0.6)
    rock(0.95, scl=(1.3, 1.0, 0.8), m=host, jitter=0.16, sub=2)
    xtal = mat("#2e2846", 0.14, metal=1.0, color2="#7a68b0", tex="noise", scale=5.0, bump=0.15, spec=1.0)
    for (x, y, z, h, w) in ((-0.25, -0.3, 0.15, 1.5, 0.27), (0.1, -0.45, 0.0, 1.1, 0.2),
                             (0.45, -0.2, 0.05, 0.95, 0.18), (-0.5, 0.0, 0.0, 0.8, 0.15),
                             (0.2, 0.15, 0.3, 0.7, 0.13)):
        tilt = (10 * (x > 0), 14 * (y < 0), 0)
        cyl(w, h, loc=(x, y, z + h * 0.35), rot=tilt, m=xtal, segs=6, r2=w * 0.4, smooth=False)
    fleck = mat("#c87a3a", 0.5, color2="#8a4a1a", tex="voronoi", scale=9.0, bump=0.3)
    for p_ in ((0.75, -0.35, -0.05), (-0.8, -0.2, -0.15)):
        rock(0.1, loc=p_, m=fleck, jitter=0.3, sub=0)
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
def steel_ingot():
    """Steel: bright polished bars, sharp true edges, a cold blue sheen and a stamped mark on top."""
    m = mat("#dfe8f2", 0.1, metal=0.95, color2="#8fa0b4", tex="noise", scale=5.0, bump=0.03)
    for loc in ((0, -0.33, 0), (0, 0.33, 0), (0, 0, 0.36)):
        box((1.24, 0.56, 0.3), loc=loc, m=m, bev=0.012, taper=(0.9, 0.88))
        tube([(-0.56, loc[1] - 0.26, loc[2] + 0.16), (0.56, loc[1] - 0.26, loc[2] + 0.16)], 0.012,
             mat("#f4f8ff", 0.05, metal=1.0), segs=4)
    box((0.4, 0.2, 0.02), loc=(0, 0, 0.53), m=mat("#4e5a68", 0.3), bev=0.004)
    turn(24)
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
def raptor_talon():
    pts = arc((-0.6, 0, -0.3), 1.0, -15, 80, 16)
    tube(pts, 0.28, mat("#3a3128", 0.3, color2="#d8c39a", tex="noise", scale=1.5, coat=0.6), segs=14, taper=(1.0, 0.04))
    blob(0.33, loc=pts[0], scl=(1.1, 0.9, 0.8), m=mat("#8a5a3c", 0.7), amp=0.08)
    lean(-10)


def armor_scute():
    """Armor scute: two overlapping bony plates off a big animal's back: thick off-white bone, a heavy
    ridge and chipped, uneven rims, one plate sitting on the other (not a smooth gem)."""
    bone = mat("#d8ccb0", 0.65, color2="#a89c7c", tex="noise", scale=6.0, bump=0.45, ramp=(0.35, 0.8))
    keel = mat("#efe6cc", 0.5, color2="#c8bc9c", tex="noise", scale=8.0, bump=0.3)
    pit = mat("#8a7c5a", 0.9, color2="#6a5e40", tex="voronoi", scale=9.0, bump=0.5)

    def plate(x, z, sc, rot_z):
        pts = []
        n = 14
        for k in range(n):
            a = 2 * math.pi * k / n
            rr = 0.9 + 0.1 * ((k * 7) % 5) / 5.0
            pts.append((rr * sc * math.cos(a), rr * sc * 0.8 * math.sin(a)))
        g = group(loc=(x, 0.1 * sc, z), rot=(10, 0, rot_z))
        prism(pts, 0.26, m=bone, bev=0.06, parent=g,
              deform=lambda co: co.__setitem__(1, co.y + 0.28 * (1 - min(1.0, (co.x ** 2 + co.z ** 2) / 0.7))))
        # The keel: a low ridge across the plate, its ends stopping short of the rim.
        tube([(-0.5 * sc, 0, 0.3), (-0.2 * sc, 0, 0.45), (0.2 * sc, 0, 0.45), (0.5 * sc, 0, 0.3)],
             0.07, keel, segs=6, taper=(0.5, 0.5), parent=g)
        for k in range(5):  # pits along the flanks
            a = 0.4 + 0.55 * k
            ball(0.05, loc=(0.55 * sc * math.cos(a), 0.2, 0.45 * sc * math.sin(a)), m=pit, sub=2, parent=g)
    plate(-0.15, -0.35, 1.15, 0)
    plate(0.2, 0.32, 0.9, 18)
    turn(10)
    turn(34, "X")
    upright()  # flat item: diagonal so the slot can lift it above its top edge
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
def raptor_hide():
    """Raptor hide: a feathered green hide: dark bands of feather rows across a moss-green skin,
    quills along the torn edge (raw_hide is the bare, wet flesh side)."""
    skin = mat("#5a6a34", 0.7, color2="#3a481c", tex="noise", scale=8.0, bump=0.4, ramp=(0.4, 0.8))
    band = mat("#28320f", 0.85, color2="#161e06", tex="noise", scale=10.0, bump=0.5)
    tuft = mat("#8a9a52", 0.7, color2="#62722e", tex="wave", scale=14.0, bump=0.3)
    _pelt(skin)
    # Feather rows: four wavy dark bands, each a row of overlapping tufts along its upper edge.
    for row in range(4):
        z = -0.6 + 0.4 * row
        pts = [(-0.55 + 0.11 * k, 0.0, z + 0.06 * math.sin(k * 1.2)) for k in range(11)]
        tube(pts, 0.07, band, segs=5)
        for k in range(1, 10, 2):
            p = pts[k]
            blob(0.09, loc=(p[0], -0.05, p[2] + 0.05), scl=(1.3, 0.5, 1.0), m=tuft, amp=0.1, sub=2)
    P = _PELT
    for k in range(0, len(P), 2):
        x0, z0 = P[k]
        x1, z1 = P[(k + 1) % len(P)]
        x = x0 + (x1 - x0) * 0.5
        z = z0 + (z1 - z0) * 0.5
        tube([(x * 0.92, 0.03, z * 0.92), (x * 1.04, 0.05, z * 1.04)], 0.03, tuft, segs=4, taper=(1.0, 0.3))
    turn(-10)
def dried_hide():
    """Dried hide: a stiff, translucent-amber sheet of rawhide with the fur scraped off, its edges
    curled hard and a few crackle wrinkles; pegged out flat like a drying frame."""
    m = mat("#d8b076", 0.85, color2="#a87a44", tex="noise", scale=9.0, bump=0.35, ramp=(0.4, 0.8))
    inner = mat("#e8c894", 0.85, color2="#c09660", tex="noise", scale=10.0, bump=0.25)
    outline = [(-1.0, -0.7), (-0.5, -0.85), (0.1, -0.78), (0.6, -0.9), (1.0, -0.6), (0.92, -0.1), (1.0, 0.4),
               (0.7, 0.8), (0.2, 0.72), (-0.2, 0.9), (-0.7, 0.75), (-1.0, 0.4), (-0.9, 0.0)]

    def curl(co):
        # Stiff edges curling up, and a few crackle wrinkles across the sheet.
        d = max(abs(co.x), abs(co.z))
        co.y += 0.35 * max(0.0, d - 0.7) ** 1.6 + 0.05 * math.sin(co.x * 7.0) * math.cos(co.z * 6.0)
    prism(outline, 0.04, m=m, bev=0.01, deform=curl)
    # The clean inner side showing where the edge curls over.
    prism([(x * 0.96, z * 0.96) for x, z in outline], 0.02, loc=(0, 0.03, 0), m=inner, bev=0.006,
          deform=lambda co: co.__setitem__(1, co.y + 0.35 * max(0.0, max(abs(co.x), abs(co.z)) - 0.7) ** 1.6 + 0.05 * math.sin(co.x * 7.0) * math.cos(co.z * 6.0) - 0.01))
    # Slit holes where the hide was pegged out.
    for (x, z) in ((-0.85, 0.1), (0.85, 0.0), (0.0, 0.8), (-0.3, -0.75)):
        cyl(0.05, 0.08, loc=(x, 0.05, z), rot=(90, 0, 0), m=mat("#5a4028", 0.9), segs=8)
    turn(-8)
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
    """Cloth: three folded lengths of woven cloth stacked (linen, rust, indigo), each with soft folds
    and a frayed edge, the top one unfolded a little over the pile."""
    linen = _weave("#d8cdb0", "#b0a482", scale=34.0, bump=0.9)
    rust = _weave("#b06040", "#8a4230", scale=32.0, bump=0.9)
    blue = _weave("#7a8fa8", "#566a82", scale=30.0, bump=0.9)
    fringe = mat("#c4b896", 1.0, color2="#9a8e70", tex="noise", scale=20.0, bump=0.2)
    # Three folded sheets: each a gently waving sheet, stacked with a slight offset.
    for i, (z, m) in enumerate(((-0.5, blue), (-0.22, rust), (0.06, linen))):
        def fold(u, v, k=i):
            x = (u * 2.0 - 1.0) * (1.0 - 0.12 * v)
            return (x + 0.05 * k, 0.12 * math.sin(x * 2.2 + k) + 0.04 * math.sin(v * 6.0), z + v * 0.2 - 0.06 * u * u)
        _sheet(13, 7, fold, m, thick=0.06)
    # The top length unfolds forward over the pile edge, its hem frayed.
    def drape(u, v):
        x = (u * 2.0 - 1.0) * 1.05
        return (x, -0.1 - 0.3 * v + 0.1 * math.sin(x * 2.4) * v, 0.26 - 0.55 * v * v - 0.1 * v)
    _sheet(13, 9, drape, linen, thick=0.05)
    for k in range(8):
        x = -0.85 + 0.24 * k
        tube([(x, -0.4, -0.34), (x + 0.03, -0.44, -0.5 - 0.04 * (k % 3))], 0.014, fringe, segs=4)
    turn(14)
    turn(16, "X")
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
    mix.inputs[6].default_value = srgb("#8a7c60")
    src = next(n for n in nt.nodes if n.type == "VALTORGB")
    nt.links.new(src.outputs["Color"], mix.inputs[7])
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
    ob.parent = ROOT
    md = ob.modifiers.new("solid", "SOLIDIFY")
    md.thickness = thick
    return ob


def cloth_scrap():
    """Torn linen: a faded linen-coloured cloth square heaped over itself in folds, the weave showing,
    the hem torn ragged with a few loose threads. Irregular outline, soft folds; not a flat plane."""
    face = _weave("#dcd2b4", "#bdb08e", scale=30.0, bump=0.9)
    back = _weave("#c8bc9c", "#a89a78", scale=26.0, bump=0.8)
    thread = mat("#d8ccae", 0.95, color2="#b0a482", tex="noise", scale=30.0, bump=0.3)

    def cloth(u, v):
        # Width narrows with a torn, wavy edge; the hem is uneven; the cloth piles into folds at the
        # bottom where it doubles over itself.
        half = 0.85 * (0.82 + 0.18 * math.sin(v * 5.0 + 0.4)) * (1.0 - 0.22 * v)
        x = (u * 2.0 - 1.0) * half
        z = 0.95 - (1.55 + 0.22 * math.sin(u * 9.0 + 1.1)) * v
        heap = 0.42 * max(0.0, v - 0.55) ** 1.5 * (0.6 + 0.4 * math.sin(u * math.pi * 2.2))
        fold = 0.2 * math.sin(u * math.pi * 3.1 + 0.6) * (0.3 + 0.7 * v)
        return (x, fold - 0.16 * v + 0.05 * math.sin(v * 8.0 + u * 5.0) - heap, z)
    _sheet(15, 15, cloth, face, thick=0.03)
    # The bottom corner folded up over the heap: a soft triangle of the other face of the weave.
    def flap(u, v):
        w = 0.62 * (1.0 - v)
        return (-0.3 + (u - 0.5) * 2.0 * w, -0.55 - 0.06 * math.sin(u * 4.0) + 0.06 * v,
                -0.55 + v * 0.85 + 0.05 * math.sin(u * math.pi))
    _sheet(9, 9, flap, back, thick=0.025)
    for i in range(9):   # loose threads from the torn hem
        u = 0.08 + 0.1 * i
        e = cloth(u, 1.0)
        tube([(e[0], e[1], e[2] + 0.02), (e[0] + 0.03, e[1] + 0.02, e[2] - 0.08 - 0.04 * (i % 3)),
              (e[0] - 0.01, e[1] + 0.03, e[2] - 0.15 - 0.04 * (i % 2))], 0.011, thread, segs=4)
    turn(8)
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


ITEMS = {
    "branch": branch, "wood_log": wood_log, "pine_log": pine_log, "plank": plank, "pillar": pillar,
    "bamboo": bamboo, "stone": stone_item, "flint": flint, "obsidian": obsidian, "sandstone": sandstone,
    "lava": lava, "ore": ore, "copper_ore": copper_ore, "silver_ore": silver_ore, "black_iron": black_iron,
    "metal_shard": metal_shard, "ingot": ingot, "copper_ingot": copper_ingot, "bronze_ingot": bronze_ingot,
    "iron_ingot": iron_ingot, "steel_ingot": steel_ingot, "charcoal": charcoal, "bone": bone,
    "raptor_bone": raptor_bone, "dense_bone": dense_bone, "raptor_talon": raptor_talon, "armor_scute": armor_scute,
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
}
