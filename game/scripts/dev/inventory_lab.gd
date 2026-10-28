extends Node3D
## W2-INV bag lab: a full 100-slot bag of mixed single instances (plus one ammo and one bandage
## stack) in the real inventory screen. The grid groups identical items visually (one cell per
## item id with a corner count badge); opening a group shows each instance; nothing ever merges.
## Shots: --resolution 1600x900 (or 844x390) -- --lab=inventory_lab --shot=<png with "bag" in it>
##   [--bag-group=stone] opens that group first; [--bag-fill=N] keeps only the first N instances
##   (a partly filled bag shows its free slots as empty cells).
## Headless (no --shot): drives the grid and prints "[invlab] PASS ..." (exit 0) or FAIL lines (exit 1).

## 100 slots: [id, instances, level step]. Levels cycle so an opened group shows different ones.
const FILL := [
	[&"stone", 16, 1], [&"branch", 12, 2], [&"berry", 10, 1], [&"fibre_stalk", 9, 3], [&"raw_meat", 8, 2],
	[&"raptor_bone", 6, 5], [&"flint", 6, 1], [&"wood_log", 5, 2], [&"herb_leaf", 5, 1], [&"raptor_hide", 4, 4],
	[&"mushroom", 4, 1], [&"clay", 3, 1], [&"reed", 3, 1], [&"raid_helm", 2, 29], [&"work_pick", 2, 10],
	[&"stone_knife_work", 1, 1], [&"work_axe", 1, 1], [&"resin", 1, 1],
]

var player: Player
var _fails: PackedStringArray = []

func _ready() -> void:
	var kit := LabKit.build(self, 30.0)
	player = kit["player"]
	# Same layering as main.gd: the bag is a modal above the HUD's canvas layers.
	var modals := CanvasLayer.new()
	modals.name = "Modals"
	modals.layer = 96
	add_child(modals)
	player.ui.reparent(modals)
	World.player_name = "Milan"
	World.occupation = "Gatherer"
	var fill := 1000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bag-fill="):
			fill = int(a.substr(11))
	for row in FILL:
		for k in int(row[1]):
			if player.inventory.used_slots() < fill:
				player.inventory.add(ItemStack.make(row[0], 1, {}, 1 + (k * int(row[2])) % 60))
	if fill >= 100:
		player.inventory.add(ItemStack.make(&"stone_shot", 45))
		player.inventory.add(ItemStack.make(&"bandage", 6))
	await get_tree().process_frame
	var ui := player.ui
	ui.visible = true
	ui.rebuild()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bag-group="):
			_open(StringName(a.substr(12)))
	print("[invlab] bag %d/%d groups=%d cells=%d" % [player.inventory.used_slots(), player.inventory.slot_count, player.inventory.groups().size(), _visible_cells().size()])
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		await _check()

## Visible grid cells; item cells only unless `with_empty` (free bag slots show as empty cells).
func _visible_cells(with_empty: bool = false) -> Array[Button]:
	var out: Array[Button] = []
	var grid: Node = player.ui._grid
	for k in grid.get_child_count():
		var b := grid.get_child(k) as Button
		if b.visible and (with_empty or k >= player.ui._cells.size() or not player.ui._cells[k].has("empty")):
			out.append(b)
	return out

## Spec 13:124 "Empty slots remain visible": an empty bag shows every slot as an empty cell, and a
## bag of 3 items shows 3 item cells and 97 empty ones. Empty cells take no taps.
func _check_empty_cells() -> void:
	var ui := player.ui
	var bag := ui.inventory
	var probe := Inventory.new()
	ui._selected = -1
	ui.inventory = probe
	ui.rebuild()
	for want in [0, 3]:
		for id in [&"stone", &"branch", &"berry"].slice(0, want):
			probe.add(ItemStack.make(id, 1))
		ui.rebuild()
		var shown := _visible_cells(true)
		var blank := shown.filter(func (b: Button) -> bool: return b.icon == null and b.text == "" and b.disabled)
		_expect(shown.size() == 100 and blank.size() == 100 - want, "%d items: %d item cells and %d empty slot cells (%d shown, %d empty)" % [want, want, 100 - want, shown.size(), blank.size()])
	ui.inventory = bag
	ui.rebuild()

## Taps the cell of group `id`, as a player would.
func _open(id: StringName) -> bool:
	var cells: Array = player.ui._cells
	for k in cells.size():
		if cells[k].get("group", &"") == id:
			player.ui._on_cell(k)
			return true
	return false

## The visible group badge text of a cell, "" when it has none.
func _badge_of(b: Button) -> String:
	var badge := b.get_node_or_null("Badge") as Label if b else null
	return badge.text if badge and badge.visible else ""

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[invlab] FAIL %s" % what)

