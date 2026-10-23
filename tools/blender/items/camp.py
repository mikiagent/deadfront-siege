"""Building kits (shown as a small model of what they place), medicine, snares and the fallback silhouette."""
from kit import *  # noqa: F401,F403


def _post(x, y, h, m, r=0.09, point=True):
    cyl(r, h, loc=(x, y, h / 2), m=m, segs=8, smooth=False)
    if point:
        cyl(r, 0.22, loc=(x, y, h + 0.11), r2=0.0, m=m, segs=8, smooth=False)


def _lash(x, y, z, m, r=0.11):
    tube(arc((x, y, 0), r, 0, 360, 12, plane="xy", y=z)[:-1], 0.025, m, segs=5, closed=True)


def straw_roll_kit():
    straw = mat("#e4c66c", 0.7, color2="#b8923a", tex="wave", scale=28.0, bump=0.3)
    cyl(0.55, 1.9, rot=(0, 90, 0), m=straw, segs=28)
    end = mat("#d8b45a", 0.75, color2="#9a7428", tex="rings", scale=7.0, bump=0.3)
    for s in (-1, 1):
        cyl(0.5, 0.04, loc=(s * 0.96, 0, 0), rot=(0, 90, 0), m=end, segs=28)
        for k in range(7):
            a = k * 0.9
            tube([(s * 0.95, 0.42 * math.cos(a), 0.42 * math.sin(a)),
                  (s * (1.12 + 0.05 * (k % 3)), 0.5 * math.cos(a + 0.2), 0.5 * math.sin(a + 0.2))], 0.022, straw, segs=4)
    tw = rope_m("#8a6a3a")
    for x in (-0.5, 0.5):
        tube(arc((0, 0, 0), 0.575, 0, 360, 28, plane="xz", y=0)[:-1], 0.04, tw, segs=6, closed=True,
             parent=group(loc=(x, 0, 0), rot=(0, 0, 90)))
    turn(-30)
    turn(12, "X")


def campfire_kit():
    st = stone("#8d8f8f", "#5f6262")
    for i in range(8):
        a = i * math.pi / 4
        rock(0.26, loc=(0.85 * math.cos(a), 0.85 * math.sin(a), 0.0), scl=(1.2, 1.0, 0.8),
             m=stone("#7a7c7a", "#525452"), jitter=0.12, sub=2, smooth=True)
    b = bark("#6b4a2c", "#4a3019")
    for i in range(5):
        a = i * 2 * math.pi / 5 + 0.3
        tube([(0.6 * math.cos(a), 0.6 * math.sin(a), -0.1), (0.05 * math.cos(a), 0.05 * math.sin(a), 1.25)], 0.08, b, segs=8)
    tube([(-0.3, -0.2, 0.05), (0.35, 0.1, 0.1)], 0.06, b, segs=8)
    turn(25, "X")


def bonfire_kit():
    b = bark("#5b3d24", "#3a2614")
    end = mat("#d4a066", 0.7, color2="#7a5530", tex="rings", scale=3.5)
    for layer in range(4):
        for s in (-1, 1):
            g = group(loc=(0, 0, layer * 0.3), rot=(0, 90, 90 * (layer % 2)))
            cyl(0.15, 1.7, loc=(0, s * 0.55, 0), m=b, segs=12, parent=g)
            for e in (-1, 1):
                cyl(0.13, 0.02, loc=(0, s * 0.55, e * 0.86), m=end, segs=12, parent=g)
    for i in range(6):
        a = i * 1.05
        tube([(0.25 * math.cos(a), 0.25 * math.sin(a), 0.1), (0.05 * math.cos(a), 0.05 * math.sin(a), 1.35)], 0.04, b, segs=6)
    turn(30)
    turn(35, "X")


