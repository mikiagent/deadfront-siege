"""Builders for every structure in the set. Each returns [(Part, origin_xyz), ...]; one Part per
glTF node. Most structures are one node; the gate has hinged leaves and the catapult a pivoting arm.

Axes (Blender, Z up): the front faces -Y, which becomes +Z in Godot (towards the iso camera).
Footprints follow game/data/props_manifest.json: X is the first footprint number, Y the second.
"""
import math

from mathutils import Euler, Vector

from lib import Part

R = math.radians


def _ring(n, radius, z=0.0, phase=0.0):
    return [(math.cos(phase + i * 2 * math.pi / n) * radius,
             math.sin(phase + i * 2 * math.pi / n) * radius, z) for i in range(n)]


def _teepee(p, n, base_r, top_z, r, seed=0, phase=0.3, tile="bark", end="char"):
    for i, (x, y, _) in enumerate(_ring(n, base_r, 0.0, phase)):
        p.log((x, y, 0.04), (x * 0.12, y * 0.12, top_z), r, tile=tile, end_tile=end)


def _stone_ring(p, n, radius, size, seed, tile="stone", z=0.0, squash=(1.2, 1.0, 0.75)):
    for i, (x, y, _) in enumerate(_ring(n, radius, 0, 0.2)):
        s = size * (0.85 + 0.3 * ((i * 37 + seed) % 7) / 6)
        p.rock(s, (x, y, z + s * squash[2] * 0.9), tile=tile, squash=squash, seed=seed + i)


# ------------------------------------------------------------------ camp

def tent():
    """Canvas A-frame on crossed poles, guy ropes and pegs, open flap at the front (3x3)."""
    p = Part("tent")
    hw, hl, top = 1.25, 1.2, 2.0
    ang = math.degrees(math.atan2(top, hw))
    slope = math.hypot(top, hw) + 0.08
    for sx in (-1, 1):
        p.box((slope, 2 * hl + 0.16, 0.035), (sx * hw / 2, 0, top / 2), "canvas", rot=(0, sx * ang, 0), tile_m=1.3)
        # hide patches stitched on the canvas
        p.box((0.36, 0.42, 0.02), (sx * hw * 0.55, sx * 0.35, top * 0.45 + 0.02), "hide", rot=(0, sx * ang, 0))
    # back wall
    p.prism([(-hw, hl, 0.0), (hw, hl, 0.0), (0, hl, top)], (0, 0.03, 0), "canvas", tile_m=1.3)
    # front flaps tied back leave a dark doorway
    p.prism([(-hw, -hl, 0.0), (-0.42, -hl, 0.0), (-0.42 * 0.2, -hl, top * 0.85), (0, -hl, top)], (0, -0.03, 0), "canvas", tile_m=1.3)
    p.prism([(0.42, -hl, 0.0), (hw, -hl, 0.0), (0, -hl, top), (0.42 * 0.2, -hl, top * 0.85)], (0, -0.03, 0), "canvas", tile_m=1.3)
    p.prism([(-0.42, -hl + 0.6, 0.0), (0.42, -hl + 0.6, 0.0), (0, -hl + 0.6, top * 0.95)], (0, 0.02, 0), "soot")
    for sx in (-1, 1):  # rolled flaps
        p.log((sx * 0.45, -hl - 0.06, 0.15), (sx * 0.12, -hl - 0.06, top * 0.8), 0.07, tile="canvas", end_tile="canvas")
    # bedroll peeking out of the doorway
    p.box((0.6, 0.9, 0.12), (0, -hl + 0.2, 0.06), "hide")
    # poles: ridge and crossed end poles
    p.log((0, -hl - 0.18, top + 0.02), (0, hl + 0.18, top + 0.02), 0.05, tile="wood_dark")
    for y in (-hl - 0.07, hl + 0.07):
        for sx in (-1, 1):
            p.log((sx * (hw + 0.05), y, 0.0), (-sx * 0.16, y, top + 0.25), 0.045, tile="wood_dark")
    # guy ropes and pegs
    for y in (-1, 1):
        a = (0, y * (hl + 0.16), top)
        b = (0, y * 1.42, 0.06)
        p.log(a, b, 0.012, tile="rope", seg=4, end_tile="rope")
        p.log((0, y * 1.42, -0.02), (0, y * 1.44, 0.16), 0.03, tile="wood", seg=5)
    for sx in (-1, 1):
        for y in (-0.8, 0.0, 0.8):
            p.log((sx * (hw + 0.12), y, -0.02), (sx * (hw + 0.14), y, 0.14), 0.025, tile="wood", seg=5)
    return [(p, (0, 0, 0))]


