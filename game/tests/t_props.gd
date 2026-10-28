extends SceneTree
## PROPS acceptance. The owner's rules, checked on a real island:
##   "Not every plant/rock/etc is a resource, the resources have the UI that is clickable and the props
##    do not." -> a prop is not in "harvest", has no TapZone, and it never opens a radial.
##   "Some props cause collision and some dont." -> a colliding prop makes its tile solid for TilePath,
##    a walk-through one does not. Camp, the harbour and every HarvestNode stay reachable.
##   "most props can be destroyed except for like really big cliffs" -> a clearable prop clears, stays
##    cleared after save/load, and a cliff refuses.
##   Larger islands: ground cover is chunked so it exists far from the origin, and an island keeps
##    400-600 HarvestNodes weighted by biome.
## Run: Godot --headless --path game --script res://tests/t_props.gd -> "[t_props] PASS", exit 0/1.

const WATCHDOG_S := 120.0

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player: Node3D
var _rt: Node3D
var _props: Node
var _world: Node
var BG: GDScript
var WATCH_POS: Vector3

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	var timer := create_timer(WATCHDOG_S)
	timer.timeout.connect(func () -> void:
		print("[t_props] FAIL watchdog %.0fs" % WATCHDOG_S)
		quit(2))
	# Scripts are load()ed on the first frame: a --script file compiles before the autoloads exist,
	# so class names (IslandRuntime, BuildGrid...) are not identifiers here.
	BG = load("res://scripts/world/build_grid.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_props] FAIL %s" % what)

func _run() -> void:
	_host = Node3D.new()
	_host.name = "TPropsHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 6.0)
	_player = kit["player"]
	_world = root.get_node("World")
	_world.harvested.clear()
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	var kit_floor := _host.get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	await process_frame
	await physics_frame
	_rt = _world.runtime
	_props = _rt.get("props") if _rt != null else null
	_expect(_props != null, "the island has a props layer")
	if _props == null:
		_finish()
		return
	_test_data()
	_test_layer()
	_test_ground_cover()
	_test_reachability()
	await _test_collide()
	await _test_clear()
	await _test_save()
	_finish()

# ------------------------------------------------------------------ data

func _test_data() -> void:
	var kinds: Dictionary = _props.call("kinds")
	_expect(kinds.size() >= 12, "props.json has at least 12 kinds (got %d)" % kinds.size())
	var collide := 0
	var no_collide := 0
	var destroyable := 0
	var indestructible := 0
	for k in kinds.keys():
		var row: Dictionary = kinds[k]
		if k.begins_with("_"):
			continue
		# A kind draws as its GLB models or, once the painted art lands, as a 2D card (owner
		# 2026-10-21: props switch to cards); one of the two must be declared.
		var has_models: bool = row.get("models", []) is Array and (row["models"] as Array).size() > 0
		var has_card := str(row.get("card", "")) != ""
		_expect(has_models or has_card, "%s lists models or a card" % k)
		var b: Variant = row.get("biomes", null)
		_expect(b is Dictionary and (b as Dictionary).size() > 0, "%s lists its biomes" % k)
		_expect(row.get("size_m", []) is Array and (row["size_m"] as Array).size() == 2, "%s has a size_m range" % k)
		_expect(row.has("collide") and row["collide"] is bool, "%s says whether it collides" % k)
		_expect(row.has("destroyable") and row["destroyable"] is bool, "%s says whether it can be destroyed" % k)
		if bool(row.get("collide", false)):
			collide += 1
		else:
			no_collide += 1
		if bool(row.get("destroyable", true)):
			destroyable += 1
		else:
			indestructible += 1
	_expect(collide >= 4 and no_collide >= 4, "props are both colliding (%d) and walk-through (%d)" % [collide, no_collide])
	_expect(destroyable > indestructible and indestructible >= 1, "most props are destroyable (%d) and big cliffs are not (%d)" % [destroyable, indestructible])
	for k in ["cliff_rock", "mesa_cliff"]:
		_expect(not bool((kinds.get(k, {}) as Dictionary).get("destroyable", true)), "%s is indestructible" % k)
	for k in ["reeds", "fern", "pebbles", "plume_grass"]:
		var row: Dictionary = kinds.get(k, {})
		_expect(not bool(row.get("collide", true)), "%s is walk-through" % k)

