"""Builders for every structure in the set. Each returns [(Part, origin_xyz), ...]; one Part per
glTF node. Most structures are one node; the gate has hinged leaves and the catapult a pivoting arm.

Axes (Blender, Z up): the front faces -Y, which becomes +Z in Godot (towards the iso camera).
The tent is the exception: its door faces +X in Godot so the camera sees a sunlit slope at rot 0.
Footprints follow game/data/props_manifest.json: X is the first footprint number, Y the second.
"""
import math
import zlib

import bmesh
from mathutils import Euler, Matrix, Vector

from lib import Part

R = math.radians


def _ring(n, radius, z=0.0, phase=0.0):
    return [(math.cos(phase + i * 2 * math.pi / n) * radius,
             math.sin(phase + i * 2 * math.pi / n) * radius, z) for i in range(n)]


def _teepee(p, n, base_r, top_z, r, seed=0, phase=0.3, tile="bark", end="char", z0=0.04):
    for i, (x, y, _) in enumerate(_ring(n, base_r, 0.0, phase)):
        p.log((x, y, z0), (x * 0.12, y * 0.12, top_z), r, tile=tile, end_tile=end)


def _stone_ring(p, n, radius, size, seed, tile="stone", z=0.0, squash=(1.2, 1.0, 0.75), cx=0.0, cy=0.0):
    for i, (x, y, _) in enumerate(_ring(n, radius, 0, 0.2)):
        s = size * (0.85 + 0.3 * ((i * 37 + seed) % 7) / 6)
        p.rock(s, (cx + x, cy + y, z + s * squash[2] * 0.9), tile=tile, squash=squash, seed=seed + i)


# ------------------------------------------------------------------ camp

def tent():
    """Canvas A-frame on crossed poles, guy ropes and pegs, open flap at the front (3x3)."""
    p = Part("tent")
    hw, hl, top = 1.25, 1.2, 2.0
    ang = math.degrees(math.atan2(top, hw))
    slope = math.hypot(top, hw) + 0.08
    for sx in (-1, 1):
        p.box((slope, 2 * hl + 0.16, 0.035), (sx * hw / 2, 0, top / 2), "canvas_slope", rot=(0, sx * ang, 0), tile_m=1.3)
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
        # tie-downs: a guy line from mid-slope out to a peg on each side, so the slopes do not read
        # as bare flat planes; a dark leather hem along the eave edges the canvas
        for y in (-0.75, 0.75):
            p.log((sx * hw * 0.52, y, top * 0.5), (sx * 1.42, y, 0.08), 0.012, tile="rope", seg=4, end_tile="rope")
            p.log((sx * 1.42, y, -0.02), (sx * 1.44, y, 0.18), 0.03, tile="wood", seg=5)
        p.box((0.14, 2 * hl + 0.16, 0.045), (sx * (hw - 0.015), 0, 0.085), "leather_dark", rot=(0, sx * ang, 0))
    # W1-LIGHT's sun crosses from -X (yaw -35..-85), so a +X slope is shade all day and rendered as a
    # black slab. Turned +90 deg (Godot rot_step 1) the camera-side slope faces +Z and catches the sun.
    bmesh.ops.rotate(p.bm, verts=p.bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(R(90), 3, "Z"))
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


DECK_TILES = ("deck", "deck_old", "deck", "deck_dark", "deck", "deck_old")


def _crate(p, size, loc, rot_z=0.0):
    p.box(size, loc, "plank", rot=(0, 0, rot_z), tile_m=0.6)


def pier():
    """The harbour dock, 3 x 6 m to fit HarbourSite's 3x6 footprint (the landward end stops where
    travel lands the survivor; +Y in Blender = -Z in Godot = out to sea). A 2 m plank deck 1.2 m
    above the pile feet (the water is at 0.7) on five pile bents, a thatched shed at the landward
    end, cargo on the open deck (barrel, crates, a fish crate, a bucket, a coiled rope), mooring
    posts at the tip and a dugout log boat moored alongside with a ladder down to it.
    One glTF node per part: W1-HARBOUR's t_harbour wants the dock to be a composite of props."""
    # deck shifted +X so the boat fits inside the 3 m width on -X: the side the iso camera sees at the
    # rotations HarbourSite picks (rot 1 on 13 islands, rot 2 on home_grassland)
    hw, hl, deck, dx = 1.0, 3.0, 1.2, 0.25
    xl, xr = dx - hw, dx + hw
    parts = []

    def part(name):
        q = Part("pier_" + name)
        parts.append((q, (0, 0, 0)))
        return q

    # deck first: it is the root node the rest hang under
    d = part("deck")
    n = 20
    step = 2 * hl / n
    for i in range(n):
        y = -hl + (i + 0.5) * step
        # full-width boards, butt joints over nothing: the grain runs along each board's length
        tile = DECK_TILES[zlib.crc32(b"board%d" % i) % len(DECK_TILES)]
        d.box((2 * hw - 0.02 * (i % 3), step - 0.035, 0.06), (dx + 0.01 * ((i % 3) - 1), y, deck - 0.03), tile, tile_m=1.0)
    for i, y in enumerate(-hl + 0.15 + k * (2 * hl - 0.3) / 4 for k in range(5)):
        b = part("bent%d" % i)  # two piles and the cap beam they carry
        for x in (xl + 0.1, xr - 0.1):
            b.log((x, y, 0.0), (x, y, deck - 0.12), 0.11)
        b.plank((xl, y, deck - 0.2), (xr, y, deck - 0.2), 0.14, 0.12, "wood_dark")
    st = part("stringers")
    for x in (xl + 0.25, dx, xr - 0.25):
        st.plank((x, -hl, deck - 0.1), (x, hl, deck - 0.1), 0.14, 0.1, "wood_dark")
    # landward shed: four posts and a thatched lean-to roof pitched towards the sea
    y0, y1, h = -hl + 0.2, -hl + 1.5, 2.0
    fr = part("shed_frame")
    for y in (y0, y1):
        for x in (xl + 0.12, xr - 0.12):
            fr.log((x, y, deck - 0.02), (x, y, deck + h - (y - y0) * 0.2), 0.06, tile="wood_dark")
    fr.plank((xl + 0.05, y1, deck + h - 0.3), (xr - 0.05, y1, deck + h - 0.3), 0.1, 0.1, "wood_dark")
    rf = part("shed_roof")
    rf.box((2 * hw + 0.2, y1 - y0 + 0.45, 0.12), (dx, (y0 + y1) / 2, deck + h - 0.13), "thatch",
           rot=(-math.degrees(math.atan(0.2)), 0, 0), tile_m=0.8)
    sk = part("sacks")  # in the shed's shade
    sk.rock(0.26, (dx - 0.45, y0 + 0.45, deck + 0.16), tile="fiber", squash=(1.0, 0.75, 0.62), seed=5)
    sk.rock(0.22, (dx - 0.05, y0 + 0.35, deck + 0.14), tile="hide", squash=(1.0, 0.8, 0.62), seed=9)
    _crate(part("shed_crate"), (0.5, 0.5, 0.45), (dx + 0.5, y0 + 0.5, deck + 0.225), 8)
    # cargo on the open deck, where the iso camera sees it
    br = part("barrel")
    bx, by = dx - 0.5, y1 + 0.55
    br.cyl(0.26, 0.62, (bx, by, deck + 0.31), "wood_dark", seg=10, r2=0.24, cap_tile="log_end")
    for z in (0.12, 0.5):
        br.cyl(0.272 - z * 0.04, 0.05, (bx, by, deck + z), "iron", seg=10)
    cr = part("crates")
    _crate(cr, (0.6, 0.6, 0.52), (dx + 0.45, y1 + 0.5, deck + 0.26), 6)
    _crate(cr, (0.44, 0.44, 0.38), (dx + 0.43, y1 + 0.52, deck + 0.71), -18)
    fc = part("fish_crate")  # open crate of the day's catch
    fx, fy = dx + 0.42, 0.55
    fc.box((0.62, 0.46, 0.05), (fx, fy, deck + 0.025), "plank", tile_m=0.6)
    for sx in (-1, 1):
        fc.box((0.62, 0.04, 0.2), (fx, fy + sx * 0.21, deck + 0.1), "plank", tile_m=0.6)
        fc.box((0.04, 0.38, 0.2), (fx + sx * 0.29, fy, deck + 0.1), "plank", tile_m=0.6)
    fi = part("fish")
    for k, (ox, oy, rz) in enumerate(((-0.12, -0.08, 8), (0.1, 0.02, -12), (-0.04, 0.1, 20))):
        c = Vector((fx + ox, fy + oy, deck + 0.09 + 0.02 * k))
        body = bmesh.ops.create_icosphere(fi.bm, subdivisions=1, radius=1.0,
                                          matrix=Part._mat(c, (0, 0, rz), (0.15, 0.05, 0.04)))["verts"]
        fi.bm.normal_update()
        fi._finish(body, "fish", smooth=True)
        tail = Matrix.Rotation(R(rz), 3, "Z")
        tip = [c + tail @ Vector(v) for v in ((-0.13, 0, 0), (-0.22, 0.06, 0), (-0.22, -0.06, 0))]
        fi.prism(tip, (0, 0, 0.02), "fish")
    bu = part("bucket")
    ux, uy = dx - 0.55, 1.0
    bu.cyl(0.14, 0.3, (ux, uy, deck + 0.15), "wood", seg=10, r2=0.17, cap_tile="wood_dark")
    bu.cyl(0.155, 0.04, (ux, uy, deck + 0.08), "iron", seg=10)
    bu.cyl(0.15, 0.01, (ux, uy, deck + 0.28), "water", seg=10)
    bu.log((ux - 0.16, uy, deck + 0.3), (ux + 0.16, uy, deck + 0.3), 0.012, tile="iron", seg=4, end_tile="iron")
    co = part("rope_coil")  # three turns stacked, so the coil has volume
    cx, cy = dx - 0.45, 2.1
    for k, rr in enumerate((0.21, 0.18, 0.15)):
        co.torus(rr, 0.045, (cx + 0.01 * k, cy, deck + 0.045 + 0.075 * k), "rope")
    # mooring posts at the seaward end
    posts = []
    for side, x in (("l", xl + 0.1), ("r", xr - 0.1)):
        mp = part("post_" + side)
        mp.cyl(0.1, 0.5, (x, hl - 0.15, deck + 0.25), "bark", seg=7, cap_tile="log_end")
        mp.cyl(0.115, 0.08, (x, hl - 0.15, deck + 0.3), "rope", seg=7)
        posts.append(x)
    # dugout log boat moored alongside, floating at the waterline (0.7 above the pile feet)
    bt = part("boat")
    ox, oy, zb, zt = xl - 0.36, 1.6, 0.55, 0.95  # 0.25 m freeboard above the water
    hull = [(ox, oy - 1.15, zb), (ox + 0.29, oy - 0.6, zb), (ox + 0.29, oy + 0.6, zb), (ox, oy + 1.15, zb),
            (ox - 0.29, oy + 0.6, zb), (ox - 0.29, oy - 0.6, zb)]
    bt.prism(hull, (0, 0, zt - zb), "bark", tile_m=1.2)
    inner = [(ox + (x - ox) * 0.72, oy + (y - oy) * 0.82, zt + 0.004) for x, y, _ in hull]
    bt.prism(inner, (0, 0, 0.008), "soot")  # the hollowed-out inside
    bt.plank((ox - 0.22, oy + 0.15, zt + 0.02), (ox + 0.22, oy + 0.15, zt + 0.02), 0.12, 0.04, "wood")
    pd = part("paddle")
    pd.plank((ox - 0.08, oy - 0.75, zt + 0.06), (ox + 0.02, oy + 0.35, zt + 0.06), 0.05, 0.03, "wood")
    pd.box((0.13, 0.32, 0.025), (ox + 0.04, oy + 0.5, zt + 0.06), "wood", rot=(0, 0, -5))
    ml = part("mooring_line")
    ml.log((posts[0], hl - 0.15, deck + 0.32), (ox, oy + 1.05, zt + 0.03), 0.016, tile="rope", seg=4, end_tile="rope")
    ml.log((posts[0], hl - 0.15, deck + 0.28), (posts[0] + 0.25, hl - 0.6, deck + 0.03), 0.016, tile="rope", seg=4, end_tile="rope")
    ld = part("ladder")  # down the deck's seaward side to the boat
    for y in (0.95, 1.35):
        ld.log((xl - 0.03, y, deck + 0.05), (xl - 0.03, y, 0.5), 0.035, tile="wood_dark", seg=5)
    for z in (0.62, 0.86, 1.1):
        ld.log((xl - 0.04, 0.95, z), (xl - 0.04, 1.35, z), 0.025, tile="wood", seg=5)
    return parts


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


