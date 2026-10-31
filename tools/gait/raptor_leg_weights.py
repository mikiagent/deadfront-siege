"""SP-RAPTOR: hand the thigh skin from the hip-socket bone (BackLeg.*) to the leg (BackUpLeg.*).

The transplant skinned the whole thigh (from the hip down to the hock, 1150 vertices a side) to BackLeg.*, the short
pelvis-to-hip-socket bone, and only 170 vertices to BackUpLeg.*, the bone that swings the leg. Gaits hide it (the
thigh barely swings), but the sickle slash and the pin stamp lift the foot to the belly and the thigh stayed behind:
the shin stretched into a thin string from the hip to the raised foot. Per vertex on a leg's side (|x| > --mid),
a share f of its BackLeg weight moves to the same side's BackUpLeg: f = 0 above --top, 1 below --bottom (mesh
units, smoothstep between), so the thigh follows the leg and the rump keeps the pelvis. Positions, bones and
everything else are unchanged.

usage: Blender -b -P tools/gait/raptor_leg_weights.py -- <in.glb> <out.glb> [--top 0.24] [--bottom 0.17] [--mid 0.02]
"""
import sys

import bpy

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = a[0], a[1]
opt = lambda k, d: float(a[a.index(k) + 1]) if k in a else d
TOP, BOTTOM, MID = opt("--top", 0.24), opt("--bottom", 0.17), opt("--mid", 0.02)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm), key=lambda o: len(o.data.vertices))
moved = 0
for s in "LR":
    src, dst = ob.vertex_groups["BackLeg." + s], ob.vertex_groups.get("BackUpLeg." + s) or ob.vertex_groups.new(name="BackUpLeg." + s)
    sign = 1.0 if s == "L" else -1.0  # left bones sit at +x
    for v in ob.data.vertices:
        p = ob.matrix_world @ v.co
        if p.x * sign <= MID:
            continue
        w = next((g.weight for g in v.groups if g.group == src.index), 0.0)
        if w <= 0.0:
            continue
        t = min(max((TOP - p.z) / (TOP - BOTTOM), 0.0), 1.0)
        f = t * t * (3 - 2 * t)
        if f <= 0.0:
            continue
        old = next((g.weight for g in v.groups if g.group == dst.index), 0.0)
        src.add([v.index], w * (1 - f), "REPLACE")
        dst.add([v.index], old + w * f, "REPLACE")
        moved += 1
print("LEG WEIGHTS moved", moved)
for o in list(bpy.data.objects):
    if o not in (arm, ob):
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", DST)
