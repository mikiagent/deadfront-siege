"""Tools, weapons and armor. Built upright (handle along Z, front toward -Y), then leaned."""
from kit import *  # noqa: F401,F403


def _ring(z, r, m, wire=0.028, n=18, x=0.0):
    return tube([(x + p[0], p[1], p[2]) for p in arc((0, 0, 0), r, 0, 360, n, plane="xy", y=z)[:-1]],
                wire, m, segs=6, closed=True)


def _handle(z0=-1.25, z1=1.1, r=0.075, m=None, bend=0.035):
    return tube([(bend * 0.5, 0, z0), (-bend, 0, z0 * 0.35), (0, 0, z1 * 0.45), (bend, 0, z1)], r, m or wood(), segs=12)


def _grip(z0, z1, r, m, pitch=0.07):
    return tube(helix(r, pitch, (z1 - z0) / pitch, 14, z0), 0.026, m, segs=6)


def _thin_edge(axis_from, axis_to, keep=0.3):
    """Deform: squeeze Y toward a blade edge between two X positions."""
    def f(co):
        t = min(max((co.x - axis_from) / (axis_to - axis_from), 0.0), 1.0)
        co.y *= 1.0 - (1.0 - keep) * t
    return f


def work_axe():
    _handle()
    head = [(-0.22, 0.86), (0.2, 0.8), (0.5, 0.64), (0.72, 0.56), (0.8, 0.95), (0.72, 1.34), (0.5, 1.28),
            (0.2, 1.1), (-0.22, 1.04)]
    prism(head, 0.2, m=stone("#a3a59f", "#6c6f6c"), bev=0.03, deform=_thin_edge(0.15, 0.8, 0.25))
    rp = rope_m()
    for z in (0.82, 0.9, 0.98, 1.06):
        _ring(z, 0.1, rp)
    _grip(-1.2, -0.55, 0.085, hidem("#5a3a22", "#3e2716"))
    lean(-38)


def work_pick():
    _handle()
    m = stone("#7f8790", "#4e555c")
    tube(arc((0, 0, 0.2), 1.0, 90, 150, 10), 0.13, m, segs=10, taper=(1.0, 0.12))
    tube(arc((0, 0, 0.2), 1.0, 90, 30, 10), 0.13, m, segs=10, taper=(1.0, 0.12))
    rp = rope_m()
    for z in (1.0, 1.08, 1.16):
        _ring(z, 0.105, rp)
    _grip(-1.2, -0.55, 0.085, hidem("#5a3a22", "#3e2716"))
    lean(-30)


def hoe():
    _handle(z1=1.2)
    blade = [(-0.05, 1.22), (0.12, 1.28), (0.82, 1.08), (0.9, 0.78), (0.6, 0.86), (0.08, 1.02)]
    prism(blade, 0.11, m=stone("#9a9488", "#6a645a"), bev=0.025, deform=_thin_edge(0.3, 0.9, 0.35))
    rp = rope_m()
    for z in (1.02, 1.1, 1.18):
        _ring(z, 0.1, rp)
    lean(-28)


def _knife_handle(m_wrap, m_core=None, length=0.85):
    cyl(0.12, length, loc=(0, 0, -length / 2 + 0.05), m=m_core or wood("#6e4626", "#4a2d16"))
    _grip(-length + 0.12, -0.02, 0.13, m_wrap, pitch=0.06)
    ball(0.15, loc=(0, 0, -length + 0.02), m=m_core or wood("#6e4626", "#4a2d16"), sub=2)


def stone_knife():
    """Stone knife: a knapped flint blade, pale honey-grey with flake scars, lashed with sinew to a
    wrapped handle: bright enough to read on the dark slot."""
    flint = mat("#c8bfa4", 0.35, color2="#a09472", tex="voronoi", scale=6.0, bump=0.25, spec=0.5)
    flint2 = mat("#e2d9bc", 0.3, color2="#b8ac88", tex="voronoi", scale=5.0, bump=0.15, spec=0.6)
    blade = [(0.0, 1.75), (0.2, 1.3), (0.28, 0.75), (0.22, 0.12), (-0.22, 0.12), (-0.26, 0.8), (-0.16, 1.3)]
    prism(blade, 0.16, m=flint, bev=0.02,
          deform=lambda co: co.__setitem__(1, co.y * (1.0 - 0.75 * min(abs(co.x) / 0.28, 1.0))))
    for (x, z, s) in ((-0.08, 1.2, 0.12), (0.1, 0.9, 0.1), (-0.05, 0.55, 0.09), (0.06, 0.3, 0.07)):
        prism([(x - s, z), (x + s, z + s * 0.6), (x + s * 0.4, z - s)], 0.01, loc=(0, -0.075, 0), m=flint2, bev=0.0)
    cyl(0.13, 0.9, loc=(0, 0, -0.4), m=mat("#6a4628", 0.8, color2="#3e2814", tex="wave", scale=8.0, bump=0.3))
    for i in range(5):
        tube(helix(0.135, 0.07, 1.0, 10, -0.8 + 0.08 * i), 0.028, hidem("#8a5a34", "#5e3a1e"), segs=4)
    for z in (0.05, 0.14, 0.23):
        tube(arc((0, 0, 0), 0.16, 0, 360, 16, plane="xy", y=z)[:-1], 0.025, mat("#e8dcc0", 0.6), segs=4, closed=True)
    lean(-42)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def stone_knife_work():
    blade = [(-0.12, 1.3), (0.3, 1.02), (0.32, 0.12), (-0.26, 0.12), (-0.3, 0.92)]
    prism(blade, 0.18, m=stone("#a7a8a0", "#77786f"), bev=0.03,
          deform=lambda co: co.__setitem__(1, co.y * (1.0 - 0.6 * min(max(co.x, 0) / 0.32, 1.0))))
    _knife_handle(rope_m(), bonem())
    lean(-40)


def barbed_knife():
    bm_ = bonem("#ead9ad")
    pts = arc((-0.9, 0, 0.1), 1.0, 0, 75, 14)
    tube(pts, 0.17, bm_, segs=12, taper=(1.0, 0.06))
    for k in (4, 7, 10):
        p = pts[k]
        cyl(0.07, 0.24, loc=(p[0] - 0.12, 0, p[2] + 0.02), rot=(0, -70 + k * 4, 0), r2=0.0, m=bm_, segs=8)
    _knife_handle(hidem("#7a2e22", "#4a1a12"), wood("#3a2a20", "#24180f"))
    lean(-30)


def club():
    prof = [(0, -1.3), (0.1, -1.27), (0.11, -0.9), (0.12, -0.3), (0.22, 0.3), (0.32, 0.85), (0.35, 1.15),
            (0.28, 1.4), (0, 1.47)]
    lathe(prof, m=wood("#7a5030", "#4e2f17"))
    for i in range(6):
        a = i * 2.1
        z = 0.5 + 0.13 * i
        r = 0.2 + 0.11 * min(i, 4) / 4 + 0.06
        ball(0.075, loc=(r * math.cos(a), r * math.sin(a), z), m=bark("#5b3d24", "#3a2614"), sub=1)
    _grip(-1.22, -0.65, 0.12, hidem("#5a3a22", "#3e2716"))
    lean(-35)


