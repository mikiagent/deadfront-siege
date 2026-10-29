#!/usr/bin/env python3
"""Author the survivor's rummage clips and the leather satchel prop they use:
  rummage_in   kneel, set the satchel down from the left hand, lift the flap open
  rummage      loop: right hand digs in the open bag, pulls a rolled bundle halfway out, looks, puts it back
  rummage_out  flap shut, left hand takes the bag by its top, stand up holding it
The body is Quaternius UAL1 Fixing_Kneeling (CC0) retargeted to the survivor (its kneel-down, kneeling hold and
stand-up), with IK hands, a forward lean and head look layered on top and baked to plain keys, like
tools/make_state_idles.py. Legs come from the source untouched, so knees and feet stay planted.

The satchel is its own small rig (bones Satchel, Flap, Item; meshes weighted 100% to one bone each) in the
survivor's model space, with three animations of the same names. Play it in sync with the survivor's clip
(PlayerAnim.play_rummage does), parented to the survivor's model root.

  Blender -b --python verifiers/tools/retarget.py -- UAL1_Standard.glb survivor.glb <tmp> Fixing_Kneeling:fk
  Blender -b --python verifiers/tools/fix_leg_twist.py -- <tmp>/fk.glb <tmp>/fk_fixed.glb   (thigh twist 64 -> 43 deg)
  Blender -b --python tools/make_rummage.py -- <survivor.glb> <tmp>/fk_fixed.glb <anim_dir> <satchel.glb>

Rig: Mixamo names, facing -Y in Blender (glTF +Z), character's left = +X. Armature at the origin, so armature
space = world space here.
"""
import json, math, os, struct, sys
import bpy, bmesh
from mathutils import Matrix, Vector, Quaternion

base, src_path, anim_dir, satchel_path = sys.argv[sys.argv.index("--") + 1:][:4]
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
TAU = 2 * math.pi

# Source timing (frames of fk.glb at 24 fps): kneel settled by 17, stand-up starts after 103.
KNEEL_END, KNEEL_HOLD, STAND_FROM, SRC_END = 17, 19, 103, 125
FPS = 24

# Satchel, in survivor model space: bottom centre G, width W (x), depth D (y), height H. Front of the body is -Y.
G = Vector((0.08, -0.52, 0.0))
W, D, H = 0.30, 0.16, 0.25
HINGE = Vector((0, -D / 2, H))               # flap hinge: top edge of the far wall
R_EDGE = Vector((0, D + 0.015, -0.10))        # flap's free edge (bottom of the near drop), from the hinge
R_LEVER = Vector((0, 0.05, 0.012))            # where the hand lifts a fallen-open flap, from the hinge
OPEN, LIFTED = 165.0, 100.0                   # flap angles: lying open behind the bag / lifted by the hand
ITEM_REST = Vector((-0.05, -0.005, 0.03))     # rolled bundle standing in the bag (bottom centre, bag space)
ITEM_LEN, ITEM_LIFT = 0.17, 0.13


def ss(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0))) if e1 != e0 else float(x >= e1)
    return t * t * (3 - 2 * t)


def wave(t, cycles, phase=0.0): return math.sin(TAU * (cycles * t + phase))


def flap_point(a_deg, r):
    return G + HINGE + Matrix.Rotation(math.radians(a_deg), 3, X) @ r


# ---------------------------------------------------------------- survivor
def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.ops.import_scene.gltf(filepath=base)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in [o for o in bpy.data.objects if o is not arm]: bpy.data.objects.remove(o)
    before = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=src_path)
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


def head(arm, name): return arm.matrix_world @ arm.pose.bones[name].head


def body(arm, t, w, look_up=0.0):
    """Lean in over the bag and look into it; t drives the loop's breathing and glances (integer cycles)."""
    if w <= 0: return
    rot(arm, "Spine", X, w * 6); rot(arm, "Spine1", X, w * (7 + 1.0 * wave(t, 2)))
    rot(arm, "Spine2", X, w * (6 + 1.0 * wave(t, 2, 0.1)))
    rot(arm, "Spine2", Z, w * 2.5 * wave(t, 1, 0.2))           # shoulders follow the digging hand a little
    rot(arm, "Neck", X, w * (10 - 14 * look_up)); rot(arm, "Head", X, w * (8 - 10 * look_up))
    rot(arm, "Head", Z, w * (7 * wave(t, 1, 0.05) * (1 - look_up)))   # glance across the bag


