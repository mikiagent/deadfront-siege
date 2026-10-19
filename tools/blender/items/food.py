"""Food: raw and cooked meat, fish, fruit, crops, seeds and meals."""
from kit import *  # noqa: F401,F403


def _raw(c="#c43a44", c2="#f2c0b8"):
    return mat(c, 0.38, color2=c2, tex="noise", scale=3.0, bump=0.15, coat=0.35, ramp=(0.56, 0.7))


def _cooked(c="#8e4a20", c2="#4e2408"):
    return mat(c, 0.42, color2=c2, tex="noise", scale=4.0, bump=0.3, coat=0.55, ramp=(0.35, 0.8))


def _flat(parent_rot=(90, 0, 0), loc=(0, 0, 0)):
    """Group whose children built in XZ end up lying flat (outline in XY, thickness along Z)."""
    return group(loc=loc, rot=parent_rot)


def _haunch(m):
    blob(1.0, scl=(1.05, 0.72, 0.85), m=m, amp=0.1)
    b = bonem()
    cyl(0.13, 1.1, loc=(1.05, 0, 0.35), rot=(0, 62, 0), m=b)
    ball(0.17, loc=(1.55, 0.09, 0.62), m=b, sub=2)
    ball(0.17, loc=(1.47, -0.1, 0.72), m=b, sub=2)


def _drumstick(m, herbs=False):
    lathe([(0, -1.0), (0.3, -0.96), (0.55, -0.72), (0.63, -0.3), (0.56, 0.1), (0.38, 0.42), (0.2, 0.62), (0.13, 0.78)],
          m=m)
    b = bonem()
    cyl(0.1, 0.7, loc=(0, 0, 1.05), m=b)
    for dx in (-0.09, 0.09):
        ball(0.15, loc=(dx, 0, 1.42), m=b, sub=2)
    if herbs:
        g_m = mat("#4f9a3a", 0.5)
        for i, (z, ang) in enumerate(((-0.2, 30), (0.05, -40), (-0.5, -10))):
            leaf(0.35, 0.12, loc=(0.15 * (i - 1), -0.6, z), rot=(80, ang, 0), m=g_m, curl=0.05)
        pep = mat("#1a1410", 0.6)
        for i in range(10):
            a = i * 2.39
            ball(0.03, loc=(0.4 * math.cos(a), -0.52 + 0.05 * math.sin(a), -0.45 + 0.09 * i), m=pep, sub=1)
    lean(-42)


def raw_meat():
    _haunch(_raw())
    lean(10)


def raptor_meat():
    _drumstick(_raw("#9c2c48", "#e6a0b0"))


def roast():
    _drumstick(_cooked())


def seasoned_roast():
    _drumstick(_cooked("#a0521e", "#5a2a0a"), herbs=True)


def grilled_meat():
    g = _flat()
    outline = [(-1.0, -0.2), (-0.8, -0.65), (-0.2, -0.8), (0.5, -0.7), (1.0, -0.35), (1.05, 0.2), (0.7, 0.62),
               (0.0, 0.75), (-0.65, 0.55), (-1.0, 0.25)]
    prism(outline, 0.35, m=mat("#6a3214", 0.6, color2="#1e0c04", tex="wave", scale=0.7, bump=0.4, coat=0.1,
                                ramp=(0.9, 0.97)), bev=0.1, parent=g)
    prism([(-1.08, -0.22), (-0.86, -0.72), (-0.82, -0.66), (-1.0, -0.2)], 0.3, m=mat("#f0dcc0", 0.5), bev=0.03, parent=g)
    turn(30)
    turn(42, "X")


def _strips(m, tie=None):
    """Jerky: four narrow torn strips, gaps between them so each reads on its own."""
    for i in range(4):
        pts = [(-1.0, -0.12), (-0.45, -0.16), (0.1, -0.1), (0.6, -0.17), (1.0, -0.06), (0.9, 0.04), (1.02, 0.14),
               (0.45, 0.16), (-0.1, 0.11), (-0.6, 0.17), (-0.95, 0.08), (-1.05, 0.0)]

        def wob(co, k=i):
            co.y += 0.18 * math.sin(co.x * 2.6 + k * 1.3)
        prism(pts, 0.07, loc=(0.12 * (i % 2), -0.05 * i, 0.4 * i - 0.6), rot=(0, 6 - 4 * i, 0), m=m, bev=0.02, deform=wob)
    if tie:
        tube([(-0.55, -0.35, 0.9), (-0.5, -0.32, -0.8)], 0.035, tie, segs=5)
        tube([(0.55, -0.35, 0.9), (0.5, -0.32, -0.8)], 0.035, tie, segs=5)
    lean(-24)


