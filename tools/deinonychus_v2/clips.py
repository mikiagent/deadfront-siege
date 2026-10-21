# The nine game clips as functions of time. Units: metres in the mesh frame (3.6 m tall, head +Y, right +X).
# Rotation signs (local X is lateral on every bone): +X pitch lifts a forward-pointing bone's tip (spine, neck,
# head, jaw: + closes) and swings a down-pointing limb's tip forward (thigh, arm); tail bones point back, so -X
# raises the tail. +Z swings a bone's tip toward the animal's left (-X). Hips rot (deg, world XYZ): x = pitch
# (+ nose up), y = roll (+ right side down), z = yaw (+ nose left).
import math
from mathutils import Vector, Matrix
from alib import track, ss, eul

TAILS = [f"Tail{i}" for i in range(1, 9)]
NECK = ["Neck1", "Neck2", "Neck3"]


class Clip:
    loop = False
    lie = False
    def __init__(self, rig):
        self.rig = rig
        self.ball0 = {s: Vector(rig.L[s]["ball0"]) for s in "RL"}
        self.hh = rig.hips_head.copy()
    def ground(self, t):
        return "check"
    def planted(self, s, d=(0, 0, 0), theta=0.0, toe=0.0, **kw):
        return dict(ball=tuple(self.ball0[s] + Vector(d)), theta=theta, toe=toe, **kw)
    def hips_point(self, off, rot, body_off):
        """World position of a point given in the rest frame relative to the hips head, after the hips pose."""
        return self.hh + Vector(off) + eul(rot).to_matrix() @ Vector(body_off)


def merge(*ds):
    out = {}
    for d in ds:
        for k, v in d.items():
            if k in out and isinstance(v, tuple):
                out[k] = tuple(a + b for a, b in zip(out[k], v))
            else:
                out[k] = v
    return out


class Idle(Clip):
    dur, loop = 3.0, True
    def spec(self, t, **_):
        w = 2 * math.pi * t / self.dur; s = math.sin(w)
        rot = {"Spine2": (0.8 * s, 0, 0), "Chest": (1.0 * math.sin(w - 0.3), 0, 0),
               "Neck1": (1.2 * math.sin(2 * w), 0, 1.5 * s), "Neck2": (0, 0, 4 * s), "Neck3": (0, 0, 2 * math.sin(w - 0.3)),
               "Head": (1.5 * math.sin(2 * w + 0.5), 0, 4 * math.sin(w - 0.6)),
               "Jaw": (-1.5 * (1 - math.cos(w)) / 2, 0, 0),
               "Forearm.R": (2 * s, 0, 0), "Forearm.L": (2 * s, 0, 0), "Sickle.R": (2 * math.sin(2 * w), 0, 0), "Sickle.L": (2 * math.sin(2 * w + 1), 0, 0)}
        for i, b in enumerate(TAILS):
            rot[b] = (0.6 * math.sin(w - 0.4 * i), 0, 2.2 * math.sin(w - 0.35 * i))
        return {"hips": {"off": (0, 0, 0.008 * s), "rot": (0.4 * s, 0, 0)}, "rot": rot,
                "legs": {s_: self.planted(s_) for s_ in "RL"}}


