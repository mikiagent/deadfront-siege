#!/usr/bin/env python3
"""Author the survivor's heavy-hit clips (KNOCKDOWN, owner 2026-10-31: "the player should get thrown around and have a
falling on his butt animation, wind knocked out of him"). Built from clips already on the rig, the way
make_pinned.py builds `pinned`: key poses sampled from knockdown.glb, sleep_up.glb (KayKit Lie_StandUp, whose lying
pose matches the knockdown's last frame) and idle_exhausted.glb, blended per bone (slerp) with small procedural layers.

  fall_back  one-shot 1.3 s: staggers back off the hit, lands on the butt (sleep_up's seated frame), the chest folds
             forward (winded), then rolls flat onto the back (the knockdown's lying pose)
  airborne   loop 1 s: the knockdown's mid-air frame, arms and legs flailing (PlayerKnock plays it on the throw arc)
  lie        loop 2 s: flat on the back, chest heaving for breath, head lifting
  get_up     one-shot: blends from the lying pose into sleep_up, played 1.25x (a scramble, not waking up)
  winded     loop 2 s: hands on knees (idle_exhausted at double rate) with a deeper, faster heave

No foot or body goes through the floor: every frame the skinned mesh is evaluated and the hips raised until the lowest
vertex is at FLOOR; frames marked `contact` (seated, lying, standing) are also lowered onto it, so nothing floats.

  Blender -b --python tools/make_knockdown_clips.py -- <survivor.glb> <anim dir> [out dir]
"""
import math, os, sys
import bpy
from mathutils import Matrix, Vector

a = sys.argv[sys.argv.index("--") + 1:]
BASE, ANIM = a[0], a[1]
OUT = a[2] if len(a) > 2 else ANIM
FPS = 24
FLOOR = 0.015
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
TAU = 2 * math.pi

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
skin = [o for o in bpy.data.objects if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)]
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
    return act


SRC = {n: load(n) for n in ("knockdown", "sleep_up", "idle_exhausted")}


def length(name):
    f0, f1 = SRC[name].frame_range
    return (f1 - f0) / FPS


def sample(name, t):
    """Local pose (loc, quat) of every bone, `name` at t seconds (clamped)."""
    act = SRC[name]
    arm.animation_data_create()
    arm.animation_data.action = act
    if len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    f = act.frame_range[0] + max(0.0, min(t, length(name))) * FPS
    sc.frame_set(int(f), subframe=f - int(f))
    return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in pbs}


def mix(p, q, w):
    w = max(0.0, min(1.0, w))
    return {n: (p[n][0].lerp(q[n][0], w), p[n][1].slerp(q[n][1], w)) for n in p}


def smooth(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3.0 - 2.0 * u)


def rot(name, axis, deg):
    """Turn a bone (and its children) about an armature-space axis through its head."""
    pb = pbs[name]
    m = pb.matrix.copy()
    p = m.translation.copy()
    pb.matrix = Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p) @ m
    bpy.context.view_layer.update()


def lowest():
    dg = bpy.context.evaluated_depsgraph_get()
    return min((o.matrix_world @ v.co).z for o in skin for v in o.evaluated_get(dg).data.vertices)


def ground(contact):
    low = lowest()
    if low < FLOOR or contact:
        pb = pbs["Hips"]
        m = pb.matrix.copy()
        m.translation.z += (FLOOR - low) / arm.scale.z
        pb.matrix = m
        bpy.context.view_layer.update()
    return lowest()


def bake(clip, n_frames, pose_fn):
    """pose_fn(f, t) -> (pose dict, layer callable or None, contact bool). Keys every bone, exports <clip>.glb."""
    arm.animation_data.action = None
    poses = [pose_fn(f, f / FPS) for f in range(n_frames + 1)]
    act = bpy.data.actions.new(clip)
    arm.animation_data.action = act
    lows = []
    for f, (pose, layer, contact) in enumerate(poses):
        for pb in pbs:
            pb.location, pb.rotation_quaternion = pose[pb.name]
        bpy.context.view_layer.update()
        if layer:
            layer(f / FPS)
        lows.append(ground(contact))
        for pb in pbs:
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
    for o in [o for o in bpy.data.objects if o is not arm]:
        o.hide_set(True)
    for x in [x for x in bpy.data.actions if x is not act and not x.name.startswith("src_")]:
        bpy.data.actions.remove(x)
    sc.frame_start, sc.frame_end = 0, n_frames
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    # Only this clip's action may be in the file: stash the sources off the armature while exporting.
    keep = {k: v for k, v in SRC.items()}
    for v in keep.values():
        v.use_fake_user = True
    out = os.path.join(OUT, clip + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="ACTIVE_ACTIONS", export_force_sampling=True, export_yup=True)
    for o in bpy.data.objects:
        o.hide_set(False)
    print(f"CLIP {clip} {n_frames + 1} frames {n_frames / FPS:.2f} s lowest vertex min {min(lows):.3f} max {max(lows):.3f} -> {out}")


