extends Node3D
## Headless perf probe for layout-mode building drags (build_placer).
## Simulates a finger drag moving the ghost across the island and records frame times,
## then micro-benchmarks the overlay rebuild and pointer raycast directly.

var _player: Player
var _cam: IsoCamera
var _frames: Array[int] = []
var _last_tick: int = 0
var _drag_left: int = 0
var _drag_origin: Vector3 = Vector3.ZERO
var _phase: StringName = &"boot"
var _rebuilds_before: int = 0

func _ready() -> void:
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 12), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	_cam._target = _player
	_cam.size = 26.0
	_cam.distance = 22.0
	_cam._snap()
	print("[boot] lab=layout_perf_lab")
	if DisplayServer.get_name() == "headless":
		call_deferred("_run")

func _process(_delta: float) -> void:
	if _phase != &"drag":
		return
	var now := Time.get_ticks_usec()
	if _last_tick > 0:
		_frames.append(now - _last_tick)
	_last_tick = now
	# Move the pointer target ~0.35 m per frame so the ghost crosses a cell border most frames.
	_drag_left -= 1
	var step := float(_drag_left)
	var target := _drag_origin + Vector3(step * 0.35, 0.0, sin(step * 0.11) * 3.0)
	Game.pointer = _cam.unproject_position(target)
	if _drag_left <= 0:
		_phase = &"bench"
		call_deferred("_bench")

func _run() -> void:
	# Find a buildable anchor, place a tent, then drag it in layout mode.
	var grid: BuildGrid = World.runtime.build_grid
	var anchor := Vector2i.ZERO
	var found := false
	for dz in range(-12, 13):
		for dx in range(-12, 13):
			var c := Vector2i(dx, dz)
			if grid.can_place(&"tent", c, 0) == "":
				anchor = c
				found = true
				break
		if found:
			break
	if not found:
		print("[perf] FAIL no anchor")
		get_tree().quit(1)
		return
	_player.global_position = BuildGrid.tile_centre(anchor + Vector2i(3, 3), World.runtime) + Vector3(0.0, 1.0, 0.0)
	LabKit.give(_player, &"tent_kit", 1)
	_player.placer.begin(&"tent")
	_player.placer.cell = anchor
	_player.placer.rot_step = 0
	if not _player.placer.confirm(_player):
		print("[perf] FAIL place tent")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var tent: Node3D = null
	for n in get_tree().get_nodes_in_group("placed_building"):
		if BuildPlacer.kind_of_building(n) == &"tent":
			tent = n as Node3D
			break
	if tent == null:
		print("[perf] FAIL tent node")
		get_tree().quit(1)
		return
	_player.placer.begin_layout()
	if not _player.placer.pick_up(tent):
		print("[perf] FAIL pick_up")
		get_tree().quit(1)
		return
	# Drag: 240 frames moving away from the anchor across fresh cells.
	_drag_origin = tent.global_position
	_drag_left = 240
	_last_tick = 0
	_phase = &"drag"
	print("[perf] drag start cell=%s" % str(_player.placer.cell))

