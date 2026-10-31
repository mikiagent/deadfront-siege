# Tripo artefacts on the tarbosaurus: two claw spikes from the hands to the floor (faces with an edge over 20 % of the
# height) and the two claw tips they left floating in front of the hands (frame A box y 7.7..8.4, z 3.0..4.3).
import bpy,sys,bmesh,math
from mathutils import Matrix
a=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=a[0])
o=max((o for o in bpy.data.objects if o.type=='MESH'),key=lambda o:len(o.data.vertices))
o.data.transform(o.matrix_world); o.parent=None; o.matrix_world=Matrix.Identity(4)
bm=bmesh.new(); bm.from_mesh(o.data)
R=Matrix.Rotation(math.pi/2,4,'Z'); P=[R@v.co for v in bm.verts]
z0,z1=min(p.z for p in P),max(p.z for p in P); cx=(max(p.x for p in P)+min(p.x for p in P))/2; cy=(max(p.y for p in P)+min(p.y for p in P))/2
A=Matrix.Scale(8.0/(z1-z0),4)@Matrix.Translation((-cx,-cy,-z0))@R
bad=[f for f in bm.faces if any(e.calc_length()>0.2*(z1-z0) for e in f.edges)]
bmesh.ops.delete(bm,geom=bad,context='FACES')
box=[v for v in bm.verts if (lambda p: 7.7<p.y<8.4 and 3.0<p.z<4.3 and abs(p.x)<1.6)(A@v.co)]
print('spike faces',len(bad),'floating claw verts',len(box))
bmesh.ops.delete(bm,geom=box,context='VERTS')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
bm.to_mesh(o.data); bm.free()
for x in list(bpy.data.objects):
    if x is not o: bpy.data.objects.remove(x)
bpy.ops.export_scene.gltf(filepath=a[1],export_format='GLB')