def workbench_kit():
    w = wood("#b07a46", "#7a4a24")
    box((2.2, 1.0, 0.2), loc=(0, 0, 0.9), m=w, bev=0.03)
    for x in (-0.95, 0.95):
        for y in (-0.38, 0.38):
            box((0.16, 0.16, 0.9), loc=(x, y, 0.4), rot=(0, x * 4, 0), m=wood("#8a5a33", "#5e3a1e"), bev=0.02)
    box((1.9, 0.12, 0.12), loc=(0, 0.38, 0.25), m=w, bev=0.02)
    # tools on top: stone hammer and a knife
    tube([(-0.7, -0.15, 1.05), (0.1, -0.2, 1.05)], 0.04, wood("#6e4626", "#4a2d16"), segs=8)
    box((0.22, 0.3, 0.18), loc=(0.15, -0.2, 1.08), m=stone(), bev=0.04)
    prism([(0.0, 0.0), (0.55, 0.05), (0.62, 0.12), (0.0, 0.12)], 0.03, loc=(0.35, 0.15, 1.01), rot=(90, 0, 25),
          m=mat("#4d5260", 0.3), bev=0.005)
    turn(-25)
    turn(12, "X")


def tent_kit():
    canvas = mat("#d8c8a0", 0.85, color2="#b8a47a", tex="wave", scale=30.0, bump=0.1)
    prism([(-1.0, 0.0), (1.0, 0.0), (0.0, 1.35)], 2.0, loc=(0, 0, 0), m=canvas, bev=0.03)
    prism([(-0.4, 0.0), (0.4, 0.0), (0.0, 0.62)], 0.04, loc=(0, -1.01, 0), m=mat("#3a2a1e", 0.8), bev=0.0)
    p = wood("#8a5a33", "#5e3a1e")
    for y in (-1.05, 1.05):
        cyl(0.05, 1.6, loc=(0, y, 0.8), m=p, segs=8)
    cyl(0.04, 2.3, loc=(0, 0, 1.38), rot=(90, 0, 0), m=p, segs=8)
    r = rope_m()
    for s in (-1, 1):
        tube([(0, s * 1.05, 1.5), (0.0, s * 1.6, 0.0)], 0.02, r, segs=4)
        cyl(0.05, 0.35, loc=(0.0, s * 1.62, 0.05), rot=(s * 15, 0, 0), m=p, segs=6)
    turn(-55)
    turn(8, "X")
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def fence_kit():
    w = wood("#9a6a3a", "#6a4220")
    for x in (-0.95, 0.95):
        _post(x, 0, 1.7, w, r=0.12)
    for z in (0.5, 1.2):
        box((2.3, 0.1, 0.22), loc=(0, -0.13, z), m=w, bev=0.02)
    rp = rope_m()
    for x in (-0.95, 0.95):
        for z in (0.5, 1.2):
            _lash(x, 0, z, rp, r=0.14)
    turn(-25)


def gate_kit():
    w = wood("#9a6a3a", "#6a4220")
    for x in (-1.0, 1.0):
        _post(x, 0, 1.8, w, r=0.13)
    for z in (0.35, 1.3):
        box((1.7, 0.12, 0.22), loc=(0, -0.12, z), m=w, bev=0.02)
    for x in (-0.5, 0.0, 0.5):
        box((0.2, 0.1, 1.25), loc=(x, -0.2, 0.82), m=wood("#a87444", "#7a4a24"), bev=0.02)
    box((0.16, 0.1, 1.5), loc=(0, -0.28, 0.82), rot=(0, 36, 0), m=w, bev=0.02)
    iron = metal("#4a4d52", 0.45)
    for z in (0.35, 1.3):
        box((0.3, 0.14, 0.12), loc=(-0.8, -0.2, z), m=iron, bev=0.01)
    turn(-25)


