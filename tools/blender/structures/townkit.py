"""Town kit (TOWNPOLISH): the tutorial town's roofs, chimneys, lamps, gate, stall, awnings and yard
clutter, built on the house kit's 2 m wall module so TownDress can snap them onto its wall rows.

Same conventions as structures.py: Blender Z up, metres, front faces -Y (+Z in Godot), one shared
atlas. A town roof is one whole piece per house plan L x S (L along the ridge, X; S the span, Y),
with its origin on the plan centre at the top of the walls (z = 0 = eave line, 2.4 m per storey),
so the slopes, the gable ends, the barge boards and the ridge always meet the walls: the old town
built roofs from a unit prism and a flat triangle that floated, poked through and lit blue.
# ASSUMPTION: pitches (thatch 0.9 rise per run, the rest 0.62), overhangs and every trim size here.
"""
import math

from lib import Part

R = math.radians

ROOF_SIZES = [(4, 4), (6, 4), (8, 4), (6, 6), (8, 6), (10, 8)]
FINISHES = {
    # finish: (slope tile, tile_m, slab thickness, pitch, gable tile, ridge tile)
    "thatch": ("thatch_dark", 1.2, 0.32, 0.9, "weathered", "thatch"),
    "shingle": ("shingle", 1.3, 0.14, 0.62, "plank", "wood_dark"),
    "slate": ("slate", 1.0, 0.14, 0.62, "stone", "stone_dark"),
    "tile": ("roof_tile", 1.0, 0.14, 0.62, "plaster", "clay_dark"),
}
EAVE_OH = 0.45   # past the wall line at the eaves
GABLE_OH = 0.3   # past the gable walls


def roof_rise(finish, span):
    return span * 0.5 * FINISHES[finish][3]


def town_roof(finish, L, S):
    tile, tile_m, t, pitch, gable_tile, ridge_tile = FINISHES[finish]
    p = Part("town_roof")
    hs = S * 0.5
    rise = hs * pitch
    ang = math.atan2(rise, hs)
    run = (hs + EAVE_OH) / math.cos(ang)  # slope length from the ridge to the eave edge
    hl = L * 0.5 + GABLE_OH
    for sy in (-1, 1):
        # The slab's underside passes through (y = sy*hs, z = 0) (the wall top) and the ridge.
        mid_y = sy * (hs + EAVE_OH) * 0.5
        mid_z = rise - (hs + EAVE_OH) * 0.5 * math.tan(ang)
        nz, ny = math.cos(ang), sy * math.sin(ang)  # slab normal (outward/up)
        # Courses: strips about 1 m down the slope and 2 m along it (the atlas UVs one tile per face,
        # so a whole-slope slab stretched one tile over 6 m), each lower course stepped out a little
        # over the one above, the way shingles, slates and thatch lap.
        n_c = max(2, int(math.ceil(run / 1.0)))
        n_x = max(1, int(round(hl * 2 / 2.0)))
        cl = run / n_c
        for k in range(n_c):
            s0 = -run * 0.5 + cl * (k + 0.5)  # along the slope from its middle, + towards the ridge
            lift = (n_c - 1 - k) * 0.025  # lower courses lap over the ones above
            cy = mid_y - sy * s0 * math.cos(ang) + ny * (t * 0.5 + lift)
            cz = mid_z + s0 * math.sin(ang) + nz * (t * 0.5 + lift)
            for j in range(n_x):
                sx0 = -hl + (j + 0.5) * hl * 2 / n_x
                p.box((hl * 2 / n_x + 0.01, cl + 0.08, t), (sx0, cy, cz), tile,
                      rot=(math.degrees(-sy * ang), 0, 0), tile_m=tile_m)
        # eave fascia and barge boards along both rakes
        ez = -EAVE_OH * math.tan(ang)
        p.box((hl * 2, 0.06, 0.18), (0, sy * (hs + EAVE_OH + 0.02), ez + 0.05), "wood_dark")
        for sx in (-1, 1):
            p.plank((sx * (hl + 0.02), sy * (hs + EAVE_OH), ez + t * 0.6),
                    (sx * (hl + 0.02), 0, rise + t * 0.9), 0.06, 0.22, "wood_dark", up=(0, 0, 1))
    # ridge: a thatch roll, a capped board or ridge tiles
    if finish == "thatch":
        p.log((-hl, 0, rise + t * 0.95), (hl, 0, rise + t * 0.95), 0.2, tile=ridge_tile, seg=8, end_tile=ridge_tile)
    else:
        p.log((-hl, 0, rise + t * 1.05), (hl, 0, rise + t * 1.05), 0.1, tile=ridge_tile, seg=6, end_tile=ridge_tile)
    # gable ends: the triangle above each end wall, 0.22 m thick, with a collar beam and a vent
    for sx in (-1, 1):
        x = sx * L * 0.5
        p.prism([(x - 0.11, -hs, 0.0), (x - 0.11, hs, 0.0), (x - 0.11, 0.0, rise)], (0.22, 0, 0), gable_tile, tile_m=1.2)
        p.box((0.26, S + 0.1, 0.16), (x, 0, 0.08), "wood_dark")
        if rise > 1.0:
            vz = rise * 0.42
            if S >= 6:  # an attic window
                p.box((0.08, 0.7, 0.6), (x + sx * 0.1, 0, vz), "soot")
                for dy in (-0.38, 0.38):
                    p.box((0.1, 0.07, 0.72), (x + sx * 0.13, dy, vz), "wood_dark")
                for dz in (-0.33, 0.33):
                    p.box((0.1, 0.83, 0.07), (x + sx * 0.13, 0, vz + dz), "wood_dark")
            else:  # a round vent
                p.cyl(0.16, 0.06, (x + sx * 0.12, 0, vz), "soot", rot=(0, 90, 0), seg=8)
                p.cyl(0.2, 0.05, (x + sx * 0.13, 0, vz), "wood_dark", rot=(0, 90, 0), seg=8)
    return [(p, (0, 0, 0))]


