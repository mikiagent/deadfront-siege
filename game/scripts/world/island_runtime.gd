class_name IslandRuntime
extends Node3D
## Generates a private or unstable island: heightmap, nav, harvest, harbour, camp, crater.
## Build orchestration and the public API live here; the work lives in IslandTerrain,
## IslandScatter, IslandSpawns, IslandClaims, WorldLighting and WorldWeather.

var harvest_count: int = 0
var creature_count: int = 0
var mm_count: int = 0
var harbour
var cargo
var cargo_basket
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var lighting: WorldLighting
var weather := WorldWeather.new()
## Cloud and pteranodon ground shadows (SKYSHADOWS).
var sky: SkyShadows
var raining: bool:
	get:
		return weather.raining
var _size: float = 240.0
var _res: int = 65
var _heights: PackedFloat32Array = PackedFloat32Array()
## The rendered ground (IslandTerrain._refine): _heights refined 2x with a clamped cubic, so the mesh,
## its collision and surface_y share one smooth surface. _heights stays the data grid (tiles, zones).
var _surf: PackedFloat32Array = PackedFloat32Array()
var _surf_res: int = 0
## The landmass generator (IslandShape): coastline, river, mesa, peaks. is_dry and the scatter
## read its precomputed rad grid through rad_at.
var _shape: IslandShape
## MAPLAB: the authored map this island was built from (def "map" path or "map_doc"), else null.
var map_doc: MapDoc = null
## Per-heightmap-vertex effective radius, river distance and gradient (IslandShape.compute).
var _rad: PackedFloat32Array = PackedFloat32Array()
var _river_d: PackedFloat32Array = PackedFloat32Array()
var _vslope: PackedFloat32Array = PackedFloat32Array()
var _climate: String = "temperate"
var _tier: int = 25
var _level_override: int = 0
var _camp_pos: Vector3 = Vector3.ZERO
var _harbour_pos: Vector3 = Vector3.ZERO
var _camp_hint: Vector3 = Vector3.ZERO
var _crater_pos: Vector3 = Vector3.ZERO
var _crater_hint: Vector3 = Vector3.ZERO
var _ridge_dir: Vector2 = Vector2.RIGHT
var _tile_span: int = 0
var tile_types: PackedByteArray = PackedByteArray()
## 1 on the river's MUD tiles as built; IslandTerrain.fresh_water_at_world reads it, harvesting never changes it.
var fresh_water: PackedByteArray = PackedByteArray()
## 1 on every dry walkable tile (IslandTerrain fills it with the tile map); is_dry's fast path.
var dry_walk: PackedByteArray = PackedByteArray()
var _tile_map_image: Image
var _tile_map_tex: ImageTexture
## Static ground masks for the terrain shader (IslandTerrain._build_tile_types): R rock, G ash, B mud,
## A dirt, mipmapped so the shader reads them blurred over a few metres instead of per 1 m tile.
var _soft_tex: ImageTexture
## Zone colour (linear tint) and layer mix per 2 m, mipmapped: the shader reads them blurred over the
## zone edge width so zone borders blend instead of stepping along the tile grid.
var _zone_tint_tex: ImageTexture
var _zone_mix_tex: ImageTexture
var _terrain_mat: ShaderMaterial
var _foliage_mat: ShaderMaterial
var _palette: Dictionary = {}
var _node_tiles: Dictionary = {}
var _harvest_nodes: Dictionary = {}
var _bare_tiles: Dictionary = {}
var spawn_rejected: int = 0
var build_grid: BuildGrid
## Scenery layer (non-resource props): IslandProps node, null until build() has scattered it.
var props
## Ground-cover instance positions (grass, flowers) as scattered, for the lab and t_props density
## checks. The visuals themselves live in VegBatch cells; this is the placement record only.
var cover_points: PackedVector3Array = PackedVector3Array()
var pathing
var _height_tex: ImageTexture
var _water_mat: ShaderMaterial
var _used_tiles: Dictionary = {}
var _tree_discs: MultiMeshInstance3D
var _tree_disc_xforms: Array[Transform3D] = []
var _batches: Array[VegBatch] = []
var claims: Array[Rect2i] = []
## CLAIMS2: the camp's own landing claim (kept for buildability; it is not a domain cell).
var camp_claim: Rect2i = Rect2i()
## CLAIMS2 / spec 29: the domain record (domain_id, kind, island_id, owner, cells, max_cells, status)
## and the grass decor multimeshes IslandScatter made, so a claim can drop the instances inside it.
var domain: Dictionary = {}
var grass_mm: Array[MultiMeshInstance3D] = []
## Fired ONCE per newly claimed cell batch with the tiles the batch covers (GROUND2D's painted ground
## cover listens: claimed land is bare). A single claim_at() fires it once too.
signal claims_changed(rect: Rect2i)
## Other players' land here: {"rect": Rect2i, "owner": {"id", "name"}}; only IslandClaims.set_others writes it.
var other_claims: Array[Dictionary] = []
var _claim_mesh: MeshInstance3D

