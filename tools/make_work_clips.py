#!/usr/bin/env python3
"""Author the survivor's looping crafting-station work clips from its own idle, and the hammer they hold:
  work_hammer  at a waist-high bench: left hand steadies the piece, right hand raises the hammer and strikes
  work_stir    slightly crouched over a fire or oven, right hand stirring / turning, left hand on the knee
  work_hang    reaching up to a drying rack, both hands tugging and smoothing a hide
  work_forge   at a low anvil: heavier overhead strikes, left hand holding the work
  work_tan     scraping a hide on a slanted frame: both hands push the scraper down, return
  kick_dirt    one-shot, 1.5 s: two scuffs of the right foot to clear the ground for a worksite, back to idle
Each is the idle loop (same length and fps, so it loops) with layered body offsets, IK hands and, for the
crouches, IK legs pinned to the idle's feet, baked to plain keys like tools/make_state_idles.py. Every motion uses
an integer number of cycles over the loop. Hands are aimed after the bake (fingers / hammer face direction).

The hammer is the survivor's armature (rest) plus a hammer mesh weighted 100% to RightHand in the gripped
position (handle out of the thumb side, face toward the fingers): RiggedModel.attach_skinned() puts it on the
live skeleton.

  Blender -b --python tools/make_work_clips.py -- <survivor.glb> <idle.glb> <anim_dir> <hammer.glb> [--only work_tan ...]

Rig: Mixamo names, facing -Y in Blender (glTF +Z), character's left = +X; armature at the origin.
"""
import argparse, json, math, os, struct, sys
import bpy, bmesh
from mathutils import Matrix, Vector, Quaternion

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("idle"); ap.add_argument("anim_dir"); ap.add_argument("hammer")
ap.add_argument("--only", nargs="*", default=[])
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

b = open(a.idle, "rb").read(); n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + n])
acc = max((j["accessors"][s["input"]] for s in j["animations"][0]["samplers"]), key=lambda x: x["count"])
FPS = round((acc["count"] - 1) / max(acc["max"][0] - acc["min"][0], 1e-6))
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
TAU = 2 * math.pi
ANKLE_MAX = 36.0
REACH = 0.51


