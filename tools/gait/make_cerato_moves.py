"""Author the ceratosaurus' one-shots, idle, feed and sleep on its rig_biped.py skeleton (the pachycephalosaurus'
make_pachy_moves.py machinery: feet IK-planted on their prints in standing clips, lying clips folded onto the floor).

Owner 2026-10-31 (species brief): "Be creative with what moves you think they should do when they fight"; suggested
moves: nose-horn gore (head-down jab), blade-tooth slashing bite that applies Bleed, tail swipe, a crocodile-like
lunge from the water's edge. # ASSUMPTION: the clip shapes and timings below.
  attack_primary  slashing bite, 1.0 s, hit 0.42: head cocked up and to one side, jaws wide, then a sideways raking
                  bite across the prey, jaws shutting at the hit, and a backward rip of the blade teeth.
  attack_heavy    nose-horn gore, 1.5 s, hit 0.72: crouch with the head dropped so the nose horn points at the prey,
                  a snort and a horn wag held as the telegraph (anim_events windup), then a driving step and an upward
                  jab-and-hook of the horn.
  kick            tail swipe, 1.0 s, hit 0.45 (the brain's "kick" slot: played when the prey is behind it): the hips
                  pivot on planted feet and the tail whips across behind it, the head looking back over the shoulder.
  pounce          water-edge lunge, 1.2 s, airborne 0.2-0.65, hit 0.7: a low crouch, a flat surge with the jaws wide
                  (the brain carries the body on a low arc), the snap on landing and a twisting tug.
  alert           roar: rears back, jaws wide, the head shaking side to side to show off the horns.
Hit fractions match game/data/creatures/anim_events.json (attack_primary 0.42, attack_heavy 0.72, kick 0.45, pounce 0.7).

usage: Blender -b -P tools/gait/make_cerato_moves.py -- <base.glb> <clip> <out.glb>
  clip: idle | alert | attack_primary | attack_heavy | kick | pounce | hit_react | knockdown | death | sleep | feed
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

# tail_set pitch: + droops the tail (tip down), - raises it
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
    # this jaw (add_jaw.py without --open, level mouth line) opens about +X; the pachy's (--open) about -X
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

# THERO-ROAR (owner 2026-10-31, fight lab: "I thought the model's head was too big when his head is facing north but if it
# stands up higher and uses his arms more it could be fine"): the idle and the alert (its combat stance, the hold pose)
# stand taller: the body tipped nose-up on the hips and lifted on straighter legs, the neck carried higher with the
# snout kept level, the arms held forward and flexed instead of hanging. # ASSUMPTION: the angles.
STANCE_BODY = {"pitch": 13.0, "dz": 0.05, "dy": -0.03}
STANCE_TURNS = {"Chest": (6, 0, 0), "Neck1": (16, 0, 0), "Neck2": (-3, 0, 0), "Head": (-27, 0, 0),
                "Arm.L": (38, 0, 10), "Arm.R": (38, 0, -10), "Forearm.L": (40, 0, 0), "Forearm.R": (40, 0, 0),
                "Hand.L": (22, 0, 0), "Hand.R": (22, 0, 0)}


def stance(p):
    """The taller stance under a clip's own motion (idle, alert)."""
    b = dict(p.get("body", {}))
    for k, v in STANCE_BODY.items():
        b[k] = b.get(k, 0.0) + v
    p["body"] = b
    p["turns"] = merge(p.get("turns", {}), STANCE_TURNS)
    return p

# ---------------------------------------------------------------------------------------------------- clips


def idle(u):
    """2.5 s loop: two breaths, weight rolling foot to foot, a look left and right, the tail swaying, a jaw twitch."""
    br = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * u)
    sway = wave(u, 1)
    look = wave(u, 1, 0.15)
    flex = wave(u, 2, 0.3)  # the hands flex and open with the breathing
    return stance({
        "body": {"dz": -0.012 * br, "dx": 0.015 * sway, "roll": 1.0 * sway, "pitch": 0.8 * br},
        "turns": merge({
            "Chest": (1.5 * br, 0, 0),
            "Neck1": (-1.5 * br, 7.0 * look, 0), "Neck2": (-1.0 * br, 6.0 * look, 0), "Head": (2.0 * br, 5.0 * look, 3.0 * look),
            "Arm.L": (5 * br, 0, 0), "Arm.R": (5 * br, 0, 0),
            "Forearm.L": (6 * flex, 0, 0), "Forearm.R": (-6 * flex, 0, 0), "Hand.L": (10 * flex, 0, 0), "Hand.R": (-10 * flex, 0, 0),
        }, tail_wave(u, 5.0, 1.5, delay=0.06, cycles=1, phase=0.1)),
        "jaw": 1.0 + 5.0 * smooth((br - 0.6) / 0.4),
        "feet": PLANT,
    })


