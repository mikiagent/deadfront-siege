extends SceneTree
## PENCLAIM part 1: a finished pen tame waits in the pen until Bond. No bond before the tap, exactly
## one after a double tap (pen API and the Taming Pen screen), the same uid after a save round trip
## (a reload between finish and claim never makes a second pet), and a failed tame leaves nothing.
## Prints "[t_pen_claim] PASS" (or FAIL lines), exits 0/1.
##   Godot --headless --path game --script res://tests/t_pen_claim.gd

var failures: Array[String] = []
var _done := false
var IS: GDScript
var PenS: GDScript
var SanS: GDScript
var game: Node
var player: Node

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	IS = load("res://scripts/items/item_stack.gd")
	PenS = load("res://scripts/world/taming_pen.gd")
	SanS = load("res://scripts/core/save_sanitizer.gd")
	game = get_root().get_node("Game")
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(player)
	player.bonded.clear()
	_test_claim_double_tap()
	_test_ui_double_tap()
	_test_save_round_trip()
	_test_fail()
	player.queue_free()
	if failures.is_empty():
		print("[t_pen_claim] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_pen_claim] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _pen(result: int) -> Node:
	var pen: Node = PenS.new()
	pen.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(pen)
	pen.occupant = IS.make(&"captured_animal", 1, {"species": "zebraceratops", "level": 13})
	pen.running = true
	pen.remaining = 0.0
	pen.force_result = result
	return pen

func _drop(pen: Node) -> void:
	get_root().remove_child(pen)
	pen.free()

func _count_uid(uid: String) -> int:
	return player.bonded.filter(func (r: Variant) -> bool: return r.uid == uid).size()

func _test_claim_double_tap() -> void:
	var pen := _pen(1)
	var before: int = player.bonded.size()
	pen.resolve(player)
	_expect(pen.tamed != null and player.bonded.size() == before, "success holds the pet in the pen, nothing bonds before the tap (bonded %d -> %d)" % [before, player.bonded.size()])
	_expect(not pen.running and not pen.feed(player), "a finished pen is not running and takes no food")
	pen.resolve(player)
	var uid: String = pen.tamed.uid if pen.tamed else ""
	_expect(uid != "", "a second resolve does not roll again or drop the record")
	var a: bool = pen.claim(player)
	var b: bool = pen.claim(player)
	_expect(a and not b and player.bonded.size() == before + 1 and _count_uid(uid) == 1, "double tap Bond bonds once (first=%s second=%s bonded %d)" % [a, b, player.bonded.size()])
	_expect(pen.tamed == null and pen.occupant == null, "the pen is empty after Bond")
	_drop(pen)

func _test_ui_double_tap() -> void:
	var pen := _pen(1)
	pen.resolve(player)
	var uid: String = pen.tamed.uid
	var ui: Node = (load("res://scripts/ui/taming_pen_ui.gd") as GDScript).new()
	get_root().add_child(ui)
	ui.open(player, pen)
	var card: Control = ui.find_child("Result", true, false)
	_expect(card != null and card.visible, "the screen shows the Taming successful card for a finished pen")
	var bond: Button = ui.find_child("BondPet", true, false)
	_expect(bond != null and bond.visible, "the card has a Bond button")
	bond.pressed.emit()
	bond.pressed.emit()
	_expect(_count_uid(uid) == 1, "two taps on the card's Bond make one pet (%d)" % _count_uid(uid))
	ui.free()
	_drop(pen)

## The pet's uid is fixed when the tame finishes: a save + load in between keeps it, and claiming
## the reloaded pen when that uid is already bonded adds nothing.
func _test_save_round_trip() -> void:
	var pen := _pen(1)
	pen.resolve(player)
	var uid: String = pen.tamed.uid
	var grade := str(pen.tamed.grade)
	var rows: Array = SanS._buildings([JSON.parse_string(JSON.stringify(pen.to_dict()))])
	var back: Node = PenS.from_dict(rows[0])
	_expect(back.tamed != null and back.tamed.uid == uid and str(back.tamed.grade) == grade and not back.running, "the ready pet survives save + load with its uid and grade (%s)" % [back.tamed.uid if back.tamed else "none"])
	var before: int = player.bonded.size()
	_expect(back.claim(player) and _count_uid(uid) == 1, "the reloaded pen bonds the same uid")
	# The pre-claim save loaded again (pen still holds the pet, roster already has it): no second pet.
	var again: Node = PenS.from_dict(SanS._buildings([JSON.parse_string(JSON.stringify(pen.to_dict()))])[0])
	_expect(not again.claim(player) and _count_uid(uid) == 1 and player.bonded.size() == before + 1 and again.tamed == null, "a uid already on the roster is never bonded twice")
	back.free()
	again.free()
	_drop(pen)

func _test_fail() -> void:
	var pen := _pen(-1)
	var before: int = player.bonded.size()
	pen.resolve(player)
	_expect(pen.tamed == null and pen.occupant == null and not pen.running, "a failed tame frees the animal")
	_expect(not pen.claim(player) and player.bonded.size() == before, "a failed tame leaves nothing to claim")
	_expect(not pen.to_dict().has("tamed"), "a failed pen saves no tamed record")
	for c in get_root().get_children():
		if c.is_in_group("creatures"):
			c.free() # the escaped animal
	_drop(pen)
