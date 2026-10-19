extends SceneTree
## W1-TAME checks: pet bags keep their size, growth is additive and bounded, one grade drives
## the rates, every tame gets an identity, and the capture rules (30 % HP, technique) hold.
## Usage: godot --headless --path game --script res://tests/t_tame.gd

var failures: Array[String] = []
var _done := false

# Pet scripts reference the Data autoload, so they load on the first frame it exists
# (same pattern as run_all.gd).
var PetRecordS: GDScript
var PetStatsS: GDScript
var GeneticsS: GDScript
var FieldTameS: GDScript
var CaptureS: GDScript
var ItemStackS: GDScript
var InventoryS: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	PetRecordS = load("res://scripts/pets/pet_record.gd")
	PetStatsS = load("res://scripts/pets/pet_stats.gd")
	GeneticsS = load("res://scripts/creatures/creature_genetics.gd")
	FieldTameS = load("res://scripts/pets/field_tame.gd")
	CaptureS = load("res://scripts/pets/capture_system.gd")
	ItemStackS = load("res://scripts/items/item_stack.gd")
	InventoryS = load("res://scripts/items/inventory.gd")
	_test_bag_survives_reload()
	_test_growth_bounded()
	_test_add_xp_and_train_match_compute()
	_test_one_grade()
	_test_identity()
	_test_rules()
	if failures.is_empty():
		print("[t_tame] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_tame] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _data() -> Node:
	return get_root().get_node("Data")

func _def(id: StringName):
	return _data().creature(id)

## IV 31 everywhere; `gains` level-up points and `evs` EVs all in one stat (the worst case).
func _perfect(stat_focus: StringName, gains: int, evs: int):
	var g = GeneticsS.new()
	for s in GeneticsS.STATS:
		g.ivs[s] = GeneticsS.IV_MAX
		g.evs[s] = 0
		g.level_gains[s] = 0
	g.evs[stat_focus] = evs
	g.level_gains[stat_focus] = gains
	return g

func _json_round(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d)) as Dictionary

func _test_bag_survives_reload() -> void:
	var tri = _def(&"triceratops")
	var rec = PetRecordS.from_def(tri, &"", &"", null, 30)
	_expect(rec.bag.slot_count == 140, "fresh triceratops bag is 140 (got %d)" % rec.bag.slot_count)
	rec.bag.slots[50] = ItemStackS.make(&"stone", 7)
	var back = PetRecordS.from_dict(_json_round(rec.to_dict()))
	var s50 = back.bag.slots[50] if back.bag.slot_count > 50 else null
	_expect(back.bag.slot_count == 140 and s50 != null and s50.def_id == &"stone" and s50.count == 7, "slot 50 survives a JSON round trip in a 140-slot bag")
	# Legacy save: a bag already truncated to 10 rows and no identity fields.
	var legacy: Dictionary = rec.to_dict()
	legacy["bag"] = (legacy["bag"] as Array).slice(0, 10)
	for k in ["uid", "owner", "origin", "tamer", "tamed_at", "wild_level", "name", "parent_uids"]:
		legacy.erase(k)
	var old = PetRecordS.from_dict(_json_round(legacy))
	_expect(old.bag.slot_count == 140, "legacy 10-slot bag re-expands to 140 (got %d)" % old.bag.slot_count)
	_expect(old.uid != "", "legacy pet gets a uid on load")
	print("[t_tame] bag slots fresh=%d roundtrip=%d legacy=%d slot50=%s" % [rec.bag.slot_count, back.bag.slot_count, old.bag.slot_count, "stone x%d" % s50.count if s50 else "MISSING"])