# ------------------------------------------------------------------ camp pieces (dsc camp set)
# The 18 placeable kinds that used to fall back to Kenney models. Same kit, tiles and palette as the
# camp above; footprints (X x Y) follow game/data/props_manifest.json, the front faces -Y.
# PropVisuals.ensure_foundation lays an opaque dirt disc at y = 0.08 m under every building but
# straw_roll and the fields, so ground detail (beds, mats, ash and ember beds) starts at GROUND and up.
GROUND = 0.08

def large_box():
    """Big plank storage crate on skids, rope handles, lid propped ajar showing the load (2x1)."""
    p = Part("large_box")
    L, W, H = 1.86, 0.84, 0.88
    for sy in (-1, 1):  # skids
        p.plank((-L / 2 + 0.1, sy * (W / 2 - 0.12), 0.035), (L / 2 - 0.1, sy * (W / 2 - 0.12), 0.035), 0.12, 0.07, "wood_dark")
    # plank body: four walls so the open top reads as a real box
    bot = 0.07
    t = 0.06
    p.box((L, W, t), (0, 0, bot + t / 2), "plank", tile_m=1.4)
    p.box((L, t, H - bot - t), (0, W / 2 - t / 2, bot + t + (H - bot - t) / 2), "plank", tile_m=1.4)
    p.box((L, t, H - bot - t), (0, -W / 2 + t / 2, bot + t + (H - bot - t) / 2), "plank", tile_m=1.4)
    for sx in (-1, 1):
        p.box((t, W - 2 * t, H - bot - t), (sx * (L / 2 - t / 2), 0, bot + t + (H - bot - t) / 2), "plank", tile_m=1.4)
    # dark interior and the load inside
    p.box((L - 0.2, W - 0.2, 0.02), (0, 0, bot + 0.18), "soot")
    p.box((0.62, 0.5, 0.16), (-0.3, 0.05, bot + 0.27), "hide", rot=(0, 0, 6))
    p.box((0.4, 0.34, 0.3), (0.45, -0.06, bot + 0.34), "weave", rot=(0, 0, -8))
    # corner battens and iron nails
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.1, 0.05, H - bot - 0.02), (sx * (L / 2 - 0.05), sy * (W / 2 + 0.005), (H + bot) / 2), "wood_dark")
    for z in (0.3, 0.66):
        p.box((L + 0.02, 0.05, 0.06), (0, -W / 2 - 0.005, z), "wood_dark")
        for x in (-0.6, 0.0, 0.6):
            p.cyl(0.018, 0.03, (x, -W / 2 - 0.035, z), "iron", rot=(90, 0, 0), seg=4)
    # rope handles on each end
    for sx in (-1, 1):
        x = sx * (L / 2 + 0.02)
        p.box((0.05, 0.035, 0.13), (x, -0.14, 0.48), "rope")
        p.box((0.05, 0.035, 0.13), (x, 0.14, 0.48), "rope")
        p.box((0.05, 0.32, 0.04), (x, 0, 0.55), "rope")
        for y in (-0.14, 0.14):
            p.cyl(0.03, 0.03, (x, y, 0.41), "iron", rot=(0, 90, 0), seg=6)
    # lid propped open against the back rim, leaning forward so it stays inside the 2x1 cell
    D = math.hypot(0.42, 0.72)
    up = Vector((0, -0.42, 0.72)).normalized()  # from the hinge up to the lid's free edge
    normal = Vector((0, -up.z, -up.y)) * -1  # faces the camera
    hinge = Vector((0, W / 2 - 0.01, H - 0.02))
    c = hinge + up * (D / 2)
    p.plank((-L / 2 + 0.03, c.y, c.z), (L / 2 - 0.03, c.y, c.z), D, 0.07, "plank", up=up)
    c2 = c + normal * 0.05
    p.plank((-L / 2 + 0.12, c2.y, c2.z), (L / 2 - 0.12, c2.y, c2.z), 0.1, 0.03, "wood_dark", up=up)
    # iron hinges on the back rim
    for sx in (-1, 1):
        p.cyl(0.06, 0.03, (sx * (L / 2 - 0.1), -W / 2 + 0.14, H + 0.02), "iron", seg=8)
        p.cyl(0.055, 0.04, (sx * (L / 2 - 0.1), -W / 2 + 0.14, H + 0.015), "rope", seg=8)
    p.log((-L / 2 + 0.16, W / 2 - 0.2, 0.12), (L / 2 - 0.3, -0.05, H + 0.22), 0.022, tile="wood_dark", seg=5)
    return [(p, (0, 0, 0))]


def chest():
    """Locked storage chest: plank body, iron straps and a lock plate, lid closed (1x1)."""
    p = Part("chest")
    L, W, H, T = 0.78, 0.5, 0.4, 0.055
    for sx in (-1, 1):  # feet
        p.box((0.1, W - 0.04, 0.05), (sx * (L / 2 - 0.08), 0, 0.025), "wood_dark")
    bot = 0.05
    p.box((L, W, T), (0, 0, bot + T / 2), "plank", tile_m=0.7)
    p.box((L, T, H - bot), (0, W / 2 - T / 2, bot + (H - bot) / 2), "plank", tile_m=0.7)
    p.box((L, T, H - bot), (0, -W / 2 + T / 2, bot + (H - bot) / 2), "plank", tile_m=0.7)
    for sx in (-1, 1):
        p.box((T, W - 2 * T, H - bot), (sx * (L / 2 - T / 2), 0, bot + (H - bot) / 2), "plank", tile_m=0.7)
    # flat plank lid with a chamfered top edge; iron straps hug the top and run down both faces
    p.box((L + 0.03, W + 0.02, 0.055), (0, 0, H + 0.028), "plank", tile_m=0.7)
    for sy in (-1, 1):
        # dark seam under the lid lip and a small cornice, so the lid reads as its own piece
        p.box((L + 0.05, 0.035, 0.025), (0, sy * (W / 2 + 0.012), H + 0.005), "wood_dark")
        p.box((L + 0.05, 0.05, 0.03), (0, sy * (W / 2 + 0.005), H + 0.045), "plank")
    for x in (-0.22, 0.22):
        p.box((0.07, 0.02, H - 0.03), (x, -W / 2 - 0.012, (H + 0.03) / 2 - 0.015), "iron")
        p.box((0.07, 0.02, H - 0.03), (x, W / 2 + 0.012, (H + 0.03) / 2 - 0.015), "iron")
        p.box((0.07, W + 0.06, 0.025), (x, 0, H + 0.068), "iron")
        p.box((0.02, 0.075, 0.06), (x, -W / 2 - 0.016, H - 0.03), "iron")
        p.box((0.02, 0.075, 0.06), (x, W / 2 + 0.016, H - 0.03), "iron")
        for sy in (-1, 1):
            p.cyl(0.014, 0.02, (x, sy * (W / 2 + 0.025), 0.2), "wood", rot=(90, 0, 0), seg=4)
    # hasp and lock plate
    p.box((0.15, 0.03, 0.16), (0, -W / 2 - 0.02, H - 0.04), "iron")
    p.box((0.1, 0.03, 0.07), (0, -W / 2 - 0.03, H + 0.02), "iron", rot=(-18, 0, 0))
    p.cyl(0.03, 0.03, (0, -W / 2 - 0.045, H - 0.07), "iron", rot=(90, 0, 0), seg=8)
    p.cyl(0.012, 0.04, (0, -W / 2 - 0.05, H - 0.07), "soot", rot=(90, 0, 0), seg=6)
    # corner irons
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.06, 0.06, H - bot), (sx * (L / 2 - 0.03), sy * (W / 2 - 0.03), bot + (H - bot) / 2), "iron")
    return [(p, (0, 0, 0))]


def barrel():
    """Open brine/water barrel: tapered two-part body with a bulge, three iron hoops, dark inside
    with the water surface at the rim and a dipper resting across it (1x1)."""
    p = Part("barrel")
    n = 12
    # body: lower half swells 0.29 -> 0.36, upper half narrows back to 0.29 (the pier barrel's read,
    # which already sits in the set, with the bulge pushed out a little so it is not a plain drum)
    p.cyl(0.29, 0.38, (0, 0, 0.2), "wood", seg=n, r2=0.36, cap_tile="wood_dark")
    # the mouth is filled with brine, so the top cap of the body is water, ringed by a dark inner lip
    p.cyl(0.36, 0.4, (0, 0, 0.585), "wood", seg=n, r2=0.3, cap_tile="soot")
    # inner lip of dark staves, then the brine filling the mouth just below the rim
    p.cyl(0.29, 0.012, (0, 0, 0.789), "soot", seg=n, cap_tile="water")
    # iron hoops: each a short cone ring just proud of the staves
    for z, r0, r1 in ((0.1, 0.318, 0.34), (0.4, 0.36, 0.365), (0.72, 0.325, 0.302)):
        p.cyl(r0 + 0.018, 0.07, (0, 0, z), "iron", seg=n, r2=r1 + 0.018)
    # a dipper resting across the rim
    p.log((-0.15, -0.07, 0.8), (0.18, 0.1, 0.89), 0.022, tile="wood_dark", seg=5)
    p.cyl(0.07, 0.1, (0.2, 0.105, 0.84), "wood", seg=8, r2=0.062, cap_tile="wood_dark")
    return [(p, (0, 0, 0))]


def bucket():
    """Small wooden bucket, iron band, rope handle standing upright (1x1; firmly under the cell)."""
    p = Part("bucket")
    p.cyl(0.13, 0.02, (0, 0, 0.01), "wood_dark", seg=10, cap_tile="wood_dark")
    p.cyl(0.15, 0.26, (0, 0, 0.15), "wood", seg=10, r2=0.17, cap_tile="soot")
    p.cyl(0.155, 0.03, (0, 0, 0.05), "iron", seg=10)
    p.cyl(0.163, 0.025, (0, 0, 0.24), "iron", seg=10)
    p.cyl(0.16, 0.012, (0, 0, 0.265), "soot", seg=10, cap_tile="soot")
    p.cyl(0.115, 0.012, (0, 0, 0.272), "water", seg=10, cap_tile="water")
    # vertical stave ribs
    for i in range(10):
        a = (i + 0.5) * 2 * math.pi / 10
        p.box((0.03, 0.012, 0.24), (math.cos(a) * 0.158, math.sin(a) * 0.158, 0.15), "wood_dark",
              rot=(0, 0, math.degrees(a) + 90))
    # rope bail: two short uprights and an arc of three segments
    for sx in (-1, 1):
        p.box((0.025, 0.03, 0.09), (sx * 0.165, 0, 0.3), "rope")
        p.log((sx * 0.165, 0, 0.33), (sx * 0.1, 0, 0.44), 0.014, tile="rope", seg=4, end_tile="rope")
    p.log((-0.1, 0, 0.44), (0.1, 0, 0.44), 0.014, tile="rope", seg=4, end_tile="rope")
    return [(p, (0, 0, 0))]


