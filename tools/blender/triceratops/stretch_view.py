# Skin-in-motion check: colour each vertex by the worst stretch or squash of its edges at one frame of a clip
# (grey = unchanged, red = stretched 2x or more, blue = squashed to half), four views.
# Blender -b anim.blend --factory-startup -P stretch_view.py -- <out.png> <clip> <frame> [focus x y z radius]
import bpy, sys, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rlib
a = sys.argv[sys.argv.index("--") + 1:]
out, clip, fr = a[0], a[1], int(a[2])
arm = bpy.data.objects["Armature"]; mesh = bpy.data.objects["SM_Triceratops"]; me = mesh.data
E = np.array([e.vertices[:] for e in me.edges]); P0 = np.array([v.co[:] for v in me.vertices])
L0 = np.linalg.norm(P0[E[:, 0]] - P0[E[:, 1]], axis=1); ok = L0 > 0.01
act = bpy.data.actions[clip]; arm.animation_data_create(); arm.animation_data.action = act
try: arm.animation_data.action_slot = act.slots[0]
except Exception: pass
sc = bpy.context.scene; sc.frame_set(fr)
P = rlib.mesh_points(mesh)
r = np.ones(len(E)); r[ok] = np.linalg.norm(P[E[ok, 0]] - P[E[ok, 1]], axis=1) / L0[ok]
lr = np.log2(r)
worst = np.zeros(len(P0))
np.maximum.at(worst, E[:, 0], np.abs(lr)); np.maximum.at(worst, E[:, 1], np.abs(lr))
sgn = np.zeros(len(P0)); np.add.at(sgn, E[:, 0], lr); np.add.at(sgn, E[:, 1], lr)
t = np.clip(worst, 0, 1)[:, None]
C = np.where(sgn[:, None] >= 0, (1 - t) * 0.7 + t * np.array([1.0, 0.05, 0.05]), (1 - t) * 0.7 + t * np.array([0.1, 0.2, 1.0]))
attr = me.color_attributes.new("scol", "FLOAT_COLOR", "POINT")
attr.data.foreach_set("color", np.hstack([C, np.ones((len(C), 1))]).ravel()); me.color_attributes.active_color = attr
rlib.setup(); rlib.floor(); sc.display.shading.color_type = "VERTEX"
paths = []; tmp = os.path.dirname(os.path.abspath(out))
Pv = P
if len(a) > 6:
    c = np.array([float(v) for v in a[3:6]]); rad = float(a[6]); Pv = P[np.linalg.norm(P - c, axis=1) < rad]
for k, d in enumerate([(1, 0, 0.05), (-1, 0, 0.05), (1, 1.1, 0.5), (-1, -1.1, 0.5)]):
    p = f"{tmp}/_s{k}.png"; rlib.shot(p, d, Pv, 700, 450, margin=1.05); paths.append(p)
rlib.montage(paths, 2, out)
print("STRETCH VIEW", out, "edges>1.5x", int((r > 1.5).sum()), "max", round(float(r.max()), 2))
