"""Author an exaggerated "curious and jumpy" idle loop for a small theropod (Meshy-library biped bone names).

Owner 2026-10-28 (compsognathus): "idle animation for this should be exaggerated curiousity and jumpy nervousness".
Bird-like darting head glances and tilts held between snaps, neck craning to peer, a sniff with the snout and jaw,
weight shifting foot to foot, tail twitches, and one startled hop. Feet stay planted (two-bone leg IK onto the
root-parented feet) except during the hop, where both feet leave and land on their own footprints. The pose at the
last frame equals the first, so the loop is seamless. Rotations are small rest-relative turns, keyed per frame,
exported skeleton-only like make_gait.py.

usage: Blender -b -P tools/gait/make_nervous_idle.py -- <base.glb> <out.glb> [--seconds 3.5] [--gain 1.0]
"""
import math
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, OUT = argv[:2]
SECONDS = float(argv[argv.index("--seconds") + 1]) if "--seconds" in argv else 3.5
GAIN = float(argv[argv.index("--gain") + 1]) if "--gain" in argv else 1.0
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


# ---- the performance, in fractions of the loop (degrees / metres before GAIN) -------------------------------
# neck yaw (+ = turn to its left), neck pitch (+ = nose down), head roll (+ = tilt to its left)
NECK_YAW = [(0, 0, 1), (at(.06), 28, 3), (at(.20), -32, 3), (at(.30), -32, 1), (at(.34), 6, 4), (at(.52), 6, 1),
            (at(.58), 0, 2), (at(.70), 22, 3), (at(.82), -10, 3), (at(.97), 0, 5), (N, 0, 1)]
NECK_PITCH = [(0, 0, 1), (at(.06), -8, 3), (at(.20), -4, 3), (at(.34), 26, 5), (at(.48), 26, 1), (at(.56), -18, 2),
              (at(.64), -18, 1), (at(.72), -12, 4), (at(.97), 0, 5), (N, 0, 1)]
HEAD_ROLL = [(0, 0, 1), (at(.07), 24, 2), (at(.13), 24, 1), (at(.15), -6, 2), (at(.21), -30, 2), (at(.28), -30, 1),
             (at(.34), 0, 3), (at(.70), 0, 1), (at(.73), 20, 2), (at(.80), 20, 1), (at(.83), -14, 2), (at(.97), 0, 4), (N, 0, 1)]
TORSO_PITCH = [(0, 0, 1), (at(.20), 0, 1), (at(.34), 10, 5), (at(.48), 10, 1), (at(.56), -8, 2), (at(.72), -4, 4),
               (at(.97), 0, 6), (N, 0, 1)]  # crane forward to peer and sniff, then rear up when startled
HOP_Z = [(0, 0, 1), (at(.52), 0, 1), (at(.535), -0.012, 1.5), (at(.565), 0.035, 2), (at(.585), 0.035, 0.5),
         (at(.615), -0.016, 2), (at(.66), 0, 4), (N, 0, 1)]  # crouch, hop, land, settle (x LEN / 1.6)
FEET_Z = [(0, 0, 1), (at(.54), 0, 1), (at(.565), 0.026, 1.5), (at(.585), 0.026, 0.5), (at(.61), 0, 1.5), (N, 0, 1)]
TAIL_YAW = [(0, 0, 1), (at(.10), 14, 2), (at(.16), -10, 2), (at(.22), 0, 3), (at(.555), 0, 1), (at(.57), 22, 1),
            (at(.60), -16, 2), (at(.66), 6, 3), (at(.76), 0, 4), (at(.86), -12, 2), (at(.90), 8, 2), (at(.97), 0, 3), (N, 0, 1)]
TAIL_PITCH = [(0, 0, 1), (at(.54), 0, 1), (at(.57), -14, 1.5), (at(.66), -4, 4), (at(.80), 0, 5), (N, 0, 1)]  # flicks up
ARM_PITCH = [(0, 0, 1), (at(.54), 0, 1), (at(.565), -28, 1.5), (at(.64), -10, 4), (at(.80), 0, 5), (N, 0, 1)]  # startle


