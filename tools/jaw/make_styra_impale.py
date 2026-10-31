#!/usr/bin/env python3
"""STYRAFIX: the styracosaurus charge set beside its charge loop, keyed as small local rotations from the idle's first
pose so every planted foot stays exactly where idle has it (only the pawing foot moves):

  charge_windup  head drops horns-first, the left fore-foot paws the ground twice, a snort, horns level at the end
  impale         from the head-down pose the horns dip to the ground, scoop up hard and fling (hit at HIT), settle
  charge_recover winded after the charge: head low, three decaying head shakes, mouth open, back to idle

The rig faces -Y in Blender; + about the side axis (left hip - right hip) pitches the nose down.
  Blender -b --python tools/jaw/make_styra_impale.py -- <base.glb> <idle.glb> <out_dir>
Prints the hit fraction for anim_events.json (impale.hit_frac) and each clip's length.
"""
import json, math, os, struct, sys
import bpy
from mathutils import Matrix

base, idle, out_dir = sys.argv[sys.argv.index("--") + 1:][:3]
FPS = 24
HIT = 0.26          # impale: the horns at their lowest, starting up (the survivor is caught here)
RELEASE = 0.46      # impale: the head at the top of the scoop (the survivor is flung here)


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def bump(u, a, b, c):  # 0 before a, rises to 1 at b, falls back to 0 at c
    return smooth((u - a) / max(b - a, 1e-6)) * (1 - smooth((u - b) / max(c - b, 1e-6)))


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in [o for o in bpy.data.objects if o is not arm]:
    bpy.data.objects.remove(o)
acts = set(bpy.data.actions)
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=idle)
src = next(iter(set(bpy.data.actions) - acts))
for o in set(bpy.data.objects) - before:
    bpy.data.objects.remove(o)
arm.animation_data_create()
arm.animation_data.action = src
if len(src.slots):
    arm.animation_data.action_slot = src.slots[0]
bpy.context.scene.frame_set(int(src.frame_range[0]))
start = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}
arm.animation_data.action = None
bpy.data.actions.remove(src)
P = arm.pose.bones
SIDE = (P["BackLeg.L"].head - P["BackLeg.R"].head).normalized()
UP = (0.0, 0.0, 1.0)


def rot(pb, axis, deg):
    if abs(deg) < 1e-6:
        return
    m = pb.matrix.copy()
    piv = m.translation.copy()
    pb.matrix = Matrix.Translation(piv) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-piv) @ m
    bpy.context.view_layer.update()


def glue(foot, shin):  # the root-parented foot controller rides its shin's tip
    m = P[foot].matrix.copy()
    m.translation = P[shin].tail.copy()
    P[foot].matrix = m
    bpy.context.view_layer.update()


def clip(name, frames, pose):
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    for f in range(frames):
        u = f / (frames - 1)
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.matrix_basis = start[pb.name]
        bpy.context.view_layer.update()
        pose(u)
        for pb in arm.pose.bones:
            pb.keyframe_insert("location", frame=f + 1)
            pb.keyframe_insert("rotation_quaternion", frame=f + 1)
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, frames
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_yup=True)
    arm.animation_data.action = None
    bpy.data.actions.remove(act)
    print(f"CLIP {name} {frames} frames {frames / FPS:.3f} s")


def head(neck_deg, head_deg, jaw_deg=0.0, yaw_deg=0.0):
    rot(P["Neck"], SIDE, neck_deg)
    rot(P["Head"], SIDE, head_deg)
    if yaw_deg:
        rot(P["Head"], UP, yaw_deg)
    if jaw_deg:
        rot(P["Jaw"], SIDE, jaw_deg)


PAW, PAW_SIDE = "Front", "L"  # the near fore-foot in the side renders


def windup(u):
    down = smooth(u / 0.22)                      # horns lowered at the threat and kept there
    snort = bump(u, 0.78, 0.86, 0.96)           # a toss of the head before the run
    head(26 * down - 6 * snort, 18 * down, jaw_deg=10 * snort)
    rot(P["Tail1"], SIDE, -8 * down)              # tail up, braced
    # two scrapes with one fore-foot: lift and reach forward, plant, drag back
    for a in (0.22, 0.5):
        lift = bump(u, a, a + 0.08, a + 0.16)
        drag = bump(u, a + 0.12, a + 0.2, a + 0.28)
        rot(P[PAW + "UpLeg." + PAW_SIDE], SIDE, -38 * lift + 18 * drag)
        rot(P[PAW + "LowLeg." + PAW_SIDE], SIDE, 95 * lift + 10 * drag)
    glue(PAW + "Foot." + PAW_SIDE, PAW + "LowLeg." + PAW_SIDE)


def impale(u):
    dip = smooth(u / HIT)                          # horns into the ground in front
    scoop = smooth((u - HIT) / (RELEASE - HIT))   # then up hard: the fling
    settle = smooth((u - 0.62) / 0.38)            # and back to the stance
    neck = 26 + 19 * dip - 67 * scoop
    hd = 18 + 18 * dip - 48 * scoop
    head(neck * (1 - settle), hd * (1 - settle), jaw_deg=22 * bump(u, HIT, RELEASE, 0.85))
    rot(P["Tail1"], SIDE, (-8 - 10 * scoop) * (1 - settle))


def recover(u):
    low = smooth(u / 0.15) * (1 - smooth((u - 0.8) / 0.2))
    shake = math.sin(u * math.tau * 3.0) * (1 - smooth((u - 0.1) / 0.7)) * smooth(u / 0.12)
    pant = 0.5 + 0.5 * math.sin(u * math.tau * 4.0)
    head(30 * low, 12 * low, jaw_deg=(8 + 8 * pant) * low, yaw_deg=16 * shake)
    rot(P["Tail1"], SIDE, 6 * low)               # tail drops, winded


os.makedirs(out_dir, exist_ok=True)
clip("charge_windup", 31, windup)
clip("impale", 30, impale)
clip("charge_recover", 39, recover)
print(json.dumps({"impale": {"hit_frac": HIT, "release_frac": RELEASE}}))
