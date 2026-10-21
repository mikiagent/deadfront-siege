class_name MarketGlyphs
extends RefCounted
## The market's own glyphs, drawn with draw_* so they stay crisp at any size: the rail's cart /
## ledger / price tag, sort arrows, the category and stepper chevrons, the bonded "B" badge, the
## T-stone coin and its lock, and the pet carrier / crate while those have no rendered icon.
# ASSUMPTION (exchange-spec A9): drawn in-package, not added to ui_icons.json (W1-UIICONS' gated set).

const ACTION_WHITE := Color(1, 1, 1)

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

## The T-stone coin (header counters, prices): the references' grey metal coin seen a little from
## above: a dark edge under it, a lit rim, a recessed face ringed in shadow and an engraved "T".
static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(r * 0.1, r * 0.2), r, Color(0, 0, 0, 0.4)) # drop shadow
	ci.draw_circle(c + Vector2(0, r * 0.12), r, Color(0.3, 0.3, 0.28)) # the coin's edge
	ci.draw_circle(c, r, Color(0.6, 0.6, 0.57))
	ci.draw_arc(c, r * 0.9, PI * 0.95, PI * 1.85, 16, Color(0.88, 0.88, 0.84), maxf(1.0, r * 0.16), true) # lit rim
	ci.draw_circle(c, r * 0.66, Color(0.47, 0.47, 0.45))
	ci.draw_arc(c, r * 0.66, PI * 0.1, PI * 0.9, 12, Color(0.78, 0.78, 0.74), maxf(1.0, r * 0.08), true) # the recess's lit lower lip
	var ink := Color(0.2, 0.2, 0.19)
	var bar := maxf(1.5, r * 0.17)
	ci.draw_rect(Rect2(c.x - r * 0.36, c.y - r * 0.38, r * 0.72, bar), ink)
	ci.draw_rect(Rect2(c.x - bar * 0.5, c.y - r * 0.38, bar, r * 0.78), ink)

## Bound T-stones: a white padlock on a dark disc of radius `r` (laid over the coin's corner).
static func lock(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color(0.05, 0.05, 0.045))
	ci.draw_arc(c, r, 0, TAU, 20, Color(0.55, 0.55, 0.5, 0.9), maxf(1.0, r * 0.1), true)
	var body := Rect2(c.x - r * 0.48, c.y - r * 0.12, r * 0.96, r * 0.7)
	ci.draw_arc(c + Vector2(0, -r * 0.14), r * 0.3, PI, TAU, 10, ACTION_WHITE, maxf(1.5, r * 0.16), true)
	ci.draw_rect(body, ACTION_WHITE)
	ci.draw_rect(Rect2(c.x - r * 0.06, body.position.y + body.size.y * 0.3, r * 0.12, body.size.y * 0.4), Color(0.05, 0.05, 0.045))

## The chip's close mark: a thin X filling `r` (the whole chip is the target).
static func cross(ci: CanvasItem, r: Rect2, color: Color) -> void:
	var w := maxf(1.5, r.size.x * 0.12)
	ci.draw_line(r.position, r.end, color, w, true)
	ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), color, w, true)

