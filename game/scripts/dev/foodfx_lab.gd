extends Node3D
## FOODFX lab (spec 32). Drives the real systems a player drives and prints ONE measured result line:
##   [foodfx] RESULT instant_split_ok= digest_once_ok= interrupt_refunds= double_eat_blocked=
##            buff_slots_ok= maxfatigue_expiry_ok= fatigue_vs_maxfatigue_ok= buff_coexist_ok=
##            plain_food_keeps_buff= ability_check_moves= bad_food_status= taste_grade_ok=
##            save_roundtrip= ui_min_px=
## Every number is read off the live scene (Vitals, StatusEffects, BuffSlots, Digestion, the panel's own
## measured tap targets), never a constant. With --shot-dir it also saves the food inspect panel and
## the two drinks; a headless run cannot draw, so screenshots are skipped there and the RESULT line
## still prints (the gate's HEADLESS_ONLY mode defers visual approval).
##   Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- \
##     --lab=foodfx_lab --shot-dir=DIR        (again with --resolution 844x390)

const DIGEST_WAIT_S := 120.0  # real seconds the lab gives digestion before reading it

var _out := ""
var _player: Player
var _cam: IsoCamera
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _ok := {
	"instant_split": 0, "digest_once": 0, "interrupt_refunds": 0, "double_eat_blocked": 0,
	"buff_slots": 0, "maxfatigue_expiry": 0, "fatigue_vs_maxfatigue": 0, "buff_coexist": 0,
	"plain_food_keeps_buff": 0, "ability_check_moves": 0, "bad_food_status": 0, "taste_grade": 0,
	"save_roundtrip": 0,
}
var _ui_min_px := 0.0
var _notes: Array[String] = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	_cam = kit["cam"]
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.time_of_day = 0.45
	_player.eat_session.set_process(false)  # the lab drives the food clock itself
	_check_split()
	_check_interrupt_and_double()
	_check_slots_and_caps()
	await _check_fatigue_effects()
	_check_ability_and_taste()
	await _check_bad_food()
	await _check_save()
	await _check_panel()
	_report()

func _report() -> void:
	var line := "[foodfx] RESULT"
	for k in ["instant_split", "digest_once", "interrupt_refunds", "double_eat_blocked", "buff_slots",
			"maxfatigue_expiry", "fatigue_vs_maxfatigue", "buff_coexist", "plain_food_keeps_buff",
			"ability_check_moves", "bad_food_status", "taste_grade", "save_roundtrip"]:
		line += " %s_ok=%d" % [k, int(_ok[k])]
	line += " ui_min_px=%d" % int(round(_ui_min_px))
	print(line)
	for n in _notes:
		print("[foodfx] note %s" % n)
	get_tree().quit(0)

# ---------------------------------------------------------------- helpers

func _fresh() -> void:
	_player.statuses.from_array([])
	BuffSlots.of(_player).from_dict({})
	BuffSlots.of(_player).apply(_player, [])
	Digestion.of(_player).from_dict({})
	_player.vitals.energy = 20.0
	_player.vitals.fatigue = 0.0
	_player.vitals.max_fatigue = 100.0
	_player.vitals.max_energy = 100.0
	_player.vitals.sync_food_caps(0.0, 0.0)
	_clock = 0.0

func _give(id: StringName) -> int:
	_player.inventory.add(ItemStack.make(id, 1))
	for i in _player.inventory.slot_count:
		var s: Variant = _player.inventory.slots[i]
		if s != null and s.def_id == id:
			return i
	return -1

func _eat(idx: int) -> bool:
	if idx < 0:
		return false
	var started: bool = _player.begin_eat_slot(idx)
	if not started:
		return false
	var guard := 0
	while _player.eat_session.eating and guard < 2000:
		_player.eat_session.advance(0.1)
		guard += 1
	return guard < 2000

## Food clock: buff expiry + digestion, driven in steps the way play does.
func _tick(seconds: float) -> void:
	var left := seconds
	while left > 0.0001:
		var step := minf(0.1, left)
		BuffSlots.of(_player).tick(_player, step)
		Digestion.of(_player).tick(_player, step)
		left -= step
		_clock += step

func _shot(name: String) -> void:
	if _out == "":
		return
	if DisplayServer.get_name() == "headless":
		_notes.append("screenshot %s skipped: headless cannot draw" % name)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%s.png" % [_out, name])

# ---------------------------------------------------------------- checks

