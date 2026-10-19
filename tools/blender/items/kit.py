"""Shared toolkit for item-art builders (headless Blender, bpy + bmesh only).

Builders call these helpers to make parts parented to one ITEM root; render_icons.py
then normalises the root, lights it with one studio rig and writes the PNG.
Geometry is seeded from the item id and the render is Cycles on the CPU with a fixed seed
(EEVEE on the GPU drifted by 1 LSB between runs), so a re-render is byte-identical.
"""
import math
import random
import zlib

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = None
RNG = random.Random(0)
_MATS = {}

# Direction from the item towards the camera: front, a little right, from above.
VIEW = Vector((0.42, -1.0, 0.62)).normalized()


def reset(item_id):
    global ROOT, RNG
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.objects):
        for b in list(block):
            block.remove(b)
    _MATS.clear()
    RNG = random.Random(zlib.crc32(item_id.encode()))
    ROOT = bpy.data.objects.new("ITEM", None)
    ROOT.rotation_mode = "QUATERNION"
    bpy.context.scene.collection.objects.link(ROOT)
    return ROOT


def rnd(a=0.0, b=1.0):
    return RNG.uniform(a, b)


# ---------------------------------------------------------------- materials

def srgb(hexstr):
    """'#rrggbb' -> linear RGBA (node colours are linear)."""
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


