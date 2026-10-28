class_name CharacterSheet
extends Control
## C1 Character (docs/design/ui-redesign-spec.md §7 C1, mockup ui-redesign/c1-character.webp), split
## out of the bag's old Character page (inventory_ui.gd). Full-screen with the shared chrome (§8):
## tabs Equipment / Titles / Appearance; left the profile on parchment and the stats list (plus the
## four gear presets); centre the figure with the ten slots around it (Head, Body, Arms, Legs | Weapon,
## Tool, Ring, Bag; Food 1, Food 2 under it) and the selected piece's bar with Unequip and Open bag;
## right the survival needs.
## Hosted by InventoryUI (it shares the bag's inventory and player); open it with
## InventoryUI.open_character() or HuntHud.open_character().


signal bag_requested    ## "Open bag ›"
signal close_requested  ## ✕ / Esc
signal back_requested   ## ‹ (back to the MENU)
signal eat_requested(index: int)  ## a food slot with food in the bag

const LEFT_SLOTS := ["head", "body", "arms", "legs"]
const RIGHT_SLOTS := ["weapon", "tool", "accessory1", "accessory2"]
const FOOD_SLOTS := ["food1", "food2"]
## ASSUMPTION: both accessory slots take a ring or a bag (Inventory.slot_for); the mockup's labels name
## the first "Ring" and the second "Bag".
const LABELS := {"head": "Head", "body": "Body", "arms": "Arms", "legs": "Legs", "weapon": "Weapon", "tool": "Tool",
	"accessory1": "Ring", "accessory2": "Bag", "food1": "Food 1", "food2": "Food 2"}
## Faded silhouettes for empty gear slots (spec 13 s14): a representative item's art at low alpha.
const SILHOUETTES := {"head": &"forager_hood", "body": &"forager_vest", "arms": &"forager_wraps", "legs": &"forager_leggings", "weapon": &"stone_knife", "tool": &"work_pick", "accessory1": &"basic_bag", "accessory2": &"basic_bag", "food1": &"berry", "food2": &"berry"}
const TABS := ["Equipment", "Titles", "Appearance"]

var inventory: Inventory
var player: Player
var _c: Dictionary = {}
var _tab := "Equipment"
var _tab_btns: Dictionary = {}
var _left: PanelContainer
var _centre: PanelContainer
var _right: PanelContainer
var _name: Label
var _sub: Label
var _profile: PanelContainer
var _stats: VBoxContainer
var _preset_grid: HBoxContainer
var _preset_btns: Array[Button] = []
var _equip_view: VBoxContainer
var _slot_grids: Array[GridContainer] = []
var _slots: Dictionary = {}       # slot -> Button
var _slot_labels: Dictionary = {} # slot -> Label (under the slot on a desktop)
var _figure: TextureRect
var _foods: HBoxContainer
var _bar: PanelContainer
var _sel_label: Label
var _unequip_btn: Button
var _bag_btn: Button
var _titles_view: VBoxContainer
var _titles_scroll: ScrollContainer
var _deco_note: Label
var _needs: VBoxContainer
var _status: Label
var _gear_sel := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 46  # over the HUD hexes where the bag shares the HUD's canvas layer (labs)
	visible = false
	_c = SheetChrome.build(self, "Character")
	(_c["back"] as Button).pressed.connect(func () -> void: back_requested.emit())
	(_c["close"] as Button).name = "CharacterClose"
	(_c["close"] as Button).pressed.connect(func () -> void: close_requested.emit())
	for t: String in TABS:
		var b := SheetChrome.flat_button(t)
		b.name = "Tab" + t
		b.pressed.connect(func () -> void: _tab = t; refresh())
		(_c["tabs"] as Control).add_child(b)
		_tab_btns[t] = b
	var row := HBoxContainer.new()
	row.name = "CharacterBody"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 20)
	(_c["body"] as Control).add_child(row)
	_build_left(row)
	_build_centre(row)
	_build_right(row)
	resized.connect(_layout)

