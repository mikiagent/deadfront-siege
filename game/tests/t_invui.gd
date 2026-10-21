extends SceneTree
## INVUI (spec 13 section 23): the Durango Bag, Character -> Gear and Equipment screens on the instance
## inventory. One test per section-23 item. Prints "[t_invui] PASS" (or FAIL lines), exits 0/1.
##   Godot --headless --path game --script res://tests/t_invui.gd
## Design and the API contract these tests pin: docs/orchestration/mmo/invui-spec.md (section 4).
## The test needs the INVUI hooks applied (docs/orchestration/reports/claude-mmo-invui-hooks.patch):
## PlayerActions.equip_at/unequip/set_locked, Crafting exact picks, Inventory.presets.
## Item scripts reference the Data autoload, so everything loads on the first frame after it exists.

const UI := "res://scripts/ui/"
const TMP := "user://t_invui"

## Counts SCRIPT ERRORs: a test that aborts on one (a missing method) must fail, not just stop.
class LineLog extends Logger:
	var script_errors := 0
	func _log_message(_message: String, _error: bool) -> void:
		pass
	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			script_errors += 1

var failures: Array[String] = []
var _done := false
var log := LineLog.new()
var host: Node3D
var player: Node
var C := {}  ## class short name -> GDScript (InvView, InvActions, ...)
## Game classes reach autoloads, so they load on the first frame (as t_inventory does), never by class name.
var IS: GDScript
var INV: GDScript
var CR: GDScript
var data: Node
var world: Node

## Never returns true: that quits the tree on the next frame, before an awaiting test finishes.
func _process(_delta: float) -> bool:
	if _done:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	_run()
	return false

func _run() -> void:
	OS.add_logger(log)
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	CR = load("res://scripts/items/crafting.gd")
	data = get_root().get_node("Data")
	world = get_root().get_node("World")
	for n in ["inv_theme", "inv_view", "inv_attributes", "inv_actions", "inv_stats", "inv_new_tracker",
			"inventory_grid", "inventory_slot", "capacity_indicator", "item_inspect_panel", "gear_presets",
			"item_picker", "bag_screen", "character_screen", "equipment_screen", "storage_screen", "detailed_stats_panel"]:
		# GearPresets is a model (inventory.gd saves it), so it lives with the items.
		var path: String = ("res://scripts/items/" if n == "gear_presets" else UI) + str(n) + ".gd"
		if ResourceLoader.exists(path):
			C[n] = load(path)
	await _make_player()
	var tests: Array[Callable] = [_t01_open_close, _t02_capacity, _t03_individual, _t04_levels, _t05_new,
		_t06_brackets, _t07_inspect, _t08_attributes, _t09_sorting, _t10_filtering, _t11_locking,
		_t12_transfers, _t13_equipment, _t14_stats, _t15_presets, _t16_rare_bone_craft,
		_t17_berry_cook, _t18_sell_exact, _t19_save_load, _t20_screen_sizes]
	for t in tests:
		_reset_bag()
		var errs := log.script_errors
		await t.call()
		_expect(log.script_errors == errs, "%s stopped on a SCRIPT ERROR" % t.get_method())
	if failures.is_empty():
		print("[t_invui] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_invui] FAIL %s" % f)
		print("[t_invui] %d failures" % failures.size())
		quit(1)

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

## True when every named INVUI script exists; otherwise one failure names what is missing.
func _need(names: Array, test: String) -> bool:
	var missing := []
	for n in names:
		if not C.has(n):
			missing.append(n + ".gd")
	if not missing.is_empty():
		_expect(false, "%s: not built yet (%s)" % [test, ", ".join(PackedStringArray(missing))])
	return missing.is_empty()

func _has(obj: Object, methods: Array, test: String) -> bool:
	var missing := []
	for m in methods:
		if obj == null or not obj.has_method(m):
			missing.append(m)
	if not missing.is_empty():
		_expect(false, "%s: missing %s" % [test, ", ".join(PackedStringArray(missing))])
	return missing.is_empty()

func _make_player() -> void:
	host = Node3D.new()
	get_root().add_child(host)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	var layer := CanvasLayer.new()
	host.add_child(layer)
	var ui = (load("res://scenes/ui/inventory.tscn") as PackedScene).instantiate()
	layer.add_child(ui)
	player.ui = ui
	ui.bind(player.inventory, player)
	world.pioneer_level = 13
	await process_frame

func _reset_bag() -> void:
	var inv = player.inventory
	for slot in INV.EQUIP_SLOTS:
		inv.equipment.erase(slot)
	inv.slot_count = INV.BASE_SLOTS
	inv.slots.clear()
	inv.slots.resize(inv.slot_count)
	inv.equipped_tool_index = -1
	if "presets" in inv:
		inv.set("presets", {})
	inv.changed.emit()

## Adds one instance and returns its bag index.
func _give(id: StringName, lvl: int, attrs: Dictionary = {}) -> int:
	var inv = player.inventory
	var s = IS.make(id, 1, attrs, lvl)
	var before := {}
	for x in inv.slots:
		if x:
			before[x.uid] = true
	inv.add(s)
	for i in inv.slot_count:
		var x = inv.slots[i]
		if x and x.def_id == id and not before.has(x.uid):
			return i
	return -1