DIG_C = Vector((-0.03, 0.0, H))   # bag space: middle of the opening


def dig_wrist(t):
    """Right wrist digging: circles and pushes down into the opening (fingers reach ~15 cm below the wrist)."""
    c = G + DIG_C
    return c + Vector((0.035 * math.cos(TAU * 3 * t), 0.06 + 0.025 * math.sin(TAU * 3 * t), 0.13 - 0.05 * (0.5 + 0.5 * wave(t, 6))))


def item_lift(t):
    return ITEM_LIFT * (ss(0.36, 0.46, t) - ss(0.64, 0.74, t))


def item_top(t): return G + ITEM_REST + Vector((0, 0, ITEM_LEN + item_lift(t)))


def loop_right(t):
    grab = ss(0.30, 0.37, t) - ss(0.74, 0.80, t)          # hand goes to the bundle, then back to digging
    hold = item_top(t) + Vector((0.0, 0.06, 0.04))
    return dig_wrist(t).lerp(hold, grab)


LEFT_HOLD = G + Vector((0.11, D / 2 + 0.035, H + 0.07))   # left hand on the near rim, holding the bag open


def loop_left(t):
    return LEFT_HOLD + Vector((0, 0, 0.008 * wave(t, 2, 0.3)))


CARRY = G + Vector((0.02, 0.0, H + 0.10))   # left wrist above the closed flap's middle: carrying the bag by its top
FLAP_GRIP = Vector((0.0, 0.035, 0.05))       # wrist above the flap point the fingers hold


def pole(arm, side):
    sg = 1 if side == "Left" else -1
    return head(arm, f"{side}Arm") + Vector((sg * 0.5, 0.25, -0.15))


# Per clip: list of frames; each frame is a dict:
#   src: source frame (or (a, b, s) to blend two), body: (t, weight, look_up), L/R: (target or None, IK weight),
#   flap: angle, aim: {side: (dir, weight)}, carry: bool (bag follows the left hand)
def clip_in():
    out = []
    n = 44
    for f in range(n):
        fr = {}
        fr["src"] = f + 1 if f < KNEEL_END else KNEEL_HOLD
        fr["body"] = (0.0, ss(10, 30, f), 0.0)
        # left: carries the bag down and sets it on the ground at 18, then moves to hold the near rim
        lw = ss(4, 16, f)
        fr["L"] = (CARRY.lerp(LEFT_HOLD, ss(19, 30, f)), lw)
        fr["carry"] = f <= 18
        # right: reaches the flap edge, lifts it to LIFTED, lets it fall open, goes to dig
        a = LIFTED * ss(22, 32, f)
        if f > 32: a = LIFTED + (OPEN - LIFTED) * ss(32, 38, f) ** 2
        fr["flap"] = a
        edge = flap_point(min(a, LIFTED), R_EDGE) + FLAP_GRIP
        r = edge.lerp(loop_right(0.0), ss(32, 42, f))
        fr["R"] = (r, ss(14, 22, f))
        fr["aim"] = {"Left": (Vector((0, -0.2, -1)), lw), "Right": (Vector((0, -0.4, -1)), ss(16, 26, f))}
        out.append(fr)
    out[-1]["body"] = (0.0, 1.0, 0.0)
    return out


LOOP_N = 120  # 5 s


def clip_loop():
    out = []
    for f in range(LOOP_N + 1):
        t = (f % LOOP_N) / LOOP_N
        look = 0.6 * (ss(0.40, 0.48, t) - ss(0.62, 0.70, t))
        out.append({"src": KNEEL_HOLD, "body": (t, 1.0, look), "L": (loop_left(t), 1.0), "R": (loop_right(t), 1.0),
                    "flap": OPEN, "item": item_lift(t), "carry": False,
                    "aim": {"Left": (Vector((0, -0.6, -1)), 1.0), "Right": (Vector((0, -0.4, -1)).lerp(Vector((0, -0.2, -1)), look), 1.0)}})
    return out