## Where the dry land ends: the shore band's start. The coastline itself (rain height -0.05) sits
## about 0.09 * size further out, so this leaves the beach walkable.
func land_radius() -> float:
	return _size * 0.36

## Effective radius (metres, coastline at land_radius + 0.09 * size) by bilinear lookup.
func rad_at(x: float, z: float) -> float:
	if _rad.is_empty():
		return Vector2(x, z).length()
	return _sample_grid(_rad, x, z)

func river_dist_at(x: float, z: float) -> float:
	if _river_d.is_empty():
		return 10000.0
	return _sample_grid(_river_d, x, z)

func slope_at(x: float, z: float) -> float:
	if _vslope.is_empty():
		return 0.0
	return _sample_grid(_vslope, x, z)

func _sample_grid(arr: PackedFloat32Array, x: float, z: float) -> float:
	var cell := _size / float(_res - 1)
	var u := clampf((x + _size * 0.5) / cell, 0.0, float(_res - 1))
	var v := clampf((z + _size * 0.5) / cell, 0.0, float(_res - 1))
	var x0 := int(floor(u))
	var z0 := int(floor(v))
	var x1 := mini(x0 + 1, _res - 1)
	var z1 := mini(z0 + 1, _res - 1)
	var tx := u - float(x0)
	var tz := v - float(z0)
	return lerpf(lerpf(arr[x0 + z0 * _res], arr[x1 + z0 * _res], tx), lerpf(arr[x0 + z1 * _res], arr[x1 + z1 * _res], tx), tz)

## True when a creature may stand at pos: on dry land above the beach and the river,
## inside the land radius and (when strict) at least 25 m from camp and the harbour
## (rules.json landing ring: "nothing spawns within 25 m of camp").
## Non-strict also accepts the harbour's approach strip (HarbourSite.APPROACH_M).
func spawn_ok(pos: Vector3, strict: bool = true) -> bool:
	if _heights.is_empty():
		return true
	if not is_dry(pos) and (strict or not on_harbour_approach(pos)):
		return false
	if strict:
		var keep := 25.0
		if Vector2(pos.x - _camp_pos.x, pos.z - _camp_pos.z).length() < keep:
			return false
		# ASSUMPTION: the harbour is where travel lands the survivor, so it gets the camp's 25 m
		# landing ring (was 15 m when it stood inland next to the camp).
		if Vector2(pos.x - _harbour_pos.x, pos.z - _harbour_pos.z).length() < keep:
			return false
	return true

