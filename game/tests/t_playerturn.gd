extends SceneTree
## PLAYERTURN (owner 2026-10-28): "player has the turn speed glitch too, just like dinosaurs" and "if i'm
## in combat and i try to walk away, my player glitches out. You should have him pathfind to where I want
## to walk and then re-engage in combat".
## Logs the survivor's visible yaw (the rig, every process AND physics frame, at a 120 Hz render rate) in:
## path corners, stick noise, running, auto-attack on a strafing deinonychus, walking away from it (stick
## and ground tap), riding a T. rex and a zebraceratops, a ground tap in the creature lab, and a walk-away
## on a real island. Per case: yaw reversals per second, max yaw step, and position jitter (velocity
## direction flips). Also: a 180 deg turn finishes within 0.3 s, mounted turning follows the mount's rate,
## a tap walk-away reaches the point and re-engages (the target, else the nearest animal).
## Usage: godot --headless --path game --script res://tests/t_playerturn.gd -> "[t_playerturn] PASS".
## `--script` compiles this file before the autoloads exist: game scripts are load()ed on the first frame.

const WATCHDOG_S := 300.0
## ASSUMPTION bounds: a clean walk reverses its turn at most ~2 times a second (corners, a strafing
## target changing side); the glitch measured 10+ (see the report).
const MAX_REV_PER_S := 2.0
const TURN_180_S := 0.3
const FOOT_RATE := deg_to_rad(720.0)

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var data: Node
var LabKit: GDScript
var _samp: Sampler

class Sampler extends Node:
	var on := false
	var who: Node3D
	var yaws: PackedFloat32Array = []
	var vel_flips := 0
	var _last_v := Vector2.ZERO
	var physics_frames := 0
	func _init() -> void:
		process_priority = 100000
		process_physics_priority = 100000
	func start(w: Node3D) -> void:
		who = w
		yaws = []
		vel_flips = 0
		physics_frames = 0
		_last_v = Vector2.ZERO
		on = true
	## Mounted: the mount's body (the rider's rig sways with the saddle bone's gait, which is not turning).
	func _yaw() -> float:
		if who.mounted_on:
			return who.mounted_on.global_rotation.y
		return who.rig.global_basis.get_euler().y if who.rig else who.visual.global_rotation.y
	func _process(_d: float) -> void:
		if on:
			yaws.append(_yaw())
	func _physics_process(_d: float) -> void:
		if not on:
			return
		physics_frames += 1
		yaws.append(_yaw())
		var body: CharacterBody3D = who.mounted_on if who.mounted_on else who
		# Against the last real heading, not the last frame: accel swings a reversal through ~0 m/s.
		var v := Vector2(body.velocity.x, body.velocity.z)
		if v.length() > 0.3:
			if _last_v.length() > 0.3 and v.dot(_last_v) < 0.0:
				vel_flips += 1
			_last_v = v
	## [reversals per second, max step (deg), velocity flips]
	func stats() -> Array:
		on = false
		var rev := 0
		var last := 0
		var mx := 0.0
		for i in range(1, yaws.size()):
			var d := angle_difference(yaws[i - 1], yaws[i])
			mx = maxf(mx, absf(d))
			if absf(d) > 0.002:
				var s := 1 if d > 0.0 else -1
				if last != 0 and s != last:
					rev += 1
				last = s
		var secs := maxf(0.001, physics_frames / 60.0)
		return [rev / secs, rad_to_deg(mx), vel_flips]

func _process(_d: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	LabKit = load("res://scripts/dev/lab_kit.gd")
	get_root().get_node("Game").max_creatures_per_island = 0
	Engine.max_fps = 120  # a 120 Hz phone: two renders per physics tick, where a _process facing write shows
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_playerturn] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	create_timer(WATCHDOG_S).timeout.connect(func () -> void:
		print("[t_playerturn] FAIL watchdog after %.0f s" % WATCHDOG_S)
		quit(1))
	_samp = Sampler.new()
	get_root().add_child(_samp)
	host = Node3D.new()
	host.name = "TPlayerTurn"
	get_root().add_child(host)
	player = LabKit.build(host)["player"]
	await _frames(30)
	player.vitals.max_health = 100000.0
	await _case_corners()
	await _case_stick_noise(false)
	await _case_stick_noise(true)
	await _case_turn_180(false)
	await _case_turn_180(true)
	await _case_strafe_fight()
	await _case_stick_walk_away()
	await _case_tap_walk_away(false)
	await _case_tap_walk_away(true)
	await _case_hit_on_the_way()
	await _case_mounted(&"tyrannosaurus")
	await _case_mounted(&"zebraceratops")
	host.queue_free()
	await _frames(5)
	await _case_creature_lab_tap()
	await _case_island_walk_away()
	if failures.is_empty():
		print("[t_playerturn] PASS")
		quit(0)
	else:
		print("[t_playerturn] FAIL count=%d" % failures.size())
		quit(1)

