"""Contact sheet for the station art (dsc-stationart): every new station model, the old workbench
and a 1.8 m figure for scale, seen from the game's iso camera angle and lit like the game.

Headless: /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P
tools/blender/structures/stationart_sheet.py -- <out.png>
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
GLB_DIR = os.path.join(REPO, "game", "assets", "props", "blender")
MANIFEST = os.path.join(REPO, "game", "data", "props_manifest.json")

# The 15 new models, the old workbench for comparison, then the scale figure.
NAMES = [
    "makeshift_workbench", "basic_workbench", "journeyman_workbench", "expert_workbench",
    "kiln", "loom", "large_loom", "oven", "large_drying_rack",
    "site_small_0", "site_small_1", "site_small_2",
    "site_large_0", "site_large_1", "site_large_2",
    "workbench",
]
# The game's iso camera: pitch 38.7 deg down, yaw 45 deg (IsoCamera.PITCH_DEG / YAW_DEG).
PITCH_DEG = 38.7
YAW_DEG = 45.0
CELL = 8.6

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = args[0] if args else os.path.join(REPO, "docs", "orchestration", "reports", "dsc-stationart-sheet.png")
names = args[1:] or NAMES

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)

ATLAS = os.path.join(GLB_DIR, "structures_atlas.png")
atlas = bpy.data.images.load(ATLAS) if os.path.exists(ATLAS) else None


def _remap_atlas():
    """The GLBs carry no embedded image; hook the shared atlas PNG onto every atlas material."""
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


def _figure_mesh():
    """A 1.8 m human stand-in on the shared atlas: the scale reference for the sheet."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    import importlib
    sys.path.insert(0, HERE)
    lib = importlib.import_module("lib")

    def part_tile(faces, tile):
        # reuse lib.Part's UV layout by making a throwaway Part and copying its uv rule
        tmp = lib.Part("fig")
        tmp.bm = bm
        tmp.uv = uv
        tmp.seed = 1
        tmp._uv_faces(faces, tile, 0.5)

    def cyl(r, h, loc, tile, rot=(0, 0, 0), seg=8):
        m = lib.Part._mat(loc, rot, (1, 1, 1))
        v = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                                  radius1=r, radius2=r * 0.92, depth=h, matrix=m)["verts"]
        bm.normal_update()
        part_tile([f for vv in v for f in vv.link_faces], tile)

    def box(size, loc, tile, rot=(0, 0, 0)):
        m = lib.Part._mat(loc, rot, size)
        v = bmesh.ops.create_cube(bm, size=1.0, matrix=m)["verts"]
        bm.normal_update()
        part_tile([f for vv in v for f in vv.link_faces], tile)

    # legs, hips, torso, arms, neck, head: 1.8 m tall in total
    for sx in (-1, 1):
        cyl(0.075, 0.86, (sx * 0.1, 0, 0.43), "leather_dark")
    box((0.34, 0.22, 0.2), (0, 0, 0.93), "hide")
    cyl(0.17, 0.5, (0, 0, 1.24), "hide")
    for sx in (-1, 1):
        cyl(0.055, 0.6, (sx * 0.22, 0, 1.22), "leather_dark", rot=(0, sx * 7, 0))
    cyl(0.05, 0.1, (0, 0, 1.53), "hide")
    v = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.115,
                                   matrix=Matrix.Translation((0, 0, 1.66)))["verts"]
    bm.normal_update()
    part_tile([f for vv in v for f in vv.link_faces], "hide")
    me = bpy.data.meshes.new("figure")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(lib.atlas_material())
    return me


fig_mesh = _figure_mesh()

with open(MANIFEST) as f:
    rows = json.load(f)["buildings"]
fp_by_glb = {}
for kind, row in rows.items():
    g = os.path.basename(str(row.get("glb", "")))[:-4]
    if g:
        fp_by_glb.setdefault(g, row.get("footprint", [1, 1]))

# The camera basis first: the grid is laid out in screen space, so the sheet is a neat
# rectangle instead of a diamond seen at 45 deg.
cam_dir = Vector((math.sin(math.radians(YAW_DEG)), -math.cos(math.radians(YAW_DEG)),
                  math.tan(math.radians(PITCH_DEG)))).normalized()
cam_rot = (-cam_dir).to_track_quat("-Z", "Y")
cam_right = cam_rot.to_matrix() @ Vector((1, 0, 0))
cam_right.z = 0.0
cam_right.normalize()
# the horizontal direction that points away from the camera (screen up, in the ground plane)
cam_up_g = Vector((cam_dir.x, cam_dir.y, 0.0))
cam_up_g = -cam_up_g.normalized()

