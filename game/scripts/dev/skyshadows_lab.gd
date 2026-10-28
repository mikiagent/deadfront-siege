extends Node3D
## SKYSHADOWS lab: home_grassland at the default camera zoom with the sky frozen on chosen frames
## (a pteranodon shadow crossing the survivor, a cloud edge over the camp, the same frame with the
## quality toggle off, dusk), then the frame cost with the system on and off.
##
##   godot --path game --resolution 1600x900 [--rendering-method gl_compatibility] -- \
##     --lab=skyshadows_lab --shot-dir=/tmp/sky_shots
## Prints [sky-lab] lines: renderer, view size, shots and "perf on=.. off=.. ms" (mean of 4 x 240 frames,
## add --disable-vsync --max-fps 0; Metal still paces Forward+ at 8.33 ms on a 120 Hz display).

const WATCHDOG_S := 240.0
const PERF_FRAMES := 240

var shot_dir := "/tmp/sky_shots"
var _player: Player
var _sky: SkyShadows
var _tag := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			shot_dir = a.substr(11)
	Game.debug_overlay = false
	Game.day_length_seconds = 1.0e9
	Game.time_of_day = 0.42
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	(kit["nav"] as Node).visible = false
	World.harvested.clear()
	World.load_island(self, &"home_grassland", Vector3(4, 1, 14), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	_tag = "compat" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "fwd"
	DirAccess.make_dir_recursive_absolute(shot_dir)
	get_tree().create_timer(WATCHDOG_S).timeout.connect(func() -> void:
		print("[sky-lab] FAIL watchdog")
		get_tree().quit(1))
	if DisplayServer.get_name() == "headless":
		print("[sky-lab] FAIL headless cannot render")
		get_tree().quit.call_deferred(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_run.call_deferred()

func _run() -> void:
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	TouchControls.visible = false
	await get_tree().create_timer(4.0).timeout
	_sky = get_tree().get_first_node_in_group(&"sky_shadows") as SkyShadows
	if _sky == null:
		print("[sky-lab] FAIL no SkyShadows on the island")
		get_tree().quit(1)
		return
	var size := get_viewport().get_visible_rect().size
	print("[sky-lab] renderer=%s view=%dx%d flyers=%d" % [_tag, size.x, size.y, _sky.flyer_count])
	Engine.time_scale = 0.0  # freeze the sky (and the survivor) on each chosen frame
	var me := Vector2(_player.global_position.x, _player.global_position.z)
	# 1. A flyer's shadow just ahead of the survivor, under open sky.
	_clear_sky_at(me)
	_flyer_near(me + Vector2(-6.0, -6.0))
	await _shot("flyer")
	# 2. A cloud edge across the camp, flyer elsewhere.
	_cloud_edge_at(me)
	_flyer_near(me + Vector2(60.0, 60.0))
	await _shot("cloud")
	SkyShadows.set_enabled(false, get_tree())
	await _shot("cloud_off")
	SkyShadows.set_enabled(true, get_tree())
	# 3. Dusk: the same flyer, fading with the light.
	Game.time_of_day = 0.79
	_clear_sky_at(me)
	_flyer_near(me + Vector2(-6.0, -6.0))
	await get_tree().create_timer(0.5, true, false, true).timeout
	await _shot("dusk")
	Engine.time_scale = 1.0
	Game.time_of_day = 0.42
	await _perf()
	Engine.time_scale = 0.0
	_flyer_near(me + Vector2(-6.0, -6.0))
	await _shot("after_perf")
	print("[sky-lab] done")
	get_tree().quit(0)

## Sets the sky clock so flyer 0's shadow centre lands within 1.5 m of `at`.
func _flyer_near(at: Vector2) -> void:
	var best := INF
	var best_t := 0.0
	var t := 0.0
	while t < 2000.0:
		_sky._t = t
		_sky.step(0.0)
		var f := _sky.last_flyers[0]
		var d := Vector2(f.x, f.y).distance_to(at)
		if d < best:
			best = d
			best_t = t
		t += 0.05
	_sky._t = best_t
	_sky.step(0.0)
	print("[sky-lab] flyer t=%.2f miss=%.1f m" % [best_t, best])

## Moves the clouds so `at` is in open sun.
func _clear_sky_at(at: Vector2) -> void:
	for i in 2400:
		if _sky.cover_at(at) < 0.01 and _sky.cover_at(at + Vector2(12, 12)) < 0.01 and _sky.cover_at(at - Vector2(12, 12)) < 0.01:
			break
		_sky._cloud_off += Vector2(0.1, 0.0)
	_sky.cover_here = _sky.cover_at(at)

## Moves the clouds so a cloud edge crosses `at`: shadow on one side, sun on the other.
func _cloud_edge_at(at: Vector2) -> void:
	for i in 2400:
		var c := _sky.cover_at(at)
		if c > 0.4 and c < 0.6 and absf(_sky.cover_at(at + Vector2(8, -8)) - _sky.cover_at(at - Vector2(8, -8))) > 0.8:
			break
		_sky._cloud_off += Vector2(0.1, 0.03)
	_sky.cover_here = _sky.cover_at(at)
	print("[sky-lab] cloud cover at survivor %.2f" % _sky.cover_here)

func _shot(label: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/sky_%s_%s_%dx%d.png" % [shot_dir, label, _tag, img.get_width(), img.get_height()]
	img.save_png(path)
	print("[sky-lab] shot %s sun_scale=%.2f" % [path, _sky.sun_scale])

## Mean frame time (wall clock between drawn frames) with the shadows on and off, interleaved.
## viewport_get_measured_render_time_gpu reads 0 on Metal and on this GL driver, so it is not used.
func _perf() -> void:
	var acc := {true: 0.0, false: 0.0}
	for round_i in 4:
		for on in [true, false]:
			SkyShadows.set_enabled(on, get_tree())
			for i in 30:
				await RenderingServer.frame_post_draw
			var t0 := Time.get_ticks_usec()
			for i in PERF_FRAMES:
				await RenderingServer.frame_post_draw
			acc[on] += float(Time.get_ticks_usec() - t0) / 1000.0 / float(PERF_FRAMES) / 4.0
	SkyShadows.set_enabled(true, get_tree())
	print("[sky-lab] perf on=%.3f ms off=%.3f ms delta=%.3f ms" % [acc[true], acc[false], acc[true] - acc[false]])
