extends SceneTree

var failures: Array[String] = []
var _capture_done := false

func _init() -> void:
	_test_save_migrations()
	_test_food_buffs()
	_test_exhaustion()
	_test_climate_palette()
	_test_creature_genetics()
	_test_progression_scaling()
	_test_starter_island_levels_and_resource_stacks()
	_test_hud_event_state()
	_test_ui_tokens()

## FieldTame references the Data autoload. `godot --script` compiles this file before
## singletons exist, so the capture checks load that class on the first frame.
func _process(_delta: float) -> bool:
	if _capture_done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_capture_done = true
	_test_tyrant_counters()
	_test_catapult_recipe_save()
	_test_slingshot_recipe()
	_test_trap_control()
	_test_counter_supplies()
	_test_combat_counters()
	_test_capture_threshold()
	_test_sleep_building_save()
	_test_staged_sleep_tiers()
	_test_save_with_craft_stations()
	_test_dried_meat_recipe()
	_test_crock_pot_recipe_and_kit()
	_test_stone_fire_pit()
	_test_temporary_campfire()
	_test_flat_stone_grill()
	_test_smoker()
	_test_mortar_well_kit_routes()
	_test_empty_bucket_recipe()
	_test_multistack_crafting()
	_finish()
	return true

func _finish() -> void:
	if failures.is_empty():
		print("[tests] PASS")
		quit(0)
		return
	for failure in failures:
		push_error("[tests] %s" % failure)
	print("[tests] FAIL count=%d" % failures.size())
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _fixture(name: String) -> Dictionary:
	var file := FileAccess.open("res://tests/fixtures/%s" % name, FileAccess.READ)
	_expect(file != null, "fixture missing: %s" % name)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "fixture is not a dictionary: %s" % name)
	return parsed as Dictionary if parsed is Dictionary else {}

func _test_save_migrations() -> void:
	var v0 := SaveMigrations.migrate(_fixture("save_v0.json"))
	_expect(int(v0.get("schema", -1)) == SaveMigrations.CURRENT_SCHEMA, "v0 reaches current schema")
	_expect(v0.get("player", {}).has("inventory_extras"), "v0 gains inventory extras")
	_expect(v0.get("home", {}).has("camp_layout"), "v0 gains camp layout")
	_expect(v0.get("home", {}).get("buildings", []).size() == 1, "v0 preserves buildings")

	var v2 := SaveMigrations.migrate(_fixture("save_v2.json"))
	_expect(int(v2.get("schema", -1)) == SaveMigrations.CURRENT_SCHEMA, "v2 reaches current schema")
	_expect(v2.get("player", {}).get("inventory_extras", null) is Dictionary, "v2 inventory extras is dictionary")
	_expect(v2.get("home", {}).get("camp_layout", null) is Dictionary, "v2 camp layout is dictionary")

	var future := SaveMigrations.migrate({"schema": SaveMigrations.CURRENT_SCHEMA + 1})
	_expect(future.is_empty(), "future schemas are rejected rather than misread")

func _test_food_buffs() -> void:
	var buffs := FoodBuffState.new()
	buffs.apply(&"stew", {"duration": 2.0, "stat": "damage", "mult": 1.25})
	buffs.apply(&"tea", {"duration": 4.0, "stat": "damage", "mult": 1.2})
	_expect(is_equal_approx(buffs.multiplier("damage"), 1.5), "food buff multipliers stack")
	buffs.tick(2.1)
	_expect(is_equal_approx(buffs.multiplier("damage"), 1.2), "expired food buff is removed")

func _test_sleep_building_save() -> void:
	var script := load("res://scripts/world/placed_building.gd") as GDScript
	var roll: Node = script.make(&"straw_roll")
	_expect(int(roll.get("sleeps_left")) == 1, "straw roll starts with one sleep")
	_expect(is_equal_approx(roll.sleep_restore(), 65.0), "straw roll restores less than tent")
	var tent: Node = script.make(&"tent")
	_expect(int(tent.get("sleeps_left")) == 6, "tent starts with six sleeps")
	get_root().add_child(tent)
	tent.complete_sleep()
	var saved: Dictionary = tent.to_dict()
	var restored: Node = script.from_dict(saved)
	_expect(int(restored.get("sleeps_left")) == 5, "remaining tent uses survive save/load")
	var canvas: Node = script.make(&"canvas_tent")
	_expect(int(canvas.get("sleeps_left")) == 12 and is_equal_approx(canvas.sleep_duration(), 8.0), "canvas tent starts with twelve faster sleeps")
	get_root().add_child(canvas)
	canvas.complete_sleep()
	var canvas_saved: Dictionary = canvas.to_dict()
	var canvas_restored: Node = script.from_dict(canvas_saved)
	_expect(int(canvas_restored.get("sleeps_left")) == 11, "canvas tent uses survive save/load")
	var canvas_old: Node = script.from_dict({"kind": "canvas_tent"})
	_expect(int(canvas_old.get("sleeps_left")) == 12, "canvas tent saves without uses start full")
	var canvas_kit: ItemDef = get_root().get_node("Data").call("item", &"canvas_tent_kit")
	_expect(canvas_kit != null and canvas_kit.place_as == &"canvas_tent" and canvas_kit.footprint == Vector2i(3, 3), "canvas tent kit places at three by three")
	canvas.queue_free()
	canvas_restored.free()
	canvas_old.free()
	var old: Node = script.from_dict({"kind": "tent"})
	_expect(int(old.get("sleeps_left")) == 6, "legacy tent saves start at six uses")
	roll.free()
	tent.queue_free()
	restored.free()
	old.free()

