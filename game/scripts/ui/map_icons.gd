class_name MapIcons
extends RefCounted
## Map symbols (spec 15 legend + spec 25): a house for a claim, a flame for campfires/bonfires, a
## crossed hammer for trade/craft/quest facilities, an anchor for the harbour, grey dots for other
## survivors and black dots for the walked trail. Drawn with the CanvasItem's own draw calls so they
## stay crisp at any zoom and need no textures.
##
## All radii are in map pixels; the caller passes its icon size (>= 22 px on the atlas, >= 7 px on
## the minimap). Icons never carry their own tap target: the atlas picks the icon under the finger
## from a list and the touch slop is added there.

## Kind -> the size multiplier used where a caller wants every icon on one row.
const KINDS := ["claim", "campfire", "facility", "harbour", "camp", "crater", "other"]

static func claim(ci: CanvasItem, at: Vector2, r: float, col: Color, ring: Color) -> void:
	# House: a gable roof over a body, with a door notch. r is the half-width.
	var body := Rect2(at + Vector2(-r * 0.72, -r * 0.05), Vector2(r * 1.44, r * 1.0))
	ci.draw_rect(body, col)
	ci.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-r, -r * 0.02), at + Vector2(0, -r * 0.95), at + Vector2(r, -r * 0.02)]), col)
	var door := Rect2(at + Vector2(-r * 0.22, r * 0.42), Vector2(r * 0.44, r * 0.53))
	ci.draw_rect(door, Color(0.08, 0.06, 0.05, 0.9))
	ci.draw_rect(body.grow(1.0).merge(Rect2(at + Vector2(-r, -r * 0.95), Vector2(r * 2.0, r * 2.0))), ring, false, maxf(1.0, r * 0.12))

static func flame(ci: CanvasItem, at: Vector2, r: float, col: Color, ring: Color) -> void:
	ci.draw_circle(at + Vector2(0, r * 0.15), r * 1.15, ring)
	var tongue := PackedVector2Array([
		at + Vector2(-r * 0.62, r * 0.55), at + Vector2(-r * 0.30, -r * 0.10),
		at + Vector2(0, -r * 0.95), at + Vector2(r * 0.32, -r * 0.05),
		at + Vector2(r * 0.62, r * 0.55)])
	ci.draw_colored_polygon(tongue, col)
	ci.draw_circle(at + Vector2(0, r * 0.42), r * 0.34, Color(1.0, 0.72, 0.22))

static func facility(ci: CanvasItem, at: Vector2, r: float, col: Color, ring: Color) -> void:
	# A workshop mark: a square sign with a hammer across it.
	var box := Rect2(at - Vector2(r * 0.9, r * 0.9), Vector2(r * 1.8, r * 1.8))
	ci.draw_rect(box, ring)
	ci.draw_rect(box.grow(-maxf(1.0, r * 0.2)), col)
	ci.draw_line(at + Vector2(-r * 0.55, r * 0.55), at + Vector2(r * 0.55, -r * 0.55), Color(0.06, 0.12, 0.10, 0.9), maxf(1.2, r * 0.28))
	ci.draw_line(at + Vector2(r * 0.1, -r * 0.62), at + Vector2(r * 0.62, -r * 0.1), Color(0.06, 0.12, 0.10, 0.9), maxf(1.2, r * 0.28))

static func anchor(ci: CanvasItem, at: Vector2, r: float, col: Color, ring: Color) -> void:
	ci.draw_circle(at + Vector2(0, -r * 0.6), r * 0.34, col)
	ci.draw_line(at, at + Vector2(0, r * 0.85), col, maxf(1.4, r * 0.22))
	ci.draw_line(at + Vector2(-r * 0.9, r * 0.35), at + Vector2(r * 0.9, r * 0.35), col, maxf(1.4, r * 0.22))
	ci.draw_arc(at, r * 0.75, 0.25, PI - 0.25, 12, col, maxf(1.4, r * 0.22))

static func dot(ci: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(at, r, col)

## A trail: black dots at each recorded step.
static func trail(ci: CanvasItem, pts: Array, radius: float = 1.8) -> void:
	var col := Color(0.04, 0.04, 0.04, 0.9)
	for p in pts:
		ci.draw_circle(p as Vector2, radius, col)
