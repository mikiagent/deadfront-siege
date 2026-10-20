extends SceneTree
## W2-BREED checks: inheritance split, mutation rate and lineage soft cap, egg incubation across a
## save/load, growth to adult with rising stats, imprint bonus, bonded cap 3 -> 7 with Animal Handling,
## and the durango 09 capture rule. Usage: godot --headless --path game --script res://tests/t_breed.gd

var failures: Array[String] = []
var _done := false

# Game classes load on the first frame the Data autoload exists (same pattern as t_tame.gd).
var PetRecordS: GDScript
var GeneticsS: GDScript
var BreedingS: GDScript
var GrowthS: GDScript
var IncubationS: GDScript
var BondingS: GDScript
var FieldTameS: GDScript
var CaptureS: GDScript
var ItemStackS: GDScript
var InventoryS: GDScript
var SkillStateS: GDScript
var NestS: GDScript
var PlayerS: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	PetRecordS = load("res://scripts/pets/pet_record.gd")
	GeneticsS = load("res://scripts/creatures/creature_genetics.gd")
	BreedingS = load("res://scripts/pets/breeding.gd")
	GrowthS = load("res://scripts/pets/pet_growth.gd")
	IncubationS = load("res://scripts/pets/incubation.gd")
	BondingS = load("res://scripts/pets/bonding.gd")
	FieldTameS = load("res://scripts/pets/field_tame.gd")
	CaptureS = load("res://scripts/pets/capture_system.gd")
	ItemStackS = load("res://scripts/items/item_stack.gd")
	InventoryS = load("res://scripts/items/inventory.gd")
	SkillStateS = load("res://scripts/skills/skill_state.gd")
	NestS = load("res://scripts/world/nest.gd")
	PlayerS = load("res://scripts/player/player.gd")
	_test_smoke_pair()
	_test_inheritance_split()
	_test_mutation_rate()
	_test_mutation_counters()
	_test_egg_save_load()
	_test_growth_to_adult()
	_test_imprint_bonus()
	_test_bonded_cap()
	_test_capture_rule()
	_test_sex_and_lineage_save()
	_test_pair_refusals()
	_test_gestation()
	if failures.is_empty():
		print("[t_breed] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_breed] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _data() -> Node:
	return get_root().get_node("Data")

func _cfg(section: String) -> Dictionary:
	return _data().breeding.get(section, {})

func _def(id: StringName):
	return _data().creature(id)

## An adult bonded pet of `species` and `sex` at `level`, with genetics `g` (null = rolled by rng).
func _pet(species: StringName, sex: StringName, level: int, g, rng: RandomNumberGenerator):
	var rec = PetRecordS.from_def(_def(species), &"", &"", g if g != null else GeneticsS.roll(rng), level)
	rec.sex = sex
	return rec

func _json_round(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d)) as Dictionary

## One pair -> egg -> hatch -> adult run through the public API.
func _test_smoke_pair() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var t0 := 1_800_000_000
	var mom = _pet(&"velociraptor", &"female", 10, null, rng)
	var dad = _pet(&"velociraptor", &"male", 10, null, rng)
	var why: String = BreedingS.pair_refusal(mom, dad, t0, 3.0, true)
	_expect(why == "", "valid pair accepted (got '%s')" % why)
	var out: Dictionary = BreedingS.pair(mom, dad, t0, rng)
	var egg = out.get("egg")
	_expect(egg != null and egg.def_id == &"fertilized_egg" and egg.uid != "", "raptor pair lays a unique fertilised egg")
	if egg == null:
		return
	_expect(BreedingS.pair_refusal(mom, dad, t0 + 60, 3.0, true) != "", "pair on cooldown right after breeding")
	IncubationS.start(egg, t0)
	var need: float = IncubationS.required_s(&"velociraptor")
	IncubationS.advance(egg, t0 + int(need), true)
	_expect(IncubationS.ready(egg), "egg ready after %.0f s in range" % need)
	var baby = IncubationS.hatch(egg, rng)
	_expect(baby != null and baby.maturity == 0.0 and baby.origin == &"breed" and baby.parent_uids.size() == 2, "egg hatches a baby with lineage")
	if baby == null:
		return
	baby.fed_until = baby.born_at + 10_000_000 # kept fed the whole way
	GrowthS.advance(baby, baby.born_at + int(GrowthS.total_s()) + 1)
	_expect(GrowthS.stage(baby) == &"adult", "baby is adult after the full growth time while fed (stage %s)" % GrowthS.stage(baby))
	print("[t_breed] smoke egg=%s need=%.0fs baby=%s sex=%s grade=%s gen=%d stage=%s hp=%.0f" % [egg.uid, need, baby.uid, baby.sex, baby.grade, baby.generation, GrowthS.stage(baby), baby.hp])

