extends Node
## FACTIONS windowed shots: a fresh new game on the tutorial island; the survivor stands on the square
## facing the Faction Hall, then at the dock arrival, then the Factions screen opens on the Company with
## some reputation and missions. PNGs into the --faction-shots=<dir> folder, named by window size.
## Run: Godot --path game --position 6000,3000 --resolution 1600x900 -- --faction-shots=<dir> --new-game --occupation=<id>
## Quits by itself.

func run(host: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--faction-shots="):
			dir = a.trim_prefix("--faction-shots=")
	DirAccess.make_dir_recursive_absolute(dir)
	var tag := "%dx%d" % [get_viewport().size.x, get_viewport().size.y]
	await get_tree().create_timer(1.5).timeout
	await get_tree().create_timer(4.0).timeout
	var player := PlayerRegistry.local()
	if not World.is_tutorial():
		print("[faction-shots] FAIL not on the tutorial island (pass --occupation=<id> --new-game)")
		get_tree().quit(1)
		return
	var rt: IslandRuntime = World.runtime
	if player == null or rt == null:
		print("[faction-shots] FAIL no survivor")
		get_tree().quit(1)
		return
	var cam := get_viewport().get_camera_3d()
	var fwd := Vector3(0, 0, -1)
	if cam:
		fwd = -cam.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
	# The camera looks along `fwd`: stand short of each subject so it sits in the upper middle of the view.
	var spots := {"hall": Tutorial.plaza_polar(rt, Tutorial.HALL_DEG, 29.0) - fwd * 17.0, "boards": Tutorial.plaza_polar(rt, Tutorial.HALL_DEG, 15.0) - fwd * 8.0,
		"plaza": rt._camp_pos - fwd * 6.0, "dock": rt.arrival_point()}
	for k in spots:
		var p: Vector3 = spots[k]
		p.y = rt.surface_y(p.x, p.z) + 0.2
		player.global_position = p
		player.velocity = Vector3.ZERO
		await get_tree().create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("hall_%s_%s.png" % [k, tag]))
	Factions.add_rep("company", 120, player)
	Factions.add_rep("chlorophyll_forum", 40, player)
	Tasks.accept("faction.company.fuel", player)
	Tasks.accept("faction.chlorophyll_forum.berries", player)
	Tasks.note(&"gather:berries", 8)
	var hud := get_tree().get_first_node_in_group("hud")
	var comms: CommsUI = hud.call("open_comms", "company")
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("factions_company_%s.png" % tag))
	comms.select("chlorophyll_forum")
	comms.receive("faction.chlorophyll_forum.berries")
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("factions_forum_receive_%s.png" % tag))
	print("[faction-shots] done %s" % tag)
	get_tree().quit(0)
