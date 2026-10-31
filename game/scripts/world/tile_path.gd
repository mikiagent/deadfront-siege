class_name TilePath
extends Node
## 1 m tile A* pathing over island terrain + occupancy.
## Terrain walkability and weights are sampled once in setup(); after that only changed cells
## are re-flagged (a full rebuild measured 440-572 ms per building change on temperate_25).
## CONTRACT (contracts v2, pathing): path() returns the points and records reachability in
## `last_reachable`, which is a member of the shared TilePath and therefore only valid until the
## next path() call. Single-threaded callers must read it immediately; the server-side reuse (W3)
## must call path_result() instead, which returns both values in one Dictionary.

const DEFAULT_MAX_LEN := 96
const REBUILD_MARGIN := 2
const NO_TILE := Vector2i(-2147483648, -2147483648)

var runtime: Node3D
## False after path() when the goal tile cannot be reached (enclosed, or off the walkable
## grid); the returned points then stop at the closest reachable tile.
var last_reachable: bool = true
var _astar := AStarGrid2D.new()
var _region: Rect2i = Rect2i()
var _dirty: bool = false
## PERF2 route cache: a far goal (the walk to a point 180-260 m off) replans every 1.5 s, and each
## replan ran A* over the whole distance (7-12 ms desktop) for a route that had not changed. The last
## long route is kept with the goal and the grid version it was found on; a replan to the same goal on
## the same grid joins the walker onto the nearest tile of that route with a short A* and reuses the
## rest (an optimal route's tail is still optimal). Any blocker change bumps the version.
const ROUTE_CACHE_MIN := 64  ## tiles: shorter routes are cheap, they always re-run A*
const ROUTE_JOIN_TILES := 12 ## a walker further than this from the cached route re-runs A*
var _grid_version: int = 0
var _route: Array[Vector2i] = []
var _route_goal: Vector2i = Vector2i(-2147483648, -2147483648)
var _route_version: int = -1
var _route_reach: bool = false
var _route_off: bool = false ## true while an owner path has its walls opened (never cached)
var route_cache_hits: int = 0
## Water / off-island tiles, static per island: one byte per region tile (1 = terrain-solid), row-major
## from _region.position. A byte array, not a Vector2i dictionary: the tutorial's 880 m region has
## ~400k such tiles and the dictionary inserts were a third of the rebuild.
var _terrain_mask: PackedByteArray = PackedByteArray()
var _harvest: Dictionary = {} ## Vector2i -> true: live HarvestNode trunks and boxes
var _build: Dictionary = {} ## Vector2i -> true: BuildGrid cells that block (closed gates do, open ones don't)
var _props: Dictionary = {} ## Vector2i -> true: colliding scenery props (IslandProps) that block

func setup(owner_runtime: Node3D) -> void:
	runtime = owner_runtime
	_rebuild()

## No cell list: something changed somewhere (harvest node depleted/regrown, occupancy cleared).
## The next path() diffs harvest and build blockers and re-flags only the cells that differ.
func mark_dirty() -> void:
	_dirty = true

## Re-flag exactly these cells now (BuildGrid occupy/release/reserve, gate open/close).
func update_cells(cells: Array) -> void:
	var grid := _grid()
	for c in cells:
		if not c is Vector2i:
			continue
		if grid and grid.blocks_path(c):
			_build[c] = true
		else:
			_build.erase(c)
		_apply(c)

func is_walkable(tile: Vector2i) -> bool:
	if _dirty:
		_refresh()
	return _region.has_point(tile) and not _astar.is_point_solid(tile)

## for_owner: the owning survivor's path, which goes through its own walls and closed doors
## (HANDOFF section 8); creatures and everyone else get the default.
func path(from_world: Vector3, to_world: Vector3, max_len: int = DEFAULT_MAX_LEN, for_owner: bool = false) -> PackedVector3Array:
	if not for_owner:
		return _path(from_world, to_world, max_len)
	if _dirty:
		_refresh()
	# The owner's walls are a handful of cells: open them for this one query, then close them again.
	var grid := _grid()
	var opened: Array[Vector2i] = []
	if grid:
		for c in grid.structures.path_blocked_cells():
			if _region.has_point(c) and not _terrain_solid(c) and _astar.is_point_solid(c) and not _harvest.has(c) and not grid.blocks_path(c, true):
				_astar.set_point_solid(c, false)
				opened.append(c)
	_route_off = not opened.is_empty()
	var out := _path(from_world, to_world, max_len)
	_route_off = false
	for c in opened:
		_apply(c)
	return out

