class_name HeadLook
extends SkeletonModifier3D
## HEADLOOK (owner 2026-10-31: "add head movement that tracks the player to every model by default"): after the clip is
## applied, the neck chain and head turn toward the animal's current target (the prey it is aware of or fighting:
## brain.attack_target). Every rigged species with a head bone gets it; pipeline.head_look in the species JSON tunes or
## disables it: {"enabled": false} opts out, "yaw_deg" / "pitch_deg" clamp the turn, "off_clips" adds clips to fade out on.
##  - The turn is split over the chain: the neck bones share NECK_SHARE of it, the head takes the rest, so no joint pivots alone.
##  - Yaw and pitch are measured from the head to the target in the body's frame and clamped per species. A target past
##    OUT_MULT x the clamp (beside or behind the animal) fades the look out instead of pinning the head at its limit.
##  - Clips that drive the head themselves (bites, roars, charges, hit_react, death, sleep...) fade it to 0 within
##    FADE_OFF_S, so an attack's head and jaw land where they were authored (hit sweeps read these bones).
##  - Angles move at a capped rate and the weight through smoothstep, so it never pops.

const NECK_SHARE := 0.5  # ASSUMPTION: the neck bones turn half of the look between them, the head the other half
const YAW_DEG := 60.0  # ASSUMPTION: default yaw clamp each side; stiff skulls and long necks set less in their JSON
const PITCH_DEG := 30.0  # ASSUMPTION: default pitch clamp up and down
const OUT_MULT := 1.5  # ASSUMPTION: past 1.5x the clamp (90 deg at the default: beside / behind) the look fades out
const TURN_DEG_S := 200.0  # ASSUMPTION: the fastest the look swings across (deg/s)
const FADE_IN_S := 0.4  # ASSUMPTION
const FADE_OUT_S := 0.3  # ASSUMPTION: target lost, out of range or behind
const FADE_OFF_S := 0.15  # ASSUMPTION: an off clip started; attack hits sit at >= ~0.25 s into their clips
const MAX_DT := 1.0 / 30.0  # a hitch frame must not swing the head in one step
## Clips that own the head: every one-shot (attacks, leaps, dodges, hit_react, roar...) but alert, plus the non-one-shots below.
const EXTRA_OFF: Array[StringName] = [&"death", &"knockdown", &"sleep", &"feed", &"charge", &"pin_foot", &"grab", &"bite_shake", &"sniff"]
const KEEP_ON: Array[StringName] = [&"alert"]
const CALM: Array[StringName] = [&"sleep", &"downed", &"dead"]

var creature: Creature
var view: Node3D
var weight := 0.0  ## 0 = the clip's pose, 1 = the full look
var yaw_max := deg_to_rad(YAW_DEG)
var pitch_max := deg_to_rad(PITCH_DEG)
var _yaw := 0.0  ## smoothed, clamped; + = to the animal's left
var _pitch := 0.0  ## + = up
var _head := -1
var _necks: Array[int] = []  ## root-most first
var _off: Dictionary = {}

static func default_off_clips() -> Array[StringName]:
	var out: Array[StringName] = []
	for c in CreatureAnim.ONESHOT + CreatureAnim.ATTACKS + CreatureAnim.LEAPS + EXTRA_OFF:
		if c not in KEEP_ON and c not in out:
			out.append(c)
	return out

## False when the species opts out or has no head bone (skipped quietly).
func setup(spec: Dictionary) -> bool:
	var sk := get_skeleton()
	if sk == null or not bool(spec.get("enabled", true)):
		return false
	_head = CreatureView.head_bone(sk)
	if _head < 0:
		return false
	var b := sk.get_bone_parent(_head)
	while b >= 0 and sk.get_bone_name(b).to_lower().begins_with("neck"):
		_necks.push_front(b)
		b = sk.get_bone_parent(b)
	yaw_max = deg_to_rad(float(spec.get("yaw_deg", YAW_DEG)))
	pitch_max = deg_to_rad(float(spec.get("pitch_deg", PITCH_DEG)))
	for c in default_off_clips() + Array(spec.get("off_clips", [])):
		_off[StringName(str(c))] = true
	return true

## The point the animal looks at, or null.
func aim_point() -> Variant:
	if creature == null or creature.health.dead or creature.brain == null or creature.brain.state in CALM:
		return null
	if not creature.brain._valid_target():
		return null
	var t := creature.brain.attack_target
	var up := 1.4  # ASSUMPTION: a survivor's face; another animal's head height; a structure's middle
	if t is Creature:
		up = (t as Creature).def.height_meters * 0.7 * (t as Creature).scale.y
	elif not (t is Player):
		up = 0.5
	return t.global_position + Vector3.UP * up

func off_clip() -> bool:
	return creature != null and creature.anim != null and _off.has(creature.anim.current_clip)

func _process_modification_with_delta(dt: float) -> void:
	var sk := get_skeleton()
	if sk == null or view == null:
		return
	dt = minf(dt, MAX_DT)
	var want_yaw := 0.0
	var want_pitch := 0.0
	var aim := 0.0
	var rate := 1.0 / FADE_OUT_S
	var p: Variant = aim_point()
	if p != null:
		var vb := view.global_basis.orthonormalized()
		var head_w := sk.global_transform * sk.get_bone_global_pose(_head).origin
		var l: Vector3 = vb.inverse() * ((p as Vector3) - head_w)
		var y := atan2(-l.x, -l.z)
		var pt := atan2(l.y, Vector2(l.x, l.z).length())
		if absf(y) <= yaw_max * OUT_MULT and absf(pt) <= pitch_max * OUT_MULT:
			want_yaw = clampf(y, -yaw_max, yaw_max)
			want_pitch = clampf(pt, -pitch_max, pitch_max)
			aim = 1.0
			rate = 1.0 / FADE_IN_S
	if off_clip():
		aim = 0.0
		rate = 1.0 / FADE_OFF_S
	weight = move_toward(weight, aim, rate * dt)
	if aim > 0.0:  # fading out holds the last angles
		var step := deg_to_rad(TURN_DEG_S) * dt
		_yaw = move_toward(_yaw, want_yaw, step)
		_pitch = move_toward(_pitch, want_pitch, step)
	var w := smoothstep(0.0, 1.0, weight)
	if w <= 0.0:
		_yaw = 0.0
		_pitch = 0.0
		return
	var up := _axis(sk, Vector3.UP)
	var right := _axis(sk, Vector3.RIGHT.rotated(Vector3.UP, _yaw * w))
	var neck_share := NECK_SHARE / float(_necks.size()) if not _necks.is_empty() else 0.0
	for b in _necks:
		_turn(sk, b, up, right, neck_share * w)
	_turn(sk, _head, up, right, (1.0 - neck_share * _necks.size()) * w)

## The look's yaw and pitch as applied this frame (radians, + = left / up).
func applied() -> Vector2:
	var w := smoothstep(0.0, 1.0, weight)
	return Vector2(_yaw * w, _pitch * w)

## A view-space axis in skeleton space (PlantedFlinch._axis).
func _axis(sk: Skeleton3D, v: Vector3) -> Vector3:
	return (sk.global_basis.inverse() * (view.global_basis * v)).normalized()

## Turn one bone by `share` of the look, about skeleton-space axes expressed in its own frame.
func _turn(sk: Skeleton3D, b: int, up: Vector3, right: Vector3, share: float) -> void:
	var inv := sk.get_bone_global_pose(b).basis.orthonormalized().inverse()
	var q := Quaternion((inv * right).normalized(), _pitch * share) * Quaternion((inv * up).normalized(), _yaw * share)
	sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * q)
