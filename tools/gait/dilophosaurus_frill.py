"""Build the dilophosaurus' neck frill in Blender: separate thin membrane geometry on its own rib bones, folded flat
along the neck at rest, flared open by the clips (make_dilo_moves.py).

Why (SP-DILOPHOSAURUS 2026-10-31): the owner's sheets draw a wide, paper-thin frill. A thin membrane is a Tripo risk
(it comes back as a lump or with holes), so Tripo modelled the body WITHOUT it (Codex drew frill-less views) and the
frill is made here:
- 7 rib bones a side (Frill1-7.L/R) on Neck2, rooted on an arc round the side of the neck behind the skull. Open, the
  ribs fan out sideways from above the crest line to under the throat (the sheet's collar); folded, they lie back
  along the neck as a narrow ruff. The rest pose is FOLDED, so clips that never key the ribs (the gaits) keep it shut.
- The membrane is a polar grid between the ribs with a serrated rim, two-sided (a back copy 1.5 mm behind, flipped),
  weighted to its two neighbouring ribs by angle, so folding the ribs pleats it.
- It joins the body mesh and shares its one material: the body UVs are squeezed into the top 80 % of the atlas and the
  frill paint (yellow cells, red veins, dark serrated rim; the alpha's fiery orange in dilophosaurus_alpha_skin.py)
  fills the bottom strip. ORM and normal maps are padded neutral. One material keeps model_variants.alpha a plain
  albedo swap.
- Writes <out json>: per rib, the armature-space rotation from folded to open (about the rib's head), which
  make_dilo_moves.py applies relative to the posed Neck2 (frill 0..1).

usage: Blender -b -P tools/gait/dilophosaurus_frill.py -- <in.glb> <out.glb> <ribs.json>
       Blender -b -P tools/gait/dilophosaurus_frill.py -- --paint <regular|alpha> <out.png>   (just the strip)
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

STRIP = 0.2  # bottom fraction of the atlas that holds the frill paint
N_RIBS = 7
PHI = (math.radians(80), math.radians(-72))  # open fan: from up-and-out to down-and-out (left side, about +x)
CENTRE = Vector((0.0, -0.373, 0.258))  # neck axis point behind the skull (Neck2), mesh units
NECK_R = (0.022, 0.03)  # base arc half-width (x) and half-height (z) round the neck
RADIUS = 0.12  # rib length at the fan's middle
CUP = math.radians(28)  # open, each half-fan turns its outer edge forward round the head (the sheets' side view shows its face)
TEETH = 26
# The model's origin (the Creature's capsule centre, the brain's reach centre) moves forward from the bbox centre to
# mid-torso: the whip tail is half the length, so the bbox centre sat 1.5 m behind the hips and the snout 5.3 m ahead of
# the origin, out of every contact reach (2.7 m). At y = -0.2 the snout is 3.2 m ahead and the bite lands.
ORIGIN_Y = -0.2


def paint(kind, W=2048, H=512, seed=7):
    """The frill membrane: u across the fan (top -> bottom), v from the neck (0) to the rim (1)."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:H, 0:W]
    u, v = xs / (W - 1), ys / (H - 1)
    cols, rows = 26, 9
    sx = (np.arange(cols)[None, :] + 0.5 + rng.uniform(-0.35, 0.35, (rows, cols))) / cols
    sy = (np.arange(rows)[:, None] + 0.5 + rng.uniform(-0.35, 0.35, (rows, cols))) / rows
    sx, sy = sx.ravel(), sy.ravel()
    d1 = np.full((H, W), 9.0)
    d2 = np.full((H, W), 9.0)
    near = np.zeros((H, W), int)
    for i in range(sx.size):
        dx = (u - sx[i]) * cols
        dy = (v - sy[i]) * rows * 0.8  # cells a little longer radially
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        near = np.where(closer, i, near)
        d1 = np.where(closer, d, d1)
    edge = d2 - d1  # 0 on a vein
    centre = np.clip(d1 / 0.6, 0, 1)
    jitter = rng.uniform(-1, 1, sx.size)[near]
    if kind == "alpha":
        core, fill, vein, rim, base = (1.0, 0.84, 0.3), (0.95, 0.5, 0.1), (0.5, 0.09, 0.04), (0.3, 0.07, 0.03), (0.4, 0.36, 0.18)
        vein_w = 0.16
    else:
        core, fill, vein, rim, base = (0.98, 0.86, 0.36), (0.9, 0.7, 0.22), (0.78, 0.14, 0.09), (0.13, 0.15, 0.07), (0.45, 0.42, 0.22)
        vein_w = 0.12
    img = np.empty((H, W, 3))
    for c in range(3):
        cell = core[c] + (fill[c] - core[c]) * centre + 0.05 * jitter
        # the paint darkens towards the rim and warms towards the neck like the sheets' gradient
        cell = cell * (1.0 - 0.18 * np.clip((v - 0.55) / 0.35, 0, 1))
        k = np.clip(1.0 - edge / vein_w, 0, 1) ** 1.5
        img[..., c] = cell * (1 - k) + vein[c] * k
        b = np.clip(1.0 - v / 0.12, 0, 1)
        img[..., c] = img[..., c] * (1 - b) + base[c] * b
        r = np.clip((v - 0.9) / 0.06, 0, 1)
        img[..., c] = img[..., c] * (1 - r) + rim[c] * r
    if kind == "alpha":  # dark speckles on the alpha's fiery frill
        dots = rng.uniform(0, 1, (H // 8, W // 8)) < 0.06
        dots = np.kron(dots, np.ones((8, 8)))[:H, :W] > 0
        img[dots & (v > 0.15) & (v < 0.88)] *= 0.55
    return np.clip(img, 0, 1)


def save_png(rgb, path):
    H, W = rgb.shape[:2]
    im = bpy.data.images.new(os.path.basename(path), W, H)
    px = np.ones((H, W, 4))
    px[..., :3] = rgb
    im.pixels[:] = px.ravel()
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()


if __name__ == "__main__" and "--paint" in sys.argv:
    a = sys.argv[sys.argv.index("--paint") + 1:]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    save_png(paint(a[0]), a[1])
    print("FRILL painted", a[1])
    sys.exit(0)


def fan(side):
    """Open fan geometry for one side: rib (heads, open dirs, lengths) and the membrane grid."""
    sx = 1.0 if side == "L" else -1.0
    X, Y, Z = Vector((sx, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

    def base(phi):
        return CENTRE + X * (NECK_R[0] * math.cos(phi)) + Z * (NECK_R[1] * math.sin(phi)) + Y * 0.004 * math.cos(phi)

    def direction(phi):
        return ((X * math.cos(CUP) - Y * math.sin(CUP)) * math.cos(phi) + Z * math.sin(phi)).normalized()

    def length(phi, tooth=0.0):
        mid = (PHI[0] + PHI[1]) / 2
        span = (PHI[0] - PHI[1]) / 2
        t = (phi - mid) / span  # -1 .. 1
        return RADIUS * (0.72 + 0.28 * math.sqrt(max(0.0, 1 - t * t)) + 0.06 * tooth)

    ribs = []
    for i in range(N_RIBS):
        phi = PHI[0] + (PHI[1] - PHI[0]) * i / (N_RIBS - 1)
        ribs.append((phi, base(phi), direction(phi), length(phi)))
    NA, NR = TEETH * 2, 6
    verts, uvs, wts = [], [], []
    for j in range(NA + 1):
        f = j / NA
        phi = PHI[0] + (PHI[1] - PHI[0]) * f
        tooth = 1.0 if j % 2 == 1 else 0.0
        for k in range(NR + 1):
            s = k / NR
            L = length(phi, tooth if k == NR else tooth * (k / NR) ** 3)
            verts.append(base(phi) + direction(phi) * L * s)
            uvs.append((f, s))
            x = f * (N_RIBS - 1)
            i0 = min(int(x), N_RIBS - 2)
            t = x - i0
            wts.append({i0: 1 - t, i0 + 1: t})
    faces = []
    for j in range(NA):
        for k in range(NR):
            a = j * (NR + 1) + k
            b = (j + 1) * (NR + 1) + k
            faces.append((a, b, b + 1, a + 1) if side == "L" else (a, a + 1, b + 1, b))  # open, the front face looks at the head (-y)
    return ribs, verts, uvs, wts, faces


def folded_dir(phi, side):
    """Folded: the rib lies back along the neck's slope, fanned a little across it, off the skin."""
    sx = 1.0 if side == "L" else -1.0
    along = Vector((0, 0.9, -0.45)).normalized()  # down the neck towards the shoulders
    across = Vector((0, 0.45, 0.9)).normalized()
    return (along + across * (0.14 * math.sin(phi)) + Vector((sx * 0.24, 0, 0))).normalized()


def build(src, out, out_json):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
    body = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes), key=lambda o: len(o.data.vertices))
    assert arm.matrix_world == Matrix.Identity(4), "armature expected at the origin"
    # ---- bones, open
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    geo = {}
    for side in "LR":
        ribs, verts, uvs, wts, faces = fan(side)
        geo[side] = (ribs, verts, uvs, wts, faces)
        for i, (phi, b, d, L) in enumerate(ribs):
            bn = eb.new("Frill%d.%s" % (i + 1, side))
            bn.head, bn.tail = b, b + d * L * 0.9
            bn.parent = eb["Neck2"]
            bn.use_deform = True
            bn.align_roll(Vector((0, 1, 0)))
    bpy.ops.object.mode_set(mode="OBJECT")
    # ---- membrane mesh (two-sided), weighted to the ribs
    me = bpy.data.meshes.new("frill")
    V, F, UV, W = [], [], [], []
    for side in "LR":
        ribs, verts, uvs, wts, faces = geo[side]
        for back in (False, True):
            o = len(V)
            for p, uv, w in zip(verts, uvs, wts):
                V.append(p + Vector((0, 0.0015, 0)) if back else p)  # the back sheet, behind the open fan
                UV.append(uv)
                W.append({"Frill%d.%s" % (i + 1, side): x for i, x in w.items() if x > 1e-4})
            for f in faces:
                F.append(tuple(o + i for i in (f[::-1] if back else f)))
    me.from_pydata([tuple(v) for v in V], [], F)
    me.update()
    uvl = me.uv_layers.new(name=body.data.uv_layers.active.name)  # join matches UV layers by name
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            uvl.data[li].uv = (UV[vi][0], UV[vi][1] * STRIP * 0.98 + 0.002)
    fr = bpy.data.objects.new("frill", me)
    bpy.context.scene.collection.objects.link(fr)
    for side in "LR":
        for i in range(N_RIBS):
            fr.vertex_groups.new(name="Frill%d.%s" % (i + 1, side))
    for vi, w in enumerate(W):
        for n, x in w.items():
            fr.vertex_groups[n].add([vi], x, "REPLACE")
    mod = fr.modifiers.new("arm", "ARMATURE")
    mod.object = arm
    fr.parent = arm
    # ---- fold: pose the ribs back along the neck, bake the folded membrane, make the fold the rest pose
    rots = {}
    for side in "LR":
        for i, (phi, b, d, L) in enumerate(geo[side][0]):
            name = "Frill%d.%s" % (i + 1, side)
            q = d.rotation_difference(folded_dir(phi, side))
            pb = arm.pose.bones[name]
            rest = arm.data.bones[name].matrix_local
            pb.matrix = Matrix.Translation(b) @ q.to_matrix().to_4x4() @ Matrix.Translation(-b) @ rest
            bpy.context.view_layer.update()
            rots[name] = q.inverted()  # folded -> open, armature space about the rib head
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = fr
    fr.select_set(True)
    bpy.ops.object.modifier_apply(modifier="arm")
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    # body skin was bound at the old rest: re-applying rest changed only the rib bones, which it has no weight on
    # ---- origin to mid-torso (ORIGIN_Y): everything moves back by it, so the origin is where y was ORIGIN_Y
    shift = Matrix.Translation((0.0, -ORIGIN_Y, 0.0))
    bpy.ops.object.mode_set(mode="EDIT")
    for b in arm.data.edit_bones:
        b.head.y -= ORIGIN_Y
        b.tail.y -= ORIGIN_Y
    bpy.ops.object.mode_set(mode="OBJECT")
    body.data.transform(shift)
    fr.data.transform(shift)
    json.dump({"note": "SP-DILOPHOSAURUS: per frill rib, the armature-space rotation folded -> open about the rib's head "
                       "(w, x, y, z), relative to Neck2's rest; make_dilo_moves.py poses frill f in 0..1 as a slerp of it",
               "parent": "Neck2",
               "ribs": {n: {"head": list(arm.data.bones[n].head_local), "q_open": list(q)} for n, q in rots.items()}},
              open(out_json, "w"), indent=1)
    # ---- atlas: the body's UVs into the top 80 %, the frill paint in the bottom strip
    mat = body.data.materials[0]
    for n in mat.node_tree.nodes:
        if n.type != "TEX_IMAGE" or n.image is None:
            continue
        im = n.image
        Wd, Hd = im.size
        src_px = np.array(im.pixels[:]).reshape(Hd, Wd, 4)
        Hn = int(round(Hd / (1 - STRIP)))
        dst = np.ones((Hn, Wd, 4))
        dst[Hn - Hd:] = src_px
        strip = Hn - Hd
        name = im.name.lower()
        if "color" in name and "orm" not in name:
            p = paint("regular", Wd, strip)
            dst[:strip, :, :3] = p
        elif "orm" in name:
            dst[:strip, :, :3] = (1.0, 0.72, 0.0)
        else:  # normal map: flat
            dst[:strip, :, :3] = (0.5, 0.5, 1.0)
        new = bpy.data.images.new(im.name + "_frill", Wd, Hn, alpha=False)
        new.colorspace_settings.name = im.colorspace_settings.name
        new.pixels[:] = dst.ravel()
        new.file_format = "JPEG" if "color" in name else "PNG"
        new.pack()
        n.image = new
    off = Hn - Hd
    for loop_uv in body.data.uv_layers.active.data:
        loop_uv.uv = (loop_uv.uv[0], (loop_uv.uv[1] * Hd + off) / Hn)
    fr.data.materials.append(mat)
    # ---- join into the body (one skinned mesh, one material)
    for vg in fr.vertex_groups:
        if vg.name not in body.vertex_groups:
            body.vertex_groups.new(name=vg.name)
    bpy.ops.object.select_all(action="DESELECT")
    fr.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=False,
                              export_skins=True, export_yup=True, export_image_format="AUTO", export_materials="EXPORT")
    print("FRILL wrote", out, "ribs", len(rots))


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:]
    build(a[0], a[1], a[2])