func _test_staged_sleep_tiers() -> void:
	var data: Node = get_root().get_node("Data")
	var script := load("res://scripts/world/placed_building.gd") as GDScript
	var placer: Node = (load("res://scripts/world/build_placer.gd") as GDScript).new()
	for row in [
		{"kind": &"log_shelter", "kit": &"log_shelter_kit", "footprint": Vector2i(4, 4), "seconds": 7.0, "costs": [8, 6, 3]},
		{"kind": &"cabin_bed", "kit": &"cabin_bed_kit", "footprint": Vector2i(2, 2), "seconds": 5.0, "costs": [6, 4, 2]},
	]:
		var kit: ItemDef = data.call("item", row["kit"])
		_expect(kit != null and kit.place_as == row["kind"] and kit.footprint == row["footprint"], "%s catalog and footprint" % row["kind"])
		_expect(placer.call("_kit_id", row["kind"]) == str(row["kit"]), "%s placement routes to kit" % row["kind"])
		var building: Node = script.make(row["kind"])
		_expect(is_equal_approx(building.sleep_duration(), row["seconds"]), "%s intended duration is staged" % row["kind"])
		get_root().add_child(building)
		_expect(not building.is_in_group("sleep_spot"), "%s cannot sleep without prerequisite" % row["kind"])
		_expect(not data.get("recipes").has(row["kit"]), "%s cannot consume resources via crafting" % row["kind"])
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json"))
		var found := false
		for recipe in catalog.get("recipes", []):
			if recipe.get("id", "") == str(row["kit"]):
				found = true
				_expect(recipe.get("implementation_status", "") == "staged", "%s recipe flagged staged" % row["kind"])
				for i in 3:
					_expect(int(recipe["slots"][i].get("count", -1)) == row["costs"][i], "%s recipe input %d" % [row["kind"], i])
		_expect(found, "%s staged recipe is recorded" % row["kind"])
		building.queue_free()
	placer.free()

func _test_save_with_craft_stations() -> void:
	# Newly craftable stations have no is_cargo field. Autosave must not cast null to bool.
	var station_script := load("res://scripts/world/craft_station.gd") as GDScript
	var st: Node = station_script.make(&"smoker")
	_expect(st.get("is_cargo") == null and st.persist_building, "craft station persists without is_cargo property")
	_expect(st.get("is_cargo") != true, "missing cargo flag is not cargo")
	st.free()

func _test_dried_meat_recipe() -> void:
	var data: Node = get_root().get_node("Data")
	var rec: Dictionary = data.get("recipes").get(&"dry_meat", {})
	_expect(str(rec.get("station", "")) == "drying_rack", "dried meat uses placed rack")
	_expect(is_equal_approx(float(rec.get("seconds", 0.0)), 8.0), "drying requires eight seconds")
	_expect(str(rec.get("slots", [{}])[0].get("category", "")) == "raw_meat", "drying accepts raw meat category")
	for raw_id in [&"raw_meat", &"fish", &"raptor_meat"]:
		var item: ItemDef = data.call("item", raw_id)
		_expect(item != null and item.has_category(&"raw_meat"), "%s can dry" % raw_id)
	var cooked: ItemDef = data.call("item", &"skewer")
	_expect(cooked != null and not cooked.has_category(&"raw_meat"), "cooked meat cannot dry again")
	var dried: ItemDef = data.call("item", &"dried_meat")
	_expect(dried != null and dried.has_category(&"food") and not dried.raw and dried.food_energy > 0.0, "drying outputs edible preserved meat")
	var kit: Dictionary = data.get("recipes").get(&"drying_rack_kit", {})
	_expect(int(kit.get("slots", [])[0].get("count", 0)) == 4 and int(kit.get("slots", [])[1].get("count", 0)) == 2, "rack kit matches wood/lashing plan")

func _test_crock_pot_recipe_and_kit() -> void:
	var data: Node = get_root().get_node("Data")
	var rec: Dictionary = data.get("recipes").get(&"camp_stew", {})
	_expect(str(rec.get("station", "")) == "crock_pot", "stew requires a crock pot")
	_expect(rec.get("slots", []).size() == 3 and is_equal_approx(float(rec.get("seconds", 0)), 6.0), "stew combines three ingredients in six seconds")
	var stew: ItemDef = data.call("item", &"camp_stew")
	_expect(stew != null and stew.has_category(&"cooked") and not stew.raw and stew.food_energy == 32.0, "stew is cooked food")
	var clay: ItemDef = data.call("item", &"clay")
	var mud: ItemDef = data.call("item", &"mud")
	_expect(clay.has_category(&"pot_clay") and not mud.has_category(&"pot_clay"), "pot kit requires clay rather than any earth")
	var kit: Dictionary = data.get("recipes").get(&"crock_pot_kit", {})
	_expect(kit.get("slots", []).size() == 3 and int(kit["slots"][0].get("count", 0)) == 4 and int(kit["slots"][1].get("count", 0)) == 2 and int(kit["slots"][2].get("count", 0)) == 2, "pot kit costs clay four, stone two, wood two")
	var build_script := load("res://scripts/world/build_placer.gd") as GDScript
	var placer: Node = build_script.new()
	_expect(placer.call("_kit_id", &"crock_pot") == "crock_pot_kit", "pot kit routes to placement")
	placer.free()
	var pot_kit: ItemDef = data.call("item", &"crock_pot_kit")
	_expect(pot_kit != null and pot_kit.place_as == &"crock_pot" and pot_kit.footprint == Vector2i(2, 2), "pot kit exposes a two by two placement")
	var props: Dictionary = data.get("props_manifest").get("buildings", {})
	_expect(props.has("crock_pot"), "pot has a visual entry")