func _uid(i: int) -> String:
	var s = player.inventory.slots[i] if i >= 0 else null
	return s.uid if s else ""

func _find(uid: String) -> int:
	var inv = player.inventory
	for i in inv.slot_count:
		if inv.slots[i] and inv.slots[i].uid == uid:
			return i
	return -1

func _ctx() -> Dictionary:
	return {"where": &"bag", "player": player}

func _grid() -> Control:
	var g: Control = C["inventory_grid"].new()
	g.size = Vector2(1100, 700)
	host.get_child(1).add_child(g)
	g.call("bind", player.inventory)
	return g

# ---------------------------------------------------------------- 1-6: bag, grid, labels, selection

func _t01_open_close() -> void:
	var ui = player.ui
	if not _has(ui, ["open_bag", "current_screen", "hide_ui"], "1 open/close"):
		return
	ui.open_bag()
	await process_frame
	_expect(ui.visible and ui.current_screen() == &"bag", "1: open_bag shows the Bag screen")
	ui.hide_ui()
	_expect(not ui.visible, "1: hide_ui closes the bag family")

func _t02_capacity() -> void:
	if not _need(["capacity_indicator", "inv_theme"], "2 capacity"):
		return
	var inv = player.inventory
	inv.slot_count = 142
	inv.slots.resize(142)
	_give(&"captured_animal", 13, {"species": "zebraceratops"})
	_give(&"berry", 12)
	_give(&"berry", 25)
	_give(&"berry", 42)
	var cap: Control = C["capacity_indicator"].new()
	host.get_child(1).add_child(cap)
	cap.call("bind", inv)
	_expect(str(cap.call("label_text")) == "7 / 142", "2: capacity reads used_slots / slot_count incl. the 4-slot cage (got '%s')" % cap.call("label_text"))
	_expect(not bool(cap.call("is_full")), "2: not full at 7 / 142")
	inv.slot_count = 7
	inv.slots.resize(7)
	inv.changed.emit()
	_expect(bool(cap.call("is_full")) and cap.call("count_color") == C["inv_theme"].DANGER, "2: a full bag turns the count to the warning colour")
	_expect(inv.add(IS.make(&"stone", 1)) == 1, "2: a full bag refuses a pickup")
	cap.queue_free()

func _t03_individual() -> void:
	if not _need(["inventory_grid", "inventory_slot"], "3 individual"):
		return
	var u := [_uid(_give(&"berry", 12)), _uid(_give(&"berry", 25)), _uid(_give(&"berry", 42, {"vivid_inspiration": true}))]
	var g := _grid()
	var items: Array = g.call("item_cells")
	var got := {}
	for c in items:
		got[c.get("uid")] = true
	_expect(items.size() == 3 and got.has(u[0]) and got.has(u[1]) and got.has(u[2]), "3: three berries are three cells with three uids (%d cells)" % items.size())
	_expect((g.call("cells") as Array).size() >= INV.BASE_SLOTS - 2, "3: empty slots stay visible up to capacity")
	g.queue_free()

func _t04_levels() -> void:
	if not _need(["inventory_grid", "inventory_slot"], "4 levels"):
		return
	var i45 := _give(&"raptor_bone", 45)
	var i60 := _give(&"raptor_bone", 60)
	var i0 := _give(&"stone", 1)
	player.inventory.slots[i0].level = 0
	var g := _grid()
	_expect(str(_cell(g, _uid(i45)).call("level_text")) == "Lv. 45" and str(_cell(g, _uid(i60)).call("level_text")) == "Lv. 60", "4: Lv. 45 and Lv. 60 bones are labelled apart")
	_expect(str(_cell(g, _uid(i0)).call("level_text")) == "", "4: an item without a level shows none")
	g.queue_free()

func _cell(g: Control, uid: String) -> Control:
	for c in g.call("item_cells"):
		if c.get("uid") == uid:
			return c
	return null

func _t05_new() -> void:
	if not _need(["inv_new_tracker", "inventory_grid", "inventory_slot"], "5 NEW"):
		return
	var inv = player.inventory
	var tr = C["inv_new_tracker"].new()
	tr.call("bind", inv)
	var ib := _give(&"berry", 12)
	inv.add(IS.make(&"stone_shot", 20))
	var shot: int = inv.find_first(&"stone_shot")
	_expect(&"new" in inv.slots[ib].flags, "5: a picked-up instance is NEW")
	_expect(shot >= 0 and not (&"new" in inv.slots[shot].flags), "5: a fungible stack never gets NEW (it would stop merging)")
	var g := _grid()
	_expect(bool(_cell(g, _uid(ib)).call("shows_new")), "5: the cell shows the NEW tag")
	tr.call("acknowledge", inv.slots[ib])
	_expect(not (&"new" in inv.slots[ib].flags), "5: acknowledging (selecting) clears NEW")
	var rows: Array = inv.to_array()
	C["inv_new_tracker"].call("rebaseline", inv)
	inv.load_array(rows)
	var any_new := false
	for s in inv.slots:
		any_new = any_new or (s != null and &"new" in s.flags)
	_expect(not any_new, "5: loading a save marks nothing NEW")
	g.queue_free()

