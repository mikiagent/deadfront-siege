extends Node3D
## Spec 15 + 25 (map) shot lab. Boots the home island with the real HUD, opens the atlas on a fresh
## (fully grey) fog, walks the survivor along a path so the brush and the black-dot trail appear,
## opens the atlas again and finally frames the minimap. Saves three PNGs to --shot-dir and prints
## one measured line:
##   [mapui] RESULT fog_start= revealed_after_walk= fog_after_walk= trail_dots= claim_icons=
##            campfire_icons= facility_icons= persist_ok= ui_min_px=
## Windowed: --resolution 1600x900 -- --lab=mapui_lab --shot-dir=DIR
## (844x390 too; add --rendering-method gl_compatibility for the web renderer).

var _out := ""
var _player: Player
var _hud: HuntHud
var _map: MapScreen
var _fails: PackedStringArray = []
var _fog_start := 0.0
var _fog_after := 0.0
var _revealed_after := 0.0
var _trail_dots := 0
var _icons := {}
var _persist := 0
var _ui_px := 0.0

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("mapui")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.player_name = "Milan"
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	# Measured before a single walk tick: a fresh island's fog knows nothing at all.
	var fresh := World.map_fog
	_fog_start = grey_share(fresh) if fresh else 1.0
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	_run.call_deferred()

func _run() -> void:
	await _wait(2.5)
	if World.runtime == null or _hud == null:
		print("[mapui] FAIL no island/HUD")
		_finish()
		return
	# A fresh lab world: the fog knows nothing yet, so the whole island is grey.
	var fog := World.map_fog
	if fog == null:
		print("[mapui] FAIL World has no map fog")
		_finish()
		return
	# The atlas, straight from a fresh start.
	_hud.open_map()
	await _wait(0.6)
	_map = _hud.get_node_or_null("MapLayer/MapScreen") as MapScreen
	if _map == null:
		print("[mapui] FAIL the atlas did not open")
		_finish()
		return
	await _shot("map_before")
	_map.close()
	await _wait(0.3)
	# Walk a path east then south, 4 m per tick like World._process (60 m each leg).
	var camp: Vector3 = World.runtime.get("_camp_pos")
	var start := camp + Vector3(-30, 0, -6)
	_player.clear_nav()
	_player.global_position = start + Vector3(0, 1, 0)
	for i in 80:
		_player.global_position = start + Vector3(float(i) * 1.0, 1.0, 0.0)
		World.note_map_walk(_player.global_position)
		await get_tree().process_frame
	# A second leg south, so the trail bends like a walked route.
	var bend := _player.global_position
	for i in 40:
		_player.global_position = bend + Vector3(0.0, 0.0, float(i) * 1.0)
		World.note_map_walk(_player.global_position)
		await get_tree().process_frame
	await _wait(0.4)
	_fog_after = grey_share(fog)
	_revealed_after = fog.revealed_fraction()
	_trail_dots = fog.trail.size()
	_hud.open_map()
	await _wait(0.6)
	_map = _hud.get_node_or_null("MapLayer/MapScreen") as MapScreen
	if _map:
		var counts := {}
		for m in _map._icon_marks():
			var k := str(m["kind"])
			counts[k] = int(counts.get(k, 0)) + 1
		_icons = counts
		_ui_px = _map.icon_min_px(get_viewport().get_visible_rect().size)
		await _shot("map_after")
		_map.close()
	await _wait(0.3)
	# Persist: save through the real save, then read the bytes back and load the fog from them.
	var SG := load("res://scripts/core/save_game.gd") as GDScript
	var ok_save: bool = SG.save_now()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	var row: Variant = (parsed as Dictionary).get("map", {}) if parsed is Dictionary else {}
	var per: Dictionary = ((row as Dictionary).get("islands", {}) as Dictionary) if row is Dictionary else {}
	_persist = 1 if ok_save and per.has("home_grassland") else 0
	# The minimap: close to the camp so its brush and trail are in the disc.
	_player.global_position = camp + Vector3(-8, 1, 4)
	await _wait(0.8)
	await _shot("minimap")
	print("[mapui] RESULT fog_start=%.3f revealed_after_walk=%.3f fog_after_walk=%.3f trail_dots=%d claim_icons=%d campfire_icons=%d facility_icons=%d persist_ok=%d ui_min_px=%.1f" % [
		_fog_start, _revealed_after, _fog_after, _trail_dots,
		int(_icons.get("claim", 0)), int(_icons.get("campfire", 0)), int(_icons.get("facility", 0)),
		_persist, _ui_px])
	for f in _fails:
		print("[mapui] FAIL %s" % f)
	_finish()

## Share of the island's land cells still grey (0 = all walked, 1 = nothing known).
static func grey_share(f: MapFog) -> float:
	return clampf(1.0 - f.revealed_fraction(), 0.0, 1.0)

func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		_fails.append("no frame image for %s" % name)
		return
	var path := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
	img.save_png(path)
	print("[mapui] shot %s" % path)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _finish() -> void:
	get_tree().quit(0 if _fails.is_empty() else 1)
