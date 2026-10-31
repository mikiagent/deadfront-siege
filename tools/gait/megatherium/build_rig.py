"""Megatherium rig (SP-WOOLLY_RHINO's mammal rig builder, from SP-MEGALOCEROS's deer rig): a Tripo body + a hand-built
skeleton. The deer leg names are kept so the shared tools read it: front = scapula, upper arm, forearm, FrontCannon (the
hand, wrist -> knuckles: it knuckle-walks) and FrontFoot (knuckles -> the long claws); hind = thigh, shin, HindCannon
(ankle -> ball of the foot, it is plantigrade) and BackFoot (the toes). Three tail bones (the tail is the third leg of
the tripod stance). Marker bones ClawTip.L/R at the fore-claw tips for claw hits.

  Blender -b -P tools/gait/megatherium/build_rig.py -- <tripo.glb> <sloth.json> <out.blend> <out_base.glb>

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
body.name = body.data.name = cfg.get("hide_name", "Hide")  # not "Body": the glTF importer would rename the Body bone to Body_2

# ---------------------------------------------------------------- 1. clean, orient, ground (raw units)
bm = bmesh.new(); bm.from_mesh(body.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
bm.verts.ensure_lookup_table()
rot0 = Matrix.Rotation(-math.pi / 2, 4, "Z"); z0_ = min(v.co.z for v in bm.verts)
for (cy0, cy1), (cz0, cz1), (ax0, ax1) in cfg.get("cut_boxes", []):
    # SLOTH: Tripo grew a thin spike up from each fore-claw (prepped units: y, z, |x| ranges)
    cut = [v for v in bm.verts if (lambda q: cy0 < q.y < cy1 and cz0 < q.z - z0_ < cz1 and ax0 < abs(q.x) < ax1)(rot0 @ v.co)]
    bmesh.ops.delete(bm, geom=cut, context="VERTS"); print("cut verts", len(cut))
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
# RHINO: the Tripo hide has ~65 open holes, several on the spine (they show the sky through the back from the iso
# camera and the saddle builder's ray fell through one): fill them; every filled corner reuses a UV its vertex already
# has, so the patch takes the surrounding fur colour.
uvl = bm.loops.layers.uv.active
# the spine seam: Tripo left the two halves apart along the dorsal midline (slits up to 7 cm): weld its open edge
mid_open = [v for v in bm.verts if abs(v.co.y) < 0.04 and any(e.is_boundary for e in v.link_edges)]
bmesh.ops.remove_doubles(bm, verts=mid_open, dist=0.02)
holes = [e for e in bm.edges if e.is_boundary]
filled = bmesh.ops.holes_fill(bm, edges=holes, sides=cfg.get("fill_sides", 200))["faces"]
for f in filled:
    for lp in f.loops:
        other = next((l for l in lp.vert.link_loops if l.face not in filled), None)
        if other is not None and uvl is not None: lp[uvl].uv = other[uvl].uv
print("holes filled", len(filled), "open edges left", sum(1 for e in bm.edges if e.is_boundary))
# what is still open shows the inside of the far flank instead of the sky: the hide is drawn double-sided
for m in body.data.materials: m.use_backface_culling = False
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
    s = [p for p in pts if p.x * sx > 0 and ((p.y < ym) if front_leg else (ym <= p.y < cfg.get("hind_ymax", 9)))]  # SLOTH: the tail lies on the ground behind the hind feet
    return sum(s, Vector()) / len(s)

J = {}  # joint name -> raw position
F, H = cfg["front"], cfg["hind"]
for sd, sx in (("L", 1), ("R", -1)):
    fet = section(F["fetlock_z"], sx, True); car = section(F["carpus_z"], sx, True)
    fet.y += F.get("fet_dy", 0.006)
    J["FrontFet." + sd] = fet; J["FrontCarpus." + sd] = car
    J["FrontToe." + sd] = Vector((fet.x, fet.y - F["toe_fwd"], F.get("toe_z", 0.012)))
    elbow = Vector((car.x * 0.95, car.y + F["elbow_back"], F["elbow_dz"]))
    J["FrontElbow." + sd] = elbow
    J["FrontShoulder." + sd] = Vector((car.x * 0.9, elbow.y - F["shoulder_fwd"], F["shoulder_z"]))
    J["FrontScap." + sd] = Vector((sx * F["scap_x"], J["FrontShoulder." + sd].y + F["scap_back"], F["scap_top_z"]))
    hfet = section(H["fetlock_z"], sx, False); hock = section(H["hock_z"], sx, False)
    hfet.y += H.get("fet_dy", 0.006); hock.y += H["hock_back"]
    J["HindFet." + sd] = hfet; J["HindHock." + sd] = hock
    J["HindToe." + sd] = Vector((hfet.x, hfet.y - H["toe_fwd"], H.get("toe_z", 0.012)))
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
bone("Tail3", P(*t[2]), P(*t[3]), "Tail2", connect=True)
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
    _cd = (J["FrontToe." + sd] - J["FrontFet." + sd]).normalized()
    bone("ClawTip." + sd, J["FrontToe." + sd], J["FrontToe." + sd] + _cd * 0.02 * S, "FrontFoot." + sd, deform=False)
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
belly = cfg.get("belly_z", 0.29) * S
mid = 0.004 * S
# RHINO: the belly fur hangs below the elbows and stifles between the legs, so "below the belly line = leg" would hand
# the belly skirt to the legs (it tore 20x when they swung). A leg bone only takes skin inside its own fore-aft span
# (+- leg_margin); outside every leg span the trunk owns everything down to the skirt's hem.
LEGM = cfg.get("leg_margin", 0.06) * S
legzone = np.zeros(len(V), bool)
for i, k in enumerate(names):
    if "Front" in k or "Hind" in k or "Foot" in k:
        lo = min(segs[k][0].y, segs[k][1].y) - LEGM; hi = max(segs[k][0].y, segs[k][1].y) + LEGM
        out = (V[:, 1] < lo) | (V[:, 1] > hi)
        D[out, i] = np.inf
        legzone |= ~out & ("Scapula" not in k)
        # SLOTH: the belly hangs low between the legs; its midline is never a leg's (it tore 16x as the legs walked)
        inner = (np.abs(V[:, 0]) < cfg.get("leg_inner_x", 0.0) * S) & (V[:, 2] > cfg.get("leg_inner_z", 0.0) * S)
        D[inner, i] = np.inf; legzone &= ~inner
for i, k in enumerate(names):
    side = k[-1] if k[-2] == "." else ""
    if side == "L": D[V[:, 0] < -mid, i] = np.inf
    if side == "R": D[V[:, 0] > mid, i] = np.inf
    body_bone = k in ("Hips", "Torso", "Shoulders", "Neck", "Tail1", "Tail2", "Tail3", "Neck2", "Head")
    if body_bone:
        D[:, i] *= np.where(V[:, 2] > belly, cfg.get("trunk_pref", 0.6), 1.0)  # the trunk owns its own flank above the belly
        D[(V[:, 2] < belly - 0.03 * S) & legzone, i] = np.inf  # and never a leg
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
# dense weights, then: (1) cut the webbing Tripo leaves between the two forelegs / hindlegs (faces whose corners
# belong to opposite legs: they stretch a metre the moment the legs part), (2) a few neighbour-averaging passes so the
# flank-to-thigh and chest-to-forearm folds blend instead of switching bone across one short edge. The head and jaw keep
# their hard split (a smoothed lip line opens a crack). (SP-MEGALOCEROS's weighting.)
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
for _ in range(4):
    acc = np.zeros_like(Wd); np.add.at(acc, E[:, 0], Wd[E[:, 1]]); np.add.at(acc, E[:, 1], Wd[E[:, 0]])
    nb = acc / np.maximum(deg, 1)[:, None]
    new = 0.5 * Wd + 0.5 * nb
    new[headish] = Wd[headish]; new[deg == 0] = Wd[deg == 0]
    new[np.ix_(V[:, 0] < -mid, side_of == "L")] = 0; new[np.ix_(V[:, 0] > mid, side_of == "R")] = 0  # no leg pulls the far side
    Wd = new / np.maximum(new.sum(1, keepdims=True), 1e-9)
# SLOTH: skin below the ankle / wrist rides the foot / hand only (a heel half on the shin dug 0.3 m into the ground
# when the shin leaned in the upright advance)
for sd in ("L", "R"):
    for low_z, upper, foot in ((H["hock_z"] * S, ("HindLower." + sd, "HindUpper." + sd), "HindCannon." + sd),
                               (F["carpus_z"] * S, ("FrontLower." + sd, "FrontUpper." + sd), "FrontCannon." + sd)):
        sel = V[:, 2] < low_z
        fi = names.index(foot)
        for u in upper:
            ui = names.index(u); Wd[sel, fi] += Wd[sel, ui]; Wd[sel, ui] = 0
order = np.argsort(-Wd, axis=1)[:, :4]
Wk = np.take_along_axis(Wd, order, 1); Wk[Wk < 0.03] = 0; Wk /= np.maximum(Wk.sum(1, keepdims=True), 1e-9)
groups = {k: body.vertex_groups.new(name=k) for k in names}
for i in range(len(V)):
    for j in range(4):
        if Wk[i, j] > 0: groups[names[order[i, j]]].add([i], float(Wk[i, j]), "REPLACE")
body.parent = arm
body.modifiers.new("Armature", "ARMATURE").object = arm
print("weighted", len(V), "verts; jaw verts", int((Wd[:, ij] > 0.5).sum()))

bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.object.select_all(action="DESELECT")
for o in bpy.data.objects: o.select_set(o.type in ("MESH", "ARMATURE"))
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, export_animations=False,
    export_skins=True, export_yup=True, export_image_format="AUTO", export_materials="EXPORT")
zs = [v.co.z for v in body.data.vertices]; ys = [v.co.y for v in body.data.vertices]
print(f"BUILT {OUT_GLB}: body height {max(zs):.2f} m, length {max(ys) - min(ys):.2f} m, scale {S:.3f}")
