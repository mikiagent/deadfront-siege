"""SP-RAPTOR signature moves on the Raptor's transplant rig (Quaternius Velociraptor bone names: Body/Hips/Torso/
Shoulders/Neck/Head/Jaw, BackLeg/BackUpLeg/BackLowLeg + root-parented BackFoot, FrontLeg/FrontUpLeg/FrontLowLeg/
FrontFoot, Tail1-5). Same method as make_investigate_idle.py: small rest-relative turns keyed per frame, the stance
foot planted on its print with two-bone leg IK, exported skeleton-only.

Owner 2026-10-30: "be creative with what moves you think they should do when they fight". # ASSUMPTION (no PRD clip
list for the Raptor), true to a big dromaeosaur:
  pin_stab      2.4 s, hits 0.38 and 0.74 (anim_events pin_stab): the RPR hold ("raptor prey restraint", how
                Deinonychus is thought to have killed). After a landed pounce the right foot stamps onto the prey and
                holds it down with the sickle claw, the arms flap wide for balance (stability flapping, the gold fans
                beating), and the head rears with the jaws wide and drives down to bite twice, tugging after each.
  attack_heavy  1.42 s, windup hold 0.6, hit 0.72 (anim_events attack_heavy): the sickle slash. It rocks onto the
                left leg with the right foot hauled high and the sickle claw cocked up (the telegraph), arms flared for
                balance and the jaws hissing, then drives the foot forward and down through the prey and rakes it back.
  alert         1.67 s: the crest-flare display. It rears, throws the feathered arms wide and the tail up, screeches
                with a head shake, then drops into a low hunting crouch. TacticalBrain's display step plays it.

usage: Blender -b -P tools/gait/make_raptor_moves.py -- <base.glb> <clip> <out.glb> [--gain 1.0]
  sleep         3.0 s loop: lying belly-down with the legs folded under, the head curled back along its left flank
                and resting on the floor, the tail curled round, slow breaths (the velociraptor's sleep did not
                survive the move onto this body: it sank 0.7 m).

  clip: pin_stab | attack_heavy | alert | sleep | charge_turn | flank_rake
  RAPTORFLANK: arms glued to the chest and keyed with hand-claw grabs (hand, elbow tracks); charge_turn (the flank's
  skid-turn) and flank_rake (the leap-rake from behind) added.
"""
import math
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, CLIP, OUT = argv[:3]
GAIN = float(argv[argv.index("--gain") + 1]) if "--gain" in argv else 1.0
FPS = 24
SECONDS = {"pin_stab": 2.4, "attack_heavy": 1.42, "alert": 1.67, "sleep": 3.0, "charge_turn": 0.71, "flank_rake": 1.0}[CLIP]
N = int(round(SECONDS * FPS))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
pbs, bones = arm.pose.bones, arm.data.bones
FWD, UP = Vector((0, -1, 0)), Vector((0, 0, 1))
SIDE = FWD.cross(UP).normalized()  # the animal's right
HIP_H = bones["BackUpLeg.L"].head_local.z


def rot_about(p, axis, ang):
    return Matrix.Translation(p) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-p)


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def track(keys, u):
    """keys: [(u, value), ...] sorted by u; smoothstep between neighbours, held outside."""
    if u <= keys[0][0]:
        return keys[0][1]
    for (u0, v0), (u1, v1) in zip(keys, keys[1:]):
        if u <= u1:
            return v0 + (v1 - v0) * smooth((u - u0) / max(u1 - u0, 1e-6))
    return keys[-1][1]


