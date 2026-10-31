"""SP-RAPTOR signature moves on the Raptor's transplant rig (Quaternius Velociraptor bone names: Body/Hips/Torso/
Shoulders/Neck/Head/Jaw, BackLeg/BackUpLeg/BackLowLeg + root-parented BackFoot, FrontLeg/FrontUpLeg/FrontLowLeg/
FrontFoot, Tail1-5). Same method as make_investigate_idle.py: small rest-relative turns keyed per frame, the stance
foot planted on its print with two-bone leg IK, exported skeleton-only.

Owner 2026-10-30: "be creative with what moves you think they should do when they fight". # ASSUMPTION (no PRD clip
list for the Raptor), true to a big dromaeosaur:
  pin_stab      2.4 s, hits 0.38 and 0.74 (anim_events pin_stab): the RPR hold ("raptor prey restraint", how
                Deinonychus is thought to have killed). After a landed pounce the right foot stamps onto the prey and
                holds it down with the sickle claw, the arms flap wide for balance (stability flapping, the gold fans
                beating), and the head rears with the jaws wide and drives down to bite twice, tugging after each.
  attack_heavy  1.42 s, windup hold 0.6, hit 0.72 (anim_events attack_heavy): the sickle slash. It rocks onto the
                left leg with the right foot hauled high and the sickle claw cocked up (the telegraph), arms flared for
                balance and the jaws hissing, then drives the foot forward and down through the prey and rakes it back.
  alert         1.67 s: the crest-flare display. It rears, throws the feathered arms wide and the tail up, screeches
                with a head shake, then drops into a low hunting crouch. TacticalBrain's display step plays it.

usage: Blender -b -P tools/gait/make_raptor_moves.py -- <base.glb> <clip> <out.glb> [--gain 1.0]
  sleep         3.0 s loop: lying belly-down with the legs folded under, the head curled back along its left flank
                and resting on the floor, the tail curled round, slow breaths (the velociraptor's sleep did not
                survive the move onto this body: it sank 0.7 m).

  clip: pin_stab | attack_heavy | alert | sleep
"""
import math
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, CLIP, OUT = argv[:3]
GAIN = float(argv[argv.index("--gain") + 1]) if "--gain" in argv else 1.0
FPS = 24
SECONDS = {"pin_stab": 2.4, "attack_heavy": 1.42, "alert": 1.67, "sleep": 3.0}[CLIP]
N = int(round(SECONDS * FPS))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
pbs, bones = arm.pose.bones, arm.data.bones
FWD, UP = Vector((0, -1, 0)), Vector((0, 0, 1))
SIDE = FWD.cross(UP).normalized()  # the animal's right
HIP_H = bones["BackUpLeg.L"].head_local.z


def rot_about(p, axis, ang):
    return Matrix.Translation(p) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-p)


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def track(keys, u):
    """keys: [(u, value), ...] sorted by u; smoothstep between neighbours, held outside."""
    if u <= keys[0][0]:
        return keys[0][1]
    for (u0, v0), (u1, v1) in zip(keys, keys[1:]):
        if u <= u1:
            return v0 + (v1 - v0) * smooth((u - u0) / max(u1 - u0, 1e-6))
    return keys[-1][1]


Z = [(0.0, 0.0)]
# Each clip: tracks in fractions of the clip. Distances in hip heights, angles in degrees.
#   drop / fwd / sway (+ = to its right): the Body; torso (+ = nose down); neck_p, head_p (+ = nose down);
#   neck_y (+ = to its left), head_r (+ = tilt left); jaw (open); tail_p (+ = tail up), tail_y; arm_out (spread),
#   arm_up (swung forward and up), flap (beat amplitude, flap_hz beats per second inside flap_on);
#   rf_fwd / rf_up / rf_pitch (+ = toe down): the right foot's target; lf_* the left's (default: on its print).
if CLIP == "pin_stab":
    T = dict(
        drop=[(0, 0), (.14, .14), (.30, .10), (.38, .22), (.50, .16), (.64, .10), (.74, .22), (.86, .14), (1, 0)],
        fwd=[(0, 0), (.14, .16), (.86, .16), (1, 0)],
        sway=[(0, 0), (.12, -.06), (.88, -.06), (1, 0)],
        torso=[(0, 0), (.14, 14), (.30, 4), (.38, 28), (.50, 16), (.64, 4), (.74, 30), (.86, 14), (1, 0)],
        neck_p=[(0, 0), (.14, 10), (.22, -22), (.31, -26), (.38, 58), (.44, 50), (.52, 36), (.60, -18), (.67, -22),
                (.74, 64), (.80, 54), (.88, 30), (1, 0)],
        head_p=[(0, 0), (.22, -8), (.31, -12), (.38, 26), (.52, 14), (.60, -10), (.67, -12), (.74, 28), (.88, 12), (1, 0)],
        neck_y=[(0, 0), (.44, 0), (.47, 10), (.50, -10), (.53, 0), (.80, 0), (.83, -12), (.86, 12), (.89, 0), (1, 0)],
        head_r=[(0, 0), (.44, 0), (.47, 18), (.50, -18), (.53, 6), (.80, 0), (.83, -20), (.86, 20), (.89, 0), (1, 0)],
        jaw=[(0, 0), (.20, 38), (.33, 42), (.38, 4), (.41, 2), (.56, 4), (.62, 40), (.70, 44), (.74, 4), (.78, 2), (1, 0)],
        tail_p=[(0, 0), (.14, 10), (.38, 4), (.74, 4), (.86, 10), (1, 0)],
        tail_y=[(0, 0), (.25, 10), (.45, -10), (.65, 8), (.85, -8), (1, 0)],
        arm_out=[(0, 0), (.12, 42), (.88, 42), (1, 0)],
        arm_up=[(0, 0), (.12, 24), (.88, 24), (1, 0)],
        flap=[(0, 0), (.12, 18), (.40, 24), (.76, 24), (.88, 12), (1, 0)],
        rf_fwd=[(0, 0), (.07, .38), (.14, .62), (.86, .62), (.93, .30), (1, 0)],
        rf_up=[(0, 0), (.07, .42), (.14, .16), (.86, .16), (.93, .30), (1, 0)],
        rf_pitch=[(0, 0), (.07, -20), (.14, 28), (.86, 28), (.93, -10), (1, 0)],
    )
    FLAP_HZ, FLAP_ON = 3.0, (0.10, 0.90)