class Gait(Clip):
    loop = True
    def a_vec(self, th, hrot):
        lat = hrot @ Vector((1, 0, 0))
        return Matrix.Rotation(-math.radians(th), 3, lat) @ (hrot @ self.rig.L["R"]["a0"])
    def leg(self, p, s, hrot):
        b = self.beta; D = self.v * b * self.dur
        y_front, y_back = self.ymid + D / 2, self.ymid - D / 2
        x = self.ball0[s].x * self.wide
        TL = 0.79  # toe length, ball to tip
        z0 = self.ball0[s].z
        if p < b:
            u = p / b
            y = y_front + (y_back - y_front) * u
            th = self.th_td + (self.th_to - self.th_td) * u ** 1.6
            # push-off: the ball rises and the toes pivot on their tips (tips stay on the ground)
            h = self.heel * ss(0.72, 1.0, u)
            return dict(ball=(x, y, z0 + h), theta=th, toe=math.degrees(math.asin(min(0.9, h / TL))))
        # swing: the ANKLE travels from its toe-off spot to its touchdown spot along a raised arc (so the femur
        # stays near its rest angle instead of swinging back with a trailing foot); the ball hangs from it.
        u = (p - b) / (1 - b)
        e = (1 - math.cos(math.pi * u)) / 2
        a_to = self.a_vec(self.th_to, hrot); a_td = self.a_vec(self.th_td, hrot)
        ank0 = Vector((x, y_back, z0 + self.heel)) + a_to
        ank1 = Vector((x, y_front, z0)) + a_td
        ank = ank0.lerp(ank1, e) + Vector((0, self.ank_fwd * math.sin(math.pi * u), self.lift * math.sin(math.pi * u)))
        th = track([(0, self.th_to), (0.4, self.th_sw), (1, self.th_td)], u)
        ball = ank - self.a_vec(th, hrot)
        toe = track([(0, math.degrees(math.asin(min(0.9, self.heel / TL)))), (0.25, 0), (0.55, self.curl), (0.9, 0), (1, 0)], u)
        return dict(ball=tuple(ball), theta=th, toe=toe)
    def spec(self, t, **_):
        p = (t / self.dur) % 1.0; w = 2 * math.pi * p; b = self.beta
        mid = b / 2  # right mid-stance
        bob = math.cos(2 * w - 4 * math.pi * mid)  # +1 at each mid-stance
        hz = self.drop + self.bob * (bob if self.walk else -bob)
        hx = self.sway * math.cos(w - 2 * math.pi * mid)
        roll = -self.roll * math.cos(w - 2 * math.pi * mid)
        yaw = self.yaw * math.cos(w - 2 * math.pi * 0.95)
        pitch = self.pitch + self.pitch_bob * bob
        hrot = eul((pitch, roll, yaw)).to_matrix()
        legs = {"R": self.leg(p, "R", hrot), "L": self.leg((p + 0.5) % 1.0, "L", hrot)}
        rot = {"Spine1": (0, 0, -0.3 * yaw), "Spine2": (0.5 * bob, 0, -0.3 * yaw), "Chest": (0, 0, -0.4 * yaw),
               "Neck1": (self.neck[0] - self.head_bob * bob, 0, -0.3 * yaw), "Neck2": (self.neck[1], 0, -0.2 * yaw), "Neck3": (self.neck[2], 0, 0),
               "Head": (self.neck[3] + self.head_bob * bob, 0, 0), "Jaw": (self.jaw, 0, 0),
               "Arm.R": (self.arm[0] + self.arm_sw * math.sin(w), 0, 0), "Arm.L": (self.arm[0] - self.arm_sw * math.sin(w), 0, 0),
               "Forearm.R": (self.arm[1], 0, 0), "Forearm.L": (self.arm[1], 0, 0), "Hand.R": (self.arm[2], 0, 0), "Hand.L": (self.arm[2], 0, 0),
               "Sickle.R": (self.sickle, 0, 0), "Sickle.L": (self.sickle, 0, 0)}
        for i, bn in enumerate(TAILS):
            rot[bn] = (self.tail_lift[i] + self.tail_bob * math.cos(2 * w - 4 * math.pi * mid - 0.5 * i), 0,
                       self.tail_sw * math.sin(w - 2 * math.pi * 0.95 - 0.45 * i))
        return {"hips": {"off": (hx, 0, hz), "rot": (pitch, roll, yaw)}, "rot": rot, "legs": legs}


class Walk(Gait):
    dur, v, beta, walk = 0.9, 2.6, 0.6, True
    ymid, wide = -0.33, 1.0
    th_td, th_to, th_sw = -24.0, 40.0, -30.0
    lift, curl, heel, ank_fwd = 0.22, 14.0, 0.10, 0.0
    drop, bob, sway, roll, yaw, pitch, pitch_bob = -0.07, 0.025, 0.035, 2.0, 3.0, -1.0, 0.6
    neck, head_bob, jaw = (-3.0, 0.0, 0.0, 3.0), 1.2, 0.0
    arm, arm_sw, sickle = (0.0, 0.0, 0.0), 3.0, 4.0
    tail_lift, tail_bob, tail_sw = [-1.0, 0, 0, 0, 0, 0, 0, 0], 0.8, 2.5


