extends SceneTree
## Spec 13 inventory screens on canon's bag (INVSCREENS): the item card's actions per item kind,
## trait colour classes, NEW tags, presentation-only Auto Sort / filter, storage and cargo transfers
## that conserve instances, gear presets that round-trip through a save, and the layout at
## 844x390 and 1600x900: every visible tap target >= 64 px, nothing outside its panel or the view.
## Run: Godot --headless --path game --script res://tests/t_invscreens.gd -> "[t_invscreens] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

var _fails: PackedStringArray = []
var _ran := false
var IS: GDScript
var INV: GDScript
var UI: GDScript
var GP: GDScript
var IA: GDScript
var CARD: GDScript
var GRID: GDScript

func _process(_delta: float) -> bool:
	if get_root() == null or get_root().get_node_or_null("Data") == null or _ran:
		return false
	_ran = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_invscreens] FAIL %s" % what)

func _json(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))

func _run() -> void:
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	UI = load("res://scripts/ui/inventory_ui.gd")
	GP = load("res://scripts/items/gear_presets.gd")
	IA = load("res://scripts/ui/inv_attributes.gd")
	CARD = load("res://scripts/ui/item_inspect_panel.gd")
	GRID = load("res://scripts/ui/bag_grid.gd")
	_test_actions()
	_test_traits()
	_test_sort_filter()
	_test_presets()
	await _test_screen()
	await _test_paint()
	if _fails.is_empty():
		print("[t_invscreens] PASS")
		quit(0)
	else:
		print("[t_invscreens] FAIL count=%d" % _fails.size())
		quit(1)

# ---------------------------------------------------------------- 1 actions per kind

func _test_actions() -> void:
	var berry = IS.make(&"berry", 1, {}, 12)
	var knife = IS.make(&"stone_knife", 1, {}, 5)
	var bag = IS.make(&"basic_bag", 1, {}, 10)
	var kit = IS.make(&"campfire_kit", 1)
	var hood = IS.make(&"forager_hood", 1, {}, 3)
	var a: Array = UI.valid_actions(berry, {})
	_expect(a.has("eat") and a.has("food1") and not a.has("equip") and not a.has("place"), "a berry offers Eat, never Equip (%s)" % [a])
	a = UI.valid_actions(berry, {"pet": true})
	_expect(a.has("feed"), "a berry offers Feed with a pet out (%s)" % [a])
	a = UI.valid_actions(knife, {})
	_expect(a.has("equip") and not a.has("eat") and not a.has("inspect"), "a weapon offers Equip, never Eat (%s)" % [a])
	a = UI.valid_actions(bag, {})
	_expect(a.has("equip") and a.has("inspect") and not a.has("eat"), "a bag offers Equip and Inspect (%s)" % [a])
	a = UI.valid_actions(kit, {})
	_expect(a.has("place") and not a.has("equip") and not a.has("eat"), "a building kit offers Place (%s)" % [a])
	a = UI.valid_actions(hood, {"deposit": true})
	_expect(a.has("equip") and a.has("store") and a.has("drop"), "an open box adds Store (%s)" % [a])
	a = UI.valid_actions(hood, {})
	_expect(not a.has("store") and not a.has("take"), "no box, no Store (%s)" % [a])
	a = UI.valid_actions(berry, {"where": "store"})
	_expect(a == ["take"], "a box item offers only Transfer to Bag (%s)" % [a])
	a = UI.valid_actions(berry, {"where": "store", "take": false})
	_expect(a.is_empty(), "a take-only box the player cannot take from offers nothing (%s)" % [a])
	_expect(UI.valid_actions(null, {}).is_empty(), "no item, no actions")

# ---------------------------------------------------------------- 2 trait colours

