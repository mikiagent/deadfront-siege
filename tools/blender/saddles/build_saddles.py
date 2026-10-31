"""Riding saddles for the rideable tames, in the T. rex howdah's style family but sized to the animal.

One shared builder driven by a per-species config (tools/blender/saddles/saddles.json). For a species it
imports the game's own GLB, measures the hide with raycasts, then builds:

  * a leather seat that follows the animal's back (pad, cushion, pommel, cantle, skirts),
  * a girth strap round the barrel with buckles,
  * stirrups under the rider's feet,
  * hand reins from the pommel to the rider's fists, and a neck strap with leads to the pommel.

Seat/straps/girth/stirrups are weighted to the socket (the back bone behind the shoulders); the neck strap
and its leads to Neck, blending to the socket at the pommel. So the saddle follows every clip.

Writes game/assets/creatures/<species>/mount/mount.json (socket, saddle, rider_offset, seat, notes) and
exports mount/saddle.glb. rider_in_mount is added afterwards by mount_to_model_space.py (build.sh does it).

  Blender -b --factory-startup -P tools/blender/saddles/build_saddles.py -- \
      --species=protoceratops --height=1.6 --preview=/tmp/saddles-preview
"""
import bpy
import bmesh
import json
import math
import os
import sys
from mathutils import Matrix, Vector

ARGS = {}
for _a in sys.argv[sys.argv.index("--") + 1:]:
    if _a.startswith("--"):
        _k, _, _v = _a[2:].partition("=")
        ARGS[_k] = _v if _v != "" else "1"

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SPECIES = ARGS["species"]
CONFIG = json.load(open(os.path.join(REPO, "tools/blender/saddles/saddles.json")))
CFG = dict(CONFIG.get("defaults", {}))
CFG.update(CONFIG.get("species", {}).get(SPECIES, {}))
GLB = ARGS.get("glb") or os.path.join(REPO, "game/assets/creatures/%s/%s.glb" % (SPECIES, SPECIES))
OUT_DIR = ARGS.get("out-dir") or os.path.join(REPO, "game/assets/creatures/%s/mount" % SPECIES)  # --glb/--out-dir: a body variant (megaloceros doe)
HEIGHT = float(ARGS.get("height", CFG.get("height_meters", 1.0)))
PREVIEW = ARGS.get("preview", "")

bpy.ops.wm.read_homefile(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.import_scene.gltf(filepath=GLB)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == "ARMATURE")
creature = max((o for o in sc.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))  # not the importer's bone-shape Icosphere
for _o in list(sc.objects):
    if _o.type == "MESH" and _o is not creature:
        bpy.data.objects.remove(_o, do_unlink=True)
# Everything below assumes the animal faces -Y in Blender (glTF +Z, the transplant rigs). A rig that faces +Y
# (glTF -Z: the Tripo/Opus triceratops) is turned 180 deg about Z for the build and turned back before binding,
# so the saddle mesh and rider_offset come out in the GLB's own frame (rider_offset then carries the 180 deg turn).
TURN = Matrix.Rotation(math.pi, 4, "Z") if CFG.get("forward", "-Y") == "+Y" else Matrix.Identity(4)
arm.matrix_world = TURN @ arm.matrix_world
arm.data.pose_position = "REST"
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
ev = creature.evaluated_get(dg)
M = ev.matrix_world
_em = ev.to_mesh()
VERTS = [M @ v.co for v in _em.vertices]
ev.to_mesh_clear()
MN = Vector([min(v[i] for v in VERTS) for i in range(3)])
MX = Vector([max(v[i] for v in VERTS) for i in range(3)])
SRC_H = MX.z - MN.z
K = HEIGHT / SRC_H                      # game metres per source unit
SCALE = 1.0 / K                         # game metres -> source units
BONES = {b.name: (arm.matrix_world @ b.head_local) for b in arm.data.bones}


def bone(name):
    return BONES[name]


def ray(origin, direction, dist=100.0):
    ok, loc, _n, _i = ev.ray_cast(M.inverted() @ origin, (M.inverted().to_3x3() @ direction).normalized(), distance=dist)
    return (M @ loc) if ok else None


def top_z(x, y):
    p = ray(Vector((x, y, MX.z + 2.0)), Vector((0, 0, -1)))
    return p.z if p else None


def side_x(y, z, sgn=1.0):
    p = ray(Vector((sgn * (MX.x + 2.0), y, z)), Vector((-sgn, 0, 0)))
    return abs(p.x) if p else None


