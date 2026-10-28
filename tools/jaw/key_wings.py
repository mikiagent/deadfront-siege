#!/usr/bin/env python3
"""Key the Wing.L / Wing.R bones (tools/jaw/add_wings.py) into a creature's attack and leap clips: the wings flare on
the wind-up and the strike and fold back after. Clips not listed keep no wing keys, so the wings stay folded there.
Every other bone keeps its keys; clips are re-exported skeleton-only at their own fps.

  Blender -b --python tools/jaw/key_wings.py -- <base_with_wings.glb> <anim_dir> <out_dir> [--spread 80]

The spread swings each fan out to the side (about the vertical) and lifts it (about the body's long axis).
"""
import argparse, json, math, pathlib, struct, sys
import bpy
from mathutils import Matrix

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("anim_dir"); ap.add_argument("out_dir")
ap.add_argument("--spread", type=float, default=80, help="full flare in degrees (exaggerated by default)")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

def smooth(x): x = min(max(x, 0.0), 1.0); return x * x * (3 - 2 * x)
def ramp(u, up0, up1, dn0, dn1): return smooth((u - up0) / max(up1 - up0, 1e-6)) * (1 - smooth((u - dn0) / max(dn1 - dn0, 1e-6)))

ev = json.load(open(pathlib.Path(__file__).resolve().parents[2] / "game/data/creatures/anim_events.json"))["clips"]
def hit(c, d): return float(ev.get(c, {}).get("hit_frac", d))

def combo(u):  # half flare on the side chomps, full and held through the MEGA chomp
    h = ev.get("bite_combo", {}).get("hit_fracs", [0.092, 0.338, 0.815])
    return max(0.55 * ramp(u, h[0] - 0.08, h[0] - 0.02, h[0] + 0.05, h[0] + 0.15),
               0.55 * ramp(u, h[1] - 0.08, h[1] - 0.02, h[1] + 0.05, h[1] + 0.15),
               ramp(u, h[2] - 0.32, h[2] - 0.2, h[2] + 0.08, h[2] + 0.18))

def airborne(c):
    lo, hi = ev.get(c, {}).get("airborne", [0.2, 0.65])
    return lambda u: ramp(u, lo - 0.12, lo + 0.05, hi - 0.05, hi + 0.15)

CURVES = {  # clip -> flare 0..1 at normalised time u
    "attack_primary": lambda u: ramp(u, hit("attack_primary", 0.42) - 0.3, hit("attack_primary", 0.42) - 0.05,
                                     hit("attack_primary", 0.42) + 0.1, hit("attack_primary", 0.42) + 0.35),
    "attack_heavy": lambda u: ramp(u, 0.1, 0.35, hit("attack_heavy", 0.72) + 0.05, hit("attack_heavy", 0.72) + 0.25),
    "alert": lambda u: ramp(u, 0.1, 0.3, 0.75, 0.95),
    "bite_combo": combo,
    "hop_back": airborne("hop_back"),
    "leap_back": airborne("leap_back"),
    "pounce": airborne("pounce"),
    "dodge_left": airborne("dodge_left"),
    "dodge_right": airborne("dodge_right"),
}

def src_fps(path):
    b = path.read_bytes(); n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + n])
    acc = max((j["accessors"][s["input"]] for s in j["animations"][0]["samplers"]), key=lambda x: x["count"])
    return round((acc["count"] - 1) / max(acc["max"][0] - acc["min"][0], 1e-6))

def spread(pb, sgn, amount):
    m = pb.matrix.copy(); piv = m.translation.copy()
    deg = a.spread * amount
    pb.matrix = (Matrix.Translation(piv) @ Matrix.Rotation(math.radians(-sgn * deg), 4, "Z")
                 @ Matrix.Rotation(math.radians(-sgn * deg * 0.45), 4, "Y") @ Matrix.Translation(-piv) @ m)

out = pathlib.Path(a.out_dir); out.mkdir(parents=True, exist_ok=True)
for clip, curve in CURVES.items():
    src = pathlib.Path(a.anim_dir) / f"{clip}.glb"
    if not src.exists(): continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = src_fps(src)
    bpy.ops.import_scene.gltf(filepath=a.base)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in [o for o in bpy.data.objects if o is not arm]: bpy.data.objects.remove(o)
    before = set(bpy.data.objects); acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(src))
    act = next(iter(set(bpy.data.actions) - acts)); act.name = clip
    for o in set(bpy.data.objects) - before: bpy.data.objects.remove(o)
    arm.animation_data_create(); arm.animation_data.action = act
    if len(act.slots): arm.animation_data.action_slot = act.slots[0]
    f0, f1 = (int(round(x)) for x in act.frame_range)
    peak = 0.0
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        amt = curve((f - f0) / max(f1 - f0, 1)); peak = max(peak, amt)
        for side, sgn in (("L", 1), ("R", -1)):
            pb = arm.pose.bones[f"Wing.{side}"]; pb.rotation_mode = "QUATERNION"
            pb.matrix_basis = Matrix.Identity(4)
            bpy.context.view_layer.update()
            spread(pb, sgn, amt)
            bpy.context.view_layer.update()
            pb.keyframe_insert("rotation_quaternion", frame=f)
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = f0, f1
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(out / f"{clip}.glb"), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_yup=True)
    print(f"WINGS {clip}: frames {f0}-{f1}, peak flare {peak:.2f}")
