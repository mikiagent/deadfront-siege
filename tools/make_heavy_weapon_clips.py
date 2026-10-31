#!/usr/bin/env python3
"""PARTCOMBAT survivor clips for the heavy blades and the PRO-Class Bow (owner 2026-10-31), authored on the survivor rig.

Built the way make_knockdown_clips.py builds its clips: the legs, hips and breathing come from clips already on the rig
(idle / walk / run), the spine is bent and twisted by hand, and the arms are solved with IK so the hands sit on the
weapon: per key the right fist's grip point, the blade's direction and its edge are given in the body's frame (right,
forward, up from the shoulders), the right hand's bone frame is set from them (glTF RightHand: +X out of the thumb side =
the handle / blade axis, +Y wrist to fingers = the edge, the palm 0.11 m along Y, as HeldModel holds props), the wrist is
IK'd there, and on two-handed keys the left fist closes on the grip below it. The result is baked to plain bone keys.

  one-handed Iron Slab Blade (blade 1.61 m past the fist)
    wpn_1h_carry_idle/_walk/_run  loops: the tip dragged on the ground behind her right side
    wpn_1h_cross1 / cross2 / cross3  the cross-slash combo: high right to low left, back up, then a big overhead finisher
    wpn_1h_impale  draw back, thrust, hold, pull up and out, back to ready
    wpn_1h_chop    raise high, one hard downward chop
  two-handed Steel Greatblade (1.51 m past the right fist, the left fist 0.25 m below it)
    wpn_2h_carry_idle/_walk/_run  loops: dragged behind her (right hand)
    wpn_2h_slam    both hands lift it from the drag over her head and slam it straight down in front
    wpn_2h_sweep   a bat swing: wind up right, through the front, follow through left, swing back through the front
  PRO-Class Bow (left hand; the right hand draws)
    wpn_bow_carry_idle  the bow upright at her left side
    wpn_bow_draw   raise the bow arm to the target and draw to the cheek
    wpn_bow_aim    loop: held at full draw, breathing
    wpn_bow_release  the string hand flies back off the cheek, then both arms settle

  Blender -b --python tools/make_heavy_weapon_clips.py -- <survivor.glb> <anim dir> [out dir]
"""
import math, os, sys
import bpy
from mathutils import Matrix, Vector

a = sys.argv[sys.argv.index("--") + 1:]
BASE, ANIM = a[0], a[1]
OUT = a[2] if len(a) > 2 else ANIM
FPS = 30
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
PALM = 0.11, 0.03          # RightHand frame: the fist closes this far along +Y, this far out of the palm (+Z)
L1H, L2H = 1.61, 1.63      # blade past the right fist
LEFT_BELOW = 0.25          # the two-hander's left fist, down the grip from the right

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
pbs = arm.pose.bones
for pb in pbs:
    pb.rotation_mode = "QUATERNION"


def load(name):
    before, objs = set(bpy.data.actions), set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ANIM, name + ".glb"))
    act = next(iter(set(bpy.data.actions) - before))
    for o in set(bpy.data.objects) - objs:
        bpy.data.objects.remove(o)
    act.name = "src_" + name
    act.use_fake_user = True
    return act


SRC = {n: load(n) for n in ("idle", "walk", "run", "attack_primary")}


def length(name):
    f0, f1 = SRC[name].frame_range
    return (f1 - f0) / FPS


def sample(name, t, loop=True):
    act = SRC[name]
    arm.animation_data_create()
    arm.animation_data.action = act
    if len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    t = t % length(name) if loop else max(0.0, min(t, length(name)))
    f = act.frame_range[0] + t * FPS
    sc.frame_set(int(f), subframe=f - int(f))
    pose = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in pbs}
    arm.animation_data.action = None
    return pose


GRIP_FINGERS = sample("attack_primary", 0.5 * length("attack_primary"), False)  # its fist closes on a weapon


def body(r, f, u):
    """Right, forward, up in the body's frame -> armature space (the survivor faces -Y, her right is -X)."""
    return Vector((-r, -f, u))


