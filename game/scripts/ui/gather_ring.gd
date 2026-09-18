class_name GatherRing
extends Control
## Floating ring over an active harvest node: pool fill, unit progress and icon.

const SIZE_PX := 72.0
const RADIUS_OUTER := 32.0
const RADIUS_INNER := 24.0
const OUTER_WIDTH := 7.0
const INNER_WIDTH := 2.5
const FADE_SECONDS := 0.6

var target: HarvestNode
var _tame_target: Creature
var unit_progress: float = 0.0
var _outer_progress: float = 0.0
var _pool_text: String = ""
var _yield_text: String = ""
var _icon: Texture2D
var _alpha: float = 0.0
var _fade_left: float = 0.0
var _screen_pos: Vector2 = Vector2.ZERO
var _icons: Dictionary = {}
var _icon_cache: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	size = custom_minimum_size
	visible = false
	_load_icons_manifest()

func show_for(node: HarvestNode, progress: float) -> void:
	if node == null:
		return
	target = node
	_tame_target = null
	unit_progress = clampf(progress, 0.0, 1.0)
	_outer_progress = clampf(float(node.session_gathered) / float(maxi(1, node.pool_max)), 0.0, 1.0)
	_pool_text = "%d/%d" % [node.pool_units_left(), maxi(1, node.pool_max)]
	var def := Data.item(node.yield_def_id)
	_yield_text = def.display_name if def else str(node.yield_def_id)
	_icon = _icon_for(node.yield_def_id)
	_alpha = 1.0
	_fade_left = 0.0
	_update_screen_position()
	visible = true
	modulate.a = 1.0
	queue_redraw()

func show_for_tame(creature: Creature, progress: float, food_id: StringName) -> void:
	if creature == null:
		return
	target = null
	_tame_target = creature
	unit_progress = clampf(progress, 0.0, 1.0)
	_outer_progress = clampf(creature.tame_feeds / maxf(0.001, creature.def.feeds_needed), 0.0, 1.0)
	_pool_text = "%.0f/%.0f" % [creature.tame_feeds, creature.def.feeds_needed]
	var def := Data.item(food_id)
	_yield_text = def.display_name if def else str(food_id)
	_icon = _icon_for(food_id)
	_alpha = 1.0
	_fade_left = 0.0
	_update_screen_position()
	visible = true
	modulate.a = 1.0
	queue_redraw()

func fade_out() -> void:
	if not visible:
		return
	target = null
	_tame_target = null
	_fade_left = FADE_SECONDS

func clear_now() -> void:
	target = null
	_tame_target = null
	_fade_left = 0.0
	_alpha = 0.0
	visible = false

func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		_update_screen_position()
	elif _tame_target and is_instance_valid(_tame_target):
		_update_screen_position()
	if _fade_left > 0.0:
		_fade_left = maxf(0.0, _fade_left - delta)
		_alpha = _fade_left / FADE_SECONDS
		if _alpha <= 0.01:
			clear_now()
			return
	elif (target and is_instance_valid(target)) or (_tame_target and is_instance_valid(_tame_target)):
		_alpha = 1.0
	else:
		_alpha = 0.0
		visible = false
		return
	position = _screen_pos - size * 0.5
	modulate.a = _alpha
	queue_redraw()

func _update_screen_position() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var world := Vector3.ZERO
	if target and is_instance_valid(target):
		world = target.global_position + Vector3(0.0, target.top_of_node() + 0.3, 0.0)
	elif _tame_target and is_instance_valid(_tame_target):
		world = _tame_target.global_position + Vector3(0.0, _tame_target.def.height_meters + 0.35, 0.0)
	else:
		return
	_screen_pos = cam.unproject_position(world)

func _draw() -> void:
	var c := Vector2(SIZE_PX * 0.5, SIZE_PX * 0.5)
	draw_arc(c, RADIUS_OUTER, 0.0, TAU, 64, Color(0.05, 0.05, 0.05, 0.45), OUTER_WIDTH, true)
	draw_arc(c, RADIUS_OUTER, -PI * 0.5, -PI * 0.5 + TAU * _outer_progress, 64, Color(0.2, 0.9, 0.45, 0.95), OUTER_WIDTH, true)
	draw_arc(c, RADIUS_INNER, 0.0, TAU, 64, Color(0.95, 0.95, 0.95, 0.22), INNER_WIDTH, true)
	draw_arc(c, RADIUS_INNER, -PI * 0.5, -PI * 0.5 + TAU * unit_progress, 64, Color(1, 1, 1, 0.95), INNER_WIDTH, true)
	if _icon:
		draw_texture_rect(_icon, Rect2(c - Vector2(10, 28), Vector2(20, 20)), false)
	else:
		var font0 := ThemeDB.fallback_font
		if font0:
			draw_string(font0, c + Vector2(0, -13), _yield_text, HORIZONTAL_ALIGNMENT_CENTER, 64.0, 11, Color(1, 1, 1, 0.85))
	var font := ThemeDB.fallback_font
	if font:
		draw_string(font, c + Vector2(0, 8), _pool_text, HORIZONTAL_ALIGNMENT_CENTER, 64.0, 16, Color(1, 1, 1, 0.98))

func _load_icons_manifest() -> void:
	var path := "res://data/icons_manifest.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var block: Variant = (parsed as Dictionary).get("icons", {})
		if block is Dictionary:
			_icons = block as Dictionary

func _icon_for(id: StringName) -> Texture2D:
	var icon_path := str(_icons.get(str(id), ""))
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
