extends SceneTree
## GENETICS acceptance (owner 2026-10-28: "dinosaur size and color variation (heritable stats)").
## Size rolls inside each species' range; a spawned animal's model, collision capsule, eyes, mount
## socket and stats follow its size by the ai.json "genetics" factors; colours stay inside the natural
## limits; the genome round-trips through a save and an old save without one loads 1.0x / not alpha;
## inherit() blends inside the parents' range plus a bounded mutation; seeded rolls are deterministic.
## Run: Godot --headless --path game --script res://tests/t_genetics.gd -> "[t_genetics] PASS".

const CREATURE_SCENE := "res://scenes/creatures/creature.tscn"

var _fails: PackedStringArray = []
var _started = false
var _sections = 0
var data: Node
var CG: GDScript
var CC: GDScript
var PR: GDScript
var PS: GDScript
var SS: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	data = root.get_node("Data")
	var game = root.get_node_or_null("Game")
	if game:
		game.debug_overlay = false
	CG = load("res://scripts/creatures/creature_genetics.gd")
	CC = load("res://scripts/creatures/creature_coloration.gd")
	PR = load("res://scripts/pets/pet_record.gd")
	PS = load("res://scripts/pets/pet_stats.gd")
	SS = load("res://scripts/core/save_sanitizer.gd")
	_run()
	return false

func _run() -> void:
	_test_size_ranges()
	_test_colour_palette()
	await _test_scale_applied()
	_test_save_round_trip()
	_test_old_save()
	_test_inherit()
	_test_determinism()
	var want = 7
	_expect(_sections == want, "only %d of %d sections completed" % [_sections, want])
	if _fails.is_empty():
		print("[t_genetics] PASS")
		quit(0)
	else:
		print("[t_genetics] FAIL count=%d" % _fails.size())
		quit(1)

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_genetics] FAIL %s" % what)

func _rng(seed_v: int) -> RandomNumberGenerator:
	var r = RandomNumberGenerator.new()
	r.seed = seed_v
	return r

func _test_size_ranges() -> void:
	var rules: Dictionary = data.creature_ai.get("genetics", {})
	var glob: Array = rules.get("size_range", [])
	_expect(glob.size() == 2 and float(glob[0]) < 1.0 and float(glob[1]) > 1.0, "ai.json genetics.size_range brackets 1.0: %s" % [glob])
	var n = 0
	for id in data.creatures:
		var def = data.creatures[id]
		var r: Vector2 = CG.size_range_for(def)
		var lo = 9.0
		var hi = 0.0
		for i in 300:
			var g = CG.for_species(def, _rng(i), _rng(1000 + i))
			lo = minf(lo, g.size)
			hi = maxf(hi, g.size)
			_expect(g.size >= r.x and g.size <= r.y, "%s size %.3f inside %s" % [id, g.size, r])
			_expect(not g.alpha, "%s normal roll is not alpha" % id)
		# The range is used, not a constant: 300 rolls cover most of it.
		_expect(hi - lo > (r.y - r.x) * 0.8, "%s sizes spread %.3f..%.3f over %s" % [id, lo, hi, r])
		n += 1
	_expect(n >= 15, "checked %d species" % n)
	print("[t_genetics] size ranges ok over %d species" % n)
	_sections += 1

func _test_colour_palette() -> void:
	for id in data.creatures:
		var def = data.creatures[id]
		for i in 200:
			var g = CG.for_species(def, _rng(i), _rng(5000 + i))
			_in_palette(g.coloration, "%s #%d" % [id, i])
			if i < 20:
				g.make_alpha(_rng(i))
				_in_palette(g.coloration, "%s alpha #%d" % [id, i])
	_sections += 1

## Natural palette: the shift never leaves the hard limits (a rare morph gets its documented wider span),
## so no species is ever painted a rarity colour.
func _in_palette(c, what: String) -> void:
	var span: float = CC.RARE_SCALE if c.rare else 1.0
	var hue_span: float = CC.RARE_HUE_SCALE if c.rare else 1.0
	_expect(absf(c.hue_deg) <= CC.HUE_LIMIT * hue_span + 0.001, "%s hue %.2f natural" % [what, c.hue_deg])
	_expect(absf(c.sat - 1.0) <= CC.SAT_LIMIT * span + 0.001, "%s sat %.3f natural" % [what, c.sat])
	_expect(absf(c.val - 1.0) <= CC.VAL_LIMIT * span + 0.001, "%s val %.3f natural" % [what, c.val])

func _spawn(size: float, at: Vector3) -> Variant:
	var c = load(CREATURE_SCENE).instantiate()
	root.add_child(c)
	c.global_position = at
	var g = CG.neutral()
	g.size = size
	c.genetics = g
	c.spawn(data.creature(&"deinonychus"), &"", 0)
	return c

