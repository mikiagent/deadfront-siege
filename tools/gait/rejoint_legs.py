"""Move a transplant quadruped's leg joints onto the mesh's real legs and re-split the leg skin between them.

Why (ANKYLO3D): the landmark warp put the ankylosaurus' front shoulder/elbow/foot 7 cm inside the body (x 0.135
while the front leg column stands at x 0.205) and the hind joints 7 cm ahead of the hind leg, with the elbow and knee
only 3-4 cm off the floor. Every stride then swung paw skin through the floor (-0.38 m in game) and stretched the
toes 20-40x. This sets each leg's joints by hand (left side; the right side is mirrored), keeps the foot bones' own
direction, and re-splits only the weight a vertex already gives that leg: paw (below --paw-top) to the foot, the
column between paw and elbow/knee to the lower leg, above it to the upper leg, with smooth bands. Spine weights and
the mesh are untouched. Clips keyed on the old joints must be moved with transfer_clips.py afterwards.

usage: Blender -b -P tools/gait/rejoint_legs.py -- <in.glb> <out.glb>
           --front SX,SY,SZ EX,EY,EZ AX,AY,AZ  --hind HX,HY,HZ KX,KY,KZ AX,AY,AZ  [--paw-top 0.022] [--band 0.012]
       (shoulder/hip, elbow/knee, ankle = the foot bone's head; mesh units, Blender axes, left side x > 0)
"""
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = a[0], a[1]


def vec(s):
    return Vector(tuple(float(x) for x in s.split(",")))


def opt(name, default):
    return float(a[a.index(name) + 1]) if name in a else default


SPEC = {}
for end, flag in (("Front", "--front"), ("Back", "--hind")):
    i = a.index(flag)
    SPEC[end] = [vec(a[i + 1]), vec(a[i + 2]), vec(a[i + 3])]
PAW = opt("--paw-top", 0.022)
BAND = opt("--band", 0.012)


def smooth(e0, e1, x):
    t = min(max((x - e0) / max(e1 - e0, 1e-9), 0.0), 1.0)
    return t * t * (3 - 2 * t)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
inv = arm.matrix_world.inverted()

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
for end, (top, mid, ank) in SPEC.items():
    for sgn, s in ((1, "L"), (-1, "R")):
        m = Vector((sgn, 1, 1))
        T, M, A = (inv @ (p * m) for p in (top, mid, ank))
        root, up, low, foot = eb[f"{end}Leg.{s}"], eb[f"{end}UpLeg.{s}"], eb[f"{end}LowLeg.{s}"], eb[f"{end}Foot.{s}"]
        d = foot.tail - foot.head
        foot.head, foot.tail = A, A + d
        root.tail = T
        up.head, up.tail = T, M
        low.head, low.tail = M, A
        end_b = eb.get(f"{end}LowLeg.{s}_end")
        if end_b:
            de = end_b.tail - end_b.head
            end_b.head, end_b.tail = A, A + de
        fe = eb.get(f"{end}Foot.{s}_end")
        if fe:
            de = fe.tail - fe.head
            fe.head, fe.tail = foot.tail, foot.tail + de
bpy.ops.object.mode_set(mode="OBJECT")

mw = ob.matrix_world
names = {g.index: g.name for g in ob.vertex_groups}
moved = 0
for v in ob.data.vertices:
    p = mw @ v.co
    w = {names[g.group]: g.weight for g in v.groups if g.weight > 0}
    for end, (top, mid, ank) in SPEC.items():
        for s in ("L", "R"):
            chain = [f"{end}UpLeg.{s}", f"{end}LowLeg.{s}", f"{end}Foot.{s}"]
            share = sum(w.get(n, 0.0) for n in chain)
            if share <= 0:
                continue
            wf = 1 - smooth(PAW - BAND / 2, PAW + BAND / 2, p.z)
            wl = (1 - wf) * (1 - smooth(mid.z - BAND, mid.z + BAND, p.z))
            wu = 1 - wf - wl
            for n, x in zip(chain, (wu, wl, wf)):
                g = ob.vertex_groups[n]
                if x * share > 1e-6:
                    g.add([v.index], x * share, "REPLACE")
                else:
                    g.remove([v.index])
            moved += 1
print(f"REJOINT leg vertices re-split: {moved}")
for o in list(bpy.data.objects):
    if o not in (arm, ob):
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", DST)
