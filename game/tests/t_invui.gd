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
		_t17_berry_cook, _t18_sell_exact, _t19_save_load, _t20_screen_sizes, _t21_polish, _t22_ingame_dock]
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
	await _t11_locked_never_spent()

## One rule for spendable units (review r1 blocker): what a lock keeps is neither counted as payable
## nor spent by builds, captures or ammo, while "have N" goals still see it.
func _t11_locked_never_spent() -> void:
	var inv = player.inventory
	var placer = player.placer
	_reset_bag()
	var k := _give(&"workbench_kit", 1)
	inv.slots[k].set_flag(&"locked", true)
	var acts: Array = C["inv_actions"].call("valid", inv.slots[k], _ctx())
	_expect(not acts.has(&"place"), "11: a locked kit offers no Place (%s)" % [acts])
	placer.placing = &"workbench"
	var paid: bool = placer.call("_pay", player)
	_expect(not paid and inv.slots[k] != null and inv.slots[k].def_id == &"workbench_kit", "11: a locked kit never pays for a build (paid=%s)" % paid)
	_reset_bag()
	for _n in 2:
		inv.slots[_give(&"branch", 1)].set_flag(&"locked", true)
	placer.placing = &"bonfire"
	var can: bool = placer.call("_can_pay", player)
	var paid2: bool = placer.call("_pay", player)
	_expect(not can and not paid2 and inv.held_of(&"branch") == 2, "11: locked branches never pay a raw cost (can=%s paid=%s held=%d)" % [can, paid2, inv.held_of(&"branch")])
	placer.placing = &""
	_reset_bag()
	var n2 := _give(&"capture_net_ii", 1)
	inv.slots[n2].set_flag(&"locked", true)
	_expect(inv.best_capture_net() == null, "11: a locked net is never the capture net")
	_give(&"capture_net_i", 1)
	var net = inv.best_capture_net()
	_expect(net != null and net.def_id == &"capture_net_i", "11: the unlocked lower net is chosen over a locked better one")
	_reset_bag()
	var a := _give(&"stone_shot", 1)
	inv.slots[a].count = 5
	inv.slots[a].set_flag(&"locked", true)
	_expect(inv.count_of(&"stone_shot") == 0 and not inv.consume(&"stone_shot", 1) and inv.held_of(&"stone_shot") == 5, "11: locked ammo neither counts as ready nor fires (count %d)" % inv.count_of(&"stone_shot"))
	var obj: Dictionary = load("res://scripts/core/objectives.gd").call("_progress", player, {"have": {"stone_shot": 5}})
	_expect(int(obj.get("got", -1)) == 5, "11: a 'have N' goal still sees locked units (%s)" % [obj])
	# Online there is no act.lock op yet: Lock is not offered (as Discard), so it never does nothing.
	player.actions.online = true
	var on: Array = C["inv_actions"].call("valid", inv.slots[a], _ctx())
	_expect(not on.has(&"lock") and not on.has(&"unlock"), "11: Lock is not offered online (%s)" % [on])
	if _need(["bag_screen"], "11 lock online"):
		player.ui.open_bag()
		await process_frame
		var tb = player.ui.get("_bag").toolbar
		_expect(not (tb.squares as Array).has(&"lock"), "11: the Bag's lock square is hidden online")
		player.ui.hide_ui()
	player.actions.online = false

# ---------------------------------------------------------------- 12-15: transfer, equipment, stats, presets

