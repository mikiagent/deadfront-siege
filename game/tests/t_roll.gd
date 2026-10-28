extends SceneTree
## ROLL acceptance (owner 2026-10-28, spec 07 §2): the roll carries the survivor clear (longer than
## the old ~5.9 m, front-loaded, and never through a wall), the opening window dodges a creature hit
## that would have landed (no damage, no stagger, a "Dodged" float, Defense XP once) while a hit after
## the window still lands, it costs stamina, cannot be chained during its cooldown, pays no XP for
## spamming it, and the server path times the same window (RollRules).
## Usage: godot --headless --path game --script res://tests/t_roll.gd
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

## The roll this test replaces: ROLL_SPEED 13.0 x ROLL_SECONDS 0.45 measured 5.907 m on the floor.
const OLD_DISTANCE := 5.907
const WATCHDOG_S := 60.0

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var data: Node
var CA: GDScript            # CreatureAttack
var RR: GDScript            # RollRules
var STORE: GDScript         # CharacterStore
var FACADE: GDScript        # WorldFacade
var IH: GDScript            # IntentHandlers (loaded: it names Data at compile time)
var CT: GDScript            # CombatTuning
var _watchdog: float = 0.0

func _process(delta: float) -> bool:
	if _started:
		_watchdog += delta
		if _watchdog > WATCHDOG_S:
			print("[t_roll] FAIL watchdog: no PASS line in %.0f s" % WATCHDOG_S)
			quit(1)
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	CA = load("res://scripts/combat/creature_attack.gd")
	RR = load("res://scripts/combat/roll_rules.gd")
	STORE = load("res://scripts/server/character_store.gd")
	FACADE = load("res://scripts/server/world_facade.gd")
	IH = load("res://scripts/server/intent_handlers.gd")
	CT = load("res://scripts/combat/combat_tuning.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_roll] %s %s" % ["ok" if ok else "FAIL", what])