class Run(Gait):
    dur, v, beta, walk = 0.6, 6.6, 0.36, False
    ymid, wide = -0.30, 0.92
    th_td, th_to, th_sw = -26.0, 42.0, -40.0
    lift, curl, heel, ank_fwd = 0.30, 18.0, 0.12, 0.0
    drop, bob, sway, roll, yaw, pitch, pitch_bob = -0.12, 0.05, 0.02, 1.5, 2.0, -7.0, 1.0
    neck, head_bob, jaw = (-12.0, -6.0, 2.0, 13.0), 2.0, -3.0
    arm, arm_sw, sickle = (-18.0, 28.0, -10.0), 2.0, 8.0
    tail_lift, tail_bob, tail_sw = [-4.0, -1.0, 0, 0, 0, 0, 0, 0], 1.2, 1.5


def kt(keys, t):
    return track(keys, t)


class Alert(Clip):
    dur = 2.0
    def spec(self, t, **_):
        K = lambda keys: kt(keys, t)
        yawk = [(0, 0), (0.18, 0), (0.45, 1), (0.8, 1), (1.05, -1), (1.4, -1), (1.7, 0), (2.0, 0)]
        yv = K(yawk)
        on = K([(0, 0), (0.18, 1), (1.7, 1), (2.0, 0)])
        trem = 0.6 * math.sin(2 * math.pi * 7 * t) * on
        rot = {"Neck1": (-16 * on, 0, 12 * yv), "Neck2": (5 * on, 0, 8 * yv), "Neck3": (5 * on, 0, 4 * yv),
               "Head": (11 * on + trem, 0, 10 * yv), "Jaw": (-6 * on, 0, 0),
               "Arm.R": (10 * on, 0, 0), "Arm.L": (10 * on, 0, 0), "Forearm.R": (22 * on, 0, 0), "Forearm.L": (22 * on, 0, 0),
               "Hand.R": (-10 * on, 0, 0), "Hand.L": (-10 * on, 0, 0), "Sickle.R": (14 * on, 0, 0), "Sickle.L": (14 * on, 0, 0),
               "Chest": (2 * on, 0, 2 * yv)}
        lift = [-6, -3, -1.5, -1, -0.5, 0, 0, 0]
        for i, bn in enumerate(TAILS):
            rot[bn] = (lift[i] * on + 0.3 * trem, 0, -1.5 * yv * on)
        return {"hips": {"off": (0, 0.05 * on, -0.10 * on), "rot": (-3 * on, 0, -2 * yv)}, "rot": rot,
                "legs": {s: self.planted(s) for s in "RL"}}


class AttackPrimary(Clip):
    dur = 1.2  # bite closes at 42 % (anim_events attack_primary hit_frac)
    def spec(self, t, **_):
        K = lambda keys: kt(keys, t)
        hit = 0.42 * self.dur
        off = K([(0, (0, 0, 0)), (0.28, (0, -0.12, -0.06)), (hit, (0, 0.30, -0.10)), (0.62, (0, 0.27, -0.08)), (0.85, (0, 0.10, -0.03)), (1.2, (0, 0, 0))])
        hr = K([(0, (0, 0, 0)), (0.28, (4, 0, 0)), (hit, (-8, 0, 0)), (0.62, (-7, 0, -3)), (0.8, (-3, 0, 2)), (1.2, (0, 0, 0))])
        rot = {
            "Neck1": K([(0, (0, 0, 0)), (0.28, (12, 0, 0)), (hit, (-22, 0, 0)), (0.62, (-20, 0, 6)), (0.8, (-10, 0, -4)), (1.2, (0, 0, 0))]),
            "Neck2": K([(0, (0, 0, 0)), (0.28, (8, 0, 0)), (hit, (-10, 0, 0)), (0.62, (-8, 6, 6)), (0.8, (-4, -3, -4)), (1.2, (0, 0, 0))]),
            "Neck3": K([(0, (0, 0, 0)), (0.28, (4, 0, 0)), (hit, (-4, 0, 0)), (1.2, (0, 0, 0))]),
            "Head": K([(0, (0, 0, 0)), (0.28, (-8, 0, 0)), (hit, (6, 0, 0)), (0.62, (6, 16, 8)), (0.82, (2, -5, 0)), (1.2, (0, 0, 0))]),
            "Jaw": K([(0, 0), (0.18, -4), (0.40, -15), (0.47, -15), (hit, 0), (0.62, -2), (0.8, 0), (1.2, 0)]),
            "Arm.R": K([(0, 0), (0.28, -5), (hit, 25), (0.7, 18), (1.2, 0)]), "Arm.L": K([(0, 0), (0.28, -5), (hit, 25), (0.7, 18), (1.2, 0)]),
            "Forearm.R": K([(0, 0), (hit, 20), (0.8, 10), (1.2, 0)]), "Forearm.L": K([(0, 0), (hit, 20), (0.8, 10), (1.2, 0)]),
            "Sickle.R": K([(0, 0), (0.28, 10), (hit, 6), (1.2, 0)]), "Sickle.L": K([(0, 0), (0.28, 10), (hit, 6), (1.2, 0)]),
        }
        for k in rot:
            if not isinstance(rot[k], tuple): rot[k] = (rot[k], 0, 0)
        tl = K([(0, 0), (0.28, 1.5), (hit, -2.5), (0.7, -1.2), (1.2, 0)])
        for i, bn in enumerate(TAILS):
            rot[bn] = (tl * (1 - i / 10), 0, K([(0, 0), (0.62, 0), (0.75, 3), (0.95, -2), (1.2, 0)]) * (0.5 + i / 8))
        return {"hips": {"off": off, "rot": hr}, "rot": rot, "legs": {s: self.planted(s) for s in "RL"}}