def raid_maul():
    _handle(z0=-1.3, z1=0.95, r=0.1, m=wood("#3d2a1f", "#22160e"))
    lava = mat("#2b2522", 0.75, color2="#46392f", tex="noise", scale=4.0, bump=0.5,
               emit="#ff5a14", emit_strength=9.0, emit_mask=3.0)
    rock(0.62, loc=(0, 0, 1.15), scl=(1.55, 0.95, 0.9), m=lava, jitter=0.12, sub=2)
    iron = metal("#5c6066", 0.4)
    for x in (-0.38, 0.38):
        cyl(0.58, 0.12, loc=(x, 0, 1.15), rot=(0, 90, 0), m=iron, segs=8, bev=0.02, smooth=False)
    for z in (-0.4, 0.2):
        cyl(0.125, 0.09, loc=(0, 0, z), m=iron, segs=12)
    _grip(-1.25, -0.7, 0.115, hidem("#7a2e22", "#4a1a12"))
    lean(-34)


def bone_hammer():
    _handle(z0=-1.25, z1=0.95)
    b = bonem("#d6c59c")
    cyl(0.24, 1.0, loc=(0, 0, 1.12), rot=(0, 90, 0), m=b)
    for x in (-0.55, 0.55):
        for dz in (-0.14, 0.16):
            ball(0.22, loc=(x, 0, 1.12 + dz), m=b, sub=2)
    rp = hidem("#5a3a22", "#3e2716")
    tube([(x, 0, 1.12) for x in (-0.12, 0.12)], 0.27, rp, segs=14)
    _grip(-1.2, -0.6, 0.085, rp)
    lean(-35)


def slingshot():
    b = bonem("#e2d2a8")
    tube([(0, 0, -1.2), (0, 0, -0.1)], 0.11, b, segs=12)
    for s in (-1, 1):
        tube([(0, 0, -0.15), (s * 0.3, 0, 0.35), (s * 0.48, 0, 0.8), (s * 0.5, 0, 1.1)], 0.09, b, segs=10, taper=(1.0, 0.75))
    band = hidem("#6b3d24", "#4a2716")
    tube([(-0.5, 0, 1.02), (-0.25, -0.35, 0.62), (0, -0.5, 0.48), (0.25, -0.35, 0.62), (0.5, 0, 1.02)], 0.035, band, segs=6)
    blob(0.16, loc=(0, -0.5, 0.48), scl=(1.3, 0.6, 0.9), m=band, amp=0.05)
    _grip(-1.15, -0.4, 0.12, hidem("#3a2a20", "#24180f"))
    lean(-12)


def stone_shot():
    m = mat("#9c9a92", 0.6, color2="#6f6d66", tex="noise", scale=5.0, bump=0.25)
    for loc in [(-0.55, 0, 0), (0.55, 0.05, 0), (0, -0.25, 0.05), (0.0, 0.35, 0.75), (-0.05, 0.7, 0.05)]:
        rock(0.5, loc=loc, m=m, jitter=0.05, sub=3, smooth=True)


def _bucket(water=False):
    prof = [(0.0, 0.0), (0.66, 0.0), (0.7, 0.04), (0.84, 1.18), (0.88, 1.24), (0.8, 1.24), (0.66, 0.14), (0.0, 0.14)]
    lathe(prof, m=wood("#a16b3c", "#6e4421"), segs=32)
    iron = metal("#55585c", 0.45)
    for z, r in ((0.25, 0.73), (1.02, 0.84)):
        _ring(z, r, iron, wire=0.035, n=32)
    tube(arc((0, 0, 1.05), 0.86, 0, 180, 18), 0.035, rope_m(), segs=6)
    if water:
        cyl(0.81, 0.02, loc=(0, 0, 1.06), m=mat("#3c8fd8", 0.05, coat=1.0, emit="#2a6fb0", emit_strength=0.4), segs=32)
    turn(-15)
    turn(14, "X")


def empty_bucket():
    _bucket()


def water_bucket():
    _bucket(True)


def _net(rim_m, net_m, weights=None):
    _handle(z0=-1.3, z1=0.55, m=wood("#7a5030", "#4e2f17"))
    R, cz = 0.62, 0.95
    hoop = group(loc=(0.35, 0, cz), rot=(0, 0, 0))
    ring = [(R * math.cos(math.radians(a)), R * math.sin(math.radians(a)) * 0.55, 0.0) for a in range(0, 360, 12)]
    tube(ring, 0.05, rim_m, segs=8, closed=True, parent=hoop)
    depth = 1.15
    for k in range(12):
        a = math.radians(k * 30)
        x0, y0 = R * math.cos(a), R * math.sin(a) * 0.55
        pts = [(x0 * (1 - t * 0.9), y0 * (1 - t * 0.9), -depth * math.sin(t * math.pi / 2)) for t in [i / 8 for i in range(9)]]
        tube(pts, 0.013, net_m, segs=5, parent=hoop)
    for j in range(1, 6):
        t = j / 6
        rr = 1 - t * 0.9
        z = -depth * math.sin(t * math.pi / 2)
        ring2 = [(R * rr * math.cos(math.radians(a)), R * rr * math.sin(math.radians(a)) * 0.55, z) for a in range(0, 360, 15)]
        tube(ring2, 0.013, net_m, segs=5, closed=True, parent=hoop)
    if weights:
        for k in range(6):
            a = math.radians(k * 60 + 30)
            ball(0.07, loc=(R * math.cos(a), R * math.sin(a) * 0.55, -0.02), m=weights, sub=2, parent=hoop)
    turn(20, "X")
    lean(-30)


def capture_net_i():
    _net(wood("#8a5a33", "#5e3a1e"), rope_m("#e2cc94"))


def capture_net_ii():
    """Capture net II: a fine-mesh net on an iron-hooped rim with lead weights and a heavy iron-shod
    handle: the upgraded net, not the plain wooden one (net_i)."""
    _handle(z0=-1.35, z1=0.55, m=mat("#6a4a2a", 0.75, color2="#3e2a16", tex="wave", scale=6.0, bump=0.3))
    iron = mat("#8a9098", 0.3, metal=0.9)
    for z in (-1.2, -0.9):
        cyl(0.12, 0.08, loc=(0, 0, z), m=iron, segs=12)
    cyl(0.1, 0.3, loc=(0, 0, -1.42), r2=0.0, m=iron, segs=8)  # iron shoe
    hoop = group(loc=(0.35, 0, 0.95))
    R = 0.66
    ring = [(R * math.cos(math.radians(a)), R * math.sin(math.radians(a)) * 0.55, 0.0) for a in range(0, 360, 10)]
    tube(ring, 0.06, iron, segs=8, closed=True, parent=hoop)
    mesh = mat("#e8e2cc", 0.85, color2="#c4bca0", tex="noise", scale=30.0, bump=0.3)
    depth = 1.25
    for k in range(18):
        a = math.radians(k * 20)
        x0, y0 = R * math.cos(a), R * math.sin(a) * 0.55
        pts = [(x0 * (1 - t * 0.92), y0 * (1 - t * 0.92), -depth * math.sin(t * math.pi / 2))
               for t in [i / 8 for i in range(9)]]
        tube(pts, 0.012, mesh, segs=4, parent=hoop)
    for j in range(1, 6):
        t = j / 6
        rr = 1 - t * 0.92
        z = -depth * math.sin(t * math.pi / 2)
        ring2 = [(R * rr * math.cos(math.radians(a)), R * rr * math.sin(math.radians(a)) * 0.55, z)
                 for a in range(0, 360, 15)]
        tube(ring2, 0.012, mesh, segs=4, closed=True, parent=hoop)
    lead = mat("#4a4e56", 0.35, metal=0.8)
    for k in range(10):
        a = math.radians(k * 36)
        ball(0.08, loc=(R * 0.97 * math.cos(a), R * 0.97 * math.sin(a) * 0.55, -0.06), m=lead, sub=2, parent=hoop)
    turn(20, "X")
    lean(-30)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)
