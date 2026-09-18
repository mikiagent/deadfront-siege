extends Node3D
## Temperate-25 island. Survivor at camp. Headless prints [world] island temperate_25.

var _player: Player
var _cam: IsoCamera

func _ready() -> void:
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	_cam.size = 19.0
	_cam.distance = 28.0
	var nav: Node = kit["nav"]
	nav.visible = false
	if Game.shot_path != "":
		TouchControls.visible = false
		TouchControls.enabled = false
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
	if Game.shot_path.contains("shore") and World.runtime:
		var r: float = World.runtime.land_radius() * 1.12
		_player.global_position = Vector3(r * 0.2, 2.0, r * 0.98)
		if World.runtime.has_method("surface_y"):
			_player.global_position.y = World.runtime.surface_y(_player.global_position.x, _player.global_position.z) + 1.2
		_cam._snap()
	if Game.shot_path.contains("night"):
		Game.time_of_day = 0.9
	if Game.shot_path.contains("crater") and World.runtime:
		_player.global_position = Vector3(8.0, 2.0, -177.0)
		if World.runtime.has_method("surface_y"):
			_player.global_position.y = World.runtime.surface_y(_player.global_position.x, _player.global_position.z) + 1.2
		_cam.size = 17.0
		_cam._snap()
		call_deferred("_log_draw_calls", "crater")
	elif Game.shot_path.contains("tiles"):
		call_deferred("_shot_tiles_probe")
	elif Game.shot_path.contains("radial"):
		call_deferred("_shot_radial_probe")
	elif Game.shot_path != "" and not (Game.shot_path.contains("shore") or Game.shot_path.contains("night") or Game.shot_path.contains("ctx")):
		call_deferred("_shot_ring_probe")
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		call_deferred("_headless_gather_probe")

func _headless_gather_probe() -> void:
	await _await_nav_ready()
	if World.runtime:
		print("[world] mm=%d nodes=%d creatures=%d" % [
			int(World.runtime.mm_count), int(World.runtime.harvest_count), int(World.runtime.creature_count)])
	var tree := _nearest_tree()
	if tree:
		var opts := tree.options()
		if opts.size() > 1:
			tree.select_option(1)
			print("[item] option %s x%d-%d %.1fs (of %d options)" % [tree.yield_def_id, tree.yield_min, tree.yield_max, tree.gather_seconds, opts.size()])
			# Gather two units with that option, as the tap flow would after arriving.
			var dir := _player.global_position - tree.global_position
			dir.y = 0.0
			if dir.length_squared() <= 0.001:
				dir = Vector3.FORWARD
			_player.global_position = tree.global_position + dir.normalized() * 1.8
			if World.runtime and World.runtime.has_method("surface_y"):
				_player.global_position.y = World.runtime.surface_y(_player.global_position.x, _player.global_position.z) + 1.0
			_player._begin_gather(tree)
			_player._on_arrived()
			var wait := 12.0
			while wait > 0.0 and tree.session_gathered < 2:
				await get_tree().create_timer(0.25).timeout
				wait -= 0.25
			print("[item] option gather done units=%d" % tree.session_gathered)
			_player._stop_gather_cycle(false)
	if Game.fast_regen_mult > 1.0:
		var berry := _nearest_family("berry_bush")
		if berry:
			berry.pool = 1.0
			berry.consume_unit()
			var wait_left := 8.0
			while wait_left > 0.0 and berry.depleted:
				await get_tree().create_timer(0.2).timeout
				wait_left -= 0.2
	get_tree().quit(0)

func _shot_tiles_probe() -> void:
	await _await_nav_ready()
	var berry := _nearest_family("berry_bush")
	if berry:
		berry.pool = 1.0
		berry.consume_unit()
		var behind := (_player.global_position - berry.global_position).normalized()
		if behind.length_squared() <= 0.0001:
			behind = Vector3.FORWARD
		_player.global_position = berry.global_position + behind * 2.2
		if World.runtime and World.runtime.has_method("surface_y"):
			_player.global_position.y = World.runtime.surface_y(_player.global_position.x, _player.global_position.z) + 1.0
		_cam.size = 18.0
		_cam._snap()
		await _log_draw_calls("tiles")

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
	await _log_draw_calls("camp")

func _tap_node(node: HarvestNode) -> void:
	if _player == null or _cam == null or node == null:
		return
	var world := node.global_position + Vector3(0.0, node.top_of_node() * 0.5, 0.0)
	var screen := _cam.unproject_position(world)
	_player.debug_tap_screen(screen)

func _nearest_family(family: String) -> HarvestNode:
	for n in get_tree().get_nodes_in_group("harvest"):
		var node := n as HarvestNode
		if node and node.family == family:
			return node
	return null

func _log_draw_calls(tag: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var draws := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	print("[world] draws %s=%d" % [tag, draws])

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

func _shot_radial_probe() -> void:
	await _await_nav_ready()
	var node := _nearest_tree()
	if node == null:
		return
	var dir := _player.global_position - node.global_position
	dir.y = 0.0
	if dir.length_squared() <= 0.001:
		dir = Vector3.FORWARD
	_player.global_position = node.global_position + dir.normalized() * 3.0
	if World.runtime and World.runtime.has_method("surface_y"):
		_player.global_position.y = World.runtime.surface_y(_player.global_position.x, _player.global_position.z) + 1.0
	_cam._snap()
	_player.debug_open_radial(node)