func _build_left(row: HBoxContainer) -> void:
	_left = PanelContainer.new()
	_left.name = "CharacterStatsPanel"
	_left.add_theme_stylebox_override("panel", SheetChrome.panel_style())
	row.add_child(_left)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_left.add_child(col)
	_profile = PanelContainer.new()
	_profile.name = "Profile"
	col.add_child(_profile)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	_profile.add_child(pv)
	_name = SheetChrome.label("", 30, UiTokens.PARCHMENT_INK, true)
	_name.name = "ProfileName"
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pv.add_child(_name)
	_sub = SheetChrome.label("", 17, UiTokens.PARCHMENT_INK)
	_sub.name = "ProfileSub"
	_sub.clip_text = true
	_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pv.add_child(_sub)
	var scroll := ScrollContainer.new()
	scroll.name = "StatsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var pad := MarginContainer.new()
	pad.name = "StatsPad"
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	_stats = VBoxContainer.new()
	_stats.name = "Stats"
	_stats.add_theme_constant_override("separation", 0)
	pad.add_child(_stats)
	# The four gear presets (INVSCREENS) sit in the header's right slot, clear of the stats list.
	_preset_grid = HBoxContainer.new()
	_preset_grid.name = "Presets"
	_preset_grid.add_theme_constant_override("separation", 4)
	(_c["right"] as Control).add_child(_preset_grid)
	for k in GearPresets.count():
		var b := SheetChrome.action_button(str(k + 1), &"ghost", false)
		b.name = "Preset%d" % (k + 1)
		b.custom_minimum_size = Vector2(SheetChrome.TAP, SheetChrome.TAP)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_on_preset.bind(k))
		_preset_grid.add_child(b)
		_preset_btns.append(b)

func _build_centre(row: HBoxContainer) -> void:
	_centre = PanelContainer.new()
	_centre.name = "CharacterEquipPanel"
	_centre.add_theme_stylebox_override("panel", SheetChrome.panel_style(UiTokens.PANEL, 12.0))
	_centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_centre)
	var stack := Control.new()
	_centre.add_child(stack)
	_equip_view = VBoxContainer.new()
	_equip_view.name = "Equipment"
	_equip_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_equip_view.add_theme_constant_override("separation", 8)
	stack.add_child(_equip_view)
	var around := HBoxContainer.new()
	around.name = "Around"
	around.size_flags_vertical = Control.SIZE_EXPAND_FILL
	around.add_theme_constant_override("separation", 12)
	_equip_view.add_child(around)
	for side: Array in [LEFT_SLOTS, RIGHT_SLOTS]:
		var g := GridContainer.new()
		g.add_theme_constant_override("h_separation", 6)
		g.add_theme_constant_override("v_separation", 6)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_slot_grids.append(g)
		for s: String in side:
			g.add_child(_slot(s))
		if side == LEFT_SLOTS:
			around.add_child(g)
			_figure = TextureRect.new()
			_figure.name = "Figure"
			_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_figure.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
			_figure.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
			around.add_child(_figure)
		else:
			around.add_child(g)
	_foods = HBoxContainer.new()
	_foods.name = "Foods"
	_foods.alignment = BoxContainer.ALIGNMENT_CENTER
	_foods.add_theme_constant_override("separation", 40)
	_equip_view.add_child(_foods)
	for s: String in FOOD_SLOTS:
		_foods.add_child(_slot(s))
	_bar = PanelContainer.new()
	_bar.name = "SelectionBar"
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = UiTokens.HEADER
	bsb.content_margin_left = 16
	bsb.content_margin_right = 8
	_bar.add_theme_stylebox_override("panel", bsb)
	_equip_view.add_child(_bar)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 8)
	_bar.add_child(bh)
	_sel_label = SheetChrome.label("", 20)
	_sel_label.name = "SelectedPiece"
	_sel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sel_label.clip_text = true
	_sel_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bh.add_child(_sel_label)
	_unequip_btn = SheetChrome.action_button("Unequip", &"ghost", false)
	_unequip_btn.name = "UnequipButton"
	_unequip_btn.pressed.connect(_on_unequip_pressed)
	bh.add_child(_unequip_btn)
	_bag_btn = SheetChrome.flat_button("Open bag ›")
	_bag_btn.name = "OpenBag"
	_bag_btn.add_theme_color_override("font_color", UiTokens.GOLD)
	_bag_btn.pressed.connect(func () -> void: bag_requested.emit())
	bh.add_child(_bag_btn)
	# Scrolls: earned rows carry a 64 px Wear/Remove button, and seven of them overrun 844x390.
	_titles_scroll = ScrollContainer.new()
	_titles_scroll.name = "TitlesScroll"
	_titles_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_titles_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(_titles_scroll)
	_titles_view = VBoxContainer.new()
	_titles_view.name = "Titles"
	_titles_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titles_view.add_theme_constant_override("separation", 0)
	_titles_scroll.add_child(_titles_view)
	# ASSUMPTION: the game has no decorative (cosmetic) gear yet, so Appearance says so instead of
	# inventing slots (INVSCREENS' Decorative tab; spec 13 s13: only what the game supports).
	_deco_note = SheetChrome.label("No decorative gear yet. Your look is set when you create your survivor.", 20, UiTokens.MUTED)
	_deco_note.name = "AppearanceNote"
	_deco_note.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deco_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deco_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deco_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(_deco_note)

