"""Author the gallimimus' one-shots, idle, feed and sleep on its rig_biped.py skeleton (Hips/Spine1/Chest/Neck1/Neck2/
Neck3/Head/Jaw, Thigh/Shin/Metatarsal/Toe, Tail1-6, Arm/Forearm/Hand), in place. make_pachy_moves.py's machinery
(IK-planted feet, lying clips resting on the floor), plus a beak solver: each peck bends the three neck bones so the beak
tip lands on the survivor's chest at her contact reach, whatever the body does.

SP-GALLIMIMUS (owner 2026-10-31: "Gallimimus is fast but the model isn't great, animations aren't great and its
behavior sucks. Animals that run away from you should get territorial and attack you if you chase them").
# ASSUMPTION (GM2): the moves of a fast, skittish ostrich-like omnivore that turns on a chaser:
  attack_primary  beak peck, 1.0 s, hit 0.42: the neck cocks into an S and whips out and down onto her chest.
  attack_heavy    spring-and-rake kick, 1.42 s, hit 0.72: right leg hauled high and held trembling (windup_hold 0.6),
                  then snapped forward and down through her and raked back. Light animal: a stagger + Winded, no knockdown.
  bite_combo      peck-peck-kick, 2.75 s on the shared fracs 0.092 / 0.338 / 0.815 (tell 0.5-0.667: rears, leg cocked).
  alert           threat display (the cornered turn): drawn up tall, beak gaping in a hiss, arms flung out, a stamp.
  hop_back, leap_back, dodge_left/right  bounds in place (the game carries the body inside anim_events airborne
                  0.2-0.65): small animal, it hops and dodges rather than strafing.
usage: Blender -b -P tools/gait/make_galli_moves.py -- <base.glb> <clip> <out.glb> [--probe]
"""
import math
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


def _tip_local(bone, axis):
    """the rest-pose skin point furthest along axis among the verts this bone dominates, in the bone's rest frame
    (the glTF importer re-guesses bone tails, so a tail is not where the beak or claw ends)"""
    gi = {g.index: g.name for g in body.vertex_groups}
    best = None
    for v in body.data.vertices:
        if v.groups and gi[max(v.groups, key=lambda g: g.weight).group] == bone:
            co = body.matrix_world @ v.co
            if best is None or co.dot(axis) > best.dot(axis):
                best = co
    return bones[bone].matrix_local.inverted() @ best


BEAK_L = _tip_local("Head", FWD)
TOE_L = {sd: _tip_local("Toe." + sd, FWD) for sd in "LR"}


def beak_tip():
    """the upper beak tip, posed (armature space)"""
    return pbs["Head"].matrix @ BEAK_L