func build(def: Dictionary, terrain: StringName) -> void:
	# Size comes from the island data (stable IDs get it from World._load_islands' tier table),
	# never from far_shore * 2: the plan's land bbox (330-415 x 265-335 m) fits the square grid.
	var size := float(def.get("size_m", 416))
	_climate = str(def.get("climate", "grassland"))
	_tier = int(def.get("tier", 10))
	_level_override = int(def.get("level_override", 0))
	var harbour_a: Array = def.get("harbour", [0, 0, 12])
	var camp_a: Array = def.get("camp", [0, 0, 6])
	_camp_hint = Vector3(float(camp_a[0]), 0.0, float(camp_a[2]))
	var crater_v: Variant = def.get("crater", null)
	_crater_hint = Vector3.ZERO
	if crater_v is Array and (crater_v as Array).size() >= 3:
		_crater_hint = Vector3(float(crater_v[0]), 0.0, float(crater_v[2]))
	lighting = WorldLighting.install(self, _climate)
	sun = lighting.sun
	world_env = lighting.world_env
	var seed := int(def.get("seed", 17 if str(def.get("kind", "")) == "private" else hash(str(def.get("id", "island")))))
	var legacy := str(def.get("kind", "")) == "private"
	var hint := Vector2(float(harbour_a[0]), float(harbour_a[2])) if def.has("harbour") else Vector2(_camp_hint.x, _camp_hint.z)
	var t0 := Time.get_ticks_usec()
	PerfTrace.start(str(def.get("id", "")))
	_shape = IslandShape.make(size, seed, str(def.get("kind", "unstable")), _tier, hint, legacy, 161, _climate)
	_shape.camp_hint = Vector2(_camp_hint.x, _camp_hint.z)
	map_doc = def.get("map_doc", null) as MapDoc
	if map_doc == null and def.has("map"):
		map_doc = MapDoc.load_file(str(def["map"]))
	if map_doc != null:
		map_doc.apply_to_shape(_shape)  # the painted land, heights and water replace the generator's
	else:
		_shape.compute()
	PerfTrace.mark("shape")
	var t1 := Time.get_ticks_usec()
	IslandTerrain.build(self, size, _climate, _shape)
	PerfTrace.mark("terrain")
	var t2 := Time.get_ticks_usec()
	IslandTerrain.bake_nav(self)
	PerfTrace.mark("nav")
	build_grid = BuildGrid.new()
	build_grid.name = "BuildGrid"
	build_grid.setup(self)
	add_child(build_grid)
	_camp_pos = _tile_at(float(camp_a[0]), float(camp_a[2]))
	_harbour_pos = _tile_at(float(harbour_a[0]), float(harbour_a[2]))
	if _crater_hint != Vector3.ZERO:
		_crater_pos = _tile_at(_crater_hint.x, _crater_hint.z)
	# The json harbour is a hint: the dock goes on the legal coast pose nearest it (HarbourSite).
	var site := HarbourSite.find(self, hint)
	if site.is_empty():
		push_error("[world] island %s has no coast for the harbour" % def.get("id", ""))
	harbour = (load("res://scripts/world/harbour.gd") as GDScript).new()
	_camp_place(harbour, "Harbour", &"harbour", site.get("cell", BuildGrid.tile_of(_harbour_pos) - Vector2i(1, 3)), int(site.get("rot", 0)))
	_publish_harbour_arrival()
	_camp(_camp_pos)
	cargo = (load("res://scripts/world/cargo_warp.gd") as GDScript).new()
	_camp_place(cargo, "CargoWarp", &"chest", BuildGrid.tile_of(_tile_at(float(camp_a[0]) + 3.0, float(camp_a[2]))))
	if str(def.get("kind", "")) == "private":
		var PB := load("res://scripts/world/placed_building.gd") as GDScript
		cargo_basket = PB.make(&"basket")
		cargo_basket.is_cargo = true
		cargo_basket.storage = World.cargo_home
		cargo_basket.position = _dry_beside_harbour()
		add_child(cargo_basket)
		build_grid.reserve_kind(&"basket", BuildGrid.tile_of(cargo_basket.position), 0)
	IslandClaims.setup(self, def)
	var t3 := Time.get_ticks_usec()
	PerfTrace.mark("camp")
	IslandScatter.scatter(self, def, terrain, _climate, _tier, size)
	PerfTrace.mark("scatter")
	props = IslandProps.build(self)
	# CLAIMPROPS: a save's claimed land is bare. The domain is set up before the scatter and the props
	# build, so the filter is already in place; this sweep is the belt to that braces (a node type that
	# appears after a claim, and the lab's authored props).
	IslandClaims.clean_claimed(self)
	PerfTrace.mark("props")
	var t4 := Time.get_ticks_usec()
	_setup_pathing()
	PerfTrace.mark("pathing")
	var t5 := Time.get_ticks_usec()
	IslandSpawns.spawn_all(self, def)
	PerfTrace.mark("spawns")
	if crater_v is Array:
		_crater(_at(float(crater_v[0]), float(crater_v[2])))
	weather.install(self)
	sky = SkyShadows.install(self, _climate, lighting)
	IslandTerrain.drive_focus(self)
	PerfTrace.finish()
	if OS.get_environment("ISL_TIME") == "1":
		print("[islandgen-time] %s shape=%.0fms terrain=%.0fms rest=%.0fms scatter=%.0fms pathing=%.0fms total=%.0fms" % [def.get("id", ""), float(t1 - t0) / 1000.0, float(t2 - t1) / 1000.0, float(t3 - t2) / 1000.0, float(t4 - t3) / 1000.0, float(t5 - t4) / 1000.0, float(Time.get_ticks_usec() - t0) / 1000.0])
	print("[world] island %s nodes=%d creatures=%d spawn_rejected=%d" % [def.get("id", ""), harvest_count, creature_count, spawn_rejected])

