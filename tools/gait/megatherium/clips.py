"""Megatherium clips on build_rig.py's skeleton (SP-WOOLLY_RHINO's solver: footfall-planned gaits and keyed moves with
an analytic leg solver, exported skeleton-only), with the giant ground sloth's moves.

  Blender -b -P tools/gait/megatherium/clips.py -- <rig.blend> <anim_dir> [clip ...]

The sloth knuckle-walks on all fours and rears up on its hind legs and tail (the TRIPOD: the body pitched up about the
hip joints, both hind feet flat, the tail laid on the ground behind as the third leg) to display, feed and fight.
  alert          the tripod threat display (rears, arms spread wide, claws open, roars), the display step
  attack_primary the hooking claw pull: half-rears, the right arm reaches out and hooks at 0.42, hauls back to the chest
  attack_heavy   the two-arm overhead swipe: rears to the tripod, both arms high and held trembling (the tell, through
                 windup_hold 0.6), then both claw hands come down together through the front at 0.72 (bleeds)
  grab           the bear hug's windup (played timed before pounce): rears, arms thrown wide open
  pounce         the hug: lurches forward out of the tripod (airborne 0.2-0.65: the game carries it), the arms close
                 round her at 0.7 and bear her down
  pin_stab       the crush: holding her down under the chest in the hug, two squeezes (0.38, 0.74)
Hit fracs are the shared anim_events.json rows for each clip name.
  charge         the lumbering advance: upright on its hind legs, arms out, slow heavy steps (super armour in game)
  toss           the advance's finisher: it topples forward onto her, both arms crashing down at 0.3
Every frame: the body pivots (Body bone), spine, neck, head, jaw and tail turn by small angles from rest, then each leg
is solved to a foot target (two-bone in the leg's plane: the knee bends forward, the elbow back, so neither reverses).
"""
import bpy, math, os, sys
from mathutils import Vector, Matrix, Quaternion

a = sys.argv[sys.argv.index("--") + 1:]
BLEND, OUT = a[:2]
ONLY = set(a[2:])
FPS = 24
bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
sc.render.fps = FPS
arm = bpy.data.objects["Armature"]
PB = arm.pose.bones
for pb in PB: pb.rotation_mode = "QUATERNION"
REST = {b.name: b.matrix_local.copy() for b in arm.data.bones}
HEAD = {k: m.translation.copy() for k, m in REST.items()}
TAIL = {b.name: b.tail_local.copy() for b in arm.data.bones}
LEN = {b.name: b.length for b in arm.data.bones}
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
H = HEAD["FrontScapula.L"].z  # withers height (scapula top): every move is scaled by it
LEGS = {}
for sd, sx in (("L", 1), ("R", -1)):
    LEGS["F" + sd] = dict(front=True, sx=sx, scap="FrontScapula." + sd, up="FrontUpper." + sd, low="FrontLower." + sd,
                          can="FrontCannon." + sd, foot="FrontFoot." + sd)
    LEGS["H" + sd] = dict(front=False, sx=sx, up="HindUpper." + sd, low="HindLower." + sd,
                          can="HindCannon." + sd, foot="BackFoot." + sd)
# symmetric home stance: fetlocks at the mean front / hind position, each side at its own width
for k, L in LEGS.items():
    pair = [HEAD[LEGS[k[0] + s]["foot"]] for s in "LR"]
    yy = sum(p.y for p in pair) / 2; xx = sum(abs(p.x) for p in pair) / 2
    L["home"] = Vector((L["sx"] * xx, yy, HEAD[L["foot"]].z))
    L["toe"] = TAIL[L["foot"]] - HEAD[L["foot"]]
    L["toe"].x = 0
    L["can_dir"] = (HEAD[L["can"]] - TAIL[L["can"]]).normalized()  # fetlock -> carpus/hock
SH = 2.2  # stride scale (m)
L_FY = LEGS["FL"]["home"].y; L_HY = LEGS["HL"]["home"].y
print(f"withers {H:.2f} m; front feet y {L_FY:.2f}, hind {L_HY:.2f}")


def smooth(x): x = min(max(x, 0.0), 1.0); return x * x * (3 - 2 * x)
def bump(u, a0, a1, b0, b1): return smooth((u - a0) / max(a1 - a0, 1e-6)) * (1 - smooth((u - b0) / max(b1 - b0, 1e-6)))
def lerp(p, q, t): return p + (q - p) * t
def R(axis, deg): return Matrix.Rotation(math.radians(deg), 4, axis)