def signpost():
    """Leaning wooden post, two carved boards pointing opposite ways, rope lashings (1x1)."""
    p = Part("signpost")
    top = (0.04, 0.03, 1.72)
    p.cyl(0.1, 0.1, (0, 0, 0.04), "cobble", seg=8, r2=0.08, cap_tile="cobble")
    p.log((0, 0, -0.02), top, 0.058)
    p.cyl(0.058, 0.14, (0.0, 0.0, 1.78), "wood", seg=7, r2=0.008, cap_tile="log_end")
    # upper board points -X (slightly towards camera), lower board points +X
    p.box((0.52, 0.05, 0.24), (-0.24, -0.02, 1.42), "sign_board", rot=(0, 0, -8), tile_m=0.7)
    p.box((0.46, 0.05, 0.22), (0.22, 0.02, 1.08), "sign_board", rot=(0, 0, 7), tile_m=0.7)
    for (bx, bz, rz) in ((-0.26, 1.42, -8), (0.24, 1.08, 7)):
        # rope band wrapped round the post where the board is tied on
        for dz in (-0.085, 0.085):
            p.cyl(0.075, 0.045, (0, 0, bz + dz), "rope", seg=8)
    # board ends chamfered with a dark edge strip
    p.box((0.05, 0.055, 0.24), (-0.5, -0.02, 1.42), "wood_dark", rot=(0, 0, -8))
    p.box((0.05, 0.055, 0.22), (0.45, 0.02, 1.08), "wood_dark", rot=(0, 0, 7))
    for nx, nz in ((-0.1, 1.42), (0.1, 1.08)):
        p.cyl(0.018, 0.02, (nx, -0.055 if nz > 1.2 else -0.015, nz), "iron", rot=(90, 0, 0), seg=6)
    # a small bundle of firewood and a tied rag at the foot
    p.log((-0.2, 0.12, 0.04), (0.18, 0.2, 0.04), 0.045, tile="bark", seg=6)
    p.log((-0.18, 0.2, 0.09), (0.2, 0.13, 0.09), 0.04, tile="bark", seg=6)
    p.cyl(0.05, 0.1, (-0.02, 0.16, 0.08), "rope", rot=(90, 0, 30), seg=6)
    return [(p, (0, 0, 0))]


def bedroll():
    """Hide bedroll on the ground: hide sheet, woven pad, a thick hide blanket rolled down over the
    foot end, a fibre pillow at the head and corner pegs (1x2). Sits on the foundation disc."""
    p = Part("bedroll")
    z = GROUND - 0.005
    # hide sheet, with stitched seam bands across both ends
    p.box((0.8, 1.94, 0.035), (0, 0, z + 0.0175), "hide", tile_m=0.45)
    for y in (-0.94, 0.94):
        p.box((0.84, 0.05, 0.045), (0, y, z + 0.02), "leather_dark")
    # woven sleeping pad down the middle, long enough for a 1.8 m sleeper
    p.box((0.56, 1.8, 0.07), (0, 0.02, z + 0.06), "weave", tile_m=0.7)
    # the blanket rolled down over the foot half of the pad: an oval roll across the mat
    p.cyl(0.12, 0.62, (0, 0.6, z + 0.16), "hide", rot=(0, 90, 0), seg=9, cap_tile="fiber")
    p.box((0.62, 0.56, 0.06), (0, 0.66, z + 0.15), "hide", tile_m=0.5)
    for x in (-0.19, 0.19):
        p.cyl(0.126, 0.045, (x, 0.6, z + 0.16), "rope", rot=(0, 90, 0), seg=9)
    # pillow: a short fibre roll tied at the ends
    p.cyl(0.085, 0.5, (0, -0.76, z + 0.105), "fiber", rot=(0, 90, 0), seg=8, cap_tile="fiber")
    for x in (-0.16, 0.16):
        p.cyl(0.09, 0.04, (x, -0.76, z + 0.105), "rope", rot=(0, 90, 0), seg=8)
    # pegs holding the corners down, driven through the sheet into the ground
    for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        p.log((sx * 0.34, sy * 0.92, -0.02), (sx * 0.34, sy * 0.92, z + 0.07), 0.018, tile="wood", seg=5)
    return [(p, (0, 0, 0))]


def straw_roll():
    """Rolled straw bed: a thick thatch roll lashed with two rope ties, part unrolled into a flat
    straw pad at the near end, on a hide ground sheet (1x2)."""
    p = Part("straw_roll")
    p.box((0.82, 1.86, 0.03), (0, 0, 0.015), "hide", tile_m=0.45)
    # the unrolled pad, low and flat, from the near end up to under the roll
    p.box((0.72, 0.86, 0.07), (0, -0.46, 0.06), "thatch", tile_m=0.6)
    p.box((0.74, 0.05, 0.02), (0, -0.87, 0.1), "rope")
    # the roll: axis along Y, over the pad's back edge
    p.cyl(0.22, 1.02, (0, 0.4, 0.23), "thatch", rot=(90, 0, 0), seg=16, cap_tile="fiber")
    for y in (-0.02, 0.4, 0.82):
        p.cyl(0.234, 0.06, (0, y, 0.23), "rope", rot=(90, 0, 0), seg=16)
        p.box((0.05, 0.04, 0.12), (0.19, y + 0.05, 0.28), "rope", rot=(0, -22, 0))
    # a thatch strip where the pad meets the roll, so the transition is not a hard step
    p.box((0.7, 0.14, 0.05), (0, -0.02, 0.1), "fiber", rot=(18, 0, 0))
    return [(p, (0, 0, 0))]


def campfire_stand():
    """Cooking fire upgrade: stone-ring fire with a hook post holding a small hanging pot, and a spit
    of meat skewered between two forked stakes in front of it (1x1)."""
    p = Part("campfire_stand")
    _stone_ring(p, 10, 0.36, 0.095, 71, z=GROUND - 0.03)
    p.cyl(0.28, 0.03, (0, 0, GROUND + 0.02), "ash", seg=10, cap_tile="ember")
    _teepee(p, 5, 0.2, 0.38, 0.032, phase=0.2, end="ember", z0=GROUND + 0.04)
    # spit: two forked stakes straddling the fire on the camera side
    for sx in (-1, 1):
        p.log((sx * 0.42, -0.1, 0), (sx * 0.42, -0.1, 0.56), 0.03, tile="wood_dark", seg=6)
        p.log((sx * 0.42, -0.1, 0.48), (sx * 0.39, -0.1, 0.63), 0.017, tile="wood_dark", seg=5)
        p.log((sx * 0.42, -0.1, 0.48), (sx * 0.45, -0.1, 0.63), 0.017, tile="wood_dark", seg=5)
        p.cyl(0.037, 0.035, (sx * 0.42, -0.1, 0.43), "rope", seg=6)
    p.cyl(0.011, 0.86, (0, -0.1, 0.575), "iron", rot=(0, 90, 0), seg=5)
    for fx, rr in ((-0.09, 0.045), (0.09, 0.04)):
        p.cyl(rr, 0.1, (fx, -0.1, 0.575), "meat_drying", rot=(0, 90, 0), seg=8, cap_tile="meat_drying")
    # tall hook post at the back corner, over the coals; a small clay pot hangs low from it
    hx, hy = -0.26, 0.36
    p.log((hx, hy, 0), (hx, hy, 0.92), 0.032, tile="wood_dark", seg=6)
    p.log((hx, hy, 0.88), (hx + 0.3, hy - 0.16, 0.92), 0.022, tile="wood_dark", seg=5)
    p.cyl(0.044, 0.05, (hx, hy, 0.78), "rope", seg=6)
    px, py = hx + 0.3, hy - 0.16
    p.log((px, py, 0.91), (px, py, 0.74), 0.007, tile="iron", seg=4, end_tile="iron")
    p.cyl(0.075, 0.11, (px, py, 0.66), "clay", seg=9, r2=0.085, cap_tile="clay_dark")
    p.cyl(0.088, 0.022, (px, py, 0.715), "clay_dark", seg=9)
    p.cyl(0.072, 0.01, (px, py, 0.72), "meat_dried", seg=9, cap_tile="meat_dried")
    # split firewood stacked beside the ring
    for i in range(3):
        p.log((0.22, 0.12 + 0.06 * i, GROUND + 0.03 + 0.05 * i), (0.38, 0.16 + 0.06 * i, GROUND + 0.04 + 0.05 * i), 0.028, tile="bark", seg=6)
    return [(p, (0, 0, 0))]


def technical_workbench():
    """Heavy bench: thick plank top on lashed log legs with a lower shelf, stone-and-iron anvil,
    bench vise, hammer and tongs, quench bucket (2x1)."""
    p = Part("technical_workbench")
    L, W, H = 1.78, 0.8, 0.9
    for i, y in enumerate((-0.26, 0.0, 0.26)):
        p.box((L, 0.255, 0.08), (0, y, H - 0.04), "plank" if i != 1 else "deck_dark", tile_m=1.8)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (L / 2 - 0.16), sy * (W / 2 - 0.12)
            p.log((x, y, 0), (x * 0.97, y * 0.94, H - 0.08), 0.065)
            p.cyl(0.075, 0.07, (x * 0.99, y * 0.97, H - 0.14), "rope", seg=6)
        p.plank((sx * (L / 2 - 0.16), -W / 2 + 0.1, 0.28), (sx * (L / 2 - 0.16), W / 2 - 0.1, 0.28), 0.08, 0.06, "wood_dark")
    p.box((L - 0.5, W - 0.2, 0.04), (0, 0, 0.29), "plank", tile_m=1.5)
    # the anvil: plank stump carrying a stone block with an iron face and a horn
    p.box((0.34, 0.3, 0.04), (0.44, 0.02, H + 0.02), "iron")
    p.box((0.26, 0.2, 0.07), (0.44, 0.02, H + 0.055), "iron", tile_m=0.3)  # base pad
    p.box((0.14, 0.12, 0.12), (0.44, 0.02, H + 0.15), "iron", tile_m=0.3)  # waist
    p.box((0.34, 0.17, 0.09), (0.42, 0.02, H + 0.255), "iron", tile_m=0.3)  # face
    p.box((0.1, 0.06, 0.05), (0.42, 0.02, H + 0.32), "iron", tile_m=0.3)  # hardie block
    p.cyl(0.05, 0.17, (0.62, 0.02, H + 0.255), "iron", rot=(0, 90, 0), seg=7, r2=0.014, cap_tile="iron")
    for sx in (-1, 1):
        p.cyl(0.016, 0.025, (0.44 + sx * 0.15, 0.02, H + 0.035), "iron", seg=4)
    # bench vise at the left front corner, jaws on a length of stock
    p.box((0.22, 0.14, 0.09), (-0.56, -W / 2 + 0.13, H + 0.045), "iron", tile_m=0.3)
    p.box((0.2, 0.05, 0.12), (-0.56, -W / 2 + 0.15, H + 0.13), "iron", tile_m=0.3)
    p.cyl(0.022, 0.16, (-0.56, -W / 2 + 0.05, H + 0.13), "iron", rot=(90, 0, 0), seg=6)
    p.cyl(0.04, 0.025, (-0.56, -W / 2 - 0.04, H + 0.13), "iron", rot=(90, 0, 0), seg=6)
    p.box((0.3, 0.045, 0.045), (-0.5, -W / 2 + 0.16, H + 0.21), "wood", rot=(0, 4, 0))
    # hammer and tongs laid out on the deck between the vise and the anvil
    p.log((-0.26, 0.22, H + 0.02), (-0.08, 0.12, H + 0.02), 0.022, tile="wood", seg=5)
    p.box((0.11, 0.045, 0.05), (-0.05, 0.1, H + 0.02), "iron", rot=(0, 0, -20), tile_m=0.3)
    p.log((-0.18, -0.22, H + 0.015), (0.04, -0.3, H + 0.015), 0.011, tile="iron", seg=4, end_tile="iron")
    p.box((0.05, 0.04, 0.035), (0.05, -0.3, H + 0.02), "iron")
    # quench bucket on the top, near corner; water just below the rim
    bx, by = L / 2 - 0.28, -0.16
    p.cyl(0.095, 0.19, (bx, by, H + 0.095), "wood", seg=8, r2=0.11, cap_tile="water")
    p.cyl(0.1, 0.025, (bx, by, H + 0.185), "iron", seg=8)
    p.cyl(0.09, 0.02, (bx, by, H + 0.18), "water", seg=8)
    # a coil of twine and a spare wedge
    p.torus(0.06, 0.016, (-0.36, 0.26, H + 0.015), "rope", seg=8, tube=4)
    p.box((0.1, 0.05, 0.04), (-0.7, 0.22, H + 0.02), "wood_dark", rot=(0, 0, 18))
    return [(p, (0, 0, 0))]


