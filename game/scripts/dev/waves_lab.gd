extends Node3D
## WAVES lab: home island, the game camera at its default zoom, the survivor on a sandy beach
## (--view=shore) or swimming 30 m out (--view=sea), one forced weather (--weather=clear|rain|storm),
## midday. --shot-dir=DIR saves waves_<view>_<weather>_<W>x<H>[_compat].png after the sea state settles;
## --frames=N also saves N frames at 10 fps (frames/f_0000.png) for an mp4; --perf prints the frame
## cost of the sea (waves on / the pre-waves shader from --old-shader=PATH / sea hidden), vsync off.
## Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility]
##   res://scenes/dev/waves_lab.tscn -- --lab=waves_lab --view=shore --weather=storm --shot-dir=DIR

var _out := ""
var _view := "shore"
var _state := &"clear"
var _frames := 0
var _perf := false
var _bare := false
var _old := ""
var _player: Player
var _rt: IslandRuntime

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--view="):
			_view = a.substr(7)
		elif a.begins_with("--weather="):
			_state = StringName(a.substr(10))
		elif a.begins_with("--frames="):
			_frames = int(a.substr(9))
		elif a.begins_with("--old-shader="):
			_old = a.substr(13)
		elif a == "--bare":
			_bare = true
		elif a == "--perf":
			_perf = true
	WorldWeather.forced = _state
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	Game.max_creatures_per_island = 0
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

## A gentle sandy beach: walk out from the island centre along rays and keep the first coast whose
## ground falls from +0.3 to -0.3 over at least 6 m. Returns [point at the waterline, seaward dir].
func _beach() -> Array:
	var c := _rt.arrival_point()
	for k in 72:
		var dir := Vector2.from_angle(TAU * float(k) / 72.0)
		var top := -1.0
		var wl := -1.0
		for s in 640:
			var p := dir * float(s) * 0.5
			var h := _rt.surface_y(p.x, p.y)
			if h > 0.3:
				top = float(s) * 0.5
				wl = -1.0
			elif h < -0.05 and top > 0.0 and wl < 0.0:
				wl = float(s) * 0.5
			elif h < -0.3 and wl > 0.0:
				var far := dir * (float(s) * 0.5 + 30.0)
				if wl - top >= 3.0 and _rt.surface_y(far.x, far.y) < -0.5 and absf(dir.angle_to(Vector2(c.x, c.z))) > 0.8:
					var at := dir * wl
					return [Vector3(at.x, 0.0, at.y), Vector3(dir.x, 0.0, dir.y)]
				break
	return [Vector3(c.x, 0, c.z), Vector3(0, 0, 1)]

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_rt = World.runtime as IslandRuntime
	for n in get_tree().get_nodes_in_group("creature"):
		n.queue_free()
	Game.time_of_day = 0.45
	var b := _beach()
	var at: Vector3 = b[0] - (b[1] as Vector3) * 4.0
	if _view == "edge":  # standing at the waterline, feet in the swash
		at = b[0] - (b[1] as Vector3) * 0.5
	if _view == "sea":
		at = b[0] + (b[1] as Vector3) * 30.0
	_player.global_position = Vector3(at.x, _rt.surface_y(at.x, at.z) + 0.5 if _view != "sea" else -0.6, at.z)
	var sea := _rt.get_node("SeaWaves") as SeaWaves
	print("[waveslab] rt at %s h(at)=%.2f h(wl)=%.2f player %s" % [_rt.global_position, _rt.surface_y(at.x, at.z), _rt.surface_y(b[0].x, b[0].z), _player.global_position])
	if _bare:
		(sea.get_node("ShoreWash") as Node3D).visible = false
		if _old != "" and not _perf:  # the pre-waves sea, for a before / after pair
			var old := Shader.new()
			old.code = FileAccess.get_file_as_string(_old)
			sea.water_mat.shader = old
	await get_tree().create_timer(3.5).timeout
	sea.settle()
	print("[waveslab] view=%s weather=%s at=%s state=%.2f wave_amp=%.2f run_up=%.2f renderer=%s quality=%s" % [_view, _state, at,
		sea.state, sea.param("wave_amp"), sea.param("run_up"), RenderingServer.get_current_rendering_method(),
		"high" if SeaWaves.high_quality else "low"])
	if _out != "":
		await _shot("waves_%s_%s%s" % [_view, _state, "_bare" if _bare else ""])
	if _frames > 0:
		await _seq()
	if _perf:
		await _measure(sea)
	if _out != "" or _perf:
		get_tree().quit(0)

func _seq() -> void:
	var dir := _out.path_join("frames_%s_%s" % [_view, _state])
	DirAccess.make_dir_recursive_absolute(dir)
	var imgs: Array[Image] = []
	var t0 := Time.get_ticks_msec()
	for k in _frames:
		while Time.get_ticks_msec() - t0 < k * 100:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() / 2, img.get_height() / 2)
		imgs.append(img)
	for k in imgs.size():
		imgs[k].save_png(dir.path_join("f_%04d.png" % k))
	print("[waveslab] frames %d -> %s" % [imgs.size(), dir])

## GPU and CPU frame time, vsync off, 3 s per pass, each mode twice.
func _measure(sea: SeaWaves) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var water: MeshInstance3D
	for c in _rt.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override == sea.water_mat:
			water = c
	var new_shader := sea.water_mat.shader
	var old_shader: Shader
	if _old != "":
		old_shader = Shader.new()
		old_shader.code = FileAccess.get_file_as_string(_old)
	var skin := sea.get_node_or_null("ShoreWash") as Node3D
	var modes: Array = ["waves", "old", "hidden"] if old_shader else ["waves", "hidden"]
	for rep in 2:
		for mode in modes:
			water.visible = mode != "hidden"
			sea.water_mat.shader = old_shader if mode == "old" else new_shader
			if skin:
				skin.visible = mode == "waves"
			await get_tree().create_timer(0.6).timeout
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
			print("[waveslab] perf view=%s weather=%s quality=%s sea=%s frames=%d wall=%.3fms gpu=%.3fms cpu=%.3fms renderer=%s %dx%d" % [
				_view, _state, "high" if SeaWaves.high_quality else "low", mode, frames, wall, gpu / frames, cpu / frames,
				RenderingServer.get_current_rendering_method(), get_tree().root.size.x, get_tree().root.size.y])
	sea.water_mat.shader = new_shader
	water.visible = true

func _shot(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var compat := "_compat" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else ""
	var path := _out.path_join("%s_%dx%d%s.png" % [stem, get_tree().root.size.x, get_tree().root.size.y, compat])
	img.save_png(path)
	print("[waveslab] shot %s" % path)