# ------------------------------------------------------------------ placement
# The transplant rigs share one donor skeleton: Hips -> Torso -> Shoulders -> Neck -> Head, so the seat
# sits on the back bone just behind the shoulders. The T. rex uses its own Spine2; these use Torso.
SOCKET = CFG.get("socket", "Torso")
if SOCKET not in BONES:
    SOCKET = "Back"
HIPS_Y = bone("Hips").y
SHO_BONE = CFG.get("shoulder_bone", "Shoulders" if "Shoulders" in BONES else "Neck")
SHO_Y = bone(SHO_BONE).y
SEAT_FRAC = float(CFG.get("seat_frac", 0.55))
SEAT_Y = HIPS_Y + (SHO_Y - HIPS_Y) * SEAT_FRAC
TORSO_LEN = abs(SHO_Y - HIPS_Y)
SEAT_HALF_LEN = max(float(CFG.get("seat_half_len_m", 0.25)) * SCALE, TORSO_LEN * float(CFG.get("torso_len_frac", 0.5)))
SEAT_HALF_W = float(CFG.get("seat_half_w_m", 0.24)) * SCALE
CUSHION = float(CFG.get("cushion_m", 0.05)) * SCALE
PAD = float(CFG.get("pad_m", 0.022)) * SCALE
LIFT = float(CFG.get("lift_m", 0.004)) * SCALE

# probe_x_m: probe the back this far off the midline (the woolly rhino's Tripo hide has a slit along the spine)
BACK_Z = top_z(float(CFG.get("probe_x_m", 0.0)) * SCALE, SEAT_Y)
if BACK_Z is None:
    raise SystemExit("no back surface at the seat")
body_hw = side_x(SEAT_Y, BACK_Z * 0.9) or SEAT_HALF_W
SEAT_HALF_W = min(SEAT_HALF_W, body_hw * 0.95)
SEAT_TOP = BACK_Z + LIFT + CUSHION
# survivor v2 mount_idle, measured on the posed rig: hips 0.581 m above the armature root, feet 0.098,
# hands at (+-0.203, -0.091, 0.846), forward = -Y in Blender space.
RIDER_HIPS_M, RIDER_FEET_M = 0.581, 0.098
RIDER_HAND = Vector((0.203, -0.091, 0.846))
# Seat the rider so the hips end up RIDER_HIP_GAP above the cushion; the root hangs the rest below it.
RIDER_HIP_GAP_M = 0.10
RIDER_ROOT = Vector((0.0, SEAT_Y, SEAT_TOP + (RIDER_HIP_GAP_M - RIDER_HIPS_M) / K))
FOOT_X = abs(RIDER_HAND.x) * SCALE
FEET_Z = RIDER_ROOT.z + RIDER_FEET_M * SCALE
# the feet sit further forward than the hands in mount_idle, so the stirrups hang where the boots are
FEET_Y = RIDER_ROOT.y - 0.156 * SCALE
HANDS = {"L": RIDER_ROOT + Vector((RIDER_HAND.x, RIDER_HAND.y, RIDER_HAND.z)) * SCALE,
         "R": RIDER_ROOT + Vector((-RIDER_HAND.x, RIDER_HAND.y, RIDER_HAND.z)) * SCALE}
print("[saddle] %s socket=%s K=%.3f seat_y=%.3f back_z=%.3f seat_top=%.3f hl=%.3f hw=%.3f hw_body=%.3f rider_root=%s" % (
    SPECIES, SOCKET, K, SEAT_Y, BACK_Z, SEAT_TOP, SEAT_HALF_LEN, SEAT_HALF_W, body_hw,
    [round(x, 3) for x in RIDER_ROOT]))


def mat(name, color, rough=0.65, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*color, 1)
    return m


LEATHER = mat("saddle_leather", (0.155, 0.068, 0.030), 0.55)
LEATHER_D = mat("saddle_leather_dark", (0.085, 0.038, 0.017), 0.62)
BONE = mat("saddle_bone", (0.55, 0.45, 0.27), 0.38)
IRON = mat("saddle_iron", (0.055, 0.055, 0.065), 0.32, 0.9)

PARTS = []          # (object, spec) spec = ("rigid", bone) | ("per", list[dict bone->w])


def add(ob, material, spec):
    ob.data.materials.clear()
    ob.data.materials.append(material)
    PARTS.append((ob, spec))
    return ob


def rigid(ob, material, bone_name):
    return add(ob, material, ("rigid", bone_name))


