"""MEGANTLERS: the stag's antlers against its own body and the floor, clip by clip.
  Blender -b -P tools/gait/megaloceros/check_antlers.py -- <megaloceros.glb> <anim dir> [clip ...]
Samples each clip on its own keys (Blender lerps quaternion keys componentwise, so subframes can twist) on the skinned meshes. An antler vertex is "in the body" when it lies more than
TOL under the hide's surface (nearest hide point, against that face's normal). Skipped: contact with the head's own skin (HEADSKIN), the burrs and pedicles
and the beam bases by the ears (within SEAT_R of each side's innermost point: the ears and brow skin are weighted to the neck and brush them) and whatever already sits in the head at rest (burr rims, seated in the skull
on purpose), so the count is what the clip pushes into the body. Prints per clip the frame with the most points in, the deepest one, and the lowest antler point;
"ANTLERS PASS" when nothing goes deeper than MAX_DEPTH into the body or under FLOOR.
"""
import bpy, sys, os, glob
from mathutils import Vector
from mathutils.bvhtree import BVHTree
a = sys.argv[sys.argv.index("--") + 1:]
BASE, ANIM = a[:2]
CLIPS = a[2:] or sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(ANIM, "*.glb")))
TOL, SEAT_R, MAX_DEPTH, FLOOR = 0.03, 1.1, 0.10, -0.02
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
hide = bpy.data.objects["MegalocerosHide"]; ant = bpy.data.objects["Antlers"]
# the head's own skin (ears, brow: Head weight >= 0.4) rides the head with the antlers; the ears swing into the beams
# when the head drops (they are half on Neck2), a body weighting matter, not the rack's
hg = hide.vertex_groups["Head"].index
HEADSKIN = {v.index for v in hide.data.vertices if any(g.group == hg and g.weight >= 0.4 for g in v.groups)}
def verts(o):
    e = o.evaluated_get(bpy.context.evaluated_depsgraph_get()); m = e.to_mesh()
    out = [o.matrix_world @ v.co for v in m.vertices]; e.to_mesh_clear(); return out
rest = verts(ant)
# the seats: each side's innermost point (the pedicle and burr sit on the skull's midline side)
seats = [min((p for p in rest if s * p.x > 0), key=lambda p: abs(p.x)) for s in (1, -1)]
skip = {i for i, p in enumerate(rest) if min((p - s).length for s in seats) < SEAT_R}
def inside(av, skip):
    hv = verts(hide); he = hide.evaluated_get(bpy.context.evaluated_depsgraph_get()); hm = he.to_mesh()
    polys = [p.vertices[:] for p in hm.polygons]; bvh = BVHTree.FromPolygons(hv, polys); he.to_mesh_clear()
    out = {}
    for i, p in enumerate(av):
        if i in skip: continue
        loc, nor, fi, d = bvh.find_nearest(p)
        if loc is not None and d < 0.5 and (p - loc).dot(nor) < -TOL and not any(v in HEADSKIN for v in polys[fi]):
            out[i] = -(p - loc).dot(nor)
    return out
skip |= set(inside(rest, skip))
print(f"antler verts {len(rest)}, skipped (seats, in the head at rest) {len(skip)}")
fails = []
for clip in CLIPS:
    objs = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ANIM, clip + ".glb"))
    act = max(set(bpy.data.actions) - acts, key=lambda x: x.frame_range[1])
    for o in set(bpy.data.objects) - objs: bpy.data.objects.remove(o, do_unlink=True)
    arm.animation_data_create(); arm.animation_data.action = act
    try: arm.animation_data.action_slot = act.slots[0]
    except Exception: pass
    f0, f1 = act.frame_range; sc = bpy.context.scene
    worst, worst_f, low, low_f, deep = 0, f0, 9.0, f0, 0.0
    for f in range(int(f0), int(f1) + 1):
        sc.frame_set(f)
        av = verts(ant); ins = inside(av, skip); n_in = len(ins)
        deep = max(deep, max(ins.values(), default=0.0))
        z = min(p.z for p in av)
        if n_in > worst: worst, worst_f = n_in, f
        if z < low: low, low_f = z, f
    bad = deep > MAX_DEPTH or low < FLOOR
    print(f"{clip:16s} in-body {worst:4d} pts (frame {worst_f:.0f}), deepest {deep:.2f} m  lowest {low:+.2f} m (frame {low_f:.0f})  {'FAIL' if bad else 'ok'}")
    if bad: fails.append(clip)
    bpy.data.actions.remove(act)
print("ANTLERS PASS" if not fails else f"ANTLERS FAIL: {', '.join(fails)}")
