"""SP-ALLOSAURUS clip gate on the real skinned mesh, in game metres (check_pachy.py adapted). Every clip in anim/ is checked for
- stretch: worst edge length / rest length, FAIL above --stretch (default 10: the jaw opens to 48 deg on a 14 m animal),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch, lowest <= 0.05 m),
- moonwalk: in walk/run each foot's planted run (sole within 6 cm of the floor) slides backwards (+Y: this rig faces -Y);
  walk_back the opposite; strafes slide against their travel,
- glide: one-shots and idle keep a planted toe on its print: while a toe stays within 3 cm of the floor it may not move
  more than 10 cm (a 6.5 m animal; the pachy gate's 6 cm at 1.8 m),
- the left foot stays on the floor in every standing one-shot but hit_react (no over-reach),
- the hits (anim_events.json fractions):
  attack_primary 0.42: the jaw tip drives forward (>= 0.6 m past rest) and down (>= 2 m),
  attack_heavy 0.72 (hatchet): the upper jaw (front Head skin) chops down at >= 4 m/s, from >= 1.5 m higher at 0.55,
  grab_bite 0.3: the hands reach >= 0.8 m further forward than at rest; 0.55 and 0.8: the jaw tip is <= 1.2 m up,
  kick 0.45 (shoulder ram): the chest/shoulder skin moves at >= 2.5 m/s,
  ALLOFEEL: claw_rake 0.5: the hand skin rakes down at >= 3 m/s and is >= 0.5 m lower than at rest; slash_bite 0.42: the
  upper jaw slashes down at >= 4 m/s from >= 1 m higher at 0.3; check_left/right 0.45: the chest/shoulder skin moves
  sideways toward that flank at >= 2.5 m/s,
- ALLOFEEL arms in every attack (owner 2026-10-31: "the arms should be moving as part of the attack animation"): from the
  first frame to the hit frame the leading claw tip (Hand bone tail, in the Chest bone's frame: the arm's own motion, not
  the body carrying it) travels >= 1.0 m and the other >= 0.4 m, the elbow bends through >= 30 deg and the wrist (the
  claws spreading and curling) through >= 30 deg.
usage: Blender -b -P tools/gait/check_allo.py -- <base.glb> <anim_dir> --height 6.5   (exit 1 on any FAIL)
"""
import os
import sys

import bpy
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 6.5
STRETCH = float(a[a.index("--stretch") + 1]) if "--stretch" in a else 10.0
ONLY = a[a.index("--only") + 1].split(",") if "--only" in a else None
FPS = 24
HIT = {"attack_primary": 0.42, "attack_heavy": 0.72, "kick": 0.45, "grab_bite": 0.3,
       "claw_rake": 0.5, "slash_bite": 0.42, "check_left": 0.45, "check_right": 0.45}
