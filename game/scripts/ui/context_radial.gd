class_name ContextRadial
extends RefCounted
## One hex layout for gather, tame and station entry.
## The anchor is the source; outer hexes stay inside the safe rect, flipping when they would clip.

const HEX := 64.0

## Top-left positions for `count` hexes on a ring around `anchor` (Durango tree wheel: the
## source name sits in the middle, hexes surround it, labels face outward). `clear_w` is the
## width of the centred title so the ring radius keeps the hexes off it.
static func hex_positions(anchor: Vector2, count: int, view: Vector2, safe: Vector4, hex: float = HEX, clear_w: float = 0.0) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions
	var radius := maxf(hex * 0.55 + 40.0, hex * 1.5)
	if count > 4:
		radius = maxf(radius, float(count) * hex * 1.08 / TAU)
	# horizontal slots must clear the title band: hex inner edge outside the title half-width
	radius = maxf(radius, clear_w * 0.5 + hex * 0.5 + 16.0)
	var angles: Array[float] = []
	if count == 1:
		angles = [-0.55]
	elif count == 2:
		angles = [-0.9, 0.9]  # upper right, lower right
	else:
		for i in count:
			angles.append(-0.55 + TAU * float(i) / float(count))
	var min_x := safe.w
	var min_y := safe.z
	var max_x := maxf(min_x, view.x - safe.x - hex)
	var max_y := maxf(min_y, view.y - safe.y - hex)
	for ang in angles:
		var center := anchor + Vector2(cos(ang), sin(ang)) * radius
		var p := center - Vector2(hex, hex) * 0.5
		positions.append(Vector2(clampf(p.x, min_x, max_x), clampf(p.y, min_y, max_y)))
	return positions

## Labels face away from the ring centre; without an anchor fall back to the screen side.
static func label_on_left(hex_pos: Vector2, hex: float, view: Vector2, anchor: Vector2 = Vector2(-1, -1)) -> bool:
	if anchor.x >= 0.0:
		return hex_pos.x + hex * 0.5 < anchor.x - 1.0
	return hex_pos.x + hex * 0.5 > view.x * 0.62