def dried_meat():
    _strips(mat("#8e3420", 0.6, color2="#d8906a", tex="noise", scale=4.0, bump=0.4, ramp=(0.6, 0.75)))


def smoked_meat():
    _strips(mat("#5a2a16", 0.55, color2="#2a1208", tex="noise", scale=5.0, bump=0.4, coat=0.3), tie=rope_m())


def _skewer(colors, specks=False):
    tube([(-1.5, 0, 0), (1.55, 0, 0)], 0.045, wood("#c9965a", "#9a6a35"), segs=8)
    cyl(0.045, 0.2, loc=(1.62, 0, 0), rot=(0, 90, 0), r2=0.0, m=wood("#c9965a", "#9a6a35"), segs=8)
    for i, c in enumerate(colors):
        x = -0.95 + 0.62 * i
        m = _cooked(*c) if isinstance(c, tuple) else mat(c, 0.4, coat=0.3)
        box((0.46, 0.44, 0.44), loc=(x, 0, 0), rot=(rnd(-10, 10), rnd(-15, 15), rnd(-10, 10)), m=m, bev=0.13)
        if specks:
            for k in range(5):
                a = k * 1.3
                ball(0.035, loc=(x + 0.15 * math.cos(a), -0.24, 0.15 * math.sin(a)), m=mat("#1a1008", 0.6), sub=1)
    lean(32)


def skewer():
    _skewer([("#8e4a20", "#4e2408"), "#5aa84a", ("#8e4a20", "#4e2408"), "#e8d6b0"])


def spiced_skewer():
    _skewer([("#b8401a", "#5a1a06"), "#e8a020", ("#b8401a", "#5a1a06"), "#d83020"], specks=True)


def fish():
    body = mat("#8fb0c8", 0.25, color2="#3e5a78", tex="noise", scale=2.0, coat=0.6, ramp=(0.35, 0.6))
    fin = mat("#c87a4a", 0.4, color2="#8a4a2a", tex="wave", scale=12.0)
    blob(1.0, scl=(1.45, 0.42, 0.62), m=body, amp=0.03)
    prism([(-1.35, 0.0), (-2.0, 0.55), (-1.85, 0.0), (-2.0, -0.55)], 0.06, m=fin, bev=0.01)
    prism([(-0.5, 0.5), (0.3, 0.55), (-0.2, 0.9)], 0.05, m=fin, bev=0.01)
    prism([(-0.2, -0.5), (0.3, -0.55), (0.0, -0.8)], 0.05, m=fin, bev=0.01)
    ball(0.12, loc=(1.0, -0.33, 0.15), m=mat("#f0f0e8", 0.3), sub=2)
    ball(0.07, loc=(1.03, -0.42, 0.16), m=mat("#0a0a0a", 0.1, coat=1.0), sub=2)
    lean(18)


def sashimi():
    leaf(2.6, 0.8, loc=(-1.3, 0.1, -0.95), rot=(90, 0, 90), m=mat("#4fa04a", 0.5, color2="#3a8a3a", tex="wave", scale=6.0),
         curl=-0.05)
    salmon = mat("#ff8a5a", 0.25, color2="#fff0e0", tex="wave", scale=5.0, coat=0.6, ramp=(0.8, 0.9))
    for i in range(3):
        box((0.42, 0.95, 0.24), loc=(-0.5 + 0.48 * i, 0.05 * i, -0.72 + 0.1 * i), rot=(0, -20, 8), m=salmon, bev=0.08)
    blob(0.18, loc=(0.85, -0.25, -0.78), m=mat("#9ac83a", 0.6), amp=0.1)
    turn(-10)
    turn(25, "X")


def _plate(r=1.1):
    lathe([(0, 0), (r * 0.8, 0.0), (r, 0.12), (r * 0.95, 0.16), (r * 0.78, 0.07), (0, 0.07)], m=wood("#b88452", "#8a5a30"),
          loc=(0, 0, -0.55))