# ---------------------------------------------------------------- helpers

func _reset(at: Vector3 = Vector3(0, 1, 0)) -> void:
	_release()
	player.hunt.stop()
	player.clear_nav()
	player.sprint_toggled = false
	for c in get_nodes_in_group("creatures"):
		if not c.is_queued_for_deletion() and c != player.mounted_on:
			c.queue_free()
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.visual.rotation.y = 0.0
	player.vitals.health = player.vitals.effective_max_health()
	player.vitals.energy = player.vitals.effective_max_energy()
	player.vitals.fatigue = 0.0
	player.sim._stagger_left = 0.0
	player.sim._stagger_immune_until = -1.0
	await _frames(8)

func _release() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right", "sprint"]:
		Input.action_release(a)

func _report(name: String, st: Array) -> void:
	print("[t_playerturn] case=%s rev_per_s=%.2f max_step_deg=%.1f vel_flips=%d" % [name, st[0], st[1], st[2]])
	_expect(float(st[0]) <= MAX_REV_PER_S, "%s: yaw reversals %.2f/s <= %.1f" % [name, st[0], MAX_REV_PER_S])

## A wild animal that stands where the test puts it: no brain, no own physics.
func _dino(id: StringName, at: Vector3, parent: Node = null):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	(parent if parent else host).add_child(c)
	c.global_position = at
	c.spawn(data.creature(id))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.set_physics_process(false)
	c.health.setup(1.0e9)
	return c

## Circle the survivor at r, reversing every 1.5 s: the deinonychus strafe.
func _strafe(c, centre: Vector3, r: float, t: float) -> void:
	var dirn := 1.0 if int(t / 1.5) % 2 == 0 else -1.0
	var a := fmod(t, 1.5) * 1.6 * dirn
	c.global_position = centre + Vector3(sin(a) * r, 0, cos(a) * r)

func _tap(at: Vector3) -> StringName:
	var cam: Camera3D = get_root().get_viewport().get_camera_3d()
	return player.debug_tap_screen(cam.unproject_position(at))

func _arrived(goal: Vector3, tol: float = 1.2) -> bool:
	return Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length() <= tol

# ---------------------------------------------------------------- on foot

func _case_corners() -> void:
	await _reset()
	var pts := [Vector3(4, 0, -4), Vector3(0, 0, -8), Vector3(4, 0, -12), Vector3(0, 0, -16), Vector3(4, 0, -20)]
	_samp.start(player)
	var i := 0
	for f in 900:
		if i >= pts.size():
			break
		if not player.nav_active or _arrived(pts[i], 0.6):
			if _arrived(pts[i], 0.6):
				i += 1
			if i < pts.size():
				player.nav_to(pts[i])
		await physics_frame
	_report("path_corners", _samp.stats())
	_expect(i >= pts.size(), "path_corners: walked all %d corners (%d)" % [pts.size(), i])

func _case_stick_noise(run: bool) -> void:
	await _reset()
	player.sprint_toggled = run
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	Input.action_press("move_up", 1.0)
	await _frames(30)
	_samp.start(player)
	for f in 180:
		var n := rng.randf_range(-0.06, 0.06)
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_press("move_right" if n > 0.0 else "move_left", absf(n))
		await physics_frame
	var name := "stick_noise_run" if run else "stick_noise_walk"
	_report(name, _samp.stats())
	_release()

## From standstill (or running) facing screen-up, the stick flips to screen-down: yaw within 0.08 rad (the 3 deg facing slack) of PI in 0.3 s.
func _case_turn_180(run: bool) -> void:
	await _reset()
	player.sprint_toggled = run
	if run:
		Input.action_press("move_up", 1.0)
		await _frames(60)
		Input.action_release("move_up")
	var up: Vector3 = player.sim.cam_dir(Vector2(0, -1))
	var y0 := atan2(-up.x, -up.z)
	if not run:
		player.visual.rotation.y = y0
		await _frames(2)
	Input.action_press("move_down", 1.0)
	var frames := 0
	for f in 120:
		await physics_frame
		frames += 1
		if absf(angle_difference(player.visual.global_rotation.y, y0 + PI)) < 0.08:
			break
	_release()
	var secs := frames / 60.0
	var name := "turn180_running" if run else "turn180_standstill"
	print("[t_playerturn] case=%s seconds=%.3f" % [name, secs])
	_expect(secs <= TURN_180_S + 0.001, "%s: 180 deg in %.3f s <= %.2f" % [name, secs, TURN_180_S])

