class_name AnimalScreen
extends Control
## Owned-animal roster and growth. Unlimited roster, three active companions.

var player: Player
var selected: int = 0
var _list: VBoxContainer
var _detail: Label
var _summon: Button
var _active: HBoxContainer
var _title: Label
var _close: Button

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var sheet := Panel.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.offset_left = 16
	sheet.offset_top = 16
	sheet.offset_right = -16
	sheet.offset_bottom = -16
	sheet.add_theme_stylebox_override("panel", UiTokens.panel_style(0.96))
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	_title = Label.new()
	_title.text = "ANIMALS    ·    GROWTH"
	_title.position = Vector2(32, 28)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_title)
	_active = HBoxContainer.new()
	_active.position = Vector2(32, 72)
	_active.add_theme_constant_override("separation", UiTokens.SPACE)
	add_child(_active)
	_list = VBoxContainer.new()
	_list.position = Vector2(32, 156)
	_list.size = Vector2(420, 520)
	_list.add_theme_constant_override("separation", UiTokens.SPACE)
	add_child(_list)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "DetailScroll"
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.clip_contents = true
	add_child(detail_scroll)
	var detail_margin := MarginContainer.new()
	detail_margin.name = "DetailMargin"
	detail_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_margin)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_margin.add_child(_detail)
	_summon = Button.new()
	_summon.custom_minimum_size = Vector2(220, 56)
	_summon.add_theme_stylebox_override("normal", UiTokens.button_style(true))
	_summon.add_theme_color_override("font_color", UiTokens.ACTION)
	_summon.pressed.connect(_toggle_selected)
	add_child(_summon)
	_close = Button.new()
	_close.text = "CLOSE"
	_close.custom_minimum_size = Vector2(160, 56)
	_close.add_theme_stylebox_override("normal", UiTokens.button_style(false))
	_close.add_theme_color_override("font_color", UiTokens.ACTION)
	_close.pressed.connect(close_screen)
	add_child(_close)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var view := get_viewport_rect().size
	var phone := UiTokens.is_phone(view)
	var pad := 24.0
	_title.add_theme_font_size_override("font_size", UiTokens.heading(view))
	_title.size = Vector2(view.x - pad * 2.0, 36)
	var detail_scroll := get_node_or_null("DetailScroll") as Control
	_detail.add_theme_font_size_override("font_size", UiTokens.body(view))
	_summon.add_theme_font_size_override("font_size", UiTokens.body(view))
	_close.add_theme_font_size_override("font_size", UiTokens.body(view))
	_active.position = Vector2(pad, 72)
	_active.size = Vector2(view.x - pad * 2.0, 64)
	var bar_h := maxf(_summon.custom_minimum_size.y, _close.custom_minimum_size.y)
	var bottom_margin := bar_h + float(UiTokens.SPACE)
	_apply_detail_margin(detail_scroll, int(bottom_margin))
	if phone:
		_list.position = Vector2(pad, 148)
		_list.size = Vector2(view.x - pad * 2.0, 180)
		_summon.position = Vector2(pad, view.y - 76.0)
		_close.position = Vector2(view.x - pad - 160.0, view.y - 76.0)
		if detail_scroll:
			var scroll_top := 340.0
			var scroll_bottom := _summon.position.y - float(UiTokens.SPACE)
			detail_scroll.position = Vector2(pad, scroll_top)
			detail_scroll.size = Vector2(view.x - pad * 2.0, maxf(120.0, scroll_bottom - scroll_top))
		_detail.custom_minimum_size = Vector2(maxf(120.0, (detail_scroll.size.x if detail_scroll else view.x) - pad), 0)
	else:
		_list.position = Vector2(pad, 148)
		_list.size = Vector2(minf(420.0, view.x * 0.34), view.y - 240.0)
		var detail_x := _list.position.x + _list.size.x + 24.0
		_summon.position = Vector2(detail_x, view.y - 84.0)
		_close.position = Vector2(_summon.position.x + 236.0, view.y - 84.0)
		if detail_scroll:
			var scroll_top := 148.0
			var scroll_bottom := _summon.position.y - float(UiTokens.SPACE)
			detail_scroll.position = Vector2(detail_x, scroll_top)
			detail_scroll.size = Vector2(maxf(180.0, view.x - detail_x - pad), maxf(120.0, scroll_bottom - scroll_top))
		_detail.custom_minimum_size = Vector2(maxf(180.0, (detail_scroll.size.x if detail_scroll else 180.0) - 4.0), 0)

