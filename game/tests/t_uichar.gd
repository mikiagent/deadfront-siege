extends SceneTree
## UICHAR acceptance (docs/design/ui-redesign-spec.md §7 C1/C3/C4, §8): Character, Skills and Orders
## open from the HUD's public entry points (open_character / open_skills / open_orders); at 844x390
## and 1600x900 every visible control of each sheet stays on screen, the header and its panels do not
## overlap, and every visible button is a 64 px target; the primary actions work (Unequip puts the
## worn knife back, Open bag returns to the bag, the GOLD Spend button buys a node, Track on HUD points
## the HUD quest card at the order) and ‹ returns to the MENU.
## Usage: godot --headless --path game --script res://tests/t_uichar.gd -> "[t_uichar] PASS", exit 0/1.

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_uichar] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	_host = Node3D.new()
	_host.name = "TUicharHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("open_orders"):
			_hud = c
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)
	for view in [Vector2i(844, 390), Vector2i(1600, 900)]:
		root.size = view
		root.content_scale_size = view
		await _frames(3)
		await _test_character(view)
		await _test_skills(view)
		await _test_orders(view)
	if _fails.is_empty():
		print("[t_uichar] PASS")
		quit(0)
	else:
		print("[t_uichar] FAIL count=%d" % _fails.size())
		quit(1)

## Inside a ScrollContainer a control is clipped by it, not by the view.
func _in_scroll(c: Node, stop: Node) -> bool:
	var p := c.get_parent()
	while p != null and p != stop:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

## Every visible control on screen; every visible button >= 64 px; `panels` (named children) and the
## header do not overlap each other.
func _layout(sheet: Control, view: Vector2i, what: String, panels: Array[String]) -> void:
	await _frames(2)
	var vr := Rect2(Vector2.ZERO, Vector2(view)).grow(0.5)
	var out: PackedStringArray = []
	var small: PackedStringArray = []
	var n := 0
	for c: Node in sheet.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or _in_scroll(ctl, sheet) or ctl.name == "Dim":
			continue
		n += 1
		var r := ctl.get_global_rect()
		if not vr.encloses(r):
			out.append("%s %s" % [ctl.name, r])
		if ctl is Button and (r.size.y < 63.5 or r.size.x < 63.5):
			small.append("%s %s" % [ctl.name, r.size])
	_expect(out.is_empty(), "%s %s: %d controls, all on screen (%s)" % [view, what, n, ", ".join(out)])
	_expect(small.is_empty(), "%s %s: every button >= 64 px (%s)" % [view, what, ", ".join(small)])
	var rects: Array[Rect2] = []
	var names: Array[String] = ["Header"]
	names.append_array(panels)
	for nm in names:
		var p := sheet.find_child(nm, true, false) as Control
		_expect(p != null and p.is_visible_in_tree(), "%s %s: %s shows" % [view, what, nm])
		rects.append(p.get_global_rect() if p else Rect2())
	var hits: PackedStringArray = []
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].grow(-0.5).intersects(rects[j].grow(-0.5)):
				hits.append("%s/%s" % [names[i], names[j]])
	_expect(hits.is_empty(), "%s %s: header and panels do not overlap (%s)" % [view, what, ", ".join(hits)])

# ---------------------------------------------------------------- C1 Character

func _test_character(view: Vector2i) -> void:
	var inv = _player.inventory
	if inv.find_first(&"stone_knife") < 0 and inv.worn(&"weapon") == null:
		inv.add(load("res://scripts/items/item_stack.gd").make(&"stone_knife", 1, {}, 5))
	if inv.worn(&"weapon") == null:
		inv.equip_at(inv.find_first(&"stone_knife"))
	_hud.open_character()
	await _frames(2)
	var ui = _player.ui
	var sheet: Control = ui._character
	_expect(ui.visible and sheet.visible and not ui._panel.visible, "%s: Character opens over the whole view, the bag hidden" % view)
	_expect(sheet.find_child("Equip_head", true, false) != null and sheet.find_child("Equip_food2", true, false) != null, "%s: the ten slots exist (Head .. Food 2)" % view)
	var names: PackedStringArray = []
	for r: Array in sheet.stat_rows():
		names.append(str(r[0]))
	_expect(names.has("Life") and names.has("Energy") and names.has("Attack") and names.has("Carry") and names.has("Skill points"), "%s: stats list Life, Energy, Attack, Carry, Skill points (%s)" % [view, ", ".join(names)])
	var needs: PackedStringArray = []
	for r: Dictionary in sheet.need_rows():
		needs.append(str(r["name"]))
	_expect(needs.has("Exhaustion") and needs.has("Thirst") and needs.has("Hygiene"), "%s: survival panel lists %s" % [view, ", ".join(needs)])
	sheet._on_equip_slot_pressed("weapon")
	await _frames(1)
	_expect(sheet._unequip_btn.is_visible_in_tree() and sheet._sel_label.text.contains("Stone Knife"), "%s: the worn knife selected shows Unequip (%s)" % [view, sheet._sel_label.text])
	await _layout(sheet, view, "character", ["CharacterStatsPanel", "CharacterEquipPanel", "CharacterSurvivalPanel"])
	# Slots never overlap each other or the figure.
	var slot_rects: Array[Rect2] = []
	for s in ["head", "body", "arms", "legs", "weapon", "tool", "accessory1", "accessory2", "food1", "food2"]:
		slot_rects.append((sheet._slots[s] as Control).get_global_rect())
	var clash := 0
	for i in slot_rects.size():
		for j in range(i + 1, slot_rects.size()):
			clash += 1 if slot_rects[i].grow(-0.5).intersects(slot_rects[j].grow(-0.5)) else 0
	_expect(clash == 0, "%s: the ten slots do not overlap (%d)" % [view, clash])
	(sheet._tab_btns["Titles"] as Button).pressed.emit()
	await _layout(sheet, view, "character titles", ["CharacterStatsPanel", "CharacterEquipPanel", "CharacterSurvivalPanel"])
	_expect(sheet._titles_view.visible and sheet._titles_view.get_child_count() >= 3, "%s: Titles lists the titles (%d)" % [view, sheet._titles_view.get_child_count()])
	(sheet._tab_btns["Equipment"] as Button).pressed.emit()
	sheet._unequip_btn.pressed.emit()
	_expect(inv.worn(&"weapon") == null and inv.find_first(&"stone_knife") >= 0, "%s: Unequip puts the knife back in the bag" % view)
	(sheet._bag_btn as Button).pressed.emit()
	await _frames(1)
	_expect(ui.visible and ui._panel.visible and not sheet.visible, "%s: Open bag returns to the bag" % view)
	ui._char_tab.pressed.emit()
	await _frames(1)
	_expect(sheet.visible and not ui._panel.visible, "%s: the bag's Character tab opens the sheet" % view)
	(sheet._c["back"] as Button).pressed.emit()
	await _frames(1)
	_expect(not ui.visible and _hud._sheet_kind == &"menu", "%s: ‹ closes Character and opens the MENU" % view)
	_hud._close_sheet()
	ui.visible = true
	await _frames(1)
	_expect(ui._panel.visible and not sheet.visible, "%s: the next bag open shows the bag, not Character" % view)
	ui.hide_ui()

