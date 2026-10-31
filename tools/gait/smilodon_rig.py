"""SP-SMILODON: put the transplant skeleton's legs inside the cat's legs and re-weight them as cat legs.

Why: the Triceratops donor's landmark warp left the smilodon's hind knee 6 cm in the air in front of the thigh and the
haunch on the spine (it would not swing with the leg), and the foot bones lie flat along the ground like a hoof.
A cat stands on its toes, so here each leg is hip/shoulder -> knee/elbow -> hock/wrist (UpLeg, LowLeg) and the Foot
bone runs from the hock/wrist down to the toe tips (metatarsus + paw, rigid). make_gait.py plants the Foot head
(hock/wrist) and rolls the foot about its tail (the toe tips), so the heel peels off the ground the way a cat's does.

Weights: every leg weight the transplant gave is handed back to the spine, then each leg takes the skin inside its
own region (lateral side, a fore/aft window, below a top height that rises into the haunch/shoulder), split along
the three segments by distance, the paw rigid on Foot. Spine and head weights are otherwise untouched.

usage: Blender -b -P tools/gait/smilodon_rig.py -- <transplant.glb> <out.glb>
"""
import math
import sys

import bpy
from mathutils import Vector
from mathutils.geometry import intersect_point_line

SRC, DST = sys.argv[sys.argv.index("--") + 1:][:2]

# Left-side joints in mesh units (Blender axes, head toward -Y, ground z=0), read off a gridded side and front render
# of the Tripo mesh (rig_side/rig_front in the report folder). The right side mirrors x.
JOINTS = {
    "Front": dict(top=(0.065, -0.300, 0.290), mid=(0.062, -0.245, 0.175), ank=(0.060, -0.270, 0.065), toe=(0.060, -0.355, 0.012)),
    "Back": dict(top=(0.060, 0.130, 0.300), mid=(0.052, 0.100, 0.180), ank=(0.050, 0.200, 0.125), toe=(0.050, 0.105, 0.012)),
}
# Skin region of each leg: fore/aft window (y0 fade-in .. y1 full .. y2 full .. y3 fade-out), top height (full below
# z_full, none above z_none), the paw (below z_paw) is rigid on Foot.
REGION = {
    "Front": dict(y=(-0.43, -0.39, -0.20, -0.15), z_full=0.24, z_none=0.33, z_paw=0.035),
    "Back": dict(y=(0.00, 0.06, 0.22, 0.31), z_full=0.21, z_none=0.34, z_paw=0.035),
}
SPINE_FOR = {"Front": "Shoulders", "Back": "Back"}
LATERAL = (0.004, 0.030)  # |x| fade-in: the midline (chest ruff, belly, groin) stays on the spine
TAU = 0.012  # segment blend softness (mesh units)


def sstep(e0, e1, x):
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
for end, j in JOINTS.items():
    for sgn, s in ((1, "L"), (-1, "R")):
        m = Vector((sgn, 1, 1))
        T, M, A, X = (inv @ (Vector(j[k]) * m) for k in ("top", "mid", "ank", "toe"))
        eb[f"{end}Leg.{s}"].tail = T
        eb[f"{end}UpLeg.{s}"].head, eb[f"{end}UpLeg.{s}"].tail = T, M
        eb[f"{end}LowLeg.{s}"].head, eb[f"{end}LowLeg.{s}"].tail = M, A
        foot = eb[f"{end}Foot.{s}"]
        foot.head, foot.tail = A, X
        for nm, h in ((f"{end}LowLeg.{s}_end", A), (f"{end}Foot.{s}_end", X)):
            e = eb.get(nm)
            if e:
                d = e.tail - e.head
                e.head, e.tail = h, h + d
bpy.ops.object.mode_set(mode="OBJECT")

mw = ob.matrix_world
names = {g.index: g.name for g in ob.vertex_groups}
LEG_GROUPS = {f"{e}{p}.{s}" for e in JOINTS for p in ("UpLeg", "LowLeg", "Foot", "Leg") for s in "LR"}
for n in [*LEG_GROUPS, *SPINE_FOR.values()]:
    if n not in ob.vertex_groups:
        ob.vertex_groups.new(name=n)
