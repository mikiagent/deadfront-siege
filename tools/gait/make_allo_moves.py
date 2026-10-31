"""Author the allosaurus' one-shots, idle, feed and sleep on its rig_biped.py skeleton (Hips/Spine1/Chest/Neck1/Neck2/
Head/Jaw, Thigh/Shin/Metatarsal/Toe, Tail1-6, Arm/Forearm/Hand), in place. A copy of make_pachy_moves.py's poser (feet
IK-planted on their prints, lying clips resting on the floor) with the allosaurus' own fight moves.

Owner 2026-10-31 ("yes allosaurus"; brief: the hatchet bite, a grab with the hands then a bite, a shoulder ram).
# ASSUMPTION: the moves (PRD verb "hatchet bite, arterial strike"; no PRD clip list):
  attack_primary  snap bite, 0.9 s, hit 0.42: head draws back with the jaws opening, a step in with the right foot and
                  the head darts forward and down to survivor height, jaws shut at the hit, a short tearing tug.
  attack_heavy    HATCHET bite, 1.6 s, hit 0.72 (windup held to 0.6, the telegraph): rears back with the head high and
                  the jaws gaping wide, holds, then chops the open upper jaw down like an axe with a step in, and
                  drags back tearing (the brain applies Bleed on this hit only).
  grab_bite       2.2 s, hits 0.3 (grab), 0.55 and 0.8 (bites): lunges low with a step, the three-fingered hands
                  reach forward and clamp the prey (the brain pins it), then two downward bites at the hands.
  kick            SHOULDER RAM (the brain's point-blank body move), 1.1 s, hit 0.45: a crouch and wind to the left,
                  then the right shoulder drives forward and out with a step, the head turned away.
  alert           roar: head up, then thrust forward level with the jaws wide and a head shake.
Hit fractions match game/data/creatures/anim_events.json (attack_primary 0.42, attack_heavy 0.72, kick 0.45,
grab_bite [0.3, 0.55, 0.8]). The Jaw opens with +X (add_jaw.py --x-side), so jaw angles are applied as +deg.

usage: Blender -b -P tools/gait/make_allo_moves.py -- <base.glb> <clip> <out.glb>
  clip: idle | alert | attack_primary | attack_heavy | grab_bite | kick | hit_react | knockdown | death | sleep | feed
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
ARMS_IN = {"Arm.L": (0, 0, 0), "Arm.R": (0, 0, 0)}


def arms(pitch, fore=0.0, hand=0.0, spread=0.0):
    """Both arms: shoulder pitch (+ = forward/up), forearm and hand pitch, yaw outward."""
    return {"Arm.L": (pitch, spread, 0), "Arm.R": (pitch, -spread, 0), "Forearm.L": (fore, 0, 0), "Forearm.R": (fore, 0, 0),
            "Hand.L": (hand, 0, 0), "Hand.R": (hand, 0, 0)}


def idle(u):
    """2.5 s loop: two slow breaths, weight shifting foot to foot, a look left and right, the tail swaying, jaws ajar."""
    br = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * u)
    sway = wave(u, 1)
    look = wave(u, 1, 0.15)
    return {
        "body": {"dz": -0.01 * br, "dx": 0.015 * sway, "roll": 1.0 * sway, "pitch": 0.6 * br},
        "turns": merge({
            "Chest": (1.2 * br, 0, 0),
            "Neck1": (-1.5 * br, 5.0 * look, 0), "Neck2": (-1.0 * br, 4.0 * look, 0), "Head": (2.0 * br, 4.0 * look, 3.0 * look),
        }, arms(4 * br), tail_wave(u, 4.0, 1.0, delay=0.05, cycles=1, phase=0.1)),
        "jaw": 2.0 + 6.0 * smooth((br - 0.6) / 0.4),
        "feet": PLANT,
    }


def alert(u):
    """Roar, 1.6 s: the head comes up and back, then thrusts forward level with the jaws wide, shaking; tail up."""
    up = track(u, [(0, 0), (0.25, 1), (0.38, 1), (0.5, 0), (1, 0)])
    out = track(u, [(0, 0), (0.3, 0), (0.48, 1), (0.85, 1), (1, 0)])
    shake = wave(u, 7) * track(u, [(0, 0), (0.48, 0), (0.55, 1), (0.82, 1), (0.92, 0), (1, 0)])
    jaw = track(u, [(0, 2), (0.25, 12), (0.4, 8), (0.5, 42), (0.85, 40), (0.97, 3), (1, 2)])
    return {
        "body": {"pitch": 8 * up - 6 * out, "dz": 0.02 * up - 0.04 * out, "dy": -0.03 * up + 0.06 * out},
        "turns": merge({
            "Chest": (4 * up - 3 * out, 0, 0), "Neck1": (14 * up - 6 * out, 0, 0), "Neck2": (8 * up + 6 * out, 0, 0),
            "Head": (10 * up + 4 * out, 5 * shake, 7 * shake),
        }, arms(-10 * out, 15 * out), tail_set(-1.5 * out + 1.0 * up), tail_wave(u, 4.0, 0.0, cycles=2, env=out)),
        "jaw": jaw,
        "feet": PLANT,
    }


def attack_primary(u):
    """Snap bite, 0.9 s, hit at 0.42: the head draws back with the jaws opening, the right foot steps in and the head
    darts forward and down; the jaws shut at the hit, then a short tearing tug back."""
    H = 0.42
    dy = track(u, [(0, 0), (0.22, -0.06), (H, 0.30), (0.6, 0.26), (0.85, 0.05), (1, 0)])
    dz = track(u, [(0, 0), (0.22, 0.02), (H, -0.10), (0.6, -0.08), (0.9, 0), (1, 0)])
    pitch = track(u, [(0, 0), (0.22, 6), (H, -12), (0.6, -9), (0.9, -1), (1, 0)])
    neck = track(u, [(0, 0), (0.22, 12), (H, -16), (0.55, -10), (0.7, -14), (1, 0)])
    head = track(u, [(0, 0), (0.22, 8), (H, -10), (0.6, -6), (1, 0)])
    tug = track(u, [(0, 0), (H, 0), (0.52, 1), (0.66, 0), (1, 0)])
    rf = track(u, [(0, 0), (0.15, 0), (0.36, 0.38), (0.75, 0.38), (0.95, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.15, 0), (0.26, 0.16), (0.36, 0), (0.75, 0), (0.85, 0.14), (0.95, 0), (1, 0)]))
    return {
        "body": {"dy": dy - 0.05 * tug, "dz": dz, "pitch": pitch},
        "turns": merge({
            "Chest": (-0.3 * pitch, 0, 0), "Neck1": (neck, 0, 0), "Neck2": (neck * 0.5, 0, 0), "Head": (head, 4 * tug, -6 * tug),
        }, arms(10 * smooth(rf / 0.38)), tail_set(-pitch * 0.25)),
        "jaw": track(u, [(0, 2), (0.3, 38), (0.38, 40), (H, 1), (0.6, 2), (0.75, 8), (1, 2)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def attack_heavy(u):
    """HATCHET bite, 1.6 s, hit at 0.72: rears back on its hips with the head high and the jaws gaping wide (held to 0.6:
    the telegraph), then chops the open upper jaw down like an axe with a step in, and drags back tearing."""
    H = 0.72
    rear = track(u, [(0, 0), (0.3, 1), (0.58, 1), (H, 0), (1, 0)])
    chop = track(u, [(0, 0), (0.58, 0), (H, 1), (0.8, 1), (0.92, 0.2), (1, 0)])
    drag = track(u, [(0, 0), (H, 0), (0.86, 1), (1, 0)])
    tremble = wave(u, 9) * track(u, [(0, 0), (0.3, 1), (0.56, 1), (0.6, 0), (1, 0)])
    rf = track(u, [(0, 0), (0.58, 0), (0.7, 0.42), (0.88, 0.42), (0.99, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.58, 0), (0.64, 0.2), (0.7, 0), (0.88, 0), (0.94, 0.14), (0.99, 0), (1, 0)]))
    return {
        "body": {"pitch": 12 * rear - 20 * chop, "dz": 0.03 * rear - 0.12 * chop, "dy": -0.08 * rear + 0.34 * chop - 0.12 * drag},
        "turns": merge({
            "Chest": (5 * rear - 6 * chop, 0, 0),
            "Neck1": (12 * rear - 22 * chop + 6 * drag, 0, 0), "Neck2": (4 * rear - 12 * chop, 0, 0),
            "Head": (-6 * rear - 18 * chop + 1.5 * tremble, 0, 2 * tremble),
        }, arms(15 * rear - 10 * chop, 20 * rear), tail_set(-1.5 * rear + 4.5 * chop)),
        "jaw": track(u, [(0, 2), (0.3, 46), (0.58, 48), (H, 40), (0.8, 30), (0.9, 4), (1, 2)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def grab_bite(u):
    """Grab and bite, 2.2 s, hits at 0.3 (the hands clamp), 0.55 and 0.8 (bites): lunges low with a step while the
    three-fingered hands reach forward and clamp; the head drives down to the hands twice, jaws snapping shut."""
    low = track(u, [(0, 0), (0.28, 1), (0.88, 1), (1, 0)])
    reach = track(u, [(0, 0), (0.22, 1), (0.3, 0.8), (0.88, 0.8), (1, 0)])
    b1 = track(u, [(0, 0), (0.42, 0), (0.55, 1), (0.64, 0.3), (1, 0.3)])
    b2 = track(u, [(0, 0), (0.67, 0), (0.8, 1), (0.9, 0), (1, 0)])
    bite = max(b1 * (1 if u < 0.67 else track(u, [(0.67, 1), (0.72, 0), (1, 0)])), b2)
    tug = track(u, [(0, 0), (0.55, 0), (0.6, 1), (0.66, 0), (0.8, 0), (0.85, 1), (0.91, 0), (1, 0)])
    rf = track(u, [(0, 0), (0.08, 0), (0.24, 0.4), (0.88, 0.4), (0.98, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.08, 0), (0.16, 0.16), (0.24, 0), (0.88, 0), (0.93, 0.14), (0.98, 0), (1, 0)]))
    jaw = track(u, [(0, 2), (0.2, 14), (0.3, 18), (0.48, 40), (0.55, 2), (0.66, 10), (0.74, 40), (0.8, 2), (0.9, 6), (1, 2)])
    return {
        "body": {"pitch": -16 * low - 6 * bite, "dz": -0.14 * low, "dy": 0.3 * low - 0.04 * tug},
        "turns": merge({
            "Chest": (-6 * low, 0, 0),
            "Neck1": (14 * low * (1 - bite) - 30 * bite, 0, 0), "Neck2": (6 * low - 16 * bite, 0, 0),
            "Head": (8 * low - 20 * bite, 0, 5 * tug),
        }, arms(50 * reach, -20 * reach, -15 * reach, 6 * reach), tail_set(3.5 * low)),
        "jaw": jaw,
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def kick(u):
    """Shoulder ram, 1.1 s, hit at 0.45: a crouch with the body wound to the left, then the right shoulder drives
    forward and out with a step of the right foot, the head turned away from the blow; back to stance."""
    H = 0.45
    wind = track(u, [(0, 0), (0.28, 1), (0.34, 1), (H, 0), (1, 0)])
    ram = track(u, [(0, 0), (0.3, 0), (H, 1), (0.62, 0.9), (0.9, 0), (1, 0)])
    rf = track(u, [(0, 0), (0.25, 0), (0.42, 0.36), (0.75, 0.36), (0.95, 0), (1, 0)])
    rs = track(u, [(0, 0), (0.25, 0), (0.42, 0.12), (0.75, 0.12), (0.95, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.25, 0), (0.33, 0.15), (0.42, 0), (0.75, 0), (0.85, 0.12), (0.95, 0), (1, 0)]))
    return {
        "body": {"yaw": 12 * wind - 22 * ram, "roll": -4 * wind + 10 * ram, "dz": -0.07 * wind - 0.08 * ram,
                 "dy": -0.04 * wind + 0.14 * ram, "dx": 0.1 * ram, "pitch": -6 * ram},
        "turns": merge({
            "Chest": (0, -8 * ram, 6 * ram),
            "Neck1": (6 * ram, 14 * ram - 6 * wind, 0), "Neck2": (4 * ram, 10 * ram, 0), "Head": (6 * ram, 6 * ram, -6 * ram),
        }, arms(10 * wind - 10 * ram, 10 * wind), tail_set(1.5 * ram, 5 * ram - 3 * wind)),
        "jaw": track(u, [(0, 2), (0.3, 6), (H, 20), (0.7, 6), (1, 2)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, rs, 0)},
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
LIMP = {"L": (8, -18, 14, 8), "R": (12, -24, 18, 10)}  # fallen: legs stretched out stiff from the belly (folded they stuck up like a bundle)


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
    """2.0 s loop: head down at a carcass, the jaws tearing with a pull back and up, then gulping."""
    d = 0.5 - 0.5 * math.cos(2 * math.pi * u)
    d = 0.75 + 0.25 * (1 - d)
    tug = max(0.0, wave(u, 2))
    return {
        "body": {"pitch": -16 * d, "dz": -0.08 * d, "dy": 0.04 * d - 0.03 * tug},
        "turns": merge({"Chest": (-8 * d, 0, 0), "Neck1": (-30 * d + 8 * tug, 3 * wave(u, 1), 0), "Neck2": (-18 * d, 0, 0),
                        "Head": (-14 * d + 10 * tug, 0, 6 * tug)}, tail_set(4 * d), tail_wave(u, 2.0, 0.0)),
        "jaw": 4 + 22 * max(0.0, wave(u, 2, 0.15)),
        "feet": PLANT,
    }


CLIPS = {"idle": (idle, 60, True), "alert": (alert, 38, False), "attack_primary": (attack_primary, 22, False),
         "attack_heavy": (attack_heavy, 38, False), "grab_bite": (grab_bite, 53, False), "kick": (kick, 26, False),
         "hit_react": (hit_react, 14, False), "knockdown": (knockdown, 50, False), "death": (death, 43, False),
         "sleep": (sleep, 48, False), "feed": (feed, 48, True)}
if CLIP == "pose":  # debugging: one static pose from $POSE (the apply() dict as JSON), 2 frames
    import json, os
    CLIPS["pose"] = (lambda u: json.loads(os.environ["POSE"]), 2, False)
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
print(f"ALLOMOVE {CLIP} {N} frames ({N / FPS:.3f} s)")

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
