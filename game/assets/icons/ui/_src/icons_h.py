"""Third drawing pass (review r2): the icons that still misread without their label at 24 px
(roll, feed, deafened, harbour, cargo, heel), the pairs that read alike (cauterise vs bleed,
wet vs auto), and stock pictograms given period material (settings, close, save, infected,
tackle). Solid polygons only, centred optically by geo2.place like icons_g."""
import math
from geo2 import *
from icons_g import chaikin, figure

G = {}


def ellipse(cx, cy, rx, ry, rot=0.0, n=36):
    return xf([(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)], rot=rot, about=(cx, cy))


def arc_arrow(cx, cy, r, a0, a1, w=5.4, hl=9.5, hw=7.5):
    """Band along a circle from angle a0 to a1 (degrees, screen space) with a solid head at a1."""
    e = math.radians(a1)
    sgn = 1.0 if a1 > a0 else -1.0
    tan = (-math.sin(e) * sgn, math.cos(e) * sgn)
    nrm = (math.cos(e), math.sin(e))
    ep = (cx + r * math.cos(e), cy + r * math.sin(e))
    head = [(ep[0] + tan[0] * hl, ep[1] + tan[1] * hl), (ep[0] + nrm[0] * hw - tan[0], ep[1] + nrm[1] * hw - tan[1]),
            (ep[0] - nrm[0] * hw - tan[0], ep[1] - nrm[1] * hw - tan[1])]
    return [band(arcp(cx, cy, r, a0, a1 - sgn * 4), w), head]


def slit(a, b, w, n=16, bend=0.0):
    """Almond-shaped cut from a to b, w wide in the middle (a wound), bowed sideways by `bend`."""
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    nx, ny = -(b[1] - a[1]) / L, (b[0] - a[0]) / L

    def side(k):
        out = []
        for i in range(n + 1):
            t = i / n
            off = bend * math.sin(math.pi * t) + k * w / 2 * math.sin(math.pi * t)
            out.append((a[0] + (b[0] - a[0]) * t + nx * off, a[1] + (b[1] - a[1]) * t + ny * off))
        return out
    return side(1) + side(-1)[::-1][1:-1]


def bone(a, b, w=7.0, knob=4.4, spread=3.4):
    """A long bone from a to b: shaft plus a pair of knobs at each end."""
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
    n = (-u[1], u[0])
    out = [capsule(a, b, w)]
    for p, s in ((a, -1.0), (b, 1.0)):
        for k in (-1.0, 1.0):
            out.append(circle(p[0] + u[0] * s + n[0] * spread * k, p[1] + u[1] * s + n[1] * spread * k, knob))
    return out


# roll: a figure tucked into a ball rolling along the ground, a curved arrow carrying it over.
G["roll"] = [(arc_arrow(31, 37, 21, 160, 338), False),
             ([circle(29.5, 39.5, 10.5), circle(39.5, 27.5, 5.4)], False),
             ([capsule((6.5, 52), (14, 52), 5), capsule((19, 57), (43, 57), 5)], False)]

# feed (tame): the raptor head of the pet family, jaws open under a drumstick held out to it.
RAPTOR = path((12, 57), ((11, 46), (10, 34), (14, 25)), ((18, 15), (26, 11), (35, 11.5)), ((40, 11.8), (43, 13), (47, 15)), (54, 18),
              ((58, 19.5), (59, 24), (56, 27)), (52, 28), (50, 32.5), (48, 28.6), (46, 29.1), (44, 33.6), (42, 29.6), (40, 30.1), (38, 34.6),
              (36, 31.1), (30, 35), (41, 40.5), (43, 36.5), (44.5, 42.2), (46, 43), (47.5, 39), (48.5, 44.2), ((51, 45), (51, 48), (48.5, 49)),
              (36, 51), ((31, 52), (28, 54), (28, 57)))
def drum_bone(a, b):
    """The bone end of a drumstick: shaft from the meat at a, two knobs at b."""
    return bone(a, b, w=5.4, knob=3.5, spread=2.6)[:1] + bone(a, b, w=5.4, knob=3.5, spread=2.6)[3:]


HEAD_XF = dict(scale=0.74, about=(12, 57), dx=-6, dy=1)
G["feed"] = [([xf(RAPTOR, **HEAD_XF), xf(circle(33.5, 22, 3.8), **HEAD_XF)], True),
             ([ellipse(44, 38, 9.5, 7, rot=-45)] + drum_bone((49.5, 31.5), (56, 22)), False)]

# deafened: an ear (helix curling down into the lobe, the inner fold) struck through; the ear is
# cut either side of the slash so the slash stands clear at 12-16 px.
HELIX = path((19, 28), ((19, 15.5), (27, 8), (35.5, 8)), ((45, 8), (51.5, 15), (51.5, 24.5)), ((51.5, 33), (45, 37), (42.5, 43)),
             ((40.5, 48.5), (39, 55.5), (31.5, 55.5)), ((26.5, 55.5), (23.5, 52), (23.5, 48)))
