extends SceneTree
## PEN-DIET (spec 02): a penned animal eats from its own diet. Herbivores take berry / herb leaf
## (preferred, wait x0.6) or fibre stalk (accepted, x0.8) and refuse meat; carnivores prefer raw
## meat and take raptor meat as accepted; spoiled meat and rot are refused; each feed eats exactly
## one item, and only after every refusal check. A pen mid-tame survives to_dict / from_dict.
## Prints "[t_pen_diet] PASS" (or FAIL lines), exits 0/1.
##   Godot --headless --path game --script res://tests/t_pen_diet.gd

const START := 1000.0
const FOODS := ["berry", "herb_leaf", "fibre_stalk", "raptor_meat", "raw_meat", "fish", "spoiled_meat", "rot"]

var failures: Array[String] = []
var _done := false
var IS: GDScript
var PenS: GDScript
var player: Node

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	IS = load("res://scripts/items/item_stack.gd")
	PenS = load("res://scripts/world/taming_pen.gd")
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(player)
	_test_herbivore()
	_test_carnivore()
	_test_spoiled()
	_test_preferred_first()
	_test_idle_pen()
	_test_no_diet()
	_test_floor()
	_test_save_round_trip()
	player.queue_free()
	if failures.is_empty():
		print("[t_pen_diet] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_pen_diet] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _pen(species: String) -> Node:
	var pen: Node = PenS.new()
	pen.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(pen)
	pen.occupant = IS.make(&"captured_animal", 1, {"species": species, "level": 5})
	pen.running = true
	pen.remaining = START
	return pen

func _drop(pen: Node) -> void:
	get_root().remove_child(pen)
	pen.free()

func _bag(items: Dictionary) -> void:
	# Empty the bag of every food this test uses (the starter kit may carry some).
	for id in FOODS:
		var i: int = player.inventory.find_first(StringName(id))
		while i >= 0:
			player.inventory.remove_at(i, 99)
			i = player.inventory.find_first(StringName(id))
	for id in items:
		for i in int(items[id]):
			player.inventory.add(IS.make(StringName(id), 1))

func _n(id: String) -> int:
	return player.inventory.count_of(StringName(id))

func _test_herbivore() -> void:
	var pen := _pen("zebraceratops")
	_bag({"raptor_meat": 2})
	var ok: bool = pen.feed(player)
	_expect(not ok and _n("raptor_meat") == 2 and is_equal_approx(pen.remaining, START), "zebraceratops refuses raptor meat and eats nothing (ok=%s meat=%d remaining=%.1f)" % [ok, _n("raptor_meat"), pen.remaining])
	var want := "Needs berry or herb leaf (or fibre stalk) in your bag."
	_expect(pen.last_feed_refusal == want, "refusal text '%s' (want '%s')" % [pen.last_feed_refusal, want])
	_bag({"berry": 2})
	ok = pen.feed(player)
	_expect(ok and _n("berry") == 1 and is_equal_approx(pen.remaining, START * 0.6), "berry: one eaten, wait x0.6 (ok=%s berry=%d remaining=%.1f)" % [ok, _n("berry"), pen.remaining])
	pen.remaining = START
	_bag({"fibre_stalk": 1})
	ok = pen.feed(player)
	_expect(ok and _n("fibre_stalk") == 0 and is_equal_approx(pen.remaining, START * 0.8), "fibre stalk (accepted): eaten, wait x0.8 (ok=%s remaining=%.1f)" % [ok, pen.remaining])
	_drop(pen)

func _test_carnivore() -> void:
	var pen := _pen("velociraptor")
	_bag({"berry": 3})
	var ok: bool = pen.feed(player)
	_expect(not ok and _n("berry") == 3, "velociraptor refuses berries (ok=%s berry=%d)" % [ok, _n("berry")])
	_bag({"raptor_meat": 1})
	ok = pen.feed(player)
	_expect(ok and _n("raptor_meat") == 0 and is_equal_approx(pen.remaining, START * 0.8), "raptor meat is accepted food for a raptor: x0.8 (remaining=%.1f)" % pen.remaining)
	pen.remaining = START
	_bag({"raw_meat": 1})
	ok = pen.feed(player)
	_expect(ok and _n("raw_meat") == 0 and is_equal_approx(pen.remaining, START * 0.6), "raw meat is preferred: x0.6 (remaining=%.1f)" % pen.remaining)
	pen.remaining = START
	_bag({"fish": 1})
	ok = pen.feed(player)
	_expect(ok and _n("fish") == 0 and is_equal_approx(pen.remaining, START * 0.8), "fish is accepted food for a raptor: x0.8 (remaining=%.1f)" % pen.remaining)
	_drop(pen)

func _test_spoiled() -> void:
	var pen := _pen("velociraptor")
	_bag({"spoiled_meat": 1, "rot": 1})
	var ok: bool = pen.feed(player)
	_expect(not ok and _n("spoiled_meat") == 1 and _n("rot") == 1 and is_equal_approx(pen.remaining, START), "spoiled meat and rot are refused")
	_drop(pen)

func _test_preferred_first() -> void:
	var pen := _pen("zebraceratops")
	_bag({"fibre_stalk": 1, "herb_leaf": 1})
	var ok: bool = pen.feed(player)
	_expect(ok and _n("herb_leaf") == 0 and _n("fibre_stalk") == 1 and is_equal_approx(pen.remaining, START * 0.6), "preferred herb leaf is eaten before accepted fibre stalk")
	_drop(pen)

func _test_no_diet() -> void:
	var def: Resource = load("res://scripts/creatures/creature_def.gd").new()
	def.preferred_food.clear()
	def.accepted_food.clear()
	_expect(PenS.feed_hint(def) == "This animal takes no food here.", "a species with no diet says so: '%s'" % PenS.feed_hint(def))

func _test_idle_pen() -> void:
	var pen := _pen("zebraceratops")
	pen.running = false
	_bag({"berry": 1})
	_expect(not pen.feed(player) and _n("berry") == 1, "an idle pen eats nothing")
	pen.running = true
	pen.occupant = null
	_expect(not pen.feed(player) and _n("berry") == 1, "an empty pen eats nothing")
	_drop(pen)

## Feeding never lengthens a nearly finished wait (the old 5 s floor turned 0.15 s into 5 s).
func _test_floor() -> void:
	var pen := _pen("zebraceratops")
	_bag({"berry": 2})
	pen.remaining = 6.0
	pen.feed(player)
	_expect(is_equal_approx(pen.remaining, 5.0), "6 s fed with berry stops at the 5 s floor (remaining=%.2f)" % pen.remaining)
	_expect(_n("berry") == 1, "the 6 s feed ate one berry (berry=%d)" % _n("berry"))
	pen.remaining = 0.15
	var ok: bool = pen.feed(player)
	_expect(not ok and is_equal_approx(pen.remaining, 0.15) and _n("berry") == 1, "at <= 5 s the pen refuses food and eats none (ok=%s remaining=%.2f berry=%d)" % [ok, pen.remaining, _n("berry")])
	_drop(pen)

func _test_save_round_trip() -> void:
	var pen := _pen("zebraceratops")
	_bag({"berry": 1})
	pen.feed(player)
	var d: Dictionary = JSON.parse_string(JSON.stringify(pen.to_dict()))
	var back: Node = PenS.from_dict(d)
	_expect(back.running and is_equal_approx(back.remaining, START * 0.6) and back.occupant != null and str(back.occupant.attributes.get("species", "")) == "zebraceratops", "pen mid-tame survives a save round trip (remaining=%.1f)" % back.remaining)
	back.free()
	_drop(pen)
