"""Author in-place walk/run loops from a footfall plan, with analytic two-bone leg IK.

Each foot follows a planned path (stance: glued to the ground and sliding back at the gait's ground
speed; swing: lifted and carried forward), so legs alternate by construction instead of by
hand-keyed rotations. The legs are solved with IK, the body is lowered only as far as the legs need
to reach, and the result is keyed per frame and exported skeleton-only with the skin, like the game's
existing clips.

usage: Blender -b -P tools/gait/make_gait.py -- <base.glb> <species.json> <clip> <out.glb>
           [--frames-dir DIR]   also render side-view frames of the posed mesh (for strips)
           [--textured]         render those frames textured with Eevee instead of grey Workbench
           [--set key=value ...] override clip parameters (numbers), for quick experiments
           [--as NAME --travel x,y,z] the same plan carried along another axis, e.g. walk --as strafe_left
                                --travel 1,0,0 (armature space; the body keeps facing "forward")
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
BASE, CFG, CLIP, OUT = argv[:4]
FRAMES_DIR = argv[argv.index("--frames-dir") + 1] if "--frames-dir" in argv else ""
cfg = json.load(open(CFG))
clip = dict(cfg["clips"][CLIP])
# --as NAME --travel x,y,z: reuse a clip's foot plan in another direction (strafe_left/right, walk_back)
NAME = argv[argv.index("--as") + 1] if "--as" in argv else CLIP
if "--travel" in argv:
    cfg["travel"] = [float(x) for x in argv[argv.index("--travel") + 1].split(",")]
if "--set" in argv:
    for kv in argv[argv.index("--set") + 1:]:
        if "=" not in kv or kv.startswith("--"):
            break
        k, v = kv.split("=", 1)
        clip[k] = float(v)

FPS = 24
N = int(round(clip["cycle_s"] * FPS))  # frames per loop; frame N repeats frame 0
DUTY = clip["duty"]
STRIDE = clip["stride"]  # ground distance per cycle, mesh units
STANCE = STRIDE * DUTY  # how far a planted foot travels backwards
REACH = cfg.get("reach", 0.985)  # never straighten a leg past this share of its length

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=BASE)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in bpy.data.objects:
    if o.type == "MESH" and o.parent is None and o.name.startswith("Icosphere"):
        o.hide_render = True  # importer's bone-shape sphere
sc = bpy.context.scene
sc.render.fps = FPS
pbs = arm.pose.bones
bones = arm.data.bones
FWD = Vector(cfg.get("forward", [0, -1, 0]))  # armature-space forward
TRAVEL = Vector(cfg.get("travel", list(FWD)))  # where the feet carry the body; differs from FWD for strafes and backing up
UP = Vector((0, 0, 1))
SIDE = FWD.cross(UP).normalized()


def rest(name):
    return bones[name].matrix_local.copy()


def set_matrix(name, m):
    pbs[name].matrix = m
    bpy.context.view_layer.update()


def head(name):
    return pbs[name].head.copy()


def rot_about(pivot, axis, angle):
    return Matrix.Translation(pivot) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Translation(-pivot)


def smoothstep(x):
    return x * x * (3 - 2 * x)


def wave(t, phase=0.0, harmonic=1):
    return math.sin(2 * math.pi * (harmonic * t + phase))


LEGS = cfg["legs"]
for leg in LEGS.values():
    up, low = leg["up"], leg["low"]
    leg["l1"] = bones[up].length
    leg["l2"] = (bones[low].head_local - bones[leg["foot"]].head_local).length if leg.get("ankle_is_foot_head", True) else bones[low].length
    leg["ankle0"] = bones[leg["foot"]].head_local.copy()
    # pivot on the real toe tip (the *_end bone) when the rig has one: rolling about the foot bone's tail pushed the
    # toe tip below the ground at push-off (deinonychus charge -22 cm, COMPYFEEL 2026-10-31)
    tip = bones.get(leg["foot"] + "_end")
    leg["toe0"] = (tip.tail_local if tip else bones[leg["foot"]].tail_local).copy()
    leg["hip0"] = bones[up].head_local.copy()
    if "pole" not in leg:  # bend the way the rest pose already bends
        h, k, an = leg["hip0"], bones[low].head_local, leg["ankle0"]
        line = an - h
        off = (k - h) - line * ((k - h).dot(line) / line.length_squared)
        leg["pole"] = list(off.normalized())


def leg_phase(leg, t):
    return (t + clip["phases"][leg]) % 1.0


def foot_plan(name, t):
    """Ankle target, hoof pitch (rad, toe-down positive) for one leg at cycle time t."""
    leg = LEGS[name]
    u = leg_phase(name, t)
    centre = clip.get("foot_offset_" + leg["end"], 0.0)  # + moves this end's footprint forward
    a0 = leg["ankle0"] + TRAVEL * centre
    # spread_<end>: plant this end's feet wider (outward from the midline) for a low, braced stance
    side_sign = 1.0 if leg["ankle0"].dot(SIDE) >= 0 else -1.0
    a0 = a0 + SIDE * side_sign * clip.get("spread_" + leg["end"], 0.0)
    lift = clip["lift_" + leg["end"]]
    roll = math.radians(clip.get("toe_roll", 25.0))
    curl = math.radians(clip.get("swing_curl_" + leg["end"], 50.0))
    if u < DUTY:  # stance: slide back at ground speed
        s = u / DUTY
        pos = a0 + TRAVEL * (STANCE * (0.5 - s))
        # heel lifts over the last part of the stance while the toe stays put
        heel = max(0.0, (s - 0.75) / 0.25)
        # reach_roll: roll onto the toes as the planted foot reaches out from under the hip, so the heel pad
        # never sinks into the ground on a long or splayed step (the ankle rises about the toe tip)
        reach = math.radians(clip.get("reach_roll", 0.0)) * abs(2 * s - 1) ** 1.5
        return pos, max(roll * smoothstep(heel), reach), True
    s = (u - DUTY) / (1 - DUTY)  # swing: lift and carry forward
    pos = a0 + TRAVEL * (STANCE * (smoothstep(s) - 0.5))
    pos = pos + UP * (lift * math.sin(math.pi * s) ** clip.get("lift_shape", 0.8))
    pitch = roll + (curl - roll) * math.sin(math.pi * min(1.0, s * 1.6)) if s < 0.625 else curl * (1 - smoothstep((s - 0.625) / 0.375))
    return pos, pitch, False


def toe_pivot(leg, ankle, pitch, planted):
    """Rotate the foot about its toe while the heel peels off (stance) so the toe never slides."""
    toe_vec = leg["toe0"] - leg["ankle0"]
    r = Matrix.Rotation(pitch, 4, -SIDE)  # positive pitch = toe down
    # swing_toe_pivot (RAPTORFLANK): keep pivoting about the toe through the swing too, so the toe carries the planned
    # lift; without it the heel-off pivot snapped away at toe-off and the toe dug 11 cm into the ground (raptor walk).
    if (planted or clip.get("swing_toe_pivot", 0)) and pitch > 0:
        toe = ankle + toe_vec
        ankle = toe - (r.to_3x3() @ toe_vec)
    return ankle, r


def ends_drop(t):
    """Per end, how far the body must lower so every planted foot of that end stays reachable."""
    drop = {}
    for name, leg in LEGS.items():
        ankle, pitch, planted = foot_plan(name, t)
        ankle, _ = toe_pivot(leg, ankle, pitch, planted)
        hip = leg["hip0"] + TRAVEL * clip.get("legroot_" + leg["end"], 0.0) * (ankle - leg["ankle0"]).dot(TRAVEL)
        reach = REACH * (leg["l1"] + leg["l2"])
        flat = ankle - hip
        horiz = (flat - UP * flat.dot(UP)).length
        need_z = math.sqrt(max(0.0, reach * reach - horiz * horiz))
        d = max(0.0, (hip.z - ankle.z) - need_z)
        drop[leg["end"]] = max(drop.get(leg["end"], 0.0), d)
    return drop


# body height per end: dilate then blur the needed drop around the loop so the body moves smoothly
raw = [ends_drop(f / N) for f in range(N)]
ENDS = sorted({leg["end"] for leg in LEGS.values()})
smooth = []
for f in range(N):
    row = {}
    for e in ENDS:
        k = max(1, N // 8)
        win = [max(raw[(f + j) % N][e] for j in range(i - 1, i + 2)) for i in range(-k, k + 1)]
        w = [math.cos(math.pi * i / (2 * k + 2)) for i in range(-k, k + 1)]
        row[e] = sum(a * b for a, b in zip(win, w)) / sum(w) * clip.get("drop_gain", 1.0)
    smooth.append(row)

end_y = {e: sum(LEGS[n]["hip0"].dot(FWD) for n in LEGS if LEGS[n]["end"] == e) / 2 for e in ENDS}
body_pivot = Vector((0, 0, 0))
for leg in LEGS.values():
    body_pivot += leg["hip0"] / len(LEGS)


def solve_leg(name, ankle, pole_dir):
    leg = LEGS[name]
    up, low = leg["up"], leg["low"]
    set_matrix(up, pbs[up].matrix)  # make sure parents are current
    h = head(up)
    l1, l2 = leg["l1"], leg["l2"]
    d_vec = ankle - h
    d = min(d_vec.length, (l1 + l2) * 0.9999)
    u = d_vec.normalized()
    w = pole_dir - u * pole_dir.dot(u)
    w.normalize()
    cos_a = max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)))
    a = math.acos(cos_a)
    knee = h + (u * math.cos(a) + w * math.sin(a)) * l1
    for bone, a_pt, b_pt in ((up, h, knee), (low, knee, ankle)):
        m = pbs[bone].matrix.copy()
        cur_y = m.to_3x3().col[1].normalized()
        q = cur_y.rotation_difference((b_pt - a_pt).normalized())
        nm = (q.to_matrix() @ m.to_3x3()).to_4x4()
        nm.translation = a_pt
        set_matrix(bone, nm)


def pose(t, f):
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    # body: lowered per end as the legs need, plus the gait's own bob and rocking
    dz = {e: -smooth[f][e] - clip.get("crouch", 0.0) + clip.get("bob", 0.0) * wave(t, clip.get("bob_phase", 0.0), int(clip.get("bob_harmonic", 2))) for e in ENDS}
    for e in ENDS:
        dz[e] += clip.get("rock_" + e, 0.0) * wave(t, clip.get("rock_phase_" + e, 0.0), 1)
    if len(ENDS) == 2:
        span = end_y["front"] - end_y["hind"]
        pitch = math.atan2(dz["front"] - dz["hind"], span) * clip.get("pitch_gain", 1.0)  # nose up positive
        mid = (dz["front"] + dz["hind"]) / 2
    else:
        pitch, mid = math.radians(clip.get("lean_deg", 0.0)), dz[ENDS[0]]  # bipeds: lean_deg > 0 tips the body nose-down (a dash)
    roll = math.radians(clip.get("roll_deg", 0.0)) * wave(t, clip.get("roll_phase", 0.0), 1)
    sway = clip.get("sway", 0.0) * wave(t, clip.get("roll_phase", 0.0), 1)
    body = cfg["body"]
    m = Matrix.Translation(UP * mid + SIDE * sway) @ rot_about(body_pivot, SIDE, -pitch) @ rot_about(body_pivot, FWD, roll) @ rest(body)
    set_matrix(body, m)
    # spine / head / tail counter-motion, as small local rotations
    for bname, spec in cfg.get("wiggle", {}).items():
        if bname not in pbs:
            continue
        amp = clip.get("wiggle_" + spec["key"], 0.0)
        if not amp:
            continue
        ang = math.radians(amp) * wave(t, spec.get("phase", 0.0) + clip.get("wiggle_phase_" + spec["key"], 0.0), int(spec.get("harmonic", clip.get("wiggle_harmonic_" + spec["key"], 1))))
        axis = {"pitch": SIDE, "yaw": UP, "roll": FWD}[spec["axis"]]
        cur = pbs[bname].matrix.copy()
        set_matrix(bname, rot_about(cur.translation, axis, ang) @ cur)
    # held offsets for the whole clip, e.g. a charge's head up and arms swept back: "hold": {"Neck": ["pitch", 12]}
    for bname, (ax, deg) in clip.get("hold", {}).items():
        if bname in pbs:
            cur = pbs[bname].matrix.copy()
            set_matrix(bname, rot_about(cur.translation, {"pitch": SIDE, "yaw": UP, "roll": FWD}[ax], math.radians(deg)) @ cur)
    # legs
    for name, leg in LEGS.items():
        ankle, pitch_f, planted = foot_plan(name, t)
        ankle, r = toe_pivot(leg, ankle, pitch_f, planted)
        root = leg.get("root")
        carry = clip.get("legroot_" + leg["end"], 0.0)
        if root and carry:
            cur = pbs[root].matrix.copy()
            set_matrix(root, Matrix.Translation(TRAVEL * carry * (ankle - leg["ankle0"]).dot(TRAVEL)) @ cur)
        pole = Vector(leg["pole"])
        solve_leg(name, ankle, pole)
        fm = r @ rest(leg["foot"])
        fm.translation = ankle
        set_matrix(leg["foot"], fm)


def key(f):
    for pb in pbs:
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert("location", frame=f)
        pb.keyframe_insert("rotation_quaternion", frame=f)
        pb.keyframe_insert("scale", frame=f)


arm.animation_data_create()
act = bpy.data.actions.new(NAME)
arm.animation_data.action = act
for f in range(N + 1):
    t = (f % N) / N
    pose(t, f % N)
    key(f)
sc.frame_start, sc.frame_end = 0, N

report = {"clip": NAME, "frames": N, "cycle_s": N / FPS, "duty": DUTY, "stride": STRIDE,
          "ground_speed": STRIDE / (N / FPS), "max_drop": {e: round(max(r[e] for r in smooth), 3) for e in ENDS}}
print("GAIT", json.dumps(report))

if FRAMES_DIR:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import render_frames
    render_frames.render(sc, cfg, FRAMES_DIR, N, "--textured" in argv, ground_speed=STRIDE / (N / FPS))

# export skeleton-only with the skin, same options as the game's existing clips
for o in list(bpy.data.objects):
    if o is not arm:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
act.name = NAME
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", export_apply=False, export_yup=True,
    use_selection=True, export_animations=True, export_animation_mode="ACTIONS",
    export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False,
    export_anim_slide_to_zero=False, export_skins=True, export_morph=False,
    export_def_bones=False, export_reset_pose_bones=False, export_current_frame=False,
    export_nla_strips=False, export_anim_single_armature=True, export_bake_animation=True,
    export_materials="NONE", export_image_format="NONE")
print("WROTE", OUT)
