extends SceneTree
## Creature energy (owner 2026-10-28). Run: godot --headless --path game --script res://tests/t_energy.gd
## Prints "[t_energy] PASS" or FAIL lines and quits 0/1.
##  1. Size default: a bigger animal has a larger pool and a slower refill.
##  2. Running drains, walking refills; at the stop threshold it cannot run until resume_frac.
##  3. A special is refused below its cost; try_special spends it.
##  4. A wild chase (approach) through the physics path drains; winded, it moves at walk pace.
##  5. Mounted: Shift and the SPRINT toggle run the mount (faster, drains ITS pool), released it walks;
##     the vitals bar reads the mount while mounted and the survivor after dismount; the survivor's
##     stamina and exhaustion do not move from the mount running.

var failures: Array[String] = []
var data: Node
var host: Node3D
var player
var _started := false

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_energy] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _creature(id: StringName, at: Vector3):
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id))
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _run() -> void:
	host = Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 30, 30)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	_test_pool()
	await _test_wild_chase()
	await _test_mounted()
	if failures.is_empty():
		print("[t_energy] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_energy] FAIL " + f)
		quit(1)

func _test_pool() -> void:
	var small = _creature(&"compsognathus", Vector3(-50, 0, -50))
	var big = _creature(&"tyrannosaurus", Vector3(50, 0, -50))
	small.set_physics_process(false)
	big.set_physics_process(false)
	_expect(big.energy_max > small.energy_max, "pool by size: rex %.0f > compy %.0f" % [big.energy_max, small.energy_max])
	_expect(big.energy_max / big.energy_regen_per_s > small.energy_max / small.energy_regen_per_s,
		"refill by size: rex %.1f s > compy %.1f s" % [big.energy_max / big.energy_regen_per_s, small.energy_max / small.energy_regen_per_s])
	var r: Dictionary = data.creature_ai["energy"]
	var c = small
	_expect(is_equal_approx(c.energy, c.energy_max) and c.can_sprint(), "spawns full and able to run")
	var e0: float = c.energy
	c.tick_energy(1.0, true)
	_expect(c.energy < e0, "running 1 s drains (%.1f -> %.1f)" % [e0, c.energy])
	var e1: float = c.energy
	c.tick_energy(0.5, false)
	_expect(c.energy > e1, "walking 0.5 s refills (%.1f -> %.1f)" % [e1, c.energy])
	var guard := 0
	while c.can_sprint() and guard < 10000:
		c.tick_energy(0.1, true)
		guard += 1
	_expect(c.winded and c.energy <= c.energy_max * float(r["stop_frac"]) + 0.001, "winded at the stop threshold (%.1f / %.0f)" % [c.energy, c.energy_max])
	# Hysteresis: just under resume it still cannot run; past it, it can.
	var resume: float = c.energy_max * float(r["resume_frac"])
	while c.energy + c.energy_regen_per_s * 0.05 < resume:
		c.tick_energy(0.05, false)
	_expect(not c.can_sprint() and c.energy > c.energy_max * float(r["stop_frac"]), "still winded at %.1f, under resume %.1f" % [c.energy, resume])
	c.tick_energy(0.2, false)
	_expect(c.can_sprint(), "runs again past resume (%.1f)" % c.energy)
	# Specials.
	var d = _creature(&"deinonychus", Vector3(0, 0, -80))
	d.set_physics_process(false)
	var heavy: float = d.special_cost(&"attack_heavy")
	var combo: float = d.special_cost(&"bite_combo")
	_expect(heavy > 0.0 and combo > 0.0 and d.special_cost(&"attack_primary") == 0.0, "costs: heavy %.1f, bite_combo %.1f, primary free" % [heavy, combo])
	d.energy = heavy - 1.0
	_expect(not d.can_use_special(heavy) and not d.try_special(&"attack_heavy") and is_equal_approx(d.energy, heavy - 1.0), "a special is refused below its cost and spends nothing")
	d.energy = d.energy_max
	_expect(d.try_special(&"attack_heavy") and is_equal_approx(d.energy, d.energy_max - heavy), "try_special spends the cost")
	small.free()
	big.free()
	d.free()

