#!/usr/bin/env python3
"""Repair the transplanted Stegosaurus skin weights without touching the rig.

Why: tools/transplant_rig.py paints quadruped weights from a soft anatomical
blend. On the stegosaurus mesh that blend leaks leg weights onto the flanks,
neck and the dorsal plates, so walk/run shear the body like a worm and the
plates split off. This tool keeps the donor skeleton, bone names and the clip
files untouched and replaces only the skin weights:

  * spine chain: partition of unity in arc length along Head..Tail5 (2 bones)
  * legs: one limb quadrant at a time, gated below the hip joint and away from
    the midline, blended up the chain (3 bones) -> max 4 influences per vertex
  * dorsal plates and tail spikes: each fin component is pinned to the spine
    weights at its own root, so the whole plate moves rigidly with its local
    spine bone instead of being torn between bones (or a leg)

It prints a BEFORE table (shipped GLB), an AFTER table (repaired weights) and
renders QA poses. Nothing outside game/assets/creatures/stegosaurus/work/ is
written.

Usage (repo root, headless):
  Blender --background --python tools/stego_weight_repair.py -- \
      [--base <glb>] [--probe] [--skip-render] [--out <glb>] [--qa <dir>]
"""
from __future__ import annotations

import argparse
import json
import math
import pathlib
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPECIES = "stegosaurus"
ASSET = ROOT / "game" / "assets" / "creatures" / SPECIES
DEFAULT_BASE = ASSET / f"{SPECIES}.glb"
FALLBACK_MESH = ASSET / "work" / "stegosaurus_i2m_v1.glb"
DONOR = ROOT / "tools" / "standins" / "quaternius" / "Triceratops.fbx"
WORK = ASSET / "work"
QA = WORK / "qa" / "weight-repair-v1"
DEFAULT_OUT = WORK / "stegosaurus_repaired.glb"

SPINE = ["Head", "Neck", "Shoulders", "Torso", "Hips", "Back",
         "Tail1", "Tail2", "Tail3", "Tail4", "Tail5"]
LIMBS = {
    "Front.L": ["FrontUpLeg.L", "FrontLowLeg.L", "FrontFoot.L"],
    "Front.R": ["FrontUpLeg.R", "FrontLowLeg.R", "FrontFoot.R"],
    "Back.L": ["BackUpLeg.L", "BackLowLeg.L", "BackFoot.L"],
    "Back.R": ["BackUpLeg.R", "BackLowLeg.R", "BackFoot.R"],
}
HIP_BONE = {"Front": "FrontUpLeg", "Back": "BackUpLeg"}
LEG_BONES = {b for bones in LIMBS.values() for b in bones}
CLIPS = ["alert", "attack_heavy", "attack_primary", "death", "hit_react",
         "idle", "knockdown", "run", "walk"]
PREVIEW_CLIPS = ["idle", "walk", "attack_heavy", "knockdown"]

# Weight design constants (metres, model is 0.85 m tall / 1.90 m long).
PLATE_HEIGHT = 0.085      # above the local spine line => plate/spike fin
DIST_IN, DIST_OUT = 0.045, 0.105   # distance falloff around a leg chain
MIDLINE_IN, MIDLINE_OUT = 0.030, 0.060  # keep leg weights off the midline
LEG_HEADROOM = 0.06       # leg weight allowed on top of the anatomical gate


def log(*args):
    print(*args, flush=True)


def smoothstep(a, b, x):
    if abs(b - a) < 1e-9:
        return 1.0 if x >= b else 0.0
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------ loading
def load_glb(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24
    bpy.ops.import_scene.gltf(filepath=str(path))
    arm = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    meshes = [o for o in bpy.context.scene.objects
              if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)]
    mesh = max(meshes, key=lambda o: len(o.data.vertices)) if meshes else None
    return arm, mesh


