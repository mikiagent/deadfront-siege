"""Farm kit: field beds, crop stages, path tiles and farm props (dsc farmkit).

Same conventions as the structure set (structures.py): Blender Z up, metres, the base at z = 0 and
the origin at the ground centre, the front faces -Y (which becomes +Z in Godot, towards the iso
camera). One shared 1024 atlas (lib.TILES); every model is one glTF node unless it is the gate,
whose leaf hangs under the main node with its origin on the hinge.

Sizes are # ASSUMPTION: a field plot module is 2 x 2 m (field_plot.gd's field_small fallback is
Vector3(2, 0.2, 2) and the build grid is 1 m cells), a path tile is 2 x 2 m and at most 0.05 m high,
the fence segment is 2 m (the same run as the existing fence.glb).
"""
import math

from lib import Part

R = math.radians


# ------------------------------------------------------------------ fields

def _ridges(p, hx, hy, top):
    """Furrow ridges: five heaped rows running along X, with the dark furrow floor between them."""
    rows = 5
    pitch = 2 * hy / rows
    seg = 3
    span = 2 * hx - 0.1
    for i in range(rows):
        y = -hy + pitch * (i + 0.5)
        w = pitch * 0.56
        for k in range(seg):
            x0 = -hx + 0.05 + k * span / seg
            seg_w = span / seg + 0.05
            h = 0.055 + 0.014 * (((i * 5 + k * 3) % 3) - 1)
            yj = y + 0.012 * (((i * 11 + k * 7) % 3) - 1)  # break the straight furrow line
            # a triangular heap of soil, not a plank: the apex is above the middle of the row
            p.prism([(x0, yj - w / 2, top), (x0, yj + w / 2, top), (x0, yj, top + h)],
                    (seg_w, 0, 0), "soil", tile_m=0.35)


def _bed(p, half=0.93):
    """The 2 x 2 m tilled plot: dark furrowed soil, furrow ridges, a raised earth edge."""
    top = 0.1
    p.box((2 * half, 2 * half, top), (0, 0, top / 2), "soil_dark", tile_m=0.5)
    _ridges(p, half, half, top)
    # raised edge: a low earth berm all round the plot, heaped like a ridge and broken at the corners
    berm_h = 0.1
    bw = 0.22
    for sy in (-1, 1):
        y = sy * (half + bw / 2)
        for k in range(4):  # four heaps per side: the berm is heaped soil, not a wall
            x = -half + (k + 0.5) * 2 * half / 4
            p.prism([(x - half / 4 - 0.03, y - bw / 2, 0), (x - half / 4 - 0.03, y + bw / 2, 0),
                     (x - half / 4 - 0.03, y, berm_h)], (half / 2 + 0.06, 0, 0), "soil", tile_m=0.4)
    for sx in (-1, 1):
        x = sx * (half + bw / 2)
        for k in range(4):
            y = -half + (k + 0.5) * 2 * half / 4
            p.prism([(x - bw / 2, y - half / 4 - 0.03, 0), (x + bw / 2, y - half / 4 - 0.03, 0),
                     (x, y - half / 4 - 0.03, berm_h)], (0, half / 2 + 0.06, 0), "soil", tile_m=0.4)
    # a few clods on the bed so the soil is not a flat slab
    for i, (x, y) in enumerate(((-0.55, -0.62), (0.4, 0.25), (0.66, -0.5), (-0.2, 0.58))):
        p.rock(0.05, (x, y, top + 0.02), tile="soil", squash=(1.2, 1.0, 0.5), seed=200 + i)
    return top + 0.05


def field_tilled():
    """A tilled 2 x 2 m plot: dark furrowed soil in furrow rows with a raised earth edge."""
    p = Part("field_tilled")
    _bed(p)
    return [(p, (0, 0, 0))]