func _path(from_world: Vector3, to_world: Vector3, max_len: int) -> PackedVector3Array:
	last_reachable = false
	if runtime == null:
		return PackedVector3Array()
	if _dirty:
		_refresh()
	var from_tile := _closest_walkable(BuildGrid.tile_of(from_world))
	var to_tile := _closest_walkable(BuildGrid.tile_of(to_world))
	if from_tile == NO_TILE or to_tile == NO_TILE:
		return PackedVector3Array()
	if from_tile == to_tile:
		last_reachable = true
		var single := PackedVector3Array([BuildGrid.tile_centre(to_tile, runtime)])
		_log_len(single.size())
		return single
	var tiles := _cached_route(from_tile, to_tile)
	if not tiles.is_empty():
		last_reachable = _route_reach
		route_cache_hits += 1
	else:
		var ids := _astar.get_id_path(from_tile, to_tile, true)
		if ids.is_empty():
			return PackedVector3Array()
		last_reachable = Vector2i(ids[ids.size() - 1]) == to_tile
		for id in ids:
			tiles.append(Vector2i(id))
		if tiles.size() >= ROUTE_CACHE_MIN and not _route_off:
			_route = tiles.duplicate()
			_route_goal = to_tile
			_route_version = _grid_version
			_route_reach = last_reachable
	if max_len > 0 and tiles.size() > max_len:
		# Keep a real prefix; callers replan before they reach its end. Jumping the last point to
		# the goal used to draw a straight line through whatever lay between.
		tiles.resize(max_len)
	tiles = _string_pull(tiles)
	var out := PackedVector3Array()
	for tile in tiles:
		out.append(BuildGrid.tile_centre(tile, runtime))
	_log_len(out.size())
	return out

## path() with its reachable flag, for callers that cannot read a shared member right away.
func path_result(from_world: Vector3, to_world: Vector3, max_len: int = DEFAULT_MAX_LEN, for_owner: bool = false) -> Dictionary:
	var points := path(from_world, to_world, max_len, for_owner)
	return {"points": points, "reachable": last_reachable}