func _t06_brackets() -> void:
	if not _need(["inventory_grid", "inventory_slot"], "6 brackets"):
		return
	var inv = player.inventory
	var a := _uid(_give(&"berry", 12))
	var b := _uid(_give(&"berry", 25))
	var g := _grid()
	g.call("select_uid", b)
	_expect(g.call("selected_uid") == b and bool(_cell(g, b).get("selected")) and not bool(_cell(g, a).get("selected")), "6: selecting moves the brackets to that cell only")
	_give(&"stone", 3)
	await process_frame
	_expect(g.call("selected_uid") == b and bool(_cell(g, b).get("selected")), "6: selection survives a refresh")
	g.call("auto_sort", &"level")
	_expect(g.call("selected_uid") == b, "6: selection survives a sort")
	inv.remove_at(_find(b), 1)
	await process_frame
	var stale := false
	for c in g.call("item_cells"):
		stale = stale or bool(c.get("selected"))
	_expect(str(g.call("selected_uid")) == "" and not stale, "6: removing the selected item clears the selection")
	g.queue_free()

# ---------------------------------------------------------------- 7-11: inspect, attributes, sort, filter, lock

func _panel(stack: Object) -> Control:
	var p: Control = C["item_inspect_panel"].new()
	p.size = Vector2(440, 700)
	host.get_child(1).add_child(p)
	p.call("show_stack", stack, _ctx())
	return p

func _t07_inspect() -> void:
	if not _need(["item_inspect_panel"], "7 inspect"):
		return
	var ic := _give(&"club", 22)
	var p := _panel(player.inventory.slots[ic])
	var rows := "\n".join(p.call("rows"))
	var club = player.inventory.slots[ic]
	_expect(str(p.call("title_text")) == club.def().display_name and rows.contains("Lv. 22"), "7: title is the item name with its level (%s)" % p.call("title_text"))
	_expect(club.max_durability > 0 and rows.contains("%d / %d" % [club.durability, club.max_durability]), "7: durability reads cur / max (%s)" % rows.replace("\n", " | "))
	_expect(not (p.call("actions") as Array).has(&"eat"), "7: a weapon offers no Eat")
	p.call("show_stack", player.inventory.slots[_give(&"berry", 12)], _ctx())
	_expect(not (p.call("actions") as Array).has(&"equip"), "7: a berry offers no Equip")
	p.queue_free()

func _t08_attributes() -> void:
	if not _need(["inv_attributes", "item_inspect_panel", "inventory_grid", "inventory_slot"], "8 attributes"):
		return
	var i60 := _give(&"raptor_bone", 60, {"firm": 8, "low_density": 3, "black_sheen": true})
	var i45 := _give(&"raptor_bone", 45, {"firm": 6})
	var sec: Dictionary = C["inv_attributes"].call("sections", player.inventory.slots[i60])
	var labels := func(k: String) -> String: return ",".join(PackedStringArray((sec.get(k, []) as Array).map(func(r: Dictionary) -> String: return str(r.label))))
	_expect(labels.call("positive") == "Firm" and labels.call("negative") == "Low Density" and labels.call("rare") == "Black Sheen", "8: Firm is positive, Low Density negative, Black Sheen rare (%s)" % sec)
	var p := _panel(player.inventory.slots[i60])
	var rows := "\n".join(p.call("rows"))
	_expect(rows.contains("Firm Lv. 8") and rows.contains("Low Density Lv. 3") and rows.contains("Black Sheen"), "8: the panel lists each attribute with its level")
	_expect(not rows.contains("hardness") and not rows.contains("tint") and not rows.contains("material_tier"), "8: technical attribute keys are never shown")
	var cp: Color = p.call("section_color", &"positive")
	var cn: Color = p.call("section_color", &"negative")
	var cr: Color = p.call("section_color", &"rare")
	_expect(cp != cn and cn != cr and cr.g > cr.r and cp.r > cp.b, "8: gold positive, grey negative, green rare")
	var g := _grid()
	_expect(bool(_cell(g, _uid(i60)).call("shows_rare")) and not bool(_cell(g, _uid(i45)).call("shows_rare")), "8: only the rare bone carries the rare marker")
	p.queue_free()
	g.queue_free()

func _snapshot() -> Array:
	var out := []
	for s in player.inventory.slots:
		out.append([s.uid, s.def_id, s.level, s.count, s.attributes.duplicate(true), s.flags.duplicate()] if s else null)
	return out

