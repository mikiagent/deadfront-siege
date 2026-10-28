class_name AnimalScreen
extends Control
## E1 Animals (docs/design/ui-redesign-spec.md §7 E1, target docs/design/ui-redesign/e1-animals.webp).
## Left: the bonded pack as slots, `Data.bonded_cap()` of PACK_MAX (spec 09: 3 + Animal Handling I-IV
## = 7), empty and locked slots shown, then the tamed animals still waiting to bond. Centre: the
## selected pet's name with its NatureChip directly below it (§11), species, grade, its live model,
## growth XP. Right: stats, needs, Feed / Ride / Summon / Release.
##
## Roster rule (§9 open question 4, resolved here): the old header said "unlimited roster, three
## active companions". In code the roster IS `player.bonded`, capped by spec 09's bonded cap, and
## PlayerPets.MAX_OUT (3) is how many are summoned at once. So the pack slots are the bonded roster;
## "the rest of the roster" is spec 09 §2's unbonded animals: captured / tamed animal items in the bag
## and animals in taming pens. Nothing about the pet save format changes.
##
## Public entry for the nav menu: HuntHud.open_animals(rec = null), which calls open(player, rec).

## Spec 09 §3: three base slots plus Animal Handling I-IV.
const PACK_MAX := 7
const LIVE_REFRESH := 0.5

var player: Player
var selected: int = 0
var chrome: SheetChrome
var _backdrop: ColorRect
var _left: Panel
var _centre: Panel
var _right: Panel
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _note: Label
## Header counter "Bonded 2 / 3   (grows to 7)" (spec 09: bonded count and max in the pets UI).
var _bonded: Label
var _detail_name: Label
var _detail_chip: NatureChip
var _detail_sub: Label
var _grade: Label
var _stage: AnimalStage
var _empty: Label
var _xp_title: Label
var _xp_value: Label
var _xp_bar: ProgressBar
var _chips: HFlowContainer
var _stats_scroll: ScrollContainer
var _stats: VBoxContainer
var _buttons: GridContainer
var _feed: Button
var _ride: Button
var _gear: Button
var _summon: Button
var _release: Button
var _cards: Array[SheetChrome.Card] = []
var _refresh_left := 0.0

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = SheetChrome.ui_theme()
	_backdrop = SheetChrome.backdrop()
	add_child(_backdrop)
	chrome = SheetChrome.new("Animals")
	add_child(chrome)
	chrome.add_tab("Pack", true)
	# ASSUMPTION: E2 Taming Pen has no screen yet (§7 E2, "no dedicated script found"); its tab is shown
	# disabled so the header reads as the canvas does without opening an empty view.
	chrome.add_tab("Taming Pen", false, false)
	# TRIBE M1: the tribe's members and the recruits waiting at the dock (TribeScreen).
	chrome.add_tab("Tribe", false).pressed.connect(func () -> void:
		close_screen()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_tribe"):
			hud.open_tribe())
	chrome.back_pressed.connect(_back)
	chrome.close_pressed.connect(close_screen)
	_bonded = chrome.counter
	_left = _panel("PackPanel")
	_centre = _panel("DetailPanel")
	_right = _panel("StatsPanel")
	# left: pack slots, then the animals waiting to bond, then the note
	_list_scroll = ScrollContainer.new()
	_list_scroll.name = "PackScroll"
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.name = "PackList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	_list_scroll.add_child(_list)
	_note = SheetChrome.text("Learn Animal Handling (Survival) to open more slots, up to %d. Tamed animals waiting to bond stay in your bag or a taming pen." % PACK_MAX, 13, UiTokens.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.clip_text = false
	_left.add_child(_note)
	# centre: name, nature chip (§11), species, grade, model, growth
	_detail_name = SheetChrome.text("", 36, UiTokens.TEXT)
	_detail_name.name = "DetailName"
	SheetChrome.strong(_detail_name, 500)
	_centre.add_child(_detail_name)
	_detail_chip = NatureChip.new()
	_centre.add_child(_detail_chip)
	_detail_sub = SheetChrome.text("", 18, UiTokens.TEXT)
	_detail_sub.name = "DetailSub"
	_centre.add_child(_detail_sub)
	_grade = SheetChrome.text("", 26, UiTokens.GOLD)
	_grade.name = "Grade"
	SheetChrome.strong(_grade, 500)
	_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0, 0, 0, 0.25)
	gsb.border_color = UiTokens.GOLD
	gsb.set_border_width_all(2)
	_grade.add_theme_stylebox_override("normal", gsb)
	_centre.add_child(_grade)
	_stage = AnimalStage.new()
	_centre.add_child(_stage)
	_empty = SheetChrome.text("", 18, UiTokens.MUTED)
	_empty.name = "Empty"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.clip_text = false
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_centre.add_child(_empty)
	_xp_title = SheetChrome.text("", 18)
	_centre.add_child(_xp_title)
	_xp_value = SheetChrome.text("", 18)
	_xp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_centre.add_child(_xp_value)
	_xp_bar = _bar(UiTokens.XP)
	_xp_bar.name = "XpBar"
	_centre.add_child(_xp_bar)
	_chips = HFlowContainer.new()
	_chips.name = "Chips"
	_chips.add_theme_constant_override("h_separation", 8)
	_chips.add_theme_constant_override("v_separation", 6)
	_centre.add_child(_chips)
	# right: stats + needs (scroll), the action grid pinned at the bottom
	_stats_scroll = ScrollContainer.new()
	_stats_scroll.name = "StatsScroll"
	_stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.add_child(_stats_scroll)
	_stats = VBoxContainer.new()
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.add_theme_constant_override("separation", 0)
	_stats_scroll.add_child(_stats)
	_buttons = GridContainer.new()
	_buttons.name = "Actions"
	_buttons.columns = 2
	_buttons.add_theme_constant_override("h_separation", 10)
	_buttons.add_theme_constant_override("v_separation", 10)
	_right.add_child(_buttons)
	_feed = _action("Feed", &"cta", _feed_selected)
	_ride = _action("Ride", &"ghost", _ride_selected)
	_summon = _action("Summon", &"ghost", _toggle_selected)
	_gear = _action("Gear", &"ghost", _gear_selected)  # SADDLES: the tame's equipment (PetGearSheet)
	# ASSUMPTION: no release / bond-breaking exists in code; spec 09 §4 says breaking a bond takes a
	# special item. The button is shown (canvas) but disabled with that reason; no pet is ever deleted.
	_release = _action("Release · locked", &"danger", func () -> void: pass)
	_release.disabled = true
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	size = get_viewport_rect().size  # CanvasLayer children do not inherit a Control parent size
	_layout()