def alert(u):
    """Roar, 1.7 s: rears back with the head up, then thrusts it forward with the jaws wide, shaking the head side to
    side so the nose and brow horns flash, the tail raised and lashing."""
    up = track(u, [(0, 0), (0.2, 1), (0.35, 0.3), (0.85, 0.3), (1, 0)])
    roar = track(u, [(0, 0), (0.25, 0), (0.38, 1), (0.82, 1), (1, 0)])
    shake = roar * wave(u, 4.5)
    return stance({
        "body": {"dz": 0.03 * up - 0.03 * roar, "pitch": 10 * up - 4 * roar, "dy": -0.05 * up + 0.06 * roar},
        "turns": merge({
            "Chest": (3 * up, 0, 0), "Neck1": (16 * up - 6 * roar, 8 * shake, 0), "Neck2": (8 * up, 6 * shake, 0),
            "Head": (6 * up + 6 * roar, 10 * shake, 10 * shake),
            "Arm.L": (20 * roar, 0, 0), "Arm.R": (20 * roar, 0, 0),
        }, tail_set(-4 * roar - 8 * up), tail_wave(u, 7.0, 0.0, cycles=3, env=roar)),
        "jaw": track(u, [(0, 1), (0.2, 8), (0.38, 30), (0.8, 28), (0.95, 3), (1, 1)]),
        "feet": PLANT,
    })


