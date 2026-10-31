"""SP-SMILODON: the sabres are upper canines, so they ride the skull, rigidly, never the jaw.

add_jaw.py gives everything below the lip line to the Jaw; the sabres hang below it (tips at z 0.326 against a lip
line near 0.39, mesh units). Tripo built each sabre as a handful of small islands; any island in the snout box
(y < SNOUT_Y) that reaches below SABRE_Z is a sabre and goes 100 % to Head.

usage: Blender -b -P tools/gait/smilodon_sabres.py -- <in.glb> <out.glb>
"""
import sys

import bmesh
import bpy

SRC, DST = sys.argv[sys.argv.index("--") + 1:][:2]
SNOUT_Y, SABRE_Z = -0.42, 0.35

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
mw = ob.matrix_world
bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table()
seen, n_isl, n_v = set(), 0, 0
head = ob.vertex_groups["Head"]
for v0 in bm.verts:
    if v0.index in seen:
        continue
    isl, st = [], [v0]; seen.add(v0.index)
    while st:
        c = st.pop(); isl.append(c.index)
        for e in c.link_edges:
            o = e.other_vert(c)
            if o.index not in seen:
                seen.add(o.index); st.append(o)
    pts = [mw @ ob.data.vertices[i].co for i in isl]
    if len(isl) < 400 and max(p.y for p in pts) < SNOUT_Y + 0.02 and min(p.y for p in pts) < SNOUT_Y and min(p.z for p in pts) < SABRE_Z:
        for g in ob.vertex_groups:
            g.remove(isl)
        head.add(isl, 1.0, "REPLACE")
        n_isl += 1; n_v += len(isl)
bm.free()
print(f"SABRES {n_isl} islands, {n_v} verts rigid on Head")
for o in list(bpy.data.objects):
    if o not in (arm, ob):
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", DST)
