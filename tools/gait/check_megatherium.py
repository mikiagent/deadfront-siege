"""SP-MEGATHERIUM clip gate (check_woolly_rhino.py adapted: same stretch / ground / moonwalk rules on the real skinned
mesh in game metres; the horn checks are replaced by the giant sloth's claw and tripod checks):
- stretch: worst edge length / rest length, FAIL above 12; ground: lowest skin point per frame (below -0.03 m sinks;
  standing clips must touch, lowest <= 0.05 m); moonwalk: planted feet slide backwards (+Y, the rig faces -Y) in
  walk/run, forwards in walk_back.
- the moves, at their anim_events.json hit fracs, with the fore-claw tips (ClawTip.L/R bones):
  attack_primary (hook, 0.42): the right claw tip >= 3.4 m ahead of the origin, 0.3-2.4 m up, within 1 m of the midline;
  attack_heavy (overhead swipe, 0.72): both claw tips coming DOWN >= 4 m/s, 0.2-2.6 m up, >= 3 m ahead, and they were
    above 4.5 m earlier in the clip (overhead);
  pounce (hug, 0.7): both claw tips ahead >= 3 m and within 1.2 m of the midline (closed round her);
  pin_stab (crush, 0.38 / 0.74): both claw tips <= 0.8 m off the ground, >= 2.8 m ahead;
  toss (the advance's topple, 0.3): both claw tips coming down >= 4 m/s, <= 2.4 m up;
  alert (tripod display): at its peak the head is >= 5 m up while both hind feet stay planted and the tail touches the
    ground (a tail-dominant vertex within 0.15 m of the floor);
  charge (the upright advance): the head stays >= 4.5 m up all clip.
usage: Blender -b -P tools/gait/check_megatherium.py -- <base.glb> <anim_dir> --height 3.39  (exit 1 on any FAIL)
"""
import bpy, sys, os
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 2.25
HIT = {"attack_primary": 0.42, "attack_heavy": 0.72, "toss": 0.3, "pounce": 0.7, "pin_stab": 0.38, "pin_stab2": 0.74}
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
TIPS = [arm.pose.bones["ClawTip.L"], arm.pose.bones["ClawTip.R"]]
HEADB = arm.pose.bones["Head"]
def horn(): return np.array([arm.matrix_world @ TIPS[0].head, arm.matrix_world @ TIPS[1].head, arm.matrix_world @ HEADB.tail]) * K
TAILV = np.where(np.char.startswith(dom.astype(str), "Tail"))[0]
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
        club.append(horn()); where.setdefault("tail", []).append(p[TAILV, 2].min())
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
    club = np.array(club)  # [frame, (clawL, clawR, head), xyz]
    n = f1 - f0
    def at(fr): return int(round(fr * n))
    def vz(i): return (club[i, :2, 2] - club[max(0, i - 3), :2, 2]) / (3.0 / FPS)
    if clip == "attack_primary":
        c = club[at(HIT[clip]), 1]
        extra = f" claw.R@hit ahead={-c[1]:.2f} z={c[2]:.2f} x={c[0]:+.2f}"
        if -c[1] < 3.4 or not 0.3 <= c[2] <= 2.4 or abs(c[0]) > 1.0: bad.append("hook: the right claw is not out in front at the hit")
    if clip in ("attack_heavy", "toss"):
        i = at(HIT[clip]); c = club[i, :2]; v = vz(i)
        extra = f" claws@hit z={c[:, 2].round(2).tolist()} ahead={(-c[:, 1]).round(2).tolist()} vz={v.round(1).tolist()} peak={club[:i, :2, 2].max():.2f}"
        if v.max() > -4.0: bad.append("claws not coming down fast at the hit")
        if c[:, 2].max() > (2.6 if clip == "attack_heavy" else 2.4) or c[:, 2].min() < 0.2: bad.append("claws not at her height at the hit")
        if clip == "attack_heavy" and ((-c[:, 1]).min() < 3.0 or club[:i, :2, 2].max() < 4.5): bad.append("swipe not overhead-to-front")
    if clip == "pounce":
        c = club[at(HIT[clip]), :2]
        extra = f" claws@hit ahead={(-c[:, 1]).round(2).tolist()} x={c[:, 0].round(2).tolist()}"
        if (-c[:, 1]).min() < 3.0 or np.abs(c[:, 0]).max() > 1.2: bad.append("hug: the arms do not close in front at the hit")
    if clip == "pin_stab":
        for h in (HIT["pin_stab"], HIT["pin_stab2"]):
            c = club[at(h), :2]
            extra += f" claws@{h} z={c[:, 2].round(2).tolist()} ahead={(-c[:, 1]).round(2).tolist()}"
            if c[:, 2].max() > 0.8 or (-c[:, 1]).min() < 2.8: bad.append(f"crush: claws not round her on the ground at {h}")
    if clip == "alert":
        i = int(np.argmax(club[:, 2, 2])); hf = [feet[k][i][0] for k in ("Back_L", "Back_R")]; tl = where["tail"][i]
        extra = f" head peak {club[i, 2, 2]:.2f} m hind soles {np.round(hf, 3).tolist()} tail low {tl:.2f}"
        if club[i, 2, 2] < 5.0 or max(hf) > 0.06 or tl > 0.15: bad.append("tripod: not reared on planted hind feet and tail")
    if clip == "charge":
        extra = f" head z=[{club[:, 2, 2].min():.2f},{club[:, 2, 2].max():.2f}]"
        if club[:, 2, 2].min() < 4.5: bad.append("advance: not upright")
    where.pop("tail", None)
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1-f0+1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] drift={drift}{extra} at={where}")
    fails += bool(bad)
print("SLOTH_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
