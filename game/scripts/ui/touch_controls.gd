extends CanvasLayer
## Autoloaded touch layer: tap-to-walk, action buttons and pinch zoom.
## Touch/web builds default to tap-only; F4 cycles the optional joystick for desktop testing.
## Buttons are TouchScreenButtons bound to InputMap actions, so they work with
## multi-touch and gameplay never sees anything but actions.

const CONTEXT_EXPLORE: StringName = &"explore"
const CONTEXT_HUNT: StringName = &"hunt"
const CONTEXT_MOUNTED: StringName = &"mounted"
const CONTEXT_PLACE: StringName = &"place"

const MODE_TAP_ONLY := 0
const MODE_TAP_AND_JOYSTICK := 1
const MODE_HIDDEN := 2

const BUTTONS: Array[Dictionary] = [
	{
		"id": "roll",
		"action": "roll",
		"label": "ROLL",
		"size": 104,
		"at": Vector2(-330, -140),
		"color": Color(0.35, 0.6, 0.9),
		"contexts": [CONTEXT_HUNT]
	},
	{
		"id": "use",
		"action": "interact",
		"label": "USE",
		"size": 96,
		"at": Vector2(-150, -370),
		"color": Color(0.4, 0.8, 0.45),
		"contexts": [CONTEXT_MOUNTED]
	},
	{
		"id": "aid",
		"action": "bandage",
		"label": "AID",
		"size": 72,
		"at": Vector2(-48, -370),
		"color": Color(0.9, 0.5, 0.55),
		"contexts": [&"hurt"]
	},
	{
		"id": "hold",
		"action": "hunt_chase",
		"label": "HOLD",
		"size": 72,
		"at": Vector2(-250, -430),
		"color": Color(0.7, 0.55, 0.3),
		"contexts": [CONTEXT_HUNT]
	},
	{
		"id": "tactic_1",
		"action": "tactic_1",
		"label": "1",
		"size": 80,
		"at": Vector2(-420, -280),
		"color": Color(0.85, 0.75, 0.35),
		"contexts": [CONTEXT_HUNT]
	},
	{
		"id": "tactic_2",
		"action": "tactic_2",
		"label": "2",
		"size": 80,
		"at": Vector2(-340, -340),
		"color": Color(0.85, 0.75, 0.35),
		"contexts": [CONTEXT_HUNT]
	},
	{
		"id": "bag",
		"action": "inventory",
		"label": "BAG",
		"size": 72,
		"at": Vector2(-100, 30),
		"color": Color(0.8, 0.8, 0.8),
		"contexts": [CONTEXT_EXPLORE]
	},
	{
		"id": "craft",
		"action": "craft",
		"label": "CRAFT",
		"size": 72,
		"at": Vector2(-190, 30),
		"color": Color(0.8, 0.8, 0.8),
		"contexts": [CONTEXT_EXPLORE]
	},
	{
		"id": "map",
		"action": "map",
		"label": "MAP",
		"size": 72,
		"at": Vector2(-280, 30),
		"color": Color(0.65, 0.75, 0.9),
		"contexts": [CONTEXT_EXPLORE]
	},
	{
		"id": "place_rotate",
		"action": "place_rotate",
		"label": "ROT",
		"size": 84,
		"at": Vector2(-360, -100),
		"color": Color(0.5, 0.7, 0.95),
		"contexts": [CONTEXT_PLACE]
	},
	{
		"id": "place_confirm",
		"action": "place_confirm",
		"label": "PLACE",
		"size": 118,
		"at": Vector2(-220, -180),
		"color": Color(0.35, 0.8, 0.45),
		"contexts": [CONTEXT_PLACE]
	},
	{
		"id": "place_cancel",
		"action": "place_cancel",
		"label": "CANCEL",
		"size": 108,
		"at": Vector2(-90, -110),
		"color": Color(0.85, 0.4, 0.42),
		"contexts": [CONTEXT_PLACE]
	},
]

var enabled: bool = false
var joystick: TouchJoystick
var _buttons: Node2D
var _gestures: TouchGestures
var _button_nodes: Dictionary = {}
var _context: StringName = CONTEXT_EXPLORE
var _hurt_overlay: bool = false
var _touch_mode: int = MODE_HIDDEN
var hud_mode: bool = false:  # the Durango HUD draws its own hexes; only the place context stays here
	set(v):
		hud_mode = v
		_refresh_buttons()

func _ready() -> void:
	layer = 50
	_touch_mode = MODE_TAP_ONLY if (DisplayServer.is_touchscreen_available() or OS.has_feature("web") or "--touch" in OS.get_cmdline_user_args()) else MODE_HIDDEN
	joystick = TouchJoystick.new()
	add_child(joystick)
	_buttons = Node2D.new()
	add_child(_buttons)
	for spec: Dictionary in BUTTONS:
		var btn := _make_button(spec)
		_buttons.add_child(btn)
		_button_nodes[str(spec["id"])] = btn
	_gestures = TouchGestures.new()
	_gestures.joystick = joystick
	add_child(_gestures)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_apply_mode()
	print("[touch] controls mode=%s (touchscreen=%s)" % [_mode_label(), DisplayServer.is_touchscreen_available()])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("touch_toggle"):
		_cycle_mode()

