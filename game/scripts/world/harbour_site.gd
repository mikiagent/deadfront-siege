class_name HarbourSite
extends RefCounted
## Where a harbour may stand: on the coast, its landward row on land and its dock over water deep
## enough for a boat (rules.json "harbour"). The dock points along the harbour's local -Z (the
## Blender pier's convention), so rot 0/1/2/3 sends it to world -Z/-X/+Z/+X.
## Rows count from the landward end: row 0 is the base, row FOOTPRINT.y - 1 is the dock tip.

const FOOTPRINT := Vector2i(3, 6)
const WATER_Y := -0.05  # IslandTerrain's water plane
const SEAWARD: Array[Vector2] = [Vector2(0, -1), Vector2(-1, 0), Vector2(0, 1), Vector2(1, 0)]
## The coast on 480 m islands lies ~15 m past the land radius, where tap-to-move ends; the 3 m
## strip from the arrival point this far inland is walkable so the survivor can reach the dock.
# ASSUMPTION: 30 m covers the widest gap measured (land radius to waterline ~15-20 m).
const APPROACH_M := 30.0

static func seaward(rot: int) -> Vector2:
	return SEAWARD[posmod(rot, 4)]

static func dims(rot: int) -> Vector2i:
	return FOOTPRINT if posmod(rot, 4) % 2 == 0 else Vector2i(FOOTPRINT.y, FOOTPRINT.x)

static func centre(cell: Vector2i, rot: int) -> Vector2:
	var d := dims(rot)
	return Vector2(float(cell.x) + float(d.x) * 0.5, float(cell.y) + float(d.y) * 0.5)

## World xz of row k's middle cell centre (k = -1 is the strip just behind the base).
static func row_point(cell: Vector2i, rot: int, k: int, column: int = 0) -> Vector2:
	var s := seaward(rot)
	return centre(cell, rot) + s * (float(k) + 0.5 - float(FOOTPRINT.y) * 0.5) + Vector2(s.y, -s.x) * float(column)

static func base_point(cell: Vector2i, rot: int) -> Vector2:
	return row_point(cell, rot, 0)

static func tip_point(cell: Vector2i, rot: int) -> Vector2:
	return row_point(cell, rot, FOOTPRINT.y - 1)

## Where travel lands the survivor: on the sand right behind the base, at the water's edge.
static func arrival_point(cell: Vector2i, rot: int) -> Vector2:
	return row_point(cell, rot, -1)

## True when p lies on the approach strip (ignores height; the runtime adds "not under water").
static func on_approach(cell: Vector2i, rot: int, p: Vector2) -> bool:
	var s := seaward(rot)
	var d := p - arrival_point(cell, rot)
	var inland := -d.dot(s)
	return inland >= -0.5 and inland <= APPROACH_M and absf(d.dot(Vector2(s.y, -s.x))) <= 1.5

## Grid rectangle holding the approach strip (TilePath grows its region to include it).
static func approach_rect(cell: Vector2i, rot: int) -> Rect2i:
	var a := arrival_point(cell, rot)
	var b := a - seaward(rot) * APPROACH_M
	var lo := Vector2i(floori(minf(a.x, b.x)) - 2, floori(minf(a.y, b.y)) - 2)
	var hi := Vector2i(ceili(maxf(a.x, b.x)) + 2, ceili(maxf(a.y, b.y)) + 2)
	return Rect2i(lo, hi - lo)

## "" when the pose is a legal harbour, else a refusal code for BuildPlacer.reason_text().
static func check(rt: IslandRuntime, cell: Vector2i, rot: int) -> String:
	# ASSUMPTION: the PRDs give no draft; a 0.4 m-deep tip, 2 m from the shore, floats a raft.
	var rules: Dictionary = Data.world_rules.get("harbour", {})
	var from_row := int(rules.get("dock_from_row", 2))
	var depth := float(rules.get("boat_depth_m", 0.4))
	for col in [-1, 0, 1]:
		var base := row_point(cell, rot, 0, col)
		var shed_edge := row_point(cell, rot, 1, col)
		if _h(rt, base) < 0.15 or _tile(rt, base) == IslandTerrain.TileType.MUD:
			return "needs_shore"
		if _h(rt, shed_edge) <= WATER_Y or _tile(rt, shed_edge) == IslandTerrain.TileType.MUD:
			return "needs_shore"
	for k in range(from_row, FOOTPRINT.y):
		for col in [-1, 0, 1]:
			if _h(rt, row_point(cell, rot, k, col)) > WATER_Y:
				return "dock_needs_water"
	if _h(rt, tip_point(cell, rot)) > WATER_Y - depth:
		return "dock_needs_water"
	return ""

## The legal coast pose nearest the hint: walk in from the open sea along 360 bearings to the
## first land, point the dock at the nearer grid axis, and nudge the base inland up to 3 m. The
## approach strip must reach dry walkable land, so camp-to-harbour pathing reaches the dock.
## Returns {"cell": Vector2i, "rot": int} or {} when no coast fits (then check() refuses all).
static func find(rt: IslandRuntime, hint: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	var half := rt._size * 0.5 - 1.0
	for i in 360:
		var ang := TAU * float(i) / 360.0
		var dir := Vector2(cos(ang), sin(ang))
		var r := half
		while r > 0.0 and _h(rt, dir * r) <= WATER_Y:
			r -= 0.5
		if r <= 0.0:
			continue
		var rot := rot_toward(dir)
		for back in 4:
			var cell := cell_for_base(dir * r - seaward(rot) * float(back), rot)
			if check(rt, cell, rot) == "":
				if not _reaches_dry(rt, cell, rot):
					break
				var d := hint.distance_to(centre(cell, rot))
				if d < best_d:
					best_d = d
					best = {"cell": cell, "rot": rot}
				break
	return best

static func rot_toward(dir: Vector2) -> int:
	if absf(dir.x) > absf(dir.y):
		return 3 if dir.x > 0.0 else 1
	return 2 if dir.y > 0.0 else 0

## The footprint cell whose base row's middle tile holds this world point.
static func cell_for_base(p: Vector2, rot: int) -> Vector2i:
	var tile_mid := Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5)
	var c := tile_mid + seaward(rot) * (float(FOOTPRINT.y) * 0.5 - 0.5)
	var d := dims(rot)
	return Vector2i(roundi(c.x - float(d.x) * 0.5), roundi(c.y - float(d.y) * 0.5))

static func _reaches_dry(rt: IslandRuntime, cell: Vector2i, rot: int) -> bool:
	var a := arrival_point(cell, rot)
	for t in int(APPROACH_M):
		var p := a - seaward(rot) * float(t)
		if rt.is_dry(Vector3(p.x, 0.0, p.y)):
			return true
	return false

static func _h(rt: IslandRuntime, p: Vector2) -> float:
	return rt.surface_y(p.x, p.y)

static func _tile(rt: IslandRuntime, p: Vector2) -> int:
	return rt._tile_type_at_world(p.x, p.y)
