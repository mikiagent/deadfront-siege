extends SceneTree
## BIGSTOMP (owner 2026-10-31: "the bigger dinosaurs all need a stomp mechanic where if you get close they will stomp the
## ground, shake the screen, and if you get stomped you probably take a lot of damage or die. Maybe you get pinned by the
## stomp attack -- ... the trexes would pin me and it would teleport me under their feet"). Real creatures, real brains:
## 1. every big modelled species has the shared stomp (and the ankylosaurus, which has its own, does not); standing in
##    the foot's shadow under it, it stomps within STOMP_WAIT_S, the foot lands inside the shadow, she is stomp-pinned
##    under the foot (pin_foot) and the camera shakes;
## 2. outside GOD a direct stomp from a T. rex takes at least half her health (or kills her);
## 3. in the ring but outside the shadow: knocked down, not pinned;
## 4. rolling out as the foot comes down: no damage, no pin;
## 5. pins never jump: through every stomp-pin and the tyrannosaurs' own heavy (rex, tarbosaurus, megarex), she never
##    moves more than MAX_STEP_M in one physics frame; a heavy that lands away from the foot knocks down, never pins.
## Run: Godot --headless --path game --script res://tests/t_bigstomp.gd  -> "[t_bigstomp] PASS", exit 0.

const SPECIES: Array[StringName] = [&"tyrannosaurus", &"tarbosaurus", &"megarex", &"carnotaurus", &"triceratops", &"styracosaurus", &"woolly_rhino"]
const STOMP_WAIT_S := 4.0
const MAX_STEP_M := 0.5
const DT := 1.0 / 60.0

var failures: Array[String] = []
var _started := false
var _watch := 0.0
var data: Node
var game: Node
var host: Node3D
var player: Node3D
var cam: Node
var _max_step := 0.0
var _last_pos := Vector3.ZERO
var BS: GDScript
var PH: GDScript
var CA: GDScript

func _process(delta: float) -> bool:
	if _started:
		_watch += delta
		if _watch > 400.0:
			print("[t_bigstomp] FAIL watchdog")
			quit(1)
		return false
	if root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_bigstomp] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	data = root.get_node("Data")
	BS = load("res://scripts/combat/big_stomp.gd")
	PH = load("res://scripts/combat/pin_hold.gd")
	CA = load("res://scripts/combat/creature_attack.gd")
	game = root.get_node("Game")
	game.debug_overlay = false
	game.god_mode = true
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	host = Node3D.new()
	host.name = "TBigStompHost"
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 120.0)
	player = kit["player"]
	cam = root.get_viewport().get_camera_3d()
	for i in 10:
		await physics_frame
	_test_roster()
	for id in SPECIES:
		await _test_direct(id)
	await _test_lethal()
	await _test_near()
	await _test_roll()
	for id in [&"tyrannosaurus", &"tarbosaurus", &"megarex"]:
		await _test_heavy_far(id)
	_expect(_max_step <= MAX_STEP_M, "no pin moved her more than %.1f m in one frame (worst %.3f m)" % [MAX_STEP_M, _max_step])
	game.god_mode = false
	if failures.is_empty():
		print("[t_bigstomp] PASS")
		quit(0)
	else:
		print("[t_bigstomp] FAIL %d" % failures.size())
		quit(1)

func _spawn(id: StringName):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = Vector3.ZERO
	c.spawn(data.creature(id))
	c.look_at(Vector3(0, 0, -10), Vector3.UP)  # faces -Z
	c.brain._roam_pause = 999.0
	return c

func _reset_player(at: Vector3) -> void:
	player.statuses.clear_all()
	if player.sim and player.sim.knock:
		player.sim.knock.cancel()
	player.global_position = Vector3(at.x, player.global_position.y, at.z)
	player.velocity = Vector3.ZERO
	player.vitals.health = player.vitals.max_health
	_last_pos = player.global_position

func _aggro(c) -> void:
	var b = c.brain
	b.attack_target = player
	if "_provoked_until" in b:
		b._provoked_until = b._now_s() + 60.0
	b._set_state(&"attack")

