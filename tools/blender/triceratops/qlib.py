# Triceratops pose solver: FK from local rest-relative rotations plus analytic two-bone IK on all four legs.
# Each leg: the ball of the foot (Metatarsal / Hand tail) is the target; the foot bone leans by `theta` (deg, + = the
# ankle/wrist ahead of the ball, i.e. heel lifted) about the body's lateral axis; hip-knee-ankle (shoulder-elbow-wrist)
# is a two-bone solve whose middle joint stays on its rest side of the line: knees forward, elbows back, so no leg can
# bend the wrong way. Every bone frame keeps local X on the body's lateral axis, so no limb twists by construction.
# Adapted from tools/deinonychus_v2/alib.py (biped) for a quadruped.
import math
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler

FPS = 30
X = Vector((1, 0, 0)); Y = Vector((0, 1, 0)); Z = Vector((0, 0, 1))
CHAINS = {"hind": ("Thigh", "Shin", "Metatarsal", "Toe"), "front": ("UpperArm", "Forearm", "Hand", "Finger")}
LEGS = {"HR": ("hind", "R"), "HL": ("hind", "L"), "FR": ("front", "R"), "FL": ("front", "L")}
ROOT_PARENT = {"hind": "Hips", "front": "Chest"}
POLE_SIGN = {"hind": 1, "front": -1}  # knees point forward (+Y), elbows back (-Y)


def eul(d):
    return Euler([math.radians(a) for a in d], "XYZ")


def frame(y, lat, pos):
    y = y.normalized(); x = (lat - y * lat.dot(y)).normalized(); z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4(); m.translation = pos; return m


def track(keys, t, loop=None):
    """Catmull-Rom through (time, value) keys, clamped between neighbouring keys (no overshoot)."""
    ts = [k[0] for k in keys]; vs = [np.atleast_1d(np.array(k[1], float)) for k in keys]
    if loop:
        t = t % loop
    if t <= ts[0]: return _out(vs[0])
    if t >= ts[-1]: return _out(vs[-1])
    i = max(j for j in range(len(ts) - 1) if ts[j] <= t)
    t0, t1 = ts[i], ts[i + 1]; u = (t - t0) / (t1 - t0)
    p1, p2 = vs[i], vs[i + 1]
    if loop:
        p0 = vs[i - 1] if i > 0 else vs[-2]; p3 = vs[i + 2] if i + 2 < len(vs) else vs[1]
    else:
        p0 = vs[i - 1] if i > 0 else p1; p3 = vs[i + 2] if i + 2 < len(vs) else p2
    dt0 = t0 - (ts[i - 1] if i > 0 else t0 - (t1 - t0)); dt2 = (ts[i + 2] if i + 2 < len(ts) else t1 + (t1 - t0)) - t1
    m1 = (p2 - p0) / (t1 - t0 + dt0) * (t1 - t0); m2 = (p3 - p1) / (t1 - t0 + dt2) * (t1 - t0)
    if not loop and i == 0: m1 = m1 * 0
    if not loop and i + 2 >= len(vs): m2 = m2 * 0
    h00 = 2 * u ** 3 - 3 * u ** 2 + 1; h10 = u ** 3 - 2 * u ** 2 + u; h01 = -2 * u ** 3 + 3 * u ** 2; h11 = u ** 3 - u ** 2
    v = h00 * p1 + h10 * m1 + h01 * p2 + h11 * m2
    return _out(np.clip(v, np.minimum(p1, p2), np.maximum(p1, p2)))


def _out(v):
    return float(v[0]) if v.size == 1 else tuple(float(a) for a in v)


def ss(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0); return t * t * (3 - 2 * t)