def raid_helm():
    """Raid hide helm: a raider's war helm: a shaped hide skull with a bone brow band, a red-dyed
    plume crest, two bone horns and riveted cheek plates. Armour only, no head inside."""
    h = hidem("#8a4a26", "#5a2c12")
    bone = bonem("#e4d6b0")
    # Skull: a domed cap with a brow ridge and a nose guard, open at the neck.
    lathe([(0, 1.05), (0.4, 1.0), (0.66, 0.86), (0.82, 0.6), (0.86, 0.28), (0.84, 0.0), (0.78, -0.05), (0.76, 0.25),
           (0.7, 0.55), (0.58, 0.78), (0.35, 0.9), (0, 0.94)], m=h, segs=32)
    # Brow band: a bone strip round the front rim.
    tube(arc((0, 0, 0), 0.84, 200, 340, 16, plane="xz", y=0.1), 0.06, bone, segs=6)
    for k in range(5):
        a = math.radians(215 + 25 * k)
        ball(0.05, loc=(0.84 * math.cos(a), 0.1, 0.84 * math.sin(a)), m=metal("#8a8f96", 0.35), sub=2)
    # Red plume crest: a fan of dyed hide strips over the top, back to front.
    plume = hidem("#a82a24", "#6a1410")
    for k in range(5):
        x = -0.16 + 0.08 * k
        tube([(x, 0.1, 1.02), (x * 1.2, 0.0, 1.32), (x * 1.6, -0.15, 1.55 - 0.06 * abs(k - 2))], 0.05, plume, segs=5,
             taper=(1.0, 0.4))
    # Two bone horns, curved up and out, each with an iron ferrule.
    for s in (-1, 1):
        pts = arc((s * 0.72, 0.0, 0.68), 0.5, 200 if s < 0 else -20, 90 if s < 0 else 160, 12, plane="xz")
        tube(pts, 0.13, bone, segs=10, taper=(1.0, 0.12))
        cyl(0.15, 0.1, loc=(s * 0.74, 0, 0.7), rot=(0, 0, 0), m=metal("#7a7f86", 0.4), segs=10)
    # Cheek plates: hide flaps with bone studs, hanging from the rim.
    for s in (-1, 1):
        g = group(loc=(s * 0.8, 0.05, 0.05), rot=(0, 0, s * 18))
        prism([(-0.14, 0.2), (0.16, 0.25), (0.2, -0.35), (0.05, -0.55), (-0.16, -0.5), (-0.2, 0.0)], 0.06, m=h,
              bev=0.02, parent=g)
        for z in (0.05, -0.25):
            ball(0.05, loc=(0, -0.04, z), m=bone, sub=2, parent=g)
    # A nose guard.
    box((0.12, 0.1, 0.4), loc=(0, -0.82, 0.55), rot=(8, 0, 0), m=bone, bev=0.02)
    turn(-18)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def raid_cuirass():
    """Raid hide cuirass: a shaped raider's vest of layered hide lames with iron collar studs, a bone
    spine guard and a red-dyed border: armour only, no body parts."""
    h = hidem("#8a4a26", "#5a2c12")
    h2 = hidem("#a85c30", "#6e3416")
    bone = bonem("#e4d6b0")
    iron = metal("#7a7f86", 0.4)
    trim = hidem("#a82a24", "#6a1410")
    for i in range(4):  # four horizontal lames: overlapping curved plates, wider at the bottom
        w = 0.62 + 0.06 * i
        z = 0.62 - 0.32 * i
        pts = [(-w, 0.3), (-w * 0.92, 0.42), (0, 0.46), (w * 0.92, 0.42), (w, 0.3), (w * 0.86, 0.0),
               (w * 0.7, -0.18), (-w * 0.7, -0.18), (-w * 0.86, 0.0)]
        g = group(loc=(0, 0.1 + 0.03 * i, z))
        prism(pts, 0.16, m=h if i % 2 else h2, bev=0.04, parent=g,
              deform=lambda co: co.__setitem__(1, co.y + 0.5 * co.x * co.x + 0.25 * co.z * co.z))
        # A red-dyed border strip along each lame's lower edge, and a bone stud on each end.
        tube([(-w * 0.95, 0.16, 0.06), (0, 0.2, 0.08), (w * 0.95, 0.16, 0.06)], 0.04, trim, segs=5, parent=g)
        for s in (-1, 1):
            ball(0.05, loc=(s * w * 0.8, 0.18, 0.05), m=bone, sub=2, parent=g)
    # Collar: two hide straps over the shoulders with iron studs.
    for s in (-1, 1):
        tube(arc((s * 0.45, 0.1, 0.72), 0.28, -20 if s > 0 else 200, 90 if s > 0 else 270, 10, plane="xz"),
             0.09, h, segs=6, taper=(1.0, 0.8))
        for k in range(3):
            ball(0.045, loc=(s * 0.5, 0.02, 0.8 + 0.08 * k), m=iron, sub=2)
    # Spine guard: a row of bone plates up the back centre.
    for k in range(4):
        blob(0.11, loc=(0, 0.3, 0.5 - 0.28 * k), scl=(0.8, 0.5, 1.3), m=bone, amp=0.06)
    turn(-14)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def raid_greaves():
    """Raid hide greaves: two hide shin guards with layered lames, a bone knee cap on each, iron
    buckle straps and a red-dyed trim: the pair, one behind the other, armour only."""
    h = hidem("#8a4a26", "#5a2c12")
    h2 = hidem("#a85c30", "#6e3416")
    bone = bonem("#e4d6b0")
    iron = metal("#7a7f86", 0.4)
    trim = hidem("#a82a24", "#6a1410")
    for s, dy in ((-1, 0.28), (1, -0.05)):
        g = group(loc=(s * 0.36, dy, 0), rot=(0, s * -4, 0))
        for i in range(3):  # three lames down the shin, front-facing
            z = 0.28 - 0.42 * i
            w = 0.34 + 0.04 * i
            prism([(-w, 0.22), (-w * 0.8, 0.34), (w * 0.8, 0.34), (w, 0.22), (w * 0.85, -0.2), (-w * 0.85, -0.2)],
                  0.14, loc=(0, 0, z), m=h if i % 2 else h2, bev=0.04, parent=g,
                  deform=lambda co: co.__setitem__(1, co.y + 0.8 * co.x * co.x))
            tube([(-w * 0.9, 0.14, z - 0.18), (0, 0.18, z - 0.17), (w * 0.9, 0.14, z - 0.18)], 0.03, trim, segs=5,
                 parent=g)
        # The knee cap: a bone dome sitting over the top lame.
        lathe([(0, 0.0), (0.3, 0.0), (0.34, 0.12), (0.28, 0.26), (0, 0.3)], loc=(0, 0.05, 0.55), rot=(80, 0, 0),
              m=bone, segs=18, parent=g)
        # Straps: hide straps round the back, each with an iron buckle.
        for z in (-0.55, 0.2):
            tube(arc((0, 0.05, z), 0.38, 0, 360, 22, plane="xy")[:-1], 0.05, hidem("#5a2c12", "#3a1a08"), segs=5,
                 closed=True, parent=g)
            box((0.12, 0.1, 0.1), loc=(0.3, 0.28, z), m=iron, bev=0.02, parent=g)
    turn(-12)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