func _t09_sorting() -> void:
	if not _need(["inv_view", "inventory_grid"], "9 sorting"):
		return
	for row in [[&"berry", 25], [&"raptor_bone", 60], [&"stone", 4], [&"berry", 42], [&"club", 22]]:
		_give(row[0], row[1])
	var before := _snapshot()
	var leads: Array = C["inv_view"].call("order", player.inventory, &"acquired", &"all")
	for key in ["name", "type", "level", "acquired", "rarity", "attributes", "durability"]:
		var order: Array = C["inv_view"].call("order", player.inventory, StringName(key), &"all")
		var a := order.duplicate()
		var b := leads.duplicate()
		a.sort()
		b.sort()
		_expect(a == b, "9: sort by %s shows every instance exactly once" % key)
	var by_level: Array = C["inv_view"].call("order", player.inventory, &"level", &"all")
	var lv := by_level.map(func(i: int) -> int: return player.inventory.slots[i].level)
	var desc := lv.duplicate()
	desc.sort()
	desc.reverse()
	_expect(lv == desc, "9: level sort is highest first (%s)" % [lv])
	var g := _grid()
	g.call("auto_sort", &"name")
	_expect(_snapshot() == before, "9: sorting changes no uid, level, count, attribute, flag or slot")
	g.queue_free()

func _t10_filtering() -> void:
	if not _need(["inv_view", "inventory_grid", "capacity_indicator"], "10 filtering"):
		return
	for row in [[&"berry", 25], [&"raptor_bone", 60], [&"club", 22], [&"raw_meat", 3]]:
		_give(row[0], row[1])
	var before := _snapshot()
	var food: Array = C["inv_view"].call("order", player.inventory, &"acquired", &"food")
	var ids := food.map(func(i: int) -> String: return str(player.inventory.slots[i].def_id))
	ids.sort()
	_expect(ids == ["berry", "raw_meat"], "10: the Food filter shows berry and meat only (%s)" % [ids])
	var g := _grid()
	g.call("set_view", &"acquired", &"food")
	_expect((g.call("item_cells") as Array).size() == 2 and _snapshot() == before, "10: filtering hides, never changes, items")
	g.queue_free()

func _t11_locking() -> void:
	if not _need(["inv_actions"], "11 locking"):
		return
	var inv = player.inventory
	var i60 := _give(&"raptor_bone", 60, {"black_sheen": true})
	_expect(bool(C["inv_actions"].call("run", &"lock", player, i60, _ctx())) and inv.slots[i60].is_locked(), "11: Lock locks through the command layer")
	_expect((inv.slots[i60].to_dict().get("flags", []) as Array).has("locked"), "11: the lock is in the saved row")
	var valid: Array = C["inv_actions"].call("valid", inv.slots[i60], _ctx())
	_expect(not valid.has(&"sell") and not valid.has(&"drop"), "11: a locked item offers no Sell or Drop")
	var rec: Dictionary = data.recipes.get(&"slingshot", {})
	var picks: Array = CR.default_picks(inv, rec)
	_expect(not rec.is_empty() and int(picks[0]) == -1, "11: crafting never picks a locked bone by default")
	var forced: Array[int] = [i60, -1, -1]
	_expect(CR.consume_for_craft(inv, rec, forced).is_empty() and inv.slots[i60] != null, "11: a locked bone cannot be consumed even when picked")
	C["inv_actions"].call("run", &"lock", player, i60, _ctx())
	_expect(not inv.slots[i60].is_locked(), "11: Lock again unlocks")

# ---------------------------------------------------------------- 12-15: transfer, equipment, stats, presets

func _t12_transfers() -> void:
	var ui = player.ui
	var box = INV.new(10)
	var i := _give(&"raptor_bone", 60, {"firm": 8})
	var uid := _uid(i)
	ui.show_storage(box, player, {"title": "Storage Box", "allow_deposit": true})
	_expect(ui.has_method("current_screen") and ui.call("current_screen") == &"storage", "12: a container opens the shared Bag | Storage split view")
	ui._select(i)
	ui._store_selected()
	var moved = box.slots[0]
	_expect(moved != null and moved.uid == uid and moved.level == 60 and int(moved.attributes.get("firm", 0)) == 8 and _find(uid) == -1, "12: Store moves the exact bone (uid, level, attributes)")
	if ui.has_method("_take_storage"):
		ui._take_storage(0)
	_expect(_find(uid) >= 0 and box.slots[0] == null, "12: Take brings the same bone back")
	ui.hide_ui()

