#!/usr/bin/env python3
"""Skeleton transplant v2: put a donor rig + its clips into an AI-generated mesh.

Why: no AI service rigs or animates non-humanoid creatures, but Meshy meshes are
good and CC0 donor rigs (Quaternius) come with real clips. Proven 2026-09-17.

Pipeline
  1. import mesh, strip any decorative skeleton, orient head to -Y, ground at z=0
  2. repair: drop loose shells (<1% of verts), merge doubles, fill holes (UVs
     inherited from neighbours), recalc normals
  3. import donor FBX, orient to -Y, uniform bbox fit, bake object transform,
     rescale location keys
  4. landmark warp (biped): piecewise-linear along the body axis so the donor's
     snout / feet / tail tip land on the mesh's, plus hip-height and hip-width
     scaling. Quadrupeds get the bbox fit only.
  5. weights: bone-heat on a watertight voxel proxy (it fails on AI meshes),
     transferred to the real mesh
  6. clips: rename per --map, then author the contract's missing ones from the
     donor set: knockdown (death 0-45%), hit_react (death 0-35% then reversed),
     alert (idle 0-40% with the head pitched), and a held telegraph beat inserted
     into attack_heavy
  7. export game/assets/creatures/<species>/<species>.glb (rigged, textured, no
     clips) and anim/<clip>.glb (armature only)

Usage (repo root):
  Blender --background --python tools/transplant_rig.py -- \
     --mesh <glb> --donor <fbx> --species <id> \
     --map Attack=attack_primary Jump=attack_heavy Death=death Idle=idle Run=run Walk=walk \
     [--fit landmark|bbox] [--no-repair] [--hold-frames 8] [--hold-at 0.3]
Prints PIPELINE {...} for the species JSON.
"""
import argparse, json, math, pathlib, sys
import bpy, bmesh
from mathutils import Vector, Matrix, Quaternion

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "creatures"
FPS = 24

argv = sys.argv[sys.argv.index("--") + 1:]
P = argparse.ArgumentParser()
P.add_argument("--mesh", required=True); P.add_argument("--donor", required=True)
P.add_argument("--species", required=True)
P.add_argument("--map", nargs="+", required=True, help="DonorClipSuffix=contract_clip")
P.add_argument("--fit", default="landmark", choices=["landmark", "bbox"])
P.add_argument("--no-repair", action="store_true")
P.add_argument("--hold-frames", type=int, default=8)
P.add_argument("--hold-at", type=float, default=0.3)
P.add_argument("--alert-pitch-deg", type=float, default=20.0)
A = P.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS


def log(*a):
    print(*a, flush=True)


def verts_world(o):
    bpy.context.view_layer.update()
    return [o.matrix_world @ v.co for v in o.data.vertices]


def bbox_of(pts):
    lo = Vector((math.inf,) * 3); hi = Vector((-math.inf,) * 3)
    for p in pts:
        lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
    return lo, hi


# ---------------------------------------------------------------- 1. mesh
bpy.ops.import_scene.gltf(filepath=str(ROOT / A.mesh))
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
mesh = max(meshes, key=lambda o: len(o.data.vertices))
for m in list(mesh.modifiers):
    if m.type == "ARMATURE":
        mesh.modifiers.remove(m)
for vg in list(mesh.vertex_groups):
    mesh.vertex_groups.remove(vg)
M0 = mesh.matrix_world.copy()
mesh.parent = None
mesh.matrix_world = Matrix.Identity(4)
mesh.data.transform(M0)
for o in list(bpy.data.objects):
    if o is not mesh:
        bpy.data.objects.remove(o)
bpy.context.view_layer.update()

# Orientation: long horizontal axis is the body; the taller end is the head. Head -> -Y.
vs = verts_world(mesh)
lo, hi = bbox_of(vs)
axis = 0 if (hi.x - lo.x) > (hi.y - lo.y) else 1
mid = (lo[axis] + hi[axis]) / 2
pos_half = [v.z for v in vs if v[axis] > mid]; neg_half = [v.z for v in vs if v[axis] <= mid]
head_sign = 1 if max(pos_half) > max(neg_half) else -1
facing = math.atan2(head_sign if axis == 1 else 0.0, head_sign if axis == 0 else 0.0)
mesh.data.transform(Matrix.Rotation(math.atan2(-1.0, 0.0) - facing, 4, "Z"))
vs = verts_world(mesh); lo, hi = bbox_of(vs)
mesh.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))))
vs = verts_world(mesh); mlo, mhi = bbox_of(vs)
log("MESH oriented: long axis", "XY"[axis], "head_sign", head_sign, "bbox", [round(v, 2) for v in mlo], [round(v, 2) for v in mhi])

