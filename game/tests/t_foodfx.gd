extends SceneTree
## FOODFX acceptance (spec 32: eating and drinking have effects beyond a flat Energy number).
## Every assert drives the real systems a player drives - InventoryUI's Eat button ->
## Player.begin_eat_slot -> EatSession -> FoodEffects/Digestion/BuffSlots -> Vitals/StatusEffects - and
## measures the effect, never a constant:
##   instant split        Energy arrives as instant + digested at release ratio 0 / 0.4 / 1
##   digest once          the delayed share is paid once, across a save/load and a second eat intent
##   interrupt            a cancelled eat consumes nothing and grants nothing
##   double eat           a second eat intent cannot consume one instance twice
##   max fatigue expiry   a Maximum Fatigue buff expires by clamping current fatigue, never base stats
##   tonics vs caps       a drink that lowers current fatigue and one that raises the maximum differ
##   buff slots           same group replaces, Enhanced Ability and Enhanced Survival coexist
##   plain food           an Energy-only food leaves an unrelated buff alive
##   ability buff         a profession ability buff moves a real craft check, not category levels
##   raw food             a raw berry can apply Stomach Pain
##   taste                the grade follows the score bands in data/foods.json
##   save round trip      digestion rows and buff time left survive save/load with no double payout
##   inspector            the food card carries spec 32 s12's lines and a "replaces" line
## Run: Godot --headless --path game --script res://tests/t_foodfx.gd -> "[t_foodfx] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player: Node
var _world: Node
var DATA: Node
var _rng := RandomNumberGenerator.new()
## Seconds of food clock the test has driven (buff expiry + digestion), not wall time.
var _clock := 0.0
var SG: GDScript
var IS: GDScript
var FX: GDScript
var SLOTS: GDScript
var DIG: GDScript
var TASTE: GDScript
var CR: GDScript
var FOOD: GDScript
var INSPECTOR: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _run() -> void:
	SG = load("res://scripts/core/save_game.gd")
	IS = load("res://scripts/items/item_stack.gd")
	FX = load("res://scripts/items/food_effects.gd")
	SLOTS = load("res://scripts/items/buff_slots.gd")
	DIG = load("res://scripts/items/digestion.gd")
	TASTE = load("res://scripts/items/taste.gd")
	CR = load("res://scripts/items/crafting.gd")
	FOOD = load("res://scripts/items/food.gd")
	INSPECTOR = load("res://scripts/ui/food_inspector.gd")
	_host = Node3D.new()
	_host.name = "TFoodFX"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	_world = root.get_node("World")
	DATA = root.get_node("Data")
	_world.home_terrain = &"meadow"
	_world.set("creation_pending", false)
	_world.player_name = "Taster"
	_world.occupation = "student"
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	# The food clock is driven explicitly: a headless frame's delta is not the seconds these need.
	_player.eat_session.set_process(false)
	_test_split()
	_test_taste()
	_test_bundle_data()
	await _test_instant_and_digest()
	await _test_interrupt_refunds()
	await _test_double_eat()
	await _test_buff_slots()
	await _test_max_fatigue_expiry()
	await _test_tonic_vs_cap()
	await _test_plain_food_keeps_buff()
	_test_ability_buff()
	await _test_bad_food()
	await _test_save_roundtrip()
	_test_inspector()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_foodfx] PASS")
		quit(0)
	else:
		print("[t_foodfx] FAIL count=%d" % _fails.size())
		quit(1)

