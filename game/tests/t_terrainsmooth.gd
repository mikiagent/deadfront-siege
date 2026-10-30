extends SceneTree
## TERRAINSMOOTH: the ground is drawn from the data grid refined 2x (IslandTerrain._refine) and zone
## colours blend across borders. Builds the home island and savannah_15 through World.load_island and
## checks, per island:
##   step      on the rendered surface sampled every 0.5 m, the largest rise between neighbours away
##             from cliff faces (CLIFF tiles grown by 3 m) and river gorge walls stays under STEP_MAX (a slope of 1.2, the
##             CLIFF threshold), and the facet crease angles (between neighbouring triangles) on dry
##             land are well under the old mesh's (the data grid drawn directly): mean and p99
##   surface   surface_y equals the drawn mesh (the chunk's triangles, read back from the ArrayMesh)
##             and the collision heightmap within SURF_TOL at random points
##   unchanged the tile map and walk mask are the data grid's (same as before the refinement, so
##             TilePath and spawns are untouched), and build-slope verdicts (workbench) agree with
##             the old bilinear surface on >= AGREE_MIN of land cells
##   beaches   sandy stretches cover BEACH_MIN..BEACH_MAX of the coast's bearings (data share per
##             climate minus steep shores, river mouths and the camp), within 0.15 of the data
##             share, and no SAND tile touches a cliff
## Windowed (no --headless) it also renders the home island's forest/meadow border top-down with the
## scatter hidden and checks the colour profile across it: the 10-90 % transition is at least
## BLEND_MIN_M wide and no 0.5 m step carries more than STEP_SHARE of the change.
## Run: Godot --headless --path game --script res://tests/t_terrainsmooth.gd -> "[t_terrainsmooth] PASS"

const STEP_MAX := 0.6
const SURF_TOL := 0.01
const AGREE_MIN := 0.985
const BLEND_MIN_M := 3.0
const STEP_SHARE := 0.25
const ISLANDS := [&"home_grassland", &"savannah_15", &"tropical_25", &"tundra_30"]
## Sandy beaches: share of coast bearings with sand (above the waterline band) 1-12 m inland.
const BEACH_MIN := 0.3
## ISLANDSHAPES: 0.65 -> 0.70. A shaped coast (an atoll's ring, a jagged lobe) puts more of its bearings
## on a gentle shore, so a 0.6 climate (tropical) lands a little over 0.65; the data-share check below
## (within 0.15) still holds every island to its climate's figure.
const BEACH_MAX := 0.70

var _fails: PackedStringArray = []
var _started := false
var _world: Node
var _host: Node3D

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	get_root().get_tree().create_timer(400.0).timeout.connect(func() -> void:
		print("[t_terrainsmooth] FAIL watchdog")
		quit(1))
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_terrainsmooth] FAIL %s" % what)

func _run() -> void:
	_world = root.get_node("World")
	_host = Node3D.new()
	root.add_child(_host)
	(load("res://scripts/world/world_lighting.gd") as GDScript).install(_host, "temperate")
	var windowed := DisplayServer.get_name() != "headless"
	for id in ISLANDS:
		_world.call("load_island", _host, id, Vector3(0, 1, 0), false)
		for i in 3:
			await process_frame
		await physics_frame
		var rt: Node = _world.get("runtime")
		_check_steps(id, rt)
		_check_surface(id, rt)
		_check_unchanged(id, rt)
		_check_beaches(id, rt)
		if windowed and id == &"home_grassland":
			await _check_blend(rt)
		_world.call("_clear_runtime")
		await process_frame
	if not windowed:
		print("[t_terrainsmooth] note zone-border colour profile needs a window (run without --headless)")
	if _fails.is_empty():
		print("[t_terrainsmooth] PASS")
		quit(0)
	else:
		print("[t_terrainsmooth] FAIL count=%d" % _fails.size())
		quit(1)

## True near a cliff face: CLIFF tiles grown by 3 m (the risers are designed steps).
func _near_cliff(rt: Node, x: float, z: float) -> bool:
	var span: int = rt._tile_span
	var half: float = rt._size * 0.5
	var tx := int(floor(x + half))
	var tz := int(floor(z + half))
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var ax := clampi(tx + dx, 0, span - 1)
			var az := clampi(tz + dz, 0, span - 1)
			if int(rt.tile_types[ax + az * span]) == 11:
				return true
	return false

