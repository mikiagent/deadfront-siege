#!/usr/bin/env python3
"""Skeleton transplant v3: put a donor rig + its clips into an AI-generated mesh.

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
     scaling. Quadrupeds use measured sole clusters and body surface landmarks.
  5. weights: continuous anatomical weights for quadrupeds; bone heat plus
     local toe-shell smoothing for bipeds. Control bones never deform skin.
  6. clips: retarget biped motion; solve quadruped legs to explicit foot targets.
     Author recoil, grounded collapse, and held attacks. Bake foot alignment,
     floor correction and closed loop endpoints.
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
P.add_argument("--output-root", type=pathlib.Path, default=OUT)
P.add_argument("--mesh", required=True); P.add_argument("--donor", required=True)
P.add_argument("--species", required=True)
P.add_argument("--map", nargs="+", required=True, help="DonorClipSuffix=contract_clip")
P.add_argument("--fit", default="landmark", choices=["landmark", "bbox"])
P.add_argument("--no-repair", action="store_true")
P.add_argument("--hold-frames", type=int, default=8)
P.add_argument("--hold-at", type=float, default=0.3)
P.add_argument("--alert-pitch-deg", type=float, default=20.0)
A = P.parse_args(argv)
OUT = A.output_root

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
# FBX object transform keys survive transform_apply and would restore its old
# scale on the next evaluated frame. Only bone tracks belong in the transplant.
for act in bpy.data.actions:
    act.use_fake_user = True
    for layer in act.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                for fc in list(cb.fcurves):
                    if not fc.data_path.startswith('pose.bones['):
                        cb.fcurves.remove(fc)
arm.animation_data_clear()
for pb in arm.pose.bones:
    pb.matrix_basis.identity()
# Control and leaf marker bones must never attract skin weights.
for bone in arm.data.bones:
    if bone.name in {"root", "Body"} or bone.name.endswith("_end"):
        bone.use_deform = False
bpy.context.view_layer.update()

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
if is_quadruped:
    # Four foot clusters, sampled from actual sole geometry rather than donor bbox.
    import numpy as np
    arr = np.array([tuple(v) for v in vs])
    low = arr[arr[:, 2] < .10 * H]
    ys = np.array([np.quantile(low[:, 1], .20), np.quantile(low[:, 1], .80)])
    for _ in range(12):
        labels = np.argmin(abs(low[:, 1, None] - ys), axis=1)
        ys = np.array([np.mean(low[labels == i, 1]) for i in range(2)])
    front_y, back_y = sorted(ys)
    foot_x = float(np.median(abs(low[:, 0])))
    old = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones}
    # Fit fore and hind joints separately. Plates and frills aren't hip height.
    def surface_center(y):
        sl = arr[abs(arr[:, 1] - y) < .055 * L]
        lateral = sl[abs(sl[:, 0]) > .60 * max(abs(sl[:, 0]))]
        return float(np.quantile(lateral[:, 2], .85))
    hip_z, shoulder_z = surface_center(back_y), surface_center(front_y)
    head_slice = arr[arr[:, 1] < mlo.y + .13 * L]
    head_z = float(np.median(head_slice[:, 2]))
    tail_slice = arr[arr[:, 1] > mhi.y - .08 * L]
    tail_z = float(np.median(tail_slice[:, 2]))
    old_y = [old['Head_end'][1].y, old['FrontFoot.L'][0].y, old['BackFoot.L'][0].y, old['Tail5_end'][1].y]
    new_y = [mlo.y, front_y, back_y, mhi.y]
    def warp_q(p):
        y = float(np.interp(p.y, old_y, new_y))
        zs = float(np.interp(p.y, old_y, [head_z/max(old['Head'][0].z,1e-5), shoulder_z/max(old['Shoulders'][0].z,1e-5), hip_z/max(old['Hips'][0].z,1e-5), tail_z/max(old['Tail5_end'][1].z,1e-5)]))
        return Vector((p.x * foot_x / abs(old['BackFoot.L'][0].x), y, p.z * zs))
    bpy.ops.object.mode_set(mode='EDIT')
    for eb in arm.data.edit_bones:
        eb.head, eb.tail = warp_q(old[eb.name][0]), warp_q(old[eb.name][1])
    bpy.ops.object.mode_set(mode='OBJECT')
    warp_info = {'mode': 'quadruped_landmarks', 'front_foot_y': float(front_y), 'back_foot_y': float(back_y), 'foot_half_width': foot_x, 'hip_z': hip_z, 'shoulder_z': shoulder_z, 'head_z': head_z}

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
if is_quadruped:
    # Continuous anatomical weights avoid top-four truncation switching between
    # opposite limbs across adjacent vertices. Each vertex uses two spine and
    # at most two bones from ONE leg; rigid parts never follow leg controls.
    def smooth(a, b, x):
        t = max(0., min(1., (x-a)/max(b-a,1e-8)))
        return t*t*(3-2*t)
    def pair_weights(samples, x):
        samples = sorted(samples)
        if x <= samples[0][0]: return {samples[0][1]: 1.}
        if x >= samples[-1][0]: return {samples[-1][1]: 1.}
        for (lo,n0),(hi,n1) in zip(samples,samples[1:]):
            if lo <= x <= hi:
                t=smooth(lo,hi,x);return {n0:1-t,n1:t}
    spine_names=['Head','Neck','Shoulders','Torso','Hips','Back','Tail1','Tail2','Tail3','Tail4','Tail5']
    spine=[((arm.data.bones[n].head_local.y+arm.data.bones[n].tail_local.y)/2,n) for n in spine_names]
    for vg in list(mesh.vertex_groups): mesh.vertex_groups.remove(vg)
    groups={n:mesh.vertex_groups.new(name=n) for n in [b.name for b in arm.data.bones if b.use_deform]}
    footnames=[f'{end}Foot.{side}' for end in ['Front','Back'] for side in ['L','R']]
    for v in mesh.data.vertices:
        p=v.co;weights=pair_weights(spine,p.y)
        nearest=min(footnames,key=lambda n:(p.xy-arm.data.bones[n].head_local.xy).length_squared)
        prefix,side=nearest.split('Foot.');upper=prefix+'UpLeg.'+side;lower=prefix+'LowLeg.'+side
        foot=arm.data.bones[nearest].head_local;hip=arm.data.bones[upper].head_local
        radius=max(.04*L,.43*(back_y-front_y))
        ydist=min(abs(p.y-foot.y),abs(p.y-hip.y))
        limb=(1-smooth(.45*radius,radius,ydist))*smooth(.25*foot_x,.8*foot_x,abs(p.x))*(1-smooth(.60*hip.z,1.02*hip.z,p.z))
        if limb>0:
            leg=pair_weights([(.065*H,nearest),((arm.data.bones[lower].head_local.z+foot.z)/2,lower),((hip.z+arm.data.bones[lower].head_local.z)/2,upper)],p.z)
            weights={n:w*(1-limb) for n,w in weights.items()}
            for n,w in leg.items():weights[n]=weights.get(n,0)+w*limb
        for n,w in weights.items():
            if w>1e-8:groups[n].add([v.index],w,'REPLACE')
    weight_info['method']='continuous anatomical spine and single-limb weights, max four'
else:
    # Prune control/marker weights and normalize before glTF's four-weight cap.
    bpy.context.view_layer.objects.active=mesh
    bpy.ops.object.select_all(action='DESELECT');mesh.select_set(True)
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    # Smooth nearby toe-shell weights without reassigning them to a different
    # joint. Spatial neighbours catch disconnected shells that topology misses.
    from mathutils.kdtree import KDTree
    kd=KDTree(len(mesh.data.vertices))
    for v in mesh.data.vertices:kd.insert(v.co,v.index)
    kd.balance()
    weights=[{g.group:g.weight for g in v.groups if g.weight>0} for v in mesh.data.vertices]
    neighbours={v.index:[(idx,math.exp(-((dist/(.018*H))**2))) for co,idx,dist in kd.find_n(v.co,20) if dist<.04*H] for v in mesh.data.vertices if v.co.z<.15*H}
    for _ in range(3):
        updated=list(weights)
        for idx,near in neighbours.items():
            sums={};total=sum(w for _,w in near)
            for other,w in near:
                for group,value in weights[other].items():sums[group]=sums.get(group,0)+value*w/total
            updated[idx]=sums
        weights=updated
    for idx in neighbours:
        for group in mesh.vertex_groups:group.remove([idx])
        selected=sorted(weights[idx].items(),key=lambda item:item[1],reverse=True)[:4];total=sum(w for _,w in selected)
        for group,value in selected:mesh.vertex_groups[group].add([idx],value/total,'REPLACE')
    weight_info['toe_weights']='three spatial smoothing passes; original bone assignments retained'

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
# Dedicated reactions replace death-derived flinches on every creature.
def neutral_action(name, duration, envelopes):
    src = next(a for a in bpy.data.actions if a.name == 'idle')
    arm.animation_data_create();arm.animation_data.action=src
    if src.slots:arm.animation_data.action_slot=src.slots[0]
    bpy.context.scene.frame_set(int(src.frame_range[0]));bpy.context.view_layer.update()
    neutral={p.name:p.matrix_basis.copy() for p in arm.pose.bones}
    previous=bpy.data.actions.get(name)
    if previous:bpy.data.actions.remove(previous)
    act=bpy.data.actions.new(name);act.use_fake_user=True;arm.animation_data.action=act
    end=round(duration*FPS)+1
    for f in range(1,end+1):
        t=(f-1)/(end-1)
        for pb in arm.pose.bones:pb.matrix_basis=neutral[pb.name]
        for bn,axis,keys in envelopes:
            if bn not in arm.pose.bones:continue
            val=0.
            for (t0,v0),(t1,v1) in zip(keys,keys[1:]):
                if t0<=t<=t1:
                    u=(t-t0)/(t1-t0);u=u*u*(3-2*u);val=v0+(v1-v0)*u;break
            pb=arm.pose.bones[bn];pb.rotation_mode='QUATERNION'
            # Convert the desired armature-space axis into the bone's rest basis.
            axis_local=pb.bone.matrix_local.to_quaternion().inverted()@Vector(axis)
            pb.rotation_quaternion=pb.rotation_quaternion@Quaternion(axis_local,math.radians(val))
        for pb in arm.pose.bones:
            for prop in ('location','rotation_quaternion','scale'):pb.keyframe_insert(data_path=prop,frame=f,group=pb.name)
    return act

neutral_action('hit_react',.6,[('Neck',(1,0,0),[(0,0),(.16,-6),(.36,-4),(.62,1),(1,0)]),('Head',(1,0,0),[(0,0),(.16,-3),(.36,-2),(.62,.5),(1,0)])])
authored['hit_react']='dedicated 0.6s head/neck recoil from neutral idle; no death frames'
if is_quadruped and A.species == 'stegosaurus':
    for name,duration,keys in [('attack_primary',1.15,[(0,0),(.2,-8),(.48,15),(.72,5),(1,0)]),('attack_heavy',1.8,[(0,0),(.22,-12),(.42,-12),(.60,22),(.78,7),(1,0)])]:
        neutral_action(name,duration,[(b,(0,0,1),keys) for b in ['Tail1','Tail2','Tail3']])
        authored[name]='authored thagomizer sweep'+(' with 0.36s anticipation hold' if name=='attack_heavy' else '')
elif is_quadruped:
    old=bpy.data.actions.get('attack_heavy')
    if old:bpy.data.actions.remove(old)
    primary=bpy.data.actions['attack_primary'];heavy=primary.copy();heavy.name='attack_heavy';heavy.use_fake_user=True
    hold_at=round(primary.frame_range[0]+.25*(primary.frame_range[1]-primary.frame_range[0]))
    for fc in all_fcurves(heavy):
        keys=keys_of(fc);value=fc.evaluate(hold_at)
        keys=[(x+10 if x>hold_at else x,y,i) for x,y,i in keys]
        keys.extend([(hold_at,value,'LINEAR'),(hold_at+10,value,'LINEAR')]);set_keys(fc,sorted(keys))
    authored['attack_heavy']='primary attack with 10-frame anticipation hold; removes donor jump'
# Collapse as one coherent body; the old donor death bent long necks and tails
# through extreme angles after retargeting between unrelated species.
fall=[(0,0),(.18,6),(.48,48),(.72,90),(1,90)]
neutral_action('death',1.8,[('root',(0,1,0),fall),('Neck',(1,0,0),[(0,0),(.6,3),(1,7)]),('Head',(1,0,0),[(0,0),(.6,2),(1,5)])])
authored['death']='coherent sideways collapse with small neck release; corrected to ground each frame'
# The entire collapse must play before the capture hold, not just its airborne opening.
old=bpy.data.actions.get('knockdown')
if old:bpy.data.actions.remove(old)
knock=bpy.data.actions['death'].copy();knock.name='knockdown';knock.use_fake_user=True
end=knock.frame_range[1]
for fc in all_fcurves(knock):
    keys=keys_of(fc);keys.append((end+8,fc.evaluate(end),'LINEAR'));set_keys(fc,keys)
authored['knockdown']='complete death collapse followed by 8-frame grounded hold'

if is_quadruped:
    # Solve each leg from anatomical rest lengths to explicit foot positions.
    # Donor poses are not transferable between a deer, a ceratopsian and a stegosaur.
    arm.animation_data.action=None
    for act in list(bpy.data.actions):bpy.data.actions.remove(act)
    for pb in arm.pose.bones:pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    rest={b.name:b.matrix_local.copy() for b in arm.data.bones}
    leg_names=[f'{end}.{side}' for end in ['Front','Back'] for side in ['L','R']]
    def rotate_global(name,axis,degrees):
        pb=arm.pose.bones[name];pb.rotation_mode='QUATERNION'
        pb.rotation_quaternion=Quaternion(rest[name].to_quaternion().inverted()@Vector(axis),math.radians(degrees))
    def envelope(t,keys):
        for (t0,v0),(t1,v1) in zip(keys,keys[1:]):
            if t0<=t<=t1:
                u=(t-t0)/(t1-t0);u=u*u*(3-2*u);return v0+(v1-v0)*u
        return keys[-1][1]
    def aim(name,head,tail):
        b=arm.data.bones[name];q=(b.tail_local-b.head_local).rotation_difference(tail-head)@rest[name].to_quaternion()
        arm.pose.bones[name].matrix=Matrix.LocRotScale(head,q,Vector((1,1,1)))
        bpy.context.view_layer.update()
    durations={'idle':3,'walk':1.6,'run':.9,'attack_primary':1.15,'attack_heavy':1.8,'hit_react':.6,'knockdown':1.8,'death':2.1,'alert':1.6}
    for clip,duration in durations.items():
        act=bpy.data.actions.new(clip);act.use_fake_user=True;arm.animation_data.action=act
        end=round(duration*FPS)+1
        for f in range(1,end+1):
            t=(f-1)/(end-1)
            for pb in arm.pose.bones:pb.matrix_basis.identity();pb.rotation_mode='QUATERNION'
            roll=envelope(t,[(0,0),(.14,4),(.42,50),(.68,90),(1,90)]) if clip in {'death','knockdown'} else 0.
            bob=0. if clip=='idle' else (.006*H*(1-math.cos(t*math.tau*2)) if clip in {'walk','run'} else 0.)
            motion=Matrix.Translation(Vector((0,0,bob)))@Matrix.Rotation(math.radians(roll),4,'Y')
            arm.pose.bones['root'].matrix=motion@rest['root']
            if clip=='idle':rotate_global('Neck',(1,0,0),.8*math.sin(t*math.tau))
            if clip=='alert':rotate_global('Neck',(1,0,0),envelope(t,[(0,0),(.3,-6),(.65,-6),(1,0)]))
            if clip=='hit_react':
                recoil=envelope(t,[(0,0),(.16,-6),(.36,-4),(.62,1),(1,0)]);rotate_global('Neck',(1,0,0),recoil);rotate_global('Head',(1,0,0),recoil*.5)
            if clip in {'attack_primary','attack_heavy'}:
                heavy=clip=='attack_heavy'
                keys=[(0,0),(.22,-12),(.42,-12),(.60,20),(.78,7),(1,0)] if heavy else [(0,0),(.2,-8),(.48,14),(.72,5),(1,0)]
                attack=envelope(t,keys)
                if A.species=='stegosaurus':
                    for bn in ['Tail1','Tail2','Tail3']:rotate_global(bn,(0,0,1),attack)
                else:
                    rotate_global('Neck',(1,0,0),attack);rotate_global('Head',(1,0,0),attack*.4)
            if clip in {'death','knockdown'}:rotate_global('Neck',(1,0,0),envelope(t,[(0,0),(.65,0),(1,5)]))
            for i,bn in enumerate(['Tail1','Tail2','Tail3','Tail4']):
                if clip in {'idle','walk','run'}:rotate_global(bn,(0,0,1),1.2*math.sin(t*math.tau-i*.4))
            bpy.context.view_layer.update()
            for ln in leg_names:
                endname,side=ln.split('.');up=endname+'UpLeg.'+side;low=endname+'LowLeg.'+side;foot=endname+'Foot.'+side
                u,l=arm.data.bones[up],arm.data.bones[low]
                target=arm.data.bones[foot].head_local.copy()
                if clip in {'walk','run'}:
                    phases={'Front.L':0.,'Front.R':.5,'Back.L':.75,'Back.R':.25} if clip=='walk' else {'Front.L':0.,'Front.R':.5,'Back.L':.5,'Back.R':0.}
                    phase=(t+phases[ln])%1;duty=.68 if clip=='walk' else .52;stride=L*(.055 if clip=='walk' else .09)
                    if phase<duty:target.y+=stride*(phase/duty-.5)
                    else:
                        swing=(phase-duty)/(1-duty);target.y+=stride*(.5-swing);target.z+=H*(.055 if clip=='walk' else .085)*math.sin(swing*math.pi)
                # Feet counter the torso's breathing/gait bob. A falling animal's
                # feet follow the body rotation instead of staying stuck to ground.
                target=Matrix.Rotation(math.radians(roll),4,'Y')@target
                hip=arm.pose.bones[up].head.copy();direction=target-hip;distance=direction.length;direction.normalize()
                l1,l2=u.length,l.length;distance=max(abs(l1-l2)+1e-5,min(distance,l1+l2-1e-5));target=hip+direction*distance
                along=(l1*l1-l2*l2+distance*distance)/(2*distance)
                bend=(u.tail_local-u.head_local);bend=motion.to_3x3()@bend;bend-=direction*bend.dot(direction)
                if bend.length<1e-6:bend=Vector((0,1,0))-direction*direction.y
                bend.normalize();knee=hip+direction*along+bend*math.sqrt(max(0,l1*l1-along*along))
                aim(up,hip,knee);aim(low,knee,target)
                mat=motion@rest[foot];mat.translation=target;arm.pose.bones[foot].matrix=mat
                bpy.context.view_layer.update()
            for pb in arm.pose.bones:
                for prop in ('location','rotation_quaternion','scale'):pb.keyframe_insert(data_path=prop,frame=f,group=pb.name)
        authored[clip]='anatomically fitted quadruped; analytic two-segment legs; baked at 24fps'
    authored['hit_react']='0.6s dedicated recoil; fixed foot targets; no body roll'
    authored['attack_heavy']='0.36s held anticipation then '+('thagomizer sweep' if A.species=='stegosaurus' else 'head thrust')
    authored['knockdown']='90-degree side collapse ending with grounded hold'

# Retargeted limb lengths differ from the donor's. Move the separate foot
# deformers to the end of their shin chains before baking, preventing tearing.
# Bake ground correction into the shared root so no vertex passes through floor.
scene=bpy.context.scene
for act in list(bpy.data.actions):
    arm.animation_data.action=act
    if act.slots:arm.animation_data.action_slot=act.slots[0]
    f0,f1=frames(act);poses=[]
    for f in range(f0,f1+1):
        scene.frame_set(f);bpy.context.view_layer.update()
        for foot in [b for b in arm.pose.bones if 'Foot.' in b.name and not b.name.endswith('_end')]:
            lower=arm.pose.bones.get(foot.name.replace('Foot.','LowLeg.'))
            if lower:
                mat=foot.matrix.copy();mat.translation=lower.tail.copy();foot.matrix=mat
        bpy.context.view_layer.update()
        ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());em=ev.to_mesh();minimum=min((ev.matrix_world@v.co).z for v in em.vertices);ev.to_mesh_clear()
        if minimum < 0:
            root=next(p for p in arm.pose.bones if p.parent is None);mat=root.matrix.copy();mat.translation.z-=minimum;root.matrix=mat;bpy.context.view_layer.update()
        poses.append({p.name:p.matrix_basis.copy() for p in arm.pose.bones})
    for f,pose in zip(range(f0,f1+1),poses):
        for pb in arm.pose.bones:
            pb.matrix_basis=pose[pb.name];pb.rotation_mode='QUATERNION'
            for prop in ('location','rotation_quaternion','scale'):pb.keyframe_insert(data_path=prop,frame=f,group=pb.name)
    if act.name in {'idle','walk','run'}:
        delta=max(abs(a-b) for name in poses[0] for row0,row1 in zip(poses[0][name],poses[-1][name]) for a,b in zip(row0,row1))
        if delta>1e-5:
            # Some donor runs omit the repeated first pose. Add the closing
            # sample so Godot cannot snap at the loop boundary.
            for pb in arm.pose.bones:
                pb.matrix_basis=poses[0][pb.name]
                for prop in ('location','rotation_quaternion','scale'):pb.keyframe_insert(data_path=prop,frame=f1+1,group=pb.name)
    for fc in all_fcurves(act):
        for k in fc.keyframe_points:k.interpolation='LINEAR'

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
        for pb in arm.pose.bones: pb.matrix_basis.identity()
        bpy.context.view_layer.update()
        mesh.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
        export_animations=action is not None, export_animation_mode="ACTIVE_ACTIONS",
        export_frame_range=True, export_force_sampling=True, export_skins=True, export_yup=True,
        export_image_format="AUTO", export_materials="EXPORT" if action is None else "NONE")
    log(f"  wrote {path}  {path.stat().st_size // 1024} KB")


export(dest / f"{A.species}.glb")
clip_info = {}
for act in sorted(bpy.data.actions, key=lambda a: a.name):
    export(dest / "anim" / f"{act.name}.glb", act)
    f0, f1 = frames(act)
    clip_info[act.name] = {"frames": [f0, f1], "seconds": round((f1 - f0) / FPS, 3)}
log("PIPELINE " + json.dumps({"species": A.species, "route": "skeleton_transplant_v3", "mesh": A.mesh, "donor": A.donor,
    "forward_axis": "+Z", "source_height_m": round(H, 4), "source_length_m": round(L, 4),
    "repair": repair, "warp": warp_info, "weights": weight_info, "authored_clips": authored, "clips": clip_info}))

# Preserve an editable source scene with the validated actions and packed maps.
arm.animation_data.action=bpy.data.actions.get('idle')
if arm.animation_data.action and arm.animation_data.action.slots:arm.animation_data.action_slot=arm.animation_data.action.slots[0]
bpy.context.scene.frame_set(1)
for img in bpy.data.images:
    if not img.packed_file and img.filepath:
        try:img.pack()
        except RuntimeError:pass
bpy.ops.wm.save_as_mainfile(filepath=str((dest/'work'/'rigged.blend').resolve()))