func mark_pathing_dirty() -> void:
	if pathing:
		pathing.mark_dirty()

func _process(delta: float) -> void:
	IslandTerrain.drive_focus(self)
	weather.tick(self, delta)

func surface_y(x: float, z: float) -> float:
	if not _surf.is_empty():
		# The drawn ground: the refined grid's two triangles per cell, diagonal (x+1, z)-(x, z+1), as
		# IslandTerrain._chunk_mesh draws them. Inlined: scatter and props call this ~100k times a build.
		var last := float(_surf_res - 1)
		var fc := _size / last
		var fu := clampf((x + _size * 0.5) / fc, 0.0, last)
		var fv := clampf((z + _size * 0.5) / fc, 0.0, last)
		var fx0 := mini(int(fu), _surf_res - 2)
		var fz0 := mini(int(fv), _surf_res - 2)
		var ftx := fu - float(fx0)
		var ftz := fv - float(fz0)
		var i := fx0 + fz0 * _surf_res
		if ftx + ftz <= 1.0:
			var a := _surf[i]
			return a + (_surf[i + 1] - a) * ftx + (_surf[i + _surf_res] - a) * ftz
		var b := _surf[i + _surf_res + 1]
		return b + (_surf[i + _surf_res] - b) * (1.0 - ftx) + (_surf[i + 1] - b) * (1.0 - ftz)
	if _heights.is_empty():
		return 0.0
	var cell := _size / float(_res - 1)
	var u := clampf((x + _size * 0.5) / cell, 0.0, float(_res - 1))
	var v := clampf((z + _size * 0.5) / cell, 0.0, float(_res - 1))
	var x0 := int(floor(u))
	var z0 := int(floor(v))
	var x1 := mini(x0 + 1, _res - 1)
	var z1 := mini(z0 + 1, _res - 1)
	var tx := u - float(x0)
	var tz := v - float(z0)
	var h00 := _heights[x0 + z0 * _res]
	var h10 := _heights[x1 + z0 * _res]
	var h01 := _heights[x0 + z1 * _res]
	var h11 := _heights[x1 + z1 * _res]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func _at(x: float, z: float) -> Vector3:
	return Vector3(x, surface_y(x, z), z)

func _tile_at(x: float, z: float) -> Vector3:
	return BuildGrid.tile_centre(BuildGrid.tile_of(Vector3(x, 0.0, z)), self)

## Rings are measured from where the survivor LANDS (the dock's arrival point), not the island
## origin: the shaped islands are elongated and off-centre, so an origin-centred ring would
## mis-level and mis-spawn the far end (the plan's landing-ring rule).
func ring_centre() -> Vector2:
	if _harbour_pos != Vector3.ZERO and _shape != null and HarbourSite != null:
		var a: Vector3 = arrival_point()
		return Vector2(a.x, a.z)
	return Vector2(_camp_pos.x, _camp_pos.z)

func ring_name(pos: Vector3) -> StringName:
	var c := ring_centre()
	var r := Vector2(pos.x - c.x, pos.z - c.y).length()
	var rings: Dictionary = Data.world_rules.get("rings", {})
	for id in ["landing", "gathering", "working", "crater", "far_shore"]:
		var row: Variant = rings.get(id, {})
		if row is Dictionary:
			var span: Array = row.get("radius_m", [0, 0])
			if span.size() >= 2 and r >= float(span[0]) and r < float(span[1]):
				return StringName(id)
	return &"far_shore"