def meatball():
    _plate()
    m = _cooked("#7a3a1a", "#3e1a08")
    for p in ((-0.35, 0.1, -0.2), (0.35, 0.1, -0.2), (0.0, -0.3, -0.2), (0.0, 0.05, 0.25)):
        blob(0.4, loc=p, m=m, amp=0.08)
    leaf(0.5, 0.15, loc=(0.6, -0.4, -0.4), rot=(70, 40, 0), m=mat("#4f9a3a", 0.5), curl=0.05)
    turn(20, "X")


def meatball_mix():
    _bowl(wood("#a87444", "#7a4a24"))
    for i in range(7):
        a = i * 0.9
        blob(0.28, loc=(0.35 * math.cos(a), 0.35 * math.sin(a), 0.62 + 0.05 * (i % 2)), m=_raw("#d06a6a", "#f2c8c0"), amp=0.15)
    turn(25, "X")


def _bowl(m, liquid=None, r=1.0):
    lathe([(0, 0), (r * 0.5, 0.0), (r * 0.9, 0.35), (r, 0.72), (r * 0.92, 0.74), (r * 0.82, 0.4), (r * 0.45, 0.1), (0, 0.1)],
          m=m, segs=32)
    if liquid:
        cyl(r * 0.88, 0.02, loc=(0, 0, 0.6), m=liquid, segs=32)


def camp_stew():
    _bowl(wood("#a87444", "#7a4a24"), mat("#8a4a1e", 0.2, coat=0.8, color2="#6a3410", tex="noise", scale=3.0))
    for i, c in enumerate(("#e8781e", "#7a3a1a", "#5aa84a", "#e8781e", "#7a3a1a")):
        a = i * 1.3
        box((0.18, 0.18, 0.12), loc=(0.5 * math.cos(a), 0.5 * math.sin(a), 0.64), rot=(0, 0, i * 30), m=mat(c, 0.4), bev=0.05)
    tube([(0.2, 0.1, 0.6), (0.9, 0.4, 1.3), (1.2, 0.5, 1.6)], 0.05, wood("#c9965a", "#9a6a35"), segs=8)
    turn(28, "X")


def boiled_meat():
    pot = mat("#a85a34", 0.75, color2="#7a3a1e", tex="noise", scale=4.0)
    _bowl(pot, mat("#c8944a", 0.15, coat=0.8))
    blob(0.42, loc=(0.0, 0.0, 0.7), scl=(1.3, 1.0, 0.6), m=mat("#9a5a3a", 0.45, color2="#6a3a22", tex="noise", scale=4.0),
         amp=0.1)
    for i in range(3):
        a = i * 2.0 + 0.5
        leaf(0.25, 0.08, loc=(0.6 * math.cos(a), 0.6 * math.sin(a), 0.62), rot=(80, 0, i * 120), m=mat("#4f9a3a", 0.5),
             curl=0.02)
    turn(28, "X")


def burnt_food():
    _drumstick(mat("#1c1612", 0.85, color2="#3a2a1e", tex="noise", scale=4.0, bump=0.6, emit="#ff4a10",
                   emit_strength=2.5, emit_mask=4.0))


def steamed_food():
    bam = mat("#c9a35a", 0.6, color2="#9a7a3a", tex="wave", scale=18.0)
    lathe([(0, 0.0), (1.0, 0.0), (1.0, 0.45), (0.92, 0.45), (0.92, 0.1), (0, 0.1)], m=bam, segs=36, smooth=False)
    bun = mat("#f6efe2", 0.6)
    for p in ((-0.4, 0.15, 0.35), (0.4, 0.15, 0.35), (0.0, -0.35, 0.35)):
        blob(0.38, loc=p, scl=(1.0, 1.0, 0.75), m=bun, amp=0.05)
        ball(0.08, loc=(p[0], p[1], p[2] + 0.28), m=bun, sub=2)
    turn(30, "X")


def herb_buff_meal():
    _plate(1.2)
    blob(0.55, loc=(0, 0.1, -0.15), scl=(1.3, 1.0, 0.7), m=_cooked("#a0521e", "#5a2a0a"), amp=0.12)
    g_m = mat("#4f9a3a", 0.5, color2="#3a7a2a", tex="wave", scale=8.0)
    for i in range(5):
        a = i * 1.25
        leaf(0.4, 0.13, loc=(0.75 * math.cos(a), 0.6 * math.sin(a), -0.42), rot=(75, i * 72, 0), m=g_m, curl=0.05)
    star = mat("#ffd84a", 0.3, emit="#ffc81a", emit_strength=3.0)
    pts = []
    for k in range(8):
        r = 0.32 if k % 2 == 0 else 0.1
        a = math.radians(90 + k * 45)
        pts.append((r * math.cos(a), r * math.sin(a)))
    prism(pts, 0.06, loc=(0.75, -0.3, 0.55), m=star, bev=0.01)
    prism([(x * 0.6, z * 0.6) for x, z in pts], 0.05, loc=(-0.65, -0.3, 0.7), m=star, bev=0.01)
    turn(20, "X")