Z = [(0.0, 0.0)]
# Each clip: tracks in fractions of the clip. Distances in hip heights, angles in degrees.
#   drop / fwd / sway (+ = to its right): the Body; torso (+ = nose down); neck_p, head_p (+ = nose down);
#   neck_y (+ = to its left), head_r (+ = tilt left); jaw (open); tail_p (+ = tail up), tail_y; arm_out (spread),
#   arm_up (swung forward and up), flap (beat amplitude, flap_hz beats per second inside flap_on);
#   rf_fwd / rf_up / rf_pitch (+ = toe down): the right foot's target; lf_* the left's (default: on its print).
if CLIP == "pin_stab":
    T = dict(
        drop=[(0, 0), (.14, .14), (.30, .10), (.38, .22), (.50, .16), (.64, .10), (.74, .22), (.86, .14), (1, 0)],
        fwd=[(0, 0), (.14, .16), (.86, .16), (1, 0)],
        sway=[(0, 0), (.12, -.06), (.88, -.06), (1, 0)],
        torso=[(0, 0), (.14, 14), (.30, 4), (.38, 28), (.50, 16), (.64, 4), (.74, 30), (.86, 14), (1, 0)],
        neck_p=[(0, 0), (.14, 10), (.22, -22), (.31, -26), (.38, 58), (.44, 50), (.52, 36), (.60, -18), (.67, -22),
                (.74, 64), (.80, 54), (.88, 30), (1, 0)],
        head_p=[(0, 0), (.22, -8), (.31, -12), (.38, 26), (.52, 14), (.60, -10), (.67, -12), (.74, 28), (.88, 12), (1, 0)],
        neck_y=[(0, 0), (.44, 0), (.47, 10), (.50, -10), (.53, 0), (.80, 0), (.83, -12), (.86, 12), (.89, 0), (1, 0)],
        head_r=[(0, 0), (.44, 0), (.47, 18), (.50, -18), (.53, 6), (.80, 0), (.83, -20), (.86, 20), (.89, 0), (1, 0)],
        jaw=[(0, 0), (.20, 38), (.33, 42), (.38, 4), (.41, 2), (.56, 4), (.62, 40), (.70, 44), (.74, 4), (.78, 2), (1, 0)],
        tail_p=[(0, 0), (.14, 10), (.38, 4), (.74, 4), (.86, 10), (1, 0)],
        tail_y=[(0, 0), (.25, 10), (.45, -10), (.65, 8), (.85, -8), (1, 0)],
        arm_out=[(0, 0), (.12, 42), (.88, 42), (1, 0)],
        arm_up=[(0, 0), (.12, 24), (.88, 24), (1, 0)],
        flap=[(0, 0), (.12, 18), (.40, 24), (.76, 24), (.88, 12), (1, 0)],
        hand=[(0, 0), (.12, -24), (.33, -34), (.39, 56), (.50, 24), (.66, -34), (.75, 56), (.86, 24), (1, 0)],
        elbow=[(0, 0), (.33, -20), (.39, 30), (.50, 10), (.66, -20), (.75, 30), (.86, 10), (1, 0)],
        rf_fwd=[(0, 0), (.07, .38), (.14, .62), (.86, .62), (.93, .30), (1, 0)],
        rf_up=[(0, 0), (.07, .42), (.14, .16), (.86, .16), (.93, .30), (1, 0)],
        rf_pitch=[(0, 0), (.07, -20), (.14, 28), (.86, 28), (.93, -10), (1, 0)],
    )
    FLAP_HZ, FLAP_ON = 3.0, (0.10, 0.90)
elif CLIP == "attack_heavy":
    T = dict(
        drop=[(0, 0), (.30, .10), (.60, .12), (.68, .02), (.80, .06), (1, 0)],
        fwd=[(0, 0), (.30, -.06), (.60, -.08), (.70, .26), (.80, .20), (1, 0)],
        sway=[(0, 0), (.25, -.09), (.60, -.10), (.72, -.04), (1, 0)],
        torso=[(0, 0), (.30, -10), (.60, -12), (.70, 16), (.82, 10), (1, 0)],
        neck_p=[(0, 0), (.30, -12), (.60, -14), (.70, 18), (.82, 10), (1, 0)],
        head_p=[(0, 0), (.30, -4), (.60, -6), (.70, 8), (1, 0)],
        neck_y=Z, head_r=[(0, 0), (.40, 6), (.50, -6), (.60, 0), (1, 0)],
        jaw=[(0, 0), (.20, 26), (.60, 30), (.70, 14), (.85, 6), (1, 0)],
        tail_p=[(0, 0), (.30, 14), (.60, 16), (.72, -4), (1, 0)],
        tail_y=[(0, 0), (.30, -8), (.60, -8), (.72, 10), (1, 0)],
        arm_out=[(0, 0), (.25, 55), (.60, 60), (.72, 30), (.90, 8), (1, 0)],
        arm_up=[(0, 0), (.25, 30), (.60, 34), (.72, 10), (1, 0)],
        flap=[(0, 0), (.30, 6), (.60, 6), (.66, 0), (1, 0)],
        hand=[(0, 0), (.30, -36), (.60, -40), (.70, 54), (.86, 30), (1, 0)],
        elbow=[(0, 0), (.30, -16), (.60, -18), (.70, 34), (.86, 16), (1, 0)],
        rf_fwd=[(0, 0), (.30, .10), (.60, .12), (.71, 1.05), (.82, .55), (.94, .10), (1, 0)],
        rf_up=[(0, 0), (.30, .58), (.60, .62), (.71, .30), (.82, .12), (.90, .14), (1, 0)],
        rf_pitch=[(0, 0), (.30, -42), (.60, -48), (.71, 46), (.82, 8), (1, 0)],
    )
    FLAP_HZ, FLAP_ON = 6.0, (0.25, 0.60)
