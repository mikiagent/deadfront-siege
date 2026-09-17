#!/usr/bin/env python3
"""Blender --background --python tools/render_glb.py -- input.glb output.png.

Sheet order: left side, front, top, three-quarter. GLTF +Z forward becomes
Blender -Y forward on import. The source geometry is never modified.
"""
import argparse
import json
import pathlib
import sys
import tempfile

import bpy
from mathutils import Vector


REQUIRED_CLIPS = ("idle", "walk", "run", "attack_primary", "attack_heavy",
                  "hit_react", "knockdown", "death", "alert")


def inspect_rig(source):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
    bones = sorted({bone.name for obj in armatures for bone in obj.data.bones})
    roots = sorted({bone.name for obj in armatures for bone in obj.data.bones if bone.parent is None})
    fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    clips = [{"name": action.name, "duration_seconds": (action.frame_range[1]-action.frame_range[0])/fps}
             for action in bpy.data.actions]
    return {"bones": bones, "roots": roots, "clips": clips}


def validate_clips(source):
    base = inspect_rig(source)
    report = {"model": str(source), "rig": base, "clips": {}, "pass": bool(base["bones"])}
    for name in REQUIRED_CLIPS:
        path = source.parent / 'anim' / (name + '.glb')
        if not path.is_file():
            report['clips'][name] = {"pass": False, "error": "missing"}
        else:
            data = inspect_rig(path)
            data['pass'] = data['bones'] == base['bones'] and bool(data['clips']) and all(c['duration_seconds'] > 0 for c in data['clips'])
            report['clips'][name] = data
        report['pass'] = report['pass'] and report['clips'][name]['pass']
    print('CLIP_VALIDATION ' + json.dumps(report))
    if not report['pass']:
        raise SystemExit('Clip contract validation failed')


def main():
    args = sys.argv[sys.argv.index('--') + 1:]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('glb', type=pathlib.Path)
    parser.add_argument('output', type=pathlib.Path)
    parser.add_argument('--forward', choices=['-Y', '-X'], default='-Y', help='Forward axis after Blender import; changes cameras only')
    parser.add_argument('--validate-clips', action='store_true', help='Assert bone sets and positive durations for every required clip before rendering')
    options = parser.parse_args(args)
    source, output = options.glb.resolve(), options.output.resolve()
    if options.validate_clips:
        validate_clips(source)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and not o.hide_render and o.visible_get()]
    if not meshes:
        raise SystemExit('GLB has no mesh')
    points = []
    graph = bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        points.extend(evaluated.matrix_world @ vertex.co for vertex in mesh.vertices)
        evaluated.to_mesh_clear()
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    print('BOUNDING_BOX_METRES ' + json.dumps({'min': list(low), 'max': list(high), 'size': list(high-low)}))
    for o in bpy.context.scene.objects:
        if o.type == 'ARMATURE':
            print('BONES ' + json.dumps([b.name for b in o.data.bones]))
    center = (low + high) / 2
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 16
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = False
    scene.display.shading.show_cavity = False
    scene.display.shading.show_specular_highlight = False
    scene.display.shading.background_type = 'WORLD'
    scene.world = bpy.data.worlds.new('White')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (1, 1, 1, 1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
    scene.render.film_transparent = False
    scene.view_settings.view_transform = 'Standard'
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    camera_data = bpy.data.cameras.new('Orthographic')
    camera = bpy.data.objects.new('Orthographic', camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera_data.type = 'ORTHO'
    span = (high-low).length
    camera_data.clip_end = max(100, span*10)
    # ASSUMPTION: meshes follow the contract's +Z forward, Y-up GLTF convention.
    views = [('left', (-1, 0, 0)), ('front', (0, -1, 0)),
             ('top', (0, 0, 1)), ('three-quarter', (-1, -1, .65))]
    if options.forward == '-X':
        views = [('left', (0, -1, 0)), ('front', (-1, 0, 0)),
                 ('top', (0, 0, 1)), ('three-quarter', (-1, -1, .65))]
    sheet = bpy.data.images.new('Sheet', width=1024, height=1024, alpha=True)
    pixels = [1.0] * (1024 * 1024 * 4)
    with tempfile.TemporaryDirectory() as temp:
        for index, (name, direction) in enumerate(views):
            camera.location = center + Vector(direction).normalized() * span * 2
            camera.rotation_euler = (center-camera.location).to_track_quat('-Z', 'Y').to_euler()
            bpy.context.view_layer.update()
            inv = camera.matrix_world.inverted()
            projected = [inv @ p for p in points]
            camera_data.ortho_scale = max(max(p[i] for p in projected)-min(p[i] for p in projected) for i in (0,1))*1.15
            scene.render.filepath = str(pathlib.Path(temp) / (name+'.png'))
            bpy.ops.render.render(write_still=True)
            frame = bpy.data.images.load(scene.render.filepath)
            data = list(frame.pixels)
            x, y = (index % 2)*512, (1-index//2)*512
            for row in range(512):
                start = ((y+row)*1024+x)*4
                pixels[start:start+512*4] = data[row*512*4:(row+1)*512*4]
            bpy.data.images.remove(frame)
    sheet.pixels.foreach_set(pixels)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.filepath_raw = str(output)
    sheet.file_format = 'PNG'
    sheet.save()
    print('SHEET ' + str(output))


if __name__ == '__main__':
    main()