def drying_rack_kit():
    w = wood("#8a5a33", "#5e3a1e")
    for x in (-1.0, 1.0):
        tube([(x, -0.5, 0), (x, 0, 1.5)], 0.06, w, segs=8)
        tube([(x, 0.5, 0), (x, 0, 1.5)], 0.06, w, segs=8)
    tube([(-1.15, 0, 1.42), (1.15, 0, 1.42)], 0.06, w, segs=8)
    meat = mat("#a8302a", 0.5, color2="#6a1a12", tex="noise", scale=4.0, coat=0.3)
    for i, x in enumerate((-0.6, -0.15, 0.3, 0.7)):
        h = 0.75 + 0.1 * (i % 2)
        prism([(-0.1, 0), (0.1, 0), (0.12, -h * 0.6), (0.06, -h), (-0.08, -h * 0.9), (-0.12, -h * 0.4)], 0.05,
              loc=(x, -0.07, 1.38), m=meat, bev=0.01, deform=lambda co, k=i: co.__setitem__(1, co.y + 0.05 * math.sin(co.z * 6 + k)))
    turn(-22)
    turn(10, "X")


def catapult_kit():
    w = wood("#8a5a33", "#5e3a1e")
    for y in (-0.45, 0.45):
        box((2.0, 0.16, 0.18), loc=(0, y, 0.2), m=w, bev=0.02)
        tube([(-0.3, y, 0.25), (0.15, y, 1.15), (0.55, y, 0.25)], 0.07, w, segs=8)
    for x in (-0.85, 0.85):
        box((0.16, 1.05, 0.16), loc=(x, 0, 0.2), m=w, bev=0.02)
    tube([(0.15, -0.45, 1.1), (0.15, 0.45, 1.1)], 0.07, w, segs=8)
    iron = metal("#4a4d52", 0.45)
    for x in (-0.7, 0.7):
        for y in (-0.55, 0.55):
            cyl(0.26, 0.1, loc=(x, y, 0.15), rot=(90, 0, 0), m=w, segs=16)
            cyl(0.08, 0.12, loc=(x, y, 0.15), rot=(90, 0, 0), m=iron, segs=8)
    tube([(0.6, 0, 0.45), (-0.2, 0, 1.0), (-0.85, 0, 1.55)], 0.07, wood("#a87444", "#7a4a24"), segs=8)
    lathe([(0, 0), (0.22, 0.0), (0.3, 0.18), (0.26, 0.2), (0.18, 0.06), (0, 0.06)], loc=(-0.95, 0, 1.6), rot=(0, -30, 0),
          m=w)
    tube(arc((0.15, 0, 0), 0.1, 0, 360, 10, plane="xy", y=1.1)[:-1], 0.04, rope_m(), segs=5, closed=True)
    turn(-30)
    turn(10, "X")


def well_kit():
    st = stone("#9a9a96", "#6a6a66")
    lathe([(0.0, 0.0), (0.9, 0.0), (0.9, 0.75), (0.7, 0.75), (0.7, 0.2), (0.0, 0.2)], m=st, segs=12, smooth=False)
    cyl(0.69, 0.02, loc=(0, 0, 0.3), m=mat("#2a5a8a", 0.05, coat=1.0), segs=24)
    w = wood("#8a5a33", "#5e3a1e")
    for x in (-0.8, 0.8):
        box((0.12, 0.12, 1.7), loc=(x, 0, 1.1), m=w, bev=0.02)
    cyl(0.07, 1.8, loc=(0, 0, 1.6), rot=(0, 90, 0), m=w, segs=10)
    prism([(-1.1, 1.8), (1.1, 1.8), (0.0, 2.45)], 1.3, m=mat("#8a4a2a", 0.8, color2="#5a2a14", tex="wave", scale=12.0),
          bev=0.03)
    tube([(0.0, 0, 1.6), (0.0, 0, 1.05)], 0.02, rope_m(), segs=4)
    lathe([(0, 0), (0.15, 0.0), (0.2, 0.28), (0.17, 0.28), (0.13, 0.04), (0, 0.04)], loc=(0, 0, 0.78), m=w)
    turn(-25)
    turn(8, "X")


