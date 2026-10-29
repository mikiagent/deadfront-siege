extends SceneTree
## HUNGER (owner-approved memo docs/design/hunger-and-tribe-automation.md Part 1, 2026-10-29):
## "the stomach is a budget, and what fills it is your buff". This test pins the data and the model:
##   rules       rules.json hunger block: decay 2.5/min, band edges, fatigue_mult per band,
##               starving_after_s 600, well_fed_regen 0.2; fatigue.fullness_mult retired.
##   foods       fullness per class (raw fruit/berries 6-10 + snack, cooked 25-30, dishes 45-60),
##               cooked dishes default to duration_mode while_fed.
##   decay       Digestion.fullness is a stored, saved value: add_fullness raises it, tick drains it at
##               the rate, an old save seeds it once from the old formula.
##   bands       state_for + the fatigue multiplier table, and the stored value in the HUD ring.
##   while_fed   a cooked dish's buff lives until fullness < 10, then goes; a snack never refreshes it.
##   starving    the status only starts after starving_after_s on an empty stomach (PlayerSim).
## Run: Godot --headless --path game --script res://tests/t_hunger.gd -> "[t_hunger] PASS".

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player
var _hud
var data: Node
var DIG: GDScript
var FX: GDScript
var ST: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_hunger] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	data = root.get_node("Data")
	DIG = load("res://scripts/items/digestion.gd")
	FX = load("res://scripts/items/food_effects.gd")
	ST = load("res://scripts/ui/hud_stomach.gd")
	_host = Node3D.new()
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("quick_row_y"):
			_hud = c
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_test_rules()
	_test_foods()
	_test_decay()
	_test_bands()
	_test_save()
	await _test_while_fed()
	await _test_starving_delay()
	if _fails.is_empty():
		print("[t_hunger] PASS")
		quit(0)
	else:
		print("[t_hunger] FAIL count=%d" % _fails.size())
		quit(1)

func _hunger() -> Dictionary:
	return (data.world_rules.get("hunger", {}) as Dictionary)

func _fresh(fullness: float = 60.0) -> void:
	_player.statuses.from_array([])
	_player.vitals.dead = false
	_player.vitals.health = _player.vitals.effective_max_health()
	load("res://scripts/items/buff_slots.gd").of(_player).restore(_player, {})
	var dig = DIG.of(_player)
	dig.from_dict({})
	dig.set_fullness(fullness)
	_player.sim.starving_s = 0.0

# ---------------------------------------------------------------- rules

func _test_rules() -> void:
	print("[t_hunger] -- rules")
	var h := _hunger()
	_expect(not h.is_empty(), "rules.json has a hunger block")
	_expect(is_equal_approx(float(h.get("decay_per_min", 0.0)), 2.5), "fullness decays 2.5 a minute (%.2f)" % float(h.get("decay_per_min", 0.0)))
	_expect(is_equal_approx(float(h.get("empty_below", 0.0)), 10.0) and is_equal_approx(float(h.get("peckish_below", 0.0)), 30.0) \
		and is_equal_approx(float(h.get("fed_below", 0.0)), 70.0) and is_equal_approx(float(h.get("well_fed_below", 0.0)), 100.0), \
		"band edges 10 / 30 / 70 / 100 (%.0f %.0f %.0f %.0f)" % [float(h.get("empty_below", 0.0)), float(h.get("peckish_below", 0.0)), float(h.get("fed_below", 0.0)), float(h.get("well_fed_below", 0.0))])
	var fm: Dictionary = h.get("fatigue_mult", {})
	_expect(is_equal_approx(float(fm.get("overfull", 0.0)), 1.05) and is_equal_approx(float(fm.get("well_fed", 0.0)), 0.85) \
		and is_equal_approx(float(fm.get("fed", 0.0)), 1.0) and is_equal_approx(float(fm.get("peckish", 0.0)), 1.1) \
		and is_equal_approx(float(fm.get("empty", 0.0)), 1.3) and is_equal_approx(float(fm.get("starving", 0.0)), 1.5), \
		"fatigue multiplier per band 1.05 / 0.85 / 1.0 / 1.1 / 1.3 / 1.5 (%s)" % str(fm))
	_expect(is_equal_approx(float(h.get("starving_after_s", 0.0)), 600.0), "starving starts after 600 s empty")
	_expect(is_equal_approx(float(h.get("starving_stack_s", 0.0)), 180.0), "a starving stack every 180 s")
	_expect(is_equal_approx(float(h.get("well_fed_regen", 0.0)), 0.2), "well fed adds 0.2 HP/s")
	# Retired: the old fatigue.fullness_mult table is gone, and Digestion reads the new block.
	_expect(not (data.world_rules.get("fatigue", {}) as Dictionary).has("fullness_mult"), "fatigue.fullness_mult is retired")
	for st in [&"overfull", &"well_fed", &"fed", &"peckish", &"empty", &"starving"]:
		_expect(is_equal_approx(DIG.fatigue_mult_for(st), float(fm.get(str(st), -1.0))), "fatigue_mult_for(%s) reads the hunger block (%.2f)" % [st, DIG.fatigue_mult_for(st)])
	_expect(is_equal_approx(DIG.fatigue_mult_for(&"no_such_band"), 1.0), "an unknown band is neutral")

