extends SceneTree
## KNOCKDOWN (owner 2026-10-31: "the dinosaurs should be able to charge and knock us on our ass or throw us etc. the
## player should get thrown around and have a falling on his butt animation, wind knocked out of him").
##  1. The tier comes from the hit (push x attacker size, lift), not the species: a zebraceratops shove is light, a
##     pachy ram knocks down, a triceratops / carnotaurus / woolly rhino charge throws.
##  2. A heavy ram knocks her down: fall_back -> lie -> get_up, cannot walk or swing meanwhile, then Winded
##     (the winded idle, no sprint, no swing) that ends on time.
##  3. A charge throws her: airborne on an arc, lands at least THROW_MIN_M away on the floor, stops at a wall
##     (never inside it), then the get-up.
##  4. GOD mode: a knockdown hit still knocks her down and costs no health; a knockdown-token hit (styracosaurus)
##     lays her down through the status.
## Usage: godot --headless --path game --script res://tests/t_knockdown.gd  -> "[t_knockdown] PASS"

var failures: Array[String] = []
var _started := false
var host: Node3D
var data: Node
var game: Node
var KN: GDScript  # PlayerKnock, CreatureAttack, TacticalBrain, Creature: loaded once the autoloads exist
var CA: GDScript
var TB: GDScript
var CR: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("[t_knockdown] FAIL %s" % msg)
	else:
		print("[t_knockdown] ok %s" % msg)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _secs(s: float) -> void:
	await _frames(int(ceil(s * Engine.physics_ticks_per_second)))

func _run() -> void:
	data = get_root().get_node("Data")
	game = get_root().get_node("Game")
	KN = load("res://scripts/player/player_knock.gd")
	CA = load("res://scripts/combat/creature_attack.gd")
	TB = load("res://scripts/creatures/brains/tactical_brain.gd")
	CR = load("res://scripts/creatures/creature.gd")
	host = Node3D.new()
	get_root().add_child(host)
	_box(Vector3(0, -0.5, 0), Vector3(200, 1, 200))  # the floor
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
	_test_tiers()
	await _test_ram_knockdown()
	await _test_charge_throw()
	await _test_throw_into_wall()
	await _test_god_mode()
	if failures.is_empty():
		print("[t_knockdown] PASS")
		quit(0)
	else:
		print("[t_knockdown] FAIL %d" % failures.size())
		quit(1)

func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	b.position = at
	host.add_child(b)
	return b

func _player(at: Vector3):
	var p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.position = at
	host.add_child(p)
	return p

