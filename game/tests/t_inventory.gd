extends SceneTree
## W2-INV: inventory and equipment by instance. Prints "[t_inventory] PASS" (or FAIL lines), exits 0/1.
##   Godot --headless --path game --script res://tests/t_inventory.gd
## Item scripts reference the Data autoload, so they load on the first frame after it exists.

const FIX := "res://tests/fixtures/"
const TMP := "user://t_inventory"

## Captures printed lines (the migration log) and counts SCRIPT ERRORs: a test that aborts on one
## (old code without a method) must fail, not just stop printing.
class LineLog extends Logger:
	var lines: PackedStringArray = []
	var script_errors := 0
	func _log_message(message: String, _error: bool) -> void:
		lines.append(message)
	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			script_errors += 1

var failures: Array[String] = []
var _done := false
var IS: GDScript
var INV: GDScript
var log := LineLog.new()

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	OS.add_logger(log)
	var tests: Array[Callable] = [_test_equip_exact_instance, _test_bad_amounts, _test_worn_out_of_bag,
		_test_best_tool, _test_no_stacking, _test_split_migration, _test_legacy_equipment_migration,
		_test_hostile_worn, _test_identity_through_transfer, _test_real_saves_split,
		_test_overflow_to_home_storage, _test_stack_bigger_than_bag, _test_round_trip_keeps_uids,
		_test_worn_gear_kept, _test_currency_stacks, _test_visual_groups, _test_server_store_migration, _test_default_pick_spares_valuable,
		_test_legacy_ceiling, _test_duplicate_uids, _test_pocket_capacity, _test_grown_container_reloads, _test_journal_before_split,
		_test_tip_names_traits, _test_default_pick_across_defs, _test_forged_worn_row, _test_split_rows_without_uid,
		_test_journal_rules_change, _test_unique_uids_across_containers, _test_default_pick_value_before_overlap]
	for t in tests:
		var errs := log.script_errors
		t.call()
		# A SCRIPT ERROR returns early from the test (old code without a method): that is a failure.
		_expect(log.script_errors == errs, "%s stopped on a SCRIPT ERROR" % t.get_method())
	_expect(log.script_errors == 0, "no SCRIPT ERROR (got %d)" % log.script_errors)
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
	var back = INV.new(slots if slots > 0 else inv.base_slots)
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
	var back = _reload(inv)
	var worn = back.equipped_in(&"head")
	_expect(worn != null and worn.level == 60 and worn.uid == uid60, "L60 stays equipped after a save/load (got lv %s)" % (worn.level if worn else -1))
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
	var wrong = INV.new(4)
	wrong.add(IS.make(&"branch", 1))
	wrong.add(_helm(1))
	_expect(not wrong.equip_at(0, &"weapon") and not wrong.equip_at(1, &"legs") and wrong.used_slots() == 2, "an item only goes into its own slot")
	var loot = INV.new(1)
	loot.add_growing(IS.make(&"raw_meat", 3))
	_expect(loot.count_of(&"raw_meat") == 3 and loot.slot_count == 3, "add_growing keeps every unit (corpse loot)")

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
	_expect(inv.equipped_in(&"body") == null and inv.equipped_in(&"legs") == null and not inv.equipment.has("tail") and inv.equipped_in(&"arms") == null, "worn rows in the wrong slot or of the wrong shape are not worn")
	# Review 3 (spec 05:11 never delete): a real item that cannot be worn where it was saved (its
	# def's slot changed, e.g. an items.json category edit) goes to the bag, logged; a non-row is not an item.
	var lines := log.lines.size()
	_expect(inv.count_of(&"stone") == 1 and inv.count_of(&"raid_helm") == 2 and inv.used_slots() == 3, "the stone (body) and the helms (legs, tail) are in the bag (stone %d helm %d used %d)" % [inv.count_of(&"stone"), inv.count_of(&"raid_helm"), inv.used_slots()])
	var full = INV.new(2)
	full.add(IS.make(&"stone", 2, {}, 1))
	full.extras_from_dict(_json({"worn": {"legs": _helm(7).to_dict()}}))
	var moved := Array(log.lines.slice(lines)).filter(func (l: String) -> bool: return l.contains("moved to the bag"))
	_expect(full.count_of(&"raid_helm") == 1 and full.count_of(&"stone") == 2 and moved.size() == 1, "a full bag grows for an unwearable worn helm rather than drop it, and says so (helm %d, %d log lines)" % [full.count_of(&"raid_helm"), moved.size()])

func _test_identity_through_transfer() -> void:
	var a = INV.new(4)
	var b = INV.new(4)
	a.add(IS.make(&"raptor_bone", 1, {"sheen": "black"}, 12))
	var uid: String = a.slots[0].uid
	_expect(a.transfer_to(b, 0) == 1 and a.slots[0] == null, "transfer moves the bone")
	var s = b.slots[0]
	_expect(s != null and s.uid == uid and s.level == 12 and str(s.attributes.get("sheen", "")) == "black", "the moved bone keeps its uid, level and attributes")

# ---------------------------------------------------------------- real old saves (W2-INV migration)

## A save file through the loader's own read path: parse, schema migrations, sanitizer.
func _read_save(path: String) -> Dictionary:
	var r: Dictionary = (load("res://scripts/core/save_migrations.gd") as GDScript).read(path)
	_expect(r.has("data"), "%s reads (%s)" % [path.get_file(), r.get("error", "")])
	return r.get("data", {})

