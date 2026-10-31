extends Node3D
## WORLDUI captures: floating creature bars over a compy, a zebraceratops and a triceratops, a rock's
## tag on its first visible frame, then walking up to the zebraceratops (top target bar, floating bar
## gone). Windowed, self-quitting, phone landscape by default:
## godot --path game --position 6000,3000 --resolution 1688x780 -- --lab=worldui_lab --shot-dir=DIR [--canvas=844x390] [--tag=after]

var _out := "user://worldui"
var _tag := "after"
var _player: Player
var _hud: HuntHud

func _ready() -> void:
	var canvas := Vector2i(844, 390)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
		elif a.begins_with("--canvas="):
			var wh := a.substr(9).split("x")
			canvas = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayMode.canvas_override = canvas
	DisplayMode.fit(get_tree().root)
	var kit := LabKit.build(self, 80.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	_run.call_deferred()

func _spawn(species: StringName, at: Vector3) -> Creature:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	c.position = at
	add_child(c)
	c.spawn(Data.creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.rotation.y = 0.9
	return c

func _run() -> void:
	Game.debug_overlay = false
	Game.ensure_creature_plates()  # deferred: current_scene is not set yet in _ready
	await get_tree().create_timer(1.0).timeout
	var p := _player.global_position
	# Iso camera (yaw 45): screen-right is +x-z, screen-down +x+z. All three past the 6 m close range.
	var compy := _spawn(&"compsognathus", p + Vector3(-3.5, -1.0, 6.4))
	var zebra := _spawn(&"zebraceratops", p + Vector3(7.1, -1.0, -2.8))
	var trike := _spawn(&"triceratops", p + Vector3(-1.6, -1.0, -7.4))
	for c in [compy, zebra, trike]:
		c.last_damaged_s = float(Time.get_ticks_msec()) * 0.001 + 60.0  # show every bar
	zebra.statuses.apply(&"bleed")
	var rock: Node3D = preload("res://scenes/world/harvest_node.tscn").instantiate()
	add_child(rock)
	rock.position = p + Vector3(-3.0, -1.0, 2.0)
	rock.setup(&"lab_rock", &"stone", 1, 1, {"level": 1}, &"none", Color.GRAY, 1.2, 8.0, "Rock")
	await get_tree().create_timer(1.5).timeout
	await _shot("bars")
	# Walk up to the zebraceratops: in close range the top bar takes it and its floating bar fades.
	_player.global_position = zebra.global_position + Vector3(-2.5, 1.0, 1.5)
	await get_tree().create_timer(1.2).timeout
	await _shot("close")
	# The rock's tag, walking in from 9 m one step a frame: shoot its first visible frame.
	for c in [compy, zebra, trike]:
		c.queue_free()
	var down := Vector3(1.0, 0.0, 1.0).normalized()  # toward the camera: the rock stands above her on screen
	_player.global_position = rock.global_position + down * 9.0 + Vector3(0, 1.0, 0)
	await get_tree().create_timer(0.6).timeout
	for i in 40:
		_player.global_position -= down * 0.1
		await get_tree().process_frame
		var hit := false
		for row: Dictionary in HudPills.last_drawn:
			if row["node"] == rock and float(row.get("a", 1.0)) > 0.02:
				hit = true
		if hit:
			break
	await _shot("tag_first_frame")
	await get_tree().create_timer(0.5).timeout
	await _shot("tag_settled")
	print("[worldui] DONE")
	get_tree().quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	var path := _out.path_join("%s_%s.png" % [_tag, name])
	img.save_png(path)
	print("[worldui] shot %s" % path)