## A pet carrier (bonded pet) or a closed slatted crate (captured animal), the references' grey
## icons, in `r`; `mod` dims a refused cell. Drawn by the market only while the item has no
## rendered icon (ItemArt.is_rendered): today the symbol fallback for both is one wireframe cage.
# swap: drop this once ICONS2 / CAGEICON's renders are in the base (ItemArt picks them up by id).
static func cage(ci: CanvasItem, id: StringName, r: Rect2, mod: Color = Color.WHITE) -> void:
	var s := minf(r.size.x, r.size.y)
	var o := r.get_center() - Vector2(s, s) * 0.5
	var crate := id == &"captured_animal"
	# A box seen from the front-left: top, front (left, the carrier's door end) and side (right) faces.
	var top := _pts(o, s, [[0.06, 0.36], [0.6, 0.22], [0.95, 0.32], [0.4, 0.46]] if not crate else [[0.08, 0.34], [0.5, 0.22], [0.94, 0.33], [0.52, 0.47]])
	var front := PackedVector2Array([top[0], top[3], top[3] + Vector2(0, s * 0.42), top[0] + Vector2(0, s * 0.38)])
	var side := PackedVector2Array([top[3], top[2], top[2] + Vector2(0, s * 0.4), top[3] + Vector2(0, s * 0.42)])
	var base := Color(0.6, 0.58, 0.53) if crate else Color(0.72, 0.71, 0.67) # weathered wood / grey plastic
	var line := Color(0.17, 0.16, 0.14, mod.a)
	ci.draw_colored_polygon(PackedVector2Array([front[3], side[3], side[2], side[2] + Vector2(s * 0.04, s * 0.03), side[3] + Vector2(0, s * 0.07), front[3] + Vector2(-s * 0.03, s * 0.03)]), Color(0, 0, 0, 0.3 * mod.a)) # ground shadow
	ci.draw_colored_polygon(top, _shade(base, 1.18, mod))
	ci.draw_colored_polygon(front, _shade(base, 0.82, mod))
	ci.draw_colored_polygon(side, _shade(base, 1.0, mod))
	var w := maxf(1.0, s * 0.022)
	if crate:
		for k in [0.25, 0.5, 0.75]: # slat gaps across every face
			ci.draw_line(_lerp(top[0], top[3], k), _lerp(top[1], top[2], k), line, w, true)
			ci.draw_line(_lerp(front[0], front[3], k), _lerp(front[1], front[2], k), line, w, true)
			ci.draw_line(_lerp(side[0], side[3], k), _lerp(side[1], side[2], k), line, w, true)
		for e: Array in [[front[0], front[3]], [front[1], front[2]], [side[1], side[2]]]: # corner posts
			ci.draw_line(e[0] + Vector2(s * 0.035, 0), e[1] + Vector2(s * 0.035, 0), Color(0.3, 0.27, 0.22, mod.a), s * 0.06)
	else:
		# The carrier's tray: the lower half of each face a shade darker under the shell's seam.
		ci.draw_colored_polygon(PackedVector2Array([_lerp(front[0], front[3], 0.6), _lerp(front[1], front[2], 0.6), front[2], front[3]]), _shade(base, 0.7, mod))
		ci.draw_colored_polygon(PackedVector2Array([_lerp(side[0], side[3], 0.6), _lerp(side[1], side[2], 0.6), side[2], side[3]]), _shade(base, 0.88, mod))
		var door := PackedVector2Array([_lerp(_lerp(front[0], front[1], 0.14), _lerp(front[3], front[2], 0.14), 0.12), _lerp(_lerp(front[0], front[1], 0.86), _lerp(front[3], front[2], 0.86), 0.12),
			_lerp(_lerp(front[0], front[1], 0.86), _lerp(front[3], front[2], 0.86), 0.88), _lerp(_lerp(front[0], front[1], 0.14), _lerp(front[3], front[2], 0.14), 0.88)])
		ci.draw_colored_polygon(door, Color(0.16, 0.15, 0.13, mod.a)) # the grille door
		for k in [0.16, 0.32, 0.48, 0.64, 0.8]:
			ci.draw_line(_lerp(door[0], door[1], k), _lerp(door[3], door[2], k), _shade(base, 0.95, mod), w * 1.4, true)
		ci.draw_polyline(door + PackedVector2Array([door[0]]), _shade(base, 1.05, mod), w * 1.8, true)
		var wc := (side[0] + side[1] + side[2] + side[3]) * 0.25 + Vector2(0, -s * 0.02) # the round side window
		ci.draw_set_transform(wc, -0.25, Vector2(0.8, 1.0))
		ci.draw_circle(Vector2.ZERO, s * 0.11, Color(0.2, 0.19, 0.17, mod.a))
		ci.draw_circle(Vector2(s * 0.015, s * 0.02), s * 0.045, _shade(base, 0.6, mod)) # someone inside
		ci.draw_arc(Vector2.ZERO, s * 0.11, 0, TAU, 24, _shade(base, 1.15, mod), w * 2.2, true)
		ci.draw_set_transform(Vector2.ZERO)
		ci.draw_line(_lerp(front[0], front[3], 0.6), _lerp(front[1], front[2], 0.6), line, w, true) # the shell's seam
		ci.draw_line(_lerp(side[0], side[3], 0.6), _lerp(side[1], side[2], 0.6), line, w, true)
		for k in [0.3, 0.45, 0.6, 0.75]: # vent slots along the lid
			var a := _lerp(top[0], top[3], 0.5).lerp(_lerp(top[1], top[2], 0.5), k)
			ci.draw_line(a + (top[1] - top[0]) * 0.12, a - (top[1] - top[0]) * 0.12, line, w, true)
		var hc := (top[0] + top[1] + top[2] + top[3]) * 0.25 # the carry handle, arching over the lid
		ci.draw_polyline(PackedVector2Array([hc + (top[0] - top[3]) * 0.22, hc + (top[0] - top[3]) * 0.22 + Vector2(0, -s * 0.1), hc + (top[2] - top[3]) * 0.22 + Vector2(0, -s * 0.12), hc + (top[2] - top[3]) * 0.22]), _shade(base, 0.45, mod), s * 0.035, true)
	for face in [top, front, side]:
		ci.draw_polyline(face + PackedVector2Array([face[0]]), line, w, true)

static func _shade(c: Color, k: float, mod: Color) -> Color:
	return Color(c.r * k, c.g * k, c.b * k) * mod

static func _lerp(a: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(b, t)

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