func _check() -> void:
	var inv := player.inventory
	var ui := player.ui
	var units := {}
	for s in inv.slots:
		if s:
			units[s.def_id] = int(units.get(s.def_id, 0)) + s.count
	_expect(inv.used_slots() == 100 and inv.slot_count == 100, "the bag holds 100 instances in 100 slots (%d/%d)" % [inv.used_slots(), inv.slot_count])
	var groups := inv.groups()
	var cells := _visible_cells()
	_expect(groups.size() == FILL.size() + 2 and cells.size() == groups.size(), "one cell per item id: %d groups, %d cells" % [groups.size(), cells.size()])
	var small := 0
	for b in cells:
		small += 1 if b.get_combined_minimum_size().x < UiTokens.TARGET_MIN or b.get_combined_minimum_size().y < UiTokens.TARGET_MIN else 0
	_expect(small == 0, "every bag cell is a %d px+ target (%d smaller)" % [UiTokens.TARGET_MIN, small])
	var stone_cell: Button = cells[0] if not cells.is_empty() else null
	# A group has a corner count badge (it opens) and its level range; a real stack reads "×45" with
	# no badge: the two never look alike.
	_expect(_badge_of(stone_cell) == "16" and stone_cell.text == "Lv 1-16" and not stone_cell.text.contains("×"), "the stone group has a 16 badge, its level range and no stack ×N (badge '%s', caption '%s')" % [_badge_of(stone_cell), stone_cell.text if stone_cell else ""])
	# Review 5: the pill sits in the corner and covers at most a third (12 px) of the 36 px icon box
	# centred in the cell (a wide pill hid the berry bowl and the meat on a 64 px phone cell).
	await get_tree().process_frame
	var pill := stone_cell.get_node_or_null("Badge") as Label if stone_cell else null
	var cover := (stone_cell.size.x + 36.0) * 0.5 - pill.position.x if pill else 99.0
	_expect(cover <= 12.0, "the stone badge covers at most 12 px of the icon box (%.0f px; cell %.0f px)" % [cover, stone_cell.size.x if stone_cell else 0.0])
	var shot_cell: Button = null
	for k in ui._cells.size():
		if ui._cells[k].has("slot") and inv.slots[int(ui._cells[k].slot)].def_id == &"stone_shot":
			shot_cell = cells[k]
	_expect(shot_cell != null and shot_cell.text.ends_with("×45") and _badge_of(shot_cell) == "", "the stone_shot stack shows ×45 and no group badge (caption '%s', badge '%s')" % [shot_cell.text if shot_cell else "", _badge_of(shot_cell)])
	inv.slots[inv.find_first(&"stone")].set_flag(&"locked", true)
	ui.rebuild()
	_expect(_visible_cells()[0].text.begins_with("L "), "a group holding a locked stone carries the L pip (got '%s')" % _visible_cells()[0].text)
	inv.slots[inv.find_first(&"stone")].set_flag(&"locked", false)
	ui.rebuild()
	_expect(_open(&"stone"), "the stone group opens")
	await get_tree().process_frame
	cells = _visible_cells()
	_expect(cells.size() == 17 and ui._cells[0].has("back"), "opened: a back cell and 16 stone instances (%d cells)" % cells.size())
	_expect(ui._selected >= 0 and inv.slots[ui._selected].def_id == &"stone" and ui._tip.text != "Tap an item.", "opening selects the first stone and shows it")
	ui._on_cell(5)
	var picked: int = ui._selected
	_expect(picked == int(ui._cells[5].slot) and inv.slots[picked].def_id == &"stone", "tapping an instance selects that slot")
	ui._on_cell(0)
	_expect(_visible_cells().size() == groups.size(), "back shows the whole bag again")
	# Equip the exact helm picked from its group: the L30 one, not the first.
	_open(&"raid_helm")
	var l30 := -1
	for k in ui._cells.size():
		var c: Dictionary = ui._cells[k]
		if c.has("slot") and inv.slots[int(c.slot)].level == 30:
			l30 = k
	ui._on_cell(l30)
	var uid: String = inv.slots[ui._selected].uid if ui._selected >= 0 and inv.slots[ui._selected] else ""
	ui._on_equip_pressed()
	var worn := inv.equipped_in(&"head")
	_expect(worn != null and worn.level == 30 and worn.uid == uid and uid != "", "Equip wears the L30 helm chosen in its group")
	_expect(inv.used_slots() == 99 and _visible_cells().size() == groups.size(), "the worn helm left the bag; one helm is left as a single cell (%d cells)" % _visible_cells().size())
	var after := {}
	for s in inv.slots:
		if s:
			after[s.def_id] = int(after.get(s.def_id, 0)) + s.count
	after[&"raid_helm"] = int(after.get(&"raid_helm", 0)) + 1
	_expect(after == units, "grouping merged nothing: every unit is where it was")
	# Tapping the worn helm with a full bag keeps it worn and says why (it was refused silently).
	inv.add(ItemStack.make(&"branch", 1))
	ui._character.bind(inv, ui._owner_player)
	ui._character._on_equip_slot_pressed("head")  # C1: the Character sheet selects, Unequip takes it off
	ui._character._on_unequip_pressed()
	var hud := get_tree().get_first_node_in_group("hud")
	var notices := str(hud.get("_events").notices) if hud and hud.get("_events") else ""
	_expect(inv.equipped_in(&"head") != null and inv.used_slots() == 100 and notices.contains("Bag is full"), "unequip into a full bag: the helm stays worn and 'Bag is full' shows")
	ui._select(inv.find_first(&"stone"))
	_expect(ui._tip.text.begins_with("Stone") and not ui._tip.text.contains("attr") and not ui._tip.text.contains("tint"), "the tip shows no raw attribute dict (%s)" % ui._tip.text.replace("\n", " | "))
	_check_empty_cells()
	if _fails.is_empty():
		print("[invlab] PASS empty_cells=100/97 slots=100 groups=%d stone_open=17 equip_l30=true full_unequip_notice=true" % groups.size())
	get_tree().quit(0 if _fails.is_empty() else 1)
