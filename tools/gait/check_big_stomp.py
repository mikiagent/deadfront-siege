"""BIGSTOMP gate for make_big_stomp.py clips (and the rex family's big_stomp): on the skinned base mesh, every planted
foot's slide (max distance from its frame-0 spot, in metres of the game animal), the stomping foot's height at the
impact frame (0.72) and at its peak, and the lowest skin point (sink below the floor). Optionally renders a side and a
front strip (6 frames each) for review.

usage: Blender -b -P tools/gait/check_big_stomp.py -- <base.glb> <clip.glb> <height_m> <stomp_bone> <planted_bone,...>
       [--impact 0.72] [--render out.png]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
BASE, CLIP, HEIGHT, STOMP, PLANTED = a[0], a[1], float(a[2]), a[3], a[4].split(",")
IMPACT = float(a[a.index("--impact") + 1]) if "--impact" in a else 0.72
RENDER = a[a.index("--render") + 1] if "--render" in a else ""
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
for s in shapes:
    if s:
        s.hide_render = True
skin = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
objs, acts = set(bpy.data.objects), set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=CLIP)
act = max(set(bpy.data.actions) - acts, key=lambda x: x.frame_range[1])
for o in set(bpy.data.objects) - objs:
    bpy.data.objects.remove(o, do_unlink=True)
arm.animation_data_create()
arm.animation_data.action = act
try:
    arm.animation_data.action_slot = act.slots[0]
except Exception:
    pass
sc = bpy.context.scene
f0, f1 = (int(round(x)) for x in act.frame_range)


def low():
    ev = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    zs = [(skin.matrix_world @ v.co).z for v in me.vertices]
    ev.to_mesh_clear()
    return min(zs), max(zs)


sc.frame_set(f0)
lo0, hi0 = low()
M = HEIGHT / (hi0 - lo0)  # game metres per world unit


def wpos(b):
    return arm.matrix_world @ arm.pose.bones[b].head


start = {b: wpos(b) for b in PLANTED}
slide = {b: 0.0 for b in PLANTED}
sink, peak, at_impact = 0.0, 0.0, None
ground = wpos(STOMP).z
fi = f0 + round(IMPACT * (f1 - f0))
for f in range(f0, f1 + 1):
    sc.frame_set(f)
    for b in PLANTED:
        slide[b] = max(slide[b], (wpos(b) - start[b]).length * M)
    h = (wpos(STOMP).z - ground) * M
    peak = max(peak, h)
    if f == fi:
        at_impact = h
    sink = min(sink, (low()[0] - lo0) * M)
worst = max(slide.values())
ok = worst <= 0.03 and abs(at_impact) <= 0.08 and sink >= -0.05 and peak >= 0.15 * HEIGHT
print("BIGSTOMP_CHECK %s %s slide_max=%.3f m %s peak=%.2f m impact_h=%.3f m sink=%.3f m -> %s" % (
    os.path.basename(BASE), os.path.basename(CLIP), worst, {k: round(v, 3) for k, v in slide.items()}, peak, at_impact, sink, "PASS" if ok else "FAIL"))

if RENDER:
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = 360, 300
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "SINGLE"
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, lo0))
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for c in skin.bound_box:
        p = skin.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
    ctr, size = (lo + hi) / 2, max(hi - lo)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.2
    sc.camera = cam
    frames = [f0 + round(t * (f1 - f0)) for t in (0.0, 0.3, 0.5, 0.66, IMPACT, 0.9)]
    tmp = os.path.splitext(RENDER)[0]
    paths = []
    for vi, d in enumerate([Vector((1, 0, 0)), Vector((0, 1, 0))]):
        cam.location = ctr + d * size * 3 + Vector((0, 0, size * 0.15))
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        for f in frames:
            sc.frame_set(f)
            sc.render.filepath = "%s_v%d_%03d.png" % (tmp, vi, f)
            bpy.ops.render.render(write_still=True)
            paths.append(sc.render.filepath)
    print("RENDERED", len(paths))
