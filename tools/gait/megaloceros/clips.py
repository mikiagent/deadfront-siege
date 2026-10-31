"""Megaloceros clips, authored from scratch on the build_rig.py skeleton: footfall-planned gaits and keyed moves with
an analytic leg solver, exported skeleton-only like the game's other clips.

  Blender -b -P tools/gait/megaloceros/clips.py -- <rig.blend> <anim_dir> <stag|doe> [clip ...]

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
BLEND, OUT, VAR = a[:3]
ONLY = set(a[3:])
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
STAG = VAR == "stag"
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
# Strides are in stag metres for both sexes: the game bakes one natural walk/run speed per species, so the doe's
# planted feet only match the ground if she covers the same ground per cycle (longer-legged for her size anyway).
SH = 3.05
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
        turn(PB[nb], side, -s.neck[i])  # +neck = up; turn(PB[nb], up, s.neck_yaw[i])
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
def ground(home, d, turn):
    """Where a ground point that sits under `home` at mid-stance is after the body has travelled d metres forward.
    turn = 0: straight (it slides back by d). turn = +-R: the body runs an arc of radius R to its left (+) or right
    (-), so the ground turns about the arc centre and planted hooves follow the arc (MEGAJOUST: no slide in a turn)."""
    if not turn: return home + Y * d
    c = Vector((turn, 0, home.z)); ang = -d / turn
    return c + R(Z, math.degrees(ang)).to_3x3() @ (home - c)


def gait(t, cyc, duty, stride, phases, lift, travel=-Y, curl=55, tilt_f=40, tilt_h=30, roll_toe=0.15, turn=0.0):
    """Feet for one instant of a footfall plan. Stance: glued to the ground, sliding against travel. Swing: lifted
    and carried forward with the carpus/hock folded. turn: arc radius (m, + = to the left) for the turning gallop."""
    s = St()
    for k, L in LEGS.items():
        ph = (t / cyc + phases[k]) % 1.0
        st = stride[0] if L["front"] else stride[1]
        if ph < duty:
            u = ph / duty
            p = ground(L["home"], st * (u - 0.5), turn) if turn else L["home"] + travel * (st * (0.5 - u))
            # heel off at the end of stance: the fetlock rises while the toe stays
            r = smooth((u - (1 - roll_toe)) / roll_toe) if roll_toe > 0 else 0
            p.z += r * 0.06 * H; s.curl[k] = -r * 18
        else:
            u = (ph - duty) / (1 - duty)
            p = ground(L["home"], st * (0.5 - smooth(u)), turn) if turn else L["home"] + travel * (st * (-0.5 + smooth(u)))
            p.z += lift[0 if L["front"] else 1] * H * math.sin(math.pi * u) ** 0.8
            b = math.sin(math.pi * min(1, u * 1.15)) ** 1.2
            s.curl[k] = curl * b
            s.tilt[k] = (tilt_f if L["front"] else -tilt_h) * b
        s.feet[k] = p
    return s


PH_WALK = {"HL": 0.0, "FL": 0.75, "HR": 0.5, "FR": 0.25}  # lateral sequence: LH, LF, RH, RF a quarter apart
PH_GALLOP = {"HL": 0.0, "HR": 0.12, "FL": 0.52, "FR": 0.62}  # transverse gallop: hinds, suspension, fores


def walk(t, T, travel=-Y, sideways=False):
    s = gait(t, T, 0.66, (0.62 * SH, 0.62 * SH), PH_WALK, (0.11, 0.08), travel, curl=50, tilt_f=35, tilt_h=22)
    w = 2 * math.pi * t / T
    s.off.z = -0.012 * H + 0.008 * H * math.cos(2 * w)
    s.roll = 1.5 * math.sin(w)
    s.neck[0] = -2.5 + 2.5 * math.sin(2 * w + 0.6); s.head = 2.0 * math.sin(2 * w + 1.2)
    s.tail[0] = 3 * math.sin(w); s.tail_yaw[1] = 6 * math.sin(w + 1)
    if sideways: s.roll *= 2
    return s


def gallop(t, T, head_low=0.0, turn=0.0):
    s = gait(t, T, 0.34, (0.76 * SH, 0.76 * SH), PH_GALLOP, (0.24, 0.20), -Y, curl=85, tilt_f=70, tilt_h=55, roll_toe=0.2, turn=turn)
    w = 2 * math.pi * t / T
    # the back rocks: nose up as the forelegs land (gather), croup up as the hinds push off
    s.pitch = 6.0 * math.sin(w - 0.5)
    s.off.z = -0.02 * H + 0.035 * H * math.sin(2 * w - 0.8)
    s.chest = 3 * math.sin(w)
    s.neck[0] = -4 - 6 * math.sin(w - 0.2) - head_low; s.head = 4 * math.sin(w + 0.5) - head_low * 0.4
    s.tail[0] = 12 + 6 * math.sin(w)
    return s


def charge(t, T):
    s = gallop(t, T, head_low=0.0)
    # head down, antlers forward like a battering ram; the body lower and the neck stretched out
    s.neck[0] -= 30; s.neck[1] -= 18; s.head -= 22; s.off.z -= 0.03 * H; s.pitch -= 2
    s.jaw = 6
    return s


# MEGAJOUST: the joust's wheel round between passes. The arc radius is the brain's (ai.json megaloceros_joust
# tactics joust_turn_radius_m, stag metres like the strides); the run's stride and cycle, so its natural speed is the run's.
TURN_R = 9.0


def run_turn(t, T, sgn):
    """Turning gallop, sgn +1 = to the left: planted hooves follow the arc (ground() about the arc centre), the body
    banks into the turn and the spine and head look round it."""
    s = gallop(t, T, turn=sgn * TURN_R)
    bank = 1.0 if STAG else 0.0  # the doe's run already sits at the stretch limit (11.8 of 12) at the hips: no bank
    s.roll += 9 * sgn * bank; s.spine_yaw = 5 * sgn * bank; s.head_yaw = 9 * sgn
    s.tail_yaw[0] = -6 * sgn
    return s


def tackle(t, T):
    """Doe: the all-out tackle run (owner 2026-10-31: 'give it your all tackle, low center of gravity'): the gallop
    with the chest dropped, the head and neck thrust out low like a ram, ears back, the legs driving."""
    s = gallop(t, T)
    s.off.z -= 0.07 * H; s.pitch -= 4; s.chest = 4 + 3 * math.sin(2 * math.pi * t / T)
    s.neck[0] -= 16; s.neck[1] -= 12; s.head -= 4; s.jaw = 4  # deeper and the brisket tears against the forelegs
    s.tail[0] = 20
    return s


def charge_crouch(t, T):
    """The joust's tell, body still, before every pass. Stag: the antlers come down level at the threat, a forehoof
    scrapes the ground twice and the weight sinks back onto the hocks. Doe: she drops her chest and head low and
    gathers her hind legs under her for the tackle (the brain turns her to the threat meanwhile)."""
    s = St(); u = t / T
    low = smooth(u / 0.45)
    if STAG:
        s.neck[0] = -30 * low; s.neck[1] = -18 * low; s.head = -22 * low  # the charge's head carriage
        s.off.z = -0.03 * H * low; s.pitch = -2 * low
        for i, c in enumerate((0.42, 0.72)):  # two scrapes with the right forehoof: forward, then raked back
            sc = bump(u, c - 0.14, c - 0.06, c + 0.02, c + 0.1)
            f = s.feet["FR"]; f.z += 0.10 * H * sc; f.y += -0.08 * H * sc + 0.10 * H * bump(u, c - 0.04, c, c + 0.06, c + 0.1)
            s.curl["FR"] = 55 * sc; s.tilt["FR"] = 45 * sc
        s.head_roll = 4 * math.sin(2 * math.pi * 2 * u) * low
    else:
        s.off.z = -0.08 * H * low; s.pitch = -5 * low; s.hips = -4 * low
        s.neck[0] = -26 * low; s.neck[1] = -10 * low; s.head = -6 * low; s.tail[0] = 18 * low
        for k in ("HL", "HR"):  # hind feet step in under her
            s.feet[k] = LEGS[k]["home"] + Vector((0, -0.07 * H * low, 0))
    return s


# ---------------------------------------------------------------- keyed moves
def idle(t, T):
    s = St(); w = 2 * math.pi * t / T
    s.off.z = 0.004 * H * math.sin(w * 2)  # breathing
    s.chest = 0.8 * math.sin(w * 2)
    look = bump(t / T, 0.25, 0.4, 0.6, 0.75)
    s.neck_yaw[0] = 7 * look; s.head_yaw = 10 * look; s.neck[1] = 3 * look
    s.head = 2 * math.sin(w)
    s.tail_yaw[1] = 15 * bump(t / T, 0.1, 0.13, 0.16, 0.2) * math.sin(t * 40)
    s.jaw = 2 * bump(t / T, 0.8, 0.85, 0.9, 0.95)
    return s


def alert(t, T):
    """Stag: the rut roar (head up and back, jaw wide), then the antlers lowered at the threat and shaken: the
    telegraph before the charge. Doe: head high and ears up, then the warning stamp with a forehoof."""
    s = St(); u = t / T
    if STAG:
        roar = bump(u, 0.05, 0.22, 0.48, 0.58)
        s.neck[0] = 18 * roar; s.neck[1] = 10 * roar; s.head = 20 * roar; s.jaw = 24 * roar * (1 + 0.1 * math.sin(t * 60))
        s.chest = 3 * roar; s.off.z = 0.01 * H * roar
        low = smooth((u - 0.55) / 0.2)
        s.neck[0] += -26 * low; s.neck[1] += -14 * low; s.head += -18 * low
        shake = low * math.sin(2 * math.pi * 3 * max(0, u - 0.7) / 0.3) * (u > 0.7)
        s.head_roll = 9 * shake; s.neck_yaw[1] = 6 * shake
        s.off.z -= 0.025 * H * low; s.pitch = -2 * low
        # front feet brace wider and a little forward
        for k in ("FL", "FR"):
            s.feet[k] = LEGS[k]["home"] + Vector((LEGS[k]["sx"] * 0.06 * H * low, -0.05 * H * low, 0))
    else:
        up = smooth(u / 0.18)
        s.neck[0] = 10 * up; s.head = 8 * up; s.tail[0] = 25 * up
        for i, c in enumerate((0.35, 0.62)):  # two stamps with the left forehoof
            lift = bump(u, c - 0.1, c - 0.03, c, c + 0.005)
            s.feet["FL"].z += 0.16 * H * lift; s.feet["FL"].y -= 0.03 * H * lift
            s.curl["FL"] = 60 * lift; s.tilt["FL"] = 50 * lift
        s.off.z = -0.01 * H * up
    return s


def attack_primary(t, T):
    """Stag: antler hook. The head drops (antler points to the ground), then rips up and to the side through the
    target at 0.42. Doe: forehoof strike: weight back, the right foreleg strikes out and down at 0.42."""
    s = St(); u = t / T; hit = 0.42
    if STAG:
        # at the hit the head is still low and the antlers sweep up and forward through the target
        down = smooth(u / 0.28) * (1 - smooth((u - 0.36) / 0.14))
        rip = bump(u, 0.3, 0.62, 0.7, 0.95)
        s.neck[0] = -34 * down + 22 * rip; s.neck[1] = -16 * down + 10 * rip; s.head = -22 * down + 16 * rip
        s.head_yaw = -14 * down + 22 * rip; s.neck_yaw[1] = 10 * rip; s.head_roll = -12 * rip
        s.off.y = -0.06 * H * rip; s.off.z = -0.03 * H * down; s.pitch = -3 * down + 2 * rip
        s.jaw = 8 * rip
        for k in ("HL", "HR"): s.feet[k] = LEGS[k]["home"].copy()
    else:
        back = bump(u, 0.0, 0.25, 0.35, 0.6); strike = bump(u, 0.22, hit, hit + 0.06, 0.75)
        s.off.y = 0.04 * H * back - 0.06 * H * strike; s.pitch = 6 * back
        s.neck[0] = 8 * back - 6 * strike; s.head = 6 * back
        lift = bump(u, 0.12, 0.3, hit - 0.02, hit)
        f = s.feet["FR"]; f.z += 0.32 * H * lift; f.y -= 0.18 * H * smooth((u - 0.2) / (hit - 0.2)) * (1 - smooth((u - 0.6) / 0.3))
        s.curl["FR"] = 70 * lift; s.tilt["FR"] = 80 * lift
    return s


def attack_heavy(t, T):
    """Rear-up and stomp (both sexes): weight sinks onto the hocks, the forequarters rise ~40 deg with the forelegs
    folded and pawing, a hold at the top (the tell), then the body crashes down and forward and both forehooves
    slam into the ground ahead at 0.72."""
    s = St(); u = t / T; hit = 0.72
    rise = smooth((u - 0.05) / 0.3) * (1 - smooth((u - 0.58) / (hit - 0.58)))
    lunge = smooth((u - 0.45) / (hit - 0.45)) * (1 - smooth((u - 0.85) / 0.15))
    s.pivot = Vector((0, L_HY, LEGS["HL"]["home"].z + 0.12 * H))
    s.pitch = 42 * rise
    s.off.y = -0.30 * H * lunge
    s.off.z = -0.05 * H * rise + -0.02 * H * bump(u, hit - 0.03, hit, hit + 0.02, hit + 0.12)
    s.hips = -6 * rise
    s.neck[0] = -12 * rise + 6 * lunge; s.head = -8 * rise - 10 * lunge; s.jaw = (22 if STAG else 12) * rise
    s.tail[0] = 20 * rise
    for k in ("HL", "HR"):
        s.feet[k] = LEGS[k]["home"].copy()
    paw = math.sin(2 * math.pi * 2.5 * u) * bump(u, 0.25, 0.35, 0.5, 0.58)
    for i, k in enumerate(("FL", "FR")):
        L = LEGS[k]
        air = bump(u, 0.08, 0.25, hit - 0.06, hit)
        # in the air the hoof rides under the chest, folded; it reaches forward and down for the stomp
        p = L["home"].copy() + Vector((0, -0.36 * H * lunge, 0))
        p.z += air * ((0.62 if STAG else 0.5) * H * rise + 0.08 * H * paw * (1 if i == 0 else -1))
        p.y += air * (0.08 * H * rise) - 0.06 * H * air * paw * (1 if i == 0 else -1)
        s.feet[k] = p
        fold = 1.0 if STAG else 0.8  # the doe's narrow brisket tears if her forelegs fold as tight
        s.curl[k] = 90 * air * fold; s.tilt[k] = 95 * air * rise * fold
    return s


def kick(t, T):
    """Rear kick (both sexes): weight rocks onto the forelegs, head down, both hind legs fire straight back and
    up at 0.45 (hooves ~1.3 H behind the rump), then plant."""
    s = St(); u = t / T; hit = 0.45
    load = bump(u, 0.0, 0.25, 0.55, 0.85)
    fire = bump(u, 0.27, hit, hit + 0.08, 0.75)
    s.pivot = Vector((0, L_FY, LEGS["FL"]["home"].z + 0.1 * H))
    s.pitch = -6 * load - 5 * fire  # a little: pitching the croup up lifts the hips out of hoof reach of the target
    s.off.y = -0.05 * H * load
    s.neck[0] = -20 * load; s.head = -10 * load; s.tail[0] = 30 * fire
    s.hips = 8 * fire
    for k in ("FL", "FR"): s.feet[k] = LEGS[k]["home"].copy()
    for k in ("HL", "HR"):
        L = LEGS[k]; tuck = bump(u, 0.12, 0.27, 0.3, 0.38)
        p = L["home"].copy()
        p.z += 0.22 * H * tuck + 0.30 * H * fire
        p.y += -0.08 * H * tuck + 0.80 * H * fire
        s.feet[k] = p
        s.curl[k] = 60 * tuck - 15 * fire; s.tilt[k] = -55 * tuck + 25 * fire
    return s


def hit_react(t, T):
    s = St(); u = t / T
    j = bump(u, 0.0, 0.12, 0.3, 1.0)
    s.off.y = 0.05 * H * j; s.off.z = -0.02 * H * j; s.roll = 4 * j; s.pitch = 3 * j
    s.neck[0] = 10 * j; s.head = 8 * j; s.head_yaw = 12 * j; s.jaw = 10 * j; s.tail[0] = 15 * j
    for k in LEGS: s.feet[k] = LEGS[k]["home"].copy()
    return s


def collapse(t, T, death):
    """Knockdown / death: the forelegs buckle (carpus first), the hindquarters sink, then the body rolls onto its
    right side with the legs out. Ends lying still (the game holds the last frame)."""
    s = St(); u = t / T
    kneel = smooth(u / 0.35); sink = smooth((u - 0.2) / 0.3); roll = smooth((u - 0.4) / 0.4)
    bh = HEAD["Body"].z
    lie_z = 0.30 * H  # body centre height lying on its side (about half the barrel's width)
    s.off.z = -(bh * 0.45) * kneel * (1 - roll) - (bh - lie_z) * roll
    s.pitch = -10 * kneel * (1 - sink) + 6 * sink * (1 - roll)
    s.roll = -86 * roll
    s.neck[0] = -20 * kneel + (-5 if death else 10) * roll; s.head = -10 * kneel - (20 if death else 0) * roll
    s.neck_yaw[0] = 8 * roll; s.jaw = (14 if death else 4) * roll
    if STAG:  # lying on the right side, the head rolls back up so the antlers rest on their edges, not under the floor
        s.head_roll = 70 * roll; s.neck[0] += 18 * roll
    s.tail[0] = -10 * roll
    for k, L in LEGS.items():
        fold = kneel if L["front"] else sink
        p = L["home"].copy()
        # legs fold under, then swing out sideways with the roll (feet follow the body)
        p.z += 0.05 * H * fold * (1 - roll)
        s.tilt[k] = (70 if L["front"] else -45) * fold * (1 - roll)
        s.curl[k] = 60 * fold * (1 - roll) + 20 * roll
        s.feet[k] = p
    s.follow = roll
    return s


def sleep(t, T):
    """Lies down sternal (on its chest, legs folded under) and rests the chin low; not looped, the game holds the
    end. The forelegs kneel first, as deer do, then the hindquarters drop."""
    s = St(); u = t / T
    kneel = smooth(u / 0.35); drop = smooth((u - 0.3) / 0.35); rest = smooth((u - 0.65) / 0.3)
    bh = HEAD["Body"].z
    s.off.z = -bh * 0.30 * kneel * (1 - drop) - bh * 0.56 * drop
    s.pitch = -14 * kneel * (1 - drop)
    s.roll = -6 * drop
    s.neck[0] = -10 * kneel - 8 * rest; s.neck[1] = -4 * rest; s.head = -12 * rest; s.neck_yaw[0] = 10 * rest
    s.tail[0] = -8 * drop
    for k, L in LEGS.items():
        fold = kneel if L["front"] else drop
        s.tilt[k] = (95 if L["front"] else -80) * fold
        s.curl[k] = 80 * fold
    return s


def feed(t, T):
    """Grazing: steps the forelegs a little apart, lowers the head to the grass, crops and chews, lifts to look."""
    s = St(); u = t / T
    down = bump(u, 0.05, 0.25, 0.78, 0.95)
    s.neck[0] = -48 * down; s.neck[1] = -20 * down; s.head = -25 * down
    s.off.z = -0.02 * H * down; s.pitch = -4 * down
    chew = down * (0.5 + 0.5 * math.sin(2 * math.pi * 6 * u))
    s.jaw = 14 * chew * (u > 0.25) * (u < 0.78)
    s.head_yaw = 6 * math.sin(2 * math.pi * 2 * u) * down
    for k in ("FL", "FR"):
        s.feet[k] = LEGS[k]["home"] + Vector((LEGS[k]["sx"] * 0.04 * H * down, -0.04 * H * down, 0))
    s.tail_yaw[1] = 10 * math.sin(2 * math.pi * 3 * u)
    return s


def sideways_walk(t, T, sgn):
    return walk(t, T, Vector((sgn, 0, 0)), True)


CLIPS = {
    "idle": (3.0, idle, True), "walk": (1.25, walk, True), "run": (0.66, gallop, True),
    "strafe_left": (1.25, lambda t, T: sideways_walk(t, T, 1), True),
    "strafe_right": (1.25, lambda t, T: sideways_walk(t, T, -1), True),
    "walk_back": (1.25, lambda t, T: walk(t, T, Y), True),
    "alert": (2.2 if STAG else 1.8, alert, False), "attack_primary": (1.1, attack_primary, False),
    "attack_heavy": (1.8, attack_heavy, False), "kick": (1.0, kick, False), "hit_react": (0.6, hit_react, False),
    "knockdown": (1.6, lambda t, T: collapse(t, T, False), False), "death": (2.2, lambda t, T: collapse(t, T, True), False),
    "sleep": (3.0, sleep, False), "feed": (3.0, feed, False),
}
# MEGAJOUST: the stag's charge is the antler ram, the doe's the low tackle; both get the joust's tell and turns.
CLIPS["charge"] = (0.66, charge if STAG else tackle, True)
CLIPS["charge_crouch"] = (1.0 if STAG else 0.7, charge_crouch, False)
CLIPS["run_turn_left"] = (0.66, lambda t, T: run_turn(t, T, 1), True)
CLIPS["run_turn_right"] = (0.66, lambda t, T: run_turn(t, T, -1), True)

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
