"""Author an in-place leap one-shot for a small biped theropod (Meshy-library / transplant bone names):
hop_back, leap_back, pounce, dodge_left, dodge_right.

Owner 2026-10-28 (compsognathus): "should jump back similar to the deinonychus (far jumps, far pounces, far strafe
jumps, combo moves, it can jump and miss the player)". tools/jaw/make_hop_back.py made the deinonychus leaps, but it
only glues the feet to the shins in the air and leaves the shins stretching to planted feet in the crouch; this one
uses two-bone leg IK (as make_nervous_idle.py) so the feet stay exactly on their prints on the ground and are carried
by the legs in the air.

Phases are the shared anim_events.json ones: crouch 0-0.2, airborne 0.2-0.65 (the game moves the creature over the
ground only inside that window, and lifts it on its own arc, so the feet must be on their rest prints at 0.2 and
0.65), landing squash 0.65-0.8, recovery to the rest pose at 1. The pounce's jaws are open wide in the air and snap
shut at hit_frac 0.7. Rotations are small rest-relative turns, keyed per frame, exported skeleton-only.

usage: Blender -b -P tools/gait/make_leap.py -- <base.glb> <kind> <out.glb> [--frames N] [--gain 1.0]
  kind: hop_back | leap_back | pounce | dodge_left | dodge_right
"""
import math
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, KIND, OUT = argv[:3]
DEFAULT_FRAMES = {"hop_back": 11, "leap_back": 16, "pounce": 18, "dodge_left": 10, "dodge_right": 10}
N = int(argv[argv.index("--frames") + 1]) if "--frames" in argv else DEFAULT_FRAMES[KIND]
GAIN = float(argv[argv.index("--gain") + 1]) if "--gain" in argv else 1.0
FPS = 24
T_OFF, T_LAND, T_SETTLE, HIT = 0.2, 0.65, 0.8, 0.7

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
pbs, bones = arm.pose.bones, arm.data.bones
FWD, UP = Vector((0, -1, 0)), Vector((0, 0, 1))
SIDE = FWD.cross(UP).normalized()  # the animal's right
LEN = max(b.head_local.y for b in bones) - min(b.head_local.y for b in bones)
S = LEN / 1.6 * GAIN  # distances below are for a 1.6-unit-long rig

back = KIND in ("hop_back", "leap_back")
fwd = KIND == "pounce"
side = 0.0 if not KIND.startswith("dodge") else (-1.0 if KIND == "dodge_left" else 1.0)  # +1 = to its right
big = 1.35 if KIND in ("leap_back", "pounce") else 1.0  # the long leaps crouch deeper and tuck higher
TRAVEL = (-FWD if back else FWD if fwd else SIDE * side)  # where the game carries the body during the air


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def rot_about(p, axis, ang):
    return Matrix.Translation(p) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-p)


def phase(u):
    """crouch depth c (0..1), airborne a (0..1 sine over the flight), landing squash l (0..1), flight progress s."""
    if u < T_OFF:
        return smooth(u / T_OFF), 0.0, 0.0, 0.0
    if u < T_LAND:
        s = (u - T_OFF) / (T_LAND - T_OFF)
        return 1.0 - smooth(s / 0.3), math.sin(math.pi * s), 0.0, s  # push off out of the crouch
    if u < T_SETTLE:
        return 0.0, 0.0, math.sin(math.pi * 0.5 * (u - T_LAND) / (T_SETTLE - T_LAND)), 1.0
    return 0.0, 0.0, 1.0 - smooth((u - T_SETTLE) / (1.0 - T_SETTLE)), 1.0


LEGS = {}
for sd in "LR":
    up, low, foot = "BackUpLeg." + sd, "BackLowLeg." + sd, "BackFoot." + sd
    h, k, an = bones[up].head_local, bones[low].head_local, bones[foot].head_local
    line = an - h
    off = (k - h) - line * ((k - h).dot(line) / line.length_squared)
    LEGS[sd] = {"up": up, "low": low, "foot": foot, "l1": bones[up].length, "l2": (k - an).length,
                "pole": off.normalized(), "ankle0": an.copy(), "x": 1.0 if an.x > 0 else -1.0,
                "toe0": bones[foot + "_end"].tail_local.copy()}


def set_m(name, m):
    pbs[name].matrix = m
    bpy.context.view_layer.update()


def turn(name, axis, deg):
    if name in pbs and deg:
        cur = pbs[name].matrix.copy()
        set_m(name, rot_about(cur.translation, axis, math.radians(deg) * GAIN) @ cur)


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
    return h + u * d  # where the ankle really got to (a clamped reach in the air)


