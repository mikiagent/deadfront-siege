extends Node3D
## Worn-bag look check: the survivor wearing basic_bag and advanced_backpack, from behind and
## three-quarter, on foot and riding a T. rex, at the game camera and close-up. One 2x2 sheet per
## bag and pose (game behind, game 3/4, close behind, close 3/4).
##   godot --path game --resolution 1600x900 -- --lab=backpack_lab --shot-dir=/tmp/backpacks
## Prints "[backpacklab] sheet <path>" per sheet and "[backpacklab] DONE".
var player: Player
var game_cam: Camera3D
var close_cam: Camera3D
var shot_dir := "/tmp/dfs-backpacks"
const BAGS: Array[StringName] = [&"basic_bag", &"advanced_backpack"]
const TINT := "#6b5a3e" # raptor hide, as a crafted bag carries it

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			shot_dir = a.substr(11)
	var kit := LabKit.build(self, 60.0)
	player = kit["player"]
	game_cam = kit["cam"]
	Game.debug_overlay = false
	(kit["ui"] as CanvasLayer).visible = false # the HUD would cover the pack
	close_cam = Camera3D.new()
	close_cam.fov = 30.0
	add_child(close_cam)
	DirAccess.make_dir_recursive_absolute(shot_dir)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	var rex: Creature = null
	for mounted in [false, true]:
		if mounted:
			rex = _spawn_rex()
			await get_tree().create_timer(0.4).timeout
			rex.set_physics_process(false)
			player.mount(rex)
		for bag in BAGS:
			player.inventory.add(ItemStack.make(bag, 1, {"tint": TINT}, 10))
			player.inventory.equip_at(player.inventory.find_first(bag), &"accessory2")
			var tiles: Array[Image] = []
			for close in [false, true]:
				for yaw in [0.0, 45.0]:
					tiles.append(await _shot(rex if mounted else null, close, yaw))
			_sheet(tiles, "%s_%s" % [bag, "mounted" if mounted else "on_foot"])
	print("[backpacklab] DONE")
	get_tree().quit(0)

func _spawn_rex() -> Creature:
	var def := Data.creature(&"tyrannosaurus")
	var rec := PetRecord.from_def(def, &"A")
	rec.fit_saddle()  # SADDLES: riding needs one
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	player.get_parent().add_child(c)
	c.is_pet = true
	c.pet_record = rec
	c.spawn(def, rec.variant)
	c.global_position = player.global_position + Vector3(0, 0.2, 0)
	return c

## Turn the body so its back faces the game camera (yaw 0) or 45 degrees past it, then shoot.
func _shot(rex: Creature, close: bool, yaw_deg: float) -> Image:
	var body: Node3D = rex if rex else player.visual
	var to_cam := game_cam.global_position - body.global_position
	body.global_rotation.y = atan2(to_cam.x, to_cam.z) + deg_to_rad(yaw_deg) # -Z (the face) points away
	game_cam.size = IsoCamera.MAX_SIZE if rex else IsoCamera.MIN_SIZE # the closest game zoom that frames her
	await get_tree().create_timer(0.6).timeout
	if close:
		var focus := player.rig.global_position + Vector3(0, 1.25, 0)
		if rex:
			focus = player.rig.global_position + Vector3(0, 0.9, 0)
		var side := Vector3(to_cam.x, 0.0, to_cam.z).normalized() # from the game camera's side, so 3/4 stays 3/4
		close_cam.look_at_from_position(focus + side * 3.4 + Vector3(0, 0.7, 0), focus)
		close_cam.current = true
	else:
		game_cam.current = true
	for _i in 3: # a camera switch takes a frame or two to land
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func _sheet(tiles: Array[Image], stage: String) -> void:
	var w := 800
	var h := 450
	var out := Image.create(w * 2, h * 2, false, Image.FORMAT_RGB8)
	for i in tiles.size():
		var t := tiles[i]
		t.convert(Image.FORMAT_RGB8)
		t.resize(w, h, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(t, Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	var path := "%s/%s.png" % [shot_dir, stage]
	out.save_png(path)
	print("[backpacklab] sheet %s" % path)
