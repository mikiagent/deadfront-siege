# Copied from deadfront-reanim/tools (adds --where N: print the N worst edges).
# Blender headless: skin stretch and belly contact of a clip on the real skinned mesh.
# usage: Blender -b -P measure_skin.py -- <mesh.glb> <clip.glb> [--ignore Bone,Bone] [--bone <name>] [--belly <y0> <y1> <half_width>]
# Prints "STRETCH max=<edge length / rest length> over2=<edges stretched past 2x> worst_frame=<f>" over every frame:
# torn rump flaps, spiked feet and flat skin wedges are edges pulled far past their rest length. --ignore skips edges
# whose first vertex is dominated by those bones (a mouth that opens stretches by design).
# With --bone, also "BONEZ <name> mean=<m> min=<m>": that bone head's height over the clip (a crouch lowers the hips).
# With --belly, also "BELLY gap=<m>" on the last frame: rays cast up from under the floor every 0.1 m along y0..y1
# (|x| <= half_width); per y the lowest skin hit, and gap is the highest of those, i.e. how far the underside hangs
# above the floor somewhere along that span (sky under the hips). BELLY_PROFILE lists y:height every 0.3 m.
import bpy, sys
a = sys.argv[sys.argv.index("--") + 1:]
base, clip = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
body = [o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups]
before = set(bpy.data.actions); bpy.ops.import_scene.gltf(filepath=clip)
act = max(set(bpy.data.actions) - before, key=lambda x: x.frame_range[1])
arm.animation_data_create(); arm.animation_data.action = act
try: arm.animation_data.action_slot = act.slots[0]
except Exception: pass
sc = bpy.context.scene
def verts():
    dg = bpy.context.evaluated_depsgraph_get(); out = []
    for o in body:
        e = o.evaluated_get(dg); me = e.to_mesh(); out.append([o.matrix_world @ v.co for v in me.vertices]); e.to_mesh_clear()
    return out
ign = set(a[a.index("--ignore") + 1].split(",")) if "--ignore" in a else set()
def dom(o, i):
    gs = o.data.vertices[i].groups
    return o.vertex_groups[max(gs, key=lambda g: g.weight).group].name if len(gs) else "?"
edges = [[tuple(e.vertices) for e in o.data.edges if dom(o, e.vertices[0]) not in ign] for o in body]
arm.data.pose_position = "REST"; sc.frame_set(int(act.frame_range[0])); rest = verts(); arm.data.pose_position = "POSE"
rl = [[(r[i] - r[j]).length for i, j in es] for r, es in zip(rest, edges)]
f0, f1 = map(int, act.frame_range); worst = (0.0, 0, f0)
bn = a[a.index("--bone") + 1] if "--bone" in a else None; bz = []
for f in range(f0, f1 + 1):
    sc.frame_set(f); vs = verts(); mx = 0.0; n2 = 0
    if bn: bz.append((arm.matrix_world @ arm.pose.bones[bn].head).z)
    for v, es, ls in zip(vs, edges, rl):
        for (i, j), l in zip(es, ls):
            if l < 1e-4: continue
            r = (v[i] - v[j]).length / l; mx = max(mx, r); n2 += r > 2.0
    if mx > worst[0]: worst = (mx, n2, f)
print(f"STRETCH max={worst[0]:.2f} over2={worst[1]} worst_frame={worst[2]}")
if bn: print(f"BONEZ {bn} mean={sum(bz) / len(bz):.3f} min={min(bz):.3f}")
# Where the worst frame tears: edges past 2x, grouped by the bone that dominates their first vertex.
sc.frame_set(worst[2]); vs = verts(); where = {}
for o, v, es, ls in zip(body, vs, edges, rl):
    for (i, j), l in zip(es, ls):
        if l >= 1e-4 and (v[i] - v[j]).length / l > 2.0:
            n = dom(o, i); where[n] = where.get(n, 0) + 1
print("STRETCH_BY_BONE " + " ".join(f"{k}={n}" for k, n in sorted(where.items(), key=lambda kv: -kv[1])[:8]))
if "--where" in a:  # the worst edges of the worst frame: rest position and the bones on both ends
    top = []
    for oi, (o, v, es, ls) in enumerate(zip(body, vs, edges, rl)):
        for (i, j), l in zip(es, ls):
            if l >= 1e-4:
                top.append(((v[i] - v[j]).length / l, oi, i, j))
    top.sort(reverse=True)
    for r, oi, i, j in top[:int(a[a.index("--where") + 1])]:
        o = body[oi]; p0 = rest[oi][i]
        wi = sorted(((o.vertex_groups[g.group].name, round(g.weight, 2)) for g in o.data.vertices[i].groups), key=lambda x: -x[1])[:3]
        wj = sorted(((o.vertex_groups[g.group].name, round(g.weight, 2)) for g in o.data.vertices[j].groups), key=lambda x: -x[1])[:3]
        print(f"EDGE x{r:.1f} at ({p0.x:.2f},{p0.y:.2f},{p0.z:.2f}) {wi} | {wj}")
if "--belly" in a:
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    k = a.index("--belly"); y0, y1, hw = float(a[k + 1]), float(a[k + 2]), float(a[k + 3])
    sc.frame_set(f1); dg = bpy.context.evaluated_depsgraph_get(); gaps = []
    trees = []
    for o in body:
        e = o.evaluated_get(dg); me = e.to_mesh()
        trees.append(BVHTree.FromPolygons([o.matrix_world @ v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons]))
        e.to_mesh_clear()
    # Rays straight up from under the floor: the first skin hit is how high the underside hangs at (x, y).
    y = y0
    while y <= y1 + 1e-6:
        hits = []
        x = -hw
        while x <= hw + 1e-6:
            for t in trees:
                h = t.ray_cast(Vector((x, y, -1.0)), Vector((0, 0, 1)))
                if h[0] is not None: hits.append(h[0].z)
            x += 0.1
        if hits: gaps.append((min(hits), y))
        y += 0.1
    g = max(gaps); print(f"BELLY gap={g[0]:.3f} at_y={g[1]:.2f} samples={len(gaps)}")
    print("BELLY_PROFILE " + " ".join(f"{y:.1f}:{z:.2f}" for z, y in gaps[::3]))
