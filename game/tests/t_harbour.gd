extends SceneTree
## W1-HARBOUR acceptance: on every island the harbour stands on the coast (base on land at the
## water's edge, dock tip over boat-deep water), the json harbour (where travel lands you) is the
## dock's arrival point, camp-to-harbour pathing reaches it, inland poses are refused (layout move
## and old saves), and the dock is a prop composite, not a box.
## Run: Godot --headless --path game --script res://tests/t_harbour.gd
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const TILE_SHALLOW := 4
const TILE_DEEP := 8

var _fails: PackedStringArray = []
var _started := false
var _HS: GDScript
var _BG: GDScript
var _host: Node3D
var _world: Node

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_harbour] FAIL %s" % what)

func _run() -> void:
	_HS = load("res://scripts/world/harbour_site.gd")
	_BG = load("res://scripts/world/build_grid.gd")
	_host = Node3D.new()
	_host.name = "THarbourHost"
	root.add_child(_host)
	_world = root.get_node("World")
	var ids: Array = _world.islands.keys()
	ids.sort()
	_expect(ids.size() >= 15, "island catalogue loaded (%d)" % ids.size())
	for id in ids:
		_world.load_island(_host, StringName(str(id)), Vector3(0, 1, 0), false)
		await process_frame
		_check_island(str(id))
	await _test_refusals()
	await _test_old_save_snaps_to_coast()
	await _test_moved_harbour_follows()
	if _fails.is_empty():
		print("[t_harbour] PASS islands=%d" % ids.size())
		quit(0)
	else:
		print("[t_harbour] FAIL count=%d" % _fails.size())
		quit(1)

func _check_island(id: String) -> void:
	var rt = _world.runtime
	var h: Node3D = rt.harbour
	var cell: Vector2i = h.build_cell
	var rot: int = h.build_rot
	var why: String = _HS.check(rt, cell, rot)
	_expect(why == "", "%s harbour pose is legal (%s)" % [id, why])
	var depth := float(root.get_node("Data").world_rules.get("harbour", {}).get("boat_depth_m", 0.4))
	var tip: Vector2 = _HS.tip_point(cell, rot)
	var tip_h: float = rt.surface_y(tip.x, tip.y)
	var tip_type: int = rt._tile_type_at_world(tip.x, tip.y)
	_expect(tip_type == TILE_SHALLOW or tip_type == TILE_DEEP, "%s dock tip cell is water (tile %d)" % [id, tip_type])
	_expect(tip_h <= _HS.WATER_Y - depth, "%s dock tip is boat-deep (%.2f m)" % [id, tip_h])
	var base: Vector2 = _HS.base_point(cell, rot)
	var base_v := Vector3(base.x, 0.0, base.y)
	_expect(rt.surface_y(base.x, base.y) > _HS.WATER_Y, "%s harbour base cell is land" % id)
	var base_shore := _water_dist(rt, base_v)
	_expect(base_shore <= 2.0, "%s harbour base within 2 m of the shoreline (%.2f)" % [id, base_shore])
	var to_water := _water_dist(rt, rt._harbour_pos)
	_expect(to_water <= 3.0, "%s harbour_to_water_m=%.2f <= 3" % [id, to_water])
	var arrive: Vector3 = rt.arrival_point()
	var edge: Vector2 = _HS.arrival_point(cell, rot)
	_expect(_water_dist(rt, Vector3(edge.x, 0.0, edge.y)) <= 3.0, "%s the strip behind the dock base is at the water's edge" % id)
	# LEGSFIX: she lands IslandRuntime.LANDING_ROW rows behind the base, clear of the shed roof's sight line, on the approach strip.
	_expect(arrive.y > _HS.WATER_Y and rt.on_harbour_approach(arrive), "%s arrival point is dry ground on the dock's approach" % id)
	var j: Array = _world.def_of(StringName(id)).get("harbour", [])
	var jd := INF if j.size() < 3 else Vector2(float(j[0]) - arrive.x, float(j[2]) - arrive.z).length()
	_expect(jd <= 1.0, "%s json harbour is the dock's arrival point: want [%.1f, 0, %.1f], have %s" % [id, arrive.x, arrive.z, j])
	var pts: PackedVector3Array = rt.pathing.path(rt._camp_pos, arrive, 0)
	var reachable: bool = rt.pathing.last_reachable and not pts.is_empty()
	_expect(reachable, "%s camp-to-harbour path reachable" % id)
	var arrive_tile := Vector2i(floori(arrive.x), floori(arrive.z))
	_expect(rt.pathing.is_walkable(arrive_tile), "%s survivor can tap-move from the arrival tile" % id)
	var meshes := _meshes(h.get_node_or_null("Visual"))
	var boxes := 0
	for m in meshes:
		if (m as MeshInstance3D).mesh is BoxMesh:
			boxes += 1
	_expect(meshes.size() >= 20 and boxes == 0, "%s harbour is a prop composite (%d meshes, %d boxes)" % [id, meshes.size(), boxes])
	var near := INF
	for c in _host.get_tree().get_nodes_in_group("creatures"):
		if c is Node3D:
			near = minf(near, (c as Node3D).global_position.distance_to(arrive))
	print("[t_harbour] %s cell=%s rot=%d harbour_to_water_m=%.2f base_to_shore_m=%.2f tip_depth_m=%.2f arrival=[%.1f, 0, %.1f] camp_to_harbour_m=%.0f reachable=%s nearest_creature_m=%.0f" % [
		id, cell, rot, to_water, base_shore, _HS.WATER_Y - tip_h, arrive.x, arrive.z,
		rt._camp_pos.distance_to(arrive), reachable, near])

