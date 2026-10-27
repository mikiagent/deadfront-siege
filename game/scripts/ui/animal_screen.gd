class_name AnimalScreen
extends Control
## Owned-animal roster and growth. Unlimited roster, three active companions.
## Header, three pinned "with you" cards, the roster on the left and the selected animal on the
## right. On a phone the roster sits above the selected animal. Everything is laid out by containers
## so long names, big numbers and both screen sizes fit without hand-placed positions.

var player: Player
var selected: int = 0
var _list: VBoxContainer
var _detail: VBoxContainer
var _summon: Button
var _active: HBoxContainer
var _title: Label
var _count: Label
var _close: Button
var _with_label: Label
var _body: BoxContainer
var _roster_scroll: ScrollContainer
var _detail_scroll: ScrollContainer

const GOLD := Color(0.85, 0.70, 0.29)
const BLUE := Color(0.37, 0.65, 0.84)
const GREEN := Color(0.37, 0.75, 0.40)
const RED := Color(0.84, 0.21, 0.17)
const ORANGE := Color(0.85, 0.54, 0.23)

## A hexagon with one letter in it: the animal's stand-in portrait until it has art.
class HexBadge extends Control:
	var letter := ""
	var fill := Color(0.12, 0.42, 0.42, 0.95)

	func _init(p_letter: String = "", p_fill: Color = Color(0.12, 0.42, 0.42, 0.95), px: float = 54.0) -> void:
		letter = p_letter
		fill = p_fill
		custom_minimum_size = Vector2(px * 0.9, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([
			Vector2(w * 0.5, 0.0), Vector2(w, h * 0.25), Vector2(w, h * 0.75),
			Vector2(w * 0.5, h), Vector2(0.0, h * 0.75), Vector2(0.0, h * 0.25)])
		draw_colored_polygon(pts, fill)
		var font := ThemeDB.fallback_font
		var fs := int(h * 0.42)
		var ts := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, Vector2((w - ts.x) * 0.5, (h + float(fs) * 0.7) * 0.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.offset_left = 16
	sheet.offset_top = 16
	sheet.offset_right = -16
	sheet.offset_bottom = -16
	sheet.add_theme_stylebox_override("panel", UiTokens.panel_style(0.97))
	add_child(sheet)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UiTokens.SPACE)
	sheet.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UiTokens.SPACE * 2)
	root.add_child(header)
	_title = Label.new()
	_title.text = "ANIMALS"
	_title.add_theme_color_override("font_color", UiTokens.TEXT)
	header.add_child(_title)
	_count = Label.new()
	_count.add_theme_color_override("font_color", UiTokens.META)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.clip_text = true
	_count.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_count)
	_close = Button.new()
	_close.text = "✕"
	_close.custom_minimum_size = Vector2(44, 44)
	_style_btn(_close, false)
	_close.pressed.connect(close_screen)
	header.add_child(_close)
	_with_label = Label.new()
	_with_label.text = "WITH YOU"
	_with_label.add_theme_color_override("font_color", UiTokens.META)
	root.add_child(_with_label)
	_active = HBoxContainer.new()
	_active.add_theme_constant_override("separation", UiTokens.SPACE * 2)
	root.add_child(_active)
	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", UiTokens.SPACE * 3)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body)
	_roster_scroll = ScrollContainer.new()
	_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(_roster_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_scroll.add_child(_list)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_detail_scroll)
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_right", 18)  # keep the numbers clear of the scrollbar
	detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(detail_margin)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", UiTokens.SPACE * 2)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var view := get_viewport_rect().size
	var phone := UiTokens.is_phone(view)
	_title.add_theme_font_size_override("font_size", UiTokens.heading(view) + (4 if not phone else 0))
	_count.add_theme_font_size_override("font_size", UiTokens.body(view))
	_with_label.add_theme_font_size_override("font_size", UiTokens.meta(view))
	_body.vertical = phone
	if phone:
		_roster_scroll.custom_minimum_size = Vector2(0, 168)
		_roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_roster_scroll.size_flags_vertical = Control.SIZE_FILL
	else:
		_roster_scroll.custom_minimum_size = Vector2(minf(430.0, view.x * 0.3), 0)
		_roster_scroll.size_flags_horizontal = Control.SIZE_FILL
		_roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if player != null and visible:
		_rebuild()