func _check_split() -> void:
	_fresh()
	var idx := _give(&"tea")
	var stack: Variant = _player.inventory.slots[idx]
	var bundle: Dictionary = FoodEffects.evaluate(stack)
	var instant := float(bundle["instant_energy"])
	var digested := float(bundle["digested_energy"])
	var before: float = _player.vitals.energy
	_eat(idx)
	var gained: float = _player.vitals.energy - before
	var scheduled := Digestion.of(_player).total_remaining()
	_ok["instant_split"] = 1 if absf(gained - instant) < 0.05 and absf(scheduled - digested) < 0.05 else 0
	_notes.append("tea %.1f = %.1f now + %.1f over %.0fs (paid %.1f, scheduled %.1f)" % [instant + digested, instant, digested, float(bundle["digest_seconds"]), gained, scheduled])
	# The whole delayed share, then nothing more.
	_player.vitals.energy = 0.0
	_tick(float(bundle["digest_seconds"]) + 1.0)
	var paid: float = _player.vitals.energy
	_tick(30.0)
	_ok["digest_once"] = 1 if absf(paid - digested) < 0.5 and absf(_player.vitals.energy - paid) < 0.01 else 0
	_notes.append("digestion paid %.1f of %.1f, then %.1f more later" % [paid, digested, _player.vitals.energy - paid])

func _check_interrupt_and_double() -> void:
	_fresh()
	var idx := _give(&"grilled_meat")
	var before: float = _player.vitals.energy
	_player.begin_eat_slot(idx)
	_player.eat_session.advance(0.2)
	_player.eat_session._cancel_with_full()
	var kept := _player.inventory.find_first(&"grilled_meat") >= 0
	_ok["interrupt_refunds"] = 1 if kept and absf(_player.vitals.energy - before) < 0.01 and Digestion.of(_player).rows().is_empty() else 0
	_notes.append("interrupt: item kept=%s energy %.1f -> %.1f" % [str(kept), before, _player.vitals.energy])
	_fresh()
	var t := _give(&"tea")
	var first: bool = _player.begin_eat_slot(t)
	var second: bool = _player.begin_eat_slot(t)
	_ok["double_eat_blocked"] = 1 if first and not second else 0
	var guard := 0
	while _player.eat_session.eating and guard < 200:
		_player.eat_session.advance(0.1)
		guard += 1
	if Digestion.of(_player).rows().size() != 1:
		_ok["double_eat_blocked"] = 0

func _check_slots_and_caps() -> void:
	_fresh()
	_eat(_give(&"crafters_meal"))
	var slots := BuffSlots.of(_player)
	var ability := slots.by_group("enhanced_ability")
	slots.apply(_player, [{"id": "lab_probe", "group": "enhanced_ability", "display_name": "Probe", "duration": 60.0, "stats": {"strength": {"add": 10.0}}}])
	var replaced := str(slots.by_group("enhanced_ability").get("id", ""))
	_ok["buff_slots"] = 1 if not ability.is_empty() and replaced == "lab_probe" else 0
	_notes.append("slot replace: %s -> %s" % [str(ability.get("id", "")), replaced])
	_player.statuses.clear_id(&"full")
	_eat(_give(&"dutch_coffee"))
	var coexist := not slots.by_group("enhanced_ability").is_empty() and not slots.by_group("enhanced_survival").is_empty()
	_ok["buff_coexist"] = 1 if coexist else 0
	# Maximum Fatigue expiry: the ceiling returns, the base does not move, current fatigue is clamped.
	var v := _player.vitals
	var base: float = v.max_fatigue
	var boosted: float = v.effective_max_fatigue()
	v.fatigue = boosted - 1.0
	_tick(1201.0)
	_ok["maxfatigue_expiry"] = 1 if boosted > base + 1.0 and absf(v.max_fatigue - base) < 0.001 and v.fatigue <= v.effective_max_fatigue() + 0.001 and v.fatigue > 0.0 else 0
	_notes.append("max fatigue %.1f -> %.1f, back to %.1f, fatigue now %.1f" % [base, boosted, v.effective_max_fatigue(), v.fatigue])
	# An Energy-only food leaves an unrelated buff alone (a fresh ability meal, so the slot is full).
	_fresh()
	_eat(_give(&"crafters_meal"))
	slots = BuffSlots.of(_player)
	var before: Array = slots.ids()
	_player.statuses.clear_id(&"full")
	_eat(_give(&"grilled_meat"))
	_ok["plain_food_keeps_buff"] = 1 if not before.is_empty() and slots.ids() == before else 0
	_notes.append("plain food kept buffs %s (now %s)" % [str(before), str(slots.ids())])