## The cached route's tail from the walker's tile, or [] when it cannot be reused (another goal, a
## changed grid, a walker off the route, an owner path).
func _cached_route(from_tile: Vector2i, to_tile: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _route_off or _route.is_empty() or _route_goal != to_tile or _route_version != _grid_version:
		return out
	var best := -1
	var best_d := ROUTE_JOIN_TILES * ROUTE_JOIN_TILES + 1
	for i in _route.size():
		var d := _route[i] - from_tile
		var dd := d.x * d.x + d.y * d.y
		if dd <= best_d:  # ties go to the later tile: closer to the goal
			best_d = dd
			best = i
	if best < 0:
		return out
	if _route[best] != from_tile:
		var head := _astar.get_id_path(from_tile, _route[best], false)
		if head.is_empty():
			return out
		for id in head:
			out.append(Vector2i(id))
		best += 1
	for i in range(best, _route.size()):
		out.append(_route[i])
	return out

func _log_len(length: int) -> void:
	if Game == null:
		return
	if Game.lab_name != "" or Game.debug_overlay:
		print("[path] len=%d%s" % [length, "" if last_reachable else " unreachable"])

func _rebuild() -> void:
	if runtime == null:
		return
	_dirty = false
	_grid_version += 1
	_region = _build_region()
	_astar.region = _region
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.jumping_enabled = false
	_astar.update()
	_terrain_mask = PackedByteArray()
	_terrain_mask.resize(_region.size.x * _region.size.y)
	_terrain_mask.fill(0)
	_harvest = _harvest_blockers()
	_build = _build_blockers()
	_props = _prop_blockers()
	PerfTrace.mark("pathing.prep")
	# Per tile the loop needs the ground height (tile_centre), the dry flag, the tile type and the
	# slope; read them once, straight from the runtime's own arrays (same rules, same clamps as
	# is_dry / tile_type_at_world / slope_deg) instead of through five helper calls and five grid
	# samples. A runtime without the tile map (a bare lab host) takes the old path unchanged.
	var fast := runtime.get("dry_walk") is PackedByteArray and (runtime.get("dry_walk") as PackedByteArray).size() > 0 \
		and int(runtime.get("_tile_span")) > 0 and (runtime.get("tile_types") as PackedByteArray).size() > 0
	var half := float(runtime.get("_size")) * 0.5
	var span := int(runtime.get("_tile_span"))
	var walk: PackedByteArray = runtime.get("dry_walk") if fast else PackedByteArray()
	var types: PackedByteArray = runtime.get("tile_types") if fast else PackedByteArray()
	var approach := Rect2i()
	var has_approach := false
	if fast and runtime.has_method("harbour_approach_rect"):
		approach = runtime.call("harbour_approach_rect")
		has_approach = approach.size.x > 0 and approach.size.y > 0
	if not fast:
		for z in range(_region.position.y, _region.end.y):
			for x in range(_region.position.x, _region.end.x):
				var tile := Vector2i(x, z)
				var pos := BuildGrid.tile_centre(tile, runtime)
				# The dock's approach strip is walkable though it lies on the beach (spawn_ok(false)'s rule).
				if not runtime.is_dry(pos) and not runtime.on_harbour_approach(pos):
					_terrain_mask[(x - _region.position.x) + (z - _region.position.y) * _region.size.x] = 1
					_astar.set_point_solid(tile, true)
					continue
				# Weight is set even under blockers so a released cell keeps its terrain cost.
				_astar.set_point_weight_scale(tile, _weight(pos))
				_astar.set_point_solid(tile, _blocked(tile))
		PerfTrace.mark("pathing.loop")
		return
	# PERF2: every tile starts solid (one engine call) and only walkable tiles are visited past the
	# dry test, so a water tile costs a byte read and a byte write instead of a Vector3, two engine
	# calls and a dictionary insert. Same rules and the same weights as before, tile for tile.
	_astar.fill_solid_region(_region, true)
	_terrain_mask.fill(1)
	var rx := _region.position.x
	var rw := _region.size.x
	var surf: PackedFloat32Array = runtime.get("_surf") if runtime.get("_surf") is PackedFloat32Array else PackedFloat32Array()
	var smooth := not surf.is_empty()
	var surf_res := int(runtime.get("_surf_res"))
	var size := float(runtime.get("_size"))
	for z in range(_region.position.y, _region.end.y):
		var pz := (float(z) + 0.5) * BuildGrid.CELL_SIZE
		var z_in := pz >= -half and pz < half
		var row := clampi(int(floor(pz + half)), 0, span - 1) * span
		var mrow := (z - _region.position.y) * rw
		for x in range(rx, _region.end.x):
			var px := (float(x) + 0.5) * BuildGrid.CELL_SIZE
			var dry := z_in and px >= -half and px < half and walk[clampi(int(floor(px + half)), 0, span - 1) + row] == 1
			# The weight reads the slope only (never the height), so a dry tile samples the four slope
			# points and skips the centre sample height_and_slope also took.
			var slope := 0.0
			if dry:
				slope = _slope_surf(surf, surf_res, size, px, pz) if smooth else IslandTerrain.height_and_slope(runtime, px, pz).y
			elif not (has_approach and _on_approach(Vector2i(x, z), approach, has_approach) and IslandTerrain.height_at(runtime, px, pz) > HarbourSite.WATER_Y):
				continue  # water / off-island: stays solid, its mask byte stays 1, no weight is read
			# (On the dock strip the deck is flat: slope 0.)
			_terrain_mask[(x - rx) + mrow] = 0
			var tile := Vector2i(x, z)
			var idx := clampi(int(floor(px + half)), 0, span - 1) + row
			# Weight is set even under blockers so a released cell keeps its terrain cost. update() left
			# every weight at 1.0, so only a dearer tile (dirt, a steep face) needs the engine call.
			var w := _weight_fast(Vector3.ZERO, int(types[idx]), slope)
			if w != 1.0:
				_astar.set_point_weight_scale(tile, w)
			if not _blocked(tile):
				_astar.set_point_solid(tile, false)
	PerfTrace.mark("pathing.loop")

func _refresh() -> void:
	_dirty = false
	var harvest := _harvest_blockers()
	var build := _build_blockers()
	var props := _prop_blockers()
	var touched := {}
	for c in props:
		if not _props.has(c):
			touched[c] = true
	for c in _props:
		if not props.has(c):
			touched[c] = true
	_props = props
	for c in harvest:
		if not _harvest.has(c):
			touched[c] = true
	for c in _harvest:
		if not harvest.has(c):
			touched[c] = true
	for c in build:
		if not _build.has(c):
			touched[c] = true
	for c in _build:
		if not build.has(c):
			touched[c] = true
	_harvest = harvest
	_build = build
	if not touched.is_empty():
		_grid_version += 1  # a blocker moved: a cached route may cross it
	for c in touched:
		_apply(c)

## Any static blocker: a live resource trunk, a building cell, or a colliding scenery prop.
func _blocked(tile: Vector2i) -> bool:
	return _harvest.has(tile) or _build.has(tile) or _props.has(tile)

## Colliding props (IslandProps.blocked_cells): boulders, logs, mounds, spires, cliffs. Walk-through
## props (reeds, ferns, flowers, pebbles) never reach this list, so they leave paths alone.
func _prop_blockers() -> Dictionary:
	var out := {}
	if runtime == null or not is_instance_valid(runtime):
		return out
	var p: Variant = runtime.get("props")
	if p == null or not is_instance_valid(p) or not p.has_method("blocked_cells"):
		return out
	for c in (p.call("blocked_cells") as Array):
		if c is Vector2i:
			out[c] = true
	return out

## True for a water / off-island tile inside the region (static per island).
func _terrain_solid(tile: Vector2i) -> bool:
	return _terrain_mask[(tile.x - _region.position.x) + (tile.y - _region.position.y) * _region.size.x] == 1

func _apply(tile: Vector2i) -> void:
	if not _region.has_point(tile) or _terrain_solid(tile):
		return
	_astar.set_point_solid(tile, _blocked(tile))

## The walkable grid covers the DRY bounding box (the shaped island is elongated and off-centre;
## a land_radius circle left 300-1,800 dry tiles outside the grid). Falls back to the radius.
func _build_region() -> Rect2i:
	var region := Rect2i()
	if runtime.has_method("dry_bbox"):
		var bb: Rect2i = runtime.dry_bbox()
		if bb.size.x > 0 and bb.size.y > 0:
			region = bb.grow(REBUILD_MARGIN)
	if region.size.x <= 0:
		var rad: int = 80
		if runtime.has_method("land_radius"):
			rad = int(ceil(float(runtime.land_radius()))) + REBUILD_MARGIN
		region = Rect2i(Vector2i(-rad, -rad), Vector2i(rad * 2 + 1, rad * 2 + 1))
	if runtime.has_method("harbour_approach_rect"):  # the dock's approach can lie past the land radius
		region = region.merge(runtime.harbour_approach_rect())
	return region

func _grid() -> BuildGrid:
	if runtime == null:
		return null
	var g: Variant = runtime.get("build_grid")
	return g as BuildGrid if g is BuildGrid else null

func _build_blockers() -> Dictionary:
	var out := {}
	var grid := _grid()
	if grid == null:
		return out
	for cell in grid.occupied_cells():
		if grid.blocks_path(cell):
			out[cell] = true
	for cell in grid.reserved_cells():
		out[cell] = true
	for cell in grid.structures.path_blocked_cells():  # level-0 walls and closed doors
		out[cell] = true
	return out

func _harvest_blockers() -> Dictionary:
	var out := {}
	for n in runtime.get_tree().get_nodes_in_group("harvest"):
		var node := n as HarvestNode
		if node == null:
			continue
		if not node.visible or node.collision_layer == 0:
			continue
		# Every live HarvestNode has a physical trunk/box, including berry bushes
		# and plants. Routing through those unregistered boxes wedges the survivor.
		out[BuildGrid.tile_of(node.global_position)] = true
	return out

## The approach strip is a ~40 x 3 m band: test the tile against its rect first, so only the few
## tiles on it pay for HarbourSite.on_approach (the strip lies past the dry box, so most builds
## have none).
func _on_approach(tile: Vector2i, rect: Rect2i, has_rect: bool) -> bool:
	if not has_rect or not rect.has_point(tile):
		return false
	return runtime.on_harbour_approach(BuildGrid.tile_centre(tile, runtime))

## IslandTerrain.slope_deg on the refined surface with IslandRuntime.surface_y inlined (the same four
## samples, the same arithmetic in the same order, so the same float): one call per tile, not five.
static func _slope_surf(surf: PackedFloat32Array, res: int, size: float, x: float, z: float) -> float:
	var d := 0.75
	var last := float(res - 1)
	var fc := size / last
	var h := [0.0, 0.0, 0.0, 0.0]  # x + d, x - d, z + d, z - d
	for k in 4:
		var sx := x + d if k == 0 else (x - d if k == 1 else x)
		var sz := z + d if k == 2 else (z - d if k == 3 else z)
		var fu := clampf((sx + size * 0.5) / fc, 0.0, last)
		var fv := clampf((sz + size * 0.5) / fc, 0.0, last)
		var fx0 := mini(int(fu), res - 2)
		var fz0 := mini(int(fv), res - 2)
		var ftx := fu - float(fx0)
		var ftz := fv - float(fz0)
		var i := fx0 + fz0 * res
		if ftx + ftz <= 1.0:
			var a := surf[i]
			h[k] = a + (surf[i + 1] - a) * ftx + (surf[i + res] - a) * ftz
		else:
			var b := surf[i + res + 1]
			h[k] = b + (surf[i + res] - b) * (1.0 - ftx) + (surf[i + 1] - b) * (1.0 - ftz)
	var dx := (float(h[0]) - float(h[1])) / (2.0 * d)
	var dz := (float(h[2]) - float(h[3])) / (2.0 * d)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz)))