## Hatches an egg laid at `t0` (in range the whole time) and returns the baby.
func _hatch(egg, t0: int, rng: RandomNumberGenerator):
	IncubationS.start(egg, t0)
	IncubationS.advance(egg, t0 + int(IncubationS.required_s(StringName(str(egg.attributes["species"])))), true)
	return IncubationS.hatch(egg, rng)

## A newborn of `species` with genetics dict `genes`, born at `t_born`.
func _baby(species: StringName, genes: Dictionary, t_born: int, rng: RandomNumberGenerator):
	return BreedingS.baby_from({"species": str(species), "genetics": genes, "mother_uid": "m", "father_uid": "f", "generation": 1}, t_born, rng)

func _creature(id: StringName, hp_frac: float, knocked: bool):
	var cr = (load("res://scripts/creatures/creature.gd") as GDScript).new()
	cr.def = _def(id)
	cr.health = (load("res://scripts/combat/health.gd") as GDScript).new()
	cr.health.setup(cr.def.hp)
	cr.add_child(cr.health)
	cr.statuses = (load("res://scripts/combat/status_effects.gd") as GDScript).new()
	cr.add_child(cr.statuses)
	cr.health.hp = cr.def.hp * hp_frac
	if knocked:
		cr.statuses.apply(&"knockdown")
	return cr

## Each stat IV comes from one parent, the higher one at the configured chance; EVs and level gains
## never pass on; the hatched baby's grade is its genetics' tier.
func _test_inheritance_split() -> void:
	var m := _cfg("mutation")
	var keep := [m.get("chance_per_stat"), m.get("colour_chance")]
	m["chance_per_stat"] = 0.0
	m["colour_chance"] = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var higher := 0
	var differ := 0
	var leaked := 0
	for _i in 1000:
		var mom = _pet(&"velociraptor", &"female", 10, null, rng)
		var dad = _pet(&"velociraptor", &"male", 10, null, rng)
		mom.genetics.evs[&"health"] = 50
		dad.genetics.level_gains[&"speed"] = 9
		var g = BreedingS.offspring(mom, dad, rng)["genetics"]
		for s in GeneticsS.STATS:
			leaked += int(g.evs[s]) + int(g.level_gains[s])
			var mi := int(mom.genetics.ivs[s])
			var fi := int(dad.genetics.ivs[s])
			if mi == fi:
				continue
			differ += 1
			if int(g.ivs[s]) == maxi(mi, fi):
				higher += 1
	var mom2 = _pet(&"velociraptor", &"female", 10, null, rng)
	var dad2 = _pet(&"velociraptor", &"male", 10, null, rng)
	var baby = _hatch(BreedingS.pair(mom2, dad2, 1_800_000_000, rng)["egg"], 1_800_000_000, rng)
	m["chance_per_stat"] = keep[0]
	m["colour_chance"] = keep[1]
	var share := float(higher) / float(maxi(1, differ))
	var want := float(_cfg("inheritance").get("higher_parent_chance", 0.55))
	_expect(absf(share - want) <= 0.02, "IV from the higher parent %.3f, config %.2f (+-0.02)" % [share, want])
	_expect(leaked == 0, "EVs/level gains leaked into offspring (%d points)" % leaked)
	_expect(baby != null and baby.grade == baby.genetics.overall_tier(), "baby grade derives from its genetics")
	print("[t_breed] inherit pairs=1000 differing_stats=%d higher=%.3f (config %.2f) leaked=%d baby_grade=%s" % [differ, share, want, leaked, baby.grade if baby else "-"])

