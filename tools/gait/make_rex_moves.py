"""Author the T. rex's exaggerated one-shots and idle on its 30-bone rig (Hips/Spine1/Chest/Neck1/Neck2/Head/Jaw,
Thigh/Shin/Metatarsal/Toe, Tail1-7), in place, feet IK-planted on their prints.

Owner 2026-10-30: "T rex needs better and more exaggerated animations. I also want it to look more intimidating."
References (Durango: Wild Lands): head held low and forward, body near horizontal in the lunge, jaws wide, tail
whipping; Tarbosaurus card: low stalking carriage, head level with the back.

Every clip starts and ends on STALK, the same carriage the walk/run hold (tools/gait/tyrannosaurus.json "hold" and
"lean_deg"), so crossfades between idle, gaits and attacks never pop the head up. Poses are keyed as channel tracks
of (u, value) keys eased with smoothstep between keys (holds at keys, snaps where keys sit close). Hit frames match
game/data/creatures/anim_events.json: attack_primary 0.42, attack_heavy 0.72, tail_swipe the default 0.55.

usage: Blender -b -P tools/gait/make_rex_moves.py -- <base.glb> <clip> <out.glb> [--v2]
  clip: idle | alert | attack_primary | attack_heavy | tail_swipe | bite_shake | hit_react | feed | knockdown | death | sleep | pin_foot

--v2: the MegaRex (SP-TYRANNOSAURUS v2 open-mouth mesh; the regular T. rex keeps the v1 numbers). bite_shake (signature), hit_react, feed and the lying clips (knockdown, death,
sleep) are authored here too. Lying clips go down on the belly with the feet planted and "settle" the skin onto the
floor every frame (the lowest evaluated vertex is put at z 0), so nothing sinks or hovers. The v2 mesh is bound with
the jaw shut and was modelled ~24 deg open, so with --v2 every jaw key is scaled by JAW (0.7): the widest roar stays inside
the modelled gape instead of stretching the lips.
"""
import math
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, CLIP, OUT = argv[:3]
FPS = 24
FWD, UP = Vector((0, 1, 0)), Vector((0, 0, 1))
SIDE = FWD.cross(UP).normalized()  # (1, 0, 0): the animal's right
TAILS = ["Tail%d" % i for i in range(1, 8)]

# The stalking carriage (degrees; pitch + = nose up / tail down). Mirrored in tyrannosaurus.json walk/run "hold".
LEAN = 5.0  # whole body tipped nose-down about the hips
STALK = {"Chest": -2.0, "Neck1": -12.0, "Neck2": -5.0, "Head": 10.0, "Tail1": 3.0, "Tail2": 2.0}
V2 = "--v2" in sys.argv
JAW = 0.7 if V2 else 1.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
pbs, bones = arm.pose.bones, arm.data.bones
_shapes = {pb.custom_shape for pb in pbs if pb.custom_shape}
SKIN = max((o for o in bpy.data.objects if o.type == "MESH" and o not in _shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))


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
    if deg:
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
    set_m(up, pbs[up].matrix)
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