class St:
    """One frame's pose: everything is an offset from rest."""
    def __init__(s):
        s.off = Vector(); s.pitch = s.roll = s.yaw = 0.0  # body (deg): +pitch = nose up
        s.pivot = None  # body rotation pivot (default: Body head)
        s.hips = 0.0; s.chest = 0.0; s.spine_yaw = 0.0
        s.neck = [0.0, 0.0]; s.neck_yaw = [0.0, 0.0]; s.head = 0.0; s.head_yaw = 0.0; s.head_roll = 0.0
        s.jaw = 0.0; s.tail = [0.0, 0.0, 0.0]; s.tail_yaw = [0.0, 0.0, 0.0]
        s.tail_plant = 0.0  # SLOTH: 0..1, the tail laid along the ground behind the hips (the tripod's third leg)
        s.feet = {k: L["home"].copy() for k, L in LEGS.items()}  # fetlock targets
        s.tilt = {k: 0.0 for k in LEGS}  # cannon tilt (deg, + = top forward)
        s.curl = {k: 0.0 for k in LEGS}  # pastern curl (deg, + = toe tucks back)
        s.scap = {k: 0.0 for k in LEGS}  # extra scapula swing (deg)
        s.follow = None  # cannon follows the body (0..1); None = by hoof height


def set_dir(pb, head, new_dir):
    """Pose pb so it starts at head and points along new_dir, by the minimal rotation from its rest direction."""
    rest = REST[pb.name]
    q = (rest.to_3x3() @ Y).rotation_difference(new_dir.normalized())
    M = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ rest.to_3x3().to_4x4()
    pb.matrix = M
    bpy.context.view_layer.update()


def turn(pb, axis, deg, piv=None):
    if abs(deg) < 1e-6: return
    m = pb.matrix.copy(); p = piv if piv is not None else m.translation.copy()
    pb.matrix = Matrix.Translation(p) @ R(axis, deg) @ Matrix.Translation(-p) @ m
    bpy.context.view_layer.update()


def two_bone(A, B, l1, l2, pole):
    d = B - A; dl = min(max(d.length, abs(l1 - l2) + 1e-4), (l1 + l2) * 0.999)
    u = d.normalized(); w = pole - u * u.dot(pole); w.normalize()
    ca = (l1 * l1 + dl * dl - l2 * l2) / (2 * l1 * dl); ca = min(1, max(-1, ca))
    return A + u * (l1 * ca) + w * (l1 * math.sqrt(1 - ca * ca)), A + u * dl


def apply(s):
    for pb in PB: pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    body = PB["Body"]
    piv = s.pivot if s.pivot is not None else HEAD["Body"]
    rot = R(Z, s.yaw) @ R(Y, s.roll) @ R(X, -s.pitch)  # +X turns -Y (the nose) down, so +pitch = -X
    body.matrix = Matrix.Translation(s.off) @ Matrix.Translation(piv) @ rot @ Matrix.Translation(-piv) @ REST["Body"]
    bpy.context.view_layer.update()
    side = (rot.to_3x3() @ X); up = rot.to_3x3() @ Z
    turn(PB["Hips"], side, s.hips)  # +hips = croup (the bone points back) up
    turn(PB["Torso"], side, -s.chest); turn(PB["Torso"], up, s.spine_yaw)
    for i, nb in enumerate(("Neck", "Neck2")):
        turn(PB[nb], side, -s.neck[i]); turn(PB[nb], up, s.neck_yaw[i])  # +neck = up
    turn(PB["Head"], side, -s.head); turn(PB["Head"], up, s.head_yaw)
    if s.head_roll: turn(PB["Head"], PB["Head"].matrix.to_3x3() @ Y, s.head_roll)
    turn(PB["Jaw"], side, s.jaw)  # +jaw = open (tip down)
    for i, tb in enumerate(("Tail1", "Tail2", "Tail3")):
        turn(PB[tb], side, s.tail[i]); turn(PB[tb], up, s.tail_yaw[i])
    if True:  # the tail is planted by tail_plant and always kept above the ground
        # the tail drops from its root to the ground and lies flat behind (blended with the turned pose)
        A = PB["Tail1"].matrix.translation.copy(); back = Vector((0, 1, 0))
        rr = [TAIL[b].z for b in ("Tail1", "Tail2", "Tail3")]  # each bone's end as high off the ground as at rest
        p = A
        for i, tb in enumerate(("Tail1", "Tail2", "Tail3")):
            l = LEN[tb]; dz = max(-l * 0.98, rr[i] * 1.0 - p.z)
            want = Vector((0, math.sqrt(max(l * l - dz * dz, 1e-6)), dz)).normalized()
            pb = PB[tb]; cur = (pb.matrix.to_3x3() @ Y).normalized()
            d = cur.lerp(want, s.tail_plant).normalized()
            if (p + d * l).z < rr[i] - 0.05: d = want  # the tail never digs into the ground
            set_dir(pb, pb.matrix.translation.copy(), d)
            p = pb.matrix.translation + d * l
    for k, L in LEGS.items():
        fet = s.feet[k]
        # a planted cannon keeps its world angle; a lifted (or lying) leg's cannon turns with the body
        wb = s.follow if s.follow is not None else min(1.0, max(0.0, (fet.z - L["home"].z) / (0.1 * H)))
        cw = R(X, s.tilt[k]).to_3x3() @ L["can_dir"]
        cdir = cw.lerp(rot.to_3x3() @ cw, wb).normalized()
        top = fet + cdir * LEN[L["can"]]
        if L["front"]:
            turn(PB[L["scap"]], side, s.scap[k])
            A = PB[L["up"]].matrix.translation.copy()
            pole = rot.to_3x3() @ Y  # elbow points back
        else:
            A = PB[L["up"]].matrix.translation.copy()
            pole = -(rot.to_3x3() @ Y)  # stifle points forward
        knee, top2 = two_bone(A, top, LEN[L["up"]], LEN[L["low"]], pole)
        set_dir(PB[L["up"]], A, knee - A)
        set_dir(PB[L["low"]], knee, top2 - knee)
        fet2 = top2 + (fet - top)  # unreachable target: the cannon keeps its angle, the hoof lifts
        set_dir(PB[L["can"]], top2, fet2 - top2)
        toe = R(X, -s.curl[k]).to_3x3() @ L["toe"]
        set_dir(PB[L["foot"]], fet2, toe)


