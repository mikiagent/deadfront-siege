#!/usr/bin/env python3
"""Retarget humanoid FBX clips (KevDev / Kevin Iglesias "Human" rig) onto the survivor's
24-bone Meshy skeleton and write one animation GLB per clip in the contract layout.

Blender headless. Both rigs are T-posed and face -Y in Blender, so each target bone takes the
source bone's armature-space rotation delta from rest (src_pose * src_rest^-1 * tgt_rest). The
hips also take the source hips' translation delta, scaled by hip height. Every other
bone keeps its rest offset. The exported GLB carries the survivor armature plus a one-triangle
proxy skin so Godot builds a Skeleton3D and RiggedModel can remap the tracks by bone name.

Usage (from the repo root):
  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/retarget_human.py -- \
      --target game/assets/characters/survivor/survivor.glb \
      --out game/assets/characters/survivor/anim \
      gather="/path/HumanF@Gathering01.fbx" craft="/path/HumanF@HammeringGround01_R - Loop.fbx:1-60"
Each positional is clip=path[:start-end] (frames, inclusive, in the source file's numbering).
"""
import argparse
import json
import math
import pathlib
import sys

import bpy
from mathutils import Matrix, Vector

# source bone -> target bone(s). World-space deltas make mapping one source to two chained
# target bones correct (both take the same world orientation).
MAP = {
    "B-hips": ["Hips"],
    "B-spine": ["Spine02"],
    "B-chest": ["Spine01", "Spine"],
    "B-neck": ["neck"],
    "B-head": ["Head"],
    "B-shoulder.L": ["LeftShoulder"], "B-upperArm.L": ["LeftArm"], "B-forearm.L": ["LeftForeArm"], "B-hand.L": ["LeftHand"],
    "B-shoulder.R": ["RightShoulder"], "B-upperArm.R": ["RightArm"], "B-forearm.R": ["RightForeArm"], "B-hand.R": ["RightHand"],
    "B-thigh.L": ["LeftUpLeg"], "B-shin.L": ["LeftLeg"], "B-foot.L": ["LeftFoot"], "B-toe.L": ["LeftToeBase"],
    "B-thigh.R": ["RightUpLeg"], "B-shin.R": ["RightLeg"], "B-foot.R": ["RightFoot"], "B-toe.R": ["RightToeBase"],
}
ROOT_SRC, ROOT_TGT = "B-hips", "Hips"


def log(*a):
    print("[retarget]", *a, flush=True)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("clips", nargs="+")
    return ap.parse_args(argv)