# crop stage: (height, stalk radius, leaves, leaf size, fruit count)
CROP_STAGES = {
    0: (0.09, 0.012, 2, (0.07, 0.05), 0),
    1: (0.24, 0.018, 3, (0.12, 0.085), 0),
    2: (0.40, 0.024, 3, (0.17, 0.12), 0),
    3: (0.46, 0.026, 3, (0.18, 0.13), 2),
}


def _crop_plant(p, x, y, z, stage, seed):
    h, r, nleaves, ls, nfruit = CROP_STAGES[stage]
    leaf_tile = "crop_leaf" if stage != 2 else "crop_leaf_dark"
    p.log((x, y, z), (x, y, z + h), r, tile="crop_leaf_dark", seg=5, end_tile="crop_leaf_dark")
    for i in range(nleaves):
        ang = 90.0 * i + 25.0 * ((seed + i) % 3)
        zz = z + h * (0.32 + 0.26 * i)
        # a leaf as a small tapered wedge, tilted out of the stalk: not a flat square
        lw, ld = ls
        tip = (x + math.cos(R(ang)) * lw * 0.75, y + math.sin(R(ang)) * lw * 0.75, zz + 0.03)
        p.prism([(x - math.sin(R(ang)) * ld * 0.5, y + math.cos(R(ang)) * ld * 0.5, zz),
                 (x + math.sin(R(ang)) * ld * 0.5, y - math.cos(R(ang)) * ld * 0.5, zz),
                 tip], (0, 0, -0.012), leaf_tile, tile_m=0.2)
    if nfruit:
        for i in range(nfruit):
            a = 40.0 * i + 20.0 * (seed % 5)
            rr = ls[0] * 0.85
            p.cyl(0.042, 0.07, (x + math.cos(R(a)) * rr, y + math.sin(R(a)) * rr, z + h * 0.7),
                  "clay", seg=6, cap_tile="clay_dark")


def _crop_rows(p, stage):
    """Crop rows standing on four of the five furrow ridges."""
    half = 0.93
    ridge_rows = 5
    pitch = 2 * half / ridge_rows
    for r in (0, 1, 2, 3):
        y = -half + pitch * (r + 0.5)
        n = 6
        for i in range(n):
            x = -0.75 + i * 1.5 / (n - 1)
            _crop_plant(p, x, y, 0.14, stage, r * 6 + i)


def _field_crop(stage):
    p = Part("field_crop_%d" % stage)
    _bed(p)
    _crop_rows(p, stage)
    return [(p, (0, 0, 0))]


def field_crop_0():
    """Seedlings: two tiny leaves per shoot on the tilled plot."""
    return _field_crop(0)


def field_crop_1():
    """Young plants: a stalk and three leaves."""
    return _field_crop(1)


def field_crop_2():
    """Grown plants: taller, darker, bushier."""
    return _field_crop(2)


def field_crop_3():
    """Ripe plants: full height with red-orange fruit, ready to harvest."""
    return _field_crop(3)


# ------------------------------------------------------------------ path tiles

def _grass_base(p, size=2.0):
    p.box((size, size, 0.014), (0, 0, 0.007), "grass", tile_m=1.0)


def _corner_grass(p):
    """The inside of the turn: a grass wedge in one corner, so four corners read as a loop."""
    p.box((0.98, 0.98, 0.045), (-0.5, -0.5, 0.0225), "grass", tile_m=0.9)


def path_dirt():
    """Packed dirt path tile, 2 x 2 m, 0.04 m high, with a grass fringe at the edges."""
    p = Part("path_dirt")
    _grass_base(p)
    p.box((1.82, 1.82, 0.032), (0, 0, 0.026), "dirt", tile_m=1.0)
    for i, (x, y, r) in enumerate(((-0.55, 0.42, 0.06), (0.48, -0.3, 0.05), (0.15, 0.62, 0.045), (-0.7, -0.55, 0.05))):
        p.rock(r, (x, y, 0.042), tile="stone", squash=(1.3, 1.0, 0.5), seed=210 + i)
    return [(p, (0, 0, 0))]


