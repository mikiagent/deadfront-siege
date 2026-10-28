class_name EatProgress
extends Control
## Eating progress over the survivor's head (PRD §6.2 anti-gotcha), B4 look (ui-redesign-spec §7 B4):
## a flat-top hex that fills like a pie (§4), the food's icon and "1.2s left" inside, the food and its
## energy under it, then "moving cancels".

const PIE := Color(0.30, 0.56, 0.32, 0.92)

var progress: float = 0.0
var _hint: Label  ## "moving cancels" (kept as a Label: labs read its visibility)
var _visible_eat: bool = false
var player: Player
var _icon: Texture2D
var _name := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 50
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(260, 190)
	size = custom_minimum_size
	_hint = Label.new()
	_hint.text = "moving cancels"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(size.x, 22)
	_hint.add_theme_font_override("font", UiTokens.ui_face())
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", UiTokens.MUTED)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hint.add_theme_constant_override("outline_size", 3)
	add_child(_hint)

func show_eat(def_id: StringName, p: float = 0.0) -> void:
	_icon = ItemIcons.texture(def_id)
	var def := Data.item(def_id)
	_name = def.display_name if def else str(def_id).capitalize()
	progress = clampf(p, 0.0, 1.0)
	_visible_eat = true
	visible = true
	_hint.visible = true
	queue_redraw()

func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	queue_redraw()

func hide_eat() -> void:
	_visible_eat = false
	visible = false

func _radius() -> float:
	return 40.0 if UiTokens.is_compact(get_viewport_rect().size) else 54.0

## Seconds left of the timed action, from the session that drives it.
func seconds_left() -> float:
	var es: EatSession = player.eat_session if player and player.get("eat_session") else null
	return (1.0 - progress) * (es.eat_seconds if es else Food.EAT_SECONDS)

## "Grilled Meat · +17 energy" (the latent energy of the evaluated bundle), or the bare name.
func line_text() -> String:
	var es: EatSession = player.eat_session if player and player.get("eat_session") else null
	var e := float(es.bundle.get("latent_energy", 0.0)) if es else 0.0
	return "%s · +%d energy" % [_name, int(round(e))] if e > 0.0 else _name

## The hex floats over the survivor's head.
func _process(_delta: float) -> void:
	if not _visible_eat or player == null or not is_instance_valid(player):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var r := _radius()
	var head := cam.unproject_position(player.get_global_transform_interpolated().origin + Vector3(0, 2.15, 0))
	position = head - Vector2(size.x * 0.5, r * 2.0 + 48.0)
	_hint.position = Vector2(0, r * 2.0 + 30.0)
	queue_redraw()

func _draw() -> void:
	if not _visible_eat:
		return
	var r := _radius()
	var c := Vector2(size.x * 0.5, r)
	var font := UiTokens.ui_face()
	var rim := UiTokens.hex_points(c, r, UiTokens.HEX_FLAT_TOP)
	draw_colored_polygon(UiTokens.hex_points(c, r - 1.5, UiTokens.HEX_FLAT_TOP), UiTokens.HUD_FILL)
	var pie := UiTokens.pie_points(c, r - 1.5, progress, UiTokens.HEX_FLAT_TOP)
	if pie.size() >= 3:
		draw_colored_polygon(pie, PIE)
	rim.append(rim[0])
	draw_polyline(rim, UiTokens.HUD_RIM, 3.0, true)
	var isz := r * 0.8
	if _icon:
		draw_texture_rect(_icon, Rect2(c - Vector2(isz * 0.5, isz * 0.75), Vector2(isz, isz)), false)
	var px := 13 if r < 50.0 else 16
	UiTokens.draw_centered(self, font, c + Vector2(0, r * 0.5), "%.1fs left" % seconds_left(), px, UiTokens.TEXT)
	var lpx := 14 if r < 50.0 else 16
	var line := UiTokens.ellipsis(font, line_text(), size.x, lpx)
	var at := Vector2(size.x * 0.5, r * 2.0 + 18.0)
	var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x
	draw_string_outline(font, Vector2(at.x - lw * 0.5, at.y + lpx * 0.36), line, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, 3, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(at.x - lw * 0.5, at.y + lpx * 0.36), line, HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, UiTokens.TEXT)
