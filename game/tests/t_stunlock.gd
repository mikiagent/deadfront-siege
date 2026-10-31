extends SceneTree
## STUNLOCK (owner 2026-10-31, fight lab: "ankylosaurus is getting stunlocked and not fighting back"; earlier "I should
## not be able to punch it over and over up close without consequence"). The survivor in GOD mode fights each big
## species the way the fight lab's auto-attack does: Hunt with Auto and Auto-ability on (a punch a second, plus Tackle
## and Kick whenever they are off cooldown; energy is free in GOD). Spawned as the lab's NEXT does: one Aggressive
## animal 8 m ahead, already on her. Per species:
## - her hits land (and over all the fights the auto-cast fires Tackle and Kick);
## - a heavy or armoured body (mass_proxy >= kick giant_mass, or ARMOURED) spends no time staggered or in hit_react
##   from her; any other body at most MAX_HER_STAGGER of the fight;
## - it fights back: at least MIN_STARTS attack starts, no gap over MAX_GAP_S of her up-time between them (her time on
##   the floor does not count, it waits for her to get up), and at least one hit or knock lands on her.
## Its health is held at full so the <= 30 % capture knockdown (FieldTame, spec 09) stays out of this check.
## Run: Godot --headless --path game --script res://tests/t_stunlock.gd  -> "[t_stunlock] PASS", exit 0.
## Debug (after "--"): --only=ankylosaurus,triceratops, --trace (a line every 0.5 s).

const NAMED: Array[StringName] = [&"ankylosaurus", &"stegosaurus", &"triceratops", &"styracosaurus", &"pachycephalosaurus", &"carnotaurus", &"tyrannosaurus"]
## The owner's armoured species, poised whatever its mass.
const ARMOURED: Array[StringName] = [&"ankylosaurus"]
## Its own attacks: every melee clip (CreatureAnim.ATTACKS) plus the charge and leap starts (and the brain's charge state).
const OWN_ATTACKS: Array[StringName] = [&"attack_primary", &"attack_heavy", &"tail_swipe", &"bite_combo", &"kick", &"pin_stab", &"stomp", &"shove_left", &"shove_right", &"tackle", &"grab_bite", &"charge", &"charge_crouch", &"charge_windup", &"bull_windup", &"pounce", &"leap", &"flank_rake", &"impale", &"toss"]
## The fight runs FIGHT_S from her first landed hit, longer (up to MAX_FIGHT_S) while it has not yet hit her back or
## started MIN_STARTS attacks: a hop-back fighter (majungasaurus) can miss for a while without being locked.
const FIGHT_S := 14.0
const MAX_FIGHT_S := 30.0
const DT := 1.0 / 60.0
# ASSUMPTION (STUNLOCK): "fights back" = 2+ attack starts, never 16 s of her up-time without one. A jouster's beat
# (MEGAJOUST: pass, overshoot, a wheel of up to wheel_max_s 12 s, the tell) is the longest designed gap.
const MIN_STARTS := 2
const MAX_GAP_S := 16.0
const POISED_MAX_STAGGER := 0.01
const MAX_HER_STAGGER := 0.35

var failures: Array[String] = []
var _started := false
var _watch := 0.0
var data: Node
var host: Node3D
var player: Node3D
var _only: PackedStringArray = []
var _trace := false
var _casts := 0  ## frames the auto-cast fired Tackle or Kick, all fights

func _process(delta: float) -> bool:
	if _started:
		_watch += delta
		if _watch > 900.0:
			print("[t_stunlock] FAIL watchdog")
			quit(1)
		return false
	if root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_stunlock] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _giant_mass() -> float:
	return float(load("res://scripts/combat/combat_tuning.gd").section("kick").get("giant_mass", 40.0))

func _mass(id: StringName) -> float:
	var def = data.creature(id)
	return def.real_length_m * def.height_meters

func species() -> Array[StringName]:
	var out: Array[StringName] = NAMED.duplicate()
	for id: StringName in data.creatures.keys():
		if data.creature(id) == null or id in out or not load("res://scripts/creatures/creature_def.gd").has_model(id):
			continue  # no model: the lab never spawns it
		if _mass(id) >= _giant_mass():
			out.append(id)
	return out

func _run() -> void:
	data = root.get_node("Data")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7).split(",")
		_trace = _trace or a == "--trace"
	root.get_node("Game").debug_overlay = false
	root.get_node("Game").god_mode = true
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261031
	seed(20261031)
	host = Node3D.new()
	host.name = "TStunlockHost"
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 120.0)
	player = kit["player"]
	for i in 10:
		await physics_frame
	var ids := species()
	print("[t_stunlock] species %s" % str(ids))
	_expect(ids.size() > NAMED.size(), "the list has the owner's seven and the other heavies")
	for id in ids:
		if _only.is_empty() or str(id) in _only:
			await _fight(id)
	_expect(_casts > 0, "the auto-cast fires Tackle and Kick in these fights (%d casts)" % _casts)
	root.get_node("Game").god_mode = false
	if failures.is_empty():
		print("[t_stunlock] PASS")
		quit(0)
	else:
		print("[t_stunlock] FAIL %d" % failures.size())
		quit(1)

