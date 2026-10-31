"""SP-CARNOTAURUS clip gate on the real skinned mesh, in game metres (check_ankylo.py adapted to a biped; --height is
the species height_meters, so the Tripo-unit mesh is scaled by height / rest height). Every clip in anim/ is checked for
- stretch: worst edge length / rest length, FAIL above 12 (check_stego.py's calibration),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch, lowest <= 0.05 m),
- moonwalk: in walk/run/charge each hind foot's planted run (sole within 4 cm of the floor) slides backwards (+Y in
  Blender: this rig faces -Y) or stays put; walk_back the opposite. Below -0.05 m on a forward gait fails,
- planted: in attack_primary, alert and bite_combo the hind toe tips stay within 6 cm of their rest prints across the floor (no
  gliding in place; a heel rolling up about them lifts them a little, which is not a slide),
- the part is the hit: at the clip's hit frame (anim_events.json: attack_primary 0.42, attack_heavy 0.72) the attacking
  part's skin (Jaw for the bite, Head for the horn ram) is at least --reach m ahead of the body centre and moving
  forward or down at least --speed m/s; bite_combo (CARNOFEEL) on each of its three hit frames 0.092 / 0.338 / 0.815, and
  the jaws must close on each (Jaw-to-Head skin centroid gap at least 0.1 m larger 3 frames before the hit),
- charge_turn: both hind toe tips planted (within 6 cm of rest across the floor) before 0.2 and after 0.6 of the clip, both lifted at
  least 0.15 m at mid-air, so the game's yaw inside [0.2, 0.6] never skids a planted foot.
usage: Blender -b -P tools/gait/check_carno.py -- <base.glb> <anim_dir> --height 5.74   (exit 1 on any FAIL)
"""
import bpy, sys, os
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 5.74
REACH = float(a[a.index("--reach") + 1]) if "--reach" in a else 3.5
SPEED = float(a[a.index("--speed") + 1]) if "--speed" in a else 2.0
HIT = {"attack_primary": ((0.42,), "Jaw"), "attack_heavy": ((0.72,), "Head"), "bite_combo": ((0.092, 0.338, 0.815), "Jaw")}
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
FEET = {s: np.where(dom == f"BackFoot.{s}")[0] for s in ("L", "R")}
PART = {b: np.where(dom == b)[0] for b in ("Jaw", "Head")}
assert all(len(v) for v in FEET.values()) and all(len(v) > 30 for v in PART.values()), ({k: len(v) for k, v in FEET.items()}, {k: len(v) for k, v in PART.items()})
# the toe tips (the most forward 20 % of each foot's sole on the floor): a heel rolling up about them is still a planted foot
def _toes(idx):
    sole = idx[rest[idx][:, 2] < 0.15]  # skin on the floor at rest (within 15 cm)
    return sole[rest[sole][:, 1] <= np.quantile(rest[sole][:, 1], 0.2)]
TOES = {s: _toes(idx) for s, idx in FEET.items()}
REST_FOOT = {s: rest[idx].mean(axis=0) for s, idx in TOES.items()}
CENTRE_Y = (rest[:, 1].max() + rest[:, 1].min()) / 2  # the game's origin: the bbox centre
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
    lows, stretch, feet, part, where = [], 1.0, {k: [] for k in FEET}, {b: [] for b in PART}, {}
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
            fp = p[idx]; tp = p[TOES[k]]; feet[k].append((fp[:, 2].min(), tp[:, 1].mean(), tp.mean(axis=0)))  # drift on the toes: a heel peeling up about them is still planted
        for b, idx in PART.items():
            part[b].append(p[idx].mean(axis=0))
    lo, hi_low = min(lows), max(lows)
    n = f1 - f0
    bad, extra = [], ""
    if stretch > 12.0: bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03: bad.append(f"sinks {lo:.3f}")
    if clip not in LYING and clip not in ("run", "charge", "charge_turn") and hi_low > 0.05: bad.append(f"floats {hi_low:.3f}")
    drift = {}
    if clip in ("walk", "run", "charge", "walk_back"):
        for k, seq in feet.items():
            best, cur = [], []
            for z, y, _ in seq:
                if z < 0.04: cur.append(y)
                else:
                    if len(cur) > len(best): best = cur
                    cur = []
            if len(cur) > len(best): best = cur
            d = (best[-1] - best[0]) if len(best) > 1 else 0.0
            drift[k] = round(d, 3)
            if (-1 if clip == "walk_back" else 1) * -d > 0.05: bad.append(f"moonwalk {k} {d:+.2f}")
    if clip in ("attack_primary", "alert", "bite_combo"):
        slide = max(float(np.linalg.norm((c - REST_FOOT[k])[:2])) for k, seq in feet.items() for _, _, c in seq)
        extra += f" foot_off_rest={slide:.3f} m"
        if slide > 0.06: bad.append(f"feet leave their prints by {slide:.2f} m")
    if clip == "charge_turn":
        ground = [i for i in range(n + 1) if i / n < 0.2 or i / n > 0.6]
        slide = max(float(np.linalg.norm((feet[k][i][2] - REST_FOOT[k])[:2])) for k in feet for i in ground)
        mid = int(round(0.4 * n))
        lift = min(feet[k][mid][0] for k in feet)
        extra += f" ground_foot_off_rest={slide:.3f} m mid_air_lift={lift:.2f} m"
        if slide > 0.06: bad.append(f"a planted foot moves {slide:.2f} m on the ground")
        if lift < 0.15: bad.append(f"feet only {lift:.2f} m up at mid-air")
    for u in HIT.get(clip, ((),))[0]:
        b = HIT[clip][1]
        i = int(round(u * n)); c = part[b][i]; prev = part[b][max(0, i - 3)]
        ahead = CENTRE_Y - c[1]  # -Y is forward
        v = (c - prev) / (3.0 / FPS)
        speed = max(-v[1], -v[2])  # forward or down into the target
        extra += f" {b}@{u} ahead={ahead:.2f} m height={c[2]:.2f} m speed={speed:.1f} m/s"
        if ahead < REACH: bad.append(f"{b} only {ahead:.2f} m ahead at the hit {u}")
        if speed < SPEED: bad.append(f"{b} moving {speed:.1f} m/s at the hit {u}")
        if clip == "bite_combo":  # CARNOFEEL: each chomp is a real bite: the jaws gape before it and shut on it
            gape = [float(np.linalg.norm(part["Jaw"][k] - part["Head"][k])) for k in (max(0, i - 3), i)]
            extra += f" gape {gape[0]:.2f}->{gape[1]:.2f} m"
            if gape[0] - gape[1] < 0.1: bad.append(f"the jaws do not shut on the hit {u} (gape {gape[0]:.2f} -> {gape[1]:.2f} m)")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={n + 1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] drift={drift}{extra} at={where}")
    fails += bool(bad)
print("CARNO_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
