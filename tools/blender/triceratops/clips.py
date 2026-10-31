# The nine game clips as functions of time. Units: metres in the mesh frame (9.0 m beak to tail, 4.645 m tall, head +Y,
# right +X), so strides are in game units (the game scales this mesh by 1.0).
# The jaw opens at most 5 deg: the beak tips are fused in the mesh, so wider opens stretch a curtain between them.
# Rotation signs (local X is lateral on every bone): +X pitch lifts a forward-pointing bone's tip (spine, neck, head;
# jaw: + closes), swings a down-pointing limb's tip forward (UpperArm, Thigh); tail bones point back, so -X raises the
# tail. +Z swings a bone's tip toward the animal's left (-X). Hips rot (deg, world XYZ): x = pitch (+ nose up),
# y = roll (+ right side down), z = yaw (+ nose left).
# Gaits: lateral-sequence walk (LH, LF, RH, RF) and a fast amble for the run (heavy animal: no flight phase).
import math
from mathutils import Vector, Matrix
from qlib import track, ss, eul, LEGS

TAILS = [f"Tail{i}" for i in range(1, 7)]
FEET = list(LEGS)


class Clip:
    loop = False
    lie = False
    def __init__(self, rig):
        self.rig = rig
        self.ball0 = {k: Vector(rig.L[k]["ball0"]) for k in FEET}
        self.hh = rig.hips_head.copy()
    def ground(self, t):
        return "check"
    def planted(self, k, d=(0, 0, 0), theta=0.0, toe=0.0, **kw):
        return dict(ball=tuple(self.ball0[k] + Vector(d)), theta=theta, toe=toe, **kw)
    def all_planted(self):
        return {k: self.planted(k) for k in FEET}


def kt(keys, t):
    return track(keys, t)


def tail_rot(rot, pitch, yaw, i_scale=0.0):
    for i, bn in enumerate(TAILS):
        rot[bn] = (pitch * (1 - i * i_scale), 0, yaw * (0.5 + i / 6))


class Idle(Clip):
    dur, loop = 3.0, True
    def spec(self, t, **_):
        w = 2 * math.pi * t / self.dur; s = math.sin(w)
        rot = {"Spine1": (0.4 * s, 0, 0), "Spine2": (0.5 * math.sin(w - 0.3), 0, 0), "Chest": (0.4 * math.sin(w - 0.6), 0, 0),
               "Neck1": (0.8 * math.sin(2 * w), 0, 1.6 * s), "Neck2": (0.5 * math.sin(2 * w + 0.4), 0, 1.4 * math.sin(w - 0.4)),
               "Head": (1.0 * math.sin(2 * w + 0.8), 0, 1.6 * math.sin(w - 0.8)), "Jaw": (-1.2 * (1 - math.cos(2 * w)) / 2, 0, 0)}
        for i, b in enumerate(TAILS):
            rot[b] = (0.5 * math.sin(w - 0.4 * i), 0, 2.5 * math.sin(w - 0.35 * i))
        return {"hips": {"off": (0.01 * math.sin(w + 1.0), 0, 0.012 * s), "rot": (0.3 * s, 0, 0.3 * math.sin(w + 1.0))},
                "rot": rot, "legs": self.all_planted()}


