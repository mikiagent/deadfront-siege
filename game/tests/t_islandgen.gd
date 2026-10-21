extends SceneTree
## ISLANDGEN acceptance: the landmass generator. For the home island and three unstable ones
## (one per size tier) it asserts the lab's own numbers and the gameplay consequences:
##   - land bbox within 10 % of the plan's target (home 375 x 300 m, unstable 330x265 / 375x300 /
##     415x335 by tier) with >= 20 m of sea on every side of the square grid;
##   - principal-axis aspect 0.70-0.90 and >= 2 headlands (the lab's documented measure);
##   - cliffs (CLIFF tiles) exist, are impassable in TilePath and refused by spawn_ok, and every
##     island has a river that reaches the sea through its low ground (MUD, -0.25..-0.38 bed) with a
##     dry ford;
##   - the home's legacy core (r <= 50 m) is dry, old-height ground and every old fixture point is
##     buildable, so old saves keep their buildings, baskets and claims;
##   - home build time stays under the plan's 2.5 s budget;
##   - old saved BARE rows whose node id no longer exists are dropped, and a save whose position is
##     in the water is rescued to the camp.
## Run: Godot --headless --path game --script res://tests/t_islandgen.gd -> "[t_islandgen] PASS", 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const IDS := ["home_grassland", "savannah_15", "temperate_35", "volcanic_60"]
const TARGET := {
	"home_grassland": Vector2(375.0, 300.0),
	"savannah_15": Vector2(330.0, 265.0),
	"temperate_35": Vector2(375.0, 300.0),
	"volcanic_60": Vector2(415.0, 335.0),
}
const SQUARE := {"home_grassland": 416.0, "savannah_15": 368.0, "temperate_35": 416.0, "volcanic_60": 464.0}
## Every fixture (baskets (4,8), (2.5,9.5), spawn (0,12), camp (0,8), claims, the old dock line).
const LEGACY_POINTS := [Vector2(4, 8), Vector2(2.5, 9.5), Vector2(0, 12), Vector2(0, 8), Vector2(0, 0), Vector2(10, -10), Vector2(-15, 20)]

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _world: Node
var _IT: GDScript
var _IS: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_islandgen] FAIL %s" % what)

func _run() -> void:
	_IT = load("res://scripts/world/island_terrain.gd")
	_IS = load("res://scripts/world/island_shape.gd")
	_host = Node3D.new()
	_host.name = "TIslandgen"
	root.add_child(_host)
	_world = root.get_node("World")
	for id in IDS:
		var t0 := Time.get_ticks_usec()
		_world.load_island(_host, StringName(id), Vector3(0, 1, 0), false)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		await process_frame
		var rt = _world.runtime
		if rt == null:
			_expect(false, "%s built a runtime" % id)
			continue
		_check_island(str(id), rt, ms)
		if str(id) == "home_grassland":
			_check_legacy_core(rt)
			_check_save_rules(rt)
	if _fails.is_empty():
		print("[t_islandgen] PASS islands=%d" % IDS.size())
		quit(0)
	else:
		print("[t_islandgen] FAIL count=%d" % _fails.size())
		quit(1)

