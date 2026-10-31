"""HOPSTRAFE (owner 2026-10-31: the velociraptor "should also use arms in attacks"): layer hand-claw grabs and rakes
onto an existing attack clip of a Meshy-library biped (FrontLeg/FrontUpLeg/FrontLowLeg/FrontFoot arm bones).

Per hit (anim_events hit_fracs, else hit_frac, else 0.55) the arms cock (raised back, elbows folded, flared out, claws
opened), then rake: thrown forward and down with the elbows opening and the hands curling the claws through the prey,
then settle back to the clip's own pose by the end. bite_combo alternates the leading arm. The pounce flares both arms
wide in the air and rakes on its hit. charge (a loop) holds the arms out and flared, grasping, the same every frame so
the loop stays seamless. Only the arm bones are rekeyed: every other channel stays exactly as it was.

usage: Blender -b -P tools/gait/add_arm_strikes.py -- <clip.glb> <kind> <out.glb> [--gain 1.0]
  kind: attack_primary | attack_heavy | bite_combo | pounce | charge
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, KIND, OUT = argv[:3]
GAIN = float(argv[argv.index("--gain") + 1]) if "--gain" in argv else 1.0
EVENTS = os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "creatures", "anim_events.json")

row = json.load(open(EVENTS))["clips"].get(KIND, {})
HITS = row.get("hit_fracs") or [row.get("hit_frac", 0.55)]
AIR = row.get("airborne", [0.2, 0.65])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
pbs, bones = arm.pose.bones, arm.data.bones
act = arm.animation_data.action
F0, F1 = (int(round(x)) for x in act.frame_range)
FWD, UP = Vector((0, -1, 0)), Vector((0, 0, 1))
SIDE = FWD.cross(UP).normalized()


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def ramp(u, a, b):
    return smooth((u - a) / max(1e-4, b - a))


def rot_about(p, axis, ang):
    return Matrix.Translation(p) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-p)


def turn(name, axis, deg):
    if name in pbs and deg:
        cur = pbs[name].matrix.copy()
        pbs[name].matrix = rot_about(cur.translation, axis, math.radians(deg) * GAIN) @ cur
        bpy.context.view_layer.update()


def strike(u, h):
    """cock c and rake s (0..1) around one hit at fraction h."""
    c = ramp(u, h - 0.28, h - 0.07) * (1.0 - ramp(u, h - 0.07, h + 0.03))
    fe = min(h + 0.35, 0.97)
    fs = min(h + 0.12, fe - 0.05)
    s = ramp(u, h - 0.09, h + 0.01) * (1.0 - ramp(u, fs, fe))
    return c, s


def envelope(u, xs):
    """(cock, rake, flare) for the arm on side xs (+1 left, -1 right)."""
    if KIND == "charge":
        return 0.0, 0.0, 1.0
    c = s = 0.0
    for i, h in enumerate(HITS):
        w = 1.0
        if KIND == "bite_combo":
            w = 1.0 if (i % 2 == 0) == (xs > 0) else 0.55  # the leading arm alternates
        ci, si = strike(u, h)
        c, s = max(c, ci * w), max(s, si * w)
    flare = c
    if KIND == "pounce":
        flare = max(flare, ramp(u, AIR[0] - 0.1, AIR[0] + 0.1) * (1.0 - ramp(u, HITS[0] + 0.1, 0.97)))
    return c, s, flare


ARMS = {}
for sd in "LR":
    xs = 1.0 if bones["FrontUpLeg." + sd].head_local.x > 0 else -1.0
    ARMS[sd] = xs

peak = 0.0
for f in range(F0, F1 + 1):
    bpy.context.scene.frame_set(f)
    u = (f - F0) / max(1, F1 - F0)
    for sd, xs in ARMS.items():
        c, s, fl = envelope(u, xs)
        if KIND == "charge":
            # held out ahead and flared, claws open: the grasp a raptor runs in with
            turn("FrontUpLeg." + sd, SIDE, 30)
            turn("FrontUpLeg." + sd, FWD, xs * 22)
            turn("FrontLowLeg." + sd, SIDE, -10)
            turn("FrontFoot." + sd, SIDE, 15)
        else:
            turn("FrontUpLeg." + sd, SIDE, -35 * c + 75 * s)
            turn("FrontUpLeg." + sd, FWD, xs * (32 * fl + 8 * s))
            turn("FrontLowLeg." + sd, SIDE, -40 * c + 25 * s)
            turn("FrontFoot." + sd, SIDE, 25 * c - 55 * s)
        peak = max(peak, abs(-35 * c + 75 * s))
        for b in ("FrontUpLeg." + sd, "FrontLowLeg." + sd, "FrontFoot." + sd):
            pb = pbs[b]
            pb.rotation_mode = "QUATERNION"
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
print(f"ARMS {KIND} frames {F0}-{F1} hits {HITS} peak upper-arm swing {peak:.0f} deg")

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
