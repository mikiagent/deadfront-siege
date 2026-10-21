class_name InvCarrierArt
extends SceneTree
## Paints the caged animal's bag art (review r1: no render exists for captured_animal, and its white
## symbol fallback read as an action glyph in a 2x2 compartment): a matte, outlined pet carrier like
## the Bag reference's crate, the animal behind the wire bars of its door.
## Signed-distance shapes with a one-pixel soft edge, a light painted grain. Writes the PNG the bag
## family draws (data/inv_ui.json "art"):
##   Godot --headless --path game --script res://scripts/dev/inv_carrier_art.gd
## then one --import. Deterministic: the same PNG every run.

const OUT := "res://assets/ui/inv/captured_animal.png"
const N := 256
const INK := Color("#26231C")
const SHELL := Color("#BDB59F")
const SHELL_DARK := Color("#8A826D")
const LID := Color("#A69D86")
const GRILLE_BACK := Color("#2C2923")
const BAR := Color("#CFC7B0")
const DINO := Color("#7E8A55") # a muted green: the animal is a thing, so it has colour

func _init() -> void:
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			img.set_pixel(x, y, _shade(Vector2(x, y) + Vector2(0.5, 0.5)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := img.save_png(OUT)
	print("[carrier] wrote %s err=%d used=%s" % [OUT, err, img.get_used_rect()])
	quit(0 if err == OK else 1)

## Back to front: shadow, handle, lid, body, the door (an animal behind its wire bars), vents, feet.
func _shade(p: Vector2) -> Color:
	var c := Color(0, 0, 0, 0)
	c = _over(c, Color(0, 0, 0, 0.28), _cover(_ellipse(p, Vector2(128, 222), Vector2(104, 12)), 3.0))
	c = _ink_fill(c, p, _ring(p, Vector2(128, 70), 30.0, 9.0) if p.y < 76.0 else 99.0, Color("#6F6754"))
	c = _ink_fill(c, p, _rbox(p, Rect2(38, 66, 180, 34), 12.0), LID.lerp(SHELL, clampf((90.0 - p.y) / 30.0, 0.0, 1.0) * 0.4))
	var body := _rbox(p, Rect2(28, 92, 200, 120), 16.0)
	c = _ink_fill(c, p, body, SHELL.lerp(SHELL_DARK, clampf((p.y - 100.0) / 110.0, 0.0, 1.0)))
	# The door: a dark opening in a raised frame, the animal inside, thin wire bars over it, a latch.
	var door := _rbox(p, Rect2(42, 104, 120, 96), 8.0)
	c = _over(c, SHELL_DARK.darkened(0.2), _cover(door - 5.0, 1.0))
	c = _ink_fill(c, p, door, GRILLE_BACK)
	if door < 0.0:
		var head := minf(p.distance_to(Vector2(112, 150)) - 22.0, _segment(p, Vector2(112, 160), Vector2(140, 168)) - 13.0)
		head = minf(head, _segment(p, Vector2(90, 200), Vector2(106, 160)) - 15.0) # the neck, down out of sight
		c = _over(c, DINO, _cover(head, 1.0))
		c = _over(c, DINO.darkened(0.35), _cover(absf(p.y - 150.0 - (p.x - 112.0) * 0.2) - 1.6, 1.0) * _cover(head + 6.0, 1.0)) # a stripe
		c = _over(c, INK, _cover(p.distance_to(Vector2(120, 146)) - 3.2, 1.0))
		for k in 8:
			var bx := 52.0 + k * 14.5
			c = _over(c, BAR.darkened(0.1 * float(k % 2)), _cover(absf(p.x - bx) - 1.6, 1.0))
	c = _ink_fill(c, p, _rbox(p, Rect2(156, 140, 14, 22), 3.0), Color("#7A725E"))
	for k in 3: # vents on the side
		c = _ink_fill(c, p, _rbox(p, Rect2(184, 118 + k * 22, 30, 8), 4.0), GRILLE_BACK)
	for fx in [52.0, 204.0]:
		c = _ink_fill(c, p, _rbox(p, Rect2(fx - 12.0, 208, 24, 10), 3.0), SHELL_DARK.darkened(0.3))
	if c.a > 0.0: # a light painted grain, so it sits with the rendered icons rather than read as vector
		var g := (_hash(floorf(p.x / 2.0), floorf(p.y / 2.0)) - 0.5) * 0.06
		c = Color(clampf(c.r + g, 0, 1), clampf(c.g + g, 0, 1), clampf(c.b + g, 0, 1), c.a)
	return c

## Fill `col` inside distance `d` with a 4 px ink outline around it.
func _ink_fill(c: Color, _p: Vector2, d: float, col: Color) -> Color:
	c = _over(c, INK, _cover(d - 4.0, 1.0))
	return _over(c, col, _cover(d, 1.0))

func _over(dst: Color, src: Color, cov: float) -> Color:
	var a := src.a * cov
	if a <= 0.0:
		return dst
	var out_a := a + dst.a * (1.0 - a)
	var rgb := (Vector3(src.r, src.g, src.b) * a + Vector3(dst.r, dst.g, dst.b) * dst.a * (1.0 - a)) / maxf(out_a, 0.0001)
	return Color(rgb.x, rgb.y, rgb.z, out_a)

func _cover(d: float, soft: float) -> float:
	return clampf(0.5 - d / soft, 0.0, 1.0)

func _rbox(p: Vector2, r: Rect2, rad: float) -> float:
	var c := r.get_center()
	var q := (p - c).abs() - r.size * 0.5 + Vector2(rad, rad)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - rad

func _ring(p: Vector2, c: Vector2, rad: float, w: float) -> float:
	return absf(p.distance_to(c) - rad) - w * 0.5

func _ellipse(p: Vector2, c: Vector2, r: Vector2) -> float:
	var q := (p - c) / r
	return (q.length() - 1.0) * minf(r.x, r.y)

func _segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length()

func _hash(x: float, y: float) -> float:
	var v := sin(x * 12.9898 + y * 78.233) * 43758.5453
	return v - floorf(v)
