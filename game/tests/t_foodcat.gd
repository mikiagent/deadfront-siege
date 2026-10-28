extends SceneTree
## FOODCAT acceptance: the owner's fan-guide catalog (docs/reference/durango-food-catalog-level60.csv,
## level-60 figures) mapped onto this build's foods through FOODFX's one effect bundle.
##   mapping invariants  every mapped food names a real catalog row; its Energy at level 60 is the
##                       catalog's instant + digestion total, its release ratio and fullness are the
##                       catalog's; every status/stat it names exists; new foods have a recipe + icon
##   effect types        each catalog effect type, eaten through the bag's real Eat path
##                       (Player.begin_eat_slot -> EatSession -> FoodEffects -> Vitals/StatusEffects/BuffSlots):
##                       stat buff, Stomach Pain Lv, Poisoned Lv, Hot Food Lv, Cold Food, Vigor Lv,
##                       Thirst Lv, Quenches thirst / Water, Fatigue -N / +N, Health +N, Fullness
## Run: Godot --headless --path game --script res://tests/t_foodcat.gd -> "[t_foodcat] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const CATALOG := "../docs/reference/durango-food-catalog-level60.csv"

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player: Node
var DATA: Node
var IS: GDScript
var FX: GDScript
var SLOTS: GDScript
var DIG: GDScript
var FOOD: GDScript
var _catalog := {}

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _run() -> void:
	IS = load("res://scripts/items/item_stack.gd")
	FX = load("res://scripts/items/food_effects.gd")
	SLOTS = load("res://scripts/items/buff_slots.gd")
	DIG = load("res://scripts/items/digestion.gd")
	FOOD = load("res://scripts/items/food.gd")
	DATA = root.get_node("Data")
	_load_catalog()
	_test_mapping()
	_host = Node3D.new()
	_host.name = "TFoodCat"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	var world: Node = root.get_node("World")
	world.home_terrain = &"meadow"
	world.set("creation_pending", false)
	world.player_name = "Taster"
	world.occupation = "student"
	world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	var frames := 0
	while _player.eat_session == null and frames < 240:
		await process_frame
		frames += 1
	if _player.eat_session == null:
		_expect(false, "the player creates an EatSession")
		_finish()
		return
	_player.eat_session.set_process(false)
	_test_level_scaling()
	_test_stat_buff()
	_test_stomach_pain()
	_test_poisoned()
	_test_hot_food()
	_test_cold_food()
	_test_vigor_and_thirst_status()
	_test_quench()
	_test_fatigue()
	_test_health()
	_test_fullness()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_foodcat] PASS")
		quit(0)
	else:
		print("[t_foodcat] FAIL count=%d" % _fails.size())
		for f in _fails:
			print("[t_foodcat] FAIL %s" % f)
		quit(1)