func set_context(ctx: StringName) -> void:
	if ctx == &"":
		ctx = CONTEXT_EXPLORE
	if _context == ctx:
		return
	_context = ctx
	_refresh_buttons()

func set_hurt_overlay(on: bool) -> void:
	if _hurt_overlay == on:
		return
	_hurt_overlay = on
	_refresh_buttons()

func _cycle_mode() -> void:
	match _touch_mode:
		MODE_TAP_ONLY:
			_touch_mode = MODE_TAP_AND_JOYSTICK
		MODE_TAP_AND_JOYSTICK:
			_touch_mode = MODE_HIDDEN
		_:
			_touch_mode = MODE_TAP_ONLY
	_apply_mode()
	print("[touch] controls mode=%s" % _mode_label())

func _apply_mode() -> void:
	enabled = _touch_mode != MODE_HIDDEN
	joystick.visible = enabled and _touch_mode == MODE_TAP_AND_JOYSTICK
	_buttons.visible = enabled
	_gestures.set_process_input(enabled)
	for b: Node in _buttons.get_children():
		(b as TouchScreenButton).visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS if enabled else TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	_refresh_buttons()

func _mode_label() -> String:
	match _touch_mode:
		MODE_TAP_ONLY:
			return "tap-only"
		MODE_TAP_AND_JOYSTICK:
			return "tap+joystick"
		_:
			return "hidden"

func _layout() -> void:
	var rect := get_viewport().get_visible_rect().size
	# Safe area (notch / home indicator) in canvas units.
	var win := Vector2(DisplayServer.window_get_size())
	var scale := rect / win if win.x > 0.0 and win.y > 0.0 else Vector2.ONE
	# Safe area is only meaningful on phones; on desktop it describes the whole
	# monitor, not the window, and would push everything off-screen.
	var inset_right := 0.0
	var inset_bottom := 0.0
	var inset_top := 0.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		inset_right = maxf(0.0, win.x - (safe.position.x + safe.size.x)) * scale.x
		inset_bottom = maxf(0.0, win.y - (safe.position.y + safe.size.y)) * scale.y
		inset_top = maxf(0.0, safe.position.y) * scale.y
	var i := 0
	for b: Node in _buttons.get_children():
		var spec := BUTTONS[i]
		var at: Vector2 = spec["at"]
		var size: float = spec["size"]
		var pos := Vector2(rect.x + at.x - inset_right, (rect.y + at.y - inset_bottom) if at.y < 0.0 else (at.y + inset_top))
		(b as Node2D).position = pos - Vector2(size, size) * 0.5
		i += 1
	_refresh_buttons()

func _make_button(spec: Dictionary) -> TouchScreenButton:
	var size: float = spec["size"]
	var color: Color = spec["color"]
	var btn := TouchScreenButton.new()
	btn.name = "Btn_%s" % spec["action"]
	btn.action = spec["action"]
	btn.texture_normal = _circle_texture(size, Color(color, 0.45))
	btn.texture_pressed = _circle_texture(size, Color(color, 0.9))
	var shape := CircleShape2D.new()
	shape.radius = size * 0.5
	btn.shape = shape
	btn.shape_centered = true
	var label := Label.new()
	label.text = spec["label"]
	label.size = Vector2(size, size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", int(size * 0.24))
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	btn.add_child(label)
	return btn

static func _circle_texture(size: float, color: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.88, 0.93, 1.0])
	g.colors = PackedColorArray([color, color, Color(1, 1, 1, color.a), Color(color, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = int(size)
	tex.height = int(size)
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex

func _refresh_buttons() -> void:
	for i in BUTTONS.size():
		var spec: Dictionary = BUTTONS[i]
		var btn := _button_nodes.get(str(spec["id"]), null) as TouchScreenButton
		if btn == null:
			continue
		btn.visible = _is_button_visible(spec)

func _is_button_visible(spec: Dictionary) -> bool:
	if not enabled:
		return false
	var contexts: Array = spec.get("contexts", [])
	if hud_mode:
		return false
	for ctx in contexts:
		var name := StringName(str(ctx))
		if name == &"hurt":
			if _hurt_overlay:
				return true
		elif name == _context:
			return true
	return false

func blocks_screen_point(p: Vector2) -> bool:
	if not enabled:
		return false
	if joystick and joystick.visible:
		var jr := Rect2(joystick.position - Vector2(80, 80), Vector2(160, 160))
		if jr.has_point(p):
			return true
	for b: Node in _buttons.get_children():
		var btn := b as TouchScreenButton
		if btn == null or not btn.visible:
			continue
		var size := 80.0
		if btn.texture_normal:
			size = float(btn.texture_normal.get_width())
		var r := Rect2(btn.position, Vector2(size, size))
		if r.has_point(p):
			return true
	return false
