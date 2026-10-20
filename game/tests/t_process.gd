extends SceneTree
## W2-PROCESS: in-place processing opportunities and identity (spec 08), process-station jobs on the wall clock (running with nobody near), save
## round trip mid-process, queue catch-up, stage models, steam cap, pack-up returns what hangs.
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
			PS.clock_skew_s = 0.0
			_test_in_place()
			_test_station_identity()
			_test_queue_catch_up()
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

func _test_pack_up() -> void:
	var ps = PS.of(_rack)
	var full = INV.new(1)
	full.add(IS.make(&"stone", 1))
	_expect(not ps.return_all(full) and ps.ready_count() == 4, "pack-up with a full bag refuses and keeps the meat")
	var bag = INV.new(4)
	_expect(ps.return_all(bag) and _count(bag, &"dried_meat") == 4 and ps.contents().is_empty(), "pack-up hands all 4 back")
	_expect(ps.stage_id() == "empty", "empty rack after pack-up")