## Rolls stat (and colour) mutations of `pairs` raptor pairings; returns [stat_mut, colour_mut, bad_iv].
func _mutations(pairs: int, rng: RandomNumberGenerator, fresh_parents: bool, line: int = 0) -> Array:
	var steps := int(_cfg("mutation").get("iv_steps", 2))
	var cap: int = GeneticsS.iv_cap()
	var stat_mut := 0
	var colour_mut := 0
	var bad_iv := 0
	var mom = _pet(&"velociraptor", &"female", 10, null, rng)
	var dad = _pet(&"velociraptor", &"male", 10, null, rng)
	for _i in pairs:
		if fresh_parents:
			mom = _pet(&"velociraptor", &"female", 10, null, rng)
			dad = _pet(&"velociraptor", &"male", 10, null, rng)
		mom.mut_maternal = line
		dad.mut_maternal = line
		var kid: Dictionary = BreedingS.offspring(mom, dad, rng)
		for id in kid["mutations"]:
			if str(id) == "colour":
				colour_mut += 1
				continue
			stat_mut += 1
			var parent = mom if str(kid["from"][StringName(str(id))]) == "mother" else dad
			if int(kid["genetics"].ivs[StringName(str(id))]) != mini(cap, int(parent.genetics.ivs[StringName(str(id))]) + steps):
				bad_iv += 1
	return [stat_mut, colour_mut, bad_iv]

## Measured mutation rates match config; a mutated IV is the parent's + iv_steps (capped).
func _test_mutation_rate() -> void:
	var m := _cfg("mutation")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var n: int = GeneticsS.STATS.size()
	var shipped := _mutations(1000, rng, true)
	var c := float(m.get("chance_per_stat", 0.01))
	var cc := float(m.get("colour_chance", 0.025))
	var rate := float(shipped[0]) / float(1000 * n)
	var crate := float(shipped[1]) / 1000.0
	_expect(absf(rate - c) <= 0.01, "stat mutation rate %.4f vs config %.4f" % [rate, c])
	_expect(absf(crate - cc) <= 0.01, "colour mutation rate %.4f vs config %.4f" % [crate, cc])
	var keep: Variant = m.get("chance_per_stat")
	m["chance_per_stat"] = 0.25
	var high := _mutations(4000, rng, false)
	m["chance_per_stat"] = keep
	var hrate := float(high[0]) / float(4000 * n)
	_expect(absf(hrate - 0.25) <= 0.01, "stat mutation rate %.4f at chance 0.25" % hrate)
	_expect(int(shipped[2]) + int(high[2]) == 0, "mutated IVs are parent + iv_steps capped (%d wrong)" % (int(shipped[2]) + int(high[2])))
	print("[t_breed] mutation shipped stat=%.4f (cfg %.4f) colour=%.4f (cfg %.4f) at0.25=%.4f bad_iv=%d" % [rate, c, crate, cc, hrate, int(shipped[2]) + int(high[2])])

