# One contact sheet per clip: 6 frames from the side and from 3/4 front, fixed framing per clip, textured, on a floor.
# Blender -b anim.blend --factory-startup -P allsheets.py -- <outdir> [clip ...]
import bpy, sys, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rlib
a = sys.argv[sys.argv.index("--") + 1:]
out = a[0]; os.makedirs(out + "/_tmp", exist_ok=True)
VIEWS = {"side": (1, 0, 0.02), "q": (1, 1.1, 0.45), "rear": (-1, -1.0, 0.35)}
arm = bpy.data.objects["Armature"]; mesh = bpy.data.objects["SM_Triceratops"]
rlib.setup(); rlib.floor(); sc = bpy.context.scene
names = a[1:] or ["idle", "walk", "run", "attack_primary", "attack_heavy", "hit_react", "knockdown", "death", "alert"]
for clip in names:
    act = bpy.data.actions[clip]; arm.animation_data_create(); arm.animation_data.action = act
    try: arm.animation_data.action_slot = act.slots[0]
    except Exception: pass
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1]); nf = 6
    frames = [int(round(f0 + (f1 - f0) * k / (nf - 1))) for k in range(nf)]
    allP = []
    for f in frames: sc.frame_set(f); allP.append(rlib.mesh_points(mesh))
    P = np.concatenate(allP); paths = []
    for vn, d in VIEWS.items():
        for f in frames:
            sc.frame_set(f); p = f"{out}/_tmp/{clip}_{vn}_{f:03d}.png"; rlib.shot(p, d, P, 420, 300, margin=1.04); paths.append(p)
    rlib.montage(paths, nf, f"{out}/{clip}.png"); print("SHEET", clip, frames)
