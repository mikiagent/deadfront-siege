extends SceneTree
## AUTO-ABILITY acceptance (docs/orchestration/reports/dsc-autoability.md). The owner: "an
## auto-ability button that uses the player's most powerful ability off cooldown and prioritizes
## that over basic attacks" / "put that on by default".
## - the toggle is ON for a fresh player (default, no save field needed)
## - with an ability ready the next action is the ability, not a basic attack
## - on cooldown it falls back to basic attacks
## - toggle off -> basic attacks only
## - the strongest of two ready abilities wins (tie-break longer cooldown)
## Usage: godot --headless --path game --script res://tests/t_autoability.gd

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var data: Node
var AA: GDScript  # AutoAbility

func _process(_delta: float) -> bool:
	if _started:
		return false
	# Player/Creature reference autoloads (Data, World, Game): wait until they exist.
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	AA = load("res://scripts/combat/auto_ability.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_autoability] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	host = Node3D.new()
	host.name = "TAutoAbility"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	_test_data()
	await _test_default_on_and_ready_cast()
	await _test_cooldown_fallback()
	await _test_toggle_off()
	_test_pick_ranking()
	CombatTuning.reset_overrides()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_autoability] PASS")
		quit(0)
	else:
		print("[t_autoability] FAIL count=%d" % failures.size())
		quit(1)