## Lineage counters add up generation over generation and, past the soft cap, cut the chance.
func _test_mutation_counters() -> void:
	var m := _cfg("mutation")
	var c := float(m.get("chance_per_stat", 0.01))
	var soft := int(m.get("soft_cap", 20))
	var mult := float(m.get("soft_cap_mult", 0.1))
	_expect(is_equal_approx(BreedingS.mutation_chance(0), c), "mutation_chance(0) is the config chance")
	_expect(is_equal_approx(BreedingS.mutation_chance(soft), c * mult) and BreedingS.mutation_chance(soft) < c, "soft cap lowers the chance")
	var keep: Variant = m.get("chance_per_stat")
	m["chance_per_stat"] = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var t0 := 1_800_000_000
	var line = _pet(&"velociraptor", &"female", 10, null, rng)
	var gens: Array[int] = []
	var totals: Array[int] = [0]
	for gen in 3:
		var mate = _pet(&"velociraptor", &"male" if line.sex == &"female" else &"female", 10, null, rng)
		var baby = _hatch(BreedingS.pair(line, mate, t0, rng)["egg"], t0, rng)
		gens.append(baby.generation)
		totals.append(baby.mut_maternal + baby.mut_paternal)
		line = baby
	m["chance_per_stat"] = 0.25
	var capped := _mutations(2000, rng, false, soft)
	m["chance_per_stat"] = keep
	var rising := totals[1] > totals[0] and totals[2] > totals[1] and totals[3] > totals[2]
	_expect(str(gens) == "[1, 2, 3]", "generations 1, 2, 3 (got %s)" % str(gens))
	_expect(rising, "lineage mutation totals rise (got %s)" % str(totals))
	var crate := float(capped[0]) / float(2000 * GeneticsS.STATS.size())
	_expect(absf(crate - 0.25 * mult) <= 0.01 and crate < 0.25, "past the soft cap the rate is %.4f (want %.4f)" % [crate, 0.25 * mult])
	print("[t_breed] counters gens=%s totals=%s capped_rate=%.4f (want %.4f)" % [str(gens), str(totals), crate, 0.25 * mult])

## An egg saved halfway (as a stack and inside a nest) hatches on the original timestamp after load;
## an out-of-range nest pauses it, an incubator does not.
func _test_egg_save_load() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	var t0 := 1_800_000_000
	var egg = BreedingS.pair(_pet(&"velociraptor", &"female", 10, null, rng), _pet(&"velociraptor", &"male", 10, null, rng), t0, rng)["egg"]
	IncubationS.start(egg, t0)
	var need := int(IncubationS.required_s(&"velociraptor"))
	IncubationS.advance(egg, t0 + need / 2, true)
	var as_stack = ItemStackS.from_dict(_json_round(egg.to_dict()))
	var nest = NestS.make(&"egg_nest")
	nest.egg = egg
	var nest2 = NestS.from_dict(_json_round(nest.to_dict()))
	var copies := [as_stack, nest2.egg]
	var ok := 0
	for copy in copies:
		var ha: int = IncubationS.hatch_at(copy)
		IncubationS.advance(copy, ha - 1, true)
		var early: bool = IncubationS.ready(copy)
		IncubationS.advance(copy, ha, true)
		var baby = IncubationS.hatch(copy, rng)
		if ha == t0 + need and not early and baby != null and baby.born_at == t0 + need:
			ok += 1
	_expect(ok == 2, "saved eggs hatch at t0+%d after load (%d/2 ok)" % [need, ok])
	nest.free()
	nest2.free()
	var cold = ItemStackS.make(&"fertilized_egg", 1, {"species": "tarbosaurus"})
	IncubationS.start(cold, t0)
	IncubationS.advance(cold, t0 + 600, IncubationS.temp_ok(&"tarbosaurus", &"egg_nest", "grassland"))
	_expect(not IncubationS.temp_ok(&"tarbosaurus", &"egg_nest", "grassland") and is_equal_approx(IncubationS.remaining_s(cold), IncubationS.required_s(&"tarbosaurus")), "tundra egg pauses in a grassland nest")
	_expect(IncubationS.temp_ok(&"tarbosaurus", &"egg_incubator", "grassland") and IncubationS.temp_ok(&"velociraptor", &"egg_nest", "grassland"), "incubator holds any egg; raptor egg fine in a grassland nest")
	var r: Vector2 = IncubationS.egg_range(&"tarbosaurus")
	print("[t_breed] egg need=%ds hatch_at=t0+%d ok=%d/2 tarbosaurus range=%.0f..%.0fC grassland=%.0fC" % [need, need, ok, r.x, r.y, IncubationS.climate_temp("grassland")])

