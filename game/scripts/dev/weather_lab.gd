extends Node3D
## WEATHER lab: an island with the real HUD and one forced weather state (--weather=clear|drizzle|rain|pour|storm|heat|
## cold), held at midday. --island=ID picks the island (default: home_grassland; heat -> desert_35, cold ->
## tundra_30). --bleed adds a bleed so the combat red edge shows over the weather's.
## --shot-dir=DIR saves weather_<state>_<W>x<H>[_compat].png once the state has settled (storm: at a strike's
## flash peak, a near strike in view); --perf prints the frame cost of
## the layer (on vs hidden, vsync off). --seq=near|far saves 6 frames across one strike's flash -> thunder;
## --clip=S with --write-movie records a near then a far strike. Quits when done; else it stays up.
## Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility]
##   res://scenes/dev/weather_lab.tscn -- --lab=weather_lab --weather=storm --shot-dir=DIR [--seq=near|far] [--perf]

var _out := ""
var _seq := ""
var _clip := 0.0
var _perf := false
var _bleed := false
var _state := &"storm"
var _player: Player
var _rt: IslandRuntime
var _w: WorldWeather

func _ready() -> void:
	var island := &""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--island="):
			island = StringName(a.substr(9))
		elif a.begins_with("--weather="):
			_state = StringName(a.substr(10))
		elif a.begins_with("--seq="):
			_seq = a.substr(6)
		elif a.begins_with("--clip="):
			_clip = float(a.substr(7))
		elif a == "--perf":
			_perf = true
		elif a == "--bleed":
			_bleed = true
	if island == &"":
		island = {&"heat": &"desert_35", &"cold": &"tundra_30"}.get(_state, &"home_grassland")
	WorldWeather.forced = _state
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	Game.max_creatures_per_island = 0
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	World.home_terrain = &"meadow"
	World.load_island(self, island, Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_rt = World.runtime as IslandRuntime
	_w = _rt.weather
	for n in get_tree().get_nodes_in_group("creature"):
		n.queue_free()
	Game.time_of_day = 0.45
	if _bleed:
		_player.statuses.apply(&"bleed", null)
	_w._flash_cd = 1.0e9  # strikes only when the lab says
	var t0 := Time.get_ticks_msec()
	_w.lightning.connect(func (pos: Vector3, d: float) -> void: print("[weatherlab] lightning at %s, %.0f m, %.2f s" % [pos, d, (Time.get_ticks_msec() - t0) / 1000.0]))
	_w.thunder.connect(func (d: float) -> void: print("[weatherlab] thunder %.0f m at %.2f s" % [d, (Time.get_ticks_msec() - t0) / 1000.0]))
	if _clip > 0.0:
		await _movie()
		get_tree().quit(0)
		return
	await get_tree().create_timer(9.0 if _state in [&"heat", &"cold", &"drizzle", &"rain", &"pour"] else 3.0).timeout
	if _state == &"storm":
		_w._flash_cd = 1.0e9
		_w.strike_at(_onscreen(7.0))
		await get_tree().process_frame
	if _out != "":
		await _shot("weather_%s%s" % [_state, "_bleed" if _bleed else ""])
	if _seq != "":
		await _sequence()
	if _perf:
		await _measure()
	if _out != "" or _perf:
		get_tree().quit(0)

## A ground point `m` metres to the screen's right of her: a near strike that lands in view.
func _onscreen(m: float) -> Vector3:
	var right := IsoCamera.view_basis().x
	return _player.global_position + Vector3(right.x, 0.0, right.z).normalized() * m

## --clip=S (with --write-movie): a near strike at 1.5 s, a far one (1500 m) at 5 s, quit at S.
func _movie() -> void:
	_w._flash_cd = 1.0e9
	await get_tree().create_timer(1.5).timeout
	_w.strike_at(_onscreen(7.0))
	await get_tree().create_timer(3.5).timeout
	_w._flash_cd = 1.0e9
	_w.strike(1500.0)
	await get_tree().create_timer(maxf(0.1, _clip - 5.0)).timeout

## Six frames across one beat (--seq=near: 7 m, on screen; --seq=far: 1500 m, 4.4 s to the thunder):
## the stroke, the second stroke, the afterglow, the wait, the clap, its rumble.
func _sequence() -> void:
	await get_tree().create_timer(3.5).timeout  # the shot's own strike has clapped
	_w._flash_cd = 1.0e9
	var near := _seq == "near"
	var d := 7.0 if near else 1500.0
	var delay := _w.thunder_delay(d)
	if near:
		_w.strike_at(_onscreen(d))
	else:
		_w.strike(d)
	var t0 := Time.get_ticks_msec() / 1000.0
	var marks := [0.02, 0.16, 0.45, 1.0, 1.8, 3.0] if near else [0.02, 0.16, 0.6, delay - 0.3, delay + 0.08, delay + 0.45]
	var imgs: Array[Image] = []
	for k in marks.size():
		while Time.get_ticks_msec() / 1000.0 - t0 < marks[k]:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		imgs.append(get_viewport().get_texture().get_image())  # saved after the beat: a PNG write takes ~0.25 s
		print("[weatherlab] seq %d t=%.2f flash=%.2f rumble=%.2f shake=%.3f" % [k, Time.get_ticks_msec() / 1000.0 - t0, _w.flash, _w.rumble, _w.fx.shake.length()])
	for k in imgs.size():
		imgs[k].save_png(_out.path_join("weather_seq_%s_%d_%dx%d.png" % [_seq, k, get_tree().root.size.x, get_tree().root.size.y]))

## GPU and CPU frame time with the weather layer drawn and hidden, vsync off, 3 s each.
func _measure() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for on in [true, false, true, false]:
		_w.fx.visible = on
		await get_tree().create_timer(0.5).timeout
		var gpu := 0.0
		var cpu := 0.0
		var frames := 0
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < 3000000:
			await get_tree().process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
			frames += 1
		var wall := float(Time.get_ticks_usec() - t0) / 1000.0 / float(frames)
		print("[weatherlab] perf state=%s quality=%s layer=%s frames=%d wall=%.3fms gpu=%.3fms cpu=%.3fms renderer=%s %dx%d" % [_state,
			"high" if WeatherFx.high_quality else "low", "on" if on else "off", frames, wall, gpu / frames, cpu / frames,
			RenderingServer.get_current_rendering_method(), get_tree().root.size.x, get_tree().root.size.y])
	_w.fx.visible = true

func _shot(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var compat := "_compat" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else ""
	var path := _out.path_join("%s_%dx%d%s.png" % [stem, get_tree().root.size.x, get_tree().root.size.y, compat])
	img.save_png(path)
	print("[weatherlab] shot %s flash=%.2f heat=%.2f cold=%.2f frost=%.2f" % [path, _w.flash, _w.heat, _w.cold, _w.frost])
