class_name LabKit
extends RefCounted
## Shared floor + nav + player + camera + HUD for scenes/dev/*_lab.tscn.

static func build(host: Node3D, size: float = 80.0) -> Dictionary:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.53, 0.68, 0.84)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.82, 0.86, 0.9)
	e.ambient_light_energy = 0.7
	env.environment = e
	host.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	sun.rotation_degrees = Vector3(-50, 30, 0)
	host.add_child(sun)
	var nav := NavigationRegion3D.new()
	nav.name = "Nav"
	var nmesh := NavigationMesh.new()
	nmesh.agent_radius = 0.35
	nmesh.agent_max_climb = 0.4
	nmesh.agent_max_slope = 45.0
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

static func give(player: Player, id: StringName, n: int, attrs: Dictionary = {}) -> void:
	player.inventory.add(ItemStack.make(id, n, attrs))