## Fed the whole way, a baby goes baby -> juvenile -> adolescent -> adult on the configured clock with
## stats never falling; an unfed one grows at neglect_rate and never dies.
func _test_growth_to_adult() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	var t_born := 1_800_000_000
	var genes: Dictionary = GeneticsS.roll(rng).to_dict()
	var baby = _baby(&"velociraptor", genes, t_born, rng)
	var inv = InventoryS.new(20)
	for _i in 3:
		inv.add(ItemStackS.make(&"raw_meat", 10))
	var step := 60
	var total := int(GrowthS.total_s())
	var bounds: Array[int] = []
	var acc := 0
	for st in GrowthS.stages():
		acc += int(st["s"])
		bounds.append(acc)
	var changes: Array = []
	var last_stage: StringName = GrowthS.stage(baby)
	var stages: Array[StringName] = [last_stage]
	var last_hp: float = baby.hp
	var last_atk: float = baby.attack
	var monotonic := true
	var t := t_born
	while t < t_born + total + 2 * step:
		t += step
		if baby.fed_until < t + step:
			GrowthS.feed(baby, inv, t)
		GrowthS.advance(baby, t)
		monotonic = monotonic and baby.hp >= last_hp - 0.0001 and baby.attack >= last_atk - 0.0001
		last_hp = baby.hp
		last_atk = baby.attack
		if GrowthS.stage(baby) != last_stage:
			last_stage = GrowthS.stage(baby)
			stages.append(last_stage)
			changes.append(t - t_born)
	_expect(str(stages) == str([&"baby", &"juvenile", &"adolescent", &"adult"]), "stage order %s" % str(stages))
	var on_time := changes.size() == bounds.size()
	for i in mini(changes.size(), bounds.size()):
		on_time = on_time and absi(int(changes[i]) - bounds[i]) <= step
	_expect(on_time, "stage changes at %s, config boundaries %s (+-%ds)" % [str(changes), str(bounds), step])
	_expect(monotonic, "hp/attack never fall while growing")
	_expect(baby.maturity >= 1.0 and GrowthS.stage(baby) == &"adult", "adult by t_born + %ds" % total)
	var c: Dictionary = GrowthS.cfg()
	var feed := float(c.get("feed_interval_s", 1200))
	var neglect := float(c.get("neglect_rate", 0.5))
	var starved = _baby(&"velociraptor", genes, t_born, rng)
	GrowthS.advance(starved, t_born + total)
	var want := (feed + (total - feed) * neglect) / float(total)
	var starved_m: float = starved.maturity
	_expect(starved_m < 1.0 and absf(starved_m - want) <= 0.01 and starved.hp > 0.0, "unfed baby at maturity %.3f (want %.3f), alive" % [starved_m, want])
	GrowthS.advance(starved, t_born + total + int(ceilf((1.0 - starved.maturity) * total / neglect)) + 1)
	_expect(GrowthS.stage(starved) == &"adult", "neglected baby still grows up, later")
	print("[t_breed] growth stages=%s at=%s cfg=%s adult_hp=%.0f starved_maturity=%.3f (want %.3f)" % [str(stages), str(changes), str(bounds), baby.hp, starved_m, want])

## Cuddling at every window reaches 100 % imprint; the imprinted adult beats a plain one by imprint_bonus.
func _test_imprint_bonus() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 16
	var t_born := 1_800_000_000
	var genes: Dictionary = GeneticsS.roll(rng).to_dict()
	var loved = _baby(&"velociraptor", genes, t_born, rng)
	var plain = _baby(&"velociraptor", genes, t_born, rng)
	loved.fed_until = t_born + 100_000_000
	plain.fed_until = t_born + 100_000_000
	var early: bool = GrowthS.cuddle(loved, t_born - 1)
	var first: bool = GrowthS.cuddle(loved, t_born)
	var again: bool = GrowthS.cuddle(loved, t_born + 1)
	var cuddles := 1 if first else 0
	var t := t_born
	while t < t_born + int(GrowthS.total_s()) + 60:
		t += 60
		if GrowthS.cuddle_ready(loved, t) and GrowthS.cuddle(loved, t):
			cuddles += 1
	GrowthS.advance(loved, t)
	GrowthS.advance(plain, t)
	_expect(not early and first and not again, "cuddle refused before cuddle_at and right after one")
	_expect(is_equal_approx(loved.imprint, 1.0) and plain.imprint == 0.0, "imprint loved=%.3f plain=%.3f" % [loved.imprint, plain.imprint])
	var bonus := float(GrowthS.cfg().get("imprint_bonus", 0.2))
	var hp_ratio: float = loved.hp / plain.hp
	var atk_ratio: float = loved.attack / plain.attack
	_expect(absf(hp_ratio - (1.0 + bonus)) <= 0.0001 and absf(atk_ratio - (1.0 + bonus)) <= 0.0001, "imprint 100 %% vs 0 %%: hp x%.4f atk x%.4f (want x%.4f)" % [hp_ratio, atk_ratio, 1.0 + bonus])
	print("[t_breed] imprint cuddles=%d loved=%.3f hp %.0f vs %.0f (x%.4f, cfg +%.2f)" % [cuddles, loved.imprint, loved.hp, plain.hp, hp_ratio, bonus])

