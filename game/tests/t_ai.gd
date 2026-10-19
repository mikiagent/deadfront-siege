extends SceneTree
## Wild AI unit checks (W1-AI). Run: godot --headless --path game --script res://tests/t_ai.gd
## Prints "[t_ai] PASS" or "[t_ai] FAIL ..." lines and quits 0/1.
##
## `--script` compiles this file before the autoloads exist, and every creature script names
## Data, so nothing here is typed as a game class: scripts load on the first frame that has
## the autoloads, and Data / Game are fetched from the root.

const CREATURE_SCENE := "res://scenes/creatures/creature.tscn"

var failures: Array[String] = []
var data: Node
var game: Node
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	data = get_root().get_node("Data")
	game = get_root().get_node("Game")
	game.debug_overlay = false
	_test_state_changed_once()
	_test_profiles()
	_test_level_scaling()
	_test_solo_spawn_and_tame_pack()
	_test_leash_every_species()
	_test_hit_beyond_leash_flees()
	_test_hit_while_asleep_stays_awake()
	_test_temp_home_expires()
	_test_pack_slots_clear_bodies()
	if failures.is_empty():
		print("[t_ai] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_ai] FAIL %s" % f)
		quit(1)
	return true

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)

func _now_s() -> float:
	return float(Time.get_ticks_msec()) * 0.001

## Pack lists are cached per physics frame and this whole run is one frame; drop the cache
## whenever the test set of creatures changes.
func _fresh_packs() -> void:
	load("res://scripts/creatures/brains/pack_index.gd").invalidate()

func _creature(id: StringName, pack: int = 0, at: Vector3 = Vector3.ZERO) -> Node:
	var c: Node = load(CREATURE_SCENE).instantiate()
	get_root().add_child(c)
	c.global_position = at
	c.spawn(data.creature(id), &"", pack)
	_fresh_packs()
	return c

func _species() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in data.creatures:
		out.append(StringName(id))
	out.sort()
	return out

func _test_state_changed_once() -> void:
	var c := _creature(&"velociraptor")
	var seen: Array = []
	c.brain.state_changed.connect(func (p: StringName, n: StringName) -> void: seen.append([p, n]))
	var from: StringName = c.brain.state
	c.brain._set_state(&"alert")
	c.brain._set_state(&"alert")  # no transition, no signal
	c.brain._set_state(&"approach")
	c.brain._set_state(&"roam")
	var want := [[from, &"alert"], [&"alert", &"approach"], [&"approach", &"roam"]]
	_check(seen == want, "state_changed once per transition: got %s want %s" % [seen, want])
	c.free()

func _test_profiles() -> void:
	var zeb := _creature(&"zebraceratops")
	var skittish: Dictionary = (data.creature_ai.get("temperaments", {}) as Dictionary).get("skittish", {})
	_check(skittish.has("flee_speed_mult") and is_equal_approx(float(zeb.brain.profile.get("flee_speed_mult", 0.0)), float(skittish["flee_speed_mult"])), "skittish temperament not merged into zebraceratops profile")
	var raptor := _creature(&"velociraptor")
	_check(is_equal_approx(float(raptor.brain.profile.get("chase_speed_mult", 0.0)), 0.7), "chase_speed_mult missing on pack_raptor")
	# Every carnivore archetype names its chase multiplier (the owner tunes it per archetype).
	var rows: Dictionary = data.creature_ai.get("archetypes", {})
	for key in rows:
		var row: Variant = rows[key]
		if row is Dictionary and not bool((row as Dictionary).get("is_herbivore", false)):
			_check((row as Dictionary).has("chase_speed_mult"), "archetype %s has no chase_speed_mult" % key)
	zeb.free()
	raptor.free()

