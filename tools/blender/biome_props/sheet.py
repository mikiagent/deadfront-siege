"""Contact sheet of the biome GLBs: neutral light, a 1.8 m scale figure beside every asset.

Headless:  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P sheet.py -- <out.png> [names...]
Renders one tile per asset (each imported next to the figure, front-left 3/4 view, sun + soft fill),
composites the tiles into a labelled grid with Blender's own image API (no PIL dependency), and
writes <out.png>. The figure is a flat light-grey human silhouette: a placeholder for scale only.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
GLB_DIR = os.path.join(REPO, "game", "assets", "nature", "biome")

TILE_W, TILE_H = 480, 400
COLS = 5
FIGURE_H = 1.8


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)


def figure_material():
    mat = bpy.data.materials.new("scale_figure")
    mat.use_nodes = True
    b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (0.62, 0.64, 0.66, 1)
    b.inputs["Roughness"].default_value = 0.6
    return mat


def add_figure(x, y):
    """A 1.8 m human silhouette (capsules), ~0.55 m wide, feet at z = 0, facing the camera."""
    mat = figure_material()

    def caps(c, r, h, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=r, depth=h, location=c, rotation=rot)
        ob = bpy.context.object
        ob.data.materials.append(mat)

    def ball(c, r):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=r, location=c)
        bpy.context.object.data.materials.append(mat)

    for dx in (-0.075, 0.075):  # legs
        caps((x + dx, y, 0.42), 0.07, 0.84)
        ball((x + dx, y, 0.035), 0.075)
    caps((x, y, 1.12), 0.15, 0.60)  # torso
    ball((x, y, 1.15), 0.155)
    for dx in (-0.22, 0.22):  # arms
        caps((x + dx, y, 1.05), 0.045, 0.62)
        ball((x + dx, y, 0.75), 0.05)
    caps((x, y, 1.47), 0.05, 0.12)  # neck
    ball((x, y, 1.62), 0.105)  # head


def add_label(text, x, y, z, size=0.22):
    """A small white text label laid flat on the ground in front of the asset."""
    cur = bpy.data.curves.new(text, "FONT")
    cur.body = text
    cur.align_x = "CENTER"
    cur.align_y = "CENTER"
    cur.size = size
    ob = bpy.data.objects.new("label_" + text, cur)
    ob.location = (x, y, z)
    mat = bpy.data.materials.new("label_" + text)
    mat.use_nodes = True
    b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (0.05, 0.05, 0.06, 1)
    b.inputs["Roughness"].default_value = 0.9
    cur.materials.append(mat)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.update()
    return ob


def setup_world():
    w = bpy.context.scene.world or bpy.data.worlds.new("w")
    bpy.context.scene.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.46, 0.50, 0.55, 1)  # neutral sky
    bg.inputs["Strength"].default_value = 0.45
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 2.2
    sun.angle = math.radians(4)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(52), 0, math.radians(35))
    bpy.context.scene.collection.objects.link(so)


def ground(size):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    g = bpy.context.object
    mat = bpy.data.materials.new("ground")
    mat.use_nodes = True
    b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (0.26, 0.25, 0.23, 1)
    b.inputs["Roughness"].default_value = 0.9
    g.data.materials.append(mat)
    return g


def render_tile(name, path):
    clear()
    scn = bpy.context.scene
    setup_world()
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(GLB_DIR, name + ".glb"))
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in new:
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
            hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
    span = hi - lo
    radius = max(span.x, span.y) * 0.5
    # figure to the right of the asset, touching its right edge
    fx = hi.x + 0.55
    add_figure(fx, 0.0)
    hi.x = fx + 0.30
    # label lies just in front of the asset, at the foot of the frame
    label_ob = add_label(name.replace("_", " "), (lo.x + hi.x) * 0.5 - 0.25, lo.y - 0.75, 0.01,
                         size=max(0.34, min(1.3, (hi.x - lo.x) * 0.13)))
    # the label lies flat in front of the asset; include it in the frame so it is never cut off
    for c in label_ob.bound_box:
        p = label_ob.matrix_world @ Vector(c)
        lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
        hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
    ground(220)
    # frame: fit the asset plus figure and the full figure height
    mid = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, 0))
    width = (hi.x - lo.x) + 0.6
    depth = (hi.y - lo.y) + 0.6
    height = max(hi.z, FIGURE_H) + 1.2  # room under the feet for the label
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "ORTHO"
    aspect = TILE_W / TILE_H
    # a 3/4 front-left view keeps the silhouette readable and the colours lit
    toward = Vector((-0.72, -0.86, 0.42)).normalized()  # from the object towards the camera
    rot = (-toward).to_track_quat("-Z", "Y")
    scn.view_settings.view_transform = "Standard"  # show the authored vertex colours, not filmic
    w_ext = abs(math.cos(math.radians(35))) * width + abs(math.sin(math.radians(35))) * depth
    # a little head/foot room so the label under the asset is never clipped by the tile edge
    cam_d.ortho_scale = max(w_ext * 1.25, height * aspect * 1.22)
    cam = bpy.data.objects.new("cam", cam_d)
    bpy.context.scene.collection.objects.link(cam)
    cam.rotation_euler = rot.to_euler()
    # look at the centre of interest: horizontal middle, 38 % of the frame height
    target = Vector((mid.x, mid.y, max(hi.z, FIGURE_H) * 0.44))
    cam.location = target + toward * 40
    scn.camera = cam
    scn.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in
                                                              scn.render.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
    scn.render.resolution_x = TILE_W
    scn.render.resolution_y = TILE_H
    scn.render.film_transparent = False
    scn.render.image_settings.file_format = "PNG"
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("[biomeprops] tile %s lo=%s hi=%s cam=%s scale=%.2f" % (name, tuple(round(v,2) for v in lo), tuple(round(v,2) for v in hi), tuple(round(v,2) for v in cam.location), cam_d.ortho_scale))
    return hi.z


def main(out, names):
    if not names:
        names = sorted(f[:-4] for f in os.listdir(GLB_DIR) if f.endswith(".glb"))
    tmp = os.path.join(os.path.dirname(out), "_tiles")
    os.makedirs(tmp, exist_ok=True)
    tiles = []
    for n in names:
        p = os.path.join(tmp, n + ".png")
        render_tile(n, p)
        img = bpy.data.images.load(p)
        tiles.append((n, img))
    cols = min(COLS, len(tiles))
    rows = (len(tiles) + cols - 1) // cols
    sheet = bpy.data.images.new("sheet", TILE_W * cols, TILE_H * rows, alpha=False)
    buf = [0.40, 0.40, 0.41, 1.0] * (TILE_W * cols * TILE_H * rows)  # ground grey fills unused cells
    for i, (n, img) in enumerate(tiles):
        px = list(img.pixels[:])
        cx, cy = i % cols, i // cols
        ox = cx * TILE_W
        oy = (rows - 1 - cy) * TILE_H
        for y in range(TILE_H):
            src = y * TILE_W * 4
            dst = ((oy + y) * TILE_W * cols + ox) * 4
            buf[dst:dst + TILE_W * 4] = px[src:src + TILE_W * 4]
    sheet.pixels[:] = buf
    sheet.filepath_raw = out
    sheet.file_format = "PNG"
    sheet.save()
    print("[biomeprops] sheet %s (%d assets, %dx%d)" % (out, len(tiles), TILE_W * cols, TILE_H * rows))


_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if not _args:
    raise SystemExit("usage: sheet.py -- <out.png> [names...]")
main(_args[0], _args[1:])