## A base fixture with edits, written under user:// and read back through the same path.
func _read_edited(name: String, edit: Callable) -> Dictionary:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + name))
	edit.call(raw)
	DirAccess.make_dir_recursive_absolute(TMP)
	var path := TMP.path_join("edited_" + name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	return _read_save(path)

## The item containers of a save, loaded the way SaveGame._apply does: home cargo (60 slots,
## World.cargo_home) first, then the bag with its overflow going to that cargo, then worn gear;
## building contents and pet bags load on their own.
func _load_containers(data: Dictionary) -> Dictionary:
	var cargo = INV.new(60)
	cargo.load_array(data.get("home", {}).get("cargo", []))
	var bag = INV.new()
	bag.load_array(data.get("player", {}).get("inventory", []), cargo)
	bag.extras_from_dict(data.get("player", {}).get("inventory_extras", {}))
	var others: Array = []
	for b in data.get("home", {}).get("buildings", []) + data.get("away", {}).get("buildings", []):
		var contents: Array = b.get("contents") if b.get("contents") is Array else []
		var inv = INV.new(maxi(1, contents.size()))
		inv.load_array(contents)
		others.append(inv)
	for p in data.get("pets", []):
		var rows: Array = p.get("bag", [])
		var inv = INV.new(maxi(1, rows.size()))
		inv.load_array(rows)
		others.append(inv)
	return {"bag": bag, "cargo": cargo, "others": others}

## Units per item id in a raw old save: bag, home cargo, building contents, pet bags. Old worn
## gear is named by id and is one of the bag's own units, so it adds nothing.
func _raw_units(raw: Dictionary) -> Dictionary:
	var rows: Array = []
	rows.append_array(raw.get("player", {}).get("inventory", []))
	rows.append_array(raw.get("home", {}).get("cargo", []))
	for b in raw.get("home", {}).get("buildings", []) + raw.get("away", {}).get("buildings", []):
		if b.get("contents") is Array:
			rows.append_array(b.contents)
	for p in raw.get("pets", []):
		rows.append_array(p.get("bag", []))
	var n := {}
	for r in rows:
		if r is Dictionary and str(r.get("id", "")) != "_slot_lock":
			n[str(r.id)] = int(n.get(str(r.id), 0)) + int(r.get("count", 1))
	return n

## Every occupant of the loaded containers, worn gear included.
func _all_stacks(c: Dictionary) -> Array:
	var out: Array = []
	for inv in [c.bag, c.cargo] + c.others:
		for s in inv.slots:
			if s != null and s.def_id != &"_slot_lock":
				out.append(s)
	for slot in c.bag.equipment:
		if c.bag.equipment[slot] is RefCounted:
			out.append(c.bag.equipment[slot])
	return out

func _units_of(stacks: Array) -> Dictionary:
	var n := {}
	for s in stacks:
		n[str(s.def_id)] = int(n.get(str(s.def_id), 0)) + s.count
	return n

func _total(units: Dictionary) -> int:
	var t := 0
	for k in units:
		t += int(units[k])
	return t

## [rows of non-stacking items with count != 1, rows without a uid, distinct uids, such rows].
func _instance_stats(stacks: Array) -> Array:
	var multi := 0
	var blank := 0
	var uids := {}
	var rows := 0
	for s in stacks:
		if s.def() == null or s.def().stack_max > 1:
			continue
		rows += 1
		multi += 1 if s.count != 1 else 0
		blank += 1 if s.uid == "" else 0
		uids[s.uid] = true
	return [multi, blank, uids.size(), rows]

func _migration_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for l in log.lines:
		if l.begins_with("[inv] migration:"):
			out.append(l)
	return out

## The base's own fixtures (schema 1 and v3 goldens, stacked rows, def-id worn gear): every unit
## survives, per item id and in total, and each non-stacking unit is its own instance with a uid.
func _test_real_saves_split() -> void:
	for name in ["save_v1.json", "save_v3_golden.json", "save_v3_away_golden.json"]:
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + name))
		var want := _raw_units(raw)
		var c := _load_containers(_read_save(FIX + name))
		var stacks := _all_stacks(c)
		var got := _units_of(stacks)
		var st := _instance_stats(stacks)
		_expect(got == want and _total(got) == _total(want), "%s: every unit survives (want %s total %d, got %s total %d)" % [name, want, _total(want), got, _total(got)])
		_expect(st[0] == 0 and st[1] == 0 and st[2] == st[3] and st[3] > 0, "%s: %d non-stacking rows, each one unit with its own uid (multi=%d blank=%d uids=%d)" % [name, st[3], st[0], st[1], st[2]])
		print("[t_inventory] real %s units=%d instances=%d bag=%d/%d" % [name, _total(got), st[3], c.bag.used_slots(), c.bag.slot_count])

## The golden's old 20-slot bag topped up with legal stacks (stone x20, the old stack_max): more
## units than 100 slots. The bag fills, the rest lands in home cargo, and the move is logged.
func _test_overflow_to_home_storage() -> void:
	var edit := func (raw: Dictionary) -> void:
		var rows: Array = raw.player.inventory
		for i in rows.size():
			if rows[i] == null:
				rows[i] = {"id": "stone", "count": 20, "level": 2}
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "save_v3_golden.json"))
	edit.call(raw)
	var want := _raw_units(raw)
	var before := _migration_lines().size()
	var c := _load_containers(_read_edited("save_v3_golden.json", edit))
	var got := _units_of(_all_stacks(c))
	var lines := _migration_lines().slice(before)
	var cargo_stone: int = c.cargo.count_of(&"stone")
	_expect(_total(want) > 100 and got == want, "a full old bag (%d units) keeps every unit: %s vs %s" % [_total(want), got, want])
	# 99: the bag fills to 100, then the old head=raid_helm leaves it for its worn slot.
	_expect(c.bag.slot_count == 100 and c.bag.used_slots() == 99 and cargo_stone > 0 and c.cargo.count_of(&"flint") == 4, "the bag fills, the rest goes to home cargo (bag %d/%d, cargo stone %d)" % [c.bag.used_slots(), c.bag.slot_count, cargo_stone])
	var logged := ""
	for l in lines:
		if l.contains("to home storage") and l.contains("stone x%d" % cargo_stone):
			logged = l.strip_edges()
	_expect(logged != "", "the overflow is logged with what moved (%s)" % [lines])
	print("[t_inventory] overflow units=%d bag=%d cargo_stone=%d log=\"%s\"" % [_total(got), c.bag.used_slots(), cargo_stone, logged])