func _test_scale_applied() -> void:
	var a = _spawn(1.0, Vector3(0, 0, 0))
	var b = _spawn(1.12, Vector3(30, 0, 0))
	var s = _spawn(0.88, Vector3(60, 0, 0))
	await process_frame
	var def = a.def
	_expect(is_equal_approx(b.view.scale.x, 1.12) and is_equal_approx(s.view.scale.x, 0.88), "model scale follows size (%.3f, %.3f)" % [b.view.scale.x, s.view.scale.x])
	var cap_a = a.shape.shape as CapsuleShape3D
	var cap_b = b.shape.shape as CapsuleShape3D
	_expect(absf(cap_b.radius / cap_a.radius - 1.12) < 0.001, "capsule radius x size (%.3f / %.3f)" % [cap_b.radius, cap_a.radius])
	_expect(absf(cap_b.height - def.height_meters * 1.12) < 0.01 or cap_b.height > cap_a.height, "capsule height grows (%.2f vs %.2f)" % [cap_b.height, cap_a.height])
	_expect(absf(b.body_radius() / a.body_radius() - 1.12) < 0.001, "body_radius x size")
	_expect(is_equal_approx(b.size_scale(), 1.12), "size_scale hook (ragdoll) reads the genome")
	# Stats by the data factor: stat x (1 + k x (size - 1)).
	var per: Dictionary = data.creature_ai["genetics"]["size_stat_per"]
	var want_hp = 1.0 + float(per["health"]) * 0.12
	var want_atk = 1.0 + float(per["melee_attack"]) * 0.12
	var want_spd = 1.0 + float(per["speed"]) * 0.12
	_expect(absf(b.health.max_hp / a.health.max_hp - want_hp) < 0.001, "HP x %.3f (got %.3f)" % [want_hp, b.health.max_hp / a.health.max_hp])
	_expect(absf(b.attack_for() / a.attack_for() - want_atk) < 0.001, "attack x %.3f (got %.3f)" % [want_atk, b.attack_for() / a.attack_for()])
	_expect(absf(b.move_speed_mps() / a.move_speed_mps() - want_spd) < 0.001, "speed x %.3f (got %.3f)" % [want_spd, b.move_speed_mps() / a.move_speed_mps()])
	_expect(b.move_speed_mps() < a.move_speed_mps() and s.move_speed_mps() > a.move_speed_mps(), "bigger is slower, smaller faster")
	# Pets read the same factor through PetStats.
	var pg = CG.neutral()
	pg.size = 1.12
	var p_big: Dictionary = PS.compute(def, pg, 1)
	var p_one: Dictionary = PS.compute(def, CG.neutral(), 1)
	_expect(absf(float(p_big[&"health"]) / float(p_one[&"health"]) - want_hp) < 0.001, "PetStats HP x size factor")
	# Eyes and mount socket ride the scaled view.
	var eyes = b.view.get_node_or_null("Eyes") as Node3D
	if eyes != null:
		var ea = a.view.get_node("Eyes")
		var eb = eyes
		var sep_a = ea.dots[0].global_position.distance_to(ea.dots[1].global_position)
		var sep_b = eb.dots[0].global_position.distance_to(eb.dots[1].global_position)
		_expect(absf(sep_b / sep_a - 1.12) < 0.01, "eye points follow the scale (%.4f / %.4f)" % [sep_b, sep_a])
	else:
		_expect(false, "deinonychus has eye dots")
	var ma = a.view.mount_socket().global_position - a.global_position
	var mb = b.view.mount_socket().global_position - b.global_position
	_expect(absf(mb.length() / maxf(0.001, ma.length()) - 1.12) < 0.02, "mount socket follows the scale (%.3f / %.3f)" % [mb.length(), ma.length()])
	for c in [a, b, s]:
		c.queue_free()
	_sections += 1

func _test_save_round_trip() -> void:
	var def = data.creature(&"deinonychus")
	var g = CG.for_species(def, _rng(7), _rng(8))
	var j = JSON.stringify(g.to_dict())
	var back = CG.from_dict(JSON.parse_string(j))
	_expect(absf(back.size - g.size) < 0.0001, "size round-trips (%.4f vs %.4f)" % [back.size, g.size])
	_expect(back.coloration.equals(g.coloration), "colours round-trip")
	_expect(back.ivs == g.ivs, "IVs round-trip")
	var al = CG.for_species(def, _rng(9), _rng(10))
	al.make_alpha(_rng(11))
	var al_back = CG.from_dict(JSON.parse_string(JSON.stringify(al.to_dict())))
	_expect(al_back.alpha and absf(al_back.size - al.size) < 0.0001 and al_back.coloration.equals(al.coloration), "alpha genome round-trips")
	# Through a pet record and the save sanitizer, as the save does it.
	var rec = PR.from_def(def, &"", &"", g, 5)
	var row: Dictionary = JSON.parse_string(JSON.stringify(rec.to_dict()))
	var save = {"pets": [row]}
	SS.clean(save)
	_expect((save["pets"] as Array).size() == 1, "sanitizer keeps the pet row")
	var rec2 = PR.from_dict(save["pets"][0])
	_expect(absf(rec2.genetics.size - g.size) < 0.0001, "pet size survives save/load (%.4f)" % rec2.genetics.size)
	_expect(absf(rec2.hp - rec.hp) < 0.01, "pet HP (size-scaled) recomputes the same (%.2f vs %.2f)" % [rec2.hp, rec.hp])
	_sections += 1