class Rig:
    def __init__(self, arm):
        self.arm = arm
        bones = arm.data.bones
        self.R = {b.name: b.matrix_local.copy() for b in bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.order = []
        todo = [b.name for b in bones if b.parent is None]
        while todo:
            n = todo.pop(0); self.order.append(n)
            todo += [c.name for c in bones[n].children]
        self.lrest = {n: (self.R[p].inverted() @ self.R[n] if p else self.R[n]) for n, p in self.parent.items()}
        self.hips_head = self.R["Hips"].translation.copy()
        self.L = {}
        for k, (kind, s) in LEGS.items():
            names = [f"{b}.{s}" for b in CHAINS[kind]]
            up, lo, ft, to = (self.R[n] for n in names)
            l3 = bones[names[2]].length
            ball0 = ft.translation + ft.to_3x3() @ Vector((0, l3, 0))
            H0, K0, A0 = up.translation, lo.translation, ft.translation
            u0 = (A0 - H0).normalized(); p0 = K0 - (H0 + u0 * (K0 - H0).dot(u0))
            assert p0.normalized().dot(Y) * POLE_SIGN[kind] > 0.8, ("middle joint on the wrong side at rest", k, p0)
            self.L[k] = dict(kind=kind, side=s, names=names, parent=ROOT_PARENT[kind], l1=bones[names[0]].length, l2=bones[names[1]].length,
                             l3=l3, a0=A0 - ball0, ball0=ball0, toe0=(to.to_3x3() @ Y).normalized(), pole0=p0.normalized())

    def body_rot(self, M, name):
        """Rotation applied to bone `name` since rest (world)."""
        return M[name].to_3x3() @ self.R[name].to_3x3().inverted()

    # spec: {"hips": {"off": vec, "rot": (rx, ry, rz) deg world}, "rot": {bone: (x, y, z) deg local},
    #        "legs": {"HR": {"ball": vec, "theta": deg, "toe": deg, "toe_lat": "world"|"body"|0..1, "a_lat": "world"|"body",
    #                        "fk": {bone base: (x,y,z)}, "w": fk weight}, ...}}
    def solve(self, spec):
        M, B, loc = {}, {}, {}
        hs = spec.get("hips", {})
        hrot = eul(hs.get("rot", (0, 0, 0))).to_matrix()
        off = Vector(hs.get("off", (0, 0, 0)))
        rots = spec.get("rot", {}); legs = spec.get("legs", {})
        roots = {self.L[k]["names"][0]: k for k in self.L}
        inleg = {n: k for k in self.L for n in self.L[k]["names"][1:]}
        self.diag = {}
        for n in self.order:
            p = self.parent[n]
            if p is None:
                M[n] = self.R[n].copy(); B[n] = Quaternion(); continue
            Mpr = M[p] @ self.lrest[n]
            if n == "Hips":
                h = self.hips_head
                M[n] = Matrix.Translation(h + off) @ hrot.to_4x4() @ Matrix.Translation(-h) @ self.R[n]
                bas = Mpr.inverted() @ M[n]
                B[n] = bas.to_quaternion(); loc[n] = bas.translation.copy(); continue
            if n in roots and roots[n] in legs:
                self._leg(roots[n], legs[roots[n]], M, B); continue
            if n in inleg and inleg[n] in legs:
                M[n] = M[p] @ self.lrest[n] @ B[n].to_matrix().to_4x4(); continue
            q = eul(rots[n]).to_quaternion() if n in rots else Quaternion()
            B[n] = q; M[n] = Mpr @ q.to_matrix().to_4x4()
        self.M = M
        return B, loc

    def _leg(self, k, lg, M, B):
        d = self.L[k]; names = d["names"]
        Mpr = M[d["parent"]] @ self.lrest[names[0]]
        H = Mpr.translation.copy()
        Rp = self.body_rot(M, d["parent"])
        lat = (Rp @ X).normalized(); fwd = (Rp @ Y).normalized()
        qik = None
        w = float(lg.get("w", 0.0))
        if w < 1.0:
            ball = Vector(lg["ball"])
            th = math.radians(lg.get("theta", 0.0))
            a = Matrix.Rotation(-th, 3, lat) @ (Rp @ d["a0"]) if lg.get("a_lat", "world") == "body" else Matrix.Rotation(-th, 3, X) @ d["a0"]
            ankle = ball + a
            v = ankle - H; dist = v.length; u = v.normalized()
            lim = (d["l1"] + d["l2"]) * 0.995
            self.diag[k] = dict(reach=dist / (d["l1"] + d["l2"]))
            dist_c = min(max(dist, abs(d["l1"] - d["l2"]) + 0.02), lim)
            ca = (d["l1"] ** 2 + dist_c ** 2 - d["l2"] ** 2) / (2 * d["l1"] * dist_c)
            al = math.acos(max(-1, min(1, ca)))
            pole = Rp @ d["pole0"]
            pv = pole - u * pole.dot(u)
            if pv.length < 1e-4: pv = fwd * POLE_SIGN[d["kind"]] - u * (fwd * POLE_SIGN[d["kind"]]).dot(u)
            pv.normalize()
            knee = H + d["l1"] * (math.cos(al) * u + math.sin(al) * pv)
            ankle_r = H + dist_c * u
            kk = lg.get("toe_lat", "world"); kk = 0.0 if kk == "world" else 1.0 if kk == "body" else float(kk)
            tl = (X * (1 - kk) + lat * kk).normalized()
            t0 = (d["toe0"] * (1 - kk) + (Rp @ d["toe0"]) * kk).normalized()
            toe_dir = Matrix.Rotation(-math.radians(lg.get("toe", 0.0)), 3, tl) @ t0
            mats = [frame(knee - H, lat, H), frame(ankle_r - knee, lat, knee), frame(-a, lat, ankle_r)]
            ball_r = ankle_r + (-a).normalized() * d["l3"]
            mats.append(frame(toe_dir, tl, ball_r))
            qik = []
            for i, n in enumerate(names):
                pr = Mpr if i == 0 else mats[i - 1] @ self.lrest[n]
                qik.append((pr.inverted() @ mats[i]).to_quaternion())
            self.diag[k].update(knee=knee, ankle=ankle_r, hip=H, ball=ball_r, fwd=fwd, lat=lat)
        fk = lg.get("fk", {})
        for i, n in enumerate(names):
            qf = eul(fk.get(n.split(".")[0], (0, 0, 0))).to_quaternion()
            if qik is None: q = qf
            elif w <= 0: q = qik[i]
            else:
                a_ = qik[i]
                if a_.dot(qf) < 0: qf = -qf
                q = a_.slerp(qf, w)
            B[n] = q
        M[names[0]] = Mpr @ B[names[0]].to_matrix().to_4x4()

    def key(self, B, loc, f, prev=None):
        pbs = self.arm.pose.bones
        for n in self.order:
            pb = pbs[n]; pb.rotation_mode = "QUATERNION"
            q = B.get(n, Quaternion())
            if prev is not None and n in prev and prev[n].dot(q) < 0: q = -q
            B[n] = q
            pb.rotation_quaternion = q
            pb.location = loc.get(n, Vector())
            pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
            pb.keyframe_insert("location", frame=f, group=n)
        return B
