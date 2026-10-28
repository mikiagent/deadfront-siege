#!/usr/bin/env python3
"""Close-up renders of a creature's head at chosen clip frames, for jaw review.

Blender headless. Frames the camera on the Head bone (works on the deformed pose) and renders one PNG per
(frame, view). Same camera for any mesh with the same skeleton, so old and new compare 1:1.

  Blender -b --python tools/jaw/render_head.py -- <base.glb> <clip.glb|-> <out_prefix> \
      [--frames 0,35] [--views side,threeq,front] [--size 900] [--head Head] [--span 4.5]
"""
import argparse, math, sys
import bpy
from mathutils import Vector

a = argparse.ArgumentParser()
a.add_argument("glb"); a.add_argument("clip"); a.add_argument("out")
a.add_argument("--frames", default="0"); a.add_argument("--views", default="side,threeq,front")
a.add_argument("--size", type=int, default=900); a.add_argument("--head", default="Head")
a.add_argument("--span", type=float, default=4.5, help="ortho width in metres")
a = a.parse_args(sys.argv[sys.argv.index("--") + 1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.glb)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
if a.clip != "-":
    before = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=a.clip)
    act = next(iter(set(bpy.data.actions) - acts))
    for o in set(bpy.data.objects) - before: bpy.data.objects.remove(o)
    arm.animation_data_create(); arm.animation_data.action = act
    if len(getattr(act, "slots", [])): arm.animation_data.action_slot = act.slots[0]
else:
    arm.animation_data_clear()

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_cavity = True
sc.render.resolution_x = sc.render.resolution_y = a.size
w = bpy.data.worlds.new("W"); w.color = (0.93, 0.93, 0.9); sc.world = w
cd = bpy.data.cameras.new("C"); cd.type = "ORTHO"; cd.ortho_scale = a.span
cam = bpy.data.objects.new("C", cd); sc.collection.objects.link(cam); sc.camera = cam

for fr in [int(x) for x in a.frames.split(",")]:
    sc.frame_set(fr)
    pb = arm.pose.bones[a.head]
    # aim at the middle of the head bone, pushed a little toward the snout
    tgt = arm.matrix_world @ (pb.head.lerp(pb.tail, 0.5))
    fwd = (arm.matrix_world.to_3x3() @ (pb.tail - pb.head)).normalized()
    tgt = tgt + fwd * a.span * 0.12
    for v in a.views.split(","):
        # yaw measured from the animal's left side (-X in Blender for +Y facing), degrees
        yaw, pitch = {"side": (0, 0), "threeq": (40, 15), "front": (85, 8), "below": (30, -30)}[v]
        base = math.atan2(fwd.y, fwd.x) + math.pi / 2  # left side of the head
        ang = base - math.radians(yaw)
        d = Vector((math.cos(ang), math.sin(ang), math.tan(math.radians(pitch)))).normalized()
        cam.location = tgt + d * 30
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = f"{a.out}_f{fr:03d}_{v}.png"
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)
