# STEGO-ART: redo game/assets/creatures/stegosaurus/sheet.png (SCHEMA: 4 views + clip contact sheet) for the
# fixed model: front, side, rear-3/4 and rear at rest, then one row per clip (6 frames, 0..100 %, side view).
#   Blender -b --factory-startup -P sheet.py -- <stegosaurus.glb> <anim_dir> <out.png>
import sys, math, pathlib
import numpy as np
import bpy
from mathutils import Vector

glb, anim_dir, out = sys.argv[sys.argv.index("--") + 1:][:3]
CLIPS = ["idle", "walk", "run", "attack_primary", "attack_heavy", "hit_react", "knockdown", "death", "alert"]
TW, TH = 600, 450        # view tile
CW, CH = 400, 260        # clip frame tile (6 per row = 2400 px)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
acts = {}
for c in CLIPS:
    before, acts_before = set(bpy.data.objects), set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(pathlib.Path(anim_dir) / f"{c}.glb"))
    new = [a for a in bpy.data.actions if a not in acts_before]
    assert len(new) == 1, f"{c}: {len(new)} actions"
    acts[c] = new[0]
    for o in [o for o in bpy.data.objects if o not in before]: bpy.data.objects.remove(o)
sc = bpy.context.scene
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        sc.render.engine = eng; break
    except TypeError:
        pass
world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.86, 0.87, 0.88, 1); bg.inputs[1].default_value = 1.0
sun = bpy.data.lights.new("sun", "SUN"); sun.energy = 2.5
so = bpy.data.objects.new("sun", sun); sc.collection.objects.link(so); so.rotation_euler = (math.radians(50), 0, math.radians(30))
cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"; co = bpy.data.objects.new("c", cd); sc.collection.objects.link(co); sc.camera = co

def render(path, w, h):
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(path); a = np.array(im.pixels[:]).reshape(h, w, 4)[::-1]; bpy.data.images.remove(im)
    return a
def aim(target, direction, scale):
    co.location = target + direction.normalized() * 30
    co.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler(); cd.ortho_scale = scale

tmp = str(pathlib.Path(out).with_suffix("")) + "_tile.png"
C = Vector((0, -1.8, 3.2))   # body centre (Blender coords: glTF -Z forward = +Y)
arm.animation_data_create(); arm.animation_data.action = None
views = []
for d, s in ((Vector((0, -1, 0.05)), 8.0), (Vector((1, 0, 0.05)), 13.0), (Vector((1, 1, 0.5)), 13.0), (Vector((0, 1, 0.1)), 8.0)):
    aim(C, d, s); views.append(render(tmp, TW, TH))
rows = [np.concatenate(views, 1)]
for c in CLIPS:
    a = acts[c]; arm.animation_data.action = a
    if hasattr(arm.animation_data, "action_slot") and len(a.slots): arm.animation_data.action_slot = a.slots[0]
    f0, f1 = a.frame_range
    frames = []
    for k in range(6):
        sc.frame_set(int(round(f0 + (f1 - f0) * k / 5)))
        aim(C + Vector((0, 0, -0.6)), Vector((1, 0, 0.05)), 15.0); frames.append(render(tmp, CW, CH))
    rows.append(np.concatenate(frames, 1))
sheet = np.concatenate(rows, 0)
img = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0]); img.pixels = sheet[::-1].ravel()
img.filepath_raw = out; img.file_format = "PNG"; img.save()
pathlib.Path(tmp).unlink(missing_ok=True)
print(f"[sheet] wrote {out} {sheet.shape[1]}x{sheet.shape[0]} (4 views, {len(CLIPS)} clips x 6 frames)")
