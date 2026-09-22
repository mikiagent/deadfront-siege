"""Headless Blender audit of exported creature meshes played with exported clips."""
import bpy,json,sys,math,os
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
out=Path(args[0]) if args else ROOT/'tools/rig_audit.json'
names=args[1:]
assets=Path(os.environ.get('CREATURE_ASSET_ROOT',str(ROOT/'game/assets/creatures')))

def points(m):
 ev=m.evaluated_get(bpy.context.evaluated_depsgraph_get());data=ev.to_mesh();v=np.array([ev.matrix_world@x.co for x in data.vertices]);ev.to_mesh_clear();return v

report={}
for src in sorted(assets.glob('*/*.glb')):
 if names and src.stem not in names:continue
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30
 bpy.ops.import_scene.gltf(filepath=str(src))
 arms=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(md.type=='ARMATURE' for md in o.modifiers)]
 if not arms or not meshes:continue
 arm=arms[0];arm.animation_data_clear()
 for b in arm.pose.bones:b.matrix_basis.identity()
 bpy.context.view_layer.update();m=max(meshes,key=lambda x:len(x.data.vertices));rest=points(m);height=np.ptp(rest[:,2]);edges=np.array([e.vertices[:] for e in m.data.edges]);length=np.linalg.norm(rest[edges[:,0]]-rest[edges[:,1]],axis=1);valid=length>height*1e-4
 weights=[[g.weight for g in v.groups if g.weight>1e-7] for v in m.data.vertices]
 data={'vertices':len(rest),'height':float(height),'max_influences':max(map(len,weights)),'weight_sum_error':max(abs(sum(w)-1) for w in weights),'clips':{}}
 for file in sorted((src.parent/'anim').glob('*.glb')):
  objs=set(bpy.data.objects);acts=set(bpy.data.actions);bpy.ops.import_scene.gltf(filepath=str(file));newacts=set(bpy.data.actions)-acts
  if not newacts:continue
  ca=next(o for o in set(bpy.data.objects)-objs if o.type=='ARMATURE')
  mismatch=max((arm.data.bones[b.name].matrix_local-b.matrix_local).magnitude if hasattr((arm.data.bones[b.name].matrix_local-b.matrix_local),'magnitude') else max(abs(x) for row in (arm.data.bones[b.name].matrix_local-b.matrix_local) for x in row) for b in ca.data.bones if b.name in arm.data.bones)
  act=next(iter(newacts))
  for o in set(bpy.data.objects)-objs:bpy.data.objects.remove(o,do_unlink=True)
  arm.animation_data_create();arm.animation_data.action=act;arm.animation_data.action_slot=act.slots[0]
  for tr in list(arm.animation_data.nla_tracks):arm.animation_data.nla_tracks.remove(tr)
  worst={'max_edge_ratio':0,'p99_edge_ratio':0,'bone_rest_mismatch':mismatch,'min_z':1e9}
  start_points=None
  for t in np.linspace(0,1,9):
   frame=act.frame_range[0]+t*(act.frame_range[1]-act.frame_range[0]);bpy.context.scene.frame_set(int(frame),subframe=float(frame%1));bpy.context.view_layer.update();v=points(m);ratio=np.linalg.norm(v[edges[:,0]]-v[edges[:,1]],axis=1)/np.maximum(length,1e-12)
   if t==0:start_points=v.copy()
   if t==1:worst['loop_max_vertex_delta']=float(np.linalg.norm(v-start_points,axis=1).max())
   assert np.isfinite(v).all(), f'{src.stem}/{file.stem}: nonfinite skin positions'
   worst['p99_edge_ratio']=max(worst['p99_edge_ratio'],float(np.quantile(ratio[valid],.99)));worst['min_z']=min(worst['min_z'],float(v[:,2].min()))
   if float(ratio[valid].max())>worst['max_edge_ratio']:
    idx=int(np.argmax(np.where(valid,ratio,0)));worst.update(max_edge_ratio=float(ratio[idx]),t=float(t),edge=[int(i) for i in edges[idx]],bounds=[v.min(axis=0).tolist(),v.max(axis=0).tolist()],pose_scale_max=max(max(b.scale) for b in arm.pose.bones))
  data['clips'][file.stem]=worst
  arm.animation_data.action=None
  for a in newacts:bpy.data.actions.remove(a)
 report[src.stem]=data
 print('AUDIT',src.stem,[(n,round(c['max_edge_ratio'],2),round(c['p99_edge_ratio'],2)) for n,c in data['clips'].items()],flush=True)
 out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2)+'\n')
