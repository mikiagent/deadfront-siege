#!/usr/bin/env python3
"""Add a Jaw bone to a rig that has none (Meshy auto-rig species) and give it the lower-jaw skin.

The mouth line is measured from the texture: generated creatures paint the shut mouth as a dark seam along the side
of the snout, so a straight line is fitted through the darkest band of each slice. The jaw pivots at the back of that line. Head skin forward of the corner ramps to rigid along the snout (skull to Head,
below the line to Jaw), so the two halves move as bone and blend into the neck at the corner; nothing else changes, so every existing clip still plays. Then run open_mouth.py on the result.

  Blender -b --python tools/jaw/add_jaw.py -- <in.glb> <out.glb> [--head Head] [--debug]
"""
import argparse, sys
import bpy
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument("inp"); ap.add_argument("out")
ap.add_argument("--head", default="Head")
ap.add_argument("--min-head", type=float, default=0.15, help="skin with at least this Head weight is head skin")
ap.add_argument("--slices", type=int, default=24)
ap.add_argument("--lip-z", type=float, default=None, help="set a flat mouth line at this height instead of fitting the texture (beaks with no painted seam)")
ap.add_argument("--chin-depth", type=float, default=None, help="only skin this far below the mouth line (x snout length) is jaw; keeps a long throat or neck off it")
ap.add_argument("--hook", type=float, default=0.0, help="this fraction of the snout behind the tip stays on Head (hooked beaks)")
ap.add_argument("--corner", type=float, default=0.3, help="mouth corner no further back than this fraction of the snout")
ap.add_argument("--open", action="store_true", help="the mesh was modelled with the mouth open: fit the line through the gape (the widest empty band per slice), then close the mouth in the bind pose")
ap.add_argument("--part", type=float, default=3.0, help="with --open: degrees left parted after closing (lips never fuse)")
ap.add_argument("--snout", type=float, default=None, help="snout length from the head joint (mesh units); set it when a nose horn reaches past the beak, or the horn tip is taken for the snout tip")
ap.add_argument("--mid", type=float, default=None, help="with --open: only skin within this x snout length of the midline counts for the gape (frill spikes and cheek horns leave gaps of their own)")
ap.add_argument("--reach", type=float, default=0.35, help="with --open: skin this far (x snout length) above or below the mouth line counts as head even when weighted to the neck")
ap.add_argument("--pivot", type=float, nargs=2, default=None, metavar=("T", "Z"), help="mouth corner by hand: T along the snout from the head joint, Z height (mesh units)")
ap.add_argument("--split", type=float, default=None, help="with --pivot: the jaw/skull boundary is the line through the pivot at this angle (deg, negative = down toward the tip); for wide-open beaked mouths where a straight lip line cuts the beak")
ap.add_argument("--close", type=float, default=None, help="with --open: close the mouth by this many degrees instead of the measured gape minus --part")
ap.add_argument("--blend", type=float, default=0.0, help="jaw skin fades in over +/- this many mesh units around the mouth corner instead of switching there (stops a crack behind the corner when --close is large)")
ap.add_argument("--x-side", action="store_true", help="roll the new Jaw so its local X is the animal's left (+X): positive X opens on every rig. Without it a jaw that points level or up (carnotaurus) came out with X flipped, so --open closed the mouth the wrong way and key_jaw's positive angles shut it")
ap.add_argument("--weld", action="store_true", help="weld the glTF's UV-seam vertex copies on import, so the rigid tooth/lip islands are real islands and coincident copies get the same weights (a split mesh cracks open along every seam at the lips)")
ap.add_argument("--debug", action="store_true")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp, merge_vertices=a.weld)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm), key=lambda o: len(o.data.vertices))
mw, aw = ob.matrix_world, arm.matrix_world
hb = arm.data.bones[a.head]
HI = ob.vertex_groups[a.head].index

# snout direction: from the head joint toward the head skin's far end, flattened to the ground plane
hv = [(v, mw @ v.co, (mw.to_3x3() @ v.normal).normalized()) for v in ob.data.vertices
      if any(g.group == HI and g.weight >= a.min_head for g in v.groups)]
joint = aw @ hb.head_local
far = max(hv, key=lambda t: ((t[1] - joint) * Vector((1, 1, 0))).length)[1]
fwd = (far - joint) * Vector((1, 1, 0)); fwd.normalize()
side = fwd.cross(Vector((0, 0, 1))).normalized()
L = (far - joint).dot(fwd)
if a.snout:
    L = a.snout
    hv = [h for h in hv if (h[1] - joint).dot(fwd) <= 1.05 * L]  # the horn beyond the beak is skull, not mouth
print(f"head skin verts {len(hv)}, snout length {L:.3f} m")

# mouth line: Meshy/Tripo paint the closed mouth as a dark seam (gum and teeth) along the side of the snout.
# Per slice, on the side of the head, find the darkest height band (ignoring the jaw's lower and the skull's upper
# edge), then fit a straight line through those points with one round of outlier rejection.
mat = ob.data.materials[0]
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
img = bsdf.inputs["Base Color"].links[0].from_node.image
W, H = img.size; px = img.pixels[:]
uvd = ob.data.uv_layers.active.data
vuv = {l.vertex_index: uvd[l.index].uv for l in ob.data.loops}
def lum(i):
    u, w = vuv[i]
    k = (int(min(max(w, 0), .9999) * H) * W + int(min(max(u, 0), .9999) * W)) * 4
    return 0.3 * px[k] + 0.6 * px[k + 1] + 0.1 * px[k + 2]