elif CLIP == "sleep":
    B = lambda a: [(0, 0), (.5, a), (1, 0)]  # one slow breath per half: seamless
    T = dict(
        drop=[(0, .80), (.25, .81), (.5, .80), (.75, .81), (1, .80)], fwd=[(0, -.10)], sway=Z,
        torso=[(0, 6)], neck_p=[(0, 62)], head_p=[(0, 16)], neck_y=[(0, 24)], head_r=[(0, -10)],
        jaw=Z, tail_p=[(0, -6)], tail_y=[(0, 34)], arm_out=[(0, -6)], arm_up=[(0, -18)], flap=Z,
        rf_fwd=[(0, -.30)], rf_up=[(0, .02)], rf_pitch=[(0, -8)],
        lf_fwd=[(0, -.30)], lf_up=[(0, .02)], lf_pitch=[(0, -8)],
    )
    FLAP_HZ, FLAP_ON = 1.0, (0.0, 0.0)
elif CLIP == "charge_turn":
    # RAPTORFLANK skid-turn (the flank's turn after it runs past): brakes leaning back with the feet skidding ahead,
    # hops (airborne 0.2-0.6, anim_events charge_turn: the brain swings the yaw only then, so no planted foot
    # skids round), arms thrown wide and the tail lifted for balance, lands squashed into a crouch facing the prey.
    T = dict(
        drop=[(0, 0), (.14, .16), (.22, .10), (.42, -.02), (.62, .06), (.72, .18), (.86, .10), (1, 0)],
        fwd=[(0, 0), (.14, .10), (.40, 0), (.70, -.04), (1, 0)],
        sway=Z,
        torso=[(0, 0), (.14, -14), (.30, -6), (.55, 4), (.70, 14), (.86, 6), (1, 0)],
        neck_p=[(0, 0), (.14, -10), (.40, -4), (.70, 16), (1, 0)],
        head_p=[(0, 0), (.20, -6), (.70, 8), (1, 0)],
        neck_y=[(0, 0), (.20, 14), (.55, 22), (.72, 6), (1, 0)], head_r=[(0, 0), (.3, 10), (.7, 0), (1, 0)],
        jaw=[(0, 0), (.20, 18), (.60, 22), (.80, 6), (1, 0)],
        tail_p=[(0, 0), (.14, 6), (.40, 20), (.60, 14), (.75, -2), (1, 0)],
        tail_y=[(0, 0), (.20, -10), (.45, -28), (.65, -10), (1, 0)],
        arm_out=[(0, 0), (.16, 30), (.30, 60), (.60, 56), (.75, 20), (1, 0)],
        arm_up=[(0, 0), (.16, 10), (.30, 30), (.60, 26), (.75, 8), (1, 0)],
        flap=Z,
        hand=[(0, 0), (.25, -36), (.60, -30), (.80, 6), (1, 0)],
        elbow=[(0, 0), (.25, -16), (.60, -12), (.80, 10), (1, 0)],
        rf_fwd=[(0, 0), (.14, .34), (.22, .26), (.40, .06), (.60, -.02), (.70, 0), (1, 0)],
        rf_up=[(0, 0), (.14, .07), (.22, .12), (.40, .22), (.58, .08), (.64, 0), (1, 0)],
        rf_pitch=[(0, 0), (.14, -12), (.40, 10), (.62, 0), (1, 0)],
        lf_fwd=[(0, 0), (.14, .28), (.22, .22), (.40, .04), (.60, -.02), (.70, 0), (1, 0)],
        lf_up=[(0, 0), (.14, .07), (.22, .14), (.42, .24), (.58, .08), (.64, 0), (1, 0)],
        lf_pitch=[(0, 0), (.14, -12), (.40, 10), (.62, 0), (1, 0)],
    )
    FLAP_HZ, FLAP_ON = 1.0, (0.0, 0.0)