## One physics frame, tracking her biggest single-frame move while she is pinned or down.
func _frame() -> void:
	await physics_frame
	var p: Vector3 = player.global_position
	if player.statuses.has(&"pinned"):
		_max_step = maxf(_max_step, Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length())
	_last_pos = p

## Waits for the stomp to land (phase leaves windup) or for `secs`; true when it landed.
func _until_landed(c, secs: float) -> bool:
	var s = c.brain.stomp
	_aggro(c)
	for f in int(secs * 60.0):
		if s.phase == &"" and c.brain.attack_target != player:
			_aggro(c)
		var was: StringName = s.phase
		await _frame()
		if was == &"windup" and s.phase != &"windup":
			return true
	return false

## Provoked and facing her, done with its roar: it may stomp now (she stands well clear meanwhile).
func _ready_to_stomp(c) -> void:
	_reset_player(c.global_position + Vector3(0, 0, -30))
	_aggro(c)
	for f in 360:
		await physics_frame
		if c.brain.stomp_ready():
			break
	await physics_frame

func _test_roster() -> void:
	for id in SPECIES + [&"ankylosaurus", &"stegosaurus", &"velociraptor"]:
		var c = _spawn(id)
		var want: bool = id in SPECIES
		_expect((c.brain.stomp != null) == want, "%s %s" % [id, "has the shared stomp" if want else "has no shared stomp"])
		c.queue_free()

func _test_direct(id: StringName) -> void:
	var c = _spawn(id)
	await physics_frame
	var s = c.brain.stomp
	if s == null:
		c.queue_free()
		return
	await _ready_to_stomp(c)
	_reset_player(s.land_point())
	if cam:
		cam.trauma = 0.0
	var t0 := Time.get_ticks_msec()
	var landed := await _until_landed(c, STOMP_WAIT_S)
	_expect(landed, "%s stomps her under its foot within %.0f s (%.2f s, wind-up %.2f s)" % [id, STOMP_WAIT_S, (Time.get_ticks_msec() - t0) / 1000.0, s.windup])
	# where the foot really came down, in body heights from its centre (ai.json big_stomp.species.<id>.land)
	var sk = c.view.rig.skeleton
	var row: Dictionary = BS.species_row(id)
	var b: int = sk.find_bone(str(row.get("pin_bone", "Toe.R")))
	var foot: Vector3 = sk.global_transform * sk.get_bone_global_pose(b).origin
	var loc: Vector3 = c.global_basis.orthonormalized().inverse() * (foot - c.global_position)
	print("[t_bigstomp] %s foot landed at land=[%.3f, %.3f] (data %s), %.2f m from the ring centre (shadow %.2f m)" % [id, loc.x / s.height(), -loc.z / s.height(), str(row.get("land")), BS.flat(foot, s.spot), s.direct_radius()])
	_expect(BS.flat(foot, s.spot) <= s.direct_radius(), "%s: the foot comes down inside its shadow ring (%.2f m, shadow %.2f m)" % [id, BS.flat(foot, s.spot), s.direct_radius()])
	_expect(s.last == &"direct", "%s: the stomp lands on her directly (%s)" % [id, s.last])
	_expect(player.statuses.has(&"pinned") and c.pin_victim == player, "%s: she is stomp-pinned under the foot" % id)
	_expect(c.anim.current_clip == &"pin_foot", "%s holds pin_foot on her (%s)" % [id, c.anim.current_clip])
	_expect(s.last_shake > 0.3, "%s: the slam shakes the camera (%.2f)" % [id, s.last_shake])
	if cam:
		_expect(cam.trauma > 0.0, "%s: IsoCamera took the trauma (%.2f)" % [id, cam.trauma])
	for f in 60:
		await _frame()
	var claws: float = BS.flat(PH.foot_point(c), PH.chest_point(player))
	_expect(claws <= 0.6, "%s: her chest is under the pinning foot (%.2f m)" % [id, claws])
	for f in 300:
		await _frame()
		if c.pin_victim == null:
			break
	_expect(c.pin_victim == null and not player.statuses.has(&"pinned"), "%s lets her go when Pinned ends" % id)
	c.queue_free()
	await physics_frame