names = {g.index: g.name for g in ob.vertex_groups}
stats = {"leg_verts": 0, "full_leg": 0}
for v in ob.data.vertices:
    p = mw @ v.co
    w = {names[g.group]: g.weight for g in v.groups if g.weight > 0}
    spine = {n: x for n, x in w.items() if n not in LEG_GROUPS}
    leg_share = sum(x for n, x in w.items() if n in LEG_GROUPS)
    side = "L" if p.x >= 0 else "R"
    sgn = 1 if side == "L" else -1
    # the midline fade is for the chest, belly and groin; below them the legs stand apart, so a paw's inner toes stay
    # on their leg (with the fade they stayed on the spine and stretched into a wedge in the gallop)
    lat = max(sstep(*LATERAL, abs(p.x)), 1 - sstep(0.10, 0.16, p.z))
    new = {}
    m_total = 0.0
    for end, r in REGION.items():
        y0, y1, y2, y3 = r["y"]
        if end == "Back" and p.z > 0.15:  # the back edge slopes forward with height: the tail root stays on the tail
            y2, y3 = y2 - 0.35 * (p.z - 0.15), y3 - 0.35 * (p.z - 0.15)
        m = lat * sstep(y0, y1, p.y) * (1 - sstep(y2, y3, p.y)) * (1 - sstep(r["z_full"], r["z_none"], p.z))
        if m <= 1e-4:
            continue
        j = {k: Vector(c) * Vector((sgn, 1, 1)) for k, c in JOINTS[end].items()}
        segs = [(f"{end}UpLeg.{side}", j["top"], j["mid"]), (f"{end}LowLeg.{side}", j["mid"], j["ank"]),
                (f"{end}Foot.{side}", j["ank"], j["toe"])]
        if p.z < r["z_paw"]:
            split = {segs[2][0]: 1.0}
        else:
            ds = []
            for n, a, b in segs:
                q, t = intersect_point_line(p, a, b)
                t = min(max(t, 0.0), 1.0)
                ds.append((n, (p - (a + (b - a) * t)).length))
            dmin = min(d for _, d in ds)
            raw = {n: math.exp(-(d - dmin) / TAU) for n, d in ds}
            tot = sum(raw.values())
            split = {n: x / tot for n, x in raw.items()}
        for n, x in split.items():
            new[n] = new.get(n, 0.0) + m * x
        m_total += m
    m_total = min(m_total, 1.0)
    if not spine and m_total < 1.0:
        # skin the transplant gave to a leg only: its spine share goes to the nearest end's spine bone
        spine = {SPINE_FOR["Front" if p.y < -0.06 else "Back"]: 1.0}
    st = sum(spine.values())
    for n, x in spine.items():
        new[n] = new.get(n, 0.0) + (1 - m_total) * x / st
    # max four influences, normalised
    top4 = sorted(new.items(), key=lambda kv: -kv[1])[:4]
    tot = sum(x for _, x in top4)
    for gi in [g.group for g in v.groups]:  # indices first: removing while walking v.groups skips elements
        ob.vertex_groups[gi].remove([v.index])
    for n, x in top4:
        if x / tot > 1e-4:
            ob.vertex_groups[n].add([v.index], x / tot, "REPLACE")
    if m_total > 0:
        stats["leg_verts"] += 1
    if m_total > 0.999:
        stats["full_leg"] += 1
# Tried and dropped: rigid fur islands. Tripo built the surface as a patchwork of 4063 islands sewn by position, so
# rigid patches tore the body into plates, and the one "loose card" found spanned heel and tail (it pulled the heel
# skin onto Tail1/Tail2 and under the floor in the stalk). Smooth positional weights keep the seams closed.
for s in "LR":  # the leg roots carry the hip/shoulder pivot only
    for e in JOINTS:
        arm.data.bones[f"{e}Leg.{s}"].use_deform = False
print("SMILODON_RIG", stats)
for o in list(bpy.data.objects):
    if o not in (arm, ob):
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", DST)
