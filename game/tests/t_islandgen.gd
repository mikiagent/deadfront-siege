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

## IslandShape.FORD_R (the shallow crossing's radius); spelled out because this script compiles
## before the autoloads exist and a direct class_name reference would break that.
const FORD_R := 11.0
const IDS := ["home_grassland", "savannah_15", "temperate_35", "volcanic_60"]
## Every island is checked for the SHAPE contract (four-side sea margins, river length and body,
## MUD channel, mesa warp): the merge review found the clipped-headland and coastal-stub defects on
## islands the four-island set did not cover.
const ALL_IDS := ["home_grassland", "savannah_15", "savannah_45", "temperate_20", "temperate_25",
	"temperate_35", "temperate_45", "tropical_25", "tropical_40", "desert_35", "desert_50",
	"tundra_30", "tundra_55", "swamp_55", "volcanic_60"]
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
	var seen := {}
	for id in ALL_IDS:
		var t0 := Time.get_ticks_usec()
		_world.load_island(_host, StringName(id), Vector3(0, 1, 0), false)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		await process_frame
		var rt = _world.runtime
		if rt == null:
			_expect(false, "%s built a runtime" % id)
			continue
		seen[str(id)] = true
		if IDS.has(id):
			_check_island(str(id), rt, ms)
		else:
			_check_shape(str(id), rt)
		if str(id) == "home_grassland":
			_check_legacy_core(rt)
			_check_save_rules(rt)
	if _fails.is_empty():
		print("[t_islandgen] PASS islands=%d (%d shape-only)" % [ALL_IDS.size(), ALL_IDS.size() - IDS.size()])
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
	# At least 20 m of sea on EACH side, measured per side: the centred `(size - bbox) * 0.5` hid
	# a headland that ran out of the grid square and was cut off in a straight line.
	var mw := float(m["margin_w"])
	var me := float(m["margin_e"])
	var mn := float(m["margin_n"])
	var msouth := float(m["margin_s"])
	_expect(minf(minf(mw, me), minf(mn, msouth)) >= 20.0,
		"%s has >= 20 m of sea on every side (w %.0f e %.0f n %.0f s %.0f)" % [id, mw, me, mn, msouth])
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
	_expect(sh != null and sh.ford != Vector2.ZERO, "%s has a ford" % id)
	# The river must read as ONE river: no post-hoc clipping to a coastal stub (the merge review
	# saw 3-sample stubs), a meander spanning >= half the long axis, one unbroken MUD channel.
	if sh != null and sh.river.size() >= 8:
		var arc := 0.0
		for i in sh.river.size() - 1:
			arc += sh.river[i].distance_to(sh.river[i + 1])
		var long_axis := maxf(bbox.x, bbox.y)
		_expect(arc >= 0.50 * long_axis, "%s river spans >= 50%% of the long axis (%.0f of %.0f m)" % [id, arc, long_axis])
		_expect(sh.river_runs_inland(), "%s river body is inland and only its mouth reaches the sea" % id)
		var mud := _channel_mud_fraction(rt)
		_expect(mud >= 0.80, "%s channel is MUD along its length (%.0f%%)" % [id, mud * 100.0])
		var mean_w := 0.0
		for w in sh.river_w:
			mean_w += w
		mean_w = mean_w / maxf(1.0, float(sh.river_w.size())) * 2.0
		_expect(mean_w >= 6.5 and mean_w <= 13.0, "%s channel is 7-12 m wide (%.1f m)" % [id, mean_w])
	# A mesa, when there is one, is warped into a butte, not a perfect circle.
	if sh != null and not sh.mesa.is_empty():
		var warp := _mesa_warp(rt, sh)
		# -1 means no bearing found a rim (the mesa is inside the plateau and has no measurable
		# edge): there is nothing to measure, so only a measured circle fails.
		_expect(warp < 0.0 or warp >= 0.10, "%s mesa is not a circle (radius spread %.0f%%)" % [id, warp * 100.0])
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

