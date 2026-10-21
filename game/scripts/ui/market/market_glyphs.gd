class_name MarketGlyphs
extends RefCounted
## The market's own white glyphs, drawn with draw_* so they stay crisp at any size: the rail's
## cart / ledger / price tag, sort arrows, the category and stepper chevrons and the bonded "B" badge.
# ASSUMPTION (exchange-spec A9): drawn in-package, not added to ui_icons.json (W1-UIICONS' gated set).

static func draw(ci: CanvasItem, id: StringName, r: Rect2, color: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var o := r.get_center() - Vector2(s, s) * 0.5
	var w := maxf(2.0, s * 0.08)
	match id:
		&"cart":
			ci.draw_polyline(_pts(o, s, [[0.05, 0.18], [0.22, 0.18], [0.32, 0.62], [0.82, 0.62], [0.92, 0.3], [0.26, 0.3]]), color, w, true)
			ci.draw_circle(o + Vector2(0.38, 0.8) * s, s * 0.075, color)
			ci.draw_circle(o + Vector2(0.74, 0.8) * s, s * 0.075, color)
		&"ledger":
			ci.draw_rect(Rect2(o + Vector2(0.14, 0.08) * s, Vector2(0.5, 0.66) * s), color, false, w)
			for y in [0.24, 0.36, 0.48]:
				ci.draw_line(o + Vector2(0.24, y) * s, o + Vector2(0.54, y) * s, color, w * 0.7)
			ci.draw_rect(Rect2(o + Vector2(0.46, 0.6) * s, Vector2(0.22, 0.2) * s), color)
			ci.draw_rect(Rect2(o + Vector2(0.7, 0.6) * s, Vector2(0.22, 0.2) * s), color)
			ci.draw_rect(Rect2(o + Vector2(0.58, 0.4) * s, Vector2(0.22, 0.18) * s), color)
		&"tag":
			var tag := _pts(o, s, [[0.1, 0.3], [0.38, 0.06], [0.62, 0.1], [0.92, 0.48], [0.5, 0.92], [0.14, 0.58]])
			ci.draw_colored_polygon(tag, color)
			ci.draw_circle(o + Vector2(0.36, 0.26) * s, s * 0.06, Color(0, 0, 0, 0.75))
			ci.draw_arc(o + Vector2(0.55, 0.55) * s, s * 0.17, 0, TAU, 24, Color(0, 0, 0, 0.75), w * 0.8, true)
			ci.draw_line(o + Vector2(0.47, 0.49) * s, o + Vector2(0.63, 0.49) * s, Color(0, 0, 0, 0.75), w * 0.7)
			ci.draw_line(o + Vector2(0.55, 0.49) * s, o + Vector2(0.55, 0.66) * s, Color(0, 0, 0, 0.75), w * 0.7)
		&"chevron":
			ci.draw_polyline(_pts(o, s, [[0.3, 0.12], [0.7, 0.5], [0.3, 0.88]]), color, maxf(3.0, s * 0.16), true)
		&"chevron_left": # Sell's steppers: lower (left) and higher (chevron); never a "+" (no monetization look)
			ci.draw_polyline(_pts(o, s, [[0.7, 0.12], [0.3, 0.5], [0.7, 0.88]]), color, maxf(3.0, s * 0.16), true)
		&"back": # the header's thin "<" (references), not a heavy arrow
			ci.draw_polyline(_pts(o, s, [[0.62, 0.14], [0.3, 0.5], [0.62, 0.86]]), color, maxf(2.0, s * 0.075), true)
		&"close": # the header's thin X
			ci.draw_line(o + Vector2(0.18, 0.18) * s, o + Vector2(0.82, 0.82) * s, color, maxf(2.0, s * 0.075), true)
			ci.draw_line(o + Vector2(0.82, 0.18) * s, o + Vector2(0.18, 0.82) * s, color, maxf(2.0, s * 0.075), true)

## The T-stone coin (header counters, prices): a grey embossed coin with a raised rim and a "T",
## like the references' grey coin (a flat white ring read as a radio button). `bound` adds a small
## dark lock tag: bound T-stones pay fees but never buy.
static func coin(ci: CanvasItem, c: Vector2, r: float, bound: bool = false) -> void:
	ci.draw_circle(c + Vector2(r * 0.08, r * 0.1), r, Color(0, 0, 0, 0.45)) # drop shadow
	ci.draw_circle(c, r, Color(0.56, 0.56, 0.53))
	ci.draw_arc(c, r * 0.94, PI * 0.95, PI * 1.85, 16, Color(0.9, 0.9, 0.86), maxf(1.0, r * 0.14), true) # lit rim
	ci.draw_circle(c, r * 0.68, Color(0.66, 0.66, 0.63))
	ci.draw_arc(c, r * 0.68, 0, TAU, 24, Color(0.36, 0.36, 0.34), maxf(1.0, r * 0.08), true)
	var ink := Color(0.3, 0.3, 0.29)
	var bar := maxf(1.5, r * 0.16)
	ci.draw_rect(Rect2(c.x - r * 0.36, c.y - r * 0.4, r * 0.72, bar), ink)
	ci.draw_rect(Rect2(c.x - bar * 0.5, c.y - r * 0.4, bar, r * 0.82), ink)
	if bound:
		var lc := c + Vector2(r * 0.72, r * 0.62)
		var lw := r * 0.62
		ci.draw_rect(Rect2(lc - Vector2(lw * 0.5, lw * 0.15), Vector2(lw, lw * 0.75)), Color(0.12, 0.11, 0.09))
		ci.draw_arc(lc + Vector2(0, -lw * 0.15), lw * 0.3, PI, TAU, 10, Color(0.12, 0.11, 0.09), maxf(1.5, lw * 0.16), true)
		ci.draw_rect(Rect2(lc - Vector2(lw * 0.36, lw * 0.02), Vector2(lw * 0.72, lw * 0.48)), Color(0.85, 0.82, 0.7))

## Up and down triangles; the active direction (`dir` 1 = up / ascending, -1 = down) is bright.
static func sort_arrows(ci: CanvasItem, c: Vector2, h: float, dir: int, on: Color, off: Color) -> void:
	var hw := h * 0.32
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-hw, -h * 0.08), c + Vector2(hw, -h * 0.08), c + Vector2(0, -h * 0.5)]), on if dir == 1 else off)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-hw, h * 0.08), c + Vector2(hw, h * 0.08), c + Vector2(0, h * 0.5)]), on if dir == -1 else off)

## The reference's bonded badge: a dark disc with a white "B", drawn before the pet's name.
static func badge_b(ci: CanvasItem, c: Vector2, radius: float) -> void:
	ci.draw_circle(c, radius, Color(0.05, 0.05, 0.05, 0.9))
	ci.draw_arc(c, radius, 0, TAU, 24, Color(0.85, 0.84, 0.78, 0.7), 1.5, true)
	var size_px := maxi(UiTokens.TYPE_MIN, roundi(radius * 1.3))
	var f := MarketTheme.font()
	var tw := f.get_string_size("B", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	ci.draw_string(f, c + Vector2(-tw * 0.5, (f.get_ascent(size_px) - f.get_descent(size_px)) * 0.5), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, MarketTheme.ACTION)

static func _pts(o: Vector2, s: float, uv: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in uv:
		out.append(o + Vector2(p[0], p[1]) * s)
	return out
