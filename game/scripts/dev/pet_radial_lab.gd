extends Node3D
## Pet radial lab (spec 23): home island, a bonded zebraceratops named REX and a compsognathus, every
## step through real pointer events. Shots: pet_tap (the menu a tap opens), rename, rename_refused,
## radial_renamed, radial_mounted, radial_compy, animals_screen. Prints "[petradial] PASS" and exits 0,
## or FAIL lines and exit 1. With the old pet hex menu it shoots pet_tap and stops.
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

func _summon(species: StringName, nm: String) -> Creature:
	var rec := PetRecord.from_def(Data.creature(species), &"A")
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
	_check(radial.visible and radial.ids() == [&"animals", &"bag", &"feed", &"ride", &"dismiss", &"rename"], "REX radial %s" % [radial.ids()])
	# Rename: refused with the character-name reason, then accepted.
	await _tap_segment(&"rename")
	var dialog := _player.pets.get("rename_dialog") as PetRenameDialog
	_check(dialog != null and dialog.visible, "Rename opens the name dialog")
	await _shot("rename")
	(dialog.find_child("NameField", true, false) as LineEdit).text = "R!"
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
	await _tap_screen(Vector2(40, get_viewport().get_visible_rect().size.y * 0.5))
	_check(not radial.visible and not _player.nav_active, "tap outside closes and does not walk")
	# Animals menu on REX.
	await _tap_pet(rex)
	await _tap_segment(&"animals")
	await _frames(4)
	var screen := _hud.find_child("AnimalScreen", true, false) as AnimalScreen
	_check(screen != null and screen.visible and screen.selected == _player.bonded.find(rex.pet_record), "Animals opens on REX")
	await _shot("animals_screen")
	print("[petradial] %s" % ("PASS" if _fails.is_empty() else "FAIL %s" % [_fails]))
	get_tree().quit(0 if _fails.is_empty() else 1)
