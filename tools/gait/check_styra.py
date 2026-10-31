"""STYRAFIX: the styracosaurus clip gate on the real skinned mesh in game metres (check_trike.py's rules on this rig:
faces -Y in Blender, root-parented FrontFoot/BackFoot controllers). Per clip in anim/:
- stretch: worst edge length / rest length, FAIL above 12 (check_stego.py's calibration);
- ground: below -0.03 m = sinking; standing clips must touch (lowest <= 0.05 m);
- moonwalk (walk, run, charge forward; walk_back backward): a planted foot's run (sole within 8 cm of the floor)
  slides backwards (+Y) or stays put; drift below -0.05 m fails (the body drives forward over it);
- planted (the stand-in-place clips): every foot's sole stays within 0.06 m (horizontal) of where it starts, except
  the pawing foot of charge_windup. These clips play with the body stopped, so a moving foot is a slide.
usage: Blender -b -P tools/gait/check_styra.py -- <base.glb> <anim_dir> --height 6.75 [clip ...]   (exit 1 on any FAIL)
"""
import bpy, sys, os
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 6.75
ONLY = [x for i, x in enumerate(a) if i >= 2 and not x.startswith("--") and a[i - 1] != "--height"]
FORWARD = {"walk", "run", "charge"}
PLANTED = {"idle", "alert", "attack_primary", "attack_heavy", "hit_react", "charge_windup", "impale", "charge_recover"}
PAWING = {"charge_windup": "Front_L"}
LYING = {"knockdown", "death", "sleep"}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 24
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
K = H / (rest[:, 2].max() - rest[:, 2].min())
rest = rest * K
print(f"scale {K:.3f} (rest height {rest[:, 2].max():.2f} m, length {np.ptp(rest[:, 1]):.2f} m, width {np.ptp(rest[:, 0]):.2f} m)")
edges = np.array([e.vertices[:] for e in body.data.edges])
rl = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1); ok = rl > 1e-3
gi = {g.index: g.name for g in body.vertex_groups}
dom = np.array([gi[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in body.data.vertices])
# a foot = its controller's skin; its sole = the fixed set of those vertices within 0.25 m of the floor at rest
FEET = {f"{e}_{s}": np.where(dom == f"{e}Foot.{s}")[0] for e in ("Front", "Back") for s in ("L", "R")}
SOLE = {k: idx[rest[idx, 2] <= 0.25] for k, idx in FEET.items()}
assert all(len(v) > 20 for v in FEET.values()), {k: len(v) for k, v in FEET.items()}
fails = 0
for f in sorted(os.listdir(anim_dir)):
    if not f.endswith(".glb"): continue
    clip = f[:-4]
    if ONLY and clip not in ONLY: continue
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
    lows, stretch, feet = [], 1.0, {k: [] for k in FEET}
    for fr in range(f0, f1 + 1):
        sc.frame_set(fr); p = pts()
        lows.append(p[:, 2].min())
        l = np.linalg.norm(p[edges[:, 0]] - p[edges[:, 1]], axis=1)
        stretch = max(stretch, float(np.where(ok, l / np.maximum(rl, 1e-9), 1.0).max()))
        for k, idx in FEET.items():
            fp = p[idx]; sole = p[SOLE[k]]
            feet[k].append((fp[:, 2].min(), sole[:, 0].mean(), sole[:, 1].mean()))
    lo, hi_low = min(lows), max(lows)
    bad, info = [], {}
    if stretch > 12.0: bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03: bad.append(f"sinks {lo:.3f}")
    if clip not in LYING and clip not in ("run", "charge") and hi_low > 0.05: bad.append(f"floats {hi_low:.3f}")
    if clip in FORWARD or clip == "walk_back":
        for k, seq in feet.items():
            best, cur = [], []
            for z, x, y in seq:
                if z < 0.08: cur.append(y)
                else:
                    if len(cur) > len(best): best = cur
                    cur = []
            if len(cur) > len(best): best = cur
            d = (best[-1] - best[0]) if len(best) > 1 else 0.0
            info[k] = round(d, 3)
            if (-1 if clip == "walk_back" else 1) * d < -0.05: bad.append(f"moonwalk {k} {d:+.2f}")
    if clip in PLANTED:
        for k, seq in feet.items():
            if PAWING.get(clip) == k: continue
            xy = np.array([(x, y) for _, x, y in seq])
            m = float(np.linalg.norm(xy - xy[0], axis=1).max())
            info[k] = round(m, 3)
            if m > 0.06: bad.append(f"slides {k} {m:.2f} m")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1 - f0 + 1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] feet={info}")
    fails += bool(bad)
print("STYRA_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
