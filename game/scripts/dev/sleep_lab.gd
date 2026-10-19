extends Node3D
## Seeded sleep/fatigue fixture, not earned progression. Real tent menu and sleep code.
var player: Player
var tent: Node3D
var _r := LabResult.new("sleeplab")

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
	_r.deadline(get_tree(), 60.0)
	await get_tree().create_timer(0.7).timeout
	player._interact_tap_target(tent)
	_r.expect(player.station_craft.menu.visible, "player.station_craft.menu.visible")
	_r.expect(player._sleep_left == 0.0, "Tent tap opens menu, does not auto-sleep")
	print("[sleeplab] tent tap opens explicit SLEEP menu")
	if Game.shot_path != "":
		return
	await _capture("menu")
	player.station_craft.menu._on_pressed(&"sleep")
	_r.expect(player._sleep_left > 0.0, "player._sleep_left > 0.0")
	_r.expect(player.anim.current_clip == &"sleep_down", "player.anim.current_clip == &\"sleep_down\"")
	await get_tree().create_timer(1.5).timeout
	await _capture("down")
	await get_tree().create_timer(3.0).timeout
	_r.expect(player.anim.current_clip == &"sleep", "player.anim.current_clip == &\"sleep\"")
	_r.expect(player.anim.rig.anim_player.get_animation(&"sleep").loop_mode == Animation.LOOP_LINEAR, "player.anim.rig.anim_player.get_animation(&\"sleep\").loop_mode == Animation.LOOP_LINEAR")
	await _capture("loop")
	await get_tree().create_timer(0.8).timeout
	Input.action_press("move_left")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_left")
	_r.expect(player._sleep_left == 0.0 and int(tent.get("sleeps_left")) == 6, "player._sleep_left == 0.0 and int(tent.get(\"sleeps_left\")) == 6")
	_r.expect(player.anim.current_clip == &"sleep_up", "player.anim.current_clip == &\"sleep_up\"")
	await get_tree().create_timer(1.1).timeout
	await _capture("up")
	await get_tree().create_timer(3.0).timeout
	_r.expect(player.anim.current_clip == &"idle", "player.anim.current_clip == &\"idle\"")
	await _capture("awake")
	print("[sleeplab] movement interrupts without consuming use; up returns to idle")
	player._start_sleep(tent)
	await get_tree().create_timer(10.5).timeout
	_r.expect(player._sleep_left == 0.0 and player.vitals.fatigue < 1.0, "player._sleep_left == 0.0 and player.vitals.fatigue < 1.0")
	_r.expect(int(tent.get("sleeps_left")) == 5, "int(tent.get(\"sleeps_left\")) == 5")
	_r.expect(player.anim.current_clip == &"sleep_up", "player.anim.current_clip == &\"sleep_up\"")
	await get_tree().create_timer(3.0).timeout
	_r.expect(player.anim.current_clip == &"idle" and not player.anim._waking, "player.anim.current_clip == &\"idle\" and not player.anim._waking")
	player.vitals.fatigue = 60.0
	player._start_sleep(tent)
	player.vitals.take_damage(1.0)
	_r.expect(player._sleep_left == 0.0 and not player.anim._sleeping and not player.anim._waking, "player._sleep_left == 0.0 and not player.anim._sleeping and not player.anim._waking")
	_r.expect(int(tent.get("sleeps_left")) == 5, "int(tent.get(\"sleeps_left\")) == 5")
	print("[sleeplab] completed sleep restores fatigue, consumes exactly one use; damage interrupts without use")
	var v := Vitals.new()
	# Ten-minute active-outing fixture: time + running + 120 gathers + 30 attacks.
	v.add_fatigue(Vitals.EXHAUSTION_PER_SEC * 600.0, &"time")
	v.add_fatigue(0.09 * 600.0, &"walk")
	v.add_fatigue(Player.GATHER_FATIGUE_PER_UNIT * 120.0, &"gather")
	v.add_fatigue(2.0 * 30.0, &"combat")
	print("[sleeplab] ten-minute modeled outing fatigue=%.2f (legacy uncapped=181.22), sources=%s" % [v.fatigue, v.fatigue_log])
	v.free()
	_r.finish(get_tree(), "tent sleeps_left=%d" % int(tent.get("sleeps_left")))

func _capture(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(LabResult.capture_path("sleep-" + stage))