class Gait(Clip):
    loop = True
    TL = 0.36  # toe length, ball to nail tip
    def a_vec(self, k, th):
        return Matrix.Rotation(-math.radians(th), 3, Vector((1, 0, 0))) @ self.rig.L[k]["a0"]
    def leg(self, k, p):
        kind = self.rig.L[k]["kind"]
        b = self.beta[kind]; D = self.v * b * self.dur
        y0 = self.ball0[k].y + self.ymid[kind]
        y_front, y_back = y0 + D / 2, y0 - D / 2
        x = self.ball0[k].x; z0 = self.ball0[k].z
        if p < b:
            u = p / b
            y = y_front + (y_back - y_front) * u
            th = self.th_to * ss(0.55, 1.0, u)                     # heel lifts late in stance (flat plant first)
            h = self.heel * ss(0.70, 1.0, u)                       # the ball rises, the nails stay on the ground
            return dict(ball=(x, y, z0 + h), theta=th, toe=math.degrees(math.asin(min(0.9, h / self.TL))))
        u = (p - b) / (1 - b)
        e = (1 - math.cos(math.pi * u)) / 2
        ank0 = Vector((x, y_back, z0 + self.heel)) + self.a_vec(k, self.th_to)
        ank1 = Vector((x, y_front, z0)) + self.a_vec(k, 0.0)
        ank = ank0.lerp(ank1, e) + Vector((0, 0, self.lift[kind] * math.sin(math.pi * u)))
        th = track([(0, self.th_to), (0.45, self.th_sw), (0.85, 4.0), (1, 0.0)], u)
        ball = ank - self.a_vec(k, th)
        toe = track([(0, math.degrees(math.asin(min(0.9, self.heel / self.TL)))), (0.3, self.curl), (0.8, 4.0), (1, 0)], u)
        return dict(ball=tuple(ball), theta=th, toe=toe)
    def spec(self, t, **_):
        p = (t / self.dur) % 1.0; w = 2 * math.pi * p
        legs = {k: self.leg(k, (p - ph) % 1.0) for k, ph in self.phase.items()}
        # body: two bobs per cycle (one per hind stance), sway and roll toward the hind foot on the ground
        hb = self.beta["hind"]
        mid = hb / 2
        bob = math.cos(2 * w - 4 * math.pi * mid)
        sway = math.cos(w - 2 * math.pi * (self.phase["HR"] + mid))  # +1 while the right hind foot carries the weight
        hz = self.drop + self.bob * bob
        rot = {"Spine1": (0.4 * bob, 0, -self.yaw * 0.3 * sway), "Spine2": (0.3 * bob, 0, -self.yaw * 0.3 * sway),
               "Chest": (self.chest + 0.4 * bob, 0, -self.yaw * 0.3 * sway),
               "Neck1": (self.neck[0] - self.head_bob * bob, 0, -0.3 * self.yaw * sway), "Neck2": (self.neck[1], 0, 0),
               "Head": (self.neck[2] + self.head_bob * bob, 0, 0.2 * self.yaw * sway), "Jaw": (self.jaw, 0, 0)}
        for i, bn in enumerate(TAILS):
            rot[bn] = (self.tail_pitch[i] + self.tail_bob * math.cos(2 * w - 4 * math.pi * mid - 0.5 * i), 0,
                       self.tail_sw * math.sin(w - 2 * math.pi * (self.phase["HR"] + mid) - 0.45 * i))
        return {"hips": {"off": (self.sway * sway, 0, hz), "rot": (self.pitch, -self.roll * sway, self.yaw * sway)},
                "rot": rot, "legs": legs}


class Walk(Gait):
    dur, v = 1.0, 1.6  # 1.2 s strides pulled the trailing thighs far enough back to open the belly crease 2x
    phase = {"HL": 0.0, "FL": 0.25, "HR": 0.5, "FR": 0.75}
    beta = {"hind": 0.65, "front": 0.60}
    ymid = {"hind": 0.0, "front": 0.0}
    th_to, th_sw, heel, curl = 28.0, 14.0, 0.06, 10.0
    lift = {"hind": 0.20, "front": 0.24}
    drop, bob, sway, roll, yaw, pitch, chest = -0.10, 0.025, 0.05, 1.6, 1.8, 0.0, 0.0
    neck, head_bob, jaw = (-1.0, 0.0, 0.0), 0.8, 0.0
    tail_pitch, tail_bob, tail_sw = [0, 0, 0, 0, 0, 0], 0.6, 3.0