def grindstone():
    """Sharpening station: a round stone on an axle between two timber posts, crank on the near end,
    water trough beneath and a blade leaning against the wheel (1x1)."""
    p = Part("grindstone")
    Z, R = 0.52, 0.19  # axle height, wheel radius: a hand-cranked stone, not a mill wheel
    for sx in (-1, 1):
        p.log((sx * 0.34, 0.02, 0), (sx * 0.28, 0.0, Z + 0.12), 0.042, tile="wood", seg=7)
        p.box((0.14, 0.34, 0.06), (sx * 0.34, 0.02, 0.03), "wood_dark")
        p.log((sx * 0.1, 0.02, 0.14), (sx * 0.29, 0.0, 0.36), 0.026, tile="wood_dark", seg=6)
        p.cyl(0.046, 0.05, (sx * 0.295, 0.0, Z - 0.02), "rope", seg=7)
    # the wheel: axis along X so the camera sees the round face and the rim
    p.cyl(R, 0.15, (0, 0, Z), "stone_dark", rot=(0, 90, 0), seg=14, cap_tile="stone")
    p.log((-0.4, 0, Z), (0.4, 0, Z), 0.026, tile="iron", end_tile="iron")
    for sx in (-1, 1):
        p.cyl(R + 0.005, 0.025, (sx * 0.09, 0, Z), "iron", rot=(0, 90, 0), seg=14)
    # crank arm on the near end (+X) turning a wooden handle
    p.box((0.045, 0.13, 0.035), (0.42, 0.0, Z), "iron", tile_m=0.3)
    p.box((0.045, 0.035, 0.17), (0.42, -0.065, Z + 0.08), "iron", tile_m=0.3)
    p.cyl(0.026, 0.12, (0.42, -0.13, Z + 0.16), "wood", rot=(90, 0, 0), seg=6)
    # trough under the wheel
    p.box((0.4, 0.26, 0.11), (0, 0, 0.055), "wood_dark", tile_m=0.45)
    p.box((0.34, 0.2, 0.01), (0, 0, 0.108), "water", tile_m=0.5)
    # a blade leaning on the wheel's rim, handle on the trough, and a fibre rag
    p.box((0.028, 0.16, 0.12), (0.12, -0.16, 0.3), "iron", rot=(24, 0, 0), tile_m=0.3)
    p.cyl(0.02, 0.1, (0.12, -0.2, 0.21), "wood_dark", rot=(-24, 0, 0), seg=5)
    p.box((0.13, 0.15, 0.035), (-0.34, -0.2, 0.07), "fiber", rot=(0, 0, 25))
    return [(p, (0, 0, 0))]


def _fish(p, c, length=0.3, girth=0.032, depth=0.07, yaw=0.0):
    """A fish hung by the tail from c (the tail tie): flattened oval body along -Z with a tail fin."""
    c = Vector(c)
    rot = Matrix.Rotation(R(yaw), 3, "Z")
    body_c = c + rot @ Vector((0, 0, -length * 0.55))
    body = bmesh.ops.create_icosphere(p.bm, subdivisions=3, radius=1.0,
                                      matrix=Matrix.Translation(body_c) @ rot.to_4x4() @
                                      Matrix.Diagonal((girth, depth, length * 0.5, 1)))["verts"]
    p.bm.normal_update()
    p._finish(body, "fish", smooth=True, tile_m=0.3)
    tip = [c + rot @ Vector(v) for v in ((0, 0, 0.03), (0.075, 0, -0.1), (-0.075, 0, -0.1))]
    p.prism(tip, rot @ Vector((0, 0.008, 0)), "fish")
    for sx in (-1, 1):  # eye
        p.cyl(0.008, 0.004, tuple(c + rot @ Vector((sx * girth * 0.9, 0, -length * 0.85))), "soot", seg=4)


def fishing_stand():
    """Camp fish-drying rack: A-frame with a ridge pole and a drying line of fish hung between the
    front posts, a small smoulder pit beneath and today's catch on a hide (1x1)."""
    p = Part("fishing_stand")
    _stone_ring(p, 7, 0.19, 0.045, 81, tile="stone_dark", squash=(1.1, 1, 0.6), z=GROUND - 0.01)
    p.cyl(0.13, 0.02, (0, 0, GROUND + 0.012), "ash", seg=8, cap_tile="ember")
    p.log((-0.08, 0, GROUND + 0.035), (0.08, 0.05, GROUND + 0.035), 0.022, tile="char", seg=5, end_tile="ember")
    # rack: four posts leaning to one ridge pole across the camera, at the back of the cell
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.log((sx * 0.42, 0.02 + sy * 0.3, 0), (sx * 0.34, 0.02 + sy * 0.06, 1.0), 0.028, tile="wood_dark", seg=6)
    p.log((-0.47, 0.02, 1.03), (0.47, 0.02, 1.03), 0.03, tile="wood")
    # drying line strung from the front pair of posts, the fish hanging on the camera side of it
    p.log((-0.34, -0.04, 0.92), (0.34, -0.04, 0.92), 0.007, tile="rope", seg=4, end_tile="rope")
    for fx, yaw in ((-0.17, 10), (0.0, -8), (0.17, 16)):
        p.log((fx, -0.04, 0.92), (fx, -0.05, 0.87), 0.005, tile="rope", seg=4)
        _fish(p, (fx, -0.06, 0.87), length=0.26, girth=0.032, depth=0.07, yaw=yaw)
    # today's catch on a hide beside the pit, and a coil of line
    p.box((0.24, 0.17, 0.02), (0.24, -0.3, GROUND + 0.01), "hide")
    _fish_flat(p, (0.24, -0.3, GROUND + 0.03), length=0.22, yaw=-30)
    p.torus(0.06, 0.014, (-0.26, -0.3, GROUND + 0.015), "rope", seg=10, tube=4)
    return [(p, (0, 0, 0))]


def _fish_flat(p, c, length=0.32, yaw=0.0):
    """A whole fish lying flat (the pier's fish read: a squashed oval body with a forked tail)."""
    c = Vector(c)
    rot = Matrix.Rotation(R(yaw), 3, "Z")
    body = bmesh.ops.create_icosphere(p.bm, subdivisions=1, radius=1.0,
                                      matrix=Part._mat(c, (0, 0, yaw), (length * 0.42, length * 0.17, length * 0.13)))["verts"]
    p.bm.normal_update()
    p._finish(body, "fish", smooth=True, tile_m=0.3)
    tip = [c + rot @ Vector(v) for v in ((-length * 0.36, 0, 0.0), (-length * 0.58, length * 0.12, 0.0), (-length * 0.58, -length * 0.12, 0.0))]
    p.prism([tuple(v) for v in tip], rot @ Vector((0, 0, 0.02)), "fish", tile_m=0.25)


def stone_grill():
    """Cooking station: a flat stone slab resting on four hearth stones over a stone-ringed fire,
    coals glowing between the stones, food set out on the slab (2x2)."""
    p = Part("stone_grill")
    # hearth ring: a tight double course of stones, like the other fire pits but heavier
    _stone_ring(p, 14, 0.56, 0.12, 91, tile="stone")
    for i, (x, y, _) in enumerate(_ring(12, 0.54, 0, 0.4)):
        s_ = 0.1 * (0.9 + 0.25 * ((i * 31) % 5) / 4)
        p.rock(s_, (x, y, 0.24), tile="stone", squash=(1.2, 1, 0.7), seed=150 + i)
    # fire inside: ash bed, two charred logs, embers
    p.cyl(0.42, 0.03, (0, 0, GROUND + 0.015), "ash", seg=12, cap_tile="ash")
    p.log((-0.22, -0.06, GROUND + 0.05), (0.22, 0.08, GROUND + 0.05), 0.045, tile="char", seg=6, end_tile="ember")
    p.log((-0.08, -0.22, GROUND + 0.06), (0.1, 0.2, GROUND + 0.06), 0.038, tile="char", seg=6, end_tile="ember")
    p.cyl(0.13, 0.03, (0, 0, GROUND + 0.04), "ember", seg=8, cap_tile="ember")
    # four squat stones carrying the slab, leaving the fire visible between them
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.rock(0.17, (sx * 0.3, sy * 0.28, 0.26), tile="stone", squash=(1.0, 1.0, 0.9), seed=160 + sx * 2 + sy)
    # the slab: one heavy flat stone, tilted a hair, a darker worn top
    p.box((0.84, 0.78, 0.09), (0, 0, 0.4), "stone", rot=(1.5, 0, 2), tile_m=0.55)
    p.box((0.75, 0.69, 0.014), (0, 0, 0.447), "stone_dark", rot=(1.5, 0, 2), tile_m=0.9)
    # food on the slab
    _fish_flat(p, (-0.13, -0.11, 0.455), length=0.32, yaw=26)
    p.box((0.16, 0.11, 0.035), (0.15, 0.12, 0.46), "meat_drying", rot=(0, 0, 12))
    p.box((0.13, 0.09, 0.025), (0.11, -0.16, 0.46), "meat_drying", rot=(0, 0, -8))
    p.cyl(0.05, 0.065, (-0.2, 0.18, 0.49), "clay", seg=8, r2=0.042, cap_tile="clay_dark")
    # tongs leaning against the slab's lip in front
    p.log((0.26, -0.48, 0.45), (0.18, -0.56, 0.28), 0.01, tile="iron", seg=4, end_tile="iron")
    p.box((0.035, 0.018, 0.08), (0.27, -0.49, 0.48), "iron")
    return [(p, (0, 0, 0))]