# ---------------------------------------------------------------- foods

func _test_foods() -> void:
	print("[t_hunger] -- foods")
	var h := _hunger()
	var cls: Dictionary = h.get("fullness_classes", {})
	var snack: Array = cls.get("snack", [])
	var simple: Array = cls.get("simple_cooked", [])
	var dish: Array = cls.get("role_dish", [])
	var items := {}
	for row: Variant in (data.items.values() if data.items is Dictionary else []):
		items[str(row.id)] = row
	for id in ["berry", "berries", "coconut", "mango", "corn"]:
		var e: Dictionary = FX.entry_for(StringName(id))
		var f := float(e.get("fullness", 0.0))
		_expect(f >= float(snack[0]) and f <= float(snack[1]) and bool(e.get("snack", false)), "%s is a snack (fullness %.0f, snack %s)" % [id, f, str(e.get("snack", false))])
		_expect(not e.has("buffs") or (e.get("buffs", []) as Array).is_empty(), "%s carries no meal buff" % id)
	for id in ["grilled_meat", "skewer", "spiced_skewer"]:
		var f := float(FX.entry_for(StringName(id)).get("fullness", 0.0))
		_expect(f >= float(simple[0]) and f <= float(simple[1]), "%s is simple cooked food (fullness %.0f in %.0f-%.0f)" % [id, f, float(simple[0]), float(simple[1])])
	for id in ["roast", "seasoned_roast", "crafters_meal", "camp_stew"]:
		var e: Dictionary = FX.entry_for(StringName(id))
		var f := float(e.get("fullness", 0.0))
		_expect(f >= float(dish[0]) and f <= float(dish[1]), "%s is a dish (fullness %.0f in %.0f-%.0f)" % [id, f, float(dish[0]), float(dish[1])])
		_expect(str(e.get("duration_mode", "")) == "while_fed", "%s's meal buff is while_fed (%s)" % [id, str(e.get("duration_mode", ""))])
	# A drink is not a meal: no while_fed buff, no dish fullness.
	for id in ["dutch_coffee", "tea", "meat_broth"]:
		var e: Dictionary = FX.entry_for(StringName(id))
		_expect(str(e.get("duration_mode", "")) != "while_fed", "%s keeps its own buff timing (%s)" % [id, str(e.get("duration_mode", ""))])

# ---------------------------------------------------------------- decay + stored value