def import_target(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    for o in new:
        if o.type != "ARMATURE":
            bpy.data.objects.remove(o, do_unlink=True)
    if arm.animation_data:
        arm.animation_data.action = None
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    return arm


def import_source(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    act = arm.animation_data.action if arm.animation_data else None
    if act is None:
        raise SystemExit("no action in %s" % path)
    return arm, act


def add_proxy_skin(arm):
    """One triangle skinned to every bone so the glTF export carries a skin (Godot then makes a
    Skeleton3D and the animation tracks resolve to bones)."""
    me = bpy.data.meshes.new("proxy")
    me.from_pydata([(0, 0, 0), (0.01, 0, 0), (0, 0.01, 0)], [], [(0, 1, 2)])
    ob = bpy.data.objects.new("proxy", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = arm
    for b in arm.data.bones:
        vg = ob.vertex_groups.new(name=b.name)
        vg.add([0, 1, 2], 1.0 / len(arm.data.bones), "REPLACE")
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


def retarget(tgt, src, act, clip, frame_range, fps):
    """Everything is computed in armature-local space. Both rigs import upright, facing -Y, in
    centimetre bone units under a 0.01 armature scale, and the KevDev soldier/throwing packs
    carry a 90-degree object rotation plus a wandering B-root that Blender 5.2 turns into a
    94 m hip offset in world space, so world space is exactly what we must not use. The source
    pose is taken relative to its B-root bone (in-place clips lose nothing; root-motion
    variants are not used)."""
    scene = bpy.context.scene
    scene.render.fps = fps
    f0, f1 = frame_range
    scene.frame_start, scene.frame_end = f0, f1

    tgt_rest = {b.name: b.matrix_local.to_3x3().normalized() for b in tgt.data.bones}
    src_rest = {b.name: b.matrix_local.to_3x3().normalized() for b in src.data.bones}
    src_root_rest_pos = src.data.bones[ROOT_SRC].head_local.copy()
    tgt_root_rest_pos = tgt.data.bones[ROOT_TGT].head_local.copy()
    height_ratio = tgt_root_rest_pos.z / max(1e-6, src_root_rest_pos.z)
    src_root_bone = src.data.bones.get("B-root")

    tgt_of = {}
    for s, ts in MAP.items():
        if s not in src.data.bones:
            log("source bone missing", s)
            continue
        for t in ts:
            if t in tgt.data.bones:
                tgt_of[t] = s

    act_new = bpy.data.actions.new(clip)
    if not tgt.animation_data:
        tgt.animation_data_create()
    tgt.animation_data.action = act_new
    for pb in tgt.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.matrix_basis = Matrix.Identity(4)

    order = []
    def walk(b):
        order.append(b.name)
        for c in b.children:
            walk(c)
    for b in tgt.data.bones:
        if b.parent is None:
            walk(b)

    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        # source pose in armature space, relative to the root bone's pose delta
        if src_root_bone is not None:
            root_pb = src.pose.bones["B-root"]
            root_fix = (root_pb.matrix @ src_root_bone.matrix_local.inverted()).inverted()
        else:
            root_fix = Matrix.Identity(4)
        src_pose = {pb.name: (root_fix @ pb.matrix) for pb in src.pose.bones}
        pose_a = {}
        for name in order:
            bone = tgt.data.bones[name]
            pb = tgt.pose.bones[name]
            rest_a = bone.matrix_local
            if bone.parent:
                base = pose_a[bone.parent.name] @ bone.parent.matrix_local.inverted() @ rest_a
            else:
                base = rest_a.copy()
            s = tgt_of.get(name)
            if s is None:
                pb.matrix_basis = Matrix.Identity(4)
                pose_a[name] = base
                continue
            R_src = src_pose[s].to_3x3().normalized()
            R_a = R_src @ src_rest[s].inverted() @ tgt_rest[name]
            P = R_a.to_4x4()
            if name == ROOT_TGT:
                delta = (src_pose[s].to_translation() - src_root_rest_pos) * height_ratio
                P.translation = rest_a.to_translation() + delta
            else:
                P.translation = base.to_translation()
            basis = base.inverted() @ P
            pb.matrix_basis = basis
            pose_a[name] = P
            pb.keyframe_insert("rotation_quaternion", frame=f)
            if name == ROOT_TGT:
                pb.keyframe_insert("location", frame=f)
    return act_new


def export(tgt, proxy, out_path):
    bpy.ops.object.select_all(action="DESELECT")
    tgt.select_set(True)
    proxy.select_set(True)
    bpy.context.view_layer.objects.active = tgt
    bpy.ops.export_scene.gltf(
        filepath=str(out_path), export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="ACTIVE_ACTIONS",
        export_force_sampling=True, export_frame_range=True, export_optimize_animation_size=False,
        export_materials="NONE", export_texcoords=False, export_normals=False,
        export_skins=True, export_def_bones=False, export_apply=False, export_yup=True,
    )


def main():
    args = parse_args()
    out_dir = pathlib.Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    report = {}
    for spec in args.clips:
        clip, rest = spec.split("=", 1)
        rng = None
        if ":" in rest and rest.rsplit(":", 1)[1].replace("-", "").isdigit():
            rest, r = rest.rsplit(":", 1)
            a, b = r.split("-")
            rng = (int(a), int(b))
        bpy.ops.wm.read_factory_settings(use_empty=True)
        tgt = import_target(args.target)
        src, act = import_source(rest)
        fr = act.frame_range
        frame_range = rng or (int(round(fr[0])), int(round(fr[1])))
        retarget(tgt, src, act, clip, frame_range, args.fps)
        bpy.data.objects.remove(src, do_unlink=True)
        proxy = add_proxy_skin(tgt)
        out = out_dir / ("%s.glb" % clip)
        export(tgt, proxy, out)
        secs = (frame_range[1] - frame_range[0]) / float(args.fps)
        report[clip] = {"source": pathlib.Path(rest).name, "frames": list(frame_range), "seconds": round(secs, 3), "bytes": out.stat().st_size}
        log(clip, json.dumps(report[clip]))
    print("RETARGET " + json.dumps(report))


main()
