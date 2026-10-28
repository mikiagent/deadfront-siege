"""Contact sheet for the house kit: every model rendered headless from the game's camera angle
(perspective, pitch 38.7 deg down, yaw 45 deg) with a 1.8 m figure for scale, plus an assembled
house in each of the three material tiers to show that the parts snap together.

Headless:  Blender -b --factory-startup -P tools/blender/structures/housekit_sheet.py -- <out.png>
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GLB_DIR = os.path.abspath(os.path.join(HERE, "..", "..", "..", "game", "assets", "props", "blender"))
ATLAS = os.path.join(GLB_DIR, "structures_atlas.png")
OUT = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

MODELS = [
    "house_foundation", "house_floor", "house_wall", "house_wall_window",
    "house_wall_doorway", "house_door", "house_roof", "house_roof_corner",
    "house_roof_gable", "house_stairs", "house_wall_timber", "house_wall_window_timber",
    "house_roof_timber", "house_wall_stone", "house_wall_window_stone", "house_roof_stone",
]
# the three tiers, each a 4 x 2 m cabin: 4 wall modules per long side, 1 per short side, 2 roof
# slopes and 2 gables over a 2 x 2 m foundation and floor.
CABINS = [
    ("log", dict(foundation="house_foundation", floor="house_floor", wall="house_wall",
                 window="house_wall_window", doorway="house_wall_doorway", roof="house_roof",
                 gable="house_roof_gable")),
    ("timber", dict(foundation="house_foundation", floor="house_floor", wall="house_wall_timber",
                    window="house_wall_window_timber", doorway="house_wall_timber", roof="house_roof_timber",
                    gable="house_roof_gable")),
    ("stone", dict(foundation="house_foundation", floor="house_floor", wall="house_wall_stone",
                   window="house_wall_window_stone", doorway="house_wall_stone", roof="house_roof_stone",
                   gable="house_roof_gable")),
]

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob)

atlas = bpy.data.images.load(ATLAS) if os.path.exists(ATLAS) else None
_cache = {}


def _remap_atlas(mat):
    """The GLBs carry no embedded image; hook the shared atlas back on for the render."""
    if atlas is None or mat is None or not mat.name.startswith("structures_atlas") or mat.get("preview_atlas"):
        return
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = atlas
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    mat["preview_atlas"] = True


def load(name):
    """Import a GLB once and return a fresh copy of its objects (parented under a new root)."""
    if name not in _cache:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(GLB_DIR, name + ".glb"))
        objs = [o for o in bpy.data.objects if o not in before]
        for o in objs:
            for m in o.data.materials if o.type == "MESH" else []:
                _remap_atlas(m)
        _cache[name] = objs
    root = bpy.data.objects.new("inst_" + name, None)
    bpy.context.scene.collection.objects.link(root)
    for src in _cache[name]:
        cp = src.copy()
        cp.data = src.data
        cp.name = src.name + "_" + str(len(bpy.data.objects))
        bpy.context.scene.collection.objects.link(cp)
        cp.parent = root
        cp.matrix_parent_inverse = src.matrix_world.inverted()
    return root


def put(name, loc, rot_z=0.0, rot_x=0.0):
    root = load(name)
    root.location = loc
    root.rotation_euler = (rot_x, 0.0, rot_z)
    return root


def figure(loc, height=1.8):
    """A 1.8 m survivor silhouette for scale (untextured, so it never reads as a prop)."""
    mat = bpy.data.materials.get("figure")
    if mat is None:
        mat = bpy.data.materials.new("figure")
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (0.22, 0.2, 0.18, 1)
        bsdf.inputs["Roughness"].default_value = 0.9
    h = height
    bpy.ops.mesh.primitive_cylinder_add(radius=h * 0.11, depth=h * 0.42,
                                         location=(loc[0], loc[1], loc[2] + h * 0.21))
    bpy.context.object.data.materials.append(mat)
    bpy.ops.mesh.primitive_cylinder_add(radius=h * 0.16, depth=h * 0.42,
                                         location=(loc[0], loc[1], loc[2] + h * 0.6))
    bpy.context.object.data.materials.append(mat)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=h * 0.1, segments=10, ring_count=6,
                                          location=(loc[0], loc[1], loc[2] + h * 0.92))
    bpy.context.object.data.materials.append(mat)


def ground():
    mat = bpy.data.materials.new("ground")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.19, 0.17, 0.12, 1)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.005))
    bpy.context.object.data.materials.append(mat)


def cabin(kit, x0, label):
    """A 4 x 2 m cabin: two 2 x 2 m foundation and floor modules, 6 wall modules, two roof
    slopes over the ridge and a gable at each end."""
    for sx in (-1, 1):
        put(kit["foundation"], (x0 + sx, 0.0, 0.0))
        put(kit["floor"], (x0 + sx, 0.0, 0.0))
    # long walls at y = +-0.88 (two 2 m modules each); the doorway faces the camera (-Y)
    put(kit["wall"], (x0 - 1.0, -0.88, 0.0))
    put(kit["doorway"], (x0 + 1.0, -0.88, 0.0))
    put(kit["wall"], (x0 - 1.0, 0.88, 0.0))
    put(kit["window"], (x0 + 1.0, 0.88, 0.0))
    # short walls at x = +-1.88, one 2 m module each, turned to run along Y
    put(kit["window"], (x0 - 1.88, 0.0, 0.0), rot_z=math.pi / 2)
    put(kit["wall"], (x0 + 1.88, 0.0, 0.0), rot_z=math.pi / 2)
    # roof: each slope is a 2 m panel, so two per side; the eave sits on the wall top (z = 2.4)
    # and the ridge is at z = 3.0 over y = 0
    for sx in (-1, 1):
        put(kit["roof"], (x0 + sx, -0.5, 2.4))
        put(kit["roof"], (x0 + sx, 0.5, 2.4), rot_z=math.pi)
    if label == "log":  # the hinged leaf in the doorway, hung on its hinge
        put("house_door", (x0 + 0.5, -0.98, 0.0))
    put(kit["gable"], (x0 - 2.0, 0.0, 2.4))
    put(kit["gable"], (x0 + 2.0, 0.0, 2.4))
    figure((x0 + 2.6, -1.6, 0.0))
    return label


def main(out_path):
    ground()
    # three assembled cabins in a row at the back
    for i, (label, kit) in enumerate(CABINS):
        cabin(kit, -6.0 + i * 6.0, label)
    # the loose parts in a grid in front, each with a figure for scale
    cols = 8
    cell = 3.0
    for i, name in enumerate(MODELS):
        cx = (i % cols) * cell - (cols - 1) * cell / 2
        cy = -8.0 - (i // cols) * cell
        put(name, (cx, cy, 0.0))
        figure((cx + 1.2, cy - 0.4, 0.0))

    # the game's camera: perspective, pitch 38.7 deg down, yaw 45 deg
    pitch = math.radians(38.7)
    yaw = math.radians(45.0)
    d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    target = Vector((0.0, -8.0, 1.0))
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "PERSP"
    cam_d.lens = 50.0
    cam = bpy.data.objects.new("cam", cam_d)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = target + d * 40.0
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam

    sun_d = bpy.data.lights.new("sun", "SUN")
    sun_d.energy = 3.2
    sun_d.angle = math.radians(8)
    sun = bpy.data.objects.new("sun", sun_d)
    sun.rotation_euler = (math.radians(52), 0, math.radians(35))
    bpy.context.scene.collection.objects.link(sun)
    w = bpy.context.scene.world or bpy.data.worlds.new("w")
    bpy.context.scene.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.5, 0.55, 0.62, 1)
    bg.inputs["Strength"].default_value = 0.9

    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.resolution_x = 1800
    sc.render.resolution_y = 1200
    sc.render.filepath = out_path
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
    print("[housekit_sheet] wrote", out_path, sc.render.engine)


main(OUT[0] if OUT else "/tmp/housekit_sheet.png")
