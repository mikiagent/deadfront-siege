extends Node3D
## Spec 17 (water context actions): stands the survivor at fixed spots on the home island with the
## real HUD and records which context hexes it shows. Spots, found from the heightmap:
##   river_bank_1m  dry ground, the river's waterline 1 m away
##   river_shallow  ankle-deep in the river
##   sea_bank_1m    dry sand, the sea's waterline 1 m away (the beach by the harbour)
##   sea_shallow    ankle-deep in the sea
##   dry_mid        dry grass on the island's z = 0 line, far from any water
## then, at the river bank, a Dirty + Thirsty survivor with an empty bucket before and after
## pressing Drink, Wash and Fill (bank_statuses, bank_after).
## Headless: Godot --headless --path game res://scenes/dev/water_lab.tscn -- --lab=water_lab
## Windowed: Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility]
##   res://scenes/dev/water_lab.tscn -- --lab=water_lab --shot-dir=DIR   (also 844x390)
## Prints "[waterlab] spot=<name> pos=... ground=... water_1m=... ctx=[...]" per spot, then "[waterlab] done".

const SETTLE_S := 1.2
const WATER_Y := -0.05 ## HarbourSite.WATER_Y, IslandTerrain's water plane

var _out := ""
var _player: Player
var _hud: HuntHud
var _cam: IsoCamera
var _rt: IslandRuntime

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false  # before the HUD builds: players never see the DEBUG hex
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	_cam = kit["cam"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_rt = World.runtime as IslandRuntime
	Game.time_of_day = 0.45  # midday light for every shot
	var river := _find_shallow(true, _rt._camp_pos, 38.0)  # mid-river, clear of its inland end
	var river_bank := _bank(river, true)
	var sea := _find_shallow(false, _rt.arrival_point(), 12.0)
	var sea_bank := _bank(sea, false)
	var spots := [
		["river_bank_1m", river_bank], ["river_shallow", river], ["sea_bank_1m", sea_bank],
		["sea_shallow", sea], ["dry_mid", _dry_mid()],
	]
	for s in spots:
		await _stand(str(s[0]), s[1])
	# Statuses and the actions, at the river bank.
	LabKit.give(_player, &"empty_bucket", 1)
	_player.statuses.apply(&"dirty")
	_player.statuses.apply(&"thirsty")
	await _stand("bank_statuses", river_bank)
	for id in ["drink", "wash", "fill"]:
		_player.context_action(id)
	print("[waterlab] after actions statuses=%s water_bucket=%d empty_bucket=%d" % [
		_player.statuses.to_array().map(func (r: Dictionary) -> String: return str(r["id"])),
		_player.inventory.count_of(&"water_bucket"), _player.inventory.count_of(&"empty_bucket")])
	await _stand("bank_after", river_bank)
	print("[waterlab] done")
	get_tree().quit(0)

func _stand(name: String, at: Vector3) -> void:
	_player.clear_nav()
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(at.x, _rt.surface_y(at.x, at.z) + 0.15, at.z)
	_player.reset_physics_interpolation()
	_cam._snap()
	await get_tree().create_timer(SETTLE_S).timeout
	var p := _player.global_position
	var ids: Array = []
	for row in _hud._ctx_ids:
		ids.append(str(row[0]))
	print("[waterlab] spot=%s pos=(%.1f, %.1f) ground=%.2f to_water=%.1fm in_water=%s ctx=%s" % [
		name, p.x, p.z, _rt.surface_y(p.x, p.z), _water_dist(p), _player.in_water, ids])
	if _out != "":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
		img.save_png(path)
		print("[waterlab] shot %s" % path)

func _is_water(x: float, z: float) -> bool:
	return _rt.surface_y(x, z) < WATER_Y

func _is_river(x: float, z: float) -> bool:
	return IslandTerrain.tile_type_at_world(_rt, x, z) == IslandTerrain.TileType.MUD

## Wadeable water (above the shoreline guard's -0.40 m) of the river or the sea, nearest `from` (or
## nearest `ring` metres from it). River spots are the channel's deep middle so the survivor stays in it.
func _find_shallow(river: bool, from: Vector3, ring: float) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	var half := _rt._size * 0.5 - 2.0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			var h := _rt.surface_y(x, z)
			# |z| > 8: off the z = 0 line, where the base's straight "Wet" box made any spot read as water.
			if h < (-0.25 if river else -0.12) and h > -0.38 and _is_river(x, z) == river and (not river or absf(z) > 8.0):
				var d := absf(Vector2(x - from.x, z - from.z).length() - ring)
				if d < best_d:
					best_d = d
					best = Vector3(x, h, z)
			z += 0.5
		x += 0.5
	return best

## Dry ground whose nearest water is ~1 m away: walk out of the water the short way, then 1 m on.
func _bank(water: Vector3, river: bool) -> Vector3:
	var dirs: Array[Vector2] = [Vector2(0, 1), Vector2(0, -1)]
	if not river:
		dirs = [-Vector2(water.x, water.z).normalized()]
	var best := water
	var best_steps := 1 << 30
	for d in dirs:
		var at := Vector2(water.x, water.z)
		var steps := 0
		while _is_water(at.x, at.y) and steps < 200:
			at += d * 0.05
			steps += 1
		if steps < best_steps:
			best_steps = steps
			best = Vector3(at.x + d.x * 1.0, 0.0, at.y + d.y * 1.0)
	return best

## Dry grass on z = 0 (the base's straight "Wet" box ran along it), 10 m or more from any water.
func _dry_mid() -> Vector3:
	var x := -_rt._size * 0.3
	while x < _rt._size * 0.3:
		var at := Vector3(x, 0.0, 0.0)
		if _rt.surface_y(x, 0.0) > 0.5 and _water_dist(at) > 10.0 and Vector2(x - _rt._camp_pos.x, -_rt._camp_pos.z).length() > 14.0:
			return at
		x += 1.0
	return Vector3(0, 0, 0)

## Metres to the nearest water (0 when standing in it), searched out to 15 m.
func _water_dist(at: Vector3) -> float:
	if _is_water(at.x, at.z):
		return 0.0
	var r := 0.1
	while r <= 15.0:
		for k in 48:
			var a := TAU * float(k) / 48.0
			if _is_water(at.x + cos(a) * r, at.z + sin(a) * r):
				return r
		r += 0.1
	return INF
