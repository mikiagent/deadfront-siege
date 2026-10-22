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
var raining: bool:
	get:
		return weather.raining
var _size: float = 240.0
var _res: int = 65
var _heights: PackedFloat32Array = PackedFloat32Array()
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
var _tile_map_image: Image
var _tile_map_tex: ImageTexture
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
## Other players' land here: {"rect": Rect2i, "owner": {"id", "name"}}; only IslandClaims.set_others writes it.
var other_claims: Array[Dictionary] = []
var _claim_mesh: MeshInstance3D

func land_radius() -> float:
	return _size * 0.38

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
	var size := float(def.get("size_m", 160))
	# ASSUMPTION: rules.json island_size_m.unstable is 240 but rings extend to 240 m radius;
	# the generator uses diameter = 2 * far_shore so crater and far-shore rings fit on the mesh.
	if str(def.get("kind", "")) != "private":
		var rings: Dictionary = Data.world_rules.get("rings", {})
		var far: Variant = rings.get("far_shore", {})
		if far is Dictionary:
			var span: Array = (far as Dictionary).get("radius_m", [])
			if span.size() >= 2:
				size = maxf(size, float(span[1]) * 2.0)
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
	IslandTerrain.build(self, size, _climate)
	IslandTerrain.bake_nav(self)
	build_grid = BuildGrid.new()
	build_grid.name = "BuildGrid"
	build_grid.setup(self)
	add_child(build_grid)
	_camp_pos = _tile_at(float(camp_a[0]), float(camp_a[2]))
	_harbour_pos = _tile_at(float(harbour_a[0]), float(harbour_a[2]))
	if _crater_hint != Vector3.ZERO:
		_crater_pos = _tile_at(_crater_hint.x, _crater_hint.z)
	# The json harbour is a hint: the dock goes on the legal coast pose nearest it (HarbourSite).
	var hint := Vector2(float(harbour_a[0]), float(harbour_a[2])) if def.has("harbour") else Vector2(_camp_hint.x, _camp_hint.z)
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
	IslandScatter.scatter(self, def, terrain, _climate, _tier, size)
	props = IslandProps.build(self)
	_setup_pathing()
	IslandSpawns.spawn_all(self, def)
	if crater_v is Array:
		_crater(_at(float(crater_v[0]), float(crater_v[2])))
	weather.install(self)
	IslandTerrain.drive_focus(self)
	print("[world] island %s nodes=%d creatures=%d spawn_rejected=%d" % [def.get("id", ""), harvest_count, creature_count, spawn_rejected])

func mark_pathing_dirty() -> void:
	if pathing:
		pathing.mark_dirty()

func _process(delta: float) -> void:
	IslandTerrain.drive_focus(self)
	weather.tick(self, delta)

func surface_y(x: float, z: float) -> float:
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

func ring_name(pos: Vector3) -> StringName:
	var r := Vector2(pos.x, pos.z).length()
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

## Dry land above the beach and inside the land radius.
func is_dry(pos: Vector3) -> bool:
	return Vector2(pos.x, pos.z).length() <= land_radius() - 2.0 and surface_y(pos.x, pos.z) >= 0.4

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
	var arr: Variant = snap.get("bare_tiles", [])
	if not arr is Array:
		return
	for row_v in arr:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
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

## Claim a 14x14 plot centred on the tile; returns false when its centre is not dry land or the plot
## would take a tile another player holds.
func claim_at(tile: Vector2i, size: int = 14) -> bool:
	return IslandClaims.claim_at(self, tile, size)

## The plot a claim at `tile` would take (IslandClaims.plot_at).
func claim_plot(tile: Vector2i, size: int = 14) -> Rect2i:
	return IslandClaims.plot_at(tile, size)

## Why a claim at `tile` would be refused, "" when it would be staked (IslandClaims.block_reason).
func claim_block_reason(tile: Vector2i, size: int = 14) -> String:
	return IslandClaims.block_reason(self, tile, size)

## Why a claim at `tile` would not expand the land held here, "" when it would (IslandClaims.expand_reason).
func claim_expand_reason(tile: Vector2i, size: int = 14) -> String:
	return IslandClaims.expand_reason(self, tile, size)

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
