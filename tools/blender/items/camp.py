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
    """Tent kit: the canvas rolled round its assembly of poles, slung diagonally, so both pole ends
    stick out at the corners; two rope bands, a mallet and pegs at the foot."""
    canvas = mat("#d8c8a0", 0.9, color2="#ad9d72", tex="wave", scale=40.0, bump=0.2)
    c2 = mat("#c8b88e", 0.9, color2="#a0906a", tex="wave", scale=36.0, bump=0.2)
    p = mat("#c9965a", 0.75, color2="#9a6a35", tex="wave", scale=6.0, bump=0.2)
    g = group(rot=(0, 0, 0))
    # The poles: a bundle inside the canvas, their ends out at both ends of the roll.
    for (dy, dz) in ((-0.12, 0.05), (0.1, -0.05), (0.0, 0.12)):
        cyl(0.045, 3.0, loc=(0, dy, dz), rot=(0, 90, 0), m=p, segs=8, parent=g)
    # The roll: canvas wound round the middle of the poles.
    cyl(0.46, 1.9, rot=(0, 90, 0), m=canvas, segs=28, parent=g)
    for s in (-1, 1):
        lathe([(0, 0.0), (0.42, 0.0), (0.46, 0.02), (0.4, 0.03), (0.33, 0.02), (0.25, 0.03), (0.16, 0.02),
               (0.07, 0.03), (0, 0.03)], loc=(s * 0.96, 0, 0), rot=(0, 90 * s, 0), m=c2, segs=28, parent=g)
    for x in (-0.5, 0.55):
        tube(arc((0, 0, 0), 0.49, 0, 360, 28, plane="xz", y=0)[:-1], 0.04, rope_m(), segs=5, closed=True,
             parent=group(loc=(x, 0, 0), rot=(0, 0, 90), parent=g))
    # The loose canvas flap hanging off one side.
    prism([(-0.6, 0.35), (0.6, 0.4), (0.55, -0.1), (0.2, -0.5), (-0.2, -0.45), (-0.55, -0.05)], 0.03,
          loc=(0.2, -0.42, -0.3), rot=(20, 0, 0), m=canvas, bev=0.008, parent=g,
          deform=lambda co: co.__setitem__(1, co.y + 0.1 * math.sin(co.x * 3.0)))
    # Mallet and pegs at the foot.
    cyl(0.06, 0.45, loc=(-1.15, -0.45, -0.55), rot=(20, 60, 0), m=p, segs=8, parent=g)
    box((0.18, 0.32, 0.18), loc=(-1.35, -0.5, -0.4), rot=(10, 30, 0), m=wood("#8a5a33", "#5e3a1e"), bev=0.04,
        parent=g)
    for k in range(3):
        cyl(0.032, 0.34, loc=(-0.9 + 0.14 * k, -0.6, -0.75), rot=(70, 0, 20 * k), m=p, segs=6, r2=0.01, parent=g)
    turn(-38)
    turn(12, "X")
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
    """Sign: a painted plank board on a squared post, two iron nails, the board's corner carved with a
    cut arrows marking for a settlement, and a rope loop to hang it."""
    w = mat("#9a6a3a", 0.8, color2="#6a4220", tex="wave", scale=5.0, bump=0.3)
    board = mat("#b88452", 0.75, color2="#8a5a30", tex="wave", scale=7.0, bump=0.25)
    box((0.2, 0.2, 2.0), loc=(0, 0, -0.3), m=w, bev=0.02)
    # The board: two planks with a gap, fastened to the post.
    prism([(-0.95, 0.2), (0.75, 0.2), (1.1, 0.5), (0.75, 0.8), (-0.95, 0.8)], 0.12, loc=(0, -0.2, 0.05),
          m=board, bev=0.015)
    tube([(-0.9, -0.27, 0.5), (0.75, -0.27, 0.5)], 0.018, mat("#6a4a28", 0.9), segs=4)  # plank seam
    nail = mat("#8a8e94", 0.35, metal=0.9)
    for x in (-0.12, 0.12):
        cyl(0.05, 0.03, loc=(x, -0.28, 0.55), rot=(90, 0, 0), m=nail, segs=8)
    # Arrows carved (and painted) on the board: a clue this is a sign, not a plank.
    paint = mat("#d8c48a", 0.7)
    tube([(-0.75, -0.29, 0.55), (0.25, -0.29, 0.55)], 0.03, paint, segs=4)
    tube([(0.05, -0.29, 0.66), (0.28, -0.29, 0.55), (0.05, -0.29, 0.44)], 0.03, paint, segs=4)
    # Rope and a couple of lashes on the post.
    _lash(0, 0, 0.05, rope_m(), r=0.16)
    tube(arc((0, 0, 1.0), 0.14, 0, 180, 12, plane="xz"), 0.035, rope_m(), segs=5)
    turn(-20)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


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
    """Heavy cable snare: a coiled steel cable with a swaged eye, a heavy iron lock and three cast
    weights: built to hold something big (the rope snare is the flexible cord one)."""
    cable = mat("#9aa0a8", 0.3, metal=0.9, color2="#6a7078", tex="wave", scale=30.0, bump=0.15)
    pts = []
    for i in range(80):
        a = i * 0.19
        r = 0.9 - 0.004 * i
        pts.append((r * math.cos(a), 0.06 * math.sin(a * 1.5), r * math.sin(a) * 0.7))
    tube(pts, 0.06, cable, segs=6)
    pts2 = [(p[0] * 0.82 + 0.12, p[1] + 0.12, p[2] * 0.82 + 0.05) for p in pts]
    tube(pts2, 0.05, cable, segs=6)
    end = pts[-1]
    tube([end, (end[0] + 0.2, end[1], end[2] + 0.25), (end[0] + 0.05, end[1], end[2] + 0.45)], 0.05, cable, segs=5)
    loop = [(0.15 * math.cos(math.radians(a)) + end[0] + 0.02, end[1], 0.15 * math.sin(math.radians(a)) + end[2] + 0.5)
            for a in range(0, 360, 30)]
    tube(loop, 0.045, mat("#b0b6be", 0.25, metal=0.9), segs=6, closed=True)
    iron = mat("#4a4e56", 0.4, metal=0.85)
    box((0.3, 0.18, 0.16), loc=(0.55, 0.0, 0.5), rot=(0, 0, 30), m=iron, bev=0.03)
    for a in (0, 120, 240):
        r = math.radians(a)
        cyl(0.12, 0.2, loc=(0.6 * math.cos(r), 0.1 * math.sin(r), -0.45), rot=(90, 0, a), m=iron, segs=6,
            r2=0.09, smooth=False)
    turn(32, "X")
    lean(-24)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def _pole(x, y, z0, z1, m, r=0.06, tilt=0.0, parent=None):
    cyl(r, z1 - z0, loc=(x, y, (z0 + z1) / 2), rot=(0, tilt, 0), m=m, segs=10, parent=parent)


def _tie(x, y, z, r, m=None, parent=None, axis="z"):
    """A rope loop around a bundle: a flat ellipse ring plus its knot."""
    m = m or rope_m()
    if axis == "z":
        tube(arc((x, y, z), r, 0, 360, 20, plane="xy")[:-1], 0.035, m, segs=5, closed=True, parent=parent)
        tube([(x + r, y, z), (x + r + 0.08, y - 0.05, z + 0.1), (x + r + 0.02, y - 0.08, z - 0.12)], 0.03, m, segs=5,
             parent=parent)
    else:  # around an X-aligned bundle
        tube([(x, p[1], p[2]) for p in arc((0, 0, 0), r, 0, 360, 20, plane="yz", y=0)[:-1]], 0.035, m, segs=5,
             closed=True, parent=parent)


def _plank_bundle(n, length, width, thick, m, z0=-0.8, dy=0.13, seed_rot=0.0):
    """A stack of planks, slightly askew, for a kit bundle."""
    for i in range(n):
        box((length - 0.04 * (i % 3), width, thick), loc=(0.02 * (i % 2), (i - (n - 1) / 2) * dy, z0 + i * (thick + 0.01)),
            rot=(0, 0, seed_rot + 2.0 * (i % 2) - 1.0), m=m, bev=0.012)


