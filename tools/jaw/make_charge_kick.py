#!/usr/bin/env python3
"""Herbivore defence clips from a species' own clips: `charge` (its run with the head dropped low, horns or frill
first, body lower) and `kick` (from idle: weight shifts forward, both hind legs snap back and up, then plant).

Works on the Meshy/transplant quadruped rigs (BackUpLeg/BackLowLeg/BackFoot, root-parented foot controllers glued to
the shins) and on rigs with hind_thigh/hind_shin/hind_foot chains (stegosaurus). Exports skeleton-only at the source
clip's fps and prints the hit fraction for anim_events.json.

  Blender -b --python tools/jaw/make_charge_kick.py -- <base.glb> <run.glb> <idle.glb> <out_dir>
      [--head-drop 28] [--crouch 0.04] [--kick 55] [--kick-frames 20]
"""
import argparse, json, math, struct, sys
import bpy
from mathutils import Matrix, Vector

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("run"); ap.add_argument("idle"); ap.add_argument("out_dir")
ap.add_argument("--head-drop", type=float, default=28, help="degrees the neck and head drop for the charge")
ap.add_argument("--crouch", type=float, default=0.04, help="body lowered for the charge (mesh units)")
ap.add_argument("--kick", type=float, default=55, help="degrees the hind thighs swing back on the kick")
ap.add_argument("--kick-frames", type=int, default=20)
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

def fps_of(path):
    b = open(path, "rb").read(); n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + n])
    acc = max((j["accessors"][s["input"]] for s in j["animations"][0]["samplers"]), key=lambda x: x["count"])
    return round((acc["count"] - 1) / max(acc["max"][0] - acc["min"][0], 1e-6))

def smooth(x): x = min(max(x, 0.0), 1.0); return x * x * (3 - 2 * x)

def load(clip):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = fps_of(clip)
    bpy.ops.import_scene.gltf(filepath=a.base)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in [o for o in bpy.data.objects if o is not arm]: bpy.data.objects.remove(o)
    before = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=clip)
    act = next(iter(set(bpy.data.actions) - acts))
    for o in set(bpy.data.objects) - before: bpy.data.objects.remove(o)
    arm.animation_data_create(); arm.animation_data.action = act
    if len(act.slots): arm.animation_data.action_slot = act.slots[0]
    return arm, act

def find(arm, *names):
    for n in names:
        if n in arm.pose.bones: return arm.pose.bones[n]
    return None

def side_axis(arm):  # the body's side axis: left hip minus right hip
    l = find(arm, "BackLeg.L", "BackUpLeg.L", "hind_thigh_L"); r = find(arm, "BackLeg.R", "BackUpLeg.R", "hind_thigh_R")
    return (l.head - r.head).normalized()

def rot(pb, axis, deg):
    m = pb.matrix.copy(); piv = m.translation.copy()
    pb.matrix = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-piv) @ m
    bpy.context.view_layer.update()

def glue_feet(arm):  # root-parented foot controllers follow their shins
    for sd in ("L", "R"):
        for e in ("Back", "Front"):
            foot, shin = find(arm, f"{e}Foot.{sd}"), find(arm, f"{e}LowLeg.{sd}")
            if foot and shin and foot.parent is not shin:
                m = foot.matrix.copy(); m.translation = shin.tail.copy(); foot.matrix = m
                bpy.context.view_layer.update()

def export(arm, name, f0, f1):
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = f0, f1
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=f"{a.out_dir}/{name}.glb", export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_yup=True)

import os; os.makedirs(a.out_dir, exist_ok=True)

# charge: the run, head down, body low
arm, src = load(a.run)
f0, f1 = (int(round(x)) for x in src.frame_range)
side = side_axis(arm)
poses = []
for f in range(f0, f1 + 1):
    bpy.context.scene.frame_set(f)
    poses.append({pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones})
act = bpy.data.actions.new("charge"); arm.animation_data.action = act
neck = find(arm, "Neck", "neck_01"); head = find(arm, "Head", "head"); body = find(arm, "Body", "hips")
for i, f in enumerate(range(f0, f1 + 1)):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"; pb.matrix_basis = poses[i][pb.name]
    bpy.context.view_layer.update()
    if body:
        body.matrix = Matrix.Translation((0, 0, -a.crouch)) @ body.matrix; bpy.context.view_layer.update()
    for pb, share in ((neck, 0.6), (head, 0.4)):
        if pb: rot(pb, side, a.head_drop * share)  # nose down (+ about the left-hip axis on these -Y facing rigs)
    glue_feet(arm)
    for pb in arm.pose.bones:
        pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)
bpy.data.actions.remove(src)
export(arm, "charge", f0, f1)
print(f"CHARGE {f1 - f0 + 1} frames (loop, the run's length)")

# kick: idle's first pose, weight forward, hind thighs snap back, plant
arm, src = load(a.idle)
bpy.context.scene.frame_set(int(src.frame_range[0]))
start = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}
arm.animation_data.action = None; bpy.data.actions.remove(src)
side = side_axis(arm)
act = bpy.data.actions.new("kick"); arm.animation_data.action = act
thighs = [b for b in (find(arm, "BackUpLeg.L", "hind_thigh_L"), find(arm, "BackUpLeg.R", "hind_thigh_R")) if b]
shins = [b for b in (find(arm, "BackLowLeg.L", "hind_shin_L"), find(arm, "BackLowLeg.R", "hind_shin_R")) if b]
N = a.kick_frames; HIT = 0.45
for f in range(N):
    u = f / (N - 1)
    load_up = smooth(u / 0.3) * (1 - smooth((u - 0.3) / 0.12))          # wind-up: tuck the hind legs
    strike = smooth((u - 0.3) / (HIT - 0.3)) * (1 - smooth((u - 0.6) / 0.35))  # snap back and up, then plant
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"; pb.matrix_basis = start[pb.name]
    bpy.context.view_layer.update()
    if body: rot(body, side, 10 * strike - 4 * load_up)  # weight onto the front legs, rump up
    for t in thighs: rot(t, side, a.kick * strike - 20 * load_up)
    for s in shins: rot(s, side, -0.5 * a.kick * strike + 25 * load_up)
    glue_feet(arm)
    for pb in arm.pose.bones:
        pb.keyframe_insert("location", frame=f + 1); pb.keyframe_insert("rotation_quaternion", frame=f + 1)
export(arm, "kick", 1, N)
print(f"KICK {N} frames, hit_frac {HIT}")
