extends SceneTree
## COELOMOVES (owner 2026-10-31): coelophysis gets the deinonychus move set (TacticalBrain, the same
## sequences, ambush, pounce, combo, leaps) and gallimimus the same template without the pounce (its own clips, the
## chase-to-fight behaviour and its fight are SP-GALLIMIMUS's: tests/t_sp_gallimimus.gd).
## Megaloceros gets the territorial brain data only. Checks: the move lists, every fight clip loads, each
## move fires and lands on a stationary survivor, the body stays on the ground outside its leaps.
## Usage: godot --headless --path game --script res://tests/t_coelomoves.gd  -> "[t_coelomoves] PASS"

const TIME_SCALE := 2.0
const DEINO_CLIPS: Array[StringName] = [&"alert", &"attack_primary", &"attack_heavy", &"bite_combo", &"pounce", &"charge",
	&"hop_back", &"leap_back", &"dodge_left", &"dodge_right", &"strafe_left", &"strafe_right"]

var failures: Array[String] = []
var _started := false
var host: Node3D
var data: Node
var player

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	get_root().get_node("Game").debug_overlay = false
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_coelomoves] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	seed(20261031)
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261031
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	Engine.max_physics_steps_per_frame = 1000
	Engine.physics_jitter_fix = 0.0
	host = Node3D.new()
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	# A navmesh like the labs' (LabKit): without one a creature only steers straight at goals within 12 m,
	# and the utahraptor's x1.4 ring starts its charge farther out than that.
	var nav := NavigationRegion3D.new()
	var nmesh := NavigationMesh.new()
	nmesh.agent_radius = 0.5
	nmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nmesh.geometry_source_group_name = &"coelo_nav"
	host.add_to_group(&"coelo_nav")
	nav.navigation_mesh = nmesh
	host.add_child(nav)
	nav.bake_navigation_mesh(false)
	await physics_frame
	await physics_frame
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.look_at_from_position(Vector3(0, 12, 12), Vector3.ZERO)
	cam.current = true
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED  # the stationary target
	_test_data()
	await _test_raptor(&"coelophysis", 9.0)
	await _test_raptor(&"utahraptor", 16.0)
	await _test_raptor(&"velociraptor", 7.0)
	load("res://scripts/combat/combat_tuning.gd").reset_overrides()
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("[t_coelomoves] PASS")
		quit(0)
	else:
		print("[t_coelomoves] FAIL %d" % failures.size())
		quit(1)

static func _steps(t: Dictionary) -> Array:
	var out: Array = []
	for row in t.get("sequences", []):
		out.append(row["steps"])
	return out

func _test_data() -> void:
	var TB = load("res://scripts/creatures/brains/tactical_brain.gd")
	var deino: Dictionary = TB.tactics_for(&"pack_flanker")
	var coelo: Dictionary = TB.tactics_for_def(data.creature(&"coelophysis"))
	for id in [&"coelophysis", &"gallimimus", &"utahraptor", &"velociraptor"]:
		_expect(str(data.creature(id).tactics.get("base", "")) == "pack_flanker", "%s runs on the one deinonychus profile (base pack_flanker)" % id)
	var utah: Dictionary = TB.tactics_for_def(data.creature(&"utahraptor"))
	var velo: Dictionary = TB.tactics_for_def(data.creature(&"velociraptor"))
	_expect(_steps(utah) == _steps(deino) and _steps(velo) == _steps(deino), "utahraptor and velociraptor run the deinonychus sequences")
	_expect(is_equal_approx(float(utah["ring_m"]), float(deino["ring_m"]) * 1.4) and is_equal_approx(float(velo["hop_m"]), float(deino["hop_m"]) * 0.75),
		"the profile scales distances per species (utahraptor ring %.1f m, velociraptor hop %.1f m)" % [utah["ring_m"], velo["hop_m"]])
	_expect(not velo.get("ambush", true), "velociraptor has no tree ambush (its investigate hold opens the fight)")
	_expect(not coelo.is_empty(), "coelophysis has a tactics profile")
	_expect(_steps(coelo) == _steps(deino), "coelophysis runs the deinonychus sequences %s" % [_steps(coelo)])
	for k in ["point_blank", "ambush", "ring_m", "hop_m", "leap_back_m", "strafe_m", "pounce_min_m", "pounce_max_m", "leap_in_max_m"]:
		_expect(coelo.get(k) == deino.get(k), "coelophysis %s = deinonychus (%s)" % [k, coelo.get(k)])
	_expect(float(coelo["pounce_mult"]) < float(deino["pounce_mult"]), "coelophysis pounce hits lighter (%s < %s)" % [coelo["pounce_mult"], deino["pounce_mult"]])
	var galli: Dictionary = TB.tactics_for_def(data.creature(&"gallimimus"))
	var finishers := {}
	for st in _steps(galli):
		finishers[st[-1]] = true
	_expect(not galli.is_empty() and not finishers.has("pounce") and finishers.has("charge") and finishers.has("combo"),
		"gallimimus: deinonychus template without the pounce (finishers %s)" % [finishers.keys()])
	_expect(not galli.has("territorial") and galli.has("cornered") and not galli.get("ambush", false), "gallimimus turns on a chaser (cornered), not after one flight; no ambush")
	var mega: Dictionary = TB.tactics_for_def(data.creature(&"megaloceros"))
	_expect(mega.has("territorial") and float(mega["territorial"].get("weak_frac", 0)) == 0.3, "megaloceros gets the territorial brain (weak_frac 0.3)")