def tent_canvas():
    """Cheap shade tent: canvas fly stretched over four poles and ridge, open sides, guy ropes,
    bedroll and a small crate underneath (3x2). Front faces -Y."""
    p = Part("tent_canvas")
    HL, HW = 1.14, 0.72  # half length (X), half width (Y) inside the 3x2 cell
    H0, H1 = 1.82, 2.16  # eave and ridge heights
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.log((sx * HL, sy * HW, 0), (sx * HL, sy * HW, H0), 0.048, tile="wood_dark", seg=7)
            p.rock(0.11, (sx * HL, sy * HW, GROUND + 0.02), tile="stone", squash=(1.2, 1.1, 0.7), seed=200 + sx * 3 + sy)
        p.log((sx * HL, -HW, H0), (sx * HL, HW, H0), 0.035, tile="wood")
    p.log((-HL - 0.06, 0, H1), (HL + 0.06, 0, H1), 0.04, tile="wood")
    for sx in (-1, 1):  # ridge posts and braces
        p.log((sx * (HL - 0.02), 0, H0 - 0.05), (sx * (HL - 0.02), 0, H1 + 0.02), 0.036, tile="wood_dark", seg=6)
        for sy in (-1, 1):
            p.log((sx * HL, sy * HW, H0 - 0.1), (sx * (HL - 0.02), sy * 0.02, H1 - 0.06), 0.022, tile="wood_dark", seg=5)
    # canvas fly: two slopes, hemmed, with stitched panels and a sagging edge on the long sides
    ang = math.degrees(math.atan2(H1 - H0, HW))
    slope = math.hypot(HW, H1 - H0) + 0.1
    for sy in (-1, 1):
        p.box((2 * HL + 0.5, slope, 0.035), (0, sy * HW * 0.5, (H0 + H1) / 2 + 0.03), "canvas_slope",
              rot=(-sy * ang, 0, 0), tile_m=1.4)
        # scalloped hem/valance hanging from the eave on this side
        for k in range(5):
            x = -HL + (k + 0.5) * (2 * HL) / 5
            p.box((2 * HL / 5 - 0.05, 0.02, 0.16), (x, sy * (HW + 0.06), H0 - 0.02), "canvas",
                  rot=(sy * 14, 0, 0), tile_m=0.7)
        p.box((2 * HL + 0.5, 0.03, 0.06), (0, sy * (HW + 0.03), H0 + 0.12), "leather_dark", rot=(-sy * ang, 0, 0))
    p.log((-HL - 0.3, 0, H1 + 0.04), (HL + 0.3, 0, H1 + 0.04), 0.045, tile="wood")
    # guy ropes from ridge ends down to pegs beyond the footprint edge
    for sx in (-1, 1):
        p.log((sx * (HL + 0.26), 0, H1 + 0.04), (sx * 1.38, 0, 0.06), 0.012, tile="rope", seg=4, end_tile="rope")
        p.log((sx * 1.4, 0, -0.02), (sx * 1.42, 0, 0.2), 0.03, tile="wood", seg=5)
    for sy in (-1, 1):
        for sx in (-1, 1):
            p.log((sx * HL, sy * (HW + 0.06), H0), (sx * 1.38, sy * 0.9, 0.06), 0.012, tile="rope", seg=4, end_tile="rope")
            p.log((sx * 1.4, sy * 0.9, -0.02), (sx * 1.42, sy * 0.9, 0.2), 0.028, tile="wood", seg=5)
    # shade floor: a hide groundsheet, a bedroll and a crate of supplies
    g = GROUND - 0.005
    p.box((1.5, 1.24, 0.025), (0.1, 0.02, g + 0.0125), "hide", tile_m=0.6)
    p.box((0.62, 0.95, 0.06), (-0.35, 0.1, g + 0.05), "weave", tile_m=0.6)
    p.cyl(0.085, 0.55, (-0.35, -0.42, g + 0.1), "fiber", rot=(0, 90, 0), seg=8, cap_tile="fiber")
    _crate(p, (0.44, 0.4, 0.36), (0.62, 0.22, g + 0.205), 9)
    p.cyl(0.1, 0.16, (0.6, -0.24, g + 0.105), "clay", seg=8, r2=0.08, cap_tile="clay_dark")
    return [(p, (0, 0, 0))]


def fence_fortified():
    """Fortified palisade run: a tight row of thick logs sharpened to points, two rails behind them
    and rope lashings on two stakes (2x1). Neighbours meet end to end like the plain fence."""
    p = Part("fence_fortified")
    n = 9
    xs = [-0.92 + i * (1.84 / (n - 1)) for i in range(n)]
    rails = (0.45, 1.45)
    for z in rails:  # rails behind the palisade
        p.log((-0.98, 0.13, z), (0.98, 0.13, z), 0.04, tile="wood_dark")
    for i, x in enumerate(xs):
        h = 2.0 + 0.1 * ((i * 37) % 3)
        r = 0.064 + 0.012 * (i % 2)
        tip = 0.32
        p.log((x, 0.0, -0.02), (x, 0.0, h - tip), r, seg=7)
        # sharpened tip: a long four-sided point in fresh pale wood
        p.cyl(r, tip, (x, 0.0, h - tip / 2), "wood", seg=4, r2=0.012, rot=(0, 0, 45), cap_tile="log_end")
        p.cyl(r + 0.006, 0.03, (x, 0.0, h - tip), "wood_dark", seg=7)
        # a shorter log in front of each tall one: the palisade has no see-through gaps
        p.log((x + 0.1, -0.13, -0.02), (x + 0.1, -0.13, h - 0.7 - tip), r * 0.92, seg=6)
        p.cyl(r * 0.92, tip, (x + 0.1, -0.13, h - 0.7 - tip / 2), "wood", seg=4, r2=0.01, rot=(0, 0, 45))
        if i in (2, 6):  # rope lashing round the stake at both rails
            for z in rails:
                p.cyl(r + 0.004, 0.05, (x, 0.0, z), "rope", seg=8)

    # a diagonal brace across the back and rocks at the feet
    p.log((-0.6, 0.22, 0.06), (0.25, 0.22, 1.5), 0.032, tile="wood")
    for i, x in enumerate((-0.55, 0.3)):
        p.rock(0.09, (x, -0.22, GROUND + 0.01), tile="stone", squash=(1.2, 1.1, 0.5), seed=210 + i)
    return [(p, (0, 0, 0))]


def _field(name, fx, fy, rows):
    """Tilled field: raised soil ridges and dark furrows running along X inside a low log border
    with corner stakes, a hoe laid on the rows, a seed basket and a watering bucket. fx/fy are the
    footprint in metres; rows is the number of ridges. A field gets no foundation disc (it is its own
    dirt); the bed stands 0.1 m proud as a raised bed on the terrain, and nothing rises past ~0.33 m:
    a field must not block like a crate (PropVisuals sizes the collider from the AABB)."""
    p = Part(name)
    hx, hy = fx / 2 - 0.09, fy / 2 - 0.09
    top = GROUND + 0.02  # bed top
    # soil bed, then a dark tilled layer over it: the furrow floor between the ridges
    p.box((2 * hx, 2 * hy, top), (0, 0, top / 2), "dirt", tile_m=0.55)
    p.box((2 * hx - 0.1, 2 * hy - 0.1, 0.012), (0, 0, top + 0.004), "soot", tile_m=0.5)
    # ridges: heaped soil, built as short segments with varied height so no long flat plane
    # catches the light and reads as a plank; the dark layer shows between neighbours as the furrow
    pitch = 2 * hy / rows
    seg = 6
    span = 2 * hx - 0.24
    for i in range(rows):
        y = -hy + pitch * (i + 0.5)
        hw_ = pitch * 0.34
        for k in range(seg):
            x0 = -hx + 0.12 + k * span / seg
            hh = 0.05 + 0.035 * ((i * 7 + k * 5) % 4) / 3
            yj = y + 0.02 * (((i * 11 + k * 7) % 3) - 1)  # break the seam line
            p.prism([(x0, yj - hw_, top + 0.005), (x0, yj + hw_, top + 0.005), (x0, yj, top + 0.005 + hh)],
                    (span / seg + 0.03, 0, 0), "clay_dark", tile_m=0.28)
    # border: logs pinned with stakes on all four sides
    for sy in (-1, 1):
        p.log((-hx - 0.02, sy * hy, GROUND + 0.05), (hx + 0.02, sy * hy, GROUND + 0.05), 0.062)
    for sx in (-1, 1):
        p.log((sx * hx, -hy, GROUND + 0.05), (sx * hx, hy, GROUND + 0.05), 0.058)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.log((sx * hx, sy * hy, -0.02), (sx * hx, sy * hy, 0.26), 0.05, tile="wood_dark", seg=6)
            p.cyl(0.05, 0.06, (sx * hx, sy * hy, 0.29), "wood", seg=5, r2=0.008)
    # a hoe laid across the near rows, a seed basket and a watering bucket in the far corner
    p.log((hx - 0.7, -hy + 0.3, top + 0.08), (hx - 0.14, -hy + 0.16, top + 0.05), 0.02, tile="wood", seg=5)
    p.box((0.12, 0.16, 0.03), (hx - 0.12, -hy + 0.2, top + 0.04), "iron", rot=(8, 0, -14))
    p.cyl(0.1, 0.14, (-hx + 0.16, hy - 0.16, top + 0.07), "weave", seg=8, r2=0.12, cap_tile="fiber")
    p.cyl(0.09, 0.16, (-hx + 0.4, hy - 0.15, top + 0.08), "wood", seg=8, r2=0.105, cap_tile="water")
    return p


def _shoots(p, xs, y, h=0.14, leaf=True):
    """Young shoots standing on a ridge."""
    z = GROUND + 0.06
    for x in xs:
        p.log((x, y, z), (x, y + 0.02, z + h), 0.014, tile="fiber", seg=4, end_tile="fiber")
        if leaf:
            p.box((0.09, 0.07, 0.012), (x + 0.02, y, z + h - 0.01), "fiber", rot=(0, 18, 0))


def field_small():
    p = _field("field_small", 1.86, 1.86, 6)
    _shoots(p, [-0.4 + 0.2 * k for k in range(5)], -0.42)  # a few young shoots in one row
    return [(p, (0, 0, 0))]


def field_large():
    p = _field("field_large", 2.86, 2.86, 9)
    _shoots(p, [-0.9 + 0.3 * k for k in range(7)], 0.62)
    _shoots(p, [-0.2 + 0.24 * k for k in range(5)], -0.9, h=0.12, leaf=False)
    return [(p, (0, 0, 0))]