func _bench() -> void:
	var p := _player.placer
	_frames.sort()
	var n := _frames.size()
	var avg := 0.0
	for f in _frames:
		avg += float(f)
	avg /= maxf(1.0, float(n))
	var p95 := _frames[int(float(n) * 0.95)] if n > 0 else 0
	var worst := _frames[n - 1] if n > 0 else 0
	print("[perf] drag frames=%d avg=%.0fus p95=%dus worst=%dus end_cell=%s" % [n, avg, p95, worst, str(p.cell)])
	# Micro: forced overlay rebuilds (cell nudge forces the _last_sync miss path).
	var t0 := Time.get_ticks_usec()
	var base := p.cell
	for i in range(200):
		p.cell = base + Vector2i(i % 5, int(i / 5) % 5)
		p._sync_grid_state()
	var rebuild_us := float(Time.get_ticks_usec() - t0) / 200.0
	print("[perf] sync_rebuild avg=%.0fus" % rebuild_us)
	# Micro: overlay draw alone.
	var grid2: BuildGrid = World.runtime.build_grid
	t0 = Time.get_ticks_usec()
	for i in range(200):
		p._draw_overlay(grid2)
	print("[perf] draw_overlay avg=%.0fus" % (float(Time.get_ticks_usec() - t0) / 200.0))
	# Micro: lines-only ImmediateMesh rebuild (copy of overlay line loop).
	var gm: StandardMaterial3D = p.get("_grid_mat")
	t0 = Time.get_ticks_usec()
	for i in range(200):
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_LINES, gm)
		var center: Vector3 = grid2.placement_transform(p.placing, p.cell, p.rot_step).origin
		var sx := floorf(center.x) - 4.0 + 0.5
		var sz := floorf(center.z) - 4.0 + 0.5
		for row in range(0, 10):
			var z := sz + float(row) - 0.5
			for step2 in range(0, 9):
				var x0: float = sx + float(step2) - 0.5
				im.surface_add_vertex(Vector3(x0, p._surface_y(x0, z) + 0.06, z))
				im.surface_add_vertex(Vector3(x0 + 1.0, p._surface_y(x0 + 1.0, z) + 0.06, z))
		im.surface_end()
	print("[perf] lines_only avg=%.0fus" % (float(Time.get_ticks_usec() - t0) / 200.0))
	# Count blocked tiles around the current cell (node churn volume).
	var occ := grid2.occupied_cells()
	var rsv := grid2.reserved_cells()
	var ctr: Vector3 = grid2.placement_transform(p.placing, p.cell, p.rot_step).origin
	var blocked := 0
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			var t := Vector2i(int(floorf(ctr.x)) + dx, int(floorf(ctr.z)) + dz)
			var wp := BuildGrid.tile_centre(t, World.runtime)
			if occ.has(t) or rsv.has(t) or not World.runtime.spawn_ok(wp, false):
				blocked += 1
	print("[perf] blocked_tiles_nearby=%d occupied_total=%d" % [blocked, occ.size()])
	# Micro: node churn only - create+free 40 quad nodes like the overlay does.
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.9, 0.9)
	var host := Node3D.new()
	add_child(host)
	t0 = Time.get_ticks_usec()
	for i in range(200):
		for c in host.get_children():
			c.queue_free()
		for j in range(40):
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			host.add_child(mi)
			mi.global_position = Vector3(j, 0, 0)
	print("[perf] node_churn40 avg=%.0fus" % (float(Time.get_ticks_usec() - t0) / 200.0))
	# Micro: label update alone.
	t0 = Time.get_ticks_usec()
	for i in range(200):
		p._update_label(grid2)
	print("[perf] update_label avg=%.0fus" % (float(Time.get_ticks_usec() - t0) / 200.0))
	# Micro: can_place + placement_transform.
	t0 = Time.get_ticks_usec()
	for i in range(200):
		grid2.can_place(&"tent", p.cell, 0)
		grid2.placement_transform(&"tent", p.cell, 0)
	print("[perf] can_place+xf avg=%.0fus" % (float(Time.get_ticks_usec() - t0) / 200.0))
	# Micro: no-op sync (same cell).
	t0 = Time.get_ticks_usec()
	for i in range(200):
		p._sync_grid_state()
	print("[perf] sync_noop avg=%.0fus" % (float(Time.get_ticks_usec() - t0) / 200.0))
	# Micro: pointer ground raycast.
	t0 = Time.get_ticks_usec()
	for i in range(200):
		p._ground()
	var ray_us := float(Time.get_ticks_usec() - t0) / 200.0
	print("[perf] ground_ray avg=%.0fus" % ray_us)
	# Micro: ghost material re-apply.
	t0 = Time.get_ticks_usec()
	for i in range(200):
		p._apply_ghost_material(p.get("_ghost_visual"), p.get("_mat_valid"))
	var mat_us := float(Time.get_ticks_usec() - t0) / 200.0
	print("[perf] ghost_mat avg=%.0fus" % mat_us)
	_functional_checks()

