extends SceneTree
## DOMAIN-D acceptance (owner's spec 29 sections 4 and 10): the Personal Communications Center is a
## BUILDFLOW structure (construction site -> exact-instance deposits -> work -> finished structure);
## once it stands, handing it the documented contributions and completing the step raises the Tamed
## Island's Pioneer rank 1 -> 2, which raises the plot CAPACITY 13 -> 17 from data/world/domains.json;
## the contributions are exact instances consumed exactly once; no cell is claimed automatically; and
## the rank and the held contributions survive a save/load.
## Run: Godot --headless --path game --script res://tests/t_domaind.gd -> "[t_domaind] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const ME := "Tess"

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _world: Node
var _rt: Node3D
var _player: Node3D
var _site: Node3D
var _station: Node3D
var CC: GDScript
var DR: GDScript
var IC: GDScript
var IS: GDScript
var BF: GDScript
var BP: GDScript
var SG: GDScript
var CELL := Vector2i.ZERO

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	root.get_tree().create_timer(90.0).timeout.connect(func () -> void:
		print("[t_domaind] FAIL watchdog: the run did not finish in 90 s")
		quit(1))
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_domaind] FAIL %s" % what)

func _run() -> void:
	CC = load("res://scripts/world/comm_center.gd")
	DR = load("res://scripts/world/domain_rules.gd")
	IC = load("res://scripts/world/island_claims.gd")
	IS = load("res://scripts/items/item_stack.gd")
	BF = load("res://scripts/items/build_flow.gd")
	BP = load("res://scripts/items/blueprints.gd")
	SG = load("res://scripts/core/save_game.gd")
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TDomaindHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	_world.player_name = ME
	_world.home_claims = []
	_world.home_domain = {}
	_world.away_domain = {}
	_world.home_comm_center = {}
	_world.unstable_claims = []
	_world.pioneer_level = 0
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_rt = _world.runtime
	var grid: Variant = _rt.get("build_grid")
	grid.ignore_distance = true
	_learn_workbench()
	_test_data()
	await _build_center()
	await _test_contributions()
	await _test_cap_rises_without_land()
	_test_save_round_trip()
	if _fails.is_empty():
		print("[t_domaind] PASS")
		quit(0)
	else:
		print("[t_domaind] FAIL count=%d" % _fails.size())
		quit(1)

func _learn_workbench() -> void:
	var sk: Node = _player.skills
	sk.trees["construction"]["level"] = 20
	sk.trees["construction"]["xp"] = 0.0
	sk.sp_extra = 200
	sk._recount_sp()
	if not sk.is_unlocked("construction", "bonfire"):
		sk.unlock("construction", "bonfire")
	if not sk.is_unlocked("construction", "workbench"):
		sk.unlock("construction", "workbench")

func _give(id: StringName, n: int) -> void:
	for i in n:
		_player.inventory.add(IS.make(id, 1, {}, 12))

func _find_cell() -> Vector2i:
	var first: Rect2i = _rt.claims[0]
	var grid: Variant = _rt.get("build_grid")
	for z in range(first.position.y, first.end.y):
		for x in range(first.position.x, first.end.x):
			var c := Vector2i(x, z)
			if grid.can_place(CC.grid_kind(), c, 0) == "":
				return c
	return Vector2i.ZERO

# ---------------------------------------------------------------- data

func _test_data() -> void:
	var bp: Dictionary = CC.blueprint()
	_expect(not bp.is_empty() and str(bp.get("id", "")) == "comm_center", "comm_center.json carries the build blueprint")
	_expect(not BP.of(CC.KIND).is_empty(), "the blueprint is visible to the BUILDFLOW pipeline (Blueprints.of)")
	var steps: Array = CC.steps()
	_expect(steps.size() >= 1 and int(steps[0]["rank"]) == 2, "the first documented step is Pioneer rank 2 (got %s)" % [steps.map(func (r: Dictionary) -> int: return int(r["rank"]))])
	_expect(int(DR.cap_for_rank(2)) == 17 and int(DR.cap_for_rank(1)) == 13, "domains.json keeps 13 at rank 1 and 17 at rank 2")
	_expect(CC.rank() == 1, "a fresh island is Pioneer rank 1 (got %d)" % CC.rank())
	_expect(int(DR.cap()) == 13, "a fresh island's cap is 13 (got %d)" % DR.cap())
	_expect(not CC.built(_rt), "the center is not built yet")

# ---------------------------------------------------------------- BUILDFLOW construction

