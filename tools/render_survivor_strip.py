#!/usr/bin/env python3
"""PNG strip of a survivor clip: one row per view (front, side), frames across. Fixed orthographic cameras and a
floor at z=0, so sinking and drift show. Optional: a prop rig playing the same-named animation (the satchel),
held props skinned to the survivor's armature (the hammer), and grey blocks standing in for a station.

  Blender -b --python tools/render_survivor_strip.py -- <survivor.glb> <clip.glb> <satchel.glb or -> <out.png>
      [--frames 8] [--size 260] [--ortho 1.95] [--cz 0.88] [--prop held.glb] [--box x0,y0,z0,x1,y1,z1 ...]
"""
import os, sys, tempfile
import bpy, numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
base, clip, satchel, out = a[:4]
opt = lambda n, d: a[a.index(n) + 1] if n in a else d
NF, SIZE = int(opt("--frames", "8")), int(opt("--size", "260"))
name = os.path.splitext(os.path.basename(clip))[0]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for pb in arm.pose.bones:
    if pb.custom_shape: pb.custom_shape.hide_render = True
before = set(bpy.data.actions); objs = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=clip)
act = next(iter(set(bpy.data.actions) - before)); act.name = "body_" + name
for o in set(bpy.data.objects) - objs: bpy.data.objects.remove(o)
arm.animation_data_create(); arm.animation_data.action = act
if len(act.slots): arm.animation_data.action_slot = act.slots[0]
if satchel != "-":
    before = set(bpy.data.actions); objs = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=satchel)
    sarm = next(o for o in set(bpy.data.objects) - objs if o.type == "ARMATURE")
    sact = next(x for x in set(bpy.data.actions) - before if x.name == name)
    sarm.animation_data_create(); sarm.animation_data.action = sact
    if len(sact.slots): sarm.animation_data.action_slot = sact.slots[0]
if "--prop" in a:  # skinned to a copy of the survivor's armature: move its meshes onto ours
    objs = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=opt("--prop", ""))
    new = set(bpy.data.objects) - objs
    for o in new:
        if o.type == "MESH" and o.vertex_groups:
            mw = o.matrix_world.copy(); o.parent = arm; o.matrix_world = mw
            for m in o.modifiers:
                if m.type == "ARMATURE": m.object = arm
    for o in new:
        if o.type == "ARMATURE":
            for c in o.children_recursive: bpy.data.objects.remove(c, do_unlink=True)
            bpy.data.objects.remove(o, do_unlink=True)
for i, x in enumerate(a):
    if x == "--box":
        v = [float(c) for c in a[i + 1].split(",")]
        bpy.ops.mesh.primitive_cube_add(size=1, location=[(v[k] + v[k + 3]) / 2 for k in range(3)])
        bpy.context.object.scale = [v[k + 3] - v[k] for k in range(3)]; bpy.context.object.name = "station_block"
for o in bpy.data.objects:
    if o.type == "MESH" and o.name.startswith(("Icosphere", "Cube")) and not o.vertex_groups: o.hide_render = True

sc = bpy.context.scene
try: sc.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError: sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = SIZE
sc.world = bpy.data.worlds.new("W"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.85, 0.9, 1)
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.5; sun.rotation_euler = (0.7, 0.2, 0.6)
bpy.ops.mesh.primitive_plane_add(size=3, location=(0, -0.3, 0))
fm = bpy.data.materials.new("floor"); fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.45, 0.47, 0.42, 1)
bpy.context.object.data.materials.append(fm)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = float(opt("--ortho", "1.95"))
C = Vector((0.03, -0.3, float(opt("--cz", "0.88"))))
VIEWS = {"front": (C + Vector((1.2, -4, 2.4)),), "side": (C + Vector((4, 0, 0.15)),)}
f0, f1 = (int(round(x)) for x in act.frame_range)
frames = [round(f0 + (f1 - f0) * i / (NF - 1)) for i in range(NF)]
tmp = tempfile.mkdtemp()
rows = []
for v, (pos,) in VIEWS.items():
    cam.location = pos
    cam.rotation_euler = (C - pos).to_track_quat("-Z", "Y").to_euler()
    tiles = []
    for f in frames:
        sc.frame_set(f)
        p = os.path.join(tmp, f"{v}_{f}.png"); sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(p)
        tiles.append(np.array(img.pixels[:], dtype=np.float32).reshape(SIZE, SIZE, 4))
        bpy.data.images.remove(img)
    rows.append(np.concatenate(tiles, axis=1))
grid = np.concatenate(rows[::-1], axis=0)  # pixel rows go bottom-up: first view ends on top
h, w = grid.shape[:2]
im = bpy.data.images.new("strip", w, h, alpha=True)
im.pixels = grid.ravel(); im.filepath_raw = out; im.file_format = "PNG"; im.save()
print("STRIP", out, "frames", frames)