func _fight(id: StringName) -> void:
	var poised := _mass(id) >= _giant_mass() or id in ARMOURED
	player.global_position = Vector3(0, player.global_position.y, 0)
	player.velocity = Vector3.ZERO
	player.sim.knock.cancel()
	player.statuses.clear_all()
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = Vector3(0, 0, -8)  # before add_child, as Spawner does: added at the origin, it carries her off as a platform
	host.add_child(c)
	c.spawn(data.creature(id), &"", 0, null, 0, &"aggressive")  # the lab's NEXT: one Aggressive animal, 8 m ahead
	await physics_frame
	c.brain.on_aggro(player)
	player.hunt.auto = true
	player.hunt.auto_ability = true
	player.hunt.start(c)
	var on_her := [0]
	var on_hit := func() -> void: on_her[0] += 1
	player.vitals.damaged.connect(on_hit)
	var dealt := [0, -1]  # her landed hits, the frame of her last one
	var frame := [0]
	var on_dmg := func(_a: float, src: Node) -> void:
		if src == player:
			dealt[0] += 1
			dealt[1] = frame[0]
	c.health.damaged.connect(on_dmg)
	var casts := 0
	var t := 0.0
	var engaged := -1.0  # her first landed hit: the clock starts there
	var starts := 0
	var since := 0.0  # her up-time since its last attack start
	var gap := 0.0
	var her_stag := 0.0  # time it spent staggered by her (or in hit_react)
	var by_her := false
	var prev_stag := 0.0
	var was_clip := &""
	var was_knocked := false
	while t < 50.0 and (engaged < 0.0 or t - engaged < FIGHT_S \
			or ((on_her[0] < 1 or starts < MIN_STARTS) and t - engaged < MAX_FIGHT_S)):
		await physics_frame
		frame[0] += 1
		t += DT
		c.health.hp = c.health.max_hp  # held at full: no capture knockdown, no death
		if player.hunt.target != c:
			player.hunt.start(c)
		if player.hunt.last_auto_cast != &"":
			casts += 1
		if engaged < 0.0 and dealt[0] > 0:
			engaged = t
		# A stagger that started on the frame of her hit is hers; one the brain sets itself (winded after a charge) is not.
		if c.stagger_left > prev_stag + 0.01:
			by_her = frame[0] - int(dealt[1]) <= 1
		prev_stag = c.stagger_left
		var knocked: bool = player.sim.knock.active()
		if knocked and not was_knocked:
			on_her[0] += 1  # a throw or knockdown lands even without damage
		was_knocked = knocked
		# A charge runs on its run clip; a new attack clip straight after another is a new start (combo, then rake).
		var clip: StringName = &"charge" if c.brain.state == &"charge" else c.anim.current_clip
		var attacking: bool = clip in OWN_ATTACKS
		var up: bool = not (knocked or player.statuses.has_flag(&"cannot_act") or player.statuses.has_flag(&"no_attack"))
		if engaged >= 0.0:
			if up:
				since += DT
			if attacking and clip != was_clip:
				starts += 1
				gap = maxf(gap, since)
				since = 0.0
			if (c.stagger_left > 0.0 and by_her) or c.anim.current_clip == &"hit_react":
				her_stag += DT
		was_clip = clip
		if _trace and frame[0] % 30 == 0:
			print("[t_stunlock]   t=%.1f d=%.1f clip=%s state=%s stag=%.2f(%s) | her clip=%s up=%s" % [t, player.global_position.distance_to(c.global_position), c.anim.current_clip, c.brain.state, c.stagger_left, "her" if by_her else "own", player.anim.current_clip, up])
	var span := t - engaged if engaged >= 0.0 else 0.0
	gap = maxf(gap, since)
	player.vitals.damaged.disconnect(on_hit)
	var frac := her_stag / maxf(span, 0.001)
	print("[t_stunlock] %s (%s): %.0f s, her hits %d, casts %d; its attack starts %d, longest gap %.1f s, hits on her %d, staggered by her %.0f %%" \
			% [id, "poised" if poised else "staggerable", span, dealt[0], casts, starts, gap, on_her[0], 100.0 * frac])
	_expect(dealt[0] >= 1, "%s: her hits land (%d)" % [id, dealt[0]])
	_casts += casts
	var cap := POISED_MAX_STAGGER if poised else MAX_HER_STAGGER
	_expect(frac <= cap, "%s: staggered by her at most %.0f %% of the fight (%.0f %%)" % [id, 100.0 * cap, 100.0 * frac])
	_expect(starts >= MIN_STARTS, "%s: it starts %d+ attacks (%d)" % [id, MIN_STARTS, starts])
	_expect(gap <= MAX_GAP_S, "%s: never %.0f s of her up-time without an attack start (%.1f s)" % [id, MAX_GAP_S, gap])
	_expect(on_her[0] >= 1, "%s: it lands hits on her (%d)" % [id, on_her[0]])
	player.hunt.stop()
	c.queue_free()
	for i in 5:
		await physics_frame
