#!/usr/bin/env python3
"""Blender --background --python tools/author_quadruped_recoil.py -- source output_dir.

Build a dedicated, planted-foot hurt proof from a quadruped's first idle pose.
Does not overwrite the source asset. Output remains a rig proof until fitted to final art.
"""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Quaternion


def evaluated_vertices(mesh):
    obj = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data = obj.to_mesh()
    result = [obj.matrix_world @ v.co for v in data.vertices]
    obj.to_mesh_clear()
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('source', type=Path)
    p.add_argument('output_dir', type=Path)
    args = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if args.source.suffix.lower() == '.fbx':
        bpy.ops.import_scene.fbx(filepath=str(args.source.resolve()))
    else:
        bpy.ops.import_scene.gltf(filepath=str(args.source.resolve()))
    scene = bpy.context.scene
    scene.render.fps = 30
    arm = next(o for o in scene.objects if o.type == 'ARMATURE')
    meshes = [o for o in scene.objects if o.type == 'MESH' and any(mod.type == 'ARMATURE' for mod in o.modifiers)]
    assert meshes, 'No skinned mesh'
    idle = next((a for a in bpy.data.actions if 'idle' in a.name.lower()), None)
    arm.animation_data_create()
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
    arm.animation_data.action = idle
    if idle and idle.slots:
        arm.animation_data.action_slot = idle.slots[0]
    scene.frame_set(int(idle.frame_range[0]) if idle else 1)
    bpy.context.view_layer.update()
    neutral = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in arm.pose.bones}
    assert 'Neck' in neutral and 'Head' in neutral
    feet = [b.name for b in arm.pose.bones if 'Foot.' in b.name and not b.name.endswith('_end')]
    assert len(feet) == 4, f'Expected four feet, found {feet}'
    action = bpy.data.actions.new('hit_react')
    arm.animation_data.action = action
    # ASSUMPTION: a light hit is a 0.6 second neck recoil, with no locomotion or body roll.
    envelope = [(1, 0), (4, 1), (7, .65), (11, -.13), (15, .04), (19, 0)]
    for f, amount in envelope:
        scene.frame_set(f)
        for b in arm.pose.bones:
            loc, rot, scale = neutral[b.name]
            b.rotation_mode = 'QUATERNION'
            b.location, b.rotation_quaternion, b.scale = loc, rot, scale
            degrees = {'Neck': -6.0, 'Head': -3.0}.get(b.name, 0.0)
            if degrees:
                b.rotation_quaternion = rot @ Quaternion((1, 0, 0), math.radians(degrees * amount))
            for prop in ('location', 'rotation_quaternion', 'scale'):
                b.keyframe_insert(data_path=prop, frame=f, group=b.name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points:
                        k.interpolation = 'BEZIER'
                        k.handle_left_type = k.handle_right_type = 'AUTO_CLAMPED'
    scene.frame_start, scene.frame_end = 1, 19
    frames = []
    ground_ids, ground_start, ground_travel = [], [], 0.0
    for f in range(1, 20):
        scene.frame_set(f)
        bpy.context.view_layer.update()
        vertices = [v for m in meshes for v in evaluated_vertices(m)]
        if f == 1:
            low, high = min(v.z for v in vertices), max(v.z for v in vertices)
            ground_ids = [i for i, v in enumerate(vertices) if v.z < low + (high - low) * .035]
            ground_start = [vertices[i].copy() for i in ground_ids]
        ground_travel = max(ground_travel, max((vertices[i] - start).length for i, start in zip(ground_ids, ground_start)))
        frames.append({'frame': f, 'min': [min(v[i] for v in vertices) for i in range(3)],
                       'max': [max(v[i] for v in vertices) for i in range(3)],
                       'feet': {n: list(arm.matrix_world @ arm.pose.bones[n].head) for n in feet}})
    base = frames[0]
    height = base['max'][2] - base['min'][2]
    max_foot = max(math.dist(row['feet'][n], base['feet'][n]) for row in frames for n in feet)
    added_penetration = max(base['min'][2] - row['min'][2] for row in frames)
    height_change = max(abs(row['max'][2] - base['max'][2]) for row in frames)
    report = {'source': str(args.source), 'duration_seconds': .6, 'foot_travel': max_foot,
              'additional_ground_penetration': added_penetration, 'ground_vertex_travel': ground_travel, 'maximum_top_change_fraction': height_change / height,
              'pass': ground_travel < height * .005 and max_foot < height * .00001 and added_penetration < height * .01 and height_change < height * .1,
              'frames': frames}
    (out / 'recoil_validation.json').write_text(json.dumps(report, indent=2) + '\n')
    assert report['pass'], json.dumps({k: v for k, v in report.items() if k != 'frames'})
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(out / 'recoil_proof.blend'))
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    for mesh in meshes:
        mesh.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out / 'recoil_proof.glb'), export_format='GLB', use_selection=True,
        export_animations=True, export_animation_mode='ACTIVE_ACTIONS', export_frame_range=True,
        export_force_sampling=True, export_skins=True, export_yup=True)
    print('RECOIL_QA ' + json.dumps({k: v for k, v in report.items() if k != 'frames'}))


if __name__ == '__main__':
    main()
