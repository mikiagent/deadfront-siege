#!/usr/bin/env python3
"""Author the survivor's state idles from its own idle: idle_cold (hunched, arms hugged, shivering), idle_heat
(fanning the face, other hand on the hip), idle_tired (slumped, slow sway) and idle_exhausted (bent over, hands
on knees, heavy breathing). Each is the idle loop with layered body offsets and IK hands, baked to plain keys,
the same length and fps as the idle so it loops and swaps in for it. Skeleton-only export like the other clips.

  Blender -b --python tools/make_state_idles.py -- <survivor.glb> <idle.glb> <out_dir> [--only idle_cold ...]

Rig: Mixamo names, facing -Y in Blender (glTF +Z). World axes: +X about = bend forward, Y = roll, Z = yaw.
"""
import argparse, json, math, os, struct, sys
import bpy
from mathutils import Matrix, Vector

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("idle"); ap.add_argument("out_dir")
ap.add_argument("--only", nargs="*", default=[])
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

b = open(a.idle, "rb").read(); n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + n])
acc = max((j["accessors"][s["input"]] for s in j["animations"][0]["samplers"]), key=lambda x: x["count"])
FPS = round((acc["count"] - 1) / max(acc["max"][0] - acc["min"][0], 1e-6))

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
FWD = Vector((0, -1, 0))
TAU = 2 * math.pi


def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.ops.import_scene.gltf(filepath=a.base)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in [o for o in bpy.data.objects if o is not arm]: bpy.data.objects.remove(o)
    before = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=a.idle)
    src = next(iter(set(bpy.data.actions) - acts))
    for o in set(bpy.data.objects) - before: bpy.data.objects.remove(o)
    arm.animation_data_create(); arm.animation_data.action = src
    if len(src.slots): arm.animation_data.action_slot = src.slots[0]
    return arm, src


def rot(arm, name, axis, deg):
    pb = arm.pose.bones[name]
    m = pb.matrix.copy(); piv = m.translation.copy()
    pb.matrix = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-piv) @ m
    bpy.context.view_layer.update()


def move(arm, name, d):
    pb = arm.pose.bones[name]
    pb.matrix = Matrix.Translation(d) @ pb.matrix
    bpy.context.view_layer.update()


def head(arm, name): return arm.matrix_world @ arm.pose.bones[name].head
def wave(t, cycles, phase=0.0): return math.sin(TAU * (cycles * t + phase))


# Each state: body(arm, t) poses the FK offsets on top of the idle; hands(arm, t) returns IK targets
# {side: (wrist, pole)} measured on that pose; legs pins feet where they stand (for poses that move the hips).
def cold_body(arm, t):
    for s, sg in (("Left", -1), ("Right", 1)):
        rot(arm, f"{s}Shoulder", Y, sg * 12)                     # shoulders up to the ears
    rot(arm, "Spine1", X, 6); rot(arm, "Spine2", X, 6)
    rot(arm, "Neck", X, 8); rot(arm, "Head", X, 4)
    shiver = 1.4 * wave(t, 24) + 0.6 * wave(t, 37, 0.3)        # fast, uneven tremor (integer cycles: loops)
    rot(arm, "Spine2", Y, shiver); rot(arm, "Head", Z, 0.8 * wave(t, 29, 0.1))


def cold_hands(arm, t):
    out = {}
    for s, o, sg in (("Left", "Right", 1), ("Right", "Left", -1)):
        up = head(arm, f"{o}Arm").lerp(head(arm, f"{o}ForeArm"), 0.45)  # grip the other upper arm
        tremor = 0.004 * wave(t, 24, 0.25 if s == "Left" else 0.6)
        wrist = up + FWD * 0.07 + Vector((sg * 0.05, 0, (-0.03 if s == "Left" else 0.01) + tremor))
        out[s] = (wrist, head(arm, f"{s}Arm") + Vector((sg * 0.25, -0.15, -0.35)))
    return out


