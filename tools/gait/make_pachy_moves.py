"""Author the pachycephalosaurus' one-shots, idle, feed and sleep on its rig_biped.py skeleton (Hips/Spine1/Chest/
Neck1/Neck2/Head/Jaw, Thigh/Shin/Metatarsal/Toe, Tail1-N, Arm/Forearm/Hand), in place. Standing clips keep the feet
IK-planted on their prints (no gliding); lying clips (knockdown, death, sleep) fold the legs and rest the body on the
floor with a skin floor pass every frame.

Owner 2026-10-31: "the Pachy's model is completely ruined ... give it fight moves that suit a dome-headed brawler".
# ASSUMPTION: the moves (PRD verb "dome headbutt charge"; no PRD clip list for it):
  attack_primary  dome butt, 1.0 s, hit 0.42: rock back, tuck the chin so the dome faces the prey, drive the body and
                  dome forward off a planted step; the dome is the most forward point at the hit.
  attack_heavy    stomp, 1.5 s, hit 0.72: rear up on the left leg with the right foot hauled high (the telegraph,
                  anim_events windup), slam it down ahead with the dome dropping behind it.
  kick            hip check, 1.0 s, hit 0.45: the brain plays "kick" when the prey is behind it; the hips and tail
                  slam round to the side and back, the feet pivot on their prints.
  alert           threat display: head lowered, dome presented, a stamp of the right foot, snort.
  charge          (make_gait.py, pachycephalosaurus.json) head-down run: the dome leads.
PACHYBULL (owner 2026-10-31: "instead of it walking back slowly, have it jump backwards and wind up like a bull,
huff huff, and then charge"):
  hop_back        0.58 s, in place (the brain moves the body back inside anim_events hop_back.airborne 0.2-0.65 and
                  lifts it on its arc): crouch on both legs, spring back nose-up with the feet tucked, land planted
                  with a squash. The brain plays it twice in a row after a charge.
  bull_windup     1.25 s, in place: head drops dome-first, weight back, the right foot paws the ground twice (lift,
                  reach forward, scrape back along the ground with the toe dug in) with a snort (head and jaw jolt)
                  at the end of each scrape; ends head-down, ready to launch the charge.
Hit fractions match game/data/creatures/anim_events.json (attack_primary 0.42, attack_heavy 0.72, kick 0.45).

usage: Blender -b -P tools/gait/make_pachy_moves.py -- <base.glb> <clip> <out.glb>
  clip: idle | alert | hop_back | bull_windup | attack_primary | attack_heavy | kick | hit_react | knockdown | death | sleep | feed
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
    set_m("Jaw", rot_about(cur.translation, cur.to_3x3().col[0].normalized(), math.radians(-p.get("jaw", 0.0))) @ cur)
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
    """Threat display, 1.5 s: the head drops and tucks so the dome faces the threat, a hard stamp of the right foot,
    a snort, the tail stiff and raised, then back up."""
    down = track(u, [(0, 0), (0.2, 1), (0.85, 1), (1, 0)])
    stamp = max(0.0, track(u, [(0, 0), (0.3, 0), (0.42, 0.35), (0.5, 0), (0.62, 0.3), (0.7, 0), (1, 0)]))
    jolt = track(u, [(0, 0), (0.49, 0), (0.52, 1), (0.6, 0), (0.69, 0), (0.72, 1), (0.8, 0), (1, 0)])
    jaw = track(u, [(0, 1), (0.48, 1), (0.53, 14), (0.62, 2), (0.7, 2), (0.74, 12), (0.85, 1), (1, 1)])
    return {
        "body": {"dz": -0.06 * down - 0.015 * jolt, "pitch": -6 * down, "dy": -0.04 * down},
        "turns": merge({
            "Chest": (-3 * down, 0, 0), "Neck1": (-20 * down, 0, 0), "Neck2": (-10 * down, 0, 0),
            "Head": (-28 * down + 4 * jolt, 4 * jolt, 0),
            "Arm.L": (12 * down, 0, 0), "Arm.R": (12 * down, 0, 0),
        }, tail_set(8 * down), tail_wave(u, 4.0, 0.0, cycles=3, env=down)),
        "jaw": jaw,
        "feet": {"L": (0, 0, 0, 0), "R": (stamp, 0.05 * smooth(stamp / 0.35), 0, 0)},
    }


def hop_back(u):
    """0.58 s: crouch (0-0.2), airborne 0.2-0.65 (the game carries the body back and up), landing squash, planted."""
    A0, A1 = 0.2, 0.65
    air = math.sin(math.pi * min(max((u - A0) / (A1 - A0), 0.0), 1.0))
    crouch = track(u, [(0, 0), (0.17, 1), (0.24, 0.2), (0.6, 0.1), (0.7, 1.1), (0.82, 0.5), (1, 0)])
    pitch = track(u, [(0, 0), (0.17, -3), (0.3, 7), (0.55, 5), (0.68, -4), (0.85, -1), (1, 0)])
    tuck = 0.13 * air  # feet drawn up under the body in the air (hip heights)
    reach = -0.06 * air  # and swung back towards the landing
    return {
        "body": {"dz": -0.09 * crouch, "pitch": pitch},
        "turns": merge({
            "Chest": (2 * air, 0, 0), "Neck1": (-6 * crouch + 6 * air, 0, 0), "Neck2": (-4 * crouch, 0, 0),
            "Head": (-10 * crouch - 2 * air, 0, 0),
            "Arm.L": (-20 * air, 0, 0), "Arm.R": (-20 * air, 0, 0),
        }, tail_set(-pitch * 0.8 + 4 * air)),
        "jaw": 2 + 6 * air,
        "feet": {"L": (tuck, reach, 0, 0), "R": (tuck * 0.9, reach * 1.1, 0, 0)},
    }


def bull_windup(u):
    """1.25 s: like a bull before the charge. Head down, dome forward, weight back on the left leg; the right foot paws
    twice: lift and reach forward, then scrape back along the ground (toe dug in, heel up), a snort (head jerk, jaw
    and a body jolt) at the end of each scrape. Ends head-down for the charge."""
    down = track(u, [(0, 0), (0.15, 1), (1, 1)])
    # paw cycles: (start, top, contact, scrape end)
    lift, fwd, heel = 0.0, 0.0, 0.0
    for a, b, c, d in ((0.12, 0.22, 0.3, 0.44), (0.5, 0.6, 0.67, 0.81)):
        if a <= u <= d:
            lift = max(0.0, track(u, [(a, 0), (b, 0.2), (c, 0), (d, 0)]))
            fwd = track(u, [(a, 0), (b, 0.16), (c, 0.22), (d, -0.1)])
            heel = track(u, [(a, 0), (b, 8), (c, 22), (d - 0.03, 22), (d, 0)])
        elif u > d and u < d + 0.06:
            fwd = track(u, [(d, -0.1), (d + 0.06, 0)])
    snort = track(u, [(0, 0), (0.43, 0), (0.46, 1), (0.54, 0), (0.8, 0), (0.83, 1), (0.92, 0), (1, 0)])
    jaw = track(u, [(0, 1), (0.43, 1), (0.46, 12), (0.55, 2), (0.8, 2), (0.83, 14), (0.93, 3), (1, 2)])
    breath = track(u, [(0, 0), (0.3, 0.6), (0.44, 1), (0.5, 0.2), (0.7, 0.7), (0.81, 1), (0.88, 0.2), (1, 0.4)])
    return {
        "body": {"dz": -0.07 * down - 0.02 * snort + 0.01 * breath, "pitch": -8 * down, "dy": -0.05 * down, "dx": 0.03 * down},
        "turns": merge({
            "Chest": (-4 * down + 2 * breath, 0, 0), "Neck1": (-22 * down + 3 * snort, 0, 0), "Neck2": (-12 * down, 0, 0),
            "Head": (-30 * down + 9 * snort, 3 * snort, 0),
            "Arm.L": (14 * down, 0, 0), "Arm.R": (14 * down, 0, 0),
        }, tail_set(10 * down + 4 * snort), tail_wave(u, 5.0, 0.0, cycles=2, env=down)),
        "jaw": jaw,
        "feet": {"L": (0, 0, 0, 0), "R": (lift, fwd, 0, heel)},
    }


def attack_primary(u):
    """Dome butt, 1.0 s, hit at 0.42: rock back on the hips, chin tucked so the dome faces forward, then drive the
    whole body forward off the left leg, the right foot stepping out under it, dome leading; recoil and step back."""
    H = 0.42
    dy = track(u, [(0, 0), (0.25, -0.12), (0.32, -0.13), (H, 0.42), (0.55, 0.38), (0.8, 0.08), (1, 0)])
    dz = track(u, [(0, 0), (0.25, 0.02), (H, -0.10), (0.55, -0.08), (0.85, 0), (1, 0)])
    pitch = track(u, [(0, 0), (0.25, 6), (0.32, 6), (H, -12), (0.55, -10), (0.85, -1), (1, 0)])
    tuck = track(u, [(0, 0), (0.25, 1), (H, 1), (0.6, 0.7), (0.9, 0), (1, 0)])
    jolt = track(u, [(0, 0), (H - 0.02, 0), (H + 0.03, 1), (0.6, 0), (1, 0)])
    rf = track(u, [(0, 0), (0.22, 0), (0.38, 0.35), (0.75, 0.35), (0.93, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.22, 0), (0.3, 0.16), (0.38, 0), (0.75, 0), (0.84, 0.14), (0.93, 0), (1, 0)]))
    return {
        "body": {"dy": dy, "dz": dz, "pitch": pitch},
        "turns": merge({
            "Chest": (-6 * tuck, 0, 0), "Neck1": (-26 * tuck + 6 * jolt, 0, 0), "Neck2": (-16 * tuck, 0, 0),
            "Head": (-50 * tuck + 8 * jolt, 0, 0),
            "Arm.L": (-15 * tuck, 0, 0), "Arm.R": (-15 * tuck, 0, 0),
        }, tail_set(-pitch * 0.6 + 6 * tuck)),
        "jaw": track(u, [(0, 1), (0.3, 6), (H, 0), (0.6, 10), (1, 1)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def attack_heavy(u):
    """Stomp, 1.5 s, hit at 0.72: shift onto the left leg and rear up, the right foot hauled high and held (the
    telegraph), then slammed down ahead with the dome dropping behind it, a heavy shudder, step back."""
    H = 0.72
    dx = track(u, [(0, 0), (0.2, -0.08), (0.6, -0.09), (H, -0.02), (0.88, 0), (1, 0)])
    dy = track(u, [(0, 0), (0.2, -0.06), (0.6, -0.08), (H, 0.2), (0.88, 0.15), (1, 0)])
    dz = track(u, [(0, 0), (0.25, 0.05), (0.6, 0.06), (H, -0.1), (0.77, -0.07), (0.82, -0.09), (0.94, 0), (1, 0)])
    pitch = track(u, [(0, 0), (0.25, 22), (0.6, 24), (H, -12), (0.82, -8), (1, 0)])
    roll = track(u, [(0, 0), (0.2, -6), (0.6, -7), (H, 2), (0.88, 0), (1, 0)])
    nd = track(u, [(0, 0), (0.25, 8), (0.6, 10), (H, -24), (0.82, -16), (1, 0)])
    shudder = track(u, [(0, 0), (H, 0), (0.74, 1), (0.86, 0), (1, 0)])
    lift = max(0.0, track(u, [(0, 0), (0.15, 0), (0.42, 0.55), (0.62, 0.58), (H, 0), (0.88, 0), (0.94, 0.1), (1, 0)]))
    fwd = track(u, [(0, 0), (0.15, 0), (0.42, 0.15), (0.6, 0.16), (H, 0.3), (0.88, 0.3), (0.99, 0), (1, 0)])
    return {
        "body": {"dx": dx, "dy": dy, "dz": dz + 0.008 * shudder * wave(u, 14), "pitch": pitch, "roll": roll},
        "turns": merge({
            "Chest": (-0.2 * pitch, 0, 0), "Neck1": (nd, 0, 0), "Neck2": (nd * 0.5, 0, 0),
            "Head": (nd * 0.6, 0, 4 * shudder * wave(u, 12)),
            "Arm.L": (track(u, [(0, 0), (0.6, 25), (H, -10), (1, 0)]), 0, 0), "Arm.R": (track(u, [(0, 0), (0.6, 25), (H, -10), (1, 0)]), 0, 0),
        }, tail_set(-pitch * 0.5)),
        "jaw": track(u, [(0, 1), (0.3, 12), (0.6, 16), (0.7, 26), (0.85, 20), (0.95, 2), (1, 1)]),
        "feet": {"L": (0, 0, 0, 0), "R": (lift, fwd, 0.04 * smooth(lift / 0.5), 14 * smooth(lift / 0.4))},
    }


def kick(u):
    """Hip check, 1.0 s, hit at 0.45: a crouch, then the hips and the stiff tail slam round to the right and back
    (the side the prey is on behind it), the body rolling into it, the feet pivoting on their prints; swing back."""
    H = 0.45
    yaw = track(u, [(0, 0), (0.25, 10), (0.32, 11), (H, -30), (0.6, -26), (0.85, -3), (1, 0)])
    roll = track(u, [(0, 0), (0.25, -4), (H, 10), (0.6, 8), (1, 0)])
    dz = track(u, [(0, 0), (0.25, -0.05), (H, -0.03), (0.7, -0.02), (1, 0)])
    dx = track(u, [(0, 0), (0.25, -0.06), (0.32, -0.06), (H, 0.22), (0.6, 0.18), (1, 0)])
    look = track(u, [(0, 0), (0.3, -20), (H, 30), (0.6, 26), (1, 0)])
    tails = {}
    for i, t in enumerate(TAILS):
        lag = 0.02 * i
        tails[t] = (0, track(u, [(0, 0), (0.28 + lag, 8), (H + lag, -16), (0.62 + lag, -9), (0.9, 0), (1, 0)]), 0)
    # the feet stay on their prints and turn with the body (a pivot, not a slide)
    return {
        "body": {"yaw": yaw, "roll": roll, "dz": dz, "dx": dx},
        "turns": merge(tails, {"Chest": (0, -0.3 * yaw, 0), "Neck1": (0, look * 0.6, 0), "Neck2": (0, look * 0.4, 0), "Head": (0, look * 0.3, 0)}),
        "jaw": track(u, [(0, 1), (0.35, 8), (H, 12), (0.7, 2), (1, 1)]),
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


CLIPS = {"idle": (idle, 60, True), "alert": (alert, 36, False), "hop_back": (hop_back, 14, False), "bull_windup": (bull_windup, 30, False), "attack_primary": (attack_primary, 24, False),
         "attack_heavy": (attack_heavy, 36, False), "kick": (kick, 24, False), "hit_react": (hit_react, 14, False),
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
print(f"PACHYMOVE {CLIP} {N} frames ({N / FPS:.3f} s)")

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