func material_level(pos: Vector3, tier: int) -> int:
	if _level_override > 0:
		return clampi(_level_override, 1, int(Data.world_rules.get("level_cap", 60)))
	var rings: Dictionary = Data.world_rules.get("rings", {})
	var row: Dictionary = rings.get(str(ring_name(pos)), {})
	var off := int(row.get("level_offset", 0))
	return clampi(tier + off, 1, int(Data.world_rules.get("level_cap", 60)))

func _setup_pathing() -> void:
	if pathing and is_instance_valid(pathing):
		pathing.queue_free()
	var script := load("res://scripts/world/tile_path.gd") as GDScript
	pathing = script.new() if script else null
	if pathing == null:
		return
	pathing.name = "TilePath"
	add_child(pathing)
	pathing.setup(self)

## Camp pieces are real buildings (occupied cells, not reserved) so layout mode can move them;
## a moved pose is remembered in World.camp_layout and applied here on the next build.
func _camp_place(node: Node3D, name: String, kind: StringName, default_cell: Vector2i, default_rot: int = 0) -> void:
	node.name = name
	var cell := default_cell
	var rot := default_rot
	var saved: Variant = World.camp_layout.get(name, null) if World else null
	if saved is Dictionary:
		var cv: Variant = (saved as Dictionary).get("cell", null)
		if cv is Array and (cv as Array).size() >= 2:
			cell = Vector2i(int(cv[0]), int(cv[1]))
		rot = int((saved as Dictionary).get("rot", 0))
	# Saves from before the coast rule kept the dock inland; those poses snap back to the coast.
	if kind == &"harbour" and HarbourSite.check(self, cell, rot) != "":
		cell = default_cell
		rot = default_rot
	add_child(node)
	node.global_transform = build_grid.placement_transform(kind, cell, rot)
	if node.has_method("set_grid_pose"):
		node.set_grid_pose(cell, rot)
	build_grid.occupy(node, build_grid.cells_for(kind, cell, rot))

## Dry land above the beach, inside the land radius, on walkable ground: never the river channel,
## a cliff face or the sea. Reads the precomputed grids only (TilePath and build checks call this
## per tile).
func is_dry(pos: Vector3) -> bool:
	if not dry_walk.is_empty():
		if pos.x < -_size * 0.5 or pos.z < -_size * 0.5 or pos.x >= _size * 0.5 or pos.z >= _size * 0.5:
			return false
		var tx := int(floor(pos.x + _size * 0.5))
		var tz := int(floor(pos.z + _size * 0.5))
		var idx := clampi(tx, 0, _tile_span - 1) + clampi(tz, 0, _tile_span - 1) * _tile_span
		return dry_walk[idx] == 1
	# Before the tile map exists (and for any caller with a position off the grid).
	if rad_at(pos.x, pos.z) > land_radius() - 2.0:
		return false
	return surface_y(pos.x, pos.z) >= 0.4

## Distance (m) from the ring centre to the FARTHEST dry tile: the spawn rings are clamped to
## this, so the band reaches the far shore of an elongated island instead of stopping at a
## land_radius circle while the far half gets no spawns.
func farthest_dry_radius() -> float:
	if dry_walk.is_empty():
		return land_radius() * 1.10
	var c := ring_centre()
	var half := _size * 0.5
	var best := 0.0
	for z in _tile_span:
		for x in _tile_span:
			if dry_walk[x + z * _tile_span] == 0:
				continue
			var wx := -half + float(x) + 0.5
			var wz := -half + float(z) + 0.5
			best = maxf(best, Vector2(wx - c.x, wz - c.y).length())
	return maxf(best, land_radius())