## The storage view (spec 13 s17; the owner's storage-transfer reference): Bag and container tabs
## over one grid, the filter rail and search over both, multi-select with Select All, and Transfer
## moving exactly the picked instances either way.
func _t12_transfers() -> void:
	var ui = player.ui
	var box = INV.new(10)
	var i := _give(&"raptor_bone", 60, {"firm": 8})
	var uid := _uid(i)
	var berry := _uid(_give(&"berry", 12))
	var berry2 := _uid(_give(&"berry", 25))
	ui.show_storage(box, player, {"title": "Storage Box", "allow_deposit": true, "take_all": true})
	_expect(ui.has_method("current_screen") and ui.call("current_screen") == &"storage", "12: a container opens the shared Bag | Storage view")
	var st = ui.get("_storage")
	if st == null or not st.has_method("select_key") or st.get("rail") == null:
		_expect(false, "12: the storage view has Bag / container tabs, a filter rail and Transfer (StorageScreen.select_key, rail)")
		ui._select(i)
		ui._store_selected()
		ui.hide_ui()
		return
	await process_frame
	_expect(st.tab == &"box" and st.box_grid.visible and not st.bag_grid.visible, "12: it opens on the container's tab")
	ui.select_uid(uid)
	var store_b = st.action_button(&"store")
	_expect(st.tab == &"bag" and st.inspect.title_text() == "Raptor Bone" and st.inspect.actions() == [&"store"] and store_b != null and store_b.text == "Transfer to Storage Box", "12: the bone picked in the Bag is inspected with Transfer to Storage Box (%s %s)" % [st.tab, st.inspect.actions()])
	store_b.pressed.emit()
	var moved = box.slots[0]
	_expect(moved != null and moved.uid == uid and moved.level == 60 and int(moved.attributes.get("firm", 0)) == 8 and _find(uid) == -1, "12: Transfer moves the exact bone (uid, level, attributes)")
	# One rail filters both tabs; it never touches the items.
	st.rail.choose(&"food")
	await process_frame
	var bag_food: int = st.bag_grid.item_cells().size()
	st.show_tab(&"box")
	_expect(bag_food == 2 and st.box_grid.item_cells().is_empty() and box.slots[0].uid == uid, "12: Food on the rail shows the two berries in the Bag and hides the bone in the box")
	st.rail.choose(&"all")
	ui.select_uid(uid)
	var take_b = st.action_button(&"take")
	_expect(st.tab == &"box" and st.box_grid.selected_uid() == uid and st.inspect.actions() == [&"take", &"take_all"] and take_b != null and take_b.text == "Transfer to Bag", "12: the bone in the box offers Transfer to Bag and Take All (%s)" % [st.inspect.actions()])
	take_b.pressed.emit()
	_expect(_find(uid) >= 0 and box.slots[0] == null, "12: Transfer to Bag brings the same bone back")
	# Multi-select: Select All on the Bag tab counts in the header, checks every cell, and one
	# Transfer moves them all.
	st.show_tab(&"bag")
	st.toolbar.select_all_pressed.emit()
	await process_frame
	var n: int = player.inventory.used_slots()
	var checked := 0
	for c in st.bag_grid.item_cells():
		checked += 1 if c.selected and c.checks else 0
	_expect(st.bag_grid.multi and checked == n and st.header.title == "Select" and st.header.get("_lead").text == str(n), "12: Select All checks all %d and the header reads '%s Select' (%d checked, '%s %s')" % [n, n, checked, st.header.get("_lead").text, st.header.title])
	st.action_button(&"store").pressed.emit()
	await process_frame
	var in_box: Dictionary = box.uids()
	_expect(player.inventory.used_slots() == 0 and in_box.has(uid) and in_box.has(berry) and in_box.has(berry2), "12: one Transfer moved every picked instance with its uid")
	st.show_tab(&"box")
	st.box_grid.select_uid(berry)
	st.box_grid.select_uid(berry2)
	st.action_button(&"take").pressed.emit()
	await process_frame
	_expect(_find(berry) >= 0 and _find(berry2) >= 0 and _find(uid) == -1 and box.uids().has(uid), "12: Transfer to Bag moves exactly the two picked berries, not the bone")
	st.toolbar.search_changed.emit("bone")
	_expect(st.box_grid.item_cells().size() == 1 and st.bag_grid.item_cells().is_empty(), "12: Search 'bone' shows only the bone on both tabs")
	st.toolbar.search_changed.emit("")
	ui.select_uid(uid)
	st.action_button(&"take").pressed.emit()
	# A take-only container says why over the grid and offers no Transfer; a locked bag item says why it stays.
	var loot = INV.new(4)
	loot.add(IS.make(&"raw_meat", 1, {}, 9))
	ui.show_storage(loot, player, {"title": "Raptor", "take_all": true, "readonly_reason": "needs knife"})
	ui.select_uid(loot.slots[0].uid)
	_expect(st.inspect.actions().is_empty() and st.notice_text() == "Needs knife", "12: read-only loot shows its reason over the grid and no Transfer (%s '%s')" % [st.inspect.actions(), st.notice_text()])
	player.inventory.slots[_find(berry)].set_flag(&"locked", true)
	ui.show_storage(box, player, {"title": "Storage Box", "allow_deposit": true})
	ui.select_uid(berry)
	_expect(st.notice_text() == "" and st.inspect.actions().is_empty() and Array(st.inspect.rows()).has("Locked: unlock it in the Bag to store it."), "12: a locked berry stays in the bag and says why (%s)" % [st.inspect.rows()])
	# The legacy entry the earned-training probe drives (select a bag slot, then Store) still stores it.
	ui._select(_find(berry2))
	ui._store_selected()
	_expect(box.uids().has(berry2) and _find(berry2) == -1, "12: the legacy _select + _store_selected entry stores that berry")
	# Dinosaur cargo: the same view over the pet's own bag.
	var rec = load("res://scripts/pets/pet_record.gd").from_def(data.creature(&"velociraptor"), &"A")
	rec.bag.add(IS.make(&"berry", 1, {}, 33))
	var cargo_uid: String = rec.bag.slots[0].uid
	ui.show_pet_bag(rec)
	_expect(ui.call("current_screen") == &"cargo" and st.box_grid.inventory == rec.bag and st.tab == &"box", "12: a bonded dinosaur's cargo opens in the same view on its tab")
	ui.select_uid(cargo_uid)
	_expect(st.inspect.actions() == [&"take"], "12: cargo offers Transfer to Bag (no Take All) (%s)" % [st.inspect.actions()])
	st.action_button(&"take").pressed.emit()
	_expect(_find(cargo_uid) >= 0 and player.inventory.slots[_find(cargo_uid)].level == 33 and rec.bag.used_slots() == 0, "12: Transfer moves that exact berry from the cargo into the bag")
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
	# A piece locked since it was saved stays in the bag, and the switch says so (review r1).
	inv.slots[_find(uid)].set_flag(&"locked", true)
	var said := str(GP.call("switch", player, 0))
	_expect(said.contains("Locked") and said.contains("Forager Hood") and inv.equipped_in(&"head") == null, "15: a locked preset piece is named, not dropped silently (%s)" % said)
	inv.slots[_find(uid)].set_flag(&"locked", false)
	GP.call("switch", player, 1)
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
	_give(&"branch", 3)
	_give(&"root", 3)
	_give(&"root", 4)
	var got := []
	var pk := _picker(&"slingshot", 0, got)
	_expect(int(pk.call("preselected_index")) == i45 and pk.call("chosen") == [i45], "16: the plain Lv. 45 bone is preselected, never the rare one")
	_expect(str(pk.call("warning_text")) == "", "16: the preselected plain bone needs no warning")
	pk.call("choose", i60)
	_expect(str(pk.call("warning_text")).contains("Black Sheen"), "16: choosing the rare bone warns (%s)" % pk.call("warning_text"))
	pk.call("confirm")
	_expect(got == [i60], "16: the picker returns exactly the rare bone's slot (%s)" % [got])
	var rec: Dictionary = data.recipes.get(&"slingshot", {})
	var picks: Array = []
	for p in CR.default_picks(inv, rec):
		picks.append(p)
	_expect(picks.size() == 3 and picks[0] == i45, "16: the default plan would spend the plain bone (%s)" % [picks])
	picks[0] = [i60]  # exact-instance picks: one Array of bag slots per recipe slot (hook)
	var used: Array = CR.consume_for_craft(inv, rec, picks)
	var uids := used.map(func(s) -> String: return s.uid)
	_expect(uids.has(u60) and _find(u60) == -1 and _find(_uid(i45)) >= 0, "16: crafting consumes exactly the chosen bone")
	pk.queue_free()
	# The real path: the picks travel through Player -> PlayerActions -> StationCraft (a hand craft).
	_reset_bag()
	var j45 := _give(&"raptor_bone", 45)
	var j60 := _give(&"raptor_bone", 60, {"black_sheen": true})
	var k60 := _uid(j60)
	var k45 := _uid(j45)
	_give(&"branch", 3)
	_give(&"root", 3)
	_give(&"root", 4)
	var real: Array = []
	for p in CR.default_picks(inv, rec):
		real.append(p)
	real[0] = [j60]
	player.craft_recipe(&"slingshot", 1, real)
	var sc = player.station_craft
	_expect(sc.recipe_id == &"slingshot", "16: the craft started with the chosen picks")
	sc._finish_one()
	_expect(_find(k60) == -1 and _find(k45) >= 0 and inv.find_first(&"slingshot") >= 0, "16: the finished slingshot used the chosen Lv. 60 bone and kept the Lv. 45")

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
	_expect(int(pk.call("preselected_index")) == _find(b12), "17: the Lv. 12 berry is preselected")
	pk.call("choose", i25)
	pk.call("confirm")
	_expect(got == [i25], "17: the picker returns the Lv. 25 berry")
	var rec: Dictionary = data.recipes.get(&"camp_stew", {})
	var picks: Array = [[meat], [leaf], [i25]]  # exact-instance picks (hook)
	CR.consume_for_craft(inv, rec, picks)
	_expect(_find(b25) == -1 and _find(b12) >= 0 and _find(b42) >= 0, "17: cooking used the Lv. 25 berry and left the others")
	pk.queue_free()
	await _t17_craft_menu()

