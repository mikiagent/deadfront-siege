extends Node3D
## Temperate-25 island. Survivor at camp. Headless prints [world] island temperate_25.

var _player: Player
var _cam: IsoCamera

func _ready() -> void:
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	_cam.size = 36.0
	_cam.distance = 28.0
	var nav: Node = kit["nav"]
	nav.visible = false
	LabKit.give(_player, &"work_axe", 1)
	LabKit.give(_player, &"stone_knife_work", 1)
	World.harvested.clear()
	World.load_island(self, &"temperate_25", Vector3(0, 1, 12), false)
	# The lab kit's 20 m placeholder floor pokes through the real island; drop it.
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	_cam._target = _player
	_cam._snap()
	print("[boot] lab=island_lab")
	if Game.shot_path.contains("crater") and World.runtime:
		_player.global_position = Vector3(8.0, 2.0, -177.0)
		if World.runtime.has_method("surface_y"):
			_player.global_position.y = World.runtime.surface_y(_player.global_position.x, _player.global_position.z) + 1.2
		_cam.size = 32.0
		_cam._snap()
	elif Game.shot_path != "":
		call_deferred("_shot_ring_probe")
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		call_deferred("_headless_gather_probe")

func _headless_gather_probe() -> void:
	await _await_nav_ready()
	if World.runtime:
		print("[world] mm=%d nodes=%d creatures=%d" % [
			int(World.runtime.mm_count), int(World.runtime.harvest_count), int(World.runtime.creature_count)])
	var node := _nearest_tree()
	if node == null:
		print("[item] gather probe failed: no tree")
		get_tree().quit(1)
		return
	_tap_node(node)
	var start := node.session_gathered
	var timeout := 30.0
	while timeout > 0.0:
		await get_tree().create_timer(0.2).timeout
		timeout -= 0.2
		if not is_instance_valid(node):
			break
		var gained := node.session_gathered - start
		if gained >= 5:
			print("[item] gather 5/%d done" % node.pool_max)
			get_tree().quit(0)
			return
	print("[item] gather probe timeout")
	get_tree().quit(1)

func _shot_ring_probe() -> void:
	await _await_nav_ready()
	var node := _nearest_tree()
	if node == null:
		return
	var dir := _player.global_position - node.global_position
	dir.y = 0.0
	if dir.length_squared() <= 0.001:
		dir = Vector3.FORWARD
	_player.global_position = node.global_position + dir.normalized() * 1.8
	if World.runtime and World.runtime.has_method("surface_y"):
		_player.global_position.y = World.runtime.surface_y(_player.global_position.x, _player.global_position.z) + 1.0
	_cam._snap()
	_player._begin_gather(node)
	_player._on_arrived()

func _tap_node(node: HarvestNode) -> void:
	if _player == null or _cam == null or node == null:
		return
	var world := node.global_position + Vector3(0.0, node.top_of_node() * 0.5, 0.0)
	var screen := _cam.unproject_position(world)
	_player.debug_tap_screen(screen)

func _nearest_tree() -> HarvestNode:
	var best: HarvestNode
	var best_d := 99999.0
	for n in get_tree().get_nodes_in_group("harvest"):
		var node := n as HarvestNode
		if node == null:
			continue
		if not node.falls_to_log:
			continue
		var d := _player.global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

func _await_nav_ready() -> void:
	while true:
		var map: RID = RID()
		if _player and _player.get_world_3d():
			map = _player.get_world_3d().navigation_map
		if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
			return
		await get_tree().create_timer(0.1).timeout
