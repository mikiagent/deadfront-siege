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
var _terrain_blocked: Dictionary = {} ## Vector2i -> true: water / off-island, static per island
var _harvest: Dictionary = {} ## Vector2i -> true: live HarvestNode trunks and boxes
var _build: Dictionary = {} ## Vector2i -> true: BuildGrid cells that block (closed gates do, open ones don't)

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
	return _region.has_point(tile) and not _astar.is_point_solid(tile)

func path(from_world: Vector3, to_world: Vector3, max_len: int = DEFAULT_MAX_LEN) -> PackedVector3Array:
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
	var ids := _astar.get_id_path(from_tile, to_tile, true)
	if ids.is_empty():
		return PackedVector3Array()
	last_reachable = Vector2i(ids[ids.size() - 1]) == to_tile
	var tiles: Array[Vector2i] = []
	for id in ids:
		tiles.append(Vector2i(id))
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
func path_result(from_world: Vector3, to_world: Vector3, max_len: int = DEFAULT_MAX_LEN) -> Dictionary:
	var points := path(from_world, to_world, max_len)
	return {"points": points, "reachable": last_reachable}

func _log_len(length: int) -> void:
	if Game == null:
		return
	if Game.lab_name != "" or Game.debug_overlay:
		print("[path] len=%d%s" % [length, "" if last_reachable else " unreachable"])

func _rebuild() -> void:
	if runtime == null:
		return
	_dirty = false
	_region = _build_region()
	_astar.region = _region
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.jumping_enabled = false
	_astar.update()
	_terrain_blocked.clear()
	_harvest = _harvest_blockers()
	_build = _build_blockers()
	for z in range(_region.position.y, _region.end.y):
		for x in range(_region.position.x, _region.end.x):
			var tile := Vector2i(x, z)
			var pos := BuildGrid.tile_centre(tile, runtime)
			if not runtime.spawn_ok(pos, false):
				_terrain_blocked[tile] = true
				_astar.set_point_solid(tile, true)
				continue
			# Weight is set even under blockers so a released cell keeps its terrain cost.
			_astar.set_point_weight_scale(tile, _weight(pos))
			_astar.set_point_solid(tile, _harvest.has(tile) or _build.has(tile))

func _refresh() -> void:
	_dirty = false
	var harvest := _harvest_blockers()
	var build := _build_blockers()
	var touched := {}
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
	for c in touched:
		_apply(c)

func _apply(tile: Vector2i) -> void:
	if not _region.has_point(tile) or _terrain_blocked.has(tile):
		return
	_astar.set_point_solid(tile, _harvest.has(tile) or _build.has(tile))

func _build_region() -> Rect2i:
	var rad: int = 80
	if runtime.has_method("land_radius"):
		rad = int(ceil(float(runtime.land_radius()))) + REBUILD_MARGIN
	var region := Rect2i(Vector2i(-rad, -rad), Vector2i(rad * 2 + 1, rad * 2 + 1))
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
