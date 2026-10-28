#!/usr/bin/env python3
"""Worn bags for the survivor: one skinned GLB per bag type in game/data/bags.json, on the survivor's own
skeleton (the same form as the armour kit pieces, so RiggedModel.attach_skinned wears them and every clip
keeps working).

Backpacks hang on the back from Spine2 with two shoulder straps fitted to the body surface; pouches sit on the
hips on a belt. Each GLB has two materials: "bag_body" (the bag's own hide, plain light leather: the game
multiplies it by the primary material's natural colour, spec 35) and "bag_trim" (fibre straps and bone
toggles, which keep their own colour: one ingredient controls each visible component, spec 35 §4).

  Blender -b --factory-startup --python tools/blender/bags/build_bags.py -- <survivor.glb> <out_dir> [--only basic_bag]
"""
import argparse, json, math, os, sys
import bmesh, bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("out_dir")
ap.add_argument("--only", nargs="*", default=[])
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

# ASSUMPTION: bag shapes. bags.json gives only names and capacities, so size follows capacity: pouches on the
# hip, backpacks on the back, the specialised bag with extra side pockets. Metres; survivor faces -Y (Blender).
BAGS = {
    "small_pouch": dict(kind="pouch", size=(0.11, 0.06, 0.13), sides=("R",)),
    "large_pouch": dict(kind="pouch", size=(0.15, 0.08, 0.17), sides=("R", "L")),
    "basic_bag": dict(kind="pack", size=(0.30, 0.15, 0.38), flap=True),
    "advanced_backpack": dict(kind="pack", size=(0.34, 0.20, 0.50), flap=True, roll=True, side_pockets=1),
    "specialized_storage_bag": dict(kind="pack", size=(0.36, 0.22, 0.46), flap=True, side_pockets=2, front_pocket=True),
}
BODY_COL = (0.86, 0.80, 0.70, 1)   # undyed hide: white enough for the tint to carry
TRIM_COL = (0.10, 0.065, 0.035, 1)   # twisted plant fibre (linear values)
BONE_COL = (0.70, 0.64, 0.50, 1)   # bone toggles


def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.base)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
    return arm, body


def mat(name, col):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = col; b.inputs["Roughness"].default_value = 0.85
    return m


def box(bm, centre, size, mi, bevel=0.0, rot=Matrix.Identity(3)):
    r = bmesh.ops.create_cube(bm, size=1.0)
    vs = r["verts"]
    bmesh.ops.scale(bm, vec=size, verts=vs)
    bmesh.ops.transform(bm, matrix=rot.to_4x4(), verts=vs)
    bmesh.ops.translate(bm, vec=centre, verts=vs)
    faces = list({f for v in vs for f in v.link_faces})
    for f in faces: f.material_index = mi
    if bevel:
        edges = list({e for v in vs for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=3, profile=0.5, affect="EDGES")
    return vs


def cylinder(bm, centre, radius, length, axis, mi, segs=12):
    r = bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=radius, radius2=radius, depth=length)
    q = Vector((0, 0, 1)).rotation_difference(axis)
    bmesh.ops.rotate(bm, verts=r["verts"], cent=Vector(), matrix=q.to_matrix())
    bmesh.ops.translate(bm, vec=centre, verts=r["verts"])
    for f in {f for v in r["verts"] for f in v.link_faces}: f.material_index = mi


def strap(bm, bvh, pts, width, mi, lift=0.012, thick=0.006):
    """A flat strap along pts, each point pulled onto the body surface and lifted off it."""
    dense = []
    for p, q in zip(pts, pts[1:]):
        for k in range(6): dense.append(p.lerp(q, k / 6))
    dense.append(pts[-1])
    rows = []
    for i, p in enumerate(dense):
        loc, nrm, _, _ = bvh.find_nearest(p)
        c = loc + nrm * lift
        t = (dense[min(i + 1, len(dense) - 1)] - dense[max(i - 1, 0)]).normalized()
        side = t.cross(nrm).normalized() * (width / 2)
        rows.append([c - side, c + side, c + side + nrm * thick, c - side + nrm * thick])
    verts = [[bm.verts.new(p) for p in r] for r in rows]
    for r0, r1 in zip(verts, verts[1:]):
        for k in range(4):
            f = bm.faces.new((r0[k], r0[(k + 1) % 4], r1[(k + 1) % 4], r1[k])); f.material_index = mi
    return rows