# ---------------------------------------------------------------- 2. repair
repair = {"loose_removed": 0, "doubles_merged": 0, "holes_filled": 0, "verts_before": len(mesh.data.vertices)}
if not A.no_repair:
    bm = bmesh.new(); bm.from_mesh(mesh.data)
    bm.verts.ensure_lookup_table()
    # connected components
    seen = set(); comps = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]; comp = []
        seen.add(v.index)
        while stack:
            cur = stack.pop(); comp.append(cur)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index); stack.append(o)
        comps.append(comp)
    total = len(bm.verts)
    # AI meshes are often hundreds of islands (feather tufts, claws). Only drop
    # islands that are tiny relative to the LARGEST one, and never more than 3%
    # of the mesh in total; otherwise leave the geometry alone.
    biggest = max(len(c) for c in comps) if comps else 0
    small = sorted([c for c in comps if len(c) < max(6, 0.002 * biggest)], key=len)
    budget = 0.03 * total
    for c in small:
        if repair["loose_removed"] + len(c) > budget:
            break
        bmesh.ops.delete(bm, geom=c, context="VERTS")
        repair["loose_removed"] += len(c)
    repair["islands"] = len(comps)
    n0 = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=max(1e-5, (mhi.y - mlo.y) * 2e-4))
    repair["doubles_merged"] = n0 - len(bm.verts)
    uv_layer = bm.loops.layers.uv.verify()
    boundary = [e for e in bm.edges if e.is_boundary]
    faces_before = set(f.index for f in bm.faces)
    if boundary:
        res = bmesh.ops.holes_fill(bm, edges=boundary, sides=80)
        new_faces = res.get("faces", [])
        repair["holes_filled"] = len(new_faces)
        # inherit UVs from each vertex's existing loops so the fill is not black
        for f in new_faces:
            for l in f.loops:
                others = [ol[uv_layer].uv.copy() for ol in l.vert.link_loops if ol.face is not f]
                if others:
                    l[uv_layer].uv = sum(others, Vector((0, 0))) / len(others)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh.data); bm.free()
    mesh.data.update()
repair["verts_after"] = len(mesh.data.vertices)
log("REPAIR", json.dumps(repair))
vs = verts_world(mesh); mlo, mhi = bbox_of(vs)
H = mhi.z - mlo.z; L = mhi.y - mlo.y

# ---------------------------------------------------------------- 3. donor
before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(ROOT / A.donor))
new = [o for o in bpy.data.objects if o not in before]
arm = next(o for o in new if o.type == "ARMATURE")
donor_mesh = [o for o in new if o.type == "MESH"]
b = arm.data.bones
d = (arm.matrix_world @ b["Head"].head_local) - (arm.matrix_world @ b["Hips"].head_local); d.z = 0
arm.rotation_euler.z += math.atan2(-1.0, 0.0) - math.atan2(d.y, d.x)
bpy.context.view_layer.update()
dpts = verts_world(donor_mesh[0]) if donor_mesh else [arm.matrix_world @ bb.head_local for bb in b]
dlo, dhi = bbox_of(dpts)
s = L / (dhi.y - dlo.y)
arm.scale *= s
bpy.context.view_layer.update()
dpts = verts_world(donor_mesh[0]) if donor_mesh else [arm.matrix_world @ bb.head_local for bb in b]
dlo, dhi = bbox_of(dpts)
arm.location += Vector((-(dlo.x + dhi.x) / 2, -(dlo.y + dhi.y) / 2, -dlo.z))
bpy.context.view_layer.update()
for o in donor_mesh:
    bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def all_fcurves(act):
    if hasattr(act, "layers") and len(act.layers):
        return [fc for layer in act.layers for strip in layer.strips for cb in strip.channelbags for fc in cb.fcurves]
    return list(act.fcurves)