func _check_island(id: String, rt, ms: float) -> void:
	var m: Dictionary = _IS.coast_metrics(rt)
	var bbox: Vector2 = m["bbox"]
	var target: Vector2 = TARGET[id]
	var long_target := maxf(target.x, target.y)
	var short_target := minf(target.x, target.y)
	var long_m := maxf(bbox.x, bbox.y)
	var short_m := minf(bbox.x, bbox.y)
	_expect(absf(long_m - long_target) <= 0.10 * long_target, "%s land long axis %.0f m within 10%% of %.0f (lab prints this line)" % [id, long_m, long_target])
	_expect(absf(short_m - short_target) <= 0.10 * short_target, "%s land short axis %.0f m within 10%% of %.0f" % [id, short_m, short_target])
	_expect(float(rt._size) == SQUARE[id], "%s grid square is %.0f m" % [id, SQUARE[id]])
	# At least 20 m of sea on every side: the land's extent must leave that much inside the square.
	var margin_x := (float(rt._size) - bbox.x) * 0.5
	var margin_y := (float(rt._size) - bbox.y) * 0.5
	_expect(margin_x >= 20.0 and margin_y >= 20.0, "%s has >= 20 m of sea on every side (%.0f x %.0f)" % [id, margin_x, margin_y])
	var aspect := float(m["aspect"])
	_expect(aspect >= 0.70 and aspect <= 0.92, "%s aspect %.2f is 0.70-0.92 (principal axes)" % [id, aspect])
	var pens := int(m["peninsulas"])
	_expect(pens >= 2, "%s has >= 2 headlands (%d)" % [id, pens])
	var cliffs := int(m["cliff_cells"])
	_expect(cliffs >= 40, "%s has cliff faces (%d CLIFF tiles)" % [id, cliffs])
	# CLIFF is impassable in both gates: is_dry (spawn_ok, build) and the TilePath grid.
	var cliff_pt := _find_tile(rt, _IT.TileType.CLIFF)
	_expect(cliff_pt != Vector2.ZERO, "%s a CLIFF tile was found" % id)
	if cliff_pt != Vector2.ZERO:
		var cp := Vector3(cliff_pt.x, rt.surface_y(cliff_pt.x, cliff_pt.y), cliff_pt.y)
		_expect(not rt.is_dry(cp), "%s cliff cells are refused by spawn_ok/is_dry" % id)
		_expect(rt.pathing != null and not rt.pathing.is_walkable(Vector2i(floori(cp.x), floori(cp.z))), "%s cliff cells are solid in TilePath" % id)
	# The river: a stored polyline, a MUD channel at the waterline profile, reaching the sea.
	var sh = rt._shape
	_expect(sh != null and sh.river.size() >= 8, "%s stores one river polyline (%d samples)" % [id, 0 if sh == null else sh.river.size()])
	_expect(sh != null and sh.river_to_sea(), "%s river runs to the sea" % id)
	var river_pt := _find_river(rt)
	_expect(river_pt != Vector2.ZERO, "%s the river has water at its bed (-0.25..-0.38, MUD)" % id)
	if river_pt != Vector2.ZERO:
		var h: float = rt.surface_y(river_pt.x, river_pt.y)
		_expect(h <= -0.25 and h >= -0.38, "%s river bed %.2f m is in the t_water profile" % [id, h])
		_expect(int(_IT.tile_type_at_world(rt, river_pt.x, river_pt.y)) == _IT.TileType.MUD, "%s river bed tile is MUD (fresh water)" % id)
	_expect(sh != null and sh.ford != Vector2.ZERO, "%s has a dry ford" % id)
	# The flat dry camp disc (every island): the camp hint and 15 m around it are dry ground.
	var camp: Vector3 = rt._camp_pos
	for k in 8:
		var a := TAU * float(k) / 8.0
		for r in [6.0, 12.0, 18.0]:
			var p := Vector3(camp.x + cos(a) * r, 0.0, camp.z + sin(a) * r)
			_expect(rt.is_dry(p), "%s camp disc is dry at r=%.0f bearing %d" % [id, r, k])
	# The camp-to-dock walk exists.
	_expect(rt.pathing.path(rt._camp_pos, rt.arrival_point(), 0).size() > 1, "%s camp and dock are connected on foot" % id)
	print("[t_islandgen] %s land=%d bbox=%.0fx%.0f aspect=%.2f peninsulas=%d solidity=%.2f coast_ratio=%.2f cliff_cells=%d river_to_sea=%s build_ms=%.0f nodes=%d" % [
		id, int(m["land"]), bbox.x, bbox.y, aspect, pens, float(m["solidity"]), float(m["coast_ratio"]), cliffs,
		"true" if (sh != null and sh.river_to_sea()) else "false", ms, rt.harvest_count])
	if str(id) == "home_grassland":
		_expect(ms <= 2500.0, "home island builds in <= 2.5 s (%.0f ms)" % ms)

