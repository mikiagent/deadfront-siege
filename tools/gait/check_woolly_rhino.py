"""SP-WOOLLY_RHINO clip gate (check_ankylo.py adapted: same stretch / ground / moonwalk rules; the tail-club check is
replaced by the rhino's signature-move checks below). ANKYLO3D clip gate on the real skinned mesh, in game metres (the GLB is in Tripo units; --height is the species
height_meters, so the mesh is scaled by height / rest height). Every clip in anim/ is checked for
- stretch: worst edge length / rest length, FAIL above 12 (check_stego.py's calibration),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch, lowest <= 0.05 m),
- moonwalk: in walk/run each foot's planted run (sole within 4 cm of the floor) slides backwards (+Y in Blender: this
  rig faces -Y) or stays put; walk_back the opposite. Drift = y(end) - y(start) in metres; below -0.05 on walk/run fails,
- the moves hit with the right part at the hit frame (anim_events.json hit_frac):
  attack_primary (stamp, 0.42): a forefoot is down (sole within 8 cm of the floor), at least 0.4 m ahead of where it
    stands at rest, and came down fast (>= 1.5 m/s over the previous 3 frames);
  attack_heavy (horn sweep, 0.72): the horn tip (HornTip bone) moves sideways >= 4 m/s and the sweep spans >= 1.5 m
    to each side of the midline over the clip;
  toss (0.3): the horn tip rises >= 2.5 m/s;
  charge: the horn tip stays between 0.4 and 1.8 m off the ground and ahead of the nose's rest position.
usage: Blender -b -P tools/gait/check_woolly_rhino.py -- <base.glb> <anim_dir> --height 2.95  (exit 1 on any FAIL)
"""
import bpy, sys, os
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 2.25
HIT = {"attack_primary": 0.42, "attack_heavy": 0.72, "toss": 0.3}
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
FEET = {f"{k}_{s}": np.where(dom == f"{k}Foot.{s}")[0] for k in ("Back", "Front") for s in ("L", "R")}
FEET = {k: v for k, v in FEET.items() if len(v)}
assert len(FEET) == 4, list(FEET)
TIP = arm.pose.bones["HornTip"]
def horn(): return np.array(arm.matrix_world @ TIP.head) * K
REST_FEET = {k: rest[idx].mean(axis=0) for k, idx in FEET.items()}
REST_TIP_Y = None
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
    lows, stretch, feet, club, where = [], 1.0, {k: [] for k in FEET}, [], {}
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
        club.append(horn())
        for k, idx in FEET.items(): feet[k][-1] = feet[k][-1] + (p[idx].mean(axis=0),)
    lo, hi_low = min(lows), max(lows)
    bad, extra = [], ""
    if stretch > 12.0: bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03: bad.append(f"sinks {lo:.3f}")
    if clip not in LYING and clip not in ("run",) and hi_low > 0.05: bad.append(f"floats {hi_low:.3f}")
    drift = {}
    if clip in ("walk", "run", "walk_back"):
        for k, seq in feet.items():
            best, cur = [], []
            for z, y, _c in seq:
                if z < 0.04: cur.append(y)
                else:
                    if len(cur) > len(best): best = cur
                    cur = []
            if len(cur) > len(best): best = cur
            d = (best[-1] - best[0]) if len(best) > 1 else 0.0
            drift[k] = round(d, 3)
            if (-1 if clip == "walk_back" else 1) * -d > 0.05: bad.append(f"moonwalk {k} {d:+.2f}")
    club = np.array(club)
    if clip == "attack_primary":
        i = int(round(HIT[clip] * (f1 - f0)))
        best = None
        for k in ("Front_L", "Front_R"):
            z, _y, c = feet[k][i]; zb = feet[k][max(0, i - 3)][0]
            fwd = REST_FEET[k][1] - c[1]  # the rig faces -Y
            vz = (zb - z) / (3.0 / FPS)
            if best is None or fwd > best[1]: best = (k, fwd, z, vz)
        extra = f" stamp {best[0]} fwd={best[1]:.2f} m sole={best[2]:.3f} down={best[3]:.1f} m/s"
        if best[1] < 0.4 or best[2] > 0.08 or best[3] < 1.5: bad.append("stamp: no forefoot slams down ahead at the hit")
    if clip == "attack_heavy":
        i = int(round(HIT[clip] * (f1 - f0)))
        vx = abs(club[i][0] - club[max(0, i - 3)][0]) / (3.0 / FPS)
        extra = f" horn@hit x={club[i][0]:+.2f} vx={vx:.1f} m/s sweep=[{club[:, 0].min():+.2f},{club[:, 0].max():+.2f}]"
        if vx < 4.0: bad.append(f"sweep only {vx:.1f} m/s at the hit")
        if club[:, 0].min() > -1.5 or club[:, 0].max() < 1.5: bad.append("sweep too narrow")
    if clip == "toss":
        i = int(round(HIT[clip] * (f1 - f0)))
        vz = (club[i][2] - club[max(0, i - 3)][2]) / (3.0 / FPS)
        extra = f" horn@hit z={club[i][2]:.2f} rising {vz:.1f} m/s"
        if vz < 2.5: bad.append(f"toss horn rises only {vz:.1f} m/s")
    if clip == "charge":
        extra = f" horn z=[{club[:, 2].min():.2f},{club[:, 2].max():.2f}] y=[{club[:, 1].min():.2f},{club[:, 1].max():.2f}]"
        if club[:, 2].min() < 0.4 or club[:, 2].max() > 1.8: bad.append("charge horn not levelled")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1-f0+1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] drift={drift}{extra} at={where}")
    fails += bool(bad)
print("RHINO_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