## The craft menu's ingredient opens the Bag's picker, and Craft spends exactly the choice. Twine (2
## fibre, by hand) so the real craft runs in the test; when every fibre left has a trait, Craft asks.
func _t17_craft_menu() -> void:
	var craft = (load("res://scenes/ui/craft.tscn") as PackedScene).instantiate()
	host.get_child(1).add_child(craft)
	craft.bind(player)
	player.craft_ui = craft
	_reset_bag()
	var f5 := _uid(_give(&"fibre_stalk", 5))
	var f9 := _uid(_give(&"fibre_stalk", 9))
	var f40 := _uid(_give(&"fibre_stalk", 40, {"tough_fiber": 3}))
	var rec: Dictionary = data.recipes.get(&"twine", {})
	craft.show_ui()
	craft._choose_recipe("twine")
	await process_frame
	var ing: Button = null
	for b in craft.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Fibre") and (b as Button).is_visible_in_tree():
			ing = b
	_expect(ing != null, "17: the twine detail shows its fibre as a button")
	if ing == null:
		craft.queue_free()
		return
	ing.pressed.emit()
	var pk = player.ui.get("_picker")
	_expect(player.ui.call("current_screen") == &"picker" and not craft.visible, "17: tapping the ingredient opens the picker over the craft menu")
	_expect(pk != null and pk.call("chosen") == [_find(f5), _find(f9)], "17: the two plain fibres are preselected (least valuable first)")
	pk.call("choose", _find(f40)) # a third pick replaces the earliest
	_expect(pk.call("chosen") == [_find(f9), _find(f40)] and str(pk.call("warning_text")) != "", "17: picking the Lv. 40 fibre replaces the Lv. 5 one and warns (%s)" % pk.call("warning_text"))
	pk.call("confirm")
	await process_frame
	_expect(craft.visible and player.ui.call("current_screen") == &"", "17: Use closes the picker and the craft menu comes back")
	craft._start(rec, 1)
	player.station_craft._finish_one()
	_expect(_find(f9) == -1 and _find(f40) == -1 and _find(f5) >= 0 and inv_count(&"twine") == 1, "17: Craft spent exactly the chosen Lv. 9 and Lv. 40 fibres")
	# Only fibre with traits left: Craft opens the picker instead of spending one silently.
	_reset_bag()
	_give(&"fibre_stalk", 30, {"tough_fiber": 2})
	_give(&"fibre_stalk", 41, {"tough_fiber": 3})
	craft.show_ui()
	craft._choose_recipe("twine")
	craft._start(rec, 1)
	_expect(player.ui.call("current_screen") == &"picker" and player.inventory.count_of(&"fibre_stalk") == 2, "17: with only trait fibre left, Craft asks which instead of spending them")
	player.ui.hide_ui()
	craft.hide_ui()
	craft.queue_free()