func _test_decay() -> void:
	print("[t_hunger] -- decay")
	var dig = DIG.of(_player)
	_fresh(0.0)
	_player.vitals.energy = 0.0
	dig.add_fullness(60.0)
	_expect(is_equal_approx(dig.fullness(), 60.0), "add_fullness(60) stores 60 points (%.2f)" % dig.fullness())
	dig.tick(_player, 60.0)
	_expect(absf(dig.fullness() - 57.5) < 0.001, "a minute of play takes 2.5 points (%.2f)" % dig.fullness())
	dig.tick(_player, 120.0)
	_expect(absf(dig.fullness() - 52.5) < 0.001, "two more minutes take 5 more (%.2f)" % dig.fullness())
	# Decay is independent of digestion: Energy still pays out over its own window.
	_fresh(0.0)
	_player.vitals.energy = 0.0
	dig.schedule(&"roast", 60.0, 300.0)
	var before: float = dig.fullness()
	dig.tick(_player, 30.0)
	_expect(absf(dig.fullness() - before + 1.25) < 0.001, "digesting Energy does not lift fullness; only decay moves it (%.2f -> %.2f)" % [before, dig.fullness()])
	_expect(_player.vitals.energy > 0.0, "the meal's Energy still digests (%.2f)" % _player.vitals.energy)
	# A full stomach cannot pass the cap.
	_fresh(0.0)
	dig.add_fullness(95.0)
	dig.add_fullness(10.0)
	_expect(is_equal_approx(dig.fullness(), 100.0), "fullness stops at the cap (%.1f)" % dig.fullness())
	_expect(DIG.state_for(dig.fullness()) == &"well_fed", "100 points is well fed (%.1f %s)" % [dig.fullness(), DIG.state_for(dig.fullness())])
	dig.add_fullness(5.0)
	_expect(DIG.state_for(dig.fullness()) == &"overfull", "above 100 is overfull (%s)" % DIG.state_for(dig.fullness()))
	_expect(FoodCanEat() == "full", "an overfull stomach refuses a meal")
	dig.set_fullness(0.0)
	_expect(FoodCanEat() == "", "an empty stomach accepts one")
	_expect(is_equal_approx(dig.decay_per_s(), 2.5 / 60.0), "decay_per_s is the rate the HUD counts with (%.5f)" % dig.decay_per_s())

## Food.can_eat for a snack in a fresh stomach, so the overfull gate is measured through the real rule.
func FoodCanEat() -> String:
	var stack = load("res://scripts/items/item_stack.gd").make(&"berry", 1)
	return load("res://scripts/items/food.gd").can_eat(_player, stack)

# ---------------------------------------------------------------- bands

func _test_bands() -> void:
	print("[t_hunger] -- bands")
	var cases := [[0.0, &"empty"], [9.9, &"empty"], [10.0, &"peckish"], [29.9, &"peckish"], [30.0, &"fed"],
		[69.9, &"fed"], [70.0, &"well_fed"], [100.0, &"well_fed"], [100.1, &"overfull"]]
	for c: Array in cases:
		_expect(DIG.state_for(float(c[0])) == c[1], "%.1f points is %s (%s)" % [float(c[0]), c[1], DIG.state_for(float(c[0]))])
	var dig = DIG.of(_player)
	for c: Array in cases:
		_fresh(float(c[0]))
		_player.sim.tick(0.0)
		_expect(_player.vitals.fullness_state == c[1], "PlayerSim publishes %s at %.1f points (%s)" % [c[1], float(c[0]), _player.vitals.fullness_state])
		var table: Dictionary = _hunger().get("fatigue_mult", {})
		_expect(is_equal_approx(_player.vitals.fullness_mult, float(table.get(str(c[1]), -1.0))), "%s carries its fatigue multiplier (%.2f)" % [c[1], _player.vitals.fullness_mult])
	# The HUD ring reads the stored value, not the digestion rows.
	_fresh(45.0)
	await _frames(2)
	_expect(absf(_hud.stomach_fill - 45.0) < 0.001 and _hud.stomach_state == &"fed", "the ring shows the stored 45 points as fed (%.2f %s)" % [_hud.stomach_fill, _hud.stomach_state])
	_expect(ST.color_for(75.0).is_equal_approx(load("res://scripts/ui/ui_tokens.gd").STOMACH_FULL), "the well-fed band is green")
	# Well Fed heals a little; empty does not.
	_fresh(80.0)
	_player.vitals.health = _player.vitals.effective_max_health() - 30.0
	_player.vitals.blocks_regen = false
	_player.sim.tick(0.0)
	var hp: float = _player.vitals.health
	_player.sim.tick(1.0)
	_expect(_player.vitals.health > hp + 0.1, "well fed adds the regen bonus (%.2f -> %.2f)" % [hp, _player.vitals.health])
	_fresh(5.0)
	_player.sim.tick(0.0)
	hp = _player.vitals.health
	_player.sim.tick(1.0)
	_expect(_player.vitals.health <= hp + 0.001, "an empty stomach gets no regen bonus (%.2f -> %.2f)" % [hp, _player.vitals.health])
	_fresh(60.0)

