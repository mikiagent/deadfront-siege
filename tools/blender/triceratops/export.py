# Export the package: <out>/triceratops.glb (mesh + rig at rest, textures) and <out>/anim/<clip>.glb (rig + skin, one
# action, no mesh, no images). Blender -b anim.blend --factory-startup -P export.py -- <outdir>
import bpy, sys, os
out = sys.argv[sys.argv.index("--") + 1]; os.makedirs(out + "/anim", exist_ok=True)
arm = bpy.data.objects["Armature"]; mesh = bpy.data.objects["SM_Triceratops"]
for o in list(bpy.data.objects):
    if o not in (arm, mesh): bpy.data.objects.remove(o, do_unlink=True)
sc = bpy.context.scene; sc.render.fps = 30
arm.animation_data_create(); arm.animation_data.action = None
for pb in arm.pose.bones: pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
bpy.context.view_layer.update()
COMMON = dict(export_format="GLB", use_selection=True, export_yup=True, export_skins=True, export_def_bones=False, export_morph=False)
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=f"{out}/triceratops.glb", export_animations=False, export_image_format="AUTO", export_materials="EXPORT", **COMMON)
print("WROTE base")
clips = ["idle", "walk", "run", "attack_primary", "attack_heavy", "hit_react", "knockdown", "death", "alert"]
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); bpy.context.view_layer.objects.active = arm
for c in clips:
    act = bpy.data.actions[c]
    arm.animation_data.action = act
    try: arm.animation_data.action_slot = act.slots[0]
    except Exception: pass
    sc.frame_start, sc.frame_end = int(act.frame_range[0]), int(act.frame_range[1])
    bpy.ops.export_scene.gltf(filepath=f"{out}/anim/{c}.glb", export_animations=True, export_animation_mode="ACTIVE_ACTIONS",
        export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_anim_slide_to_zero=True,
        export_reset_pose_bones=True, export_current_frame=False, export_nla_strips=False, export_anim_single_armature=True,
        export_bake_animation=False, export_materials="NONE", export_image_format="NONE", **COMMON)
    print("WROTE", c, sc.frame_start, sc.frame_end)
