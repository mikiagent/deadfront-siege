"""Sixth drawing pass (FOODFX): the seven statuses FOODFX added to data/statuses.json so the HUD
status chips stop drawing letters.

Caffeinated is a tapered mug with a rim, a handle and two steam curls (drink is a bowl under one
droplet, station_pot is a lidded pot). The four taste grades are one family of mouths, each built
of different parts so none reads as another at 24 px (t_uiicons _test_distinct/_test_composition;
tastes_bad already owns the filled face plate):
  tastes_great      a wide open laughing mouth (thick oval of lip) with a tongue in it, arc eyes above
  tastes_delicious  dot eyes, a smile and a licking tongue
  tastes_horrible   a bare heavy frown
  tastes_disgusting cross eyes, a wavy mouth and a drop of drool
hot_food is a two-tongued flame over a deep pot with two handles; cold_food a snowflake over a
shallow dish. Solid polygons only, centred optically by geo2.place like icons_g..j."""
import math
from geo2 import *
from icons_g import chaikin, droppoly

G = {}

# ---------------------------------------------------------------- caffeinated: a tapered mug
G["caffeinated"] = [([chaikin([(14.5, 22), (45.5, 22), (41.5, 53), (18.5, 53)], 2)], False),
                    ([band([(14.5, 26.5), (45.5, 26.5)], 3.4),
                      band(arcp(45, 37.5, 8.0, -72, 72), 5.0),
                      band([(21.5, 18.5), (25.5, 14), (21.5, 9.5), (25, 6)], 4.4),
                      band([(32.5, 18.5), (36.5, 14), (32.5, 9.5), (36, 6)], 4.4)], False)]

# ---------------------------------------------------------------- taste family
def mouth(cx, cy, r, a0, a1, w):
    """Curved mouth: a band along an arc; angles 20..160 dip (a smile), 200..340 arch (a frown)."""
    return band(arcp(cx, cy, r, a0, a1, 16), w)


def eyes(cx, cy, r, dx, dy=0.0):
    return [circle(cx - dx, cy + dy, r), circle(cx + dx, cy + dy, r)]


# tastes_great: a thick ring face, dot eyes and the widest smile (no tongue: delicious licks).
G["tastes_great"] = [([circle(32, 32, 25.5), circle(32, 32, 19.5)], True),
                     ([mouth(32, 26, 16, 20, 160, 5.6)] + eyes(32, 25, 3.4, 8.5), False)]

# tastes_delicious: dot eyes, a smile and the tongue licking out of the right corner of the lip.
G["tastes_delicious"] = [([mouth(31, 25, 12.5, 24, 156, 5.0)] + eyes(31, 17.5, 3.6, 8.5), False),
                         ([chaikin([(37, 32), (48, 36), (46, 48), (37.5, 44)], 2)], False)]

# tastes_horrible: dot eyes and the heaviest mouth in the family, an arch (a frown).
G["tastes_horrible"] = [([mouth(32, 46, 16, 202, 338, 6.2)] + eyes(32, 22, 4.0, 9), False)]

# ---------------------------------------------------------------- tastes_disgusting: a sick face
# Filled plate like tastes_bad, but the eyes are vertical slits and the mouth a small open oval
# with a runnel of drool over the chin, so it cannot be read as tastes_bad's X eyes over a frown.
def closed_eye(cx, cy, r=6.0, w=4.4):
    """A weary closed eye: a shallow dip (the happy arcs in tastes_delicious peak up)."""
    return band([(cx - r, cy - r * 0.45), (cx, cy + r * 0.5), (cx + r, cy - r * 0.45)], w)


DROOL = band([(31, 42), (29.5, 50), (31, 57)], 4.6)
G["tastes_disgusting"] = [([circle(32, 29, 25.0),
                            band([(23, 18.5), (23, 26.5)], 5.0), band([(41, 18.5), (41, 26.5)], 5.0),
                            circle(32, 38.5, 5.4)], True),
                          ([DROOL, droppoly(31, 54, 3.4)], False)]

# ---------------------------------------------------------------- hot_food: a two-tongued flame over a pot
FLAME = [(35, 5), (38.5, 11.5), (41.5, 15.5), (42.5, 21), (40, 26.5), (37, 30), (35, 27),
         (32.5, 30.5), (28, 29.5), (22.5, 26), (21.5, 19), (25, 13), (26.5, 9.5), (29, 15),
         (31, 20), (32.5, 24), (34, 16)]
POT = chaikin([(16, 34.5), (48, 34.5), (43, 53), (21, 53)], 2)
G["hot_food"] = [([band([(9, 35), (55, 35)], 6.5), POT,
                   band(arcp(14, 40, 5.2, 100, 260), 4.4), band(arcp(50, 40, 5.2, -80, 80), 4.4)], False),
                 ([chaikin(FLAME, 2)], False)]

# ---------------------------------------------------------------- cold_food: a snowflake over a shallow dish
DISH = chaikin([(15, 40), (49, 40), (42.5, 53), (21.5, 53)], 2)


def snowflake(cx, cy, r, w=3.8):
    out = []
    for a in (90, 210, 330):
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        out.append(band([(cx - r * c, cy - r * s), (cx + r * c, cy + r * s)], w))
    for a in range(0, 360, 60):
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        b = (cx + 0.58 * r * c, cy + 0.58 * r * s)
        for k in (-52, 52):
            d = math.radians(a + k)
            out.append(band([b, (b[0] + 0.42 * r * math.cos(d), b[1] + 0.42 * r * math.sin(d))], 3.2))
    return out


G["cold_food"] = [([band([(10, 40.5), (54, 40.5)], 7.0), DISH], False), (snowflake(32, 19.5, 12.5), False)]

# optical weight (t_uiicons _test_weight, band 0.6..1.5 x the set median): the three bare faces are
# mostly empty space, so draw them larger than the plated icons beside them.
for _k, _s in {"tastes_delicious": 1.34, "tastes_horrible": 1.24, "tastes_disgusting": 0.79}.items():
    G[_k] = [([xf(p, scale=_s, about=(32, 32)) for p in polys], eo) for polys, eo in G[_k]]

I = place(G)
