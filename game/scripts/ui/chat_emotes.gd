class_name ChatEmotes
extends RefCounted
## The region chat's white emote stickers (spec 20: "an emote sticker (white smiley or skull)").
## A sticker travels as an ordinary chat line whose whole text is one code below, so the server's
## text rules (NetChat) cover it and an old client shows the code as text.
# ASSUMPTION: the docs name no sticker set; these eight, drawn in code (no image assets), are ours.

const CODES: Array[String] = [":smile:", ":laugh:", ":wink:", ":wow:", ":sad:", ":angry:", ":skull:", ":heart:"]
const INK := Color(0.07, 0.07, 0.08)

static func is_emote(text: String) -> bool:
	return text in CODES

## Draws the sticker for `code` centred in `r` (square-ish), white with dark features.
static func draw(ci: CanvasItem, code: String, r: Rect2) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.5  # radius
	var w := maxf(1.5, s * 0.14)  # feature stroke
	match code:
		":heart:":
			var pts := PackedVector2Array()
			for i in 48:
				var t := TAU * float(i) / 48.0
				# The classic heart curve, scaled to the radius.
				var x := 16.0 * pow(sin(t), 3.0)
				var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
				pts.append(c + Vector2(x, -y - 1.5) * (s / 17.0))
			ci.draw_colored_polygon(pts, Color.WHITE)
			return
		":skull:":
			ci.draw_circle(c + Vector2(0, -s * 0.12), s * 0.82, Color.WHITE)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.46, s * 0.3), Vector2(s * 0.92, s * 0.6)), Color.WHITE)
			for e in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(e * s * 0.33, -s * 0.05), s * 0.24, INK)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.2), c + Vector2(-s * 0.1, s * 0.4), c + Vector2(s * 0.1, s * 0.4)]), INK)
			for x in [-0.22, 0.0, 0.22]:
				ci.draw_line(c + Vector2(x * s, s * 0.62), c + Vector2(x * s, s * 0.9), INK, w * 0.8)
			return
	ci.draw_circle(c, s * 0.92, Color.WHITE)
	var eye_y := -s * 0.2
	var eye := s * 0.13
	match code:
		":laugh:":
			for e in [-1.0, 1.0]:
				ci.draw_polyline(_arc(c + Vector2(e * s * 0.32, eye_y + s * 0.06), s * 0.14, PI, TAU), INK, w)
			var mouth := _arc(c + Vector2(0, s * 0.12), s * 0.46, 0.0, PI)
			ci.draw_colored_polygon(mouth, INK)
		":wink:":
			ci.draw_circle(c + Vector2(-s * 0.32, eye_y), eye, INK)
			ci.draw_line(c + Vector2(s * 0.18, eye_y), c + Vector2(s * 0.46, eye_y), INK, w)
			ci.draw_polyline(_arc(c + Vector2(0, s * 0.05), s * 0.45, 0.35, PI - 0.35), INK, w)
		":wow:":
			for e in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(e * s * 0.32, eye_y), eye, INK)
			ci.draw_circle(c + Vector2(0, s * 0.38), s * 0.2, INK)
		":sad:":
			for e in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(e * s * 0.32, eye_y), eye, INK)
			ci.draw_polyline(_arc(c + Vector2(0, s * 0.78), s * 0.42, PI + 0.5, TAU - 0.5), INK, w)
		":angry:":
			for e in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(e * s * 0.32, eye_y + s * 0.05), eye, INK)
				ci.draw_line(c + Vector2(e * s * 0.52, eye_y - s * 0.22), c + Vector2(e * s * 0.12, eye_y - s * 0.06), INK, w)
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.45), c + Vector2(s * 0.3, s * 0.45), INK, w)
		_:  # :smile: and any unknown code
			for e in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(e * s * 0.32, eye_y), eye, INK)
			ci.draw_polyline(_arc(c + Vector2(0, s * 0.02), s * 0.48, 0.3, PI - 0.3), INK, w)

static func _arc(c: Vector2, r: float, from: float, to: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(from, to, float(i) / 16.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

## A sticker as a control: list rows and the picker use it.
class Sticker extends Control:
	var code := ""
	func _init(p_code: String, side: float) -> void:
		code = p_code
		custom_minimum_size = Vector2(side, side)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		ChatEmotes.draw(self, code, Rect2(Vector2.ZERO, size))