def basket():
    """Woven storage basket with rope rim, handles and some contents showing (1x1)."""
    p = Part("basket")
    p.cyl(0.3, 0.06, (0, 0, 0.03), "weave", seg=12, r2=0.31, cap_tile="weave")
    p.cyl(0.31, 0.56, (0, 0, 0.34), "weave", seg=12, r2=0.4, cap_tile="fiber")
    p.cyl(0.41, 0.06, (0, 0, 0.62), "rope", seg=12, cap_tile="weave")
    p.cyl(0.36, 0.02, (0, 0, 0.65), "fiber", seg=12, cap_tile="fiber")
    for sx in (-1, 1):
        p.box((0.04, 0.16, 0.12), (sx * 0.41, 0, 0.56), "rope")
    # a bundle of fibre and a hide poking out show it is in use
    p.cyl(0.12, 0.3, (0.08, 0.05, 0.72), "fiber", rot=(20, 10, 0), seg=6, cap_tile="fiber")
    p.box((0.3, 0.2, 0.08), (-0.1, -0.08, 0.69), "hide", rot=(0, 12, 30))
    return [(p, (0, 0, 0))]


def workbench():
    """Plank top on lashed log legs, chopping stump, tools and a stock of planks (2x1)."""
    p = Part("workbench")
    L, W, H = 1.7, 0.72, 0.9
    for i, y in enumerate((-0.24, 0.0, 0.24)):
        p.box((L, 0.235, 0.07), (0, y, H - 0.035), "plank" if i != 1 else "wood", tile_m=1.8)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.log((sx * (L / 2 - 0.12), sy * (W / 2 - 0.08), 0), (sx * (L / 2 - 0.15), sy * (W / 2 - 0.12), H - 0.07), 0.05)
        p.plank((sx * (L / 2 - 0.14), -W / 2 + 0.08, 0.28), (sx * (L / 2 - 0.14), W / 2 - 0.08, 0.28), 0.07, 0.06, "wood_dark")
        p.cyl(0.07, 0.08, (sx * (L / 2 - 0.13), W / 2 - 0.1, H - 0.12), "rope", seg=6)
    p.box((L - 0.24, W - 0.2, 0.05), (0, 0, 0.32), "plank", tile_m=1.6)
    # stock of planks and a log on the shelf
    for i in range(3):
        p.box((1.0, 0.18, 0.05), (-0.1, -0.05 + i * 0.03, 0.37 + i * 0.05), "wood", rot=(0, 0, 4 * i))
    p.log((-0.6, 0.16, 0.42), (0.55, 0.16, 0.42), 0.07)
    # stone hammer
    p.log((0.1, -0.05, H + 0.03), (0.52, -0.2, H + 0.03), 0.022, tile="wood_dark", seg=5)
    p.rock(0.075, (0.52, -0.21, H + 0.06), tile="stone_dark", squash=(1.3, 0.9, 0.8), seed=4)
    # flint knife and a coil of cord
    p.box((0.22, 0.04, 0.02), (-0.15, -0.22, H + 0.01), "wood_dark")
    p.box((0.14, 0.05, 0.015), (-0.33, -0.22, H + 0.01), "stone_dark", rot=(0, 0, 8))
    p.cyl(0.09, 0.05, (-0.55, 0.12, H + 0.025), "rope", seg=10)
    # chopping stump with a hatchet beside the bench
    p.cyl(0.2, 0.45, (L / 2 + 0.02, -0.08, 0.225), "bark", seg=9, cap_tile="log_end")
    p.log((L / 2 - 0.05, -0.1, 0.45), (L / 2 + 0.12, -0.18, 0.72), 0.02, tile="wood_dark", seg=5)
    p.box((0.05, 0.14, 0.09), (L / 2 + 0.02, -0.09, 0.5), "stone_dark", rot=(0, 30, 20))
    return [(p, (0, 0, 0))]


def sign():
    """Post with a carved board and a small drip roof (1x1)."""
    p = Part("sign")
    p.log((0, 0, -0.02), (0, 0, 1.62), 0.055)
    p.box((0.78, 0.05, 0.42), (0, -0.07, 1.18), "sign_board", tile_m=0.8)
    for z in (1.02, 1.34):
        p.cyl(0.065, 0.06, (0, -0.02, z), "rope", seg=6)
    p.box((0.86, 0.22, 0.03), (0, -0.07, 1.45), "wood_dark", rot=(-12, 0, 0))
    p.box((0.32, 0.18, 0.06), (0, 0, 0.03), "stone")
    return [(p, (0, 0, 0))]