func _t13_equipment() -> void:
	if not _need(["inv_actions"], "13 equipment"):
		return
	var inv = player.inventory
	var ic := _give(&"hide_bone_cuirass", 20)
	var uid := _uid(ic)
	_expect(bool(C["inv_actions"].call("run", &"equip", player, ic, _ctx())), "13: Equip runs")
	var worn: Object = inv.equipped_in(&"body")
	_expect(worn != null and worn.uid == uid and _find(uid) == -1, "13: the exact cuirass is worn and left the bag")
	_expect(bool(C["inv_actions"].call("run", &"unequip", player, -1, {"where": &"equipment", "player": player, "slot": &"body"})), "13: Unequip runs")
	_expect(inv.equipped_in(&"body") == null and _find(uid) >= 0, "13: unequipped, it is back in the bag")
	# Through the screens (references 2-3): Character lists the exact instances that fit the cell;
	# picking one opens Equipment to compare; Equip there wears that instance; Unequip on Character.
	if not _need(["character_screen", "equipment_screen"], "13 screens"):
		return
	var ui = player.ui
	var ua := _uid(_give(&"forager_vest", 12))
	var ub := _uid(_give(&"forager_vest", 30))
	ui.open_character(&"body")
	await process_frame
	var ch = ui.get("_character")
	_expect(ui.current_screen() == &"character", "13: open_character shows Character -> Gear")
	var listed: Array = ch.list.item_cells().map(func(c) -> String: return c.uid)
	_expect(listed.has(ua) and listed.has(ub) and listed.has(uid) and listed.size() == 3, "13: the body cell lists the three bag instances that fit (%s)" % [listed])
	ch.list.select_uid(ub)
	var eq = ui.get("_equipment")
	_expect(ui.current_screen() == &"equipment" and eq != null and eq.list.selected_uid() == ub, "13: picking the Lv. 30 vest opens Equipment with it picked")
	_expect(eq != null and eq.primary.visible and eq.primary.text == "Equip", "13: Equipment offers Equip for the picked vest")
	eq.primary.pressed.emit()
	var on: Object = inv.equipped_in(&"body")
	_expect(on != null and on.uid == ub and _find(ua) >= 0, "13: Equip wears the exact vest picked, not the first")
	eq.header.back_pressed.emit()
	await process_frame
	_expect(ui.current_screen() == &"character", "13: back from Equipment returns to Character")
	var cell: Object = ch.cells.filter(func(c) -> bool: return c.slot == &"body")[0]
	_expect(cell.stack != null and cell.stack.uid == ub, "13: the torso cell shows the vest now worn")
	ch.select_slot(&"body")
	_expect(ch.primary.visible and ch.primary.text == "Unequip", "13: the worn vest offers Unequip")
	ch.primary.pressed.emit()
	_expect(inv.equipped_in(&"body") == null and _find(ub) >= 0, "13: Unequip on Character puts the vest back in the bag")
	# The held-tool cell: Hold picks the exact pick; Unequip lets go (gathering chooses again).
	var p1 := _uid(_give(&"work_pick", 10))
	var p2 := _uid(_give(&"work_pick", 20))
	ui.open_equipment(&"tool", p2)
	_expect(eq.primary.visible and eq.primary.text == "Hold", "13: a work tool offers Hold on the tool cell")
	eq.primary.pressed.emit()
	_expect(inv.equipped_tool_index == _find(p2) and _find(p1) >= 0, "13: Hold takes the Lv. 20 pick picked")
	await process_frame
	eq.select_slot(&"tool")
	_expect(eq.primary.text == "Unequip", "13: the held pick offers Unequip")
	eq.primary.pressed.emit()
	_expect(inv.equipped_tool_index == -1, "13: Unequip lets go of the held tool")
	ui.hide_ui()

func _t14_stats() -> void:
	if not _need(["inv_stats", "inv_actions"], "14 stats"):
		return
	var s0: Dictionary = C["inv_stats"].call("snapshot", player)
	var ic := _give(&"raid_cuirass", 30)
	var cu := _uid(ic)
	var armor: float = player.inventory.slots[ic].scaled_armor()
	C["inv_actions"].call("run", &"equip", player, ic, _ctx())
	player.refresh_equipment_vitals()
	var s1: Dictionary = C["inv_stats"].call("snapshot", player)
	player.refresh_equipment_vitals()
	var s2: Dictionary = C["inv_stats"].call("snapshot", player)
	_expect(armor > 0.0 and is_equal_approx(float(s1.defense) - float(s0.defense), armor), "14: wearing the cuirass adds its armour to Defense once (%s -> %s, armour %s)" % [s0.get("defense"), s1.get("defense"), armor])
	_expect(s2 == s1, "14: a second refresh does not apply it twice")
	C["inv_actions"].call("run", &"unequip", player, -1, {"where": &"equipment", "player": player, "slot": &"body"})
	player.refresh_equipment_vitals()
	_expect(C["inv_stats"].call("snapshot", player) == s0, "14: unequipping restores every stat")
	var preview: Dictionary = C["inv_stats"].call("with_candidate", player, _find(cu), &"body")
	_expect(is_equal_approx(float(preview.get("defense", 0.0)), float(s1.defense)) and C["inv_stats"].call("snapshot", player) == s0, "14: the compare preview predicts Defense without equipping")
	# Equip, equip another (a swap), unequip: Defense follows what is worn, never the sum.
	var ih := _give(&"hide_bone_cuirass", 20)
	var ah: float = player.inventory.slots[ih].scaled_armor()
	C["inv_actions"].call("run", &"equip", player, ih, _ctx())
	C["inv_actions"].call("run", &"equip", player, _find(cu), _ctx())
	var s3: Dictionary = C["inv_stats"].call("snapshot", player)
	_expect(is_equal_approx(float(s3.defense) - float(s0.defense), armor) and not is_equal_approx(float(s3.defense) - float(s0.defense), armor + ah), "14: a swap leaves only the new cuirass's armour in Defense")
	_expect(is_equal_approx(player.vitals.effective_max_health(), float(s3.max_health)), "14: max health matches what the vitals use (%s vs %s)" % [player.vitals.effective_max_health(), s3.max_health])
	C["inv_actions"].call("run", &"unequip", player, -1, {"where": &"equipment", "player": player, "slot": &"body"})
	_expect(C["inv_stats"].call("snapshot", player) == s0, "14: unequipping after the swap restores every stat")
	# Attack is Hunt's own swing number with the worn weapon (hunt.gd land_hit before defence).
	var ik := _give(&"stone_knife", 18)
	C["inv_actions"].call("run", &"equip", player, ik, _ctx())
	var tune: Dictionary = load("res://scripts/combat/combat_tuning.gd").section("player_melee")
	var want: float = player.hunt._swing_damage(player.hunt._weapon()) * (1.0 + float(tune.get("damage_per_melee_level", 0.01)) * player.skills.level_of("melee"))
	var s4: Dictionary = C["inv_stats"].call("snapshot", player)
	_expect(player.hunt._weapon() != null and is_equal_approx(float(s4.attack), want) and float(s4.attack) != float(s0.attack), "14: Attack is Hunt's swing damage with the worn knife (%s vs %s)" % [s4.attack, want])