func _functional_checks() -> void:
	var p := _player.placer
	var grid: BuildGrid = World.runtime.build_grid
	var fails: Array[String] = []
	# Overlay meshes: grid lines are one ArrayMesh surface of 440 verts; cell quads carry
	# vertex colours, blue for the footprint when valid, red for blocked tiles.
	p.cell = p.cell  # keep
	p._sync_grid_state()
	var lines_mesh: ArrayMesh = p.get("_ghost_grid").mesh
	if lines_mesh == null or lines_mesh.get_surface_count() != 1:
		fails.append("grid mesh missing")
	else:
		var lv: PackedVector3Array = lines_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if lv.size() != 360:
			fails.append("grid verts=%d != 360" % lv.size())
	var cells_mesh: ArrayMesh = p.get("_ghost_cells").mesh
	if cells_mesh == null or cells_mesh.get_surface_count() != 1:
		fails.append("cells mesh missing")
	else:
		var qc: PackedColorArray = cells_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var qv: PackedVector3Array = cells_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if qv.size() != qc.size() or qv.size() % 6 != 0 or qv.is_empty():
			fails.append("quad arrays bad: v=%d c=%d" % [qv.size(), qc.size()])
		var has_blue := false
		for col in qc:
			if col.b > 0.4 and col.b > col.r:
				has_blue = true
				break
		if p.valid and not has_blue:
			fails.append("no blue footprint quads while valid")
	# Red blocked quads show when hovering blocked tiles: find an occupied cell's neighbour.
	var occ: Array = grid.occupied_cells()
	if not occ.is_empty():
		var probe: Vector2i = occ[0] + Vector2i(3, 0)
		# place ghost so its window contains the occupied tile but footprint does not cover it
		p.cell = probe
		p._sync_grid_state()
		var cm: ArrayMesh = p.get("_ghost_cells").mesh
		var cols: PackedColorArray = cm.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var has_red := false
		for col in cols:
			if col.r > 0.8 and col.g < 0.4:
				has_red = true
				break
		if not has_red:
			fails.append("no red blocked quads near occupied tile")
	# End-to-end move: drag the held tent to a new valid cell and drop it.
	var tent: Node3D = p.moving
	var from_cell: Vector2i = p.get("_moving_cell")
	var target := Vector2i(-999, -999)
	for dz in range(-14, 15):
		for dx in range(-14, 15):
			var c := Vector2i(dx, dz)
			if grid.can_place(&"tent", c, 0) == "" and c != from_cell:
				target = c
				break
		if target.x != -999:
			break
	if target.x == -999:
		fails.append("no move target")
	else:
		p.cell = target
		p.dragging = false
		p.drag_end(_player)
		if p.moving != null:
			fails.append("tent still held after drop")
		elif tent.get("build_cell") != target:
			fails.append("tent build_cell=%s != %s" % [str(tent.get("build_cell")), str(target)])
		else:
			var dims := grid.footprint(&"tent")
			var tc := BuildGrid.tile_of(tent.global_position)
			if tc != target + Vector2i(int(dims.x / 2), int(dims.y / 2)):
				fails.append("tent pos tile=%s != %s" % [str(tc), str(target)])
	# Pick up again and put back with X: returns to the cell it was picked from.
	if fails.is_empty() and p.begin_layout != null:
		if not p.pick_up(tent):
			fails.append("re-pick failed")
		else:
			p.put_back()
			if tent.get("build_cell") != target:
				fails.append("put_back moved tent: %s" % str(tent.get("build_cell")))
	p.end_layout()
	if fails.is_empty():
		print("[perf] functional PASS")
	else:
		for f in fails:
			print("[perf] functional FAIL: %s" % f)
	get_tree().quit(0 if fails.is_empty() else 1)