func _test_traits() -> void:
	var bone = IS.make(&"bone", 1, {"firm": 8, "low_density": 3, "black_sheen": true, "tint": "#ffffff", "hardness": 4}, 60)
	var sec: Dictionary = IA.sections(bone)
	_expect((sec.positive as Array).size() == 1 and IA.line(sec.positive[0]) == "Firm Lv. 8", "Firm Lv. 8 is positive (%s)" % [sec.positive])
	_expect((sec.negative as Array).size() == 1 and IA.line(sec.negative[0]) == "Low Density Lv. 3", "Low Density Lv. 3 is negative (%s)" % [sec.negative])
	_expect((sec.rare as Array).size() == 1 and IA.line(sec.rare[0]) == "Black Sheen", "Black Sheen is rare (%s)" % [sec.rare])
	_expect(IA.has_rare(bone) and not IA.has_rare(IS.make(&"bone", 1, {"firm": 2})), "only a rare trait marks the slot")
	var rows: Array = CARD.rows_for(bone)
	var by_cls := {}
	for r: Dictionary in rows:
		by_cls[str(r.text)] = str(r.cls)
		_expect(not str(r.text).to_lower().contains("tint") and not str(r.text).to_lower().contains("hardness"), "technical keys never show (%s)" % r.text)
	_expect(by_cls.get("Firm Lv. 8") == "positive" and by_cls.get("Low Density Lv. 3") == "negative" and by_cls.get("Black Sheen") == "rare", "the card classes each trait (%s)" % [by_cls])
	_expect(CARD.color_of("positive") == Color("#D9B65A") and CARD.color_of("negative") == Color("#A6A69B") and CARD.color_of("rare") == Color("#67B84E"),
		"gold positive, grey negative, green rare")
	for t in load("res://scripts/items/crafting.gd").rare_attributes():
		_expect(IA.class_of(str(t)) == "rare", "rules.json rare trait %s reads green" % t)

# ---------------------------------------------------------------- sort / filter

func _test_sort_filter() -> void:
	var inv = INV.new(12)
	inv.add(IS.make(&"stone", 1, {}, 3))
	inv.add(IS.make(&"berry", 1, {}, 40))
	inv.add(IS.make(&"stone_knife", 1, {}, 9))
	inv.add(IS.make(&"bone", 1, {"black_sheen": true}, 20))
	inv.slots[0].set_flag(&"locked", true)
	var before: String = JSON.stringify(inv.to_array())
	var order: Array = GRID.view_order(inv, "level", "")
	_expect(order.size() == 12 and order.slice(0, 4) == [1, 3, 2, 0], "Auto Sort by level draws 40, 20, 9, 3 then the empties (%s)" % [order])
	var seen := {}
	for i in order:
		seen[i] = true
	_expect(seen.size() == 12, "every slot drawn once")
	_expect(GRID.view_order(inv, "", "food") == [1], "the Food filter draws only the berry")
	_expect(GRID.view_order(inv, "", "rare") == [3], "the Rare filter draws the black-sheen bone")
	_expect(GRID.view_order(inv, "", "locked") == [0], "the Locked filter draws the locked stone")
	_expect(GRID.view_order(inv, "", "tools") == [2], "the Tools filter draws the knife")
	_expect(JSON.stringify(inv.to_array()) == before, "sorting and filtering never move or change an item")

# ---------------------------------------------------------------- presets

