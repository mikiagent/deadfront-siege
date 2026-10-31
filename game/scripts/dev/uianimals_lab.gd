extends Node3D
## UIANIMALS shot lab: E1 Animals, F2 World Atlas and the Harbour sheet in the running build, with a
## small pack (a raptor out, a zebraceratops resting, a compy down) and a captured animal in the bag.
## Windowed: --resolution 1600x900 -- --lab=uianimals_lab --shot-dir=DIR
##           --resolution 1688x780 -- --lab=uianimals_lab --shot-dir=DIR --canvas=844x390
## Prints "[uianimals] shot <path>" per screen, then "[uianimals] DONE".

var _out := ""
var _player: Player
var _hud: HuntHud

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("uianimals")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--canvas="):
			var wh := a.substr(9).split("x")
			DisplayMode.canvas_override = Vector2i(int(wh[0]), int(wh[1]))
			DisplayMode.fit(get_tree().root)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.player_name = "Milan"
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _pet(species: StringName, nm: String, nature: StringName, level: int) -> PetRecord:
	var rec := PetRecord.from_def(Data.creature(species), &"A")
	rec.name = nm
	rec.nature = nature
	rec.level = level
	rec.xp = PetRecord.xp_to_next(level) * 0.27
	_player.bonded.append(rec)
	return rec

func _run() -> void:
	await _wait(2.5)
	var rex := _pet(&"velociraptor", "Rex", &"timid", 1)
	var bramble := _pet(&"zebraceratops", "Bramble", &"docile", 13)
	bramble.hunger = bramble.hunger_max * 0.2
	_pet(&"compsognathus", "", &"brave", 4).start_respawn()
	var out := _player.pets.summon(0)
	if out:
		out.hunger = out.hunger_max * 0.64
	_player.inventory.add(ItemStack.make(&"raw_meat", 1))
	_player.inventory.add(ItemStack.make(&"captured_animal", 1, {"species": "velociraptor"}))
	_hud.open_animals(rex)
	await _wait(1.5)
	await _shot("e1_animals")
	_hud.get("_animal_screen").call("close_screen")
	_hud.open_map()
	await _wait(0.8)
	await _shot("f2_world_atlas")
	_hud.open_map()
	var ui = (load("res://scripts/ui/world_ui.gd") as GDScript).ensure()
	World.t_stones = 20
	ui.show_harbour()
	await _wait(0.8)
	await _shot("f2_harbour")
	ui.hide_all()
	print("[uianimals] DONE")
	get_tree().quit(0)

func _shot(n: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		print("[uianimals] no pixels for %s (run windowed)" % n)
		return
	var path := _out.path_join("%s_%dx%d.png" % [n, get_tree().root.size.x, get_tree().root.size.y])
	img.save_png(path)
	print("[uianimals] shot %s" % path)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