func _test_level_scaling() -> void:
	var c := _creature(&"velociraptor")
	c.level = c.def.tier
	var base: float = c.stat_value(&"melee_attack")
	c.level = c.def.tier + 5
	var up: float = c.stat_value(&"melee_attack")
	var rate := float(data.world_rules.get("wild_level_stat_rate", 0.0))
	_check(is_equal_approx(up, base * (1.0 + 5.0 * rate)), "tier+5 attack %.2f, expected %.2f" % [up, base * (1.0 + 5.0 * rate)])
	c.level = maxi(1, c.def.tier - 5)
	_check(is_equal_approx(c.stat_value(&"melee_attack"), base), "a level below tier changed stats")
	c.free()

func _test_solo_spawn_and_tame_pack() -> void:
	var sp: Node = load("res://scripts/world/spawner.gd").new()
	sp.species = &"velociraptor"
	sp.count = 1
	sp.as_pack = true
	get_root().add_child(sp)
	var out: Array = sp.spawn_now()
	_check(out.size() == 1 and out[0].pack_id == 0, "a solo spawn joined pack %d" % (out[0].pack_id if out.size() > 0 else -1))
	for c in out:
		c.free()
	sp.count = 3
	var trio: Array = sp.spawn_now()
	_check(trio.size() == 3 and trio[0].pack_id > 0 and trio[0].pack_id == trio[2].pack_id, "a pack of three did not share a pack id")
	trio[1].become_pet(load("res://scripts/pets/pet_record.gd").from_def(trio[1].def, &"normal"))
	_check(trio[1].pack_id == 0, "a tame kept its wild pack id %d" % trio[1].pack_id)
	for c in trio:
		c.free()
	sp.free()

## qa-ai-01: the leash rule for all 19 species, not 3. A target just inside aggro_radius is
## kept for a think; one just outside is dropped on the next think and the animal stands down.
func _test_leash_every_species() -> void:
	game.time_of_day = 0.40
	var ids := _species()
	_check(ids.size() == 19, "expected 19 species, found %d" % ids.size())
	var bad: Array[String] = []
	for id in ids:
		var c := _creature(id)
		var target := Node3D.new()
		get_root().add_child(target)
		var r: float = c.brain.aggro_radius()
		target.global_position = Vector3(r - 0.5, 0.0, 0.0)
		c.brain.attack_target = target
		c.brain._set_state(&"approach")
		c.brain.tick(0.1)
		var kept: bool = c.brain.attack_target == target
		target.global_position = Vector3(r + 0.5, 0.0, 0.0)
		c.brain._last_hit_s = -999.0  # not a fresh hit (see the next test)
		c.brain.tick(0.1)
		var dropped: bool = c.brain.attack_target == null and c.brain.state in [&"disengage", &"roam"]
		if not kept or not dropped:
			bad.append("%s r=%.1f kept=%s dropped=%s state=%s" % [id, r, kept, dropped, c.brain.state])
		c.free()
		target.free()
	_check(bad.is_empty(), "leash rule broken: %s" % [bad])

## A grazer shot from just beyond its leash runs from the shot instead of walking home.
func _test_hit_beyond_leash_flees() -> void:
	game.time_of_day = 0.40
	var zeb := _creature(&"zebraceratops")
	var shooter := Node3D.new()
	get_root().add_child(shooter)
	shooter.global_position = Vector3(zeb.brain.aggro_radius() + 0.5, 0.0, 0.0)
	zeb.brain.note_damage(1.0)
	zeb.brain.on_aggro(shooter)
	var trail: Array[StringName] = [zeb.brain.state]
	for i in 12:  # 1.2 s of thinks: through alert into flee
		zeb.brain.tick(0.1)
		if trail[-1] != zeb.brain.state:
			trail.append(zeb.brain.state)
	_check(zeb.brain.state == &"flee" and zeb.brain.attack_target == shooter, "shot beyond the leash: trail %s target_kept=%s (want flee)" % [trail, zeb.brain.attack_target == shooter])
	# Once the hit is stale the leash applies again: it stops where it is, no walk home.
	zeb.brain._last_hit_s = _now_s() - 10.0
	zeb.brain.tick(0.1)
	_check(zeb.brain.attack_target == null and zeb.brain.state == &"roam", "stale hit past the leash: state=%s target=%s (want roam, none)" % [zeb.brain.state, zeb.brain.attack_target])
	zeb.free()
	shooter.free()

