"""Megaloceros rig: a Tripo body + a hand-built deer skeleton (3-joint legs with real carpus/hock/fetlock, a jaw)
and, for the stag, palmate antlers modelled here and skinned 100 % to Head.

  Blender -b -P tools/gait/megaloceros/build_rig.py -- <tripo.glb> <variant.json> <out.blend> <out_base.glb>

Coordinates: Blender, head to -Y, left = +X, hooves at z=0, game metres (the GLB needs no further scale).
Landmarks (variant.json) are in the prepped mesh's raw units; leg joints below the belly are cross-section
centroids at the listed heights. Weights are geometric (inverse distance to bone segments, side-gated legs, the
body preferred over the upper legs above the belly, the lower jaw split by a line through the mouth corner):
bone heat fails on Tripo meshes (not watertight).
"""
import bpy, bmesh, json, math, sys
import numpy as np
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index("--") + 1:]
SRC, CFG, OUT_BLEND, OUT_GLB = a[:4]
cfg = json.load(open(CFG))
S = cfg["withers_m"] / cfg["withers_raw"]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
body = [o for o in bpy.data.objects if o.type == "MESH"][0]
body.name = body.data.name = "MegalocerosHide"  # not "Body": the glTF importer would rename the Body bone to Body_2

# ---------------------------------------------------------------- 1. clean, orient, ground (raw units)
bm = bmesh.new(); bm.from_mesh(body.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
bm.verts.ensure_lookup_table()
seen, shells = set(), []
for v in bm.verts:
    if v.index in seen: continue
    st, comp = [v], []; seen.add(v.index)
    while st:
        x = st.pop(); comp.append(x)
        for e in x.link_edges:
            y = e.other_vert(x)
            if y.index not in seen: seen.add(y.index); st.append(y)
    shells.append(comp)
shells.sort(key=len, reverse=True)
kill = [v for c in shells[1:] if len(c) < 0.01 * len(bm.verts) for v in c]
bmesh.ops.delete(bm, geom=kill, context="VERTS")
rot = Matrix.Rotation(-math.pi / 2, 4, "Z")  # Tripo faces +X; the rig faces -Y
bm.transform(rot)
zmin = min(v.co.z for v in bm.verts)
for v in bm.verts: v.co.z -= zmin
if cfg.get("deflap"):
    # the doe mesh carries a flat card behind its left front leg: cut faces further behind the leg's front edge
    # than the leg is deep (deeper allowance up where the forearm thickens)
    tab = sorted(cfg["deflap_front"])
    def front(z):
        for (z0, y0), (z1, y1) in zip(tab, tab[1:]):
            if z0 <= z <= z1: return y0 + (y1 - y0) * (z - z0) / (z1 - z0)
        return tab[0][1] if z < tab[0][0] else tab[-1][1]
    def depth(z): return 0.036 if z < 0.212 else 0.06 if z < 0.235 else 0.075
    flap = [f for f in bm.faces if (lambda c: c.x > 0 and 0.065 < c.z < 0.285 and c.y < -0.04 and c.y > front(c.z) + depth(c.z))(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=flap, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    print("deflap faces", len(flap))
bm.to_mesh(body.data); bm.free()
body.matrix_world = Matrix.Identity(4)
print("shells removed", len(kill))

# ---------------------------------------------------------------- 2. leg sections (raw units)
def section(z, sx, front_leg):
    bm = bmesh.new(); bm.from_mesh(body.data)
    r = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, z), plane_no=(0, 0, 1))
    pts = [g.co.copy() for g in r["geom_cut"] if isinstance(g, bmesh.types.BMVert)]
    bm.free()
    ym = cfg["ymid"]
    s = [p for p in pts if p.x * sx > 0 and ((p.y < ym) if front_leg else (p.y >= ym))]
    return sum(s, Vector()) / len(s)

J = {}  # joint name -> raw position
F, H = cfg["front"], cfg["hind"]
for sd, sx in (("L", 1), ("R", -1)):
    fet = section(F["fetlock_z"], sx, True); car = section(F["carpus_z"], sx, True)
    fet.y += 0.006
    J["FrontFet." + sd] = fet; J["FrontCarpus." + sd] = car
    J["FrontToe." + sd] = Vector((fet.x, fet.y - F["toe_fwd"], 0.012))
    elbow = Vector((car.x * 0.95, car.y + F["elbow_back"], F["elbow_dz"]))
    J["FrontElbow." + sd] = elbow
    J["FrontShoulder." + sd] = Vector((car.x * 0.9, elbow.y - F["shoulder_fwd"], F["shoulder_z"]))
    J["FrontScap." + sd] = Vector((sx * F["scap_x"], J["FrontShoulder." + sd].y + F["scap_back"], F["scap_top_z"]))
    hfet = section(H["fetlock_z"], sx, False); hock = section(H["hock_z"], sx, False)
    hfet.y += 0.006; hock.y += H["hock_back"]
    J["HindFet." + sd] = hfet; J["HindHock." + sd] = hock
    J["HindToe." + sd] = Vector((hfet.x, hfet.y - H["toe_fwd"], 0.012))
    J["HindStifle." + sd] = Vector((hock.x * 1.05, hock.y - H["stifle_fwd"], H["stifle_z"]))
    J["HindHip." + sd] = Vector((sx * H["hip_x"], H["hip"][0], H["hip"][1]))
for k, v in J.items(): print(f"  {k:18s} ({v.x:+.3f},{v.y:+.3f},{v.z:+.3f})")

# ---------------------------------------------------------------- 3. scale to game metres
body.data.transform(Matrix.Scale(S, 4))
for k in J: J[k] = J[k] * S
def P(y, z, x=0.0): return Vector((x, y, z)) * S

arm_data = bpy.data.armatures.new("Armature")
arm = bpy.data.objects.new("Armature", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_data.edit_bones
XW = Vector((1, 0, 0))

def bone(name, head, tail, parent=None, deform=True, connect=False):
    b = eb.new(name); b.head = head; b.tail = tail
    d = (tail - head).normalized()
    zt = XW.cross(d)
    if zt.length < 1e-4: zt = Vector((0, 0, 1))
    b.align_roll(zt)  # local X = the body's left (+X) on every sagittal bone: hinge axis [1,0,0]
    if parent: b.parent = eb[parent]; b.use_connect = connect
    b.use_deform = deform
    return b

bz = cfg["body_z"]
bone("root", Vector((0, 0, 0)), Vector((0, 0, 0.3 * S)), deform=False)
bone("Body", P(cfg["torso_y"], bz), P(cfg["torso_y"] - 0.08, bz), "root", deform=False)
bone("Hips", P(cfg["torso_y"], bz), P(cfg["hips_y"], bz), "Body")
bone("Torso", P(cfg["torso_y"], bz), P(cfg["chest_y"], bz), "Body")
ce = cfg["chest_end"]
bone("Shoulders", P(cfg["chest_y"], bz), P(ce[0], ce[1]), "Torso", connect=True)
n = cfg["neck"]
bone("Neck", P(*n[0]), P(*n[1]), "Shoulders")
bone("Neck2", P(*n[1]), P(*n[2]), "Neck", connect=True)
bone("Head", P(*n[2]), P(*cfg["head_tip"]), "Neck2", connect=True)
jw = cfg["jaw"]
bone("Jaw", P(*jw["pivot"]), P(*jw["tip"]), "Head")
t = cfg["tail"]
bone("Tail1", P(*t[0]), P(*t[1]), "Hips")
bone("Tail2", P(*t[1]), P(*t[2]), "Tail1", connect=True)
for sd in ("L", "R"):
    bone("FrontScapula." + sd, J["FrontScap." + sd], J["FrontShoulder." + sd], "Shoulders")
    bone("FrontUpper." + sd, J["FrontShoulder." + sd], J["FrontElbow." + sd], "FrontScapula." + sd, connect=True)
    bone("FrontLower." + sd, J["FrontElbow." + sd], J["FrontCarpus." + sd], "FrontUpper." + sd, connect=True)
    bone("FrontCannon." + sd, J["FrontCarpus." + sd], J["FrontFet." + sd], "FrontLower." + sd, connect=True)
    bone("FrontFoot." + sd, J["FrontFet." + sd], J["FrontToe." + sd], "FrontCannon." + sd, connect=True)
    bone("HindUpper." + sd, J["HindHip." + sd], J["HindStifle." + sd], "Hips")
    bone("HindLower." + sd, J["HindStifle." + sd], J["HindHock." + sd], "HindUpper." + sd, connect=True)
    bone("HindCannon." + sd, J["HindHock." + sd], J["HindFet." + sd], "HindLower." + sd, connect=True)
    bone("BackFoot." + sd, J["HindFet." + sd], J["HindToe." + sd], "HindCannon." + sd, connect=True)
segs = {b.name: (b.head.copy(), b.tail.copy()) for b in eb if b.use_deform}
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------- 4. weights
V = np.array([v.co[:] for v in body.data.vertices])
names = list(segs)
A_ = np.array([segs[k][0][:] for k in names]); B_ = np.array([segs[k][1][:] for k in names])
def seg_dist(P, A, B):
    ab = B - A; t = np.clip(((P[:, None, :] - A[None]) * ab[None]).sum(-1) / (ab * ab).sum(-1)[None], 0, 1)
    return np.linalg.norm(P[:, None, :] - (A[None] + t[..., None] * ab[None]), axis=-1)
D = seg_dist(V, A_, B_)
belly = 0.29 * S
mid = 0.015 * S
for i, k in enumerate(names):
    side = k[-1] if k[-2] == "." else ""
    if side == "L": D[V[:, 0] < -mid, i] = np.inf
    if side == "R": D[V[:, 0] > mid, i] = np.inf
    body_bone = k in ("Hips", "Torso", "Shoulders", "Neck", "Tail1", "Tail2", "Neck2", "Head")
    if body_bone:
        D[:, i] *= np.where(V[:, 2] > belly, 0.6, 1.0)  # the trunk owns its own flank above the belly
        D[V[:, 2] < belly - 0.03 * S, i] = np.inf  # and never a leg
    if k == "Jaw":
        D[:, i] = np.inf
# jaw: head skin forward of the corner and below the split line through the pivot
piv = Vector((0, jw["pivot"][0], jw["pivot"][1])) * S
ang = math.radians(jw["split_deg"])  # the split line through the pivot, tilted down toward the snout tip
nrm = Vector((0, -math.sin(ang), -math.cos(ang)))  # its normal, pointing down: below the line is positive
blend = jw["blend"] * S
ih, ij = names.index("Head"), names.index("Jaw")
W = 1.0 / np.maximum(D, 1e-4) ** 4
W[~np.isfinite(D)] = 0
order = np.argsort(-W, axis=1)[:, :3]
Wk = np.take_along_axis(W, order, 1); Wk /= Wk.sum(1, keepdims=True)
Wk[Wk < 0.04] = 0; Wk /= Wk.sum(1, keepdims=True)
for i, v in enumerate(V):
    pv = Vector(v)
    if abs(pv.x) > 0.09 * S: continue
    along = (pv - piv).dot(Vector((0, -1, 0)))
    below = (pv - piv).dot(nrm)
    head_w = sum(Wk[i, j] for j in range(3) if order[i, j] == ih)
    if head_w < 0.3 or below <= 0: continue
    f = min(1.0, max(0.0, (along + blend) / (2 * blend))) * min(1.0, below / (0.004 * S))
    if f <= 0: continue
    for j in range(3):
        if order[i, j] == ih: Wk[i, j] *= (1 - f)
    # put the jaw share in the weakest slot
    j = int(np.argmin(Wk[i])); Wk[i, j] = 0; order[i, j] = ij; Wk[i, j] = head_w * f
    Wk[i] /= Wk[i].sum()
groups = {k: body.vertex_groups.new(name=k) for k in names}
for i in range(len(V)):
    for j in range(3):
        if Wk[i, j] > 0: groups[names[order[i, j]]].add([i], float(Wk[i, j]), "REPLACE")
body.parent = arm
body.modifiers.new("Armature", "ARMATURE").object = arm
print("weighted", len(V), "verts; jaw verts", sum(1 for i in range(len(V)) if ij in order[i] and Wk[i][list(order[i]).index(ij)] > 0.5))

# ---------------------------------------------------------------- 5. antlers (stag)
def antler_texture():
    img = bpy.data.images.new("megaloceros_antler", 256, 64)
    px = np.zeros((64, 256, 4))
    u = np.linspace(0, 1, 256)
    base, midc, tip = np.array([0.22, 0.15, 0.09]), np.array([0.50, 0.39, 0.26]), np.array([0.88, 0.83, 0.71])
    col = np.where(u[:, None] < 0.45, base + (midc - base) * (u[:, None] / 0.45), midc + (tip - midc) * ((u[:, None] - 0.45) / 0.55))
    rng = np.random.default_rng(7)
    streak = rng.normal(0, 0.035, (64, 1)) + rng.normal(0, 0.02, (64, 256))
    px[..., :3] = np.clip(col[None, :, :] * (1 + streak[..., None]), 0, 1)
    px[..., 3] = 1
    img.pixels = px.ravel(); img.pack()
    mat = bpy.data.materials.new("Antler"); mat.use_nodes = True
    nt = mat.node_tree; bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.62
    return mat

def tube(bm, uvl, pts, radii, us, ring=8):
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a1 = d.orthogonal().normalized(); a2 = d.cross(a1)
        rings.append([bm.verts.new(p + (a1 * math.cos(2 * math.pi * k / ring) + a2 * math.sin(2 * math.pi * k / ring)) * radii[i]) for k in range(ring)])
    for i in range(len(rings) - 1):
        for k in range(ring):
            f = bm.faces.new((rings[i][k], rings[i][(k + 1) % ring], rings[i + 1][(k + 1) % ring], rings[i + 1][k]))
            for lp, uu in zip(f.loops, (us[i], us[i], us[i + 1], us[i + 1])): lp[uvl].uv = (uu, 0.5)
    tipv = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1] * 1.5)
    for k in range(ring):
        f = bm.faces.new((rings[-1][k], rings[-1][(k + 1) % ring], tipv))
        for lp in f.loops: lp[uvl].uv = (min(1.0, us[-1] + 0.02), 0.5)

