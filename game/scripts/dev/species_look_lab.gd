extends Node3D
## One creature per species, idle, for eyeballing models. --species=a,b (default stegosaurus).
## Asserts each species loads its GLB; with a display, screenshots go to /tmp/dfs-look-<species>.png.

func _ready() -> void:
	Game.lab_force_clips = true
	Game.debug_overlay = false
	LabKit.build(self, 120.0)
	var species := "stegosaurus"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--species="):
			species = a.substr(10)
	call_deferred("_run", species.split(","))

func _run(ids: PackedStringArray) -> void:
	var cam := Camera3D.new()
	add_child(cam)
	for id in ids:
		var s := Spawner.new()
		s.species = StringName(id)
		s.count = 1
		s.position = Vector3(30, 0, 30)
		add_child(s)
		var c: Creature = s.spawn_now()[0]
		await get_tree().create_timer(4.0).timeout  # spawn pop-in finishes well inside this
		assert(c.view.using_glb, "%s loads its GLB" % id)
		print("[looklab] %s using_glb=true" % id)
		var h: float = c.def.height_meters
		cam.look_at_from_position(c.global_position + Vector3(h * 2.5, h * 1.4, h * 3.0), c.global_position + Vector3(0, h * 0.45, 0))
		cam.make_current()
		if DisplayServer.get_name() != "headless":
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/dfs-look-%s.png" % id)
		c.queue_free()
		s.queue_free()
	print("[looklab] PASS")
	get_tree().quit()
