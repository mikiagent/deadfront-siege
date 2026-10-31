# Build the Triceratops armature from joints.py on prep.blend, heat-weight the welded Tripo mesh, clean the weights by
# region, save rig.blend.  Blender -b prep.blend --factory-startup -P build_rig.py -- <out.blend>
# Rules (why): heat weighting reaches across gaps on a one-island scan mesh, so
#  - the frill, horns and face are RIGID on Head (no frill or horn stretching on head turns). The frill is found by
#    occlusion: a frill vertex cannot be seen from the neck centre without crossing the skin (air lies between the
#    frill and the neck/shoulders); skull, horns and body skin can;
#  - the lower jaw is split on the mouth line measured at 1.5 mm/px (overlay.py), the upper beak hook stays on Head;
#  - limb bones keep only vertices near their own segment and side; trunk bones never own a lower leg or foot;
#  - feet below the wrist/ankle ride Hand/Metatarsal, toes forward of the ball ride Finger/Toe (rigid soles stay flat).
import bpy, sys, os, numpy as np, importlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import joints; importlib.reload(joints)
out = sys.argv[sys.argv.index("--") + 1]
mesh = bpy.data.objects["SM_Triceratops"]; me = mesh.data
for im in bpy.data.images:
    if im.name.startswith("ORM") and im.size[0]:
        px = np.array(im.pixels[:]).reshape(-1, 4)
        print("ORM mean ao/rough/metal", px[:, 0].mean().round(3), px[:, 1].mean().round(3), px[:, 2].mean().round(3))
col = bpy.data.collections["COL_Export"]
ad = bpy.data.armatures.new("Armature"); arm = bpy.data.objects.new("Armature", ad); col.objects.link(arm)
bpy.context.view_layer.objects.active = arm; arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
eb = ad.edit_bones
r = eb.new("root"); r.head = (0, 0, 0); r.tail = (0, 0.6, 0); r.use_deform = False
X = Vector((1, 0, 0))
for n, (h, t, p) in joints.J.items():
    b = eb.new(n); b.head = h; b.tail = t
for n, (h, t, p) in joints.J.items():
    b = eb[n]; b.parent = eb[p]
    b.use_connect = (eb[p].tail - b.head).length < 1e-4
    y = (b.tail - b.head).normalized(); xp = (X - y * X.dot(y)).normalized()
    b.align_roll(xp.cross(y))  # local X = world +X (lateral) on every bone, both sides: pitch is +X everywhere
bpy.ops.object.mode_set(mode="OBJECT")
for b in ad.bones:
    assert b.matrix_local.to_3x3().col[0].dot(X) > 0.6 or b.name == "root", b.name
mesh.parent = arm; mesh.matrix_parent_inverse = arm.matrix_world.inverted()
bpy.ops.object.select_all(action="DESELECT"); mesh.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
names = {g.index: g.name for g in mesh.vertex_groups}; gi = {nm: i for i, nm in names.items()}
W = np.zeros((len(me.vertices), len(names)))
for v in me.vertices:
    for g in v.groups: W[v.index, g.group] = g.weight