def finish(ob, spec):
    """Write the part's weights as vertex groups now, so join() merges them by name."""
    groups = {}
    if spec[0] == "rigid":
        groups[spec[1]] = [(i, 1.0) for i in range(len(ob.data.vertices))]
    else:
        for i, wd in enumerate(spec[1]):
            tot = sum(wd.values()) or 1.0
            for bn, w in wd.items():
                groups.setdefault(bn, []).append((i, w / tot))
    for bn, pairs in groups.items():
        vg = ob.vertex_groups.new(name=bn)
        for i, w in pairs:
            vg.add([i], w, "REPLACE")


def poly_weights(pairs):
    """Weight function for a strap: smooth blend along the polyline between (bone, t) knots."""
    def w(t):
        if len(pairs) == 1:
            return {pairs[0][0]: 1.0}
        (b0, t0), (b1, t1) = pairs[0], pairs[1]
        s = 0.0 if t1 == t0 else max(0.0, min(1.0, (t - t0) / (t1 - t0)))
        s = s * s * (3 - 2 * s)
        return {b0: 1.0 - s, b1: s}
    return w


def link(name, points, radius, material, weight_fn, thin=0.45):
    """A flat leather strap along a polyline."""
    me_ = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    n = len(points)
    for i, pt in enumerate(points):
        tang = (points[min(i + 1, n - 1)] - points[max(i - 1, 0)])
        if tang.length < 1e-6:
            tang = Vector((0, 0, 1))
        tang.normalize()
        side = tang.cross(Vector((0, 1, 0)))
        if side.length < 1e-4:
            side = tang.cross(Vector((1, 0, 0)))
        side.normalize()
        up = side.cross(tang).normalized()
        rings.append([bm.verts.new(pt + side * (dx * radius) + up * (dz * radius * thin))
                      for dx, dz in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    for a, b in zip(rings, rings[1:]):
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bm.normal_update()
    bm.to_mesh(me_)
    bm.free()
    ob = bpy.data.objects.new(name, me_)
    sc.collection.objects.link(ob)
    per = []
    for v in ob.data.vertices:
        best, bt = 1e9, 0.0
        for i in range(n - 1):
            a, b = points[i], points[i + 1]
            ab = b - a
            t = 0.0 if ab.length_squared < 1e-12 else max(0.0, min(1.0, (v.co - a).dot(ab) / ab.length_squared))
            d = (a + ab * t - v.co).length
            if d < best:
                best, bt = d, (i + t) / (n - 1)
        per.append(weight_fn(bt))
    return add(ob, material, ("per", per))


def bez(points, n=12):
    out = []
    for i in range(n):
        t = i / (n - 1)
        p = list(points)
        while len(p) > 1:
            p = [a.lerp(b, t) for a, b in zip(p, p[1:])]
        out.append(p[0])
    return out


def box(name, center, size, material, weight_bone, bevel=0.02, rot=(0, 0, 0), segs=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = (max(size[0], 1e-4), max(size[1], 1e-4), max(size[2], 1e-4))
    ob.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        m = ob.modifiers.new("bev", "BEVEL")
        m.width = bevel
        m.segments = segs
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=m.name)
    return rigid(ob, material, weight_bone)


def cyl(name, center, radius, depth, material, weight_bone, rot=(0, 0, 0), verts=16, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=center, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    if bevel:
        m = ob.modifiers.new("bev", "BEVEL")
        m.width = bevel
        m.segments = 2
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.shade_smooth()
    return rigid(ob, material, weight_bone)


def barrel_cz(cy, fallback):
    """Height of the barrel's middle at y = cy, between the back and the belly. A slab's own z-range can include
    the legs (a biped stands under its seat), which drags the centre below the belly: the girth then hung to
    the feet and its buckles floated beside the thighs."""
    top = top_z(0.0, cy)
    if top is not None:
        belly = ray(Vector((0.0, cy, top - 0.002)), Vector((0, 0, -1)))
        if belly is not None and top - belly.z > 0.01:
            return (top + belly.z) * 0.5
    return fallback


def section(cy, n=40):
    """The hide's cross-section in the XZ plane at y = cy: for each direction, cast a ray outward from
    the body's axis (inside the hide) so the hit is the outer surface, never a leg or the far side."""
    half = max((MX.y - MN.y) * 0.015, 0.004)
    pts = [v for v in VERTS if abs(v.y - cy) <= half]
    if not pts:
        return None
    cz = barrel_cz(cy, (min(v.z for v in pts) + max(v.z for v in pts)) * 0.5)
    # the axis point has to be inside the hide; take the slab's central vertex nearest the axis
    centre = min(pts, key=lambda v: (v.x - 0.0) ** 2 + (v.z - cz) ** 2)
    cen = Vector((0.0, cy, cz))
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        d = Vector((math.cos(a), 0, math.sin(a)))
        p = ray(cen + d * 0.005, d)
        if p is None:
            p = Vector((centre.x + math.cos(a) * (MX.x - MN.x) * 0.5, cy,
                        cz + math.sin(a) * (BACK_Z - MN.z) * 0.5))
        out.append((a, math.hypot(p.x - cen.x, p.z - cen.z), cz))
    return out


def strap_ring(name, cy, width, thick, material, weight_bone, N=40, shrink=0.004):
    """A strap that follows the hide's cross-section in the XZ plane at y = cy."""
    sec = section(cy, N)
    if sec is None:
        return None
    me_ = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for a, r, cz in sec:
        nrm = Vector((math.cos(a), 0, math.sin(a)))
        p = Vector((nrm.x * r, cy, cz + nrm.z * r))
        rings.append([bm.verts.new((p.x + nrm.x * dr, cy + dy, p.z + nrm.z * dr))
                      for dy, dr in ((-width / 2, -shrink), (width / 2, -shrink),
                                     (width / 2, thick), (-width / 2, thick))])
    for a, b in zip(rings, rings[1:] + [rings[0]]):
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.normal_update()
    bm.to_mesh(me_)
    bm.free()
    ob = bpy.data.objects.new(name, me_)
    sc.collection.objects.link(ob)
    bpy.ops.object.shade_smooth()
    return rigid(ob, material, weight_bone)


def strap_outer_x(cy, cz, sgn, half=0.01):
    """Outer |x| of the hide in the slab at y = cy, at height cz (for placing buckles on the strap)."""
    pts = [v for v in VERTS if abs(v.y - cy) <= half and abs(v.z - cz) <= (MX.z - MN.z) * 0.04]
    if not pts:
        return None
    return max(sgn * v.x for v in pts)


# ------------------------------------------------------------------ seat
# A sheet that follows the hide: u across the back, down both flanks (capped so it cannot wrap under the
# belly); v from front (+y) to back (-y). It rises into a pommel and a cantle and is dished where the
# rider sits, like the T. rex howdah but with no howdah box.
NX, NY = 21, 19
max_drop = float(CFG.get("skirt_drop_m", 0.26)) * SCALE
verts, faces = [], []
for j in range(NY + 1):
    v = j / NY
    y = SEAT_Y + (0.5 - v) * 2 * SEAT_HALF_LEN
    taper = 1.0 - 0.5 * max(0.0, (0.24 - v) / 0.24) ** 2 - 0.16 * max(0.0, (v - 0.80) / 0.20) ** 2
    for i in range(NX + 1):
        u = (i / NX * 2 - 1) * taper
        x = u * SEAT_HALF_W
        z = top_z(x, y)
        if z is None:
            z = BACK_Z - max_drop * 0.6
        z = max(z, BACK_Z - max_drop)
        z += LIFT
        cz = CUSHION * max(0.0, 1.0 - (u / 0.85) ** 2) * max(0.0, 1.0 - ((v - 0.5) / 0.6) ** 2)
        cz -= 0.04 * CUSHION * max(0.0, 1.0 - (u / 0.4) ** 2) * max(0.0, 1.0 - ((v - 0.5) / 0.3) ** 2)
        z += cz
        centre = (1.0 - abs(u)) ** 2
        if v < 0.36:
            z += 0.34 * CUSHION * math.exp(-((v - 0.03) / 0.09) ** 2) * centre
        if v > 0.64:
            z += 0.40 * CUSHION * math.exp(-((v - 0.97) / 0.08) ** 2) * centre
        verts.append((x, y, z))
for j in range(NY):
    for i in range(NX):
        a = j * (NX + 1) + i
        faces.append((a, a + 1, a + NX + 2, a + NX + 1))
seat_mesh = bpy.data.meshes.new("saddle_seat")
seat_mesh.from_pydata(verts, [], faces)
seat_mesh.update()
seat = bpy.data.objects.new("saddle_seat", seat_mesh)
sc.collection.objects.link(seat)
solid = seat.modifiers.new("solid", "SOLIDIFY")
solid.thickness = float(CFG.get("seat_thick_m", 0.025)) * SCALE
solid.offset = 0.0
bev = seat.modifiers.new("bev", "BEVEL")
bev.width = float(CFG.get("seat_bevel_m", 0.006)) * SCALE
bev.segments = 2
bpy.context.view_layer.objects.active = seat
bpy.ops.object.modifier_apply(modifier=solid.name)
bpy.ops.object.modifier_apply(modifier=bev.name)
bpy.ops.object.shade_smooth()
rigid(seat, LEATHER, SOCKET)

# blanket pad under the seat, draped over the flanks
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, SEAT_Y, BACK_Z - PAD * 0.5))
pad = bpy.context.active_object
pad.name = "saddle_pad"
pw, pl = SEAT_HALF_W * 1.1, SEAT_HALF_LEN * 1.12
pad.scale = (pw, pl, PAD)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.subdivide(number_cuts=5)
bpy.ops.object.mode_set(mode="OBJECT")
for vv in pad.data.vertices:
    x, y, z = vv.co
    vv.co.z -= (abs(x) / pw) ** 2 * PAD * 2.2 + (abs(y) / pl) ** 2 * PAD * 0.5
m = pad.modifiers.new("bev", "BEVEL")
m.width = float(CFG.get("seat_bevel_m", 0.006)) * SCALE
m.segments = 2
bpy.context.view_layer.objects.active = pad
bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.object.shade_smooth()
rigid(pad, LEATHER_D, SOCKET)

# skirts: thin leather panels hanging down both flanks, so it reads as a saddle at a distance
SKIRT = float(CFG.get("skirt_m", 0.09)) * SCALE
for sgn, nm in ((1, "L"), (-1, "R")):
    zc = SEAT_TOP - SEAT_HALF_W * 0.30
    surf = side_x(SEAT_Y, zc, sgn) or (SEAT_HALF_W * 0.9)
    x0 = sgn * max(SEAT_HALF_W * 0.86, surf + 0.008 * SCALE)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x0, SEAT_Y, zc - SKIRT * 0.40))
    sk = bpy.context.active_object
    sk.name = "skirt_%s" % nm
    sk.scale = (0.012 * SCALE + 0.006 * SCALE, SEAT_HALF_LEN * 0.82, SKIRT * 0.85)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for vv in sk.data.vertices:
        if vv.co.z < 0:
            vv.co.z -= SKIRT * 0.30 * (1 - abs(vv.co.y) / (SEAT_HALF_LEN * 0.82))
    m = sk.modifiers.new("bev", "BEVEL")
    m.width = float(CFG.get("seat_bevel_m", 0.006)) * SCALE
    m.segments = 2
    bpy.context.view_layer.objects.active = sk
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.shade_smooth()
    rigid(sk, LEATHER, SOCKET)

