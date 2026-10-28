#!/usr/bin/env python3
"""Render neutral preview PNGs of GLB assets for the wiki art board (Blender headless).

Usage:
    Blender --background --python tools/render_model_cards.py -- <glb> <out.png> [<glb> <out.png> ...]

Each GLB is imported at its rest pose (frame 1) and rendered against a plain
light background with a fitted camera — a documentation card, not a beauty
shot. Zero credits; the wiki board (tools/docs_wiki/boards.js) links the PNGs.
"""
import sys
from math import radians
from pathlib import Path

import bpy
from mathutils import Vector


def render_one(glb: Path, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "EEVEE_NEXT", "BLENDER_EEVEE", "EEVEE", "CYCLES"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    bpy.ops.import_scene.gltf(filepath=str(glb))
    scene.frame_set(1)

    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    try:
        background.inputs[0].default_value = (0.93, 0.94, 0.95, 1.0)  # color socket (pre-5.x: RGBA)
    except ValueError:
        background.inputs[0].default_value = (0.93, 0.94, 0.95)  # 5.x: RGB only
    background.inputs[1].default_value = 1.0  # strength

    sun = bpy.data.lights.new("key_sun", "SUN")
    sun.energy = 2.5
    sun_obj = bpy.data.objects.new("key_sun", sun)
    scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (radians(45), 0, radians(35))
    fill = bpy.data.lights.new("fill", "SUN")
    fill.energy = 0.8
    fill_obj = bpy.data.objects.new("fill", fill)
    scene.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (radians(35), 0, radians(215))

    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"{glb}: no mesh geometry")
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    center = (low + high) / 2
    radius = max((high - low).length / 2, 1e-3)

    camera = bpy.data.cameras.new("card_camera")
    camera.lens = 40
    camera.clip_start = radius / 100
    camera.clip_end = radius * 100
    camera_obj = bpy.data.objects.new("card_camera", camera)
    scene.collection.objects.link(camera_obj)
    offset_scale = 0.55  # fills ~70% of the card frame
    camera_obj.location = center + Vector((radius * 1.2 * offset_scale, -radius * 2.4 * offset_scale, radius * 1.2 * offset_scale))
    direction = center - camera_obj.location
    camera_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera_obj

    scene.render.resolution_x = 960
    scene.render.resolution_y = 1200
    try:
        scene.view_settings.view_transform = "Standard"  # AgX would grey the light backdrop
    except TypeError:
        pass
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)
    print("CARD", out, f"radius={radius:.3f}")


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:]
    if len(argv) % 2:
        raise SystemExit("expected <glb> <out.png> pairs")
    for i in range(0, len(argv), 2):
        render_one(Path(argv[i]), Path(argv[i + 1]))


if __name__ == "__main__":
    main()