def town_chimney():
    """Stone chimney stack, 0.7 m square, base at z = 0 (sunk into the roof by TownDress), with a
    cap course and two clay pots."""
    p = Part("town_chimney")
    h = 3.2
    for i in range(8):
        z = 0.2 + i * 0.4
        p.box((0.72, 0.72, 0.38), (0, 0, z), "stone" if i % 2 else "stone_dark", tile_m=0.6)
    p.box((0.86, 0.86, 0.14), (0, 0, h + 0.07), "stone_dark", tile_m=0.6)
    for dx in (-0.16, 0.16):
        p.cyl(0.1, 0.32, (dx, 0, h + 0.3), "clay", seg=8, r2=0.08, cap_tile="soot")
    return [(p, (0, 0, 0))]


def town_lamp():
    """Street lamp: a squared post on a stone footing with an iron lantern cage on top. The glass is
    TownDress's emissive box (lit at night), placed in the cage at z 2.62..2.98."""
    p = Part("town_lamp")
    p.box((0.34, 0.34, 0.24), (0, 0, 0.1), "stone_dark", tile_m=0.5)
    p.box((0.14, 0.14, 2.5), (0, 0, 1.25 + 0.1), "wood_dark")
    p.box((0.32, 0.32, 0.06), (0, 0, 2.6), "iron")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.035, 0.035, 0.4), (sx * 0.15, sy * 0.15, 2.8), "iron")
    p.cyl(0.26, 0.16, (0, 0, 3.08), "iron", seg=4, r2=0.04, rot=(0, 0, 45))
    p.torus(0.06, 0.015, (0, 0, 3.2), "iron", seg=8, tube=4)
    for sx in (-1, 1):  # brackets
        p.plank((sx * 0.07, 0, 2.3), (sx * 0.16, 0, 2.58), 0.04, 0.03, "iron", up=(0, 1, 0))
    return [(p, (0, 0, 0))]


