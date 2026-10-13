"""Retarget KayKit CC0 Lie_* clips to the original Meshy survivor. Blender 4.5+.
Usage: blender -b --python tools/retarget_kaykit_sleep.py
No model/texture changes: only skeleton + proxy skin and clip tracks.
"""
import bpy,sys,pathlib,json
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
code=(ROOT/"tools/retarget_human.py").read_text();exec(code.rsplit('\nmain()',1)[0])
MAP={'hips':['Hips'],'spine':['Spine02'],'chest':['Spine01','Spine'],'head':['neck','Head']}
for side,t in [('l','Left'),('r','Right')]:
 for s,d in [('upperarm','Arm'),('lowerarm','ForeArm'),('hand','Hand'),('upperleg','UpLeg'),('lowerleg','Leg'),('foot','Foot'),('toes','ToeBase')]:MAP[s+'.'+side]=[t+d]
ROOT_SRC='hips';ROOT_TGT='Hips'
for name,clip in [('Lie_Idle','sleep'),('Lie_Down','sleep_down'),('Lie_StandUp','sleep_up')]:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/characters/survivor/survivor.glb'))
 tgt=next(o for o in bpy.data.objects if o.type=='ARMATURE'); meshes=[o for o in bpy.data.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)];tgt.animation_data_clear()
 for x in list(bpy.data.actions):bpy.data.actions.remove(x)
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/'tools/standins/kaykit/Rig_Medium_Simulation.glb'));src=next(o for o in set(bpy.data.objects)-before if o.type=='ARMATURE');act=bpy.data.actions[name];src.animation_data_create();src.animation_data.action=act;src.animation_data.action_slot=act.slots[0]
 for tr in list(src.animation_data.nla_tracks):src.animation_data.nla_tracks.remove(tr)
 f0,f1=map(lambda x:int(round(x)),act.frame_range);new=retarget(tgt,src,act,clip,(f0,f1),24)
 # Ground evaluated real skin frame by frame. Fix horizontal hips at the standing origin.
 for f in range(f0,f1+1):
  bpy.context.scene.frame_set(f);bpy.context.view_layer.update();pb=tgt.pose.bones['Hips'];mat=pb.matrix.copy();mat.translation.x=tgt.data.bones['Hips'].head_local.x;mat.translation.y=tgt.data.bones['Hips'].head_local.y;pb.matrix=mat;bpy.context.view_layer.update()
  dg=bpy.context.evaluated_depsgraph_get();low=min((m.matrix_world@v.co).z for m in meshes for v in m.evaluated_get(dg).data.vertices);mat=pb.matrix.copy();mat.translation.z+=(0.015-low)/tgt.scale.z;pb.matrix=mat;pb.keyframe_insert('location',frame=f)
 for o in list(bpy.data.objects):
  if o!=tgt:bpy.data.objects.remove(o,do_unlink=True)
 proxy=add_proxy_skin(tgt);out=(ROOT/'game/assets/characters/survivor/anim')/(clip+'.glb');export(tgt,proxy,out);print('DONE',clip,f1/24,out.stat().st_size)
