# Build the Deinonychus armature from joints.py on prep.blend, heat-weight the welded Tripo mesh, save rig.blend.
# Blender -b prep.blend --factory-startup -P build_rig.py -- <out.blend>
import bpy, sys, os, numpy as np, importlib
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import joints; importlib.reload(joints)
out = sys.argv[sys.argv.index("--") + 1]
mesh = bpy.data.objects["SM_Deinonychus"]
# metallic: Tripo PBR maps carry metallic; feathers must be matte
for im in bpy.data.images:
    if im.name.startswith("ORM") and im.size[0]:
        px = np.array(im.pixels[:]).reshape(-1, 4)
        print("ORM mean ao/rough/metal", px[:, 0].mean().round(3), px[:, 1].mean().round(3), px[:, 2].mean().round(3), "metal>0.2", (px[:, 2] > 0.2).mean().round(4))
col = bpy.data.collections["COL_Export"]
ad = bpy.data.armatures.new("Armature"); arm = bpy.data.objects.new("Armature", ad); col.objects.link(arm)
bpy.context.view_layer.objects.active = arm; arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
eb = ad.edit_bones
r = eb.new("root"); r.head = (0, 0, 0); r.tail = (0, 0.4, 0); r.use_deform = False
X = Vector((1, 0, 0))
for n, (h, t, p) in joints.J.items():
    b = eb.new(n); b.head = h; b.tail = t
for n, (h, t, p) in joints.J.items():
    b = eb[n]; b.parent = eb[p]
    b.use_connect = (eb[p].tail - b.head).length < 1e-4
    y = (b.tail - b.head).normalized(); xp = (X - y * X.dot(y)).normalized()
    b.align_roll(xp.cross(y))  # local X = world +X (lateral) on every bone, both sides
bpy.ops.object.mode_set(mode="OBJECT")
for b in ad.bones:
    m = b.matrix_local.to_3x3()
    assert m.col[0].dot(X) > 0.6 or b.name == "root", (b.name, m.col[0])
mesh.parent = arm; mesh.matrix_parent_inverse = arm.matrix_world.inverted()
bpy.ops.object.select_all(action="DESELECT"); mesh.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
me = mesh.data
names = {g.index: g.name for g in mesh.vertex_groups}
W = np.zeros((len(me.vertices), len(names)))
for v in me.vertices:
    for g in v.groups: W[v.index, g.group] = g.weight
tot = W.sum(1)
print("WEIGHTS zero-weight verts", int((tot < 1e-6).sum()), "of", len(tot), "groups", len(names))
for i, nm in sorted(names.items()):
    print(f"  {nm:14s} verts>0.5 {int((W[:, i] > 0.5).sum()):5d}")
# Region cleanup of the heat weights (bone heat reaches across gaps on this one-island mesh): a belly vertex
# carried Arm.L/Arm.R/Thigh.L/Thigh.R and no spine; ground toe tips carried Sickle; the far side carried the near
# side's limbs. Limb bones keep only vertices near their own segment; what is lost goes to the nearest trunk bone.
def ss(a, b, x): t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)
P = np.array([v.co[:] for v in me.vertices]); x, y, z = P.T
gi = {nm: i for i, nm in names.items()}
def segd(n):
    h, t = (np.array(c) for c in (ad.bones[n].head_local, ad.bones[n].tail_local))
    d = t - h; u = np.clip(((P - h) @ d) / (d @ d), 0, 1); return np.linalg.norm(P - (h + u[:, None] * d), axis=1)