def clip_out():
    out = []
    hold = 20
    n = hold + (SRC_END - STAND_FROM) + 1 + 4
    for f in range(n):
        fr = {}
        if f < hold: fr["src"] = (KNEEL_HOLD, STAND_FROM, ss(0, hold - 1, f))
        else: fr["src"] = min(SRC_END, STAND_FROM + f - hold)
        fr["body"] = (0.0, 1.0 - ss(8, hold + 2, f), 0.0)
        # right: from digging to the fallen flap, lift it (lever point -> edge), push it shut, let go
        a = OPEN + (0.0 - OPEN) * ss(4, 15, f)
        fr["flap"] = a
        rr = R_LEVER.lerp(R_EDGE, ss(LIFTED, 0.0, a) if a < LIFTED else 0.0)
        tgt = flap_point(a, rr) + FLAP_GRIP
        fr["R"] = (loop_right(0.0).lerp(tgt, ss(0, 4, f)), 1.0 - ss(16, 24, f))
        # left: rim -> top of the closed bag, carries it up while standing, IK fades so the arm hangs naturally
        fr["L"] = (LEFT_HOLD.lerp(CARRY, ss(12, 18, f)), 1.0 - ss(hold + 4, hold + 18, f))
        fr["carry"] = f >= 18
        fr["aim"] = {"Left": (Vector((0, -0.6, -1)).lerp(Vector((0, -0.2, -1)), ss(12, 18, f)), 1.0 - ss(hold + 6, hold + 20, f)),
                     "Right": (Vector((0, -0.4, -1)), 1.0 - ss(14, 24, f))}
        out.append(fr)
    return out


def empty(name):
    e = bpy.data.objects.new(name, None); bpy.context.scene.collection.objects.link(e); return e


ANKLE_MAX = 36.0  # limb_check fails ankle twist past 40; the source's kneeling back foot reads ~43


def ankle_twist(arm, s):
    """limb_check's measure: shin side axis vs foot side axis, across the shin."""
    L, F = arm.pose.bones[f"{s}Leg"].matrix.to_3x3(), arm.pose.bones[f"{s}Foot"].matrix.to_3x3()
    sg = 1 if arm.data.bones[f"{s}Leg"].matrix_local.col[0].dot(arm.data.bones[f"{s}Foot"].matrix_local.col[0]) >= 0 else -1
    d = L.col[1].normalized()
    ax, bx = L.col[0] - d * L.col[0].dot(d), F.col[0] * sg - d * (F.col[0] * sg).dot(d)
    return math.degrees(ax.normalized().angle(bx.normalized())), d


def clamp_ankle(arm, s, f):
    """Turn the foot about the shin until its twist is within ANKLE_MAX (a few degrees of toe-out at most)."""
    tw, d = ankle_twist(arm, s)
    if tw <= ANKLE_MAX: return
    pb = arm.pose.bones[f"{s}Foot"]; m0 = pb.matrix.copy(); piv = m0.translation.copy()
    best = None
    for sign in (1, -1):
        pb.matrix = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(sign * (tw - ANKLE_MAX)), 4, d) @ Matrix.Translation(-piv) @ m0
        bpy.context.view_layer.update()
        t2 = ankle_twist(arm, s)[0]
        if best is None or t2 < best[0]: best = (t2, pb.matrix.copy())
    pb.matrix = best[1]; bpy.context.view_layer.update()
    pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)


