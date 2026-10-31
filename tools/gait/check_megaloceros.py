"""SP-MEGALOCEROS clip gate (check_ankylo.py adapted): the megaloceros GLBs (stag megaloceros.glb + anim/, doe
doe/megaloceros_doe.glb + doe/anim/) are built in game metres, so no rescale (--height defaults to the rest height).
Every clip in the anim dir is checked on the real skinned hide for
- stretch: worst edge length / rest length, FAIL above 12 (check_stego.py's calibration),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch, lowest <= 0.05 m),
- moonwalk: in walk/run each foot's planted run (sole within 4 cm of the floor) slides backwards (+Y in Blender: this
  rig faces -Y) or stays put; walk_back the opposite. Drift = y(end) - y(start) in metres; below -0.05 on walk/run fails,
- the hooves are the hit: at attack_heavy 0.72 (rear-up stomp) the lowest forehoof skin is on the floor (< 0.25 m) and
  at least 0.6 m ahead of where it stood; at kick 0.45 a hind hoof is at least 1.2 m behind its stance and 0.8 m up.
usage: Blender -b -P tools/gait/check_megaloceros.py -- <base.glb> <anim_dir>   (exit 1 on any FAIL)
"""
import bpy, sys, os
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else None
HIT = {"attack_heavy": 0.72, "kick": 0.45}
FPS = 24
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
body = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
sc = bpy.context.scene


def pts():
    dg = bpy.context.evaluated_depsgraph_get(); e = body.evaluated_get(dg); me = e.to_mesh()
    v = np.array([body.matrix_world @ x.co for x in me.vertices]); e.to_mesh_clear(); return v * K


arm.animation_data_clear()
for pb in arm.pose.bones: pb.matrix_basis.identity()
bpy.context.view_layer.update()
K = 1.0
rest = pts()
K = (H / (rest[:, 2].max() - rest[:, 2].min())) if H else 1.0
rest = rest * K
print(f"scale {K:.3f} (rest height {rest[:, 2].max():.2f} m, length {np.ptp(rest[:, 1]):.2f} m, width {np.ptp(rest[:, 0]):.2f} m)")
edges = np.array([e.vertices[:] for e in body.data.edges])
rl = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1); ok = rl > 1e-3
gi = {g.index: g.name for g in body.vertex_groups}
dom = np.array([gi[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in body.data.vertices])
FEET = {f"{k}_{s}": np.where(dom == f"{k}Foot.{s}")[0] for k in ("Back", "Front") for s in ("L", "R")}
FEET = {k: v for k, v in FEET.items() if len(v)}
assert len(FEET) == 4, list(FEET)
FRONT = np.concatenate([FEET["Front_L"], FEET["Front_R"]]); HIND = np.concatenate([FEET["Back_L"], FEET["Back_R"]])
rest_front_y = rest[FRONT, 1].mean(); rest_hind_y = rest[HIND, 1].mean()
fails = 0
LYING = {"knockdown", "death", "sleep"}
for f in sorted(os.listdir(anim_dir)):
    if not f.endswith(".glb"): continue
    clip = f[:-4]
    objs = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=os.path.join(anim_dir, f))
    new = set(bpy.data.actions) - acts
    for o in set(bpy.data.objects) - objs: bpy.data.objects.remove(o, do_unlink=True)
    if not new: print(f"CLIP {clip} FAIL no action"); fails += 1; continue
    act = max(new, key=lambda x: x.frame_range[1])
    arm.animation_data_create(); arm.animation_data.action = act
    try: arm.animation_data.action_slot = act.slots[0]
    except Exception: pass
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    lows, stretch, feet, hooves, where = [], 1.0, {k: [] for k in FEET}, [], {}
    for fr in range(f0, f1 + 1):
        sc.frame_set(fr); p = pts()
        lows.append(p[:, 2].min())
        if p[:, 2].min() <= min(lows): where["low"] = (fr, dom[int(p[:, 2].argmin())])
        l = np.linalg.norm(p[edges[:, 0]] - p[edges[:, 1]], axis=1)
        r = np.where(ok, l / np.maximum(rl, 1e-9), 1.0)
        if r.max() > stretch:
            stretch = float(r.max()); k = int(r.argmax())
            where["stretch"] = (fr, dom[edges[k, 0]], dom[edges[k, 1]], round(float(rl[k]), 3))
        for k, idx in FEET.items():
            fp = p[idx]; feet[k].append((fp[:, 2].min(), fp[:, 1].mean()))
        hooves.append((p[FRONT, 2].min(), p[FRONT, 1].min(), p[HIND, 1].max(), max(p[FEET['Back_L'], 2].min(), p[FEET['Back_R'], 2].min())))
    lo, hi_low = min(lows), max(lows)
    bad, extra = [], ""
    if stretch > 12.0: bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03: bad.append(f"sinks {lo:.3f}")
    if clip not in LYING and clip not in ("run", "charge", "run_turn_left", "run_turn_right") and hi_low > 0.05: bad.append(f"floats {hi_low:.3f}")
    drift = {}
    if clip in ("walk", "run", "walk_back", "charge", "run_turn_left", "run_turn_right"):  # MEGAJOUST: the gallops too
        for k, seq in feet.items():
            best, cur = [], []
            for z, y in seq:
                if z < 0.04: cur.append(y)
                else:
                    if len(cur) > len(best): best = cur
                    cur = []
            if len(cur) > len(best): best = cur
            d = (best[-1] - best[0]) if len(best) > 1 else 0.0
            drift[k] = round(d, 3)
            if (-1 if clip == "walk_back" else 1) * -d > 0.05: bad.append(f"moonwalk {k} {d:+.2f}")
    if clip in HIT:
        i = int(round(HIT[clip] * (f1 - f0)))
        fz, fy, hy, hz = hooves[i]
        if clip == "attack_heavy":
            extra = f" stomp@hit forehoof z={fz:.2f} m, {rest_front_y - fy:.2f} m ahead"  # forward is -y
            if fz > 0.25 or rest_front_y - fy < 0.6: bad.append("the stomp does not land ahead on the floor")
        else:
            extra = f" kick@hit hind hoof {hy - rest_hind_y:.2f} m back, {hz:.2f} m up"
            if hy - rest_hind_y < 1.2 or hz < 0.8: bad.append("the kick does not reach back")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1-f0+1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] drift={drift}{extra} at={where}")
    fails += bool(bad)
print("MEGALOCEROS_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