def log_shelter():
    """Small log hut: stacked-log back and side walls, steep gable thatch roof with the ridge into
    the depth, open gable front facing the camera; hide bed, crate and pot inside, fire pit and log
    seat out front (4x4, the hut itself about 3 x 2.6 m so the yard reads). Front faces -Y."""
    p = Part("log_shelter")
    hw, hd = 1.5, 1.3     # half width (X), half depth (Y)
    eave, ridge = 1.98, 3.0  # 1.9 m clear under the lintel: a 1.8 m survivor walks in upright
    r = 0.1
    # back wall: stacked logs, ends interlocked at the corners
    z, row = r * 0.9, 0
    while z < eave + 0.2:
        ex = 0.09 if row % 2 == 0 else 0.015
        p.log((-hw - ex, hd, z), (hw + ex, hd, z), r * (1.0 if row % 2 else 0.92))
        z += 2 * r * 0.9
        row += 1
    # side walls: five low logs each (~0.9 m), open above so the camera sees in
    for sx in (-1, 1):
        for i in range(5):
            zz = r * 0.9 + i * 2 * r * 0.9
            p.log((sx * hw, hd, zz), (sx * hw, -hd, zz), r * (0.95 if i % 2 else 1.0))
    # front: corner posts to the eave, a lintel, and a centre post to the ridge
    for sx in (-1, 1):
        p.log((sx * (hw - 0.02), -hd, -0.02), (sx * (hw - 0.02), -hd, eave), 0.08, tile="wood_dark", seg=7)
        p.cyl(0.085, 0.07, (sx * (hw - 0.02), -hd, eave - 0.24), "rope", seg=6)
    p.log((-hw, -hd, eave), (hw, -hd, eave), 0.065, tile="wood")
    p.log((0, -hd, eave - 0.06), (0, -hd, ridge), 0.05, tile="wood_dark", seg=6)
    p.log((0, hd + 0.14, ridge + 0.02), (0, -hd - 0.16, ridge + 0.02), 0.055, tile="wood_dark", seg=6)
    # gable: bark-filled back triangle, heavy barge boards across the open front
    p.prism([(-hw, hd, eave), (hw, hd, eave), (0, hd, ridge)], (0, 0.1, 0), "bark", tile_m=0.8)
    for sx in (-1, 1):
        p.log((sx * (hw + 0.02), -hd - 0.1, eave - 0.05), (0, -hd - 0.1, ridge + 0.04), 0.055, tile="wood")
    # roof: rafters, then steep thatch slopes with a fringe of straw along the eaves
    run = hw + 0.12
    rise = ridge - eave
    ang = math.degrees(math.atan2(rise, run))
    slope = math.hypot(run, rise)
    for sx in (-1, 1):
        for k in (-0.95, -0.1, 0.75, 1.15):
            p.log((0, k, ridge - 0.02), (sx * (hw + 0.08), k, eave - 0.02), 0.038, tile="wood_dark", seg=5)
        p.box((slope + 0.1, 2 * hd + 0.34, 0.12), (sx * run / 2, 0, eave + rise / 2 + 0.04), "thatch",
              rot=(0, sx * ang, 0), tile_m=1.2)
        for k in range(8):
            y = -hd - 0.14 + k * (2 * hd + 0.28) / 7
            p.box((0.13, 0.22, 0.1), (sx * (run - 0.02), y, eave + 0.0), "thatch", rot=(0, sx * ang + 16, 6 * (k % 2)),
                  tile_m=0.5)
    p.log((0, -hd - 0.28, ridge + 0.04), (0, hd + 0.16, ridge + 0.04), 0.07, tile="wood_dark")
    # inside: hide bed on a plank platform, crate and pot by the back wall
    for cx in (0.35, 1.2):
        p.log((cx, 0.9, 0), (cx, 0.9, 0.3), 0.045, seg=6)
    p.box((1.0, 0.76, 0.05), (0.78, 0.9, 0.32), "plank", tile_m=0.8)
    p.box((0.9, 0.66, 0.1), (0.78, 0.9, 0.4), "hide", tile_m=0.5)
    p.cyl(0.085, 0.52, (0.78, 0.6, 0.44), "fiber", rot=(0, 90, 0), seg=8, cap_tile="fiber")
    _crate(p, (0.4, 0.38, 0.38), (-0.85, 1.0, 0.19), 4)
    p.cyl(0.08, 0.17, (-0.85, 0.72, 0.46), "clay", seg=9, r2=0.066, cap_tile="clay_dark")
    p.torus(0.07, 0.018, (-0.5, 1.05, GROUND + 0.015), "rope", seg=10, tube=4)
    # front yard: fire pit (the ring around the yard fire, not the hut centre), log seat, firewood
    _stone_ring(p, 8, 0.3, 0.09, 61, tile="stone", z=GROUND - 0.03, cx=-0.85, cy=-1.4)
    p.cyl(0.22, 0.025, (-0.85, -1.4, GROUND + 0.012), "ash", seg=8, cap_tile="ash")
    p.cyl(0.11, 0.03, (-0.85, -1.4, GROUND + 0.02), "ember", seg=7, cap_tile="ember")
    p.log((-0.95, -1.4, GROUND + 0.07), (-0.73, -1.36, GROUND + 0.07), 0.033, tile="char", seg=5, end_tile="ember")
    p.log((0.35, -1.6, 0.11), (1.25, -1.6, 0.11), 0.11, tile="bark", seg=8)
    for i in range(3):
        p.log((-1.62, 0.6 - 0.1 * i, GROUND + 0.03 + 0.07 * i), (-1.62, -0.5, GROUND + 0.03 + 0.07 * i), 0.045, tile="bark", seg=6)
    return [(p, (0, 0, 0))]


def cabin_bed():
    """Wooden bed: plank frame and legs, hide mattress, a fur blanket folded over the foot end, a
    plank headboard, pillow, boots and a stool with a clay lamp (2x2)."""
    p = Part("cabin_bed")
    L, W, H = 2.0, 0.94, 0.42
    M = L - 0.16  # mattress length: 1.84 m, longer than the 1.8 m survivor
    for sy in (-1, 1):
        p.box((L, 0.09, 0.1), (0, sy * (W / 2 - 0.05), H - 0.05), "plank", tile_m=1.3)
    for sx in (-1, 1):
        p.box((0.1, W, 0.1), (sx * (L / 2 - 0.05), 0, H - 0.05), "plank", tile_m=1.0)
        for sy in (-1, 1):
            p.log((sx * (L / 2 - 0.08), sy * (W / 2 - 0.08), 0), (sx * (L / 2 - 0.08), sy * (W / 2 - 0.08), H - 0.1), 0.055,
                  tile="wood_dark", seg=6)
    # headboard: two square posts, three boards, a rail across the top
    hx = -L / 2 + 0.05
    for sy in (-1, 1):
        p.box((0.1, 0.1, 0.76), (hx, sy * (W / 2 - 0.05), H + 0.32), "wood", tile_m=0.7)
        p.box((0.12, 0.12, 0.04), (hx, sy * (W / 2 - 0.05), H + 0.71), "wood_dark", tile_m=0.4)
    for z in (H + 0.2, H + 0.4, H + 0.6):
        p.box((0.05, W - 0.1, 0.14), (hx, 0, z), "plank", tile_m=0.7)
    # foot rail on short posts
    for sy in (-1, 1):
        p.log((L / 2 - 0.04, sy * (W / 2 - 0.05), H - 0.02), (L / 2 - 0.04, sy * (W / 2 - 0.05), H + 0.22), 0.045,
              tile="wood_dark", seg=6)
    p.log((L / 2 - 0.04, -W / 2 + 0.02, H + 0.2), (L / 2 - 0.04, W / 2 - 0.02, H + 0.2), 0.045, tile="wood")
    # slats and the hide mattress, with a worn leather top layer
    for i in range(5):
        p.box((M, (W - 0.2) / 5 - 0.04, 0.04), (0, -W / 2 + 0.1 + (i + 0.5) * (W - 0.2) / 5, H), "wood", tile_m=0.8)
    p.box((M, W - 0.1, 0.12), (0.0, 0, H + 0.07), "hide", tile_m=0.6)
    p.box((M - 0.2, W - 0.26, 0.05), (0.03, 0, H + 0.15), "leather_dark", tile_m=0.6)
    # pillow at the head
    p.cyl(0.075, 0.5, (-L / 2 + 0.3, 0, H + 0.19), "fiber", rot=(0, 90, 0), seg=8, cap_tile="fiber")
    for y in (-0.16, 0.16):
        p.cyl(0.08, 0.035, (-L / 2 + 0.3, y, H + 0.19), "rope", rot=(0, 90, 0), seg=8)
    # fur blanket folded over the foot half: three thin layers, the top one turned back
    for i, (zz, yy, ln, tile) in enumerate(((0.0, 0.42, 0.9, "hide"), (0.06, 0.4, 0.84, "fiber"), (0.11, 0.36, 0.64, "leather_dark"))):
        p.box((ln * 0.96, W + 0.04 - 0.02 * i, 0.05), (0.16 + 0.02 * i, -0.02, H + 0.2 + zz), tile, rot=(0, 0, 2 * i), tile_m=0.7)
    p.cyl(0.05, W - 0.06, (0.16 + 0.9 * 0.48, -0.02, H + 0.2), "hide", rot=(0, 90, 0), seg=7, cap_tile="fiber")
    # a stool by the head on the camera side with a small clay lamp burning
    stx, sty = -L / 2 + 0.42, -W / 2 - 0.2
    p.cyl(0.14, 0.36, (stx, sty, 0.18), "bark", seg=8, cap_tile="log_end")
    p.cyl(0.055, 0.05, (stx, sty, 0.39), "clay", seg=8, r2=0.07, cap_tile="ember")
    # boots on the floor beside the foot and a folded shirt over the foot rail
    for x in (L / 2 - 0.5, L / 2 - 0.32):
        p.box((0.09, 0.1, 0.18), (x, -W / 2 - 0.12, 0.09), "leather_dark")
        p.box((0.09, 0.22, 0.05), (x, -W / 2 - 0.18, 0.025), "leather_dark")
    p.box((0.2, 0.22, 0.03), (L / 2 - 0.1, 0.16, H + 0.24), "canvas", rot=(0, 0, 8), tile_m=0.4)
    # centre the bed plus its stool on the origin (check_manifest: origin within 0.15 m)
    lo = min(v.co.y for v in p.bm.verts)
    hi = max(v.co.y for v in p.bm.verts)
    bmesh.ops.translate(p.bm, verts=p.bm.verts, vec=(0, -(lo + hi) / 2, 0))
    return [(p, (0, 0, 0))]


# ------------------------------------------------------------------ station art (dsc-stationart)
# Crafting stations and construction sites (owner's guide 15, docs/design/durango-prompts/30_*).
# Same kit and atlas as the rest of the set: one material, origin at the ground centre, front -Y
# (which becomes +Z in Godot, towards the iso camera). Sizes in metres next to a 1.8 m survivor.

def _nailed_plank(p, size, loc, tile="plank", nails=True, rot=(0, 0, 0)):
    """A plank with iron nail heads at both ends."""
    p.box(size, loc, tile, rot=rot, tile_m=1.6)
    if nails:
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.box((0.025, 0.025, 0.012), (loc[0] + sx * (size[0] / 2 - 0.05),
                                              loc[1] + sy * (size[1] / 2 - 0.05),
                                              loc[2] + size[2] / 2 + 0.005), "iron", rot=rot)


def _rope_lashing(p, x, y, z, r=0.075):
    """A strap wound round a post: a short cylinder of rope plus a loose tail."""
    p.cyl(r, 0.06, (x, y, z), "rope", seg=8)
    p.log((x + r * 0.7, y, z - 0.02), (x + r * 1.5, y - r * 0.6, z - 0.09), 0.012, tile="rope", seg=4,
          end_tile="rope")


def makeshift_workbench():
    """Tier 0: a flat stone slab on four lashed sticks (1.2 x 0.6 m, top 0.78 m)."""
    p = Part("makeshift_workbench")
    L, W, H = 1.2, 0.6, 0.78
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (L / 2 - 0.14), sy * (W / 2 - 0.1)
            p.log((x + sx * 0.06, y + sy * 0.05, 0.0), (x, y, H - 0.06), 0.033, tile="bark", seg=6)
            _rope_lashing(p, x, y, H - 0.12, r=0.05)
    # cross sticks tying the legs, lashed
    for sy in (-1, 1):
        p.log((-L / 2 + 0.1, sy * (W / 2 - 0.1), 0.3), (L / 2 - 0.1, sy * (W / 2 - 0.1), 0.3), 0.022,
              tile="bark", seg=5)
    # the flat stone slab: two stones, the bigger one on top
    p.rock(0.3, (-0.12, 0.0, H - 0.05), tile="stone", squash=(1.5, 1.15, 0.24), seed=101)
    p.rock(0.24, (0.42, 0.05, H - 0.04), tile="stone_dark", squash=(1.1, 1.0, 0.22), seed=102)
    # a stone hammer and a stick of cord left on the slab
    p.log((-0.02, -0.08, H + 0.02), (0.16, -0.14, H + 0.02), 0.018, tile="wood_dark", seg=5)
    p.rock(0.05, (0.18, -0.15, H + 0.04), tile="stone_dark", squash=(1.1, 0.9, 0.8), seed=103)
    p.torus(0.07, 0.016, (0.4, -0.14, H + 0.01), "rope", seg=10, tube=4)
    return [(p, (0, 0, 0))]