def pose(f):
    u = f / N
    c, a, land, s = phase(u)
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    crouch = c * 0.045 * S * big + land * 0.035 * S * big
    rise = a * 0.02 * S  # the game lifts the whole body on its own arc (leap_height_per_m); this is the stretch
    # Body pitch (+ = nose up): hops lean back into the push and land nose-up; the pounce dives nose-first and
    # pulls up for the landing; a dodge banks into the direction of travel instead.
    if back:
        pitch = 6 * c + 16 * big * a - 4 * land
    elif fwd:
        pitch = -8 * c - 14 * a * (1 - s) + 10 * a * s - 6 * land
    else:
        pitch = -3 * c
    roll = side * (-5 * c + 18 * a - 4 * land) if side else 0.0  # + side (right): roll right = lean right
    body = pbs["Body"].matrix.copy()
    piv = bones["Hips"].head_local.copy()
    lean = TRAVEL * (0.02 * S * c)  # load the push: the hips shift towards the jump before take-off
    m = Matrix.Translation(UP * (rise - crouch) + lean) @ rot_about(piv, SIDE, math.radians(pitch * GAIN)) \
        @ rot_about(piv, FWD, math.radians(roll * GAIN)) @ body
    set_m("Body", m)
    # spine and neck keep the head steady and on the prey (the game faces the body at it)
    turn("Torso", SIDE, -pitch * 0.15)
    turn("Neck", SIDE, -pitch * 0.35 + (-10 * a if fwd else 0.0))
    turn("Head", SIDE, -pitch * 0.25 + (-8 * a if fwd else 6 * c if back else 0.0))
    turn("Neck", FWD, -roll * 0.5)
    turn("Head", FWD, -roll * 0.3)
    if "Jaw" in pbs:  # positive Jaw local X opens (tools/jaw/key_jaw.py)
        if fwd:  # wide in the air, snap shut on the hit, a small parted recovery
            open_deg = 28 * smooth((u - 0.1) / 0.2) * (1 - smooth((u - (HIT - 0.06)) / 0.06)) + 6 * land
        elif back:
            open_deg = 10 * a  # a hiss on the way out
        else:
            open_deg = 4 * a
        jb = pbs["Jaw"]
        cur = jb.matrix.copy()
        set_m("Jaw", rot_about(cur.translation, cur.to_3x3().col[0].normalized(), math.radians(open_deg * GAIN)) @ cur)
    # tail: the counterweight. Up and stiff in the air, swinging against a bank.
    for i, t in enumerate(("Tail1", "Tail2", "Tail3", "Tail4", "Tail5")):
        k = (0.3, 0.25, 0.2, 0.15, 0.1)[i]
        # a negative turn about SIDE lifts the tail; it also cancels most of the body's nose-up pitch so the tip
        # never swings down into the ground
        turn(t, SIDE, -(10 * a * big + 4 * c) * k * (1 if not fwd else 1.4) * (1 if i < 3 else 0.6) - max(0.0, pitch) * 0.9 * k / 0.3 * (1 if i < 2 else 0.4))
        if side:
            turn(t, UP, side * 30 * a * k)
    # arms: tucked to the chest on the hops, thrown forward to grab on the pounce
    for sd in "LR":
        turn("FrontUpLeg." + sd, SIDE, (40 * a + 10 * c) if fwd else (-25 * a))
        turn("FrontLowLeg." + sd, SIDE, (20 * a) if fwd else (-15 * a))
    # hind legs: planted on their rest prints on the ground; in the air carried up into a tuck and, for the
    # pounce, trailing back from the push then reaching forward to land; hops reach back (the landing side).
    for leg in LEGS.values():
        lift = a * 0.14 * S * big
        if fwd:
            swing = FWD * (0.07 * S * (math.cos(math.pi * s) * -1.0)) * a  # trail back early, reach ahead late
        elif back:
            swing = -FWD * (0.05 * S * s) * a
        else:
            # the push leg (away from the travel) trails, the lead leg reaches; both lift
            swing = SIDE * side * (0.03 * S) * a
            lift *= 0.8 if leg["x"] * side > 0 else 1.0
        # On the ground a crouch rolls the foot heel-up about the planted toe tip (digitigrade), so the ankle skin
        # never folds into the ground and the toes stay on their print.
        heel = rot_about(leg["toe0"], SIDE, math.radians(-(22 * c + 18 * land) * big * GAIN))
        ankle = heel @ leg["ankle0"] + UP * lift + swing
        got = solve_leg(leg, ankle)
        fm = heel @ pbs[leg["foot"]].matrix.copy()
        fm.translation = got
        if a > 0:  # toes hang a little in the air
            fm = rot_about(got, SIDE, math.radians(-12 * a)) @ fm
        set_m(leg["foot"], fm)


arm.animation_data_create()
act = bpy.data.actions.new(KIND)
arm.animation_data.action = act
for f in range(N + 1):
    pose(f)
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert("location", frame=f)
        pb.keyframe_insert("rotation_quaternion", frame=f)
        pb.keyframe_insert("scale", frame=f)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, N
print(f"LEAP {KIND} {N} frames at {FPS} fps ({N / FPS:.3f} s), airborne {T_OFF}-{T_LAND}, hit {HIT}")

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
