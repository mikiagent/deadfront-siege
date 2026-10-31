"""SP-THERIZINOSAURUS clip gate on the real skinned mesh, in game metres (check_pachy.py adapted). Every clip in anim/ is
checked for stretch, ground (sinking/floating), moonwalk on gaits and strafes, and glide on one-shots (check_pachy's rules),
plus the claws are the hit (anim_events.json fractions):
- stretch gate 10 (check_pachy 8, check_stego 12),
- attack_primary 0.42 (the sweep): a claw tip is ahead of the chest, at survivor height (0-1.78 m) and moving >= 4 m/s,
- attack_heavy 0.72 (the overhead rake): a claw tip at survivor height, coming down >= 4 m/s after being >= 4 m up,
- bite_combo 0.092 / 0.338 / 0.815 (hook, backhand, double thrust): a claw tip at survivor height, moving >= 3 m/s.
The claw reach ahead of the origin at each hit is printed (tactics attack_range / hit_parts are set from it).
usage: Blender -b -P tools/gait/check_theri.py -- <base.glb> <anim_dir> --height 8.0   (exit 1 on any FAIL)
"""
import os
import sys

import bpy
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 8.0
STRETCH = float(a[a.index("--stretch") + 1]) if "--stretch" in a else 10.0  # the run stretches one 13 cm thigh-feather edge 9x
ONLY = a[a.index("--only") + 1].split(",") if "--only" in a else None
FPS = 24
HIT = {"attack_primary": [0.42], "attack_heavy": [0.72], "bite_combo": [0.092, 0.338, 0.815]}
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
CLAWS = np.where(np.isin(dom, ["Claw.L", "Claw.R"]))[0]
CHEST_Y = float(rest[np.where(dom == "Chest")[0], 1].mean())
assert all(len(v) > 20 for v in TOES.values()) and len(CLAWS) > 50, ({s: len(v) for s, v in TOES.items()}, len(CLAWS))
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
    toe, sole, claws = {s: [] for s in "LR"}, {s: [] for s in "LR"}, []
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
        claws.append(p[CLAWS])
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
        for frac in HIT[clip]:
            i = int(round(frac * n))
            c, cp = claws[i], claws[max(0, i - 2)]
            sp = np.linalg.norm(c - cp, axis=1) / (2.0 / FPS)
            low = (c[:, 2] >= -0.05) & (c[:, 2] <= 1.78)
            ahead = c[:, 1] < CHEST_Y  # ahead of the chest (the rig faces -Y)
            fast = sp >= (3.0 if clip == "bite_combo" else 4.0)
            hit = low & ahead & fast
            reach = float(-c[hit, 1].min()) if hit.any() else 0.0
            extra += f" claw@{frac}: {int(hit.sum())} tips low+ahead+fast, reach {reach:.2f} m, top speed {sp.max():.1f} m/s"
            if not hit.any():
                bad.append(f"no claw at survivor height moving at {frac}")
            if clip == "attack_heavy":
                top = max(float(cl[:, 2].max()) for cl in claws[:i])
                if top < 4.0:
                    bad.append(f"rake raised only {top:.1f} m")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1 - f0 + 1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] feet={drift}{extra} at={where}")
    fails += bool(bad)
print("THERI_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
