extends SceneTree
## GATHERGLIDE acceptance: the gather radial glides when its held layout has to give way.
## A RadialHold that is solved again draws its parts from where they were and moves each of them at
## most 8 px a frame, easing into the new layout and arriving exactly; a label that changes side glides
## on its own and leaves the hexes where they are; a walk (a few px a frame) is tracked exactly.
## Usage: godot --headless --path game --script res://tests/t_gatherglide.gd -> "[t_gatherglide] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const MAX_STEP := 8.0  ## the task's ceiling; RadialHold.MAX_STEP (2 px) is what the parts hold to
const FRAMES := 120

var _fails: Array[String] = []
var _started := false
var _watchdog := 0.0

func _process(delta: float) -> bool:
	_watchdog += delta
	if _watchdog > 60.0:
		print("[t_gatherglide] FAIL the test hung and hit its 60 s watchdog")
		quit(1)
		return true
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_gatherglide] FAIL %s" % what)

func _run() -> void:
	var Hold := load("res://scripts/ui/radial_hold.gd") as GDScript
	_test_resolve(Hold)
	_test_label_side(Hold)
	_test_walk(Hold)
	if _fails.is_empty():
		print("[t_gatherglide] PASS")
		quit(0)
	else:
		print("[t_gatherglide] FAIL count=%d" % _fails.size())
		quit(1)

## `n` parts: the title, hexes and labels of a layout centred on (cx, cy), a ring of 2 hexes 120 px out.
func _layout(cx: float, cy: float) -> Dictionary:
	var title := Rect2(Vector2(cx - 60.0, cy + 90.0), Vector2(120.0, 26.0))
	var hexes: Array[Vector2] = []
	var labels: Array[Rect2] = []
	for i in 2:
		var p := Vector2(cx + (90.0 if i == 0 else -90.0), cy - 40.0 + float(i) * 80.0)
		hexes.append(p)
		labels.append(Rect2(p + Vector2(74.0, 18.0), Vector2(60.0, 26.0)))
	return {"title": title, "hexes": hexes, "labels": labels, "at": Vector2(cx, cy)}

func _solve(hold, l: Dictionary) -> void:
	hold.solve(l["title"] as Rect2, l["hexes"] as Array[Vector2], l["labels"] as Array[Rect2])

## Where every part is drawn: title, hexes, labels.
func _parts(hold) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in hold.drawn_count():
		out.append(hold.drawn(i))
	return out

## A re-solve 150 px away: glided, not jumped. Every part steps <= 8 px a frame, arrives, and nothing
## still moves after it has arrived.
func _test_resolve(Hold: GDScript) -> void:
	var hold: RefCounted = Hold.new()
	var a := _layout(400.0, 300.0)
	_solve(hold, a)
	_expect(_parts(hold).size() == 5, "the layout has the title, 2 hexes and 2 labels (5 parts)")
	var before: Array[Rect2] = _parts(hold)
	var b := _layout(550.0, 300.0)  # 150 px right: a phone re-solve after MAX_DRIFT
	_solve(hold, b)
	_expect(hold.gliding(), "a re-solve 150 px away glides instead of placing at once")
	var worst := 0.0
	var prev: Array[Rect2] = before
	var frames := 0
	var arrived_at := -1
	for f in FRAMES:
		hold.advance()
		frames += 1
		var cur: Array[Rect2] = _parts(hold)
		for i in cur.size():
			worst = maxf(worst, (cur[i].position - prev[i].position).length())
		prev = cur
		if not hold.gliding():
			arrived_at = frames
			break
	var target := _layout(550.0, 300.0)
	var arrived: Array[Rect2] = _parts(hold)
	var miss := 0.0
	miss = maxf(miss, (arrived[0].position - (target["title"] as Rect2).position).length())
	for i in 2:
		miss = maxf(miss, (arrived[1 + i].position - (target["hexes"] as Array[Vector2])[i]).length())
		miss = maxf(miss, (arrived[3 + i].position - (target["labels"] as Array[Rect2])[i].position).length())
	var cap := float(Hold.get("MAX_STEP"))
	print("[t_gatherglide] re-solve: max_step=%.2f px (cap %.1f) frames=%d arrived_at=%d miss=%.3f px" % [worst, cap, frames, arrived_at, miss])
	_expect(cap <= MAX_STEP, "RadialHold glides at no more than the task's %.0f px a frame (%.1f)" % [MAX_STEP, cap])
	_expect(worst <= cap + 0.01, "re-solve: no part moves more than RadialHold.MAX_STEP px in a frame (max %.2f)" % worst)

	_expect(worst > 1.0, "re-solve: the parts do move (max %.2f px a frame), so the measure is not vacuous" % worst)
	_expect(arrived_at > 0 and arrived_at < FRAMES, "re-solve: the glide arrives (%d frames)" % arrived_at)
	_expect(miss < 0.01, "re-solve: the parts arrive exactly on the new layout (%.3f px off)" % miss)
	# Arrived means still: one more frame moves nothing.
	var still: Array[Rect2] = _parts(hold)
	hold.advance()
	var drift := 0.0
	var after: Array[Rect2] = _parts(hold)
	for i in after.size():
		drift = maxf(drift, (after[i].position - still[i].position).length())
	_expect(drift == 0.0, "re-solve: nothing moves once the glide has arrived (%.3f px)" % drift)