def bez(p0, p1, p2, n):
    return [p0 * (1 - t) ** 2 + p1 * 2 * t * (1 - t) + p2 * t * t for t in (i / (n - 1) for i in range(n))]

def build_antler(sx):
    """One palmate antler in the animal frame (metres from its pedicle; +X out for sx=1): a short beam out, up
    and back, a brow tine forward, then a broad cupped palm reaching ~2.4 m out with tines along its rim."""
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new("UVMap")
    X = lambda x, y, z: Vector((x * sx, y, z))
    beam = bez(X(0, 0, -0.05), X(0.34, 0.06, 0.16), X(0.74, 0.20, 0.27), 7)
    tube(bm, uvl, beam, [0.13, 0.12, 0.115, 0.11, 0.105, 0.10, 0.10], [0.05 * i for i in range(7)], 10)
    brow = bez(X(0.14, 0.0, 0.12), X(0.30, -0.35, 0.18), X(0.40, -0.62, 0.42), 6)
    tube(bm, uvl, brow, [0.07, 0.06, 0.05, 0.04, 0.025, 0.012], [0.2, 0.4, 0.55, 0.7, 0.85, 1.0], 8)
    # palm: grid over (u along, v across), centreline from the beam end outward, up and back
    U = X(1.0, 0.38, 0.16).normalized()
    Vraw = Vector((0, 1.0, 0.65)); Vd = (Vraw - U * U.dot(Vraw)).normalized()
    N = U.cross(Vd).normalized()
    if N.z < 0: N = -N
    L = 1.95; nu, nv = 18, 9
    base = beam[-1] - Vd * 0.05
    def width(u): return 0.26 + 0.8 * math.sin(min(u, 0.92) / 0.92 * math.pi * 0.62) - 0.35 * max(0.0, u - 0.8) / 0.2
    def pt(u, v):
        w = width(u); c = base + U * (L * u) + N * (0.18 * u * u)  # the palm rises toward its end
        return c + Vd * ((v - 0.5) * w) - N * (0.22 * w * (v - 0.5) ** 2) * 1.0  # cupped: the rims curl down
    top, bot = [], []
    for side_off, store in ((0.028, top), (-0.028, bot)):
        store.extend([[bm.verts.new(pt(i / (nu - 1), j / (nv - 1)) + N * side_off) for j in range(nv)] for i in range(nu)])
    def quad(vs, uvs, flip):
        f = bm.faces.new(vs[::-1] if flip else vs)
        for lp, uu in zip(f.loops, uvs[::-1] if flip else uvs): lp[uvl].uv = (uu, 0.5)
    for i in range(nu - 1):
        for j in range(nv - 1):
            us = [0.3 + 0.45 * i / (nu - 1), 0.3 + 0.45 * i / (nu - 1), 0.3 + 0.45 * (i + 1) / (nu - 1), 0.3 + 0.45 * (i + 1) / (nu - 1)]
            quad([top[i][j], top[i][j + 1], top[i + 1][j + 1], top[i + 1][j]], us, sx < 0)
            quad([bot[i][j], bot[i][j + 1], bot[i + 1][j + 1], bot[i + 1][j]], us, sx > 0)
    rim = [(i, 0) for i in range(nu)] + [(nu - 1, j) for j in range(nv)] + [(i, nv - 1) for i in range(nu - 1, -1, -1)] + [(0, j) for j in range(nv - 1, -1, -1)]
    for (i0, j0), (i1, j1) in zip(rim, rim[1:]):
        if (i0, j0) == (i1, j1): continue
        uu = 0.3 + 0.45 * i0 / (nu - 1)
        quad([top[i0][j0], top[i1][j1], bot[i1][j1], bot[i0][j0]], [uu] * 4, sx < 0)
    # tines: along the back/upper rim (v=1) and round the end, curving up; two on the front rim
    # tines fan out from the palm's middle like fingers and curl up at the tips; the long ones on the back rim
    tines = [(0.22, 1.0, 0.50), (0.36, 1.0, 0.72), (0.50, 1.0, 0.86), (0.63, 1.0, 0.92), (0.75, 1.0, 0.88),
             (0.86, 0.95, 0.82), (0.95, 0.78, 0.76), (1.0, 0.52, 0.70), (0.97, 0.25, 0.62), (0.88, 0.04, 0.55),
             (0.72, 0.0, 0.46), (0.55, 0.0, 0.36)]
    hub = pt(0.42, 0.5)
    up = Vector((0, 0, 1))
    for k, (u, v, ln) in enumerate(tines):
        p0 = pt(u, v)
        rad = (p0 - hub); rad -= N * rad.dot(N); rad.normalize()
        d1 = (rad + up * 0.25).normalized(); d2 = (rad * 0.45 + up).normalized()
        ln *= 1.0 + 0.12 * math.sin(k * 2.3)
        pts = bez(p0 - rad * 0.08, p0 + d1 * ln * 0.6, p0 + d1 * ln * 0.6 + d2 * ln * 0.5, 6)
        tube(bm, uvl, pts, [0.075, 0.062, 0.048, 0.034, 0.02, 0.008], [0.62, 0.72, 0.8, 0.88, 0.95, 1.0], 7)
    me = bpy.data.meshes.new("Antler" + ("L" if sx > 0 else "R")); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    return me