func _t15_presets() -> void:
	if not _need(["gear_presets", "inv_actions"], "15 presets"):
		return
	var GP = C["gear_presets"]
	var inv = player.inventory
	_expect(int(GP.call("unlocked_count", 13)) == 2 and int(GP.call("unlocked_count", 1)) == 1, "15: presets unlock by level from data (2 at Lv. 13)")
	var ih := _give(&"forager_hood", 12)
	var uid := _uid(ih)
	C["inv_actions"].call("run", &"equip", player, ih, _ctx())
	GP.call("capture", inv, 0)
	C["inv_actions"].call("run", &"unequip", player, -1, {"where": &"equipment", "player": player, "slot": &"head"})
	_expect(inv.equipped_in(&"head") == null, "15: hood off before switching")
	_expect(str(GP.call("apply", player, 0)) == "" and inv.equipped_in(&"head") != null and inv.equipped_in(&"head").uid == uid, "15: preset 1 puts the same hood back on")
	_expect(str(GP.call("apply", player, 3)) != "", "15: a locked preset is refused")
	# The Gear tab's numbers: an unsaved preset 2 starts as a copy; what changes there stays with 2;
	# switching back to 1 puts 1's exact gear on again.
	_expect(str(GP.call("switch", player, 1)) == "" and int(GP.call("active", inv)) == 1 and inv.equipped_in(&"head") != null, "15: switching to preset 2 copies the gear worn")
	C["inv_actions"].call("run", &"unequip", player, -1, {"where": &"equipment", "player": player, "slot": &"head"})
	_expect(str(GP.call("switch", player, 0)) == "" and inv.equipped_in(&"head") != null and inv.equipped_in(&"head").uid == uid, "15: back to preset 1, the hood is on again")
	_expect(str(GP.call("switch", player, 1)) == "" and inv.equipped_in(&"head") == null and _find(uid) >= 0, "15: preset 2 kept its bare head")
	var why := str(GP.call("switch", player, 2))
	_expect(why.contains("Lv. 30") and int(GP.call("active", inv)) == 1, "15: preset 3 is refused until Lv. 30 (%s)" % why)
	if _need(["character_screen"], "15 selector"):
		player.ui.open_character(&"head")
		await process_frame
		var ch = player.ui.get("_character")
		_expect(int(ch.presets.unlocked) == 2 and int(ch.presets.active) == 1, "15: the selector shows 2 earned presets, the 2nd active")
		ch.presets.chosen.emit(3)
		_expect(str(ch.note.text).contains("Lv. 50"), "15: tapping a locked preset says when it unlocks (%s)" % ch.note.text)
		player.ui.hide_ui()

# ---------------------------------------------------------------- 16-18: picker, market

func _picker(rid: StringName, slot_index: int, got: Array) -> Control:
	var pk: Control = C["item_picker"].new()
	pk.size = Vector2(1100, 700)
	host.get_child(1).add_child(pk)
	pk.call("open", player.inventory, data.recipes.get(rid, {}), slot_index, func(picked: Array) -> void: got.append_array(picked))
	return pk