func open(p: Player) -> void:
	player = p
	selected = clampi(selected, 0, maxi(0, player.bonded.size() - 1))
	visible = true
	# Fill the display even when the parent is a plain Control with no size of its own.
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_layout()
	_rebuild()

func close_screen() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- small builders

func _style_btn(b: Button, primary: bool) -> void:
	var normal := UiTokens.button_style(false)
	if primary:
		normal.bg_color = UiTokens.TEAL
		normal.border_color = UiTokens.TEAL
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.12)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", UiTokens.button_style(true))
	var ink := Color(0.02, 0.12, 0.12) if primary else UiTokens.TEXT
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_disabled_color", UiTokens.META)

func _bar(value: float, fill: Color, height: float = 10.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = clampf(value, 0.0, 1.0)
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.11, 0.12, 0.13)
	back.set_corner_radius_all(int(height * 0.5))
	var front := StyleBoxFlat.new()
	front.bg_color = fill
	front.set_corner_radius_all(int(height * 0.5))
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", front)
	return bar

func _label(text: String, size_px: int, color: Color = UiTokens.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _chip(grade: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var g := grade.substr(0, 1).to_upper()
	sb.bg_color = GOLD if g == "S" or g == "A" else (BLUE if g == "B" else Color(0.55, 0.58, 0.60))
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", sb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := _label(grade, UiTokens.body(get_viewport_rect().size), Color(0.08, 0.07, 0.02))
	chip.add_child(l)
	return chip

func _initial(rec: PetRecord) -> String:
	return str(rec.species).substr(0, 1).to_upper()

func _status_text(rec: PetRecord) -> String:
	if rec.respawning():
		return "Down. Back in %ds" % int(ceil(rec.respawn_left))
	if _is_out(rec):
		return "With you"
	if rec.hunger_max > 0.0 and rec.hunger <= 0.0:
		return "Hungry"
	return "At camp"

func _title_words(raw: String) -> String:
	var out := ""
	for part in raw.replace("_", " ").split(" ", false):
		var word := str(part)
		if word == "":
			continue
		if out != "":
			out += " "
		out += word.substr(0, 1).to_upper() + word.substr(1)
	return out

func _is_out(rec: PetRecord) -> bool:
	for pet in player.live_pets():
		if pet.pet_record == rec:
			return true
	return false

func _active_pet(slot: int) -> Creature:
	if player == null:
		return null
	var live := player.live_pets()
	if slot < 0 or slot >= live.size():
		return null
	return live[slot]

## All the text on the selected-animal side, joined, so a test can check it without walking nodes.
func detail_text() -> String:
	var parts: PackedStringArray = []
	_collect_text(_detail, parts)
	return "\n".join(parts)

func _collect_text(node: Node, out: PackedStringArray) -> void:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		_collect_text(child, out)

# ---------------------------------------------------------------- rebuild

func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _rebuild() -> void:
	_clear(_list)
	_clear(_active)
	_clear(_detail)
	var view := get_viewport_rect().size
	var owned := player.bonded.size() if player else 0
	var out_now := player.live_pets().size() if player else 0
	_count.text = "%d owned. %d of %d out with you." % [owned, out_now, Player.MAX_PETS_OUT]
	_pin_active(view)
	if player == null or player.bonded.is_empty():
		_summon = null
		_detail.add_child(_label("No animals yet.", UiTokens.heading(view)))
		var how := _label("To tame one: wear a wild animal down below 30 percent health, knock it over with a tackle, then feed it.", UiTokens.body(view), UiTokens.META)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(how)
		return
	selected = clampi(selected, 0, player.bonded.size() - 1)
	for i in player.bonded.size():
		_list.add_child(_roster_row(i, view))
	_show_detail(player.bonded[selected], view)

func _roster_row(i: int, view: Vector2) -> Control:
	var rec: PetRecord = player.bonded[i]
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := UiTokens.button_style(i == selected)
	normal.bg_color = UiTokens.TEAL_DIM if i == selected else Color(0.07, 0.08, 0.09, 0.9)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", UiTokens.button_style(true))
	b.pressed.connect(_select_row.bind(i))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	if rec.respawning():
		var ring := RespawnRing.new(rec, _rebuild)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ring)
	else:
		var badge := HexBadge.new(_initial(rec), UiTokens.TEAL_DIM if _is_out(rec) else Color(0.16, 0.17, 0.19), 48.0)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	var name_l := _label(_title_words(str(rec.species)), UiTokens.body(view) + 3)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_l)
	var meta := _label("Level %d. %s" % [rec.level, _status_text(rec)], UiTokens.meta(view), UiTokens.META)
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(meta)
	row.add_child(col)
	row.add_child(_chip(str(rec.grade)))
	return b

