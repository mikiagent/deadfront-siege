"""Shared kit for the DEADFRONT biome props (game/assets/nature/biome).

Headless only:  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P build_all.py
Blender is Z up, metres. Geometry is authored with z = 0 at the ground and the footprint centred on
x = y = 0, so the exported GLB has its origin at the ground centre and is Y up (export_yup).
Colour is baked per vertex (a COLOR_0 attribute) and read by one Principled material per asset,
"biome_vcol" (base colour = attribute "Col", roughness 0.72). COLOR_0 stores the authored sRGB
shade verbatim; Godot's importer reads COLOR_0 as sRGB (vertex_color_is_srgb) and linearises it (see
the note above paint()).
No image textures: the GLBs are a few KB each, which the mobile web build needs.
"""
import math
import os
import random
import zlib

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_DIR = os.path.join(REPO, "game", "assets", "nature", "biome")
SCENE_PREFIX = "BIOME_"
MAT_NAME = "biome_vcol"
COLOR_ATTR = "Col"


def srgb(c):
    """sRGB triplet -> linear. The GLBs no longer use this for COLOR_0 (see paint()); it stays for
    tools that need linear numbers, e.g. sheet.py's Blender previews."""
    out = []
    for x in c[:3]:
        x = max(0.0, min(1.0, x))
        out.append(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


def hash01(*args):
    """Deterministic hash noise in 0..1 (no Python hash(), no RNG state to thread through)."""
    h = zlib.crc32(repr(args).encode("utf-8")) & 0xFFFFFFFF
    return h / 0xFFFFFFFF


def noise3(co, cell, seed=0.0):
    """Cheap smooth-ish 3D noise in 0..1 from hashed lattice corners (trilinear)."""
    x, y, z = co.x / cell + seed, co.y / cell + seed * 1.7, co.z / cell + seed * 2.3
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    fx, fy, fz = x - xi, y - yi, z - zi
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    fz = fz * fz * (3 - 2 * fz)
    out = 0.0
    for dz in (0, 1):
        for dy in (0, 1):
            for dx in (0, 1):
                w = (fx if dx else 1 - fx) * (fy if dy else 1 - fy) * (fz if dz else 1 - fz)
                out += w * hash01(xi + dx, yi + dy, zi + dz, seed)
    return out


def wobble(co, octaves=3, cell=1.0, seed=0.0):
    """fBm in about -1..1."""
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total += amp * (noise3(co, cell / (2 ** o), seed + o * 13.1) - 0.5) * 2.0
        norm += amp
        amp *= 0.5
    return total / norm


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def shade(c, k):
    return (max(0.0, min(1.0, c[0] * k)), max(0.0, min(1.0, c[1] * k)), max(0.0, min(1.0, c[2] * k)))


def new_scene(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.name = SCENE_PREFIX + name
    scn.unit_settings.system = "METRIC"
    scn.unit_settings.scale_length = 1.0
    return scn


# ---------------------------------------------------------------- materials

_MATS = {}


def material(name=MAT_NAME, rough=0.72, metallic=0.0, double_sided=False):
    """One Principled material reading the baked vertex colour. double_sided=False culls back
    faces (glTF doubleSided=false), which is right for every solid; only foliage cards pass True."""
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = COLOR_ATTR
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    mat.use_backface_culling = not double_sided
    mat["biome_asset"] = True
    return mat


# ---------------------------------------------------------------- finishing a mesh

def finalize(bm, name, smooth=False, flat_above=None, double_sided=False, rough=0.72, metallic=0.0):
    """Triangulate, set shading, make an object at the world origin (geometry is already metres)."""
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    if flat_above is not None:
        for f in bm.faces:
            f.smooth = f.normal.z < flat_above
    else:
        for f in bm.faces:
            f.smooth = smooth
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.name = name
    me.materials.append(material(rough=rough, metallic=metallic, double_sided=double_sided))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# Measured, not assumed (BIOMEPROPS, Godot 4.7.1 + gl_compatibility): the glTF importer sets the
# imported material's vertex_color_is_srgb = true, i.e. it takes COLOR_0 as sRGB and converts it to
# linear itself. Storing linear numbers here therefore darkened every prop twice (sandstone came out
# a grey slab, basalt near black) on the deployed build. The authored sRGB value is stored verbatim;
# tests/t_biomeprops.gd fails if a model's stored paint is not sRGB.
# sheet.py (Blender) previews these numbers as linear, so its renders read lighter than the game;
# Godot is the authority for colour.


def paint(bm, fn):
    """fn(co) -> sRGB (r, g, b) for every vertex, stored in the COLOR_0 attribute as sRGB."""
    layer = bm.verts.layers.float_color.get(COLOR_ATTR)
    if layer is None:
        layer = bm.verts.layers.float_color.new(COLOR_ATTR)
    for v in bm.verts:
        c = fn(Vector(v.co))
        v[layer] = (max(0.0, min(1.0, c[0])), max(0.0, min(1.0, c[1])), max(0.0, min(1.0, c[2])), 1.0)
    return bm


def _bounds(ob):
    """World-space AABB (lo, hi) of an object's vertices."""
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for v in ob.data.vertices:
        p = ob.matrix_world @ v.co
        lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
        hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
    return lo, hi


def export(objs, name):
    """Join the parts of one asset into a single mesh (one draw call) and write OUT_DIR/name.glb."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    # Origin at the ground centre of the AABB: shift so the footprint centre is x = y = 0 and the
    # lowest geometry sits on z = 0, whatever the builder did with its parts.
    lo, hi = _bounds(ob)
    # x/y only: the AABB centre of the footprint sits on the origin, z stays as authored so big
    # landforms keep their skirt below z = 0 (ground_z in the report).
    ob.location -= Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, 0.0))
    bpy.context.view_layer.update()
    ob.select_set(True)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
        export_vertex_color="MATERIAL",
        export_normals=True,
        export_extras=False,
        export_cameras=False,
        export_lights=False,
    )
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    lo, hi = _bounds(ob)
    # Godot axes: x = Blender x, y up = Blender z, z = Blender y
    size = (hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)
    return {"name": name, "tris": tris, "verts": len(ob.data.vertices),
            "size_m": [round(s, 2) for s in size],
            "ground_z": round(lo.z, 3), "center_xy": [round((lo.x + hi.x) * 0.5, 2), round((lo.y + hi.y) * 0.5, 2)],
            "materials": [m.name for m in ob.data.materials]}


# ---------------------------------------------------------------- primitives
# Helpers add to an existing bmesh at world positions and return the new verts.

def add_cylinder(bm, p0, p1, r0, r1, segments=8, caps=True, matrix=None):
    """A tapered cylinder from p0 to p1 (Vectors, metres). Optional extra matrix for the profile."""
    p0 = Vector(p0)
    p1 = Vector(p1)
    d = p1 - p0
    length = d.length
    if length < 1e-5:
        return []
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    mat = Matrix.Translation((p0 + p1) * 0.5) @ rot
    if matrix is not None:
        mat = mat @ matrix
    res = bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=segments,
                                radius1=r0, radius2=r1, depth=length, matrix=mat)
    return res["verts"]


def ring_points(n, radius, phase=0.0):
    return [(radius * math.cos(phase + 2 * math.pi * i / n), radius * math.sin(phase + 2 * math.pi * i / n))
            for i in range(n)]


def loft(bm, rings, close_top=True, close_bottom=True):
    """Loft rings of equal length (lists of coords) into a tube. `rings` runs bottom to top."""
    rows = [[bm.verts.new(Vector(co)) for co in ring] for ring in rings]
    n = len(rings[0])
    for j in range(len(rows) - 1):
        for i in range(n):
            a, b = rows[j][i], rows[j][(i + 1) % n]
            c, d = rows[j + 1][(i + 1) % n], rows[j + 1][i]
            bm.faces.new((a, b, c, d))
    if close_bottom:
        bm.faces.new(list(reversed(rows[0])))
    if close_top:
        top = rows[-1]
        if len(top) <= 12:
            bm.faces.new(top)
        else:
            c = bm.verts.new(sum((v.co for v in top), Vector()) / len(top))
            for i in range(n):
                bm.faces.new((top[i], top[(i + 1) % n], c))
    return [v for row in rows for v in row]


def add_ico(bm, center, radius, subdiv=1, scale=(1, 1, 1), wob=0.0, seed=0.0, sink=0.0):
    """An icosphere, squashed by `scale`, roughened by `wob` (metres) and sunk `sink` below z = 0."""
    center = Vector(center)
    res = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius,
                                     matrix=Matrix.Translation(center))
    verts = res["verts"]
    base = Vector(center)
    for v in verts:
        d = v.co - base
        v.co = Vector((base.x + d.x * scale[0], base.y + d.y * scale[1], base.z + d.z * scale[2]))
        if wob:
            v.co += Vector((wobble(v.co, 2, radius * 0.7, seed),
                            wobble(v.co, 2, radius * 0.7, seed + 4.2),
                            wobble(v.co, 2, radius * 0.7, seed + 9.1))) * wob
        if v.co.z < sink:
            v.co.z = sink
    return verts


def add_sheet(bm, fn, nu, nv, double=False):
    """A parametric sheet fn(u, v) -> Vector, u and v in 0..1. double=True adds the mirrored back."""
    def make(flip):
        rows = []
        for j in range(nv + 1):
            rows.append([bm.verts.new(fn(i / nu, j / nv)) for i in range(nu + 1)])
        for j in range(nv):
            for i in range(nu):
                q = (rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i])
                bm.faces.new(q if not flip else tuple(reversed(q)))

    make(False)
    if double:
        make(True)


def leaf(bm, base, tip, width, normal=(0, 0, 1), bend=0.0, steps=3, taper=0.8, fold=0.18):
    """A tapered ribbon leaf from base to tip, `width` across, bowed `bend` metres along `normal`."""
    base = Vector(base)
    tip = Vector(tip)
    axis = tip - base
    up = Vector(normal).normalized()
    side = axis.cross(up)
    side = side.normalized() if side.length > 1e-6 else Vector((1, 0, 0))
    side *= 0.5

    def fn(u, v):
        w = width * (1.0 - u) ** taper
        co = base + axis * u + side * (w * (v * 2.0 - 1.0))
        co += up * (bend * math.sin(u * math.pi) - fold * w * abs(v * 2.0 - 1.0))
        return co

    add_sheet(bm, fn, steps, 1)


def rot_z(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


def placed(p, deg, center=(0, 0, 0)):
    """p rotated by `deg` about the Z axis through `center`."""
    c = Vector(center)
    return c + (Matrix.Rotation(math.radians(deg), 3, "Z") @ (Vector(p) - c))


def rng_for(name, seed=7):
    return random.Random(zlib.crc32(name.encode()) + seed)
