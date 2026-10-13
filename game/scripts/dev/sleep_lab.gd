extends Node3D
## Seeded sleep/fatigue fixture, not earned progression. Real tent menu and sleep code.
var player: Player
var tent: Node3D

func _ready() -> void:
	var kit := LabKit.build(self, 24.0)
	player = kit["player"]
	var cam: IsoCamera = kit["cam"]
	cam.size = 10.0
	cam._snap()
	tent = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"tent")
	tent.position = Vector3(2.5, 0, 0)
	add_child(tent)
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
	player.station_craft.menu._on_pressed(&"sleep")
	assert(player._sleep_left > 0.0)
	await get_tree().create_timer(0.8).timeout
	Input.action_press("move_left")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_left")
	assert(player._sleep_left == 0.0 and int(tent.get("sleeps_left")) == 6)
	print("[sleeplab] movement interrupts without consuming use")
	player._start_sleep(tent)
	await get_tree().create_timer(10.5).timeout
	assert(player._sleep_left == 0.0 and player.vitals.fatigue < 1.0)
	assert(int(tent.get("sleeps_left")) == 5)
	print("[sleeplab] completed sleep restores fatigue, consumes exactly one use")
	var v := Vitals.new()
	# Ten-minute active-outing fixture: time + running + 120 gathers + 30 attacks.
	v.add_fatigue(Vitals.EXHAUSTION_PER_SEC * 600.0, &"time")
	v.add_fatigue(0.09 * 600.0, &"walk")
	v.add_fatigue(Player.GATHER_FATIGUE_PER_UNIT * 120.0, &"gather")
	v.add_fatigue(2.0 * 30.0, &"combat")
	print("[sleeplab] ten-minute modeled outing fatigue=%.2f (legacy uncapped=181.22), sources=%s" % [v.fatigue, v.fatigue_log])
	v.free()
	get_tree().quit(0)
