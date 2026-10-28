extends Node3D
## GROUND2D lab (islands plan P2 row 2, spec 28 "Tall grasses on terrain"): the home grassland, a
## temperate island's forest and a point 150 m from the origin, each with the survivor and the game
## camera, so the ground cover is judged in the real light and the numbers are measured live.
## Windowed: Godot --path game --resolution 1600x900 -- --lab=ground2d_lab --shot-dir=DIR
## Saves DIR/camp.png, DIR/forest.png, DIR/far.png and prints exactly one line:
##   [ground2d] RESULT density_camp= density_forest= density_far= far_ratio= blocking= wrong_biome=
##   grey_cards= prims_camp= ms_frame= ms_base=
## The settle and shot order is fixed: camp frame, primitives, timing, then the temperate island.
## density_* = ground-cover instances per m2 within 25 m of the survivor (camp) and of the forest and
## far points; far_ratio = density_far / density_camp; blocking = colliders under the cover;
## wrong_biome = instances on a desert island plus instances standing on sand/ash tiles;
## grey_cards = cards whose sprite texture is missing; prims_camp = primitives in the camp frame;
## ms_frame / ms_base = average frame time with the cover on and with the cover hidden.

const CAMP_R := 25.0
const FAR_M := 150.0
## Frames timed per phase (the first ones after a switch recompile pipelines).
const WARMUP := 20
const PERF_FRAMES := 90
## Alternating cover-on/off frame pairs timed for the frame-time comparison.
const PERF_PAIRS := 90

var _player: Player
var _cam: IsoCamera
var _shot_dir := ""
var _gc: GroundCover
var _rt: IslandRuntime
var _phase := &""
var _frames: Array[float] = []
var _last_us := 0
var _timed: Array[float] = []
var _ms_frame := 0.0
var _ms_base := 0.0
var _prims_camp := 0
var _pair_mode := false
var _pair_cur_on := true
var _pair_on: Array[float] = []
var _pair_off: Array[float] = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_shot_dir = a.substr(11)
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	_cam.size = 14.0
	TouchControls.visible = false
	TouchControls.enabled = false
	(kit["ui"] as CanvasLayer).visible = false
	Game.debug_overlay = false
	# Frame times, not the display refresh: without this both phases read the vsync cap.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("[boot] lab=ground2d_lab")
	_run.call_deferred()