def town_gate():
    """Town gate over a 6 m avenue: two timber towers on stone footings, a beam with a little
    shingle roof, a hanging sign. Origin at the middle of the opening; the opening is 7 m."""
    p = Part("town_gate")
    for sx in (-1, 1):
        x = sx * 3.85
        for i in range(3):
            p.box((1.0, 1.0, 0.3), (x, 0, 0.15 + i * 0.3), "stone" if i % 2 else "stone_dark", tile_m=0.6)
        p.box((0.7, 0.7, 4.2), (x, 0, 0.9 + 2.1), "wood_dark")
        for sy in (-1, 1):
            p.plank((x - sx * 0.35, sy * 0.36, 2.6), (x - sx * 1.6, sy * 0.36, 3.85), 0.2, 0.14, "wood_dark", up=(0, 1, 0))
        p.cyl(0.42, 0.7, (x, 0, 5.45), "shingle", seg=4, r2=0.02, rot=(0, 0, 45))
    p.box((9.0, 0.5, 0.45), (0, 0, 4.1), "wood")
    p.box((9.4, 0.3, 0.16), (0, 0, 4.42), "wood_dark")
    for sy in (-1, 1):  # a small roof over the beam
        p.box((9.6, 0.7, 0.1), (0, sy * 0.3, 4.66), "shingle", rot=(sy * 28, 0, 0), tile_m=1.3)
    p.log((-4.8, 0, 4.82), (4.8, 0, 4.82), 0.06, tile="wood_dark", seg=6, end_tile="wood_dark")
    # hanging sign
    for dx in (-0.7, 0.7):
        p.log((dx, -0.05, 3.88), (dx, -0.05, 3.45), 0.015, tile="rope", seg=4, end_tile="rope")
    p.box((1.8, 0.08, 0.55), (0, -0.05, 3.2), "sign_board", tile_m=1.8)
    return [(p, (0, 0, 0))]


def town_stall():
    """Market stall frame: four posts, a plank counter at the front, a back shelf and a stool.
    TownDress lays a coloured canvas over it at z 2.15. 3.6 x 2.6 m, front -Y."""
    p = Part("town_stall")
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.14, 0.14, 2.2), (sx * 1.8, sy * 1.3, 1.1), "wood")
    p.box((3.5, 0.7, 0.08), (0, -1.0, 0.92), "plank", tile_m=1.2)
    p.box((3.4, 0.06, 0.86), (0, -1.33, 0.45), "plank", tile_m=1.2)
    for sx in (-1, 1):
        p.box((0.06, 0.66, 0.86), (sx * 1.7, -1.0, 0.45), "wood_dark")
    p.box((3.4, 0.4, 0.06), (0, 1.15, 1.25), "plank")
    p.box((3.4, 0.4, 0.06), (0, 1.15, 0.6), "plank")
    for sx in (-1.4, 1.4):
        p.box((0.06, 0.4, 1.3), (sx, 1.15, 0.65), "wood_dark")
    for i, x in enumerate((-1.0, -0.2, 0.7)):  # goods on the back shelf
        p.cyl(0.16, 0.26, (x, 1.15, 1.42), "weave" if i % 2 else "clay", seg=8, r2=0.12)
    p.box((0.4, 0.4, 0.45), (0.9, 0.2, 0.225), "wood_dark")
    for sy in (-1, 1):
        p.box((3.7, 0.1, 0.1), (0, sy * 1.3, 2.12), "wood_dark")
    return [(p, (0, 0, 0))]


