extends SceneTree
## W2-PROCESS: in-place processing opportunities and identity (spec 08), process-station jobs on the
## wall clock (running with nobody near), save round trip mid-process (running and waiting jobs), queue
## catch-up, two recipes at once, stage models, collect into a full bag, what each slow station's
## output is worth against the grill, pack-up through every path refusing while anything is on the
## station (review r1 blocker: shift-tap pack-up destroyed what hung on the rack), the exact picked
## instances (spec 08:98), and a destroyed or refunded station keeping its contents (spec 10:102, 11:155).
## Item scripts reference the Data autoload, so they load once it exists.

var failures: Array[String] = []
var _phase := 0
var _frames := 0
var IS: GDScript
var INV: GDScript
var CR: GDScript
var FOOD: GDScript
var CS: GDScript
var PS: GDScript
var _rack: Node3D
var _far: Node3D
var _t0: float = 0.0
var _wait_until: int = 0
var _player: Node3D
var BP: GDScript

func _process(_delta: float) -> bool:
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_frames += 1
	match _phase:
		0:
			IS = load("res://scripts/items/item_stack.gd")
			INV = load("res://scripts/items/inventory.gd")
			CR = load("res://scripts/items/crafting.gd")
			FOOD = load("res://scripts/items/food.gd")
			CS = load("res://scripts/world/craft_station.gd")
			PS = load("res://scripts/world/process_station.gd")
			BP = load("res://scripts/world/build_placer.gd")
			PS.clock_skew_s = 0.0
			var host := Node3D.new()
			get_root().add_child(host)
			_player = load("res://scripts/dev/lab_kit.gd").build(host, 20.0)["player"]
			_test_in_place()
			_test_payoff()
			_test_station_identity()
			_test_queue_catch_up()
			_test_two_recipes_at_once()
			_test_exact_picks()
			_test_craft_route_picks()
			var checks: Dictionary = (load("res://tests/process_checks.gd") as GDScript).new().run(get_root())
			for label in checks:
				_expect(bool(checks[label]), str(label))
			_test_destroyed()
			_test_refund_row()
			_start_rack()
			_phase = 1
			_frames = 0
		1:
			# Nobody within 50 m: jump the clock past the drying time and let the station's own
			# _process (not a test call) finish the jobs.
			if _frames == 2:
				PS.clock_skew_s = 610.0
				_wait_until = Time.get_ticks_msec() + 800  # the station redraws 4x a second
			if _frames > 2 and Time.get_ticks_msec() > _wait_until:
				_check_rack_finished()
				_test_collect_full_bag()
				_test_pack_up()
				_finish()
				return true
	return false