def ss(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def wave(t, cycles, phase=0.0): return math.sin(TAU * (cycles * t + phase))


def strike(p, up_end=0.62, hit=0.74):
    """One hammer cycle, p in [0,1): 0 = resting on the work, rises to 1 by up_end, falls fast to 0 at hit."""
    if p < up_end: return ss(0.04, up_end, p)
    if p < hit: return 1 - ((p - up_end) / (hit - up_end)) ** 2
    return 0.0


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


def pole(arm, side, d=(0.5, 0.25, -0.15)):
    sg = 1 if side == "Left" else -1
    return head(arm, f"{side}Arm") + Vector((sg * d[0], d[1], d[2]))


# Each clip: body(arm, t) FK offsets; hands(arm, t) -> {side: (wrist, pole)}; aim(t) -> {side: (fingers dir,
# thumb dir or None)}; crouch: knee bend in degrees (feet stay put).
FWD = Vector((0, -1, 0))


def hammer_cycle(t, n): return strike((t * n) % 1.0)


def hammer_body(arm, t):
    s = hammer_cycle(t, 5)
    rot(arm, "Spine", X, 6); rot(arm, "Spine1", X, 6 - 2 * s); rot(arm, "Spine2", X, 4 - 3 * s)
    rot(arm, "Spine1", Z, -4 - 4 * s)                         # right shoulder draws back on the raise
    rot(arm, "Neck", X, 14); rot(arm, "Head", X, 10)


def hammer_hands(arm, t):
    s = hammer_cycle(t, 5)
    hit = Vector((-0.10, -0.36, 1.02)); top = Vector((-0.20, -0.12, 1.38))
    return {"Right": (hit.lerp(top, s), pole(arm, "Right", (0.45, 0.35, -0.1))),
            "Left": (Vector((0.12, -0.36, 1.00)) + Vector((0, 0, 0.006 * s)), pole(arm, "Left"))}


def hammer_aim(t):
    s = hammer_cycle(t, 5)
    return {"Right": (Vector((0, -0.25, -1)).lerp(Vector((0, -1, 0.35)), s), Vector((0, -1, -0.1)).lerp(Vector((0, 0.15, 1)), s)),
            "Left": (Vector((0, -0.7, -1)), None)}


def forge_body(arm, t):
    s = strike((t * 4) % 1.0, 0.6, 0.72)
    rot(arm, "Spine", X, 10); rot(arm, "Spine1", X, 10 - 5 * s); rot(arm, "Spine2", X, 6 - 6 * s)
    rot(arm, "Spine1", Z, -5 - 6 * s)
    rot(arm, "Neck", X, 16 - 6 * s); rot(arm, "Head", X, 10)


def forge_hands(arm, t):
    s = strike((t * 4) % 1.0, 0.6, 0.72)
    hit = Vector((-0.08, -0.38, 0.86)); top = Vector((-0.22, -0.10, 1.45))
    return {"Right": (hit.lerp(top, s), pole(arm, "Right", (0.45, 0.35, -0.05))),
            "Left": (Vector((0.14, -0.38, 0.88)) + Vector((0, 0.01 * s, 0.01 * s)), pole(arm, "Left"))}


def forge_aim(t):
    s = strike((t * 4) % 1.0, 0.6, 0.72)
    return {"Right": (Vector((0, -0.2, -1)).lerp(Vector((0, -0.6, 1)), s), Vector((0, -1, -0.15)).lerp(Vector((0, 0.5, 1)), s)),
            "Left": (Vector((0, -0.6, -1)), None)}


def stir_body(arm, t):
    rot(arm, "Hips", X, 10)
    rot(arm, "Spine", X, 8); rot(arm, "Spine1", X, 8 + 2 * wave(t, 3)); rot(arm, "Spine2", X, 4)
    rot(arm, "Spine1", Z, 4 * wave(t, 3, 0.25))               # the body turns a little with the stirring
    rot(arm, "Neck", X, 12); rot(arm, "Head", X, 8)


def stir_hands(arm, t):
    c = Vector((-0.10, -0.40, 0.80))  # spit crank: a vertical circle beside the fire, three turns per loop
    r = c + Vector((0.0, 0.09 * math.cos(TAU * 3 * t), 0.09 * math.sin(TAU * 3 * t)))
    knee = head(arm, "LeftLeg")
    return {"Right": (r, pole(arm, "Right")),
            "Left": (knee + Vector((0.0, -0.02, 0.10)), pole(arm, "Left", (0.5, 0.35, -0.1)))}


def stir_aim(t): return {"Right": (Vector((0, -0.6, -1)), None), "Left": (Vector((0, -0.5, -1)), None)}


def hang_body(arm, t):
    rot(arm, "Spine1", X, -4); rot(arm, "Spine2", X, -4 + 1.5 * wave(t, 2))
    rot(arm, "Spine2", Y, 3 * wave(t, 1))                     # leans toward the hand doing the work
    rot(arm, "Neck", X, -18); rot(arm, "Head", X, -10)


def hang_hands(arm, t):
    out = {}
    for s, sg, ph in (("Left", 1, 0.0), ("Right", -1, 0.5)):
        tug = 0.5 + 0.5 * wave(t, 2, ph)                       # one hand pulls down while the other holds
        slide = 0.05 * wave(t, 1, ph + 0.25)                   # and smooths along the bar
        out[s] = (Vector((sg * 0.22 + slide, -0.22, 1.84 - 0.07 * tug)), pole(arm, s, (0.55, 0.15, -0.35)))
    return out


def hang_aim(t): return {"Left": (Vector((0.1, -0.5, 1)), None), "Right": (Vector((-0.1, -0.5, 1)), None)}


def tan_stroke(t):
    p = (t * 4) % 1.0                                         # slow pressing stroke down, quick return
    return ss(0.0, 0.62, p) if p < 0.62 else 1 - ss(0.62, 1.0, p)


def tan_body(arm, t):
    s = tan_stroke(t)
    rot(arm, "Hips", X, 6 + 4 * s)
    rot(arm, "Spine", X, 6 + 4 * s); rot(arm, "Spine1", X, 6 + 5 * s); rot(arm, "Spine2", X, 4)
    rot(arm, "Neck", X, 12); rot(arm, "Head", X, 8)


def tan_hands(arm, t):
    s = tan_stroke(t)
    top, bot = Vector((0, -0.32, 1.15)), Vector((0, -0.42, 0.90))   # along the slanted frame
    c = top.lerp(bot, s)
    return {"Left": (c + Vector((0.13, 0, 0)), pole(arm, "Left")), "Right": (c + Vector((-0.13, 0, 0)), pole(arm, "Right"))}


def tan_aim(t): return {"Left": (Vector((-0.2, -1, -0.6)), None), "Right": (Vector((0.2, -1, -0.6)), None)}


def keys(q, pts):
    """Smoothstep between (q, value) keys."""
    for (q0, v0), (q1, v1) in zip(pts, pts[1:]):
        if q <= q1: return v0 + (v1 - v0) * ss(q0, q1, q)
    return pts[-1][1]


def kick_body(arm, t):
    """Two scuffs of the right foot (0.6 s each), then 0.3 s back in the idle. Thigh/shin/foot hinge on X:
    + swings back / bends the knee / points the toes down."""
    q = (t / 0.8) * 2 if t < 0.8 else 0.0
    q -= int(q)
    th = keys(q, [(0, 0), (0.3, 12), (0.62, -24), (1, 0)])
    kn = keys(q, [(0, 0), (0.3, 42), (0.62, 14), (1, 0)])
    an = keys(q, [(0, 0), (0.3, -8), (0.62, 9), (1, 0)])
    env = 1 - ss(0.75, 0.95, t)
    rot(arm, "Spine1", X, 6 * (1 - ss(0.8, 1.0, t))); rot(arm, "Spine1", Z, -4 * env * math.sin(math.pi * q))
    rot(arm, "Neck", X, 14 * (1 - ss(0.8, 1.0, t))); rot(arm, "Head", X, 8 * (1 - ss(0.8, 1.0, t)))
    rot(arm, "RightUpLeg", X, th); rot(arm, "RightLeg", X, kn); rot(arm, "RightFoot", X, an)
    rot(arm, "LeftArm", Y, 6 * env * math.sin(math.pi * q))   # a little arm swing for balance


CLIPS = {
    "work_hammer": dict(body=hammer_body, hands=hammer_hands, aim=hammer_aim),
    "work_stir": dict(body=stir_body, hands=stir_hands, aim=stir_aim, crouch=24),
    "work_hang": dict(body=hang_body, hands=hang_hands, aim=hang_aim),
    "work_forge": dict(body=forge_body, hands=forge_hands, aim=forge_aim, crouch=10),
    "work_tan": dict(body=tan_body, hands=tan_hands, aim=tan_aim, crouch=10),
    # one-shot (owner: "he like kicks the dirt to make the construction site"); 36 frames = 1.5 s
    "kick_dirt": dict(body=kick_body, hands=lambda arm, t: {}, aim=lambda t: {}, frames=36),
}


def crouch(arm, deg):
    """Bend both knees by hinging only (thigh forward, shin back twice as far, foot back to flat) and lower the
    hips so the feet stay where the idle put them. Pure hinges: no thigh twist, unlike a leg IK solve here."""
    before = {s: head(arm, f"{s}Foot") for s in ("Left", "Right")}
    for s in ("Left", "Right"):
        rot(arm, f"{s}UpLeg", X, -deg); rot(arm, f"{s}Leg", X, 2 * deg); rot(arm, f"{s}Foot", X, -deg)
    d = sum(((before[s] - head(arm, f"{s}Foot")) for s in before), Vector()) / 2
    move(arm, "Hips", d)


def ik(arm, bone, target, pole_t, chain=2):
    c = arm.pose.bones[bone].constraints.new("IK")
    c.target = target; c.pole_target = pole_t; c.chain_count = chain; c.pole_angle = math.radians(-90)
    return c


def empty(name):
    e = bpy.data.objects.new(name, None); bpy.context.scene.collection.objects.link(e); return e


def aim_hand(arm, side, d, thumb):
    """Turn the hand about the wrist so the fingers point along d (and the thumb side toward `thumb`)."""
    pb = arm.pose.bones[f"{side}Hand"]
    m = pb.matrix.copy(); piv = m.translation.copy()
    cur = m.to_3x3().normalized()
    y = d.normalized()
    if thumb is None:
        q = cur.col[1].rotation_difference(y)
    else:
        x = (thumb - y * thumb.dot(y)).normalized(); z = x.cross(y)
        q = (Matrix((x, y, z)).transposed() @ cur.inverted()).to_quaternion()
    pb.matrix = Matrix.Translation(piv) @ q.to_matrix().to_4x4() @ Matrix.Translation(-piv) @ m
    bpy.context.view_layer.update()


def ankle_twist(arm, s):
    L, F = arm.pose.bones[f"{s}Leg"].matrix.to_3x3(), arm.pose.bones[f"{s}Foot"].matrix.to_3x3()
    sg = 1 if arm.data.bones[f"{s}Leg"].matrix_local.col[0].dot(arm.data.bones[f"{s}Foot"].matrix_local.col[0]) >= 0 else -1
    d = L.col[1].normalized()
    ax, bx = L.col[0] - d * L.col[0].dot(d), F.col[0] * sg - d * (F.col[0] * sg).dot(d)
    return math.degrees(ax.normalized().angle(bx.normalized())), d


os.makedirs(a.anim_dir, exist_ok=True)
for name, st in CLIPS.items():
    if a.only and name not in a.only: continue
    arm, src = load()
    f0, f1 = (int(round(x)) for x in src.frame_range)
    N = f1 - f0
    sc = bpy.context.scene
    poses = []
    for f in range(f0, f1 + 1):
        sc.frame_set(f); poses.append({pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones})
    if st.get("frames"):  # one-shot: starts and ends on the idle's first pose
        f1 = f0 + st["frames"] - 1; N = f1 - f0
    fk = bpy.data.actions.new(name + "_fk"); arm.animation_data.action = fk
    targets = []; over = [0.0]
    for i, f in enumerate(range(f0, f1 + 1)):
        t = i / N if st.get("frames") else (i % N) / N  # loops: last frame == first
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"; pb.matrix_basis = poses[i % N if not st.get("frames") else i][pb.name]
        bpy.context.view_layer.update()
        if st.get("crouch"): crouch(arm, st["crouch"])
        st["body"](arm, t)
        tg = st["hands"](arm, t)
        for s, (w, p) in tg.items():  # the rig's arms are short (0.55 m shoulder to wrist): keep the elbow bent
            sh = head(arm, f"{s}Arm"); v = w - sh
            over[0] = max(over[0], v.length - REACH)
            if v.length > REACH: tg[s] = (sh + v.normalized() * REACH, p)
        targets.append(tg)
        for pb in arm.pose.bones:
            pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)
    emp = {}
    for s in targets[0]:
        emp[s] = (empty(f"{s}_wrist"), empty(f"{s}_pole")); ik(arm, f"{s}ForeArm", *emp[s])
    for i, f in enumerate(range(f0, f1 + 1)):
        for s, (w, p) in emp.items():
            w.location, p.location = targets[i][s]
            w.keyframe_insert("location", frame=f); p.keyframe_insert("location", frame=f)
    bpy.context.view_layer.objects.active = arm; arm.select_set(True)
    bpy.ops.object.mode_set(mode="POSE"); bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=f0, frame_end=f1, only_selected=False, visual_keying=True,
                     clear_constraints=True, use_current_action=False, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    baked = arm.animation_data.action
    for i, f in enumerate(range(f0, f1 + 1)):
        sc.frame_set(f)
        t = i / N if st.get("frames") else (i % N) / N
        for s, (d, thumb) in st["aim"](t).items(): aim_hand(arm, s, d, thumb)
        for s in ("Left", "Right"):
            tw, d = ankle_twist(arm, s)
            if tw > ANKLE_MAX:
                pb = arm.pose.bones[f"{s}Foot"]; m0 = pb.matrix.copy(); piv = m0.translation.copy(); best = None
                for sg in (1, -1):
                    pb.matrix = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(sg * (tw - ANKLE_MAX)), 4, d) @ Matrix.Translation(-piv) @ m0
                    bpy.context.view_layer.update()
                    t2 = ankle_twist(arm, s)[0]
                    if best is None or t2 < best[0]: best = (t2, pb.matrix.copy())
                pb.matrix = best[1]; bpy.context.view_layer.update()
        for pb in arm.pose.bones:
            pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)
    baked.name = name
    for o in [o for o in bpy.data.objects if o.type == "EMPTY"]: bpy.data.objects.remove(o)
    for act in [x for x in bpy.data.actions if x is not baked]: bpy.data.actions.remove(act)
    sc.frame_start, sc.frame_end = f0, f1
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(a.anim_dir, name + ".glb"), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_yup=True)
    print(f"WORK {name}: {N + 1} frames at {FPS} fps, targets pulled in by up to {max(0, over[0]):.3f} m")