print("WEIGHTS zero-weight verts after heat", int((W.sum(1) < 1e-6).sum()), "of", len(W))
P = np.array([v.co[:] for v in me.vertices]); x, y, z = P.T
def ss(a, b, t): t = np.clip((t - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)
def segd(n):
    h, t = (np.array(c) for c in (ad.bones[n].head_local, ad.bones[n].tail_local))
    d = t - h; u = np.clip(((P - h) @ d) / (d @ d), 0, 1); return np.linalg.norm(P - (h + u[:, None] * d), axis=1)
before = W.copy()
EL = np.ones_like(W)
def soft(d, r0, r1): return 1 - ss(r0, r1, d)
LIMBS = {"front": ("UpperArm", "Forearm", "Hand", "Finger"), "hind": ("Thigh", "Shin", "Metatarsal", "Toe")}
for sd, sg in (("R", 1), ("L", -1)):
    keep = ss(-0.10, 0.05, sg * x)  # 0 on the far side of the midline
    for fr, (b0, b1, b2, b3) in LIMBS.items():
        ycol = ad.bones[f"{b2}.{sd}"].head_local.y  # ankle / wrist: the foot spans it +-0.65 m
        yknee = ad.bones[f"{b1}.{sd}"].head_local.y
        EL[:, gi[f"{b0}.{sd}"]] = keep * soft(segd(f"{b0}.{sd}"), 0.70, 0.95) * (1 - ss(0.55, 0.85, abs(y - yknee)))
        EL[:, gi[f"{b1}.{sd}"]] = keep * soft(segd(f"{b1}.{sd}"), 0.55, 0.70) * ss(0.05, 0.20, sg * x) * (1 - ss(1.45, 1.65, z))
        a_z = ad.bones[f"{b2}.{sd}"].head_local.z
        foot = keep * (z < a_z + 0.10) * (abs(y - ycol) < 0.80) * (sg * x > 0.0)
        EL[:, gi[f"{b2}.{sd}"]] = np.maximum(foot, keep * soft(segd(f"{b2}.{sd}"), 0.40, 0.55))
        EL[:, gi[f"{b3}.{sd}"]] = foot
# leg columns: below the belly line a vertex inside a leg's column belongs to that leg, never to the trunk, neck or
# tail (the walk stretched a Neck1-owned patch on the upper foreleg 5.8x, Tail1-owned thigh backs 5x)
col_ = np.zeros(len(P))
for (cx, cy, rx, ry) in ((0.77, 1.35, 0.45, 0.60), (0.63, -1.55, 0.50, 0.65)):
    for sg in (1, -1):
        e = np.sqrt(((x - sg * cx) / rx) ** 2 + ((y - cy) / ry) ** 2)
        col_ = np.maximum(col_, (1 - ss(0.85, 1.15, e)) * (1 - ss(1.55, 1.85, z)))
tail_hw = np.interp(y, [-4.8, -3.0, -2.5, -2.25, -2.0], [0.25, 0.5, 0.65, 0.85, 1.0])
for n in ["Hips", "Spine1", "Spine2", "Chest", "Neck1", "Neck2", "Head"] + [f"Tail{i}" for i in range(1, 7)]:
    EL[:, gi[n]] = soft(segd(n), 1.6, 2.1) * ss(0.85, 1.15, z) * (1 - col_)  # trunk bones never own a leg or a foot
    if n.startswith("Neck"): EL[:, gi[n]] *= soft(segd(n), 1.1, 1.5)
    if n.startswith("Tail"): EL[:, gi[n]] *= 1 - ss(0.0, 0.15, np.abs(x) - tail_hw)
W *= EL
D = np.stack([segd(names[i]) if names[i] != "Jaw" else np.full(len(P), 9.0) for i in range(len(names))], 1)
D[EL < 0.5] = 9.0
lost = np.clip(1 - W.sum(1), 0, 1)
W[np.arange(len(P)), D.argmin(1)] += lost
orphan = D.min(1) >= 9.0
W[orphan] = before[orphan]
print("CLEANUP orphans kept on heat weights", int(orphan.sum()))
# feet: below the wrist/ankle pad everything rides the foot bones; toes forward of the ball ride Finger/Toe
for sd, sg in (("R", 1), ("L", -1)):
    for fr, (b0, b1, b2, b3) in LIMBS.items():
        hb, tb = ad.bones[f"{b2}.{sd}"], ad.bones[f"{b3}.{sd}"]
        ycol = hb.head_local.y
        m = (sg * x > 0.0) & (abs(y - ycol) < 0.80) & (z < hb.head_local.z - 0.12)
        toe = ss(tb.head_local.y - 0.08, tb.head_local.y + 0.08, y) * (1 - ss(0.25, 0.40, z))
        W[m] = 0; W[m, gi[f"{b3}.{sd}"]] = toe[m]; W[m, gi[f"{b2}.{sd}"]] = 1 - toe[m]
        print("FOOT", fr, sd, int(m.sum()), "verts, toes", int((toe[m] > 0.5).sum()))
# Smooth the trunk / limb-root blend (body region only; feet and head untouched)
Ev = np.array([e.vertices[:] for e in me.edges])
# (6 passes left 4.7x stretch on the shoulder and behind the knee in the walk: a wide blend spreads the swing)
body = (z > 0.75) & (y < 2.3) & (y > -2.8)
for it in range(int(os.environ.get("TRIKE_SMOOTH", "30"))):
    acc = np.zeros_like(W); cnt = np.zeros(len(P))
    np.add.at(acc, Ev[:, 0], W[Ev[:, 1]]); np.add.at(acc, Ev[:, 1], W[Ev[:, 0]])
    np.add.at(cnt, Ev[:, 0], 1); np.add.at(cnt, Ev[:, 1], 1)
    avg = acc / np.maximum(cnt, 1)[:, None]
    W[body] = 0.5 * W[body] + 0.5 * avg[body]
    W *= EL; W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
# Head: rigid from just behind the skull (y 2.4) forward, plus the frill found by occlusion: a frill vertex cannot be
# seen from the neck centre C nor from the chest centre C2 without crossing the skin (air lies between the frill and the
# neck and shoulders); shoulder skin near the frill wings is visible from C2, so it stays on the trunk bones.
bvh = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [p.vertices[:] for p in me.polygons])
def occluded(c, sel):
    c = Vector(c); o = np.zeros(len(P), bool)
    for i in np.nonzero(sel)[0]:
        d = Vector(P[i]) - c; L = d.length
        hit = bvh.ray_cast(c, d.normalized(), L)
        if hit[0] is not None and hit[3] < L - 0.04: o[i] = True
    return o
