"""Author the therizinosaurus' fight moves, idle, feed and sleep on its rig_biped.py skeleton (Hips/Spine1/Chest/
Neck1/Neck2/Head/Jaw, Thigh/Shin/Metatarsal/Toe, Tail1-6, Arm/Forearm/Hand/Claw: the three sickle claws ride Claw), in
place. The pose machinery (IK-planted feet, body/turn/jaw/feet pose dicts, lying clips resting on the floor) is
make_pachy_moves.py's, with the Claw bones added to the turn order.

Owner 2026-10-31 (sheet: "use this for the therezino"): a big, mostly non-predatory herbivore that defends itself
brutally. # ASSUMPTION: the moves (the PRDs are silent on the therizinosaurus):
  attack_primary  forward claw sweep, 1.0 s, hit 0.42: the right arm cocks out to its right, then the claws sweep
                  low across its front at survivor height; a landed sweep shoves her back (tactics.primary_shove_m),
                  so it keeps a pest at claw's length.
  attack_heavy    two-arm overhead rake, 1.6 s, hit 0.72 (windup_hold 0.6): rears up hissing with both arms raised
                  high and the claws fanned (held and trembling: the telegraph), then drives both down through the
                  prey and rakes them back to its chest. The bleed move (bleed_2, pipeline.status_clips).
  bite_combo      hook-and-rake, 3.0 s, hits 0.092 / 0.338 / 0.815, tell 0.5-0.667 (anim_events bite_combo):
                  the right claws reach out and HOOK her, dragging back to its chest (the pull,
                  tactics.hook_pull_m), a left backhand slash, then it rears with both arms cocked at the shoulders
                  (the tell) and thrusts both claw sets forward and down.
  alert           threat display, 1.6 s: rears up tall, neck high, arms flung wide and raised with the claws fanned,
                  beak open hissing, two arm shakes, the tail fan raised.
Hit fractions match game/data/creatures/anim_events.json.

usage: Blender -b -P tools/gait/make_theri_moves.py -- <base.glb> <clip> <out.glb>
  clip: idle | alert | attack_primary | attack_heavy | bite_combo | hit_react | knockdown | death | sleep | feed
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
    order = ["Spine1", "Chest", "Neck1", "Neck2", "Head"] + TAILS + [b + s for b in ("Arm", "Forearm", "Hand", "Claw") for s in (".L", ".R")]
    for name in order:
        tp, ty, tr = turns.get(name, (0.0, 0.0, 0.0))
        tp += CARRY.get(name, 0.0)
        turn(name, UP, ty)
        turn(name, SIDE, tp)
        turn(name, FWD, tr)
    # reach {L/R: (x, y, z, w)}: swing the whole arm about the shoulder so the claw tip (ClawTip bone) moves w of the way
    # to that armature-space point (mesh units). The claws hang far out to the sides at rest, so every hit pose aims
    # the tips at the survivor's spot ahead of the animal (the game's hit check reads the ClawTip bones).
    for sd, (tx, ty, tz, w) in p.get("reach", {}).items():
        if w <= 0.001:
            continue
        sh = pbs["Arm." + sd].head.copy()
        tip = pbs["ClawTip." + sd].head.copy()
        want = tip.lerp(Vector((tx, ty, tz)), min(w, 1.0))
        q = (tip - sh).rotation_difference(want - sh)
        set_m("Arm." + sd, Matrix.Translation(sh) @ q.to_matrix().to_4x4() @ Matrix.Translation(-sh) @ pbs["Arm." + sd].matrix)
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



def arms(pitch=0.0, spread=0.0, yaw=0.0, fore=0.0, hand=0.0, claw=0.0, sides="LR"):
    """Mirrored arm turns. pitch + = the arm swings forward/up; spread + = out to that side; yaw + = outward (an arm
    reaching forward turns away from the midline); fore/hand + = the forearm/hand fold up; claw - = the claws curl
    back (a hook)."""
    out = {}
    for sd in sides:
        s = 1.0 if sd == "L" else -1.0
        out["Arm." + sd] = (pitch, s * yaw, s * spread)
        out["Forearm." + sd] = (fore, 0.0, 0.0)
        out["Hand." + sd] = (hand, 0.0, 0.0)
        out["Claw." + sd] = (claw, 0.0, 0.0)
    return out


# carry: the arms held a little forward, claws hanging clear of the legs
CARRY_ARMS = arms(6, 4, 0, 4, 0, 0)


def idle(u):
    """2.5 s loop: two breaths, a look left and right, the heavy arms swaying, the claws ticking, tail fan swaying."""
    br = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * u)
    sway = wave(u, 1)
    look = wave(u, 1, 0.15)
    return {
        "body": {"dz": -0.01 * br, "dx": 0.015 * sway, "roll": 1.0 * sway, "pitch": 1.0 * br},
        "turns": merge(CARRY_ARMS, arms(3 * br, 2 * sway, 0, 3 * br, 0, 4 * wave(u, 2, 0.3)),
                       {"Chest": (1.5 * br, 0, 0),
                        "Neck1": (-1.5 * br, 5.0 * look, 0), "Neck2": (-1.0 * br, 5.0 * look, 0), "Head": (2.0 * br, 5.0 * look, 4.0 * look)},
                       tail_wave(u, 3.0, 1.0, delay=0.05, cycles=1, phase=0.1)),
        "jaw": 1.0 + 3.0 * smooth((br - 0.6) / 0.4),
        "feet": PLANT,
    }


def alert(u):
    """Threat display, 1.6 s: rears up tall, neck high, the arms flung wide and raised with the claws fanned, beak
    open hissing, two shakes of the claws, tail fan raised; then down again."""
    up = track(u, [(0, 0), (0.25, 1), (0.82, 1), (1, 0)])
    shake = track(u, [(0, 0), (0.35, 0), (0.4, 1), (0.7, 1), (0.75, 0), (1, 0)]) * wave(u, 6)
    return {
        "body": {"dz": 0.05 * up, "pitch": 16 * up, "dy": 0.04 * up},
        "turns": merge(arms(40 * up + 6 * shake, 72 * up, 20 * up, -25 * up, 10 * up, 25 * up + 8 * shake),
                       {"Chest": (4 * up, 0, 0), "Neck1": (-8 * up, 0, 0), "Neck2": (6 * up, 0, 0), "Head": (-8 * up, 0, 4 * shake)},
                       tail_set(-24 * up), tail_wave(u, 5.0, 0.0, cycles=3, env=up)),
        "jaw": 1 + 26 * track(u, [(0, 0), (0.25, 0.6), (0.4, 1), (0.75, 1), (0.9, 0.2), (1, 0)]),
        "feet": PLANT,
    }


# where the survivor stands when it swings: on the midline at its reach (~5.6 m at size 1 = 0.42 mesh units ahead of the
# origin) and, for claws, at her waist (survivor 1.78 m = 0.134 mesh units). Mesh units, armature space (head -Y).
PREY_Y, PREY_Z = -0.46, 0.07


def attack_primary(u):
    """Forward claw sweep, 1.0 s, hit 0.42: the right arm cocks out to its right and back, then the claw tips sweep low
    across its front from right to left through the prey's spot (at the hit), the body twisting into it; recover."""
    H = 0.42
    sw = track(u, [(0, 0), (0.25, -1), (0.3, -1), (H, 0.0), (0.55, 0.9), (0.85, 0.2), (1, 0)])  # -1 cocked right, +1 across to the left
    lean = track(u, [(0, 0), (0.25, -0.3), (H, 1), (0.6, 0.8), (1, 0)])
    w = track(u, [(0, 0), (0.12, 0), (0.25, 1), (0.6, 1), (0.9, 0), (1, 0)])
    # the tip's path: out to the right and up (cocked), through the prey's spot, on across to the left
    x = track(u, [(0, -0.25), (0.25, -0.32), (0.3, -0.32), (H, 0.0), (0.55, 0.22), (1, 0.22)])
    y = track(u, [(0, -0.38), (0.25, -0.30), (0.3, -0.30), (H, PREY_Y), (0.55, -0.40), (1, -0.40)])
    z = track(u, [(0, 0.10), (0.25, 0.24), (0.3, 0.24), (H, PREY_Z), (0.55, 0.06), (1, 0.10)])
    yaw = 14 * sw
    return {
        "body": {"yaw": yaw, "pitch": -8 * lean, "dy": 0.06 * lean, "dz": -0.04 * lean},
        "turns": merge(CARRY_ARMS, {"Forearm.R": (-15 * w, 0, 0), "Claw.R": (10 * w, 0, 0)},
                       {"Chest": (0, 6 * sw, 0), "Neck1": (-6 * lean, -0.6 * yaw, 0), "Head": (4 * lean, -0.4 * yaw, 0)},
                       tail_set(4 * lean, -0.8 * yaw)),
        "reach": {"R": (x, y, z, w)},
        "jaw": track(u, [(0, 1), (0.3, 8), (H, 14), (0.7, 3), (1, 1)]),
        "feet": PLANT,
    }


