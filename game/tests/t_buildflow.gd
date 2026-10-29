extends SceneTree
## W2-BUILDFLOW acceptance (owner's spec 30, phases 1-3): construction components from tags, the
## Craft/Build blueprint with its exact unmet prerequisites, a placement that creates a persistent
## ConstructionSite (never a working station), exact-instance escrow deposits, work, atomic
## completion into one leveled Workbench, and a real queued processing job collected exactly once.
## §17 items 1-6, 8-10, 12-14, 16, 18. Run:
##   Godot --headless --path game --script res://tests/t_buildflow.gd
## Scripts are load()ed on the first frame: --script compiles this before the autoloads exist.

var _fails: PackedStringArray = []
var _started := false
var _IS: GDScript
var _INV: GDScript
var _BF: GDScript
var _BP: GDScript
var _BLUEPRINTS: GDScript
var _SITE: GDScript
var _CS: GDScript
var _PS: GDScript
var _CR: GDScript
var _player: Node3D
var _host: Node3D
var _grid: Node
var _rt: Node3D
var _cell := Vector2i.ZERO
var _site: Node3D
var _site_cell := Vector2i.ZERO

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_buildflow] FAIL %s" % what)
	else:
		print("[t_buildflow] ok %s" % what)

func _run() -> void:
	_IS = load("res://scripts/items/item_stack.gd")
	_INV = load("res://scripts/items/inventory.gd")
	_CR = load("res://scripts/items/crafting.gd")
	_BP = load("res://scripts/world/build_placer.gd")
	_BF = load("res://scripts/items/build_flow.gd")
	_BLUEPRINTS = load("res://scripts/items/blueprints.gd")
	_SITE = load("res://scripts/world/construction_site.gd")
	_CS = load("res://scripts/world/craft_station.gd")
	_PS = load("res://scripts/world/process_station.gd")
	_host = Node3D.new()
	_host.name = "TBuildflowHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 20.0)
	_player = kit["player"]
	var world: Node = root.get_node("World")
	world.load_island(_host, &"temperate_25", Vector3(0, 1, 12), false)
	var kit_floor := _host.get_node_or_null("Floor")
	if kit_floor:
		kit_floor.free()
	await process_frame
	await physics_frame
	_rt = world.runtime
	_grid = _rt.get("build_grid")
	_grid.ignore_distance = true
	_learn_workbench()
	_cell = _free_cell()
	_test_components()
	_test_specific_instances()
	_test_blueprint_prerequisites()
	_test_placement()
	_test_escrow_two_contributors()
	_test_save_partial()
	_test_work_and_completion()
	_season_processing()
	_test_station_job()
	_test_cancel_and_farm()
	if _fails.is_empty():
		print("[t_buildflow] PASS")
		quit(0)
	else:
		print("[t_buildflow] FAIL count=%d" % _fails.size())
		quit(1)

func _free_cell() -> Vector2i:
	var first: Variant = _rt.claims[0]
	for z in range(first.position.y, first.end.y):
		for x in range(first.position.x, first.end.x):
			var c := Vector2i(x, z)
			if _grid.can_place(&"workbench", c, 0) == "":
				return c
	return Vector2i.ZERO

func _give(id: StringName, n: int = 1, level: int = -1) -> Object:
	var s = _IS.make(id, n, {}, level)
	_player.inventory.add(s)
	return s

## The gate is the trees.json 'workbench' construction node (Lv 5, behind Bonfire); learn it the
## real way (SP paid from the character level, so hand the character the SP the nodes cost).
func _learn_workbench() -> void:
	var sk: Node = _player.skills
	sk.trees["construction"]["level"] = 20
	sk._learn_autos("construction")
	if sk.is_unlocked("construction", "workbench"):
		return
	sk.sp_extra = 200
	sk._recount_sp()
	if not sk.is_unlocked("construction", "bonfire"):
		sk.unlock("construction", "bonfire")
	sk.unlock("construction", "workbench")

## Processing at a low level caps every output at that level (the ingredient's level would be lost
## for a reason that is not this system), so the survivor here is a seasoned processor.
func _season_processing() -> void:
	_player.skills.trees["processing"]["level"] = 60
	_player.skills.trees["processing"]["xp"] = 0.0

func _clear_bag() -> void:
	for i in _player.inventory.slot_count:
		_player.inventory.slots[i] = null

# ---------------------------------------------------------------- §17 1-3 components