func _test_stone_fire_pit() -> void:
	var data: Node = get_root().get_node("Data")
	var kit: Dictionary = data.get("recipes").get(&"stone_fire_pit_kit", {})
	_expect(kit.get("slots", []).size() == 2 and int(kit["slots"][0].get("count", 0)) == 6 and int(kit["slots"][1].get("count", 0)) == 2, "stone pit costs six stone and two wood")
	var kit_item: ItemDef = data.call("item", &"stone_fire_pit_kit")
	_expect(kit_item != null and kit_item.place_as == &"stone_fire_pit" and kit_item.footprint == Vector2i(2, 2), "stone pit kit places as two by two")
	var build_script := load("res://scripts/world/build_placer.gd") as GDScript
	var placer: Node = build_script.new()
	_expect(placer.call("_kit_id", &"stone_fire_pit") == "stone_fire_pit_kit", "pit placement spends its own kit")
	placer.free()
	var props: Dictionary = data.get("props_manifest").get("buildings", {})
	_expect(props.has("stone_fire_pit"), "stone pit has a placed visual")
	# The boot smoke keeps the legacy public-camp bonfire path exercised.

func _test_empty_bucket_recipe() -> void:
	var data: Node = get_root().get_node("Data")
	var rec: Dictionary = data.get("recipes").get(&"empty_bucket", {})
	_expect(str(rec.get("station", "")) == "workbench" and str(rec.get("output", {}).get("id", "")) == "empty_bucket", "workbench crafts an empty bucket")
	_expect(rec.get("slots", []).size() == 2 and str(rec["slots"][0].get("category", "")) == "wood" and int(rec["slots"][0].get("count", 0)) == 2 and str(rec["slots"][1].get("category", "")) == "lashing" and int(rec["slots"][1].get("count", 0)) == 1, "bucket provisional wood and lashing cost")
	var bucket: ItemDef = data.call("item", &"empty_bucket")
	_expect(bucket != null and bucket.has_category(&"bucket"), "bucket qualifies for well fill recipe")
	var fill: Dictionary = data.get("recipes").get(&"fill_bucket", {})
	_expect(str(fill.get("station", "")) == "well" and str(fill.get("output", {}).get("id", "")) == "water_bucket", "well makes water bucket from crafted bucket")

func _test_mortar_well_kit_routes() -> void:
	var data: Node = get_root().get_node("Data")
	var placer: Node = (load("res://scripts/world/build_placer.gd") as GDScript).new()
	for row in [
		{"kind": &"mortar", "kit": &"mortar_kit", "footprint": Vector2i(1, 1), "costs": [3, 1]},
		{"kind": &"well", "kit": &"well_kit", "footprint": Vector2i(2, 2), "costs": [6, 4, 2]},
	]:
		var rec: Dictionary = data.get("recipes").get(row["kit"], {})
		_expect(rec.get("slots", []).size() == row["costs"].size(), "%s kit has required materials" % row["kind"])
		for i in row["costs"].size():
			_expect(int(rec["slots"][i].get("count", 0)) == row["costs"][i], "%s kit material %d" % [row["kind"], i])
		var kit: ItemDef = data.call("item", row["kit"])
		_expect(kit != null and kit.place_as == row["kind"] and kit.footprint == row["footprint"], "%s kit footprint and place kind" % row["kind"])
		_expect(placer.call("_kit_id", row["kind"]) == str(row["kit"]), "%s placement consumes its kit" % row["kind"])
		var station: Node = placer.call("_spawn", row["kind"])
		_expect(station != null and station.get("station_id") == row["kind"], "%s station spawns" % row["kind"])
		station.free()
	placer.free()
	var fill: Dictionary = data.get("recipes").get(&"fill_bucket", {})
	_expect(str(fill.get("station", "")) == "well" and str(fill.get("input_id", "")) == "empty_bucket", "well fills empty bucket")
	var mince: Dictionary = data.get("recipes").get(&"meatball_mix", {})
	_expect(str(mince.get("station", "")) == "mortar" and str(mince.get("slots", [{}])[0].get("category", "")) == "raw_meat", "mortar minces raw meat, not cooked meat")

func _test_smoker() -> void:
	var data: Node = get_root().get_node("Data")
	var rec: Dictionary = data.get("recipes").get(&"smoke_meat", {})
	_expect(str(rec.get("station", "")) == "smoker" and is_equal_approx(float(rec.get("seconds", 0.0)), 12.0), "smoker processing takes twelve seconds")
	_expect(str(rec.get("slots", [{}])[0].get("category", "")) == "raw_meat", "smoker takes only uncooked meat/fish")
	var smoked: ItemDef = data.call("item", &"smoked_meat")
	var dried: ItemDef = data.call("item", &"dried_meat")
	_expect(smoked != null and not smoked.raw and smoked.has_category(&"preserved") and smoked.food_energy > dried.food_energy, "smoked meat preserves and exceeds dried food energy")
	var kit: Dictionary = data.get("recipes").get(&"smoker_kit", {})
	_expect(kit.get("slots", []).size() == 3 and int(kit["slots"][0].get("count", 0)) == 6 and int(kit["slots"][1].get("count", 0)) == 3 and int(kit["slots"][2].get("count", 0)) == 2, "smoker kit costs wood six, stone three, lashing two")
	var kit_item: ItemDef = data.call("item", &"smoker_kit")
	_expect(kit_item != null and kit_item.place_as == &"smoker" and kit_item.footprint == Vector2i(2, 2), "smoker kit places two by two")
	var placer: Node = (load("res://scripts/world/build_placer.gd") as GDScript).new()
	_expect(placer.call("_kit_id", &"smoker") == "smoker_kit", "smoker placement spends kit")
	var station: Node = placer.call("_spawn", &"smoker")
	_expect(station != null and station.get("station_id") == &"smoker", "smoker spawns craft station")
	station.free()
	placer.free()