def key(f):
    for pb in PB:
        pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f)


# ---------------------------------------------------------------- gaits
def gait(t, cyc, duty, stride, phases, lift, travel=-Y, curl=55, tilt_f=40, tilt_h=30, roll_toe=0.15):
    """Feet for one instant of a footfall plan. Stance: glued to the ground, sliding against travel. Swing: lifted
    and carried forward with the carpus/hock folded."""
    s = St()
    for k, L in LEGS.items():
        ph = (t / cyc + phases[k]) % 1.0
        st = stride[0] if L["front"] else stride[1]
        if ph < duty:
            u = ph / duty
            p = L["home"] + travel * (st * (0.5 - u))
            # heel off at the end of stance: the fetlock rises while the toe stays
            r = smooth((u - (1 - roll_toe)) / roll_toe) if roll_toe > 0 else 0
            p.z += r * 0.06 * H; s.curl[k] = -r * 18
        else:
            u = (ph - duty) / (1 - duty)
            p = L["home"] + travel * (st * (-0.5 + smooth(u)))
            p.z += lift[0 if L["front"] else 1] * H * math.sin(math.pi * u) ** 0.8
            b = math.sin(math.pi * min(1, u * 1.15)) ** 1.2
            s.curl[k] = curl * b
            s.tilt[k] = (tilt_f if L["front"] else -tilt_h) * b
        s.feet[k] = p
    return s


PH_WALK = {"HL": 0.0, "FL": 0.75, "HR": 0.5, "FR": 0.25}  # lateral sequence: LH, LF, RH, RF a quarter apart
PH_GALLOP = {"HL": 0.0, "HR": 0.12, "FL": 0.52, "FR": 0.62}  # transverse gallop: hinds, suspension, fores


def walk(t, T, travel=-Y, sideways=False):
    """The knuckle-walk: a slow lateral-sequence walk, the claws kept curled (the fore-claws never touch down point
    first), a heavy side-to-side roll and the tail swinging."""
    s = gait(t, T, 0.68, (0.6 * SH, 0.6 * SH), PH_WALK, (0.09, 0.07), travel, curl=30, tilt_f=30, tilt_h=22, roll_toe=0.18)
    w = 2 * math.pi * t / T
    s.off.z = -0.012 * H + 0.008 * H * math.cos(2 * w)
    s.roll = 2.5 * math.sin(w); s.spine_yaw = 2 * math.sin(w)
    s.neck[0] = -2 + 2 * math.sin(2 * w + 0.6); s.head = 2.0 * math.sin(2 * w + 1.2); s.neck_yaw[0] = 2 * math.sin(w)
    s.tail_yaw = [3 * math.sin(w), 6 * math.sin(w + 0.8), 9 * math.sin(w + 1.6)]
    if sideways: s.roll *= 1.5
    return s


