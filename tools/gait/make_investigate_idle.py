"""Author the raptor's "investigate" idle loop and its short "sniff" one-shot (Meshy-library biped bone names).

Owner 2026-10-30 (velociraptor): "they gave this raptor like a head tilt and curious/inquisitive movement (similar to
compy but more aggressive)". Same method as make_nervous_idle.py (the compy's curious idle), tuned to read as a
predator: the body holds a low crouch, head low and level on the prey, arms out, tail stiff and lashing. The head
snaps bird-like between cocked tilts and holds each one, cocks hard toward the prey (straight ahead: the brain faces
the raptor at it) with the jaw parted, and the weight shifts in quick twitches rather than a sway. Feet stay planted
(two-bone leg IK onto the root-parented feet) and the last frame equals the first.

  investigate: 4.0 s loop, played while the raptor is aware of prey but not attacking.
  sniff:       1.5 s one-shot from the same crouch: neck stretches toward the prey, snout bobs with the jaw
               working, a tilt to inspect, then a snap back up into the crouch.

usage: Blender -b -P tools/gait/make_investigate_idle.py -- <base.glb> <out.glb> [--clip investigate|sniff]
       [--seconds S] [--gain 1.0]
"""
import math
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, OUT = argv[:2]
CLIP = argv[argv.index("--clip") + 1] if "--clip" in argv else "investigate"
SECONDS = float(argv[argv.index("--seconds") + 1]) if "--seconds" in argv else {"investigate": 4.0, "combat": 3.0, "charge_crouch": 0.42}.get(CLIP, 1.5)
LOOP = CLIP in ("investigate", "combat")
GAIN = float(argv[argv.index("--gain") + 1]) if "--gain" in argv else 1.0
HEEL_ROLL = float(argv[argv.index("--heel-roll") + 1]) if "--heel-roll" in argv else 0.0
FPS = 24
N = int(round(SECONDS * FPS))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
pbs, bones = arm.pose.bones, arm.data.bones
FWD, UP = Vector((0, -1, 0)), Vector((0, 0, 1))
SIDE = FWD.cross(UP).normalized()  # the animal's right
LEN = max(b.head_local.y for b in bones) - min(b.head_local.y for b in bones)  # snout to tail, scales distances
HIP_H = bones["BackUpLeg.L"].head_local.z


def rot_about(p, axis, ang):
    return Matrix.Translation(p) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-p)


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def track(keys, f):
    """keys: [(frame, value, snap_frames)], value held after each snap; first and last value equal (loop)."""
    v = keys[0][1]
    for i in range(1, len(keys)):
        f0, v0 = keys[i - 1][0], keys[i - 1][1]
        f1, v1, snap = keys[i]
        if f < f1 - snap:
            return v0 if f >= f0 else v
        if f <= f1:
            return v0 + (v1 - v0) * smooth((f - (f1 - snap)) / max(snap, 1e-6))
        v = v1
    return keys[-1][1]


def at(frac):
    return frac * N


