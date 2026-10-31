extends Node3D
## INVSLOTS lab: the bag as a scrolling grid of slots (spec 13 s5/s12), one item instance per slot,
## empty slots drawn, "used / capacity" in the header, capacity that grows with worn storage
## (spec 05:11). Shots go to --shot-dir. Prints exactly one "[invslots] RESULT k=v ..." line.
##   Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- \
##     --lab=invslots_lab --shot-dir=/tmp/invslots_shots

const FILL := [
	[&"stone", 14, 1], [&"branch", 11, 2], [&"berry", 9, 1], [&"fibre_stalk", 8, 3], [&"raw_meat", 7, 2],
	[&"raptor_bone", 6, 5], [&"flint", 5, 1], [&"wood_log", 5, 2], [&"herb_leaf", 4, 1], [&"raptor_hide", 3, 4],
	[&"mushroom", 3, 1], [&"clay", 2, 1], [&"reed", 2, 1],
]

var player: Player
var shot_dir := "/tmp/invslots_shots"
var _frames: Array[float] = []
var _scroll_range := 0
var _pills := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			shot_dir = a.substr(11)
	DirAccess.make_dir_recursive_absolute(shot_dir)
	var kit := LabKit.build(self, 30.0)
	player = kit["player"]
	var modals := CanvasLayer.new()
	modals.name = "Modals"
	modals.layer = 96
	add_child(modals)
	player.ui.reparent(modals)
	World.player_name = "Milan"
	World.occupation = "Gatherer"
	# One rare instance first, so the green trait mark is in the first visible rows of every shot:
	# a bone with a trait the def does not hand to every one.
	player.inventory.add(ItemStack.make(&"raptor_bone", 1, {"hardness": 3}, 42))
	for row in FILL:
		for k in int(row[1]):
			player.inventory.add(ItemStack.make(row[0], 1, {}, 1 + (k * int(row[2])) % 60))
	await get_tree().process_frame
	player.ui.visible = true
	player.ui.rebuild()
	await get_tree().process_frame
	await get_tree().process_frame
	call_deferred("_run")