def rot(name, axis, deg):
    pb = pbs[name]
    m = pb.matrix.copy()
    p = m.translation.copy()
    pb.matrix = Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p) @ m
    bpy.context.view_layer.update()


def empty(name):
    o = bpy.data.objects.new(name, None)
    sc.collection.objects.link(o)
    o.rotation_mode = "QUATERNION"
    return o


T = {s: (empty("wrist" + s), empty("rot" + s)) for s in ("R", "L")}
CONS = []
for s, side in (("R", "Right"), ("L", "Left")):
    ik = pbs[side + "ForeArm"].constraints.new("IK")
    ik.target = T[s][0]
    ik.chain_count = 2
    cr = pbs[side + "Hand"].constraints.new("COPY_ROTATION")
    cr.target = T[s][1]
    CONS.append((s, ik, cr))


def hand_frame(d, e, left=False):
    """Bone frame of a fist on a handle along d with the edge (fingers) toward e."""
    xa = (-d if left else d).normalized()
    ya = (e - xa * e.dot(xa)).normalized()
    za = xa.cross(ya)
    return Matrix((xa, ya, za)).transposed()


def shoulders():
    return (pbs["RightArm"].head + pbs["LeftArm"].head) * 0.5


def pose_frame(base, pitch, twist, right, left, fingers_r=True, fingers_l=False):
    """base pose, spine pitch (+ forward) / twist (+ to her left) in degrees; right / left: None (the base clip's arm)
    or (grip point, handle direction, edge direction) in armature space, computed by a callable from the posed chest."""
    for pb in pbs:
        pb.location, pb.rotation_quaternion = base[pb.name]
        if (fingers_r and pb.name.startswith("RightHand") and pb.name != "RightHand") or \
                (fingers_l and pb.name.startswith("LeftHand") and pb.name != "LeftHand"):
            pb.rotation_quaternion = GRIP_FINGERS[pb.name][1]
    bpy.context.view_layer.update()
    if twist:
        rot("Spine", Z, twist * 0.5)
        rot("Spine1", Z, twist * 0.5)
    if pitch:
        rot("Spine1", X, pitch * 0.5)  # about +X tips a body facing -Y forwards
        rot("Spine2", X, pitch * 0.5)
    c = shoulders()
    targets = {"R": right(c) if right else None, "L": left(c) if left else None}
    for s, ik, cr in CONS:
        tg = targets[s]
        ik.influence = cr.influence = 1.0 if tg else 0.0
        if tg:
            g, d, e = tg
            m = hand_frame(d, e, s == "L")
            palm = m @ Vector((0.0, PALM[0], PALM[1] if s == "R" else -PALM[1]))
            T[s][0].location = g - palm
            T[s][1].rotation_quaternion = m.to_quaternion()
    bpy.context.view_layer.update()
    # Bake: the solved arms back into plain local keys (constraints off).
    solved = {n: pbs[n].matrix.copy() for s in ("Right", "Left") for n in (s + "Arm", s + "ForeArm", s + "Hand")}
    for _, ik, cr in CONS:
        ik.mute = cr.mute = True
    bpy.context.view_layer.update()
    for s in ("Right", "Left"):
        for n in (s + "Arm", s + "ForeArm", s + "Hand"):
            pbs[n].matrix = solved[n]
            bpy.context.view_layer.update()
    pose = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in pbs}
    for _, ik, cr in CONS:
        ik.mute = cr.mute = False
    return pose


def bake(clip, seconds, fn):
    n = max(2, int(round(seconds * FPS)))
    poses = [fn(f / FPS) for f in range(n + 1)]
    act = bpy.data.actions.new(clip)
    arm.animation_data_create()
    arm.animation_data.action = act
    for _, ik, cr in CONS:
        ik.mute = cr.mute = True
    for f, pose in enumerate(poses):
        for pb in pbs:
            pb.location, pb.rotation_quaternion = pose[pb.name]
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
    sc.frame_start, sc.frame_end = 0, n
    for o in bpy.data.objects:
        o.hide_set(o is not arm)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    out = os.path.join(OUT, clip + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="ACTIVE_ACTIONS", export_force_sampling=True, export_yup=True)
    for o in bpy.data.objects:
        o.hide_set(False)
    arm.animation_data.action = None
    bpy.data.actions.remove(act)
    for _, ik, cr in CONS:
        ik.mute = cr.mute = False
    print(f"CLIP {clip} {n + 1} frames {n / FPS:.2f} s -> {out}")


