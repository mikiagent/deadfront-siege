extends SceneTree
## TOWNPOLISH capture: a fresh new game on the tutorial island (the real main scene, character
## creation finished by --occupation), then the camera walks the town: every district at the game
## camera (default zoom and zoomed out), at street level with the survivor in frame for scale, the
## gates, and an overview, by day and by night. The HUD is hidden. Writes PNGs to --out and quits.
## Run windowed and off-screen (never left running; it quits by itself):
##   Godot --path game --position 6000,3000 --resolution 1600x900 --script res://scripts/dev/townpolish_shots.gd \
##     -- --new-game --occupation=soldier --out=<dir> [--quick] [--only=<substring>]
## --quick: game-camera shots only (the phone pass).

var _started := false
var _out := ""
var _quick := false
var _only := ""
## --tods=day:0.42,dusk:0.68 replaces the default day/night pair (LOOKPASS dusk shots).
var _tods: Array = [["day", 0.42], ["night", 0.93]]
var _player: Node3D
var _town: Node
var _cam: Camera3D
var _street: Camera3D

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--quick":
			_quick = true
		elif a.begins_with("--only="):
			_only = a.substr(7)
		elif a.begins_with("--tods="):
			_tods = []
			for kv in a.substr(7).split(","):
				_tods.append([kv.get_slice(":", 0), float(kv.get_slice(":", 1))])
	DirAccess.make_dir_recursive_absolute(_out)
	var wd := create_timer(900.0)
	wd.timeout.connect(func () -> void:
		print("[townshots] FAIL watchdog")
		quit(2))
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	# The shell normally calls World._boot once the game scene is up (shell/boot.gd); do the same.
	if root.find_children("CharacterCreation", "", true, false).is_empty():
		root.get_node("World").call("_boot")
	var t := 0.0
	while t < 120.0:
		await create_timer(0.5).timeout
		t += 0.5
		_player = root.get_node("World").get_tree().get_first_node_in_group(&"player")
		var rt: Node = root.get_node("World").get("runtime")
		if _player and rt and is_instance_valid(rt) and rt.get_node_or_null("TownDress"):
			_town = rt.get_node("TownDress")
			break
	if _town == null:
		print("[townshots] FAIL no town (player=%s)" % _player)
		quit(1)
		return
	await create_timer(3.0).timeout
	root.get_node("Game").set_process(false)  # the probe holds the clock
	Engine.time_scale = 1.0
	_cam = root.get_viewport().get_camera_3d()
	_street = Camera3D.new()
	_street.fov = 62.0
	_street.far = 600.0
	current_scene.add_child(_street)
	print("[townshots] town %s" % _town.get("stats"))
	var env := root.get_viewport().find_world_3d().environment
	if env == null:
		for we in root.find_children("*", "WorldEnvironment", true, false):
			if (we as WorldEnvironment).environment:
				env = (we as WorldEnvironment).environment
				break
	if env:
		print("[townshots] env renderer=%s ssao=%s ssil=%s sdfgi=%s tonemap=%d exposure=%.2f fog=%.4f" % [RenderingServer.get_current_rendering_method(), env.ssao_enabled, env.ssil_enabled, env.sdfgi_enabled, env.tonemap_mode, env.tonemap_exposure, env.fog_density])
	var view := root.get_visible_rect().size
	var tag := "%dx%d" % [int(view.x), int(view.y)]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hide="):  # debugging: which layer draws what
			var n: Node = _town.get("rt").get_node_or_null(a.substr(7))
			if n:
				n.queue_free()
	if "--cover-debug" in OS.get_cmdline_user_args():
		for gc in root.find_children("*", "GroundCover", true, false):
			var live := 0
			var dead := 0
			for mmi: MultiMeshInstance3D in gc.find_children("*", "MultiMeshInstance3D", true, false):
				for i in mmi.multimesh.instance_count:
					var xf := mmi.global_transform * mmi.multimesh.get_instance_transform(i)
					if xf.basis.get_scale().x < 0.01:
						dead += 1
					elif xf.origin.distance_to(_town.get("camp")) < 85.0:
						live += 1
			print("[townshots] cover %s live_in_town=%d collapsed=%d" % [gc.get_path(), live, dead])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--walkto="):  # debugging: walk the survivor from the camp, print where it gets to
			var xz := a.substr(9).split(",")
			var goal := Vector3(float(xz[0]), 0, float(xz[1]))
			print("[townshots] gates %s" % [_town.get("gates")])
			_place_player(_town.get("camp") + Vector3(4, 0, 6))
			for b in OS.get_cmdline_user_args():
				if b.begins_with("--walkfrom="):
					var fz := b.substr(11).split(",")
					_place_player(Vector3(float(fz[0]), 0, float(fz[1])))
			var hrow := ""
			for zz in range(180, 140, -2):
				hrow += " z%d:%.2f" % [zz, float(_town.get("rt").call("surface_y", -52.5, float(zz)))]
			print("[townshots] heights x=-52.5%s" % hrow)
			var pth: Variant = _town.get("rt").get("pathing")
			var cg: Vector3 = _player.call("_closest_nav_point", goal)
			var pts: PackedVector3Array = pth.call("path", _player.global_position, cg, 0, true)
			var summ := []
			for k in range(0, pts.size(), maxi(1, pts.size() / 25)):
				summ.append(Vector2(pts[k].x, pts[k].z).snapped(Vector2.ONE))
			print("[townshots] route to %s reach=%s n=%d %s" % [cg.snapped(Vector3.ONE), pth.get("last_reachable"), pts.size(), summ])
			for frm: Vector3 in [Vector3(-52, 2, 166), Vector3(-52, 2, 175), Vector3(-52, 2, 190), Vector3(-30, 2, 166)]:
				var p2: PackedVector3Array = pth.call("path", frm, cg, 0, false)
				var s2 := []
				for k in range(0, p2.size(), maxi(1, p2.size() / 12)):
					s2.append(Vector2(p2[k].x, p2[k].z).snapped(Vector2.ONE))
				print("[townshots] route from %s reach=%s n=%d %s" % [frm, pth.get("last_reachable"), p2.size(), s2])
			_player.call("nav_to", _player.call("_closest_nav_point", goal))
			for i in 60:
				await create_timer(1.0).timeout
				if not _player.get("nav_active"):
					_player.call("nav_to", _player.call("_closest_nav_point", goal))
				var hit := ""
				if _player is CharacterBody3D:
					var cb := _player as CharacterBody3D
					for ci in cb.get_slide_collision_count():
						var col := cb.get_slide_collision(ci).get_collider()
						hit += " %s%s" % [col.name if col is Node else str(col), cb.get_slide_collision(ci).get_normal().snapped(Vector3.ONE * 0.01)]
				var pp: PackedVector3Array = _player.get("sim").call("path_points") if _player.get("sim") else PackedVector3Array()
				print("[townshots] walk t=%d at %s hit=%s next=%s" % [i * 2, _player.global_position.snapped(Vector3.ONE * 0.1), hit, pp[pp.size() - 1].snapped(Vector3.ONE) if pp.size() > 0 else "-"])
			quit(0)
			return
	var anchors := _anchors()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--spot="):  # debugging: one extra game shot at x,z
			var xz := a.substr(7).split(",")
			anchors = {"spot": Vector3(float(xz[0]), 0, float(xz[1]))}
			var rt: Node = _town.get("rt")
			for f: Dictionary in rt.get("_shape").get("topo"):
				print("[townshots] topo %s pos=%s r=%.1f reach=%.1f camp_d=%.1f" % [f["kind"], f["pos"], f["r"], f["reach"], (f["pos"] as Vector2).distance_to(Vector2(rt.get("_camp_pos").x, rt.get("_camp_pos").z))])
			var span: int = rt.get("_tile_span")
			var row := ""
			for dz in range(-12, 13, 3):
				for dx in range(-12, 13, 3):
					var tx := int(floor(float(xz[0]) + dx + float(rt.get("_size")) * 0.5))
					var tz := int(floor(float(xz[1]) + dz + float(rt.get("_size")) * 0.5))
					row += "%2d " % (rt.get("tile_types") as PackedByteArray)[tx + tz * span]
				row += "| "
			print("[townshots] tiles ", row)
			var bt: PackedByteArray = load("res://scripts/world/biome_zones.gd").call("biome_types", rt)
			var zrow := ""
			for dz in range(-60, 61, 20):
				for dx in range(-60, 61, 20):
					var cp0: Vector3 = rt.get("_camp_pos")
					var tx := int(floor(cp0.x + dx + float(rt.get("_size")) * 0.5))
					var tz := int(floor(cp0.z + dz + float(rt.get("_size")) * 0.5))
					zrow += "%d" % bt[tx + tz * span]
				zrow += " "
			print("[townshots] zones ", zrow)
			var cp: Vector3 = rt.get("_camp_pos")
			var hs := []
			for r in [0, 20, 40, 60, 80, 100]:
				var line := "r%d:" % r
				for k in 8:
					var ang := TAU * k / 8.0
					line += " %.1f" % rt.call("surface_y", cp.x + cos(ang) * r, cp.z + sin(ang) * r)
				hs.append(line)
			print("[townshots] camp %s heights %s river_d=%.1f" % [cp, hs, rt.call("river_dist_at", cp.x, cp.z)])
	print("[townshots] anchors %s" % [anchors.keys()])
	for tod: Array in _tods:
		await _set_time(float(tod[1]))
		for nm: String in anchors:
			var at: Vector3 = anchors[nm]
			await _game_shot("%s_game_%s_%s" % [nm, tod[0], tag], at, 14.0)
			if tod[0] == "day":
				await _game_shot("%s_wide_%s_%s" % [nm, tod[0], tag], at, 18.0)
			if _quick:
				continue
			await _street_shot("%s_street_%s_%s" % [nm, tod[0], tag], at)
		if _quick:
			continue
		await _over("overview_%s_%s" % [tod[0], tag])
		if tod[0] == "day":
			for gi in 4:
				await _gate_shot("gate_%d_%s_%s" % [gi, tod[0], tag], gi)
	print("[townshots] DONE")
	quit(0)