## One old row bigger than the whole bag: armor_scute x150 (old stack_max 999).
func _test_stack_bigger_than_bag() -> void:
	var edit := func (raw: Dictionary) -> void:
		raw.player.inventory[10] = {"id": "armor_scute", "count": 150, "level": 7}
	var c := _load_containers(_read_edited("save_v3_golden.json", edit))
	var scute: int = c.bag.count_of(&"armor_scute") + c.cargo.count_of(&"armor_scute")
	var levels := true
	for s in _all_stacks(c):
		if s.def_id == &"armor_scute":
			levels = levels and s.count == 1 and s.level == 7
	_expect(scute == 150 and levels, "150 scutes in one old row become 150 L7 instances (got %d)" % scute)
	_expect(c.bag.used_slots() == 99 and c.cargo.count_of(&"armor_scute") >= 150 - 100, "what the bag cannot hold is in home cargo (cargo %d)" % c.cargo.count_of(&"armor_scute"))

## Migrated once, a save keeps every uid through save -> JSON -> load, worn gear included.
func _test_round_trip_keeps_uids() -> void:
	var c := _load_containers(_read_save(FIX + "save_v3_golden.json"))
	var rows: Variant = _json(c.bag.to_array())
	var extras: Variant = _json(c.bag.extras_to_dict())
	var cargo_rows: Variant = _json(c.cargo.to_array())
	var cargo = INV.new(60)
	cargo.load_array(cargo_rows)
	var bag = INV.new()
	bag.load_array(rows, cargo)
	bag.extras_from_dict(extras)
	var same: bool = _json(bag.to_array()) == rows and _json(cargo.to_array()) == cargo_rows and _json(bag.extras_to_dict()) == extras
	var worn = bag.equipped_in(&"head")
	_expect(same, "a migrated save reloads to the same rows and uids (bag, cargo, worn)")
	_expect(worn != null and worn.uid != "" and worn.uid == c.bag.equipped_in(&"head").uid, "the worn helm keeps its uid through the reload")
	var lines := _migration_lines().size()
	var again = INV.new()
	again.load_array(rows, INV.new(60))
	_expect(_migration_lines().size() == lines, "a migrated bag does not migrate again (no new log line)")

## The golden's def-id head=raid_helm: that helm is worn after the load, out of the bag, saved
## whole under "worn", and still the one unit the old save had.
func _test_worn_gear_kept() -> void:
	var c := _load_containers(_read_save(FIX + "save_v3_golden.json"))
	var worn = c.bag.equipped_in(&"head")
	var extras: Dictionary = c.bag.extras_to_dict()
	_expect(worn != null and worn.def_id == &"raid_helm" and c.bag.find_first(&"raid_helm") < 0, "the old head=raid_helm is worn and out of the bag")
	_expect(extras.has("worn") and str(extras.worn.get("head", {}).get("id", "")) == "raid_helm" and not extras.has("equipment"), "worn gear saves whole under worn (%s)" % [extras.keys()])
	_expect(_units_of(_all_stacks(c)).get("raid_helm", 0) == 1, "still exactly one raid_helm")

## Currency (prompt 05: "currency in a wallet") and counted consumables keep stacking, in play
## and through the migration; a material beside them splits.
func _test_currency_stacks() -> void:
	var data: Node = get_root().get_node("Data")
	var DEF := load("res://scripts/items/item_def.gd") as GDScript
	data.items[&"t_coin"] = DEF.from_dict({"id": "t_coin", "display_name": "Test coin", "categories": ["currency"], "stack_max": 9999})
	var inv = INV.new(10)
	inv.add(IS.make(&"t_coin", 400))
	inv.add(IS.make(&"t_coin", 600))
	_expect(inv.used_slots() == 1 and inv.count_of(&"t_coin") == 1000, "coins stack in one slot (slots %d)" % inv.used_slots())
	var old = INV.new(10)
	old.load_array(_json([{"id": "t_coin", "count": 5000}, {"id": "stone_shot", "count": 30}, {"id": "stone", "count": 4}]))
	_expect(old.slots[0] != null and old.slots[0].count == 5000 and old.slots[1].count == 30 and old.used_slots() == 2 + 4, "an old coin row and an ammo row stay one stack each; stone splits (slots %d)" % old.used_slots())
	data.items.erase(&"t_coin")

## Visual grouping: one entry per item id listing its instances' slots; nothing merges.
func _test_visual_groups() -> void:
	var inv = INV.new(100)
	for i in 12:
		inv.add(IS.make(&"raptor_bone", 1, {}, i + 1))
	inv.add(IS.make(&"stone_shot", 30))
	inv.add(IS.make(&"berry", 3))
	var groups: Array = inv.groups()
	var bones: Dictionary = groups[0] if not groups.is_empty() else {}
	_expect(groups.size() == 3 and bones.get("def_id") == &"raptor_bone" and (bones.get("slots", []) as Array).size() == 12 and int(bones.get("units", 0)) == 12, "12 bones are one group of 12 slots (groups %d)" % groups.size())
	_expect(inv.used_slots() == 16, "grouping merges nothing: 12 + 1 + 3 slots stay used (%d)" % inv.used_slots())

