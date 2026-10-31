"""MEGANTLERS: clean the Tripo antler rack (image-to-model of a Codex antler image, task id in megaloceros.json
pipeline.antlers) into tools/gait/megaloceros/antlers_tripo.glb, which build_rig.py fits to the stag's head.

  Blender -b -P tools/gait/megaloceros/antler_prep.py -- <tripo_antlers.glb> <out.glb>

- Turns it to the rig's frame (Tripo faces +X; the rig faces -Y, +Z up).
- Cuts away the bare skull cap the rack was generated on: a plane under each burr.
- Records each burr centre (object extras burr_l / burr_r, +X = the animal's left).
- Drops the metallic channel (bone is not metal), shrinks the textures to 1024.
"""
import bpy, bmesh, sys, math
import numpy as np
from mathutils import Vector, Matrix
a = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = a[:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
o = [o for o in bpy.data.objects if o.type == "MESH"][0]
o.name = o.data.name = "Antlers"
me = o.data
mat = me.materials[0]
nodes = mat.node_tree.nodes

bm = bmesh.new(); bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)  # Tripo splits vertices along UV seams; join them so shells are real
bm.transform(o.matrix_world @ Matrix.Rotation(-math.pi / 2, 4, "Z"))
# the skull: cut each beam just under its burr (a plane read off a close front render: the burr ring leans out and up)
for sx in (1, -1):
    no = Vector((0.775 * sx, 0, 0.633)); co = Vector((0.062 * sx, 0, -0.146)) - no * 0.006
    region = [f for f in bm.faces if 0 < sx * f.calc_center_median().x < 0.16 and f.calc_center_median().z < -0.04]
    geom = list({v for f in region for v in f.verts}) + list({e for f in region for e in f.edges}) + region
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-6, plane_co=co, plane_no=no, clear_inner=True)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.calc_center_median().x) < 0.03], context="FACES")
# burr centres (the centre of each cut), read by build_rig.py to seat the burrs; the cuts stay open for its pedicles
burrs = {}
for sx in (1, -1):
    rv = list({v for e in bm.edges if e.is_boundary and sx * e.verts[0].co.x > 0 and abs(e.verts[0].co.x) < 0.16 and e.verts[0].co.z < -0.04 for v in e.verts})
    burrs[sx] = sum((v.co for v in rv), Vector()) / len(rv)
# keep the two biggest shells (the antlers); skull crumbs go
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
print("shells", [len(s) for s in shells[:6]])
bmesh.ops.delete(bm, geom=[v for s in shells[2:] for v in s], context="VERTS")
bm.to_mesh(me); bm.free()
o.matrix_world = Matrix.Identity(4)
o["burr_l"] = list(burrs[1]); o["burr_r"] = list(burrs[-1])
print("burrs", [round(c, 4) for c in burrs[1]], [round(c, 4) for c in burrs[-1]])
print("verts left", len(me.vertices))
# metal off; keep colour, roughness (ORM green) and normal
bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
for l in list(bsdf.inputs["Metallic"].links): mat.node_tree.links.remove(l)
bsdf.inputs["Metallic"].default_value = 0.0
for n in nodes:
    if n.type == "TEX_IMAGE" and max(n.image.size) > 1024: n.image.scale(1024, 1024)
bpy.ops.object.select_all(action="DESELECT"); o.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_image_format="JPEG", export_jpeg_quality=88, export_extras=True)
