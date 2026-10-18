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
var _pre_boss_size := 0.0  # size to return to once a big-boss hunt ends; 0 = not zoomed

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
	if not _target:
		return
	# Interpolated origin: the survivor moves on physics ticks, the camera every frame. Without
	# this the survivor stepped 60 Hz under a 120 Hz camera and read as a doubled, smeared image.
	var desired := _target.get_global_transform_interpolated().origin + (-global_basis.z) * -distance
	global_position = global_position.lerp(desired, clampf(follow_lerp * delta, 0.0, 1.0))
	_boss_zoom(delta)

## An 8 m tyrant overflows the default frame: widen while hunting anything over ~4 m tall.
func _boss_zoom(delta: float) -> void:
	var hunt: Hunt = (_target as Player).hunt if _target is Player else null
	var boss: Creature = hunt.target if hunt and is_instance_valid(hunt.target) and not hunt.target.health.dead else null
	if boss and boss.def.height_meters > 4.0:
		if _pre_boss_size == 0.0:
			_pre_boss_size = size
		size = move_toward(size, clampf(boss.def.height_meters * 3.0, _pre_boss_size, max_size), 12.0 * delta)
	elif _pre_boss_size > 0.0:
		size = move_toward(size, _pre_boss_size, 12.0 * delta)
		if is_equal_approx(size, _pre_boss_size):
			_pre_boss_size = 0.0

func _snap() -> void:
	global_position = _target.global_position + (-global_basis.z) * -distance

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = clampf(size - 2.0, min_size, max_size)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = clampf(size + 2.0, min_size, max_size)