def berries():
    m = mat("#a01a3c", 0.18, color2="#600a24", tex="noise", scale=3.0, coat=0.8)
    spots = [(0, 0, 0), (0.55, 0.1, -0.1), (-0.55, 0.1, -0.1), (0.28, -0.35, -0.3), (-0.28, -0.35, -0.3), (0.0, 0.25, 0.5),
             (0.3, -0.1, 0.45), (-0.3, -0.1, 0.45)]
    for p in spots:
        ball(0.33, loc=p, m=m, sub=3)
    st = mat("#6a7a3a", 0.5)
    tube([(0, 0.1, 0.7), (0.05, 0.1, 1.1), (0.25, 0.1, 1.35)], 0.035, st, segs=6)
    leaf(0.6, 0.22, loc=(0.25, 0.1, 1.3), rot=(0, 60, 0), curl=0.1)
    leaf(0.5, 0.2, loc=(0.05, 0.1, 1.05), rot=(0, -55, 0), curl=0.1)


def berry():
    m = mat("#4a3ab8", 0.2, color2="#2a1a78", tex="noise", scale=3.0, coat=0.8)
    ball(0.8, scl=(1.0, 1.0, 0.92), m=m, sub=4)
    crown = mat("#2a1a50", 0.5)
    pts = []
    for k in range(10):
        r = 0.25 if k % 2 == 0 else 0.1
        a = math.radians(k * 36)
        pts.append((r * math.cos(a), r * math.sin(a)))
    prism(pts, 0.06, loc=(0, 0, 0.72), rot=(90, 0, 0), m=crown, bev=0.01)
    leaf(0.7, 0.25, loc=(0.1, 0, 0.75), rot=(0, 50, 0), curl=0.12)
    turn(20, "X")


def mango():
    m = mat("#7ab83a", 0.35, color2="#ff6a2a", tex="noise", scale=0.9, coat=0.5, ramp=(0.4, 0.62))
    blob(1.0, scl=(0.8, 0.72, 1.12), m=m, amp=0.06, rot=(0, 18, 0))
    tube([(-0.2, 0, 1.0), (-0.25, 0, 1.25)], 0.05, mat("#5a4a2a", 0.6), segs=6)
    leaf(0.75, 0.24, loc=(-0.25, 0, 1.2), rot=(0, -55, 0), curl=0.12)


def coconut():
    husk = mat("#6b4a2a", 0.9, color2="#3e2814", tex="noise", scale=8.0, bump=0.8)
    blob(0.8, loc=(-0.45, 0.35, 0.1), m=husk, amp=0.06)
    shell = group(loc=(0.55, -0.25, -0.2), rot=(25, 0, 0))
    lathe([(0, -0.62), (0.4, -0.55), (0.62, -0.3), (0.7, 0.0), (0.62, 0.0), (0.55, -0.25), (0.35, -0.45), (0, -0.5)],
          m=husk, parent=shell)
    cyl(0.62, 0.04, loc=(0, 0, -0.01), m=mat("#f6f2e6", 0.45), segs=28, parent=shell)
    cyl(0.4, 0.05, loc=(0, 0, 0.0), m=mat("#e8e2d0", 0.2, coat=0.6), segs=24, parent=shell)
    turn(15)


def mushroom():
    cap = mat("#a8602a", 0.35, color2="#7a3e18", tex="noise", scale=3.0, coat=0.5)
    stem = mat("#efe4cc", 0.6)
    for (x, y, s) in ((0.0, 0.0, 1.0), (0.85, -0.3, 0.6)):
        g = group(loc=(x, y, -0.4 * (1 - s)), rot=(0, 10 * s - 5, 0))
        lathe([(0.0, 0.0), (0.28 * s, 0.0), (0.24 * s, 0.6 * s), (0.2 * s, 0.9 * s), (0, 0.9 * s)], m=stem, parent=g)
        lathe([(0, 1.35 * s), (0.35 * s, 1.3 * s), (0.62 * s, 1.15 * s), (0.75 * s, 0.92 * s), (0.6 * s, 0.86 * s),
               (0.2 * s, 0.85 * s), (0, 0.85 * s)], m=cap, parent=g)
    turn(10, "X")


