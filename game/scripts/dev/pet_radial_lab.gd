extends Node3D
## Pet radial lab (spec 23): home island, a bonded zebraceratops named REX and a compsognathus, every
## step through real pointer and key events. Shots: pet_tap (the menu a tap opens), rename, rename_typed,
## rename_resized, rename_refused, radial_renamed, radial_mounted, radial_compy, combat_pet_tap,
## animals_screen. Prints "[petradial] PASS" and exits 0, or FAIL lines and exit 1. With the old pet hex
## menu it shoots pet_tap and stops.
## Usage: Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility] -- --lab=pet_radial_lab --shot-dir=DIR

var _out := ""
var _player: Player
var _hud: HuntHud
var _cam: Camera3D
var _fails: Array[String] = []

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("pet_radial_lab")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	_cam = kit["cam"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	var modals := CanvasLayer.new()
	modals.name = "Modals"
	modals.layer = 96
	add_child(modals)
	_player.ui.reparent(modals)
	(_player.craft_ui as Node).reparent(modals)
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	print("[petradial] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join("%s_%dx%d.png" % [label, img.get_width(), img.get_height()])
	img.save_png(path)
	print("[petradial] shot %s" % path)

## A real left click (press, then release two frames later) at a canvas point.
func _tap_screen(vp: Vector2) -> void:
	var wp: Vector2 = get_viewport().get_final_transform() * vp
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = wp
	down.global_position = wp
	Input.parse_input_event(down)
	await _frames(2)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)

func _tap_pet(c: Creature) -> void:
	await _tap_screen(_cam.unproject_position(c.global_position + Vector3(0, c.def.height_meters * 0.5, 0)))

func _tap_segment(id: StringName) -> bool:
	var radial := _player.pets.get("menu") as PetRadial
	var i := radial.ids().find(id) if radial and radial.visible else -1
	if i < 0:
		return false
	await _tap_screen(radial.segment_center(i))
	return true

## Real key presses through Input (the path a keyboard takes, so polled movement sees them too).
## Returns the path the survivor walked meanwhile, in metres.
func _type(text: String) -> float:
	var walked := 0.0
	var last := _player.global_position
	for ch in text:
		var k := InputEventKey.new()
		k.keycode = OS.find_keycode_from_string(ch.to_upper())
		k.physical_keycode = k.keycode
		k.unicode = ch.unicode_at(0)
		k.pressed = true
		Input.parse_input_event(k)
		for f in 8:
			await get_tree().physics_frame
			walked += _player.global_position.distance_to(last)
			last = _player.global_position
		var up := k.duplicate() as InputEventKey
		up.pressed = false
		Input.parse_input_event(up)
		await _frames(2)
	return walked

## Screen rects of the creature plates' pills that are showing.
func _plate_pills() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var plates := get_tree().current_scene.get_node_or_null("CreaturePlates") as CanvasLayer
	if plates == null or plates.get_child_count() == 0 or not (plates.get_child(0) as Control).visible:
		return out
	for n in plates.get_child(0).get_children():
		var node := n as Control
		var pill := node.get_node_or_null("Pill") as Control if node else null
		if pill and node.visible and node.modulate.a > 0.05:
			out.append(Rect2(node.position + pill.position * node.scale, pill.size * node.scale))
	return out

## The HUD's hexes that are showing.
func _hud_controls() -> Array[Control]:
	var out: Array[Control] = []
	for n in get_tree().get_nodes_in_group(&"hex_button"):
		if n is HexButton and (n as Control).is_visible_in_tree() and _hud.is_ancestor_of(n):
			out.append(n as Control)
	return out

func _name_of(c: Control) -> String:
	return (c as HexButton).caption if c is HexButton else str(c.name)

func _summon(species: StringName, nm: String) -> Creature:
	var rec := PetRecord.from_def(Data.creature(species), &"A")
	rec.fit_saddle()  # SADDLES: the lab rides REX
	rec.name = nm
	_player.bonded.append(rec)
	return _player.pets.summon(_player.bonded.size() - 1)

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	print("[petradial] window=%s logical=%s" % [get_tree().root.size, get_viewport().get_visible_rect().size])
	var rex := _summon(&"zebraceratops", "REX")
	rex.hunger = rex.hunger_max * 0.6
	await get_tree().create_timer(2.0).timeout
	await _tap_pet(rex)
	# get(): the lab also runs against the old hex menu (BEFORE shots), where menu is a StationMenu.
	var menu := _player.pets.get("menu") as Control
	var radial := menu as PetRadial
	print("[petradial] pet tap: radial=%s visible=%s" % [radial != null, menu.visible if menu else false])
	await _shot("pet_tap")
	if radial == null:
		print("[petradial] old pet menu; stopping after pet_tap")
		get_tree().quit(0)
		return
	_check(radial.visible and radial.ids() == [&"animals", &"bag", &"feed", &"ride", &"gear", &"dismiss", &"rename"], "REX radial %s" % [radial.ids()])
	# Rename: refused with the character-name reason, then accepted.
	await _tap_segment(&"rename")
	var dialog := _player.pets.get("rename_dialog") as PetRenameDialog
	_check(dialog != null and dialog.visible, "Rename opens the name dialog")
	await _shot("rename")
	# Typing a name fills the field and does not walk the survivor (movement is polled).
	var field := dialog.find_child("NameField", true, false) as LineEdit
	var walked := await _type("dash")
	_check(field.text == "dash" and walked < 0.1, "typing 'dash' fills the field (%s) and walks %.2f m" % [field.text, walked])
	await _shot("rename_typed")
	# The window goes from desktop to phone size (or back) with the dialog open: the card follows.
	var win := get_tree().root.size
	get_tree().root.size = Vector2i(844, 390) if win.x > 1000 else Vector2i(1600, 900)
	await get_tree().create_timer(0.5).timeout
	var card := dialog.find_child("Card", true, false) as Control
	var view := get_viewport().get_visible_rect()
	_check(card != null and view.encloses(card.get_global_rect()) and absf(card.get_global_rect().get_center().x - view.get_center().x) < 2.0,
		"rename card on screen and centred after a resize (card %s, view %s)" % [card.get_global_rect() if card else Rect2(), view])
	await _shot("rename_resized")
	get_tree().root.size = win
	await get_tree().create_timer(0.5).timeout
	field.text = "R!"
	dialog.submit()
	await _frames(2)
	_check(dialog.visible and dialog.refusal() != "" and rex.pet_record.name == "REX", "bad name refused: %s" % dialog.refusal())
	await _shot("rename_refused")
	(dialog.find_child("NameField", true, false) as LineEdit).text = "Rex II"
	dialog.submit()
	await _frames(2)
	_check(not dialog.visible and rex.pet_record.name == "Rex II", "renamed to %s" % rex.pet_record.name)
	await _tap_pet(rex)
	await _frames(2)
	await _shot("radial_renamed")
	# Ride, then the ring on the mount offers Dismount.
	await _tap_segment(&"ride")
	await get_tree().create_timer(1.0).timeout
	_check(_player.mounted_on == rex, "Ride mounts REX")
	await _tap_pet(rex)
	await _frames(2)
	_check(radial.visible and &"dismount" in radial.ids() and not (&"ride" in radial.ids()), "ring on the mount: %s" % [radial.ids()])
	await _shot("radial_mounted")
	await _tap_segment(&"dismount")
	await _frames(3)
	_check(_player.mounted_on == null, "Dismount")
	# A combat-only species: no Ride, no Bag.
	var compy := _summon(&"compsognathus", "")
	await get_tree().create_timer(1.5).timeout
	await _tap_pet(compy)
	await _frames(2)
	_check(radial.visible and radial.ids() == [&"animals", &"bag", &"feed", &"dismiss", &"rename"], "compsognathus radial %s" % [radial.ids()])
	await _shot("radial_compy")
	# Space with the mouse resting on a segment rolls; it does not fire the segment.
	var mm := InputEventMouseMotion.new()
	mm.position = get_viewport().get_final_transform() * radial.segment_center(radial.ids().find(&"dismiss"))
	mm.global_position = mm.position
	Input.parse_input_event(mm)
	await _frames(2)
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	await _frames(2)
	var space_up := space.duplicate() as InputEventKey
	space_up.pressed = false
	Input.parse_input_event(space_up)
	await _frames(2)
	_check(radial.visible and compy.pet_record.summoned, "Space over Dismiss does not dismiss (ring open %s)" % radial.visible)
	await _tap_screen(Vector2(40, get_viewport().get_visible_rect().size.y * 0.5))
	_check(not radial.visible and not _player.nav_active, "tap outside closes and does not walk")
	_player.pets.dismiss(compy)  # later taps on REX must not land on it
	# Mid-fight: the ring opens on the pet, the hunt goes on, and creature plates keep off the ring.
	var wild := (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate() as Creature
	add_child(wild)
	wild.spawn(Data.creature(&"protoceratops"))
	wild.global_position = _player.global_position + Vector3(-2.5, 0.0, 1.5)
	wild.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)
	_player.hunt.start(wild)
	await get_tree().create_timer(0.5).timeout
	await _tap_pet(rex)
	await _frames(4)
	var clash := false
	for r in _plate_pills():
		clash = clash or r.intersects(radial.ring_rect())
	_check(radial.visible and _player.hunt.target == wild and not clash, "pet tap mid-fight: ring open %s, hunt kept %s, no plate on the ring %s" % [radial.visible, _player.hunt.target == wild, not clash])
	# HUD hexes the ring or a label covers are faded while it is open, and only those.
	var shown_under: Array[String] = []
	var faded: Array[String] = []
	for c in _hud_controls():
		var r := c.get_global_rect()
		if c is HexButton:
			r = (c as HexButton).hex_rect()
		if c.modulate.a < 0.05:
			faded.append(_name_of(c))
		elif radial.covers(r):
			shown_under.append(_name_of(c))
	_check(shown_under.is_empty(), "no HUD hex shows under the ring (faded %s, still shown %s)" % [faded, shown_under])
	await _shot("combat_pet_tap")
	await _tap_screen(Vector2(40, get_viewport().get_visible_rect().size.y * 0.5))
	var still_faded: Array[String] = []
	for c in _hud_controls():
		if c.modulate.a < 0.05:
			still_faded.append(_name_of(c))
	_check(still_faded.is_empty(), "closing the ring brings the hexes back (%s)" % [still_faded])
	_player.hunt.stop()
	_player.clear_nav()
	wild.queue_free()
	await _frames(3)
	# Animals menu on REX.
	await _tap_pet(rex)
	await _tap_segment(&"animals")
	await _frames(4)
	var screen := _hud.find_child("AnimalScreen", true, false) as AnimalScreen
	_check(screen != null and screen.visible and screen.selected == _player.bonded.find(rex.pet_record), "Animals opens on REX")
	await _shot("animals_screen")
	print("[petradial] %s" % ("PASS" if _fails.is_empty() else "FAIL %s" % [_fails]))
	get_tree().quit(0 if _fails.is_empty() else 1)
