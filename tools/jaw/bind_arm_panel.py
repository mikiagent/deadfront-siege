#!/usr/bin/env python3
"""Move a generated mesh's own sculpted, folded arm feathers onto the Wing bones (tools/jaw/add_wings.py).

Tripo/Meshy sculpt the folded wing as a feather panel hanging behind the forearm and skin it to the arm, so
when the added fans flare the old panel stays pressed to the flank: two wings. Skin that sits behind the
forearm and out at the side, and is weighted mostly to the arm, ramps over to Wing.L / Wing.R, so the panel
spreads with the fans. The arm and hand themselves (at or ahead of the forearm) keep their weights.

  Blender -b --python tools/jaw/bind_arm_panel.py -- <in.glb> <out.glb> [--ramp 0.04] [--side-min 0.05]
"""
import argparse, sys
import bpy

ap = argparse.ArgumentParser()
ap.add_argument("inp"); ap.add_argument("out")
ap.add_argument("--ramp", type=float, default=0.04, help="distance behind the forearm over which skin hands over to the wing")
ap.add_argument("--start", type=float, default=-0.005, help="hand-over starts this far behind the forearm joint")
ap.add_argument("--side-min", type=float, default=0.05, help="only skin at least this far out from the midline (keeps the chest)")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm), key=lambda o: len(o.data.vertices))
mw = ob.matrix_world; names = {g.index: g.name for g in ob.vertex_groups}
ARM = ("FrontLeg", "FrontUpLeg", "FrontLowLeg")
moved = {"L": 0, "R": 0}
for sd in ("L", "R"):
    wg = ob.vertex_groups.get(f"Wing.{sd}")
    if wg is None: sys.exit("no Wing bones: run add_wings.py first")
    ref = arm.matrix_world @ arm.data.bones[f"FrontLowLeg.{sd}"].head_local
    for v in ob.data.vertices:
        ws = {names[g.group]: g.weight for g in v.groups}
        if f"Wing.{sd}" in ws: continue  # the added fans
        share = sum(ws.get(f"{n}.{sd}", 0.0) for n in ARM)
        p = mw @ v.co
        if share < 0.5 or abs(p.x) < a.side_min: continue
        x = min(max((p.y - ref.y - a.start) / a.ramp, 0.0), 1.0)  # +y is backwards on these -y facing rigs
        h = x * x * (3 - 2 * x)
        if h <= 0: continue
        for n in ARM:
            if f"{n}.{sd}" in ws: ob.vertex_groups[f"{n}.{sd}"].add([v.index], ws[f"{n}.{sd}"] * (1 - h), "REPLACE")
        wg.add([v.index], share * h, "REPLACE")
        moved[sd] += 1
print(f"ARM PANEL to wings: {moved['L']} verts left, {moved['R']} right")
for o in list(bpy.data.objects):
    if o not in (arm, ob) and o.type == "MESH" and o.parent is None: bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", a.out)