def fence():
    """Rail fence segment, 2 m, sharpened posts and lashings; meets its neighbours end to end (2x1)."""
    p = Part("fence")
    for x in (-0.92, 0.0, 0.92):
        p.cyl(0.07, 1.25, (x, 0, 0.625), "bark", seg=7, cap_tile="log_end")
        p.cyl(0.07, 0.22, (x, 0, 1.36), "wood", seg=7, r2=0.012, cap_tile="log_end")
        for z in (0.5, 1.02):
            p.cyl(0.085, 0.07, (x, 0, z), "rope", seg=7)
    for z in (0.5, 1.02):
        p.log((-1.0, -0.085, z), (1.0, -0.085, z), 0.045, tile="wood")
    p.log((-0.92, -0.06, 0.2), (0.0, -0.06, 0.92), 0.03, tile="wood_dark")
    p.log((0.0, -0.06, 0.92), (0.92, -0.06, 0.2), 0.03, tile="wood_dark")
    return [(p, (0, 0, 0))]


def _gate_leaf(name, side):
    """side -1: hinge on the left (x=-0.84), leaf spans to x=-0.02; +1 mirrored."""
    p = Part(name)
    hx = side * 0.84
    ix = side * 0.03
    span = (hx, ix)
    lo, hi = min(span), max(span)
    w = hi - lo
    for z in (0.32, 1.12):
        p.box((w, 0.06, 0.1), ((lo + hi) / 2, -0.03, z), "wood")
    n = 5
    for i in range(n):
        x = lo + 0.07 + i * (w - 0.14) / (n - 1)
        p.box((0.11, 0.04, 1.2), (x, 0.02, 0.72), "weathered")
        p.cyl(0.055, 0.12, (x, 0.02, 1.38), "weathered", seg=4, r2=0.005)
    a = (hx - side * 0.06, -0.075, 0.38)
    b = (ix + side * 0.06, -0.075, 1.06)
    p.plank(a, b, 0.09, 0.04, "wood_dark", up=(0, -1, 0))
    for z in (0.32, 1.12):  # hinge straps
        p.box((0.16, 0.08, 0.06), (hx + (-side) * 0.06, -0.03, z), "leather_dark")
    return p


def gate():
    """Two hinged leaves between lashed posts under a lintel. LeafL/LeafR origins sit on the hinges
    so code can swing them open (rotate about Y in Godot)."""
    frame = Part("gate")
    for sx in (-1, 1):
        frame.cyl(0.085, 1.82, (sx * 0.93, 0, 0.91), "bark", seg=8, cap_tile="log_end")
    frame.log((-1.0, 0, 1.76), (1.0, 0, 1.76), 0.07)
    for sx in (-1, 1):
        frame.cyl(0.1, 0.08, (sx * 0.93, 0, 1.76), "rope", seg=7)
        frame.rock(0.11, (sx * 0.93, -0.12, 0.05), squash=(1.2, 1, 0.6), seed=sx + 5)
    left = _gate_leaf("LeafL", -1)
    right = _gate_leaf("LeafR", 1)
    return [(frame, (0, 0, 0)), (left, (-0.84, 0, 0)), (right, (0.84, 0, 0))]


# ------------------------------------------------------------------ fires

def campfire():
    """Small cooking fire: stone ring, ember bed, log teepee (1x1)."""
    p = Part("campfire")
    _stone_ring(p, 9, 0.38, 0.1, 11)
    p.cyl(0.3, 0.03, (0, 0, 0.015), "ash", seg=10, cap_tile="ember")
    _teepee(p, 5, 0.26, 0.5, 0.035)
    p.log((-0.2, 0.12, 0.05), (0.2, -0.08, 0.05), 0.04, tile="char")
    return [(p, (0, 0, 0))]


def bonfire():
    """Big signal/cook fire: heavy stones, tall teepee of split logs (1x1)."""
    p = Part("bonfire")
    _stone_ring(p, 8, 0.38, 0.13, 21, tile="stone_dark")
    p.cyl(0.32, 0.04, (0, 0, 0.02), "ash", seg=10, cap_tile="ember")
    _teepee(p, 7, 0.3, 0.95, 0.05, phase=0.1)
    _teepee(p, 4, 0.18, 0.62, 0.04, phase=0.9, end="ember")
    return [(p, (0, 0, 0))]