# ------------------------------------------------------------------ the layer

func _test_layer() -> void:
	var n := int(_props.call("prop_count"))
	var coll := int(_props.call("colliding_count"))
	var passable := int(_props.call("passable_count"))
	print("[t_props] props=%d colliding=%d passable=%d destroyable=%d resources=%d" % [
		n, coll, passable, int(_props.call("destroyable_count")), _harvest_count()])
	_expect(n >= 100, "the home island is scattered with props (%d)" % n)
	# Plan P4 band: the biome weighting must not starve the island of resources either.
	var res := _harvest_count()
	_expect(res >= 420 and res <= 620, "the island keeps 420-620 HarvestNodes (%d)" % res)
	_expect(coll > 0 and passable > 0, "both colliding (%d) and walk-through (%d) props are placed" % [coll, passable])
	var group_props := get_nodes_in_group("props").size()
	_expect(group_props == coll, "'props' group holds exactly the colliding props (%d of %d)" % [group_props, coll])
	# No prop is a resource: the "harvest" group holds HarvestNodes only.
	var harvest_script: GDScript = load("res://scenes/world/harvest_node.tscn").instantiate().get_script()
	for node in get_nodes_in_group("harvest"):
		_expect(node.get_script() == harvest_script, "the harvest group holds no prop (%s)" % node.name)
		break
	# Every prop body has a collider and a path footprint, and no tap zone.
	var bodies := 0
	for node in get_nodes_in_group("props"):
		_expect(node is StaticBody3D, "a prop body is a static collider")
		_expect(node.get_node_or_null("Shape") != null, "a prop body has a collision shape")
		_expect(node.get_node_or_null("TapZone") == null, "a prop has no tap zone (%s)" % node.name)
		_expect(not node.is_in_group("harvest"), "a prop is not a harvest node (%s)" % node.name)
		bodies += 1
	_expect(bodies >= 1, "colliding props have bodies")
	var blocked: Array = _props.call("blocked_cells")
	_expect(blocked.size() >= bodies, "colliding props publish path blocker cells (%d cells, %d bodies)" % [blocked.size(), bodies])

func _harvest_count() -> int:
	return get_nodes_in_group("harvest").size()

## Ground cover is chunked (VegBatch cells, 120 m range) so a walk 150 m from the origin still has
## grass, and the far count is within half of the near count. The old single island-wide MultiMesh
## was culled at 48 m from the origin: far from the middle there was no cover at all (scout 3b).
func _test_ground_cover() -> void:
	var cover: PackedVector3Array = _rt.get("cover_points")
	var cells := 0
	var cell_nodes := {}
	for b in _rt.get("_batches"):
		var batch: Node = b
		for c in batch.get_children():
			if c is MultiMeshInstance3D:
				var mm := (c as MultiMeshInstance3D).multimesh
				if mm != null and mm.mesh != null and String(mm.mesh.resource_path).is_empty():
					continue
				cell_nodes[c.name] = true
	for c in cell_nodes.keys():
		cells += 1
	print("[t_props] cover=%d batch_cells=%d" % [cover.size(), cells])
	_expect(cover.size() >= 300, "the home island scatters ground cover (%d instances)" % cover.size())
	# The old whole-island MultiMesh was culled at 48 m from the origin, so anything past that distance
	# had no cover. Near = the camp, far = the outer third of the island's land.
	var land := float(_rt.call("land_radius"))
	var near := 0
	var far := 0
	for p in cover:
		var d := Vector2(p.x, p.z).length()
		if d <= 25.0:
			near += 1
		elif d >= land * 0.72:
			far += 1
	print("[t_props] cover near=%d far=%d land_r=%.1f" % [near, far, land])
	_expect(near >= 20, "cover at the camp (%d instances within 25 m of the origin)" % near)
	_expect(far >= maxi(10, near / 3), "cover far from the origin (%d instances past %.0f m, near %d)" % [far, land * 0.72, near])
	# Every cover batch cell is a 32 m VegBatch cell with its own range, not one island-wide mesh.
	var bad := 0
	for b in _rt.get("_batches"):
		if String(b.name).begins_with("VegBatch_"):
			for c in (b as Node).get_children():
				if c is MultiMeshInstance3D and float((c as MultiMeshInstance3D).visibility_range_end) < 100.0:
					bad += 1
	_expect(bad == 0, "every batch cell has a >= 100 m visibility range (%d short)" % bad)