func _pin_active(view: Vector2) -> void:
	for i in Player.MAX_PETS_OUT:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 60 if UiTokens.is_phone(view) else 100)
		var sb := UiTokens.button_style(false)
		sb.bg_color = Color(0.07, 0.08, 0.09, 0.9)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		var pet := _active_pet(i)
		if pet == null or pet.pet_record == null:
			sb.border_color = Color(0.40, 0.42, 0.44, 0.7)
			card.add_theme_stylebox_override("panel", sb)
			var empty_text := "Empty" if UiTokens.is_phone(view) else "Empty slot.\nEquip an animal from the roster."
			var empty := _label(empty_text, UiTokens.meta(view), UiTokens.META)
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(empty)
		else:
			var rec := pet.pet_record
			sb.border_color = UiTokens.TEAL
			card.add_theme_stylebox_override("panel", sb)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			card.add_child(row)
			var badge := HexBadge.new(_initial(rec), UiTokens.TEAL_DIM, 56.0)
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(badge)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			col.add_theme_constant_override("separation", 2)
			var name_l := _label(_title_words(str(rec.species)), UiTokens.body(view) + 4)
			name_l.clip_text = true
			name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			col.add_child(name_l)
			col.add_child(_label("Level %d" % rec.level, UiTokens.meta(view), UiTokens.META))
			var hp_frac := 1.0
			if pet.health != null:
				hp_frac = pet.health.hp / maxf(1.0, pet.health.max_hp)
			col.add_child(_bar(hp_frac, GREEN, 8.0))
			row.add_child(col)
			var idx := player.bonded.find(rec)
			var go := Button.new()
			go.text = "Select"
			go.custom_minimum_size = Vector2(0, 40)
			go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_style_btn(go, false)
			if idx >= 0:
				go.pressed.connect(_select_row.bind(idx))
			row.add_child(go)
		_active.add_child(card)