def basket_kit():
    # Lower weave contrast: the original (#8a6a32, bump 0.4) PNG went over 64 KB under Cycles noise.
    weave = mat("#c8a05a", 0.75, color2="#a07c40", tex="wave", scale=6.0, bump=0.15, ramp=(0.2, 0.8))
    lathe([(0, 0), (0.6, 0.0), (0.75, 0.1), (0.95, 0.9), (1.0, 1.0), (0.93, 1.0), (0.88, 0.9), (0.7, 0.14), (0, 0.14)],
          m=weave, segs=32)
    _lash(0, 0, 1.0, rope_m("#9a7a42"), r=0.98)
    tube(arc((0, 0, 1.0), 0.95, 0, 180, 20), 0.06, rope_m("#9a7a42"), segs=8)
    turn(20, "X")


def crock_pot_kit():
    st = stone("#8d8f8f", "#5f6262")
    for i in range(3):
        a = i * 2.1 + 0.4
        rock(0.32, loc=(0.75 * math.cos(a), 0.75 * math.sin(a), -0.15), m=st, jitter=0.2)
    pot = mat("#a85a34", 0.7, color2="#7a3a1e", tex="noise", scale=4.0, bump=0.2)
    lathe([(0, 0.0), (0.55, 0.05), (0.9, 0.4), (0.95, 0.75), (0.75, 1.05), (0.7, 1.15), (0, 1.15)], m=pot, segs=32)
    lathe([(0, 1.35), (0.15, 1.33), (0.18, 1.25), (0.72, 1.2), (0.76, 1.13), (0, 1.13)], m=mat("#8a4a2a", 0.7), segs=32)
    ball(0.12, loc=(0, 0, 1.4), m=mat("#8a4a2a", 0.7), sub=2)
    tube(arc((-0.95, 0, 0.75), 0.15, 90, 270, 10), 0.04, pot, segs=6)
    tube(arc((0.95, 0, 0.75), 0.15, -90, 90, 10), 0.04, pot, segs=6)
    turn(20, "X")


def stone_grill_kit():
    st = stone("#8d8f8f", "#5f6262")
    for i in range(5):
        a = i * 2 * math.pi / 5
        rock(0.3, loc=(0.8 * math.cos(a), 0.6 * math.sin(a), 0.0), m=st, jitter=0.2)
    box((2.0, 1.5, 0.16), loc=(0, 0, 0.35), rot=(0, 3, 2), m=stone("#6a6a68", "#4a4a48"), bev=0.06)
    meat = mat("#8e4a22", 0.45, coat=0.4)
    box((0.5, 0.35, 0.1), loc=(-0.3, -0.1, 0.48), rot=(0, 0, 20), m=meat, bev=0.05)
    box((0.45, 0.3, 0.1), loc=(0.4, 0.2, 0.48), rot=(0, 0, -15), m=meat, bev=0.05)
    turn(30, "X")


def mortar_kit():
    st = stone("#a8a49a", "#7a766c")
    lathe([(0, 0), (0.6, 0.0), (0.85, 0.35), (0.9, 0.75), (0.8, 0.8), (0.6, 0.5), (0, 0.38)], m=st, segs=28)
    tube([(0.1, 0, 0.45), (0.6, -0.1, 1.2), (0.85, -0.15, 1.55)], 0.12, st, segs=12, taper=(1.3, 0.9))
    turn(25, "X")


def claim_stake():
    w = wood("#9a6a3a", "#6a4220")
    box((0.22, 0.22, 2.2), loc=(0, 0, 0.3), m=w, bev=0.02)
    cyl(0.155, 0.45, loc=(0, 0, -1.02), rot=(180, 0, 45), r2=0.0, m=w, segs=4, smooth=False)
    flag = mat("#d8342a", 0.6, color2="#a8201a", tex="wave", scale=8.0)

    def ripple(co):
        co.y += 0.09 * math.sin(co.x * 5.0)
    prism([(0.1, 1.35), (1.1, 1.25), (0.95, 0.95), (1.15, 0.65), (0.1, 0.75)], 0.04, m=flag, bev=0.01, deform=ripple)
    for z in (0.8, 1.3):
        _lash(0, 0, z, rope_m(), r=0.17)
    turn(-20)
    lean(-8)


