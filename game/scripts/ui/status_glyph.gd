class_name StatusGlyph
extends Control
## Small status glyph with a countdown ring.

var glyph_text: String = "?"
var glyph_color: Color = Color.WHITE
var progress: float = 1.0
var icon: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 128 px UiIcons drawn at ~14 px
	# 14 px letter: plates shrink to 0.86 with distance, which keeps it at the 12 px floor.
	custom_minimum_size = Vector2(26, 26)
	size = custom_minimum_size

func configure(text: String, color: Color, frac: float, tex: Texture2D = null) -> void:
	glyph_text = text
	glyph_color = color
	progress = clampf(frac, 0.0, 1.0)
	icon = tex
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	draw_circle(c, radius, Color(0.05, 0.05, 0.05, 0.82))
	draw_arc(c, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, glyph_color, 2.6, true)
	if icon:
		var isz := radius * 1.3
		draw_texture_rect(icon, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false)
	else:
		UiTokens.draw_centered(self, ThemeDB.fallback_font, c, glyph_text, 14, glyph_color)