## One spot per district (the lot nearest the centroid of that district's lots), and a second
## market/homes spot further out, so every shot frames real town pieces.
func _anchors() -> Dictionary:
	var by: Dictionary = {}
	for c: Vector3 in _town.get("lots"):
		var d: StringName = _town.call("district_of", _town.call("_deg_of", c))
		if not by.has(d):
			by[d] = []
		(by[d] as Array).append(c)
	var out := {}
	for d: StringName in by:
		var pts: Array = by[d]
		var mid := Vector3.ZERO
		for p: Vector3 in pts:
			mid += p
		mid /= float(pts.size())
		var best: Vector3 = pts[0]
		for p: Vector3 in pts:
			if p.distance_to(mid) < best.distance_to(mid):
				best = p
		out[str(d)] = best
		var far: Vector3 = best
		for p: Vector3 in pts:
			if p.distance_to(best) > far.distance_to(best):
				far = p
		if far.distance_to(best) > 25.0:
			out[str(d) + "2"] = far
	return out

func _set_time(tod: float) -> void:
	root.get_node("Game").set("time_of_day", tod)
	await create_timer(0.3).timeout

func _hide_ui(on: bool) -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = not on

func _place_player(p: Vector3, yaw: float = 0.0) -> void:
	if _player.has_method("clear_nav"):
		_player.call("clear_nav")
	p.y = float(_town.get("rt").call("surface_y", p.x, p.z))
	_player.global_position = p + Vector3(0, 0.2, 0)
	_player.rotation.y = yaw
	_player.reset_physics_interpolation()

