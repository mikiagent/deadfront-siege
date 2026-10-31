"""SP-SMILODON clip gate (check_ankylo.py adapted) on the real skinned mesh, in game metres (the GLB is in Tripo units; --height is the species
height_meters, so the mesh is scaled by height / rest height). Every clip in anim/ is checked for
- stretch: worst edge length / rest length, FAIL above 12 (check_stego.py's calibration),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch, lowest <= 0.05 m),
- moonwalk: in walk/run each foot's planted run (sole within 4 cm of the floor) slides backwards (+Y in Blender: this
  rig faces -Y) or stays put; walk_back the opposite. Drift = y(end) - y(start) in metres; below -0.05 on walk/run fails,
- moonwalk also on stalk; the pounce is airborne (no float check), the gallop has a flight phase,
- gallops (run, sprint): a flight phase (every paw >= 2 cm up for a frame), the back flexes >= 12 deg, and each planted
  paw moves back at the clip's ground speed within 3 cm a frame (no slide),
- the part is the hit: at each hit frame (anim_events.json) the skin of the clip's hit bone (pipeline.hit_parts: the
  swiping FrontFoot.R, the sabres on Head) is at least --reach metres ahead of the rest body centre, and a sabre
  stab (Head) has come down at least --drop metres from the head's rest height.
usage: Blender -b -P tools/gait/check_smilodon.py -- <base.glb> <anim_dir> --height 2.0   (exit 1 on any FAIL)
"""
import bpy, sys, os
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 2.0
REACH = float(a[a.index("--reach") + 1]) if "--reach" in a else 1.2
DROP = float(a[a.index("--drop") + 1]) if "--drop" in a else 0.2
PLANT = 0.02  # m: a paw is planted while its lowest skin is this close to the floor (the cat's low swing passes 4 cm)
HIT = {"attack_primary": ([0.42], "FrontFoot.R"), "attack_heavy": ([0.72], "Head"), "pounce": ([0.7], "Head"), "pin_stab": ([0.38, 0.74], "Head"),
       "long_leap": ([0.74], "Head"), "maul_bite": ([0.24, 0.5, 0.74], "Head")}  # SMILOFEEL