def toe_tip(sd):
    return pbs["Toe." + sd].matrix @ TOE_L[sd]


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
    order = ["Spine1", "Chest", "Neck1", "Neck2", "Neck3", "Head"] + TAILS + ["Arm.L", "Arm.R", "Forearm.L", "Forearm.R", "Hand.L", "Hand.R"]
    for name in order:
        tp, ty, tr = turns.get(name, (0.0, 0.0, 0.0))
        tp += CARRY.get(name, 0.0)
        turn(name, UP, ty)
        turn(name, SIDE, tp)
        turn(name, FWD, tr)
    # beak {(y, z, w)}: bend the neck (Neck1-3, a share each) so the beak tip moves w of the way to that armature-space
    # point (mesh units, on the midline): the peck lands where the survivor stands, whatever the body does.
    bk = p.get("beak")
    if bk and bk[2] > 0.001:
        ty, tz, w = bk
        w = min(w, 1.0)
        goal = Vector((p.get("beak_side", 0.0), ty, tz))
        # the beak strikes nose-first, pointing down at peck_dip_deg; the neck reaches along a gentle upward arc (FABRIK on
        # the joint positions from a bowed start), so it never hooks over or folds into the chest
        dip = math.radians(p.get("peck_dip_deg", 35.0))
        want_dir = (FWD * math.cos(dip) - UP * math.sin(dip)).normalized()
        chain = ["Neck1", "Neck2", "Neck3", "Head"]
        J = [pbs[n].head.copy() for n in chain]
        L = [(J[k + 1] - J[k]).length for k in range(3)]
        LH = (beak_tip() - J[3]).length
        dip_dir = want_dir.copy()
        base = J[0]
        for _outer in range(1):
            T = goal - want_dir * LH
            d = T - base
            side = d.cross(UP).normalized()
            bow = d.cross(side).normalized()  # up-ish, square to the reach
            if bow.dot(UP) < 0:
                bow = -bow
            P = [base + d * (k / 3.0) + bow * (0.1 * sum(L)) * math.sin(math.pi * k / 3.0) for k in range(4)]
            for _it in range(20):
                P[3] = T.copy()
                for k in (2, 1, 0):
                    P[k] = P[k + 1] + (P[k] - P[k + 1]).normalized() * L[k]
                P[0] = base.copy()
                for k in (1, 2, 3):
                    P[k] = P[k - 1] + (P[k] - P[k - 1]).normalized() * L[k - 1]
        for k in range(3):  # pose each neck bone to point at its solved child joint (blended by w)
            cur = [pbs[n].head.copy() for n in chain]
            want = cur[k].lerp(cur[k] + (P[k + 1] - P[k]), 1.0)
            q = (cur[k + 1] - cur[k]).rotation_difference(cur[k + 1].lerp(want, w) - cur[k])
            name = chain[k]
            set_m(name, Matrix.Translation(cur[k]) @ q.to_matrix().to_4x4() @ Matrix.Translation(-cur[k]) @ pbs[name].matrix)
        hp = pbs["Head"].head.copy()
        q = Quaternion().slerp((beak_tip() - hp).rotation_difference(want_dir), w)
        set_m("Head", Matrix.Translation(hp) @ q.to_matrix().to_4x4() @ Matrix.Translation(-hp) @ pbs["Head"].matrix)
    jb = pbs["Jaw"]
    cur = jb.matrix.copy()
    # GALLIFIX: the Jaw is rolled with add_jaw.py --x-side (local X = the animal's left), so + opens. Without it the
    # roll came out skewed and every open key yawed the lower beak out of the side of the face ("face looks mangled").
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
# where the survivor stands when it strikes: on the midline at its contact reach (3.1 m at size 1 = 0.53 mesh units; the beak aims 2.9 m out
# ahead of the origin; game 5.88 m per mesh unit), her chest at ~1.3 m (0.22). Mesh units, armature space (head -Y).
PREY_Y, PREY_CHEST, PREY_WAIST = -0.56, 0.22, 0.13  # 3.3 m: the long neck reaches nearly straight; the 0.55 m beak capsule still covers her at 2.6-3.1 m


def neck_s(k):
    """the neck drawn back into a tight S (k 0..1): base forward, middle back, head level. The cocked peck."""
    return {"Neck1": (-18 * k, 0, 0), "Neck2": (34 * k, 0, 0), "Neck3": (12 * k, 0, 0), "Head": (-26 * k, 0, 0)}


def arms(pitch=0.0, spread=0.0, fore=0.0, hand=0.0):
    """arm pose on both sides: pitch + = the arm swings forward/up, spread + = out from the body, fore/hand + = fold up"""
    out = {}
    for sd, s in (("L", 1.0), ("R", -1.0)):
        out["Arm." + sd] = (pitch, 0, -spread * s)
        out["Forearm." + sd] = (fore, 0, 0)
        out["Hand." + sd] = (hand, 0, 0)
    return out


def idle(u):
    """2.5 s loop: two breaths, the long neck bobbing and looking left and right (a bird checking for danger), a quick
    head flick, the weight rolling foot to foot, the tail swaying."""
    br = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * u)
    sway = wave(u, 1)
    look = wave(u, 1, 0.15)
    flick = track(u, [(0, 0), (0.55, 0), (0.6, 1), (0.68, 0), (1, 0)])
    return {
        "body": {"dz": -0.01 * br, "dx": 0.02 * sway, "roll": 1.0 * sway, "pitch": 0.6 * br},
        "turns": merge({
            "Chest": (1.2 * br, 0, 0),
            "Neck1": (-2.0 * br, 4.0 * look, 0), "Neck2": (2.0 * br, 5.0 * look, 0), "Neck3": (1.0 * br, 8.0 * look, 0),
            "Head": (-1.0 * br + 6 * flick, 10.0 * look, 5.0 * look),
        }, arms(4 * br), tail_wave(u, 3.0, 1.0, delay=0.05, cycles=1, phase=0.1)),
        "jaw": 1.0 + 3.0 * smooth((br - 0.6) / 0.4),
        "feet": PLANT,
    }


