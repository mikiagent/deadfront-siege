class_name PickupToast
extends Control
## Top-centre floating toast for item gains. Stacks repeated ids.

const RISE_PX := 40.0
const LIFE := 1.2

var _rows: Array[Dictionary] = [] ## {id, count, age, icon}
var _icons: Dictionary = {}
var _icon_cache: Dictionary = {}
var _aliases: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = 72.0
	offset_bottom = 160.0
	_load_icons()

func show_gain(def_id: StringName, count: int) -> void:
	if count <= 0:
		return
	print("[ui] toast %s +%d" % [def_id, count])
	for row in _rows:
		if str(row.get("id", "")) == str(def_id) and float(row.get("age", 0.0)) < LIFE * 0.85:
			row["count"] = int(row.get("count", 0)) + count
			row["age"] = 0.0
			queue_redraw()
			return
	_rows.append({
		"id": str(def_id),
		"count": count,
		"age": 0.0,
		"icon": _icon_for(def_id),
	})
	queue_redraw()

func _process(delta: float) -> void:
	if _rows.is_empty():
		return
	var keep: Array[Dictionary] = []
	for row in _rows:
		row["age"] = float(row.get("age", 0.0)) + delta
		if float(row["age"]) < LIFE:
			keep.append(row)
	_rows = keep
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var y := 0.0
	for row in _rows:
		var age := float(row.get("age", 0.0))
		var t := clampf(age / LIFE, 0.0, 1.0)
		var alpha := 1.0 - t
		var rise := RISE_PX * t
		var cx := size.x * 0.5
		var cy := 28.0 + y - rise
		var col := Color(1, 1, 1, alpha)
		var icon: Texture2D = row.get("icon", null) as Texture2D
		if icon:
			draw_texture_rect(icon, Rect2(cx - 40, cy - 14, 28, 28), false, col)
		if font:
			draw_string(font, Vector2(cx + 4, cy + 6), "+%d" % int(row.get("count", 1)), HORIZONTAL_ALIGNMENT_LEFT, 80.0, 18, col)
		y += 34.0

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
