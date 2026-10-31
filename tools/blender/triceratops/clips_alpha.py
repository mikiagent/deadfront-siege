# ALPHA triceratops clips (TRIKE_CLIPS=clips_alpha): the nine regular clips (clips.py, unchanged, solved on the Alpha's
# rig) plus the ones the regular trike lacks (walk_back, strafe_left/right, feed, sleep) and its signature pair:
#   charge: the run with the head dropped and the brow horns levelled (same stride as the run);
#   toss:   the bull-horn hook-and-throw played on a charge impact (TacticalBrain._charge_impact): head driven low,
#           then a hard twist to the animal's RIGHT and up that flings the target sideways off the brow horns.
# Same conventions as clips.py (local X lateral on every bone; +X pitch lifts a forward bone's tip; +Z swings it left).
import math
from mathutils import Vector
from qlib import ss
from clips import Clip, Gait, Walk, Run, Knockdown, LIE, TAILS, FEET, kt, tail_rot, CLIPS as BASE


class DirGait(Walk):
    """The walk's footfall timing, travelling along dirv (x, y) in the body frame (stance feet slide the other way)."""
    dirv = (0.0, 1.0)
    def leg(self, k, p):
        kind = self.rig.L[k]["kind"]
        b = self.beta[kind]; D = self.v * b * self.dur
        c = self.ball0[k]; dv = Vector((self.dirv[0], self.dirv[1], 0.0)) * (D / 2)
        front, back = c + dv, c - dv
        if p < b:
            u = p / b
            pos = front.lerp(back, u); h = self.heel * ss(0.70, 1.0, u)
            return dict(ball=(pos.x, pos.y, c.z + h), theta=self.th_to * ss(0.55, 1.0, u), toe=math.degrees(math.asin(min(0.9, h / self.TL))))
        u = (p - b) / (1 - b)
        e = (1 - math.cos(math.pi * u)) / 2
        ank0 = back + Vector((0, 0, self.heel)) + self.a_vec(k, self.th_to)
        ank1 = front + self.a_vec(k, 0.0)
        ank = ank0.lerp(ank1, e) + Vector((0, 0, self.lift[kind] * math.sin(math.pi * u)))
        th = self.th_to * (1 - e)
        return dict(ball=tuple(ank - self.a_vec(k, th)), theta=th, toe=0.0)


class WalkBack(DirGait):
    dirv = (0.0, -1.0)
    th_to, heel = 6.0, 0.02  # backing up: the foot lifts nearly flat


class StrafeLeft(DirGait):
    dirv = (-1.0, 0.0)  # the animal's left is -X
    v = 1.0; th_to, heel, yaw = 4.0, 0.02, 0.6
    lift = {"hind": 0.22, "front": 0.26}


class StrafeRight(StrafeLeft):
    dirv = (1.0, 0.0)


class Charge(Run):
    # the run, head down: neck and head pitched so the brow horns point ahead at chest height
    neck, head_bob, jaw = (-12.0, -6.0, -6.0), 1.0, -1.0
    tail_pitch = [-4.0, -2.0, -1.0, 0, 0, 0]


class Feed(Clip):
    # grazing: the forequarters sink, the head goes down to the ground, three bites with a sideways rip, back up
    dur = 3.0
    def spec(self, t, **_):
        K = lambda keys: kt(keys, t)
        down = K([(0, 0), (0.6, 1), (2.4, 1), (3.0, 0)])
        bite = sum(K([(0, 0), (t0, 0), (t0 + 0.15, 1), (t0 + 0.35, 0), (3.0, 0)]) for t0 in (0.8, 1.35, 1.9))
        rip = K([(0, 0), (0.95, 0), (1.15, 1), (1.5, -1), (2.05, 1), (2.3, 0), (3.0, 0)])
        rot = {"Spine2": (-1.0 * down, 0, 0), "Chest": (-3.0 * down, 0, 0),
               "Neck1": (-14 * down, 0, 3 * rip), "Neck2": (-12 * down, 0, 2 * rip), "Head": (-14 * down + 2 * bite, -2 * rip, 2 * rip),
               "Jaw": (-5 * bite, 0, 0)}
        tail_rot(rot, 1.0 * down, K([(0, 0), (1.0, 1.5), (2.0, -1.5), (3.0, 0)]))
        return {"hips": {"off": (0, 0.05 * down, -0.10 * down), "rot": (-3.0 * down, 0, 0)}, "rot": rot, "legs": self.all_planted()}


