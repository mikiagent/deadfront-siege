"""SP-SPINOSAURUS clip gate on the real skinned mesh, in game metres (check_cerato.py adapted). Every clip in anim/ is
checked for
- stretch: worst edge length / rest length, FAIL above --stretch (default 8),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch with a foot, <= 0.06 m; the
  pounce is airborne by design between 0.2 and 0.65 and must touch at its start and end),
- moonwalk: in walk/run each foot's planted run slides backwards (+Y: this rig faces -Y); walk_back the opposite;
  strafes slide against their travel,
- glide (the no-glide rule): one-shots and idle keep a planted toe on its print: while a toe stays within 3 cm of the
  floor it may not move more than 6 cm,
- the croc snap is the hit (attack_primary at 0.42): the snout leads, >= 0.5 m forward of rest, and is down at the
  survivor (snout <= 2.6 m off the ground: she is 1.78 m),
- the claw rake is the hit (attack_heavy at 0.72): the hands are >= 0.5 m forward of rest, low enough to reach her
  (<= 2.6 m) and raking down at >= 2 m/s,
- the snap-and-shake clamps at its hit (bite_shake at 0.30): the snout leads and is down at her (<= 2.6 m); the shake
  (0.44-0.70) swings the snout sideways at >= 2 m/s,
- the tail swipe is the hit (kick at 0.45): the tail tip swings sideways at >= 3 m/s,
- the lunge is the hit (pounce at 0.7): the snout leads,
- stalk (the wading creep) is a gait: no moonwalk.
usage: Blender -b -P tools/gait/check_spino.py -- <base.glb> <anim_dir> --height 9.0   (exit 1 on any FAIL)
"""
import os
import sys