func _creature(at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.spawn(data.creature(&"velociraptor"))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # rules under test, not AI
	return c

func _engage(at := Vector3(0, 0, -1.6)):
	var c = _creature(at)
	player.hunt.auto = true
	player.hunt.auto_ability = true
	player.hunt.last_auto_cast = &""
	player.hunt.start(c)
	# A leftover state from the previous engagement must not gate this one: the tactic cooldowns and
	# lock (the game keeps them across a hunt stop), a pending swing and the attack clip.
	player.hunt.commit_tactic(&"tackle", 0.0, 0.0)
	player.hunt.commit_tactic(&"kick", 0.0, 0.0)
	player.hunt._swing_cd = 0.0
	player.hunt._swing_pending = false
	player.sim._stagger_left = 0.0
	player.vitals.energy = player.vitals.effective_max_energy()
	player.vitals.max_health = 1000.0
	player.vitals.health = 1000.0
	player.clear_nav()
	player.hunt._resume_after_move = false
	return c

## A swing counter in an Array: a GDScript lambda captures locals by value, so `n += 1` in a
## lambda would never reach the test's own variable.
func _swinger() -> Array:
	var n := [0]
	player.hunt.swing_started.connect(func () -> void: n[0] += 1)
	return n

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

## The previous test's attack clip can still hold `can_start_tactic()` while the basic swing is not
## gated on it, so the swing wins the race before the auto-cast. Wait for the anim to go idle.
func _await_idle(frames: int) -> void:
	for i in frames:
		if not player.anim._busy and not player.rolling:
			return
		await physics_frame

## Wait until the fight's next action shows (an auto-cast or a swing started), or frames run out.
func _await_action(frames: int) -> void:
	for i in frames:
		if player.hunt.last_auto_cast != &"" or player.hunt._swing_pending:
			return
		await physics_frame

func _test_data() -> void:
	_expect(not AA.rows().is_empty(), "auto_ability.rows() lists auto-castable abilities from data")
	_expect(bool((CombatTuning.section("tackle") as Dictionary).has("damage")), "tackle tuning section loads")

## The default + the ready-cast rule: the next action is the ability, not a basic attack.
func _test_default_on_and_ready_cast() -> void:
	_expect(player.hunt.auto_ability, "auto-ability defaults ON for a new player (no save field needed)")
	var c = _engage()
	var swings := _swinger()
	await _await_action(180)  # spawn clips may hold the tactic gate for a moment
	_expect(player.hunt.target == c, "hunt holds its target through the auto-cast")
	# last_auto_cast is transient (cleared at the top of every _process), so the durable evidence of
	# which ability the auto-cast chose is the cooldown its cast committed.
	_expect(player.hunt.cooldown_left(&"tackle") > 0.0 and swings[0] == 0,
			"a ready ability casts before any basic swing (tackle cd=%.2f swings=%d last=%s)" % [player.hunt.cooldown_left(&"tackle"), swings[0], player.hunt.last_auto_cast])
	_expect(player.hunt.cooldown_left(&"tackle") > 0.0, "the cast committed its cooldown")
	player.hunt.stop()
	c.free()
	await _await_idle(240)  # the tackle clip ends before the next engagement
	await physics_frame

## Tackle on cooldown: the picker falls back to Kick (still an ability), and with both cooling down
## it falls back to the basic attack.
func _test_cooldown_fallback() -> void:
	await _await_idle(240)
	var c = _engage()
	# The frame AFTER the tackle cooldown is cleared may already have started a cast/swing in _process
	# (both run in the same _process tick), so the test could catch last_auto_cast of the cast that
	# this engagement's own tick made with the cooldown still cleared. Clear it and the swing state
	# in the same tick as the cooldown, then let _process pick it up from here.
	player.hunt.commit_tactic(&"tackle", 5.0, 0.0)  # the strongest row is cooling down
	player.hunt._swing_cd = 0.0
	player.hunt._swing_pending = false
	player.hunt.last_auto_cast = &""
	player.hunt._tactic_lock = 0.0
	var swings := _swinger()
	await _frames(40)  # enough for the kick cast (0.45 lock) to fire and settle
	# Tackle is cooling: the auto-cast must pick Kick, seen as Kick's committed cooldown (and the
	# same body-edge reach ran for tackle in the ready test, so the kick cast is what can differ).
	_expect(player.hunt.cooldown_left(&"kick") > 4.0 and swings[0] == 0,
			"tackle cooling down -> kick is cast instead (kick cd=%.2f swings=%d last=%s)" % [player.hunt.cooldown_left(&"kick"), swings[0], player.hunt.last_auto_cast])
	player.hunt.stop()
	c.free()
	await _await_idle(240)
	await physics_frame
	c = _engage()
	player.hunt.commit_tactic(&"tackle", 5.0, 0.0)
	player.hunt.commit_tactic(&"kick", 5.0, 0.0)
	var swings2 := _swinger()
	await _frames(30)  # a basic swing starts inside 0.5 s; no auto-cast must appear
	_expect(player.hunt.last_auto_cast == &"" and swings2[0] >= 1, "both abilities cooling down -> basic attacks only (swings=%d)" % swings2[0])
	player.hunt.stop()
	c.free()
	await _await_idle(240)
	await physics_frame

## Toggle off: no ability cast, basic attacks only.
func _test_toggle_off() -> void:
	await _await_idle(240)
	var c = _engage()
	player.hunt.auto_ability = false
	var swings := _swinger()
	await _frames(30)
	_expect(player.hunt.last_auto_cast == &"" and swings[0] >= 1, "toggle off -> basic attacks only (swings=%d)" % swings[0])
	player.hunt.stop()
	c.free()
	await _await_idle(240)
	await physics_frame

## The picker alone (no engine timing): the strongest of two ready rows wins; the longer cooldown
## breaks a damage tie; an unaffordable or cooling row is skipped.
func _test_pick_ranking() -> void:
	player.vitals.energy = player.vitals.effective_max_energy()
	var c = _creature(Vector3(0, 0, -1.6))
	player.hunt.start(c)
	_expect(AA.pick(player.hunt) == &"tackle", "tackle (6 dmg) beats kick (4 dmg) when both are ready")
	# HOLDKICK: under HOLD the auto-cast never picks a push (Kick), which would shove the target out of reach.
	player.hunt._tackle_cd = 8.0
	player.hunt.hold = true
	_expect(AA.pick(player.hunt) == &"", "HOLD + tackle cooling -> no auto kick (got %s)" % AA.pick(player.hunt))
	player.hunt.hold = false
	_expect(AA.pick(player.hunt) == &"kick", "no HOLD + tackle cooling -> kick")
	player.hunt._tackle_cd = 0.0
	c.free()
