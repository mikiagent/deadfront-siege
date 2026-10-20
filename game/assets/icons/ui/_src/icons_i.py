"""Fourth drawing pass (review r2, material): the remaining stock pictograms keep the convention a
player knows (gear, padlock, speech bubble, horn with sound waves, magnifier, balance, star, tapping
hand) but are made of the game's materials: knapped stone, bone, hide and rope. Solid polygons only,
centred optically by geo2.place like icons_g and icons_h."""
import math
from geo2 import *
from icons_g import chaikin, taper, wraps
from icons_h import bone, ellipse

G = {}


def scallop(poly, depth, size):
    """Knapped edge: every edge becomes a run of shallow concave flake scars about `size` long."""
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    out = []
    for i in range(len(poly)):
        p, q = poly[i], poly[(i + 1) % len(poly)]
        L = math.hypot(q[0] - p[0], q[1] - p[1])
        k = max(1, round(L / size))
        for j in range(k):
            for s in range(4):
                t = (j + s / 4) / k
                bow = depth * math.sin(math.pi * s / 4)
                x, y = p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t
                m = math.hypot(cx - x, cy - y) or 1.0
                out.append((x + (cx - x) / m * bow, y + (cy - y) / m * bow))
    return out


# settings: the gear convention, knapped from flint (scalloped flake scars on every edge, a bored
# hole that is not a perfect circle).
def gear_pts(cx, cy, ro, ri, teeth):
    pts = []
    step = 360.0 / teeth
    for i in range(teeth):
        a = -90 + i * step
        for da, rr in ((-0.3, ri), (-0.17, ro), (0.17, ro), (0.3, ri)):
            ang = math.radians(a + da * step)
            pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    return pts


HOLE = [(25.5, 30), (29, 25), (35.5, 25.5), (39, 30.5), (38, 37), (32.5, 39.5), (26.5, 37)]
G["settings"] = [([scallop(gear_pts(32, 32, 26, 18, 8), 1.2, 7.0), HOLE], True)]

# padlock: a rough-hewn stone block (chipped corners, uneven faces) with the keyhole cut through,
# under a bone shackle (unlock: swung open, its knobbed end free).
BLOCK = chaikin([(14, 31), (36, 30), (49.5, 31), (52, 34.5), (51, 43), (52.5, 52.5), (48.5, 56), (31, 55), (16, 56), (12, 52.5),
                 (13, 42), (11.5, 34.5)], 1)
KEYHOLE = arcp(32, 40.5, 4.6, 115, 425, 24) + [(35, 50), (29, 50)]
G["lock"] = [([BLOCK, KEYHOLE], True), ([band([(21, 31.5), (21, 19)] + arcp(32, 19, 11, 180, 360, 20)[1:] + [(43, 31.5)], 6.4)], False)]
G["unlock"] = [([BLOCK, KEYHOLE], True), ([band([(21, 31.5), (21, 13)] + arcp(32, 13, 11, 180, 360, 20)[1:] + [(43, 17)], 6.4),
                                           circle(40.5, 19.5, 3.6), circle(45.5, 19.5, 3.6)], False)]

# chat: the speech bubble as a stretched hide (leg lobes at the corners), tail and three dots.
PELT = chaikin([(6, 7), (15, 11), (24, 9.5), (32, 11), (40, 9.5), (49, 11), (58, 7), (54.5, 17), (56.5, 26), (54.5, 35), (58, 45),
                (48, 41.5), (40, 43), (30, 42), (17, 55), (21, 42.5), (15, 41.5), (6, 45), (9.5, 35), (7.5, 26), (9.5, 17)], 2)
G["chat"] = [([PELT, circle(21, 26.5, 3.8), circle(32, 26.5, 3.8), circle(43, 26.5, 3.8)], True)]


# sound: a blown animal horn with sound waves (mute: the same horn struck by an X).
def horn(dx=0.0):
    c = [(8 + dx, 52)] + cubic((8 + dx, 52), (8 + dx, 36), (17 + dx, 29), (33 + dx, 29), 14)
    return [taper(c, 5.0, 19.0), ellipse(33 + dx, 29, 3.2, 10.5), circle(8 + dx, 53, 3.6)]


G["sound"] = [(horn() + [band(arcp(34, 29, r, -48, 48), 5.4) for r in (11.5, 20)], False)]
G["mute"] = [(horn(-1) + [capsule((42, 22), (55, 36), 6), capsule((55, 22), (42, 36), 6)], False)]


# zoom: a magnifier ring on a bone handle (knobbed end). (Rope lashing on the handle read as key teeth.)
def magnifier(minus_only):
    ring = [circle(27, 27, 18.5), circle(27, 27, 13)]
    handle = bone((41, 41), (52.5, 52.5), w=8.4, knob=4.8, spread=3.4)
    mark = [capsule((20, 27), (34, 27), 5.4)] + ([] if minus_only else [capsule((27, 20), (27, 34), 5.4)])
    return [(ring, True), ([handle[0]] + handle[3:] + mark, False)]


G["zoom_in"] = magnifier(False)
G["zoom_out"] = magnifier(True)

# market: the balance convention: a branch beam lashed to a post set in a stone, rope cords, gourd pans.
BOWL_L = [(4, 36)] + arcp(13, 36, 9, 0, 180, 14)[::-1][:-1] + [(22, 36)]
BOWL_R = [(x + 38, y) for x, y in BOWL_L]
G["market"] = [([band([(32, 18), (32, 50)], 5.6), chaikin([(19, 57), (21, 50.5), (28, 47.5), (37, 47.5), (43.5, 51), (45, 57)], 1),
                 taper([(7, 18.5), (20, 17), (32, 16.5), (44, 17), (57, 18.5)], 5.6, 4.4), band([(46, 17), (49.5, 11.5)], 3.6),
                 chaikin([(32, 10.5), (37.5, 16.5), (32, 22.5), (26.5, 16.5)], 1)]
                + [band(c, 3.2) for c in ([(12, 19), (5.5, 36)], [(12, 19), (20.5, 36)], [(52, 19), (43.5, 36)], [(52, 19), (58.5, 36)])]
                + [chaikin(BOWL_L, 1), chaikin(BOWL_R, 1)], False)]

# skills: the star, carved: a ridge cut from every point to the centre so it reads as faceted stone.
STAR = [(32 + (25 if i % 2 == 0 else 10.5) * math.cos(math.radians(-90 + 36 * i)),
         33.5 + (25 if i % 2 == 0 else 10.5) * math.sin(math.radians(-90 + 36 * i))) for i in range(10)]
FACETS = [STAR]
for i in range(5):
    tip = STAR[2 * i]
    FACETS = [q for p in FACETS for q in cut(p, (32, 33.5), tip, 1.3)]
G["skills"] = [(FACETS, False)]

# use: the tapping hand, wrist bound in a hide wrap.
PALM = chaikin([(24, 30), (43, 30), (48.5, 33.5), (49, 43), (44.5, 49.5), (29, 49.5), (23, 45), (15, 37.5), (16.5, 34), (24, 36.5)], 2)
CUFF = [xf(p, dx=37, dy=0) for p in wraps(2, 51, 2.6, 1.5, 17, slant=-10)]
G["use"] = [([band(arcp(28, 15.5, 10, 200, 340), 4.6), capsule((28, 16), (28, 34), 8.4), PALM] + CUFF, False)]

I = place(G)
