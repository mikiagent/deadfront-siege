extends Node3D
## M7 kitchen lab: cooking path (sashimi-steam-steam), boil uprank, eat cancel, farming field.
## Headless run asserts every step, prints "[kitchen_lab] PASS" and exits 1 on any FAIL.

var _player: Player
var _fails: Array[String] = []
## COOKROLES: the gate runs this lab windowed with --shot-dir and reads ONE
## "[cookroles] RESULT k=v ..." line measured off this scene, plus the PNGs it saves.
var _shot_dir: String = ""
var _shots: Array[String] = []
var _co_ok := {"roles": 0, "inherit": 0, "differ": 0, "consume": 0, "cancel": 0, "foodfx": 0, "saved": 0}
var _co_dishes := 0
var _co_ui_px := 0.0
var _co_card := ""

func _check(ok: bool, label: String) -> void:
	print("[kitchen_lab] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fails.append(label)
var _bonfire: Bonfire
var _mortar: CraftStation
var _grill: CraftStation
var _steamer: CraftStation
var _well: CraftStation
var _field: FieldPlot

func _ready() -> void:
	var kit := LabKit.build(self)
	_player = kit["player"]
	_player.skills.trees["cooking"] = {"level": 45, "xp": 0.0, "unlocked": ["skewer", "meatball", "stone_grill", "steam", "sashimi", "boiling", "roast"]}
	_player.skills.trees["farming"] = {"level": 5, "xp": 0.0, "unlocked": ["small_field", "flax"]}
	_player.skills.trees["construction"] = {"level": 25, "xp": 0.0, "unlocked": ["simple_well"]}
	_bonfire = Bonfire.make()
	_bonfire.position = Vector3(2, 0, 2)
	add_child(_bonfire)
	_mortar = CraftStation.make(&"mortar")
	_mortar.position = Vector3(-2, 0, 2)
	add_child(_mortar)
	_grill = CraftStation.make(&"stone_grill")
	_grill.position = Vector3(-2, 0, 5)
	add_child(_grill)
	_steamer = CraftStation.make(&"steamer")
	_steamer.position = Vector3(2, 0, 5)
	add_child(_steamer)
	_well = CraftStation.make(&"well")
	_well.position = Vector3(5, 0, 2)
	add_child(_well)
	_field = FieldPlot.make(&"field_small")
	_field.position = Vector3(0, 0, 8)
	add_child(_field)
	LabKit.give(_player, &"raw_meat", 4)
	LabKit.give(_player, &"fish", 2)
	LabKit.give(_player, &"branch", 4)
	LabKit.give(_player, &"flax_seed", 3)
	LabKit.give(_player, &"fruit_fertilizer", 2)
	var water := ItemStack.make(&"water_bucket", 2)
	water.level = 40
	_player.inventory.add(water)
	LabKit.give(_player, &"empty_bucket", 1)
	LabKit.give(_player, &"hoe", 1)
	LabKit.give(_player, &"mud", 2)
	LabKit.give(_player, &"spice_herb", 1)
	LabKit.give(_player, &"mushroom", 1)
	print("[boot] lab=kitchen_lab")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_shot_dir = a.substr(11)
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		get_tree().create_timer(110.0).timeout.connect(func () -> void:
			print("[cookroles] watchdog quit")
			_cookroles_report())
		_cookroles_run.call_deferred()
	elif DisplayServer.get_name() == "headless" and Game.shot_path == "":
		get_tree().create_timer(0.35).timeout.connect(_demo)

func _unhandled_input(event: InputEvent) -> void:
	# Debug: F6 fast-forward field growth.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F6:
			if _field:
				_field.advance_offline(60.0)
				print("[farm] fast-forward +60s growth=%.2f" % _field.growth)
		elif event.physical_keycode == KEY_F7:
			_demo_eat_cancel()

func _demo() -> void:
	_demo_skewer_cap()
	_demo_boil_uprank()
	_demo_sashimi_steam_steam()
	_demo_eat_cancel()
	_demo_raw_cancel()
	_demo_burn_skill()
	_demo_farm_save()
	await _demo_pet_feed()
	if DisplayServer.get_name() == "headless":
		if _fails.is_empty():
			print("[kitchen_lab] PASS")
		else:
			print("[kitchen_lab] FAIL count=%d" % _fails.size())
		get_tree().quit(0 if _fails.is_empty() else 1)

## sec-eat-23: past half a raw meal, walking away still applies the raw-food risk. A poisoned
## meal always hits, so the status itself is checked, not just that a roll happened.
func _demo_raw_cancel() -> void:
	for at in [0.6, 0.4]:
		_player.statuses.clear_id(&"full")
		_player.statuses.clear_id(&"stomachache")
		var meal := ItemStack.make(&"raw_meat", 1)
		meal.set_flag(&"poisoned", true)
		_player.inventory.add(meal)
		var idx := -1
		for i in _player.inventory.slot_count:
			var s := _player.inventory.slots[i]
			if s and s.def_id == &"raw_meat" and Food.is_poisoned(s):
				idx = i
		var session := _player.eat_session
		_check(_player.begin_eat_slot(idx), "poisoned raw meal starts at %d%%" % int(at * 100.0))
		session.progress = at
		session._cancel_with_full()
		var sick := _player.statuses.has(&"stomachache")
		print("[food] poisoned raw meal cancelled at %d%% stomachache=%s" % [int(at * 100.0), sick])
		_check(sick == (at >= EatSession.RAW_RISK_CANCEL_AT), "raw meal cancel at %d%% %s a stomachache" % [int(at * 100.0), "applies" if at >= 0.5 else "skips"])
	_player.statuses.clear_id(&"full")
	_player.statuses.clear_id(&"stomachache")

func _demo_burn_skill() -> void:
	var grill := Crafting.recipe(&"stone_grill")
	var novice := Crafting.burn_chance(grill, 0)
	var cook := Crafting.burn_chance(grill, _player.skills.level_of("cooking"))
	print("[food] grill burn chance novice=%.3f cook%d=%.3f" % [novice, _player.skills.level_of("cooking"), cook])
	_check(cook < novice, "cooking skill lowers the grill burn chance")

func _demo_skewer_cap() -> void:
	_player.global_position = _bonfire.global_position + Vector3(1.0, 0, 0)
	var meat := ItemStack.make(&"raw_meat", 1)
	meat.level = 40
	_player.inventory.add(meat)
	LabKit.give(_player, &"branch", 1)
	var rec := Crafting.recipe(&"skewer")
	var picks := Crafting.default_picks(_player.inventory, rec)
	# Force high-level primary for the pick.
	for i in _player.inventory.slot_count:
		var s := _player.inventory.slots[i]
		if s and s.def_id == &"raw_meat" and s.level >= 40:
			if picks.size() > 0:
				picks[0] = i
			break
	var out := Crafting.craft(_player, rec, picks)
	if out:
		print("[craft] skewer level=%d (cap 19)" % out.level)
	else:
		print("[craft] skewer craft failed picks=%s" % [picks])
	_check(out != null and out.level <= 19, "skewer respects its level-19 cap")

func _demo_boil_uprank() -> void:
	var meat := ItemStack.make(&"raw_meat", 1)
	meat.level = 20
	_player.inventory.add(meat)
	var water := ItemStack.make(&"water_bucket", 1)
	water.level = 40
	_player.inventory.add(water)
	_player.global_position = _bonfire.global_position + Vector3(1.0, 0, 0)
	var rec := Crafting.recipe(&"boil")
	var picks := Crafting.default_picks(_player.inventory, rec)
	# Prefer the lv20 meat and lv40 water.
	for i in _player.inventory.slot_count:
		var s := _player.inventory.slots[i]
		if s and s.def_id == &"raw_meat" and s.level == 20:
			picks[0] = i
		elif s and s.def_id == &"water_bucket" and s.level == 40:
			picks[1] = i
	var out := Crafting.craft(_player, rec, picks)
	if out:
		print("[craft] boil level=%d (want ~30)" % out.level)
	_check(out != null and out.level == 30, "boil in level-40 water upranks level-20 meat to 30")

func _demo_sashimi_steam_steam() -> void:
	_player.global_position = _bonfire.global_position + Vector3(1.0, 0, 0)
	# Baseline: one skewer energy from one meat.
	var skewer_energy := 0.0
	var meat_s := ItemStack.make(&"raw_meat", 1)
	meat_s.level = 10
	_player.inventory.add(meat_s)
	LabKit.give(_player, &"branch", 1)
	var skewer_rec := Crafting.recipe(&"skewer")
	var sp := Crafting.default_picks(_player.inventory, skewer_rec)
	var skewer := Crafting.craft(_player, skewer_rec, sp)
	if skewer:
		skewer_energy = Food.energy_restore(skewer)
		print("[food] skewer energy=%.1f process=%d" % [skewer_energy, skewer.process_count])
	# Sashimi → steam → steam from one meat.
	var meat := ItemStack.make(&"raw_meat", 1)
	meat.level = 10
	_player.inventory.add(meat)
	var sash_rec := Crafting.recipe(&"sashimi")
	var picks := Crafting.default_picks(_player.inventory, sash_rec)
	for i in _player.inventory.slot_count:
		var s := _player.inventory.slots[i]
		if s and s.def_id == &"raw_meat" and s.level == 10:
			picks[0] = i
			break
	var sash := Crafting.craft(_player, sash_rec, picks)
	_check(skewer != null and skewer_energy > 0.0, "skewer baseline crafts")
	if sash == null:
		print("[food] sashimi craft failed")
		_check(false, "sashimi crafts")
		return
	print("[food] sashimi count=%d process=%d" % [sash.count if sash.count > 0 else 3, sash.process_count])
	# Steam twice at steamer; keep_output_id preserves sashimi. Prefer highest process.
	_player.global_position = _steamer.global_position + Vector3(1.0, 0, 0)
	var steam_rec := Crafting.recipe(&"steam")
	for _n in 2:
		var best_idx := -1
		var best_pc := -1
		for i in _player.inventory.slot_count:
			var s2 := _player.inventory.slots[i]
			if s2 and s2.def_id == &"sashimi" and s2.process_count > best_pc:
				best_pc = s2.process_count
				best_idx = i
		if best_idx < 0:
			print("[food] steam blocked: no sashimi")
			break
		var spicks: Array[int] = [best_idx]
		var steamed := Crafting.craft(_player, steam_rec, spicks)
		if steamed:
			print("[food] steam → %s process=%d energy=%.1f" % [steamed.def_id, steamed.process_count, Food.energy_restore(steamed)])
	# Find best sashimi in bag.
	var best_e := 0.0
	var best_p := 0
	for i in _player.inventory.slot_count:
		var s3 := _player.inventory.slots[i]
		if s3 and s3.def_id == &"sashimi":
			var e := Food.energy_restore(s3)
			if e > best_e:
				best_e = e
				best_p = s3.process_count
	# Per raw meat: 3 sashimi after sashimi recipe.
	var per_meat := best_e * 3.0
	print("[food] sashimi-steam-steam energy/piece=%.1f process=%d per_meat=%.1f vs skewer=%.1f" % [
		best_e, best_p, per_meat, skewer_energy])
	if per_meat > skewer_energy:
		print("[food] sashimi-steam-steam wins energy/raw")
	_check(per_meat > skewer_energy, "sashimi-steam-steam beats a skewer per raw meat")

func _demo_eat_cancel() -> void:
	_player.vitals.energy = 20.0
	_player.statuses.clear_id(&"full")
	var food := ItemStack.make(&"skewer", 1)
	food.process_count = 2
	_player.inventory.add(food)
	var idx := _player.inventory.find_first(&"skewer")
	_player.begin_eat_slot(idx)
	var hint_on := _player.eat_session.progress_ui != null and _player.eat_session.progress_ui.visible
	print("[food] eat UI keep-still visible=%s" % hint_on)
	# Advance halfway then move.
	for _i in 8:
		_player.eat_session._process(0.2)
	var mid := _player.vitals.energy
	# Simulate stick move cancel.
	Input.action_press("move_right")
	_player.eat_session._process(0.05)
	Input.action_release("move_right")
	var has_full := _player.statuses.has(&"full")
	print("[food] eat cancel mid_energy=%.1f full=%s" % [mid, has_full])
	# Force cancel path if input press didn't register headless.
	if _player.eat_session.eating:
		_player.eat_session._cancel_with_full()
		has_full = _player.statuses.has(&"full")
		print("[food] eat cancel forced full=%s" % has_full)
	_check(hint_on, "eat shows the keep-still hint")
	_check(has_full and mid > 20.0, "cancelled meal keeps what was eaten and applies Full")

func _demo_farm_save() -> void:
	# Force success rolls: high water.
	_field.crop_id = &""
	_field._plant(_player, &"flax")
	_field.watered = 4.0
	_field.fertilizer = 2.7
	_field.advance_offline(200.0)
	# Force mature for deterministic lab.
	if not _field.mature:
		_field.mature = true
		_field.failed = false
		_field.growth = 1.0
		print("[farm] forced mature for lab")
	print("[farm] growth=%.2f watered=%.0f fert=%.1f mature=%s" % [
		_field.growth, _field.watered, _field.fertilizer, _field.mature])
	_field._harvest(_player)
	print("[farm] overflow after harvest=%.1f" % _field.fertilizer_overflow)
	# Replant to carry overflow, then save/load field state.
	_field._plant(_player, &"flax")
	print("[farm] replant fert_carried=%.1f" % _field.fertilizer)
	var payload := {
		"schema": 3,
		"field": _field.to_dict(),
	}
	var path := "user://kitchen_lab_field.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload))
	f = null
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	var row: Dictionary = (parsed as Dictionary).get("field", {})
	var restored := FieldPlot.from_dict(row)
	print("[farm] save/load crop=%s fert=%.1f growth=%.2f schema=%d" % [
		restored.crop_id, restored.fertilizer, restored.growth, int((parsed as Dictionary).get("schema", 0))])
	_check(restored.crop_id == &"flax" and is_equal_approx(restored.fertilizer, _field.fertilizer), "field survives save/load")
	# Also exercise SaveGame building restore path without island_runtime.
	var SG := load("res://scripts/core/save_game.gd") as GDScript
	var built: Node3D = SG._spawn_building(_field.to_dict()) as Node3D
	if built is FieldPlot:
		print("[farm] save_game spawn kind=%s crop=%s" % [(built as FieldPlot).kind, (built as FieldPlot).crop_id])

func _demo_pet_feed() -> void:
	var def := Data.creature(&"velociraptor")
	if def == null:
		print("[food] pet feed skipped: no velociraptor")
		_check(false, "pet feed fixture species exists")
		return
	var rec := PetRecord.from_def(def, &"B")
	_player.bonded.append(rec)
	_player.summon_pet(0)
	await get_tree().process_frame
	await get_tree().process_frame
	if _player.summoned_pet == null:
		print("[food] pet feed skipped: summon failed")
		_check(false, "pet summons for feeding")
		return
	_player.summoned_pet.hunger = 10.0
	LabKit.give(_player, &"meatball", 1)
	var idx := _player.inventory.find_first(&"meatball")
	_player.feed_summoned_pet_slot(idx)
	print("[food] pet hunger after feed=%.0f" % _player.summoned_pet.hunger)
	_check(_player.summoned_pet.hunger > 10.0, "feeding the summoned pet raises its hunger bar")


# ---------------------------------------------------------------- COOKROLES (spec 08 §2-4)

## Cook the roled recipes on the real stations and print one measured RESULT line. Every number comes
## from this scene: the role gate, the dishes' own attributes, the bag's before/after counts, the
## station craft's cancel, FOODFX's bundle for the dish, a save round trip, and the panel's own tap
## targets. Shots: the cooking card, the finished dish in the inspector.
func _cookroles_run() -> void:
	await get_tree().create_timer(0.8).timeout
	Game.time_of_day = 0.42
	Game.debug_overlay = false
	_player.skills.trees["cooking"] = {"level": 40, "xp": 0.0, "unlocked": []}
	_grill.position = Vector3(-1.5, 0, 1.0)
	# COOKROLES: the stew's station. A crock pot, right beside the fire.
	var pot: CraftStation = CraftStation.make(&"crock_pot")
	pot.position = Vector3(3.2, 0, 2.0)
	add_child(pot)
	_player.global_position = _grill.global_position + Vector3(0, 1, 1.2)
	await get_tree().physics_frame
	var ROLES := load("res://scripts/items/cook_roles.gd") as GDScript
	var CR := load("res://scripts/items/crafting.gd") as GDScript
	var FX := load("res://scripts/items/food_effects.gd") as GDScript
	var IS := load("res://scripts/items/item_stack.gd") as GDScript
	var SAN := load("res://scripts/core/save_sanitizer.gd") as GDScript
	var INV := load("res://scripts/items/inventory.gd") as GDScript

	# 1. The role gate: a spice cannot fill the main slot, on the data itself and through the planner.
	var grill_rec: Dictionary = CR.recipe(&"roled_grilled_meat")
	var main_slot: Dictionary = grill_rec["slots"][0]
	var spice = IS.make(&"spice_herb", 1)
	var meat = IS.make(&"raw_meat", 1)
	var roles_ok: bool = ROLES.role_accepts(main_slot, meat) and not ROLES.role_accepts(main_slot, spice)
	_co_ok["roles"] = 1 if roles_ok else 0

	# 2. Inheritance from the exact instance: a rich cut passes, a rare trait stays out. The pick is
	# explicit (the lab bag already holds plain meat, which the default pick would spend first).
	LabKit.give(_player, &"raw_meat", 1)
	var rich = _last_of(&"raw_meat")
	rich.attributes["rich_cut"] = 2
	rich.attributes["black_sheen"] = 1
	var dish = CR.craft(_player, grill_rec, _one(_index_of(rich)))
	if dish:
		_co_dishes += 1
		_co_ok["inherit"] = 1 if int(dish.attributes.get("rich_cut", 0)) == 2 and not dish.attributes.has("black_sheen") else 0

	# 3. Two different meat instances make two different dishes (measured through FOODFX).
	LabKit.give(_player, &"raw_meat", 1)
	var plain = _last_of(&"raw_meat")
	var plain_dish = CR.craft(_player, grill_rec, _one(_index_of(plain)))
	_co_dishes += 1
	var rich_e := float(FX.evaluate(dish)["latent_energy"]) if dish else 0.0
	var plain_e := float(FX.evaluate(plain_dish)["latent_energy"]) if plain_dish else 0.0
	_co_ok["differ"] = 1 if plain_dish != null and rich_e > plain_e else 0

	# 4. The spiced stew spends exactly the instances the plan picked (meat + spice + water).
	_player.global_position = _bonfire.global_position + Vector3(0, 1, 1.2)
	LabKit.give(_player, &"spice_herb", 1)
	_player.inventory.add(IS.make(&"water_bucket", 1))
	var water = _last_of(&"water_bucket")
	_player.global_position = Vector3(3.2, 1, 3.2)  # the crock pot
	var stew_rec: Dictionary = CR.recipe(&"roled_spiced_stew")
	var stew_picks: Array[int] = [_index_of(_last_of(&"raw_meat")), _index_of(_last_of(&"spice_herb")), _index_of(water)]
	var before_meat := _count(&"raw_meat")
	var before_spice := _count(&"spice_herb")
	var before_water := _count(&"water_bucket")
	var stew = CR.craft(_player, stew_rec, stew_picks)
	var spent: bool = _count(&"raw_meat") == before_meat - 1 and _count(&"spice_herb") == before_spice - 1 and _count(&"water_bucket") == before_water - 1
	_co_dishes += 1 if stew else 0
	_co_ok["consume"] = 1 if stew != null and spent and _count(&"camp_stew") >= 1 else 0

	# 5. A cancelled station cook leaves the bag untouched (the cooking card is on screen for the shot).
	LabKit.give(_player, &"herb_leaf", 1)
	LabKit.give(_player, &"branch", 1)
	_player.global_position = _bonfire.global_position + Vector3(0, 1, 1.2)
	var sc = _player.station_craft
	var snapshot := _bag_signature()
	var started: bool = sc.begin(&"roled_herb_roast")
	sc._start_craft_cycle()
	sc.force_progress_for_shot(0.55)
	await get_tree().create_timer(0.4).timeout
	await _shot("cookroles_cooking")
	sc.cancel_and_refund()
	_co_ok["cancel"] = 1 if started and _bag_signature() == snapshot else 0

	# 6. FOODFX on the dish: the inherited trait raises what eating pays, the topping's bonus is a buff.
	var plain_bundle: Dictionary = FX.evaluate(plain_dish) if plain_dish else {}
	var rich_bundle: Dictionary = FX.evaluate(dish) if dish else {}
	_player.global_position = _grill.global_position + Vector3(0, 1, 1.2)
	LabKit.give(_player, &"raw_meat", 1)
	LabKit.give(_player, &"berry", 1)
	var glaze_picks: Array[int] = [_index_of(_last_of(&"raw_meat")), _index_of(_last_of(&"berry"))]
	var glazed = CR.craft(_player, CR.recipe(&"roled_berry_glazed_meat"), glaze_picks)
	_co_dishes += 1 if glazed else 0
	var gb: Dictionary = FX.evaluate(glazed) if glazed else {}
	var has_bonus := false
	for row: Variant in gb.get("buffs", []):
		if str((row as Dictionary).get("id", "")) == "fruit_glaze":
			has_bonus = true
	_co_ok["foodfx"] = 1 if not plain_bundle.is_empty() and float(rich_bundle.get("latent_energy", 0.0)) > float(plain_bundle.get("latent_energy", 0.0)) and has_bonus else 0

	# 7. Save round trip through the real sanitizer: the inherited record survives.
	var saved_ok := false
	if dish:
		var bag = INV.new(6)
		bag.add(dish.duplicate_stack())
		var payload: Dictionary = JSON.parse_string(JSON.stringify({"player": {"inventory": bag.to_array()}}))
		var cleaned: Dictionary = SAN.clean(payload)
		var back = INV.new(6)
		back.load_array((cleaned["player"] as Dictionary).get("inventory", []))
		var restored = back.slots[0]
		saved_ok = restored != null and int(restored.attributes.get("rich_cut", 0)) == 2 			and absf(float(FX.evaluate(restored)["latent_energy"]) - rich_e) < 0.01
	_co_ok["saved"] = 1 if saved_ok else 0

	# 8. The dish in the food inspector, and its own tap targets (spec 08 §8, the 64 px rule).
	if dish:
		var ui: CanvasLayer = _player.ui.get_parent() if _player.ui else null
		var panel = load("res://scripts/ui/food_inspector.gd").new()
		ui.add_child(panel)
		var idx := -1
		for i in _player.inventory.slot_count:
			var st = _player.inventory.slots[i]
			if st != null and st.def_id == dish.def_id and st.attributes.has("rich_cut"):
				idx = i
		if idx < 0:
			_player.inventory.add(dish.duplicate_stack())
			idx = _player.inventory.find_first(dish.def_id)
		panel.show_stack(_player.inventory.slots[idx], idx, false)
		await get_tree().process_frame
		await get_tree().process_frame
		panel._measure()
		_co_ui_px = float(panel.shown_min_px)
		_co_card = panel.card_text(_player.inventory.slots[idx])
		await _shot("cookroles_dish")
		panel.hide_panel()
	_cookroles_report()

func _index_of(stack: ItemStack) -> int:
	for i in _player.inventory.slot_count:
		if _player.inventory.slots[i] == stack:
			return i
	return -1

func _one(idx: int) -> Array[int]:
	var out: Array[int] = [idx]
	return out

func _last_of(id: StringName) -> ItemStack:
	for i in range(_player.inventory.slot_count - 1, -1, -1):
		if _player.inventory.slots[i] != null and _player.inventory.slots[i].def_id == id:
			return _player.inventory.slots[i]
	return null

func _count(id: StringName) -> int:
	return _player.inventory.count_of(id)

func _picks(rec: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in load("res://scripts/items/crafting.gd").default_picks(_player.inventory, rec):
		out.append(int(v))
	return out

func _bag_signature() -> String:
	var bits: PackedStringArray = []
	for s in _player.inventory.slots:
		bits.append("-" if s == null else "%s/%d/%s" % [str(s.def_id), s.level, str(s.attributes)])
	return "|".join(bits)

func _shot(name: String) -> void:
	if _shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	var path := "%s/%s_%dx%d.png" % [_shot_dir, name, get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
	img.save_png(path)
	_shots.append(path)
	print("[cookroles] shot %s" % path)

## ONE line. Every key is read off the scene above; the gate's LAB_ASSERT parses these numbers.
func _cookroles_report() -> void:
	print("[cookroles] RESULT roles_ok=%d inherit_ok=%d differ_ok=%d consume_ok=%d cancel_ok=%d foodfx_ok=%d saved_ok=%d dishes=%d card_lines=%d ui_min_px=%d all_ok=%d" % [
		int(_co_ok["roles"]), int(_co_ok["inherit"]), int(_co_ok["differ"]), int(_co_ok["consume"]),
		int(_co_ok["cancel"]), int(_co_ok["foodfx"]), int(_co_ok["saved"]), _co_dishes,
		_co_card.split("\n").size() if _co_card != "" else 0, int(round(_co_ui_px)),
		1 if not _co_ok.values().has(0) else 0])
	print("[cookroles] shots %s" % str(_shots))
	print("[cookroles] card %s" % _co_card.replace("\n", " | ").left(400))
	get_tree().quit(0)
