class_name BuildGrid
extends Node
## 1 m placement grid and occupancy map for world building.

const CELL_SIZE := 1.0
const MAX_PLACE_DISTANCE := 8.0
const MAX_SLOPE_SPREAD := 0.6

var runtime: Node3D
var _actor: Node3D
var ignore_distance: bool = false  # layout mode: move buildings anywhere on the claim
var _occupied: Dictionary = {} ## Vector2i -> Node
var _node_cells: Dictionary = {} ## instance id -> Array[Vector2i]
var _reserved: Dictionary = {} ## Vector2i -> StringName

static func tile_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.z / CELL_SIZE))

static func tile_centre(tile: Vector2i, owner_runtime: Node) -> Vector3:
	var x := (float(tile.x) + 0.5) * CELL_SIZE
	var z := (float(tile.y) + 0.5) * CELL_SIZE
	var y := 0.0
	if owner_runtime and owner_runtime.has_method("surface_y"):
		y = owner_runtime.surface_y(x, z)
	return Vector3(x, y, z)

func setup(owner_runtime: Node3D) -> void:
	runtime = owner_runtime
	_actor = null
	_occupied.clear()
	_node_cells.clear()
	_reserved.clear()
	_mark_pathing_dirty()

func set_actor(actor: Node3D) -> void:
	_actor = actor

func clear_actor(actor: Node3D) -> void:
	if _actor == actor:
		_actor = null

func clear_occupancy() -> void:
	_occupied.clear()
	_node_cells.clear()
	_mark_pathing_dirty()

func reserve_kind(kind: StringName, cell: Vector2i, rot: int = 0) -> void:
	reserve_cells(cells_for(kind, cell, rot), kind)

func reserve_cells(cells: Array[Vector2i], tag: StringName = &"reserved") -> void:
	for c in cells:
		_reserved[c] = tag
	_mark_pathing_dirty()

