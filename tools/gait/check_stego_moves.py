"""STEGOSPIN gate for the stegosaurus' spin, pivot and close clips (tools/gait/make_stego_moves.py), on the skinned mesh.

For each clip, frame by frame, in the WORLD frame: a turn clip's pose is turned back by the brain's code turn
(ai.json spiked_tail: turn_deg * smoothstep over turn [a, b], about pivot_gltf), so what is checked is what the game shows.
- planted feet: each toe ball (toe bone head) while down (within 3 cm of its idle height) must not move: the largest drift
  inside one planted stretch, FAIL above 0.06 m (the pivot foot twists about its ball, so it is checked the same way);
- leg reach: the foot bone must sit on the shin's end (a leg that cannot reach leaves a gap), FAIL above 0.03 m;
- ground: lowest skin point below -0.03 m = sinking;
- stretch: worst edge length / rest length, FAIL above 12 (check_stego.py's calibration);
- turn: the body's facing at the last frame, world frame, must be the idle facing turned by turn_deg (within 3 deg).
usage: Blender -b -P tools/gait/check_stego_moves.py -- <base.glb> <anim_dir> <ai.json> [clip ...]   (exit 1 on any FAIL)
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir, ai = a[:3]
CLIPS = a[3:] or ["spin_right", "spin_left", "pivot_right", "pivot_left", "stomp", "rear_slam", "hind_stomp_left",
                  "hind_stomp_right", "shove_left", "shove_right", "tackle"]
prof = json.load(open(ai))["archetypes"]["spiked_tail"]
TURNS = {}
for group in ("club_moves", "close_moves", "pivots"):
    for mv in prof.get(group, {}).values():
        if isinstance(mv, dict) and "turn_deg" in mv:
            TURNS[mv["clip"]] = mv
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
body = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
sc = bpy.context.scene
pbs = arm.pose.bones
FEET = ["hind_foot_L", "hind_foot_R", "front_foot_L", "front_foot_R"]
SHIN = {"hind_foot_L": "hind_shin_L", "hind_foot_R": "hind_shin_R", "front_foot_L": "front_forearm_L", "front_foot_R": "front_forearm_R"}


def pts():
    dg = bpy.context.evaluated_depsgraph_get(); e = body.evaluated_get(dg); me = e.to_mesh()
    v = np.array([body.matrix_world @ x.co for x in me.vertices]); e.to_mesh_clear(); return v


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


arm.animation_data_clear()
for pb in pbs: pb.matrix_basis.identity()
bpy.context.view_layer.update()
rest = pts()
edges = np.array([e.vertices[:] for e in body.data.edges])
rl = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1); ok = rl > 1e-3
gi = {g.index: g.name for g in body.vertex_groups}
DOM = [gi[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in body.data.vertices]


def load(clip):
    objs = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=os.path.join(anim_dir, clip + ".glb"))
    new = set(bpy.data.actions) - acts
    for o in set(bpy.data.objects) - objs: bpy.data.objects.remove(o, do_unlink=True)
    act = max(new, key=lambda x: x.frame_range[1])
    arm.animation_data_create(); arm.animation_data.action = act
    try: arm.animation_data.action_slot = act.slots[0]
    except Exception: pass
    return int(act.frame_range[0]), int(act.frame_range[1])


f0, _ = load("idle")
sc.frame_set(f0)
IDLE_Z = {f: pbs[f.replace("foot", "toe")].head.z for f in FEET}
fails = 0
for clip in CLIPS:
    if not os.path.exists(os.path.join(anim_dir, clip + ".glb")):
        print(f"CLIP {clip} FAIL missing"); fails += 1; continue
    f0, f1 = load(clip)
    mv = TURNS.get(clip)
    if mv:
        px, pz = mv["pivot_gltf"]
        P = Vector((px, -pz, 0.0))  # glTF (x, z) -> Blender (x, -z)
    runs = {f: [] for f in FEET}
    drift = {f: 0.0 for f in FEET}
    gap = stretch = 0.0
    where = ""
    lo = 9.0
    head_dir = None
    for fr in range(f0, f1 + 1):
        sc.frame_set(fr)
        u = (fr - f0) / max(1, f1 - f0)
        W = Matrix.Identity(4)
        if mv:
            t0, t1 = mv["turn"]
            T = mv["turn_deg"] * smooth((u - t0) / (t1 - t0))
            W = Matrix.Translation(P) @ Matrix.Rotation(math.radians(T), 4, "Z") @ Matrix.Translation(-P)
        for f in FEET:
            ball = W @ pbs[f.replace("foot", "toe")].head
            gap = max(gap, (pbs[f].head - pbs[SHIN[f]].tail).length)
            if ball.z <= IDLE_Z[f] + 0.03:
                runs[f].append(ball.copy())
                drift[f] = max(drift[f], max((Vector((ball.x - b.x, ball.y - b.y, 0)).length for b in runs[f])))
            else:
                runs[f] = []
        p = pts()
        lo = min(lo, float(p[:, 2].min()))
        l = np.linalg.norm(p[edges[:, 0]] - p[edges[:, 1]], axis=1)
        r = np.where(ok, l / np.maximum(rl, 1e-9), 1.0)
        if r.max() > stretch:
            stretch = float(r.max())
            where = f"{DOM[edges[int(r.argmax()), 0]]}@{fr - f0}"
        head_dir = (W.to_3x3() @ (pbs["head"].head - pbs["hips"].head))
    bad = []
    worst = max(drift.values())
    if worst > 0.06: bad.append("slide " + ", ".join(f"{k} {v:.3f}" for k, v in drift.items() if v > 0.06))
    if gap > 0.03: bad.append(f"leg gap {gap:.3f}")
    if lo < -0.03: bad.append(f"sinks {lo:.3f}")
    if stretch > 12.0: bad.append(f"stretch {stretch:.2f}")
    turned = ""
    if mv:
        got = math.degrees(math.atan2(-head_dir.x, head_dir.y))
        err = abs((got - mv["turn_deg"] + 180) % 360 - 180)
        turned = f" turn={got:.0f}/{mv['turn_deg']:.0f}"
        if err > 3.0: bad.append(f"turn off by {err:.1f}")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1 - f0 + 1} slide={worst:.3f} gap={gap:.3f} low={lo:.3f} stretch={stretch:.2f}({where}){turned}")
    fails += bool(bad)
print("STEGO_MOVES", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
