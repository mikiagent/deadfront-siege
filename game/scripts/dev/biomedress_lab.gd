extends Node3D
## BIOMEDRESS lab (specs 26-28, docs/reference/biome-concept-*.webp): one top shot and one
## game-camera shot per biome zone, on the home island and two other islands (savanna and volcanic),
## so every zone's dressing is judged against the owner's concept art in the real light.
## Windowed: Godot --path game --resolution 1600x900 --rendering-method gl_compatibility --
##   --lab=biomedress_lab --shot-dir=DIR
## Saves DIR/<island>-<zone>-top.png and -game.png for every dressed zone (>= 5 PNGs), plus the home
## camp perf frames, and prints exactly one line:
##   [biomedress] RESULT zones_total= zones_dressed= sprite_kinds_min= grass_in_claim= prims_camp=
##   ms_frame= ms_base= wrong_biome= zones_home_grassland= cards_home_grassland= ... (one pair of
##   keys per island visited, so the gate sees each island's own numbers, never a cumulative total)
## All numbers are measured from the live scene: zones_total = BiomeZones.zone_count();
## zones_dressed = zones with placed cards on the islands visited; sprite_kinds_min = the fewest
## distinct sprite ids in any dressed zone; grass_in_claim = cards on claimed tiles on every island
## visited; prims_camp = primitives drawn at the home camp (shadow pass off for that sample);
## ms_frame / ms_base = median frame time with the dressing shown and hidden, alternating per frame;
## wrong_biome = cards standing outside the zone their kind lists. The per-island keys are
## zones_<island> (zones that island dressed) and cards_<island> (cards it drew), measured after that
## island is built and reset before the next one, and every island is also printed on its own line.

const TOP_SIZE := 46.0
const TOP_H := 120.0
const ISLANDS: Array[StringName] = [&"home_grassland", &"savannah_15", &"volcanic_60"]
## Frames timed per phase (the first ones after a switch recompile pipelines).
const WARMUP := 20
const PERF_PAIRS := 80

var _player: Player
var _cam: IsoCamera
var _top: Camera3D
var _shot_dir := ""
var _bd: BiomeDress
var _rt: IslandRuntime
var _shots := 0
var _phase := &""
var _last_us := 0
var _pair_mode := false
var _pair_cur_on := true
var _pair_on: Array[float] = []
var _pair_off: Array[float] = []
var _ms_frame := 0.0
var _ms_base := 0.0
var _prims_camp := 0
var _dressed: Dictionary = {}
var _kinds_min := 999
var _grass_in_claim := 0
var _wrong := 0
## Per island: zones it dressed and cards it drew, measured on that island only.
var _island_zones: Dictionary = {}
var _island_cards: Dictionary = {}
## A headless run has a dummy renderer: no frame_post_draw, no viewport image. Everything except the
## pixels still measures (per-island cards, zones, claims, wrong zone), so the gate keeps a headless
## accounting check; the Forward+/GL screenshots are the windowed (deferred) part.
var _headless := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_shot_dir = a.substr(11)
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	_cam.size = 16.0
	TouchControls.visible = false
	TouchControls.enabled = false
	(kit["ui"] as CanvasLayer).visible = false
	Game.debug_overlay = false
	_headless = DisplayServer.get_name() == "headless"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_top = Camera3D.new()
	_top.name = "TopCam"
	_top.projection = Camera3D.PROJECTION_ORTHOGONAL
	_top.size = TOP_SIZE
	_top.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_top.current = false
	add_child(_top)
	print("[boot] lab=biomedress_lab")
	_run.call_deferred()