func _test_components() -> void:
	var log = _IS.make(&"wood_log", 1, {}, 12)
	var bag = _INV.new(10)
	bag.add(log)
	var picks: Array[int] = [0]
	var made: Array = _CR.consume_for_craft(bag, _CR.recipe(&"plank_shape"), picks)
	var out = _CR.build_output(_CR.recipe(&"plank_shape"), made[0], 12, made) if not made.is_empty() else null
	_expect(out != null and out.def_id == &"plank_shape" and out.level == 12 and _CR.recipe(&"plank_shape").get("slots", [{}])[0].get("category") == "log",
		"a log is accepted by the Plank Shape slot (got %s lv %s)" % [out.def_id if out else "none", out.level if out else -1])
	var wrong = _INV.new(4)
	wrong.add(_IS.make(&"stone", 2))
	_expect(not _CR.picks_valid(wrong, _CR.recipe(&"plank_shape"), _CR.default_picks(wrong, _CR.recipe(&"plank_shape"))),
		"a stone is refused by the Plank Shape slot")
	var strap_rec: Dictionary = _CR.recipe(&"strap")
	var reeds = _INV.new(10)
	reeds.add(_IS.make(&"reed", 1, {}, 7))
	reeds.add(_IS.make(&"root", 1, {}, 21))
	_expect(_CR.picks_valid(reeds, strap_rec, [0] as Array[int]) and _CR.picks_valid(reeds, strap_rec, [1] as Array[int]),
		"reed and root both satisfy the Strap slot")
	var not_strap = _INV.new(4)
	not_strap.add(_IS.make(&"stone", 1))
	_expect(not _CR.picks_valid(not_strap, strap_rec, _CR.default_picks(not_strap, strap_rec)), "stone makes no strap")

# ---------------------------------------------------------------- §17 2-3 level and identity

func _test_specific_instances() -> void:
	_clear_bag()
	var low := _give(&"wood_log", 1, 5)
	var high := _give(&"wood_log", 1, 50)
	var r: Dictionary = _CR.recipe(&"plank_shape")
	var low_out = _CR.build_output(r, low, low.level)
	var high_out = _CR.build_output(r, high, high.level)
	_expect(low_out.level == 5 and high_out.level == 50 and low_out.uid == "" and high_out.uid == "",
		"low and high logs preview distinct component levels (5 vs 50)")
	# A rare component keeps its identity and traits through a deposit into escrow.
	var rare = _IS.make(&"plank_shape", 1, {"rare": "splits_easily"}, 31)
	rare.stamp_identity("craft", "tester")
	_player.inventory.add(rare)
	var site: Node3D = _BF.place_site(_player, &"basic_workbench", _cell, 0)
	_expect(site != null, "a site exists to receive the rare component")
	if site == null:
		return
	_player.inventory.slots = _player.inventory.slots
	var at := -1
	for i in _player.inventory.slot_count:
		var held_i = _player.inventory.slots[i]
		if held_i != null and held_i.def_id == &"plank_shape" and held_i.level == 31:
			at = i
			rare = held_i  # the bag keeps its own instance (the source's first unit moves in)
	_expect(at >= 0 and site.deposit(0, at), "the rare component deposits into its slot")
	var held: Array = site.escrow()
	var kept: bool = held.size() == 1 and held[0].uid == rare.uid and str(held[0].attributes.get("rare", "")) == "splits_easily"
	_expect(kept, "its uid and trait stay intact in escrow (%s)" % [held.map(func (s) -> String: return s.uid)])
	var back_at := -1
	_expect(site.withdraw(0), "withdraw takes the instance out of escrow")
	for i in _player.inventory.slot_count:
		if _player.inventory.slots[i] != null and _player.inventory.slots[i].uid == rare.uid:
			back_at = i
	_expect(back_at >= 0 and site.escrow().is_empty(), "withdraw moves the same instance back to the bag, no copy")
	# Remove the site again so the placement test starts clean.
	BF_free(site)