def gallop(t, T, head_low=0.0):
    """The run: a heavy rolling amble (a fast lateral walk, about half the time in the air for each foot), no flight."""
    s = gait(t, T, 0.52, (0.8 * SH, 0.8 * SH), PH_WALK, (0.13, 0.11), -Y, curl=45, tilt_f=45, tilt_h=35, roll_toe=0.2)
    w = 2 * math.pi * t / T
    s.off.z = -0.02 * H + 0.012 * H * math.cos(2 * w)
    s.roll = 4 * math.sin(w); s.spine_yaw = 3 * math.sin(w); s.pitch = 1.5 * math.sin(2 * w)
    s.neck[0] = -5 + 3 * math.sin(2 * w + 0.5); s.head = 3 * math.sin(2 * w + 1.0)
    s.tail_yaw = [4 * math.sin(w), 8 * math.sin(w + 0.8), 12 * math.sin(w + 1.6)]
    return s


# ---------------------------------------------------------------- the sloth's poses
HIP = HEAD["HindUpper.L"].copy(); HIP.x = 0.0
FWD, UP = Vector((0, -1, 0)), Vector((0, 0, 1))


def body_m(s):
    piv = s.pivot if s.pivot is not None else HEAD["Body"]
    rot = R(Z, s.yaw) @ R(Y, s.roll) @ R(X, -s.pitch)
    return Matrix.Translation(s.off) @ Matrix.Translation(piv) @ rot @ Matrix.Translation(-piv)


def lerpv(p, q, t): return p + (q - p) * t


# A pose is a dict of numbers; arms are (fwd, out, up, w): the knuckles placed at the shoulder joint + those metres
# (world axes; out = away from the midline) with weight w against the standing home. Keys are (u, pose) pairs,
# eased with smoothstep between neighbours; a key repeats the previous one's values for anything it leaves out.
BASE = dict(pitch=0.0, yaw=0.0, roll=0.0, offx=0.0, offy=0.0, offz=0.0, chest=0.0, spine_yaw=0.0, neck0=0.0, neck1=0.0,
            head=0.0, head_yaw=0.0, head_roll=0.0, jaw=0.0, tail0=0.0, tail1=0.0, tail2=0.0, tail_yaw=0.0, plant=0.0,
            FL=(0.0, 0.0, 0.0, 0.0), FR=(0.0, 0.0, 0.0, 0.0), curl=0.0, tilt=0.0, curlL=None, curlR=None)


def keyed(keys):
    full = []; cur = dict(BASE)
    for u, p in keys:
        cur = dict(cur); cur.update(p); full.append((u, cur))
    return full


def at(full, u):
    if u <= full[0][0]: return full[0][1]
    for (u0, a), (u1, b) in zip(full, full[1:]):
        if u <= u1:
            t = smooth((u - u0) / max(u1 - u0, 1e-6)); out = {}
            for k in a:
                x, y = a[k], b[k]
                if x is None or y is None: out[k] = y if t > 0.5 else x
                elif isinstance(x, tuple): out[k] = tuple(xi + (yi - xi) * t for xi, yi in zip(x, y))
                else: out[k] = x + (y - x) * t
            return out
    return full[-1][1]


def pose(p, s=None, rear=True):
    """A St from a pose dict. rear: the body pitches about the hip joints (the tripod), not the body centre."""
    s = s or St()
    s.pivot = HIP.copy() if rear else None
    s.pitch, s.yaw, s.roll = p["pitch"], p["yaw"], p["roll"]
    s.off = Vector((p["offx"], p["offy"], p["offz"]))
    s.chest, s.spine_yaw = p["chest"], p["spine_yaw"]
    s.neck = [p["neck0"], p["neck1"]]; s.head, s.head_yaw, s.head_roll, s.jaw = p["head"], p["head_yaw"], p["head_roll"], p["jaw"]
    s.tail = [p["tail0"], p["tail1"], p["tail2"]]; s.tail_yaw = [p["tail_yaw"] * 0.5, p["tail_yaw"], p["tail_yaw"]]
    s.tail_plant = p["plant"]
    M = body_m(s)
    for k in ("FL", "FR"):
        L = LEGS[k]; f, o, up, w = p[k]
        sh = M @ HEAD[L["up"]]
        tgt = sh + FWD * f + Vector((L["sx"], 0, 0)) * o + UP * up
        s.feet[k] = lerpv(L["home"], tgt, w)
        c = p["curlL" if k == "FL" else "curlR"]
        s.curl[k] = p["curl"] if c is None else c
        s.tilt[k] = p["tilt"] * w
    return s


