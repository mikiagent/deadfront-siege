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
  clip: idle | alert | attack_primary | attack_heavy | grab_bite | kick | hit_react | knockdown | death | sleep | feed |
        claw_rake | slash_bite | check_left | check_right (ALLOFEEL)
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


Z = [(0, 0)]


def arm_keys(u, **tr):
    """ALLOFEEL (owner 2026-10-31: "the arms should be moving as part of the attack animation"): both arms keyed as
    tracks (clip fractions, smoothstep between keys, degrees), raptor_overlay.py's arm language on this rig:
      up    + = the arm swings forward and up at the shoulder
      out   + = the elbow swings out from the body
      elbow + = the forearm folds up, - = it straightens to reach
      wrist + = the hand flips forward, the three claws presented and spread; - = they curl down and back (the rake,
              the clench). The rig has no finger bones: the claws spread and clench through the wrist.
    A _L / _R suffix overrides one side."""
    out = {}
    for sd, sg in (("L", 1.0), ("R", -1.0)):
        g = lambda k: track(u, tr.get(k + "_" + sd, tr.get(k, Z)))
        out["Arm." + sd] = (g("up"), sg * g("out"), 0.0)
        out["Forearm." + sd] = (g("elbow"), 0.0, 0.0)
        out["Hand." + sd] = (g("wrist"), 0.0, 0.0)
    return out


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
        }, arm_keys(u,  # ALLOFEEL: cocked back with the claws curled, thrust out with the head, claws spread, raked down on the bite
                    up=[(0, 0), (0.22, -18), (0.36, 58), (H, 64), (0.56, 18), (0.78, 4), (1, 0)],
                    up_L=[(0, 0), (0.25, -18), (0.39, 54), (0.46, 60), (0.6, 16), (0.8, 4), (1, 0)],
                    out=[(0, 0), (0.22, 10), (H, 6), (1, 0)],
                    elbow=[(0, 0), (0.22, 30), (0.36, -46), (H, -42), (0.56, 24), (0.78, 8), (1, 0)],
                    wrist=[(0, 0), (0.22, -26), (0.36, 42), (H, 30), (0.52, -44), (0.78, -10), (1, 0)]),
            tail_set(-pitch * 0.25)),
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
        }, arm_keys(u,  # ALLOFEEL: raised and spread wide with the claws open through the held gape (the telegraph), slammed
                    # down and forward with the chop, the claws hooking in on the hit, then dragged back to the chest, tearing
                    up=[(0, 0), (0.3, 40), (0.58, 44), (0.68, 70), (H, 58), (0.8, 30), (0.88, -6), (1, 0)],
                    out=[(0, 0), (0.3, 26), (0.58, 28), (H, 8), (0.88, 4), (1, 0)],
                    elbow=[(0, 0), (0.3, -10), (0.58, -14), (0.68, -44), (H, -30), (0.8, 20), (0.88, 34), (1, 0)],
                    wrist=[(0, 0), (0.3, 44), (0.58, 48), (0.68, 30), (H, -30), (0.8, -46), (0.88, -30), (1, 0)]),
            {"Hand.L": (5 * tremble, 0, 0), "Hand.R": (-5 * tremble, 0, 0)}, tail_set(-1.5 * rear + 4.5 * chop)),
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
        }, arm_keys(u,  # ALLOFEEL: reach out wide with the claws spread, clamp shut on the prey at 0.3, haul her to the jaws on each
                    # bite (elbows fold), fling open on the release
                    up=[(0, 0), (0.12, 20), (0.24, 66), (0.3, 64), (0.42, 56), (0.55, 44), (0.64, 54), (0.8, 44), (0.86, 52), (0.9, 30), (1, 0)],
                    out=[(0, 0), (0.18, 30), (0.26, 22), (0.3, -4), (0.88, -4), (0.93, 24), (1, 0)],
                    elbow=[(0, 0), (0.2, -46), (0.26, -42), (0.3, -30), (0.55, -6), (0.64, -20), (0.8, -6), (0.88, -14), (0.93, -24), (1, 0)],
                    wrist=[(0, 0), (0.2, 48), (0.26, 50), (0.3, -36), (0.88, -30), (0.93, 40), (1, 0)]),
            tail_set(3.5 * low)),
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
        }, arm_keys(u,  # ALLOFEEL: both tucked and clenched in the wind; the right arm drives out with the shoulder, claws spread,
                    # and rakes down through her after the hit; the left swings back for balance
                    up=[(0, 0), (0.3, -18), (1, 0)],
                    up_R=[(0, 0), (0.3, -22), (H, 58), (0.6, 36), (0.85, 0), (1, 0)],
                    up_L=[(0, 0), (0.3, -22), (H, -40), (0.6, -16), (1, 0)],
                    out_R=[(0, 0), (0.3, -4), (H, 36), (0.6, 26), (1, 0)],
                    out_L=[(0, 0), (0.3, 0), (H, 18), (0.7, 6), (1, 0)],
                    elbow=[(0, 0), (0.3, 30), (1, 0)],
                    elbow_R=[(0, 0), (0.3, 30), (H, -34), (0.6, 10), (1, 0)],
                    elbow_L=[(0, 0), (0.3, 30), (H, 40), (1, 0)],
                    wrist=[(0, 0), (0.3, -30), (1, 0)],
                    wrist_R=[(0, 0), (0.3, -30), (0.42, 40), (0.52, -44), (0.66, -20), (1, 0)]),
            tail_set(1.5 * ram, 5 * ram - 3 * wind)),
        "jaw": track(u, [(0, 2), (0.3, 6), (H, 20), (0.7, 6), (1, 2)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, rs, 0)},
    }


