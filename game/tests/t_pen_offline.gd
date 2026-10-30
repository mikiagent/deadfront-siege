extends SceneTree
## PENCLAIM part 2: the pen timer is an end timestamp. Save a running pen, push the clock 2 h
## (PenS.time_skew fakes the time source), load: the pen resolves once into the ready state.
## Feeding a timestamped pen still eats one item and moves the end time; a save from before
## PENCLAIM (only "remaining") converts on load.
## Prints "[t_pen_offline] PASS" (or FAIL lines), exits 0/1.
##   Godot --headless --path game --script res://tests/t_pen_offline.gd

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
	_test_offline_two_hours()
	_test_feed_moves_end()
	_test_old_save()
	PenS.time_skew = 0.0
	player.queue_free()
	if failures.is_empty():
		print("[t_pen_offline] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_pen_offline] FAIL %s" % f)
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
	pen.remaining = PenS.BASE_SECONDS
	return pen

func _load(d: Dictionary) -> Node:
	return PenS.from_dict(SanS._buildings([JSON.parse_string(JSON.stringify(d))])[0])

func _test_offline_two_hours() -> void:
	PenS.time_skew = 0.0
	var pen := _pen("zebraceratops")
	var saved: Dictionary = pen.to_dict()
	_expect(float(saved.get("end_at", 0.0)) > 0.0, "the save holds an end timestamp")
	PenS.time_skew = 2.0 * 3600.0
	var back: Node = _load(saved)
	get_root().add_child(back)
	_expect(back.running and is_zero_approx(back.remaining), "after 2 h away the loaded pen's wait is over (remaining %.1f)" % back.remaining)
	back.force_result = 1
	var before: int = player.bonded.size()
	back.resolve(player)
	var uid: String = back.tamed.uid if back.tamed else ""
	_expect(back.tamed != null and not back.running and player.bonded.size() == before, "it resolves into the ready state, not straight into the roster")
	back.force_result = -1
	back.resolve(player)
	_expect(back.tamed != null and back.tamed.uid == uid and back.occupant != null, "a second resolve never rolls again")
	var reload: Node = _load(back.to_dict())
	_expect(reload.tamed != null and reload.tamed.uid == uid and not reload.running, "the ready state survives another save + load")
	reload.free()
	get_root().remove_child(back)
	back.free()
	get_root().remove_child(pen)
	pen.free()
	PenS.time_skew = 0.0

func _test_feed_moves_end() -> void:
	var pen := _pen("zebraceratops")
	for id in ["berry", "herb_leaf", "fibre_stalk"]:
		var i: int = player.inventory.find_first(StringName(id))
		while i >= 0:
			player.inventory.remove_at(i, 99)
			i = player.inventory.find_first(StringName(id))
	player.inventory.add(IS.make(&"berry", 1))
	player.inventory.add(IS.make(&"berry", 1))
	var end0: float = pen.end_at
	var ok: bool = pen.feed(player)
	_expect(ok and player.inventory.count_of(&"berry") == 1, "feeding a timestamped pen eats exactly one berry (%d left)" % player.inventory.count_of(&"berry"))
	var want: float = PenS.now() + PenS.BASE_SECONDS * 0.6 / game.time_scale
	_expect(pen.end_at < end0 and absf(pen.end_at - want) < 0.01, "feeding moves the end time to 60 %% of the wait (end %.2f want %.2f)" % [pen.end_at, want])
	get_root().remove_child(pen)
	pen.free()

## A save from before PENCLAIM: no end_at, only the remaining seconds. The wait restarts from the load.
func _test_old_save() -> void:
	var old := {"kind": "makeshift_taming_pen", "cell": [0, 0], "rot": 0, "running": true, "remaining": 100.0,
		"occupant": {"id": "captured_animal", "count": 1, "attributes": {"species": "velociraptor", "level": 3}}}
	var back: Node = _load(old)
	_expect(back.running and absf(back.remaining - 100.0) < 0.01 and absf(back.end_at - (PenS.now() + 100.0 / game.time_scale)) < 0.01, "an old save's remaining converts to an end time (remaining %.2f)" % back.remaining)
	_expect(back.tamed == null, "an old save has nothing to claim")
	var idle: Node = _load({"kind": "makeshift_taming_pen", "cell": [0, 0], "rot": 0, "running": false, "remaining": 0.0, "occupant": null})
	_expect(not idle.running and idle.end_at == 0.0 and idle.occupant == null, "an old idle pen stays idle")
	back.free()
	idle.free()
