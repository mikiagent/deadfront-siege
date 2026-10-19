extends RefCounted
## Cases for t_ai.gd (loaded once the autoloads exist).

var failures: Array[String] = []
var root: Node

func run(p_root: Node) -> Array[String]:
	root = p_root
	_test_state_changed_once()
	_test_profiles()
	_test_level_scaling()
	_test_solo_spawn_and_tame_pack()
	return failures

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)

func _creature(id: StringName, pack: int = 0) -> Creature:
	var c: Creature = load("res://scenes/creatures/creature.tscn").instantiate()
	root.add_child(c)
	c.spawn(Data.creature(id), &"", pack)
	return c

func _test_state_changed_once() -> void:
	var c := _creature(&"velociraptor")
	var seen: Array = []
	c.brain.state_changed.connect(func (p: StringName, n: StringName) -> void: seen.append([p, n]))
	var from := c.brain.state
	c.brain._set_state(&"alert")
	c.brain._set_state(&"alert")  # no transition, no signal
	c.brain._set_state(&"approach")
	c.brain._set_state(&"roam")
	var want := [[from, &"alert"], [&"alert", &"approach"], [&"approach", &"roam"]]
	_check(seen == want, "state_changed once per transition: got %s want %s" % [seen, want])
	c.free()

func _test_profiles() -> void:
	var zeb := _creature(&"zebraceratops")
	var skittish: Dictionary = (Data.creature_ai.get("temperaments", {}) as Dictionary).get("skittish", {})
	_check(skittish.has("flee_speed_mult") and is_equal_approx(float(zeb.brain.profile.get("flee_speed_mult", 0.0)), float(skittish["flee_speed_mult"])), "skittish temperament not merged into zebraceratops profile")
	var raptor := _creature(&"velociraptor")
	_check(is_equal_approx(float(raptor.brain.profile.get("chase_speed_mult", 0.0)), 0.7), "chase_speed_mult missing on pack_raptor")
	zeb.free()
	raptor.free()

func _test_level_scaling() -> void:
	var c := _creature(&"velociraptor")
	c.level = c.def.tier
	var base := c.stat_value(&"melee_attack")
	c.level = c.def.tier + 5
	var up := c.stat_value(&"melee_attack")
	var rate := float(Data.world_rules.get("wild_level_stat_rate", 0.0))
	_check(is_equal_approx(up, base * (1.0 + 5.0 * rate)), "tier+5 attack %.2f, expected %.2f" % [up, base * (1.0 + 5.0 * rate)])
	c.level = maxi(1, c.def.tier - 5)
	_check(is_equal_approx(c.stat_value(&"melee_attack"), base), "a level below tier changed stats")
	c.free()

func _test_solo_spawn_and_tame_pack() -> void:
	var sp := Spawner.new()
	sp.species = &"velociraptor"
	sp.count = 1
	sp.as_pack = true
	root.add_child(sp)
	var out := sp.spawn_now()
	_check(out.size() == 1 and out[0].pack_id == 0, "a solo spawn joined pack %d" % (out[0].pack_id if out.size() > 0 else -1))
	for c in out:
		c.free()
	sp.count = 3
	var trio := sp.spawn_now()
	_check(trio.size() == 3 and trio[0].pack_id > 0 and trio[0].pack_id == trio[2].pack_id, "a pack of three did not share a pack id")
	trio[1].become_pet(PetRecord.from_def(trio[1].def, &"normal"))
	_check(trio[1].pack_id == 0, "a tame kept its wild pack id %d" % trio[1].pack_id)
	for c in trio:
		c.free()
	sp.free()