func _test_lethal() -> void:
	game.god_mode = false
	var c = _spawn(&"tyrannosaurus")
	await _ready_to_stomp(c)
	_reset_player(c.brain.stomp.land_point())
	var hp0: float = player.vitals.health
	await _until_landed(c, STOMP_WAIT_S)
	var hp1: float = player.vitals.health if not player.dead else 0.0
	_expect(player.dead or hp1 <= hp0 * 0.5, "outside GOD a direct T. rex stomp takes half her health or kills her (%.0f -> %.0f, dead %s)" % [hp0, hp1, player.dead])
	c.queue_free()
	await physics_frame
	game.god_mode = true
	if player.dead:
		player.respawn()
		for f in 10:
			await physics_frame

func _test_near() -> void:
	var c = _spawn(&"tyrannosaurus")
	await physics_frame
	var s = c.brain.stomp
	await _ready_to_stomp(c)
	var side: Vector3 = c.global_basis.x * (s.direct_radius() + 0.6 * (s.near_radius() - s.direct_radius()))
	_reset_player(s.land_point() + side)
	await _until_landed(c, STOMP_WAIT_S)
	await physics_frame
	_expect(s.last == &"near", "in the ring but out of the shadow: a near miss (%s)" % s.last)
	_expect(player.statuses.has(&"knockdown") and not player.statuses.has(&"pinned"), "the near miss knocks her down and does not pin")
	c.queue_free()
	for f in 300:
		await _frame()
		if not player.statuses.has(&"knockdown"):
			break

func _test_roll() -> void:
	game.god_mode = false
	var c = _spawn(&"tyrannosaurus")
	await physics_frame
	var s = c.brain.stomp
	await _ready_to_stomp(c)
	_reset_player(s.land_point())
	var hp0: float = player.vitals.health
	var rolled := false
	for f in int(STOMP_WAIT_S * 60.0):
		if s.phase == &"" and c.brain.attack_target != player:
			_aggro(c)
		if not rolled and s.phase == &"windup" and s.t >= s.windup - 0.15:
			player.sim._roll_cd_left = 0.0
			rolled = player.sim.try_roll(c.global_basis.x)
		var was: StringName = s.phase
		await _frame()
		if was == &"windup" and s.phase != &"windup":
			break
	await physics_frame
	_expect(rolled, "she rolls as the foot comes down")
	_expect(s.last in [&"dodged", &"clear"] and not player.statuses.has(&"pinned") and player.vitals.health >= hp0, "rolling out of the stomp: no damage, no pin (%s, %.0f -> %.0f)" % [s.last, hp0, player.vitals.health])
	c.queue_free()
	await physics_frame
	game.god_mode = true

## The tyrannosaurs' own heavy (attack_heavy: the stomp ahead, or the tarbosaurus' lunge clamp) landing on her away from
## its foot: a knockdown, no pin, no jump. Right at the foot: a pin that never jumps.
func _test_heavy_far(id: StringName) -> void:
	for near in [false, true]:
		var c = _spawn(id)
		await physics_frame
		c.brain.stomp = null  # only the species' own heavy here
		c.anim.play_clip(&"attack_heavy")
		for f in 50:
			await physics_frame
		var foot: Vector3 = PH.foot_point(c)
		var ahead: Vector3 = -c.global_basis.z
		_reset_player(foot - Vector3(0, foot.y, 0) + (Vector3(0.3, 0, 0) if near else ahead * 9.0))
		CA._apply_token(&"pinned", &"attack_heavy", player, c)
		var pinned: bool = c.pin_victim == player
		if near:
			_expect(pinned, "%s: a heavy landing at its foot pins her" % id)
		else:
			_expect(not pinned and not player.statuses.has(&"pinned") and player.statuses.has(&"knockdown"), "%s: a heavy that lands away from its foot knocks her down, no pin" % id)
		for f in 300:
			await _frame()
			if c.pin_victim == null and f > 30:
				break
		c.queue_free()
		await physics_frame
		player.statuses.clear_all()
