extends SceneTree
## ALPHAS acceptance (owner 2026-10-28: "alpha dinosaurs with special loot but are on steroids and
## really hard to kill"). The spawn rate over many seeded rolls sits inside its data chance; an alpha's
## stats beat a twin's by the ai.json alpha modifier and its tactic knobs follow the class profile's
## alpha block; its carcass guarantees the rare rows, a rare trait on every part and the trophy, and the
## kill pays the XP multiplier; a packmate inside the aura radius is buffed and outside it is not; the
## name keeps "Alpha" with the nature as a chip under it, never in the name.
## Run: Godot --headless --path game --script res://tests/t_alphas.gd -> "[t_alphas] PASS".

const CREATURE_SCENE := "res://scenes/creatures/creature.tscn"

var _fails: PackedStringArray = []
var _started = false
var _sections = 0
var data: Node
var CG: GDScript
var NR: GDScript
var LR: GDScript
var BL: GDScript
var PI: GDScript
var INV: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	data = root.get_node("Data")
	var game = root.get_node_or_null("Game")
	if game:
		game.debug_overlay = false
	CG = load("res://scripts/creatures/creature_genetics.gd")
	NR = load("res://scripts/creatures/brains/brain_natures.gd")
	LR = load("res://scripts/gather/loot_roller.gd")
	BL = load("res://scripts/gather/butcher_loot.gd")
	PI = load("res://scripts/creatures/brains/pack_index.gd")
	INV = load("res://scripts/items/inventory.gd")
	_run()
	return false

func _run() -> void:
	_test_spawn_rate()
	await _test_stats()
	_test_loot()
	await _test_corpse()
	await _test_aura()
	await _test_name()
	var want = 6
	_expect(_sections == want, "only %d of %d sections completed" % [_sections, want])
	if _fails.is_empty():
		print("[t_alphas] PASS")
		quit(0)
	else:
		print("[t_alphas] FAIL count=%d" % _fails.size())
		quit(1)

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_alphas] FAIL %s" % what)

func _rng(seed_v: int) -> RandomNumberGenerator:
	var r = RandomNumberGenerator.new()
	r.seed = seed_v
	return r

func _rules() -> Dictionary:
	return data.creature_ai["alpha"]

func _test_spawn_rate() -> void:
	var chance = float(_rules()["chance_per_group"])
	var n = 20000
	var hits = 0
	for i in n:
		var idx: int = CG.alpha_pick(3, _rng(i))
		_expect(idx == -1 or idx == 0, "at most one alpha, member 0 (got %d)" % idx)
		hits += 1 if idx == 0 else 0
	var rate = float(hits) / float(n)
	# 3 sigma of a binomial at n = 20000 is about 0.6 % for p = 0.08.
	var tol = 3.0 * sqrt(chance * (1.0 - chance) / float(n))
	_expect(absf(rate - chance) <= tol, "alpha rate %.4f within %.4f of %.3f" % [rate, tol, chance])
	_expect(CG.alpha_pick(3, _rng(99)) == CG.alpha_pick(3, _rng(99)), "seeded alpha roll is deterministic")
	_expect(CG.alpha_pick(0, _rng(1)) == -1, "an empty group has no alpha")
	print("[t_alphas] spawn rate %.4f (chance %.3f)" % [rate, chance])
	_sections += 1

func _spawn(alpha: bool, at: Vector3, pack: int = 0) -> Variant:
	var c = load(CREATURE_SCENE).instantiate()
	root.add_child(c)
	c.global_position = at
	c.genetics = CG.neutral()
	c.alpha_spawn = alpha
	c.spawn(data.creature(&"deinonychus"), &"", pack)
	return c