# ---- the performance, in fractions of the clip (degrees / metres before GAIN) --------------------------------
# neck yaw (+ = turn to its left), neck pitch (+ = nose down), head roll (+ = tilt to its left)
CROUCH_M = 0.2 * HIP_H  # constant predatory crouch, both clips (so they blend into each other)
CROUCH_TORSO = 9.0  # chest dipped, nose-down degrees, the neck lifts the head back to level
HEAD_LOW = 10.0  # neck carried lower and forward, the head turned back up so the snout stays on the prey
if CLIP == "investigate":
    NECK_YAW = [(0, 0, 1), (at(.08), 6, 2), (at(.24), -4, 2), (at(.38), 0, 1), (at(.41), 30, 2), (at(.47), 30, 1),
                (at(.50), 0, 2), (at(.72), 0, 1), (at(.75), -8, 2), (at(.84), 4, 2), (at(.93), 0, 3), (N, 0, 1)]
    NECK_PITCH = [(0, 0, 1), (at(.24), 0, 1), (at(.27), -6, 2), (at(.38), -6, 1), (at(.41), -10, 2), (at(.47), -10, 1),
                  (at(.52), 10, 3), (at(.70), 10, 1), (at(.74), 0, 3), (N, 0, 1)]
    HEAD_ROLL = [(0, 0, 1), (at(.08), 30, 2), (at(.15), 30, 1), (at(.16), 26, 1), (at(.24), -34, 2), (at(.34), -34, 1),
                 (at(.38), -8, 2), (at(.44), -8, 1), (at(.52), 38, 2), (at(.70), 38, 1), (at(.74), -12, 2),
                 (at(.82), -12, 1), (at(.84), -26, 1.5), (at(.90), -26, 1), (at(.94), 0, 2), (N, 0, 1)]
    HEAD_PITCH = [(0, 0, 1), (at(.24), 0, 1), (at(.27), 8, 2), (at(.34), 8, 1), (at(.38), 0, 2), (N, 0, 1)]  # peer
    TORSO_PITCH = [(0, 0, 1), (at(.48), 0, 1), (at(.53), 5, 3), (at(.70), 5, 1), (at(.76), 0, 4), (N, 0, 1)]
    CROUCH_EXTRA = [(0, 0, 1), (at(.48), 0, 1), (at(.53), 1.0, 3), (at(.70), 1.0, 1), (at(.76), 0, 4), (N, 0, 1)]
    JAW = [(0, 0, 1), (at(.54), 0, 1), (at(.57), 11, 2), (at(.66), 11, 1), (at(.69), 0, 2), (N, 0, 1)]  # silent hiss
    WEIGHT = [(0, 0, 1), (at(.12), 1, 2), (at(.30), 1, 1), (at(.32), -1, 2), (at(.60), -1, 1), (at(.62), 0.6, 2),
              (at(.80), 0.6, 1), (at(.82), -0.4, 2), (at(.95), -0.4, 1), (N, 0, 3)]  # twitchy foot-to-foot
    TAIL_YAW = [(0, 0, 1), (at(.10), 8, 6), (at(.30), -10, 8), (at(.50), 4, 6), (at(.56), 14, 2), (at(.62), -12, 3),
                (at(.80), 8, 6), (N, 0, 6)]  # slow lash, a flick at the hiss
    TAIL_PITCH = [(0, -6, 1), (at(.52), -6, 1), (at(.56), -9, 2), (at(.72), -9, 1), (at(.80), -6, 4), (N, -6, 1)]
    ARM_PITCH = [(0, -14, 1), (at(.08), -18, 1.5), (at(.24), -12, 1.5), (at(.52), -26, 2), (at(.70), -26, 1),
                 (at(.76), -14, 3), (N, -14, 1)]  # arms out, claws flex with the snaps
    ARM_SPREAD = [(0, 10, 1), (at(.52), 18, 2), (at(.70), 18, 1), (at(.76), 10, 3), (N, 10, 1)]
