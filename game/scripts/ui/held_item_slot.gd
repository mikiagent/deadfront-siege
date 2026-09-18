class_name HeldItemSlot
extends Control
## Bottom-left 64 px equipped-tool slot above the menu row; tap opens swap row, long-press unequips.

signal equip_requested(slot_index: int)
signal unequip_requested

const SLOT := 64.0

var player: Player
var _icon: Texture2D
var _glyph: String = ""
var _swap_open: bool = false
var _swap_row: HBoxContainer
var _pressing: bool = false
var _long_left: float = 0.0
var _icons: Dictionary = {}
var _icon_cache: Dictionary = {}
var _aliases: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(SLOT, SLOT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	position = Vector2(20, -160)
	_load_icons()
	_swap_row = HBoxContainer.new()
	_swap_row.visible = false
	_swap_row.position = Vector2(SLOT + 8.0, 0.0)
	_swap_row.add_theme_constant_override("separation", 8)
	add_child(_swap_row)

func bind(p: Player) -> void:
	player = p
	if player and player.inventory and not player.inventory.changed.is_connected(refresh):
		player.inventory.changed.connect(refresh)
	refresh()

func refresh() -> void:
	_icon = null
	_glyph = ""
	if player == null:
		queue_redraw()
		return
	var tool := player.inventory.equipped_gather_tool()
	if tool:
		_icon = _icon_for(tool.def_id)
		_glyph = str(tool.def_id).substr(0, 1).to_upper()
	if _swap_open:
		_rebuild_swap()
	queue_redraw()

func open_swap_for_shot() -> void:
	_swap_open = true
	_rebuild_swap()
	queue_redraw()

func _rebuild_swap() -> void:
	for c in _swap_row.get_children():
		c.queue_free()
	if player == null:
		_swap_row.visible = false
		return
	var tools := player.inventory.gather_tools_in_bag()
	for entry in tools:
		var idx: int = int(entry.get("index", -1))
		var stack: ItemStack = entry.get("stack", null) as ItemStack
		if stack == null:
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT, SLOT)
		b.text = str(stack.def_id).substr(0, 4)
		var tex := _icon_for(stack.def_id)
		if tex:
			b.icon = tex
			b.text = ""
			b.expand_icon = true
		b.pressed.connect(func () -> void:
			equip_requested.emit(idx)
			_swap_open = false
			_swap_row.visible = false
		)
		_swap_row.add_child(b)
	_swap_row.visible = tools.size() > 0
	_swap_open = _swap_row.visible

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressing = true
			_long_left = 0.45
		else:
			if _pressing:
				if _swap_open:
					_swap_open = false
					_swap_row.visible = false
				else:
					_swap_open = true
					_rebuild_swap()
			_pressing = false
		accept_event()
		queue_redraw()

func _process(delta: float) -> void:
	var safe := DisplayServer.get_display_safe_area()
	var vp := get_viewport_rect().size
	var left := 20.0 + float(safe.position.x)
	var bottom_margin := 150.0 + float(maxi(0, int(vp.y) - safe.end.y))
	position = Vector2(left, vp.y - bottom_margin - SLOT)
	if _pressing:
		_long_left -= delta
		if _long_left <= 0.0:
			_pressing = false
			_swap_open = false
			_swap_row.visible = false
			unequip_requested.emit()
			queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, SLOT * 0.48, Color(0.1, 0.11, 0.13, 0.92))
	draw_arc(c, SLOT * 0.48, 0.0, TAU, 40, Color(0.7, 0.72, 0.75, 0.7), 2.0, true)
	if _icon:
		draw_texture_rect(_icon, Rect2(c - Vector2(20, 20), Vector2(40, 40)), false)
	else:
		var font := ThemeDB.fallback_font
		if font and _glyph != "":
			draw_string(font, c + Vector2(0, 6), _glyph, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 18, Color(0.9, 0.9, 0.85))
		elif font:
			draw_string(font, c + Vector2(0, 6), "—", HORIZONTAL_ALIGNMENT_CENTER, SLOT, 18, Color(0.6, 0.6, 0.6))
	# Swap arrows glyph.
	var font2 := ThemeDB.fallback_font
	if font2:
		draw_string(font2, Vector2(size.x - 10, 14), "⇄", HORIZONTAL_ALIGNMENT_CENTER, 20.0, 12, Color(0.85, 0.85, 0.8, 0.9))

func _icon_for(id: StringName) -> Texture2D:
	var key := str(id)
	if _aliases.has(key):
		key = str(_aliases[key])
	var icon_path := str(_icons.get(key, ""))
	if icon_path == "" and ResourceLoader.exists("res://assets/icons/%s.png" % key):
		icon_path = "res://assets/icons/%s.png" % key
	if icon_path == "":
		return null
	if _icon_cache.has(icon_path):
		return _icon_cache[icon_path] as Texture2D
	if not ResourceLoader.exists(icon_path):
		return null
	var tex := load(icon_path) as Texture2D
	if tex:
		_icon_cache[icon_path] = tex
	return tex

func _load_icons() -> void:
	var path := "res://data/icons_manifest.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var root := parsed as Dictionary
		var block: Variant = root.get("icons", {})
		if block is Dictionary:
			_icons = block as Dictionary
		var al: Variant = root.get("aliases", {})
		if al is Dictionary:
			_aliases = al as Dictionary