def rebuild_from_work():
    """Shipped GLB is mesh-only: rebuild mesh + donor rig from work/ sources."""
    log("FALLBACK: shipped GLB carries no armature; rebuilding from work/ sources")
    manifest = WORK / "rig_manifest.json"
    if not (FALLBACK_MESH.is_file() and manifest.is_file()):
        raise SystemExit(f"FALLBACK: need {FALLBACK_MESH} and {manifest}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 24
    bpy.ops.import_scene.gltf(filepath=str(FALLBACK_MESH))
    mesh = max((o for o in bpy.context.scene.objects if o.type == "MESH"),
               key=lambda o: len(o.data.vertices))
    mesh.data.transform(mesh.matrix_world)
    mesh.matrix_world.identity()
    for o in list(bpy.data.objects):
        if o is not mesh:
            bpy.data.objects.remove(o, do_unlink=True)
    if not DONOR.is_file():
        raise SystemExit(f"FALLBACK: missing donor rig {DONOR}")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(DONOR))
    arm = next(o for o in bpy.data.objects if o not in before and o.type == "ARMATURE")
    for o in [o for o in bpy.data.objects if o not in before and o.type == "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    # Re-apply the recorded landmark warp so the bone rests match the mesh.
    warp = json.loads(manifest.read_text()).get("warp", {})
    if warp.get("mode") != "quadruped_landmarks":
        raise SystemExit("FALLBACK: rig_manifest has no quadruped landmark warp")
    old = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones}
    vec = np.array([tuple(v.co) for v in mesh.data.vertices])
    lo, hi = vec.min(0), vec.max(0)
    old_y = [old["Head_end"][1].y, old["FrontFoot.L"][0].y,
             old["BackFoot.L"][0].y, old["Tail5_end"][1].y]
    new_y = [float(lo[1]), warp["front_foot_y"], warp["back_foot_y"], float(hi[1])]
    tail_z = float(np.median(vec[vec[:, 1] > hi[1] - 0.08 * (hi[1] - lo[1])][:, 2]))
    zs = [warp["head_z"] / max(old["Head"][0].z, 1e-5),
          warp["shoulder_z"] / max(old["Shoulders"][0].z, 1e-5),
          warp["hip_z"] / max(old["Hips"][0].z, 1e-5),
          tail_z / max(old["Tail5_end"][1].z, 1e-5)]
    xs = warp["foot_half_width"] / abs(old["BackFoot.L"][0].x)

    def warp_q(p):
        y = float(np.interp(p.y, old_y, new_y))
        return Vector((p.x * xs, y, p.z * float(np.interp(p.y, old_y, zs))))

    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in arm.data.edit_bones:
        eb.head, eb.tail = warp_q(old[eb.name][0]), warp_q(old[eb.name][1])
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in arm.data.bones:
        bone.use_deform = not (bone.name in {"root", "Body"} or bone.name.endswith("_end"))
    for vg in list(mesh.vertex_groups):
        mesh.vertex_groups.remove(vg)
    mesh.parent = arm
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return arm, mesh


def rest_points(mesh):
    """Vertex positions with every pose cleared (the skin's rest pose)."""
    arm = next((o for o in mesh.modifiers if o.type == "ARMATURE"), None)
    saved = None
    if arm and arm.object and arm.object.animation_data:
        saved = arm.object.animation_data.action
        arm.object.animation_data.action = None
    for obj in bpy.context.scene.objects:
        if obj.type == "ARMATURE":
            for pb in obj.pose.bones:
                pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    pts = deformed_points(mesh)
    if arm and arm.object and arm.object.animation_data and saved is not None:
        arm.object.animation_data.action = saved
        if getattr(saved, "slots", None):
            arm.object.animation_data.action_slot = saved.slots[0]
    bpy.context.view_layer.update()
    return pts


def deformed_points(mesh):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    data = ev.to_mesh()
    pts = np.array([tuple(ev.matrix_world @ v.co) for v in data.vertices], dtype=np.float64)
    ev.to_mesh_clear()
    return pts


# ---------------------------------------------------------------- geometry
def components(mesh, keep=None):
    """Connected components over mesh edges, optionally restricted to a mask."""
    n = len(mesh.data.vertices)
    parent = np.arange(n)

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for e in mesh.data.edges:
        a, b = int(e.vertices[0]), int(e.vertices[1])
        if keep is not None and not (keep[a] and keep[b]):
            continue
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra
    ids = np.array([find(i) for i in range(n)])
    if keep is not None:
        ids = np.where(keep, ids, -1)
    return ids


def spine_polyline(arm):
    """Ordered centre-line through the spine bones, plus per-bone arc centres."""
    mids, tails = [], []
    pts = [np.array(arm.data.bones["Head"].tail_local)]
    for name in SPINE:
        b = arm.data.bones.get(name)
        if b is None:
            raise SystemExit(f"armature has no {name} bone")
        mid = (np.array(b.head_local) + np.array(b.tail_local)) / 2.0
        mids.append((name, mid))
        pts.append(mid)
    pts.append(np.array(arm.data.bones[SPINE[-1]].tail_local))
    pts = np.array(pts)
    cuts = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
    # Arc position of each bone centre (index matches SPINE order).
    centres = cuts[1:-1]
    return pts, cuts, centres, [name for name, _ in mids]