INNER = path((29.5, 29), ((29.5, 22.5), (32.5, 18.5), (36.5, 18.5)), ((40.5, 18.5), (43, 21.5), (43, 26)))
SL0, SL1 = (9, 9), (55, 55)
G["deafened"] = [([q for part in (band(HELIX, 7.4), band(INNER, 6.2)) for q in cut(part, SL0, SL1, 5.6)], False),
                 ([capsule((11, 11), (53, 53), 6.2)], False)]

# harbour: a paddler in a dugout canoe (one unbroken hull) on the water.
HULL = path((5, 27.5), ((12, 33), (20, 34.5), (32, 34.5)), ((44, 34.5), (52, 33), (59, 27.5)), ((58.5, 38), (52, 45.5), (40, 46)),
            (24, 46), ((12, 45.5), (5.5, 38), (5, 27.5)))
WAVE = path((7, 55), ((12, 50.5), (17, 50.5), (22, 55)), ((27, 59.5), (32, 59.5), (37, 55)), ((42, 50.5), (47, 50.5), (52, 55)),
            ((54, 57), (55.5, 57.5), (57, 57.5)))
G["harbour"] = [([HULL], False), ([band(WAVE, 5.0)], False),
                ([circle(31, 12, 5.6), capsule((31, 21), (31, 28), 9.5), capsule((45, 8.5), (19, 31), 4.4)], False)]

# cargo warp: a hide bundle tied across with rope (the ties are gaps, knotted where they cross),
# speed marks behind it: goods sent away.
BUNDLE = chaikin([(18, 8), (46, 8), (48, 22), (46, 36), (18, 36), (16, 22)], 2)
TIES = [q for half in cut(BUNDLE, (32, 0), (32, 64), 1.5) for q in cut(half, (0, 22), (64, 22), 1.5)]
G["cargo"] = [(TIES + [circle(32, 22, 4.2)], False),
              ([ellipse(32, 49.5, 26, 9.5), ellipse(32, 49.5, 19.5, 4.6)], True)]


# heel: the survivor standing with the pet-family raptor head at their side, turned to them.
RAPTOR_L = mirror_x(RAPTOR)
PET_XF = dict(scale=0.6, about=(52, 57), dx=6, dy=1)
G["heel"] = [(figure((14, 11.5), [[(12.5, 23.5), (8.5, 35.5)], [(16, 23.5), (20.5, 35)], [(14.5, 38), (10.5, 47.5), (10, 57)],
                                  [(14.5, 38), (18.5, 47.5), (19.5, 57)]], w=6.6, torso=[(14.5, 22), (14.5, 38)]), False),
             ([xf(RAPTOR_L, **PET_XF), xf(circle(64 - 33.5, 22, 3.8), **PET_XF)], True)]

# cauterise: a flame over a stitched wound (not a drop: it sits beside the bleed drop it cures).
FLAME = path((0, -24), ((5, -18.5), (10, -14.5), (10, -8.5)), ((10, -3.5), (5.5, 0), (0, 0)), ((-5.5, 0), (-10, -3.5), (-10, -8.5)),
             ((-10, -12.5), (-7.5, -15), (-5.5, -18.5)), ((-4, -16), (-3, -15), (-2, -14.5)), ((-2.5, -18), (-2, -21), (0, -24)))
TONGUE = path((0, -11), ((1.8, -9), (3, -7.5), (3, -5.7)), ((3, -3.7), (1.6, -2.7), (0, -2.7)), ((-1.6, -2.7), (-3, -3.7), (-3, -5.7)),
              ((-3, -7.5), (-1.8, -9), (0, -11)))
G["cauterise"] = [([xf(FLAME, scale=1.4, dx=32, dy=38), xf(TONGUE, scale=1.4, dx=32, dy=38)], True),
                  ([slit((12, 47), (52, 47), 7.5, bend=4.0)], False),
                  ([capsule((x - 2.5, 43.5), (x + 2.5, 55), 4.0) for x in (22, 32, 42)], False)]

# wet: rain falling straight down onto water (vertical drops, no slant: auto owns the slashes).
WET_WAVE = path((6, 41), ((12, 34.5), (19, 34.5), (25, 41)), ((31, 47.5), (38, 47.5), (44, 41)), ((50, 34.5), (55, 35), (58, 38)),
                (58, 47.5), ((55, 44.5), (50, 44.5), (44, 51)), ((38, 57.5), (31, 57.5), (25, 51)), ((19, 44.5), (12, 44.5), (6, 51)))