class AttackHeavy(Clip):
    # crouch, held telegraph (sickle claws up), spring, two sickle rakes (hit at 72 %), kick off backward, land
    dur = 2.4
    def spec(self, t, **_):
        K = lambda keys: kt(keys, t)
        hit = 0.72 * self.dur
        off = K([(0, (0, 0, 0)), (0.5, (0, -0.18, -0.32)), (1.3, (0, -0.18, -0.34)), (1.5, (0, 0.22, 0.30)), (1.63, (0, 0.42, 0.46)),
                 (hit, (0, 0.48, 0.42)), (1.9, (0, 0.42, 0.34)), (2.06, (0, 0.12, -0.14)), (2.2, (0, 0.04, -0.16)), (2.4, (0, 0, 0))])
        hold = K([(0, 0), (0.5, 1), (1.3, 1), (1.4, 0), (2.4, 0)])
        trem = math.sin(2 * math.pi * 9 * t) * hold
        hr = K([(0, (0, 0, 0)), (0.5, (9, 0, 0)), (1.3, (9, 0, 0)), (1.5, (16, 0, 0)), (hit, (20, 0, 0)), (1.9, (14, 0, 0)),
                (2.06, (-4, 0, 0)), (2.2, (-2, 0, 0)), (2.4, (0, 0, 0))])
        hr = (hr[0] + 0.4 * trem, hr[1], hr[2])
        fly = K([(0, 0), (1.38, 0), (1.5, 1), (1.98, 1), (2.08, 0), (2.4, 0)])
        legs = {}
        # airborne foot targets in the hips' rest frame (relative to the hips head): tuck, rake, retract, rake
        rel = K([(1.3, (0, 0.10, -2.05)), (1.55, (0, 0.55, -1.55)), (hit, (0, 1.25, -1.62)), (1.82, (0, 0.60, -1.45)), (1.93, (0, 1.15, -1.60)), (2.08, (0, 0.20, -2.10))])
        th = K([(0, 0), (0.5, 8), (1.3, 8), (1.42, 40), (1.55, 45), (hit, -8), (1.82, 35), (1.93, -6), (2.06, -5), (2.2, 6), (2.4, 0)])
        sk = K([(0, 0), (0.5, 28), (1.3, 30), (1.55, 42), (hit - 0.05, 40), (hit, -18), (1.82, 35), (1.93, -15), (2.1, 5), (2.4, 0)])
        curl = K([(0, 0), (1.38, 0), (1.55, 30), (hit, 18), (1.93, 18), (2.06, 0), (2.4, 0)])
        for s in "RL":
            sgn = 1 if s == "R" else -1
            air = self.hips_point(off, hr, (self.ball0[s].x + 0.04 * sgn - self.hh.x, rel[1] + (0.06 if s == "R" else -0.06), rel[2]))
            ground = self.ball0[s]
            b = ground.lerp(air, fly)
            legs[s] = dict(ball=tuple(b), theta=th, toe=curl, sickle=sk + 0.8 * trem, toe_lat="body" if fly > 0.5 else "world")
        rot = {
            "Neck1": K([(0, 0), (0.5, -12), (1.3, -12), (1.55, -20), (hit, -24), (2.0, -14), (2.4, 0)]),
            "Neck2": K([(0, 0), (0.5, 4), (1.3, 4), (1.55, -4), (2.4, 0)]),
            "Head": K([(0, 0), (0.5, 4), (1.3, 4), (1.55, 2), (hit, -6), (2.0, 0), (2.4, 0)]),
            "Jaw": K([(0, 0), (0.5, -10), (1.3, -12), (1.55, -16), (hit, -16), (1.9, -8), (2.2, 0), (2.4, 0)]),
            "Arm.R": K([(0, 0), (0.5, 30), (1.3, 30), (1.55, 55), (hit, 50), (1.95, 40), (2.2, 8), (2.4, 0)]),
            "Arm.L": K([(0, 0), (0.5, 30), (1.3, 30), (1.55, 55), (hit, 50), (1.95, 40), (2.2, 8), (2.4, 0)]),
            "Forearm.R": K([(0, 0), (0.5, 35), (1.3, 35), (1.55, 30), (hit, 45), (1.95, 30), (2.4, 0)]),
            "Forearm.L": K([(0, 0), (0.5, 35), (1.3, 35), (1.55, 30), (hit, 45), (1.95, 30), (2.4, 0)]),
            "Hand.R": K([(0, 0), (0.5, -20), (1.55, -25), (hit, -35), (2.4, 0)]), "Hand.L": K([(0, 0), (0.5, -20), (1.55, -25), (hit, -35), (2.4, 0)]),
        }
        for k in rot:
            rot[k] = (rot[k] + (0.5 * trem if k.startswith("Neck") else 0), 0, 0)
        tl = K([(0, 0), (0.5, -2.5), (1.3, -2.5), (1.55, -4.5), (hit, -4), (2.0, 1), (2.2, -0.5), (2.4, 0)])
        for i, bn in enumerate(TAILS):
            rot[bn] = (tl * (1.0 - i / 12) + 0.4 * trem, 0, K([(0, 0), (1.5, 0), (1.7, 4), (1.95, -4), (2.2, 2), (2.4, 0)]) * (0.4 + i / 8))
        return {"hips": {"off": off, "rot": hr}, "rot": rot, "legs": legs}