def alert(u):
    """Threat display, 1.5 s (the turn on a chaser, brain_cornered display_clips): it draws itself up tall, the neck
    stretched high and the beak gaping at the threat in a hiss, arms flung out with the claws spread, tail raised and
    lashing, then a hard stamp of the right foot and a lunge of the head at the threat; back down ready to fight."""
    up = track(u, [(0, 0), (0.2, 1), (0.8, 1), (1, 0)])
    hiss = track(u, [(0, 0), (0.15, 0), (0.25, 1), (0.75, 1), (0.9, 0), (1, 0)])
    shake = hiss * wave(u, 9) * 0.5
    stamp = max(0.0, track(u, [(0, 0), (0.45, 0), (0.55, 0.45), (0.64, 0), (1, 0)]))
    jab = track(u, [(0, 0), (0.6, 0), (0.66, 1), (0.76, 0), (1, 0)])
    return {
        "body": {"pitch": 14 * up - 6 * jab, "dz": 0.03 * up - 0.03 * jab, "dy": -0.06 * up + 0.08 * jab, "roll": 2 * shake},
        "turns": merge({
            "Chest": (4 * up, 0, 0), "Neck1": (-6 * up - 10 * jab, 0, 0), "Neck2": (-8 * up, 0, 0), "Neck3": (6 * up, 3 * shake, 0),
            "Head": (-22 * up + 8 * shake - 6 * jab, 4 * shake, 0),
        }, arms(30 * up, 40 * up, -20 * up, 10 * up), tail_set(-6 * up), tail_wave(u, 6.0, 0.0, cycles=3, env=up)),
        "jaw": 2 + 24 * hiss + 2 * wave(u, 11) * hiss,
        "feet": {"L": (0, 0, 0, 0), "R": (stamp, 0.08 * smooth(stamp / 0.45), 0, 0)},
    }


def peck_pose(u, H, sc=1.0):
    """one beak strike: cock the neck into an S, whip it out and down through the prey's chest at H, snap back.
    sc scales the timing offsets (clip fractions of the 1.0 s peck): the 2.75 s combo passes 24/66."""
    t = lambda d: H + d * sc
    cock = track(u, [(t(-0.3), 0), (t(-0.12), 1), (t(-0.05), 1), (H, 0), (t(0.25), 0)])
    w = track(u, [(t(-0.14), 0), (H, 1), (t(0.08), 1), (t(0.3), 0)])
    lunge = track(u, [(t(-0.3), 0), (t(-0.1), -0.15), (H, 0.12), (t(0.12), 0.1), (t(0.4), 0)])  # a small step: the long neck does the reaching
    return cock, w, lunge


def attack_primary(u):
    """Beak peck, 1.0 s, hit 0.42: rock back with the neck drawn into an S, then the whole body springs forward off a
    planted step and the neck whips out and down, the beak snapping shut on her chest; snap back."""
    H = 0.42
    cock, w, lunge = peck_pose(u, H)
    rf = track(u, [(0, 0), (0.22, 0), (0.38, 0.35), (0.75, 0.35), (0.93, 0), (1, 0)])
    rl = max(0.0, track(u, [(0, 0), (0.22, 0), (0.3, 0.18), (0.38, 0), (0.75, 0), (0.84, 0.15), (0.93, 0), (1, 0)]))
    return {
        "body": {"dy": lunge, "dz": -0.04 * w, "pitch": 5 * cock - 8 * w},
        "turns": merge(neck_s(cock), arms(-10 * cock + 15 * w), tail_set(-6 * cock + 6 * w)),
        "beak": (PREY_Y, PREY_CHEST, w),
        "jaw": track(u, [(0, 1), (0.25, 4), (H - 0.06, 26), (H, 0), (0.6, 6), (1, 1)]),
        "feet": {"L": (0, 0, 0, 0), "R": (rl, rf, 0, 0)},
    }


