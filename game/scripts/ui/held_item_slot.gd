class_name HeldItemSlot
extends Control
## Bottom-right hex showing the held gather tool. Tap cycles to the next tool in the bag,
## long-press unequips. Gathering auto-equips the tool the node needs (Player._auto_equip_tool),
## so this is mostly for choosing a weapon or checking what is in hand.

signal equip_requested(slot_index: int)
signal unequip_requested

const SLOT := 64.0

var player: Player
var _icon: Texture2D
var _caption: String = "TOOL"
var _pressing: bool = false
var _long_left: float = 0.0
var _fired_long: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(SLOT, SLOT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)

func bind(p: Player) -> void:
	player = p
	if player and player.inventory and not player.inventory.changed.is_connected(refresh):
		player.inventory.changed.connect(refresh)
	refresh()

var _fighting_shown: bool = false

func _fighting() -> bool:
	return player != null and player.hunt != null and player.hunt.target != null and is_instance_valid(player.hunt.target)

func refresh() -> void:
	_icon = null
	_caption = "TOOL"
	if player == null:
		queue_redraw()
		return
	var tool := player.inventory.equipped_gather_tool()
	if tool == null:
		# Bare hands: fists while fighting, open hands while gathering.
		_fighting_shown = _fighting()
		_icon = ItemIcons.texture(&"fists" if _fighting_shown else &"hands")
		_caption = "FISTS" if _fighting_shown else "HANDS"
	if tool:
		_icon = ItemIcons.texture(tool.def_id)
		var d := tool.def()
		var name := d.display_name if d and d.display_name != "" else str(tool.def_id).replace("_", " ")
		_caption = name.to_upper()
	queue_redraw()

func open_swap_for_shot() -> void:
	pass

## Next tool in the bag after the held one (wraps). Nothing held -> first tool.
func cycle() -> void:
	if player == null:
		return
	var tools := player.inventory.gather_tools_in_bag()
	if tools.is_empty():
		return
	var cur := player.inventory.equipped_tool_index
	var pos := -1
	for i in tools.size():
		if int(tools[i].get("index", -1)) == cur:
			pos = i
			break
	var next: Dictionary = tools[(pos + 1) % tools.size()]
	equip_requested.emit(int(next.get("index", -1)))

func _gui_input(event: InputEvent) -> void:
	var press := false
	var release := false
	if event is InputEventScreenTouch:
		press = (event as InputEventScreenTouch).pressed
		release = not press
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		press = (event as InputEventMouseButton).pressed
		release = not press
	else:
		return
	if press:
		_pressing = true
		_fired_long = false
		_long_left = 0.5
	elif release:
		if _pressing and not _fired_long:
			cycle()
		_pressing = false
	accept_event()
	queue_redraw()

func _process(delta: float) -> void:
	if player and player.inventory.equipped_gather_tool() == null and _fighting() != _fighting_shown:
		refresh()
	var safe := DisplayServer.get_display_safe_area()
	var vp := get_viewport_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var scale := vp / win if win.x > 0.0 and win.y > 0.0 else Vector2.ONE
	var right := 16.0 + maxf(0.0, win.x - float(safe.end.x)) * scale.x
	var bottom := 108.0 + maxf(0.0, win.y - float(safe.end.y)) * scale.y
	position = Vector2(vp.x - right - SLOT, vp.y - bottom - SLOT)
	if _pressing:
		_long_left -= delta
		if _long_left <= 0.0:
			_pressing = false
			_fired_long = true
			unequip_requested.emit()
			queue_redraw()

func _hex(r: float, c: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * float(i) - 30.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

func _draw() -> void:
	var c := size * 0.5
	var r := SLOT * 0.5 - 2.0
	var fill := Color(0.07, 0.08, 0.09, 0.93)
	if _pressing:
		fill = fill.lightened(0.15)
	draw_colored_polygon(_hex(r, c), fill)
	var outline := _hex(r, c)
	outline.append(outline[0])
	draw_polyline(outline, Color(0.95, 0.95, 0.95), 2.0, true)
	var font := ThemeDB.fallback_font
	if _icon:
		var isz := r * 0.95
		draw_texture_rect(_icon, Rect2(c - Vector2(isz, isz + 6.0) * 0.5, Vector2(isz, isz)), false)
	elif font:
		var gs := int(r * 0.7)
		var w := font.get_string_size("—", HORIZONTAL_ALIGNMENT_CENTER, -1, gs).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y + gs * 0.2), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Color(0.6, 0.6, 0.6))
	if font:
		# Caption sits under the hex like every other action word (HexButton.caption) and is
		# ellipsised and kept on screen; the slot hugs the bottom-right corner.
		var bs := 13
		var cap := UiTokens.ellipsis(font, _caption, size.x * 1.25, bs)
		var w := font.get_string_size(cap, HORIZONTAL_ALIGNMENT_CENTER, -1, bs).x
		var cx := c.x - w * 0.5
		var gx := global_position.x
		var vw := get_viewport_rect().size.x
		if gx + size.x > vw - 40.0:
			cx = minf(cx, size.x + 6.0 - w)  # right-edge hex: end the word at the hex edge
		cx = maxf(cx, 4.0 - gx)
		draw_string(font, Vector2(cx, c.y + r + 15.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color.WHITE)
		var bc := c + Vector2(r * 0.55, -r * 0.55)
		draw_circle(bc, r * 0.24, Color(0.2, 0.22, 0.26, 0.95))
		var sw := font.get_string_size("⇄", HORIZONTAL_ALIGNMENT_CENTER, -1, 11).x
		draw_string(font, Vector2(bc.x - sw * 0.5, bc.y + 4.0), "⇄", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.95, 0.9))
