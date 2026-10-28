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
    upright()  # flat item: diagonal so the slot can lift it above its top edge


def raptor_meat():
    _drumstick(_raw("#9c2c48", "#e6a0b0"))


def roast():
    _drumstick(_cooked())


def seasoned_roast():
    """Seasoned roast: a drumstick crusted with a herb-and-pepper rub, green flecks and black pepper
    spots over the lit face, oiled to a sheen: distinct from the plain roast."""
    m = _cooked("#a85e20", "#5a3008")
    _drumstick(m)
    g_m = mat("#4a9a34", 0.55)
    pep = mat("#141008", 0.6)
    salt = mat("#f4f0e4", 0.35, spec=0.7)
    for i in range(30):
        a = math.radians(i * 41)
        r = 0.6 * (0.55 + 0.45 * ((i * 7) % 5) / 5.0)
        z = -0.85 + 0.95 * ((i * 3) % 7) / 7.0
        y = -abs(r * math.sin(a)) - 0.05      # the camera-facing half of the meat
        p_ = (r * math.cos(a), y, z)
        if i % 3 == 0:
            leaf(0.2, 0.07, loc=p_, rot=(80, math.degrees(a), 0), m=g_m, curl=0.01)
        elif i % 3 == 1:
            ball(0.045, loc=p_, m=pep, sub=1)
        else:
            box((0.06, 0.03, 0.03), loc=p_, rot=(20, 30, 40), m=salt, bev=0.0)
    # A herb sprig tucked under the bone.
    leaf(0.5, 0.18, loc=(0.35, -0.55, 0.4), rot=(70, 20, 0), m=g_m, curl=0.06)
    turn(10)
    lean(-42)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def grilled_meat():
    """Grilled meat: a thick steak with charred grid marks from the grill, a bone-in edge and a sprig,
    on a board: not a flat striped disc."""
    meat = mat("#7a3418", 0.5, color2="#b85a28", tex="noise", scale=3.0, bump=0.5, coat=0.5, ramp=(0.55, 0.85))
    char = mat("#241208", 0.7, color2="#3a2010", tex="noise", scale=8.0, bump=0.4)
    board = wood("#a87444", "#7a4a24")
    box((2.1, 1.5, 0.14), loc=(0, 0.1, -0.7), rot=(0, 0, 3), m=board, bev=0.06)
    # The steak: a fat lozenge, raised, with a dark seared crust and grill bars pressed across it.
    blob(0.85, loc=(0.0, -0.05, -0.15), scl=(1.25, 0.95, 0.38), m=meat, amp=0.1, sub=3)
    for k in range(2, 8):
        x = -0.7 + 0.2 * k
        tube([(x, -0.75, 0.1), (x + 0.05, 0.6, 0.12)], 0.055, char, segs=6, taper=(0.9, 1.0))
    b = bonem("#e2d2a8")
    tube([(0.9, -0.3, -0.2), (1.25, -0.45, -0.35)], 0.11, b, segs=8, taper=(1.0, 1.3))
    ball(0.14, loc=(1.3, -0.47, -0.38), m=b, sub=2)
    leaf(0.45, 0.16, loc=(-0.75, -0.4, 0.0), rot=(60, 30, 0), m=mat("#4f9a3a", 0.5), curl=0.05)
    turn(24)
    turn(40, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def dried_meat():
    _strips(mat("#8e3420", 0.6, color2="#d8906a", tex="noise", scale=4.0, bump=0.4, ramp=(0.6, 0.75)))


def smoked_meat():
    """Smoked meat: a haunch of smoked meat, dark mahogany glaze over a wrinkled rind, tied round
    with twine, its bone out at the knee, and a bundle of jerky strips beside it: unlike the roasts,
    which are plated drumsticks in a cooked brown."""
    glaze = mat("#54200c", 0.35, color2="#8a3c14", tex="noise", scale=4.0, bump=0.6, spec=0.5, ramp=(0.45, 0.8))
    meat = mat("#5e2610", 0.5, color2="#8a4420", tex="voronoi", scale=12.0, bump=0.9, spec=0.35)
    _haunch(meat)
    # Glaze: a shiny dark pass over the near half of the haunch.
    blob(0.85, loc=(-0.1, -0.25, 0.0), scl=(1.0, 0.6, 0.85), m=glaze, amp=0.12, sub=3)
    # Twine: two loops round the meat and a knot.
    for x in (-0.45, 0.15):
        tube(arc((0, 0, 0), 0.8, 0, 360, 26, plane="xz", y=0)[:-1], 0.035, rope_m("#c8a86a"), segs=4, closed=True,
             parent=group(loc=(x, -0.05, 0.0), rot=(0, 0, 90)))
    tube([(0.18, -0.5, 0.1), (0.35, -0.55, -0.2), (0.3, -0.5, -0.5)], 0.025, rope_m("#c8a86a"), segs=4)
    # Jerky strips leaning on it.
    jerky = mat("#6a2814", 0.55, color2="#9a4a22", tex="noise", scale=7.0, bump=0.5)
    for i in range(3):
        prism([(-0.08, 0.6), (0.08, 0.6), (0.06, -0.55), (0.0, -0.65), (-0.07, -0.5)], 0.04,
              loc=(-0.75 + 0.09 * i, 0.35 + 0.06 * i, -0.1), rot=(0, 12 + 14 * i, 0), m=jerky, bev=0.01)
    turn(12)
    lean(-40)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def skewer():
    _skewer([("#8e4a20", "#4e2408"), "#5aa84a", ("#8e4a20", "#4e2408"), "#e8d6b0"])


def spiced_skewer():
    _skewer([("#b8401a", "#5a1a06"), "#e8a020", ("#b8401a", "#5a1a06"), "#d83020"], specks=True)


def fish():
    """Fish: a silver fish with a dark blue back, a pale belly, a fine lateral line, orange fins and a
    round eye, its tail curling: no camouflage blotches."""
    back = mat("#4e6e80", 0.55, color2="#6e8e9e", tex="noise", scale=6.0, bump=0.25, spec=0.3)
    belly = mat("#e8ecf0", 0.45, color2="#c0ccd4", tex="noise", scale=7.0, spec=0.35)
    fin = mat("#d8803a", 0.5, color2="#a85a20", tex="noise", scale=10.0, bump=0.2)
    blob(1.0, scl=(1.4, 0.4, 0.55), m=back, amp=0.02)
    blob(0.92, loc=(0.0, -0.05, -0.13), scl=(1.3, 0.38, 0.32), m=belly, amp=0.02)
    tube([(0.95, -0.1, -0.02), (-1.1, -0.12, 0.0)], 0.014, mat("#c8d8e4", 0.4), segs=4)  # lateral line
    prism([(-1.25, 0.0), (-2.0, 0.6), (-1.85, 0.0), (-2.0, -0.6)], 0.06, m=fin, bev=0.01)
    prism([(-0.5, 0.5), (0.3, 0.55), (-0.2, 0.95)], 0.05, m=fin, bev=0.01)
    prism([(-0.3, -0.48), (0.35, -0.5), (0.05, -0.82)], 0.05, m=fin, bev=0.01)
    prism([(0.35, -0.35), (0.7, -0.42), (0.45, -0.7)], 0.04, m=fin, bev=0.01)
    tube(arc((0.8, 0, 0), 0.34, 100, 260, 10, plane="xz", y=-0.36), 0.016, mat("#8aa4b4", 0.45), segs=4)
    ball(0.13, loc=(1.02, -0.3, 0.14), m=mat("#f0f4f0", 0.25), sub=3)
    ball(0.075, loc=(1.05, -0.4, 0.15), m=mat("#0a0a0a", 0.1, coat=1.0), sub=2)
    lean(52)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def sashimi():
    leaf(2.6, 0.8, loc=(-1.3, 0.1, -0.95), rot=(90, 0, 90), m=mat("#4fa04a", 0.5, color2="#3a8a3a", tex="wave", scale=6.0),
         curl=-0.05)
    salmon = mat("#ff8a5a", 0.25, color2="#fff0e0", tex="wave", scale=5.0, coat=0.6, ramp=(0.8, 0.9))
    for i in range(3):
        box((0.42, 0.95, 0.24), loc=(-0.5 + 0.48 * i, 0.05 * i, -0.72 + 0.1 * i), rot=(0, -20, 8), m=salmon, bev=0.08)
    blob(0.18, loc=(0.85, -0.25, -0.78), m=mat("#9ac83a", 0.6), amp=0.1)
    turn(-10)
    turn(25, "X")
    upright()  # flat item: diagonal so the slot can lift it above its top edge


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


def _drum_radius(z):
    """Radius of the drumstick's meat at height z (same profile as _drumstick)."""
    prof = [(-1.0, 0.0), (-0.96, 0.3), (-0.72, 0.55), (-0.3, 0.63), (0.1, 0.56), (0.42, 0.38), (0.62, 0.2), (0.78, 0.13)]
    for (z0, r0), (z1, r1) in zip(prof, prof[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0)
            return r0 + (r1 - r0) * t
    return 0.0


def burnt_food():
    """Burnt food: a drumstick burnt black, ash-grey crackle lines running across the charred skin and
    a dull ember glow deep in two of them: scorched food, not a lava rock."""
    char = mat("#26221e", 0.95, color2="#463e34", tex="noise", scale=6.0, bump=0.8, ramp=(0.3, 0.7))
    ash = mat("#9a958c", 0.99, color2="#726d64", tex="noise", scale=14.0, bump=0.3)
    ember = mat("#e86a24", 0.55, color2="#a84810", emit="#ff6a1a", emit_strength=0.9)
    lathe([(0, -1.0), (0.3, -0.96), (0.55, -0.72), (0.63, -0.3), (0.56, 0.1), (0.38, 0.42), (0.2, 0.62), (0.13, 0.78)],
          m=char)
    # Crackle lines: thin ash-grey fissures lying on the char, plus two with embers in them.
    for i in range(6):
        a0 = math.radians(200 + 25 * i)
        zs = -0.85 + 0.18 * (i % 3)
        pts = []
        for k in range(6):
            z = zs + 0.07 * k
            aa = a0 + 0.18 * math.sin(k * 1.3 + i)
            r = _drum_radius(z) * 1.01
            pts.append((r * math.cos(aa), r * math.sin(aa), z))
        tube(pts, 0.018, ember if i in (1, 4) else ash, segs=4)
    # A few ash flakes: flat chips clinging to the lower crust.
    for (a0, z) in ((250, -0.75), (300, -0.55), (215, -0.4)):
        aa = math.radians(a0)
        r = _drum_radius(z) * 1.0
        prism([(-0.08, -0.05), (0.06, -0.08), (0.1, 0.03), (0.0, 0.08), (-0.09, 0.04)], 0.012,
              loc=(r * math.cos(aa), r * math.sin(aa), z), rot=(90, math.degrees(aa), 0), m=ash, bev=0.0)
    b = mat("#5e564c", 0.9, color2="#3e3830", tex="noise", scale=8.0, bump=0.4)
    cyl(0.1, 0.7, loc=(0, 0, 1.05), m=b)
    for dx in (-0.09, 0.09):
        ball(0.15, loc=(dx, 0, 1.42), m=b, sub=2)
    lean(-42)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


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
    """Berry: three dark blue-purple berries in a cluster, each with a clear green five-pointed calyx
    on its top, and a stem with one leaf: not a plain sphere."""
    m = mat("#4a3ab8", 0.45, color2="#2a1a78", tex="noise", scale=3.0, spec=0.3)
    calyx = mat("#5a9a42", 0.55, color2="#3a6a28", tex="noise", scale=6.0)
    spots = ((0, -0.05, 0.05, 0.52), (0.56, 0.1, -0.22, 0.44), (-0.54, 0.12, -0.18, 0.46))
    for (x, y, z, r) in spots:
        ball(r, loc=(x, y, z), scl=(1.0, 1.0, 0.92), m=m, sub=4)
        # Calyx: a big green star laid on the berry's top, its points over the shoulder.
        top = (x, y, z + r * 0.9)
        pts = []
        for k in range(10):
            rr = r * 0.75 * (1.0 if k % 2 == 0 else 0.4)
            a = math.radians(k * 36 + 18)
            pts.append((rr * math.cos(a), rr * math.sin(a)))
        cal = group(loc=top, rot=(0, 0, 0))
        prism(pts, 0.05, rot=(0, 0, 0), m=calyx, bev=0.008, parent=cal, deform=None)
        for k in range(5):  # the star's points bend down over the berry
            a = math.radians(k * 72 + 18)
            ball(0.07, loc=(r * 0.8 * math.cos(a), r * 0.8 * math.sin(a), -r * 0.25), m=calyx, sub=2, parent=cal)
    tube([(0.0, -0.05, 0.6), (0.02, -0.02, 0.85), (0.18, 0.0, 1.05)], 0.04, calyx, segs=6)
    leaf(0.65, 0.26, loc=(0.18, 0.0, 1.0), rot=(5, 55, 0), m=calyx, curl=0.12)
    turn(18)
    turn(10, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def mango():
    """Mango: one long kidney-shaped fruit, green at the stem blushing to red-orange, a dark stem and
    a leaf, beside a cut cheek showing the deep orange flesh (review: blotchy; a round fruit next
    to a green ball read as an orange and a lime)."""
    skin = mat("#a8c03a", 0.4, color2="#e0502a", tex="noise", scale=0.45, spec=0.35, ramp=(0.4, 0.6))
    flesh = mat("#ffa020", 0.35, color2="#f08010", tex="noise", scale=4.0, spec=0.4, coat=0.3)
    g = group(loc=(-0.25, 0.1, 0.1), rot=(0, 30, 0))
    blob(0.85, scl=(0.66, 0.6, 1.12), m=skin, amp=0.06, parent=g, seed=(3, 1, 4))
    ball(0.16, loc=(0.22, 0, -0.84), scl=(1, 1, 0.8), m=skin, parent=g)  # the beak at the tip
    tube([(-0.05, 0, 0.9), (-0.08, 0, 1.12)], 0.05, mat("#5a4a2a", 0.6), segs=6, parent=g)
    leaf(0.85, 0.24, loc=(-0.08, 0, 1.08), rot=(10, -60, 0),
         m=mat("#3e7a34", 0.5, color2="#2a5a24", tex="wave", scale=8.0), curl=0.12, parent=g)
    cheek = group(loc=(0.62, -0.35, -0.45), rot=(-105, 0, 15))
    lathe([(0, 0.0), (0.5, 0.0), (0.48, 0.12), (0.38, 0.26), (0.2, 0.34), (0, 0.36)], m=skin,
          scl=(0.72, 1.0, 1.0), parent=cheek)
    lathe([(0, -0.02), (0.43, -0.02), (0.43, 0.01), (0, 0.01)], m=flesh, scl=(0.72, 1.0, 1.0), parent=cheek)
    # The pale fibrous stone showing through the middle of the cut face.
    lathe([(0, -0.03), (0.2, -0.03), (0.2, 0.0), (0, 0.0)], m=mat("#ffe0a0", 0.6, color2="#f0c070", tex="wave", scale=12.0),
          scl=(0.6, 1.0, 1.0), parent=cheek)
    turn(10)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


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


# ---------------------------------------------------------------- ICONS4: drinks and the crafter's meal
# Same bowls, plates and lathes as above: a drink is a lathe cup with a surface disc, so it reads
# by what is in it at slot size.

def _cup(m, liquid=None, r=0.78, h=1.0, wall=0.78, dz=0.0):
    """Open cup (or mug) of radius r: outer wall, rim, inner wall and base, plus a surface disc."""
    lathe([(0, 0), (r * 0.86, 0.0), (r * 0.94, h * 0.12), (r, h * 0.9), (r, h), (r * wall + 0.03, h),
           (r * wall + 0.02, h * 0.75), (r * wall * 0.9, h * 0.2), (0, h * 0.16)], m=m, segs=32)
    if liquid:
        cyl(r * wall, 0.03, loc=(0, 0, h * (0.72 + dz)), m=liquid, segs=32)


def _handle(m, r=0.78, h=1.0, side=1):
    """A cup handle: an open loop on the +X side, from the rim to near the base."""
    pts = arc((side * (r + 0.16), 0, h * 0.55), 0.3, -80 if side > 0 else 100, 90 if side > 0 else -90, 14, plane="xz")
    tube([(side * (r - 0.02), 0, h * 0.86)] + pts + [(side * (r - 0.02), 0, h * 0.28)], 0.055, m, segs=6)


def spring_water():
    """Spring water: a clay cup of clear water, the surface bright with a highlight, two drops
    running down the outside of the cup (the cup, not a bottle, is what a spring fills)."""
    clay = mat("#c9a882", 0.75, color2="#a08262", tex="noise", scale=7.0, bump=0.25)
    water = mat("#7fd4f0", 0.05, coat=1.0, color2="#3fa8d8", tex="noise", scale=3.0, alpha=1.0,
                emit="#2a94c8", emit_strength=0.25)
    _cup(clay, water)
    _handle(clay)
    # A white glint on the water and a bead of water on the rim.
    for (x, y, s) in ((-0.2, -0.32, 0.11), (0.24, -0.22, 0.06)):
        blob(s, loc=(x, y, 0.76), scl=(1.5, 0.9, 0.25), m=mat("#ffffff", 0.1, coat=1.0), amp=0.1, sub=2)
    for (x, z, s) in ((0.55, 0.42, 0.075), (0.62, 0.2, 0.05)):
        blob(s, loc=(x, -0.62, z), scl=(1.0, 0.35, 1.3), m=water, amp=0.1, sub=2)
    turn(-18)
    turn(14, "X")


def tea():
    """Tea: a pale ceramic cup of amber tea with a teabag's string over the rim and a green leaf
    beside it (the leaves are what say tea, the colour says not coffee)."""
    cer = mat("#ece4d2", 0.55, color2="#cfc2a8", tex="noise", scale=9.0, bump=0.12, spec=0.6)
    tea_m = mat("#b8621e", 0.06, coat=1.0, color2="#8a3e0e", tex="noise", scale=3.5)
    _cup(cer, tea_m, r=0.74, h=1.05)
    _handle(cer, r=0.74, h=1.05)
    # Teabag string: a pale thread over the rim to a small tag leaning on the table.
    tube([(0.28, -0.3, 0.95), (0.6, -0.34, 1.02), (0.9, -0.4, 0.8), (1.02, -0.44, 0.45)], 0.016,
         mat("#f4ecd8", 0.8), segs=4)
    box((0.24, 0.02, 0.18), loc=(1.02, -0.44, 0.34), rot=(0, 22, 8), m=mat("#e4d6b4", 0.8, color2="#c4b48e",
                                                                          tex="noise", scale=16.0), bev=0.004)
    leaf(0.7, 0.22, loc=(0.1, 0.28, 0.1), rot=(70, 30, 0), m=mat("#4f9a3a", 0.5, color2="#3a7a2a",
                                                                 tex="wave", scale=8.0), curl=0.1)
    leaf(0.55, 0.18, loc=(-0.2, 0.34, 0.05), rot=(75, -40, 0), m=mat("#5aa842", 0.5, color2="#3a7a2a",
                                                                    tex="wave", scale=8.0), curl=0.08)
    turn(-16)
    turn(12, "X")


def _filter_cone():
    """Brown paper drip filter cone standing in a cup, its seam and a fold visible."""
    paper = mat("#b08a5a", 0.9, color2="#8a683e", tex="wave", scale=22.0, bump=0.15)
    lathe([(0.42, 0.0), (0.5, 0.02), (0.95, 1.0), (1.02, 1.0), (1.06, 0.96), (0.52, 0.0)], m=paper, segs=28,
          smooth=False, loc=(0, 0, 0.78))
    for k in range(10):  # the pleated rim
        a = math.radians(k * 36)
        box((0.06, 0.05, 0.14), loc=(1.04 * math.cos(a), 1.04 * math.sin(a), 1.88), rot=(0, 0, math.degrees(a)),
            m=paper, bev=0.006)
    # Coffee grounds sitting in the cone.
    blob(0.44, loc=(0, 0, 1.5), scl=(1.0, 1.0, 0.35), m=mat("#3a2618", 0.9, color2="#1e1408", tex="noise",
                                                             scale=10.0), amp=0.12, sub=2)


def drip_coffee():
    """Drip coffee: a mug of dark coffee with a paper filter cone standing in it, the last of the
    brew dripping from the cone (the cone is the silhouette that tells it from tea)."""
    cer = mat("#d8d2c4", 0.5, color2="#b4ae9e", tex="noise", scale=9.0, bump=0.1, spec=0.5)
    brew = mat("#2e1a0c", 0.08, coat=1.0, color2="#1a0e06", tex="noise", scale=4.0)
    _cup(cer, brew, r=0.82, h=0.95)
    _handle(cer, r=0.82, h=0.95)
    _filter_cone()
    tube([(0, -0.02, 0.84), (0, -0.02, 0.9)], 0.022, brew, segs=6)  # the drip
    blob(0.06, loc=(0, -0.02, 0.9), scl=(1.0, 1.0, 1.3), m=brew, amp=0.1, sub=2)
    turn(-20)
    turn(14, "X")


def dutch_coffee():
    """Dutch coffee: a squat tin pot with a long spout, a bail handle over the top and dark coffee
    showing at the rim, a coarse-ground pinch beside it: the camp pot, not the paper filter."""
    tin = mat("#8a9098", 0.35, metal=0.9, color2="#6a7078", tex="noise", scale=8.0, bump=0.08)
    brew = mat("#301c0e", 0.08, coat=1.0, color2="#1c1006", tex="noise", scale=4.0)
    prof = [(0, 0), (0.66, 0.0), (0.78, 0.12), (0.9, 0.62), (0.92, 0.86), (0.8, 0.9), (0.86, 1.0), (0.78, 1.02),
            (0.74, 0.86), (0.72, 0.5), (0.62, 0.1), (0, 0.1)]
    lathe(prof, m=tin, segs=32)
    cyl(0.7, 0.02, loc=(0, 0, 0.82), m=brew, segs=28)
    # The long spout, up and out from the shoulder.
    tube([(0.72, 0, 0.55), (1.05, 0, 0.82), (1.3, 0, 1.12), (1.36, 0, 1.2)], 0.1, tin, segs=10, taper=(1.0, 0.55))
    # Bail handle: a wire arc over the pot.
    tube(arc((0, 0, 0.98), 0.62, 10, 170, 18, plane="xz"), 0.03, tin, segs=5)
    for s in (-1, 1):
        box((0.08, 0.1, 0.1), loc=(s * 0.88, 0, 0.94), m=tin, bev=0.01)
    # Coarse grounds: a small dark heap beside the pot.
    for (x, y, s) in ((0.35, -0.72, 0.22), (0.62, -0.66, 0.15), (0.1, -0.78, 0.13)):
        blob(s, loc=(x, y, 0.08), scl=(1.4, 1.0, 0.45), m=mat("#3a2414", 0.98, color2="#1e1208", tex="noise",
                                                              scale=14.0), amp=0.3, sub=2)
    turn(-24)
    turn(16, "X")


def fatigue_tonic():
    """Fatigue tonic: a small dark-glass bottle of green tonic, corked and waxed, its label a paper
    band: a medicine bottle, not a drink cup."""
    glass = mat("#2e5a4a", 0.08, coat=1.0, color2="#1a3a2e", tex="noise", scale=4.0)
    tonic = mat("#7dff6a", 0.05, coat=1.0, emit="#5ad84a", emit_strength=1.4)
    lathe([(0, 0), (0.42, 0.0), (0.5, 0.1), (0.55, 0.32), (0.55, 0.95), (0.34, 1.2), (0.22, 1.32), (0.24, 1.42),
           (0, 1.42)], m=glass, segs=28)
    lathe([(0, 0.06), (0.42, 0.06), (0.5, 0.14), (0.5, 0.8), (0, 0.8)], m=tonic, segs=28)
    # Paper label band across the belly.
    lathe([(0.56, 0.3), (0.56, 0.68), (0.5, 0.68), (0.5, 0.3)], m=mat("#ece0c4", 0.9, color2="#c8b894",
                                                                     tex="noise", scale=20.0), segs=28)
    for k in range(4):  # a printed row of marks on the label
        box((0.09, 0.02, 0.03), loc=(-0.3 + 0.2 * k, -0.48, 0.5), m=mat("#3a4a2a", 0.8), bev=0.0)
    cyl(0.24, 0.22, loc=(0, 0, 1.5), m=mat("#b88452", 0.85, color2="#8a5a32", tex="noise", scale=12.0,
                                           bump=0.4), segs=16)  # cork
    cyl(0.255, 0.06, loc=(0, 0, 1.4), m=mat("#8a2a32", 0.45, color2="#5a141c", tex="noise", scale=10.0),
        segs=16)  # wax
    turn(-8)
    turn(6, "X")
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def crafters_meal():
    """Crafter's meal: a plate with a slab of roast, a floury roll, two wedges of root veg and a
    sprig: a full plate, not a bowl of stew or a single haunch."""
    _plate(1.25)
    roast_m = _cooked("#9a5222", "#54280c")
    blob(0.62, loc=(-0.3, 0.05, -0.2), scl=(1.25, 0.9, 0.6), m=roast_m, amp=0.12, sub=3)
    for k in range(3):  # scored fat lines across the roast
        tube([(-0.75 + 0.4 * k, -0.42, -0.02), (-0.6 + 0.4 * k, -0.5, -0.2), (-0.45 + 0.4 * k, -0.36, -0.34)],
             0.03, mat("#e8c48a", 0.6), segs=4)
    bread = mat("#d8ae6e", 0.65, color2="#b08a4a", tex="noise", scale=8.0, bump=0.2)
    blob(0.42, loc=(0.62, 0.12, -0.12), scl=(1.15, 0.95, 0.75), m=bread, amp=0.12, sub=3)
    for k in range(2):  # a slash across the roll
        tube([(0.42 + 0.16 * k, -0.42, 0.06 + 0.02 * k), (0.62 + 0.16 * k, -0.34, 0.14)], 0.03,
             mat("#e8ca94", 0.7), segs=4)
    veg = mat("#d87a1e", 0.55, color2="#a8520e", tex="noise", scale=7.0, coat=0.3)
    for (x, y, rot_) in ((-0.35, 0.55, 20), (0.05, 0.62, -25)):
        box((0.34, 0.2, 0.26), loc=(x, y, -0.28), rot=(0, 0, rot_), m=veg, bev=0.05)
    leaf(0.6, 0.2, loc=(0.85, -0.35, -0.3), rot=(70, 35, 0), m=mat("#4f9a3a", 0.5, color2="#3a7a2a",
                                                                 tex="wave", scale=8.0), curl=0.08)
    turn(-14)
    turn(24, "X")
    upright()  # flat item: diagonal so the slot can lift it above its top edge


ITEMS = {
    "raw_meat": raw_meat, "raptor_meat": raptor_meat, "roast": roast, "seasoned_roast": seasoned_roast,
    "grilled_meat": grilled_meat, "dried_meat": dried_meat, "smoked_meat": smoked_meat, "skewer": skewer,
    "spiced_skewer": spiced_skewer, "fish": fish, "sashimi": sashimi, "meatball": meatball,
    "meatball_mix": meatball_mix, "camp_stew": camp_stew, "boiled_meat": boiled_meat, "burnt_food": burnt_food,
    "steamed_food": steamed_food, "herb_buff_meal": herb_buff_meal, "berries": berries, "berry": berry,
    "mango": mango, "coconut": coconut, "mushroom": mushroom, "corn": corn, "cactus_flesh": cactus_flesh,
    "corn_seed": corn_seed, "wheat_seed": wheat_seed, "flax_seed": flax_seed, "berry_seed": berry_seed,
    # dsc icons4: drinks and the crafter's meal.
    "spring_water": spring_water, "tea": tea, "drip_coffee": drip_coffee, "dutch_coffee": dutch_coffee,
    "fatigue_tonic": fatigue_tonic, "crafters_meal": crafters_meal,
}
