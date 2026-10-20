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


# deep bleed: three drops (bleed is one): more drops, worse bleeding.
G["bleed_deep"] = [([droppoly(32, 5, 9.5), droppoly(18.5, 30, 9.5), droppoly(45.5, 30, 9.5)], False)]

# venom: heavy jaw with two fangs and one drip.
G["venom"] = [([path((8, 15), (8, 11), ((8, 8), (10, 6.5), (12.5, 6.5)), (51.5, 6.5), ((54, 6.5), (56, 8), (56, 11)), (56, 15))],
               False),
              ([path((11, 14), (28, 14), ((28, 26), (24.5, 36), (17, 44)), ((18.5, 34), (16.5, 24), (11, 14))),
                path((36, 14), (53, 14), ((47.5, 24), (45.5, 34), (47, 44)), ((39.5, 36), (36, 26), (36, 14)))], False),
              ([droppoly(32, 32, 8.5)], False)]

# pinned: a stake driven through split ground.
G["pinned"] = [([chaikin([(16.5, 7), (47.5, 7), (47.5, 17.5), (16.5, 17.5)], 1), [(24.5, 17), (39.5, 17), (39.5, 37), (32, 53), (24.5, 37)]], False),
               ([chaikin([(6, 47.5), (21, 47.5), (21, 54.5), (6, 54.5)], 1), chaikin([(43, 47.5), (58, 47.5), (58, 54.5), (43, 54.5)], 1)], False),
               ([[(8.5, 37), (16.5, 40.5), (10, 43)], [(55.5, 37), (47.5, 40.5), (54, 43)]], False)]

# groggy: one bold spiral band (1.3 turns) instead of thin rings.
sp = []
for i in range(80):
    th = 0.55 + 7.6 * i / 79
    r = 2.2 + 15.0 / (2 * math.pi) * th
    sp.append((32 + r * math.cos(th + 2.2), 32 + r * math.sin(th + 2.2)))
G["groggy"] = [([band(sp, 7.5)], False)]

# stomachache: solid stomach with a pain bolt cut out of it.
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
def haft(top=-30.0, bottom=27.0, wy0=-22.5, n=3, h=4.2, gap=1.9, w=8.6, ww=14.0):
    return [capsule((0, top + 3.5), (0, wy0 + 1), w), capsule((0, wy0 + n * (h + gap) - gap - 1), (0, bottom - 3.5), w)] + wraps(n, wy0, h, gap, ww)

# chop: knapped flint axe head lashed to a wooden haft.
CHOP_HEAD = [(-6.5, -19.5), (-12, -22.5), (-18, -26), (-23.5, -30), (-26.5, -26.5), (-28.3, -20.5), (-29, -14.5), (-28.3, -8),
             (-26, -1.5), (-20.5, -4), (-14, -7.5), (-6.5, -10)]
G["chop"] = [([xf(p, rot=38, dx=32, dy=32) for p in haft() + [xf(CHOP_HEAD, scale=1.18, about=(-6.5, -15))]], False)]

# mine: long knapped stone pick lashed across the haft (blunt butt behind).
PICK = [(-6, -20.5), (-11, -22), (-16.5, -21.5), (-22, -19), (-27, -14.5), (-31.5, -7), (-26.5, -10.5), (-21, -13), (-15, -14),
        (-10, -12.5), (-6, -11.5)]
BUTT = [(6, -19.5), (9.5, -20.5), (12, -17.5), (12, -13.5), (9.5, -11), (6, -11.5)]
G["mine"] = [([xf(p, rot=-32, dx=32, dy=32) for p in haft() + [xf(PICK, scale=1.12, about=(-6, -16)), BUTT]], False)]