class Run(Gait):
    dur, v = 0.6, 4.2
    phase = {"HL": 0.0, "FL": 0.2, "HR": 0.5, "FR": 0.7}
    beta = {"hind": 0.50, "front": 0.47}
    ymid = {"hind": 0.0, "front": 0.0}
    th_to, th_sw, heel, curl = 32.0, 22.0, 0.08, 16.0
    lift = {"hind": 0.30, "front": 0.36}
    drop, bob, sway, roll, yaw, pitch, chest = -0.16, 0.04, 0.035, 1.4, 1.4, -1.5, -0.5
    neck, head_bob, jaw = (-4.0, -1.0, -2.0), 1.4, 0.0
    tail_pitch, tail_bob, tail_sw = [-2.0, -1.0, 0, 0, 0, 0], 1.0, 2.0


class Alert(Clip):
    # head comes up (frill shown), the right forefoot paws the ground twice, a snort, then back
    dur = 2.0
    def spec(self, t, **_):
        K = lambda keys: kt(keys, t)
        up = K([(0, 0), (0.3, 1), (1.7, 1), (2.0, 0)])
        snort = K([(0, 0), (1.45, 0), (1.55, 1), (1.7, 0), (2.0, 0)])
        yaw = K([(0, 0), (0.4, 0), (0.8, 1), (1.2, -0.6), (1.6, 0), (2.0, 0)])
        rot = {"Spine1": (0.3 * up, 0, 0), "Spine2": (0.3 * up, 0, 0), "Chest": (0.4 * up, 0, 0),
               "Neck1": (7 * up, 0, 3 * yaw), "Neck2": (4 * up, 0, 2 * yaw), "Head": (4 * up - 3 * snort, 0, 3 * yaw),
               "Jaw": (-4 * snort, 0, 0)}
        for i, bn in enumerate(TAILS):
            rot[bn] = (-2.0 * up * (1 - i / 7), 0, 1.5 * math.sin(2 * math.pi * t / 2.0 - 0.4 * i))
        # paw: lift, reach forward, scrape back along the ground, lift, repeat
        paw = [(0, (0, 0, 0)), (0.35, (0, 0, 0)), (0.5, (0, 0.10, 0.30)), (0.62, (0, 0.30, 0.05)), (0.66, (0, 0.30, 0.0)),
               (0.85, (0, -0.15, 0.0)), (0.95, (0, -0.05, 0.25)), (1.08, (0, 0.28, 0.05)), (1.12, (0, 0.28, 0.0)),
               (1.30, (0, -0.15, 0.0)), (1.42, (0, 0.0, 0.18)), (1.55, (0, 0, 0)), (2.0, (0, 0, 0))]
        d = K(paw)
        th = K([(0, 0), (0.35, 0), (0.5, 20), (0.62, 5), (0.85, 12), (0.95, 22), (1.08, 5), (1.3, 12), (1.42, 15), (1.55, 0), (2.0, 0)])
        legs = self.all_planted()
        legs["FR"] = self.planted("FR", d, theta=th, toe=K([(0, 0), (0.45, 10), (0.62, 0), (0.95, 10), (1.08, 0), (1.42, 6), (1.55, 0), (2.0, 0)]))
        shift = K([(0, 0), (0.3, 1), (1.5, 1), (1.8, 0), (2.0, 0)])
        return {"hips": {"off": (-0.07 * shift, -0.04 * up, -0.05 * up), "rot": (0.0, -1.2 * shift, 0)}, "rot": rot, "legs": legs}