func _test_wild_chase() -> void:
	var c = _creature(&"velociraptor", Vector3(0, 0.2, 60))
	c.brain.state = &"approach"
	await _frames(10)
	var e0: float = c.energy
	for i in 60:
		c._path_active = true
		c._path_goal = c.global_position + Vector3(0, 0, -6)
		c.agent.target_position = c._path_goal
		await physics_frame
	_expect(c.energy < e0 - 1.0, "a chase drains the pool (%.1f -> %.1f)" % [e0, c.energy])
	c.energy = 0.0
	c.winded = true
	for i in 20:
		c._path_active = true
		c._path_goal = c.global_position + Vector3(0, 0, -6)
		c.agent.target_position = c._path_goal
		await physics_frame
	var v := Vector2(c.velocity.x, c.velocity.z).length()
	var walk: float = c.walk_mps(c.move_speed_mps())
	_expect(v > 0.1 and v <= walk + 0.01, "winded, the chase drops to a walk (%.2f m/s <= %.2f)" % [v, walk])
	c._path_active = false
	c.free()

func _ride_frames(m, n: int) -> float:
	var p0: Vector3 = m.global_position
	await _frames(n)
	return Vector2(m.global_position.x - p0.x, m.global_position.z - p0.z).length()

func _test_mounted() -> void:
	player = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)
	var hud = load("res://scripts/ui/hunt_hud.gd").new()
	hud.bind(player)
	var layer := CanvasLayer.new()
	host.add_child(layer)
	layer.add_child(hud)
	player.bonded.append(load("res://scripts/pets/pet_record.gd").from_def(data.creature(&"zebraceratops"), &"A"))
	var m = player.pets.summon(player.bonded.size() - 1)
	m.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(10)
	player.pets.mount(m)
	await _frames(5)
	_expect(player.mounted_on == m, "mounted the zebraceratops")
	var HH = load("res://scripts/ui/hunt_hud.gd")
	var read: Dictionary = HH.energy_reading(player)
	_expect(is_equal_approx(read.value, m.energy) and is_equal_approx(read.max, m.energy_max) and read.name != "",
		"vitals bar reads the mount (%s %.0f / %.0f)" % [read.name, read.value, read.max])
	var pe0: float = player.vitals.energy
	var pf0: float = player.vitals.fatigue
	Input.action_press("move_up")
	var walked: float = await _ride_frames(m, 60)
	var e_walk: float = m.energy
	_expect(is_equal_approx(e_walk, m.energy_max), "walking the mount does not drain it (%.1f)" % e_walk)
	Input.action_press("sprint")
	var ran: float = await _ride_frames(m, 60)
	_expect(ran > walked * 1.5, "Shift runs the mount: %.2f m vs %.2f m walking in 60 frames" % [ran, walked])
	_expect(m.energy < e_walk - 1.0, "running drains the mount (%.1f -> %.1f)" % [e_walk, m.energy])
	read = HH.energy_reading(player)
	_expect(is_equal_approx(read.value, m.energy), "the bar follows the mount's pool (%.1f)" % read.value)
	Input.action_release("sprint")
	player.sprint_toggled = true  # the HUD SPRINT hex
	var e1: float = m.energy
	var toggled: float = await _ride_frames(m, 30)
	_expect(toggled > walked * 0.5 * 1.5 and m.energy < e1, "the SPRINT toggle runs it too (%.2f m in 30 frames, %.1f -> %.1f)" % [toggled, e1, m.energy])
	# Run it dry: it drops to a walk at the threshold and the toggle stays on for when it recovers.
	var guard := 0
	while m.can_sprint() and guard < 3000:
		await physics_frame
		guard += 1
	var slow: float = await _ride_frames(m, 30)
	_expect(not m.can_sprint() and slow < toggled * 0.75, "winded mount walks (%.2f m in 30 frames)" % slow)
	player.sprint_toggled = false
	Input.action_release("move_up")
	_expect(player.vitals.energy >= pe0 - 0.01, "the survivor's stamina did not pay for the run (%.1f -> %.1f)" % [pe0, player.vitals.energy])
	_expect(player.vitals.fatigue <= pf0 + 0.5, "the survivor's exhaustion did not move from the run (%.2f -> %.2f)" % [pf0, player.vitals.fatigue])
	player.dismount()
	await _frames(3)
	read = HH.energy_reading(player)
	_expect(read.name == "" and is_equal_approx(read.value, player.vitals.energy), "after dismount the bar reads the survivor (%.0f)" % read.value)