func _test_presets() -> void:
	var inv = INV.new(20)
	inv.add(IS.make(&"stone_knife", 1, {}, 5))
	inv.add(IS.make(&"forager_hood", 1, {}, 3))
	inv.add(IS.make(&"bone_knife", 1, {}, 7))
	var knife_uid: String = inv.slots[0].uid
	var bone_uid: String = inv.slots[2].uid
	inv.equip_at(0)
	inv.equip_at(inv.find_first(&"forager_hood"))
	_expect(GP.switch(inv, 0, 60) == "" and GP.has_set(inv, 0), "preset 1 captures what is worn")
	_expect(GP.switch(inv, 1, 60) == "" and GP.has_set(inv, 1), "preset 2 starts as a copy")
	inv.equip_at(inv.find_first(&"bone_knife"), &"weapon")
	inv.unequip(&"head")
	_expect(GP.switch(inv, 0, 60) == "", "back to preset 1")
	_expect(inv.worn(&"weapon") != null and inv.worn(&"weapon").uid == knife_uid and inv.worn(&"head") != null, "preset 1 puts the exact knife and the hood back on")
	_expect(GP.switch(inv, 1, 60) == "" and inv.worn(&"weapon").uid == bone_uid and inv.worn(&"head") == null, "preset 2 remembered the bone knife and no hood")
	_expect(GP.switch(inv, 3, 5).begins_with("Preset 4 unlocks"), "a preset not yet earned refuses with its level")
	var units_before: int = inv.used_slots() + inv.equipment.size()
	var back = INV.new(20)
	back.load_array(_json(inv.to_array()))
	back.extras_from_dict(_json(inv.extras_to_dict()))
	_expect(_json(back.presets) == _json(inv.presets) and back.used_slots() + back.equipment.size() == units_before, "presets survive a save (%s)" % [back.presets])
	# Old saves: no presets key loads as {} and re-saves without one (additive change).
	var old = INV.new(20)
	old.extras_from_dict({"worn": {}, "quick_food": ["", ""], "tool_index": -1})
	_expect(old.presets.is_empty() and not old.extras_to_dict().has("presets"), "an old save without presets loads and re-saves unchanged")
	var forged: Dictionary = GP.sanitize({"active": 9, "sets": [{"weapon": "lzz", "head": "l1a", "nose": "l2b"}, "x"]})
	_expect(forged.active == 1 and forged.sets[0] == {"head": "l1a"} and forged.sets[1] == null, "a forged preset row is cleaned (%s)" % [forged])
	_expect(GP.sanitize("junk").is_empty() and GP.sanitize({"sets": []}).is_empty(), "junk presets load as none")

# ---------------------------------------------------------------- screen: NEW, transfers, layout

