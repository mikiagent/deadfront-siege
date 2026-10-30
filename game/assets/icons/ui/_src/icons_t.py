"""Fifteenth drawing pass (BUTCHERHEX, owner 2026-10-30: "inspiration for butchering and animal parts
symbols", a Durango carcass with one flat-top hex per part): the animal parts a carcass is cut into,
and the tool-needed badge a locked part wears. Line drawings (5-unit bands, round ends) built as solid
polygons so geo2.place centres them optically like icons_g..s; a few small details are solid."""
import math
from geo2 import *
from icons_g import chaikin, droppoly

G = {}
LW = 5.0  # the set's line weight


def ring(pts, w=LW):
    """A closed outline of width w along the polygon pts (the band runs one point past the seam)."""
    return band(list(pts) + list(pts[:2]), w)


def line(*pts, w=LW):
    return band(list(pts), w)


def smooth(pts, n=2):
    return chaikin(list(pts), n)


def bone_outline(x0, x1, cy, half, r):
    """Outline of a bone lying along y = cy from x0 to x1: a shaft `half` thick each side and two round
    knobs of radius r at each end (centres 0.95 r above and below the axis)."""
    k = r * 0.95
    cx = x1 - r
    a1 = math.degrees(math.atan2(k - half, -math.sqrt(r * r - (k - half) ** 2)))  # shaft top meets the upper knob
    notch = math.degrees(math.asin(k / r))
    right = arcp(cx, cy - k, r, a1, 360 + notch, 24) + arcp(cx, cy + k, r, -notch, 360 - a1, 24)
    return right + [(x0 + x1 - x, y) for x, y in right][::-1]


# ---------------------------------------------------------------- bone: a dog-bone on the rising diagonal
BONE = bone_outline(8.0, 56.0, 32.0, 4.0, 7.0)
G["part_bone"] = [([xf(ring(BONE), rot=-40, about=(32, 32))], False)]

# ---------------------------------------------------------------- large leg bone: a femur on the other diagonal,
# one round head at the top, two condyles at the foot, a thicker shaft than the plain bone
def femur():
    r, k, half, cy = 8.0, 7.6, 5.0, 32.0
    cx = 54.0 - r
    a1 = math.degrees(math.atan2(k - half, -math.sqrt(r * r - (k - half) ** 2)))
    notch = math.degrees(math.asin(k / r))
    foot = arcp(cx, cy - k, r, a1, 360 + notch, 24) + arcp(cx, cy + k, r, -notch, 360 - a1, 24)
    hr = 9.0  # the head: one ball set above the axis
    hx, hy = 10.0 + hr, cy - 3.0
    b = math.degrees(math.asin((cy + half - hy) / hr))
    t = math.degrees(math.asin((cy - half - hy) / hr))
    head = arcp(hx, hy, hr, 180 - b, 360 + t, 30)
    return foot + head
G["part_large_leg_bone"] = [([xf(ring(femur()), rot=52, about=(32, 32))], False)]

# ---------------------------------------------------------------- skull: front view, round cranium, two sockets,
# a nose notch and a row of teeth
CRANIUM = smooth([(32, 7), (46, 10), (54, 21), (53, 33), (47, 39), (46, 48), (40, 51), (24, 51), (18, 48), (17, 39), (11, 33), (10, 21), (18, 10)], 2)
G["part_skull"] = [([ring(CRANIUM), smooth([(19.5, 24), (28, 23), (28.5, 31), (22, 33), (18.5, 29)], 2),
                     smooth([(44.5, 24), (36, 23), (35.5, 31), (42, 33), (45.5, 29)], 2), [(32, 33.5), (35.5, 40), (28.5, 40)],
                     line((26, 45), (26, 51)), line((32, 45), (32, 51)), line((38, 45), (38, 51))], False)]

# ---------------------------------------------------------------- large skull: a theropod skull in profile,
# long snout to the left, the jaw a little open, a solid eye socket, the big opening before it, teeth
SKULL_L = smooth([(6, 27), (12, 19), (28, 13), (44, 7), (54, 9), (58, 19), (56, 31), (52, 40), (46, 50), (30, 48), (13, 44), (10, 40),
                  (30, 39), (46, 36), (30, 33), (10, 33)], 1)
