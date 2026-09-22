"""Render the real exported base plus clip at evenly spaced times, with a fixed camera."""
import argparse,sys,math
from pathlib import Path
import bpy
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('model',type=Path);p.add_argument('out',type=Path);p.add_argument('--clips',nargs='+',default=['idle','walk','hit_react','death']);p.add_argument('--samples',type=int,default=5);p.add_argument('--side',action='store_true');p.add_argument('--view',choices=['three_quarter','front','top','side'],default='three_quarter');a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30;bpy.ops.import_scene.gltf(filepath=str(a.model.resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(x.type=='ARMATURE' for x in o.modifiers)]
arm.animation_data_clear()
for b in arm.pose.bones:b.matrix_basis.identity()
bpy.context.view_layer.update();pts=[m.matrix_world@v.co for m in meshes for v in m.data.vertices];low=Vector(tuple(min(v[i] for v in pts) for i in range(3)));high=Vector(tuple(max(v[i] for v in pts) for i in range(3)));center=(low+high)/2;span=(high-low).length
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=720;s.render.resolution_y=480;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.world=bpy.data.worlds.new('Studio');s.world.use_nodes=True
bg=next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.07,.085,.10,1);bg.inputs['Strength'].default_value=.7
s.view_settings.view_transform='AgX'
c=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'));s.collection.objects.link(c);s.camera=c;c.data.type='ORTHO';c.data.ortho_scale=span*1.20;c.data.clip_end=span*20;c.data.clip_start=.001
direction={'three_quarter':(1,-1,.6),'front':(0,-1,.06),'top':(.001,0,1),'side':(1,0,.06)}['side' if a.side else a.view]
c.location=center+Vector(direction).normalized()*span*3;c.rotation_euler=(center-c.location).to_track_quat('-Z','Y').to_euler()
for off,power in [((1,-1,2),160),((-1,-.5,1),80),((0,2,2),120)]:
 l=bpy.data.objects.new('Softbox',bpy.data.lights.new('Softbox','AREA'));s.collection.objects.link(l);l.location=center+Vector(off)*span;l.data.energy=power*span*span;l.data.size=span*1.5;l.rotation_euler=(center-l.location).to_track_quat('-Z','Y').to_euler()
a.out.mkdir(parents=True,exist_ok=True)
for clip in a.clips:
 old=set(bpy.data.objects);acts=set(bpy.data.actions);bpy.ops.import_scene.gltf(filepath=str(a.model.parent/'anim'/f'{clip}.glb'));act=next(x for x in bpy.data.actions if x not in acts)
 for o in set(bpy.data.objects)-old:bpy.data.objects.remove(o,do_unlink=True)
 arm.animation_data_create();arm.animation_data.action=act;arm.animation_data.action_slot=act.slots[0]
 for track in list(arm.animation_data.nla_tracks):arm.animation_data.nla_tracks.remove(track)
 for i in range(a.samples):
  t=i/max(1,a.samples-1);f=act.frame_range[0]+t*(act.frame_range[1]-act.frame_range[0]);s.frame_set(int(f),subframe=f%1);s.render.filepath=str((a.out/f'{clip}_{i:03d}.png').resolve());bpy.ops.render.render(write_still=True)
 arm.animation_data.action=None;bpy.data.actions.remove(act)
