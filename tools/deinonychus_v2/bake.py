# Bake the nine clips onto rig.blend, floor-pass the lying frames, measure, save anim.blend + stats.json.
# Blender -b rig.blend --factory-startup -P bake.py -- <out.blend> <stats.json> [clip ...]
import bpy, sys, os, json, math, importlib
import numpy as np
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import alib, clips, rlib
importlib.reload(alib); importlib.reload(clips)
a = sys.argv[sys.argv.index("--") + 1:]
out_blend, out_stats = a[0], a[1]
only = a[2:]
arm = bpy.data.objects["Armature"]; mesh = bpy.data.objects["SM_Deinonychus"]
rig = alib.Rig(arm)
sc = bpy.context.scene; sc.render.fps = alib.FPS
me0 = mesh.data
E = np.empty(len(me0.edges) * 2, np.int64); me0.edges.foreach_get("vertices", E); E = E.reshape(-1, 2)
P0 = np.empty(len(me0.vertices) * 3); me0.vertices.foreach_get("co", P0); P0 = P0.reshape(-1, 3)
L0 = np.linalg.norm(P0[E[:, 0]] - P0[E[:, 1]], axis=1); E = E[L0 > 0.008]; L0 = L0[L0 > 0.008]  # ignore degenerate slivers
LEGB = alib.LEG


def apply_pose(B, loc):
    for n in rig.order:
        pb = arm.pose.bones[n]; pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = B.get(n); pb.location = loc.get(n, Vector())
    bpy.context.view_layer.update()


def minz():
    return float(rlib.mesh_points(mesh)[:, 2].min())


def leg_checks(spec):
    hr = alib.eul(spec.get("hips", {}).get("rot", (0, 0, 0))).to_matrix()
    F = hr @ alib.Y; Lat = hr @ alib.X
    res = {}
    for s in "RL":
        H = rig.M[f"Thigh.{s}"].translation; K = rig.M[f"Shin.{s}"].translation; A = rig.M[f"Metatarsal.{s}"].translation; Bl = rig.M[f"Toe.{s}"].translation
        u = (A - H).normalized(); ko = (K - H) - u * (K - H).dot(u)
        v = (Bl - K).normalized(); ao = (A - K) - v * (A - K).dot(v)
        tw = 0.0
        for b in LEGB:
            m = rig.M[f"{b}.{s}"].to_3x3(); y = m.col[1]; x = m.col[0]
            lp = (Lat - y * Lat.dot(y))
            if lp.length > 1e-3: tw = max(tw, math.degrees(x.angle(lp.normalized())))
        res[s] = dict(knee_fwd=ko.dot(F), ankle_back=-ao.dot(F), twist=tw, ball=tuple(Bl), reach=rig.diag.get(s, {}).get("reach", 0))
    return res


stats = {}
for name, cls in clips.CLIPS.items():
    if only and name not in only: continue
    c = cls(rig)
    N = int(round(c.dur * alib.FPS))
    arm.animation_data_create()
    act = bpy.data.actions.new(name); act.use_fake_user = True
    arm.animation_data.action = act
    try:
        if len(act.slots) == 0: act.slots.new(id_type="OBJECT", name="Armature")
        arm.animation_data.action_slot = act.slots[0]
    except Exception as e:
        print("slot", e)
    kw = {}
    if c.lie:  # resting height: the final pose with the hips at lz=0, then lifted so its lowest skin point touches z=0
        B, loc = rig.solve(c.spec(c.dur, lz=0.0)); apply_pose(B, loc); kw["lz"] = -minz()
        print(name, "lie lz", round(kw["lz"], 3))
    specs = []
    prev = None
    for f in range(N + 1):
        t = f / alib.FPS if f < N or not c.loop else 0.0  # loops: last frame == first frame
        sp = c.spec(t, **kw); specs.append(sp)
        B, loc = rig.solve(sp); prev = rig.key(B, loc, f, prev)
    act.use_frame_range = True; act.frame_start = 0; act.frame_end = N
    # floor pass and measurements
    st = dict(frames=N + 1, dur=N / alib.FPS, minz=[], knee_fwd_min=9, ankle_back_min=9, twist_max=0, reach_max=0, stretch_max=0, stretch_frame=0, over15=0)
    balls = {s: [] for s in "RL"}
    for f in range(N + 1):
        sp = specs[f]; t = f / alib.FPS
        mode = c.ground(t)
        sc.frame_set(f)
        mz = minz()
        for it in range(3):
            need = (mode == "snap" and abs(mz) > 0.003) or (mode == "lift" and mz < -0.003)
            if not need: break
            o = sp["hips"]["off"]; sp["hips"]["off"] = (o[0], o[1], o[2] - mz)
            B, loc = rig.solve(sp); rig.key(B, loc, f, None); sc.frame_set(f); mz = minz()
        rig.solve(sp)
        lc = leg_checks(sp)
        P = rlib.mesh_points(mesh)
        Lr = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1) / L0
        if Lr.max() > st["stretch_max"]:
            st["stretch_max"], st["stretch_frame"] = float(Lr.max()), f
            k = int(Lr.argmax()); st["stretch_where"] = [round(float(c), 2) for c in P0[E[k, 0]]]
        lo = int(P[:, 2].argmin()); st.setdefault("minz_where", {})[f] = [round(float(c), 2) for c in P0[lo]]
        st["over15"] = max(st["over15"], int((Lr > 1.5).sum()))
        st["minz"].append(round(mz, 4))
        for s in "RL":
            st["knee_fwd_min"] = min(st["knee_fwd_min"], lc[s]["knee_fwd"]); st["ankle_back_min"] = min(st["ankle_back_min"], lc[s]["ankle_back"])
            st["twist_max"] = max(st["twist_max"], lc[s]["twist"]); st["reach_max"] = max(st["reach_max"], lc[s]["reach"])
            balls[s].append(lc[s]["ball"])
    if c.loop and name in ("walk", "run"):
        dt = 1.0 / alib.FPS
        for s in "RL":
            Bz = np.array(balls[s]); zmin = Bz[:, 2].min(); tol = 0.054
            v = [(Bz[i + 1, 1] - Bz[i, 1]) / dt for i in range(N) if Bz[i, 2] <= zmin + tol and Bz[i + 1, 2] <= zmin + tol]
            st[f"planted_speed_{s}"] = float(abs(np.median(v))) if v else 0.0
            st[f"planted_frac_{s}"] = len(v) / N
    mzs = st["minz"]
    st["minz_min"], st["minz_max"] = min(mzs), max(mzs)
    st["minz_end"] = mzs[-1]
    stats[name] = st
    print(f"CLIP {name}: {N + 1} frames {st['dur']:.2f}s minz {st['minz_min']:.3f}..{st['minz_max']:.3f} end {st['minz_end']:.3f} "
          f"knee_fwd>= {st['knee_fwd_min']:.3f} ankle_back>= {st['ankle_back_min']:.3f} twist<= {st['twist_max']:.1f} reach<= {st['reach_max']:.3f} "
          f"stretch {st['stretch_max']:.2f}@{st['stretch_frame']} edges>1.5x {st['over15']}"
          + (f" planted v L {st.get('planted_speed_L', 0):.2f} R {st.get('planted_speed_R', 0):.2f} m/s" if name in ("walk", "run") else ""))
arm.animation_data.action = None
for pb in arm.pose.bones: pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
json.dump(stats, open(out_stats, "w"), indent=1)
print("BAKED", list(stats))