def kick_pose(u, H, hold0, hold1, sc=1.0):
    """the right leg cocked high (knee up, foot drawn back under the body, claws spread) through [hold0, hold1] (the
    telegraph), then driven forward and down through her waist (still travelling at H) and raked back to the ground.
    sc scales the timing offsets (clip fractions of the 1.42 s kick)."""
    t = lambda d: H + d * sc
    # no key on H itself: track() eases into every key, so a key on the hit would stop the foot dead there
    lift = max(0.0, track(u, [(hold0 - 0.25 * sc, 0), (hold0, 0.85), (hold1, 0.9), (t(0.05), 0.3), (t(0.12), 0.12), (t(0.2), 0)]))
    fwd = track(u, [(hold0 - 0.25 * sc, 0), (hold0, 0.25), (hold1, 0.2), (t(0.05), 1.25), (t(0.12), 0.7), (t(0.2), 0.15), (t(0.3), 0)])
    heel = track(u, [(hold0 - 0.25 * sc, 0), (hold0, 25), (hold1, 28), (t(0.06), -18), (t(0.12), 10), (t(0.25), 0)])
    lean = track(u, [(hold0 - 0.25 * sc, 0), (hold0, -1), (hold1, -1), (t(0.05), 1), (t(0.15), 0.6), (t(0.35), 0)])
    return lift, fwd, heel, lean


def attack_heavy(u):
    """Spring-and-rake kick, 1.42 s, hit 0.72: it rocks back onto the left leg, hauls the right leg up high with the knee
    forward and the three claws spread (held trembling through anim_events windup_hold 0.6: the telegraph), then
    snaps the foot forward and down through her and rakes it back; the arms fling back for balance. ASSUMPTION GM2."""
    H = 0.72
    lift, fwd, heel, lean = kick_pose(u, H, 0.35, 0.6)
    tremble = track(u, [(0.33, 0), (0.38, 1), (0.6, 1), (0.64, 0)]) * wave(u, 10)
    return {
        "body": {"dy": 0.12 * lean - 0.03, "dx": -0.05 * smooth(lift / 0.6), "dz": 0.04 * smooth(lift / 0.6) - 0.05 * max(0.0, lean),
                 "pitch": 10 * min(0.0, lean) * -1 - 6 * max(0.0, lean), "roll": -4 * smooth(lift / 0.6) + 0.8 * tremble},
        "turns": merge({"Chest": (-4 * lean, 0, 0), "Neck1": (-8 * lean, 0, 0), "Neck2": (10 * min(0.0, lean) * -1, 0, 0),
                        "Neck3": (0, 2 * tremble, 0), "Head": (-12 * max(0.0, lean) - 8 * min(0.0, lean) * -1, 0, 0)},
                       arms(-25 * abs(lean), 30 * abs(lean)), tail_set(-4 * max(0.0, -lean) + 3 * max(0.0, lean)),
                       tail_wave(u, 3.0, 0.0, cycles=4, env=abs(lean))),
        "jaw": track(u, [(0, 1), (0.3, 14), (0.6, 18), (H, 24), (0.85, 10), (1, 1)]) + 2 * tremble,
        "feet": {"L": (0, 0, 0, 0), "R": (lift, fwd, 0.02, heel)},
    }


def bite_combo(u):
    """Peck-peck-kick, 2.75 s on the shared bite_combo fracs: a peck a little to its left on 0.092, one to its right on
    0.338, then it rears with the right leg cocked high (the tell, 0.5-0.667) and drives the kick through her on 0.815.
    ASSUMPTION GM2."""
    SC = 24.0 / 66.0
    c1, w1, l1 = peck_pose(u, 0.092, SC)
    c2, w2, l2 = peck_pose(u, 0.338, SC)
    lift, fwd, heel, lean = kick_pose(u, 0.815, 0.5, 0.76, 34.0 / 66.0)  # cocked through the tell, snapped on the hit
    lean = lean if u > 0.42 else 0.0
    cock, w = c1 + c2, w1 + w2
    side = 0.015 * w1 - 0.015 * w2
    rl = max(0.0, track(u, [(0.18, 0), (0.22, 0.12), (0.27, 0)]))
    return {
        "body": {"dy": l1 + l2 + 0.3 * max(0.0, lean) + 0.06 * min(0.0, lean), "dz": -0.05 * w + 0.04 * smooth(lift / 0.6), "pitch": 5 * cock - 14 * w - 6 * max(0.0, lean) + 8 * smooth(lift / 0.6),
                 "yaw": 2 * w1 - 2 * w2, "dx": -0.04 * smooth(lift / 0.6)},
        "turns": merge(neck_s(cock), arms(-10 * cock + 15 * w - 20 * abs(lean), 25 * abs(lean)),
                       {"Neck1": (-8 * max(0.0, lean), 0, 0), "Head": (-10 * max(0.0, lean), 0, 0)}, tail_set(-6 * cock + 10 * w - 4 * smooth(lift / 0.6))),
        "beak": (PREY_Y, PREY_CHEST, w) if w > 0.001 else None,
        "beak_side": side,
        "jaw": max(1.0, 26 * max(track(u, [(0, 0), (0.06, 1), (0.092, 0)]), track(u, [(0.25, 0), (0.3, 1), (0.338, 0)])),
                   track(u, [(0.42, 1), (0.55, 20), (0.667, 24), (0.815, 30), (0.9, 8), (1, 1)])),
        "feet": {"L": (0, 0, 0, 0), "R": (max(lift, rl), fwd if u > 0.42 else 0.1 * rl, 0.02, heel)},
    }


