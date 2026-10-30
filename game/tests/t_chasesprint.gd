extends SceneTree
## CHASESPRINT acceptance (owner, verbatim: "when chasing a fleeing enemy, when it leaves a certain
## radius around the player, toggle sprint to chase it").
## Rules under test (radii are # ASSUMPTION in game/scripts/player/player.gd):
##  1. A hunt target farther than CHASE_SPRINT_ON_M (7 m) switches sprint on by itself.
##  2. It stays on between 7 and 4 m (hysteresis) and switches off inside CHASE_SPRINT_OFF_M (4 m).
##  3. The chase ending (target cleared / dead / a click-to-move order) switches it off.
##  4. A sprint the player latched by hand is never switched off by chase-sprint; chase-sprint off
##     leaves the manual latch on.
##  5. A winded survivor is not forced to sprint, even with the target 9 m away.
##  6. Mounted, the same flag asks the mount to run (and the mount's own pool gates it).
## Usage: godot --headless --path game --script res://tests/t_chasesprint.gd -> "[t_chasesprint] PASS".

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var data: Node
const WATCHDOG_S := 240.0

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	get_root().get_node("Game").max_creatures_per_island = 0  # no wandering aggro: only the cases' own bodies
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_chasesprint] %s %s" % ["ok" if ok else "FAIL", msg])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _creature(id: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id))
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.set_physics_process(false)
	return c

func _run() -> void:
	create_timer(WATCHDOG_S).timeout.connect(_on_watchdog)
	host = Node3D.new()
	host.name = "TChaseSprint"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)
	await _frames(10)
	# Held still: the chase's auto-attack would otherwise walk her onto the target and undo every
	# distance this test sets. Player._physics_process calls chase_sprint_tick each frame; the test
	# calls it itself after moving the target, which is the same entry point.
	player.set_physics_process(false)
	var target = _creature(&"compsognathus", Vector3(0, 0.0, -9.0))
	await _test_radii(target)
	await _test_manual_latch(target)
	await _test_winded(target)
	await _test_chase_end(target)
	await _test_move_order(target)
	await _test_mounted(target)
	_finish()

func _finish() -> void:
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_chasesprint] PASS")
		quit(0)
	else:
		print("[t_chasesprint] FAIL count=%d" % failures.size())
		quit(1)

func _on_watchdog() -> void:
	_expect(false, "the run finished inside %.0f s (a case hung)" % WATCHDOG_S)
	print("[t_chasesprint] FAIL count=%d" % maxi(1, failures.size()))
	quit(1)

## 1 + 2: on past 7 m, hysteresis down to 4 m, off inside 4 m.
func _test_radii(target) -> void:
	player.vitals.energy = player.vitals.effective_max_energy()
	player.vitals.exhausted = false
	player.sprint_toggled = false
	player.chase_sprint = false
	player.hunt.start(target)
	target.global_position = player.global_position + Vector3(0, 0, -9)
	player.chase_sprint_tick()
	_expect(player.chase_sprint, "a target at 9 m switches chase sprint on")
	_expect(player.sim.wants_sprint(), "the movement tick sees the chase sprint")
	_expect(not player.sprint_toggled, "chase sprint does not latch the player's own SPRINT toggle")
	# 5 m: past the off radius but inside the on radius -> still sprinting (hysteresis).
	target.global_position = player.global_position + Vector3(0, 0, -5)
	player.chase_sprint_tick()
	_expect(player.chase_sprint, "5 m keeps it on (hysteresis between 4 and 7 m)")
	# 3 m: inside the off radius -> off.
	target.global_position = player.global_position + Vector3(0, 0, -3)
	player.chase_sprint_tick()
	_expect(not player.chase_sprint, "3 m switches chase sprint off")
	_expect(not player.sim.wants_sprint(), "the movement tick stops sprinting inside 4 m")
	# A target that never crossed 7 m does not start a sprint at 6 m.
	target.global_position = player.global_position + Vector3(0, 0, -6)
	player.chase_sprint_tick()
	_expect(not player.chase_sprint, "6 m alone does not switch it on (needs more than 7 m)")