def attack_heavy(u):
    """Two-arm overhead rake, 1.6 s, hit 0.72: rears up hissing, both arms raised high, claws fanned, held trembling
    (the telegraph, windup_hold 0.6), then both arms drive down through the prey's spot with a step and rake back
    toward the chest; recover."""
    H = 0.72
    rear = track(u, [(0, 0), (0.3, 1), (0.6, 1), (H, -0.6), (0.82, -0.7), (1, 0)])
    raise_ = track(u, [(0, 0), (0.3, 1), (0.6, 1.05), (H, 0.6), (0.82, 0.3), (1, 0)])
    trem = track(u, [(0, 0), (0.3, 0), (0.33, 1), (0.6, 1), (0.63, 0), (1, 0)]) * wave(u, 14)
    w = track(u, [(0, 0), (0.62, 0), (H, 1), (0.84, 1), (1, 0)])
    rake = track(u, [(0, 0), (H, 0), (0.84, 1), (1, 1)])  # after the hit the tips drag back toward the chest
    y = PREY_Y + 0.12 * rake
    z = PREY_Z + 0.04 * rake
    step = track(u, [(0, 0), (0.6, 0), (H, 0.35), (0.92, 0.35), (1, 0)])
    lift = max(0.0, track(u, [(0, 0), (0.6, 0), (0.66, 0.12), (H, 0), (0.9, 0), (0.95, 0.08), (1, 0)]))
    return {
        "body": {"pitch": 20 * rear, "dz": 0.05 * max(rear, 0) - 0.05 * max(-rear, 0), "dy": 0.25 * step - 0.04 * max(rear, 0)},
        "turns": merge(arms(120 * raise_ + 3 * trem, 25 * raise_, 10 * raise_, -15 * raise_, 0, 30 * raise_ - 20 * rake),
                       {"Chest": (5 * rear, 0, 0), "Neck1": (-10 * rear, 0, 0), "Neck2": (4 * max(rear, 0), 0, 0), "Head": (-6 * rear, 0, 3 * trem)},
                       tail_set(-10 * rear)),
        "reach": {"L": (0.05, y, z, w), "R": (-0.05, y, z, w)},
        "jaw": track(u, [(0, 1), (0.3, 20), (0.6, 24), (H, 28), (0.85, 10), (1, 1)]),
        "feet": {"L": (0, 0, 0, 0), "R": (lift, step, 0, 0)},
    }


