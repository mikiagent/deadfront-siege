extends Node3D
## W2-PLAYER lab. Flat floor: the idle survivor's lowest bone is on the floor and a mid-roll pose
## follows the stick. Island: summons at the island origin are never launched, and walking into a
## compsognathus, zebraceratops and velociraptor on real terrain does not lift her. Exit 1 on any
## failure. Windowed runs save /tmp/dfs-player-<stage>.png:
## godot --path game --resolution 1600x900 -- --lab=player_lab

var player: Player
var cam: Camera3D
var _fails: Array[String] = []

func _ready() -> void:
	var kit := LabKit.build(self, 60.0)
	player = kit["player"]
	Game.debug_overlay = false
	TouchControls.visible = false
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	print("[boot] lab=player_lab")
	call_deferred("_demo")

func _check(ok: bool, what: String) -> void:
	print("[playerlab] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _demo() -> void:
	await get_tree().create_timer(1.0).timeout
	var low := _lowest_bone_y()
	_check(absf(low - 0.0) <= 0.05, "idle lowest bone %.3f m from the floor" % low)
	await _side_shot("1_idle_side")
	player.vitals.energy = player.vitals.max_energy
	Input.action_press(&"move_right")
	player._try_roll()
	Input.action_release(&"move_right")
	await get_tree().create_timer(0.2).timeout
	await _side_shot("2_mid_roll")
	await _island()
	print("[playerlab] %s" % ("PASS" if _fails.is_empty() else "FAIL %s" % [_fails]))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _lowest_bone_y() -> float:
	var sk := player.rig.skeleton
	var low := INF
	for b in sk.get_bone_count():
		low = minf(low, (sk.global_transform * sk.get_bone_global_pose(b)).origin.y)
	return low

func _island() -> void:
	World.harvested.clear()
	World.load_island(self, &"home_grassland", Vector3.ZERO, false)
	var kit_floor := get_node_or_null("Nav/Floor")
	if kit_floor:
		kit_floor.queue_free()
	for c in get_tree().get_nodes_in_group("creatures"):
		c.queue_free()
	cam.current = false
	await get_tree().create_timer(1.0).timeout
	var ground: float = World.runtime.surface_y(player.global_position.x, player.global_position.z)
	_check(absf(_lowest_bone_y() - ground) <= 0.08, "island idle lowest bone %.3f m from the terrain" % (_lowest_bone_y() - ground))
	# Three pets summoned at the island origin.
	for sp: StringName in [&"velociraptor", &"zebraceratops", &"compsognathus"]:
		player.bonded.append(PetRecord.from_def(Data.creature(sp), &"A"))
		player.summon_pet(player.bonded.size() - 1)
	var fast := 0.0
	for i in 120:
		await get_tree().physics_frame
		for c in player.live_pets():
			fast = maxf(fast, c.velocity.length())
	_check(fast <= 15.0, "summons at the island origin: top pet speed %.1f m/s" % fast)
	await get_tree().create_timer(0.5).timeout
	await _save("3_island_summon")
	for i in range(player.bonded.size() - 1, -1, -1):
		player.summon_pet(i)
	await get_tree().process_frame
	for sp: StringName in [&"compsognathus", &"zebraceratops", &"velociraptor"]:
		await _walk_into(sp)

func _walk_into(sp: StringName) -> void:
	var start := Vector3(6.0, 0.0, 6.0)
	start.y = float(World.runtime.surface_y(start.x, start.z)) + player.half_height() + 0.05
	player.velocity = Vector3.ZERO
	player.global_position = start
	await get_tree().create_timer(0.4).timeout
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	var at := start + _cam_forward() * 3.0
	at.y = float(World.runtime.surface_y(at.x, at.z))
	c.position = World.runtime.to_local(at)
	World.runtime.add_child(c)
	c.spawn(Data.creature(sp))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.3).timeout
	var rise := 0.0
	var touched := false
	var goal := start + _cam_forward() * 8.0  # a tap-to-walk route through the animal
	for i in 300:
		if not player.nav_active:
			player.nav_to(player.sim.closest_nav_point(goal))
		await get_tree().physics_frame
		var feet := player.feet_position()
		rise = maxf(rise, feet.y - float(World.runtime.surface_y(feet.x, feet.z)))
		for k in player.get_slide_collision_count():
			touched = touched or player.get_slide_collision(k).get_collider() == c
	player.clear_nav()
	_check(touched and rise <= 0.15, "routed into a %s for 5 s (contact=%s) lifts her %.2f m above the terrain" % [sp, touched, rise])
	c.queue_free()

func _cam_forward() -> Vector3:
	var f := -get_viewport().get_camera_3d().global_basis.z
	f.y = 0.0
	return f.normalized()

func _side_shot(stage: String) -> void:
	var t := player.global_position
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.0
	cam.look_at_from_position(t + Vector3(0.0, 0.2, 8.0), t + Vector3(0.0, 0.1, 0.0))
	await _save(stage)

func _save(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame  # let a moved camera render once
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/dfs-player-%s.png" % stage)
	print("[playerlab] shot %s" % stage)