pts_t = []
NB = 10
for k in range(a.slices):
    t0 = L * (0.2 + 0.8 * k / a.slices); t1 = t0 + L * 0.8 / a.slices
    sl = [(p, v.index) for v, p, n in hv if t0 <= (p - joint).dot(fwd) < t1 and abs(n.dot(side)) > 0.3]
    if len(sl) < 8: continue
    zt, zb = max(p.z for p, _ in sl), min(p.z for p, _ in sl)
    bins = [[] for _ in range(NB)]
    for p, i in sl: bins[min(NB - 1, int((p.z - zb) / (zt - zb + 1e-9) * NB))].append(lum(i))
    avg = [sum(x) / len(x) if x else 9 for x in bins]
    j = min(range(1, 7), key=lambda q: avg[q])
    if avg[j] < 8: pts_t.append(((t0 + t1) / 2, zb + (j + 0.5) * (zt - zb) / NB))
def fit(ps):
    n = len(ps); mt = sum(t for t, _ in ps) / n; mz = sum(z for _, z in ps) / n
    b = sum((t - mt) * (z - mz) for t, z in ps) / max(sum((t - mt) ** 2 for t, _ in ps), 1e-9)
    return mz - b * mt, b
gape = []  # --open: (t, top of the lower jaw, bottom of the upper jaw) per slice
if a.open:
    pts_t = []
    for k in range(a.slices):
        t0 = L * (0.3 + 0.65 * k / a.slices); t1 = t0 + L * 0.65 / a.slices
        zs = sorted(p.z for v, p, n in hv if t0 <= (p - joint).dot(fwd) < t1
                    and (a.mid is None or abs((p - joint).dot(side)) < a.mid * L))
        if len(zs) < 8: continue
        g, i = max((zs[i + 1] - zs[i], i) for i in range(len(zs) - 1))
        if g > 0.03 * L:
            gape.append(((t0 + t1) / 2, zs[i], zs[i + 1])); pts_t.append(((t0 + t1) / 2, (zs[i] + zs[i + 1]) / 2))
if len(pts_t) < 4:
    sys.exit(f"mouth line not found ({len(pts_t)} slices); set it by hand")