## A label that must change side glides across on its own: the hexes and the title do not move.
func _test_label_side(Hold: GDScript) -> void:
	var hold: RefCounted = Hold.new()
	var a := _layout(400.0, 300.0)
	_solve(hold, a)
	var hex_before: Array[Vector2] = []
	for i in hold.drawn_count():
		hex_before.append((hold.drawn(i) as Rect2).position)
	var cap := float(Hold.get("MAX_STEP"))
	var label_at: Rect2 = hold.drawn(3)
	var flipped := Rect2(Vector2(400.0 - 90.0 - 74.0 - 60.0, 340.0), label_at.size)  # label 0 to its hex's left
	hold.set_label_goal(0, flipped)
	_expect(hold.gliding(), "a label changing side glides")
	var cap2 := float(Hold.get("MAX_STEP"))
	var worst := 0.0
	var prev: Vector2 = label_at.position
	var frames := 0
	while hold.gliding() and frames < 400:
		hold.advance()
		frames += 1
		var cur: Vector2 = hold.drawn(3).position
		worst = maxf(worst, (cur - prev).length())
		prev = cur
	var moved := 0.0
	for i in hold.drawn_count():
		if i == 3:
			continue
		moved = maxf(moved, (hold.drawn(i).position - hex_before[i]).length())
	print("[t_gatherglide] label side: step=%.2f px frames=%d hex_move=%.3f px arrive=%.3f px" % [worst, frames, moved, (prev - flipped.position).length()])
	_expect(moved == 0.0, "label side: the title and the hexes stay put (max %.3f px)" % moved)
	_expect(worst <= cap2 + 0.01, "label side: the label glides at most %.1f px a frame (max %.2f)" % [cap2, worst])
	_expect(frames > 3, "label side: the label glides over several frames (%d)" % frames)
	_expect((prev - flipped.position).length() < 0.01, "label side: the label arrives on its new side")

## A walk: the anchor moves ~4 px a frame and the parts follow exactly, with nothing left to glide.
func _test_walk(Hold: GDScript) -> void:
	var hold: RefCounted = Hold.new()
	var a := _layout(400.0, 300.0)
	_solve(hold, a)
	hold.anchored(Vector2(400.0, 300.0))
	var hud: Array[Rect2] = []
	var worst := 0.0
	var prev: Array[Rect2] = _parts(hold)
	var anchor := Vector2(400.0, 300.0)
	for f in 60:
		anchor += Vector2(3.0, 1.0)
		hold.follow(anchor, Vector2(1600.0, 900.0), Vector4.ZERO, hud)
		hold.advance()
		var cur: Array[Rect2] = _parts(hold)
		for i in cur.size():
			worst = maxf(worst, (cur[i].position - prev[i].position).length())
		prev = cur
	print("[t_gatherglide] walk: max_step=%.3f px gliding=%s" % [worst, hold.gliding()])
	_expect(worst <= MAX_STEP, "walk: the parts track the node at most %.0f px a frame (max %.3f)" % [MAX_STEP, worst])
	_expect(not hold.gliding(), "walk: a held layout that fits is followed exactly, with no glide left over")