# the tripod: reared ~58 deg about the hips, face brought back down toward level, tail laid on the ground
TRI = dict(pitch=58.0, offz=-0.08 * H, neck0=-22.0, neck1=-14.0, head=-18.0, plant=1.0, chest=-6.0,
           FL=(0.4, 0.15, -1.9, 1.0), FR=(0.4, 0.15, -1.9, 1.0), curl=40.0)
DOWN = dict(BASE)


def idle(t, T):
    u = t / T; w = 2 * math.pi * u
    s = St()
    s.off.z = 0.004 * H * math.sin(2 * w); s.chest = 0.8 * math.sin(2 * w)
    look = bump(u, 0.2, 0.35, 0.55, 0.7)
    s.neck_yaw[0] = 7 * look; s.head_yaw = 12 * look; s.neck[1] = 3 * look; s.head = 2 * math.sin(w)
    s.jaw = 6 * bump(u, 0.78, 0.82, 0.86, 0.9)  # a lick of the lips
    s.tail_yaw = [3 * math.sin(w), 5 * math.sin(w + 0.7), 7 * math.sin(w + 1.4)]
    for k in ("FL", "FR"): s.curl[k] = 6 * bump(u, 0.05, 0.12, 0.18, 0.25)  # the claws flex
    return s


ALERT = keyed([(0.0, {}), (0.12, dict(pitch=20, neck0=-6, head=-6, FL=(0.6, 0.1, -1.6, 0.6), FR=(0.6, 0.1, -1.6, 0.6), curl=20, plant=0.4)),
               (0.3, dict(TRI)),
               (0.42, dict(FL=(0.7, 1.7, 0.2, 1.0), FR=(0.7, 1.7, 0.2, 1.0), curl=-30, jaw=10, head=-10, neck0=-16)),
               (0.5, dict(jaw=34, head=-4, neck0=-10, curl=-45, chest=-2)),  # the roar, claws splayed
               (0.62, dict(jaw=30, head_yaw=10, FL=(0.9, 1.8, 0.4, 1.0), FR=(0.9, 1.8, 0.4, 1.0))),
               (0.72, dict(jaw=26, head_yaw=-10)),
               (0.8, dict(jaw=4, head_yaw=0, FL=(0.7, 1.5, 0.0, 1.0), FR=(0.7, 1.5, 0.0, 1.0), curl=10)),
               (0.88, dict(pitch=28, neck0=-8, neck1=-6, head=-8, plant=0.5, FL=(0.8, 0.2, -1.8, 0.7), FR=(0.8, 0.2, -1.8, 0.7), curl=30, chest=0)),
               (1.0, dict(DOWN))])


def alert(t, T):
    return pose(at(ALERT, t / T))


# the hooking claw pull: half-rears, the right arm reaches far out and hooks at 0.45, then hauls back to the chest
PRIMARY = keyed([(0.0, {}), (0.23, dict(pitch=22, plant=0.5, yaw=-8, neck0=-8, head=-6, FR=(1.6, 1.5, -0.6, 1.0), FL=(0.5, 0.1, -1.9, 0.5), curlR=-20, curlL=20, jaw=8)),
                 (0.42, dict(pitch=14, yaw=5, FR=(2.6, -0.5, -2.7, 1.0), curlR=60, jaw=16, head=-12)),  # the hook sweeps in across her
                 (0.7, dict(pitch=18, yaw=-4, FR=(0.5, 0.0, -1.2, 1.0), curlR=90, jaw=6, head=-6)),  # hauled in to the chest
                 (1.0, dict(DOWN))])


def attack_primary(t, T):
    return pose(at(PRIMARY, t / T))


# the two-arm overhead swipe: up into the tripod, both arms high and held trembling (the tell), then both come down
# together through the front at 0.64 and it lands back on its knuckles
HEAVY = keyed([(0.0, {}), (0.3, dict(TRI)),
               (0.44, dict(FL=(0.4, 0.5, 1.7, 1.0), FR=(0.4, 0.5, 1.7, 1.0), curl=70, jaw=14, head=-8, neck0=-14, chest=-10)),
               (0.6, dict(FL=(0.3, 0.55, 1.8, 1.0), FR=(0.3, 0.55, 1.8, 1.0), jaw=20, pitch=62)),
               (0.72, dict(pitch=22, plant=0.6, offy=-0.4, FL=(2.2, 0.35, -2.4, 1.0), FR=(2.2, 0.35, -2.4, 1.0), curl=95, jaw=28, neck0=-6, head=-14, chest=4)),
               (0.82, dict(pitch=4, plant=0.1, offy=-0.5, offz=-0.04 * H, FL=(2.0, 0.3, -2.6, 0.9), FR=(2.0, 0.3, -2.6, 0.9), curl=60, jaw=8, neck0=-8, head=-8, chest=0)),
               (1.0, dict(DOWN))])


