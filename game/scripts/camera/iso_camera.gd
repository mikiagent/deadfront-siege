class_name IsoCamera
extends Camera3D
## Fixed-angle orthographic camera that follows a target. Classic 2:1-ish
## isometric look: pitch -35.264, yaw 45. Zoom with the mouse wheel.

@export var target_path: NodePath
@export var distance: float = 40.0
@export var follow_lerp: float = 8.0
@export var min_size: float = 10.0
@export var max_size: float = 28.0
@export var default_size: float = 15.0

var _target: Node3D
## 0..1 impact shake; decays linearly, offset grows with trauma^2 so small knocks stay subtle.
var trauma: float = 0.0
var _shake_t: float = 0.0

## Shake the camera that follows `subject` (no-op on a headless server or for other bodies).
static func shake(subject: Node, amount: float) -> void:
	if subject == null or not subject.is_inside_tree():
		return
	var cam := subject.get_viewport().get_camera_3d() as IsoCamera
	if cam and cam._target == subject:
		cam.add_trauma(amount)

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	if size <= 1.0:
		size = default_size  # Camera3D.size defaults to 1 m, which is a face-full of capsule
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cam-size="):  # screenshot runs: start zoomed out
			size = clampf(float(a.substr(11)), min_size, max_size)
	rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	_target = get_node_or_null(target_path) as Node3D
	if _target:
		global_position = _target.global_position - global_basis.z * -distance
		_snap()

func _process(delta: float) -> void:
	_update_shake(delta)
	if not _target:
		return
	# Interpolated origin: the survivor moves on physics ticks, the camera every frame. Without
	# this the survivor stepped 60 Hz under a 120 Hz camera and read as a doubled, smeared image.
	var desired := _target.get_global_transform_interpolated().origin + (-global_basis.z) * -distance
	global_position = global_position.lerp(desired, clampf(follow_lerp * delta, 0.0, 1.0))

## Screen-space offsets, so the shake never fights the follow lerp.
func _update_shake(delta: float) -> void:
	if trauma <= 0.0:
		h_offset = 0.0
		v_offset = 0.0
		return
	trauma = maxf(0.0, trauma - CombatTuning.num("camera", "trauma_decay_per_s", 1.4) * delta)
	_shake_t += delta
	var amp := trauma * trauma * CombatTuning.num("camera", "max_offset_m", 0.45)
	h_offset = amp * sin(_shake_t * 57.0)
	v_offset = amp * sin(_shake_t * 43.0 + 1.3)

func _snap() -> void:
	global_position = _target.global_position + (-global_basis.z) * -distance

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = clampf(size - 2.0, min_size, max_size)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = clampf(size + 2.0, min_size, max_size)