func _test_flat_stone_grill() -> void:
	var data: Node = get_root().get_node("Data")
	var kit: Dictionary = data.get("recipes").get(&"stone_grill_kit", {})
	_expect(kit.get("slots", []).size() == 2 and int(kit["slots"][0].get("count", 0)) == 4 and int(kit["slots"][1].get("count", 0)) == 2, "flat grill costs stone four, wood two")
	var kit_item: ItemDef = data.call("item", &"stone_grill_kit")
	_expect(kit_item != null and kit_item.place_as == &"stone_grill" and kit_item.footprint == Vector2i(2, 2), "flat grill kit places two by two")
	var placer: Node = (load("res://scripts/world/build_placer.gd") as GDScript).new()
	_expect(placer.call("_kit_id", &"stone_grill") == "stone_grill_kit", "flat grill placement spends kit")
	var grill: Node = placer.call("_spawn", &"stone_grill")
	_expect(grill != null and grill.get("station_id") == &"stone_grill", "flat grill spawns craft station")
	grill.free()
	placer.free()
	for rid in [&"stone_grill", &"roast", &"seasoned_roast"]:
		var rec: Dictionary = data.get("recipes").get(rid, {})
		_expect(str(rec.get("station", "")) == "stone_grill" and str(rec.get("slots", [{}])[0].get("category", "")) == "raw_meat", "%s only takes raw meat or fish" % rid)
	var cooked: ItemDef = data.call("item", &"grilled_meat")
	_expect(cooked != null and not cooked.has_category(&"raw_meat"), "cooked meat cannot be repeatedly grilled")

func _test_temporary_campfire() -> void:
	var data: Node = get_root().get_node("Data")
	var kit: Dictionary = data.get("recipes").get(&"campfire_kit", {})
	_expect(kit.get("slots", []).size() == 2 and int(kit["slots"][0].get("count", 0)) == 2 and int(kit["slots"][1].get("count", 0)) == 1, "campfire costs wood two and tinder one")
	var cook: Dictionary = data.get("recipes").get(&"campfire_skewer", {})
	_expect(str(cook.get("station", "")) == "campfire" and str(cook.get("slots", [{}])[0].get("category", "")) == "raw_meat", "campfire only skewers raw meat")
	var build_script := load("res://scripts/world/build_placer.gd") as GDScript
	var placer: Node = build_script.new()
	_expect(placer.call("_kit_id", &"campfire") == "campfire_kit", "campfire placement spends its kit")
	placer.free()
	var fire_script := load("res://scripts/world/bonfire.gd") as GDScript
	var fire: Node = fire_script.make(&"campfire")
	_expect(fire.get("kind") == &"campfire" and fire.get("station_id") == &"campfire", "campfire has its own cook station")
	_expect(is_equal_approx(float(fire.get("seconds_left")), 120.0), "campfire starts with two active minutes")
	get_root().add_child(fire)
	fire.set_process(false) # Keep a fixed lifetime for the save round-trip assertion.
	fire.set("seconds_left", 53.0)
	var saved: Dictionary = fire.to_dict()
	var restored: Node = fire_script.from_dict(saved)
	_expect(restored.get("kind") == &"campfire" and is_equal_approx(float(restored.get("seconds_left")), 53.0), "campfire remaining time survives save")
	var legacy: Node = fire_script.from_dict({"kind": "bonfire"})
	_expect(legacy.get("station_id") == &"bonfire" and float(legacy.get("seconds_left")) < 0.0, "legacy bonfire stays persistent")
	fire.queue_free()
	restored.free()
	legacy.free()

func _test_exhaustion() -> void:
	var v := Vitals.new()
	v.fatigue = 60.0
	v.energy = 5.0
	v._process(1.0)
	_expect(v.fatigue > 60.0 and v.energy > 5.0, "time raises exhaustion while stamina still regenerates")
	v.eat(40.0)
	_expect(v.fatigue < 51.0, "food reduces exhaustion by a quarter of Energy")
	v.fatigue = 100.0
	v.energy = 100.0
	v._process(0.1)
	_expect(is_equal_approx(v.energy, 75.0), "high exhaustion caps Energy at 75 percent")
	var saved := v.to_dict()
	_expect(not saved.has("hunger") and not saved.has("thirst") and saved.has("fatigue"), "player save keeps exhaustion without hunger or thirst")
	var restored := Vitals.new()
	restored.from_dict(saved)
	_expect(is_equal_approx(restored.fatigue, 100.0) and restored.exhausted, "exhaustion survives save/load")
	restored.rest(100.0)
	_expect(is_equal_approx(restored.fatigue, 0.0) and not restored.exhausted, "sleep rest clears exhaustion")
	v.free()
	restored.free()

func _test_climate_palette() -> void:
	var palette := ClimatePalette.resolve({"palette": {"grass": "#ffffff", "sand": "#123456"}})
	_expect(palette.get("grass") == Color.WHITE, "white climate override is accepted")
	_expect(palette.get("sand") == Color.from_string("#123456", Color.BLACK), "hex climate override is parsed")
	_expect(palette.has("rock"), "default climate colours remain present")

func _test_progression_scaling() -> void:
	_expect(ProgressionScaling.TOOL_TIERS == [&"stone", &"bone", &"flint", &"obsidian", &"copper", &"bronze", &"iron", &"steel"], "tool tier ladder keeps owner order")
	_expect(is_equal_approx(ProgressionScaling.tool_power(1, &"stone"), 1.0), "level 1 stone is baseline")
	_expect(is_equal_approx(ProgressionScaling.tool_power(5, &"stone"), 1.4), "level 5 tool is meaningfully stronger")
	_expect(ProgressionScaling.gather_seconds(3.0, 6, 1, &"stone", 1) > 4.5, "five-level zone gap slows gathering")
	_expect(ProgressionScaling.gather_seconds(3.0, 1, 5, &"steel", 5) < 1.0, "high-level steel tool gathers much faster")
	var mean := ProgressionScaling.crafted_level([5, 10, 15])
	_expect(mean == 10, "craft output level is weighted material average")

