extends Node3D
## Deterministic verification of movement input, gather->inventory and respawn/combat clearing.
## Answers QA claims with ground truth rather than browser guesswork. Prints [probe] lines.

var player: Player
var failures: Array[String] = []

func _ready() -> void:
	var kit := LabKit.build(self, 40.0)
	player = kit["player"]
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.3).timeout

	await _probe_movement()
	_probe_gather()
	await _probe_respawn()

	if failures.is_empty():
		print("[probe] PASS")
	else:
		for f in failures:
			push_error("[probe] FAIL %s" % f)
		print("[probe] FAIL count=%d" % failures.size())
	if Game.shot_path == "":
		get_tree().quit(0 if failures.is_empty() else 1)

func _release_all() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right", "sprint"]:
		if InputMap.has_action(a):
			Input.action_release(a)

func _press_and_measure(action: String, seconds: float) -> float:
	var start := player.global_position
	Input.action_press(action)
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	Input.action_release(action)
	await get_tree().physics_frame
	return start.distance_to(player.global_position)

func _probe_movement() -> void:
	var have_actions := InputMap.has_action("move_up") and InputMap.has_action("move_down") \
		and InputMap.has_action("move_left") and InputMap.has_action("move_right")
	print("[probe] move_actions_present=%s" % have_actions)
	if not have_actions:
		failures.append("move_* InputMap actions missing")
		return
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		player.velocity = Vector3.ZERO
		var moved := await _press_and_measure(action, 0.6)
		print("[probe] %s moved=%.3f m" % [action, moved])
		if moved < 0.2:
			failures.append("%s produced no movement (%.3f m)" % [action, moved])
	# Sprint should cover more ground than a plain tap over the same window.
	player.velocity = Vector3.ZERO
	var walk := await _press_and_measure("move_up", 0.6)
	player.velocity = Vector3.ZERO
	Input.action_press("sprint")
	var sprint := await _press_and_measure("move_up", 0.6)
	Input.action_release("sprint")
	print("[probe] walk=%.3f sprint=%.3f sprint_faster=%s" % [walk, sprint, sprint > walk])
	_release_all()

func _probe_gather() -> void:
	var node: HarvestNode = preload("res://scenes/world/harvest_node.tscn").instantiate()
	add_child(node)
	node.global_position = player.global_position + Vector3(1.5, 0, 0)
	# Bare-handed berry pool, no tool required.
	node.setup(&"probe_bush", &"berries", 1, 1, {"level": 1}, &"none",
		Color(0.4, 0.7, 0.35), 1.0, 0.0, "", false, 5)
	var can := node.can_gather(player.inventory)
	print("[probe] gather_can='%s' pool=%d" % [can, node.pool_units_left()])
	var before_slots := player.inventory.used_slots()
	var before_count := _count_item(&"berries")
	# Drive the real completion path the running game uses.
	player.gather_target = node
	player._gathering = false
	player._finish_gather()
	var after_slots := player.inventory.used_slots()
	var after_count := _count_item(&"berries")
	print("[probe] gather before_slots=%d after_slots=%d berries %d->%d" % [before_slots, after_slots, before_count, after_count])
	if after_count <= before_count:
		failures.append("gather did not add berries to inventory (%d->%d)" % [before_count, after_count])

func _count_item(id: StringName) -> int:
	var total := 0
	for i in player.inventory.slot_count:
		var s = player.inventory.slots[i]
		if s != null and s.def_id == id:
			total += s.count
	return total

func _probe_respawn() -> void:
	# Simulate a very recent hit, then verify the in-combat window is live.
	player._last_hit_taken_s = Time.get_ticks_msec() * 0.001
	await get_tree().physics_frame
	var combat_after_hit := player.vitals.in_combat
	# Kill and respawn.
	player.vitals.take_damage(player.vitals.max_health + 50.0)
	await get_tree().physics_frame
	var died := player.dead
	player.respawn()
	await get_tree().physics_frame
	var revived := not player.dead
	var statuses_cleared := player.statuses == null or player.statuses.instances().is_empty()
	var hunt_target := player.hunt != null and player.hunt.target != null
	var combat_right_after_respawn := player.vitals.in_combat
	# Now age the last-hit timestamp past the 5 s window and re-evaluate.
	player._last_hit_taken_s = -1000.0
	await get_tree().physics_frame
	var combat_after_window := player.vitals.in_combat
	print("[probe] respawn died=%s revived=%s statuses_cleared=%s hunt_target=%s in_combat[hit=%s afterRespawn=%s afterWindow=%s]" % [
		died, revived, statuses_cleared, hunt_target,
		combat_after_hit, combat_right_after_respawn, combat_after_window])
	if not revived:
		failures.append("respawn did not revive the player")
	if hunt_target:
		failures.append("hunt target still set after respawn")
	if combat_after_window:
		failures.append("in_combat stayed true after the 5s window (would trap the player)")
