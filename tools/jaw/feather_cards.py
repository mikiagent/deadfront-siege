#!/usr/bin/env python3
"""Give the wing fans from add_wings.py a painted feather texture with cut-out edges, keeping their geometry.

Every blade (a connected island skinned to Wing.L / Wing.R) gets its own UV box over one cell of a feather
atlas painted here: a shaft, barbs angled toward the tip, the body's rust with darker bars, and an alpha
outline with a soft ragged edge. The fans get their own material (alpha clip, double sided) so the outline,
not the card, is the feather. Everything else in the mesh is untouched, so every clip still plays.

  Blender -b --python tools/jaw/feather_cards.py -- <in.glb> <out.glb> [--cells 4] [--png out.png]
"""
import argparse, math, random, sys
import bmesh, bpy
import numpy as np
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument("inp"); ap.add_argument("out")
ap.add_argument("--cells", type=int, default=4, help="feather variants in the atlas")
ap.add_argument("--res", type=int, default=256, help="cell width in px (height is twice that)")
ap.add_argument("--bars", type=float, default=2.0, help="dark bars along a feather")
ap.add_argument("--png", default="", help="also save the atlas here")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.inp)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm), key=lambda o: len(o.data.vertices))
wing_g = {ob.vertex_groups[n].index for n in ("Wing.L", "Wing.R") if n in ob.vertex_groups}
body_mat = ob.data.materials[0]
body_img = next(n.image for n in body_mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)

# feather colours from the body: the mean of the wing's current (borrowed rust) texels, and a darker bar tone
bm = bmesh.new(); bm.from_mesh(ob.data)
uvl = bm.loops.layers.uv.active; dl = bm.verts.layers.deform.active
def on_wing(v): return any(g in wing_g and w > 0.5 for g, w in v[dl].items())
W, H = body_img.size
PX = np.array(body_img.pixels[:], dtype=np.float32).reshape(H, W, 4)
samples = [PX[int(min(max(l[uvl].uv.y, 0), .9999) * H), int(min(max(l[uvl].uv.x, 0), .9999) * W), :3]
           for f in bm.faces if all(on_wing(v) for v in f.verts) for l in f.loops]
if not samples: sys.exit("no wing faces (run add_wings.py first)")
rust = np.median(np.array(samples), axis=0)
dark = rust * np.array([0.45, 0.38, 0.35])
pale = np.minimum(rust * np.array([1.25, 1.3, 1.3]), 1.0)
print("feather colours", rust.round(3), dark.round(3))

# atlas: cells side by side, each a feather pointing up (v = 0 at the quill, 1 at the tip)
R = a.res; CW, CH = R, 2 * R
img_px = np.zeros((CH, CW * a.cells, 4), dtype=np.float32)
yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
v = yy / (CH - 1); u = xx / (CW - 1) * 2 - 1  # u: -1..1 across, shaft at 0
rng = np.random.default_rng(7)
for c in range(a.cells):
    asym = 0.75 + 0.1 * c  # leading vane narrower than trailing, like a flight feather
    half = np.where(u < 0, asym, 1.0) * np.sin(np.pi * np.clip(v, 0, 1) ** 0.8) ** 0.55 * (1 - 0.35 * v)
    # ragged edge: barbs part in a few places; a soft rounded tip
    ragged = 1 - 0.06 * (np.sin(v * (40 + 7 * c) + rng.uniform(0, 6)) > 0.75)
    inside = np.abs(u) < half * ragged
    # barbs: fine lines slanting toward the tip, a slightly darker shaft, bars across the vane
    barb = 0.5 + 0.5 * np.sin((v * 1.0 - np.abs(u) * 0.35) * 2 * np.pi * 34)
    bars = 0.5 + 0.5 * np.sin(v * 2 * np.pi * a.bars + c * 1.3 + np.abs(u) * 0.6)
    col = rust[None, None, :] * (0.88 + 0.12 * barb[..., None])
    col = col * (1 - 0.55 * (bars[..., None] > 0.72)) + dark * 0.55 * (bars[..., None] > 0.72)
    col = np.where((np.abs(u) < 0.03)[..., None], pale, col)              # shaft
    tipshade = np.clip((v - 0.8) / 0.2, 0, 1)[..., None]
    col = col * (1 - 0.35 * tipshade) + dark * 0.35 * tipshade            # darker tips read as separate feathers
    img_px[:, c * CW:(c + 1) * CW, :3] = col
    img_px[:, c * CW:(c + 1) * CW, 3] = inside.astype(np.float32)
atlas = bpy.data.images.new("feathers", CW * a.cells, CH, alpha=True)
atlas.pixels[:] = img_px.ravel()
atlas.pack()
if a.png:
    atlas.filepath_raw = a.png; atlas.file_format = "PNG"; atlas.save()

# per blade UVs: islands of wing faces, laid along their own long axis (quill at the wing root end)
wing_faces = [f for f in bm.faces if all(on_wing(v) for v in f.verts)]
fset = set(wing_faces); seen = set(); islands = []
for f in wing_faces:
    if f in seen: continue
    stack, isl = [f], []
    seen.add(f)
    while stack:
        g = stack.pop(); isl.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h in fset and h not in seen: seen.add(h); stack.append(h)
    islands.append(isl)
roots = {}
for side in ("L", "R"):
    b = arm.data.bones.get(f"Wing.{side}")
    if b: roots[ob.vertex_groups[f"Wing.{side}"].index] = arm.matrix_world @ b.head_local
mwi = ob.matrix_world
rnd = random.Random(3)
for k, isl in enumerate(islands):
    verts = {v for f in isl for v in f.verts}
    pts = np.array([list(mwi @ v.co) for v in verts])
    gi = max(((g, w) for v in verts for g, w in v[dl].items() if g in roots), key=lambda t: t[1])[0]
    root = np.array(list(roots[gi]))
    cen = pts.mean(axis=0)
    _, _, vt = np.linalg.svd(pts - cen)
    along, across = vt[0], vt[1]
    if np.dot(along, cen - root) < 0: along = -along  # quill end toward the wing root
    s = (pts - cen) @ along; t = (pts - cen) @ across
    s0, s1, t0, t1 = s.min(), s.max(), t.min(), t.max()
    cell = rnd.randrange(a.cells)
    for f in isl:
        for l in f.loops:
            p = np.array(list(mwi @ l.vert.co)) - cen
            vv = (p @ along - s0) / max(s1 - s0, 1e-6)
            uu = (p @ across - t0) / max(t1 - t0, 1e-6)
            l[uvl].uv = Vector(((cell + 0.04 + 0.92 * uu) / a.cells, 0.01 + 0.98 * vv))
print(f"feather cards: {len(islands)} blades, atlas {CW * a.cells}x{CH}")

# their own material: the atlas, alpha clip, both sides
mat = bpy.data.materials.new("feathers"); mat.use_nodes = True
mat.use_backface_culling = False
nt = mat.node_tree; bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = atlas
rnd_n = nt.nodes.new("ShaderNodeMath"); rnd_n.operation = "ROUND"  # glTF exporter: alpha through Round = MASK at 0.5
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
nt.links.new(tex.outputs["Alpha"], rnd_n.inputs[0]); nt.links.new(rnd_n.outputs[0], bsdf.inputs["Alpha"])
bsdf.inputs["Roughness"].default_value = 0.85
ob.data.materials.append(mat); mi = len(ob.data.materials) - 1
for f in wing_faces: f.material_index = mi
bm.to_mesh(ob.data); bm.free()

for o in list(bpy.data.objects):
    if o not in (arm, ob) and o.type == "MESH" and o.parent is None: bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", a.out)