func _skills():
	var sk = SkillStateS.new()
	sk._load()
	return sk

## Bonded cap 3 + 1 per Animal Handling I-IV (real purchases with level and SP gates) = 7; a 4th bond
## at 3 / 3 is refused without losing the animal; a reset keeps pets but blocks new bonds.
func _test_bonded_cap() -> void:
	var sk = _skills()
	var cap0: int = _data().bonded_cap(sk)
	sk.trees["survival"]["level"] = 34
	sk.sp_available = 100
	var low_level: bool = sk.unlock("survival", "animal_management_1")
	var gate = _skills()
	gate.trees["survival"]["level"] = 60
	(gate.trees["survival"]["unlocked"] as Array).append("capture_technique_3")
	gate.sp_available = 3
	var poor: bool = gate.unlock("survival", "animal_management_1")
	gate.sp_available = 4
	var paid: bool = gate.unlock("survival", "animal_management_1")
	sk.trees["survival"]["level"] = 60
	sk.sp_available = 10000
	var caps: Array[int] = []
	var costs: Array[int] = []
	var levels: Array[int] = []
	for n in sk.nodes("survival"):
		if sk.unlock("survival", str(n["id"])) and int(n.get("bonded_cap_bonus", 0)) > 0:
			caps.append(_data().bonded_cap(sk))
			costs.append(int(n["sp"]))
			levels.append(int(n["level"]))
	_expect(cap0 == 3, "base cap 3 (got %d)" % cap0)
	_expect(not low_level and not poor and paid, "Animal Handling I needs Survival 35 and 4 SP (level34=%s sp3=%s sp4=%s)" % [low_level, poor, paid])
	_expect(str(caps) == "[4, 5, 6, 7]" and str(costs) == "[4, 5, 5, 6]" and str(levels) == "[35, 45, 55, 60]", "cap %s costs %s levels %s" % [str(caps), str(costs), str(levels)])
	var fresh = _skills()
	var player = PlayerS.new()
	player.skills = fresh
	var raptor = _def(&"velociraptor")
	for _i in 3:
		BondingS.try_bond(player, PetRecordS.from_def(raptor))
	var fourth = PetRecordS.from_def(raptor)
	var refused: bool = not BondingS.try_bond(player, fourth)
	var msg: String = BondingS.full_message(3, 3)
	_expect(refused and player.bonded.size() == 3 and not player.bonded.has(fourth) and fourth.uid != "" and msg.contains("3 / 3"), "4th bond refused at 3 / 3 with nothing lost ('%s')" % msg)
	_expect(BondingS.label(player) == "3 / 3", "label reads 3 / 3 (got %s)" % BondingS.label(player))
	var vet = PlayerS.new()
	vet.skills = sk
	for _i in 7:
		BondingS.try_bond(vet, PetRecordS.from_def(raptor))
	var full_seven: int = vet.bonded.size()
	sk.refund("survival", "animal_management_4")
	var after_reset: int = BondingS.cap(vet)
	_expect(full_seven == 7 and after_reset == 6 and vet.bonded.size() == 7 and not BondingS.can_bond(vet), "reset: cap %d, pets kept %d, new bonds blocked" % [after_reset, vet.bonded.size()])
	print("[t_breed] cap base=%d caps=%s costs=%s levels=%s 4th_refused=%s reset_cap=%d kept=%d" % [cap0, str(caps), str(costs), str(levels), refused, after_reset, vet.bonded.size()])
	for id in _data().survival_unlocked.keys():
		_data().survival_unlocked[id] = false
	player.free()
	vet.free()
	for node in [sk, gate, fresh]:
		node.free()