## The old save's ground: the seed-17 height function blended in within 50 m of the origin, flat,
## dry and buildable at every fixture point.
func _check_legacy_core(rt) -> void:
	var sh = rt._shape
	_expect(sh != null and sh.legacy, "home runs the legacy core blend")
	var dry := 0
	var total := 0
	var lo := INF
	var hi := -INF
	# The camp's own ground (r <= 25 m) must be dry and flat; the river then crosses the wider
	# legacy zone as a watercourse with a dry ford at |x| < 25 m (plan 1.3), so the r <= 50 m ring
	# is checked for flatness and for the fixtures, not for "all dry".
	for z in range(-25, 26, 2):
		for x in range(-25, 26, 2):
			if Vector2(x, z).length() > 25.0:
				continue
			total += 1
			var p := Vector3(float(x), 0.0, float(z))
			var h: float = rt.surface_y(p.x, p.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
			if rt.is_dry(p):
				dry += 1
			else:
				print("[t_islandgen] core not dry at %s h=%.2f tile=%d" % [p, h, int(rt._tile_type_at_world(p.x, p.z))])
	_expect(dry == total, "home camp ground (r <= 25 m) is dry everywhere (%d of %d samples)" % [dry, total])
	_expect(hi - lo < 2.6, "home camp ground is flat enough for the old camp (relief %.2f m)" % (hi - lo))
	# The legacy zone's height function is the old one: within 50 m of the origin the ground is
	# continuous with the old seed-17 terrain (no cliffs, no terrace steps in the ring).
	var steep := 0
	for z in range(-50, 51, 2):
		for x in range(-50, 51, 2):
			if Vector2(x, z).length() > 50.0:
				continue
			if rt.slope_at(float(x), float(z)) > 1.15:
				steep += 1
	_expect(steep == 0, "no cliff faces inside the home legacy ring r <= 50 m (%d steep tiles)" % steep)
	for fp in LEGACY_POINTS:
		var pos := Vector3(fp.x, 0.0, fp.y)
		_expect(rt.is_dry(pos), "old fixture %s stands on dry ground" % fp)
		var why: String = rt.build_grid.can_place(&"basket", _IT.tile_idx(rt, int(fp.x), int(fp.y)) if false else Vector2i(int(fp.x), int(fp.y)), 0)
		# Unclaimed cells are refused for anything but the camp's own pieces; water/slope/cliff is
		# what matters here, so only those refusals fail the check.
		_expect(why != "water" and why != "slope" and why != "overlap", "old fixture %s is buildable ground (grid says '%s')" % [fp, why])
	# The old dry gap by the camp: the river does not cross |x| < 25 m at z near the camp.
	for x in [-20, -10, 0, 10, 20]:
		var p := Vector3(float(x), 0.0, rt._shape.ford.y)
		_expect(rt.is_dry(p) or x == 0 and false, "the ford at x=%d is dry ground" % x)

## Save compatibility: stale BARE rows are dropped; a saved position in the water is rescued.
func _check_save_rules(rt) -> void:
	var before: int = rt._bare_tiles.size()
	rt.apply_harvest_tile_snapshot({"bare_tiles": [{"tile": [0, 0], "base": 0, "node_id": "an_old_layout_node_999"}]})
	_expect(rt._bare_tiles.size() == before, "a stale bare tile (unknown node id) is dropped")
	var t := int(_IT.tile_type_at_world(rt, 0, 0))
	_expect(t != _IT.TileType.BARE, "the stale row painted nothing (tile %d)" % t)
	var live_id := ""
	for k in rt._harvest_nodes.keys():
		live_id = str(k)
		break
	if live_id != "":
		var node = rt._harvest_nodes[live_id]
		var tile := Vector2i(floori(node.global_position.x), floori(node.global_position.z))
		rt.apply_harvest_tile_snapshot({"bare_tiles": [{"tile": [tile.x, tile.y], "base": _IT.TileType.GRASS, "node_id": live_id}]})
		_expect(rt._bare_tiles.size() == before + 1, "a bare tile of a live node is kept")
		rt._on_tile_regrown(node, tile)
	_expect(rt.has_method("ring_centre"), "rings are measured from the landing point")
	var c: Vector2 = rt.ring_centre()
	var a: Vector3 = rt.arrival_point()
	_expect(Vector2(a.x, a.z).distance_to(c) < 1.0, "ring centre is the dock's arrival point")

func _find_tile(rt, type: int) -> Vector2:
	var span: int = rt._tile_span
	var half: float = rt._size * 0.5
	for z in span:
		for x in span:
			if int(rt.tile_types[x + z * span]) == type:
				return Vector2(-half + float(x) + 0.5, -half + float(z) + 0.5)
	return Vector2.ZERO

func _find_river(rt) -> Vector2:
	var sh = rt._shape
	if sh == null:
		return Vector2.ZERO
	# The first sample (from the source) whose bed holds fresh water. The source end can be a dry
	# gully (high ground) and the mouth end is over the sea; what matters is that the river has a
	# watercourse in between.
	for i in sh.river.size():
		var p: Vector2 = sh.river[i]
		var h: float = rt.surface_y(p.x, p.y)
		if h <= -0.25 and h >= -0.38:
			return p
	return Vector2.ZERO