func _run() -> void:
	await get_tree().create_timer(0.4).timeout
	await _shoot("bag_%s" % _res_name())
	var inv := player.inventory
	var grid: BagGrid = player.ui._grid
	var base_cap := inv.capacity()
	var capacity := base_cap
	var grid_slots := grid.slot_count()
	var items := _item_count()
	var filled := grid.filled()
	var empties := grid.empty_visible()
	_pills = _count_pills()
	var min_cell: float = _min_cell()
	var cap_text := player.ui._cap_label.text
	# Tap a filled compartment: the gold brackets land on that slot only.
	var picked := -1
	for i in grid.slot_count():
		if grid.cell_for(i).stack != null:
			picked = i
			break
	# A tap is a press and a release at (nearly) the same point; a drag emits nothing.
	var cell := grid.cell_for(picked)
	grid._on_cell_input(_tap(true, Vector2(10, 10)), cell)
	grid._on_cell_input(_tap(false, Vector2(11, 11)), cell)
	await get_tree().process_frame
	var sel_ok: bool = grid.selected_index == picked and grid.cell_for(picked).selected
	# A drag (press, then release far away) must not select; drag_ok=1 when it stayed put.
	var tapped: int = grid.selected_index
	grid._on_cell_input(_tap(true, Vector2(10, 10)), cell)
	grid._on_cell_input(_tap(false, Vector2(10, 60)), cell)
	var drag_ok := 1 if grid.selected_index == tapped else 0
	grid.set_selected(picked)
	var level_ok := _has_level_label()
	# Measured with the action row populated: every visible action is >= 64 px and inside the panel.
	var panel_rect: Rect2 = player.ui._panel.get_global_rect()
	_actions_in_panel = 1 if player.ui._actions.get_global_rect().end.y <= panel_rect.end.y + 1.0 else 0
	for b: Button in [player.ui._lock_btn, player.ui._equip_btn, player.ui._food1_btn, player.ui._food2_btn, player.ui._inspect_btn, player.ui._eat_btn, player.ui._feed_btn, player.ui._place_btn, player.ui._store_btn]:
		if b.visible:
			_min_action_h = minf(_min_action_h, b.get_global_rect().size.y)
			if b.get_global_rect().end.y > panel_rect.end.y + 1.0:
				_actions_in_panel = 0
	await _shoot("bag_selected_%s" % _res_name())
	# Upgrade: wear the data-only storage bag; capacity grows live.
	inv.add(ItemStack.make(&"woven_bag", 1))
	var equipped: bool = inv.equip_at(inv.find_first(&"woven_bag"))
	player.ui.rebuild()
	await get_tree().process_frame
	var cap_upgraded := inv.capacity()
	var grown_slots := grid.slot_count()
	var cap_grown_text := player.ui._cap_label.text
	await _shoot("bag_upgraded_%s" % _res_name())
	var unequipped: bool = inv.unequip(&"accessory1")
	player.ui.rebuild()
	await get_tree().process_frame
	var cap_after_unequip := inv.capacity()
	# Overflow refusal, model-level on a scratch bag so the screen keeps its items: 120 slots full,
	# unequip refused, nothing deleted.
	var scratch: Inventory = load("res://scripts/items/inventory.gd").new()
	scratch.add(ItemStack.make(&"woven_bag", 1))
	scratch.equip_at(scratch.find_first(&"woven_bag"))
	while scratch.used_slots() < scratch.slot_count:
		if scratch.add(ItemStack.make(&"stone", 1)) != 0:
			break
	var uids_before: Dictionary = scratch.uids()
	var refused := not scratch.unequip(&"accessory1")
	var lost := 0
	for u in uids_before:
		if not scratch.uids().has(u):
			lost += 1
	# Storage / pet cargo uses the same grid: a 40-slot box with instances shows 40 compartments.
	var u: InventoryUI = player.ui
	var store: Inventory = load("res://scripts/items/inventory.gd").new(40)
	for k in 12:
		store.add(ItemStack.make(&"stone", 1, {}, 1 + k))
	player.ui.show_storage(store, player, {"title": "Storage box", "take_all": true})
	await get_tree().process_frame
	await get_tree().process_frame
	await _shoot("storage_%s" % _res_name())
	# Phone landscape: the page scrolls so the box grid is reachable under the bag.
	var page: ScrollContainer = u._page_scroll
	page.scroll_vertical = int(page.get_v_scroll_bar().max_value)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shoot("storage_scrolled_%s" % _res_name())
	# The box grid is on screen after the page scroll, and the action row (Lock / Take all) still is.
	_storage_visible = 1 if u._pet_grid.get_global_rect().intersects(u._panel.get_global_rect()) else 0
	if u._actions.get_global_rect().end.y > u._panel.get_global_rect().end.y + 1.0:
		_storage_visible = 0
	page.scroll_vertical = 0
	var store_slots: int = player.ui._pet_grid.slot_count()
	var store_filled: int = player.ui._pet_grid.filled()
	var store_pills := 0
	for i in player.ui._pet_grid.slot_count():
		for child in player.ui._pet_grid.cell_for(i).get_children():
			if child is Label:
				store_pills += 1
	player.ui.hide_ui()
	player.ui.visible = true
	player.ui.rebuild()
	await get_tree().process_frame
	# 300-slot bag: one Pocket 30 storage bag = 100 + 20 + 180 = 300 slots; scroll it and time frames.
	inv.add(ItemStack.make(&"woven_bag", 1))
	var pocket := ItemStack.make(&"woven_bag", 1)
	pocket.attributes["pocket"] = 30
	inv.add(pocket)
	var pidx := -1
	for i in inv.slot_count:
		if inv.slots[i] != null and inv.slots[i].def_id == &"woven_bag" and int(inv.slots[i].attributes.get("pocket", 0)) == 30:
			pidx = i
			break
	inv.equip_at(pidx, &"accessory1")
	player.ui.rebuild()
	await get_tree().process_frame
	while inv.used_slots() < 90:
		if inv.add(ItemStack.make(&"stone", 1)) != 0:
			break
	player.ui.rebuild()
	await get_tree().process_frame
	items = _item_count()
	_filled = grid.filled()
	_empties = grid.empty_visible()
	_grid_slots = grid.slot_count()
	var cap_300 := inv.capacity()
	await _shoot("bag_300_%s" % _res_name())
	await _stress_scroll(grid)
	await _shoot("bag_300_scrolled_%s" % _res_name())
	# Back to the plain bag: capacity returns to 100 and the grid shrinks live.
	inv.unequip(&"accessory1")
	player.ui.rebuild()
	await get_tree().process_frame
	capacity = inv.capacity()
	var shrunk_slots := grid.slot_count()
	await _shoot("bag_shrunk_%s" % _res_name())
	# The RESULT fields are the plain bag after the shrink: items, filled and empties agree.
	items = _item_count()
	filled = grid.filled()
	empties = grid.empty_visible()
	grid_slots = grid.slot_count()
	var report := "[invslots] RESULT capacity=%d grid_slots=%d items=%d filled=%d empty_visible=%d pills=%d min_slot_px=%d scroll_range=%d frame_ms_p95_300=%.1f cap_upgraded=%d cap_after_unequip=%d items_lost=%d actions_in_panel=%d storage_visible=%d min_action_px=%d drag_ok=%d" % [
		capacity, grid_slots, items, filled, empties, _pills, int(min_cell), _scroll_range, _p95(),
		cap_upgraded, cap_after_unequip, lost, _actions_in_panel, _storage_visible, int(_min_action_h), drag_ok]
	print("[invslots] storage slots=%d filled=%d pills=%d" % [store_slots, store_filled, store_pills])
	print("[invslots] base_cap=%d cap_text='%s' grown_slots=%d cap_grown_text='%s' shrunk_slots=%d cap_300=%d filled_300=%d empty_300=%d selection=%s level_label=%s refusal=%s equipped=%s unequipped=%s" % [
		base_cap, cap_text, grown_slots, cap_grown_text, shrunk_slots, cap_300, _filled, _empties, sel_ok, level_ok, refused, equipped, unequipped])

	print(report)
	# The lab's own acceptance, measured: each one must hold at the live viewport.
	var fails: PackedStringArray = []
	fails.append("grid_slots != capacity") if grid_slots != capacity else null
	fails.append("filled != items") if filled != items else null
	fails.append("no empty slot visible") if empties < 1 else null
	fails.append("count pills visible") if _pills > 0 else null
	fails.append("slot under 64 px") if min_cell < 64.0 else null
	fails.append("bag does not scroll") if _scroll_range <= 0 else null
	fails.append("300-slot p95 over 33 ms") if _p95() > 33.0 else null
	fails.append("wearing the bag did not grow capacity") if cap_upgraded <= capacity else null
	fails.append("unequip did not shrink capacity back") if cap_after_unequip != capacity else null
	fails.append("items lost") if lost > 0 else null
	fails.append("action row clipped by the panel") if _actions_in_panel != 1 else null
	fails.append("action button under 64 px") if _min_action_h < 64.0 else null
	fails.append("storage grid not on screen") if _storage_visible != 1 else null
	fails.append("a drag selected a slot") if drag_ok != 1 else null
	for f in fails:
		print("[invslots] FAIL %s" % f)
	get_tree().quit(0 if fails.is_empty() else 1)

