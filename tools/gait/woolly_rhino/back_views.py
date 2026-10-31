"""Render the woolly rhino's back from six high angles (RHINOHOLE before/after shots; sheet: back_sheet.sh <prefix> <out.jpg>).
  Blender -b -P tools/gait/woolly_rhino/back_views.py -- <model.glb> <abs out_prefix> [<clip.glb> <frac>] [--cull]
  --cull: back faces invisible so every hole shows the red sky; default is double-sided like the game."""
import bpy, sys, math
from mathutils import Vector
a = sys.argv[sys.argv.index("--")+1:]
cull = "--cull" in a; a = [x for x in a if x != "--cull"]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
for s in shapes: s.hide_render = True
body = next(o for o in bpy.data.objects if o.type == "MESH" and o not in shapes)
sc = bpy.context.scene
if len(a) > 2:
    before = set(bpy.data.actions); before_o = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=a[2])
    act = next(x for x in bpy.data.actions if x not in before)
    for o in set(bpy.data.objects) - before_o: bpy.data.objects.remove(o, do_unlink=True)
    arm.animation_data_create(); arm.animation_data.action = act
    if len(act.slots): arm.animation_data.action_slot = act.slots[0]
    f0, f1 = act.frame_range; sc.frame_set(int(f0 + (f1 - f0) * float(a[3])))
for m in body.data.materials: m.use_backface_culling = cull
bpy.context.view_layer.update()
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.display.shading.show_backface_culling = cull
sc.render.resolution_x = 1400; sc.render.resolution_y = 1100
sc.world = bpy.data.worlds.new("w"); sc.world.color = (1, 0, 0) if cull else (0.55, 0.6, 0.65)
sc.display.shading.background_type = "WORLD"
dg = bpy.context.evaluated_depsgraph_get(); ev = body.evaluated_get(dg)
pts = [ev.matrix_world @ v.co for v in ev.to_mesh().vertices]
lo = Vector(tuple(min(p[i] for p in pts) for i in range(3))); hi = Vector(tuple(max(p[i] for p in pts) for i in range(3)))
c = (lo + hi) / 2; print("BBOX", lo, hi)
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co); sc.camera = co
# y+ is the rump here (horn at y-); views of the back: top, rear-high, both rear three-quarters, both side-highs
views = {"top": (0, 0.001, 1), "rear_high": (0, 1, 1.1), "rq_left": (-1, 1, 1.2), "rq_right": (1, 1, 1.2),
         "side_left_high": (-1, -0.1, 0.8), "side_right_high": (1, -0.1, 0.8), "front_high": (0, -1, 1.0)}
for name, d in views.items():
    d = Vector(d).normalized(); co.location = c + d * 20
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.ortho_scale = max(hi - lo) * 1.1
    sc.render.filepath = f"{a[1]}_{name}.png"; bpy.ops.render.render(write_still=True)