func cells_for(kind: StringName, cell: Vector2i, rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dims := _footprint_rotated(kind, rot)
	for dz in dims.y:
		for dx in dims.x:
			out.append(cell + Vector2i(dx, dz))
	return out

func can_place(kind: StringName, cell: Vector2i, rot: int) -> String:
	var cells := cells_for(kind, cell, rot)
	if _too_far(kind, cell, rot):
		return "too_far"
	for c in cells:
		if _reserved.has(c):
			return "reserved"
	for c in cells:
		if _occupied.has(c):
			return "overlap"
	if runtime and runtime.has_method("is_claimed"):
		for c in cells:
			if not runtime.is_claimed(c):
				return "unclaimed"
	for c in cells:
		var at := tile_centre(c, runtime)
		if runtime and runtime.has_method("spawn_ok") and not runtime.spawn_ok(at, false):
			return "water"
	if not _slope_ok(kind, cell, rot):
		return "slope"
	return ""

func occupy(node: Node, cells: Array[Vector2i]) -> void:
	release(node)
	var key := node.get_instance_id()
	_node_cells[key] = cells.duplicate()
	for c in cells:
		_occupied[c] = node
	_mark_pathing_dirty()

func release(node: Node) -> void:
	if node == null:
		return
	var key := node.get_instance_id()
	if not _node_cells.has(key):
		return
	var cells: Array = _node_cells[key]
	for c in cells:
		if c is Vector2i and _occupied.get(c, null) == node:
			_occupied.erase(c)
	_node_cells.erase(key)
	_mark_pathing_dirty()

func occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in _occupied.keys():
		if c is Vector2i:
			out.append(c)
	return out

func reserved_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in _reserved.keys():
		if c is Vector2i:
			out.append(c)
	return out

func neighbours(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i.LEFT,
		cell + Vector2i.RIGHT,
		cell + Vector2i.UP,
		cell + Vector2i.DOWN,
	]

func placement_transform(kind: StringName, cell: Vector2i, rot: int) -> Transform3D:
	var dims := _footprint_rotated(kind, rot)
	var x := (float(cell.x) + float(dims.x) * 0.5) * CELL_SIZE
	var z := (float(cell.y) + float(dims.y) * 0.5) * CELL_SIZE
	var y := _mean_corner_height(kind, cell, rot)
	var basis := Basis(Vector3.UP, deg_to_rad(float(_rot_step(rot)) * 90.0))
	return Transform3D(basis, Vector3(x, y, z))

func footprint(kind: StringName) -> Vector2i:
	var row := _building_row(kind)
	var fp: Variant = row.get("footprint", [1, 1])
	if fp is Array and fp.size() >= 2:
		return Vector2i(maxi(1, int(fp[0])), maxi(1, int(fp[1])))
	return Vector2i.ONE

func suggested_fence_rot(kind: StringName, cell: Vector2i, rot: int) -> int:
	if kind != &"fence" and kind != &"gate":
		return _rot_step(rot)
	var cells := cells_for(kind, cell, rot)
	var own := {}
	for c in cells:
		own[c] = true
	var horizontal := 0
	var vertical := 0
	for c in cells:
		for n in neighbours(c):
			if own.has(n):
				continue
			var occ: Object = _occupied.get(n, null)
			if occ == null:
				continue
			var occ_kind := _kind_of(occ as Node)
			if occ_kind != &"fence" and occ_kind != &"gate":
				continue
			var d := n - c
			if abs(d.x) == 1 and d.y == 0:
				horizontal += 1
			elif abs(d.y) == 1 and d.x == 0:
				vertical += 1
	if horizontal == 0 and vertical == 0:
		return _rot_step(rot)
	return 0 if horizontal >= vertical else 1

func _too_far(kind: StringName, cell: Vector2i, rot: int) -> bool:
	if ignore_distance:
		return false
	var actor := _actor
	if actor == null:
		var player := get_tree().get_first_node_in_group("player")
		if player is Node3D:
			actor = player as Node3D
	if actor == null:
		return false
	var t := placement_transform(kind, cell, rot)
	return actor.global_position.distance_to(t.origin) > MAX_PLACE_DISTANCE

func _slope_ok(kind: StringName, cell: Vector2i, rot: int) -> bool:
	var spread := _corner_spread(kind, cell, rot)
	return spread <= MAX_SLOPE_SPREAD

func _corner_spread(kind: StringName, cell: Vector2i, rot: int) -> float:
	if runtime == null or not runtime.has_method("surface_y"):
		return 0.0
	var dims := _footprint_rotated(kind, rot)
	var x0 := float(cell.x) * CELL_SIZE
	var z0 := float(cell.y) * CELL_SIZE
	var x1 := x0 + float(dims.x) * CELL_SIZE
	var z1 := z0 + float(dims.y) * CELL_SIZE
	var ys := PackedFloat32Array([
		runtime.surface_y(x0, z0),
		runtime.surface_y(x1, z0),
		runtime.surface_y(x0, z1),
		runtime.surface_y(x1, z1),
	])
	var lo := ys[0]
	var hi := ys[0]
	for y in ys:
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo

func _mean_corner_height(kind: StringName, cell: Vector2i, rot: int) -> float:
	if runtime == null or not runtime.has_method("surface_y"):
		return 0.0
	var dims := _footprint_rotated(kind, rot)
	var x0 := float(cell.x) * CELL_SIZE
	var z0 := float(cell.y) * CELL_SIZE
	var x1 := x0 + float(dims.x) * CELL_SIZE
	var z1 := z0 + float(dims.y) * CELL_SIZE
	return (
		runtime.surface_y(x0, z0)
		+ runtime.surface_y(x1, z0)
		+ runtime.surface_y(x0, z1)
		+ runtime.surface_y(x1, z1)
	) * 0.25

func _rot_step(rot: int) -> int:
	return posmod(rot, 4)

func _footprint_rotated(kind: StringName, rot: int) -> Vector2i:
	var dims := footprint(kind)
	if _rot_step(rot) % 2 == 0:
		return dims
	return Vector2i(dims.y, dims.x)

func _building_row(kind: StringName) -> Dictionary:
	var key := str(kind)
	if key == "gate":
		key = "fence_gate"
	elif key == "makeshift_taming_pen":
		key = "taming_pen"
	var buildings: Dictionary = Data.props_manifest.get("buildings", {})
	var row: Variant = buildings.get(key, {})
	if row is Dictionary:
		return row as Dictionary
	return {}

func _kind_of(node: Node) -> StringName:
	if node == null:
		return &""
	if node.has_method("get"):
		var k: Variant = node.get("kind")
		if str(k) != "":
			return StringName(str(k))
		var sid: Variant = node.get("station_id")
		if str(sid) != "":
			return StringName(str(sid))
	return &""

func _mark_pathing_dirty() -> void:
	if runtime and runtime.has_method("mark_pathing_dirty"):
		runtime.mark_pathing_dirty()