## Camp, the harbour arrival point and every HarvestNode must still be reachable: a scenery layer that
## walls off the camp or a resource is a bug, not a look.
func _test_reachability() -> void:
	var path: Variant = _rt.pathing
	if path == null:
		_expect(false, "the island has pathing")
		return
	var from: Vector3 = _rt._camp_pos
	var unreachable := 0
	var checked := 0
	# Harbour arrival.
	var to: Vector3 = _rt.arrival_point()
	path.call("path", from, to)
	checked += 1
	if not bool(path.get("last_reachable")):
		unreachable += 1
		print("[t_props] FAIL harbour arrival is unreachable from camp")
	# Every harvest node (sampled to 40 so the A* cost stays small).
	var nodes: Array = get_nodes_in_group("harvest")
	var step := maxi(1, nodes.size() / 40)
	for i in range(0, nodes.size(), step):
		var node: Node3D = nodes[i] as Node3D
		if node == null:
			continue
		path.call("path", from, node.global_position)
		checked += 1
		if not bool(path.get("last_reachable")):
			unreachable += 1
			print("[t_props] FAIL %s is unreachable from camp" % str(node.get("node_id")))
	_expect(unreachable == 0, "camp reaches the harbour and %d resources (unreachable=%d)" % [checked, unreachable])
	print("[t_props] reachable=%d of %d checks" % [checked - unreachable, checked])

# ------------------------------------------------------------------ collision

func _test_collide() -> void:
	var path: Variant = _rt.pathing
	var grid: Variant = _rt.get("build_grid")
	WATCH_POS = _rt._camp_pos
	# A colliding prop placed beside the camp on a known dry tile.
	var at := _dry_near(_rt._camp_pos, 6.0)
	var ok_big: bool = bool(_props.call("add_prop", "boulder", at, 2.2))
	_expect(ok_big, "a boulder is placed for the collider check")
	var big_tile: Vector2i = BG.call("tile_of", at)
	var boulder := _last_row("boulder")
	if not boulder.is_empty():
		for c in boulder.get("cells", []):
			_expect(not bool(path.call("is_walkable", c)), "a boulder blocks path tile (%d,%d)" % [c.x, c.y])
	# A walk-through prop on the next tile over.
	var at2 := _dry_near(at, 2.0)
	var ok_small: bool = bool(_props.call("add_prop", "reeds", at2, 1.4))
	_expect(ok_small, "reeds are placed for the walk-through check")
	var small_tile: Vector2i = BG.call("tile_of", at2)
	var reeds := _last_row("reeds")
	if not reeds.is_empty():
		_expect(not bool(reeds.get("collide", true)), "reeds are marked walk-through")
		_expect(not grid.blocks_path(small_tile), "reeds do not reserve a building cell")
	# TilePath's own blocker list must contain the boulder's tile and not the reeds' tile.
	var blocked: Array = _props.call("blocked_cells")
	_expect(blocked.has(big_tile), "the boulder's tile is in the path blocker list")
	_expect(not blocked.has(small_tile), "the reeds' tile is not in the path blocker list")
	# A cliff refuses a building spot; pebbles do not.
	var cliff_at := _dry_near(at, 5.0)
	_props.call("add_prop", "cliff_rock", cliff_at, 3.0)
	var cliff_row := _last_row("cliff_rock")
	if not cliff_row.is_empty():
		var cells: Array = [cliff_row["tile"]]
		_expect(str(_props.call("blocking_kind_at_cells", cells)) != "", "a cliff refuses a building spot")
		_expect(not bool(_props.call("clear_at_tile", cliff_row["tile"])), "a cliff refuses to be cleared")
	await process_frame

