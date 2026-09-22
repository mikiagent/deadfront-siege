class_name TouchJoystick
extends Control
## Floating joystick. Press inside the bottom-left region and DRAG: the stick
## starts fixed and visible in the lower-left so movement is immediately discoverable.
## Drag anywhere inside its generous touch zone to drive it. Named TouchJoystick because Godot 4.7 ships its own
## VirtualJoystick node (which is a fine alternative if this one grows warts). Feeds the move_* actions
## through Input.action_press so gameplay code reads Input.get_vector as usual
## and never knows whether a keyboard or a thumb is driving.

## Region of the screen (fractions of the viewport) that owns the stick.
## Default: bottom-left, below the HUD text. Invisible unless show_zone_hint.
@export var zone: Rect2 = Rect2(0.0, 0.35, 0.45, 0.65)
@export var show_zone_hint: bool = true
@export var drag_threshold: float = 14.0  ## px of movement before the stick appears
@export var radius: float = 90.0
@export var knob_radius: float = 38.0
@export var dead_zone: float = 0.12
@export var base_color: Color = Color(0.30, 0.95, 0.72, 0.28)
@export var knob_color: Color = Color(0.78, 1.0, 0.90, 0.72)

var active: bool = false
var vector: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _home: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _sprint_latched: bool = false

const _ACTIONS := {"move_right": Vector2.RIGHT, "move_left": Vector2.LEFT, "move_down": Vector2.DOWN, "move_up": Vector2.UP}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_update_home()
	get_viewport().size_changed.connect(_update_home)
	queue_redraw()

func _update_home() -> void:
	var vs := get_viewport_rect().size
	_home = Vector2(118.0, vs.y - 112.0)
	if not active:
		_origin = _home
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1 and _in_zone(t.position):
			# Remember where the finger landed but show nothing yet: a tap
			# without a drag is gameplay's (tap-to-gather, tap-to-attack).
			_touch_index = t.index
			_origin = _home
			_dragging = false
			vector = Vector2.ZERO
		elif not t.pressed and t.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			if not _dragging:
				if d.position.distance_to(_origin) < drag_threshold:
					return
				_dragging = true
				active = true
			var delta := (d.position - _origin).limit_length(radius) / radius
			vector = Vector2.ZERO if delta.length() < dead_zone else delta
			_feed()
			queue_redraw()
			get_viewport().set_input_as_handled()

func _zone_px() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(zone.position * vs, zone.size * vs)

func _in_zone(p: Vector2) -> bool:
	return _zone_px().has_point(p)

func _feed() -> void:
	for action: String in _ACTIONS:
		var strength: float = maxf(0.0, vector.dot(_ACTIONS[action]))
		if strength > 0.0:
			Input.action_press(action, strength)
		else:
			Input.action_release(action)
	# Pushing the stick to its rim sprints. Cheap, discoverable, no extra button.
	var want_sprint := vector.length() > 0.92
	if want_sprint != _sprint_latched:
		_sprint_latched = want_sprint
		if want_sprint:
			Input.action_press("sprint")
		else:
			Input.action_release("sprint")

func _release() -> void:
	_touch_index = -1
	_dragging = false
	active = false
	vector = Vector2.ZERO
	for action: String in _ACTIONS:
		Input.action_release(action)
	if _sprint_latched:
		_sprint_latched = false
		Input.action_release("sprint")
	queue_redraw()

func _draw() -> void:
	if show_zone_hint and not active:
		draw_circle(_home, radius, base_color)
		draw_arc(_home, radius, 0.0, TAU, 48, Color(0.62, 1.0, 0.82, 0.72), 3.0, true)
		draw_circle(_home, knob_radius, knob_color)
	if not active:
		return
	draw_circle(_origin, radius, base_color)
	draw_arc(_origin, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
	draw_circle(_origin + vector * radius, knob_radius, knob_color)
