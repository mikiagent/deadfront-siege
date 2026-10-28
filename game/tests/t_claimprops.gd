extends SceneTree
## CLAIMPROPS acceptance (owner bug: "I shouldn't have a tree stump or log within my claimed land").
## Claimed land holds no scenery: claiming a cell (or expanding into one) removes every non-harvestable
## decorative prop whose footprint overlaps the claimed tiles - including kinds that refuse an attack
## clear (a big cliff) and counting stumps and fallen logs; a "harvest node" with no valid gather option
## is a prop and goes too, while a node that really can be gathered stays and still offers its yields.
## Props never (re)spawn on claimed tiles: the scatter skips them, so an island rebuilt from the seed
## with the same claim (the save -> load case) has none inside, and nothing regrows there over time.
## Run: Godot --headless --path game --script res://tests/t_claimprops.gd -> "[t_claimprops] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const WATCHDOG_S := 120.0

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _world: Node
var _rt: Node3D
var BG: GDScript
var IC: GDScript
var ISC: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	create_timer(WATCHDOG_S).timeout.connect(func () -> void:
		print("[t_claimprops] FAIL watchdog: the run did not finish in %.0f s" % WATCHDOG_S)
		quit(2))
	BG = load("res://scripts/world/build_grid.gd")
	IC = load("res://scripts/world/island_claims.gd")
	ISC = load("res://scripts/world/island_scatter.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_claimprops] FAIL %s" % what)

func _run() -> void:
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TClaimPropsHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_world.player_name = "Tess"
	_world.home_claims = []
	_world.home_domain = {}
	_world.away_domain = {}
	_world.harvested.clear()
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_rt = _world.runtime
	var props: Variant = _rt.get("props")
	_expect(props != null, "the island has a props layer")
	if props == null:
		_finish()
		return
	await _test_claim_clears_props(props)
	await _test_expand_clears_props(props)
	await _test_harvestable_node_stays(props)
	await _test_rebuild_is_clean()
	await _test_no_regrow()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_claimprops] PASS")
		quit(0)
	else:
		print("[t_claimprops] FAIL count=%d" % _fails.size())
		quit(1)

# ---------------------------------------------------------------- helpers

func _props() -> Node:
	return _rt.get("props")

## A dry cell the domain may take now (the camp's own land is not a domain cell).
func _next_cell() -> Vector2i:
	var held: Dictionary = IC.occupied_cells(_rt)
	var cells: Array = _rt.claim_eligible_cells()
	for c: Vector2i in cells:
		if IC.adjacent_to(c, held) and IC.cell_block_reason(_rt, c) == "":
			return c
	return IC.NO_CELL

## Forgets the domain but keeps the camp's own land: the props already planted stay where they are.
func _reset_domain() -> void:
	_rt.domain = {}
	_rt.claims.clear()
	IC._rebuild_claim_rects(_rt)
	_rt.set_other_claims([])

## Every uncleared prop row whose centre or footprint cell is claimed (the live number, not a constant).
func _props_on_claimed() -> int:
	var p: Variant = _props()
	if p == null or not p.has_method("on_claimed_count"):
		return 999
	return int(p.call("on_claimed_count"))

func _prop_rows(rect: Rect2i) -> Array:
	var p: Variant = _props()
	if p == null or not p.has_method("rows_in_rect"):
		return []
	var out: Array = []
	for row in (p.call("rows_in_rect", rect) as Array):
		if not bool((row as Dictionary).get("cleared", false)):
			out.append(row)
	return out

func _node_at(tile: Vector2i) -> Node:
	for n in _rt._harvest_nodes.values():
		if is_instance_valid(n) and BG.tile_of((n as Node3D).global_position) == tile:
			return n
	return null

func _gatherable(node: Node) -> bool:
	if node == null or not node.has_method("options"):
		return false
	for o in (node.call("options") as Array):
		var item := StringName(str((o as Dictionary).get("item", "")))
		if item != &"" and _item_exists(item):
			return true
	return false

## Data is an autoload: it has no identifier at compile time in a --script test.
func _item_exists(item: StringName) -> bool:
	var d: Node = root.get_node_or_null("Data")
	return d != null and (d as Object).call("item", item) != null