elif CLIP == "combat":  # COMPYFEEL (owner 2026-10-31): "a head twitching idle ... itching for a fight"
    # Snout stays on the prey (small yaw); the head snaps between hard tilts every few frames and holds each one,
    # jerks up and down, chatters the jaw, the tail flicks, and the whole body bounces on pumping knees.
    CROUCH_M = 0.24 * HIP_H
    NECK_YAW = [(0, 0, 1), (at(.10), 7, 1), (at(.22), -6, 1), (at(.31), 0, 1), (at(.52), 9, 1), (at(.60), -8, 1),
                (at(.74), 4, 1), (at(.86), -3, 1), (N, 0, 1.5)]
    NECK_PITCH = [(0, 0, 1), (at(.12), -6, 1), (at(.20), 4, 1), (at(.34), -8, 1), (at(.40), 0, 1), (at(.62), 6, 1),
                  (at(.70), -5, 1), (at(.88), 0, 1.5), (N, 0, 1)]
    HEAD_ROLL = [(0, 0, 1), (at(.06), 28, 1), (at(.14), -22, 1), (at(.20), -22, 1), (at(.24), 34, 1), (at(.33), 10, 1),
                 (at(.38), -30, 1), (at(.48), -30, 1), (at(.52), 18, 1), (at(.58), -12, 1), (at(.66), 36, 1),
                 (at(.76), 36, 1), (at(.80), -18, 1), (at(.88), 8, 1), (N, 0, 1.5)]
    HEAD_PITCH = [(0, 0, 1), (at(.14), 6, 1), (at(.20), -4, 1), (at(.40), 8, 1), (at(.46), 0, 1), (at(.70), -6, 1),
                  (at(.78), 4, 1), (N, 0, 1.5)]
    TORSO_PITCH = [(0, 0, 1), (at(.30), 0, 1), (at(.34), 4, 1.5), (at(.46), 4, 1), (at(.52), 0, 2), (N, 0, 1)]
    CROUCH_EXTRA = [(0, 0, 1), (at(.30), 0, 1), (at(.34), 0.4, 1.5), (at(.46), 0.4, 1), (at(.52), 0, 2), (N, 0, 1)]
    JAW = [(0, 0, 1), (at(.34), 0, 1), (at(.36), 14, 1), (at(.39), 2, 1), (at(.41), 12, 1), (at(.45), 0, 1),
           (at(.80), 0, 1), (at(.82), 9, 1), (at(.85), 0, 1), (N, 0, 1)]  # chatter, a hiss, a snap
    WEIGHT = [(0, 0, 1), (at(.16), 1, 1.5), (at(.30), 1, 1), (at(.33), -1, 1.5), (at(.56), -1, 1), (at(.58), 0.8, 1.5),
              (at(.78), 0.8, 1), (at(.80), -0.6, 1.5), (N, 0, 2)]
    TAIL_YAW = [(0, 0, 1), (at(.08), 16, 1.5), (at(.14), -8, 2), (at(.36), -6, 1), (at(.40), 18, 1.5), (at(.46), -12, 2),
                (at(.66), 0, 3), (at(.70), -16, 1.5), (at(.76), 10, 2), (N, 0, 3)]  # flicks
    TAIL_PITCH = [(0, -4, 1), (at(.34), -4, 1), (at(.38), -9, 1.5), (at(.50), -9, 1), (at(.56), -4, 3), (N, -4, 1)]
    ARM_PITCH = [(0, -16, 1), (at(.06), -22, 1), (at(.14), -14, 1), (at(.36), -6, 1), (at(.48), -6, 1),
                 (at(.54), -16, 2), (at(.66), -24, 1), (at(.76), -14, 1.5), (N, -16, 1)]
    ARM_SPREAD = [(0, 12, 1), (at(.36), 20, 1), (at(.48), 20, 1), (at(.54), 12, 2), (N, 12, 1)]
elif CLIP == "charge_crouch":  # COMPYFEEL: the coil before the charge, ends in the charge loop's low lean
    CROUCH_M = 0.34 * HIP_H
    CROUCH_TORSO = 16.0
    HEAD_LOW = 14.0
    NECK_YAW = [(0, 0, 1)]
    NECK_PITCH = [(0, 0, 1)]
    HEAD_ROLL = [(0, 0, 1), (at(.15), 14, 1.5), (at(.45), 0, 2), (N, 0, 1)]  # one last cock, then dead level
    HEAD_PITCH = [(0, 0, 1)]
    TORSO_PITCH = [(0, 0, 1)]
    CROUCH_EXTRA = [(0, 0, 1)]
    JAW = [(0, 0, 1), (at(.40), 0, 1), (at(.55), 12, 2), (N, 12, 1)]  # jaws part as it launches
    WEIGHT = [(0, 0, 1)]
    TAIL_YAW = [(0, 0, 1), (at(.20), 10, 1.5), (at(.40), -6, 2), (N, 0, 2)]
    TAIL_PITCH = [(0, -4, 1), (at(.60), 10, 5), (N, 10, 1)]  # tail lifts level as the chest drops
    ARM_PITCH = [(0, -14, 1), (at(.60), 20, 5), (N, 20, 1)]  # arms tuck back
    ARM_SPREAD = [(0, 10, 1), (at(.60), 0, 5), (N, 0, 1)]