func _slot(s: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "Slot_%s" % s
	v.add_theme_constant_override("separation", 4)
	var b := Button.new()
	b.name = "Equip_%s" % s
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.clip_text = true
	b.pressed.connect(_on_equip_slot_pressed.bind(s))
	v.add_child(b)
	var l := SheetChrome.label(str(LABELS[s]), 16, UiTokens.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_slots[s] = b
	_slot_labels[s] = l
	return v

func _build_right(row: HBoxContainer) -> void:
	_right = PanelContainer.new()
	_right.name = "CharacterSurvivalPanel"
	_right.add_theme_stylebox_override("panel", SheetChrome.panel_style())
	row.add_child(_right)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_right.add_child(col)
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0, 0, 0, 0.25)
	hsb.content_margin_left = 18
	hsb.content_margin_top = 10
	hsb.content_margin_bottom = 10
	head.add_theme_stylebox_override("panel", hsb)
	head.add_child(SheetChrome.label("Survival", 22))
	head.name = "SurvivalHead"
	col.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.name = "NeedsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var pad := MarginContainer.new()
	pad.name = "NeedsPad"
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	_needs = VBoxContainer.new()
	_needs.name = "Needs"
	_needs.add_theme_constant_override("separation", 14)
	pad.add_child(_needs)
	var foot := PanelContainer.new()
	foot.name = "StatusFoot"
	foot.add_theme_stylebox_override("panel", hsb.duplicate())
	col.add_child(foot)
	_status = SheetChrome.label("", 19, UiTokens.OK_GREEN)
	_status.name = "StatusLine"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(_status)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()

func bind(inv: Inventory, p: Player) -> void:
	inventory = inv
	player = p

# ---------------------------------------------------------------- layout

func _layout() -> void:
	_apply_sizes()
	if visible:
		refresh()

## Panel widths, slot and type sizes for the current canvas (also on every refresh: the sheet can
## open without a resize, e.g. the first time).
func _apply_sizes() -> void:
	if _c.is_empty():
		return
	var view := get_viewport_rect().size
	SheetChrome.fit(_c, view, UiTokens.safe_insets(get_viewport()))
	var compact := SheetChrome.compact(view)
	(_c["body"] as Control).get_child(0).add_theme_constant_override("separation", 8 if compact else 20)
	_left.custom_minimum_size = Vector2(196 if compact else 380, 0)
	_right.custom_minimum_size = Vector2(212 if compact else 474, 0)
	_profile.add_theme_stylebox_override("panel", SheetChrome.parchment_style(8.0 if compact else 18.0, 8.0 if compact else 18.0))
	_name.add_theme_font_size_override("font_size", SheetChrome.px(view, 30, 17))
	_sub.add_theme_font_size_override("font_size", SheetChrome.px(view, 17, 12))
	for m: MarginContainer in [_stats.get_parent(), _needs.get_parent()]:
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 8 if compact else 20)
	for b: Button in _preset_btns:
		b.add_theme_font_size_override("font_size", SheetChrome.px(view, 16, 13))
	# A phone has no room for labels under the slots: an empty slot shows its name inside instead.
	var slot_px := SheetChrome.TAP if compact else 96.0
	for g: GridContainer in _slot_grids:
		g.columns = 2 if compact else 1
		g.add_theme_constant_override("v_separation", 4 if compact else 14)
	for s: String in _slots:
		var b: Button = _slots[s]
		b.custom_minimum_size = Vector2(slot_px, slot_px)
		b.add_theme_font_size_override("font_size", 12 if compact else 16)
		(_slot_labels[s] as Label).visible = not compact
		(_slot_labels[s] as Label).add_theme_font_size_override("font_size", 16)
	_foods.add_theme_constant_override("separation", 16 if compact else 40)
	_sel_label.add_theme_font_size_override("font_size", SheetChrome.px(view, 20, 13))
	_unequip_btn.add_theme_font_size_override("font_size", SheetChrome.px(view, 18, 13))
	_bag_btn.add_theme_font_size_override("font_size", SheetChrome.px(view, 20, 14))
	_deco_note.add_theme_font_size_override("font_size", SheetChrome.px(view, 20, 14))
	_status.add_theme_font_size_override("font_size", SheetChrome.px(view, 19, 13))
	(_right.get_child(0).get_child(0).get_child(0) as Label).add_theme_font_size_override("font_size", SheetChrome.px(view, 22, 15))
	var fig := 84.0 if compact else 300.0
	_centre.add_theme_stylebox_override("panel", SheetChrome.panel_style(UiTokens.PANEL, 6.0 if compact else 12.0))
	(_equip_view.get_child(0) as HBoxContainer).add_theme_constant_override("separation", 6 if compact else 12)
	_figure.custom_minimum_size = Vector2(fig, fig)