def sniff(f):  # quick snout bobs while craned down, with the jaw working
    u = (f - at(.36)) / (at(.50) - at(.36))
    return 0.0 if u <= 0 or u >= 1 else math.sin(math.pi * u) * math.sin(2 * math.pi * 7 * u)


def weight(f):  # body shifts onto one foot then the other, once per loop
    return math.sin(2 * math.pi * f / N)


# ---- legs: analytic two-bone IK (as make_gait.py) -------------------------------------------------------------
LEGS = {}
for s in "LR":
    up, low, foot = "BackUpLeg." + s, "BackLowLeg." + s, "BackFoot." + s
    h, k, an = bones[up].head_local, bones[low].head_local, bones[foot].head_local
    line = an - h
    off = (k - h) - line * ((k - h).dot(line) / line.length_squared)
    LEGS[s] = {"up": up, "low": low, "foot": foot, "l1": bones[up].length, "l2": (k - an).length,
               "pole": off.normalized(), "ankle0": an.copy()}


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
    scale = LEN / 1.6
    w = weight(f)
    hop = track(HOP_Z, f) * scale * GAIN
    body = pbs["Body"].matrix.copy()
    sway = SIDE * (0.018 * scale * w * GAIN)
    pivot = bones["Hips"].head_local
    roll = math.radians(4.0 * GAIN) * w
    set_m("Body", Matrix.Translation(sway + UP * hop) @ rot_about(pivot, FWD, roll) @ body)
    turn("Torso", SIDE, -track(TORSO_PITCH, f) * 0.5)  # a positive turn about SIDE lifts the nose
    turn("Shoulders", SIDE, -track(TORSO_PITCH, f) * 0.5)
    s = sniff(f)
    turn("Neck", UP, track(NECK_YAW, f) * 0.55)
    turn("Neck", SIDE, -(track(NECK_PITCH, f) * 0.6 + 4.0 * s))
    turn("Head", UP, track(NECK_YAW, f) * 0.45)
    turn("Head", SIDE, -(track(NECK_PITCH, f) * 0.4 + 5.0 * s))
    turn("Head", FWD, -track(HEAD_ROLL, f))
    if "Jaw" in pbs:  # positive Jaw local X opens (tools/jaw/key_jaw.py); sniff = quick small gapes
        jb = pbs["Jaw"]
        cur = jb.matrix.copy()
        x_axis = cur.to_3x3().col[0].normalized()
        set_m("Jaw", rot_about(cur.translation, x_axis, math.radians(6.0 * max(0.0, s))) @ cur)
    for i, t in enumerate(("Tail1", "Tail2", "Tail3", "Tail4")):
        k = (0.35, 0.3, 0.25, 0.2)[i]
        turn(t, UP, track(TAIL_YAW, f) * k + 3.0 * math.sin(2 * math.pi * (f / N + 0.15 * i)))
        turn(t, SIDE, track(TAIL_PITCH, f) * k)
    for s_ in "LR":
        turn("FrontUpLeg." + s_, SIDE, track(ARM_PITCH, f))
    lift = track(FEET_Z, f) * scale * GAIN
    for leg in LEGS.values():
        ankle = leg["ankle0"] + UP * lift
        fm = pbs[leg["foot"]].matrix.copy()
        fm.translation = fm.translation + UP * lift
        set_m(leg["foot"], fm)
        solve_leg(leg, ankle)


arm.animation_data_create()
act = bpy.data.actions.new("idle")
arm.animation_data.action = act
for f in range(N + 1):
    pose(f % N)
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert("location", frame=f)
        pb.keyframe_insert("rotation_quaternion", frame=f)
        pb.keyframe_insert("scale", frame=f)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, N
print("IDLE frames", N, "seconds", N / FPS)

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