def cabin_bed_kit():
    """Bed kit: four frame planks stacked and lashed, a log leg bundle, and a folded straw mattress
    roll on top with a hide blanket strapped to it."""
    w = wood("#b07a46", "#7a4a24")
    w2 = wood("#9a6a3a", "#6a4220")
    g = group(rot=(0, 0, 0))
    for i in range(4):
        box((2.2, 0.22, 0.1), loc=(0, (i - 1.5) * 0.24, -0.75 + i * 0.11), rot=(0, 0, 1.5 * (i % 2)), m=w if i % 2 else w2,
            bev=0.012, parent=g)
    for (x, y) in ((-0.95, 0.42), (0.95, 0.42), (-0.95, -0.42), (0.95, -0.42)):
        cyl(0.08, 0.62, loc=(x, y, -0.22), rot=(0, 0, 0), m=w2, segs=8, parent=g)
    straw = mat("#e0c070", 0.85, color2="#b8923a", tex="wave", scale=26.0, bump=0.35)
    cyl(0.3, 1.9, rot=(0, 90, 0), loc=(0, 0, 0.22), m=straw, segs=20, parent=g)
    for s in (-1, 1):
        cyl(0.27, 0.03, loc=(s * 0.96, 0, 0.22), rot=(0, 90, 0), m=mat("#c8a050", 0.85, color2="#9a7428",
                                                                        tex="rings", scale=9.0), segs=20, parent=g)
    h = hidem("#9a5a34", "#6a3a1e")
    box((1.5, 0.9, 0.12), loc=(0.1, 0.05, 0.56), rot=(0, 4, -6), m=h, bev=0.05, parent=g)
    for y in (-0.32, 0.32):
        _lash(0, 0, 0, rope_m(), r=0.07)
        tube([(x, y, 0.5) for x in (-0.75, 0.75)], 0.04, rope_m(), segs=5, parent=g)
    for x in (-0.5, 0.5):
        tube(arc((x, 0, 0), 0.62, 0, 360, 18, plane="xz")[:-1], 0.035, rope_m(), segs=5, closed=True, parent=g)
    turn(-18)
    turn(12, "X")
    upright()


def canvas_tent_kit():
    """Canvas tent kit: a long canvas roll, two poles and a fistful of pegs under two rope ties,
    with a loose corner of canvas unrolled at one end."""
    canvas = mat("#d8c8a0", 0.9, color2="#b0a074", tex="wave", scale=34.0, bump=0.15)
    cyl(0.34, 2.0, rot=(0, 90, 0), loc=(0, -0.12, -0.05), m=canvas, segs=24)
    for s in (-1, 1):
        cyl(0.3, 0.03, loc=(s * 1.01, -0.12, -0.05), rot=(0, 90, 0), m=mat("#c4b48a", 0.9, color2="#a0906a",
                                                                          tex="rings", scale=11.0), segs=24)
    # The unrolled flap: a slack sheet spilling off the near end.
    prism([(0.9, 0.3), (1.55, 0.1), (1.75, -0.35), (1.5, -0.55), (1.0, -0.45), (0.85, -0.2)], 0.03,
          loc=(0, -0.34, 0.02), rot=(0, 0, 0), m=canvas, bev=0.006,
          deform=lambda co: co.__setitem__(1, co.y + 0.12 * math.sin(co.x * 3.0)))
    p = wood("#c9965a", "#9a6a35")
    for (y, z) in ((0.34, 0.12), (0.3, -0.3)):
        cyl(0.05, 2.3, rot=(0, 90, 0), loc=(0, y, z), m=p, segs=8)
    for i in range(5):  # pegs, fanned out at the far end
        a = -35 + 15 * i
        cyl(0.035, 0.4, loc=(-1.12, 0.1 + 0.05 * (i % 2), -0.05 + 0.16 * (i - 2)), rot=(0, 0, a), m=p, segs=6,
            r2=0.012)
    for x in (-0.55, 0.55):
        tube(arc((x, 0, 0), 0.47, 270, 450, 16, plane="xz", y=-0.05)[:-1], 0.035, rope_m(), segs=5, closed=True,
             parent=group(loc=(0, 0, -0.05), rot=(0, 0, 90)))
    turn(-20)
    upright()


def _field_kit(scale, n_planks, n_stakes, pouches):
    """Furrow stakes and frame planks in a bundle, seed pouches tied on and a hoe blade strapped to
    the side. The large kit is longer, with more planks, twice the stakes and two pouches (the two
    looked alike at slot size)."""
    w = wood("#a87444", "#7a4a24")
    w2 = wood("#c48d55", "#93602f")
    for i in range(n_planks):
        box((1.7 * scale, 0.16, 0.09), loc=(0, (i - (n_planks - 1) / 2) * 0.19, -0.55 + i * 0.1),
            rot=(0, 0, 1.2 * (i % 2)), m=w if i % 2 else w2, bev=0.012)
    for i in range(n_stakes):
        a = -18 + 9 * i
        cyl(0.05, 1.2 * scale, loc=(0.15 * (i - (n_stakes - 1) / 2), 0.32, 0.35), rot=(6 * (i % 2), a, 0),
            m=wood("#8a5a33", "#5e3a1e"), segs=6, r2=0.015)
    # Seed pouches, tied on and resting on the planks.
    pouch = hidem("#b08a52", "#8a6434")
    for x, y, z in pouches:
        blob(0.26 * scale, loc=(x, y, z), scl=(1.0, 0.9, 1.15), m=pouch, amp=0.12)
        _lash(x, y, z + 0.12, rope_m("#d7c08a"), r=0.13)
    # A hoe blade strapped against the planks.
    prism([(-0.05, 0.3), (0.12, 0.34), (0.62 * scale, 0.15), (0.68 * scale, -0.15), (0.4 * scale, -0.05), (0.05, 0.12)],
          0.08, loc=(0.35, -0.24, 0.1), rot=(0, 0, 10), m=stone("#9a9488", "#6a645a"), bev=0.02)
    for x in (-0.4, 0.35):
        tube(arc((x, 0, 0), 0.28, 0, 360, 18, plane="xz")[:-1], 0.035, rope_m(), segs=5, closed=True,
             parent=group(loc=(0, 0, 0.0), rot=(0, 0, 90)))
    turn(-18)
    turn(10, "X")
    upright()


def field_large_kit():
    """Large field kit: long frame planks, a bundle of stakes, a seed pouch and a heavy hoe blade,
    all lashed with rope."""
    _field_kit(1.15, 5, 7, [(-0.45, -0.2, -0.07), (-0.95, 0.05, 0.04)])
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def field_small_kit():
    """Small field kit: a short bundle of frame planks and three stakes, a small seed pouch tied on."""
    _field_kit(0.7, 3, 3, [(-0.45, -0.2, -0.3)])
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def log_shelter_kit():
    """Log shelter kit: notched logs stacked in a bundle (their ends show the notch cuts), roof planks
    on top and a rope sling around the whole load with a loop to carry it."""
    b = bark("#6b4a2c", "#4a3019")
    end = mat("#d4a066", 0.75, color2="#8a5a30", tex="rings", scale=4.0)
    for layer in range(3):
        for s in (-1, 1):
            g = group(loc=(0, 0, -0.62 + layer * 0.34), rot=(0, 90, 90 * (layer % 2)))
            cyl(0.15, 1.8, loc=(0, s * 0.36, 0), m=b, segs=14, parent=g)
            for e in (-1, 1):
                cyl(0.14, 0.03, loc=(0, s * 0.36, e * 0.9), m=end, segs=14, parent=g)
                # The notch cut where a crossing log sits.
                box((0.2, 0.3, 0.08), loc=(0, s * 0.36, e * 0.86), m=end, bev=0.01, parent=g)
    w = wood("#b88452", "#8a5a30")
    for i in range(3):
        box((1.9, 0.24, 0.07), loc=(0, (i - 1) * 0.26, 0.44), rot=(0, 0, 2 * (i % 2)), m=w, bev=0.01)
    for x in (-0.6, 0.6):
        tube([(x, p[1], p[2]) for p in arc((0, 0, 0), 0.62, 0, 360, 20, plane="yz", y=0)[:-1]], 0.04, rope_m(),
             segs=5, closed=True)
    tube(arc((0, 0, 0.5), 0.3, 0, 180, 14, plane="xz", y=0), 0.035, rope_m(), segs=5)  # carry loop
    turn(-24)
    turn(10, "X")
    upright()