# ---------------------------------------------------------------- refresh

func refresh() -> void:
	if inventory == null:
		return
	var view := get_viewport_rect().size
	_apply_sizes()
	for t: String in _tab_btns:
		SheetChrome.tab_style(_tab_btns[t], t == _tab, SheetChrome.compact(view))
	_equip_view.visible = _tab == "Equipment"
	_titles_scroll.visible = _tab == "Titles"
	_deco_note.visible = _tab == "Appearance"
	var nm := player.display_name() if player else (World.player_name if World.player_name != "" else "Survivor")
	var occ := World.occupation.capitalize() if World.occupation != "" else "Survivor"
	_name.text = nm
	_sub.text = "%s · %s · %s" % [LevelDisplay.player_label(), occ, LevelDisplay.current_title(LevelDisplay.player_level())]
	_fill_stats(view)
	_fill_presets()
	_figure.texture = PlayerPortrait.texture_for({"own": true, "id": "self"}, self) if player else PlayerPortrait.silhouette()
	_refresh_equipped()
	_fill_titles(view)
	_fill_needs(view)

## Rows: [label, value]. Life and Energy read the live vitals; the rest is InvStats' snapshot (the
## numbers combat and the bag use), then Carry and Skill points.
func stat_rows() -> Array:
	var rows: Array = []
	var snap := InvStats.snapshot(player)
	if player and player.vitals:
		var v := player.vitals
		rows.append(["Life", "%d / %d" % [roundi(v.health), roundi(v.effective_max_health())]])
		rows.append(["Energy", "%d / %d" % [roundi(v.energy), roundi(v.effective_max_energy())]])
	for r: Array in InvStats.ROWS:
		if r[0] in ["max_health", "energy", "capacity"]:
			continue # shown as Life / Energy / Carry
		rows.append([r[1], InvStats.fmt(str(r[0]), snap[r[0]]) if snap.has(r[0]) else "-"])
	var groups := InvStats.powers_data()
	for k: String in ["combat", "crafting", "gathering"]:
		var g: Dictionary = groups.get(k, {})
		rows.append([str(g.get("label", k.capitalize() + " Power")), str(int(snap.get(k + "_power", 0))) if not snap.is_empty() else "-"])
	rows.append(["Carry", "%d / %d" % [inventory.used_slots(), inventory.capacity()]])
	if player and player.skills:
		rows.append(["Skill points", str(player.skills.sp_available)])
	return rows

