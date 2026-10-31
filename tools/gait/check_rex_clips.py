"""Ground and foot checks for T. rex clips on the skinned mesh (Blender, headless).

Per clip, every frame, measured on the toe tips (Toe.L/R tails) and the evaluated skin:
  sink      lowest skin vertex vs the rest pose's lowest vertex; below -3 cm is sinking into the ground.
  float     lowest skin vertex above +3 cm while a foot is supposed to be down: the body hovers.
  slip      one-shots and idle: a toe tip on the ground (within 3 cm of its rest height) may not move more than
            3 cm from where it touched down until it lifts again (foot sliding).
  grounded  one-shots and idle: at least one foot on the ground in every frame.
  ends      one-shots and idle: both toe tips on their rest prints (3 cm) in the first and last frame, so
            crossfades to idle and the gaits never drag a foot.
  moonwalk  gaits (walk, run, walk_back, strafe_*): planted toes must slide against the clip's travel
            (median planted velocity . travel < 0); a positive value is a moonwalk.
Prints one REXCHECK line per clip and exits 1 on any failure.

usage: Blender -b -P tools/gait/check_rex_clips.py -- <base.glb> <clip.glb> [<clip.glb> ...]
"""
import os
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
base, clips = a[0], a[1:]
TOL = 0.03
TRAVEL = {"walk": (0, 1, 0), "run": (0, 1, 0), "walk_back": (0, -1, 0), "strafe_left": (-1, 0, 0), "strafe_right": (1, 0, 0)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
meshes = [o for o in bpy.data.objects if o.type == "MESH" and o not in shapes and not o.name.startswith(("Icosphere", "Cube"))]
sc = bpy.context.scene


LOW_AT = [None]


def low_z():
    dg = bpy.context.evaluated_depsgraph_get()
    z, at = 1e9, None
    for o in meshes:
        e = o.evaluated_get(dg)
        mw = e.matrix_world
        for v in e.data.vertices:
            w = mw @ v.co
            if w.z < z:
                z, at = w.z, w
    LOW_AT[0] = at
    return z


def toes():
    return {s: arm.matrix_world @ arm.pose.bones["Toe." + s].tail for s in "LR"}


rest_low = low_z()
rest = toes()
fails = 0
for path in clips:
    name = os.path.splitext(os.path.basename(path))[0]
    before = set(bpy.data.objects)
    acts = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    act = next(iter(set(bpy.data.actions) - acts))
    for o in set(bpy.data.objects) - before:
        bpy.data.objects.remove(o, do_unlink=True)
    arm.animation_data_create()
    arm.animation_data.action = act
    try:
        arm.animation_data.action_slot = act.slots[0]
    except Exception:
        pass
    f0, f1 = (int(round(x)) for x in act.frame_range)
    gait = name in TRAVEL
    sink, flo, slip, airborne, vels = 0.0, 0.0, 0.0, 0, []
    touch = {"L": None, "R": None}
    prev = None
    ends = 0.0
    sink_at = None
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        lz = low_z() - rest_low
        if lz < sink:
            sink, sink_at = lz, (f - f0, tuple(round(x, 2) for x in LOW_AT[0]))
        t = toes()
        down = {s: t[s].z < rest[s].z + TOL for s in "LR"}
        if any(down.values()):
            flo = max(flo, lz)
        else:
            airborne += 1
        for s in "LR":
            if down[s]:
                if touch[s] is None:
                    touch[s] = t[s].copy()
                d = t[s] - touch[s]
                slip = max(slip, Vector((d.x, d.y)).length)
                if prev is not None and prev[1][s]:
                    vels.append((t[s] - prev[0][s]).dot(Vector(TRAVEL.get(name, (0, 0, 0)))))
            else:
                touch[s] = None
        if f in (f0, f1):
            ends = max(ends, max((t[s] - rest[s]).length for s in "LR"))
        prev = (t, down)
    bad = []
    if sink < -TOL:
        bad.append("sink")
    if flo > TOL:
        bad.append("float")
    if gait:
        vels.sort()
        med = vels[len(vels) // 2] * 24 if vels else 0.0
        if med > 0:
            bad.append("moonwalk")
        if not vels:
            bad.append("no_planted_foot")
        detail = f"planted_speed {-med:+.2f} m/s along travel ({len(vels)} planted samples)"
    else:
        if slip > TOL:
            bad.append("slip")
        if airborne:
            bad.append("airborne")
        if ends > TOL:
            bad.append("ends")
        detail = f"slip {slip * 100:.1f} cm airborne_frames {airborne} ends {ends * 100:.1f} cm"
    fails += bool(bad)
    print(f"REXCHECK {name:15s} frames {f1 - f0:3d} sink {sink * 100:+.1f} cm float {flo * 100:+.1f} cm {detail} "
          f"{'FAIL ' + ','.join(bad) if bad else 'PASS'}" + (f"  (deepest f{sink_at[0]} at {sink_at[1]})" if "sink" in bad else ""))
print("REXCHECK", "FAIL" if fails else "PASS", f"{len(clips)} clips")
sys.exit(1 if fails else 0)