# dig: antler hoe (tine lashed to a haft) biting into a mound of earth.
A, B = (56, 8), (24.5, 25)
ang = math.degrees(math.atan2(B[1] - A[1], B[0] - A[0])) + 90   # local "up" (-y) points from A to B
L_HAFT = haft(top=-21, bottom=17, wy0=-19.5, n=2, h=4.0, gap=1.8, w=7.0, ww=12.0)
loc = [xf(p, rot=ang) for p in L_HAFT]
ref = xf([(0, -19.5)], rot=ang)[0]
G_HAFT = [[(x - ref[0] + B[0], y - ref[1] + B[1]) for x, y in p] for p in loc]
TINE = taper([B] + cubic(B, (20.5, 30), (17.5, 38), (16, 47.5), 10), 12.5, 1.5)
GROUND = chaikin([(6, 57.5), (6, 53), (12, 50.5), (20, 51.5), (28, 50), (38, 51.5), (47, 50.5), (55, 52), (58, 57.5)], 2)
G["dig"] = [(G_HAFT + [TINE], False), ([GROUND, chaikin([(27, 40), (32, 38.5), (33.5, 43), (28.5, 44.5)], 1), chaikin([(34.5, 31), (38.5, 30), (39.5, 33.5), (35.5, 34.5)], 1)], False)]

# butcher: single-edged flint knife (straight spine, curved knapped edge, point) on a sinew-wrapped
# grip; a symmetric leaf blade read as a club at 24 px (review r2 blind read).
BLADE = [(-3.5, -36), (1.5, -31), (5.5, -25), (8.5, -18.5), (8.2, -16.5), (9.5, -12), (9.5, -7.5), (7.5, -4), (-5, -4), (-5, -14),
         (-4.8, -26)]
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

# tailoring: a fringed hide tunic with a laced neck.
TUNIC = [(22.5, 8), (27, 8), (32, 17), (37, 8), (41.5, 8), (55.5, 15.5), (51.5, 28.5), (46.5, 26.5), (47.5, 49.5), (16.5, 49.5), (17.5, 26.5),
         (12.5, 28.5), (8.5, 15.5)]
FRINGE = [capsule((x, 50), (x + (x - 32) * 0.08, 56), 3.6) for x in (19, 24.5, 30, 35.5, 41, 46)]
LACE = [band([(28.5, 20.5), (35.5, 27)], 3.2), band([(35.5, 20.5), (28.5, 27)], 3.2)]
G["tailoring"] = [([chaikin(TUNIC, 1)] + LACE, True), ([[(16.5, 47), (47.5, 47), (47.5, 49), (16.5, 49)]] + FRINGE, False)]

# toxin: a stoppered gourd with a drip running off it.
GOURD = [circle(0, 9, 15.5), circle(0, -11.5, 9.5), chaikin([(-4.5, -25.5), (4.5, -25.5), (4.5, -18), (-4.5, -18)], 1),
         chaikin([(-6.5, -29), (6.5, -29), (6.5, -25), (-6.5, -25)], 1)]
G["toxin"] = [([xf(p, rot=28, dx=27, dy=34) for p in GOURD], False), ([droppoly(48.5, 26, 6.8)], False)]

# claim: a horned skull on a stake driven into the ground.
SKULL = chaikin([(23, 12), (27, 8), (37, 8), (41, 12), (41.5, 21), (38, 27), (36.5, 31), (27.5, 31), (26, 27), (22.5, 21)], 2)
HORN_L = taper([(25, 14)] + cubic((25, 14), (17, 14), (11, 12), (7.5, 5.5), 8), 7.5, 1.2)
HORN_R = [(64 - x, y) for x, y in HORN_L]
G["claim"] = [([SKULL, chaikin([(25.5, 15.5), (30.5, 16.5), (29.5, 21), (26.5, 20)], 1), chaikin([(38.5, 15.5), (33.5, 16.5), (34.5, 21), (37.5, 20)], 1),
                [(30.5, 25), (33.5, 25), (32, 28.5)]], True),
              ([HORN_L, HORN_R], False),
              ([[(28, 34), (36, 34), (36, 48), (32, 56), (28, 48)]], False),
              ([chaikin([(6, 50.5), (23.5, 50.5), (23.5, 56.5), (6, 56.5)], 1), chaikin([(40.5, 50.5), (58, 50.5), (58, 56.5), (40.5, 56.5)], 1)], False)]

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

# optical weight: these fill more of the hex than the set (t_uiicons _test_weight), so draw them smaller
for k, sc in {"tailoring": 0.9, "construction": 0.88, "tastes_bad": 0.9}.items():
    G[k] = [([xf(p, scale=sc, about=(32, 32)) for p in polys], eo) for polys, eo in G[k]]

I = place(G)
