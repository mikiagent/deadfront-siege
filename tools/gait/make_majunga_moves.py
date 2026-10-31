"""Author the majungasaurus' one-shots, idle, feed and sleep on its rig_biped.py skeleton (Hips/Spine1/Chest/
Neck1/Neck2/Head/Jaw, Thigh/Shin/Metatarsal/Toe, Tail1-N, Arm/Forearm/Hand), in place. Forked from make_pachy_moves.py
(same rig layout). Standing clips keep the feet IK-planted on their prints (no gliding); lying clips (knockdown,
death, sleep) fold the legs and rest the body on the floor with a skin floor pass every frame.

Owner 2026-10-31 (approved sheet, named Majungasaurus): "be creative with what moves you think they should do".
# ASSUMPTION: the moves (the PRDs are silent on Majungasaurus):
  attack_primary  crushing bite, 0.9 s, hit 0.42: coil back with the jaws wide, dart forward and down to a survivor's
                  height, clamp shut and wrench back. A landed bite becomes the grab (pin_stab) in TacticalBrain.
  pin_stab        grab and shake, 2.4 s, hits 0.38 and 0.74 (anim_events pin_stab): the jaws stay clamped on the prey
                  held low in front, two violent side-to-side shakes, then it lets go.
  attack_heavy    skull-knob headbutt, 1.4 s, hit 0.72: rears back, chin tucked so the knob faces the prey, a hind
                  foot paws the ground (the telegraph), then a stepping drive, knob first, at chest height.
  kick            low tail swipe, 1.0 s, hit 0.45: the brain plays "kick" when the prey is behind it; the hips pivot and
                  the tail sweeps round low to the right and back, the feet pivot on their prints.
  alert           roar: head up, then thrust forward with the jaws wide and shaking.
  charge          (make_gait.py, majungasaurus.json) the run with the body level and the jaws pushed out ahead.
Hit fractions match game/data/creatures/anim_events.json (attack_primary 0.42, attack_heavy 0.72, kick 0.45,
pin_stab 0.38 / 0.74). The Jaw was added with add_jaw --x-side, so a positive angle opens it.

usage: Blender -b -P tools/gait/make_majunga_moves.py -- <base.glb> <clip> <out.glb>
  clip: idle | alert | attack_primary | attack_heavy | kick | pin_stab | hit_react | knockdown | death | sleep | feed
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, CLIP, OUT = argv[:3]
FPS = 24
FWD, UP = Vector((0, -1, 0)), Vector((0, 0, 1))
SIDE = FWD.cross(UP).normalized()  # (-1, 0, 0): the animal's right

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
body = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
pbs, bones = arm.pose.bones, arm.data.bones
TAILS = sorted([b.name for b in bones if b.name.startswith("Tail") and b.name[4:].isdigit()], key=lambda n: int(n[4:]))
U = bones["Thigh.L"].head_local.z  # hip height: every distance below is in hip heights

# carriage: neck S-curve, head level (degrees, + = nose up)
CARRY = {}


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def track(u, keys):
    """keys: [(u, value), ...] sorted; smoothstep between neighbours, held outside."""
    if u <= keys[0][0]:
        return keys[0][1]
    for (u0, v0), (u1, v1) in zip(keys, keys[1:]):
        if u <= u1:
            return v0 + (v1 - v0) * smooth((u - u0) / max(u1 - u0, 1e-6))
    return keys[-1][1]


def wave(u, cycles, phase=0.0):
    return math.sin(2 * math.pi * (cycles * u + phase))


def rot_about(p, axis, ang):
    return Matrix.Translation(p) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-p)


def set_m(name, m):
    pbs[name].matrix = m
    bpy.context.view_layer.update()


def turn(name, axis, deg):
    if deg and name in pbs:
        cur = pbs[name].matrix.copy()
        set_m(name, rot_about(cur.translation, axis, math.radians(deg)) @ cur)


LEGS = {}
for sd in "LR":
    up, low, foot = "Thigh." + sd, "Shin." + sd, "Metatarsal." + sd
    h, k, an = bones[up].head_local, bones[low].head_local, bones[foot].head_local
    line = an - h
    off = (k - h) - line * ((k - h).dot(line) / line.length_squared)
    LEGS[sd] = {"up": up, "low": low, "foot": foot, "l1": bones[up].length, "l2": (k - an).length,
                "pole": off.normalized(), "ankle0": an.copy(), "ball0": bones[foot].tail_local.copy()}
PIVOT = (bones["Thigh.L"].head_local + bones["Thigh.R"].head_local) / 2


def solve_leg(leg, ankle):
    up, low = leg["up"], leg["low"]
    h = pbs[up].head.copy()
    l1, l2 = leg["l1"], leg["l2"]
    d_vec = ankle - h
    d = min(d_vec.length, (l1 + l2) * 0.9999)
    u = d_vec.normalized()
    w = leg["pole"] - u * leg["pole"].dot(u)
    w.normalize()
    a = math.acos(max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    knee = h + (u * math.cos(a) + w * math.sin(a)) * l1
    for bone, p0, p1 in ((up, h, knee), (low, knee, h + u * d)):
        m = pbs[bone].matrix.copy()
        q = m.to_3x3().col[1].normalized().rotation_difference((p1 - p0).normalized())
        nm = (q.to_matrix() @ m.to_3x3()).to_4x4()
        nm.translation = p0
        set_m(bone, nm)
    return h + u * d


def lowest():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    co = co.reshape(-1, 3)
    mw = np.array(body.matrix_world)
    z = co @ mw[2, :3] + mw[2, 3]
    return float(z.min())


def apply(p):
    """p: body {dx, dy, dz, pitch, roll, yaw}, turns {bone: (pitch, yaw, roll)}, jaw,
    feet {L/R: (lift, fwd, side, heel)} planted by IK, or None for a free leg posed by legs {L/R: (thigh, shin, meta, toe)}."""
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    b = p.get("body", {})
    m = Matrix.Translation((SIDE * b.get("dx", 0.0) + FWD * b.get("dy", 0.0) + UP * b.get("dz", 0.0)) * U) \
        @ rot_about(PIVOT, UP, math.radians(b.get("yaw", 0.0))) \
        @ rot_about(PIVOT, SIDE, math.radians(b.get("pitch", 0.0))) @ rot_about(PIVOT, FWD, math.radians(b.get("roll", 0.0))) \
        @ bones["Hips"].matrix_local
    set_m("Hips", m)
    turns = p.get("turns", {})
    order = ["Spine1", "Chest", "Neck1", "Neck2", "Head"] + TAILS + ["Arm.L", "Arm.R", "Forearm.L", "Forearm.R", "Hand.L", "Hand.R"]
    for name in order:
        tp, ty, tr = turns.get(name, (0.0, 0.0, 0.0))
        tp += CARRY.get(name, 0.0)
        turn(name, UP, ty)
        turn(name, SIDE, tp)
        turn(name, FWD, tr)
    jb = pbs["Jaw"]
    cur = jb.matrix.copy()
    set_m("Jaw", rot_about(cur.translation, cur.to_3x3().col[0].normalized(), math.radians(p.get("jaw", 0.0))) @ cur)
    feet = p.get("feet", {})
    for sd, leg in LEGS.items():
        f = feet.get(sd, (0.0, 0.0, 0.0, 0.0))
        if f is None:
            th, sh, mt, to = p.get("legs", {}).get(sd, (0, 0, 0, 0))
            for bn, ang in (("Thigh", th), ("Shin", sh), ("Metatarsal", mt), ("Toe", to)):
                n = "%s.%s" % (bn, sd)
                # the hinge rides with the body (after a roll onto the side a world-axis pitch would fold the legs skyward)
                sgn = 1.0 if bones[n].matrix_local.col[0].xyz.dot(SIDE) >= 0 else -1.0
                turn(n, pbs[n].matrix.col[0].xyz.normalized() * sgn, ang)
            continue
        lift, fwd, side, heel = f
        ball = leg["ball0"] + (FWD * fwd + SIDE * side) * U
        r = rot_about(ball, -SIDE, math.radians(heel))  # + = heel up / toe down, pivoting on the ball of the foot
        ankle = r @ (leg["ankle0"] + (FWD * fwd + SIDE * side) * U) + UP * lift * U
        got = solve_leg(leg, ankle)
        yaw = p.get("foot_yaw", {}).get(sd, 0.0)
        fm = rot_about(Vector((0, 0, 0)), UP, math.radians(yaw)) @ Matrix.Rotation(math.radians(heel), 4, -SIDE) @ bones[leg["foot"]].matrix_local
        fm.translation = got
        set_m(leg["foot"], fm)
        tm = (rot_about(Vector((0, 0, 0)), UP, math.radians(yaw)) @ bones["Toe." + sd].matrix_local).copy()
        tm.translation = pbs[leg["foot"]].tail
        set_m("Toe." + sd, tm)
        if lift > 0.08:
            turn("Toe." + sd, SIDE, -min(25.0, lift * 60))  # toes hang while the foot is up
    if p.get("rest_on_floor"):  # lying clips: the lowest skin point is the floor
        low = lowest()
        set_m("Hips", Matrix.Translation(UP * -low) @ pbs["Hips"].matrix)


def tail_wave(u, amp_yaw, amp_pitch, delay=0.06, cycles=1.0, phase=0.0, env=1.0):
    out = {}
    for i, t in enumerate(TAILS):
        k = 0.6 + 0.08 * i
        out[t] = (amp_pitch * k * wave(u, cycles, phase - delay * i) * env, amp_yaw * k * wave(u, cycles, phase - delay * i) * env, 0.0)
    return out


def merge(*dicts):
    out = {}
    for d in dicts:
        for k, v in d.items():
            a = out.get(k, (0.0, 0.0, 0.0))
            out[k] = (a[0] + v[0], a[1] + v[1], a[2] + v[2])
    return out


def tail_set(pitch=0.0, yaw=0.0, falloff=0.85):
    return {t: (pitch * falloff ** i, yaw * falloff ** i, 0.0) for i, t in enumerate(TAILS)}


PLANT = {"L": (0, 0, 0, 0), "R": (0, 0, 0, 0)}

# ---------------------------------------------------------------------------------------------------- clips


def idle(u):
    """2.5 s loop: two breaths, weight rolling foot to foot, a look left and right, the stiff tail swaying."""
    br = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * u)
    sway = wave(u, 1)
    look = wave(u, 1, 0.15)
    return {
        "body": {"dz": -0.012 * br, "dx": 0.02 * sway, "roll": 1.2 * sway, "pitch": 0.8 * br},
        "turns": merge({
            "Chest": (1.5 * br, 0, 0),
            "Neck1": (-1.5 * br, 6.0 * look, 0), "Neck2": (-1.0 * br, 5.0 * look, 0), "Head": (2.0 * br, 4.0 * look, 3.0 * look),
            "Arm.L": (5 * br, 0, 0), "Arm.R": (5 * br, 0, 0),
        }, tail_wave(u, 3.0, 1.0, delay=0.05, cycles=1, phase=0.1)),
        "jaw": 1.0 + 4.0 * smooth((br - 0.6) / 0.4),
        "feet": PLANT,
    }


def alert(u):
    """Roar, 1.5 s: the head rears up and back with the chest, then thrusts forward and down with the jaws wide,
    shaking with the bellow, a stamp of the right foot; settles."""
    rear = track(u, [(0, 0), (0.22, 1), (0.34, 0), (1, 0)])
    thrust = track(u, [(0, 0), (0.22, 0), (0.36, 1), (0.82, 1), (1, 0)])
    trem = wave(u, 11) * track(u, [(0, 0), (0.36, 0), (0.42, 1), (0.8, 1), (0.9, 0), (1, 0)])
    sweep = track(u, [(0, 0), (0.4, 0), (0.58, 1), (0.76, -1), (0.9, 0), (1, 0)])
    stamp = max(0.0, track(u, [(0, 0), (0.3, 0), (0.4, 0.3), (0.5, 0), (1, 0)]))
    return {
        "body": {"pitch": 10 * rear - 6 * thrust, "dy": -0.05 * rear + 0.06 * thrust, "dz": 0.02 * rear - 0.04 * thrust},
        "turns": merge({
            "Chest": (4 * rear - 3 * thrust, 0, 0), "Neck1": (18 * rear - 10 * thrust + 2 * trem, 8 * sweep, 0),
            "Neck2": (8 * rear - 6 * thrust, 6 * sweep, 0), "Head": (6 * rear + 8 * thrust, 4 * sweep, 3 * trem),
            "Arm.L": (-20 * rear + 10 * thrust, 0, 0), "Arm.R": (-20 * rear + 10 * thrust, 0, 0),
        }, tail_set(-8 * rear + 6 * thrust), tail_wave(u, 5.0, 0.0, cycles=2, env=thrust)),
        "jaw": track(u, [(0, 1), (0.22, 10), (0.36, 34), (0.8, 32), (0.92, 4), (1, 1)]) + 2 * trem,
        "feet": {"L": (0, 0, 0, 0), "R": (stamp, 0.04 * smooth(stamp / 0.3), 0, 0)},
    }


def attack_primary(u):
    """Crushing bite, 0.9 s, hit at 0.42: rock back with the jaws gaping, then dart forward and down to a survivor's
    height and clamp shut on 0.42; a wrench back (the hold starts here when it lands), recover."""
    H = 0.42
    coil = track(u, [(0, 0), (0.28, 1), (H, 0), (1, 0)])
    strike = track(u, [(0, 0), (0.28, 0), (H, 1), (0.62, 0.85), (0.9, 0), (1, 0)])
    wrench = track(u, [(0, 0), (H, 0), (0.52, 1), (0.66, 0), (1, 0)])
    return {
        "body": {"dy": -0.06 * coil + 0.16 * strike - 0.04 * wrench, "dz": 0.02 * coil - 0.14 * strike,
                 "pitch": 6 * coil - 20 * strike + 3 * wrench},
        "turns": merge({
            "Chest": (2 * coil - 8 * strike, 0, 0), "Neck1": (14 * coil - 24 * strike + 6 * wrench, 0, 0),
            "Neck2": (6 * coil - 12 * strike, 0, 0), "Head": (10 * coil - 4 * strike, 4 * wrench, 6 * wrench),
            "Arm.L": (-10 * coil + 25 * strike, 0, 0), "Arm.R": (-10 * coil + 25 * strike, 0, 0),
        }, tail_set(-6 * coil + 6 * strike)),
        "jaw": track(u, [(0, 1), (0.26, 30), (0.36, 34), (H, 0), (0.7, 0), (0.85, 6), (1, 1)]),
        "feet": PLANT,
    }


def pin_stab(u):
    """Grab and shake, 2.4 s, hits at 0.38 and 0.74 (anim_events pin_stab, shared by every species): the jaws stay
    clamped on the prey held low in front of the chest, the head and neck wrench hard to one side and back (the
    shake peaks on each hit frame), then the jaws open and it lets go."""
    down = track(u, [(0, 0), (0.12, 1), (0.88, 1), (1, 0)])
    shake = 0.0
    for c in (0.38, 0.74):
        if c - 0.12 <= u <= c + 0.1:
            shake += math.sin(math.pi * 2 * (u - (c - 0.12)) / 0.22 * 1.5) * math.sin(math.pi * (u - (c - 0.12)) / 0.22)
    return {
        "body": {"dy": 0.06 * down, "dz": -0.13 * down, "pitch": -26 * down, "roll": 5 * shake, "yaw": 6 * shake},
        "turns": merge({
            "Chest": (-8 * down, 0, 0), "Neck1": (-32 * down, 18 * shake, 0), "Neck2": (-12 * down, 12 * shake, 0),
            "Head": (-6 * down, 8 * shake, 16 * shake),
            "Arm.L": (20 * down, 0, 0), "Arm.R": (20 * down, 0, 0),
        }, tail_set(22 * down), tail_wave(u, 10.0, 0.0, cycles=2.0, env=down)),
        "jaw": track(u, [(0, 1), (0.06, 18), (0.12, 0), (0.86, 0), (0.94, 22), (1, 1)]),
        "feet": PLANT,
    }


def attack_heavy(u):
    """Skull-knob headbutt, 1.4 s, hit at 0.72: rears back with the chin tucked so the skull knob faces the prey, the
    right hind foot paws the ground twice (the telegraph), then a stepping drive with the left foot, knob first at
    chest height, and the head snaps up through the hit; step back."""
    H = 0.72
    rear = track(u, [(0, 0), (0.22, 1), (0.56, 1), (H, 0), (1, 0)])
    drive = track(u, [(0, 0), (0.56, 0), (H, 1), (0.8, 0.9), (1, 0)])
    tuck = track(u, [(0, 0), (0.22, 1), (H, 1), (0.82, 0.3), (1, 0)])
    snap = track(u, [(0, 0), (H - 0.02, 0), (0.8, 1), (0.92, 0), (1, 0)])
    paw = 0.0
    for c in (0.28, 0.42):
        if c <= u <= c + 0.1:
            paw = math.sin(math.pi * (u - c) / 0.1)
    step = track(u, [(0, 0), (0.58, 0), (0.68, 1), (0.86, 1), (0.98, 0), (1, 0)])
    lift = math.sin(math.pi * min(1.0, max(0.0, (u - 0.58) / 0.1))) if u < 0.68 else \
        (math.sin(math.pi * min(1.0, max(0.0, (u - 0.86) / 0.12))) if u < 0.98 else 0.0)
    return {
        "body": {"dy": -0.08 * rear + 0.5 * drive, "dz": 0.03 * rear - 0.1 * drive, "pitch": 10 * rear - 8 * drive + 4 * snap},
        "turns": merge({
            "Chest": (2 * rear - 4 * drive, 0, 0), "Neck1": (10 * rear - 14 * tuck - 20 * drive + 12 * snap, 0, 0),
            "Neck2": (-8 * tuck, 0, 0), "Head": (-30 * tuck + 14 * snap, 0, 0),
            "Arm.L": (-15 * rear + 20 * drive, 0, 0), "Arm.R": (-15 * rear + 20 * drive, 0, 0),
        }, tail_set(-8 * rear + 12 * drive)),
        "jaw": track(u, [(0, 1), (0.15, 16), (0.3, 4), (H, 1), (0.82, 10), (1, 1)]),
        "feet": {"L": (0.14 * lift, 0.32 * step, 0, 0), "R": (0.06 * paw, -0.05 * paw, 0, 12 * paw)},
    }


def kick(u):
    """Low tail swipe, 1.0 s, hit at 0.45: a crouch with the tail cocked to one side, then the hips pivot and the stiff
    tail sweeps low right across its back (straight behind on the hit frame, so it catches prey anywhere in the rear
    arc), the feet pivoting on their prints; swing back."""
    H = 0.45
    yaw = track(u, [(0, 0), (0.25, 12), (0.32, 13), (H, 0), (0.58, -12), (0.85, -2), (1, 0)])
    roll = track(u, [(0, 0), (0.25, -4), (H, 2), (0.6, 6), (1, 0)])
    dz = track(u, [(0, 0), (0.25, -0.06), (H, -0.06), (0.7, -0.03), (1, 0)])
    low = track(u, [(0, 0), (0.28, 0.5), (H, 1), (0.65, 0.8), (0.92, 0), (1, 0)])
    look = track(u, [(0, 0), (0.3, -20), (H, 10), (0.6, 26), (1, 0)])
    tails = {}
    for i, t in enumerate(TAILS):
        lag = 0.02 * i
        tails[t] = (6 * low, track(u, [(0, 0), (0.28 + lag, 6), (H + lag, 0), (0.6 + lag, -6), (0.9, 0), (1, 0)]), 0)
    return {
        "body": {"yaw": yaw, "roll": roll, "dz": dz, "pitch": 6 * low},
        "turns": merge(tails, {"Chest": (-4 * low, -0.3 * yaw, 0), "Neck1": (-4 * low, look * 0.6, 0), "Neck2": (0, look * 0.4, 0), "Head": (0, look * 0.3, 0)}),
        "jaw": track(u, [(0, 1), (0.35, 10), (H, 14), (0.7, 2), (1, 1)]),
        "feet": PLANT,
    }


def hit_react(u):
    """0.6 s: the head and chest jerk back and up from the blow, a stagger step back with the left foot."""
    j = track(u, [(0, 0), (0.15, 1), (0.45, 0.7), (1, 0)])
    lf = track(u, [(0, 0), (0.1, 0), (0.36, -0.16), (0.62, -0.16), (0.9, 0), (1, 0)])
    ll = max(0.0, track(u, [(0, 0), (0.06, 0), (0.22, 0.14), (0.38, 0), (0.6, 0), (0.75, 0.12), (0.92, 0), (1, 0)]))
    return {
        "body": {"dy": -0.08 * j, "pitch": 9 * j, "roll": -3 * j, "dz": -0.02 * j},
        "turns": merge({"Neck1": (12 * j, 6 * j, 0), "Neck2": (8 * j, 0, 0), "Head": (14 * j, 0, -8 * j)}, tail_set(-6 * j)),
        "jaw": 14 * j,
        "feet": {"L": (ll, lf, 0, 0), "R": (0, 0, 0, 0)},
    }


FOLD = {"L": (38, -70, 62, 30), "R": (38, -70, 62, 30)}  # thigh, shin, metatarsal, toe: a bird sitting on its hocks
LIMP = {"L": (22, -40, 34, 20), "R": (30, -50, 40, 24)}  # fallen: legs half folded, the upper (left) one looser


def collapse(u, end_roll, legs_at, head_drop, hold_from):
    c = track(u, [(0, 0), (hold_from, 1), (1, 1)])
    buckle = track(u, [(0, 0), (hold_from * 0.5, 1), (1, 1)])
    legs = {sd: tuple(v * buckle for v in LIMP[sd]) for sd in "LR"}
    if c < 0.02:
        return {"feet": PLANT}
    return {
        "body": {"roll": end_roll * c, "pitch": -4 * c},
        "turns": merge({"Neck1": (-head_drop * 0.5 * c, -10 * c, 6 * c), "Neck2": (-head_drop * 0.3 * c, -8 * c, 0), "Head": (-head_drop * 0.2 * c, 0, 10 * c)},
                       tail_set(5 * c, -8 * c)),
        "feet": {"L": None, "R": None},
        "legs": legs,
        "rest_on_floor": True,
    }


def knockdown(u):
    """2.1 s: the knees buckle, it topples onto its right side and lies there, legs folded (the capture hold)."""
    p = collapse(u, 82, 1, 20, 0.45)
    p["jaw"] = track(u, [(0, 1), (0.3, 16), (0.5, 6), (1, 4)])
    return p


def death(u):
    """1.8 s: a last stagger, then a heavy fall onto the right side, the neck and tail going slack."""
    p = collapse(u, 88, 1, 34, 0.5)
    p["jaw"] = track(u, [(0, 1), (0.3, 20), (0.6, 10), (1, 8)])
    return p


def sleep(u):
    """2.0 s, held on the last frame: settles belly-down onto folded legs, chin to the ground, tail curled round."""
    c = track(u, [(0, 0), (0.75, 1), (1, 1)])
    buckle = track(u, [(0, 0), (0.6, 1), (1, 1)])
    return {
        "body": {"pitch": -3 * c},
        "turns": merge({"Neck1": (-30 * c, 12 * c, 0), "Neck2": (-14 * c, 10 * c, 0), "Head": (10 * c, 8 * c, 4 * c),
                        "Arm.L": (-25 * c, 0, 0), "Arm.R": (-25 * c, 0, 0)}, tail_set(6 * c, 9 * c, 0.95)),
        "jaw": 0.5,
        "feet": {"L": None, "R": None},
        "legs": {sd: tuple(v * buckle for v in FOLD[sd]) for sd in "LR"},
        "rest_on_floor": True,
    }


def feed(u):
    """2.0 s loop: head down to the ground, two cropping bites with a tug, chewing."""
    d = 0.5 - 0.5 * math.cos(2 * math.pi * u)
    d = 0.75 + 0.25 * (1 - d)  # stays mostly down
    tug = max(0.0, wave(u, 2))
    return {
        "body": {"pitch": -14 * d, "dz": -0.05 * d, "dy": 0.02 * d},
        "turns": merge({"Chest": (-6 * d, 0, 0), "Neck1": (-26 * d + 4 * tug, 3 * wave(u, 1), 0), "Neck2": (-14 * d, 0, 0), "Head": (-10 * d + 6 * tug, 0, 0)},
                       tail_set(10 * d), tail_wave(u, 2.0, 0.0)),
        "jaw": 2 + 10 * max(0.0, wave(u, 4)),
        "feet": PLANT,
    }


CLIPS = {"idle": (idle, 60, True), "alert": (alert, 36, False), "attack_primary": (attack_primary, 22, False),
         "attack_heavy": (attack_heavy, 34, False), "kick": (kick, 24, False), "pin_stab": (pin_stab, 58, False), "hit_react": (hit_react, 14, False),
         "knockdown": (knockdown, 50, False), "death": (death, 43, False), "sleep": (sleep, 48, False), "feed": (feed, 48, True)}
fn, N, loop = CLIPS[CLIP]

arm.animation_data_create()
act = bpy.data.actions.new(CLIP)
arm.animation_data.action = act
for f in range(N + 1):
    apply(fn(f / N))
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert("location", frame=f)
        pb.keyframe_insert("rotation_quaternion", frame=f)
        pb.keyframe_insert("scale", frame=f)
sc = bpy.context.scene
sc.render.fps = FPS
sc.frame_start, sc.frame_end = 0, N
print(f"MAJUNGAMOVE {CLIP} {N} frames ({N / FPS:.3f} s)")

for o in list(bpy.data.objects):
    if o is not arm:
        bpy.data.objects.remove(o, do_unlink=True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
act.name = CLIP
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", export_apply=False, export_yup=True,
    use_selection=True, export_animations=True, export_animation_mode="ACTIONS",
    export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
    export_anim_slide_to_zero=False, export_skins=True, export_morph=False,
    export_def_bones=False, export_reset_pose_bones=False, export_current_frame=False,
    export_nla_strips=False, export_anim_single_armature=True, export_bake_animation=True,
    export_materials="NONE", export_image_format="NONE")
print("WROTE", OUT)
