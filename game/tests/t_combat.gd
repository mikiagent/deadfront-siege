extends SceneTree
## W1-COMBAT rules: statuses only on landed hits, walls block melee, wear per landed hit,
## seeded accuracy, pets are never hunted, nets keep the 30 % rule, kick mass scaling.
## Usage: godot --headless --path game --script res://tests/t_combat.gd

var failures: Array[String] = []
var _started := false
var host: Node3D
## `godot --script` compiles this file before the autoloads exist, so every class that touches
## Data/World/Game is loaded at run time and used untyped (the run_all.gd pattern).
var player
var data: Node
var CA: GDScript  # CreatureAttack
var MQ: GDScript  # MeleeQuery
var HUNT: GDScript
var TACT: GDScript  # CombatTactics
var ITEM: GDScript  # ItemStack

func _process(_delta: float) -> bool:
	if _started:
		return false
	# Player/Creature reference autoloads (Data, World, Game): wait until they exist.
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	CA = load("res://scripts/combat/creature_attack.gd")
	MQ = load("res://scripts/combat/melee_query.gd")
	HUNT = load("res://scripts/combat/hunt.gd")
	TACT = load("res://scripts/combat/combat_tactics.gd")
	ITEM = load("res://scripts/items/item_stack.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("[t_combat] FAIL %s" % msg)
	else:
		print("[t_combat] ok %s" % msg)

func _run() -> void:
	host = Node3D.new()
	host.name = "TCombat"
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
	_test_tuning()
	_test_no_status_without_hit()
	await _test_walls_block()
	await _test_corner_slot()
	await _test_swing_pauses()
	await _test_swing_after_stop()
	await _test_telegraph_clip()
	_test_stone_evasion()
	_test_wear()
	_test_seeded_accuracy()
	_test_evasion()
	_test_pets_and_nets()
	_test_kick_mass()
	CombatTuning.reset_overrides()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_combat] PASS")
		quit(0)
	else:
		print("[t_combat] FAIL count=%d" % failures.size())
		quit(1)

