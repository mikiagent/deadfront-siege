extends SceneTree
var started := false
func _process(_d: float) -> bool:
	if started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	started = true
	_run.call_deferred()
	return false
func _run() -> void:
	root.get_node("Game").god_mode = true
	var host := Node3D.new(); root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 120.0)
	for i in 5: await physics_frame
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c); c.global_position = Vector3.ZERO
	c.spawn(root.get_node("Data").creature(&"stegosaurus"))
	c.look_at(Vector3(0, 0, -10), Vector3.UP)
	c.brain._roam_pause = 999.0
	for i in 20: await physics_frame
	var b = c.brain
	var pl = kit["player"]
	pl.global_position = Vector3(-3.75, pl.global_position.y, 6.4)
	b.attack_target = pl
	b._provoked_until = b._now_s() + 600.0
	b._set_state(&"attack")
	b._start(&"spin_right")
	print("hips ", b._bone_world("hips"), " club ", b.club_position(), " pivot ", c.global_transform * b._turn_pivot)
	for f in 240:
		await physics_frame
		pl.hunt.stop()
		if b.move_id == &"": break
		var from = b._bone_world("hips")
		var club: Vector3 = b.club_position()
		if f >= 90 and f <= 100:
			var bl = load("res://scripts/combat/melee_query.gd").blocker(c, pl)
			print("blk ", bl, " ", bl.name if bl else "", " feet c=", load("res://scripts/combat/melee_query.gd").feet_y(c), " pl=", load("res://scripts/combat/melee_query.gd").feet_y(pl), " h=", load("res://scripts/combat/melee_query.gd").body_height(c))
		if f % 6 == 0:
			print("f%d u=%.2f turn=%.0f d=%.2f club=(%.1f,%.1f) pl=(%.1f,%.1f) struck=%d" % [f, b.move_t / b.move_len, b.turn_applied, b._flat_seg_dist(pl.global_position, from, club), club.x, club.z, pl.global_position.x, pl.global_position.z, b._struck.size()])
	quit(0)
