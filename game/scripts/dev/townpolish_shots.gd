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
	var anchors := _anchors()
	print("[townshots] anchors %s" % [anchors.keys()])
	for tod: Array in [["day", 0.42], ["night", 0.93]]:
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
			for av: float in [0.0, 72.0, 144.0, -72.0, -144.0]:
				await _gate_shot("gate_%d_%s_%s" % [int(av), tod[0], tag], av)
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

func _gate_shot(name: String, av: float) -> void:
	if not _want(name):
		return
	var wall := 97.0
	var p: Vector3 = _town.call("polar", av, wall - 14.0)
	var g: Vector3 = _town.call("polar", av, wall)
	_place_player(_town.call("polar", av, wall - 6.0))
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
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	img.save_png(path)
	print("[townshots] shot %s fps=%d" % [path, Engine.get_frames_per_second()])
