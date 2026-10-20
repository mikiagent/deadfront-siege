extends Node3D
## W2-PROCESS lab: a drying rack, smoker, crock pot and steamer running real jobs.
## Headless: the survivor hangs 4 raw strips through the craft route, walks 50 m away, the rack
## finishes on its own clock, COLLECT pays once, the meat is the same instance one step on, and
## eating it applies its own stored energy.
## Prints "[process_lab] PASS" or exits 1.
## Windowed: --lab=process_lab --shot=<png> [--proc=0|50|100] [--proc-view=rack|all]
## sets every station's jobs to that progress and frames the rack or the whole row.

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
	var rack_secs := ProcessStation.job_seconds(&"drying_rack", &"dry_meat")
	# 100 % shows the finished rack: dried strips, smoke out, "Ready" label.
	ProcessStation.clock_skew_s = rack_secs * pct + (1.0 if pct >= 1.0 else 0.0)
	for s in [_rack, _smoker, _pot, _steamer]:
		var ps := ProcessStation.of(s)
		if pct < 1.0 and s != _rack:
			# Keep the other stations mid-job whatever their length, so smoke/steam shows.
			for j in ps.jobs:
				j["started"] = ProcessStation.now_s() - ProcessStation.job_seconds(ps.station_id, StringName(str(j["recipe"]))) * maxf(pct, 0.3)
		ps.advance(ProcessStation.now_s())
		ps._redraw()
	var view := _arg("proc-view", "rack")
	_player.global_position = Vector3(1.6, 0, 2.2) if view == "rack" else Vector3(-1.5, 0, 3.2)
	_player.face_world(_rack.global_position)
	_cam._target = _rack if view == "rack" else _pot
	_cam.size = 4.2 if view == "rack" else 9.0
	_cam._snap()
	print("[process_lab] shot ready proc=%d%% view=%s rack stage=%s label='%s' smoke=%s" % [
		int(pct * 100.0), view, ProcessStation.of(_rack).stage_id(), ProcessStation.of(_rack).label_text(),
		(ProcessStation.of(_rack).get_node("ProcessFx") as CPUParticles3D).emitting])

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
	await get_tree().create_timer(Food.EAT_SECONDS + 0.5).timeout
	_check(_player.vitals.energy > 10.0 and not _player.eat_session.eating, "eaten (energy 10 -> %.1f)" % _player.vitals.energy)
	_check(_player.food_buffs._active.is_empty(), "no invented buff: dried meat carries none (%s)" % [_player.food_buffs._active.keys()])
	ProcessStation.clock_skew_s = 0.0
	if _fails.is_empty():
		print("[process_lab] PASS")
		get_tree().quit(0)
	else:
		print("[process_lab] FAIL %s" % ", ".join(_fails))
		get_tree().quit(1)

func _xp() -> float:
	var t: Dictionary = _player.skills.trees.get("processing", {})
	return float(t.get("level", 0)) * 100000.0 + float(t.get("xp", 0.0))