func _test_screen() -> void:
	for view in [Vector2i(844, 390), Vector2i(1600, 900)]:
		get_root().size = view
		get_root().content_scale_size = view
		await process_frame
		var inv = INV.new(30)
		inv.add(IS.make(&"berry", 1, {}, 12))
		inv.add(IS.make(&"stone_knife", 1, {}, 5))
		inv.add(IS.make(&"bone", 1, {"firm": 8, "low_density": 3, "black_sheen": true}, 60))
		inv.add(IS.make(&"basic_bag", 1, {}, 10))
		var ui = load("res://scenes/ui/inventory.tscn").instantiate()
		get_root().add_child(ui)
		ui.bind(inv, null)
		ui.visible = true
		ui.rebuild()
		# NEW: the bound bag is the baseline; a pickup is NEW until tapped.
		_expect(ui._new_uids.is_empty(), "%s: a loaded bag shows no NEW" % view)
		inv.add(IS.make(&"stone", 1, {}, 4))
		var stone_i: int = inv.find_first(&"stone")
		var cell = ui._grid.cell_for(stone_i)
		_expect(cell != null and cell.is_new and ui._new_uids.has(inv.slots[stone_i].uid), "%s: a pickup shows NEW" % view)
		ui._on_bag_slot_tapped(stone_i)
		_expect(not ui._new_uids.has(inv.slots[stone_i].uid) and not ui._grid.cell_for(stone_i).is_new, "%s: tapping it acknowledges NEW" % view)
		# The card: a berry shows Eat and no Equip; the bone's traits are classed.
		ui._on_bag_slot_tapped(inv.find_first(&"berry"))
		_expect(ui._card.visible and ui._eat_btn.visible and not ui._equip_btn.visible, "%s: the berry's card offers Eat, not Equip" % view)
		ui._on_bag_slot_tapped(inv.find_first(&"stone_knife"))
		_expect(ui._equip_btn.visible and not ui._eat_btn.visible, "%s: the knife's card offers Equip, not Eat" % view)
		ui._on_bag_slot_tapped(inv.find_first(&"bone"))
		await _layout(ui, view, "bag card")
		# Storage tab: transfers both ways conserve every instance.
		var box = INV.new(10)
		box.add(IS.make(&"wood_log", 1, {}, 8))
		ui.show_storage(box, null, {"title": "Small Box", "take_all": true, "allow_deposit": true})
		var all_before: Dictionary = inv.uids().merged(box.uids())
		_expect(ui._tab == "store" and ui._pet_grid.visible and not ui._grid.visible, "%s: a box opens on its own tab" % view)
		ui._on_store_slot_tapped(0)
		_expect(ui._take_btn.visible and ui._take_btn.text == "Transfer to Bag", "%s: a box item offers Transfer to Bag" % view)
		await _layout(ui, view, "store tab")
		var log_uid: String = box.slots[0].uid
		ui._take_btn.pressed.emit()
		_expect(box.used_slots() == 0 and inv.uids().has(log_uid), "%s: Transfer to Bag moves the exact log" % view)
		ui._show_page("bag", "bag")
		var bone_i: int = inv.find_first(&"bone")
		var bone_uid: String = inv.slots[bone_i].uid
		ui._on_bag_slot_tapped(bone_i)
		_expect(ui._store_btn.visible and ui._store_btn.text == "Transfer to Small Box", "%s: a bag item offers Transfer to Small Box" % view)
		ui._store_btn.pressed.emit()
		_expect(box.uids().has(bone_uid) and not inv.uids().has(bone_uid), "%s: the exact bone moves to the box" % view)
		_expect(inv.uids().merged(box.uids()) == all_before, "%s: transfers conserve every instance (%d)" % [view, all_before.size()])
		# Dinosaur cargo: the same grid on a cargo tab.
		var rec = load("res://scripts/pets/pet_record.gd").new()
		rec.name = "Raptor"
		rec.bag = INV.new(10)
		ui.show_pet_bag(rec)
		_expect(ui._store_tab.visible and ui._store_tab.text.begins_with("Raptor cargo"), "%s: cargo opens as its own tab (%s)" % [view, ui._store_tab.text])
		ui._show_page("bag", "bag")
		ui._on_bag_slot_tapped(inv.find_first(&"berry"))
		var berry_uid: String = inv.slots[inv.find_first(&"berry")].uid
		ui._store_btn.pressed.emit()
		_expect(rec.bag.uids().has(berry_uid), "%s: a berry goes into the cargo" % view)
		ui._show_page("bag", "store")
		ui._on_store_slot_tapped(0)
		ui._take_btn.pressed.emit()
		_expect(inv.uids().has(berry_uid) and rec.bag.used_slots() == 0, "%s: and comes back out" % view)
		# Select mode toolbar.
		ui._show_page("bag", "bag")
		ui._on_toggle_multi()
		await _layout(ui, view, "select mode")
		ui._on_toggle_multi()
		# Character page: gear tab, presets, a worn piece selected with Unequip, Detailed Stats, deco.
		inv.equip_at(inv.find_first(&"stone_knife"))
		ui._show_page("character", "bag")
		ui._on_equip_slot_pressed("weapon")
		_expect(ui._unequip_btn.visible and ui._gear_sel_label.text.begins_with("Stone Knife"), "%s: a worn knife selected shows Unequip (%s)" % [view, ui._gear_sel_label.text])
		await _layout(ui, view, "character")
		_expect(not ui._preset_btns[0].disabled, "%s: preset 1 is open at level 1" % view)
		ui._toggle_stats()
		_expect(ui._stats_scroll.visible and ui._stats_btn.text == "Back", "%s: Detailed Stats opens" % view)
		await _layout(ui, view, "detailed stats")
		ui._toggle_stats()
		ui._deco = true
		ui._refresh_character()
		await _layout(ui, view, "decorative")
		ui._unequip_btn.pressed.emit()
		_expect(inv.worn(&"weapon") == null and inv.find_first(&"stone_knife") >= 0, "%s: Unequip puts the knife back in the bag" % view)
		ui.hide_ui()
		ui.queue_free()
		await process_frame
	get_root().content_scale_size = Vector2i(1600, 900)

