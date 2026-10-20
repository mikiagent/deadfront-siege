extends Node3D
## W2-BREED end to end in a real scene: two bonded raptors out at home -> Breeding.pair_live lays an
## egg -> a Nest incubates it on the clock -> the baby hatches into the roster -> fed and cuddled it
## grows baby -> juvenile -> adolescent -> adult with rising stats. Then the bonded cap: a smilodon
## birth refused at 3 / 3, Animal Handling I-IV raise the cap to 7, the caged baby bonds at a pen.
## Headless: prints every step with numbers, '[breedlab] PASS n/n' and exits 0, else exits 1.
## Time is simulated with Breeding.clock_offset (lab only).

var _player: Player
var _fails: Array[String] = []
var _checks := 0
var _rng := RandomNumberGenerator.new()
var _nest: Nest

func _ready() -> void:
	_rng.seed = 20261020
	World.island_def = {"kind": "private", "climate": "grassland"} # lab stands in for the home island
	var kit := LabKit.build(self)
	_player = kit["player"]
	var cam := kit.get("cam", null) as Camera3D
	if cam:
		cam.size = 11.0
	print("[boot] lab=breeding_lab")
	call_deferred("_run")

func _check(ok: bool, what: String) -> bool:
	_checks += 1
	print("[breedlab] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)
	return ok

func _now() -> int:
	return Breeding.now()

func _skip(seconds: int) -> void:
	Breeding.clock_offset += seconds

func _adult(species: StringName, sex: StringName, level: int) -> PetRecord:
	var rec := PetRecord.from_def(Data.creature(species), &"", &"", CreatureGenetics.roll(_rng), level)
	rec.sex = sex
	return rec

func _ivs(g: CreatureGenetics) -> String:
	var parts: PackedStringArray = []
	for s in CreatureGenetics.STATS:
		parts.append("%s=%d" % [str(s).left(3), int(g.ivs[s])])
	return " ".join(parts)

func _run() -> void:
	await get_tree().process_frame
	_player.global_position = Vector3(0, 0, 0)
	# 1. Pair: two bonded adult raptors, both out, a few metres apart, at home.
	var mom := _adult(&"velociraptor", &"female", 10)
	var dad := _adult(&"velociraptor", &"male", 10)
	_check(Bonding.try_bond(_player, mom) and Bonding.try_bond(_player, dad), "two raptors bonded (%s)" % Bonding.label(_player))
	_player.summon_pet(0)
	_player.summon_pet(1)
	await get_tree().process_frame
	print("[breedlab] mother %s %s grade=%s ivs %s" % [mom.uid, mom.sex, mom.grade, _ivs(mom.genetics)])
	print("[breedlab] father %s %s grade=%s ivs %s" % [dad.uid, dad.sex, dad.grade, _ivs(dad.genetics)])
	var why := Breeding.pair_live(_player, mom, dad, _rng)
	var egg_idx := _player.inventory.find_first(Breeding.EGG_ID)
	if not _check(why == "" and egg_idx >= 0, "pair -> fertilised egg in the bag ('%s')" % why):
		_finish()
		return
	var egg := _player.inventory.slots[egg_idx]
	var eg := CreatureGenetics.from_dict(egg.attributes["genetics"])
	print("[breedlab] egg %s gen=%d mutations=%s ivs %s" % [egg.uid, int(egg.attributes["generation"]), str(egg.attributes["mutations"]), _ivs(eg)])
	_check(Breeding.pair_live(_player, mom, dad, _rng) != "", "same pair refused while on cooldown")
	# 2. Incubate in a nest; save the nest halfway, reload it, finish on the original timestamp.
	_nest = Nest.make(&"egg_nest")
	_nest.position = Vector3(-2.5, 0, 1.5)
	add_child(_nest)
	_check(_nest.interact(_player) and _nest.egg != null, "egg goes into the nest: %s" % _nest.status_text())
	var need := Incubation.required_s(&"velociraptor")
	var hatch_at := Incubation.hatch_at(_nest.egg)
	_skip(int(need / 2.0))
	_nest.tick(_now())
	var saved := JSON.parse_string(JSON.stringify(_nest.to_dict())) as Dictionary
	_nest.queue_free()
	_nest = Nest.from_dict(saved)
	_nest.position = Vector3(-2.5, 0, 1.5)
	add_child(_nest)
	print("[breedlab] nest saved at %.0f / %.0f s, reloaded: %s" % [need / 2.0, need, _nest.status_text()])
	_skip(hatch_at - _now() - 1)
	_check(_nest.tick(_now()) == null and _nest.egg != null, "reloaded egg not hatched 1 s early (hatch_at %d)" % hatch_at)
	_skip(1)
	var before := _player.bonded.size()
	var baby := _nest.tick(_now(), _rng)
	if not _check(baby != null and _player.bonded.size() == before + 1 and baby.born_at == hatch_at, "egg hatched on its timestamp into the roster (%s)" % Bonding.label(_player)):
		_finish()
		return
	print("[breedlab] baby %s %s grade=%s gen=%d parents=%s ivs %s" % [baby.uid, baby.sex, baby.grade, baby.generation, ",".join(baby.parent_uids), _ivs(baby.genetics)])
	# 3. Grow: feed when hungry, cuddle when due, one stage at a time.
	LabKit.give(_player, &"raw_meat", 20)
	var last_hp := baby.hp
	var rising := true
	var stages: Array[StringName] = [PetGrowth.stage(baby)]
	var step := 300
	var t_end := baby.born_at + int(PetGrowth.total_s()) + step
	while _now() < t_end:
		_skip(step)
		var t := _now()
		PetGrowth.advance(baby, t)
		var care := PetGrowth.care_state(baby, t)
		if care["hungry"]:
			PetGrowth.feed(baby, _player.inventory, t)
		if care["cuddle_ready"]:
			PetGrowth.cuddle(baby, t)
		rising = rising and baby.hp >= last_hp - 0.001
		last_hp = baby.hp
		if stages[-1] != PetGrowth.stage(baby):
			stages.append(PetGrowth.stage(baby))
			print("[breedlab] t+%5ds %-10s maturity=%.2f imprint=%.2f hp=%.0f atk=%.0f scale=%.2f" % [t - baby.born_at, PetGrowth.stage(baby), baby.maturity, baby.imprint, baby.hp, baby.attack, PetGrowth.body_scale(baby)])
	_check(str(stages) == str([&"baby", &"juvenile", &"adolescent", &"adult"]), "stages %s" % str(stages))
	_check(rising, "stats rose monotonically (adult hp %.0f atk %.0f)" % [baby.hp, baby.attack])
	_check(is_equal_approx(baby.imprint, 1.0), "every cuddle taken: imprint %.0f%%" % (100.0 * baby.imprint))
	var plain := PetStats.compute(Data.creature(baby.species), baby.genetics, baby.level)
	var bonus := float(PetGrowth.cfg().get("imprint_bonus", 0.2))
	_check(absf(baby.hp / float(plain[&"health"]) - (1.0 + bonus)) < 0.001, "imprint bonus x%.2f on hp" % (baby.hp / float(plain[&"health"])))
	# 4. Bonded cap: a smilodon birth at 3 / 3 is refused at the pen (cage kept), Animal Handling I-IV -> 7.
	var cat_mom := _adult(&"smilodon", &"female", 10)
	var cat_dad := _adult(&"smilodon", &"male", 10)
	var g := Breeding.pair(cat_mom, cat_dad, _now(), _rng)
	_check(g.get("gestation", false) and not g.has("egg"), "smilodon pairing starts a gestation, no egg")
	_skip(int(Breeding.species_cfg(&"smilodon").get("gestation_s", 3600)))
	var cage := Breeding.birth_if_due(cat_mom, _now(), _rng)
	_check(cage != null and cage.attributes.get("pet") is Dictionary, "gestation ends in a caged baby")
	if cage == null:
		_finish()
		return
	_player.inventory.add(cage)
	var pen := TamingPen.make()
	pen.position = Vector3(3, 0, -2)
	add_child(pen)
	var n_before := _player.bonded.size()
	_check(not pen.try_insert(_player) and _player.bonded.size() == n_before and _player.inventory.find_first(&"captured_animal") >= 0, "caged baby refused at %s, cage kept: '%s'" % [Bonding.label(_player), Bonding.full_message(n_before, Bonding.cap(_player))])
	var sk := _player.skills
	sk.trees["survival"]["level"] = 60
	sk.sp_available = 2000
	var caps: Array[int] = []
	for n in sk.nodes("survival"): # file order satisfies every "requires"
		if sk.unlock("survival", str(n["id"])) and int(n.get("bonded_cap_bonus", 0)) > 0:
			caps.append(Bonding.cap(_player))
	_check(str(caps) == str([4, 5, 6, 7]), "Animal Handling I-IV raise the cap %s" % str(caps))
	_check(pen.try_insert(_player) and _player.bonded.size() == n_before + 1 and _player.inventory.find_first(&"captured_animal") < 0, "caged smilodon baby bonded at the pen (%s)" % Bonding.label(_player))
	_finish()

func _finish() -> void:
	Breeding.clock_offset = 0
	var verdict := "PASS %d/%d" % [_checks, _checks] if _fails.is_empty() else "FAIL %s" % "; ".join(PackedStringArray(_fails))
	print("[breedlab] %s" % verdict)
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		get_tree().quit(0 if _fails.is_empty() else 1)