func inv_count(id: StringName) -> int:
	return player.inventory.count_of(id)

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
	if _need(["storage_screen", "item_picker"], "20 storage and picker sizes"):
		var box_inv = INV.new(60)
		box_inv.add(IS.make(&"wood_log", 1, {}, 14))
		var berry := _give(&"berry", 42, {"vivid_inspiration": true})
		for view in [Vector2(1600, 900), Vector2(844, 390), Vector2(804, 452)]:
			var box := Control.new()
			box.size = view
			host.get_child(1).add_child(box)
			var ss: Control = C["storage_screen"].new()
			box.add_child(ss)
			ss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ss.call("setup", player.inventory, box_inv, "Velociraptor A Cargo", player, &"cargo")
			ss.call("set_actions", true, false, true, "")
			ss.call("select_key", _uid(berry)) # the Bag tab with Transfer as the primary
			await process_frame
			await process_frame
			_check_targets(ss, view)
			# The reference's state: the container tab, a take-only notice, search open, all picked.
			ss.call("show_tab", &"box")
			ss.call("set_actions", false, false, false, "This box belongs to someone else: cannot take.")
			ss.get("toolbar").call("set_search", true)
			ss.get("toolbar").emit_signal("select_all_pressed")
			await process_frame
			await process_frame
			_check_targets(ss, view)
			ss.visible = false
			var pk: Control = C["item_picker"].new()
			box.add_child(pk)
			pk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pk.call("open", player.inventory, data.recipes.get(&"camp_stew", {}), 2, func(_p: Array) -> void: pass)
			pk.call("choose", berry) # the rare berry: the warning line is the longest panel
			await process_frame
			await process_frame
			_check_targets(pk, view)
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

# ---------------------------------------------------------------- 21: B4 polish (spec 13 s2, s16, s20, s21)