## Durango 09: stunned at ANY HP or under 30 % is eligible; awake at 50 % is not (with the hint);
## dead and pets never; the chance reads actual HP and level.
func _test_capture_rule() -> void:
	var cases := [
		[0.80, true, true, "stunned 80 %"],
		[0.50, false, false, "awake 50 %"],
		[0.29, false, true, "awake 29 %"],
		[0.50, true, true, "stunned 50 %"],
	]
	var got: Array[String] = []
	for row in cases:
		var cr = _creature(&"velociraptor", float(row[0]), bool(row[1]))
		var ok: bool = FieldTameS.capture_eligible(cr)
		_expect(ok == bool(row[2]) and FieldTameS.can_attempt(cr) == ok, "%s eligible=%s (want %s)" % [row[3], ok, row[2]])
		got.append("%s=%s" % [row[3], ok])
		cr.free()
	var hint_text := str(_cfg("capture").get("hint_text", ""))
	var awake = _creature(&"velociraptor", 0.5, false)
	var stunned = _creature(&"velociraptor", 0.5, true)
	_expect(FieldTameS.capture_hint(awake) == hint_text and hint_text != "" and FieldTameS.capture_hint(stunned) == "", "hint '%s' at awake 50 %%, none once stunned" % FieldTameS.capture_hint(awake))
	var dead = _creature(&"velociraptor", 0.5, true)
	dead.health.hp = 0.0
	dead.health.dead = true
	var pet = _creature(&"velociraptor", 0.2, true)
	pet.is_pet = true
	_expect(not FieldTameS.capture_eligible(dead) and not FieldTameS.capture_eligible(pet), "dead and pets never eligible")
	var p80: float = CaptureS.chance(2, 2, 0.8, 1)
	var p29: float = CaptureS.chance(2, 2, 0.29, 1)
	var p29_lv30: float = CaptureS.chance(2, 2, 0.29, 30)
	_expect(p80 < p29 and p29_lv30 < p29, "chance uses HP and level (80%%=%.2f 29%%=%.2f 29%%@Lv30=%.2f)" % [p80, p29, p29_lv30])
	print("[t_breed] capture %s hint='%s' p80=%.2f p29=%.2f p29lv30=%.2f" % [", ".join(PackedStringArray(got)), hint_text, p80, p29, p29_lv30])
	for node in [awake, stunned, dead, pet]:
		node.free()

## Sex is rolled and saved; lineage and growth fields round-trip; legacy saves get a stable sex.
func _test_sex_and_lineage_save() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var t0 := 1_800_000_000
	var rec = PetRecordS.from_def(_def(&"velociraptor"))
	_expect(rec.sex == &"female" or rec.sex == &"male", "from_def rolls a sex (%s)" % rec.sex)
	rec.generation = 3
	rec.mut_maternal = 2
	rec.mut_paternal = 5
	rec.born_at = t0
	rec.maturity = 0.4
	rec.imprint = 0.5
	rec.breed_ready_at = t0 + 99
	rec.parent_uids.assign(["pa", "pb"])
	var back = PetRecordS.from_dict(_json_round(rec.to_dict()))
	var same: bool = back.sex == rec.sex and back.generation == 3 and back.mut_maternal == 2 and back.mut_paternal == 5 \
		and back.born_at == t0 and is_equal_approx(back.maturity, 0.4) and is_equal_approx(back.imprint, 0.5) \
		and back.breed_ready_at == t0 + 99 and str(back.parent_uids) == str(rec.parent_uids)
	_expect(same, "lineage and growth fields round-trip")
	var legacy: Dictionary = rec.to_dict()
	legacy.erase("sex")
	var a = PetRecordS.from_dict(_json_round(legacy))
	var b = PetRecordS.from_dict(_json_round(legacy))
	_expect(a.sex == b.sex and a.sex == PetRecordS.sex_from_uid(rec.uid), "legacy save gets a stable sex from its uid")
	var females := 0
	for _i in 1000:
		if PetRecordS.roll_sex(rng) == &"female":
			females += 1
	_expect(absf(float(females) / 1000.0 - 0.5) <= 0.05, "sex roll female share %.3f" % (float(females) / 1000.0))
	print("[t_breed] sex rolled=%s roundtrip=%s legacy=%s females=%d/1000" % [rec.sex, same, a.sex, females])