func _case_strafe_fight() -> void:
	await _reset()
	var c = _dino(&"deinonychus", Vector3(0, 0, 1.8))
	await _frames(3)
	player.hunt.start(c)
	_samp.start(player)
	var t := 0.0
	for f in 240:
		_strafe(c, player.global_position, 1.8, t)
		t += 1.0 / 60.0
		await physics_frame
	_report("strafe_autoattack", _samp.stats())

func _case_stick_walk_away() -> void:
	await _reset()
	var c = _dino(&"deinonychus", Vector3(0, 0, -1.8))
	await _frames(3)
	player.hunt.start(c)
	await _frames(30)
	var start: Vector3 = player.global_position
	var centre := start
	Input.action_press("move_down", 1.0)  # +Z, away from it
	_samp.start(player)
	var t := 0.0
	for f in 120:
		_strafe(c, centre, 1.8, t)  # it keeps dancing where the fight was
		t += 1.0 / 60.0
		await physics_frame
	var st := _samp.stats()
	_release()
	_report("stick_walk_away", st)
	var moved: float = player.global_position.z - start.z
	_expect(moved > 4.0, "stick_walk_away: she walks away %.1f m (> 4)" % moved)
	_expect(int(st[2]) == 0, "stick_walk_away: no position jitter (%d velocity flips)" % st[2])

## A ground tap during a fight: she walks to it, nothing pulls her back, then re-engages.
func _case_tap_walk_away(target_dies: bool) -> void:
	await _reset()
	var c = _dino(&"deinonychus", Vector3(0, 0, -1.8))
	var other = _dino(&"protoceratops", Vector3(-3, 0, 12)) if target_dies else null
	await _frames(3)
	player.hunt.start(c)
	await _frames(30)
	var centre: Vector3 = player.global_position
	var goal := BuildGrid_centre(Vector3(0, 0, 9), null)  # a tap walks to its tile's centre
	var swings := [0]
	var count := func () -> void: swings[0] += 1
	player.hunt.swing_started.connect(count)
	var kind: StringName = _tap(goal)
	_samp.start(player)
	var t := 0.0
	var reached := false
	for f in 360:
		if is_instance_valid(c):
			_strafe(c, centre, 1.8, t)
		if target_dies and f == 30 and is_instance_valid(c):
			c.queue_free()
		t += 1.0 / 60.0
		await physics_frame
		if not player.move_order:
			reached = _arrived(goal)
			break
	var st := _samp.stats()
	player.hunt.swing_started.disconnect(count)
	var name := "tap_walk_away_target_gone" if target_dies else "tap_walk_away"
	_report(name, st)
	_expect(kind == &"ground", "%s: the tap is a ground move (%s)" % [name, kind])
	_expect(reached, "%s: she reaches the tapped spot (at %s)" % [name, player.global_position])
	_expect(int(swings[0]) == 0, "%s: no swing on the way (%d)" % [name, swings[0]])
	_expect(int(st[2]) == 0, "%s: no position jitter (%d velocity flips)" % [name, st[2]])
	await _frames(10)
	var want = other if target_dies else c
	_expect(player.hunt.target == want and want != null, "%s: on arrival she re-engages %s (hunt target %s)" % [
		name, "the nearest animal" if target_dies else "her target", player.hunt.target.def.id if player.hunt.target else "none"])

## The move-priority rule: a bite on the way cancels the walk and she fights the biter.
func _case_hit_on_the_way() -> void:
	await _reset()
	var c = _dino(&"deinonychus", Vector3(0, 0, -1.8))
	await _frames(3)
	player.hunt.start(c)
	await _frames(10)
	_tap(Vector3(0, 0, 9))
	await _frames(40)
	var b = _dino(&"velociraptor", player.global_position + Vector3(1.5, 0, 0))
	player.receive_creature_hit(b, &"bite")
	await _frames(40)
	_expect(player.hunt.target == b, "hit_on_the_way: a bite during the walk turns her on the biter (%s)" % [
		player.hunt.target.def.id if player.hunt.target else "none"])
	_expect(not player.nav_active, "hit_on_the_way: the walk is cancelled")

# ---------------------------------------------------------------- mounted