c0, c1 = fit(pts_t)
res = sorted(abs(z - (c0 + c1 * t)) for t, z in pts_t); cut = 2.5 * res[len(res) // 2] + 1e-4
pts_t = [(t, z) for t, z in pts_t if abs(z - (c0 + c1 * t)) <= cut]
c0, c1 = fit(pts_t)
line = sorted(pts_t)
if a.debug:
    for t, z in line: print(f"  t {t:.3f}  dark z {z:.3f}  fit {c0 + c1 * t:.3f}")
if a.lip_z is not None: c0, c1 = a.lip_z, 0.0
def lip_z(t): return c0 + c1 * t

t_corner, t_tip = max(line[0][0], a.corner * L), L  # a gape that reaches the neck reads as unhinging
if a.pivot:
    import math as _m
    t_corner = a.pivot[0]
    c1 = _m.tan(_m.radians(a.split or 0.0)); c0 = a.pivot[1] - c1 * t_corner
    pivot = joint + fwd * t_corner + Vector((0, 0, a.pivot[1] - joint.z))
else:
    pivot = joint + fwd * t_corner + Vector((0, 0, lip_z(t_corner) - joint.z + 0.02 * L))
pivot -= side * pivot.dot(side) - side * joint.dot(side)  # on the midline
chin = joint + fwd * t_tip + Vector((0, 0, lip_z(t_tip) - joint.z))
chin -= side * chin.dot(side) - side * joint.dot(side)
print(f"mouth line: {len(line)} slices, corner t {t_corner:.3f}, pivot {tuple(round(x, 3) for x in pivot)}")

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones.new("Jaw")
inv = aw.inverted()
eb.head, eb.tail = inv @ pivot, inv @ chin
eb.parent = arm.data.edit_bones[a.head]
eb.roll = 0
if eb.x_axis.dot(inv.to_3x3() @ side) > 0:
    eb.roll = 3.141592653589793  # a +X turn opens the jaw on every rig: local X must point to the animal's left (-side); +Y-facing rigs need the flip
if a.x_side:
    from mathutils import Vector as _V
    eb.align_roll(inv.to_3x3() @ _V((0, 0, -1)))  # Z down, so X = Y x Z = +X (the side axis) for a forward jaw
bpy.ops.object.mode_set(mode="OBJECT")

jaw_g = ob.vertex_groups.get("Jaw") or ob.vertex_groups.new(name="Jaw")
names = {g.index: g.name for g in ob.vertex_groups}
span = 0.3 * (t_tip - t_corner)
moved = 0
for v in ob.data.vertices:
    p = mw @ v.co; t = (p - joint).dot(fwd)
    hg = next((g for g in v.groups if g.group == HI and g.weight > 0), None)
    if a.open and hg is None and t > t_corner + span and abs(p.z - lip_z(t)) < a.reach * L:
        hg = True  # open-mouth meshes: snout skin and teeth weighted to Neck or nothing still belong to the head
    if hg is None or t < t_corner - max(0.02 * L, a.blend): continue
    if a.chin_depth is not None and p.z < lip_z(t) - a.chin_depth * L: continue  # throat and neck stay put
    # Meshy weights the snout about half to Neck, so the whole skull bends with the neck. Ramp both halves of the
    # head to rigid along the snout (skull -> Head, below the mouth line -> Jaw), or a rigid jaw splits off the skull.
    x = min(max((t - t_corner) / span, 0.0), 1.0); w = x * x * (3 - 2 * x)
    jaw = p.z < lip_z(t) and t < t_tip - a.hook * L  # a hooked beak dips below the line but belongs to the skull
    old = {g.group: g.weight for g in v.groups}
    share = old.pop(HI, 0.0)
    for gi, gw in old.items(): ob.vertex_groups[names[gi]].add([v.index], gw * (1 - w), "REPLACE")
    if HI in [g.group for g in v.groups]: ob.vertex_groups[a.head].remove([v.index])
    tot = share * (1 - w) + w
    jw = (lambda y: y * y * (3 - 2 * y))(min(max((t - t_corner + a.blend) / (2 * a.blend), 0.0), 1.0)) if jaw and a.blend > 0 else float(jaw)
    if jw > 0: jaw_g.add([v.index], tot * jw, "REPLACE")
    if jw < 1: ob.vertex_groups[a.head].add([v.index], tot * (1 - jw), "REPLACE")
    moved += jaw
print(f"jaw skin: {moved} verts moved from {a.head} to Jaw")

if a.open:  # close the modelled gape in the bind pose: pose the jaw shut, bake that shape into the mesh
    import math
    import bmesh
    # teeth and other small islands in the snout move as one piece with whichever jaw holds them
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table()
    seen = set(); rigid = 0
    for v0 in bm.verts:
        if v0.index in seen: continue
        isl, st = [], [v0]; seen.add(v0.index)
        while st:
            c = st.pop(); isl.append(c.index)
            for e in c.link_edges:
                o = e.other_vert(c)
                if o.index not in seen: seen.add(o.index); st.append(o)
        if len(isl) > 400: continue
        cen = sum((mw @ ob.data.vertices[i].co for i in isl), Vector()) / len(isl)
        t = (cen - joint).dot(fwd)
        if t < t_corner + span or abs(cen.z - lip_z(t)) > a.reach * L: continue  # the corner's ramp keeps its blended skin
        if a.blend > 0 and min((mw @ ob.data.vertices[i].co - joint).dot(fwd) for i in isl) < t_corner + a.blend:
            continue  # an island reaching back to the corner (a whole lower-jaw shell) keeps the blend, or it cracks off the throat
        tgt = jaw_g if cen.z < lip_z(t) and t < t_tip - a.hook * L else ob.vertex_groups[a.head]
        for g in list(ob.vertex_groups): g.remove(isl)
        tgt.add(isl, 1.0, "REPLACE"); rigid += 1
    bm.free()
    print(f"rigid snout islands (teeth): {rigid}")
    # gape = angle at the pivot between the snout tip and the lower jaw tip, in the side plane
    def ang(p): d = p - pivot; return math.atan2(d.z, d.dot(fwd))
    jaw_pts = [mw @ v.co for v in ob.data.vertices if any(g.group == jaw_g.index and g.weight > 0.9 for g in v.groups)]
    skull_pts = [mw @ v.co for v in ob.data.vertices if any(g.group == HI and g.weight > 0.9 for g in v.groups)]
    skull_pts = [q for q in skull_pts if (q - joint).dot(fwd) <= 1.05 * L]
    lt = max(jaw_pts, key=lambda q: (q - pivot).dot(fwd)); ut = max(skull_pts, key=lambda q: (q - pivot).dot(fwd))
    gape_deg = math.degrees(ang(ut) - ang(lt)) - 6.0  # a shut mouth still has the snout tip a few degrees above the chin
    close = max(0.0, gape_deg - a.part) if a.close is None else a.close
    print(f"open mouth: gape {gape_deg:.1f} deg over {len(gape)} slices, closing {close:.1f} deg")
    pb = arm.pose.bones["Jaw"]; pb.rotation_mode = "XYZ"; pb.rotation_euler.x = -math.radians(close)
    bpy.context.view_layer.update()
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    co = [v.co.copy() for v in ev.to_mesh().vertices]; ev.to_mesh_clear()
    pb.rotation_euler.x = 0.0; bpy.context.view_layer.update()
    for v, c in zip(ob.data.vertices, co): v.co = c

for o in list(bpy.data.objects):
    if o not in (arm, ob) and o.type == "MESH" and o.parent is None: bpy.data.objects.remove(o)  # bone-shape sphere
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", a.out)