func _test_starter_island_levels_and_resource_stacks() -> void:
	var home_file := FileAccess.open("res://data/islands/home_grassland.json", FileAccess.READ)
	_expect(home_file != null, "starter-island definition exists")
	var home: Variant = JSON.parse_string(home_file.get_as_text()) if home_file else {}
	_expect(home is Dictionary and int(home.get("level_override", 0)) == 1, "starter island pins resources and creatures to level 1")

	# Explicit spawn/gather level beats catalog/species tiers. These are the two live regressions.
	_expect(ProgressionScaling.resolved_item_level(1, 20) == 1, "explicit level-one resource stays level one")
	_expect(ProgressionScaling.resolved_item_level(-1, 20) == 20, "omitted resource level uses catalog level")
	_expect(ProgressionScaling.resolved_spawn_level(20, {"level_override": 1}) == 1, "starter creature override beats species tier during island build")
	_expect(ProgressionScaling.resolved_spawn_level(20, {}) == 20, "islands without override keep species tier")


func _test_hud_event_state() -> void:
	var events := HudEventState.new()
	events.add_toast(&"wood", 2)
	events.add_toast(&"wood", 3)
	_expect(events.toasts.size() == 1 and int(events.toasts[0]["n"]) == 5, "nearby item toasts coalesce")
	events.add_notice("Too far")
	events.add_notice("Too far")
	_expect(events.notices.size() == 1, "duplicate notices coalesce")
	events.add_bite(7.0, true)
	_expect(events.bites.size() == 1 and events.player_floats.size() == 1, "bite and damage float are paired")
	events.tick(4.0)
	_expect(events.toasts.is_empty() and events.notices.is_empty() and events.bites.is_empty() and events.player_floats.is_empty(), "expired HUD events are removed")

func _test_creature_genetics() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var genes := CreatureGenetics.roll(rng)
	for stat in CreatureGenetics.STATS:
		_expect(int(genes.ivs[stat]) >= 0 and int(genes.ivs[stat]) <= CreatureGenetics.IV_MAX, "IV in range: %s" % stat)
	var before := 0
	for value in genes.level_gains.values():
		before += int(value)
	var gains := genes.add_level(rng)
	var after := 0
	for value in genes.level_gains.values():
		after += int(value)
	_expect(after - before == 3, "level grants three random combat stat points")
	_expect(not gains.is_empty(), "level gain summary is populated")
	_expect(genes.train(&"accuracy", 500) == CreatureGenetics.EV_MAX_PER_STAT, "focused EV respects per-stat cap")
	_expect(genes.tier_for_iv(0) == &"D-", "lowest IV is D-")
	_expect(genes.tier_for_iv(31) == &"S+", "highest IV is S+")
	var copy := CreatureGenetics.from_dict(genes.to_dict())
	_expect(copy.ivs == genes.ivs and copy.evs == genes.evs and copy.level_gains == genes.level_gains, "genetics save roundtrip")

