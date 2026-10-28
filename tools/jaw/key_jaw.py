#!/usr/bin/env python3
"""Key the Jaw bone into existing clips: the bite chomps (wide wind-up, one-frame snap on the hit, head lunge), the roar opens wide and
holds, eating chews. Every other bone keeps its keys; the clip is re-exported skeleton-only like the originals.

  Blender -b --python tools/jaw/key_jaw.py -- <base_with_jaw.glb> <anim_dir> <out_dir> [--hit 0.42]
      [--bite 40] [--roar 36] [--chew 18] [--heavy 30] [--lunge 14]

Angles are degrees about the Jaw bone's local X (positive opens, checked with render_head.py --jaw).
"""
import argparse, json, math, pathlib, struct, sys
import bpy
from mathutils import Matrix, Quaternion

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("anim_dir"); ap.add_argument("out_dir")
ap.add_argument("--hit", type=float, default=0.42, help="attack_primary hit fraction (anim_events.json)")
ap.add_argument("--heavy-hit", type=float, default=0.72)
ap.add_argument("--bite", type=float, default=40); ap.add_argument("--roar", type=float, default=36)
ap.add_argument("--chew", type=float, default=18)
ap.add_argument("--lunge", type=float, default=14, help="bite head pitch into the snap, degrees (0 = off)")
ap.add_argument("--lunge-sign", type=float, default=1.0); ap.add_argument("--heavy", type=float, default=30)
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

def smooth(x): x = min(max(x, 0.0), 1.0); return x * x * (3 - 2 * x)

def ramp(u, up0, up1, dn0, dn1):  # 0 -> 1 between up0..up1, back to 0 between dn0..dn1
    return smooth((u - up0) / max(up1 - up0, 1e-6)) * (1 - smooth((u - dn0) / max(dn1 - dn0, 1e-6)))

def chomp(u):
    """Bite: wide wind-up, snap shut in about one frame on the hit with a slight clench past closed, then a small
    recoil gape that settles. The hit frame and clip length stay where combat expects them."""
    if u < a.hit:
        return a.bite * ramp(u, a.hit - 0.35, a.hit - 0.10, a.hit - 0.04, a.hit) - 3.0 * ramp(u, a.hit - 0.04, a.hit, 1, 1)
    return -3.0 * (1 - smooth((u - a.hit) / 0.06)) + 0.25 * a.bite * ramp(u, a.hit + 0.08, a.hit + 0.18, a.hit + 0.25, a.hit + 0.45)

def lunge(u):  # head pitches down and forward into the snap (degrees), back out over the recoil
    return a.lunge * ramp(u, a.hit - 0.12, a.hit, a.hit + 0.04, a.hit + 0.30)

CURVES = {  # clip -> degrees at normalised time u
    "attack_primary": chomp,
    "attack_heavy": lambda u: a.heavy * ramp(u, a.heavy_hit - 0.35, a.heavy_hit - 0.10, a.heavy_hit - 0.04, a.heavy_hit),
    "alert": lambda u: a.roar * ramp(u, 0.15, 0.35, 0.75, 0.92),
    "feed": lambda u: a.chew * ramp(u, 0.15, 0.2, 0.8, 0.9) * (0.5 - 0.5 * math.cos(u * 2 * math.pi * 4)),
    "idle": lambda u: 2.0 * (0.5 - 0.5 * math.cos(u * 2 * math.pi)),  # breathing; first == last for the loop
}

def src_fps(path):  # author at the clip's own rate, or integer frames shift its length (24 fps sources exist)
    b = path.read_bytes(); n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + n])
    acc = max((j["accessors"][s["input"]] for s in j["animations"][0]["samplers"]), key=lambda a: a["count"])  # constant tracks have 2 keys
    return round((acc["count"] - 1) / max(acc["max"][0] - acc["min"][0], 1e-6))

out = pathlib.Path(a.out_dir); out.mkdir(parents=True, exist_ok=True)
for clip, curve in CURVES.items():
    src = pathlib.Path(a.anim_dir) / f"{clip}.glb"
    if not src.exists(): continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = src_fps(src)
    bpy.ops.import_scene.gltf(filepath=a.base)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in [o for o in bpy.data.objects if o is not arm]: bpy.data.objects.remove(o)  # skeleton-only, like the clips
    before = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(src))
    act = next(iter(set(bpy.data.actions) - acts)); act.name = clip
    for o in set(bpy.data.objects) - before: bpy.data.objects.remove(o)
    arm.animation_data_create(); arm.animation_data.action = act
    if len(act.slots): arm.animation_data.action_slot = act.slots[0]
    f0, f1 = (int(round(x)) for x in act.frame_range)
    pb = arm.pose.bones["Jaw"]; pb.rotation_mode = "QUATERNION"
    peak = 0.0
    for f in range(f0, f1 + 1):
        u = (f - f0) / max(f1 - f0, 1)
        deg = curve(u); peak = max(peak, deg)
        pb.rotation_quaternion = Quaternion((1, 0, 0), math.radians(deg))
        pb.keyframe_insert("rotation_quaternion", frame=f)
    if clip == "attack_primary" and a.lunge:
        # add the lunge on top of the clip's own Head keys: a pitch about the armature's side axis at the head joint
        hb = arm.pose.bones["Head"]; hb.rotation_mode = "QUATERNION"
        for f in range(f0, f1 + 1):
            bpy.context.scene.frame_set(f)
            ang = math.radians(a.lunge_sign * lunge((f - f0) / max(f1 - f0, 1)))
            m = hb.matrix.copy(); piv = m.translation.copy()
            r = Matrix.Translation(piv) @ Matrix.Rotation(ang, 4, "X") @ Matrix.Translation(-piv)
            hb.matrix = r @ m
            bpy.context.view_layer.update()
            hb.keyframe_insert("rotation_quaternion", frame=f)
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = f0, f1
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out / f"{clip}.glb"), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_yup=True)
    print(f"KEYED {clip}: {bpy.context.scene.render.fps} fps, frames {f0}-{f1}, jaw peak {peak:.0f} deg")