for act in bpy.data.actions:
    for fc in all_fcurves(act):
        if fc.data_path.endswith(".location"):
            for kp in fc.keyframe_points:
                kp.co.y *= s; kp.handle_left.y *= s; kp.handle_right.y *= s
            fc.update()
log("DONOR bbox-fit scale", round(s, 4))

# ---------------------------------------------------------------- 4. landmark warp
is_quadruped = "Triceratops" in A.donor or "quadruped" in A.donor.lower()
warp_info = {"mode": "bbox"}
if A.fit == "landmark" and not is_quadruped:
    # mesh landmarks (head at -Y, ground z=0)
    snout_m = min(v.y for v in vs)
    tail_m = max(v.y for v in vs)
    low = [v for v in vs if v.z < 0.06 * H]
    foot_m = sum(v.y for v in low) / len(low) if low else 0.0
    hip_slice = [v for v in vs if abs(v.y - foot_m) < 0.08 * L]
    top_at_hips = max(v.z for v in hip_slice) if hip_slice else H
    hipz_m = 0.65 * top_at_hips
    width_m = (max(v.x for v in hip_slice) - min(v.x for v in hip_slice)) if hip_slice else (mhi.x - mlo.x)
    # donor landmarks (armature now at identity, world == local)
    eb_pos = {bb.name: (bb.head_local.copy(), bb.tail_local.copy()) for bb in arm.data.bones}
    snout_d = eb_pos["Head_end"][1].y if "Head_end" in eb_pos else eb_pos["Head"][1].y
    tail_d = eb_pos["Tail5_end"][1].y if "Tail5_end" in eb_pos else max(t.y for h, t in eb_pos.values())
    feet = [eb_pos[n][0] for n in ("BackFoot.L", "BackFoot.R") if n in eb_pos]
    foot_d = sum(p.y for p in feet) / len(feet) if feet else 0.0
    hipz_d = eb_pos["Hips"][0].z
    legs = [eb_pos[n][0].x for n in ("BackUpLeg.L", "BackUpLeg.R") if n in eb_pos]
    width_d = (max(legs) - min(legs)) / 0.8 if len(legs) == 2 else width_m
    ys_d = [snout_d, foot_d, tail_d]; ys_m = [snout_m, foot_m, tail_m]
    zs = hipz_m / hipz_d if hipz_d > 1e-6 else 1.0
    xs = width_m / width_d if width_d > 1e-6 else 1.0

    def warp_y(y):
        if y <= ys_d[1]:
            t = (y - ys_d[0]) / (ys_d[1] - ys_d[0]) if ys_d[1] != ys_d[0] else 0.0
            return ys_m[0] + t * (ys_m[1] - ys_m[0])
        t = (y - ys_d[1]) / (ys_d[2] - ys_d[1]) if ys_d[2] != ys_d[1] else 0.0
        return ys_m[1] + t * (ys_m[2] - ys_m[1])

    def warp(p):
        return Vector((p.x * xs, warp_y(p.y), p.z * zs))

    bpy.ops.object.mode_set(mode="EDIT")
    for eb in arm.data.edit_bones:
        h, t = eb.head.copy(), eb.tail.copy()
        eb.head = warp(h); eb.tail = warp(t)
    bpy.ops.object.mode_set(mode="OBJECT")
    warp_info = {"mode": "landmark", "snout": [round(snout_d, 2), round(snout_m, 2)], "foot": [round(foot_d, 2), round(foot_m, 2)],
                 "tail": [round(tail_d, 2), round(tail_m, 2)], "hip_z_scale": round(zs, 3), "width_scale": round(xs, 3)}
log("WARP", json.dumps(warp_info))

# ---------------------------------------------------------------- 5. weights
def weighted_fraction(o):
    n = sum(1 for v in o.data.vertices if any(g.weight > 0.01 for g in v.groups))
    return n / max(1, len(o.data.vertices))


bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
frac = weighted_fraction(mesh)
weight_info = {"direct_fraction": round(frac, 3)}
if frac < 0.9:
    proxy = mesh.copy(); proxy.data = mesh.data.copy(); proxy.name = "proxy"
    bpy.context.scene.collection.objects.link(proxy)
    for vg in list(proxy.vertex_groups): proxy.vertex_groups.remove(vg)
    for m in list(proxy.modifiers): proxy.modifiers.remove(m)
    rm = proxy.modifiers.new("remesh", "REMESH"); rm.mode = "VOXEL"; rm.voxel_size = L / 90.0
    bpy.ops.object.select_all(action="DESELECT"); proxy.select_set(True); bpy.context.view_layer.objects.active = proxy
    bpy.ops.object.modifier_apply(modifier="remesh")
    proxy.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    weight_info["proxy_verts"] = len(proxy.data.vertices); weight_info["proxy_fraction"] = round(weighted_fraction(proxy), 3)
    for vg in list(mesh.vertex_groups): mesh.vertex_groups.remove(vg)
    for vg in proxy.vertex_groups: mesh.vertex_groups.new(name=vg.name)
    bpy.ops.object.select_all(action="DESELECT"); proxy.select_set(True); mesh.select_set(True); bpy.context.view_layer.objects.active = mesh
    dt = mesh.modifiers.new("dt", "DATA_TRANSFER"); dt.object = proxy; dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}; dt.vert_mapping = "NEAREST"; dt.layers_vgroup_select_src = "ALL"; dt.layers_vgroup_select_dst = "NAME"
    while mesh.modifiers.find("dt") > 0:
        bpy.ops.object.modifier_move_up(modifier="dt")
    bpy.ops.object.modifier_apply(modifier="dt")
    bpy.data.objects.remove(proxy)
    weight_info["final_fraction"] = round(weighted_fraction(mesh), 3)
log("WEIGHTS", json.dumps(weight_info))

# ---------------------------------------------------------------- 6. clips
names = dict(kv.split("=") for kv in A.map)
for act in list(bpy.data.actions):
    key = act.name.split("_")[-1]
    if key in names:
        act.name = names[key]
    else:
        bpy.data.actions.remove(act)


def keys_of(fc):
    return [(k.co.x, k.co.y, k.interpolation) for k in fc.keyframe_points]


def set_keys(fc, keys):
    n = len(fc.keyframe_points)
    for i in range(n - 1, -1, -1):
        fc.keyframe_points.remove(fc.keyframe_points[i], fast=True)
    fc.keyframe_points.add(len(keys))
    for kp, (x, y, interp) in zip(fc.keyframe_points, keys):
        kp.co = (x, y); kp.interpolation = interp
    fc.update()


def slice_copy(src, name, f0, f1):
    """Copy src keeping frames [f0,f1], rebased to start at frame 1."""
    act = src.copy(); act.name = name
    for fc in all_fcurves(act):
        keep = [(x, y, i) for (x, y, i) in keys_of(fc) if f0 <= x <= f1]
        for f in (f0, f1):
            if not any(abs(k[0] - f) < 1e-3 for k in keep):
                keep.append((f, fc.evaluate(f), "LINEAR"))
        keep.sort()
        set_keys(fc, [(x - f0 + 1, y, i) for (x, y, i) in keep])
    try:
        act.use_frame_range = True; act.frame_range = (1, f1 - f0 + 1)
    except (AttributeError, TypeError):
        pass
    return act


def frames(act):
    f0, f1 = act.frame_range
    return int(f0), int(f1)


authored = {}
have = {a.name: a for a in bpy.data.actions}
if "death" in have:
    f0, f1 = frames(have["death"]); n = f1 - f0
    if "knockdown" not in have:
        authored["knockdown"] = "death 0-45%, holds"
        slice_copy(have["death"], "knockdown", f0, f0 + int(n * 0.45))
    if "hit_react" not in have:
        end = f0 + int(n * 0.35)
        act = slice_copy(have["death"], "hit_react", f0, end)
        # append the same keys reversed so the clip returns to the start pose
        for fc in all_fcurves(act):
            ks = keys_of(fc); last = ks[-1][0]
            mirrored = [(last + (last - x), y, i) for (x, y, i) in reversed(ks[:-1])]
            set_keys(fc, ks + mirrored)
        try:
            act.use_frame_range = True; act.frame_range = (1, 2 * (end - f0) + 1)
        except (AttributeError, TypeError):
            pass
        authored["hit_react"] = "death 0-35% then reversed"