def sign_kit():
    w = wood("#9a6a3a", "#6a4220")
    box((0.18, 0.18, 2.0), loc=(0, 0, 0), m=w, bev=0.02)
    prism([(-0.9, 0.35), (0.7, 0.35), (1.05, 0.65), (0.7, 0.95), (-0.9, 0.95)], 0.12, loc=(0, -0.15, 0.2), m=wood("#b88452", "#8a5a30"),
          bev=0.02)
    _lash(0, 0, 0.75, rope_m(), r=0.15)
    turn(-20)


def bandage():
    """Upright linen roll, its tail unrolled across the ground, two healing herbs tucked in."""
    c = mat("#ece2c8", 0.85, color2="#cfc2a0", tex="wave", scale=30.0, bump=0.15)
    cyl(0.62, 0.62, loc=(-0.35, 0.2, 0.31), m=c, segs=32)
    cyl(0.58, 0.02, loc=(-0.35, 0.2, 0.63), m=mat("#ddd0b0", 0.8, color2="#bfb08a", tex="rings", scale=14.0), segs=32)
    cyl(0.12, 0.03, loc=(-0.35, 0.2, 0.64), m=mat("#8a7a5a", 0.8), segs=16)
    pts = [(0.2, 0.32), (0.75, 0.55), (1.15, 0.95), (1.25, 1.35)]  # +z here lands toward the camera
    path = []
    for i in range(len(pts) - 1):
        for t in range(6):
            u = t / 6
            path.append((pts[i][0] + (pts[i + 1][0] - pts[i][0]) * u, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * u))
    path.append(pts[-1])
    left, right = [], []
    for i, (x, y) in enumerate(path):
        nx, ny = path[min(i + 1, len(path) - 1)]
        px, py = path[max(i - 1, 0)]
        dx, dy = nx - px, ny - py
        n = math.hypot(dx, dy) or 1.0
        left.append((x - dy / n * 0.27, y + dx / n * 0.27))
        right.append((x + dy / n * 0.27, y - dx / n * 0.27))
    prism(left + right[::-1], 0.03, loc=(-0.35, 0.2, 0.02), rot=(90, 0, 0), m=c, bev=0.005)
    g_m = mat("#4f9a3a", 0.5, color2="#3a7a2a", tex="wave", scale=8.0)
    leaf(0.6, 0.2, loc=(-0.45, 0.2, 0.6), rot=(0, -35, 0), m=g_m, curl=0.1)
    leaf(0.5, 0.17, loc=(-0.25, 0.2, 0.6), rot=(0, 30, 0), m=g_m, curl=0.1)
    turn(10)
    turn(18, "X")


def splint():
    w = wood("#c9965a", "#9a6a35")
    for x in (-0.13, 0.13):
        box((0.2, 0.08, 2.4), loc=(x, 0, 0), m=w, bev=0.02)
    c = mat("#ece2c8", 0.85, color2="#cfc2a0", tex="wave", scale=30.0)
    for z0 in (-0.85, 0.35):
        pts = [(0.27 * math.cos(t * 0.5), 0.12 * math.sin(t * 0.5), z0 + 0.5 * t / (6 * math.pi)) for t in
               [i * 0.4 for i in range(48)]]
        tube(pts, 0.045, c, segs=6)
    lean(-38)
    turn(15)


