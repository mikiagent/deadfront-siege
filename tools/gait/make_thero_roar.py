"""THERO-ROAR: author the shared rearing roar (clip `roar`) on any big theropod rig with the rig_biped / fit_rex_rig
skeleton (Hips, Spine1[, Spine2], Chest, Neck1, Neck2, Head, Jaw, Arm/Forearm/Hand.L/R, Thigh/Shin/Metatarsal/Toe.L/R,
Tail1..N). One script for every species; the per-species numbers are rows in tools/gait/thero_roar.json.

Owner 2026-10-31 (fight lab, the ceratosaurus): "a roar animation where they stand on their hind legs and roar in almost a
circular motion with special effects and screen shake ... if it stands up higher and uses his arms more it could be fine".
The beats (fractions of the clip; anim_events.json roar hit_frac 0.34 is the burst, when the shockwave fires):
  0.00-0.24  rear: the body pitches up on the hips and rises as far as the legs reach (feet IK-planted on their prints),
             the tail lowered as the counterweight, the arms come up and flex, the head is thrown up and to the left,
             the jaw starts to open
  0.24-0.34  the jaw goes wide (a real Jaw bone, opened about the head's side axis)
  0.30-0.80  the bellow: the head sweeps a near-circular arc, high on the left, down and forward through the middle, up
             on the right, carried by the hips (yawing on the planted feet), the chest, both neck bones and the head, so the
             snout's heading sweeps `sweep` degrees; the tail swings the other way, the arms tremble
  0.80-1.00  settle back to the rest stance (the idle's first frame), the jaw shuts
Feet never leave their prints: the IK solves every frame to the rest ankle, and the rise is clamped to 0.97 of the
leg's reach so the knee never locks short of the print.

usage: Blender -b -P tools/gait/make_thero_roar.py -- <base.glb> <species> <out.glb>
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, SPECIES, OUT = argv[:3]
CFG = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "thero_roar.json")))
ROW = dict(CFG["default"])
ROW.update(CFG["species"].get(SPECIES, {}))
FPS = 24
N = int(round(ROW["secs"] * FPS))
UP = Vector((0, 0, 1))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
pbs, bones = arm.pose.bones, arm.data.bones
# forward is whichever way the head lies from the hips (rig_biped rigs face -Y, the fit_rex_rig rex rigs +Y)
FWD = Vector((0, 1 if bones["Head"].head_local.y > bones["Hips"].head_local.y else -1, 0))
SIDE = FWD.cross(UP).normalized()  # the animal's right; +pitch about it lifts the nose
TAILS = sorted([b.name for b in bones if b.name.startswith("Tail") and b.name[4:].isdigit()], key=lambda n: int(n[4:]))
SPINE = [n for n in ("Spine1", "Spine2", "Chest") if n in bones]
U = bones["Thigh.L"].head_local.z  # hip height: body offsets are in hip heights
HEAD_REST = bones["Head"].matrix_local.to_3x3().normalized()


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
                "pole": off.normalized(), "ankle0": an.copy()}
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


def body_matrix(b):
    return Matrix.Translation((SIDE * b.get("dx", 0.0) + FWD * b.get("dy", 0.0) + UP * b.get("dz", 0.0)) * U) \
        @ rot_about(PIVOT, UP, math.radians(b.get("yaw", 0.0))) \
        @ rot_about(PIVOT, SIDE, math.radians(b.get("pitch", 0.0))) @ rot_about(PIVOT, FWD, math.radians(b.get("roll", 0.0))) \
        @ bones["Hips"].matrix_local


def reach_ok(b):
    """Every thigh head within 0.97 of its leg's reach of its rest ankle (a straighter leg would pull the foot off)."""
    m = body_matrix(b) @ bones["Hips"].matrix_local.inverted()
    for leg in LEGS.values():
        hip = m @ bones[leg["up"]].head_local
        if (leg["ankle0"] - hip).length > 0.97 * (leg["l1"] + leg["l2"]):
            return False
    return True


def apply(p):
    """p: body {dx, dy, dz, pitch, roll, yaw}, turns {bone: (pitch, yaw, roll)}, jaw (deg open). Feet stay on their prints."""
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    b = dict(p.get("body", {}))
    for _ in range(40):  # rise only as far as the legs reach
        if reach_ok(b):
            break
        b["dz"] = b.get("dz", 0.0) * 0.9 - 0.002
    set_m("Hips", body_matrix(b))
    turns = p.get("turns", {})
    for name in SPINE + ["Neck1", "Neck2", "Head"] + TAILS + ["Arm.L", "Arm.R", "Forearm.L", "Forearm.R", "Hand.L", "Hand.R"]:
        tp, ty, tr = turns.get(name, (0.0, 0.0, 0.0))
        turn(name, UP, ty)
        turn(name, SIDE, tp)
        turn(name, FWD, tr)
    # the jaw opens about the head's side axis (tip down), whatever the jaw bone's own roll
    axis = (pbs["Head"].matrix.to_3x3().normalized() @ HEAD_REST.inverted()) @ -SIDE
    cur = pbs["Jaw"].matrix.copy()
    set_m("Jaw", rot_about(cur.translation, axis.normalized(), math.radians(p.get("jaw", 0.0))) @ cur)
    for sd, leg in LEGS.items():
        solve_leg(leg, leg["ankle0"])
        fm = bones[leg["foot"]].matrix_local.copy()  # the foot keeps its rest orientation on its print
        fm.translation = pbs[leg["low"]].tail
        set_m(leg["foot"], fm)
        tm = bones["Toe." + sd].matrix_local.copy()
        tm.translation = pbs[leg["foot"]].tail
        set_m("Toe." + sd, tm)
    return b