# ---------------------------------------------------------------- ICONS4: the metal and bone tool tiers
# One builder per tool kind, one blade material per tier: the silhouette says knife/axe/pick/spear/
# sword, the blade colour says flint/obsidian/copper/bronze/iron/steel/bone. Handles stay wood (bone
# for the bone set), the grips and lashings reuse _grip / _ring / rope_m so the tools match the ones
# ICONS2 landed.

def _flint_m():
    """Knapped flint: pale honey-grey with flake scars (stone_knife's blade)."""
    return mat("#c8bfa4", 0.35, color2="#a09472", tex="voronoi", scale=6.0, bump=0.25, spec=0.5)


def _obsidian_m():
    """Obsidian blade: black glass with a violet sheen and a bright chipped edge."""
    return mat("#1e1c26", 0.05, color2="#3e3852", tex="voronoi", scale=7.0, bump=0.12, coat=1.0, spec=0.9,
               emit="#6a5aa0", emit_strength=0.3)


BLADES = {
    "flint": lambda: _flint_m(),
    "obsidian": lambda: _obsidian_m(),
    "copper": lambda: metal("#d07a3e", 0.28),
    "bronze": lambda: metal("#c99a3e", 0.3),
    "iron": lambda: mat("#6a6e74", 0.45, metal=0.85, color2="#4a4e54", tex="noise", scale=12.0, bump=0.35),
    "steel": lambda: mat("#dfe8f2", 0.12, metal=0.95, color2="#8fa0b4", tex="noise", scale=6.0, bump=0.04),
    "bone": lambda: bonem("#e4d6b0"),
}


def _tool_handle(z0, z1, core=None, wrap=None, r=0.075):
    """Straight tool handle with a bound grip and a butt knob (the _handle bend is for the stone set)."""
    core = core or wood("#6e4626", "#4a2d16")
    cyl(r, z1 - z0, loc=(0, 0, (z0 + z1) / 2), m=core)
    ball(r * 1.25, loc=(0, 0, z0), m=core, sub=2)
    if wrap:
        _grip(z0 + 0.12, z0 + (z1 - z0) * 0.55, r * 1.05, wrap, pitch=0.06)


def _knife(m, edge, handle_m=None, wrap_m=None):
    """Blade with a flat spine and a raised edge bevel, a bolster and a bound grip."""
    blade = [(0.0, 1.8), (0.2, 1.36), (0.26, 0.8), (0.2, 0.14), (-0.2, 0.14), (-0.24, 0.8), (-0.14, 1.34)]
    prism(blade, 0.14, m=m, bev=0.018,
          deform=lambda co: co.__setitem__(1, co.y * (1.0 - 0.78 * min(abs(co.x) / 0.26, 1.0))))
    if edge:  # a brighter line down each cheek, so the bevel reads at slot size
        for s in (-1, 1):
            tube([(s * 0.2, -0.02, 0.24), (s * 0.24, -0.02, 0.8), (s * 0.17, -0.02, 1.3), (0.0, -0.02, 1.76)],
                 0.016, edge, segs=4)
    box((0.26, 0.16, 0.09), loc=(0, 0, 0.1), m=m, bev=0.015)  # bolster
    _tool_handle(-0.85, 0.08, core=handle_m, wrap=wrap_m or hidem("#5a3a22", "#3e2716"), r=0.095)
    lean(-42)
    upright()


def _axe(m, edge, handle_m=None):
    """Axe: wood haft, a wedge head with a bright honed edge and a poll behind the eye."""
    haft = handle_m or wood("#8a5a33", "#5e3a1e")
    tube([(0, 0, -1.3), (0.03, 0, -0.4), (-0.02, 0, 0.5), (0.02, 0, 1.05)], 0.08, haft, segs=10)
    head = [(-0.2, 0.86), (0.18, 0.8), (0.52, 0.66), (0.78, 0.56), (0.86, 0.98), (0.76, 1.36), (0.5, 1.3),
            (0.18, 1.12), (-0.2, 1.04)]
    prism(head, 0.22, m=m, bev=0.025, deform=_thin_edge(0.2, 0.86, 0.22))
    if edge:
        tube([(0.8, 0.0, 0.6), (0.87, 0.0, 0.98), (0.78, 0.0, 1.34)], 0.022, edge, segs=4)
    box((0.24, 0.24, 0.34), loc=(-0.1, 0, 0.92), m=m, bev=0.02)  # poll
    rp = rope_m()
    for z in (0.84, 0.92, 1.0):
        _ring(z, 0.1, rp)
    _grip(-1.22, -0.6, 0.088, hidem("#5a3a22", "#3e2716"))
    lean(-36)
    upright()


def _pick(m, edge, handle_m=None):
    """Pick: wood haft, a curved double head tapering to two points."""
    haft = handle_m or wood("#8a5a33", "#5e3a1e")
    tube([(0, 0, -1.25), (0.03, 0, -0.3), (-0.02, 0, 0.6), (0.0, 0, 0.95)], 0.08, haft, segs=10)
    tube(arc((0, 0, 0.1), 1.0, 90, 152, 10), 0.125, m, segs=10, taper=(1.0, 0.1))
    tube(arc((0, 0, 0.1), 1.0, 90, 28, 10), 0.125, m, segs=10, taper=(1.0, 0.1))
    if edge:
        for a, b in ((90, 152), (90, 28)):
            p = arc((0, 0, 0.1), 1.0, a, b, 10)
            tube(p, 0.02, edge, segs=4)
    rp = rope_m()
    for z in (0.86, 0.94, 1.02):
        _ring(z, 0.105, rp)
    _grip(-1.18, -0.55, 0.088, hidem("#5a3a22", "#3e2716"))
    lean(-30)
    upright()


