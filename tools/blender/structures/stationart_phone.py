"""Phone-scale contact sheet of the six construction sites (dsc-stationart).

The game camera on a phone is a perspective camera 14 m of view height away
(IsoCamera.DEFAULT_SIZE); at 844x390 that is about 28 px/m, so anything thinner than
about 3 cm is sub-pixel. This renders the sites at that scale from the game's iso angle so the
review can see what the player actually sees.

Headless: /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P
tools/blender/structures/stationart_phone.py -- <out.png>
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
GLB_DIR = os.path.join(REPO, "game", "assets", "props", "blender")

NAMES = ["site_small_0", "site_small_1", "site_small_2",
         "site_large_0", "site_large_1", "site_large_2"]
PITCH_DEG = 38.7
YAW_DEG = 45.0
# the phone's view: 844x390 px over about 30 m of width
RES_X, RES_Y = int(os.environ.get("PHONE_RES_X", "844")), int(os.environ.get("PHONE_RES_Y", "390"))
VIEW_W = float(os.environ.get("PHONE_VIEW_W", "30.0"))

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else os.path.join(REPO, "docs", "orchestration", "reports", "dsc-stationart-phone.png")
names = args[1:] or NAMES

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)

ATLAS = os.path.join(GLB_DIR, "structures_atlas.png")
atlas = bpy.data.images.load(ATLAS) if os.path.exists(ATLAS) else None


def _remap_atlas():
    if atlas is None:
        return
    for mat in bpy.data.materials:
        if not mat.name.startswith("structures_atlas") or mat.get("preview_atlas"):
            continue
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = atlas
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        mat["preview_atlas"] = True


# the camera basis: the grid is laid out in screen space so the sheet reads as rows
cam_dir = Vector((math.sin(math.radians(YAW_DEG)), -math.cos(math.radians(YAW_DEG)),
                  math.tan(math.radians(PITCH_DEG)))).normalized()
cam_rot = (-cam_dir).to_track_quat("-Z", "Y")
cam_right = cam_rot.to_matrix() @ Vector((1, 0, 0))
cam_right.z = 0.0
cam_right.normalize()
cam_up_g = -Vector((cam_dir.x, cam_dir.y, 0.0)).normalized()

cols = 3
rows = math.ceil(len(names) / cols)
CELL = float(os.environ.get("PHONE_CELL", "9.0"))
items = []
for i, n in enumerate(names):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(GLB_DIR, n + ".glb"))
    _remap_atlas()
    new = [o for o in bpy.data.objects if o not in before]
    col, row = i % cols, i // cols
    off = cam_right * ((col - (cols - 1) / 2.0) * CELL) + cam_up_g * ((rows - 1) / 2.0 - row) * CELL
    for o in new:
        if o.parent is None:
            o.location += off
    items.append((n, off))

gm = bpy.data.materials.new("ground")
gm.use_nodes = True
next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.16, 0.2, 0.1, 1)
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, -0.01))
g = bpy.context.object
g.scale = (400, 400, 1)
g.data.materials.append(gm)

# the ortho camera: the view width the phone shows, so 1 m is VIEW_W/RES_X pixels
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = VIEW_W
cam = bpy.data.objects.new("cam", cam_d)
bpy.context.scene.collection.objects.link(cam)
mid = Vector((0, 0, 0.8))
cam.location = mid + cam_dir * 60
cam.rotation_euler = cam_rot.to_euler()
bpy.context.scene.camera = cam

sun_d = bpy.data.lights.new("sun", "SUN")
sun_d.energy = 3.6
sun_d.color = (1.0, 0.93, 0.82)
sun_d.angle = math.radians(3.0)
sun = bpy.data.objects.new("sun", sun_d)
sun.rotation_euler = (math.radians(50), 0, math.radians(-60))
bpy.context.scene.collection.objects.link(sun)
w = bpy.context.scene.world or bpy.data.worlds.new("w")
bpy.context.scene.world = w
w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.52, 0.58, 0.68, 1)
bg.inputs["Strength"].default_value = 0.5

sc = bpy.context.scene
for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
    try:
        sc.render.engine = eng
        break
    except TypeError:
        continue
sc.render.resolution_x = RES_X
sc.render.resolution_y = RES_Y
sc.render.filepath = out
sc.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)
print("[phone] wrote", out, sc.render.engine, "%d px/m" % round(RES_X / VIEW_W, 2))