func _creature(id: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.spawn(data.creature(id))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func _tac(id: StringName, key: String) -> float:
	var c = data.creature(id)
	return float(TB.tactics_for_def(c).get(key, 0.0)) if c else 0.0

func _who(id: StringName):
	var c = CR.new()
	c.def = data.creature(id)
	return c

## 1. Tier from push x size and lift.
func _test_tiers() -> void:
	var K = KN
	var cases := [
		[&"zebraceratops", "charge_shove_m", 0.0, K.Tier.LIGHT],
		[&"pachycephalosaurus", "charge_shove_m", 0.0, K.Tier.KNOCKDOWN],
		[&"styracosaurus", "charge_shove_m", 0.0, K.Tier.THROW],  # STYRAFIX made it bigger (size 1.5)
		[&"triceratops", "charge_shove_m", 0.0, K.Tier.THROW],
		[&"carnotaurus", "charge_shove_m", 0.0, K.Tier.THROW],
		[&"woolly_rhino", "charge_shove_m", 5.5, K.Tier.THROW],
	]
	for row in cases:
		var who = _who(row[0])
		var push: float = _tac(row[0], row[1])
		var got: int = K.tier_for(push, row[2], who)
		_expect(got == row[3], "%s %s %.1f m x size %.2f -> tier %d (want %d)" % [row[0], row[1], push, K.size_scale(who), got, row[3]])
		who.free()

## 2. Heavy ram: down, lie, up, winded.
func _test_ram_knockdown() -> void:
	var p = _player(Vector3(-40, 0.9, 0))
	var pachy = _creature(&"pachycephalosaurus", Vector3(-43, 0, 0))
	await _frames(5)
	for c in [&"fall_back", &"airborne", &"lie", &"get_up", &"winded"]:
		_expect(p.rig.has_clip(c), "survivor has the %s clip" % c)
	_expect(p.rig.anim_player.get_animation(&"lie").loop_mode == Animation.LOOP_LINEAR and p.rig.anim_player.get_animation(&"get_up").loop_mode == Animation.LOOP_NONE, "lie loops, get_up plays once")
	var at: Vector3 = p.global_position
	p.sim.shove(Vector3(_tac(&"pachycephalosaurus", "charge_shove_m"), 0, 0), 0.6, 0.0, pachy)
	await _frames(2)
	_expect(p.sim.knock.phase == KN.Phase.FALL and p.anim.current_clip == &"fall_back", "a pachy ram knocks her down (clip %s)" % p.anim.current_clip)
	_expect(p.statuses.has(&"knockdown") and not p.statuses.can_act(), "she holds Knockdown (cannot act) while down")
	_expect(not p.hunt.swing_now() and p.sim.roll_refusal() != "", "no swing and no roll while down")
	await _secs(0.7)
	var slid: float = _flat(p.global_position - at).length()
	_expect(slid > 0.6 * _tac(&"pachycephalosaurus", "charge_shove_m"), "the ram still shoves her back (%.2f m)" % slid)
	var down_at: Vector3 = p.global_position
	p.nav_to(down_at + Vector3(0, 0, 6))
	await _secs(0.9)
	_expect(p.anim.current_clip == &"lie", "then she lies on her back (clip %s)" % p.anim.current_clip)
	_expect(_flat(p.global_position - down_at).length() < 0.05, "she cannot walk while down (moved %.2f m)" % _flat(p.global_position - down_at).length())
	p.anim.on_damaged()
	_expect(p.anim.current_clip == &"lie", "a hit while down does not stand her up into a flinch")
	# ROOTED: rams, shoves and light hits that land while she lies there do not slide her anywhere.
	var lie_at: Vector3 = p.global_position
	p.sim.shove(Vector3(_tac(&"pachycephalosaurus", "charge_shove_m"), 0, 0), 0.6, 0.0, pachy)
	p.sim.shove(Vector3(0, 0, 0.8), 0.4)
	await _secs(0.15)
	_expect(_flat(p.global_position - lie_at).length() < 0.05, "hits while down do not move her (moved %.2f m)" % _flat(p.global_position - lie_at).length())
	var t := 0.0
	var saw_up := false
	while p.sim.knock.active() and t < 4.0:
		saw_up = saw_up or p.anim.current_clip == &"get_up"
		await _frames(1)
		t += 1.0 / Engine.physics_ticks_per_second
	_expect(saw_up and not p.sim.knock.active(), "she gets up (get_up played, %.1f s after lying)" % t)
	_expect(not p.statuses.has(&"knockdown") and p.statuses.can_act(), "Knockdown cleared when she stands")
	_expect(p.statuses.has(&"winded"), "she is Winded")
	await _frames(2)
	_expect(p.anim.current_clip == &"winded", "the winded idle plays (clip %s)" % p.anim.current_clip)
	p.sprint_toggled = true
	_expect(not p.sim.wants_sprint(), "no sprint while Winded")
	p.sprint_toggled = false
	_expect(p.statuses.has_flag(&"no_sprint") and p.statuses.has_flag(&"no_attack") and p.statuses.move_mult() < 1.0, "Winded: no sprint, no attack, slowed (x%.2f)" % p.statuses.move_mult())
	_expect(not p.hunt.can_start_tactic(), "no tackle or kick while Winded")
	var left: float = p.statuses.get_instance(&"winded").time_left
	await _secs(left + 0.2)
	_expect(not p.statuses.has(&"winded"), "Winded ends on time (%.1f s)" % left)
	await _frames(int(Engine.physics_ticks_per_second * 0.6))
	_expect(p.anim.current_clip != &"winded", "the winded idle is gone (clip %s)" % p.anim.current_clip)
	var at2: Vector3 = p.global_position
	p.nav_to(at2 + Vector3(0, 0, -6))
	await _frames(30)
	_expect(_flat(p.global_position - at2).length() > 0.3, "and she walks again (moved %.2f m)" % _flat(p.global_position - at2).length())
	p.clear_nav()
	pachy.queue_free()
	p.queue_free()

## 3. Big charge: thrown on an arc, lands metres away on the floor.
func _test_charge_throw() -> void:
	var p = _player(Vector3(0, 0.9, 30))
	var trike = _creature(&"triceratops", Vector3(-4, 0, 30))
	await _frames(5)
	var y0: float = p.global_position.y
	var push := Vector3(_tac(&"triceratops", "charge_shove_m"), 0, 0)
	p.sim.shove(push, 0.6, 0.0, trike)
	await _frames(2)
	_expect(p.sim.knock.phase == KN.Phase.AIR and p.anim.current_clip == &"airborne", "a triceratops charge throws her (clip %s)" % p.anim.current_clip)
	var peak := 0.0
	var t := 0.0
	while p.sim.knock.phase == KN.Phase.AIR and t < 4.0:
		peak = maxf(peak, p.global_position.y - y0)
		await _frames(1)
		t += 1.0 / Engine.physics_ticks_per_second
	var flew: float = _flat(p.sim.knock.landed_at - p.sim.knock.launched_at).length()
	_expect(peak > 0.8, "she goes up on an arc (%.2f m)" % peak)
	_expect(flew >= KN.THROW_MIN_M, "and lands %.1f m away (at least %.1f)" % [flew, KN.THROW_MIN_M])
	_expect(p.anim.current_clip == &"fall_back", "landing on her butt (clip %s)" % p.anim.current_clip)
	await _frames(10)
	_expect(p.is_on_floor() and absf(p.global_position.y - y0) < 0.15, "on the floor, not in it (y %.2f vs %.2f)" % [p.global_position.y, y0])
	var t2 := 0.0
	while p.sim.knock.active() and t2 < 6.0:
		await _frames(1)
		t2 += 1.0 / Engine.physics_ticks_per_second
	_expect(not p.sim.knock.active() and p.statuses.has(&"winded"), "she gets up winded after the throw")
	trike.queue_free()
	p.queue_free()

## 3b. Thrown at a wall: the arc stops at it, she never ends inside it.
func _test_throw_into_wall() -> void:
	var wall_x := 3.0
	var wall = _box(Vector3(wall_x + 0.5, 1.5, -30), Vector3(1, 3, 10))  # face at x = 3
	var p = _player(Vector3(0, 0.9, -30))
	await _frames(5)
	p.sim.shove(Vector3(8, 0, 0), 0.6, 5.0, null)
	var t := 0.0
	while p.sim.knock.active() and t < 6.0:
		await _frames(1)
		t += 1.0 / Engine.physics_ticks_per_second
	var r: float = (p.get_node("Shape").shape as CapsuleShape3D).radius
	_expect(p.global_position.x <= wall_x - r + 0.05, "a wall stops the throw: x %.2f, wall face %.2f, radius %.2f" % [p.global_position.x, wall_x, r])
	_expect(p.global_position.x > 1.0, "but she still flew up to it (x %.2f)" % p.global_position.x)
	wall.queue_free()
	p.queue_free()

## 4. GOD: the reaction lands, the health does not move.
func _test_god_mode() -> void:
	game.god_mode = true
	var p = _player(Vector3(40, 0.9, 0))
	var styr = _creature(&"styracosaurus", Vector3(42.2, 0, 0))
	styr.face_towards(p.global_position, 10.0)
	await _frames(5)
	var hp: float = p.vitals.health
	var landed: bool = CA.apply_for(styr, &"attack_heavy", p)
	await _frames(2)
	_expect(landed and p.statuses.has(&"knockdown"), "a styracosaurus heavy lands its Knockdown token")
	_expect(p.sim.knock.active() and p.anim.current_clip == &"fall_back", "GOD: the token knocks her down (clip %s)" % p.anim.current_clip)
	_expect(is_equal_approx(p.vitals.health, hp), "GOD: no health lost (%.1f -> %.1f)" % [hp, p.vitals.health])
	var t := 0.0
	while p.sim.knock.active() and t < 8.0:
		await _frames(1)
		t += 1.0 / Engine.physics_ticks_per_second
	_expect(not p.sim.knock.active() and p.statuses.can_act(), "she gets up after the token's knockdown (%.1f s)" % t)
	p.sim.shove(Vector3(-5, 0, 0), 0.6, 5.5, styr)
	await _frames(2)
	_expect(p.sim.knock.phase == KN.Phase.AIR and is_equal_approx(p.vitals.health, hp), "GOD: a toss still throws her, still no damage")
	game.god_mode = false
	styr.queue_free()
	p.queue_free()