# bones: pommel horn at the front, cantle roll at the back (same family as the howdah)
HORN_Y = SEAT_Y - SEAT_HALF_LEN * 0.84
HORN_Z = SEAT_TOP + CUSHION * 0.4
box("horn_stem", (0, HORN_Y, HORN_Z + 0.04 * SCALE), (0.045 * SCALE, 0.045 * SCALE, 0.09 * SCALE),
    LEATHER, SOCKET, bevel=0.012 * SCALE)
cyl("horn_knob", (0, HORN_Y, HORN_Z + 0.11 * SCALE), 0.055 * SCALE, 0.065 * SCALE, BONE, SOCKET,
    bevel=0.016 * SCALE)
CANTLE_Y = SEAT_Y + SEAT_HALF_LEN * 0.90
box("cantle_lip", (0, CANTLE_Y, SEAT_TOP + 0.025 * SCALE),
    (SEAT_HALF_W * 1.0, 0.035 * SCALE, 0.075 * SCALE), LEATHER, SOCKET,
    bevel=0.014 * SCALE, rot=(math.radians(12), 0, 0))
cyl("cantle_roll", (0, CANTLE_Y + 0.008 * SCALE, SEAT_TOP + 0.07 * SCALE), 0.022 * SCALE,
    SEAT_HALF_W * 2.0, BONE, SOCKET, rot=(0, math.radians(90), 0), verts=14, bevel=0.007 * SCALE)

