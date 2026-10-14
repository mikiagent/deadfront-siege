#!/usr/bin/env python3
"""Finish and inspect one Meshy nature/prop GLB (Blender headless).

  Blender --background --python tools/nature_wave_finish.py -- inspect  in.glb  sheet.png
  Blender --background --python tools/nature_wave_finish.py -- finish   in.glb  out.glb  <height_m> [clip=<frac>] [gain=<x>]
      height_m < 0 scales the longest side to |height_m| (fallen logs).
      clip=<frac>  deletes every face whose centre is below frac * height: Meshy often adds a thin soil pad or mound
                   under small plants, which the art brief forbids. The cut is logged in the REPORT line.
      gain=<x>     multiplies the base-colour texture by x (texture only, geometry untouched).
      bark=1       recolours very dark (grey-black) texels toward brown wood.
      variant=moss|snow  paints patchy moss (dark crack texels plus upward faces) or snow (upward faces) into the
                   base-colour texture, by face normal through the UVs: a free material swap of the same mesh.
      under=<x>    with variant=snow, darkens the base texture by x first (a dark boulder under snow).

inspect: renders front / side / three-quarter plus the project camera (pitch -35.264, yaw 45, orthographic
         size 15 and 17 m) with a 1.72 m survivor stand-in, and prints a JSON report. The model is not changed.
finish:  merges every mesh into one object, applies transforms, scales uniformly so the height is <height_m>,
         centres the base on the origin with its lowest point at Y=0, downsizes every texture to at most 1024 px
         JPEG (alpha-bearing textures are reported, not flattened) and writes a GLB (metres, Y up).
Prints one `REPORT {json}` line.
"""
import json
import math
import pathlib
import sys

import bpy
from mathutils import Vector

GAME_PITCH = 35.264
GAME_YAW = 45.0
SURVIVOR_H = 1.72
TEX_MAX = 1024


