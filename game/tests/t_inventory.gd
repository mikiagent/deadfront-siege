extends SceneTree
## W2-INV: inventory and equipment by instance. Prints "[t_inventory] PASS" (or FAIL lines), exits 0/1.
##   Godot --headless --path game --script res://tests/t_inventory.gd
## Item scripts reference the Data autoload, so they load on the first frame after it exists.

var failures: Array[String] = []
var _done := false
var IS: GDScript
var INV: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	_test_equip_exact_instance()
	_test_bad_amounts()
	_test_worn_out_of_bag()
	_test_best_tool()
	_test_no_stacking()
	_test_split_migration()
	_test_legacy_equipment_migration()
	_test_hostile_worn()
	_test_identity_through_transfer()
	if failures.is_empty():
		print("[t_inventory] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_inventory] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _json(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))

## Save/load the way SaveGame does: bag rows then extras, both through JSON.
func _reload(inv, slots := -1, overflow = null):
	var back = INV.new(slots if slots > 0 else inv.slot_count)
	back.load_array(_json(inv.to_array()), overflow)
	back.extras_from_dict(_json(inv.extras_to_dict()))
	return back

func _helm(level: int):
	return IS.make(&"raid_helm", 1, {}, level)

func _test_equip_exact_instance() -> void:
	var inv = INV.new(20)
	inv.add(IS.make(&"branch", 1))
	inv.add(_helm(1))
	inv.add(_helm(60))
	var i60: int = -1
	for i in inv.slot_count:
		if inv.slots[i] and inv.slots[i].def_id == &"raid_helm" and inv.slots[i].level == 60:
			i60 = i
	var uid60: String = inv.slots[i60].uid
	_expect(inv.equip_at(i60), "equip_at the L60 helm")
	inv.sort()
	var back = _reload(inv)
	var worn = back.equipped_in(&"head")
	_expect(worn != null and worn.level == 60 and worn.uid == uid60, "L60 stays equipped after a sort and a save/load (got lv %s)" % (worn.level if worn else -1))
	_expect(back.count_of(&"raid_helm") == 1 and back.slots[back.find_first(&"raid_helm")].level == 1, "the L1 helm is the one left in the bag")
	# The def-id form wears the highest level, not the first match.
	var inv2 = INV.new(20)
	inv2.add(_helm(1))
	inv2.add(_helm(60))
	inv2.equip(&"head", &"raid_helm")
	_expect(inv2.equipped_in(&"head").level == 60, "equip(slot, id) picks the highest-level instance")
	print("[t_inventory] exact equip: worn lv=%d uid_kept=%s bag_helm_lv=%d" % [worn.level if worn else -1, worn != null and worn.uid == uid60, back.slots[back.find_first(&"raid_helm")].level])

func _test_bad_amounts() -> void:
	var inv = INV.new(20)
	inv.add(IS.make(&"stone_shot", 30))
	inv.add(IS.make(&"berry", 2))
	var before: Array = inv.to_array()
	_expect(inv.remove_at(0, -100) == null, "remove_at(i, -100) returns null")
	_expect(inv.remove_at(0, 0) == null, "remove_at(i, 0) returns null")
	_expect(not inv.consume(&"stone_shot", 0), "consume(id, 0) returns false")
	_expect(not inv.consume(&"stone_shot", -5), "consume(id, -5) returns false")
	_expect(not inv.consume_by_category(&"food", 0), "consume_by_category(cat, 0) returns false")
	_expect(inv.to_array() == before, "bad amounts change nothing")
	print("[t_inventory] bad amounts: remove_at(-100)=null consume(0)=false unchanged=%s" % (inv.to_array() == before))

func _test_worn_out_of_bag() -> void:
	var inv = INV.new(20)
	for i in 19:
		inv.add(IS.make(&"branch", 1))
	inv.add(_helm(30))
	_expect(inv.used_slots() == 20 and not inv.can_accept(IS.make(&"branch", 1)), "20 items fill a 20-slot bag")
	_expect(inv.equip_at(inv.find_first(&"raid_helm")), "equipping works on a full bag (it frees a slot)")
	_expect(inv.used_slots() == 19 and inv.can_accept(IS.make(&"branch", 1)), "worn gear no longer occupies a bag slot (used %d)" % inv.used_slots())
	inv.add(IS.make(&"branch", 1))
	_expect(not inv.unequip(&"head") and inv.equipped_in(&"head") != null, "unequip into a full bag is refused and the helm stays worn")
	inv.remove_at(0, 1)
	var uid: String = inv.equipped_in(&"head").uid
	_expect(inv.unequip(&"head") and inv.equipped_in(&"head") == null, "unequip with room")
	var idx: int = inv.find_first(&"raid_helm")
	_expect(idx >= 0 and inv.slots[idx].uid == uid, "the unequipped helm is the same instance")
	# Swap: wearing a second helm puts the first back where the second was.
	inv.equip_at(idx)
	inv.remove_at(1, 1)
	inv.add(_helm(5))
	var j: int = -1
	for i in inv.slot_count:
		if inv.slots[i] and inv.slots[i].def_id == &"raid_helm":
			j = i
	inv.equip_at(j)
	_expect(inv.equipped_in(&"head").level == 5 and inv.slots[j] != null and inv.slots[j].uid == uid, "equipping over worn gear swaps it into the vacated slot")

func _pick(tier: String):
	return IS.make(&"work_pick", 1, {"material_tier": tier}, 1)

func _test_best_tool() -> void:
	var inv = INV.new(20)
	inv.add(_pick("stone"))
	inv.add(_pick("flint"))
	inv.add(IS.make(&"stone_knife", 1))
	var auto = inv.find_gather_tool(&"pick")
	_expect(inv.equipped_tool_index == -1 and auto != null and auto.material_tier() == &"flint", "with nothing equipped the flint pick beats the stone pick (got %s)" % (auto.material_tier() if auto else &"none"))
	_expect(inv.equipped_gather_tool() != null and inv.equipped_gather_tool().material_tier() == &"flint", "auto gather tool is the flint pick")
	inv.set_equipped_tool_index(0)
	_expect(inv.find_gather_tool(&"pick").material_tier() == &"stone", "a chosen stone pick is kept")
	inv.sort()
	_expect(inv.find_gather_tool(&"pick").material_tier() == &"stone", "the chosen tool follows its item through a sort")
	# A worn knife still works as a knife.
	var k = INV.new(20)
	k.add(IS.make(&"stone_knife", 1))
	k.equip_at(0)
	_expect(k.slots[0] == null and k.find_gather_tool(&"knife") != null, "a worn weapon still counts as a gather tool")
	print("[t_inventory] best tool auto=%s" % (auto.material_tier() if auto else &"none"))

func _test_no_stacking() -> void:
	var inv = INV.new(20)
	_expect(inv.add(IS.make(&"berry", 5)) == 0, "five berries fit")
	var uids := {}
	for i in 5:
		var s = inv.slots[i]
		if s and s.count == 1 and s.uid != "":
			uids[s.uid] = true
	_expect(inv.used_slots() == 5 and uids.size() == 5, "five berries are five instances in five slots with five uids (slots %d uids %d)" % [inv.used_slots(), uids.size()])
	inv.add(IS.make(&"stone_shot", 50))
	inv.add(IS.make(&"stone_shot", 50))
	_expect(inv.used_slots() == 6 and inv.count_of(&"stone_shot") == 100, "ammunition still stacks (slots %d)" % inv.used_slots())
	_expect(inv.consume(&"berry", 2) and inv.count_of(&"berry") == 3 and inv.used_slots() == 4, "consume takes whole instances")
	var full = INV.new(2)
	_expect(full.add(IS.make(&"berry", 5)) == 3 and full.used_slots() == 2, "a full bag returns the units that did not fit")
	_expect(not full.can_accept(IS.make(&"berry", 1)), "can_accept is false on a full bag")
	print("[t_inventory] no stacking: berries slots=%d uids=%d ammo_slots=1" % [5, uids.size()])

func _test_split_migration() -> void:
	# A pre-W2-INV bag: 12 stone in one row, a branch row, a 30-shot ammo row, all without uids.
	var legacy: Array = [{"id": "stone", "count": 12, "level": 3, "attributes": {"hardness": 2}}, null, {"id": "branch", "count": 2}, {"id": "stone_shot", "count": 30}]
	var bag = INV.new(6)
	var cargo = INV.new(3)
	cargo.add(IS.make(&"flint", 1))
	bag.load_array(_json(legacy), cargo)
	var stone: int = bag.count_of(&"stone") + cargo.count_of(&"stone")
	var uids := {}
	var lv_ok := true
	for inv in [bag, cargo]:
		for s in inv.slots:
			if s and s.def_id == &"stone":
				uids[s.uid] = true
				lv_ok = lv_ok and s.count == 1 and s.level == 3 and int(s.attributes.get("hardness", 0)) == 2
	_expect(stone == 12 and uids.size() == 12 and lv_ok, "12 stacked stone become 12 instances with their level and attributes (got %d, %d uids)" % [stone, uids.size()])
	_expect(bag.count_of(&"branch") + cargo.count_of(&"branch") == 2 and bag.count_of(&"stone_shot") == 30 and bag.slots[3].count == 30, "the branch row splits too and ammo stays one stack in its slot")
	_expect(bag.slot_count == 6 and bag.used_slots() == 6, "the bag fills to its size and does not grow when there is an overflow container")
	_expect(cargo.count_of(&"flint") == 1 and cargo.count_of(&"stone") > 0 and cargo.slot_count > 3, "overflow lands in cargo, which grows instead of dropping (cargo %d slots)" % cargo.slot_count)
	# No overflow container: the bag itself grows; nothing is deleted.
	var lone = INV.new(4)
	lone.load_array(_json(legacy))
	_expect(lone.count_of(&"stone") == 12 and lone.count_of(&"branch") == 2 and lone.count_of(&"stone_shot") == 30, "without overflow every unit is kept (bag grew to %d)" % lone.slot_count)
	# Idempotent: a migrated bag re-saves and reloads to the same rows.
	var again = INV.new(lone.slot_count)
	again.load_array(_json(lone.to_array()))
	_expect(_json(again.to_array()) == _json(lone.to_array()), "a migrated bag round-trips unchanged (uids kept)")
	# Rows past the size of the container are kept, not dropped as before.
	var pet = INV.new(2)
	pet.load_array(_json([null, null, {"id": "stone_shot", "count": 4}]))
	_expect(pet.count_of(&"stone_shot") == 4, "a row past the container's size is kept")
	print("[t_inventory] migration: stone=%d uids=%d bag=%d/%d cargo=%d slots lone_bag=%d" % [stone, uids.size(), bag.used_slots(), bag.slot_count, cargo.slot_count, lone.slot_count])

func _test_legacy_equipment_migration() -> void:
	var inv = INV.new(20)
	inv.load_array(_json([_helm(1).to_dict(), null, _helm(60).to_dict(), IS.make(&"stone_knife", 1).to_dict()]))
	inv.extras_from_dict(_json({"equipment": {"head": "raid_helm", "weapon": "stone_knife", "chest": "nope"}, "quick_food": ["berry", ""], "tool_index": 3}))
	_expect(inv.equipped_in(&"head") != null and inv.equipped_in(&"head").level == 60 and inv.slots[2] == null, "legacy head=raid_helm wears the L60 helm and takes it out of the bag")
	_expect(inv.equipped_in(&"weapon") != null and inv.slots[3] == null and inv.equipped_tool_index == -1, "legacy weapon moves out; a tool index on it is cleared")
	_expect(not inv.equipment.has("chest") and inv.quick_food[0] == "berry", "unknown legacy entries are dropped, quick food kept")
	var back = _reload(inv)
	_expect(back.equipped_in(&"head").level == 60 and back.equipped_in(&"head").uid == inv.equipped_in(&"head").uid, "the migrated equipment survives a save/load as itself")

func _test_hostile_worn() -> void:
	var inv = INV.new(20)
	var forged: Dictionary = _helm(60).to_dict()
	forged["count"] = 50
	forged["level"] = 9999
	inv.extras_from_dict(_json({"worn": {"head": forged, "body": IS.make(&"stone", 1).to_dict(), "legs": _helm(5).to_dict(), "tail": _helm(5).to_dict(), "arms": "raid_helm"}}))
	var h = inv.equipped_in(&"head")
	_expect(h != null and h.count == 1 and h.level == 60, "a forged worn helm loads as x1 L60")
	_expect(inv.equipped_in(&"body") == null and inv.equipped_in(&"legs") == null and not inv.equipment.has("tail") and inv.equipped_in(&"arms") == null, "worn rows in the wrong slot or of the wrong shape are dropped")

func _test_identity_through_transfer() -> void:
	var a = INV.new(4)
	var b = INV.new(4)
	a.add(IS.make(&"raptor_bone", 1, {"sheen": "black"}, 12))
	var uid: String = a.slots[0].uid
	_expect(a.transfer_to(b, 0) == 1 and a.slots[0] == null, "transfer moves the bone")
	var s = b.slots[0]
	_expect(s != null and s.uid == uid and s.level == 12 and str(s.attributes.get("sheen", "")) == "black", "the moved bone keeps its uid, level and attributes")