before = W.copy()
EL = np.ones_like(W)  # eligibility 0..1: which bones may own each vertex (soft edges, no seams)
def soft(d, r0, r1): return 1 - ss(r0, r1, d)
for sd, sg in (("R", 1), ("L", -1)):
    farf = 1 - ss(-0.12, -0.02, sg * x)  # 1 on the far side
    keep = 1 - farf
    armd = np.minimum.reduce([segd(f"{b}.{sd}") for b in ("Arm", "Forearm", "Hand")])
    wing = ((sg * x > 0.35) & (y > 0.25) & (y < 1.6) & (z > 0.5) & (z < 2.35)).astype(float)
    for b in ("Arm", "Forearm", "Hand"):
        EL[:, gi[f"{b}.{sd}"]] = keep * np.maximum(soft(armd, 0.28, 0.45), wing)
    EL[:, gi[f"Thigh.{sd}"]] = keep * soft(segd(f"Thigh.{sd}"), 0.40, 0.60) * (1 - ss(0.12, 0.30, y))  # thigh mass ends at y~0.2
    EL[:, gi[f"Shin.{sd}"]] = keep * soft(segd(f"Shin.{sd}"), 0.30, 0.42) * ss(0.12, 0.22, sg * x) * (1 - ss(1.40, 1.55, z))  # not the belly
    EL[:, gi[f"Metatarsal.{sd}"]] = keep * soft(segd(f"Metatarsal.{sd}"), 0.24, 0.34)
    by = ad.bones[f"Toe.{sd}"].head_local.y
    EL[:, gi[f"Toe.{sd}"]] = keep * ((z < 0.30) & (sg * x > 0.0) & (sg * x < 0.95) & (y > by - 0.25) & (y < 0.7))
    skreg = keep * soft(segd(f"Sickle.{sd}"), 0.15, 0.22) * (z > 0.10)
    EL[:, gi[f"Sickle.{sd}"]] = skreg
    claw = (skreg > 0.99) & (W[:, gi[f"Sickle.{sd}"]] >= 0.3)  # the raised digit II follows its own bone, not the ground toes
    W[claw, gi[f"Sickle.{sd}"]] += W[claw, gi[f"Toe.{sd}"]]; W[claw, gi[f"Toe.{sd}"]] = 0
for n in ["Hips", "Spine1", "Spine2", "Chest", "Neck1", "Neck2", "Neck3", "Head"] + [f"Tail{i}" for i in range(1, 9)]:
    EL[:, gi[n]] = soft(segd(n), 1.1, 1.45)  # trunk bones never own a foot or a hand
W *= EL
D = np.stack([segd(names[i]) if names[i] != "Jaw" else np.full(len(P), 9.0) for i in range(len(names))], 1)
D[EL < 0.5] = 9.0
lost = np.clip(1 - W.sum(1), 0, 1)
near = D.argmin(1)
W[np.arange(len(P)), near] += lost
orphan = D.min(1) >= 9.0
W[orphan] = before[orphan]
print("CLEANUP orphans kept on heat weights", int(orphan.sum()))
# Smooth the trunk/limb-root blend over the welded mesh (body region only; feet, hands and head stay as they are)
Ev = np.array([e.vertices[:] for e in me.edges])
body = (z > 1.0) & (y < 1.75) & (y > -1.5)
for it in range(6):
    acc = np.zeros_like(W); cnt = np.zeros(len(P))
    np.add.at(acc, Ev[:, 0], W[Ev[:, 1]]); np.add.at(acc, Ev[:, 1], W[Ev[:, 0]])
    np.add.at(cnt, Ev[:, 0], 1); np.add.at(cnt, Ev[:, 1], 1)
    avg = acc / np.maximum(cnt, 1)[:, None]
    W[body] = 0.5 * W[body] + 0.5 * avg[body]
    W *= EL; W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
print("CLEANUP verts changed", int((np.abs(W - before).sum(1) > 0.05).sum()), "max lost", round(float(lost.max()), 3))
# Jaw: heat weighting blends the lips, so the upper snout sagged when the jaw opened. Re-split along the mouth
# line measured on the mesh (side close-up, 1 mm/px): lower jaw 100 % Jaw, upper skull 0 % Jaw, blend only at the hinge.
MY = [1.95, 2.25, 2.46, 2.68, 2.85]; MZ = [3.08, 3.015, 2.952, 2.915, 2.90]
P = np.array([v.co[:] for v in me.vertices]); x, y, z = P.T
below = np.interp(y, MY, MZ) - z
wj = ss(-0.004, 0.012, below) * ss(1.97, 2.12, y) * ss(2.76, 2.84, z) * (abs(x) < 0.3) * (y > 1.9)
gi = {nm: i for i, nm in names.items()}
W[:, gi["Jaw"]] = 0
other = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
W = other * (1 - wj)[:, None]; W[:, gi["Jaw"]] = wj
# limit to 4 influences, normalise
idx = np.argsort(-W, 1)[:, 4:]; np.put_along_axis(W, idx, 0, 1); W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
for i, nm in names.items():
    g = mesh.vertex_groups[nm]; g.remove(range(len(me.vertices)))
    nz = np.nonzero(W[:, i] > 1e-4)[0]
    for vi in nz: g.add([int(vi)], float(W[vi, i]), "REPLACE")
print("JAW verts>0.5", int((wj > 0.5).sum()), "blend", int(((wj > 0.02) & (wj < 0.98)).sum()))
bpy.ops.wm.save_as_mainfile(filepath=out)
print("SAVED", out)
