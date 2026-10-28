#!/usr/bin/env python3
"""Build a three-bite combo clip ("chomp, Chomp, CHOMP") from a species' own bite.

The body motion of each bite is the source attack_primary replayed over its segment; the jaw opens wider and the
head lunges harder on every bite, and the third bite gets a held wind-up the player can read and roll through.
Exports skeleton-only like the other clips and prints the hit fractions for anim_events.json.

  Blender -b --python tools/jaw/make_combo.py -- <base_with_jaw.glb> <attack_primary.glb> <out.glb> [--hit 0.42]
"""
import argparse, json, math, struct, sys
import bpy
from mathutils import Matrix, Quaternion

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("bite"); ap.add_argument("out")
ap.add_argument("--hit", type=float, default=0.42, help="hit fraction of the source bite")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

# (frames, jaw degrees, lunge degrees, wind-up hold frames before the bite)
BITES = [(14, 26, 8, 0), (14, 36, 14, 0), (18, 50, 22, 8)]

b = open(a.bite, "rb").read(); n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + n])
acc = max((j["accessors"][s["input"]] for s in j["animations"][0]["samplers"]), key=lambda x: x["count"])
fps = round((acc["count"] - 1) / max(acc["max"][0] - acc["min"][0], 1e-6))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = fps
bpy.ops.import_scene.gltf(filepath=a.base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in [o for o in bpy.data.objects if o is not arm]: bpy.data.objects.remove(o)
before = set(bpy.data.objects); acts = set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=a.bite)
src = next(iter(set(bpy.data.actions) - acts))
for o in set(bpy.data.objects) - before: bpy.data.objects.remove(o)
arm.animation_data_create()
s0, s1 = (int(round(x)) for x in src.frame_range)

def sample(u):  # source bite pose (matrix_basis per bone) at normalised time u
    arm.animation_data.action = src
    if len(src.slots): arm.animation_data.action_slot = src.slots[0]
    f = s0 + u * (s1 - s0)
    bpy.context.scene.frame_set(int(f), subframe=f - int(f))
    return {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}

def smooth(x): x = min(max(x, 0.0), 1.0); return x * x * (3 - 2 * x)

poses, jaw, lunge, hits, f = [], [], [], [], 0
for frames, jd, ld, hold in BITES:
    for k in range(hold):  # wind-up hold: the opening pose of the bite, jaw already half open
        poses.append(sample(0.0)); jaw.append(jd * 0.5 * smooth((k + 1) / hold)); lunge.append(-ld * 0.3 * smooth((k + 1) / hold))
        f += 1
    for k in range(frames):
        u = k / (frames - 1)
        poses.append(sample(u))
        if u < a.hit:
            jaw.append(jd * smooth((u + 0.05) / max(a.hit - 0.05, 1e-6)) if u < a.hit - 0.05 else jd * (1 - smooth((u - (a.hit - 0.05)) / 0.05)))
        else:
            jaw.append(-3.0 * (1 - smooth((u - a.hit) / 0.1)))
        lunge.append(ld * smooth((u - (a.hit - 0.15)) / 0.15) * (1 - smooth((u - a.hit - 0.1) / 0.35)))
        if abs(u - a.hit) < 0.5 / (frames - 1): hits.append(f)
        f += 1
total = f

act = bpy.data.actions.new("bite_combo")
arm.animation_data.action = act
for i in range(total):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"; pb.matrix_basis = poses[i][pb.name]
    jb = arm.pose.bones["Jaw"]; jb.rotation_quaternion = Quaternion((1, 0, 0), math.radians(jaw[i]))
    bpy.context.view_layer.update()  # no frame_set here: it would re-evaluate the action over these poses
    hb = arm.pose.bones["Head"]
    m = hb.matrix.copy(); piv = m.translation.copy()
    hb.matrix = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(lunge[i]), 4, "X") @ Matrix.Translation(-piv) @ m
    bpy.context.view_layer.update()
    for pb in arm.pose.bones:
        pb.keyframe_insert("location", frame=i + 1); pb.keyframe_insert("rotation_quaternion", frame=i + 1)
bpy.data.actions.remove(src)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, total
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_force_sampling=True, export_yup=True)
fracs = [round(h / (total - 1), 3) for h in hits]
print(f"COMBO {total} frames at {fps} fps ({(total - 1) / fps:.2f} s), hit fractions {fracs}")
