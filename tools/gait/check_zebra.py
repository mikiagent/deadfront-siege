"""ZEBRAWALK locomotion gate on the real skinned zebraceratops mesh, in game metres (check_ankylo.py adapted: same
Triceratops-donor bone names, --height scales the Tripo-unit mesh to the species height_meters).

For walk, run, walk_back, strafe_left, strafe_right (or every clip with --all):
- stretch: worst edge length / rest length, FAIL above 12 (check_stego.py's calibration),
- ground: lowest skin point (below -0.03 m = sinking); walk and the strafes must keep a foot down (lowest <= 0.05 m),
- shuffle: each foot's sole (lowest skin point, toes included) clears the floor by 6 cm at the top of its swing,
- moonwalk: each foot's planted frames (sole within 3 cm of the floor; a swinging toe that
  scuffs the floor counts as planted, so a scuff shows up as a skid or a moonwalk) slide against the clip's travel (walk/run:
  forward, walk_back: backward, strafe_left/right: the body's own left/right); sliding with it more than 0.02 m fails,
- sideways skid: a planted foot's slide across the travel axis is at most 35 % of its slide along it,
- foot agreement: every foot's planted slide speed is within 25 % of the clip's mean (one natural speed fits all feet,
  so a stride-matched cadence leaves no foot sliding on the ground),
- smooth stance: within a planted run the per-frame slide speed varies by at most 50 % of its mean (no stick-then-skate).
Facing comes from the rig (Head bone ahead of the hips), so the check does not care which axis the GLB faces.
Prints each clip's planted speed at cadence 1 (m/s, game scale), duty factor and footfall order.

usage: Blender -b -P tools/gait/check_zebra.py -- <base.glb> <anim_dir> --height 1.8 [--all]   (exit 1 on any FAIL)
"""
import bpy, sys, os
import numpy as np
a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 1.8
ALL = "--all" in a
FPS = 24
LOCO = {"walk": "fwd", "run": "fwd", "walk_back": "back", "strafe_left": "left", "strafe_right": "right"}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
body = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
sc = bpy.context.scene
K = 1.0


def pts():
    dg = bpy.context.evaluated_depsgraph_get(); e = body.evaluated_get(dg); me = e.to_mesh()
    v = np.array([body.matrix_world @ x.co for x in me.vertices]); e.to_mesh_clear(); return v * K


arm.animation_data_clear()
for pb in arm.pose.bones: pb.matrix_basis.identity()
bpy.context.view_layer.update()
rest = pts()
K = H / (rest[:, 2].max() - rest[:, 2].min())
rest = rest * K
head = arm.matrix_world @ arm.pose.bones["Head"].head
hips = arm.matrix_world @ arm.pose.bones["Body"].head if "Body" in arm.pose.bones else arm.matrix_world @ arm.pose.bones[0].head
f = np.array([head.x - hips.x, head.y - hips.y]); f /= np.linalg.norm(f)
FWD = np.array([f[0], f[1]])
LEFT = np.array([-f[1], f[0]])  # Z up, right-handed: up x forward = left
DIRS = {"fwd": FWD, "back": -FWD, "left": LEFT, "right": -LEFT}
print(f"scale {K:.3f}  forward (Blender xy) {FWD.round(2)}  left {LEFT.round(2)}")
edges = np.array([e.vertices[:] for e in body.data.edges])
rl = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1); ok = rl > 1e-3
gi = {g.index: g.name for g in body.vertex_groups}
dom = np.array([gi[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in body.data.vertices])
FEET = {f"{k[0]}{s}": np.where(dom == f"{k}Foot.{s}")[0] for k in ("Back", "Front") for s in ("L", "R")}
assert all(len(v) for v in FEET.values()), {k: len(v) for k, v in FEET.items()}
fails = 0
for fn in sorted(os.listdir(anim_dir)):
    if not fn.endswith(".glb"): continue
    clip = fn[:-4]
    if clip not in LOCO and not ALL: continue
    objs = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=os.path.join(anim_dir, fn))
    new = set(bpy.data.actions) - acts
    for o in set(bpy.data.objects) - objs: bpy.data.objects.remove(o, do_unlink=True)
    if not new: print(f"CLIP {clip} FAIL no action"); fails += 1; continue
    act = max(new, key=lambda x: x.frame_range[1])
    arm.animation_data_create(); arm.animation_data.action = act
    try: arm.animation_data.action_slot = act.slots[0]
    except Exception: pass
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    n = f1 - f0  # last frame repeats the first in a loop
    lows, stretch, feet = [], 1.0, {k: [] for k in FEET}
    for fr in range(f0, f1 + 1):
        sc.frame_set(fr); p = pts()
        lows.append(p[:, 2].min())
        l = np.linalg.norm(p[edges[:, 0]] - p[edges[:, 1]], axis=1)
        stretch = max(stretch, float(np.where(ok, l / np.maximum(rl, 1e-9), 1.0).max()))
        for k, idx in FEET.items():
            fp = p[idx]; feet[k].append((fp[:, 2].min(), fp[:, 0].mean(), fp[:, 1].mean()))
    lo, hi_low = min(lows), max(lows)
    bad = []
    if stretch > 12.0: bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03: bad.append(f"sinks {lo:.3f}")
    if clip in LOCO and clip != "run" and hi_low > 0.05: bad.append(f"floats {hi_low:.3f}")
    info = ""
    if clip in LOCO:
        T = DIRS[LOCO[clip]]; X = np.array([-T[1], T[0]])
        speeds, duty, order = {}, {}, {}
        for k, seq in feet.items():
            s = np.array(seq[:n])  # one loop
            planted = s[:, 0] < 0.03  # sole within 3 cm of the floor (rest soles sit at 0)
            lift = float(s[:, 0].max())
            if lift < 0.06: bad.append(f"shuffle {k} lifts only {lift:.2f} m")
            duty[k] = round(planted.mean(), 2)
            # first planted frame after a lift = touchdown, as a share of the loop
            td = [i for i in range(n) if planted[i] and not planted[i - 1]]
            order[k] = round(td[0] / n, 2) if td else None
            along, across, vels = 0.0, 0.0, []
            for i in range(n):
                j = (i + 1) % n
                if planted[i] and planted[j]:
                    d = s[j, 1:] - s[i, 1:]
                    along += d @ T; across += abs(d @ X); vels.append(-(d @ T) * FPS)
            if along > 0.02: bad.append(f"moonwalk {k} {along:+.2f} m with the travel")
            if abs(along) > 1e-3 and across > 0.35 * abs(along): bad.append(f"skid {k} across {across:.2f} vs along {abs(along):.2f}")
            if len(vels) > 2:
                v = np.array(vels); speeds[k] = float(v.mean())
                if v.mean() > 0.05 and v.std() > 0.5 * v.mean(): bad.append(f"jerky stance {k} {v.std() / v.mean():.2f}")
        info = f" duty={duty} touchdown={order}"
        if speeds:
            m = np.mean(list(speeds.values()))
            for k, v in speeds.items():
                if m > 0.05 and abs(v - m) > 0.25 * m: bad.append(f"foot {k} {v:.2f} vs mean {m:.2f} m/s")
            info = f" speed={m:.2f} m/s feet={ {k: round(v, 2) for k, v in speeds.items()} } duty={duty} touchdown={order}"
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} len={n / FPS:.3f}s stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}]{info}")
    fails += bool(bad)
print("ZEBRA_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