# ---------------------------------------------------------------- C3 Skills

func _test_skills(view: Vector2i) -> void:
	var sk = _player.skills
	sk.sp_extra = maxi(sk.sp_extra, 5)
	(sk.trees["melee"]["unlocked"] as Array).erase("attack_stance")  # the previous canvas bought it
	sk._recount_sp()
	_hud.open_skills("melee")
	await _frames(2)
	var sheet: Control = _hud._skills_sheet
	_expect(sheet != null and sheet.visible, "%s: Skills opens from open_skills" % view)
	var grid := sheet.find_child("SkillsGrid", true, false) as GridContainer
	_expect(grid != null and grid.columns == 4 and grid.get_child_count() == 12, "%s: a 4-column grid of 12 skills" % view)
	_expect(sheet._title.text == "Melee" and sheet.find_child("SkillXp", true, false) != null, "%s: the detail shows Melee with its Skill XP" % view)
	var cell := sheet.find_child("Skill_melee", true, false) as Control
	var BR = SheetChrome.Brackets
	_expect(cell != null and cell.get_children().any(func (c: Node) -> bool: return is_instance_of(c, BR)), "%s: the selected cell carries gold brackets" % view)
	await _layout(sheet, view, "skills", ["SkillsGridPanel", "SkillsDetail"])
	var spend := sheet.find_child("SkillsSpend", true, false) as Button
	var before: int = sk.sp_available
	var had_buy := not spend.disabled
	if had_buy:
		spend.pressed.emit()
	_expect(had_buy and sk.sp_available < before, "%s: the GOLD Spend button buys the next Melee node (SP %d -> %d)" % [view, before, sk.sp_available])
	(sheet.find_child("Skill_gathering", true, false) as Button).pressed.emit()
	_expect(sheet._title.text == "Gathering", "%s: tapping a cell selects it (%s)" % [view, sheet._title.text])
	(sheet._c["back"] as Button).pressed.emit()
	await _frames(1)
	_expect(not sheet.visible and _hud._sheet_kind == &"menu", "%s: ‹ closes Skills and opens the MENU" % view)
	_hud._close_sheet()

# ---------------------------------------------------------------- C4 Orders

func _test_orders(view: Vector2i) -> void:
	var OS_: GDScript = load("res://scripts/ui/orders_sheet.gd")
	OS_.tracked = -1
	_hud.open_orders()
	await _frames(2)
	var sheet: Control = _hud._orders_sheet
	var steps: Array = OS_.steps()
	_expect(sheet != null and sheet.visible and sheet._list.get_child_count() == steps.size() and steps.size() > 2, "%s: Orders lists every order (%d)" % [view, steps.size()])
	_expect(sheet._track.disabled and sheet._track.text == "Tracking on HUD", "%s: the running order reads Tracking on HUD" % view)
	await _layout(sheet, view, "orders", ["OrdersListPanel", "OrdersDetail"])
	var later: int = _player.get_node("/root/World").objective + 2
	(sheet._list.get_child(later) as Button).pressed.emit()
	_expect(not sheet._track.disabled and sheet._track.text == "Track on HUD", "%s: a later order offers Track on HUD" % view)
	sheet._track.pressed.emit()
	var card: Dictionary = OS_.hud_step(_player)
	_expect(OS_.tracked == later and str(card.get("title", "")) == str((steps[later] as Dictionary)["title"]), "%s: Track on HUD points the quest card at it (%s)" % [view, card.get("title", "")])
	_expect(sheet._track.disabled and sheet._track.text == "Tracking on HUD", "%s: and it now reads Tracking on HUD" % view)
	OS_.tracked = -1
	_expect(str(OS_.hud_step(_player).get("title", "")) == str(load("res://scripts/core/objectives.gd").current(_player).get("title", "")), "%s: untracked, the card follows the running order" % view)
	(sheet._c["back"] as Button).pressed.emit()
	await _frames(1)
	_expect(not sheet.visible and _hud._sheet_kind == &"menu", "%s: ‹ closes Orders and opens the MENU" % view)
	_hud._close_sheet()
