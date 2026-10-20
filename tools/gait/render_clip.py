"""Render side-view frames of an existing clip GLB on its base mesh, same camera as make_gait.py.

usage: Blender -b -P tools/gait/render_clip.py -- <base.glb> <clip.glb> <species.json> <frames_dir> [--textured]
"""
import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_frames

a = sys.argv[sys.argv.index("--") + 1:]
base, clip, cfg, out = a[:4]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in bpy.data.objects:
    if o.type == "MESH" and o.name.startswith("Icosphere"):
        o.hide_render = True
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=clip)
act = next(o for o in set(bpy.data.objects) - before if o.type == "ARMATURE").animation_data.action
for o in set(bpy.data.objects) - before:
    bpy.data.objects.remove(o, do_unlink=True)
arm.animation_data_create()
arm.animation_data.action = act
try:
    arm.animation_data.action_slot = act.slots[0]
except Exception:
    pass
f0, f1 = (int(round(x)) for x in act.frame_range)
sc = bpy.context.scene
sc.render.fps = 24
cfg = json.load(open(cfg))
# the clip's own ground speed: median backward speed of each foot while it is near its lowest point
speeds = []
for leg in cfg["legs"].values():
    ys = []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        p = arm.pose.bones[leg["foot"]].head
        ys.append((p.y, p.z))
    zmin = min(z for _, z in ys)
    speeds += [(ys[i][0] - ys[i - 1][0]) * 24 for i in range(1, len(ys)) if ys[i][1] < zmin + 0.01 and ys[i - 1][1] < zmin + 0.01]
speeds.sort()
v = -speeds[len(speeds) // 2] if speeds else 0.0  # forward is -y, so planted feet move +y
v = abs(v)
print("GROUND_SPEED", round(v, 3))
render_frames.render(sc, cfg, out, f1 - f0, "--textured" in a, first=f0, ground_speed=v)
print("RENDERED", f1 - f0, "frames from", clip)
