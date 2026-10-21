extends Node3D
## CAMERA package lab (claude/mmo-camera): the survivor on an island with the real HUD, for the
## camera's shots, frame time and motion gate. Works with whatever IsoCamera the build has (it only
## sets size and snaps), so the same lab measures the camera before and after.
##   --cam-island=<id>      island (default home_grassland)
##   --cam-spot=home|forest home: the island's spawn (0, 18); forest: beside the densest stand of
##                          tall trees within 70 m of camp (default forest)
##   --cam-size=<m>         zoom (IsoCamera reads it too)
##   --cam-shots=<dir>      windowed: saves <dir>/<spot>.png, and for the forest a parallax series
##                          <dir>/<spot>_pan_<-6|0|6>.png (the survivor and camera 6 m left/right along
##                          the screen), then quits. Prints each tall tree's on-screen lean.
##   --cam-perf             windowed, with --disable-vsync: 300 frames standing, 300 walking; prints
##                          "[cam] perf stand|walk mean median p95 ms, draw calls"
##   --cam-motion           walks right then up for 3 s each with the move actions at 60 fps and logs
##                          the survivor's chest on screen every frame; "[cam] motion PASS" when no frame
##                          steps more than MAX_JERK px off the frame before it (no jumps)
## --cam-ortho (the old orthographic camera, where the build has one) passes through to IsoCamera.

const TALL_M := 2.4
const MAX_JERK := 2.0
const PERF_FRAMES := 300

var _player: Player
var _cam: Camera3D
var _spot := "forest"
var _shots := ""
var _trees: Array[Dictionary] = []  # {"base": Vector3, "top": Vector3}

