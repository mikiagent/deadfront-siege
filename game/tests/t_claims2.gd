extends SceneTree
## CLAIMS2 model acceptance (owner's spec 29, sections 2-4, 9, 12-14): a domain is a set of 4x4-tile
## cells on a grid anchored at the island origin; Declare takes one valid cell, Expand only cells that
## share an edge with the domain, the cap is 13 at Pioneer rank 1 and follows the documented
## milestones (2 -> 17, 6 -> 23, 7 -> 30; a rank between two keeps the previous cap); another owner's
## cell, a tile outside the island, a repeated claim and a capped domain are refused with a reason; an
## old save's 14x14 plots become the cells that cover them with every placed building inside; the
## record saves and loads with its cells and cap; claims_changed fires once per claimed batch.
## Run: Godot --headless --path game --script res://tests/t_claims2.gd -> "[t_claims2] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const ME := "Tess"
const THEM := {"id": "p2", "name": "Rowan"}

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _world: Node
var _rt: Node3D
var IC: GDScript
var ISC: GDScript
var DR: GDScript
var BG: GDScript
var _player: Node3D
var _changed := 0
var _change_batches := 0
var _last_changed := Rect2i()

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	root.get_tree().create_timer(90.0).timeout.connect(func () -> void:
		print("[t_claims2] FAIL watchdog: the run did not finish in 90 s")
		quit(1))
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_claims2] FAIL %s" % what)

func _run() -> void:
	BG = load("res://scripts/world/build_grid.gd")
	IC = load("res://scripts/world/island_claims.gd")
	DR = load("res://scripts/world/domain_rules.gd")
	ISC = load("res://scripts/world/island_scatter.gd")  # by path: naming it compiles it before autoloads exist
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TClaims2Host"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	_world.player_name = ME
	_world.home_claims = []
	_world.home_domain = {}
	_world.away_domain = {}
	_world.unstable_claims = []
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_rt = _world.runtime
	_rt.claims_changed.connect(func (r: Rect2i) -> void:
		_changed += 1
		_last_changed = r)
	_test_cell_size()
	_test_rank_caps()
	await _test_declare_and_expand()
	await _test_refusals()
	await _test_other_owner_and_double()
	await _test_footprint_rule()
	await _test_grass()
	await _test_legacy_migration()
	await _test_save_round_trip()
	if _fails.is_empty():
		print("[t_claims2] PASS")
		quit(0)
	else:
		print("[t_claims2] FAIL count=%d" % _fails.size())
		quit(1)

# ---------------------------------------------------------------- cells (spec 29 section 3)

func _test_cell_size() -> void:
	var n: int = DR.cell_tiles()
	_expect(n == 4, "cell_tiles comes from domains.json (4, got %d)" % n)
	var cell := Vector2i(3, -2)
	var rect: Rect2i = IC.cell_rect(_rt, cell)
	_expect(rect == Rect2i(12, -8, 4, 4), "a cell is 4x4 tiles on a grid anchored at the origin (%s)" % rect)
	_expect(IC.cell_of(_rt, Vector2i(13, -6)) == cell, "the tile (13,-6) is in cell (3,-2) (got %s)" % IC.cell_of(_rt, Vector2i(13, -6)))
	var cells: Array = IC.cells_covering(_rt, Rect2i(-7, 1, 14, 14))
	_expect(cells.size() == 16, "a legacy 14x14 plot is covered by 16 cells (got %d)" % cells.size())
	var covered := Rect2i()
	for c in cells:
		covered = IC.cell_rect(_rt, c) if not covered.has_area() else covered.merge(IC.cell_rect(_rt, c))
	_expect(covered.encloses(Rect2i(-7, 1, 14, 14)), "the covering cells contain the legacy plot (%s in %s)" % [Rect2i(-7, 1, 14, 14), covered])
	print("[t_claims2] cells: %d tiles a side, legacy 14x14 -> %d cells" % [n, cells.size()])

