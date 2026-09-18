#!/usr/bin/env python3
"""Render inventory icons (PNG, transparent) from GLB models. Blender headless.
Usage: Blender --background --python tools/render_icons.py -- <out_dir> <size> <id=path.glb> [<id=path.glb> ...]
Writes <out_dir>/<id>.png and prints ICON <id>."""
import math, pathlib, sys
import bpy
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
out, size, pairs = pathlib.Path(argv[0]), int(argv[1]), argv[2:]
out.mkdir(parents=True, exist_ok=True)
for pair in pairs:
    iid, path = pair.split("=", 1)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE" if hasattr(bpy.types, "SceneEEVEE") else "BLENDER_WORKBENCH"
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        try: scene.render.engine = "BLENDER_EEVEE"
        except TypeError: scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = size; scene.render.resolution_y = size
    scene.render.film_transparent = True
    world = bpy.data.worlds.new("W"); world.use_nodes = True; scene.world = world
    bg = world.node_tree.nodes.get("Background"); bg.inputs[0].default_value = (1, 1, 1, 1); bg.inputs[1].default_value = 1.2
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in bpy.data.objects:
        if o.type == "MESH":
            for v in o.data.vertices:
                w = o.matrix_world @ v.co; lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    c = (lo + hi) / 2; L = max(hi - lo) or 1.0
    cam_data = bpy.data.cameras.new("C"); cam_data.type = "ORTHO"; cam_data.ortho_scale = L * 1.15
    cam = bpy.data.objects.new("C", cam_data); scene.collection.objects.link(cam); scene.camera = cam
    d = Vector((1.0, -1.0, 0.8)).normalized() * L * 4
    cam.location = c + d
    cam.rotation_euler = (Vector((0, 0, -1))).rotation_difference(-d.normalized()).to_euler()
    # look-at
    direction = c - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    sun = bpy.data.lights.new("S", "SUN"); sun.energy = 3.0
    so = bpy.data.objects.new("S", sun); scene.collection.objects.link(so); so.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.render.filepath = str(out / f"{iid}.png")
    bpy.ops.render.render(write_still=True)
    print(f"ICON {iid}")