func _panel(n: String) -> Panel:
	var p := Panel.new()
	p.name = n
	p.add_theme_stylebox_override("panel", SheetChrome.panel_style())
	p.clip_contents = true
	add_child(p)
	return p

func _action(t: String, kind: StringName, cb: Callable) -> Button:
	var b := SheetChrome.action_button(t, kind)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	_buttons.add_child(b)
	return b

static func _bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar

# ---------------------------------------------------------------- layout

func _layout() -> void:
	if chrome == null:
		return
	var view := get_viewport_rect().size
	position = Vector2.ZERO
	size = view
	var compact := UiTokens.is_compact(view)
	var safe := UiTokens.safe_insets(get_viewport())
	var side := SheetChrome.side_for(view)
	var left_x := side + safe.w
	var right_x := view.x - side - safe.x
	var top := SheetChrome.body_top(view)
	var bottom := view.y - (8.0 if compact else 32.0) - safe.y
	var gap := 8.0 if compact else 20.0
	chrome.layout(view)
	var avail := right_x - left_x - gap * 2.0
	var lw := minf(420.0, avail * (0.3 if compact else 0.27))
	var rw := minf(455.0, avail * (0.3 if compact else 0.29))
	var h := bottom - top
	_left.position = Vector2(left_x, top)
	_left.size = Vector2(lw, h)
	_right.position = Vector2(right_x - rw, top)
	_right.size = Vector2(rw, h)
	_centre.position = Vector2(left_x + lw + gap, top)
	_centre.size = Vector2(_right.position.x - gap - _centre.position.x, h)
	# left
	var note_h := 0.0 if compact else 72.0
	_note.visible = not compact
	_note.position = Vector2(18, h - note_h)
	_note.size = Vector2(lw - 36, note_h - 12)
	_list_scroll.position = Vector2.ZERO
	_list_scroll.size = Vector2(lw, h - note_h)
	# centre
	var pad := 12.0 if compact else 24.0
	var cw := _centre.size.x
	var grade_s := 44.0 if compact else 66.0
	_grade.size = Vector2(grade_s, grade_s)
	_grade.position = Vector2(cw - pad - grade_s, pad * 0.75)
	_grade.add_theme_font_size_override("font_size", 20 if compact else 26)
	_detail_name.add_theme_font_size_override("font_size", 24 if compact else 36)
	_detail_name.position = Vector2(pad, pad * 0.5)
	_detail_name.size = Vector2(_grade.position.x - pad * 1.5, 32 if compact else 48)
	_detail_chip.position = Vector2(pad, _detail_name.position.y + _detail_name.size.y)
	_detail_sub.add_theme_font_size_override("font_size", 13 if compact else 18)
	var sub_y := _detail_chip.position.y + NatureChip.CHIP_H + 4.0
	_detail_sub.position = Vector2(pad, sub_y)
	_detail_sub.size = Vector2(_grade.position.x - pad * 1.5, 20 if compact else 26)
	var chips_h := 0.0 if compact else 40.0
	var xp_h := 22.0 if compact else 30.0
	var bar_h := 6.0 if compact else 8.0
	var chips_y := h - pad - chips_h
	_chips.position = Vector2(pad, chips_y)
	_chips.size = Vector2(cw - pad * 2.0, chips_h)
	var bar_y := chips_y - (12.0 if not compact else 0.0) - bar_h
	_xp_bar.position = Vector2(pad, bar_y)
	_xp_bar.size = Vector2(cw - pad * 2.0, bar_h)
	_xp_bar.custom_minimum_size = Vector2(0, bar_h)
	for l in [_xp_title, _xp_value]:
		(l as Label).add_theme_font_size_override("font_size", 13 if compact else 18)
	_xp_title.position = Vector2(pad, bar_y - xp_h - 4.0)
	_xp_title.size = Vector2((cw - pad * 2.0) * 0.6, xp_h)
	_xp_value.position = Vector2(pad + (cw - pad * 2.0) * 0.4, bar_y - xp_h - 4.0)
	_xp_value.size = Vector2((cw - pad * 2.0) * 0.6, xp_h)
	var stage_top := _detail_sub.position.y + _detail_sub.size.y + 4.0
	_stage.position = Vector2(pad, stage_top)
	_stage.size = Vector2(cw - pad * 2.0, maxf(40.0, _xp_title.position.y - 4.0 - stage_top))
	_empty.position = Vector2(pad, pad)
	_empty.size = Vector2(cw - pad * 2.0, h - pad * 2.0)
	# right
	var bpad := 8.0 if compact else 16.0
	var bh := 64.0
	var rows := ceili(_buttons.get_child_count() / 2.0)  # SADDLES: Gear made it five
	var grid_h := bh * rows + 10.0 * (rows - 1)
	_buttons.position = Vector2(bpad, h - bpad - grid_h)
	_buttons.size = Vector2(rw - bpad * 2.0, grid_h)
	for b in _buttons.get_children():
		(b as Button).add_theme_font_size_override("font_size", 13 if compact else 18)
		(b as Button).custom_minimum_size = Vector2(0, bh)
	_stats_scroll.position = Vector2.ZERO
	_stats_scroll.size = Vector2(rw, _buttons.position.y - bpad)
	if visible and player != null:
		_rebuild()