elif CLIP == "flank_rake":
    # RAPTORFLANK finisher: from behind the prey, a short leap onto its back (airborne 0.18-0.55, the brain carries
    # the arc) with both sickle feet swung forward and cocked, the arms thrown forward with the hand claws spread and
    # the jaws wide; at 0.55 both feet and both hands rake down through the prey and the jaws bite; it rakes back
    # and drops into its stance. # ASSUMPTION timing.
    T = dict(
        drop=[(0, 0), (.16, .20), (.26, .06), (.45, -.06), (.55, .04), (.66, .16), (.85, .08), (1, 0)],
        fwd=[(0, 0), (.16, -.06), (.40, .10), (.55, .22), (.70, .14), (1, 0)],
        sway=Z,
        torso=[(0, 0), (.16, 14), (.30, -12), (.48, -8), (.56, 22), (.70, 16), (.88, 4), (1, 0)],
        neck_p=[(0, 0), (.16, 10), (.30, -18), (.48, -20), (.56, 30), (.70, 22), (1, 0)],
        head_p=[(0, 0), (.30, -8), (.48, -10), (.56, 16), (1, 0)],
        neck_y=Z, head_r=[(0, 0), (.58, 0), (.62, 12), (.66, -12), (.70, 0), (1, 0)],
        jaw=[(0, 0), (.20, 20), (.48, 46), (.56, 4), (.66, 2), (1, 0)],
        tail_p=[(0, 0), (.16, -6), (.30, 16), (.50, 12), (.62, -4), (1, 0)],
        tail_y=[(0, 0), (.55, 0), (.65, 10), (.80, -6), (1, 0)],
        arm_out=[(0, 0), (.16, 0), (.30, 34), (.50, 30), (.58, 12), (.80, 6), (1, 0)],
        arm_up=[(0, 0), (.16, -18), (.30, 60), (.50, 72), (.58, 4), (.70, -10), (.88, -2), (1, 0)],
        flap=Z,
        hand=[(0, 0), (.16, 6), (.30, -48), (.50, -52), (.57, 62), (.75, 44), (1, 0)],
        elbow=[(0, 0), (.16, 22), (.30, -26), (.50, -30), (.57, 36), (.75, 20), (1, 0)],
        rf_fwd=[(0, 0), (.16, -.04), (.30, .40), (.50, .70), (.56, .78), (.66, .34), (.82, .10), (1, 0)],
        rf_up=[(0, 0), (.16, 0), (.30, .40), (.50, .46), (.56, .30), (.66, .14), (.76, 0), (1, 0)],
        rf_pitch=[(0, 0), (.16, 0), (.30, -36), (.50, -44), (.56, 34), (.68, 8), (.76, 0), (1, 0)],
        lf_fwd=[(0, 0), (.16, -.04), (.32, .36), (.50, .64), (.56, .72), (.66, .30), (.82, .08), (1, 0)],
        lf_up=[(0, 0), (.16, 0), (.32, .38), (.50, .44), (.56, .28), (.66, .12), (.76, 0), (1, 0)],
        lf_pitch=[(0, 0), (.16, 0), (.32, -34), (.50, -42), (.56, 32), (.68, 6), (.76, 0), (1, 0)],
    )
    FLAP_HZ, FLAP_ON = 1.0, (0.0, 0.0)
