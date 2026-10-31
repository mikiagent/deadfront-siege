"""RAPTORFLANK (owner 2026-10-31: "Slate Raptor needs to be moving its arms as part of the attack ... I think the
animations are weird on this one"). Rework a Raptor clip on its own rig: keep its legs, Body and neck/head, and
re-author what read wrong on the transferred deinonychus clips:
  - arms: on this rig the arms (FrontLeg.*) hang from Body, not from the chest, so a torso pitch left them behind;
    they are first glued to the chest (Shoulders), then keyed: grab forward with the hand claws open, rake down and
    back with the claws clenched on the hit, flare wide for balance in the air.
  - tail: the deinonychus tail turns came across as a scorpion flick (straight up in the bite, combo, pounce, leaps);
    the tail is reset to rest and keyed as small counter-balance turns.
  - spine: a little torso / neck motion where the clip had none (the leaps were frozen from the hips up).
Each clip's tracks are fractions of the clip (smoothstep between keys), angles in degrees, as make_raptor_moves.py.
Arm tracks: arm_up (+ = swung forward and up), arm_out (+ = elbows out, fans open), elbow (+ = forearm folds),
hand (+ = claws clench, - = claws spread forward); a _L / _R suffix overrides one side. Tail: tail_p (+ = up),
tail_y (+ = tip to its right). torso (+ = nose down, added to the clip's), neck_p (+ = nose down). keep_arms: add the arm
turns on top of the clip's own (the combo's step-in swings the thigh into the arm skin, which tore 21x at rest arms);
keep_tail: leave the clip's tail (lying clips).

usage: Blender -b -P tools/gait/raptor_overlay.py -- <base.glb> <clip.glb> <out.glb> [--clip SPEC] [--name NAME] [--keep] [--arm-gain K] [--shoulder K]
  --clip: which spec (default: the file name); --name: the exported clip's name (default: the spec);
  --keep: add the arm turns on top of the clip's own arms and keep its tail (UTAHARMS, owner 2026-10-31: the
          utahraptor "is in a pretty good state, it just needs to use its arms in the attacks too sometimes":
          grab_bite = its attack_primary with the raptor's grab-and-rake, and its bite_combo gets the arm rakes).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, SRC, OUT = argv[:3]
CLIP = argv[argv.index("--clip") + 1] if "--clip" in argv else os.path.splitext(os.path.basename(SRC))[0]
NAME = argv[argv.index("--name") + 1] if "--name" in argv else CLIP
SHOULDER = float(argv[argv.index("--shoulder") + 1]) if "--shoulder" in argv else 1.0  # share of the swing on FrontLeg (the shoulder root, which drags the chest skin); the rest goes to the upper arm
ARM_GAIN = float(argv[argv.index("--arm-gain") + 1]) if "--arm-gain" in argv else 1.0  # utahraptor: its arm skin stretches sooner
Z = [(0, 0)]
# hit fractions (anim_events.json): attack_primary 0.42; bite_combo 0.092 0.338 0.815; pounce airborne 0.2-0.65, hit 0.7;
# hop_back / leap_back / dodge_* airborne 0.2-0.65.
AIR_FLARE = dict(arm_up=[(0, 0), (.15, -16), (.24, 34), (.55, 30), (.7, 8), (1, 0)],
                 arm_out=[(0, 0), (.15, 8), (.24, 52), (.55, 50), (.72, 14), (1, 0)],
                 elbow=[(0, 0), (.15, 20), (.26, -14), (.55, -10), (.72, 10), (1, 0)],
                 hand=[(0, 0), (.24, -28), (.55, -24), (.72, 8), (1, 0)],
                 tail_p=[(0, 0), (.15, -6), (.3, 12), (.6, 8), (.75, -4), (1, 0)],
                 torso=[(0, 0), (.15, 6), (.3, -6), (.6, -4), (.75, 6), (1, 0)])
SPECS = {
    # the step-in bite: both hands reach forward with the claws spread as the head shoots out, then rake down and
    # back through the prey on the bite and clench.
    "attack_primary": dict(
        arm_up=[(0, 0), (.18, 20), (.36, 72), (.44, 58), (.58, 2), (.78, 2), (1, 0)],
        arm_out=[(0, 0), (.30, 18), (.44, 10), (.6, 4), (1, 0)],
        elbow=[(0, 0), (.30, -30), (.40, -26), (.52, 34), (.7, 18), (1, 0)],
        hand=[(0, 0), (.30, -46), (.40, -40), (.48, 58), (.7, 40), (1, 0)],
        tail_p=[(0, 0), (.3, 6), (.45, -4), (.7, 4), (1, 0)],
        tail_y=[(0, 0), (.3, -6), (.55, 8), (1, 0)]),
    # three bites: left hand rakes on the first, right on the second, both on the third.
    "bite_combo": dict(
        keep_arms=True,  # added on top of the transferred arm turns: they keep the arm skin on the thigh it touches
        arm_up_L=[(0, 0), (.05, 44), (.10, 28), (.17, 6), (.24, 14), (.30, 24), (.40, 10), (.66, 26), (.79, 50),
                  (.84, 26), (.93, 12), (1, 0)],
        arm_up_R=[(0, 0), (.06, 10), (.20, 16), (.30, 50), (.35, 38), (.43, 6), (.52, 10), (.66, 26), (.79, 50),
                  (.84, 26), (.93, 12), (1, 0)],
        arm_out=[(0, 0), (.1, 16), (.34, 16), (.82, 24), (1, 0)],
        elbow_L=[(0, 0), (.06, -18), (.12, 14), (.24, 6), (.70, -8), (.80, -14), (.88, 8), (1, 0)],
        elbow_R=[(0, 0), (.20, 0), (.30, -16), (.38, 14), (.50, 6), (.70, -8), (.80, -14), (.88, 8), (1, 0)],
        hand_L=[(0, 0), (.06, -44), (.11, 56), (.24, 20), (.72, -10), (.80, -44), (.86, 60), (1, 0)],
        hand_R=[(0, 0), (.24, 0), (.30, -44), (.36, 56), (.50, 20), (.72, -10), (.80, -44), (.86, 60), (1, 0)],
        tail_p=[(0, 0), (.1, 4), (.34, 4), (.82, 6), (1, 0)],
        tail_y=[(0, 0), (.09, 8), (.34, -8), (.6, 0), (.82, 6), (1, 0)]),
    # the pounce: arms tucked in the crouch, thrown forward and wide in the air with the claws spread, clamped shut
    # on the prey on the hit (0.7) and held there as it lands.
    "pounce": dict(
        arm_up=[(0, 0), (.16, -18), (.26, 46), (.50, 78), (.66, 70), (.72, 24), (.85, 10), (1, 0)],
        arm_out=[(0, 0), (.16, 0), (.30, 40), (.55, 46), (.68, 22), (.75, 10), (1, 0)],
        elbow=[(0, 0), (.16, 26), (.28, -24), (.6, -30), (.70, 30), (.85, 24), (1, 0)],
        hand=[(0, 0), (.20, 6), (.30, -48), (.62, -52), (.70, 64), (.90, 50), (1, 0)],
        tail_p=[(0, 0), (.16, -6), (.30, 10), (.6, 6), (.72, -2), (1, 0)],
        torso=[(0, 0), (.16, 6), (.30, -8), (.62, 4), (.72, 10), (1, 0)],
        neck_p=[(0, 0), (.30, -8), (.62, 6), (.72, 12), (1, 0)]),
    "hop_back": AIR_FLARE,
    "leap_back": AIR_FLARE,
    "dodge_left": dict(AIR_FLARE, tail_y=[(0, 0), (.2, 0), (.35, 18), (.6, 14), (.8, 0), (1, 0)],
                       arm_out_L=[(0, 0), (.15, 8), (.24, 62), (.55, 58), (.72, 14), (1, 0)]),
    "dodge_right": dict(AIR_FLARE, tail_y=[(0, 0), (.2, 0), (.35, -18), (.6, -14), (.8, 0), (1, 0)],
                        arm_out_R=[(0, 0), (.15, 8), (.24, 62), (.55, 58), (.72, 14), (1, 0)]),
    # struck: the arms jerk out and the claws splay, then fold back.
    "hit_react": dict(arm_up=[(0, 0), (.2, 30), (.5, 16), (1, 0)], arm_out=[(0, 0), (.2, 44), (.55, 20), (1, 0)],
                      elbow=[(0, 0), (.2, -20), (1, 0)], hand=[(0, 0), (.2, -40), (.6, -10), (1, 0)],
                      tail_p=[(0, 0), (.2, 10), (.6, 2), (1, 0)], tail_y=[(0, 0), (.25, 10), (.6, -4), (1, 0)]),
    # thrown down: the arms fling out as it goes over, then fold limp on the ground (lying tail kept).
    "knockdown": dict(keep_tail=True, arm_up=[(0, 0), (.15, 40), (.35, 30), (.55, -4), (1, -4)],
                      arm_out=[(0, 0), (.15, 50), (.35, 40), (.55, 10), (1, 10)],
                      elbow=[(0, 0), (.15, -20), (.55, 28), (1, 28)], hand=[(0, 0), (.15, -40), (.55, 30), (1, 30)]),
    "death": dict(keep_tail=True, arm_up=[(0, 0), (.2, 36), (.45, 20), (.7, -4), (1, -4)],
                  arm_out=[(0, 0), (.2, 44), (.45, 30), (.7, 8), (1, 8)],
                  elbow=[(0, 0), (.2, -16), (.7, 28), (1, 28)], hand=[(0, 0), (.2, -36), (.45, -30), (.7, 34), (1, 34)]),
    # idle: slow breathing in the arms, the claws flexing; the tail sway (39 deg) halved by resetting it to a slow swing.
    "idle": dict(arm_up=[(0, 0), (.25, 4), (.5, 0), (.75, 4), (1, 0)], elbow=[(0, 0), (.5, 8), (1, 0)],
                 hand=[(0, 0), (.3, 14), (.45, 0), (.8, 10), (1, 0)],
                 tail_p=[(0, 2), (.5, 5), (1, 2)], tail_y=[(0, 0), (.25, 6), (.75, -6), (1, 0)]),
}
if CLIP not in SPECS:
    sys.exit(f"raptor_overlay: no spec for {CLIP}")
T = dict(SPECS[CLIP])
if "--keep" in argv:
    T["keep_arms"] = T["keep_tail"] = True

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
objs, acts = set(bpy.data.objects), set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=SRC)
for o in set(bpy.data.objects) - objs:
    bpy.data.objects.remove(o, do_unlink=True)
src = max(set(bpy.data.actions) - acts, key=lambda x: x.frame_range[1])
arm.animation_data_create()
arm.animation_data.action = src
try:
    arm.animation_data.action_slot = src.slots[0]
except Exception:
    pass
pbs, bones = arm.pose.bones, arm.data.bones
FWD, UP = Vector((0, -1, 0)), Vector((0, 0, 1))
SIDE = FWD.cross(UP).normalized()
F0, F1 = int(src.frame_range[0]), int(src.frame_range[1])
N = F1 - F0
TAILS = ("Tail1", "Tail2", "Tail3", "Tail4", "Tail5")


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def track(keys, u):
    if u <= keys[0][0]:
        return keys[0][1]
    for (u0, v0), (u1, v1) in zip(keys, keys[1:]):
        if u <= u1:
            return v0 + (v1 - v0) * smooth((u - u0) / max(u1 - u0, 1e-6))
    return keys[-1][1]


def g(name, u, side=""):
    keys = T.get(name + "_" + side) or T.get(name)
    return track(keys, u) * (ARM_GAIN if name in ("arm_up", "arm_out", "elbow", "hand") else 1.0) if keys else 0.0


def rot_about(p, axis, ang):
    return Matrix.Translation(p) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-p)


def set_m(name, m):
    pbs[name].matrix = m
    bpy.context.view_layer.update()


def turn(name, axis, deg):
    if deg:
        cur = pbs[name].matrix.copy()
        set_m(name, rot_about(cur.translation, axis, math.radians(deg)) @ cur)


def frame_of(name):
    """Rotation taking rest armature axes to the bone's current frame (so turns follow a pitched body)."""
    return (pbs[name].matrix.to_3x3() @ bones[name].matrix_local.to_3x3().inverted()).normalized()


