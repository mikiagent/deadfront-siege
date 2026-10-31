extends SceneTree
## NO TELEPORT (owner 2026-10-31: "Pachy is teleporting or something", "Smilodon kind of teleports too"): every
## modelled species fights the GOD survivor (auto-fighting, so her kick and tackle fire) in a lab world with a baked
## navmesh, and no physics frame moves its body, or its hips within the body, further than its top speed x dt x 3
## (top speed: its run at the charge multiplier, or LEAP_MPS for leaps; a fast turn swinging the hips round is not a
## jump). Then the survivor kicks each kickable animal: it slides back over the stagger, never in one frame.
## The cause was the survivor's kick: CombatTactics.kick moved the
## target its whole push (3.5 m on a pachy or a smilodon) in one move_and_collide; now Creature.shove slides it.
## Run: Godot --headless --path game --script res://tests/t_noteleport.gd  -> "[t_noteleport] PASS", exit 0.
## Env NOTELEPORT_SPECIES=a,b limits the roster.

const SECS := 10.0
const LEAP_MPS := 20.0  ## m/s: a pounce or leap-in arc's top flat speed (bounded by its distance over its airborne time)

var failures: Array[String] = []
var _started := false

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_noteleport] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

## Top flat speed this animal may legitimately reach (m/s).
static func top_speed(c) -> float:
	var tac: Dictionary = c.brain.tac if "tac" in c.brain else {}
	var mult := maxf(float(tac.get("charge_speed_mult", 1.5)), 1.5)
	return c.move_speed_mps() * c.run_speed_mult() * mult

func _run() -> void:
	seed(20261031)
	Engine.max_physics_steps_per_frame = 1000
	var game := root.get_node("Game")
	game.debug_overlay = false
	game.god_mode = true
	var host := Node3D.new()
	root.add_child(host)
	var LK = load("res://scripts/dev/lab_kit.gd")
	var player: Node3D = LK.build(host)["player"]
	LK.bake(host)
	await physics_frame
	await physics_frame
	var start: Vector3 = player.global_position
	var roster: Array = []
	if OS.get_environment("NOTELEPORT_SPECIES") != "":
		roster = Array(OS.get_environment("NOTELEPORT_SPECIES").split(","))
	else:
		var PANEL = load("res://scripts/dev/lab_spawn_panel.gd")
		for id in PANEL.all_species():
			if PANEL.has_model(id):
				roster.append(id)
	var kicks := 0  ## kickable species checked
	var hz := float(Engine.physics_ticks_per_second)
	for id in roster:
		player.global_position = start
		player.velocity = Vector3.ZERO
		var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
		host.add_child(c)
		c.global_position = start + Vector3(0, 0, -8)
		c.spawn(root.get_node("Data").creature(StringName(id)), &"", 0, null, 0, &"aggressive")
		await physics_frame
		await physics_frame
		c.brain.on_aggro(player)
		var sks: Array = c.view.find_children("*", "Skeleton3D", true, false)
		var sk: Skeleton3D = sks[0] if not sks.is_empty() else null
		var hips := sk.find_bone("Hips") if sk else -1
		var top := maxf(top_speed(c), LEAP_MPS)
		var lim := top / hz * 3.0
		var worst := 0.0
		var worst_at := ""
		var prev: Vector3 = c.global_position
		var prevh := _hips(c, sk, hips)
		for f in int(SECS * hz):
			await physics_frame
			player.vitals.health = player.vitals.effective_max_health()
			if not is_instance_valid(c) or c.health.dead:
				break
			var pos: Vector3 = c.global_position
			var h := _hips(c, sk, hips)
			var db := Vector2(pos.x - prev.x, pos.z - prev.z).length()
			var d := maxf(db, Vector2(h.x - prevh.x, h.z - prevh.z).length())
			if d > worst:
				worst = d
				worst_at = "f%d %s/%s (body %.2f m)" % [f, c.brain.state, c.anim.current_clip, db]
			prev = pos
			prevh = h
		_expect(worst <= lim, "%s: worst frame step %.2f m <= %.2f m (top %.1f m/s x dt x 3) at %s" % [id, worst, lim, top, worst_at])
		if is_instance_valid(c) and not c.health.dead and load("res://scripts/combat/combat_tactics.gd").kick_push(c) > 0.0:
			kicks += 1
			await _kick(player, c, lim)
		if is_instance_valid(c):
			c.free()
		await physics_frame
	_expect(kicks > 0, "the kick check ran on %d kickable species" % kicks)
	if failures.is_empty():
		print("[t_noteleport] PASS")
		quit(0)
	else:
		print("[t_noteleport] FAIL %d" % failures.size())
		quit(1)

## The hips in the body's own frame: a clip snapping the root shows here, a turn of the whole body does not.
func _hips(c, sk: Skeleton3D, hips: int) -> Vector3:
	if hips < 0:
		return Vector3.ZERO
	return c.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(hips)).origin

## The survivor's kick, 2 m in front of her, both brains still (her loop and its brain off, its path cleared): the
## animal slides >= 0.3 m back, never more than lim in a frame.
func _kick(player, c, lim: float) -> void:
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.stop_move()
	player.process_mode = Node.PROCESS_MODE_DISABLED  # no auto-fight, no hurt clip running on
	player.rolling = false
	player.statuses.clear_all()  # a charge may have knocked her down (cannot_act)
	player.sim._stagger_left = 0.0
	player.anim._busy = false
	player.vitals.energy = player.vitals.effective_max_energy()
	c.global_position = player.global_position + Vector3(0, -0.95, -2.0)
	c.velocity = Vector3.ZERO
	c.stagger_left = 0.0
	await physics_frame
	await physics_frame
	player.hunt.commit_tactic(&"kick", 0.0, 0.0)
	player.hunt.start(c)
	var p0: Vector3 = c.global_position
	player.hunt.use_kick()  # the old code moved it right here, inside the call
	player.hunt.stop()
	var fired: bool = player.hunt.cooldown_left(&"kick") > 0.0
	var prev := p0
	var worst := 0.0
	for f in 40:
		var d := Vector2(c.global_position.x - prev.x, c.global_position.z - prev.z).length()
		worst = maxf(worst, d)
		prev = c.global_position
		await physics_frame
	var moved := Vector2(c.global_position.x - p0.x, c.global_position.z - p0.z).length()
	_expect(fired and worst <= lim and moved >= 0.3, "%s: the kick (fired %s, '%s') slides it %.2f m back, worst frame %.2f m <= %.2f m" % [c.def.id, fired, player.hunt.last_notice, moved, worst, lim])
	player.process_mode = Node.PROCESS_MODE_INHERIT