# ---------------------------------------------------------------- open / close

## Opens the screen on `rec` (the pet radial's Animals segment) or the last selected pet.
func open(p: Player, rec: PetRecord = null) -> void:
	player = p
	if rec and player.bonded.has(rec):
		selected = player.bonded.find(rec)
	selected = clampi(selected, 0, maxi(0, player.bonded.size() - 1))
	visible = true
	_layout()
	_rebuild()
	UiTokens.focus_first(_cards)

func close_screen() -> void:
	visible = false

## ‹ goes back to the MENU (§8); ✕ returns to the HUD.
func _back() -> void:
	close_screen()
	SheetChrome.back_to_menu(get_tree())

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible or player == null:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = LIVE_REFRESH
		_refresh_live()

# ---------------------------------------------------------------- content

func _rebuild() -> void:
	if player == null:
		return
	var view := get_viewport_rect().size
	var compact := UiTokens.is_compact(view)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_cards.clear()
	var cap := Data.bonded_cap()
	_bonded.text = ("Bonded %d / %d   (grows to %d)" % [player.bonded.size(), cap, PACK_MAX]) if cap < PACK_MAX else ("Bonded %d / %d" % [player.bonded.size(), cap])
	_list.add_child(SheetChrome.section_label("Pack slots", view))
	for i in player.bonded.size():
		var card := _pack_card(i, player.bonded[i], view)
		_cards.append(card)
		_list.add_child(card)
		(card.find_child("NatureChip", true, false) as NatureChip).configure(player.bonded[i].nature)
	var filled := player.bonded.size()
	for i in range(filled, cap):
		_list.add_child(_slot_row("Empty slot", view))
	var first_locked := maxi(cap, filled) + 1
	if first_locked <= PACK_MAX:
		_list.add_child(_slot_row(("%d – %d · locked" % [first_locked, PACK_MAX]) if first_locked < PACK_MAX else ("%d · locked" % PACK_MAX), view))
	var waiting := _waiting_rows()
	if not waiting.is_empty():
		_list.add_child(SheetChrome.section_label("Waiting to bond", view))
		for row in waiting:
			_list.add_child(_waiting_row(row, view))
	var has := not player.bonded.is_empty()
	for n in [_detail_name, _detail_sub, _grade, _stage, _xp_title, _xp_value, _xp_bar, _buttons, _stats_scroll]:
		(n as CanvasItem).visible = has
	_chips.visible = has and not compact
	_empty.visible = not has
	if not has:
		_detail_name.text = ""
		_detail_chip.configure(&"")
		_empty.text = "No bonded animals yet.\nKnock one down, net it, and tame it in a pen or by feeding to add it to your pack."
		return
	selected = clampi(selected, 0, player.bonded.size() - 1)
	_show_detail(player.bonded[selected])