func _t16_rare_bone_craft() -> void:
	if not _need(["item_picker"], "16 rare bone"):
		return
	var inv = player.inventory
	var i45 := _give(&"raptor_bone", 45, {"firm": 6})
	var i60 := _give(&"raptor_bone", 60, {"firm": 8, "black_sheen": true})
	var u60 := _uid(i60)
	var got := []
	var pk := _picker(&"slingshot", 0, got)
	_expect(int(pk.call("preselected_index")) == i45, "16: the plain Lv. 45 bone is preselected, never the rare one")
	pk.call("choose", i60)
	_expect(str(pk.call("warning_text")) != "", "16: choosing the rare bone warns")
	pk.call("confirm")
	_expect(got == [i60], "16: the picker returns exactly the rare bone's slot (%s)" % [got])
	var rec: Dictionary = data.recipes.get(&"slingshot", {})
	var picks: Array = []
	for p in CR.default_picks(inv, rec):
		picks.append(p)
	picks[0] = [i60]  # exact-instance picks: one Array of bag slots per recipe slot (hook)
	_give(&"branch", 3)
	_give(&"fibre_stalk", 3)
	_give(&"fibre_stalk", 4)
	var used: Array = CR.consume_for_craft(inv, rec, picks)
	var uids := used.map(func(s) -> String: return s.uid)
	_expect(uids.has(u60) and _find(u60) == -1 and _find(_uid(i45)) >= 0, "16: crafting consumes exactly the chosen bone")
	pk.queue_free()

func _t17_berry_cook() -> void:
	if not _need(["item_picker"], "17 berry cook"):
		return
	var inv = player.inventory
	var meat := _give(&"raw_meat", 10)
	var leaf := _give(&"herb_leaf", 8)
	var b12 := _uid(_give(&"berry", 12))
	var i25 := _give(&"berry", 25)
	var b25 := _uid(i25)
	var b42 := _uid(_give(&"berry", 42, {"vivid_inspiration": true}))
	var got := []
	var pk := _picker(&"camp_stew", 2, got)
	var cands: Array = pk.call("candidates")
	_expect(cands.has(_find(b12)) and cands.has(i25) and cands.has(_find(b42)), "17: all three berries are pickable")
	pk.call("choose", i25)
	pk.call("confirm")
	_expect(got == [i25], "17: the picker returns the Lv. 25 berry")
	var rec: Dictionary = data.recipes.get(&"camp_stew", {})
	var picks: Array = [[meat], [leaf], [i25]]  # exact-instance picks (hook)
	CR.consume_for_craft(inv, rec, picks)
	_expect(_find(b25) == -1 and _find(b12) >= 0 and _find(b42) >= 0, "17: cooking used the Lv. 25 berry and left the others")
	pk.queue_free()

func _t18_sell_exact() -> void:
	if not _need(["inv_actions"], "18 sell"):
		return
	var IA = C["inv_actions"]
	var i := _give(&"raptor_bone", 60, {"black_sheen": true})
	var stack = player.inventory.slots[i]
	_expect(not (IA.call("valid", stack, _ctx()) as Array).has(&"sell"), "18: no market screen, no Sell button")
	var sold := []
	IA.set("sell_handler", func(uid: String) -> void: sold.append(uid))
	_expect((IA.call("valid", stack, _ctx()) as Array).has(&"sell"), "18: with a market hooked, Sell shows")
	IA.call("run", &"sell", player, i, _ctx())
	_expect(sold == [stack.uid], "18: Sell hands the market the exact uid")
	stack.set_flag(&"locked", true)
	_expect(not (IA.call("valid", stack, _ctx()) as Array).has(&"sell"), "18: a locked item cannot be sold")
	IA.set("sell_handler", Callable())

# ---------------------------------------------------------------- 19-20: save, sizes

func _t19_save_load() -> void:
	if not _need(["gear_presets"], "19 save/load"):
		return
	var inv = player.inventory
	var i := _give(&"raptor_bone", 60, {"firm": 8, "black_sheen": true})
	inv.slots[i].set_flag(&"new", true)
	var j := _give(&"berry", 42)
	inv.slots[j].set_flag(&"locked", true)
	var ih := _give(&"forager_hood", 12)
	inv.equip_at(ih, &"head")
	C["gear_presets"].call("capture", inv, 0)
	var rows: Variant = JSON.parse_string(JSON.stringify(inv.to_array()))
	var extras: Variant = JSON.parse_string(JSON.stringify(inv.extras_to_dict()))
	var inv2 = INV.new(INV.BASE_SLOTS)
	inv2.load_array(rows)
	inv2.extras_from_dict(extras)
	var flags := {}
	for s in inv2.slots:
		if s:
			flags[s.uid] = s.flags
	_expect((flags.get(_uid(i), []) as Array).has(&"new") and (flags.get(_uid(j), []) as Array).has(&"locked"), "19: NEW and locked survive a save")
	_expect(JSON.stringify(inv2.get("presets")) == JSON.stringify(inv.get("presets")) and not (inv.get("presets") as Dictionary).is_empty(), "19: presets survive a save")
	var old := (extras as Dictionary).duplicate()
	old.erase("presets")
	var inv3 = INV.new(INV.BASE_SLOTS)
	inv3.load_array(rows)
	inv3.extras_from_dict(old)
	_expect(inv3.get("presets") is Dictionary and (inv3.get("presets") as Dictionary).is_empty(), "19: an old save without presets loads with none")
	_expect(not inv3.extras_to_dict().has("presets"), "19: a bag that never used presets saves none (old save format kept)")
	var forged = INV.new(INV.BASE_SLOTS)
	forged.extras_from_dict({"presets": {"active": 9, "sets": [{"head": "lab", "evil": "x", "body": 5}, "junk"]}})
	var fp: Dictionary = forged.get("presets")
	_expect(fp.get("active") == 1 and JSON.stringify(fp.get("sets")) == JSON.stringify([{"head": "lab"}, null]), "19: a forged presets row is cleaned (%s)" % JSON.stringify(fp))