cols = max(1, math.ceil(math.sqrt(len(names) * 1.4)))
items = []
for i, n in enumerate(names):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(GLB_DIR, n + ".glb"))
    _remap_atlas()
    new = [o for o in bpy.data.objects if o not in before]
    col, row = i % cols, i // cols
    off = cam_right * ((col - (cols - 1) / 2.0) * CELL) + cam_up_g * ((rows_n := (math.ceil(len(names) / cols) - 1) / 2.0 - row) * CELL)
    for o in new:
        if o.parent is None:
            o.location += off
    # the model's own extent, to place the figure clear of it
    pts = [o.matrix_world @ Vector(c) for o in new for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), 0))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), 0))
    items.append((n, off, new, lo, hi))

# ground and the game's dirt discs under the buildings
gm = bpy.data.materials.new("ground")
gm.use_nodes = True
next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.16, 0.2, 0.1, 1)
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, -0.01))
g = bpy.context.object
g.scale = (400, 400, 1)
g.data.materials.append(gm)

dm = bpy.data.materials.new("foundation_disc")
dm.use_nodes = True
next(n for n in dm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.2, 0.14, 0.08, 1)
for n, off, new, lo, hi in items:
    fp = fp_by_glb.get(n)
    if not fp:
        continue
    r = 0.5 * math.hypot(fp[0], fp[1]) + 1.0
    bpy.ops.mesh.primitive_circle_add(vertices=28, radius=r, fill_type="NGON",
                                      location=(off.x, off.y, 0.08))
    bpy.context.object.data.materials.append(dm)

# the 1.8 m figure beside every model, on the screen-left so it never hides the model
for n, off, new, lo, hi in items:
    half = 0.0
    for o in new:
        for c in o.bound_box:
            half = max(half, abs((o.matrix_world @ Vector(c) - off).dot(cam_right)))
    pos = off - cam_right * (half + 0.75)
    fig = bpy.data.objects.new("figure_" + n, fig_mesh)
    bpy.context.scene.collection.objects.link(fig)
    fig.location = pos
    # the model name, laid flat on the ground in front of the cell
    txt = bpy.data.curves.new("label_" + n, type="FONT")
    txt.body = n
    txt.size = 0.38
    txt.align_x = "CENTER"
    txt.extrude = 0.006
    lm = bpy.data.materials.new("label_mat")
    lm.use_nodes = True
    next(nd for nd in lm.node_tree.nodes if nd.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.9, 0.85, 0.7, 1)
    txt.materials.append(lm)
    lab = bpy.data.objects.new("label_" + n, txt)
    bpy.context.scene.collection.objects.link(lab)
    # clear of the foundation disc, so the text is not buried under it
    fp = fp_by_glb.get(n)
    disc_r = 0.5 * math.hypot(fp[0], fp[1]) + 1.0 if fp else 1.4
    lab.location = off - cam_up_g * (disc_r + 0.55) + Vector((0, 0, 0.02))
    lab.rotation_euler = (0, 0, math.atan2(cam_right.y, cam_right.x))

# the game's iso camera: yaw 45 deg, pitch 38.7 deg down
d = Vector((math.sin(math.radians(YAW_DEG)), -math.cos(math.radians(YAW_DEG)),
            math.tan(math.radians(PITCH_DEG)))).normalized()
rot = (-d).to_track_quat("-Z", "Y")
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cell_objs = [o for o in bpy.data.objects if o.type == "MESH" and o.name != g.name]
inv = rot.to_matrix().inverted()
pts = [inv @ (o.matrix_world @ Vector(c)) for o in cell_objs for c in o.bound_box]
mnx, mxx = min(p.x for p in pts), max(p.x for p in pts)
mny, mxy = min(p.y for p in pts), max(p.y for p in pts)
mid = rot.to_matrix() @ Vector(((mnx + mxx) / 2, (mny + mxy) / 2, 0))
cam_d.ortho_scale = max(mxx - mnx, (mxy - mny) / min(1.0, max(0.45, (mxy - mny) / max(1e-3, mxx - mnx)))) * 1.04
cam = bpy.data.objects.new("cam", cam_d)
bpy.context.scene.collection.objects.link(cam)
cam.location = mid + d * 80
cam.rotation_euler = rot.to_euler()
bpy.context.scene.camera = cam

# game light: the sun's elevation and yaw band (world_lighting.gd), sky ambient on top
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
# a warm fill from the sky side so the shadowed faces do not go flat black
bg.inputs["Strength"].default_value = 0.5

sc = bpy.context.scene
for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
    try:
        sc.render.engine = eng
        break
    except TypeError:
        continue
sc.render.resolution_x = 2000
sc.render.resolution_y = int(2000 * min(1.0, max(0.45, (mxy - mny) / max(1e-3, mxx - mnx))))
sc.render.filepath = out
sc.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)
print("[sheet] wrote", out, sc.render.engine)
