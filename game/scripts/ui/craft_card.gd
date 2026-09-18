class_name CraftCard
extends PanelContainer
## Compact unprojected craft panel above a station: name, ingredient slots with rings.

const SLOT_R := 28.0
const RING_W := 4.0

var recipe_name: String = ""
var queue_count: int = 1
var progress: float = 0.0
var slots: Array[Dictionary] = []
var station: Node3D
var follow_station: bool = true

var _title: Label
var _slots_row: HBoxContainer
var _slot_draws: Array[Control] = []
var _icons: Dictionary = {}
var _icon_cache: Dictionary = {}
var _aliases: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 40
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.1, 0.92)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	box.add_child(_title)
	_slots_row = HBoxContainer.new()
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_row.add_theme_constant_override("separation", 10)
	box.add_child(_slots_row)
	_load_icons()

func show_recipe(st: Node3D, name: String, slot_rows: Array[Dictionary], p_progress: float = 0.0, queue: int = 1) -> void:
	station = st
	recipe_name = name
	slots = slot_rows
	progress = clampf(p_progress, 0.0, 1.0)
	queue_count = maxi(1, queue)
	follow_station = true
	_rebuild_slots()
	_title.text = recipe_name if queue_count <= 1 else "%s  ×%d" % [recipe_name, queue_count]
	visible = true
	modulate = Color.WHITE
	_update_screen_pos()

func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	for c in _slot_draws:
		c.queue_redraw()

func set_queue(n: int) -> void:
	queue_count = maxi(1, n)
	if _title:
		_title.text = recipe_name if queue_count <= 1 else "%s  ×%d" % [recipe_name, queue_count]

func hide_card() -> void:
	station = null
	visible = false
	follow_station = true

func icon_for(id: StringName) -> Texture2D:
	return _icon_for(id)

func _rebuild_slots() -> void:
	for c in _slots_row.get_children():
		c.queue_free()
	_slot_draws.clear()
	for i in slots.size():
		if i > 0:
			var plus := Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 18)
			plus.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
			_slots_row.add_child(plus)
		var slot := _SlotRing.new()
		slot.custom_minimum_size = Vector2(SLOT_R * 2.0 + 4.0, SLOT_R * 2.0 + 4.0)
		slot.icon = slots[i].get("icon", null) as Texture2D
		slot.glyph = str(slots[i].get("glyph", "?"))
		slot.count = int(slots[i].get("count", 1))
		slot.progress = progress
		slot.host = self
		_slots_row.add_child(slot)
		_slot_draws.append(slot)

func _process(_delta: float) -> void:
	if not visible:
		return
	if follow_station and station and is_instance_valid(station):
		_update_screen_pos()
	for c in _slot_draws:
		if c.has_method("sync_progress"):
			c.sync_progress(progress)

func _update_screen_pos() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or station == null:
		return
	var world := station.global_position + Vector3(0.0, 1.85, 0.0)
	var screen := cam.unproject_position(world)
	position = screen - Vector2(size.x * 0.5, size.y + 8.0)

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

class _SlotRing extends Control:
	var icon: Texture2D
	var glyph: String = "?"
	var count: int = 1
	var progress: float = 0.0
	var host: CraftCard

	func sync_progress(p: float) -> void:
		progress = p
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, SLOT_R, Color(0.16, 0.17, 0.19, 0.95))
		draw_arc(c, SLOT_R - 1.0, 0.0, TAU, 48, Color(0.35, 0.38, 0.4, 0.9), RING_W, true)
		draw_arc(c, SLOT_R - 1.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(0.95, 0.95, 0.92, 0.98), RING_W, true)
		if icon:
			draw_texture_rect(icon, Rect2(c - Vector2(16, 16), Vector2(32, 32)), false)
		else:
			var font := ThemeDB.fallback_font
			if font:
				draw_string(font, c + Vector2(0, 4), glyph, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 14, Color(0.9, 0.9, 0.85))
		if count > 1:
			var font2 := ThemeDB.fallback_font
			if font2:
				draw_string(font2, c + Vector2(14, 18), str(count), HORIZONTAL_ALIGNMENT_LEFT, 30.0, 11, Color(1, 1, 1, 0.95))