func _run() -> void:
	# 1. The home island at camp.
	await _load(&"home_grassland")
	_gc = World.runtime.get_node_or_null("GroundCover") as GroundCover
	if _gc == null:
		print("[ground2d] RESULT grass_in_claim=0 density_camp=0 density_forest=0 density_far=0 far_ratio=0 blocking=0 wrong_biome=0 grey_cards=0 prims_camp=0 ms_frame=0 ms_base=0")
		get_tree().quit(1)
		return
	var camp: Vector3 = World.runtime._camp_pos
	_player.global_position = camp + Vector3(2.0, 1.0, 2.0)
	_player.global_position.y = World.runtime.surface_y(_player.global_position.x, _player.global_position.z) + 1.0
	_cam._snap()
	await _settle()
	var density_camp := _density(camp)
	# Owner rule: claimed land carries no ground cover (the camp plot is claimed on a home island).
	var grass_in_claim := _claimed_instances()
	if grass_in_claim > 0:
		print("[ground2d] FAIL %d instances stand on claimed tiles" % grass_in_claim)
	await _shot("camp")
	await _measure_prims()
	await _timing()
	# 2. A temperate island: the densest grove (forest) and a point 150 m from the origin (far).
	var blocking: int = _gc.collision_bodies()
	var grey: int = _gc.grey_cards() + _gc.missing_sprites()
	var wrong_biome := _cover_on_bad_tiles(_rt)
	await _load(&"temperate_25")
	var rt: IslandRuntime = World.runtime
	_gc = rt.get_node_or_null("GroundCover") as GroundCover
	if _gc != null:
		blocking += _gc.collision_bodies()
		grey += _gc.grey_cards() + _gc.missing_sprites()
	wrong_biome += _cover_on_bad_tiles(rt)
	var forest := _forest_point(rt)
	_player.global_position = forest + Vector3(0.0, 1.0, 0.0)
	_player.global_position.y = rt.surface_y(forest.x, forest.z) + 1.0
	_cam._snap()
	await _settle()
	var density_forest := _density(forest)
	await _shot("forest")
	var far := _far_point(rt)
	_player.global_position = far + Vector3(0.0, 1.0, 0.0)
	_player.global_position.y = rt.surface_y(far.x, far.z) + 1.0
	_cam._snap()
	await _settle()
	var density_far := _density(far)
	await _shot("far")
	# 3. A desert island: the cover must not exist there at all.
	await _load(&"desert_35")
	var desert_nodes := 0
	var desert_instances := 0
	var dgc := World.runtime.get_node_or_null("GroundCover") as GroundCover
	if dgc != null:
		desert_nodes += 1
		desert_instances += dgc.instance_count()
		blocking += dgc.collision_bodies()
	wrong_biome += desert_instances
	var far_ratio := density_far / maxf(0.0001, density_camp)
	print("[ground2d] RESULT grass_in_claim=%d density_camp=%.3f density_forest=%.3f density_far=%.3f far_ratio=%.3f blocking=%d wrong_biome=%d grey_cards=%d prims_camp=%d ms_frame=%.2f ms_base=%.2f" % [
		grass_in_claim, density_camp, density_forest, density_far, far_ratio, blocking, wrong_biome, grey, _prims_camp, _ms_frame, _ms_base])
	print("[ground2d] desert_nodes=%d desert_instances=%d cover_instances=%d" % [desert_nodes, desert_instances, _gc.instance_count() if _gc else 0])
	get_tree().quit(0)

## A loaded island with the survivor's camera live; waits for the terrain and the cover to settle.
func _load(id: StringName) -> void:
	World.load_island(self, id, Vector3(0, 1, 18), false)
	await get_tree().process_frame
	await get_tree().process_frame
	_rt = World.runtime as IslandRuntime
	_player.global_position.y = _rt.surface_y(_player.global_position.x, _player.global_position.z) + 1.0
	_cam._snap()

func _settle() -> void:
	for i in 8:
		await get_tree().process_frame

## Instances per m2 within CAMP_R of `centre`.
func _density(centre: Vector3) -> float:
	if _gc == null:
		return 0.0
	var n := _gc.count_within(centre, CAMP_R)
	return float(n) / (PI * CAMP_R * CAMP_R)

## Instances standing on a claimed tile at camp (must be 0: the owner's rule is bare claimed land).
func _claimed_instances() -> int:
	if _gc == null:
		return 0
	return _gc.claimed_instances()

## Instances standing on sand, ash or bare rock tiles (the cover grows on soil only).
func _cover_on_bad_tiles(rt: IslandRuntime) -> int:
	var gc := rt.get_node_or_null("GroundCover") as GroundCover
	if gc == null:
		return 0
	var bad := 0
	for p in gc.positions():
		var t := IslandTerrain.tile_type_at_world(rt, p.x, p.z)
		if t == IslandTerrain.TileType.SAND or t == IslandTerrain.TileType.ASH \
			or t == IslandTerrain.TileType.ROCK or t == IslandTerrain.TileType.BARE \
			or t == IslandTerrain.TileType.WET or t == IslandTerrain.TileType.DEEP \
			or t == IslandTerrain.TileType.SHALLOW:
			bad += 1
	return bad

## The island's densest grove: the tree with the most tree neighbours within 15 m, stood 4 m from it.
func _forest_point(rt: IslandRuntime) -> Vector3:
	var trees: Array[HarvestNode] = []
	for n in get_tree().get_nodes_in_group("harvest"):
		var node := n as HarvestNode
		if node != null and node.falls_to_log:
			trees.append(node)
	var best := Vector3.ZERO
	var best_score := -1
	for node in trees:
		var score := 0
		for other in trees:
			if node == other:
				continue
			if Vector2(node.global_position.x - other.global_position.x, node.global_position.z - other.global_position.z).length() < 15.0:
				score += 1
		if score > best_score:
			best_score = score
			best = node.global_position
	if best == Vector3.ZERO:
		return rt._camp_pos
	# A few metres off the trunk, so the shot is under the canopy rather than inside it.
	var off := Vector3(4.0, 0.0, 4.0)
	return Vector3(best.x + off.x, 0.0, best.z + off.z)