else:  # sniff
    NECK_YAW = [(0, 0, 1), (at(.40), 0, 1), (at(.46), 10, 2), (at(.58), -8, 2), (at(.66), 0, 2), (N, 0, 1)]
    NECK_PITCH = [(0, 0, 1), (at(.22), 30, 5), (at(.62), 30, 1), (at(.70), -14, 2), (at(.86), -14, 1), (N, 0, 3)]
    HEAD_ROLL = [(0, 0, 1), (at(.30), 0, 1), (at(.36), 20, 2), (at(.48), 20, 1), (at(.52), -14, 2), (at(.62), -14, 1),
                 (at(.70), 28, 2), (at(.86), 28, 1), (N, 0, 3)]
    HEAD_PITCH = [(0, 0, 1), (at(.22), 10, 5), (at(.62), 10, 1), (at(.70), 0, 2), (N, 0, 1)]
    TORSO_PITCH = [(0, 0, 1), (at(.22), 10, 5), (at(.62), 10, 1), (at(.70), -4, 2), (at(.86), -4, 1), (N, 0, 3)]
    CROUCH_EXTRA = [(0, 0, 1), (at(.22), 0.6, 5), (at(.62), 0.6, 1), (at(.70), 0, 2), (N, 0, 1)]
    JAW = [(0, 0, 1)]
    WEIGHT = [(0, 0, 1), (at(.20), 0.5, 3), (at(.62), 0.5, 1), (at(.68), -0.5, 1.5), (at(.86), -0.5, 1), (N, 0, 3)]
    TAIL_YAW = [(0, 0, 1), (at(.30), 6, 6), (at(.60), -6, 6), (at(.70), 12, 1.5), (at(.80), -6, 2), (N, 0, 4)]
    TAIL_PITCH = [(0, -6, 1), (at(.70), -6, 1), (at(.74), -9, 1.5), (at(.86), -9, 1), (N, -6, 3)]
    ARM_PITCH = [(0, -14, 1), (at(.22), -8, 5), (at(.62), -8, 1), (at(.70), -24, 1.5), (at(.86), -24, 1), (N, -14, 3)]
    ARM_SPREAD = [(0, 10, 1), (at(.70), 16, 1.5), (at(.86), 16, 1), (N, 10, 3)]


def sniff_bob(f):  # quick snout bobs while craned down, with the jaw working
    if CLIP != "sniff":
        return 0.0
    u = (f - at(.24)) / (at(.62) - at(.24))
    return 0.0 if u <= 0 or u >= 1 else math.sin(math.pi * u) * math.sin(2 * math.pi * 5 * u)


def breath(f):  # two breaths per loop (whole cycles, so the loop stays seamless)
    return math.sin(2 * math.pi * 2 * f / N) if CLIP == "investigate" else 0.0


def crouch_k(f):  # charge_crouch sinks into the coil over its first 60 %; the other clips hold their crouch
    return smooth(f / (0.6 * N)) if CLIP == "charge_crouch" else 1.0


def bounce(f):  # combat: the weight bounces on pumping knees, 6 bounces per loop (whole cycles: seamless)
    return 0.07 * HIP_H * (1.0 - abs(math.cos(math.pi * 6 * f / N))) if CLIP == "combat" else 0.0  # sharp at the bottom


def tremor(f):  # tiny head jitter during the holds: twitchy, never still
    if CLIP == "combat":
        return 1.6 * (math.sin(2 * math.pi * 13 * f / N) * 0.6 + math.sin(2 * math.pi * 23 * f / N) * 0.4)
    return math.sin(2 * math.pi * 11 * f / N) * 0.6 + math.sin(2 * math.pi * 17 * f / N) * 0.4 if CLIP == "investigate" else 0.0


# ---- legs: analytic two-bone IK (as make_gait.py) -------------------------------------------------------------
LEGS = {}
for s in "LR":
    up, low, foot = "BackUpLeg." + s, "BackLowLeg." + s, "BackFoot." + s
    h, k, an = bones[up].head_local, bones[low].head_local, bones[foot].head_local
    line = an - h
    off = (k - h) - line * ((k - h).dot(line) / line.length_squared)
    LEGS[s] = {"up": up, "low": low, "foot": foot, "l1": bones[up].length, "l2": (k - an).length,
               "pole": off.normalized(), "ankle0": an.copy(), "toe0": bones[foot + "_end"].tail_local.copy()}


def set_m(name, m):
    pbs[name].matrix = m
    bpy.context.view_layer.update()


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
    for bone, p0, p1 in ((up, h, knee), (low, knee, ankle)):
        m = pbs[bone].matrix.copy()
        q = m.to_3x3().col[1].normalized().rotation_difference((p1 - p0).normalized())
        nm = (q.to_matrix() @ m.to_3x3()).to_4x4()
        nm.translation = p0
        set_m(bone, nm)


def turn(name, axis, deg):
    if name in pbs and deg:
        cur = pbs[name].matrix.copy()
        set_m(name, rot_about(cur.translation, axis, math.radians(deg) * GAIN) @ cur)