# ---------------------------------------------------------------- save

func _test_save() -> void:
	print("[t_hunger] -- save")
	var dig = DIG.of(_player)
	_fresh(0.0)
	dig.set_fullness(42.0)
	dig.empty_for_s = 7.0
	var d: Dictionary = dig.to_dict()
	_expect(is_equal_approx(float(d.get("fullness", -1.0)), 42.0), "the save carries fullness (%.1f)" % float(d.get("fullness", -1.0)))
	_expect(is_equal_approx(float(d.get("empty_for_s", -1.0)), 7.0), "the save carries empty_for_s (%.1f)" % float(d.get("empty_for_s", -1.0)))
	var rt = DIG.new()
	rt.from_dict(d)
	_expect(is_equal_approx(rt.fullness(), 42.0) and is_equal_approx(rt.empty_for_s, 7.0), "and both come back (%.1f, %.1f)" % [rt.fullness(), rt.empty_for_s])
	# An old save has rows and no stored value: seed it once from today's formula (fullness x undigested share).
	var old = DIG.new()
	old.from_dict({"rows": [{"id": "dig1", "def_id": "roast", "total": 60.0, "remaining": 30.0, "seconds": 300.0, "rate": 0.2}], "next_id": 2})
	_expect(old.fullness() > 0.0, "an old save seeds fullness from its digestion rows (%.1f)" % old.fullness())
	var seeded: float = old.fullness()
	_expect(absf(seeded - 24.0) < 0.5, "a half-digested roast is about half its %.0f points (%.1f)" % (float(FX.entry_for(&"roast").get("fullness", 0.0)), seeded))
	old.from_dict(old.to_dict())
	_expect(is_equal_approx(old.fullness(), seeded), "the seed is saved, so a second load does not recompute it (%.1f)" % old.fullness())
	# A save from before the rework with nothing digesting starts empty, not fed.
	var bare = DIG.new()
	bare.from_dict({"rows": [], "next_id": 4})
	_expect(is_equal_approx(bare.fullness(), 0.0) and DIG.state_for(bare.fullness()) == &"empty", "an old empty save loads empty")

# ---------------------------------------------------------------- while_fed buffs