## 4: the player's own latch is untouched in both directions.
func _test_manual_latch(target) -> void:
	player.sprint_toggled = true
	target.global_position = player.global_position + Vector3(0, 0, -9)
	player.chase_sprint_tick()
	_expect(player.chase_sprint and player.sprint_toggled, "manual latch and chase sprint coexist")
	target.global_position = player.global_position + Vector3(0, 0, -2)
	player.chase_sprint_tick()
	_expect(not player.chase_sprint, "inside 4 m the chase sprint drops")
	_expect(player.sprint_toggled, "the manual latch survives the chase sprint dropping")
	_expect(player.sim.wants_sprint(), "the manual latch still sprints")
	target.global_position = player.global_position + Vector3(0, 0, -9)
	player.sprint_toggled = false
	player.chase_sprint_tick()
	_expect(player.chase_sprint, "chase sprint comes back with the latch off")

## 5: winded / empty does not force a sprint.
func _test_winded(target) -> void:
	player.chase_sprint = false
	player.sprint_toggled = false
	player.vitals.energy = 0.0
	player.vitals.exhausted = true
	target.global_position = player.global_position + Vector3(0, 0, -9)
	player.chase_sprint_tick()
	_expect(not player.chase_sprint, "a winded survivor is not forced to sprint at 9 m")
	_expect(not player.sim.wants_sprint(), "and the movement tick walks")
	player.vitals.exhausted = false
	player.vitals.energy = player.vitals.effective_max_energy()

## 3: the chase ending switches it off.
func _test_chase_end(target) -> void:
	target.global_position = player.global_position + Vector3(0, 0, -9)
	player.chase_sprint_tick()
	_expect(player.chase_sprint, "sprinting again before the chase ends")
	player.hunt.stop()
	player.chase_sprint_tick()
	_expect(not player.chase_sprint, "the chase ending switches chase sprint off")
	_expect(not player.sim.wants_sprint(), "and the movement tick stops sprinting")

## 3b: a ground-tap move order outranks combat, so it also ends the chase sprint; the hunt keeps its
## target and the sprint comes back when the order is done.
func _test_move_order(target) -> void:
	player.sprint_toggled = false
	target.global_position = player.global_position + Vector3(0, 0, -9)
	player.hunt.start(target)
	player.chase_sprint_tick()
	_expect(player.chase_sprint, "chase sprint on with the target 9 m off")
	player.move_order = true
	player.nav_active = true
	player.chase_sprint_tick()
	_expect(not player.chase_sprint, "a ground-tap move order ends the chase sprint")
	_expect(not player.sim.wants_sprint(), "and she walks her own path")
	player.move_order = false
	player.clear_nav()
	player.chase_sprint_tick()
	_expect(player.chase_sprint and player.hunt.target == target,
		"the target is still held and the chase sprint returns when the order ends")

## 6: mounted, the flag asks the mount to run; the mount's pool gates it.
func _test_mounted(target) -> void:
	player.bonded.append(load("res://scripts/pets/pet_record.gd").from_def(data.creature(&"zebraceratops"), &"A"))
	player.bonded[-1].fit_saddle()
	var m = player.pets.summon(player.bonded.size() - 1)
	m.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(10)
	player.pets.mount(m)
	await _frames(5)
	_expect(player.mounted_on == m, "mounted the zebraceratops")
	player.sprint_toggled = false
	player.chase_sprint = false
	m.energy = m.energy_max
	m.winded = false
	target.global_position = player.global_position + Vector3(0, 0, -9)
	player.hunt.start(target)
	player.chase_sprint_tick()
	_expect(player.chase_sprint, "mounted, a target at 9 m switches chase sprint on")
	_expect(player.pets.wants_mount_sprint(), "the rider asks the mount to run")
	m.energy = 0.0
	m.winded = true
	player.chase_sprint_tick()
	_expect(not player.chase_sprint, "a winded mount drops the chase sprint")
	_expect(not player.pets.wants_mount_sprint(), "and stops asking it to run")
	player.hunt.stop()
	player.dismount()
	await _frames(2)
	m.queue_free()
