"""SP-SMILODON: the sabre cat's fighting and life clips, keyed from rest on the smilodon rig (smilodon_rig.py).

Every clip is a set of curves over u in [0, 1] (piecewise smoothstep through (u, value) points): the Body moves and
turns about a pivot between hips and shoulders, the neck, head, jaw and tail turn as small rotations from rest, and
each foot has a target (rest + offset, in the ground frame, or carried with the body while airborne). Legs are solved
onto their feet every frame with the same analytic two-bone IK as make_gait.py (knee/elbow kept on its rest side), then
a floor pass lifts the Body wherever skin would dip under the ground. Planted feet have zero offset, so they do not
slide. Exported skeleton-only like make_gait.py.

attack_primary  1.0 s  forepaw swipe: weight back onto the hind legs and left fore, the right paw rises claws out and
                rakes down and across; hit (anim_events hit_frac 0.42) on FrontFoot.R.
attack_heavy    1.8 s  the pounce windup and a sabre lunge: sinks into a flat crouch, rump wiggles, tail tip flicks,
                jaws gape, then springs forward driving the sabres down; hit 0.72 on Head (windup, the brain retimes it).
pounce          1.0 s  launch from the crouch, fly with the forelegs reaching (airborne 0.2-0.65), slam both paws down
                on the prey and stab at 0.7 (Head), settle into the pin crouch.
pin_stab        2.4 s  holding the prey under both forepaws: rears the head up with the jaws wide, drives the sabres down
                (hits 0.38 and 0.74 on Head), the hind legs braced, tail lashing.
alert           1.6 s  rises on the forelegs, head up, a wide-jawed roar with a head shake, tail lash.
stalk_idle      unused name; the stalk loop is make_gait.py's (smilodon.json).
sleep           2.5 s  not looped (the game holds the last frame): lies down on its belly, forepaws out, chin on paws.
feed            2.0 s  loop: head down to the carcass, jaw tearing and a yank back.
idle            3.0 s  loop: breathing, a slow look round, tail sway, ear-to-ear head tilt.
leap            0.75 s the chase bound (SMILORUN): coil, drive off, stretched flight 0.12-0.78, fronts then hinds land on
                their prints, gathered to run on.
hit_react       0.6 s  flinch back off the forepaws, head jerks away, jaw snarls.
long_leap       1.4 s  SMILOFEEL: the large leap attack from mid range: a deep coil, drive off at 0.2, a long flight with both
                forelegs thrown far forward, claws out, jaws wide, the hinds trailing; the fronts slam down at 0.7 and the
                sabres drive in at 0.74 (Head + forepaws), then it settles into the pin crouch (airborne 0.2-0.7).
maul_bite       2.6 s  SMILOFEEL: the maul on a pinned or downed survivor, timed as the shared maul_bite (hits 0.24, 0.5,
                0.74, jaws open at 0.86): the forepaws come down on her and hold, the sabres bite in at 0.24, then two
                head-shake worries peaking on 0.5 and 0.74, each with a forepaw raking back; the hind legs stay planted.

usage: Blender -b -P tools/gait/make_cat_moves.py -- <base.glb> <out_dir> [clip ...]
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, OUT = argv[:2]
FPS = 24
TAILS = ["Tail1", "Tail2", "Tail3", "Tail4", "Tail5"]
LEGS = {f"{e}{s}": (f"{n}UpLeg.{s}", f"{n}LowLeg.{s}", f"{n}Foot.{s}") for e, n in (("F", "Front"), ("H", "Back")) for s in ("L", "R")}


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def k(u, pts):
    """Piecewise smoothstep through (u, value) points; a bare number is a constant."""
    if not isinstance(pts, list):
        return pts
    if u <= pts[0][0]:
        return pts[0][1]
    for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
        if u <= u1:
            return v0 + (v1 - v0) * smooth((u - u0) / max(u1 - u0, 1e-6))
    return pts[-1][1]


def osc(u, u0, u1, cycles, amp, phase=0.0):
    """A shake that fades in and out between u0 and u1."""
    if not u0 < u < u1:
        return 0.0
    s = (u - u0) / (u1 - u0)
    return amp * math.sin(2 * math.pi * (cycles * s + phase)) * math.sin(math.pi * s)


# Units: metres of the mesh (0.568 tall), degrees. body: dy (+ back, - forward), dz (+ up), pitch (+ nose up),
# roll (+ left side down), yaw (+ turns left). feet: per leg FL/FR/HL/HR {dx, dy, dz, pitch (+ toe down), follow
# (0 planted on the ground frame, 1 carried with the body)}. neck/head: pitch (+ nose up), yaw (+ left), roll.
# jaw: degrees open. tail: lift (+ up), yaw (+ tip to the left), lash (cycles, amp).
CLIPS = {
    "attack_primary": dict(
        n=24,
        body=dict(dy=[(0, 0), (0.25, 0.02), (0.42, -0.05), (0.6, -0.03), (1, 0)],
                  dz=[(0, 0), (0.25, 0.01), (0.42, -0.02), (1, 0)],
                  pitch=[(0, 0), (0.25, 7), (0.42, -5), (0.65, -2), (1, 0)],
                  roll=[(0, 0), (0.25, 5), (0.42, -3), (1, 0)],
                  yaw=[(0, 0), (0.25, -6), (0.42, 10), (1, 0)]),
        feet=dict(FR=dict(dy=[(0, 0), (0.12, 0.0), (0.27, -0.06), (0.42, -0.17), (0.55, -0.12), (0.72, -0.04), (1, 0)],
                          dz=[(0, 0), (0.12, 0.05), (0.27, 0.24), (0.42, 0.09), (0.55, 0.03), (0.72, 0.0), (1, 0)],
                          dx=[(0, 0), (0.27, -0.05), (0.42, 0.05), (0.6, 0.02), (1, 0)],
                          pitch=[(0, 0), (0.15, 30), (0.27, -40), (0.42, -10), (0.6, 0), (1, 0)],
                          follow=[(0, 0), (0.12, 0.6), (0.6, 0.6), (0.8, 0)])),
        neck=dict(pitch=[(0, 0), (0.25, 6), (0.42, -10), (1, 0)], yaw=[(0, 0), (0.25, 8), (0.42, -6), (1, 0)]),
        head=dict(roll=[(0, 0), (0.25, -10), (0.45, 6), (1, 0)]),
        jaw=[(0, 3), (0.2, 22), (0.45, 26), (0.7, 8), (1, 3)],
        tail=dict(lift=[(0, 0), (0.3, 10), (1, 0)], yaw=[(0, 0), (0.25, 12), (0.45, -16), (1, 0)])),
    "attack_heavy": dict(
        n=43,
        body=dict(dy=[(0, 0), (0.2, 0.03), (0.62, 0.035), (0.72, -0.12), (0.82, -0.12), (1, 0)],
                  dz=[(0, 0), (0.2, -0.13), (0.62, -0.14), (0.7, -0.03), (0.76, -0.04), (0.86, -0.05), (1, 0)],
                  pitch=[(0, 0), (0.2, -4), (0.62, -5), (0.68, 5), (0.72, -14), (0.86, -10), (1, 0)],
                  roll=lambda u: osc(u, 0.25, 0.62, 3, 4)),
        hips=dict(yaw=lambda u: osc(u, 0.25, 0.62, 3, 7), dz=[(0, 0), (0.2, 0.02), (0.5, 0.04), (0.62, 0.02), (0.72, 0), (1, 0)]),
        feet=dict(FL=dict(dy=[(0, 0), (0.64, 0), (0.72, -0.11), (1, 0)], dz=[(0, 0), (0.64, 0), (0.68, 0.06), (0.72, 0), (1, 0)],
                          pitch=[(0, 0), (0.62, 0), (0.66, -20), (0.72, 0)], follow=[(0, 0), (0.64, 0), (0.66, 0.4), (0.72, 0)]),
                  FR=dict(dy=[(0, 0), (0.66, 0), (0.74, -0.13), (1, 0)], dz=[(0, 0), (0.66, 0), (0.7, 0.07), (0.74, 0), (1, 0)],
                          pitch=[(0, 0), (0.64, 0), (0.68, -20), (0.74, 0)], follow=[(0, 0), (0.66, 0), (0.68, 0.4), (0.74, 0)]),
                  HL=dict(dy=[(0, 0), (0.72, 0), (0.86, -0.06), (1, 0)], dz=[(0, 0), (0.72, 0), (0.79, 0.04), (0.86, 0), (1, 0)]),
                  HR=dict(dy=[(0, 0), (0.74, 0), (0.88, -0.06), (1, 0)], dz=[(0, 0), (0.74, 0), (0.81, 0.04), (0.88, 0), (1, 0)])),
        neck=dict(pitch=[(0, 0), (0.2, -6), (0.6, -4), (0.66, 18), (0.72, -42), (0.82, -32), (1, 0)]),
        head=dict(pitch=[(0, 0), (0.2, 8), (0.6, 6), (0.66, 14), (0.72, -30), (0.82, -22), (1, 0)]),
        jaw=[(0, 3), (0.5, 8), (0.62, 48), (0.7, 48), (0.73, 20), (0.85, 30), (1, 3)],
        tail=dict(lift=[(0, 0), (0.2, 6), (0.62, 8), (0.72, 16), (1, 0)], lash=(0.2, 0.62, 5, 9))),
    "pounce": dict(
        n=24, airborne=(0.2, 0.65),
        body=dict(dy=[(0, 0.03), (0.2, 0.0), (0.42, -0.02), (0.65, -0.06), (0.7, -0.08), (1, -0.04)],
                  dz=[(0, -0.10), (0.18, -0.11), (0.3, 0.05), (0.45, 0.10), (0.62, 0.02), (0.7, -0.06), (1, -0.07)],
                  pitch=[(0, -4), (0.18, -2), (0.3, 16), (0.48, 2), (0.62, -14), (0.72, -12), (1, -8)]),
        feet=dict(FL=dict(dy=[(0, 0), (0.22, 0), (0.45, -0.20), (0.65, -0.16), (0.7, -0.16), (1, -0.16)],
                          dz=[(0, 0), (0.22, 0), (0.4, 0.10), (0.6, 0.04), (0.66, 0), (1, 0)],
                          pitch=[(0, 0), (0.25, 20), (0.42, -30), (0.62, -10), (0.66, 0)],
                          follow=[(0, 0), (0.2, 0), (0.3, 0.7), (0.58, 0.7), (0.66, 0)]),
                  FR=dict(dy=[(0, 0), (0.22, 0), (0.45, -0.22), (0.65, -0.18), (0.7, -0.18), (1, -0.18)],
                          dz=[(0, 0), (0.22, 0), (0.4, 0.12), (0.6, 0.05), (0.66, 0), (1, 0)],
                          pitch=[(0, 0), (0.25, 20), (0.42, -30), (0.62, -10), (0.66, 0)],
                          follow=[(0, 0), (0.2, 0), (0.3, 0.7), (0.58, 0.7), (0.66, 0)]),
                  HL=dict(dy=[(0, 0), (0.2, 0), (0.35, 0.10), (0.55, -0.04), (0.68, -0.06), (1, -0.06)],
                          dz=[(0, 0), (0.22, 0), (0.4, 0.06), (0.6, 0.06), (0.68, 0), (1, 0)],
                          pitch=[(0, 0), (0.2, 30), (0.4, 50), (0.6, 10), (0.68, 0)],
                          follow=[(0, 0), (0.22, 0), (0.32, 0.8), (0.6, 0.8), (0.68, 0)]),
                  HR=dict(dy=[(0, 0), (0.2, 0), (0.35, 0.12), (0.55, -0.03), (0.7, -0.05), (1, -0.05)],
                          dz=[(0, 0), (0.22, 0), (0.4, 0.06), (0.6, 0.06), (0.7, 0), (1, 0)],
                          pitch=[(0, 0), (0.2, 30), (0.4, 50), (0.6, 10), (0.7, 0)],
                          follow=[(0, 0), (0.22, 0), (0.32, 0.8), (0.6, 0.8), (0.7, 0)])),
        neck=dict(pitch=[(0, 4), (0.3, 10), (0.55, 4), (0.66, 14), (0.7, -26), (0.8, -20), (1, -12)]),
        head=dict(pitch=[(0, 4), (0.3, 4), (0.62, 10), (0.7, -22), (1, -10)]),
        jaw=[(0, 20), (0.3, 40), (0.6, 48), (0.69, 48), (0.73, 22), (0.85, 30), (1, 18)],
        tail=dict(lift=[(0, 0), (0.25, 18), (0.5, 8), (0.7, -6), (1, 4)], lash=(0.7, 1.0, 1.5, 10))),
    # SMILORUN: the chase bound (ASSUMPTION shape). Out of the run: fronts lift as the hinds coil, the hinds drive off at 0.12,
    # a stretched flight (forelegs reaching, hinds trailing then folding forward), the fronts land on their rest prints at
    # 0.78 as the body stops, the hinds swing in under the chest (gathered) at 0.88, ready to run on. The game moves the
    # body only inside airborne (0.12-0.78), so every planted foot sits on its rest print outside it.
    "leap": dict(
        n=18, airborne=(0.12, 0.78),
        body=dict(dy=[(0, 0), (0.12, 0.02), (0.45, -0.02), (0.78, 0.0), (1, 0)],
                  dz=[(0, -0.04), (0.12, -0.06), (0.3, 0.06), (0.5, 0.09), (0.7, 0.03), (0.8, -0.05), (0.9, -0.04), (1, 0)],
                  pitch=[(0, -2), (0.12, 3), (0.25, 6), (0.5, 0), (0.72, -8), (0.82, -8), (0.92, 2), (1, 0)]),
        feet=dict(FL=dict(dy=[(0, 0), (0.06, 0), (0.4, -0.20), (0.7, -0.08), (0.78, 0)], dz=[(0, 0), (0.06, 0), (0.25, 0.10), (0.6, 0.06), (0.78, 0)],
                          pitch=[(0, 0), (0.06, 30), (0.3, 40), (0.5, -25), (0.72, -10), (0.78, 0)],
                          follow=[(0, 0), (0.06, 0), (0.14, 1.0), (0.7, 1.0), (0.78, 0)]),
                  FR=dict(dy=[(0, 0), (0.08, 0), (0.42, -0.22), (0.7, -0.08), (0.78, 0)], dz=[(0, 0), (0.08, 0), (0.27, 0.11), (0.6, 0.06), (0.78, 0)],
                          pitch=[(0, 0), (0.08, 30), (0.32, 40), (0.52, -25), (0.72, -10), (0.78, 0)],
                          follow=[(0, 0), (0.08, 0), (0.16, 1.0), (0.7, 1.0), (0.78, 0)]),
                  HL=dict(dy=[(0, 0), (0.12, 0), (0.35, 0.14), (0.65, 0.04), (0.8, -0.04), (0.88, 0)], dz=[(0, 0), (0.12, 0), (0.35, 0.12), (0.7, 0.12), (0.8, 0.05), (0.88, 0)],
                          pitch=[(0, 0), (0.1, 25), (0.3, 15), (0.6, 0), (0.8, 5), (0.88, 0)],
                          follow=[(0, 0), (0.12, 0), (0.2, 1.0), (0.72, 1.0), (0.8, 0.4), (0.88, 0)]),
                  HR=dict(dy=[(0, 0), (0.12, 0), (0.37, 0.16), (0.66, 0.05), (0.82, -0.03), (0.9, 0)], dz=[(0, 0), (0.12, 0), (0.37, 0.12), (0.7, 0.12), (0.82, 0.05), (0.9, 0)],
                          pitch=[(0, 0), (0.1, 25), (0.3, 15), (0.6, 0), (0.82, 5), (0.9, 0)],
                          follow=[(0, 0), (0.12, 0), (0.2, 0.8), (0.72, 0.8), (0.82, 0.3), (0.9, 0)])),
        neck=dict(pitch=[(0, 0), (0.25, -8), (0.5, 0), (0.72, 10), (0.85, 6), (1, 0)]),
        head=dict(pitch=[(0, 0), (0.25, -4), (0.72, 6), (1, 0)]),
        jaw=[(0, 6), (0.3, 14), (0.8, 10), (1, 6)],
        tail=dict(lift=[(0, 4), (0.25, 2), (0.55, 8), (0.8, 14), (1, 6)])),
    # SMILOFEEL (ASSUMPTION shape): the large leap attack. Coiled deep, it drives off at 0.2 into a long flight with both
    # forelegs thrown far forward, claws out (toes up), the jaws wide and the hinds trailing; the fronts slam down ahead of
    # their prints at 0.7, the head drives the sabres down on 0.74, the hinds land on their rest prints (the maul's), crouched.
    "long_leap": dict(
        n=34, airborne=(0.2, 0.7),
        body=dict(dy=[(0, 0), (0.16, 0.04), (0.22, 0.0), (0.45, -0.03), (0.7, -0.07), (0.78, -0.08), (1, -0.04)],
                  dz=[(0, 0), (0.16, -0.13), (0.22, -0.10), (0.32, 0.07), (0.48, 0.12), (0.64, 0.04), (0.72, -0.07), (0.8, -0.08), (1, -0.07)],
                  pitch=[(0, 0), (0.16, -5), (0.22, 4), (0.32, 18), (0.5, 4), (0.64, -12), (0.74, -16), (0.85, -11), (1, -8)]),
        hips=dict(dz=[(0, 0), (0.08, 0.02), (0.16, 0.04), (0.22, 0.0), (1, 0)]),
        feet=dict(FL=dict(dy=[(0, 0), (0.2, 0), (0.42, -0.27), (0.62, -0.22), (0.7, -0.16), (1, -0.16)],
                          dz=[(0, 0), (0.2, 0), (0.36, 0.14), (0.58, 0.07), (0.68, 0), (1, 0)],
                          pitch=[(0, 0), (0.22, 25), (0.4, -45), (0.6, -25), (0.68, 0)],
                          follow=[(0, 0), (0.2, 0), (0.28, 0.85), (0.6, 0.85), (0.68, 0)]),
                  FR=dict(dy=[(0, 0), (0.2, 0), (0.44, -0.29), (0.62, -0.24), (0.7, -0.18), (1, -0.18)],
                          dz=[(0, 0), (0.2, 0), (0.38, 0.15), (0.58, 0.08), (0.69, 0), (1, 0)],
                          pitch=[(0, 0), (0.22, 25), (0.42, -45), (0.6, -25), (0.69, 0)],
                          follow=[(0, 0), (0.2, 0), (0.28, 0.85), (0.6, 0.85), (0.69, 0)]),
                  HL=dict(dy=[(0, 0), (0.22, 0), (0.38, 0.16), (0.6, 0.02), (0.74, 0), (1, 0)],
                          dz=[(0, 0), (0.22, 0), (0.4, 0.08), (0.62, 0.08), (0.74, 0), (1, 0)],
                          pitch=[(0, 0), (0.2, 35), (0.4, 55), (0.62, 10), (0.74, 0)],
                          follow=[(0, 0), (0.22, 0), (0.3, 0.85), (0.64, 0.85), (0.74, 0)]),
                  HR=dict(dy=[(0, 0), (0.22, 0), (0.4, 0.18), (0.6, 0.03), (0.76, 0), (1, 0)],
                          dz=[(0, 0), (0.22, 0), (0.4, 0.08), (0.62, 0.08), (0.76, 0), (1, 0)],
                          pitch=[(0, 0), (0.2, 35), (0.4, 55), (0.62, 10), (0.76, 0)],
                          follow=[(0, 0), (0.22, 0), (0.3, 0.85), (0.64, 0.85), (0.76, 0)])),
        neck=dict(pitch=[(0, 0), (0.16, -6), (0.32, 12), (0.6, 10), (0.7, 16), (0.74, -30), (0.84, -22), (1, -12)]),
        head=dict(pitch=[(0, 0), (0.16, 4), (0.4, 6), (0.68, 12), (0.74, -24), (1, -10)]),
        jaw=[(0, 6), (0.16, 22), (0.3, 46), (0.7, 48), (0.75, 22), (0.88, 26), (1, 15)],
        tail=dict(lift=[(0, 2), (0.16, -4), (0.3, 20), (0.55, 14), (0.72, -4), (1, 8)], lash=(0.72, 1.0, 1.5, 10))),
    # SMILOFEEL (ASSUMPTION shape): the maul, on the shared maul_bite timing. Out of the hold (or a stand) both forepaws come
    # forward and down on her (planted, holding), the head rears with the jaws wide and the sabres bite in at 0.24; then two
    # worries, the head wrenching side to side with the jaws clamped, peaking on 0.5 and 0.74, each with one forepaw raking
    # back across her and planting again; the jaws open at 0.86 and the head lifts. The hind legs never leave their prints.
    "maul_bite": dict(
        n=62,
        body=dict(dy=[(0, -0.02), (0.18, 0.01), (0.24, -0.05), (0.42, -0.03), (0.5, 0.0), (0.58, -0.04), (0.66, -0.03), (0.74, 0.0), (0.86, -0.03), (1, -0.02)],
                  dz=[(0, -0.04), (0.18, -0.02), (0.24, -0.09), (0.5, -0.07), (0.74, -0.07), (0.9, -0.05), (1, -0.04)],
                  pitch=[(0, -6), (0.18, 4), (0.24, -16), (0.4, -12), (0.5, -9), (0.62, -13), (0.74, -9), (0.88, -8), (1, -6)],
                  roll=lambda u: osc(u, 0.3, 0.86, 2, 4)),
        feet=dict(FL=dict(dy=[(0, 0), (0.06, 0), (0.18, -0.12), (0.23, -0.17), (0.6, -0.17), (0.66, -0.12), (0.72, -0.08), (0.78, -0.16), (1, -0.16)],
                          dz=[(0, 0), (0.06, 0), (0.13, 0.09), (0.2, 0.03), (0.23, 0), (0.6, 0), (0.66, 0.06), (0.72, 0.02), (0.76, 0), (1, 0)],
                          pitch=[(0, 0), (0.08, 20), (0.16, -30), (0.23, 0), (0.6, 0), (0.66, -25), (0.72, 20), (0.76, 0)],
                          follow=[(0, 0), (0.06, 0), (0.1, 0.5), (0.2, 0.5), (0.23, 0), (0.6, 0), (0.64, 0.4), (0.72, 0.4), (0.76, 0)]),
                  FR=dict(dy=[(0, 0), (0.08, 0), (0.2, -0.14), (0.24, -0.19), (0.36, -0.19), (0.42, -0.13), (0.48, -0.09), (0.54, -0.18), (1, -0.18)],
                          dz=[(0, 0), (0.08, 0), (0.15, 0.10), (0.21, 0.03), (0.24, 0), (0.36, 0), (0.42, 0.06), (0.48, 0.02), (0.52, 0), (1, 0)],
                          pitch=[(0, 0), (0.1, 20), (0.18, -30), (0.24, 0), (0.36, 0), (0.42, -25), (0.48, 20), (0.52, 0)],
                          follow=[(0, 0), (0.08, 0), (0.12, 0.5), (0.21, 0.5), (0.24, 0), (0.36, 0), (0.4, 0.4), (0.48, 0.4), (0.52, 0)]),
                  HL=dict(dy=0.0), HR=dict(dy=0.0)),  # on their prints: the maul starts from a stand or the long leap's landing
        neck=dict(pitch=[(0, -10), (0.16, 22), (0.2, 24), (0.24, -40), (0.4, -34), (0.86, -34), (0.94, -10), (1, -10)],
                  yaw=lambda u: osc(u, 0.34, 0.6, 1.0, 16) + osc(u, 0.6, 0.84, 1.0, -16)),
        head=dict(pitch=[(0, -8), (0.16, 16), (0.2, 18), (0.24, -30), (0.86, -28), (0.94, -8), (1, -8)],
                  roll=lambda u: osc(u, 0.34, 0.6, 2, 18) + osc(u, 0.6, 0.84, 2, 18)),
        jaw=[(0, 12), (0.14, 46), (0.21, 48), (0.25, 20), (0.84, 18), (0.88, 40), (0.94, 30), (1, 12)],
        tail=dict(lift=[(0, 6), (0.24, 12), (1, 6)], lash=(0.0, 1.0, 3, 16))),
    "pin_stab": dict(
        n=58,
        body=dict(dy=[(0, -0.04), (1, -0.04)], dz=[(0, -0.07), (0.3, -0.06), (0.38, -0.09), (0.6, -0.06), (0.74, -0.09), (1, -0.07)],
                  pitch=[(0, -8), (0.25, -2), (0.38, -14), (0.55, -4), (0.74, -15), (1, -8)],
                  roll=[(0, 0), (0.38, 3), (0.74, -3), (1, 0)]),
        feet=dict(FL=dict(dy=-0.16), FR=dict(dy=-0.18), HL=dict(dy=-0.06), HR=dict(dy=-0.05)),
        neck=dict(pitch=[(0, -12), (0.22, 24), (0.3, 26), (0.38, -36), (0.5, -26), (0.6, 24), (0.66, 26), (0.74, -38), (0.88, -24), (1, -12)],
                  yaw=[(0, 0), (0.22, 6), (0.38, -4), (0.6, -6), (0.74, 4), (1, 0)]),
        head=dict(pitch=[(0, -10), (0.22, 18), (0.3, 20), (0.38, -30), (0.5, -20), (0.6, 18), (0.66, 20), (0.74, -32), (1, -10)],
                  roll=lambda u: osc(u, 0.4, 0.58, 2, 8) + osc(u, 0.76, 0.96, 2, 8)),
        jaw=[(0, 15), (0.22, 48), (0.33, 48), (0.38, 26), (0.5, 20), (0.6, 48), (0.7, 48), (0.74, 24), (0.9, 20), (1, 15)],
        tail=dict(lift=[(0, 8), (1, 8)], lash=(0.0, 1.0, 3, 14))),
    "alert": dict(
        n=38,
        body=dict(dy=[(0, 0), (0.2, 0.025), (0.8, 0.025), (1, 0)], dz=[(0, 0), (0.2, 0.02), (0.8, 0.02), (1, 0)],
                  pitch=[(0, 0), (0.2, 8), (0.8, 8), (1, 0)]),
        neck=dict(pitch=[(0, 0), (0.2, 22), (0.75, 22), (1, 0)], yaw=lambda u: osc(u, 0.3, 0.75, 2, 7)),
        head=dict(pitch=[(0, 0), (0.2, 6), (0.32, 16), (0.75, 16), (1, 0)], roll=lambda u: osc(u, 0.3, 0.75, 3, 9)),
        jaw=[(0, 3), (0.22, 10), (0.32, 48), (0.7, 48), (0.82, 10), (1, 3)],
        tail=dict(lift=[(0, 0), (0.2, 16), (0.8, 16), (1, 0)], lash=(0.2, 0.85, 3, 14))),
    "sleep": dict(
        n=60,
        body=dict(dz=[(0, 0), (0.15, -0.03), (0.6, -0.205), (1, -0.205)], dy=[(0, 0), (0.6, 0.02), (1, 0.02)],
                  pitch=[(0, 0), (0.4, -6), (0.6, 0), (1, 0)], roll=[(0, 0), (0.6, 0), (0.85, 6), (1, 6)]),
        feet=dict(FL=dict(dy=[(0, 0), (0.3, 0), (0.6, -0.10), (1, -0.10)], dx=[(0, 0), (0.6, 0.01), (1, 0.01)],
                          dz=[(0, 0), (0.25, 0), (0.42, 0.02), (0.6, -0.035), (1, -0.035)], pitch=[(0, 0), (0.6, -30), (1, -30)]),
                  FR=dict(dy=[(0, 0), (0.35, 0), (0.62, -0.09), (1, -0.09)], dx=[(0, 0), (0.6, -0.01), (1, -0.01)],
                          dz=[(0, 0), (0.3, 0), (0.46, 0.02), (0.62, -0.035), (1, -0.035)], pitch=[(0, 0), (0.62, -30), (1, -30)]),
                  HL=dict(dy=[(0, 0), (0.5, 0), (0.8, -0.02), (1, -0.02)], dx=[(0, 0), (0.5, 0), (0.8, 0.04), (1, 0.04)],
                          dz=[(0, 0), (0.5, 0), (0.8, -0.095), (1, -0.095)], pitch=[(0, 0), (0.8, -50), (1, -50)]),
                  HR=dict(dy=[(0, 0), (0.5, 0), (0.8, -0.01), (1, -0.01)], dx=[(0, 0), (0.5, 0), (0.8, -0.035), (1, -0.035)],
                          dz=[(0, 0), (0.5, 0), (0.8, -0.095), (1, -0.095)], pitch=[(0, 0), (0.8, -50), (1, -50)])),
        neck=dict(pitch=[(0, 0), (0.5, -6), (0.8, -22), (1, -22)], yaw=[(0, 0), (0.6, 0), (0.9, 14), (1, 14)]),
        head=dict(pitch=[(0, 0), (0.8, -6), (1, -6)], roll=[(0, 0), (0.9, -8), (1, -8)]),
        jaw=[(0, 3), (0.3, 12), (0.45, 3), (1, 2)],
        tail=dict(lift=[(0, 0), (0.6, 12), (1, 12)], yaw=[(0, 0), (0.6, 0), (1, 40)])),  # the body sinks 0.2: the tail root lifts so the tail lies on the ground, curled
    "feed": dict(
        n=48, loop=True,
        body=dict(dz=[(0, -0.03), (1, -0.03)], pitch=[(0, -6), (0.5, -4), (0.62, -8), (1, -6)], dy=[(0, -0.01), (0.55, 0.02), (0.7, -0.01), (1, -0.01)]),
        neck=dict(pitch=[(0, -42), (0.45, -44), (0.58, -30), (0.72, -44), (1, -42)], yaw=[(0, 0), (0.55, 8), (0.7, -4), (1, 0)]),
        head=dict(pitch=[(0, -18), (0.5, -20), (0.6, -6), (0.75, -20), (1, -18)], roll=lambda u: osc(u, 0.5, 0.75, 2, 10)),
        jaw=lambda u: 14 + 14 * math.sin(2 * math.pi * 3 * u) ** 2,
        tail=dict(lift=[(0, -4), (1, -4)], lash=(0, 1, 1, 6))),
    "idle": dict(
        n=72, loop=True,
        body=dict(dz=lambda u: 0.003 * math.sin(2 * math.pi * 2 * u), pitch=lambda u: 0.6 * math.sin(2 * math.pi * 2 * u)),
        neck=dict(yaw=lambda u: 14 * math.sin(2 * math.pi * u) * smooth(abs(math.sin(2 * math.pi * u)) * 1.4),
                  pitch=lambda u: 3 * math.sin(2 * math.pi * (2 * u + 0.25))),
        head=dict(roll=lambda u: 6 * math.sin(2 * math.pi * (u + 0.1))),
        jaw=lambda u: 3 + 4 * max(0.0, math.sin(2 * math.pi * (2 * u))) ** 4,
        tail=dict(lift=lambda u: 2 * math.sin(2 * math.pi * u), yaw=lambda u: 14 * math.sin(2 * math.pi * u + 0.6))),
    "hit_react": dict(
        n=15,
        body=dict(dy=[(0, 0), (0.25, 0.04), (1, 0)], dz=[(0, 0), (0.25, 0.015), (0.5, -0.01), (1, 0)],
                  pitch=[(0, 0), (0.25, 10), (0.6, -3), (1, 0)], roll=[(0, 0), (0.25, -6), (1, 0)]),
        feet=dict(FL=dict(dz=[(0, 0), (0.2, 0.05), (0.5, 0), (1, 0)], dy=[(0, 0), (0.3, 0.03), (0.6, 0.03), (1, 0)], follow=[(0, 0), (0.15, 0.6), (0.45, 0)]),
                  FR=dict(dz=[(0, 0), (0.25, 0.06), (0.55, 0), (1, 0)], dy=[(0, 0), (0.35, 0.03), (0.65, 0.03), (1, 0)], follow=[(0, 0), (0.15, 0.6), (0.5, 0)])),
        neck=dict(pitch=[(0, 0), (0.2, 16), (1, 0)], yaw=[(0, 0), (0.2, -14), (1, 0)]),
        jaw=[(0, 3), (0.2, 34), (0.6, 12), (1, 3)],
        tail=dict(lift=[(0, 0), (0.2, 18), (1, 0)])),
}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
skin = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and o.vertex_groups), key=lambda o: len(o.data.vertices))
for o in [o for o in bpy.data.objects if o not in (arm, skin)]:
    bpy.data.objects.remove(o, do_unlink=True)
pbs = arm.pose.bones
bones = arm.data.bones
for pb in pbs:
    pb.rotation_mode = "QUATERNION"
upd = bpy.context.view_layer.update
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
hip0 = (bones["BackUpLeg.L"].head_local + bones["BackUpLeg.R"].head_local) / 2
sho0 = (bones["FrontUpLeg.L"].head_local + bones["FrontUpLeg.R"].head_local) / 2
PIVOT = (hip0 + sho0) / 2
REST_FOOT = {leg: bones[f].matrix_local.copy() for leg, (_, _, f) in LEGS.items()}


def about(pb, axis, deg, piv=None):
    if abs(deg) < 1e-6:
        return
    m = pb.matrix.copy()
    p = m.translation.copy() if piv is None else piv
    pb.matrix = Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p) @ m
    upd()


def val(spec, key, u, default=0.0):
    if not spec or key not in spec:
        return default
    v = spec[key]
    return v(u) if callable(v) else k(u, v)


def solve_leg(up, low, foot):
    h = pbs[up].head.copy(); knee0 = pbs[low].head.copy(); ankle = pbs[foot].head.copy()
    l1 = pbs[up].bone.length
    l2 = (bones[low].head_local - bones[foot].head_local).length
    d_vec = ankle - h
    d = min(d_vec.length, (l1 + l2) * 0.9999)
    u = d_vec.normalized()
    pole = (knee0 - h) - u * (knee0 - h).dot(u)
    if pole.length < 1e-6:
        return
    w = pole.normalized()
    a = math.acos(max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    knee = h + (u * math.cos(a) + w * math.sin(a)) * l1
    for bone, p0, p1 in ((up, h, knee), (low, knee, ankle)):
        m = pbs[bone].matrix.copy()
        q = m.to_3x3().col[1].normalized().rotation_difference((p1 - p0).normalized())
        nm = (q.to_matrix() @ m.to_3x3()).to_4x4(); nm.translation = p0
        pbs[bone].matrix = nm
        upd()


_names = {g.index: g.name for g in skin.vertex_groups}
FOOT_VERTS = {f: [v.index for v in skin.data.vertices if v.groups and _names[max(v.groups, key=lambda g: g.weight).group] == f]
              for _, _, f in LEGS.values()}


def feet_on_floor():
    """A paw whose skin dips under the floor is raised by the deficit (a pitched or lowered foot; the gallop's planted
    pads), then the legs are solved again. Runs before the body's floor pass."""
    ev = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    moved = False
    for foot, idx in FOOT_VERTS.items():
        if not idx:
            continue
        z = min((skin.matrix_world @ me.vertices[i].co).z for i in idx)
        if z < -0.002:
            m = pbs[foot].matrix.copy(); m.translation.z -= z; pbs[foot].matrix = m
            moved = True
    ev.to_mesh_clear()
    if moved:
        upd()
        for up, low, foot in LEGS.values():
            solve_leg(up, low, foot)