elif CLIP == "attack_heavy":
    T = dict(
        drop=[(0, 0), (.30, .10), (.60, .12), (.68, .02), (.80, .06), (1, 0)],
        fwd=[(0, 0), (.30, -.06), (.60, -.08), (.70, .26), (.80, .20), (1, 0)],
        sway=[(0, 0), (.25, -.09), (.60, -.10), (.72, -.04), (1, 0)],
        torso=[(0, 0), (.30, -10), (.60, -12), (.70, 16), (.82, 10), (1, 0)],
        neck_p=[(0, 0), (.30, -12), (.60, -14), (.70, 18), (.82, 10), (1, 0)],
        head_p=[(0, 0), (.30, -4), (.60, -6), (.70, 8), (1, 0)],
        neck_y=Z, head_r=[(0, 0), (.40, 6), (.50, -6), (.60, 0), (1, 0)],
        jaw=[(0, 0), (.20, 26), (.60, 30), (.70, 14), (.85, 6), (1, 0)],
        tail_p=[(0, 0), (.30, 14), (.60, 16), (.72, -4), (1, 0)],
        tail_y=[(0, 0), (.30, -8), (.60, -8), (.72, 10), (1, 0)],
        arm_out=[(0, 0), (.25, 55), (.60, 60), (.72, 30), (.90, 8), (1, 0)],
        arm_up=[(0, 0), (.25, 30), (.60, 34), (.72, 10), (1, 0)],
        flap=[(0, 0), (.30, 6), (.60, 6), (.66, 0), (1, 0)],
        rf_fwd=[(0, 0), (.30, .10), (.60, .12), (.71, 1.05), (.82, .55), (.94, .10), (1, 0)],
        rf_up=[(0, 0), (.30, .58), (.60, .62), (.71, .30), (.82, .12), (.90, .14), (1, 0)],
        rf_pitch=[(0, 0), (.30, -42), (.60, -48), (.71, 46), (.82, 8), (1, 0)],
    )
    FLAP_HZ, FLAP_ON = 6.0, (0.25, 0.60)
elif CLIP == "sleep":
    B = lambda a: [(0, 0), (.5, a), (1, 0)]  # one slow breath per half: seamless
    T = dict(
        drop=[(0, .80), (.25, .81), (.5, .80), (.75, .81), (1, .80)], fwd=[(0, -.10)], sway=Z,
        torso=[(0, 6)], neck_p=[(0, 62)], head_p=[(0, 16)], neck_y=[(0, 24)], head_r=[(0, -10)],
        jaw=Z, tail_p=[(0, -6)], tail_y=[(0, 34)], arm_out=[(0, -6)], arm_up=[(0, -18)], flap=Z,
        rf_fwd=[(0, -.30)], rf_up=[(0, .02)], rf_pitch=[(0, -8)],
        lf_fwd=[(0, -.30)], lf_up=[(0, .02)], lf_pitch=[(0, -8)],
    )
    FLAP_HZ, FLAP_ON = 1.0, (0.0, 0.0)