func _test_stats() -> void:
	var n = _spawn(false, Vector3(0, 0, 0))
	var a = _spawn(true, Vector3(40, 0, 0))
	await process_frame
	_expect(a.is_alpha() and not n.is_alpha(), "alpha_spawn makes an alpha")
	var top: float = CG.size_range_for(a.def).y
	_expect(a.size_scale() > top, "alpha is bigger than any normal roll (%.3f > %.3f)" % [a.size_scale(), top])
	var st: Dictionary = _rules()["stats"]
	var sf = func(stat: StringName) -> float: return a.genetics.size_factor(stat)
	var hp_ratio = a.health.max_hp / n.health.max_hp
	_expect(absf(hp_ratio - float(st["health"]) * sf.call(&"health")) < 0.001, "alpha HP x %.2f x size (got %.3f)" % [float(st["health"]), hp_ratio])
	_expect(hp_ratio >= float(st["health"]), "alpha HP at least the modifier above normal")
	var atk_ratio = a.attack_for() / n.attack_for()
	_expect(absf(atk_ratio - float(st["melee_attack"]) * sf.call(&"melee_attack")) < 0.001, "alpha attack x modifier x size (got %.3f)" % atk_ratio)
	var def_ratio = a.defense_for() / n.defense_for()
	_expect(absf(def_ratio - float(st["melee_defense"])) < 0.001, "alpha defense x modifier (got %.3f)" % def_ratio)
	var spd_ratio = a.move_speed_mps() / n.move_speed_mps()
	_expect(absf(spd_ratio - float(st["speed"]) * sf.call(&"speed")) < 0.001 and spd_ratio > 1.0, "alpha speed x modifier x size, still faster (got %.3f)" % spd_ratio)
	# Class profile modifier: ai.json archetypes.pack_flanker.tactics.alpha.
	var mod: Dictionary = data.creature_ai["archetypes"]["pack_flanker"]["tactics"]["alpha"]
	for knob in ["tactic_cooldown_mult", "tactic_w_pounce", "tactic_w_charge", "tactic_w_combo"]:
		var r = a.nature_knob(knob, 1.0) / n.nature_knob(knob, 1.0)
		_expect(absf(r - float(mod[knob])) < 0.001, "alpha %s x %.2f (got %.3f)" % [knob, float(mod[knob]), r])
	_expect(a.nature_knob("aggro_radius_mult", 1.0) == n.nature_knob("aggro_radius_mult", 1.0), "non-tactic knobs unchanged")
	# Visibly distinct: darker and richer than the same genes as a normal animal, eyes brighter.
	_expect(a.genetics.coloration.val < n.genetics.coloration.val and a.genetics.coloration.sat > n.genetics.coloration.sat, "alpha is darker and richer (val %.2f sat %.2f)" % [a.genetics.coloration.val, a.genetics.coloration.sat])
	var ea = a.view.get_node_or_null("Eyes")
	var en = n.view.get_node_or_null("Eyes")
	_expect(ea != null and en != null and ea.glow > en.glow and ea.eye_material.emission_energy_multiplier > en.eye_material.emission_energy_multiplier, "alpha eyes glow stronger")
	_expect(a.kill_xp(a.def.tier) == int(round(float(4 + a.def.tier / 5) * float(_rules()["xp_mult"]))) and a.kill_xp(a.def.tier) > n.kill_xp(n.def.tier), "alpha kill pays the XP multiplier (%d vs %d)" % [a.kill_xp(a.def.tier), n.kill_xp(n.def.tier)])
	# A tame keeps size and colours but drops the steroids (PetStats has no alpha term).
	a.is_pet = true
	_expect(a.alpha_stat_mult(&"health") == 1.0 and a.pack_aura_mult("attack") == 1.0, "a pet gets no alpha stat buff")
	a.is_pet = false
	n.queue_free()
	a.queue_free()
	_sections += 1

func _test_loot() -> void:
	# The rare row: a 0.01 % row must drop every time on an alpha carcass, almost never on a normal one.
	var base = [{"id": "raptor_meat", "min": 2, "max": 3}, {"id": "raptor_bone", "min": 1, "max": 1}]
	var rare = [{"id": "raptor_hide", "min": 1, "max": 1, "chance": 0.0001}]
	var normal_rares = 0
	for i in 200:
		var res: Dictionary = LR.roll_carcass(base, rare, 30, &"", 5, 0, false, _rng(i), true)
		_expect((res["rares"] as Array).has(&"raptor_hide"), "#%d alpha carcass guarantees the rare row" % i)
		BL.alpha_extras(res, 30, _rng(500 + i))
		var trophies = 0
		for stack in res["stacks"]:
			if stack.def_id == &"alpha_trophy":
				trophies += stack.count
				continue
			var traits = INV.traits(stack)
			var has_rare = false
			for k in traits:
				has_rare = has_rare or traits[k] == true
			_expect(has_rare, "#%d alpha part %s carries a rare trait (%s)" % [i, stack.def_id, traits])
		_expect(trophies == int(_rules()["loot"]["trophy_count"]), "#%d alpha carcass has the trophy" % i)
		var plain: Dictionary = LR.roll_carcass(base, rare, 30, &"", 5, 0, false, _rng(i), false)
		normal_rares += (plain["rares"] as Array).size()
		for stack in plain["stacks"]:
			_expect(stack.def_id != &"alpha_trophy", "#%d a normal carcass has no trophy" % i)
	_expect(normal_rares <= 2, "a normal carcass keeps the shipped odds (%d of 200)" % normal_rares)
	_expect(data.item(&"alpha_trophy") != null, "alpha_trophy is an item")
	_sections += 1