func _pack_card(i: int, rec: PetRecord, view: Vector2) -> SheetChrome.Card:
	var compact := UiTokens.is_compact(view)
	var card := SheetChrome.Card.new()
	card.name = "PackCard%d" % i
	card.set_meta("pet_index", i)
	card.selected = i == selected
	card.custom_minimum_size = Vector2(0, 76 if compact else 120)
	card.pressed.connect(_select_row.bind(i))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := 8 if compact else 18
	row.offset_left = pad
	row.offset_right = -pad
	row.offset_top = 6 if compact else 16
	row.offset_bottom = -(6 if compact else 16)
	row.add_theme_constant_override("separation", 8 if compact else 14)
	card.add_child(row)
	row.add_child(_thumb(rec, 44.0 if compact else 76.0))
	var info := VBoxContainer.new()
	info.name = "Info"
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1 if compact else 2)
	row.add_child(info)
	var nm := SheetChrome.text(_name_of(rec), 15 if compact else 22, UiTokens.GOLD if i == selected else UiTokens.TEXT)
	nm.name = "Name"
	SheetChrome.strong(nm, 500)
	info.add_child(nm)
	# NATURES (§11): the chip sits directly under the name. Configured once the card is in the tree
	# (_rebuild): fitted before that, its label kept the fallback font's taller line box.
	var chip := NatureChip.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(chip)
	var sub := SheetChrome.text("%s · %s · %s" % [_species(rec), LevelDisplay.label(rec.level), rec.grade], 12 if compact else 15, UiTokens.TEXT)
	sub.name = "Sub"
	info.add_child(sub)
	var status := SheetChrome.text("", 12 if compact else 14, UiTokens.MUTED)
	status.name = "Status"
	info.add_child(status)
	_status_into(status, rec)
	return card