if "antlers" in cfg:
    mat = antler_texture()
    ped = Vector(cfg["antlers"]["pedicle"]) * S
    bm_all = bmesh.new()
    for sx in (1, -1):
        me = build_antler(sx)
        me.transform(Matrix.Translation(Vector((ped.x * sx, ped.y, ped.z))))
        bm_all.from_mesh(me)
    me = bpy.data.meshes.new("Antlers"); bm_all.to_mesh(me); bm_all.free()
    me.materials.append(mat)
    for p in me.polygons: p.use_smooth = True
    ant = bpy.data.objects.new("Antlers", me); bpy.context.scene.collection.objects.link(ant)
    ant.parent = arm
    g = ant.vertex_groups.new(name="Head"); g.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ant.modifiers.new("Armature", "ARMATURE").object = arm
    xs = [v.co.x for v in me.vertices]
    print(f"antlers {len(me.vertices)} verts, span {max(xs) - min(xs):.2f} m, top {max(v.co.z for v in me.vertices):.2f} m")

bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects: o.select_set(o.type in ("MESH", "ARMATURE"))
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_animations=False,
    export_skins=True, export_yup=True, export_image_format="AUTO", export_materials="EXPORT")
zs = [v.co.z for v in body.data.vertices]; ys = [v.co.y for v in body.data.vertices]
print(f"BUILT {OUT_GLB}: body height {max(zs):.2f} m, length {max(ys) - min(ys):.2f} m, scale {S:.3f}")