def smooth(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3.0 - 2.0 * u)


def keyed(keys, t):
    """keys: [(t, value tuple)] -> value at t, smoothstepped between keys (each component)."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            w = smooth((t - t0) / max(1e-6, t1 - t0))
            return tuple(x + (y - x) * w for x, y in zip(v0, v1))
    return keys[-1][1]


# --- the drag carry ------------------------------------------------------------------------------------------------
def drag(blade_len, out=0.18):
    """The right fist low at her right side, a little back; the blade runs back and down to a tip on the ground."""
    def right(c):
        g = c + body(0.24, -0.1, -0.5)
        g_world = arm.matrix_world @ g
        drop = max(0.05, g_world.z - 0.04)
        horiz = math.sqrt(max(0.0, blade_len ** 2 - drop ** 2))
        d = body(out, -1.0, 0.0).normalized() * horiz + Vector((0, 0, -drop))
        return g, d.normalized(), Vector((0, 0, -1))
    return right


def carry(clip, src, blade_len):
    bake(clip, length(src), lambda t: pose_frame(sample(src, t), 0.0, 0.0, drag(blade_len), None))


# --- keyed weapon moves --------------------------------------------------------------------------------------------
# Each key: (t, (grip r, f, u from the shoulders), (handle dir r, f, u), (edge hint r, f, u), pitch, twist)
def move(clip, seconds, keys, blade_len, two_hands=False, carry_ends=True):
    def right_at(t):
        def right(c):
            if carry_ends and (t <= keys[0][0] or t >= keys[-1][0]):
                return drag(blade_len)(c)
            g = keyed([(k[0], k[1]) for k in keys], t)
            d = keyed([(k[0], k[2]) for k in keys], t)
            e = keyed([(k[0], k[3]) for k in keys], t)
            return c + body(*g), body(*d).normalized(), body(*e)
        return right

    def left_at(t):
        if not two_hands or (carry_ends and (t <= keys[0][0] or t >= keys[-1][0])):
            return None

        def left(c):
            g, d, e = right_at(t)(c)
            return g - d * LEFT_BELOW, d, e
        return left

    def frame(t):
        pitch = keyed([(k[0], (k[4],)) for k in keys], t)[0]
        twist = keyed([(k[0], (k[5],)) for k in keys], t)[0]
        return pose_frame(sample("idle", t), pitch, twist, right_at(t), left_at(t), True, two_hands)
    bake(clip, seconds, frame)


def drag_key(t, blade_len):
    """A key matching the drag pose (so a move leaves and returns to the carry without a pop)."""
    g = (0.24, -0.1, -0.5)
    drop = 1.435 - 0.5 - 0.04
    horiz = math.sqrt(max(0.0, blade_len ** 2 - drop ** 2))
    d = (0.18 * horiz, -horiz, -drop)
    return (t, g, d, (0, 0, -1), 0.0, 0.0)


# One-handed slab: the cross-slash combo, the impale, the chop.
for src, clip in (("idle", "wpn_1h_carry_idle"), ("walk", "wpn_1h_carry_walk"), ("run", "wpn_1h_carry_run")):
    carry(clip, src, L1H)
for src, clip in (("idle", "wpn_2h_carry_idle"), ("walk", "wpn_2h_carry_walk"), ("run", "wpn_2h_carry_run")):
    carry(clip, src, L2H)

move("wpn_1h_cross1", 0.8, [
    drag_key(0.0, L1H),
    (0.18, (0.32, 0.1, 0.1), (0.4, -0.1, 0.9), (0.6, 0.6, 0), 0, -25),       # wound up high on the right
    (0.36, (0.0, 0.42, -0.15), (-0.5, 0.75, -0.35), (-0.5, 0.2, -0.8), 12, 5),  # the cut through the front
    (0.5, (-0.25, 0.3, -0.45), (-0.75, 0.25, -0.6), (-0.4, -0.3, -0.8), 18, 25),  # low on her left
    (0.8, (-0.2, 0.32, -0.35), (-0.6, 0.6, -0.4), (0, 0, -1), 10, 15),
], L1H, carry_ends=False)
move("wpn_1h_cross2", 0.8, [
    (0.0, (-0.2, 0.32, -0.35), (-0.6, 0.6, -0.4), (0, 0, -1), 10, 15),
    (0.12, (-0.25, 0.3, -0.45), (-0.75, 0.25, -0.6), (0.6, 0.3, 0.4), 15, 25),
    (0.34, (0.0, 0.42, 0.0), (0.55, 0.8, 0.25), (0.5, 0.1, 0.8), 5, 0),         # back across, rising
    (0.55, (0.3, 0.15, 0.15), (0.45, 0.0, 0.9), (0.5, -0.5, 0.6), -5, -25),     # high on the right
    (0.8, (0.3, 0.15, 0.1), (0.4, -0.1, 0.9), (0.6, 0.6, 0), -5, -25),
], L1H, carry_ends=False)
move("wpn_1h_cross3", 1.2, [
    (0.0, (0.3, 0.15, 0.1), (0.4, -0.1, 0.9), (0.6, 0.6, 0), -5, -25),
    (0.32, (0.1, 0.0, 0.32), (0.2, -0.65, 0.75), (0, 1, 0), -15, -15),          # up over her head, blade behind
    (0.58, (0.02, 0.45, -0.2), (-0.35, 0.8, -0.5), (0, 0.3, -1), 25, 10),       # the finisher, through the front
    (0.78, (-0.2, 0.3, -0.5), (-0.5, 0.35, -0.8), (0, 0, -1), 25, 20),
    (0.92, (-0.2, 0.3, -0.5), (-0.5, 0.35, -0.8), (0, 0, -1), 20, 15),
    drag_key(1.2, L1H),
], L1H)
move("wpn_1h_impale", 1.3, [
    drag_key(0.0, L1H),
    (0.25, (0.25, -0.12, -0.25), (0.0, 1.0, 0.05), (0, 0, -1), -5, -15),        # drawn back, point forward
    (0.45, (0.1, 0.52, -0.25), (-0.05, 1.0, 0.0), (0, 0, -1), 18, 5),           # the thrust
    (0.7, (0.1, 0.5, -0.25), (-0.05, 1.0, 0.0), (0, 0, -1), 18, 5),             # driven in
    (0.95, (0.15, 0.3, 0.2), (0.0, 0.6, 0.8), (0, 1, 0), 0, 0),                 # pulled up and out
    (1.1, (0.2, 0.25, -0.2), (0.1, 0.6, 0.8), (0, 1, 0), 0, -5),                # ready
    drag_key(1.3, L1H),
], L1H)
move("wpn_1h_chop", 1.0, [
    drag_key(0.0, L1H),
    (0.32, (0.15, 0.05, 0.38), (0.0, -0.45, 0.9), (0, 1, 0), -12, -5),          # raised high
    (0.52, (0.08, 0.45, -0.3), (0.0, 0.75, -0.66), (0, 0.6, -0.8), 25, 0),      # chopped down
    (0.7, (0.08, 0.42, -0.35), (0.0, 0.7, -0.7), (0, 0.6, -0.8), 25, 0),
    drag_key(1.0, L1H),
], L1H)

# Two-handed greatblade: the overhead slam and the bat sweep and back.
move("wpn_2h_slam", 1.7, [
    drag_key(0.0, L2H),
    (0.35, (0.05, 0.4, -0.2), (0.0, 0.3, 0.95), (0, 1, 0), 0, 0),               # lifted in front
    (0.72, (0.0, 0.05, 0.42), (0.0, -0.75, 0.3), (0, 0, 1), -18, 0),            # over her head, blade hanging back
    (0.95, (0.0, 0.45, -0.3), (0.0, 0.85, -0.52), (0, 0.5, -0.85), 30, 0),      # slammed down onto the target
    (1.25, (0.0, 0.43, -0.35), (0.0, 0.8, -0.6), (0, 0.5, -0.85), 30, 0),       # held in the ground
    drag_key(1.7, L2H),
], L2H, two_hands=True)
move("wpn_2h_sweep", 2.2, [
    drag_key(0.0, L2H),
    (0.4, (0.35, -0.05, -0.05), (0.35, -0.9, 0.2), (0.2, 0.0, 1.0), 0, -40),    # wound up over the right shoulder
    (0.58, (0.35, 0.2, -0.2), (0.95, 0.25, 0.0), (0, 1, 0), 0, -25),            # coming round her right
    (0.75, (0.0, 0.42, -0.25), (0.15, 0.98, 0.0), (-1, 0, 0), 5, 0),            # through the front
    (0.95, (-0.32, 0.25, -0.2), (-0.95, 0.3, 0.05), (0, -1, 0), 5, 35),         # followed through to the left
    (1.2, (-0.32, 0.2, -0.2), (-0.95, 0.15, 0.05), (0, -1, 0), 0, 35),
    (1.5, (0.0, 0.42, -0.25), (-0.15, 0.98, 0.0), (1, 0, 0), 5, 0),             # swung back through the front
    (1.7, (0.32, 0.25, -0.2), (0.95, 0.3, 0.0), (0, 1, 0), 0, -30),
    drag_key(2.2, L2H),
], L2H, two_hands=True)


# --- PRO-Class Bow -------------------------------------------------------------------------------------------------
def bow_hold(c):
    """Bow arm out to the target at shoulder height, the bow upright (its handle axis up), fingers wrapping forward."""
    return c + body(-0.28, 0.42, -0.02), body(0.05, 0.0, 1.0).normalized(), body(0.3, 1.0, 0.0)


def bow_side(c):
    return c + body(-0.24, 0.02, -0.5), body(0, 0.1, 1.0).normalized(), body(0, 1.0, 0)


def draw_hand(k):
    """The string hand from the bow grip (k = 0) back to the cheek (k = 1)."""
    def right(c):
        g = c + body(-0.2 + 0.25 * k, 0.4 - 0.42 * k, 0.0 + 0.12 * k)
        return g, body(0, 0, 1).normalized(), body(-0.3, 1.0, 0.0)
    return right


def mix_left(f0, f1, w):
    def left(c):
        a0, b0, e0 = f0(c)
        a1, b1, e1 = f1(c)
        return a0.lerp(a1, w), b0.lerp(b1, w).normalized(), e0.lerp(e1, w)
    return left


TW = 45  # the shoulders turn side-on to the target


bake("wpn_bow_carry_idle", length("idle"), lambda t: pose_frame(sample("idle", t), 0, 0, None, bow_side, False, True))
bake("wpn_bow_draw", 0.6, lambda t: pose_frame(sample("idle", t), 0, TW * smooth(t / 0.3),
                                                 draw_hand(smooth((t - 0.2) / 0.4)) if t > 0.2 else None,
                                                 mix_left(bow_side, bow_hold, smooth(t / 0.3)), True, True))
bake("wpn_bow_aim", 1.0, lambda t: pose_frame(sample("idle", t), 1.5 * math.sin(2 * math.pi * t), TW,
                                                draw_hand(1.0), bow_hold, True, True))
bake("wpn_bow_release", 0.6, lambda t: pose_frame(sample("idle", t), 0, TW * (1.0 - smooth((t - 0.3) / 0.3)),
                                                    draw_hand(1.0 + 0.35 * smooth(t / 0.12) - 1.35 * smooth((t - 0.25) / 0.35)),
                                                    mix_left(bow_hold, bow_side, smooth((t - 0.3) / 0.3)), True, True))