func _case_mounted(id: StringName) -> void:
	await _reset()
	var def = data.creature(id)
	var rec = load("res://scripts/pets/pet_record.gd").from_def(def, &"A")
	rec.fit_saddle()  # SADDLES: riding needs one
	var m = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	player.get_parent().add_child(m)
	m.is_pet = true
	m.pet_record = rec
	m.spawn(def, rec.variant)
	m.global_position = player.global_position + Vector3(3, 0.2, 0)
	await _frames(20)
	player.mount(m)
	await _frames(20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	Input.action_press("move_up", 1.0)
	await _frames(60)
	_samp.start(player)
	var mx := 0.0
	for f in 180:
		var n := rng.randf_range(-0.06, 0.06)
		Input.action_release("move_left")
		Input.action_release("move_right")
		if f >= 90:
			Input.action_release("move_up")
			Input.action_press("move_right", 1.0)  # a hard 90 deg turn, under the mount's own rate
		else:
			Input.action_press("move_right" if n > 0.0 else "move_left", absf(n))
		var before: float = m.rotation.y
		await physics_frame
		mx = maxf(mx, absf(angle_difference(before, m.rotation.y)))
	var st := _samp.stats()
	_release()
	_report("mounted_%s" % id, st)
	var cap: float = m.turn_rate() / 60.0
	_expect(mx <= cap * 1.05 + 0.0001, "mounted_%s: the mount turns <= its rate (%.4f <= %.4f rad/frame)" % [id, mx, cap])
	player.dismount()
	await _frames(5)
	m.queue_free()

# ---------------------------------------------------------------- lab and island

func _case_creature_lab_tap() -> void:
	var lab: Node3D = (load("res://scenes/dev/creature_lab.tscn") as PackedScene).instantiate()
	get_root().add_child(lab)
	await _frames(40)
	player = lab.get("_player")
	for c in get_nodes_in_group("creatures"):
		c.queue_free()
	await _frames(20)
	for tap in [Vector3(-6, 0, 8), Vector3(9, 0, 1), Vector3(2, 0, -12)]:  # the 2nd and 3rd run past the lab's crates
		var goal := BuildGrid_centre(tap, null)
		var kind: StringName = _tap(goal)
		_samp.start(player)
		var reached := false
		for f in 600:
			await physics_frame
			if _arrived(goal) and not player.nav_active:
				reached = true
				break
		var st := _samp.stats()
		_report("creature_lab_tap_%d_%d" % [goal.x, goal.z], st)
		_expect(kind == &"ground" and reached, "creature_lab: a ground tap walks to %s (%s, at %s)" % [goal, kind, player.global_position])
		_expect(int(st[2]) <= 1, "creature_lab: no position jitter on the way (%d velocity flips)" % st[2])
	Game_lab_off()
	lab.queue_free()
	await _frames(5)

func Game_lab_off() -> void:
	var g := get_root().get_node("Game")
	g.lab_force_clips = false
	g.lab_flat_attack = false

func _case_island_walk_away() -> void:
	var world := get_root().get_node("World")
	world.set("creation_pending", false)
	for n in get_nodes_in_group(&"character_creation"):
		n.free()
	for n in get_nodes_in_group(&"island_pick"):
		n.free()
	host = Node3D.new()
	host.name = "TPlayerTurnIsland"
	get_root().add_child(host)
	player = LabKit.build(host, 4.0)["player"]
	world.call("load_island", host, &"home_grassland", Vector3(0, 1, 18), false)
	await _frames(60)
	for n in get_nodes_in_group(&"island_pick"):
		n.free()
	var rt: Node3D = world.get("runtime")
	_expect(rt != null and player.sim.use_tile_path(), "island: built, and the survivor routes on its tile paths")
	for c in get_nodes_in_group("creatures"):
		c.queue_free()
	await _frames(5)
	var start: Vector3 = player.global_position
	var c = _dino(&"deinonychus", start + Vector3(0, 0, -1.8), rt)
	await _frames(3)
	player.hunt.start(c)
	await _frames(30)
	var goal: Vector3 = BuildGrid_centre(start + Vector3(4, 0, 6), rt)
	var kind: StringName = _tap(goal)
	_samp.start(player)
	var t := 0.0
	var reached := false
	for f in 600:
		_strafe(c, start, 1.8, t)
		t += 1.0 / 60.0
		await physics_frame
		if not player.move_order:
			reached = _arrived(goal, 1.6)
			break
	var st := _samp.stats()
	_report("island_tap_walk_away", st)
	_expect(kind == &"ground" and reached, "island: the tap walk-away reaches %s (%s, at %s)" % [goal, kind, player.global_position])
	_expect(int(st[2]) == 0, "island: no position jitter (%d velocity flips)" % st[2])
	await _frames(10)
	_expect(player.hunt.target == c, "island: she re-engages on arrival")

func BuildGrid_centre(at: Vector3, rt: Node) -> Vector3:
	var bg: GDScript = load("res://scripts/world/build_grid.gd")
	return bg.tile_centre(bg.tile_of(at), rt)
