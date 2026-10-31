extends Node
## NORTHUP / ISOCAM capture: a fresh new game on the tutorial island, then the game view at each zoom
## and spot, and the open atlas, saved as PNGs. Quits by itself.
## Run: Godot --path game --position 6000,3000 --resolution 1600x900 -- --skip-charcreate --lab=tutorial --occupation=soldier --new-game --northup-shot=<dir>
##   [--shot-sizes=14,3.5,18] [--shot-spots=dock,square,guild]  (ISOCAM: zooms and places; default: the
##   start zoom at the dock). square = the camp square, guild = in front of the Adventurer's Guild door.

func run(host: Node) -> void:
	var dir := ""
	var sizes: Array = []
	var spots: Array = ["dock"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--northup-shot="):
			dir = a.substr(15)
		elif a.begins_with("--shot-sizes="):
			sizes = Array(a.substr(13).split(",")).map(func (v: String) -> float: return float(v))
		elif a.begins_with("--shot-spots="):
			spots = Array(a.substr(13).split(","))
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(7.5).timeout
	var size := get_viewport().get_visible_rect().size
	var tag := "%dx%d" % [int(size.x), int(size.y)]
	var p := PlayerRegistry.local()
	var cam := get_viewport().get_camera_3d()
	print("[northup] island=%s player=%s harbour=%s" % [World.island_id, p.global_position if p else Vector3.ZERO, World.runtime.get("_harbour_pos") if World.runtime else null])
	if sizes.is_empty():
		await _shot(dir.path_join("game_%s.png" % tag))
	for spot in spots:
		var at := _spot(str(spot))
		if at == Vector3.INF:
			print("[northup] no spot %s" % spot)
			continue
		if p and str(spot) != "dock":
			p.global_position = at
			await get_tree().create_timer(1.5).timeout
		for s in sizes:
			cam.size = s
			await get_tree().create_timer(1.2).timeout
			await _shot(dir.path_join("%s_z%s_%s.png" % [spot, str(s), tag]))
	var hud := host.find_child("HuntHud", true, false)
	if hud and hud.has_method("open_atlas"):
		hud.open_atlas()
		await get_tree().create_timer(1.5).timeout
		await _shot(dir.path_join("map_%s.png" % tag))
	print("[northup] DONE")
	get_tree().quit(0)

func _spot(spot: String) -> Vector3:
	var rt := World.runtime
	match spot:
		"dock":
			return PlayerRegistry.local().global_position
		"square":
			var c: Vector3 = rt.get("_camp_pos")
			return c + Vector3(0, 1, 8)
		"guild":
			for n in get_tree().get_nodes_in_group("town_building"):
				if str(n.name) == "AdventurersGuild":
					return (n as Node3D).global_position + Vector3(5.5, 1, 5.5)  # outside the south-east door
	return Vector3.INF

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[northup] shot %s" % path)