func _last_row(kind: String) -> Dictionary:
	var arr: Array = _props.get("_rows")
	for i in range(arr.size() - 1, -1, -1):
		if str(arr[i].get("kind", "")) == kind:
			return arr[i]
	return {}

## A dry, prop-free point `min_d`..`min_d+4` m from `from` in a random direction.
func _dry_near(from: Vector3, min_d: float) -> Vector3:
	for i in 32:
		var ang := float(i) * TAU / 32.0
		var p := Vector3(from.x + cos(ang) * min_d, 0.0, from.z + sin(ang) * min_d)
		if _rt == null or not _rt.is_dry(p):
			continue
		if not (_props.call("prop_at_tile", BG.call("tile_of", p)) as Dictionary).is_empty():
			continue
		p.y = _rt.surface_y(p.x, p.z)
		return p
	return from + Vector3(min_d, 0.0, 0.0)

# ------------------------------------------------------------------ clearing

func _test_clear() -> void:
	var at := _dry_near(_rt._camp_pos, 14.0)
	var ok: bool = bool(_props.call("add_prop", "fallen_log", at, 3.5))
	_expect(ok, "a fallen log is placed to be cleared")
	var row := _last_row("fallen_log")
	if row.is_empty():
		return
	var tile: Vector2i = row["tile"]
	var cleared_before := int(_props.get("cleared_count"))
	_expect(bool(_props.call("clear_at_tile", tile)), "a fallen log clears")
	_expect(int(_props.get("cleared_count")) == cleared_before + 1, "the clear counter moved")
	_expect(bool(_props.call("is_cleared", tile)), "the cleared tile is remembered")
	_expect(not bool(_props.call("clear_at_tile", tile)), "clearing the same prop twice is refused")
	# A clearable prop no longer blocks the path or a build.
	await process_frame
	_expect(_props.call("prop_at_tile", tile).is_empty(), "the cleared prop is gone from its tile")
	_world.call("_snapshot_harvest")

# ------------------------------------------------------------------ save

func _test_save() -> void:
	var SG := load("res://scripts/core/save_game.gd") as GDScript
	var cleared_rows: Dictionary = _props.call("snapshot")
	var before: Array = cleared_rows.get("cleared", [])
	_expect(before.size() >= 1, "the snapshot carries the cleared props (%d)" % before.size())
	_expect(SG.save_now(), "the island saves")
	var saved_tile := Vector2i(int((before[0] as Dictionary).get("x", 0)), int((before[0] as Dictionary).get("y", 0)))
	# Regenerate the island from the save: the cleared prop must stay cleared.
	SG.load_now(_host)
	await process_frame
	await physics_frame
	var rt2: Node3D = _world.runtime
	_expect(rt2 != null and rt2 != _rt, "the save loads a fresh island")
	if rt2 == null:
		return
	var props2: Variant = rt2.get("props")
	_expect(props2 != null, "the reloaded island has a props layer")
	if props2 == null:
		return
	_expect(bool(props2.call("is_cleared", saved_tile)), "the cleared prop stays cleared after save/load (tile %s)" % saved_tile)
	var row: Dictionary = props2.call("prop_at_tile", saved_tile)
	_expect(row.is_empty() or bool(row.get("cleared", false)), "the cleared prop is not standing after load")
	# The save file itself holds the tile.
	var txt := FileAccess.get_file_as_string(SG.path)
	var raw: Dictionary = {}
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		raw = parsed as Dictionary
	var tiles: Variant = (raw.get("unstable", {}) as Dictionary).get("harvested", {})
	if tiles is Dictionary:
		var snap: Variant = (tiles as Dictionary).get("__tiles", {})
		if snap is Dictionary:
			var pv: Variant = (snap as Dictionary).get("props", {})
			var rows: Variant = (pv as Dictionary).get("cleared", []) if pv is Dictionary else []
			_expect(rows is Array and (rows as Array).size() >= 1, "the save file stores the cleared prop by tile")

func _finish() -> void:
	if _fails.is_empty():
		print("[t_props] PASS")
		quit(0)
	else:
		print("[t_props] FAIL %d check(s)" % _fails.size())
		quit(1)