cand = (y > 1.35) & (z > 2.4)
frill = occluded((0.0, 2.30, 2.80), cand) & occluded((0.0, 1.35, 2.70), cand)
# fill the few frill-wing patches the rays see through (where the wings meet the cheeks): a wing vertex whose
# edge neighbours are mostly frill joins the frill (closing, wings only: |x| > 0.5, z > 3.0)
Ev = np.array([e.vertices[:] for e in me.edges])
wing = (np.abs(x) > 0.5) & (z > 3.0) & (y > 1.35)
for it in range(4):
    f = frill.astype(float); acc = np.zeros(len(P)); cnt = np.zeros(len(P))
    np.add.at(acc, Ev[:, 0], f[Ev[:, 1]]); np.add.at(acc, Ev[:, 1], f[Ev[:, 0]]); np.add.at(cnt, Ev[:, 0], 1); np.add.at(cnt, Ev[:, 1], 1)
    grow = wing & ~frill & (acc / np.maximum(cnt, 1) >= 0.5)
    frill |= grow
    print("FRILL closing pass", it, "added", int(grow.sum()))
head_w = np.maximum(ss(2.28, 2.40, y), frill.astype(float))  # the frill base meets the neck at y 2.3-2.45
# the neck blend under the frill keeps its own (smoothed) weights scaled by 1 - head_w
W = W * (1 - head_w)[:, None]; W[:, gi["Head"]] += head_w
print("HEAD rigid verts", int((head_w > 0.99).sum()), "frill (occluded from the neck centre)", int(frill.sum()))
# Jaw on the mouth line
MY = [3.10, 3.35, 3.55, 3.75, 3.92, 4.02]; MZ = [2.40, 2.37, 2.33, 2.25, 2.17, 2.10]
below = np.interp(y, MY, MZ) - z
rostral = y < 3.93 + 0.45 * np.clip(2.18 - z, 0, None)  # the hooked upper beak (rostral) stays on Head
wj = ss(-0.005, 0.02, below) * ss(3.05, 3.25, y) * (1 - ss(0.50, 0.62, abs(x))) * (z > 1.80) * rostral
other = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
W = other * (1 - wj)[:, None]; W[:, gi["Jaw"]] = wj
print("JAW verts>0.5", int((wj > 0.5).sum()), "blend", int(((wj > 0.02) & (wj < 0.98)).sum()))
idx = np.argsort(-W, 1)[:, 4:]; np.put_along_axis(W, idx, 0, 1); W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
for i, nm in names.items():
    g = mesh.vertex_groups[nm]; g.remove(range(len(me.vertices)))
    for vi in np.nonzero(W[:, i] > 1e-4)[0]: g.add([int(vi)], float(W[vi, i]), "REPLACE")
print("CLEANUP verts changed", int((np.abs(W - before).sum(1) > 0.05).sum()), "unweighted", int((W.sum(1) < 0.99).sum()))
for i, nm in sorted(names.items()):
    print(f"  {nm:14s} verts>0.5 {int((W[:, i] > 0.5).sum()):5d}")
np.save(os.path.splitext(out)[0] + "_frill.npy", frill)
bpy.ops.wm.save_as_mainfile(filepath=out)
print("SAVED", out)