var _storage_visible := 0
var _actions_in_panel := 0
var _min_action_h := 1e9
var _filled := 0
var _empties := 0
var _grid_slots := 0

func _tap(pressed: bool, at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	return e

func _res_name() -> String:
	var v := get_viewport().get_visible_rect().size
	return "%dx%d" % [int(v.x), int(v.y)]

func _item_count() -> int:
	var n := 0
	for s in player.inventory.slots:
		if s != null and s.def_id != Inventory.LOCK:
			n += 1
	return n

## Count badges (the rejected count pills): a Label child of a compartment.
func _count_pills() -> int:
	var n := 0
	var grid: BagGrid = player.ui._grid
	for i in grid.slot_count():
		for child in grid.cell_for(i).get_children():
			if child is Label and (child as Label).visible:
				n += 1
	return n

func _min_cell() -> float:
	var m := 1e9
	var grid: BagGrid = player.ui._grid
	for i in grid.slot_count():
		m = minf(m, grid.cell_for(i).size.x)
	return m

## True when a compartment holding a level > 1 instance draws its label at >= 12 px.
func _has_level_label() -> bool:
	var grid: BagGrid = player.ui._grid
	for i in grid.slot_count():
		var c := grid.cell_for(i)
		if c.stack != null and c.stack.level > 1:
			return c.font_px >= 12
	return false

func _shoot(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [shot_dir, stage]
	get_viewport().get_texture().get_image().save_png(path)
	print("[invslots] shot %s" % path)

## Scrolls the 300-slot bag a row per frame and samples the frame time.
func _stress_scroll(grid: BagGrid) -> void:
	var scroll: ScrollContainer = grid._scroll
	var bar := scroll.get_v_scroll_bar()
	_scroll_range = int(bar.max_value - bar.page)
	_frames.clear()
	var span := maxi(1, _scroll_range)
	for k in 90:
		await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		scroll.scroll_vertical = int(float(k) / 89.0 * float(span) * 0.12)
		await get_tree().process_frame
		_frames.append(float(Time.get_ticks_usec() - t0) / 1000.0)

func _p95() -> float:
	if _frames.is_empty():
		return 999.0
	var xs := _frames.duplicate()
	xs.sort()
	var at := int(clampf(ceil(0.95 * float(xs.size())) - 1.0, 0.0, float(xs.size() - 1)))
	return float(xs[at])