def attack_heavy(t, T):
    s = pose(at(HEAVY, t / T)); u = t / T
    trem = math.sin(2 * math.pi * 12 * u) * bump(u, 0.44, 0.47, 0.57, 0.6)
    s.chest += 2 * trem
    for k in ("FL", "FR"): s.feet[k].z += 0.05 * trem
    return s


# the bear hug: the windup throws the arms wide in the tripod; the hug lurches forward, the arms close round her and
# bear her down; the crush holds her under the chest and squeezes twice
WIDE = dict(pitch=46, offz=-0.06 * H, neck0=-18, neck1=-10, head=-14, plant=0.9, FL=(0.8, 1.9, 0.3, 1.0), FR=(0.8, 1.9, 0.3, 1.0), curl=-30, jaw=22, chest=-6)
HUGLOW = dict(pitch=-4, plant=0.0, offz=-0.12 * H, offy=-0.2, neck0=-14, neck1=-6, head=-16, FL=(1.7, 0.25, -2.3, 1.0), FR=(1.7, 0.25, -2.3, 1.0), curl=95, jaw=10, chest=6)
GRAB = keyed([(0.0, {}), (0.25, dict(pitch=24, plant=0.5, neck0=-8, head=-6, FL=(0.7, 0.4, -1.6, 0.7), FR=(0.7, 0.4, -1.6, 0.7))), (0.7, dict(WIDE)),
              (0.85, dict(jaw=30, FL=(0.7, 2.0, 0.4, 1.0), FR=(0.7, 2.0, 0.4, 1.0))), (1.0, dict(WIDE))])
POUNCE = keyed([(0.0, dict(WIDE)), (0.3, dict(pitch=38, FL=(1.6, 1.6, -0.2, 1.0), FR=(1.6, 1.6, -0.2, 1.0), jaw=30)),
                (0.7, dict(pitch=12, plant=0.3, offz=-0.06 * H, neck0=-10, head=-14, FL=(2.0, 0.3, -1.5, 1.0), FR=(2.0, 0.3, -1.5, 1.0), curl=80, jaw=18, chest=2)),
                (0.9, dict(HUGLOW)), (1.0, dict(HUGLOW))])
PIN = keyed([(0.0, dict(HUGLOW)),
             (0.38, dict(offz=-0.16 * H, FL=(1.7, 0.05, -2.45, 1.0), FR=(1.7, 0.05, -2.45, 1.0), jaw=26, head=-20, chest=10)),
             (0.54, dict(HUGLOW)),
             (0.74, dict(offz=-0.17 * H, FL=(1.7, 0.03, -2.5, 1.0), FR=(1.7, 0.03, -2.5, 1.0), jaw=30, head=-22, chest=12, head_yaw=8)),
             (0.88, dict(HUGLOW, head_yaw=0)), (1.0, dict(HUGLOW))])


def grab(t, T): return pose(at(GRAB, t / T))
def pounce(t, T): return pose(at(POUNCE, t / T))
def pin_stab(t, T): return pose(at(PIN, t / T))


# the lumbering advance: upright on the hind legs, arms out in front, heavy alternating steps, the tail dragging
STRIDE_ADV = 0.55 * SH


def charge(t, T):
    u = t / T; w = 2 * math.pi * u
    p = dict(BASE); p.update(dict(pitch=50, offz=-0.035 * H, neck0=-18, neck1=-12, head=-16, plant=0.85, chest=-4, curl=40, jaw=10))
    sw = math.sin(w)
    p["FL"] = (1.2 + 0.25 * sw, 0.9, -0.9 + 0.15 * math.cos(w), 1.0); p["FR"] = (1.2 - 0.25 * sw, 0.9, -0.9 - 0.15 * math.cos(w), 1.0)
    p["roll"] = 5 * sw; p["spine_yaw"] = -4 * sw; p["head_yaw"] = 3 * sw; p["offz"] += -0.015 * H * abs(math.cos(w))
    p["tail_yaw"] = 6 * math.sin(w + 0.8)
    s = pose(p)
    g = gait(t, T, 0.6, (0.0, STRIDE_ADV), {"HL": 0.0, "HR": 0.5, "FL": 0.0, "FR": 0.0}, (0.0, 0.12), -Y, curl=8, tilt_f=0, tilt_h=8, roll_toe=0.1)
    for k in ("HL", "HR"): s.feet[k] = g.feet[k]; s.curl[k] = g.curl[k]; s.tilt[k] = g.tilt[k]
    return s