def _spear(m, edge, handle_m=None, bone=False):
    """Spear: a long shaft with the head socketed on, two lashings and a butt cap."""
    haft = handle_m or wood("#8a5a33", "#5e3a1e")
    tube([(0, 0, -1.55), (0.02, 0, -0.2), (-0.02, 0, 0.85), (0.0, 0, 1.05)], 0.07, haft, segs=10)
    head = [(0.0, 2.15), (0.19, 1.72), (0.26, 1.3), (0.2, 0.98), (-0.2, 0.98), (-0.24, 1.32), (-0.15, 1.74)]
    prism(head, 0.12, m=m, bev=0.016,
          deform=lambda co: co.__setitem__(1, co.y * (1.0 - 0.8 * min(abs(co.x) / 0.26, 1.0))))
    if edge:
        for s in (-1, 1):
            tube([(s * 0.2, -0.02, 1.02), (s * 0.25, -0.02, 1.32), (s * 0.17, -0.02, 1.74), (0.0, -0.02, 2.1)],
                 0.014, edge, segs=4)
    cyl(0.1, 0.3, loc=(0, 0, 0.98), r2=0.075, m=m if not bone else m, segs=10)  # socket
    if bone:  # a bone spear is lashed on, not socketed in iron
        for z in (0.95, 1.04, 1.13):
            _ring(z, 0.095, rope_m())
    else:
        for z in (0.94, 1.02):
            _ring(z, 0.085, rope_m())
    _grip(-1.35, -0.75, 0.08, hidem("#5a3a22", "#3e2716"))
    lean(-22)
    upright()


def _sword(m, edge, handle_m=None):
    """Sword: a long double-edged blade, a crossguard, a bound grip and a pommel."""
    blade = [(0.0, 2.05), (0.16, 1.66), (0.2, 0.9), (0.18, 0.24), (-0.18, 0.24), (-0.21, 0.9), (-0.14, 1.68)]
    prism(blade, 0.1, m=m, bev=0.014,
          deform=lambda co: co.__setitem__(1, co.y * (1.0 - 0.82 * min(abs(co.x) / 0.21, 1.0))))
    if edge:
        for s in (-1, 1):
            tube([(s * 0.16, -0.02, 0.3), (s * 0.2, -0.02, 0.9), (s * 0.15, -0.02, 1.7), (0.0, -0.02, 2.0)],
                 0.014, edge, segs=4)
    box((0.72, 0.14, 0.1), loc=(0, 0, 0.18), m=m, bev=0.02, taper=(0.9, 0.9))  # crossguard
    _tool_handle(-0.62, 0.14, core=handle_m, wrap=hidem("#4a2a18", "#2e1a0c"), r=0.085)
    ball(0.14, loc=(0, 0, -0.68), scl=(1.0, 0.8, 0.9), m=m, sub=2)  # pommel
    lean(-30)
    upright()


def _edge_m(m_name):
    """The bright honed line down a blade: pale for stone, near-white for steel."""
    return {"flint": "#efe6cc", "obsidian": "#a89ad0", "copper": "#f0a878", "bronze": "#f2d48a",
            "iron": "#b8bec4", "steel": "#ffffff", "bone": "#f8f0d8"}[m_name]


def _tier(kind, name, short):
    """Make one tool of the tier: knife/axe/pick/spear/sword x flint/obsidian/copper/bronze/iron/
    steel/bone. Handles are wood, except the bone set's (bone hafts, lashed heads)."""
    m = BLADES[name]()
    edge = mat(_edge_m(name), 0.1 if name in ("obsidian", "steel") else 0.35, metal=0.9 if name not in
               ("flint", "obsidian", "bone") else 0.0,
               color2=_edge_m(name), tex="noise", scale=6.0, coat=0.6 if name in ("obsidian", "steel") else 0.0,
               spec=0.7)
    bone = name == "bone"
    handle = bonem("#d6c59c") if bone else None
    {"knife": _knife, "axe": _axe, "pick": _pick, "spear": _spear, "sword": _sword}[kind](m, edge, handle)


# One thin wrapper per id: the registry maps ids to builders, so each id has its own function.
def flint_knife():
    """Flint knife: a knapped flint blade lashed on a bound wood handle."""
    _tier("knife", "flint", "flint")


def flint_axe():
    """Flint axe: a chipped flint wedge lashed to the haft, with a rope binding at the eye."""
    _tier("axe", "flint", "flint")


def flint_pick():
    """Flint pick: two chipped flint points on a curved head, bound to the haft."""
    _tier("pick", "flint", "flint")


def flint_spear():
    """Flint spear: a knapped leaf point lashed into the shaft's split end."""
    _tier("spear", "flint", "flint")


def obsidian_knife():
    """Obsidian knife: a black glass blade with a violet sheen on a bound handle."""
    _tier("knife", "obsidian", "obsidian")


def obsidian_axe():
    """Obsidian axe: a black glass wedge, its honed edge pale against the dark blade."""
    _tier("axe", "obsidian", "obsidian")


def obsidian_pick():
    """Obsidian pick: two black glass points on a curved head, bound to the haft."""
    _tier("pick", "obsidian", "obsidian")


def obsidian_spear():
    """Obsidian spear: a black glass leaf point socketed on the shaft."""
    _tier("spear", "obsidian", "obsidian")


def copper_knife():
    """Copper knife: soft orange metal, a short wide blade with a bolster."""
    _tier("knife", "copper", "copper")


def copper_axe():
    """Copper axe: a cast copper wedge head on a wood haft with a rope binding."""
    _tier("axe", "copper", "copper")


def copper_pick():
    """Copper pick: a cast copper double head on a wood haft."""
    _tier("pick", "copper", "copper")


def copper_sword():
    """Copper sword: a broad cast blade, short crossguard and bound grip."""
    _tier("sword", "copper", "copper")


def bronze_knife():
    """Bronze knife: warmer, harder bronze than copper, the same shape."""
    _tier("knife", "bronze", "bronze")


def bronze_axe():
    """Bronze axe: a bronze wedge head with a poll and a honed edge."""
    _tier("axe", "bronze", "bronze")


def bronze_pick():
    """Bronze pick: a bronze double head on a wood haft."""
    _tier("pick", "bronze", "bronze")


def bronze_sword():
    """Bronze sword: a long bronze blade with a crossguard."""
    _tier("sword", "bronze", "bronze")


def iron_knife():
    """Iron knife: a dark, mottled iron blade with a bright edge, iron bolster."""
    _tier("knife", "iron", "iron")


def iron_axe():
    """Iron axe: a dark iron wedge head, honed edge, poll behind the eye."""
    _tier("axe", "iron", "iron")


def iron_pick():
    """Iron pick: a dark iron double head on a wood haft."""
    _tier("pick", "iron", "iron")


def iron_sword():
    """Iron sword: a long dark blade with a steel-bright honed edge and an iron guard."""
    _tier("sword", "iron", "iron")


def steel_knife():
    """Steel knife: polished steel, the edge near white, the bolster and pommel the same steel."""
    _tier("knife", "steel", "steel")


def steel_axe():
    """Steel axe: a polished steel head with a horn and a wide honed bit."""
    _tier("axe", "steel", "steel")


def steel_pick():
    """Steel pick: a polished steel double head on a wood haft."""
    _tier("pick", "steel", "steel")


def steel_sword():
    """Steel sword: a long polished blade, bright edge, steel crossguard and pommel."""
    _tier("sword", "steel", "steel")


def bone_knife():
    """Bone knife: a flat bone blade with a lashed bone handle (barbed_knife's material family)."""
    _tier("knife", "bone", "bone")


def bone_axe():
    """Bone axe: a heavy bone wedge lashed to a bone haft."""
    _tier("axe", "bone", "bone")


def bone_pick():
    """Bone pick: a curved bone head with two worn points on a bone haft."""
    _tier("pick", "bone", "bone")


