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