import bpy
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 9.0
STRETCH = float(a[a.index("--stretch") + 1]) if "--stretch" in a else 8.0
ONLY = a[a.index("--only") + 1].split(",") if "--only" in a else None
FPS = 24
HIT = {"attack_primary": 0.42, "attack_heavy": 0.72, "bite_shake": 0.30, "kick": 0.45, "pounce": 0.7}
LOW_M = 2.6  # snout / claws at the hit no higher than this: the survivor is 1.78 m
GAITS = {"walk": 1, "run": 1, "stalk": 1, "walk_back": -1}  # sign of the planted foot's y drift (+y = backwards)
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
DOME = np.where(np.isin(dom, ["Head", "Jaw"]))[0]  # the head: its front-most point is the snout / nose horn
TAILN = sorted({str(d) for d in dom if str(d).startswith("Tail")}, key=lambda n: int(n[4:]))
HIPS = np.where(np.isin(dom, TAILN[-2:]))[0]  # the tail tip that whips in the swipe
HANDS = np.where(np.isin(dom, ["Hand.L", "Hand.R"]))[0]  # the claws that rake
assert len(HANDS) > 20, len(HANDS)
assert all(len(v) > 20 for v in TOES.values()) and len(DOME) > 20 and len(HIPS) > 20, ({s: len(v) for s, v in TOES.items()}, len(DOME), len(HIPS))
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
    toe, sole, dome, hips, front, hand = {s: [] for s in "LR"}, {s: [] for s in "LR"}, [], [], [], []
    for fr in range(f0, f1 + 1):
        sc.frame_set(fr)
        p = pts()
        lows.append(p[:, 2].min())
        l = np.linalg.norm(p[edges[:, 0]] - p[edges[:, 1]], axis=1)
        r = np.where(ok, l / np.maximum(rl, 1e-9), 1.0)
        if r.max() > stretch:
            stretch = float(r.max())
            k = int(r.argmax())
            where["stretch"] = (fr, dom[edges[k, 0]], dom[edges[k, 1]], round(float(rl[k]), 3), [round(float(x), 2) for x in rest[edges[k, 0]]])
        for s in "LR":
            toe[s].append(p[TOES[s]].mean(axis=0) * [1, 1, 0] + [0, 0, p[TOES[s], 2].min()])
            sole[s].append((p[SOLES[s], 2].min(), p[SOLES[s]].mean(axis=0)))
        dome.append(p[DOME][p[DOME, 1].argmin()])  # the dome's front-most point
        hips.append(p[HIPS].mean(axis=0))
        front.append(p[:, 1].min())
        hp = p[HANDS]
        hand.append(hp[hp[:, 1].argmin()])  # the front-most claw
    lo, hi_low = min(lows), max(lows)
    bad, extra = [], ""
    if stretch > STRETCH:
        bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03:
        bad.append(f"sinks {lo:.3f}")
    if clip == "pounce" and max(lows[0], lows[-1]) > 0.05:
        bad.append(f"lunge does not start and end on the ground {lows[0]:.3f} {lows[-1]:.3f}")
    if clip not in LYING and clip not in ("run", "pounce") and hi_low > 0.05:
        bad.append(f"floats {hi_low:.3f}")
    # ground_clip lifts the whole body when anything (a drooping tail, the snout) digs in: then the feet hover
    feet_low = [min(sole["L"][k][0], sole["R"][k][0]) for k in range(len(lows))]
    if clip not in LYING and clip not in ("run", "pounce") and max(feet_low) > 0.06:
        k = int(np.argmax(feet_low))
        bad.append(f"feet off the floor {max(feet_low):.2f} m at frame {f0 + k} (the body was lifted: something dug in)")
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
        i = int(round(HIT[clip] * n))
        reach = -dome[i][1]
        ahead = dome[i][1] - front[i]
        extra = f" snout@hit reach={reach:.2f} m ahead-of-origin (rest {-dome[0][1]:.2f}), {ahead:.2f} m behind the front-most point"
        if clip in ("attack_primary", "bite_shake", "pounce") and ahead > 0.04:
            bad.append(f"snout {ahead:.2f} m behind the front-most point at the hit")
        if clip in ("attack_primary", "bite_shake"):
            extra += f" snout height={dome[i][2]:.2f} m"
            if reach < -dome[0][1] + 0.5:
                bad.append("the head does not drive forward")
            if dome[i][2] > LOW_M:
                bad.append(f"snout {dome[i][2]:.2f} m up at the hit: over her head")
        if clip == "bite_shake":
            a0, a1 = int(0.44 * n), int(0.70 * n)
            sp = max(abs(dome[k][0] - dome[k - 1][0]) * FPS for k in range(a0 + 1, a1 + 1))
            extra += f" shake side-speed={sp:.1f} m/s"
            if sp < 2.0:
                bad.append(f"the shake only {sp:.1f} m/s")
        if clip == "attack_heavy":
            hreach = -hand[i][1]
            vz = (hand[min(n, i + 2)][2] - hand[max(0, i - 2)][2]) / (4.0 / FPS)
            extra = f" claw@hit reach={hreach:.2f} m (rest {-hand[0][1]:.2f}) height={hand[i][2]:.2f} m down-speed={-vz:.1f} m/s"
            if hreach < -hand[0][1] + 0.5:
                bad.append("the claws do not drive forward")
            if hand[i][2] > LOW_M:
                bad.append(f"claws {hand[i][2]:.2f} m up at the hit: over her head")
            if -vz < 2.0:
                bad.append(f"the rake does not come down ({-vz:.1f} m/s)")
        if clip == "kick":
            sp = abs(hips[i][0] - hips[max(0, i - 3)][0]) / (3.0 / FPS)
            extra = f" tail@hit side-speed={sp:.1f} m/s side={hips[i][0]:+.2f} m"
            if sp < 3.0:
                bad.append(f"tail swipe only {sp:.1f} m/s")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1 - f0 + 1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] feet={drift}{extra} at={where}")
    fails += bool(bad)
print("SPINO_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