def apply(p):
    """p: body {dx, dy, dz, pitch, roll, yaw}, turns {bone: (pitch, yaw, roll)}, jaw, feet {L/R: (lift, fwd, side, heel)}."""
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    b = p.get("body", {})
    pitch = b.get("pitch", 0.0) - LEAN
    m = Matrix.Translation(SIDE * b.get("dx", 0.0) + FWD * b.get("dy", 0.0) + UP * b.get("dz", 0.0)) \
        @ rot_about(PIVOT, UP, math.radians(b.get("yaw", 0.0))) \
        @ rot_about(PIVOT, SIDE, math.radians(pitch)) @ rot_about(PIVOT, FWD, math.radians(b.get("roll", 0.0))) \
        @ bones["Hips"].matrix_local
    set_m("Hips", m)
    turns = p.get("turns", {})
    order = ["Spine1", "Spine2", "Chest", "Neck1", "Neck2", "Head"] + TAILS + ["Arm.L", "Arm.R", "Forearm.L", "Forearm.R"]
    for name in order:
        tp, ty, tr = turns.get(name, (0.0, 0.0, 0.0))
        tp += STALK.get(name, 0.0)
        turn(name, UP, ty)
        turn(name, SIDE, tp)
        turn(name, FWD, tr)
    jb = pbs["Jaw"]
    cur = jb.matrix.copy()
    set_m("Jaw", rot_about(cur.translation, cur.to_3x3().col[0].normalized(), math.radians(JAW * p.get("jaw", 0.0))) @ cur)
    for sd, leg in LEGS.items():
        lift, fwd, side, heel = p.get("feet", {}).get(sd, (0.0, 0.0, 0.0, 0.0))
        ball = leg["ball0"] + FWD * fwd + SIDE * side
        r = rot_about(ball, -SIDE, math.radians(heel))  # + = heel up / toe down, pivoting on the ball of the foot
        ankle = r @ (leg["ankle0"] + FWD * fwd + SIDE * side) + UP * lift
        got = solve_leg(leg, ankle)
        fm = Matrix.Rotation(math.radians(heel), 4, -SIDE) @ bones[leg["foot"]].matrix_local
        fm.translation = got
        set_m(leg["foot"], fm)
        if lift > 0.05:
            turn("Toe." + sd, SIDE, -min(12.0, lift * 12))  # toes hang while the foot is up
        else:  # toes stay flat on the ground while the heel peels, or their claws would dig in
            tm = bones["Toe." + sd].matrix_local.copy()
            tm.translation = pbs[leg["foot"]].tail
            set_m("Toe." + sd, tm)
    settle = p.get("settle", 0.0)
    if settle > 0:  # put the lowest skin on the floor (lying clips): no sinking, no hovering
        ev = SKIN.evaluated_get(bpy.context.evaluated_depsgraph_get())
        me = ev.to_mesh()
        lo = min((SKIN.matrix_world @ v.co).z for v in me.vertices)
        ev.to_mesh_clear()
        m = pbs["Hips"].matrix.copy()
        m.translation.z -= settle * lo
        set_m("Hips", m)


def tail_wave(u, amp_yaw, amp_pitch, delay=0.06, cycles=1.0, phase=0.0, env=1.0):
    """Travelling wave down the tail (each segment lags the one before). Periodic in u when cycles is whole."""
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


# ---------------------------------------------------------------------------------------------------- clips

def idle(u):
    """4 s loop: two heavy breaths (chest heaves, belly sags, jaw parts on the exhale), weight rolling from foot to
    foot, a slow look left and right with the head low, tail swaying like a heavy rope."""
    br = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * u)  # 0..1, two breaths
    sway = wave(u, 1)
    look = wave(u, 1, 0.15)
    return {
        "body": {"dz": -0.10 * br, "dx": 0.18 * sway, "roll": 1.6 * sway, "pitch": 1.2 * br, "yaw": 2.0 * look},
        "turns": merge({
            "Spine2": (1.0 * br, 0, 0), "Chest": (2.5 * br, 0, 0),
            "Neck1": (-2.0 * br, 5.0 * look, -1.6 * sway), "Neck2": (-1.0 * br, 4.0 * look, 0), "Head": (1.5 * br, 3.0 * look, 2.0 * look),
            "Arm.L": (6 * br, 0, 0), "Arm.R": (6 * br, 0, 0),
        }, tail_wave(u, 4.0, 1.2, delay=0.05, cycles=1, phase=0.1)),
        "jaw": 2.0 + 7.0 * smooth((br - 0.6) / 0.4),
        "feet": {"L": (0, 0, 0, 3.0 * max(0.0, sway)), "R": (0, 0, 0, 3.0 * max(0.0, -sway))},
    }


