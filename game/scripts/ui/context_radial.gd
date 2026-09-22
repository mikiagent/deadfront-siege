class_name ContextRadial
extends RefCounted
## One hex layout for gather, tame and station entry.
## The anchor is the source; outer hexes stay inside the safe rect, flipping when they would clip.

const HEX := 64.0

## Top-left positions for `count` hexes around `anchor`.
static func hex_positions(anchor: Vector2, count: int, view: Vector2, safe: Vector4, hex: float = HEX) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions
	var radius := hex * 0.55 + 40.0
	if count > 4:
		radius = hex * 0.65 + 56.0
	var trial := _arc(anchor, count, hex, radius, 1.0)
	if not _fits(trial, hex, view, safe):
		trial = _arc(anchor, count, hex, radius, -1.0)
	var min_x := safe.w
	var min_y := safe.z
	var max_x := maxf(min_x, view.x - safe.x - hex)
	var max_y := maxf(min_y, view.y - safe.y - hex)
	for p in trial:
		positions.append(Vector2(clampf(p.x, min_x, max_x), clampf(p.y, min_y, max_y)))
	return positions

static func label_on_left(hex_pos: Vector2, hex: float, view: Vector2) -> bool:
	return hex_pos.x + hex * 0.5 > view.x * 0.62

static func _arc(anchor: Vector2, count: int, hex: float, radius: float, side: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	# side > 0 fans toward the upper right; side < 0 fans toward the lower left.
	var start := -0.9 if side > 0.0 else 1.4
	var span := 1.6
	for i in count:
		var t := 0.5 if count <= 1 else float(i) / float(count - 1)
		var ang := start + span * t
		var center := anchor + Vector2(cos(ang), sin(ang)) * radius
		out.append(center - Vector2(hex, hex) * 0.5)
	return out

static func _fits(positions: Array[Vector2], hex: float, view: Vector2, safe: Vector4) -> bool:
	var bounds := Rect2(Vector2(safe.w, safe.z), Vector2(maxf(1.0, view.x - safe.x - safe.w), maxf(1.0, view.y - safe.y - safe.z)))
	for p in positions:
		if not bounds.encloses(Rect2(p, Vector2(hex, hex)).grow(-1.0)):
			return false
	return true