func _test_growth_bounded() -> void:
	var rex = _def(&"tyrannosaurus")
	var worst_hp := 0.0
	var worst_atk := 0.0
	var max_gains: int = 3 * (int(PetStatsS.MAX_LEVEL) - 1)  # every level-up point in one stat
	var count := 0
	for id in _data().creatures:
		var def = _data().creatures[id]
		if not def.tameable:
			continue
		count += 1
		var ev: int = GeneticsS.EV_MAX_PER_STAT
		var hp1: float = PetStatsS.value(def, _perfect(&"health", 0, 0), 1, &"health")
		var hp60: float = PetStatsS.value(def, _perfect(&"health", max_gains, ev), 60, &"health")
		var atk1: float = PetStatsS.value(def, _perfect(&"melee_attack", 0, 0), 1, &"melee_attack")
		var atk60: float = PetStatsS.value(def, _perfect(&"melee_attack", max_gains, ev), 60, &"melee_attack")
		var ratk60: float = PetStatsS.value(def, _perfect(&"ranged_attack", max_gains, ev), 60, &"ranged_attack")
		worst_hp = maxf(worst_hp, hp60 / hp1)
		worst_atk = maxf(worst_atk, atk60 / atk1)
		_expect(hp60 <= 3.0 * hp1, "%s Lv60 HP %.0f > 3x Lv1 %.0f" % [id, hp60, hp1])
		_expect(atk60 <= 2.5 * atk1, "%s Lv60 attack %.0f > 2.5x Lv1 %.0f" % [id, atk60, atk1])
		_expect(hp60 <= rex.hp, "%s Lv60 HP %.0f exceeds wild T. rex %.0f" % [id, hp60, rex.hp])
		_expect(atk60 <= rex.attack and ratk60 <= rex.attack, "%s Lv60 attack %.0f exceeds wild T. rex %.0f" % [id, maxf(atk60, ratk60), rex.attack])
	_expect(count >= 16, "tameable species found (%d)" % count)
	print("[t_tame] growth species=%d worst Lv60/Lv1 hp=x%.2f attack=x%.2f (was x93.8 / x17.8) rex hp=%.0f atk=%.0f" % [count, worst_hp, worst_atk, rex.hp, rex.attack])

func _test_add_xp_and_train_match_compute() -> void:
	var raptor = _def(&"velociraptor")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rec = PetRecordS.from_def(raptor, &"", &"", GeneticsS.roll(rng), 1)
	var hp1: float = rec.hp
	var guard := 0
	while rec.level < 60 and guard < 10000:
		rec.add_xp(50.0)
		guard += 1
	_expect(rec.level == 60, "raptor reaches Lv60 (got %d)" % rec.level)
	var st: Dictionary = PetStatsS.compute(raptor, rec.genetics, rec.level)
	var exact: bool = rec.hp == st[&"health"] and rec.attack == st[&"melee_attack"] and rec.ranged_attack == st[&"ranged_attack"] \
		and rec.defense == st[&"melee_defense"] and rec.ranged_defense == st[&"ranged_defense"] \
		and rec.accuracy == st[&"accuracy"] and rec.speed == st[&"speed"]
	_expect(exact, "stats after add_xp equal PetStats.compute exactly")
	var gains := 0
	for v in rec.genetics.level_gains.values():
		gains += int(v)
	_expect(gains == 3 * 59, "59 level-ups grant 177 growth points (got %d)" % gains)
	# Level-up points count: zeroing them lowers the stat they went into.
	var top: StringName = &"health"
	for s in GeneticsS.STATS:
		if int(rec.genetics.level_gains[s]) > int(rec.genetics.level_gains[top]):
			top = s
	var no_gain = GeneticsS.from_dict(rec.genetics.to_dict())
	no_gain.level_gains[top] = 0
	_expect(PetStatsS.value(raptor, no_gain, 60, top) < PetStatsS.value(raptor, rec.genetics, 60, top), "level-up points raise %s" % top)
	var before: float = rec.attack
	var added: int = rec.train(&"melee_attack", 40)
	_expect(added == 40 and rec.attack > before, "train() raises the trained stat (%.1f -> %.1f)" % [before, rec.attack])
	_expect(rec.attack == PetStatsS.value(raptor, rec.genetics, 60, &"melee_attack"), "trained attack equals PetStats.compute")
	print("[t_tame] raptor lv=60 hp %.0f -> %.0f (x%.2f) attack trained %.1f -> %.1f" % [hp1, rec.hp, rec.hp / hp1, before, rec.attack])
	# A legacy save carrying the old compounded numbers is recomputed on load.
	var d: Dictionary = rec.to_dict()
	d["hp"] = 60295.0
	d["attack"] = 1675.0
	var loaded = PetRecordS.from_dict(_json_round(d))
	_expect(loaded.hp == PetStatsS.value(raptor, loaded.genetics, 60, &"health"), "load recomputes HP from PetStats (got %.0f)" % loaded.hp)

func _test_one_grade() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var def = _def(&"compsognathus")
	var bad := 0
	for i in 200:
		var g = GeneticsS.roll(rng)
		var rec = PetRecordS.from_def(def, &"S", &"", g, 1)  # the passed grade must be ignored
		var want: float = PetStatsS.grade_rate(g.overall_tier())
		if rec.grade != g.overall_tier() or rec.xp_rate != want or rec.hunger_efficiency != want:
			bad += 1
	_expect(bad == 0, "grade and rates follow genetics.overall_tier() (%d of 200 differ)" % bad)
	var low = _perfect(&"health", 0, 0)
	for s in GeneticsS.STATS:
		low.ivs[s] = 0
	var r = PetRecordS.from_def(def, &"S", &"", low, 1)
	_expect(r.grade == &"D-" and is_equal_approx(r.xp_rate, 0.85), "IV0 pet is D- with the low rate, not S (grade=%s xp_rate=%.2f)" % [r.grade, r.xp_rate])
	print("[t_tame] grade 200 random genetics mismatches=%d IV0 grade=%s xp_rate=%.2f" % [bad, r.grade, r.xp_rate])

