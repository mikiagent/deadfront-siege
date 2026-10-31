class_name LabSpawnPanel
extends Control
## Creature lab spawner (owner 2026-10-28: "a dinosaur selector so I can spawn them"). A SPAWN tab
## opens a panel: a dropdown of every species in game/data/creatures (model-less ones spawn as the
## box stand-in CreatureView builds and are marked "(stand-in)"), a count (1-6), a nature (or Random), an Alpha
## toggle; SPAWN drops them as a pack in front of the survivor, CLEAR ALL removes every wild animal.
## SheetChrome look, 64 px tap targets, mouse and touch.

const COUNT_MAX := 6
const SPAWN_AHEAD_M := 8.0

var player: Player
var species_id: StringName = &""
var count := 1
var nature: StringName = &""  ## "" = rolled per animal
var alpha := false
var _panel: PanelContainer
var _species_opt: OptionButton
var _count: Label
var _nature: Button
var _alpha: Button
var _ids: Array[StringName] = []

## Every species in the data, sorted (owner 2026-10-28: "put all of the animals in the creature lab").
static func all_species() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in Data.creatures:
		out.append(StringName(id))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))  # StringName sort is not alphabetical
	return out

static func has_model(id: StringName) -> bool:
	return ResourceLoader.exists("res://assets/creatures/%s/%s.glb" % [id, id])

## Dropdown row text: model-less species spawn as CreatureView's box placeholder.
static func item_label(id: StringName) -> String:
	return str(id).capitalize() + ("" if has_model(id) else " (stand-in)")

func setup(p: Player) -> void:
	player = p
	theme = SheetChrome.ui_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toggle := SheetChrome.gold_button("SPAWN")
	toggle.name = "SpawnToggle"
	toggle.custom_minimum_size = Vector2(140, SheetChrome.TAP)
	toggle.position = Vector2(16, 96)
	toggle.pressed.connect(func() -> void: _panel.visible = not _panel.visible)
	add_child(toggle)
	_panel = SheetChrome.panel()
	_panel.name = "SpawnPanel"
	_panel.position = Vector2(16 + 140 + 8, 96)  # beside the toggle, so it fits a 720 px tall window
	_panel.custom_minimum_size = Vector2(340, 0)
	_panel.visible = false
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	col.add_child(SheetChrome.label("Species", 16, UiTokens.TEXT, true))
	_species_opt = OptionButton.new()
	_species_opt.name = "SpeciesPicker"
	_species_opt.custom_minimum_size = Vector2(320, SheetChrome.TAP)
	_species_opt.fit_to_longest_item = false
	_ids = all_species()
	for id in _ids:
		_species_opt.add_item(item_label(id))
	var pop := _species_opt.get_popup()
	pop.add_theme_font_size_override("font_size", 20)
	pop.add_theme_constant_override("v_separation", int(SheetChrome.TAP) - 28)  # ~64 px touch rows at 20 px text
	pop.max_size = Vector2i(400, 64 * 6)  # scrolls past six rows so it fits a 390 px tall phone
	_species_opt.item_selected.connect(func(i: int) -> void: _pick_species(_ids[i]))
	col.add_child(_species_opt)
	var row := HBoxContainer.new()
	col.add_child(row)
	var minus := SheetChrome.ghost_button("-")
	minus.custom_minimum_size = Vector2(SheetChrome.TAP, SheetChrome.TAP)
	minus.pressed.connect(func() -> void: set_count(count - 1))
	row.add_child(minus)
	_count = SheetChrome.label("", 20, UiTokens.TEXT, true)
	_count.custom_minimum_size = Vector2(96, SheetChrome.TAP)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_count)
	var plus := SheetChrome.ghost_button("+")
	plus.custom_minimum_size = Vector2(SheetChrome.TAP, SheetChrome.TAP)
	plus.pressed.connect(func() -> void: set_count(count + 1))
	row.add_child(plus)
	_nature = SheetChrome.ghost_button("")
	_nature.pressed.connect(_next_nature)
	col.add_child(_nature)
	_alpha = SheetChrome.ghost_button("")
	_alpha.pressed.connect(func() -> void:
		alpha = not alpha
		_refresh())
	_alpha.visible = "alpha" in CreatureGenetics.new()  # ALPHAS have landed when genetics carries the flag
	col.add_child(_alpha)
	var go := SheetChrome.gold_button("SPAWN")
	go.name = "SpawnGo"
	go.pressed.connect(func() -> void: spawn(species_id, count, nature, alpha))
	col.add_child(go)
	var clear := SheetChrome.ghost_button("CLEAR ALL", true)
	clear.name = "ClearAll"
	clear.pressed.connect(clear_all)
	col.add_child(clear)
	if not _ids.is_empty():
		_pick_species(&"compsognathus" if _ids.has(&"compsognathus") else _ids[0])
	_refresh()

func set_count(n: int) -> void:
	count = clampi(n, 1, COUNT_MAX)
	_refresh()

func _pick_species(id: StringName) -> void:
	species_id = id
	_refresh()

func _next_nature() -> void:
	var all: Array[StringName] = [&""]
	all.append_array(CreatureNatures.ids())
	nature = all[(all.find(nature) + 1) % all.size()]
	_refresh()

func _refresh() -> void:
	if _count == null:
		return
	_count.text = "x%d" % count
	_nature.text = "Nature: %s" % ("Random" if nature == &"" else CreatureNatures.label(nature))
	_alpha.text = "Alpha: %s" % ("ON" if alpha else "off")
	_species_opt.select(_ids.find(species_id))

## Drop `n` of `sp` as one pack SPAWN_AHEAD_M in front of the survivor (member 0 an alpha when asked).
func spawn(sp: StringName, n: int, nat: StringName = &"", is_alpha: bool = false) -> Array[Creature]:
	if Data.creature(sp) == null or player == null:
		return []
	CreatureDef.allow_placeholder = true  # NOBOXES: the lab panel may drop model-less species as boxes
	var fwd := -player.visual.global_basis.z if player.visual else Vector3.FORWARD
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.01 else Vector3.FORWARD
	var s := Spawner.new()
	s.species = sp
	s.count = clampi(n, 1, COUNT_MAX)
	s.radius = 1.5 + 0.4 * float(s.count)
	s.as_pack = s.count > 1
	s.nature = nat
	s.force_alpha = is_alpha
	player.get_parent().add_child(s)
	s.global_position = player.global_position + fwd * SPAWN_AHEAD_M
	var made := s.spawn_now()
	s.queue_free()
	print("[creature_lab] spawned %d %s nature=%s alpha=%s" % [made.size(), sp, nat if nat != &"" else &"random", is_alpha])
	return made

## Remove every wild animal (pets and the mount stay).
func clear_all() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("creatures"):
		var c := node as Creature
		if c and not c.is_pet and not c.is_queued_for_deletion():
			c.queue_free()
			n += 1
	print("[creature_lab] cleared %d" % n)
	return n
