"""Stegosaurus clip gate on the real skinned mesh (STEGOFIX): every clip in anim/ is checked for
- stretch: worst edge length / rest length, FAIL above 12 (calibrated 2026-10-30: the shipped T. rex reads 8-24 from its
  jaw; the stegosaurus 2-10 sits in folds under the chest and at the neck plate bases, invisible at game range),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch, lowest <= 0.05 m),
- moonwalk: in walk/run each foot's planted frames (sole within 4 cm of the floor) must slide backwards along the
  facing (+Y in Blender = glTF -Z) or stay put; walk_back the opposite. Drift is foot y(end) - y(start) of the
  longest planted run, in metres; + on walk/run = moonwalk.
usage: Blender -b -P tools/gait/check_stego.py -- <base.glb> <anim_dir>   (exit 1 on any FAIL)
"""
import bpy, sys, os
import numpy as np
a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
body = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
sc = bpy.context.scene

def pts():
    dg = bpy.context.evaluated_depsgraph_get(); e = body.evaluated_get(dg); me = e.to_mesh()
    v = np.array([body.matrix_world @ x.co for x in me.vertices]); e.to_mesh_clear(); return v

arm.animation_data_clear()
for pb in arm.pose.bones: pb.matrix_basis.identity()
bpy.context.view_layer.update()
rest = pts()
edges = np.array([e.vertices[:] for e in body.data.edges])
rl = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1); ok = rl > 1e-3
gi = {g.index: g.name for g in body.vertex_groups}
dom = []
for v in body.data.vertices:
    g = max(v.groups, key=lambda g: g.weight, default=None); dom.append(gi[g.group] if g else "")
dom = np.array(dom)
FEET = {f"{k}_{s}": np.where(np.isin(dom, [f"{k}_foot_{s}", f"{k}_toe_{s}"]))[0] for k in ("hind", "front") for s in ("L", "R")}
FEET = {k: v for k, v in FEET.items() if len(v)}
fails = 0
LYING = {"knockdown", "death"}
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
    worst = None
    lows, stretch, feet = [], 1.0, {k: [] for k in FEET}
    for fr in range(f0, f1 + 1):
        sc.frame_set(fr); p = pts()
        lows.append(p[:, 2].min())
        l = np.linalg.norm(p[edges[:, 0]] - p[edges[:, 1]], axis=1)
        r = np.where(ok, l / np.maximum(rl, 1e-9), 1.0)
        if r.max() > stretch:
            stretch = float(r.max()); worst = (fr, int((r > 1.6).sum()), sorted(set(dom[edges[np.argsort(r)[-8:], 0]])), [tuple(np.round(rest[edges[k,0]],2)) for k in np.argsort(r)[-3:]])
        for k, idx in FEET.items():
            fp = p[idx]; feet[k].append((fp[:, 2].min(), fp[:, 1].mean()))
    lo = min(lows); hi_low = max(lows)
    bad = []
    if stretch > 12.0: bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03: bad.append(f"sinks {lo:.3f}")
    if clip not in LYING and clip not in ("run", "charge", "kick") and hi_low > 0.05: bad.append(f"floats {hi_low:.3f}")
    drift = {}
    if clip in ("walk", "run", "walk_back"):
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
            sign = -1 if clip == "walk_back" else 1
            if sign * d > 0.05: bad.append(f"moonwalk {k} {d:+.2f}")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1-f0+1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] drift={drift} worst={worst}")
    fails += bool(bad)
print("STEGO_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