## A swatch in the pet's natural colour with the white animals glyph. ASSUMPTION: no painted creature
## portraits exist; the live 3D model is the centre panel's portrait, rows get this.
func _thumb(rec: PetRecord, s: float) -> Control:
	var p := Panel.new()
	p.name = "Thumb"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(s, s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = _tint(rec).darkened(0.45)
	sb.border_color = Color(UiTokens.HUD_RIM, 0.15)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	var icon := TextureRect.new()
	icon.texture = UiIcons.icon(&"animals")
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := s * 0.18
	icon.offset_left = inset
	icon.offset_top = inset
	icon.offset_right = -inset
	icon.offset_bottom = -inset
	icon.modulate = _tint(rec).lightened(0.35)
	p.add_child(icon)
	return p

func _tint(rec: PetRecord) -> Color:
	var base: Color = CreatureView.TINTS.get(str(rec.species), Color(0.55, 0.5, 0.4))
	var col := rec.coloration()
	if col:
		base.h = fposmod(base.h + col.hue_deg / 360.0, 1.0)
	return base

func _slot_row(t: String, view: Vector2) -> Control:
	var l := SheetChrome.text(t, 14 if UiTokens.is_compact(view) else 18, UiTokens.MUTED)
	l.name = "SlotRow"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, 56 if UiTokens.is_compact(view) else 110)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(UiTokens.HUD_RIM, 0.1)
	sb.border_width_bottom = 1
	l.add_theme_stylebox_override("normal", sb)
	return l

## Spec 09 §2: captured / tamed animal items in the bag and occupied taming pens (not bonded, not
## counted against the cap). Each row: [title, detail].
func _waiting_rows() -> Array:
	var out: Array = []
	if player.inventory:
		for s in player.inventory.slots:
			if s == null or not (s.def_id in [&"captured_animal", &"tamed_animal"]):
				continue
			var sp := str(s.attributes.get("species", "")).capitalize()
			if s.def_id == &"captured_animal":
				out.append(["%s · captured" % sp, "In your bag · tame it in a taming pen"])
			else:
				out.append(["%s · tamed" % sp, "In your bag · bonds when a slot is free"])
	if is_inside_tree():
		for pen in get_tree().get_nodes_in_group("taming_pen"):
			var occ: Variant = pen.get("occupant")
			if not occ is ItemStack:
				continue
			var sp := str((occ as ItemStack).attributes.get("species", "")).capitalize()
			var left := float(pen.get("remaining")) / maxf(0.001, Game.time_scale) if pen.get("remaining") != null else 0.0
			out.append(["%s · in a pen" % sp, "Ready · needs a free slot" if left <= 0.0 else "Taming · %d min left" % ceili(left / 60.0)])
	return out

func _waiting_row(row: Array, view: Vector2) -> Control:
	var compact := UiTokens.is_compact(view)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	var m := MarginContainer.new()
	m.name = "WaitingRow"
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(s, 10 if compact else 18)
	for s in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 6 if compact else 10)
	m.add_child(box)
	box.add_child(SheetChrome.text(str(row[0]), 14 if compact else 18))
	box.add_child(SheetChrome.text(str(row[1]), 12 if compact else 14, UiTokens.MUTED))
	return m

func _show_detail(rec: PetRecord) -> void:
	var view := get_viewport_rect().size
	var def := Data.creature(rec.species)
	_detail_name.text = _name_of(rec)
	_detail_chip.configure(rec.nature)
	var diet := ""
	if def:
		diet = "Herbivore" if def.is_herbivore_diet() else "Carnivore"
	_detail_sub.text = _species(rec) + (" · " + diet if diet != "" else "")
	_grade.text = str(rec.grade)
	if _stage.is_inside_tree():
		_stage.show_pet(rec)
	var need := PetRecord.xp_to_next(rec.level)
	_xp_title.text = "%s · Growth" % LevelDisplay.label(rec.level)
	_xp_value.text = "XP %d / %d" % [int(rec.xp), int(need)]
	_xp_bar.value = clampf(rec.xp / maxf(1.0, need), 0.0, 1.0)
	for c in _chips.get_children():
		c.queue_free()
	for role in rec.tamed_role:
		_chips.add_child(SheetChrome.chip(str(role).capitalize(), &"negative", 15))
	if rec.genetics:
		_chips.add_child(SheetChrome.chip("Potential %s" % rec.genetics.overall_tier(), &"positive", 15))
	for c in _stats.get_children():
		_stats.remove_child(c)
		c.queue_free()
	_stats.add_child(SheetChrome.section_label("Stats", view))
	var g := rec.genetics
	_stats.add_child(_stat_row("Life", "%d" % int(rec.hp), str(g.tier_for(&"health")) if g else "", view))
	_stats.add_child(_stat_row("Attack", "%d" % int(rec.attack), str(g.tier_for(&"melee_attack")) if g else "", view))
	_stats.add_child(_stat_row("Defense", "%d" % int(rec.defense), str(g.tier_for(&"melee_defense")) if g else "", view))
	_stats.add_child(_stat_row("Speed", "%d" % int(rec.speed), str(g.tier_for(&"speed")) if g else "", view))
	if rec.bag:
		_stats.add_child(_stat_row("Carry", "%d slots" % rec.bag.slot_count, "", view))
	_stats.add_child(SheetChrome.section_label("Needs", view))
	_stats.add_child(_need_row("Fullness", "FullnessRow", view))
	_stats.add_child(_need_row("Health", "HealthRow", view))
	_refresh_live()

