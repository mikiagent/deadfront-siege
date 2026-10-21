class_name InvGlyphs
extends RefCounted
## White procedural glyphs for the bag toolbar that the white icon set (data/ui_icons.json) has no
## drawing for: multi-select (a ticked box), select all (a grid of dots with a tick), filter (a funnel),
## the storage rail's All (four squares), the Auto Sort dropdown caret and the in-game Bag's trash.
## White polylines, so they read as actions (GAUNTLET: colour = things, white = actions); thin outlines
## at about half the square, as Durango's toolbar draws them (review r1: ours were heavy and solid).

const WHITE := Color(1, 1, 1, 0.92)

## A square with a tick, offset like Durango's select toggle.
static func select(ci: CanvasItem, r: Rect2, on: bool = false) -> void:
	var s := minf(r.size.x, r.size.y) * 0.5
	var o := r.get_center() - Vector2(s, s) * 0.5
	var w := maxf(1.5, s * 0.07)
	ci.draw_polyline(PackedVector2Array([o + Vector2(s * 0.62, s * 0.08), o + Vector2(s * 0.08, s * 0.08),
		o + Vector2(s * 0.08, s * 0.92), o + Vector2(s * 0.92, s * 0.92), o + Vector2(s * 0.92, s * 0.5)]), WHITE, w)
	ci.draw_polyline(PackedVector2Array([o + Vector2(s * 0.28, s * 0.48), o + Vector2(s * 0.5, s * 0.7), o + Vector2(s, s * 0.08)]), InvTheme.SELECT if on else WHITE, w * 1.2)

## A 3x3 grid of dots with a tick over its corner: select every item shown (storage reference).
static func select_all(ci: CanvasItem, r: Rect2) -> void:
	var s := minf(r.size.x, r.size.y) * 0.5
	var o := r.get_center() - Vector2(s, s) * 0.5
	var d := s * 0.2
	for y in 3:
		for x in 3:
			if x + y < 4: # the bottom-right corner is the tick's
				ci.draw_rect(Rect2(o + Vector2(x, y) * s * 0.36, Vector2(d, d)), WHITE)
	var w := maxf(1.5, s * 0.08)
	ci.draw_polyline(PackedVector2Array([o + Vector2(s * 0.6, s * 0.86), o + Vector2(s * 0.78, s * 1.02), o + Vector2(s * 1.08, s * 0.66)]), WHITE, w)

## Four squares: the storage rail's All filter.
static func grid(ci: CanvasItem, r: Rect2, color: Color = WHITE) -> void:
	var s := minf(r.size.x, r.size.y) * 0.44
	var o := r.get_center() - Vector2(s, s) * 0.5
	var g := s * 0.16
	var q := (s - g) * 0.5
	for k in 4:
		ci.draw_rect(Rect2(o + Vector2(k % 2, k / 2) * (q + g), Vector2(q, q)), color)

## A funnel: wide top, narrow stem, in outline (filled gold while a filter is on).
static func funnel(ci: CanvasItem, r: Rect2, on: bool = false) -> void:
	var s := minf(r.size.x, r.size.y) * 0.5
	var o := r.get_center() - Vector2(s, s) * 0.5
	var pts := PackedVector2Array([o + Vector2(0, s * 0.06), o + Vector2(s, s * 0.06), o + Vector2(s * 0.6, s * 0.52),
		o + Vector2(s * 0.6, s * 0.94), o + Vector2(s * 0.4, s * 0.8), o + Vector2(s * 0.4, s * 0.52)])
	if on:
		ci.draw_colored_polygon(pts, InvTheme.SELECT)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, WHITE, maxf(1.5, s * 0.07), true)

## The upward caret on the Auto Sort dropdown segment.
static func caret(ci: CanvasItem, r: Rect2) -> void:
	var s := minf(r.size.x, r.size.y) * 0.32
	var c := r.get_center()
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, s * 0.45), c + Vector2(s, s * 0.45), c + Vector2(0, -s * 0.55)]), WHITE)

## A pendant on a cord, filled and soft-edged: the empty accessory cell's silhouette (no accessory art
## exists yet), in the spirit of the reference's faded heart (review r1: a hard outline ring read as UI).
static func amulet(ci: CanvasItem, r: Rect2, color: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var c := r.get_center()
	ci.draw_arc(c - Vector2(0, s * 0.12), s * 0.34, PI * 0.15, PI * 0.85, 24, color, maxf(2.0, s * 0.05), true)
	var drop := c + Vector2(0, s * 0.2)
	var rad := s * 0.2
	var pts := PackedVector2Array()
	for k in 25: # a teardrop: round below, a point up toward the cord
		var a := PI * 0.5 + TAU * float(k) / 24.0
		var p := drop + Vector2(cos(a), sin(a)) * rad
		p.y -= maxf(0.0, -sin(a)) * rad * 0.7 * maxf(0.0, 1.0 - absf(cos(a)) * 1.6)
		pts.append(p)
	ci.draw_colored_polygon(pts, color)
	ci.draw_polyline(pts, Color(color, color.a * 0.6), 2.0, true) # an antialiased edge, not a ruled one

## A target with an arrow: Accuracy on My Info (the icon set has attack and defense, no accuracy).
static func target(ci: CanvasItem, r: Rect2, color: Color = WHITE) -> void:
	var rad := minf(r.size.x, r.size.y) * 0.42
	var c := r.get_center() + Vector2(rad * 0.15, 0)
	var w := maxf(2.0, rad * 0.14)
	ci.draw_arc(c, rad, 0.0, TAU, 40, color, w, true)
	ci.draw_arc(c, rad * 0.55, 0.0, TAU, 32, color, w, true)
	ci.draw_circle(c, rad * 0.18, color)
	ci.draw_line(c - Vector2(rad * 1.25, rad * 0.12), c, color, w * 0.8, true)

## The thin ">" after a power row (opens Detailed Stats there).
static func chevron(ci: CanvasItem, r: Rect2, color: Color) -> void:
	var c := r.get_center()
	var h := minf(r.size.x, r.size.y) * 0.22
	ci.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.4, -h), c + Vector2(h * 0.45, 0), c + Vector2(-h * 0.4, h)]), color, maxf(2.0, h * 0.18), true)

## A bin with its lid: the in-game Bag's discard square (the icon set has no trash).
static func trash(ci: CanvasItem, r: Rect2, color: Color = WHITE) -> void:
	var s := minf(r.size.x, r.size.y) * 0.5
	var o := r.get_center() - Vector2(s, s) * 0.5
	var w := maxf(1.5, s * 0.07)
	ci.draw_line(o + Vector2(0, s * 0.16), o + Vector2(s, s * 0.16), color, w)
	ci.draw_polyline(PackedVector2Array([o + Vector2(s * 0.36, s * 0.16), o + Vector2(s * 0.36, 0), o + Vector2(s * 0.64, 0), o + Vector2(s * 0.64, s * 0.16)]), color, w * 0.8)
	ci.draw_polyline(PackedVector2Array([o + Vector2(s * 0.12, s * 0.28), o + Vector2(s * 0.2, s), o + Vector2(s * 0.8, s), o + Vector2(s * 0.88, s * 0.28)]), color, w)
	for fx in [0.38, 0.62]:
		ci.draw_line(o + Vector2(s * fx, s * 0.4), o + Vector2(s * fx, s * 0.86), color, w * 0.8)