## Two frames for the containers to sort, then: every visible button and grid cell is a 64 px tap
## target, and every visible control sits inside its panel (sheet or card) and the view.
func _layout(ui: Control, view: Vector2i, what: String) -> void:
	await process_frame
	await process_frame
	var vr := Rect2(Vector2.ZERO, Vector2(view)).grow(0.5)
	var sheet: Rect2 = (ui._panel as Control).get_global_rect().grow(0.5)
	var card: Rect2 = (ui._card as Control).get_global_rect().grow(0.5)
	_expect(vr.encloses(sheet), "%s %s: the sheet %s is inside the view" % [view, what, sheet])
	if ui._card.visible:
		_expect(vr.encloses(card), "%s %s: the card %s is inside the view" % [view, what, card])
		_expect(not card.intersects(sheet.grow(-1.0)) or ui._card.position.x >= sheet.position.x, "%s %s: the card floats beside the bag" % [view, what])
	var small: PackedStringArray = []
	var out: PackedStringArray = []
	for c: Node in ui.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or _in_scroll(ctl, ui):
			continue
		var r := ctl.get_global_rect()
		var host: Rect2 = card if ui._card.is_ancestor_of(ctl) else sheet
		if (ui._panel as Control).is_ancestor_of(ctl) or ui._card.is_ancestor_of(ctl):
			if not host.encloses(r):
				out.append("%s %s" % [ctl.name, r])
		if ctl is Button and (r.size.y < 64.0 or r.size.x < 64.0):
			small.append("%s %s" % [ctl.name, r.size])
	_expect(out.is_empty(), "%s %s: nothing overflows its panel (%s)" % [view, what, ", ".join(out)])
	_expect(small.is_empty(), "%s %s: every button is >= 64 px (%s)" % [view, what, ", ".join(small)])
	var g: Control = ui._grid if ui._grid.visible else ui._pet_grid
	if g.visible and g.get_child_count() > 0:
		var c0 = g.cell_for(0) if g.cell_for(0) != null else null
		_expect(c0 == null or (c0.size.x >= 64.0 and c0.size.y >= 64.0), "%s %s: grid cells are >= 64 px (%s)" % [view, what, c0.size if c0 else Vector2.ZERO])

## Grid cells and card facts scroll: they are clipped by their ScrollContainer, not the panel.
func _in_scroll(c: Node, stop: Node) -> bool:
	var p := c.get_parent()
	while p != null and p != stop:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

# ---------------------------------------------------------------- hold / drag select

func _mouse(cell: Control, at_global: Vector2, pressed: Variant) -> void:
	var ev: InputEvent
	if pressed == null:
		var mm := InputEventMouseMotion.new()
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		ev = mm
	else:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = bool(pressed)
		ev = mb
	(ev as InputEventMouse).position = at_global - cell.get_global_rect().position
	cell.gui_input.emit(ev)

