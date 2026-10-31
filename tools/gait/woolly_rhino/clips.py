"""Woolly rhino clips on the build_rig.py skeleton (the solver and gaits are SP-MEGALOCEROS's deer clips.py; the moves
are the rhino's own): footfall-planned gaits and keyed moves with an analytic leg solver, exported skeleton-only.

  Blender -b -P tools/gait/woolly_rhino/clips.py -- <rig.blend> <anim_dir> [clip ...]

Signature moves (hit frames = anim_events.json hit_frac; the game judges each hit at the bone named in the species
JSON pipeline.hit_parts): alert = the paw-the-ground telegraph (the display before the charge), charge = the
head-down gallop with the horn levelled, toss = the horn hooks up through the target at 0.3 (played on the charge
impact), attack_primary = the forefoot stamp at 0.42, attack_heavy = the wide horn sweep, cocked right, held, then
ripped across to the left through the front at 0.72.

Every frame: the body pivots (Body bone), the spine, neck, head, jaw and tail turn by small angles from rest, then
each leg is solved to a hoof target: the cannon keeps a set tilt from its rest direction, the hock (hind) or carpus
(front) sits at fetlock + cannon, and the upper two bones are a two-bone solve in the leg's own plane with the
stifle bending forward and the elbow back (deer anatomy), so knees never reverse. The pastern (Foot bone) points at
a toe target: flat on the ground in stance, curled in swing. Bones are posed by the minimal rotation from their rest
direction (all leg motion is sagittal, so no twist). Hits land where the antlers or hooves are: anim_events.json
hit_frac (attack_primary 0.42, attack_heavy 0.72, kick 0.45).
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
SH = 2.4  # stride scale (m): walk stride 0.62 SH ~ 1.5 m on a 2.9 m rhino
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
        s.jaw = 0.0; s.tail = [0.0, 0.0]; s.tail_yaw = [0.0, 0.0]
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
    for i, tb in enumerate(("Tail1", "Tail2")):
        turn(PB[tb], side, s.tail[i]); turn(PB[tb], up, s.tail_yaw[i])
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
    s = gait(t, T, 0.66, (0.5 * SH, 0.5 * SH), PH_WALK, (0.11, 0.08), travel, curl=50, tilt_f=35, tilt_h=22)
    w = 2 * math.pi * t / T
    s.off.z = -0.012 * H + 0.008 * H * math.cos(2 * w)
    s.roll = 1.5 * math.sin(w)
    s.neck[0] = -2.5 + 2.5 * math.sin(2 * w + 0.6); s.head = 2.0 * math.sin(2 * w + 1.2)
    s.tail[0] = 3 * math.sin(w); s.tail_yaw[1] = 6 * math.sin(w + 1)
    if sideways: s.roll *= 2
    return s


def gallop(t, T, head_low=0.0):
    s = gait(t, T, 0.42, (0.62 * SH, 0.5 * SH), PH_GALLOP, (0.18, 0.15), -Y, curl=85, tilt_f=70, tilt_h=55, roll_toe=0.2)
    w = 2 * math.pi * t / T
    # the back rocks: nose up as the forelegs land (gather), croup up as the hinds push off
    s.pitch = 3.5 * math.sin(w - 0.5)
    s.off.z = -0.015 * H + 0.02 * H * math.sin(2 * w - 0.8)
    s.chest = 3 * math.sin(w)
    s.neck[0] = -4 - 6 * math.sin(w - 0.2) - head_low; s.head = 4 * math.sin(w + 0.5) - head_low * 0.4
    s.tail[0] = 12 + 6 * math.sin(w)
    return s


def charge(t, T):
    s = gallop(t, T, head_low=0.0)
    # head down, nose near the grass, the nose horn levelled forward like a lance; the body lower, the tail up
    s.neck[0] -= 8; s.neck[1] -= 6; s.head -= 16; s.off.z -= 0.025 * H; s.pitch -= 2
    s.jaw = 4; s.tail[0] += 10
    return s


# ---------------------------------------------------------------- keyed moves
def idle(t, T):
    s = St(); w = 2 * math.pi * t / T
    s.off.z = 0.004 * H * math.sin(w * 2)  # breathing
    s.chest = 0.8 * math.sin(w * 2)
    look = bump(t / T, 0.25, 0.4, 0.6, 0.75)
    s.neck_yaw[0] = 5 * look; s.head_yaw = 9 * look; s.neck[1] = 2 * look
    s.head = 2 * math.sin(w)
    s.tail_yaw[1] = 15 * bump(t / T, 0.1, 0.13, 0.16, 0.2) * math.sin(t * 40)
    s.jaw = 3 * bump(t / T, 0.8, 0.85, 0.9, 0.95)
    return s


def alert(t, T):
    """The paw-the-ground telegraph (owner: "paw-the-ground telegraph then a long charge"): the head drops until the
    horn points at the threat, a snort, then the right forefoot scrapes back through the dirt three times while the
    head bobs and hooks; it ends set low, horn levelled, ready to go. Plays as the display before the charge."""
    s = St(); u = t / T
    low = smooth(u / 0.18)
    s.neck[0] = -10 * low; s.neck[1] = -6 * low; s.head = -20 * low
    s.off.z = -0.025 * H * low; s.pitch = -2 * low
    snort = bump(u, 0.12, 0.17, 0.2, 0.26)
    s.jaw = 10 * snort; s.head += 6 * snort; s.chest = 2 * snort
    for i, c in enumerate((0.38, 0.6, 0.82)):  # three scrapes: forward and up, then down and dragged back
        ph = (u - (c - 0.16)) / 0.2
        if 0.0 <= ph <= 1.0:
            f = s.feet["FR"]
            reach = math.sin(math.pi * min(1.0, ph / 0.45)) if ph < 0.45 else 0.0
            drag = smooth((ph - 0.45) / 0.55)
            f.y += -0.16 * H * smooth(ph / 0.45) * (1 - drag) + 0.06 * H * drag * (1 - smooth((ph - 0.9) / 0.1))
            f.z += 0.10 * H * reach
            s.curl["FR"] = 45 * reach; s.tilt["FR"] = 40 * reach
        s.head += -5 * bump(u, c - 0.06, c - 0.02, c, c + 0.05)  # a hook of the horn with each scrape
        s.head_yaw += 6 * bump(u, c - 0.06, c - 0.02, c, c + 0.05) * (1 if i % 2 else -1)
    s.tail[0] = 18 * low + 8 * math.sin(2 * math.pi * 3 * u)
    s.feet["FL"] = LEGS["FL"]["home"] + Vector((0.03 * H * low, -0.03 * H * low, 0))
    return s


def attack_primary(t, T):
    """The stamp: the forequarters rise off the forefeet (the croup sinks a little), both forelegs fold and come
    forward, then the body drops and lunges and both forefeet slam into the ground a stride ahead at 0.42."""
    s = St(); u = t / T; hit = 0.42
    rise = smooth((u - 0.04) / 0.28) * (1 - smooth((u - 0.32) / (hit - 0.32)))
    lunge = smooth((u - 0.2) / (hit - 0.2)) * (1 - smooth((u - 0.62) / 0.32))
    s.pivot = Vector((0, L_HY, LEGS["HL"]["home"].z + 0.15 * H))
    s.pitch = 13 * rise
    s.off.y = -0.22 * H * lunge
    s.off.z = -0.03 * H * bump(u, hit - 0.03, hit, hit + 0.03, hit + 0.15)
    s.neck[0] = 6 * rise - 6 * lunge; s.head = 4 * rise - 10 * lunge; s.jaw = 8 * rise
    s.tail[0] = 15 * rise
    for k in ("HL", "HR"): s.feet[k] = LEGS[k]["home"].copy()
    for i, k in enumerate(("FL", "FR")):
        L = LEGS[k]
        air = bump(u, 0.06, 0.2, hit - 0.05, hit)
        p = L["home"].copy() + Vector((0, -0.30 * H * lunge, 0))
        p.z += 0.30 * H * air * (0.6 + 0.4 * rise)
        p.y += 0.06 * H * air * rise
        s.feet[k] = p
        s.curl[k] = 70 * air; s.tilt[k] = 75 * air
    return s


def attack_heavy(t, T):
    """The wide horn sweep: weight onto the left legs, the head cocked far right and low with the horn laid
    sideways (the held tell, trembling), then the whole front swings from the hips and the horn rips across the front
    to the far left at hit 0.72, the body yawing with it; it recovers to centre."""
    s = St(); u = t / T; hit = 0.72
    cock = smooth(u / 0.3)
    swing = smooth((u - 0.6) / (hit + 0.1 - 0.6))  # 0 -> 1 across the hit
    back = smooth((u - 0.86) / 0.14)
    side = cock * (1 - 2 * swing) * (1 - back) + 0 * back  # +1 right ... -1 left
    trem = math.sin(2 * math.pi * 9 * u) * bump(u, 0.3, 0.35, 0.56, 0.6)
    s.pivot = Vector((0, L_HY, HEAD["Body"].z))
    s.yaw = -16 * side  # +yaw turns the nose to +X (left): the body follows the horn
    s.spine_yaw = -6 * side
    s.neck_yaw[0] = -14 * side; s.neck_yaw[1] = -12 * side; s.head_yaw = -18 * side + 2 * trem
    s.head_roll = 26 * side
    s.neck[0] = -10 * cock * (1 - back); s.head = -16 * cock * (1 - back) - 4 * abs(trem)
    s.off.z = -0.03 * H * cock * (1 - back)
    s.roll = 3 * side
    s.jaw = 6 * cock + 10 * bump(u, hit - 0.08, hit, hit + 0.05, hit + 0.15)
    s.tail[0] = 15 * cock; s.tail_yaw[0] = 15 * side
    # the forefeet step with the swing (planted; a quick shuffle toward the sweep side)
    for k in ("FL", "FR"):
        L = LEGS[k]; p = L["home"].copy()
        shift = -0.08 * H * side
        p.x += shift; p.y += -0.03 * H * cock * (1 - back)
        lift = bump(u, 0.62, 0.66, 0.74, 0.8) if k == ("FR" if side > 0 else "FL") else 0.0
        p.z += 0.06 * H * lift
        s.feet[k] = p
    return s


def toss(t, T):
    """The horn toss (owner: "a long charge that tosses the target with the horn"): it starts in the charge's head-low
    pose and, as it hits (0.3), the head and neck whip up and to the right so the nose horn hooks up through the target;
    the forequarters lift with it, then the body settles."""
    s = St(); u = t / T; hit = 0.3
    start = 1 - smooth(u / hit)
    hook = bump(u, 0.05, hit, hit + 0.15, 0.85)
    s.neck[0] = -8 * start + 18 * hook; s.neck[1] = -6 * start + 7 * hook; s.head = -16 * start + 22 * hook
    s.head_yaw = 14 * hook; s.head_roll = -12 * hook; s.neck_yaw[1] = 6 * hook
    s.pivot = Vector((0, L_HY, LEGS["HL"]["home"].z + 0.15 * H))
    s.pitch = 7 * hook - 2 * start
    s.off.y = -0.12 * H * smooth(u / 0.4) * (1 - smooth((u - 0.6) / 0.4))
    s.off.z = -0.03 * H * start
    s.jaw = 10 * hook
    s.tail[0] = 12 * start + 20 * hook
    for k in ("FL", "FR"):
        L = LEGS[k]; p = L["home"].copy() + Vector((0, -0.12 * H * smooth(u / 0.4) * (1 - smooth((u - 0.6) / 0.4)), 0))
        air = bump(u, hit - 0.08, hit, hit + 0.1, hit + 0.3)
        p.z += 0.12 * H * air; s.curl[k] = 50 * air; s.tilt[k] = 50 * air
        s.feet[k] = p
    for k in ("HL", "HR"): s.feet[k] = LEGS[k]["home"].copy()
    return s


def hit_react(t, T):
    s = St(); u = t / T
    j = bump(u, 0.0, 0.12, 0.3, 1.0)
    s.off.y = 0.04 * H * j; s.off.z = -0.02 * H * j; s.roll = 3 * j; s.pitch = 3 * j
    s.neck[0] = 8 * j; s.head = 10 * j; s.head_yaw = 12 * j; s.jaw = 12 * j; s.tail[0] = 15 * j
    for k in LEGS: s.feet[k] = LEGS[k]["home"].copy()
    return s


def collapse(t, T, death):
    """Knockdown / death: the forelegs buckle, the hindquarters sink, then the body rolls onto its right side with the
    legs out; the head rolls back up so the horn lies along the ground, not through it. Ends lying still."""
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
    s.follow = roll
    return s


def sleep(t, T):
    """Lies down sternal (on its belly, legs folded under) and rests the chin low; not looped, the game holds the end."""
    s = St(); u = t / T
    kneel = smooth(u / 0.35); drop = smooth((u - 0.3) / 0.35); rest = smooth((u - 0.65) / 0.3)
    bh = HEAD["Body"].z
    s.off.z = -bh * 0.18 * kneel * (1 - drop) - bh * 0.27 * drop
    s.pitch = -10 * kneel * (1 - drop)
    s.roll = -4 * drop
    s.neck[0] = -6 * kneel - 4 * rest; s.head = -8 * rest; s.neck_yaw[0] = 8 * rest
    s.tail[0] = -8 * drop
    for k, L in LEGS.items():
        fold = kneel if L["front"] else drop
        s.tilt[k] = (95 if L["front"] else -80) * fold
        s.curl[k] = 80 * fold
    return s


def feed(t, T):
    """Grazing: the head goes down to the grass (the horn swings forward, clear of it), crops and chews, lifts to look."""
    s = St(); u = t / T
    down = bump(u, 0.05, 0.25, 0.78, 0.95)
    s.neck[0] = -22 * down; s.neck[1] = -12 * down; s.head = -14 * down
    s.off.z = -0.02 * H * down; s.pitch = -3 * down
    chew = down * (0.5 + 0.5 * math.sin(2 * math.pi * 6 * u))
    s.jaw = 12 * chew * (u > 0.25) * (u < 0.78)
    s.head_yaw = 6 * math.sin(2 * math.pi * 2 * u) * down
    for k in ("FL", "FR"):
        s.feet[k] = LEGS[k]["home"] + Vector((LEGS[k]["sx"] * 0.03 * H * down, -0.03 * H * down, 0))
    s.tail_yaw[1] = 10 * math.sin(2 * math.pi * 3 * u)
    return s


def sideways_walk(t, T, sgn):
    return walk(t, T, Vector((sgn, 0, 0)), True)


CLIPS = {
    "idle": (3.0, idle, True), "walk": (1.3, walk, True), "run": (0.7, gallop, True), "charge": (0.7, charge, True),
    "strafe_left": (1.3, lambda t, T: sideways_walk(t, T, 1), True),
    "strafe_right": (1.3, lambda t, T: sideways_walk(t, T, -1), True),
    "walk_back": (1.3, lambda t, T: walk(t, T, Y), True),
    "alert": (2.0, alert, False), "attack_primary": (1.1, attack_primary, False),
    "attack_heavy": (1.8, attack_heavy, False), "toss": (1.0, toss, False), "hit_react": (0.6, hit_react, False),
    "knockdown": (1.6, lambda t, T: collapse(t, T, False), False), "death": (2.2, lambda t, T: collapse(t, T, True), False),
    "sleep": (3.0, sleep, False), "feed": (3.0, feed, False),
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