TOSS = keyed([(0.0, dict(pitch=50, offz=-0.07 * H, neck0=-18, neck1=-12, head=-16, plant=0.85, chest=-4, curl=40, jaw=10, FL=(1.2, 0.9, -0.9, 1.0), FR=(1.2, 0.9, -0.9, 1.0))),
              (0.12, dict(pitch=56, FL=(0.6, 0.6, 1.4, 1.0), FR=(0.6, 0.6, 1.4, 1.0), curl=70, jaw=24)),
              (0.3, dict(pitch=8, plant=0.2, offy=-0.6, offz=-0.05 * H, neck0=-6, head=-12, FL=(2.2, 0.4, -2.5, 1.0), FR=(2.2, 0.4, -2.5, 1.0), curl=90, jaw=30, chest=6)),
              (0.5, dict(pitch=-2, plant=0.0, offy=-0.6, FL=(1.8, 0.3, -2.7, 0.8), FR=(1.8, 0.3, -2.7, 0.8), jaw=8, chest=0)),
              (1.0, dict(DOWN))])


def toss(t, T): return pose(at(TOSS, t / T))


def hit_react(t, T):
    s = St(); u = t / T
    j = bump(u, 0.0, 0.12, 0.3, 1.0)
    s.off.y = 0.04 * H * j; s.off.z = -0.02 * H * j; s.roll = 3 * j; s.pitch = 3 * j
    s.neck[0] = 8 * j; s.head = 10 * j; s.head_yaw = 12 * j; s.jaw = 12 * j; s.tail[0] = 15 * j
    for k in LEGS: s.feet[k] = LEGS[k]["home"].copy()
    return s


def collapse(t, T, death):
    """Knockdown / death: the forelegs buckle, the hindquarters sink, then the body rolls onto its right side with the
    legs out; the head rolls back up so the snout lies along the ground, not through it; the tail stays on the ground.
    Ends lying still."""
    s = St(); u = t / T
    kneel = smooth(u / 0.35); sink = smooth((u - 0.2) / 0.3); roll = smooth((u - 0.4) / 0.4)
    bh = HEAD["Body"].z
    lie_z = 0.42 * H  # the barrel is wide: body centre height lying on its side
    s.off.z = -(bh * 0.28) * kneel * (1 - roll) - (bh - lie_z) * roll
    s.pitch = -8 * kneel * (1 - sink) + 5 * sink * (1 - roll)
    s.roll = -84 * roll
    s.neck[0] = -12 * kneel + (8 if death else 16) * roll; s.head = -8 * kneel - (14 if death else 0) * roll
    s.neck_yaw[0] = 6 * roll; s.jaw = (14 if death else 4) * roll
    s.head_roll = -60 * roll
    s.tail[0] = -10 * roll
    for k, L in LEGS.items():
        fold = kneel if L["front"] else sink
        p = L["home"].copy()
        p.z += 0.05 * H * fold * (1 - roll)
        s.tilt[k] = (70 if L["front"] else -45) * fold * (1 - roll)
        s.curl[k] = 60 * fold * (1 - roll) + 20 * roll
        s.feet[k] = p
    s.follow = roll; s.tail_plant = 1.0
    return s


def sleep(t, T):
    """Lies down sternal (on its belly, legs folded under) and rests the chin low; not looped, the game holds the end."""
    s = St(); u = t / T
    kneel = smooth(u / 0.35); drop = smooth((u - 0.3) / 0.35); rest = smooth((u - 0.65) / 0.3)
    bh = HEAD["Body"].z
    s.off.z = -bh * 0.16 * kneel * (1 - drop) - bh * 0.22 * drop
    s.pitch = -10 * kneel * (1 - drop)
    s.roll = -4 * drop
    s.neck[0] = -6 * kneel - 4 * rest; s.head = -8 * rest; s.neck_yaw[0] = 8 * rest
    s.tail[0] = -8 * drop
    for k, L in LEGS.items():
        fold = kneel if L["front"] else drop
        s.tilt[k] = (95 if L["front"] else -80) * fold
        s.curl[k] = 80 * fold
    s.tail_plant = 1.0; s.tail_yaw = [0.0, 20 * rest, 30 * rest]  # the tail curls round beside it
    return s