def lowest_skin():
    ev = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    z = min((skin.matrix_world @ v.co).z for v in me.vertices)
    ev.to_mesh_clear()
    return z


def pose(c, u):
    for pb in pbs:
        pb.matrix_basis.identity()
    upd()
    b = c.get("body", {})
    dy, dz = val(b, "dy", u), val(b, "dz", u)
    body_m = (Matrix.Translation((0, dy, dz)) @ Matrix.Translation(PIVOT) @ Matrix.Rotation(math.radians(val(b, "yaw", u)), 4, Z)
              @ Matrix.Rotation(math.radians(-val(b, "pitch", u)), 4, X) @ Matrix.Rotation(math.radians(val(b, "roll", u)), 4, Y)
              @ Matrix.Translation(-PIVOT))
    body = pbs["Body"]
    body.matrix = body_m @ body.matrix
    upd()
    hp = c.get("hips", {})
    if hp:  # rump wiggle: the hindquarters sway about the shoulders
        about(pbs["Hips"], Z, val(hp, "yaw", u), body_m @ sho0)
        for s in "LR":
            about(pbs[f"BackLeg.{s}"], Z, val(hp, "yaw", u), body_m @ sho0)
        m = pbs["Hips"].matrix.copy(); m.translation.z += val(hp, "dz", u); pbs["Hips"].matrix = m; upd()
        for s in "LR":
            m = pbs[f"BackLeg.{s}"].matrix.copy(); m.translation.z += val(hp, "dz", u); pbs[f"BackLeg.{s}"].matrix = m; upd()
    # feet: ground-frame targets, or carried with the body (follow) while airborne / lifted
    for leg, (up, low, foot) in LEGS.items():
        f = c.get("feet", {}).get(leg, {})
        rest = REST_FOOT[leg]
        off = Vector((val(f, "dx", u), val(f, "dy", u), val(f, "dz", u)))
        fol = val(f, "follow", u)
        ground = rest.translation + off
        carried = body_m @ (rest.translation + off)
        tgt = ground.lerp(carried, fol)
        rot = Matrix.Rotation(math.radians(val(f, "pitch", u)), 3, X)  # + = toe down/back about the side axis
        if fol > 0:  # a carried foot also turns with the body
            rot = Quaternion().slerp(body_m.to_quaternion(), fol).to_matrix() @ rot
        elif val(f, "pitch", u) > 0:  # a planted foot pitching toe-down peels the heel off its toes (they stay put)
            tvec = bones[foot].tail_local - bones[foot].head_local
            tgt = tgt + tvec - rot @ tvec
        m = (rot @ rest.to_3x3()).to_4x4(); m.translation = tgt
        pbs[foot].matrix = m
        upd()
    n = c.get("neck", {}); h = c.get("head", {})
    about(pbs["Neck"], Z, val(n, "yaw", u)); about(pbs["Neck"], X, -val(n, "pitch", u))
    about(pbs["Head"], Z, val(h, "yaw", u)); about(pbs["Head"], X, -val(h, "pitch", u))
    hy = pbs["Head"].matrix.to_3x3().col[1].normalized()
    about(pbs["Head"], hy, val(h, "roll", u))
    jaw = c.get("jaw", 0.0)
    jd = jaw(u) if callable(jaw) else k(u, jaw)
    pbs["Jaw"].matrix_basis = Quaternion(X, math.radians(jd)).to_matrix().to_4x4()
    upd()
    t = c.get("tail", {})
    about(pbs["Tail1"], X, val(t, "lift", u))
    lash = t.get("lash")
    for i, tb in enumerate(TAILS):
        ang = val(t, "yaw", max(0.0, u - 0.03 * i)) / len(TAILS) * 1.6
        if lash:
            ang += osc(u, lash[0], lash[1], lash[2], lash[3] * (0.4 + 0.2 * i), -0.08 * i)
        about(pbs[tb], Z, ang)
    for up, low, foot in LEGS.values():
        solve_leg(up, low, foot)
    feet_on_floor()
    air = c.get("airborne")
    z = lowest_skin()
    if z < -0.002:
        if air and air[0] < u < air[1]:  # in the air the whole animal is lifted (the game carries it on an arc anyway)
            m = pbs["root"].matrix.copy(); m.translation.z -= z; pbs["root"].matrix = m
            upd()
        else:  # on the ground the body rises off whatever would sink (belly, knees); the feet stay planted
            m = body.matrix.copy(); m.translation.z -= z; body.matrix = m
            upd()
            for up, low, foot in LEGS.values():
                solve_leg(up, low, foot)


WANT = argv[2:] or list(CLIPS)
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
for name in WANT:
    c = CLIPS[name]
    n = c["n"]
    frames = []
    for f in range(n + (1 if c.get("loop") else 0)):
        u = (f % n) / n if c.get("loop") else f / (n - 1)
        pose(c, u)
        frames.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in pbs})
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f, rows in enumerate(frames):
        for pb in pbs:
            pb.location, pb.rotation_quaternion = rows[pb.name]
            pb.keyframe_insert("location", frame=f + 1)
            pb.keyframe_insert("rotation_quaternion", frame=f + 1)
    sc.frame_start, sc.frame_end = 1, len(frames)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    out = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", export_apply=False, export_yup=True,
        use_selection=True, export_animations=True, export_animation_mode="ACTIVE_ACTIONS",
        export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
        export_anim_slide_to_zero=False, export_skins=True, export_morph=False,
        export_def_bones=False, export_reset_pose_bones=False, export_current_frame=False,
        export_nla_strips=False, export_anim_single_armature=True, export_bake_animation=True,
        export_materials="NONE", export_image_format="NONE")
    print("WROTE", out, len(frames), "frames")
    arm.animation_data.action = None
    for pb in pbs:
        pb.matrix_basis.identity()
