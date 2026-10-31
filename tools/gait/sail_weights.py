"""SP-SPINOSAURUS: smooth the sail's skin weights so it rides the spine as one membrane.

Bone heat gives the tall sail (Tripo kept it whole on the back) noisy Hips/Spine1/Chest/Tail weights near its crest; a
4 m lever turns that noise into torn crest spikes (stretch 11x in the run). Every sail vertex (|x| < --mid, above the
back line --base-z, between --y0 and --y1, mesh units, head -Y) takes a Gaussian blend (sigma --sigma along y) of the
weights of the back skin at the sail's base, so each column of the sail moves with the back right under it and
neighbouring columns differ smoothly. Only the spine chain (Hips, Spine1, Chest, Neck1-2, Tail*) is kept: the back skin
near the hips also holds Thigh weight, and a sail riding the thighs swung with every stride.
usage: Blender -b -P tools/gait/sail_weights.py -- <rig.glb> <out.glb> [--base-z 0.30] [--mid 0.035] [--y0 -0.30] [--y1 0.15] [--sigma 0.03]
"""
import sys

import bpy
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[:2]


def opt(k, d):
    return float(a[a.index(k) + 1]) if k in a else d


BASE, MID, Y0, Y1, SIG = opt("--base-z", 0.30), opt("--mid", 0.035), opt("--y0", -0.30), opt("--y1", 0.15), opt("--sigma", 0.03)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
mw = ob.matrix_world
names = [g.name for g in ob.vertex_groups]
co = np.array([tuple(mw @ v.co) for v in ob.data.vertices])
W = np.zeros((len(co), len(names)))
for v in ob.data.vertices:
    for g in v.groups:
        W[v.index, g.group] = g.weight
sail = (np.abs(co[:, 0]) < MID) & (co[:, 2] > BASE) & (co[:, 1] > Y0) & (co[:, 1] < Y1)
base = (np.abs(co[:, 0]) < MID * 2) & (co[:, 2] > BASE - 0.03) & (co[:, 2] <= BASE) & (co[:, 1] > Y0 - 0.05) & (co[:, 1] < Y1 + 0.05)
print("SAIL verts", int(sail.sum()), "base verts", int(base.sum()))
assert sail.sum() > 50 and base.sum() > 20
# only the spine chain carries the sail (the back skin at its base also holds thigh and arm weight near the joints)
AXIAL = np.array([n in ("Hips", "Spine1", "Chest", "Neck1", "Neck2") or n.startswith("Tail") for n in names])
by, bw = co[base, 1], W[base] * AXIAL
for i in np.where(sail)[0]:
    k = np.exp(-((co[i, 1] - by) / SIG) ** 2)
    w = (k[:, None] * bw).sum(axis=0) / max(k.sum(), 1e-9)
    top = np.argsort(-w)[:4]
    nw = np.zeros_like(w)
    nw[top] = w[top]
    W[i] = nw / max(nw.sum(), 1e-9)
for vg in ob.vertex_groups:
    vg.remove([int(i) for i in np.where(sail)[0]])
for i in np.where(sail)[0]:
    for j in np.nonzero(W[i])[0]:
        ob.vertex_groups[j].add([int(i)], float(W[i, j]), "REPLACE")
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True, export_image_format="AUTO", export_materials="EXPORT")
print("SAIL wrote", OUT)
