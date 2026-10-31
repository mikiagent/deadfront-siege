"""ANKYLO3D + ANKYLOAI: the ankylosaurus' tail-club clips, keyed from rest on the transplant skeleton (Triceratops donor
bones).

ANKYLOAI (owner 2026-10-31: "smashing that tail around", "keeps feet planted or steps in the direction for the swing"):
every foot is planted (its pose is fixed: zero slide) except inside a scheduled step, where it lifts on an arc and lands
on a new plant (its rest spot turned about PIVOT by that step's yaw, optionally set out wider), or a stamp (lift and
stamp in place). The body yaws a few degrees over planted feet; bigger yaws are carried by steps. ClubTailBrain never
turns the animal in code while these play, so what the feet do is what the player sees.

TAIL WHIP  attack_primary 2.0 s: the tail cocks left and rattles, the head looks back right, a front-foot stamp, then the
           whip to the right: the club sweeps from behind round the right flank (strike window 0.50-0.66) while the hind
           feet step into the swing; they step back in the recovery.
TAIL SMASH attack_heavy 3.0 s: the front feet step out into a wide brace, the tail rises overhead (curled up) and
           trembles, then slams down behind and a little right (impact 0.65; the club rests on the ground, never under
           it); hold, then the feet step back in.
CLUB SWEEP tail_swipe 2.6 s: the tail drawn far left and low, a stamp, then one long low sweep from the left through
           straight behind to the right (0.44-0.74) while all four feet step round a pivot; steps back in the recovery.
alert 1.6 s and sleep 2.5 s (not looped) are unchanged from ANKYLO3D.
(The ANKYLO3D attack_primary 1.25 s / attack_heavy 2.0 s side whips were replaced: their feet followed the body yaw and
slid, which read as gliding.)

usage: Blender -b -P tools/gait/make_tail_club.py -- <base.glb> <out_dir> [clip ...]
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, OUT = argv[:2]
WANT = argv[2:] or ["attack_primary", "attack_heavy", "tail_swipe", "alert", "sleep"]
FPS = 24
TAILS = ["Tail1", "Tail2", "Tail3", "Tail4", "Tail5"]
LEGS = [(f"{e}UpLeg.{s}", f"{e}LowLeg.{s}", f"{e}Foot.{s}") for e in ("Back", "Front") for s in ("L", "R")]


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def keys(u, pts):
    """Piecewise smoothstep through (u, value) points."""
    if pts is None:
        return 0.0
    if u <= pts[0][0]:
        return pts[0][1]
    for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
        if u <= u1:
            return v0 + (v1 - v0) * smooth((u - u0) / max(u1 - u0, 1e-6))
    return pts[-1][1]


Z0 = [(0, 0), (1.0, 0)]
# Each clip: frames, and curves of u in [0, 1]. yaw: body yaw (deg, + swings the rear to the right, -X; the rig faces -Y);
# tail: per-bone tail yaw (deg, + = club to the right), lagged down the chain; lift: Tail1 pitch (deg, + raises the club);
# curl: pitch of Tail2-5 each (deg, + curls the club up and over); crouch: body drop (mesh units); roll: body roll (deg);
# head: neck+head pitch (deg, + = nose up); look: neck+head yaw (deg, + = looks right); tremble: (u0, u1, cycles, deg).
# steps: (foot, u0, u1, yaw, out): the foot lifts at u0 and lands at u1 on its rest spot turned by yaw about PIVOT and set
# out by `out` mesh units to its own side; it is planted (unmoving) before and after. stamps: (foot, u0, u1, height).
CLIPS = {
    "attack_primary": dict(
        n=48, lag=0.02,
        yaw=[(0, 0), (0.18, -5), (0.48, -5), (0.58, 8), (0.66, 10), (0.80, 5), (1.0, 0)],
        tail=[(0, 0), (0.18, -18), (0.48, -20), (0.53, -2), (0.59, 22), (0.65, 27), (0.80, 12), (1.0, 0)],
        lift=[(0, 0), (0.18, 10), (0.48, 12), (0.56, 5), (0.70, 4), (1.0, 0)],
        curl=[(0, 0), (0.18, 3), (0.48, 3), (0.56, 0), (1.0, 0)],
        crouch=[(0, 0), (0.18, 0.006), (0.48, 0.008), (0.60, 0.011), (1.0, 0)],
        roll=[(0, 0), (0.18, -3), (0.48, -3), (0.60, 5), (1.0, 0)],
        head=[(0, 0), (0.18, -4), (0.48, -6), (0.60, -8), (1.0, 0)],
        look=[(0, 0), (0.18, 25), (0.48, 25), (0.62, 12), (1.0, 0)],
        tremble=(0.20, 0.48, 4.0, 2.5),
        stamps=[("FrontFoot.L", 0.26, 0.34, 0.02)],
        steps=[("BackFoot.R", 0.55, 0.64, 10, 0), ("BackFoot.L", 0.60, 0.69, 10, 0),
               ("BackFoot.R", 0.80, 0.89, 0, 0), ("BackFoot.L", 0.86, 0.95, 0, 0)]),
    "attack_heavy": dict(
        n=72, lag=0.015,
        yaw=[(0, 0), (0.15, 0), (0.45, -4), (0.60, -4), (0.66, 6), (0.80, 6), (1.0, 0)],
        tail=[(0, 0), (0.15, 0), (0.45, -4), (0.60, -4), (0.66, 8), (0.82, 8), (1.0, 0)],
        lift=[(0, 0), (0.12, 6), (0.45, 36), (0.60, 38), (0.655, -18), (0.70, -16), (0.82, -14), (1.0, 0)],
        curl=[(0, 0), (0.12, 2), (0.45, 15), (0.60, 16), (0.655, -2), (0.70, 0), (1.0, 0)],
        crouch=[(0, 0), (0.12, 0.012), (0.60, 0.014), (0.66, 0.020), (0.72, 0.012), (1.0, 0)],
        roll=Z0,
        head=[(0, 0), (0.12, -10), (0.60, -12), (0.66, -16), (0.80, -8), (1.0, 0)],
        look=[(0, 0), (0.15, 15), (0.60, 15), (1.0, 0)],
        tremble=(0.45, 0.60, 5.0, 3.0),
        steps=[("FrontFoot.L", 0.03, 0.12, 0, 0.03), ("FrontFoot.R", 0.08, 0.17, 0, 0.03),
               ("BackFoot.R", 0.63, 0.71, 6, 0), ("BackFoot.L", 0.68, 0.76, 6, 0),
               ("FrontFoot.L", 0.82, 0.90, 0, 0), ("FrontFoot.R", 0.87, 0.95, 0, 0),
               ("BackFoot.R", 0.84, 0.92, 0, 0), ("BackFoot.L", 0.89, 0.97, 0, 0)]),
    "tail_swipe": dict(
        n=62, lag=0.03,
        yaw=[(0, 0), (0.20, -6), (0.42, -6), (0.60, 10), (0.72, 16), (0.80, 16), (1.0, 0)],
        tail=[(0, 0), (0.20, -22), (0.42, -24), (0.50, -10), (0.60, 10), (0.70, 26), (0.80, 20), (1.0, 0)],
        lift=[(0, 0), (0.20, -2), (0.42, -3), (0.60, 2), (0.80, 4), (1.0, 0)],
        curl=Z0,
        crouch=[(0, 0), (0.20, 0.010), (0.70, 0.012), (1.0, 0)],
        roll=[(0, 0), (0.20, -4), (0.42, -4), (0.65, 6), (1.0, 0)],
        head=[(0, 0), (0.20, -6), (0.70, -6), (1.0, 0)],
        look=[(0, 0), (0.20, 30), (0.42, 30), (0.70, 0), (1.0, 0)],
        tremble=(0.22, 0.42, 3.0, 2.0),
        stamps=[("FrontFoot.R", 0.26, 0.33, 0.02)],
        steps=[("BackFoot.L", 0.46, 0.56, 8, 0), ("BackFoot.R", 0.52, 0.62, 16, 0), ("BackFoot.L", 0.62, 0.70, 16, 0),
               ("FrontFoot.L", 0.55, 0.63, 16, 0), ("FrontFoot.R", 0.60, 0.68, 16, 0),
               ("BackFoot.R", 0.80, 0.88, 0, 0), ("BackFoot.L", 0.85, 0.93, 0, 0),
               ("FrontFoot.L", 0.82, 0.89, 0, 0), ("FrontFoot.R", 0.88, 0.96, 0, 0)]),
    "alert": dict(
        n=38, lag=0.03,
        yaw=Z0,
        tail=[(0, 0), (0.25, -6), (0.75, -6), (1.0, 0)],
        lift=[(0, 0), (0.25, 12), (0.75, 12), (1.0, 0)],
        crouch=[(0, 0), (0.25, 0.012), (0.75, 0.012), (1.0, 0)],
        roll=Z0,
        head=[(0, 0), (0.22, 16), (0.78, 16), (1.0, 0)],
        tremble=(0.28, 0.72, 3.0, 5.0)),
    "sleep": dict(
        n=60, lag=0.04,
        yaw=Z0,
        tail=[(0, 0), (0.25, 0), (0.65, 13), (1.0, 13)],
        lift=[(0, 0), (0.3, 0), (0.6, -4), (1.0, -4)],
        crouch=[(0, 0), (0.15, 0.004), (0.55, 0.04), (1.0, 0.04)],
        roll=Z0,
        head=[(0, 0), (0.35, 0), (0.7, -14), (1.0, -14)],
        splay=[(0, 0), (0.15, 0), (0.55, 0.035), (1.0, 0.035)],
        reach=[(0, 0), (0.15, 0), (0.55, 0.03), (1.0, 0.03)],  # front paws forward, hind paws back: legs lie out flat
        tremble=None),
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
for pb in pbs:
    pb.rotation_mode = "QUATERNION"
upd = bpy.context.view_layer.update
fl = arm.data.bones["FrontFoot.L"].head_local
bl = arm.data.bones["BackFoot.L"].head_local
# Yaw pivot: a quarter of the way from the front feet to the hind feet, so the shoulders barely move over planted front
# feet and the hips (which step) carry the swing.
PIVOT = Vector((0.0, fl.y + 0.25 * (bl.y - fl.y), 0.0))
Z, X, Y = Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))
gi = {g.index: g.name for g in skin.vertex_groups}
TAIL_V = [v.index for v in skin.data.vertices if v.groups and gi[max(v.groups, key=lambda g: g.weight).group] in TAILS]
for pb in pbs:
    pb.matrix_basis.identity()
upd()
REST_FOOT = {foot: pbs[foot].matrix.copy() for _, _, foot in LEGS}


def about(pb, axis, deg, piv=None):
    m = pb.matrix.copy()
    p = m.translation.copy() if piv is None else piv
    pb.matrix = Matrix.Translation(p) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-p) @ m
    upd()


def solve_leg(up, low, foot):  # same analytic two-bone solve as transfer_clips.py, knee kept on its rest side
    h = pbs[up].head.copy(); knee0 = pbs[low].head.copy(); ankle = pbs[foot].head.copy()
    l1 = pbs[up].bone.length
    l2 = (arm.data.bones[low].head_local - arm.data.bones[foot].head_local).length
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


def plant(foot, yaw, out):
    m = Matrix.Translation(PIVOT) @ Matrix.Rotation(math.radians(yaw), 4, Z) @ Matrix.Translation(-PIVOT) @ REST_FOOT[foot]
    m.translation.x += out * (1 if foot.endswith("L") else -1)
    return m


def foot_at(c, foot, u):
    """The foot's matrix at u: planted on its latest landed step, or lifted on the arc of the step in progress."""
    cur = (0.0, 0.0)
    m, lift = None, 0.0
    for f, u0, u1, yaw, out in sorted((s for s in c.get("steps", []) if s[0] == foot), key=lambda s: s[1]):
        if u >= u1:
            cur = (yaw, out)
            continue
        if u > u0:
            t = (u - u0) / (u1 - u0)
            m = plant(foot, *cur).lerp(plant(foot, yaw, out), smooth(t))
            lift = 0.022 * math.sin(math.pi * t)
        break
    if m is None:
        m = plant(foot, *cur)
    for f, u0, u1, h in c.get("stamps", []):
        if f == foot and u0 < u < u1:
            lift = h * math.sin(math.pi * (u - u0) / (u1 - u0))
    m = m.copy()
    m.translation.z += lift
    return m


