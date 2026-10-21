extends SceneTree
## Walkthrough finger checks (durango-prompts 22): every early order resolves to something to point at
## (or an explicit none), the tree pick prefers nodes outside hunters' reach, old saves count passed
## orders as shown, and the hand's placement keeps off the vitals and the Orders card.
## Usage: godot --headless --path game --script res://tests/t_guide.gd

var failures: Array[String] = []
var _done := false
var _sections := 0  ## bumped at the end of every _test_*: a runtime error aborts only its function
# These scripts reference the Data and World autoloads, so they load on the first frame those exist
# (same pattern as t_tame.gd).
var GuideS: GDScript
var FingerS: GDScript
var ObjectivesS: GDScript
var SanitizerS: GDScript
var HarvestS: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	GuideS = load("res://scripts/core/guide.gd")
	FingerS = load("res://scripts/ui/guide_finger.gd")
	ObjectivesS = load("res://scripts/core/objectives.gd")
	SanitizerS = load("res://scripts/core/save_sanitizer.gd")
	HarvestS = load("res://scripts/world/harvest_node.gd")
	_test_plans()
	_test_saves()
	_test_pick_node()
	_test_placement()
	var want := 4
	if _sections != want:
		failures.append("only %d of %d test sections completed (a runtime error aborted the rest)" % [_sections, want])
	if failures.is_empty():
		print("[t_guide] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_guide] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _test_plans() -> void:
	var want := [
		{"kind": "gather", "item": "branch"}, {"kind": "gather", "item": "stone"},
		{"kind": "gather", "item": "fibre_stalk"}, {"kind": "craft"}, {"kind": "craft"},
		{"kind": "station", "stations": ["workbench"]}, {"kind": "gather", "item": "wood_log"},
		{"kind": "creature", "id": "compsognathus"}, {"kind": "station", "stations": ["campfire", "bonfire"]},
		{"kind": "craft"}, {"kind": "creature", "id": "zebraceratops"},
	]
	for i in want.size():
		var step: Dictionary = ObjectivesS.step(i)
		var got: Dictionary = GuideS.plan(step)
		print("[t_guide] step %d %s -> %s" % [i, step.get("id", "?"), got])
		_expect(str(got) == str(want[i]), "step %d (%s) plans %s, want %s" % [i, step.get("id", "?"), got, want[i]])
	# Past the guided orders: an explicit none, never a guess (sail needs the harbour route, not a tap).
	_expect(GuideS.plan(ObjectivesS.step(11)) == {"kind": "none"}, "step 11 (sail) plans none, got %s" % GuideS.plan(ObjectivesS.step(11)))
	_expect(ObjectivesS.step(-1).is_empty() and ObjectivesS.step(9999).is_empty(), "step() past the list is empty")
	_expect(GuideS.plan({}) == {"kind": "none"}, "an empty step plans none")
	var hint := str(ObjectivesS.step(0).get("hint", ""))
	_expect(not hint.to_lower().contains("wheel"), "order 1's hint names the hex, not a wheel: \"%s\"" % hint)
	_sections += 1

func _test_saves() -> void:
	var old: PackedStringArray = GuideS.done_from_save({"objective": 3})
	_expect(old == PackedStringArray(["branches", "stone", "fibre"]), "an old save at order 4 counts the first three as shown, got %s" % old)
	_expect(GuideS.done_from_save({"objective": 0}).is_empty(), "a fresh save has nothing shown")
	var kept: PackedStringArray = GuideS.done_from_save({"objective": 3, "guide_done": ["branches", 7]})
	_expect(kept == PackedStringArray(["branches", "7"]), "a saved list is kept as strings, got %s" % kept)
	var forged: Dictionary = SanitizerS.clean({"objective": 2, "guide_done": "branches"})
	_expect(not forged.has("guide_done") and GuideS.done_from_save(forged) == PackedStringArray(["branches", "stone"]), "a guide_done that is not a list is dropped and the default applies")
	_expect(JSON.stringify({"g": PackedStringArray(["branches"])}) == "{\"g\":[\"branches\"]}", "World.guide_done saves as a JSON list")
	_sections += 1

func _test_pick_node() -> void:
	var host := Node3D.new()
	get_root().add_child(host)
	var near := _node(host, "CommonTree", Vector3(3, 0, 0))
	var far := _node(host, "CommonTree", Vector3(12, 0, 0))
	var bush := _node(host, "Bush", Vector3(1, 0, 0))
	var nodes := [bush, near, far]
	_expect(GuideS.offers(near, &"branch") and not GuideS.offers(bush, &"branch"), "a tree offers branch, a bush does not")
	_expect(GuideS.pick_node(Vector3.ZERO, &"branch", nodes, []) == near, "with no hunters the nearest tree is picked")
	var hunter := [[Vector3(3, 0, 1), 6.0]]
	_expect(GuideS.pick_node(Vector3.ZERO, &"branch", nodes, hunter) == far, "a tree inside a hunter's radius loses to a farther safe one")
	_expect(GuideS.pick_node(Vector3.ZERO, &"branch", nodes, [[Vector3(8, 0, 0), 20.0]]) == near, "with no safe tree the nearest one is still picked")
	_expect(GuideS.pick_node(Vector3.ZERO, &"fibre_stalk", nodes, []) == bush, "fibre picks the bush")
	var mid := _node(host, "CommonTree", Vector3(4, 0, 0))
	nodes.append(mid)
	_expect(GuideS.pick_node(Vector3.ZERO, &"branch", nodes, [], mid) == mid, "the last tree is kept while it is nearly as near (no hopping)")
	_expect(GuideS.pick_node(Vector3.ZERO, &"branch", nodes, [], far) == near, "a last tree four times as far gives way to the nearest")
	_expect(GuideS.pick_node(Vector3.ZERO, &"branch", nodes, [[Vector3(5, 0, 1), 1.5]], mid) == near, "a last tree a hunter now reaches gives way to a safe one")
	near.depleted = true
	_expect(GuideS.pick_node(Vector3.ZERO, &"branch", nodes, []) == mid, "a depleted tree is skipped")
	_expect(GuideS.pick_node(Vector3.ZERO, &"branch", nodes, [], near) == mid, "a depleted last tree is dropped")
	_expect(GuideS.pick_node(Vector3.ZERO, &"stone", nodes, []) == null, "nothing offers stone here: no target")
	host.queue_free()
	_sections += 1

func _node(host: Node3D, family: String, at: Vector3) -> Node3D:
	var n: Node3D = HarvestS.new()
	n.family = family
	n.position = at
	host.add_child(n)
	return n

func _test_placement() -> void:
	var phone := Vector2(844, 390)
	var tall: float = FingerS.HAND_H * FingerS.hand_scale(phone)
	print("[t_guide] hand %.0f px tall at 844x390, %.0f px at 1600x900" % [tall, FingerS.HAND_H * FingerS.hand_scale(Vector2(1600, 900))])
	_expect(tall >= 64.0, "the hand is at least 64 px tall at 844x390 (%.0f)" % tall)
	_expect(FingerS.bob(0.0) <= FingerS.BOB and FingerS.bob(0.45) >= 0.0, "the tap stays within %.0f px of the target" % FingerS.BOB)
	var view := Rect2(Vector2.ZERO, Vector2(1600, 900))
	var vitals := Rect2(8, 8, 300, 88)
	var quest := Rect2(1178, 34, 240, 72)
	var keep: Array[Rect2] = [vitals, quest]
	# Mid-screen, under the vitals, under the card, the MENU hex (bottom-left corner), the CLAIM hex.
	for at in [Vector2(800, 450), Vector2(200, 130), Vector2(1300, 140), Vector2(48, 836), Vector2(1548, 266)]:
		var a: float = FingerS.pick_angle(at, view, keep, 1.1)
		var r: Rect2 = FingerS.hand_rect(at, a, 1.1) if not is_nan(a) else Rect2()
		_expect(not is_nan(a) and view.encloses(r) and not r.intersects(vitals) and not r.intersects(quest), "target %s: the hand fits on screen off the vitals and the card (%s)" % [at, r])
	_expect(is_nan(FingerS.pick_angle(Vector2(100, 50), view, keep, 1.1)), "a target on the vitals hides the finger rather than cover them")
	var label := Rect2(830, 440, 120, 26)  # a hex's label to the right of the tip: the hand goes elsewhere
	var soft: Array[Rect2] = [label]
	var la: float = FingerS.pick_angle(Vector2(800, 450), view, keep, 1.1, soft)
	_expect(not FingerS.hand_rect(Vector2(800, 450), la, 1.1).intersects(label), "the hand keeps off a soft label where a placement allows")
	# Hysteresis: the current placement stays while it fits, so the hand does not swap sides frame to frame.
	var none: Array[Rect2] = []
	var mid := Vector2(800, 450)
	var up_right: float = FingerS.ANGLES[2]
	_expect(FingerS.pick_angle(mid, view, keep, 1.1, none, up_right) == up_right, "the current placement stays while it fits")
	var foot: float = FingerS.pick_angle(Vector2(800, 885), view, keep, 1.1, none, FingerS.ANGLES[0])
	_expect(not is_nan(foot) and foot != FingerS.ANGLES[0], "a current placement that runs off the screen gives way (%s)" % foot)
	# A block 10 px right of the below-right hand: inside GAP_NEW, outside GAP_KEEP. Whichever side the hand
	# is on stays (the old rule flipped back to below-right, the first choice, as soon as it fit again).
	var br: float = FingerS.ANGLES[0]
	var bl: float = FingerS.ANGLES[1]
	var r0: Rect2 = FingerS.hand_rect(mid, br, 1.1)
	var near_block: Array[Rect2] = [vitals, quest, Rect2(r0.end.x + 10.0, r0.position.y, 40.0, r0.size.y)]
	_expect(FingerS.pick_angle(mid, view, near_block, 1.1, none, br) == br and FingerS.pick_angle(mid, view, near_block, 1.1, none, bl) == bl,
		"a placement 10 px from a block keeps its side")
	# The flip-flop the motion gate caught at 844x390: the hand left that side; its new spot covers a label,
	# but the side 10 px from the block is not clear enough to take it back.
	var tag: Array[Rect2] = [Rect2(mid + Vector2(-90, -34), Vector2(45, 137))]
	var back: float = FingerS.pick_angle(mid, view, near_block, 1.1, tag, bl)
	_expect(not is_nan(back) and back != br, "a hand moved off a side does not flip back while that side is 10 px from a block (%s)" % back)
	var over: Array[Rect2] = [FingerS.hand_rect(mid, up_right, 1.1)]
	_expect(FingerS.pick_angle(mid, view, keep, 1.1, over, up_right) != up_right, "a current placement that now covers a label gives way to a clear one")
	var boxed: Array[Rect2] = [Rect2(0, 0, 1600, 900)]
	_expect(not is_nan(FingerS.pick_angle(Vector2(800, 450), view, keep, 1.1, boxed)), "soft rects never hide the finger")
	_expect(is_equal_approx(FingerS.aim_angle(Vector2.UP), 0.0) and is_equal_approx(FingerS.aim_angle(Vector2.RIGHT), PI * 0.5), "aim angle: up is 0, right is a quarter turn")
	var inner := view.grow(-20.0)
	var right: Vector2 = FingerS.clamp_tip(Vector2(5000, 450), false, inner)
	_expect(right.is_equal_approx(Vector2(1580, 450)), "a target far right clamps to the right edge (%s)" % right)
	var behind: Vector2 = FingerS.clamp_tip(Vector2(5000, 450), true, inner)
	_expect(behind.is_equal_approx(Vector2(20, 450)), "a target behind the camera clamps to the mirrored edge (%s)" % behind)
	var corner: Vector2 = FingerS.clamp_tip(Vector2(-800, -1000), false, inner)
	_expect(inner.grow(0.5).has_point(corner) and (absf(corner.x - 20.0) < 0.5 or absf(corner.y - 20.0) < 0.5), "an up-left target clamps onto the edge (%s)" % corner)
	_sections += 1
