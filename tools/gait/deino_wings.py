"""DEINOARMS (owner 2026-10-31: "make sure its arms/wings actually move during attacks"): spread the folded wings in
the attacks so they read.

The raptor_overlay arm keys swing the arm forward about the shoulder. On this rig the arm bones hang down while the
folded wing (deino_wing_shell.py) lies back along the flank, so that swing moved the wing tip only 0.7-1.3 m and partly
down into the ground. Here, on top of the clip, each wing is spread: the upper arm is swung out to the side about the
chest's forward axis (abduction, the tip rises and opens like a mantling hawk) and lifted back about the side axis
so the tip clears the ground, on an envelope per clip: open on the wind-up, held through the hit, folded after.

Every clip it is run on (attacks or not) also keeps the wing off the ground: where the forward arm swing would carry the
wing's lowest point under --clear (mesh units), the upper arm is lifted back about the side axis until it clears
(owner: "4 legs on the ground" - nothing but the hind feet may reach the floor).

usage: Blender -b -P tools/gait/deino_wings.py -- <base.glb> <clip.glb> <out.glb> [--out-deg 70] [--lift-deg 25] [--clear 0.12]
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, SRC, OUT = argv[:3]
CLIP = os.path.splitext(os.path.basename(SRC))[0]
opt = lambda k, d: float(argv[argv.index(k) + 1]) if k in argv else d
OUT_DEG, LIFT_DEG = opt("--out-deg", 70.0), opt("--lift-deg", 25.0)
# ASSUMPTION: envelopes (clip fraction, 0..1 of the full spread); hits from anim_events.json.
ENV = {
    "attack_primary": [(0, 0), (.12, .3), (.32, 1), (.5, 1), (.75, .25), (1, 0)],  # hit .42
    "bite_combo": [(0, .2), (.06, 1), (.14, .7), (.3, 1), (.42, .7), (.55, .6), (.7, 1), (.86, 1), (1, 0)],  # .092 .338 .815
    "pounce": [(0, 0), (.15, .5), (.25, 1), (.75, 1), (.9, .4), (1, 0)],  # airborne .2-.65, hit .7
    "attack_heavy": [(0, 0), (.2, .8), (.6, 1), (.78, 1), (.92, .3), (1, 0)],  # windup hold .6, hit .72
}
# the sickle slash already holds the arms up for balance: it takes a wider, higher spread to read
OUT_DEG, LIFT_DEG = {"attack_heavy": (90.0, 65.0)}.get(CLIP, (OUT_DEG, LIFT_DEG)) if "--out-deg" not in argv else (OUT_DEG, LIFT_DEG)
CLEAR = opt("--clear", 0.12)  # mesh units (~0.65 m at 2.55 m): the wing tip never comes lower than this


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def env(u):
    k = ENV.get(CLIP, [(0, 0), (1, 0)])  # other clips: only the ground clearance below
    for (u0, v0), (u1, v1) in zip(k, k[1:]):
        if u <= u1:
            return v0 + (v1 - v0) * smooth((u - u0) / max(u1 - u0, 1e-6))
    return k[-1][1]


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
mesh = max((o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm), key=lambda o: len(o.data.vertices))
gi = {g.index: g.name for g in mesh.vertex_groups}
WING = {s: [] for s in "LR"}  # rest positions of each wing shell's lower-edge vertices, and their bone
for v in mesh.data.vertices:
    if v.groups:
        n = gi[max(v.groups, key=lambda g: g.weight).group]
        if n in ("FrontUpLeg.L", "FrontLowLeg.L", "FrontUpLeg.R", "FrontLowLeg.R"):
            WING[n[-1]].append((mesh.matrix_world @ v.co, n))
SAMPLE = {s: WING[s][::10] for s in "LR"}  # the whole wing, for which way is out
for s in "LR":
    WING[s].sort(key=lambda t: t[0].z)
    WING[s] = WING[s][:60]  # the lowest edge


def wing_out(s, sign):
    return sum(sign * ((pbs[n].matrix @ bones[n].matrix_local.inverted()) @ p).x for p, n in SAMPLE[s]) / max(1, len(SAMPLE[s]))


def wing_low(s):
    return min(((pbs[n].matrix @ bones[n].matrix_local.inverted()) @ p).z for p, n in WING[s])
FWD, SIDE = Vector((0, -1, 0)), Vector((1, 0, 0))  # this rig faces -Y; +X is the animal's left
F0, F1 = int(src.frame_range[0]), int(src.frame_range[1])
frames = []
for f in range(F0, F1 + 1):
    bpy.context.scene.frame_set(f)
    e = env((f - F0) / max(1, F1 - F0))
    r = (pbs["Shoulders"].matrix.to_3x3() @ bones["Shoulders"].matrix_local.to_3x3().inverted()).normalized()
    for s, sign in (("L", 1.0), ("R", -1.0)):
        b = pbs["FrontUpLeg." + s]
        m = b.matrix.copy(); p = m.translation.copy()
        # spread: whichever way about the chest's forward axis carries the wing away from the body (a raised arm,
        # as in the sickle slash, opens the other way round than a hanging one)
        best = None
        for d in (1.0, -1.0):
            rot = Matrix.Rotation(math.radians(d * sign * OUT_DEG * e), 4, r @ FWD) @ Matrix.Rotation(math.radians(LIFT_DEG * e), 4, r @ SIDE)
            b.matrix = Matrix.Translation(p) @ rot @ Matrix.Translation(-p) @ m
            bpy.context.view_layer.update()
            o = wing_out(s, sign)
            if best is None or o > best[0]:
                best = (o, rot)
        b.matrix = Matrix.Translation(p) @ best[1] @ Matrix.Translation(-p) @ m
        bpy.context.view_layer.update()
        for _ in range(30):  # ground clearance: lift the wing back in 3 deg steps
            if wing_low(s) >= CLEAR:
                break
            m = b.matrix.copy(); p = m.translation.copy()
            b.matrix = Matrix.Translation(p) @ Matrix.Rotation(math.radians(3.0), 4, r @ SIDE) @ Matrix.Translation(-p) @ m
            bpy.context.view_layer.update()
    frames.append({pb.name: pb.matrix_basis.copy() for pb in pbs})
arm.animation_data.action = None
for pb in pbs:
    pb.matrix_basis = Matrix.Identity(4)
act = bpy.data.actions.new(CLIP)
arm.animation_data.action = act
for i, fb in enumerate(frames):
    for pb in pbs:
        pb.matrix_basis = fb[pb.name]
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert("location", frame=i)
        pb.keyframe_insert("rotation_quaternion", frame=i)
        pb.keyframe_insert("scale", frame=i)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, len(frames) - 1
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
