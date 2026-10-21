# Package sheet.png: row 1 = rest views, then one row of 6 side-view frames per clip. Blender -b anim.blend -P make_sheet.py -- <out.png>
import bpy, sys, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rlib
out = sys.argv[sys.argv.index("--") + 1]; tmp = os.path.dirname(os.path.abspath(out)) + "/_sheet_tmp"; os.makedirs(tmp, exist_ok=True)
arm = bpy.data.objects["Armature"]; mesh = bpy.data.objects["SM_Deinonychus"]
rlib.setup(); rlib.floor(); sc = bpy.context.scene
arm.animation_data_create(); arm.animation_data.action = None
for pb in arm.pose.bones: pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
bpy.context.view_layer.update()
P = rlib.mesh_points(mesh); paths = []
for k, d in enumerate([(0, 1, 0.05), (1, 0, 0.02), (0, -1, 0.1), (1, 1.1, 0.45), (-1, 1.1, 0.45), (-1, 0, 0.02)]):
    p = f"{tmp}/rest_{k}.png"; rlib.shot(p, d, P, 420, 300, margin=1.04); paths.append(p)
for clip in ["idle", "walk", "run", "attack_primary", "attack_heavy", "hit_react", "knockdown", "death", "alert"]:
    act = bpy.data.actions[clip]; arm.animation_data.action = act
    try: arm.animation_data.action_slot = act.slots[0]
    except Exception: pass
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1]); frames = [int(round(f0 + (f1 - f0) * k / 5)) for k in range(6)]
    allP = []
    for f in frames: sc.frame_set(f); allP.append(rlib.mesh_points(mesh))
    Pc = np.concatenate(allP)
    for f in frames:
        sc.frame_set(f); p = f"{tmp}/{clip}_{f:03d}.png"; rlib.shot(p, (1, 0.35, 0.15), Pc, 420, 300, margin=1.04); paths.append(p)
rlib.montage(paths, 6, out); print("SHEET", out, os.path.getsize(out) // 1024, "KB")