def alert(u):
    """Roar, 2.4 s: drop the head and load the chest, then heave up and throw the head skyward with the jaws wide,
    hold the bellow with the head shaking, tail lashing, then settle back to the stalk."""
    dz = track(u, [(0, 0), (0.12, -0.5), (0.30, -0.58), (0.40, 0.25), (0.78, 0.15), (1, 0)]) if V2 else \
        track(u, [(0, 0), (0.12, -0.55), (0.30, -0.65), (0.40, 0.25), (0.78, 0.15), (1, 0)])
    pitch = track(u, [(0, 0), (0.12, -6), (0.30, -8), (0.40, 9), (0.78, 7), (1, 0)])
    n1 = track(u, [(0, 0), (0.12, -15), (0.30, -18), (0.42, 26), (0.78, 22), (1, 0)]) if V2 else \
        track(u, [(0, 0), (0.12, -18), (0.30, -22), (0.42, 26), (0.78, 22), (1, 0)])  # v2 skull: the chin hangs lower
    n2 = track(u, [(0, 0), (0.12, -8), (0.30, -10), (0.42, 14), (0.78, 12), (1, 0)])
    hd = track(u, [(0, 0), (0.12, -6), (0.30, -10), (0.42, 12), (0.78, 8), (1, 0)])
    jaw = track(u, [(0, 2), (0.30, 4), (0.40, 46), (0.78, 44), (0.92, 4), (1, 2)])
    shake = track(u, [(0, 0), (0.42, 0), (0.48, 1), (0.74, 1), (0.82, 0), (1, 0)])
    heave = track(u, [(0, 0), (0.30, -4), (0.42, 6), (0.78, 5), (1, 0)])
    arms = track(u, [(0, 0), (0.3, -10), (0.42, 28), (0.78, 24), (1, 0)])
    tail_lift = track(u, [(0, 0), (0.3, 8), (0.42, -4), (0.8, -4), (1, 0)])
    lash = track(u, [(0, 0), (0.36, 0), (0.45, 1), (0.8, 1), (0.95, 0), (1, 0)])
    tw = tail_wave(u, 9.0, 0.0, delay=0.03, cycles=3, env=lash)
    return {
        "body": {"dz": dz, "pitch": pitch, "roll": 1.5 * shake * wave(u, 7)},
        "turns": merge({
            "Spine2": (heave * 0.5, 0, 0), "Chest": (heave, 0, 0),
            "Neck1": (n1, 7 * shake * wave(u, 6), 0), "Neck2": (n2, 5 * shake * wave(u, 6, 0.1), 0),
            "Head": (hd, 3 * shake * wave(u, 6, 0.2), 6 * shake * wave(u, 6, 0.15)),
            "Arm.L": (arms, 0, 0), "Arm.R": (arms, 0, 0), "Forearm.L": (arms * 0.6, 0, 0), "Forearm.R": (arms * 0.6, 0, 0),
            "Tail1": (-tail_lift, 0, 0), "Tail2": (-tail_lift * 0.6, 0, 0), "Tail3": (-tail_lift * 0.4, 0, 0),
        }, tw),
        "jaw": jaw + 3 * shake * wave(u, 9),
        "feet": {"L": (0, 0, 0, 0), "R": (0, 0, 0, 0)},
    }