def path_dirt_corner():
    """Dirt path corner tile: the same surface with a grass wedge in the inside of the turn."""
    p = Part("path_dirt_corner")
    _grass_base(p)
    p.box((1.82, 1.82, 0.032), (0, 0, 0.026), "dirt", tile_m=1.0)
    _corner_grass(p)
    for i, (x, y, r) in enumerate(((0.5, 0.45, 0.055), (-0.2, 0.66, 0.05), (0.62, -0.1, 0.05))):
        p.rock(r, (x, y, 0.042), tile="stone", squash=(1.3, 1.0, 0.5), seed=220 + i)
    return [(p, (0, 0, 0))]


def _stone_slab(p):
    p.box((1.86, 1.86, 0.026), (0, 0, 0.027), "soil_dark", tile_m=1.0)
    stones = ((-0.55, -0.5, 0.46, 0.42), (0.02, -0.52, 0.5, 0.4), (0.6, -0.42, 0.42, 0.5),
              (-0.6, 0.08, 0.44, 0.46), (0.0, 0.06, 0.52, 0.44), (0.58, 0.12, 0.46, 0.44),
              (-0.5, 0.66, 0.5, 0.38), (0.1, 0.64, 0.44, 0.42), (0.62, 0.64, 0.42, 0.4))
    for i, (x, y, w, d) in enumerate(stones):
        p.box((w, d, 0.026), (x, y, 0.038), "cobble", rot=(0, 0, 12 * (i % 5) - 24), tile_m=0.5)


def path_stone():
    """Stone path tile, 2 x 2 m: flat cobbles bedded in dirt, grass at the edges."""
    p = Part("path_stone")
    _grass_base(p)
    _stone_slab(p)
    return [(p, (0, 0, 0))]


def path_stone_corner():
    """Stone path corner tile: cobbles with a grass wedge in the inside of the turn."""
    p = Part("path_stone_corner")
    _grass_base(p)
    _stone_slab(p)
    _corner_grass(p)
    return [(p, (0, 0, 0))]


# ------------------------------------------------------------------ farm props

def fence_post_rail():
    """A 2 m rail fence run: two sharpened posts, two rails and rope lashings."""
    p = Part("fence_post_rail")
    for x in (-0.92, 0.92):
        p.cyl(0.07, 1.2, (x, 0, 0.6), "bark", seg=7, cap_tile="log_end")
        p.cyl(0.07, 0.22, (x, 0, 1.3), "wood", seg=7, r2=0.012, cap_tile="log_end")
        for z in (0.46, 0.98):
            p.cyl(0.085, 0.07, (x, 0, z), "rope", seg=7)
    for z in (0.46, 0.98):
        p.log((-1.0, -0.085, z), (1.0, -0.085, z), 0.045, tile="wood")
    p.log((-0.92, -0.06, 0.18), (0.0, -0.06, 0.9), 0.028, tile="wood_dark", seg=5)
    p.log((0.0, -0.06, 0.9), (0.92, -0.06, 0.18), 0.028, tile="wood_dark", seg=5)
    return [(p, (0, 0, 0))]


def _gate_leaf():
    """The swinging leaf: hinges on the left post, so the part origin is on the hinge."""
    p = Part("Leaf")
    span = 1.66
    for z in (0.36, 1.06):
        p.box((span, 0.06, 0.1), (span / 2, -0.03, z), "wood")
    n = 6
    for i in range(n):
        x = 0.07 + i * (span - 0.14) / (n - 1)
        p.box((0.11, 0.04, 1.14), (x, 0.02, 0.68), "weathered")
        p.cyl(0.05, 0.12, (x, 0.02, 1.32), "weathered", seg=4, r2=0.005)
    p.plank((0.08, -0.075, 0.42), (span - 0.08, -0.075, 1.0), 0.09, 0.04, "wood_dark", up=(0, -1, 0))
    for z in (0.36, 1.06):
        p.box((0.16, 0.08, 0.06), (0.06, -0.03, z), "leather_dark")
    return p


