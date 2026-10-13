extends Node3D
## Real-world seeded berry-pool/rendering fixture; not earned progression.
var player: Player
var runtime: Node3D
var bushes: Array[HarvestNode] = []

func _ready() -> void:
	var kit := LabKit.build(self, 24.0)
	player = kit["player"]
	Game.max_creatures_per_island = 0
	Game.debug_overlay = false
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 12), false)
	runtime = World.runtime
	var floor := get_node_or_null("Nav/Floor")
	if floor:
		floor.queue_free()
	var cam: IsoCamera = kit["cam"]
	cam.size = 14.0
	cam._snap()
	call_deferred("_demo")

func _demo() -> void:
	await get_tree().create_timer(0.6).timeout
	# Isolated closest legal clump: four mapped bushes, full/empty paira and pairb.
	for i in 4:
		var pos := player.global_position + Vector3(-5.0 + float(i % 2) * 4.0, 0, -4.0 - float(i / 2) * 4.0)
		runtime._plant_at("berry_bush", "berryfixture_%d" % i, pos, &"berry", &"none", "grassland", 1, Color.GREEN)
		var n: HarvestNode = runtime._harvest_nodes["berryfixture_%d" % i]
		bushes.append(n)
	for b in runtime._batches:
		b.commit()
	for n in runtime._harvest_nodes.values():
		n.refresh_batched_visual()
	var cam := get_viewport().get_camera_3d() as IsoCamera
	cam.size = 7.0
	player.global_position = bushes[0].global_position + Vector3(0, 1, 2.0)
	cam._snap()
	# First half full, second half depleted via actual yield-consumption entrypoint.
	for i in [2, 3]:
		_empty(bushes[i])
	for i in 4:
		_verify(bushes[i], i < 2)
	await _capture("mixed")
	for i in [0, 1]:
		_empty(bushes[i])
		_verify(bushes[i], false)
	await _capture("empty")
	for bush in bushes:
		bush._process(91.0)
		_verify(bush, true)
	# Explicit restore and berry-vs-fibre pool distinction.
	var n := bushes[0]
	var snap := n.pools_snapshot()
	n.restore_pools({"pools": {"berry": 0.0, "fibre_stalk": 3.0}, "maxes": {"berry": 10, "fibre_stalk": 3}, "regen": {"berry": 90.0}})
	_verify(n, false)
	assert(not n.depleted, "fibre availability keeps harvesting active")
	n.restore_pools(snap)
	_verify(n, true)
	for b in runtime._batches:
		b.commit()
	for bush in bushes:
		_verify(bush, true)
	await _capture("regrown")
	if DisplayServer.get_name() != "headless":
		get_tree().quit(0)
		return
	var min_d: float = 999.0
	var mapped: Array[HarvestNode] = []
	for other in runtime._harvest_nodes.values():
		if is_instance_valid(other) and other._empty_batch and not str(other.node_id).begins_with("berryfixture"):
			mapped.append(other)
	for a in mapped:
		for b in mapped:
			if a != b:
				min_d = minf(min_d, Vector2(a.position.x-b.position.x, a.position.z-b.position.z).length())
	assert(min_d >= 3.8, "generated berry clump centre separation")
	# Move across the fixture clump with normal navigation, no collider changes.
	player.nav_to(player._closest_nav_point(player.global_position + Vector3(-3, 0, -10)))
	var start := player.global_position
	await get_tree().create_timer(6.0).timeout
	assert(player.global_position.distance_to(start) > 3.0, "walk route makes progress through bush clump")
	print("[berrylab] PASS both variants consume/refill/restore; nodes=%d min_separation=%.2f walk_progress=%.2f" % [mapped.size(), min_d, player.global_position.distance_to(start)])
	get_tree().quit(0)

func _empty(n: HarvestNode) -> void:
	n.yield_def_id = &"berry"
	while n.units_left_for(&"berry") > 0:
		n.consume_unit()

func _verify(n: HarvestNode, full: bool) -> void:
	assert(n.berries_available() == full)
	assert(n.visible, "empty foliage persists")
	assert(n._batch._xforms[n._batch_idx] == n._empty_batch._xforms[n._empty_batch_idx], "identical transform for both states")
	assert(bool(n._batch._shown.get(n._batch_idx, true)) == full)
	assert(bool(n._empty_batch._shown.get(n._empty_batch_idx, true)) != full)
	if n.depleted:
		assert(n.collision_layer == 0 and n.get_node("TapZone").collision_layer == 0)

func _capture(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/dfs-berries-" + stage + ".png")
