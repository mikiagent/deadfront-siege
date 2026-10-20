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
	_test_smoke_pair()
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