func _expect(ok: bool, what: String) -> void:
	print("[t_foodcat] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

# ---------------------------------------------------------------- catalog

func _load_catalog() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join(CATALOG)
	var f := FileAccess.open(path, FileAccess.READ)
	_expect(f != null, "the owner's catalog is in the repo (%s)" % path)
	if f == null:
		return
	var head := f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() != head.size():
			continue
		var d := {}
		for i in head.size():
			d[head[i]] = row[i]
		_catalog[d["Game ID"]] = d
	_expect(_catalog.size() >= 250, "the catalog has its 254 rows (%d)" % _catalog.size())

# ---------------------------------------------------------------- 1. mapping invariants

func _test_mapping() -> void:
	print("[t_foodcat] -- mapping")
	var foods: Dictionary = FX.doc().get("foods", {})
	var stat_keys: Dictionary = FX.stat_keys()
	var scale: Dictionary = FX.doc().get("catalog_scale", {})
	var ek := float(scale.get("energy_k", 0.0))
	_expect(ek > 0.0 and ek < 1.0, "the catalog's Energy is normalised by one factor energy_k (%.4f), not imported raw" % ek)
	var mapped := 0
	var kept_energy := 0
	for id: String in foods:
		var e: Dictionary = foods[id]
		var c: Variant = e.get("catalog")
		if not c is Dictionary:
			continue
		mapped += 1
		var gid := str((c as Dictionary).get("game_id", ""))
		_expect(_catalog.has(gid), "%s names a real catalog row (%s)" % [id, gid])
		if not _catalog.has(gid):
			continue
		var row: Dictionary = _catalog[gid]
		var inst := float(row["Instant energy L60"])
		var total := inst + float(row["Digestion energy L60"])
		var def: ItemDef = DATA.item(StringName(id))
		_expect(def != null, "%s is a real item" % id)
		if def == null:
			continue
		var kept := str((c as Dictionary).get("energy_kept", ""))
		if kept != "":
			# An existing tested design rule outranks the catalog's Energy; the row must say which.
			_expect(kept.contains("NOT mapped") and (kept.contains("t_process") or kept.contains("run_all")), "%s documents why its Energy is not the catalog's: %s" % [id, kept])
			kept_energy += 1
		else:
			_expect(absf(def.food_energy_at(60) - total * ek) < 0.01, "%s at level 60 restores the catalog's %.1f x energy_k = %.2f (%.2f)" % [id, total, total * ek, def.food_energy_at(60)])
		if total > 0.0:
			var ratio := float((e.get("energy", {}) as Dictionary).get("instant_release_ratio", -1.0))
			_expect(absf(ratio - inst / total) < 0.001, "%s releases the catalog's instant share %.3f (%.3f)" % [id, inst / total, ratio])
		_expect(is_equal_approx(float(e.get("fullness", -1.0)), float(row["Fullness"])), "%s fullness is the catalog's %s" % [id, row["Fullness"]])
		_expect(str(e.get("provenance", "")) == "restoration-evaluated", "%s is tagged restoration-evaluated, not an original constant" % id)
		_expect(str(e.get("assumption", "")).contains("FOODCAT") and str(e.get("assumption", "")).contains(gid), "%s's note names its catalog source row" % id)
		for s: Variant in e.get("statuses", []):
			var sid := str((s as Dictionary).get("id", ""))
			_expect(DATA.status(StringName(sid)) != null, "%s's status %s exists" % [id, sid])
		if e.has("risk_status"):
			_expect(DATA.status(StringName(str(e["risk_status"]))) != null, "%s's raw-bite status %s exists" % [id, e["risk_status"]])
		for b: Variant in e.get("buffs", []):
			for k: Variant in ((b as Dictionary).get("stats", {}) as Dictionary):
				_expect(stat_keys.has(str(k)), "%s's buff stat %s is one of spec 32's keys" % [id, k])
		var lvl := int(e.get("temperature_level", 1))
		if str(e.get("temperature", "")) != "":
			var sdef: StatusDef = DATA.status(&"hot_food" if str(e["temperature"]) == "hot" else &"cold_food")
			_expect(sdef != null and lvl <= sdef.max_stacks, "%s's temperature level %d fits the status" % [id, lvl])
	_expect(mapped >= 30, "the existing foods and the new slice carry a catalog row (%d)" % mapped)
	_expect(kept_energy <= 1, "only camp_stew keeps its old Energy (%d)" % kept_energy)
	var icons: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/icons_manifest.json"))
	var recipes: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json")) as Dictionary).get("recipes", [])
	for id in ["fruit_juice", "cactus_juice", "meat_broth", "salad", "herbal_tea", "shaved_ice"]:
		_expect(DATA.item(StringName(id)) != null and foods.has(id), "new food %s is an item with a bundle" % id)
		_expect((icons.get("icons", {}) as Dictionary).has(id) or (icons.get("aliases", {}) as Dictionary).has(id), "new food %s has an icon" % id)
		_expect(recipes.any(func(r: Dictionary) -> bool: return str(r.get("output", {}).get("id", "")) == id), "new food %s has a recipe" % id)

# ---------------------------------------------------------------- helpers

func _fresh() -> void:
	_player.statuses.from_array([])
	SLOTS.of(_player).restore(_player, {})
	DIG.of(_player).from_dict({})
	var v = _player.vitals
	v.max_energy = 100.0
	v.max_fatigue = 100.0
	v.sync_food_caps(0.0, 0.0)
	v.energy = 10.0
	v.fatigue = 0.0
	v.health = v.effective_max_health()

func _eat(id: StringName, poisoned := false, level := 1) -> bool:
	var s = IS.make(id, 1)
	s.level = level
	if poisoned:
		s.set_flag(&"poisoned", true)
	_player.inventory.add(s)
	var idx: int = _player.inventory.find_first(id)  # add() may store a copy: find it by id
	if idx < 0 or not _player.begin_eat_slot(idx):
		return false
	var session = _player.eat_session
	var guard := 0
	while session.eating and guard < 2000:
		session.advance(0.1)
		guard += 1
	return not session.eating

func _fk() -> float:
	return float((FX.doc().get("catalog_scale", {}) as Dictionary).get("fatigue_k", 0.0))

func _stacks(id: StringName) -> int:
	var inst = _player.statuses.get_instance(id)
	return inst.stacks if inst != null else 0

## Run `body` with foods.json's entry for `id` temporarily replaced by `entry` (a probe bundle on a
## real, edible item), then restore it.
func _with_entry(id: String, entry: Dictionary, body: Callable) -> void:
	var foods: Dictionary = FX.doc()["foods"]
	var saved: Dictionary = foods[id]
	foods[id] = entry
	body.call()
	foods[id] = saved

# ---------------------------------------------------------------- 2. effect types, end to end

func _test_level_scaling() -> void:
	print("[t_foodcat] -- level scaling")
	var k := float((FX.doc().get("catalog_scale", {}) as Dictionary).get("energy_k", 0.0))
	var s = IS.make(&"raw_meat", 1)
	s.level = 60
	_expect(absf(FOOD.energy_restore(s) - 163.3 * k) < 0.01, "a level-60 raw meat restores the catalog's (40.8 + 122.5) x energy_k (%.2f)" % FOOD.energy_restore(s))
	var b: Dictionary = FX.evaluate(s)
	_expect(absf(float(b["instant_energy"]) - 40.8 * k) < 0.01 and absf(float(b["digested_energy"]) - 122.5 * k) < 0.01, "and keeps the catalog's split shape (%.2f / %.2f)" % [float(b["instant_energy"]), float(b["digested_energy"])])
	# Normalised, not imported: a level-1 raw meat stays near today's 12 Energy, and pet feed fills
	# a pet within 20 % of what it did before FOODCAT (Food.feed_pet: Energy x 10; base 15 / 12 Energy).
	var raw1 = IS.make(&"raw_meat", 1)
	_expect(absf(FOOD.energy_restore(raw1) - 12.0) / 12.0 <= 0.1, "a level-1 raw meat stays near its pre-FOODCAT 12 Energy (%.2f)" % FOOD.energy_restore(raw1))
	for row in [[&"carnivore_feed", 150.0], [&"herbivore_feed", 120.0]]:
		var fill: float = FOOD.energy_restore(IS.make(row[0], 1)) * 10.0
		_expect(absf(fill - float(row[1])) / float(row[1]) <= 0.2, "%s fills a pet %.1f, within 20%% of its pre-FOODCAT %.0f" % [row[0], fill, row[1]])

func _test_stat_buff() -> void:
	print("[t_foodcat] -- stat buff")
	_fresh()
	_expect(_eat(&"meatball"), "a meatball is eaten")
	var row: Dictionary = SLOTS.of(_player).by_group("enhanced_ability")
	var add := float(((row.get("stats", {}) as Dictionary).get("strength", {}) as Dictionary).get("add", 0.0))
	_expect(is_equal_approx(add, 20.9), "it fills Enhanced Ability with the catalog's Strength +20.9 (%.1f)" % add)
	_fresh()
	_expect(_eat(&"roast"), "a roast is eaten")
	var stats: Dictionary = SLOTS.of(_player).by_group("enhanced_ability").get("stats", {})
	_expect(stats.has("strength") and stats.has("defense"), "a roast carries Strength and Defense (Sirloin Steak) %s" % str(stats.keys()))

func _test_stomach_pain() -> void:
	print("[t_foodcat] -- stomach pain")
	_fresh()
	_expect(_eat(&"raw_meat", true), "a bad raw meat is eaten")
	_expect(_stacks(&"stomachache") == 1, "it applies Stomach Pain Lv1 (stacks %d)" % _stacks(&"stomachache"))

func _test_poisoned() -> void:
	print("[t_foodcat] -- poisoned")
	_fresh()
	_expect(_eat(&"mushroom", true), "a bad raw mushroom is eaten")
	_expect(_stacks(&"poisoned") == 4, "it applies Poisoned Lv4, not Stomach Pain (stacks %d)" % _stacks(&"poisoned"))
	_expect(not _player.statuses.has(&"stomachache"), "and no Stomach Pain")
	var before: float = _player.vitals.health
	_player.statuses._dot(_player.statuses.get_instance(&"poisoned"))
	_expect(_player.vitals.health < before, "Poisoned hurts over time (%.2f -> %.2f)" % [before, _player.vitals.health])

func _test_hot_food() -> void:
	print("[t_foodcat] -- hot food")
	_fresh()
	_expect(_eat(&"roast"), "a roast is eaten")
	_expect(_stacks(&"hot_food") == 3, "it applies Hot Food Lv3 (stacks %d)" % _stacks(&"hot_food"))
	_player.statuses.clear_id(&"full")
	_expect(_eat(&"boiled_meat"), "a boiled meat is eaten after it")
	_expect(_stacks(&"hot_food") == 3, "a Lv1 hot meal never lowers or adds to Lv3 (stacks %d)" % _stacks(&"hot_food"))

func _test_cold_food() -> void:
	print("[t_foodcat] -- cold food")
	_fresh()
	_expect(_eat(&"shaved_ice"), "shaved ice is eaten")
	_expect(_stacks(&"cold_food") == 1, "it applies Cold Food (stacks %d)" % _stacks(&"cold_food"))

func _test_vigor_and_thirst_status() -> void:
	print("[t_foodcat] -- vigor + thirst")
	_fresh()
	var probe: Dictionary = (FX.doc()["foods"]["salad"] as Dictionary).duplicate(true)
	probe["buffs"] = []
	probe["statuses"] = [{"id": "vigor", "duration": 600.0, "level": 2}, {"id": "thirsty", "duration": 0.0}]
	_with_entry("salad", probe, func() -> void:
		_expect(_eat(&"salad"), "a probe meal carrying 'Vigor Lv2' and 'Thirst Lv1' is eaten")
		_expect(_stacks(&"vigor") == 2, "Vigor Lv2 lands as two stacks (%d)" % _stacks(&"vigor"))
		_expect(_player.statuses.has(&"thirsty"), "'Thirst Lv1' makes the survivor Thirsty"))

func _test_quench() -> void:
	print("[t_foodcat] -- quench")
	_fresh()
	_player.statuses.apply(&"thirsty", _player)
	_expect(_eat(&"fruit_juice"), "a fruit juice is drunk")
	_expect(not _player.statuses.has(&"thirsty") and _player.statuses.has(&"quenched"), "'Quenches thirst' clears Thirsty and grants Quenched")
	_fresh()
	_player.statuses.apply(&"thirsty", _player)
	_expect(_eat(&"meat_broth"), "a meat broth is drunk")
	_expect(not _player.statuses.has(&"thirsty"), "'Water Lv1' clears Thirsty too")

func _test_fatigue() -> void:
	print("[t_foodcat] -- fatigue")
	_fresh()
	_player.vitals.fatigue = 80.0
	_expect(_eat(&"fatigue_tonic"), "the Fatigue Restorative is drunk")
	_expect(is_equal_approx(float(_player.eat_session.last_paid.get("fatigue", 0.0)), -300.0 * _fk()), "it pays the catalog's Fatigue -300 x fatigue_k (%.1f)" % float(_player.eat_session.last_paid.get("fatigue", 0.0)))
	_expect(_player.vitals.fatigue < 0.01, "current fatigue drops to the floor (%.1f)" % _player.vitals.fatigue)
	_fresh()
	_expect(_eat(&"carnivore_feed"), "carnivore feed is eaten by the survivor")
	_expect(_player.vitals.fatigue > 0.0 and _player.vitals.fatigue < _player.vitals.effective_max_fatigue(), "the catalog's Fatigue +130 x fatigue_k adds fatigue without filling the bar (%.1f)" % _player.vitals.fatigue)

func _test_health() -> void:
	print("[t_foodcat] -- health")
	_fresh()
	var v = _player.vitals
	v.health = v.effective_max_health() - 80.0
	var before: float = v.health
	_expect(_eat(&"herbal_tea"), "a herbal tea is drunk")
	var hk := float((FX.doc().get("catalog_scale", {}) as Dictionary).get("health_k", 0.0))
	_expect(absf(v.health - before - 50.4 * hk) < 0.05, "it heals the catalog's Health +50.4 x health_k (%.1f -> %.1f)" % [before, v.health])

func _test_fullness() -> void:
	print("[t_foodcat] -- fullness")
	_fresh()
	_expect(_eat(&"roast"), "a roast is eaten")
	_expect(is_equal_approx(float(_player.eat_session.last_paid.get("fullness", 0.0)), 50.0), "the meal pays the catalog's Fullness 50 (%.1f)" % float(_player.eat_session.last_paid.get("fullness", 0.0)))
	_expect(_player.statuses.has(&"full"), "and leaves the survivor Full")
