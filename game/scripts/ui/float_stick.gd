class_name FloatStick
extends TouchJoystick
## Durango-style floating move stick for touch. A press on the left half of the screen that is not on a HUD
## control and drags past DEAD_ZONE_PX spawns the stick centred where the finger landed (kept inside the
## safe area); the knob clamps to the base, a push to the rim sprints (TouchJoystick._feed), release hides it.
## A press there that never drags is handed back as a plain tap on release, so tap-to-walk, select and
## interact still work; the right half keeps its role. touch_controls.gd puts this full-rect, pass-through
## control on a canvas layer under the HUD, so HUD controls take their touches first, and mouse events always
## pass on to the game (desktop click-to-move).

const DEAD_ZONE_PX := 12.0
# ASSUMPTION: 200 ms; the PRDs give no pinch window.
const PINCH_MS := 200  ## two fingers landing this close together are a pinch, not a stick
const REPLAY_DEVICE := 7701  ## marks the tap this stick hands back, so it lets that one through
const RUN_KNOB := Color(0.20, 0.78, 0.74, 0.85)  ## UiTokens.TEAL: the knob shows the sprint deflection

var _press := Vector2.ZERO  ## where the finger landed: deflection is measured from here, the base drawn at _origin
var _down: Dictionary = {}  ## touch index -> msec it landed, for every finger on the screen

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zone = Rect2(0.0, 0.0, 0.5, 1.0)
	show_zone_hint = false
	base_color = Color(1, 1, 1, 0.16)
	knob_color = Color(1, 1, 1, 0.62)
	_fit()
	get_viewport().size_changed.connect(_fit)

## Phone-sized on a compact canvas.
# ASSUMPTION: 58 / 72 px radius (116 / 144 px base), sized against the 64 px HUD hexes; no reference size.
func _fit() -> void:
	radius = 58.0 if UiTokens.is_compact(get_viewport_rect().size) else 72.0
	knob_radius = radius * 0.42

## Only the left half is the stick's: the GUI never routes a right-half press here.
func _has_point(point: Vector2) -> bool:
	return _in_zone(point)

## The base while the stick is up (TouchControls.blocks_screen_point keeps another finger's tap off it).
func blocks(point: Vector2) -> bool:
	return active and point.distance_to(_origin) <= radius

## Every finger, before the GUI routes it. A second finger landing right after the stick's press is a pinch:
## the stick lets go of its press (no tap, no stick).
func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventScreenTouch) or event.device == REPLAY_DEVICE:
		return
	var t := event as InputEventScreenTouch
	if not t.pressed:
		_down.erase(t.index)
		return
	_down[t.index] = Time.get_ticks_msec()
	if _touch_index != -1 and not _dragging and t.index != _touch_index and _landed_together(_touch_index):
		_touch_index = -1

func _gui_input(event: InputEvent) -> void:
	if event.device == REPLAY_DEVICE:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _touch_index != -1 or _landed_together(t.index) or _world_busy():
				return
			_touch_index = t.index
			_press = t.position
			_origin = t.position
			_dragging = false
			vector = Vector2.ZERO
			accept_event()
		elif t.index == _touch_index:
			accept_event()
			if _dragging:
				_release()
			else:
				_touch_index = -1
				_replay_tap(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != _touch_index:
			return
		accept_event()
		if not _dragging:
			if d.position.distance_to(_press) < DEAD_ZONE_PX:
				return
			_dragging = true
			active = true
			_origin = _in_safe_area(_press)
		var delta := (d.position - _press).limit_length(radius) / radius
		vector = Vector2.ZERO if delta.length() < dead_zone else delta
		_feed()
		queue_redraw()

## Another finger landed within PINCH_MS of this one.
func _landed_together(index: int) -> bool:
	var at: int = _down.get(index, Time.get_ticks_msec())
	for other: int in _down:
		if other != index and absi(int(_down[other]) - at) < PINCH_MS:
			return true
	return false

## Placing or arranging buildings drags on the world: the stick stays out of the way.
func _world_busy() -> bool:
	var p := PlayerRegistry.local()
	return p != null and p.placer != null and (p.placer.placing != &"" or p.placer.layout_mode)

## The base sits fully inside the safe area even when the finger lands at the edge.
func _in_safe_area(at: Vector2) -> Vector2:
	var view := get_viewport_rect().size
	var inset := UiTokens.safe_insets(get_viewport())  # x right, y bottom, z top, w left
	var lo := Vector2(inset.w, inset.z) + Vector2(radius, radius)
	var hi := view - Vector2(inset.x, inset.y) - Vector2(radius, radius)
	return at.clamp(lo, hi.max(lo))

## The press never dragged: hand it back as the tap it was (press + release where it landed). Input takes
## window coordinates; the GUI gave canvas ones.
func _replay_tap(index: int) -> void:
	var at := get_viewport().get_final_transform() * _press
	for down: bool in [true, false]:
		var t := InputEventScreenTouch.new()
		t.device = REPLAY_DEVICE
		t.index = index
		t.position = at
		t.pressed = down
		Input.parse_input_event(t)

func _draw() -> void:
	if not active:
		return
	draw_circle(_origin, radius, base_color)
	draw_arc(_origin, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0, true)
	draw_circle(_origin + vector * radius, knob_radius, RUN_KNOB if _sprint_latched else knob_color)