func _spawn(id: StringName, at: Vector3, nature: StringName):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	seed(20261031)
	var iv_rng := RandomNumberGenerator.new()
	iv_rng.seed = 20261031
	c.genetics = load("res://scripts/creatures/creature_genetics.gd").roll(iv_rng)
	c.spawn(data.creature(id), &"", 0, null, 0, nature)
	c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	if "rng" in c.brain:
		c.brain.rng.seed = 20261031
		c.brain._circle_sign = 1.0
		c.brain._flank_sign = 1.0
	return c

func _keep_player_alive() -> void:
	player.vitals.max_health = 1000000.0
	player.vitals.health = player.vitals.effective_max_health()
	player.vitals.dead = false
	player.dead = false

const ATTACK_KINDS: Array[StringName] = [&"bite", &"charge_bite", &"combo", &"pounce", &"heavy", &"kick"]
const AIR_STATES: Array[StringName] = [&"hop", &"pounce", &"dodge", &"lunge"]

## Fights `c` for `seconds` against the stationary survivor; returns {fired: {kind: n}, landed: {kind: n},
## lift: highest body y outside the leaps}. A hit is credited to the attack move that last started.
func _fight(c, seconds: float, press_m: float = 0.0, keep_hp: bool = true) -> Dictionary:
	var b = c.brain
	var fired := {}
	var landed := {}
	var last := [&""]
	var on_tactic := func(k: StringName) -> void:
		fired[k] = int(fired.get(k, 0)) + 1
		if k in ATTACK_KINDS:
			last[0] = k
	var on_hurt := func() -> void:
		if last[0] != &"":
			landed[last[0]] = int(landed.get(last[0], 0)) + 1
	b.tactic.connect(on_tactic)
	player.vitals.damaged.connect(on_hurt)
	Engine.time_scale = TIME_SCALE
	var step := 1.0 / float(Engine.physics_ticks_per_second) * TIME_SCALE
	var t := 0.0
	var lift := 0.0
	var hp0: float = c.health.max_hp
	var press_t := 0.0
	var states := {}
	while t < seconds:
		await physics_frame
		t += step
		states[b.state] = true
		if OS.has_environment("CM_CHARGE") and b.state in [&"charge", &"approach", &"circle"]:
			print("[charge] %s %s %.2f d=%.2f reach=%.2f left=%.2f busy=%s clip=%s stag=%.2f v=%.2f" % [c.def.id, b.state, t, b._flat_dist(b.attack_target), b.reach_to(b.attack_target), b._left, c.anim._busy, c.anim.current_clip, c.stagger_left, Vector2(c.velocity.x, c.velocity.z).length()])
		_keep_player_alive()
		if keep_hp:
			c.health.hp = hp0
		if not b.state in AIR_STATES and not c.anim.current_clip in [&"pounce", &"hop_back", &"leap_back", &"dodge_left", &"dodge_right", &"attack_heavy"]:
			lift = maxf(lift, c.global_position.y)
		# Pressing (a survivor who walks in): every few seconds she steps up to press_m in front of it.
		press_t += step
		if press_m > 0.0 and press_t > 4.0 and b.state in [&"circle", &"hold", &"dodge"]:
			press_t = 0.0
			var fwd: Vector3 = player.global_position - c.global_position
			fwd.y = 0.0
			player.global_position = c.global_position + fwd.normalized() * press_m + Vector3(0, player.global_position.y - c.global_position.y, 0)
	Engine.time_scale = 1.0
	b.tactic.disconnect(on_tactic)
	player.vitals.damaged.disconnect(on_hurt)
	return {"fired": fired, "landed": landed, "lift": lift, "states": states}

func _clips(c, id: String, want: Array[StringName]) -> void:
	var missing: Array[StringName] = []
	for clip in want:
		if not c.anim.has_state(clip):
			missing.append(clip)
	_expect(missing.is_empty(), "%s loads every fight clip (missing %s)" % [id, missing])

func _test_raptor(id: StringName, at: float) -> void:
	player.global_position = Vector3(0, 0.9, 0)
	var c = _spawn(id, Vector3(0, 0.1, at), &"loyal")
	_expect(c.brain.get_script().get_global_name() == &"TacticalBrain", "%s gets the TacticalBrain" % id)
	_clips(c, str(id), DEINO_CLIPS)
	c.brain.on_aggro(player)
	var r := await _fight(c, 70.0)
	print("[t_coelomoves] %s fired %s landed %s lift %.2f" % [id, r.fired, r.landed, r.lift])
	# As for deinonychus the plain bite is a last resort: attack_primary lands as the charge's bite.
	for k in [&"combo", &"pounce", &"charge"]:
		_expect(int(r.fired.get(k, 0)) > 0, "%s %s fires" % [id, k])
	for k in [&"combo", &"pounce", &"charge_bite"]:
		_expect(int(r.landed.get(k, 0)) > 0, "%s %s lands" % [id, k])
	_expect(int(r.fired.get(&"hop", 0)) + int(r.fired.get(&"dodge", 0)) > 0, "%s leaps back or power-strafes" % id)
	_expect(r.lift < 0.25, "%s stays on the ground outside its leaps (%.2f m)" % [id, r.lift])
	c.queue_free()
	await physics_frame
