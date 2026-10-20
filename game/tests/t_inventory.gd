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
	_test_equip_exact_instance()
	_test_bad_amounts()
	_test_worn_out_of_bag()
	_test_best_tool()
	_test_no_stacking()
	_test_split_migration()
	_test_legacy_equipment_migration()
	_test_hostile_worn()
	_test_identity_through_transfer()
	_test_real_saves_split()
	_test_overflow_to_home_storage()
	_test_stack_bigger_than_bag()
	_test_round_trip_keeps_uids()
	_test_worn_gear_kept()
	_test_currency_stacks()
	_test_visual_groups()
	_test_server_store_migration()
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
	var logged := false
	for l in lines:
		logged = logged or (l.contains("to home storage") and l.contains("stone x%d" % cargo_stone))
	_expect(logged, "the overflow is logged with what moved (%s)" % [lines])
	print("[t_inventory] overflow units=%d bag=%d cargo_stone=%d log=%s" % [_total(got), c.bag.used_slots(), cargo_stone, lines[-1] if not lines.is_empty() else "none"])

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