## Tile rect (BuildGrid tile coordinates) holding every dry tile: TilePath's grid is built from it.
## Computed once per island when the tile map exists (1 m tiles), cached.
func dry_bbox() -> Rect2i:
	if _dry_bbox.size.x > 0:
		return _dry_bbox
	if tile_types.is_empty():
		return Rect2i()
	var span := _tile_span
	var half := _size * 0.5
	var lo := Vector2i(span, span)
	var hi := Vector2i(-span, -span)
	var off := span / 2
	for z in span:
		for x in span:
			if not _is_dry_tile(x, z, half):
				continue
			# Tile map indices -> BuildGrid world tiles (1 m cells at floor(world)).
			var t := Vector2i(x - off, z - off)
			lo = Vector2i(mini(lo.x, t.x), mini(lo.y, t.y))
			hi = Vector2i(maxi(hi.x, t.x), maxi(hi.y, t.y))
	if hi.x < lo.x:
		return Rect2i()
	_dry_bbox = Rect2i(lo, hi - lo + Vector2i.ONE)
	return _dry_bbox

var _dry_bbox: Rect2i = Rect2i()

func _is_dry_tile(x: int, z: int, _half: float) -> bool:
	return dry_walk[x + z * _tile_span] == 1

func on_harbour_approach(pos: Vector3) -> bool:
	return harbour != null and HarbourSite.on_approach(harbour.build_cell, harbour.build_rot, Vector2(pos.x, pos.z)) \
		and surface_y(pos.x, pos.z) > HarbourSite.WATER_Y

func harbour_approach_rect() -> Rect2i:
	return HarbourSite.approach_rect(harbour.build_cell, harbour.build_rot) if harbour != null else Rect2i()

## Travel lands the survivor here: the sand just behind the dock's base, at the water's edge.
func arrival_point() -> Vector3:
	var p := HarbourSite.arrival_point(harbour.build_cell, harbour.build_rot)
	return _at(p.x, p.y)

## Scatter keeps the dock, its approach and the cargo basket clear.
func near_harbour(pos: Vector3) -> bool:
	return Vector2(pos.x - _harbour_pos.x, pos.z - _harbour_pos.z).length() < 8.0 or on_harbour_approach(pos)

## The home cargo basket: beside the dock's base, walked inland until it stands on dry land.
func _dry_beside_harbour() -> Vector3:
	var s := HarbourSite.seaward(harbour.build_rot)
	var p := HarbourSite.base_point(harbour.build_cell, harbour.build_rot) + Vector2(s.y, -s.x) * 3.0
	for _i in 24:
		if is_dry(_at(p.x, p.y)):
			break
		p -= s
	return _tile_at(p.x, p.y)

func on_harbour_moved() -> void:
	_harbour_pos = harbour.global_position
	_publish_harbour_arrival()
	if cargo_basket == null or build_grid == null:
		return
	var old_basket_cell := BuildGrid.tile_of(cargo_basket.global_position)
	build_grid.release_reserved_kind(&"basket", old_basket_cell)
	cargo_basket.position = _dry_beside_harbour()
	build_grid.reserve_kind(&"basket", BuildGrid.tile_of(cargo_basket.position), 0)

func _publish_harbour_arrival() -> void:
	if World == null:
		return
	var row: Variant = World.islands.get(str(World.island_id), null)
	if not row is Dictionary:
		return
	var p := arrival_point()
	(row as Dictionary)["harbour"] = [p.x, 0.0, p.z]

func _camp(at: Vector3) -> void:
	_coziness(at)
	var fire := Bonfire.make()
	fire.persist_building = false
	_camp_place(fire, "CampFire", &"bonfire", BuildGrid.tile_of(at + Vector3(-2.0, 0.0, 0.0)))
	var bench := CraftStation.make(&"workbench")
	bench.persist_building = false
	_camp_place(bench, "CampBench", &"workbench", BuildGrid.tile_of(at + Vector3(2.0, 0.0, 0.0)))
	var PB := load("res://scripts/world/placed_building.gd") as GDScript
	var shed = PB.make(&"tent")
	shed.persist_building = false
	shed.sleeps_left = -1  # public camp shelter does not consume personal kit uses
	_camp_place(shed, "CampShed", &"tent", BuildGrid.tile_of(_tile_at(at.x, at.z - 3.5)))

func _coziness(at: Vector3) -> void:
	var area := Area3D.new()
	area.name = "CampCozy"
	area.add_to_group("coziness")
	area.position = at
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(12, 4, 12)
	cs.shape = sh
	cs.position.y = 2
	area.add_child(cs)
	add_child(area)

