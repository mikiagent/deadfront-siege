class_name ContextRadial
extends RefCounted
## One hex layout for gather, tame and station entry.
## The anchor is the source; the ring turns as a whole to stay inside the safe rect and off the
## HUD, and only when no turn fits does the whole ring slide in. Clamping each hex on its own
## stacked them on one spot when the anchor sat above the view.

const HEX := 64.0
const TURN_STEPS := 24

## Top-left positions for `count` hexes on a ring around `anchor` (Durango tree wheel: the
## source name sits in the middle, hexes surround it, labels face outward). `clear_w` is the
## width of the centred title so the ring radius keeps the hexes off it. `avoid` are screen rects
## the hexes should stay off (UiTokens.hud_reserved). With `label_w`, each hex's outward label slot
## must stay off them too (and off the other hexes): a ring with its hexes clear still put a label
## on the plant or into the HUD column on a small landscape phone.
static func hex_positions(anchor: Vector2, count: int, view: Vector2, safe: Vector4, hex: float = HEX, clear_w: float = 0.0, avoid: Array[Rect2] = [], label_w: float = 0.0) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions
	# A NaN anchor (a source behind the camera) scored NaN on every turn and returned nothing,
	# leaving the hexes where they last were; centre the ring instead.
	if not anchor.is_finite():
		anchor = view * 0.5
	var radius := maxf(hex * 0.55 + 40.0, hex * 1.5)
	if count > 4:
		radius = maxf(radius, float(count) * hex * 1.08 / TAU)
	# horizontal slots must clear the title band: hex inner edge outside the title half-width
	radius = maxf(radius, clear_w * 0.5 + hex * 0.5 + 16.0)
	# A huge finite anchor (unproject_position near the camera plane) lost float precision and
	# stacked the hexes; past one ring off the view it slides in the same anyway.
	var reach := Vector2.ONE * (radius + hex)
	anchor = anchor.clamp(-reach, view + reach)
	var angles: Array[float] = []
	if count == 1:
		angles = [-0.55]
	elif count == 2:
		angles = [-0.9, 0.9]  # upper right, lower right
	else:
		for i in count:
			angles.append(-0.55 + TAU * float(i) / float(count))
	var bounds := Rect2(Vector2(safe.w, safe.z), Vector2(maxf(hex, view.x - safe.w - safe.x), maxf(hex, view.y - safe.z - safe.y)))
	# Try the preferred layout, then turn it a step either way, nearest turns first.
	var best: Array[Vector2] = []
	var best_score := INF
	for k in TURN_STEPS:
		var step := ((k + 1) >> 1) * (1 if k % 2 == 1 else -1)
		var turn := TAU * float(step) / float(TURN_STEPS)
		var ring := _ring(anchor, angles, turn, radius, hex)
		var score := _overflow(ring, hex, bounds) * 1000.0 + _overlap(ring, hex, avoid)
		if label_w > 0.0:
			score += _label_cover(ring, hex, anchor, view, label_w, avoid)
		if score <= 0.0:
			return ring
		if score < best_score:
			best_score = score
			best = ring
	# Nothing fits as is (anchor near or past an edge): slide the best ring in, keeping its shape.
	if best.is_empty():  # no finite score at all: the unturned ring
		best = _ring(anchor, angles, 0.0, radius, hex)
	return _slide_inside(best, hex, bounds)

static func _ring(anchor: Vector2, angles: Array[float], turn: float, radius: float, hex: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for ang in angles:
		out.append(anchor + Vector2(cos(ang + turn), sin(ang + turn)) * radius - Vector2(hex, hex) * 0.5)
	return out

## Pixels of hex area outside the bounds, summed.
static func _overflow(ring: Array[Vector2], hex: float, bounds: Rect2) -> float:
	var total := 0.0
	for p in ring:
		var r := Rect2(p, Vector2(hex, hex))
		total += r.get_area() - r.intersection(bounds).get_area()
	return total

static func _overlap(ring: Array[Vector2], hex: float, avoid: Array[Rect2]) -> float:
	var total := 0.0
	for p in ring:
		var r := Rect2(p, Vector2(hex, hex))
		for a in avoid:
			total += r.intersection(a).get_area()
	return total

## Area of the outward label slots (as GatherRadial.label_rect places them) off screen, on `avoid`
## or on another hex.
static func _label_cover(ring: Array[Vector2], hex: float, anchor: Vector2, view: Vector2, label_w: float, avoid: Array[Rect2]) -> float:
	var total := 0.0
	for p in ring:
		var left := label_on_left(p, hex, view, anchor)
		var x := p.x - label_w - 14.0 if left else p.x + hex + 8.0
		var r := Rect2(Vector2(x - 4.0, p.y + hex * 0.5 - 14.0), Vector2(label_w + 12.0, 26.0))
		total += r.get_area() - r.intersection(Rect2(Vector2.ZERO, view)).get_area()
		for a in avoid:
			total += r.intersection(a).get_area()
		for q in ring:
			total += r.intersection(Rect2(q, Vector2(hex, hex))).get_area()
	return total

static func _slide_inside(ring: Array[Vector2], hex: float, bounds: Rect2) -> Array[Vector2]:
	if ring.is_empty():
		return ring
	var box := Rect2(ring[0], Vector2(hex, hex))
	for p in ring:
		box = box.merge(Rect2(p, Vector2(hex, hex)))
	var shift := Vector2.ZERO
	if box.size.x <= bounds.size.x:
		shift.x = clampf(box.position.x, bounds.position.x, bounds.end.x - box.size.x) - box.position.x
	else:
		shift.x = bounds.get_center().x - box.get_center().x
	if box.size.y <= bounds.size.y:
		shift.y = clampf(box.position.y, bounds.position.y, bounds.end.y - box.size.y) - box.position.y
	else:
		shift.y = bounds.get_center().y - box.get_center().y
	var out: Array[Vector2] = []
	for p in ring:
		out.append(p + shift)
	return out

## Labels face away from the ring centre; without an anchor fall back to the screen side.
static func label_on_left(hex_pos: Vector2, hex: float, view: Vector2, anchor: Vector2 = Vector2(-1, -1)) -> bool:
	if anchor.x >= 0.0:
		return hex_pos.x + hex * 0.5 < anchor.x - 1.0
	return hex_pos.x + hex * 0.5 > view.x * 0.62