def attack_primary(u):
    """Slashing bite, 1.0 s, hit at 0.42: the head cocks up and to the left with the jaws gaping, then rakes down and
    across to the right as the body lunges off a planted step, the jaws shutting at the hit; the blade teeth rip back
    and up, and it steps back."""
    H = 0.42
    dy = track(u, [(0, 0), (0.25, -0.08), (H, 0.30), (0.58, 0.24), (0.85, 0.05), (1, 0)])
    dz = track(u, [(0, 0), (0.25, 0.02), (H, -0.06), (0.6, -0.04), (0.9, 0), (1, 0)])
    pitch = track(u, [(0, 0), (0.25, 6), (H, -12), (0.6, -5), (0.9, 0), (1, 0)])
    yaw = track(u, [(0, 0), (0.25, 22), (H, -14), (0.6, -24), (0.85, -4), (1, 0)])
    lift = track(u, [(0, 0), (0.25, 12), (H, -16), (0.58, 8), (0.85, 0), (1, 0)])
    roll = track(u, [(0, 0), (0.25, -14), (H, 10), (0.6, 18), (0.9, 0), (1, 0)])
    rf = track(u, [(0, 0), (0.2, 0), (0.36, 0.32), (0.72, 0.32), (0.92, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.2, 0), (0.28, 0.14), (0.36, 0), (0.72, 0), (0.82, 0.12), (0.92, 0), (1, 0)]))
    return {
        "body": {"dy": dy, "dz": dz, "pitch": pitch, "yaw": 0.15 * yaw},
        "turns": merge({
            "Chest": (0, 0.15 * yaw, 0), "Neck1": (lift, 0.45 * yaw, 0), "Neck2": (0.5 * lift, 0.3 * yaw, 0),
            "Head": (0.4 * lift, 0.2 * yaw, roll),
            "Arm.L": (-15 * smooth(rf / 0.32), 0, 0), "Arm.R": (-15 * smooth(rf / 0.32), 0, 0),
        }, tail_set(-pitch * 0.5, -0.4 * yaw)),
        "jaw": track(u, [(0, 1), (0.28, 30), (0.36, 32), (H, 0), (0.62, 2), (0.8, 8), (1, 1)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def attack_heavy(u):
    """Nose-horn gore, 1.5 s, hit at 0.72: crouches with the head dropped so the nose horn points at the prey, snorts
    and wags the horn (the held telegraph), then drives forward off a big step and jabs the horn up and through,
    hooking the head high; recover."""
    H = 0.72
    low = track(u, [(0, 0), (0.28, 1), (0.6, 1), (H, 0.6), (0.85, 0), (1, 0)])
    drive = track(u, [(0, 0), (0.6, 0), (H, 1), (0.82, 0.9), (1, 0)])
    hook = track(u, [(0, 0), (0.64, 0), (H, 0.3), (0.82, 1), (0.95, 0.1), (1, 0)])
    wag = track(u, [(0, 0), (0.32, 0), (0.38, 1), (0.56, 1), (0.6, 0), (1, 0)]) * wave(u, 6)
    snort = track(u, [(0, 0), (0.42, 0), (0.45, 1), (0.52, 0), (1, 0)])
    rf = track(u, [(0, 0), (0.6, 0), (0.7, 0.34), (0.86, 0.34), (0.97, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.6, 0), (0.65, 0.16), (0.7, 0), (0.86, 0), (0.92, 0.12), (0.97, 0), (1, 0)]))
    return {
        "body": {"dy": -0.06 * low + 0.36 * drive, "dz": -0.10 * low - 0.03 * drive + 0.006 * snort,
                 "pitch": -9 * low - 3 * drive + 6 * hook},
        "turns": merge({
            "Chest": (-3 * low, 0, 0), "Neck1": (-20 * low + 10 * hook, 6 * wag, 0), "Neck2": (-10 * low + 6 * hook, 4 * wag, 0),
            "Head": (-22 * low + 26 * hook + 6 * drive - 4 * snort, 4 * wag, 8 * wag),
            "Arm.L": (10 * low - 20 * drive, 0, 0), "Arm.R": (10 * low - 20 * drive, 0, 0),
        }, tail_set(-2 * low - 4 * hook), tail_wave(u, 4.0, 0.0, cycles=2, env=low)),
        "jaw": track(u, [(0, 1), (0.3, 2), (0.44, 2), (0.47, 10), (0.55, 2), (H, 4), (0.82, 26), (0.95, 3), (1, 1)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def kick(u):
    """Tail swipe, 1.0 s, hit at 0.45: the head swings round to look back at the prey behind it while the hips coil the
    tail out to the right, then the hips pivot hard on the planted feet and the long tail whips across behind it,
    passing straight behind at the hit, and follows through to the left; it swings back."""
    H = 0.45
    yaw = track(u, [(0, 0), (0.25, 14), (0.32, 15), (H, -4), (0.6, -20), (0.85, -3), (1, 0)])
    roll = track(u, [(0, 0), (0.25, -4), (H, 6), (0.6, 8), (1, 0)])
    dz = track(u, [(0, 0), (0.25, -0.05), (H, -0.03), (0.7, -0.02), (1, 0)])
    look = track(u, [(0, 0), (0.3, -24), (H, 26), (0.6, 30), (1, 0)])
    tails = {}
    for i, t in enumerate(TAILS):
        lag = 0.02 * i
        k = 1.0 + 0.12 * i
        tails[t] = (track(u, [(0, 0), (0.3, 3), (H, 6), (0.7, 2), (1, 0)]),  # droops: the whip passes at survivor height
                    k * track(u, [(0, 0), (0.28 + lag, 6), (H - 0.04 + lag, 0), (0.62 + lag, -8), (0.9, 0), (1, 0)]), 0)
    return {
        "body": {"yaw": yaw, "roll": roll, "dz": dz},
        "turns": merge(tails, {"Chest": (0, -0.3 * yaw, 0), "Neck1": (0, look * 0.6, 0), "Neck2": (0, look * 0.4, 0), "Head": (0, look * 0.3, 0)}),
        "jaw": track(u, [(0, 1), (0.35, 10), (H, 16), (0.7, 2), (1, 1)]),
        "feet": PLANT,
    }


def pounce(u):
    """Water-edge lunge, 1.2 s, airborne 0.2-0.65, hit at 0.7: sinks into a low crouch with the head flat and forward,
    surges out flat and low with the jaws wide and the legs trailing (the brain carries the body), snaps shut as it
    lands and tugs the head to the side."""
    crouch = track(u, [(0, 0), (0.16, 1), (0.24, 0.4), (0.62, 0.2), (0.72, 0.7), (0.85, 0.3), (1, 0)])
    air = track(u, [(0, 0), (0.18, 0), (0.28, 1), (0.58, 1), (0.66, 0), (1, 0)])
    tug = track(u, [(0, 0), (0.7, 0), (0.78, 1), (0.9, 0.4), (1, 0)])
    lf = track(u, [(0, 0), (0.2, 0), (0.32, -0.25), (0.55, -0.2), (0.66, 0), (1, 0)])
    lift = max(0.0, track(u, [(0, 0), (0.2, 0), (0.32, 0.22), (0.55, 0.22), (0.66, 0), (1, 0)]))
    return {
        "body": {"dz": -0.12 * crouch + 0.04 * air, "pitch": -6 * crouch - 4 * air, "dy": -0.04 * crouch},
        "turns": merge({
            "Chest": (-2 * crouch, 0, 0), "Neck1": (-12 * crouch - 6 * air + 4 * tug, 0, 0), "Neck2": (-4 * crouch, 0, 0),
            "Head": (8 * crouch + 6 * air - 6 * tug, 14 * tug, 18 * tug),
            "Arm.L": (-30 * air, 0, 0), "Arm.R": (-30 * air, 0, 0),
        }, tail_set(5 * air + 4 * crouch, 6 * tug), tail_wave(u, 5.0, 0.0, cycles=1.5, env=air)),
        "jaw": track(u, [(0, 1), (0.16, 12), (0.3, 30), (0.62, 32), (0.7, 0), (0.85, 3), (1, 1)]),
        "feet": {"L": (lift, lf, 0, 0), "R": (lift * 0.9, lf * 0.9, 0, 0)},
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
    """2.0 s loop: head down to a carcass, two tearing bites with a backward tug, gulping."""
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


CLIPS = {"idle": (idle, 60, True), "alert": (alert, 40, False), "attack_primary": (attack_primary, 24, False),
         "attack_heavy": (attack_heavy, 36, False), "kick": (kick, 24, False), "pounce": (pounce, 29, False),
         "hit_react": (hit_react, 14, False), "knockdown": (knockdown, 50, False), "death": (death, 43, False),
         "sleep": (sleep, 48, False), "feed": (feed, 48, True)}
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
print(f"CERATOMOVE {CLIP} {N} frames ({N / FPS:.3f} s)")

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
