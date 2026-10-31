"""Check and render an in-place one-shot (make_leap.py) on the skinned mesh.

Prints per clip: lowest skin point over all frames vs the rest pose's lowest point (ground penetration), the hind
toe tips' worst distance from their rest prints on the ground frames (u < 0.2 and u >= 0.65: no slide = no moonwalk,
the game only moves the body inside the airborne window), how high the feet get in the air, and the Jaw's widest
opening. Renders side and front frames (Workbench) to <frames_dir>/side_f###.png and front_f###.png.
Exits 1 on penetration > 1 cm (game scale) or a planted-foot slide > 1 cm.

usage: Blender -b -P tools/gait/check_leap.py -- <base.glb> <clip.glb> <frames_dir> [--game-scale 2.4] [--no-render]
       [--grounded]  (an in-place clip with no airborne window: every frame is a ground frame)
"""
import math
import os
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
base, clip, out = a[:3]
SCALE = float(a[a.index("--game-scale") + 1]) if "--game-scale" in a else 2.4
RENDER = "--no-render" not in a
GROUNDED = "--grounded" in a
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
meshes = [o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and not o.name.startswith(("Icosphere", "Cube"))]
for o in bpy.data.objects:
    if o.type == "MESH" and o not in meshes:
        o.hide_render = True
sc = bpy.context.scene


LOW_AT = [None]


def low_z():
    dg = bpy.context.evaluated_depsgraph_get()
    z = 1e9
    for o in meshes:
        e = o.evaluated_get(dg)
        mw = e.matrix_world
        for v in e.data.vertices:
            w = mw @ v.co
            if w.z < z:
                z, LOW_AT[0] = w.z, w
    return z


sc.frame_set(0)
rest_low = low_z()
feet = {n: arm.matrix_world @ arm.data.bones[n].tail_local for n in ("BackFoot.L_end", "BackFoot.R_end")}  # toe tips
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=clip)
act = next(o for o in set(bpy.data.objects) - before if o.type == "ARMATURE").animation_data.action
for o in set(bpy.data.objects) - before:
    bpy.data.objects.remove(o, do_unlink=True)
arm.animation_data_create()
arm.animation_data.action = act
try:
    arm.animation_data.action_slot = act.slots[0]
except Exception:
    pass
f0, f1 = (int(round(x)) for x in act.frame_range)
n = f1 - f0
worst_low, slide, peak, jaw = 0.0, 0.0, 0.0, 0.0
for f in range(f0, f1 + 1):
    sc.frame_set(f)
    u = (f - f0) / max(1, n)
    lz = low_z() - rest_low
    if "--verbose" in a:
        print(f"  f{f - f0} low {lz * SCALE * 100:+.2f} cm at {tuple(round(x, 3) for x in LOW_AT[0])}")
    worst_low = min(worst_low, lz)
    for nm, p0 in feet.items():
        p = arm.matrix_world @ arm.pose.bones[nm].tail
        if GROUNDED or u <= 0.2 + 1e-6 or u >= 0.65 - 1e-6:
            slide = max(slide, (p - p0).length)
        peak = max(peak, p.z - p0.z)
    if "Jaw" in arm.pose.bones:
        q = arm.pose.bones["Jaw"].matrix_basis.to_quaternion()
        jaw = max(jaw, math.degrees(q.angle))
name = os.path.splitext(os.path.basename(clip))[0]
ok = worst_low * SCALE > -0.01 and slide * SCALE < 0.01
print(f"LEAPCHECK {name} frames {n} len {n / 24:.3f}s penetration {worst_low * SCALE * 100:+.2f} cm "
      f"planted_slide {slide * SCALE * 100:.2f} cm feet_peak {peak * SCALE * 100:.1f} cm jaw_max {jaw:.1f} deg "
      f"{'PASS' if ok else 'FAIL'}")
if RENDER:
    os.makedirs(out, exist_ok=True)
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "SINGLE"
    sc.display.shading.single_color = (0.72, 0.62, 0.5)
    sc.display.shading.show_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = 480, 400
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.55, 0.62, 0.7)
    bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
    g = bpy.context.object
    m = bpy.data.materials.new("g")
    m.diffuse_color = (0.42, 0.5, 0.36, 1)
    g.data.materials.append(m)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.3
    tilt = math.radians(6)
    for view, loc, rot in (("side", (6, 0.0, 0.3 + 6 * math.tan(tilt)), (math.pi / 2 - tilt, 0, math.pi / 2)),
                           ("front", (0.0, -6, 0.3 + 6 * math.tan(tilt)), (math.pi / 2 - tilt, 0, 0))):
        cam.location, cam.rotation_euler = loc, rot
        for f in range(f0, f1 + 1):
            sc.frame_set(f)
            sc.render.filepath = os.path.join(out, "%s_f%03d.png" % (view, f - f0))
            bpy.ops.render.render(write_still=True)
sys.exit(0 if ok else 1)
