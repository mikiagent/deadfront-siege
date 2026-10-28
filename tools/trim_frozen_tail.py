#!/usr/bin/env python3
"""Cut a looping clip's frozen tail in the GLB itself: donor walks play one stride, then hold the start pose for the
rest of the file. t_canim allows at most 25 % frozen. Keeps frames up to the first one that equals the start pose
after the motion ends (so the loop stays seamless) and re-exports skeleton-only like the other clips.

  Blender -b --python tools/trim_frozen_tail.py -- <base.glb> <clip.glb> <out.glb> [--eps 0.0005]
"""
import argparse, sys
import bpy

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("clip"); ap.add_argument("out")
ap.add_argument("--eps", type=float, default=0.0005)
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

import json, struct
b = open(a.clip, "rb").read(); n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + n])
acc = max((j["accessors"][s["input"]] for s in j["animations"][0]["samplers"]), key=lambda x: x["count"])
fps = round((acc["count"] - 1) / max(acc["max"][0] - acc["min"][0], 1e-6))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = fps
bpy.ops.import_scene.gltf(filepath=a.base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in [o for o in bpy.data.objects if o is not arm]: bpy.data.objects.remove(o)
before = set(bpy.data.objects); acts = set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=a.clip)
act = next(iter(set(bpy.data.actions) - acts)); act.name = "walk" if "walk" in a.clip else act.name
for o in set(bpy.data.objects) - before: bpy.data.objects.remove(o)
arm.animation_data_create(); arm.animation_data.action = act
if len(act.slots): arm.animation_data.action_slot = act.slots[0]
f0, f1 = (int(round(x)) for x in act.frame_range)

def pose(f):
    bpy.context.scene.frame_set(f)
    return [c for pb in arm.pose.bones for c in (*pb.location, *pb.rotation_quaternion)]

poses = [pose(f) for f in range(f0, f1 + 1)]
moving = [max(abs(x - y) for x, y in zip(p, q)) > a.eps for p, q in zip(poses, poses[1:])]
last = max(i for i, m in enumerate(moving) if m) + 1  # index of the first frame after the motion stops
end = f0 + last
print(f"TRIM {a.clip}: {fps} fps, frames {f0}-{f1}, motion ends at frame {end}; "
      f"end pose vs start {max(abs(x - y) for x, y in zip(poses[last], poses[0])):.4f}")
bpy.context.scene.frame_start, bpy.context.scene.frame_end = f0, end
act.frame_range = (f0, end); act.use_frame_range = True
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_force_sampling=True, export_yup=True)
print("WROTE", a.out)
