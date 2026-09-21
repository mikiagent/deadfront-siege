class_name StationMenu
extends Control
## Hexagonal interact menu floating over a tapped workstation. Workbench offers CRAFT,
## bonfire offers COOK (plus CAUTERISE while bleeding); any other station with recipes
## falls back to CRAFT. Add entries to ACTIONS to give a station its own hexes.
## Tapping a hex emits action_chosen; tapping elsewhere walks and the menu closes.

signal action_chosen(station: Node3D, action_id: StringName)

const HEX_SIZE := 76.0
const GAP := 12.0
const CLOSE_RANGE := 3.6
const MARGIN := 8.0

## Per-station hexes. icon resolves through data/icons_manifest.json, glyph is the fallback.
const ACTIONS := {
	&"workbench": [{"id": &"craft", "label": "CRAFT", "icon": "hammer", "glyph": "🔨"}],
	&"bonfire": [{"id": &"cook", "label": "COOK", "icon": "skewer", "glyph": "🍖"}],
}
## Menu anchor height above the station origin, per station kind.
const HEIGHTS := {
	&"workbench": 1.55,
	&"bonfire": 1.25,
	&"drying_rack": 1.5,
}
const DEFAULT_HEIGHT := 1.45

var station: Node3D
var player: Player
var _buttons: Array[HexButton] = []
var _icons: Dictionary = {}
var _aliases: Dictionary = {}
var _icon_cache: Dictionary = {}

## The hexes a station offers right now. Data-driven so new stations/actions slot in here.
static func actions_for(sid: StringName, p: Player) -> Array:
	var out: Array = []
	var list: Array = ACTIONS.get(sid, [])
	if list.is_empty() and not Crafting.recipes_for_station(sid).is_empty():
		list = [{"id": &"craft", "label": "CRAFT", "icon": "hammer", "glyph": "🔨"}]
	for a in list:
		out.append((a as Dictionary).duplicate())
	if sid == &"bonfire" and p != null and p.statuses \
			and (p.statuses.has(&"bleed") or p.statuses.has(&"deep_bleed")):
		out.append({"id": &"cauterise", "label": "CAUTERISE", "icon": "", "glyph": "🔥"})
	return out

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_load_icons()

func show_for(st: Node3D, actions: Array) -> void:
	station = st
	_clear()
	for a in actions:
		var row: Dictionary = a
		var btn := HexButton.new(HEX_SIZE)
		btn.icon = _icon_for(str(row.get("icon", "")))
		btn.glyph = "" if btn.icon else str(row.get("glyph", ""))
		btn.bottom_text = str(row.get("label", ""))
		var aid := StringName(str(row.get("id", "")))
		btn.pressed.connect(_on_pressed.bind(aid))
		add_child(btn)
		_buttons.append(btn)
	visible = true
	_update_screen_pos()

func hide_menu() -> void:
	_clear()
	station = null
	visible = false

func _on_pressed(aid: StringName) -> void:
	var st := station
	hide_menu()
	action_chosen.emit(st, aid)

func _clear() -> void:
	for b in _buttons:
		if is_instance_valid(b):
			b.queue_free()
	_buttons.clear()

func _process(_delta: float) -> void:
	if not visible:
		return
	if station == null or not is_instance_valid(station):
		hide_menu()
		return
	# The craft sheet covers the station flow; walking away dismisses.
	var cui: Variant = player.get("craft_ui") if player else null
	if cui != null and cui is Control and (cui as Control).visible:
		hide_menu()
		return
	if player and (player.nav_active \
			or player.global_position.distance_to(station.global_position) > CLOSE_RANGE):
		hide_menu()
		return
	_update_screen_pos()

func _update_screen_pos() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or station == null:
		return
	var sid := StringName(str(station.get("station_id"))) if station.get("station_id") != null else &""
	var h := float(HEIGHTS.get(sid, DEFAULT_HEIGHT))
	var world := station.global_position + Vector3(0.0, h, 0.0)
	if cam.is_position_behind(world):
		return
	var anchor := cam.unproject_position(world)
	var n := _buttons.size()
	var total := float(n) * HEX_SIZE + float(maxi(0, n - 1)) * GAP
	var view := get_viewport_rect().size
	var x := clampf(anchor.x - total * 0.5, MARGIN, maxf(MARGIN, view.x - total - MARGIN))
	var y := clampf(anchor.y - HEX_SIZE * 0.5, MARGIN, maxf(MARGIN, view.y - HEX_SIZE - MARGIN))
	for i in n:
		_buttons[i].position = Vector2(x + float(i) * (HEX_SIZE + GAP), y)

func _load_icons() -> void:
	var path := "res://data/icons_manifest.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var root := parsed as Dictionary
		var block: Variant = root.get("icons", {})
		if block is Dictionary:
			_icons = block as Dictionary
		var al: Variant = root.get("aliases", {})
		if al is Dictionary:
			_aliases = al as Dictionary

func _icon_for(key: String) -> Texture2D:
	if key == "":
		return null
	if _aliases.has(key):
		key = str(_aliases[key])
	var icon_path := str(_icons.get(key, ""))
	if icon_path == "" and ResourceLoader.exists("res://assets/icons/%s.png" % key):
		icon_path = "res://assets/icons/%s.png" % key
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return null
	if _icon_cache.has(icon_path):
		return _icon_cache[icon_path] as Texture2D
	var tex := load(icon_path) as Texture2D
	if tex:
		_icon_cache[icon_path] = tex
	return tex