func _check_steps(id: StringName, rt: Node) -> void:
	_expect(rt._surf_res == 2 * (rt._res - 1) + 1, "%s refined grid is 2x the data grid" % id)
	var half: float = rt._size * 0.5 - 1.0
	var d := 0.5
	var worst := 0.0
	var worst_at := Vector2.ZERO
	var n := 0
	var z := -half
	while z < half:
		var x := -half
		while x < half:
			var h0: float = rt.surface_y(x, z)
			# Cliff faces and the river's gorge walls (the channel cut, ~2.2 half-widths) are designed steps.
			if h0 > 0.3 and not _near_cliff(rt, x, z) and rt.river_dist_at(x, z) > rt._shape.river_half_width(x, z) * 2.2 + 3.0:
				var hx: float = rt.surface_y(x + d, z)
				var hz: float = rt.surface_y(x, z + d)
				var s := maxf(absf(hx - h0), absf(hz - h0))
				if s > worst:
					worst = s
					worst_at = Vector2(x, z)
				n += 1
			x += 2.1
		z += 2.1
	print("[t_terrainsmooth] %s step_max=%.3f m at (%.1f, %.1f) samples=%d" % [id, worst, worst_at.x, worst_at.y, n])
	_expect(worst < STEP_MAX, "%s rises %.2f m over 0.5 m at (%.1f, %.1f) away from a cliff (max %.2f)" % [id, worst, worst_at.x, worst_at.y, STEP_MAX])
	var old := _creases(rt, rt._heights, rt._res)
	var now := _creases(rt, rt._surf, rt._surf_res)
	print("[t_terrainsmooth] %s crease angle mean/p99 deg: old mesh %.2f/%.2f, refined %.2f/%.2f" % [id, old.x, old.y, now.x, now.y])
	_expect(now.x < old.x * 0.75 and now.y < old.y * 0.75, "%s facet creases are not 25 %% below the old mesh's" % id)

## Mean and 99th percentile of the angle (deg) between each triangle and its neighbours across the
## cell diagonal, the +x edge and the +z edge, on dry land away from cliffs. Grid of `res` over the island.
func _creases(rt: Node, h: PackedFloat32Array, res: int) -> Vector2:
	var cell: float = rt._size / float(res - 1)
	var half: float = rt._size * 0.5
	var angles := PackedFloat32Array()
	for z in range(1, res - 2):
		for x in range(1, res - 2):
			var wx := -half + (float(x) + 0.5) * cell
			var wz := -half + (float(z) + 0.5) * cell
			if h[x + z * res] < 0.5 or _near_cliff(rt, wx, wz):
				continue
			var a := _tri_n(h, res, cell, x, z, false)
			var b := _tri_n(h, res, cell, x, z, true)
			angles.append(rad_to_deg(a.angle_to(b)))
			angles.append(rad_to_deg(b.angle_to(_tri_n(h, res, cell, x + 1, z, false))))
			angles.append(rad_to_deg(b.angle_to(_tri_n(h, res, cell, x, z + 1, false))))
	if angles.is_empty():
		return Vector2.ZERO
	angles.sort()
	var sum := 0.0
	for v in angles:
		sum += v
	return Vector2(sum / float(angles.size()), angles[int(float(angles.size()) * 0.99)])

## Facet normal of the cell's first (x,z)(x+1,z)(x,z+1) or second (x+1,z)(x+1,z+1)(x,z+1) triangle.
func _tri_n(h: PackedFloat32Array, res: int, cell: float, x: int, z: int, second: bool) -> Vector3:
	var p00 := Vector3(0, h[x + z * res], 0)
	var p10 := Vector3(cell, h[x + 1 + z * res], 0)
	var p01 := Vector3(0, h[x + (z + 1) * res], cell)
	if not second:
		return (p01 - p00).cross(p10 - p00).normalized()
	var p11 := Vector3(cell, h[x + 1 + (z + 1) * res], cell)
	return (p01 - p10).cross(p11 - p10).normalized()

