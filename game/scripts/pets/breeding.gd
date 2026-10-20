class_name Breeding
extends RefCounted
## Pairing, inheritance and mutations (W2-BREED). Node-free: the server can run it as is.
## Two bonded adults of one species and opposite sex, at or above pairing.min_level, near each other
## at home and off cooldown, make a fertilised egg (a unique "fertilized_egg" stack carrying the
## rolled genetics) or, for a gestation species, start a timer on the mother that ends in a caged
## baby. Each stat IV comes from one parent (the higher one with inheritance.higher_parent_chance);
## level gains and EVs are never inherited; the grade derives from the result (PetRecord.recompute).

const EGG_ID := &"fertilized_egg"

## Test/lab clock skew; the game never sets it.
static var clock_offset: int = 0

static func cfg() -> Dictionary:
	return Data.breeding

static func section(key: String) -> Dictionary:
	return cfg().get(key, {})

static func now() -> int:
	return int(Time.get_unix_time_from_system()) + clock_offset

static func species_cfg(species: StringName) -> Dictionary:
	return section("species").get(str(species), {})

## "egg" or "gestation".
static func birth_kind(species: StringName) -> String:
	return str(species_cfg(species).get("birth", "egg"))

## "" when the pair may breed, else the reason to show.
static func pair_refusal(a: PetRecord, b: PetRecord, at: int, distance_m: float, at_home: bool) -> String:
	if a == null or b == null or a == b or a.uid == b.uid:
		return "Pick two different animals."
	if a.species != b.species:
		return "Only animals of the same species can breed."
	if a.sex == b.sex:
		return "They need to be a female and a male."
	var p := section("pairing")
	var min_level := int(p.get("min_level", 5))
	for r in [a, b]:
		var rec := r as PetRecord
		if PetGrowth.is_baby(rec):
			return "%s is not grown up yet." % _who(rec)
		if rec.level < min_level:
			return "%s must be level %d to breed." % [_who(rec), min_level]
		if at < rec.breed_ready_at:
			return "%s can breed again in %s." % [_who(rec), _dur(rec.breed_ready_at - at)]
	var mother := a if a.sex == &"female" else b
	if not mother.gestation.is_empty():
		return "%s is already expecting." % _who(mother)
	if bool(p.get("require_home", true)) and not at_home:
		return "Breeding only works at your home island."
	if distance_m > float(p.get("radius_m", 12.0)):
		return "Bring them closer together (within %.0f m)." % float(p.get("radius_m", 12.0))
	return ""

## Mutation chance for one stat whose parent line already carries `line_mutations`.
static func mutation_chance(line_mutations: int, base: float = -1.0) -> float:
	var m := section("mutation")
	var p := float(m.get("chance_per_stat", 0.01)) if base < 0.0 else base
	return p * float(m.get("soft_cap_mult", 0.1)) if line_mutations >= int(m.get("soft_cap", 20)) else p

## Rolls the child's genes. Returns {genetics: CreatureGenetics, from: {stat: "mother"|"father"},
## mutations: Array[String] (stat ids and "colour"), mut_maternal, mut_paternal, generation}.
static func offspring(mother: PetRecord, father: PetRecord, rng: RandomNumberGenerator) -> Dictionary:
	var m := section("mutation")
	var higher_p := float(section("inheritance").get("higher_parent_chance", 0.55))
	var steps := int(m.get("iv_steps", 2))
	var cap := CreatureGenetics.iv_cap()
	var line := {"mother": mother.mut_maternal + mother.mut_paternal, "father": father.mut_maternal + father.mut_paternal}
	var counters := line.duplicate()
	var g := CreatureGenetics.neutral()
	var from := {}
	var mutations: Array[String] = []
	for stat in CreatureGenetics.STATS:
		var mi := int(mother.genetics.ivs.get(stat, 16))
		var fi := int(father.genetics.ivs.get(stat, 16))
		var mother_higher := mi >= fi if mi != fi else rng.randf() < 0.5
		var take_higher := rng.randf() < higher_p
		var side := "mother" if mother_higher == take_higher else "father"
		var iv := mi if side == "mother" else fi
		if rng.randf() < mutation_chance(int(line[side])):
			iv = mini(cap, iv + steps)
			mutations.append(str(stat))
			counters[side] = int(counters[side]) + 1
		g.ivs[stat] = iv
		from[stat] = side
	# Colour comes from one parent (even odds) unless it mutates into a new palette entry.
	var colour_side := "mother" if rng.randf() < 0.5 else "father"
	g.colour = mother.genetics.colour if colour_side == "mother" else father.genetics.colour
	var palette: Array = cfg().get("colours", [""])
	if palette.size() > 1 and rng.randf() < mutation_chance(int(line[colour_side]), float(m.get("colour_chance", 0.025))):
		g.colour = 1 + rng.randi_range(0, palette.size() - 2)
		mutations.append("colour")
		counters[colour_side] = int(counters[colour_side]) + 1
	return {
		"genetics": g,
		"from": from,
		"mutations": mutations,
		"mut_maternal": int(counters["mother"]),
		"mut_paternal": int(counters["father"]),
		"generation": maxi(mother.generation, father.generation) + 1,
	}