class HitReact(Clip):
    dur = 0.6
    def spec(self, t, **_):
        K = lambda keys: kt(keys, t)
        off = K([(0, (0, 0, 0)), (0.08, (0.07, -0.12, -0.05)), (0.25, (0.02, -0.04, -0.02)), (0.6, (0, 0, 0))])
        hr = K([(0, (0, 0, 0)), (0.08, (4, 4, -6)), (0.25, (1, 1, -2)), (0.6, (0, 0, 0))])
        rot = {"Neck1": K([(0, (0, 0, 0)), (0.08, (12, 0, -8)), (0.28, (3, 0, -2)), (0.6, (0, 0, 0))]),
               "Neck2": K([(0, (0, 0, 0)), (0.1, (8, 0, -6)), (0.3, (2, 0, -1)), (0.6, (0, 0, 0))]),
               "Head": K([(0, (0, 0, 0)), (0.1, (10, 0, -10)), (0.32, (2, 0, -2)), (0.6, (0, 0, 0))]),
               "Jaw": (K([(0, 0), (0.07, -12), (0.3, -3), (0.6, 0)]), 0, 0),
               "Forearm.R": (K([(0, 0), (0.1, 16), (0.6, 0)]), 0, 0), "Forearm.L": (K([(0, 0), (0.1, 16), (0.6, 0)]), 0, 0),
               "Sickle.R": (K([(0, 0), (0.1, 12), (0.6, 0)]), 0, 0), "Sickle.L": (K([(0, 0), (0.1, 12), (0.6, 0)]), 0, 0)}
        for i, bn in enumerate(TAILS):
            d = 0.025 * i
            rot[bn] = (K([(0, 0), (0.08 + d, -1.2), (0.3 + d, 0.5), (0.6, 0)]), 0, K([(0, 0), (0.1 + d, 4), (0.3 + d, -1.5), (0.6, 0)]))
        return {"hips": {"off": off, "rot": hr}, "rot": rot, "legs": {s: self.planted(s) for s in "RL"}}


# Lying on the LEFT side (roll -90 about the long axis): body -X is world down, so +Z on the neck, tail and limbs
# lowers them to the ground. Legs fold in FK; the upper (right) leg drapes over the lower one.
LIE_LEGS = {"R": {"Thigh": (38, 0, 22), "Shin": (-62, 0, 4), "Metatarsal": (55, 0, 6), "Toe": (-35, 0, 0)},
            "L": {"Thigh": (24, 0, -4), "Shin": (-48, 0, -2), "Metatarsal": (42, 0, 0), "Toe": (-28, 0, 0)}}


