extends Node3D
## TARGETUI lab (spec 23): on the home island a real mouse tap selects a wild protoceratops (plate,
## ring, red swords hex), a real click on the swords starts the fight, a raptor already on the
## survivor is selected with its aggro ring showing, and a tap on your own pet shows its menu and no
## swords. Shoots each beat; prints "[targetui] PASS" and exits 0, or exits 1 on any failed check.
## Run: Godot --path game --resolution 1600x900 -- --lab=targetui_lab --shot-dir=DIR

var _out := ""
var _player: Player
var _hud: HuntHud
var _cam: Camera3D
var _failed := 0

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("targetui")
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
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _check(ok: bool, msg: String) -> void:
	if not ok:
		_failed += 1
	print("[targetui] %s %s" % ["ok" if ok else "FAIL", msg])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join("%s_%dx%d.png" % [label, img.get_width(), img.get_height()])
	img.save_png(path)
	print("[targetui] shot %s" % path)

## A real left click at a viewport point, through Input like a mouse or finger.
func _click(vp: Vector2) -> void:
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
	await _frames(3)

func _spawn(species: StringName, offset: Vector3) -> Creature:
	var sp := Spawner.new()
	sp.species = species
	sp.count = 1
	sp.radius = 0.5
	sp.as_pack = false
	sp.position = _player.global_position + offset
	World.runtime.add_child(sp)
	var made := sp.spawn_now()
	if made.is_empty():
		return null
	var c: Creature = made[0]
	c.global_position = _player.global_position + offset
	return c

func _swords() -> TargetSwordsHex:
	return _hud.get_node_or_null("TargetSwords") as TargetSwordsHex

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	print("[targetui] window=%s logical=%s" % [get_tree().root.size, get_viewport().get_visible_rect().size])
	# 1. Tap a wild protoceratops (real art; the wildsaurus is still a stand-in): selected, no fight.
	var wild := _spawn(&"protoceratops", Vector3(4.0, 0, 1.5))
	_check(wild != null, "protoceratops spawned")
	if wild == null:
		get_tree().quit(1)
		return
	wild.brain.process_mode = Node.PROCESS_MODE_DISABLED  # stands for the shots
	await get_tree().create_timer(1.0).timeout
	var at := _cam.unproject_position(wild.global_position + Vector3(0, wild.def.height_meters * 0.5, 0))
	await _click(at)
	if _player.controls.selection.current() != wild:
		Game.pointer = at
		var hit := _player.controls.ray()
		print("[targetui] tap at %s hit %s picked %s hovered %s blocked %s" % [at, hit.get("collider"), _player.controls.pick_interactable(hit) if not hit.is_empty() else null, get_viewport().gui_get_hovered_control(), _player.controls.tap_blocked()])
	_check(_player.controls.selection.current() == wild and _player.hunt.target == null, "tap selects the animal, no hunt (hunt %s)" % [_player.hunt.target])
	_check(_swords() != null and _swords().is_visible_in_tree(), "the red swords hex shows beside it")
	await _frames(4)
	await _shot("select")
	# 2. Click the swords: the fight starts.
	if _swords() and _swords().is_visible_in_tree():
		await _click(_swords().get_global_rect().get_center())
	_check(_player.hunt.target == wild, "the swords hex starts the hunt on it")
	await get_tree().create_timer(0.6).timeout
	await _shot("engaged")
	_player.hunt.stop()
	_player.clear_nav()
	wild.queue_free()
	await _frames(3)
	_check(_player.controls.selection.current() == null and not _swords().is_visible_in_tree(), "a freed selection clears the swords")
	# 3. A raptor already on the survivor: its aggro ring and the select ring together.
	var raptor := _spawn(&"velociraptor", Vector3(-6.0, 0, 3.0))
	if raptor:
		raptor.brain.on_aggro(_player)
		await _frames(2)
		raptor.brain.process_mode = Node.PROCESS_MODE_DISABLED  # holds it in alert for the shot
		await _frames(10)
		await _click(_cam.unproject_position(raptor.global_position + Vector3(0, raptor.def.height_meters * 0.5, 0)))
		var ring := raptor.get_node_or_null("AggroRing") as Node3D
		_check(_player.controls.selection.current() == raptor and ring != null and ring.visible and raptor.get_node_or_null("SelectRing") != null,
			"a raptor on the survivor is selected with its aggro ring still shown")
		await _frames(4)
		await _shot("aggro_select")
		raptor.queue_free()
		await _frames(3)
	# 4. Your own pet: its menu, never the swords.
	var rec := PetRecord.from_def(Data.creature(&"zebraceratops"), &"A")
	rec.name = "REX"
	_player.bonded.append(rec)
	var pet := _player.pets.summon(_player.bonded.size() - 1)
	await get_tree().create_timer(2.0).timeout
	_player.clear_nav()
	await _click(_cam.unproject_position(pet.global_position + Vector3(0, 0.6, 0)))
	_check(_player.controls.selection.current() == null and not _swords().is_visible_in_tree() and _player.hunt.target == null,
		"a tap on your pet selects nothing and shows no swords")
	_check(_player.pets.menu != null and _player.pets.menu.visible, "a tap on your pet opens its menu")
	await _shot("pet_tap")
	print("[targetui] %s" % ("PASS" if _failed == 0 else "FAIL count=%d" % _failed))
	get_tree().quit(0 if _failed == 0 else 1)
