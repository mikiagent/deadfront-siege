class_name AnimalScreen
extends Control
## Desktop-first owned-animal roster + growth details. Unlimited roster, three active companions.

var player: Player
var selected: int = 0
var _list: VBoxContainer
var _detail: Label
var _summon: Button

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.035, 0.96)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var title := Label.new()
	title.text = "ANIMALS   ·   GROWTH"
	title.position = Vector2(32, 24)
	title.add_theme_font_size_override("font_size", 26)
	add_child(title)
	_list = VBoxContainer.new()
	_list.position = Vector2(32, 78)
	_list.size = Vector2(360, 570)
	_list.add_theme_constant_override("separation", 7)
	add_child(_list)
	_detail = Label.new()
	_detail.position = Vector2(430, 82)
	_detail.size = Vector2(600, 460)
	_detail.add_theme_font_size_override("font_size", 17)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_detail)
	_summon = Button.new()
	_summon.position = Vector2(430, 560)
	_summon.custom_minimum_size = Vector2(230, 54)
	_summon.pressed.connect(_toggle_selected)
	add_child(_summon)
	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(680, 560)
	close.custom_minimum_size = Vector2(180, 54)
	close.pressed.connect(close_screen)
	add_child(close)

func open(p: Player) -> void:
	player = p
	selected = clampi(selected, 0, maxi(0, player.bonded.size() - 1))
	visible = true
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
	if player == null or player.bonded.is_empty():
		_detail.text = "No bonded animals yet. Knock one down and feed it to add it to your roster."
		_summon.visible = false
		return
	_summon.visible = true
	for i in player.bonded.size():
		var rec: PetRecord = player.bonded[i]
		var b := Button.new()
		b.text = "%s   Lv.%d   %s%s" % [str(rec.species).capitalize(), rec.level, rec.grade, "   EQUIPPED" if _is_out(rec) else ""]
		b.custom_minimum_size = Vector2(350, 48)
		b.pressed.connect(func () -> void: selected = i; _rebuild())
		_list.add_child(b)
	_show_detail(player.bonded[selected])

func _show_detail(rec: PetRecord) -> void:
	var xp_need := PetRecord.xp_to_next(rec.level)
	var genes := rec.genetics
	var growth := ""
	if genes:
		for stat in CreatureGenetics.STATS:
			growth += "%s  %s   +%d growth   EV %d\n" % [str(stat).replace("_", " ").capitalize(), genes.tier_for(stat), int(genes.level_gains.get(stat, 0)), int(genes.evs.get(stat, 0))]
	_detail.text = "%s\nLv. %d   Grade %s\nXP %.0f / %.0f\n\nHP %.0f   Attack %.0f   Defense %.0f\nSpeed %.0f   Hunger %.0f / %.0f\n\nGROWTH / POTENTIAL\n%s\nLevel-ups add three random growth points. Training can focus EVs up to the species limits." % [str(rec.species).capitalize(), rec.level, rec.grade, rec.xp, xp_need, rec.hp, rec.attack, rec.defense, rec.speed, rec.hunger, rec.hunger_max, growth]
	_summon.text = "DISMISS" if _is_out(rec) else ("EQUIP   (%d / %d)" % [player.live_pets().size(), Player.MAX_PETS_OUT])
	_summon.disabled = not _is_out(rec) and player.live_pets().size() >= Player.MAX_PETS_OUT

func _is_out(rec: PetRecord) -> bool:
	for pet in player.live_pets():
		if pet.pet_record == rec:
			return true
	return false

func _toggle_selected() -> void:
	if player == null or selected < 0 or selected >= player.bonded.size():
		return
	player.summon_pet(selected)
	_rebuild()