def author(name, frames):
    arm, src = load()
    sc = bpy.context.scene
    poses = {}
    for f in range(KNEEL_END - 20, SRC_END + 2):
        if f < 1: continue
        sc.frame_set(f); poses[f] = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}

    def src_pose(s):
        if isinstance(s, tuple):
            a, b, k = s
            out = {}
            for n_, ma in poses[a].items():
                mb = poses[b][n_]
                la, ra, _ = ma.decompose(); lb, rb, _ = mb.decompose()
                out[n_] = Matrix.Translation(la.lerp(lb, k)) @ ra.slerp(rb, k).to_matrix().to_4x4()
            return out
        return poses[s]

    fk = bpy.data.actions.new(name + "_fk"); arm.animation_data.action = fk
    poles = []
    for i, fr in enumerate(frames):
        f = i + 1
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"; pb.matrix_basis = src_pose(fr["src"])[pb.name]
        bpy.context.view_layer.update()
        body(arm, *fr["body"])
        poles.append({s: pole(arm, s) for s in ("Left", "Right")})
        for pb in arm.pose.bones:
            pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)
    cons = {}
    for s in ("Left", "Right"):
        w, p = empty(f"{s}_wrist"), empty(f"{s}_pole")
        c = arm.pose.bones[f"{s}ForeArm"].constraints.new("IK")
        c.target = w; c.pole_target = p; c.chain_count = 2; c.pole_angle = math.radians(-90)
        cons[s] = (c, w, p)
    for i, fr in enumerate(frames):
        f = i + 1
        for s, key in (("Left", "L"), ("Right", "R")):
            c, w, p = cons[s]
            tgt, wt = fr[key]
            w.location = tgt; p.location = poles[i][s]; c.influence = wt
            w.keyframe_insert("location", frame=f); p.keyframe_insert("location", frame=f)
            c.keyframe_insert("influence", frame=f)
    bpy.context.view_layer.objects.active = arm; arm.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=1, frame_end=len(frames), only_selected=False, visual_keying=True,
                     clear_constraints=True, use_current_action=False, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    baked = arm.animation_data.action
    # Hands: swing (no twist) the hand so the fingers point into the bag / down onto what they hold.
    grips = []
    for i, fr in enumerate(frames):
        f = i + 1
        sc.frame_set(f)
        for s, (d, wt) in fr["aim"].items():
            if wt <= 0.001: continue
            pb = arm.pose.bones[f"{s}Hand"]
            m = pb.matrix.copy(); piv = m.translation.copy()
            q = Quaternion().slerp(m.col[1].xyz.normalized().rotation_difference(d.normalized()), wt)
            pb.matrix = Matrix.Translation(piv) @ q.to_matrix().to_4x4() @ Matrix.Translation(-piv) @ m
            bpy.context.view_layer.update()
            pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)
        for s in ("Left", "Right"):
            clamp_ankle(arm, s, f)
        grips.append(head(arm, "LeftHandMiddle2").copy())
    baked.name = name
    for o in [o for o in bpy.data.objects if o.type == "EMPTY"]: bpy.data.objects.remove(o)
    for act in [x for x in bpy.data.actions if x is not baked]: bpy.data.actions.remove(act)
    sc.frame_start, sc.frame_end = 1, len(frames)
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(anim_dir, name + ".glb"), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_yup=True)
    print(f"RUMMAGE {name}: {len(frames)} frames at {FPS} fps")
    return grips


def bag_track(frames, grips):
    """Satchel position per frame: on the ground at G, or hanging from the left hand while carried (the offset
    measured at the hand-over frame, so there is no jump), never below the ground."""
    carry = [fr.get("carry", False) for fr in frames]
    track = [G.copy() for _ in frames]
    if any(carry):
        # hand-over frame: last carried frame (in), first carried frame (out)
        k = max(i for i, c in enumerate(carry) if c) if carry[0] else min(i for i, c in enumerate(carry) if c)
        off = G - grips[k]
        for i, c in enumerate(carry):
            if c:
                p = grips[i] + off
                p.z = max(0.0, p.z)
                track[i] = p
        print(f"BAG hand-over frame {k + 1}: grip {tuple(round(x, 3) for x in grips[k])}")
    return track


# ---------------------------------------------------------------- satchel prop
def mat(name, rgb, rough=0.75, metal=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    bs = m.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (*rgb, 1); bs.inputs["Roughness"].default_value = rough
    bs.inputs["Metallic"].default_value = metal
    return m


def box(name, lo, hi, material, bevel=0.012):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector(((lo[i] + hi[i]) / 2 + v.co[i] * (hi[i] - lo[i]) for i in range(3)))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES")
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    me.materials.append(material)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    for p in me.polygons: p.use_smooth = True
    return o


def cyl(name, c, r, h, material, verts=12):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r, depth=h)
    bmesh.ops.translate(bm, verts=bm.verts, vec=c + Vector((0, 0, h / 2)))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(material)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    for p in me.polygons: p.use_smooth = True
    return o


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join(); objs[0].name = name
    return objs[0]