def stone_fire_pit():
    """Two-course stone pit with a spit on forked posts (2x2)."""
    p = Part("stone_fire_pit")
    _stone_ring(p, 12, 0.66, 0.15, 31, tile="cobble")
    for i, (x, y, _) in enumerate(_ring(10, 0.64, 0, 0.5)):
        p.rock(0.12, (x, y, 0.24), tile="stone", squash=(1.3, 1, 0.65), seed=60 + i)
    p.cyl(0.55, 0.04, (0, 0, 0.02), "ash", seg=12, cap_tile="ember")
    p.log((-0.4, -0.15, 0.08), (0.4, 0.15, 0.08), 0.06, tile="char", end_tile="ember")
    p.log((-0.3, 0.3, 0.08), (0.35, -0.25, 0.1), 0.055, tile="char", end_tile="ember")
    _teepee(p, 4, 0.2, 0.42, 0.04, phase=0.4)
    for sx in (-1, 1):
        p.log((sx * 0.88, 0, 0), (sx * 0.88, 0, 0.78), 0.04, tile="wood_dark")
        p.log((sx * 0.88, 0, 0.7), (sx * 0.95, 0, 0.92), 0.025, tile="wood_dark")
        p.log((sx * 0.88, 0, 0.7), (sx * 0.81, 0, 0.92), 0.025, tile="wood_dark")
    p.log((-0.98, 0, 0.82), (0.98, 0, 0.82), 0.025, tile="wood")
    p.cyl(0.09, 0.32, (0.05, 0, 0.82), "meat_drying", rot=(0, 90, 0), seg=8, cap_tile="meat_drying")
    return [(p, (0, 0, 0))]


# ------------------------------------------------------------------ processing stations

STRIP_STAGES = {
    # stage: (tile, width, length, thickness, curl degrees, shrink of hang point)
    "raw": ("meat_raw", 0.12, 0.5, 0.03, 0.0),
    "drying": ("meat_drying", 0.105, 0.44, 0.022, 9.0),
    "dried": ("meat_dried", 0.105, 0.38, 0.016, 18.0),  # length shrinks, width kept so the dark mass reads
}


def _rack_frame(p):
    for sx in (-1, 1):
        x = sx * 0.84
        for sy in (-1, 1):
            p.log((x, sy * 0.36, 0), (x, -sy * 0.06, 1.74), 0.04)
        p.cyl(0.06, 0.07, (x, 0, 1.6), "rope", rot=(90, 0, 0), seg=6)
        p.log((x, -0.34, 1.02), (x, 0.34, 1.02), 0.03, tile="wood")
    p.log((-0.97, 0, 1.62), (0.97, 0, 1.62), 0.035, tile="wood")
    for sy in (-1, 1):
        p.log((-0.97, sy * 0.27, 1.07), (0.97, sy * 0.27, 1.07), 0.03, tile="wood")
    # coil of cord and a hide mat beneath the rack to catch drips
    p.box((1.3, 0.62, 0.02), (0, 0, 0.01), "hide")


def _strips(p, stage, seed):
    tile, w, ln, t, curl = STRIP_STAGES[stage]
    poles = [(0.0, 1.62, 0.035), (-0.27, 1.07, 0.03), (0.27, 1.07, 0.03)]
    for pi, (y, z, r) in enumerate(poles):
        n = 6
        for i in range(n):
            x = -0.68 + i * 1.36 / (n - 1) + (0.03 if pi else 0.0)
            k = (i * 7 + pi * 3 + seed) % 5 - 2
            c = curl * (1 if (i + pi) % 2 else -1)
            length = ln * (0.85 + 0.06 * k)
            # fold over the pole, then the hanging tongue on the camera side
            p.box((w, 2 * r + t * 2, t * 1.6), (x, y, z + r + t * 0.5), tile)
            p.box((w, t, length), (x, y - r - t / 2, z - length / 2), tile, rot=(c, 0, c * 0.6))
            if stage == "dried":
                # near-black jerky renders at the same value as the dark dirt disc behind it, so thin
                # amber fat rims down BOTH edges outline each strip at gameplay zoom. One wide rim
                # (30 %) out-read the dark body and the rack looked like orange sticks.
                rot = (c, 0, c * 0.6)
                for side in (-1, 1):
                    off = Euler([R(a) for a in rot], "XYZ").to_matrix() @ Vector((side * w * 0.43, -t * 0.3, 0))
                    centre = Vector((x, y - r - t / 2, z - length / 2)) + off
                    p.box((w * 0.14, t * 1.2, length * 0.96), tuple(centre), "meat_fat", rot=rot)
            p.box((w * 0.9, t, length * 0.6), (x, y + r + t / 2, z - length * 0.3), tile, rot=(-c, 0, 0))


def drying_rack(stage="empty"):
    """A-frame rack, three poles. Stages: empty, raw (bright red), drying (darker, curling),
    dried (leathery brown, thinner, curled). The frame is identical in every stage so swapping the
    model reads as the meat changing."""
    name = "drying_rack" if stage == "empty" else "drying_rack_" + stage
    p = Part(name)
    _rack_frame(p)
    if stage != "empty":
        _strips(p, stage, {"raw": 1, "drying": 2, "dried": 3}[stage])
    if stage == "dried":  # a tied bundle of finished jerky waiting on the mat
        for i in range(4):
            p.box((0.07, 0.36, 0.015), (0.35 + i * 0.015, -0.05, 0.035 + i * 0.016), "meat_dried", rot=(0, 0, 12 * i))
        p.cyl(0.05, 0.08, (0.37, -0.05, 0.06), "rope", rot=(90, 0, 0), seg=6)
    return [(p, (0, 0, 0))]


