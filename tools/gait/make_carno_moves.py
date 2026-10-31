"""Author the carnotaurus' fight one-shots on its transplant biped rig (Velociraptor donor bone names + Jaw),
in place, hind feet IK-planted on their rest prints unless a beat steps or lifts them.

Owner 2026-10-30: "Fast bull-like predator: horn ram that knocks the target back, sprint charge with a sharp turn,
snap bite." Hit frames match game/data/creatures/anim_events.json (attack_primary 0.42, attack_heavy 0.72) and the
charge_turn's airborne window [0.2, 0.6] is where the game swings the body round (TacticalBrain charge_turn).

  attack_primary  snap bite, 0.75 s: coil (neck back, jaws wide) -> dart forward-down -> SNAP shut on 0.42 ->
                  a short head shake -> recover
  attack_heavy    horn ram, 1.5 s: rear back bellowing -> hold, scrape a hind foot like a bull while the head drops
                  to aim the brow horns (the telegraph) -> drive forward with a step, horns first, impact on 0.72 ->
                  hook the head up (the toss that throws the target back) -> recover, the foot steps back
  charge_turn     the sharp turn at the end of a charge, 0.71 s: plant and crouch, hop with the body banked into the
                  turn and the tail flung wide as a counterweight, land squashed, recover. Turns to its left; the game
                  yaws the body only while it is airborne, so planted feet never skid.
  alert           roar, 1.25 s: rear up, head high, then thrust the head forward with the jaws wide and shaking
  idle            3 s loop: breathing, a slow look around, tail sway
  hit_react       0.58 s recoil: head jerks back, body flinches, settles
  feed            3 s loop: head down to the carcass, three tearing tugs, chewing
  (The transplant's donor idle and hit_react kept the velociraptor's feet 0.86 m from this rig's prints.)

Poses are channel values eased with smoothstep between keys (u, value), keyed per frame as small turns from rest.
usage: Blender -b -P tools/gait/make_carno_moves.py -- <base.glb> <clip> <out.glb>
"""
import math
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, CLIP, OUT = argv[:3]
FPS = 24
N = {"attack_primary": 18, "attack_heavy": 36, "charge_turn": 17, "alert": 30, "idle": 72, "hit_react": 14, "feed": 72}[CLIP]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
pbs, bones = arm.pose.bones, arm.data.bones
FWD, UP = Vector((0, -1, 0)), Vector((0, 0, 1))
SIDE = FWD.cross(UP).normalized()  # the animal's right
LEN = max(b.head_local.y for b in bones) - min(b.head_local.y for b in bones)
S = LEN / 1.0  # distances below are for a 1.0-unit-long rig


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def track(keys, u):
    """Smoothstep between (u, value) keys; holds before the first and after the last."""
    if u <= keys[0][0]:
        return keys[0][1]
    for (u0, v0), (u1, v1) in zip(keys, keys[1:]):
        if u <= u1:
            return v0 + (v1 - v0) * smooth((u - u0) / max(1e-6, u1 - u0))
    return keys[-1][1]


def rot_about(p, axis, ang):
    return Matrix.Translation(p) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-p)


def set_m(name, m):
    pbs[name].matrix = m
    bpy.context.view_layer.update()


def turn(name, axis, deg):
    if name in pbs and deg:
        cur = pbs[name].matrix.copy()
        set_m(name, rot_about(cur.translation, axis, math.radians(deg)) @ cur)


LEGS = {}
for sd in "LR":
    up, low, foot = "BackUpLeg." + sd, "BackLowLeg." + sd, "BackFoot." + sd
    h, k, an = bones[up].head_local, bones[low].head_local, bones[foot].head_local
    line = an - h
    off = (k - h) - line * ((k - h).dot(line) / line.length_squared)
    LEGS[sd] = {"up": up, "low": low, "foot": foot, "l1": bones[up].length, "l2": (k - an).length,
                "pole": off.normalized(), "ankle0": an.copy(), "x": 1.0 if an.x > 0 else -1.0,
                "toe0": bones[foot].tail_local.copy()}
# The heel rolls about the claw tips on the floor: the foot's skin that touches the ground furthest forward (the bone's
# tail sits 1 cm up and behind them, and rolling about it lifted the claws 0.17 m).
_skin = next(o for o in bpy.data.objects if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers))
for sd, leg in LEGS.items():
    gi = _skin.vertex_groups[leg["foot"]].index
    sole = [_skin.matrix_world @ v.co for v in _skin.data.vertices
            if v.groups and max(v.groups, key=lambda g: g.weight).group == gi and (_skin.matrix_world @ v.co).z < 0.012]
    if sole:
        tip = min(sole, key=lambda q: q.y)
        leg["toe0"] = Vector((tip.x, tip.y, 0.0))


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
    return h + u * d


