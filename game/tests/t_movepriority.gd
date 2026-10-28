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
	await _test_ground_click_wins()
	await _test_enemy_tap_and_tick()
	await _test_damage_breaks_move()
	await _test_ground_click_cancels_errands()
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
	_expect(player.hunt.target == c, "baseline: the hunt holds its target")
	_expect(int(swings[0]) >= 1, "baseline: without a move order auto-attack swings at a target in reach (%d)" % int(swings[0]))
	_expect(player.global_position.distance_to(Vector3(0, 1.0, 0)) < 1.0, "baseline: she fights from where she stood, no route")
	await _clear_world()

# ---------------------------------------------------------------- 1. a move order outranks combat

## Owner rule 1: with an enemy in auto-attack range a ground click walks her to the point and no
## swing or chase happens, even with a hunt target started over the walk.
func _test_ground_click_wins() -> void:
	await _clear_world()
	var c = _creature(&"protoceratops", Vector3(1.3, 0, 0))
	await _frames(4)
	var goal := Vector3(0, 0, -9)
	var swings := _count_swings()
	_tap_ground(goal + Vector3(0, 0.05, 0))
	await _frames(3)
	_expect(player.move_order and player.nav_active, "move order: a ground click starts a move order (order=%s nav=%s)" % [player.move_order, player.nav_active])
	_expect(player.hunt.target == null, "move order: the click drops the fight it was not told to keep")
	player.hunt.start(c)  # a target in reach, as a tap or a stray bite would leave it
	await _seconds(1.2)
	_expect(int(swings[0]) == 0, "move order: no auto-attack swing during the walk (%d)" % int(swings[0]))
	_expect(player.global_position.distance_to(goal) < 6.0, "move order: she walks her own path, not at the enemy (%.1f m to the point)" % player.global_position.distance_to(goal))
	_expect(player.global_position.distance_to(c.global_position) > 2.5, "move order: auto-chase did not pull her back onto the enemy (%.1f m)" % player.global_position.distance_to(c.global_position))
	# Watch the route frame by frame: the moment it ends (or the 4 s budget runs out) is the measure,
	# because once the order is over the hunt's own target takes the body back toward the enemy.
	# Watch the order itself (not nav_active: the hunt's own chase re-arms that after arrival).
	var arrived_at := Vector3.INF
	for i in 240:
		await physics_frame
		if not player.move_order:
			arrived_at = player.global_position
			break
	await _frames(2)
	# After arrival combat may resume (the hunt target is still live): only the order must be over.
	_expect(not player.move_order, "move order ends on arrival (order=%s)" % player.move_order)
	var at_goal := Vector2(arrived_at.x, arrived_at.z)
	_expect(arrived_at != Vector3.INF and at_goal.distance_to(Vector2(goal.x, goal.z)) < 2.5,
		"move order: she arrives at the clicked point (%.1f m off)" % at_goal.distance_to(Vector2(goal.x, goal.z)))
	await _clear_world()

## Owner rule 1 (second half) and spec §11: a tap on an enemy is a select/retarget, never a move; a
## DoT tick (bleed) is not "taking damage" and does not break the order.
func _test_enemy_tap_and_tick() -> void:
	await _clear_world()
	var near = _creature(&"protoceratops", Vector3(1.4, 0, 0))
	var far = _creature(&"protoceratops", Vector3(-2.0, 0, -4.0))
	await _frames(4)
	var goal := Vector3(0, 0, -11)
	_tap_ground(goal + Vector3(0, 0.05, 0))
	await _frames(3)
	var goal0: Vector3 = player._path_goal
	var kind: StringName = _tap_ground(far.global_position + Vector3(0, 0.6, 0))
	await _frames(3)
	var sel = player.controls.get("selection")
	_expect(kind == &"interact" and sel != null and sel.current() == far,
		"enemy tap: a tap on an animal selects it, it is not a move (kind=%s selection=%s)" % [kind, sel.current() if sel else null])
	_expect(player.move_order and player._path_goal.distance_to(goal0) < 0.01,
		"enemy tap: the walk to the clicked point is untouched (order=%s goal %s -> %s)" % [player.move_order, goal0, player._path_goal])
	_expect(player.hunt.target == null, "enemy tap: out of combat a tap on an enemy still starts no fight")
	# In combat the same tap retargets, still without becoming a move.
	player.hunt.start(near)
	await _frames(2)
	_tap_ground(far.global_position + Vector3(0, 0.6, 0))
	await _frames(3)
	_expect(player.hunt.target == far, "enemy tap: in combat a tap on another enemy retargets at once (hunt %s)" % [player.hunt.target])
	_expect(player.move_order, "enemy tap: retargeting kept the move order (the click still owns the walk)")
	# Bleed: a damage-over-time tick never turns her round.
	player.hunt.stop()
	player.statuses.apply(&"bleed")
	await _seconds(1.6)
	_expect(player.move_order and player.nav_active, "bleed tick: the walk survives a status tick (order=%s nav=%s)" % [player.move_order, player.nav_active])
	_expect(player.hunt.target == null, "bleed tick: no retaliation against a status with no attacker")
	player.statuses.clear_id(&"bleed")
	await _clear_world()

# ---------------------------------------------------------------- 2. taking damage breaks the order