def toxin_pot():
    pot = mat("#7a6a4a", 0.7, color2="#4a3e2a", tex="noise", scale=4.0)
    lathe([(0, 0), (0.5, 0.02), (0.85, 0.4), (0.85, 0.75), (0.5, 1.0), (0.42, 1.12), (0.5, 1.2), (0.38, 1.2), (0, 1.2)],
          m=pot, segs=28)
    blob(0.5, loc=(0, 0, 1.25), scl=(1.0, 1.0, 0.45), m=cloth("#8a7a5a", "#6a5a3a"), amp=0.1)
    _lash(0, 0, 1.12, rope_m(), r=0.46)
    goo = mat("#7dff3a", 0.1, coat=1.0, emit="#5aff1a", emit_strength=2.5)
    tube([(0.45, -0.1, 1.1), (0.75, -0.3, 0.8), (0.82, -0.4, 0.35)], 0.07, goo, segs=8, taper=(1.0, 0.7))
    ball(0.1, loc=(0.82, -0.4, 0.25), scl=(1, 1, 1.3), m=goo, sub=2)
    ball(0.07, loc=(0.8, -0.4, -0.05), scl=(1, 1, 1.3), m=goo, sub=2)
    turn(20)
    turn(12, "X")


def toxin_coating():
    glass = mat("#9adf6a", 0.05, coat=1.0, emit="#5ad81a", emit_strength=1.2)
    lathe([(0, 0), (0.45, 0.0), (0.5, 0.15), (0.5, 0.8), (0.25, 1.05), (0.18, 1.25), (0.2, 1.3), (0, 1.3)], m=glass, segs=28)
    cyl(0.17, 0.3, loc=(0, 0, 1.4), m=mat("#b88452", 0.8), segs=16)
    _lash(0, 0, 1.15, rope_m(), r=0.21)
    lean(-12)


def _snare(m, heavy=False):
    loop = arc((0, 0, 0.1), 0.85, 0, 360, 30, plane="xy", y=0.0)[:-1]
    tube(loop, 0.06 if heavy else 0.045, m, segs=8, closed=True)
    tube([(0.85, 0, 0.0), (1.1, 0, 0.3), (1.0, 0, 1.0), (0.6, 0, 1.6)], 0.06 if heavy else 0.045, m, segs=8)
    w = wood("#8a5a33", "#5e3a1e")
    cyl(0.1, 1.4, loc=(0.55, 0.1, 1.2), rot=(0, -15, 0), m=w, segs=8)
    if heavy:
        iron = metal("#4a4d52", 0.45)
        box((0.3, 0.2, 0.2), loc=(0.85, 0, 0.0), m=iron, bev=0.03)
        for a in (0, 120, 240):
            r = math.radians(a + 60)
            ball(0.12, loc=(0.85 * math.cos(r), 0.85 * math.sin(r), 0.0), m=iron, sub=2)
    turn(30, "X")


def rope_snare():
    _snare(rope_m())


def heavy_snare():
    _snare(metal("#7c8188", 0.35), heavy=True)


def _unknown():
    blob(0.9, loc=(0, 0, -0.2), scl=(1.0, 0.9, 1.0), m=flat("#ffffff"), amp=0.08)
    cyl(0.2, 0.25, loc=(0, 0, 0.75), m=flat("#ffffff"), segs=12)
    lathe([(0.0, 0.85), (0.25, 0.88), (0.45, 1.15), (0.35, 1.2), (0.0, 1.05)], m=flat("#ffffff"))


ITEMS = {
    "straw_roll_kit": straw_roll_kit, "campfire_kit": campfire_kit, "bonfire_kit": bonfire_kit,
    "workbench_kit": workbench_kit, "tent_kit": tent_kit, "fence_kit": fence_kit, "gate_kit": gate_kit,
    "drying_rack_kit": drying_rack_kit, "catapult_kit": catapult_kit, "well_kit": well_kit, "basket_kit": basket_kit,
    "crock_pot_kit": crock_pot_kit, "stone_grill_kit": stone_grill_kit, "mortar_kit": mortar_kit,
    "claim_stake": claim_stake, "sign_kit": sign_kit, "bandage": bandage, "splint": splint, "toxin_pot": toxin_pot,
    "toxin_coating": toxin_coating, "rope_snare": rope_snare, "heavy_snare": heavy_snare, "_unknown": _unknown,
}