def smoker():
    """Stone firebox under a plank smokehouse with a thatch roof; the door hangs open on dark,
    smoked strips (2x2)."""
    p = Part("smoker")
    S, H0, H1 = 1.5, 0.45, 1.55
    p.box((S, S, H0), (0, 0, H0 / 2), "cobble", tile_m=0.9)
    p.box((0.46, 0.04, 0.26), (0, -S / 2 - 0.01, 0.17), "soot")
    p.box((0.4, 0.05, 0.12), (0, -S / 2 - 0.02, 0.07), "ember")
    hs = 0.65
    wall_t = 0.07
    # back and side walls
    p.box((2 * hs, wall_t, H1 - H0), (0, hs, (H0 + H1) / 2), "plank", tile_m=1.3)
    for sx in (-1, 1):
        p.box((wall_t, 2 * hs, H1 - H0), (sx * hs, 0, (H0 + H1) / 2), "plank", rot=(0, 0, 0), tile_m=1.3)
    # front wall with a doorway
    door_w = 0.56
    side_w = hs - door_w / 2
    for sx in (-1, 1):
        p.box((side_w, wall_t, H1 - H0), (sx * (door_w / 2 + side_w / 2), -hs, (H0 + H1) / 2), "plank", tile_m=1.3)
    p.box((door_w, wall_t, 0.22), (0, -hs, H1 - 0.11), "plank")
    p.box((2 * hs - 0.1, 2 * hs - 0.1, H1 - H0 - 0.02), (0, 0.0, (H0 + H1) / 2), "soot")
    # open door leaf, hinged on the left
    # swung right round so it lies back against the front wall: open, but inside the footprint
    sw = math.radians(-160.0)
    dh = door_w * 0.5
    p.box((door_w, 0.05, H1 - H0 - 0.25),
          (-door_w / 2 + math.cos(sw) * dh, -hs - 0.06 + math.sin(sw) * dh, H0 + (H1 - H0 - 0.25) / 2),
          "weathered", rot=(0, 0, -160.0))
    # strips smoking inside, seen through the doorway
    for i in range(4):
        x = -0.18 + i * 0.12
        p.box((0.08, 0.02, 0.36), (x, -hs + 0.18, H1 - 0.36), "meat_dried", rot=(0, 0, 8 * (i - 1.5)))
    p.log((-0.3, -hs + 0.18, H1 - 0.16), (0.3, -hs + 0.18, H1 - 0.16), 0.02, tile="wood")
    # corner posts
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.cyl(0.05, H1 - H0 + 0.05, (sx * hs, sy * hs, (H0 + H1) / 2), "bark", seg=6, cap_tile="log_end")
    # thatch roof, ridge along X
    ang = 35.0
    run = hs + 0.1
    rl = run / math.cos(R(ang))
    rise = run * math.tan(R(ang))
    for sy in (-1, 1):
        p.box((2 * hs + 0.2, rl, 0.12), (0, sy * run / 2, H1 + rise / 2), "thatch", rot=(-sy * ang, 0, 0), tile_m=1.5)
    p.log((-hs - 0.12, 0, H1 + rise + 0.03), (hs + 0.12, 0, H1 + rise + 0.03), 0.05, tile="wood_dark")
    # clay smoke vent
    p.cyl(0.09, 0.32, (0.32, 0.2, H1 + rise * 0.7 + 0.1), "clay", seg=8, cap_tile="soot")
    return [(p, (0, 0, 0))]


def _pot(p, cx, cy, z0, scale=1.0, tile="clay"):
    s = scale
    prof = [(0.22, 0.0), (0.36, 0.14), (0.42, 0.3), (0.38, 0.48), (0.28, 0.6), (0.3, 0.66)]
    for (r0, z0a), (r1, z1a) in zip(prof, prof[1:]):
        p.cyl(r0 * s, (z1a - z0a) * s, (cx, cy, z0 + (z0a + z1a) / 2 * s), tile, seg=12, r2=r1 * s,
              cap_tile="clay_dark")
    return z0 + 0.66 * s