FPS = 24
GALLOPS = ("run", "lope", "sprint")  # SMILORUN: bounding gaits that must leave the ground, flex the back and keep planted paws stuck
FLIGHT, MIN_BEND, SLIP = 0.02, 12.0, 0.03  # m clear of the floor, deg of back flex, m per frame off the ground speed
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
K = H / (rest[:, 2].max() - rest[:, 2].min())
rest = rest * K
print(f"scale {K:.3f} (rest height {rest[:, 2].max():.2f} m, length {np.ptp(rest[:, 1]):.2f} m, width {np.ptp(rest[:, 0]):.2f} m)")
edges = np.array([e.vertices[:] for e in body.data.edges])
rl = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1); ok = rl > 1e-3
gi = {g.index: g.name for g in body.vertex_groups}
dom = np.array([gi[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in body.data.vertices])
FEET = {f"{k}_{s}": np.where(dom == f"{k}Foot.{s}")[0] for k in ("Back", "Front") for s in ("L", "R")}
FEET = {k: v for k, v in FEET.items() if len(v)}
PART = {b: np.where(dom == b)[0] for _, b in HIT.values()}
assert len(FEET) == 4 and all(len(v) > 20 for v in PART.values()), (list(FEET), {k: len(v) for k, v in PART.items()})
CENTRE_Y = (rest[:, 1].max() + rest[:, 1].min()) / 2
HEAD_Z = rest[PART["Head"]][:, 2].mean()
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
    lows, stretch, feet, part, where = [], 1.0, {k: [] for k in FEET}, [], {}
    flex, hipz, headz = [], [], []
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
            # the contact patch (lowest 15 % of the paw): the cat's Foot runs up to the hock, whose mean swings forward
            # over the toes as the heel peels, which is not a slide
            fp = p[idx]; pad = fp[np.argsort(fp[:, 2])[:max(3, len(fp) * 15 // 100)]]
            feet[k].append((fp[:, 2].min(), pad[:, 1].mean()))
        if clip in HIT:
            part.append(p[PART[HIT[clip][1]]].mean(axis=0))
        if clip in GALLOPS:  # SMILORUN: spine bend (pelvis vs chest pitch in the side plane), hip and head heights
            pb = arm.pose.bones
            def pitch(b):
                y = pb[b].matrix.to_3x3().col[1]; return np.degrees(np.arctan2(y.z, -y.y))
            flex.append(pitch("Shoulders") - pitch("Back"))
            hipz.append((arm.matrix_world @ pb["BackUpLeg.L"].head).z * K); headz.append((arm.matrix_world @ pb["Head"].head).z * K)
    lo, hi_low = min(lows), max(lows)
    bad, extra = [], ""
    if stretch > 12.0: bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03: bad.append(f"sinks {lo:.3f}")
    if clip not in LYING and clip not in ("run", "lope", "sprint", "pounce", "leap", "long_leap") and hi_low > 0.05: bad.append(f"floats {hi_low:.3f}")
    drift = {}
    if clip in ("walk", "run", "walk_back", "stalk"):
        for k, seq in feet.items():
            best, cur = [], []
            for z, y in seq:
                if z < PLANT: cur.append(y)
                else:
                    if len(cur) > len(best): best = cur
                    cur = []
            if len(cur) > len(best): best = cur
            d = (best[-1] - best[0]) if len(best) > 1 else 0.0
            drift[k] = round(d, 3)
            if (-1 if clip == "walk_back" else 1) * -d > 0.05: bad.append(f"moonwalk {k} {d:+.2f}")
    if clip in GALLOPS:
        # flight: frames where every paw's lowest skin is clear of the floor; slip: each planted run (the paw's lowest skin
        # within PLANT of the floor) must travel back at the clip's one ground speed (the median over every planted frame)
        air = [i for i in range(len(lows)) if min(feet[k][i][0] for k in feet) > FLIGHT]
        vel = [feet[k][i + 1][1] - feet[k][i][1] for k in feet for i in range(len(lows) - 1) if feet[k][i][0] < PLANT and feet[k][i + 1][0] < PLANT]
        v = float(np.median(vel)) if vel else 0.0
        slip = max([abs(d - v) for d in vel] or [0.0])
        bend = max(flex) - min(flex)
        extra += f" flight={len(air)}f {air} bend={bend:.1f}deg v={v * FPS:.2f}m/s slip={slip:.3f}m/f hip_z={min(hipz):.2f}-{max(hipz):.2f} head_z={min(headz):.2f}-{max(headz):.2f}"
        if os.environ.get("GALLOP_TRACE"): print("TRACE head", [round(z, 2) for z in headz], "hip", [round(z, 2) for z in hipz], "flex", [round(f) for f in flex])
        if not air: bad.append("no flight phase")
        if bend < MIN_BEND: bad.append(f"spine bends only {bend:.1f} deg")
        if slip > SLIP: bad.append(f"planted paw slips {slip:.3f} m/frame")
    if clip == "maul_bite":  # SMILOFEEL: the hind legs hold their prints through the whole maul (no skating on the hits)
        hind = max(feet[k][i][0] for k in ("Back_L", "Back_R") for i in range(len(lows)))
        hdrift = max(abs(feet[k][-1][1] - feet[k][0][1]) for k in ("Back_L", "Back_R"))
        extra += f" hind_lift={hind:.3f}m hind_drift={hdrift:.3f}m"
        if hind > PLANT or hdrift > 0.03: bad.append(f"hind paws leave their prints (lift {hind:.3f}, drift {hdrift:.3f})")
    if clip in HIT:
        fracs, bone = HIT[clip]
        for frac in fracs:
            i = int(round(frac * (f1 - f0)))
            ahead = CENTRE_Y - part[i][1]  # the rig faces -Y
            drop = HEAD_Z - part[i][2]
            extra += f" {bone}@{frac} ahead={ahead:.2f} m drop={drop:.2f} m"
            if ahead < REACH: bad.append(f"{bone} only {ahead:.2f} m ahead at hit {frac}")
            if bone == "Head" and drop < DROP: bad.append(f"sabres only {drop:.2f} m down at hit {frac}")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1-f0+1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] drift={drift}{extra} at={where}")
    fails += bool(bad)
print("SMILODON_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