## _weight's rule on values already read for this tile: DIRT costs 1.4, a face steeper than 22 deg
## at least 2.0 (same comparisons, same result).
func _weight_fast(_pos: Vector3, tile_type: int, slope: float) -> float:
	var w := 1.0
	if tile_type == 3:
		w = 1.4
	if slope > 22.0:
		w = maxf(w, 2.0)
	return w

func _weight(pos: Vector3) -> float:
	var w := 1.0
	var tile_type := 0
	if runtime.has_method("_tile_type_at_world"):
		tile_type = int(runtime._tile_type_at_world(pos.x, pos.z))
	if tile_type == 3:
		w = 1.4
	var slope := 0.0
	if runtime.has_method("_slope_deg"):
		slope = float(runtime._slope_deg(pos.x, pos.z))
	if slope > 22.0:
		w = maxf(w, 2.0)
	return w

func _closest_walkable(tile: Vector2i) -> Vector2i:
	if is_walkable(tile):
		return tile
	for ring in range(1, 7):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if abs(x) != ring and abs(y) != ring:
					continue
				var probe := tile + Vector2i(x, y)
				if is_walkable(probe):
					return probe
	return NO_TILE

func _string_pull(src: Array[Vector2i]) -> Array[Vector2i]:
	if src.size() <= 2:
		return src
	var out: Array[Vector2i] = [src[0]]
	var anchor := src[0]
	var i := 1
	while i < src.size():
		var far := i
		while far + 1 < src.size() and _line_walkable(anchor, src[far + 1]):
			far += 1
		out.append(src[far])
		anchor = src[far]
		i = far + 1
	return out

func _line_walkable(a: Vector2i, b: Vector2i) -> bool:
	for tile in _line_tiles(a, b):
		if _astar.is_point_solid(tile):
			return false
	return true

func _line_tiles(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x0: int = a.x
	var y0: int = a.y
	var x1: int = b.x
	var y1: int = b.y
	var dx: int = absi(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -absi(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		out.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2: int = err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return out
