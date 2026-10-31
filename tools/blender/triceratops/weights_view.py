# Weight check renders: each vertex coloured by its strongest bone (blended by weight), four views in one sheet.
# Blender -b rig.blend --factory-startup -P weights_view.py -- <out.png> [bone ...]   (bones given: show only their weight, red)
import bpy, sys, os, colorsys, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rlib
a = sys.argv[sys.argv.index("--") + 1:]
out = a[0]; only = a[1:]
mesh = bpy.data.objects["SM_Triceratops"]; me = mesh.data
names = [g.name for g in mesh.vertex_groups]
cols = {n: colorsys.hsv_to_rgb((i * 0.618) % 1.0, 0.75, 0.95) for i, n in enumerate(names)}
C = np.zeros((len(me.vertices), 3))
for v in me.vertices:
    for g in v.groups:
        n = names[g.group]
        if only:
            if n in only: C[v.index] += np.array((1.0, 0.1, 0.1)) * g.weight
        else:
            C[v.index] += np.array(cols[n]) * g.weight
if only: C += 0.6 * (1 - C.max(1, keepdims=True).clip(0, 1))
attr = me.color_attributes.new("wcol", "FLOAT_COLOR", "POINT")
attr.data.foreach_set("color", np.hstack([C, np.ones((len(C), 1))]).ravel())
me.color_attributes.active_color = attr
rlib.setup(); sc = bpy.context.scene
sc.display.shading.color_type = "VERTEX"
P = rlib.mesh_points(mesh); tmp = os.path.dirname(os.path.abspath(out)); paths = []
for k, d in enumerate([(1, 0, 0.02), (-1, 1.1, 0.5), (0, 1, 0.1), (0, 0.001, 1), (1, -1.0, 0.4), (0, -1, 0.1)]):
    p = f"{tmp}/_w{k}.png"; rlib.shot(p, d, P, 700, 450, margin=1.04); paths.append(p)
rlib.montage(paths, 3, out); print("WEIGHTS VIEW", out)
