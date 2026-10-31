"""Megaloceros rig: a Tripo body + a hand-built deer skeleton (3-joint legs with real carpus/hock/fetlock, a jaw)
and, for the stag, the Tripo antler rack (antlers_tripo.glb, MEGANTLERS) seated on the skull and skinned 100 % to Head.

  Blender -b -P tools/gait/megaloceros/build_rig.py -- <tripo.glb> <variant.json> <out.blend> <out_base.glb>

Coordinates: Blender, head to -Y, left = +X, hooves at z=0, game metres (the GLB needs no further scale).
Landmarks (variant.json) are in the prepped mesh's raw units; leg joints below the belly are cross-section
centroids at the listed heights. Weights are geometric (inverse distance to bone segments, side-gated legs, the
body preferred over the upper legs above the belly, the lower jaw split by a line through the mouth corner):
bone heat fails on Tripo meshes (not watertight).
"""
import bpy, bmesh, json, math, os, sys
import numpy as np
from mathutils import Vector, Matrix, Quaternion

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
    if any(t in k for t in ("Lower", "Cannon", "Foot.")):  # forearm/shin and below: never the chest or flank above the joint
        D[V[:, 2] > segs[k][0].z + 0.02 * S, i] = np.inf
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
# dense weights, then: (1) cut the webbing Tripo leaves between the two forelegs / hindlegs (faces whose corners
# belong to opposite legs: they stretch a metre the moment the legs part), (2) a few neighbour-averaging passes so the
# flank-to-thigh and chest-to-forearm folds blend instead of switching bone across one short edge (check_megaloceros
# stretch gate). The head and jaw keep their hard split (a smoothed lip line opens a crack).
Wd = np.zeros((len(V), len(names)))
np.put_along_axis(Wd, order, Wk, 1)
dom = Wd.argmax(1)
side_of = np.array([(k[-1] if k[-2] == "." else "") for k in names])
leg_of = np.array([("Front" in k or "Hind" in k or "Foot" in k) for k in names])
bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
web = [f for f in bm.faces if len({side_of[dom[v.index]] for v in f.verts if leg_of[dom[v.index]]} - {""}) > 1]
bmesh.ops.delete(bm, geom=web, context="FACES_ONLY")
print("webbing faces cut", len(web))
bm.to_mesh(body.data); bm.free()
E = np.array([e.vertices[:] for e in body.data.edges])
deg = np.bincount(E.ravel(), minlength=len(V)).astype(float)
headish = (Wd[:, ih] + Wd[:, ij]) > 0.3
for _ in range(6):
    acc = np.zeros_like(Wd); np.add.at(acc, E[:, 0], Wd[E[:, 1]]); np.add.at(acc, E[:, 1], Wd[E[:, 0]])
    nb = acc / np.maximum(deg, 1)[:, None]
    new = 0.5 * Wd + 0.5 * nb
    new[headish] = Wd[headish]; new[deg == 0] = Wd[deg == 0]
    new[np.ix_(V[:, 0] < -mid, side_of == "L")] = 0; new[np.ix_(V[:, 0] > mid, side_of == "R")] = 0  # no leg pulls the far side
    # groin and brisket between the legs ride the trunk: leg weights fade out from |x| 0.14 m to 0.06 m
    taper = np.where(V[:, 2] > 0.25 * S, np.clip((np.abs(V[:, 0]) - 0.06) / 0.08, 0, 1), 1.0)
    new[:, leg_of] *= taper[:, None]
    empty = new.sum(1) <= 1e-9  # a masked vertex with only leg weights goes to its nearest trunk bone
    if empty.any():
        trunk = [names.index(k) for k in ("Hips", "Torso", "Shoulders", "Neck")]
        new[np.where(empty)[0], np.array(trunk)[D[np.ix_(empty, trunk)].argmin(1)]] = 1.0
    Wd = new / np.maximum(new.sum(1, keepdims=True), 1e-9)