def mat(color, rough=0.6, metal=0.0, color2=None, tex=None, scale=6.0, bump=0.0,
        emit=None, emit_strength=0.0, coat=0.0, spec=0.5, alpha=1.0, emit_mask=None, ramp=(0.3, 0.75)):
    """Principled material. tex: None|'noise'|'wave'|'voronoi'|'rings' mixes color->color2.
    emit_mask: voronoi crack mask that drives emission (lava, embers)."""
    key = (color, rough, metal, color2, tex, scale, bump, emit, emit_strength, coat, spec, alpha, emit_mask, ramp)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new("m%d" % len(_MATS))
    m.use_nodes = True
    nt = m.node_tree
    p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = srgb(color)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    p.inputs["Specular IOR Level"].default_value = spec
    if coat:
        p.inputs["Coat Weight"].default_value = coat
        p.inputs["Coat Roughness"].default_value = 0.08
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
    coord = None
    if tex or bump or emit_mask:
        coord = nt.nodes.new("ShaderNodeTexCoord")
    fac = None
    ramp_at = ramp
    if tex:
        if tex == "noise":
            t = nt.nodes.new("ShaderNodeTexNoise")
            t.inputs["Scale"].default_value = scale
            t.inputs["Detail"].default_value = 4.0
            out = t.outputs["Fac"]
        elif tex in ("wave", "rings"):
            t = nt.nodes.new("ShaderNodeTexWave")
            t.wave_type = "RINGS" if tex == "rings" else "BANDS"
            t.inputs["Scale"].default_value = scale
            t.inputs["Distortion"].default_value = 3.0
            t.inputs["Detail"].default_value = 2.0
            out = t.outputs["Fac"]
        else:
            t = nt.nodes.new("ShaderNodeTexVoronoi")
            t.inputs["Scale"].default_value = scale
            out = t.outputs["Distance"]
        nt.links.new(coord.outputs["Object"], t.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = srgb(color)
        ramp.color_ramp.elements[1].color = srgb(color2 or color)
        ramp.color_ramp.elements[0].position = ramp_at[0]
        ramp.color_ramp.elements[1].position = ramp_at[1]
        nt.links.new(out, ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
        fac = out
    if bump:
        bn = nt.nodes.new("ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump
        if fac is None:
            t = nt.nodes.new("ShaderNodeTexNoise")
            t.inputs["Scale"].default_value = scale * 2.0
            nt.links.new(coord.outputs["Object"], t.inputs["Vector"])
            fac = t.outputs["Fac"]
        nt.links.new(fac, bn.inputs["Height"])
        nt.links.new(bn.outputs["Normal"], p.inputs["Normal"])
    if emit:
        p.inputs["Emission Color"].default_value = srgb(emit)
        p.inputs["Emission Strength"].default_value = emit_strength
        if emit_mask:
            v = nt.nodes.new("ShaderNodeTexVoronoi")
            v.feature = "DISTANCE_TO_EDGE"
            v.inputs["Scale"].default_value = emit_mask
            nt.links.new(coord.outputs["Object"], v.inputs["Vector"])
            r = nt.nodes.new("ShaderNodeMapRange")
            r.inputs["From Min"].default_value = 0.0
            r.inputs["From Max"].default_value = 0.06
            r.inputs["To Min"].default_value = emit_strength
            r.inputs["To Max"].default_value = 0.0
            nt.links.new(v.outputs["Distance"], r.inputs["Value"])
            nt.links.new(r.outputs["Result"], p.inputs["Emission Strength"])
    _MATS[key] = m
    return m


# Palette shared by builders so families read as one set.
def wood(c="#8a5a33", c2="#5e3a1e"):
    return mat(c, 0.7, color2=c2, tex="wave", scale=3.0, bump=0.15)


def bark(c="#5b3d24", c2="#3a2614"):
    return mat(c, 0.9, color2=c2, tex="noise", scale=9.0, bump=0.5)


def stone(c="#8d8f8f", c2="#5f6262"):
    return mat(c, 0.85, color2=c2, tex="noise", scale=5.0, bump=0.35)


def metal(c, rough=0.32):
    # 0.85 keeps a little diffuse so metals read against the dark UI from the front
    return mat(c, rough, metal=0.85, tex="noise", color2=c, scale=12.0, bump=0.05)


def bonem(c="#eadfc4"):
    return mat(c, 0.55, color2="#c9b88f", tex="noise", scale=4.0, bump=0.1)


def hidem(c="#9b6b43", c2="#7a4f2e"):
    return mat(c, 0.85, color2=c2, tex="noise", scale=5.0, bump=0.2)


def cloth(c="#d8cfb5", c2="#b9ad8e"):
    return mat(c, 0.9, color2=c2, tex="wave", scale=40.0, bump=0.08)


def rope_m(c="#c7a46a"):
    return mat(c, 0.85, color2="#9c7c45", tex="wave", scale=30.0, bump=0.2)


def flat(c, rough=0.5, **kw):
    return mat(c, rough, **kw)


# ---------------------------------------------------------------- mesh plumbing

def _ob(name, bm, m, loc, rot, scl, smooth, parent, sharp=None):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = smooth
    if smooth and sharp:
        me.set_sharp_from_angle(angle=math.radians(sharp))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if m is not None:
        me.materials.append(m)
    ob.parent = parent or ROOT
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    ob.scale = scl
    return ob


def bevel(ob, w=0.02, seg=2, angle=40):
    md = ob.modifiers.new("bevel", "BEVEL")
    md.width = w
    md.segments = seg
    md.limit_method = "ANGLE"
    md.angle_limit = math.radians(angle)
    return ob


def subsurf(ob, levels=2):
    md = ob.modifiers.new("sub", "SUBSURF")
    md.levels = levels
    md.render_levels = levels
    return ob


def box(size, loc=(0, 0, 0), rot=(0, 0, 0), m=None, bev=0.02, parent=None, taper=None):
    """Bevelled box. taper=(sx, sy) shrinks the top face (ingots, blades)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        if taper and v.co.z > 0:
            v.co.x *= taper[0]
            v.co.y *= taper[1]
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    ob = _ob("box", bm, m, loc, rot, (1, 1, 1), False, parent)
    if bev:
        bevel(ob, bev)
    return ob


def cyl(r, h, loc=(0, 0, 0), rot=(0, 0, 0), m=None, segs=20, r2=None, bev=0.0, smooth=True, parent=None):
    """Cylinder (or cone/frustum with r2) along local Z, centred."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=h)
    ob = _ob("cyl", bm, m, loc, rot, (1, 1, 1), smooth, parent, sharp=35)
    if bev:
        bevel(ob, bev, angle=30)
    return ob


def ball(r, loc=(0, 0, 0), scl=(1, 1, 1), m=None, sub=3, rot=(0, 0, 0), smooth=True, parent=None):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    return _ob("ball", bm, m, loc, rot, scl, smooth, parent)


def rock(r, loc=(0, 0, 0), scl=(1, 1, 1), m=None, jitter=0.22, sub=1, rot=(0, 0, 0), smooth=False, parent=None):
    """Faceted low-poly rock: icosphere with seeded radial jitter."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        v.co *= 1.0 + RNG.uniform(-jitter, jitter)
    return _ob("rock", bm, m, loc, rot, scl, smooth, parent)


def prism(pts, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, bev=0.015, parent=None, smooth=False, deform=None):
    """Extrude a 2D outline [(x, z), ...] (in the XZ plane) by depth along Y, centred.
    deform(co) may edit each vertex in place (thin blade edges, bends)."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, -depth / 2, z)) for x, z in pts]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, depth, 0), verts=nv)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if deform:
        for v in bm.verts:
            deform(v.co)
    ob = _ob("prism", bm, m, loc, rot, (1, 1, 1), smooth, parent)
    if bev:
        bevel(ob, bev, angle=30)
    return ob


def blob(r, loc=(0, 0, 0), scl=(1, 1, 1), m=None, amp=0.12, freq=1.6, sub=3, rot=(0, 0, 0), parent=None, seed=None):
    """Smooth organic lump: icosphere pushed by Perlin noise (meat, clay, sacs)."""
    from mathutils import noise
    off = Vector((rnd(-50, 50), rnd(-50, 50), rnd(-50, 50))) if seed is None else Vector(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        n = v.co.normalized()
        v.co *= 1.0 + amp * noise.noise(n * freq + off, noise_basis="PERLIN_ORIGINAL")
    return _ob("blob", bm, m, loc, rot, scl, True, parent)


def leaf(length=1.0, width=0.35, loc=(0, 0, 0), rot=(0, 0, 0), m=None, curl=0.15, parent=None):
    """Thin pointed leaf in the XZ plane, base at the origin, tip along +Z, curled toward -Y."""
    pts = []
    n = 8
    for i in range(n + 1):
        t = i / n
        pts.append((width * math.sin(math.pi * t) * (1 - 0.3 * t), length * t))
    for i in range(n - 1, 0, -1):
        t = i / n
        pts.append((-width * math.sin(math.pi * t) * (1 - 0.3 * t), length * t))
    pts = pts[:-1] if pts[-1] == pts[0] else pts

    def bend(co):
        co.y -= curl * (co.z / length) ** 2 + curl * 0.6 * (co.x / max(width, 1e-6)) ** 2

    return prism(pts, 0.03, loc=loc, rot=rot, m=m or mat("#4f9a3a", 0.55, color2="#3b7a2a", tex="wave", scale=8.0),
                 bev=0.008, parent=parent, deform=bend)


def lathe(profile, loc=(0, 0, 0), rot=(0, 0, 0), m=None, segs=28, parent=None, smooth=True, scl=(1, 1, 1)):
    """Revolve [(radius, z), ...] around Z (bowls, pots, fruit, mushrooms)."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if profile[0][0] > 1e-4:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _ob("lathe", bm, m, loc, rot, scl, smooth, parent)


def tube(points, r, m=None, segs=10, parent=None, taper=None, closed=False, smooth=True):
    """Sweep a circle along a polyline (handles, rope, coral, nets). taper=(r0, r1) scales radius."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    bm = bmesh.new()
    rings = []
    prev_normal = None
    for i, p in enumerate(pts):
        if closed:
            t = (pts[(i + 1) % n] - pts[i - 1]).normalized()
        else:
            t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        if prev_normal is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            nrm = t.cross(ref).normalized()
        else:
            nrm = (prev_normal - t * prev_normal.dot(t)).normalized()
        prev_normal = nrm
        bin_ = t.cross(nrm)
        rr = r
        if taper:
            rr = r * (taper[0] + (taper[1] - taper[0]) * i / max(n - 1, 1))
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            ring.append(bm.verts.new(p + (nrm * math.cos(a) + bin_ * math.sin(a)) * rr))
        rings.append(ring)
    pairs = list(zip(rings, rings[1:]))
    if closed:
        pairs.append((rings[-1], rings[0]))
    for a, b in pairs:
        for k in range(segs):
            j = (k + 1) % segs
            bm.faces.new((a[k], a[j], b[j], b[k]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _ob("tube", bm, m, (0, 0, 0), (0, 0, 0), (1, 1, 1), smooth, parent)


def arc(center, radius, a0, a1, n=16, plane="xz", y=0.0):
    """Points along a circular arc (degrees) in a plane."""
    out = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        u, v = radius * math.cos(a), radius * math.sin(a)
        if plane == "xz":
            out.append((center[0] + u, y + center[1], center[2] + v))
        else:
            out.append((center[0] + u, center[1] + v, center[2] + y))
    return out


def helix(radius, pitch, turns, n_per_turn=24, z0=0.0, wobble=0.0):
    pts = []
    total = int(turns * n_per_turn)
    for i in range(total + 1):
        a = 2 * math.pi * i / n_per_turn
        rr = radius + wobble * math.sin(a * 3.0)
        pts.append((rr * math.cos(a), rr * math.sin(a), z0 + pitch * i / n_per_turn))
    return pts


def group(loc=(0, 0, 0), rot=(0, 0, 0), parent=None):
    """Empty used to pose a sub-assembly (a stack, a bundle)."""
    e = bpy.data.objects.new("grp", None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent or ROOT
    e.location = loc
    e.rotation_euler = [math.radians(a) for a in rot]
    return e


def lean(deg):
    """Rotate the whole item around the view axis: long tools read best on the diagonal."""
    ROOT.rotation_quaternion = Quaternion(VIEW, math.radians(deg)) @ ROOT.rotation_quaternion


def turn(deg, axis="Z"):
    ax = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}[axis]
    ROOT.rotation_quaternion = Quaternion(ax, math.radians(deg)) @ ROOT.rotation_quaternion


# ---------------------------------------------------------------- studio rig

RIG = {
    "name": "studio_v1",
    "engine": "CYCLES",
    "device": "CPU",
    "samples": 128,
    "seed": 0,
    "threads": 4,
    "render_px": 512,
    "out_px": 256,
    "camera": "orthographic, view dir (0.42,-1,0.62), fit to projected bounds, margin 0.085",
    "lights": "key area 520W warm (-3,-4,5), fill area 170W cool (4,-2,1.5), rim area 700W (1,5,4), gradient world 0.45",
    "view_transform": "Standard",
    "post": "4px dark outline at 512, 2x box downsample, zeroed border rows, deterministic PNG encode",
}
MARGIN = 0.085


def _mesh_points():
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        pts.extend(mw @ v.co for v in me.vertices)
        ev.to_mesh_clear()
    return pts


def normalise():
    """Centre the item on the origin and scale its largest extent to 2 units."""
    bpy.context.view_layer.update()
    pts = _mesh_points()
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    s = 2.0 / max(max(hi - lo), 1e-6)
    c = (lo + hi) / 2
    ROOT.location = (ROOT.location - c) * s
    ROOT.scale = ROOT.scale * s
    bpy.context.view_layer.update()


def _area(name, energy, color, loc, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.color = color
    ld.size = size
    ld.use_shadow = True
    lo = bpy.data.objects.new(name, ld)
    bpy.context.scene.collection.objects.link(lo)
    lo.location = loc
    lo.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return lo


def stage():
    """One light rig, one camera rule, one world for every item."""
    sc = bpy.context.scene
    sc.render.engine = RIG["engine"]
    # CPU, fixed seed, fixed sample count, no denoiser: the only setup that re-renders to the
    # same bytes (EEVEE's GPU path flipped single pixels by 1 LSB from run to run).
    cy = sc.cycles
    cy.device = RIG["device"]
    cy.samples = RIG["samples"]
    cy.seed = RIG["seed"]
    cy.use_animated_seed = False
    cy.use_adaptive_sampling = False
    cy.use_denoising = False
    sc.render.threads_mode = "FIXED"  # frugal on a shared machine; Cycles pixels do not depend on it
    sc.render.threads = RIG["threads"]
    sc.render.resolution_x = sc.render.resolution_y = RIG["render_px"]
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "8"
    sc.view_settings.view_transform = RIG["view_transform"]
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    # Studio world: dark floor, bright top, so metals have something to reflect.
    w = bpy.data.worlds.new("studio")
    w.use_nodes = True
    sc.world = w
    nt = w.node_tree
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[0].color = srgb("#5a534a")
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = srgb("#f2f0ea")
    nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1.0
    mr.inputs["From Max"].default_value = 1.0
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.45
    _area("key", 520.0, (1.0, 0.95, 0.86), (-3.0, -4.0, 5.0), 4.0)
    _area("fill", 170.0, (0.80, 0.88, 1.0), (4.0, -2.0, 1.5), 5.0)
    _area("rim", 700.0, (1.0, 0.98, 0.95), (1.0, 5.0, 4.0), 3.0)
    # Camera: orthographic, framed to the item's projected silhouette.
    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    q = (-VIEW).to_track_quat("-Z", "Y")
    right = q @ Vector((1, 0, 0))
    up = q @ Vector((0, 1, 0))
    pts = _mesh_points()
    xs = [p.dot(right) for p in pts]
    ys = [p.dot(up) for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    extent = max(max(xs) - min(xs), max(ys) - min(ys))
    cd.ortho_scale = extent / (1.0 - 2.0 * MARGIN)
    cd.clip_start = 0.01
    cd.clip_end = 100.0
    cam.location = right * cx + up * cy + VIEW * 10.0
    cam.rotation_euler = q.to_euler()


# ---------------------------------------------------------------- pixels -> PNG

def _dilate(a, r):
    import numpy as np
    out = a.copy()
    h, w = a.shape
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy > r * r or (dx == 0 and dy == 0):
                continue
            sh = np.zeros_like(a)
            ys0, ys1 = max(dy, 0), h + min(dy, 0)
            xs0, xs1 = max(dx, 0), w + min(dx, 0)
            sh[ys0:ys1, xs0:xs1] = a[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
            np.maximum(out, sh, out=out)
    return out


def post(render_png, white=False):
    """512 straight-alpha render -> 256 RGBA uint8 array with an ink outline."""
    import numpy as np
    img = bpy.data.images.load(render_png)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float64).reshape(h, w, 4)[::-1]  # top row first
    bpy.data.images.remove(img)
    rgb, a = px[..., :3], px[..., 3]
    if white:
        rgb = np.ones_like(rgb)
    ink = np.array([0.075, 0.062, 0.05])
    ring = np.clip(_dilate(a, 4) * 1.0, 0.0, 1.0) * 0.96
    # art over ink ring (premultiplied)
    out_a = a + ring * (1.0 - a)
    out_p = rgb * a[..., None] + (0.0 if white else 1.0) * ink * (ring * (1.0 - a))[..., None]
    if white:
        out_a = a
        out_p = rgb * a[..., None]
    # 2x box downsample in premultiplied space
    out_a = out_a.reshape(h // 2, 2, w // 2, 2).mean(axis=(1, 3))
    out_p = out_p.reshape(h // 2, 2, w // 2, 2, 3).mean(axis=(1, 3))
    safe = np.where(out_a > 1e-6, out_a, 1.0)
    straight = np.clip(out_p / safe[..., None], 0.0, 1.0)
    rgba = np.zeros((h // 2, w // 2, 4), dtype=np.uint8)
    rgba[..., :3] = np.round(straight * 255.0).astype(np.uint8)
    rgba[..., 3] = np.round(np.clip(out_a, 0.0, 1.0) * 255.0).astype(np.uint8)
    rgba[rgba[..., 3] == 0] = 0  # no colour under clear pixels: smaller and stable
    rgba[:4] = 0
    rgba[-4:] = 0
    rgba[:, :4] = 0
    rgba[:, -4:] = 0
    return rgba


def encode_png(rgba):
    """Minimal deterministic PNG writer (no metadata chunks, fixed zlib level)."""
    import struct
    import numpy as np
    h, w, _ = rgba.shape
    img = rgba.astype(np.int16)
    bpp = 4
    left = np.zeros_like(img)
    left[:, bpp // 4:] = img[:, :-1]
    up = np.zeros_like(img)
    up[1:] = img[:-1]
    ul = np.zeros_like(img)
    ul[1:, 1:] = img[:-1, :-1]
    pa = np.abs(up - ul)
    pb = np.abs(left - ul)
    pc = np.abs(left + up - 2 * ul)
    paeth = np.where((pa <= pb) & (pa <= pc), left, np.where(pb <= pc, up, ul))
    cands = [img, img - left, img - up, img - (left + up) // 2, img - paeth]
    cands = [(c % 256).astype(np.uint8).reshape(h, w * 4) for c in cands]
    raw = bytearray()
    for y in range(h):
        best = min(range(5), key=lambda f: int(np.abs(cands[f][y].astype(np.int8).astype(np.int32)).sum()))
        raw.append(best)
        raw += cands[best][y].tobytes()

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