def jaw(deg):
    if "Jaw" in pbs and deg:
        cur = pbs["Jaw"].matrix.copy()
        set_m("Jaw", rot_about(cur.translation, cur.to_3x3().col[0].normalized(), math.radians(deg)) @ cur)


def plant(foot_moves):
    """Hind legs onto their rest prints (+ per-side offset, lift and heel roll): foot_moves[sd] = (offset, roll_deg).
    The legs stand ~95 % straight at rest, so a body pose that takes a hip out of reach of its print lowers the Body
    just enough first (as make_gait does): a clamped leg would drag its foot off the print instead, and rolling the
    heel up could not reach far enough."""
    goals = {}
    for sd, leg in LEGS.items():
        off, roll = foot_moves.get(sd, (Vector(), 0.0))
        heel = rot_about(leg["toe0"] + off, SIDE, math.radians(-roll))
        goals[sd] = (heel, heel @ (leg["ankle0"] + off), off)
    drop = 0.0
    for sd, leg in LEGS.items():
        h, ankle = pbs[leg["up"]].head, goals[sd][1]
        reach = (leg["l1"] + leg["l2"]) * 0.985
        flat = Vector((ankle.x - h.x, ankle.y - h.y, 0.0)).length
        if (ankle - h).length > reach and flat < reach:
            drop = max(drop, (h.z - ankle.z) - math.sqrt(reach * reach - flat * flat))
    if drop > 0.0:
        set_m("Body", Matrix.Translation(-UP * drop) @ pbs["Body"].matrix.copy())
    for sd, leg in LEGS.items():
        heel, ankle, off = goals[sd]
        got = solve_leg(leg, ankle)
        fm = heel @ (Matrix.Translation(off) @ pbs[leg["foot"]].matrix.copy())
        fm.translation = got
        set_m(leg["foot"], fm)


def body(shift_fwd, drop, pitch, roll=0.0, yaw=0.0):
    piv = bones["Hips"].head_local.copy()
    m = Matrix.Translation(FWD * shift_fwd * S - UP * drop * S) @ rot_about(piv, UP, math.radians(yaw)) \
        @ rot_about(piv, SIDE, math.radians(pitch)) @ rot_about(piv, FWD, math.radians(roll)) @ pbs["Body"].matrix.copy()
    set_m("Body", m)


TAILS = [t for t in ("Tail1", "Tail2", "Tail3", "Tail4", "Tail5") if t in pbs]


def tail(lift, yaw):
    for i, t in enumerate(TAILS):
        k = (0.3, 0.25, 0.2, 0.15, 0.1)[i]
        turn(t, SIDE, -lift * k / 0.3 * 0.35)
        turn(t, UP, yaw * k / 0.3 * 0.35)


def arms(deg):
    for sd in "LR":
        turn("FrontUpLeg." + sd, SIDE, deg)
        turn("FrontLowLeg." + sd, SIDE, deg * 0.5)