def bone_spear():
    """Bone spear: a long bone point lashed into a bone shaft."""
    _tier("spear", "bone", "bone")


# ---------------------------------------------------------------- ICONS4: capture nets III-V
# _net and capture_net_ii set the shape; the tiers differ by rim metal, mesh fineness and weights,
# so each reads as an upgrade of the one before.

def _capture_net(tier, rim_m, mesh_m, weight_m, weights, fine):
    _handle(z0=-1.35, z1=0.55, m=wood("#6a4a2a", "#3e2a16"))
    for z in (-1.22, -0.92):
        cyl(0.12, 0.08, loc=(0, 0, z), m=rim_m, segs=12)
    hoop = group(loc=(0.35, 0, 0.95))
    R = 0.66
    ring = [(R * math.cos(math.radians(a)), R * math.sin(math.radians(a)) * 0.55, 0.0) for a in range(0, 360, 10)]
    tube(ring, 0.062, rim_m, segs=8, closed=True, parent=hoop)
    depth = 1.25
    for k in range(fine):
        a = math.radians(k * 360.0 / fine)
        x0, y0 = R * math.cos(a), R * math.sin(a) * 0.55
        pts = [(x0 * (1 - t * 0.92), y0 * (1 - t * 0.92), -depth * math.sin(t * math.pi / 2))
               for t in [i / 8 for i in range(9)]]
        tube(pts, 0.012 if tier > 3 else 0.014, mesh_m, segs=4, parent=hoop)
    for j in range(1, 6):
        t = j / 6
        rr = 1 - t * 0.92
        z = -depth * math.sin(t * math.pi / 2)
        ring2 = [(R * rr * math.cos(math.radians(a)), R * rr * math.sin(math.radians(a)) * 0.55, z)
                 for a in range(0, 360, 15 if tier < 5 else 12)]
        tube(ring2, 0.012, mesh_m, segs=4, closed=True, parent=hoop)
    for k in range(weights):
        a = math.radians(k * 360.0 / weights)
        ball(0.075, loc=(R * 0.97 * math.cos(a), R * 0.97 * math.sin(a) * 0.55, -0.06), m=weight_m, sub=2,
             parent=hoop)
    if tier >= 4:  # a reinforced outer rim band
        tube([(R * 1.02 * math.cos(math.radians(a)), R * 1.02 * math.sin(math.radians(a)) * 0.55, 0.05)
              for a in range(0, 360, 10)], 0.03, rim_m, segs=6, closed=True, parent=hoop)
    if tier >= 5:  # a small ring of studs on the rim, the top tier's mark
        for k in range(8):
            a = math.radians(k * 45 + 22)
            ball(0.05, loc=(R * 1.02 * math.cos(a), R * 1.02 * math.sin(a) * 0.55, 0.08), m=weight_m, sub=2,
                 parent=hoop)
    turn(20, "X")
    lean(-30)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def capture_net_iii():
    """Capture net III: a bronze-hooped net, its mesh finer than the plain nets, bronze weights."""
    _capture_net(3, metal("#c99a3e", 0.3), mat("#efe8d0", 0.85, color2="#cdc2a0", tex="noise", scale=30.0,
                                                 bump=0.3), metal("#a87a2e", 0.4), 10, 20)


def capture_net_iv():
    """Capture net IV: an iron-hooped net with a reinforced rim band, finer mesh and more lead."""
    _capture_net(4, mat("#8a9098", 0.3, metal=0.9), mat("#e8e2cc", 0.85, color2="#c4bca0", tex="noise",
                                                         scale=34.0, bump=0.3), mat("#4a4e56", 0.35, metal=0.8),
                 12, 24)


def capture_net_v():
    """Capture net V: a polished steel hoop with a rim band and studs, the finest mesh and steel
    weights (the top tier)."""
    _capture_net(5, mat("#dfe8f2", 0.12, metal=0.95, color2="#8fa0b4", tex="noise", scale=6.0, bump=0.04),
                 mat("#f4f0e4", 0.85, color2="#d4ccb4", tex="noise", scale=38.0, bump=0.25),
                 mat("#b8c0c8", 0.2, metal=0.95), 14, 30)


# ---------------------------------------------------------------- ICONS4: armour tiers + bags
# Five materials x four slots. Each slot keeps one silhouette across its tiers (so a helm always reads
# as a helm) and the material carries the tier: leather is stitched hide lames with bone studs, the
# metals are riveted plate in the same palette as their ingots. No body parts, no head inside a helm
# (the raid_* set is the hidden "raider" variant).

ARMOUR = {
    "leather": lambda: hidem("#8a5a32", "#5e3a1e"),
    "copper": lambda: metal("#d07a3e", 0.3),
    "bronze": lambda: metal("#c99a3e", 0.3),
    "iron": lambda: mat("#6a6e74", 0.45, metal=0.85, color2="#4a4e54", tex="noise", scale=12.0, bump=0.3),
    "steel": lambda: mat("#dfe8f2", 0.12, metal=0.95, color2="#8fa0b4", tex="noise", scale=6.0, bump=0.04),
}


