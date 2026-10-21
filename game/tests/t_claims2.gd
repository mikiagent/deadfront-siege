extends SceneTree
## CLAIMS2 acceptance (owner 2026-10-21: "claimed land shouldn't have the grass, also claims should
## expand in a predictable way and there are claim limits").
## Plots are 14x14 cells on a grid anchored at the base (camp) plot; a claim stakes exactly the free
## orthogonal candidate cell the survivor stands in and nothing otherwise; the candidate set is the
## panel's ghosts; the cap comes from rules.json claims and grows with the Pioneer Level; an off-grid
## saved plot loads unchanged while new plots snap to the grid; grass is never scattered on claimed
## tiles and is cleared from a plot as it is staked while other nodes stay; claims_changed fires once
## per new plot with its rect; saving keeps the plots.
## Run: Godot --headless --path game --script res://tests/t_claims2.gd -> "[t_claims2] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const ME := "Tess"

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player: Node
var _hud: Control
var _world: Node
var _rt: Node3D
var IC: GDScript
var BG: GDScript
var SG: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	# Watchdog: a run that dies mid-test ends, rather than idling to the outer alarm.
	root.get_tree().create_timer(120.0).timeout.connect(func () -> void:
		print("[t_claims2] FAIL watchdog: the run did not finish in 120 s")
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
	SG = load("res://scripts/core/save_game.gd")
	_world = root.get_node("World")
	_world.player_name = ME
	_world.home_claims = []
	_world.unstable_claims = []
	_world.free_claim_used = false
	_world.pioneer_level = 0
	_host = Node3D.new()
	_host.name = "TClaims2Host"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("taken_rects"):
			_hud = c
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	await process_frame
	await physics_frame
	_rt = _world.runtime
	_test_candidates()
	_test_claim_cell()
	_test_outside_refused()
	_test_grass_bare()
	_test_limit_formula()
	_test_limit_refusal()
	_test_signal()
	_test_off_grid_save()
	_test_save_load()
	if _fails.is_empty():
		print("[t_claims2] PASS")
		quit(0)
	else:
		print("[t_claims2] FAIL count=%d" % _fails.size())
		quit(1)

# ---------------------------------------------------------------- helpers

func _base() -> Rect2i:
	return _rt.claims[0]

func _rect(cell: Vector2i) -> Rect2i:
	return IC.cell_rect(_rt, cell)

func _stand(tile: Vector2i) -> void:
	var c: Vector3 = BG.tile_centre(tile, _rt)
	_player.global_position = Vector3(c.x, float(_rt.surface_y(c.x, c.z)) + 0.05, c.z)

func _notices() -> Array:
	var ev: Variant = _hud.get("_events") if _hud else null
	return (ev.get("notices") as Array) if ev != null else []

func _last_notice() -> String:
	var n := _notices()
	return str((n.back() as Dictionary).get("text", "")) if not n.is_empty() else ""

## Reset to the base plot only (in memory and in the save rows), at Pioneer Level `level`.
func _reset(level: int) -> void:
	while _rt.claims.size() > 1:
		_rt.claims.pop_back()
	var b := _base()
	_world.home_claims = [[b.position.x, b.position.y, b.size.x, b.size.y]]
	_world.island_def = {"kind": "private"}
	_world.pioneer_level = level
	if _hud and _hud.has_method("claim_confirm_cancel"):
		_hud.call("claim_confirm_cancel")

# ---------------------------------------------------------------- the grid

## The candidates are the free grid cells orthogonally next to held land: 14x14, snapped to the base
## plot's grid, sharing a full edge with the land held, dry and nobody else's - never a diagonal.
func _test_candidates() -> void:
	_reset(0)
	var base := _base()
	var cands: Array = _rt.claim_candidates()
	print("[t_claims2] base=%s candidates=%s" % [base, cands])
	_expect(cands.size() >= 2, "the camp plot has free orthogonal neighbours (%d)" % cands.size())
	_expect(cands.size() <= 4, "only the four orthogonal neighbours are candidates (%d)" % cands.size())
	var expect_cells := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for c in cands:
		var cell: Vector2i = c
		_expect(expect_cells.has(cell), "candidate %s is an orthogonal neighbour cell of the base" % cell)
		var r: Rect2i = _rect(cell)
		_expect(r.size == Vector2i(14, 14), "candidate %s is 14x14 (%s)" % [cell, r.size])
		_expect(r.position == base.position + cell * 14, "candidate %s sits on the base plot's grid (%s)" % [cell, r])
		var touches := false
		for held in _rt.claims:
			var h: Rect2i = held
			if (r.position.x == h.end.x or r.end.x == h.position.x) and r.position.y < h.end.y and h.position.y < r.end.y:
				touches = true
			elif (r.position.y == h.end.y or r.end.y == h.position.y) and r.position.x < h.end.x and h.position.x < r.end.x:
				touches = true
		_expect(touches, "candidate %s shares a full edge with land held" % cell)
		_expect(_rt.spawn_ok(BG.tile_centre(r.get_center(), _rt), false), "candidate %s is dry land" % cell)
		_expect(_rt.claim_expand_reason(r.get_center()) == "", "candidate %s passes claim_expand_reason" % cell)

## A claim from inside a candidate cell takes exactly that cell, whatever tile in it the survivor is on.
func _test_claim_cell() -> void:
	_reset(0)
	var cands: Array = _rt.claim_candidates()
	if cands.is_empty():
		_expect(false, "setup: at least one candidate to claim")
		return
	var cell: Vector2i = cands[0]
	var want: Rect2i = _rect(cell)
	# Stand on a corner tile, not the centre: the plot must not follow the survivor any more.
	var tile: Vector2i = want.position + Vector2i(1, 2)
	_stand(tile)
	_expect(_rt.claim_plot(tile) == want, "claim_plot names the candidate cell the survivor stands in (%s, want %s)" % [_rt.claim_plot(tile), want])
	_expect(_rt.claim_at(tile), "a claim from inside a candidate cell is staked")
	_expect(_rt.claims.has(want), "the claim took exactly the candidate cell %s (%s)" % [want, _rt.claims])
	_expect(_rt.claims.size() == 2, "one plot was added (%d)" % _rt.claims.size())
	for held in _rt.claims:
		_expect(IC.on_grid(_rt, held), "plot %s is on the base grid" % held)

## Standing outside every candidate cell: no claim, and the notice says where to stand.
func _test_outside_refused() -> void:
	_reset(0)
	var base := _base()
	var start := Vector2i(base.end.x + 60, base.get_center().y)
	var far := start
	for k in 40:
		var t := Vector2i(start.x + k, start.y)
		if _rt.spawn_ok(BG.tile_centre(t, _rt), false) and not _rt.is_claimed(t):
			far = t
			break
	_stand(far)
	var n: int = _rt.claims.size()
	_expect(_rt.claim_candidate_at(far) == IC.NO_CELL, "a tile well off the candidates is in no cell")
	_expect(not _rt.claim_at(far), "a claim outside every candidate cell is refused")
	_expect(_rt.claims.size() == n, "the refused claim added no plot (%d)" % _rt.claims.size())
	_expect(_rt.claim_expand_reason(far).to_lower().contains("stand inside"), "the reason tells the survivor where to stand: \"%s\"" % _rt.claim_expand_reason(far))
	var before := _notices().size()
	_player.actions.claim()
	await process_frame
	await process_frame
	var said := _last_notice()
	_expect(_notices().size() > before, "the press shows a notice (%s)" % said)
	_expect(said.to_lower().contains("stand inside"), "the notice names where to stand: \"%s\"" % said)
	_expect(_rt.claims.size() == n, "the press staked nothing (%d)" % _rt.claims.size())

# ---------------------------------------------------------------- grass

## Claimed land is bare: no grass scattered on it, and staking a plot removes the grass inside it at
## once - the nodes and the decor instances - while every other node stays.
func _test_grass_bare() -> void:
	_reset(0)
	var base := _base()
	var scattered: int = IC.grass_in(_rt, [base])
	print("[t_claims2] grass in the camp plot after scatter=%d" % scattered)
	_expect(scattered == 0, "no grass is scattered on the camp plot (%d)" % scattered)
	var cands: Array = _rt.claim_candidates()
	if cands.is_empty():
		_expect(false, "setup: a candidate cell to plant grass in")
		return
	var cell: Vector2i = cands[0]
	var rect: Rect2i = _rect(cell)
	# Plant one grass node and one non-grass node inside the cell, deterministically.
	var spot := _free_tile(rect)
	var tree_spot := _free_tile(rect, spot)
	print("[t_claims2] grass at %s, tree at %s in %s" % [spot, tree_spot, rect])
	var col := Color(0.4, 0.6, 0.3)
	_rt._plant_at("WildGrass", "grass2_test", BG.tile_centre(spot, _rt), &"dry_grass", &"none", "grassland", 1, col)
	_rt._plant_at("Bush", "bush2_test", BG.tile_centre(tree_spot, _rt), &"fibre_stalk", &"knife", "grassland", 1, col)
	_expect(IC.grass_in(_rt, [rect]) >= 1, "setup: grass planted inside the candidate cell")
	var others_before: int = IC.other_nodes_in(_rt, [rect])
	_expect(others_before >= 1, "setup: a non-grass node inside the cell (%d)" % others_before)
	_expect(_rt.claim_at(rect.get_center()), "the cell is staked")
	_expect(IC.grass_in(_rt, [rect]) == 0, "grass inside the new plot is gone at once (%d)" % IC.grass_in(_rt, [rect]))
	_expect(IC.other_nodes_in(_rt, [rect]) == others_before, "non-grass nodes inside the plot stay (%d, was %d)" % [IC.other_nodes_in(_rt, [rect]), others_before])

## Last free tile in `rect` (or after `avoid`) that holds no harvest node.
## `rows` holds `rect`, numbers int or float (the save file is json).
func _has_row(rows: Array, rect: Rect2i) -> bool:
	for r in rows:
		if not r is Array or (r as Array).size() < 4:
			continue
		if int(r[0]) == rect.position.x and int(r[1]) == rect.position.y and int(r[2]) == rect.size.x and int(r[3]) == rect.size.y:
			return true
	return false

func _free_tile(rect: Rect2i, avoid: Vector2i = Vector2i(1 << 30, 0)) -> Vector2i:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			if t == avoid or _rt.is_claimed(t) or not _rt.spawn_ok(BG.tile_centre(t, _rt), false):
				continue
			if _rt._used_tiles.has(t):
				continue
			if _rt.claim_candidate_at(t) != IC.candidate_of(_rt, rect.get_center()):
				continue
			return t
	return rect.get_center()

# ---------------------------------------------------------------- limits

## The cap from rules.json: home 2 at Pioneer 0, 3 at 10, 6 at 40 and 9 at 70 (max 9); unstable 3
## (its landing camp plot plus two staked).
func _test_limit_formula() -> void:
	var l: Dictionary = IC.limits()
	print("[t_claims2] limits=%s" % l)
	_expect(int(l.get("home_base_plots", -1)) == 2 and int(l.get("plots_per_levels", -1)) == 10 and int(l.get("home_max_plots", -1)) == 9, "rules.json carries the cap numbers (%s)" % l)
	for pair in [[0, 2], [9, 2], [10, 3], [25, 4], [70, 9], [300, 9]]:
		var level: int = pair[0]
		var want: int = pair[1]
		_world.pioneer_level = level
		_world.island_def = {"kind": "private"}
		_expect(IC.limit(_rt) == want, "home at Pioneer %d allows %d plots (%d)" % [level, want, IC.limit(_rt)])
	_world.pioneer_level = 0
	_world.island_def = {"kind": "unstable"}
	_expect(IC.limit(_rt) == 3, "an unstable island allows its landing plot + 2 staked (got %d)" % IC.limit(_rt))
	_world.island_def = {"kind": "private"}

## At the cap CLAIM is refused with the numbers, and claims nothing.
func _test_limit_refusal() -> void:
	_reset(0)
	var limit: int = _rt.claim_limit()
	_expect(limit == 2, "home at Pioneer 0 allows 2 plots (%d)" % limit)
	var cands: Array = _rt.claim_candidates()
	_expect(_rt.claim_at(_rect(cands[0]).get_center()), "the second plot is staked")
	_expect(_rt.claim_used() == 2, "plots used = 2 (%d)" % _rt.claim_used())
	_expect(_rt.claim_limit_reason().begins_with("Land limit reached (2/2)"), "the island names the cap: \"%s\"" % _rt.claim_limit_reason())
	_expect(_rt.claim_limit_reason().contains("Pioneer Level"), "the cap notice says how to raise it: \"%s\"" % _rt.claim_limit_reason())
	var next: Array = _rt.claim_candidates()
	var stood := false
	for c in next:
		var t: Vector2i = _rect(c).get_center()
		if _rt.spawn_ok(BG.tile_centre(t, _rt), false):
			_stand(t)
			stood = true
			break
	_expect(stood, "setup: a candidate cell to stand in at the cap")
	var before := _notices().size()
	var n: int = _rt.claims.size()
	_player.actions.claim()
	await process_frame
	await process_frame
	var said := _last_notice()
	print("[t_claims2] cap notice: %s" % said)
	_expect(_notices().size() > before, "the press at the cap shows a notice")
	_expect(said.contains("Land limit reached (2/2)"), "the notice is the cap one: \"%s\"" % said)
	_expect(_rt.claims.size() == n, "the press at the cap staked nothing (%d)" % _rt.claims.size())
	# Raising the Pioneer Level lifts the cap: the next press is offered again.
	_world.pioneer_level = 10
	_expect(_rt.claim_limit_reason() == "", "Pioneer 10 lifts the cap (%s)" % _rt.claim_limit_reason())
	_world.pioneer_level = 0

## claims_changed fires once per new plot, with that plot's rect.
func _test_signal() -> void:
	_reset(0)
	var seen: Array[Rect2i] = []
	var cb := func (r: Rect2i) -> void: seen.append(r)
	_rt.claims_changed.connect(cb)
	var cell: Vector2i = _rt.claim_candidates()[0]
	var want: Rect2i = _rect(cell)
	_rt.claim_at(want.get_center())
	_expect(seen.size() == 1, "claims_changed fired once for one new plot (%d)" % seen.size())
	_expect(seen.size() == 1 and seen[0] == want, "claims_changed carried the new plot (%s, want %s)" % [seen, want])
	_rt.claims_changed.disconnect(cb)

# ---------------------------------------------------------------- saves

## An off-grid plot from an older save loads unchanged and seeds no grid cell; new plots still snap.
func _test_off_grid_save() -> void:
	_reset(0)
	var base := _base()
	var off := Rect2i(base.position + Vector2i(3, 5), Vector2i(14, 14))
	_world.home_claims.append([off.position.x, off.position.y, off.size.x, off.size.y])
	IC.setup(_rt, {"kind": "private"})
	_expect(_rt.claims.has(off), "an off-grid saved plot loads unchanged (%s)" % str(_rt.claims))
	_expect(not IC.on_grid(_rt, off), "the saved off-grid plot is not treated as a grid cell")
	var old_cell: Vector2i = IC.cell_of(_rt, off.position)
	_expect(not _rt.claim_candidates().has(old_cell), "the off-grid plot seeds no candidate cell of its own")
	var cands: Array = _rt.claim_candidates()
	var cell: Vector2i = cands[0]
	_expect(_rt.claim_at(_rect(cell).get_center()), "a new plot beside it is staked")
	var added: Rect2i = _rt.claims.back()
	_expect(IC.on_grid(_rt, added), "the new plot snaps to the base grid (%s)" % added)
	_expect(added.position == base.position + cell * 14, "the new plot is the cell beside the base (%s)" % added)

## Save keeps the plots: the rows go to the save file, and a reload of the island rebuilds them.
func _test_save_load() -> void:
	_reset(0)
	var cell: Vector2i = _rt.claim_candidates()[0]
	var want: Rect2i = _rect(cell)
	_expect(_rt.claim_at(want.get_center()), "a plot to save is staked")
	var rows: Array = _world.home_claims
	_expect(rows.size() == 2 and _has_row([rows[1]], want), "the new plot is in the saved rows (%s)" % str(rows))
	_expect(SG.save_now(), "the save file is written")
	var read: Dictionary = load("res://scripts/core/save_migrations.gd").read(str(SG.path))
	var data: Dictionary = read.get("data", {}) as Dictionary
	_expect(not data.is_empty(), "the save file reads back")
	if not data.is_empty():
		var saved: Array = (data.get("home", {}) as Dictionary).get("claims", [])
		_expect(_has_row(saved, want), "the save file holds the new plot (%s)" % str(saved))
	# A reload of the same island rebuilds both plots from the rows.
	_rt.claims.clear()
	IC.setup(_rt, {"kind": "private"})
	# The base plot is always seeded first, then every saved row (a row for the base is harmless).
	var cells: Array = []
	for r in _rt.claims:
		cells.append(r)
	_expect(cells.has(_base()) and cells.has(want), "loading the island restores the plots (%s)" % str(_rt.claims))
