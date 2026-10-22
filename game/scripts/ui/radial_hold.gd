class_name RadialHold
extends RefCounted
## Holds the gather radial's solved layout against its node while the camera moves (CONTROLS B1), and
## glides its parts from where they are drawn to where the layout wants them (GATHERGLIDE).
## GatherRadial solved its layout every frame against the HUD, the survivor's nameplate and its own
## title, so while the camera followed a walk the hexes swapped sides and the title flipped above and
## below the plant (owner: "UI glitching up and down on resource nodes"). Now it solves when it opens;
## each frame the hexes, the title and the labels move with the anchor. Where that would push them onto
## the HUD, or further off the screen than SLACK px² beyond what the solve left, they move along one axis
## or hold still and the node slides under them; once they lag it by MAX_DRIFT px the radial solves
## again. Every move a part cannot follow in one frame is glided: the drawn parts ease towards the layout
## at no more than MAX_STEP px a frame, so a re-solve or a stalled frame's camera catch-up is motion, not
## a jump. A label whose own side changes glides across without the hexes moving.
## Holding until the layout fails is the hysteresis: a jiggle at an edge cannot flip it back.

const SLACK := 1024.0  ## px² off the screen: a quarter of a 64 px hex
const MAX_DRIFT := 64.0  ## px the held layout may lag its node before it is solved again (one hex)
const MAX_STEP := 7.0  ## px a drawn part may move against its node in one frame (the task allows 8)
const EASE := 0.25  ## of the distance left, a frame: a glide settles instead of stopping dead
## ASSUMPTION: 8 px a frame (the task's ceiling), measured against the node. A walk moves the anchor
## under 6 px a frame and a part follows it exactly; a hitch or a re-solve moves a part 45-160 px, a
## glide of about a second. GatherRadial clamps each part's step against the node to MAX_STEP, so the
## gate holds however the layout was moved.

## True once a draw has picked the title and label boxes for the current solve: later draws reuse them.
var held := false
var _solved := false
var _placed := false
var _last := Vector2.ZERO
var _drift := Vector2.ZERO
var _base := Vector2(-1.0, -1.0)  ## what the solve left: (px² off the screen, px² on the HUD)
var _goal: Array[Rect2] = []  ## where the layout wants each part: title, hexes, labels
var _pos: Array[Rect2] = []   ## where each part is drawn
var _labels_at := 0  ## index of the first label in _goal

## Forget the layout (the menu closed, or opens on another anchor).
func reset() -> void:
	held = false
	_solved = false
	_placed = false
	_goal.clear()
	_pos.clear()
	_labels_at = 0

## True while a part is still on its way to the layout.
func gliding() -> bool:
	for i in mini(_goal.size(), _pos.size()):
		if not _pos[i].position.is_equal_approx(_goal[i].position):
			return true
	return false

## The radial solved a layout: title box, hex positions (64 px squares) and label boxes. The first solve
## of a menu places everything at once; a later one keeps the drawn parts and glides them there.
func solve(title: Rect2, hexes: Array[Vector2], labels: Array[Rect2]) -> void:
	var goals: Array[Rect2] = [title]
	for h in hexes:
		goals.append(Rect2(h, Vector2(64.0, 64.0)))
	_labels_at = goals.size()
	for r in labels:
		goals.append(r)
	_solved = true
	_base = Vector2(-1.0, -1.0)
	_drift = Vector2.ZERO
	held = true
	if not _placed or _pos.size() != goals.size():
		_placed = true
		_goal = goals.duplicate()
		_pos = goals.duplicate()
		return
	_goal = goals  # still drawn where we were; advance() glides to the new layout

## The solve is anchored: where the node's anchor is now (drift is measured from here).
func anchored(anchor: Vector2) -> void:
	_last = anchor

## A label's own place changed (its side flipped): glide just that label, the hexes stay put.
func set_label_goal(i: int, rect: Rect2) -> void:
	if not _placed:
		return
	var k := _labels_at + i
	if k >= _goal.size():
		return
	_goal[k] = rect