func _creature(species: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.spawn(data.creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # rules under test, not AI
	return c

func _reset_player() -> void:
	for inst in player.statuses.instances().duplicate():
		player.statuses.clear_id(inst.id)
	player.vitals.dead = false
	player.dead = false
	# refresh_equipment_vitals clamps health to max every frame, so 1000 needs a 1000 max; with
	# the default 100 a raptor heavy crit (135) killed him and the control row flaked.
	player.vitals.max_health = 1000.0
	player.vitals.health = 1000.0
	player.sim._stagger_left = 0.0  # TACTICS: a hurt stun is a hard stun (no swings); start each check unstunned

func _test_tuning() -> void:
	_expect(CombatTuning.section("player_melee").has("hit_frac"), "combat_tuning.json loads with player_melee.hit_frac")
	_expect(is_equal_approx(CombatTuning.num("creature_melee", "player_base_defense", -1.0), 20.0), "today's player base defense 20 lives in data")

## pc-combat-02: a dodged or missed velociraptor pounce applies no knockdown and no bleed.
func _test_no_status_without_hit() -> void:
	var raptor = _creature(&"velociraptor", Vector3(0, 0, -1.6))
	for mode in ["dodge", "miss"]:
		_reset_player()
		CombatTuning.reset_overrides()
		if mode == "dodge":
			CombatTuning.force_dodge = 1.0
		else:
			CombatTuning.force_accuracy = 0.0
		var landed = CA.apply_for(raptor, &"attack_heavy", player)
		_expect(not landed and player.statuses.instances().is_empty() and is_equal_approx(player.vitals.health, 1000.0),
			"forced %s: heavy applies 0 statuses, 0 damage (statuses=%d)" % [mode, player.statuses.instances().size()])
	_reset_player()
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
	var landed_ctrl = CA.apply_for(raptor, &"attack_heavy", player)
	_expect(landed_ctrl and player.statuses.has(&"knockdown") and player.statuses.has(&"bleed"), "control: a landed heavy applies knockdown + bleed")
	_reset_player()
	raptor.free()

## phys-hit-01: one fence between the bodies blocks the bite and the swing.
func _test_walls_block() -> void:
	_reset_player()
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
	player.global_position = Vector3(0, 0.9, -0.8)
	var raptor = _creature(&"velociraptor", Vector3(0, 0, 0.9))
	var fence = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"fence")
	host.add_child(fence)
	fence.global_position = Vector3(0, 0, 0)
	await physics_frame
	await physics_frame
	_expect(MQ.blocker(raptor, player) == fence, "knee ray raptor->survivor meets the fence")
	player.vitals.health = 1000.0  # vitals clamp to max each frame; re-arm right before the bite
	_expect(not CA.apply_for(raptor, &"attack_primary", player) and is_equal_approx(player.vitals.health, 1000.0), "bite through the fence lands nothing")
	_expect(not MQ.clear(player, raptor), "survivor swing through the fence refused")
	player.hunt.start(raptor)
	player.hunt._notice_s.clear()
	player.hunt.last_notice = ""
	player.hunt._auto_attack()
	_expect(player.hunt.last_notice.contains("in the way"), "melee blocked by the fence says so ('%s')" % player.hunt.last_notice)
	player.hunt.stop()
	fence.free()
	await physics_frame
	_expect(MQ.clear(raptor, player), "same bodies without the fence: clear")
	player.vitals.health = 1000.0
	_expect(CA.apply_for(raptor, &"attack_primary", player) and player.vitals.health < 1000.0, "control: bite lands without the fence")
	_reset_player()
	raptor.global_position = Vector3(0, 6.0, 0.9)
	_expect(not MQ.clear(player, raptor), "a body 5 m above is out of reach")
	player.global_position = Vector3(0, 0.9, 0)
	raptor.free()

## phys-hit-01 regression: the 0.4 m slot where a fence row (z=16.5) and column (x=10.5) fail
## to meet let a zero-width ray through diagonally (combat_rules_lab, 3 of 5 runs). Same geometry
## and body positions, shifted to the origin.
func _test_corner_slot() -> void:
	_reset_player()
	var walls: Array[StaticBody3D] = []
	for spec in [[Vector3(-2.5, 0.6, 0.0), Vector3(6.0, 1.2, 0.2)], [Vector3(0.0, 0.6, 2.0), Vector3(0.2, 1.2, 3.0)]]:
		var w := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = spec[1]
		cs.shape = bx
		w.add_child(cs)
		host.add_child(w)
		w.global_position = spec[0]
		walls.append(w)
	var raptor = _creature(&"velociraptor", Vector3(1.23, 0, 0.07))
	player.global_position = Vector3(-0.55, 0.9, 0.55)
	await physics_frame
	await physics_frame
	var hit = MQ.blocker(raptor, player)
	_expect(hit != null and hit in walls, "corner slot: raptor->survivor blocked by %s" % hit)
	_expect(MQ.blocker(player, raptor) != null, "corner slot: survivor->raptor blocked")
	for w in walls:
		w.free()
	await physics_frame
	_expect(MQ.clear(raptor, player), "corner slot control: clear with the walls gone")
	player.global_position = Vector3(0, 0.9, 0)
	raptor.free()

## A swing started just before a pause must not land while the game is paused.
func _test_swing_pauses() -> void:
	_reset_player()
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
	player.global_position = Vector3(0, 0.9, 0)
	var raptor = _creature(&"velociraptor", Vector3(0, 0, -1.6))
	await physics_frame
	player.hunt.start(raptor)
	player.hunt.auto = false
	var hp0: float = raptor.health.hp
	player.hunt.begin_swing()
	paused = true
	await create_timer(1.0, true).timeout
	var hp_paused: float = raptor.health.hp
	paused = false
	await create_timer(1.0).timeout
	_expect(is_equal_approx(hp_paused, hp0) and raptor.health.hp < hp0, "swing waits out a pause: hp %.2f paused, %.2f after (bare hands)" % [hp_paused, raptor.health.hp])
	player.hunt.auto = true
	player.hunt.stop()
	CombatTuning.reset_overrides()
	raptor.free()

## A swing pending when the hunt stops (or retargets) is lost: it never lands on the old target.
func _test_swing_after_stop() -> void:
	_reset_player()
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
	player.global_position = Vector3(0, 0.9, 0)
	var raptor = _creature(&"velociraptor", Vector3(0, 0, -1.6))
	await physics_frame
	player.hunt.start(raptor)
	player.hunt.auto = false
	var hp0: float = raptor.health.hp
	player.hunt.begin_swing()
	player.hunt.stop()
	await create_timer(1.0).timeout
	_expect(is_equal_approx(raptor.health.hp, hp0), "swing pending at Hunt.stop() is lost: hp %.2f -> %.2f" % [hp0, raptor.health.hp])
	player.hunt.auto = true
	CombatTuning.reset_overrides()
	raptor.free()

## pc-combat-02: only the telegraphed clip's hit shortens its ring; a stray hit from another clip does not.
func _test_telegraph_clip() -> void:
	var TG: GDScript = load("res://scripts/combat/telegraph.gd")
	var raptor = _creature(&"velociraptor", Vector3(4, 0, -4))
	await physics_frame
	TG.show_for(raptor, &"attack_heavy")
	var ring = TG._active[TG._active.size() - 1]
	var life0: float = ring._life
	raptor.anim.attack_hit.emit(&"attack_primary")
	var after_stray: float = ring._life
	raptor.anim.attack_hit.emit(&"attack_heavy")
	_expect(after_stray > TG.LINGER and ring._life <= TG.LINGER, "telegraph ring %.2f s, %.2f s after a stray attack_primary hit, %.2f s after its own attack_heavy hit" % [life0, after_stray, ring._life])
	ring.free()
	raptor.free()

## pc-ranged-01: a stone impact rolls evasion like a swing; a dodged stone deals nothing and costs
## no durability, a landed one costs exactly 1.
func _test_stone_evasion() -> void:
	var raptor = _creature(&"velociraptor", Vector3(0, 0, -6))
	player.inventory.add(ITEM.make(&"slingshot", 1))
	player.inventory.equip(&"weapon", &"slingshot")
	var sling = player.inventory.equipped_weapon()
	var shot = (load("res://scripts/combat/stone_projectile.gd") as GDScript).new()
	shot.source = player
	shot.weapon = sling
	shot.damage = 20.0
	var hp0: float = raptor.health.hp
	var dur0: int = sling.durability
	CombatTuning.force_accuracy = 1.0
	CombatTuning.force_dodge = 1.0
	shot.impact(raptor)
	_expect(is_equal_approx(raptor.health.hp, hp0) and sling.durability == dur0, "dodged stone: hp %.2f -> %.2f, durability %d -> %d" % [hp0, raptor.health.hp, dur0, sling.durability])
	CombatTuning.force_dodge = 0.0
	shot.impact(raptor)
	_expect(raptor.health.hp < hp0 and sling.durability == dur0 - 1, "landed stone: hp %.2f -> %.2f, durability %d -> %d" % [hp0, raptor.health.hp, dur0, sling.durability])
	CombatTuning.reset_overrides()
	shot.free()
	raptor.free()

## pc-data-02 / durability-01: 10 landed club hits cost 10 durability; a broken club is bare hands.
func _test_wear() -> void:
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
	var target = _creature(&"velociraptor", Vector3(0, 0, -1.6))
	player.inventory.add(ITEM.make(&"club", 1))
	player.inventory.equip(&"weapon", &"club")
	var club = player.inventory.equipped_weapon()
	var before = club.durability
	var landed := 0
	for i in 10:
		target.health.hp = target.health.max_hp
		if player.hunt.land_hit(target, club):
			landed += 1
	_expect(landed == 10 and before - club.durability == 10, "10 landed club hits: durability %d -> %d" % [before, club.durability])
	CombatTuning.force_accuracy = 0.0
	var dur = club.durability
	player.hunt.land_hit(target, club)
	_expect(club.durability == dur, "a missed swing does not wear the club")
	club.durability = 0
	_expect(player.hunt._weapon() == null, "a broken club fights as bare hands")
	# Stones still in flight after the break must not wear it again (and re-print "X broke.").
	player.hunt.say("")  # reset the notice sink so the check below sees only a fresh message
	player.hunt.wear_weapon(club)
	_expect(player.hunt.last_notice == "", "wear_weapon on an already-broken weapon does nothing (notice '%s')" % player.hunt.last_notice)
	club.durability = club.max_durability
	target.free()
	_test_notice_throttle()

## Two different messages within 3 s must both show; the same message twice must not.
func _test_notice_throttle() -> void:
	player.hunt._notice_s.clear()
	player.hunt.last_notice = ""
	player.hunt.say_throttled("Something is in the way.")
	var first: String = player.hunt.last_notice
	player.hunt.say_throttled("No clear shot: something is in the way.")
	var second: String = player.hunt.last_notice
	player.hunt.say_throttled("Something is in the way.")
	var third: String = player.hunt.last_notice
	print("[t_combat] throttle: first='%s' second='%s' repeat='%s'" % [first, second, third])
	_expect(first.contains("Something") and second.contains("No clear shot"), "a second, different message is not swallowed by the first")
	_expect(third == second, "the same message is still throttled within 3 s")
	player.hunt._notice_s.clear()
	player.hunt.last_notice = ""

## pc-data-01: 1,000 seeded swings by a groggy attacker hit at base x accuracy_mult (+-3 %).
func _test_seeded_accuracy() -> void:
	CombatTuning.reset_overrides()
	_reset_player()
	var raptor = _creature(&"velociraptor", Vector3(0, 0, -1.6))
	var base = CA.hit_chance(raptor, player)
	raptor.statuses.apply(&"groggy")
	var mult: float = data.status(&"groggy").accuracy_mult
	CombatTuning.rng.seed = 20261018
	var hits := 0
	for i in 1000:
		if CombatTuning.roll(CA.hit_chance(raptor, player)):
			hits += 1
	var want: float = base * mult
	_expect(absf(hits / 1000.0 - want) <= 0.03, "groggy raptor: %d/1000 hits, want %.3f x %.2f = %.3f" % [hits, base, mult, want])
	# The survivor: groggy swings against a target with no dodge.
	player.statuses.apply(&"groggy")
	CombatTuning.force_dodge = 0.0
	hits = 0
	for i in 1000:
		if CombatTuning.roll(player.hunt.hit_chance(raptor)):
			hits += 1
	_expect(absf(hits / 1000.0 - mult) <= 0.03, "groggy survivor: %d/1000 hits, want %.2f" % [hits, mult])
	CombatTuning.reset_overrides()
	_reset_player()
	raptor.free()

## evasion_add (dizziness -40) lowers the host's dodge.
func _test_evasion() -> void:
	var raptor = _creature(&"velociraptor", Vector3(0, 0, -1.6))
	var plain = player.hunt.hit_chance(raptor)
	raptor.statuses.apply(&"dizziness")
	_expect(raptor.statuses.evasion_add() < 0.0 and player.hunt.hit_chance(raptor) > plain, "dizziness evasion_add raises the chance to hit it (%.3f -> %.3f)" % [plain, player.hunt.hit_chance(raptor)])
	raptor.free()

## pc-bug-01 / tame-11: never hunt your own pet; a net needs < 30 % health.
func _test_pets_and_nets() -> void:
	var pet = _creature(&"velociraptor", Vector3(0, 0, -1.6))
	pet.is_pet = true
	player.hunt.stop()
	player.hunt.start(pet)
	_expect(player.hunt.target == null, "Hunt.start on a pet starts no hunt")
	pet.free()
	var wild = _creature(&"velociraptor", Vector3(0, 0, -1.6))
	player.hunt.start(wild)
	wild.is_capturable = true
	wild.health.hp = wild.health.max_hp * 0.5
	player.hunt.last_notice = ""
	player.hunt.use_net()
	_expect(player.hunt.last_notice.contains("30%"), "net at 50 %% health refused (%s)" % player.hunt.last_notice)
	_expect(player.hunt.tactic_label(4) != "Net", "Net hex hidden above 30 % health")
	player.hunt.stop()
	wild.free()

## phys-kick-01: shove falls off with mass; giants do not budge.
func _test_kick_mass() -> void:
	var probe = (load("res://scripts/creatures/creature.gd") as GDScript).new()
	for row in [[&"compsognathus", 1.5, INF], [&"velociraptor", 0.3, INF], [&"triceratops", -1.0, 0.0], [&"tyrannosaurus", -1.0, 0.0]]:
		probe.def = data.creature(row[0])
		var push = TACT.kick_push(probe)
		_expect(push >= float(row[1]) and push <= float(row[2]), "kick push %s = %.2f m" % [row[0], push])
	probe.free()
