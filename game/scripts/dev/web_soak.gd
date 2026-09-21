extends Node
## Deterministic in-engine route used by tools/production_soak.mjs.
## It drives real menu and travel methods while the browser harness watches pixels and logs.

func run(host: Node) -> void:
	print("[soak] start")
	await get_tree().create_timer(1.0).timeout
	for node in get_tree().get_nodes_in_group("character_creation"):
		node.queue_free()
	World.home_terrain = &"meadow"
	World.t_stones = maxi(World.t_stones, 20)
	World.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await _checkpoint("world-entered")

	# Real input acceptance for the two-stage CraftStation flow. Project the live bench
	# and generated CRAFT hex to screen, then feed touch press/release pairs through Godot.
	var player := get_tree().get_first_node_in_group("player") as Player
	var bench := get_tree().get_first_node_in_group("workbench") as Node3D
	if player == null or bench == null:
		_fail("station acceptance missing player or workbench")
		return
	var cam := get_viewport().get_camera_3d()
	var bench_screen := cam.unproject_position(bench.global_position + Vector3(0, 0.5, 0))
	print("[soak] station screen=%s bench=%s player=%s" % [bench_screen, bench.global_position, player.global_position])
	var kind := player.debug_tap_screen(bench_screen)
	print("[soak] station tap kind=%s menu=%s ring=%s ring_visible=%s" % [kind, player.station_craft.menu.visible, player.station_craft.menu._ring3d, player.station_craft.menu._ring3d.visible if player.station_craft.menu._ring3d else false])
	await get_tree().create_timer(0.75).timeout
	print("[soak] station postwait menu=%s ring_visible=%s nav=%s dist=%.2f" % [player.station_craft.menu.visible, player.station_craft.menu._ring3d.visible if player.station_craft.menu._ring3d else false, player.nav_active, player.global_position.distance_to(bench.global_position)])
	if player.station_craft == null or not player.station_craft.menu.visible \
			or player.station_craft.menu._ring3d == null or not player.station_craft.menu._ring3d.visible:
		_fail("first workbench touch did not open ring")
		return
	await _checkpoint("station-ring-open")
	var craft_button := player.station_craft.menu._buttons[0] as Control
	_touch(craft_button.get_global_rect().get_center())
	await get_tree().create_timer(0.75).timeout
	if player.craft_ui == null or not player.craft_ui.visible:
		_fail("second CRAFT touch did not open sheet")
		return
	await _checkpoint("station-craft-open")
	player.craft_ui.hide()
	_touch(cam.unproject_position(bench.global_position + Vector3(0, 0.5, 0)))
	await get_tree().create_timer(0.75).timeout
	player.global_position = bench.global_position + Vector3(8, 0, 0)
	await get_tree().create_timer(0.75).timeout
	if player.station_craft.menu.visible:
		_fail("walking away did not dismiss station ring")
		return
	await _checkpoint("station-walkaway-dismissed")

	var world_ui = (load("res://scripts/ui/world_ui.gd") as GDScript).ensure()
	world_ui.show_harbour()
	await _checkpoint("harbour-open")
	world_ui.hide_all()
	await _checkpoint("harbour-closed")

	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		_fail("HUD not found")
		return
	hud._toggle_sheet(&"pets")
	await _checkpoint("pets-open")
	hud._close_sheet()
	hud._toggle_sheet(&"build")
	await _checkpoint("build-open")
	hud._close_sheet()
	await _checkpoint("build-closed")

	World.travel(&"temperate_25", &"sail")
	await World.island_changed
	await _checkpoint("travelled")
	World.travel(&"home_grassland", &"harbour_home")
	await World.island_changed
	await _checkpoint("returned-home")
	print("[soak] PASS")

func _checkpoint(name: String) -> void:
	await get_tree().create_timer(0.75).timeout
	print("[soak] checkpoint %s" % name)

func _fail(message: String) -> void:
	push_error("[soak] FAIL %s" % message)
	print("[soak] FAIL %s" % message)

func _touch(pos: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 7
	down.position = pos
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventScreenTouch.new()
	up.index = 7
	up.position = pos
	up.pressed = false
	Input.parse_input_event(up)
