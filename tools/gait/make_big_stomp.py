"""BIGSTOMP (owner 2026-10-31: "the bigger dinosaurs all need a stomp mechanic where if you get close they will stomp the
ground, shake the screen ... Maybe you get pinned by the stomp attack"). One generic author for the shared big-dinosaur
stomp on any rig with a two-bone-plus-foot leg, keyed from rest on the base GLB's own skeleton:

big_stomp  1.667 s (40 frames at 24 fps), impact at 0.72 (anim_events.json big_stomp hit_frac): the weight shifts off
           the stomping leg and the body rears (front up for a quadruped, chest up for a biped); the foot is hauled
           high, held trembling (the telegraph), then slammed down on a spot a little forward of and inward from its
           print (under the body); the body drops with the impact, shudders, and the foot steps back onto its print.
pin_foot   4 s (96 frames), held on its last frame (PINFEEL's clip name): starts on big_stomp's impact pose; the
           stomping foot rises a survivor's chest height off the ground and presses down on that same spot while the
           body leans over it with the head low, two breaths and small head shakes. Only made for rigs that have no
           pin_foot of their own (the tyrannosaur family takes tools/gait/make_rex_moves.py's).

Every other foot is planted (its plant point is fixed for the whole clip: zero slide). Legs are solved analytically:
the upper two bones by a two-bone solve in their rest plane (knees keep their rest side), the bones below them keep
their rest orientation (the cannon / metatarsal tilt and a flat sole). A foot that is a root child (the Triceratops
donor rigs: styracosaurus, carnotaurus) is placed directly and the leg is solved to its head.

The per-species leg map, body bone and sizes are in tools/gait/big_stomp.json. Run ground_clip.py on the result.

usage: Blender -b -P tools/gait/make_big_stomp.py -- <base.glb> <species> <out_dir> [big_stomp] [pin_foot]
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, SPECIES, OUT = argv[:3]
WANT = argv[3:] or ["big_stomp", "pin_foot"]
FPS = 24
S = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "big_stomp.json")))[SPECIES]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
pbs, bones = arm.pose.bones, arm.data.bones
_shapes = {pb.custom_shape for pb in pbs if pb.custom_shape}
SKIN = max((o for o in bpy.data.objects if o.type == "MESH" and o not in _shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
for pb in pbs:
    pb.rotation_mode = "QUATERNION"
    pb.matrix_basis = Matrix.Identity(4)


def upd():
    bpy.context.view_layer.update()


upd()
UP = (arm.matrix_world.inverted().to_3x3() @ Vector((0, 0, 1))).normalized()
_f = bones[S["head"]].head_local - bones[S["tail"]].head_local
_f -= UP * _f.dot(UP)
FWD = _f.normalized()
SIDE = FWD.cross(UP).normalized()  # the animal's right
# armature units per metre of the game animal (the game scales the model to height_meters)
ev = SKIN.evaluated_get(bpy.context.evaluated_depsgraph_get())
me = ev.to_mesh()
zs = [(SKIN.matrix_world @ v.co).z for v in me.vertices]
ev.to_mesh_clear()
ARM_PER_WORLD = 1.0 / arm.matrix_world.to_scale().x
PER_M = (max(zs) - min(zs)) * ARM_PER_WORLD / float(S["height_m"])


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def track(u, keys):
    if u <= keys[0][0]:
        return keys[0][1]
    for (u0, v0), (u1, v1) in zip(keys, keys[1:]):
        if u <= u1:
            return v0 + (v1 - v0) * smooth((u - u0) / max(u1 - u0, 1e-6))
    return keys[-1][1]


def rot_about(p, axis, deg):
    return Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p)


def set_m(name, m):
    pbs[name].matrix = m
    upd()


def turn(name, axis, deg):
    if deg and name in pbs:
        cur = pbs[name].matrix.copy()
        set_m(name, rot_about(cur.translation, axis, deg) @ cur)


LEGS = []
for L in S["legs"]:
    up, low, lower, foot = L["up"], L["low"], L.get("lower", []), L.get("foot")
    h, k = bones[up].head_local, bones[low].head_local
    ankle = bones[foot].head_local if foot else bones[lower[0]].head_local
    line = ankle - h
    off = (k - h) - line * ((k - h).dot(line) / line.length_squared)
    LEGS.append({"up": up, "low": low, "lower": lower, "foot": foot, "l1": (k - h).length, "l2": (ankle - k).length,
                 "pole": off.normalized(), "ankle0": ankle.copy()})
ST = LEGS[S["stomp"]]
H = (bones[ST["up"]].head_local - ST["ankle0"]).dot(UP)  # hip (or shoulder) height of the stomping leg
QUAD = len(LEGS) == 4
# pitch pivot: the hind feet for a quadruped (the front rears), the hips for a biped
_hind = [L["ankle0"] for L in LEGS[2:]] if QUAD else [bones[L["up"]].head_local for L in LEGS]
PIVOT = sum(_hind, Vector()) / len(_hind)
STOMP_SIDE = 1.0 if ST["ankle0"].dot(SIDE) > PIVOT.dot(SIDE) else -1.0  # +1: the stomping foot is the right one
LIFT = float(S.get("lift", 0.55)) * H
F = float(S.get("fwd", 0.2)) * H
IN = -STOMP_SIDE * abs((ST["ankle0"] - PIVOT).dot(SIDE)) * float(S.get("inward", 0.5))
P = float(S.get("pitch", 10.0))
BODY = S["body"]
CROUCH = float(S.get("crouch", 1.0))  # scales the body drop on the impact
DROP = float(S.get("neck_drop", 16.0))  # deg the head drives down on the impact


def solve(leg, target):
    up, low = leg["up"], leg["low"]
    set_m(up, pbs[up].matrix)
    h = pbs[up].head.copy()
    l1, l2 = leg["l1"], leg["l2"]
    d_vec = target - h
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
    if leg["foot"]:  # a root-child foot sits exactly on its target
        m = bones[leg["foot"]].matrix_local.copy()
        m.translation = target
        set_m(leg["foot"], m)
    prev = None
    for b in leg["lower"]:  # rest orientation, carried to the end of the bone above
        m = bones[b].matrix_local.copy()
        m.translation = pbs[leg["low"]].tail.copy() if prev is None else pbs[prev].tail.copy()
        set_m(b, m)
        prev = b


def apply(p):
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    upd()
    m = Matrix.Translation(SIDE * p["dx"] + FWD * p.get("dy", 0.0) + UP * p["dz"]) \
        @ rot_about(PIVOT, SIDE, p["pitch"]) @ rot_about(PIVOT, FWD, p["roll"]) @ bones[BODY].matrix_local
    set_m(BODY, m)
    for _ in range(4):  # a planted leg that cannot reach its print lowers the body (no foot lifts off or slides)
        short = max((leg["ankle0"] - pbs[leg["up"]].head).length - (leg["l1"] + leg["l2"]) * 0.97 for leg in LEGS if leg is not ST)
        if short <= 0.0:
            break
        m = pbs[BODY].matrix.copy()
        m.translation -= UP * (short + 0.002)
        set_m(BODY, m)
    for i, b in enumerate(S.get("neck", [])):
        turn(b, SIDE, p["neck"] * (0.5 if i == 0 else 0.3))
        if p.get("shake"):
            turn(b, UP, p["shake"] * 0.5)
    for i, b in enumerate(S.get("tails", [])):
        turn(b, SIDE, -p["tail"] * (0.4 if i < 2 else 0.2))
    for leg in LEGS:
        t = leg["ankle0"].copy()
        if leg is ST:
            t += FWD * p["fwd"] + SIDE * p["side"] + UP * p["lift"]
        solve(leg, t)


def stomp(u):
    I = 0.72
    lift = max(0.0, track(u, [(0, 0), (0.12, 0), (0.42, 1.0), (0.62, 1.0), (0.69, 0.4), (I, 0), (0.86, 0), (0.92, 0.12), (0.98, 0), (1, 0)]))
    tremble = 0.04 * math.sin(2 * math.pi * 7 * u) * smooth((u - 0.42) / 0.05) * (1 - smooth((u - 0.6) / 0.04))
    reach = track(u, [(0, 0), (0.12, 0), (0.42, 0.6), (0.62, 0.7), (I, 1.0), (0.86, 1.0), (0.98, 0), (1, 0)])
    shudder = track(u, [(0, 0), (I, 0), (0.74, 1), (0.84, 0), (1, 0)]) * math.sin(2 * math.pi * 14 * u)
    away = track(u, [(0, 0), (0.15, 1), (0.62, 1), (I, 0.25), (0.86, 0), (1, 0)])
    return {
        "lift": (lift + tremble * lift) * LIFT, "fwd": reach * F, "side": reach * IN,
        "dx": -STOMP_SIDE * 0.1 * H * away, "dy": 0.0,
        "dz": track(u, [(0, 0), (0.2, 0.02), (0.62, 0.03), (I, -0.06), (0.77, -0.04), (0.82, -0.05), (0.92, 0), (1, 0)]) * H * CROUCH + 0.012 * H * shudder,
        "pitch": track(u, [(0, 0), (0.22, P), (0.62, P * 1.1), (I, -P * 0.4), (0.8, -P * 0.25), (1, 0)]),
        "roll": -STOMP_SIDE * track(u, [(0, 0), (0.2, 4.0), (0.62, 4.5), (I, -1.0), (0.85, 0), (1, 0)]),
        "neck": track(u, [(0, 0), (0.25, 8), (0.62, 10), (I, -DROP), (0.8, -DROP * 0.6), (1, 0)]),
        "tail": track(u, [(0, 0), (0.25, 10), (0.62, 12), (I, 10), (0.85, 3), (1, 0)]),
        "shake": 3.0 * shudder,
    }


PIN_LIFT = float(S.get("pin_lift_m", 0.28)) * PER_M  # a lying survivor's chest


def pin(u):
    E = 0.15
    s = stomp(0.72)
    k = smooth(u / E)
    br = 0.5 - 0.5 * math.cos(2 * math.pi * 2 * max(0.0, (u - E) / (1 - E)))
    sh = math.sin(2 * math.pi * 9 * u) * smooth((u - E) / 0.1) * (0.6 + 0.4 * br)

    def mix(a, b):
        return a + (b - a) * k
    return {
        "lift": max(0.0, track(u, [(0, 0), (E * 0.5, PIN_LIFT * 2.0), (E, PIN_LIFT), (1, PIN_LIFT)])),
        "fwd": s["fwd"], "side": s["side"],
        "dx": mix(s["dx"], -STOMP_SIDE * 0.04 * H), "dy": 0.0, "dz": mix(s["dz"], -0.05 * H) - 0.012 * H * br,
        "pitch": mix(s["pitch"], -0.35 * P) - 0.8 * br, "roll": mix(s["roll"], STOMP_SIDE * 2.0),
        "neck": mix(s["neck"], -1.5 * DROP) + 3.0 * br, "tail": mix(s["tail"], 8.0), "shake": 4.0 * sh,
    }


CLIPS = {"big_stomp": (stomp, 40), "pin_foot": (pin, 96)}
os.makedirs(OUT, exist_ok=True)
for o in list(bpy.data.objects):
    if o is not arm:
        bpy.data.objects.remove(o, do_unlink=True)
sc = bpy.context.scene
sc.render.fps = FPS
for name in WANT:
    fn, n = CLIPS[name]
    arm.animation_data_create()
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    for f in range(n + 1):
        apply(fn(f / n))
        for pb in pbs:
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("scale", frame=f)
    if name == "big_stomp":
        apply(stomp(0.72))
        pinb = ST["foot"] or ST["lower"][-1]
        print("BIGSTOMP %s impact foot %s at %s (rest %s), H %.3f, per_m %.3f, %s len %.3f" % (
            SPECIES, pinb, tuple(round(x, 3) for x in pbs[pinb].head), tuple(round(x, 3) for x in bones[pinb].head_local),
            H, PER_M, pinb, bones[pinb].length))
    sc.frame_start, sc.frame_end = 0, n
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    out = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", export_apply=False, export_yup=True,
        use_selection=True, export_animations=True, export_animation_mode="ACTIVE_ACTIONS",
        export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
        export_anim_slide_to_zero=False, export_skins=True, export_morph=False,
        export_def_bones=False, export_reset_pose_bones=False, export_current_frame=False,
        export_nla_strips=False, export_anim_single_armature=True, export_bake_animation=True,
        export_materials="NONE", export_image_format="NONE")
    print("WROTE", out, n + 1, "frames")
    arm.animation_data.action = None