G["wet"] = [([capsule((x, 7), (x, 16), 5.6) for x in (17, 32, 47)] + [capsule((x, 21), (x, 28), 5.6) for x in (24.5, 39.5)], False),
            ([WET_WAVE], False)]

# tackle: a solid figure driving shoulder-first into an impact burst.
G["tackle"] = [(figure((38, 18.5), [[(34, 27), (40.5, 35), (47.5, 32)], [(30.5, 29.5), (24.5, 23.5)],
                                    [(19, 38.5), (12.5, 45), (6.5, 50.5)], [(19, 38.5), (27.5, 46), (25.5, 56)]],
                       w=7.4, torso=[(33.5, 25.5), (19, 38.5)]), False),
               ([xf([(52, 9), (53.5, 17), (58, 14), (55.5, 21), (58.5, 27.5), (52.5, 26.5), (50, 32), (48, 26), (44.5, 24.5),
                     (47.5, 20), (45.5, 13.5), (50, 16)], dx=1, dy=10)], False)]

# infected wound: a gash with spores of rot settling on it (nothing like a drop, a slash set or a germ ball).
G["infected"] = [([slit((10, 54), (46, 18), 13, bend=2.5)], False),
                 ([circle(50, 34, 5.4), circle(39, 47, 4.6), circle(52, 49, 3.6), circle(30, 13, 4.2), circle(20, 23, 3.4)], False)]

# save: a carved stone stele (outline, chipped at the shoulder) with the store-down mark cut in.
STELE = [(13, 57), (51, 57)] + arcp(32, 26, 19, 0, -180, 24) + [(13, 57)]
STELE_IN = [(18.5, 51.5), (45.5, 51.5)] + arcp(32, 26, 13.5, 0, -180, 20) + [(18.5, 51.5)]
G["save"] = [([clip(STELE, -1, 1, 37), clip(STELE_IN, -1, 1, 37 - 5.5 * math.sqrt(2))], True),
             ([capsule((32, 17.5), (32, 31), 5.4), [(23, 30), (41, 30), (32, 42.5)]], False)]


# settings: a gear knapped from stone; every tooth chipped a different way.
def stone_gear(cx, cy, ro, ri, teeth, chips):
    pts = []
    step = 360.0 / teeth
    for i in range(teeth):
        a = -90 + i * step
        c0, c1 = chips[i]
        for da, rr in ((-0.3, ri), (-0.19, ro - c0), (0.02, ro), (0.19, ro - c1), (0.3, ri)):
            ang = math.radians(a + da * step)
            pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    return pts


G["settings"] = [([stone_gear(32, 32, 26, 18.5, 8, [(0, 2.5), (2, 0), (0.5, 3), (3, 0.5), (0, 2), (2.5, 0), (1, 3), (3, 1)]),
                   circle(32, 32, 7.5)], True)]

# close: two long bones crossed (an X that reads at any size, with bone knobs for material).
G["close"] = [(bone((15.5, 15.5), (48.5, 48.5)) + bone((48.5, 15.5), (15.5, 48.5)), False)]


# ---------------------------------------------------------------- arrows drawn heavier (optical weight)
# Thin 5-unit line arrows filled half as much of the hex as the solid icons beside them.
G["rotate"] = [(arc_arrow(32, 34, 20, -60, 250, w=6.4, hl=10.5, hw=9), False)]
G["dismount"] = [([capsule((8, 55), (56, 55), 6.4), band(path((12, 13), ((28, 9), (42, 17), (43, 34))), 6.4),
                   [(43.5, 50), (53.5, 33.5), (43.2, 37.5), (33, 33.5)]], False)]
G["end_combat"] = [([band(arcp(26, 32, 18, a0, a1), 6.2) for a0, a1 in ((40, 100), (130, 230), (260, 320))]
                    + [capsule((26, 32), (46, 32), 6.4), [(59.5, 32), (44.5, 21.5), (48, 32), (44.5, 42.5)]], False)]

# stone grill: meat lying on a hot stone slab, two support stones, fire between them. (Grill bars over
# flames read as the meat dryer's hanging strips in the blind read.)
G["station_grill"] = [([chaikin([(7, 27), (57, 27), (57, 35), (7, 35)], 1)], False),
                      ([chaikin([(9.5, 38.5), (21.5, 38.5), (22.5, 57), (8.5, 57)], 1), chaikin([(42.5, 38.5), (54.5, 38.5), (55.5, 57), (41.5, 57)], 1)], False),
                      ([xf(FLAME, scale=0.72, dx=32, dy=57), xf(TONGUE, scale=0.72, dx=32, dy=57)], True),
                      ([ellipse(26, 17.5, 12.5, 6.8)] + drum_bone((36, 17.5), (49.5, 17.5)), False)]

I = place(G)