class Sleep(Knockdown):
    # lies down slowly onto its left side (the knockdown's resting pose) and sleeps: slow breathing, held
    dur, lie = 3.6, True
    t_down = 1.8
    def spec(self, t, lz=0.0, **_):
        K = lambda keys: kt(keys, t)
        off = K([(0, (0, 0, 0)), (0.9, (-0.20, 0, -0.45)), (1.5, (-0.80, 0, lz + 0.15)), (self.t_down, (-0.95, 0, lz)), (3.6, (-0.95, 0, lz))])
        hr = K([(0, (0, 0, 0)), (0.9, (-1, -12, 0)), (1.5, (-1, -70, -4)), (self.t_down, (-1, -88, -6)), (3.6, (-1, -88, -6))])
        w = K([(0, 0), (0.4, 0), (1.4, 1), (3.6, 1)])
        lay = K([(0, 0), (1.0, 0), (self.t_down, 1), (3.6, 1)])
        breath = math.sin(2 * math.pi * (t - 1.8) / 2.4) * ss(1.8, 2.4, t)
        legs = {}
        for k in FEET:
            legs[k] = dict(ball=tuple(self.ball0[k] + Vector((-0.30 * min(1, t / 1.0), 0, 0.6 * min(1.0, 2 * w)))), theta=0, toe=0, w=w,
                           toe_lat=w * w, fk=LIE[k])
        rot = {"Spine1": (0.6 * breath, 0, 0), "Spine2": (0.8 * breath, 0, 0), "Chest": (0.6 * breath, 0, 0),
               "Neck1": (-2 * lay, 0, 7 * lay), "Neck2": (-1 * lay, 0, 5 * lay), "Head": (-2 * lay + 0.5 * breath, 0, 5 * lay), "Jaw": (0, 0, 0)}
        for i, bn in enumerate(TAILS):
            rot[bn] = (0, 0, 2.2 * lay)
        return {"hips": {"off": off, "rot": hr}, "rot": rot, "legs": legs}


class Toss(Clip):
    # Bull-horn hook-and-throw (ASSUMPTION, the Alpha's signature): starts in the charge's head-low pose, drives the
    # brow horns lower and in (0-0.30), then twists the head and neck hard to its RIGHT and up (0.30-0.55, hit at 0.36 =
    # 30 %), the forequarters heave right, follow-through held, then back to neutral. Hit = the charge impact.
    dur = 1.2
    def spec(self, t, **_):
        K = lambda keys: kt(keys, t)
        hit = 0.36
        tw = K([(0, 0), (0.28, 0), (hit, 0.6), (0.55, 1), (0.8, 1), (1.2, 0)])     # the twist and throw
        dn = K([(0, 1), (0.28, 1.25), (hit, 0.8), (0.55, 0.2), (0.8, 0.1), (1.2, 0)])  # head low (charge pose)
        rot = {"Spine2": (-1.0 * dn, 0, -2 * tw), "Chest": (-2.0 * dn + 1.5 * tw, 0, -3 * tw),
               "Neck1": (-12 * dn + 8 * tw, 0, -10 * tw), "Neck2": (-6 * dn + 5 * tw, 0, -8 * tw),
               "Head": (-6 * dn + 10 * tw, -22 * tw, -10 * tw), "Jaw": (-4 * tw, 0, 0)}
        tail_rot(rot, -2.0 * dn, 3.0 * tw)
        legs = self.all_planted()
        # the left forefoot plants wider to brace the heave; the hind heels lift as it drives in
        legs["FL"] = self.planted("FL", K([(0, (0, 0, 0)), (0.2, (0, 0, 0)), (0.3, (-0.10, 0.10, 0.20)), (0.42, (-0.20, 0.20, 0)), (0.9, (-0.20, 0.20, 0)),
                                           (1.05, (-0.10, 0.10, 0.18)), (1.2, (0, 0, 0))]),
                                  theta=K([(0, 0), (0.25, 0), (0.3, 15), (0.42, 0), (1.2, 0)]))
        for k in ("HL", "HR"):
            legs[k]["theta"] = K([(0, 0), (0.15, 16), (hit, 20), (0.7, 6), (1.2, 0)])
        return {"hips": {"off": K([(0, (0, 0, -0.08)), (0.28, (0, 0.18, -0.12)), (hit, (0.06, 0.22, -0.08)), (0.6, (0.14, 0.12, -0.02)), (1.2, (0, 0, 0))]),
                         "rot": K([(0, (-2, 0, 0)), (0.28, (-3, 0, 0)), (hit, (0, -3, -6)), (0.6, (1, -4, -9)), (0.9, (0.5, -2, -5)), (1.2, (0, 0, 0))])},
                "rot": rot, "legs": legs}


CLIPS = dict(BASE)
CLIPS.update({"walk_back": WalkBack, "strafe_left": StrafeLeft, "strafe_right": StrafeRight, "charge": Charge, "feed": Feed,
              "sleep": Sleep, "toss": Toss})