## Placing (or layout-moving) a harbour inland or with the dock pointing at land is refused.
func _test_refusals() -> void:
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 0), false)
	await process_frame
	var rt = _world.runtime
	var grid = rt.build_grid
	grid.ignore_distance = true
	var h: Node3D = rt.harbour
	var inland := Vector2i(-1, 15)  # the old fixed pose, 18 m from the island centre
	var code: String = grid.can_place(&"harbour", inland, 0)
	_expect(code == "dock_needs_water", "inland harbour refused (got '%s')" % code)
	print("[t_harbour] inland placement code=%s" % code)
	grid.release(h)
	var here: String = grid.can_place(&"harbour", h.build_cell, h.build_rot)
	_expect(here == "", "coast pose accepted by BuildGrid (got '%s')" % here)
	var backwards: String = grid.can_place(&"harbour", h.build_cell, h.build_rot + 2)
	_expect(backwards != "", "dock pointing inland refused (got '%s')" % backwards)
	grid.occupy(h, grid.cells_for(&"harbour", h.build_cell, h.build_rot))

## A save from before the coast rule holds an inland harbour pose; loading it snaps to the coast.
func _test_old_save_snaps_to_coast() -> void:
	_world.camp_layout["Harbour"] = {"cell": [-1, 15], "rot": 0}
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 0), false)
	await process_frame
	var h: Node3D = _world.runtime.harbour
	_expect(h.build_cell != Vector2i(-1, 15) and _HS.check(_world.runtime, h.build_cell, h.build_rot) == "", "old inland save pose snaps back to the coast (%s)" % h.build_cell)
	_world.camp_layout.erase("Harbour")

## A moved home harbour remains the source of travel, basket placement and walkable deck state.
func _test_moved_harbour_follows() -> void:
	# The hint rule (not the southern-most one the island itself uses): a pose the player moved to.
	var site: Dictionary = _HS.find(_world.runtime, Vector2(61.0, -7.0), false)
	_expect(not site.is_empty(), "found a legal moved harbour pose")
	if site.is_empty():
		return
	var moved_cell: Vector2i = site["cell"]
	var moved_rot: int = int(site["rot"])
	var fixed: Array = _world.def_of(&"home_grassland").get("harbour", []).duplicate()
	_world.camp_layout["Harbour"] = {"cell": [moved_cell.x, moved_cell.y], "rot": moved_rot}
	_world.load_island(_host, &"home_grassland", Vector3.ZERO, false)
	await process_frame
	var rt = _world.runtime
	var h: Node3D = rt.harbour
	if h == null or rt.cargo_basket == null:
		_expect(false, "moved harbour runtime rebuilt")
		_world.camp_layout.erase("Harbour")
		return
	var arrival: Vector3 = rt.arrival_point()
	var fixed_pos := Vector3(float(fixed[0]), 0.0, float(fixed[2]))
	_expect(h.build_cell == moved_cell and h.build_rot == moved_rot, "moved harbour pose survives reload")
	_expect(arrival.distance_to(fixed_pos) > 50.0, "moved harbour repro is away from the old json point")
	_expect(Vector2(float(_world.camp_layout["Harbour"]["cell"][0]), float(_world.camp_layout["Harbour"]["cell"][1])) == Vector2(moved_cell.x, moved_cell.y), "moved harbour pose is persisted")
	var basket_pos: Vector3 = rt.cargo_basket.global_position
	_expect(basket_pos.distance_to(rt._dry_beside_harbour()) < 0.1, "cargo basket follows moved harbour")
	_expect(rt.build_grid.reserved_cells().has(_BG.tile_of(basket_pos)), "cargo basket re-reserves its moved cell")
	var shapes := []
	for child in h.get_children():
		if child is CollisionShape3D:
			shapes.append(child)
	_expect(shapes.size() >= 2, "harbour uses separate deck and shed colliders")
	var why: String = _HS.check(rt, h.build_cell, h.build_rot)
	_expect(why == "", "moved harbour pose remains legal (%s)" % why)
	_world.camp_layout.erase("Harbour")

## Metres from p to the nearest point at or below the water line (0 when p is over water).
func _water_dist(rt: Node, p: Vector3) -> float:
	var best := INF
	for iz in range(-16, 17):
		for ix in range(-16, 17):
			var q := Vector2(p.x + float(ix) * 0.25, p.z + float(iz) * 0.25)
			if rt.surface_y(q.x, q.y) <= _HS.WATER_Y:
				best = minf(best, q.distance_to(Vector2(p.x, p.z)))
	return best

func _meshes(n: Node) -> Array:
	var out: Array = []
	if n == null:
		return out
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