## A harvest node with no gather route at all: the kind of thing the owner calls a prop.
func _make_dud_node(tile: Vector2i) -> Node:
	var node: Node = (load("res://scenes/world/harvest_node.tscn") as PackedScene).instantiate()
	node.name = "DudNode"
	node.position = BG.tile_centre(tile, _rt)
	_rt.add_child(node)
	node.call("setup", &"dud_node", &"not_an_item_at_all", 1, 1, {}, &"none", Color.WHITE, 1.0, 60.0, "", false, 1)
	_rt._harvest_nodes["dud_node"] = node
	return node

# ---------------------------------------------------------------- claim (spec 29 section 4 + owner)

func _test_claim_clears_props(props: Node) -> void:
	_reset_domain()
	var cell := _next_cell()
	_expect(cell != IC.NO_CELL, "a cell the domain may claim exists")
	if cell == IC.NO_CELL:
		return
	var rect: Rect2i = IC.cell_rect(_rt, cell)
	# Known scenery inside the cell: a fallen log, a tree stump and a big cliff (a log and a stump are
	# the owner's own examples; the cliff never clears from an attack, so a claim must still take it).
	var log_tile := rect.position + Vector2i(1, 1)
	var stump_tile := rect.position + Vector2i(2, 2)
	var cliff_tile := rect.position + Vector2i(1, 3)
	_expect(bool(props.call("add_prop", "fallen_log", BG.tile_centre(log_tile, _rt), 3.5)), "a fallen log is planted in the cell to claim")
	_expect(bool(props.call("add_prop", "tree_stump", BG.tile_centre(stump_tile, _rt), 1.0)), "a tree stump is planted in the cell to claim")
	_expect(bool(props.call("add_prop", "cliff_rock", BG.tile_centre(cliff_tile, _rt), 4.0)), "a cliff is planted in the cell to claim")
	var dud := _make_dud_node(rect.position + Vector2i(3, 0))
	var alive := _make_alive_node(rect.position + Vector2i(0, 2))
	var before: int = _prop_rows(rect).size()
	_expect(before >= 3, "the cell holds scenery before the claim (%d rows)" % before)
	var out: Dictionary = _rt.claim_domain([cell])
	_expect(bool(out["ok"]), "the cell is claimed (reason %s)" % [out["reason"]])
	await process_frame
	var after: int = _prop_rows(rect).size()
	_expect(after == 0, "no prop is left inside the claimed cell (%d before, %d after)" % [before, after])
	_expect(_props_on_claimed() == 0, "no prop anywhere on claimed land (%d found)" % _props_on_claimed())
	_expect(not is_instance_valid(dud), "a harvest node with no gather option is removed like a prop")
	_expect(is_instance_valid(alive), "a harvest node that can be gathered stays on claimed land")
	_expect(_gatherable(alive), "the node that stays still offers a gather option")
	# Claiming did not take the camp's own land or break the claim record.
	_expect(_rt.claim_used() == 1, "the claim record holds the one cell (used=%d)" % _rt.claim_used())
	print("[t_claimprops] claim: %d props removed from %s, dud gone=%s, tree stays=%s" % [before, rect, not is_instance_valid(dud), is_instance_valid(alive)])

## A plant node with a real, bare-handed gather route (Plant -> herb_leaf).
func _make_alive_node(tile: Vector2i) -> Node:
	ISC.plant_at(_rt, "Plant", "plant", BG.tile_centre(tile, _rt), &"herb_leaf", &"none", "temperate", 1, Color(0.35, 0.55, 0.25))
	return _node_at(tile)

# ---------------------------------------------------------------- expand

func _test_expand_clears_props(props: Node) -> void:
	var cell := _next_cell()
	_expect(cell != IC.NO_CELL, "a cell adjacent to the domain exists to expand into")
	if cell == IC.NO_CELL:
		return
	var rect: Rect2i = IC.cell_rect(_rt, cell)
	var tile := rect.position + Vector2i(2, 1)
	_expect(bool(props.call("add_prop", "fallen_log", BG.tile_centre(tile, _rt), 3.0)), "a fallen log is planted in the cell to expand into")
	_expect(_prop_rows(rect).size() >= 1, "the cell to expand into holds the log")
	var out: Dictionary = _rt.claim_domain([cell])
	_expect(bool(out["ok"]), "the adjacent cell expands the domain (reason %s)" % [out["reason"]])
	await process_frame
	_expect(_prop_rows(rect).is_empty(), "expanding removes the props in the new cell (%d left)" % _prop_rows(rect).size())
	_expect(_props_on_claimed() == 0, "no prop is on claimed land after the expansion (%d found)" % _props_on_claimed())
	print("[t_claimprops] expand: %s clean, used=%d" % [rect, _rt.claim_used()])