KD_AIR = 0.27     # s into knockdown: off the ground, flung back, arms up
SEAT = 0.68       # s into sleep_up: seated on the butt, hands behind (PlayerAnim.STAND_FROM)
KD_END = length("knockdown")
LIE = sample("knockdown", KD_END)
SIT = sample("sleep_up", SEAT)
UP0 = sample("sleep_up", 0.0)


# fall_back -----------------------------------------------------------------------------------------------------
def fall_back(f, t):
    if t <= 0.30:
        return sample("knockdown", t), None, False
    if t <= 0.46:  # drop onto the butt
        return mix(sample("knockdown", 0.30), SIT, smooth((t - 0.30) / 0.16)), None, t > 0.40
    if t <= 0.78:  # sat down hard: the chest folds over the stomach (the wind knocked out), then sags back
        fold = math.sin(math.pi * (t - 0.46) / 0.32)

        def layer(_t, k=fold):
            rot("Spine1", X, 28.0 * k)
            rot("Neck", X, 20.0 * k)
        return SIT, layer, True
    if t <= 1.12:  # rolls flat onto the back
        return mix(SIT, LIE, smooth((t - 0.78) / 0.34)), None, True
    return LIE, None, True


# airborne ------------------------------------------------------------------------------------------------------
AIR = sample("knockdown", KD_AIR)


def airborne(f, t):
    u = t / 1.0

    def layer(_t):
        for s, sx, ph in (("Left", 1.0, 0.0), ("Right", -1.0, 0.5)):
            rot(s + "Arm", Y, 28.0 * sx * math.sin(TAU * (2 * u + ph)))   # arms windmill
            rot(s + "UpLeg", X, 18.0 * math.sin(TAU * (2 * u + ph)))     # legs kick
            rot(s + "Leg", X, -14.0 * (0.5 + 0.5 * math.sin(TAU * (2 * u + ph + 0.25))))
        rot("Spine1", X, -6.0 * math.sin(TAU * u))
    return AIR, layer, False


# lie -----------------------------------------------------------------------------------------------------------
def lie(f, t):
    u = t / 2.0

    def layer(_t):
        heave = 0.5 - 0.5 * math.cos(TAU * 3 * u)  # three gasps in 2 s
        rot("Spine2", X, -11.0 * heave)
        rot("Neck", X, -10.0 * (0.5 - 0.5 * math.cos(TAU * u)))
        rot("Head", Z, 10.0 * math.sin(TAU * u))
    return LIE, layer, True


# get_up --------------------------------------------------------------------------------------------------------
GET_UP_SPEED = 1.25
BLEND_IN = 0.2


def get_up(f, t):
    if t <= BLEND_IN:
        return mix(LIE, UP0, smooth(t / BLEND_IN)), None, True
    return sample("sleep_up", (t - BLEND_IN) * GET_UP_SPEED), None, True


# winded --------------------------------------------------------------------------------------------------------
def winded(f, t):
    u = t / 2.0
    pose = sample("idle_exhausted", (2.0 * t) % length("idle_exhausted"))

    def layer(_t):
        heave = 0.5 - 0.5 * math.cos(TAU * 2 * u)  # a breath a second, deep
        rot("Spine1", X, 5.0 * heave)
        rot("Spine2", X, -9.0 * heave)
        rot("LeftShoulder", Y, 5.0 * heave)
        rot("RightShoulder", Y, -5.0 * heave)
        rot("Neck", X, 6.0 * heave)
    return pose, layer, True


bake("fall_back", int(round(1.30 * FPS)), fall_back)
bake("airborne", FPS, airborne)
bake("lie", 2 * FPS, lie)
bake("get_up", int(round((BLEND_IN + length("sleep_up") / GET_UP_SPEED) * FPS)), get_up)
bake("winded", 2 * FPS, winded)