def project_arc(points, poly, cuts):
    """Arc coordinate of the closest point on each polyline segment per point."""
    best_d = np.full(len(points), np.inf)
    best_s = np.zeros(len(points))
    for i in range(len(poly) - 1):
        a, b = poly[i], poly[i + 1]
        ab = b - a
        denom = float(ab @ ab)
        if denom < 1e-12:
            d = np.linalg.norm(points - a, axis=1)
            s = np.full(len(points), cuts[i])
        else:
            t = np.clip(((points - a) @ ab) / denom, 0.0, 1.0)
            d = np.linalg.norm(points - (a + t[:, None] * ab), axis=1)
            s = cuts[i] + t * math.sqrt(denom)
        closer = d < best_d
        best_d = np.where(closer, d, best_d)
        best_s = np.where(closer, s, best_s)
    return best_s, best_d


def chain_points(arm, names):
    pts = [np.array(arm.data.bones[names[0]].head_local)]
    for name in names:
        pts.append(np.array(arm.data.bones[name].tail_local))
    return np.array(pts)


def polyline_distance(points, poly):
    best = np.full(len(points), np.inf)
    for i in range(len(poly) - 1):
        a, b = poly[i], poly[i + 1]
        ab = b - a
        denom = float(ab @ ab)
        if denom < 1e-12:
            d = np.linalg.norm(points - a, axis=1)
        else:
            t = np.clip(((points - a) @ ab) / denom, 0.0, 1.0)
            d = np.linalg.norm(points - (a + t[:, None] * ab), axis=1)
        best = np.minimum(best, d)
    return best


def pair_weights(samples, x):
    """smoothstep blend between the two bracketing samples (2 bones max)."""
    if x <= samples[0][0]:
        return {samples[0][1]: 1.0}
    if x >= samples[-1][0]:
        return {samples[-1][1]: 1.0}
    for (lo, n0), (hi, n1) in zip(samples, samples[1:]):
        if lo <= x <= hi:
            t = smoothstep(lo, hi, x)
            return {n0: 1.0 - t, n1: t}
    return {samples[-1][1]: 1.0}


def plate_components(mesh, rest, arm):
    """Each dorsal fin / tail spike becomes one rigid component.

    Vertices above the local spine line by PLATE_HEIGHT belong to a fin; the
    fins are disconnected from each other (and from the body core top), so
    connected components over that mask recover one component per plate.
    """
    poly, cuts, centres, names = spine_polyline(arm)
    _, spine_d = project_arc(rest, poly, cuts)
    body_axis_y = rest[:, 1]
    local_z = np.interp(body_axis_y, poly[:, 1], poly[:, 2])
    mask = (rest[:, 2] - local_z) > PLATE_HEIGHT
    ids = components(mesh, keep=mask)
    comps = []
    for cid in np.unique(ids):
        if cid < 0:
            continue
        idx = np.where(ids == cid)[0]
        if len(idx) < 8:
            continue
        span_y = rest[idx, 1].max() - rest[idx, 1].min()
        span_z = rest[idx, 2].max() - rest[idx, 2].min()
        if span_y > 0.30 or span_z > 0.40:      # not a fin, leave it alone
            continue
        comps.append(idx)
    plate_mask = np.zeros(len(rest), dtype=bool)
    for idx in comps:
        plate_mask[idx] = True
    return comps, plate_mask