class Knockdown(Clip):
    # struck on the right flank, skids left, drops onto its left side, lies stunned (held)
    dur, lie = 2.5, True
    t_down = 1.0
    def ground(self, t):
        return "snap" if t >= 0.92 else "lift"
    def spec(self, t, lz=0.0, **_):
        K = lambda keys: kt(keys, t)
        off = K([(0, (0, 0, 0)), (0.12, (-0.14, -0.04, -0.04)), (0.45, (-0.42, -0.08, -0.26)), (0.8, (-0.66, -0.12, lz + 0.18)),
                 (self.t_down, (-0.72, -0.12, lz)), (1.1, (-0.72, -0.12, lz + 0.04)), (1.22, (-0.72, -0.12, lz)), (2.5, (-0.72, -0.12, lz))])
        breath = math.sin(2 * math.pi * (t - 1.2) / 1.3) * ss(1.1, 1.5, t)
        hr = K([(0, (0, 0, 0)), (0.12, (0, -6, -8)), (0.45, (-3, -26, -12)), (0.8, (-4, -74, -12)), (self.t_down, (-3, -90, -12)),
                (1.1, (-3, -86, -12)), (1.22, (-3, -90, -12)), (2.5, (-3, -90, -12))])
        w = K([(0, 0), (0.3, 0), (0.8, 1), (2.5, 1)])
        skid = K([(0, (0, 0, 0)), (0.12, (-0.10, 0, 0)), (0.45, (-0.38, -0.04, 0)), (2.5, (-0.38, -0.04, 0))])
        legs = {}
        for s in "RL":
            th = K([(0, 0), (0.45, 12), (2.5, 12)])
            legs[s] = dict(ball=tuple(self.ball0[s] + Vector(skid) + Vector((0, 0, 0.5 * min(1.0, 2 * w)))), theta=th, toe=0, w=w, toe_lat=w * w,
                           fk={k: (v[0], v[1], v[2] + (0 if t < 1.3 else 0)) for k, v in LIE_LEGS[s].items()})
        lay = K([(0, 0), (0.5, 0), (self.t_down, 1), (2.5, 1)])
        lift = K([(0, 0), (1.5, 0), (1.75, 1), (2.05, 1), (2.3, 0), (2.5, 0)])  # stunned head lift
        rot = {"Neck1": (K([(0, 0), (0.12, 6), (0.5, 4), (2.5, 0)]), 0, K([(0, 0), (0.12, -14), (0.5, -6), (self.t_down, 8), (2.5, 8)]) - 6 * lift),
               "Neck2": (K([(0, 0), (0.12, 6), (2.5, 0)]), 0, K([(0, 0), (0.12, -10), (0.5, -4), (self.t_down, 7), (2.5, 7)]) - 5 * lift),
               "Neck3": (0, 0, 5 * lay - 3 * lift), "Head": (K([(0, 0), (0.12, 8), (0.6, 0), (2.5, 0)]), 0, 6 * lay - 4 * lift),
               "Jaw": (K([(0, 0), (0.12, -10), (0.6, -4), (self.t_down, -8), (2.5, -8)]), 0, 0),
               "Chest": (1.2 * breath, 0, 0), "Spine2": (0.8 * breath, 0, 0),
               "Arm.R": (K([(0, 0), (0.12, 15), (self.t_down, 20), (2.5, 20)]), 0, 28 * lay), "Arm.L": (K([(0, 0), (0.12, 15), (self.t_down, 10), (2.5, 10)]), 0, -12 * lay),
               "Forearm.R": (K([(0, 0), (0.2, 25), (2.5, 25)]), 0, 0), "Forearm.L": (K([(0, 0), (0.2, 25), (2.5, 25)]), 0, 0),
               "Sickle.R": (K([(0, 0), (0.3, 12), (2.5, 8)]), 0, 0), "Sickle.L": (K([(0, 0), (0.3, 12), (2.5, 8)]), 0, 0)}
        for i, bn in enumerate(TAILS):
            rot[bn] = (0, 0, K([(0, 0), (0.12, 4 + i * 0.5), (0.5, -2), (self.t_down, 1.2), (2.5, 1.2)]))
        return {"hips": {"off": off, "rot": hr}, "rot": rot, "legs": legs}