def build_satchel(tracks):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    leather = mat("satchel_leather", (0.30, 0.16, 0.07), 0.7)
    dark = mat("satchel_leather_dark", (0.19, 0.10, 0.045), 0.65)
    brass = mat("satchel_brass", (0.62, 0.48, 0.22), 0.35, 0.8)
    linen = mat("satchel_bundle", (0.72, 0.66, 0.52), 0.9)
    t = 0.012  # wall thickness: an open box (no top) so the inside reads when the flap is open
    walls = [box("b0", (-W / 2, -D / 2, 0), (W / 2, D / 2, t), leather, 0.006),
             box("b1", (-W / 2, -D / 2, 0), (W / 2, -D / 2 + t, H), leather, 0.005),
             box("b2", (-W / 2, D / 2 - t, 0), (W / 2, D / 2, H), leather, 0.005),
             box("b3", (-W / 2, -D / 2, 0), (-W / 2 + t, D / 2, H), leather, 0.005),
             box("b4", (W / 2 - t, -D / 2, 0), (W / 2, D / 2, H), leather, 0.005),
             box("b5", (-W / 2 - 0.004, -D / 2 - 0.004, 0.0), (W / 2 + 0.004, D / 2 + 0.004, 0.035), dark, 0.006)]  # sole band
    for sx in (-1, 1):  # side strap rings
        walls.append(box(f"ring{sx}", (sx * W / 2 - 0.006, -0.012, H - 0.06), (sx * W / 2 + 0.006, 0.012, H - 0.02), brass, 0.003))
    bag = join(walls, "satchel_body")
    hz, hy = HINGE.z, HINGE.y
    flap = join([box("f0", (-W / 2 - 0.006, hy, hz), (W / 2 + 0.006, D / 2 + 0.016, hz + 0.014), dark, 0.005),
                 box("f1", (-W / 2 - 0.006, D / 2 + 0.002, hz - 0.10), (W / 2 + 0.006, D / 2 + 0.016, hz + 0.014), dark, 0.005),
                 box("f2", (-0.022, D / 2 + 0.016, hz - 0.13), (0.022, D / 2 + 0.024, hz + 0.01), leather, 0.003),   # strap
                 box("f3", (-0.03, D / 2 + 0.018, hz - 0.115), (0.03, D / 2 + 0.03, hz - 0.085), brass, 0.003)],       # buckle
                "satchel_flap")
    item = join([cyl("i0", ITEM_REST, 0.036, ITEM_LEN, linen, 14),
                 cyl("i1", ITEM_REST + Vector((0, 0, ITEM_LEN * 0.3)), 0.039, 0.014, dark, 14),
                 cyl("i2", ITEM_REST + Vector((0, 0, ITEM_LEN * 0.7)), 0.039, 0.014, dark, 14)], "satchel_item")
    # rig: bones point +Y with no roll, so a bone's local axes are the model's axes
    ad = bpy.data.armatures.new("SatchelRig"); ao = bpy.data.objects.new("SatchelRig", ad)
    bpy.context.scene.collection.objects.link(ao)
    bpy.context.view_layer.objects.active = ao
    bpy.ops.object.mode_set(mode="EDIT")
    for bn, hd, par in (("Satchel", Vector(), None), ("Flap", HINGE, "Satchel"), ("Item", ITEM_REST, "Satchel")):
        eb = ad.edit_bones.new(bn); eb.head = hd; eb.tail = hd + Vector((0, 0.08, 0)); eb.roll = 0
        if par: eb.parent = ad.edit_bones[par]
    bpy.ops.object.mode_set(mode="OBJECT")
    for o, bn in ((bag, "Satchel"), (flap, "Flap"), (item, "Item")):
        vg = o.vertex_groups.new(name=bn); vg.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
        o.parent = ao; o.modifiers.new("Armature", "ARMATURE").object = ao
    ao.animation_data_create()
    for name, (frames, track) in tracks.items():
        act = bpy.data.actions.new(name); ao.animation_data.action = act
        for i, fr in enumerate(frames):
            f = i + 1
            P = ao.pose.bones
            for pb in P: pb.rotation_mode = "QUATERNION"
            P["Satchel"].location = track[i]
            P["Flap"].rotation_quaternion = Quaternion(X, math.radians(fr.get("flap", 0.0)))
            P["Item"].location = Vector((0, 0, fr.get("item", 0.0)))
            for pb in P:
                pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)
        act.use_fake_user = True
    ao.animation_data.action = None
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=satchel_path, export_format="GLB", use_selection=True, export_animations=True,
                              export_animation_mode="ACTIONS", export_force_sampling=True, export_yup=True)
    print(f"SATCHEL {satchel_path}: {list(tracks)}")


os.makedirs(anim_dir, exist_ok=True); os.makedirs(os.path.dirname(satchel_path), exist_ok=True)
tracks = {}
for nm, fn in (("rummage_in", clip_in), ("rummage", clip_loop), ("rummage_out", clip_out)):
    frames = fn()
    grips = author(nm, frames)
    tracks[nm] = (frames, bag_track(frames, grips))
build_satchel(tracks)