def bite_combo(u):
    """Hook-and-rake, 3.0 s: hits 0.092 (the right claws hook her and drag her in), 0.338 (left backhand slash),
    tell 0.5-0.667 (rears, both arms cocked at the shoulders, claws forward), 0.815 (both claw sets thrust down)."""
    # hook: the right tip reaches through her spot at 0.092, then drags back in toward the chest (the pull)
    wr = track(u, [(0, 0.6), (0.06, 1), (0.25, 1), (0.32, 0), (0.72, 0), (0.815, 1), (0.9, 1), (1, 0)])
    rx = track(u, [(0, -0.12), (0.092, -0.01), (0.22, -0.06), (0.32, -0.12), (0.72, -0.03), (0.815, -0.03), (1, -0.03)])
    ry = track(u, [(0, -0.50), (0.092, PREY_Y), (0.22, -0.33), (0.32, -0.33), (0.72, -0.40), (0.815, PREY_Y - 0.02), (1, PREY_Y)])
    rz = track(u, [(0, 0.14), (0.092, PREY_Z), (0.22, 0.12), (0.32, 0.14), (0.72, 0.20), (0.815, PREY_Z - 0.01), (1, PREY_Z)])
    curl = track(u, [(0, 0), (0.06, 0), (0.092, 1), (0.22, 1), (0.3, 0), (1, 0)])
    # backhand: the left tip swings from across on her right, through her spot at 0.338, out to the left
    wl = track(u, [(0, 0), (0.2, 0), (0.26, 1), (0.42, 1), (0.5, 0), (0.72, 0), (0.815, 1), (0.9, 1), (1, 0)])
    lx = track(u, [(0, -0.10), (0.26, -0.14), (0.338, 0.0), (0.42, 0.24), (0.5, 0.2), (0.72, 0.03), (1, 0.03)])
    ly = track(u, [(0, -0.40), (0.26, -0.40), (0.338, PREY_Y), (0.42, -0.38), (0.5, -0.38), (0.72, -0.40), (0.815, PREY_Y - 0.02), (1, PREY_Y)])
    lz = track(u, [(0, 0.12), (0.26, 0.16), (0.338, PREY_Z), (0.42, 0.14), (0.72, 0.20), (0.815, PREY_Z - 0.01), (1, PREY_Z)])
    cock = track(u, [(0, 0), (0.45, 0), (0.52, 1), (0.667, 1), (0.815, 0), (1, 0)])
    thrust = track(u, [(0, 0), (0.72, 0), (0.815, 1), (0.92, 1), (1, 0)])
    rear = track(u, [(0, 0), (0.45, 0), (0.55, 1), (0.667, 1), (0.815, -0.8), (0.9, -0.7), (1, 0)])
    hook = track(u, [(0, 0.5), (0.092, 1), (0.22, 0), (1, 0)])
    bk = track(u, [(0, 0), (0.26, -1), (0.338, 0), (0.42, 1), (0.5, 0), (1, 0)])
    lunge = track(u, [(0, 0.1), (0.092, 0.15), (0.25, 0), (0.667, -0.05), (0.86, 0.2), (0.92, 0.18), (1, 0)])
    lift = max(0.0, track(u, [(0, 0), (0.7, 0), (0.76, 0.1), (0.815, 0), (0.92, 0), (0.96, 0.06), (1, 0)]))
    rstep = track(u, [(0, 0), (0.7, 0), (0.815, 0.3), (0.94, 0.3), (1, 0)])
    yaw = 10 * hook - 10 * bk
    return {
        "body": {"pitch": 12 * rear - 5 * hook, "dy": lunge, "dz": 0.01 * max(rear, 0) - 0.05 * thrust, "yaw": yaw},
        "turns": merge(arms(100 * cock, 10 * cock, 0, -50 * cock, 0, 25 * cock),
                       {"Forearm.R": (-20 * curl, 0, 0), "Claw.R": (-40 * curl, 0, 0), "Claw.L": (15 * abs(bk), 0, 0)},
                       {"Chest": (3 * rear, 0.5 * yaw, 0), "Neck1": (-8 * rear - 8 * thrust, -0.5 * yaw, 0), "Head": (-4 * rear, -0.3 * yaw, 0)},
                       tail_set(-8 * rear, -0.8 * yaw)),
        "reach": {"R": (rx, ry, rz, wr * (1 - cock)), "L": (lx, ly, lz, wl * (1 - cock))},
        "jaw": track(u, [(0, 2), (0.092, 14), (0.2, 4), (0.338, 12), (0.45, 3), (0.6, 24), (0.815, 18), (1, 1)]),
        "feet": {"L": (0, 0, 0, 0), "R": (lift, rstep, 0, 0)},
    }