func _fill_stats(view: Vector2) -> void:
	for c in _stats.get_children():
		_stats.remove_child(c)
		c.queue_free()
	var compact := SheetChrome.compact(view)
	for r: Array in stat_rows():
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(0, 30 if compact else 51)
		var a := SheetChrome.label(str(r[0]), SheetChrome.px(view, 21, 13))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		a.clip_text = true
		h.add_child(a)
		if str(r[0]) == "Skill points":  # the brain glyph is the skill point (Skills sheet, Spend)
			h.add_child(SheetChrome.icon_rect(&"brain", SheetChrome.px(view, 24, 16)))
		var b := SheetChrome.label(str(r[1]), SheetChrome.px(view, 21, 13))
		b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(b)
		_stats.add_child(h)
		var line := ColorRect.new()
		line.color = Color(1, 1, 1, 0.08)
		line.custom_minimum_size = Vector2(0, 1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats.add_child(line)

func _fill_presets() -> void:
	var lv := LevelDisplay.player_level()
	var active := GearPresets.active(inventory, lv)
	for k in _preset_btns.size():
		var b := _preset_btns[k]
		var open := k < GearPresets.unlocked_count(lv)
		b.disabled = not open
		b.text = "Set %d" % (k + 1) if open else LevelDisplay.label(GearPresets.unlock_level(k))
		b.tooltip_text = "Gear set %d" % (k + 1) if open else "Gear set %d unlocks at %s." % [k + 1, LevelDisplay.label(GearPresets.unlock_level(k))]
		b.add_theme_color_override("font_color", UiTokens.GOLD if open and k == active and not inventory.presets.is_empty() else UiTokens.TEXT)

func _on_preset(k: int) -> void:
	if inventory == null:
		return
	var why := GearPresets.switch(inventory, k)
	if why != "" and player:
		player.notice(why)
	refresh()

## A worn slot's item (food slots show the first of the chosen food).
func worn_in(slot: String) -> ItemStack:
	match slot:
		"weapon":
			return inventory.equipped_weapon()
		"tool":
			return inventory.equipped_gather_tool()
		"food1", "food2":
			var fid := str(inventory.quick_food[0 if slot == "food1" else 1])
			var idx := inventory.find_first(StringName(fid)) if fid != "" else -1
			return inventory.slots[idx] if idx >= 0 else null
	return inventory.equipped_in(StringName(slot))

## Real art (and Lv.) when worn; a faded silhouette when empty (its name inside on a phone, where
## the label under it is hidden); gold brackets and a gold label on the selected slot.
func _refresh_equipped() -> void:
	var compact := SheetChrome.compact(get_viewport_rect().size)
	for slot: String in _slots:
		var b: Button = _slots[slot]
		var st := worn_in(slot)
		var on := slot == _gear_sel
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.05, 0.07, 0.9)
		sb.border_color = Color(1, 1, 1, 0.08)
		sb.set_border_width_all(1)
		sb.set_content_margin_all(8 if not compact else 4)
		for k in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(k, sb)
		for c in b.get_children():
			if c is SheetChrome.Brackets:
				b.remove_child(c)
				c.queue_free()
		if on:
			b.add_child(SheetChrome.Brackets.new())
		(_slot_labels[slot] as Label).add_theme_color_override("font_color", UiTokens.GOLD if on else UiTokens.TEXT)
		var label := str(LABELS[slot])
		if st:
			b.icon = ItemIcons.texture(st.def_id)
			b.text = ""
			b.tooltip_text = st.tooltip()
			b.self_modulate = Color.WHITE
		else:
			b.icon = null if compact else ItemIcons.texture(SILHOUETTES.get(slot, &""))
			b.text = label if compact else ""
			b.tooltip_text = "%s: empty" % label
			b.self_modulate = Color(1, 1, 1, 1.0 if compact else 0.18)
	var sel := worn_in(_gear_sel) if _gear_sel != "" else null
	if sel:
		var d := sel.def()
		var facts: PackedStringArray = [d.display_name if d else str(sel.def_id)]
		if sel.level > 1:
			facts.append(LevelDisplay.label(sel.level))
		if _gear_sel == "weapon" and player:
			var snap := InvStats.snapshot(player)
			facts.append("Attack %s" % InvStats.fmt("attack", snap.get("attack", 0)))
		if sel.max_durability > 0:
			facts.append("%d/%d" % [sel.durability, sel.max_durability])
		_sel_label.text = "%s   %s" % [str(LABELS[_gear_sel]), " · ".join(facts)]
	else:
		_sel_label.text = "Tap a slot." if _gear_sel == "" else "%s   empty" % str(LABELS[_gear_sel])
	_sel_label.add_theme_color_override("font_color", UiTokens.TEXT)
	_unequip_btn.visible = sel != null and _gear_sel not in ["food1", "food2", "tool"]

