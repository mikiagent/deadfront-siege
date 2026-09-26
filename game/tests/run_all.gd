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
	_test_capture_threshold()
	_test_sleep_building_save()
	_test_dried_meat_recipe()
	_test_crock_pot_recipe_and_kit()
	_test_stone_fire_pit()
	_test_temporary_campfire()
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
	var old: Node = script.from_dict({"kind": "tent"})
	_expect(int(old.get("sleeps_left")) == 6, "legacy tent saves start at six uses")
	roll.free()
	tent.queue_free()
	restored.free()
	old.free()

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
