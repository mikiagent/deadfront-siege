extends Node3D
## Seeded sleep/fatigue fixture, not earned progression. Real tent menu and sleep code.
var player: Player
var tent: Node3D

func _ready() -> void:
	var kit := LabKit.build(self, 24.0)
	player = kit["player"]
	var cam: IsoCamera = kit["cam"]
	Game.debug_overlay = false
	Game.max_creatures_per_island = 0
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 12), false)
	for n in get_tree().get_nodes_in_group("creature"):
		n.queue_free()
	var floor := get_node_or_null("Nav/Floor")
	if floor:
		floor.queue_free()
	cam.size = 7.0
	cam._snap()
	tent = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"tent")
	tent.position = player.global_position + Vector3(2.5, 0, 0)
	tent.position.y = World.runtime.surface_y(tent.position.x, tent.position.z)
	World.runtime.add_child(tent)
	player.vitals.fatigue = 96.0
	player._last_hit_taken_s = -999.0
	call_deferred("_demo")

func _demo() -> void:
	await get_tree().create_timer(0.7).timeout
	player._interact_tap_target(tent)
	assert(player.station_craft.menu.visible)
	assert(player._sleep_left == 0.0, "Tent tap opens menu, does not auto-sleep")
	print("[sleeplab] tent tap opens explicit SLEEP menu")
	if Game.shot_path != "":
		return
	await _capture("menu")
	player.station_craft.menu._on_pressed(&"sleep")
	# Tapping SLEEP from out of reach walks the survivor to the bedding first.
	var waited := 0.0
	while player._sleep_left <= 0.0 and waited < 6.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	assert(player._sleep_left > 0.0, "the sleep button walks over, then sleeps")
	assert(player.global_position.distance_to(tent.global_position) <= 0.5, "lies down inside the tent")
	assert(player.anim.current_clip == &"sleep_down")
	await get_tree().create_timer(1.5).timeout
	await _capture("down")
	await get_tree().create_timer(3.0).timeout
	assert(player.anim.current_clip == &"sleep")
	assert(player.anim.rig.anim_player.get_animation(&"sleep").loop_mode == Animation.LOOP_LINEAR)
	await _capture("loop")
	await get_tree().create_timer(0.8).timeout
	Input.action_press("move_left")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_left")
	assert(player._sleep_left == 0.0 and int(tent.get("sleeps_left")) == 6)
	assert(player.anim.current_clip == &"sleep_up")
	await get_tree().create_timer(1.1).timeout
	await _capture("up")
	await get_tree().create_timer(3.0).timeout
	assert(str(player.anim.current_clip).begins_with("idle"))
	# Waking stands the survivor up OUTSIDE the bedding, on the ground, never under the map.
	var away := player.global_position.distance_to(tent.global_position)
	assert(away >= 1.0, "wakes up outside the tent (%.2f m from its centre)" % away)
	var ground: float = float(World.runtime.surface_y(player.global_position.x, player.global_position.z))
	assert(player.global_position.y > ground, "stands above the ground (y=%.2f vs ground %.2f)" % [player.global_position.y, ground])
	await _capture("awake")
	print("[sleeplab] movement interrupts without consuming use; up returns to idle, outside the tent")
	player._start_sleep(tent)
	await get_tree().create_timer(10.5).timeout
	assert(player._sleep_left == 0.0 and player.vitals.fatigue < 1.0)
	assert(int(tent.get("sleeps_left")) == 5)
	assert(player.anim.current_clip == &"sleep_up")
	await get_tree().create_timer(3.0).timeout
	assert(str(player.anim.current_clip).begins_with("idle") and not player.anim._waking)
	player.vitals.fatigue = 60.0
	player._start_sleep(tent)
	player.vitals.take_damage(1.0)
	assert(player._sleep_left == 0.0 and not player.anim._sleeping and not player.anim._waking)
	assert(int(tent.get("sleeps_left")) == 5)
	print("[sleeplab] completed sleep restores fatigue, consumes exactly one use; damage interrupts without use")
	player.anim.force_awake()
	player.global_position = tent.global_position + Vector3(7.0, 0.0, 0.0)
	player.global_position.y = World.runtime.surface_y(player.global_position.x, player.global_position.z)
	player._start_sleep(tent)
	var far_waited := 0.0
	while player._sleep_left <= 0.0 and far_waited < 8.0:
		await get_tree().physics_frame
		far_waited += get_physics_process_delta_time()
	assert(player._sleep_left > 0.0, "sleeping from 7 m away pathfinds to the tent")
	assert(player.global_position.distance_to(tent.global_position) <= 0.5, "and lies down inside it")
	print("[sleeplab] from 7 m: walked to the tent and slept inside it")
	player.vitals.take_damage(1.0)
	var v := Vitals.new()
	# Ten-minute active-outing fixture: time + running + 120 gathers + 30 attacks.
	v.add_fatigue(Vitals.EXHAUSTION_PER_SEC * 600.0, &"time")
	v.add_fatigue(0.09 * 600.0, &"walk")
	v.add_fatigue(Player.GATHER_FATIGUE_PER_UNIT * 120.0, &"gather")
	v.add_fatigue(2.0 * 30.0, &"combat")
	print("[sleeplab] ten-minute modeled outing fatigue=%.2f (legacy uncapped=181.22), sources=%s" % [v.fatigue, v.fatigue_log])
	v.free()
	get_tree().quit(0)

func _capture(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/dfs-sleep-" + stage + ".png")