if "idle" in have and "alert" not in have:
    f0, f1 = frames(have["idle"]); n = f1 - f0
    act = slice_copy(have["idle"], "alert", f0, f0 + int(n * 0.4))
    # pitch the head: multiply Head rotation_quaternion keys by a ramped X rotation
    quat_fcs = [fc for fc in all_fcurves(act) if fc.data_path == 'pose.bones["Head"].rotation_quaternion']
    if len(quat_fcs) == 4:
        quat_fcs.sort(key=lambda fc: fc.array_index)
        xs_frames = sorted({k.co.x for k in quat_fcs[0].keyframe_points})
        total = xs_frames[-1] - xs_frames[0] if len(xs_frames) > 1 else 1.0
        new_keys = [[] for _ in range(4)]
        for x in xs_frames:
            t = (x - xs_frames[0]) / total
            ramp = min(1.0, t / 0.3) if t < 0.75 else max(0.0, (1.0 - t) / 0.25)
            q = Quaternion([fc.evaluate(x) for fc in quat_fcs])
            q2 = q @ Quaternion((1, 0, 0), math.radians(A.alert_pitch_deg) * ramp)
            for i in range(4):
                new_keys[i].append((x, q2[i], "LINEAR"))
        for i, fc in enumerate(quat_fcs):
            set_keys(fc, new_keys[i])
        authored["alert"] = f"idle 0-40% with head pitched {A.alert_pitch_deg} deg"
    else:
        authored["alert"] = "idle 0-40% (no Head quaternion curves found; no pitch)"
if "attack_heavy" in have and A.hold_frames > 0:
    act = have["attack_heavy"]; f0, f1 = frames(act); k = f0 + int((f1 - f0) * A.hold_at); Hf = A.hold_frames
    for fc in all_fcurves(act):
        ks = keys_of(fc)
        vk = fc.evaluate(k)
        shifted = [(x + Hf if x > k else x, y, i) for (x, y, i) in ks]
        if not any(abs(x - k) < 1e-3 for x, _, _ in ks):
            shifted.append((k, vk, "LINEAR"))
        shifted.append((k + Hf, vk, "LINEAR"))
        shifted.sort()
        set_keys(fc, shifted)
    try:
        act.use_frame_range = True; act.frame_range = (f0, f1 + Hf)
    except (AttributeError, TypeError):
        pass
    authored["attack_heavy"] = f"telegraph hold of {Hf} frames at {int(A.hold_at * 100)}%"
log("AUTHORED", json.dumps(authored))

# ---------------------------------------------------------------- 7. export
dest = OUT / A.species
(dest / "anim").mkdir(parents=True, exist_ok=True)
(dest / "work").mkdir(exist_ok=True); (dest / "work" / ".gdignore").touch()
for old in (dest / "anim").glob("*"):
    old.unlink()
arm.animation_data_create()


def export(path, action=None):
    scene = bpy.context.scene
    arm.animation_data.action = action
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    if action is not None:
        if hasattr(arm.animation_data, "action_slot") and len(action.slots):
            arm.animation_data.action_slot = action.slots[0]
        f0, f1 = frames(action)
        scene.frame_start, scene.frame_end = f0, f1
    else:
        mesh.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
        export_animations=action is not None, export_animation_mode="ACTIVE_ACTIONS",
        export_frame_range=True, export_force_sampling=True, export_skins=True, export_yup=True,
        export_image_format="AUTO", export_materials="EXPORT" if action is None else "NONE")
    log(f"  wrote {path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")


export(dest / f"{A.species}.glb")
clip_info = {}
for act in sorted(bpy.data.actions, key=lambda a: a.name):
    export(dest / "anim" / f"{act.name}.glb", act)
    f0, f1 = frames(act)
    clip_info[act.name] = {"frames": [f0, f1], "seconds": round((f1 - f0) / FPS, 3)}
log("PIPELINE " + json.dumps({"species": A.species, "route": "skeleton_transplant", "mesh": A.mesh, "donor": A.donor,
    "forward_axis": "+Z", "source_height_m": round(H, 4), "source_length_m": round(L, 4),
    "repair": repair, "warp": warp_info, "weights": weight_info, "authored_clips": authored, "clips": clip_info}))