func _test_corpse() -> void:
	var a = _spawn(true, Vector3(80, 0, 0))
	await process_frame
	a.health.take_damage(a.health.max_hp + 1.0, null)
	await process_frame
	var corpse = null
	for n in root.get_children():
		if n.has_method("cut_part") and n._owner == a:
			corpse = n
	_expect(corpse != null and corpse.alpha, "an alpha's corpse is marked alpha")
	if corpse != null:
		_expect(corpse.loot.count_of(&"alpha_trophy") >= 1, "an alpha's corpse holds the alpha trophy")
		corpse.queue_free()
	a.queue_free()
	_sections += 1

func _test_aura() -> void:
	var pack = 7777
	var a = _spawn(true, Vector3(200, 0, 0), pack)
	var mate = _spawn(false, Vector3(205, 0, 0), pack)
	var stranger = _spawn(false, Vector3(206, 0, 0), pack + 1)
	await physics_frame
	PI.invalidate()
	var aura: Dictionary = _rules()["aura"]
	_expect(absf(mate.pack_aura_mult("attack") - float(aura["attack"])) < 0.0001, "packmate inside %.0f m gets the attack buff (%.3f)" % [float(aura["radius_m"]), mate.pack_aura_mult("attack")])
	_expect(absf(mate.pack_aura_mult("speed") - float(aura["speed"])) < 0.0001 and absf(mate.pack_aura_mult("defense") - float(aura["defense"])) < 0.0001, "packmate gets speed and defense buffs")
	var base_atk = mate.stat_value(&"melee_attack") * mate.nature_knob("damage_dealt_mult", 1.0)
	_expect(absf(mate.attack_for() / base_atk - float(aura["attack"])) < 0.001, "the buff reaches attack_for")
	_expect(a.pack_aura_mult("attack") == 1.0, "the alpha does not buff itself")
	_expect(stranger.pack_aura_mult("attack") == 1.0, "another pack is not buffed")
	mate.global_position = a.global_position + Vector3(float(aura["radius_m"]) + 3.0, 0, 0)
	await physics_frame
	PI.invalidate()
	_expect(mate.pack_aura_mult("attack") == 1.0 and mate.pack_aura_mult("speed") == 1.0, "the buff ends outside the radius")
	mate.global_position = a.global_position + Vector3(2, 0, 0)
	await physics_frame
	PI.invalidate()
	a.health.take_damage(a.health.max_hp + 1.0, null)
	await physics_frame
	PI.invalidate()
	_expect(mate.pack_aura_mult("attack") == 1.0, "a dead alpha buffs nobody")
	for c in [a, mate, stranger]:
		c.queue_free()
	for n in root.get_children():
		if n.has_method("cut_part"):
			n.queue_free()
	_sections += 1

func _test_name() -> void:
	var lone = _spawn(true, Vector3(300, 0, 0))
	var plain = _spawn(false, Vector3(330, 0, 0))
	lone.nature = &"timid"
	plain.nature = &"timid"
	await process_frame
	var t: String = NR.display_title(lone)
	_expect(t.begins_with("Alpha "), "a lone alpha is named \"Alpha ...\" (%s)" % t)
	_expect(not NR.display_title(plain).begins_with("Alpha"), "a lone normal animal is not (%s)" % NR.display_title(plain))
	var chip: String = NR.tag_for(lone)
	_expect(chip != "" and not t.to_lower().contains(chip.to_lower()), "the nature is a chip (%s), not in the name (%s)" % [chip, t])
	lone.queue_free()
	plain.queue_free()
	_sections += 1