def fence_post_rail_gate():
    """A 2 m gate run: two posts with a lintel and one hinged leaf (node Leaf, origin on the hinge)."""
    frame = Part("fence_post_rail_gate")
    for x in (-0.92, 0.92):
        frame.cyl(0.085, 1.5, (x, 0, 0.75), "bark", seg=8, cap_tile="log_end")
        frame.cyl(0.09, 0.2, (x, 0, 1.6), "wood", seg=8, r2=0.01, cap_tile="log_end")
    frame.log((-0.98, 0, 1.5), (0.98, 0, 1.5), 0.06, tile="wood")
    for x in (-0.92, 0.92):
        frame.cyl(0.1, 0.08, (x, 0, 1.5), "rope", seg=7)
        frame.rock(0.1, (x, -0.11, 0.045), squash=(1.2, 1, 0.55), seed=int(x * 10) + 5)
    leaf = _gate_leaf()
    return [(frame, (0, 0, 0)), (leaf, (-0.86, 0, 0))]


def trellis():
    """A bean trellis: an A-frame of poles with a lattice and climbing vines (1.2 x 1.7 m)."""
    p = Part("trellis")
    for sx in (-1, 1):
        p.log((sx * 0.6, 0.16, 0), (sx * 0.6, 0.0, 1.7), 0.045, tile="wood", seg=6)
        p.log((sx * 0.6, -0.16, 0), (sx * 0.6, 0.0, 1.7), 0.045, tile="wood", seg=6)
    for z in (0.42, 0.9, 1.38, 1.66):
        p.log((-0.62, 0, z), (0.62, 0, z), 0.032, tile="wood_dark", seg=5)
    for sx in (-1, 1):
        for k in (0.28, 0.66):
            p.log((-0.6, 0.0, k * 1.7), (0.6, 0.0, (k + 0.34) * 1.7), 0.022, tile="wood_dark", seg=5)
    # vines: two stems up the frame with leaves
    for sx in (-1, 1):
        x = sx * 0.42
        p.log((x, 0.04, 0), (x, 0.02, 1.55), 0.022, tile="crop_leaf_dark", seg=5, end_tile="crop_leaf_dark")
        for i in range(5):
            z = 0.3 + i * 0.28
            p.box((0.17, 0.12, 0.012), (x - 0.06 if i % 2 else x + 0.06, 0.02, z), "crop_leaf",
                  rot=(0, 12, 30 * i))
    p.cyl(0.03, 0.05, (0, 0.02, 1.62), "rope", seg=6)
    return [(p, (0, 0, 0))]


def scarecrow():
    """A scarecrow on a cross frame: straw head, cloth body and a straw hat (1.9 m tall)."""
    p = Part("scarecrow")
    p.log((0, 0, 0), (0, 0, 1.62), 0.055, tile="wood", seg=6)
    p.log((-0.46, 0, 1.24), (0.46, 0, 1.24), 0.04, tile="wood", seg=6)
    p.log((0, 0, 1.42), (0, 0, 1.9), 0.028, tile="wood_dark", seg=5)
    # straw head
    p.cyl(0.11, 0.22, (0, 0, 1.62), "fiber", seg=8, r2=0.1, cap_tile="straw")
    p.cyl(0.19, 0.03, (0, 0, 1.73), "straw", seg=10, cap_tile="straw")
    p.cyl(0.09, 0.11, (0, 0, 1.78), "straw", seg=8, r2=0.02, cap_tile="straw")
    # cloth body: a shirt on the frame
    p.box((0.44, 0.14, 0.56), (0, 0, 1.06), "canvas", tile_m=0.6)
    p.box((0.3, 0.16, 0.26), (0.12, 0, 1.22), "canvas", rot=(0, 0, 12), tile_m=0.4)
    # straw hands
    for sx in (-1, 1):
        p.cyl(0.07, 0.18, (sx * 0.44, 0, 1.22), "straw", seg=6, cap_tile="straw", rot=(0, 90, 0))
    # rope ties
    p.cyl(0.13, 0.04, (0, 0, 1.3), "rope", seg=8)
    p.cyl(0.055, 0.05, (0, 0, 1.18), "rope", seg=6)
    return [(p, (0, 0, 0))]


