#!/usr/bin/env python3
"""Author an in-place leap clip (hop_back, leap_back, or with --forward a pounce) (crouch, backward leap, tucked feet, landing, recovery) from a species' idle pose.

The clip stays in place like the game's other clips; the game moves the creature backwards while it plays. The body
rises and falls on a jump arc, pitches nose-up in the air, the thighs tuck the feet up and the tail swings for
balance. Exports skeleton-only, like the other clips.

  Blender -b --python tools/jaw/make_hop_back.py -- <base.glb> <idle.glb> <out.glb> [--frames 12] [--height 0.08]
      [--tuck 35] [--pitch 14]

--height is in mesh units (the deinonychus is about 1 unit long). Prints the airborne fraction for anim_events.json.
"""
import argparse, json, math, struct, sys
import bpy
from mathutils import Matrix, Vector

ap = argparse.ArgumentParser()
ap.add_argument("base"); ap.add_argument("idle"); ap.add_argument("out")
ap.add_argument("--frames", type=int, default=12)
ap.add_argument("--height", type=float, default=0.08)
ap.add_argument("--tuck", type=float, default=35)
ap.add_argument("--pitch", type=float, default=14)
ap.add_argument("--forward", action="store_true", help="a pounce: nose down in the air, legs trail back")
ap.add_argument("--name", default="hop_back")
ap.add_argument("--side", choices=["left", "right"], help="a sideways dodge: the body banks away from the push instead of pitching")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

b = open(a.idle, "rb").read(); n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20 + n])
acc = max((j["accessors"][s["input"]] for s in j["animations"][0]["samplers"]), key=lambda x: x["count"])
fps = round((acc["count"] - 1) / max(acc["max"][0] - acc["min"][0], 1e-6))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = fps
bpy.ops.import_scene.gltf(filepath=a.base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in [o for o in bpy.data.objects if o is not arm]: bpy.data.objects.remove(o)
before = set(bpy.data.objects); acts = set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=a.idle)
src = next(iter(set(bpy.data.actions) - acts))
for o in set(bpy.data.objects) - before: bpy.data.objects.remove(o)
arm.animation_data_create(); arm.animation_data.action = src
if len(src.slots): arm.animation_data.action_slot = src.slots[0]
bpy.context.scene.frame_set(int(src.frame_range[0]))
start = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}
arm.animation_data.action = None
bpy.data.actions.remove(src)

def smooth(x): x = min(max(x, 0.0), 1.0); return x * x * (3 - 2 * x)

# phases (fraction of the clip): crouch 0-0.2, airborne 0.2-0.65, landing squash 0.65-0.8, recover to 1
T_OFF, T_LAND = 0.2, 0.65

def curves(u):
    if u < T_OFF:
        dz = -0.4 * a.height * smooth(u / T_OFF); air = 0.0
    elif u < T_LAND:
        s = (u - T_OFF) / (T_LAND - T_OFF); dz = a.height * 4 * s * (1 - s) - 0.4 * a.height * (1 - smooth(s / 0.25))
        air = math.sin(math.pi * s)
    elif u < 0.8:
        dz = -0.5 * a.height * math.sin(math.pi * (u - T_LAND) / 0.3); air = 0.0
    else:
        dz = -0.5 * a.height * math.sin(math.pi * (u - T_LAND) / 0.3) * (1 - smooth((u - 0.8) / 0.2)); air = 0.0
    return dz, air

act = bpy.data.actions.new(a.name)
sgn_dir = -1.0 if a.forward else 1.0
arm.animation_data.action = act
side = Vector((1, 0, 0))
for f in range(a.frames):
    u = f / (a.frames - 1)
    dz, air = curves(u)
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"; pb.matrix_basis = start[pb.name]
    bpy.context.view_layer.update()
    body = arm.pose.bones["Body"]
    m = body.matrix.copy(); piv = m.translation.copy()
    # nose up in the air (positive pitch lifts the snout for a -Y facing rig), whole body rises on the arc
    tilt = (Matrix.Rotation(math.radians((1 if a.side == "left" else -1) * a.pitch * air), 4, Vector((0, 1, 0))) if a.side
            else Matrix.Rotation(math.radians(-sgn_dir * a.pitch * air), 4, side))
    body.matrix = Matrix.Translation((0, 0, dz)) @ Matrix.Translation(piv) @ tilt @ Matrix.Translation(-piv) @ m
    bpy.context.view_layer.update()
    for nm in ("BackFoot.L", "BackFoot.R"):  # on these rigs the feet are root-parented controllers: lift them too
        pb = arm.pose.bones.get(nm)
        if pb is None: continue
        pb.matrix = Matrix.Translation((0, 0, max(0.0, dz) + 0.35 * a.height * air)) @ pb.matrix
        bpy.context.view_layer.update()
    for nm in ("BackUpLeg.L", "BackUpLeg.R"):  # tuck the feet up and forward while airborne
        pb = arm.pose.bones.get(nm)
        if pb is None: continue
        m = pb.matrix.copy(); piv = m.translation.copy()
        pb.matrix = Matrix.Translation(piv) @ Matrix.Rotation(math.radians((0.5 if a.side else sgn_dir) * a.tuck * air), 4, side) @ Matrix.Translation(-piv) @ m
        bpy.context.view_layer.update()
    for pb in arm.pose.bones:
        pb.keyframe_insert("location", frame=f + 1); pb.keyframe_insert("rotation_quaternion", frame=f + 1)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, a.frames
bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_force_sampling=True, export_yup=True)
print(f"HOP {a.name} {a.frames} frames at {fps} fps ({(a.frames - 1) / fps:.2f} s), airborne {T_OFF:.2f}-{T_LAND:.2f} of the clip")