func _build_center() -> void:
	CELL = _find_cell()
	_expect(CELL != Vector2i.ZERO or _rt.claims[0].has_point(CELL), "a free claimed cell for the center")
	var why: String = BF.place_reason(_player, CC.KIND, CELL, 0)
	_site = BF.place_site(_player, CC.KIND, CELL, 0)
	_expect(_site != null, "placing the center makes a construction site (%s)" % why)
	if _site == null:
		print("[t_domaind] cannot continue without a site")
		return
	_expect(_site.is_in_group("construction_site") and not CC.built(_rt), "the placed site is a construction site, not the finished center")
	_give(&"plank_shape", 2)
	_give(&"strap", 4)
	_give(&"stone", 6)
	for i in 2:
		_expect(bool(_site.deposit(0, _player.inventory.find_first(&"plank_shape"))), "plank shape %d deposited" % (i + 1))
	for i in 4:
		_expect(bool(_site.deposit(1, _player.inventory.find_first(&"strap"))), "strap %d deposited" % (i + 1))
	for i in 6:
		_expect(bool(_site.deposit(2, _player.inventory.find_first(&"stone"))), "stone %d deposited" % (i + 1))
	_expect(_site.materials_ready(), "every site slot is full")
	_expect(not _site.ready_to_finish(), "the site still needs work")
	_site.work(float(_site.bp().get("work_seconds", 20.0)))
	var site_id: String = _site.site_id
	_station = BF.complete(_player, _site)
	_expect(_station != null and CC.TAG in (_station.get("station_tags") as Array), "the finished structure is the Personal Communications Center (tags %s)" % [str(_station.get("station_tags")) if _station else "none"])
	await process_frame
	_expect(CC.built(_rt), "the center counts as built on this island")
	_expect(CC.station(_rt) == _station, "the model finds that same station")
	_expect(_player.inventory.count_of(&"plank_shape") == 0 and _player.inventory.count_of(&"strap") == 0 and _player.inventory.count_of(&"stone") == 0,
		"the site's deposits were consumed exactly once by the build")
	print("[t_domaind] built: site=%s station=%s tags=%s" % [site_id, str(_station.get("kind")) if _station else "none", str(_station.get("station_tags")) if _station else "[]"])

# ---------------------------------------------------------------- contributions

func _test_contributions() -> void:
	_expect(CC.built(_rt), "setup: the center stands")
	_expect(int(CC.target_rank()) == 2, "the next step is rank 2 (got %d)" % int(CC.target_rank()))
	# A full rank-2 step before the center existed would still need it: the reason names the building.
	var why_first: String = CC.complete_reason(2, _rt)
	_expect(why_first == "The center still needs contributions", "an empty center cannot complete (reason \"%s\")" % why_first)
	var rank_before: int = CC.rank()
	var cap_before: int = DR.cap()
	var bag_before: int = _player.inventory.count_of(&"plank_shape") + _player.inventory.count_of(&"stone")
	_give(&"plank_shape", 2)
	_give(&"stone", 8)
	_expect(CC.deposit(2, 0, _player.inventory), "contribute the first plank shape to rank 2")
	_expect(_player.inventory.count_of(&"plank_shape") == 1, "the contributed instance left the bag exactly once (bag has %d)" % _player.inventory.count_of(&"plank_shape"))
	_expect(CC.deposit(2, 0, _player.inventory), "contribute the second plank shape")
	_expect(not CC.deposit(2, 0, _player.inventory), "a full slot takes no more (the step needs %d)" % CC.needed(2, 0))
	_expect(CC.deposited(2, 0) == CC.needed(2, 0), "the center holds exactly the required plank shapes (%d/%d)" % [CC.deposited(2, 0), CC.needed(2, 0)])
	# Exact instances: withdrawing hands the very instance back and leaves the step short again.
	var held: int = CC.deposited(2, 0)
	_expect(CC.withdraw(2, 0, _player.inventory), "withdrawing a contribution hands it back")
	_expect(CC.deposited(2, 0) == held - 1 and _player.inventory.count_of(&"plank_shape") == 1, "the withdrawn unit is in the bag and no longer held")
	_expect(CC.deposit(2, 0, _player.inventory), "it can be contributed again")
	while CC.deposited(2, 1) < CC.needed(2, 1):
		_expect(CC.deposit(2, 1, _player.inventory), "contribute a stone")
	_expect(CC.ready(2), "the step's contributions are complete")
	_expect(int(DR.cap()) == 13, "contributions alone have not changed the cap (got %d)" % DR.cap())
	var cells_before: int = IC.used(_rt)
	var claims_before: int = _rt.claims.size()
	var owned_before: Array = (IC.owned_cells(_rt).keys() as Array).duplicate()
	var out: Dictionary = CC.complete(_rt, 2)
	_expect(bool(out["ok"]), "completing the step works (%s)" % str(out["reason"]))
	_expect(int(out["rank_before"]) == 1 and int(out["rank_after"]) == 2, "rank %d -> %d" % [out["rank_before"], out["rank_after"]])
	_expect(int(out["cap_before"]) == 13 and int(out["cap_after"]) == 17, "cap %d -> %d" % [out["cap_before"], out["cap_after"]])
	_expect(CC.rank() == 2 and int(DR.cap()) == 17, "the island now reads rank %d, cap %d" % [CC.rank(), DR.cap()])
	_expect(int(out["consumed"]) == CC.needed(2, 0) + CC.needed(2, 1), "the step consumed exactly its contributions once (%d)" % int(out["consumed"]))
	var owned_after: Array = (IC.owned_cells(_rt).keys() as Array).duplicate()
	_expect(IC.used(_rt) == cells_before and _rt.claims.size() == claims_before and owned_after == owned_before,
		"the upgrade assigned no land: %d -> %d cells, %d -> %d claim rects" % [cells_before, IC.used(_rt), claims_before, _rt.claims.size()])
	_expect(_player.inventory.count_of(&"stone") == 0 and _player.inventory.count_of(&"plank_shape") == 0, "the contributed instances are gone from the bag and from the world (no refund)")
	var left: int = _player.inventory.count_of(&"plank_shape") + _player.inventory.count_of(&"stone")
	_expect(bag_before + 10 - left == int(out["consumed"]), "the bag lost exactly what the step consumed (%d of %d)" % [bag_before + 10 - left, int(out["consumed"])])
	# Completing again spends nothing: the step is behind the rank now.
	var again: Dictionary = CC.complete(_rt, 2)
	_expect(not bool(again["ok"]) and int(again["consumed"]) == 0 and CC.rank() == 2, "a second completion spends nothing and keeps rank 2")
	print("[t_domaind] rank %d->%d cap %d->%d" % [rank_before, CC.rank(), cap_before, DR.cap()])