func _test_while_fed() -> void:
	print("[t_hunger] -- while fed")
	var slots = load("res://scripts/items/buff_slots.gd").of(_player)
	_fresh(0.0)
	var dig = DIG.of(_player)
	# The real transaction: a roast eaten through EatSession.
	_player.statuses.from_array([])
	_player.inventory.add(load("res://scripts/items/item_stack.gd").make(&"roast", 1))
	var idx: int = _player.inventory.find_first(&"roast")
	_expect(idx >= 0 and _player.begin_eat_slot(idx), "a roast is eaten")
	var session = _player.eat_session
	var guard := 0
	while session.eating and guard < 200:
		session.advance(0.1)
		guard += 1
	var row: Dictionary = slots.by_group("enhanced_ability")
	_expect(not row.is_empty() and str(row.get("id", "")) == "roast_catalog", "the roast's buff took the Enhanced Ability slot (%s)" % str(row.get("id", "")))
	_expect(is_equal_approx(dig.fullness(), 50.0), "eating added the roast's 50 points (%.1f)" % dig.fullness())
	_expect(bool(row.get("while_fed", false)), "the cooked dish's buff is marked while_fed")
	# Its timer does not run out first: 20 minutes on the clock, still fed.
	slots.tick(_player, 1200.0)
	_expect(not slots.by_group("enhanced_ability").is_empty(), "the meal buff outlives its nominal 900 s while fed (%s)" % str(slots.ids()))
	# Fullness < 10 switches it off, after only a few minutes more.
	dig.set_fullness(9.9)
	slots.tick(_player, 0.1)
	_expect(slots.by_group("enhanced_ability").is_empty(), "below 10 points the meal buff goes (slots %s)" % str(slots.ids()))
	# A snack never revives a dish's buff (it has none), and does not mark itself while_fed.
	_fresh(50.0)
	slots.restore(_player, {"buffs": [{"id": "probe_meal", "group": "enhanced_ability", "display_name": "Probe", "duration": 600.0, "time_left": 600.0, "stats": {}}]})
	_player.statuses.clear_id(&"full")
	_player.inventory.add(load("res://scripts/items/item_stack.gd").make(&"berry", 1))
	_player.eat_session.rng = RandomNumberGenerator.new()
	_player.eat_session.rng.seed = 1
	_expect(_player.begin_eat_slot(_player.inventory.find_first(&"berry")), "a berry is eaten")
	guard = 0
	while session.eating and guard < 200:
		session.advance(0.1)
		guard += 1
	_player.eat_session.rng = null
	_expect(str(slots.by_group("enhanced_ability").get("id", "")) == "probe_meal", "a snack leaves the dish's buff alone (%s)" % str(slots.by_group("enhanced_ability").get("id", "")))
	# The outer HUD ring is the meal buff's time left: fullness above the off line over the decay rate.
	_fresh(50.0)
	dig = DIG.of(_player)
	slots.restore(_player, {"buffs": [{"id": "probe_meal", "group": "enhanced_ability", "display_name": "Probe", "duration": 600.0, "time_left": 600.0, "stats": {}, "while_fed": true}]})
	await _frames(2)
	var want := 50.0 / (2.5 / 60.0) / 960.0
	_expect(absf(_hud.stomach_saturation - want) < 0.01, "the outer ring counts the fed time left (%.3f want %.3f)" % [_hud.stomach_saturation, want])
	_fresh(5.0)
	await _frames(2)
	_expect(is_equal_approx(_hud.stomach_saturation, 0.0), "with no meal buff and an empty stomach the outer ring is dark (%.2f)" % _hud.stomach_saturation)
	_fresh(60.0)
	slots.restore(_player, {})

# ---------------------------------------------------------------- starving delay

func _test_starving_delay() -> void:
	print("[t_hunger] -- starving delay")
	var dig = DIG.of(_player)
	_fresh(0.0)
	dig.set_fullness(5.0)  # empty, but not long
	_player.sim.tick(0.0)
	_expect(_player.vitals.fullness_state == &"empty" and not _player.statuses.has(&"starving"), "empty does not starve her at once")
	_player.sim.tick(599.0)
	_expect(not _player.statuses.has(&"starving"), "599 s empty: still no Starving")
	_player.sim.tick(2.0)
	_expect(_player.statuses.has(&"starving"), "after 600 s empty Starving arrives")
	var inst = _player.statuses.get_instance(&"starving")
	_expect(inst != null and inst.stacks == 1, "it starts at one stack (%d)" % (inst.stacks if inst else -1))
	_player.sim.tick(181.0)
	_expect(inst.stacks == 2, "a stack at 180 s more (%d)" % inst.stacks)
	# Peckish is not starving.
	_fresh(20.0)
	_player.sim.tick(0.0)
	_expect(_player.vitals.fullness_state == &"peckish" and not _player.statuses.has(&"starving"), "peckish is not starving")
	_fresh(60.0)