## Reads the chunk mesh under (x, z) back and intersects its triangles: surface_y must be the
## drawn ground, and the collision heightmap must hold the same array.
func _check_surface(id: StringName, rt: Node) -> void:
	var floor: Node = rt.get_node("Floor")
	var hs: HeightMapShape3D = null
	for c in floor.get_children():
		if c is CollisionShape3D:
			hs = (c as CollisionShape3D).shape as HeightMapShape3D
	_expect(hs != null and hs.map_width == rt._surf_res and hs.map_data == rt._surf, "%s collision heightmap is the refined grid" % id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var worst := 0.0
	var half: float = rt._size * 0.5 - 2.0
	for i in 300:
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var drawn := _mesh_y(floor, x, z)
		if is_nan(drawn):
			_expect(false, "%s no drawn triangle under (%.1f, %.1f)" % [id, x, z])
			return
		worst = maxf(worst, absf(drawn - float(rt.surface_y(x, z))))
	print("[t_terrainsmooth] %s surface_y vs drawn mesh max_err=%.5f m" % [id, worst])
	_expect(worst <= SURF_TOL, "%s surface_y is %.3f m off the drawn mesh (tol %.3f)" % [id, worst, SURF_TOL])

func _mesh_y(floor: Node, x: float, z: float) -> float:
	for c in floor.get_children():
		if not (c is MeshInstance3D) or not String(c.name).begins_with("TerrainMesh_"):
			continue
		var mesh := (c as MeshInstance3D).mesh
		if not mesh.get_aabb().grow(0.01).has_point(Vector3(x, mesh.get_aabb().get_center().y, z)):
			continue
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var p := Vector2(x, z)
		for k in range(0, idx.size(), 3):
			var a := v[idx[k]]
			var b := v[idx[k + 1]]
			var cc := v[idx[k + 2]]
			var bary := Geometry2D.point_is_inside_triangle(p, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(cc.x, cc.z))
			if bary:
				var w := _bary(p, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(cc.x, cc.z))
				return a.y * w.x + b.y * w.y + cc.y * w.z
	return NAN

func _bary(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var den := v0.x * v1.y - v1.x * v0.y
	var v := (v2.x * v1.y - v1.x * v2.y) / den
	var w := (v0.x * v2.y - v2.x * v0.y) / den
	return Vector3(1.0 - v - w, v, w)

## The data grid drives tiles and walkability, so those are unchanged by construction; build-slope
## verdicts read surface_y, so they are compared against the old bilinear surface cell by cell.
func _check_unchanged(id: StringName, rt: Node) -> void:
	_expect(rt.tile_types.size() == rt._tile_span * rt._tile_span and rt.dry_walk.size() == rt.tile_types.size(),
		"%s tile map and walk mask cover the island" % id)
	var grid: Node = rt.build_grid
	var surf: PackedFloat32Array = rt._surf
	var cells: Array[Vector2i] = []
	var half := int(rt._size * 0.5) - 4
	for z in range(-half, half, 3):
		for x in range(-half, half, 3):
			if rt.is_dry(Vector3(x + 0.5, 0, z + 0.5)):
				cells.append(Vector2i(x, z))
	var new_ok: Array[bool] = []
	for c in cells:
		new_ok.append(bool(grid._slope_ok(&"workbench", c, 0)))
	rt._surf = PackedFloat32Array()  # surface_y falls back to the data grid's bilinear surface
	var same := 0
	for i in cells.size():
		if bool(grid._slope_ok(&"workbench", cells[i], 0)) == new_ok[i]:
			same += 1
	rt._surf = surf
	var share := float(same) / maxf(1.0, float(cells.size()))
	print("[t_terrainsmooth] %s build-slope verdicts agree on %d/%d land cells (%.2f %%)" % [id, same, cells.size(), share * 100.0])
	_expect(share >= AGREE_MIN, "%s build-slope verdicts agree on only %.2f %%" % [id, share * 100.0])

func _check_beaches(id: StringName, rt: Node) -> void:
	var shape = rt._shape
	var span: int = rt._tile_span
	var half: float = rt._size * 0.5
	var sandy := 0
	var bearings := 360
	for i in bearings:
		var th := TAU * float(i) / float(bearings)
		var dir := Vector2(cos(th), sin(th))
		# The real waterline on this bearing: walk in from 12 m offshore until the ground is dry.
		var c: Vector2 = shape.coast_point(th) + dir * 12.0
		var steps := 0
		while rt.surface_y(c.x, c.y) < 0.0 and steps < 120:
			c -= dir * 0.25
			steps += 1
		var hits := 0
		var d := 1.0
		while d <= 12.0:
			var p := c - dir * d
			if int(rt.call("_tile_type_at_world", p.x, p.y)) == 3 and rt.surface_y(p.x, p.y) >= 0.45:
				hits += 1
			d += 1.0
		if hits >= 1:
			sandy += 1
	var share := float(sandy) / float(bearings)
	var want := float(load("res://scripts/world/biome_material.gd").row(str(rt._climate)).get("beach_share", 0.5))
	var near_cliff := 0
	for z in range(1, span - 1):
		for x in range(1, span - 1):
			# Beach sand (above the waterline band); the old waterline sand strip is not part of this.
			if int(rt.tile_types[x + z * span]) != 3 or rt.surface_y(-half + x + 0.5, -half + z + 0.5) < 0.45:
				continue
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if int(rt.tile_types[x + dx + (z + dz) * span]) == 11:
						near_cliff += 1
	print("[t_terrainsmooth] %s sandy beach on %.0f %% of the coast (data share %.0f %%), sand tiles touching a cliff: %d" % [
		id, share * 100.0, want * 100.0, near_cliff])
	_expect(share >= BEACH_MIN and share <= BEACH_MAX, "%s sandy beach covers %.0f %% of the coast (want %.0f-%.0f %%)" % [id, share * 100.0, BEACH_MIN * 100.0, BEACH_MAX * 100.0])
	_expect(absf(share - want) <= 0.15, "%s sandy beach %.0f %% is far from its data share %.0f %%" % [id, share * 100.0, want * 100.0])
	_expect(near_cliff == 0, "%s has %d sand tiles touching a cliff" % [id, near_cliff])

## Top-down shot of a forest/meadow border with everything but the ground hidden; the colour
## profile across it (x axis, averaged over 8 m of z) must change gradually.
func _check_blend(rt: Node) -> void:
	var at := _border(rt)
	if at == Vector3.INF:
		_expect(false, "home has no forest/meadow border to measure")
		return
	for c in rt.get_children():
		if c is Node3D and c.name != "Floor":
			(c as Node3D).visible = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 24.0
	cam.far = 300.0
	_host.add_child(cam)
	cam.global_position = Vector3(at.x, 120.0, at.z)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.current = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	cam.queue_free()
	var w := img.get_width()
	var h := img.get_height()
	var m_per_px := 24.0 / float(h)
	var rows := int(8.0 / m_per_px)
	var prof: Array[Color] = []
	var step_px := maxi(1, int(0.5 / m_per_px))
	var x := 0
	while x < w:
		var acc := Color(0, 0, 0)
		var n := 0
		for y in range(h / 2 - rows / 2, h / 2 + rows / 2):
			for dx in step_px:
				acc += img.get_pixel(mini(x + dx, w - 1), y)
				n += 1
		prof.append(acc / float(n))
		x += step_px
	# Ends: the mean of the outer 3 m on each side.
	var k := int(3.0 / 0.5)
	var lc := Color(0, 0, 0)
	var rc := Color(0, 0, 0)
	for i in k:
		lc += prof[i]
		rc += prof[prof.size() - 1 - i]
	lc /= float(k)
	rc /= float(k)
	var dvec := Vector3(rc.r - lc.r, rc.g - lc.g, rc.b - lc.b)
	var dd := dvec.length_squared()
	if dd < 0.0004:
		_expect(false, "forest and meadow are the same colour at (%.1f, %.1f)" % [at.x, at.z])
		return
	var t: Array[float] = []
	for c in prof:
		t.append(Vector3(c.r - lc.r, c.g - lc.g, c.b - lc.b).dot(dvec) / dd)
	var max_step := 0.0
	for i in range(1, t.size()):
		max_step = maxf(max_step, absf(t[i] - t[i - 1]))
	var lo := -1
	var hi := -1
	for i in t.size():
		if lo < 0 and t[i] > 0.1:
			lo = i
		if t[i] < 0.9:
			hi = i + 1
	var width := float(hi - lo) * 0.5 if lo >= 0 and hi >= 0 else 0.0
	print("[t_terrainsmooth] zone border at (%.1f, %.1f): colour diff %.3f, 10-90 %% width %.1f m, largest 0.5 m step %.0f %% of the change" % [
		at.x, at.z, sqrt(dd), width, max_step * 100.0])
	_expect(width >= BLEND_MIN_M, "zone border blends over %.1f m (min %.1f)" % [width, BLEND_MIN_M])
	_expect(max_step <= STEP_SHARE, "a 0.5 m step carries %.0f %% of the zone border's colour change" % (max_step * 100.0))
	for c in rt.get_children():
		if c is Node3D:
			(c as Node3D).visible = true

## A point with forest 10+ m to the west and meadow 10+ m to the east along x, on flat dry land.
func _border(rt: Node) -> Vector3:
	var bz := load("res://scripts/world/biome_zones.gd")
	var arr: PackedByteArray = bz.biome_types(rt)
	var forest: int = bz.zone_id("forest")
	var meadow: int = bz.zone_id("meadow")
	var span: int = rt._tile_span
	var half: float = rt._size * 0.5
	for z in range(20, span - 20, 3):
		for x in range(20, span - 20):
			var ok := true
			for dx in range(1, 11):
				if int(arr[x - dx + z * span]) != forest or int(arr[x + dx + z * span]) != meadow:
					ok = false
					break
			if not ok:
				continue
			var p := Vector3(-half + x + 0.5, 0, -half + z + 0.5)
			var flat := true
			for dx in range(-11, 12, 2):
				var t := int(rt.tile_types[x + dx + z * span])
				if t != 0 or not rt.is_dry(Vector3(p.x + dx, 0, p.z)):
					flat = false
			if flat:
				return p
	return Vector3.INF
