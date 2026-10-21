class_name RadialHold
extends RefCounted
## Holds the gather radial's solved layout against its node while the camera moves (CONTROLS B1).
## GatherRadial solved its layout every frame against the HUD, the survivor's nameplate and its own
## title, so while the camera followed a walk the hexes swapped sides and the title flipped above and
## below the plant (owner: "UI glitching up and down on resource nodes"). Now it solves when it opens;
## each frame the hexes, the title and the labels move with the anchor, and it solves again only when
## the held layout has run out of screen: parts pushed off the safe area or under the HUD by more than
## SLACK px² beyond what the last solve left (hysteresis, so it cannot flip back and forth).

const SLACK := 1024.0  ## px²: a quarter of a 64 px hex

## True once a draw has picked the title and label boxes for the current solve: later draws reuse them.
var held := false
var _solved := false
var _last := Vector2.ZERO
var _base_cost := -1.0

## Forget the layout (the menu closed, or opens on another anchor).
func reset() -> void:
	held = false
	_solved = false
	_base_cost = -1.0

## The radial solved its layout around `anchor`; returns it.
func solved(anchor: Vector2) -> Vector2:
	_solved = true
	held = false
	_base_cost = -1.0
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
	radial.title_box.position += d
	var parts: Array[Rect2] = [radial.title_box]
	for b in radial._buttons:
		b.position += d
		parts.append(Rect2(b.position, b.size))
	if not held:
		return true  # this frame's draw picks the labels; measure from the next frame
	for i in radial.label_rects.size():
		radial.label_rects[i].position += d
		parts.append(radial.label_rects[i])
	var view := radial.get_viewport_rect().size
	var safe := UiTokens.safe_insets(radial.get_viewport())
	var cost := spill(parts, Rect2(Vector2(safe.w, safe.z), view - Vector2(safe.w + safe.x, safe.z + safe.y)), UiTokens.hud_reserved(view))
	if _base_cost < 0.0:
		_base_cost = cost  # what the solve left (a crowded edge may leave some)
	return cost <= _base_cost + SLACK

## Px² of `parts` outside `bounds` plus px² of them on the `blocked` rects (the HUD).
static func spill(parts: Array[Rect2], bounds: Rect2, blocked: Array[Rect2]) -> float:
	var total := 0.0
	for r in parts:
		total += r.get_area() - r.intersection(bounds).get_area()
		for b in blocked:
			total += r.intersection(b).get_area()
	return total