## Phase 5: restrained motion, desktop keys, trait classes by shape (never colour alone), the same
## layout rules at 1920x1080 and inside a phone's notch, and a full 142-slot bag opening in < 50 ms.
func _t21_polish() -> void:
	if not _need(["inv_theme", "bag_screen", "storage_screen", "character_screen", "item_inspect_panel", "inventory_slot"], "21 polish"):
		return
	var M: GDScript = load(UI + "inv_motion.gd") if ResourceLoader.exists(UI + "inv_motion.gd") else null
	_expect(M != null, "21: not built yet (inv_motion.gd)")
	if M == null:
		return
	_expect(float(M.OPEN_S) <= 0.12 and float(M.TAB_S) <= 0.08 and float(M.SETTLE_S) <= 0.12 and float(M.FLASH_S) <= 0.4, "21: motion is short: open <= 120 ms, tab <= 80 ms, settle and flash brief")
	var ui = player.ui
	ui.call("hide_ui")
	var first := -1
	for k in 12:
		var i := _give(&"berry", 10 + k)
		first = i if first < 0 else first
	# Motion: the Bag fades in as it opens and is fully shown well within the open time.
	ui.call("open_bag")
	var bag: Control = ui.get("_bag")
	_expect(bag.modulate.a < 1.0, "21: the Bag fades in as it opens (alpha %.2f at once)" % bag.modulate.a)
	await create_timer(0.3).timeout
	_expect(is_equal_approx(bag.modulate.a, 1.0), "21: the fade ends within the open time (alpha %.2f)" % bag.modulate.a)
	# Keys: arrows walk the selection in reading order and by rows; Enter runs the yellow action.
	var g = bag.get("grid")
	g.call("select_uid", "")
	_press(ui, KEY_RIGHT)
	_expect(g.call("selected_uid") == _uid(first), "21: Right with nothing selected picks the first item")
	_press(ui, KEY_RIGHT)
	var second: String = g.call("selected_uid")
	_press(ui, KEY_DOWN)
	var below: String = g.call("selected_uid")
	var cols: int = g.get("columns")
	_expect(second != _uid(first) and below == str(g.call("item_cells")[1 + cols].get("uid")), "21: Right steps to the next item, Down to the one below it")
	_press(ui, KEY_LEFT)
	_expect(g.call("selected_uid") == str(g.call("item_cells")[cols].get("uid")), "21: Left steps back in reading order")
	var club := _give(&"club", 22)
	g.call("select_uid", _uid(club))
	_press(ui, KEY_ENTER) # a weapon's yellow action is Equip: Equipment opens to compare it
	_expect(ui.call("current_screen") == &"equipment" and (ui.get("_equipment").get("list") as Object).call("selected_uid") == _uid(club), "21: Enter runs the yellow action on the selected item (Equip opens the compare)")
	ui.call("hide_ui")
	# Storage: Tab switches the tab (a quick fade), Enter transfers, the receiving tab lights up.
	var box = INV.new(20)
	box.add(IS.make(&"wood_log", 1, {}, 14))
	ui.call("show_storage", box, player, {"title": "Storage Box", "allow_deposit": true})
	var st: Control = ui.get("_storage")
	_press(ui, KEY_TAB)
	_expect(st.get("tab") == &"bag", "21: Tab switches the storage view to the Bag tab")
	_expect((st.call("active_grid") as Control).modulate.a < 1.0, "21: the tab switch fades the grid in")
	_press(ui, KEY_TAB)
	_press(ui, KEY_RIGHT)
	_press(ui, KEY_ENTER)
	_expect(box.used_slots() == 0 and player.inventory.count_of(&"wood_log") == 1, "21: Enter on the box tab runs Transfer to Bag")
	await process_frame
	_expect(float((st.get("_flash") as Dictionary)[&"bag"]) > 0.0, "21: the Bag tab lights up as the log arrives")
	ui.call("hide_ui")
	# Gear: arrows walk the 3x3, skipping the blank cell.
	ui.call("open_character", &"head")
	var ch = ui.get("_character")
	_press(ui, KEY_DOWN)
	_expect(ch.get("slot") == &"body", "21: Down on Character moves from the head cell to the torso")
	_press(ui, KEY_RIGHT)
	_press(ui, KEY_DOWN)
	_expect(ch.get("slot") == &"tool", "21: the blank corner cell is skipped (stays on the held-tool cell)")
	ui.call("hide_ui")
	# Accessibility: a trait's class reads by shape and words, not colour alone.
	var shapes: Dictionary = (load(UI + "inv_paint.gd") as GDScript).get_script_constant_map().get("PIP_SHAPES", {})
	_expect(shapes.size() == 3 and shapes.values()[0] != shapes.values()[1] and shapes.values()[1] != shapes.values()[2] and shapes.values()[0] != shapes.values()[2], "21: positive, negative and rare pips have three different shapes (%s)" % shapes)
	var ib := _give(&"raptor_bone", 60, {"firm": 8, "heavy": 2, "black_sheen": true})
	var p := _panel(player.inventory.slots[ib])
	p.call("apply_metrics", C["inv_theme"].call("metrics", Vector2(1600, 900)))
	var tips := []
	var stack: Array[Node] = [p]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Control and "cls" in n:
			tips.append([n.get("cls"), (n as Control).tooltip_text])
	var words := ",".join(PackedStringArray(tips.map(func(t: Array) -> String: return str(t[1]))))
	_expect(tips.size() == 3 and words.contains("Positive trait: Firm Lv. 8") and words.contains("Negative trait: Heavy Lv. 2") and words.contains("Rare trait: Black Sheen"), "21: each trait chip carries its class shape and says its class (%s)" % words)
	var tip: String = C["inventory_slot"].call("describe", player.inventory.slots[ib])
	_expect(tip.contains("Raptor Bone Lv. 60") and tip.contains("Rare trait: Black Sheen"), "21: a cell's hover tip says the item, its level and its traits in words (%s)" % tip.replace("\n", " | "))
	p.queue_free()
	# 1920x1080 and a notched phone: the same tap-target, text and safe-area rules.
	var T = C["inv_theme"]
	# A notch on the 844x390 canvas (insets 47 / 47 / 21, as the lab's --insets); 804x452 is the narrowest
	# canvas DisplayMode gives (an SE has no notch, a notched phone gets a wider canvas).
	for view in [Vector2(1920, 1080), Vector2(844, 390), Vector2(804, 452)]:
		var notch: bool = view.x == 844.0
		T.set("forced_insets", Vector4(47, 21, 0, 47) if notch else Vector4(-1, -1, -1, -1))
		for n in ["bag_screen", "storage_screen", "character_screen"]:
			var holder := Control.new()
			holder.size = view
			host.get_child(1).add_child(holder)
			var sc: Control = C[n].new()
			holder.add_child(sc)
			sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			if n == "storage_screen":
				sc.call("setup", player.inventory, box, "Storage Box", player, &"storage")
			else:
				sc.call("bind", player.inventory, player)
			await process_frame
			await process_frame
			_check_targets(sc, view)
			if notch:
				_check_safe(sc, view, Rect2(47, 0, view.x - 94, view.y - 21))
			if n == "bag_screen":
				var px: float = (sc.get("grid") as Object).call("cell_px")
				_expect(px >= float(T.call("label_room", 12)), "21: a Bag compartment holds NEW beside 'Lv. 60' at %s%s (cell %d < %d)" % [view, " with a notch" if notch else "", px, T.call("label_room", 12)])
			holder.queue_free()
	T.set("forced_insets", Vector4(-1, -1, -1, -1))
	# Performance: a full 142-slot bag opens in under 50 ms (build and layout, measured).
	_reset_bag()
	var inv = player.inventory
	inv.slot_count = 142
	inv.slots.resize(142)
	var k2 := 0
	while inv.used_slots() < 142:
		inv.add(IS.make(&"raptor_bone" if k2 % 3 == 0 else &"ore", 1, {"firm": 1 + k2 % 5} if k2 % 2 == 0 else {}, 10 + k2 % 50))
		k2 += 1
	ui.call("hide_ui")
	await process_frame
	var t0 := Time.get_ticks_usec()
	ui.call("open_bag")
	var cells: Array = (ui.get("_bag").get("grid") as Object).call("cells")
	var us := Time.get_ticks_usec() - t0
	print("[t_invui] 21 open 142/142: %d cells in %d us" % [cells.size(), us])
	_expect(cells.size() == 142 and us < 50000, "21: a full 142-slot bag opens in under 50 ms (%d cells, %d us)" % [cells.size(), us])
	ui.call("hide_ui")

