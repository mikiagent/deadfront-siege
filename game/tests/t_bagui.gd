extends SceneTree
## BAGUI (owner 2026-10-28): the bag without backpacks. The filter rail and the Sort dropdown change
## only the draw order; a locked item cannot be trashed (single or batch); the header counts the
## worn backpack's spaces (backpacks are the only capacity source) and the CurrencyBar the balances;
## rare perks roll a tier I-V (higher rarer, a better tool
## shifts it) and a craft keeps the primary's tier; the item card shows tags, perks with tiers,
## swatches, maintenance and the recipes the item goes into.
## Run: Godot --headless --path game --script res://tests/t_bagui.gd -> "[t_bagui] PASS".

var _fails: PackedStringArray = []
var _ran := false
var IS: GDScript
var INV: GDScript
var UI: GDScript
var GRID: GDScript
var CARD: GDScript
var IA: GDScript
var IT: GDScript
var WORLD: Node
var CR: GDScript
var LR: GDScript
var FD: GDScript

func _process(_delta: float) -> bool:
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null or _ran:
		return false
	_ran = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_bagui] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _json(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))

func _run() -> void:
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	UI = load("res://scripts/ui/inventory_ui.gd")
	GRID = load("res://scripts/ui/bag_grid.gd")
	CARD = load("res://scripts/ui/item_inspect_panel.gd")
	IA = load("res://scripts/ui/inv_attributes.gd")
	IT = load("res://scripts/items/item_tags.gd")
	CR = load("res://scripts/items/crafting.gd")
	LR = load("res://scripts/gather/loot_roller.gd")
	FD = load("res://scripts/items/food.gd")
	_test_sort()
	_test_tiers()
	_test_card()
	WORLD = get_root().get_node("World")
	_test_tags()
	await _test_screen()
	await _test_chest()
	_test_sail()
	if _fails.is_empty():
		print("[t_bagui] PASS")
		quit(0)
	else:
		print("[t_bagui] FAIL count=%d" % _fails.size())
		quit(1)

func _test_sort() -> void:
	var inv = INV.new(10)
	inv.add(IS.make(&"stone", 1, {}, 3))        # common
	inv.add(IS.make(&"metal_shard", 1, {}, 2))  # uncommon
	inv.add(IS.make(&"berry", 1, {}, 9))
	inv.slots[0].created_at = 100
	inv.slots[1].created_at = 300
	inv.slots[2].created_at = 200
	var before: String = JSON.stringify(inv.to_array())
	_expect((GRID.view_order(inv, "rarity", "") as Array).slice(0, 1) == [1], "Sort by Rarity draws the uncommon shard first (%s)" % [GRID.view_order(inv, "rarity", "")])
	_expect((GRID.view_order(inv, "newest", "") as Array).slice(0, 3) == [1, 2, 0], "Sort by Newest draws the latest first (%s)" % [GRID.view_order(inv, "newest", "")])
	_expect((GRID.view_order(inv, "level", "") as Array).slice(0, 3) == [2, 0, 1], "Sort by Level draws 9, 3, 2 (%s)" % [GRID.view_order(inv, "level", "")])
	_expect(JSON.stringify(inv.to_array()) == before, "sorting never moves an item")

func _test_tiers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := [0, 0, 0, 0, 0, 0]
	var sum_stone := 0
	for i in 20000:
		var t: int = LR.roll_tier(rng)
		counts[t] += 1
		sum_stone += t
	_expect(counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > counts[4] and counts[4] > counts[5] and counts[5] > 0, "higher tiers are rarer and V happens (%s)" % [counts.slice(1)])
	var sum_steel := 0
	for i in 20000:
		sum_steel += LR.roll_tier(rng, &"steel")
	_expect(sum_steel > sum_stone, "a better tool shifts the tiers up (%d > %d)" % [sum_steel, sum_stone])
	var bone = IS.make(&"bone", 1, {"black_sheen": 4}, 20)
	_expect(IA.line((IA.sections(bone).rare as Array)[0]) == "Black Sheen IV", "a tier-4 perk reads Black Sheen IV")
	_expect(IA.line((IA.sections(IS.make(&"bone", 1, {"black_sheen": true})).rare as Array)[0]) == "Black Sheen I", "an old save's true reads as tier I")
	# Inheritance: the primary's tier carries into the craft; a rolled one takes its rolled tier.
	var rec: Dictionary = {}
	for r: Dictionary in CR.all_recipes():
		if str(r.get("id", "")) == "improvised_stone_knife":
			rec = r
	var flint = IS.make(&"stone", 1, {"black_sheen": 3}, 5)
	var out = CR.build_output(rec, flint, 5)
	var oc = CR.roll_outcome_for(rec, flint, 100.0, rng)
	CR.apply_outcome(out, rec, oc)
	_expect(int(out.attributes.get("black_sheen", 0)) == 3, "a crafted knife keeps the primary's Black Sheen III (%s)" % out.attributes.get("black_sheen"))
	var plain = IS.make(&"stone", 1, {}, 5)
	var made = CR.build_output(rec, plain, 5)
	CR.apply_outcome(made, rec, {"success": true, "flawless": false, "rare": &"low_vibration", "rare_tier": 4})
	_expect(int(made.attributes.get("low_vibration", 0)) == 4, "a rolled perk takes its rolled tier (%s)" % made.attributes.get("low_vibration"))