def _armour_helm(name):
    """Helm: a domed cap with a studded rim band round its base, a crown band arching front-to-back
    over the top and a nasal hung from the rim: the two crossing bands are what read as a helmet at
    slot size (a bare dome reads as a bowl and hanging cheek flaps read as legs). No head inside;
    the raid_* helm is the hidden "raider" variant."""
    m = ARMOUR[name]()
    lea = name == "leather"
    trim = bonem("#e4d6b0") if lea else mat("#c8d0d8", 0.3, metal=0.9)
    stud = bonem("#e4d6b0") if lea else mat("#b8c0c8", 0.25, metal=0.9)
    # Skull: a dome with a slight outward flare at the rim, open at the neck.
    lathe([(0, 1.04), (0.4, 0.99), (0.64, 0.88), (0.8, 0.64), (0.9, 0.36), (0.96, 0.14), (1.0, 0.02),
           (0.9, -0.02), (0.86, 0.16), (0.78, 0.38), (0.68, 0.64), (0.52, 0.84), (0.3, 0.96), (0, 1.0)],
          m=m, segs=32)
    # Rim band round the base.
    rim = [(0.92 * math.cos(math.radians(a)), 0.92 * math.sin(math.radians(a)), 0.07) for a in range(0, 360, 12)]
    tube(rim, 0.075, trim, segs=6, closed=True)
    for k in range(8):
        a = math.radians(k * 45 + 18)
        ball(0.04, loc=(0.95 * math.cos(a), 0.95 * math.sin(a), 0.09), m=stud, sub=2)
    # Crown band: a wide strip over the dome, front rim to back rim, proud of the surface.
    prof = [(0.0, 1.04), (0.4, 0.99), (0.64, 0.88), (0.8, 0.64), (0.9, 0.36), (0.96, 0.14), (1.0, 0.02)]
    outer, inner = [], []
    for (r, z) in prof:
        d = math.hypot(r, z - (-0.02)) or 1.0
        ux, uz = r / d, (z + 0.02) / d
        outer.append((r + 0.05 * ux, z + 0.05 * uz))
        inner.append((r - 0.07 * ux, z - 0.07 * uz))
    band = [(y, z) for (y, z) in outer] + [(y, z) for (y, z) in reversed(inner)]
    band = band + [(-y, z) for (y, z) in reversed(band)]  # mirror to the other half of the arch
    prism(band, 0.17, rot=(0, 0, 90), m=trim, bev=0.01)
    # Nasal: a plate hung from the front of the rim band, angled out over the face.
    prism([(-0.1, 0.12), (0.1, 0.12), (0.085, -0.34), (0.0, -0.46), (-0.085, -0.34)], 0.09,
          loc=(0, -0.9, 0.02), rot=(8, 0, 0), m=trim, bev=0.012)
    if lea:  # stitched seam down each side of the crown band
        for sgn in (-1, 1):
            for z in (0.9, 0.78, 0.62):
                tube([(sgn * 0.12, -0.32 + 0.2 * (0.9 - z), z), (sgn * 0.16, -0.3 + 0.2 * (0.9 - z), z + 0.03)],
                     0.014, mat("#e8dcc0", 0.85), segs=4)
    turn(-16)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def _armour_cuirass(name):
    """Cuirass: a breastplate seen face-on, its chest plane bulged toward the camera, a neck notch,
    three lames stepped across the waist and shoulder straps with studs: leather is stitched hide,
    metal is riveted plate (the same material as its ingot)."""
    m = ARMOUR[name]()
    lea = name == "leather"
    stud = bonem("#e4d6b0") if lea else mat("#b8c0c8", 0.25, metal=0.9)
    seam = mat("#e8dcc0", 0.85) if lea else mat("#c8d0d8", 0.25, metal=0.9)
    bulge = 0.55

    def front(co):
        co.y -= bulge * co.x * co.x + 0.18 * co.z * co.z
    # Chest plate: a tall shield outline with a neck notch and armholes.
    chest = [(-0.72, 0.62), (-0.5, 0.86), (-0.24, 0.9), (-0.16, 0.72), (0.16, 0.72), (0.24, 0.9), (0.5, 0.86),
             (0.72, 0.62), (0.68, 0.1), (0.62, -0.3), (0.0, -0.44), (-0.62, -0.3), (-0.68, 0.1)]
    prism(chest, 0.22, m=m, bev=0.03, deform=front)
    # Three lames across the waist, each a little wider, stepped forward.
    for i in range(3):
        w = 0.6 + 0.04 * i
        z = -0.16 - 0.16 * i
        lame = [(-w, z + 0.09), (-w * 0.9, z + 0.13), (0, z + 0.15), (w * 0.9, z + 0.13), (w, z + 0.09),
                (w * 0.86, z - 0.08), (0, z - 0.1), (-w * 0.86, z - 0.08)]
        prism(lame, 0.2, m=m, bev=0.025, deform=front)
        for sgn in (-1, 1):
            ball(0.045, loc=(sgn * w * 0.78, -0.22 - bulge * (w * 0.78) ** 2, z + 0.02), m=stud, sub=2)
    # Shoulder straps: two thick loops over the top, each with a stud.
    for sgn in (-1, 1):
        tube(arc((sgn * 0.46, 0.0, 0.82), 0.26, 150 if sgn < 0 else -30, 250 if sgn < 0 else 30, 10, plane="xz"),
             0.055, m, segs=6, taper=(1.0, 0.85))
        for k in range(2):
            ball(0.04, loc=(sgn * 0.5, -0.1, 0.98 - 0.1 * k), m=stud, sub=2)
    if lea:  # stitched seams: two rows of stitches down the chest and one round the lames
        for z in (0.5, 0.3, 0.1):
            for sgn in (-1, 1):
                tube([(sgn * 0.3, -0.05 - bulge * 0.09, z), (sgn * 0.36, -0.05 - bulge * 0.13, z + 0.03)],
                     0.014, seam, segs=4)
    else:  # a ridge down the centre and a riveted border: the plate read
        tube([(0, -0.05, 0.66), (0, -0.05 - bulge * 0.0, 0.1), (0, -0.05, -0.42)], 0.035, seam, segs=4)
        for (x, z) in ((-0.6, 0.5), (-0.62, 0.1), (0.6, 0.5), (0.62, 0.1), (-0.4, 0.74), (0.4, 0.74)):
            ball(0.04, loc=(x, -0.05 - bulge * x * x, z), m=stud, sub=2)
    turn(-8)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def _armour_bracers(name):
    """Bracers: one vambrace seen side-on: a tapered shell, wide flared cuff at the elbow and narrow
    at the wrist, its inner face dark and visible at the wide end, two buckled straps. One arm, not
    a floating pair (the ICONS2 lesson for worn arm pieces)."""
    m = ARMOUR[name]()
    lea = name == "leather"
    stud = bonem("#e4d6b0") if lea else mat("#b8c0c8", 0.25, metal=0.9)
    seam = mat("#e8dcc0", 0.85) if lea else mat("#c8d0d8", 0.25, metal=0.9)
    dark = mat("#241a10", 1.0)  # the shadowed inside of the cuff
    bulge = 0.45

    def cupped(co):
        co.y -= bulge * co.x * co.x
    # Outline: tall at the elbow end (+Z), tapering to the wrist (-Z), the cuff flared outward.
    shell = [(-0.62, 0.95), (0.62, 0.95), (0.52, 0.78), (0.4, 0.2), (0.3, -0.6), (0.36, -0.72),
             (-0.36, -0.72), (-0.3, -0.6), (-0.4, 0.2), (-0.52, 0.78)]
    prism(shell, 0.3, m=m, bev=0.03, deform=cupped)
    # The cuff's inner face, recessed and dark, so the wide end reads open.
    prism([(-0.5, 0.94), (0.5, 0.94), (0.44, 0.8), (-0.44, 0.8)], 0.2,
          loc=(0, -0.03, 0.0), m=dark, bev=0.0, deform=cupped)
    # Rolled lips on both ends.
    for (z, w, r) in ((0.95, 0.62, 0.055), (-0.72, 0.36, 0.045)):
        tube([(-w + 2 * w * i / 12, -bulge * (-w + 2 * w * i / 12) ** 2, z) for i in range(13)], r, m, segs=6)
    # Two straps with proud buckles, and the seam.
    for z in (0.35, -0.2):
        w = 0.44 - 0.08 * (0.35 - z)
        tube([(-w * 1.06 + 2 * w * 1.06 * i / 14,
               -bulge * (-w * 1.06 + 2 * w * 1.06 * i / 14) ** 2 - 0.02, z) for i in range(15)], 0.038,
             mat("#3e2412", 0.9) if lea else hidem("#4a2a16", "#2e1a0c"), segs=5)
        box((0.17, 0.13, 0.1), loc=(w * 1.1, -bulge * (w * 1.1) ** 2 - 0.06, z), m=stud, bev=0.02)
    if lea:  # cross-stitches down the seam
        for z in (0.6, 0.1, -0.4):
            tube([(-0.07, -0.05, z), (0.07, -0.05, z + 0.05)], 0.015, seam, segs=4)
    else:  # a riveted seam line
        for z in (0.6, 0.1, -0.4):
            ball(0.038, loc=(0.0, -0.06, z), m=stud, sub=2)
    turn(-16)
    lean(-30)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def _armour_greaves(name):
    """Greaves: one shin guard: a tall curved plate covering the front of the shin (its edges roll
    back, the leg side is open), a knee cop sitting on top and two buckled straps. A single leg
    piece, taller and narrower than a bracer; the raid pair is the hidden variant."""
    m = ARMOUR[name]()
    lea = name == "leather"
    stud = bonem("#e4d6b0") if lea else mat("#b8c0c8", 0.25, metal=0.9)
    seam = mat("#e8dcc0", 0.85) if lea else mat("#c8d0d8", 0.25, metal=0.9)
    bulge = 0.5

    def shell_bend(co):
        co.y -= bulge * co.x * co.x
    # Tall plate, wider at the knee, tapering to the ankle, its sides rolled back.
    plate = [(-0.5, 1.15), (0.5, 1.15), (0.56, 0.95), (0.46, 0.2), (0.36, -0.75), (0.24, -1.05),
             (-0.24, -1.05), (-0.36, -0.75), (-0.46, 0.2), (-0.56, 0.95)]
    prism(plate, 0.26, m=m, bev=0.03, deform=shell_bend)
    # Rolled edges down both sides, so the plate reads as bent sheet rather than a box.
    for sgn in (-1, 1):
        pts = [(sgn * 0.5, -bulge * 0.25, 1.15), (sgn * 0.56, -bulge * 0.31, 0.95),
               (sgn * 0.46, -bulge * 0.21, 0.2), (sgn * 0.36, -bulge * 0.13, -0.75),
               (sgn * 0.24, -bulge * 0.058, -1.05)]
        tube(pts, 0.045, m, segs=6)
    # Knee cop: a dome over the top edge.
    lathe([(0, 0.0), (0.3, 0.0), (0.34, 0.12), (0.26, 0.26), (0, 0.3)], loc=(0, 0.05, 1.13), rot=(84, 0, 0), m=m,
          segs=18)
    # Straps and buckles, the buckle standing proud of the plate's curve.
    for z in (0.5, -0.35):
        w = 0.5 - 0.06 * (0.5 - z)
        tube([(-w * 1.06 + 2 * w * 1.06 * i / 14,
               -bulge * (-w * 1.06 + 2 * w * 1.06 * i / 14) ** 2 - 0.02, z) for i in range(15)], 0.04,
             mat("#3e2412", 0.9) if lea else hidem("#4a2a16", "#2e1a0c"), segs=5)
        box((0.18, 0.13, 0.11), loc=(w * 1.1, -bulge * (w * 1.1) ** 2 - 0.06, z), m=stud, bev=0.02)
    if lea:  # cross-stitches down the centre
        for z in (0.8, 0.3, -0.2, -0.7):
            tube([(-0.07, -0.05, z), (0.07, -0.05, z + 0.05)], 0.015, seam, segs=4)
    else:  # a riveted centre ridge
        tube([(0, -0.06, 1.0), (0, -0.06, 0.0), (0, -0.06, -0.95)], 0.035, seam, segs=4)
        for z in (0.8, 0.2, -0.4):
            ball(0.038, loc=(0.0, -0.1, z), m=stud, sub=2)
    turn(-14)
    lean(-18)
    upright()  # no-op unless the silhouette is wider than a slot can lift (<= 1.3:1)


