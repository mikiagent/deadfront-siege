"""Author the spinosaurus' one-shots, idle, feed and sleep on its rig_biped.py skeleton (make_cerato_moves.py's
machinery: feet IK-planted on their prints in standing clips, lying clips folded onto the floor).

Owner 2026-10-31 (species brief): "Be creative with what moves you think they should do when they fight"; design notes:
a crocodile-snout snap-and-shake (grab and thrash), a sweeping forearm claw rake, a sail-flare threat display, an
ambush lunge from the water; it uses its claws (raptor-like species use their arms). # ASSUMPTION: shapes and timings.
  attack_primary  croc snap, 0.9 s, hit 0.42: the long snout swings out to the side with the jaws gaping, the claws
                  hooking forward, and snaps shut across the prey on the hit.
  attack_heavy    forearm claw rake, 1.6 s, hit 0.72 (windup held to 0.6): rears up, both arms cocked high with the
                  claws spread (the telegraph), then drops forward off a planted step and rakes both hooked claws
                  down and across; hits from the hands.
  bite_shake      snap-and-shake, 2.5 s, clamp 0.30, release 0.78: head drawn back with the jaws gaping and the claws
                  raised, a low lunge and clamp, the head lifts her and thrashes side to side (three shakes), then
                  whips to its left and opens: she is flung (TacticalBrain tactics.grab carries and throws her).
  kick            tail swipe, 1.0 s, hit 0.45 (the brain's "kick" slot: the prey behind it).
  pounce          water ambush lunge, 1.2 s, airborne 0.2-0.65, hit 0.7: sunk low, a flat surge with the jaws wide and
                  the claws reaching, the snap on landing and a tug.
  alert           sail-flare display / roar, 1.9 s: turns broadside to show the full sail, rears up and swells, arms
                  spread with the claws open, then roars with the jaws wide and the head shaking.
Hit fractions match game/data/creatures/anim_events.json (attack_primary 0.42, attack_heavy 0.72, bite_shake 0.30 and
release_frac 0.78, kick 0.45, pounce 0.7).

usage: Blender -b -P tools/gait/make_spino_moves.py -- <base.glb> <clip> <out.glb>
  clip: idle | alert | attack_primary | attack_heavy | bite_shake | kick | pounce | hit_react | knockdown | death | sleep | feed
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

# ---------------------------------------------------------------------------------------------------- clips
# Arms: + pitch swings a hanging arm forward and up (about the animal's right axis); Forearm/Hand curl with + too.


def arms(a=0.0, fa=0.0, h=0.0, spread=0.0, l=1.0, r=1.0):
    """both arms: upper-arm pitch, forearm and hand curl, spread = yaw outward (degrees)."""
    return {"Arm.L": (a * l, spread * l, 0), "Arm.R": (a * r, -spread * r, 0),
            "Forearm.L": (fa * l, 0, 0), "Forearm.R": (fa * r, 0, 0), "Hand.L": (h * l, 0, 0), "Hand.R": (h * r, 0, 0)}


def idle(u):
    """3.0 s loop: two slow breaths swelling the chest under the sail, weight rolling foot to foot, a look left and
    right with the long snout, the claws flexing, the tail swaying, a jaw twitch."""
    br = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * u)
    sway = wave(u, 1)
    look = wave(u, 1, 0.15)
    return {
        "body": {"dz": -0.012 * br, "dx": 0.012 * sway, "roll": 1.0 * sway, "pitch": 0.8 * br},
        "turns": merge({
            "Chest": (1.5 * br, 0, 0),
            "Neck1": (-1.5 * br, 6.0 * look, 0), "Neck2": (-1.0 * br, 5.0 * look, 0), "Head": (2.0 * br, 5.0 * look, 3.0 * look),
        }, arms(4 * br, 6 * br, 8 * max(0.0, wave(u, 2, 0.3))), tail_wave(u, 5.0, 1.5, delay=0.06, cycles=1, phase=0.1)),
        "jaw": 1.0 + 5.0 * smooth((br - 0.6) / 0.4),
        "feet": PLANT,
    }


def alert(u):
    """Sail-flare display and roar, 1.9 s: turns broadside (the body swings 65 deg off the threat while the head keeps
    looking at it) so the whole sail shows, rears up and swells the chest with the arms spread and the claws open,
    holds it, then thrusts the head at the threat with the jaws wide and shakes it; the tail lifts and lashes."""
    side = track(u, [(0, 0), (0.22, 1), (0.85, 1), (1, 0)])
    up = track(u, [(0, 0), (0.25, 1), (0.5, 1), (0.62, 0.5), (0.85, 0.5), (1, 0)])
    roar = track(u, [(0, 0), (0.5, 0), (0.62, 1), (0.88, 1), (1, 0)])
    shake = roar * wave(u, 4.0)
    yaw = 65 * side
    return {
        "body": {"yaw": yaw, "dz": 0.05 * up - 0.03 * roar, "pitch": 11 * up - 5 * roar, "roll": -5 * side},
        "turns": merge({
            "Chest": (4 * up, -0.15 * yaw, 0), "Neck1": (14 * up - 8 * roar, -0.38 * yaw + 6 * shake, 0),
            "Neck2": (6 * up - 2 * roar, -0.28 * yaw + 5 * shake, 0),
            "Head": (-6 * up + 8 * roar, -0.19 * yaw + 8 * shake, 8 * shake),
        }, arms(40 * up + 20 * roar, -20 * up, -25 * up, spread=25 * up),
            tail_set(-2 * up - 1 * roar, 0.12 * yaw), tail_wave(u, 6.0, 0.0, cycles=3, env=roar)),
        "jaw": track(u, [(0, 1), (0.25, 10), (0.5, 8), (0.62, 30), (0.86, 28), (0.96, 3), (1, 1)]),
        "feet": PLANT,
    }


def attack_primary(u):
    """Croc snap, 0.9 s, hit at 0.42: the head drops and swings out to the left with the long jaws gaping and the
    claws hooking forward, then the snout sweeps down and across to the right as the body lunges off a planted step,
    snapping shut on the hit; a backward tug, and it steps back."""
    H = 0.42
    dy = track(u, [(0, 0), (0.25, -0.06), (H, 0.30), (0.6, 0.24), (0.85, 0.05), (1, 0)])
    dz = track(u, [(0, 0), (0.25, -0.04), (H, -0.16), (0.6, -0.12), (0.9, 0), (1, 0)])
    pitch = track(u, [(0, 0), (0.25, -6), (H, -14), (0.6, -9), (0.9, 0), (1, 0)])
    yaw = track(u, [(0, 0), (0.25, 24), (H, -8), (0.6, -16), (0.85, -3), (1, 0)])
    dip = track(u, [(0, 0), (0.25, -8), (H, -20), (0.6, -12), (0.85, 0), (1, 0)])
    reach = track(u, [(0, 0), (0.25, 1), (H, 0.6), (0.7, 0.2), (1, 0)])
    rf = track(u, [(0, 0), (0.2, 0), (0.36, 0.32), (0.72, 0.32), (0.92, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.2, 0), (0.28, 0.14), (0.36, 0), (0.72, 0), (0.82, 0.12), (0.92, 0), (1, 0)]))
    return {
        "body": {"dy": dy, "dz": dz, "pitch": pitch, "yaw": 0.15 * yaw},
        "turns": merge({
            "Chest": (0, 0.15 * yaw, 0), "Neck1": (dip, 0.4 * yaw, 0), "Neck2": (0.5 * dip, 0.3 * yaw, 0),
            "Head": (6 - 0.2 * dip, 0.2 * yaw, 0.4 * yaw),
        }, arms(45 * reach, 15 * reach, 20 * reach), tail_set(-pitch * 0.5, -0.4 * yaw)),
        "jaw": track(u, [(0, 1), (0.25, 27), (0.36, 30), (H, 0), (0.62, 2), (0.8, 6), (1, 1)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def attack_heavy(u):
    """Forearm claw rake, 1.6 s, hit at 0.72 (windup held to 0.6): rears up with both arms cocked high and the hooked
    thumb claws spread, holds it (the telegraph) with a low hiss, then drops forward off a big planted step and rakes
    both claws down and across through the prey, the left a beat ahead of the right; recovers."""
    H = 0.72
    rear = track(u, [(0, 0), (0.3, 1), (0.6, 1), (0.66, 0.6), (H, 0), (1, 0)])
    drop = track(u, [(0, 0), (0.6, 0), (H, 1), (0.85, 0.8), (1, 0)])
    rakeL = track(u, [(0, 0), (0.3, 1), (0.6, 1), (0.7, -0.35), (0.85, -0.4), (1, 0)])
    rakeR = track(u, [(0, 0), (0.3, 1), (0.62, 1), (0.74, -0.35), (0.88, -0.4), (1, 0)])
    hiss = track(u, [(0, 0), (0.32, 0), (0.4, 1), (0.58, 1), (0.64, 0), (1, 0)])
    rf = track(u, [(0, 0), (0.6, 0), (0.7, 0.36), (0.88, 0.36), (0.98, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.6, 0), (0.65, 0.16), (0.7, 0), (0.88, 0), (0.93, 0.12), (0.98, 0), (1, 0)]))
    return {
        "body": {"dy": -0.05 * rear + 0.32 * drop, "dz": 0.06 * rear - 0.10 * drop, "pitch": 14 * rear - 8 * drop,
                 "yaw": -4 * drop},
        "turns": merge({
            "Chest": (5 * rear - 6 * drop, 4 * drop, 0), "Neck1": (8 * rear - 6 * drop, 0, 0), "Neck2": (2 * rear, 0, 0),
            "Head": (-10 * rear + 6 * drop, 0, 0),
            "Arm.L": (60 * rakeL, 28 * max(0.0, rakeL), 0), "Arm.R": (60 * rakeR, -28 * max(0.0, rakeR), 0),
            "Forearm.L": (-15 * max(0.0, rakeL) + 25 * drop, 0, 0), "Forearm.R": (-15 * max(0.0, rakeR) + 25 * drop, 0, 0),
            "Hand.L": (-25 * max(0.0, rakeL) + 20 * drop, 0, 0), "Hand.R": (-25 * max(0.0, rakeR) + 20 * drop, 0, 0),
        }, tail_set(-5 * rear + 6 * drop), tail_wave(u, 3.0, 0.0, cycles=2, env=hiss)),
        "jaw": track(u, [(0, 1), (0.3, 8), (0.4, 16), (0.58, 16), (H, 4), (0.85, 8), (1, 1)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def bite_shake(u):
    """Snap-and-shake, 2.5 s, clamp at 0.30, release at 0.78: the head draws back and up with the long jaws gaping and
    the claws raised (the telegraph), lunges low and clamps, lifts her and thrashes the head side to side three times
    with the claws clutching, then whips the head to its left and opens the jaws (she is flung), and recovers."""
    C, R = 0.30, 0.78
    draw = track(u, [(0, 0), (0.2, 1), (C - 0.03, 0), (1, 0)])
    lunge = track(u, [(0, 0), (0.2, 0), (C, 1), (0.4, 0.6), (R, 0.5), (0.9, 0), (1, 0)])
    lift = track(u, [(0, 0), (C, 0), (0.4, 1), (R - 0.04, 1), (0.9, 0), (1, 0)])
    sh = track(u, [(0, 0), (0.4, 0), (0.44, 1), (0.7, 1), (0.74, 0), (1, 0)]) * wave(u - 0.4, 3.0 / 0.32)
    fling = track(u, [(0, 0), (0.72, 0), (R, 1), (0.88, 0.6), (1, 0)])
    clutch = track(u, [(0, 0), (0.2, 0.8), (C, 1), (R, 1), (0.88, 0), (1, 0)])
    rf = track(u, [(0, 0), (0.18, 0), (0.28, 0.3), (0.86, 0.3), (0.96, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.18, 0), (0.23, 0.14), (0.28, 0), (0.86, 0), (0.91, 0.1), (0.96, 0), (1, 0)]))
    return {
        "body": {"dy": -0.06 * draw + 0.30 * lunge, "dz": 0.03 * draw - 0.16 * lunge + 0.06 * lift,
                 "pitch": 8 * draw - 14 * lunge + 6 * lift, "yaw": 6 * sh + 10 * fling, "roll": -4 * sh},
        "turns": merge({
            "Chest": (3 * draw, 4 * sh, 0),
            "Neck1": (14 * draw - 20 * lunge + 12 * lift, 12 * sh + 20 * fling, 0),
            "Neck2": (6 * draw - 8 * lunge + 6 * lift, 10 * sh + 14 * fling, 0),
            "Head": (-8 * draw + 10 * lunge - 4 * lift, 8 * sh + 6 * fling, 14 * sh),
        }, arms(55 * clutch, 30 * clutch, 30 * clutch, spread=10 * draw),
            tail_set(-4 * draw + 3 * lunge, -6 * sh - 8 * fling), tail_wave(u, 5.0, 0.0, cycles=3, env=abs(sh))),
        "jaw": track(u, [(0, 1), (0.2, 30), (C - 0.03, 30), (C, 3), (R - 0.02, 3), (R + 0.03, 28), (0.9, 8), (1, 1)]),
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
        tails[t] = (track(u, [(0, 0), (0.3, 1), (H, 2), (0.7, 1), (1, 0)]),  # a slight droop: the whip passes low, never into the ground
                    k * track(u, [(0, 0), (0.28 + lag, 6), (H - 0.04 + lag, 0), (0.62 + lag, -8), (0.9, 0), (1, 0)]), 0)
    return {
        "body": {"yaw": yaw, "roll": roll, "dz": dz, "pitch": track(u, [(0, 0), (0.3, 1), (H, 2), (0.8, 0), (1, 0)])},
        "turns": merge(tails, {"Chest": (0, -0.3 * yaw, 0), "Neck1": (0, look * 0.6, 0), "Neck2": (0, look * 0.4, 0), "Head": (0, look * 0.3, 0)}),
        "jaw": track(u, [(0, 1), (0.35, 10), (H, 16), (0.7, 2), (1, 1)]),
        "feet": PLANT,
    }


def pounce(u):
    """Water ambush lunge, 1.2 s, airborne 0.2-0.65, hit at 0.7: sinks into a low crouch with the head flat and
    forward (a croc in the shallows), surges out flat and low with the jaws wide and the claws reaching (the brain
    carries the body), snaps shut as it lands and tugs the head to the side."""
    crouch = track(u, [(0, 0), (0.16, 1), (0.24, 0.4), (0.62, 0.3), (0.72, 0.8), (0.85, 0.3), (1, 0)])
    air = track(u, [(0, 0), (0.18, 0), (0.28, 1), (0.58, 1), (0.66, 0), (1, 0)])
    tug = track(u, [(0, 0), (0.7, 0), (0.78, 1), (0.9, 0.4), (1, 0)])
    lf = track(u, [(0, 0), (0.2, 0), (0.32, -0.25), (0.55, -0.2), (0.66, 0), (1, 0)])
    lift = max(0.0, track(u, [(0, 0), (0.2, 0), (0.32, 0.2), (0.55, 0.2), (0.66, 0), (1, 0)]))
    return {
        "body": {"dz": -0.18 * crouch + 0.04 * air, "pitch": -8 * crouch - 4 * air, "dy": -0.04 * crouch},
        "turns": merge({
            "Chest": (-2 * crouch, 0, 0), "Neck1": (-14 * crouch - 6 * air + 4 * tug, 0, 0), "Neck2": (-4 * crouch, 0, 0),
            "Head": (10 * crouch + 6 * air - 6 * tug, 14 * tug, 18 * tug),
        }, arms(60 * air + 20 * crouch, 10 * air, -20 * air + 30 * tug),
            tail_set(5 * air + 4 * crouch, 6 * tug), tail_wave(u, 5.0, 0.0, cycles=1.5, env=air)),
        "jaw": track(u, [(0, 1), (0.16, 12), (0.3, 30), (0.62, 30), (0.7, 0), (0.85, 3), (1, 1)]),
        "feet": {"L": (lift, lf, 0, 0), "R": (lift * 0.9, lf * 0.9, 0, 0)},
    }


def hit_react(u):
    """0.6 s: the head and chest jerk back and up from the blow, the arms fling out, a stagger step back."""
    j = track(u, [(0, 0), (0.15, 1), (0.45, 0.7), (1, 0)])
    lf = track(u, [(0, 0), (0.1, 0), (0.36, -0.16), (0.62, -0.16), (0.9, 0), (1, 0)])
    ll = max(0.0, track(u, [(0, 0), (0.06, 0), (0.22, 0.14), (0.38, 0), (0.6, 0), (0.75, 0.12), (0.92, 0), (1, 0)]))
    return {
        "body": {"dy": -0.08 * j, "pitch": 9 * j, "roll": -3 * j, "dz": -0.02 * j},
        "turns": merge({"Neck1": (12 * j, 6 * j, 0), "Neck2": (8 * j, 0, 0), "Head": (14 * j, 0, -8 * j)},
                       arms(25 * j, -10 * j, -15 * j, spread=10 * j), tail_set(-6 * j)),
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
                       arms(20 * c, 20 * c, 10 * c), tail_set(5 * c, -8 * c)),
        "feet": {"L": None, "R": None},
        "legs": legs,
        "rest_on_floor": True,
    }


def knockdown(u):
    """2.1 s: the knees buckle, it topples onto its right side (the sail swinging down flat) and lies there (the capture hold)."""
    p = collapse(u, 82, 1, 20, 0.45)
    p["jaw"] = track(u, [(0, 1), (0.3, 16), (0.5, 6), (1, 4)])
    return p


def death(u):
    """1.8 s: a last stagger, then a heavy fall onto the right side, the neck and tail going slack."""
    p = collapse(u, 88, 1, 34, 0.5)
    p["jaw"] = track(u, [(0, 1), (0.3, 20), (0.6, 10), (1, 8)])
    return p


def sleep(u):
    """2.0 s, held on the last frame: settles belly-down onto folded legs, the long snout laid on the ground, the arms
    tucked, the tail curled round."""
    c = track(u, [(0, 0), (0.75, 1), (1, 1)])
    buckle = track(u, [(0, 0), (0.6, 1), (1, 1)])
    return {
        "body": {"pitch": -3 * c},
        "turns": merge({"Neck1": (-30 * c, 12 * c, 0), "Neck2": (-14 * c, 10 * c, 0), "Head": (12 * c, 8 * c, 4 * c)},
                       arms(-20 * c, 50 * c, 20 * c), tail_set(6 * c, 9 * c, 0.95)),
        "jaw": 0.5,
        "feet": {"L": None, "R": None},
        "legs": {sd: tuple(v * buckle for v in FOLD[sd]) for sd in "LR"},
        "rest_on_floor": True,
    }


def feed(u):
    """2.0 s loop: head down to a carcass (a fish), the claws pinning it, two tearing bites with a backward tug."""
    d = 0.5 - 0.5 * math.cos(2 * math.pi * u)
    d = 0.75 + 0.25 * (1 - d)  # stays mostly down
    tug = max(0.0, wave(u, 2))
    return {
        "body": {"pitch": -11 * d, "dz": -0.06 * d, "dy": 0.02 * d},
        "turns": merge({"Chest": (-5 * d, 0, 0), "Neck1": (-20 * d + 4 * tug, 3 * wave(u, 1), 0), "Neck2": (-10 * d, 0, 0), "Head": (0 * d + 6 * tug, 0, 0)},
                       arms(12 * d, 15 * d, 10 * d), tail_set(2 * d), tail_wave(u, 2.0, 0.0)),
        "jaw": 2 + 12 * max(0.0, wave(u, 4)),
        "feet": PLANT,
    }


CLIPS = {"idle": (idle, 72, True), "alert": (alert, 46, False), "attack_primary": (attack_primary, 22, False),
         "attack_heavy": (attack_heavy, 38, False), "bite_shake": (bite_shake, 60, False), "kick": (kick, 24, False),
         "pounce": (pounce, 29, False), "hit_react": (hit_react, 14, False), "knockdown": (knockdown, 50, False),
         "death": (death, 43, False), "sleep": (sleep, 48, False), "feed": (feed, 48, True)}
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
print(f"SPINOMOVE {CLIP} {N} frames ({N / FPS:.3f} s)")

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
