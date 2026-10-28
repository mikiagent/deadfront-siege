extends Node3D
## TERRAINSMOOTH review shots: the home island at the game camera (default zoom) at four spots, plus
## a top-down island shot. Spots are found from the island's own maps:
##   camp           the camp centre
##   zone_border    a forest/meadow zone border 30+ m from camp
##   river_bank     dry ground 1 m from the river's waterline
##   beach          the sand by the harbour arrival
## Windowed: Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility]
##   res://scenes/dev/terrain_lab.tscn -- --lab=terrain_lab --shot-dir=DIR [--spots=camp,beach]
## Prints "[terrainlab] shot <path>" per PNG, then "[terrainlab] done".

const SETTLE_S := 1.4

var _out := ""
var _player: Player
var _cam: IsoCamera
var _rt: IslandRuntime
var _ui: CanvasLayer
var _only: PackedStringArray = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		if a.begins_with("--spots="):
			_only = a.substr(8).split(",", false)
	if _out == "":
		_out = OS.get_user_data_dir().path_join("terrain_lab")
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	_cam = kit["cam"]
	_ui = kit["ui"]
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	get_tree().create_timer(300.0).timeout.connect(func() -> void: get_tree().quit(2))
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_rt = World.runtime as IslandRuntime
	Game.time_of_day = 0.45
	_ui.visible = false
	var perf := get_node_or_null("/root/Game/PerfHud") as CanvasLayer
	if perf:
		perf.visible = false
	var spots := [
		["camp", _rt._camp_pos], ["zone_border", _zone_border()], ["river_bank", _river_bank()],
		["beach", _beach()], ["cliff", _cliff()],
	]
	for s in spots:
		if _only.is_empty() or str(s[0]) in _only:
			await _stand(str(s[0]), s[1])
	if _only.is_empty() or "top" in _only:
		await _top()
	print("[terrainlab] done")
	get_tree().quit(0)

func _stand(name: String, at: Vector3) -> void:
	_player.clear_nav()
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(at.x, _rt.surface_y(at.x, at.z) + 0.15, at.z)
	_player.reset_physics_interpolation()
	_cam._snap()
	await get_tree().create_timer(SETTLE_S).timeout
	print("[terrainlab] spot=%s pos=(%.1f, %.1f)" % [name, at.x, at.z])
	await _shot(name)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join("%s.png" % name)
	img.save_png(path)
	print("[terrainlab] shot %s" % path)

func _top() -> void:
	var top := Camera3D.new()
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.size = _rt._size * 0.62
	top.far = 400.0
	add_child(top)
	top.global_position = Vector3(0, 200, 0)
	top.rotation_degrees = Vector3(-90, 0, 0)
	top.current = true
	await get_tree().create_timer(1.0).timeout
	await _shot("top")
	_cam.current = true

## A forest tile with meadow 4 m away, 30+ m from camp, on dry ground.
func _zone_border() -> Vector3:
	var arr := BiomeZones.biome_types(_rt)
	var forest := BiomeZones.zone_id("forest")
	var meadow := BiomeZones.zone_id("meadow")
	var span := _rt._tile_span
	var half := _rt._size * 0.5
	var best := _rt._camp_pos
	var best_d := INF
	for z in range(4, span - 4, 2):
		for x in range(4, span - 4, 2):
			if int(arr[x + z * span]) != forest or int(arr[x + 4 + z * span]) != meadow:
				continue
			var p := Vector3(-half + x + 2.5, 0, -half + z + 0.5)
			var d := Vector2(p.x - _rt._camp_pos.x, p.z - _rt._camp_pos.z).length()
			if d > 30.0 and d < best_d and _rt.is_dry(p):
				best_d = d
				best = p
	return best

## Dry ground 1 m from the river waterline, nearest the camp past 25 m.
func _river_bank() -> Vector3:
	var best := _rt._camp_pos
	var best_d := INF
	var half := _rt._size * 0.5 - 2.0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			if IslandTerrain.tile_type_at_world(_rt, x, z) == IslandTerrain.TileType.MUD and _rt.surface_y(x, z) < -0.2:
				for dz in [3.0, -3.0]:
					var bz: float = z + dz
					if _rt.surface_y(x, bz) > 0.3 and _rt.is_dry(Vector3(x, 0, bz)):
						var d := Vector2(x - _rt._camp_pos.x, bz - _rt._camp_pos.z).length()
						if d > 25.0 and d < best_d:
							best_d = d
							best = Vector3(x, 0, bz)
			z += 1.0
		x += 1.0
	return best

## A cliff face nearest the camp.
func _cliff() -> Vector3:
	var span := _rt._tile_span
	var half := _rt._size * 0.5
	var best := _rt._camp_pos
	var best_d := INF
	for z in span:
		for x in span:
			if int(_rt.tile_types[x + z * span]) != IslandTerrain.TileType.CLIFF:
				continue
			var p := Vector3(-half + x + 0.5, 0, -half + z + 0.5)
			var d := Vector2(p.x - _rt._camp_pos.x, p.z - _rt._camp_pos.z).length()
			if d < best_d:
				best_d = d
				best = p
	return best

## Dry sand a few metres inland of the arrival point.
func _beach() -> Vector3:
	var a := _rt.arrival_point()
	var dir := -Vector2(a.x, a.z).normalized()
	var p := Vector2(a.x, a.z)
	for i in 60:
		if _rt.surface_y(p.x, p.y) > 0.2:
			break
		p += dir * 0.5
	p += dir * 2.0
	return Vector3(p.x, 0, p.y)
