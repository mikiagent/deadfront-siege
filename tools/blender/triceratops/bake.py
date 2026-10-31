# Bake the nine clips onto rig.blend, floor-pass the lying frames, measure on the skinned mesh, save anim.blend + stats.
# Blender -b rig.blend --factory-startup -P bake.py -- <out.blend> <stats.json> [clip ...]
# Per clip: lowest skin point per frame, knee-forward / elbow-back margins, limb twist, IK reach, edge stretch (whole
# skin and the rigid head: frill, horns), planted-foot speeds of the gaits (the stride the game's bake will measure).
import bpy, sys, os, json, math, importlib
import numpy as np
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qlib, rlib
clips = importlib.import_module(os.environ.get("TRIKE_CLIPS", "clips"))  # clips_alpha: the Alpha's set
importlib.reload(qlib); importlib.reload(clips)
a = sys.argv[sys.argv.index("--") + 1:]
out_blend, out_stats = a[0], a[1]
only = a[2:]
arm = bpy.data.objects["Armature"]; mesh = bpy.data.objects["SM_Triceratops"]
rig = qlib.Rig(arm)
sc = bpy.context.scene; sc.render.fps = qlib.FPS
me0 = mesh.data
E = np.empty(len(me0.edges) * 2, np.int64); me0.edges.foreach_get("vertices", E); E = E.reshape(-1, 2)
P0 = np.empty(len(me0.vertices) * 3); me0.vertices.foreach_get("co", P0); P0 = P0.reshape(-1, 3)
L0 = np.linalg.norm(P0[E[:, 0]] - P0[E[:, 1]], axis=1); keep = L0 > 0.01; E = E[keep]; L0 = L0[keep]  # ignore slivers
gi = {g.name: g.index for g in mesh.vertex_groups}
hw = np.zeros(len(P0))
for v in me0.vertices:
    for g in v.groups:
        if g.group == gi["Head"]: hw[v.index] = g.weight
HEADE = (hw[E[:, 0]] > 0.99) & (hw[E[:, 1]] > 0.99)  # rigid head edges (face, horns, frill): must not stretch at all
names = [g.name for g in mesh.vertex_groups]
DOM = np.zeros(len(P0), int)
for v in me0.vertices:
    if v.groups: DOM[v.index] = max(v.groups, key=lambda g: g.weight).group


FOOTV = {}  # per leg: vertices owned by its foot bones (Metatarsal/Toe, Hand/Finger)
for k, d in rig.L.items():
    ids = {gi[d["names"][2]], gi[d["names"][3]]}
    FOOTV[k] = np.array([i for i in range(len(P0)) if DOM[i] in ids])


def apply_pose(B, loc):
    for n in rig.order:
        pb = arm.pose.bones[n]; pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = B.get(n); pb.location = loc.get(n, Vector())
    bpy.context.view_layer.update()


def minz():
    return float(rlib.mesh_points(mesh)[:, 2].min())


def leg_checks():
    res = {}
    for k, d in rig.L.items():
        n = d["names"]; up = rig.M[d["parent"]].to_3x3() @ rig.R[d["parent"]].to_3x3().inverted()
        F = up @ qlib.Y; Lat = up @ qlib.X
        H = rig.M[n[0]].translation; K = rig.M[n[1]].translation; A = rig.M[n[2]].translation; Bl = rig.M[n[3]].translation
        u = (A - H).normalized(); ko = (K - H) - u * (K - H).dot(u)
        tw = 0.0
        for b in n[:3]:
            m = rig.M[b].to_3x3(); yv = m.col[1]; xv = m.col[0]
            lp = (Lat - yv * Lat.dot(yv))
            if lp.length > 1e-3: tw = max(tw, math.degrees(xv.angle(lp.normalized())))
        res[k] = dict(mid=ko.dot(F) * qlib.POLE_SIGN[d["kind"]], twist=tw, ball=tuple(Bl), reach=rig.diag.get(k, {}).get("reach", 0))
    return res


