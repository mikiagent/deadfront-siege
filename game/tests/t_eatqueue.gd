extends SceneTree
## BAGUI eat queue (owner 2026-10-28: "select multiple and for it to eat them in queue (number in the
## top left of the selected items showing the order)"): marking three foods numbers their badges
## 1, 2, 3 (unmarking renumbers), Eat (3) eats them in that order through EatSession, and a Full
## stomach stops the queue with a notice, leaving the rest in the bag. And the owner's bug: three
## berries eaten one at a time through the bag's Eat (Use) action all succeed (Full no longer blocks).
## Run: Godot --headless --path game --script res://tests/t_eatqueue.gd -> "[t_eatqueue] PASS".

var _fails: PackedStringArray = []
var _ran := false
var _player

func _process(_delta: float) -> bool:
	if _ran or get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_ran = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_eatqueue] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

## Advance the current eat until `st` leaves the bag (a queue chains straight into the next bite).
func _finish_one(st = null) -> void:
	var guard := 0
	while _player.eat_session.eating and guard < 4000 and (st == null or _player.inventory.slots.find(st) >= 0):
		_player.eat_session.advance(0.1)
		guard += 1

func _run() -> void:
	var IS: GDScript = load("res://scripts/items/item_stack.gd")
	var host := Node3D.new()
	get_root().add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 4.0)
	_player = kit["player"]
	await process_frame
	await process_frame
	var inv = _player.inventory
	for k in 3:
		inv.slots[k] = IS.make(&"berry", 1, {}, 1 + k)
	inv.changed.emit()
	if _player.statuses:
		_player.statuses.clear_id(&"full")
	var ui = _player.ui
	ui.visible = true
	ui.rebuild()
	ui._on_toggle_multi()
	var g = ui._grid
	for i in [2, 0, 1]:
		g.toggle_multi(i)
	ui._update_batch_bar()
	_expect([g.cell_for(2).order, g.cell_for(0).order, g.cell_for(1).order] == [1, 2, 3], "badges read 1, 2, 3 in the order marked")
	g.toggle_multi(0)
	_expect(g.cell_for(2).order == 1 and g.cell_for(1).order == 2 and g.cell_for(0).order == 0, "unmarking renumbers the rest")
	g.toggle_multi(0)
	ui._update_batch_bar()
	_expect(ui._batch_eat_btn.visible and ui._batch_eat_btn.text == "Eat (3)", "the batch bar offers Eat (3) (%s)" % ui._batch_eat_btn.text)
	var first = inv.slots[2]
	var second = inv.slots[1]
	var third = inv.slots[0]
	ui._on_batch_eat()
	_expect(not ui.visible and _player.eat_session.eating and _player.eat_session.queue.size() == 2, "Eat closes the bag and starts the queue (%d left)" % _player.eat_session.queue.size())
	_finish_one(first)
	_expect(inv.slots.find(first) < 0 and inv.slots.find(second) >= 0 and _player.eat_session.eating, "the first marked berry went first, the next started")
	var dig = load("res://scripts/items/digestion.gd").of(_player)
	# HUNGER: fullness is the stored stomach (Digestion.add_fullness), not digesting rows; overfill it.
	dig.set_fullness(dig.OVERFULL_MAX)
	_finish_one(second)
	_expect(inv.slots.find(second) < 0, "the second marked berry was eaten")
	_expect(inv.slots.find(third) >= 0 and not _player.eat_session.eating and _player.eat_session.queue.is_empty(), "Full stops the queue; the third berry stays in the bag")
	_expect(_player.eat_session.last_queue_stop == "Too full to eat more.", "the stop says why (%s)" % _player.eat_session.last_queue_stop)
	await _single_eats(IS)
	if _fails.is_empty():
		print("[t_eatqueue] PASS")
		quit(0)
	else:
		print("[t_eatqueue] FAIL count=%d" % _fails.size())
		quit(1)

## Owner bug 2026-10-28: "eating multiple berries in succession is bugged out, I can't select eat again
## the second time". Three berries, each through the bag's Use (Eat) action, one after another.
func _single_eats(IS: GDScript) -> void:
	var inv = _player.inventory
	inv.slots.fill(null)
	var dig = load("res://scripts/items/digestion.gd").of(_player)
	dig._rows.clear()
	dig.set_fullness(0.0) # an empty stomach: three berries never overfill it, so only the Full status could block
	for k in 3:
		inv.slots[k] = IS.make(&"berry", 1, {}, 1)
	inv.changed.emit()
	var ui = _player.ui
	for k in 3:
		ui.visible = true
		ui.rebuild()
		var idx: int = inv.find_first(&"berry")
		ui._on_bag_slot_tapped(idx)
		_expect(not ui._use_btn.disabled and ui._use_btn.text.contains("Eat"), "berry %d: Use reads Eat" % (k + 1))
		ui._use_btn.pressed.emit()
		_expect(_player.eat_session.eating, "berry %d: the eat starts" % (k + 1))
		_finish_one()
	_expect(inv.count_of(&"berry") == 0, "all three berries were eaten (%d left)" % inv.count_of(&"berry"))