func _on_unequip_pressed() -> void:
	if inventory == null or _gear_sel == "":
		return
	if inventory.equipment.has(_gear_sel) and not inventory.unequip(StringName(_gear_sel)) and player:
		player.notice("Bag is full.") # the gear stays worn (W2-INV: never dropped)
	refresh()

## A worn armour/weapon slot selects it (Unequip in the bar); the tool slot cycles the held tool; a
## food slot eats its food (or clears the empty shortcut), as on the bag's old Character page.
func _on_equip_slot_pressed(slot: String) -> void:
	if inventory == null:
		return
	match slot:
		"tool":
			var tools := inventory.gather_tools_in_bag()
			if not tools.is_empty():
				var pos := -1
				for i in tools.size():
					if int(tools[i]["index"]) == inventory.equipped_tool_index:
						pos = i
				inventory.set_equipped_tool_index(int(tools[(pos + 1) % tools.size()]["index"]))
		"food1", "food2":
			var fid := str(inventory.quick_food[0 if slot == "food1" else 1])
			var idx := inventory.find_first(StringName(fid)) if fid != "" else -1
			if idx >= 0 and player:
				eat_requested.emit(idx)
				return
			elif fid != "":
				inventory.set_quick_food(0 if slot == "food1" else 1, &"")
	_gear_sel = slot
	refresh()

## Titles tab: every title with the level that earns it. An earned one has Wear (worn over her name,
## in gold) or Remove; an unearned one shows its level.
func _fill_titles(view: Vector2) -> void:
	for c in _titles_view.get_children():
		_titles_view.remove_child(c)
		c.queue_free()
	if _tab != "Titles":
		return
	var worn := LevelDisplay.worn_title()
	var lv := LevelDisplay.player_level()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/titles.json")) if FileAccess.file_exists("res://data/skills/titles.json") else {}
	var keys: Array = (parsed as Dictionary).keys().filter(func (k: Variant) -> bool: return str(k).is_valid_int()) if parsed is Dictionary else []
	keys.sort_custom(func (a: Variant, b: Variant) -> bool: return int(a) < int(b))
	for k: Variant in keys:
		var t := str((parsed as Dictionary)[k])
		var h := HBoxContainer.new()
		h.name = "Title_%s" % str(k)
		h.custom_minimum_size = Vector2(0, 40 if SheetChrome.compact(view) else 56)
		var earned := int(k) <= lv
		var a := SheetChrome.label(t, SheetChrome.px(view, 22, 14), UiTokens.GOLD if t == worn else (UiTokens.TEXT if earned else UiTokens.MUTED), false, t == worn)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(a)
		if earned:
			var b := SheetChrome.flat_button("Remove" if t == worn else "Wear")
			b.name = "TitleToggle"
			b.add_theme_font_size_override("font_size", SheetChrome.px(view, 18, 13))
			b.pressed.connect(set_title.bind("" if t == worn else t))
			h.add_child(b)
		else:
			var b := SheetChrome.label(LevelDisplay.label(int(k)), SheetChrome.px(view, 18, 13), UiTokens.MUTED)
			b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h.add_child(b)
		_titles_view.add_child(h)

