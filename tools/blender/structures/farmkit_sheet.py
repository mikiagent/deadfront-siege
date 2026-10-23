"""Render the farm kit contact sheet from the game's camera angle, with a 1.8 m figure for scale.

Headless: /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/structures/farmkit_sheet.py -- <out.png>

The game camera (IsoCamera) is perspective, pitched 38.7 deg down and yawed 45 deg; this script
renders the same view with a long lens (a narrow vertical field of view) so the sheet shows what the
player sees. The survivor GLB stands next to the models as the 1.8 m scale reference.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
GLB_DIR = os.path.join(ROOT, "game", "assets", "props", "blender")
SURVIVOR = os.path.join(ROOT, "game", "assets", "characters", "survivor", "survivor.glb")

MODELS = [
    "field_tilled", "field_crop_0", "field_crop_1", "field_crop_2", "field_crop_3",
    "path_dirt", "path_dirt_corner", "path_stone", "path_stone_corner",
    "fence_post_rail", "fence_post_rail_gate", "trellis", "scarecrow", "compost_heap", "water_trough",
]
PITCH_DEG = 38.7
YAW_DEG = 45.0

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else "/tmp/farmkit_sheet.png"

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


def _import(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    _remap_atlas()
    return [o for o in bpy.data.objects if o not in before]


def _flat(obj, colour, rough=0.9):
    m = bpy.data.materials.new(obj.name + "_flat")
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*colour, 1)
    bsdf.inputs["Roughness"].default_value = rough
    obj.data.materials.clear()
    obj.data.materials.append(m)


# --- lay the models out on a grid, in one row of 5 x 3 cells
CELL = 5.0
cols = 5
rows = math.ceil(len(MODELS) / cols)
positions = []
for i, name in enumerate(MODELS):
    x = (i % cols) * CELL
    y = -(i // cols) * CELL
    positions.append((name, Vector((x, y, 0))))

for name, off in positions:
    objs = _import(os.path.join(GLB_DIR, name + ".glb"))
    for o in objs:
        if o.parent is None:
            o.location += off

# --- the 1.8 m survivor stands next to three models as the scale reference
FIGURE_CELLS = {"field_crop_3": (-1.6, 1.5), "scarecrow": (-1.4, 1.2), "water_trough": (-1.3, 1.3)}
figure_objs = []
for name, (dx, dy) in FIGURE_CELLS.items():
    off = dict((n, p) for n, p in positions)[name]
    objs = _import(SURVIVOR)
    root = [o for o in objs if o.parent is None]
    for o in objs:
        if o.parent is None:
            o.location += off + Vector((dx, dy, 0))
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in root:
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            for k in range(3):
                lo[k] = min(lo[k], p[k])
                hi[k] = max(hi[k], p[k])
    h = hi[2] - lo[2]
    s_scale = 1.8 / h if h > 0.1 else 1.0
    for o in objs:
        o.scale = (s_scale, s_scale, s_scale)
    figure_objs += objs
    print("[sheet] survivor beside %s scaled to 1.80 m (was %.2f m)" % (name, h))

# --- ground
minx = min(p.x for _, p in positions) - CELL / 2
maxx = max(p.x for _, p in positions) + CELL / 2
miny = min(p.y for _, p in positions) - CELL / 2
maxy = max(p.y for _, p in positions) + CELL / 2
bpy.ops.mesh.primitive_plane_add(size=1, location=((minx + maxx) / 2, (miny + maxy) / 2, -0.005))
g = bpy.context.object
g.scale = (maxx - minx, maxy - miny, 1)
_flat(g, (0.19, 0.26, 0.11))

# --- camera: the game's iso view (pitch 38.7 down, yaw 45), perspective with the game's long lens
d = Vector((math.sin(math.radians(YAW_DEG)), -math.cos(math.radians(YAW_DEG)),
            math.sin(math.radians(PITCH_DEG)))).normalized()
rot = (-d).to_track_quat("-Z", "Y")
R = rot.to_matrix()
right = R @ Vector((1, 0, 0))
up = R @ Vector((0, 1, 0))
mid = Vector(((minx + maxx) / 2, (miny + maxy) / 2, 0.6))

sc = bpy.context.scene
sc.render.resolution_x = 1900
sc.render.resolution_y = 1400
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "PERSP"
cam_d.sensor_fit = "VERTICAL"
cam_d.angle_y = math.radians(4.3)  # the game's 4.3 deg vertical field of view
aspect = sc.render.resolution_x / sc.render.resolution_y
T = math.tan(math.radians(4.3) / 2)

# distance so that every point of every model fits in the frame
pts = []
for o in bpy.data.objects:
    if o.type != "MESH" or o is g:
        continue
    for c in o.bound_box:
        pts.append(o.matrix_world @ Vector(c))
dist = 0.0
for p in pts:
    q = (p - mid).dot(d)
    need = max(abs((p - mid).dot(up)) / T, abs((p - mid).dot(right)) / (aspect * T))
    dist = max(dist, need + q)
dist *= 1.06
cam = bpy.data.objects.new("cam", cam_d)
bpy.context.scene.collection.objects.link(cam)
cam.location = mid + d * dist
cam.rotation_euler = rot.to_euler()
bpy.context.scene.camera = cam
print("[sheet] camera distance %.1f m for %d points" % (dist, len(pts)))

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

for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
    try:
        sc.render.engine = eng
        break
    except TypeError:
        continue
sc.render.filepath = out
sc.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)
print("[sheet] wrote", out, sc.render.engine)