class AttackPrimary(Clip):
    # head toss: horns dip, then sweep up and to the right; hit at 42 % (anim_events attack_primary hit_frac)
    dur = 1.2
    def spec(self, t, **_):
        K = lambda keys: kt(keys, t)
        hit = 0.42 * self.dur
        off = K([(0, (0, 0, 0)), (0.32, (0, -0.10, -0.08)), (hit, (0, 0.24, -0.09)), (0.66, (0, 0.20, -0.07)), (0.9, (0, 0.07, -0.02)), (1.2, (0, 0, 0))])
        hr = K([(0, (0, 0, 0)), (0.32, (-2.5, 0, 0)), (hit, (0.3, 0, -3)), (0.66, (0.3, 0, -3)), (0.9, (0.1, 0, -1)), (1.2, (0, 0, 0))])
        rot = {"Spine2": K([(0, (0, 0, 0)), (0.32, (-1.5, 0, 0)), (hit, (0.3, 0, -1)), (1.2, (0, 0, 0))]),
               "Chest": K([(0, (0, 0, 0)), (0.32, (-2, 0, 0)), (hit, (0.4, 0, -1.5)), (1.2, (0, 0, 0))]),
               "Neck1": K([(0, (0, 0, 0)), (0.32, (-7, 0, 2)), (hit, (6, 0, -5)), (0.66, (5, 0, -4)), (0.9, (1, 0, -1)), (1.2, (0, 0, 0))]),
               "Neck2": K([(0, (0, 0, 0)), (0.32, (-5, 0, 1)), (hit, (4, 0, -4)), (0.66, (3, 0, -3)), (1.2, (0, 0, 0))]),
               "Head": K([(0, (0, 0, 0)), (0.32, (-8, 0, 0)), (hit, (7, -6, -4)), (0.66, (5, -5, -3)), (0.9, (1, -1, 0)), (1.2, (0, 0, 0))]),
               "Jaw": (K([(0, 0), (0.3, -1.5), (hit, -4), (0.7, -1.5), (1.2, 0)]), 0, 0)}
        tail_rot(rot, K([(0, 0), (0.32, 1.5), (hit, -2.5), (1.2, 0)]), K([(0, 0), (0.4, 0), (0.6, 3), (0.9, -1.5), (1.2, 0)]))
        legs = self.all_planted()
        for k in ("HR", "HL"):
            legs[k]["theta"] = K([(0, 0), (0.32, 0), (hit, 10), (0.7, 6), (1.0, 0), (1.2, 0)])
        return {"hips": {"off": off, "rot": hr}, "rot": rot, "legs": legs}


