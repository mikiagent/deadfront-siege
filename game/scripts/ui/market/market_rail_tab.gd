class_name MarketRailTab
extends Button
## A tall left-rail tab of the Island Market (spec 14): an icon over its label. The active tab is
## lighter, with GOLD corner brackets and a GOLD label (§8 selection). Icons are drawn strokes:
## cart (Buy), ledger (My Market), price tag (Sell).

var id := &"buy"
var label := ""
var px := 22
var picked := false:
	set(b):
		picked = b
		queue_redraw()

func _init(p_id: StringName = &"buy", p_label: String = "") -> void:
	id = p_id
	label = p_label
	flat = true
	focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, empty)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(UiTokens.PANEL, 0.95) if picked else Color(UiTokens.PANEL, 0.55))
	if picked:
		draw_rect(r, Color(1, 1, 1, 0.06))
	elif is_hovered() or has_focus():
		draw_rect(r, Color(1, 1, 1, 0.03))
	var x := 0.0
	while x < size.x: # dotted divider under the tab
		draw_line(Vector2(x, size.y - 1), Vector2(minf(x + 3, size.x), size.y - 1), Color(UiTokens.DIVIDER, 0.6))
		x += 7.0
	var col := UiTokens.GOLD if picked else UiTokens.TEXT
	var s := minf(size.x * 0.34, size.y * 0.3)
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	_icon(c, s, col)
	var f := UiTokens.ui_face(UiTokens.WEIGHT_BOLD if picked else UiTokens.WEIGHT_REGULAR)
	UiTokens.draw_centered(self, f, Vector2(size.x * 0.5, size.y * 0.78), UiTokens.ellipsis(f, label, size.x - 8.0, px), px, col)
	if picked:
		UiTokens.draw_brackets(self, r.grow(-3.0), UiTokens.GOLD, minf(UiTokens.BRACKET_ARM, size.y * 0.2))

func _icon(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.08)
	match id:
		&"buy": # cart: basket trapezoid, handle, two wheels
			var h := s * 0.5
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, -h * 0.9), c + Vector2(-s * 0.45, -h * 0.9), c + Vector2(-s * 0.25, h * 0.4), c + Vector2(s * 0.5, h * 0.4), c + Vector2(s * 0.62, -h * 0.5), c + Vector2(-s * 0.38, -h * 0.5)]), col, w, true)
			draw_arc(c + Vector2(-s * 0.15, h * 0.85), s * 0.1, 0, TAU, 12, col, w, true)
			draw_arc(c + Vector2(s * 0.4, h * 0.85), s * 0.1, 0, TAU, 12, col, w, true)
		&"my_market": # ledger: a page with lines and a small stacked box
			var page := Rect2(c - Vector2(s * 0.55, s * 0.6), Vector2(s * 0.8, s * 1.1))
			draw_rect(page, col, false, w)
			for i in 3:
				var y := page.position.y + page.size.y * (0.28 + 0.2 * i)
				draw_line(Vector2(page.position.x + s * 0.12, y), Vector2(page.end.x - s * 0.15, y), col, w * 0.8)
			draw_rect(Rect2(c + Vector2(s * 0.1, s * 0.1), Vector2(s * 0.5, s * 0.4)), col, true)
		_: # price tag with a coin hole
			var pts := PackedVector2Array([c + Vector2(-s * 0.65, -s * 0.15), c + Vector2(-s * 0.2, -s * 0.6), c + Vector2(s * 0.65, -s * 0.6), c + Vector2(s * 0.65, s * 0.45), c + Vector2(-s * 0.2, s * 0.45)])
			pts.append(pts[0])
			draw_polyline(pts, col, w, true)
			draw_arc(c + Vector2(s * 0.2, -s * 0.07), s * 0.24, 0, TAU, 18, col, w, true)