def town_awning():
    """A small shingled canopy over a door, 1.8 m wide and 0.9 m deep, on two brackets. Origin at
    the wall face (y = 0) at the canopy's back top edge; it reaches out along -Y."""
    p = Part("town_awning")
    p.box((1.8, 1.0, 0.08), (0, -0.45, -0.18), "shingle", rot=(-20, 0, 0), tile_m=1.3)
    p.box((1.86, 0.06, 0.14), (0, -0.93, -0.36), "wood_dark")
    for sx in (-1, 1):
        p.plank((sx * 0.8, 0.0, -0.8), (sx * 0.8, -0.85, -0.34), 0.08, 0.08, "wood_dark", up=(1, 0, 0))
        p.box((0.08, 0.06, 0.6), (sx * 0.8, -0.03, -0.6), "wood_dark")
    return [(p, (0, 0, 0))]


def town_woodpile():
    """Firewood stacked against a wall: three courses of split logs under a plank lean-to."""
    p = Part("town_woodpile")
    for row in range(3):
        for i in range(6 - row):
            x = -0.62 + i * 0.25 + row * 0.125
            p.log((x, -0.3, 0.12 + row * 0.21), (x, 0.3, 0.12 + row * 0.21), 0.11, tile="bark", seg=6)
    for sx in (-1, 1):
        p.box((0.08, 0.08, 1.0), (sx * 0.8, -0.32, 0.5), "wood_dark")
    p.box((1.8, 0.8, 0.05), (0, -0.05, 1.0), "plank", rot=(-12, 0, 0))
    return [(p, (0, 0, 0))]


def town_flowerbox():
    """Window box: a plank trough of soil with leafy plants and clay-red blooms. 1.0 m long; origin
    at its back top edge, so TownDress hangs it under a window sill."""
    p = Part("town_flowerbox")
    p.box((1.0, 0.26, 0.2), (0, -0.13, -0.1), "plank")
    p.box((0.94, 0.2, 0.04), (0, -0.13, 0.0), "soil")
    for i in range(6):
        x = -0.4 + i * 0.16
        p.rock(0.08, (x, -0.13, 0.07), tile="crop_leaf", squash=(1.0, 0.9, 0.9), seed=60 + i)
        if i % 2 == 0:
            p.rock(0.045, (x + 0.05, -0.18, 0.14), tile="clay", squash=(1, 1, 0.8), seed=70 + i)
    return [(p, (0, 0, 0))]


def town_cart():
    """A two-wheeled hand cart, tipped forward on its shafts, a few sacks in the bed."""
    p = Part("town_cart")
    p.box((1.3, 1.0, 0.08), (0, 0, 0.55), "plank", tile_m=1.0)
    for sy in (-1, 1):
        p.box((1.3, 0.06, 0.3), (0, sy * 0.5, 0.72), "plank")
        p.cyl(0.42, 0.08, (0.1, sy * 0.58, 0.42), "wheel", rot=(90, 0, 0), seg=12, cap_tile="wheel")
        p.plank((-0.65, sy * 0.35, 0.55), (-1.7, sy * 0.3, 0.06), 0.07, 0.07, "wood_dark", up=(0, 0, 1))
    p.log((0.1, -0.62, 0.42), (0.1, 0.62, 0.42), 0.04, tile="wood_dark", seg=6, end_tile="wood_dark")
    for i, (x, y) in enumerate(((-0.25, -0.2), (0.3, 0.15), (0.0, 0.25))):
        p.rock(0.24, (x, y, 0.78), tile="canvas" if i % 2 else "hide", squash=(1.2, 0.9, 0.7), seed=80 + i)
    return [(p, (0, 0, 0))]


def builders():
    out = {}
    for fin in FINISHES:
        for (L, S) in ROOF_SIZES:
            out["town_roof_%s_%dx%d" % (fin, L, S)] = (lambda f=fin, l=L, s=S: town_roof(f, l, s))
    out.update({
        "town_chimney": town_chimney,
        "town_lamp": town_lamp,
        "town_gate": town_gate,
        "town_stall": town_stall,
        "town_awning": town_awning,
        "town_woodpile": town_woodpile,
        "town_flowerbox": town_flowerbox,
        "town_cart": town_cart,
    })
    return out