class AttackHeavy(Clip):
    # horns lowered, held telegraph (tremor), then a short charge: body lunges 0.75 m with a quick step of both
    # forefeet, horns hook up at 72 % (anim_events attack_heavy hit_frac), back off to the start
    dur = 2.4
    def spec(self, t, **_):
        K = lambda keys: kt(keys, t)
        hit = 0.72 * self.dur
        hold = K([(0, 0), (0.45, 1), (1.2, 1), (1.3, 0), (2.4, 0)])
        trem = math.sin(2 * math.pi * 8 * t) * hold
        off = K([(0, (0, 0, 0)), (0.45, (0, -0.22, -0.14)), (1.2, (0, -0.24, -0.15)), (1.38, (0, 0.10, -0.24)), (1.6, (0, 0.62, -0.26)),
                 (hit, (0, 0.78, -0.22)), (1.88, (0, 0.72, -0.16)), (2.1, (0, 0.30, -0.06)), (2.4, (0, 0, 0))])
        hr = K([(0, (0, 0, 0)), (0.45, (-3, 0, 0)), (1.2, (-3, 0, 0)), (1.5, (-4, 0, 0)), (hit, (1.5, 0, -2)), (1.9, (1, 0, -1)), (2.4, (0, 0, 0))])
        hr = (hr[0] + 0.3 * trem, hr[1], hr[2])
        rot = {"Spine2": (K([(0, -0.0), (0.45, -1.5), (1.2, -1.5), (1.5, -2), (hit, 1), (2.4, 0)]), 0, 0),
               "Chest": (K([(0, 0), (0.45, -2), (1.2, -2), (1.5, -2.5), (hit, 1.5), (2.4, 0)]), 0, 0),
               "Neck1": K([(0, (0, 0, 0)), (0.45, (-9, 0, 0)), (1.2, (-9, 0, 0)), (1.55, (-10, 0, 0)), (hit, (6, 0, -4)), (1.9, (4, 0, -3)), (2.4, (0, 0, 0))]),
               "Neck2": K([(0, (0, 0, 0)), (0.45, (-6, 0, 0)), (1.2, (-6, 0, 0)), (1.55, (-7, 0, 0)), (hit, (4, 0, -3)), (1.9, (3, 0, -2)), (2.4, (0, 0, 0))]),
               "Head": K([(0, (0, 0, 0)), (0.45, (-10, 0, 0)), (1.2, (-10, 0, 0)), (1.55, (-11, 0, 0)), (hit, (8, -5, -3)), (1.9, (5, -4, -2)), (2.4, (0, 0, 0))]),
               "Jaw": (K([(0, 0), (0.45, -2), (1.2, -2), (hit, -4.5), (2.0, -1.5), (2.4, 0)]), 0, 0)}
        for k in ("Neck1", "Neck2", "Head"):
            rot[k] = (rot[k][0] + 0.4 * trem, rot[k][1], rot[k][2])
        tail_rot(rot, K([(0, 0), (0.45, -3), (1.2, -3), (1.5, -4), (hit, 1), (2.4, 0)]) + 0.5 * trem,
                 K([(0, 0), (1.5, 0), (1.75, 3), (2.0, -2), (2.4, 0)]))
        legs = {}
        # forefeet: one quick step forward each during the charge, one step back during the recovery
        for k, t0, t1 in (("FL", 1.30, 2.02), ("FR", 1.40, 2.14)):
            d = K([(0, (0, 0, 0)), (t0, (0, 0, 0)), (t0 + 0.09, (0, 0.30, 0.30)), (t0 + 0.18, (0, 0.62, 0.0)),
                   (t1, (0, 0.62, 0.0)), (t1 + 0.09, (0, 0.32, 0.26)), (t1 + 0.18, (0, 0, 0)), (2.4, (0, 0, 0))])
            th = K([(0, 0), (t0, 0), (t0 + 0.06, 22), (t0 + 0.16, 4), (t0 + 0.18, 0), (t1, 0), (t1 + 0.06, 20), (t1 + 0.16, 4), (t1 + 0.18, 0), (2.4, 0)])
            legs[k] = self.planted(k, d, theta=th)
        # hind feet planted; heels lift as the body lunges past them (the push)
        for k in ("HL", "HR"):
            th = K([(0, 0), (1.25, 0), (1.55, 24), (hit, 30), (1.9, 26), (2.15, 8), (2.4, 0)])
            h = K([(0, 0), (1.3, 0), (1.55, 0.05), (hit, 0.07), (1.9, 0.06), (2.15, 0.01), (2.4, 0)])
            legs[k] = self.planted(k, (0, 0, h), theta=th, toe=math.degrees(math.asin(min(0.9, h / 0.36))))
        return {"hips": {"off": off, "rot": hr}, "rot": rot, "legs": legs}


class HitReact(Clip):
    dur = 0.6
    def spec(self, t, **_):
        K = lambda keys: kt(keys, t)
        off = K([(0, (0, 0, 0)), (0.09, (0.06, -0.12, -0.08)), (0.26, (0.02, -0.04, -0.03)), (0.6, (0, 0, 0))])
        hr = K([(0, (0, 0, 0)), (0.09, (0.8, 1.5, -3)), (0.26, (0.3, 0.5, -1)), (0.6, (0, 0, 0))])
        rot = {"Neck1": K([(0, (0, 0, 0)), (0.09, (5, 0, -4)), (0.3, (1.5, 0, -1)), (0.6, (0, 0, 0))]),
               "Neck2": K([(0, (0, 0, 0)), (0.11, (3, 0, -3)), (0.32, (1, 0, -1)), (0.6, (0, 0, 0))]),
               "Head": K([(0, (0, 0, 0)), (0.11, (5, 0, -4)), (0.34, (1, 0, -1)), (0.6, (0, 0, 0))]),
               "Jaw": (K([(0, 0), (0.08, -5), (0.3, -1.5), (0.6, 0)]), 0, 0)}
        for i, bn in enumerate(TAILS):
            d = 0.025 * i
            rot[bn] = (K([(0, 0), (0.08 + d, -1.5), (0.3 + d, 0.6), (0.6, 0)]), 0, K([(0, 0), (0.1 + d, 4), (0.3 + d, -1.5), (0.6, 0)]))
        return {"hips": {"off": off, "rot": hr}, "rot": rot, "legs": self.all_planted()}