# ---------------------------------------------------------------- hammer, gripped in the right hand at rest
def mat(nm, rgb, rough, metal=0.0):
    m = bpy.data.materials.new(nm); m.use_nodes = True
    bs = m.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (*rgb, 1); bs.inputs["Roughness"].default_value = rough
    bs.inputs["Metallic"].default_value = metal
    return m


if not a.only or "hammer" in a.only:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.base)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in [o for o in bpy.data.objects if o is not arm]: bpy.data.objects.remove(o)
    M = arm.data.bones["RightHand"].matrix_local       # hand frame: +Y fingers, +Z out of the palm, +X thumb side
    grip = Vector((0.0, 0.085, 0.03))                  # inside the closed fist
    bm = bmesh.new()
    wood, iron = 0, 1
    # handle along +X (out of the thumb side), butt 6 cm past the little finger
    hl = bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.016, radius2=0.014, depth=0.30)
    bmesh.ops.rotate(bm, verts=hl["verts"], cent=Vector(), matrix=Matrix.Rotation(math.radians(90), 3, Y))
    bmesh.ops.translate(bm, verts=hl["verts"], vec=grip + X * 0.09)
    for f in bm.faces: f.material_index = wood
    hd = bmesh.ops.create_cube(bm, size=1.0)
    for v in hd["verts"]: v.co = grip + X * 0.215 + Vector((v.co.x * 0.04, v.co.y * 0.12 + 0.012, v.co.z * 0.04))  # face toward +Y
    for v in hd["verts"]:
        for f in v.link_faces: f.material_index = iron
    for v in bm.verts: v.co = M @ v.co
    me = bpy.data.meshes.new("work_hammer"); bm.to_mesh(me); bm.free()
    me.materials.append(mat("hammer_wood", (0.42, 0.27, 0.13), 0.7)); me.materials.append(mat("hammer_iron", (0.32, 0.32, 0.34), 0.45, 0.85))
    ob = bpy.data.objects.new("work_hammer", me); bpy.context.scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name="RightHand"); vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    ob.parent = arm; ob.modifiers.new("Armature", "ARMATURE").object = arm
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True); ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a.hammer, export_format="GLB", use_selection=True, export_animations=False, export_yup=True)
    print("HAMMER", a.hammer)