order = np.argsort(-Wd, axis=1)[:, :4]
Wk = np.take_along_axis(Wd, order, 1); Wk[Wk < 0.03] = 0; Wk /= np.maximum(Wk.sum(1, keepdims=True), 1e-9)
groups = {k: body.vertex_groups.new(name=k) for k in names}
for i in range(len(V)):
    for j in range(4):
        if Wk[i, j] > 0: groups[names[order[i, j]]].add([i], float(Wk[i, j]), "REPLACE")
body.parent = arm
body.modifiers.new("Armature", "ARMATURE").object = arm
print("weighted", len(V), "verts; jaw verts", sum(1 for i in range(len(V)) if ij in order[i] and Wk[i][list(order[i]).index(ij)] > 0.5))

# ---------------------------------------------------------------- 5. antlers (stag)
def tripo_antlers(ac):
    """MEGANTLERS: the Tripo rack (antler_prep.py output, cut open under each burr). Each side is bent by
    pitch/roll about its burr along the beam, the pair scaled so the tips span span_m, each burr centre put at seat_m (x mirrored).
    The open cut under each burr is extruded down into the skull to pedicle_m as a pedicle wearing the stag's own
    hide (its material and a hide texel from the skull beside it), and the burr base is baked toward the hide colour
    over fade_m above the cut, so bone grows out of fur instead of sitting on it."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(os.path.dirname(CFG), ac["mesh"]))
    ob = next(o for o in set(bpy.data.objects) - before if o.type == "MESH")
    burr = {1: Vector(ob["burr_l"]), -1: Vector(ob["burr_r"])}
    for o in set(bpy.data.objects) - before - {ob}: bpy.data.objects.remove(o, do_unlink=True)
    ob.parent = None; ob.matrix_world = Matrix.Identity(4); ob.name = "Antlers"; me = ob.data
    seat = {sx: Vector((ac["seat_m"][0] * sx, *ac["seat_m"][1:])) for sx in (1, -1)}
    pin = {sx: Vector((ac["pedicle_m"][0] * sx, *ac["pedicle_m"][1:])) for sx in (1, -1)}
    turn = {sx: (Matrix.Rotation(math.radians(ac["roll_deg"][0 if sx > 0 else 1]) * sx, 3, "Y") @ Matrix.Rotation(math.radians(-ac["pitch_deg"]), 3, "X")).to_quaternion() for sx in (1, -1)}
    side = [1 if v.co.x > 0 else -1 for v in me.vertices]
    # the turn bends in along the beam (bend_raw: from, to; raw rack units from the burr), so the burr keeps the
    # seat Tripo gave it on the skull while the rack leans back
    b0, b1 = ac["bend_raw"]
    def bent(p, sx):
        t = min(max((p.length - b0) / (b1 - b0), 0.0), 1.0)
        return Quaternion().slerp(turn[sx], t * t * (3 - 2 * t)) @ p
    loc = [bent(v.co - burr[sx], sx) for v, sx in zip(me.vertices, side)]
    reach = max(p.x for p, sx in zip(loc, side) if sx > 0) - min(p.x for p, sx in zip(loc, side) if sx < 0)
    k = (ac["span_m"] - 2 * ac["seat_m"][0]) / reach
    for v, p, sx in zip(me.vertices, loc, side): v.co = p * k + seat[sx]
    # fade: 1 at the cut, 0 at fade_m along the beam (its direction: the cut centre to the points 0.5-0.8 m out)
    fade = {}
    for sx in (1, -1):
        mid = [v.co for v, s_ in zip(me.vertices, side) if s_ == sx and 0.5 < (v.co - seat[sx]).length < 0.8]
        ax = (sum(mid, Vector()) / len(mid) - seat[sx]).normalized()
        for v, s_ in zip(me.vertices, side):
            if s_ == sx: fade[v.index] = max(0.0, 1.0 - max(0.0, (v.co - seat[sx]).dot(ax)) / ac["fade_m"]) ** 2
    attr_l = me.attributes.new("hide_fade", "FLOAT", "POINT")
    for i, f in fade.items(): attr_l.data[i].value = f
    # bake: the antler colour mixed toward the mean hide colour round the seat by that fade
    nt = me.materials[0].node_tree
    col = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image.name.startswith("Color"))
    himg = next(n for n in body.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE" and "Color" in n.image.name).image
    hw, hh = himg.size; hpx = np.array(himg.pixels[:], np.float32).reshape(hh, hw, 4)
    huv = body.data.uv_layers.active.data
    near = [li for poly in body.data.polygons if (poly.center - seat[1]).length < 0.45 for li in poly.loop_indices]
    hide = np.mean([hpx[min(hh - 1, int(huv[li].uv[1] * hh)), min(hw - 1, int(huv[li].uv[0] * hw)), :3] for li in near], 0) ** 2.2  # sRGB texels -> linear
    baked = bpy.data.images.new("megaloceros_antler", *col.image.size)
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"
    attr = nt.nodes.new("ShaderNodeAttribute"); attr.attribute_name = "hide_fade"
    emit = nt.nodes.new("ShaderNodeEmission"); out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    bsdf_link = out.inputs["Surface"].links[0].from_socket
    nt.links.new(attr.outputs["Fac"], mix.inputs["Factor"]); nt.links.new(col.outputs["Color"], mix.inputs[6])
    mix.inputs[7].default_value = (*hide, 1.0)
    nt.links.new(mix.outputs[2], emit.inputs["Color"]); nt.links.new(emit.outputs[0], out.inputs["Surface"])
    target = nt.nodes.new("ShaderNodeTexImage"); target.image = baked; nt.nodes.active = target
    sc = bpy.context.scene; sc.render.engine = "CYCLES"; sc.cycles.samples = 1; sc.cycles.device = "CPU"
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.bake(type="EMIT", margin=4)
    baked.pack()
    nt.links.new(bsdf_link, out.inputs["Surface"])
    nt.links.new(target.outputs["Color"], next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"])
    for n in (mix, attr, emit, col): nt.nodes.remove(n)
    me.attributes.remove(me.attributes["hide_fade"])
    # pedicles: each cut rim extruded to a smaller ring inside the skull, closed, in the hide material
    me.materials.append(body.data.materials[0])
    from mathutils.kdtree import KDTree
    kd = KDTree(len(body.data.vertices))
    for v in body.data.vertices: kd.insert(v.co, v.index)
    kd.balance()
    vuv = {}
    for l in body.data.loops: vuv.setdefault(l.vertex_index, huv[l.index].uv.copy())
    bm = bmesh.new(); bm.from_mesh(me); uvl = bm.loops.layers.uv.active
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)  # the glTF import splits vertices along UV seams; only the cuts stay open
    for sx in (1, -1):
        rim = [e for e in bm.edges if e.is_boundary and sx * e.verts[0].co.x > 0 and (e.verts[0].co - seat[sx]).length < 1.0]
        ring = {v for e in rim for v in e.verts}; c = sum((v.co for v in ring), Vector()) / len(ring)
        print(f"pedicle {sx:+d}: rim {len(rim)} edges, burr centre {tuple(round(x, 2) for x in c)}")
        new = bmesh.ops.extrude_edge_only(bm, edges=rim)["geom"]
        nv = [g for g in new if isinstance(g, bmesh.types.BMVert)]
        for v in nv: v.co = pin[sx] + (v.co - c) * ac["pedicle_shrink"]
        faces = [g for g in new if isinstance(g, bmesh.types.BMFace)]
        skin = vuv[kd.find(Vector((0, pin[sx].y - 0.05, pin[sx].z + 0.3)))[1]]  # one texel of the crown's fur: per-vertex nearest UVs streak, the ears are pale
        faces += bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary and sx * e.verts[0].co.x > 0 and (e.verts[0].co - pin[sx]).length < 0.6], sides=0)["faces"]
        for f in faces:
            f.material_index = 1
            for l in f.loops: l[uvl].uv = skin
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    print(f"tripo antlers: scale {k:.2f}, hide rgb {np.round(hide, 3)}")
    return ob

if "antlers" in cfg:
    ant = tripo_antlers(cfg["antlers"]); me = ant.data
    for p in me.polygons: p.use_smooth = True
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