def hit_react(u):
    """0.6 s: the head and chest jerk back and up from the blow, the arms flinch up, a stagger step back."""
    j = track(u, [(0, 0), (0.15, 1), (0.45, 0.7), (1, 0)])
    lf = track(u, [(0, 0), (0.1, 0), (0.36, -0.14), (0.62, -0.14), (0.9, 0), (1, 0)])
    ll = max(0.0, track(u, [(0, 0), (0.06, 0), (0.22, 0.12), (0.38, 0), (0.6, 0), (0.75, 0.1), (0.92, 0), (1, 0)]))
    return {
        "body": {"dy": -0.07 * j, "pitch": 8 * j, "roll": -3 * j, "dz": -0.02 * j},
        "turns": merge(CARRY_ARMS, arms(25 * j, 15 * j, 0, -10 * j, 0, 10 * j),
                       {"Neck1": (12 * j, 6 * j, 0), "Neck2": (8 * j, 0, 0), "Head": (14 * j, 0, -8 * j)}, tail_set(-6 * j)),
        "jaw": 16 * j,
        "feet": {"L": (ll, lf, 0, 0), "R": (0, 0, 0, 0)},
    }


FOLD = {"L": (38, -70, 62, 30), "R": (38, -70, 62, 30)}  # thigh, shin, metatarsal, toe: a bird sitting on its hocks
LIMP = {"L": (22, -40, 34, 20), "R": (30, -50, 40, 24)}
TUCK = arms(-70, 0, 0, 0, 0, -60)  # lying: arms swung back along the flanks, claws curled back (never under it or skyward)
# rolled onto its right side: both arms fold in under the chest, so neither claw set sticks up off the fallen body
TUCK_SIDE = merge(arms(-70, -55, 0, 0, 0, -60, sides="L"), arms(-70, -40, 0, 0, 0, -60, sides="R"))