def leap(u, A0, A1, crouch_d, tuck, reach, pitch_air, bank=0.0):
    """a bound (anim_events airborne A0-A1; the game carries the body): crouch, push off, feet tucked, landing squash."""
    air = math.sin(math.pi * min(max((u - A0) / (A1 - A0), 0.0), 1.0))
    crouch = track(u, [(0, 0), (A0 - 0.03, 1), (A0 + 0.04, 0.2), (A1 - 0.05, 0.1), (A1 + 0.05, 1.1), (A1 + 0.2, 0.4), (1, 0)])
    pitch = track(u, [(0, 0), (A0 - 0.03, -3), (A0 + 0.1, pitch_air), (A1 - 0.1, pitch_air * 0.7), (A1 + 0.03, -4), (A1 + 0.2, -1), (1, 0)])
    return {
        "body": {"dz": -crouch_d * crouch, "pitch": pitch, "roll": bank * air},
        "turns": merge({"Chest": (2 * air, 0, 0), "Neck1": (-6 * crouch + 8 * air, 0, 0), "Neck2": (-6 * air, 0, 0), "Neck3": (4 * crouch, 0, 0),
                        "Head": (-6 * crouch - 2 * air, -0.5 * bank * air, 0)},
                       arms(-25 * air, 20 * air * (1 if bank else 0.5)), tail_set(-pitch * 0.8 + 4 * air, -0.6 * bank * air)),
        "jaw": 2 + 8 * air,
        "feet": {"L": (tuck * air, reach * air, 0, 0), "R": (tuck * 0.9 * air, reach * 1.1 * air, 0, 0)},
    }


def hop_back(u):
    """0.58 s: crouch, a quick spring back with the feet tucked, planted squash landing."""
    return leap(u, 0.2, 0.65, 0.08, 0.16, -0.08, 6)


def leap_back(u):
    """0.79 s: a deeper crouch and a long high bound back, legs tucked tight, nose up, a heavy landing."""
    return leap(u, 0.2, 0.65, 0.12, 0.28, -0.12, 10)


def dodge_left(u):
    """0.42 s: crouch and an explosive side bound to its left, banking into it, legs tucked; lands facing the prey."""
    return leap(u, 0.2, 0.65, 0.08, 0.2, 0.0, 3, bank=-14)


def dodge_right(u):
    return leap(u, 0.2, 0.65, 0.08, 0.2, 0.0, 3, bank=14)


def hit_react(u):
    """0.6 s: the head and long neck whip back from the blow, the body flinches; the feet stay planted (PlantedFlinch
    pins them in game too)."""
    j = track(u, [(0, 0), (0.15, 1), (0.45, 0.7), (1, 0)])
    return {
        "body": {"dy": -0.05 * j, "pitch": 7 * j, "roll": -3 * j, "dz": -0.02 * j},
        "turns": merge({"Neck1": (10 * j, 6 * j, 0), "Neck2": (8 * j, 4 * j, 0), "Neck3": (6 * j, 6 * j, 0), "Head": (12 * j, 0, -8 * j)},
                       arms(15 * j, 20 * j), tail_set(-6 * j)),
        "jaw": 18 * j,
        "feet": PLANT,
    }


FOLD = {"L": (40, -75, 70, 30), "R": (40, -75, 70, 30)}  # thigh, shin, metatarsal, toe: a bird sitting on its hocks
LIMP = {"L": (24, -45, 40, 20), "R": (32, -55, 46, 24)}


