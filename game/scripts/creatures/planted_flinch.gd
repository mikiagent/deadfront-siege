class_name PlantedFlinch
extends SkeletonModifier3D
## PLANTEDFLINCH (owner 2026-10-31): a hit rattles the body while the feet stay planted.
## Runs after the AnimationTree on the creature's skeleton:
##  - shake(): the procedural hurt. A damped pitch + yaw rattle on the head chain (the head and its ancestors that no
##    foot hangs from: neck, and the torso of a biped) and a sway on the tail; the legs and the root never move.
##    It replaces the old tween that pitched and shoved the whole rig node (feet 7-61 cm into the floor).
##  - pin(): for an authored hit_react clip. The feet's drift from where they stood when the hit landed (skeleton
##    space) is taken off the root bone each frame: the mean horizontal drift and the lowest foot's height. The clip's
##    torso, neck and head motion stays; the body no longer slides or sinks over the feet.
## Feet = the bones within FOOT_BAND of the body's height of the lowest bone in the pose at the hit, less the root (it
## sits on the floor and is what the correction moves), anything on the head (a low-slung jaw) and the "_end" tips
## (no skin weights: they only mark where a bone ends).

const FOOT_BAND := 0.06  # ASSUMPTION: a foot sits within 6 % of body height of the lowest limb bone
const SHAKE_S := 0.45
const FADE_S := 0.15

var view: Node3D  ## the creature's view: its basis gives the body's side and up axes
var height_m := 1.0
var _feet: Array[int] = []
var _feet0: Array[Vector3] = []
var _chain: Array[int] = []
var _tail: Array[int] = []
var _shake_t := -1.0
var _strength := 1.0
var _pin_left := 0.0
var _still_on: Callable
var _fade := 0.0

func _ready() -> void:
	active = false

## The procedural rattle, `strength` 1 = a normal hit (1.4 = crit).
func shake(strength: float = 1.0) -> void:
	_snapshot()
	_shake_t = 0.0
	_strength = strength
	active = true

## Hold the feet where they stand for `seconds` while `still_on` returns true (the hit_react clip is playing).
func pin(seconds: float, still_on: Callable) -> void:
	_snapshot()
	_pin_left = seconds
	_still_on = still_on
	_fade = 1.0
	active = true

func _snapshot() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var n := sk.get_bone_count()
	var head := CreatureView.head_bone(sk)
	var lo := INF
	var limb: Array[int] = []  # not the root, not on the head, not a skinless "_end" tip (Blender's leaf bones)
	for i in n:
		if sk.get_bone_parent(i) >= 0 and not _under(sk, i, head) and not sk.get_bone_name(i).ends_with("_end"):
			limb.append(i)
			lo = minf(lo, (sk.global_transform * sk.get_bone_global_pose(i).origin).y)
	_feet.clear()
	_feet0.clear()
	for i in limb:
		if (sk.global_transform * sk.get_bone_global_pose(i).origin).y <= lo + FOOT_BAND * height_m:
			_feet.append(i)
			_feet0.append(sk.get_bone_global_pose(i).origin)
	if not _chain.is_empty() or not _tail.is_empty():
		return
	var holds_feet: Dictionary = {}
	for f in _feet:
		var x := sk.get_bone_parent(f)
		while x >= 0:
			holds_feet[x] = true
			x = sk.get_bone_parent(x)
	var h := head
	while h >= 0 and not holds_feet.has(h):
		_chain.push_front(h)  # root-most first
		h = sk.get_bone_parent(h)
	for i in n:
		var nm := sk.get_bone_name(i).to_lower()
		if nm.begins_with("tail") and not nm.ends_with("_end") and not holds_feet.has(i):
			_tail.append(i)

## A low-slung head or jaw (the ankylosaurus) is not a foot.
func _under(sk: Skeleton3D, bone: int, head: int) -> bool:
	while bone >= 0:
		if bone == head:
			return true
		bone = sk.get_bone_parent(bone)
	return false

func _process_modification_with_delta(dt: float) -> void:  # 4.7 calls this one, not _process_modification
	var sk := get_skeleton()
	if sk == null:
		return
	var busy := false
	if _pin_left > 0.0 or _fade > 0.0:
		busy = true
		_pin_left -= dt
		if _pin_left <= 0.0 or not (_still_on.is_valid() and _still_on.call()):
			_pin_left = 0.0
			_fade = maxf(0.0, _fade - dt / FADE_S)  # ease the correction out instead of popping
		_pin_feet(sk, _fade)
	if _shake_t >= 0.0:
		busy = true
		_shake_t += dt
		_rattle(sk)
		if _shake_t >= SHAKE_S:
			_shake_t = -1.0
	if not busy:
		active = false

func _pin_feet(sk: Skeleton3D, w: float) -> void:
	if _feet.is_empty():
		return
	var mean := Vector3.ZERO
	var low := INF
	for k in _feet.size():
		var d: Vector3 = sk.get_bone_global_pose(_feet[k]).origin - _feet0[k]
		mean += d
		low = minf(low, d.y)
	mean /= float(_feet.size())
	var up := _axis(sk, Vector3.UP)
	# Horizontal = the mean drift with its up part removed; vertical = the lowest foot back to where it stood.
	var off := (mean - up * mean.dot(up) + up * low) * w
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) < 0:
			sk.set_bone_pose_position(i, sk.get_bone_pose_position(i) - off)

## A view-space axis in skeleton space (the skeleton is scaled and turned to the model's forward axis).
func _axis(sk: Skeleton3D, v: Vector3) -> Vector3:
	var b := view.global_basis if view else Basis.IDENTITY
	return (sk.global_basis.inverse() * (b * v)).normalized()

func _rattle(sk: Skeleton3D) -> void:
	var t := _shake_t
	# ASSUMPTION: a recoil that peaks at 0.06 s and rings out by SHAKE_S at ~6 Hz; 0.5 rad pitch / 0.3 rad yaw over the head chain.
	var env := (1.0 - exp(-t / 0.025)) * exp(-t / 0.12) * _strength
	var pitch := 0.5 * env * cos(t * TAU * 6.0)
	var yaw := 0.3 * env * sin(t * TAU * 5.0)
	_turn(sk, _chain, _axis(sk, Vector3.RIGHT), pitch)
	_turn(sk, _chain, _axis(sk, Vector3.UP), yaw)
	_turn(sk, _tail, _axis(sk, Vector3.UP), -yaw * 1.5)

## Rotate each bone of `bones` by angle / count about a skeleton-space axis (each bone's share in its own frame).
func _turn(sk: Skeleton3D, bones: Array[int], axis_sk: Vector3, angle: float) -> void:
	if bones.is_empty() or absf(angle) < 0.0001:
		return
	var share := angle / float(bones.size())
	for b in bones:
		var local := (sk.get_bone_global_pose(b).basis.orthonormalized().inverse() * axis_sk).normalized()
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion(local, share))
