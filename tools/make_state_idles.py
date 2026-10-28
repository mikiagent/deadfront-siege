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


def tired_body(arm, t):
    rot(arm, "Hips", Y, 2.5 * wave(t, 1))                       # slow sway, weight side to side
    for bn, d in (("Spine", 5), ("Spine1", 5), ("Spine2", 5)):
        rot(arm, bn, X, d + 1.2 * wave(t, 2, 0.1))              # slumped, long breaths
    rot(arm, "Spine1", Y, -1.8 * wave(t, 1))
    for s, sg in (("Left", 1), ("Right", -1)):
        rot(arm, f"{s}Shoulder", Y, sg * 7)                     # shoulders drop
        rot(arm, f"{s}Arm", Y, sg * 6)                          # arms hang heavier
    rot(arm, "Neck", X, 9); rot(arm, "Head", X, 8 + 2 * wave(t, 1, 0.3))


def exhausted_body(arm, t):
    breath = wave(t, 3)
    move(arm, "Hips", Vector((0, 0.11, -0.13)))                 # sit back over the heels
    rot(arm, "Hips", X, 22)
    rot(arm, "Spine", X, 12 + 2 * breath); rot(arm, "Spine1", X, 10 + 2 * breath); rot(arm, "Spine2", X, 6 + 3 * breath)
    for s, sg in (("Left", -1), ("Right", 1)):
        rot(arm, f"{s}Shoulder", Y, sg * 4 * (0.5 + 0.5 * breath))  # shoulders heave
    rot(arm, "Neck", X, -18); rot(arm, "Head", X, -16 + 3 * breath)  # head up, eyes ahead


def exhausted_hands(arm, t):
    out = {}
    for s, sg in (("Left", 1), ("Right", -1)):
        knee = head(arm, f"{s}Leg")
        out[s] = (knee + FWD * 0.05 + Vector((sg * 0.01, 0, 0.09)), head(arm, f"{s}Arm") + Vector((sg * 0.45, 0.25, -0.1)))
    return out


STATES = {
    "idle_cold": dict(body=cold_body, hands=cold_hands),
    "idle_heat": dict(body=heat_body, hands=heat_hands, after=heat_after),
    "idle_tired": dict(body=tired_body),
    "idle_exhausted": dict(body=exhausted_body, hands=exhausted_hands, pin_feet=True),
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
    # 1. FK pass: the idle plus this state's body offsets, keyed; record IK targets on that pose
    poses = []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        poses.append({pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones})
    feet = {s: (head(arm, f"{s}Foot"), arm.pose.bones[f"{s}Foot"].matrix.copy()) for s in ("Left", "Right")}
    fk = bpy.data.actions.new(name + "_fk"); arm.animation_data.action = fk
    targets = []
    for i, f in enumerate(range(f0, f1 + 1)):
        t = (i % N) / N  # last frame == first: seamless loop
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"; pb.matrix_basis = poses[i % N][pb.name]
        bpy.context.view_layer.update()
        st["body"](arm, t)
        targets.append(st["hands"](arm, t) if "hands" in st else {})
        for pb in arm.pose.bones:
            pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)
    # 2. IK hands (and planted feet) toward the recorded targets, then bake everything to plain keys
    emp = {}
    for s in ("Left", "Right"):
        if any(s in tg for tg in targets):
            emp[s] = (empty(f"{s}_wrist"), empty(f"{s}_pole"))
            ik(arm, f"{s}ForeArm", *emp[s])
        if st.get("pin_feet"):
            fe, fp = empty(f"{s}_foot"), empty(f"{s}_knee")
            fe.location = feet[s][0]; fp.location = feet[s][0] + FWD * 0.6 + Vector((0, 0, 0.5))
            ik(arm, f"{s}Leg", fe, fp)
    for i, f in enumerate(range(f0, f1 + 1)):
        for s, (w, p) in emp.items():
            w.location, p.location = targets[i][s]
            w.keyframe_insert("location", frame=f); p.keyframe_insert("location", frame=f)
    bpy.context.view_layer.objects.active = arm; arm.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=f0, frame_end=f1, only_selected=False, visual_keying=True,
                     clear_constraints=True, use_current_action=False, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    baked = arm.animation_data.action
    if "after" in st or st.get("pin_feet"):  # hand flicks on the baked pose; feet keep their idle rotation
        for i, f in enumerate(range(f0, f1 + 1)):
            sc.frame_set(f)
            if "after" in st: st["after"](arm, (i % N) / N)
            if st.get("pin_feet"):
                for s in ("Left", "Right"):
                    pb = arm.pose.bones[f"{s}Foot"]; m = feet[s][1].copy(); m.translation = pb.matrix.translation
                    pb.matrix = m; bpy.context.view_layer.update()
            for pb in arm.pose.bones:
                pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)
    baked.name = name
    for o in [o for o in bpy.data.objects if o.type == "EMPTY"]: bpy.data.objects.remove(o)
    for act in [x for x in bpy.data.actions if x is not baked]: bpy.data.actions.remove(act)
    sc.frame_start, sc.frame_end = f0, f1
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(a.out_dir, name + ".glb"), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_yup=True)
    print(f"STATE {name}: {N + 1} frames at {FPS} fps")