func _test_card() -> void:
	var log = IS.make(&"wood_log", 1, {"black_sheen": 2}, 12)
	_expect(CARD.tags_for(log).has("Wood"), "a log's tags include Wood (%s)" % [CARD.tags_for(log)])
	var into: Array = CARD.craft_into(log)
	_expect(not into.is_empty(), "a log lists recipes it goes into (%s)" % [into])
	_expect((CARD.swatches(log) as Array).size() == 3, "a log with a tint shows three swatches")
	_expect(CARD.repair_text(log) == "Repair: Not Possible", "maintenance says repair is not possible")
	_expect(UI.use_action(["eat", "food1", "drop"] as Array[String]) == "eat" and UI.use_action(["equip", "drop"] as Array[String]) == "equip" and UI.use_action(["drop"] as Array[String]) == "", "Use picks the main action")

## The screen: the rail filters, the Sort dropdown sorts, Lock blocks Trash, the header counts the worn bag.
func _test_screen() -> void:
	for view in [Vector2i(844, 390), Vector2i(1600, 900)]:
		get_root().size = view
		get_root().content_scale_size = view
		await process_frame
		var inv = INV.new(30)
		inv.add(IS.make(&"berry", 1, {}, 12))
		inv.add(IS.make(&"stone", 1, {}, 4))
		inv.add(IS.make(&"wood_log", 1, {"black_sheen": 3}, 20))
		var ui = load("res://scenes/ui/inventory.tscn").instantiate()
		get_root().add_child(ui)
		ui.bind(inv, null)
		ui.visible = true
		ui.rebuild()
		await process_frame
		(ui._rail_btns["food"] as Button).pressed.emit()
		_expect(ui._grid.filter_id == "food" and ui._grid.slot_count() == 1, "%s: the Food rail tab shows only the berry (%d)" % [view, ui._grid.slot_count()])
		(ui._rail_btns[""] as Button).pressed.emit()
		_expect(ui._grid.filter_id == "" and ui._grid.slot_count() == 30, "%s: All shows every slot" % view)
		ui._sort_btn.select(GRID.SORTS.find("level"))
		ui._sort_btn.item_selected.emit(GRID.SORTS.find("level"))
		_expect(ui._grid.sort_key == "level", "%s: the Sort dropdown sorts by level" % view)
		# Lock blocks Trash.
		var stone_i: int = inv.find_first(&"stone")
		ui._on_bag_slot_tapped(stone_i)
		ui._toggle_lock()
		_expect(inv.slots[stone_i].is_locked() and ui._destroy_btn.disabled, "%s: a locked stone's Trash is disabled" % view)
		ui._destroy_selected()
		ui._destroy_selected()
		_expect(inv.count_of(&"stone") == 1, "%s: Trash twice on a locked stone keeps it" % view)
		var res: Dictionary = UI.batch_check(inv, [stone_i] as Array[int], "destroy", true, true)
		_expect((res["ok"] as Array).is_empty() and res["skip"].get(stone_i) == "locked", "%s: a batch trash skips the locked stone" % view)
		ui._toggle_lock()
		ui._destroy_selected()
		_expect(ui._destroy_btn.text != "Trash", "%s: the first Trash tap asks for confirmation (%s)" % [view, ui._destroy_btn.text])
		ui._destroy_selected()
		_expect(inv.count_of(&"stone") == 0, "%s: the second tap trashes the unlocked stone" % view)
		# The card: perks with tiers, Use for food.
		var log_i: int = inv.find_first(&"wood_log")
		ui._on_bag_slot_tapped(log_i)
		var texts: Array = (ui._card.shown_rows as Array).map(func (r: Dictionary) -> String: return str(r.text))
		_expect(texts.has("Black Sheen III"), "%s: the card shows Black Sheen III (%s)" % [view, texts])
		_expect(ui._use_btn.visible and ui._use_btn.disabled, "%s: a log's Use is shown but disabled" % view)
		ui._on_bag_slot_tapped(inv.find_first(&"berry"))
		_expect(not ui._use_btn.disabled and ui._use_btn.text.contains("Eat"), "%s: a berry's Use eats (%s)" % [view, ui._use_btn.text])
		# The worn backpack's spaces show in the header; the parked expand button stays hidden.
		inv.add(IS.make(&"basic_bag", 1, {}, 1))
		var cap0: int = inv.capacity()
		_expect(inv.equip_at(inv.find_first(&"basic_bag")), "%s: a Basic Bag can still be worn" % view)
		ui.rebuild()
		_expect(inv.capacity() > cap0 and ui._cap_label.text.ends_with("/ %d" % inv.capacity()), "%s: the header counts the worn bag (%s, capacity %d)" % [view, ui._cap_label.text, inv.capacity()])
		WORLD.warp_gems = 1363
		WORLD.t_stones = 9017
		ui._currency.refresh()
		_expect(ui._currency.gems_label.text == "1,363" and ui._currency.stones_label.text == "9,017", "%s: the header shows both balances (%s / %s)" % [view, ui._currency.gems_label.text, ui._currency.stones_label.text])
		ui.hide_ui()
		ui.queue_free()
		await process_frame
	get_root().content_scale_size = Vector2i(1600, 900)