## Spec 05:23 ("protect valuable items from default auto-consumption"): with no picks, a twine
## (fibre x2) takes the plain lv 1 stalks, oldest first, not the trait or lv 5 one that sit earlier.
func _test_default_pick_spares_valuable() -> void:
	var CR := load("res://scripts/items/crafting.gd") as GDScript
	var inv = INV.new(10)
	var rows := [[{"hardness": 2}, 1, 100], [{}, 5, 100], [{"climate": "grassland", "level": 1}, 1, 300], [{}, 1, 200]]
	for i in rows.size():
		var s = IS.make(&"fibre_stalk", 1, rows[i][0], rows[i][1])
		s.created_at = rows[i][2]
		inv.slots[i] = s
	var rec: Dictionary = get_root().get_node("Data").recipes.get(&"twine", {})
	var picks: Array[int] = CR.default_picks(inv, rec)
	var spent: Array[int] = []
	for part in CR._plan(inv, rec, picks)[0].parts:
		spent.append(int(part.idx))
	_expect(picks == [3] and spent == [3, 2], "default twine spends the plain oldest stalks 3 then 2, not the trait (0) or lv 5 (1) one (picks %s spent %s)" % [picks, spent])
	var stone = IS.make(&"stone", 1, {}, 1)
	_expect(not stone.attributes.is_empty() and INV.spend_key(stone)[0] == 0, "a def's own default attributes (stone tint) are not traits (%s)" % [stone.attributes])

## Review 2: the lead's own def is only a tie-break inside equal spend keys. A default twine spends
## the plain lv1 stalk and the plain lv1 palm frond, not the lv40 stalk (with or without a trait);
## when every candidate carries a trait the plan says so (spec 13:486), so the UI can ask for a pick.
func _test_default_pick_across_defs() -> void:
	var CR := load("res://scripts/items/crafting.gd") as GDScript
	var rec: Dictionary = get_root().get_node("Data").recipes.get(&"twine", {})
	for traits in [{"hardness": 9}, {}]:
		var inv = INV.new(10)
		inv.slots[0] = IS.make(&"fibre_stalk", 1, {}, 1)
		inv.slots[1] = IS.make(&"fibre_stalk", 1, traits, 40)
		inv.slots[2] = IS.make(&"palm_frond", 1, {}, 1)
		var picks: Array[int] = CR.default_picks(inv, rec)
		var spent: Array[int] = []
		for part in CR._plan(inv, rec, picks)[0].parts:
			spent.append(int(part.idx))
		spent.sort()
		_expect(spent == [0, 2], "default twine spends stalk lv1 and the plain frond lv1, not the lv40 stalk %s (spent %s)" % [traits, spent])
		_expect(not CR.plan_spends_traits(inv, rec, picks), "a default that spends no trait does not ask for a pick %s" % [traits])
	var rare = INV.new(10)
	rare.slots[0] = IS.make(&"fibre_stalk", 1, {"hardness": 7}, 30)
	rare.slots[1] = IS.make(&"fibre_stalk", 1, {"hardness": 9}, 40)
	var rp: Array[int] = CR.default_picks(rare, rec)
	_expect(CR.picks_valid(rare, rec, rp) and CR.plan_spends_traits(rare, rec, rp), "only trait stalks: the default plan says it spends a trait")