## A dry point FAR_M from the origin (searching outward if that bearing is water or a cliff).
func _far_point(rt: IslandRuntime) -> Vector3:
	for i in 36:
		var a := TAU * float(i) / 36.0
		var p := Vector3(cos(a) * FAR_M, 0.0, sin(a) * FAR_M)
		if rt.is_dry(p) and IslandTerrain.slope_deg(rt, p.x, p.z) < 25.0:
			return p
	return Vector3(cos(0.7) * FAR_M, 0.0, sin(0.7) * FAR_M)

func _shot(tag: String) -> void:
	if _shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _shot_dir.path_join("%s.png" % tag)
	img.save_png(path)
	print("[ground2d] shot %s" % path)

## Primitives the camera actually draws at camp. RenderingServer's total for a frame includes the
## sun's shadow pass (the island's meshy trees are ~2 M triangles there), so the visible count is
## sampled with the shadow pass off for that one frame; the total with shadows is printed beside it.
func _measure_prims() -> void:
	var sun := _sun()
	var lights: Array[DirectionalLight3D] = []
	if sun != null:
		for l in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
			var dl := l as DirectionalLight3D
			if dl != null and dl.shadow_enabled:
				lights.append(dl)
				dl.shadow_enabled = false
	for i in 4:
		await RenderingServer.frame_post_draw
	_prims_camp = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	for l in lights:
		l.shadow_enabled = true
	for i in 3:
		await RenderingServer.frame_post_draw
	var with_shadow := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	print("[ground2d] prims visible=%d with_shadow=%d draws=%d" % [_prims_camp, with_shadow,
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))])

func _sun() -> DirectionalLight3D:
	var rt := World.runtime as IslandRuntime
	if rt != null and rt.lighting != null:
		return rt.lighting.sun
	return null

## Frame time with the cover drawn and with it hidden. The two states alternate EVERY frame inside one
## window, and each frame's cost goes to the bucket of the state that was visible, so machine drift (other
## jobs' loads, thermal ramp) hits both buckets equally instead of landing on whichever ran first. Reported
## as the median frame time of each bucket, which ignores the occasional hitch.
func _timing() -> void:
	if _gc == null:
		return
	_pair_mode = true
	_pair_on.clear()
	_pair_off.clear()
	_pair_cur_on = true
	_gc.visible = true
	_timed.clear()
	_last_us = 0
	_phase = &"perf"
	await _wait(WARMUP * 2 + PERF_PAIRS * 2)
	_phase = &""
	_pair_mode = false
	_gc.visible = true
	_pair_on.sort()
	_pair_off.sort()
	_ms_frame = _median(_pair_on)
	_ms_base = _median(_pair_off)
	print("[ground2d] timing cover n=%d median=%.2f mean=%.2f | base n=%d median=%.2f mean=%.2f" % [
		_pair_on.size(), _ms_frame, _mean(_pair_on), _pair_off.size(), _ms_base, _mean(_pair_off)])

func _median(a: Array[float]) -> float:
	return a[a.size() / 2] if not a.is_empty() else 0.0

func _mean(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var sum := 0.0
	for x in a:
		sum += x
	return sum / float(a.size())

func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _process(_delta: float) -> void:
	if _phase != &"perf":
		return
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		var ms := float(now - _last_us) / 1000.0
		_timed.append(ms)
		if _pair_mode and _timed.size() > WARMUP:
			if _pair_cur_on:
				_pair_on.append(ms)
			else:
				_pair_off.append(ms)
			_pair_cur_on = not _pair_cur_on
			if _gc != null:
				_gc.visible = _pair_cur_on
	_last_us = now