func _test_ui_tokens() -> void:
	var font := ThemeDB.fallback_font
	_expect(font != null, "UI font is available")
	if font == null:
		return
	for sample in ["Stegosaurus", "Compsognathus", "Ranged Defense", "Obsidian Pickaxe"]:
		var clipped := UiTokens.ellipsis(font, sample, 72.0, 14)
		_expect(clipped.ends_with("…") or font.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 72.0, "long name stays inside 72 px: %s" % sample)
		_expect(font.get_string_size(clipped, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 72.0 + 1.0, "ellipsis result fits: %s" % sample)
	_expect(UiTokens.ellipsis(font, "999", 80.0, 14) == "999", "three-digit stack is kept when it fits")
	_expect(font.get_string_size("999s", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 60.0, "three-digit timer fits a 64 px ring")
	_expect(UiTokens.body(Vector2(1600, 900)) >= 16, "desktop body is at least 16")
	_expect(UiTokens.body(Vector2(390, 844)) >= 14, "phone body stays at least 14")
	_expect(UiTokens.meta(Vector2(390, 844)) >= 12, "phone metadata stays at least 12")
	_expect(UiTokens.heading(Vector2(1600, 900)) >= 20 and UiTokens.heading(Vector2(1600, 900)) <= 28, "desktop heading is in range")
	var labels: Array = [
		{"id": "Workbench", "anchor": Vector2(400, 300), "w": 150.0, "h": 22.0, "priority": 2},
		{"id": "Cargo Warp", "anchor": Vector2(410, 308), "w": 160.0, "h": 22.0, "priority": 1},
	]
	var placed: Array = UiTokens.layout_labels(labels, Vector2(1600, 900))
	_expect(placed.size() == 2, "both world labels are placed")
	var a: Rect2 = placed[0]["rect"]
	var b: Rect2 = placed[1]["rect"]
	_expect(not a.grow(1.0).intersects(b), "Workbench and Cargo Warp labels do not overlap")
	var edge: Array = ContextRadial.hex_positions(Vector2(1580, 860), 3, Vector2(1600, 900), Vector4.ZERO, 64.0)
	_expect(edge.size() == 3, "radial returns one spot per hex")
	for spot in edge:
		var p: Vector2 = spot
		_expect(p.x >= -0.1 and p.y >= -0.1 and p.x + 64.0 <= 1600.1 and p.y + 64.0 <= 900.1, "radial hex stays inside 1600x900")
	var phone: Array = ContextRadial.hex_positions(Vector2(370, 820), 3, Vector2(390, 844), Vector4.ZERO, 64.0)
	for spot in phone:
		var p2: Vector2 = spot
		_expect(p2.x >= -0.1 and p2.y >= -0.1 and p2.x + 64.0 <= 390.1 and p2.y + 64.0 <= 844.1, "radial hex stays inside 390x844")

func _test_capture_threshold() -> void:
	var script: Variant = load("res://scripts/pets/field_tame.gd")
	_expect(script != null, "field tame script loads after autoloads")
	if script == null:
		return
	_expect(bool(script.call("health_allows_capture", 0.299)), "capture opens below 30 percent health")
	_expect(not bool(script.call("health_allows_capture", 0.30)), "capture stays closed at 30 percent health")
	_expect(not bool(script.call("health_allows_capture", 0.50)), "capture stays closed above threshold")

func _test_multistack_crafting() -> void:
	# Dynamic load avoids compiling Crafting before autoload Data exists.
	var script: GDScript = load("res://tests/multistack_lab.gd") as GDScript
	_expect(script != null, "multi-stack lab loads")
	if script == null: return
	var lab: RefCounted = script.new()
	var results: Dictionary = lab.call("run")
	for label in results:
		_expect(bool(results[label]), str(label))

func _test_combat_counters() -> void:
	var model := load("res://scripts/combat/combat_counters.gd") as GDScript
	var creature_count := 0
	var dir := DirAccess.open("res://data/creatures")
	for filename in dir.get_files():
		if not filename.ends_with(".json"): continue
		var row: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/" + filename))
		if not row is Dictionary or not row.has("stats"): continue
		creature_count += 1
		_expect(model.family(StringName(row["archetype"])) != "neutral", "counter family for " + filename)
	_expect(creature_count == 19, "counter chart covers19 catalogue species")
	_expect(is_equal_approx(model.multiplier(&"tyrant", &"blunt"), 1.5), "tyrant blunt counter")
	_expect(is_equal_approx(model.multiplier(&"tyrant", &"slashing"), 0.5), "slashing aliases cut")
	_expect(is_equal_approx(model.multiplier(&"unknown", &"blunt"), 1.0), "unknown archetype neutral")
	_expect(is_equal_approx(model.multiplier(&"tyrant", &"unknown"), 1.0), "unknown channel neutral")
	_expect(is_equal_approx(model.dot_fraction(&"tyrant", &"poisoned_target"), 0.00225), "tyrant poison0.225percent")
	_expect(is_equal_approx(model.dot_dps(&"tyrant", &"bleeding_target", 200000.0, 5), 6.0), "tyrant fixed bleed resistance")
	_expect(is_equal_approx(model.dot_dps(&"pack_raptor", &"bleeding_target", 640.0, 5), 90.0), "raptor stacked fixed bleed")
	_expect(model.dot_dps(&"pack_raptor", &"bleeding_target", 640.0, 1) == model.dot_dps(&"pack_raptor", &"bleeding_target", 64000.0, 1), "bleed independent of health")
	_expect(model.dot_dps(&"pack_raptor", &"bleeding_target", 640.0, 2) > 2 * model.dot_dps(&"pack_raptor", &"bleeding_target", 640.0, 1), "bleed stacks escalate")
	_expect(model.dot_duration(&"bleeding_target", 20.0) == 12.0, "creature counter duration")
	_expect(model.dot_duration(&"deep_bleed", 30.0) == 30.0, "injury clock unchanged")
	var pl = (load("res://scripts/player/player.gd") as GDScript).new()
	var status = (load("res://scripts/combat/status_effects.gd") as GDScript).new()
	pl.vitals = (load("res://scripts/combat/vitals.gd") as GDScript).new()
	pl.add_child(pl.vitals)
	pl.add_child(status)
	status.apply(&"bleeding_target")
	status.apply(&"poisoned_target")
	_expect(not status.has(&"bleeding_target") and not status.has(&"poisoned_target"), "no creature counter status on players")
	status.apply(&"deep_bleed")
	_expect(status.has(&"deep_bleed"), "ordinary player bleed unchanged")
	pl.free()
	var cr = (load("res://scripts/creatures/creature.gd") as GDScript).new()
	cr.def = (load("res://scripts/creatures/creature_def.gd") as GDScript).new()
	cr.def.archetype = &"pack_raptor"
	cr.health = (load("res://scripts/combat/health.gd") as GDScript).new()
	cr.health.setup(640.0)
	cr.add_child(cr.health)
	cr.statuses = (load("res://scripts/combat/status_effects.gd") as GDScript).new()
	cr.add_child(cr.statuses)
	for i in 6: cr.statuses.apply(&"bleeding_target")
	var inst = cr.statuses.get_instance(&"bleeding_target")
	_expect(inst.stacks == 5 and inst.time_left == 12.0, "creature bleed stack cap and refresh")
	cr.statuses._dot(inst)
	_expect(is_equal_approx(cr.health.hp, 595.0), "real creature bleed tick45HP")
	var saved: Array = cr.statuses.to_array()
	cr.statuses.from_array(saved)
	_expect(cr.statuses.get_instance(&"bleeding_target").stacks == 5, "bleed stacks survive reload")
	cr.def.archetype = &"tyrant"
	cr.health.setup(200000.0)
	cr.statuses.apply(&"poisoned_target")
	cr.statuses._dot(cr.statuses.get_instance(&"poisoned_target"))
	_expect(is_equal_approx(cr.health.hp, 199775.0), "real tyrant poison tick225HP")
	cr.free()

func _test_counter_supplies() -> void:
	var data = get_root().get_node("Data")
	var inv = (load("res://scripts/items/inventory.gd") as GDScript).new(20)
	var stack_script := load("res://scripts/items/item_stack.gd") as GDScript
	for pair in [[&"herb_leaf", 4], [&"dense_bone", 2], [&"branch", 2], [&"hide_strap", 3], [&"raptor_talon", 1]]:
		inv.add(stack_script.make(pair[0], pair[1]))
	var craft := load("res://scripts/items/crafting.gd") as GDScript
	for id in [&"toxin_coating", &"bone_hammer", &"barbed_knife"]:
		var recipe: Dictionary = craft.recipe(id)
		_expect(not recipe.is_empty(), "counter recipe " + str(id))
		var picks: Array = craft.default_picks(inv, recipe)
		_expect(craft.picks_valid(inv, recipe, picks), "counter materials allocation " + str(id))
		var parts: Array = craft.consume_for_craft(inv, recipe, picks)
		var output = craft.build_output(recipe, parts[0], 1, parts)
		inv.add(output)
	_expect(inv.count_of(&"herb_leaf") == 0 and inv.count_of(&"toxin_coating") == 1, "herb toxin consumes real herbs")
	var pl = (load("res://tests/fixtures/counter_player.gd") as GDScript).new()
	pl.inventory = inv
	pl.anim = (load("res://scripts/player/player_anim.gd") as GDScript).new()
	pl.add_child(pl.anim)
	pl.vitals = (load("res://scripts/combat/vitals.gd") as GDScript).new()
	pl.add_child(pl.vitals)
	inv.equip(&"weapon", &"barbed_knife")
	_expect(pl.coat_weapon(), "normal coat action")
	_expect(inv.count_of(&"toxin_coating") == 0, "coating dose consumed")
	var weapon = inv.equipped_weapon()
	_expect(int(weapon.attributes.get("toxin_hits", 0)) == 3, "three toxin charges")
	_expect(not pl.coat_weapon(), "cannot overwrite active coating")
	var restored = (load("res://scripts/items/inventory.gd") as GDScript).new(20)
	restored.load_array(inv.to_array())
	_expect(int(restored.slots[restored.find_first(&"barbed_knife")].attributes.get("toxin_hits", 0)) == 3, "toxin charges survive item reload")
	var cr = (load("res://scripts/creatures/creature.gd") as GDScript).new()
	cr.def = (load("res://scripts/creatures/creature_def.gd") as GDScript).new()
	cr.def.archetype = &"pack_raptor"
	cr.health = (load("res://scripts/combat/health.gd") as GDScript).new()
	cr.health.setup(640)
	cr.add_child(cr.health)
	cr.statuses = (load("res://scripts/combat/status_effects.gd") as GDScript).new()
	cr.add_child(cr.statuses)
	var hunt = (load("res://scripts/combat/hunt.gd") as GDScript).new()
	hunt.player = pl
	for i in 3: hunt.apply_counter_hit(weapon, cr)
	_expect(cr.statuses.has(&"bleeding_target") and cr.statuses.has(&"poisoned_target"), "third valid barbed hit bleeds and coating poisons")
	_expect(int(weapon.attributes["toxin_hits"]) == 0, "three hits spend exactly three charges")
	hunt.free()
	cr.free()
	pl.free()
	for species in [&"compsognathus", &"velociraptor", &"deinonychus", &"utahraptor"]:
		var found := false
		for drop in data.butcher_drops(species):
			if str(drop.get("id", "")) == "predator_tendon": found = true
		_expect(found, "guaranteed tendon source " + str(species))
	var corpse = (load("res://scripts/creatures/corpse.gd") as GDScript).new()
	corpse.species = &"velociraptor"
	corpse.poison_spoiled = true
	corpse._roll_loot()
	_expect(corpse.loot.count_of(&"raptor_meat") == 0, "poison corpse rejects meat")
	_expect(corpse.loot.count_of(&"raptor_bone") > 0 and corpse.loot.count_of(&"predator_tendon") > 0, "poison corpse keeps counter materials")
	corpse.free()

func _test_trap_control() -> void:
	var script := load("res://scripts/creatures/creature.gd") as GDScript
	var cr = script.new()
	cr.def = (load("res://scripts/creatures/creature_def.gd") as GDScript).new()
	cr.def.archetype = &"pack_raptor"
	cr.health = (load("res://scripts/combat/health.gd") as GDScript).new()
	cr.health.setup(640)
	cr.add_child(cr.health)
	cr.statuses = (load("res://scripts/combat/status_effects.gd") as GDScript).new()
	cr.add_child(cr.statuses)
	_expect(cr.apply_trap_control(false), "light snare catches fast prey")
	_expect(cr.trap_left == 4 and cr.trap_move_mult == 0, "fast prey root4s")
	_expect(cr.statuses.can_act(), "root never disables attacks")
	_expect(not cr.apply_trap_control(true), "no control refresh while trapped")
	cr.tick_trap_control(4)
	_expect(cr.trap_left == 0 and cr.trap_immunity_left == 10, "postrelease10s immunity")
	_expect(not cr.apply_trap_control(false), "immunity rejects retrap")
	cr.tick_trap_control(10)
	cr.def.archetype = &"tyrant"
	_expect(not cr.apply_trap_control(false), "tyrant rejects rope root")
	_expect(cr.apply_trap_control(true) and cr.trap_move_mult > 0 and cr.trap_left == 2, "tyrant heavy slow not root")
	cr.tick_trap_control(2)
	_expect(not cr.apply_trap_control(true), "tyrant slow chain rejected")
	cr.free()
	var model := load("res://scripts/combat/ground_snare.gd") as GDScript
	var row := {"heavy": true, "position": [1.0, 2.0, 3.0], "life_left": 30.0, "arm_left": 0.5}
	var host := Node3D.new()
	get_root().add_child(host)
	var trap = model.restore(row, host)
	_expect(trap != null and trap.to_dict() == row, "placed snare snapshot restores remaining life")
	_expect(model.restore({"position": [1,2,3], "life_left": 0}, host) == null, "expired trap not restored")
	host.free()
	var craft := load("res://scripts/items/crafting.gd") as GDScript
	var inv = (load("res://scripts/items/inventory.gd") as GDScript).new(20)
	var stack_script := load("res://scripts/items/item_stack.gd") as GDScript
	for pair in [[&"predator_tendon",1], [&"hide_strap",4], [&"branch",1], [&"armor_scute",2], [&"metal_shard",2]]:
		inv.add(stack_script.make(pair[0], pair[1]))
	for id in [&"rope_snare", &"heavy_snare"]:
		var recipe: Dictionary = craft.recipe(id)
		var picks: Array = craft.default_picks(inv, recipe)
		_expect(craft.picks_valid(inv, recipe, picks), "snare recipe allocation " + str(id))
		var parts: Array = craft.consume_for_craft(inv, recipe, picks)
		inv.add(craft.build_output(recipe, parts[0], 1, parts))
	_expect(inv.count_of(&"rope_snare") == 1 and inv.count_of(&"heavy_snare") == 1, "snare crafted outputs with real payment")

func _test_slingshot_recipe() -> void:
	var craft := load("res://scripts/items/crafting.gd") as GDScript
	var inv = (load("res://scripts/items/inventory.gd") as GDScript).new(20)
	var stack_script := load("res://scripts/items/item_stack.gd") as GDScript
	for pair in [[&"bone",1], [&"branch",1], [&"hide_strap",2], [&"stone",1]]:
		inv.add(stack_script.make(pair[0], pair[1]))
	for id in [&"slingshot", &"stone_shot"]:
		var recipe: Dictionary = craft.recipe(id)
		var picks: Array = craft.default_picks(inv, recipe)
		_expect(craft.picks_valid(inv, recipe, picks), "ranged recipe allocation " + str(id))
		var parts: Array = craft.consume_for_craft(inv, recipe, picks)
		inv.add(craft.build_output(recipe, parts[0], 1, parts))
	_expect(inv.count_of(&"slingshot") == 1 and inv.count_of(&"stone_shot") == 5, "slingshot and five shots paid")
	var data = get_root().get_node("Data")
	_expect(data.item(&"slingshot").range_m == 12 and data.item(&"slingshot").ammo_id == &"stone_shot", "ranged data loaded")

func _test_catapult_recipe_save() -> void:
	var inv = load("res://scripts/items/inventory.gd").new()
	for part in [[&"branch",8],[&"dense_bone",2],[&"twine",6],[&"venom_gland",1],[&"stone",2]]:
		inv.add(load("res://scripts/items/item_stack.gd").make(part[0],part[1]))
	var craft = load("res://scripts/items/crafting.gd")
	for id in [&"catapult_kit",&"toxin_pot"]:
		var rec: Dictionary = craft.recipe(id)
		var picks: Array[int] = craft.default_picks(inv,rec)
		_expect(craft.picks_valid(inv,rec,picks), "siege recipe payable: %s" % id)
		var parts: Array = craft.consume_for_craft(inv,rec,picks)
		if not parts.is_empty(): inv.add(craft.build_output(rec,parts[0],1,parts))
	_expect(inv.count_of(&"catapult_kit")==1 and inv.count_of(&"toxin_pot")==1, "siege craft spends real ingredients")
	var platform = load("res://scripts/world/field_catapult.gd").new()
	platform.set_grid_pose(Vector2i(4,5),1)
	platform.receive_siege_hit(50)
	platform.reload_left = 2.0
	var save := load("res://scripts/core/save_game.gd")
	var restored = save._spawn_building(platform.to_dict())
	_expect(restored != null and restored.hp == 150 and restored.reload_left == 2 and restored.build_cell == Vector2i(4,5) and restored.build_rot == 1, "siege hp/reload/pose persist")
	var dead_row: Dictionary = platform.to_dict()
	dead_row["hp"] = 0
	_expect(save._spawn_building(dead_row) == null, "destroyed siege is not resurrected from transient save")
	var grid = load("res://scripts/world/build_grid.gd").new()
	_expect(grid.cells_for(&"catapult",Vector2i.ZERO,0).size()==9, "siege uses 3x3 footprint")
	grid.free()
	platform.free()
	restored.free()

func _test_tyrant_counters() -> void:
	var scene = load("res://scenes/creatures/creature.tscn")
	var boss = scene.instantiate()
	get_root().add_child(boss)
	boss.spawn(get_root().get_node("Data").creature(&"tyrannosaurus"))
	var brain = boss.brain
	_expect(brain.get_script() == load("res://scripts/creatures/brains/tyrant_brain.gd"), "T-rex uses timing controller")
	brain.phase = &"windup"
	brain.blunt_counter()
	_expect(brain.counter_hits == 0, "windup damage cannot stagger")
	brain.phase = &"recovery"
	for k in range(5): brain.blunt_counter()
	_expect(brain.phase == &"recovery" and brain.counter_hits == 5, "unpoisoned boss needs six punish hits")
	brain.blunt_counter()
	_expect(brain.phase == &"stagger" and brain.phase_left == 3 and brain.counter_hits == 0, "six blunt counters grant fixed stagger")
	brain.phase = &"recovery"
	boss.statuses.apply(&"poisoned_target")
	for k in range(3): brain.blunt_counter()
	_expect(brain.phase == &"stagger", "poison lowers threshold to three punish hits")
	brain.phase = &"recovery"
	brain.stagger_immunity = 20
	brain.blunt_counter()
	_expect(brain.counter_hits == 0, "stagger immunity rejects buildup")
	for id in [&"groggy",&"knockdown",&"snared",&"pinned"]:
		boss.statuses.apply(id)
		_expect(not boss.statuses.has(id), "tyrant rejects shortcut control " + str(id))
	boss.free()
