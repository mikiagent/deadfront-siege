"""Contact sheet for the town kit: houses assembled the way TownDress assembles them (2 m wall
panels on the plan edge, one town_roof per plan, a chimney), plus the loose town props, from the
game's camera angle with a 1.8 m figure for scale.

Headless:  Blender -b --factory-startup -P tools/blender/structures/townkit_sheet.py -- <out.png>
"""
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(HERE, "housekit_sheet.py")).read()
exec(_src[:_src.index("def main(")])  # the sheet helpers: load, put, figure, ground  # noqa: S102

WALLS = {"log": ("house_wall", "house_wall_window"), "timber": ("house_wall_timber", "house_wall_window_timber"),
         "stone": ("house_wall_stone", "house_wall_window_stone")}
HOUSES = [  # x, y, L, S, wall style, finish
    (-12, 6, 6, 4, "timber", "thatch"), (-4, 6, 8, 6, "stone", "slate"), (5, 6, 4, 4, "log", "shingle"),
    (13, 6, 6, 6, "timber", "tile"), (-8, -4, 10, 8, "stone", "tile"), (4, -4, 8, 4, "log", "thatch"),
]
PROPS = ["town_lamp", "town_stall", "town_awning", "town_woodpile", "town_flowerbox", "town_cart", "town_chimney"]


def house(x, y, L, S, style, finish):
    wall, window = WALLS[style]
    for side in range(4):
        along = L if side % 2 == 0 else S
        across = S if side % 2 == 0 else L
        a = side * math.pi / 2
        for i in range(along // 2):
            off = Vector((-along / 2 + 1 + 2 * i, -across / 2, 0))
            off.rotate(__import__("mathutils").Euler((0, 0, a)))
            name = "house_wall_doorway" if side == 0 and i == along // 4 else (window if i % 2 else wall)
            put(name, (x + off.x, y + off.y, 0.0), rot_z=a)
    put("town_roof_%s_%dx%d" % (finish, L, S), (x, y, 2.4))
    put("town_chimney", (x + L * 0.3, y + 0.4, 2.4))
    figure((x + L / 2 + 0.8, y - S / 2 - 0.8, 0.0))


def main(out_path):
    ground()
    for h in HOUSES:
        house(*h)
    for i, name in enumerate(PROPS):
        put(name, (-14 + i * 4.5, -14, 0.0))
        figure((-14 + i * 4.5 + 1.5, -15, 0.0))
    put("town_gate", (14, -6, 0.0))
    pitch = math.radians(38.7)
    yaw = math.radians(45.0)
    d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    target = Vector((0.0, -2.0, 1.0))
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 50.0
    cam = bpy.data.objects.new("cam", cam_d)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = target + d * 62.0
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    sun_d = bpy.data.lights.new("sun", "SUN")
    sun_d.energy = 3.2
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
    bpy.ops.render.render(write_still=True)
    print("[townkit_sheet] wrote", out_path)


main(OUT[0] if OUT else "/tmp/townkit_sheet.png")