## A hard ceiling on how far a drawn part may move against its anchor this frame: anything further is
## pulled back to `limit` px from last frame's offset, and the layout's own pull glides the rest next
## frame. Whatever moved the layout (a re-solve, a frame the camera caught up, a new label set), no
## part ever shows a jump against its node.
func clamp_offsets(prev: Array[Vector2], anchor: Vector2, limit: float) -> void:
	if prev.size() != _pos.size():
		return
	for i in _pos.size():
		var d := (_pos[i].position - anchor) - prev[i]
		if d.length() > limit:
			_pos[i].position = anchor + prev[i] + d.normalized() * limit

## Where a part is drawn now: title (0), hex i (1 + i) or label i (1 + hex count + i).
func drawn(i: int) -> Rect2:
	if i < 0 or i >= _pos.size():
		return Rect2()
	return _pos[i]

## How many parts the layout has (title, hexes, labels).
func drawn_count() -> int:
	return _pos.size()

## Each frame, before the radial lays out: moves the hexes, title and labels with the anchor and returns
## true while they still fit; false when the radial must solve again (never solved, or out of space).
func follow(anchor: Vector2, view: Vector2, safe: Vector4, hud: Array[Rect2]) -> bool:
	if not _solved:
		return false
	if not anchor.is_finite():
		return true  # a source behind the camera: keep what is up rather than shift it by NaN
	if not _last.is_finite():
		return false  # solved while it was: solve again now that it is on screen
	var d := anchor - _last
	_last = anchor
	if not held:
		_shift(d, true)  # the first draw picks the labels; measure from the next frame
		return true
	var bounds := Rect2(Vector2(safe.w, safe.z), view - Vector2(safe.w + safe.x, safe.z + safe.y))
	if _base.x < 0.0:
		_base = spill(_parts(Vector2.ZERO), bounds, hud)
	# A walk's step (a few px) may push the layout a little further off the screen than the solve left
	# it: SLACK + 4 px² per px walked, or the ring would hold still and the parts would be dragged off.
	var room := SLACK + 4.0 * d.length()
	for t: Vector2 in [d, Vector2(d.x, 0.0), Vector2(0.0, d.y), Vector2.ZERO]:
		var cost := spill(_parts(t), bounds, hud)
		if cost.x <= _base.x + room and cost.y <= _base.y + 1.0:
			# The layout and the drawn parts follow the node at once: a walk is tracked exactly. A
			# hitch - the camera catching up a stalled frame all at once - is clamped against the node
			# by GatherRadial/clamp_moves, so it glides instead of jumping.
			_shift(t, true)
			_drift += d - t
			return _drift.length() <= MAX_DRIFT
	return false  # even holding still it spills (the view changed)

## One frame of glide: every drawn part eases towards where the layout wants it, at most MAX_STEP px.
func advance() -> void:
	if not _placed or _goal.size() != _pos.size():
		return
	for i in _pos.size():
		var d := _goal[i].position - _pos[i].position
		var len := d.length()
		if len <= MAX_STEP * 0.5:
			_pos[i].position = _goal[i].position  # arrived, exactly (the slow tail would crawl)
		else:
			_pos[i].position += d / len * minf(MAX_STEP, maxf(len * EASE, 0.5))

## Move both the layout and the drawn parts by `u`; `snap` moves the drawn parts with it (a walk, whose
## step a part can follow), false leaves them to glide after it (a hitch, or a new solve).
func _shift(u: Vector2, snap: bool) -> void:
	for i in _goal.size():
		_goal[i].position += u
	if snap:
		for i in _pos.size():
			_pos[i].position += u

## The parts as the layout would move them by `t`.
func _parts(t: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in _goal:
		out.append(Rect2(r.position + t, r.size))
	return out

## (px² of `parts` outside `bounds`, px² of them on the `blocked` rects: the HUD).
static func spill(parts: Array[Rect2], bounds: Rect2, blocked: Array[Rect2]) -> Vector2:
	var out := Vector2.ZERO
	for r in parts:
		out.x += r.get_area() - r.intersection(bounds).get_area()
		for b in blocked:
			out.y += r.intersection(b).get_area()
	return out