## A chest opens the bag panel with two tabs ("Bag used / cap", "<chest> used / cap"); a selection
## is deposited or withdrawn, a full chest keeps the rest in the bag, a locked item stays.
func _test_chest() -> void:
	get_root().size = Vector2i(844, 390)
	get_root().content_scale_size = Vector2i(844, 390)
	await process_frame
	var inv = INV.new(20)
	for k in 4:
		inv.add(IS.make(&"stone", 1, {}, 1 + k))
	inv.slots[3].set_flag(&"locked", true)
	var chest = INV.new(2)
	var ui = load("res://scenes/ui/inventory.tscn").instantiate()
	get_root().add_child(ui)
	ui.bind(inv, null)
	ui.show_storage(chest, null, {"title": "Chest", "allow_deposit": true})
	ui._show_page("bag", "bag")
	_expect(ui._bag_tab.text == "Bag 4 / 20" and ui._store_tab.text == "Chest 0 / 2", "two tabs with used / capacity (%s | %s)" % [ui._bag_tab.text, ui._store_tab.text])
	ui._on_toggle_multi()
	for i in 4:
		ui._grid.toggle_multi(i)
	ui._update_batch_bar()
	_expect(ui._batch_store_btn.visible and ui._batch_store_btn.text == "Deposit", "the bag tab's batch bar offers Deposit")
	ui._on_batch_store()
	_expect(chest.used_slots() == 2 and inv.used_slots() == 2, "Deposit fills the 2-slot chest and keeps the rest (chest %d, bag %d)" % [chest.used_slots(), inv.used_slots()])
	_expect(inv.slots[3] != null and inv.slots[3].is_locked(), "the locked stone was not deposited")
	ui._set_multi_mode(false)
	ui._show_page("bag", "store")
	ui._on_toggle_multi()
	ui._pet_grid.toggle_multi(0)
	ui._update_batch_bar()
	_expect(ui._batch_take_btn.visible and ui._batch_take_btn.text == "Withdraw", "the chest tab's batch bar offers Withdraw")
	ui._on_batch_take()
	_expect(chest.used_slots() == 1 and inv.used_slots() == 3, "Withdraw brings the selected stone back (chest %d, bag %d)" % [chest.used_slots(), inv.used_slots()])
	ui.hide_ui()
	ui.queue_free()
	await process_frame
	get_root().content_scale_size = Vector2i(1600, 900)

## Owner 2026-10-28: a tendon is classified Strap / Tendon / Edible / Meat, can be eaten, and twists
## into a bowstring (any item tagged strap fills that slot).
func _test_tags() -> void:
	var tags: Array = IT.tags(&"predator_tendon")
	_expect(IT.has_tag(&"predator_tendon", &"strap") and IT.has_tag(&"predator_tendon", &"edible") and IT.has_tag(&"predator_tendon", &"meat"), "a tendon is tagged strap, edible and meat (%s)" % [tags])
	var tendon = IS.make(&"predator_tendon", 1, {}, 10)
	_expect(FD.is_food(tendon) and UI.valid_actions(tendon, {}).has("eat"), "a tendon can be eaten (%s)" % [UI.valid_actions(tendon, {})])
	_expect(CARD.tags_for(tendon).has("Strap") and CARD.tags_for(tendon).has("Edible"), "the card shows its tag chips (%s)" % [CARD.tags_for(tendon)])
	var inv = INV.new(10)
	inv.add(tendon)
	var rec: Dictionary = CR.recipe(&"bowstring")
	var picks: Array[int] = CR.default_picks(inv, rec)
	_expect(not rec.is_empty() and CR.picks_valid(inv, rec, picks), "a tendon fills the bowstring recipe (%s)" % [picks])
	var out = CR.build_output(rec, tendon, 10)
	_expect(out.def_id == &"bowstring", "the recipe makes a Bowstring (%s)" % out.def_id)

## Owner 2026-10-28: Harbour sailings cost Warp Gems; too few refuses with a clear line and spends nothing.
func _test_sail() -> void:
	WORLD.warp_gems = 7
	_expect(WORLD.pay_sail(5) == "" and WORLD.warp_gems == 2, "a 5-gem sailing spends 5 Warp Gems (left %d)" % WORLD.warp_gems)
	var why: String = WORLD.pay_sail(5)
	_expect(why.begins_with("Needs 5 Warp Gems") and WORLD.warp_gems == 2, "too few gems refuses and spends nothing (%s)" % why)
	_expect(WORLD.START_WARP_GEMS >= 5, "a new game can afford a sailing (%d)" % WORLD.START_WARP_GEMS)

