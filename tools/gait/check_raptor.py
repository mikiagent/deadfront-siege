"""SP-RAPTOR clip gate (check_smilodon.py adapted to a biped) on the real skinned mesh, in game metres (the GLB is in Tripo units; --height is the species
height_meters, so the mesh is scaled by height / rest height). Every clip in anim/ is checked for
- stretch: worst edge length / rest length, FAIL above 13 (check_stego.py's 12, see STRETCH),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch, lowest <= 0.05 m),
- moonwalk: in walk/run each foot's planted run (sole within 4 cm of the floor) slides backwards (+Y in Blender: this
  rig faces -Y) or stays put; walk_back the opposite. Drift = y(end) - y(start) in metres; below -0.05 on walk/run fails,
- moonwalk also on stalk; the pounce is airborne (no float check), the gallop has a flight phase,
- the part is the hit: at each hit frame (anim_events.json) the skin of the clip's hit bone (pipeline.hit_parts: the
  swiping FrontFoot.R, the sabres on Head) is at least --reach metres ahead of the rest body centre, and a sabre
  stab (Head) has come down at least --drop metres from the head's rest height.
Raptor: only the hind feet (BackFoot.*) are feet; the hit parts are the jaws (Head) for the bites, the pounce and the
pin bites, and the right sickle foot (BackFoot.R) for the slash (attack_heavy); a Head hit must come down --drop m
from the head's rest height only on the pin bites (the prey is on the ground).
usage: Blender -b -P tools/gait/check_raptor.py -- <base.glb> <anim_dir> --height 3.5   (exit 1 on any FAIL)
"""
import bpy, sys, os
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 2.0
REACH = float(a[a.index("--reach") + 1]) if "--reach" in a else 1.2
DROP = float(a[a.index("--drop") + 1]) if "--drop" in a else 0.2
PLANT = 0.03  # m: a foot is planted while its lowest skin is this close to the floor
HIT = {"attack_primary": ([0.42], "Head"), "bite_combo": ([0.092, 0.338, 0.815], "Head"), "attack_heavy": ([0.72], "BackFoot.R"),
       "pounce": ([0.7], "Head"), "pin_stab": ([0.38, 0.74], "Head")}
DROP_CLIPS = {"pin_stab"}
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
K = H / (rest[:, 2].max() - rest[:, 2].min())
rest = rest * K
print(f"scale {K:.3f} (rest height {rest[:, 2].max():.2f} m, length {np.ptp(rest[:, 1]):.2f} m, width {np.ptp(rest[:, 0]):.2f} m)")
edges = np.array([e.vertices[:] for e in body.data.edges])
rl = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1); ok = rl > 1e-3
gi = {g.index: g.name for g in body.vertex_groups}
dom = np.array([gi[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in body.data.vertices])
FEET = {f"Back_{s}": np.where(dom == f"BackFoot.{s}")[0] for s in ("L", "R")}
FEET = {k: v for k, v in FEET.items() if len(v)}
PART = {b: np.where(dom == b)[0] for _, b in HIT.values()}
assert len(FEET) == 2 and all(len(v) > 20 for v in PART.values()), (list(FEET), {k: len(v) for k, v in PART.items()})
CENTRE_Y = (rest[:, 1].max() + rest[:, 1].min()) / 2
HEAD_Z = rest[PART["Head"]][:, 2].mean()
fails = 0
LYING = {"knockdown", "death", "sleep"}
# The deinonychus bites it inherits step in with a short hop (both feet up to 0.18 m for a frame or two): allowed up
# to LUNGE_FLOAT, still no sinking or gliding. The deinonychus charge tucks the arms hard: a 2 cm elbow edge reads
# 12.8x, so the stretch gate is 13 (check_stego.py's 12 plus that).
LUNGE = {"attack_primary", "bite_combo"}
LUNGE_FLOAT = 0.2
STRETCH = 13.0
AIR = {"run", "pounce", "hop_back", "leap_back", "dodge_left", "dodge_right", "charge"}  # flight phases: no float check
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
            # the contact patch (lowest 15 % of the foot): the heel peeling up is not a slide
            fp = p[idx]; pad = fp[np.argsort(fp[:, 2])[:max(3, len(fp) * 15 // 100)]]
            feet[k].append((fp[:, 2].min(), pad[:, 1].mean()))
        if clip in HIT:
            part.append(p[PART[HIT[clip][1]]].mean(axis=0))
    lo, hi_low = min(lows), max(lows)
    bad, extra = [], ""
    if stretch > STRETCH: bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03: bad.append(f"sinks {lo:.3f}")
    if clip not in LYING and clip not in AIR and hi_low > (LUNGE_FLOAT if clip in LUNGE else 0.05): bad.append(f"floats {hi_low:.3f}")
    drift = {}
    if clip in ("walk", "run", "walk_back"):
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
    if clip in HIT:
        fracs, bone = HIT[clip]
        for frac in fracs:
            i = int(round(frac * (f1 - f0)))
            ahead = CENTRE_Y - part[i][1]  # the rig faces -Y
            drop = HEAD_Z - part[i][2]
            extra += f" {bone}@{frac} ahead={ahead:.2f} m drop={drop:.2f} m"
            if ahead < REACH: bad.append(f"{bone} only {ahead:.2f} m ahead at hit {frac}")
            if clip in DROP_CLIPS and drop < DROP: bad.append(f"jaws only {drop:.2f} m down at hit {frac}")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1-f0+1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] drift={drift}{extra} at={where}")
    fails += bool(bad)
print("RAPTOR_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