class Death(Clip):
    # legs buckle, falls onto its left side, head strikes the ground, one leg spasm, settles still
    dur, lie = 2.8, True
    t_down = 1.25
    def ground(self, t):
        return "snap" if t >= 1.18 else "lift"
    def spec(self, t, lz=0.0, **_):
        K = lambda keys: kt(keys, t)
        off = K([(0, (0, 0, 0)), (0.3, (0, -0.05, -0.25)), (0.62, (0, -0.10, -0.55)), (1.0, (-0.30, -0.15, lz + 0.16)),
                 (self.t_down, (-0.36, -0.15, lz)), (1.35, (-0.36, -0.15, lz + 0.03)), (1.5, (-0.36, -0.15, lz)), (2.8, (-0.36, -0.15, lz))])
        hr = K([(0, (0, 0, 0)), (0.3, (-6, -4, 0)), (0.62, (-10, -14, 3)), (1.0, (-6, -70, 6)), (self.t_down, (-4, -90, 6)),
                (1.4, (-4, -87, 6)), (1.6, (-4, -90, 6)), (2.8, (-4, -90, 6))])
        w = K([(0, 0), (0.55, 0), (1.05, 1), (2.8, 1)])
        spasm = K([(0, 0), (1.55, 0), (1.68, 1), (1.85, -0.4), (2.05, 0.3), (2.3, 0), (2.8, 0)])
        legs = {}
        for s in "RL":
            fk = dict(LIE_LEGS[s])
            if s == "R":
                fk = {k: (v[0] + {"Thigh": 18, "Shin": -20, "Metatarsal": 25, "Toe": 10}[k] * spasm, v[1], v[2]) for k, v in fk.items()}
            legs[s] = dict(ball=tuple(self.ball0[s] + Vector((0, 0, 0.5 * min(1.0, 2 * w)))), theta=K([(0, 0), (0.6, -10), (2.8, -10)]), toe=0, w=w, fk=fk, toe_lat=w * w)
        lay = K([(0, 0), (0.7, 0), (self.t_down, 1), (2.8, 1)])
        limp = K([(0, 0), (1.2, 0), (1.5, 1), (2.8, 1)])
        rot = {"Neck1": (K([(0, 0), (0.3, -10), (0.62, -18), (1.0, -8), (2.8, -4)]), 0, 8 * lay + 3 * limp),
               "Neck2": (K([(0, 0), (0.3, -6), (0.62, -8), (2.8, -2)]), 0, 7 * lay + 3 * limp),
               "Neck3": (K([(0, 0), (0.62, -4), (2.8, 0)]), 0, 5 * lay + 2 * limp),
               "Head": (K([(0, 0), (0.62, 6), (1.2, 10), (self.t_down, 2), (2.8, 0)]), 0, 6 * lay + 1 * limp),
               "Jaw": (K([(0, 0), (0.3, -6), (0.62, -12), (self.t_down, -9), (1.5, -12), (2.8, -12)]), 0, 0),
               "Arm.R": (K([(0, 0), (0.62, 20), (2.8, 26)]), 0, 30 * lay), "Arm.L": (K([(0, 0), (0.62, 20), (2.8, 14)]), 0, -12 * lay),
               "Forearm.R": (K([(0, 0), (0.62, 15), (2.8, 30)]), 0, 0), "Forearm.L": (K([(0, 0), (0.62, 15), (2.8, 30)]), 0, 0),
               "Hand.R": (K([(0, 0), (2.8, -20)]), 0, 0), "Hand.L": (K([(0, 0), (2.8, -20)]), 0, 0),
               "Sickle.R": (K([(0, 0), (0.6, 10), (2.8, 0)]), 0, 0), "Sickle.L": (K([(0, 0), (0.6, 10), (2.8, 0)]), 0, 0)}
        for i, bn in enumerate(TAILS):
            rot[bn] = (K([(0, 0), (0.62, 2), (2.8, 0)]), 0, K([(0, 0), (0.62, 0), (self.t_down, 1.6), (1.4, 1.0), (2.8, 1.3)]))
        return {"hips": {"off": off, "rot": hr}, "rot": rot, "legs": legs}


CLIPS = {"idle": Idle, "walk": Walk, "run": Run, "attack_primary": AttackPrimary, "attack_heavy": AttackHeavy,
         "hit_react": HitReact, "knockdown": Knockdown, "death": Death, "alert": Alert}