# ---------------------------------------------------------------- no land is assigned

func _test_cap_rises_without_land() -> void:
	var used: int = IC.used(_rt)
	var cap: int = int(_rt.call("claim_cap"))
	_expect(cap == 17, "the live island cap follows the rank (%d)" % cap)
	_expect(used <= cap, "the island holds %d cells, cap %d" % [used, cap])
	# Rank is capacity only: the step claimed nothing, and claiming still needs the Domain screen.
	var cells: int = (IC.owned_cells(_rt) as Dictionary).size()
	_expect(cells == used, "no cell was claimed by the upgrade (record holds %d, cap %d)" % [cells, cap])
	var claims_now: int = _rt.claims.size()
	_expect(claims_now >= 1, "the camp land is still the land that exists (%d rects)" % claims_now)
	# Room above the old cap: the upgrade made the land claimable, it did not claim it.
	_expect(cap > 13, "capacity grew beyond the starting 13 (%d)" % cap)
	print("[t_domaind] land: %d cells held, cap %d" % [used, cap])

# ---------------------------------------------------------------- save / load

func _test_save_round_trip() -> void:
	# Some progress toward rank 6 is held when the save is taken: it must come back instance for instance.
	_give(&"stone", 3)
	_expect(CC.deposit(6, 0, _player.inventory) == false, "rank 6's first slot takes planks, not stone")
	_give(&"plank_shape", 1)
	_expect(CC.deposit(6, 0, _player.inventory), "a plank shape is held for rank 6")
	_expect(CC.deposit(6, 2, _player.inventory), "a stone is held for rank 6")
	var rank_was: int = CC.rank()
	var held_was: int = CC.deposited(6, 0) + CC.deposited(6, 2)
	_expect(SG.save_now(), "the save writes")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	var home: Variant = (saved as Dictionary).get("home", {}) if saved is Dictionary else {}
	var row: Variant = (home as Dictionary).get("comm_center", {}) if home is Dictionary else {}
	_expect(row is Dictionary and not (row as Dictionary).is_empty(), "the save carries home.comm_center")
	var center_rows: int = 0
	for b: Variant in ((home as Dictionary).get("buildings", []) if home is Dictionary else []):
		if b is Dictionary and "comm_center" in ((b as Dictionary).get("station_tags", []) as Array):
			center_rows += 1
	_expect(center_rows == 1, "the built center is saved as a building row (%d)" % center_rows)
	# A load: the record goes back through the same path SaveGame uses.
	_world.home_comm_center = {}
	CC.from_save(row)
	_expect(CC.rank() == rank_was, "the reloaded rank is %d (got %d)" % [rank_was, CC.rank()])
	_expect(CC.deposited(6, 0) + CC.deposited(6, 2) == held_was, "the reloaded contributions are the same instances (%d vs %d)" % [CC.deposited(6, 0) + CC.deposited(6, 2), held_was])
	_expect(int(DR.cap()) == 17, "the reloaded cap is 17 (got %d)" % DR.cap())
	# An old save with no comm_center field keeps its exact shape: no record is written.
	_world.home_comm_center = {}
	CC.from_save({})
	_expect(_world.home_comm_center.is_empty(), "a save without the field leaves no center record behind")
	_expect(CC.rank() == 1, "with no record the island reads rank 1 again (got %d)" % CC.rank())
	print("[t_domaind] save: rank %d, %d held" % [rank_was, held_was])