## Measured layout at the judge's desktop canvas and the landscape phone (design section 7).
func _t20_screen_sizes() -> void:
	if not _need(["inv_theme", "bag_screen"], "20 sizes"):
		return
	var T = C["inv_theme"]
	var d: Dictionary = T.call("metrics", Vector2(1600, 900))
	var ph: Dictionary = T.call("metrics", Vector2(844, 390))
	_expect(float(d.header_h) >= 72 and float(d.header_h) <= 90, "20: desktop header is 8-10 %% of 900 (%s)" % d.header_h)
	_expect(float(d.toolbar_h) >= 90 and float(d.toolbar_h) <= 108, "20: desktop toolbar is 10-12 %% of 900 (%s)" % d.toolbar_h)
	_expect(int(d.columns) >= 7 and int(d.columns) <= 8, "20: 7-8 columns at 1600x900 (%s)" % d.columns)
	_expect(float(ph.header_h) >= 44 and float(ph.toolbar_h) >= 48 and float(ph.cell) >= 72 and int(ph.columns) >= 6 and int(ph.columns) <= 8, "20: phone header/toolbar/cell/columns (%s)" % ph)
	_expect(int(ph.lv_font) >= 12 and int(ph.new_font) >= 12, "20: Lv and NEW are 12 px or more on the phone")
	_give(&"raptor_bone", 60, {"black_sheen": true})
	for view in [Vector2(1600, 900), Vector2(844, 390), Vector2(804, 452)]:
		var box := Control.new()
		box.size = view
		host.get_child(1).add_child(box)
		var bs: Control = C["bag_screen"].new()
		box.add_child(bs)
		bs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bs.call("bind", player.inventory, player)
		bs.call("select_index", 0)
		await process_frame
		await process_frame
		_check_targets(bs, view)
		box.queue_free()
	if not _need(["character_screen", "equipment_screen", "detailed_stats_panel"], "20 gear sizes"):
		return
	var ih := _give(&"raid_helm", 30)
	for view in [Vector2(1600, 900), Vector2(844, 390), Vector2(804, 452)]:
		for n in ["character_screen", "equipment_screen"]:
			var box := Control.new()
			box.size = view
			host.get_child(1).add_child(box)
			var gs: Control = C[n].new()
			box.add_child(gs)
			gs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			gs.call("bind", player.inventory, player)
			if n == "equipment_screen":
				gs.call("preselect", &"head", _uid(ih)) # the compare state: "20 → 37 +17" must fit
			else:
				gs.call("select_slot", &"head")
			await process_frame
			await process_frame
			_check_targets(gs, view)
			if n == "character_screen":
				gs.call("open_stats", "gathering")
				await process_frame
				_check_targets(gs.get("stats_panel"), view)
				_expect(Array(gs.get("stats_panel").call("rows")).has("Gathering Power  %d" % C["inv_stats"].call("power", player, "gathering")), "20: Detailed Stats lists Gathering Power")
			box.queue_free()

## Tap targets inside a scroll area (the grid's cells are not buttons; a list's rows may be).
func _scrolled(sc: Control, view: Vector2, small: Array) -> void:
	var stack: Array[Node] = sc.get_children()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is BaseButton and (n as Control).is_visible_in_tree() and ((n as Control).size.y < 43.5 or (n as Control).size.x < 43.5):
			small.append("%s %s (scrolled)" % [n.name, (n as Control).size])

func _check_targets(root: Control, view: Vector2) -> void:
	var small := []
	var clipped := []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var c := n as Control
		if n is ScrollContainer:
			_scrolled(c, view, small)  # scrolled content runs past the view on purpose; its targets still count
			continue
		stack.append_array(n.get_children())
		if c is BaseButton:
			var need := 56.0 if c.is_in_group(&"inv_contextual") else 44.0
			if c.size.y < need - 0.5 or c.size.x < 44.0 - 0.5:
				small.append("%s %s" % [c.name, c.size])
		if c is Label and (c as Label).text != "" and (c as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and not (c as Label).autowrap_mode:
			var f := c.get_theme_font(&"font")
			var w := f.get_string_size((c as Label).text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size(&"font_size")).x
			if w > c.size.x + 1.0:
				clipped.append("%s '%s' %d>%d" % [c.name, (c as Label).text, w, c.size.x])
		if not Rect2(Vector2.ZERO, view).grow(1.0).encloses(c.get_global_rect()) and c.size != Vector2.ZERO:
			clipped.append("%s outside %s" % [c.name, view])
	_expect(small.is_empty(), "20: every tap target is 44 px+ and contextual actions 56 px+ at %s (%s)" % [view, small])
	_expect(clipped.is_empty(), "20: no clipped or off-screen text at %s (%s)" % [view, clipped.slice(0, 6)])