# ---------------------------------------------------------------- 22: the in-game Bag (owner's third reference)

## "Inventory menu while in game, scrollview": opened in play (I, the HUD's Bag), the Bag is a panel
## docked on the right while the world stays visible and live on the left; the item card floats
## between them and shows every field the item's data has with only its valid actions; the grid
## scrolls (wheel, drag, fling); the toolbar's trash discards the exact instance after a confirm.
func _t22_ingame_dock() -> void:
	if not _need(["bag_screen", "inv_theme", "item_inspect_panel"], "22 in-game Bag"):
		return
	var ui = player.ui
	ui.call("hide_ui")
	var meat := _give(&"raw_meat", 23)
	player.inventory.slots[meat].process_count = 2
	var meat_uid := _uid(meat)
	var bone := _give(&"raptor_bone", 60, {"firm": 8})
	var bone_uid := _uid(bone)
	for k in 30: # enough rows to scroll at every canvas
		_give(&"herb_leaf", 10 + k)
	# Layout at the judge's canvas, the landscape phone (with a notch) and the SE canvas.
	for view in [Vector2(1600, 900), Vector2(844, 390), Vector2(804, 452)]:
		var notch: bool = view.x == 844.0
		C["inv_theme"].set("forced_insets", Vector4(47, 21, 0, 47) if notch else Vector4(-1, -1, -1, -1))
		var holder := Control.new()
		holder.size = view
		host.get_child(1).add_child(holder)
		var bs: Control = C["bag_screen"].new()
		holder.add_child(bs)
		bs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bs.call("bind", player.inventory, player)
		bs.call("select_uid", "")
		await process_frame
		await process_frame
		if not bs.has_method("dock_rect"):
			_expect(false, "22: the Bag is not docked (no dock_rect: it still fills the screen)")
			holder.queue_free()
			break
		var dock: Rect2 = bs.call("dock_rect")
		var desk: bool = view.x == 1600.0
		_expect(is_equal_approx(dock.end.x, view.x) and dock.position.y == 0.0 and dock.size.y == view.y, "22: the panel runs the full height of the right edge at %s (%s)" % [view, dock])
		var share: float = dock.size.x / view.x
		_expect((share >= 0.34 and share <= 0.4) if desk else (share >= 0.45 and share <= 0.6), "22: the panel takes %s of the width at %s (%.2f)" % ["37 %% (the reference)" if desk else "about half", view, share])
		_expect(bs.mouse_filter == Control.MOUSE_FILTER_IGNORE, "22: outside its panel the Bag lets the pointer through to the world")
		var covers := []
		for c in bs.get_children():
			if c is Control and (c as Control).visible and (c as Control).get_global_rect().position.x < holder.global_position.x + dock.position.x - 0.5:
				covers.append(c.name)
		_expect(covers.is_empty(), "22: with nothing selected nothing covers the world left of the panel at %s (%s)" % [view, covers])
		var g = bs.get("grid")
		var px: float = g.call("cell_px")
		_expect(int(g.get("columns")) == (5 if desk else 4) and px >= float(C["inv_theme"].call("label_room", 12)), "22: %d columns of %d px at %s, each holds NEW beside 'Lv. 60'" % [g.get("columns"), px, view])
		var tab: Control = bs.get("tab")
		var cap = bs.get("capacity")
		var count := "%d / %d" % [player.inventory.used_slots(), player.inventory.slot_count]
		_expect((tab.visible and str(tab.get("count")) == count) if desk else (cap.visible and cap.call("label_text") == count), "22: the capacity reads %s on the %s" % [count, "Bag tab" if desk else "header"])
		_expect((bs.get("rail") as Control).visible and (bs.get("toolbar") as Control).visible, "22: the category rail and the toolbar are on the panel")
		bs.call("select_uid", meat_uid)
		await process_frame
		var card: Control = bs.get("inspect")
		var cr := card.get_global_rect()
		var dl := holder.global_position.x + dock.position.x
		_expect(card.visible and cr.end.x <= dl + 0.5 and cr.position.x >= holder.global_position.x + (47.0 if notch else 0.0) - 0.5 and cr.size.x < dock.size.x, "22: the card floats between the world and the panel at %s (card %s, panel from %d)" % [view, cr, dl])
		_check_targets(bs, view)
		if notch:
			_check_safe(bs, view, Rect2(47, 0, view.x - 94, view.y - 21))
		holder.queue_free()
	C["inv_theme"].set("forced_insets", Vector4(-1, -1, -1, -1))
	# The card shows what the meat's data has and only its valid actions.
	var p := _panel(player.inventory.slots[_find(meat_uid)])
	p.call("apply_metrics", C["inv_theme"].call("dock_metrics", Vector2(1600, 900)) if C["inv_theme"].has_method("dock_metrics") else C["inv_theme"].call("metrics", Vector2(1600, 900)))
	var rows := "\n".join(Array(p.call("rows")))
	var food: GDScript = load("res://scripts/items/food.gd")
	var energy := "Energy  +%.0f" % food.call("energy_restore", player.inventory.slots[_find(meat_uid)])
	for want in ["Lv. 23", "Processed  ×2", "Meat", "Food", "\nRaw\n", energy, "Carnivore food", "Stomachache  25 %", "Create"]:
		_expect(rows.contains(want), "22: the meat's card shows '%s' (%s)" % [want.strip_edges(), rows.replace("\n", " / ")])
	var acts: Array = p.call("actions")
	_expect(not acts.is_empty() and acts[0] == &"eat" and not acts.has(&"equip"), "22: the meat's yellow action is Eat and nothing it cannot do (%s)" % [acts])
	p.queue_free()
	var stick := _panel(player.inventory.slots[_give(&"club", 22)])
	stick.call("apply_metrics", C["inv_theme"].call("metrics", Vector2(1600, 900)))
	var srows := "\n".join(Array(stick.call("rows")))
	_expect(srows.contains("Durability") and srows.contains("Maintenance") and srows.contains("Repair  Not possible") and not Array(stick.call("actions")).has(&"eat"), "22: a club's card has its durability and Maintenance, and no Eat (%s)" % srows.replace("\n", " / "))
	stick.queue_free()
	# Real pointer routing in a 1600x900 viewport: I opens the dock; taps on the panel and the card keep
	# it open, a tap on a cell selects it, wheel / drag / fling scroll, a tap on the world closes.
	var sv := SubViewport.new()
	sv.size = Vector2i(1600, 900)
	host.add_child(sv)
	var ui2: Control = (load("res://scenes/ui/inventory.tscn") as PackedScene).instantiate()
	sv.add_child(ui2)
	ui2.call("bind", player.inventory, player)
	ui2.visible = true # what the I key and the HUD's Bag entry do
	await process_frame
	await process_frame
	var bag: Control = ui2.get("_bag")
	_expect(ui2.call("current_screen") == &"bag" and bag != null and bag.has_method("dock_rect"), "22: I / the HUD's Bag opens the docked Bag")
	if bag == null or not bag.has_method("dock_rect"):
		sv.queue_free()
		return
	var g2 = bag.get("grid")
	var cell: Control = null
	for c in g2.call("item_cells"):
		if str(c.get("uid")) == bone_uid:
			cell = c
	_tap(sv, cell.get_global_rect().get_center() if cell else Vector2(1300, 200))
	await process_frame
	_expect(g2.call("selected_uid") == bone_uid and (bag.get("inspect") as Control).visible, "22: a tap on a cell selects that instance and floats its card in")
	var dock2: Rect2 = bag.call("dock_rect")
	_tap(sv, Vector2(dock2.position.x + 6.0, dock2.position.y + dock2.size.y * 0.5)) # the panel's own margin
	_tap(sv, (bag.get("inspect") as Control).get_global_rect().get_center())
	await process_frame
	_expect(ui2.visible and g2.call("selected_uid") == bone_uid, "22: taps on the panel and on the card keep the Bag open and the selection")
	var sc: ScrollContainer = null
	for c in g2.get_children():
		if c is ScrollContainer:
			sc = c
	var gc: Vector2 = (g2 as Control).get_global_rect().get_center()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = gc
	wheel.global_position = gc
	sv.push_input(wheel)
	await process_frame
	var mid := sc.scroll_vertical
	await create_timer(0.25).timeout
	_expect(sc.scroll_vertical > 0 and mid < sc.scroll_vertical, "22: a wheel notch glides the grid down (at once %d, after 0.25 s %d)" % [mid, sc.scroll_vertical])
	sc.scroll_vertical = 0
	await process_frame
	var sel := str(g2.call("selected_uid"))
	_mouse(sv, gc, true)
	var at := gc
	for k in 6:
		at += Vector2(0, -24)
		var mm := InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		mm.relative = Vector2(0, -24)
		mm.velocity = Vector2(0, -1400)
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		sv.push_input(mm)
	var dragged := sc.scroll_vertical
	_mouse(sv, at, false)
	await create_timer(0.15).timeout
	_expect(dragged >= 100 and sc.scroll_vertical > dragged and g2.call("selected_uid") == sel, "22: a drag scrolls the grid with the pointer (%d px), keeps gliding after release (%d px) and selects nothing" % [dragged, sc.scroll_vertical])
	# The trash: a confirm on the card first, Keep keeps; Discard removes exactly that instance; a locked one stays.
	var bar = bag.get("toolbar")
	if not bar.has_signal("trash_pressed"):
		_expect(false, "22: the toolbar has no trash")
	else:
		g2.call("select_uid", bone_uid)
		bar.emit_signal("trash_pressed")
		var card2 = bag.get("inspect")
		_expect(Array(card2.call("actions")) == [&"discard", &"keep"] and "\n".join(Array(card2.call("rows"))).contains("gone for good"), "22: the trash asks on the card first (%s)" % [card2.call("actions")])
		(card2.call("button_for", &"keep") as Button).pressed.emit()
		_expect(_find(bone_uid) >= 0, "22: Keep keeps the bone")
		bar.emit_signal("trash_pressed")
		(card2.call("button_for", &"discard") as Button).pressed.emit()
		_expect(_find(bone_uid) < 0 and _find(meat_uid) >= 0, "22: Discard removes exactly the selected bone")
		var mi := _find(meat_uid)
		player.inventory.slots[mi].set_flag(&"locked", true)
		g2.call("select_uid", meat_uid)
		bar.emit_signal("trash_pressed")
		_expect(not Array(card2.call("actions")).has(&"discard") and _find(meat_uid) >= 0, "22: a locked item is never offered for discard")
		player.inventory.slots[mi].set_flag(&"locked", false)
	_tap(sv, Vector2(200, 450)) # the world left of the card
	await process_frame
	_expect(not ui2.visible and ui2.call("current_screen") == &"", "22: a tap on the world beside the Bag closes it")
	sv.queue_free()

