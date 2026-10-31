"""REXJAW gate: the T. rex's lower jaw in its bite and roar clips, measured on the deformed skin (Blender, headless).

Owner 2026-10-31: "tyrannosaurus rex jaw is not moving correctly in bite animations". The bite, stomp, alert and idle
clips swung the lower jaw UP through the skull (make_rex_moves.py turned it about the bone's own +X, which closes on
this rig). Per clip, every frame:
  gape     the Jaw's rotation relative to Head, signed by the chin moving down in head space (+ = open):
           widest opening 30-46 deg, never closing past -5 deg (a small clench on the snap is fine)
  hinge    the rotation axis is the head's side axis (|dot| >= 0.98): no sideways jaw
  jaw      skin held >= 99 % by Jaw moves rigidly with the Jaw bone (<= 2 cm off)
  skull    skin of the snout/skull held by Head and not by Jaw (forward of the hinge) stays rigid on Head (<= X = 5 cm),
           so the opening comes from the lower jaw, not from the skull or neck bending
  stretch  no head or jaw skin edge longer than 3.0x its rest length (tearing/sliver corners)
  snap     attack_primary only: the jaw is >= 30 deg open in the frames before the hit (anim_events hit_frac) and
           shut (<= 5 deg) within one frame of it
Prints one REXJAW line per clip and exits 1 on any failure.

usage: Blender -b -P tools/gait/check_rex_jaw.py -- <base.glb> <clip.glb> [<clip.glb> ...]
  e.g. game/assets/creatures/tyrannosaurus/{tyrannosaurus.glb,anim/{attack_primary,attack_heavy,roar,alert}.glb}
"""
import json
import math
import os
import sys

import bpy

a = sys.argv[sys.argv.index("--") + 1:]
base, clips = a[0], a[1:]
GAPE_MIN, GAPE_MAX, CLENCH = 30.0, 46.0, -5.0
JAW_TOL, SKULL_TOL, STRETCH = 0.02, 0.05, 3.0  # m, m, x rest length (an 8 m animal; >= 0.99 Jaw skin may carry 1 % neck)
EVENTS = os.path.join(os.path.dirname(__file__), "../../game/data/creatures/anim_events.json")
HIT = {"attack_primary": json.load(open(EVENTS))["clips"]["attack_primary"]["hit_frac"]}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=base)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
shapes = {pb.custom_shape for pb in arm.pose.bones if pb.custom_shape}
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o not in shapes), key=lambda o: len(o.data.vertices))
H, J = ob.vertex_groups["Head"].index, ob.vertex_groups["Jaw"].index
jb, hb = arm.data.bones["Jaw"], arm.data.bones["Head"]
mw = ob.matrix_world
rest = [mw @ v.co for v in ob.data.vertices]
W = [{g.group: g.weight for g in v.groups} for v in ob.data.vertices]
piv = arm.matrix_world @ jb.head_local
jaw_only = [i for i, w in enumerate(W) if w.get(J, 0) >= 0.99]
skull = [i for i, w in enumerate(W) if w.get(H, 0) >= 0.5 and w.get(J, 0) < 0.01 and rest[i].y > piv.y + 0.3]
region = {i for i, w in enumerate(W) if w.get(H, 0) + w.get(J, 0) >= 0.5}
edges = [(e.vertices[0], e.vertices[1]) for e in ob.data.edges if e.vertices[0] in region and e.vertices[1] in region]
rlen = [max((rest[i] - rest[k]).length, 1e-6) for i, k in edges]
jdir = (arm.matrix_world.to_3x3() @ (jb.tail_local - jb.head_local)).normalized()
chin = max(jaw_only, key=lambda i: (rest[i] - piv).dot(jdir))
side = (arm.matrix_world.to_3x3() @ hb.matrix_local.to_3x3().col[0]).normalized()


def deform(name):  # rest -> posed, world space
    pb = arm.pose.bones[name]
    return arm.matrix_world @ pb.matrix @ pb.bone.matrix_local.inverted() @ arm.matrix_world.inverted()


fails = 0
for path in clips:
    name = os.path.splitext(os.path.basename(path))[0]
    acts, before = set(bpy.data.actions), set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    for o in set(bpy.data.objects) - before:
        bpy.data.objects.remove(o, do_unlink=True)
    act = next(iter(set(bpy.data.actions) - acts))
    arm.animation_data_create()
    arm.animation_data.action = act
    if len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    f0, f1 = (int(round(x)) for x in act.frame_range)
    gape, hinge, jaw_dev, skull_dev, worst = [], 1.0, 0.0, 0.0, 0.0
    for f in range(f0, f1 + 1):
        bpy.context.scene.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        P = [mw @ v.co for v in me.vertices]
        Mh, Mj = deform("Head"), deform("Jaw")
        rel = (Mh.inverted() @ Mj).to_quaternion()
        ang = math.degrees(rel.angle)
        sign = 1.0 if (Mh.inverted() @ P[chin]).z < rest[chin].z else -1.0
        gape.append(sign * ang)
        if ang > 2.0:
            hinge = min(hinge, abs((Mh.to_3x3() @ rel.axis).normalized().dot((Mh.to_3x3() @ side).normalized())))
        jaw_dev = max(jaw_dev, max((P[i] - Mj @ rest[i]).length for i in jaw_only))
        skull_dev = max(skull_dev, max((P[i] - Mh @ rest[i]).length for i in skull))
        worst = max(worst, max((P[i] - P[k]).length / r for (i, k), r in zip(edges, rlen)))
        ev.to_mesh_clear()
    bad = []
    if not GAPE_MIN <= max(gape) <= GAPE_MAX:
        bad.append("gape")
    if min(gape) < CLENCH:
        bad.append("closes_up")
    if hinge < 0.98:
        bad.append("sideways")
    if jaw_dev > JAW_TOL:
        bad.append("jaw_not_rigid")
    if skull_dev > SKULL_TOL:
        bad.append("skull_moves")
    if worst > STRETCH:
        bad.append("stretch")
    snap = ""
    if name in HIT:
        h = HIT[name] * (f1 - f0)
        lo, hi = int(math.floor(h)) - 1, int(math.ceil(h)) + 1
        shut = [g for k, g in enumerate(gape) if lo <= k <= hi]
        wide = max(gape[max(0, lo - 6):lo] or [0.0])
        if min(shut) > 5.0 or wide < GAPE_MIN:
            bad.append("snap")
        snap = f" snap: {wide:.0f} deg before hit f{h:.1f}, {min(shut):.0f} deg at it"
    fails += bool(bad)
    print(f"REXJAW {name:15s} gape {max(gape):5.1f} deg (min {min(gape):+.1f}) hinge {hinge:.3f} jaw {jaw_dev * 100:.1f} cm "
          f"skull {skull_dev * 100:.1f} cm stretch {worst:.2f}x{snap} {'FAIL ' + ','.join(bad) if bad else 'PASS'}")
print("REXJAW", "FAIL" if fails else "PASS", f"{len(clips)} clips")
sys.exit(1 if fails else 0)
