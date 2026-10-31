class_name DisplayFlare
extends SkeletonModifier3D
## DILOFRILL (owner 2026-10-31: "keep its frills out more often in combat"): a display structure (the dilophosaurus
## neck frill) held open from combat state, over whatever clip plays. Runs after the AnimationPlayer on the
## creature's skeleton and slerps each display bone from the clip's pose toward its open pose by one weight:
##  - calm, roaming, fleeing, asleep, downed or dead: the weight eases to 0 and the clips own the bones (folded in the
##    gaits, their own flicks in hit_react and death);
##  - any other brain state (alert, approach, circle, spit, every attack...): it opens to HOLD;
##  - while an attack clip plays (spit, bites, slash, leap): it snaps to fully open, the tell.
## The weight moves at a capped rate and is applied through smoothstep, so it never pops.
## Species opt in with pipeline.display_flare {bone_prefix, open_clip, open_at}: the open pose is the clip's rotation
## of each bone whose name starts with bone_prefix, sampled at open_at (a share of the clip).

const CALM: Array[StringName] = [&"roam", &"flee", &"sleep", &"disengage", &"lurk", &"downed", &"dead"]
const SNAP_CLIPS: Array[StringName] = [&"spit", &"attack_primary", &"attack_heavy", &"pounce", &"bite_combo"]
const HOLD := 0.8  # ASSUMPTION: held ~80 % open while engaged, so the snap to full before a strike still reads
const OPEN_S := 0.35  # ASSUMPTION: seconds from folded to held open on engaging
const SNAP_S := 0.12  # ASSUMPTION: seconds for the snap open before a strike
const FOLD_S := 0.6  # ASSUMPTION: seconds to fold back when it calms down

var creature: Creature
var weight := 0.0  ## 0 = the clip's pose, 1 = fully open
var _bones: Array[int] = []
var _open: Array[Quaternion] = []

## Reads the open pose from the rig's clip; false when the clip or the bones are missing (nothing to drive).
func setup(spec: Dictionary, ap: AnimationPlayer) -> bool:
	var sk := get_skeleton()
	var clip := StringName(str(spec.get("open_clip", "alert")))
	if sk == null or ap == null or not ap.has_animation(clip):
		return false
	var a := ap.get_animation(clip)
	var t := a.length * float(spec.get("open_at", 0.5))
	var prefix := str(spec.get("bone_prefix", "Frill"))
	for tr in a.get_track_count():
		if a.track_get_type(tr) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := sk.find_bone(str(a.track_get_path(tr)).get_slice(":", 1))
		if bone >= 0 and sk.get_bone_name(bone).begins_with(prefix):
			_bones.append(bone)
			_open.append(a.rotation_track_interpolate(tr, t))
	return not _bones.is_empty()

## The weight this frame aims for and how fast it may move there (per second).
func target() -> Vector2:
	if creature == null or creature.health.dead or creature.brain == null or creature.brain.state in CALM:
		return Vector2(0.0, 1.0 / FOLD_S)
	if creature.anim and creature.anim.current_clip in SNAP_CLIPS:
		return Vector2(1.0, 1.0 / SNAP_S)
	return Vector2(HOLD, 1.0 / OPEN_S)

func _process_modification_with_delta(dt: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var aim := target()
	weight = move_toward(weight, aim.x, aim.y * dt)
	var w := smoothstep(0.0, 1.0, weight)
	if w <= 0.0:
		return
	for k in _bones.size():
		var b := _bones[k]
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(_open[k], w))