def roar(u):
    R = ROW
    rear = track(u, [(0, 0), (0.24, 1), (0.8, 1), (0.97, 0), (1, 0)])
    # the sweep: phi runs 0 -> pi across the bellow; side -1 (left) -> +1 (right), dip lowest in the middle
    phi = math.pi * smooth((u - 0.3) / 0.5)
    pre = track(u, [(0, 0), (0.22, 1), (0.3, 1), (0.8, 1), (0.95, 0), (1, 0)])  # how much of the sweep pose is on
    side = -math.cos(phi) if u >= 0.3 else -1.0
    side = side * pre if u < 0.8 else track(u, [(0.8, 1), (0.95, 0), (1, 0)])
    dip = math.sin(phi) * pre if 0.3 <= u <= 0.8 else 0.0
    lift = track(u, [(0, 0), (0.22, 1), (0.3, 1), (0.8, 0.6), (0.92, 0), (1, 0)])  # head thrown up at both ends
    trem = math.sin(2 * math.pi * 7 * u) * track(u, [(0, 0), (0.3, 0), (0.36, 1), (0.76, 1), (0.82, 0), (1, 0)])
    sw = R["sweep"] / 2.0  # degrees each way; shared hips, chest, necks, head in these proportions
    share = {"hips": 0.16, "spine": 0.10, "Neck1": 0.27, "Neck2": 0.25, "Head": 0.22}
    yaw = lambda k: -side * sw * share[k]  # + yaw turns toward the animal's left
    pitch = R["rear_pitch"] * rear
    turns = {}
    for n in SPINE:
        turns[n] = (R["chest_pitch"] * rear / len(SPINE), yaw("spine") / len(SPINE), 0.0)
    # the neck carries the head up from the reared chest; the head itself stays near level then looks up at the ends
    turns["Neck1"] = (R["neck_pitch"] * rear - R["dip"] * 0.5 * dip, yaw("Neck1"), 0.0)
    turns["Neck2"] = (-0.4 * R["neck_pitch"] * rear - R["dip"] * 0.3 * dip, yaw("Neck2"), 0.0)
    turns["Head"] = (-(pitch + R["chest_pitch"] + 0.6 * R["neck_pitch"]) * rear + R["head_up"] * lift - R["dip"] * 0.2 * dip + 2 * trem,
                     yaw("Head"), 14 * side * pre + 3 * trem)
    # the tail: lowered against the rearing chest (the counterweight: its root follows the hips down, the rest held
    # out nearly level), swinging against the head
    for i, t in enumerate(TAILS):
        k = 0.85 ** i
        turns[t] = (-R["tail_hold"] * pitch * (1.0 if i == 0 else 0.25 * k) + 3 * trem * i / max(1, len(TAILS) - 1),
                    side * R["tail_swing"] * (0.5 + 0.1 * i), 0.0)
    a = track(u, [(0, 0), (0.18, 1), (0.84, 1), (0.98, 0), (1, 0)])
    for sd, s in (("L", 1.0), ("R", -1.0)):
        turns["Arm." + sd] = (R["arm_raise"] * a + 4 * trem, 0.0, s * R["arm_spread"] * a)
        turns["Forearm." + sd] = (R["arm_flex"] * a - 3 * trem, 0.0, 0.0)
        turns["Hand." + sd] = (R["hand_curl"] * a, 0.0, 0.0)
    jaw = track(u, [(0, 1), (0.16, 8), (0.3, R["jaw"]), (0.78, R["jaw"] - 2), (0.93, 4), (1, 1)]) + 1.5 * trem
    return {
        "body": {"pitch": pitch, "dz": R["rise"] * rear, "dy": -R["back"] * rear, "yaw": yaw("hips"),
                 "roll": -3 * side * pre},
        "turns": turns,
        "jaw": jaw,
    }


arm.animation_data_create()
act = bpy.data.actions.new("roar")
arm.animation_data.action = act
rises = []
for f in range(N + 1):
    b = apply(roar(f / N))
    rises.append(b.get("dz", 0.0))
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert("location", frame=f)
        pb.keyframe_insert("rotation_quaternion", frame=f)
        pb.keyframe_insert("scale", frame=f)
sc = bpy.context.scene
sc.render.fps = FPS
sc.frame_start, sc.frame_end = 0, N
print(f"THEROROAR {SPECIES} {N} frames ({N / FPS:.3f} s) fwd {tuple(FWD)} rise asked {ROW['rise']:.3f} got {max(rises):.3f} hip heights")

for o in list(bpy.data.objects):
    if o is not arm:
        bpy.data.objects.remove(o, do_unlink=True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
act.name = "roar"
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", export_apply=False, export_yup=True,
    use_selection=True, export_animations=True, export_animation_mode="ACTIONS",
    export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
    export_anim_slide_to_zero=False, export_skins=True, export_morph=False,
    export_def_bones=False, export_reset_pose_bones=False, export_current_frame=False,
    export_nla_strips=False, export_anim_single_armature=True, export_bake_animation=True,
    export_materials="NONE", export_image_format="NONE")
print("WROTE", OUT)