func _stat_row(label: String, value: String, tier: String, view: Vector2) -> Control:
	var compact := UiTokens.is_compact(view)
	var pc := PanelContainer.new()
	pc.name = "Stat" + label
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(UiTokens.HUD_RIM, 0.08)
	sb.border_width_bottom = 1
	sb.content_margin_left = 10 if compact else 18
	sb.content_margin_right = 10 if compact else 18
	sb.content_margin_top = 3 if compact else 11
	sb.content_margin_bottom = 3 if compact else 11
	pc.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(row)
	var px := 13 if compact else 19
	var l := SheetChrome.text(label, px)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if tier != "":
		# The growth potential (genetics tier) the old text block listed, kept as a muted tag.
		row.add_child(SheetChrome.text(tier, px - 3, UiTokens.MUTED))
	var v := SheetChrome.text(value, px)
	v.name = "Value"
	v.custom_minimum_size = Vector2(56 if compact else 80, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return pc

func _need_row(label: String, n: String, view: Vector2) -> Control:
	var compact := UiTokens.is_compact(view)
	var m := MarginContainer.new()
	m.name = n
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(s, 10 if compact else 18)
	for s in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(s, 4 if compact else 10)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	m.add_child(box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var px := 13 if compact else 19
	var l := SheetChrome.text(label, px)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := SheetChrome.text("", px, UiTokens.OK_GREEN)
	v.name = "Value"
	v.custom_minimum_size = Vector2(110, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	var bar := _bar(UiTokens.OK_GREEN)
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(0, 5 if compact else 6)
	box.add_child(bar)
	return m

## Live values (hunger, health, out / down, button states) without rebuilding the lists.
func _refresh_live() -> void:
	if player == null or player.bonded.is_empty():
		return
	for card in _cards:
		if not is_instance_valid(card):
			continue
		var i := int(card.get_meta("pet_index", -1))
		if i >= 0 and i < player.bonded.size():
			var st := card.find_child("Status", true, false) as Label
			if st:
				_status_into(st, player.bonded[i])
	var rec := player.bonded[clampi(selected, 0, player.bonded.size() - 1)]
	var live := _live_of(rec)
	var full := (live.hunger / maxf(1.0, live.hunger_max)) if live else (rec.hunger / maxf(1.0, rec.hunger_max))
	_set_need("FullnessRow", full, "%d%%" % roundi(full * 100.0))
	var hp_max := live.health.max_hp if live else rec.hp
	var hp := live.health.hp if live else PlayerPets.stored_hp(rec)
	if hp < 0.0:
		hp = hp_max  # nothing stored = full health
	var down := rec.respawning()
	_set_need("HealthRow", 0.0 if down else hp / maxf(1.0, hp_max), ("Down · %ds" % ceili(rec.respawn_left)) if down else ("%d / %d" % [int(hp), int(hp_max)]))
	_update_buttons(rec, live)

func _set_need(n: String, ratio: float, value: String) -> void:
	var row := _stats.get_node_or_null(n)
	if row == null:
		return
	var col := UiTokens.OK_GREEN if ratio >= 0.3 else UiTokens.LIFE
	var v := row.find_child("Value", true, false) as Label
	if v:
		v.text = value
		v.add_theme_color_override("font_color", col)
	var bar := row.find_child("Bar", true, false) as ProgressBar
	if bar:
		bar.value = clampf(ratio, 0.0, 1.0)
		(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = col

func _update_buttons(rec: PetRecord, live: Creature) -> void:
	_update_button_texts(rec, live)
	# A landscape phone's buttons are ~100 px wide: the action word over its detail, not one line.
	if UiTokens.is_compact(get_viewport_rect().size):
		for b in [_feed, _ride, _summon, _gear, _release]:
			(b as Button).text = (b as Button).text.replace(" · ", "\n")

func _update_button_texts(rec: PetRecord, live: Creature) -> void:
	_release.text = "Release · locked"
	var out_n := player.live_pets().size()
	_summon.text = ("Dismiss · active %d / %d" if live else "Summon · active %d / %d") % [out_n, Player.MAX_PETS_OUT]
	_summon.disabled = live == null and (out_n >= Player.MAX_PETS_OUT or rec.respawning())
	if live == null:
		_feed.text = "Feed · summon first"
		_feed.disabled = true
	else:
		var food := _food_for(live)
		_feed.text = ("Feed · %s" % food) if food != "" else "Feed · no food it eats"
		_feed.disabled = food == ""
	if not (&"mount" in rec.tamed_role):
		_ride.text = "Ride · locked"
		_ride.disabled = true
	elif live == null:
		_ride.text = "Ride · summon first"
		_ride.disabled = true
	elif player.mounted_on != live and rec.ride_refusal() != "":
		_ride.text = "Ride · %s" % rec.ride_refusal().to_lower()
		_ride.disabled = true
	else:
		_ride.text = "Dismount" if player.mounted_on == live else "Ride"
		_ride.disabled = false
	var sad := rec.saddle()
	_gear.text = "Gear · %s" % (sad.def().display_name if sad and sad.def() else "no saddle")
	_gear.disabled = not (&"mount" in rec.tamed_role)  # a saddle is the only tame slot so far
	if _gear.disabled:
		_gear.text = "Gear · not rideable"

## The first food in the bag this pet eats (the same pick as the pet radial's Feed).
func _food_for(c: Creature) -> String:
	for s in player.inventory.slots:
		if s and Food._pet_accepts(c, s):
			var d := s.def()
			return d.display_name if d and d.display_name != "" else LevelDisplay.nice_name(str(s.def_id))
	return ""

func _status_into(l: Label, rec: PetRecord) -> void:
	var live := _live_of(rec)
	var hungry := rec.hunger_max > 0.0 and (live.hunger if live else rec.hunger) / rec.hunger_max < 0.3
	if rec.respawning():
		l.text = "Down · back in %ds" % ceili(rec.respawn_left)
		l.add_theme_color_override("font_color", UiTokens.LIFE)
	elif live:
		l.text = "Riding" if player.mounted_on == live else ("Out · following" + (" · hungry" if hungry else ""))
		l.add_theme_color_override("font_color", UiTokens.LIFE if hungry else UiTokens.OK_GREEN)
	else:
		l.text = "Resting" + (" · hungry" if hungry else "")
		l.add_theme_color_override("font_color", UiTokens.LIFE if hungry else UiTokens.MUTED)

func _live_of(rec: PetRecord) -> Creature:
	for pet in player.live_pets():
		if pet.pet_record == rec:
			return pet
	return null

## "Velociraptor": the species alone; the nature is the chip under the name (§11), never a word in it.
func _species(rec: PetRecord) -> String:
	return CreatureNatures.display_name("", str(rec.species).capitalize())

## The pet's own name (pet radial Rename), else its species.
func _name_of(rec: PetRecord) -> String:
	return rec.name if rec.name != "" else _species(rec)

func _is_out(rec: PetRecord) -> bool:
	return _live_of(rec) != null

# ---------------------------------------------------------------- actions

func _select_row(i: int) -> void:
	selected = i
	_rebuild()
	if i < _cards.size():
		_cards[i].grab_focus()

func _toggle_selected() -> void:
	if player == null or selected < 0 or selected >= player.bonded.size():
		return
	player.summon_pet(selected)
	_rebuild()

func _feed_selected() -> void:
	if player == null or selected >= player.bonded.size():
		return
	var live := _live_of(player.bonded[selected])
	if live:
		player.pets.feed_best(live)
		_refresh_live()

func _gear_selected() -> void:
	if player == null or selected < 0 or selected >= player.bonded.size():
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("open_pet_gear"):
		hud.open_pet_gear(player.bonded[selected])

func _ride_selected() -> void:
	if player == null or selected >= player.bonded.size():
		return
	var live := _live_of(player.bonded[selected])
	if live == null:
		return
	if player.mounted_on == live:
		player.dismount()
	else:
		if player.mounted_on:
			player.dismount()
		player.mount(live)
		close_screen()  # riding happens in the world
	_refresh_live()
