"""Side (or front/top) strip of a clip on the skinned mesh from clips.py's *_anim.blend: N frames left to right,
with a 1.78 m post for scale and a floor line. For checking poses by eye.
  Blender -b -P tools/gait/megaloceros/strip.py -- <rig_anim.blend> <clip> <out.png> [--n 6] [--view side|front|tq]
"""
import bpy, sys, math, os
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=a[0]); clip, out = a[1], a[2]
n = int(a[a.index("--n") + 1]) if "--n" in a else 6
view = a[a.index("--view") + 1] if "--view" in a else "side"
sc = bpy.context.scene
arm = bpy.data.objects["Armature"]; act = bpy.data.actions[clip]
arm.animation_data_create(); arm.animation_data.action = act
if len(act.slots): arm.animation_data.action_slot = act.slots[0]
f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x = 600; sc.render.resolution_y = 600
bpy.ops.mesh.primitive_plane_add(size=60); g = bpy.context.active_object
gm = bpy.data.materials.new("g"); gm.diffuse_color = (0.33, 0.31, 0.28, 1); g.data.materials.append(gm)
bpy.ops.mesh.primitive_cylinder_add(radius=0.1, depth=1.78, location=(2.2, -3.2, 0.89))
pm = bpy.data.materials.new("p"); pm.diffuse_color = (0.2, 0.4, 0.9, 1); bpy.context.active_object.data.materials.append(pm)
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; cam.ortho_scale = float(a[a.index("--size") + 1]) if "--size" in a else 8.0
co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co); sc.camera = co
if view == "side": co.location = (-30, 0.2, 2.6); co.rotation_euler = (math.pi / 2, 0, -math.pi / 2)
elif view == "front": co.location = (0, -30, 2.6); co.rotation_euler = (math.pi / 2, 0, 0)
else:
    co.location = (-18, -14, 12); co.rotation_euler = (Vector((0, 0.3, 1.8)) - Vector(co.location)).to_track_quat("-Z", "Y").to_euler()
tmp = out + "_tmp"; os.makedirs(tmp, exist_ok=True)
frames = [round(f0 + (f1 - f0) * i / max(1, n - 1)) for i in range(n)]
for i, f in enumerate(frames):
    sc.frame_set(f); sc.render.filepath = f"{tmp}/{i:02d}.png"; bpy.ops.render.render(write_still=True)
import subprocess
subprocess.run(["/usr/local/bin/python3", "-c", f"""
from PIL import Image, ImageDraw
ims=[Image.open('{tmp}/%02d.png'%i).convert('RGB') for i in range({n})]
c=Image.new('RGB',(600*{n},620),(30,30,30))
for i,im in enumerate(ims):
    c.paste(im,(600*i,20)); ImageDraw.Draw(c).text((600*i+6,2),'{clip} f{frames}'.split(' ')[0]+' frame '+str({frames}[i])+' ({{:.0f}}%)'.format(100*i/max(1,{n}-1)),fill=(255,255,0))
c.save('{out}')
"""])