def compost_heap():
    """A compost heap: a mound of compost with straw and a couple of planks leaned on it."""
    p = Part("compost_heap")
    heap = ((0.0, 0.0, 0.22, 0.3), (-0.24, 0.12, 0.17, 0.22), (0.22, -0.1, 0.16, 0.2),
            (0.1, 0.24, 0.14, 0.18), (-0.18, -0.22, 0.14, 0.17), (0.34, 0.2, 0.12, 0.15),
            (-0.38, 0.02, 0.12, 0.14), (0.02, -0.32, 0.12, 0.14))
    for i, (x, y, r, h) in enumerate(heap):
        p.rock(r, (x, y, h * 0.42), tile="compost", squash=(1.15, 1.0, h / r * 0.9), seed=300 + i)
    for i, (x, y, a) in enumerate(((-0.1, 0.02, 12), (0.16, 0.14, -20), (0.02, -0.12, 34))):
        p.box((0.26, 0.05, 0.02), (x, y, 0.24 + i * 0.03), "straw", rot=(0, 0, a))
    p.plank((-0.5, 0.3, 0.05), (-0.34, 0.36, 0.46), 0.14, 0.04, "wood_dark")
    p.plank((0.46, -0.3, 0.05), (0.3, -0.36, 0.42), 0.13, 0.04, "wood_dark")
    return [(p, (0, 0, 0))]


def water_trough():
    """A wooden water trough with an iron band and a water surface (1.5 x 0.6 x 0.55 m)."""
    p = Part("water_trough")
    L, W, H = 1.5, 0.6, 0.52
    t = 0.06
    for sx in (-1, 1):
        p.box((t, W, H), (sx * (L / 2 - t / 2), 0, H / 2), "plank", tile_m=1.0)
    for sy in (-1, 1):
        p.box((L - 2 * t, t, H), (0, sy * (W / 2 - t / 2), H / 2), "plank", tile_m=1.0)
    p.box((L - 2 * t, W - 2 * t, t), (0, 0, t / 2 + 0.04), "plank", tile_m=1.0)
    for sx in (-1, 1):
        p.box((0.1, W + 0.03, 0.05), (sx * 0.42, 0, 0.18), "iron")
        p.box((0.1, W + 0.03, 0.05), (sx * 0.42, 0, 0.42), "iron")
    # the water inside, just below the rim
    p.box((L - 2 * t - 0.02, W - 2 * t - 0.02, 0.02), (0, 0, 0.42), "water")
    p.rock(0.07, (0.3, -0.05, 0.44), tile="stone", squash=(1.2, 1.0, 0.35), seed=340)
    return [(p, (0, 0, 0))]


FARM_BUILDERS = {
    "field_tilled": field_tilled,
    "field_crop_0": field_crop_0,
    "field_crop_1": field_crop_1,
    "field_crop_2": field_crop_2,
    "field_crop_3": field_crop_3,
    "path_dirt": path_dirt,
    "path_dirt_corner": path_dirt_corner,
    "path_stone": path_stone,
    "path_stone_corner": path_stone_corner,
    "fence_post_rail": fence_post_rail,
    "fence_post_rail_gate": fence_post_rail_gate,
    "trellis": trellis,
    "scarecrow": scarecrow,
    "compost_heap": compost_heap,
    "water_trough": water_trough,
}
