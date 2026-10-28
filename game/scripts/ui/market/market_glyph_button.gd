class_name MarketGlyphButton
extends Button
## The header's back chevron (‹) and close cross (✕), drawn as strokes so no glyph font is needed.
## 64x64 tap target (owner rule); the stroke sits centred in it.

var kind := &"close"

func _init(p_kind: StringName = &"close") -> void:
	kind = p_kind
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(64, 64)
	tooltip_text = "Back" if kind == &"back" else "Close"
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, empty)

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.22
	var col := UiTokens.GOLD if (is_hovered() or has_focus()) else UiTokens.TEXT
	if kind == &"back":
		draw_polyline(PackedVector2Array([c + Vector2(r * 0.45, -r), c + Vector2(-r * 0.45, 0), c + Vector2(r * 0.45, r)]), col, 3.0, true)
	else:
		draw_line(c - Vector2(r, r), c + Vector2(r, r), col, 3.0, true)
		draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, 3.0, true)
