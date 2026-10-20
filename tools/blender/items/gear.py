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
    blade = [(0.0, 1.75), (0.18, 1.3), (0.25, 0.75), (0.2, 0.12), (-0.2, 0.12), (-0.24, 0.8), (-0.14, 1.3)]
    prism(blade, 0.16, m=mat("#4d5260", 0.3, color2="#2e323c", tex="voronoi", scale=4.0, bump=0.4),
          bev=0.02, deform=lambda co: co.__setitem__(1, co.y * (1.0 - 0.75 * min(abs(co.x) / 0.25, 1.0))))
    _knife_handle(hidem("#4a2e1b", "#2f1d10"))
    lean(-42)


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
    _net(metal("#9aa0a8", 0.35), rope_m("#8a7050"), weights=metal("#4a4d52", 0.4))


def raid_helm():
    h = hidem("#7b4a2a", "#5a3218")
    prof = [(0, 1.0), (0.35, 0.97), (0.6, 0.85), (0.78, 0.6), (0.86, 0.3), (0.88, 0.0), (0.8, 0.0), (0.78, 0.3),
            (0.7, 0.6), (0.55, 0.8), (0.3, 0.9), (0, 0.92)]
    lathe(prof, m=h, segs=32)
    dark = hidem("#3e2416", "#2a170c")
    _ring(0.07, 0.9, dark, wire=0.06, n=32)
    b = bonem("#e4d6b0")
    for i, z in enumerate((0.98, 0.84, 0.62)):
        blob(0.2 - 0.02 * i, loc=(0, 0.25 * i - 0.15, z + 0.04), scl=(0.8, 1.2, 0.45),
             rot=(-25 * i, 0, 0), m=b, amp=0.05)
    for s in (-1, 1):
        tube([(s * 0.7, 0, 0.62), (s * 1.0, 0, 0.82), (s * 1.12, 0, 1.15), (s * 1.02, 0, 1.45)], 0.13, b, segs=10,
             taper=(1.0, 0.08))
        prism([(0, 0), (0.28, 0.02), (0.24, -0.38), (0.05, -0.5)], 0.06, loc=(s * 0.82, -0.25, 0.05),
              rot=(0, 0, s * 65), m=h, bev=0.02)
    turn(-18)


def _bulge(k):
    def f(co):
        co.y += k * (co.x * co.x)
    return f


def raid_cuirass():
    h = hidem("#7b4a2a", "#5a3218")
    vest = [(-0.35, 1.0), (-0.12, 0.72), (0.12, 0.72), (0.35, 1.0), (0.78, 0.92), (0.78, 0.45), (0.62, 0.3),
            (0.66, -0.8), (-0.66, -0.8), (-0.62, 0.3), (-0.78, 0.45), (-0.78, 0.92)]
    prism(vest, 0.3, m=h, bev=0.06, deform=_bulge(0.45))
    b = bonem("#e4d6b0")
    for row, z in enumerate((0.4, 0.1, -0.2, -0.5)):
        for k in range(-2, 3):
            x = k * 0.24 + (0.12 if row % 2 else 0.0)
            if abs(x) > 0.55:
                continue
            blob(0.12, loc=(x, -0.2 + 0.45 * x * x, z), scl=(1.0, 0.4, 1.15), m=b, amp=0.06)
    for s in (-1, 1):
        blob(0.36, loc=(s * 0.66, 0.0, 0.92), scl=(1.0, 0.9, 0.45), rot=(0, s * -22, 0), m=hidem("#5e3720", "#43240f"), amp=0.05)
    strap = hidem("#3e2416", "#2a170c")
    box((1.36, 0.36, 0.14), loc=(0, 0.0, -0.7), m=strap, bev=0.03, parent=None)
    box((0.22, 0.4, 0.2), loc=(0, -0.02, -0.7), m=metal("#8a8f96", 0.35), bev=0.03)
    turn(-14)


def raid_greaves():
    h = hidem("#7b4a2a", "#5a3218")
    b = bonem("#e4d6b0")
    strap = hidem("#3e2416", "#2a170c")
    shin = [(-0.3, 0.95), (0.3, 0.95), (0.34, 0.4), (0.24, -0.6), (0.3, -0.9), (-0.3, -0.9), (-0.24, -0.6), (-0.34, 0.4)]
    for s, dy in ((-1, 0.25), (1, -0.1)):
        g = group(loc=(s * 0.42, dy, 0), rot=(0, s * -5, 0))
        prism(shin, 0.22, m=h, bev=0.05, deform=_bulge(1.6), parent=g)
        blob(0.24, loc=(0, -0.05, 0.92), scl=(1.15, 0.6, 0.85), m=b, amp=0.07, parent=g)
        for z in (-0.55, 0.3):
            box((0.66, 0.3, 0.1), loc=(0, 0.04, z), m=strap, bev=0.02, parent=g, taper=None)
        for z in (-0.12, 0.62):
            blob(0.09, loc=(0, -0.15, z), scl=(1, 0.5, 1.2), m=b, amp=0.05, parent=g)
    turn(-12)


ITEMS = {
    "work_axe": work_axe, "work_pick": work_pick, "hoe": hoe, "stone_knife": stone_knife,
    "stone_knife_work": stone_knife_work, "barbed_knife": barbed_knife, "club": club, "raid_maul": raid_maul,
    "bone_hammer": bone_hammer, "slingshot": slingshot, "stone_shot": stone_shot, "empty_bucket": empty_bucket,
    "water_bucket": water_bucket, "capture_net_i": capture_net_i, "capture_net_ii": capture_net_ii,
    "raid_helm": raid_helm, "raid_cuirass": raid_cuirass, "raid_greaves": raid_greaves,
}