else:  # alert: the crest-flare display
    T = dict(
        drop=[(0, 0), (.22, -.01), (.65, -.01), (.85, .16), (1, .16)],
        fwd=[(0, 0), (.22, -.05), (.65, -.05), (.85, .04), (1, .04)],
        sway=Z,
        torso=[(0, 0), (.22, -18), (.65, -18), (.85, 6), (1, 6)],
        neck_p=[(0, 0), (.22, -22), (.30, -26), (.65, -20), (.85, 12), (1, 12)],
        head_p=[(0, 0), (.22, -6), (.65, -6), (.85, -12), (1, -12)],
        neck_y=[(0, 0), (.30, 0), (.40, 12), (.50, -12), (.60, 0), (1, 0)],
        head_r=[(0, 0), (.30, 0), (.34, 14), (.38, -14), (.42, 14), (.46, -14), (.50, 10), (.54, -10), (.60, 0), (1, 0)],
        jaw=[(0, 0), (.22, 10), (.30, 46), (.58, 46), (.70, 10), (1, 8)],
        tail_p=[(0, 0), (.22, 18), (.65, 18), (.85, 2), (1, 2)],
        tail_y=[(0, 0), (.30, 12), (.40, -12), (.50, 12), (.60, -12), (.75, 0), (1, 0)],
        arm_out=[(0, 0), (.22, 70), (.65, 70), (.85, 6), (1, 6)],
        arm_up=[(0, 0), (.22, 38), (.65, 38), (.85, 4), (1, 4)],
        flap=[(0, 0), (.22, 8), (.60, 8), (.66, 0), (1, 0)],
        hand=[(0, 0), (.22, -40), (.65, -40), (.85, 6), (1, 6)],
        elbow=[(0, 0), (.22, -20), (.65, -20), (.85, 8), (1, 8)],
        rf_fwd=Z, rf_up=Z, rf_pitch=Z,
    )
    FLAP_HZ, FLAP_ON = 5.0, (0.20, 0.62)


def flap(u):
    a, b = FLAP_ON
    if u <= a or u >= b:
        return 0.0
    return track(T["flap"], u) * math.sin(2 * math.pi * FLAP_HZ * (u - a) * SECONDS)


LEGS = {}
for s in "LR":
    up, low, foot = "BackUpLeg." + s, "BackLowLeg." + s, "BackFoot." + s
    h, k, an = bones[up].head_local, bones[low].head_local, bones[foot].head_local
    line = an - h
    off = (k - h) - line * ((k - h).dot(line) / line.length_squared)
    LEGS[s] = {"up": up, "low": low, "foot": foot, "l1": bones[up].length, "l2": (k - an).length,
               "pole": off.normalized(), "ankle0": an.copy()}


def set_m(name, m):
    pbs[name].matrix = m
    bpy.context.view_layer.update()