def crock_pot():
    """Big clay crock on three stones over embers, lid and wooden ladle (2x2)."""
    p = Part("crock_pot")
    _stone_ring(p, 10, 0.62, 0.13, 41)
    p.cyl(0.5, 0.03, (0, 0, 0.015), "ash", seg=12, cap_tile="ember")
    _teepee(p, 4, 0.35, 0.25, 0.04, phase=0.8, end="ember")
    for i, (x, y, _) in enumerate(_ring(3, 0.24, 0, 0.5)):
        p.rock(0.09, (x, y, 0.08), tile="stone_dark", squash=(1, 1, 1.3), seed=70 + i)
    top = _pot(p, 0, 0, 0.18, 1.15)
    p.cyl(0.33, 0.05, (0, 0, top + 0.02), "clay_dark", seg=12, cap_tile="clay_dark")
    p.cyl(0.05, 0.07, (0, 0, top + 0.08), "clay_dark", seg=6)
    p.log((0.2, -0.1, top + 0.0), (0.62, -0.32, top + 0.32), 0.018, tile="wood", seg=5)
    p.cyl(0.06, 0.04, (0.18, -0.09, top - 0.01), "wood", seg=8)
    return [(p, (0, 0, 0))]


def steamer():
    """Clay water pot on stones under two stacked woven steamer trays and a domed lid (1x1)."""
    p = Part("steamer")
    _stone_ring(p, 6, 0.28, 0.09, 51, tile="stone_dark")
    p.cyl(0.22, 0.03, (0, 0, 0.015), "ash", seg=10, cap_tile="ember")
    top = _pot(p, 0, 0, 0.12, 0.8)
    z = top
    for i in range(2):
        p.cyl(0.34, 0.15, (0, 0, z + 0.075), "steamer_weave", seg=12, cap_tile="steamer_weave")
        p.cyl(0.355, 0.025, (0, 0, z + 0.14), "rope", seg=12, cap_tile="steamer_weave")
        z += 0.155
    p.cyl(0.35, 0.18, (0, 0, z + 0.09), "steamer_weave", seg=12, r2=0.08, cap_tile="weave")
    p.cyl(0.04, 0.05, (0, 0, z + 0.2), "wood", seg=6)
    return [(p, (0, 0, 0))]


def mortar():
    """Stone bowl on a stump with a wooden pestle and a pinch of ground meal (1x1)."""
    p = Part("mortar")
    p.cyl(0.27, 0.5, (0, 0, 0.25), "bark", seg=10, r2=0.24, cap_tile="log_end")
    p.cyl(0.2, 0.2, (0, 0, 0.6), "stone", seg=10, r2=0.27, cap_tile="stone_dark")
    p.cyl(0.21, 0.02, (0, 0, 0.67), "meat_raw", seg=10, cap_tile="meat_raw")
    p.log((0.02, 0.0, 0.62), (0.2, -0.16, 1.05), 0.035, tile="wood", seg=6)
    p.rock(0.05, (0.02, 0.0, 0.66), tile="wood", squash=(1, 1, 1), seed=3)
    for i, (x, y, _) in enumerate(_ring(3, 0.36, 0, 1.1)):
        p.rock(0.07, (x, y, 0.04), tile="stone", squash=(1.2, 1, 0.6), seed=80 + i)
    return [(p, (0, 0, 0))]


def well():
    """Stone-ringed well with water, windlass, rope and bucket under a little plank roof (2x2)."""
    p = Part("well")
    n = 12
    for course, (rr, z, ph) in enumerate(((0.68, 0.18, 0.0), (0.68, 0.52, math.pi / n))):
        for i, (x, y, _) in enumerate(_ring(n, rr, 0, ph)):
            a = math.degrees(math.atan2(y, x))
            p.box((0.24, 0.36, 0.33), (x, y, z), "cobble", rot=(0, 0, a), tile_m=0.6)
    p.cyl(0.6, 0.04, (0, 0, 0.6), "water", seg=12, cap_tile="water")
    p.cyl(0.6, 0.02, (0, 0, 0.02), "stone_dark", seg=12, cap_tile="stone_dark")
    for sx in (-1, 1):
        p.log((sx * 0.86, 0, 0), (sx * 0.86, 0, 2.02), 0.06)
    p.log((-0.95, 0, 1.45), (0.95, 0, 1.45), 0.07, tile="wood")
    p.cyl(0.1, 0.42, (0.1, 0, 1.45), "rope", rot=(0, 90, 0), seg=10)
    p.plank((0.95, 0, 1.45), (0.95, -0.25, 1.45), 0.05, 0.05, "wood_dark")
    p.log((0.95, -0.25, 1.45), (0.95, -0.25, 1.3), 0.025, tile="wood_dark", seg=5)
    p.log((0.1, -0.1, 1.38), (0.1, -0.1, 0.95), 0.012, tile="rope", seg=4, end_tile="rope")
    p.cyl(0.14, 0.2, (0.1, -0.1, 0.85), "wood", seg=8, r2=0.16, cap_tile="water")
    p.box((0.32, 0.02, 0.03), (0.1, -0.1, 0.98), "iron")
    ang = 32.0
    run = 0.62
    rl = run / math.cos(R(ang))
    rise = run * math.tan(R(ang))
    for sy in (-1, 1):
        p.box((1.96, rl, 0.06), (0, sy * run / 2, 2.0 + rise / 2), "plank", rot=(-sy * ang, 0, 0), tile_m=1.6)
    p.log((-0.98, 0, 2.0 + rise + 0.03), (0.98, 0, 2.0 + rise + 0.03), 0.045, tile="wood_dark")
    return [(p, (0, 0, 0))]