## The bag slots a default plan spends, sorted.
func _spent(CR: GDScript, inv, rec: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for row in CR._plan(inv, rec, CR.default_picks(inv, rec)):
		for part in row.parts:
			out.append(int(part.idx))
	out.sort()
	return out

func _bag_of(rows: Array):
	var inv = INV.new(20)
	for i in rows.size():
		inv.slots[i] = IS.make(rows[i][0], 1, rows[i][1], rows[i][2])
	return inv

## Review 3 (spec 05:23): value comes before "dedicated before dual-category". A straw roll (fibre x3,
## lashing x1) spends 4 plain reeds, not 3 lv40 trait stalks; a slingshot spends a plain raptor bone,
## not the rare dense bone. A cheap dual unit a later slot needs is left for it (3 reeds, a frond:
## no trait stalk goes), and when value first cannot fill every slot the dedicated-first plan does.
func _test_default_pick_value_before_overlap() -> void:
	var CR := load("res://scripts/items/crafting.gd") as GDScript
	var recipes: Dictionary = get_root().get_node("Data").recipes
	var trait9 := {"hardness": 9}
	var straw: Dictionary = recipes.get(&"straw_roll_kit", {})
	var inv = _bag_of([[&"fibre_stalk", trait9, 40], [&"fibre_stalk", trait9, 40], [&"fibre_stalk", trait9, 40],
		[&"reed", {}, 1], [&"reed", {}, 1], [&"reed", {}, 1], [&"reed", {}, 1]])
	var spent := _spent(CR, inv, straw)
	_expect(spent == [3, 4, 5, 6], "straw roll spends the 4 plain reeds, not the lv40 trait stalks (spent %s)" % [spent])
	var sling: Dictionary = recipes.get(&"slingshot", {})
	inv = _bag_of([[&"dense_bone", {"firm": 5}, 40], [&"raptor_bone", {}, 1], [&"raptor_bone", {}, 1], [&"branch", {}, 1],
		[&"twine", {}, 1], [&"twine", {}, 1]])
	spent = _spent(CR, inv, sling)
	_expect(spent == [1, 3, 4, 5], "slingshot spends a plain raptor bone and the branch, not the dense bone (spent %s)" % [spent])
	_expect(not CR.plan_spends_traits(inv, sling, CR.default_picks(inv, sling)), "the slingshot default spends no trait")
	inv = _bag_of([[&"fibre_stalk", trait9, 40], [&"fibre_stalk", trait9, 40], [&"reed", {}, 1], [&"reed", {}, 1],
		[&"reed", {}, 1], [&"palm_frond", {}, 5]])
	spent = _spent(CR, inv, straw)
	_expect(spent == [2, 3, 4, 5], "3 reeds and a frond: the third reed stays for the lashing, no trait stalk goes (spent %s)" % [spent])
	# handle, bone, blade_mat: value first takes the lv1 raptor bone as the handle, then the dense
	# bone is the only blade left for two slots; dedicated first (the branch) fills all three.
	var tri := {"id": "t_tri", "slots": [{"category": "handle", "count": 1}, {"category": "bone", "count": 1}, {"category": "blade_mat", "count": 1}], "output": {"id": "twine", "count": 1}}
	inv = _bag_of([[&"raptor_bone", {}, 1], [&"dense_bone", {}, 1], [&"branch", {}, 5]])
	spent = _spent(CR, inv, tri)
	_expect(spent == [0, 1, 2], "when value first runs a slot short, the dedicated-first plan still crafts (spent %s)" % [spent])

## Review 2: the worn row is a trust boundary. A forged worn helm (x5000, L9999, durability 1e9,
## a bad uid) read through the loader's own path loads as x1 L60 within the real durability ceiling.
func _test_forged_worn_row() -> void:
	var data := _read_edited("save_forged.json", func (raw: Dictionary) -> void:
		raw.player["inventory_extras"] = {"worn": {"head": {"id": "raid_helm", "count": 5000, "level": 9999,
			"durability": 1e9, "max_durability": 1e9, "uid": "not a uid"}}})
	var h = _load_containers(data).bag.equipped_in(&"head")
	var top: int = IS.make(&"raid_helm", 1, {}, 60).max_durability
	_expect(h != null and h.count == 1 and h.level == 60 and h.max_durability <= top and h.durability <= top and h.uid.begins_with("l"),
		"a forged worn helm loads as x1 L60 with durability <= %d (%s)" % [top, h.to_dict() if h else null])

## Review 2: a stored row with no uid must not mint ".1", ".2" for every such row (duplicates).
func _test_split_rows_without_uid() -> void:
	var CST := load("res://scripts/server/character_state.gd") as GDScript
	var row: Dictionary = IS.make(&"stone", 1, {}, 2).to_dict()
	row.count = 3
	row.erase("uid")
	var d := {"bag": [row.duplicate(true), row.duplicate(true)]}
	CST.split_stacks(d)
	var seen := {}
	var dup := 0
	var units := 0
	for r in (d.bag as Array) + (d.get("storage", []) as Array):
		if r is Dictionary:
			units += int(r.count)
			var u := str(r.get("uid", ""))
			dup += 1 if u != "" and seen.has(u) else 0
			seen[u] = true
	_expect(dup == 0 and units == 6, "rows without a uid split into no duplicate uids and keep every unit (dup %d, units %d, uids %s)" % [dup, units, seen.keys()])

## Review 2: a journal written under other data rules (the stacking build) that no longer replays
## stops boot with a message that says what to do, not only "seq N did not replay".
func _test_journal_rules_change() -> void:
	var CS := load("res://scripts/server/character_store.gd") as GDScript
	var WF := load("res://scripts/server/world_facade.gd") as GDScript
	var PV := load("res://scripts/server/provenance.gd") as GDScript
	var dir := TMP.path_join("srv_rules")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	var a = CS.new(WF.new(), dir, 5)
	a.open()
	a.apply("char.create", 1, {"name": "Old"}, 10)
	var row: Dictionary = IS.make(&"stone", 1, {}, 2).to_dict()
	row.count = 20
	var d: Dictionary = a.s.chars["1"]
	d.bag[0] = PV.stamp(row, PV.item_uid(2, 0), "gather", 2)
	a.s.minted = {"stone": 20}
	a.s.seq = 2
	a.s.chars["1"] = CS.norm(d)
	a.snapshot()
	a.apply("act.deposit", 1, {"bag_slot": 0, "count": 5}, 20)
	a = null
	# The old build's snapshot: its data hash differs, and its slot 0 is not what the journal saw.
	var snap := dir.path_join("snapshot.json")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(snap))
	parsed["data"] = "old build"
	parsed.chars["1"].bag[0] = null
	var f := FileAccess.open(snap, FileAccess.WRITE)
	f.store_string(JSON.stringify(parsed))
	f.close()
	var why: String = CS.new(WF.new(), dir, 5).open()
	_expect(why.contains("did not replay") and why.contains("previous build"), "a journal that fails under changed rules says to snapshot on the previous build (%s)" % why)

## Review 2 (spec 05:20/26): a uid held in two containers that load on their own (a bag row, a
## basket row, a pet bag row) is kept by the first holder; the others are reminted.
func _test_unique_uids_across_containers() -> void:
	var IM := load("res://scripts/items/inventory_migration.gd") as GDScript
	var bag = INV.new(4)
	var basket = INV.new(4)
	var pet = INV.new(4)
	for inv in [bag, basket, pet]:
		inv.load_array(_json([{"id": "stone", "count": 1, "uid": "laaaa0001"}]))
	var n: int = IM.unique_uids([bag, basket, bag, pet])
	var u := [bag.slots[0].uid, basket.slots[0].uid, pet.slots[0].uid]
	_expect(n == 2 and u[0] == "laaaa0001" and u[1] != u[0] and u[2] != u[0] and u[1] != u[2], "one holder keeps a shared uid, the rest are reminted, a container listed twice is not (n %d, %s)" % [n, u])