def solve_leg(leg, ankle):
    up, low = leg["up"], leg["low"]
    set_m(up, pbs[up].matrix)
    h = pbs[up].head.copy()
    l1, l2 = leg["l1"], leg["l2"]
    d_vec = ankle - h
    d = min(d_vec.length, (l1 + l2) * 0.9999)
    u = d_vec.normalized()
    w = leg["pole"] - u * leg["pole"].dot(u)
    w.normalize()
    a = math.acos(max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    knee = h + (u * math.cos(a) + w * math.sin(a)) * l1
    for bone, p0, p1 in ((up, h, knee), (low, knee, h + u * d)):
        m = pbs[bone].matrix.copy()
        q = m.to_3x3().col[1].normalized().rotation_difference((p1 - p0).normalized())
        nm = (q.to_matrix() @ m.to_3x3()).to_4x4()
        nm.translation = p0
        set_m(bone, nm)


def turn(name, axis, deg):
    if name in pbs and deg:
        cur = pbs[name].matrix.copy()
        set_m(name, rot_about(cur.translation, axis, math.radians(deg) * GAIN) @ cur)


def pose(f):
    u = f / N
    g = lambda k: track(T[k], u) * GAIN
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    body = pbs["Body"].matrix.copy()
    move = FWD * (g("fwd") * HIP_H) + SIDE * (g("sway") * HIP_H) - UP * (g("drop") * HIP_H)
    set_m("Body", Matrix.Translation(move) @ body)
    tp = g("torso")
    turn("Torso", SIDE, -tp * 0.5)  # a positive turn about SIDE lifts the nose
    turn("Shoulders", SIDE, -tp * 0.5)
    turn("Neck", UP, g("neck_y") * 0.55)
    turn("Neck", SIDE, -(g("neck_p") * 0.6 - tp * 0.7))
    turn("Head", UP, g("neck_y") * 0.45)
    turn("Head", SIDE, -(g("neck_p") * 0.4 + g("head_p") - tp * 0.3))
    turn("Head", FWD, -g("head_r"))
    if "Jaw" in pbs:  # positive Jaw local X opens (tools/jaw/key_jaw.py)
        cur = pbs["Jaw"].matrix.copy()
        set_m("Jaw", rot_about(cur.translation, cur.to_3x3().col[0].normalized(), math.radians(g("jaw"))) @ cur)
    for i, t in enumerate(("Tail1", "Tail2", "Tail3", "Tail4", "Tail5")):
        k = (0.3, 0.26, 0.2, 0.14, 0.1)[i]
        turn(t, UP, g("tail_y") * k * 1.6)
        turn(t, SIDE, -(g("tail_p") - tp * (0.6 if i == 0 else 0.0)) * k * 1.6)  # tail up = nose-down turn reversed
    fl = flap(u) * GAIN
    # RAPTORFLANK: the arms hang from Body, not the chest; carry them with the Shoulders so a torso pitch does not leave
    # them behind, and turn them in the chest's frame.
    sh_rest = pbs["Body"].matrix @ bones["Body"].matrix_local.inverted() @ bones["Shoulders"].matrix_local
    glue = pbs["Shoulders"].matrix @ sh_rest.inverted()
    for s_ in "LR":
        set_m("FrontLeg." + s_, glue @ pbs["FrontLeg." + s_].matrix)
    cr = (pbs["Shoulders"].matrix.to_3x3() @ bones["Shoulders"].matrix_local.to_3x3().inverted()).normalized()
    cside, cfwd = cr @ SIDE, cr @ FWD
    for s_, sign in (("L", 1.0), ("R", -1.0)):
        out = g("arm_out") + fl
        turn("FrontLeg." + s_, cside, g("arm_up") * 0.6 + fl * 0.3)  # swing the arm forward and up
        turn("FrontLeg." + s_, cfwd, -sign * out * 0.7)  # elbows out: the feather fans open
        turn("FrontUpLeg." + s_, cfwd, -sign * out * 0.3)
        turn("FrontLowLeg." + s_, cside, -g("arm_up") * 0.5 - (g("elbow") if "elbow" in T else 0.0))  # hands curl in as the arms rise
        if "hand" in T:
            turn("FrontFoot." + s_, cside, -g("hand"))  # + = the hand claws clench, - = spread forward
    for s_, leg in LEGS.items():
        k = s_.lower() + "f_"
        gl = lambda n: g(k + n) if k + n in T else 0.0
        if gl("fwd") or gl("up") or gl("pitch"):
            ankle = leg["ankle0"] + FWD * (gl("fwd") * HIP_H) + UP * (gl("up") * HIP_H)
            fm = rot_about(Vector(), SIDE, -math.radians(gl("pitch"))) @ bones[leg["foot"]].matrix_local.copy()
            fm.translation = ankle
            set_m(leg["foot"], fm)
            solve_leg(leg, ankle)
        else:
            solve_leg(leg, leg["ankle0"])  # planted on its print, the knee takes the crouch


arm.animation_data_create()
act = bpy.data.actions.new(CLIP)
arm.animation_data.action = act
for f in range(N + 1):
    pose(f)
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert("location", frame=f)
        pb.keyframe_insert("rotation_quaternion", frame=f)
        pb.keyframe_insert("scale", frame=f)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, N
print("CLIP", CLIP, "frames", N, "seconds", N / FPS)

for o in list(bpy.data.objects):
    if o is not arm:
        bpy.data.objects.remove(o, do_unlink=True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", export_apply=False, export_yup=True,
    use_selection=True, export_animations=True, export_animation_mode="ACTIONS",
    export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
    export_anim_slide_to_zero=False, export_skins=True, export_morph=False,
    export_def_bones=False, export_reset_pose_bones=False, export_current_frame=False,
    export_nla_strips=False, export_anim_single_armature=True, export_bake_animation=True,
    export_materials="NONE", export_image_format="NONE")
print("WROTE", OUT)