# Lying on the LEFT side (hips roll -90 about the long axis): body -X is world down, so +Z on the neck, head and tail
# lowers them to the ground. Legs fold in FK (knees forward, elbows back, never past their hinge); the upper (right)
# legs rest on the lower ones.
LIE = {"HR": {"Thigh": (34, 0, 14), "Shin": (-58, 0, 0), "Metatarsal": (40, 0, 0), "Toe": (-20, 0, 0)},
       "HL": {"Thigh": (24, 0, -4), "Shin": (-46, 0, 0), "Metatarsal": (34, 0, 0), "Toe": (-16, 0, 0)},
       "FR": {"UpperArm": (-26, 0, 16), "Forearm": (52, 0, 0), "Hand": (-36, 0, 0), "Finger": (16, 0, 0)},
       "FL": {"UpperArm": (-16, 0, -4), "Forearm": (40, 0, 0), "Hand": (-28, 0, 0), "Finger": (12, 0, 0)}}


class Knockdown(Clip):
    # struck on the right flank: staggers left, the legs give, it collapses onto its left side and lies stunned (held)
    dur, lie = 2.5, True
    t_down = 1.1
    def ground(self, t):
        return "snap" if t >= self.t_down - 0.06 else "lift"
    def spec(self, t, lz=0.0, **_):
        K = lambda keys: kt(keys, t)
        off = K([(0, (0, 0, 0)), (0.14, (-0.12, -0.03, -0.05)), (0.5, (-0.40, -0.06, -0.45)), (0.85, (-0.85, -0.08, lz + 0.25)),
                 (self.t_down, (-0.95, -0.08, lz)), (1.2, (-0.95, -0.08, lz + 0.05)), (1.32, (-0.95, -0.08, lz)), (2.5, (-0.95, -0.08, lz))])
        hr = K([(0, (0, 0, 0)), (0.14, (0, -4, -4)), (0.5, (-2, -22, -6)), (0.85, (-2, -70, -8)), (self.t_down, (-1, -88, -8)),
                (1.2, (-1, -85, -8)), (1.32, (-1, -88, -8)), (2.5, (-1, -88, -8))])
        w = K([(0, 0), (0.25, 0), (0.85, 1), (2.5, 1)])
        breath = math.sin(2 * math.pi * (t - 1.3) / 1.4) * ss(1.2, 1.6, t)
        lay = K([(0, 0), (0.6, 0), (self.t_down, 1), (2.5, 1)])
        lift = K([(0, 0), (1.55, 0), (1.85, 1), (2.15, 1), (2.4, 0), (2.5, 0)])  # stunned head lift
        legs = {}
        for k in FEET:
            th = K([(0, 0), (0.5, 10), (2.5, 10)])
            legs[k] = dict(ball=tuple(self.ball0[k] + Vector((-0.30 * min(1, t / 0.5), 0, 0.6 * min(1.0, 2 * w)))), theta=th, toe=0, w=w,
                           toe_lat=w * w, fk=LIE[k])
        rot = {"Spine1": (0.6 * breath, 0, 0), "Spine2": (0.8 * breath, 0, 0), "Chest": (0.6 * breath, 0, 0),
               "Neck1": (K([(0, 0), (0.14, 4), (0.5, 2), (2.5, -2)]), 0, K([(0, 0), (0.14, -6), (0.5, -3), (self.t_down, 6), (2.5, 6)]) - 4 * lift),
               "Neck2": (K([(0, 0), (0.14, 3), (2.5, -1)]), 0, 5 * lay - 3 * lift),
               "Head": (K([(0, 0), (0.14, 5), (0.6, 0), (2.5, -2)]), 0, 5 * lay - 3 * lift),
               "Jaw": (K([(0, 0), (0.14, -5), (0.6, -2), (self.t_down, -4), (2.5, -4)]), 0, 0)}
        for i, bn in enumerate(TAILS):
            rot[bn] = (0, 0, K([(0, 0), (0.14, 3 + i * 0.4), (0.5, -1.5), (self.t_down, 2.0), (2.5, 2.0)]))
        return {"hips": {"off": off, "rot": hr}, "rot": rot, "legs": legs}