## Owner 2026-10-27: a long press enters Select mode, a drag paints cells in, dragging back
## un-paints them, and the batch actions then act on the painted set (locked items skipped).
func _test_paint() -> void:
	get_root().size = Vector2i(844, 390)
	get_root().content_scale_size = Vector2i(844, 390)
	var host := Node3D.new()
	get_root().add_child(host)
	var world: Node = get_root().get_node("World")
	var old_rt: Variant = world.get("runtime")
	world.set("runtime", host)
	var inv = INV.new(30)
	for k in 12:
		inv.add(IS.make(&"stone", 1, {}, 2 + k))
	var ui = load("res://scenes/ui/inventory.tscn").instantiate()
	get_root().add_child(ui)
	ui.bind(inv, null)
	ui.visible = true
	ui.rebuild()
	await process_frame
	await process_frame
	var g = ui._grid
	g.long_press_s = 0.05
	var c0: Control = g.cell_for(0)
	var mid := func (i: int) -> Vector2: return (g.cell_for(i) as Control).get_global_rect().get_center()
	_mouse(c0, mid.call(0), true)
	await create_timer(0.15).timeout
	await process_frame
	_expect(g.multi_mode and g.multi == [0] and ui._select_btn.text == "Done", "a long press enters Select mode with that cell (%s)" % [g.multi])
	for i in range(1, 10):
		_mouse(c0, mid.call(i), null)
	_expect(g.multi.size() == 10, "dragging over 10 cells selects 10 (%d)" % g.multi.size())
	_expect(ui._batch_label.visible and ui._batch_label.text == "10 selected", "the toolbar counts them (%s)" % ui._batch_label.text)
	_mouse(c0, mid.call(5), null)
	_expect(g.multi_list() == [0, 1, 2, 3, 4, 5], "dragging back un-paints (%s)" % [g.multi_list()])
	_mouse(c0, mid.call(0), null)
	_expect(g.multi_list() == [0], "back to the start leaves only it (%s)" % [g.multi_list()])
	for i in range(1, 10):
		_mouse(c0, mid.call(i), null)
	_mouse(c0, mid.call(9), false)
	_expect(g.multi.size() == 10 and not g._painting, "release keeps the 10 (%d)" % g.multi.size())
	# A plain tap in Select mode toggles one cell.
	var c11: Control = g.cell_for(11)
	_mouse(c11, mid.call(11), true)
	_mouse(c11, mid.call(11), false)
	_expect(g.multi.has(11) and g.multi.size() == 11, "a tap adds one")
	_mouse(c11, mid.call(11), true)
	_mouse(c11, mid.call(11), false)
	_expect(not g.multi.has(11) and g.multi.size() == 10, "a second tap removes it")
	# Batch drop: the 10 go to loot bags, two locked ones stay; nothing is lost.
	inv.slots[2].set_flag(&"locked", true)
	inv.slots[7].set_flag(&"locked", true)
	var before: Dictionary = inv.uids()
	ui._on_batch_drop()
	var dropped := {}
	for b in host.get_children():
		if b.get("storage") != null:
			dropped.merge(b.storage.uids())
	_expect(dropped.size() == 8 and inv.used_slots() == 4 and inv.slots[2] != null and inv.slots[7] != null, "batch drop drops 8, skips the 2 locked (%d dropped)" % dropped.size())
	_expect(inv.uids().merged(dropped) == before, "batch drop conserves every instance")
	# Batch Store and Transfer to Bag on a box.
	var box = INV.new(10)
	ui.show_storage(box, null, {"title": "Small Box", "allow_deposit": true})
	ui._show_page("bag", "bag")
	ui._set_multi_mode(true)
	for i in inv.slot_count:
		if inv.slots[i] != null:
			g.toggle_multi(i)
	ui._update_batch_bar()
	ui._update_toolbar()
	_expect(ui._batch_store_btn.visible, "an open box adds Store to the batch bar")
	var all_before: Dictionary = inv.uids().merged(box.uids())
	ui._on_batch_store()
	_expect(box.used_slots() == 2 and inv.used_slots() == 2, "batch Store moves the unlocked ones (box %d)" % box.used_slots())
	ui._set_multi_mode(false)
	ui._show_page("bag", "store")
	ui._set_multi_mode(true)
	ui._pet_grid.toggle_multi(0)
	ui._pet_grid.toggle_multi(1)
	ui._update_batch_bar()
	ui._update_toolbar()
	_expect(ui._batch_take_btn.visible and not ui._batch_take_btn.disabled, "the box tab's batch bar offers Transfer to Bag")
	ui._on_batch_take()
	_expect(box.used_slots() == 0 and inv.uids().merged(box.uids()) == all_before, "batch Transfer to Bag brings them back, nothing lost")
	await _layout(ui, Vector2i(844, 390), "box select mode")
	ui.hide_ui()
	ui.queue_free()
	world.set("runtime", old_rt)
	host.queue_free()
	await process_frame
	get_root().content_scale_size = Vector2i(1600, 900)
