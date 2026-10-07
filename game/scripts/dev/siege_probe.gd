extends Node
func run(host: Node) -> void:
	print("[siege] seeded ammunition/build fixture, real AI retaliation; not earned progression")
	get_window().size = Vector2i(960,600)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	await get_tree().create_timer(1.0).timeout
	for node in get_tree().root.find_children("CharacterCreation", "CharacterCreation", true, false): node.queue_free()
	get_tree().paused = false
	World.home_terrain = &"meadow"
	World.load_island(host, &"home_grassland", Vector3(0,1,12), false)
	print("[siege] home-loaded")
	await get_tree().create_timer(0.5).timeout
	print("[siege] timer-done")
	var player := get_tree().get_first_node_in_group("player") as Player
	for cr in get_tree().get_nodes_in_group("creatures"): cr.queue_free()
	player.inventory.add(ItemStack.make(&"catapult_kit",1))
	player.inventory.add(ItemStack.make(&"stone_shot",5))
	player.inventory.add(ItemStack.make(&"toxin_pot",2))
	var grid := World.runtime.get("build_grid") as BuildGrid
	var built := false
	for x in range(-8,9):
		for z in range(-8,9):
			var cell := Vector2i(x,z)
			player.global_position = grid.placement_transform(&"catapult",cell,0).origin+Vector3(0,1,3)
			player.placer.begin(&"catapult")
			player.placer.cell = cell
			if player.placer.confirm(player):
				built = true
				break
		if built: break
	print("[siege] built=%s kit=%d" % [built,player.inventory.count_of(&"catapult_kit")])
	if not built: get_tree().quit(1); return
	var platform := get_tree().get_first_node_in_group("catapult") as FieldCatapult
	player.placer.cancel()
	player.global_position = platform.global_position+Vector3(2.5,0.5,0)
	var sp := Spawner.new()
	sp.species = &"protoceratops"
	sp.count = 1
	sp.radius = 0.1
	sp.position = platform.global_position+Vector3(0,0,10)
	World.runtime.add_child(sp)
	var victim: Creature = sp.spawn_now()[0]
	victim.reset_physics_interpolation()
	victim.genetics = CreatureGenetics.from_dict({})
	victim.health.setup(victim.def.hp)
	victim.set_physics_process(false)
	victim.brain.set_physics_process(false)
	player.hunt.start(victim)
	player.hunt.hold = true
	player.hunt.auto = false
	get_window().size = Vector2i(960,600)
	await get_tree().create_timer(0.3).timeout
	RenderingServer.force_draw()
	if "--siege-visual" in OS.get_cmdline_user_args(): get_viewport().get_texture().get_image().save_png("user://siege-aim.png")
	var hp := victim.health.hp
	var hud := get_tree().root.find_child("HuntHud",true,false) as HuntHud
	if hud == null:
		hud = HuntHud.new()
		hud.name = "HuntHud"
		host.get_node("UI").add_child(hud)
		hud.bind(player)
	hud._on_skill(&"net")
	print("[siege] fire ammo=%d reload=%.1f target-platform=%s" % [player.inventory.count_of(&"stone_shot"),platform.reload_left,victim.brain.attack_target==platform])
	print("[siege] reload-refuse=%s" % not platform.fire(player,victim))
	await get_tree().create_timer(0.4).timeout
	RenderingServer.force_draw()
	if "--siege-visual" in OS.get_cmdline_user_args(): get_viewport().get_texture().get_image().save_png("user://siege-shot.png")
	await get_tree().create_timer(1.4).timeout
	print("[siege] stone-damage=%.1f" % (hp-victim.health.hp))
	platform.reload_left = 0
	hud._on_skill(&"tackle")
	await get_tree().create_timer(2.0).timeout
	print("[siege] poisoned=%s toxin-ammo=%d target-platform=%s" % [victim.statuses.has(&"poisoned_target"),player.inventory.count_of(&"toxin_pot"),victim.brain.attack_target==platform])
	platform.reload_left = 0
	var ammo_before := player.inventory.count_of(&"stone_shot")
	var spot := victim.global_position
	victim.global_position = platform.global_position+Vector3(0,0,7)
	print("[siege] min-range-refuse=%s no-spend=%s" % [not platform.fire(player,victim),player.inventory.count_of(&"stone_shot")==ammo_before])
	victim.global_position = platform.global_position+Vector3(0,0,25)
	print("[siege] max-range-refuse=%s" % not platform.fire(player,victim))
	victim.global_position = spot
	player.global_position += Vector3(5,0,0)
	print("[siege] operator-refuse=%s" % not platform.fire(player,victim))
	player.global_position -= Vector3(5,0,0)
	var row := platform.to_dict()
	var platform_id := platform.get_instance_id()
	var restored := (load("res://scripts/core/save_game.gd") as GDScript)._spawn_building(row) as FieldCatapult
	print("[siege] save hp=%.1f reload=%.1f" % [restored.hp,restored.reload_left])
	restored.free()
	victim.set_physics_process(true)
	victim.brain.set_physics_process(true)
	# Real AI from ten metres: no forced contact, health or attack events.
	for k in range(25):
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(platform):
			print("[siege] destroyed-after=%ds occupancy-cleared=%s" % [k+1,not grid._node_cells.has(platform_id)])
			RenderingServer.force_draw()
			if "--siege-visual" in OS.get_cmdline_user_args(): get_viewport().get_texture().get_image().save_png("user://siege-destroyed.png")
			break
		if k == 5:
			RenderingServer.force_draw()
			if "--siege-visual" in OS.get_cmdline_user_args(): get_viewport().get_texture().get_image().save_png("user://siege-hit.png")
		print("[siege] t=%ds platformHP=%.1f distance=%.1f state=%s clip=%s" % [k+1,platform.hp,victim.global_position.distance_to(platform.global_position),victim.brain.state,victim.anim.current_clip])
	get_tree().quit(0)