# ---------------------------------------------------------------- weighting
def build_weights(mesh, arm, rest):
    poly, cuts, centres, names = spine_polyline(arm)
    samples = [(float(c), n) for c, n in zip(centres, names)]
    s_all, _ = project_arc(rest, poly, cuts)

    legs = {}
    for side, bones in LIMBS.items():
        poly_leg = chain_points(arm, bones)
        d = polyline_distance(rest, poly_leg)
        hip_z = float(arm.data.bones[bones[0]].head_local.z)
        # Zero above the hip joint: leg rotation must not drag the flank or spine.
        z_gate = 1.0 - np.array([smoothstep(hip_z - 0.09, hip_z + 0.01, z) for z in rest[:, 2]])
        lateral = np.array([smoothstep(MIDLINE_IN, MIDLINE_OUT, abs(x)) for x in rest[:, 0]])
        near = np.array([1.0 - smoothstep(DIST_IN, DIST_OUT, x) for x in d])
        mask = z_gate * lateral * near
        if mask.max() <= 0.0:
            continue
        mid = (arm.data.bones[bones[0]].head_local.z + arm.data.bones[bones[1]].head_local.z) / 2
        low_mid = (arm.data.bones[bones[1]].head_local.z + arm.data.bones[bones[2]].head_local.z) / 2
        leg_samples = [(float(arm.data.bones[bones[2]].head_local.z), bones[2]),
                       (float(low_mid), bones[1]),
                       (float(mid), bones[0])]
        legs[side] = (mask, leg_samples)

    spine_w = [pair_weights(samples, float(s)) for s in s_all]
    # Only one limb quadrant may touch a vertex: blend competing masks by weight.
    leg_total = np.zeros(len(rest))
    leg_field = [np.zeros(len(rest)) for _ in legs]
    for k, (side, (mask, _s)) in enumerate(legs.items()):
        leg_field[k] = mask
        leg_total = np.maximum(leg_total, mask)
    norm = np.maximum(leg_total, 1e-9)

    weights = []
    for i in range(len(rest)):
        w = {n: v * (1.0 - leg_total[i]) for n, v in spine_w[i].items()}
        if leg_total[i] > 1e-6:
            acc = {}
            for k, (side, (mask, leg_samples)) in enumerate(legs.items()):
                share = leg_field[k][i] / norm[i]
                if share <= 1e-6:
                    continue
                for n, v in pair_weights(leg_samples, float(rest[i, 2])).items():
                    acc[n] = acc.get(n, 0.0) + share * v
            scale = leg_total[i]
            for n, v in acc.items():
                w[n] = w.get(n, 0.0) + v * scale
        w = {n: v for n, v in w.items() if v > 1e-5}
        if len(w) > 4:      # keep the four strongest, never more (glTF cap)
            w = dict(sorted(w.items(), key=lambda kv: -kv[1])[:4])
        total = sum(w.values())
        if total <= 0.0:
            w = {samples[len(samples) // 2][1]: 1.0}
            total = 1.0
        weights.append({n: v / total for n, v in w.items()})

    comps, plate_mask = plate_components(mesh, rest, arm)
    # Spatial relaxation: split/shaded vertices mean topology neighbours miss
    # the real surface, so smooth over a 4.5 cm radius KD neighbourhood. This
    # removes the abrupt weight step across the hip/shoulder seam (the source
    # of the worm-like shear) without moving any weight to a distant bone.
    # Six passes, 4.5 cm radius: measured best across all nine clips (walk peak
    # 2.68 -> 2.55, run 3.34 -> 3.15) with plate edges untouched. A wider
    # radius (5.5 cm) did not help and leaked more leg weight into the flanks.
    from mathutils.kdtree import KDTree
    from collections import defaultdict
    body_idx = np.where(~plate_mask)[0]
    kd = KDTree(len(body_idx))
    for slot, vi in enumerate(body_idx):
        kd.insert(Vector(rest[vi]), int(vi))
    kd.balance()
    radius = 0.045
    neighbours = []
    for vi in body_idx:
        near = [(int(j), math.exp(-((d / radius) ** 2)))
                for _co, j, d in kd.find_range(Vector(rest[vi]), radius)]
        total = sum(w for _, w in near)
        neighbours.append([(j, w / total) for j, w in near] if total > 0 else [(int(vi), 1.0)])
    index_of = {int(vi): k for k, vi in enumerate(body_idx)}
    for _ in range(6):
        updated = []
        for vi, near in zip(body_idx, neighbours):
            acc = defaultdict(float)
            for j, w in near:
                for n, v in weights[j].items():
                    acc[n] += v * w
            updated.append(dict(acc))
        for vi, w in zip(body_idx, updated):
            weights[int(vi)] = {n: v for n, v in w.items() if v > 1e-5}
    del index_of

    # Guard rail: relaxation drags a little leg weight into the flank. Clamp
    # each body vertex's total leg weight to what the anatomical gate allows
    # before smoothing, and push the excess back onto the spine bones.
    # LEG_HEADROOM is the portion of the hip crease the anatomical gate would
    # otherwise denude: carved away entirely the crease tears (run peak 3.8),
    # left fully relaxed it leaks leg weight onto the flank (6.7% -> 7.1%+).
    for i in body_idx:
        allowed = float(leg_total[i]) + LEG_HEADROOM
        w = weights[int(i)]
        leg_sum = sum(v for n, v in w.items() if n in LEG_BONES)
        if leg_sum <= allowed + 1e-9:
            continue
        scale = allowed / leg_sum
        legs_now = {n: v * scale for n, v in w.items() if n in LEG_BONES}
        spine_now = {n: v for n, v in w.items() if n not in LEG_BONES}
        spine_sum = sum(spine_now.values())
        if spine_sum <= 1e-9:      # keep the skin rigid to its local spine bone
            spine_now = pair_weights(samples, float(s_all[int(i)]))
            spine_sum = sum(spine_now.values())
        want = 1.0 - sum(legs_now.values())
        spine_now = {n: v * want / spine_sum for n, v in spine_now.items()}
        merged = dict(spine_now)
        for n, v in legs_now.items():
            merged[n] = merged.get(n, 0.0) + v
        weights[int(i)] = {n: v for n, v in merged.items() if v > 1e-5}

    # Rigid plates: each fin copies the smoothed body weights at its own root,
    # so the plate/body seam carries no weight discontinuity.
    pinned = 0
    for idx in comps:
        root_idx = idx[rest[idx, 2] < np.quantile(rest[idx, 2], 0.25) + 1e-6]
        if not len(root_idx):
            root_idx = idx
        acc = defaultdict(float)
        for i in root_idx:
            near = kd.find(Vector(rest[i]))
            for n, v in weights[int(near[1])].items():
                acc[n] += v
        total = sum(acc.values())
        rigid = {n: v / total for n, v in acc.items() if v / total > 1e-4}
        if len(rigid) > 4:
            rigid = dict(sorted(rigid.items(), key=lambda kv: -kv[1])[:4])
            total = sum(rigid.values())
            rigid = {n: v / total for n, v in rigid.items()}
        for i in idx:
            weights[i] = dict(rigid)
        pinned += len(idx)
    log(f"PLATES pinned {len(comps)} fin components, {pinned} vertices "
        f"({100.0 * plate_mask.mean():.1f}% of the mesh)")
    return weights, plate_mask, comps, s_all


def apply_weights(mesh, arm, weights):
    for vg in list(mesh.vertex_groups):
        mesh.vertex_groups.remove(vg)
    deform = [b.name for b in arm.data.bones if b.use_deform]
    groups = {n: mesh.vertex_groups.new(name=n) for n in deform}
    for i, w in enumerate(weights):
        for name, value in w.items():
            if name in groups:
                groups[name].add([i], float(value), "REPLACE")
    # Enforce the pipeline contract: max four influences, normalized.
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    bpy.ops.object.select_all(action="DESELECT")


# ------------------------------------------------------------------ metrics
def import_clips(arm):
    actions = []
    for name in CLIPS:
        path = ASSET / "anim" / f"{name}.glb"
        if not path.is_file():
            raise SystemExit(f"missing clip {path}")
        objs, acts = set(bpy.data.objects), set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=str(path))
        new_actions = set(bpy.data.actions) - acts
        for o in set(bpy.data.objects) - objs:
            bpy.data.objects.remove(o, do_unlink=True)
        if not new_actions:
            raise SystemExit(f"clip {name} carries no action")
        act = sorted(new_actions, key=lambda a: a.name)[0]
        if arm.animation_data is None:
            arm.animation_data_create()
        for tr in list(arm.animation_data.nla_tracks):
            arm.animation_data.nla_tracks.remove(tr)
        actions.append((name, act))
    return actions


def weight_table(mesh):
    index_name = {g.index: g.name for g in mesh.vertex_groups}
    return [sorted([(index_name[g.group], float(g.weight)) for g in v.groups if g.weight > 1e-7],
                   key=lambda kv: -kv[1]) for v in mesh.data.vertices]


def leakage(mesh, rest, plate_mask, arm):
    w = weight_table(mesh)
    dominant = np.array([x[0][0] if x else "" for x in w])
    any_leg = np.array([any(n in LEG_BONES and v > 0.05 for n, v in x) for x in w])
    heavy_leg = np.array([any(n in LEG_BONES and v > 0.15 for n, v in x) for x in w])
    leg_mass = np.array([sum(v for n, v in x if n in LEG_BONES) for x in w])
    is_leg = np.array([bool(d) and d in LEG_BONES for d in dominant])
    midline = np.abs(rest[:, 0]) < 0.25 * np.abs(rest[:, 0]).max()
    body = ~plate_mask & ~is_leg
    # Neck/head ahead of the front legs and tail behind the hind legs: no leg
    # bone may drive skin there. This is the leak that tore the neck in the
    # shipped weights (e.g. Neck+Shoulders+FrontUpLeg on one vertex).
    ys = [float(arm.data.bones[b].head_local.y) for bones in LIMBS.values()
          for b in bones[:1]]
    y_lo, y_hi = min(ys), max(ys)
    outside = ~plate_mask & ~is_leg & ((rest[:, 1] < y_lo) | (rest[:, 1] > y_hi))
    return {
        "body_leg_fraction": round(float(any_leg[body].mean()) if body.any() else 0.0, 4),
        "body_heavy_leg_fraction": round(float(heavy_leg[body].mean()) if body.any() else 0.0, 4),
        "neck_tail_leg_fraction": round(float(heavy_leg[outside].mean()) if outside.any() else 0.0, 4),
        "body_leg_mass": round(float(leg_mass[body].sum() / max(1, body.sum())), 4),
        "midline_leg_fraction": round(float(any_leg[midline & ~is_leg].mean())
                                      if (midline & ~is_leg).any() else 0.0, 4),
        "plate_leg_fraction": round(float(any_leg[plate_mask].mean()) if plate_mask.any() else 0.0, 4),
        "plate_spine_only": round(float(np.mean([all(n in SPINE for n, _ in x)
                                                 for x, p in zip(w, plate_mask) if p]))
                                  if plate_mask.any() else 0.0, 4),
        "max_influences": int(max((len(x) for x in w), default=0)),
        "weight_sum_error": float(max((abs(sum(v for _, v in x) - 1.0) for x in w), default=0.0)),
        "groups_used": len({n for x in w for n, _ in x}),
    }, w


def audit(mesh, arm, rest, plate_comps, plate_mask, actions, label):
    edges = np.array([e.vertices[:] for e in mesh.data.edges], dtype=int)
    rest_len = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
    valid = rest_len > 1e-5
    leak, wtab = leakage(mesh, rest, plate_mask, arm)
    dominant = np.array([x[0][0] if x else "" for x in wtab])
    same_bone = dominant[edges[:, 0]] == dominant[edges[:, 1]]
    comp_of = np.full(len(rest), -1)
    for k, idx in enumerate(plate_comps):
        comp_of[idx] = k
    same_plate = (comp_of[edges[:, 0]] == comp_of[edges[:, 1]]) & (comp_of[edges[:, 0]] >= 0)
    non_plate = ~plate_mask
    from mathutils.kdtree import KDTree
    surface_mask = non_plate
    report = {"clips": {}, "leaks": leak, "plate_components": len(plate_comps)}

    def kd_of(points, subset):
        kd = KDTree(int(subset.sum()))
        for j in np.where(subset)[0]:
            kd.insert(Vector(points[j]), int(j))
        kd.balance()
        return kd

    rest_kd = kd_of(rest, surface_mask)
    rest_gap = np.array([rest_kd.find(Vector(rest[idx].mean(0)))[2] for idx in plate_comps]) \
        if plate_comps else np.zeros(0)
    for name, action in actions:
        if arm.animation_data is None:
            arm.animation_data_create()
        arm.animation_data.action = action
        if getattr(action, "slots", None) and len(action.slots):
            arm.animation_data.action_slot = action.slots[0]
        for tr in list(arm.animation_data.nla_tracks):
            arm.animation_data.nla_tracks.remove(tr)
        f0, f1 = action.frame_range
        worst = {"max_edge_ratio": 0.0, "p99_edge_ratio": 0.0,
                 "plate_edge_ratio": 0.0, "plate_sep_growth": 0.0,
                 "worst_bone": "", "worst_bone_ratio": 0.0}
        for t in np.linspace(0.0, 1.0, 9):
            frame = f0 + t * (f1 - f0)
            bpy.context.scene.frame_set(int(frame), subframe=float(frame % 1))
            bpy.context.view_layer.update()
            pts = deformed_points(mesh)
            if not np.isfinite(pts).all():
                raise SystemExit(f"{label}/{name}: non-finite skinned positions")
            ratio = np.linalg.norm(pts[edges[:, 0]] - pts[edges[:, 1]], axis=1) / rest_len
            r = np.where(valid, ratio, 1.0)
            worst["p99_edge_ratio"] = max(worst["p99_edge_ratio"], float(np.quantile(r, 0.99)))
            i = int(np.argmax(r))
            if float(r[i]) > worst["max_edge_ratio"]:
                worst["max_edge_ratio"] = float(r[i])
                worst["worst_bone"] = str(dominant[edges[i, 0]] if same_bone[i]
                                          else dominant[edges[i, 0]] + "|" + dominant[edges[i, 1]])
            if same_bone.any():
                for bone in np.unique(dominant[edges[same_bone, 0]]):
                    pick = same_bone & (dominant[edges[:, 0]] == bone)
                    if pick.sum() < 50:
                        continue
                    worst["worst_bone_ratio"] = max(
                        worst["worst_bone_ratio"],
                        float(np.quantile(r[pick], 0.995)))
            if same_plate.any():
                worst["plate_edge_ratio"] = max(worst["plate_edge_ratio"], float(r[same_plate].max()))
            if plate_comps:
                kd = kd_of(pts, surface_mask)
                gaps = np.array([kd.find(Vector(pts[idx].mean(0)))[2] for idx in plate_comps])
                worst["plate_sep_growth"] = max(worst["plate_sep_growth"],
                                                float(np.max(gaps - rest_gap)))
        for k in ("max_edge_ratio", "p99_edge_ratio", "plate_edge_ratio",
                  "plate_sep_growth", "worst_bone_ratio"):
            worst[k] = round(worst[k], 3)
        report["clips"][name] = worst
    arm.animation_data.action = None
    return report


def print_table(label, report):
    log(f"\n{label}")
    log(f"{'clip':<15}{'max_edge':>9}{'p99_edge':>9}{'bone_p995':>11}"
        f"{'plate_edge':>11}{'plate_sep':>10}  worst")
    for name in CLIPS:
        c = report["clips"][name]
        log(f"{name:<15}{c['max_edge_ratio']:>9.2f}{c['p99_edge_ratio']:>9.2f}"
            f"{c['worst_bone_ratio']:>11.2f}{c['plate_edge_ratio']:>11.2f}"
            f"{c['plate_sep_growth']:>10.3f}  {c['worst_bone']}")
    leak = report["leaks"]
    log(f"leaks: body verts w/ leg weight >0.05 {leak['body_leg_fraction'] * 100:.1f}% "
        f"(>0.15 {leak['body_heavy_leg_fraction'] * 100:.1f}%, mean mass "
        f"{leak['body_leg_mass']:.3f}), neck/tail {leak['neck_tail_leg_fraction'] * 100:.1f}%, "
        f"midline {leak['midline_leg_fraction'] * 100:.1f}%, "
        f"plates {leak['plate_leg_fraction'] * 100:.1f}% "
        f"(spine-only plate verts {leak['plate_spine_only'] * 100:.1f}%)")
    log(f"weights: max influences {leak['max_influences']}, "
        f"sum error {leak['weight_sum_error']:.2e}, groups used {leak['groups_used']}, "
        f"plate components {report['plate_components']}")
    worst = max(c["p99_edge_ratio"] for c in report["clips"].values())
    log(f"worst clip p99 edge ratio: {worst:.2f}")


# ---------------------------------------------------------------- exports
def export_glb(path):
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    mesh = max((o for o in bpy.context.scene.objects
                if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)),
               key=lambda o: len(o.data.vertices))
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    if getattr(arm, "animation_data", None):
        for tr in list(arm.animation_data.nla_tracks):
            arm.animation_data.nla_tracks.remove(tr)
    bpy.context.scene.frame_set(1)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                              export_animations=False, export_skins=True, export_yup=True,
                              export_image_format="AUTO", export_materials="EXPORT")
    log(f"WROTE {path}  {path.stat().st_size // 1024} KB")