G["part_large_skull"] = [([ring(SKULL_L), circle(46, 19, 4.5), smooth([(22, 26), (31, 21), (36, 22), (32, 27)], 2)]
                         + [[(x, 33), (x + 4, 33), (x + 2, 37)] for x in (15, 23, 31)], False)]

# ---------------------------------------------------------------- tendon: a spindle of three sinew fibres, pinched and
# bound at both ends
A, B = (10.0, 50.0), (54.0, 14.0)
def strand(off):
    dx, dy = B[0] - A[0], B[1] - A[1]
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    pts = []
    for i in range(25):
        t = i / 24
        o = off * math.sin(math.pi * t) + 1.6 * math.sin(t * 4 * math.pi)
        pts.append((A[0] + dx * t + nx * o, A[1] + dy * t + ny * o))
    return pts
def tie(t):
    dx, dy = B[0] - A[0], B[1] - A[1]
    L = math.hypot(dx, dy)
    nx, ny = -dy / L * 6, dx / L * 6
    c = (A[0] + dx * t, A[1] + dy * t)
    return capsule((c[0] - nx, c[1] - ny), (c[0] + nx, c[1] + ny), 5.0)
G["part_tendon"] = [([band(strand(-11), 4.0), band(strand(0), 4.0), band(strand(11), 4.0), tie(0.1), tie(0.9)], False)]

# ---------------------------------------------------------------- intestines: a gut tube coiled back and forth
GUT = path((10, 14), (44, 14), ((54, 14), (54, 26), (44, 26)), (22, 26), ((12, 26), (12, 38), (22, 38)), (42, 38),
           ((52, 38), (52, 50), (42, 50)), (16, 50))
G["part_intestines"] = [([band(GUT, 7.0)], False)]

# ---------------------------------------------------------------- meat: a steak with its round bone and a rind of fat
STEAK = smooth([(14, 16), (30, 9), (46, 12), (56, 24), (53, 40), (40, 47), (36, 55), (24, 56), (12, 48), (8, 32)], 2)
RIND = smooth([(18, 22), (30, 15.5), (44, 18)], 1)
G["part_meat"] = [([ring(STEAK), band(RIND, 4.0), circle(25, 37, 5.0)], False)]

# ---------------------------------------------------------------- hide: a pegged-out pelt, four legs and a tail
PELT = smooth([(32, 7), (38, 10), (40, 15), (50, 9), (56, 13), (48, 21), (49, 36), (56, 46), (51, 51), (42, 45),
               (36, 54), (32, 58), (28, 54), (22, 45), (13, 51), (8, 46), (15, 36), (16, 21), (8, 13), (14, 9), (24, 15), (26, 10)], 1)
G["part_hide"] = [([ring(PELT), line((32, 22), (32, 41), w=3.0)], False)]

# ---------------------------------------------------------------- armor: three keeled scutes, two on one under,
# each an outlined rounded rhombus with its keel
def scute(cx, cy, w, h):
    return [ring(smooth([(cx, cy - h), (cx + w, cy - h * 0.2), (cx + w * 0.7, cy + h * 0.7), (cx, cy + h), (cx - w * 0.7, cy + h * 0.7), (cx - w, cy - h * 0.2)], 1)),
            line((cx, cy - h * 0.45), (cx, cy + h * 0.5), w=3.5)]
G["part_armor"] = [(scute(20, 21, 12, 13) + scute(44, 21, 12, 13) + scute(32, 43, 12, 13), False)]

# ---------------------------------------------------------------- fat: a soft block of suet, marbled, a drip running off it
SUET = smooth([(9, 16), (55, 13), (53, 44), (11, 46)], 2)
WAVE = lambda y: [(x, y + 2.2 * math.sin((x - 16) / 32 * 2 * math.pi * 1.5)) for x in [16 + i * 2 for i in range(17)]]
G["part_fat"] = [([ring(SUET), band(WAVE(24), 3.5), band(WAVE(34), 3.5), droppoly(44, 47, 4.5)], False)]

# ---------------------------------------------------------------- claw: a hooked talon, thick at the root, curling over
# to a point that faces down
from icons_g import taper
CURVE = arcp(30, 36, 20, 200, 395, 30)
G["part_claw"] = [([ring(taper(CURVE, 16.0, 0.0)), line((9, 37), (19, 46), w=3.5)], False)]

