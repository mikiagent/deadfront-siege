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


def pine_log():
    _log(0.36, 2.1, bark("#6a3a26", "#3e1f12"), "#e0b27a", loc=(0, 0.2, 0))
    _log(0.3, 1.8, bark("#6a3a26", "#3e1f12"), "#e0b27a", loc=(0.1, -0.35, -0.05))
    _log(0.3, 1.9, bark("#6a3a26", "#3e1f12"), "#e0b27a", loc=(0.0, -0.05, 0.5))
    turn(30)


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
    w = wood("#a8743f", "#6f4520")
    box((0.5, 0.5, 2.6), m=w, bev=0.05)
    iron = metal("#55585c", 0.45)
    for z in (-0.95, 0.95):
        box((0.56, 0.56, 0.1), loc=(0, 0, z), m=iron, bev=0.015)
    turn(30)
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
    m = mat("#121116", 0.05, color2="#2a2630", tex="noise", scale=3.0, coat=1.0, spec=1.0)
    rock(0.55, loc=(0, 0, 0.35), scl=(0.8, 0.7, 2.0), m=m, jitter=0.25, sub=0, rot=(0, 8, 0))
    rock(0.45, loc=(-0.5, 0.1, -0.1), scl=(0.8, 0.7, 1.5), m=m, jitter=0.25, sub=0, rot=(0, -28, 0))
    rock(0.4, loc=(0.5, -0.05, -0.25), scl=(0.9, 0.7, 1.2), m=m, jitter=0.25, sub=0, rot=(0, 35, 0))


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


def _ore(nug_m, host=None, n=5, big=0.24):
    rock(1.0, scl=(1.25, 0.95, 0.75), m=host or stone("#7a736a", "#4f4a44"), jitter=0.15, sub=2)
    spots = [(-0.5, -0.62, 0.25), (0.3, -0.7, 0.1), (0.75, -0.4, 0.4), (-0.1, -0.45, 0.6), (0.55, -0.15, 0.7),
             (-0.75, -0.3, -0.1)]
    for i, p in enumerate(spots[:n]):
        rock(big * (1.0 - 0.12 * (i % 3)), loc=p, m=nug_m, jitter=0.3, sub=0)


def ore():
    _ore(metal("#c9a85a", 0.3))


def copper_ore():
    _ore(metal("#d07a3e", 0.3))
    for p in [(-0.2, -0.75, -0.2), (0.9, -0.1, 0.0)]:
        rock(0.16, loc=p, m=mat("#3fae8c", 0.5), jitter=0.3, sub=0)


def silver_ore():
    _ore(metal("#e4e8ee", 0.15), host=stone("#5c6068", "#3a3d44"), n=6)


def black_iron():
    m = mat("#33363d", 0.3, metal=1.0, color2="#4a3f5c", tex="noise", scale=5.0, bump=0.3)
    for p, r in (((0, 0, 0), 0.7), ((0.7, -0.2, -0.2), 0.45), ((-0.6, 0.1, -0.25), 0.5), ((0.1, -0.3, 0.6), 0.4)):
        rock(r, loc=p, m=m, jitter=0.28, sub=1)


def metal_shard():
    m = metal("#c8d0d8", 0.42)
    prism([(0, 1.4), (0.35, 0.6), (0.25, -0.2), (0.45, -0.9), (-0.1, -1.2), (-0.3, -0.3), (-0.2, 0.5)], 0.12, m=m,
          bev=0.02)
    prism([(0, 0.6), (0.2, 0.0), (0.05, -0.5), (-0.2, 0.0)], 0.1, loc=(0.7, 0.2, -0.4), rot=(0, 30, 0), m=m, bev=0.02)
    lean(-20)
    turn(20)


def _ingot(c, rough=0.28):
    box((1.2, 0.56, 0.34), m=metal(c, rough), bev=0.045, taper=(0.8, 0.72))
    turn(24)


def ingot():
    _ingot("#a9a49a", 0.45)


def copper_ingot():
    _ingot("#c8743c")


def bronze_ingot():
    _ingot("#c99a3e", 0.3)


def iron_ingot():
    _ingot("#4e5157", 0.55)


def steel_ingot():
    _ingot("#dce8f4", 0.12)


