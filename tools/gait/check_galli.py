"""GALLIMIMUS clip gate (SP-GALLIMIMUS; check_pachy.py adapted). PACHY clip gate on the real skinned mesh, in game metres (check_ankylo.py adapted to the rig_biped.py biped).
Every clip in anim/ is checked for
- stretch: worst edge length / rest length, FAIL above --stretch (default 8; check_stego.py uses 12; the worst here are 7 mm mouth-corner edges when the jaw opens),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch, lowest <= 0.05 m),
- moonwalk: in walk/run/charge each foot's planted run (sole within 4 cm of the floor) slides backwards (+Y in Blender:
  this rig faces -Y); walk_back the opposite; strafes slide against their travel,
- glide: one-shots and idle keep a planted toe on its print: while a toe stays within 3 cm of the floor it may not move
  more than 6 cm (a kick pivot turns the foot on the print, it does not slide it),
- the peck is the hit (attack_primary at 0.42 and bite_combo at 0.092 / 0.338): the beak tip (front-most head skin)
  is within 0.2 m of the peck target in her chest (3.3 m ahead, 1.3 m up; contact reach 3.1 m) and drove there from at least 0.6 m away,
- the kick is the hit (attack_heavy at 0.72, bite_combo at 0.815): the right toe tip is 2 m or more ahead at survivor
  height (0.3-1.4 m), moving at >= 3 m/s, after the telegraph raised it at least 1.0 m,
- hop_back, leap_back, dodge_left/right: frames inside the airborne window (0.2-0.65) are not held to the floor;
  the striking / stepping right foot of the attacks may leave its print.
usage: Blender -b -P tools/gait/check_galli.py -- <base.glb> <anim_dir> --height 3.8   (exit 1 on any FAIL)
"""
import os
import sys

import bpy
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 3.8
STRETCH = float(a[a.index("--stretch") + 1]) if "--stretch" in a else 8.0
ONLY = a[a.index("--only") + 1].split(",") if "--only" in a else None
FPS = 24
PECK = {"attack_primary": [0.42], "bite_combo": [0.092, 0.338]}
KICK = {"attack_heavy": [0.72], "bite_combo": [0.815]}
CHEST = (-3.3, 1.3)  # the peck target: survivor chest: y (ahead = -y), z, game metres
GAITS = {"walk": 1, "run": 1, "charge": 1, "walk_back": -1}  # sign of the planted foot's y drift (+y = backwards)
STRAFE = {"strafe_left": -1, "strafe_right": 1}  # sign of x drift of a planted foot (+x = the animal's left)
LYING = {"knockdown", "death", "sleep"}
AIR = {c: (0.2, 0.65) for c in ("hop_back", "leap_back", "dodge_left", "dodge_right")}  # anim_events airborne: the game lifts the body on its arc, the feet tuck (no touch/glide gate)
PAW = {"attack_heavy": "R", "bite_combo": "R", "attack_primary": "R"}  # the pawing foot scrapes back along the ground on purpose
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
HEAD = np.where(np.isin(dom, ["Head", "Jaw"]))[0]
BEAK = HEAD[np.argsort(rest[HEAD, 1])[:8]]  # the beak tip: the front-most head skin at rest
TOER = TOES["R"][np.argsort(rest[TOES["R"], 1])[:8]]  # the right claws' tips
assert all(len(v) > 20 for v in TOES.values()) and len(HEAD) > 20, ({s: len(v) for s, v in TOES.items()}, len(HEAD))
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
    toe, sole, beak, toer, front = {s: [] for s in "LR"}, {s: [] for s in "LR"}, [], [], []
    air = AIR.get(clip)
    for fr in range(f0, f1 + 1):
        sc.frame_set(fr)
        p = pts()
        u = (fr - f0) / max(1, f1 - f0)
        lows.append(p[:, 2].min() if not (air and air[0] < u < air[1]) else 0.0)
        l = np.linalg.norm(p[edges[:, 0]] - p[edges[:, 1]], axis=1)
        r = np.where(ok, l / np.maximum(rl, 1e-9), 1.0)
        if r.max() > stretch:
            stretch = float(r.max())
            k = int(r.argmax())
            where["stretch"] = (fr, dom[edges[k, 0]], dom[edges[k, 1]], round(float(rl[k]), 3))
        for s in "LR":
            toe[s].append(p[TOES[s]].mean(axis=0) * [1, 1, 0] + [0, 0, p[TOES[s], 2].min()])
            sole[s].append((p[SOLES[s], 2].min(), p[SOLES[s]].mean(axis=0)))
        beak.append(p[BEAK].mean(axis=0))
        toer.append(p[TOER].mean(axis=0))
        front.append(p[:, 1].min())
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
            if PAW.get(clip) == s:
                continue
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
    for hf in PECK.get(clip, []):
        i = int(round(hf * n))
        d = float(np.hypot(beak[i][1] - CHEST[0], beak[i][2] - CHEST[1]))
        far = max(float(np.hypot(b[1] - CHEST[0], b[2] - CHEST[1])) for b in beak[max(0, i - 8):i + 1])
        extra += f" peck@{hf}: beak {d:.2f} m from her chest (from {far:.2f})"
        if d > 0.2 or far < 0.6:
            bad.append(f"peck {hf} misses ({d:.2f} m)")
    for hf in KICK.get(clip, []):
        i = int(round(hf * n))
        t, t0 = toer[i], toer[max(0, i - 2)]
        v = float(np.linalg.norm(t - t0)) / (2.0 / FPS)
        top = max(float(x[2]) for x in toer[:i])
        extra += f" kick@{hf}: toe ahead {-t[1]:.2f} m, up {t[2]:.2f} m, {v:.1f} m/s, raised {top:.2f} m"
        if not (0.3 <= t[2] <= 1.4) or v < 3.0 or top < 1.0 or -t[1] < 2.0:
            bad.append(f"kick {hf} does not strike")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1 - f0 + 1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] feet={drift}{extra} at={where}")
    fails += bool(bad)
print("GALLI_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
