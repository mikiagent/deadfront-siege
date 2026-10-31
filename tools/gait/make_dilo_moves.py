"""Author the dilophosaurus' one-shots, idle, feed and sleep on its rig_biped.py skeleton (as make_pachy_moves.py) plus
its frill ribs (dilophosaurus_frill.py), in place. Standing clips keep the feet IK-planted; lying clips fold the legs and
rest on the floor; the pounce's flight leaves the legs free.

Owner 2026-10-30: "Be creative with what moves you think they should do when they fight"; task: frill flare + hiss as
the telegraph, a venom spit, a quick snapping bite, a leaping slash. # ASSUMPTION (SP-DILOPHOSAURUS, no PRD clip list):
  alert           frill flare + hiss display (the hold pose and the threat display)
  attack_primary  quick snapping bite, 0.9 s, hit 0.42
  attack_heavy    flare-and-slash, 1.6 s, hit 0.72: crouch + flare + hiss (the telegraph), then a raking forward kick;
                  0 -> 0.72 is also the pounce windup
  spit            venom spit, 1.4 s, the glob leaves at 0.62 (TacticalBrain launches VenomSpit on that hit)
  pounce          leaping slash, 1.0 s, airborne 0.2-0.65, both feet rake at 0.7

usage: Blender -b -P tools/gait/make_dilo_moves.py -- <base.glb> <clip> <out.glb>
  clip: idle | alert | attack_primary | attack_heavy | spit | pounce | hit_react | knockdown | death | sleep | feed
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

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

# the frill ribs (dilophosaurus_frill.py): rest = folded; f 0..1 slerps each rib to its open rotation, relative to the
# posed Neck2, with an optional shiver (a rattle of the membrane while it is held open)
RIBS = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "dilophosaurus_frill.json")))
RIB_PARENT = RIBS["parent"]


def set_frill(f, shiver=0.0):
    par = pbs[RIB_PARENT]
    pm = par.matrix @ bones[RIB_PARENT].matrix_local.inverted()
    for i, (name, r) in enumerate(sorted(RIBS["ribs"].items())):
        if name not in pbs:
            continue
        h = Vector(r["head"])
        k = min(1.0, max(0.0, f * (1.0 + shiver * math.sin(7.3 * i + 41.0 * f))))
        q = Quaternion((1, 0, 0, 0)).slerp(Quaternion(r["q_open"]), k)
        set_m(name, pm @ Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h) @ bones[name].matrix_local)


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
    set_frill(p.get("frill", 0.0), p.get("frill_shiver", 0.0))
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
# Hit fractions match game/data/creatures/anim_events.json: attack_primary 0.42, attack_heavy 0.72 (windup), spit 0.62
# (the glob leaves the mouth), pounce airborne 0.2-0.65 and hit 0.7.


def idle(u):
    """2.5 s loop: two breaths, weight rolling foot to foot, a look round, the whip tail swaying, frill shut."""
    br = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * u)
    sway = wave(u, 1)
    look = wave(u, 1, 0.15)
    return {
        "body": {"dz": -0.01 * br, "dx": 0.015 * sway, "roll": 1.0 * sway, "pitch": 0.6 * br},
        "turns": merge({
            "Chest": (1.2 * br, 0, 0),
            "Neck1": (-1.5 * br, 7.0 * look, 0), "Neck2": (-1.0 * br, 6.0 * look, 0), "Head": (2.0 * br, 5.0 * look, 4.0 * look),
            "Arm.L": (4 * br, 0, 0), "Arm.R": (4 * br, 0, 0),
        }, tail_wave(u, 4.0, 1.2, delay=0.07, cycles=1, phase=0.1)),
        "jaw": 1.0 + 3.0 * smooth((br - 0.6) / 0.4),
        "frill": 0.0,
        "feet": PLANT,
    }


def alert(u):
    """Threat display, 1.6 s: the frill snaps open (by 0.25) and rattles, the body sinks and the head rises and sways
    side to side, jaws wide in a long hiss, tail up; the frill folds again over the last 15 %."""
    up = track(u, [(0, 0), (0.2, 1), (0.85, 1), (1, 0)])
    fr = track(u, [(0, 0), (0.08, 0.2), (0.25, 1), (0.85, 1), (1, 0.05)])
    sway = wave(u, 2, 0.0) * track(u, [(0, 0), (0.25, 1), (0.8, 1), (1, 0)])
    hiss = track(u, [(0, 1), (0.15, 4), (0.3, 30), (0.75, 30), (0.9, 6), (1, 1)])
    return {
        "body": {"dz": -0.07 * up, "pitch": -4 * up, "dy": -0.03 * up, "roll": 2 * sway},
        "turns": merge({
            "Chest": (3 * up, 0, 0), "Neck1": (14 * up, 9 * sway, 0), "Neck2": (6 * up, 7 * sway, 0),
            "Head": (-8 * up + 3 * wave(u, 9) * up, 4 * sway, 9 * sway),
            "Arm.L": (-18 * up, 0, 0), "Arm.R": (-18 * up, 0, 0), "Forearm.L": (-20 * up, 0, 0), "Forearm.R": (-20 * up, 0, 0),
        }, tail_set(-3 * up), tail_wave(u, 6.0, 0.0, cycles=3, env=up)),  # tail_set: + droops, - raises (it adds up down 7 bones)
        "jaw": hiss + 2.0 * wave(u, 11) * up,
        "frill": fr,
        "frill_shiver": 0.06 * up,
        "feet": PLANT,
    }


def attack_primary(u):
    """Quick snapping bite, 0.9 s, hit at 0.42: a flick of the frill, the head cocks back, then darts forward and down
    off a short step with the right foot, the jaws snapping shut at the hit; it pulls straight back."""
    H = 0.42
    dy = track(u, [(0, 0), (0.22, -0.06), (H, 0.32), (0.55, 0.3), (0.85, 0.05), (1, 0)])
    dz = track(u, [(0, 0), (0.22, 0.01), (H, -0.08), (0.6, -0.06), (1, 0)])
    pitch = track(u, [(0, 0), (0.22, 5), (H, -10), (0.6, -8), (1, 0)])
    cock = track(u, [(0, 0), (0.22, 1), (0.3, 1), (H, -1), (0.6, -0.8), (0.95, 0), (1, 0)])
    rf = track(u, [(0, 0), (0.18, 0), (0.36, 0.3), (0.78, 0.3), (0.95, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.18, 0), (0.27, 0.14), (0.36, 0), (0.78, 0), (0.86, 0.12), (0.95, 0), (1, 0)]))
    return {
        "body": {"dy": dy, "dz": dz, "pitch": pitch},
        "turns": merge({
            "Chest": (-3 * cock, 0, 0), "Neck1": (14 * cock, 0, 0), "Neck2": (10 * cock, 0, 0), "Head": (6 * cock - 8 * max(0.0, -cock), 0, 0),
            "Arm.L": (-25 * max(0.0, -cock), 0, 0), "Arm.R": (-25 * max(0.0, -cock), 0, 0),
        }, tail_set(-pitch * 0.35)),
        "jaw": track(u, [(0, 1), (0.22, 8), (0.36, 34), (H, 2), (0.55, 4), (0.7, 1), (1, 1)]),
        "frill": track(u, [(0, 0), (0.15, 0.45), (0.55, 0.45), (0.8, 0), (1, 0)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def attack_heavy(u):
    """Flare and slash, 1.6 s, hit at 0.72: the frill flares and rattles while it sinks into a crouch, hissing, tail
    up (the telegraph, held to 0.6), then it springs off the left leg and rakes the right foot forward and down through
    the prey, claws first; it lands the step and pulls back. As the pounce windup the game plays 0 -> 0.72."""
    H = 0.72
    crouch = track(u, [(0, 0), (0.3, 1), (0.6, 1), (0.66, 0.3), (H, 0), (0.9, 0.3), (1, 0)])
    dy = track(u, [(0, 0), (0.3, -0.08), (0.6, -0.1), (H, 0.16), (0.85, 0.14), (1, 0)])
    dz = -0.14 * crouch
    pitch = track(u, [(0, 0), (0.3, -4), (0.6, -5), (0.68, 8), (H, 4), (0.85, -2), (1, 0)])
    fr = track(u, [(0, 0), (0.25, 1), (0.85, 1), (1, 0)])
    hiss = track(u, [(0, 1), (0.2, 24), (0.6, 28), (0.68, 10), (H, 30), (0.85, 8), (1, 1)])
    # the raking foot comes down ahead (0.78), then steps back to its print lifted, never sliding on the ground
    rl = max(0.0, track(u, [(0, 0), (0.6, 0), (0.68, 0.62), (H, 0.3), (0.78, 0.0), (0.82, 0.0), (0.89, 0.16), (0.96, 0), (1, 0)]))
    rf = track(u, [(0, 0), (0.6, 0), (0.68, 1.05), (H, 1.0), (0.78, 0.8), (0.82, 0.8), (0.96, 0), (1, 0)])
    heel = track(u, [(0, 0), (0.6, 0), (0.66, -30), (H, -10), (0.8, 0), (1, 0)])  # toes up: claws lead the rake
    return {
        "body": {"dy": dy, "dz": dz, "pitch": pitch, "roll": track(u, [(0, 0), (0.6, 0), (H, -4), (1, 0)])},
        "turns": merge({
            "Chest": (2 * crouch, 0, 0), "Neck1": (10 * crouch - 6 * (1 - crouch) * fr, 0, 0), "Neck2": (4 * crouch, 0, 0),
            "Head": (-6 * crouch + 2 * wave(u, 10) * crouch, 0, 0),
            "Arm.L": (-20 * fr, 0, 0), "Arm.R": (-20 * fr, 0, 0),
        }, tail_set(-2 * crouch - pitch * 0.4), tail_wave(u, 5.0, 0.0, cycles=3, env=crouch)),
        "jaw": hiss,
        "frill": fr,
        "frill_shiver": 0.07 * crouch,
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0.03 * smooth(rl / 0.3), heel)},
    }


def spit(u):
    """Venom spit, 1.4 s, the glob leaves at 0.62: the frill flares and the head draws back and up, jaws gaping, throat
    working (held, quivering, to 0.55), then the neck whips forward and down and the venom flies at 0.62; it follows
    through, the frill stays up a moment and folds."""
    H = 0.62
    draw = track(u, [(0, 0), (0.3, 1), (0.55, 1), (H, -1), (0.75, -0.7), (1, 0)])
    fr = track(u, [(0, 0), (0.22, 1), (0.85, 1), (1, 0)])
    quiver = track(u, [(0, 0), (0.3, 1), (0.55, 1), (0.6, 0), (1, 0)])
    dy = track(u, [(0, 0), (0.3, -0.08), (0.55, -0.1), (H, 0.12), (0.8, 0.08), (1, 0)])
    pitch = 6 * max(0.0, draw) - 8 * max(0.0, -draw)
    return {
        "body": {"dy": dy, "dz": track(u, [(0, 0), (0.3, -0.03), (H, -0.06), (1, 0)]), "pitch": pitch},
        "turns": merge({
            "Chest": (-3 * draw, 0, 0), "Neck1": (16 * draw, 0, 0), "Neck2": (12 * draw, 0, 0),
            "Head": (10 * draw + 2.5 * wave(u, 13) * quiver, 0, 0),
            "Arm.L": (-15 * fr, 0, 0), "Arm.R": (-15 * fr, 0, 0),
        }, tail_set(-0.3 * pitch - 1.5 * quiver), tail_wave(u, 4.0, 0.0, cycles=2, env=quiver)),
        "jaw": track(u, [(0, 1), (0.25, 18), (0.5, 30), (H, 38), (0.75, 24), (0.95, 2), (1, 1)]),
        "frill": fr,
        "frill_shiver": 0.05 * quiver,
        "feet": PLANT,
    }


def pounce(u):
    """Leaping slash, 1.0 s (anim_events pounce: airborne 0.2-0.65, hit 0.7; the game carries the body on the arc):
    a deep crouch, launch, in the air the legs tuck then swing forward with the toes up so both sickle claws lead,
    frill wide and jaws open; it lands feet-first ahead of itself and both feet rake down on the prey at 0.7, then it
    steps back onto its prints and recovers."""
    crouch = track(u, [(0, 0), (0.15, 1), (0.22, 0.2), (0.62, 0.2), (0.75, 1), (0.9, 0.4), (1, 0)])
    air = track(u, [(0, 0), (0.18, 0), (0.26, 1), (0.56, 1), (0.64, 0), (1, 0)])
    reach = track(u, [(0, 0), (0.32, 0), (0.48, 1), (1, 1)])
    pitch = track(u, [(0, 0), (0.15, -6), (0.25, 4), (0.5, 12), (0.68, -6), (0.8, -6), (1, 0)])
    p = {
        "body": {"dz": -0.16 * crouch * (1 - air), "pitch": pitch},
        "turns": merge({
            "Chest": (-0.3 * pitch, 0, 0), "Neck1": (6 * air - 10 * crouch * (1 - air), 0, 0), "Neck2": (-0.4 * pitch, 0, 0), "Head": (-0.5 * pitch, 0, 0),
            "Arm.L": (-35 * air, 0, 0), "Arm.R": (-35 * air, 0, 0), "Forearm.L": (-25 * air, 0, 0), "Forearm.R": (-25 * air, 0, 0),
        }, tail_set(-pitch * 0.25 - 2 * air)),
        "jaw": track(u, [(0, 1), (0.2, 12), (0.5, 32), (0.7, 36), (0.8, 10), (1, 1)]),
        "frill": track(u, [(0, 0.5), (0.15, 1), (0.85, 1), (1, 0)]),
    }
    if 0.2 < u < 0.64:
        # in flight, free legs: tucked on take-off (thigh up, shin folded), then thrown forward toes-up for the rake
        tuck, rk = (1 - reach) * air, reach * air
        p["feet"] = {"L": None, "R": None}
        p["legs"] = {sd: (35 * tuck + 55 * rk, -80 * tuck - 20 * rk, 50 * tuck + 5 * rk, 30 * tuck - 30 * rk) for sd in "LR"}
    else:
        # on the ground: planted for the launch; on landing both feet strike ahead of the body (the rake) and walk back
        fwd = track(u, [(0, 0), (0.64, 0.75), (0.7, 0.7), (0.78, 0.65), (0.86, 0.3), (0.95, 0), (1, 0)])
        lift = max(0.0, track(u, [(0, 0), (0.64, 0.22), (0.7, 0.0), (0.78, 0.0), (0.82, 0.1), (0.9, 0.08), (0.95, 0), (1, 0)]))
        heel = track(u, [(0, 0), (0.64, -30), (0.7, -8), (0.8, 0), (1, 0)])
        stag = track(u, [(0, 0), (0.78, 0), (0.86, 0.12), (1, 0)])  # the right foot steps back a beat after the left
        p["feet"] = {"L": (lift, fwd, 0, heel), "R": (max(lift, stag), fwd + 0.05, 0, heel)}
    return p


def hit_react(u):
    """0.6 s: the head and chest jerk back and up from the blow, the frill flicks half open, a stagger step back."""
    j = track(u, [(0, 0), (0.15, 1), (0.45, 0.7), (1, 0)])
    lf = track(u, [(0, 0), (0.1, 0), (0.36, -0.16), (0.62, -0.16), (0.9, 0), (1, 0)])
    ll = max(0.0, track(u, [(0, 0), (0.06, 0), (0.22, 0.14), (0.38, 0), (0.6, 0), (0.75, 0.12), (0.92, 0), (1, 0)]))
    return {
        "body": {"dy": -0.08 * j, "pitch": 8 * j, "roll": -3 * j, "dz": -0.02 * j},
        "turns": merge({"Neck1": (14 * j, 6 * j, 0), "Neck2": (8 * j, 0, 0), "Head": (12 * j, 0, -10 * j)}, tail_set(-6 * j)),
        "jaw": 18 * j,
        "frill": 0.5 * track(u, [(0, 0), (0.12, 1), (0.5, 0.6), (1, 0)]),
        "feet": {"L": (ll, lf, 0, 0), "R": (0, 0, 0, 0)},
    }


FOLD = {"L": (38, -70, 62, 30), "R": (38, -70, 62, 30)}  # thigh, shin, metatarsal, toe: a bird sitting on its hocks
LIMP = {"L": (22, -40, 34, 20), "R": (30, -50, 40, 24)}  # fallen: legs half folded, the upper (left) one looser


def collapse(u, end_roll, head_drop, hold_from):
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
    """2.1 s: the knees buckle, the frill flares in alarm then sags, it topples onto its right side and lies there."""
    p = collapse(u, 82, 20, 0.45)
    p["jaw"] = track(u, [(0, 1), (0.3, 18), (0.5, 6), (1, 4)])
    p["frill"] = track(u, [(0, 0), (0.15, 0.7), (0.5, 0.3), (1, 0.15)])
    return p


def death(u):
    """1.8 s: a last stagger, a heavy fall onto the right side, the neck and tail going slack, the frill half spread."""
    p = collapse(u, 88, 34, 0.5)
    p["jaw"] = track(u, [(0, 1), (0.3, 22), (0.6, 10), (1, 8)])
    p["frill"] = track(u, [(0, 0), (0.2, 0.6), (0.6, 0.35), (1, 0.3)])
    return p


def sleep(u):
    """2.0 s, held on the last frame: settles belly-down onto folded legs, chin to the ground, tail curled round."""
    c = track(u, [(0, 0), (0.75, 1), (1, 1)])
    buckle = track(u, [(0, 0), (0.6, 1), (1, 1)])
    return {
        "body": {"pitch": -3 * c},
        "turns": merge({"Neck1": (-26 * c, 14 * c, 0), "Neck2": (-14 * c, 12 * c, 0), "Head": (8 * c, 8 * c, 4 * c),
                        "Arm.L": (-25 * c, 0, 0), "Arm.R": (-25 * c, 0, 0)}, tail_set(5 * c, 9 * c, 0.97)),
        "jaw": 0.5,
        "frill": 0.0,
        "feet": {"L": None, "R": None},
        "legs": {sd: tuple(v * buckle for v in FOLD[sd]) for sd in "LR"},
        "rest_on_floor": True,
    }


def feed(u):
    """2.0 s loop: head down on the carcass, jaws tearing, a hard yank back and up, swallow."""
    d = 0.5 - 0.5 * math.cos(2 * math.pi * u)
    d = 0.75 + 0.25 * (1 - d)
    yank = max(0.0, wave(u, 2, 0.1)) ** 2
    return {
        "body": {"pitch": -14 * d + 4 * yank, "dz": -0.05 * d, "dy": 0.02 * d - 0.03 * yank},
        "turns": merge({"Chest": (-6 * d, 0, 0), "Neck1": (-24 * d + 10 * yank, 5 * wave(u, 1), 0), "Neck2": (-14 * d + 4 * yank, 0, 0),
                        "Head": (-12 * d + 8 * yank, 0, 8 * yank * wave(u, 1, 0.2))},
                       tail_set(10 * d), tail_wave(u, 3.0, 0.0)),
        "jaw": 3 + 16 * max(0.0, wave(u, 4)),
        "frill": 0.0,
        "feet": PLANT,
    }


CLIPS = {"idle": (idle, 60, True), "alert": (alert, 38, False), "attack_primary": (attack_primary, 22, False),
         "attack_heavy": (attack_heavy, 38, False), "spit": (spit, 34, False), "pounce": (pounce, 24, False),
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
print(f"DILOMOVE {CLIP} {N} frames ({N / FPS:.3f} s)")

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
