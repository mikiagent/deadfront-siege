"""Render a contact sheet of built GLBs from the game's iso angle (headless).

Blender -b --factory-startup -P tools/blender/structures/preview.py -- <out.png> [names...]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GLB_DIR = os.path.abspath(os.path.join(HERE, "..", "..", "..", "game", "assets", "props", "blender"))

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0]
names = args[1:] or sorted(f[:-4] for f in os.listdir(GLB_DIR) if f.endswith(".glb"))

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)

cols = max(1, math.ceil(math.sqrt(len(names) * 1.6)))
cell = 4.2
lo = Vector((1e9, 1e9, 0))
hi = Vector((-1e9, -1e9, 0))
for i, n in enumerate(names):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(GLB_DIR, n + ".glb"))
    new = [o for o in bpy.data.objects if o not in before]
    off = Vector(((i % cols) * cell, -(i // cols) * cell, 0))
    for o in new:
        if o.parent is None:
            o.location += off
    lo = Vector((min(lo.x, off.x), min(lo.y, off.y), 0))
    hi = Vector((max(hi.x, off.x), max(hi.y, off.y), 0))

bpy.ops.mesh.primitive_plane_add(size=1, location=((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, -0.01))
g = bpy.context.object
g.scale = (hi.x - lo.x + cell * 2, hi.y - lo.y + cell * 2, 1)
gm = bpy.data.materials.new("ground")
gm.use_nodes = True
next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.16, 0.2, 0.1, 1)
g.data.materials.append(gm)

cell_objs = [o for o in bpy.data.objects if o.type == "MESH" and o.name != g.name]
d = Vector((1, -1, 1.15)).normalized()  # game iso: from the front-right, above
rot = (-d).to_track_quat("-Z", "Y")
inv = rot.to_matrix().inverted()
pts = [inv @ (o.matrix_world @ Vector(c)) for o in cell_objs for c in o.bound_box]
mnx, mxx = min(p.x for p in pts), max(p.x for p in pts)
mny, mxy = min(p.y for p in pts), max(p.y for p in pts)
mid = rot.to_matrix() @ Vector(((mnx + mxx) / 2, (mny + mxy) / 2, 0))
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
aspect = (mxy - mny) / max(1e-3, mxx - mnx)
cam_d.ortho_scale = max(mxx - mnx, (mxy - mny) / min(1.0, max(0.45, aspect))) * 1.08
cam = bpy.data.objects.new("cam", cam_d)
bpy.context.scene.collection.objects.link(cam)
cam.location = mid + d * 60
cam.rotation_euler = rot.to_euler()
bpy.context.scene.camera = cam

sun_d = bpy.data.lights.new("sun", "SUN")
sun_d.energy = 3.5
sun = bpy.data.objects.new("sun", sun_d)
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
bpy.context.scene.collection.objects.link(sun)
w = bpy.context.scene.world or bpy.data.worlds.new("w")
bpy.context.scene.world = w
w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.5, 0.55, 0.6, 1)
bg.inputs["Strength"].default_value = 0.8

sc = bpy.context.scene
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
    try:
        sc.render.engine = eng
        break
    except TypeError:
        continue
sc.render.resolution_x = 1600
sc.render.resolution_y = int(1600 * min(1.0, max(0.45, aspect)))
sc.render.filepath = out
sc.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)
print("[preview] wrote", out, sc.render.engine)