def heat_body(arm, t):
    rot(arm, "Spine2", X, -3 + 1.5 * wave(t, 2))               # upright, slow deep breaths
    rot(arm, "Neck", X, -6); rot(arm, "Head", X, -4)            # chin up, face to the air
    rot(arm, "Head", Y, 3 * wave(t, 1))


def heat_hands(arm, t):
    face = head(arm, "Head") + FWD * 0.24 + Vector((-0.15, 0, 0.0))  # an arm's length short of the face
    fan = Vector((0.07 * wave(t, 10), 0, 0.02 * wave(t, 10, 0.25)))  # 2.5 waves a second
    hip = head(arm, "LeftUpLeg") + Vector((0.09, 0.02, 0.1))
    return {"Right": (face + fan, head(arm, "RightArm") + Vector((-0.4, 0.1, -0.3))),
            "Left": (hip, head(arm, "LeftArm") + Vector((0.5, 0.3, -0.2)))}


def heat_after(arm, t):
    for pb in arm.pose.bones:  # open, flat hand to fan with (the rest pose's straight fingers)
        if pb.name.startswith("RightHand") and pb.name != "RightHand": pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    rot(arm, "RightHand", Z, 30 * wave(t, 10, 0.1))             # the fanning flick
    rot(arm, "RightHand", X, -25)                               # palm toward the face


def relax_fingers(arm, side, k):
    """Fingers k of the way from the idle's fist to the rest pose's open hand: a hand hanging heavy, not clenched."""
    for pb in arm.pose.bones:
        if pb.name.startswith(side + "Hand") and pb.name != side + "Hand":
            q = pb.matrix_basis.to_quaternion().slerp(Matrix.Identity(4).to_quaternion(), k)
            pb.matrix_basis = Matrix.Translation(pb.matrix_basis.translation) @ q.to_matrix().to_4x4()
    bpy.context.view_layer.update()


# Tired (rebuilt 2026-10-28, owner: "looks horrible"): the first pass hung the head 34 deg (chin on the chest,
# the neck jutting forward in profile), pressed the fists into the thighs and rolled the pelvis without moving
# the feet, so the feet slid and dipped 1 cm. Now: a modest slump with the face still readable, slow deep
# breaths that lift chest and shoulders, weight shifting foot to foot with the feet planted (leg IK), loose hands.
def tired_body(arm, t):
    breath = wave(t, 2)                                         # two slow, deep breaths per 4 s loop
    sway = wave(t, 1)                                           # weight onto one foot, then the other
    move(arm, "Hips", Vector((0.03 * sway, 0, -0.02)))          # knees soft, hips over the loaded foot
    rot(arm, "Hips", Y, 1.5 * sway)                             # the unloaded hip drops
    rot(arm, "Spine", Y, -1.2 * sway); rot(arm, "Spine1", Y, -1.0 * sway)  # torso stays over the hips
    rot(arm, "Spine", X, 3); rot(arm, "Spine1", X, 3 - 0.8 * breath)
    rot(arm, "Spine2", X, 4 - 2.0 * breath)                     # inhale lifts the chest out of the slump
    for s, sg in (("Left", 1), ("Right", -1)):
        rot(arm, f"{s}Shoulder", Y, sg * (5 - 2.5 * breath))    # shoulders low, they rise on the inhale
        rot(arm, f"{s}Arm", Y, sg * 3)                          # arms hang closer, heavy
    rot(arm, "Neck", X, 5); rot(arm, "Head", X, 6 + 2 * wave(t, 1, 0.3))
    rot(arm, "Head", Y, 2.5 * wave(t, 1, 0.15))                 # head tips with the weight shift


def tired_after(arm, t):
    relax_fingers(arm, "Left", 0.55); relax_fingers(arm, "Right", 0.55)


