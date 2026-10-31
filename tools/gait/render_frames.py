"""Side-view frame renderer shared by make_gait.py and render_clip.py (Blender, headless)."""
import math
import os

import bpy


def _mat(name, rgba):
    m = bpy.data.materials.new(name)
    m.diffuse_color = rgba  # Workbench
    if m.node_tree:  # Eevee
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = rgba
    return m


def render(sc, cfg, frames_dir, n, textured=False, first=0, ground_speed=0.0):
    """Render frames first..first+n-1 of the current scene to frames_dir/f000.png...

    The striped ground scrolls backwards at ground_speed (m/s) so a planted foot of an in-place loop
    looks stuck to it when the clip's stride matches that speed, and visibly skates when it does not.
    """
    os.makedirs(frames_dir, exist_ok=True)
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "SINGLE"
    sc.display.shading.single_color = (0.72, 0.62, 0.5)
    sc.display.shading.show_cavity = True
    sc.display.shading.show_shadows = True
    if textured:  # what players see: the real texture under a sun
        sc.render.engine = "BLENDER_EEVEE"
        sc.eevee.taa_render_samples = 16
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        sun.data.energy = 4.0
        sun.rotation_euler = (math.radians(50), 0, math.radians(60))
        sc.collection.objects.link(sun)
    sc.render.resolution_x, sc.render.resolution_y = 640, 480
    sc.render.film_transparent = False
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.55, 0.62, 0.7)
    if textured and sc.world.node_tree:
        bg = next((n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND"), None)
        if bg:
            bg.inputs[0].default_value = (0.55, 0.62, 0.7, 1)
    # ground with stripes every 0.25 m so sliding feet show
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
    g = bpy.context.object
    g.scale = (3, 40, 1)
    rig = bpy.data.objects.new("ground", None)
    sc.collection.objects.link(rig)
    g.parent = rig
    gm = _mat("g", (0.42, 0.5, 0.36, 1))
    g.data.materials.append(gm)
    sm = _mat("s", (0.3, 0.36, 0.26, 1))
    # irregular stripes that repeat exactly once per loop, so the looping video has no jump or
    # wagon-wheel aliasing; a static ground (speed 0) gets plain 0.25 m stripes
    period = ground_speed * n / sc.render.fps
    reps = max(1, int(math.ceil(0.5 / period))) if period > 0 else 1  # keep stripes >= ~7 cm apart
    period = period * reps if period > 0 else 0.25
    ys = []
    for k in range(int(-20 / period), int(20 / period) + 1):
        ys += [k * period + period * x for x in ((0.0, 0.17, 0.36, 0.52, 0.74) if ground_speed > 0 else (0.0,))]
    for y in ys:
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, y, 0.002))
        o = bpy.context.object
        o.scale = (3, 0.02, 1)
        o.parent = rig
        o.data.materials.append(sm)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    size = cfg.get("view_size", 2.6)
    cam.data.ortho_scale = size
    cy = cfg.get("view_centre", [0.0, size * 0.36])
    tilt = math.radians(8)  # look slightly down so the striped ground shows
    cam.location = (6, cy[0], cy[1] + 6 * math.tan(tilt))
    cam.rotation_euler = (math.pi / 2 - tilt, 0, math.pi / 2)
    for f in range(n):
        sc.frame_set(first + f)
        rig.location.y = (ground_speed * f / sc.render.fps) % period
        sc.render.filepath = os.path.join(frames_dir, "f%03d.png" % f)
        bpy.ops.render.render(write_still=True)