# ------------------------------------------------------------------ siege + harbour

def catapult():
    """Wheeled mangonel: plank chassis on four textured wheels, A-frame with a padded stop beam,
    torsion bundle and a throwing arm (node Arm, origin on its axle) with a hide-lined cup (3x3)."""
    body = Part("catapult")
    L, Wd = 2.5, 1.2
    z = 0.52
    for sy in (-1, 1):
        body.plank((-L / 2, sy * Wd / 2, z), (L / 2, sy * Wd / 2, z), 0.14, 0.16, "wood_dark")
        for x in (-0.9, 0.0, 0.9):
            body.box((0.06, 0.18, 0.2), (x, sy * Wd / 2, z), "iron")
    for x in (-1.1, -0.35, 0.5, 1.1):
        body.plank((x, -Wd / 2, z + 0.06), (x, Wd / 2, z + 0.06), 0.13, 0.12, "wood")
    body.box((1.0, Wd - 0.1, 0.05), (-0.75, 0, z + 0.14), "plank", tile_m=1.2)
    # wheels and axles
    for x in (-0.85, 0.85):
        body.log((x, -0.86, 0.4), (x, 0.86, 0.4), 0.045, tile="wood_dark")
        for sy in (-1, 1):
            body.cyl(0.4, 0.12, (x, sy * 0.78, 0.4), "iron", rot=(90, 0, 0), seg=14, cap_tile="wheel", smooth=False)
            body.cyl(0.08, 0.2, (x, sy * 0.78, 0.4), "wood_dark", rot=(90, 0, 0), seg=8, cap_tile="log_end")
    # A-frame uprights and stop beam
    for sy in (-1, 1):
        y = sy * (Wd / 2 - 0.05)
        body.log((0.95, y, z), (0.62, y, 1.72), 0.06, tile="wood")
        body.log((0.15, y, z), (0.6, y, 1.72), 0.06, tile="wood")
    body.log((0.6, -Wd / 2 - 0.04, 1.7), (0.6, Wd / 2 + 0.04, 1.7), 0.08, tile="wood_dark")
    body.cyl(0.13, 0.45, (0.6, 0, 1.7), "hide", rot=(90, 0, 0), seg=8, cap_tile="hide")
    # torsion bundle around the arm axle
    body.cyl(0.15, Wd - 0.1, (-0.25, 0, z + 0.2), "rope", rot=(90, 0, 0), seg=10, cap_tile="rope")
    body.log((-0.25, -Wd / 2 - 0.05, z + 0.2), (-0.25, Wd / 2 + 0.05, z + 0.2), 0.04, tile="iron", end_tile="iron")
    # ammunition stones on the deck
    for i, (x, y) in enumerate(((-0.95, -0.25), (-0.75, 0.2), (-1.05, 0.15))):
        body.rock(0.13, (x, y, z + 0.27), tile="stone", squash=(1, 1, 0.9), seed=90 + i)
    arm = Part("Arm")
    pv = (-0.25, 0.0, z + 0.2)
    tip = (-1.2, 0.0, z + 0.66)
    arm.log(pv, (tip[0], 0, tip[2]), 0.065, tile="wood")
    for t in (0.25, 0.6):
        x = pv[0] + (tip[0] - pv[0]) * t
        zz = pv[2] + (tip[2] - pv[2]) * t
        arm.cyl(0.08, 0.06, (x, 0, zz), "iron", rot=(0, 90 - 21.8, 0), seg=8)
    arm.cyl(0.17, 0.14, (tip[0] - 0.05, 0, tip[2] + 0.08), "hide", seg=10, r2=0.21, cap_tile="leather_dark")
    arm.rock(0.11, (tip[0] - 0.05, 0, tip[2] + 0.2), tile="stone", squash=(1, 1, 0.9), seed=99)
    return [(body, (0, 0, 0)), (arm, pv)]