def low_z(idx=None):
    ev = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    vs = me.vertices if idx is None else [me.vertices[i] for i in idx]
    z = min((skin.matrix_world @ v.co).z for v in vs)
    ev.to_mesh_clear()
    return z


def pose(c, u):
    for pb in pbs:
        pb.matrix_basis.identity()
    upd()
    yaw = keys(u, c["yaw"])
    for _, _, foot in LEGS:
        m = foot_at(c, foot, u)
        if "splay" in c:  # sleep: feet slide out to the sides as the body settles (legs fold out, not through the belly)
            m.translation.x += keys(u, c["splay"]) * (1 if foot.endswith("L") else -1)
        if "reach" in c:
            m.translation.y += keys(u, c["reach"]) * (1 if foot.startswith("Back") else -1)
        pbs[foot].matrix = m
        upd()
    R = Matrix.Translation(PIVOT) @ Matrix.Rotation(math.radians(yaw), 4, Z) @ Matrix.Translation(-PIVOT)
    body = pbs["Body"]
    body.matrix = Matrix.Translation((0, 0, -keys(u, c["crouch"]))) @ R @ body.matrix
    upd()
    fwd = (Matrix.Rotation(math.radians(yaw), 3, Z) @ Y)
    about(body, fwd, keys(u, c["roll"]), body.matrix.translation.copy())
    # head counter-turns against the body yaw and looks toward the swing side (+look = right, a negative Z turn)
    look = keys(u, c.get("look"))
    about(pbs["Shoulders"], Z, -0.55 * yaw - 0.4 * look)
    about(pbs["Neck"], Z, -0.30 * yaw - 0.6 * look)
    side = Matrix.Rotation(math.radians(yaw * 0.15), 3, Z) @ X
    hp = keys(u, c["head"])
    about(pbs["Neck"], side, -0.6 * hp)  # rotating about +X lifts +Y; the head points -Y, so nose up is negative
    about(pbs["Head"], side, -0.4 * hp)
    # tail: lift at the root, curl down the chain, then the lagged yaw (the club whips after the root)
    tside = Matrix.Rotation(math.radians(yaw), 3, Z) @ X
    about(pbs["Tail1"], tside, keys(u, c["lift"]))
    curl = keys(u, c.get("curl"))
    tr = c["tremble"]
    for i, t in enumerate(TAILS):
        if i and curl:
            about(pbs[t], pbs[t].matrix.to_3x3().col[0].normalized(), curl)
        ang = keys(max(0.0, u - c["lag"] * i), c["tail"])
        if tr and tr[0] < u < tr[1]:
            s = (u - tr[0]) / (tr[1] - tr[0])
            ang += tr[3] * math.sin(2 * math.pi * tr[2] * s) * math.sin(math.pi * s) * (0.4 + 0.15 * i)
        about(pbs[t], Z, ang)
    # the club rests on the ground at most: a slam that would bury it raises the tail root until the skin touches 0
    for _ in range(12):
        if low_z(TAIL_V) >= 0.0:
            break
        about(pbs["Tail1"], tside, 1.5)
    for up, low, foot in LEGS:
        solve_leg(up, low, foot)
    # floor pass: a crouch must not push knee or belly skin through the ground; lift the Body (feet stay)
    for _ in range(4):  # re-solving the legs after a lift can tilt a shin under again: repeat until it holds
        lz = low_z()
        if lz >= -0.0005:
            break
        m = body.matrix.copy(); m.translation.z -= lz; body.matrix = m
        upd()
        for up, low, foot in LEGS:
            solve_leg(up, low, foot)


os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
for name in WANT:
    c = CLIPS[name]
    n = c["n"]
    frames = []
    for f in range(n):
        pose(c, f / (n - 1))
        frames.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in pbs})
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f, rows in enumerate(frames):
        for pb in pbs:
            pb.location, pb.rotation_quaternion = rows[pb.name]
            pb.keyframe_insert("location", frame=f + 1)
            pb.keyframe_insert("rotation_quaternion", frame=f + 1)
    sc.frame_start, sc.frame_end = 1, n
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
    print("WROTE", out, n, "frames")
    arm.animation_data.action = None
    for pb in pbs:
        pb.matrix_basis.identity()
