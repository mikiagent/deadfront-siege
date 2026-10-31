"""PARTCOMBAT weapon meshes (owner 2026-10-31), our own designs, built from primitives:
  slab_blade.glb   one-handed Iron Slab Blade: a survivor-tall slab of dark iron, worn bright edges, simple cross-guard,
                   long grip, a clipped tip (it drags behind her)
  greatblade.glb   two-handed Steel Greatblade: twice a greatsword's width, dark grey-black steel with mottled lighter
                   grey cloud patches; a flattened-diamond section with a central ridge and bright ground edges, a
                   ricasso over a straight cross-guard, a long wrapped grip and a hard angled point
  pro_bow.glb      PRO-Class Bow: recurved bone-and-steel limbs, leather grip, a taut string
Every model stands on its handle axis (Blender +Z, glTF +Y), pommel / lower tip at 0, blade width along X, so
HeldModel puts the handle through the survivor's fist with the edge facing where the fingers point.

  Blender -b --python tools/blender/items/heavy_weapons.py -- <out dir>
"""
import math, random, sys
import bpy, bmesh
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]
random.seed(7)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb, metal=0.0, rough=0.6, image=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if image:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def obj_from_bm(name, bm, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = False
    return ob


def blade(name, z0, z1, w0, w1, thick, edge, tip, mats, uv_scale=1.0, diamond=False):
    """A blade along +Z from z0 to z1, width w0 -> w1, then its tip. Section: a hexagon (flat faces, bright bevelled
    edges: the slab) or, diamond=True, a flattened diamond: a raised central ridge falling to a thin bevel line, and a
    bright ground edge from there to the edge (the greatblade). Faces: material 0 the body, 1 the bright edge.
    tip: 'clip' (the back runs on, the edge side cut away to a point: the slab), 'point' (a hard angled point)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    rings = []
    steps = 10
    for i in range(steps + 1):
        u = i / steps
        rings.append((z0 + (z1 - z0) * u, w0 + (w1 - w0) * u, thick, 0.0))
    if tip == "point":  # both edges run in to a point set a little off centre, the back edge longer: a hard angle
        for k in range(1, 7):
            f = k / 6
            w = w1 * (1.0 - f) ** 1.15
            rings.append((z1 + f * w1 * 0.75, max(0.004, w), thick * max(0.15, 1.0 - 0.8 * f), w1 * 0.18 * f))
    else:
        for k in range(1, 5):
            f = k / 4
            w = w1 * (1.0 - f * 0.92)
            rings.append((z1 + f * w1 * 0.9, w, thick * (1.0 - 0.6 * f), (w1 - w) * 0.5))
    secs = []
    for z, w, t, shift in rings:
        e = min(edge, w * 0.3)
        if diamond:
            tb = t * 0.16  # the bevel line: the edge band from here out is ground thin
            pts = [(-w / 2, 0.0), (-w / 2 + e, tb), (0.0, t / 2), (w / 2 - e, tb), (w / 2, 0.0), (w / 2 - e, -tb), (0.0, -t / 2), (-w / 2 + e, -tb)]
            bright = (0, 3, 4, 7)
        else:
            pts = [(-w / 2, 0.0), (-w / 2 + e, t / 2), (w / 2 - e, t / 2), (w / 2, 0.0), (w / 2 - e, -t / 2), (-w / 2 + e, -t / 2)]
            bright = (0, 2, 3, 5)
        secs.append([bm.verts.new((x + shift, y, z)) for x, y in pts])
    n = len(secs[0])
    for a, b in zip(secs, secs[1:]):
        for j in range(n):
            f = bm.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
            f.material_index = 1 if j in bright else 0
            for lp in f.loops:
                lp[uv].uv = (lp.vert.co.x * uv_scale + 0.5, lp.vert.co.z * uv_scale * 0.5)
    for cap in (secs[0], secs[-1]):
        f = bm.faces.new(cap if cap is secs[-1] else list(reversed(cap)))
        f.material_index = 0
    # Every face points away from the blade's centre line (recalc can flip a thin, pinched point the wrong way).
    bm.normal_update()
    for f in bm.faces:
        c = f.calc_center_median()
        if f.normal.dot(c - Vector((0.0, 0.0, c.z))) < 0.0 and abs(c.x) + abs(c.y) > 1e-4:
            f.normal_flip()
    bm.normal_update()
    return obj_from_bm(name, bm, mats)


def cyl(name, r, z0, z1, m, verts=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=z1 - z0, location=(0, 0, (z0 + z1) / 2))
    o = bpy.context.object
    o.name = name
    o.data.materials.append(m)
    return o


def box(name, sx, sy, sz, z, m):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, z))
    o = bpy.context.object
    o.name = name
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(m)
    return o


def ball(name, r, z, m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=r, location=(0, 0, z))
    o = bpy.context.object
    o.name = name
    o.data.materials.append(m)
    return o


def export(name):
    for o in bpy.data.objects:
        o.select_set(o.type == "MESH")
    bpy.context.view_layer.objects.active = next(o for o in bpy.data.objects if o.type == "MESH")
    bpy.ops.object.join()
    path = f"{OUT}/{name}.glb"
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True)
    o = bpy.context.object
    zs = [v.co.z for v in o.data.vertices]
    xs = [v.co.x for v in o.data.vertices]
    print(f"WEAPON {name} length {max(zs) - min(zs):.2f} m width {max(xs) - min(xs):.2f} m tris {len(o.data.polygons)} -> {path}")


def mottled(name, size=256):
    """Dark grey-black steel with soft lighter-grey cloud patches (value noise, a few octaves)."""
    img = bpy.data.images.new(name, size, size)
    grid = {}

    def noise(x, y, cell):
        gx, gy = int(x // cell), int(y // cell)
        fx, fy = (x % cell) / cell, (y % cell) / cell
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)

        def g(i, j):
            k = (cell, i % (size // cell), j % (size // cell))
            if k not in grid:
                grid[k] = random.random()
            return grid[k]
        a = g(gx, gy) + (g(gx + 1, gy) - g(gx, gy)) * fx
        b = g(gx, gy + 1) + (g(gx + 1, gy + 1) - g(gx, gy + 1)) * fx
        return a + (b - a) * fy
    px = []
    for y in range(size):
        for x in range(size):
            n = 0.55 * noise(x, y, 64) + 0.3 * noise(x, y, 32) + 0.15 * noise(x, y, 16)
            cloud = max(0.0, min(1.0, (n - 0.48) * 3.0))
            v = 0.3 + 0.45 * cloud
            px += [v, v, v * 1.03, 1.0]
    img.pixels = px
    img.pack()
    return img


# --- slab blade (one-handed) ---------------------------------------------------------------------------------------
reset()
iron = mat("dark_iron", (0.2, 0.2, 0.22), 0.55, 0.5)
edge = mat("worn_edge", (0.92, 0.9, 0.85), 0.55, 0.3)
leather = mat("grip_leather", (0.16, 0.09, 0.05), 0.0, 0.8)
blade("blade", 0.37, 1.62, 0.24, 0.21, 0.045, 0.03, "clip", [iron, edge])
box("guard", 0.34, 0.07, 0.05, 0.345, iron)
cyl("grip", 0.022, 0.05, 0.32, leather)
ball("pommel", 0.04, 0.04, iron)
export("slab_blade")

# --- greatblade (two-handed) ---------------------------------------------------------------------------------------
reset()
steel = mat("cloud_steel", (1, 1, 1), 0.1, 0.5, mottled("cloud_steel"))
edge = mat("steel_edge", (0.92, 0.92, 0.9), 0.55, 0.28)
leather = mat("wrap_leather", (0.12, 0.08, 0.06), 0.0, 0.85)
dark = mat("guard_iron", (0.06, 0.06, 0.07), 0.8, 0.5)
box("ricasso", 0.3, 0.055, 0.14, 0.7, dark)  # an unsharpened square shoulder above the guard
blade("blade", 0.77, 1.8, 0.46, 0.38, 0.075, 0.05, "point", [steel, edge], uv_scale=0.9, diamond=True)
box("guard", 0.62, 0.09, 0.07, 0.595, dark)
cyl("grip", 0.027, 0.06, 0.56, leather)
for k in range(9):  # the wrap's ridges
    bpy.ops.mesh.primitive_torus_add(major_segments=12, minor_segments=4, major_radius=0.028, minor_radius=0.006, location=(0, 0, 0.09 + k * 0.055))
    bpy.context.object.data.materials.append(leather)
ball("pommel", 0.045, 0.045, dark)
export("greatblade")

# --- PRO-Class bow -------------------------------------------------------------------------------------------------
reset()
bone = mat("bow_bone", (0.78, 0.72, 0.6), 0.0, 0.55)
steel = mat("bow_steel", (0.35, 0.35, 0.37), 0.9, 0.35)
leather = mat("bow_grip", (0.2, 0.11, 0.06), 0.0, 0.8)
string = mat("bow_string", (0.85, 0.82, 0.7), 0.0, 0.7)
# A recurve in the X-Z plane: the limbs sweep back toward the string (+X), the tips curl forward again.
H = 0.74


def limb_x(z):
    u = abs(z) / H
    return 0.16 * (1.0 - math.cos(math.pi * min(1.0, u / 0.85))) * 0.5 - 0.05 * max(0.0, (u - 0.85) / 0.15) ** 2


bm = bmesh.new()
rings = []
N = 32
for i in range(N + 1):
    z = -H + 2 * H * i / N
    x = limb_x(z)
    w = 0.035 * (1.0 - 0.55 * abs(z) / H) + 0.012
    t = 0.022 * (1.0 - 0.5 * abs(z) / H) + 0.008
    rings.append([bm.verts.new((x + dx * t, dy * w, z)) for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
for a, b in zip(rings, rings[1:]):
    for j in range(4):
        bm.faces.new((a[j], a[(j + 1) % 4], b[(j + 1) % 4], b[j]))
bm.faces.new(list(reversed(rings[0])))
bm.faces.new(rings[-1])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
obj_from_bm("limbs", bm, [bone])
cyl("grip", 0.03, -0.09, 0.09, leather)
for z in (-0.12, 0.12):
    o = cyl("band", 0.028, z - 0.012, z + 0.012, steel)
    o.location.x = limb_x(z)
tip_x = limb_x(H) - 0.01
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.003, depth=2 * H - 0.02, location=(tip_x - 0.0, 0, 0))
o = bpy.context.object
o.data.materials.append(string)
export("pro_bow")