# ---------------------------------------------------------------- server character store

## A character as the pre-W2-INV server stored it (a 20-slot bag of stamped stacks, the worn helm
## in it by uid) boots through CharacterStore.open(): every unit becomes its own row with a
## deterministic uid, the bag grows to 100, the rest goes to its home storage, the invariants hold,
## and the next boot changes nothing.
func _test_server_store_migration() -> void:
	var CS := load("res://scripts/server/character_store.gd") as GDScript
	var WF := load("res://scripts/server/world_facade.gd") as GDScript
	var PV := load("res://scripts/server/provenance.gd") as GDScript
	var dir := TMP.path_join("srv")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	var a = CS.new(WF.new(), dir, 5)
	_expect(a.open() == "", "a fresh store opens")
	a.apply("char.create", 1, {"name": "Legacy"}, 10)
	var bag: Array = []
	bag.resize(20)
	var units := {"stone": 0, "berry": 20, "stone_shot": 30, "raid_helm": 1}
	for i in 15:
		var row: Dictionary = IS.make(&"stone", 1, {}, 2).to_dict()
		row.count = 20
		bag[i] = PV.stamp(row, PV.item_uid(2 + i, 0), "gather", 2 + i)
		units.stone += 20
	var berry: Dictionary = IS.make(&"berry", 1, {}, 4).to_dict()
	berry.count = 20
	bag[15] = PV.stamp(berry, "i20.0", "gather", 20)
	var shot: Dictionary = IS.make(&"stone_shot", 30).to_dict()
	bag[16] = PV.stamp(shot, "i21.0", "craft", 21)
	bag[17] = PV.stamp(IS.make(&"raid_helm", 1, {}, 60).to_dict(), "i22.0", "craft", 22)
	var d: Dictionary = a.s.chars["1"]
	d.bag = bag
	d.equipment = {"head": "i22.0"}
	a.s.minted = units.duplicate()
	a.s.seq = 22
	a.s.chars["1"] = CS.norm(d)
	_expect(a.invariants().is_empty(), "the stacked fixture is a valid old state (%s)" % [a.invariants()])
	a.close()
	var before := log.lines.size()
	var b = CS.new(WF.new(), dir, 5)
	_expect(b.open() == "", "the stacked store boots")
	var ch: Dictionary = b.s.chars["1"]
	var rows: Array = (ch.bag as Array) + (ch.get("storage", []) as Array)
	var got := {}
	var multi := 0
	var uids := {}
	for r in rows:
		if r is Dictionary:
			got[str(r.id)] = int(got.get(str(r.id), 0)) + int(r.count)
			if str(r.id) != "stone_shot":
				multi += 1 if int(r.count) != 1 else 0
			uids[str(r.get("uid", ""))] = true
	var used := (ch.bag as Array).filter(func (r: Variant) -> bool: return r is Dictionary).size()
	_expect(got == units, "every server unit survives (want %s got %s)" % [units, got])
	_expect(multi == 0 and uids.size() == _total(units) - 29 and not uids.has(""), "one row per unit, distinct uids (multi %d uids %d)" % [multi, uids.size()])
	_expect((ch.bag as Array).size() == 100 and used == 100 and (ch.get("storage", []) as Array).size() == _total(units) - 29 - 100, "the bag grows to 100 and fills; the rest is in home storage (bag %d/%d, storage %d)" % [used, (ch.bag as Array).size(), (ch.get("storage", []) as Array).size()])
	_expect(str(ch.bag[0].uid) == "i2.0" and uids.has("i2.0.19") and str(ch.equipment.get("head", "")) == "i22.0" and b.character(1).find_uid("i22.0") >= 0, "the first unit keeps the stack's uid, the rest get <uid>.<k>, the worn helm stays worn")
	_expect(b.invariants().is_empty(), "the store's invariants hold after the split (%s)" % [b.invariants()])
	var logged := false
	for l in log.lines.slice(before):
		logged = logged or (l.begins_with("[srv] migration:") and l.contains("home storage"))
	_expect(logged, "the server migration is logged")
	var hash: String = b.state_hash()
	b.close()
	var mid := log.lines.size()
	var c = CS.new(WF.new(), dir, 5)
	_expect(c.open() == "" and c.state_hash() == hash, "the next boot reads the migrated snapshot unchanged")
	var again := false
	for l in log.lines.slice(mid):
		again = again or l.begins_with("[srv] migration:")
	_expect(not again, "and does not migrate again")
	var dep: Dictionary = c.apply("act.deposit", 1, {"bag_slot": 0, "count": 1}, 30)
	_expect(bool(dep.get("ok", false)) and str(dep.r.asset.uid) == "i2.0", "a migrated unit leaves by its own uid (%s)" % [dep])
	c.close()
	print("[t_inventory] server migration units=%d bag=%d storage=%d uids=%d" % [_total(got), used, (ch.get("storage", []) as Array).size(), uids.size()])

# ---------------------------------------------------------------- review fixes (2026-10-20)