func _test_rank_caps() -> void:
	var wants := {1: 13, 2: 17, 4: 17, 6: 23, 7: 30, 0: 13}
	for rank in wants:
		var got: int = DR.cap_for_rank(rank)
		_expect(got == int(wants[rank]), "Pioneer rank %d -> cap %d (got %d)" % [rank, wants[rank], got])
	# DOMAIN-D / spec 29 section 4: the live cap follows the island's Pioneer rank, which only the
	# Personal Communications Center's contribution track raises. The character level is the player
	# level and never grants a rank, so the track's record is what moves the cap here.
	var was_rec: Variant = (_world.home_comm_center as Dictionary).duplicate(true)
	var was_level: int = int(_world.pioneer_level)
	_world.pioneer_level = 60
	_expect(int(DR.cap()) == 13, "a level-60 survivor with no contributions keeps the 13-plot cap (got %d)" % int(DR.cap()))
	for rank in [2, 4, 6, 7]:
		_world.home_comm_center = {"rank": rank, "steps": {}}
		_expect(int(DR.cap()) == int(wants[rank]), "the live cap at Pioneer rank %d is %d (got %d)" % [rank, wants[rank], DR.cap()])
	_world.home_comm_center = was_rec
	_world.pioneer_level = was_level
	print("[t_claims2] caps: %s" % [wants])

# ---------------------------------------------------------------- declare / expand

## A domain with no cells yet, on this island.
func _reset_domain() -> void:
	_rt.domain = {}
	_rt.claims.clear()
	_rt.set_other_claims([])
	_changed = 0
	_last_changed = Rect2i()

## A cell on dry, claimable land within `radius` cells of the camp, for a chosen predicate.
func _find_cell(take: Callable) -> Vector2i:
	var camp: Vector2i = IC.cell_of(_rt, BG.tile_of(_rt._camp_pos))
	for r in range(1, 12):
		for y in range(camp.y - r, camp.y + r + 1):
			for x in range(camp.x - r, camp.x + r + 1):
				var c := Vector2i(x, y)
				if IC.cell_block_reason(_rt, c) == "" and not IC.occupied_cells(_rt).has(c) and take.call(c):
					return c
	return IC.NO_CELL

func _test_declare_and_expand() -> void:
	_reset_domain()
	var first := _find_cell(func (_c: Vector2i) -> bool: return true)
	_expect(first != IC.NO_CELL, "a dry cell exists near the camp")
	if first == IC.NO_CELL:
		return
	var out: Dictionary = _rt.claim_domain([first])
	_expect(bool(out["ok"]) and _rt.claim_used() == 1, "Declare takes one cell (ok=%s used=%d)" % [out["ok"], _rt.claim_used()])
	_expect(IC.is_claimed(_rt, IC.cell_rect(_rt, first).get_center()), "the declared cell's tiles are claimed")
	_expect(_changed == 1, "claims_changed fired once for the declared cell (got %d)" % _changed)
	_expect(_last_changed == IC.cell_rect(_rt, first), "claims_changed carries the claimed tiles (%s)" % _last_changed)
	# Every eligible cell shares an edge with the domain (or the camp land it grew from).
	var eligible: Array = _rt.claim_eligible_cells()
	_expect(eligible.size() > 0, "the new domain has cells it may grow into (%d)" % eligible.size())
	var not_adjacent := []
	for c in eligible:
		if not IC.adjacent_to(c, IC.occupied_cells(_rt)):
			not_adjacent.append(c)
	_expect(not_adjacent.is_empty(), "eligible cells are edge-adjacent only (%s)" % [not_adjacent])
	# Grow one edge-adjacent cell: it lands exactly on that cell and fires the signal once.
	var next: Vector2i = eligible[0]
	var before: int = _rt.claim_used()
	_changed = 0
	out = _rt.claim_domain([next])
	_expect(bool(out["ok"]) and _rt.claim_used() == before + 1, "Expand adds an edge-adjacent cell (%d -> %d)" % [before, _rt.claim_used()])
	_expect(IC.owned_cells(_rt).has(next), "the expanded cell is the one chosen (%s)" % [next])
	_expect(_changed == 1, "claims_changed fired once for the expansion (got %d)" % _changed)
	# A batch of cells (one Declare/Expand confirm) fires once, not once per cell.
	var batch: Array = _rt.claim_eligible_cells()
	var want: Array = batch.slice(0, mini(2, batch.size()))
	if want.size() >= 1:
		_changed = 0
		out = _rt.claim_domain(want)
		_expect(bool(out["ok"]) and _changed == 1, "a batch claim fires claims_changed once (%d, ok=%s)" % [_changed, out["ok"]])
	print("[t_claims2] declare/expand: first=%s used=%d eligible=%d" % [first, _rt.claim_used(), eligible.size()])

