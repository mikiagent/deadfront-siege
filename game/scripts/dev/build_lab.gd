extends Node3D
## Headless placement demo for M8b acceptance.

var _player: Player
var _cam: IsoCamera

func _ready() -> void:
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 12), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	_cam._target = _player
	_cam.size = 26.0
	_cam.distance = 22.0
	_cam._snap()
	_give_build_kits()
	print("[boot] lab=build_lab")
	if Game.shot_path != "":
		call_deferred("_stage_ghost_for_shot")
	if DisplayServer.get_name() == "headless":
		call_deferred("_demo")

func _give_build_kits() -> void:
	LabKit.give(_player, &"tent_kit", 1)
	LabKit.give(_player, &"basket_kit", 3)
	LabKit.give(_player, &"fence_kit", 3)
	LabKit.give(_player, &"gate_kit", 1)

func _demo() -> void:
	await _await_nav_ready()
	var grid := _grid()
	if grid == null:
		get_tree().quit(1)
		return
	var anchor := _find_anchor_cell()
	_player.global_position = BuildGrid.tile_centre(anchor + Vector2i(3, 3), World.runtime) + Vector3(0.0, 1.0, 0.0)
	_place(&"tent", anchor)
	_place(&"basket", anchor + Vector2i(4, 0))
	var fence0 := anchor + Vector2i(0, 4)
	_place(&"fence", fence0)
	_place(&"fence", fence0 + Vector2i(2, 0))
	_place(&"fence", fence0 + Vector2i(4, 0), 1)
	_place(&"gate", fence0 + Vector2i(6, 0), 3)
	_place(&"basket", anchor + Vector2i(4, 0)) # overlap
	var water_cell := _find_water_probe_cell(anchor)
	_player.global_position = BuildGrid.tile_centre(water_cell + Vector2i(-4, 0), World.runtime) + Vector3(0.0, 1.0, 0.0)
	_place(&"basket", water_cell)
	var SG := load("res://scripts/core/save_game.gd") as GDScript
	SG.save_now()
	SG.load_now(self)
	await get_tree().process_frame
	var restored := 0
	for n in World.runtime.get_tree().get_nodes_in_group("placed_building"):
		var keep := bool(n.get("persist_building")) if n and n.has_method("get") else true
		if keep and not bool(n.get("is_cargo")):
			restored += 1
	print("[build] restored %d" % restored)
	get_tree().quit(0)

func _stage_ghost_for_shot() -> void:
	var grid := _grid()
	if grid == null:
		return
	var anchor := _find_anchor_cell()
	_player.global_position = BuildGrid.tile_centre(anchor + Vector2i(3, 3), World.runtime) + Vector3(0.0, 1.0, 0.0)
	var ghost_at := BuildGrid.tile_centre(anchor, World.runtime)
	Game.pointer = _cam.unproject_position(ghost_at)
	_player.placer.begin(&"tent")
	_cam._snap()

func _place(kind: StringName, at: Vector2i, rot: int = 0) -> void:
	_player.placer.begin(kind)
	_player.placer.cell = at
	_player.placer.rot_step = rot
	_player.placer.confirm(_player)

func _find_anchor_cell() -> Vector2i:
	var grid := _grid()
	if grid == null:
		return Vector2i(6, 10)
	var around := BuildGrid.tile_of(_player.global_position)
	for dz in range(-8, 9):
		for dx in range(-8, 9):
			var c := around + Vector2i(dx, dz)
			if grid.can_place(&"tent", c, 0) != "":
				continue
			if grid.can_place(&"basket", c + Vector2i(4, 0), 0) != "":
				continue
			if grid.can_place(&"fence", c + Vector2i(0, 4), 0) != "":
				continue
			if grid.can_place(&"fence", c + Vector2i(2, 4), 0) != "":
				continue
			if grid.can_place(&"fence", c + Vector2i(4, 4), 0) != "":
				continue
			if grid.can_place(&"gate", c + Vector2i(6, 4), 0) != "":
				continue
			return c
	return around + Vector2i(4, 2)

func _find_water_probe_cell(anchor: Vector2i) -> Vector2i:
	if World.runtime == null:
		return anchor + Vector2i(10, 0)
	var land := int(World.runtime.land_radius())
	for ring in range(maxi(10, land - 4), land + 10):
		var water := Vector2i(ring, 0)
		var dry := Vector2i(ring - 4, 0)
		var water_ok: bool = World.runtime.spawn_ok(BuildGrid.tile_centre(water, World.runtime), false)
		var dry_ok: bool = World.runtime.spawn_ok(BuildGrid.tile_centre(dry, World.runtime), false)
		if not water_ok and dry_ok:
			return water
	return anchor + Vector2i(land, 0)

func _grid() -> BuildGrid:
	if World.runtime == null:
		return null
	var g: Variant = World.runtime.get("build_grid")
	return g as BuildGrid if g is BuildGrid else null

func _await_nav_ready() -> void:
	while true:
		var map: RID = RID()
		if _player and _player.get_world_3d():
			map = _player.get_world_3d().navigation_map
		if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
			return
		await get_tree().create_timer(0.1).timeout
