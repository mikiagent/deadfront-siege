extends SceneTree
## W2-PROCESS: spoilage, process-station jobs on the wall clock (running with nobody near), save
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
			FOOD.clock_skew_s = 0.0
			_test_spoilage()
			_test_steam_cap()
			_test_queue_catch_up()
			_start_rack()
			_phase = 1
			_frames = 0
		1:
			# Nobody within 50 m: jump the clock past the drying time and let the station's own
			# _process (not a test call) finish the jobs.
			if _frames == 2:
				FOOD.clock_skew_s = 610.0
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
	FOOD.clock_skew_s = 0.0
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

func _test_spoilage() -> void:
	FOOD.clock_skew_s = 0.0
	var raw = IS.make(&"raw_meat", 1)
	var dried = IS.make(&"dried_meat", 1)
	var secs: int = FOOD.spoil_seconds(raw.def())
	_expect(secs > 0 and raw.spoil_at > 0, "raw meat starts a spoil clock (%ds)" % secs)
	_expect(dried.spoil_at == 0, "dried meat keeps (no spoil clock)")
	var e_fresh: float = FOOD.energy_restore(raw)
	FOOD.clock_skew_s = float(secs) + 1.0
	_expect(FOOD.is_spoiled(raw), "raw meat spoils after its processing.json time")
	_expect(not FOOD.is_spoiled(dried), "dried meat in the same bag does not spoil")
	_expect(FOOD.energy_restore(raw) < e_fresh * 0.5, "spoiled meat restores less energy (%.1f < %.1f)" % [FOOD.energy_restore(raw), e_fresh])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_expect(FOOD.raw_risk_roll(raw, rng) == &"stomachache", "spoiled meat always gives a stomachache")
	_expect(&"trail_ration" in FOOD.buff_ids(dried), "dried meat carries its buff (%s)" % [FOOD.buff_ids(dried)])
	_expect("SPOILED" in raw.tooltip(), "tooltip says SPOILED")
	# A spoiled stack cannot go on the rack; a fresh one beside it can.
	var inv = INV.new(6)
	inv.add(raw)
	var rack: Node3D = CS.make(&"drying_rack")
	get_root().add_child(rack)
	var ps = PS.of(rack)
	_expect(ps != null, "drying rack gets a ProcessStation")
	_expect(ps.load_from(inv, &"dry_meat", 1) == 0 and _count(inv, &"raw_meat") == 1, "spoiled meat is refused and stays in the bag")
	_expect(ps.refuse_reason(inv, &"dry_meat").contains("Spoiled"), "refusal says why: '%s'" % ps.refuse_reason(inv, &"dry_meat"))
	var fresh = IS.make(&"raw_meat", 1)  # bought now, at the skewed clock
	inv.slots[3] = fresh
	_expect(ps.load_from(inv, &"dry_meat", 1) == 1 and _count(inv, &"raw_meat") == 1, "the fresh stack is picked over the spoiled lead")
	rack.free()
	FOOD.clock_skew_s = 0.0
	# Save rows: a saved clock can only be earlier than a fresh one; old rows get a fresh clock.
	var row: Dictionary = IS.make(&"raw_meat", 1).to_dict()
	_expect(row.has("spoil_at"), "raw meat rows save spoil_at")
	row["spoil_at"] = int(FOOD.now_s()) - 5
	_expect(IS.from_dict(row).spoil_at == row["spoil_at"], "an earlier saved spoil time survives a load")
	row["spoil_at"] = int(FOOD.now_s()) + 999999
	_expect(IS.from_dict(row).spoil_at <= int(FOOD.now_s()) + secs, "a save cannot push spoilage into the future")
	row.erase("spoil_at")
	_expect(IS.from_dict(row).spoil_at > 0, "an old row without spoil_at gets a fresh clock (nothing spoils on upgrade)")
	_expect(not IS.make(&"stone", 1).to_dict().has("spoil_at"), "rows of things that keep keep the old shape")
	# Merging fresh units onto an older stack keeps the older clock.
	var old = IS.make(&"raw_meat", 1)
	old.spoil_at -= 100
	var young = IS.make(&"raw_meat", 1)
	young.take_into(old)
	var older = IS.make(&"raw_meat", 1)
	older.spoil_at -= 300
	older.take_into(old)
	_expect(old.count == 3 and old.spoil_at == older.spoil_at, "a merged stack spoils with its oldest units")

func _test_steam_cap() -> void:
	var rec: Dictionary = CR.recipe(&"steam")
	var dish = IS.make(&"sashimi", 1)
	var cap := int(FOOD.rules().get("steam_cap", 0))
	for i in cap:
		_expect(not CR.steam_capped(rec, dish), "steam %d of %d allowed" % [i + 1, cap])
		dish = CR.build_output(rec, dish, dish.level)
	_expect(CR.steam_capped(rec, dish) and int(dish.attributes.get("steams", 0)) == cap, "steam %d refused (steams=%s)" % [cap + 1, dish.attributes.get("steams")])
	var inv = INV.new(4)
	inv.add(dish)
	var picks: Array[int] = [0]
	_expect(not CR.picks_valid(inv, rec, picks), "picks_valid refuses a capped dish")

## Steamer: 2 slots + 2 queue. Four dishes: the waiting two start the moment the first two finish,
## so a catch-up after 130 s matches a watched run exactly.
func _test_queue_catch_up() -> void:
	FOOD.clock_skew_s = 0.0
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
	FOOD.clock_skew_s = 0.0
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
	FOOD.clock_skew_s = secs * 0.5
	ps.advance(FOOD.now_s())
	_expect(ps.stage_id() == "drying", "50 %%: drying stage (%s)" % ps.stage_id())
	# Save at 50 % and reload into a new rack: same start time, same remaining time.
	var row: Dictionary = JSON.parse_string(JSON.stringify(_rack.to_dict()))
	var left_before: float = _t0 + secs - FOOD.now_s()
	_rack.free()
	_rack = load("res://scripts/core/save_restore.gd").spawn(row)  # the island-load path
	get_root().add_child(_rack)
	ps = PS.of(_rack)
	var left_after: float = float(ps.jobs[0]["started"]) + secs - FOOD.now_s() if ps.jobs.size() == 4 else -1.0
	_expect(absf(left_after - left_before) < 1.0, "reload mid-process resumes with %.0fs left (was %.0fs)" % [left_after, left_before])
	_expect(ps.label_text().begins_with("Drying 4/4"), "label: '%s'" % ps.label_text())
	FOOD.clock_skew_s = secs * 0.8
	ps.advance(FOOD.now_s())
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