def basic_workbench():
    """Tier 1: rough planks on four pillars, held with strap lashings (1.6 x 0.7 m, top 0.85 m)."""
    p = Part("basic_workbench")
    L, W, H = 1.6, 0.7, 0.85
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (L / 2 - 0.12), sy * (W / 2 - 0.09)
            p.log((x, y, 0.0), (x, y, H - 0.07), 0.048, tile="bark", seg=7)
            _rope_lashing(p, x, y, H - 0.14)
    # two rough planks across the top, a third short one under them
    p.box((L, 0.3, 0.06), (0, 0.16, H - 0.03), "wood", tile_m=1.6)
    p.box((L, 0.28, 0.06), (0, -0.16, H - 0.03), "plank", tile_m=1.6)
    p.box((L - 0.4, W - 0.1, 0.05), (0, 0, 0.34), "plank", tile_m=1.2)
    for sx in (-1, 1):
        p.plank((sx * (L / 2 - 0.12), -W / 2 + 0.08, 0.34), (sx * (L / 2 - 0.12), W / 2 - 0.08, 0.34), 0.07, 0.05,
                "wood_dark")
    # a stone adze head and a stick of cord on the bench
    p.log((-0.3, -0.02, H + 0.03), (-0.05, -0.1, H + 0.03), 0.02, tile="wood", seg=5)
    p.box((0.09, 0.05, 0.07), (-0.02, -0.11, H + 0.05), "stone_dark", rot=(0, 0, -18), tile_m=0.3)
    p.torus(0.08, 0.018, (0.42, 0.1, H + 0.01), "rope", seg=10, tube=4)
    # two spare planks leaning on the bench end
    p.plank((L / 2 - 0.1, 0.1, 0.02), (L / 2 + 0.16, 0.34, 0.95), 0.2, 0.045, "wood", up=(0, 1, 0))
    p.plank((L / 2 - 0.14, 0.22, 0.02), (L / 2 + 0.1, 0.46, 0.9), 0.18, 0.04, "wood_dark", up=(0, 1, 0))
    return [(p, (0, 0, 0))]


def journeyman_workbench():
    """Tier 2: trimmed planks nailed to squared legs, a bench vice and a tool rack (1.8 x 0.8 m)."""
    p = Part("journeyman_workbench")
    L, W, H = 1.8, 0.8, 0.9
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (L / 2 - 0.13), sy * (W / 2 - 0.1)
            p.box((0.1, 0.1, H - 0.08), (x, y, (H - 0.08) / 2), "wood_dark", tile_m=0.7)
            p.box((0.13, 0.13, 0.05), (x, y, 0.025), "stone_dark", tile_m=0.4)
    # four trimmed planks nailed down
    for i in range(4):
        y = -W / 2 + (i + 0.5) * W / 4
        _nailed_plank(p, (L, W / 4 - 0.02, 0.055), (0, y, H - 0.028), "plank")
    # apron rails and a lower shelf
    for sy in (-1, 1):
        p.box((L - 0.1, 0.06, 0.14), (0, sy * (W / 2 - 0.05), H - 0.16), "wood", tile_m=1.0)
    p.box((L - 0.5, W - 0.2, 0.05), (0, 0, 0.32), "plank", tile_m=1.4)
    for sx in (-1, 1):
        p.box((0.08, W - 0.2, 0.06), (sx * (L / 2 - 0.3), 0, 0.29), "wood_dark", tile_m=0.6)
    # bench vice at the front left: iron jaws on a wooden screw
    vx, vy = -L / 2 + 0.3, -W / 2 + 0.02
    p.box((0.24, 0.16, 0.1), (vx, vy, H + 0.05), "iron", tile_m=0.3)
    p.box((0.22, 0.05, 0.14), (vx, vy + 0.04, H + 0.15), "iron", tile_m=0.3)
    p.cyl(0.022, 0.2, (vx, vy - 0.14, H + 0.15), "iron", rot=(90, 0, 0), seg=6)
    p.cyl(0.04, 0.025, (vx, vy - 0.23, H + 0.15), "iron", rot=(90, 0, 0), seg=6)
    p.box((0.34, 0.05, 0.05), (vx + 0.04, vy + 0.06, H + 0.24), "wood", rot=(0, 3, 0))
    # tool rack on the back edge: two posts, a rail and pegs with hanging tools
    for sx in (-1, 1):
        p.box((0.07, 0.07, 0.62), (sx * 0.62, W / 2 - 0.06, H + 0.31), "wood", tile_m=0.6)
    p.box((1.34, 0.06, 0.09), (0, W / 2 - 0.06, H + 0.58), "plank", tile_m=1.0)
    for tx, t_tile, t_len in ((-0.4, "iron", 0.26), (-0.16, "stone_dark", 0.2), (0.16, "iron", 0.24),
                              (0.4, "wood_dark", 0.22)):
        p.cyl(0.016, 0.07, (tx, W / 2 - 0.1, H + 0.55), "wood", rot=(90, 0, 0), seg=5)
        p.box((0.05, 0.05, t_len), (tx, W / 2 - 0.13, H + 0.55 - t_len / 2), t_tile, tile_m=0.3)
    # a mallet on the bench and a coil of rope
    p.log((0.05, -0.2, H + 0.03), (0.32, -0.12, H + 0.03), 0.02, tile="wood", seg=5)
    p.box((0.1, 0.06, 0.06), (0.35, -0.11, H + 0.04), "wood_dark", rot=(0, 0, -20), tile_m=0.3)
    p.torus(0.08, 0.018, (0.68, 0.16, H + 0.01), "rope", seg=10, tube=4)
    return [(p, (0, 0, 0))]


def expert_workbench():
    """Tier 3: processed planks on heavy legs, iron fittings, drawers and glue pots (2.0 x 0.9 m)."""
    p = Part("expert_workbench")
    L, W, H = 2.0, 0.9, 0.95
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (L / 2 - 0.14), sy * (W / 2 - 0.12)
            p.box((0.13, 0.13, H - 0.1), (x, y, (H - 0.1) / 2), "wood_dark", tile_m=0.8)
            p.box((0.16, 0.16, 0.04), (x, y, 0.02), "stone_dark", tile_m=0.4)
            # iron corner bracket at the top of each leg
            p.box((0.05, 0.16, 0.1), (x, y, H - 0.14), "iron", tile_m=0.3)
    # the top: four processed planks with an iron edge strip along the front
    for i in range(4):
        y = -W / 2 + (i + 0.5) * W / 4
        _nailed_plank(p, (L, W / 4 - 0.02, 0.06), (0, y, H - 0.03), "plank")
    p.box((L, 0.05, 0.09), (0, -W / 2 + 0.02, H - 0.04), "iron", tile_m=1.4)
    # drawer unit under the top on the right half: two drawers with iron pulls
    for i, (dx, dz) in enumerate(((0.55, H - 0.19), (0.55, H - 0.38))):
        p.box((0.78, W - 0.22, 0.16), (dx, 0, dz), "plank", tile_m=1.0)
        p.box((0.72, 0.05, 0.13), (dx, -W / 2 + 0.13, dz), "wood", tile_m=0.8)
        p.box((0.16, 0.04, 0.035), (dx, -W / 2 + 0.09, dz), "iron", tile_m=0.3)
        p.box((0.05, 0.05, 0.02), (dx + 0.34, -W / 2 + 0.11, dz), "iron", tile_m=0.2)
    p.box((0.86, W - 0.16, 0.04), (0.55, 0, H - 0.09), "plank", tile_m=1.0)
    # an open shelf on the left with jars and a stack of nails
    p.box((0.6, W - 0.24, 0.05), (-0.62, 0, 0.36), "plank", tile_m=0.8)
    p.cyl(0.075, 0.16, (-0.72, -0.16, 0.46), "clay", seg=9, r2=0.085, cap_tile="clay_dark")
    p.cyl(0.065, 0.13, (-0.5, -0.12, 0.45), "clay", seg=9, r2=0.075, cap_tile="clay_dark")
    p.box((0.14, 0.1, 0.05), (-0.58, 0.18, 0.41), "iron", tile_m=0.3)
    # two glue pots with lids on the bench, and a strung bow drill
    for px, py in ((-0.2, -0.16), (0.02, -0.22)):
        p.cyl(0.085, 0.15, (px, py, H + 0.075), "clay", seg=10, r2=0.075, cap_tile="clay_dark")
        p.cyl(0.082, 0.02, (px, py, H + 0.15), "wood", seg=10)
    p.log((0.6, -0.2, H + 0.04), (0.86, -0.26, H + 0.04), 0.018, tile="wood", seg=5)
    p.log((0.72, -0.3, H + 0.02), (0.76, -0.12, H + 0.04), 0.012, tile="rope", seg=4, end_tile="rope")
    # a coil of rope and a hand saw hanging on the front edge
    p.torus(0.085, 0.02, (-0.86, 0.22, H + 0.01), "rope", seg=10, tube=4)
    p.box((0.42, 0.035, 0.09), (-0.35, -W / 2 - 0.01, H - 0.12), "iron", rot=(0, 8, 0), tile_m=0.4)
    p.box((0.12, 0.05, 0.07), (-0.58, -W / 2 - 0.01, H - 0.15), "wood_dark", rot=(0, 8, 0), tile_m=0.3)
    return [(p, (0, 0, 0))]


def _dome(p, r, h, z0, tile="clay", seg=14, rings=4, cx=0.0, cy=0.0):
    """A dome built from stacked frustums: the kiln and oven shells."""
    for i in range(rings):
        t0, t1 = i / rings, (i + 1) / rings
        r0 = max(r * math.cos(t0 * math.pi / 2), 0.03)
        r1 = max(r * math.cos(t1 * math.pi / 2), 0.03)
        za, zb = z0 + h * t0, z0 + h * t1
        p.cyl(r0, zb - za, (cx, cy, (za + zb) / 2), tile, seg=seg, r2=r1, cap_tile=tile)


def kiln():
    """Clay dome kiln: a firebox with an arched mouth under a domed shell, chimney on top (2x2,
    about 1.6 m tall)."""
    p = Part("kiln")
    # plinth
    p.box((1.7, 1.6, 0.1), (0, 0.05, 0.05), "cobble", tile_m=0.9)
    # firebox: two side walls, a back wall and a soot-lined mouth at the front
    for sx in (-1, 1):
        p.box((0.3, 1.0, 0.5), (sx * 0.5, -0.1, 0.35), "clay", tile_m=0.7)
    p.box((1.3, 0.22, 0.5), (0, 0.32, 0.35), "clay", tile_m=0.7)
    p.box((0.72, 0.06, 0.42), (0, -0.52, 0.31), "soot", tile_m=0.5)  # dark inside the mouth
    p.box((0.8, 0.9, 0.04), (0, -0.1, 0.12), "ash", tile_m=0.6)
    p.cyl(0.22, 0.03, (0, -0.12, 0.14), "ember", seg=10, cap_tile="ember")
    for i, (lx, ly) in enumerate(((-0.2, -0.2), (0.18, -0.28), (0.0, 0.08))):
        p.log((lx - 0.12, ly, 0.17), (lx + 0.12, ly + 0.05, 0.19), 0.035, tile="char", seg=5, end_tile="ember")
    # the clay dome shell over the firebox
    _dome(p, 0.72, 0.72, 0.56, tile="clay", seg=14, rings=4, cy=0.06)
    p.cyl(0.74, 0.06, (0, 0.06, 0.58), "clay_dark", seg=14, cap_tile="clay")
    # a collar and the chimney
    p.cyl(0.19, 0.1, (0, 0.06, 1.29), "clay_dark", seg=10, cap_tile="clay_dark")
    p.cyl(0.16, 0.34, (0, 0.06, 1.48), "clay", seg=10, cap_tile="soot")
    # the mouth's clay arch, made of two leaning slabs and a lintel
    for sx in (-1, 1):
        p.box((0.16, 0.14, 0.5), (sx * 0.36, -0.56, 0.36), "clay_dark", rot=(0, sx * 10, 0), tile_m=0.4)
    p.box((0.9, 0.16, 0.14), (0, -0.56, 0.66), "clay_dark", tile_m=0.5)
    # firewood stacked at the side and a clay pot waiting to be fired
    for i in range(3):
        p.log((-0.98, 0.08 + i * 0.17, 0.07 + i * 0.09), (-0.98, 0.22 + i * 0.17, 0.07 + i * 0.09), 0.05,
              tile="bark", seg=6)
    for i in range(2):
        p.log((-0.86, 0.12 + i * 0.18, 0.06), (-0.86, 0.26 + i * 0.18, 0.06), 0.05, tile="bark", seg=6)
    p.cyl(0.11, 0.18, (0.95, -0.35, 0.19), "clay", seg=10, r2=0.13, cap_tile="clay_dark")
    p.cyl(0.125, 0.03, (0.95, -0.35, 0.29), "clay_dark", seg=10)
    return [(p, (0, 0, 0))]