## The old sanitizer's ceiling was 999 for every item without durability or a multi-slot span
## (base item_def.gd: owner rule 2026-09-20), not the items.json stack_max. Legal old rows above
## the data value (stone x150, bandage x40 in the bag, fibre_stalk x400 in home cargo) keep every
## unit through SaveMigrations.read (sanitizer) and the loader.
func _test_legacy_ceiling() -> void:
	var edit := func (raw: Dictionary) -> void:
		var rows: Array = raw.player.inventory
		var free: Array[int] = []
		for i in rows.size():
			if rows[i] == null:
				free.append(i)
		rows[free[0]] = {"id": "stone", "count": 150, "level": 2}
		rows[free[1]] = {"id": "bandage", "count": 40}
		(raw.home.cargo as Array).append({"id": "fibre_stalk", "count": 400, "level": 3})
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "save_v3_golden.json"))
	edit.call(raw)
	var want := _raw_units(raw)
	var got := _units_of(_all_stacks(_load_containers(_read_edited("save_v3_golden.json", edit))))
	for id in ["stone", "bandage", "fibre_stalk"]:
		_expect(int(got.get(id, 0)) == int(want.get(id, 0)), "old %s rows keep every unit (want %d got %d)" % [id, int(want.get(id, 0)), int(got.get(id, 0))])
	_expect(got == want, "a legal old save above the data stack_max keeps every unit (want %s got %s)" % [want, got])
	var data: Node = get_root().get_node("Data")
	_expect(data.item(&"stone").legacy_stack_max == 999 and data.item(&"work_pick").legacy_stack_max < 999, "legacy ceiling: 999, but a durability tool keeps its data value (stone %d, work_pick %d)" % [data.item(&"stone").legacy_stack_max, data.item(&"work_pick").legacy_stack_max])
	print("[t_inventory] legacy ceiling stone=%d bandage=%d fibre_stalk=%d" % [int(got.get("stone", 0)), int(got.get("bandage", 0)), int(got.get("fibre_stalk", 0))])

## Spec 05:26 "Test duplicate IDs": rows that share a uid load as instances with distinct uids; the
## first holder keeps it (home cargo loads first, then the bag, then worn gear).
func _test_duplicate_uids() -> void:
	var u := "l00aa11"
	var bone := func (n: int, id := u) -> Dictionary:
		return {"id": "raptor_bone", "count": n, "level": 4, "uid": id, "origin": "gather", "created_at": 100}
	var inv = INV.new(20)
	inv.load_array(_json([bone.call(1), bone.call(1), bone.call(3)]))
	var ids := {}
	for s in inv.slots:
		if s:
			ids[s.uid] = int(ids.get(s.uid, 0)) + 1
	_expect(inv.count_of(&"raptor_bone") == 5 and ids.size() == 5 and inv.slots[0].uid == u, "dup-uid rows: 5 instances with 5 uids, the first row keeps %s (%s)" % [u, ids])
	var helm: Dictionary = _helm(30).to_dict()
	helm.uid = "lbb22"
	var cargo = INV.new(10)
	cargo.load_array(_json([bone.call(1, "lcc33")]))
	var bag = INV.new(10)
	bag.load_array(_json([helm, bone.call(1, "lcc33")]), cargo)
	bag.extras_from_dict(_json({"worn": {"head": helm}}))
	var worn = bag.equipped_in(&"head")
	_expect(bag.slots[0].uid == "lbb22" and worn != null and worn.uid != "" and worn.uid != "lbb22", "a worn helm with the bag helm's uid gets its own (bag %s worn %s)" % [bag.slots[0].uid, worn.uid if worn else "-"])
	_expect(cargo.slots[0].uid == "lcc33" and bag.slots[1].uid != "lcc33" and bag.slots[1].uid != "", "a bag row repeating a home cargo uid gets its own; cargo keeps it")
	print("[t_inventory] dup uids: instances=%d distinct=%d worn_same=%s" % [inv.count_of(&"raptor_bone"), ids.size(), worn != null and worn.uid == "lbb22"])

