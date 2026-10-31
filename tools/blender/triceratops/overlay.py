# Measuring aid: orthographic textured render of a region with a metre grid (thin every 0.1 m, thick every 0.5 m)
# and the joint chain of joints.py drawn on top (red bones, yellow joints), so joints can be placed on the mesh.
# Blender -b <file.blend> --factory-startup -P overlay.py -- <out.png> <view side|front|top|back> <y0> <y1> <z0> <z1> [x0 x1]
import bpy, sys, os, importlib, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rlib
joints = importlib.import_module(os.environ.get("TRIKE_JOINTS", "joints")); importlib.reload(joints)
a = sys.argv[sys.argv.index("--") + 1:]
out, view = a[0], a[1]; y0, y1, z0, z1 = map(float, a[2:6]); x0, x1 = (map(float, a[6:8]) if len(a) > 7 else (-2.0, 2.0))
o = bpy.data.objects["SM_Triceratops"]
arm = bpy.data.objects.get("Armature")
if arm:
    arm.animation_data_create(); arm.animation_data.action = None
    for pb in arm.pose.bones: pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
rlib.setup()
# view: (camera dir, image-right axis, image-up axis); side looks at the animal's right flank (head to the right)
V = {"side": ((1, 0, 0), 1, 2, 1), "front": ((0, 1, 0), 0, 2, -1), "top": ((0, 0, 1), 1, 0, -1), "back": ((0, -1, 0), 0, 2, 1)}
d, ax_u, ax_v, sgn_u = V[view]
lo = {0: x0, 1: y0, 2: z0}; hi = {0: x1, 1: y1, 2: z1}
W = 1000; Hh = int(W * (hi[ax_v] - lo[ax_v]) / (hi[ax_u] - lo[ax_u]))
c = [(lo[i] + hi[i]) / 2 for i in range(3)]
P = np.array([[lo[0], lo[1], lo[2]], [hi[0], hi[1], hi[2]]])
ortho = hi[ax_u] - lo[ax_u]
rlib.shot(out, d, P, W, Hh, center=c, ortho=ortho if W >= Hh else hi[ax_v] - lo[ax_v])  # Blender fits ortho_scale to the longer side
im = bpy.data.images.load(out); px = np.array(im.pixels[:]).reshape(Hh, W, 4)
def uv(p):
    u = (sgn_u * (p[ax_u] - c[ax_u])) / ortho * W + W / 2
    v = (p[ax_v] - c[ax_v]) / ortho * W + Hh / 2  # pixel rows count from the bottom in Blender images
    return u, v
def line(p, q, col, w=1):
    (u0, v0), (u1, v1) = uv(p), uv(q); n = int(max(abs(u1 - u0), abs(v1 - v0))) + 1
    for t in np.linspace(0, 1, n):
        u = int(round(u0 + (u1 - u0) * t)); v = int(round(v0 + (v1 - v0) * t))
        if 0 <= u < W and 0 <= v < Hh: px[max(0, v - w + 1):v + w, max(0, u - w + 1):u + w, :3] = col
for g in np.arange(np.floor(lo[ax_u] * 10) / 10, hi[ax_u] + 1e-6, 0.1):
    thick = abs(g * 2 - round(g * 2)) < 1e-6
    p = list(c); q = list(c); p[ax_u] = q[ax_u] = g; p[ax_v] = lo[ax_v]; q[ax_v] = hi[ax_v]
    u, _ = uv(p); u = int(round(u))
    if 0 <= u < W: px[:, max(0, u - (1 if thick else 0)):u + 1, :3] = px[:, max(0, u - (1 if thick else 0)):u + 1, :3] * 0.6 + (0.2 if thick else 0.35)
for g in np.arange(np.floor(lo[ax_v] * 10) / 10, hi[ax_v] + 1e-6, 0.1):
    thick = abs(g * 2 - round(g * 2)) < 1e-6
    p = list(c); p[ax_v] = g
    _, v = uv(p); v = int(round(v))
    if 0 <= v < Hh: px[max(0, v - (1 if thick else 0)):v + 1, :, :3] = px[max(0, v - (1 if thick else 0)):v + 1, :, :3] * 0.6 + (0.2 if thick else 0.35)
for n, (h, t, p) in joints.J.items():
    if view == "side" and n.endswith(".L"): continue
    line(h, t, (1, 0.1, 0.1), 2)
    u, v = uv(h); u, v = int(u), int(v)
    if 0 <= u < W and 0 <= v < Hh: px[max(0, v - 4):v + 4, max(0, u - 4):u + 4, :3] = (1, 0.9, 0)
im.pixels[:] = px.ravel(); im.save()
print("OVERLAY", out, W, Hh)
