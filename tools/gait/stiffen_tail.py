"""Damp the tail in existing clips: every Tail* bone's local turn from rest is scaled by --keep (slerp toward rest),
so a donor's whippy raptor tail reads as a long stiff one. Other bones are untouched; exports skeleton-only.

usage: Blender -b -P tools/gait/stiffen_tail.py -- <out_dir> <clip.glb> [...] [--keep 0.35]
"""
import os
import sys

import bpy
from mathutils import Quaternion

argv = sys.argv[sys.argv.index("--") + 1:]
KEEP = float(argv[argv.index("--keep") + 1]) if "--keep" in argv else 0.35
args = [a for i, a in enumerate(argv) if a != "--keep" and (i == 0 or argv[i - 1] != "--keep")]
OUT, CLIPS = args[0], args[1:]
os.makedirs(OUT, exist_ok=True)
for path in CLIPS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24
    bpy.ops.import_scene.gltf(filepath=path)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    act = arm.animation_data.action
    f0, f1 = (int(round(x)) for x in act.frame_range)
    tails = [pb for pb in arm.pose.bones if pb.name.startswith("Tail")]
    keyed = {}
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        keyed[f] = {pb.name: Quaternion((1, 0, 0, 0)).slerp(pb.rotation_quaternion, KEEP) for pb in tails}
    for f, rows in keyed.items():
        for pb in tails:
            pb.rotation_quaternion = rows[pb.name]
            pb.keyframe_insert("rotation_quaternion", frame=f)
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = f0, f1
    for o in list(bpy.data.objects):
        if o is not arm:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    out = os.path.join(OUT, os.path.basename(path))
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", export_yup=True, use_selection=True, export_animations=True,
        export_animation_mode="ACTIVE_ACTIONS", export_force_sampling=True, export_frame_step=1,
        export_optimize_animation_size=False, export_anim_slide_to_zero=False, export_skins=True,
        export_morph=False, export_def_bones=False, export_reset_pose_bones=False, export_current_frame=False,
        export_nla_strips=False, export_anim_single_armature=True, export_bake_animation=True,
        export_materials="NONE", export_image_format="NONE")
    print("STIFFENED", out, len(tails), "tail bones, keep", KEEP)