def claw_rake(u):
    """ALLOFEEL arm rake, 1.1 s, hit at 0.5 (windup held 0.18-0.36: the telegraph): rears a little with the head drawn
    back and up out of the way, jaws open hissing, both arms raised high with the claws spread; then it pitches forward
    with a step of the right foot and both arms rake down and back through the prey under its chest, the left a beat
    ahead of the right, the claws curling shut. Hits from the claw tips (hitboxes.json Hand + offset rows)."""
    H = 0.5
    rear = track(u, [(0, 0), (0.18, 1), (0.36, 1), (H, 0), (1, 0)])
    lunge = track(u, [(0, 0), (0.36, 0), (H, 1), (0.66, 0.8), (0.9, 0), (1, 0)])
    tremble = wave(u, 8) * track(u, [(0, 0), (0.18, 1), (0.34, 1), (0.38, 0), (1, 0)])
    rf = track(u, [(0, 0), (0.34, 0), (0.46, 0.3), (0.8, 0.3), (0.97, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.34, 0), (0.4, 0.14), (0.46, 0), (0.8, 0), (0.88, 0.12), (0.97, 0), (1, 0)]))
    return {
        "body": {"pitch": 7 * rear - 20 * lunge, "dz": 0.02 * rear - 0.12 * lunge, "dy": -0.05 * rear + 0.2 * lunge},
        "turns": merge({
            "Chest": (4 * rear - 8 * lunge, 0, 0),
            "Neck1": (10 * rear + 12 * lunge, 0, 0), "Neck2": (4 * rear + 6 * lunge, 0, 0), "Head": (2 * rear - 6 * lunge, 0, 1.5 * tremble),
        }, arm_keys(u,
                    up=[(0, 0), (0.18, 74), (0.36, 78), (0.44, 58), (H, 22), (0.62, 4), (0.8, 2), (1, 0)],
                    up_L=[(0, 0), (0.18, 74), (0.34, 78), (0.42, 54), (0.47, 20), (0.6, 2), (0.8, 2), (1, 0)],
                    out=[(0, 0), (0.18, 22), (0.36, 24), (H, 10), (0.7, 6), (1, 0)],
                    elbow=[(0, 0), (0.18, -30), (0.36, -34), (0.44, -46), (H, -40), (0.62, 20), (0.8, 10), (1, 0)],
                    wrist=[(0, 0), (0.18, 46), (0.36, 50), (0.44, 24), (H, -10), (0.6, -52), (0.8, -16), (1, 0)]),
            {"Hand.L": (4 * tremble, 0, 0), "Hand.R": (-4 * tremble, 0, 0)}, tail_set(-1.2 * rear + 3.5 * lunge)),
        "jaw": track(u, [(0, 2), (0.18, 22), (0.36, 24), (H, 14), (0.7, 4), (1, 2)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def slash_bite(u):
    """ALLOFEEL hatchet slash, 1.3 s, hit at 0.42 (windup held 0.16-0.3): the slash-and-retreat bite (the hatchet-
    jaw hypothesis: open-mouthed strikes that wound, then back off and let the prey bleed). The head cocks high and to
    its left with the jaws gaping, the arms raised with the claws spread; a quick step in with the right foot and the
    OPEN upper jaw slashes down and across to its right through the prey, the arms raking with it; the jaws shut after
    the hit and it pulls back off the prey, stepping the right foot back to its print."""
    H = 0.42
    cock = track(u, [(0, 0), (0.16, 1), (0.3, 1), (H, 0), (1, 0)])
    slash = track(u, [(0, 0), (0.3, 0), (H, 1), (0.52, 0.85), (0.66, 0.2), (1, 0)])
    back = track(u, [(0, 0), (0.5, 0), (0.68, 1), (0.88, 0.6), (1, 0)])
    sweep = track(u, [(0, 0), (0.16, 1), (0.3, 1), (H, 0), (0.55, -1), (0.72, -0.6), (1, 0)])  # + its left; through the middle on the hit
    rf = track(u, [(0, 0), (0.26, 0), (0.38, 0.34), (0.62, 0.34), (0.82, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.26, 0), (0.32, 0.14), (0.38, 0), (0.62, 0), (0.72, 0.12), (0.82, 0), (1, 0)]))
    return {
        "body": {"pitch": 5 * cock - 14 * slash + 4 * back, "yaw": 7 * sweep, "roll": -3 * sweep,
                 "dz": 0.02 * cock - 0.08 * slash, "dy": -0.04 * cock + 0.24 * slash - 0.1 * back},
        "turns": merge({
            "Chest": (2 * cock - 6 * slash, 4 * sweep, 0),
            "Neck1": (14 * cock - 20 * slash + 6 * back, 13 * sweep, 0),
            "Neck2": (6 * cock - 12 * slash, 9 * sweep, 0),
            "Head": (-4 * cock - 14 * slash, 7 * sweep, 9 * sweep),
        }, arm_keys(u,
                    up=[(0, 0), (0.16, 34), (0.3, 38), (H, 56), (0.56, 14), (0.75, 0), (1, 0)],
                    out=[(0, 0), (0.16, 18), (0.3, 20), (H, 4), (1, 0)],
                    elbow=[(0, 0), (0.16, -6), (0.3, -10), (H, -34), (0.56, 22), (0.75, 10), (1, 0)],
                    wrist=[(0, 0), (0.16, 38), (0.3, 42), (H, 10), (0.52, -44), (0.75, -12), (1, 0)]),
            tail_set(-1.0 * cock + 3.5 * slash, -4 * cock + 6 * slash)),
        "jaw": track(u, [(0, 2), (0.16, 44), (0.3, 46), (H, 40), (0.5, 30), (0.58, 3), (0.75, 6), (1, 2)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def check(u, sgn):
    """ALLOFEEL shoulder-check to one side (sgn +1 = its right, -1 = its left), 1.0 s, hit at 0.45 (windup held 0.18-0.32):
    for prey beside its flank (a big animal's blind side). It leans away with the head turned off and the arms tucked,
    then slams its chest, shoulder and hip sideways into her, the near arm lashing out with the claws spread and
    raking down. At survivor height only its legs are there (the chest is 4 m up), so the near foot steps out sideways
    into her as the body lurches over it (a hip-and-shoulder check), and steps back to its print."""
    H = 0.45
    lean = track(u, [(0, 0), (0.18, 1), (0.32, 1), (H, 0), (1, 0)])
    slam = track(u, [(0, 0), (0.32, 0), (H, 1), (0.6, 0.8), (0.9, 0), (1, 0)])
    near, far = ("R", "L") if sgn > 0 else ("L", "R")
    out_ = track(u, [(0, 0), (0.3, 0), (H, 0.22), (0.66, 0.22), (0.9, 0), (1, 0)])
    lift = max(0.0, track(u, [(0, 0), (0.3, 0), (0.38, 0.16), (H, 0), (0.66, 0), (0.78, 0.12), (0.9, 0), (1, 0)]))
    return {
        "body": {"dx": sgn * (-0.07 * lean + 0.22 * slam), "roll": sgn * (-6 * lean + 15 * slam), "yaw": sgn * (4 * lean - 6 * slam),
                 "dz": -0.03 * lean - 0.08 * slam},
        "turns": merge({
            "Chest": (0, sgn * (4 * lean - 6 * slam), sgn * (-3 * lean + 6 * slam)),
            "Neck1": (6 * slam, sgn * (8 * lean + 16 * slam), 0), "Neck2": (4 * slam, sgn * (4 * lean + 10 * slam), 0),
            "Head": (6 * slam, sgn * 6 * slam, sgn * -6 * slam),
        }, arm_keys(u, **{
            "up": [(0, 0), (0.25, -16), (1, 0)], "elbow": [(0, 0), (0.25, 30), (1, 0)], "wrist": [(0, 0), (0.25, -28), (1, 0)],
            "up_" + near: [(0, 0), (0.25, -20), (0.38, 14), (H, 52), (0.6, 30), (0.85, 0), (1, 0)],
            "out_" + near: [(0, 0), (0.25, -6), (H, 56), (0.6, 40), (0.85, 4), (1, 0)],
            "elbow_" + near: [(0, 0), (0.25, 30), (H, -36), (0.6, 8), (1, 0)],
            "wrist_" + near: [(0, 0), (0.25, -28), (0.4, 40), (0.52, -40), (0.7, -16), (1, 0)],
            "up_" + far: [(0, 0), (0.25, -20), (H, -24), (0.7, -8), (1, 0)],
            "out_" + far: [(0, 0), (0.25, 0), (H, 16), (0.7, 6), (1, 0)],
            "wrist_" + far: [(0, 0), (0.25, -28), (H, 0), (0.7, -14), (1, 0)],
        }), tail_set(1.0 * slam, sgn * (-4 * lean + 9 * slam))),
        "jaw": track(u, [(0, 2), (0.3, 8), (H, 22), (0.7, 6), (1, 2)]),
        "feet": {near: (lift, 0.04 * out_, sgn * out_, 0), far: (0, 0, 0, 0)},
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
         "sleep": (sleep, 48, False), "feed": (feed, 48, True),
         "claw_rake": (claw_rake, 26, False), "slash_bite": (slash_bite, 31, False),
         "check_left": (lambda u: check(u, -1.0), 24, False), "check_right": (lambda u: check(u, 1.0), 24, False)}
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