func _test_old_save() -> void:
	# A pet row written before the genome fields: genetics has IVs and colours, no size / alpha.
	var old = {
		"uid": "p_00aa11bb22cc33dd", "species": "deinonychus", "level": 4, "origin": "tame",
		"genetics": {
			"ivs": {"health": 20, "melee_defense": 10, "ranged_defense": 10, "melee_attack": 25, "ranged_attack": 5, "accuracy": 16, "speed": 30},
			"evs": {}, "level_gains": {},
			"coloration": {"hue_deg": 4.0, "sat": 1.05, "val": 0.95, "morph": "", "rare": false, "pattern": "", "pattern_scale": 1.0, "pattern_strength": 0.0, "pattern_tone": 1.0, "pattern_seed": 0.0},
		},
	}
	var rec = PR.from_dict(old)
	_expect(rec.genetics.size == 1.0 and not rec.genetics.alpha, "old save loads 1.0x, not alpha (%.3f, %s)" % [rec.genetics.size, rec.genetics.alpha])
	_expect(int(rec.genetics.ivs[&"melee_attack"]) == 25 and absf(rec.genetics.coloration.hue_deg - 4.0) < 0.001, "old save keeps its IVs and colours")
	var no_genes = PR.from_dict({"uid": "p_1122334455667788", "species": "velociraptor"})
	_expect(no_genes.genetics.size == 1.0, "a row without any genetics loads 1.0x")
	# Junk is clamped, never trusted.
	var junk = CG.from_dict({"size": 99.0, "alpha": "yes"})
	_expect(junk.size == CG.SIZE_LIMIT.y and not junk.alpha, "forged size clamps, a non-bool alpha is false")
	_sections += 1

func _test_inherit() -> void:
	var def = data.creature(&"deinonychus")
	var mut: Dictionary = data.creature_ai["genetics"]["mutation"]
	var miv = int(mut["iv"])
	var ms = float(mut["size"])
	var mh = float(mut["hue_deg"])
	for i in 200:
		var a = CG.for_species(def, _rng(i), _rng(300 + i))
		var b = CG.for_species(def, _rng(900 + i), _rng(1300 + i))
		if i % 10 == 0:
			b.make_alpha(_rng(i))
		a.train(&"health", 50)
		var c = CG.inherit(a, b, _rng(7000 + i))
		for stat in CG.STATS:
			var lo = mini(int(a.ivs[stat]), int(b.ivs[stat])) - miv
			var hi = maxi(int(a.ivs[stat]), int(b.ivs[stat])) + miv
			_expect(int(c.ivs[stat]) >= maxi(0, lo) and int(c.ivs[stat]) <= mini(CG.IV_MAX, hi), "#%d %s IV %d in [%d, %d]" % [i, stat, c.ivs[stat], lo, hi])
			_expect(int(c.evs[stat]) == 0 and int(c.level_gains[stat]) == 0, "#%d EVs and level gains are not inherited" % i)
		_expect(c.size >= minf(a.size, b.size) - ms - 0.0001 and c.size <= maxf(a.size, b.size) + ms + 0.0001, "#%d size %.3f between %.3f and %.3f +- %.2f" % [i, c.size, a.size, b.size, ms])
		var h_lo = minf(a.coloration.hue_deg, b.coloration.hue_deg) - mh
		var h_hi = maxf(a.coloration.hue_deg, b.coloration.hue_deg) + mh
		_expect(c.coloration.hue_deg >= maxf(-CC.HUE_LIMIT, h_lo) - 0.001 and c.coloration.hue_deg <= minf(CC.HUE_LIMIT, h_hi) + 0.001, "#%d hue %.2f in parents' range" % [i, c.coloration.hue_deg])
		_expect(c.coloration.pattern == a.coloration.pattern or c.coloration.pattern == b.coloration.pattern, "#%d pattern from a parent" % i)
		_expect(not c.alpha and not c.coloration.rare, "#%d alpha and rare are not inherited" % i)
		_in_palette(c.coloration, "child #%d" % i)
	_sections += 1

func _test_determinism() -> void:
	var def = data.creature(&"deinonychus")
	var g1 = CG.for_species(def, _rng(42), _rng(43))
	var g2 = CG.for_species(def, _rng(42), _rng(43))
	_expect(g1.size == g2.size and g1.ivs == g2.ivs and g1.coloration.equals(g2.coloration), "seeded for_species is deterministic")
	# The size draws after the colours, so a seeded colour stream is the same as before the size gene.
	var plain = CG.roll(_rng(42), def.coloration, _rng(43))
	_expect(plain.coloration.equals(g1.coloration), "adding size left the seeded colour roll unchanged")
	var c1 = CG.inherit(g1, plain, _rng(5))
	var c2 = CG.inherit(g1, plain, _rng(5))
	_expect(c1.size == c2.size and c1.ivs == c2.ivs and c1.coloration.equals(c2.coloration), "seeded inherit is deterministic")
	var c3 = CG.inherit(g1, plain, _rng(6))
	_expect(not (c3.size == c1.size and c3.ivs == c1.ivs), "another seed gives another child")
	_sections += 1