# Exhausted (fixed 2026-10-28): the legs were pinned with an IK pole that flipped the shins half a turn
# (ankle twist 175 deg, thigh twist 176 deg: wrung skin at the ankles) and the fists pressed into the groin.
# Now the leg IK has no pole, so the knees bend the way they already bend, and open hands rest on the thighs.
def exhausted_body(arm, t):
    breath = wave(t, 3)                                         # fast, heaving breaths
    move(arm, "Hips", Vector((0, 0.12, -0.13)))                 # sit back over the heels, knees bent
    rot(arm, "Hips", X, 32)                                     # bend from the hips far enough that the hands reach the knees
    rot(arm, "Spine", X, 12 + 1.5 * breath); rot(arm, "Spine1", X, 10 + 1.5 * breath); rot(arm, "Spine2", X, 6 + 2.5 * breath)
    for s, sg in (("Left", -1), ("Right", 1)):
        rot(arm, f"{s}Shoulder", Y, sg * 4 * (0.5 + 0.5 * breath))  # shoulders heave
    rot(arm, "Neck", X, -24); rot(arm, "Head", X, -18 + 2 * breath)  # head up, eyes ahead


def palm_down(arm, side):
    """Roll the forearm and hand (half each) about the hand's length so the palm (hand local +Z on this rig)
    faces down onto the knee. The arm IK leaves the left palm turned up and out, the right one down."""
    m = (arm.matrix_world @ arm.pose.bones[f"{side}Hand"].matrix).to_3x3()
    along, palm = m.col[1].normalized(), m.col[2].normalized()
    want = Vector((0, 0.3, -1)) - along * along.dot(Vector((0, 0.3, -1)))
    ang = math.degrees(palm.angle(want.normalized()))
    if palm.cross(want).dot(along) < 0: ang = -ang
    print(f"PALM {side} {ang:.0f}")
    fa = (arm.matrix_world @ arm.pose.bones[f"{side}ForeArm"].matrix).to_3x3().col[1].normalized()
    rot(arm, f"{side}ForeArm", fa, ang / 2); rot(arm, f"{side}Hand", along, ang / 2)


def exhausted_after(arm, t):
    relax_fingers(arm, "Left", 0.85); relax_fingers(arm, "Right", 0.85)
    palm_down(arm, "Left"); palm_down(arm, "Right")
    rot(arm, "LeftHand", X, 35); rot(arm, "RightHand", X, 35)  # fingers drape down over the knee


def exhausted_hands(arm, t):
    out = {}
    for s, sg in (("Left", 1), ("Right", -1)):
        knee = head(arm, f"{s}Leg")
        # wrist over the front of the thigh a hand's length above the knee: the palm rests on the thigh
        out[s] = (knee + FWD * 0.035 + Vector((sg * 0.02, 0, 0.15)), head(arm, f"{s}Arm") + Vector((sg * 0.2, 0.45, -0.15)))  # elbows bend back, a bracing arm
    return out


STATES = {
    "idle_cold": dict(body=cold_body, hands=cold_hands),
    "idle_heat": dict(body=heat_body, hands=heat_hands, after=heat_after),
    "idle_tired": dict(body=tired_body, after=tired_after, pin_feet=True),
    "idle_exhausted": dict(body=exhausted_body, hands=exhausted_hands, after=exhausted_after, pin_feet=True),
}


def ik(arm, bone, target, pole, chain=2):
    c = arm.pose.bones[bone].constraints.new("IK")
    c.target = target; c.pole_target = pole; c.chain_count = chain; c.pole_angle = math.radians(-90)
    return c


def empty(name):
    e = bpy.data.objects.new(name, None); bpy.context.scene.collection.objects.link(e); return e


