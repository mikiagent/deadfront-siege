class_name StationMenu
extends Control
## Hexagonal interact menu floating over a tapped workstation. Workbench offers CRAFT,
## bonfire offers COOK (plus CAUTERISE while bleeding); any other station with recipes
## falls back to CRAFT. Add entries to ACTIONS to give a station its own hexes.
## Tapping a hex emits action_chosen; tapping elsewhere walks and the menu closes.

signal action_chosen(station: Node3D, action_id: StringName)

const HEX_SIZE := 64.0
const GAP := 12.0
const CLOSE_RANGE := 3.6
const MARGIN := 8.0
const RING_RADIUS := 1.15
const RING_WIDTH := 0.07
const EXPAND_SECONDS := 0.22

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
var _ring3d: MeshInstance3D
var _expand_elapsed: float = 0.0

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
		# HexButton only emits after receiving its own press and release. Because this is
		# created after the station press, that opening gesture cannot activate the action.
		# Station entry is an action, so the glyph stays white. Item thumbnails live on the gather radial.
		btn.icon = null
		btn.color_icon = false
		btn.glyph = str(row.get("glyph", "✦"))
		btn.bottom_text = str(row.get("label", ""))
		var aid := StringName(str(row.get("id", "")))
		btn.pressed.connect(_on_pressed.bind(aid))
		add_child(btn)
		_buttons.append(btn)
	visible = true
	_expand_elapsed = 0.0
	_show_ring3d(0.22)
	_update_screen_pos()

func hide_menu() -> void:
	_clear()
	station = null
	visible = false
	_expand_elapsed = 0.0
	if _ring3d:
		_ring3d.visible = false

func _on_pressed(aid: StringName) -> void:
	var st := station
	hide_menu()
	action_chosen.emit(st, aid)

func _clear() -> void:
	for b in _buttons:
		if is_instance_valid(b):
			b.queue_free()
	_buttons.clear()

func _process(delta: float) -> void:
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
	# Ground taps start navigation and dismiss the menu. Do not also close solely because
	# the first station tap came from farther than CLOSE_RANGE; that made the ring flash
	# for one frame at the opening camp.
	if player and player.nav_active:
		hide_menu()
		return
	_expand_elapsed = minf(EXPAND_SECONDS, _expand_elapsed + delta)
	var t := ease(_expand_elapsed / EXPAND_SECONDS, 0.35)
	_show_ring3d(lerpf(0.22, RING_RADIUS, t))
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
	var view := get_viewport_rect().size
	var spots := ContextRadial.hex_positions(anchor, _buttons.size(), view, UiTokens.safe_insets(get_viewport()), HEX_SIZE)
	for i in _buttons.size():
		if i < spots.size():
			_buttons[i].position = spots[i]

## Ground selection ring shared visually with gathering. It grows from the station on first tap;
## the action hex sits above it and needs its own second tap.
func _show_ring3d(radius: float) -> void:
	if station == null or not is_instance_valid(station):
		return
	if _ring3d == null:
		_ring3d = MeshInstance3D.new()
		_ring3d.name = "StationSelectHex3D"
		_ring3d.top_level = true
		_ring3d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.92, 0.5, 0.82)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring3d.material_override = material
		_ring3d.mesh = ImmediateMesh.new()
		var host: Node = get_tree().current_scene
		if host:
			host.add_child(_ring3d)
		else:
			add_child(_ring3d)
	var im := _ring3d.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := station.global_position
	var rt := World.runtime if World else null
	var has_surface := rt != null and rt.has_method("surface_y")
	var inner := maxf(0.03, radius - RING_WIDTH)
	for i in 6:
		var a0 := deg_to_rad(60.0 * float(i))
		var a1 := deg_to_rad(60.0 * float(i + 1))
		var quad: Array[Vector3] = []
		for pair in [[a0, inner], [a0, radius], [a1, radius], [a1, inner]]:
			var point := c + Vector3(cos(pair[0]) * pair[1], 0.0, sin(pair[0]) * pair[1])
			point.y = (rt.surface_y(point.x, point.z) if has_surface else c.y) + 0.05
			quad.append(point)
		im.surface_add_vertex(quad[0])
		im.surface_add_vertex(quad[1])
		im.surface_add_vertex(quad[2])
		im.surface_add_vertex(quad[0])
		im.surface_add_vertex(quad[2])
		im.surface_add_vertex(quad[3])
	im.surface_end()
	_ring3d.global_transform = Transform3D.IDENTITY
	_ring3d.visible = true

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
