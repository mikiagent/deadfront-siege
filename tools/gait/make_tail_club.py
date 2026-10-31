"""ANKYLO3D: the ankylosaurus' tail-club clips, keyed from rest on the transplant skeleton (Triceratops donor bones).

attack_primary  1.25 s: cock the tail to the left, then whip it to the right; the club passes the right flank at
                hit_frac 0.42 (anim_events.json), overshoots and settles back.
attack_heavy    2.0 s: braced telegraph (tail cocked far and high, body low, a tremble while it holds), then a full
                swing that lands at hit_frac 0.72, follow-through, recover.
alert           1.6 s: head comes up, body drops low and wide, the club lifts and rattles.
sleep           2.5 s, not looped (the game holds the last frame): settles belly-down on the ground, legs folded out to
                the sides, chin down, the tail curled round to the right with the club resting on the ground.

Body yaw pivots about the front feet, so the hindquarters swing with the tail; all four feet follow that yaw (the
hind ones scramble: they lift while the yaw is fast) and the legs are solved onto them every frame, so nothing
slides through the floor. The head counter-turns to keep facing the target. Exports skeleton-only like make_gait.py.

usage: Blender -b -P tools/gait/make_tail_club.py -- <base.glb> <out_dir> [clip ...]
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, OUT = argv[:2]
WANT = argv[2:] or ["attack_primary", "attack_heavy", "alert", "sleep"]
FPS = 24
TAILS = ["Tail1", "Tail2", "Tail3", "Tail4", "Tail5"]
LEGS = [(f"{e}UpLeg.{s}", f"{e}LowLeg.{s}", f"{e}Foot.{s}") for e in ("Back", "Front") for s in ("L", "R")]


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def keys(u, pts):
    """Piecewise smoothstep through (u, value) points."""
    if u <= pts[0][0]:
        return pts[0][1]
    for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
        if u <= u1:
            return v0 + (v1 - v0) * smooth((u - u0) / max(u1 - u0, 1e-6))
    return pts[-1][1]


# Each clip: frames, and curves of u in [0, 1]. yaw: body yaw (deg, + swings the rear to the right, -X);
# tail: per-bone tail yaw (deg, + = club to the right), lagged down the chain; lift: tail pitch (deg, + raises the club);
# crouch: body drop (mesh units); roll: body roll (deg); head: neck+head pitch (deg, + = nose up); tremble: deg.
CLIPS = {
    "attack_primary": dict(
        n=30, lag=0.03,
        yaw=[(0, 0), (0.24, -10), (0.42, 26), (0.55, 30), (1.0, 0)],
        tail=[(0, 0), (0.24, -15), (0.36, 18), (0.46, 23), (0.62, 14), (1.0, 0)],
        lift=[(0, 0), (0.24, 10), (0.40, 6), (0.6, 4), (1.0, 0)],
        crouch=[(0, 0), (0.24, 0.008), (0.45, 0.010), (1.0, 0)],
        roll=[(0, 0), (0.24, -4), (0.44, 5), (1.0, 0)],
        head=[(0, 0), (0.24, 4), (0.44, -6), (1.0, 0)],
        tremble=None),
    "attack_heavy": dict(
        n=48, lag=0.02,
        yaw=[(0, 0), (0.32, -16), (0.60, -18), (0.72, 34), (0.82, 38), (1.0, 0)],
        tail=[(0, 0), (0.32, -19), (0.60, -20), (0.68, 20), (0.76, 26), (0.88, 14), (1.0, 0)],
        lift=[(0, 0), (0.32, 16), (0.60, 18), (0.72, 6), (0.85, 4), (1.0, 0)],
        crouch=[(0, 0), (0.32, 0.009), (0.60, 0.010), (0.75, 0.008), (1.0, 0)],
        roll=[(0, 0), (0.32, -5), (0.60, -5), (0.74, 6), (1.0, 0)],
        head=[(0, 0), (0.32, -8), (0.60, -9), (0.74, -4), (1.0, 0)],
        tremble=(0.34, 0.60, 4.0, 2.0)),  # u0, u1, cycles, degrees on the cocked tail
    "alert": dict(
        n=38, lag=0.03,
        yaw=[(0, 0), (1.0, 0)],
        tail=[(0, 0), (0.25, -6), (0.75, -6), (1.0, 0)],
        lift=[(0, 0), (0.25, 12), (0.75, 12), (1.0, 0)],
        crouch=[(0, 0), (0.25, 0.012), (0.75, 0.012), (1.0, 0)],
        roll=[(0, 0), (1.0, 0)],
        head=[(0, 0), (0.22, 16), (0.78, 16), (1.0, 0)],
        tremble=(0.28, 0.72, 3.0, 5.0)),
    "sleep": dict(
        n=60, lag=0.04,
        yaw=[(0, 0), (1.0, 0)],
        tail=[(0, 0), (0.25, 0), (0.65, 13), (1.0, 13)],
        lift=[(0, 0), (0.3, 0), (0.6, -4), (1.0, -4)],
        crouch=[(0, 0), (0.15, 0.004), (0.55, 0.04), (1.0, 0.04)],
        roll=[(0, 0), (1.0, 0)],
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
fl, fr = arm.data.bones["FrontFoot.L"].head_local, arm.data.bones["FrontFoot.R"].head_local
PIVOT = Vector(((fl.x + fr.x) / 2, (fl.y + fr.y) / 2, 0.0))  # between the front feet
Z, X, Y = Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))


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


def pose(c, u, du):
    for pb in pbs:
        pb.matrix_basis.identity()
    upd()
    yaw = keys(u, c["yaw"])
    # feet: follow the body yaw about the pivot; lift while the yaw moves fast (scrambling steps), hind more than front
    speed = abs(keys(min(u + du, 1), c["yaw"]) - keys(max(u - du, 0), c["yaw"])) / (2 * du) / 400.0
    R = Matrix.Translation(PIVOT) @ Matrix.Rotation(math.radians(yaw), 4, Z) @ Matrix.Translation(-PIVOT)
    for i, (_, _, foot) in enumerate(LEGS):
        hind = foot.startswith("Back")
        phase = (u * 9.0 + (0.5 if foot.endswith("R") else 0.0) + (0.25 if hind else 0.0)) % 1.0
        lift = min(1.0, speed) * (0.016 if hind else 0.008) * max(0.0, math.sin(math.pi * phase * 2.0))
        m = R @ pbs[foot].matrix.copy()
        m.translation.z += lift
        if "splay" in c:  # feet slide out to the sides as the body settles (legs fold out, not through the belly)
            m.translation.x += keys(u, c["splay"]) * (1 if foot.endswith("L") else -1)
        if "reach" in c:
            m.translation.y += keys(u, c["reach"]) * (1 if hind else -1)
        pbs[foot].matrix = m
        upd()
    body = pbs["Body"]
    body.matrix = Matrix.Translation((0, 0, -keys(u, c["crouch"]))) @ R @ body.matrix
    upd()
    fwd = (Matrix.Rotation(math.radians(yaw), 3, Z) @ Y)
    about(body, fwd, keys(u, c["roll"]), body.matrix.translation.copy())
    # head counter-turns to keep facing the target, and pitches
    about(pbs["Shoulders"], Z, -0.55 * yaw)
    about(pbs["Neck"], Z, -0.30 * yaw)
    side = Matrix.Rotation(math.radians(yaw * 0.15), 3, Z) @ X
    hp = keys(u, c["head"])
    about(pbs["Neck"], side, -0.6 * hp)  # rotating about +X lifts +Y; the head points -Y, so nose up is negative
    about(pbs["Head"], side, -0.4 * hp)
    # tail: lift at the root, then the lagged yaw down the chain (the club whips after the root)
    about(pbs["Tail1"], Matrix.Rotation(math.radians(yaw), 3, Z) @ X, keys(u, c["lift"]))
    tr = c["tremble"]
    for i, t in enumerate(TAILS):
        ang = keys(max(0.0, u - c["lag"] * i), c["tail"])
        if tr and tr[0] < u < tr[1]:
            s = (u - tr[0]) / (tr[1] - tr[0])
            ang += tr[3] * math.sin(2 * math.pi * tr[2] * s) * math.sin(math.pi * s) * (0.4 + 0.15 * i)
        about(pbs[t], Z, ang)
    for up, low, foot in LEGS:
        solve_leg(up, low, foot)
    # floor pass: a crouch or a scramble must not push knee or belly skin through the ground; lift the Body (feet stay)
    ev = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = ev.to_mesh()
    low_z = min((skin.matrix_world @ v.co).z for v in me.vertices)
    ev.to_mesh_clear()
    if low_z < -0.0005:
        m = body.matrix.copy(); m.translation.z -= low_z; body.matrix = m
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
        u = f / (n - 1)
        pose(c, u, 1.0 / (n - 1))
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
