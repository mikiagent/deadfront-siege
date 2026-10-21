# Render helpers: workbench texture shading, auto-framed ortho camera, numpy montage.
import bpy, numpy as np, os
from mathutils import Vector
def setup(engine="WORKBENCH"):
    sc = bpy.context.scene
    if engine == "WORKBENCH":
        sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
        if sc.world is None: sc.world = bpy.data.worlds.new("W")
        sc.world.color = (0.75, 0.77, 0.8)
    else:
        try: sc.render.engine = "BLENDER_EEVEE_NEXT"
        except TypeError: sc.render.engine = "BLENDER_EEVEE"
        w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
        bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = (0.8, 0.82, 0.85, 1); bg.inputs[1].default_value = 0.9
        if not bpy.data.objects.get("sun"):
            s = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(s); s.data.energy = 3.0; s.rotation_euler = (0.7, 0.2, 0.9)
    sc.view_settings.view_transform = "Standard"
    if not bpy.data.objects.get("cam"):
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam)
    cam = bpy.data.objects["cam"]; sc.camera = cam; cam.data.type = "ORTHO"; cam.data.clip_end = 200
    return cam
def floor(size=30):
    if bpy.data.objects.get("floor"): return
    me = bpy.data.meshes.new("floor"); s = size
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new("floor", me); bpy.context.scene.collection.objects.link(o)
    m = bpy.data.materials.new("floorm"); m.diffuse_color = (0.35, 0.42, 0.3, 1); me.materials.append(m)
def mesh_points(obj):
    dg = bpy.context.evaluated_depsgraph_get(); ev = obj.evaluated_get(dg); me = ev.to_mesh()
    P = np.empty(len(me.vertices) * 3); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
    M = np.array(obj.matrix_world); P = P @ M[:3, :3].T + M[:3, 3]; ev.to_mesh_clear(); return P
def shot(path, d, P, w=640, h=480, margin=1.12, center=None, ortho=None):
    sc = bpy.context.scene; cam = sc.camera
    d = Vector(d).normalized(); c = Vector(center) if center is not None else Vector(((P.min(0) + P.max(0)) / 2).tolist())
    cam.location = c + d * 60; cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    if ortho is None:
        # extent in camera plane
        R = np.array(cam.rotation_euler.to_matrix()); rel = P - np.array(c); u = rel @ R[:, 0]; v = rel @ R[:, 1]
        ortho = max((u.max() - u.min()) * margin, (v.max() - v.min()) * margin * w / h, 0.5)
    cam.data.ortho_scale = ortho
    sc.render.resolution_x, sc.render.resolution_y = w, h; sc.render.resolution_percentage = 100
    sc.render.filepath = path; bpy.ops.render.render(write_still=True); return ortho
def montage(paths, cols, out):
    ims = []
    for p in paths:
        im = bpy.data.images.load(p); a = np.array(im.pixels[:]).reshape(im.size[1], im.size[0], 4); ims.append(a); bpy.data.images.remove(im)
    h = max(i.shape[0] for i in ims); w = max(i.shape[1] for i in ims); rows = (len(ims) + cols - 1) // cols
    M = np.ones((rows * h, cols * w, 4))
    for k, a in enumerate(ims):
        r, c = divmod(k, cols); y0 = (rows - 1 - r) * h  # pixel rows start at the bottom
        M[y0:y0 + a.shape[0], c * w:c * w + a.shape[1]] = a
    img = bpy.data.images.new("mont", cols * w, rows * h, alpha=True); img.pixels[:] = M.ravel(); img.filepath_raw = out; img.file_format = "PNG"; img.save(); bpy.data.images.remove(img)