func _mouse(vp: Viewport, at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.position = at
	e.global_position = at
	vp.push_input(e)

## A left click (press and release in place), as a tap on a phone arrives.
func _tap(vp: Viewport, at: Vector2) -> void:
	_mouse(vp, at, true)
	_mouse(vp, at, false)

## A key press as the desktop sends it, to the bag family.
func _press(ui: Object, key: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	e.physical_keycode = key
	e.pressed = true
	ui.call("_unhandled_input", e)

## Every button and panel of `root` sits inside the phone's safe area (the header's black may run
## under the notch; its controls may not).
func _check_safe(root: Control, view: Vector2, safe: Rect2) -> void:
	var out := []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if not (n is Control) or not (n as Control).is_visible_in_tree() or n is ScrollContainer:
			continue
		stack.append_array(n.get_children())
		var c := n as Control
		var panel: bool = c.get_script() in [C["inventory_grid"], C["item_inspect_panel"], load(UI + "bag_toolbar.gd")]
		if (c is BaseButton or panel) and not safe.grow(1.0).encloses(c.get_global_rect()):
			out.append("%s %s" % [c.name, c.get_global_rect()])
	_expect(out.is_empty(), "21: controls stay inside the safe area at %s (%s)" % [view, out.slice(0, 4)])

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
