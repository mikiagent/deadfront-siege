extends SceneTree
## INVSLOTS: the bag is a fixed list of slots, one item instance per slot, and its capacity is
## base 100 plus worn storage (spec 05:11). Prints "[t_invslots] PASS" or FAIL lines, exits 0/1.
##   Godot --headless --path game --script res://tests/t_invslots.gd

var failures: Array[String] = []
var _done := false
var IS: GDScript
var INV: GDScript
var _started := 0

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		if _started == 0:
			_started = int(Time.get_ticks_msec())
		elif int(Time.get_ticks_msec()) - _started > 60000:
			print("[t_invslots] FAIL Data autoload never appeared")
			quit(1)
		return false
	_done = true
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	for t in [_test_one_slot_per_instance, _test_capacity_bonuses, _test_overflow_unequip_refused,
			_test_save_load_instances_and_capacity, _test_bag_item_exists]:
		t.call()
	if failures.is_empty():
		print("[t_invslots] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_invslots] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _json(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))

## Save/load the way SaveGame does: bag rows then extras, both through JSON.
func _reload(inv):
	var back = INV.new(inv.base_slots)
	back.load_array(_json(inv.to_array()))
	back.extras_from_dict(_json(inv.extras_to_dict()))
	return back

## Five bones of the same def with different levels: five physical spaces, five uids.
func _test_one_slot_per_instance() -> void:
	var inv = INV.new()
	_expect(inv.capacity() == 100 and inv.slot_count == 100, "a fresh bag has 100 slots (%d/%d)" % [inv.capacity(), inv.slot_count])
	for k in 5:
		inv.add(IS.make(&"raptor_bone", 1, {}, 1 + k * 7))
	_expect(inv.used_slots() == 5, "five identical bones take five slots (%d)" % inv.used_slots())
	var uids := {}
	var levels := {}
	for i in inv.slot_count:
		var s = inv.slots[i]
		if s:
			uids[s.uid] = true
			levels[s.level] = true
	_expect(uids.size() == 5 and not uids.has(""), "each bone has its own uid (%d unique)" % uids.size())
	_expect(levels.size() == 5, "each bone keeps its own level (%d levels)" % levels.size())
	_expect(inv.add(IS.make(&"raptor_bone", 1, {}, 60)) == 0 and inv.used_slots() == 6, "a sixth bone takes a sixth slot")
	# The grid is exactly capacity slots, empty ones included.
	_expect(inv.to_array().size() == inv.capacity(), "the saved bag has one row per slot (%d rows, capacity %d)" % [inv.to_array().size(), inv.capacity()])

func _test_capacity_bonuses() -> void:
	var inv = INV.new()
	inv.add(IS.make(&"woven_bag", 1))
	var idx: int = inv.find_first(&"woven_bag")
	_expect(idx >= 0, "the data-only bag item exists in data/items.json")
	if idx < 0:
		return
	_expect(inv.equip_at(idx), "the woven bag can be worn")
	_expect(inv.capacity() == 120 and inv.slot_count == 120, "wearing the +20 bag makes 120 slots (capacity %d, slots %d)" % [inv.capacity(), inv.slot_count])
	# Pocket +6 per level (spec 05:11).
	var pocket = IS.make(&"woven_bag", 1)
	pocket.attributes["pocket"] = 3
	inv.add(pocket)
	var pidx: int = -1
	for i in inv.slot_count:
		if inv.slots[i] and inv.slots[i].def_id == &"woven_bag" and int(inv.slots[i].attributes.get("pocket", 0)) == 3:
			pidx = i
	var before: int = inv.capacity()
	_expect(pidx >= 0 and inv.equip_at(pidx, &"accessory2"), "a Pocket 3 bag can be worn in the second ring slot")
	_expect(inv.capacity() == before + 20 + 18, "Pocket 3 adds 18 slots on top of the bag's 20 (%d -> %d)" % [before, inv.capacity()])
	_expect(inv.unequip(&"accessory2") and inv.capacity() == before, "unequipping it takes the bonus away again (%d)" % inv.capacity())
	_expect(inv.unequip(&"accessory1") and inv.capacity() == 100 and inv.slot_count == 100, "the last unequip returns to 100 slots (capacity %d, slots %d)" % [inv.capacity(), inv.slot_count])

func _test_overflow_unequip_refused() -> void:
	var inv = INV.new()
	inv.add(IS.make(&"woven_bag", 1))
	inv.equip_at(inv.find_first(&"woven_bag"))
	# Fill all 120 slots (119 bag items + the worn bag).
	for i in 119:
		inv.add(IS.make(&"stone", 1))
	_expect(inv.used_slots() == 119 and inv.slot_count == 120, "119 stones fill the bag up to 119/120 (%d/%d)" % [inv.used_slots(), inv.slot_count])
	var uids: Dictionary = inv.uids()
	_expect(not inv.unequip(&"accessory1"), "unequipping the bag into a bag that cannot hold the 119 stones + itself is refused")
	_expect(inv.equipped_in(&"accessory1") != null, "the refused bag stays worn")
	_expect(inv.used_slots() == 119 and inv.slot_count == 120 and inv.uids() == uids, "nothing was lost by the refused unequip (%d/%d)" % [inv.used_slots(), inv.slot_count])
	_expect(inv.count_of(&"stone") == 119, "all 119 stones survived (%d)" % inv.count_of(&"stone"))

func _test_save_load_instances_and_capacity() -> void:
	var inv = INV.new()
	inv.add(IS.make(&"woven_bag", 1))
	inv.equip_at(inv.find_first(&"woven_bag"))
	for k in 8:
		inv.add(IS.make(&"raptor_bone", 1, {}, 1 + k))
	var before := {}
	for s in inv.slots:
		if s:
			before[s.uid] = [s.def_id, s.level]
	var back = _reload(inv)
	_expect(back.capacity() == inv.capacity() and back.slot_count == inv.capacity(), "save/load keeps every slot (%d capacity, %d slots)" % [back.capacity(), back.slot_count])
	var after := {}
	for s in back.slots:
		if s:
			after[s.uid] = [s.def_id, s.level]
	_expect(after == before, "save/load keeps every instance and its level (%d before, %d after)" % [before.size(), after.size()])
	_expect(back.equipped_in(&"accessory1") != null and back.equipped_in(&"accessory1").def_id == &"woven_bag", "the worn bag comes back worn")

func _test_bag_item_exists() -> void:
	var d: Variant = get_root().get_node("Data").item(&"woven_bag")
	_expect(d != null and d.bag_slots > 0, "woven_bag is a data-only bag item with bag_slots (%s)" % (d.bag_slots if d else "missing"))
	var slot: StringName = INV.slot_for(d) if d else &""
	_expect(slot == &"accessory1", "the bag item wears in the ring slot (%s)" % slot)