# ---------------------------------------------------------------- refusals (spec 29 sections 2, 4, 12)

func _test_refusals() -> void:
	_reset_domain()
	var first := _find_cell(func (_c: Vector2i) -> bool: return true)
	_rt.claim_domain([first])
	# A non-adjacent cell on good land is refused, and names the reason.
	var far := _find_cell(func (c: Vector2i) -> bool:
		return not IC.adjacent_to(c, IC.occupied_cells(_rt)) and IC.cell_block_reason(_rt, c) == "")
	_expect(far != IC.NO_CELL, "a dry non-adjacent cell exists")
	var out: Dictionary = _rt.claim_domain([far])
	_expect(not bool(out["ok"]) and str(out["reason"]) == "not_adjacent", "a non-adjacent cell is refused for adjacency (got %s)" % [out["reason"]])
	# A cell outside the island is refused for being outside it.
	var half := int(_rt._size * 0.5)
	var outside := Vector2i(int(floor(float(half) / 4.0)) + 4, 0)
	out = _rt.claim_domain([outside])
	_expect(not bool(out["ok"]) and str(out["reason"]) in ["outside_the_island", "terrain"], "a cell off the island is refused (%s)" % [out["reason"]])
	# A cell mostly under water is refused for terrain: find one and check the classifier agrees.
	var wet := Vector2i(1 << 30, 0)
	var camp: Vector2i = IC.cell_of(_rt, BG.tile_of(_rt._camp_pos))
	for y in range(camp.y - 20, camp.y + 21):
		for x in range(camp.x - 20, camp.x + 21):
			var c := Vector2i(x, y)
			if IC.cell_block_reason(_rt, c) == "terrain":
				wet = c
				break
		if wet.x != 1 << 30:
			break
	if wet.x != 1 << 30:
		out = _rt.claim_domain([wet])
		_expect(not bool(out["ok"]) and str(out["reason"]) == "terrain", "a water/cliff cell is refused for terrain (got %s)" % [out["reason"]])
	else:
		print("[t_claims2] no water cell near the camp on this island; terrain refusal not sampled")
	# Fill to the cap (13 at rank 1), then one more is refused for the cap - never silently.
	_world.home_comm_center = {}
	var guard := 0
	while _rt.claim_used() < int(DR.cap()) and guard < 200:
		guard += 1
		var elig: Array = _rt.claim_eligible_cells()
		if elig.is_empty():
			break
		_rt.claim_domain([elig[0]])
	_expect(_rt.claim_used() == int(DR.cap()), "the domain fills to the cap %d (used=%d)" % [int(DR.cap()), _rt.claim_used()])
	_expect(_rt.claim_eligible_cells().size() > 0, "there is still land it would like, so the cap is what stops it")
	var capped: Array = _rt.claim_eligible_cells()
	if capped.size() > 0:
		out = _rt.claim_domain([capped[0]])
		_expect(not bool(out["ok"]) and str(out["reason"]) == "cap", "one past the cap is refused for the cap (got %s)" % [out["reason"]])
		_expect(_rt.claim_limit_reason().begins_with("Claim limit reached"), "the runtime names the cap (%s)" % _rt.claim_limit_reason())
	print("[t_claims2] cap: used=%d cap=%d reason=%s" % [_rt.claim_used(), _rt.claim_cap(), _rt.claim_limit_reason()])