def charcoal():
    m = mat("#1e1e20", 0.55, color2="#3a3a3e", tex="voronoi", scale=5.0, bump=0.4, spec=0.6)
    for p, r, s in (((0, 0, 0), 0.6, (1.3, 0.9, 0.8)), ((0.85, -0.1, -0.15), 0.4, (1.2, 1.0, 0.8)),
                    ((-0.7, 0.1, -0.2), 0.42, (1.0, 1.0, 0.9))):
        rock(r, loc=p, scl=s, m=m, jitter=0.2, sub=1)
    ember = mat("#2a1e1a", 0.6, emit="#ff5a14", emit_strength=6.0, emit_mask=4.0)
    rock(0.3, loc=(0.2, -0.45, 0.35), m=ember, jitter=0.2, sub=1)


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
    m = mat("#cdbb92", 0.6, color2="#8f7a55", tex="voronoi", scale=3.0, bump=0.4)
    _bone(1.5, 0.27, 0.36, m)
    lean(-35)


def raptor_talon():
    pts = arc((-0.6, 0, -0.3), 1.0, -15, 80, 16)
    tube(pts, 0.28, mat("#3a3128", 0.3, color2="#d8c39a", tex="noise", scale=1.5, coat=0.6), segs=14, taper=(1.0, 0.04))
    blob(0.33, loc=pts[0], scl=(1.1, 0.9, 0.8), m=mat("#8a5a3c", 0.7), amp=0.08)
    lean(-10)


def armor_scute():
    m = mat("#8f9a7a", 0.55, color2="#5f6a4c", tex="voronoi", scale=4.0, bump=0.5)
    lathe([(0, 0.35), (0.3, 0.33), (0.6, 0.24), (0.85, 0.1), (0.95, 0.0), (0, 0.0)], m=m, segs=6, smooth=False,
          scl=(1.0, 0.8, 1.0))
    cyl(0.2, 0.5, loc=(0, 0, 0.5), m=mat("#d8cfb0", 0.5), segs=6, r2=0.0, smooth=False)
    turn(15)
    turn(35, "X")


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
    top = group(loc=(0, 0.75, 0.25), rot=(-70, 0, 0))
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


def sulphur():
    m = mat("#ecd43a", 0.3, color2="#c8a81a", tex="noise", scale=4.0, coat=0.4)
    rock(0.6, loc=(0, 0, -0.4), scl=(1.6, 1.2, 0.6), m=stone("#9a8f6a", "#6a6046"), jitter=0.2)
    for (x, y, h, tx, ty) in ((0, 0, 1.4, 0, 0), (0.35, -0.1, 1.0, 0, 28), (-0.4, 0.05, 1.1, 0, -25),
                              (0.1, -0.35, 0.8, -25, 10), (-0.1, 0.35, 0.9, 25, -8)):
        cyl(0.16, h, loc=(x + math.sin(math.radians(ty)) * h / 2, y, -0.2 + h / 2), rot=(tx, ty, 0), m=m, segs=6,
            r2=0.05, smooth=False)


def clay():
    m = mat("#b4643c", 0.75, color2="#8e4a2a", tex="noise", scale=3.0, bump=0.3)
    blob(1.0, scl=(1.2, 1.0, 0.75), m=m, amp=0.18, freq=1.3)
    blob(0.4, loc=(1.05, -0.3, -0.35), m=m, amp=0.15)


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
    _pelt(hidem("#b07a4e", "#8a5530"))


def raptor_hide():
    _pelt(mat("#6f7a3a", 0.75, color2="#3a3a1c", tex="wave", scale=4.0, bump=0.2, ramp=(0.45, 0.6)))


def dried_hide():
    m = hidem("#cfae80", "#a8875a")
    cyl(0.42, 1.8, rot=(0, 90, 0), m=m, segs=24)
    end = mat("#a8875a", 0.8, color2="#7a5a36", tex="rings", scale=6.0)
    for s in (-1, 1):
        cyl(0.38, 0.03, loc=(s * 0.905, 0, 0), rot=(0, 90, 0), m=end, segs=24)
    strap = hidem("#4a2e1b", "#2f1d10")
    for x in (-0.5, 0.5):
        tube(arc((0, 0, 0), 0.45, 0, 360, 24, plane="xz", y=0)[:-1], 0.04, strap, segs=6, closed=True,
             parent=group(loc=(x, 0, 0), rot=(0, 0, 90)))
    turn(25)


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
    cols = (("#d8cfb5", "#b9ad8e"), ("#c06a4a", "#9a4a32"), ("#7a8fa8", "#5a6f88"))
    for i, (c, c2) in enumerate(cols):
        box((1.6, 1.1, 0.22), loc=(0.05 * i, -0.04 * i, 0.24 * i), rot=(0, 0, 4 * i - 4), m=cloth(c, c2), bev=0.09)
    turn(25)


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
}
