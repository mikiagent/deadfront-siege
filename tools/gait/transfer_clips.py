"""Move a species' clips onto a new mesh's rig with the same bone names (a remodel on the same donor skeleton).

Each bone replays the old clip's armature-space turn from rest (the two rigs' bone roll may differ, so local
channels would not carry over), the bones the clip translates (root, Body, the feet) move by their old offset
scaled by the leg-length ratio. The feet are authoritative (they are root children, so planting is exact): each frame the two-bone leg
chain is solved onto its foot, keeping the knee on the side the clip bent it, so a leg of new proportions still
meets its foot, and the Body is lifted wherever the skin would dip below the floor. Exports skeleton-only, like make_gait.py.

usage: Blender -b -P tools/gait/transfer_clips.py -- <old_base.glb> <new_base.glb> <out_dir> <clip.glb> [...]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OLD, NEW, OUT = argv[:3]
CLIPS = argv[3:]
LEGS = [("BackUpLeg." + s, "BackLowLeg." + s, "BackFoot." + s) for s in "LR"]


def import_arm(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = set(bpy.data.objects) - before
    return next(o for o in new if o.type == "ARMATURE"), new


def leg_len(arm):
    b = arm.data.bones
    return b[LEGS[0][0]].length + (b[LEGS[0][1]].head_local - b[LEGS[0][2]].head_local).length


bpy.ops.wm.read_factory_settings(use_empty=True)
old_arm, old_objs = import_arm(OLD)
K = None
new_arm, new_objs = import_arm(NEW)
skin = max((o for o in new_objs if o.type == "MESH" and o.find_armature() == new_arm), key=lambda o: len(o.data.vertices))
K = leg_len(new_arm) / leg_len(old_arm)
for o in old_objs:
    bpy.data.objects.remove(o, do_unlink=True)
print("TRANSFER leg ratio", round(K, 4))
pbs = new_arm.pose.bones
for pb in pbs:
    pb.rotation_mode = "QUATERNION"
sc = bpy.context.scene
sc.render.fps = 24


def solve_leg(up, low, foot):
    h = pbs[up].head.copy()
    knee0 = pbs[low].head.copy()
    ankle = pbs[foot].head.copy()
    l1 = pbs[up].bone.length
    l2 = (new_arm.data.bones[low].head_local - new_arm.data.bones[foot].head_local).length
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
        nm = (q.to_matrix() @ m.to_3x3()).to_4x4()
        nm.translation = p0
        pbs[bone].matrix = nm
        bpy.context.view_layer.update()


def order(arm):
    out = []
    def walk(b):
        out.append(b.name)
        for c in b.children:
            walk(c)
    for b in arm.data.bones:
        if b.parent is None:
            walk(b)
    return out


for path in CLIPS:
    name = os.path.splitext(os.path.basename(path))[0]
    src_arm, objs = import_arm(path)
    act = src_arm.animation_data.action
    f0, f1 = (int(round(x)) for x in act.frame_range)
    sb, spb = src_arm.data.bones, src_arm.pose.bones
    nb = new_arm.data.bones
    # bones the clip translates (root, Body, the root-parented feet) carry their scaled armature-space offset;
    # every other bone keeps its new parent-relative head
    sc.frame_set(f0)
    heads0 = {b: spb[b].head.copy() for b in spb.keys()}
    free = set()
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        for pb in spb:
            if pb.location.length > 1e-5:
                free.add(pb.name)
    frames = []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        for pb in pbs:
            pb.matrix_basis.identity()
        bpy.context.view_layer.update()
        for n in order(new_arm):
            if n not in spb:
                continue
            ms = spb[n].matrix
            rot = ms.to_3x3() @ sb[n].matrix_local.to_3x3().inverted()  # armature-space turn from rest
            nm = (rot @ nb[n].matrix_local.to_3x3()).to_4x4()
            if n in free:
                nm.translation = nb[n].head_local + (ms.translation - sb[n].head_local) * K
            else:
                nm.translation = pbs[n].matrix.translation
            pbs[n].matrix = nm
            bpy.context.view_layer.update()
        for up, low, foot in LEGS:
            solve_leg(up, low, foot)
        # floor pass: a thicker body than the old rig's must not sink when it lies down; lift the Body (feet stay)
        ev = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
        me = ev.to_mesh()
        low_z = min((skin.matrix_world @ v.co).z for v in me.vertices)
        ev.to_mesh_clear()
        if low_z < -0.002:
            m = pbs["Body"].matrix.copy()
            m.translation.z -= low_z
            pbs["Body"].matrix = m
            bpy.context.view_layer.update()
            for up, low, foot in LEGS:
                solve_leg(up, low, foot)
        frames.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in pbs})
    src_arm.animation_data.action = None
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    baked = bpy.data.actions.new(name)
    new_arm.animation_data_create()
    new_arm.animation_data.action = baked
    for i, f in enumerate(range(f0, f1 + 1)):
        for pb in pbs:
            loc, rot, scl = frames[i][pb.name]
            pb.location, pb.rotation_quaternion, pb.scale = loc, rot, scl
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("scale", frame=f)
    sc.frame_start, sc.frame_end = f0, f1
    # export this one action, skeleton only
    bpy.ops.object.select_all(action="DESELECT")
    new_arm.select_set(True)
    bpy.context.view_layer.objects.active = new_arm
    out = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=out, export_format="GLB", export_apply=False, export_yup=True,
        use_selection=True, export_animations=True, export_animation_mode="ACTIVE_ACTIONS",
        export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
        export_anim_slide_to_zero=False, export_skins=True, export_morph=False,
        export_def_bones=False, export_reset_pose_bones=False, export_current_frame=False,
        export_nla_strips=False, export_anim_single_armature=True, export_bake_animation=True,
        export_materials="NONE", export_image_format="NONE")
    print("WROTE", out, f1 - f0, "frames")
    for pb in pbs:
        pb.matrix_basis.identity()
    new_arm.animation_data.action = None
