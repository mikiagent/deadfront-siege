class_name TilePath
extends Node
## 1 m tile A* pathing over island terrain + occupancy.

const DEFAULT_MAX_LEN := 96
const REBUILD_MARGIN := 2

var runtime: Node3D
var _astar := AStarGrid2D.new()
var _region: Rect2i = Rect2i()
var _dirty: bool = true
var _blockers: Dictionary = {} ## "x:y" -> true

func setup(owner_runtime: Node3D) -> void:
	runtime = owner_runtime
	_rebuild()

func mark_dirty() -> void:
	_dirty = true

func path(from_world: Vector3, to_world: Vector3, max_len: int = DEFAULT_MAX_LEN) -> PackedVector3Array:
	if runtime == null:
		return PackedVector3Array()
	if _dirty:
		_rebuild()
	var from_tile := _closest_walkable(BuildGrid.tile_of(from_world))
	var to_tile := _closest_walkable(BuildGrid.tile_of(to_world))
	if from_tile == Vector2i(-2147483648, -2147483648) or to_tile == Vector2i(-2147483648, -2147483648):
		return PackedVector3Array()
	if from_tile == to_tile:
		var single := PackedVector3Array([BuildGrid.tile_centre(to_tile, runtime)])
		_log_len(single.size())
		return single
	var ids := _astar.get_id_path(from_tile, to_tile, true)
	if ids.is_empty():
		return PackedVector3Array()
	var tiles: Array[Vector2i] = []
	for id in ids:
		tiles.append(Vector2i(id))
	if max_len > 0 and tiles.size() > max_len:
		tiles.resize(max_len)
		tiles[tiles.size() - 1] = to_tile
	tiles = _string_pull(tiles)
	var out := PackedVector3Array()
	for tile in tiles:
		out.append(BuildGrid.tile_centre(tile, runtime))
	_log_len(out.size())
	return out

func _log_len(length: int) -> void:
	if Game == null:
		return
	if Game.lab_name != "" or Game.debug_overlay:
		print("[path] len=%d" % length)

func _rebuild() -> void:
	if runtime == null:
		return
	_dirty = false
	_blockers.clear()
	_region = _build_region()
	_astar.region = _region
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.jumping_enabled = false
	_astar.update()
	_collect_blockers()
	for z in range(_region.position.y, _region.end.y):
		for x in range(_region.position.x, _region.end.x):
			var tile := Vector2i(x, z)
			var solid := not _walkable(tile)
			_astar.set_point_solid(tile, solid)
			if not solid:
				_astar.set_point_weight_scale(tile, _weight(tile))

func _build_region() -> Rect2i:
	var rad: int = 80
	if runtime.has_method("land_radius"):
		rad = int(ceil(float(runtime.land_radius()))) + REBUILD_MARGIN
	return Rect2i(Vector2i(-rad, -rad), Vector2i(rad * 2 + 1, rad * 2 + 1))

func _collect_blockers() -> void:
	var grid: Variant = runtime.get("build_grid")
	if grid is BuildGrid:
		for cell in (grid as BuildGrid).occupied_cells():
			_blockers[_key(cell)] = true
		for cell in (grid as BuildGrid).reserved_cells():
			_blockers[_key(cell)] = true
	for n in runtime.get_tree().get_nodes_in_group("harvest"):
		var node := n as HarvestNode
		if node == null:
			continue
		if not node.visible or node.collision_layer == 0:
			continue
		var role := str(Data.nature_families.get(node.family, {}).get("role", ""))
		if role.begins_with("tree") or role == "rock":
			_blockers[_key(BuildGrid.tile_of(node.global_position))] = true

func _walkable(tile: Vector2i) -> bool:
	if not _region.has_point(tile):
		return false
	if _blockers.has(_key(tile)):
		return false
	var pos := BuildGrid.tile_centre(tile, runtime)
	return runtime.spawn_ok(pos, false)

func _weight(tile: Vector2i) -> float:
	var pos := BuildGrid.tile_centre(tile, runtime)
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
	if _walkable(tile):
		return tile
	for ring in range(1, 7):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if abs(x) != ring and abs(y) != ring:
					continue
				var probe := tile + Vector2i(x, y)
				if _walkable(probe):
					return probe
	return Vector2i(-2147483648, -2147483648)

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

func _key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