func _test_identity() -> void:
	var def = _def(&"velociraptor")
	var seen := {}
	var bad_origin := 0
	for i in 1000:
		var rec = PetRecordS.from_def(def, &"", &"", null, 25)
		if i % 2 == 1:
			rec.origin = &"capture"  # the pen path sets this; field tames keep the default
		if rec.uid == "":
			continue
		seen[rec.uid] = true
		if not rec.origin in [&"tame", &"capture"]:
			bad_origin += 1
	_expect(seen.size() == 1000, "1000 tames give 1000 distinct non-empty uids (got %d)" % seen.size())
	_expect(bad_origin == 0, "every origin is tame or capture")
	var lv25 = PetRecordS.from_def(def, &"", &"", null, 25)
	var lv75 = PetRecordS.from_def(def, &"", &"", null, 75)
	_expect(lv25.level == 25 and lv25.wild_level == 25, "fresh tame keeps the wild level")
	_expect(lv75.level == 60 and lv75.wild_level == 60, "wild level is capped at 60 (got %d)" % lv75.level)
	lv25.tamer = "Milan"
	lv25.name = "Rex Jr"
	lv25.parent_uids.assign(["p_a", "p_b"])
	var back = PetRecordS.from_dict(_json_round(lv25.to_dict()))
	_expect(back.uid == lv25.uid and back.origin == lv25.origin and back.tamer == "Milan" and back.name == "Rex Jr" \
		and back.tamed_at == lv25.tamed_at and back.tamed_at > 0 and back.wild_level == 25 and back.parent_uids == lv25.parent_uids, "identity fields round-trip")
	print("[t_tame] uids distinct=%d/1000 sample=%s level wild25=%d wild75=%d" % [seen.size(), lv25.uid, lv25.level, lv75.level])

func _creature(id: StringName, hp_frac: float, knocked: bool):
	var cr = (load("res://scripts/creatures/creature.gd") as GDScript).new()
	cr.def = _def(id)
	cr.health = (load("res://scripts/combat/health.gd") as GDScript).new()
	cr.health.setup(cr.def.hp)
	cr.add_child(cr.health)
	cr.statuses = (load("res://scripts/combat/status_effects.gd") as GDScript).new()
	cr.add_child(cr.statuses)
	cr.health.hp = cr.def.hp * hp_frac
	cr.is_capturable = true
	if knocked:
		cr.statuses.apply(&"knockdown")
	return cr

func _test_rules() -> void:
	_expect(PetRecordS.RESPAWN_TIME == 180.0, "RESPAWN_TIME is 180 s (got %.0f)" % PetRecordS.RESPAWN_TIME)
	var half = _creature(&"velociraptor", 0.5, true)
	_expect(not CaptureS.attempt(null, half), "net refuses a creature at 50 % HP")
	half.free()
	_expect(not _data().has_capture_technique(5), "fresh survivor lacks Capture Technique 5")
	var cat = _creature(&"smilodon", 0.2, true)
	var inv = InventoryS.new(10)
	inv.add(ItemStackS.make(&"raw_meat", 3))
	var hint: Dictionary = FieldTameS.plate_hint(cat, inv)
	_expect(str(hint.get("text", "")) == "Needs Capture Technique 5", "smilodon plate hint names the technique (got '%s')" % str(hint.get("text", "")))
	_expect(FieldTameS.food_in_bag(inv, cat) == &"", "a locked smilodon accepts no food")
	_expect(FieldTameS.refuse_message(cat) == "Needs Capture Technique 5", "refusal names the technique")
	_data().set_survival_unlocked(&"capture_technique_V", true)
	_expect(FieldTameS.lock_reason(cat) == "" and FieldTameS.food_in_bag(inv, cat) == &"raw_meat", "Capture Technique V unlocks the smilodon")
	_data().set_survival_unlocked(&"capture_technique_V", false)
	cat.free()
	var comp = _creature(&"compsognathus", 0.2, true)
	_expect(FieldTameS.lock_reason(comp) == "", "tier-1 starter species needs no technique")
	comp.free()
	print("[t_tame] rules respawn=%.0f net@50%%=refused smilodon='%s'" % [PetRecordS.RESPAWN_TIME, str(hint.get("text", ""))])
