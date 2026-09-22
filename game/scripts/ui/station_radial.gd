class_name StationRadial
extends Control
## Hex radial of recipes a craft station can make. Unprojected over the station.

signal recipe_chosen(recipe_id: StringName)
signal dismissed

const HEX_SIZE := 64.0

var station: Node3D
var _buttons: Array[HexButton] = []
var _icons: Dictionary = {}
var _icon_cache: Dictionary = {}
var _aliases: Dictionary = {}
var _cat_fallback: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_load_icons()

func show_for(st: Node3D, recipes: Array[Dictionary], inv: Inventory) -> void:
	station = st
	_clear_buttons()
	visible = true
	var n := recipes.size()
	for i in n:
		var rec: Dictionary = recipes[i]
		var btn := HexButton.new(HEX_SIZE)
		btn.color_icon = true
		var rid := StringName(str(rec.get("id", "")))
		var out_row: Dictionary = rec.get("output", {})
		var out_id := StringName(str(out_row.get("id", rid)))
		var secs := Crafting.recipe_seconds(rec)
		var level := Crafting.preview_level(inv, rec)
		var missing := Crafting.missing_ingredient_name(inv, rec)
		var label := str(rec.get("display_name", rid))
		if level > 0:
			label = "%s Lv.%d" % [label, level]
		btn.setup(_icon_for(out_id), _glyph_for(out_id), label, "%.1fs" % secs, "×%d" % int(out_row.get("count", 1)))
		if missing != "":
			btn.set_blocked(missing)
		btn.pressed.connect(_on_pressed.bind(rid, missing))
		add_child(btn)
		_buttons.append(btn)
	_update_screen_pos()
	queue_redraw()

func hide_radial() -> void:
	_clear_buttons()
	station = null
	visible = false

func _on_pressed(rid: StringName, missing: String) -> void:
	if missing != "":
		print("[craft] blocked %s: needs %s" % [rid, missing])
		return
	recipe_chosen.emit(rid)

func _clear_buttons() -> void:
	for b in _buttons:
		if is_instance_valid(b):
			b.queue_free()
	_buttons.clear()

func _process(_delta: float) -> void:
	if not visible or station == null or not is_instance_valid(station):
		return
	_update_screen_pos()

func _update_screen_pos() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or station == null:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var world := station.global_position + Vector3(0.0, 1.4, 0.0)
	var screen := cam.unproject_position(world)
	var spots := ContextRadial.hex_positions(screen, _buttons.size(), size, UiTokens.safe_insets(get_viewport()), HEX_SIZE)
	for i in _buttons.size():
		if i < spots.size():
			_buttons[i].position = spots[i]
	queue_redraw()

func _draw() -> void:
	if station == null or not is_instance_valid(station):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var screen := cam.unproject_position(station.global_position + Vector3(0.0, 1.4, 0.0))
	var font := ThemeDB.fallback_font
	var view := get_viewport_rect().size
	var sid := str(station.get("station_id")) if station.get("station_id") != null else str(station.name)
	var title := UiTokens.ellipsis(font, sid.replace("_", " ").capitalize(), 160.0, UiTokens.body(view))
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.body(view)).x
	var pos := screen + Vector2(-tw * 0.5, 22.0)
	draw_rect(Rect2(pos + Vector2(-8, -16), Vector2(tw + 16, 24)), UiTokens.INK)
	draw_string(font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.body(view), Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	# Tap empty radial area does nothing; outside is handled by StationCraft.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()

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
		var cf: Variant = root.get("category_fallback", {})
		if cf is Dictionary:
			_cat_fallback = cf as Dictionary

func _icon_for(id: StringName) -> Texture2D:
	var key := str(id)
	if _aliases.has(key):
		key = str(_aliases[key])
	var icon_path := str(_icons.get(key, ""))
	if icon_path == "" and ResourceLoader.exists("res://assets/icons/%s.png" % key):
		icon_path = "res://assets/icons/%s.png" % key
	if icon_path == "":
		var def := Data.item(id)
		if def:
			for cat in def.categories:
				var fb := str(_cat_fallback.get(str(cat), ""))
				if fb != "" and _icons.has(fb):
					icon_path = str(_icons[fb])
					break
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

func _glyph_for(id: StringName) -> String:
	var s := str(id)
	if s.length() >= 1:
		return s.substr(0, 1).to_upper()
	return "?"
