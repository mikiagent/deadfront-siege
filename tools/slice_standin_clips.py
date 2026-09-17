#!/usr/bin/env python3
"""Turn a single-track stand-in GLB into the creature contract layout.

Blender headless script. The Gobkit CC0 dinosaurs ship ONE baked action per
model (idle 0-29, attack 30-59, dead 60-89, walk 90-119 @ 24 fps). The game's
contract (game/data/creatures/SCHEMA.md) wants <species>.glb with no clips plus
anim/<clip>.glb, one file per named clip. This script slices the track by frame
range, renames each slice to a contract clip, and exports.

Usage (from the repo root):
  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/slice_standin_clips.py -- \
      --glb tools/standins/gobkit/Carnotaurus.glb --species utahraptor \
      --map idle=0-29 attack_primary=30-59 attack_heavy=30-59 death=60-89 knockdown=60-89 walk=90-119 run=90-119

Prints a JSON line starting with PIPELINE that carries forward_axis and
source_height_m for the species JSON pipeline block.
"""
import argparse
import json
import math
import pathlib
import sys

import bpy
from mathutils import Vector

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "creatures"
FPS = 24


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--species", required=True)
    p.add_argument("--map", nargs="+", required=True, help="clip=start-end frame ranges")
    p.add_argument("--source-action", default="dino")
    return p.parse_args(argv)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def find_armature():
    for o in bpy.data.objects:
        if o.type == "ARMATURE":
            return o
    sys.exit("no armature in GLB")


def measure(arm):
    """World bounds of all meshes in rest pose, and which glTF axis the head faces."""
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    size = hi - lo
    # Facing: head bone relative to hips, projected on the ground plane.
    bones = arm.data.bones
    head = next((b for b in bones if b.name.lower() in ("head", "head_01", "neck")), None)
    hips = next((b for b in bones if b.name.lower() in ("hips", "pelvis", "root")), None)
    forward = "-Z"
    if head and hips:
        d = (arm.matrix_world @ head.head_local) - (arm.matrix_world @ hips.head_local)
        d.z = 0.0
        if d.length > 1e-6:
            # Blender is Z-up, -Y forward. glTF is Y-up, +Z forward. Blender -Y == glTF +Z.
            if abs(d.x) > abs(d.y):
                forward = "+X" if d.x > 0 else "-X"
            else:
                forward = "+Z" if d.y < 0 else "-Z"
    return {"source_height_m": round(size.z, 4), "source_length_m": round(max(size.x, size.y), 4),
            "forward_axis": forward}


def fcurve_groups(act):
    """Every F-Curve collection in an action. Blender 4.4+ stores them in
    layers > strips > channelbags; older builds expose action.fcurves."""
    if hasattr(act, "layers") and len(act.layers):
        return [cb.fcurves for layer in act.layers for strip in layer.strips for cb in strip.channelbags]
    return [act.fcurves]


def slice_action(src, name, start, end):
    """Copy `src`, keep keys in [start, end], shift so the clip starts at frame 0."""
    act = src.copy()
    act.name = name
    act.use_fake_user = False
    for fc in [fc for group in fcurve_groups(act) for fc in group]:
        keep = [(k.co.x, k.co.y, k.interpolation) for k in fc.keyframe_points if start <= k.co.x <= end]
        # Sample the boundary frames so a range that starts between keys still starts on-pose.
        for f in (start, end):
            if not any(abs(k[0] - f) < 1e-3 for k in keep):
                keep.append((f, fc.evaluate(f), "LINEAR"))
        keep.sort()
        n = len(fc.keyframe_points)
        for i in range(n - 1, -1, -1):
            fc.keyframe_points.remove(fc.keyframe_points[i], fast=True)
        fc.keyframe_points.add(len(keep))
        for kp, (x, y, interp) in zip(fc.keyframe_points, keep):
            kp.co = (x - start, y)
            kp.interpolation = interp
        fc.update()
    try:
        act.use_frame_range = True
        act.frame_range = (0, end - start)
    except (AttributeError, TypeError):
        pass
    return act


def export(path, animations, arm=None, action=None, frame_end=0):
    path.parent.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    if action is not None:
        if arm.animation_data is None:
            arm.animation_data_create()
        arm.animation_data.action = action
        if hasattr(arm.animation_data, "action_slot") and len(action.slots):
            arm.animation_data.action_slot = action.slots[0]
        scene.frame_start = 0
        scene.frame_end = int(frame_end)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=False,
        export_animations=animations, export_animation_mode="ACTIVE_ACTIONS",
        export_frame_range=True, export_force_sampling=True, export_optimize_animation_size=False,
        export_skins=True, export_yup=True, export_apply=False)
    print(f"  wrote {path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")


def main():
    a = parse_args()
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(ROOT / a.glb))
    arm = find_armature()
    src = bpy.data.actions.get(a.source_action)
    if src is None:
        sys.exit(f"action {a.source_action!r} not found; have {[x.name for x in bpy.data.actions]}")
    # Drop every other action so the exporter never picks them up.
    for act in list(bpy.data.actions):
        if act is not src:
            bpy.data.actions.remove(act)
    info = measure(arm)
    dest = OUT / a.species

    # Base mesh, no clips.
    if arm.animation_data:
        arm.animation_data.action = None
    export(dest / f"{a.species}.glb", animations=False)

    clips = {}
    for spec in a.map:
        name, rng = spec.split("=")
        start, end = (int(x) for x in rng.split("-"))
        act = slice_action(src, name, start, end)
        export(dest / "anim" / f"{name}.glb", animations=True, arm=arm, action=act, frame_end=end - start)
        clips[name] = {"frames": [start, end], "seconds": round((end - start) / FPS, 3)}
        arm.animation_data.action = None
        bpy.data.actions.remove(act)

    (dest / "work").mkdir(exist_ok=True)
    (dest / "work" / ".gdignore").touch()
    print("PIPELINE " + json.dumps({"species": a.species, "source": a.glb, "clips": clips, **info}))


if __name__ == "__main__":
    main()