def attack_primary(u):
    """Lunge bite, 1.667 s, hit at 0.42: rock back with the jaws gaping, then throw the whole body forward and low,
    nearly horizontal, the right foot stepping out to carry it, snap shut on the hit, wrench the head, recoil and
    step back onto the print."""
    H = 0.42
    dy = track(u, [(0, 0), (0.22, -0.55), (0.32, -0.6), (H, 1.3), (0.55, 1.2), (0.78, 0.35), (1, 0)])
    dz = track(u, [(0, 0), (0.22, 0.15), (0.32, 0.12), (H, -0.85), (0.55, -0.75), (0.80, -0.1), (1, 0)])
    pitch = track(u, [(0, 0), (0.22, 8), (0.32, 9), (H, -10), (0.55, -8), (0.8, -1), (1, 0)])
    n1 = track(u, [(0, 0), (0.22, 16), (0.32, 18), (H, -2), (0.5, -6), (0.8, 0), (1, 0)])
    n2 = track(u, [(0, 0), (0.22, 8), (0.32, 8), (H, 4), (0.8, 0), (1, 0)])
    hd = track(u, [(0, 0), (0.22, 6), (0.32, 8), (H, -6), (0.5, -2), (1, 0)])
    jaw = track(u, [(0, 2), (0.2, 34), (0.36, 50), (0.385, 50), (H, -3), (0.5, 0), (0.62, 10), (0.8, 3), (1, 2)])
    wrench = track(u, [(0, 0), (H, 0), (0.48, 1), (0.56, -1), (0.66, 0.6), (0.76, 0), (1, 0)])
    tail_lift = track(u, [(0, 0), (0.25, -6), (H, 12), (0.6, 8), (1, 0)])
    tail_whip = track(u, [(0, 0), (0.3, -1), (H, 1), (0.56, -0.6), (0.75, 0.3), (1, 0)])
    arms = track(u, [(0, 0), (0.3, -12), (H, 30), (0.6, 20), (1, 0)])
    # right foot steps forward under the lunge, lands just before the bite, steps back in the recovery
    rf = track(u, [(0, 0), (0.24, 0), (0.38, 1.7), (0.72, 1.7), (0.92, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.24, 0), (0.31, 0.75), (0.38, 0), (0.72, 0), (0.82, 0.6), (0.92, 0), (1, 0)]))
    return {
        "body": {"dy": dy, "dz": dz, "pitch": pitch, "yaw": -2 * wrench, "roll": -1 * wrench},
        "turns": {
            "Spine1": (pitch * -0.15, 0, 0), "Chest": (pitch * -0.2, 0, 0),
            "Neck1": (n1, 13 * wrench, 0), "Neck2": (n2, 10 * wrench, 0), "Head": (hd, 6 * wrench, 14 * wrench),
            "Arm.L": (arms, 0, 0), "Arm.R": (arms, 0, 0), "Forearm.L": (arms * 0.5, 0, 0), "Forearm.R": (arms * 0.5, 0, 0),
            **{t: (-tail_lift * (0.5 if i < 2 else 0.3), 7 * tail_whip * (0.5 + 0.12 * i), 0) for i, t in enumerate(TAILS)},
        },
        "jaw": jaw,
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def attack_heavy(u):
    """Stomp, 1.667 s, hit at 0.72: shift onto the left leg and rear back, the right foot hauled high and held (the
    telegraph), then slammed down ahead with the whole body dropping behind it, head and jaws driving down with
    the impact, a heavy bounce, and a step back onto the print."""
    H = 0.72
    dx = track(u, [(0, 0), (0.2, -0.45), (0.6, -0.5), (H, -0.1), (0.85, 0), (1, 0)])
    dy = track(u, [(0, 0), (0.2, -0.3), (0.6, -0.4), (H, 0.9), (0.85, 0.8), (1, 0)])
    dz = track(u, [(0, 0), (0.2, 0.1), (0.6, 0.15), (H, -0.75), (0.77, -0.55), (0.82, -0.65), (0.92, -0.1), (1, 0)])
    pitch = track(u, [(0, 0), (0.25, 16), (0.6, 18), (H, -9), (0.8, -6), (1, 0)])
    roll = track(u, [(0, 0), (0.2, -5), (0.6, -6), (H, 2), (0.85, 0), (1, 0)])
    n1 = track(u, [(0, 0), (0.25, 10), (0.6, 12), (H, -20), (0.8, -14), (1, 0)])
    hd = track(u, [(0, 0), (0.25, 4), (0.6, 6), (H, -10), (0.8, -6), (1, 0)])
    jaw = track(u, [(0, 2), (0.3, 18), (0.6, 22), (0.68, 38), (0.85, 30), (0.95, 4), (1, 2)])
    shudder = track(u, [(0, 0), (H, 0), (0.74, 1), (0.84, 0), (1, 0)])
    lift = max(0.0, track(u, [(0, 0), (0.15, 0), (0.42, 2.4), (0.6, 2.5), (0.69, 0.6), (H, 0), (0.86, 0), (0.92, 0.35), (0.98, 0), (1, 0)]))
    fwd = track(u, [(0, 0), (0.15, 0), (0.42, 0.6), (0.6, 0.7), (H, 1.2), (0.86, 1.2), (0.98, 0), (1, 0)])
    tail_lift = track(u, [(0, 0), (0.25, 14), (0.6, 16), (H, 14), (0.85, 4), (1, 0)])
    arms = track(u, [(0, 0), (0.6, 22), (H, -10), (1, 0)])
    return {
        "body": {"dx": dx, "dy": dy, "dz": dz + 0.05 * shudder * wave(u, 14), "pitch": pitch, "roll": roll},
        "turns": {
            "Chest": (pitch * -0.15, 0, 0), "Neck1": (n1, 0, 0), "Neck2": (n1 * 0.4, 0, 0), "Head": (hd, 0, 3 * shudder * wave(u, 12)),
            "Arm.L": (arms, 0, 0), "Arm.R": (arms, 0, 0),
            **{t: (-tail_lift * (0.45 if i < 3 else 0.25), 0, 0) for i, t in enumerate(TAILS)},
        },
        "jaw": jaw,
        "feet": {"L": (0, 0, 0, 0), "R": (lift, fwd, 0.15 * smooth(lift), 16 * smooth(lift / 1.5))},
    }


def tail_swipe(u):
    """Tail whip, 2 s, hit at 0.55: wind the hips to the right and look back over the left shoulder, then unwind
    hard to the left so the tail cracks across behind, the wave running out to the tip, and swing back."""
    H = 0.55  # anim_events.json default_hit_frac (no tail_swipe row)
    yaw = track(u, [(0, 0), (0.3, -22), (0.36, -24), (H, 26), (0.64, 22), (0.85, -4), (1, 0)])
    dz = track(u, [(0, 0), (0.3, -0.35), (H, -0.5), (0.7, -0.3), (1, 0)])
    roll = track(u, [(0, 0), (0.3, -4), (H, 6), (0.7, 3), (1, 0)])
    look = track(u, [(0, 0), (0.3, 30), (0.4, 32), (H, 10), (0.7, -8), (1, 0)])
    jaw = track(u, [(0, 2), (0.3, 20), (0.45, 26), (0.6, 8), (1, 2)])
    swing = {}
    for i, t in enumerate(TAILS):
        lag = 0.025 * i
        a = track(u, [(0, 0), (0.28 + lag, -11), (0.36 + lag, -12), (H + lag, 14), (0.62 + lag, 9), (0.86 + lag, -2), (1, 0)])
        swing[t] = (-3 if i == 0 else 0, a, 0)  # pitch on a sideways-bent tail rolls it into a scorpion curl
    return {
        "body": {"yaw": yaw, "dz": dz, "roll": roll},
        "turns": {
            **swing,
            "Spine1": (0, -yaw * 0.12, 0), "Chest": (0, -yaw * 0.15, 0),
            "Neck1": (-4, look * 0.5, 0), "Neck2": (0, look * 0.3, 0), "Head": (2, look * 0.3, look * 0.2),
        },
        "jaw": jaw,
        "feet": {"L": (0, 0, 0, 0), "R": (0, 0, 0, 0)},
    }


def bite_shake(u):
    """Signature: bite and shake, 2.5 s, clamp at 0.30. A short lunge with the jaws wide, they clamp on the hit, then
    she plants both feet and thrashes the head side to side (the whole neck, the shoulders rolling with it) four
    times, wrenches up and flings the catch to her left, jaws opening on the release, and settles back."""
    H = 0.30
    dy = track(u, [(0, 0), (0.14, -0.35), (0.2, -0.4), (H, 0.9), (0.72, 0.75), (0.82, 0.3), (1, 0)])
    dz = track(u, [(0, 0), (0.14, 0.1), (H, -0.55), (0.7, -0.45), (0.8, 0.1), (0.9, 0), (1, 0)])
    pitch = track(u, [(0, 0), (0.14, 7), (0.2, 8), (H, -7), (0.7, -5), (0.8, 6), (0.9, 1), (1, 0)])
    n1 = track(u, [(0, 0), (0.14, 14), (0.2, 16), (H, -4), (0.7, -4), (0.78, 22), (0.88, 4), (1, 0)])
    hd = track(u, [(0, 0), (0.2, 6), (H, -5), (0.7, -3), (0.78, 12), (1, 0)])
    jaw = track(u, [(0, 2), (0.12, 30), (0.24, 48), (0.27, 48), (H, -2), (0.72, -2), (0.78, 36), (0.9, 6), (1, 2)])
    env = track(u, [(0, 0), (0.32, 0), (0.36, 1), (0.66, 1), (0.72, 0), (1, 0)])
    sh = env * wave(u, 6.5, 0.0)  # four thrashes across the hold
    fling = track(u, [(0, 0), (0.7, 0), (0.78, 1), (0.88, 0.3), (1, 0)])
    tail = env * wave(u, 6.5, 0.45)
    arms = track(u, [(0, 0), (0.2, -10), (H, 26), (0.7, 22), (1, 0)])
    rf = track(u, [(0, 0), (0.12, 0), (0.24, 1.2), (0.82, 1.2), (0.95, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.12, 0), (0.18, 0.6), (0.24, 0), (0.82, 0), (0.88, 0.5), (0.95, 0), (1, 0)]))
    return {
        "body": {"dy": dy, "dz": dz, "pitch": pitch, "yaw": 6 * sh - 8 * fling, "roll": 4 * sh},
        "turns": {
            "Spine2": (0, 4 * sh, 0), "Chest": (pitch * -0.2, 8 * sh, 3 * sh),
            "Neck1": (n1, 20 * sh - 18 * fling, 6 * sh), "Neck2": (n1 * 0.4, 14 * sh - 10 * fling, 0),
            "Head": (hd, 10 * sh - 8 * fling, 18 * sh + 10 * fling),
            "Arm.L": (arms, 0, 0), "Arm.R": (arms, 0, 0), "Forearm.L": (arms * 0.5, 0, 0), "Forearm.R": (arms * 0.5, 0, 0),
            **{t: (-6 * env if i < 2 else -2 * env, -12 * tail * (0.5 + 0.12 * i) + 10 * fling, 0) for i, t in enumerate(TAILS)},
        },
        "jaw": jaw,
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def hit_react(u):
    """0.75 s flinch: the body jolts back and up off the blow, the head snaps up and away with a bellow, tail
    lifts, and she drops back onto the stalk. Feet stay planted."""
    k = track(u, [(0, 0), (0.18, 1), (0.45, 0.7), (1, 0)])
    return {
        "body": {"dy": -0.45 * k, "dz": 0.12 * k, "pitch": 7 * k, "roll": -3 * k, "yaw": 4 * k},
        "turns": merge({"Chest": (3 * k, 0, 0), "Neck1": (14 * k, -10 * k, 0), "Neck2": (6 * k, -6 * k, 0), "Head": (8 * k, -6 * k, -8 * k),
                        "Arm.L": (20 * k, 0, 0), "Arm.R": (20 * k, 0, 0)},
                       {t: (-8 * k * (0.6 + 0.1 * i), 0, 0) for i, t in enumerate(TAILS)}),
        "jaw": 2 + 34 * track(u, [(0, 0), (0.15, 1), (0.6, 0.8), (1, 0)]),
        "feet": {"L": (0, 0, 0, 0), "R": (0, 0, 0, 0)},
    }


def feed(u):
    """4 s: reach the head down to a carcass at her feet, clamp, tug back twice with the legs braced (the neck
    stretching, a shake on the second tug), then lift the head and gulp twice, jaw working."""
    down = track(u, [(0, 0), (0.15, 1), (0.6, 1), (0.72, 0.15), (1, 0)])
    tug = track(u, [(0, 0), (0.2, 0), (0.28, 1), (0.34, 0.2), (0.42, 1), (0.5, 0.3), (0.6, 0), (1, 0)])
    shake = track(u, [(0, 0), (0.4, 0), (0.43, 1), (0.52, 1), (0.56, 0), (1, 0)]) * wave(u, 12)
    gulp = track(u, [(0, 0), (0.68, 0), (0.74, 1), (0.8, 0), (0.86, 1), (0.92, 0), (1, 0)])
    jaw = track(u, [(0, 2), (0.12, 30), (0.17, 2), (0.6, 2), (0.66, 18), (0.7, 4), (0.76, 20), (0.82, 4), (0.88, 18), (0.94, 3), (1, 2)])
    return {
        "body": {"dy": 0.3 * down - 0.35 * tug, "dz": -0.38 * down, "pitch": -10 * down + 3 * tug},
        "turns": {"Spine2": (-3 * down, 0, 0), "Chest": (-6 * down, 0, 0),
                  "Neck1": (-20 * down + 10 * tug + 12 * gulp, 8 * shake, 0), "Neck2": (-14 * down + 4 * tug, 6 * shake, 0),
                  "Head": (-8 * down - 6 * tug - 6 * gulp, 4 * shake, 10 * shake),
                  "Tail1": (8 * down, 0, 0), "Tail2": (4 * down, 0, 0), "Tail3": (2 * down, 0, 0)},
        "jaw": jaw,
        "feet": {"L": (0, 0, 0, 0), "R": (0, 0, 0, 0)},
    }


def _belly_lie(k, roll=0.0, breath=0.0):
    """Down on her belly, k = 0 (standing) .. 1 (down): the body dropped 3 m onto its belly and chest, legs folded
    under with the feet flat on their soles, the chin laid on the ground and the tail along it. A rex is too
    tall and its legs too long to lie on its side without the thighs tearing, so it goes down sternal, the way birds
    and big theropod mounts are shown resting; roll tips it onto its right flank (death)."""
    return {
        "body": {"dz": -2.5 * k, "pitch": -2 * k + 1.0 * breath, "roll": roll},
        "turns": merge({"Spine2": (1.2 * breath, 0, 0), "Chest": (2.0 * breath, 0, 0),
                        "Neck1": (-3 * k, 0, -roll * 0.3), "Neck2": (-2 * k, 0, 0), "Head": (2 * k, 0, -roll * 0.4),
                        "Arm.L": (30 * k, 0, 0), "Arm.R": (30 * k, 0, 0)},
                       {t: (6 * k if i < 2 else 2 * k, 0, 0) for i, t in enumerate(TAILS)}),
        "feet": {"L": (0, 0.6 * k, 0, -8 * k), "R": (0, 0.6 * k, 0, -8 * k)},  # the foot stays on its sole; more heel-down about the ball buries the heel pad
        "settle": 1.0,
    }


def knockdown(u):
    """3.2 s: staggers back a step, the legs buckle and she crashes onto her belly and chest (a bounce, the head
    slamming down), lies heaving, then shoves herself back up onto her feet."""
    k = track(u, [(0, 0), (0.1, 0), (0.24, 1.05), (0.29, 0.92), (0.34, 1), (0.66, 1), (0.9, 0), (1, 0)])
    st = track(u, [(0, 0), (0.1, 1), (0.26, 0), (1, 0)])
    breath = 0.5 - 0.5 * math.cos(2 * math.pi * 3 * u) if 0.34 < u < 0.66 else 0.0
    p = _belly_lie(k, track(u, [(0, 0), (0.24, 8), (0.66, 6), (0.9, 0), (1, 0)]), breath)
    p["body"]["dy"] = -0.5 * st
    p["body"]["pitch"] += 8 * st
    p["feet"]["R"] = (0.5 * smooth(st) * (1 - st) * 4, p["feet"]["R"][1] - 0.5 * st, 0, p["feet"]["R"][3])
    p["feet"]["L"] = (0, p["feet"]["L"][1] - 0.5 * st, 0, p["feet"]["L"][3])
    p["jaw"] = 2 + 30 * track(u, [(0, 0), (0.2, 1), (0.28, 0.1), (0.4, 0.6), (0.6, 0.1), (0.78, 0.7), (0.92, 0), (1, 0)])
    return p


def death(u):
    """3 s: a last bellow and stagger, the legs buckle and she crashes onto her belly, then sags over onto her right
    flank with a final shudder and breath and goes still: jaw slack, tail flat. The game holds the last frame."""
    k = track(u, [(0, 0), (0.14, 0), (0.36, 1), (1, 1)])
    st = track(u, [(0, 0), (0.14, 1), (0.36, 0), (1, 0)])
    roll = track(u, [(0, 0), (0.36, 6), (0.62, 30), (1, 30)])
    breath = track(u, [(0, 0), (0.6, 0), (0.7, 1), (0.85, 0), (1, 0)])
    p = _belly_lie(k, roll, breath)
    p["body"]["dy"] = -0.4 * st
    p["body"]["pitch"] += 10 * st
    p["feet"]["R"] = (0.4 * smooth(st) * (1 - st) * 4, p["feet"]["R"][1] - 0.4 * st, 0, p["feet"]["R"][3])
    p["feet"]["L"] = (0, p["feet"]["L"][1] - 0.4 * st, 0, p["feet"]["L"][3])
    p["turns"] = merge(p["turns"], {"Neck1": (18 * st, 0, 0), "Head": (10 * st, 0, 0)})
    p["jaw"] = track(u, [(0, 2), (0.12, 40), (0.3, 30), (0.45, 10), (0.7, 16), (1, 14)])
    return p


def sleep(u):
    """6 s loop: belly-down with the legs folded under, the head laid on the ground turned a little aside, slow deep
    breaths (chest and belly), jaw just parted."""
    br = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * u)
    p = _belly_lie(1.0, 3.0, br)
    p["turns"] = merge(p["turns"], {"Neck1": (0, -14, 0), "Neck2": (0, -12, 0), "Head": (0, -8, -10)},
                       {t: (0, -3 * (i + 1), 0) for i, t in enumerate(TAILS)})
    p["jaw"] = 2 + 3 * br
    return p


