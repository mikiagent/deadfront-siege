class_name RadialHold
extends RefCounted
## Holds the gather radial's solved layout against its node while the camera moves (CONTROLS B1).
## GatherRadial solved its layout every frame against the HUD, the survivor's nameplate and its own
## title, so while the camera followed a walk the hexes swapped sides and the title flipped above and
## below the plant (owner: "UI glitching up and down on resource nodes"). Now it solves when it opens;
## each frame the hexes, the title and the labels move with the anchor. Where that would push them onto
## the HUD, or further off the screen than SLACK px² beyond what the solve left, they move along one axis
## or hold still and the node slides under them; once they lag it by MAX_DRIFT px the radial solves
## again. Holding until the layout fails is the hysteresis: a jiggle at an edge cannot flip it back.

const SLACK := 1024.0  ## px² off the screen: a quarter of a 64 px hex
const MAX_DRIFT := 64.0  ## px the held layout may lag its node before it is solved again (one hex)

## True once a draw has picked the title and label boxes for the current solve: later draws reuse them.
var held := false
var _solved := false
var _last := Vector2.ZERO
var _drift := Vector2.ZERO
var _base := Vector2(-1.0, -1.0)  ## what the solve left: (px² off the screen, px² on the HUD)

## Forget the layout (the menu closed, or opens on another anchor).
func reset() -> void:
	held = false
	_solved = false

## The radial solved its layout around `anchor`; returns it.
func solved(anchor: Vector2) -> Vector2:
	_solved = true
	held = false
	_base = Vector2(-1.0, -1.0)
	_drift = Vector2.ZERO
	_last = anchor
	return anchor

## A draw picked the title and label boxes for this solve.
func picked() -> void:
	held = true

## Each frame, before the radial lays out: moves the hexes, title and labels with the anchor and returns
## true while they still fit; false when the radial must solve again (never solved, or out of space).
func follow(radial: GatherRadial, anchor: Vector2) -> bool:
	if not _solved:
		return false
	if not anchor.is_finite():
		return true  # a source behind the camera: keep what is up rather than shift it by NaN
	if not _last.is_finite():
		return false  # solved while it was: solve again now that it is on screen
	var d := anchor - _last
	_last = anchor
	if not held:
		_shift(radial, d)  # this frame's draw picks the labels; measure from the next frame
		return true
	var view := radial.get_viewport_rect().size
	var safe := UiTokens.safe_insets(radial.get_viewport())
	var bounds := Rect2(Vector2(safe.w, safe.z), view - Vector2(safe.w + safe.x, safe.z + safe.y))
	var hud := UiTokens.hud_reserved(view)
	if _base.x < 0.0:
		_base = spill(_parts(radial, Vector2.ZERO), bounds, hud)
	for t: Vector2 in [d, Vector2(d.x, 0.0), Vector2(0.0, d.y), Vector2.ZERO]:
		var cost := spill(_parts(radial, t), bounds, hud)
		if cost.x <= _base.x + SLACK and cost.y <= _base.y + 1.0:
			_shift(radial, t)
			_drift += d - t
			return _drift.length() <= MAX_DRIFT
	return false  # even holding still it spills (the view changed)

## The title, hexes and labels as they would be moved by `t`.
static func _parts(radial: GatherRadial, t: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = [Rect2(radial.title_box.position + t, radial.title_box.size)]
	for b in radial._buttons:
		out.append(Rect2(b.position + t, b.size))
	for r in radial.label_rects:
		out.append(Rect2(r.position + t, r.size))
	return out

static func _shift(radial: GatherRadial, t: Vector2) -> void:
	radial.title_box.position += t
	for b in radial._buttons:
		b.position += t
	for i in radial.label_rects.size():
		radial.label_rects[i].position += t

## (px² of `parts` outside `bounds`, px² of them on the `blocked` rects: the HUD).
static func spill(parts: Array[Rect2], bounds: Rect2, blocked: Array[Rect2]) -> Vector2:
	var out := Vector2.ZERO
	for r in parts:
		out.x += r.get_area() - r.intersection(bounds).get_area()
		for b in blocked:
			out.y += r.intersection(b).get_area()
	return out