## Breeds a valid pair (call pair_refusal first). Puts both on cooldown. Returns {egg: ItemStack}
## for egg layers, or {gestation: true} after starting the mother's timer.
static func pair(a: PetRecord, b: PetRecord, at: int, rng: RandomNumberGenerator) -> Dictionary:
	var mother := a if a.sex == &"female" else b
	var father := b if mother == a else a
	var kid := offspring(mother, father, rng)
	var attrs := {
		"species": str(mother.species),
		"mother_uid": mother.uid,
		"father_uid": father.uid,
		"genetics": (kid["genetics"] as CreatureGenetics).to_dict(),
		"mutations": kid["mutations"],
		"generation": kid["generation"],
		"mut_maternal": kid["mut_maternal"],
		"mut_paternal": kid["mut_paternal"],
		"laid_at": at,
	}
	var cd: Dictionary = section("pairing").get("cooldown_s", {})
	mother.breed_ready_at = at + int(cd.get("female", 21600))
	father.breed_ready_at = at + int(cd.get("male", 3600))
	if birth_kind(mother.species) == "gestation":
		mother.gestation = {"ends_at": at + int(species_cfg(mother.species).get("gestation_s", 3600)), "embryo": attrs}
		return {"gestation": true}
	var egg := ItemStack.make(EGG_ID, 1, attrs)
	egg.stamp_identity("breed")
	return {"egg": egg}

## A newborn from egg or embryo attributes (Incubation.hatch, gestation births).
static func baby_from(attrs: Dictionary, born_at: int, rng: RandomNumberGenerator) -> PetRecord:
	var def := Data.creature(StringName(str(attrs.get("species", ""))))
	if def == null:
		return null
	var genes_raw: Variant = attrs.get("genetics", {})
	var genes := CreatureGenetics.from_dict(genes_raw) if genes_raw is Dictionary else CreatureGenetics.roll(rng)
	var rec := PetRecord.from_def(def, &"", &"", genes, 1)
	rec.origin = &"breed"
	rec.sex = PetRecord.roll_sex(rng)
	rec.parent_uids.assign([str(attrs.get("mother_uid", "")), str(attrs.get("father_uid", ""))])
	rec.generation = maxi(1, int(PetRecord._num(attrs.get("generation"), 1)))
	rec.mut_maternal = maxi(0, int(PetRecord._num(attrs.get("mut_maternal"), 0)))
	rec.mut_paternal = maxi(0, int(PetRecord._num(attrs.get("mut_paternal"), 0)))
	rec.tamed_at = born_at
	PetGrowth.start(rec, born_at)
	return rec

## Ends a due gestation: returns the newborn in a cage (a captured_animal stack carrying the full
## PetDict under "pet"; a taming pen bonds it without a timed tame). null while still expecting.
static func birth_if_due(mother: PetRecord, at: int, rng: RandomNumberGenerator) -> ItemStack:
	if mother == null or mother.gestation.is_empty() or at < int(PetRecord._num(mother.gestation.get("ends_at"), 0)):
		return null
	var ends := int(PetRecord._num(mother.gestation.get("ends_at"), at))
	var embryo: Variant = mother.gestation.get("embryo", {})
	var baby := baby_from(embryo if embryo is Dictionary else {}, ends, rng)
	if baby == null:
		mother.gestation = {}
		return null
	return cage(baby)

## # ASSUMPTION: W2-CAGE's caged_animal item does not exist yet; a bred baby rides in the
## captured_animal cage with its PetDict, which TamingPen.try_insert bonds directly.
static func cage(rec: PetRecord) -> ItemStack:
	var s := ItemStack.make(&"captured_animal", 1, {
		"species": str(rec.species),
		"level": rec.level,
		"genetics": rec.genetics.to_dict(),
		"sex": str(rec.sex),
		"baby": true,
		"pet": rec.to_dict(),
	})
	s.stamp_identity("breed")
	return s

## Player-level pairing: both pets must be out (live) near each other at home, and an egg needs bag
## room. Returns "" on success (the egg is in the bag or the mother is expecting), else the refusal,
## which is also shown as a notice. Integrator hook: the Animals screen breeding panel calls this.
static func pair_live(player: Player, a: PetRecord, b: PetRecord, rng: RandomNumberGenerator = null) -> String:
	var ca := _live(player, a)
	var cb := _live(player, b)
	var why := "Summon both animals first." if ca == null or cb == null else pair_refusal(a, b, now(), ca.global_position.distance_to(cb.global_position), World.is_home())
	if why == "" and birth_kind(a.species) == "egg" and player.inventory.used_slots() >= player.inventory.slot_count:
		why = "No room in your bag for the egg."
	if why != "":
		_say(player, why)
		return why
	var roller := rng if rng != null else _rng()
	var out := pair(a, b, now(), roller)
	if out.has("egg"):
		player.inventory.add(out["egg"])
		_say(player, "%s laid a fertilised egg." % _who(a if a.sex == &"female" else b))
	else:
		_say(player, "%s is expecting." % _who(a if a.sex == &"female" else b))
	return ""

## Once a second (integrator hook: Player._process): grows bonded babies and delivers due births
## into the bag. A birth waits, without loss, while the bag is full.
static func tick_player(player: Player, rng: RandomNumberGenerator = null) -> void:
	var t := now()
	for rec in player.bonded:
		PetGrowth.advance(rec, t)
		var cage_stack := birth_if_due(rec, t, rng if rng != null else _rng())
		if cage_stack == null:
			continue
		if player.inventory.add(cage_stack) > 0:
			continue # bag full: the gestation stays due and delivers on a later tick
		rec.gestation = {}
		_say(player, "%s gave birth. Take the cage to a taming pen to bond the baby." % _who(rec))

static func _live(player: Player, rec: PetRecord) -> Creature:
	for c in player.live_pets():
		if c.pet_record == rec:
			return c
	return null

static func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r

static func _say(player: Player, text: String) -> void:
	print("[breed] %s" % text)
	if player and player.is_inside_tree():
		player.notice(text)

static func _who(rec: PetRecord) -> String:
	return rec.name if rec.name != "" else str(rec.species).capitalize()

static func _dur(s: int) -> String:
	return "%dh %02dm" % [s / 3600, (s % 3600) / 60] if s >= 3600 else "%dm" % maxi(1, ceili(s / 60.0))