func _check_fatigue_effects() -> void:
	_fresh()
	_player.vitals.fatigue = 60.0
	_eat(_give(&"fatigue_tonic"))
	var tonic_fatigue: float = _player.vitals.fatigue
	var tonic_cap := _player.vitals.effective_max_fatigue()
	_notes.append("restorative 60 -> %.1f fatigue, cap %.1f" % [tonic_fatigue, tonic_cap])
	_fresh()
	_player.vitals.fatigue = 60.0
	_eat(_give(&"dutch_coffee"))
	var coffee_fatigue: float = _player.vitals.fatigue
	var coffee_cap: float = _player.vitals.effective_max_fatigue()
	_notes.append("Dutch Coffee fatigue %.1f, cap %.1f" % [coffee_fatigue, coffee_cap])
	_ok["fatigue_vs_maxfatigue"] = 1 if tonic_fatigue < 60.0 and absf(tonic_cap - _player.vitals.max_fatigue) > -1.0 and absf(coffee_fatigue - 60.0) < 0.01 and coffee_cap > _player.vitals.max_fatigue + 1.0 else 0
	await _shot("drink_effects")
	_player.statuses.clear_id(&"full")

func _check_ability_and_taste() -> void:
	_fresh()
	var rec: Dictionary = {}
	var recipes: Dictionary = Data.recipes
	for rid: Variant in recipes:
		var row: Dictionary = recipes[rid]
		if float(row.get("required_ability", 0.0)) > 0.0:
			rec = row
			break
	var before: float = Crafting.crafting_ability(_player, rec)
	var chance_before: float = Crafting.success_for(rec, _player)
	_eat(_give(&"crafters_meal"))
	var after: float = Crafting.crafting_ability(_player, rec)
	var chance_after: float = Crafting.success_for(rec, _player)
	_ok["ability_check_moves"] = 1 if after > before + 1.0 and chance_after > chance_before else 0
	_notes.append("craft ability %.1f -> %.1f, success %.3f -> %.3f on %s" % [before, after, chance_before, chance_after, str(rec.get("id", ""))])
	var doc: Dictionary = FoodEffects.doc()
	var great: Dictionary = Taste.score(doc, {"flavors": {"sweet": 40}, "taste_score": 90}, {})
	var horrible: Dictionary = Taste.score(doc, {"flavors": {"sour": 40}, "taste_score": 12}, {})
	_ok["taste_grade"] = 1 if str(great["grade"]) == "phenomenal" and str(horrible["grade"]) == "horrible" else 0
	_notes.append("taste grades: %s / %s" % [str(great["grade"]), str(horrible["grade"])])

func _check_bad_food() -> void:
	_fresh()
	var probe := ItemStack.make(&"berry", 1)
	var seed := -1
	for s in 400:
		_rng.seed = s
		if Food.raw_risk_roll(probe, _rng) == &"stomachache":
			seed = s
			break
	_fresh()
	_give(&"berry")
	_player.eat_session.rng = _rng
	_rng.seed = seed
	_eat(_player.inventory.find_first(&"berry"))
	_player.eat_session.rng = null
	_ok["bad_food_status"] = 1 if _player.statuses.has(&"stomachache") else 0
	_notes.append("raw berry seed %d -> stomachache=%s" % [seed, str(_player.statuses.has(&"stomachache"))])

func _check_save() -> void:
	_fresh()
	_eat(_give(&"tea"))
	_player.statuses.clear_id(&"full")
	_eat(_give(&"dutch_coffee"))
	var digest_before := Digestion.of(_player).total_remaining()
	var buffs_before: Array = BuffSlots.of(_player).ids()
	var cap_before: float = _player.vitals.effective_max_fatigue()
	var saved: bool = SaveGame.save_now()
	SaveGame.load_now(self)
	await get_tree().process_frame
	await get_tree().process_frame
	_player.eat_session.set_process(false)
	var digest_after := Digestion.of(_player).total_remaining()
	var same_buffs: bool = BuffSlots.of(_player).ids() == buffs_before
	_player.vitals.energy = 0.0
	_tick(float(FoodEffects.defaults().get("digest_seconds", 300.0)) + 1.0)
	var paid: float = _player.vitals.energy
	_ok["save_roundtrip"] = 1 if saved and absf(digest_after - digest_before) < 0.5 and same_buffs and absf(_player.vitals.effective_max_fatigue() - cap_before) < 0.5 and absf(paid - digest_after) < 0.6 else 0
	_notes.append("save/load digestion %.1f -> %.1f, paid %.1f once, buffs same=%s, cap %.1f -> %.1f" % [digest_before, digest_after, paid, str(same_buffs), cap_before, _player.vitals.effective_max_fatigue()])

func _check_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := FoodInspector.new()
	layer.add_child(panel)
	_player.statuses.clear_id(&"full")
	var idx := _give(&"dutch_coffee")
	panel.show_stack(_player.inventory.slots[idx], idx, false)
	await get_tree().process_frame
	await get_tree().process_frame
	panel._measure()
	_ui_min_px = panel.shown_min_px
	_notes.append("panel card: %s" % panel._body.text.replace("\n", " | ").left(300))
	_notes.append("panel min tap px=%.0f fits=%s" % [_ui_min_px, str(panel.shown_fits)])
	await _shot("food_inspect_panel")
	panel.hide_panel()
	layer.queue_free()
	await get_tree().process_frame