# ------------------------------------------------------------------ girth
GSEL = [v for v in VERTS if abs(v.y - SEAT_Y) < (MX.y - MN.y) * 0.02]
if GSEL:
    gzmin, gzmax = max(MN.z, min(v.z for v in GSEL)), max(v.z for v in GSEL)
else:
    gzmin, gzmax = MN.z, BACK_Z
GCZ = barrel_cz(SEAT_Y, (gzmin + gzmax) * 0.5)
GW = float(CFG.get("girth_width_m", 0.08)) * SCALE
strap_ring("girth", SEAT_Y, GW, float(CFG.get("girth_thick_m", 0.025)) * SCALE, LEATHER_D, SOCKET)
GSEC = section(SEAT_Y)
for sgn, nm in ((1, "L"), (-1, "R")):
    # on the strap itself (its radius at the side), not on the widest hide at that height: folded wing
    # feathers stick out past the girth and left the buckles floating beside the body
    bx = (GSEC[0][1] if sgn > 0 else GSEC[len(GSEC) // 2][1]) if GSEC else strap_outer_x(SEAT_Y, GCZ, sgn)
    if bx is None:
        bx = body_hw
    box("buckle_%s" % nm, (sgn * (bx + 0.012 * SCALE), SEAT_Y, GSEC[0][2] if GSEC else GCZ),
        (0.03 * SCALE, 0.055 * SCALE, 0.07 * SCALE), IRON, SOCKET, bevel=0.007 * SCALE)

# ------------------------------------------------------------------ stirrups
BOOT_HALF = 0.075
STIRRUPS = {}
for sgn, nm in ((1, "L"), (-1, "R")):
    # The iron hangs just outside the boot; if the flank there is wider than the rider's stance the iron
    # moves out to the hide and the boot rests against its inner side, rather than inside the animal.
    surf = side_x(FEET_Y, FEET_Z, sgn) or 0.0
    # keep the iron out of the hide at the boot's own height, not only at the flank's widest point
    hide_at_foot = top_z(FOOT_X, FEET_Y)
    x_iron = max(FOOT_X + BOOT_HALF * SCALE, surf + 0.02 * SCALE)
    if hide_at_foot is not None and hide_at_foot > FEET_Z + BOOT_HALF * SCALE:
        x_iron = max(x_iron, (side_x(FEET_Y, hide_at_foot - 0.01 * SCALE, sgn) or surf) + 0.02 * SCALE)
    STIRRUPS[nm] = Vector((sgn * x_iron, FEET_Y, FEET_Z))
    # a short iron bar out of the tree, then the stirrup leather down to the iron
    top_x = min(SEAT_HALF_W * 0.9, x_iron - 0.02 * SCALE)
    box("stirrup_bar_%s" % nm, (sgn * (top_x + x_iron) * 0.5, FEET_Y, SEAT_TOP - 0.015 * SCALE),
        (max(0.02 * SCALE, x_iron - top_x), 0.026 * SCALE, 0.016 * SCALE), IRON, SOCKET,
        bevel=0.006 * SCALE)
    ztop = FEET_Z + 0.12 * SCALE
    zbot = SEAT_TOP - 0.01 * SCALE
    box("stirrup_leather_%s" % nm, (sgn * (x_iron + top_x) * 0.5, FEET_Y, (ztop + zbot) * 0.5),
        (0.024 * SCALE, 0.04 * SCALE, max(0.02 * SCALE, zbot - ztop)), LEATHER_D, SOCKET,
        bevel=0.006 * SCALE, rot=(0, math.radians(-sgn * 10), 0))
    box("stirrup_tread_%s" % nm, (sgn * x_iron, FEET_Y, FEET_Z - 0.011 * SCALE),
        (0.16 * SCALE, 0.13 * SCALE, 0.022 * SCALE), IRON, SOCKET, bevel=0.007 * SCALE)
    for dy, tag in ((0.058 * SCALE, "f"), (-0.058 * SCALE, "b")):
        box("stirrup_side_%s_%s" % (nm, tag), (sgn * x_iron, FEET_Y + dy, FEET_Z + 0.05 * SCALE),
            (0.022 * SCALE, 0.02 * SCALE, 0.15 * SCALE), IRON, SOCKET, bevel=0.006 * SCALE)
    box("stirrup_yoke_%s" % nm, (sgn * x_iron, FEET_Y, FEET_Z + 0.12 * SCALE),
        (0.022 * SCALE, 0.14 * SCALE, 0.022 * SCALE), IRON, SOCKET, bevel=0.006 * SCALE)

# ------------------------------------------------------------------ neck strap
NECK_BONE = CFG.get("neck_bone", "Neck" if "Neck" in BONES else SOCKET)
NECK_Y = (bone(NECK_BONE).y + SHO_Y) * 0.5 if "neck_y_frac" not in CFG else \
    bone(NECK_BONE).y + (SHO_Y - bone(NECK_BONE).y) * float(CFG["neck_y_frac"])
NSEL = [v for v in VERTS if abs(v.y - NECK_Y) < (MX.y - MN.y) * 0.02]
if NSEL:
    nzmin, nzmax = max(MN.z, min(v.z for v in NSEL)), max(v.z for v in NSEL)
else:
    nzmin, nzmax = MN.z, top_z(0.0, NECK_Y) or BACK_Z
NCZ = (nzmin + nzmax) * 0.5
strap_ring("neck_strap", NECK_Y, float(CFG.get("girth_width_m", 0.08)) * 0.75 * SCALE,
           float(CFG.get("girth_thick_m", 0.025)) * 0.75 * SCALE, LEATHER_D, NECK_BONE, N=24)

# ------------------------------------------------------------------ reins
REIN_R = 0.010 * SCALE
ANCHOR = {"L": Vector((0.045 * SCALE, HORN_Y + 0.008 * SCALE, HORN_Z + 0.085 * SCALE)),
          "R": Vector((-0.045 * SCALE, HORN_Y + 0.008 * SCALE, HORN_Z + 0.085 * SCALE))}
for side in ("L", "R"):
    hand = HANDS[side]
    sgn = 1 if side == "L" else -1
    a = ANCHOR[side]
    end = hand + Vector((0, 0, 0.02 * SCALE))
    ctrl = [a, a + (end - a) * 0.35 + Vector((0, 0, 0.05 * SCALE)),
            a + (end - a) * 0.72 + Vector((0, 0, 0.03 * SCALE)), end]
    link("rein_%s" % side, bez(ctrl, 10), REIN_R, LEATHER, lambda t: {SOCKET: 1.0})
    box("rein_buckle_%s" % side, a, (0.026 * SCALE, 0.026 * SCALE, 0.026 * SCALE), IRON, SOCKET,
        bevel=0.006 * SCALE)
    # a bone grip bar across the closed fist
    axis = Vector((sgn * 0.49, -0.04, 0.87)).normalized()
    cyl("rein_grip_%s" % side, hand, 0.011 * SCALE, 0.09 * SCALE, BONE, SOCKET,
        rot=axis.to_track_quat("Z", "Y").to_euler(), verts=10, bevel=0.003 * SCALE)
    # the lead: from the side of the neck strap down to the pommel; Neck at the neck end, socket at the horn
    sx = strap_outer_x(NECK_Y, NCZ, sgn, half=0.02) or (body_hw * 0.5)
    start = Vector((sgn * (sx + 0.008 * SCALE), NECK_Y, NCZ))
    ctrl = [start, start + (a - start) * 0.4 + Vector((0, 0, -0.03 * SCALE)),
            start + (a - start) * 0.75 + Vector((0, 0, -0.01 * SCALE)), a]
    link("lead_%s" % side, bez(ctrl, 12), REIN_R * 1.1, LEATHER,
         poly_weights([(NECK_BONE, 0.0), (SOCKET, 1.0)]))

# ------------------------------------------------------------------ join, weight, bind
for _ob, _spec in PARTS:
    _b = [_ob.matrix_world @ Vector(c) for c in _ob.bound_box]
    print("[part] %-20s %s..%s" % (_ob.name, [round(min(v[i] for v in _b), 3) for i in range(3)],
                                   [round(max(v[i] for v in _b), 3) for i in range(3)]))
for ob, spec in PARTS:
    finish(ob, spec)
bpy.ops.object.select_all(action="DESELECT")
for p, _spec in PARTS:
    p.select_set(True)
bpy.context.view_layer.objects.active = PARTS[0][0]
bpy.ops.object.join()
saddle = bpy.context.active_object
saddle.name = "saddle"
for o in list(sc.objects):
    if o.type == "MESH" and o is not saddle and o is not creature:
        bpy.data.objects.remove(o, do_unlink=True)

bpy.ops.object.select_all(action="DESELECT")
saddle.select_set(True)
bpy.context.view_layer.objects.active = saddle
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# rider_offset in the socket bone's frame is the same in the turned frame and the GLB's own one
OFF = (arm.matrix_world @ arm.data.bones[SOCKET].matrix_local).inverted() @ Matrix.Translation(RIDER_ROOT)
saddle.data.transform(TURN.inverted())
arm.matrix_world = TURN.inverted() @ arm.matrix_world
bpy.context.view_layer.update()
saddle.parent = arm
saddle.parent_type = "OBJECT"
saddle.matrix_parent_inverse = Matrix.Identity(4)
mod = saddle.modifiers.new("Armature", "ARMATURE")
mod.object = arm
bpy.context.view_layer.update()

bb = [Vector(c) for c in saddle.bound_box]
smin = [min(v[i] for v in bb) for i in range(3)]
smax = [max(v[i] for v in bb) for i in range(3)]
tris = sum(len(p.vertices) - 2 for p in saddle.data.polygons)
print("[saddle] tris=%d verts=%d groups=%s bounds=%s..%s" % (
    tris, len(saddle.data.vertices), [g.name for g in saddle.vertex_groups],
    [round(x, 3) for x in smin], [round(x, 3) for x in smax]))

# ------------------------------------------------------------------ mount.json
# rider_offset: the rider root in the socket bone's frame, as Blender imports it (reference only; the game
# uses rider_in_mount, which mount_to_model_space.py derives from it against the game's own GLB).
# These species face +Z in glTF (the survivor does too), which is -Y in Blender after the import's Y-up
# conversion, and the rider's own forward is -Y as well, so the root needs no turn (the T. rex howdah's
# 180 deg exists because its model faces -Z).
os.makedirs(OUT_DIR, exist_ok=True)
mj = {
    "mount": SPECIES,
    "saddle": "saddle.glb",
    "socket": SOCKET,
    "rider_offset": [OFF[r][c] for c in range(4) for r in range(4)],
    "seat": {"y": round(SEAT_Y, 4), "top": round(SEAT_TOP, 4), "half_len": round(SEAT_HALF_LEN, 4),
             "half_w": round(SEAT_HALF_W, 4), "back_z": round(BACK_Z, 4)},
    # hips above the socket bone at rest, in game metres: what the mount lab checks the rider against (it is
    # clip-invariant, unlike an absolute height, because the rider follows the socket bone).
    "hips_above_socket_m": round((RIDER_ROOT.z + RIDER_HIPS_M / K - bone(SOCKET).z) * K, 4),
    "seat_above_socket_m": round((SEAT_TOP - bone(SOCKET).z) * K, 4),
    "stirrups": {k: [round(x, 4) for x in v] for k, v in STIRRUPS.items()},
    "scale": {"height_meters": HEIGHT, "source_height_m": round(SRC_H, 4), "game_m_per_source": round(K, 5)},
    "notes": ("seat and straps are skinned to %s (the back just behind the shoulders), the neck strap and "
              "its leads blend to Neck; rider_offset is the rider armature root relative to %s in Blender's "
              "imported bone frame, column-major; rider_in_mount (added by mount_to_model_space.py) is the "
              "same pose in the mount's glTF model space and is what the game uses" % (SOCKET, SOCKET)),
}
json.dump(mj, open(os.path.join(OUT_DIR, "mount.json"), "w"), indent=1)

# ------------------------------------------------------------------ export
arm.data.pose_position = "REST"
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
saddle.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(
    filepath=os.path.join(OUT_DIR, "saddle.glb"), export_format="GLB",
    use_selection=True, use_active_scene=True, export_animations=False,
    export_skins=True, export_rest_position_armature=True, export_apply=False,
    export_yup=True, export_materials="EXPORT", export_anim_single_armature=True)
arm.data.pose_position = "POSE"
print("[saddle] exported %s (%d bytes)" % (os.path.join(OUT_DIR, "saddle.glb"),
                                           os.path.getsize(os.path.join(OUT_DIR, "saddle.glb"))))

# ------------------------------------------------------------------ preview
if PREVIEW:
    os.makedirs(PREVIEW, exist_ok=True)
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.render.resolution_x, sc.render.resolution_y = 900, 700
    sc.render.film_transparent = False
    arm.data.pose_position = "POSE"
    bpy.ops.mesh.primitive_plane_add(size=100, location=(0, 0, MN.z - 0.001))
    arm.data.pose_position = "POSE"
    ctr = Vector((0, SEAT_Y, BACK_Z))
    for label, loc in (("side", Vector((3.2, SEAT_Y, BACK_Z + 0.3))),
                       ("iso", Vector((2.2, SEAT_Y + 2.4, BACK_Z + 1.8))),
                       ("front", Vector((0.05, SEAT_Y - 3.4, BACK_Z + 0.8)))):
        cam_data = bpy.data.cameras.new("cam_" + label)
        cam = bpy.data.objects.new("cam_" + label, cam_data)
        sc.collection.objects.link(cam)
        cam.location = loc
        d = ctr - loc
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = 50
        sc.camera = cam
        sc.render.filepath = os.path.join(PREVIEW, "%s_%s.png" % (SPECIES, label))
        bpy.ops.render.render(write_still=True)
    print("[saddle] preview in %s" % PREVIEW)