os.makedirs(a.out_dir, exist_ok=True)
for name, st in STATES.items():
    if a.only and name not in a.only: continue
    arm, src = load()
    f0, f1 = (int(round(x)) for x in src.frame_range)
    N = f1 - f0
    sc = bpy.context.scene
    # 1. FK pass: the idle plus this state's body offsets, keyed
    poses = []; feet_f = []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        poses.append({pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones})
        feet_f.append({s: (head(arm, f"{s}Foot"), arm.pose.bones[f"{s}Foot"].matrix.copy()) for s in ("Left", "Right")})
    fk = bpy.data.actions.new(name + "_fk"); arm.animation_data.action = fk
    for i, f in enumerate(range(f0, f1 + 1)):
        t = (i % N) / N  # last frame == first: seamless loop
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"; pb.matrix_basis = poses[i % N][pb.name]
        bpy.context.view_layer.update()
        st["body"](arm, t)
        for pb in arm.pose.bones:
            pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)

    def bake():
        bpy.context.view_layer.objects.active = arm; arm.select_set(True)
        bpy.ops.object.mode_set(mode="POSE")
        bpy.ops.pose.select_all(action="SELECT")
        bpy.ops.nla.bake(frame_start=f0, frame_end=f1, only_selected=False, visual_keying=True,
                         clear_constraints=True, use_current_action=False, bake_types={"POSE"})
        bpy.ops.object.mode_set(mode="OBJECT")

    def rekey(fn):
        for i, f in enumerate(range(f0, f1 + 1)):
            sc.frame_set(f); fn(i)
            for pb in arm.pose.bones:
                pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)

    # 2. Planted feet first (leg IK to the idle's own foot positions, then the idle's foot rotation), so the
    # hand targets below are measured where the knees really end up (measuring them before the legs were
    # pinned put exhausted's hands 12 cm behind the knees, reaching back past the thighs).
    if st.get("pin_feet"):
        feet_e = {}; knee_e = {}
        for s in ("Left", "Right"):
            # no pole: the knee keeps bending the way the idle bends it (a pole flipped the shins 175 deg)
            fe = feet_e[s] = empty(f"{s}_foot"); kp = knee_e[s] = empty(f"{s}_knee")
            c = arm.pose.bones[f"{s}Leg"].constraints.new("IK"); c.target = fe; c.chain_count = 2
            c.pole_target = kp; c.pole_angle = math.radians(90)  # this rig's leg roll: -90 flips the shin 180 deg, 0 and 180 twist it 80-110 deg
        for i, f in enumerate(range(f0, f1 + 1)):
            sc.frame_set(f)
            for s, fe in feet_e.items():
                fe.location = feet_f[i % N][s][0]; fe.keyframe_insert("location", frame=f)
                # knee aims straight ahead of the hip, over the foot (no pole let the knees cave inward)
                kp = knee_e[s]; hp = head(arm, f"{s}UpLeg")
                kp.location = Vector((hp.x, hp.y, 0)) * 0.5 + Vector((fe.location.x, fe.location.y, 0)) * 0.5 + FWD * 0.8 + Vector((0, 0, 0.5))
                kp.keyframe_insert("location", frame=f)
        bake()

        def feet_rot(i):
            for s in ("Left", "Right"):
                pb = arm.pose.bones[f"{s}Foot"]; m = feet_f[i % N][s][1].copy(); m.translation = pb.matrix.translation
                pb.matrix = m; bpy.context.view_layer.update()
        rekey(feet_rot)
    # 3. IK hands toward targets measured on that pose
    if "hands" in st:
        targets = []
        for i, f in enumerate(range(f0, f1 + 1)):
            sc.frame_set(f); targets.append(st["hands"](arm, (i % N) / N))
        emp = {}
        for s in targets[0]:
            emp[s] = (empty(f"{s}_wrist"), empty(f"{s}_pole"))
            ik(arm, f"{s}ForeArm", *emp[s])
        for i, f in enumerate(range(f0, f1 + 1)):
            for s, (w, p) in emp.items():
                w.location, p.location = targets[i][s]
                w.keyframe_insert("location", frame=f); p.keyframe_insert("location", frame=f)
        bake()
    if "after" in st:  # hand flicks and finger poses on the final pose
        rekey(lambda i: st["after"](arm, (i % N) / N))
    baked = arm.animation_data.action
    baked.name = name
    for o in [o for o in bpy.data.objects if o.type == "EMPTY"]: bpy.data.objects.remove(o)
    for act in [x for x in bpy.data.actions if x is not baked]: bpy.data.actions.remove(act)
    sc.frame_start, sc.frame_end = f0, f1
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(a.out_dir, name + ".glb"), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_yup=True)
    print(f"STATE {name}: {N + 1} frames at {FPS} fps")