func BF_free(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	if _grid:
		_grid.release(n)
	n.queue_free()

# ---------------------------------------------------------------- §17 4-5 prerequisites

func _test_blueprint_prerequisites() -> void:
	var bp: Dictionary = _BLUEPRINTS.of(&"basic_workbench")
	_expect(not bp.is_empty(), "blueprints.json has basic_workbench")
	_player.skills.trees["construction"]["level"] = 1
	_player.skills.trees["construction"]["unlocked"] = []
	var missing: Array = _BLUEPRINTS.unmet(_player, bp)
	_expect(missing.size() >= 2 and str(missing).contains("Construction") and str(missing).contains("Workbench"),
		"details list every unmet prerequisite: Construction level and the skill node (%s)" % [missing])
	_expect(_BF.place_site(_player, &"basic_workbench", _cell, 0) == null, "no learned skill node: no placement")
	_player.skills.trees["construction"]["level"] = 20
	_learn_workbench()
	_expect(_BLUEPRINTS.unmet(_player, bp).is_empty(), "Construction 20 + the Workbench node meet every prerequisite (%s)" % [_BLUEPRINTS.unmet(_player, bp)])
	# §17 5: outside the claim, on another kind, and a footprint that rotation moves.
	var outside := _cell + Vector2i(400, 0)
	_expect(_BF.place_reason(_player, &"basic_workbench", outside, 0) != "" and _BF.place_site(_player, &"basic_workbench", outside, 0) == null,
		"placement outside the claim is refused: '%s'" % _BF.place_reason(_player, &"basic_workbench", outside, 0))
	var taken: Node3D = _BF.place_site(_player, &"basic_workbench", _cell, 0)
	_expect(taken != null, "a valid cell takes the site")
	if taken:
		_expect(_BF.place_site(_player, &"basic_workbench", _cell, 0) == null, "a second site on the same cells is refused (overlap)")
		var rotated := _cell + Vector2i(3, 0)
		var why0: String = _BF.place_reason(_player, &"basic_workbench", rotated, 0)
		var why1: String = _BF.place_reason(_player, &"basic_workbench", rotated, 1)
		_expect(why0 == "" and why1 == "", "the rotated footprint stays placeable on a free strip (%s / %s)" % [why0, why1])
		# The footprint is the blueprint's 2x1, and rotation moves it: the cell it uses at rot 1 is
		# one tile north, so a site there blocks rot 1 and leaves rot 0 free.
		var block_cell := rotated + Vector2i(0, 1)
		var blocker: Node3D = _BF.place_site(_player, &"basic_workbench", block_cell, 1)
		_expect(blocker != null and _BF.place_reason(_player, &"basic_workbench", rotated, 0) == "" \
				and _BF.place_reason(_player, &"basic_workbench", rotated, 1) != "",
			"a 2x1 footprint moves with rotation: rot 1 hits the site at %s, rot 0 does not (%s / %s)" % [block_cell, _BF.place_reason(_player, &"basic_workbench", rotated, 0), _BF.place_reason(_player, &"basic_workbench", rotated, 1)])
		BF_free(blocker)
		BF_free(taken)

# ---------------------------------------------------------------- §17 6 placement makes a site

func _test_placement() -> void:
	_site = _BF.place_site(_player, &"basic_workbench", _cell, 0)
	_expect(_site != null, "placing creates a construction site")
	if _site == null:
		return
	_site_cell = _site.build_cell
	_expect(_site is Node3D and _site.get_script() == _SITE and _PS.of(_site) == null,
		"the site is not a CraftStation and has no job machinery (site_not_station)")
	_expect(str(_site.blueprint_id) == "basic_workbench" and str(_site.owner_name) != "" and _site.site_id != "",
		"it carries a unique id, owner and blueprint")
	_expect(_site.progress() == 0.0 and _site.materials_ready() == false, "a new site is empty and unfinished")

# ---------------------------------------------------------------- §17 7 escrow, no duplication

func _test_escrow_two_contributors() -> void:
	_clear_bag()
	_give(&"plank_shape", 2, 12)
	_give(&"pillar_shape", 2, 12)
	_give(&"strap", 6, 12)
	var before: int = _player.inventory.used_slots()
	var ok: bool = true
	for slot in 3:
		while _site.deposited(slot) < _site.needed(slot):
			var idx: int = _site.first_fitting(_player.inventory, slot)
			if idx < 0:
				ok = false
				break
			ok = _site.deposit(slot, idx) and ok
	_expect(ok and _site.materials_ready(), "every exact instance deposits into its slot (%s)" % [_site.slot_counts()])
	_expect(_player.inventory.used_slots() == 0 and _site.escrow().size() == 10 and before == 10,
		"deposits move the real instances, they are never cloned (bag %d, escrow %d)" % [_player.inventory.used_slots(), _site.escrow().size()])
	var wrong = _INV.new(3)
	wrong.add(_IS.make(&"stone", 1))
	_expect(_site.first_fitting(wrong, 0) < 0 and not _site.deposit(0, 0), "a wrong-tag instance is refused (wrong_tag_refused)")
	# A second contributor with its own bag.
	var other = _INV.new(3)
	other.add(_IS.make(&"strap", 1, {}, 9))
	var site2: Node3D = _BF.place_site(_player, &"basic_workbench", _cell + Vector2i(4, 0), 0)
	if site2:
		site2.bind_bag(other)  # its own bag stands in for a second survivor's
	var idx2: int = site2.first_fitting(other, 2) if site2 else -1
	var uid2: String = (other.slots[idx2] as Object).uid if site2 and idx2 >= 0 else ""
	_expect(site2 != null and idx2 >= 0 and site2.deposit(2, idx2, "friend") and site2.escrow()[0].creator == "friend" and str(site2.deposited_by.get(uid2, "")) == "friend",
		"a second contributor's exact instance lands in the shared escrow with its owner recorded (%s)" % [site2.deposited_by if site2 else {}])
	BF_free(site2)

# ---------------------------------------------------------------- §17 8 persistence

func _test_save_partial() -> void:
	var row: Dictionary = JSON.parse_string(JSON.stringify(_site.to_dict()))
	var SR: GDScript = load("res://scripts/core/save_restore.gd")
	var back: Node3D = SR.spawn(row)
	_expect(back != null and str(back.blueprint_id) == "basic_workbench" and back.escrow().size() == 10 and back.materials_ready(),
		"a partially built site reloads with every deposited instance (%d)" % [back.escrow().size() if back else -1])
	if back:
		_expect(back.escrow()[0].uid == _site.escrow()[0].uid, "reloaded deposits keep their uids")
		back.free()

# ---------------------------------------------------------------- §17 9-10, 18 completion and level

func _test_work_and_completion() -> void:
	var xp_before: float = _xp()
	var site_units: int = _site.escrow().size()
	_expect(_BF.complete(_player, _site) == null and is_instance_valid(_site), "completion is refused while the work is unfinished")
	while not _site.work_done():
		_site.work(1.0)
	var station = _BF.complete(_player, _site)
	_expect(station != null and station.get_script() == _CS, "completion creates exactly one finished Workbench")
	_expect(not is_instance_valid(_site) or _site.is_queued_for_deletion(), "the site is removed")
	_expect(station == null or station.get_node_or_null("SiteIcon") == null, "the finished station replaces the worksite's dirt symbol")
	_expect(site_units == 10 and _site.escrow().size() == 0, "escrow is consumed exactly once (was %d, now %d)" % [site_units, _site.escrow().size()])
	var benches := 0
	for n in _rt.get_tree().get_nodes_in_group("craft_station"):
		if n.get_script() == _CS and _rt.is_ancestor_of(n) and n.build_cell == _site_cell:
			benches += 1
	_expect(benches == 1, "exactly one structure exists on the site's cells after completion (%d)" % benches)
	if station == null:
		return
	_expect(station.station_level == 12, "structure level is the weighted average of level-contributing inputs (got %d)" % station.station_level)
	_expect(station.has_station_tag(&"workbench") and station.station_level >= 12, "the Workbench is tagged [workbench] at its level")
	var xp_after: float = _xp()
	_expect(xp_after > xp_before, "completion pays Construction XP once (%.0f -> %.0f)" % [xp_before, xp_after])
	_expect(_BF.complete(_player, station) == null, "completing a finished station does nothing (no second structure, no XP)")
	_expect(_xp() == xp_after, "no XP for a repeated completion")
	# §10 formula: construction level caps the result, blueprint max clamps it, min raises never.
	var bp: Dictionary = _BLUEPRINTS.of(&"basic_workbench")
	_expect(_BLUEPRINTS.result_level(bp, [60, 60, 60, 60], 1) == 1, "a Construction level of 1 caps a lv-60 structure to 1")
	_expect(_BLUEPRINTS.result_level(bp, [12, 12, 12, 12], 60) <= int(bp.get("level_max", 60)), "the blueprint max clamps the result")
	# # ASSUMPTION: support slots do not raise the level (spec 30 §9 level_contributing).
	_expect(_BLUEPRINTS.result_level(bp, [10, 10], 40) == 10, "the contributing levels average to 10")
	# Straps are support slots: their level never enters the structure level.
	var strap_site: Node3D = _BF.place_site(_player, &"basic_workbench", _cell + Vector2i(4, 2), 0)
	if strap_site:
		for i in 2:
			_player.inventory.add(_IS.make(&"plank_shape", 1, {}, 10))
			_player.inventory.add(_IS.make(&"pillar_shape", 1, {}, 10))
		for i in 6:
			_player.inventory.add(_IS.make(&"strap", 1, {}, 60))
		for slot in 3:
			while strap_site.deposited(slot) < strap_site.needed(slot):
				var idx: int = strap_site.first_fitting(_player.inventory, slot)
				if idx < 0 or not strap_site.deposit(slot, idx):
					break
		var lvls: Array = strap_site.contributing_levels()
		_expect(lvls.size() == 4 and _BLUEPRINTS.result_level(bp, lvls, 40) == 10,
			"six level-60 straps do not lift a level-10 build (%s -> %d)" % [lvls, _BLUEPRINTS.result_level(bp, lvls, 40)])
		BF_free(strap_site)
	_clear_bag()
	_site = station

func _xp() -> float:
	var n := 0.0
	for t: Dictionary in _player.skills.trees.values():
		n += float(t.get("xp", 0.0)) + 100000.0 * float(t.get("level", 0))
	return n

# ---------------------------------------------------------------- §17 12-14 station job

func _test_station_job() -> void:
	var station = _site
	_clear_bag()
	_give(&"plank_shape", 1, 20)
	var ps = _PS.of(station)
	_expect(ps != null and ps.slots() >= 1, "the workbench runs job machinery")
	var added: int = ps.load_from(_player.inventory, &"trimmed_plank", 1) if ps else 0
	_expect(added == 1 and ps.jobs.size() == 1 and ps.running_count() == 1, "a processing job starts in the queue (%d)" % ps.jobs.size() if ps else "no station")
	var wrong_recipe: String = ps.refuse_reason(_player.inventory, &"fine_plank") if ps else ""
	_expect(not ps.runs(&"dry_meat"), "a recipe of another station kind is refused by this Workbench")
	# The Craft menu reads the same gate, so a row and its station never disagree.
	var tags: Array[StringName] = [&"workbench"]
	var gate_ok: String = _CS.station_gate(_CR.recipe(&"trimmed_plank"), tags, 2, &"workbench")
	var gate_low: String = _CS.station_gate(_CR.recipe(&"fine_plank"), tags, 1, &"workbench")
	var gate_tag: String = _CS.station_gate(_CR.recipe(&"trimmed_plank"), [] as Array[StringName], 9, &"workbench")
	_expect(gate_ok == "" and gate_low.contains("2") and gate_tag.contains("workbench"),
		"the station gate names the missing level and the missing tag (%s / %s / %s)" % [gate_ok, gate_low, gate_tag])
	var low: String = ""
	if ps:
		var was: int = station.station_level
		station.station_level = 1
		low = ps.refuse_reason(_player.inventory, &"fine_plank")
		station.station_level = was
	_expect(low != "", "a recipe requiring Workbench >= 2 is refused at level 1 (low_station_refused): '%s'" % low)
	# §17 13: the job survives a save/load mid-run.
	var row: Dictionary = JSON.parse_string(JSON.stringify(station.to_dict()))
	var SR: GDScript = load("res://scripts/core/save_restore.gd")
	var back: Node3D = SR.spawn(row)
	if back:
		root.add_child(back)  # a reloaded station is put in the world; its jobs come back on _ready
	_expect(back != null and _PS.of(back) != null and _PS.of(back).jobs.size() == 1, "the running job survives a save/load")
	if back:
		_expect(back.station_level == station.station_level and back.has_station_tag(&"workbench"), "the reloaded Workbench keeps its tag and level")
		BF_free(back)
	# §17 14: collect exactly once, traits kept.
	var levels_before: int = ps.jobs[0]["inputs"][0].level if ps else -1
	_PS.clock_skew_s = _PS.job_seconds(&"workbench", &"trimmed_plank") + 1.0
	if ps:
		ps.advance(_PS.now_s())
	_PS.clock_skew_s = 0.0
	_clear_bag()
	var got: int = ps.collect_into(_player.inventory) if ps else 0
	var again: int = ps.collect_into(_player.inventory) if ps else 0
	_expect(got == 1 and again == 0 and _player.inventory.count_of(&"trimmed_plank") == 1, "the output collects exactly once (%d, then %d)" % [got, again])
	var out_level := 0
	for s in _player.inventory.slots:
		if s and s.def_id == &"trimmed_plank":
			out_level = s.level
	_expect(out_level == levels_before, "the collected instance keeps the component's level (%d)" % out_level)
	# §17 14b: a full bag never eats a finished output: it stays on the station until there is room.
	_clear_bag()
	_give(&"plank_shape", 1, 20)
	var full_ps = _PS.of(_site)
	var full_loaded: int = full_ps.load_from(_player.inventory, &"trimmed_plank", 1) if full_ps else 0
	_PS.clock_skew_s = _PS.job_seconds(&"workbench", &"trimmed_plank") + 1.0
	if full_ps:
		full_ps.advance(_PS.now_s())
	_PS.clock_skew_s = 0.0
	var filler: StringName = &"stone"
	for i in _player.inventory.slot_count:
		if _player.inventory.slots[i] == null:
			_player.inventory.slots[i] = _IS.make(filler, 1)
	var full_moved: int = full_ps.collect_into(_player.inventory, _player) if full_ps else -1
	_expect(full_loaded == 1 and full_moved == 0 and full_ps.ready_count() == 1,
		"a full bag keeps the finished output on the station (%d moved, %d ready)" % [full_moved, full_ps.ready_count() if full_ps else -1])
	_clear_bag()
	var freed: int = full_ps.collect_into(_player.inventory) if full_ps else 0
	_expect(freed == 1 and _player.inventory.count_of(&"trimmed_plank") == 1, "making room collects it exactly once (%d)" % freed)
	_clear_bag()
	# §17 16: destroying the station hands its contents over, once.
	_clear_bag()
	_give(&"plank_shape", 1, 20)
	var ps2 = _PS.of(_site)
	var loaded: int = ps2.load_from(_player.inventory, &"trimmed_plank", 1) if ps2 else 0
	var salvaged: Array = _site.call("salvage_contents") if _site.has_method("salvage_contents") else []
	var twice: Array = _site.call("salvage_contents") if _site.has_method("salvage_contents") else []
	_expect(loaded == 1 and salvaged.size() == 1 and salvaged[0].def_id == &"plank_shape" and twice.is_empty(),
		"a destroyed Workbench hands its job inputs back once")

# ---------------------------------------------------------------- §17 16, 18 cancel and farm

func _test_cancel_and_farm() -> void:
	BF_free(_site)
	_site = null
	var xp_before: float = _xp()
	var site: Node3D = _BF.place_site(_player, &"basic_workbench", _cell + Vector2i(8, 0), 0)
	_expect(site != null, "a second site for the cancel test")
	if site == null:
		return
	_clear_bag()
	_give(&"plank_shape", 2, 12)
	for slot in 2:
		while site.deposited(slot) < site.needed(slot) and site.first_fitting(_player.inventory, slot) >= 0:
			site.deposit(slot, site.first_fitting(_player.inventory, slot))
	var had: int = site.escrow().size()
	_expect(site.cancel(_player) and _player.inventory.count_of(&"plank_shape") == had and site.escrow().is_empty(),
		"cancel returns every deposited instance (%s)" % [had])
	_expect(_xp() == xp_before, "cancel and restart pays no Construction XP (%.0f -> %.0f)" % [xp_before, _xp()])
	# Work progress alone never pays XP and is not lost by reopening.
	var site2: Node3D = _BF.place_site(_player, &"basic_workbench", _cell + Vector2i(4, 0), 0)
	for slot in 3:
		while site2.deposited(slot) < site2.needed(slot):
			var idx: int = site2.first_fitting(_player.inventory, slot)
			if idx < 0:
				_give(StringName(["plank_shape", "pillar_shape", "strap"][slot]), site2.needed(slot) - site2.deposited(slot), 12)
				idx = site2.first_fitting(_player.inventory, slot)
				if idx < 0:
					break
			if not site2.deposit(slot, idx):
				break
	var p0: float = site2.work_progress
	_expect(site2.work(1.0) and site2.work_progress > p0, "Work advances a real timer (%s -> %s)" % [p0, site2.work_progress])
	var mid: float = site2.work_progress
	var row: Dictionary = JSON.parse_string(JSON.stringify(site2.to_dict()))
	var back: Node3D = load("res://scripts/core/save_restore.gd").spawn(row)
	_expect(back != null and absf(back.work_progress - mid) < 0.01, "reopening after a save resumes the same work (%s)" % [back.work_progress if back else -1])
	if back:
		BF_free(back)
	_expect(_xp() == xp_before, "work progress pays no XP before completion")
	BF_free(site2)
