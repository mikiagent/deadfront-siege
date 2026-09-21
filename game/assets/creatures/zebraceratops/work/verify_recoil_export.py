import bpy,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parent/'recoil_proof'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(ROOT/'recoil_proof.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
assert len(bpy.data.actions)==1
action=bpy.data.actions[0]
arm.animation_data.action=action;arm.animation_data.action_slot=action.slots[0]
for tr in list(arm.animation_data.nla_tracks):arm.animation_data.nla_tracks.remove(tr)
feet=[b.name for b in arm.pose.bones if 'Foot.' in b.name and not b.name.endswith('_end')]
rows=[]
for f in range(int(action.frame_range[0]),int(action.frame_range[1])+1):
 bpy.context.scene.frame_set(f);bpy.context.view_layer.update();points=[]
 for m in meshes:
  ev=m.evaluated_get(bpy.context.evaluated_depsgraph_get());data=ev.to_mesh();points.extend(ev.matrix_world@v.co for v in data.vertices);ev.to_mesh_clear()
 rows.append({'frame':f,'min_z':min(p.z for p in points),'max_z':max(p.z for p in points),'feet':{n:list(arm.matrix_world@arm.pose.bones[n].head) for n in feet}})
base=rows[0];height=base['max_z']-base['min_z']
max_foot=max(math.dist(row['feet'][n],base['feet'][n]) for row in rows for n in feet)
penetration=max(base['min_z']-row['min_z'] for row in rows)
weights=[[(g.group,g.weight) for g in v.groups if g.weight>1e-7] for m in meshes for v in m.data.vertices]
report={'frame_count':len(rows),'duration_seconds':(action.frame_range[1]-action.frame_range[0])/bpy.context.scene.render.fps,
'maximum_foot_travel':max_foot,'additional_ground_penetration':penetration,
'maximum_top_change_fraction':max(abs(r['max_z']-base['max_z']) for r in rows)/height,
'maximum_influences':max(map(len,weights)),'maximum_weight_sum_error':max(abs(sum(w for _,w in ws)-1) for ws in weights)}
report['pass']=max_foot<height*1e-5 and penetration<height*.01 and report['maximum_top_change_fraction']<.1 and report['maximum_influences']<=4 and report['maximum_weight_sum_error']<1e-5
(ROOT/'export_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('EXPORT_QA',json.dumps(report));assert report['pass']