ARMS = list(HIT)  # every attack moves its arms
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
head = np.where(dom == "Head")[0]
DOME = head[rest[head, 1] < rest[head, 1].min() + 0.3 * np.ptp(rest[head, 1])]  # the upper jaw: front third of the skull skin
JAW = np.where(dom == "Jaw")[0]
JAWTIP = JAW[rest[JAW, 1] < rest[JAW, 1].min() + 0.15 * np.ptp(rest[JAW, 1])]
HANDS = np.where(np.isin(dom, ["Hand.L", "Hand.R"]))[0]
HIPS = np.where(np.isin(dom, ["Chest", "Arm.R", "Arm.L", "Spine1"]))[0]  # the chest and shoulders that ram
assert all(len(v) > 20 for v in TOES.values()) and min(len(DOME), len(JAWTIP), len(HANDS), len(HIPS)) > 10, ({s: len(v) for s, v in TOES.items()}, len(DOME), len(JAWTIP), len(HANDS), len(HIPS))
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
    armrow = []  # per frame, per side: (claw tip in the Chest frame, elbow deg, wrist deg)
    toe, sole, dome, hips, front, jaw, hands = {s: [] for s in "LR"}, {s: [] for s in "LR"}, [], [], [], [], []
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
        dome.append(p[DOME].mean(axis=0))
        jaw.append(p[JAWTIP].mean(axis=0))
        hands.append(p[HANDS].mean(axis=0))
        hips.append(p[HIPS].mean(axis=0))
        front.append(p[:, 1].min())
        pb = arm.pose.bones
        ch = pb["Chest"].matrix.inverted()
        # the claw tip = the Hand head + 0.045 rig units along it (allosaurus_rig.json's hand; the glTF importer guesses
        # bone tails, so .tail would overstate it); hitboxes.json's ClawTip offset is the same 0.64 m
        armrow.append([(ch @ (pb["Hand." + s].head + (pb["Hand." + s].tail - pb["Hand." + s].head).normalized() * 0.045) * K,
                        np.degrees(pb["Arm." + s].vector.angle(pb["Forearm." + s].vector)),
                        np.degrees(pb["Forearm." + s].vector.angle(pb["Hand." + s].vector))) for s in "LR"])
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
                if z < 0.06:
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
            if slide > 0.10:
                bad.append(f"glide {s} {slide:.2f} m")
        # the left foot is the planted one in every standing one-shot but hit_react's stagger step: it never leaves the
        # floor (an over-reached leg lifts it off its print)
        lmax = max(z for z, _ in sole["L"])
        if clip not in ("hit_react", "check_left") and lmax > 0.04:  # ALLOFEEL: check_left steps its left foot out
            bad.append(f"left foot lifts {lmax:.2f} m")
    if clip in HIT:
        n = f1 - f0
        i = int(round(HIT[clip] * n))
        at = lambda u: int(round(u * n))
        if clip == "attack_primary":
            fwd = jaw[0][1] - jaw[i][1]
            extra = f" jaw@hit reach={-jaw[i][1]:.2f} m ahead height={jaw[i][2]:.2f} m (rest reach {-jaw[0][1]:.2f}, height {jaw[0][2]:.2f})"
            if fwd < 0.6 or jaw[i][2] > jaw[0][2] - 2.0:
                bad.append("bite does not drive forward and down")
        elif clip == "attack_heavy":
            v = (dome[i - 2][2] - dome[i][2]) / (2.0 / FPS)
            drop = dome[at(0.55)][2] - dome[i][2]
            extra = f" upper-jaw@hit reach={-dome[i][1]:.2f} m height={dome[i][2]:.2f} m down-speed={v:.1f} m/s drop-from-raised={drop:.2f} m"
            if v < 4.0 or drop < 1.5:
                bad.append("hatchet does not chop down on the hit")
        elif clip == "grab_bite":
            fwd = hands[0][1] - hands[i][1]
            b1, b2 = jaw[at(0.55)], jaw[at(0.8)]
            extra = f" hands@grab reach={-hands[i][1]:.2f} m height={hands[i][2]:.2f} m (+{fwd:.2f}); bites jaw at ({-b1[1]:.2f}, {b1[2]:.2f}) ({-b2[1]:.2f}, {b2[2]:.2f})"
            if fwd < 0.8 or b1[2] > 1.2 or b2[2] > 1.2:
                bad.append("grab does not reach or bites do not come down")
        elif clip == "claw_rake":
            hd = (hands[i - 2][2] - hands[i][2]) / (2.0 / FPS)
            extra = f" hands@hit reach={-hands[i][1]:.2f} m height={hands[i][2]:.2f} m (rest {hands[0][2]:.2f}) down-speed={hd:.1f} m/s"
            if hd < 3.0 or hands[i][2] > hands[0][2] - 0.5:
                bad.append("rake does not drive the claws down")
        elif clip == "slash_bite":
            v = (dome[i - 2][2] - dome[i][2]) / (2.0 / FPS)
            drop = dome[at(0.3)][2] - dome[i][2]
            extra = f" upper-jaw@hit reach={-dome[i][1]:.2f} m side={-dome[i][0]:+.2f} m height={dome[i][2]:.2f} m down-speed={v:.1f} m/s drop={drop:.2f} m"
            if v < 4.0 or drop < 1.0:
                bad.append("slash does not cut down on the hit")
        elif clip in ("check_left", "check_right"):
            sgn = 1.0 if clip == "check_left" else -1.0  # +x is the animal's left
            sp = sgn * float(hips[i][0] - hips[max(0, i - 3)][0]) / (3.0 / FPS)
            extra = f" shoulder@hit sideways speed={sp:.1f} m/s at side {hips[i][0]:+.2f} m"
            if sp < 2.5:
                bad.append(f"shoulder-check only {sp:.1f} m/s sideways")
        elif clip == "kick":
            sp = float(np.linalg.norm((hips[i] - hips[max(0, i - 3)])[:2])) / (3.0 / FPS)
            extra = f" shoulder@hit speed={sp:.1f} m/s at ({hips[i][0]:+.2f}, {-hips[i][1]:.2f}) m"
            if sp < 2.5:
                bad.append(f"shoulder ram only {sp:.1f} m/s")
    if clip in ARMS:
        n = f1 - f0
        i = int(round(HIT[clip] * n))
        tr = [max(float(np.linalg.norm(np.array(r[k][0] - armrow[0][k][0]))) for r in armrow[:i + 1]) for k in (0, 1)]
        el = [max(r[k][1] for r in armrow[:i + 1]) - min(r[k][1] for r in armrow[:i + 1]) for k in (0, 1)]
        wr = [max(r[k][2] for r in armrow[:i + 1]) - min(r[k][2] for r in armrow[:i + 1]) for k in (0, 1)]
        extra += f" arms: tip travel L {tr[0]:.2f} R {tr[1]:.2f} m, elbow {el[0]:.0f}/{el[1]:.0f} deg, wrist {wr[0]:.0f}/{wr[1]:.0f} deg"
        if max(tr) < 1.0 or min(tr) < 0.4 or max(el) < 30 or max(wr) < 30:
            bad.append("arms do not move in the attack")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1 - f0 + 1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}@{int(np.argmax(lows))} soles {sole["L"][int(np.argmax(lows))][0]:.3f},{sole["R"][int(np.argmax(lows))][0]:.3f}] feet={drift}{extra} at={where}")
    fails += bool(bad)
print("ALLO_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
