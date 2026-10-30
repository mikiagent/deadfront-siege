extends Node3D
## TRIBE M2a screenshot on the real home island: a member assigned a craft at a workbench, hammering it
## with the job plate over its head, the survivor standing by. One PNG into --shot-dir.
## Windowed: Godot --path game --resolution 1600x900 --position 6000,3000 -- --lab=tribework_lab --shot-dir=DIR

var _out := ""
var _player: Player

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("tribework")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self)
	_player = kit["player"]
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	Game.time_of_day = 0.4
	get_tree().root.gui_disable_input = true  # a windowed capture must not take the desk's stray input
	_player.set_process_input(false)
	_player.set_process_unhandled_input(false)
	_run.call_deferred()

func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, World.runtime.surface_y(x, z), z)

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	Tribe.reset()
	Tribe.seeded = true
	var camp: Vector3 = World.runtime.get("_camp_pos")
	var at := _ground(camp.x - 4.0, camp.z + 4.0)
	var wb := CraftStation.make(&"workbench")
	World.runtime.add_child(wb)
	wb.global_position = at
	var basket: Node3D = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"basket")
	World.runtime.add_child(basket)
	basket.global_position = _ground(at.x + 2.2, at.z - 0.6)
	var r := Tribe.make_recruit(Tribe.rng)
	r.name = "Joss"
	r.pos = [at.x - 0.4, at.y + 1.05, at.z + 1.9]  # the camera side of the bench
	Tribe.members.append(r)
	World.pioneer_crafts["work_axe"] = true
	for id in [&"stone", &"branch", &"twine"]:
		_player.inventory.add(ItemStack.make(id, 1, {}, 1))
	var why := TribeWork.assign_craft(_player, r, wb, &"work_axe")
	r.job["seconds"] = 60.0  # long enough to catch mid-swing
	print("[tribework_lab] assign '%s'" % why)
	_player.global_position = _ground(at.x - 3.0, at.z + 3.2) + Vector3(0, 1.0, 0)
	_player.face_world(at)
	await get_tree().create_timer(4.0).timeout
	var body := _player.tribe.body_of(r)
	print("[tribework_lab] state=%s clip=%s plate='%s'" % [body.state if body else &"none", body._clip if body else &"", body.plate.text.replace("\n", " / ") if body else ""])
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var v := get_tree().root.get_visible_rect().size
	var path := _out.path_join("tribework_hammer_%dx%d.png" % [int(v.x), int(v.y)])
	get_tree().root.get_texture().get_image().save_png(path)
	print("[tribework_lab] shot %s" % path)
	get_tree().quit(0)
