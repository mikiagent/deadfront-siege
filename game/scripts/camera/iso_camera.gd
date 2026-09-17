class_name IsoCamera
extends Camera3D
## Fixed-angle orthographic camera that follows a target. Classic 2:1-ish
## isometric look: pitch -35.264, yaw 45. Zoom with the mouse wheel.

@export var target_path: NodePath
@export var distance: float = 40.0
@export var follow_lerp: float = 8.0
@export var min_size: float = 12.0
@export var max_size: float = 40.0
@export var default_size: float = 24.0

var _target: Node3D

func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	if size <= 1.0:
		size = default_size  # Camera3D.size defaults to 1 m, which is a face-full of capsule
	rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	_target = get_node_or_null(target_path) as Node3D
	if _target:
		global_position = _target.global_position - global_basis.z * -distance
		_snap()

func _process(delta: float) -> void:
	if not _target:
		return
	var desired := _target.global_position + (-global_basis.z) * -distance
	global_position = global_position.lerp(desired, clampf(follow_lerp * delta, 0.0, 1.0))

func _snap() -> void:
	global_position = _target.global_position + (-global_basis.z) * -distance

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = clampf(size - 2.0, min_size, max_size)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = clampf(size + 2.0, min_size, max_size)