def reset_and_import(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def merge(meshes):
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    for o in meshes:
        o.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(p[i] for p in pts) for i in range(3)))
    hi = Vector((max(p[i] for p in pts) for i in range(3)))
    return lo, hi


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def texture_report(obj):
    out = []
    for mat in obj.data.materials:
        if not mat or not mat.use_nodes:
            continue
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img = n.image
                has_alpha = False
                if img.channels == 4 and img.size[0] and img.size[1]:
                    px = img.pixels[:]
                    has_alpha = any(a < 0.99 for a in px[3::4][:: max(1, len(px) // 4 // 20000)])
                out.append({"name": img.name, "size": list(img.size), "alpha_used": has_alpha})
        # alpha blend/clip on the material itself
    return out


def shrink_textures(obj):
    done = []
    for mat in obj.data.materials:
        if not mat or not mat.use_nodes:
            continue
        for n in mat.node_tree.nodes:
            if n.type != "TEX_IMAGE" or not n.image:
                continue
            img = n.image
            w, h = img.size
            if max(w, h) > TEX_MAX:
                k = TEX_MAX / max(w, h)
                img.scale(max(1, int(w * k)), max(1, int(h * k)))
            done.append({"name": img.name, "size": list(img.size)})
    return done


def clip_base(obj, frac):
    """Delete faces whose centre is below frac * height, then drop vertices left loose. Returns the count removed."""
    import bmesh

    lo, hi = bounds(obj)
    limit = lo.z + frac * (hi.z - lo.z)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    doomed = [f for f in bm.faces if (obj.matrix_world @ f.calc_center_median()).z < limit]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    return len(doomed)


def lift_textures(obj, gain):
    import numpy as np

    for mat in obj.data.materials:
        if not mat or not mat.use_nodes:
            continue
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img = n.image
                px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, img.channels)
                px[:, :3] = np.clip(px[:, :3] * gain, 0, 1)
                img.pixels = px.ravel().tolist()


def _first_image(obj):
    for mat in obj.data.materials:
        if mat and mat.use_nodes:
            for n in mat.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    return n.image
    return None


def _smooth(x, a, b):
    import numpy as np

    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def _noise(size, seed, scales=(5, 11, 23, 53)):
    import numpy as np

    rng = np.random.default_rng(seed)
    out = np.zeros((size, size), np.float32)
    amp, total = 1.0, 0.0
    for sc in scales:
        g = rng.random((sc + 1, sc + 1)).astype(np.float32)
        xs = np.linspace(0, sc, size, endpoint=False)
        i = xs.astype(int)
        f = (xs - i).astype(np.float32)
        fx, fy = f[None, :], f[:, None]
        v = (g[i][:, i] * (1 - fx) * (1 - fy) + g[i][:, i + 1] * fx * (1 - fy)
             + g[i + 1][:, i] * (1 - fx) * fy + g[i + 1][:, i + 1] * fx * fy)
        out += amp * v
        total += amp
        amp *= 0.55
    return out / total


def upward_mask(obj, size):
    """Texture-space mask, 1 where the surface faces up (vertex normal z), rasterised through the UVs."""
    import numpy as np

    me = obj.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    mask = np.zeros((size, size), np.float32)
    for tri in me.loop_triangles:
        p = np.array([[uv[li].uv[0] * (size - 1), uv[li].uv[1] * (size - 1)] for li in tri.loops], np.float32)
        w = np.array([min(1.0, max(0.0, (me.vertices[vi].normal.z - 0.15) / 0.6)) for vi in tri.vertices], np.float32)
        x0, y0 = np.floor(p.min(0)).astype(int)
        x1, y1 = np.ceil(p.max(0)).astype(int)
        x0, y0, x1, y1 = max(x0 - 1, 0), max(y0 - 1, 0), min(x1 + 1, size - 1), min(y1 + 1, size - 1)
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        d = (p[1][1] - p[2][1]) * (p[0][0] - p[2][0]) + (p[2][0] - p[1][0]) * (p[0][1] - p[2][1])
        if abs(d) < 1e-9:
            continue
        a = ((p[1][1] - p[2][1]) * (xs - p[2][0]) + (p[2][0] - p[1][0]) * (ys - p[2][1])) / d
        b = ((p[2][1] - p[0][1]) * (xs - p[2][0]) + (p[0][0] - p[2][0]) * (ys - p[2][1])) / d
        c = 1 - a - b
        inside = (a >= -0.02) & (b >= -0.02) & (c >= -0.02)
        val = a * w[0] + b * w[1] + c * w[2]
        region = mask[y0:y1 + 1, x0:x1 + 1]
        np.maximum(region, np.where(inside, val, 0), out=region)
    for _ in range(2):  # bleed a texel or two so seams do not show
        mask = np.maximum(mask, np.maximum(np.roll(mask, 1, 0), np.maximum(np.roll(mask, -1, 0), np.maximum(np.roll(mask, 1, 1), np.roll(mask, -1, 1)))))
    return mask


def recolor_bark(img):
    import numpy as np

    w, h = img.size
    px = np.array(img.pixels[:], np.float32).reshape(h, w, img.channels)
    rgb = px[..., :3]
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    m = np.clip((0.42 - lum) / 0.2, 0, 1)[..., None]
    brown = ((lum * 1.55 + 0.05)[..., None]) * np.array([1.15, 0.85, 0.60], np.float32)
    px[..., :3] = np.clip(rgb * (1 - m) + brown * m, 0, 1)
    img.pixels = px.ravel().tolist()


def paint_variant(obj, kind, under=1.0):
    import numpy as np

    img = _first_image(obj)
    if img is None:
        return
    w, h = img.size
    px = np.array(img.pixels[:], np.float32).reshape(h, w, img.channels)
    rgb = px[..., :3]
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    rel = lum / max(float(lum.mean()), 1e-3)
    up = upward_mask(obj, w)
    n1, n2 = _noise(w, 1), _noise(w, 2)
    if kind == "snow":
        rgb = rgb * under
        a = _smooth(up * 0.58 + (n1 - 0.5) * 1.0, 0.52, 0.66)[..., None]
        snow = np.array([0.91, 0.93, 0.96], np.float32) * (0.9 + 0.1 * np.clip(rel, 0, 1.6))[..., None]
        rgb = rgb * (1 - a) + snow * a
    elif kind == "moss":
        crack = np.clip((0.95 - rel) / 0.55, 0, 1)
        a = _smooth(0.9 * n1 + 0.35 * crack + 0.35 * up * n2, 0.66, 0.76)[..., None]
        low, high = np.array([0.13, 0.23, 0.08], np.float32), np.array([0.25, 0.37, 0.14], np.float32)
        moss = (low + (high - low) * n2[..., None]) * (0.85 + 0.3 * np.clip(rel, 0, 1.5))[..., None]
        rgb = rgb * (1 - a) + moss * a
    px[..., :3] = np.clip(rgb, 0, 1)
    img.pixels = px.ravel().tolist()


def finish(src, dst, height, clip=0.0, gain=1.0, bark=False, variant="", under=1.0):
    meshes = reset_and_import(src)
    if not meshes:
        raise SystemExit("no mesh in " + str(src))
    obj = merge(meshes)
    removed = clip_base(obj, clip) if clip > 0 else 0
    bpy.context.view_layer.update()  # bound_box is stale after the bmesh edit
    shrink_textures(obj)
    if gain != 1.0:
        lift_textures(obj, gain)
    if bark and _first_image(obj):
        recolor_bark(_first_image(obj))
    if variant:
        paint_variant(obj, variant, under)
    lo, hi = bounds(obj)
    # A negative height means: scale so the longest side is |height| (fallen logs).
    k = -height / max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z) if height < 0 else height / (hi.z - lo.z)
    obj.scale = (k, k, k)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    lo, hi = bounds(obj)
    obj.location = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    lo, hi = bounds(obj)
    textures = shrink_textures(obj)
    alpha = texture_report(obj)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(dst), export_format="GLB", export_yup=True, export_apply=True,
                              export_animations=False, export_image_format="JPEG", export_image_quality=88,
                              export_materials="EXPORT")
    d = hi - lo
    report = {"file": pathlib.Path(dst).name, "size_m": [round(d.x, 3), round(d.z, 3), round(d.y, 3)],  # width, height, depth
              "base_y": round(lo.z, 4), "triangles": triangles(obj), "meshes": 1, "materials": len(obj.data.materials),
              "textures": textures, "alpha_textures": [a["name"] for a in alpha if a["alpha_used"]],
              "base_clip_frac": clip, "faces_removed": removed, "texture_gain": gain, "bark_recolor": bark, "variant": variant or None}
    print("REPORT " + json.dumps(report))


