class_name EatProgress
extends Control
## Progress ring + "keep still" hint while eating (PRD §6.2 anti-gotcha).

const RING_R := 36.0
const RING_W := 5.0

var progress: float = 0.0
var _hint: Label
var _visible_eat: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 50
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(160, 120)
	size = custom_minimum_size
	_hint = Label.new()
	_hint.text = "Keep still"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 78)
	_hint.size = Vector2(160, 28)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	add_child(_hint)

func show_eat(_def_id: StringName, p: float = 0.0) -> void:
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

func _draw() -> void:
	if not _visible_eat:
		return
	var c := Vector2(size.x * 0.5, 44.0)
	draw_circle(c, RING_R, Color(0.08, 0.09, 0.1, 0.9))
	draw_arc(c, RING_R - 1.0, 0.0, TAU, 48, Color(0.35, 0.38, 0.4, 0.9), RING_W, true)
	draw_arc(c, RING_R - 1.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(0.35, 0.75, 1.0, 0.98), RING_W, true)
	var font := ThemeDB.fallback_font
	if font:
		draw_string(font, c + Vector2(0, 5), "Eat", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 14, Color(0.95, 0.95, 0.9))