func _apply_detail_margin(detail_scroll: Control, bottom_margin: int) -> void:
	if detail_scroll == null:
		return
	var margin := detail_scroll.get_node_or_null("DetailMargin") as MarginContainer
	if margin:
		margin.add_theme_constant_override("margin_bottom", bottom_margin)

func open(p: Player) -> void:
	player = p
	selected = clampi(selected, 0, maxi(0, player.bonded.size() - 1))
	visible = true
	_layout()
	_rebuild()

func close_screen() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()

func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	for child in _active.get_children():
		child.queue_free()
	_pin_active()
	if player == null or player.bonded.is_empty():
		_detail.text = "No bonded animals yet. Knock one down and feed it to add it to your roster."
		_summon.visible = false
		return
	_summon.visible = true
	var view := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	for i in player.bonded.size():
		var rec: PetRecord = player.bonded[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiTokens.SPACE)
		row.custom_minimum_size = Vector2(0, 56)
		if rec.respawning():
			row.add_child(RespawnRing.new(rec, _rebuild))
		var b := Button.new()
		var full := "%s   Lv.%d   %s%s" % [str(rec.species).capitalize(), rec.level, rec.grade, "   EQUIPPED" if _is_out(rec) else ""]
		b.text = UiTokens.ellipsis(font, full, 300.0, UiTokens.body(view))
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(240, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", UiTokens.body(view))
		b.add_theme_stylebox_override("normal", UiTokens.button_style(i == selected))
		b.add_theme_color_override("font_color", UiTokens.ACTION)
		b.pressed.connect(_select_row.bind(i))
		row.add_child(b)
		_list.add_child(row)
	_show_detail(player.bonded[selected])

func _pin_active() -> void:
	var view := get_viewport_rect().size
	for i in Player.MAX_PETS_OUT:
		var slot := Button.new()
		var slot_w := minf(160.0, maxf(72.0, (_active.size.x - UiTokens.SPACE * 2.0) / float(Player.MAX_PETS_OUT)))
		slot.custom_minimum_size = Vector2(slot_w, 56)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_font_size_override("font_size", UiTokens.meta(view))
		slot.add_theme_color_override("font_color", UiTokens.ACTION)
		slot.clip_text = true
		slot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var rec := _active_record(i)
		if rec == null:
			slot.text = "ACTIVE"
			slot.add_theme_stylebox_override("normal", UiTokens.button_style(false))
		else:
			slot.text = UiTokens.ellipsis(ThemeDB.fallback_font, str(rec.species).capitalize(), 110.0, UiTokens.meta(view))
			slot.add_theme_stylebox_override("normal", UiTokens.button_style(true))
			var idx := player.bonded.find(rec)
			if idx >= 0:
				slot.pressed.connect(_select_row.bind(idx))
		_active.add_child(slot)

func _active_record(slot: int) -> PetRecord:
	if player == null:
		return null
	var live := player.live_pets()
	if slot < 0 or slot >= live.size():
		return null
	return live[slot].pet_record

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

func _show_detail(rec: PetRecord) -> void:
	var xp_need := PetRecord.xp_to_next(rec.level)
	var genes := rec.genetics
	var growth := ""
	if genes:
		for stat in CreatureGenetics.STATS:
			var stat_name := _title_words(str(stat))
			growth += "%s\n    %s    +%d growth    EV %d\n" % [stat_name, genes.tier_for(stat), int(genes.level_gains.get(stat, 0)), int(genes.evs.get(stat, 0))]
	var name := str(rec.species).capitalize()
	_detail.text = "%s\nLv. %d          Grade %s\nXP %.0f / %.0f\n\nHP              %.0f\nAttack          %.0f\nDefense         %.0f\nSpeed           %.0f\nHunger          %.0f / %.0f\n\nGROWTH / POTENTIAL\n%s\nLevel-ups add three random growth points. Training can focus EVs up to the species limits." % [name, rec.level, rec.grade, rec.xp, xp_need, rec.hp, rec.attack, rec.defense, rec.speed, rec.hunger, rec.hunger_max, growth]
	_summon.text = "DISMISS" if _is_out(rec) else ("EQUIP   (%d / %d)" % [player.live_pets().size(), Player.MAX_PETS_OUT])
	_summon.disabled = not _is_out(rec) and player.live_pets().size() >= Player.MAX_PETS_OUT

func _is_out(rec: PetRecord) -> bool:
	for pet in player.live_pets():
		if pet.pet_record == rec:
			return true
	return false

func _select_row(i: int) -> void:
	selected = i
	_rebuild()

func _toggle_selected() -> void:
	if player == null or selected < 0 or selected >= player.bonded.size():
		return
	player.summon_pet(selected)
	_rebuild()
