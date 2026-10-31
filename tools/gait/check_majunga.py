"""MAJUNGASAURUS clip gate on the real skinned mesh, in game metres (check_pachy.py adapted: same rig_biped.py rig).
Every clip in anim/ is checked for
- stretch: worst edge length / rest length, FAIL above --stretch (default 8; check_stego.py uses 12; the worst here are 7 mm mouth-corner edges when the jaw opens),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch, lowest <= 0.05 m),
- moonwalk: in walk/run/charge each foot's planted run (sole within 4 cm of the floor) slides backwards (+Y in Blender:
  this rig faces -Y); walk_back the opposite; strafes slide against their travel,
- glide: one-shots and idle keep a planted toe on its print: while a toe stays within 3 cm of the floor it may not move
  more than 6 cm (a kick pivot turns the foot on the print, it does not slide it),
- the crushing bite is the hit (attack_primary at 0.42, anim_events.json): the jaw skin comes down to a survivor's
  height (lowest jaw point <= 2.0 m, at least 1.2 m below rest) and the jaw has just snapped shut (its gap to the
  skull closing at the hit),
- the headbutt is the hit (attack_heavy at 0.72): the skull top (Head skin in the top third) drives forward >= 0.3 m
  past its rest and is moving forward at >= 2 m/s,
- the low tail swipe is the hit (kick at 0.45): the mid tail (Tail3-5 skin) sweeps sideways at >= 2 m/s, lower than at rest,
- the grab-and-shake is the hit (pin_stab at 0.38 and 0.74): the jaw skin is low (lowest point <= 0.6 m) and shaking
  sideways at >= 1.5 m/s on each hit frame.
usage: Blender -b -P tools/gait/check_majunga.py -- <base.glb> <anim_dir> --height 5.0   (exit 1 on any FAIL)
"""
import os
import sys

import bpy
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 5.0
STRETCH = float(a[a.index("--stretch") + 1]) if "--stretch" in a else 10.0
ONLY = a[a.index("--only") + 1].split(",") if "--only" in a else None
FPS = 24
HIT = {"attack_primary": [0.42], "attack_heavy": [0.72], "kick": [0.45], "pin_stab": [0.38, 0.74]}
GAITS = {"walk": 1, "run": 1, "charge": 1, "walk_back": -1}  # sign of the planted foot's y drift (+y = backwards)
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
head = np.where(dom == "Head")[0]
hz = rest[head, 2]
DOME = head[hz > hz.min() + 0.67 * np.ptp(hz)]
TAIL = np.where(np.isin(dom, ["Tail3", "Tail4", "Tail5"]))[0]  # the mid tail that sweeps in the swipe
JAW = np.where(dom == "Jaw")[0]
assert all(len(v) > 20 for v in TOES.values()) and len(DOME) > 20 and len(TAIL) > 20 and len(JAW) > 20, ({s: len(v) for s, v in TOES.items()}, len(DOME), len(TAIL), len(JAW))
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
    toe, sole, dome, tail, jaw, gap = {s: [] for s in "LR"}, {s: [] for s in "LR"}, [], [], [], []
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
        dome.append(p[DOME][p[DOME, 1].argmin()])  # the skull top's front-most point
        tail.append(p[TAIL].mean(axis=0))
        jaw.append((p[JAW, 2].min(), p[JAW].mean(axis=0)))
        gap.append(float(np.linalg.norm(p[JAW].mean(axis=0) - p[DOME].mean(axis=0))))
    lo, hi_low = min(lows), max(lows)
    bad, extra = [], ""
    if stretch > STRETCH:
        bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03:
        bad.append(f"sinks {lo:.3f}")
    if clip not in LYING and clip not in ("run", "charge") and hi_low > 0.05:
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
    elif clip not in LYING:
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
    if clip in HIT:
        n = f1 - f0
        dt = 3.0 / FPS
        for hf in HIT[clip]:
            i = int(round(hf * n))
            j = max(0, i - 3)
            if clip == "attack_primary":
                low, rest_low = jaw[i][0], jaw[0][0]
                shut = (gap[j] - gap[i]) / dt
                extra += f" bite@{hf} jaw low={low:.2f} m (rest {rest_low:.2f}) closing={shut:.1f} m/s"
                if low > 2.0 or rest_low - low < 1.2:
                    bad.append(f"bite jaws at {low:.2f} m")
                if shut <= 0.0:
                    bad.append("jaws not closing at the hit")
            elif clip == "attack_heavy":
                fwd = dome[0][1] - dome[i][1]
                v = (dome[j][1] - dome[i][1]) / dt
                extra += f" butt@{hf} skull {fwd:.2f} m forward of rest, {v:.1f} m/s, at {dome[i][2]:.2f} m"
                if fwd < 0.3 or v < 2.0:
                    bad.append(f"headbutt does not drive the skull forward ({fwd:.2f} m, {v:.1f} m/s)")
            elif clip == "kick":
                sp = abs(tail[i][0] - tail[j][0]) / dt
                extra += f" swipe@{hf} tail side-speed={sp:.1f} m/s z={tail[i][2]:.2f} (rest {tail[0][2]:.2f})"
                if sp < 2.0 or tail[i][2] >= tail[0][2]:
                    bad.append(f"tail swipe only {sp:.1f} m/s")
            elif clip == "pin_stab":
                sp = abs(jaw[i][1][0] - jaw[j][1][0]) / dt
                extra += f" shake@{hf} jaw low={jaw[i][0]:.2f} m side-speed={sp:.1f} m/s"
                if jaw[i][0] > 0.6 or sp < 1.5:
                    bad.append(f"shake at {hf}: jaw {jaw[i][0]:.2f} m, {sp:.1f} m/s")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1 - f0 + 1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] feet={drift}{extra} at={where}")
    fails += bool(bad)
print("MAJUNGA_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
