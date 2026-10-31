"""ANKYLO3D clip gate on the real skinned mesh, in game metres (the GLB is in Tripo units; --height is the species
height_meters, so the mesh is scaled by height / rest height). Every clip in anim/ is checked for
- stretch: worst edge length / rest length, FAIL above 12 (check_stego.py's calibration),
- ground: lowest skin point per frame (below -0.03 m = sinking; standing clips must touch, lowest <= 0.05 m),
- moonwalk: in walk/run each foot's planted run (sole within 4 cm of the floor) slides backwards (+Y in Blender: this
  rig faces -Y) or stays put; walk_back the opposite. Drift = y(end) - y(start) in metres; below -0.05 on walk/run fails,
- ANKYLOAI planted feet: in every tail move (attack_primary, attack_heavy, tail_swipe), alert and (ANKYLOCLOSE) the close
  moves (stomp, shove_left, shove_right, tackle), each foot's sole, while
  planted (within 3 cm of the floor), moves at most --slide metres in total over each planted run (the body may turn
  over it; a foot that moves must lift: a step),
- ANKYLOAI the club is the hit: ClubTailBrain's move table (game/data/creatures/ai.json archetypes.club_tail.club_moves)
  names each move's strike window (fractions of the clip) and the spot it is aimed at (target_bearing_deg, + = right of
  the snout, target_dist_m from the creature origin). In that window the club (skin weighted mostly to Tail5) must pass
  within hit_radius_m - 0.35 (survivor radius) of that spot, move faster than --club-speed m/s there, and never come
  within hit_radius_m + 0.35 of a survivor standing at the snout (bearing 0, 1 m ahead of the head). The script prints
  the club's bearing/distance through the window: those are the numbers the move table is set from.
- STEGOSPIN turn clips (spin_*, pivot_*: a move or pivot with turn_deg in club_tail): checked in the WORLD frame, i.e. with
  the brain's code turn (turn_deg * smoothstep over turn [a, b] about pivot_gltf) put back on, and held to the planted-foot
  rule like the tail moves (the pivot foot twists about its own centre, so its sole moves a little: SLIDE covers it).
usage: Blender -b -P tools/gait/check_ankylo.py -- <base.glb> <anim_dir> --height 2.25   (exit 1 on any FAIL)
"""
import bpy, sys, os
import numpy as np

a = sys.argv[sys.argv.index("--") + 1:]
base, anim_dir = a[0], a[1]
H = float(a[a.index("--height") + 1]) if "--height" in a else 2.25
CLUB_SPEED = float(a[a.index("--club-speed") + 1]) if "--club-speed" in a else 3.0
SLIDE = float(a[a.index("--slide") + 1]) if "--slide" in a else 0.03
import json, math
AI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../game/data/creatures/ai.json")
_CT = json.load(open(AI))["archetypes"]["club_tail"]
MOVES = {m["clip"]: m for m in _CT["club_moves"].values()}
# ANKYLOCLOSE: stomp / shove / tackle keep every foot planted except the one that steps or stomps
PLANTED = set(MOVES) | {"alert"} | {m["clip"] for m in _CT.get("close_moves", {}).values()}
TURNS = {m["clip"]: m for g in ("club_moves", "close_moves", "pivots") for m in _CT.get(g, {}).values() if "turn_deg" in m}
PLANTED |= set(TURNS)
SURVIVOR_R = 0.35
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
# the sole proper: vertices weighted 0.9+ to the foot bone (the dominant set includes ankle skin that bends with the shin)
PURE = {f"{k}_{s}": np.array([v.index for v in body.data.vertices
                              if sum(g.weight for g in v.groups if gi[g.group] == f"{k}Foot.{s}") > 0.9])
        for k in ("Back", "Front") for s in ("L", "R")}