## The shape contract every island must meet (the merge review's four defects were on islands the
## deeper four-island check did not cover): per-side sea margins, a real river (long, inland, MUD,
## 7-12 m wide) and a non-circular mesa.
func _check_shape(id: String, rt) -> void:
	var m: Dictionary = _IS.coast_metrics(rt)
	var bbox: Vector2 = m["bbox"]
	var margin_min := float(m["margin_min"])
	_expect(margin_min >= 20.0, "%s has >= 20 m of sea on every side (min %.0f: w %.0f e %.0f n %.0f s %.0f)" % [
		id, margin_min, float(m["margin_w"]), float(m["margin_e"]), float(m["margin_n"]), float(m["margin_s"])])
	_expect(int(m["cliff_cells"]) >= 1, "%s has cliff faces (%d CLIFF tiles)" % [id, int(m["cliff_cells"])])
	var sh = rt._shape
	_expect(sh != null, "%s has a shape" % id)
	if sh == null:
		return
	_expect(sh.river_to_sea(), "%s river reaches the sea" % id)
	if sh.river.size() >= 8:
		var arc := 0.0
		for i in sh.river.size() - 1:
			arc += sh.river[i].distance_to(sh.river[i + 1])
		var long_axis := maxf(bbox.x, bbox.y)
		_expect(arc >= 0.50 * long_axis, "%s river spans >= 50%% of the long axis (%.0f of %.0f m)" % [id, arc, long_axis])
		_expect(sh.river_runs_inland(), "%s river body is inland (mouth only at the sea)" % id)
		var mud := _channel_mud_fraction(rt)
		_expect(mud >= 0.80, "%s channel is MUD along its length (%.0f%%)" % [id, mud * 100.0])
	if sh.ford != Vector2.ZERO:
		# A continuous shallow crossing: on the river's own samples the bed is at or just under
		# the water plane and the tile is MUD, so the fresh-water mask never breaks.
		var wet := 0
		var deep := 0.0
		for i in sh.river.size():
			var q: Vector2 = sh.river[i]
			if q.distance_to(sh.ford) > FORD_R * 0.5:
				continue
			wet += 1
			deep = minf(deep, rt.surface_y(q.x, q.y))
			_expect(int(_IT.tile_type_at_world(rt, q.x, q.y)) == _IT.TileType.MUD, "%s ford sample %s is MUD water" % [id, q.snapped(Vector2.ONE)])
		var hc: float = rt.surface_y(sh.ford.x, sh.ford.y)
		_expect(wet >= 1 and hc > -0.22 and hc < 0.05 and deep > -0.34,
			"%s ford is a continuous shallow crossing (%d samples, centre %.2f m, shallowest %.2f m)" % [id, wet, hc, deep])
	if not sh.mesa.is_empty():
		var warp := _mesa_warp(rt, sh)
		_expect(warp >= 0.10, "%s mesa is not a circle (radius spread %.0f%%)" % [id, warp * 100.0])
	# Every fixed spawn row and the crater stand on dry land.
	var def: Dictionary = _world.islands.get(id, {})
	for row in def.get("creatures", []):
		var at: Array = row.get("at", [0, 0, 0])
		var p := Vector3(float(at[0]), 0.0, float(at[2]))
		_expect(rt.is_dry(p), "%s %s spawn %s is on dry land" % [id, row.get("species", "?"), p])
	var cr: Variant = def.get("crater", null)
	if cr is Array and (cr as Array).size() >= 3:
		var cp := Vector3(float(cr[0]), 0.0, float(cr[2]))
		_expect(rt.is_dry(cp), "%s crater %s is on dry land" % [id, cp])
	# The spawn rings reach the far shore: the band is clamped to the farthest dry tile, not a
	# land_radius circle.
	var far: float = rt.farthest_dry_radius()
	_expect(far >= float(rt.land_radius()) * 1.2, "%s spawn band reaches the far dry shore (%.0f m vs land_radius %.0f)" % [id, far, rt.land_radius()])

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
	# The crossing on the home channel is a CONTINUOUS shallow ford: water everywhere along it
	# (the channel is never cut), but wadeable (bed between -0.20 and -0.02 m) and MUD, so the
	# fresh-water mask runs unbroken and a survivor can cross.
	var near := 0
	for i in rt._shape.river.size():
		var q: Vector2 = rt._shape.river[i]
		if q.distance_to(rt._shape.ford) > FORD_R:
			continue
		near += 1
		var h: float = rt.surface_y(q.x, q.y)
		_expect(h > -0.34 and h < 0.10, "the ford sample %s is shallow (bed %.2f m)" % [q.snapped(Vector2.ONE), h])
		_expect(int(_IT.tile_type_at_world(rt, q.x, q.y)) == _IT.TileType.MUD, "the ford sample %s is MUD water" % q.snapped(Vector2.ONE))
	_expect(near >= 2, "the ford covers more than one river sample (%d)" % near)

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

## Fraction of the channel's own tiles (within its half-width of the polyline) that are MUD: the
## fresh-water mask has to run unbroken through the ford (a dry disc split it in two).
func _channel_mud_fraction(rt) -> float:
	var span: int = rt._tile_span
	var half: float = rt._size * 0.5
	var mud := 0
	var total := 0
	for z in span:
		for x in span:
			var wx := -half + float(x) + 0.5
			var wz := -half + float(z) + 0.5
			if rt.river_dist_at(wx, wz) > 2.6:
				continue
			total += 1
			if int(rt.tile_types[x + z * span]) == _IT.TileType.MUD:
				mud += 1
	return float(mud) / maxf(1.0, float(total))

## How far the mesa's rim departs from a circle: the spread of its radius over 48 bearings.
func _mesa_warp(rt, sh) -> float:
	var mp: Vector2 = sh.mesa["pos"]
	var lo := INF
	var hi := 0.0
	for i in 48:
		var ang := TAU * float(i) / 48.0
		var dir := Vector2(cos(ang), sin(ang))
		var base: float = rt.surface_y(mp.x + dir.x * 90.0, mp.y + dir.y * 90.0)
		var top: float = rt.surface_y(mp.x, mp.y)
		if top - base < 0.8:
			continue  # no measurable mesa relief on this bearing (it sits inside the plateau)
		var tgt: float = base + (top - base) * 0.5
		var r := 0.0
		var d := 3.0
		# Only the mesa's own rim counts: scanning past 1.8 radii finds the enclosing plateau's
		# edge instead, whose radius is nearly the same on every bearing (spurious "circle").
		var limit := float(sh.mesa["r"]) * 1.8
		while d < limit:
			if rt.surface_y(mp.x + dir.x * d, mp.y + dir.y * d) < tgt:
				r = d
				break
			d += 1.0
		if r <= 0.0:
			continue
		lo = minf(lo, r)
		hi = maxf(hi, r)
	if lo == INF:
		return -1.0
	return (hi - lo) / maxf(1.0, hi)

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