func _show_detail(rec: PetRecord, view: Vector2) -> void:
	var phone := UiTokens.is_phone(view)
	var body_px := UiTokens.body(view)
	var meta_px := UiTokens.meta(view)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiTokens.SPACE * 3)
	_detail.add_child(top)
	if not phone:
		var portrait := PanelContainer.new()
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(0.07, 0.15, 0.14)
		psb.border_color = Color(0.17, 0.23, 0.22)
		psb.set_border_width_all(1)
		psb.set_corner_radius_all(12)
		portrait.add_theme_stylebox_override("panel", psb)
		portrait.custom_minimum_size = Vector2(220, 200)
		var center := CenterContainer.new()
		portrait.add_child(center)
		center.add_child(HexBadge.new(_initial(rec), UiTokens.TEAL_DIM, 140.0))
		top.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	top.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	var name_l := _label(_title_words(str(rec.species)), UiTokens.heading(view) + 12)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_l)
	name_row.add_child(_chip(str(rec.grade)))
	info.add_child(name_row)
	info.add_child(_label("Level %d" % rec.level, body_px, UiTokens.META))
	var xp_need := PetRecord.xp_to_next(rec.level)
	info.add_child(_label("XP  %.0f / %.0f" % [rec.xp, xp_need], meta_px, UiTokens.META))
	info.add_child(_bar(rec.xp / maxf(1.0, xp_need), UiTokens.TEAL))
	info.add_child(_label("Hunger  %.0f / %.0f" % [rec.hunger, rec.hunger_max], meta_px, UiTokens.META))
	info.add_child(_bar(rec.hunger / maxf(1.0, rec.hunger_max), GOLD))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", UiTokens.SPACE)
	info.add_child(buttons)
	_summon = Button.new()
	_summon.custom_minimum_size = Vector2(0, 48)
	_summon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summon.add_theme_font_size_override("font_size", body_px)
	_style_btn(_summon, true)
	_summon.text = "Send away" if _is_out(rec) else "Bring with you  (%d of %d)" % [player.live_pets().size(), Player.MAX_PETS_OUT]
	_summon.disabled = not _is_out(rec) and player.live_pets().size() >= Player.MAX_PETS_OUT
	_summon.pressed.connect(_toggle_selected)
	buttons.add_child(_summon)

	_detail.add_child(_label("STATS", meta_px, UiTokens.META))
	var maxes := _roster_maxes()
	_detail.add_child(_stat_row("Health", rec.hp, float(maxes["hp"]), RED, body_px))
	_detail.add_child(_stat_row("Attack", rec.attack, float(maxes["attack"]), ORANGE, body_px))
	_detail.add_child(_stat_row("Defense", rec.defense, float(maxes["defense"]), BLUE, body_px))
	_detail.add_child(_stat_row("Speed", rec.speed, float(maxes["speed"]), GREEN, body_px))

	var genes := rec.genetics
	if genes:
		_detail.add_child(_label("GROWTH POTENTIAL", meta_px, UiTokens.META))
		for stat in CreatureGenetics.STATS:
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 36)
			row.add_theme_constant_override("separation", 12)
			var n := _label(_title_words(str(stat)), body_px)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.clip_text = true
			n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			row.add_child(n)
			row.add_child(_chip(str(genes.tier_for(stat))))
			var g := _label("+%d growth" % int(genes.level_gains.get(stat, 0)), meta_px, UiTokens.META)
			g.custom_minimum_size = Vector2(88, 0)
			row.add_child(g)
			var ev := _label("EV %d" % int(genes.evs.get(stat, 0)), meta_px, UiTokens.META)
			ev.custom_minimum_size = Vector2(44, 0)
			row.add_child(ev)
			_detail.add_child(row)

func _stat_row(stat_name: String, value: float, max_value: float, fill: Color, body_px: int) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 36)
	row.add_theme_constant_override("separation", 12)
	var n := _label(stat_name, body_px, UiTokens.META)
	n.custom_minimum_size = Vector2(84, 0)
	row.add_child(n)
	row.add_child(_bar(value / maxf(1.0, max_value), fill))
	var v := _label("%.0f" % value, body_px + 1)
	v.custom_minimum_size = Vector2(64, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return row

## Bars compare an animal with the strongest in the roster, so the longest bar is the best you own.
func _roster_maxes() -> Dictionary:
	var m := {"hp": 1.0, "attack": 1.0, "defense": 1.0, "speed": 1.0}
	for rec: PetRecord in player.bonded:
		m["hp"] = maxf(float(m["hp"]), rec.hp)
		m["attack"] = maxf(float(m["attack"]), rec.attack)
		m["defense"] = maxf(float(m["defense"]), rec.defense)
		m["speed"] = maxf(float(m["speed"]), rec.speed)
	return m

func _select_row(i: int) -> void:
	selected = i
	_rebuild()

func _toggle_selected() -> void:
	if player == null or selected < 0 or selected >= player.bonded.size():
		return
	player.summon_pet(selected)
	_rebuild()