# ---------------------------------------------------------------- horn: a curved brow horn with growth rings at its base
HORN = path((12, 56), ((10, 34), (24, 14), (52, 7)), ((36, 20), (34, 40), (40, 56)))
G["part_horn"] = [([ring(smooth(HORN, 1)), line((15, 46), (37, 47), w=3.5), line((17, 37), (35, 39), w=3.5)], False)]

# ---------------------------------------------------------------- frill plate: a fan of bone with points round its rim
FRILL = [(32, 54)]
for i in range(9):
    a = 180 + i * 22.5
    r = 26 if i % 2 == 0 else 20
    FRILL.append((32 + r * math.cos(math.radians(a)), 40 + r * math.sin(math.radians(a))))
G["part_frill"] = [([ring(FRILL), line((32, 49), (32, 22), w=3.5), line((32, 49), (19, 28), w=3.5), line((32, 49), (45, 28), w=3.5)], False)]

# ---------------------------------------------------------------- dorsal plates: three kite plates standing in a row on
# the curve of a back, the middle one tallest
def kite(cx, base, h, w):
    return smooth([(cx, base - h), (cx + w, base - h * 0.45), (cx + w * 0.45, base), (cx - w * 0.45, base), (cx - w, base - h * 0.45)], 1)
G["part_dorsal_plate"] = [([kite(14, 46, 22, 8), kite(32, 40, 32, 10), kite(50, 46, 22, 8),
                            band(arcp(32, 82, 42, 235, 305, 20), 5.0)], False)]

# ---------------------------------------------------------------- tail club: a tapering tail ending in a two-lobed knob
def club():
    r, k, half, cy = 9.0, 8.6, 3.5, 32.0
    cx = 58.0 - r
    a1 = math.degrees(math.atan2(k - half, -math.sqrt(r * r - (k - half) ** 2)))
    notch = math.degrees(math.asin(k / r))
    return arcp(cx, cy - k, r, a1, 360 + notch, 24) + arcp(cx, cy + k, r, -notch, 360 - a1, 24)
TAIL = [(4 + i * 3.2, 32 + 2.0 * math.sin(i / 3.0)) for i in range(11)]
from icons_g import taper
G["part_tail_club"] = [([xf(p, rot=-30, about=(32, 32)) for p in [ring(club() + [(30, 35.5), (30, 28.5)]), taper(TAIL[::-1], 7.0, 2.0)]], False)]

# ---------------------------------------------------------------- tail spike: two long spikes from one bony base
def spike(tip, base, w):
    dx, dy = tip[0] - base[0], tip[1] - base[1]
    L = math.hypot(dx, dy)
    nx, ny = -dy / L * w, dx / L * w
    return ring([(base[0] + nx, base[1] + ny), tip, (base[0] - nx, base[1] - ny)])
G["part_tail_spike"] = [([spike((10, 8), (20, 46), 6.0), spike((54, 8), (44, 46), 6.0), capsule((12, 52), (52, 52), 9.0)], False)]

# ---------------------------------------------------------------- venom gland: a sac on its duct, a drop falling from the tip
SAC = smooth([(32, 7), (44, 12), (48, 24), (42, 34), (34, 40), (30, 40), (22, 34), (16, 24), (20, 12)], 2)
G["part_venom_gland"] = [([ring(SAC), line((32, 40), (32, 46)), droppoly(32, 47, 4.5), line((26, 18), (32, 15), w=3.0)], False)]

# ---------------------------------------------------------------- tool needed (the badge on a part the knife or a
# Butchering node does not reach yet): a wrench inside a no-entry ring, the bar cut across it
WRENCH = [xf(xf(p, rot=45, about=(32, 32)), about=(32, 32), scale=0.78) for p in [
    capsule((32, 24), (32, 58), 10),
    path((21, 4), (21, 14), ((21, 22), (26, 27), (32, 27)), ((38, 27), (43, 22), (43, 14)), (43, 4), (36.5, 4), (36.5, 14), (27.5, 14), (27.5, 4))]]
BAR = ((14.0, 14.0), (50.0, 50.0))
G["tool_needed"] = [([q for p in WRENCH for q in cut(p, BAR[0], BAR[1], 6.0)] + [ring(circle(32, 32, 24.5), 5.0), capsule(BAR[0], BAR[1], 5.0)], False)]

I = place(G)