class Death(Clip):
    # forelegs buckle first (it kneels forward), the hindquarters sink, it rolls onto its left side, a last leg kick,
    # then still
    dur, lie = 2.8, True
    t_down = 1.35
    def ground(self, t):
        return "snap" if t >= self.t_down - 0.06 else "lift"
    def spec(self, t, lz=0.0, **_):
        K = lambda keys: kt(keys, t)
        off = K([(0, (0, 0, 0)), (0.35, (0, 0.05, -0.18)), (0.75, (0, 0.10, -0.55)), (1.1, (-0.55, 0.05, lz + 0.20)),
                 (self.t_down, (-0.75, 0.05, lz)), (1.45, (-0.75, 0.05, lz + 0.04)), (1.6, (-0.75, 0.05, lz)), (2.8, (-0.75, 0.05, lz))])
        hr = K([(0, (0, 0, 0)), (0.35, (-5, -2, 0)), (0.75, (-8, -10, 2)), (1.1, (-4, -64, 4)), (self.t_down, (-2, -88, 4)),
                (1.48, (-2, -85, 4)), (1.62, (-2, -88, 4)), (2.8, (-2, -88, 4))])
        wf = K([(0, 0), (0.2, 0), (0.75, 1), (2.8, 1)])     # forelegs fold first
        wh = K([(0, 0), (0.45, 0), (1.0, 1), (2.8, 1)])
        kick = K([(0, 0), (1.7, 0), (1.82, 1), (1.98, -0.3), (2.15, 0.2), (2.35, 0), (2.8, 0)])
        legs = {}
        for k in FEET:
            fk = dict(LIE[k]); w = wf if k[0] == "F" else wh
            if k == "HR":
                fk = {b: (v[0] + {"Thigh": 16, "Shin": -18, "Metatarsal": 14, "Toe": 6}[b] * kick, v[1], v[2]) for b, v in fk.items()}
            legs[k] = dict(ball=tuple(self.ball0[k] + Vector((0, 0, 0.6 * min(1.0, 2 * w)))), theta=K([(0, 0), (0.6, -6), (2.8, -6)]), toe=0,
                           w=w, fk=fk, toe_lat=w * w)
        lay = K([(0, 0), (0.8, 0), (self.t_down, 1), (2.8, 1)])
        limp = K([(0, 0), (1.3, 0), (1.7, 1), (2.8, 1)])
        rot = {"Neck1": (K([(0, 0), (0.35, -4), (0.75, -8), (1.1, -3), (2.8, -3)]), 0, 6 * lay + 2 * limp),
               "Neck2": (K([(0, 0), (0.35, -2), (0.75, -4), (2.8, -1)]), 0, 4 * lay + 2 * limp),
               "Head": (K([(0, 0), (0.75, -6), (1.2, 2), (2.8, -1)]), 0, 4 * lay + 1 * limp),
               "Jaw": (K([(0, 0), (0.35, -3), (0.75, -5), (self.t_down, -4), (1.6, -5), (2.8, -5)]), 0, 0)}
        for i, bn in enumerate(TAILS):
            rot[bn] = (K([(0, 0), (0.75, 2), (2.8, 0)]), 0, K([(0, 0), (0.75, 0), (self.t_down, 2.2), (1.5, 1.5), (2.8, 1.8)]))
        return {"hips": {"off": off, "rot": hr}, "rot": rot, "legs": legs}


CLIPS = {"idle": Idle, "walk": Walk, "run": Run, "attack_primary": AttackPrimary, "attack_heavy": AttackHeavy,
         "hit_react": HitReact, "knockdown": Knockdown, "death": Death, "alert": Alert}