else:  # alert: the crest-flare display
    T = dict(
        drop=[(0, 0), (.22, -.01), (.65, -.01), (.85, .16), (1, .16)],
        fwd=[(0, 0), (.22, -.05), (.65, -.05), (.85, .04), (1, .04)],
        sway=Z,
        torso=[(0, 0), (.22, -18), (.65, -18), (.85, 6), (1, 6)],
        neck_p=[(0, 0), (.22, -22), (.30, -26), (.65, -20), (.85, 12), (1, 12)],
        head_p=[(0, 0), (.22, -6), (.65, -6), (.85, -12), (1, -12)],
        neck_y=[(0, 0), (.30, 0), (.40, 12), (.50, -12), (.60, 0), (1, 0)],
        head_r=[(0, 0), (.30, 0), (.34, 14), (.38, -14), (.42, 14), (.46, -14), (.50, 10), (.54, -10), (.60, 0), (1, 0)],
        jaw=[(0, 0), (.22, 10), (.30, 46), (.58, 46), (.70, 10), (1, 8)],
        tail_p=[(0, 0), (.22, 18), (.65, 18), (.85, 2), (1, 2)],
        tail_y=[(0, 0), (.30, 12), (.40, -12), (.50, 12), (.60, -12), (.75, 0), (1, 0)],
        arm_out=[(0, 0), (.22, 70), (.65, 70), (.85, 6), (1, 6)],
        arm_up=[(0, 0), (.22, 38), (.65, 38), (.85, 4), (1, 4)],
        flap=[(0, 0), (.22, 8), (.60, 8), (.66, 0), (1, 0)],
        rf_fwd=Z, rf_up=Z, rf_pitch=Z,
    )
    FLAP_HZ, FLAP_ON = 5.0, (0.20, 0.62)


def flap(u):
    a, b = FLAP_ON
    if u <= a or u >= b:
        return 0.0
    return track(T["flap"], u) * math.sin(2 * math.pi * FLAP_HZ * (u - a) * SECONDS)


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
    for bone, p0, p1 in ((up, h, knee), (low, knee, h + u * d)):
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
    u = f / N
    g = lambda k: track(T[k], u) * GAIN
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    body = pbs["Body"].matrix.copy()
    move = FWD * (g("fwd") * HIP_H) + SIDE * (g("sway") * HIP_H) - UP * (g("drop") * HIP_H)
    set_m("Body", Matrix.Translation(move) @ body)
    tp = g("torso")
    turn("Torso", SIDE, -tp * 0.5)  # a positive turn about SIDE lifts the nose
    turn("Shoulders", SIDE, -tp * 0.5)
    turn("Neck", UP, g("neck_y") * 0.55)
    turn("Neck", SIDE, -(g("neck_p") * 0.6 - tp * 0.7))
    turn("Head", UP, g("neck_y") * 0.45)
    turn("Head", SIDE, -(g("neck_p") * 0.4 + g("head_p") - tp * 0.3))
    turn("Head", FWD, -g("head_r"))
    if "Jaw" in pbs:  # positive Jaw local X opens (tools/jaw/key_jaw.py)
        cur = pbs["Jaw"].matrix.copy()
        set_m("Jaw", rot_about(cur.translation, cur.to_3x3().col[0].normalized(), math.radians(g("jaw"))) @ cur)
    for i, t in enumerate(("Tail1", "Tail2", "Tail3", "Tail4", "Tail5")):
        k = (0.3, 0.26, 0.2, 0.14, 0.1)[i]
        turn(t, UP, g("tail_y") * k * 1.6)
        turn(t, SIDE, -(g("tail_p") - tp * (0.6 if i == 0 else 0.0)) * k * 1.6)  # tail up = nose-down turn reversed
    fl = flap(u) * GAIN
    for s_, sign in (("L", 1.0), ("R", -1.0)):
        out = g("arm_out") + fl
        turn("FrontLeg." + s_, SIDE, g("arm_up") * 0.6 + fl * 0.3)  # swing the arm forward and up
        turn("FrontLeg." + s_, FWD, -sign * out * 0.7)  # elbows out: the feather fans open
        turn("FrontUpLeg." + s_, FWD, -sign * out * 0.3)
        turn("FrontLowLeg." + s_, SIDE, -g("arm_up") * 0.5)  # hands curl in as the arms rise
    for s_, leg in LEGS.items():
        k = s_.lower() + "f_"
        gl = lambda n: g(k + n) if k + n in T else 0.0
        if gl("fwd") or gl("up") or gl("pitch"):
            ankle = leg["ankle0"] + FWD * (gl("fwd") * HIP_H) + UP * (gl("up") * HIP_H)
            fm = rot_about(Vector(), SIDE, -math.radians(gl("pitch"))) @ bones[leg["foot"]].matrix_local.copy()
            fm.translation = ankle
            set_m(leg["foot"], fm)
            solve_leg(leg, ankle)
        else:
            solve_leg(leg, leg["ankle0"])  # planted on its print, the knee takes the crouch


arm.animation_data_create()
act = bpy.data.actions.new(CLIP)
arm.animation_data.action = act
for f in range(N + 1):
    pose(f)
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