def collapse(u, end_roll, head_drop, hold_from):
    c = track(u, [(0, 0), (hold_from, 1), (1, 1)])
    buckle = track(u, [(0, 0), (hold_from * 0.5, 1), (1, 1)])
    if c < 0.02:
        return {"feet": PLANT}
    return {
        "body": {"roll": end_roll * c, "pitch": -4 * c},
        "turns": merge({"Neck1": (-head_drop * 0.4 * c, -14 * c, 6 * c), "Neck2": (-head_drop * 0.3 * c, -12 * c, 0),
                        "Neck3": (-head_drop * 0.2 * c, -10 * c, 0), "Head": (-head_drop * 0.1 * c, 0, 10 * c)},
                       arms(-20 * c, 10 * c), tail_set(5 * c, -8 * c)),
        "feet": {"L": None, "R": None},
        "legs": {sd: tuple(v * buckle for v in LIMP[sd]) for sd in "LR"},
        "rest_on_floor": True,
    }


def knockdown(u):
    """2.1 s: the long legs buckle, it topples onto its right side and lies there, neck sprawled (the capture hold)."""
    p = collapse(u, 82, 30, 0.45)
    p["jaw"] = track(u, [(0, 1), (0.3, 18), (0.5, 6), (1, 4)])
    return p


def death(u):
    """1.8 s: a last stagger, then a fall onto the right side, the neck and tail going slack along the ground."""
    p = collapse(u, 88, 50, 0.5)
    p["jaw"] = track(u, [(0, 1), (0.3, 22), (0.6, 10), (1, 8)])
    return p


def sleep(u):
    """2.0 s, held on the last frame: settles belly-down onto folded legs like an ostrich, the long neck laid forward and
    down with the chin near the ground, tail curled round."""
    c = track(u, [(0, 0), (0.75, 1), (1, 1)])
    buckle = track(u, [(0, 0), (0.6, 1), (1, 1)])
    return {
        "body": {"pitch": -3 * c},
        "turns": merge({"Neck1": (-48 * c, 10 * c, 0), "Neck2": (-16 * c, 8 * c, 0), "Neck3": (14 * c, 6 * c, 0), "Head": (16 * c, 4 * c, 8 * c)},
                       arms(-20 * c), tail_set(6 * c, 9 * c, 0.95)),
        "jaw": 0.5,
        "feet": {"L": None, "R": None},
        "legs": {sd: tuple(v * buckle for v in FOLD[sd]) for sd in "LR"},
        "rest_on_floor": True,
    }


def feed(u):
    """2.0 s loop: the long neck dips to the ground, two pecking bites at seeds with a tug, head up to swallow."""
    d = 0.5 - 0.5 * math.cos(2 * math.pi * u)
    d = 0.7 + 0.3 * (1 - d)
    tug = max(0.0, wave(u, 2))
    return {
        "body": {"pitch": -16 * d, "dz": -0.06 * d, "dy": 0.03 * d},
        "turns": merge({"Chest": (-6 * d, 0, 0), "Neck1": (-34 * d + 4 * tug, 3 * wave(u, 1), 0), "Neck2": (-24 * d, 0, 0),
                        "Neck3": (8 * d, 0, 0), "Head": (-14 * d + 8 * tug, 0, 0)},
                       arms(10 * d), tail_set(12 * d), tail_wave(u, 2.0, 0.0)),
        "jaw": 2 + 12 * max(0.0, wave(u, 4)),
        "feet": PLANT,
    }


CLIPS = {"idle": (idle, 60, True), "alert": (alert, 36, False), "attack_primary": (attack_primary, 24, False),
         "attack_heavy": (attack_heavy, 34, False), "bite_combo": (bite_combo, 66, False), "hop_back": (hop_back, 14, False),
         "leap_back": (leap_back, 19, False), "dodge_left": (dodge_left, 10, False), "dodge_right": (dodge_right, 10, False),
         "hit_react": (hit_react, 14, False), "knockdown": (knockdown, 50, False), "death": (death, 43, False),
         "sleep": (sleep, 48, False), "feed": (feed, 48, True)}
fn, N, loop = CLIPS[CLIP]

if "--probe" in argv:  # print the beak and toe tips at the hit frames (mesh units), no export
    for f in range(N + 1):
        apply(fn(f / N))
        b, t = beak_tip(), toe_tip("R")
        print("PROBE %s f%02d u=%.3f beak y=%.3f z=%.3f  toeR y=%.3f z=%.3f" % (CLIP, f, f / N, b.y, b.z, t.y, t.z))
    sys.exit(0)

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
print(f"GALLIMOVE {CLIP} {N} frames ({N / FPS:.3f} s)")

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
