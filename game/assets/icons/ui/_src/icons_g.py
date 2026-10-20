"""Second drawing pass (review r1): status glyphs redrawn for 12-16 px plates, period tools
(knapped flint, rope lashing, hide, bone, totem, dugout), solid-bodied figures, smoker station.
Every icon here is solid polygons only; each is centred optically by rasterising it here."""
import math
from geo import drop as drop_d, f
from geo2 import *

G = {}   # id -> [(polys, evenodd)]

def chaikin(poly, n=2):
    for _ in range(n):
        out = []
        for i in range(len(poly)):
            p, q = poly[i], poly[(i + 1) % len(poly)]
            out += [(p[0] * 0.75 + q[0] * 0.25, p[1] * 0.75 + q[1] * 0.25), (p[0] * 0.25 + q[0] * 0.75, p[1] * 0.25 + q[1] * 0.75)]
        poly = out
    return poly

def droppoly(cx, top, r):
    by = top + 1.6 * r
    return path((cx, top), ((cx + r * 0.35, top + r * 0.6), (cx + r, by - r * 0.55), (cx + r, by))) + arcp(cx, by, r, 0, 180, 16)[1:] + \
        cubic((cx - r, by), (cx - r, by - r * 0.55), (cx - r * 0.35, top + r * 0.6), (cx, top))[:-1]

