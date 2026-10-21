# Inspection renders of appearance options in headless Blender, neutral studio light, bind pose.
#   Blender -b --factory-startup -P render_options.py -- <out_dir> <sheet.png> <row>=<a.glb>,<b.glb> [<row>=...]
#   [views=front,side,34,back,portrait,iso] picks the views (default: the first five).
#   [engine=eevee] renders with EEVEE under an even grey sky and a soft key (Workbench, the default, shows neither
#   alpha-blended decals nor material colour factors).
# Each row is one look (the pieces are loaded together with the unchanged body chest/arms/legs for context)
# and gets front, side, 3/4, back (the nape hairline) and portrait views; the sheet stacks the rows (first row = the unchanged base).
# Also writes <out_dir>/<row>_<view>.png and prints, per row, how many pixels differ from the first row.
import bpy, sys, os
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out, sheet = argv[0], argv[1]
rows = [(a.split("=", 1)[0], a.split("=", 1)[1].split(",")) for a in argv[2:] if not a.startswith(("views=", "engine="))]
EEVEE = "engine=eevee" in argv
pick = next((a[6:].split(",") for a in argv[2:] if a.startswith("views=")), None)  # views=front,iso,... (default: five)
BODY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../game/assets/characters/survivor/body")
CONTEXT = [os.path.normpath(f"{BODY}/body_{r}.glb") for r in ("chest", "arms", "legs")]
os.makedirs(out, exist_ok=True)
RES = 512
VIEWS = (  # name, direction from target, ortho scale (0 = perspective portrait)
    ("front", (0, -1, 0), 0.36), ("side", (1, 0, 0), 0.36), ("34", (0.75, -1, 0.12), 0.36),
    ("back", (-0.35, 1, 0.15), 0.36), ("portrait", (0.45, -1, 0.10), 0.0),
)
EXTRA = {"iso": ((0.7, -0.7, 1.0), 0.36)}  # the play camera's angle, looking down on the head
if pick:
    VIEWS = tuple(next(((n, d, o) for n, d, o in VIEWS if n == v), None) or (v, *EXTRA[v]) for v in pick)


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
    if EEVEE:
        sc.render.engine = "BLENDER_EEVEE"
        sc.world = bpy.data.worlds.new("w")
        sc.world.use_nodes = True
        bg = next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND")
        bg.inputs[0].default_value, bg.inputs[1].default_value = (0.42, 0.42, 0.42, 1), 1.0
        sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
        sun.data.energy, sun.data.angle = 1.6, 0.5
        sun.rotation_euler = (0.9, 0.0, -0.5)
        sc.collection.objects.link(sun)
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
    if EEVEE:  # draw like the game: PlayerView.web_safe_mesh keeps albedo (and alpha), roughness 0.82, no normal or ORM map
        for m in bpy.data.materials:
            bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m.node_tree else None
            if bsdf is None:
                continue
            for name, value in (("Normal", None), ("Roughness", 0.82), ("Metallic", 0.0)):
                for l in list(bsdf.inputs[name].links):
                    m.node_tree.links.remove(l)
                if value is not None:
                    bsdf.inputs[name].default_value = value


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