def pin_foot(u):
    """Foot pin, 4 s, held on its last frame (PINFEEL, owner 2026-10-30: "the trex ... physically pinned the target
    with a foot"). Starts on the stomp's impact frame (attack_heavy at its 0.72 hit), so the brain can cut to it
    the moment the stomp lands and Pinned is applied. The right foot rises off the ground and comes down on the
    victim's chest (ball of the foot PIN_LIFT up, PIN_FWD ahead, toward the midline, toes curled down), she crouches
    over it with the body tipped nose-down, neck curled and the head low over the victim, then holds: two growling
    breaths, small head shakes, the tail up for balance. The game slides the victim's chest under the claws (PinHold)."""
    E = 0.15  # the plant: 0.6 s
    s = attack_heavy(0.72)  # the stomp's impact pose: the first frame
    b0, t0 = s["body"], s["turns"]
    br = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * max(0.0, (u - E) / (1 - E)))  # two breaths over the hold
    hold = smooth((u - E * 0.4) / (E * 0.6))
    shake = wave(u, 9) * smooth((u - E) / 0.1) * (0.6 + 0.4 * br)

    def mix(a, b):
        return a + (b - a) * smooth(u / E)
    body = {"dx": mix(b0["dx"], 0.0), "dy": mix(b0["dy"], 0.55), "dz": mix(b0["dz"], -0.7) - 0.07 * br,
            "pitch": mix(b0["pitch"], -9.0) - 1.5 * br, "roll": mix(b0["roll"], 3.0), "yaw": 2.0 * wave(u, 1) * hold}
    n1 = mix(t0["Neck1"][0], -13.0 if V2 else -22.0)  # v2: the bigger skull reached the floor at -22
    tl = mix(-14.0, -10.0)
    turns = {
        "Chest": (mix(t0["Chest"][0], 3.0) + 2.0 * br, 0, 0),
        "Neck1": (n1 + 2.0 * br, 4.0 * wave(u, 1, 0.2) * hold, 0),
        "Neck2": (mix(t0["Neck2"][0], -9.0 if V2 else -16.0), 3.0 * shake, 0),
        "Head": (mix(t0["Head"][0], 4.0), 2.0 * shake, 4.0 * shake),
        "Arm.L": (mix(-10.0, 18.0), 0, 0), "Arm.R": (mix(-10.0, 18.0), 0, 0),
        **{t: (tl * (0.45 if i < 3 else 0.25), 0, 0) for i, t in enumerate(TAILS)},
    }
    lift = max(0.0, track(u, [(0, 0), (E * 0.55, 0.95), (E, PIN_LIFT), (1, PIN_LIFT)]))
    fwd = track(u, [(0, 1.2), (E * 0.55, 1.55), (E, PIN_FWD), (1, PIN_FWD)])
    side = track(u, [(0, 0.0), (E, PIN_SIDE), (1, PIN_SIDE)])
    heel = track(u, [(0, 0.0), (E * 0.55, 14.0), (E, 8.0), (1, 8.0)])
    return {"body": body, "turns": turns, "jaw": mix(37.0, 12.0) + 9.0 * br * hold,
            "feet": {"L": (0, 0, 0, 0), "R": (lift, fwd, side, heel)}}


# The pinning foot's hold, metres in the rig (FWD / SIDE / UP from the right foot's print). PIN_LIFT puts the sole
# on a lying survivor's chest (~0.3 m); PinHold moves the victim, never the foot, so these only shape the pose.
PIN_LIFT, PIN_FWD, PIN_SIDE = (0.45 if V2 else 0.30), 1.8, -0.55  # v2: 0.45 (the v2 toes hang lower than the v1 toes)


CLIPS = {"idle": (idle, 96), "alert": (alert, 58), "attack_primary": (attack_primary, 40),
         "attack_heavy": (attack_heavy, 40), "tail_swipe": (tail_swipe, 48), "bite_shake": (bite_shake, 60),
         "hit_react": (hit_react, 18), "feed": (feed, 96), "knockdown": (knockdown, 76), "death": (death, 72),
         "sleep": (sleep, 144), "pin_foot": (pin_foot, 96)}
fn, N = CLIPS[CLIP]

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
print(f"REXMOVE {CLIP} {N} frames ({N / FPS:.3f} s)")

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