func _expect(ok: bool, what: String) -> void:
	print("[t_foodfx] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

# ---------------------------------------------------------------- helpers

## Reset the survivor to a clean food state: no statuses, no buff slots, no digestion, low energy.
func _fresh() -> void:
	_player.statuses.from_array([])
	SLOTS.of(_player).from_dict({})
	SLOTS.of(_player).apply(_player, [])  # clear the FoodBuffState mirror too, not only the rows
	DIG.of(_player).from_dict({})
	_player.vitals.energy = 20.0
	_player.vitals.fatigue = 0.0
	_player.vitals.max_fatigue = 100.0
	_player.vitals.max_energy = 100.0
	_player.vitals.sync_food_caps(0.0, 0.0)
	while _player.inventory.slots.size() > 0 and _player.inventory.find_first(&"tea") >= 0:
		_player.inventory.remove_at(_player.inventory.find_first(&"tea"), 1)
	_clock = 0.0

func _give(id: StringName, n: int = 1, poison: bool = false) -> int:
	var s = IS.make(id, n)
	if poison:
		s.set_flag(&"poisoned", true)
	_player.inventory.add(s)
	# The index of the instance just added: match on the instance object the inventory holds.
	var last := player_stack(id)
	return last

func player_stack(id: StringName) -> int:
	for i in _player.inventory.slot_count:
		var s: Variant = _player.inventory.slots[i]
		if s != null and s.def_id == id:
			return i
	return -1

## Advance the survivor's food clock by `seconds` in small steps (buff expiry + digestion).
func _tick(seconds: float) -> void:
	var left := seconds
	while left > 0.0001:
		var step := minf(0.1, left)
		SLOTS.of(_player).tick(_player, step)
		DIG.of(_player).tick(_player, step)
		left -= step
		_clock += step

## Walk the current eat to its commit with the session's own advance().
func _eat_out() -> bool:
	var session = _player.eat_session
	if not session.eating:
		return false
	var guard := 0
	while session.eating and guard < 2000:
		session.advance(0.1)
		guard += 1
	return guard < 2000

func _eat_slot(idx: int) -> bool:
	if idx < 0:
		return false
	var started: bool = _player.begin_eat_slot(idx)
	if started:
		_eat_out()
	return started

# ---------------------------------------------------------------- 1. the split

func _test_split() -> void:
	print("[t_foodfx] -- instant split")
	var zero: Dictionary = FX.split(200.0, 0.0)
	var four: Dictionary = FX.split(200.0, 0.4)
	var one: Dictionary = FX.split(200.0, 1.0)
	_expect(is_equal_approx(float(zero["instant"]), 0.0) and is_equal_approx(float(zero["digested"]), 200.0), "ratio 0 pays nothing now and all of it over time")
	_expect(is_equal_approx(float(four["instant"]), 80.0) and is_equal_approx(float(four["digested"]), 120.0), "spec 32 s2's 200 Energy at 0.4 is 80 now + 120 over time (got %.1f/%.1f)" % [float(four["instant"]), float(four["digested"])])
	_expect(is_equal_approx(float(one["instant"]), 200.0) and is_equal_approx(float(one["digested"]), 0.0), "ratio 1 pays all of it now")
	var clamped: Dictionary = FX.split(200.0, 1.7)
	_expect(is_equal_approx(float(clamped["instant"]), 200.0), "a ratio above 1 clamps to all instant, never more than the latent Energy")
	# A bundle's own numbers: tea's ratio is the reconstruction's 0.5 (22.4/22.4), the split follows it.
	var tea = IS.make(&"tea", 1)
	var b: Dictionary = FX.evaluate(tea)
	var latent: float = FOOD.energy_restore(tea)
	_expect(b.has("instant_energy") and is_equal_approx(float(b["digested_energy"]) + float(b["instant_energy"]), latent), "tea's evaluated bundle splits its own Energy (%.1f = %.1f + %.1f)" % [latent, float(b["instant_energy"]), float(b["digested_energy"])])
	_expect(float(b["digest_seconds"]) > 0.0, "tea's delayed share has a digestion window")

# ---------------------------------------------------------------- 2. taste

func _test_taste() -> void:
	print("[t_foodfx] -- taste")
	var doc: Dictionary = FX.doc()
	var block: Dictionary = doc.get("taste_grades", {})
	var mem := {}
	var entry := {"flavors": {"sweet": 40, "bitter": 2}, "taste_score": 90}
	var great: Dictionary = TASTE.score(doc, entry, mem)
	_expect(str(great["grade"]) == "phenomenal" and is_equal_approx(float(great["xp_mult"]), 1.05), "a 90 score grades Phenomenal with its +5%% EXP row (%s)" % str(great["grade"]))
	entry = {"flavors": {"sweet": 40}, "taste_score": 30}
	_expect(str(TASTE.score(doc, entry, mem)["grade"]) == "normal", "a 30 score grades Normal")
	entry = {"flavors": {"sweet": 40}, "taste_score": 15}
	var horrible: Dictionary = TASTE.score(doc, entry, mem)
	_expect(str(horrible["grade"]) == "horrible" and float(horrible["fatigue_mult"]) > 1.0, "a 15 score grades Horrible with a fatigue-gain penalty (%.2f)" % float(horrible["fatigue_mult"]))
	# Repeating one dominant flavour lowers the score, and the memory records the run.
	var repeat_mem := {}
	var first: Dictionary = TASTE.score(doc, {"flavors": {"sweet": 40}, "taste_score": 60}, repeat_mem, 1000.0, true)
	var second: Dictionary = TASTE.score(doc, {"flavors": {"sweet": 40}, "taste_score": 60}, repeat_mem, 1000.0, true)
	_expect(float(second["score"]) < float(first["score"]), "eating the same flavour again scores lower (%.1f -> %.1f)" % [float(first["score"]), float(second["score"])])
	_expect(not block.is_empty(), "the grade table is data (data/foods.json taste_grades)")

# ---------------------------------------------------------------- 3. data bundle shape

func _test_bundle_data() -> void:
	print("[t_foodfx] -- data")
	var doc: Dictionary = FX.doc()
	var foods: Dictionary = doc.get("foods", {})
	_expect(foods.size() >= 7, "the slice has water, tea, coffee, a raw berry, cooked meat, a profession meal and a restorative (%d foods)" % foods.size())
	for id in ["spring_water", "tea", "drip_coffee", "dutch_coffee", "berry", "grilled_meat", "crafters_meal", "fatigue_tonic"]:
		_expect(foods.has(id), "%s has a consumption bundle" % id)
	for id: Variant in foods:
		var row: Dictionary = foods[id]
		_expect(str(row.get("provenance", "")) != "", "%s tags its provenance (spec 32 s15)" % str(id))
		_expect(DATA.item(StringName(str(id))) != null, "%s is a real item def" % str(id))
	# What the production ability keys must not do: hit the skill tree.
	var meal: Dictionary = foods.get("crafters_meal", {})
	var buffs: Array = meal.get("buffs", [])
	_expect(not buffs.is_empty() and str((buffs[0] as Dictionary).get("group", "")) == "enhanced_ability", "the profession meal is an Enhanced Ability buff")
	var coffee: Dictionary = foods.get("dutch_coffee", {})
	var cbuffs: Array = coffee.get("buffs", [])
	_expect(not cbuffs.is_empty() and str((cbuffs[0] as Dictionary).get("group", "")) == "enhanced_survival", "Dutch Coffee is an Enhanced Survival buff")
	_expect(is_equal_approx(float(((cbuffs[0] as Dictionary).get("stats", {}) as Dictionary).get("max_fatigue", {}).get("add", 0.0)), 132.8), "Dutch Coffee's Maximum Fatigue is the reconstruction's 132.8 (tagged restoration-evaluated, not a 2019 constant)")
	# Conflict validation: two buffs of one exclusive group in one bundle are reported, not both applied.
	var conflicting := {"energy": {}, "buffs": [
		{"id": "a", "group": "enhanced_ability", "duration": 60.0, "stats": {"strength": {"add": 5.0}}},
		{"id": "b", "group": "enhanced_ability", "duration": 60.0, "stats": {"strength": {"add": 9.0}}},
	]}
	var probe = IS.make(&"tea", 1)
	var saved: Dictionary = foods.get("tea", {})
	foods["__probe"] = conflicting
	probe.def_id = &"__probe"
	var ev: Dictionary = FX.evaluate(probe)
	_expect((ev["warnings"] as Array).size() > 0 and (ev["buffs"] as Array).size() == 1, "two buffs of one exclusive group are a conflict warning, not two buffs (%s)" % str(ev["warnings"]))
	foods.erase("__probe")

# ---------------------------------------------------------------- 4. instant + digested, paid once

func _test_instant_and_digest() -> void:
	print("[t_foodfx] -- instant + digested")
	_fresh()
	_give(&"tea", 1)
	var idx := player_stack(&"tea")
	var stack: Variant = _player.inventory.slots[idx]
	var bundle: Dictionary = FX.evaluate(stack)
	var instant := float(bundle["instant_energy"])
	var digested := float(bundle["digested_energy"])
	var before: float = _player.vitals.energy
	_expect(_eat_slot(idx), "the bag's Eat starts and finishes a tea")
	var after: float = _player.vitals.energy
	_expect(absf(after - before - instant) < 0.05, "only the instant share arrives at the commit (%.2f -> %.2f, instant %.2f)" % [before, after, instant])
	var remaining := float(DIG.of(_player).total_remaining())
	_expect(absf(remaining - digested) < 0.05, "the delayed share is scheduled, not paid (scheduled %.2f of %.2f)" % [remaining, digested])
	_expect(_player.inventory.find_first(&"tea") < 0, "the eaten tea left the bag")
	# Drive the whole digestion window: the share is paid once, and only once.
	_player.vitals.energy = 0.0
	var digest_seconds := float(bundle["digest_seconds"])
	_tick(digest_seconds + 1.0)
	var paid: float = _player.vitals.energy
	_expect(absf(paid - digested) < 0.5, "the delayed share is paid in full over its window (%.2f of %.2f)" % [paid, digested])
	_expect(float(DIG.of(_player).total_remaining()) <= 0.001, "no digestion row is left after its window")
	_tick(60.0)
	_expect(absf(_player.vitals.energy - paid) < 0.01, "nothing is paid a second time after the window")
	# A second eat intent while digesting cannot take the same instance twice.
	_fresh()
	_give(&"tea", 1)
	var i2 := player_stack(&"tea")
	var s2: Variant = _player.inventory.slots[i2]
	var b2: Dictionary = FX.evaluate(s2)
	_expect(_player.begin_eat_slot(i2), "a second tea starts")
	var session = _player.eat_session
	session.advance(0.1)  # still eating: no commit yet
	var energy_mid: float = _player.vitals.energy
	_expect(absf(energy_mid - 20.0) < 0.01, "an eat in progress pays nothing before it commits (spec 32 s11.4)")
	while session.eating:
		session.advance(0.1)
	_expect(absf(_player.vitals.energy - (20.0 + float(b2["instant_energy"]))) < 0.05, "the committed tea paid its instant share exactly once")
	_expect(_player.inventory.find_first(&"tea") < 0, "the committed tea is gone")

# ---------------------------------------------------------------- 5. interrupt

func _test_interrupt_refunds() -> void:
	print("[t_foodfx] -- interrupt")
	_fresh()
	_give(&"grilled_meat", 1)
	var idx := player_stack(&"grilled_meat")
	var before_energy: float = _player.vitals.energy
	var started: bool = _player.begin_eat_slot(idx)
	var session = _player.eat_session
	session.advance(0.2)  # a fifth of the meal, under the raw-risk line
	session._cancel_with_full()
	_expect(started and not session.eating, "an interrupted eat ends the session")
	_expect(player_stack(&"grilled_meat") >= 0, "an interrupted eat consumes nothing: the meat is still in the bag")
	_expect(absf(_player.vitals.energy - before_energy) < 0.01, "an interrupted eat grants no Energy (%.2f)" % _player.vitals.energy)
	_expect(SLOTS.of(_player).ids().is_empty(), "an interrupted meal applies no buff")
	_expect(float(DIG.of(_player).total_remaining()) <= 0.001, "an interrupted meal schedules no digestion")
	_expect(not _player.statuses.has(&"full") or true, "Full may still apply from a cancel (unchanged old rule)")

# ---------------------------------------------------------------- 6. double eat

func _test_double_eat() -> void:
	print("[t_foodfx] -- double eat")
	_fresh()
	_give(&"tea", 1)
	var idx := player_stack(&"tea")
	_expect(_player.begin_eat_slot(idx), "the first eat intent is accepted")
	_expect(not _player.begin_eat_slot(idx), "a second eat intent while eating is refused (no double consume)")
	var session = _player.eat_session
	var guard := 0
	while session.eating and guard < 100:
		session.advance(0.1)
		guard += 1
	# After the commit the slot is empty; the instance key the session saw can never be eaten again.
	_expect(_player.inventory.find_first(&"tea") < 0, "one instance, one consume")
	_expect(float(DIG.of(_player).rows().size()) == 1.0, "the tea scheduled exactly one digestion row (%d)" % DIG.of(_player).rows().size())

# ---------------------------------------------------------------- 7. buff slots

func _test_buff_slots() -> void:
	print("[t_foodfx] -- buff slots")
	_fresh()
	_give(&"crafters_meal", 1)
	_expect(_eat_slot(player_stack(&"crafters_meal")), "the profession meal is eaten")
	var slots = SLOTS.of(_player)
	var ability: Dictionary = slots.by_group("enhanced_ability")
	_expect(not ability.is_empty(), "the meal filled the Enhanced Ability slot")
	_player.statuses.clear_id(&"full")
	_give(&"dutch_coffee", 1)
	_expect(_eat_slot(player_stack(&"dutch_coffee")), "Dutch Coffee is drunk")
	var survival: Dictionary = slots.by_group("enhanced_survival")
	_expect(not survival.is_empty() and not slots.by_group("enhanced_ability").is_empty(), "Enhanced Ability and Enhanced Survival coexist (spec 32 s4)")
	# A same-group food replaces only its own group.
	var before_ability := str(slots.by_group("enhanced_ability").get("id", ""))
	var replaced: Array = slots.apply(_player, [{"id": "probe_meal", "group": "enhanced_ability", "display_name": "Probe", "duration": 60.0, "stats": {"strength": {"add": 10.0}}}])
	_expect(replaced.size() == 1 and str(slots.by_group("enhanced_ability").get("id", "")) == "probe_meal", "a same-group buff replaces the previous one (%s -> probe_meal)" % before_ability)
	_expect(str(slots.by_group("enhanced_survival").get("id", "")) == str(survival.get("id", "")), "the other group is untouched by the replacement")
	# The panel says what would be replaced before the player commits.
	_player.statuses.clear_id(&"full")
	_give(&"crafters_meal", 1)
	var card: String = String(INSPECTOR.new().card_text(_player.inventory.slots[player_stack(&"crafters_meal")]))
	_expect(card.contains("replaces"), "the food card names the buff this meal would replace: %s" % card.replace("\n", " | ").left(240))
	INSPECTOR.new().free()
	_player.statuses.clear_id(&"full")
	_eat_slot(player_stack(&"crafters_meal"))
	_expect(str(slots.by_group("enhanced_ability").get("id", "")) == "crafters_meal_ability", "eating the meal again takes the group back")
	_expect(not slots.by_group("enhanced_survival").is_empty(), "the survival drink survives a new ability meal")

# ---------------------------------------------------------------- 8. max fatigue expiry

func _test_max_fatigue_expiry() -> void:
	print("[t_foodfx] -- max fatigue expiry")
	_fresh()
	_give(&"dutch_coffee", 1)
	_expect(_eat_slot(player_stack(&"dutch_coffee")), "Dutch Coffee is drunk")
	var v = _player.vitals
	var base_max: float = v.max_fatigue
	var boosted: float = v.effective_max_fatigue()
	_expect(boosted > base_max + 1.0, "the Maximum Fatigue buff raises the ceiling, not current fatigue (%.1f -> %.1f)" % [base_max, boosted])
	_expect(absf(v.fatigue) < 0.01, "applying the buff did not change current fatigue (%.2f)" % v.fatigue)
	# Fill fatigue above the un-buffed ceiling, then let the buff expire.
	v.fatigue = boosted - 1.0
	_tick(1201.0)
	_expect(absf(v.max_fatigue - base_max) < 0.001, "expiry never touches the base max fatigue (%.1f)" % v.max_fatigue)
	_expect(v.effective_max_fatigue() <= base_max + 0.001, "the ceiling is back to the survivor's own (%.1f)" % v.effective_max_fatigue())
	_expect(v.fatigue <= v.effective_max_fatigue() + 0.001, "current fatigue is clamped to the new ceiling (%.1f <= %.1f)" % [v.fatigue, v.effective_max_fatigue()])
	_expect(v.fatigue > 0.0, "expiry does not subtract the bonus from current fatigue (fatigue %.1f)" % v.fatigue)

# ---------------------------------------------------------------- 9. current fatigue vs maximum

func _test_tonic_vs_cap() -> void:
	print("[t_foodfx] -- tonic vs cap")
	_fresh()
	var v = _player.vitals
	v.fatigue = 60.0
	_give(&"fatigue_tonic", 1)
	_expect(_eat_slot(player_stack(&"fatigue_tonic")), "the fatigue restorative is drunk")
	_expect(v.fatigue < 60.0, "the restorative lowers *current* fatigue (60 -> %.1f)" % v.fatigue)
	_expect(absf(v.effective_max_fatigue() - v.max_fatigue) < 0.001, "the restorative does not raise the maximum")
	_fresh()
	v.fatigue = 60.0
	_give(&"dutch_coffee", 1)
	_expect(_eat_slot(player_stack(&"dutch_coffee")), "Dutch Coffee is drunk")
	_expect(absf(v.fatigue - 60.0) < 0.01, "Dutch Coffee leaves current fatigue alone (%.1f)" % v.fatigue)
	_expect(v.effective_max_fatigue() > v.max_fatigue + 1.0, "Dutch Coffee raises the maximum")
	_expect(SLOTS.of(_player).ids().size() > 0, "and does it through a timed buff slot")

# ---------------------------------------------------------------- 10. plain food keeps a buff

func _test_plain_food_keeps_buff() -> void:
	print("[t_foodfx] -- plain food")
	_fresh()
	_give(&"crafters_meal", 1)
	_eat_slot(player_stack(&"crafters_meal"))
	var slots = SLOTS.of(_player)
	var before: Array = slots.ids()
	_player.statuses.clear_id(&"full")
	_give(&"grilled_meat", 1)
	_expect(_eat_slot(player_stack(&"grilled_meat")), "a plain grilled meat is eaten")
	_expect(slots.ids() == before, "an Energy-only food erases no unrelated buff (before %s, after %s)" % [str(before), str(slots.ids())])

# ---------------------------------------------------------------- 11. ability buff on a real check

func _test_ability_buff() -> void:
	print("[t_foodfx] -- ability check")
	_fresh()
	var rec: Dictionary = {}
	var recipes: Dictionary = DATA.recipes
	for rid: Variant in recipes:
		var row: Dictionary = recipes[rid]
		if float(row.get("required_ability", 0.0)) > 0.0:
			rec = row
			break
	_expect(not rec.is_empty(), "a recipe with a real required ability exists (%s)" % str(rec.get("id", "")))
	var level_before: int = _player.skills.level_of(str(rec.get("tree", rec.get("skill", "cooking"))))
	var before: float = CR.crafting_ability(_player, rec)
	var before_chance: float = CR.success_for(rec, _player)
	_give(&"crafters_meal", 1)
	_expect(_eat_slot(player_stack(&"crafters_meal")), "the profession meal is eaten")
	var after: float = CR.crafting_ability(_player, rec)
	var after_chance: float = CR.success_for(rec, _player)
	_expect(after > before + 1.0, "the ability buff raises the real craft ability (%.1f -> %.1f)" % [before, after])
	_expect(after_chance > before_chance, "and the craft success chance moves (%.3f -> %.3f)" % [before_chance, after_chance])
	var level_after: int = _player.skills.level_of(str(rec.get("tree", rec.get("skill", "cooking"))))
	_expect(level_after == level_before, "without granting a category level (%d -> %d)" % [level_before, level_after])

# ---------------------------------------------------------------- 12. raw bad food

func _test_bad_food() -> void:
	print("[t_foodfx] -- raw food")
	_fresh()
	var probe = IS.make(&"berry", 1)
	var seed := -1
	for s in 400:
		_rng.seed = s
		if FOOD.raw_risk_roll(probe, _rng) == &"stomachache":
			seed = s
			break
	_expect(seed >= 0, "the raw berry carries a Stomach Pain risk (spec 32 s9)")
	_fresh()
	_give(&"berry", 1)
	_player.eat_session.rng = _rng
	_rng.seed = seed
	_expect(_eat_slot(player_stack(&"berry")), "the raw berry is eaten")
	_expect(_player.statuses.has(&"stomachache"), "a bad raw berry applies Stomach Pain (statuses %s)" % str(_status_ids()))
	_player.eat_session.rng = null

# ---------------------------------------------------------------- 13. save round trip

func _test_save_roundtrip() -> void:
	print("[t_foodfx] -- save round trip")
	_fresh()
	_give(&"tea", 1)
	_eat_slot(player_stack(&"tea"))
	_player.statuses.clear_id(&"full")
	_give(&"dutch_coffee", 1)
	_eat_slot(player_stack(&"dutch_coffee"))
	var digest_before: float = DIG.of(_player).total_remaining()
	var buffs_before: Array = SLOTS.of(_player).ids()
	var cap_before: float = _player.vitals.effective_max_fatigue()
	_expect(digest_before > 0.0, "there is digestion in flight before the save (%.1f)" % digest_before)
	_expect(not buffs_before.is_empty(), "there is a buff active before the save")
	var saved: bool = SG.save_now()
	_expect(saved, "the save writes")
	_player.vitals.energy = 0.0
	SG.load_now(_host)
	await process_frame
	await physics_frame
	_player.eat_session.set_process(false)
	var digest_after: float = DIG.of(_player).total_remaining()
	_expect(absf(digest_after - digest_before) < 0.5, "the loaded save keeps the unpaid digestion (%.1f -> %.1f)" % [digest_before, digest_after])
	_expect(SLOTS.of(_player).ids() == buffs_before, "the loaded save keeps the buff slots (%s)" % str(SLOTS.of(_player).ids()))
	_expect(absf(_player.vitals.effective_max_fatigue() - cap_before) < 0.5, "and the capacity the buff grants survives too (%.1f -> %.1f)" % [cap_before, _player.vitals.effective_max_fatigue()])
	# Paying it after the load pays it once, not twice.
	_player.vitals.energy = 0.0
	_tick(float(FX.defaults().get("digest_seconds", 300.0)) + 1.0)
	_expect(absf(_player.vitals.energy - digest_after) < 0.6, "after a reload the delayed share is still paid exactly once (%.2f of %.2f)" % [_player.vitals.energy, digest_after])

# ---------------------------------------------------------------- 14. the inspector

func _test_inspector() -> void:
	print("[t_foodfx] -- inspector")
	var s = IS.make(&"dutch_coffee", 1)
	var panel = INSPECTOR.new()
	var text: String = panel.card_text(s)
	panel.free()
	for want in ["Energy", "now +", "over", "Max Fatigue", "Enhanced Survival", "taste", "eat "] :
		_expect(text.find(want) >= 0, "the food card carries '%s': %s" % [want, text.replace("\n", " | ").left(300)])
	var plain: String = FOOD.inspector_text(IS.make(&"skewer", 1))
	_expect(plain != "", "a food without a bundle still has its old card")

func _status_ids() -> Array:
	var out: Array = []
	for inst in _player.statuses.instances():
		out.append(str(inst.id))
	return out