## Every pairing rule refuses with a reason; a valid pair passes.
func _test_pair_refusals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 18
	var t0 := 1_800_000_000
	var p := _cfg("pairing")
	var min_level := int(p.get("min_level", 5))
	var radius := float(p.get("radius_m", 12.0))
	var mom = _pet(&"velociraptor", &"female", min_level, null, rng)
	var dad = _pet(&"velociraptor", &"male", min_level, null, rng)
	var baby = _pet(&"velociraptor", &"male", min_level, null, rng)
	baby.maturity = 0.0
	var resting = _pet(&"velociraptor", &"male", min_level, null, rng)
	resting.breed_ready_at = t0 + 100
	var cases := [
		["same sex", mom, _pet(&"velociraptor", &"female", min_level, null, rng), 3.0, true],
		["other species", mom, _pet(&"compsognathus", &"male", min_level, null, rng), 3.0, true],
		["baby", mom, baby, 3.0, true],
		["under level", mom, _pet(&"velociraptor", &"male", maxi(1, min_level - 1), null, rng), 3.0, true],
		["too far", mom, dad, radius + 1.0, true],
		["away from home", mom, dad, 3.0, false],
		["on cooldown", mom, resting, 3.0, true],
	]
	var reasons: Array[String] = []
	for row in cases:
		var why: String = BreedingS.pair_refusal(row[1], row[2], t0, float(row[3]), bool(row[4]))
		_expect(why != "", "%s must be refused" % row[0])
		reasons.append("%s: %s" % [row[0], why])
	var ok: String = BreedingS.pair_refusal(mom, dad, t0, 3.0, true)
	_expect(ok == "", "valid pair passes (got '%s')" % ok)
	print("[t_breed] refusals %s" % " | ".join(PackedStringArray(reasons)))

## Mammals: no egg, a gestation timer on the mother that ends in a caged baby on time.
func _test_gestation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var t0 := 1_800_000_000
	var mom = _pet(&"smilodon", &"female", 10, null, rng)
	var dad = _pet(&"smilodon", &"male", 10, null, rng)
	var out: Dictionary = BreedingS.pair(mom, dad, t0, rng)
	var gest_s := int(BreedingS.species_cfg(&"smilodon").get("gestation_s", 3600))
	var ends := int(mom.gestation.get("ends_at", 0))
	_expect(bool(out.get("gestation", false)) and not out.has("egg") and ends == t0 + gest_s, "smilodon gestation ends at t0+%d (got t0+%d)" % [gest_s, ends - t0])
	var early = BreedingS.birth_if_due(mom, ends - 1, rng)
	var cage = BreedingS.birth_if_due(mom, ends, rng)
	var pet: Dictionary = cage.attributes.get("pet", {}) if cage else {}
	var parents: Array = pet.get("parent_uids", [])
	_expect(early == null and cage != null and cage.def_id == &"captured_animal" and bool(cage.attributes.get("baby", false)), "caged baby delivered at ends_at, not before")
	_expect(float(pet.get("maturity", 1.0)) == 0.0 and str(pet.get("origin", "")) == "breed" and parents.size() == 2 and str(parents[0]) == mom.uid and str(parents[1]) == dad.uid and int(pet.get("born_at", 0)) == ends, "cage holds the newborn's PetDict with lineage")
	print("[t_breed] gestation ends=t0+%d cage=%s baby_sex=%s born_at=t0+%d" % [ends - t0, cage.uid if cage else "-", str(pet.get("sex", "")), int(pet.get("born_at", 0)) - t0])