func _want(name: String) -> bool:
	return _only == "" or name.contains(_only)

func _game_shot(name: String, at: Vector3, size: float) -> void:
	if not _want(name):
		return
	_place_player(at)
	_cam.current = true
	_cam.size = size
	if _cam.has_method("_snap"):
		_cam.call("_snap")
	await _save(name)

func _street_shot(name: String, at: Vector3) -> void:
	if not _want(name):
		return
	var c: Vector3 = _town.get("camp")
	var dir := Vector3(at.x - c.x, 0, at.z - c.z).normalized().rotated(Vector3.UP, 0.5)
	var eye := at - dir * 13.0
	eye.y = float(_town.get("rt").call("surface_y", eye.x, eye.z))
	_place_player(eye + dir * 5.0, atan2(dir.x, dir.z) + PI)
	_street.current = true
	_street.global_position = eye + Vector3(0, 2.2, 0)
	_street.look_at(at + Vector3(0, 1.8, 0))
	await _save(name)

func _gate_shot(name: String, i: int) -> void:
	if not _want(name):
		return
	var gs: Array = _town.get("gates")
	if i >= gs.size():
		return
	var g: Vector3 = gs[i]
	var c: Vector3 = _town.get("camp")
	var inward := Vector3(c.x - g.x, 0, c.z - g.z)
	inward = (Vector3(signf(inward.x), 0, 0) if absf(inward.x) > absf(inward.z) else Vector3(0, 0, signf(inward.z)))
	var p := g + inward * 14.0
	p.y = float(_town.get("rt").call("surface_y", p.x, p.z))
	_place_player(g + inward * 6.0)
	_street.current = true
	_street.global_position = p + Vector3(0, 3.0, 0)
	_street.look_at(g + Vector3(0, 1.5, 0))
	await _save(name)

func _over(name: String) -> void:
	if not _want(name):
		return
	var c: Vector3 = _town.get("camp")
	_place_player(c)
	_street.current = true
	_street.global_position = c + Vector3(70, 120, 110)
	_street.look_at(c)
	await _save(name)

func _save(name: String) -> void:
	_hide_ui(true)
	for i in 30:
		await process_frame
	if "--perf" in OS.get_cmdline_user_args():  # LOOKPASS: frame time per shot (run with --disable-vsync)
		var vp := root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		var ms: Array[float] = []
		var gpu := 0.0
		for i in 240:
			var t0 := Time.get_ticks_usec()
			await process_frame
			ms.append((Time.get_ticks_usec() - t0) / 1000.0)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		ms.sort()
		var mean := 0.0
		for m in ms:
			mean += m / ms.size()
		print("[townshots] RESULT perf shot=%s ms_mean=%.2f ms_median=%.2f ms_p95=%.2f gpu_ms=%.2f prims=%d draws=%d" % [name, mean, ms[120], ms[228], gpu / 240.0,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	img.save_png(path)
	print("[townshots] shot %s fps=%d" % [path, Engine.get_frames_per_second()])
