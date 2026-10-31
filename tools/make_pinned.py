#!/usr/bin/env python3
"""Author the survivor's `pinned` loop: flat on her back (the last frame of knockdown.glb), struggling under a
predator's foot. Owner 2026-10-30: "pinned should force the player/animal in the lying down animation".

2 s loop (the knockdown's fps), every motion a whole number of cycles so the last frame is the first:
  hands   both shove up at the foot on her chest (wrists 0.2-0.3 m over the sternum), alternating
  legs    heels drag in and kick out, one leg then the other, feet near the ground
  head    turns side to side and strains up off the ground
  body    the hips and chest writhe (counter-rolled about the body's long axis)
Wrists and ankles are IK targets (Blender IK constraints, baked with visual keying like make_work_clips.py).
PlayerAnim blends into it from the knockdown's last frame (she is already on her back), so it does not pop.

  Blender -b --python tools/make_pinned.py -- <survivor.glb> <knockdown.glb> <out pinned.glb>

Rig: Mixamo names. Lying: head toward +Y, chest up (+Z), her left = +X; armature at the origin.
"""
import json, math, struct, sys
import bpy
from mathutils import Matrix, Vector

a = sys.argv[sys.argv.index("--") + 1:]
BASE, KD, OUT = a[:3]
b = open(KD, "rb").read(); n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + n])
acc = max((j["accessors"][s["input"]] for s in j["animations"][0]["samplers"]), key=lambda x: x["count"])
FPS = round((acc["count"] - 1) / max(acc["max"][0] - acc["min"][0], 1e-6))
N = 2 * FPS  # 2 s loop
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
TAU = 2 * math.pi
LEG_POLE = 90.0  # knees up (0 and 180 tried: the knee swings sideways or through the floor)


def wave(t, cycles, phase=0.0):
    return math.sin(TAU * (cycles * t + phase))


def pulse(t, cycles, phase=0.0):
    """0..1..0 once per cycle (cosine bump), periodic."""
    return 0.5 - 0.5 * math.cos(TAU * (cycles * t + phase))


bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in [o for o in bpy.data.objects if o is not arm]:
    bpy.data.objects.remove(o)
before, acts = set(bpy.data.objects), set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=KD)
kd = next(iter(set(bpy.data.actions) - acts))
for o in set(bpy.data.objects) - before:
    bpy.data.objects.remove(o)
arm.animation_data_create(); arm.animation_data.action = kd
if len(kd.slots):
    arm.animation_data.action_slot = kd.slots[0]
sc.frame_set(int(round(kd.frame_range[1])))
LIE = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}
pbs = arm.pose.bones


def head(name):
    return arm.matrix_world @ pbs[name].head


def rot(name, axis, deg, pivot=None):
    """Turn a bone (and so its children) about a world axis through its head (or pivot)."""
    pb = pbs[name]; m = pb.matrix.copy(); p = m.translation.copy() if pivot is None else pivot
    pb.matrix = Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p) @ m
    bpy.context.view_layer.update()


def body(t):
    """Writhe and head work, applied on the lying pose before the IK targets are read."""
    writhe = wave(t, 2)
    rot("Hips", Y, 5.0 * writhe)
    rot("Spine1", Y, -8.0 * writhe)
    rot("Spine2", X, -6.0 * pulse(t, 2, 0.1))  # the chest heaves up against the foot
    rot("Neck", X, -12.0 * pulse(t, 1, 0.25))  # strains the head up off the ground
    rot("Head", (pbs["Head"].matrix.to_3x3().col[1]).normalized(), 28.0 * wave(t, 1))  # turns side to side


def targets(t):
    """World wrist / ankle targets and poles. Shoves alternate (2 cycles), kicks alternate (1 cycle each leg)."""
    ch = head("Spine2")
    out = {}
    for s, sx, ph in (("Left", 1.0, 0.0), ("Right", -1.0, 0.5)):
        shove = pulse(t, 2, ph)
        w = ch + Vector((0.20 * sx, 0.12, 0.16 + 0.12 * shove))
        out[s + "ForeArm"] = (w, head(s + "Arm") + Vector((0.45 * sx, -0.15, -0.05)))
        kick = pulse(t, 1, ph)
        f0 = head(s + "Foot")
        an = f0 + Vector((0.0, 0.34 * kick, 0.10 * math.sin(math.pi * kick)))
        out[s + "Leg"] = (an, head(s + "UpLeg") + Vector((0.1 * sx, -0.4, 0.6)))
    return out


fk = bpy.data.actions.new("pinned_fk"); arm.animation_data.action = fk
tg = []
for f in range(N + 1):
    t = (f % N) / N
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"; pb.matrix_basis = LIE[pb.name]
    bpy.context.view_layer.update()
    body(t)
    tg.append(targets(t))
    for pb in pbs:
        pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)


def empty(name):
    e = bpy.data.objects.new(name, None); sc.collection.objects.link(e); return e


emp = {}
for bone in tg[0]:
    w, p = empty(bone + "_t"), empty(bone + "_p")
    c = pbs[bone].constraints.new("IK")
    c.target, c.pole_target, c.chain_count, c.pole_angle = w, p, 2, math.radians(-90 if "Arm" in bone else LEG_POLE)
    emp[bone] = (w, p)
for f in range(N + 1):
    for bone, (w, p) in emp.items():
        w.location, p.location = tg[f][bone]
        w.keyframe_insert("location", frame=f); p.keyframe_insert("location", frame=f)
bpy.context.view_layer.objects.active = arm; arm.select_set(True)
bpy.ops.object.mode_set(mode="POSE"); bpy.ops.pose.select_all(action="SELECT")
bpy.ops.nla.bake(frame_start=0, frame_end=N, only_selected=False, visual_keying=True,
                 clear_constraints=True, use_current_action=False, bake_types={"POSE"})
bpy.ops.object.mode_set(mode="OBJECT")
baked = arm.animation_data.action
baked.name = "pinned"
for o in [o for o in bpy.data.objects if o.type == "EMPTY"]:
    bpy.data.objects.remove(o)
for act in [x for x in bpy.data.actions if x is not baked]:
    bpy.data.actions.remove(act)
sc.frame_start, sc.frame_end = 0, N
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_force_sampling=True, export_yup=True)
print(f"PINNED {N + 1} frames at {FPS} fps -> {OUT}")