def render_previews(out_dir):
    """Lit 1280x720 previews of the repaired mesh under the shipped clips."""
    scene = bpy.context.scene
    arm = next(o for o in scene.objects if o.type == "ARMATURE")
    mesh = max((o for o in scene.objects
                if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)),
               key=lambda o: len(o.data.vertices))
    for obj in list(scene.objects):
        if obj.type == "MESH" and obj is not mesh:
            bpy.data.objects.remove(obj, do_unlink=True)   # stray icosphere
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("QAWorld")
    scene.world.use_nodes = True
    bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.055, 0.07, 0.09, 1.0)
    bg.inputs["Strength"].default_value = 0.8
    scene.view_settings.view_transform = "AgX"
    cam = bpy.data.objects.new("QACamera", bpy.data.cameras.new("QACamera"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.type = "ORTHO"
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    pts = deformed_points(mesh)
    lo, hi = pts.min(0), pts.max(0)
    center = Vector(((lo + hi) / 2).tolist())
    span = float(np.linalg.norm(hi - lo))
    cam.data.ortho_scale = span * 1.25
    cam.data.clip_end = span * 20
    cam.data.clip_start = 0.001
    for offset, power in [((1, -1, 2), 190), ((-1, -0.5, 1), 90), ((0, 2, 2), 130)]:
        light = bpy.data.objects.new("Softbox", bpy.data.lights.new("Softbox", "AREA"))
        scene.collection.objects.link(light)
        light.location = center + Vector(offset) * span
        light.data.energy = power * span * span
        light.data.size = span * 1.5
        light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()
    out_dir.mkdir(parents=True, exist_ok=True)
    views = {"side": (1, -0.05, 0.06), "three_quarter": (1, -1, 0.6)}
    for clip in PREVIEW_CLIPS:
        path = ASSET / "anim" / f"{clip}.glb"
        objs, acts = set(bpy.data.objects), set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=str(path))
        act = sorted(set(bpy.data.actions) - acts, key=lambda a: a.name)[0]
        for o in set(bpy.data.objects) - objs:
            bpy.data.objects.remove(o, do_unlink=True)
        if arm.animation_data is None:
            arm.animation_data_create()
        arm.animation_data.action = act
        if getattr(act, "slots", None) and len(act.slots):
            arm.animation_data.action_slot = act.slots[0]
        for tr in list(arm.animation_data.nla_tracks):
            arm.animation_data.nla_tracks.remove(tr)
        f0, f1 = act.frame_range
        for frac in (0.35, 0.6):
            frame = f0 + (f1 - f0) * frac
            scene.frame_set(int(frame), subframe=float(frame % 1))
            bpy.context.view_layer.update()
            p = deformed_points(mesh)
            mid = Vector(((p.min(0) + p.max(0)) / 2).tolist())
            for view, direction in views.items():
                cam.location = mid + Vector(direction).normalized() * span * 3
                cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
                # Fit the deformed pose, not the rest pose: attacks swing the
                # tail and knockdown lays the body out sideways.
                bpy.context.view_layer.update()
                inv = cam.matrix_world.inverted()
                proj = np.array([tuple(inv @ Vector(p)) for p in p])
                # ortho_scale spans the wider image axis; the vertical budget is
                # that times the aspect ratio, so portrait-ish poses need more.
                aspect = scene.render.resolution_y / scene.render.resolution_x
                cam.data.ortho_scale = max(float(np.ptp(proj[:, 0])),
                                           float(np.ptp(proj[:, 1])) / aspect) * 1.18
                scene.render.filepath = str(
                    (out_dir / f"{clip}_f{int(frac * 100):02d}_{view}.png").resolve())
                bpy.ops.render.render(write_still=True)
                log(f"RENDERED {scene.render.filepath}")
        arm.animation_data.action = None
        bpy.data.actions.remove(act)


# -------------------------------------------------------------------- main
def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--base", type=pathlib.Path, default=DEFAULT_BASE)
    p.add_argument("--out", type=pathlib.Path, default=DEFAULT_OUT)
    p.add_argument("--qa", type=pathlib.Path, default=QA)
    p.add_argument("--json", type=pathlib.Path, default=None,
                   help="write BEFORE/AFTER metrics as JSON here")
    p.add_argument("--probe", action="store_true", help="print contents and BEFORE metrics")
    p.add_argument("--skip-render", action="store_true")
    a = p.parse_args(args)

    base = a.base if a.base.is_file() else DEFAULT_BASE
    arm, mesh = load_glb(base)
    if arm is None or mesh is None:
        log(f"PROBE: {base} has armature={bool(arm)} skinned_mesh={bool(mesh)}")
        arm, mesh = rebuild_from_work()

    log(f"BASE {base}")
    log(f"mesh {mesh.name}: {len(mesh.data.vertices)} verts, {len(mesh.data.polygons)} polys, "
        f"{len(mesh.vertex_groups)} groups, materials "
        f"{[m.name if m else None for m in mesh.data.materials]}")
    log(f"armature {arm.name}: {len(arm.data.bones)} bones, "
        f"{sum(1 for b in arm.data.bones if b.use_deform)} deforming")
    log("bones " + ", ".join(b.name for b in arm.data.bones))

    rest = rest_points(mesh)
    plate_comps, plate_mask = plate_components(mesh, rest, arm)
    log(f"PLATES detected {len(plate_comps)} fin components, "
        f"{int(plate_mask.sum())} verts above the local spine line")

    actions = import_clips(arm)
    before = audit(mesh, arm, rest, plate_comps, plate_mask, actions, "BEFORE")
    print_table("BEFORE (shipped weights)", before)
    if a.probe:
        if a.json:
            a.json.parent.mkdir(parents=True, exist_ok=True)
            a.json.write_text(json.dumps({"before": before}, indent=2) + "\n")
        return

    weights, plate_mask, plate_comps, _s = build_weights(mesh, arm, rest)
    apply_weights(mesh, arm, weights)
    after = audit(mesh, arm, rest, plate_comps, plate_mask, actions, "AFTER")
    print_table("AFTER (repaired weights)", after)
    for name, act in actions:
        arm.animation_data.action = act
        bpy.data.actions.remove(act)
    arm.animation_data.action = None

    export_glb(a.out)
    if not a.skip_render:
        render_previews(a.qa)

    if a.json:
        a.json.parent.mkdir(parents=True, exist_ok=True)
        a.json.write_text(json.dumps({"before": before, "after": after}, indent=2) + "\n")
    log("\nDONE")


if __name__ == "__main__":
    main()