stats = {}
for name, cls in clips.CLIPS.items():
    if only and name not in only: continue
    c = cls(rig)
    N = int(round(c.dur * qlib.FPS))
    arm.animation_data_create()
    act = bpy.data.actions.get(name)
    if act: bpy.data.actions.remove(act)
    act = bpy.data.actions.new(name); act.use_fake_user = True
    arm.animation_data.action = act
    try:
        if len(act.slots) == 0: act.slots.new(id_type="OBJECT", name="Armature")
        arm.animation_data.action_slot = act.slots[0]
    except Exception as e:
        print("slot", e)
    kw = {}
    if c.lie:  # resting height: the final pose with the hips at lz=0, lifted so its lowest skin point touches z=0
        B, loc = rig.solve(c.spec(c.dur, lz=0.0)); apply_pose(B, loc); kw["lz"] = -minz()
        print(name, "lie lz", round(kw["lz"], 3))
    specs = []; prev = None
    for f in range(N + 1):
        t = f / qlib.FPS if f < N or not c.loop else 0.0  # loops: last frame == first frame
        sp = c.spec(t, **kw); specs.append(sp)
        B, loc = rig.solve(sp); prev = rig.key(B, loc, f, prev)
    act.use_frame_range = True; act.frame_start = 0; act.frame_end = N
    st = dict(frames=N + 1, dur=N / qlib.FPS, minz=[], mid_min=9, twist_max=0, reach_max=0, stretch_max=0, stretch_frame=0, over15=0, head_stretch=0)
    balls = {k: [] for k in rig.L}
    for f in range(N + 1):
        sp = specs[f]; t = f / qlib.FPS
        mode = c.ground(t)
        sc.frame_set(f)
        mz = minz()
        for it in range(3):
            need = (mode == "snap" and abs(mz) > 0.003) or (mode == "lift" and mz < -0.003)
            if not need: break
            o = sp["hips"]["off"]; sp["hips"]["off"] = (o[0], o[1], o[2] - mz)
            B, loc = rig.solve(sp); rig.key(B, loc, f, None); sc.frame_set(f); mz = minz()
        # foot floor pass: a planted (IK) foot whose sole or nails dip below the floor is raised by the dip
        for it in range(3):
            P = rlib.mesh_points(mesh); moved = False
            for k, idx in FOOTV.items():
                lg = sp["legs"].get(k)
                if lg is None or float(lg.get("w", 0.0)) >= 0.5: continue
                dz = float(P[idx, 2].min())
                if dz < -0.003:
                    b_ = lg["ball"]; lg["ball"] = (b_[0], b_[1], b_[2] - dz); moved = True
            if not moved: break
            B, loc = rig.solve(sp); rig.key(B, loc, f, None); sc.frame_set(f)
        mz = minz()
        rig.solve(sp)
        lc = leg_checks()
        P = rlib.mesh_points(mesh)
        Lr = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1) / L0
        st["head_stretch"] = max(st["head_stretch"], float(np.abs(Lr[HEADE] - 1).max()))
        if Lr.max() > st["stretch_max"]:
            st["stretch_max"], st["stretch_frame"] = float(Lr.max()), f
            kk = int(Lr.argmax()); st["stretch_where"] = [round(float(v), 2) for v in P0[E[kk, 0]]]
        st["over15"] = max(st["over15"], int((Lr > 1.5).sum()))
        for e in np.nonzero(Lr > 1.5)[0]:
            bn = names[DOM[E[e, 0]]]; st.setdefault("over15_bones", {})[bn] = max(st.setdefault("over15_bones", {}).get(bn, 0), float(Lr[e]))
        if mz < st.get("sink", 0.0):
            st["sink"] = mz; lo = int(P[:, 2].argmin()); st["sink_where"] = [round(float(v), 2) for v in P0[lo]] + [names[DOM[lo]], f]
        st["minz"].append(round(mz, 4))
        for k in rig.L:
            st["mid_min"] = min(st["mid_min"], lc[k]["mid"]); st["twist_max"] = max(st["twist_max"], lc[k]["twist"])
            st["reach_max"] = max(st["reach_max"], lc[k]["reach"]); balls[k].append(lc[k]["ball"])
    if c.loop and name in ("walk", "run"):
        dt = 1.0 / qlib.FPS
        for k in rig.L:
            Bz = np.array(balls[k]); zmin = Bz[:, 2].min(); tol = 0.07
            v = [(Bz[i + 1, 1] - Bz[i, 1]) / dt for i in range(N) if Bz[i, 2] <= zmin + tol and Bz[i + 1, 2] <= zmin + tol]
            st[f"planted_speed_{k}"] = float(abs(np.median(v))) if v else 0.0
    mzs = st["minz"]; st["minz_min"], st["minz_max"], st["minz_end"] = min(mzs), max(mzs), mzs[-1]
    stats[name] = st
    print(f"CLIP {name}: {N + 1} frames {st['dur']:.2f}s minz {st['minz_min']:.3f}..{st['minz_max']:.3f} end {st['minz_end']:.3f} "
          f"knee/elbow margin>= {st['mid_min']:.3f} twist<= {st['twist_max']:.1f} reach<= {st['reach_max']:.3f} "
          f"stretch {st['stretch_max']:.2f}@{st['stretch_frame']} {st.get('stretch_where')} edges>1.5x {st['over15']} head {st['head_stretch']:.4f}"
          + f" sink {st.get('sink_where')} over1.5 by bone {dict(sorted(((k, round(v, 1)) for k, v in st.get('over15_bones', {}).items()), key=lambda kv: -kv[1])[:6])}"
          + ("".join(f" v{k} {st.get('planted_speed_' + k, 0):.2f}" for k in rig.L) if name in ("walk", "run") else ""))
arm.animation_data.action = None
for pb in arm.pose.bones: pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
json.dump(stats, open(out_stats, "w"), indent=1)
print("BAKED", list(stats))