def taper(pts, w0, w1):
    """Band along a polyline whose width goes from w0 to w1 (a pointed end when w1 = 0)."""
    left, right = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        a, b = pts[max(0, i - 1)], pts[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1.0
        w = (w0 + (w1 - w0) * i / (n - 1)) / 2
        left.append((p[0] - dy / L * w, p[1] + dx / L * w))
        right.append((p[0] + dy / L * w, p[1] - dx / L * w))
    return left + right[::-1]

def lens(a, b, w, bend=0.0):
    """Claw-slash lens from a to b, widest (w) in the middle, optionally bowed sideways."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    pts = []
    for i in range(13):
        t = i / 12
        pts.append((a[0] + dx * t + nx * bend * math.sin(math.pi * t), a[1] + dy * t + ny * bend * math.sin(math.pi * t)))
    return taper(pts[:7], 0.6, w) + taper(pts[6:], w, 0.6)[1:]

def wraps(n, y0, h, gap, w, slant=-18.0):
    """Lashing: n slanted rope wraps across a vertical haft (local frame), top at y0."""
    out = []
    for i in range(n):
        y = y0 + i * (h + gap)
        r = [(-w / 2, y), (w / 2, y), (w / 2, y + h), (-w / 2, y + h)]
        out.append(chaikin(xf(r, rot=slant, about=(0, y + h / 2)), 1))
    return out

# ---------------------------------------------------------------- status glyphs (12-16 px plates)
# wet: rain streaks onto a water line. No drop shapes, so it cannot be read as bleeding.
G["wet"] = [([capsule((x, 8), (x - 6, 24), 7) for x in (23, 37, 51)], False),
            ([path((6, 41), ((12, 34.5), (19, 34.5), (25, 41)), ((31, 47.5), (38, 47.5), (44, 41)), ((50, 34.5), (55, 35), (58, 38)),
                   (58, 47.5), ((55, 44.5), (50, 44.5), (44, 51)), ((38, 57.5), (31, 57.5), (25, 51)), ((19, 44.5), (12, 44.5), (6, 51)))], False)]

# deep bleed: three drops (bleed is one): more drops, worse bleeding.
G["bleed_deep"] = [([droppoly(32, 5, 9.5), droppoly(18.5, 30, 9.5), droppoly(45.5, 30, 9.5)], False)]

# venom: heavy jaw with two fangs and one drip.
G["venom"] = [([path((8, 15), (8, 11), ((8, 8), (10, 6.5), (12.5, 6.5)), (51.5, 6.5), ((54, 6.5), (56, 8), (56, 11)), (56, 15))],
               False),
              ([path((11, 14), (28, 14), ((28, 26), (24.5, 36), (17, 44)), ((18.5, 34), (16.5, 24), (11, 14))),
                path((36, 14), (53, 14), ((47.5, 24), (45.5, 34), (47, 44)), ((39.5, 36), (36, 26), (36, 14)))], False),
              ([droppoly(32, 32, 8.5)], False)]

# pinned: a three-toed foot pressing down onto the ground.
def toe(base, tip, w):
    dx, dy = tip[0] - base[0], tip[1] - base[1]
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    m = (base[0] + dx * 0.62, base[1] + dy * 0.62)
    return [(base[0] + nx * w / 2, base[1] + ny * w / 2), (m[0] + nx * w * 0.42, m[1] + ny * w * 0.42), tip,
            (m[0] - nx * w * 0.42, m[1] - ny * w * 0.42), (base[0] - nx * w / 2, base[1] - ny * w / 2)]
G["pinned"] = [([chaikin([(16.5, 7), (47.5, 7), (47.5, 17.5), (16.5, 17.5)], 1), [(24.5, 17), (39.5, 17), (39.5, 37), (32, 53), (24.5, 37)]], False),
               ([chaikin([(6, 47.5), (21, 47.5), (21, 54.5), (6, 54.5)], 1), chaikin([(43, 47.5), (58, 47.5), (58, 54.5), (43, 54.5)], 1)], False),
               ([[(8.5, 37), (16.5, 40.5), (10, 43)], [(55.5, 37), (47.5, 40.5), (54, 43)]], False)]

# deafened: solid ear struck through (the ear is cut so the slash stands clear of it).
_EAR_UNUSED = path((18, 27), ((18, 14), (27, 6.5), (36.5, 6.5)), ((47, 6.5), (54.5, 14), (54.5, 24)), ((54.5, 32), (50, 36.5), (46, 40.5)),
           ((42, 44.5), (42, 49.5), (38, 53.5)), ((34, 57.5), (25, 58), (22.5, 51.5)), ((20, 44), (18, 37), (18, 27)))
EAR_HOLE = chaikin([(33, 18), (41, 18), (43.5, 24), (38, 31), (33, 36), (29, 31), (30, 22)], 2)
SL0, SL1 = (8, 56), (56, 8)
HELIX = [(21, 27)] + cubic((21, 27), (21, 15), (28.5, 8.5), (37, 8.5), 8) + cubic((37, 8.5), (46.5, 8.5), (52, 15.5), (52, 23.5), 8) + \
    cubic((52, 23.5), (52, 31.5), (46, 35), (43, 40), 8) + cubic((43, 40), (40, 45), (40.5, 50.5), (35, 54), 8) + cubic((35, 54), (31, 56.5), (25.5, 55), (24.5, 50), 6)
INNER = [(30.5, 26)] + cubic((30.5, 26), (30.5, 20.5), (33.5, 17.5), (37, 17.5), 6) + cubic((37, 17.5), (41, 17.5), (43.5, 20.5), (43.5, 24.5), 6)
SL0, SL1 = (8, 56), (56, 8)
G["deafened"] = [([q for part in (band(HELIX, 8.6), band(INNER, 7.6)) for q in cut(part, SL0, SL1, 7.5)], False), ([capsule((10, 54), (54, 10), 6.5)], False)]

# infected wound: a spore ball (rot), one bold idea, nothing like a drop.
spikes = []
for i in range(8):
    a = math.radians(22.5 + 45 * i)
    u = (math.cos(a), math.sin(a))
    spikes += [capsule((32 + u[0] * 12, 32 + u[1] * 12), (32 + u[0] * 19, 32 + u[1] * 19), 5.5), circle(32 + u[0] * 21.5, 32 + u[1] * 21.5, 4.6)]
G["infected"] = [([circle(32, 32, 13.5), circle(27.5, 28.5, 3.2), circle(36.5, 36, 2.6)], True), (spikes, False)]

# groggy: one bold spiral band (1.3 turns) instead of thin rings.
sp = []
for i in range(80):
    th = 0.55 + 7.6 * i / 79
    r = 2.2 + 15.0 / (2 * math.pi) * th
    sp.append((32 + r * math.cos(th + 2.2), 32 + r * math.sin(th + 2.2)))
G["groggy"] = [([band(sp, 7.5)], False)]

# stomachache: solid stomach with a pain bolt cut out of it.
STOM = path((19.5, 6.5), (28.5, 6.5), (28.5, 15.5), ((28.5, 21), (33, 23), (39, 23)), ((49.5, 23), (56.5, 30), (56.5, 39.5)),
            ((56.5, 50.5), (46.5, 57.5), (34, 57.5)), ((19.5, 57.5), (8, 48.5), (8, 36.5)), ((8, 27.5), (13.5, 21.5), (19.5, 17)))
STOM = chaikin([(20, 16), (28, 14), (38, 10), (48, 11), (55, 18), (56.5, 29), (52.5, 41), (43.5, 50.5), (32, 55.5), (20, 56.5), (10.5, 53.5),
                (6.5, 47), (11, 43.5), (18.5, 45), (26, 42.5), (30.5, 36.5), (29.5, 29.5), (24, 25), (19, 22.5)], 2)
G["stomachache"] = [([STOM, [(46.5, 18.5), (36, 33.5), (42, 34), (37.5, 46.5), (50.5, 29.5), (44.5, 29), (49, 18.5)]], True),
                    ([capsule((21.5, 5.5), (24, 17), 8.5)], False)]

# tastes bad: solid face, squeezed eyes and a wavy mouth cut out.
wave = [(17 + 30 * i / 24, 42 + 3.6 * math.sin(i / 24 * 2 * math.pi * 1.5)) for i in range(25)]
G["tastes_bad"] = [([circle(32, 32, 25.5), band([(16.5, 19), (25.5, 24.5), (16.5, 30)], 5.2), band([(47.5, 19), (38.5, 24.5), (47.5, 30)], 5.2),
                     band(wave, 5.2)], True)]

# snared: the rope noose drawn as a bold band (it shows on creature plates at 12-16 px).
LOOP = [xf([(38 + 17 * math.cos(math.radians(a)), 22 + 11 * math.sin(math.radians(a)))], rot=-18, about=(38, 22))[0] for a in range(0, 361, 8)]
TAIL = [(24, 31)] + cubic((24, 31), (18, 38), (26, 44), (18, 50), 8) + cubic((18, 50), (13, 54), (9, 52), (7, 56), 6)
G["snare"] = [([band(LOOP, 6.6), band(TAIL, 6.6), capsule((21.5, 26.5), (26.5, 34.5), 11)], False)]

# ---------------------------------------------------------------- period tools (local frame: haft vertical, origin mid-haft)
def haft(top=-30.0, bottom=27.0, wy0=-22.5, n=3, h=4.2, gap=1.9, w=7.0, ww=12.5):
    return [capsule((0, top + 3.5), (0, wy0 + 1), w), capsule((0, wy0 + n * (h + gap) - gap - 1), (0, bottom - 3.5), w)] + wraps(n, wy0, h, gap, ww)

# chop: knapped flint axe head lashed to a wooden haft.
CHOP_HEAD = [(-6.5, -19.5), (-12, -22.5), (-18, -26), (-23.5, -30), (-26.5, -26.5), (-28.3, -20.5), (-29, -14.5), (-28.3, -8),
             (-26, -1.5), (-20.5, -4), (-14, -7.5), (-6.5, -10)]
G["chop"] = [([xf(p, rot=38, dx=32, dy=32) for p in haft() + [CHOP_HEAD]], False)]

# mine: long knapped stone pick lashed across the haft (blunt butt behind).
PICK = [(-6, -20.5), (-11, -22), (-16.5, -21.5), (-22, -19), (-27, -14.5), (-31.5, -7), (-26.5, -10.5), (-21, -13), (-15, -14),
        (-10, -12.5), (-6, -11.5)]
BUTT = [(6, -19.5), (9.5, -20.5), (12, -17.5), (12, -13.5), (9.5, -11), (6, -11.5)]
G["mine"] = [([xf(p, rot=-32, dx=32, dy=32) for p in haft() + [PICK, BUTT]], False)]

# dig: antler hoe (tine lashed to a haft) biting into a mound of earth.
HOE = haft(top=-29, bottom=27, wy0=-23, n=2, h=4.2, gap=1.9)
TINE = taper(cubic((-4, -21), (-12, -18), (-19, -10), (-21, 2), 8) + [], 10.0, 1.0)
TINE = taper([(-4.5, -20.5)] + cubic((-4.5, -20.5), (-12, -18.5), (-18.5, -11), (-20.5, 1.5), 10), 9.5, 0.8)
SPUR = taper([(-11, -18)] + cubic((-11, -18), (-14, -22), (-17, -24), (-20.5, -25), 6), 5.5, 0.6)
MOUND = chaikin([(5, 57.5), (6, 53), (11, 50), (17, 51), (23, 48.5), (30, 50.5), (36, 53), (38, 57.5)], 2)
TINE = taper([(-4.5, -20.5)] + cubic((-4.5, -20.5), (-12, -18.5), (-18.5, -11), (-20.5, 1.5), 10), 12.0, 1.5)
A, B = (56, 8), (24.5, 25)
ang = math.degrees(math.atan2(B[1] - A[1], B[0] - A[0])) + 90   # local "up" (-y) points from A to B
L_HAFT = haft(top=-21, bottom=17, wy0=-19.5, n=2, h=4.0, gap=1.8, w=7.0, ww=12.0)
loc = [xf(p, rot=ang) for p in L_HAFT]
ref = xf([(0, -19.5)], rot=ang)[0]
G_HAFT = [[(x - ref[0] + B[0], y - ref[1] + B[1]) for x, y in p] for p in loc]
TINE = taper([B] + cubic(B, (20.5, 30), (17.5, 38), (16, 47.5), 10), 12.5, 1.5)
GROUND = chaikin([(6, 57.5), (6, 53), (12, 50.5), (20, 51.5), (28, 50), (38, 51.5), (47, 50.5), (55, 52), (58, 57.5)], 2)
G["dig"] = [(G_HAFT + [TINE], False), ([GROUND, chaikin([(27, 40), (32, 38.5), (33.5, 43), (28.5, 44.5)], 1), chaikin([(34.5, 31), (38.5, 30), (39.5, 33.5), (35.5, 34.5)], 1)], False)]

# butcher: knapped flint blade on a sinew-wrapped grip.
BLADE = [(0, -31), (4.5, -26.5), (7.6, -20), (8.6, -13), (7.8, -7.5), (5, -4), (-4.5, -4), (-6.3, -8), (-6.8, -14), (-5.8, -21),
         (-3.4, -27)]
GRIP = [capsule((0, -2.5), (0, 18.5), 7.5)] + wraps(4, -1.5, 3.6, 1.8, 11.5, slant=-16) + [circle(0, 23, 5.2)]
G["butcher"] = [([xf(p, rot=45, dx=32, dy=32) for p in [BLADE] + GRIP], False)]

# construction: dry-stacked stone wall (rounded stones in courses), not bricks.
def stone(x0, y0, x1, y1, j=(0.0, 0.0, 0.0, 0.0)):
    return chaikin([(x0 + 1.5 + j[0], y0), (x1 - 1.5, y0 + j[1]), (x1, y0 + 2.5), (x1 - j[2], y1 - 1.5), (x1 - 2.5, y1), (x0 + 2, y1 - j[3]),
                    (x0, y1 - 2.5), (x0 + j[3], y0 + 2)], 2)
G["construction"] = [([stone(5.5, 45.5, 22, 57.5, (1, 1, 0.5, 1)), stone(24.5, 46, 41, 57.5, (0, 1.5, 1, 0)), stone(43.5, 45, 58.5, 57.5, (1, 0, 0.5, 1)),
                       stone(8, 31, 28.5, 43, (1.5, 1, 0, 0.5)), stone(31, 30.5, 55.5, 43, (0, 1.5, 1, 1)),
                       stone(13, 17, 32, 28.5, (1, 0, 1, 0)), stone(34.5, 17.5, 50.5, 28.5, (0, 1, 0, 1)),
                       stone(22, 6, 41.5, 14.8, (1, 0.5, 0, 0.5))], False)]

# tailoring: bone needle (eye at the top) pushed through a stretched hide.
PELT = chaikin([(8, 13), (17, 16), (29, 19.5), (41, 15.5), (52, 12), (49.5, 24), (46.5, 35), (50, 46), (53, 56), (41, 52.5), (30, 50),
                (19, 53), (8, 57), (11.5, 45), (15, 35), (11.5, 24)], 2)
N0, N1 = (6, 50.5), (58, 15)
nd = (N1[0] - N0[0], N1[1] - N0[1])
nL = math.hypot(*nd)
NEEDLE_PTS = [(N0[0] + nd[0] * t, N0[1] + nd[1] * t) for t in [i / 16 for i in range(17)]]
NEEDLE = taper(NEEDLE_PTS[:13], 0.6, 6.8) + []
NEEDLE = taper(NEEDLE_PTS, 0.6, 7.2)
EYE_C = (N0[0] + nd[0] * 0.9, N0[1] + nd[1] * 0.9)
EYE = capsule((EYE_C[0] - nd[0] / nL * 3, EYE_C[1] - nd[1] / nL * 3), (EYE_C[0] + nd[0] / nL * 2.5, EYE_C[1] + nd[1] / nL * 2.5), 3.0)
PELT = chaikin([(6, 17), (12, 15.5), (18, 19.5), (27, 18.5), (36, 19.5), (42, 15.5), (48, 17), (47, 23), (44, 30), (45, 38), (44, 46),
                (48, 52), (47, 58), (41, 56.5), (36, 53.5), (27, 54.5), (18, 53.5), (12, 57), (6, 56), (7.5, 50), (10, 44), (9, 36),
                (10, 28), (7.5, 22)], 2)
N0, N1 = (9, 51), (58.5, 9.5)
nd = (N1[0] - N0[0], N1[1] - N0[1])
nL = math.hypot(*nd)
NEEDLE = taper([(N0[0] + nd[0] * i / 16, N0[1] + nd[1] * i / 16) for i in range(17)], 0.6, 7.6)
EYE_C = (N0[0] + nd[0] * 0.91, N0[1] + nd[1] * 0.91)
u = (nd[0] / nL, nd[1] / nL)
EYE = capsule((EYE_C[0] - u[0] * 2.6, EYE_C[1] - u[1] * 2.6), (EYE_C[0] + u[0] * 2.2, EYE_C[1] + u[1] * 2.2), 2.8)
RUG = [chaikin([(13, 19), (43, 19), (45, 26), (44, 46), (43, 53), (13, 53), (11, 46), (12, 26)], 2),
       capsule((15, 23), (10, 17), 10), capsule((41, 23), (46, 17), 10), capsule((15, 49), (10, 55), 10), capsule((41, 49), (46, 55), 10)]
N0, N1 = (6.5, 46), (58.5, 13)
nd = (N1[0] - N0[0], N1[1] - N0[1])
nL = math.hypot(*nd)
NEEDLE = taper([(N0[0] + nd[0] * i / 16, N0[1] + nd[1] * i / 16) for i in range(17)], 0.6, 7.6)
EYE_C = (N0[0] + nd[0] * 0.91, N0[1] + nd[1] * 0.91)
u = (nd[0] / nL, nd[1] / nL)
EYE = capsule((EYE_C[0] - u[0] * 2.6, EYE_C[1] - u[1] * 2.6), (EYE_C[0] + u[0] * 2.2, EYE_C[1] + u[1] * 2.2), 2.8)
TUNIC = [(22.5, 8), (27, 8), (32, 17), (37, 8), (41.5, 8), (55.5, 15.5), (51.5, 28.5), (46.5, 26.5), (47.5, 49.5), (16.5, 49.5), (17.5, 26.5),
         (12.5, 28.5), (8.5, 15.5)]
FRINGE = [capsule((x, 50), (x + (x - 32) * 0.08, 56), 3.6) for x in (19, 24.5, 30, 35.5, 41, 46)]
LACE = [band([(28.5, 20.5), (35.5, 27)], 3.2), band([(35.5, 20.5), (28.5, 27)], 3.2)]
G["tailoring"] = [([chaikin(TUNIC, 1)] + LACE, True), ([[(16.5, 47), (47.5, 47), (47.5, 49), (16.5, 49)]] + FRINGE, False)]

# toxin: a stoppered gourd with a drip running off it.
GOURD = [circle(26, 41, 15.5), circle(26, 20.5, 9.5), chaikin([(22, 6.5), (30, 6.5), (30, 14), (22, 14)], 1)]
GOURD = [circle(0, 9, 15.5), circle(0, -11.5, 9.5), chaikin([(-4.5, -25.5), (4.5, -25.5), (4.5, -18), (-4.5, -18)], 1),
         chaikin([(-6.5, -29), (6.5, -29), (6.5, -25), (-6.5, -25)], 1)]
G["toxin"] = [([xf(p, rot=28, dx=27, dy=34) for p in GOURD], False), ([droppoly(48.5, 26, 6.8)], False)]

# claim: carved totem stake driven into the ground.
TOTEM_HEAD = chaikin([(20.5, 6), (25, 10), (39, 10), (43.5, 6), (43.5, 26), (20.5, 26)], 1)
SKULL = chaikin([(23, 12), (27, 8), (37, 8), (41, 12), (41.5, 21), (38, 27), (36.5, 31), (27.5, 31), (26, 27), (22.5, 21)], 2)
HORN_L = taper([(25, 14)] + cubic((25, 14), (17, 14), (11, 12), (7.5, 5.5), 8), 7.5, 1.2)
HORN_R = [(64 - x, y) for x, y in HORN_L]
G["claim"] = [([SKULL, chaikin([(25.5, 15.5), (30.5, 16.5), (29.5, 21), (26.5, 20)], 1), chaikin([(38.5, 15.5), (33.5, 16.5), (34.5, 21), (37.5, 20)], 1),
                [(30.5, 25), (33.5, 25), (32, 28.5)]], True),
              ([HORN_L, HORN_R], False),
              ([[(28, 34), (36, 34), (36, 48), (32, 56), (28, 48)]], False),
              ([chaikin([(6, 50.5), (23.5, 50.5), (23.5, 56.5), (6, 56.5)], 1), chaikin([(40.5, 50.5), (58, 50.5), (58, 56.5), (40.5, 56.5)], 1)], False)]

# cargo: a hide bale tied crosswise with rope, a carrying loop on top.
BALE = chaikin([(8, 22), (32, 20), (56, 22), (57, 38), (56, 55), (32, 57), (8, 55), (7, 38)], 2)
pieces = []
for half in cut(BALE, (32, 0), (32, 64), 5.0):
    pieces += cut(half, (0, 38), (64, 38), 5.0)
RING = arcp(32, 12.5, 6.5, -90, 270, 40)
ROLL = chaikin([(7, 38), (10, 31), (17, 29.5), (47, 29.5), (54, 31), (57, 38), (57, 50), (54, 56), (47, 57.5), (17, 57.5), (10, 56), (7, 50)], 2)
pieces = []
rest = [ROLL]
for x in (21.5, 42.5):
    nxt = []
    for p in rest:
        nxt += cut(p, (x, 0), (x, 64), 5.0)
    rest = nxt
SEND = arcp(32, 36, 22, 205, 330, 30)
end = math.radians(330)
tg = (-math.sin(end), math.cos(end))
nm = (math.cos(end), math.sin(end))
ep = (32 + 22 * math.cos(end), 32 + 22 * math.sin(end))
ROLL = chaikin([(17, 33), (20, 26.5), (27, 25), (49, 25), (55.5, 26.5), (58.5, 33), (58.5, 47), (55.5, 53.5), (49, 55), (27, 55), (20, 53.5), (17, 47)], 2)
rest = [ROLL]
for x in (29.5, 46.5):
    nxt = []
    for p in rest:
        nxt += cut(p, (x, 0), (x, 64), 5.0)
    rest = nxt
G["cargo"] = [(rest, False), ([capsule((29.5, 22), (29.5, 58), 4.8), capsule((46.5, 22), (46.5, 58), 4.8)], False),
              ([capsule((7.5, 31), (12.5, 31), 5), capsule((6.5, 40), (12, 40), 5), capsule((8, 49), (12.5, 49), 5)], False)]

# save: a carved stone tablet with the store-down mark cut into it.
STELE = path((13, 57.5), (13, 25)) + arcp(32, 25, 19, 180, 360, 30)[1:] + [(51, 57.5)]
SLAB = [(10, 13), (17, 10.5), (46, 10), (54.5, 12.5), (56, 21), (55, 46), (53, 54), (45, 56), (19, 56.5), (10.5, 54), (8.5, 45), (9, 21)]
G["save"] = [([chaikin(SLAB, 1), [(29, 16), (35, 16), (35, 29), (41.5, 29), (32, 40.5), (22.5, 29), (29, 29)], chaikin([(19, 44.5), (45, 44.5), (45, 49.5), (19, 49.5)], 1)], True)]

# harbour: dugout canoe on the water, paddle across it.
HULL = path((5, 27.5), ((15, 33), (49, 33), (59, 27.5)), ((56.5, 39.5), (46, 44.5), (32, 44.5)), ((18, 44.5), (7.5, 39.5), (5, 27.5)))
P0, P1 = (49, 6), (19, 58)
HULL = path((6, 25), (11, 29.5), (53, 29.5), (58, 25), ((57, 35), (50, 42.5), (40, 42.5)), (24, 42.5), ((14, 42.5), (7, 35), (6, 25)))
P0, P1 = (45, 14), (24.5, 47)
pd = (P1[0] - P0[0], P1[1] - P0[1])
BLADE = xf(chaikin([(-4.6, 0), (4.6, 0), (4.2, 11), (0, 14), (-4.2, 11)], 2), rot=math.degrees(math.atan2(pd[1], pd[0])) - 90, dx=P1[0], dy=P1[1])
WAVE = [(8.5 + 47 * i / 40, 53 + 2.3 * math.sin(i / 40 * 2 * math.pi * 2.5)) for i in range(41)]
G["harbour"] = [(cut(HULL, P0, P1, 6.0), False), ([capsule(P0, P1, 5.0), BLADE], False), ([band(WAVE, 5.0)], False)]

# ---------------------------------------------------------------- solid-bodied figures and verbs
def figure(head, limbs, w=8.0, torso=None):
    out = [circle(head[0], head[1], 6.6)]
    if torso:
        out.append(band(torso, 10.0))
    out += [band(l, w) for l in limbs]
    return out

G["chase"] = [(figure((39, 11.5), [[(34.5, 24), (44, 28.5), (51, 21.5)], [(33.5, 24.5), (24, 26.5), (17.5, 21)],
                                   [(29, 37), (39.5, 43), (37.5, 54.5)], [(29, 37), (21.5, 47), (11, 48.5)]],
                     torso=[(35, 23), (29, 37)]), False),
              ([capsule((5, 33), (13, 33), 5), capsule((7, 41), (13, 41), 5)], False)]

G["kick"] = [(figure((17.5, 11.5), [[(18.5, 25), (10, 31.5)], [(20, 25), (29.5, 20.5)], [(22.5, 38.5), (18.5, 46.5), (20.5, 53.5)],
                                    [(22.5, 38.5), (35, 35.5), (45.5, 33)]], torso=[(19.5, 22.5), (22.5, 38.5)]), False),
             ([[(50.5, 27.5), (56, 21.5), (53.5, 30)], [(51.5, 31.5), (57.5, 33.5), (51.5, 35.5)], [(50.5, 39), (56, 45), (53.5, 37)]], False)]

# roll: a figure tucked into a ball on the ground, motion marks behind.
RC = (36, 29)
RC = (31, 30)
BODY_C = (29, 31)
end = math.radians(25)
ARC2 = arcp(30, 14, 37, 150, 25, 30)
tg = (math.sin(end), -math.cos(end))
nm = (math.cos(end), math.sin(end))
ep = (30 + 37 * math.cos(end), 14 + 37 * math.sin(end))
C0 = (31, 28)
LEGS = xf(chaikin([(-9, 0), (-6, -6), (0, -7.5), (6.5, -5), (9.5, 0), (6.5, 5.5), (0, 7.5), (-6, 6)], 2), rot=-35, dx=C0[0] + 3.5, dy=C0[1] + 1)
G["roll"] = [([circle(37, 43.5, 6.3), band([(32.5, 36.5), (25, 22.5)], 10.0), band([(31, 38), (22.5, 47.5)], 7.0),
               band([(25, 22.5), (35.5, 11.5), (47, 19.5)], 8.5)], False),
             ([capsule((6.5, 27), (12.5, 27), 5), capsule((5.5, 36), (12, 36), 5)], False),
             ([chaikin([(10, 53), (56, 53), (56, 57.5), (10, 57.5)], 1)], False)]

# feed: a palm-up hand offering meat.
HAND = chaikin([(6, 43), (18, 41.5), (33, 41.5), (36.5, 36), (40.5, 32.5), (44, 34), (43.5, 38.5), (41.5, 42), (52, 42), (57.5, 43.5),
                (58, 47.5), (55, 49.5), (44, 53.5), (30, 55.5), (17, 55.5), (6, 54)], 1)
MEAT = xf(chaikin([(13, 30), (16, 22.5), (24, 19), (33, 20.5), (38, 26), (34, 32.5), (25, 35.5), (16, 34.5)], 2), dx=0, dy=0)
HAND = chaikin([(6, 44.5), (16, 43.5), (24, 46.5), (36, 46), (48, 45), (54.5, 41.5), (58, 43), (57, 48), (50, 54.5), (38, 57.5), (22, 57.5),
                (14, 55.5), (6, 55.5)], 2)
THUMB = capsule((19, 46), (25.5, 36.5), 6.8)
MEAT = chaikin([(29, 31), (32, 24.5), (39, 22), (47, 24.5), (50, 31), (47, 37.5), (39, 40), (32, 38.5)], 2)
G["feed"] = [([HAND, THUMB], False), ([MEAT, capsule((35, 29), (24, 19), 5.4), circle(19.5, 18, 3.9), circle(24, 13.5, 3.9)], False)]

# auto: claw slashes inside a cycle arrow (auto-attack).
ARC = arcp(32, 32, 22, -55, 235, 50)
end = math.radians(235)
tan = (-math.sin(end), math.cos(end))
nrm = (math.cos(end), math.sin(end))
ep = (32 + 22 * math.cos(end), 32 + 22 * math.sin(end))
HEADP = [(ep[0] + tan[0] * 9, ep[1] + tan[1] * 9), (ep[0] + nrm[0] * 7.5 - tan[0] * 1, ep[1] + nrm[1] * 7.5 - tan[1] * 1),
         (ep[0] - nrm[0] * 7.5 - tan[0] * 1, ep[1] - nrm[1] * 7.5 - tan[1] * 1)]
G["auto"] = [([band(ARC[:-2], 5.2), HEADP], False),
             ([lens((40 + k, 19 - k * 0.2), (26 + k, 45 - k * 0.2), 5.6, 2.0) for k in (-7.5, 0.0, 7.5)], False)]

# hold: stop palm (fingers together) planted on a bar: stay.
def cap_v(x, y0, y1, w):
    return capsule((x, y0), (x, y1), w)
G["hold"] = [([chaikin([(19.5, 27), (45, 27), (45, 37), (43, 43), (35, 45.5), (27, 45.5), (21, 42), (19.5, 37)], 1),
               cap_v(22.8, 29, 11.5, 6.6), cap_v(29.2, 29, 7.5, 6.6), cap_v(35.6, 29, 8.5, 6.6), cap_v(41.8, 30, 12.5, 6.2),
               capsule((21, 39.5), (12, 28.5), 6.8)], False),
             ([chaikin([(10, 50.5), (54, 50.5), (54, 56.5), (10, 56.5)], 1)], False)]

# smoker station: a domed smoke hut, door at the base, smoke rising.
DOME = path((9, 57), ((9, 42), (19, 31), (32, 31)), ((45, 31), (55, 42), (55, 57)))
DOOR = path((27, 53.5), (27, 47.5)) + arcp(32, 47.5, 5, 180, 360, 12)[1:] + [(37, 53.5)]
def smoke(x, y0, y1, amp, ph):
    return band([(x + amp * math.sin(ph + i / 12 * 2 * math.pi), y0 + (y1 - y0) * i / 12) for i in range(13)], 4.8)
G["station_smoker"] = [([DOME, DOOR], True), ([smoke(25, 26.5, 12.5, 2.6, 0.0), smoke(39, 26.5, 12.5, 2.6, 0.0)], False)]

# pack up: the hide tent with arrows closing in on it (it was a tent in a focus frame, the same
# composition as equip).
TENT = [(32, 15), (47.5, 52), (36.5, 52), (32, 41), (27.5, 52), (16.5, 52)]
G["pack_up"] = [([TENT, capsule((32, 17), (27.5, 8), 5), capsule((32, 17), (36.5, 8), 5)], False),
                ([capsule((6, 34), (11, 34), 5.5), [(17.5, 34), (9.5, 26.5), (9.5, 41.5)],
                  capsule((58, 34), (53, 34), 5.5), [(46.5, 34), (54.5, 26.5), (54.5, 41.5)]], False)]

I = place(G)