func _ready() -> void:
	Game.debug_overlay = false
	var island := &"home_grassland"
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--cam-island="):
			island = StringName(a.substr(13))
		elif a.begins_with("--cam-spot="):
			_spot = a.substr(11)
		elif a.begins_with("--cam-shots="):
			_shots = a.substr(12)
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	_cam = kit["cam"]
	(kit["nav"] as Node).queue_free()
	World.home_terrain = &"meadow"
	World.load_island(self, island, Vector3(0, 1, 18), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	for a in args:
		if a.begins_with("--cam-size="):
			_cam.size = float(a.substr(11))
	if _spot == "forest":
		_stand_in_forest()
	_snap()
	print("[boot] lab=camera_lab island=%s spot=%s cam size=%.1f projection=%d fov=%.2f pitch=%.3f" % [
		island, _spot, _cam.size, _cam.projection, _cam.fov, _cam.rotation_degrees.x])
	if "--cam-perf" in args:
		_perf.call_deferred()
	elif "--cam-motion" in args:
		_motion.call_deferred()
	elif _shots != "":
		_take_shots.call_deferred()

func _snap() -> void:
	_player.reset_physics_interpolation()
	_cam.set("_target", _player)
	_cam.call("_snap")

func _ground(x: float, z: float) -> float:
	var rt := World.runtime
	return float(rt.call("surface_y", x, z)) if rt and rt.has_method("surface_y") else 0.0

## The tall VegBatch instances (trees, palms) as world base and top points.
func _collect_trees() -> void:
	_trees.clear()
	var rt := World.runtime
	if rt == null:
		return
	for b: VegBatch in rt.get("_batches"):
		if not is_instance_valid(b):
			continue
		var xfs: Array[Transform3D] = b.get("_xforms")
		var mh: float = b.get("_mesh_h")
		var shown: Dictionary = b.get("_shown")
		for i in xfs.size():
			if not bool(shown.get(i, true)):
				continue  # harvested, or the depleted twin of a standing tree
			var g := b.global_transform * xfs[i]
			var h := g.basis.get_scale().y * mh
			if h >= TALL_M:
				_trees.append({"base": g.origin, "top": g.origin + Vector3.UP * h})

func _stand_in_forest() -> void:
	_collect_trees()
	var camp: Vector3 = World.runtime.get("_camp_pos") if World.runtime else Vector3.ZERO
	var best := -1
	var best_n := -1
	for i in _trees.size():
		var p: Vector3 = _trees[i]["base"]
		if Vector2(p.x - camp.x, p.z - camp.z).length() > 70.0:
			continue
		var n := 0
		for t in _trees:
			if (t["base"] as Vector3).distance_to(p) < 9.0:
				n += 1
		if n > best_n:
			best_n = n
			best = i
	if best < 0:
		print("[cam] no tall tree within 70 m of camp; staying at the spawn")
		return
	var at: Vector3 = _trees[best]["base"]
	# Behind the tree as the camera sees it (the camera sits towards +x/+z), so its crown covers her.
	var stand := at + Vector3(-1.6, 0.0, -1.6)
	_player.global_position = Vector3(stand.x, _ground(stand.x, stand.z) + 1.0, stand.z)
	print("[cam] forest: %d tall trees within 9 m of %s (%.1f m tall; camp %s)" % [best_n, at, (_trees[best]["top"] as Vector3).y - at.y, camp])

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

func _take_shots() -> void:
	DirAccess.make_dir_recursive_absolute(_shots)
	await get_tree().create_timer(2.6).timeout
	await _shot(_shots.path_join("%s.png" % _spot))
	if _spot == "forest":
		var right := _cam.global_basis.x
		right.y = 0.0
		right = right.normalized()
		var home := _player.global_position
		for off in [-6, 0, 6]:
			var p := home + right * float(off)
			_player.global_position = Vector3(p.x, _ground(p.x, p.z) + 1.0, p.z)
			_snap()
			await _settle(20)
			_report_lean(off)
			await _shot(_shots.path_join("%s_pan_%d.png" % [_spot, off]))
	get_tree().quit(0)

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[cam] shot %s" % path)

## Screen vector from each on-screen tall tree's base to its top (the 3D lean the projection gives,
## before any shader parallax), for the trees nearest the screen's left and right edges and centre.
func _report_lean(off: int) -> void:
	if _trees.is_empty():
		_collect_trees()
	var view := get_viewport().get_visible_rect().size
	var rows: Array[String] = []
	for t in _trees:
		var b: Vector3 = t["base"]
		var tp: Vector3 = t["top"]
		if _cam.is_position_behind(b):
			continue
		var sb := _cam.unproject_position(b)
		var st := _cam.unproject_position(tp)
		if sb.x < 0.0 or sb.x > view.x or sb.y < 0.0 or sb.y > view.y:
			continue
		var d := st - sb
		rows.append("x=%4.0f y=%4.0f lean %+6.1f px over %5.1f px (%+.2f deg)" % [sb.x, sb.y, d.x, -d.y, rad_to_deg(atan2(d.x, -d.y))])
	rows.sort()
	print("[cam] pan %+d m: %d tall trees on screen" % [off, rows.size()])
	for r in rows:
		print("[cam]   " + r)

func _perf() -> void:
	Engine.max_fps = 0
	TouchControls.visible = false
	# The Mac's compositor can hold frames at the display rate even with vsync off, so also read the
	# viewport's own measured CPU/GPU render time, and --cam-ss2 renders 3D at 2x to get above the cap.
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if "--cam-ss2" in OS.get_cmdline_user_args():
		get_viewport().scaling_3d_scale = 2.0
	await get_tree().create_timer(3.0).timeout
	var stand := await _time_frames(PERF_FRAMES)
	Input.action_press("move_right")
	await _settle(30)
	var walk := await _time_frames(PERF_FRAMES)
	Input.action_release("move_right")
	print("[cam] perf stand %s" % stand)
	print("[cam] perf walk  %s" % walk)
	get_tree().quit(0)

func _time_frames(n: int) -> String:
	var dts: Array[float] = []
	var draws := 0.0
	var cpu := 0.0
	var gpu := 0.0
	var vp := get_viewport().get_viewport_rid()
	var last := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		dts.append(float(now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var sorted := dts.duplicate()
	sorted.sort()
	var mean := 0.0
	for d in dts:
		mean += d
	mean /= float(n)
	return "mean %.3f median %.3f p95 %.3f ms, render cpu %.3f gpu %.3f ms, draw calls %.0f" % [
		mean, sorted[n / 2], sorted[int(n * 0.95)], cpu / float(n), gpu / float(n), draws / float(n)]

func _motion() -> void:
	Engine.max_fps = 60
	await get_tree().create_timer(2.0).timeout
	var worst := 0.0
	var worst_at := ""
	var frames := 0
	for action in ["move_right", "move_up"]:
		Input.action_press(action)
		var prev := Vector2.INF
		var prev_d := Vector2.INF
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3000:
			await get_tree().process_frame
			var s := _cam.unproject_position(_player.get_global_transform_interpolated().origin + Vector3.UP * 0.3)
			if prev != Vector2.INF:
				var d := s - prev
				if prev_d != Vector2.INF:
					var jerk := (d - prev_d).length()
					frames += 1
					if jerk > worst:
						worst = jerk
						worst_at = "%s frame %d (step %s after %s)" % [action, frames, d, prev_d]
				prev_d = d
			prev = s
		Input.action_release(action)
		await _settle(10)
	print("[cam] motion: %d frames, largest frame-to-frame change of the survivor's screen step %.2f px at %s" % [frames, worst, worst_at])
	print("[cam] motion %s" % ("PASS" if worst <= MAX_JERK else "FAIL"))
	get_tree().quit(0 if worst <= MAX_JERK else 1)
