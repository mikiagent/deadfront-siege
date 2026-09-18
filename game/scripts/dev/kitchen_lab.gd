extends Node3D
## M7 kitchen lab: cooking path (sashimi-steam-steam), boil uprank, eat cancel, farming field.

var _player: Player
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
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
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
	_demo_farm_save()
	await _demo_pet_feed()
	if DisplayServer.get_name() == "headless":
		get_tree().quit()

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
		if out.level > 19:
			print("[craft] ERROR skewer exceeded level 19")
	else:
		print("[craft] skewer craft failed picks=%s" % [picks])

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
	if sash == null:
		print("[food] sashimi craft failed")
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
	# Also exercise SaveGame building restore path without island_runtime.
	var SG := load("res://scripts/core/save_game.gd") as GDScript
	var built: Node3D = SG._spawn_building(_field.to_dict()) as Node3D
	if built is FieldPlot:
		print("[farm] save_game spawn kind=%s crop=%s" % [(built as FieldPlot).kind, (built as FieldPlot).crop_id])

func _demo_pet_feed() -> void:
	var def := Data.creature(&"velociraptor")
	if def == null:
		print("[food] pet feed skipped: no velociraptor")
		return
	var rec := PetRecord.from_def(def, &"B")
	_player.bonded.append(rec)
	_player.summon_pet(0)
	await get_tree().process_frame
	await get_tree().process_frame
	if _player.summoned_pet == null:
		print("[food] pet feed skipped: summon failed")
		return
	_player.summoned_pet.hunger = 10.0
	LabKit.give(_player, &"meatball", 1)
	var idx := _player.inventory.find_first(&"meatball")
	_player.feed_summoned_pet_slot(idx)
	print("[food] pet hunger after feed=%.0f" % _player.summoned_pet.hunger)
