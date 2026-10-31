# Geometry QA of the prepped mesh: islands, open edges, winding vs normals, key heights, and textured renders
# (side, front, back, top, below, 3/4, head close-ups). Blender -b prep.blend --factory-startup -P qa_mesh.py -- <outdir>
import bpy, bmesh, sys, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rlib
out = sys.argv[sys.argv.index("--") + 1]; os.makedirs(out, exist_ok=True)
o = bpy.data.objects["SM_Triceratops"]; me = o.data
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
seen = np.zeros(len(bm.verts), bool); isl = []
for v in bm.verts:
    if seen[v.index]: continue
    st = [v]; seen[v.index] = True; n = 0
    while st:
        c = st.pop(); n += 1
        for e in c.link_edges:
            w = e.other_vert(c)
            if not seen[w.index]: seen[w.index] = True; st.append(w)
    isl.append(n)
print("QA islands", len(isl), sorted(isl, reverse=True)[:5], "non-manifold edges", sum(1 for e in bm.edges if not e.is_manifold),
      "boundary edges", sum(1 for e in bm.edges if e.is_boundary))
# winding vs the custom (Tripo) corner normals: a face whose corners all point against its geometric normal is inside out
cn = np.empty(len(me.loops) * 3); me.corner_normals.foreach_get("vector", cn); cn = cn.reshape(-1, 3)
inv = 0
for p in me.polygons:
    if np.dot(cn[p.loop_start:p.loop_start + p.loop_total].sum(0), np.array(p.normal[:])) < 0: inv += 1
print("QA faces wound against their normals", inv, "of", len(me.polygons))
bm.free()
P = np.array([v.co[:] for v in me.vertices]); x, y, z = P.T
print("QA bounds", P.min(0).round(3), P.max(0).round(3))
for lo, hi, name in ((-3.4, -0.6, "back over the hips"), (-0.6, 1.0, "back over the shoulders")):
    m = (y > lo) & (y < hi) & (np.abs(x) < 0.4)
    print(f"QA {name}: top z {z[m].max():.2f} at y {y[m][z[m].argmax()]:.2f}")
print("QA frill top z %.2f at y %.2f" % (z.max(), y[z.argmax()]))
for name, sel in (("front feet", y > 0.8), ("hind feet", y < 0.8)):
    m = sel & (z < 0.12)
    print(f"QA {name}: x {x[m].min():.2f}..{x[m].max():.2f} y {y[m].min():.2f}..{y[m].max():.2f}")
rlib.setup(); cam = bpy.context.scene.camera
VIEWS = {"side_left": (-1, 0, 0.02), "side_right": (1, 0, 0.02), "front": (0, 1, 0.05), "back": (0, -1, 0.08), "top": (0, 0.001, 1),
         "below": (0, 0.001, -1), "q_front_left": (-1, 1.1, 0.45), "q_back_right": (1, -1.1, 0.45)}
for n, d in VIEWS.items():
    rlib.shot(f"{out}/{n}.png", d, P, 900, 600, margin=1.06)
head = P[y > 2.6]
for n, d in (("head_left", (-1, 0, 0.02)), ("head_front", (0, 1, 0.05)), ("head_top", (0, 0.001, 1)), ("head_q", (-1, 1.0, 0.6))):
    rlib.shot(f"{out}/{n}.png", d, head, 700, 600, margin=1.1)
feet = P[z < 1.2]
rlib.shot(f"{out}/feet_q.png", (-1, 0.8, 0.5), feet, 900, 500, margin=1.05)
rlib.montage([f"{out}/{n}.png" for n in VIEWS], 2, f"{out}/views.png")
rlib.montage([f"{out}/{n}.png" for n in ("head_left", "head_front", "head_top", "head_q")], 2, f"{out}/head.png")
print("QA renders in", out)