## Wears `t` over her name ("" clears it). Only an earned title takes.
func set_title(t: String) -> void:
	if t == "" or LevelDisplay.earned_titles(LevelDisplay.player_level()).has(t):
		World.player_title = t
	refresh()

## The survival rows this build has (docs/current/survival-needs.md): exhaustion is a meter; food,
## thirst and hygiene are statuses, so they read as a state, not a bar.
## Each row: {name, value, frac (-1 = no bar), color, note}.
func need_rows() -> Array:
	var rows: Array = []
	var v: Vitals = player.vitals if player else null
	var s: StatusEffects = player.statuses if player else null
	if v:
		var cap := maxf(1.0, v.effective_max_fatigue())
		var f := clampf(v.fatigue / cap, 0.0, 1.0)
		var tier := mini(3, int(f * 4.0))
		rows.append({"name": "Exhaustion", "value": "%s %d%%" % [["Rested", "Worn", "Tired", "Exhausted"][tier], roundi(f * 100.0)], "frac": f,
			"color": UiTokens.MOOD[tier], "note": "Only sleep in a tent or bed clears this fully."})
	var has := func (id: String) -> bool: return s != null and s.has(StringName(id))
	rows.append({"name": "Food", "value": "Full" if has.call("full") else "Can eat", "frac": -1.0, "color": UiTokens.OK_GREEN,
		"note": "Eating refills energy; Full blocks the next bite for a while."})
	rows.append({"name": "Thirst", "value": "Thirsty" if has.call("thirsty") else ("Quenched" if has.call("quenched") else "Fine"), "frac": -1.0,
		"color": UiTokens.GOLD if has.call("thirsty") else UiTokens.OK_GREEN, "note": "Drink from a gourd or stream."})
	var dirt := "Very dirty" if has.call("very_dirty") else ("Dirty" if has.call("dirty") else ("Clean" if has.call("clean") else "Fine"))
	rows.append({"name": "Hygiene", "value": dirt, "frac": -1.0, "color": UiTokens.GOLD if dirt.contains("irty") else UiTokens.OK_GREEN,
		"note": "Wash at a basin or in water."})
	return rows

func _fill_needs(view: Vector2) -> void:
	for c in _needs.get_children():
		_needs.remove_child(c)
		c.queue_free()
	var bad: PackedStringArray = []
	for r: Dictionary in need_rows():
		var col := VBoxContainer.new()
		col.name = "Need_" + str(r["name"])
		col.add_theme_constant_override("separation", 4)
		var h := HBoxContainer.new()
		var a := SheetChrome.label(str(r["name"]), SheetChrome.px(view, 22, 14))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(SheetChrome.label(str(r["value"]), SheetChrome.px(view, 20, 13), r["color"]))
		col.add_child(h)
		if float(r["frac"]) >= 0.0:
			col.add_child(SheetChrome.thin_bar(float(r["frac"]), r["color"], 5.0))
		var n := SheetChrome.label(str(r["note"]), SheetChrome.px(view, 16, 12), UiTokens.MUTED)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(n)
		_needs.add_child(col)
		if r["color"] != UiTokens.OK_GREEN and r["color"] != UiTokens.MOOD[0]:
			bad.append("%s: %s" % [r["name"], r["value"]])
	_status.text = "Rested · all needs normal" if bad.is_empty() else " · ".join(bad)
	_status.add_theme_color_override("font_color", UiTokens.OK_GREEN if bad.is_empty() else UiTokens.GOLD)
