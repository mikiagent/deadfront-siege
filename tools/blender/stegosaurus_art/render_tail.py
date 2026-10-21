# STEGO-ART review renders: a close rear-3/4 of the thagomizer (the four-spike gate) plus whole-animal views.
#   Blender -b --factory-startup -P render_tail.py -- <glb> <out_prefix>
# Writes <out_prefix>_tail_rear34.png, _tail_side.png, _tail_rear.png, _tail_low.png, _side.png, _rear34.png.
import sys, math
import bpy
from mathutils import Vector

glb, out = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
sc = bpy.context.scene
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        sc.render.engine = eng; break
    except TypeError:
        pass
sc.render.resolution_x, sc.render.resolution_y = 1200, 900
world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.62, 0.64, 0.66, 1); bg.inputs[1].default_value = 0.9
sun = bpy.data.lights.new("sun", "SUN"); sun.energy = 3.0
so = bpy.data.objects.new("sun", sun); sc.collection.objects.link(so); so.rotation_euler = (math.radians(45), 0, math.radians(35))
cam = bpy.data.cameras.new("cam"); co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co); sc.camera = co
g2b = lambda x, y, z: Vector((x, -z, y))   # glTF (Y up, -Z forward) -> Blender (Z up)

def shot(name, target, eye, lens):
    co.location = eye; co.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler(); cam.lens = lens
    sc.render.filepath = f"{out}_{name}.png"; bpy.ops.render.render(write_still=True)

T = g2b(0, 3.9, 7.0)                       # thagomizer (tail end at z 6.5-7.7 m, 3.5-4.6 m up)
shot("tail_rear34", T, T + g2b(2.6, 1.6, 2.6), 50)
shot("tail_side", T, T + g2b(4.2, 0.3, 0.0), 50)
shot("tail_rear", T, T + g2b(0.0, 0.4, 4.0), 50)
shot("tail_low", T, T + g2b(2.4, -1.8, 2.4), 50)
shot("side", g2b(0, 3.2, 1.8), g2b(17, 3.4, 1.8), 50)
shot("rear34", g2b(0, 3.0, 2.5), g2b(10, 6.5, 13), 50)
