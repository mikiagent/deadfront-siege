import bpy,json,math
from mathutils import Vector
from pathlib import Path
root=Path('/Users/milankinzy/Documents/deadfront-siege')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'game/assets/creatures/protoceratops/protoceratops.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
before=set(bpy.data.objects);actions=set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=str(root/'game/assets/creatures/protoceratops/anim/hit_react.glb'))
action=next(a for a in bpy.data.actions if a not in actions)
for o in set(bpy.data.objects)-before:bpy.data.objects.remove(o,do_unlink=True)
arm.animation_data_create();arm.animation_data.action=action;arm.animation_data.action_slot=action.slots[0]
for track in list(arm.animation_data.nla_tracks): arm.animation_data.nla_tracks.remove(track)
report=[]
for t in [0,.25,.5,.75,1]:
 f0,f1=action.frame_range;bpy.context.scene.frame_set(round(f0+t*(f1-f0)));bpy.context.view_layer.update()
 ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());em=ev.to_mesh();p=[ev.matrix_world@v.co for v in em.vertices]
 lo=[min(v[i] for v in p) for i in range(3)];hi=[max(v[i] for v in p) for i in range(3)]
 report.append({'t':t,'min':lo,'max':hi,'head':list(arm.matrix_world@arm.pose.bones['Head'].head),'body':list(arm.matrix_world@arm.pose.bones['Body'].head)})
 ev.to_mesh_clear()
print('AUDIT',json.dumps(report));(root/'game/assets/creatures/zebraceratops/work/protoceratops_hurt_audit.json').write_text(json.dumps(report,indent=2))