func _test_other_owner_and_double() -> void:
	_reset_domain()
	var first := _find_cell(func (_c: Vector2i) -> bool: return true)
	_rt.claim_domain([first])
	# The same cell twice: refused, and the domain does not grow.
	var used: int = _rt.claim_used()
	var out: Dictionary = _rt.claim_domain([first])
	_expect(not bool(out["ok"]) and str(out["reason"]) == "already_owned", "the same cell twice is refused (got %s)" % [out["reason"]])
	_expect(_rt.claim_used() == used, "the repeated claim adds nothing (%d -> %d)" % [used, _rt.claim_used()])
	# A cell another survivor holds is refused for ownership, and claiming it changes nothing.
	var theirs: Vector2i = _rt.claim_eligible_cells()[0]
	var rect: Rect2i = IC.cell_rect(_rt, theirs)
	_rt.set_other_claims([{"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "owner": THEM}])
	out = _rt.claim_domain([theirs])
	_expect(not bool(out["ok"]) and str(out["reason"]) == "ownership", "another survivor's cell is refused for ownership (got %s)" % [out["reason"]])
	_expect(not IC.owned_cells(_rt).has(theirs), "another survivor's cell is not claimed")
	var look: Dictionary = _rt.classify_cell(theirs)
	_expect(str(look["state"]) == "invalid" and str(look["reason"]) == "ownership", "the preview marks their cell invalid for ownership (%s)" % [look])
	_rt.set_other_claims([])
	# One atomic call: a valid batch with one bad cell claims nothing at all.
	var good: Array = _rt.claim_eligible_cells()
	var bad_cell := Vector2i(1 << 30, 0)
	var mixed: Array = good.slice(0, 1)
	mixed.append(bad_cell)
	used = _rt.claim_used()
	out = _rt.claim_domain(mixed)
	_expect(not bool(out["ok"]) and _rt.claim_used() == used, "a batch with one bad cell claims nothing (reason %s)" % [out["reason"]])
	print("[t_claims2] refusals: repeat=%s ownership=%s atomic=%s" % ["already_owned", "ownership", not out["ok"]])

# ---------------------------------------------------------------- building footprints (spec 29 section 9)

## A building's WHOLE footprint must stand on owned land: an anchor inside the domain with the rest
## of the footprint across the border is refused ("unclaimed"), never placed half on the neighbour's
## land. The footprint also rotates, so a 2x1 building cannot slip across the edge by turning.
func _test_footprint_rule() -> void:
	_reset_domain()
	var first := _find_cell(func (_c: Vector2i) -> bool: return true)
	_rt.claim_domain([first])
	var cands: Array = _rt.claim_eligible_cells()
	var grid: Variant = _rt.build_grid  # untyped: naming BuildGrid here compiles it before autoloads exist
	_player.global_position = BG.tile_centre(IC.cell_rect(_rt, first).get_center(), _rt) + Vector3(0, 1, 0)  # within build reach
	await process_frame
	var crossed := 0
	var placed_inside := 0
	for c: Vector2i in cands:
		# Try every cell on the domain's border as an anchor of a 2x1 building in both rotations.
		var rect: Rect2i = IC.cell_rect(_rt, c)
		var tiles: Array[Vector2i] = [rect.position, rect.position + Vector2i(1, 0), rect.position + Vector2i(0, 1)]
		for tile in tiles:
			for rot in [0, 1]:
				var cells: Array[Vector2i] = grid.cells_for(&"workbench", tile, rot)
				var inside := 0
				for k in cells:
					inside += 1 if _rt.is_claimed(k) else 0
				if inside == cells.size():
					continue
				var why: String = grid.can_place(&"workbench", tile, rot)
				if why == "unclaimed":
					crossed += 1
				elif why == "":
					print("[t_claims2] FAIL a %dx%d footprint at %s (rot %d) is half off the claim but can_place said yes (%d of %d tiles claimed)" % [grid.footprint(&"workbench").x, grid.footprint(&"workbench").y, tile, rot, inside, cells.size()])
					_fails.append("an anchor-only placement across the claim border was allowed")
	# A footprint fully inside the claimed cell can be placed (the rule refuses only the straddle).
	var cell_rect: Rect2i = IC.cell_rect(_rt, first)
	for tile in [cell_rect.position, cell_rect.position + Vector2i(1, 0), cell_rect.get_center()]:
		var why_in: String = grid.can_place(&"workbench", tile, 0)
		if why_in == "":
			placed_inside += 1
		print("[t_claims2] inside anchor %s -> '%s'" % [tile, why_in])
	_expect(crossed > 0, "a footprint straddling the claim border is refused for being unclaimed (%d anchors sampled)" % crossed)
	_expect(placed_inside > 0, "a footprint wholly inside a claimed cell may be placed (%d anchors sampled)" % placed_inside)
	print("[t_claims2] footprint: %d straddling anchors refused, %d inside anchors allowed" % [crossed, placed_inside])

# ---------------------------------------------------------------- no grass on claimed land (owner)

## Claimed land is bare: claiming the cells removes the grass nodes and decor instances inside them,
## and nothing else (trees, bushes, rocks, flowers, reeds survive). New scatter skips claimed tiles.
## Claimed land is bare: claiming the cells removes the grass harvest nodes inside them (and the
## decor instances, which only a real renderer can be measured on - the lab measures those windowed),
## and nothing else (trees, bushes, rocks, flowers, reeds survive).
func _test_grass() -> void:
	_reset_domain()
	# The scatter is random, so the grass the test measures is placed where it needs it: a WildGrass
	# node in a cell the domain may grow into. It is the same clearing a real claim does.
	var held: Dictionary = IC.occupied_cells(_rt)
	var batch: Array = []
	for c in _rt.claim_eligible_cells():
		if batch.size() < 1 and IC.adjacent_to(c, held):
			batch.append(c)
			held[c] = true
	_expect(batch.size() == 1, "a cell the domain may grow into exists for the grass check")
	if batch.is_empty():
		return
	var rect: Rect2i = IC.cell_rect(_rt, batch[0])
	var spot: Vector3 = BG.tile_centre(rect.get_center(), _rt)
	var authored: int = ISC.plant_at(_rt, "WildGrass", "wild_grass", spot, &"fibre", &"hand", "temperate", 1, Color(0.4, 0.55, 0.25))
	_expect(authored == 1, "a WildGrass node stands inside the cell to claim")
	var plots: Array = [rect]
	var nodes_before: int = _grass_nodes_in(plots)
	_expect(nodes_before >= 1, "the cell holds grass before the claim (%d nodes)" % nodes_before)
	var others_before: int = IC.other_nodes_in(_rt, plots)
	_change_batches = 0
	var on_change := func (_r: Rect2i) -> void: _change_batches += 1
	_rt.claims_changed.connect(on_change)
	var out: Dictionary = _rt.claim_domain(batch)
	_rt.claims_changed.disconnect(on_change)
	var changed := _change_batches
	_expect(bool(out["ok"]), "the grass check's batch claims (reason %s)" % [out["reason"]])
	var nodes_after: int = _grass_nodes_in(plots)
	var others_after: int = IC.other_nodes_in(_rt, plots)
	_expect(nodes_after == 0, "no grass node is left on the claimed cell (%d before, %d after)" % [nodes_before, nodes_after])
	_expect(others_after == others_before, "claimed land keeps its trees, rocks and other resources (%d -> %d)" % [others_before, others_after])
	_expect(changed == 1, "the claim fired claims_changed exactly once for the batch (%d)" % changed)
	# Scatter skips claimed tiles: the island's decor was built with the claim in place.
	if _decor_readable():
		var on_claim: int = ISC.grass_in(_rt, _rt.claims)
		_expect(on_claim == 0, "no grass decor instance stands on the claimed cell (%d found)" % on_claim)
	else:
		print("[t_claims2] headless renderer reports every multimesh instance at the origin: decor clearing is measured windowed in claims2_lab")
	print("[t_claims2] grass: %d node(s) cleared on the claimed cell, %d other nodes kept" % [nodes_before, others_after])

func _grass_nodes_in(plots: Array) -> int:
	var n := 0
	for node in _rt._harvest_nodes.values():
		if is_instance_valid(node) and IC.is_grass(str(node.get("family"))):
			var tile: Vector2i = BG.tile_of((node as Node3D).global_position)
			for r in plots:
				if (r as Rect2i).has_point(tile):
					n += 1
					break
	return n

## A headless run has a dummy renderer: multimesh instance transforms read back as the origin, so
## nothing about decor instances can be measured there (the windowed lab measures it for real).
func _decor_readable() -> bool:
	for mmi in _rt.grass_mm:
		if not is_instance_valid(mmi) or (mmi as MultiMeshInstance3D).multimesh == null:
			continue
		var mm := (mmi as MultiMeshInstance3D).multimesh
		for i in mini(mm.instance_count, 4):
			if mm.get_instance_transform(i).origin != Vector3.ZERO:
				return true
	return false

# ---------------------------------------------------------------- old saves (spec 29 section 4)

func _test_legacy_migration() -> void:
	# An old save: the camp's 14x14 plot first (as setup always wrote it), then a staked 14x14 plot
	# elsewhere, plus a building's cell 20 tiles further out that no plot covered (the migration must
	# keep every placed building inside the domain).
	var camp_tile: Vector2i = BG.tile_of(_rt._camp_pos)
	var camp_plot := Rect2i(camp_tile - Vector2i(7, 7), Vector2i(14, 14))
	var plot := Rect2i(camp_plot.end.x + 20, camp_plot.position.y, 14, 14)
	var bcell := plot.end + Vector2i(6, 0)
	_world.home_claims = [[camp_plot.position.x, camp_plot.position.y, 14, 14], [plot.position.x, plot.position.y, 14, 14]]
	_world.home_domain = {}
	_world._home_buildings_cache = [{"kind": "basket", "cell": [bcell.x, bcell.y], "rot": 0}]
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	_rt = _world.runtime
	_rt.claims_changed.connect(func (r: Rect2i) -> void:
		_changed += 1
		_last_changed = r)
	var used: int = _rt.claim_used()
	var cells: Dictionary = IC.owned_cells(_rt)
	var cover: Array = IC.cells_covering(_rt, plot)
	var inside := true
	for c in cover:
		inside = inside and cells.has(c)
	var building_cell: Vector2i = IC.cell_of(_rt, bcell)
	_expect(inside, "a legacy 14x14 plot migrates to the cells that cover it (%d cells, %s)" % [used, cover])
	_expect(cells.has(building_cell), "the placed building's cell is inside the migrated domain (%s)" % [building_cell])
	_expect(used >= 16, "the migrated domain covers the plot's 16 cells (used=%d, cap=%d)" % [used, _rt.claim_cap()])
	var extra: Array = _rt.claim_eligible_cells()
	var refused := ""
	if extra.size() > 0:
		var out: Dictionary = _rt.claim_domain([extra[0]])
		refused = str(out["reason"])
	_expect(extra.is_empty() or refused == "cap", "a migrated save over the cap allows no new cells (reason %s)" % refused)
	_expect(_rt.claim_used() == used, "no migrated cell was removed (%d -> %d)" % [used, _rt.claim_used()])
	print("[t_claims2] legacy: %d cells cover the 14x14 plot, building cell %s inside, cap %d" % [used, building_cell, _rt.claim_cap()])

# ---------------------------------------------------------------- save / load (spec 29 section 4)

func _test_save_round_trip() -> void:
	_world.home_claims = []
	_world.home_domain = {}
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	_rt = _world.runtime
	var first: Vector2i = _find_cell(func (_c: Vector2i) -> bool: return true)
	_rt.claim_domain([first])
	var elig: Array = _rt.claim_eligible_cells()
	_rt.claim_domain(elig.slice(0, 2))
	var cells_before: Array = (IC.owned_cells(_rt).keys() as Array).duplicate()
	var cap_before: int = _rt.claim_cap()
	var record: Dictionary = _rt.domain_record()
	_expect(record.has("domain_id") and str(record["kind"]) == IC.KIND_TAMED and str(record["status"]) in ["active", "camp"],
		"the record has spec 29 section 3's fields (%s)" % [record.keys()])
	_expect(record.get("cells", []).size() == cells_before.size(), "the saved record lists every cell (%d)" % [record.get("cells", []).size()])
	var saved: Dictionary = _world.home_domain
	_expect(saved.get("cells", []).size() == cells_before.size(), "the world keeps the saved domain (save_now writes this)")
	# Load the same island again: the record (not the rects) is what the cells come back from.
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	_rt = _world.runtime
	var cells_after: Array = (IC.owned_cells(_rt).keys() as Array).duplicate()
	_expect(cells_after.size() == cells_before.size(), "a reload keeps every cell (%d -> %d)" % [cells_before.size(), cells_after.size()])
	var same := true
	for c in cells_before:
		same = same and cells_after.has(c)
	_expect(same, "the reloaded cells are the same cells (%s vs %s)" % [cells_before, cells_after])
	_expect(_rt.claim_cap() == cap_before, "the reloaded cap is unchanged (%d -> %d)" % [cap_before, _rt.claim_cap()])
	print("[t_claims2] save/load: %d cells, cap %d, record keys %s" % [cells_after.size(), _rt.claim_cap(), record.keys()])