## Spec 05:11: worn equipment adds its bag_slots and Pocket +6 per level, once; unequip removes it;
## an unequip (or swap) that would shrink the bag below what it holds is refused and changes nothing.
func _test_pocket_capacity() -> void:
	var data: Node = get_root().get_node("Data")
	var DEF := load("res://scripts/items/item_def.gd") as GDScript
	data.items[&"t_pouch"] = DEF.from_dict({"id": "t_pouch", "display_name": "Test pouch", "categories": ["accessory"]})
	data.items[&"t_satchel"] = DEF.from_dict({"id": "t_satchel", "display_name": "Test satchel", "categories": ["accessory"], "bag_slots": 4})
	var inv = INV.new()
	inv.add(IS.make(&"t_pouch", 1, {"pocket": 2}))
	_expect(inv.equip_at(0) and inv.slot_count == 112 and inv.capacity() == 112, "a Pocket 2 pouch adds 12 slots (%d)" % inv.slot_count)
	inv.add(IS.make(&"t_satchel", 1))
	_expect(inv.equip_at(inv.find_first(&"t_satchel")) and inv.slot_count == 116 and inv.capacity() == 116, "a satchel's bag_slots add once, beside the pouch (%d)" % inv.slot_count)
	for i in 116:
		inv.add(IS.make(&"branch", 1))
	_expect(inv.used_slots() == 116 and not inv.unequip(&"accessory1") and inv.worn(&"accessory1") != null and inv.slot_count == 116, "a full bag refuses the pouch's unequip; it stays worn, nothing moves")
	# Room enough, but items sit in the slots the pouch gave: they move down, none is lost.
	for i in 20:
		inv.remove_at(i, 1)
	var before: Dictionary = inv.uids()
	_expect(inv.slots[110] != null and inv.unequip(&"accessory1") and inv.slot_count == 104 and inv.capacity() == 104, "unequip with room: the bag shrinks by 12 (%d)" % inv.slot_count)
	var after: Dictionary = inv.uids()
	var lost := 0
	for k in before:
		lost += 0 if after.has(k) else 1
	_expect(lost == 0 and inv.count_of(&"branch") == 96 and inv.find_first(&"t_pouch") >= 0, "every item survives the shrink and the pouch is back in the bag (lost %d)" % lost)
	# A swap to a smaller pouch in a full bag would cut off items: refused, the old one stays worn.
	inv.equip_at(inv.find_first(&"t_pouch"))
	while inv.used_slots() < inv.slot_count - 1:
		inv.add(IS.make(&"branch", 1))
	inv.add(IS.make(&"t_pouch", 1, {"pocket": 0}))
	var small: int = -1
	for i in inv.slot_count:
		if inv.slots[i] and inv.slots[i].def_id == &"t_pouch":
			small = i
	_expect(small >= 0 and not inv.equip_at(small, &"accessory1") and int(inv.worn(&"accessory1").attributes.get("pocket", 0)) == 2 and inv.slots[small].def_id == &"t_pouch", "a swap that shrinks a full bag is refused and undone")
	# Save and load: the bag comes back at its capacity, nothing goes to home storage, no migration.
	var lines := _migration_lines().size()
	var cargo = INV.new(60)
	var back = _reload(inv, -1, cargo)
	_expect(back.slot_count == 116 and back.used_slots() == inv.used_slots() and cargo.used_slots() == 0 and _migration_lines().size() == lines, "a Pocket bag reloads at 116 with every item, none to cargo (%d/%d, cargo %d)" % [back.used_slots(), back.slot_count, cargo.used_slots()])
	var forged = INV.new()
	forged.extras_from_dict(_json({"worn": {"accessory1": IS.make(&"t_pouch", 1, {"pocket": 1e9}).to_dict()}}))
	_expect(forged.slot_count == 100 + 60 * 6, "a forged Pocket level is capped (%d slots)" % forged.slot_count)
	data.items.erase(&"t_pouch")
	data.items.erase(&"t_satchel")
	print("[t_inventory] pocket: 100 -> 112 -> 116, refused full, shrink kept all, reload %d" % back.slot_count)

## A container that grew past its size (home cargo after a migration) reloads at its saved size and
## does not log a migration again.
func _test_grown_container_reloads() -> void:
	var cargo = INV.new(60)
	for i in 70:
		cargo.add_growing(IS.make(&"stone", 1, {}, 1 + i % 5))
	var rows: Variant = _json(cargo.to_array())
	var lines := _migration_lines().size()
	var back = INV.new(60)
	back.load_array(rows)
	_expect(back.slot_count == 70 and _json(back.to_array()) == rows and _migration_lines().size() == lines, "a 70-row cargo reloads as 70 rows with no migration log (slots %d, new lines %d)" % [back.slot_count, _migration_lines().size() - lines])

## The tip names an instance's traits; it does not dump the attribute dict (stone's tint).
func _test_tip_names_traits() -> void:
	var tip: String = IS.make(&"stone", 1, {"hardness": 2}, 3).tooltip()
	_expect(not tip.contains("attr") and not tip.contains("tint") and tip.contains("Hardness 2"), "the tip names traits, not the raw dict (%s)" % tip.replace("\n", " | "))

## An unclean shutdown left a journal written against stacked rows: it replays against those rows
## (a deposit of 5 from a 20-stack), then the character splits, so the boot matches what clients saw.
func _test_journal_before_split() -> void:
	var CS := load("res://scripts/server/character_store.gd") as GDScript
	var WF := load("res://scripts/server/world_facade.gd") as GDScript
	var PV := load("res://scripts/server/provenance.gd") as GDScript
	var dir := TMP.path_join("srv_journal")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	var a = CS.new(WF.new(), dir, 5)
	_expect(a.open() == "", "a fresh store opens (journal case)")
	a.apply("char.create", 1, {"name": "Crash"}, 10)
	var bag: Array = []
	bag.resize(20)
	var row: Dictionary = IS.make(&"stone", 1, {}, 2).to_dict()
	row.count = 20
	bag[0] = PV.stamp(row, PV.item_uid(2, 0), "gather", 2)
	var d: Dictionary = a.s.chars["1"]
	d.bag = bag
	a.s.minted = {"stone": 20}
	a.s.seq = 2
	a.s.chars["1"] = CS.norm(d)
	_expect(a.snapshot() == "", "the stacked state is snapshotted")
	var dep: Dictionary = a.apply("act.deposit", 1, {"bag_slot": 0, "count": 5}, 20)
	_expect(bool(dep.get("ok", false)) and int(dep.r.asset.count) == 5, "the live deposit took 5 from the stack (%s)" % [dep])
	a = null # no close(): the journal holds the deposit, as after a crash
	var b = CS.new(WF.new(), dir, 5)
	var why: String = b.open()
	var stone := 0
	var multi := 0
	var ch: Dictionary = b.s.chars.get("1", {})
	for r in (ch.get("bag", []) as Array) + (ch.get("storage", []) as Array):
		if r is Dictionary and str(r.id) == "stone":
			stone += int(r.count)
			multi += 1 if int(r.count) != 1 else 0
	var sent := int((b.s.get("exported", {}) as Dictionary).get("stone", 0))
	_expect(why == "" and stone == 15 and multi == 0 and sent == 5, "the replayed deposit still moved 5; 15 stone are left, one row each (boot '%s', stone %d, multi %d, exported %d)" % [why, stone, multi, sent])
	_expect(b.invariants().is_empty(), "invariants hold after replay then split (%s)" % [b.invariants()])
	b.close()