def collapse(u, end_roll, head_drop, hold_from):
    c = track(u, [(0, 0), (hold_from, 1), (1, 1)])
    buckle = track(u, [(0, 0), (hold_from * 0.5, 1), (1, 1)])
    legs = {sd: tuple(v * buckle for v in LIMP[sd]) for sd in "LR"}
    if c < 0.02:
        return {"feet": PLANT, "turns": CARRY_ARMS}
    tuck = {k: tuple(x * buckle for x in v) for k, v in TUCK_SIDE.items()}
    return {
        "body": {"roll": end_roll * c, "pitch": -4 * c},
        "turns": merge(CARRY_ARMS, tuck,
                       {"Neck1": (-head_drop * 0.5 * c, -10 * c, 6 * c), "Neck2": (-head_drop * 0.3 * c, -8 * c, 0), "Head": (-head_drop * 0.2 * c, 0, 10 * c)},
                       tail_set(5 * c, -8 * c)),
        "feet": {"L": None, "R": None},
        "legs": legs,
        "rest_on_floor": True,
    }


def knockdown(u):
    """2.1 s: the knees buckle, it topples onto its right side and lies there, arms folded in (the capture hold)."""
    p = collapse(u, 80, 24, 0.45)
    p["jaw"] = track(u, [(0, 1), (0.3, 18), (0.5, 6), (1, 4)])
    return p


def death(u):
    """1.8 s: a last stagger, then a heavy fall onto the right side, neck and tail going slack."""
    p = collapse(u, 86, 40, 0.5)
    p["jaw"] = track(u, [(0, 1), (0.3, 22), (0.6, 10), (1, 8)])
    return p


def sleep(u):
    """2.0 s, held on the last frame: settles belly-down onto folded legs, the arms folded back like a bird's wings,
    the neck curled round with the head resting low, tail fan curled."""
    c = track(u, [(0, 0), (0.75, 1), (1, 1)])
    buckle = track(u, [(0, 0), (0.6, 1), (1, 1)])
    tuck = {k: tuple(x * c for x in v) for k, v in TUCK.items()}
    return {
        "body": {"pitch": -3 * c},
        "turns": merge(CARRY_ARMS, tuck, {"Neck1": (-34 * c, 14 * c, 0), "Neck2": (-16 * c, 12 * c, 0), "Head": (12 * c, 10 * c, 4 * c)},
                       tail_set(6 * c, 9 * c, 0.95)),
        "jaw": 0.5,
        "feet": {"L": None, "R": None},
        "legs": {sd: tuple(v * buckle for v in FOLD[sd]) for sd in "LR"},
        "rest_on_floor": True,
    }


def feed(u):
    """2.0 s loop: browsing high: the neck stretches up, the right claws reach overhead and hook a branch down, the
    beak strips it, chewing."""
    reach = 0.5 - 0.5 * math.cos(2 * math.pi * u)
    pull = track(u, [(0, 0), (0.35, 0), (0.55, 1), (0.8, 1), (1, 0)])
    return {
        "body": {"pitch": 10 + 4 * reach, "dz": 0.02 * reach},
        "turns": merge(CARRY_ARMS, arms(60 + 50 * (1 - pull), 10, 0, -10 + 20 * pull, 0, -30 * pull, sides="R"),
                       arms(10, 6, 0, 10, 0, 0, sides="L"),
                       {"Neck1": (6 + 6 * reach, 0, 0), "Neck2": (8 * reach, 0, 0), "Head": (6 * reach - 8 * pull, 0, 0)},
                       tail_set(-6), tail_wave(u, 2.0, 0.0)),
        "jaw": 2 + 12 * max(0.0, wave(u, 4)) * pull + 6 * (1 - pull) * reach,
        "feet": PLANT,
    }


CLIPS = {"idle": (idle, 60, True), "alert": (alert, 38, False), "attack_primary": (attack_primary, 24, False),
         "attack_heavy": (attack_heavy, 38, False), "bite_combo": (bite_combo, 72, False), "hit_react": (hit_react, 14, False),
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
print(f"THERIMOVE {CLIP} {N} frames ({N / FPS:.3f} s)")

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