def build(bag_id, spec):
    arm, body = load()
    aw = arm.matrix_world
    def bone(n): return aw @ arm.data.bones[n].head_local
    bm_b = bmesh.new(); bm_b.from_mesh(body.data); bm_b.transform(body.matrix_world)
    # the torso only: straps and belts must not snap onto the arms hanging beside them
    names = {g.index: g.name for g in body.vertex_groups}
    dl = bm_b.verts.layers.deform.active
    def limb(v):
        ws = v[dl].items()
        return bool(ws) and any(k in names[max(ws, key=lambda t: t[1])[0]] for k in ("Arm", "Hand"))
    bmesh.ops.delete(bm_b, geom=[v for v in bm_b.verts if limb(v)], context="VERTS")
    bvh = BVHTree.FromBMesh(bm_b)
    def surface_y(x, z, from_back=True):  # body surface along a ray from behind (+y) or the front (-y)
        o = Vector((x, 1.0 if from_back else -1.0, z)); d = Vector((0, -1 if from_back else 1, 0))
        hit = bvh.ray_cast(o, d)[0]
        return hit.y if hit else 0.0
    bm = bmesh.new()
    BODY, TRIM, BONE = 0, 1, 2
    sp2, sp1, hips = bone("Spine2"), bone("Spine1"), bone("Hips")
    weights = []  # (vert-index range end, bone name) assigned after the build
    if spec["kind"] == "pack":
        w, d, h = spec["size"]
        top = bone("Neck").z - 0.08
        zc = top - h / 2
        back = max(surface_y(x, z) for x in (-0.1, 0, 0.1) for z in (zc - h / 3, zc, zc + h / 3))
        c = Vector((0, back + d / 2 + 0.015, zc))
        box(bm, c, (w, d, h), BODY, bevel=min(w, d) * 0.35)
        if spec.get("flap"):
            box(bm, c + Vector((0, 0.012, h / 2 - h * 0.12)), (w * 1.02, d * 1.08, h * 0.26), BODY, bevel=0.03)
            for sx in (-0.07, 0.07):  # two toggle straps down the flap
                box(bm, c + Vector((sx, d / 2 + 0.018, h / 2 - h * 0.28)), (0.025, 0.006, h * 0.35), TRIM)
                cylinder(bm, c + Vector((sx, d / 2 + 0.026, h / 2 - h * 0.44)), 0.008, 0.04, Vector((1, 0, 0)), BONE)
        if spec.get("roll"):  # bedroll strapped on top
            cylinder(bm, c + Vector((0, 0, h / 2 + 0.06)), 0.06, w * 1.15, Vector((1, 0, 0)), TRIM, segs=16)
        for k in range(spec.get("side_pockets", 0)):
            for sx in (-1, 1):
                pz = -h * 0.18 + k * h * 0.32  # offset from the bag centre c (c.z is already zc)
                box(bm, c + Vector((sx * (w / 2 + 0.03), 0, pz)), (0.06, d * 0.7, h * 0.28), BODY, bevel=0.02)
        if spec.get("front_pocket"):
            box(bm, c + Vector((0, d / 2 + 0.03, -h * 0.18)), (w * 0.7, 0.06, h * 0.32), BODY, bevel=0.025)
        # shoulder straps: from the top of the bag, over the shoulder, down the chest, under the arm, back to its base
        for sg, s in ((1, "Left"), (-1, "Right")):
            sh = bone(f"{s}Arm")
            pts = [Vector((sg * 0.07, back + 0.02, top - 0.03)),
                   Vector((sg * 0.09, (back + 0.0) / 2, sh.z + 0.06)),
                   Vector((sg * 0.11, surface_y(sg * 0.11, sh.z - 0.05, False) - 0.01, sh.z - 0.04)),
                   Vector((sg * 0.12, surface_y(sg * 0.12, sh.z - 0.2, False) - 0.01, sh.z - 0.2)),
                   Vector((sg * 0.165, 0.0, sh.z - 0.27)),
                   Vector((sg * 0.12, back + 0.02, zc - h / 2 + 0.05))]
            strap(bm, bvh, pts, 0.04, TRIM)
        bone_for = lambda p: "Spine2"  # rigid: a pack rides the upper back and does not bend with the spine
    else:
        w, d, h = spec["size"]
        zb = hips.z + 0.03
        # belt round the waist
        ring = [Vector((math.sin(t) * 0.3, -math.cos(t) * 0.3, zb)) for t in [i * math.tau / 24 for i in range(25)]]
        strap(bm, bvh, ring, 0.035, TRIM, lift=0.01)
        for sd in spec["sides"]:
            sg = 1 if sd == "L" else -1
            x = sg * 0.16
            sy = surface_y(x, zb - h / 2 + 0.03)
            # on the hip, slightly behind the side seam so it clears the swinging arm
            p = Vector((x + sg * (d / 2 + 0.005), 0.03, zb - h / 2 + 0.02))
            loc, nrm, _, _ = bvh.find_nearest(p)
            c = loc + nrm.normalized() * (d / 2 + 0.008)
            rotm = Matrix.Rotation(math.atan2(nrm.x, -nrm.y), 3, "Z")
            box(bm, c, (w, d, h), BODY, bevel=min(w, d) * 0.4, rot=rotm)
            box(bm, c + Vector((0, 0, h / 2 - h * 0.15)) + nrm.normalized() * 0.006, (w * 1.04, d * 1.1, h * 0.32), BODY, bevel=0.015, rot=rotm)
            cylinder(bm, c + Vector((0, 0, h * 0.18)) + nrm.normalized() * (d / 2 + 0.012), 0.007, 0.035, rotm @ Vector((1, 0, 0)), BONE)
        bone_for = lambda p: "Hips"
    # mesh object skinned rigidly to the bone each part sits on
    me = bpy.data.meshes.new(bag_id); bm.to_mesh(me); bm.free(); bm_b.free()
    ob = bpy.data.objects.new(bag_id, me); bpy.context.scene.collection.objects.link(ob)
    for m in (mat("bag_body", BODY_COL), mat("bag_trim", TRIM_COL), mat("bag_bone", BONE_COL)): me.materials.append(m)
    groups = {}
    for v in me.vertices:
        n = bone_for(v.co)
        g = groups.get(n) or ob.vertex_groups.new(name=n); groups[n] = g
        g.add([v.index], 1.0, "REPLACE")
    for p in me.polygons: p.use_smooth = True
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE"); mod.object = arm
    for o in [o for o in bpy.data.objects if o.type == "MESH" and o is not ob]: bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
    out = os.path.join(a.out_dir, bag_id + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=False,
                              export_skins=True, export_yup=True)
    print(f"BAG {bag_id}: {len(me.polygons)} faces, bones {sorted(groups)} -> {out}")
    return sorted(groups)


os.makedirs(a.out_dir, exist_ok=True)
manifest = {"_doc": "Worn bag meshes, one per game/data/bags.json bag. Skinned to the survivor skeleton like the armour "
            "pieces: wear with RiggedModel.attach_skinned(skeleton, <dir>/<file>). Tint: multiply the material "
            "\"bag_body\" albedo by the bag's primary-material colour (spec 35); \"bag_trim\" (fibre straps) and "
            "\"bag_bone\" (toggles) keep their own colours. Built by tools/blender/bags/build_bags.py.",
            "tint_material": "bag_body", "bags": {}}
for bag_id, spec in BAGS.items():
    if a.only and bag_id not in a.only: continue
    bones = build(bag_id, spec)
    manifest["bags"][bag_id] = {"file": bag_id + ".glb", "attach": "skinned", "bones": bones,
                                "anchor_bone": "Spine2" if spec["kind"] == "pack" else "Hips"}
if not a.only:
    json.dump(manifest, open(os.path.join(a.out_dir, "bags.json"), "w"), indent=2)