## Owner rule 2: a hit during the walk cancels the move after the hurt stun and she attacks the source.
func _test_damage_breaks_move() -> void:
	await _clear_world()
	var a = _creature(&"protoceratops", Vector3(1.3, 0, 0))
	var b = _creature(&"protoceratops", Vector3(-1.4, 0, -1.4))
	await _frames(4)
	var swings := _count_swings()
	_tap_ground(Vector3(0, 0.05, -11))
	await _frames(3)
	_expect(player.move_order, "damage: walking the order first")
	player.receive_creature_hit(a, &"attack_primary")
	await _frames(2)
	_expect(not player.move_order and not player.nav_active, "damage: the move order is cancelled by a hit (order=%s nav=%s)" % [player.move_order, player.nav_active])
	_expect(player.hunt.target == a, "damage: she turns on the creature that hit her (hunt %s, a %s)" % [player.hunt.target, a])
	_expect(player.sim._stagger_left > 0.0, "damage: the hurt stun holds her for the clip (%.2f s)" % player.sim._stagger_left)
	var stagger: float = player.sim._stagger_left
	await _seconds(stagger + 0.6)
	_expect(int(swings[0]) >= 1, "damage: she attacks the damage source once the stun ends (%d swings)" % int(swings[0]))
	# No live source (a trap, a fall, a projectile whose attacker is gone): the nearest hostile.
	await _clear_world()
	b = _creature(&"protoceratops", Vector3(-1.4, 0, -1.4))
	await _frames(4)
	_tap_ground(Vector3(0, 0.05, -11))
	await _frames(3)
	player.receive_creature_hit(null, &"attack_primary")
	await _frames(2)
	_expect(not player.move_order, "damage: a hit with no attacker also cancels the move")
	_expect(player.hunt.target == b, "damage: with no live source she attacks the nearest hostile (hunt %s)" % [player.hunt.target])
	await _clear_world()

# ---------------------------------------------------------------- 3. a move order cancels errands

func _bag_item(id: StringName, n: int = 1) -> void:
	player.inventory.add((load("res://scripts/items/item_stack.gd") as GDScript).make(id, n))

## Owner (verbatim): "if I am trying to sleep and decide against it while walking there (i click to
## move somewhere else) it should cancel the interact pathfind to the tent". Same for a gather node
## and a station craft: the intent AND the path go; nothing finishes when she passes by.
func _test_ground_click_cancels_errands() -> void:
	await _clear_world()
	# --- sleep at a tent
	var tent = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"tent")
	host.add_child(tent)
	tent.global_position = Vector3(0, 0, -14)
	await _frames(3)
	player.vitals.fatigue = 85.0
	player.sim.start_sleep(tent)
	await _frames(3)
	_expect(player.sim._sleep_pending == tent and player.nav_active, "errand: the tent sleep starts with a walk to the bedding")
	var away := Vector3(9, 0.05, 9)
	_tap_ground(away)
	await _frames(3)
	_expect(player.sim._sleep_pending == null, "errand: a ground click drops the pending sleep")
	_expect(player.move_order and player.nav_active, "errand: the click owns the route (order=%s nav=%s)" % [player.move_order, player.nav_active])
	await _seconds(4.0)
	_expect(player._sleep_left <= 0.0 and not player.anim._sleeping, "errand: she never lies down afterwards (sleep %.1f s)" % player._sleep_left)
	_expect(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(away.x, away.z)) < 3.0,
		"errand: she walks to where the player clicked, not the tent (%.1f m off)" % Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(away.x, away.z)))
	tent.queue_free()
	await _clear_world()
	# --- gather a node
	var node = (load("res://scenes/world/harvest_node.tscn") as PackedScene).instantiate()
	node.setup(&"test_branch_pile", &"branch", 1, 1, {}, &"none", Color(0.6, 0.45, 0.3), 0.1, 60.0, "", false, 4)
	node.position = Vector3(0, 0, -13)
	host.add_child(node)
	await _frames(3)
	var started: bool = player.actions.begin_gather(node)
	await _frames(2)
	_expect(started and player.gather_target == node and player.nav_active, "errand: a gather node starts a walk to it")
	_tap_ground(away)
	await _frames(3)
	_expect(player.gather_target == null, "errand: a ground click drops the gather target")
	await _seconds(4.0)
	_expect(player.gather_target == null and not player._gathering, "errand: she never gathers afterwards")
	node.queue_free()
	await _clear_world()
	# --- craft at a station
	var bench = (load("res://scripts/world/craft_station.gd") as GDScript).make(&"workbench")
	host.add_child(bench)
	bench.global_position = Vector3(0, 0, -13)
	await _frames(3)
	_bag_item(&"stone")
	_bag_item(&"branch")
	_bag_item(&"bark_strip")
	var began: bool = player.station_craft.begin(&"work_axe")
	await _frames(2)
	_expect(began and player.station_craft.recipe_id == &"work_axe" and player.nav_active,
		"errand: a workbench craft starts with a walk to the bench (began=%s recipe=%s)" % [began, player.station_craft.recipe_id])
	_tap_ground(away)
	await _frames(3)
	_expect(player.station_craft.recipe_id == &"" and not player.station_craft.crafting,
		"errand: a ground click drops the pending station craft (recipe=%s)" % player.station_craft.recipe_id)
	await _seconds(4.0)
	_expect(not player.station_craft.crafting and player.station_craft.recipe_id == &"", "errand: she never crafts at the bench afterwards")
	bench.queue_free()
	await _clear_world()