def _loom_frame(p, half_w, height, warp_n, cloth_w, cloth_d, bench=False):
    """Shared frame for the looms: two posts, a warp beam, a heddle bar, a top beam, warp threads
    and a partly woven cloth."""
    for sx in (-1, 1):
        p.box((0.09, 0.09, height), (sx * half_w, 0, height / 2), "wood", tile_m=0.7)
        p.box((0.14, 0.5, 0.08), (sx * half_w, 0, 0.04), "wood_dark", tile_m=0.5)
        p.log((sx * half_w, 0, height - 0.2), (sx * (half_w - 0.32), 0, height - 0.5), 0.035, tile="wood_dark",
              seg=5)
    # beams along X
    p.log((-half_w, 0, height - 0.08), (half_w, 0, height - 0.08), 0.05, tile="wood_dark")
    p.log((-half_w, 0, height * 0.66), (half_w, 0, height * 0.66), 0.035, tile="wood", seg=6)
    p.log((-half_w, 0, 0.28), (half_w, 0, 0.28), 0.05, tile="wood_dark")  # warp beam
    # warp threads: vertical strands from the warp beam up to the heddle bar
    z0, z1 = 0.3, height * 0.66
    for i in range(warp_n):
        x = -cloth_w / 2 + (i + 0.5) * cloth_w / warp_n
        p.box((0.012, cloth_d, z1 - z0), (x, 0, (z0 + z1) / 2), "fiber", tile_m=0.6)
    # the woven part hanging below the heddle bar
    p.box((cloth_w, cloth_d * 0.92, 0.03), (0, 0, z1 - 0.02), "canvas", tile_m=0.8)
    p.box((cloth_w * 0.98, cloth_d * 0.9, height * 0.66 - 0.42), (0, 0, (0.42 + z1 - 0.04) / 2), "canvas",
          tile_m=1.2)
    # the shuttle lying on the cloth and a peg row
    p.box((0.16, 0.05, 0.035), (cloth_w * 0.2, 0, z1 - 0.06), "wood", rot=(0, 0, 12), tile_m=0.3)
    for i in range(3):
        p.cyl(0.014, 0.12, (-cloth_w * 0.3 + i * 0.1, cloth_d * 0.5, z1 - 0.02), "wood", rot=(90, 0, 0), seg=5)
    if bench:
        # a bench in front of the loom for the weaver
        p.box((cloth_w * 0.8, 0.34, 0.05), (0, -cloth_d * 0.9 - 0.24, 0.46), "plank", tile_m=1.0)
        for sx in (-1, 1):
            p.log((sx * cloth_w * 0.32, -cloth_d * 0.9 - 0.24, 0), (sx * cloth_w * 0.32, -cloth_d * 0.9 - 0.24, 0.44),
                  0.04, tile="wood_dark", seg=6)
        p.log((-cloth_w * 0.36, -cloth_d * 0.9 - 0.24, 0.2), (cloth_w * 0.36, -cloth_d * 0.9 - 0.24, 0.2), 0.03,
              tile="wood", seg=5)


def loom():
    """Upright frame loom with warp threads and a partly woven cloth (2x1, about 1.6 m tall)."""
    p = Part("loom")
    _loom_frame(p, 0.5, 1.55, 14, 0.86, 0.34, bench=False)
    # a bundle of yarn waiting at the side and a pair of weights
    p.cyl(0.11, 0.22, (-0.78, 0.12, 0.11), "weave", seg=9, r2=0.12, cap_tile="fiber")
    p.cyl(0.06, 0.1, (0.76, 0.06, 0.05), "fiber", seg=8, cap_tile="fiber")
    return [(p, (0, 0, 0))]


def large_loom():
    """The wider loom: a 2 m frame with more warp threads, a finished cloth roll and a bench (3x2,
    about 1.6 m tall)."""
    p = Part("large_loom")
    _loom_frame(p, 0.92, 1.6, 22, 1.6, 0.42, bench=True)
    # the finished cloth rolled on the warp beam
    p.cyl(0.11, 1.5, (0, 0, 0.4), "canvas", rot=(0, 90, 0), seg=10, cap_tile="canvas")
    p.cyl(0.03, 1.6, (0, 0, 0.4), "wood", rot=(0, 90, 0), seg=6)
    # yarn baskets on both sides
    p.cyl(0.13, 0.2, (-1.15, 0.1, 0.1), "weave", seg=9, r2=0.14, cap_tile="fiber")
    p.cyl(0.11, 0.18, (1.12, -0.05, 0.09), "weave", seg=9, r2=0.12, cap_tile="fiber")
    return [(p, (0, 0, 0))]


def oven():
    """Stone bread oven: a stone base with an arched mouth, a stone dome and a flue (2x2, 1.4 m)."""
    p = Part("oven")
    # hearth base with a mouth at the front
    p.box((1.3, 1.2, 0.1), (0, 0.05, 0.05), "cobble", tile_m=0.8)
    for sx in (-1, 1):
        p.box((0.26, 1.05, 0.46), (sx * 0.5, 0.02, 0.33), "stone", tile_m=0.7)
    p.box((1.2, 0.2, 0.46), (0, 0.45, 0.33), "stone", tile_m=0.7)
    p.box((0.66, 0.06, 0.34), (0, -0.5, 0.27), "soot", tile_m=0.5)
    p.box((0.74, 0.9, 0.04), (0, 0.0, 0.11), "ash", tile_m=0.6)
    p.cyl(0.2, 0.03, (0, 0.02, 0.13), "ember", seg=10, cap_tile="ember")
    p.log((-0.18, -0.18, 0.16), (0.2, -0.24, 0.17), 0.032, tile="char", seg=5, end_tile="ember")
    # the stone dome
    _dome(p, 0.62, 0.5, 0.52, tile="stone", seg=14, rings=4, cy=0.05)
    p.cyl(0.64, 0.05, (0, 0.05, 0.54), "stone_dark", seg=14, cap_tile="stone")
    # the flue
    p.cyl(0.15, 0.09, (0, 0.05, 1.04), "stone_dark", seg=10, cap_tile="stone_dark")
    p.cyl(0.12, 0.3, (0, 0.05, 1.21), "stone", seg=10, cap_tile="soot")
    # the stone arch over the mouth
    for sx in (-1, 1):
        p.box((0.18, 0.16, 0.42), (sx * 0.33, -0.52, 0.32), "stone_dark", rot=(0, sx * 12, 0), tile_m=0.4)
    p.box((0.86, 0.18, 0.14), (0, -0.52, 0.58), "stone_dark", tile_m=0.5)
    # a baking peel leaning against the oven and a loaf on a stone slab beside it
    p.log((0.78, -0.7, 0.02), (0.5, -0.42, 1.1), 0.02, tile="wood", seg=5)
    p.box((0.34, 0.26, 0.02), (0.78, -0.72, 0.03), "wood", rot=(0, 0, 18), tile_m=0.4)
    p.box((0.5, 0.42, 0.07), (0.85, 0.45, 0.04), "stone_dark", tile_m=0.5)
    # a bowl of dough ready to go in
    p.cyl(0.11, 0.07, (0.85, 0.45, 0.11), "clay", seg=9, r2=0.13, cap_tile="clay_dark")
    p.rock(0.09, (0.85, 0.45, 0.13), tile="fiber", squash=(1.2, 1.0, 0.55), seed=111)
    return [(p, (0, 0, 0))]


def large_drying_rack():
    """Two-bay drying rack on trimmed pillars, 3 m wide: rails, lashings and a spare stack of
    straps on the ground (3x1)."""
    p = Part("large_drying_rack")
    H = 1.95
    for x in (-1.42, 0.0, 1.42):
        p.box((0.13, 0.13, H), (x, 0, H / 2), "wood", tile_m=0.8)
        p.box((0.2, 0.2, 0.06), (x, 0, 0.03), "stone_dark", tile_m=0.4)
        for z in (H - 0.16, H * 0.55):
            p.cyl(0.09, 0.07, (x, 0, z), "rope", seg=8)
    # rails: two high, one lower per bay
    for y in (-0.16, 0.16):
        p.log((-1.55, y, H - 0.16), (1.55, y, H - 0.16), 0.045, tile="wood")
        p.log((-1.55, y, H * 0.55), (1.55, y, H * 0.55), 0.035, tile="wood", seg=6)
    # cross braces at the ends and between the bays
    for x in (-1.42, 0.0, 1.42):
        p.log((x, -0.16, H * 0.55), (x, 0.16, H - 0.16), 0.028, tile="wood_dark", seg=5)
    # a few straps hooked over the high rail, showing it is in use
    for i, x in enumerate((-1.1, -0.55, 0.35, 0.95)):
        p.box((0.05, 0.02, 0.42 + 0.1 * (i % 2)), (x, -0.19, H - 0.38), "fiber", rot=(0, 0, 4 * (i - 1)),
              tile_m=0.5)
    # spare straps coiled on the ground and a coil of rope
    p.torus(0.1, 0.022, (-0.75, -0.3, 0.02), "rope", seg=10, tube=4)
    for i in range(3):
        p.box((0.34, 0.1, 0.04), (0.75, -0.32, 0.02 + i * 0.045), "fiber", rot=(0, 0, -6 + 4 * i), tile_m=0.5)
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
    "large_box": large_box,
    "chest": chest,
    "barrel": barrel,
    "bucket": bucket,
    "signpost": signpost,
    "bedroll": bedroll,
    "straw_roll": straw_roll,
    "campfire_stand": campfire_stand,
    "technical_workbench": technical_workbench,
    "grindstone": grindstone,
    "fishing_stand": fishing_stand,
    "stone_grill": stone_grill,
    "tent_canvas": tent_canvas,
    "fence_fortified": fence_fortified,
    "field_small": field_small,
    "field_large": field_large,
    "log_shelter": log_shelter,
    "cabin_bed": cabin_bed,
    # station art (dsc-stationart)
    "makeshift_workbench": makeshift_workbench,
    "basic_workbench": basic_workbench,
    "journeyman_workbench": journeyman_workbench,
    "expert_workbench": expert_workbench,
    "kiln": kiln,
    "loom": loom,
    "large_loom": large_loom,
    "oven": oven,
    "large_drying_rack": large_drying_rack,
}