func _crater(at: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Crater"
	area.add_to_group("crater")
	area.position = at
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 10.0
	cs.shape = sh
	area.add_child(cs)
	area.body_entered.connect(func (b: Node) -> void:
		if b is Player:
			World.discover_crater()
	)
	add_child(area)
	var crater_lv := clampi(_tier + 5, 1, 60)
	for i in 6:
		var ang := float(i) * TAU / 6.0
		var p := Vector3(at.x + cos(ang) * 9.0, 0.0, at.z + sin(ang) * 9.0)
		p.y = surface_y(p.x, p.z)
		harvest_count += _plant_at("Plant", "crater_node_%d" % i, p, &"herb_leaf", &"none", _climate, crater_lv, Color(0.45, 0.2, 0.35))

func _on_tile_bare(node: HarvestNode, tile: Vector2i) -> void:
	if node == null:
		return
	var key := "%d:%d" % [tile.x, tile.y]
	var row: Dictionary = _node_tiles.get(str(node.node_id), {})
	var base_type := int(row.get("base", IslandTerrain.TileType.GRASS))
	_bare_tiles[key] = {
		"tile": [tile.x, tile.y],
		"base": base_type,
		"node_id": str(node.node_id),
	}
	IslandTerrain.set_tile_type(self, tile, IslandTerrain.TileType.BARE)
	mark_pathing_dirty()
	print("[world] tile bare (%d,%d)" % [tile.x, tile.y])

func _on_tile_regrown(node: HarvestNode, tile: Vector2i) -> void:
	if node == null:
		return
	var key := "%d:%d" % [tile.x, tile.y]
	var row: Dictionary = _bare_tiles.get(key, {})
	var base_type := int(row.get("base", IslandTerrain.TileType.GRASS))
	IslandTerrain.set_tile_type(self, tile, base_type)
	_bare_tiles.erase(key)
	mark_pathing_dirty()
	print("[world] tile regrown (%d,%d)" % [tile.x, tile.y])

func harvest_tile_snapshot() -> Dictionary:
	var arr: Array = []
	for key in _bare_tiles.keys():
		var row: Dictionary = _bare_tiles[key]
		var node_id := str(row.get("node_id", ""))
		var left := 0.0
		if _harvest_nodes.has(node_id):
			var n := _harvest_nodes[node_id] as HarvestNode
			if n:
				left = n.regen_left()
		arr.append({
			"tile": row.get("tile", [0, 0]),
			"base": int(row.get("base", IslandTerrain.TileType.GRASS)),
			"node_id": node_id,
			"regen_left": left,
		})
	# Scenery props cleared by this save (owner: most props can be destroyed except big cliffs). They
	# ride this snapshot so no save key and no schema bump is needed; IslandProps reads it back.
	var snap := {"bare_tiles": arr}
	if props != null and is_instance_valid(props) and props.has_method("snapshot"):
		snap["props"] = props.snapshot()
	return snap

func apply_harvest_tile_snapshot(snap: Dictionary) -> void:
	var pv: Variant = snap.get("props", null)
	if pv is Dictionary and props != null and is_instance_valid(props) and props.has_method("apply_snapshot"):
		props.apply_snapshot(pv as Dictionary)
	# Stale rows are dropped: a bare tile whose node does not exist in this layout (an old island's
	# id) would otherwise paint BARE at an unrelated coordinate until it regrows.
	var arr: Variant = snap.get("bare_tiles", [])
	if not arr is Array:
		return
	for row_v in arr:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var nid := str(row.get("node_id", ""))
		if nid != "" and not _harvest_nodes.is_empty() and not _harvest_nodes.has(nid):
			continue
		var tile_a: Array = row.get("tile", [0, 0])
		if tile_a.size() < 2:
			continue
		var tile := Vector2i(int(tile_a[0]), int(tile_a[1]))
		var key := "%d:%d" % [tile.x, tile.y]
		_bare_tiles[key] = {
			"tile": [tile.x, tile.y],
			"base": int(row.get("base", IslandTerrain.TileType.GRASS)),
			"node_id": str(row.get("node_id", "")),
		}
		IslandTerrain.set_tile_type(self, tile, IslandTerrain.TileType.BARE)

func is_claimed(tile: Vector2i) -> bool:
	return IslandClaims.is_claimed(self, tile)

## CLAIMS2 / spec 29: claim the cell the tile stands in; false when it cannot be claimed (water, a
## cliff, another survivor, the cap, or not next to the domain).
func claim_at(tile: Vector2i, size: int = 0) -> bool:
	return IslandClaims.claim_at(self, tile, size)

## The tile rect of the cell a claim at `tile` would take (IslandClaims.plot_for).
func claim_plot(tile: Vector2i, size: int = 0) -> Rect2i:
	return IslandClaims.plot_for(self, tile)

## Why a claim at `tile` would be refused, "" when it would be staked (IslandClaims.block_reason).
func claim_block_reason(tile: Vector2i, size: int = 0) -> String:
	return IslandClaims.block_reason(self, tile, size)

## Why a claim at `tile` would not expand the land held here, "" when it would (IslandClaims.expand_reason).
func claim_expand_reason(tile: Vector2i, size: int = 0) -> String:
	return IslandClaims.expand_reason(self, tile, size)

## The cells this domain may grow into now (IslandClaims.eligible_cells): the preview's candidates.
func claim_eligible_cells(centre: Vector2i = IslandClaims.NO_CELL, radius: int = -1) -> Array[Vector2i]:
	return IslandClaims.eligible_cells(self, centre, radius)

## The preview around `centre`: {"claimed", "eligible", "invalid"} (IslandClaims.preview).
func claim_preview(centre: Vector2i, radius: int = IslandClaims.PREVIEW_RADIUS) -> Dictionary:
	return IslandClaims.preview(self, centre, radius)

## Claim a batch of cells as Declare or Expand (IslandClaims.claim_cells): {"ok", "reason", "cells"}.
func claim_domain(cells: Array) -> Dictionary:
	return IslandClaims.claim_cells(self, cells)

## Give up the domain's cells (the camp's own land stays): the Domain screen's Release.
func clear_domain() -> void:
	IslandClaims.clear_domain(self)

## UNCLAIM: why the cell at `cell` cannot be released right now ("" when it can).
func release_reason(cell: Vector2i) -> String:
	return IslandClaims.release_reason(self, cell)

## UNCLAIM: release one cell of the domain ({"ok", "reason", "cell"}).
func release_cell(cell: Vector2i) -> Dictionary:
	return IslandClaims.release_cell(self, cell)

## Cells held / the cap (spec 29 section 4).
func claim_used() -> int:
	return IslandClaims.used(self)

func claim_cap() -> int:
	return IslandClaims.cap(self)

## Why this island refuses more land now ("" below the cap): the notice the HUD and the Domain
## screen show. The cap reason wins; otherwise the ground is the reason.
func claim_limit_reason() -> String:
	if IslandClaims.at_cap(self):
		return "Claim limit reached (%d/%d)" % [IslandClaims.used(self), IslandClaims.cap(self)]
	return ""

## The domain record (spec 29 section 3): domain_id, kind, island_id, owner, cells, max_cells, status.
func domain_record() -> Dictionary:
	return IslandClaims.to_save(self)

func classify_cell(cell: Vector2i) -> Dictionary:
	return IslandClaims.classify(self, cell)

## Whose land the tile is, {} when nobody's (IslandClaims.owner_at).
func owner_at(tile: Vector2i) -> Dictionary:
	return IslandClaims.owner_at(self, tile)

## Other players' claims on this island, replacing the last set (IslandClaims.set_others).
func set_other_claims(rows: Array) -> void:
	IslandClaims.set_others(self, rows)

# Kept for labs, the HUD and has_method() callers that reach into the runtime.
func _plant_at(family: String, role: String, pos: Vector3, fallback_id: StringName, tool: StringName, climate: String, level: int, color: Color) -> int:
	return IslandScatter.plant_at(self, family, role, pos, fallback_id, tool, climate, level, color)

func _tile_type_at_world(x: float, z: float) -> int:
	return IslandTerrain.tile_type_at_world(self, x, z)

func _slope_deg(x: float, z: float) -> float:
	return IslandTerrain.slope_deg(self, x, z)
