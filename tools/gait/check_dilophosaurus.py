"""SP-DILOPHOSAURUS clip gate (check_pachy.py adapted) on the real skinned mesh, in game metres (check_ankylo.py adapted to the rig_biped.py biped).
Every clip in anim/ is checked for
- stretch: worst edge length / rest length, FAIL above --stretch (default 8; check_stego.py uses 12; the worst here are 7 mm mouth-corner edges when the jaw opens),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch, lowest <= 0.05 m),
- moonwalk: in walk/run/charge each foot's planted run (sole within 4 cm of the floor) slides backwards (+Y in Blender:
  this rig faces -Y); walk_back the opposite; strafes slide against their travel,
- glide: one-shots and idle keep a planted toe on its print: while a toe stays within 3 cm of the floor it may not move
  more than 6 cm (a kick pivot turns the foot on the print, it does not slide it),
- the snap is the hit (attack_primary at 0.42, anim_events.json): the snout (Head/Jaw skin) is the front-most point of the
  body and has driven at least 0.2 m forward of its rest reach,
- the rake is the hit (attack_heavy at 0.72): the right toe is out ahead of the chest and sweeping (>= 2 m/s),
- the spit is the hit (spit at 0.62): the snout is whipping forward (>= 1.5 m/s) with the jaws open,
- the leaping slash is the hit (pounce at 0.7): both toes are ahead of the hips (claws forward),
- the frill: shut (narrower than 1.4 m: folded it hugs the neck) in idle, walk and run; open (wider than 2.4 m) in alert, attack_heavy and spit
  at their hold/hit frames.
The pounce's flight is the game's (TacticalBrain arcs the body), so it is not held to the floor or glide rules.
usage: Blender -b -P tools/gait/check_dilophosaurus.py -- <base.glb> <anim_dir> --height 3.6   (exit 1 on any FAIL)
"""
import os
import sys

import bpy
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 3.6
STRETCH = float(a[a.index("--stretch") + 1]) if "--stretch" in a else 8.0
ONLY = a[a.index("--only") + 1].split(",") if "--only" in a else None
FPS = 24
HIT = {"attack_primary": 0.42, "attack_heavy": 0.72, "spit": 0.62, "pounce": 0.7}
FRILL_OPEN = {"alert": 0.5, "attack_heavy": 0.6, "spit": 0.55}
FRILL_SHUT = {"idle", "walk", "run"}
GAITS = {"walk": 1, "run": 1, "walk_back": -1}  # sign of the planted foot's y drift (+y = backwards)
STRAFE = {"strafe_left": -1, "strafe_right": 1}  # sign of x drift of a planted foot (+x = the animal's left)
LYING = {"knockdown", "death", "sleep"}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
body = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
sc = bpy.context.scene


def pts():
    dg = bpy.context.evaluated_depsgraph_get()
    e = body.evaluated_get(dg)
    me = e.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    e.to_mesh_clear()
    co = co.reshape(-1, 3)
    mw = np.array(body.matrix_world)
    return (co @ mw[:3, :3].T + mw[:3, 3]) * K


arm.animation_data_clear()
for pb in arm.pose.bones:
    pb.matrix_basis.identity()