def corn():
    m = mat("#f2c23a", 0.35, color2="#d8961a", tex="voronoi", scale=14.0, bump=0.6, coat=0.3)
    blob(0.45, scl=(1.0, 1.0, 2.6), m=m, amp=0.03)
    h = mat("#8ab84a", 0.5, color2="#6a9a2a", tex="wave", scale=10.0)
    for ang in (-40, 30, 160):
        leaf(1.3, 0.35, loc=(0, 0, -1.1), rot=(0, ang * 0.5, ang), m=h, curl=-0.25)
    lean(-35)


def cactus_flesh():
    pad = mat("#5aa04a", 0.4, color2="#3e7a32", tex="noise", scale=4.0, coat=0.3)
    blob(1.0, scl=(0.8, 0.28, 1.0), m=pad, amp=0.06)
    sp = mat("#f6f0dc", 0.4)
    for i in range(9):
        a = i * 2.4
        r = 0.25 + 0.06 * i
        cyl(0.025, 0.2, loc=(r * math.cos(a) * 0.8, -0.3, r * math.sin(a)), rot=(90, 0, 0), r2=0.0, m=sp, segs=6)
    box((0.6, 0.35, 0.5), loc=(0.85, -0.3, -0.6), rot=(0, 20, 10), m=mat("#cbe89a", 0.35, coat=0.4), bev=0.08)
    turn(-20)


def _seeds(c, c2, shape=(1.0, 0.7, 0.5), n=26):
    """A heap of seeds with a sprout: reads as 'plant me'."""
    m = mat(c, 0.35, color2=c2, tex="noise", scale=4.0, coat=0.4)
    for i in range(n):
        a = i * 2.4
        r = 0.9 * math.sqrt(i / n)
        z = 0.55 * (1 - r / 0.9) - 0.3
        ball(0.2, loc=(r * math.cos(a), r * math.sin(a) * 0.8, z), scl=shape,
             rot=(rnd(0, 90), rnd(0, 90), rnd(0, 180)), m=m, sub=2)
    st = mat("#6aa83a", 0.5)
    tube([(0, 0, 0.2), (0.02, 0, 0.6), (0, 0, 0.95)], 0.04, st, segs=6)
    leaf(0.5, 0.2, loc=(0, 0, 0.92), rot=(0, 55, 0), m=mat("#5fb04a", 0.5), curl=0.08)
    leaf(0.45, 0.18, loc=(0, 0, 0.92), rot=(0, -55, 0), m=mat("#5fb04a", 0.5), curl=0.08)
    turn(20, "X")


def corn_seed():
    _seeds("#f2c23a", "#d8961a", (0.9, 0.8, 0.7))


def wheat_seed():
    _seeds("#d8a85a", "#a87a3a", (1.3, 0.6, 0.6))


def flax_seed():
    _seeds("#7a4a2a", "#4a2a14", (1.3, 0.7, 0.4))


def berry_seed():
    _seeds("#3a2a1e", "#1e140c", (0.8, 0.8, 0.8))


ITEMS = {
    "raw_meat": raw_meat, "raptor_meat": raptor_meat, "roast": roast, "seasoned_roast": seasoned_roast,
    "grilled_meat": grilled_meat, "dried_meat": dried_meat, "smoked_meat": smoked_meat, "skewer": skewer,
    "spiced_skewer": spiced_skewer, "fish": fish, "sashimi": sashimi, "meatball": meatball,
    "meatball_mix": meatball_mix, "camp_stew": camp_stew, "boiled_meat": boiled_meat, "burnt_food": burnt_food,
    "steamed_food": steamed_food, "herb_buff_meal": herb_buff_meal, "berries": berries, "berry": berry,
    "mango": mango, "coconut": coconut, "mushroom": mushroom, "corn": corn, "cactus_flesh": cactus_flesh,
    "corn_seed": corn_seed, "wheat_seed": wheat_seed, "flax_seed": flax_seed, "berry_seed": berry_seed,
}
