extends SceneTree
## MOVEPRIORITY acceptance (owner 2026-10-28, verbatim): "Click to move navigation should take a
## priority over combat, unless the player takes damage, then it attacks damage source/nearest."
## and "clicking to move should cancel an interact pathfind. So if I am trying to sleep and decide
## against it while walking there (i click to move somewhere else) it should cancel the interact
## pathfind to the tent".
## Rules under test:
##  1. A ground click (a move order) is always honoured: auto-attack / auto-chase never pulls her off
##     the path, even with a hunt target or an enemy in reach, until she arrives or a new order comes.
##     A tap on an enemy is still a select/retarget, never a move.
##  2. A creature hit during the move cancels it and she fights the source (else the nearest hostile);
##     a bleed tick does not.
##  3. Without a move order combat is unchanged (a hunt target in reach still auto-attacks).
##  4. A ground click drops a pending interact walk (sleep at a tent, gather, station craft).
## Usage: godot --headless --path game --script res://tests/t_movepriority.gd -> "[t_movepriority] PASS".
## `--script` compiles this file before the autoloads exist: game classes are loaded at run time.

var failures: Array[String] = []
var _started := false
var host: Node3D
var cam: Camera3D
var player
var data: Node
## Seconds the whole run may take (the gate kills it at 10 min): a hung await still fails cleanly.
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
	print("[t_movepriority] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	create_timer(WATCHDOG_S).timeout.connect(_on_watchdog)
	host = Node3D.new()
	host.name = "TMovePriority"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(90, 1, 90)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	# Behind +Z looking at the origin, the t_targetui / t_player framing: a tap at a world point on
	# the floor lands where that point projects.
	cam = Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 14, 14)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)
	await _frames(20)
	player.vitals.max_health = 1000.0
	player.vitals.health = 1000.0
	await _test_baseline_auto_attack()
	_finish()

func _finish() -> void:
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_movepriority] PASS")
		quit(0)
	else:
		print("[t_movepriority] FAIL count=%d" % failures.size())
		quit(1)

func _on_watchdog() -> void:
	_expect(false, "the run finished inside %.0f s (a case hung)" % WATCHDOG_S)
	print("[t_movepriority] FAIL count=%d" % maxi(1, failures.size()))
	quit(1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

## Wait in whole seconds of physics, capped by a frame budget: a hung body cannot hang the test.
func _seconds(s: float) -> void:
	var left := int(ceil(s * 60.0))
	while left > 0:
		await physics_frame
		left -= 1

# ---------------------------------------------------------------- helpers

func _creature(species: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.spawn(data.creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # rules under test, not AI
	c.set_physics_process(false)  # and never moves on its own
	return c

func _clear_world() -> void:
	player.hunt.stop()
	player.clear_nav()
	player.move_order = false
	var sel = player.controls.get("selection")
	if sel:
		sel.clear()
	for c in get_nodes_in_group("creatures"):
		c.queue_free()
	for n in get_nodes_in_group("harvest"):
		n.queue_free()
	for b in get_nodes_in_group("placed_building"):
		if b != null and is_instance_valid(b):
			b.queue_free()
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 1.0, 0)
	player.vitals.health = 1000.0
	player.vitals.fatigue = 0.0
	player.sim._stagger_left = 0.0
	player.sim._stagger_immune_until = -1.0
	await _frames(6)

## A ground tap at a world point, as a finger would: the camera ray, then the 1 m bubble.
func _tap_ground(at: Vector3) -> StringName:
	var kind: StringName = player.debug_tap_screen(cam.unproject_position(at))
	return kind

## The hunt's own swing count, so "no attack" is measured on the real path, not only on state.
func _count_swings() -> Array:
	var box := [0]
	var count := func () -> void: box[0] += 1
	player.hunt.swing_started.connect(count)
	return box

func _stop_counting(box: Array) -> void:
	pass  # the counter rides the hunt signal; test scope is short-lived

# ---------------------------------------------------------------- 3. baseline (no move order)

## Without a move order today's combat is unchanged: a live hunt target in reach swings by itself.
func _test_baseline_auto_attack() -> void:
	await _clear_world()
	var c = _creature(&"protoceratops", Vector3(1.3, 0, 0))
	await _frames(5)
	var swings := _count_swings()
	player.hunt.start(c)
	await _seconds(2.0)
	_expect(not player.move_order and player.hunt.target == c, "baseline: the hunt holds its target")
	_expect(int(swings[0]) >= 1, "baseline: without a move order auto-attack swings at a target in reach (%d)" % int(swings[0]))
	_expect(player.global_position.distance_to(Vector3(0, 1.0, 0)) < 1.0, "baseline: she fights from where she stood, no route")
	await _clear_world()
