"""Workbench views of a woolly rhino rig .blend (optionally posed at a clip frame): side, front, three-quarter,
with the bones drawn in front as sticks. Used for the landmark review and quick pose checks.
  Blender -b -P tools/gait/woolly_rhino/view.py -- <rig.blend> <out_prefix> [--action NAME --frame F] [--bones]
"""
import bpy, sys, math
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=a[0]); pre = a[1]
sc = bpy.context.scene
arm = bpy.data.objects["Armature"]
if "--action" in a:
    act = bpy.data.actions[a[a.index("--action") + 1]]
    arm.animation_data_create(); arm.animation_data.action = act
    if len(act.slots): arm.animation_data.action_slot = act.slots[0]
    sc.frame_set(int(a[a.index("--frame") + 1]))
bpy.context.view_layer.update()
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x = 1200; sc.render.resolution_y = 900
sc.world = sc.world or bpy.data.worlds.new("w"); sc.world.color = (0.55, 0.6, 0.65)
if "--bones" in a:
    mat = bpy.data.materials.new("stick"); mat.diffuse_color = (1, 0.1, 0.1, 1)
    for pb in arm.pose.bones:
        h = arm.matrix_world @ pb.head; t = arm.matrix_world @ pb.tail
        d = t - h
        bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=max(d.length, 1e-3), vertices=6)
        o = bpy.context.active_object
        o.matrix_world = Matrix.Translation((h + t) / 2) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        o.data.materials.append(mat); o.show_in_front = True
# ground plane + survivor-height post (1.78 m)
bpy.ops.mesh.primitive_plane_add(size=40); g = bpy.context.active_object
gm = bpy.data.materials.new("g"); gm.diffuse_color = (0.35, 0.33, 0.3, 1); g.data.materials.append(gm)
bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=1.78, location=(1.8, -4.0, 0.89))
pm = bpy.data.materials.new("p"); pm.diffuse_color = (0.2, 0.4, 0.9, 1); bpy.context.active_object.data.materials.append(pm)
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co); sc.camera = co
cz = 1.6; size = 7.5
for name, loc, rot in [("side", (-20, 0.3, cz), (math.pi / 2, 0, -math.pi / 2)), ("front", (0, -20, cz), (math.pi / 2, 0, 0)),
                       ("tq", (-14, -12, cz + 9), None)]:
    co.location = loc
    if rot: co.rotation_euler = rot
    else: co.rotation_euler = (Vector((0, 0.3, 1.8)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.ortho_scale = size
    sc.render.filepath = f"{pre}_{name}.png"; bpy.ops.render.render(write_still=True)