bpy.context.view_layer.update()
K = 1.0
rest = pts()
K = H / (rest[:, 2].max() - rest[:, 2].min())
rest = rest * K
print(f"scale {K:.3f} (rest height {rest[:, 2].max():.2f} m, length {np.ptp(rest[:, 1]):.2f} m)")
edges = np.array([e.vertices[:] for e in body.data.edges])
rl = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
ok = rl > 2e-3 * H
gi = {g.index: g.name for g in body.vertex_groups}
dom = np.array([gi[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in body.data.vertices])
TOES = {s: np.where(dom == "Toe." + s)[0] for s in "LR"}
SOLES = {s: np.where(np.isin(dom, ["Toe." + s, "Metatarsal." + s]))[0] for s in "LR"}
SNOUT = np.where(np.isin(dom, ["Head", "Jaw"]))[0]
JAW = np.where(dom == "Jaw")[0]
FRILL = np.array([i for i, n in enumerate(dom) if n.startswith("Frill")])
CHEST = np.where(dom == "Chest")[0]
HIPV = np.where(dom == "Hips")[0]
assert all(len(v) > 20 for v in TOES.values()) and len(SNOUT) > 20 and len(JAW) > 20 and len(FRILL) > 100, ({s: len(v) for s, v in TOES.items()}, len(SNOUT), len(JAW), len(FRILL))
fails = 0
for f in sorted(os.listdir(anim_dir)):
    if not f.endswith(".glb"):
        continue
    clip = f[:-4]
    if ONLY and clip not in ONLY:
        continue
    objs = set(bpy.data.objects)
    acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=os.path.join(anim_dir, f))
    new = set(bpy.data.actions) - acts
    for o in set(bpy.data.objects) - objs:
        bpy.data.objects.remove(o, do_unlink=True)
    if not new:
        print(f"CLIP {clip} FAIL no action")
        fails += 1
        continue
    act = max(new, key=lambda x: x.frame_range[1])
    arm.animation_data_create()
    arm.animation_data.action = act
    try:
        arm.animation_data.action_slot = act.slots[0]
    except Exception:
        pass
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    lows, stretch, where = [], 1.0, {}
    toe, sole, snout, gape, front, frill, chest, hipy = {s: [] for s in "LR"}, {s: [] for s in "LR"}, [], [], [], [], [], []
    for fr in range(f0, f1 + 1):
        sc.frame_set(fr)
        p = pts()
        lows.append(p[:, 2].min())
        l = np.linalg.norm(p[edges[:, 0]] - p[edges[:, 1]], axis=1)
        r = np.where(ok, l / np.maximum(rl, 1e-9), 1.0)
        if r.max() > stretch:
            stretch = float(r.max())
            k = int(r.argmax())
            where["stretch"] = (fr, dom[edges[k, 0]], dom[edges[k, 1]], round(float(rl[k]), 3))
        for s in "LR":
            toe[s].append(p[TOES[s]].mean(axis=0) * [1, 1, 0] + [0, 0, p[TOES[s], 2].min()])
            sole[s].append((p[SOLES[s], 2].min(), p[SOLES[s]].mean(axis=0)))
        snout.append(p[SNOUT][p[SNOUT, 1].argmin()])  # the snout's front-most point
        gape.append(float(p[SNOUT, 2].max() - p[JAW, 2].min()))
        front.append(p[:, 1].min())
        frill.append(float(np.ptp(p[FRILL, 0])))
        chest.append(float(p[CHEST, 1].min()))
        hipy.append(float(p[HIPV, 1].mean()))
    if clip == "pounce":  # in flight the game lifts the body on its arc: the floor applies on the ground only
        lows = [z for k, z in enumerate(lows) if not 0.2 <= k / max(1, f1 - f0) <= 0.65]
    lo, hi_low = min(lows), max(lows)
    bad, extra = [], ""
    if stretch > STRETCH:
        bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03:
        bad.append(f"sinks {lo:.3f}")
    if clip not in LYING and clip not in ("run", "pounce") and hi_low > 0.05:
        bad.append(f"floats {hi_low:.3f}")
    drift = {}
    if clip in GAITS or clip in STRAFE:
        ax = 1 if clip in GAITS else 0
        want = GAITS.get(clip, STRAFE.get(clip))
        for s in "LR":
            best, cur = [], []
            for z, c in sole[s]:
                if z < 0.04:
                    cur.append(c[ax])
                else:
                    best = cur if len(cur) > len(best) else best
                    cur = []
            best = cur if len(cur) > len(best) else best
            d = (best[-1] - best[0]) if len(best) > 1 else 0.0
            drift[s] = round(d, 3)
            if want * d < -0.05:
                bad.append(f"moonwalk {s} {d:+.2f}")
    elif clip not in LYING and clip != "pounce":
        for s in "LR":
            slide, start = 0.0, None
            for t in toe[s]:
                if t[2] < 0.03:
                    start = t if start is None else start
                    slide = max(slide, float(np.linalg.norm((t - start)[:2])))
                else:
                    start = None
            drift[s] = round(slide, 3)
            if slide > 0.06:
                bad.append(f"glide {s} {slide:.2f} m")
    n = f1 - f0
    if clip in HIT:
        i = int(round(HIT[clip] * n))
        if clip == "attack_primary":
            reach, rest_reach = -snout[i][1], -snout[0][1]
            behind = snout[i][1] - front[i]
            extra = f" snout@hit reach={reach:.2f} m (rest {rest_reach:.2f}), {behind:.2f} m behind the front-most point"
            if behind > 0.04 or reach < rest_reach + 0.2:
                bad.append("the snap does not lead with the snout")
        elif clip == "attack_heavy":
            t = toe["R"][i]
            v = float(np.linalg.norm(toe["R"][i] - toe["R"][max(0, i - 3)])) / (3.0 / FPS)
            extra = f" toe.R@hit y={t[1]:+.2f} m (chest {chest[i]:+.2f}) speed={v:.1f} m/s"
            if t[1] > chest[i] + 0.3 or v < 2.0:
                bad.append("the rake does not sweep out front")
        elif clip == "spit":
            v = (snout[max(0, i - 2)][1] - snout[i][1]) / (2.0 / FPS)
            extra = f" snout@spit forward-speed={v:.1f} m/s gape={gape[i]:.2f} m (rest {gape[0]:.2f})"
            if v < 1.5 or gape[i] < gape[0] + 0.1:
                bad.append("the spit does not whip forward open-mouthed")
        elif clip == "pounce":
            ty = max(toe["L"][i][1], toe["R"][i][1])
            extra = f" toes@hit y={ty:+.2f} m hips {hipy[i]:+.2f}"
            if ty > hipy[i]:
                bad.append("the slash does not lead with the claws")
    if clip in FRILL_OPEN:
        w = frill[int(round(FRILL_OPEN[clip] * n))]
        extra += f" frill={w:.2f} m"
        if w < 2.4:
            bad.append(f"frill not open ({w:.2f} m)")
    if clip in FRILL_SHUT:
        w = max(frill)
        extra += f" frill<={w:.2f} m"
        if w > 1.4:
            bad.append(f"frill not shut ({w:.2f} m)")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1 - f0 + 1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] feet={drift}{extra} at={where}")
    fails += bool(bad)
print("DILO_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