func _run() -> void:
	var zones_total := BiomeZones.zone_count()
	for id in ISLANDS:
		await _load(id)
		var bd := _rt.get_node_or_null("BiomeDress") as BiomeDress
		if bd == null:
			print("[biomedress] FAIL island %s has no BiomeDress" % str(id))
			continue
		_bd = bd
		_grass_in_claim += bd.claimed_instances()
		_wrong += bd.wrong_biome_instances()
		var island_zones := 0
		var island_kinds := 999
		var island_cards := bd.instance_count()
		if id == ISLANDS[0]:
			await _perf_camp(bd)
		for zone in BiomeZones.ZONE_NAMES:
			var spot := bd.zone_spot(zone)
			if spot.is_empty():
				continue
			_dressed[zone] = true
			island_zones += 1
			var kinds := bd.sprites_in_zone(zone).size()
			island_kinds = mini(island_kinds, kinds)
			_kinds_min = mini(_kinds_min, kinds)
			await _shot_zone(str(id), zone, spot["point"] as Vector3, spot["centroid"] as Vector3)
		_island_zones[str(id)] = island_zones
		_island_cards[str(id)] = island_cards
		print("[biomedress] island %s zones=%d cards=%d kinds_min=%d (own numbers, not cumulative)" % [
			str(id), island_zones, island_cards, 0 if island_kinds == 999 else island_kinds])
	if _kinds_min == 999:
		_kinds_min = 0
	var per_island := ""
	for id in ISLANDS:
		per_island += " zones_%s=%d cards_%s=%d" % [str(id), int(_island_zones.get(str(id), 0)),
			str(id), int(_island_cards.get(str(id), 0))]
	print("[biomedress] RESULT zones_total=%d zones_dressed=%d sprite_kinds_min=%d grass_in_claim=%d prims_camp=%d ms_frame=%.2f ms_base=%.2f wrong_biome=%d%s" % [
		zones_total, _dressed.size(), _kinds_min, _grass_in_claim, _prims_camp, _ms_frame, _ms_base, _wrong, per_island])
	print("[biomedress] shots=%d islands=%d zones_dressed=%s" % [_shots, ISLANDS.size(), ",".join(_dressed.keys())])
	# Headless draws no pixels, so the PNG count cannot be the exit condition there; the windowed run
	# still has to produce the shots.
	if _headless:
		get_tree().quit(0 if _dressed.size() >= 5 else 1)
		return
	get_tree().quit(0 if _shots >= 5 else 1)

func _load(id: StringName) -> void:
	World.load_island(self, id, Vector3(0, 1, 18), false)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_rt = World.runtime as IslandRuntime
	_player.global_position.y = _rt.surface_y(_player.global_position.x, _player.global_position.z) + 1.0
	_cam._snap()

## A top-down shot of the zone (ortho, fixed 46 m) and a game-camera shot standing on it.
func _shot_zone(island: String, zone: String, point: Vector3, centroid: Vector3) -> void:
	if _shot_dir == "":
		return
	_top.global_position = Vector3(centroid.x, TOP_H, centroid.z)
	_top.size = TOP_SIZE
	_top.current = true
	for i in 3:
		await get_tree().process_frame
	await _shot("%s-%s-top" % [island, zone])
	# The game camera: the survivor stands on a dressed card of the zone, the iso camera snaps to it.
	_cam.current = true
	_player.global_position = point + Vector3(0.0, 1.0, 0.0)
	_player.global_position.y = _rt.surface_y(point.x, point.z) + 1.0
	_cam._snap()
	for i in 6:
		await get_tree().process_frame
	await _shot("%s-%s-game" % [island, zone])

func _shot(tag: String) -> void:
	if _shot_dir == "" or _headless:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _shot_dir.path_join("%s.png" % tag)
	img.save_png(path)
	_shots += 1
	print("[biomedress] shot %s" % path)

# ---------------------------------------------------------------- perf at the home camp

func _perf_camp(bd: BiomeDress) -> void:
	var camp: Vector3 = _rt._camp_pos
	_cam.current = true
	_player.global_position = camp + Vector3(2.0, 1.0, 2.0)
	_player.global_position.y = _rt.surface_y(_player.global_position.x, _player.global_position.z) + 1.0
	_cam._snap()
	for i in 8:
		await get_tree().process_frame
	if _headless:
		print("[biomedress] headless: prims and frame timing need a renderer (deferred)")
		return
	await _measure_prims()
	await _timing(bd)

func _measure_prims() -> void:
	var lights: Array[DirectionalLight3D] = []
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
	print("[biomedress] prims=%d draws=%d" % [_prims_camp,
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))])

## Frame time with the dressing drawn and hidden, alternating EVERY frame inside one window, so
## machine drift hits both buckets equally; reported as the median of each bucket.
func _timing(bd: BiomeDress) -> void:
	_pair_mode = true
	_pair_on.clear()
	_pair_off.clear()
	_pair_cur_on = true
	bd.visible = true
	_last_us = 0
	_phase = &"perf"
	await _wait(WARMUP * 2 + PERF_PAIRS * 2)
	_phase = &""
	_pair_mode = false
	bd.visible = true
	_pair_on.sort()
	_pair_off.sort()
	_ms_frame = _median(_pair_on)
	_ms_base = _median(_pair_off)
	print("[biomedress] timing dress n=%d median=%.2f | base n=%d median=%.2f" % [
		_pair_on.size(), _ms_frame, _pair_off.size(), _ms_base])

func _median(a: Array[float]) -> float:
	return a[a.size() / 2] if not a.is_empty() else 0.0

func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _process(_delta: float) -> void:
	if _phase != &"perf":
		return
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		var ms := float(now - _last_us) / 1000.0
		if _pair_mode:
			if _pair_cur_on:
				_pair_on.append(ms)
			else:
				_pair_off.append(ms)
			_pair_cur_on = not _pair_cur_on
			if _bd != null:
				_bd.visible = _pair_cur_on
	_last_us = now