def pose(f):
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    w = track(WEIGHT, f)
    k = crouch_k(f)
    drop = (CROUCH_M * k * (1.0 + 0.35 * track(CROUCH_EXTRA, f)) + bounce(f) - 0.004 * breath(f)) * GAIN
    body = pbs["Body"].matrix.copy()
    sway = SIDE * (0.02 * HIP_H * w * GAIN)
    pivot = bones["Hips"].head_local
    roll = math.radians(5.0 * GAIN) * w
    set_m("Body", Matrix.Translation(sway - UP * drop) @ rot_about(pivot, FWD, roll) @ body)
    tp = CROUCH_TORSO * k + track(TORSO_PITCH, f)
    turn("Torso", SIDE, -tp * 0.5)  # a positive turn about SIDE lifts the nose
    turn("Shoulders", SIDE, -tp * 0.5)
    s = sniff_bob(f)
    j = tremor(f)
    turn("Neck", UP, track(NECK_YAW, f) * 0.55)
    turn("Neck", SIDE, -(track(NECK_PITCH, f) * 0.6 - tp * 0.7 + HEAD_LOW * k + 4.0 * s))  # hold the head level over the dipped chest
    turn("Head", UP, track(NECK_YAW, f) * 0.45 + j)
    turn("Head", SIDE, -(track(NECK_PITCH, f) * 0.4 + track(HEAD_PITCH, f) - tp * 0.3 - HEAD_LOW * k + 5.0 * s))
    turn("Head", FWD, -(track(HEAD_ROLL, f) + 0.8 * j))
    if "Jaw" in pbs:  # positive Jaw local X opens (tools/jaw/key_jaw.py)
        jb = pbs["Jaw"]
        cur = jb.matrix.copy()
        x_axis = cur.to_3x3().col[0].normalized()
        set_m("Jaw", rot_about(cur.translation, x_axis, math.radians(track(JAW, f) + 7.0 * max(0.0, s))) @ cur)
    for i, t in enumerate(("Tail1", "Tail2", "Tail3", "Tail4", "Tail5")):
        k = (0.3, 0.28, 0.24, 0.2, 0.16)[i]
        turn(t, UP, track(TAIL_YAW, f) * k + 1.5 * math.sin(2 * math.pi * (2 * f / N + 0.12 * i)))
        turn(t, SIDE, track(TAIL_PITCH, f) * k)
    for s_, sign in (("L", 1.0), ("R", -1.0)):
        turn("FrontUpLeg." + s_, SIDE, track(ARM_PITCH, f))
        turn("FrontUpLeg." + s_, FWD, -sign * track(ARM_SPREAD, f))  # elbows out from the body
        turn("FrontLowLeg." + s_, SIDE, track(ARM_PITCH, f) * 0.5)
    # --heel-roll DEG: per hip height of drop, roll each foot up about its planted toe tip (digitigrade), so a deep
    # crouch lifts the hock instead of folding its skin into the ground (0 = feet flat, the raptor clips).
    pitch = math.radians(HEEL_ROLL) * max(0.0, drop) / HIP_H
    r = Matrix.Rotation(pitch, 4, -SIDE)  # positive = toe down / heel up (make_gait.py toe_pivot)
    for leg in LEGS.values():
        ankle = leg["toe0"] - r.to_3x3() @ (leg["toe0"] - leg["ankle0"])
        solve_leg(leg, ankle)  # toes planted, knees take the crouch
        if pitch:
            fm = r @ bones[leg["foot"]].matrix_local.copy()
            fm.translation = ankle
            set_m(leg["foot"], fm)


arm.animation_data_create()
act = bpy.data.actions.new(CLIP)
arm.animation_data.action = act
for f in range(N + 1):
    pose(f % N if LOOP else f)
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert("location", frame=f)
        pb.keyframe_insert("rotation_quaternion", frame=f)
        pb.keyframe_insert("scale", frame=f)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, N
print("CLIP", CLIP, "frames", N, "seconds", N / FPS)

for o in list(bpy.data.objects):
    if o is not arm:
        bpy.data.objects.remove(o, do_unlink=True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", export_apply=False, export_yup=True,
    use_selection=True, export_animations=True, export_animation_mode="ACTIONS",
    export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
    export_anim_slide_to_zero=False, export_skins=True, export_morph=False,
    export_def_bones=False, export_reset_pose_bones=False, export_current_frame=False,
    export_nla_strips=False, export_anim_single_armature=True, export_bake_animation=True,
    export_materials="NONE", export_image_format="NONE")
print("WROTE", OUT)