CLUB = np.where(dom == "Tail5")[0]
assert len(FEET) == 4 and len(CLUB) > 50, (list(FEET), len(CLUB))
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
        if clip in TURNS:  # put the brain's code turn back on: the world view
            tm = TURNS[clip]
            uu = (fr - f0) / max(1, f1 - f0)
            x = min(max((uu - tm["turn"][0]) / (tm["turn"][1] - tm["turn"][0]), 0.0), 1.0)
            ang = math.radians(tm["turn_deg"] * x * x * (3 - 2 * x))
            pv = np.array([tm["pivot_gltf"][0], -tm["pivot_gltf"][1]]) * K
            q = p[:, :2] - pv
            p = p.copy()
            p[:, 0] = pv[0] + q[:, 0] * math.cos(ang) - q[:, 1] * math.sin(ang)
            p[:, 1] = pv[1] + q[:, 0] * math.sin(ang) + q[:, 1] * math.cos(ang)
        lows.append(p[:, 2].min())
        if p[:, 2].min() <= min(lows): where["low"] = (fr, dom[int(p[:, 2].argmin())])
        l = np.linalg.norm(p[edges[:, 0]] - p[edges[:, 1]], axis=1)
        r = np.where(ok, l / np.maximum(rl, 1e-9), 1.0)
        if r.max() > stretch:
            stretch = float(r.max()); k = int(r.argmax())
            where["stretch"] = (fr, dom[edges[k, 0]], dom[edges[k, 1]], round(float(rl[k]), 3))
        for k, idx in FEET.items():
            fp = p[idx]; sp_ = p[PURE[k]]; feet[k].append((fp[:, 2].min(), fp[:, 1].mean(), sp_[:, :2].mean(axis=0), sp_[:, 2].min()))
        club.append(p[CLUB].mean(axis=0))
    lo, hi_low = min(lows), max(lows)
    bad, extra = [], ""
    if stretch > 12.0: bad.append(f"stretch {stretch:.2f}")
    if lo < -0.03: bad.append(f"sinks {lo:.3f}")
    if clip not in LYING and clip not in ("run",) and hi_low > 0.05: bad.append(f"floats {hi_low:.3f}")
    drift = {}
    if clip in ("walk", "run", "walk_back"):
        for k, seq in feet.items():
            best, cur = [], []
            for z, y, _, _ in seq:
                if z < 0.04: cur.append(y)
                else:
                    if len(cur) > len(best): best = cur
                    cur = []
            if len(cur) > len(best): best = cur
            d = (best[-1] - best[0]) if len(best) > 1 else 0.0
            drift[k] = round(d, 3)
            if (-1 if clip == "walk_back" else 1) * -d > 0.05: bad.append(f"moonwalk {k} {d:+.2f}")
    if clip in PLANTED:
        worst = (0.0, "")
        for k, seq in feet.items():
            run = 0.0
            for (_, _, p0, z0), (_, _, p1, z1) in zip(seq, seq[1:]):
                if z0 < 0.03 and z1 < 0.03:
                    run += float(np.linalg.norm(p1 - p0))
                    if run > worst[0]: worst = (run, k)
                else:
                    run = 0.0
        extra += f" slide={worst[0]:.3f} m ({worst[1]})"
        if worst[0] > SLIDE: bad.append(f"planted foot {worst[1]} slides {worst[0]:.3f} m")
    if clip in MOVES:
        mv = MOVES[clip]
        n = f1 - f0
        i0, i1 = int(math.floor(mv["strike"][0] * n)), int(math.ceil(mv["strike"][1] * n))
        b = math.radians(mv["target_bearing_deg"])
        tgt = np.array([-math.sin(b), -math.cos(b)]) * mv["target_dist_m"]  # rig faces -Y, right is -X
        head_y = rest[:, 1].min()
        snout = np.array([0.0, head_y - 1.0])
        r = mv["hit_radius_m"]
        path = []
        for i in range(i0, i1 + 1):
            c2 = club[i][:2]
            sp = np.linalg.norm(club[i] - club[max(0, i - 1)]) * FPS
            path.append((i, float(np.linalg.norm(c2 - tgt)), float(np.linalg.norm(c2 - snout)), sp,
                         math.degrees(math.atan2(-c2[0], -c2[1])), float(np.linalg.norm(c2)), float(club[i][2])))
        best = min(path, key=lambda q: q[1])
        near_head = min(q[2] for q in path)
        extra += (f" club: closest {best[1]:.2f} m to the target spot at frame {best[0]} ({best[0] / n:.2f}), {best[3]:.1f} m/s;"
                  f" nearest the snout {near_head:.2f} m; path " + " ".join(f"{q[0]}:{q[4]:+.0f}deg/{q[5]:.1f}m/z{q[6]:.1f}" for q in path))
        if best[1] > r - SURVIVOR_R: bad.append(f"club misses the target spot by {best[1]:.2f} m (radius {r - SURVIVOR_R:.2f})")
        if best[3] < CLUB_SPEED and not mv.get("slam"): bad.append(f"club moving {best[3]:.1f} m/s at the target")
        if mv.get("slam") and min(q[6] for q in path) > mv.get("slam_height_m", 0.9): bad.append(f"slam: the club never comes down to {mv.get('slam_height_m', 0.9)} m in the window")
        if near_head < r + SURVIVOR_R: bad.append(f"club reaches a survivor at the snout ({near_head:.2f} m)")
    print(f"CLIP {clip} {'FAIL ' + '; '.join(bad) if bad else 'PASS'} frames={f1-f0+1} stretch={stretch:.2f} low=[{lo:.3f},{hi_low:.3f}] drift={drift}{extra} at={where}")
    fails += bool(bad)
print("ANKYLO_CHECK", "PASS" if fails == 0 else f"FAIL {fails}")
sys.exit(1 if fails else 0)
