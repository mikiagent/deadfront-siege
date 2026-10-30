extends Node
## NORTHUP capture: a fresh new game on the tutorial island, then the game view (minimap north-up,
## the dock's anchor below the survivor) and the open atlas, saved as PNGs. Quits by itself.
## Run: Godot --path game --position 6000,3000 --resolution 1600x900 -- --lab=tutorial --occupation=soldier --new-game --northup-shot=<dir>
## (--lab=tutorial: its own fresh save folder; --occupation finishes character creation at once)

func run(host: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--northup-shot="):
			dir = a.substr(15)
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(1.5).timeout
	await get_tree().create_timer(6.0).timeout
	var size := get_viewport().get_visible_rect().size
	var tag := "%dx%d" % [int(size.x), int(size.y)]
	var p := PlayerRegistry.local()
	print("[northup] island=%s player=%s harbour=%s" % [World.island_id, p.global_position if p else Vector3.ZERO, World.runtime.get("_harbour_pos") if World.runtime else null])
	await _shot(dir.path_join("game_%s.png" % tag))
	var hud := host.find_child("HuntHud", true, false)
	if hud and hud.has_method("open_atlas"):
		hud.open_atlas()
		await get_tree().create_timer(1.5).timeout
		await _shot(dir.path_join("map_%s.png" % tag))
	print("[northup] DONE")
	get_tree().quit(0)

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[northup] shot %s" % path)
