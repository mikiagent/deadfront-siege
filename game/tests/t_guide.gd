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
	near.depleted = true
	_expect(GuideS.pick_node(Vector3.ZERO, &"branch", nodes, []) == far, "a depleted tree is skipped")
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
	_expect(is_equal_approx(FingerS.aim_angle(Vector2.UP), 0.0) and is_equal_approx(FingerS.aim_angle(Vector2.RIGHT), PI * 0.5), "aim angle: up is 0, right is a quarter turn")
	var inner := view.grow(-20.0)
	var right: Vector2 = FingerS.clamp_tip(Vector2(5000, 450), false, inner)
	_expect(right.is_equal_approx(Vector2(1580, 450)), "a target far right clamps to the right edge (%s)" % right)
	var behind: Vector2 = FingerS.clamp_tip(Vector2(5000, 450), true, inner)
	_expect(behind.is_equal_approx(Vector2(20, 450)), "a target behind the camera clamps to the mirrored edge (%s)" % behind)
	var corner: Vector2 = FingerS.clamp_tip(Vector2(-800, -1000), false, inner)
	_expect(inner.grow(0.5).has_point(corner) and (absf(corner.x - 20.0) < 0.5 or absf(corner.y - 20.0) < 0.5), "an up-left target clamps onto the edge (%s)" % corner)
	_sections += 1
