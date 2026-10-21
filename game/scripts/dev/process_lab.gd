extends Node3D
## W2-PROCESS lab: a drying rack, smoker, crock pot and steamer running real jobs.
## Headless: the survivor hangs 4 raw strips through the craft route, walks 50 m away, the rack
## finishes on its own clock, COLLECT pays once, the meat is the same instance one step on, eating
## it applies its stored energy plus the Dried property's fatigue relief, and a smoked meat gives
## the Warming Meal. Shift-tap pack-up refuses while the rack is loaded.
## Prints "[process_lab] PASS" or exits 1.
## Windowed: --lab=process_lab --shot=<png> [--proc=0|50|100] [--proc-view=rack|smoker|crock_pot|steamer|all]
## [--open-menu=1] sets every station's jobs to that progress and frames one station or the whole row
## (with its hex menu open).

var _player: Player
var _cam: IsoCamera
var _rack: CraftStation
var _smoker: CraftStation
var _pot: CraftStation
var _steamer: CraftStation
var _fails: Array[String] = []

func _check(ok: bool, label: String) -> void:
	print("[process_lab] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fails.append(label)

func _ready() -> void:
	ProcessStation.clock_skew_s = 0.0
	var kit := LabKit.build(self)
	_player = kit["player"]
	_cam = kit["cam"]
	_rack = _station(&"drying_rack", Vector3(0, 0, 0))
	_smoker = _station(&"smoker", Vector3(3.6, 0, -0.4))
	_pot = _station(&"crock_pot", Vector3(-3.4, 0, 0.2))
	_steamer = _station(&"steamer", Vector3(-6.2, 0, -0.6))
	print("[boot] lab=process_lab")
	if Game.shot_path != "":
		call_deferred("_shot_setup")
	elif DisplayServer.get_name() == "headless":
		_demo()

func _station(id: StringName, at: Vector3) -> CraftStation:
	var s := CraftStation.make(id)
	s.position = at
	add_child(s)
	return s

func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return fallback

## Fill every station from a lab bag, then put the clock at --proc percent of each job.
func _shot_setup() -> void:
	await get_tree().process_frame
	var pct := clampf(float(_arg("proc", "50")) / 100.0, 0.0, 1.0)
	var inv := Inventory.new(24)
	inv.add(ItemStack.make(&"raw_meat", 8))
	inv.add(ItemStack.make(&"herb_leaf", 1))
	inv.add(ItemStack.make(&"berry", 1))
	inv.add(ItemStack.make(&"dried_meat", 2))
	ProcessStation.of(_rack).load_from(inv, &"dry_meat", 4)
	ProcessStation.of(_smoker).load_from(inv, &"smoke_meat", 3)
	ProcessStation.of(_pot).load_from(inv, &"camp_stew", 1)
	ProcessStation.of(_steamer).load_from(inv, &"steam", 2)
	var stations: Array[CraftStation] = [_rack, _smoker, _pot, _steamer]
	var longest := 0.0
	for s in stations:
		for j in ProcessStation.of(s).jobs:
			longest = maxf(longest, ProcessStation.job_seconds(ProcessStation.of(s).station_id, StringName(str(j["recipe"]))))
	# 100 % finishes every station (smoke out, "Ready" labels); below that every job sits at pct.
	ProcessStation.clock_skew_s = longest + 1.0 if pct >= 1.0 else 0.0
	for s in stations:
		var ps := ProcessStation.of(s)
		if pct < 1.0:
			for j in ps.jobs:
				j["started"] = ProcessStation.now_s() - ProcessStation.job_seconds(ps.station_id, StringName(str(j["recipe"]))) * pct
		ps.advance(ProcessStation.now_s())
		ps._redraw()
	var view := _arg("proc-view", "rack")
	var target: CraftStation = _pot
	for s in stations:
		if str(s.station_id) == view or (view == "rack" and s == _rack):
			target = s
	_player.global_position = target.global_position + (Vector3(1.6, 0, 2.2) if view != "all" else Vector3(1.9, 0, 3.0))
	_player.face_world(target.global_position)
	_cam._target = target
	_cam.size = _cam.default_size if view == "all" else _cam.min_size  # the game's own zoom range, closest for one station
	_cam._snap()
	var tps := ProcessStation.of(target)
	if _arg("open-menu", "") == "1":  # the station's hex menu (COLLECT / CRAFT) open, as a tap does
		_player.global_position = target.global_position + Vector3(1.2, 0, 0.8)
		await get_tree().process_frame
		_player.station_craft.open_station_menu(target)
	get_tree().create_timer(4.0).timeout.connect(_check_labels.bind("shot %s %d%%" % [view, int(pct * 100.0)]))
	print("[process_lab] shot ready proc=%d%% view=%s stage=%s label='%s' fx=%s" % [
		int(pct * 100.0), view, tps.stage_id(), tps.label_text(),
		(tps.get_node("ProcessFx") as CPUParticles3D).emitting if tps.has_node("ProcessFx") else false])

func _demo() -> void:
	await get_tree().process_frame
	var ps := ProcessStation.of(_rack)
	LabKit.give(_player, &"raw_meat", 4)
	_player.global_position = _rack.global_position + Vector3(1.2, 0, 0.8)
	_player.skills.trees["processing"] = {"level": 10, "xp": 0.0, "unlocked": []}
	var ok := _player.station_craft.begin(&"dry_meat", 4)
	for _i in 20:
		await get_tree().process_frame
	_check(ok and ps.jobs.size() == 4, "craft route hangs 4 strips on the rack (jobs %d)" % ps.jobs.size())
	_check(_player.inventory.find_first(&"raw_meat") < 0, "the raw meat left the bag")
	_check(not _player.station_craft.crafting, "the survivor is free: no stand-and-wait craft")
	_check(ps.stage_id() == "raw" and (ps.get_node("ProcessFx") as CPUParticles3D).emitting, "raw stage, smoke on")
	_check_labels("survivor at the loaded rack")
	_player.global_position = _rack.global_position + Vector3(50, 0, 0)
	ProcessStation.clock_skew_s = ProcessStation.job_seconds(&"drying_rack", &"dry_meat") + 2.0
	await get_tree().create_timer(0.6).timeout
	_check(ps.ready_count() == 4 and ps.stage_id() == "dried", "finished with the survivor 50 m away (ready %d, %s)" % [ps.ready_count(), ps.stage_id()])
	_player.global_position = _rack.global_position + Vector3(1.2, 0, 0.8)
	var xp_before := _xp()
	_player.station_craft.open_station_menu(_rack)
	var has_collect := false
	for b in _player.station_craft.menu._buttons:
		has_collect = has_collect or str(b.bottom_text).begins_with("COLLECT")
	_check(has_collect, "the station menu offers COLLECT")
	_player.station_craft._on_menu_action(_rack, &"collect")
	var idx := _player.inventory.find_first(&"dried_meat")
	_check(idx >= 0 and _player.inventory.slots[idx].count == 4, "4 dried meat in the bag")
	_check(_xp() > xp_before, "processing XP paid on collect (%.1f -> %.1f)" % [xp_before, _xp()])
	var xp_once := _xp()
	_player.station_craft._on_menu_action(_rack, &"collect")
	_check(_xp() == xp_once, "a second collect pays nothing")
	# In place (spec 08): the same meat, one processing opportunity spent, the raw tag gone.
	var dried := _player.inventory.slots[idx]
	_check(dried.attributes.get("processed", []) == ["dry"] and not Food.is_raw(dried), "dried meat records the dry step and is no longer raw (%s)" % [dried.attributes.get("processed")])
	# Eating applies what the stored item carries: its energy, and no buff it does not have.
	var expect := Food.energy_restore(dried)
	_player.vitals.energy = 10.0
	_check(_player.eat_session.begin_eat(idx), "eating dried meat starts")
	var meal := _player.eat_session._total_energy
	_check(is_equal_approx(meal, expect), "the meal is the stored item's own %.1f energy (eating %.1f)" % [expect, meal])
	_player.vitals.fatigue = 60.0
	await get_tree().create_timer(Food.EAT_SECONDS + 0.5).timeout
	_check(_player.vitals.energy > 10.0 and not _player.eat_session.eating, "eaten (energy 10 -> %.1f)" % _player.vitals.energy)
	# The meal's energy break (EatSession: 1.5 x energy into Vitals.eat) plus the Dried property.
	var expect_rest := expect * 1.5 * 0.25 + Food.fatigue_relief(dried)
	_check(Food.fatigue_relief(dried) > 0.0 and _player.vitals.fatigue <= 60.0 - expect_rest + 0.5, "Dried eases fatigue: 60 -> %.1f (energy break + %.0f)" % [_player.vitals.fatigue, Food.fatigue_relief(dried)])
	_check(_player.food_buffs._active.is_empty(), "no invented buff: dried meat carries none (%s)" % [_player.food_buffs._active.keys()])
	# Smoked meat: the property's Warming Meal (the existing cold_resist row) from its stored history.
	var smoked := Crafting.build_output(Crafting.recipe(&"smoke_meat"), ItemStack.make(&"raw_meat", 1), 1)
	_player.statuses.clear_id(&"full")
	_player.inventory.add(smoked)
	_check(_player.eat_session.begin_eat(_player.inventory.find_first(&"smoked_meat")), "eating smoked meat starts")
	await get_tree().create_timer(Food.EAT_SECONDS + 0.5).timeout
	_check(_player.climate_resistance()["cold"] >= 1.0, "Smoked gives the Warming Meal: cold resistance %.0f" % _player.climate_resistance()["cold"])
	# Shift-tap pack-up (BuildPlacer.pack_up_node) refuses while the rack holds anything.
	World.island_def = {"kind": "private"}
	LabKit.give(_player, &"raw_meat", 1)
	ps.load_from(_player.inventory, &"dry_meat", 1, _player)
	_check(not BuildPlacer.pack_up_node(_rack, _player) and is_instance_valid(_rack) and ps.jobs.size() == 1, "shift-tap pack-up refuses a loaded rack: '%s'" % BuildPlacer.pack_up_blocker(_rack))
	ProcessStation.clock_skew_s = 0.0
	if _fails.is_empty():
		print("[process_lab] PASS")
		get_tree().quit(0)
	else:
		print("[process_lab] FAIL %s" % ", ".join(_fails))
		get_tree().quit(1)

## Review r1: the job status as a world label ran into the survivor's chip, the HUD panels and the
## next station's label. It is the second line of each station's HUD chip now (HudPills lays the chips
## out): no chip may cover another chip or the survivor, and no station draws world text.
func _check_labels(tag: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud") as HuntHud
	var pills: Array[Rect2] = []
	for k in (hud.drawn_blocks if hud else {}):
		if str(k).begins_with("pill"):
			pills.append(hud.drawn_blocks[k])
	var fig := HudLayout.figure_rect(hud) if hud else Rect2()
	var hits := 0
	for i in pills.size():
		hits += 1 if pills[i].intersects(fig) else 0
		for j in range(i + 1, pills.size()):
			hits += 1 if pills[i].intersects(pills[j]) else 0
	var world_text := 0
	for s: Node in [_rack, _smoker, _pot, _steamer]:
		world_text += s.find_children("*", "Label3D", true, false).size()
	_check(not pills.is_empty() and hits == 0 and world_text == 0, "%s: %d chips, %d overlaps (chip on chip or on the survivor), %d station world labels" % [tag, pills.size(), hits, world_text])

func _xp() -> float:
	var t: Dictionary = _player.skills.trees.get("processing", {})
	return float(t.get("level", 0)) * 100000.0 + float(t.get("xp", 0.0))