def glue_arms():
    """Carry the arms (Body children) with the chest: apply the Shoulders' move relative to Body."""
    body_now = pbs["Body"].matrix
    s_rest_now = body_now @ bones["Body"].matrix_local.inverted() @ bones["Shoulders"].matrix_local
    d = pbs["Shoulders"].matrix @ s_rest_now.inverted()
    for s in "LR":
        set_m("FrontLeg." + s, d @ pbs["FrontLeg." + s].matrix)


def pose(u):
    tp = g("torso", u)
    if tp:
        r = frame_of("Hips")
        turn("Torso", r @ SIDE, -tp * 0.5)
        turn("Shoulders", r @ SIDE, -tp * 0.5)
    np_ = g("neck_p", u)
    if np_:
        turn("Neck", frame_of("Shoulders") @ SIDE, -np_ * 0.6)
        turn("Head", frame_of("Neck") @ SIDE, -np_ * 0.4)
    if not T.get("keep_tail"):
        for t in TAILS:
            pbs[t].matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        for i, t in enumerate(TAILS):
            k = (0.3, 0.26, 0.2, 0.14, 0.1)[i] * 1.6
            r = frame_of(t if i == 0 else TAILS[i - 1])
            turn(t, r @ UP, -g("tail_y", u) * k)
            turn(t, r @ SIDE, -g("tail_p", u) * k)
    if not T.get("keep_arms"):
        for s in "LR":
            for b in ("FrontLeg.", "FrontUpLeg.", "FrontLowLeg.", "FrontFoot."):
                pbs[b + s].matrix_basis = Matrix.Identity(4)  # the transferred arm turns are replaced
        bpy.context.view_layer.update()
        glue_arms()
    for s, sign in (("L", 1.0), ("R", -1.0)):
        r = frame_of("Shoulders")
        side, fwd = r @ SIDE, r @ FWD
        up, out = g("arm_up", u, s), g("arm_out", u, s)
        turn("FrontLeg." + s, side, up * 0.6 * SHOULDER)
        turn("FrontLeg." + s, fwd, -sign * out * 0.7 * SHOULDER)
        turn("FrontUpLeg." + s, fwd, -sign * out * (1.0 - 0.7 * SHOULDER))
        turn("FrontUpLeg." + s, side, up * (1.0 - 0.6 * SHOULDER))
        turn("FrontLowLeg." + s, side, -g("elbow", u, s))
        turn("FrontFoot." + s, side, -g("hand", u, s))


frames = []
for f in range(F0, F1 + 1):
    bpy.context.scene.frame_set(f)
    pose((f - F0) / max(1, N))
    frames.append({pb.name: pb.matrix_basis.copy() for pb in pbs})

arm.animation_data.action = None
for pb in pbs:
    pb.matrix_basis = Matrix.Identity(4)
act = bpy.data.actions.new(NAME)
arm.animation_data.action = act
for i, fb in enumerate(frames):
    for pb in pbs:
        pb.matrix_basis = fb[pb.name]
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert("location", frame=i)
        pb.keyframe_insert("rotation_quaternion", frame=i)
        pb.keyframe_insert("scale", frame=i)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, len(frames) - 1
print("CLIP", NAME, "from spec", CLIP, "frames", len(frames))
bpy.data.actions.remove(src)
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