def feed(t, T):
    """Browsing: rears up into a low tripod, the right arm reaches high for a branch, hooks it down to the mouth, chews."""
    u = t / T
    p = at(FEED, u)
    s = pose(p)
    chew = bump(u, 0.5, 0.55, 0.82, 0.86) * (0.5 + 0.5 * math.sin(2 * math.pi * 8 * u))
    s.jaw += 14 * chew
    return s


FEED = keyed([(0.0, {}), (0.2, dict(pitch=40, offz=-0.05 * H, neck0=-8, neck1=-4, head=-6, plant=0.9, FL=(0.5, 0.2, -1.9, 1.0), FR=(0.6, 0.3, -1.6, 1.0), curl=30)),
              (0.35, dict(neck0=4, head=8, FR=(1.0, 0.3, 2.2, 1.0), curlR=80, jaw=10)),
              (0.5, dict(neck0=-4, head=-4, FR=(1.1, -0.1, 0.9, 1.0), curlR=95, jaw=4)),
              (0.85, dict(FR=(1.0, -0.1, 0.8, 1.0))),
              (1.0, dict(DOWN))])


def sideways_walk(t, T, sgn):
    return walk(t, T, Vector((sgn, 0, 0)), True)


CLIPS = {
    "idle": (4.0, idle, True), "walk": (1.6, walk, True), "run": (0.9, gallop, True), "charge": (1.3, charge, True),
    "strafe_left": (1.6, lambda t, T: sideways_walk(t, T, 1), True),
    "strafe_right": (1.6, lambda t, T: sideways_walk(t, T, -1), True),
    "walk_back": (1.6, lambda t, T: walk(t, T, Y), True),
    "alert": (2.6, alert, False), "attack_primary": (1.3, attack_primary, False),
    "attack_heavy": (2.2, attack_heavy, False), "grab": (1.4, grab, False), "pounce": (1.4, pounce, False),
    "pin_stab": (2.4, pin_stab, False), "toss": (1.2, toss, False), "hit_react": (0.7, hit_react, False),
    "knockdown": (1.8, lambda t, T: collapse(t, T, False), False), "death": (2.4, lambda t, T: collapse(t, T, True), False),
    "sleep": (3.0, sleep, False), "feed": (4.0, feed, False),
}

os.makedirs(OUT, exist_ok=True)
GROUND = {"knockdown", "death", "sleep"}


for name, (T, fn, loop) in CLIPS.items():
    if ONLY and name not in ONLY: continue
    act = bpy.data.actions.new(name)
    arm.animation_data_create(); arm.animation_data.action = act
    N = max(2, int(round(T * FPS)))
    for f in range(N + 1):
        t = T * f / N
        s = fn(t % T if loop else t, T) if not loop else fn(t if f < N else 0.0, T)
        if name in GROUND:
            # feet ride with the body as it goes down: the hoof keeps its offset below its hip/shoulder, folded,
            # and never goes under the floor
            rot = R(Z, s.yaw) @ R(Y, s.roll) @ R(X, -s.pitch)
            piv = s.pivot if s.pivot is not None else HEAD["Body"]
            M = Matrix.Translation(s.off) @ Matrix.Translation(piv) @ rot @ Matrix.Translation(-piv)
            for k, L in LEGS.items():
                p = M @ LEGS[k]["home"]
                fold = s.tilt[k] / (95.0 if L["front"] else -80.0) if name == "sleep" else abs(s.tilt[k]) / 70.0
                fold = min(1.0, max(0.0, fold))
                joint = M @ HEAD[L["up"]]
                legdir = (M.to_3x3() @ -Z)
                # folded: the hoof comes up toward the joint (carpus/hock bent) and slightly back/forward
                tuck = joint + legdir * (0.38 * H) + (M.to_3x3() @ Y) * (0.12 * H if L["front"] else -0.05 * H)
                q = p.lerp(tuck, 0.85 * fold) if name == "sleep" else p.lerp(tuck, 0.4 * fold)
                q.z = max(q.z, LEGS[k]["home"].z * 0.9)
                s.feet[k] = q
        apply(s)
        key(f + 1)
    act.use_fake_user = True
    sc.frame_start, sc.frame_end = 1, N + 1
    bpy.ops.object.select_all(action="DESELECT"); arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=True,
        export_animation_mode="ACTIVE_ACTIONS", export_frame_range=True, export_force_sampling=True,
        export_skins=True, export_yup=True, export_materials="NONE")
    print(f"CLIP {name} {T:.2f}s {N + 1} frames -> {path}")
for pb in PB: pb.matrix_basis.identity()
arm.animation_data.action = None
bpy.ops.wm.save_as_mainfile(filepath=BLEND.replace(".blend", "_anim.blend"))
