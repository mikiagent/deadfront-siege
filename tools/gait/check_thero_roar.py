"""THERO-ROAR gate on a roar clip, in Blender on the posed skin (game metres via --height, the species' height_meters):
  - feet planted: every Toe/Metatarsal joint stays within 5 cm of frame 0 for the whole clip
  - no sinking: the lowest skin point never under -2 cm
  - the rear: hips rise and the chest pitches up at the peak
  - the sweep: the head's heading (its bone axis on the ground plane) sweeps >= 180 deg
  - the jaw: opens >= 25 deg from its rest against the head
usage: Blender -b -P tools/gait/check_thero_roar.py -- <base.glb> <roar.glb> --height <m>
Prints THEROROAR_CHECK PASS|FAIL and the numbers.
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
base, clip = a[:2]
H = float(a[a.index("--height") + 1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
body = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
dg = bpy.context.evaluated_depsgraph_get()


def skin():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    co = co.reshape(-1, 3)
    mw = np.array(body.matrix_world)
    return co @ mw[:3, :3].T + mw[:3, 3]


rest = skin()
SCALE = H / float(rest[:, 2].max() - min(0.0, rest[:, 2].min()))  # game metres per Blender unit
objs, acts = set(bpy.data.objects), set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=clip)
act = max(set(bpy.data.actions) - acts, key=lambda x: x.frame_range[1])
for o in set(bpy.data.objects) - objs:
    bpy.data.objects.remove(o, do_unlink=True)
arm.animation_data_create()
arm.animation_data.action = act
try:
    arm.animation_data.action_slot = act.slots[0]
except Exception:
    pass
pbs = arm.pose.bones
f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
mw = arm.matrix_world
fwd = Vector((0, 1 if arm.data.bones["Head"].head_local.y > arm.data.bones["Hips"].head_local.y else -1, 0))
JOINTS = [(n, end) for sd in "LR" for n, end in (("Metatarsal." + sd, "head"), ("Toe." + sd, "head"), ("Toe." + sd, "tail"))]


def joint(n, end):
    return mw @ (pbs[n].head if end == "head" else pbs[n].tail)


def heading():
    y = (mw.to_3x3() @ pbs["Head"].matrix.to_3x3().col[1]).normalized()
    return math.degrees(math.atan2(y.dot(fwd.cross(Vector((0, 0, 1)))), y.dot(fwd)))


def jaw_open():
    h = pbs["Head"].matrix.to_3x3().col[1].normalized()
    j = pbs["Jaw"].matrix.to_3x3().col[1].normalized()
    return math.degrees(h.angle(j))


bpy.context.scene.frame_set(f0)
start = {k: joint(*k) for k in JOINTS}
hip0 = (mw @ pbs["Hips"].head).z
jaw0 = jaw_open()
drift = sink = 0.0
rise = 0.0
heads, jaws = [], []
for f in range(f0, f1 + 1):
    bpy.context.scene.frame_set(f)
    for k in JOINTS:
        drift = max(drift, (joint(*k) - start[k]).length * SCALE)
    sink = max(sink, -float(skin()[:, 2].min()) * SCALE)
    rise = max(rise, ((mw @ pbs["Hips"].head).z - hip0) * SCALE)
    heads.append(heading())
    jaws.append(jaw_open() - jaw0)
h = np.unwrap(np.radians(heads))
sweep = math.degrees(h.max() - h.min())
gape = max(jaws)
ok = drift <= 0.05 and sink <= 0.02 and sweep >= 180.0 and gape >= 25.0 and rise > 0.0
print("THEROROAR_CHECK %s %s frames %d: foot drift %.3f m, sink %.3f m, hip rise %.2f m, head sweep %.0f deg, jaw %.0f deg"
      % ("PASS" if ok else "FAIL", clip.split("/")[-1], f1 - f0 + 1, drift, sink, rise, sweep, gape))