def survivor(x, y):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=SURVIVOR_H - 0.3, location=(x, y, (SURVIVOR_H - 0.3) / 2))
    body = bpy.context.object
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.15, location=(x, y, SURVIVOR_H - 0.15))
    head = bpy.context.object
    mat = bpy.data.materials.new("survivor")
    mat.diffuse_color = (0.15, 0.35, 0.75, 1)
    for o in (body, head):
        o.data.materials.append(mat)
    return [body, head]


def setup_world():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light = "STUDIO"
    sh.color_type = "TEXTURE"
    sh.show_shadows = True
    scene.render.resolution_x = scene.render.resolution_y = 768
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.62, 0.66, 0.62)
    scene.display.shading.background_type = "WORLD"
    gb = bpy.data.objects.new("ground", bpy.data.meshes.new("g"))
    bpy.context.collection.objects.link(gb)
    verts = [(-30, -30, -0.001), (30, -30, -0.001), (30, 30, -0.001), (-30, 30, -0.001)]
    gb.data.from_pydata(verts, [], [(0, 1, 2, 3)])
    mat = bpy.data.materials.new("gm")
    mat.diffuse_color = (0.30, 0.34, 0.24, 1)
    gb.data.materials.append(mat)
    scene.display.shading.color_type = "TEXTURE"


def shoot(cam_loc, target, out, ortho=None, persp_lens=50):
    scene = bpy.context.scene
    cam = bpy.data.objects.get("cam") or bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    scene.camera = cam
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = "PERSP"
        cam.data.lens = persp_lens
    cam.location = cam_loc
    d = Vector(target) - Vector(cam_loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(out)
    bpy.ops.render.render(write_still=True)


def inspect(src, sheet):
    meshes = reset_and_import(src)
    obj = merge(meshes)
    lo, hi = bounds(obj)
    h = hi.z - lo.z
    cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
    setup_world()
    survivor(max(hi.x - cx, hi.y - cy) + 0.9, 0)
    out = pathlib.Path(sheet)
    tiles = []
    r = max(h, hi.x - lo.x, hi.y - lo.y) * 3.2
    t = (cx, cy, h / 2)
    views = {"front": (cx, cy - r, h / 2 + 0.1), "side": (cx + r, cy, h / 2 + 0.1), "three-quarter": (cx + r * 0.7, cy - r * 0.7, h * 0.9 + 0.3)}
    for name, loc in views.items():
        p = out.with_name(out.stem + "_" + name + ".png")
        shoot(loc, t, p)
        tiles.append((name, p))
    pitch, yaw = math.radians(GAME_PITCH), math.radians(GAME_YAW)
    dist = 60
    gloc = (cx + dist * math.cos(pitch) * math.sin(yaw), cy - dist * math.cos(pitch) * math.cos(yaw), dist * math.sin(pitch))
    for size in (15, 17):
        p = out.with_name(out.stem + f"_game{size}.png")
        shoot(gloc, (cx, cy, 0.3), p, ortho=size)
        tiles.append((f"game ortho {size}m", p))
    print("TILES " + json.dumps([[n, str(p)] for n, p in tiles]))
    print("REPORT " + json.dumps({"size_m": [round(hi.x - lo.x, 3), round(h, 3), round(hi.y - lo.y, 3)],
                                  "base_y": round(lo.z, 4), "triangles": triangles(obj), "textures": texture_report(obj)}))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    if argv[0] == "inspect":
        inspect(argv[1], argv[2])
    elif argv[0] == "finish":
        opts = dict(a.split("=", 1) for a in argv[4:])
        finish(argv[1], argv[2], float(argv[3]), float(opts.get("clip", 0)), float(opts.get("gain", 1)),
               opts.get("bark") == "1", opts.get("variant", ""), float(opts.get("under", 1)))
    else:
        raise SystemExit(__doc__)