# ---------------------------------------------------------------- a harvestable tree inside stays
# Spec 29 does not say a domain is cleared of resources: only scenery goes. A tree is a resource.

func _test_harvestable_node_stays(props: Node) -> void:
	var cell := _next_cell()
	if cell == IC.NO_CELL:
		print("[t_claimprops] no further cell to grow into; tree check skipped")
		return
	var rect: Rect2i = IC.cell_rect(_rt, cell)
	var tile := rect.position + Vector2i(1, 1)
	ISC.plant_at(_rt, "Rock", "rock", BG.tile_centre(tile, _rt), &"stone", &"pick", "temperate", 1, Color(0.5, 0.5, 0.48))
	var rock := _node_at(tile)
	_expect(rock != null, "a harvestable rock node stands in the cell to claim")
	var out: Dictionary = _rt.claim_domain([cell])
	_expect(bool(out["ok"]), "the cell with the rock is claimed (reason %s)" % [out["reason"]])
	await process_frame
	_expect(rock != null and is_instance_valid(rock), "a harvestable rock inside a claimed cell stays")
	_expect(_gatherable(rock), "the rock still offers a gather option after the claim")
	_expect(_props_on_claimed() == 0, "the claim left no scenery on its cells (%d found)" % _props_on_claimed())
	print("[t_claimprops] harvestable rock kept inside %s" % rect)

# ---------------------------------------------------------------- save -> load (the seed, not the save)

## A saved claim is re-applied before the props are scattered, so a rebuild from the same seed puts
## nothing on the claimed tiles: the cleaning is a build-time filter, not a save-format change.
func _test_rebuild_is_clean() -> void:
	var cells: Array = (IC.owned_cells(_rt).keys() as Array).duplicate()
	_expect(cells.size() >= 3, "the domain holds the cells claimed above (%d)" % cells.size())
	var record: Dictionary = _rt.domain_record()
	_expect((record.get("cells", []) as Array).size() == cells.size(), "the domain record lists every cell (save format unchanged)")
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	await physics_frame
	_rt = _world.runtime
	var same := true
	var owned_now: Dictionary = IC.owned_cells(_rt)
	for c: Vector2i in cells:
		same = same and owned_now.has(c)
	_expect(same, "the reloaded island has the same claimed cells (%d)" % owned_now.size())
	_expect(_props_on_claimed() == 0, "a rebuilt island scatters no prop on claimed cells (%d found)" % _props_on_claimed())
	var duds := 0
	for n in _rt._harvest_nodes.values():
		if is_instance_valid(n) and not _gatherable(n):
			var tile: Vector2i = BG.tile_of((n as Node3D).global_position)
			if _rt.is_claimed(tile):
				duds += 1
	_expect(duds == 0, "a rebuilt island has no non-gatherable node on claimed land (%d found)" % duds)
	print("[t_claimprops] rebuild: %d claimed cells, props on them=%d" % [owned_now.size(), _props_on_claimed()])

# ---------------------------------------------------------------- nothing regrows on claimed land

func _test_no_regrow() -> void:
	var game: Node = root.get_node_or_null("Game")
	var was: float = float(game.get("fast_regen_mult")) if game != null else 1.0
	if game != null:
		game.set("fast_regen_mult", 60.0)
	for i in 8:
		await process_frame
	if game != null:
		game.set("fast_regen_mult", was)
	_expect(_props_on_claimed() == 0, "no prop regrows on claimed land over simulated regrow time (%d found)" % _props_on_claimed())
	var regrown_dud := 0
	for n in _rt._harvest_nodes.values():
		if is_instance_valid(n) and not _gatherable(n) and _rt.is_claimed(BG.tile_of((n as Node3D).global_position)):
			regrown_dud += 1
	_expect(regrown_dud == 0, "no non-gatherable node regrows on claimed land (%d found)" % regrown_dud)
	print("[t_claimprops] regrow: props on claimed land=%d" % _props_on_claimed())
