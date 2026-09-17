#!/usr/bin/env python3
"""Render posed frames of an animated GLB so skinning quality can be judged.

Blender headless. For every animation in the file (or the ones named with
--clips), sets the scene to a fraction of the clip and renders a side view
framed on the *deformed* mesh. Output: <out_prefix>_<clip>.png

Usage:
  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/render_posed.py -- \
      <file.glb> <out_prefix> [--frac 0.5] [--clips idle,attack_primary] [--view side|front|three_quarter]
"""
import argparse, math, pathlib, sys
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
p = argparse.ArgumentParser()
p.add_argument("glb"); p.add_argument("out_prefix")
p.add_argument("--frac", type=float, default=0.5)
p.add_argument("--clips", default="")
p.add_argument("--view", default="side")
p.add_argument("--anim", default="", help="extra GLB(s) whose animations are applied to the base armature (comma-separated)")
a = p.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.glb)
base_arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
for extra in [x for x in a.anim.split(",") if x]:
    before = set(bpy.data.objects); acts_before = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=extra)
    for act in bpy.data.actions:
        if act not in acts_before:
            act.name = pathlib.Path(extra).stem
    for o in [o for o in bpy.data.objects if o not in before]:
        bpy.data.objects.remove(o)
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "TEXTURE"
scene.render.resolution_x = 900; scene.render.resolution_y = 600
scene.render.film_transparent = False
world = bpy.data.worlds.new("W"); world.color = (1, 1, 1); scene.world = world
arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
cam_data = bpy.data.cameras.new("C"); cam_data.type = "ORTHO"
cam = bpy.data.objects.new("C", cam_data); scene.collection.objects.link(cam); scene.camera = cam
wanted = [c for c in a.clips.split(",") if c] or [x.name for x in bpy.data.actions]

def deformed_bbox():
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((math.inf,) * 3); hi = Vector((-math.inf,) * 3)
    for o in meshes:
        ev = o.evaluated_get(dg)
        for v in ev.data.vertices:
            w = ev.matrix_world @ v.co
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi

for act in bpy.data.actions:
    if not any(act.name == w or act.name.endswith(w) for w in wanted):
        continue
    if arm:
        if arm.animation_data is None: arm.animation_data_create()
        arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and len(act.slots):
            arm.animation_data.action_slot = act.slots[0]
    f0, f1 = act.frame_range
    scene.frame_set(int(f0 + (f1 - f0) * a.frac))
    lo, hi = deformed_bbox()
    c = (lo + hi) / 2; size = hi - lo; L = max(size.x, size.y, size.z)
    if a.view == "side":
        cam.location = (c.x + L * 3, c.y, c.z); cam.rotation_euler = (math.radians(90), 0, math.radians(90))
    elif a.view == "front":
        cam.location = (c.x, c.y - L * 3, c.z); cam.rotation_euler = (math.radians(90), 0, 0)
    else:
        cam.location = (c.x + L * 2.2, c.y - L * 2.2, c.z + L * 1.2); cam.rotation_euler = (math.radians(65), 0, math.radians(45))
    cam_data.ortho_scale = L * 1.25
    out = f"{a.out_prefix}_{act.name.split('|')[-1]}.png"
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print(f"RENDERED {out} clip={act.name} frame={scene.frame_current} bbox={[round(v,2) for v in size]}")
