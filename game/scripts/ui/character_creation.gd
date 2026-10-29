class_name CharacterCreation
extends CanvasLayer
## First launch, in Durango's three screens (spec 19): Gender/Profession (one of eight occupations
## starts its tree at Lv. 20), Create Character (portrait, height, colours, parts) and Name. One
## live 3D survivor (SurvivorStage) moves between them. Finishing emits `done` as before; the look
## is on `look` for World to keep. `--occupation=<id>` preselects and finishes at once (tests).

signal done(occupation: String, gender: String, player_name: String)

## Gender, height, colours, parts and portrait settings (CharacterLook); World saves it.
var look: Dictionary = CharacterLook.defaults()
var _selected: String = ""
## The name step's field (the UI gate and older callers look it up by name: NameField).
var _name: LineEdit
## The control that finishes creation (the name step's OK).
var _start: Button
## Canvas px per fitted px: 1 once DisplayMode.install runs, ~2.3 on an unfitted 844x390 phone.
var _k := 1.0
var stage: SurvivorStage
var profession: CcProfessionStep
var create: CcCreateStep
var naming: CcNameStep
var step := 0
var _root: Control
var _rng := RandomNumberGenerator.new()

## Layout choice for a canvas `view` whose window DisplayMode would fit to `fitted`. Decided on the
## fitted canvas, then scaled by k, so the screen is the same with or without the canvas fit (the
## boot hook may land later; before this an unfitted landscape phone got the desktop layout at 0.43).
static func layout_for(view: Vector2, fitted: Vector2) -> Dictionary:
	var k := 1.0
	if fitted.x > 0.0 and fitted.y > 0.0:
		k = minf(view.x / fitted.x, view.y / fitted.y)
	var phone := UiTokens.is_compact(fitted)
	return {"k": k, "fitted": fitted, "phone": phone, "short": phone and not UiTokens.is_narrow(fitted), "narrow": UiTokens.is_narrow(fitted)}

func _px(v: float) -> int:
	return roundi(v * _k)

func _ready() -> void:
	layer = 60
	add_to_group(&"character_creation")
	_rng.randomize()
	_root = Control.new()
	_root.name = "CharacterCreationRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = CcUi.BG  # opaque: the HUD under it showed through the old 0.98 backdrop
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	profession = CcProfessionStep.new(self)
	create = CcCreateStep.new(self)
	naming = CcNameStep.new(self)
	stage = SurvivorStage.new()
	# The profession step goes first: its info column must be the first VBoxContainer (see its note).
	for n in [profession, create, naming]:
		_root.add_child(n)
	_root.add_child(stage)
	_root.move_child(stage, 1)
	_name = naming.field
	_start = naming.ok
	profession.next_pressed.connect(func () -> void: _go(1))
	create.back_pressed.connect(func () -> void: _go(0))
	create.next_pressed.connect(func () -> void: _go(2))
	naming.back_pressed.connect(func () -> void: _go(1))
	naming.ok_pressed.connect(_finish)
	var occ := SkillState.occupations()
	if not occ.is_empty():
		_selected = str(occ[0].get("id", ""))  # Durango opens with a row selected; any row can be picked
	get_viewport().size_changed.connect(_layout)
	stage.apply_look(look)
	_go(0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--occupation="):
			select_occupation(a.substr(13))
			call_deferred("_finish")

## Shows step `i` (0 Gender/Profession, 1 Create Character, 2 Name) with the stage in its place.
func _go(i: int) -> void:
	step = i
	for s in [profession, create, naming]:
		(s as Control).visible = s == [profession, create, naming][i]
	_layout()
	if i == 1:
		PortraitService.shared().request(look)
	if i == 2:
		naming.validate()

func _layout() -> void:
	relayout(get_viewport().get_visible_rect().size, DisplayMode.fitted_size(get_window()), UiTokens.safe_insets(get_viewport()))

## Lays the shown step out on a `view` canvas (t_charcreate drives it at 844x390 and 1600x900).
## `inset`: the safe area (x right, y bottom, z top, w left).
func relayout(view: Vector2, fitted: Vector2, inset: Vector4) -> void:
	var lay := layout_for(view, fitted)
	_k = float(lay["k"])
	var phone: bool = lay["phone"]
	var m := {
		"px": _px, "phone": phone, "inset": inset,
		"band_h": float(_px(46 if phone else 72)) + inset.z, "title_px": _px(20 if phone else 30),
	}
	var s: Control = [profession, create, naming][step]
	var r: Rect2 = s.call("layout", view, m)
	stage.position = r.position
	stage.size = r.size

func occupation() -> String:
	return _selected

func occupation_row(id: String) -> Dictionary:
	for row in SkillState.occupations():
		if str(row.get("id", "")) == id:
			return row
	return {}

func select_occupation(id: String) -> void:
	_selected = id
	profession.refresh()
	profession.show_selected()

func set_gender(g: String) -> void:
	look["gender"] = g
	_set_look(look)

func set_height(h: float) -> void:
	look["height"] = h
	_set_look(look)

func set_color(slot: String, hex: String) -> void:
	if hex == "":
		look["colors"].erase(slot)
	else:
		look["colors"][slot] = hex
	_set_look(look)

## The preview tries a kit on (Durango's clothing toggles): preview only, nothing is given or saved.
func preview_outfit(kit: String) -> void:
	stage.wear(kit)
	create.refresh()

## A slot only kits carry (Outfit Color 3) cannot show on the base clothes: the preview puts on the first
## kit that has it, so the swatches never look inert.
func show_slot(slot: String) -> void:
	if stage.outfit == "" and CharacterLook.kit_only(slot):
		for o in CharacterLook.preview_outfits():
			if str(o.get("id", "")) in CharacterLook.atlases_with(slot):
				stage.wear(str(o.get("id", "")))
				return

func set_part(slot: String, option: String) -> void:
	look["parts"][slot] = option
	_set_look(look)

func set_portrait(key: String, value: String) -> void:
	look["portrait"][key] = value
	_set_look(look)

## The die: a new look from the data's ranges and palettes, keeping the chosen gender.
func randomize_look() -> void:
	_set_look(CharacterLook.randomized(str(look["gender"]), _rng))

func _set_look(new_look: Dictionary) -> void:
	look = CharacterLook.clean(new_look)
	stage.apply_look(look)
	profession.refresh()
	create.refresh()
	if step == 1:
		PortraitService.shared().request(look)

func _finish() -> void:
	if _selected == "":
		return
	var nm := naming.player_name()
	if nm == "" or CcNameStep.name_error(nm) != "":
		nm = "Survivor"
	done.emit(_selected, str(look["gender"]), nm)
	queue_free()
