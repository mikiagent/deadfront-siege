"""SP-DEINONYCHUS: add non-deforming ClawTip.L/R marker bones at the hand claw tips of a Quaternius-Velociraptor
transplant rig (FrontFoot.* is the hand). The hitbox system (hitboxes.json) and Creature.part_hit read bone origins,
so an arm strike can hit from the claws, as the therizinosaurus does (rig_biped.py makes the same marker).

The tip is the FrontFoot-dominated vertex farthest from the hand bone's head along the bone (the longest claw);
with no hand skin (the deinonychus' hands are folded inside the wing) it is the hand bone's end;
the marker is parented to FrontFoot.<s>, deform off, so weights and every existing clip stay valid.

usage: Blender -b -P tools/gait/add_claw_tips.py -- <in.glb> <out.glb>
"""
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ob = max((o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm), key=lambda o: len(o.data.vertices))
gi = {g.index: g.name for g in ob.vertex_groups}
inv = arm.matrix_world.inverted()
tips = {}
for s in "LR":
    hb = arm.data.bones["FrontFoot." + s]
    h, d = hb.head_local, (hb.tail_local - hb.head_local).normalized()
    best, bd = None, -1e9
    for v in ob.data.vertices:
        if not v.groups or gi[max(v.groups, key=lambda g: g.weight).group] != "FrontFoot." + s:
            continue
        p = inv @ (ob.matrix_world @ v.co)
        t = (p - h).dot(d)
        if t > bd:
            best, bd = p, t
    if best is None:  # the hands are tucked inside the folded wing (no FrontFoot skin): the hand bone's end
        best = hb.tail_local.copy()
    tips[s] = (best, d)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
for s, (p, d) in tips.items():
    b = eb.new("ClawTip." + s)
    b.head, b.tail = p, p + d * 0.01
    b.parent = eb["FrontFoot." + s]
    b.use_deform = False
    print("CLAWTIP", s, tuple(round(x, 3) for x in p))
bpy.ops.object.mode_set(mode="OBJECT")
for o in list(bpy.data.objects):
    if o not in (arm, ob):
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_animations=False,
                          export_skins=True, export_yup=True)
print("WROTE", DST)
