class_name LabKit
extends RefCounted
## Shared floor + nav + player + camera + HUD for scenes/dev/*_lab.tscn.

static func build(host: Node3D, size: float = 80.0) -> Dictionary:
	# The game's own lighting (temperate profile), so lab shots match the islands (an island load
	# replaces it, so no handle is returned); the old kit
	# added a second 1.2 sun and 0.7 flat ambient on top of the main scene's and blew out.
	WorldLighting.install(host, "temperate")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tod="):  # start at this time of day (0.9 = night) for day/night shots
			Game.time_of_day = fposmod(float(a.substr(6)), 1.0)
	var nav := NavigationRegion3D.new()
	nav.name = "Nav"
	var nmesh := NavigationMesh.new()
	nmesh.agent_radius = 0.5
	nmesh.agent_max_climb = 0.5
	nmesh.agent_max_slope = 45.0
	# Owner: "the test scene doesn't have navigable paths". The bake read the floor's render mesh, which a
	# headless or GPU-readback-less run returns empty, and only the floor: lab crates were never carved,
	# so a ground tap routed into them or had no path. Bake every static collider under the lab instead
	# (bake() again after adding props).
	nmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nmesh.geometry_source_group_name = &"lab_nav"
	host.add_to_group(&"lab_nav")
	nav.navigation_mesh = nmesh
	host.add_child(nav)
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	var fmesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size, 1, size)
	fmesh.mesh = box
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.36, 0.5, 0.28)
	fmesh.material_override = fmat
	floor.add_child(fmesh)
	var fshape := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(size, 1, size)
	fshape.shape = bshape
	floor.add_child(fshape)
	floor.position.y = -0.5
	nav.add_child(floor)
	var player: Player = preload("res://scenes/player/player.tscn").instantiate()
	player.position = Vector3(0, 1, 0)
	host.add_child(player)
	var cam := IsoCamera.new()
	cam.name = "IsoCamera"
	cam.current = true
	host.add_child(cam)
	cam.target_path = cam.get_path_to(player)
	cam._target = player
	cam._snap()
	var ui := CanvasLayer.new()
	ui.name = "UI"
	host.add_child(ui)
	var inv_ui: InventoryUI = preload("res://scenes/ui/inventory.tscn").instantiate()
	ui.add_child(inv_ui)
	player.ui = inv_ui
	inv_ui.bind(player.inventory, player)
	var craft = preload("res://scenes/ui/craft.tscn").instantiate()
	ui.add_child(craft)
	player.craft_ui = craft
	craft.bind(player)
	var hud := HuntHud.new()
	hud.bind(player)
	ui.add_child(hud)
	var skills := SkillDebug.new()
	ui.add_child(skills)
	(load("res://scripts/ui/world_ui.gd") as GDScript).instance_on(host)
	var debug := Label.new()
	debug.name = "DebugLabel"
	debug.position = Vector2(12, 8)
	debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(debug)
	if player.station_craft:
		player.station_craft.reparent_ui(ui)
	if player.eat_session:
		player.eat_session.reparent_ui(ui)
	nav.bake_navigation_mesh(false)
	return {"player": player, "nav": nav, "ui": ui, "debug": debug, "cam": cam}

## Re-bake the lab's navigation mesh after static props were added (they carve it).
static func bake(host: Node3D) -> void:
	var nav := host.get_node_or_null("Nav") as NavigationRegion3D
	if nav:
		nav.bake_navigation_mesh(false)

static func give(player: Player, id: StringName, n: int, attrs: Dictionary = {}) -> void:
	player.inventory.add(ItemStack.make(id, n, attrs))
