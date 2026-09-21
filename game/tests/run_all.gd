extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	_test_save_migrations()
	_test_food_buffs()
	_test_climate_palette()
	_test_creature_genetics()
	_test_hud_event_state()
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

func _test_climate_palette() -> void:
	var palette := ClimatePalette.resolve({"palette": {"grass": "#ffffff", "sand": "#123456"}})
	_expect(palette.get("grass") == Color.WHITE, "white climate override is accepted")
	_expect(palette.get("sand") == Color.from_string("#123456", Color.BLACK), "hex climate override is parsed")
	_expect(palette.has("rock"), "default climate colours remain present")

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