func _run() -> void:
	host = Node3D.new()
	host.name = "TRoll"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 160)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	# Camera behind +Z looking at the origin, the t_player setup: move_up walks -Z.
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 12, 12)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)
	player.vitals.max_health = 1000.0
	player.vitals.health = 1000.0
	await _frames(20)
	await _test_direction()
	await _test_distance()
	await _test_wall()
	await _test_iframes()
	await _test_cost_and_cooldown()
	await _test_no_xp_for_spam()
	_test_server()
	CT.reset_overrides()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_roll] PASS")
		quit(0)
	else:
		print("[t_roll] FAIL count=%d" % failures.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

## A creature with its brain off: the rules under test, not the AI.
func _creature(species: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.spawn(data.creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _clear_creatures() -> void:
	player.hunt.stop()
	for c in get_nodes_in_group("creatures"):
		c.queue_free()
	await process_frame

## Clean slate: paused at `pos`, stamina full, no roll in flight, no cooldown left.
func _reset_at(pos: Vector3) -> void:
	await _clear_creatures()
	player.velocity = Vector3.ZERO
	player.global_position = pos
	player.sim._roll_left = 0.0
	player.sim._roll_cd_left = 0.0
	player.sim._roll_buffer_left = 0.0
	player.sim._stagger_left = 0.0
	player.rolling = false
	player.vitals.dead = false
	player.dead = false
	player.vitals.energy = player.vitals.max_energy
	player.vitals.max_health = 1000.0
	player.vitals.health = 1000.0
	await _frames(20)

## Cumulative Defense XP (level and bank), so a level-up mid-test cannot hide a gain.
func _defense_total() -> float:
	var total := 0.0
	for l in range(1, player.skills.level_of("defense")):
		total += player.skills.xp_to_next(l)
	return total + player.skills.xp_of("defense")

## 0. OWNER RULE 2026-10-28: rolls are directional. Held input rolls that way; with no direction
## she rolls backward, away from where she faces, and keeps her facing. Measured on the live scene.
func _test_direction() -> void:
	# Facing +Z (rotation.y = PI puts the rig's -Z forward at +Z).
	await _reset_at(Vector3(0, 1.0, 0))
	player.visual.rotation.y = PI
	await _frames(2)
	var facing: Vector3 = -player.visual.global_basis.z
	var yaw0: float = player.visual.rotation.y
	var dir_left: Vector3 = player.sim.cam_dir(Vector2(-1, 0))
	var left_roll: bool = player.sim.try_roll(dir_left)
	while player.rolling:
		await physics_frame
	var moved_left: Vector3 = player.global_position - Vector3(0, 1.0, 0)
	print("[t_roll] measure left roll accepted=%s moved=(%.2f, %.2f) wanted=(%.2f, %.2f)" % [left_roll, moved_left.x, moved_left.z, dir_left.x, dir_left.z])
	_expect(left_roll and Vector2(moved_left.x, moved_left.z).normalized().dot(Vector2(dir_left.x, dir_left.z).normalized()) > 0.95,
		"holding left rolls her left (%.2f, %.2f)" % [moved_left.x, moved_left.z])
	# No input: backward, away from the facing, and she does not turn round.
	await _reset_at(Vector3(0, 1.0, 0))
	player.visual.rotation.y = PI
	await _frames(2)
	facing = -player.visual.global_basis.z
	yaw0 = player.visual.rotation.y
	var back_roll: bool = player.sim.try_roll(Vector3.ZERO)
	while player.rolling:
		await physics_frame
	var moved_back: Vector3 = player.global_position - Vector3(0, 1.0, 0)
	var yaw1: float = player.visual.rotation.y
	var flat := Vector2(moved_back.x, moved_back.z)
	print("[t_roll] measure no-input roll accepted=%s moved=(%.2f, %.2f) facing=(%.2f, %.2f) yaw %.2f -> %.2f" % [back_roll, flat.x, flat.y, facing.x, facing.z, yaw0, yaw1])
	_expect(back_roll and flat.length() > 1.0 and flat.normalized().dot(Vector2(facing.x, facing.z)) < -0.95,
		"with no direction held she rolls backward, away from her facing (moved %.2f, %.2f)" % [flat.x, flat.y])
	_expect(absf(angle_difference(yaw0, yaw1)) < 0.05, "a backward roll keeps her facing (yaw %.3f -> %.3f)" % [yaw0, yaw1])

## 1. The roll carries her clear: longer than the old 5.9 m, front-loaded, and it is the dash that
## Did the moving (measured on the live scene, never the constant).
func _test_distance() -> void:
	var target: float = RR.distance()
	await _reset_at(Vector3(0, 1.0, 0))
	var start: Vector3 = player.global_position
	var accepted: bool = player.sim.try_roll(Vector3(0, 0, 1))
	var first := 0.0
	var travelled := 0.0
	while player.rolling:
		await physics_frame
		var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
		travelled = moved
		if player.rolling and player.sim.roll_elapsed() <= 0.16:
			first = maxf(first, moved)
	print("[t_roll] measure roll accepted=%s distance=%.3f m front(%.2fs)=%.3f m target=%.3f m" % [accepted, travelled, minf(0.16, RR.iframes_s()), first, target])
	_expect(accepted and travelled >= 0.9 * target, "the roll covers %.2f m (target %.2f m from data/combat_tuning.json)" % [travelled, target])
	_expect(travelled >= 1.6 * OLD_DISTANCE, "the roll reaches %.2f m, at least 1.6 x the old %.2f m" % [travelled, OLD_DISTANCE])
	_expect(first >= 0.42 * travelled, "the speed curve is front-loaded: %.2f m of %.2f m inside the first 0.16 s" % [first, travelled])

## 2. A wall stops her exactly where a walk would: no terrain or obstacle is rolled through.
func _test_wall() -> void:
	await _reset_at(Vector3(0, 1.0, 0))
	var wall := StaticBody3D.new()
	var ws := CollisionShape3D.new()
	var wb := BoxShape3D.new()
	wb.size = Vector3(20, 4, 1)
	ws.shape = wb
	wall.add_child(ws)
	wall.position = Vector3(0, 2, -3)
	host.add_child(wall)
	await _frames(3)
	var start: Vector3 = player.global_position
	player.sim.try_roll(Vector3(0, 0, -1))
	while player.rolling:
		await physics_frame
	var travelled := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	print("[t_roll] measure wall distance=%.3f m (wall face at 2.50 m)" % travelled)
	_expect(travelled >= 1.0 and travelled < 3.0, "a wall 3 m ahead stops the roll at %.2f m (not through it, not short of it)" % travelled)
	wall.queue_free()
	await _frames(3)

## 3. I-frames: a bite that would have landed 0.15 s into the roll deals nothing, staggers nothing
## and pays Defense XP once; the same bite 0.5 s in (after the window) still lands.
func _test_iframes() -> void:
	CT.force_accuracy = 1.0
	CT.force_dodge = 0.0
	await _reset_at(Vector3(0, 1.0, 0))
	var raptor = _creature(&"velociraptor", Vector3(0, 0, -1.6))
	await _frames(5)
	var hp0: float = player.vitals.health
	var xp0 := _defense_total()
	player.sim.try_roll(Vector3(0, 0, 1))
	while player.sim.roll_elapsed() < 0.15:
		await physics_frame
	var t_in: float = player.sim.roll_elapsed()
	var landed_in: bool = CA.apply_for(raptor, &"attack_primary", player)
	var hp_in: float = player.vitals.health
	var xp_in := _defense_total()
	var staggered_in: bool = player.sim._stagger_left > 0.0
	print("[t_roll] measure bite at %.2fs: landed=%s dmg=%.2f defense_xp=%.1f stagger=%s" % [t_in, landed_in, hp0 - hp_in, xp_in - xp0, staggered_in])
	_expect(t_in < RR.iframes_s() and not landed_in and is_equal_approx(hp_in, hp0), "a bite %.2f s into the roll deals 0 damage" % t_in)
	_expect(not staggered_in, "the dodged bite applies no stagger")
	_expect(is_equal_approx(xp_in - xp0, float(RR.defense_xp())), "the real dodge pays Defense XP once (%.1f)" % (xp_in - xp0))
	# A second bite, also inside the window: each attack is judged on its own, never twice.
	var hp_mid: float = player.vitals.health
	var xp_mid0 := _defense_total()
	if player.sim.roll_invulnerable():
		CA.apply_for(raptor, &"attack_primary", player)
		print("[t_roll] measure second bite inside the window: dmg=%.2f defense_xp=%.1f" % [hp_mid - player.vitals.health, _defense_total() - xp_mid0])
		_expect(is_equal_approx(player.vitals.health, hp_mid), "a second bite inside the window also deals 0")
	# After the window the roll still moves her, but the bite lands: the window is the shield.
	await _reset_at(Vector3(0, 1.0, 0))
	player.vitals.health = 1000.0
	raptor = _creature(&"velociraptor", Vector3(0, 0, -1.6))
	await _frames(5)
	xp0 = _defense_total()
	player.sim.try_roll(Vector3(0, 0, 1))
	while player.sim.roll_elapsed() < 0.5:
		await physics_frame
	raptor.global_position = player.global_position + Vector3(0, -1.0, -1.4)
	await _frames(2)
	var t_out: float = player.sim.roll_elapsed()
	var landed_out: bool = CA.apply_for(raptor, &"attack_primary", player)
	var dmg_out: float = 1000.0 - player.vitals.health
	print("[t_roll] measure bite at %.2fs: landed=%s dmg=%.2f" % [t_out, landed_out, dmg_out])
	_expect(t_out >= RR.iframes_s() and landed_out and dmg_out > 0.0, "a bite %.2f s in (after the %.2f s window) deals %.1f damage" % [t_out, RR.iframes_s(), dmg_out])
	while player.rolling:
		await physics_frame
	CT.reset_overrides()
	await _clear_creatures()

## 4. Cost and limits: the press spends RollRules.stamina(), and another press inside the cooldown
## is refused (so it cannot be chained).
func _test_cost_and_cooldown() -> void:
	await _reset_at(Vector3(0, 1.0, 0))
	var e0: float = player.vitals.energy
	var first: bool = player.sim.try_roll(Vector3(0, 0, 1))
	var spent: float = e0 - player.vitals.energy
	print("[t_roll] measure stamina spent=%.1f (want %.1f)" % [spent, RR.stamina()])
	_expect(first and absf(spent - RR.stamina()) <= 0.5, "the roll spends %.1f stamina" % spent)
	while player.rolling:
		await physics_frame
	var cd_left: float = player.sim.roll_cooldown_left()
	var again: bool = player.sim.try_roll(Vector3(0, 0, 1))
	print("[t_roll] measure cooldown left after the dash=%.2f s refused=%s (%s)" % [cd_left, not again, player.sim.roll_refusal()])
	_expect(cd_left > 0.0 and not again and not player.rolling, "a roll during the cooldown is refused")
	await create_timer(RR.cooldown_s(), true, true).timeout
	_expect(player.sim.try_roll(Vector3(0, 0, 1)), "once the cooldown is over the roll is accepted again")
	while player.rolling:
		await physics_frame

## 5. Spamming Roll with no attack in sight pays no Defense XP (spec 07 §2).
func _test_no_xp_for_spam() -> void:
	await _reset_at(Vector3(0, 1.0, 0))
	var xp0 := _defense_total()
	var rolls := 0
	for i in 3:
		player.vitals.energy = player.vitals.max_energy
		if player.sim.try_roll(Vector3(0, 0, 1)):
			rolls += 1
		while player.rolling:
			await physics_frame
		await create_timer(RR.cooldown_s(), true, true).timeout
	var gained := _defense_total() - xp0
	print("[t_roll] measure spam rolls=%d defense_xp_gained=%.1f" % [rolls, gained])
	_expect(rolls == 3 and is_zero_approx(gained), "three rolls with no attack pay no Defense XP (%.1f)" % gained)

## 6. The server honours the same window: act.roll stamps the press, rolls_dodge() judges a hit at
## its own time with RollRules, and the cooldown is the same rule.
func _test_server() -> void:
	var w = FACADE.new()
	var st = STORE.new(w, "", 4242)
	var created: Dictionary = st.apply("char.create", 1, {"name": "Roller"}, 1)
	_expect(bool(created.get("ok", false)), "the server has a character to roll")
	var ch = st.character(1)
	var press: Dictionary = st.apply("act.roll", 1, {"ms": 200}, 10)
	var ok := bool(press.get("ok", false))
	var base: int = ch.roll_ms()
	print("[t_roll] measure server roll ok=%s roll_ms=%d" % [ok, base])
	_expect(ok and base == 10200, "act.roll stamps the press (roll_ms %d)" % base)
	var agree := true
	var rows: Array[String] = []
	for ms in [0, 150, 250, 319, 330, 500, 900]:
		var at: int = base + ms
		var server: bool = IH.rolls_dodge(ch, at)
		var client: bool = RR.invulnerable_at(float(ms) * 0.001)
		agree = agree and server == client
		rows.append("%dms:%s" % [ms, "dodge" if server else "hit"])
	print("[t_roll] measure server vs client window %s" % [", ".join(rows)])
	_expect(agree and IH.rolls_dodge(ch, base + 150) and not IH.rolls_dodge(ch, base + 500),
		"the server dodges at 0.15 s and takes the hit at 0.5 s, exactly where the client does")
	var early: Dictionary = st.apply("act.roll", 1, {"ms": 300}, 10)
	print("[t_roll] measure second server roll inside the cooldown: %s" % early.get("err", "ok"))
	_expect(str(early.get("err", "")) == "not_ready", "a server roll inside the cooldown is refused (not_ready)")
	var later: Dictionary = st.apply("act.roll", 1, {"ms": 0}, 12)
	ch = st.character(1)  # a committed op stores its own normalised state
	print("[t_roll] measure server roll after the cooldown: %s roll_ms=%s" % [later.get("err", "ok"), str(ch.roll_ms())])
	_expect(bool(later.get("ok", false)) and ch.roll_ms() == 12000, "a server roll after the cooldown is accepted")
	_expect(not IH.rolls_dodge(ch, 12000 + 330) and not IH.rolls_dodge(ch, 12000 + 900), "the new press closes the old window")