def _armour(slot, name):
    {"helm": _armour_helm, "cuirass": _armour_cuirass, "bracers": _armour_bracers,
     "greaves": _armour_greaves}[slot](name)


def leather_helm():
    _armour("helm", "leather")


def copper_helm():
    _armour("helm", "copper")


def bronze_helm():
    _armour("helm", "bronze")


def iron_helm():
    _armour("helm", "iron")


def steel_helm():
    _armour("helm", "steel")


def leather_cuirass():
    _armour("cuirass", "leather")


def copper_cuirass():
    _armour("cuirass", "copper")


def bronze_cuirass():
    _armour("cuirass", "bronze")


def iron_cuirass():
    _armour("cuirass", "iron")


def steel_cuirass():
    _armour("cuirass", "steel")


def leather_bracers():
    _armour("bracers", "leather")


def copper_bracers():
    _armour("bracers", "copper")


def bronze_bracers():
    _armour("bracers", "bronze")


def iron_bracers():
    _armour("bracers", "iron")


def steel_bracers():
    _armour("bracers", "steel")


def leather_greaves():
    _armour("greaves", "leather")


def copper_greaves():
    _armour("greaves", "copper")


def bronze_greaves():
    _armour("greaves", "bronze")


def iron_greaves():
    _armour("greaves", "iron")


def steel_greaves():
    _armour("greaves", "steel")


ITEMS = {
    # dsc icons4: the armour tiers.
    "leather_helm": leather_helm, "leather_cuirass": leather_cuirass, "leather_bracers": leather_bracers,
    "leather_greaves": leather_greaves, "copper_helm": copper_helm, "copper_cuirass": copper_cuirass,
    "copper_bracers": copper_bracers, "copper_greaves": copper_greaves, "bronze_helm": bronze_helm,
    "bronze_cuirass": bronze_cuirass, "bronze_bracers": bronze_bracers, "bronze_greaves": bronze_greaves,
    "iron_helm": iron_helm, "iron_cuirass": iron_cuirass, "iron_bracers": iron_bracers, "iron_greaves": iron_greaves,
    "steel_helm": steel_helm, "steel_cuirass": steel_cuirass, "steel_bracers": steel_bracers,
    "steel_greaves": steel_greaves,
    # dsc icons4: metal and bone tool tiers and capture nets III-V.
    "flint_knife": flint_knife, "flint_axe": flint_axe, "flint_pick": flint_pick, "flint_spear": flint_spear,
    "obsidian_knife": obsidian_knife, "obsidian_axe": obsidian_axe, "obsidian_pick": obsidian_pick,
    "obsidian_spear": obsidian_spear,
    "copper_knife": copper_knife, "copper_axe": copper_axe, "copper_pick": copper_pick, "copper_sword": copper_sword,
    "bronze_knife": bronze_knife, "bronze_axe": bronze_axe, "bronze_pick": bronze_pick, "bronze_sword": bronze_sword,
    "iron_knife": iron_knife, "iron_axe": iron_axe, "iron_pick": iron_pick, "iron_sword": iron_sword,
    "steel_knife": steel_knife, "steel_axe": steel_axe, "steel_pick": steel_pick, "steel_sword": steel_sword,
    "bone_knife": bone_knife, "bone_axe": bone_axe, "bone_pick": bone_pick, "bone_spear": bone_spear,
    "capture_net_iii": capture_net_iii, "capture_net_iv": capture_net_iv, "capture_net_v": capture_net_v,
    "work_axe": work_axe, "work_pick": work_pick, "hoe": hoe, "stone_knife": stone_knife,
    "stone_knife_work": stone_knife_work, "barbed_knife": barbed_knife, "club": club, "raid_maul": raid_maul,
    "bone_hammer": bone_hammer, "slingshot": slingshot, "stone_shot": stone_shot, "empty_bucket": empty_bucket,
    "water_bucket": water_bucket, "capture_net_i": capture_net_i, "capture_net_ii": capture_net_ii,
    "raid_helm": raid_helm, "raid_cuirass": raid_cuirass, "raid_greaves": raid_greaves,
}
