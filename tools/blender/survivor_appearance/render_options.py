# Inspection renders of appearance options in headless Blender, neutral studio light, bind pose.
#   Blender -b --factory-startup -P render_options.py -- <out_dir> <sheet.png> <row>=<a.glb>,<b.glb> [<row>=...]
# Each row is one look (the pieces are loaded together with the unchanged body chest/arms/legs for context)
# and gets front, side, 3/4, back (the nape hairline) and portrait views; the sheet stacks the rows (first row = the unchanged base).
# Also writes <out_dir>/<row>_<view>.png and prints, per row, how many pixels differ from the first row.
import bpy, sys, os
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out, sheet = argv[0], argv[1]
rows = [(a.split("=", 1)[0], a.split("=", 1)[1].split(",")) for a in argv[2:]]
BODY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../game/assets/characters/survivor/body")
CONTEXT = [os.path.normpath(f"{BODY}/body_{r}.glb") for r in ("chest", "arms", "legs")]
os.makedirs(out, exist_ok=True)
RES = 512
VIEWS = (  # name, direction from target, ortho scale (0 = perspective portrait)
    ("front", (0, -1, 0), 0.36), ("side", (1, 0, 0), 0.36), ("34", (0.75, -1, 0.12), 0.36),
    ("back", (-0.35, 1, 0.15), 0.36), ("portrait", (0.45, -1, 0.10), 0.0),
)


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light, sh.color_type, sh.studio_light = "STUDIO", "TEXTURE", "Default"
    sh.background_type, sh.background_color = "VIEWPORT", (0.42, 0.42, 0.42)
    sh.show_specular_highlight = False
    sc.display_settings.display_device = "sRGB"
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x = sc.render.resolution_y = RES
    sc.render.image_settings.file_format = "PNG"
    cd = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam, cd


def load(paths):
    for p in paths:
        bpy.ops.import_scene.gltf(filepath=p)
    for o in list(bpy.data.objects):
        if o.type == "MESH" and not o.modifiers and o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o)  # importer's bone-shape helper


def shoot(sc, cam, cd, path, d, ortho):
    target = Vector((0, -0.01, 1.63))
    d = Vector(d).normalized()
    if ortho:
        cd.type, cd.ortho_scale = "ORTHO", ortho
        cam.location = target + d * 3
    else:  # head-and-shoulders portrait, 50 mm, a little above eye level
        cd.type, cd.lens = "PERSP", 50
        target = Vector((0, -0.01, 1.58))
        cam.location = target + d * 1.15
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def pixels(path):
    im = bpy.data.images.load(path)
    a = np.array(im.pixels[:], np.float32).reshape(im.size[1], im.size[0], 4)
    bpy.data.images.remove(im)
    return a


grid = []
for name, pieces in rows:
    sc, cam, cd = clear()
    load(CONTEXT + pieces)
    row = []
    for v, d, o in VIEWS:
        p = f"{out}/{name}_{v}.png"
        shoot(sc, cam, cd, p, d, o)
        row.append(p)
    grid.append(row)

base = [pixels(p) for p in grid[0]]
for (name, _), row in zip(rows, grid):
    diff = sum(int((np.abs(pixels(p)[..., :3] - b[..., :3]).max(2) > 1.5 / 255).sum()) for p, b in zip(row, base))
    print(f"DIFF {name} vs {rows[0][0]}: {diff} px over {len(VIEWS)} views")
img = np.ones((RES * len(grid), RES * len(VIEWS), 4), np.float32)
for r, row in enumerate(grid):
    for c, p in enumerate(row):
        img[(len(grid) - 1 - r) * RES:(len(grid) - r) * RES, c * RES:(c + 1) * RES] = pixels(p)
im = bpy.data.images.new("sheet", RES * len(VIEWS), RES * len(grid))
im.pixels.foreach_set(img.ravel())
im.filepath_raw, im.file_format = sheet, "PNG"
im.save()
print("SHEET", sheet)
