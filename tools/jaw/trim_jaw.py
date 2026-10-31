#!/usr/bin/env python3
"""Pull a lower jaw that juts past the upper snout back under it (an underbite "lip").

Open-mouth generator meshes (Tripo) model the lower jaw long; once add_jaw.py --open closes it, its tip sits in front
of the upper lip. This slides the front of the jaw skin back along the Jaw bone (a smooth ramp from --from of its reach to
the tip) so the chin tip ends --gap behind the upper lip's front. Each vertex moves by its Jaw weight, so the blended corner barely moves and the rigid teeth keep their
spacing ratio. Bones are untouched, so every clip still plays.

  Blender -b --python tools/jaw/trim_jaw.py -- <in.glb> <out.glb> [--gap 0.004] [--band 0.015] [--head Head]
"""
import argparse, sys
import bpy

ap = argparse.ArgumentParser()
ap.add_argument("inp"); ap.add_argument("out")
ap.add_argument("--head", default="Head")
ap.add_argument("--gap", type=float, default=0.004, help="chin tip ends this far (mesh units) behind the upper lip front")
ap.add_argument("--from", dest="frm", type=float, default=0.55, help="only skin past this fraction of the chin's reach moves (ramped), so the lips behind it stay sealed")
ap.add_argument("--band", type=float, default=0.015, help="upper lip = Head skin within this height of the chin tip")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm), key=lambda o: len(o.data.vertices))
mw = ob.matrix_world; inv = mw.inverted()
jb = arm.data.bones["Jaw"]
piv = arm.matrix_world @ jb.head_local
ax = (arm.matrix_world @ jb.tail_local - piv).normalized()
JI, HI = ob.vertex_groups["Jaw"].index, ob.vertex_groups[a.head].index

def wt(v, gi): return next((g.weight for g in v.groups if g.group == gi), 0.0)
pts = [(v, mw @ v.co) for v in ob.data.vertices]
chin = max((p for v, p in pts if wt(v, JI) > 0.9), key=lambda p: (p - piv).dot(ax))
lip = max((p for v, p in pts if wt(v, HI) > 0.5 and abs(p.z - chin.z) < a.band), key=lambda p: (p - piv).dot(ax))
lc, ll = (chin - piv).dot(ax), (lip - piv).dot(ax)
shift = max(0.0, lc - (ll - a.gap)); t0 = a.frm * lc
print(f"chin {lc:.4f} upper lip {ll:.4f} along the jaw: overbite {lc - ll:+.4f}, pulling the chin back {shift:.4f}")
for v, p in pts:
    w = wt(v, JI); x = min(max(((p - piv).dot(ax) - t0) / (lc - t0), 0.0), 1.0)
    if w > 0 and x > 0: v.co = inv @ (p - ax * (shift * x * x * (3 - 2 * x) * w))

for o in list(bpy.data.objects):
    if o not in (arm, ob) and o.type == "MESH" and o.parent is None: bpy.data.objects.remove(o)  # bone-shape sphere
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", a.out)
