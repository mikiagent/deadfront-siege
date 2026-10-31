extends SceneTree
var started := false
func _process(_d: float) -> bool:
	if started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	started = true
	_run.call_deferred()
	return false
func _run() -> void:
	var host := Node3D.new(); root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 80.0)
	for i in 5: await physics_frame
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c); c.global_position = Vector3.ZERO
	c.spawn(root.get_node("Data").creature(StringName(OS.get_cmdline_user_args()[0])))
	c.look_at(Vector3(0, 0, -10), Vector3.UP)
	c.brain._roam_pause = 999.0
	for i in 20: await physics_frame
	var b = c.brain
	print("tree callback ", c.anim.tree.callback_mode_process)
	var pl = kit["player"]
	pl.global_position = Vector3(-4, pl.global_position.y, 6)
	root.get_node("Game").god_mode = true
	b.attack_target = pl
	b._provoked_until = b._now_s() + 600.0
	b._set_state(&"attack")
	b._start(StringName(OS.get_cmdline_user_args()[1]))
	print("after start mv=", b.move_id, " state=", b.state)
	await physics_frame
	print("after 1 frame mv=", b.move_id, " state=", b.state, " busy=", c.anim._busy)
	var sk: Skeleton3D = c.view.rig.skeleton
	var bn: String = OS.get_cmdline_user_args()[2]
	for f in 240:
		await physics_frame
		var p := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bn)).origin
		if f > 60 and f < 200:
			print("f%d u=%.3f os_t=%.3f turn=%.1f expect=%.1f mv=%s clip=%s foot=(%.3f,%.3f,%.3f)" % [f, c.anim._os_t / b._clip_length, c.anim._os_t, b.turn_applied, b.turn_at(c.anim._os_t / b._clip_length), b.move_id, c.anim.current_clip, p.x, p.y, p.z])
	quit(0)