def makeshift_taming_pen():
    """Makeshift taming pen: a bundle of sharpened stakes lashed to two rails, a coil of rope and a
    gate latch, the parts of a quick pen bundled together."""
    w = wood("#9a6a3a", "#6a4220")
    for i in range(7):
        _pole(-0.55 + 0.18 * i, 0.0, -0.9, 1.0, w, r=0.055, tilt=2.0 * (i % 3) - 2.0)
        cyl(0.055, 0.2, loc=(-0.55 + 0.18 * i, 0.0, 1.1), r2=0.0, m=wood("#b88452", "#8a5a30"), segs=6)
    for z in (-0.3, 0.35):
        box((1.6, 0.1, 0.14), loc=(0, -0.13, z), rot=(0, 0, 0), m=wood("#a87444", "#7a4a24"), bev=0.02)
    for x in (-0.62, 0.62):
        tube([(x, p[1] - 0.13, p[2]) for p in arc((0, 0, 0), 0.11, 0, 360, 14, plane="xz", y=0)[:-1]], 0.03, rope_m(),
             segs=5, closed=True)
    # A coil of rope hanging off the bundle and a latch of bone and wood.
    g = group(loc=(0.72, -0.28, 0.0), rot=(90, 0, 0))
    tube(helix(0.24, 0.06, 3.2, 16, -0.2), 0.04, rope_m("#c8a86a"), segs=5, parent=g)
    box((0.36, 0.08, 0.08), loc=(-0.15, -0.25, 0.62), rot=(0, 0, 20), m=bonem("#e2d2a8"), bev=0.02)
    box((0.1, 0.08, 0.3), loc=(0.05, -0.25, 0.7), rot=(0, 0, 20), m=w, bev=0.02)
    turn(-14)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def smoker_kit():
    """Smoker kit: a lashed A-frame of green poles with two cross rails, a bundle of hanging meat
    strips and a pouch of wood chips tied at its foot."""
    w = bark("#9a7650", "#6a4c30")  # lighter than the first try, which sank into the dark slot
    for s in (-1, 1):
        for y in (-0.35, 0.35):
            tube([(s * 0.95, y, -1.0), (0, y, 1.0)], 0.1, w, segs=8)
    for z in (0.1, 0.75):
        cyl(0.075, 0.95, loc=(0, 0, z), rot=(90, 0, 0), m=w, segs=8)
    for y in (-0.35, 0.35):
        _lash(0, y, 0.9, rope_m(), r=0.08)
    meat = mat("#b8482a", 0.55, color2="#8a3018", tex="noise", scale=5.0, bump=0.35, coat=0.3)
    for i, x in enumerate((-0.26, 0.0, 0.26)):
        h = 0.6 + 0.1 * (i % 2)
        tube([(x, -0.12, 0.14), (x, -0.12, 0.02)], 0.02, rope_m("#d7c08a"), segs=4)
        prism([(-0.11, 0), (0.11, 0), (0.13, -h * 0.5), (0.04, -h), (-0.11, -h * 0.8), (-0.14, -h * 0.3)], 0.05,
              loc=(x, -0.12, 0.06), rot=(15, 0, 0), m=meat, bev=0.01,
              deform=lambda co: co.__setitem__(1, co.y + 0.03 * math.sin(co.z * 9)))
    pouch = mat("#b89a6a", 0.9, color2="#8a7044", tex="wave", scale=16.0, bump=0.3)
    blob(0.3, loc=(0.75, -0.3, -0.85), scl=(1.0, 0.9, 0.9), m=pouch, amp=0.14)
    _tie(0.75, -0.3, -0.7, 0.12, rope_m("#d7c08a"))
    for k in range(5):
        chip = mat("#c8a878", 0.8, color2="#9a7a4a", tex="noise", scale=8.0)
        box((0.12, 0.08, 0.03), loc=(0.55 + 0.1 * k, -0.55, -1.05), rot=(0, 0, 20 * k), m=chip, bev=0.005)
    turn(28)  # face the A so the hanging meat shows between its legs
    turn(8, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def steamer_kit():
    """Steamer kit: a stack of bamboo steamer trays bound with twine, a lid askew on top, a bundle of
    green leaves and a pair of wooden tongs beside them."""
    bam = mat("#c9a35a", 0.72, color2="#a8844a", tex="noise", scale=6.0, bump=0.2)
    bam2 = mat("#d8b86e", 0.72, color2="#b08e50", tex="noise", scale=6.0, bump=0.2)
    for i in range(3):
        r = 0.8 - 0.02 * i
        lathe([(0, 0.0), (r, 0.0), (r, 0.26), (r - 0.08, 0.26), (r - 0.08, 0.06), (0, 0.06)],
              loc=(0, 0, -0.75 + i * 0.3), m=bam if i % 2 else bam2, segs=30, smooth=False)
        tube(arc((0, 0, 0), r + 0.01, 0, 360, 30, plane="xy", y=-0.6 + i * 0.3)[:-1], 0.03, mat("#8a6a34", 0.8),
             segs=4, closed=True)
    # Lid, tilted open on top.
    lid = group(loc=(0.06, 0, 0.25), rot=(-12, 8, 0))
    lathe([(0, 0.0), (0.78, 0.0), (0.78, 0.1), (0.6, 0.16), (0.2, 0.2), (0.06, 0.26), (0, 0.27)], m=bam2, segs=30,
          parent=lid)
    lathe([(0, 0.0), (0.26, 0.0), (0.26, 0.05), (0.16, 0.14), (0.16, 0.32), (0.26, 0.42), (0.26, 0.47), (0, 0.47)],
          loc=(0, 0, 0.22), m=wood("#b07a46", "#7a4a24"), segs=14, parent=lid)
    for a in (20, 140, 260):
        rad = math.radians(a)
        tube([(0.76 * math.cos(rad), 0.76 * math.sin(rad), -0.9), (0.86 * math.cos(rad), 0.86 * math.sin(rad), 0.35)],
             0.03, mat("#d7c08a", 0.9), segs=4)
    leaf(0.9, 0.3, loc=(-0.95, -0.1, -0.55), rot=(0, 60, 20), m=mat("#5aa04a", 0.5, color2="#3e7a32", tex="wave",
                                                                   scale=8.0), curl=0.15)
    leaf(0.8, 0.26, loc=(-0.9, 0.15, -0.5), rot=(0, 40, -30), m=mat("#4e8a46", 0.5, color2="#2e6234", tex="wave",
                                                                   scale=8.0), curl=0.1)
    for s in (-1, 1):  # tongs
        tube([(0.55 + s * 0.06, -0.72, -0.85), (0.75 + s * 0.02, -0.8, -0.4), (0.7 + s * 0.04, -0.76, -0.1)], 0.035,
             mat("#b88452", 0.75, color2="#8a5a30", tex="noise", scale=3.0, bump=0.1), segs=5)
    turn(18)
    turn(20, "X")
    upright()


def stone_fire_pit_kit():
    """Fire pit kit: a stack of fire-ring stones in a rope sling that hangs from a stick, with a
    bundle of split firewood tied beside it."""
    st = stone("#8a8c8a", "#5e605e")
    for i in range(7):
        a = i * 0.9
        rock(0.24, loc=(0.7 * math.cos(a), 0.7 * math.sin(a), -0.55 + 0.08 * (i % 2)), scl=(1.3, 1.0, 0.75),
             m=st if i % 2 else stone("#7a7c7a", "#525452"), jitter=0.14, sub=2, smooth=False)
    rock(0.26, loc=(0.1, 0.05, -0.2), scl=(1.2, 1.0, 0.8), m=st, jitter=0.12, sub=2)
    rock(0.2, loc=(-0.15, -0.1, 0.05), scl=(1.2, 1.0, 0.8), m=stone("#9a9c98", "#6a6c68"), jitter=0.12, sub=2)
    rp = rope_m()
    tube([(0.75, 0.4, -0.6), (0.35, 0.2, 0.35), (0.0, 0.0, 0.85), (-0.45, -0.2, 0.4), (-0.8, -0.35, -0.6)], 0.035, rp,
         segs=5)
    tube(arc((0, 0, 0.9), 0.18, 0, 180, 12, plane="xz", y=0), 0.035, rp, segs=5)
    # Split firewood, tied, leaning against the stones.
    inner = mat("#e0b07a", 0.75, color2="#a87440", tex="rings", scale=5.0)
    for i in range(4):
        g = group(loc=(-0.5, -0.55 + 0.12 * i, 0.1), rot=(-8, 0, 90))
        cyl(0.11, 1.1, m=inner, segs=8, parent=g)
        cyl(0.1, 0.03, loc=(0, 0, 0.56), m=bark("#5b3d24", "#3a2614"), segs=8, parent=g)
    for z in (-0.25, 0.25):
        tube([(x, -0.5, z) for x in (-0.75, -0.25)], 0.03, rp, segs=5)
    turn(-22)
    turn(10, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def carnivore_feed():
    """Carnivore feed: a pile of raw meat cuts on a scrap of hide, a bone through the middle and a
    strip draped over the edge."""
    meat = mat("#b83a3a", 0.35, color2="#f0b0a8", tex="noise", scale=4.0, bump=0.3, coat=0.4, ramp=(0.55, 0.75))
    hide = hidem("#8a5a34", "#5e3a1e")
    prism([(-0.9, 0.5), (-0.4, 0.85), (0.4, 0.9), (1.0, 0.55), (1.05, -0.3), (0.6, -0.75), (-0.2, -0.8),
           (-0.9, -0.5)], 0.05, rot=(80, 0, 0), loc=(0, 0.05, -0.55), m=hide, bev=0.02,
          deform=lambda co: co.__setitem__(1, co.y + 0.06 * math.sin(co.x * 4)))
    for (x, y, z, r, scl, rot_) in ((-0.3, -0.1, -0.2, 0.36, (1.2, 1.0, 0.8), (0, 20, 0)),
                                     (0.35, 0.05, -0.15, 0.33, (1.1, 1.0, 0.85), (0, -25, 0)),
                                     (0.0, -0.3, 0.1, 0.3, (1.2, 1.0, 0.9), (10, 0, 0)),
                                     (0.5, -0.25, -0.35, 0.24, (1.1, 1.0, 0.8), (0, 30, 0))):
        blob(r, loc=(x, y, z), scl=scl, rot=rot_, m=meat, amp=0.18)
    b = bonem()
    cyl(0.08, 1.5, loc=(0.05, 0.0, 0.15), rot=(12, 72, 0), m=b, segs=12)
    for s in (-1, 1):
        ball(0.13, loc=(0.05 + s * 0.72 * 0.95, 0.0, 0.15 + s * 0.72 * 0.3), m=b, sub=2)
    # A strip draped over the hide's edge.
    prism([(-0.15, 0.55), (0.15, 0.6), (0.2, 0.0), (0.1, -0.5), (0.0, -0.2), (-0.12, -0.55), (-0.2, 0.0)], 0.04,
          loc=(0.7, -0.35, -0.35), rot=(30, 0, -10), m=meat, bev=0.012)
    turn(15)
    upright()


def herbivore_feed():
    """Herbivore feed: a woven basket of greens, a corn cob, a bunch of stalks and a halved fruit."""
    weave = mat("#c8a05a", 0.8, color2="#a8844a", tex="noise", scale=4.0, bump=0.2)
    lathe([(0, 0), (0.6, 0.0), (0.78, 0.1), (0.98, 0.8), (1.04, 0.9), (0.96, 0.9), (0.9, 0.8), (0.7, 0.16), (0, 0.16)],
          m=weave, segs=32, loc=(0, 0, -0.6))
    tube(arc((0, 0, 0.3), 1.02, 0, 360, 26, plane="xy")[:-1], 0.05, rope_m("#9a7a42"), segs=6, closed=True)
    greens = mat("#5fb04a", 0.6, color2="#448a38", tex="noise", scale=4.0, bump=0.15)
    for i, (x, y, z, r) in enumerate(((-0.3, -0.15, 0.45, 0.32), (0.25, -0.2, 0.42, 0.3), (0.05, 0.25, 0.5, 0.34))):
        blob(r, loc=(x, y, z), scl=(1.2, 1.0, 0.8), m=greens, amp=0.2)
    for (x, ang) in ((-0.55, 40), (0.55, -45), (0.6, 30), (-0.6, -25)):  # leaves sticking out of the basket
        leaf(0.8, 0.26, loc=(x, -0.1, 0.55), rot=(15, ang, 0), m=greens, curl=0.15)
    corn = mat("#f2c23a", 0.4, color2="#d8961a", tex="voronoi", scale=13.0, bump=0.6)
    blob(0.2, loc=(0.0, -0.35, 0.7), scl=(1.0, 1.0, 1.9), rot=(0, 30, 0), m=corn, amp=0.05)
    leaf(0.55, 0.16, loc=(0.0, -0.4, 0.45), rot=(0, -30, 0), m=greens, curl=0.1)
    fruit = mat("#d86a3a", 0.4, coat=0.4, color2="#f0a070", tex="noise", scale=6.0)
    lathe([(0, 0), (0.02, 0.22), (0.24, 0.3), (0.36, 0.18), (0.38, 0.0), (0.36, -0.02), (0, -0.02)], m=fruit,
          segs=20, loc=(-0.65, 0.35, 0.3), rot=(20, 0, 0))
    turn(18)
    turn(14, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def fruit_fertilizer():
    """Fruit fertilizer: a gourd of mashed fruit with a broad leaf lid, a scoop stick in it and a
    couple of over-ripe fruits beside it."""
    pulp = mat("#8a4a2a", 0.2, color2="#c8783a", tex="noise", scale=5.0, bump=0.4, coat=0.7)
    gourd = mat("#c8a860", 0.7, color2="#9a7a3a", tex="noise", scale=6.0, bump=0.3)
    lathe([(0, 0), (0.5, 0.02), (0.8, 0.25), (0.92, 0.6), (0.8, 0.9), (0.6, 1.02), (0.62, 1.08), (0.5, 1.1), (0, 1.05)],
          m=gourd, segs=30)
    cyl(0.56, 0.03, loc=(0, 0, 1.02), m=pulp, segs=28)
    blob(0.5, loc=(0, 0, 1.02), scl=(1.0, 1.0, 0.25), m=pulp, amp=0.2, sub=2)
    lid = mat("#4f9a3a", 0.5, color2="#3a7a2a", tex="wave", scale=6.0)
    leaf(0.9, 0.45, loc=(-0.45, 0.0, 1.12), rot=(20, 70, 0), m=lid, curl=0.12)
    tube([(0.15, -0.1, 1.05), (0.35, -0.2, 1.45), (0.3, -0.25, 1.7)], 0.04, wood("#c9965a", "#9a6a35"), segs=6)
    fruit = mat("#b85a2a", 0.35, color2="#e09a5a", tex="noise", scale=5.0, coat=0.5)
    for (x, y, r) in ((0.95, -0.25, 0.22), (1.15, 0.15, 0.18)):
        blob(r, loc=(x, y, 0.15), scl=(1.0, 1.0, 0.9), m=fruit, amp=0.1)
    leaf(0.5, 0.2, loc=(1.0, -0.2, 0.42), rot=(0, 40, 0), m=lid, curl=0.08)
    turn(16)
    turn(16, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def pressure_dressing():
    """Pressure dressing: a thick folded linen pad (cream, three layers) with two hide straps crossed
    over the top face, a bone buckle and a knot, the loose end of one strap trailing off."""
    pad = mat("#e6dcc0", 0.92, color2="#c2b48e", tex="wave", scale=44.0, bump=0.18)
    strap = hidem("#6e3e1e", "#46240e")
    for i, (z, w, d) in enumerate(((-0.42, 1.45, 1.05), (-0.2, 1.38, 1.0), (0.02, 1.28, 0.92))):
        box((w, d, 0.22), loc=(0, 0, z), rot=(0, 2 * i - 2, 0), m=pad, bev=0.08)
    # Straps crossing over the top face of the pad, and down both sides.
    for ang in (28, -34):
        g = group(loc=(0, 0, 0.14), rot=(0, 0, ang))
        box((2.1, 0.22, 0.07), loc=(0, 0, 0.0), m=strap, bev=0.02, parent=g)
        for s in (-1, 1):
            box((0.07, 0.22, 0.75), loc=(s * 0.72, 0, -0.34), rot=(0, 0, 0), m=strap, bev=0.015, parent=g)
    buckle = bonem("#e2d2a8")
    box((0.3, 0.12, 0.1), loc=(0.05, -0.2, 0.24), rot=(0, 0, 28), m=buckle, bev=0.03)
    box((0.12, 0.22, 0.07), loc=(0.05, -0.2, 0.32), rot=(0, 0, 28), m=buckle, bev=0.015)
    tube(arc((0.55, 0.35, 0.16), 0.12, 0, 360, 14, plane="xz")[:-1], 0.035, rope_m(), segs=5, closed=True)
    prism([(0.2, 0.3), (0.8, 0.15), (0.9, -0.05), (0.25, -0.1)], 0.2, loc=(0.55, -0.45, -0.05), rot=(0, 0, 10),
          m=strap, bev=0.02, deform=lambda co: co.__setitem__(1, co.y + 0.18 * co.x * co.x))
    turn(12)
    turn(22, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


# ---------------------------------------------------------------- cages (owner rule)

def _cage(door_deg=0.0):
    """A lashed wooden cage: a slatted floor, four corner posts, vertical bars on every side and a
    lashed roof hatch. open_door swings the front panel out on its hinge."""
    # Flat fills where possible: the cage is many thin bars, and noisy materials push the PNG
    # over the 64 KB budget.
    w = mat("#9a6a3a", 0.75, color2="#7a4e26", tex="noise", scale=3.0, bump=0.1)
    w2 = mat("#bb8a56", 0.7, color2="#8a5a30", tex="noise", scale=3.0, bump=0.1)
    rp = rope_m()
    W, D, H = 0.9, 0.66, 0.92
    # Floor slats and a rim.
    for i in range(5):
        box((2 * W + 0.1, 0.26, 0.07), loc=(0, -D + 0.28 * i, -H + 0.06), m=w if i % 2 else w2, bev=0.012)
    for y in (-D - 0.04, D + 0.04):
        box((2 * W + 0.16, 0.09, 0.1), loc=(0, y, -H + 0.05), m=w, bev=0.015)
    for x in (-W - 0.04, W + 0.04):
        box((0.09, 2 * D + 0.16, 0.1), loc=(x, 0, -H + 0.05), m=w, bev=0.015)
    # Corner posts, lashed at top and bottom.
    for x in (-W, W):
        for y in (-D, D):
            cyl(0.075, 2 * H, loc=(x, y, 0), m=w2, segs=8)
            for z in (-H + 0.18, H - 0.1):
                tube([(x, p[1], p[2]) for p in arc((0, 0, 0), 0.11, 0, 360, 12, plane="xy", y=z)[:-1]], 0.03, rp,
                     segs=5, closed=True)
    # Bars: sides and back, tighter than the slats, so it reads as a cage and not a crate.
    def bars(fixed, axis, n, lo, hi):
        for i in range(n):
            t = lo + (hi - lo) * i / (n - 1)
            if axis == "x":
                cyl(0.032, 2 * H - 0.2, loc=(t, fixed, 0), m=w2, segs=6)
            else:
                cyl(0.032, 2 * H - 0.2, loc=(fixed, t, 0), m=w2, segs=6)
    # The near sides carry fewer bars than the far ones, so the animal inside stays readable at
    # slot size while the cage still reads as slatted on every side.
    bars(-D, "x", 2, -W + 0.36, W - 0.36)
    bars(D, "x", 9, -W + 0.1, W - 0.1)
    bars(-W, "y", 5, -D + 0.16, D - 0.16)
    bars(W, "y", 4, -D + 0.2, D - 0.2)
    # The front panel: a frame with bars, hanging from a hinge on the left post.
    door = group(loc=(-W, -D, 0), rot=(0, 0, -door_deg))
    box((2 * W, 0.07, 0.09), loc=(W, 0, H - 0.08), m=w, bev=0.012, parent=door)
    box((2 * W, 0.07, 0.09), loc=(W, 0, -H + 0.12), m=w, bev=0.012, parent=door)
    for i in range(5):
        x = 0.2 + (2 * W - 0.4) * i / 4
        cyl(0.03, 2 * H - 0.24, loc=(x, 0, 0), m=w2, segs=6, parent=door)
    if door_deg == 0.0:
        for z in (-H + 0.4, H - 0.3):
            box((0.3, 0.08, 0.06), loc=(W - 0.18, 0, z), m=rp, bev=0.01, parent=door)
    # Roof: open, so the animal inside shows through: only the frame beams and a hinged hatch at
    # the back, lashed on.
    for x in (-W, W):
        box((0.1, 2 * D + 0.16, 0.09), loc=(x, 0, H), m=w, bev=0.012)
    for y in (-D, D):
        box((2 * W + 0.16, 0.1, 0.09), loc=(0, y, H), m=w, bev=0.012)
    # A loose roof slat pushed back over the far beams (the cage is open from above, so the animal
    # inside shows).
    box((1.4, 0.4, 0.05), loc=(-0.75, D - 0.12, H + 0.1), rot=(-18, 0, 4), m=w2, bev=0.01)
    for x in (-0.45, 0.45):
        tube([(x, p[1], p[2]) for p in arc((0, 0, 0), 0.09, 0, 360, 12, plane="xy", y=H + 0.07)[:-1]], 0.03, rp,
             segs=5, closed=True)
    return door


def _small_dino(loc=(0, 0, 0), rot=(0, 0, 0), collar=None):
    """A small generic theropod standing in the cage, neck and head up: body, S-neck, head with a
    blunt snout, tail, two legs and little arms. Not a named species (the PRD's roster is not needed
    for a generic captured animal)."""
    g = group(loc=loc, rot=rot)
    # A cool green animal against the warm wood cage: it reads through the bars at slot size.
    skin = mat("#5e8a52", 0.7, color2="#3e6838", tex="noise", scale=2.5, bump=0.2)
    belly = mat("#cfd8a8", 0.75, color2="#a8b880", tex="noise", scale=3.0, bump=0.15)
    dark = mat("#2e4a28", 0.8)
    blob(0.3, loc=(0, 0, 0.0), scl=(1.3, 0.85, 0.85), m=skin, amp=0.07, parent=g)
    blob(0.2, loc=(0.08, -0.12, -0.04), scl=(1.3, 0.6, 0.65), m=belly, amp=0.05, parent=g)
    # S-neck rising from the shoulders to a head held level with the top of the cage.
    neck = [(0.24, 0, 0.12), (0.36, 0, 0.3), (0.36, 0, 0.5), (0.44, 0, 0.62), (0.55, 0, 0.66)]
    tube(neck, 0.1, skin, segs=10, taper=(1.0, 0.75), parent=g)
    blob(0.15, loc=(0.62, 0, 0.68), scl=(1.5, 0.85, 0.9), m=skin, amp=0.05, parent=g)
    tube([(0.72, 0, 0.66), (0.86, 0, 0.62)], 0.075, skin, segs=8, taper=(1.0, 0.7), parent=g)  # snout
    for y in (-0.08, 0.08):
        ball(0.038, loc=(0.66, y, 0.74), m=mat("#1a1a14", 0.2, coat=1.0), sub=2, parent=g)
    for k in range(3):  # dorsal stripes, so it is not a plain egg
        cyl(0.1, 0.03, loc=(-0.08 + 0.1 * k, 0, 0.22), m=dark, segs=10, parent=g)
    tube([(-0.3, 0, 0.04), (-0.6, 0.06, -0.16), (-0.92, 0.1, -0.34)], 0.1, skin, segs=8, taper=(1.0, 0.15),
         parent=g)
    for y in (-0.15, 0.15):  # legs
        tube([(0.05, y, -0.12), (-0.02, y, -0.38), (0.02, y, -0.62)], 0.065, skin, segs=8, taper=(1.0, 0.7),
             parent=g)
        tube([(0.02, y, -0.62), (0.17, y, -0.68)], 0.04, skin, segs=6, parent=g)
    for y in (-0.17, 0.17):  # little arms
        tube([(0.26, y * 0.7, 0.12), (0.34, y, 0.0)], 0.03, skin, segs=6, taper=(1.0, 0.5), parent=g)
    if collar:
        cyl(0.115, 0.06, loc=(0.36, 0, 0.45), rot=(0, 40, 0), m=collar, segs=12, parent=g)
    return g


def captured_animal():
    """A captured animal is shown in its cage: a lashed wooden cage shut, a small generic dinosaur
    standing inside it (owner rule)."""
    _cage()
    # Neck and head rise out of the open top: at 64 px the animal inside a closed cage would be
    # just bars.
    _small_dino(loc=(-0.12, 0.18, 0.12), rot=(0, 0, -32)).scale = (1.85, 1.85, 1.85)
    turn(-22)
    turn(30, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def tamed_animal():
    """The same cage with its door swung open, a hide collar round the animal's neck and a spare
    collar and lead hung on the door: an animal that has been tamed and walks with you (owner rule)."""
    door = _cage(door_deg=78.0)
    tame = hidem("#a85a2a", "#6a3010")
    _small_dino(loc=(-0.02, 0.26, 0.1), rot=(0, 0, 20), collar=tame).scale = (1.8, 1.8, 1.8)
    collar = hidem("#8a4a20", "#5a2c10")
    # A spare hide collar hung over the open door's top rail, with its lead and a bone ring.
    tube(arc((0, 0, 0), 0.26, 20, 340, 20, plane="xz", y=0), 0.06, collar, segs=6, parent=door)
    tube([(0.12, 0, -0.24), (0.1, -0.06, -0.6), (0.24, -0.12, -0.95), (0.42, -0.06, -1.15)], 0.04, collar, segs=5,
         parent=door)
    tube(arc((0.44, -0.06, -1.20), 0.07, 0, 360, 12, plane="xz")[:-1], 0.022, bonem(), segs=4, closed=True,
         parent=door)
    turn(-22)
    turn(30, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def _unknown():
    blob(0.9, loc=(0, 0, -0.2), scl=(1.0, 0.9, 1.0), m=flat("#ffffff"), amp=0.08)
    cyl(0.2, 0.25, loc=(0, 0, 0.75), m=flat("#ffffff"), segs=12)
    lathe([(0.0, 0.85), (0.25, 0.88), (0.45, 1.15), (0.35, 1.2), (0.0, 1.05)], m=flat("#ffffff"))


# ---------------------------------------------------------------- ICONS4: forge, anvil, medicine
# A kit is a small model of what it places (as above); the two medicines are small bottles, the
# same lathe-and-cork shape as toxin_coating, distinguished by contents and label colour.

def anvil_kit():
    """Anvil kit: an iron anvil with its horn and a hardie hole, sitting on a chopping-stump base,
    a hammer leaning against the stump, a struck-off spark at its foot."""
    iron = mat("#5e646a", 0.42, metal=0.9, color2="#3e444a", tex="noise", scale=9.0, bump=0.18)
    stump = mat("#8a6440", 0.85, color2="#5e4224", tex="rings", scale=6.0, bump=0.3)
    cyl(0.62, 0.85, loc=(0, 0, -0.95), m=stump, segs=22, smooth=False)
    for k in range(4):  # chopping marks and bark rim on the stump
        box((0.2, 0.04, 0.05), loc=(-0.2 + 0.15 * k, -0.3, -0.52), rot=(0, 0, 20 * k), m=mat("#3e2a14", 0.95),
            bev=0.0)
    # Body: a tapered waist between a wide base and the face, then the horn.
    box((0.95, 0.5, 0.24), loc=(0, 0, -0.3), m=iron, bev=0.03)
    box((0.62, 0.42, 0.32), loc=(0, 0, -0.02), m=iron, bev=0.02)
    box((1.35, 0.5, 0.22), loc=(0, 0, 0.24), m=iron, bev=0.025, taper=(0.96, 0.94))
    # The horn: a cone off one end of the face.
    cyl(0.22, 0.75, loc=(-0.98, 0, 0.26), rot=(0, 90, 0), m=iron, segs=16, r2=0.03, smooth=False)
    # The heel and its hardie hole at the other end.
    box((0.34, 0.44, 0.2), loc=(0.78, 0, 0.25), m=iron, bev=0.02)
    cyl(0.075, 0.24, loc=(0.78, 0, 0.3), m=mat("#1a1c1e", 0.9), segs=10)
    # A hammer: handle leaning on the stump, head on the base.
    hw = wood("#b08150", "#7a5630")
    tube([(0.62, -0.42, -1.25), (0.85, -0.45, -0.5), (1.0, -0.46, 0.1)], 0.06, hw, segs=8)
    box((0.34, 0.16, 0.16), loc=(1.05, -0.46, 0.18), rot=(0, 12, 0), m=iron, bev=0.02)
    # Two struck-off sparks of scale at the foot.
    for (x, y) in ((-0.6, -0.5), (-0.35, -0.62)):
        rock(0.07, loc=(x, y, -0.6), m=mat("#6a5a4a", 0.6, metal=0.5), jitter=0.3, sub=0)
    turn(-18)
    turn(10, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def forge_kit():
    """Forge: a stone hearth with a bed of glowing coals, a battered steel hood and flue above it,
    a leather bellows behind and a small stack of fuel at the foot: the placement model."""
    st = stone("#7a7c7a", "#4e504e")
    for i in range(9):  # the ring of hearth stones
        a = i * 0.7
        rock(0.3, loc=(0.9 * math.cos(a), 0.9 * math.sin(a), -0.6), scl=(1.3, 1.0, 0.8), m=st, jitter=0.14,
             sub=2)
    rock(0.72, loc=(0, 0, -0.72), scl=(1.5, 1.3, 0.4), m=stone("#6a6c6a", "#444644"), jitter=0.1, sub=2)
    coal = mat("#2a2624", 0.85, color2="#443c36", tex="voronoi", scale=7.0, bump=0.5,
               emit="#ff6a14", emit_strength=6.0, emit_mask=3.5)
    for (x, y, r) in ((0, 0, 0.32), (0.34, -0.2, 0.24), (-0.3, 0.16, 0.22), (0.05, 0.32, 0.2)):
        blob(r, loc=(x, y, -0.42), scl=(1.2, 1.0, 0.7), m=coal, amp=0.2, sub=2)
    # Hood: a wide iron cone over the fire, its flue running back and up.
    hood = mat("#5a5e62", 0.5, metal=0.75, color2="#3c4044", tex="noise", scale=8.0, bump=0.3)
    lathe([(0, 1.55), (0.22, 1.5), (0.3, 1.2), (1.05, 0.55), (1.12, 0.42), (0.95, 0.4), (0.85, 0.5), (0, 1.3)],
          m=hood, segs=26, smooth=False)
    tube([(0, 0.35, 1.3), (0, 0.7, 1.55), (0, 1.0, 1.85)], 0.2, hood, segs=12)
    for k in range(4):  # rivets round the hood rim
        a = math.radians(30 + 90 * k)
        ball(0.05, loc=(1.03 * math.cos(a), 1.03 * math.sin(a), 0.5), m=metal("#9aa0a6", 0.35), sub=2)
    # Bellows behind the hearth: two hide boards with a fold between them and a nozzle.
    bd = mat("#6e4a2a", 0.85, color2="#4a3018", tex="noise", scale=9.0, bump=0.4)
    g = group(loc=(-0.15, 0.95, -0.35), rot=(-14, 0, 18))
    box((0.9, 0.56, 0.1), loc=(0, 0, 0.06), m=bd, bev=0.03, parent=g)
    box((0.9, 0.56, 0.1), loc=(0, 0, -0.06), m=bd, bev=0.03, parent=g)
    for s in (-1, 1):
        tube([(s * 0.42, 0, 0.06), (s * 0.5, 0, 0.0), (s * 0.42, 0, -0.06)], 0.05, bd, segs=6, parent=g)
    tube([(-0.45, 0, 0), (-0.7, 0, 0.02)], 0.07, hood, segs=8, taper=(1.0, 0.6), parent=g)
    # Fuel: a small stack of charcoal at the foot.
    char = mat("#22201e", 0.6, color2="#3e3a36", tex="voronoi", scale=6.0, bump=0.4)
    for (x, y, z, rot_) in ((0.95, -0.5, -0.8, 12), (1.12, -0.64, -0.78, -20), (1.02, -0.55, -0.68, 40)):
        box((0.28, 0.2, 0.18), loc=(x, y, z), rot=(0, 0, rot_), m=char, bev=0.03)
    turn(-24)
    turn(8, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def _medicine_bottle(glass_c, tonic_c, label_c, label_marks, cork_c="#b88452", wax_c=None, tall=1.0,
                     emit_c=None, emit_s=0.0, rscale=1.0):
    """A stoppered medicine bottle: dark glass, a coloured contents level, a paper label band with
    printed marks, a cork and (optional) wax seal. rscale makes a slim vial."""
    r = rscale
    glass = mat(glass_c, 0.08, coat=1.0, color2=glass_c, tex="noise", scale=4.0)
    tonic = mat(tonic_c, 0.05, coat=1.0, color2=tonic_c, emit=emit_c, emit_strength=emit_s)
    lathe([(0, 0), (0.4 * r, 0.0), (0.48 * r, 0.1), (0.52 * r, 0.3), (0.52 * r, 0.9 * tall), (0.32 * r, 1.12 * tall),
           (0.2 * r, 1.24 * tall), (0.22 * r, 1.34 * tall), (0, 1.34 * tall)], m=glass, segs=26)
    lathe([(0, 0.06), (0.4 * r, 0.06), (0.47 * r, 0.14), (0.47 * r, 0.72 * tall), (0, 0.72 * tall)], m=tonic, segs=26)
    lathe([(0.53 * r, 0.28), (0.53 * r, 0.66 * tall), (0.47 * r, 0.66 * tall), (0.47 * r, 0.28)],
          m=mat(label_c, 0.9, color2="#c8b894", tex="noise", scale=20.0), segs=26)
    for k in range(label_marks):
        box((0.08 * r, 0.02, 0.025), loc=(-0.24 * r + 0.16 * r * k, -0.47 * r, 0.47 * tall),
            m=mat("#3a3a2a", 0.8), bev=0.0)
    cyl(0.22 * r, 0.2, loc=(0, 0, 1.42 * tall), m=mat(cork_c, 0.85, color2="#8a5a32", tex="noise", scale=12.0,
                                                     bump=0.4), segs=16)
    if wax_c:
        cyl(0.235 * r, 0.05, loc=(0, 0, 1.33 * tall), m=mat(wax_c, 0.45, color2=wax_c, tex="noise", scale=10.0),
            segs=16)


def antivenom():
    """Antivenom: a tall slim amber-glass vial of pale straw serum with a red wax seal, a shed fang
    and a drop of venom beside it: a vial, not the squat green tonic bottle."""
    _medicine_bottle("#8a6a2e", "#f4ecc0", "#ece4cc", 3, wax_c="#a8322a", tall=1.25, rscale=0.72)
    # The fang: a curved white cone lying at the bottle's foot.
    fang = mat("#f4eedc", 0.35, color2="#d8ccae", tex="noise", scale=6.0, spec=0.6)
    tube([(-0.55, -0.45, 0.32), (-0.8, -0.5, 0.18), (-0.95, -0.5, -0.02)], 0.075, fang, segs=8, taper=(1.0, 0.05))
    blob(0.1, loc=(-1.0, -0.5, -0.1), scl=(1.0, 1.0, 1.3), m=mat("#8ad83a", 0.05, coat=1.0, emit="#6ac81a",
                                                                 emit_strength=1.2), amp=0.1, sub=2)
    turn(-10)
    turn(8, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def antibiotic():
    """Antibiotic: a brown-glass jar of white powder with a screw lid and a blue label band, a small
    wooden spoon of powder beside it, two white tablets (a powder jar, not a liquid vial)."""
    glass = mat("#7a5a3a", 0.12, coat=1.0, color2="#5a4028", tex="noise", scale=5.0)
    lathe([(0, 0), (0.46, 0.0), (0.54, 0.1), (0.56, 0.6), (0.52, 0.72), (0.5, 0.8), (0, 0.8)], m=glass, segs=26)
    powder = mat("#f4f2ec", 0.85, color2="#dcd8ce", tex="noise", scale=24.0, bump=0.3)
    lathe([(0, 0.5), (0.5, 0.5), (0.5, 0.74), (0.34, 0.8), (0, 0.82)], m=powder, segs=26)
    lathe([(0.53, 0.08), (0.53, 0.34), (0.47, 0.34), (0.47, 0.08)], m=mat("#dcecf4", 0.9, color2="#b4ccd8",
                                                                          tex="noise", scale=20.0), segs=26)
    box((0.22, 0.02, 0.03), loc=(-0.1, -0.5, 0.22), m=mat("#2a5a9a", 0.8), bev=0.0)
    box((0.16, 0.02, 0.03), loc=(-0.08, -0.5, 0.14), m=mat("#2a5a9a", 0.8), bev=0.0)
    # Screw lid: a shallow drum with knurl ridges, sitting on the jar's neck.
    lid = metal("#9aa0a6", 0.35)
    cyl(0.54, 0.2, loc=(0, 0, 0.9), m=lid, segs=26)
    for k in range(16):
        a = math.radians(k * 22.5)
        box((0.03, 0.06, 0.16), loc=(0.54 * math.cos(a), 0.54 * math.sin(a), 0.9), rot=(0, 0, math.degrees(a)),
            m=lid, bev=0.0)
    # A spoon of powder and two tablets at the foot.
    sw = wood("#b08150", "#7a5630")
    tube([(0.55, -0.35, 0.1), (0.85, -0.5, 0.05), (1.05, -0.6, 0.02)], 0.035, sw, segs=6)
    blob(0.12, loc=(0.58, -0.36, 0.12), scl=(1.3, 1.2, 0.6), m=sw, amp=0.1, sub=2)
    blob(0.1, loc=(0.58, -0.36, 0.19), scl=(1.1, 1.0, 0.5), m=powder, amp=0.2, sub=2)
    for (x, y, s) in ((-0.62, -0.42, 0.12), (-0.42, -0.56, 0.11)):
        cyl(s, 0.05, loc=(x, y, 0.1), rot=(0, 0, 0), m=powder, segs=16)
    turn(20)
    turn(10, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


# ---------------------------------------------------------------- ICONS4: bags
# Every bag is the same readable satchel: a rounded body with a stitched seam, a flap sewn on its top
# edge that folds over and lies flat on the FRONT face (a rounded tongue, seated on the face), and
# flat webbing straps. The tiers differ by what is added: drawstring mouth and cord on the pouches,
# a strap + toggle on the basic bag, a plait on the woven bag, twin padded straps + pockets + bedroll
# on the backpack, a lashing frame and iron bands on the storage pack. Two earlier passes failed and
# are worth remembering: the flap floated in front of the body as a disc "lid", and the bodies sat on
# a flat slab that read as a tray. Both are gone: no base plate, and the flap sits at 0.5*d + 4 mm.

def _bag_body(w, h, d, m, amp=0.05):
    """The satchel body: a soft rounded box with a stitched seam round its waist."""
    g = group()
    blob(1.0, loc=(0, 0, -0.04 * h), scl=(0.5 * w, 0.5 * d, 0.48 * h), m=m, amp=amp, sub=3, parent=g)
    blob(1.0, loc=(0, 0, 0.3 * h), scl=(0.4 * w, 0.4 * d, 0.24 * h), m=m, amp=amp * 1.6, sub=3, parent=g)
    tube([(0.48 * w * math.cos(math.radians(a)), 0.48 * d * math.sin(math.radians(a)), -0.12 * h)
          for a in range(0, 360, 12)], 0.028, m, segs=5, closed=True, parent=g)
    return g


def _bag_flap(g, w, h, d, m, stud=None, tongue=0.62):
    """The flap: a tongue that hangs over the FRONT of the bag, narrower than the body and bent round
    its curve so its edges meet the sack instead of sticking out past it, plus a centre strap and a
    buckle. The earlier passes nailed flat plates and hem bars across the front, which read as planks
    and cardboard."""
    bulge = 2.2 / max(d, 0.4)

    def cupped(co):
        co.y -= bulge * co.x * co.x * 0.5

    wf, hf = 0.62 * w, 0.5 * h
    pts = [(-wf, hf), (wf, hf), (wf, 0.0), (0.74 * wf, -0.3 * h), (0.0, -0.44 * h), (-0.74 * wf, -0.3 * h),
           (-wf, 0.0)]
    prism(pts, 0.07, loc=(0, -0.4 * d, 0), m=m, bev=0.0, deform=cupped, parent=g)
    if stud:  # centre strap tail and its buckle
        tube([(0, -0.4 * d - 0.05, hf), (0, -0.4 * d - 0.07, -0.12 * h)], 0.075, m, segs=6, parent=g)
        box((0.14, 0.08, 0.16), loc=(0, -0.44 * d, -0.1 * h), m=stud, bev=0.0, parent=g)
    return g


def _strap(pts, m, w=0.16, flat=0.32):
    """A flat webbing strap, squashed across the view axis so it reads as webbing. Kept thin: the first
    pass's fat arcs rose higher than the bag and read as a bucket handle."""
    ob = tube(pts, w, m, segs=8)
    ob.scale = (1.0, flat, 1.0)
    return ob


def _handle(radius, m, thick=0.11, y=0.0, z=0.0):
    """A carrying loop: a strap arc rising from the bag's two top corners and meeting above the flap,
    kept low and squashed flat so it reads as webbing, not wire."""
    pts = [(radius * math.cos(math.radians(a)), y + 0.02 * math.sin(math.radians(a)),
            z + radius * math.sin(math.radians(a)))
           for a in range(0, 181, 10)]
    ob = tube(pts, thick, m, segs=8)
    ob.scale = (1.0, 0.36, 1.0)
    return ob


def _pouch(m, w, h, d, cord, g=None):
    """Drawstring pouch: one lathed sack that swells at the belly and is pinched at the neck with the
    cloth frilling out above the tie, the cord round the pinch. Two earlier passes failed here: a
    sphere with a lathed cup on top read as a gourd with a lid."""
    g = g or group()
    lathe([(0.0, 0.0), (0.5 * w, 0.03 * h), (0.62 * w, 0.3 * h), (0.58 * w, 0.6 * h), (0.3 * w, 0.84 * h),
           (0.22 * w, 0.9 * h), (0.34 * w, 0.97 * h), (0.3 * w, 1.03 * h), (0.0, 1.05 * h)],
          loc=(0, 0, -0.5 * h), m=m, segs=26, scl=(1.0, d / w, 1.0), parent=g)
    zt = -0.5 * h + 0.9 * h
    tube([(0.25 * w * math.cos(math.radians(a)), 0.25 * d * math.sin(math.radians(a)), zt)
          for a in range(0, 360, 18)], 0.04, cord, segs=5, closed=True, parent=g)
    for (sgn, dz) in ((1, 0.0), (0.7, 0.08)):
        tube([(0.22 * w * sgn, -0.16 * d, zt), (0.45 * w * sgn, -0.26 * d, zt + 0.08 + dz),
              (0.52 * w * sgn, -0.24 * d, zt - 0.16 + dz)], 0.023, cord, segs=4, parent=g)
    return g


def small_pouch():
    """Small pouch: a little drawstring hide pouch, cord tied with two loose ends and a bone bead."""
    lea = hidem("#b08a52", "#8a6434")
    cord = rope_m("#e2cc94")
    g = _pouch(lea, 1.0, 1.05, 0.66, cord)
    ball(0.085, loc=(0.5, -0.2, 0.45), m=bonem("#e4d6b0"), sub=2, parent=g)
    turn(8)
    turn(14, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def large_pouch():
    """Large pouch: the small pouch grown wide, a flap folded over its mouth and a shoulder strap:
    accessory-sized, so it hangs rather than being hauled."""
    lea = hidem("#9a6a3e", "#6e4a24")
    lea2 = hidem("#7a4e2a", "#54341a")
    cord = rope_m("#d8c08a")
    g = _pouch(lea, 1.32, 1.02, 0.8, cord)
    _bag_flap(g, 0.44, 0.6, 0.62, lea2, tongue=0.16)
    _handle(0.52, lea2, 0.07, y=0.06, z=0.12)
    turn(8)
    turn(14, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def basic_bag():
    """Basic bag: a plain hide satchel with one shoulder strap, a flap and a bone toggle: the first bag
    a survivor makes, so nothing on it is metal."""
    lea = hidem("#8a5a32", "#5e3a1e")
    lea2 = hidem("#734826", "#4c2e14")
    g = _bag_body(1.34, 1.1, 0.86, lea)
    _bag_flap(g, 0.66, 1.1, 0.86, lea2, stud=bonem('#e4d6b0'))
    _handle(0.58, lea2, 0.08, y=0.06, z=0.16)
    cyl(0.045, 0.3, loc=(0, -0.5, -0.42), rot=(0, 90, 0), m=bonem("#e4d6b0"), segs=8, parent=g)  # toggle
    tube([(0.0, -0.46, -0.2), (0.0, -0.5, -0.34)], 0.03, rope_m("#d8c08a"), segs=4, parent=g)
    turn(10)
    turn(14, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def woven_bag():
    """Woven bag: a bag plaited from fibre, its mouth rolled round a rim, two fibre handles and a hide
    patch on the front."""
    # Low weave contrast: the first try (bump 0.5, wave 9) rendered 65950 B, over the 64 KB budget
    # under Cycles noise (basket_kit hit the same limit).
    # Second size blow-up (72613 B) after adding the plaited warps: flat-ish weave, 7 warps.
    # Flat colours, no procedural texture: every textured variant of this bag rendered over the 64 KB
    # PNG cap (65405-72613 B) because the noise defeated the compressor. The plait is geometry now.
    weave = mat("#c8a05a", 0.92)
    fibre = mat("#dcc084", 0.94)
    hide = hidem("#8a5a32", "#5e3a1e")
    g = group()
    blob(1.0, loc=(0, 0, -0.02), scl=(0.6, 0.39, 0.53), m=weave, amp=0.015, sub=2, parent=g)
    for k in range(4):  # horizontal weft bands, sunk into the weave (fat standing hoops read as a barrel)
        z = -0.32 + 0.21 * k
        r = 0.6 - 0.05 * abs(k - 1.5)
        tube([(r * math.cos(math.radians(a)), 0.64 * r * math.sin(math.radians(a)), z)
              for a in range(0, 360, 12)], 0.026, fibre, segs=4, closed=True, parent=g)
    for (x, y0) in ((-0.32, 0.26), (0.0, 0.38), (0.32, 0.26)):  # three warps on the front, sunk in
        tube([(x, -y0, -0.38), (x * 1.06, -y0 * 1.06, 0.0), (x, -y0, 0.4)], 0.016, fibre, segs=4, parent=g)
    tube([(0.58 * math.cos(math.radians(a)), 0.37 * math.sin(math.radians(a)), 0.47)
          for a in range(0, 360, 10)], 0.055, weave, segs=6, closed=True, parent=g)  # rolled mouth
    for sgn in (-1, 1):  # two fibre handles rising from the mouth
        tube([(sgn * 0.34, -0.28, 0.47), (sgn * 0.42, -0.32, 0.76), (sgn * 0.08, -0.28, 0.88)], 0.036, fibre,
             segs=5, parent=g)
    prism([(-0.34, 0.16), (0.34, 0.16), (0.29, -0.12), (0.0, -0.2), (-0.29, -0.12)], 0.05,
          loc=(0, -0.36, 0), m=hide, bev=0.0, parent=g)  # hide patch on the front
    turn(14)
    turn(10, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def advanced_backpack():
    """Advanced backpack: a hide satchel with two padded shoulder straps, a flap with an iron buckle,
    two side pockets and a bedroll strapped across the top: clearly more than the basic bag."""
    lea = hidem("#7a4e2a", "#54341a")
    lea2 = hidem("#9a6a3e", "#6e4a24")
    iron = mat("#8a9098", 0.4)
    g = _bag_body(1.42, 1.2, 0.96, lea)
    _bag_flap(g, 0.7, 1.2, 0.96, lea2, stud=iron)
    _handle(0.46, lea2, 0.07, y=0.2, z=0.16)
    for sgn in (-1, 1):  # two padded shoulder straps
        _strap([(sgn * 0.62, 0.34, 0.0), (sgn * 0.5, 0.42, 0.5), (sgn * 0.24, 0.46, 0.62)],
               lea2, 0.11, 0.3)
        blob(0.34, loc=(sgn * 0.72, -0.12, -0.22), scl=(0.7, 1.0, 1.1), m=lea2, amp=0.08, sub=2,
             parent=g)  # side pocket
    box((0.3, 0.1, 0.22), loc=(0, -0.56, -0.3), m=iron, bev=0.0, parent=g)  # buckle on the tongue
    box((0.14, 0.08, 0.14), loc=(0, -0.6, -0.3), m=mat("#3a3e42", 0.6), bev=0.0, parent=g)
    roll = mat("#c8b48a", 0.9, color2="#a08a60", tex="wave", scale=22.0, bump=0.3)
    cyl(0.2, 1.7, loc=(0, 0.22, 0.66), rot=(0, 90, 0), m=roll, segs=18, parent=g)  # bedroll
    for x in (-0.46, 0.46):
        tube([(x, 0.22 + 0.23 * math.sin(math.radians(a)), 0.66 + 0.23 * math.cos(math.radians(a)))
              for a in range(0, 360, 20)], 0.028, lea2, segs=5, closed=True, parent=g)
    turn(12)
    turn(14, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def specialized_storage_bag():
    """Specialized storage bag: a rigid framed pack: two lashed uprights with cross rails, iron bands
    and buckles round the sack, two lashed-on pouches and a rolled mat strapped across the top."""
    lea = hidem("#6e4626", "#4a2e16")
    lea2 = hidem("#8a5a32", "#5e3a1e")
    w = wood("#7a5634", "#55391e")
    iron = mat("#8a9098", 0.3, metal=0.9)
    cord = rope_m("#d8c08a")
    g = _bag_body(1.3, 1.15, 0.9, lea)
    _bag_flap(g, 0.62, 1.15, 0.9, lea2)
    _handle(0.46, lea2, 0.07, y=0.2, z=0.16)
    for sgn in (-1, 1):  # the frame: two uprights behind the sack
        tube([(sgn * 0.66, 0.5, -0.58), (sgn * 0.7, 0.52, 0.02), (sgn * 0.58, 0.48, 0.66)], 0.055, w, segs=8,
             parent=g)
    for z in (-0.42, 0.38):  # cross rails
        tube([(-0.7, 0.5, z), (0, 0.5, z + 0.02), (0.7, 0.5, z)], 0.055, w, segs=8, parent=g)
    for (x, z) in ((-0.68, -0.42), (0.68, -0.42), (-0.6, 0.38), (0.6, 0.38)):  # lashings
        tube([(x, 0.5 + 0.09 * math.sin(math.radians(a)), z + 0.09 * math.cos(math.radians(a)))
              for a in range(0, 360, 24)], 0.026, cord, segs=4, closed=True, parent=g)
    for z in (-0.24, 0.18):  # iron bands round the sack, each with a buckle
        tube([(0.64 * math.cos(math.radians(a)), 0.45 * math.sin(math.radians(a)), z)
              for a in range(0, 360, 12)], 0.032, iron, segs=5, closed=True, parent=g)
        box((0.13, 0.09, 0.11), loc=(0, -0.47, z), m=iron, bev=0.0, parent=g)
    for (x, z, r) in ((0.5, 0.5, 0.22), (-0.5, 0.54, 0.2)):  # lashed-on pouches
        blob(r, loc=(x, -0.3, z), scl=(1.0, 0.8, 1.1), m=lea2, amp=0.08, sub=2, parent=g)
        tube([(x, -0.3, z + r), (x * 0.94, 0.46, z + r + 0.24)], 0.024, cord, segs=4, parent=g)
    mat_m = mat("#b8a06a", 0.92, color2="#8e7648", tex="wave", scale=20.0, bump=0.3)
    cyl(0.17, 1.45, loc=(0, 0.5, 0.7), rot=(0, 90, 0), m=mat_m, segs=16, parent=g)  # rolled mat
    for x in (-0.4, 0.4):
        tube([(x, 0.5 + 0.2 * math.sin(math.radians(a)), 0.7 + 0.2 * math.cos(math.radians(a)))
              for a in range(0, 360, 20)], 0.026, iron, segs=4, closed=True, parent=g)
    turn(12)
    turn(16, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


ITEMS = {
    # dsc icons4: the bag tiers.
    "small_pouch": small_pouch, "large_pouch": large_pouch, "basic_bag": basic_bag, "woven_bag": woven_bag,
    "advanced_backpack": advanced_backpack, "specialized_storage_bag": specialized_storage_bag,
    "straw_roll_kit": straw_roll_kit, "campfire_kit": campfire_kit, "bonfire_kit": bonfire_kit,
    "workbench_kit": workbench_kit, "tent_kit": tent_kit, "fence_kit": fence_kit, "gate_kit": gate_kit,
    "drying_rack_kit": drying_rack_kit, "catapult_kit": catapult_kit, "well_kit": well_kit, "basket_kit": basket_kit,
    "crock_pot_kit": crock_pot_kit, "stone_grill_kit": stone_grill_kit, "mortar_kit": mortar_kit,
    "claim_stake": claim_stake, "sign_kit": sign_kit, "bandage": bandage, "splint": splint, "toxin_pot": toxin_pot,
    "toxin_coating": toxin_coating, "rope_snare": rope_snare, "heavy_snare": heavy_snare, "_unknown": _unknown,
    # dsc icons2: the kits, feeds, medicine and cages that had no render.
    "cabin_bed_kit": cabin_bed_kit, "canvas_tent_kit": canvas_tent_kit, "field_large_kit": field_large_kit,
    "field_small_kit": field_small_kit, "log_shelter_kit": log_shelter_kit,
    "makeshift_taming_pen": makeshift_taming_pen, "smoker_kit": smoker_kit, "steamer_kit": steamer_kit,
    "stone_fire_pit_kit": stone_fire_pit_kit, "carnivore_feed": carnivore_feed,
    "herbivore_feed": herbivore_feed, "fruit_fertilizer": fruit_fertilizer,
    "pressure_dressing": pressure_dressing, "captured_animal": captured_animal, "tamed_animal": tamed_animal,
    # dsc icons4: forge, anvil and the two medicines.
    "forge_kit": forge_kit, "anvil_kit": anvil_kit, "antivenom": antivenom, "antibiotic": antibiotic,
}