## A grazer hit while asleep wakes, flees, and does not fall asleep again at the leash edge.
func _test_hit_while_asleep_stays_awake() -> void:
	game.time_of_day = 0.05
	var zeb := _creature(&"zebraceratops")
	zeb.brain.tick(0.1)
	var slept: bool = zeb.brain.state == &"sleep"
	var shooter := Node3D.new()
	get_root().add_child(shooter)
	shooter.global_position = Vector3(8.0, 0.0, 0.0)
	zeb.brain.note_damage(1.0)
	zeb.brain.on_aggro(shooter)
	var awake_for: float = zeb.brain._awake_until - _now_s()
	# The threat leaves the leash: it stands down but stays awake.
	zeb.brain._last_hit_s = _now_s() - 10.0
	shooter.global_position = Vector3(zeb.brain.aggro_radius() + 5.0, 0.0, 0.0)
	for i in 5:
		zeb.brain.tick(0.1)
	_check(slept and awake_for >= 20.0 and zeb.brain.state != &"sleep", "hit while asleep: slept=%s awake_for=%.1f state=%s (want awake >= 20 s)" % [slept, awake_for, zeb.brain.state])
	game.time_of_day = 0.40
	zeb.free()
	shooter.free()

## The post-kill / post-flight home is temporary (TEMP_HOME_S), then the real one returns.
func _test_temp_home_expires() -> void:
	var c := _creature(&"velociraptor", 0, Vector3(3, 0, 4))
	var real: Vector3 = c.spawn_home
	c.brain._set_temp_home(real + Vector3(20, 0, 0))
	var moved: bool = c.spawn_home.distance_to(real) > 19.0
	var lasts: float = c.brain._home_until - _now_s()
	c.brain._home_until = _now_s() - 0.01
	c.brain.tick(0.1)
	_check(moved and lasts > 100.0 and c.spawn_home.distance_to(real) < 0.01, "temp home moved=%s lasts=%.0f s restored=%s" % [moved, lasts, c.spawn_home.distance_to(real) < 0.01])
	c.free()

## dino-ai-13: idle pack slots clear real bodies in a mixed-size pack (one leader, small and
## big followers): every slot is clear of the leader's body and of every other slot's body.
func _test_pack_slots_clear_bodies() -> void:
	var pack: Array = []
	for id in [&"tyrannosaurus", &"triceratops", &"velociraptor", &"velociraptor", &"compsognathus"]:
		pack.append(_creature(id, 77, Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))))
	var leader: Node = pack[0].brain._pack_leader()
	var slots: Dictionary = {}
	for c in pack:
		if c != leader:
			slots[c] = c.brain._idle_pack_slot(leader)
	var bad: Array[String] = []
	for c in slots:
		var s: Vector3 = slots[c]
		var gap: float = Vector2(s.x - leader.global_position.x, s.z - leader.global_position.z).length() - leader.body_radius() - c.body_radius()
		if gap < 0.0:
			bad.append("%s/leader %.2f" % [c.def.id, gap])
		for o in slots:
			if o != c and o.get_instance_id() > c.get_instance_id():
				var t: Vector3 = slots[o]
				var g2: float = Vector2(s.x - t.x, s.z - t.z).length() - c.body_radius() - o.body_radius()
				if g2 < 0.0:
					bad.append("%s/%s %.2f" % [c.def.id, o.def.id, g2])
	_check(leader != null and slots.size() == 4 and bad.is_empty(), "pack slots overlap bodies: %s" % [bad])
	for c in pack:
		c.free()
	_fresh_packs()