def pier():
    """Plank dock on log piles, 3 x 8 m, deck 1.2 m above the pile feet, mooring posts and a
    coil of rope at the seaward end (+Y in Blender = -Z in Godot)."""
    p = Part("pier")
    hw, hl, deck = 1.38, 3.9, 1.2
    ys = [-hl + 0.15 + i * (2 * hl - 0.3) / 4 for i in range(5)]
    for y in ys:
        for sx in (-1, 1):
            p.log((sx * (hw - 0.1), y, 0.0), (sx * (hw - 0.1), y, deck - 0.12), 0.11)
        p.plank((-hw, y, deck - 0.2), (hw, y, deck - 0.2), 0.14, 0.12, "wood_dark")
    for x in (-hw + 0.25, 0.0, hw - 0.25):
        p.plank((x, -hl, deck - 0.1), (x, hl, deck - 0.1), 0.14, 0.1, "wood_dark")
    n = 26
    step = 2 * hl / n
    for i in range(n):
        y = -hl + (i + 0.5) * step
        # each board is three ~0.9 m lengths with staggered butt joints, so the grain tile maps at
        # ~1 m instead of being stretched across the whole deck width
        cuts = [-hw, -hw / 3 + 0.25 * ((i % 3) - 1), hw / 3 + 0.25 * ((i % 3) - 1), hw]
        for a, b in zip(cuts, cuts[1:]):
            p.box((b - a - 0.025, step - 0.035, 0.06), ((a + b) / 2, y, deck - 0.03), "weathered", tile_m=1.0)
    for sx in (-1, 1):
        p.cyl(0.1, 0.5, (sx * (hw - 0.1), hl - 0.15, deck + 0.25), "bark", seg=7, cap_tile="log_end")
        p.cyl(0.115, 0.08, (sx * (hw - 0.1), hl - 0.15, deck + 0.3), "rope", seg=7)
    p.cyl(0.22, 0.1, (0.6, hl - 0.6, deck + 0.05), "rope", seg=10, cap_tile="rope")
    p.box((0.5, 0.5, 0.45), (-0.7, hl - 0.8, deck + 0.225), "plank", tile_m=0.6)
    return [(p, (0, 0, 0))]


# ------------------------------------------------------------------ building-system stand-ins
# ASSUMPTION: 1 m pieces (manifest footprints are 1x1); W2-BUILDSYS sets the real module size.

def floor():
    p = Part("floor")
    for x in (-0.38, 0.38):
        p.log((x, -0.5, 0.07), (x, 0.5, 0.07), 0.07)
    for i in range(5):
        y = -0.4 + i * 0.2
        p.box((1.0, 0.19, 0.05), (0, y, 0.175), "plank" if i % 2 else "wood", tile_m=1.0)
    return [(p, (0, 0, 0))]


def wall():
    p = Part("wall")
    _log_courses(p, -0.5, 0.5, 0.0, 2.4)
    return [(p, (0, 0, 0))]


def _log_courses(p, x0, x1, z0, z1, r=0.12):
    z = z0 + r
    i = 0
    while z + r <= z1 + 1e-6:
        p.log((x0, 0, z), (x1, 0, z), r * (0.96 if i % 2 else 1.0))
        z += 2 * r * 0.98
        i += 1
    p.box((x1 - x0, 0.08, 0.08), ((x0 + x1) / 2, -0.06, z1 - 0.04), "wood_dark")


def wall_doorway():
    p = Part("wall_doorway")
    for sx in (-1, 1):
        p.box((0.12, 0.24, 2.4), (sx * 0.44, 0, 1.2), "wood")
    _log_courses(p, -0.5, 0.5, 1.92, 2.4)
    p.plank((-0.42, -0.08, 1.9), (0.42, -0.08, 1.9), 0.06, 0.1, "wood_dark", up=(0, -1, 0))
    p.box((0.76, 0.24, 0.04), (0, 0, 0.02), "plank")
    return [(p, (0, 0, 0))]


def roof():
    p = Part("roof")
    ang = math.degrees(math.atan2(0.6, 1.0))
    rl = math.hypot(1.0, 0.6)
    for x in (-0.4, 0.4):
        p.plank((x, -0.5, 0.05), (x, 0.5, 0.65), 0.07, 0.07, "wood_dark")
    p.box((1.0, rl - 0.04, 0.1), (0, 0, 0.36), "thatch", rot=(ang, 0, 0), tile_m=1.2)
    return [(p, (0, 0, 0))]


BUILDERS = {
    "tent": tent,
    "basket": basket,
    "workbench": workbench,
    "sign": sign,
    "fence": fence,
    "gate": gate,
    "campfire": campfire,
    "bonfire": bonfire,
    "stone_fire_pit": stone_fire_pit,
    "drying_rack": lambda: drying_rack("empty"),
    "drying_rack_raw": lambda: drying_rack("raw"),
    "drying_rack_drying": lambda: drying_rack("drying"),
    "drying_rack_dried": lambda: drying_rack("dried"),
    "smoker": smoker,
    "crock_pot": crock_pot,
    "steamer": steamer,
    "mortar": mortar,
    "well": well,
    "catapult": catapult,
    "pier": pier,
    "floor": floor,
    "wall": wall,
    "wall_doorway": wall_doorway,
    "roof": roof,
}