func _expect(ok: bool, label: String) -> void:
	print("[t_process] %s %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		failures.append(label)

func _finish() -> void:
	PS.clock_skew_s = 0.0
	if failures.is_empty():
		print("[t_process] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_process] FAIL %s" % f)
		quit(1)

func _count(inv, id: StringName) -> int:
	var n := 0
	for s in inv.slots:
		if s and s.def_id == id:
			n += s.count
	return n

## Spec 08 §2: in-place processing keeps the instance (uid, provenance, properties), spends one of
## its opportunities and drops the raw tag; a new-food recipe starts fresh; none left = refused.
func _test_in_place() -> void:
	var rec_dry: Dictionary = CR.recipe(&"dry_meat")
	var rec_steam: Dictionary = CR.recipe(&"steam")
	var total := int((PS.rules().get("in_place", {}) as Dictionary).get("opportunities", 0))
	var raw = IS.make(&"raw_meat", 1, {"marbling": 3}, 17)
	raw.stamp_identity("loot", "tester")
	_expect(CR.processing_left(rec_dry, raw) == total, "fresh meat has %d processing opportunities" % total)
	var dried = CR.build_output(rec_dry, raw, raw.level)
	_expect(dried.def_id == &"dried_meat" and dried.uid == raw.uid and dried.origin == "loot" and dried.creator == "tester" and dried.created_at == raw.created_at, "drying keeps the instance identity (uid %s)" % dried.uid)
	_expect(int(dried.attributes.get("marbling", 0)) == 3 and dried.level == 17, "drying keeps the instance's properties and level")
	_expect(dried.attributes.get("processed") == ["dry"] and CR.processing_left(rec_steam, dried) == total - 1, "drying spends one opportunity (history %s)" % [dried.attributes.get("processed")])
	_expect(not FOOD.is_raw(dried), "drying removes the raw tag")
	var steamed = CR.build_output(rec_steam, dried, dried.level)
	_expect(CR.processing_left(rec_steam, steamed) == 0 and steamed.uid == raw.uid, "steaming spends the second; still the same instance")
	var bag = INV.new(4)
	bag.add(steamed.duplicate_stack())
	var picks: Array[int] = [0]
	_expect(not CR.picks_valid(bag, rec_steam, picks), "no opportunities left: a third in-place step is refused")
	var plain = IS.make(&"dried_meat", 1)
	_expect(not dried.can_merge_with(plain) and not plain.can_merge_with(dried), "a processed instance never merges into a plain stack")
	# New-food recipe: sashimi is a new item with fresh opportunities (kitchen's sashimi-steam-steam).
	var sash = CR.build_output(CR.recipe(&"sashimi"), dried, dried.level)
	_expect(not sash.attributes.has("processed") and CR.processing_left(rec_steam, sash) == total, "a new-food recipe starts with fresh opportunities")
	# Saved history survives JSON.
	var back = IS.from_dict(JSON.parse_string(JSON.stringify(steamed.to_dict())))
	_expect(back.uid == raw.uid and CR.processing_left(rec_steam, back) == 0, "identity and spent opportunities survive save/load")
	# A rack refuses meat with nothing left and picks one that has.
	var rack: Node3D = CS.make(&"drying_rack")
	get_root().add_child(rack)
	var ps = PS.of(rack)
	var spent = IS.make(&"raw_meat", 1)
	spent.attributes["processed"] = ["dry", "smoke"]
	var inv = INV.new(4)
	inv.add(spent)
	_expect(ps.load_from(inv, &"dry_meat", 1) == 0 and ps.refuse_reason(inv, &"dry_meat").contains("No processing left"), "the rack refuses meat with no opportunities left: '%s'" % ps.refuse_reason(inv, &"dry_meat"))
	inv.slots[2] = IS.make(&"raw_meat", 1)
	_expect(ps.load_from(inv, &"dry_meat", 1) == 1 and inv.slots[0] != null and inv.slots[2] == null, "the instance that still has one is picked instead")
	rack.free()

## One uid'd instance through a station: the same instance comes out, exactly once (XP once is in process_lab).
func _test_station_identity() -> void:
	var rack: Node3D = CS.make(&"drying_rack")
	get_root().add_child(rack)
	var ps = PS.of(rack)
	var inv = INV.new(6)
	var a = IS.make(&"raw_meat", 1, {}, 9)
	a.stamp_identity("loot", "tester")
	var b = IS.make(&"raw_meat", 1, {}, 31)
	b.stamp_identity("loot", "tester")
	inv.add(a)
	inv.add(b)
	_expect(inv.used_slots() == 2, "two identically named meats with uids keep two slots")
	var uids := [a.uid, b.uid]
	_expect(ps.load_from(inv, &"dry_meat", 2) == 2 and inv.used_slots() == 0, "both instances leave the bag onto the rack")
	ps.advance(PS.now_s() + PS.job_seconds(&"drying_rack", &"dry_meat") + 1.0)
	ps.advance(PS.now_s() + PS.job_seconds(&"drying_rack", &"dry_meat") + 2.0)  # a repeated poll finishes nothing twice
	_expect(ps.ready_count() == 2, "two outputs, not more, after repeated advances (ready %d)" % ps.ready_count())
	var row: Dictionary = JSON.parse_string(JSON.stringify(rack.to_dict()))
	rack.free()
	rack = load("res://scripts/core/save_restore.gd").spawn(row)
	get_root().add_child(rack)
	ps = PS.of(rack)
	_expect(ps.ready_count() == 2, "finished outputs survive save/load (ready %d)" % ps.ready_count())
	var bag = INV.new(6)
	_expect(ps.collect_into(bag) == 2 and ps.collect_into(bag) == 0, "collect moves 2, a second collect moves nothing")
	var got: Array = []
	var levels: Array = []
	for st in bag.slots:
		if st:
			got.append(st.uid)
			levels.append(st.level)
	got.sort()
	uids.sort()
	levels.sort()
	_expect(got == uids and levels == [9, 31], "the same two instances came back, levels kept (%s %s)" % [got, levels])
	# Exactly one copy of each instance: in the bag, none left on the station or in its save row.
	_expect(bag.used_slots() == 2 and ps.contents().is_empty() and not rack.to_dict().has("process"), "after collect each uid exists once (bag %d, station %d, save row %s)" % [bag.used_slots(), ps.contents().size(), rack.to_dict().has("process")])
	rack.free()

## Steamer: 2 slots + 2 queue. Four dishes: the waiting two start the moment the first two finish,
## so a catch-up after 130 s matches a watched run exactly.
func _test_queue_catch_up() -> void:
	PS.clock_skew_s = 0.0
	var st: Node3D = CS.make(&"steamer")
	get_root().add_child(st)
	var ps = PS.of(st)
	var inv = INV.new(8)
	for i in 5:
		inv.add(IS.make(&"dried_meat", 1))
	var n: int = ps.load_from(inv, &"steam", 5)
	var secs: float = PS.job_seconds(&"steamer", &"steam")
	_expect(n == 4 and ps.running_count() == 2 and ps.jobs.size() == 4, "steamer takes 4 (2 run, 2 wait), refuses the 5th: loaded %d" % n)
	var t0: float = ps.jobs[0]["started"]
	ps.advance(t0 + secs * 2.0 + 5.0)
	_expect(ps.jobs.is_empty() and ps.ready_count() == 4, "all four done after two cycles (ready %d)" % ps.ready_count())
	var inv2 = INV.new(8)
	ps.collect_into(inv2)
	_expect(_count(inv2, &"steamed_food") == 4 and ps.ready_count() == 0, "collect moves 4 steamed dishes into the bag")
	st.free()
	# Watched: the third job's start is the first finish, not the advance call.
	var st2: Node3D = CS.make(&"steamer")
	get_root().add_child(st2)
	var ps2 = PS.of(st2)
	var inv3 = INV.new(8)
	for i in 3:
		inv3.add(IS.make(&"dried_meat", 1))
	ps2.load_from(inv3, &"steam", 3)
	var s0: float = ps2.jobs[0]["started"]
	# Saved mid-job with one waiting: it comes back still waiting, then starts at the freeing finish.
	var row: Dictionary = JSON.parse_string(JSON.stringify(st2.to_dict()))
	st2.free()
	st2 = load("res://scripts/core/save_restore.gd").spawn(row)
	get_root().add_child(st2)
	ps2 = PS.of(st2)
	_expect(ps2.jobs.size() == 3 and ps2.running_count() == 2 and float(ps2.jobs[2]["started"]) < 0.0, "reload mid-job: 2 running, the third still waiting (%d/%d)" % [ps2.running_count(), ps2.jobs.size()])
	ps2.advance(s0 + secs + 40.0)
	_expect(ps2.jobs.size() == 1 and absf(float(ps2.jobs[0]["started"]) - (s0 + secs)) < 0.01, "a waiting job starts at the freeing finish time")
	st2.free()

func _start_rack() -> void:
	PS.clock_skew_s = 0.0
	_rack = CS.make(&"drying_rack")
	get_root().add_child(_rack)
	var ps = PS.of(_rack)
	var inv = INV.new(8)
	inv.add(IS.make(&"raw_meat", 4))
	var n: int = ps.load_from(inv, &"dry_meat", 4)
	_expect(n == 4 and _count(inv, &"raw_meat") == 0, "4 raw strips leave the bag onto the rack")
	_expect(ps.stage_id() == "raw" and ps.is_active(), "rack shows the raw stage while active")
	var fx := ps.get_node_or_null("ProcessFx") as CPUParticles3D
	_expect(fx != null and fx.emitting, "smoke is on while the rack works")
	_t0 = ps.jobs[0]["started"]
	var secs: float = PS.job_seconds(&"drying_rack", &"dry_meat")
	PS.clock_skew_s = secs * 0.5
	ps.advance(PS.now_s())
	_expect(ps.stage_id() == "drying", "50 %%: drying stage (%s)" % ps.stage_id())
	# Save at 50 % and reload into a new rack: same start time, same remaining time.
	var row: Dictionary = JSON.parse_string(JSON.stringify(_rack.to_dict()))
	var left_before: float = _t0 + secs - PS.now_s()
	_rack.free()
	_rack = load("res://scripts/core/save_restore.gd").spawn(row)  # the island-load path
	get_root().add_child(_rack)
	ps = PS.of(_rack)
	var left_after: float = float(ps.jobs[0]["started"]) + secs - PS.now_s() if ps.jobs.size() == 4 else -1.0
	_expect(absf(left_after - left_before) < 1.0, "reload mid-process resumes with %.0fs left (was %.0fs)" % [left_after, left_before])
	_expect(ps.label_text().begins_with("Drying 4/4"), "label: '%s'" % ps.label_text())
	PS.clock_skew_s = secs * 0.8
	ps.advance(PS.now_s())
	_expect(ps.stage_id() == "dried", "80 %%: dried stage (%s)" % ps.stage_id())
	# The only survivor-like node is 50 m away; the station never looks for one.
	_far = Node3D.new()
	get_root().add_child(_far)
	_far.global_position = _rack.global_position + Vector3(50, 0, 0)

func _check_rack_finished() -> void:
	var ps = PS.of(_rack)
	_expect(_far.global_position.distance_to(_rack.global_position) >= 50.0, "nobody within 50 m")
	_expect(ps.jobs.is_empty() and ps.ready_count() == 4, "rack finished 4 on its own clock (ready %d)" % ps.ready_count())
	_expect(ps.stage_id() == "dried" and not (ps.get_node("ProcessFx") as CPUParticles3D).emitting, "done: dried strips stay, smoke stops")
	var prop := _rack.get_node_or_null("Prop")
	_expect(prop != null and str(prop.scene_file_path).ends_with("drying_rack_dried.glb"), "the rack shows drying_rack_dried.glb (%s)" % (prop.scene_file_path if prop else "none"))
	_expect(ps.label_text() == "Ready: 4 Dried Meat", "label: '%s'" % ps.label_text())

## What a slow station's output is worth against the grill (stone grill, seconds): spec 08 §2 "in-place
## recipes add cooking properties", §4 "Food benefits must be calculated from the actual prepared
## item's stored state". Fatigue is the survival meter (energy refills by itself out of combat), so the
## meal is measured on a real Vitals the way EatSession feeds it.
func _test_payoff() -> void:
	var raw = IS.make(&"raw_meat", 1)
	var grilled = CR.build_output(CR.recipe(&"stone_grill"), raw, 1)
	var dried = CR.build_output(CR.recipe(&"dry_meat"), raw, 1)
	var smoked = CR.build_output(CR.recipe(&"smoke_meat"), raw, 1)
	var stew = CR.build_output(CR.recipe(&"camp_stew"), raw, 1)
	var steamed = CR.build_output(CR.recipe(&"steam"), grilled, 1)
	var g := _relief(grilled)
	print("[t_process] meal: grilled e=%.1f rel=%.1f | dried e=%.1f rel=%.1f | smoked e=%.1f rel=%.1f buffs=%s | stew e=%.1f rel=%.1f | grilled+steam e=%.1f rel=%.1f" % [
		FOOD.energy_restore(grilled), g, FOOD.energy_restore(dried), _relief(dried), FOOD.energy_restore(smoked), _relief(smoked), FOOD.buff_ids(smoked),
		FOOD.energy_restore(stew), _relief(stew), FOOD.energy_restore(steamed), _relief(steamed)])
	_expect(_relief(dried) > g * 1.5, "drying: dried meat eases more fatigue than grilled (%.1f vs %.1f)" % [_relief(dried), g])
	_expect(_relief(smoked) > g and &"cold_resist" in FOOD.buff_ids(smoked) and FOOD.buff_ids(grilled).is_empty(), "smoking: more relief than grilled (%.1f vs %.1f) and a Warming Meal the grill does not give" % [_relief(smoked), g])
	_expect(FOOD.energy_restore(steamed) > FOOD.energy_restore(grilled) and _relief(steamed) > g, "steaming a grilled meat raises its energy (%.1f -> %.1f)" % [FOOD.energy_restore(grilled), FOOD.energy_restore(steamed)])
	_expect(_relief(stew) > g and stew.attributes.get("processed") == null, "the stew beats grilled meat (%.1f vs %.1f) and is a new food with fresh opportunities" % [_relief(stew), g])
	var plain_dried = IS.make(&"dried_meat", 1)
	_expect(FOOD.fatigue_relief(plain_dried) == 0.0 and FOOD.fatigue_relief(dried) > 0.0, "the effect comes from the stored history, not the item name")
	_expect(FOOD.cooking_properties(IS.make(&"dried_hide", 1, {"processed": ["dry"]})).is_empty(), "a dried hide is not a meal")
	_expect(FOOD.inspector_text(dried).contains("Dried: eases fatigue"), "the food inspector shows the property: %s" % FOOD.inspector_text(dried).replace("\n", " | "))

## Fatigue a meal takes off on a real Vitals: the energy break EatSession feeds plus the properties.
func _relief(meal) -> float:
	var v = load("res://scripts/combat/vitals.gd").new()
	v.fatigue = 90.0
	v.eat(FOOD.energy_restore(meal) * 1.5)
	v.rest(FOOD.fatigue_relief(meal))
	var r: float = 90.0 - v.fatigue
	v.free()
	return r

## The rack runs meat and hide side by side; both finish on time and collect shows each.
func _test_two_recipes_at_once() -> void:
	var rack: Node3D = CS.make(&"drying_rack")
	get_root().add_child(rack)
	var ps = PS.of(rack)
	var inv = INV.new(6)
	inv.add(IS.make(&"raw_meat", 1))
	inv.add(IS.make(&"raw_hide", 1))
	_expect(ps.load_from(inv, &"dry_meat", 1) == 1 and ps.load_from(inv, &"dried_hide", 1) == 1 and ps.running_count() == 2, "meat and hide hang on the rack at once")
	ps.advance(PS.now_s() + maxf(PS.job_seconds(&"drying_rack", &"dry_meat"), PS.job_seconds(&"drying_rack", &"dried_hide")) + 1.0)
	var bag = INV.new(6)
	_expect(ps.collect_into(bag) == 2 and ps.last_collected.size() == 2 and int(ps.last_collected.get(&"dried_meat", 0)) == 1 and int(ps.last_collected.get(&"dried_hide", 0)) == 1, "collect moves both and names each (%s)" % [ps.last_collected])
	rack.free()

## Collect into a full bag: everything stays on the station, nothing is lost or doubled.
func _test_collect_full_bag() -> void:
	var ps = PS.of(_rack)
	var bag = INV.new(1)
	bag.add(IS.make(&"stone", 1))
	_expect(ps.collect_into(bag) == 0 and ps.ready_count() == 4 and _count(bag, &"dried_meat") == 0, "full bag: nothing moves, 4 stay on the rack (ready %d)" % ps.ready_count())
	var bag2 = INV.new(8)
	_expect(ps.collect_into(bag2) == 4 and _count(bag2, &"dried_meat") == 4 and ps.contents().is_empty(), "with room: all 4 dried meat collect, the rack is empty")

## Review r1 blocker: shift-tap pack-up (BuildPlacer.pack_up_node) destroyed what hung on the rack, and
## a refused CraftStation.pack_up had already cancelled the jobs. Every path now asks the station
## first and changes nothing when it refuses.
func _test_pack_up() -> void:
	var world: Node = get_root().get_node("World")
	var was: Dictionary = world.island_def
	world.island_def = {"kind": "private"}  # home: owned land, so only the station's own rule refuses
	var inv = _player.inventory
	for i in inv.slot_count:
		inv.slots[i] = null
	var rack: Node3D = CS.make(&"drying_rack")
	get_root().add_child(rack)
	var ps = PS.of(rack)
	for lv in [5, 7]:
		var m = IS.make(&"raw_meat", 1, {}, lv)
		m.stamp_identity("loot", "tester")
		inv.add(m)
	ps.load_from(inv, &"dry_meat", 2)
	var saved := JSON.stringify(ps.to_dict())
	# Working: shift-tap path.
	var ok: bool = BP.pack_up_node(rack, _player)
	_expect(not ok and not rack.is_queued_for_deletion() and JSON.stringify(ps.to_dict()) == saved and inv.used_slots() == 0, "shift-tap pack-up refuses a working rack and touches nothing: '%s'" % BP.pack_up_blocker(rack))
	# Working, bag with room for the meat but not the kit (the old pack_up cancelled the jobs here).
	for i in inv.slot_count - 2:
		inv.slots[i] = IS.make(&"stone", 1)
	ok = rack.pack_up(_player)
	_expect(not ok and ps.jobs.size() == 2 and JSON.stringify(ps.to_dict()) == saved and _count(inv, &"raw_meat") == 0, "a refused pack-up cancels no job and moves nothing (jobs %d)" % ps.jobs.size())
	for i in inv.slot_count:
		inv.slots[i] = null
	# Finished but not collected.
	ps.advance(PS.now_s() + PS.job_seconds(&"drying_rack", &"dry_meat") + 1.0)
	ok = BP.pack_up_node(rack, _player)
	_expect(not ok and ps.ready_count() == 2 and BP.pack_up_blocker(rack).contains("collect"), "a rack with dried meat waiting refuses: '%s'" % BP.pack_up_blocker(rack))
	# Collected and empty: it packs up into its kit.
	ps.collect_into(inv)
	ok = BP.pack_up_node(rack, _player)
	_expect(ok and rack.is_queued_for_deletion() and inv.count_of(&"drying_rack_kit") == 1 and _count(inv, &"dried_meat") == 2, "an empty rack packs up: kit and both dried meats in the bag")
	world.island_def = was

## Spec 08:98: the first job takes exactly the instances the card picked, never a substitute; only
## queued repeats auto-pick.
func _test_exact_picks() -> void:
	var rack: Node3D = CS.make(&"drying_rack")
	get_root().add_child(rack)
	var ps = PS.of(rack)
	var inv = INV.new(6)
	var a = IS.make(&"raw_meat", 1, {}, 9)
	a.stamp_identity("loot", "tester")
	var b = IS.make(&"raw_meat", 1, {}, 31)
	b.stamp_identity("loot", "tester")
	inv.slots[0] = a
	inv.slots[1] = b
	var pick_b: Array[int] = [1]
	_expect(ps.load_from(inv, &"dry_meat", 1, null, null, pick_b) == 1 and (ps.jobs[0]["inputs"][0]).uid == b.uid and inv.slots[0] != null and inv.slots[0].uid == a.uid, "the rack takes the picked lv 31 meat, not the default lv 9")
	var spent = IS.make(&"raw_meat", 1)
	spent.attributes["processed"] = ["dry", "smoke"]
	inv.slots[2] = spent
	var pick_spent: Array[int] = [2]
	var why: String = ps.refuse_reason(inv, &"dry_meat", null, pick_spent)
	_expect(ps.load_from(inv, &"dry_meat", 1, null, null, pick_spent) == 0 and ps.jobs.size() == 1 and inv.slots[0] != null and inv.slots[2] != null and why == "No processing left on that one.", "a spent pick is refused, the other meat is not substituted: '%s'" % why)
	var pick_gone: Array[int] = [4]
	why = ps.refuse_reason(inv, &"dry_meat", null, pick_gone)
	_expect(ps.load_from(inv, &"dry_meat", 1, null, null, pick_gone) == 0 and why == "That one is no longer in your bag.", "a pick that left the bag is refused: '%s'" % why)
	rack.free()
	# A batch of 2: the pick first, the repeat auto-picks.
	rack = CS.make(&"drying_rack")
	get_root().add_child(rack)
	ps = PS.of(rack)
	inv = INV.new(6)
	var c = IS.make(&"raw_meat", 1, {}, 4)
	c.stamp_identity("loot", "tester")
	var d = IS.make(&"raw_meat", 1, {}, 22)
	d.stamp_identity("loot", "tester")
	inv.slots[0] = c
	inv.slots[3] = d
	var pick_d: Array[int] = [3]
	_expect(ps.load_from(inv, &"dry_meat", 2, null, null, pick_d) == 2 and (ps.jobs[0]["inputs"][0]).uid == d.uid and (ps.jobs[1]["inputs"][0]).uid == c.uid, "a batch takes the pick first, then auto-picks the repeat")
	rack.free()

## Review r1: the game path (StationCraft.begin -> walk -> arrival) re-picked on arrival, so a bag
## change on the way put the lv 31 meat on the rack instead of the previewed lv 9 one. The station now
## takes the previewed uid wherever it moved, and refuses (no substitute) once it left the bag.
func _test_craft_route_picks() -> void:
	var inv = _player.inventory
	for i in inv.slot_count:
		inv.slots[i] = null
	_player.skills.trees["processing"] = {"level": 10, "xp": 0.0, "unlocked": []}
	var rack: Node3D = CS.make(&"drying_rack")
	get_root().add_child(rack)
	rack.global_position = _player.global_position + Vector3(1.0, 0.0, 0.0)
	var ps = PS.of(rack)
	var sc = _player.station_craft
	var a = IS.make(&"raw_meat", 1, {}, 9)
	a.stamp_identity("loot", "tester")
	var b = IS.make(&"raw_meat", 1, {}, 31)
	b.stamp_identity("loot", "tester")
	inv.slots[0] = a
	inv.slots[1] = b
	var ok: bool = sc.begin(&"dry_meat", 1)
	var shown: String = inv.slots[sc._picks[0]].uid if ok and sc._picks.size() == 1 and sc._picks[0] >= 0 else ""
	inv.slots[0] = b  # the bag is sorted on the way to the rack
	inv.slots[1] = a
	sc._start_craft_cycle()
	var took: String = ps.jobs[0]["inputs"][0].uid if ps.jobs.size() == 1 else "none"
	_expect(shown == a.uid and took == a.uid and inv.slots[0] == b, "craft route: the rack takes the previewed instance after a bag sort (previewed %s, took %s)" % [shown, took])
	# The previewed one leaves the bag before arrival: refused, the other meat is not substituted.
	var c = IS.make(&"raw_meat", 1, {}, 4)
	c.stamp_identity("loot", "tester")
	inv.slots[1] = c
	ok = sc.begin(&"dry_meat", 1)
	var picked: String = inv.slots[sc._picks[0]].uid if ok and sc._picks[0] >= 0 else ""
	var stays = c if picked == b.uid else b
	inv.slots[sc._picks[0]] = null  # eaten, dropped or traded on the way
	sc._start_craft_cycle()
	_expect(ok and ps.jobs.size() == 1 and inv.slots.has(stays) and sc.recipe_id == &"", "craft route: a previewed instance gone on arrival is refused, %s stays in the bag" % ("lv %d" % stays.level))
	rack.free()

## Spec 10:102 / 11:155: a station destroyed by damage never deletes what is on it. W2-BUILDSYS's
## StructureHealth asks the host duck-typed (has_method("salvage_contents")) and drops the stacks into
## the bag, home cargo or a loot bag; this checks the station hands over everything exactly once.
func _test_destroyed() -> void:
	var rack: Node3D = CS.make(&"drying_rack")
	get_root().add_child(rack)
	var ps = PS.of(rack)
	var inv = INV.new(6)
	var m = IS.make(&"raw_meat", 1, {}, 12)
	m.stamp_identity("loot", "tester")
	inv.add(m)
	inv.add(IS.make(&"raw_hide", 1))
	inv.add(IS.make(&"raw_meat", 1))
	ps.load_from(inv, &"dry_meat", 1)
	ps.advance(PS.now_s() + PS.job_seconds(&"drying_rack", &"dry_meat") + 1.0)  # meat done
	ps.load_from(inv, &"dried_hide", 1)  # hide still drying
	ps.load_from(inv, &"dry_meat", 1)  # a second meat still drying
	var got: Array = rack.call("salvage_contents") if rack.has_method("salvage_contents") else []
	var ids: Array = []
	var uid_ok := false
	for s in got:
		ids.append(str(s.def_id))
		uid_ok = uid_ok or (s.def_id == &"dried_meat" and s.uid == m.uid)
	ids.sort()
	_expect(ids == ["dried_meat", "raw_hide", "raw_meat"] and uid_ok, "a destroyed rack hands over its dried meat (same uid), the drying hide and the drying meat (%s)" % [ids])
	var again: Array = rack.call("salvage_contents")
	_expect(ps.contents().is_empty() and again.is_empty() and not rack.to_dict().has("process") and not ps.is_active(), "nothing stays on the station, a second salvage hands over nothing")
	rack.free()

## A saved station row that the grid refuses on load is refunded with its jobs and outputs, not just
## the kit (hooks patch: SaveRestore._items_of reads the row's process dict).
func _test_refund_row() -> void:
	var world: Node = get_root().get_node("World")
	var SR: GDScript = load("res://scripts/core/save_restore.gd")
	var was_cargo = world.cargo_home
	world.cargo_home = INV.new(8)
	var rack: Node3D = CS.make(&"drying_rack")
	get_root().add_child(rack)
	var ps = PS.of(rack)
	var inv = INV.new(6)
	inv.add(IS.make(&"raw_meat", 2))
	ps.load_from(inv, &"dry_meat", 2)
	ps.advance(PS.now_s() + PS.job_seconds(&"drying_rack", &"dry_meat") * 0.5)
	var row: Dictionary = JSON.parse_string(JSON.stringify(rack.to_dict()))
	rack.free()
	SR._refund(row, &"drying_rack_kit", "test")
	_expect(_count(world.cargo_home, &"drying_rack_kit") == 1 and _count(world.cargo_home, &"raw_meat") == 2, "a refunded rack row returns its kit and the 2 meats on it (cargo meat %d)" % _count(world.cargo_home, &"raw_meat"))
	world.cargo_home = was_cargo
