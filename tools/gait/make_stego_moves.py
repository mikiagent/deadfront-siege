"""STEGOSPIN: the stegosaurus' spin and close-range clips, keyed from its idle pose on the Opus rig (34 bones, +Y forward,
the animal's left at -X, legs thigh/shin/foot/toe, front legs upperarm/forearm/foot/toe).

Owner 2026-10-31: "Stego needs a stronger twist attack, tackle attack, etc. it should be spinning a lot" / "also needs
stomp attacks" / "smaller animals hop around more than they strafe, big and heavy dinosaurs strafe more than they hop".

Every foot is planted (its pose is fixed in the world: zero slide) except inside a step, where it lifts on an arc and
lands on a new plant. A TURN clip (spin_*, pivot_*) turns the animal TURN_DEG about a planted front foot's ball (the
pivot): ClubTailBrain turns the body in code by exactly turn_deg * smoothstep((u - a) / (b - a)) about the same point
(ai.json spiked_tail: turn_deg, turn [a, b], pivot_gltf), so the clip keys the world-frame motion counter-rotated by that
turn. The pivot foot twists about its ball; the other three step round it on a schedule made here. At the clip's end the
pose is the idle pose again, so the hand-back to idle never pops.

SPIN      spin_right / spin_left 4.0 s: crouch, the tail raised and cocked, trembling (0-0.28), then a 220 deg turn about the
          inner front foot (0.28-0.86) with the tail lagging and whipping round the outside, then it settles.
PIVOT     pivot_right / pivot_left 1.6 s: a quick 90 deg repositioning turn on the inner front foot.
STOMP     stomp 1.5 s: rears the front off the left forefoot, foot hauled high and forward, slammed down (impact 0.56).
REAR SLAM rear_slam 2.2 s: rears up on the hind legs (24 deg), both forefeet high, held, slammed down together ahead
          (impact 0.62), wide.
HIND STOMP hind_stomp_left / _right 1.4 s: the hind foot on that side hauled up and out, stamped down beside the flank
          (impact 0.55), body rolled into it, tail swung toward it.
SHOVE     shove_left / shove_right 1.7 s: the SHOULDER SLAM: momentum step-in, the whole body lurched over and forward
          into that side with the shoulder dropped (impact 0.40), then it rocks back, re-plants and steadies.
TACKLE    tackle 0.9 s: the coil before the body check (crouch, head down, a forefoot paws); the brain runs it up at the
          run gait, then tackle_lunge 1.25 s: gather, a leap (airborne 0.14-0.52, carried by the brain), land, steady.

usage: Blender -b -P tools/gait/make_stego_moves.py -- <base.glb> <idle.glb> <out_dir> [clip ...]
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, IDLE, OUT = argv[:3]
ALL = ["spin_right", "spin_left", "pivot_right", "pivot_left", "stomp", "rear_slam", "hind_stomp_left", "hind_stomp_right",
       "shove_left", "shove_right", "tackle", "tackle_lunge"]
WANT = argv[3:] or ALL
FPS = 24
TAILS = [f"tail_0{i}" for i in range(1, 8)]
LEGS = [("hind_thigh_L", "hind_shin_L", "hind_foot_L"), ("hind_thigh_R", "hind_shin_R", "hind_foot_R"),
        ("front_upperarm_L", "front_forearm_L", "front_foot_L"), ("front_upperarm_R", "front_forearm_R", "front_foot_R")]
FEET = [l[2] for l in LEGS]
TOE = {f: f.replace("foot", "toe") for f in FEET}
Z, X, Y = Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def keys(u, pts):
    """Piecewise smoothstep through (u, value) points."""
    if not pts:
        return 0.0
    if u <= pts[0][0]:
        return pts[0][1]
    for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
        if u <= u1:
            return v0 + (v1 - v0) * smooth((u - u0) / max(u1 - u0, 1e-6))
    return pts[-1][1]


Z0 = [(0, 0), (1.0, 0)]
# Curves (u in [0, 1]): turn: see turn_deg; yaw: small body yaw (deg, + = left, CCW) about the pivot; tail: tail yaw per
# bone, lagged down the chain (deg, + = club to its right); lift: tail_01 pitch (deg, + raises the club); crouch: body
# drop (m); roll (deg, + = right side down); pitch (deg, + = front up, about the hind ankles); shift (m, + = to its right);
# back (m, + = toward the tail); head (deg, + = nose up, neck+head); look (deg, + = looks right); tremble (u0, u1,
# cycles, deg) on the tail. steps: (foot, u0, u1, yaw, out, fwd, lift, kind): lands at u1 on its idle spot turned yaw
# about the pivot, set out (m, to its own side) and forward (m); kind "stomp" rises fast, holds, slams down.
# stamps: (foot, u0, u1, height) a paw in place.
SPIN_R = dict(
    n=96, lag=0.025, turn_deg=-220.0, turn=(0.28, 0.86), pivot="front_foot_R", gait=dict(hind=9, front=4),
    tail=[(0, 0), (0.20, 26), (0.28, 30), (0.42, -28), (0.74, -42), (0.88, -10), (1.0, 0)],
    lift=[(0, 0), (0.20, 16), (0.28, 18), (0.45, 8), (0.86, 6), (1.0, 0)],
    crouch=[(0, 0), (0.22, 0.26), (0.86, 0.30), (1.0, 0)],
    roll=[(0, 0), (0.28, 3), (0.5, 6), (0.86, 5), (1.0, 0)],
    head=[(0, 0), (0.22, -8), (0.86, -10), (1.0, 0)],
    look=[(0, 0), (0.22, 25), (0.86, 25), (1.0, 0)],
    tremble=(0.06, 0.27, 4.0, 4.0))
PIVOT_R = dict(
    n=38, lag=0.03, turn_deg=-90.0, turn=(0.10, 0.90), pivot="front_foot_R", gait=dict(hind=4, front=2),
    tail=[(0, 0), (0.3, -14), (0.8, -12), (1.0, 0)],
    lift=[(0, 0), (0.3, 6), (1.0, 0)],
    crouch=[(0, 0), (0.12, 0.2), (0.88, 0.2), (1.0, 0)],
    roll=[(0, 0), (0.4, 3), (1.0, 0)],
    head=[(0, 0), (0.3, -4), (1.0, 0)],
    look=[(0, 0), (0.15, 20), (0.85, 15), (1.0, 0)])
HSTOMP_R = dict(
    n=34, lag=0.04,
    tail=[(0, 0), (0.3, 14), (0.55, 30), (0.75, 20), (1.0, 0)],
    lift=[(0, 0), (0.3, 8), (0.55, 4), (1.0, 0)],
    crouch=[(0, 0), (0.15, 0.05), (0.5, 0.02), (0.56, 0.16), (0.7, 0.1), (1.0, 0)],
    roll=[(0, 0), (0.3, -6), (0.5, -7), (0.56, 4), (0.75, 2), (1.0, 0)],
    shift=[(0, 0), (0.3, -0.22), (0.5, -0.24), (0.56, 0.08), (1.0, 0)],
    head=[(0, 0), (0.3, 6), (0.56, -8), (1.0, 0)],
    look=[(0, 0), (0.25, 40), (0.7, 35), (1.0, 0)],
    steps=[("hind_foot_R", 0.12, 0.56, 0, 0.55, -0.2, 0.95, "stomp"), ("hind_foot_R", 0.74, 0.94, 0, 0, 0, 0.12)])
# SHOULDER SLAM (STEGOSPIN port, owner 2026-10-31 on the ankylosaurus' shove: "use its momentum and drop its shoulder ...
# throw its body weight at the player. Like a proper slam. and then steady itself after"; the stego's shove only swung
# its head over her): weight cocked off (0-0.26) while the near forefoot and hind foot step in, then the whole body lurches
# over and forward into that side with the shoulder dropped (impact 0.40), held; it rocks back, re-plants (0.64-0.86) and
# steadies (a stamp of the far forefoot).
SHOVE_R = dict(
    n=40, lag=0.04,
    yaw=[(0, 0), (0.26, 6), (0.40, -8), (0.54, -7), (0.70, 2), (0.84, -1), (1.0, 0)],
    tail=[(0, 0), (0.26, -12), (0.45, 14), (0.70, 6), (1.0, 0)],
    lift=[(0, 0), (0.3, 4), (1.0, 0)],
    crouch=[(0, 0), (0.26, 0.12), (0.40, 0.30), (0.52, 0.32), (0.68, 0.06), (0.80, 0.12), (1.0, 0)],
    roll=[(0, 0), (0.26, -6), (0.40, 13), (0.52, 14), (0.68, -3), (0.82, 1), (1.0, 0)],
    shift=[(0, 0), (0.26, -0.25), (0.40, 0.62), (0.52, 0.64), (0.68, 0.0), (0.82, 0.05), (1.0, 0)],
    back=[(0, 0), (0.26, 0.15), (0.40, -0.35), (0.52, -0.35), (0.68, 0.05), (1.0, 0)],
    head=[(0, 0), (0.26, 6), (0.40, -14), (0.55, -10), (0.75, 4), (1.0, 0)],
    look=[(0, 0), (0.2, 35), (0.4, 30), (0.6, 20), (1.0, 0)],
    steps=[("front_foot_R", 0.12, 0.30, -4, 0.55, 0.25, 0.3), ("hind_foot_R", 0.20, 0.36, 0, 0.3, 0.15, 0.25),
           ("front_foot_R", 0.64, 0.80, 0, 0, 0, 0.2), ("hind_foot_R", 0.70, 0.86, 0, 0, 0, 0.2)],
    stamps=[("front_foot_L", 0.86, 0.95, 0.12)])
CLIPS = {
    "spin_right": SPIN_R,
    "pivot_right": PIVOT_R,
    "hind_stomp_right": HSTOMP_R,
    "shove_right": SHOVE_R,
    "stomp": dict(
        n=36, lag=0.04,
        tail=[(0, 0), (0.2, -6), (0.55, -6), (0.7, 4), (1.0, 0)],
        lift=[(0, 0), (0.2, 6), (0.5, 8), (0.58, -2), (1.0, 0)],
        crouch=[(0, 0), (0.12, 0.08), (0.3, 0.36), (0.5, 0.38), (0.56, 0.34), (0.68, 0.22), (1.0, 0)],  # the rear-up lifts the shoulders: the crouch keeps the planted forefoot reached
        roll=[(0, 0), (0.2, 5), (0.5, 6), (0.58, -2), (0.75, 0), (1.0, 0)],
        pitch=[(0, 0), (0.12, 0), (0.3, 5), (0.5, 6), (0.56, -2), (0.68, -1), (1.0, 0)],
        back=[(0, 0), (0.5, 0.0), (0.56, -0.05), (1.0, 0)],
        head=[(0, 0), (0.3, 14), (0.5, 16), (0.56, -14), (0.72, -10), (1.0, 0)],
        steps=[("front_foot_L", 0.12, 0.56, 0, 0.05, 0.45, 0.9, "stomp"), ("front_foot_L", 0.76, 0.94, 0, 0, 0, 0.15)]),
    "rear_slam": dict(
        n=53, lag=0.04,
        tail=Z0,
        lift=[(0, 0), (0.15, 6), (0.45, 22), (0.55, 22), (0.62, 2), (1.0, 0)],
        crouch=[(0, 0), (0.1, 0.12), (0.2, 0.0), (0.58, 0.0), (0.63, 0.26), (0.75, 0.18), (1.0, 0)],
        pitch=[(0, 0), (0.1, -2), (0.42, 24), (0.55, 25), (0.62, -3), (0.72, -2), (1.0, 0)],
        back=[(0, 0), (0.42, 0.25), (0.55, 0.25), (0.62, -0.1), (0.75, -0.06), (1.0, 0)],
        head=[(0, 0), (0.42, 22), (0.55, 24), (0.62, -16), (0.78, -10), (1.0, 0)],
        tremble=(0.44, 0.56, 3.0, 3.0),
        steps=[("front_foot_L", 0.12, 0.62, 0, 0.05, 0.4, 1.35, "stomp"), ("front_foot_R", 0.14, 0.62, 0, 0.05, 0.4, 1.35, "stomp"),
               ("front_foot_L", 0.78, 0.92, 0, 0, 0, 0.15), ("front_foot_R", 0.84, 0.98, 0, 0, 0, 0.15)]),
    "tackle": dict(
        n=22, lag=0.04,
        tail=Z0,
        lift=[(0, 0), (0.5, 10), (1.0, 6)],
        crouch=[(0, 0), (0.5, 0.2), (0.85, 0.22), (1.0, 0.1)],
        pitch=[(0, 0), (0.5, -3), (0.85, -4), (1.0, -1)],
        back=[(0, 0), (0.5, 0.16), (0.85, 0.18), (1.0, -0.06)],
        head=[(0, 0), (0.4, -18), (1.0, -22)],
        tremble=(0.45, 0.85, 3.0, 2.0),
        stamps=[("front_foot_R", 0.18, 0.4, 0.25)]),
    # TACKLE LUNGE (owner 2026-10-31: "tackle should be legs moving fast, then a jump/lunge that goes kind of far"): after
    # the run-up (the run gait, ClubTailBrain) a short gather, then airborne 0.14-0.52 (the brain carries the body
    # forward on an arc in exactly that window: anim_events tackle_lunge.airborne) with the head down and the forefeet
    # reaching; the forefeet land at 0.52, the hind at 0.56, it absorbs, steps the forefeet back in and steadies.
    "tackle_lunge": dict(
        n=30, lag=0.04,
        tail=Z0,
        lift=[(0, 4), (0.3, 10), (0.6, -2), (0.8, 2), (1.0, 0)],
        crouch=[(0, 0.1), (0.12, 0.22), (0.18, -0.04), (0.50, 0.0), (0.62, 0.30), (0.76, 0.14), (1.0, 0)],
        pitch=[(0, -3), (0.12, -5), (0.2, 8), (0.4, 2), (0.54, -6), (0.66, -4), (0.85, -1), (1.0, 0)],
        back=[(0, 0.08), (0.12, 0.14), (0.2, -0.1), (0.54, -0.08), (0.66, 0.05), (1.0, 0)],
        head=[(0, -18), (0.2, -22), (0.5, -24), (0.62, -14), (0.85, -4), (1.0, 0)],
        steps=[("front_foot_L", 0.10, 0.52, 0, 0, 0.3, 0.5), ("front_foot_R", 0.11, 0.52, 0, 0, 0.3, 0.5),
               ("hind_foot_L", 0.12, 0.56, 0, 0, 0, 0.45), ("hind_foot_R", 0.13, 0.56, 0, 0, 0, 0.45),
               ("front_foot_L", 0.68, 0.80, 0, 0, 0, 0.15), ("front_foot_R", 0.74, 0.86, 0, 0, 0, 0.15)]),
}
SIDEWAYS = ("turn_deg", "yaw", "tail", "roll", "shift", "look")


def mirror(c):
    m = dict(c)
    for k in ("yaw", "tail", "roll", "shift", "look"):
        if k in m:
            m[k] = [(u, -v) for u, v in m[k]]
    if "turn_deg" in m:
        m["turn_deg"] = -m["turn_deg"]
    if "pivot" in m:
        m["pivot"] = m["pivot"].replace("_R", "_L")
    if "tremble" in m:
        m["tremble"] = m["tremble"]
    swap = lambda f: f.replace("_R", "_X").replace("_L", "_R").replace("_X", "_L")
    m["steps"] = [(swap(s[0]),) + tuple(-x if i == 2 else x for i, x in enumerate(s[1:])) for s in c.get("steps", [])]
    m["stamps"] = [(swap(s[0]),) + tuple(s[1:]) for s in c.get("stamps", [])]
    return m


for r, l in (("spin_right", "spin_left"), ("pivot_right", "pivot_left"), ("hind_stomp_right", "hind_stomp_left"), ("shove_right", "shove_left")):
    CLIPS[l] = mirror(CLIPS[r])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
skin = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
for o in [o for o in bpy.data.objects if o not in (arm, skin)]:
    bpy.data.objects.remove(o, do_unlink=True)
pbs = arm.pose.bones
for pb in pbs:
    pb.rotation_mode = "QUATERNION"
upd = bpy.context.view_layer.update
# The idle pose (its first frame) is the base every clip starts and ends on.
acts = set(bpy.data.actions)
objs = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=IDLE)
idle = max(set(bpy.data.actions) - acts, key=lambda a: a.frame_range[1])
for o in set(bpy.data.objects) - objs:
    bpy.data.objects.remove(o, do_unlink=True)
arm.animation_data_create()
arm.animation_data.action = idle
try:
    arm.animation_data.action_slot = idle.slots[0]
except Exception:
    pass
bpy.context.scene.frame_set(int(idle.frame_range[0]))
upd()
BASE_POSE = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in pbs}
arm.animation_data.action = None


def reset():
    for pb in pbs:
        pb.location, pb.rotation_quaternion, pb.scale = BASE_POSE[pb.name]
    upd()


reset()
BASE_FOOT = {f: pbs[f].matrix.copy() for f in FEET}
BALL = {f: pbs[TOE[f]].head.copy() for f in FEET}
HIND_LINE = (pbs["hind_foot_L"].head + pbs["hind_foot_R"].head) / 2
gi = {g.index: g.name for g in skin.vertex_groups}
TAIL_V = [v.index for v in skin.data.vertices if v.groups and gi[max(v.groups, key=lambda g: g.weight).group] in TAILS]


def rot_about(p, deg):
    return Matrix.Translation(Vector((p.x, p.y, 0))) @ Matrix.Rotation(math.radians(deg), 4, Z) @ Matrix.Translation(Vector((-p.x, -p.y, 0)))


def about(pb, axis, deg, piv=None):
    m = pb.matrix.copy()
    p = m.translation.copy() if piv is None else piv
    pb.matrix = Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p) @ m
    upd()


def solve_leg(up, low, foot, target):
    """Thigh and shin reach the foot's planted head (knee kept on its side), then the foot takes its planted matrix."""
    h = pbs[up].head.copy(); knee0 = pbs[low].head.copy(); ankle = target.translation.copy()
    l1 = pbs[up].bone.length
    l2 = pbs[low].bone.length
    d_vec = ankle - h
    if d_vec.length > 0.985 * (l1 + l2) and ankle.z > BASE_FOOT[foot].translation.z + 0.05:
        # a lifted foot out of reach hangs from the leg (a rear-up carries it): it follows the leg, no gap
        ankle = h + d_vec.normalized() * 0.985 * (l1 + l2)
        target = target.copy(); target.translation = ankle
        d_vec = ankle - h
    d = min(d_vec.length, (l1 + l2) * 0.9999)
    u = d_vec.normalized()
    pole = (knee0 - h) - u * (knee0 - h).dot(u)
    if pole.length > 1e-6:
        w = pole.normalized()
        a = math.acos(max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
        knee = h + (u * math.cos(a) + w * math.sin(a)) * l1
        for bone, p0, p1 in ((up, h, knee), (low, knee, h + u * d)):
            m = pbs[bone].matrix.copy()
            q = m.to_3x3().col[1].normalized().rotation_difference((p1 - p0).normalized())
            nm = (q.to_matrix() @ m.to_3x3()).to_4x4(); nm.translation = p0
            pbs[bone].matrix = nm
            upd()
    pbs[foot].matrix = target
    upd()


def turn_at(c, u):
    if "turn_deg" not in c:
        return 0.0
    a, b = c["turn"]
    return c["turn_deg"] * smooth((u - a) / (b - a))


def turn_steps(c):
    """The stepping schedule of a turn clip: each non-pivot foot steps round the pivot, the last step landing on the end turn."""
    a, b = c["turn"]
    out = []
    plan = [(f, c["gait"]["front" if f.startswith("front") else "hind"]) for f in FEET if f != c["pivot"]]
    phases = {"hind_foot_L": 0.0, "hind_foot_R": 0.5, "front_foot_L": 0.25, "front_foot_R": 0.25}
    sw = 0.55
    for f, n in plan:
        ph = phases[f]
        p = (b - a) / (n - 1 + ph + sw + 0.15)
        for i in range(n):
            u0 = a + p * (i + ph + 0.15)
            u1 = u0 + sw * p
            last = i == n - 1
            mid = min(b, u1 + (1 - sw) * p * 0.5)
            yaw = c["turn_deg"] if last else turn_at(c, mid)
            out.append((f, u0, u1, yaw, 0.0, 0.0, 0.3 if f.startswith("hind") else 0.22))
    return out


def plant(c, foot, yaw, out, fwd):
    m = rot_about(c["_piv"], yaw) @ BASE_FOOT[foot]
    m.translation.x += out * (-1 if foot.endswith("L") else 1)
    m.translation.y += fwd
    return m


def stomp_arc(t):
    if t < 0.35:
        return smooth(t / 0.35)
    if t < 0.8:
        return 1.0
    return 1.0 - ((t - 0.8) / 0.2) ** 2


def foot_at(c, foot, u):
    """World-frame matrix of the foot at u: planted on its latest landed step, or on the arc of the step in progress."""
    if foot == c.get("pivot"):
        return rot_about(c["_piv"], turn_at(c, u)) @ BASE_FOOT[foot]  # it twists about its own ball
    cur = (0.0, 0.0, 0.0)
    m, lift = None, 0.0
    for st in sorted((s for s in c["_steps"] if s[0] == foot), key=lambda s: s[1]):
        f, u0, u1, yaw, out = st[:5]
        fwd = st[5] if len(st) > 5 else 0.0
        if u >= u1:
            cur = (yaw, out, fwd)
            continue
        if u > u0:
            t = (u - u0) / (u1 - u0)
            h = st[6] if len(st) > 6 else 0.2
            if len(st) > 7 and st[7] == "stomp":
                m = plant(c, foot, *cur).lerp(plant(c, foot, yaw, out, fwd), smooth(min(1.0, t / 0.35)))
                lift = h * stomp_arc(t)
            else:
                m = plant(c, foot, *cur).lerp(plant(c, foot, yaw, out, fwd), smooth(t))
                lift = h * math.sin(math.pi * t)
        break
    if m is None:
        m = plant(c, foot, *cur)
    for f, u0, u1, h in c.get("stamps", []):
        if f == foot and u0 < u < u1:
            lift = h * math.sin(math.pi * (u - u0) / (u1 - u0))
    m = m.copy()
    m.translation.z += lift
    return m


def low_z(idx=None):
    ev = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    vs = me.vertices if idx is None else [me.vertices[i] for i in idx]
    z = min((skin.matrix_world @ v.co).z for v in vs)
    ev.to_mesh_clear()
    return z


def pose(c, u):
    reset()
    T = turn_at(c, u)
    C = rot_about(c["_piv"], -T)  # the code turns the body by T: the clip keys the world motion counter-rotated
    targets = {f: C @ foot_at(c, f, u) for f in FEET}
    yaw = keys(u, c.get("yaw"))
    hips = pbs["hips"]
    R = rot_about(c["_piv"], yaw)
    hips.matrix = Matrix.Translation((keys(u, c.get("shift")), -keys(u, c.get("back")), -keys(u, c.get("crouch")))) @ R @ hips.matrix
    upd()
    pitch = keys(u, c.get("pitch"))
    if pitch:  # + = front up, about the hind ankles' line
        about(hips, X, pitch, HIND_LINE.copy())
    fwd = Matrix.Rotation(math.radians(yaw), 3, Z) @ Y
    about(hips, fwd, keys(u, c.get("roll")), hips.matrix.translation.copy())
    look = keys(u, c.get("look"))
    about(pbs["spine_03"], Z, -0.3 * look)
    about(pbs["neck_01"], Z, -0.4 * look)
    about(pbs["neck_02"], Z, -0.3 * look)
    side = Matrix.Rotation(math.radians(yaw - 0.6 * look), 3, Z) @ X
    hp = keys(u, c.get("head"))
    about(pbs["neck_01"], side, 0.5 * hp)
    about(pbs["head"], side, 0.5 * hp)
    tside = Matrix.Rotation(math.radians(yaw), 3, Z) @ X
    # the tail keeps its line through a rear-up (it would otherwise drive the spikes into the ground)
    tl = -keys(u, c.get("lift")) - 0.6 * pitch
    for t, k in (("tail_01", 0.25), ("tail_02", 0.4), ("tail_03", 0.35)):  # spread down the chain: the root skin tears on one joint
        about(pbs[t], tside, tl * k)
    tr = c.get("tremble")
    for i, t in enumerate(TAILS):
        ang = keys(max(0.0, u - c["lag"] * i), c.get("tail")) * (0.2 + 0.03 * i)  # seven bones: about twice the value at the club
        if tr and tr[0] < u < tr[1]:
            s = (u - tr[0]) / (tr[1] - tr[0])
            ang += tr[3] * math.sin(2 * math.pi * tr[2] * s) * math.sin(math.pi * s) * (0.4 + 0.15 * i)
        about(pbs[t], Z, ang)
    for _ in range(12):
        if low_z(TAIL_V) >= 0.02:
            break
        about(pbs["tail_01"], tside, -1.5)
    for up, low, foot in LEGS:
        solve_leg(up, low, foot, targets[foot])
    for _ in range(4):  # a crouch must not push belly or knee skin through the ground: lift the hips, feet stay
        lz = low_z()
        if lz >= -0.005:
            break
        m = hips.matrix.copy(); m.translation.z -= lz; hips.matrix = m
        upd()
        for up, low, foot in LEGS:
            solve_leg(up, low, foot, targets[foot])


os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
for name in WANT:
    c = dict(CLIPS[name])
    c["_piv"] = BALL[c["pivot"]] if "pivot" in c else (BALL["front_foot_L"] + BALL["front_foot_R"]) / 2
    c["_steps"] = list(c.get("steps", [])) + (turn_steps(c) if "turn_deg" in c else [])
    if "pivot" in c:
        p = c["_piv"]
        print(f"PIVOT {name} blender=({p.x:.3f},{p.y:.3f}) gltf_xz=({p.x:.3f},{-p.y:.3f}) turn_deg={c['turn_deg']} turn={c['turn']}")
    n = c["n"]
    frames = []
    for f in range(n):
        pose(c, f / (n - 1))
        frames.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in pbs})
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f, rows in enumerate(frames):
        for pb in pbs:
            pb.location, pb.rotation_quaternion = rows[pb.name]
            pb.keyframe_insert("location", frame=f + 1)
            pb.keyframe_insert("rotation_quaternion", frame=f + 1)
    sc.frame_start, sc.frame_end = 1, n
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    out = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", export_apply=False, export_yup=True,
        use_selection=True, export_animations=True, export_animation_mode="ACTIVE_ACTIONS",
        export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
        export_anim_slide_to_zero=False, export_skins=True, export_morph=False,
        export_def_bones=False, export_reset_pose_bones=False, export_current_frame=False,
        export_nla_strips=False, export_anim_single_armature=True, export_bake_animation=True,
        export_materials="NONE", export_image_format="NONE")
    print("WROTE", out, n, "frames")
    arm.animation_data.action = None
    reset()