def pose(f):
    u = f / N
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    feet = {}
    if CLIP == "attack_primary":  # snap bite, hit 0.42
        fwd = track([(0, 0), (0.3, -0.015), (0.42, 0.035), (0.6, 0.02), (1, 0)], u)
        pitch = track([(0, 0), (0.3, 5), (0.42, -14), (0.6, -6), (1, 0)], u)
        neck = track([(0, 0), (0.3, 16), (0.42, -32), (0.6, -16), (1, 0)], u)  # down to a survivor's height
        head = track([(0, 0), (0.3, 8), (0.42, -6), (0.6, -4), (1, 0)], u)
        shake = 12 * math.sin(2 * math.pi * 2 * max(0.0, (u - 0.42) / 0.2)) * (1 if 0.42 <= u <= 0.62 else 0)
        jaw_deg = track([(0, 2), (0.28, 34), (0.38, 36), (0.42, 0), (0.6, 2), (1, 2)], u)
        body(fwd, 0.0, pitch, roll=shake * 0.15)
        turn("Torso", SIDE, -pitch * 0.2)
        turn("Neck", SIDE, neck)
        turn("Neck", UP, shake)
        turn("Head", SIDE, head)
        turn("Head", FWD, shake * 0.8)
        jaw(jaw_deg)
        tail(track([(0, 0), (0.3, 6), (0.42, -12), (0.6, -6), (1, 0)], u), -shake * 0.6)  # against the body pitch: the tip stays level
        arms(track([(0, 0), (0.3, 10), (0.42, 25), (1, 0)], u))
    elif CLIP == "attack_heavy":  # horn ram, telegraph to 0.55, hit 0.72
        fwd = track([(0, 0), (0.22, -0.04), (0.55, -0.045), (0.72, 0.07), (0.82, 0.06), (1, 0)], u)
        drop = track([(0, 0), (0.22, 0.0), (0.55, 0.03), (0.72, 0.045), (0.82, 0.015), (1, 0)], u)
        pitch = track([(0, 0), (0.22, 12), (0.4, 4), (0.55, -6), (0.72, -16), (0.8, 6), (1, 0)], u)
        neck = track([(0, 0), (0.22, 22), (0.4, 4), (0.55, -18), (0.72, -28), (0.8, 18), (0.9, 6), (1, 0)], u)
        head = track([(0, 0), (0.22, 12), (0.4, -10), (0.55, -30), (0.72, -32), (0.8, 22), (0.9, 6), (1, 0)], u)
        trem = 2.5 * math.sin(2 * math.pi * 9 * u) * (1 if 0.25 <= u <= 0.55 else 0)  # head trembling on the hold
        jaw_deg = track([(0, 2), (0.15, 38), (0.3, 30), (0.42, 6), (0.72, 4), (0.8, 14), (1, 2)], u)
        body(fwd, drop, pitch)
        turn("Torso", SIDE, -pitch * 0.25)
        turn("Neck", SIDE, neck + trem)
        turn("Head", SIDE, head)
        jaw(jaw_deg)
        tail(track([(0, 0), (0.22, 12), (0.55, -2), (0.72, -14), (0.8, 6), (1, 0)], u), 0.0)
        arms(track([(0, 0), (0.22, -15), (0.72, 20), (1, 0)], u))
        # the bull's scrape: the right hind foot drags back twice during the hold, then plants
        scrape = 0.0
        for c in (0.3, 0.44):
            if c <= u <= c + 0.1:
                scrape = math.sin(math.pi * (u - c) / 0.1)
        r_off = -FWD * 0.04 * S * scrape + UP * 0.012 * S * max(0.0, math.sin(math.pi * scrape))
        # the drive: the left foot steps forward to carry the lunge, and back on the recovery
        step = track([(0, 0), (0.56, 0), (0.68, 1), (0.84, 1), (0.96, 0), (1, 0)], u)
        lift = math.sin(math.pi * min(1.0, max(0.0, (u - 0.56) / 0.12))) if u < 0.68 else \
            math.sin(math.pi * min(1.0, max(0.0, (u - 0.84) / 0.12))) if u < 0.96 else 0.0
        l_off = FWD * 0.08 * S * step + UP * 0.03 * S * lift
        feet = {"L": (l_off, 0.0), "R": (r_off, 10 * scrape)}
    elif CLIP == "charge_turn":  # airborne 0.2-0.6, turning to its left
        crouch = track([(0, 0), (0.2, 0.05), (0.28, 0.0), (0.6, 0.0), (0.72, 0.045), (1, 0)], u)
        rise = 0.025 * math.sin(math.pi * min(1.0, max(0.0, (u - 0.2) / 0.4))) if 0.2 <= u <= 0.6 else 0.0
        roll = track([(0, 0), (0.2, -6), (0.4, -18), (0.6, -10), (0.75, -6), (1, 0)], u)  # bank into a left turn
        pitch = track([(0, 0), (0.2, -6), (0.4, 4), (0.6, -2), (0.72, -6), (1, 0)], u)
        yaw = track([(0, 0), (0.2, 6), (0.45, 18), (0.6, 10), (1, 0)], u)  # the front leads the turn
        body(0.0, crouch - rise, pitch, roll=roll, yaw=yaw)
        turn("Neck", UP, track([(0, 0), (0.15, 16), (0.45, 26), (0.65, 10), (1, 0)], u))
        turn("Head", UP, track([(0, 0), (0.15, 10), (0.45, 14), (1, 0)], u))
        turn("Neck", SIDE, -pitch * 0.5)
        jaw(track([(0, 2), (0.2, 14), (0.6, 10), (0.75, 4), (1, 2)], u))
        tail(track([(0, 0), (0.2, 4), (0.45, 12), (0.7, 2), (1, 0)], u),
             track([(0, 0), (0.2, -10), (0.45, -48), (0.65, -30), (0.85, 8), (1, 0)], u))  # flung wide, then whips back
        arms(track([(0, 0), (0.3, -20), (0.7, -10), (1, 0)], u))
        a = math.sin(math.pi * min(1.0, max(0.0, (u - 0.2) / 0.4))) if 0.2 <= u <= 0.6 else 0.0
        heel = 22 * track([(0, 0), (0.2, 1), (0.28, 0), (0.6, 0), (0.72, 1), (1, 0)], u)
        feet = {sd: (UP * 0.09 * S * a + (FWD * 0.02 * S * a if sd == "L" else -FWD * 0.02 * S * a), heel) for sd in "LR"}
    elif CLIP == "alert":  # roar
        pitch = track([(0, 0), (0.2, 14), (0.35, 6), (0.8, 2), (1, 0)], u)
        neck = track([(0, 0), (0.2, 28), (0.35, -4), (0.8, -8), (1, 0)], u)
        head = track([(0, 0), (0.2, 14), (0.35, 4), (0.8, 2), (1, 0)], u)
        trem = 3.0 * math.sin(2 * math.pi * 11 * u) * (1 if 0.35 <= u <= 0.8 else 0)
        sweep = track([(0, 0), (0.35, 0), (0.55, 14), (0.75, -10), (0.9, 0), (1, 0)], u)
        body(track([(0, 0), (0.2, -0.02), (0.35, 0.02), (1, 0)], u), 0.0, pitch)
        turn("Torso", SIDE, -pitch * 0.2)
        turn("Neck", SIDE, neck + trem)
        turn("Neck", UP, sweep)
        turn("Head", SIDE, head)
        jaw(track([(0, 2), (0.2, 12), (0.35, 40), (0.8, 38), (0.92, 4), (1, 2)], u))
        tail(track([(0, 0), (0.2, 12), (0.4, 8), (0.8, 6), (1, 0)], u), -sweep * 0.5)
        arms(track([(0, 0), (0.2, -20), (0.4, 15), (1, 0)], u))
    elif CLIP == "idle":  # loop: breathing, a slow look around, the tail swaying (first frame == last)
        w = 2 * math.pi * u
        body(0.0, 0.003 * (0.5 - 0.5 * math.cos(2 * w)), 1.0 * math.sin(w))
        turn("Torso", SIDE, 0.8 * math.sin(2 * w))
        turn("Neck", SIDE, 3.0 * math.sin(w + 0.6))
        turn("Neck", UP, 9.0 * math.sin(w))
        turn("Head", UP, 5.0 * math.sin(w - 0.5))
        turn("Head", SIDE, 2.0 * math.sin(2 * w))
        jaw(2.0 * (0.5 - 0.5 * math.cos(2 * w)))
        tail(1.5 * math.sin(w), 6.0 * math.sin(w + 1.2))
        arms(4.0 * math.sin(2 * w))
    elif CLIP == "hit_react":  # recoil: the head jerks back and up, the body flinches away, then settles
        k = track([(0, 0), (0.18, 1), (0.45, 0.6), (1, 0)], u)
        body(-0.02 * k, 0.01 * k, 6 * k, roll=4 * k)
        turn("Neck", SIDE, 14 * k)
        turn("Neck", UP, -10 * k)
        turn("Head", SIDE, 8 * k)
        jaw(18 * k)
        tail(6 * k, 8 * k)
        arms(-15 * k)
    elif CLIP == "feed":  # loop: head down to the carcass, three tearing tugs with the jaws, chewing up high
        down = track([(0, 0), (0.15, 1), (0.75, 1), (0.9, 0), (1, 0)], u)
        tug = sum(math.sin(math.pi * min(1.0, max(0.0, (u - c) / 0.12))) for c in (0.22, 0.4, 0.58))
        body(0.01 * down, 0.02 * down, -12 * down + 3 * tug)
        turn("Torso", SIDE, -6 * down)
        turn("Neck", SIDE, -34 * down + 12 * tug)
        turn("Head", SIDE, -14 * down + 6 * tug)
        turn("Neck", UP, 6 * tug * (1 if int(u * 10) % 2 else -1))
        jaw(track([(0, 2), (0.15, 26), (0.22, 4), (0.3, 24), (0.4, 4), (0.48, 24), (0.58, 4), (0.75, 10), (1, 2)], u) + 8 * math.sin(2 * math.pi * 6 * u) * (1 if u > 0.75 else 0))
        tail(-10 * down, 4 * math.sin(2 * math.pi * u))
        arms(10 * down)
    plant(feet)


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
print(f"CARNO {CLIP} {N} frames at {FPS} fps ({N / FPS:.3f} s)")

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
