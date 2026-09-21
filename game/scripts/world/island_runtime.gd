extends Node3D
## Generates a private or unstable island: heightmap, nav, harvest, harbour, camp, crater.

const TERRAIN_SHADER: Shader = preload("res://scripts/world/terrain_tiles.gdshader")
const FOLIAGE_SHADER: Shader = preload("res://scripts/world/foliage_sway.gdshader")
const WATER_SHADER: Shader = preload("res://scripts/world/water.gdshader")
const DISC_SHADER: Shader = preload("res://scripts/world/dirt_disc.gdshader")
const TERRAIN_TEX := {
	"grass": "res://assets/terrain/aerial_grass_rock_diff_1k.jpg",
	"dirt": "res://assets/terrain/brown_mud_leaves_01_diff_1k.jpg",
	"sand": "res://assets/terrain/aerial_beach_01_diff_1k.jpg",
	"rock": "res://assets/terrain/rocky_trail_diff_1k.jpg",
}

enum TileType {
	GRASS = 0,
	DRY = 1,
	DIRT = 2,
	SAND = 3,
	SHALLOW = 4,
	ROCK = 5,
	MUD = 6,
	BARE = 7,
	DEEP = 8,
	ASH = 9,
	WET = 10,
}

var harvest_count: int = 0
var creature_count: int = 0
var mm_count: int = 0
var harbour
var cargo
var cargo_basket
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var _size: float = 240.0
var _res: int = 65
var _heights: PackedFloat32Array = PackedFloat32Array()
var raining: bool = false
var _rain_left: float = 0.0
var _rain_cd: float = 40.0
var _wet_area: Area3D
var _rain_fx: GPUParticles3D
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
var _tile_base: PackedByteArray = PackedByteArray()
var _tile_map_image: Image
var _tile_map_tex: ImageTexture
var _terrain_mat: ShaderMaterial
var _foliage_mat: ShaderMaterial
var _sky_mat: ProceduralSkyMaterial
var _palette: Dictionary = {}
var _node_tiles: Dictionary = {}
var _harvest_nodes: Dictionary = {}
var _bare_tiles: Dictionary = {}
var spawn_rejected: int = 0
var build_grid: BuildGrid
var pathing
var _height_tex: ImageTexture
var _water_mat: ShaderMaterial
var _used_tiles: Dictionary = {}
var _tree_discs: MultiMeshInstance3D
var _tree_disc_xforms: Array[Transform3D] = []
var _batches: Array[VegBatch] = []
var claims: Array[Rect2i] = []
var _claim_mesh: MeshInstance3D
var _claim_mat: StandardMaterial3D

## Radius of dry, walkable land: the shore starts falling at 0.36 * size (see _terrain).
func land_radius() -> float:
	return _size * 0.38

## True when a creature may stand at pos: on dry land above the beach and the river,
## inside the land radius and (when strict) at least 25 m from camp and the harbour
## (rules.json landing ring: "nothing spawns within 25 m of camp").
func spawn_ok(pos: Vector3, strict: bool = true) -> bool:
	if _heights.is_empty():
		return true
	if Vector2(pos.x, pos.z).length() > land_radius() - 2.0:
		return false
	if surface_y(pos.x, pos.z) < 0.4:
		return false
	if strict:
		var keep := 25.0
		if Vector2(pos.x - _camp_pos.x, pos.z - _camp_pos.z).length() < keep:
			return false
		if Vector2(pos.x - _harbour_pos.x, pos.z - _harbour_pos.z).length() < keep * 0.6:
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
	_env()
	_sun()
	_terrain(size, _climate)
	build_grid = BuildGrid.new()
	build_grid.name = "BuildGrid"
	build_grid.setup(self)
	add_child(build_grid)
	_camp_pos = _tile_at(float(camp_a[0]), float(camp_a[2]))
	_harbour_pos = _tile_at(float(harbour_a[0]), float(harbour_a[2]))
	if _crater_hint != Vector3.ZERO:
		_crater_pos = _tile_at(_crater_hint.x, _crater_hint.z)
	harbour = (load("res://scripts/world/harbour.gd") as GDScript).new()
	_camp_place(harbour, "Harbour", &"harbour", BuildGrid.tile_of(_harbour_pos) - Vector2i(1, 3))
	_camp(_camp_pos)
	cargo = (load("res://scripts/world/cargo_warp.gd") as GDScript).new()
	_camp_place(cargo, "CargoWarp", &"chest", BuildGrid.tile_of(_tile_at(float(camp_a[0]) + 3.0, float(camp_a[2]))))
	if str(def.get("kind", "")) == "private":
		var PB := load("res://scripts/world/placed_building.gd") as GDScript
		cargo_basket = PB.make(&"basket")
		cargo_basket.is_cargo = true
		cargo_basket.storage = World.cargo_home
		cargo_basket.position = _tile_at(float(harbour_a[0]) + 3.0, float(harbour_a[2]))
		add_child(cargo_basket)
		build_grid.reserve_kind(&"basket", BuildGrid.tile_of(cargo_basket.position), 0)
	_setup_claims(def)
	_scatter(def, terrain, _climate, _tier, size)
	_setup_pathing()
	_creatures(def)
	if crater_v is Array:
		_crater(_at(float(crater_v[0]), float(crater_v[2])))
	_rain_layer()
	_drive_terrain_focus()
	print("[world] island %s nodes=%d creatures=%d spawn_rejected=%d" % [def.get("id", ""), harvest_count, creature_count, spawn_rejected])

func mark_pathing_dirty() -> void:
	if pathing:
		pathing.mark_dirty()

func _env() -> void:
	# The island owns the lighting: every other directional light (main scene, lab kits)
	# is switched off and every other WorldEnvironment is emptied, so day/night works
	# the same in the game and in the labs.
	var root := get_tree().root
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		if l != sun:
			(l as DirectionalLight3D).visible = false
	var envs := root.find_children("*", "WorldEnvironment", true, false)
	for i in envs.size():
		var we := envs[i] as WorldEnvironment
		if i == 0:
			world_env = we
		else:
			we.environment = null
	if world_env:
		if world_env.environment == null:
			world_env.environment = Environment.new()
		_apply_env_setup(world_env.environment)
		return
	world_env = WorldEnvironment.new()
	var e := Environment.new()
	_apply_env_setup(e)
	world_env.environment = e
	add_child(world_env)

func _apply_env_setup(e: Environment) -> void:
	e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.80, 0.86, 0.95)
	e.ambient_light_energy = 0.75
	e.ssao_enabled = false
	e.ssr_enabled = false
	e.glow_enabled = false
	e.fog_enabled = true
	e.fog_density = 0.0022
	e.fog_light_color = Color(0.64, 0.74, 0.83)
	e.fog_sun_scatter = 0.0
	e.fog_height = 0.0
	e.fog_aerial_perspective = 0.2
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = Color(0.20, 0.42, 0.66)
	_sky_mat.sky_horizon_color = Color(0.66, 0.78, 0.92)
	_sky_mat.ground_bottom_color = Color(0.06, 0.08, 0.10)
	_sky_mat.ground_horizon_color = Color(0.24, 0.29, 0.34)
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	e.sky = sky

func _sun() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)

func _process(delta: float) -> void:
	_drive_day()
	_drive_terrain_focus()
	_weather(delta)

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

func _terrain(size: float, climate: String) -> void:
	_size = size
	_res = 129 if size >= 200.0 else 65
	_heights.resize(_res * _res)
	var seed := 25 if climate == "temperate" else 17
	var n0 := FastNoiseLite.new()
	n0.seed = seed
	n0.frequency = 0.012
	var n1 := FastNoiseLite.new()
	n1.seed = seed + 101
	n1.frequency = 0.03
	var n2 := FastNoiseLite.new()
	n2.seed = seed + 211
	n2.frequency = 0.08
	var nshore := FastNoiseLite.new()
	nshore.seed = seed + 307
	nshore.frequency = 0.02
	var rr := RandomNumberGenerator.new()
	rr.seed = int(seed) * 131
	var ridge_ang := rr.randf() * TAU
	_ridge_dir = Vector2(cos(ridge_ang), sin(ridge_ang)).normalized()
	var cell := size / float(_res - 1)
	# Durango ground is flat: gentle undulation only, a low ridge far inland, and a wide
	# gradual shore (dry sand -> wet sand -> shallow -> deep over 20-30 m) whose waterline
	# wanders with noise so it never reads as a ring.
	var shore0 := size * 0.36
	var shore1 := size * 0.47
	for z in _res:
		for x in _res:
			var wx := -size * 0.5 + float(x) * cell
			var wz := -size * 0.5 + float(z) * cell
			var h := 1.1
			h += n0.get_noise_2d(wx, wz) * 0.45
			h += n1.get_noise_2d(wx, wz) * 0.18
			h += n2.get_noise_2d(wx, wz) * 0.06
			var rad := Vector2(wx, wz).length()
			if rad > size * 0.14 and rad < shore0:
				var dir := Vector2(wx, wz).normalized()
				var along := maxf(0.0, dir.dot(_ridge_dir))
				var cross := absf(dir.dot(Vector2(-_ridge_dir.y, _ridge_dir.x)))
				var width := clampf(1.0 - cross / 0.5, 0.0, 1.0)
				var inland := clampf((rad - size * 0.14) / (shore0 - size * 0.14), 0.0, 1.0)
				h += 2.0 * along * width * sin(inland * PI)
			var river_center := sin(wx * 0.018 + float(seed) * 0.13) * (size * 0.085)
			var river := absf(wz - river_center)
			if river < 6.0 and rad > size * 0.16 and rad < size * 0.42:
				var carve := clampf(1.0 - river / 6.0, 0.0, 1.0)
				carve = carve * carve * (3.0 - 2.0 * carve)
				h = lerpf(h, -0.35, carve)
			if _crater_hint != Vector3.ZERO:
				var dc := Vector2(wx - _crater_hint.x, wz - _crater_hint.z).length()
				if dc < 12.0:
					var bowl := pow(clampf(1.0 - dc / 12.0, 0.0, 1.0), 2.0)
					h -= bowl * 1.2
				var rim := clampf(1.0 - absf(dc - 12.0) / 4.0, 0.0, 1.0)
				h += rim * 0.4
			var wander := nshore.get_noise_2d(wx, wz) * (size * 0.03)
			var rs := rad + wander
			if rs > shore0:
				var t := clampf((rs - shore0) / maxf(0.001, shore1 - shore0), 0.0, 1.0)
				var eased := t * t * (3.0 - 2.0 * t)
				h = lerpf(h, -1.4, eased)
			if rs > shore1:
				var t2 := clampf((rs - shore1) / (size * 0.05), 0.0, 1.0)
				h = lerpf(h, -2.6, t2)
			if _camp_hint != Vector3.ZERO:
				var camp_d := Vector2(wx - _camp_hint.x, wz - _camp_hint.z).length()
				if camp_d < 16.0:
					var s := clampf(1.0 - camp_d / 16.0, 0.0, 1.0)
					h = lerpf(h, 1.1, s * 0.6)
			_heights[x + z * _res] = h
	_build_height_texture()
	_build_tile_types(climate)
	_build_terrain_mesh(size, cell, climate)
	_sea(size)
	_river_trigger()
	_nav_bake()

func _build_terrain_mesh(size: float, cell: float, climate: String) -> void:
	_palette = _palette_for(climate)
	_terrain_mat = _terrain_material()
	var body := StaticBody3D.new()
	body.name = "Floor"
	var tiles := 8 if _res >= 129 else 4
	var span := int((_res - 1) / tiles)
	for tz in tiles:
		for tx in tiles:
			var st := SurfaceTool.new()
			var nav_st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			nav_st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_smooth_group(0)
			var x0 := tx * span
			var z0 := tz * span
			var x1 := _res - 1 if tx == tiles - 1 else (tx + 1) * span
			var z1 := _res - 1 if tz == tiles - 1 else (tz + 1) * span
			for z in range(z0, z1):
				for x in range(x0, x1):
					_tri(st, nav_st, size, cell, x, z)
					_tri2(st, nav_st, size, cell, x, z)
			st.generate_normals()
			st.generate_tangents()
			var mi := MeshInstance3D.new()
			mi.name = "TerrainMesh_%d_%d" % [tx, tz]
			mi.mesh = st.commit()
			mi.material_override = _terrain_mat
			mi.extra_cull_margin = 80.0
			body.add_child(mi)
			var nav_mesh := nav_st.commit()
			if nav_mesh:
				var nav_src := MeshInstance3D.new()
				nav_src.name = "TerrainNav_%d_%d" % [tx, tz]
				nav_src.mesh = nav_mesh
				nav_src.visible = false
				body.add_child(nav_src)
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = _res
	hs.map_depth = _res
	hs.map_data = _heights
	cs.shape = hs
	cs.position = Vector3.ZERO
	cs.scale = Vector3(cell, 1, cell)
	body.add_child(cs)
	add_child(body)

func _tri(st: SurfaceTool, nav_st: SurfaceTool, size: float, cell: float, x: int, z: int) -> void:
	var p0 := _vpos(size, cell, x, z)
	var p1 := _vpos(size, cell, x + 1, z)
	var p2 := _vpos(size, cell, x, z + 1)
	_v(st, p0)
	_v(st, p1)
	_v(st, p2)
	_nav_tri(nav_st, p0, p1, p2)

func _tri2(st: SurfaceTool, nav_st: SurfaceTool, size: float, cell: float, x: int, z: int) -> void:
	var p0 := _vpos(size, cell, x + 1, z)
	var p1 := _vpos(size, cell, x + 1, z + 1)
	var p2 := _vpos(size, cell, x, z + 1)
	_v(st, p0)
	_v(st, p1)
	_v(st, p2)
	_nav_tri(nav_st, p0, p1, p2)

func _vpos(size: float, cell: float, x: int, z: int) -> Vector3:
	var wx := -size * 0.5 + float(x) * cell
	var wz := -size * 0.5 + float(z) * cell
	return Vector3(wx, _heights[x + z * _res], wz)

func _v(st: SurfaceTool, p: Vector3) -> void:
	st.set_smooth_group(0)
	st.set_color(_terrain_color(p))
	st.set_uv(Vector2(p.x, p.z) / 6.0)
	st.add_vertex(p)

func _terrain_color(p: Vector3) -> Color:
	var col := Color(1, 1, 1)  # vertex colour is a multiplier on the shader's albedo
	var camp_d := Vector2(p.x - _camp_hint.x, p.z - _camp_hint.z).length()
	if camp_d < 18.0:
		# A warm, trampled clearing frames the opening camp against the surrounding grass.
		# The broad feathered edge reads as terrain variation, not a UI boundary ring.
		var inner := 1.0 - smoothstep(7.0, 18.0, camp_d)
		var path_band := 1.0 - smoothstep(2.0, 5.5, absf(p.x - _camp_hint.x))
		var warmth := maxf(inner * 0.55, path_band * inner * 0.22)
		col = col.lerp(Color(0.88, 0.78, 0.57), warmth)
	var crater_d := Vector2(p.x - _crater_hint.x, p.z - _crater_hint.z).length()
	if _crater_hint != Vector3.ZERO and crater_d < 14.0:
		var bowl := clampf(1.0 - crater_d / 14.0, 0.0, 1.0)
		col = col.lerp(Color(0.55, 0.48, 0.42), bowl * 0.85)
	if _crater_hint != Vector3.ZERO:
		var rim := clampf(1.0 - absf(crater_d - 11.0) / 4.0, 0.0, 1.0)
		if rim > 0.0:
			col = col.lerp(Color(0.66, 0.58, 0.52), rim * 0.65)
	return col

func _tile_color(tile_type: int) -> Color:
	match tile_type:
		TileType.DRY:
			return _palette.get("dry", Color(0.58, 0.56, 0.34))
		TileType.DIRT:
			return _palette.get("dirt", Color(0.40, 0.32, 0.22))
		TileType.SAND:
			return _palette.get("sand", Color(0.79, 0.72, 0.54))
		TileType.WET:
			return Color(0.55, 0.49, 0.38)
		TileType.SHALLOW:
			return Color(0.60, 0.78, 0.84)
		TileType.DEEP:
			return Color(0.22, 0.39, 0.56)
		TileType.ROCK:
			return _palette.get("rock", Color(0.46, 0.45, 0.44))
		TileType.MUD:
			return Color(0.34, 0.27, 0.20)
		TileType.BARE:
			return Color(0.44, 0.33, 0.23)
		TileType.ASH:
			return Color(0.34, 0.33, 0.33)
		_:
			return _palette.get("grass", Color(0.42, 0.62, 0.32))

func _noise_jitter(x: float, z: float) -> float:
	return 0.5 + 0.5 * sin(x * 0.11 + z * 0.07 + sin(z * 0.03))

func _nav_tri(nav_st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	var c := (p0 + p1 + p2) / 3.0
	if c.y < -0.3:
		return
	nav_st.add_vertex(p0)
	nav_st.add_vertex(p1)
	nav_st.add_vertex(p2)

func _sea(size: float) -> void:
	var deep := MeshInstance3D.new()
	var dplane := PlaneMesh.new()
	dplane.size = Vector2(size * 1.8, size * 1.8)
	deep.mesh = dplane
	deep.position.y = -2.6
	deep.extra_cull_margin = 320.0
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.09, 0.19, 0.28, 1.0)
	dmat.roughness = 0.95
	deep.material_override = dmat
	add_child(deep)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size * 1.6, size * 1.6)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	water.mesh = plane
	water.position.y = -0.05
	water.extra_cull_margin = 300.0
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WATER_SHADER
	_water_mat.set_shader_parameter("height_tex", _height_tex)
	_water_mat.set_shader_parameter("noise_tex", _noise_tex())
	_water_mat.set_shader_parameter("map_size", size)
	_water_mat.set_shader_parameter("height_res", float(_res))
	_water_mat.set_shader_parameter("water_y", -0.05)
	water.material_override = _water_mat
	add_child(water)

func _build_height_texture() -> void:
	var img := Image.create(_res, _res, false, Image.FORMAT_RF)
	for z in _res:
		for x in _res:
			img.set_pixel(x, z, Color(_heights[x + z * _res], 0.0, 0.0))
	_height_tex = ImageTexture.create_from_image(img)

func _foam_ring(radius: float, width: float) -> MeshInstance3D:
	var segs := 180
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := float(i) / float(segs) * TAU
		var a1 := float(i + 1) / float(segs) * TAU
		var i0 := Vector3(cos(a0) * radius, -0.05, sin(a0) * radius)
		var i1 := Vector3(cos(a1) * radius, -0.05, sin(a1) * radius)
		var o0 := Vector3(cos(a0) * (radius + width), -0.02, sin(a0) * (radius + width))
		var o1 := Vector3(cos(a1) * (radius + width), -0.02, sin(a1) * (radius + width))
		st.set_color(Color(1, 1, 1, 0.38))
		st.add_vertex(i0)
		st.add_vertex(i1)
		st.add_vertex(o0)
		st.set_color(Color(1, 1, 1, 0.38))
		st.add_vertex(i1)
		st.add_vertex(o1)
		st.add_vertex(o0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.extra_cull_margin = 220.0
	return mi

func _river_trigger() -> void:
	_wet_area = Area3D.new()
	_wet_area.name = "Wet"
	_wet_area.monitoring = true
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_size, 2.0, 10.0)
	cs.shape = box
	cs.position.y = -0.2
	_wet_area.add_child(cs)
	_wet_area.body_entered.connect(func (b: Node) -> void:
		if b is Player:
			(b as Player).in_water = true
	)
	_wet_area.body_exited.connect(func (b: Node) -> void:
		if b is Player:
			(b as Player).in_water = false
	)
	add_child(_wet_area)

func _nav_bake() -> void:
	var nav := NavigationRegion3D.new()
	nav.name = "Nav"
	var nmesh := NavigationMesh.new()
	nmesh.agent_radius = 0.5
	nmesh.agent_max_climb = 1.25
	nmesh.agent_max_slope = 45.0
	nav.navigation_mesh = nmesh
	add_child(nav)
	var floor := get_node_or_null("Floor")
	if floor:
		for c in floor.get_children():
			if c is MeshInstance3D and String(c.name).begins_with("TerrainNav_"):
				var dup: Node = c.duplicate()
				dup.name = String(c.name) + "_nav"
				nav.add_child(dup)
	nav.bake_navigation_mesh(true)

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
func _camp_place(node: Node3D, name: String, kind: StringName, default_cell: Vector2i) -> void:
	node.name = name
	var cell := default_cell
	var rot := 0
	var saved: Variant = World.camp_layout.get(name, null) if World else null
	if saved is Dictionary:
		var cv: Variant = (saved as Dictionary).get("cell", null)
		if cv is Array and (cv as Array).size() >= 2:
			cell = Vector2i(int(cv[0]), int(cv[1]))
		rot = int((saved as Dictionary).get("rot", 0))
	add_child(node)
	node.global_transform = build_grid.placement_transform(kind, cell, rot)
	if node.has_method("set_grid_pose"):
		node.set_grid_pose(cell, rot)
	build_grid.occupy(node, build_grid.cells_for(kind, cell, rot))

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

func _scatter(def: Dictionary, terrain: StringName, climate: String, tier: int, size: float) -> void:
	var clim: Dictionary = Data.world_climates.get(climate, {})
	var families: Array = clim.get("vegetation", ["BirchTree", "Bush", "Grass", "Rock", "Flowers"])
	var counts: Dictionary = {}
	if def.has("terrains") and def["terrains"] is Dictionary:
		counts = def["terrains"].get(str(terrain), {})
	var home := str(def.get("kind", "")) == "private"
	var rng := RandomNumberGenerator.new()
	rng.seed = 17 if home else 25
	_multimesh_family("Grass", int(counts.get("grass", 260 if not home else 140)), size, rng)
	_multimesh_family("Flowers", int(counts.get("flower", 40 if not home else 24)), size, rng)
	# Durango's islands are dense: every family keeps a floor even when the island data is sparse.
	# Denser islands (owner asked for resources everywhere): home floors up 3-4x, unstable up ~1.5x.
	var floors := {"tree": 40 if home else 64, "bush": 36 if home else 44, "rock": 20 if home else 26, "plant": 24 if home else 24, "wild_grass": 48 if home else 60}
	var tree_families: Array[String] = []
	for fam in families:
		var fs := str(fam)
		if fs.begins_with("Grass") or fs == "Flowers":
			continue
		var role := str(Data.nature_families.get(fs, {}).get("role", "node"))
		if role.begins_with("tree"):
			tree_families.append(fs)
	for fam in families:
		var fs := str(fam)
		if fs.begins_with("Grass") or fs == "Flowers":
			continue
		var role := str(Data.nature_families.get(fs, {}).get("role", "node"))
		var n := 0
		var fallback := &"wood_log"
		var tool := &"axe"
		var col := Color(0.35, 0.22, 0.1)
		match role:
			"tree", "tree_dead":
				n = maxi(int(counts.get("tree", 0)), int(floors["tree"])) / maxi(1, tree_families.size())
			"bush":
				n = maxi(int(counts.get("bush", 0)), int(floors["bush"]))
				fallback = &"fibre_stalk"
				tool = &"knife"
				col = Color(0.2, 0.45, 0.18)
			"rock":
				n = maxi(int(counts.get("rock", 0)), int(floors["rock"]))
				fallback = &"stone"
				tool = &"pick"
				col = Color(0.5, 0.5, 0.48)
			"prop":
				n = 0
			_:
				n = int(floors["wild_grass"]) if fs == "WildGrass" else int(floors["plant"])
				fallback = &"dry_grass" if fs == "WildGrass" else &"herb_leaf"
				tool = &"none"
				col = Color(0.55, 0.62, 0.3) if fs == "WildGrass" else Color(0.35, 0.55, 0.25)
		if n <= 0:
			continue
		harvest_count += _plant_family(fs, role, n, fallback, tool, climate, tier, size, rng, col)
	_scatter_special_tiles(climate, tier, rng)
	for b in _batches:
		b.commit()
	_commit_tree_discs()

## Plants a family in clumps of 3-6 (thickets and clearings, like the reference), on free
## dry tiles, avoiding the camp. Tree clumps near the shore become palms where the climate allows.
func _plant_family(family: String, role: String, n: int, fallback_id: StringName, tool: StringName, climate: String, tier: int, size: float, rng: RandomNumberGenerator, color: Color) -> int:
	var placed := 0
	var half := size * 0.40
	var tries := 0
	var palms := family != "PalmTree" and role.begins_with("tree") and not (climate in ["tundra", "volcanic"]) and _models("PalmTree").size() > 0
	while placed < n and tries < n * 30:
		tries += 1
		var cx := rng.randf_range(-half, half)
		var cz := rng.randf_range(-half, half)
		var centre := Vector3(cx, surface_y(cx, cz), cz)
		if not spawn_ok(centre, false):
			continue
		if Vector2(cx - _camp_hint.x, cz - _camp_hint.z).length() < 9.0:
			continue
		var fam := family
		if palms and Vector2(cx, cz).length() > land_radius() * 0.70:
			fam = "PalmTree"
		var clump := rng.randi_range(3, 6) if (role.begins_with("tree") or role == "bush") else rng.randi_range(1, 3)
		var spread := 3.2 if role.begins_with("tree") else 2.4
		for k in clump:
			if placed >= n:
				break
			var ox := cx + rng.randf_range(-spread, spread)
			var oz := cz + rng.randf_range(-spread, spread)
			var pos := Vector3(ox, surface_y(ox, oz), oz)
			if not spawn_ok(pos, false):
				continue
			var tile := BuildGrid.tile_of(pos)
			if _used_tiles.has(tile):
				continue
			placed += _plant_at(fam, "%s_%s_%d" % [fam.to_lower(), role, placed], pos, fallback_id, tool, climate, material_level(pos, tier), color)
	return placed

func _plant_at(family: String, role: String, pos: Vector3, fallback_id: StringName, tool: StringName, climate: String, level: int, color: Color) -> int:
	var tile := BuildGrid.tile_of(pos)
	pos = BuildGrid.tile_centre(tile, self)
	var models: PackedStringArray = _models(family)
	var harvest: Dictionary = _harvest(family)
	var yield_id := fallback_id
	var amin := 1
	var amax := 1
	if not harvest.is_empty():
		for k in harvest.keys():
			var cand := StringName(str(k))
			if Data.item(cand):
				yield_id = cand
				var pair: Variant = harvest[k]
				if pair is Array and pair.size() >= 2:
					amin = int(pair[0])
					amax = int(pair[1])
				break
	var tool_s := tool
	var tjson := _family_tool(family)
	if tjson != &"":
		tool_s = tjson
	if not Data.item(yield_id):
		yield_id = fallback_id
	var node: HarvestNode = preload("res://scenes/world/harvest_node.tscn").instantiate()
	node.position = pos
	add_child(node)
	var attrs := {"climate": climate, "level": level}
	var role_s := str(Data.nature_families.get(family, {}).get("role", ""))
	var pool_max := _family_pool_max(family, role_s)
	var regen_s := _family_regen_seconds(family, role_s)
	node.setup(
		StringName(role),
		yield_id,
		amin,
		amax,
		attrs,
		tool_s,
		color,
		1.2,
		regen_s,
		family,
		role_s.begins_with("tree"),
		pool_max
	)
	node.depleted_tile.connect(_on_tile_bare)
	node.regrown_tile.connect(_on_tile_regrown)
	_node_tiles[str(node.node_id)] = {"tile": tile, "base": _tile_type_at_world(pos.x, pos.z)}
	_harvest_nodes[str(node.node_id)] = node
	_used_tiles[tile] = true
	if models.size() > 0:
		var model := models[(harvest_count + _used_tiles.size()) % models.size()]
		if model == "":
			model = models[0]
		var path := "res://assets/nature/%s.glb" % model
		if ResourceLoader.exists(path):
			_attach_batched(node, path, role_s, family, pos)
		else:
			print("[world] missing nature %s" % path)
	return 1

## Reference look: palms 8-11 m, trees 7-10 m, bushes 1.5-2.2 m, rocks knee-high.
func _target_height(role: String, family: String) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash(family) + _used_tiles.size() * 7919
	if family == "PalmTree":
		return r.randf_range(8.0, 11.0)
	if role.begins_with("tree"):
		return r.randf_range(7.0, 10.0)
	if role == "bush":
		return r.randf_range(1.5, 2.2)
	if role == "rock":
		return r.randf_range(0.7, 1.3)
	if family == "tree_stump":
		return 0.7
	return r.randf_range(0.6, 1.0)

func _attach_batched(node: HarvestNode, path: String, role: String, family: String, pos: Vector3) -> void:
	var batch := VegBatch.get_for(self, path)
	if batch == null:
		node.set_visual(path)
		return
	if not _batches.has(batch):
		_batches.append(batch)
	var h := VegBatch.mesh_height(path)
	var scale := _target_height(role, family) / h
	var yaw := float(hash(str(pos)) % 628) / 100.0
	var basis := Basis.IDENTITY.rotated(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
	var idx := batch.add(Transform3D(basis, pos))
	node.set_batched_visual(batch, idx)
	if role.begins_with("tree") or family == "tree_stump":
		_tree_disc_xforms.append(Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.08, 0)))

func _commit_tree_discs() -> void:
	if _tree_disc_xforms.is_empty():
		return
	var PV := load("res://scripts/world/prop_visuals.gd") as GDScript
	_tree_discs = MultiMeshInstance3D.new()
	_tree_discs.name = "TreeDiscs"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = PV.make_disc_mesh(0.9)
	mm.instance_count = _tree_disc_xforms.size()
	for i in _tree_disc_xforms.size():
		mm.set_instance_transform(i, _tree_disc_xforms[i])
	_tree_discs.multimesh = mm
	_tree_discs.material_override = PV.disc_material(0.9, Color(0.66, 0.52, 0.38))
	_tree_discs.visibility_range_end = 60.0
	_tree_discs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tree_discs)

func _family_pool_max(family: String, role: String) -> int:
	var row: Dictionary = Data.nature_families.get(family, {})
	var from_manifest := int(row.get("pool", 0))
	if from_manifest > 0:
		return from_manifest
	# ASSUMPTION: when pool is missing, trees/rocks start at 30 units and bushes/plants at 12.
	if role.begins_with("tree") or role == "rock":
		return 30
	return 12

func _family_regen_seconds(family: String, role: String) -> float:
	if family == "mud" or family == "clay":
		# ASSUMPTION: fast regrowth for river-bed resources.
		return 60.0
	if family == "berry_bush" or role == "bush":
		# ASSUMPTION: bush-type nodes regrow in 90s.
		return 90.0
	if role.begins_with("tree") or family == "tree_stump":
		# ASSUMPTION: tree resources regrow in 240s.
		return 240.0
	return 120.0

func _multimesh_family(family: String, n: int, size: float, rng: RandomNumberGenerator) -> void:
	var models := _models(family)
	if models.is_empty() or n <= 0:
		return
	var path := "res://assets/nature/%s.glb" % models[0]
	if not ResourceLoader.exists(path):
		print("[world] missing nature %s" % path)
		return
	var packed := load(path)
	var inst: Node = packed.instantiate() if packed is PackedScene else null
	var src_mesh: Mesh
	if inst:
		src_mesh = _first_mesh(inst)
		inst.queue_free()
	if src_mesh == null:
		return
	var xforms: Array[Transform3D] = []
	var half := size * 0.42
	for i in n:
		var ox := rng.randf_range(-half, half)
		var oz := rng.randf_range(-half, half)
		var y := surface_y(ox, oz)
		if not spawn_ok(Vector3(ox, y, oz), false):
			continue
		if (family == "Grass" or family == "Flowers") and _slope_deg(ox, oz) > 35.0:
			continue
		var t := Transform3D.IDENTITY
		t.origin = Vector3(ox, y, oz)
		t.basis = _basis_from_normal(_normal_at(ox, oz), rng.randf() * TAU)
		xforms.append(t)
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = src_mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 48.0
	if family == "Grass" or family == "Flowers":
		if _foliage_mat == null:
			_foliage_mat = ShaderMaterial.new()
			_foliage_mat.shader = FOLIAGE_SHADER
		mmi.material_override = _foliage_mat
	add_child(mmi)
	mm_count += 1

func _creatures(def: Dictionary) -> void:
	var cap := Game.max_creatures_per_island
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for row in def.get("creatures", []):
		if not row is Dictionary:
			continue
		if creature_count >= cap:
			break
		var placed := Spawner.new()
		placed.species = StringName(str(row.get("species", "velociraptor")))
		placed.count = mini(int(row.get("count", 1)), cap - creature_count)
		placed.as_pack = bool(row.get("pack", true))
		var at: Array = row.get("at", [10, 0, 0])
		var want := _at(float(at[0]), float(at[2]))
		var fixed := _nearest_valid(want)
		if fixed.is_empty():
			spawn_rejected += 1
			print("[world] no dry land for %s at %s; skipped" % [placed.species, want])
			placed.queue_free()
			continue
		placed.position = fixed["pos"]
		add_child(placed)
		var made0 := placed.spawn_now()
		_apply_creature_level_override(made0)
		creature_count += made0.size()
	var rings: Dictionary = Data.world_rules.get("rings", {})
	var spawns: Variant = def.get("spawns", {})
	if spawns is Dictionary:
		for ring_id in spawns:
			var rows: Variant = spawns[ring_id]
			if not rows is Array:
				continue
			var span: Array = rings.get(str(ring_id), {}).get("radius_m", [40, 80])
			for row in rows:
				if not row is Dictionary:
					continue
				var groups := int(row.get("groups", 1))
				var chance := float(row.get("chance", 1.0))
				for _g in groups:
					if creature_count >= cap:
						return
					if chance < 1.0 and rng.randf() > chance:
						continue
					var r0 := float(span[0]) if span.size() > 0 else 40.0
					var r1 := float(span[1]) if span.size() > 1 else r0 + 20.0
					# rules.json rings are written for a 240 m land radius; a 160 m home island
					# has 64 m of land, so clamp the band to what exists instead of spawning at sea.
					var land := land_radius() - 4.0
					r1 = minf(r1, land)
					r0 = minf(r0, r1 - 8.0)
					if r1 <= r0 + 4.0:
						r1 = r0 + 8.0
					var pos := _ring_point(rng, r0, r1)
					if pos.is_empty():
						spawn_rejected += 1
						print("[world] no valid spawn for %s in ring %s (r %.0f-%.0f); skipped" % [
							row.get("species", "?"), ring_id, r0, r1])
						continue
					var sp := Spawner.new()
					sp.species = StringName(str(row.get("species", "velociraptor")))
					sp.count = mini(int(row.get("count", 1)), cap - creature_count)
					sp.as_pack = sp.count > 1
					sp.position = pos["pos"]
					add_child(sp)
					var made := sp.spawn_now()
					_apply_creature_level_override(made)
					creature_count += made.size()

func _apply_creature_level_override(creatures: Array[Creature]) -> void:
	if _level_override <= 0:
		return
	for creature in creatures:
		creature.level = _level_override

## Up to 40 draws in the band [r0, r1]; returns {"pos": Vector3} or {} when the band has no dry land.
func _ring_point(rng: RandomNumberGenerator, r0: float, r1: float) -> Dictionary:
	for _try in 40:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(r0 + 2.0, maxf(r0 + 2.0, r1 - 2.0))
		var pos := Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		pos.y = surface_y(pos.x, pos.z) + 0.3
		if spawn_ok(pos):
			return {"pos": pos}
	return {}

## Walk a fixed spawn point toward the island centre until it sits on dry land.
func _nearest_valid(want: Vector3) -> Dictionary:
	var p := want
	for _step in 12:
		p.y = surface_y(p.x, p.z) + 0.3
		if spawn_ok(p, false):
			return {"pos": p}
		p.x *= 0.9
		p.z *= 0.9
	return {}

func _normal_at(x: float, z: float) -> Vector3:
	var d := 0.75
	var h0 := surface_y(x - d, z)
	var h1 := surface_y(x + d, z)
	var h2 := surface_y(x, z - d)
	var h3 := surface_y(x, z + d)
	return Vector3(h0 - h1, 2.0 * d, h2 - h3).normalized()

func _slope_deg(x: float, z: float) -> float:
	var d := 0.75
	var dx := (surface_y(x + d, z) - surface_y(x - d, z)) / (2.0 * d)
	var dz := (surface_y(x, z + d) - surface_y(x, z - d)) / (2.0 * d)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz)))

func _basis_from_normal(up: Vector3, yaw: float) -> Basis:
	var n := up.normalized()
	var t := n.cross(Vector3.FORWARD)
	if t.length_squared() < 0.001:
		t = n.cross(Vector3.RIGHT)
	t = t.normalized()
	var b := t.cross(n).normalized()
	var basis := Basis(t, n, b)
	return basis.rotated(n, yaw)

func _models(family: String) -> PackedStringArray:
	var man: Dictionary = Data.nature_families.get(family, {})
	var out := PackedStringArray()
	for m in man.get("models", []):
		out.append(str(m))
	return out

func _harvest(family: String) -> Dictionary:
	var man: Dictionary = Data.nature_families.get(family, {})
	var h: Variant = man.get("harvest", {})
	return h if h is Dictionary else {}

func _family_tool(family: String) -> StringName:
	var man: Dictionary = Data.nature_families.get(family, {})
	var t: Variant = man.get("tool_class", null)
	if t == null:
		return &""
	var s := str(t)
	if s == "" or s == "<null>" or s == "null":
		return &"none"
	return StringName(s)

func _first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		return (n as MeshInstance3D).mesh
	for c in n.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null

func _reserve_box(center: Vector3, dims: Vector2i, tag: StringName) -> void:
	if build_grid == null:
		return
	var start := Vector2i(
		floori(center.x - float(dims.x) * 0.5),
		floori(center.z - float(dims.y) * 0.5)
	)
	var cells: Array[Vector2i] = []
	for z in dims.y:
		for x in dims.x:
			cells.append(start + Vector2i(x, z))
	build_grid.reserve_cells(cells, tag)

func _drive_day() -> void:
	if sun == null:
		return
	var tod := Game.time_of_day
	var from_noon := absf(tod - 0.5) * 2.0
	sun.rotation_degrees = Vector3(lerpf(-62.0, 12.0, from_noon), 30.0, 0.0)
	var night_n := smoothstep(0.35, 1.0, from_noon)
	# Real night (reference: dark ground, the fire and the lantern carry the scene).
	sun.light_energy = lerpf(1.3, 0.03, night_n)
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(0.55, 0.62, 0.85), night_n)
	if world_env and world_env.environment:
		world_env.environment.ambient_light_energy = lerpf(0.75, 0.10, night_n)
		world_env.environment.ambient_light_color = Color(0.80, 0.86, 0.95).lerp(Color(0.35, 0.42, 0.70), night_n)
		world_env.environment.fog_density = lerpf(0.0022, 0.0044, night_n)
		if _sky_mat:
			_sky_mat.sky_top_color = Color(0.20, 0.42, 0.66).lerp(Color(0.04, 0.08, 0.16), night_n)
			_sky_mat.sky_horizon_color = Color(0.66, 0.78, 0.92).lerp(Color(0.18, 0.22, 0.31), night_n)
			_sky_mat.ground_horizon_color = Color(0.24, 0.29, 0.34).lerp(Color(0.08, 0.10, 0.12), night_n)

func _rain_layer() -> void:
	_rain_fx = GPUParticles3D.new()
	_rain_fx.emitting = false
	_rain_fx.amount = 400
	_rain_fx.lifetime = 0.9
	_rain_fx.visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 20, 80))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 4.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -14, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(18, 0.2, 18)
	mat.color = Color(0.65, 0.75, 0.9, 0.7)
	_rain_fx.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.03
	draw.height = 0.12
	_rain_fx.draw_pass_1 = draw
	add_child(_rain_fx)

func _weather(delta: float) -> void:
	_rain_cd -= delta
	var p := get_tree().get_first_node_in_group("player") as Player
	if raining:
		_rain_left -= delta
		if p:
			p.vitals.drink(delta * 2.0)  # rain refills thirst 2/s while it falls
			p.statuses.apply(&"wet", null)
		if _rain_fx:
			if p:
				_rain_fx.global_position = p.global_position + Vector3(0, 10, 0)
			_rain_fx.emitting = true
		if _rain_left <= 0.0:
			raining = false
			_rain_cd = randf_range(50.0, 90.0)
			if _rain_fx:
				_rain_fx.emitting = false
	elif _rain_cd <= 0.0:
		raining = true
		_rain_left = 18.0
		print("[world] rain")
	if p:
		p.tick_climate_fatigue(delta, _climate)

func _palette_for(climate: String) -> Dictionary:
	return ClimatePalette.resolve(Data.world_climates.get(climate, {}))

func _build_tile_types(climate: String) -> void:
	_tile_span = maxi(1, int(round(_size)))
	tile_types.resize(_tile_span * _tile_span)
	_tile_base.resize(_tile_span * _tile_span)
	_tile_map_image = Image.create(_tile_span, _tile_span, false, Image.FORMAT_R8)
	_tile_map_image.fill(Color.BLACK)
	var has_ash := _climate_has_material(climate, "ash")
	for z in _tile_span:
		for x in _tile_span:
			var wx := -_size * 0.5 + float(x) + 0.5
			var wz := -_size * 0.5 + float(z) + 0.5
			var h := surface_y(wx, wz)
			var slope := _slope_deg(wx, wz)
			var rad := Vector2(wx, wz).length()
			var t := TileType.GRASS
			if h < -0.6:
				t = TileType.DEEP
			elif h < -0.05:
				t = TileType.SHALLOW
			elif h < 0.15:
				t = TileType.WET
			elif h < 0.45 or rad > land_radius() + 2.0:
				t = TileType.SAND
			elif slope > 40.0 or h > 5.5:
				t = TileType.ROCK
			elif slope > 28.0:
				t = TileType.DRY
			if has_ash and h > 4.8 and t == TileType.ROCK:
				t = TileType.ASH
			var river_center := sin(wx * 0.018 + float(25 if climate == "temperate" else 17) * 0.13) * (_size * 0.085)
			var river := absf(wz - river_center)
			if river < 2.4 and h > -0.5 and h < 0.4:
				t = TileType.MUD
			var cdist := Vector2(wx - _crater_hint.x, wz - _crater_hint.z).length()
			if _crater_hint != Vector3.ZERO and cdist < 8.5 and h > -0.2:
				t = TileType.DIRT
			var idx := x + z * _tile_span
			tile_types[idx] = t
			_tile_base[idx] = t
			_tile_map_image.set_pixel(x, z, Color(float(t) / 255.0, 0.0, 0.0))
	_tile_map_tex = ImageTexture.create_from_image(_tile_map_image)

func _terrain_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter("map_size", _size)
	m.set_shader_parameter("grid_enabled", 1.0 if Game.show_grid else 0.0)
	m.set_shader_parameter("tile_map_tex", _tile_map_tex)
	m.set_shader_parameter("grass_tex", _tex_or_fallback(TERRAIN_TEX["grass"], Color(0.45, 0.68, 0.38)))
	m.set_shader_parameter("dirt_tex", _tex_or_fallback(TERRAIN_TEX["dirt"], Color(0.44, 0.34, 0.24)))
	m.set_shader_parameter("sand_tex", _tex_or_fallback(TERRAIN_TEX["sand"], Color(0.82, 0.75, 0.58)))
	m.set_shader_parameter("rock_tex", _tex_or_fallback(TERRAIN_TEX["rock"], Color(0.48, 0.47, 0.45)))
	m.set_shader_parameter("noise_tex", _noise_tex())
	m.set_shader_parameter("focus_pos", Vector3.ZERO)
	m.set_shader_parameter("tint_grass", _c3(_tile_color(TileType.GRASS)))
	m.set_shader_parameter("tint_dry", _c3(_tile_color(TileType.DRY)))
	m.set_shader_parameter("tint_dirt", _c3(_tile_color(TileType.DIRT)))
	m.set_shader_parameter("tint_sand", _c3(_tile_color(TileType.SAND)))
	m.set_shader_parameter("tint_shallow", _c3(_tile_color(TileType.SHALLOW)))
	m.set_shader_parameter("tint_wet", _c3(_tile_color(TileType.WET)))
	m.set_shader_parameter("tint_rock", _c3(_tile_color(TileType.ROCK)))
	m.set_shader_parameter("tint_mud", _c3(_tile_color(TileType.MUD)))
	m.set_shader_parameter("tint_bare", _c3(_tile_color(TileType.BARE)))
	m.set_shader_parameter("tint_deep", _c3(_tile_color(TileType.DEEP)))
	m.set_shader_parameter("tint_ash", _c3(_tile_color(TileType.ASH)))
	return m

func _c3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)

func _noise_tex() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = 4121
	n.frequency = 0.09
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	return t

func _tex_or_fallback(path: String, color: Color) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _tile_idx(x: int, z: int) -> int:
	return x + z * _tile_span

func _tile_type_at_world(x: float, z: float) -> int:
	if tile_types.is_empty():
		return TileType.GRASS
	var tx := clampi(int(floor(x + _size * 0.5)), 0, _tile_span - 1)
	var tz := clampi(int(floor(z + _size * 0.5)), 0, _tile_span - 1)
	return int(tile_types[_tile_idx(tx, tz)])

func _set_tile_type(tile: Vector2i, tile_type: int) -> void:
	if tile_types.is_empty():
		return
	var tx := clampi(tile.x + int(_size * 0.5), 0, _tile_span - 1)
	var tz := clampi(tile.y + int(_size * 0.5), 0, _tile_span - 1)
	var idx := _tile_idx(tx, tz)
	tile_types[idx] = tile_type
	if _tile_map_image:
		_tile_map_image.set_pixel(tx, tz, Color(float(tile_type) / 255.0, 0.0, 0.0))
		if _tile_map_tex:
			_tile_map_tex.update(_tile_map_image)

func _drive_terrain_focus() -> void:
	if _terrain_mat == null:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		_terrain_mat.set_shader_parameter("focus_pos", p.global_position)
	_terrain_mat.set_shader_parameter("grid_enabled", 1.0 if Game.show_grid else 0.0)

func _climate_has_material(climate: String, item_id: String) -> bool:
	var row: Dictionary = Data.world_climates.get(climate, {})
	var arr: Array = row.get("materials", [])
	for m in arr:
		if m is Dictionary and str((m as Dictionary).get("id", "")) == item_id:
			return true
	return false

func _scatter_special_tiles(climate: String, tier: int, rng: RandomNumberGenerator) -> void:
	_spawn_special_family("mud", 3, [TileType.MUD, TileType.SAND], -0.2, 0.55, &"mud", &"none", climate, tier, Color(0.35, 0.27, 0.20), rng)
	_spawn_special_family("clay", 2, [TileType.MUD, TileType.DIRT], -0.1, 0.9, &"clay", &"pick", climate, tier, Color(0.44, 0.30, 0.22), rng)
	_spawn_special_family("berry_bush", 3, [TileType.GRASS, TileType.DRY], 0.25, 6.0, &"berry", &"none", climate, tier, Color(0.58, 0.24, 0.24), rng)
	_spawn_special_family("tree_stump", 1, [TileType.GRASS, TileType.DRY], 0.25, 6.5, &"wood_log", &"axe", climate, tier, Color(0.41, 0.27, 0.19), rng)

func _spawn_special_family(family: String, count: int, tile_kinds: Array, min_h: float, max_h: float, fallback_id: StringName, tool: StringName, climate: String, tier: int, tint: Color, rng: RandomNumberGenerator) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 120:
		tries += 1
		var tx := rng.randi_range(0, _tile_span - 1)
		var tz := rng.randi_range(0, _tile_span - 1)
		var idx := _tile_idx(tx, tz)
		var tile_t := int(tile_types[idx])
		if not tile_kinds.has(tile_t):
			continue
		var wx := -_size * 0.5 + float(tx) + 0.5
		var wz := -_size * 0.5 + float(tz) + 0.5
		var h := surface_y(wx, wz)
		if h < min_h or h > max_h:
			continue
		var pos := Vector3(wx, h, wz)
		if family != "mud" and family != "clay" and not spawn_ok(pos, false):
			continue
		var uid := "%s_tile_%d" % [family, placed]
		harvest_count += _plant_at(family, uid, pos, fallback_id, tool, climate, material_level(pos, tier), tint)
		placed += 1

func _on_tile_bare(node: HarvestNode, tile: Vector2i) -> void:
	if node == null:
		return
	var key := "%d:%d" % [tile.x, tile.y]
	var row: Dictionary = _node_tiles.get(str(node.node_id), {})
	var base_type := int(row.get("base", TileType.GRASS))
	_bare_tiles[key] = {
		"tile": [tile.x, tile.y],
		"base": base_type,
		"node_id": str(node.node_id),
	}
	_set_tile_type(tile, TileType.BARE)
	mark_pathing_dirty()
	print("[world] tile bare (%d,%d)" % [tile.x, tile.y])

func _on_tile_regrown(node: HarvestNode, tile: Vector2i) -> void:
	if node == null:
		return
	var key := "%d:%d" % [tile.x, tile.y]
	var row: Dictionary = _bare_tiles.get(key, {})
	var base_type := int(row.get("base", TileType.GRASS))
	_set_tile_type(tile, base_type)
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
			"base": int(row.get("base", TileType.GRASS)),
			"node_id": node_id,
			"regen_left": left,
		})
	return {"bare_tiles": arr}

func apply_harvest_tile_snapshot(snap: Dictionary) -> void:
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
			"base": int(row.get("base", TileType.GRASS)),
			"node_id": str(row.get("node_id", "")),
		}
		_set_tile_type(tile, TileType.BARE)

# ---------------------------------------------------------------- land claims (M8d Part B)

## Home: the camp plot (14x14 tiles) is claimed at creation plus whatever was saved.
## Unstable: whatever the player staked this visit. Buildings only go on claimed tiles.
func _setup_claims(def: Dictionary) -> void:
	claims.clear()
	var camp_tile := BuildGrid.tile_of(_camp_pos)
	var saved: Array = World.claims_for_current()
	if str(def.get("kind", "")) == "private":
		var base := Rect2i(camp_tile - Vector2i(7, 7), Vector2i(14, 14))
		claims.append(base)
		for r in saved:
			if r is Array and (r as Array).size() >= 4:
				claims.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		if saved.is_empty():
			World.home_claims = [[base.position.x, base.position.y, base.size.x, base.size.y]]
	else:
		# ASSUMPTION: the camp landing spot is always buildable on unstable islands (tents, pens).
		claims.append(Rect2i(camp_tile - Vector2i(7, 7), Vector2i(14, 14)))
		for r in saved:
			if r is Array and (r as Array).size() >= 4:
				claims.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	_rebuild_claim_mesh()

func is_claimed(tile: Vector2i) -> bool:
	for r in claims:
		if r.has_point(tile):
			return true
	return false

## Claim a 14x14 plot centred on the tile; returns false when it overlaps water or an existing claim centre.
func claim_at(tile: Vector2i, size: int = 14) -> bool:
	var rect := Rect2i(tile - Vector2i(size / 2, size / 2), Vector2i(size, size))
	var centre := BuildGrid.tile_centre(tile, self)
	if not spawn_ok(centre, false):
		return false
	claims.append(rect)
	var row := [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	if World.is_home():
		World.home_claims.append(row)
	else:
		World.unstable_claims.append(row)
	_rebuild_claim_mesh()
	print("[world] claimed %dx%d at (%d,%d)" % [size, size, tile.x, tile.y])
	return true

func _rebuild_claim_mesh() -> void:
	if _claim_mesh == null:
		_claim_mesh = MeshInstance3D.new()
		_claim_mesh.name = "ClaimBoundary"
		_claim_mat = StandardMaterial3D.new()
		_claim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_claim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Claims should quietly mark ownership, not dominate the camp as a cyan debug ring.
		_claim_mat.albedo_color = Color(0.72, 0.74, 0.58, 0.30)
		_claim_mat.vertex_color_use_as_albedo = false
		_claim_mesh.material_override = _claim_mat
		_claim_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_claim_mesh.extra_cull_margin = 200.0
		add_child(_claim_mesh)
	var im := ImmediateMesh.new()
	var any := false
	for r in claims:
		var x0 := float(r.position.x)
		var z0 := float(r.position.y)
		var x1 := float(r.position.x + r.size.x)
		var z1 := float(r.position.y + r.size.y)
		var corners := [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			var len := a.distance_to(b)
			var dash := 0.28
			var gap := 0.72
			var t := 0.0
			while t < len:
				var t2 := minf(len, t + dash)
				var pa := a.lerp(b, t / len)
				var pb := a.lerp(b, t2 / len)
				if not any:
					im.surface_begin(Mesh.PRIMITIVE_LINES)
					any = true
				im.surface_add_vertex(Vector3(pa.x, surface_y(pa.x, pa.y) + 0.06, pa.y))
				im.surface_add_vertex(Vector3(pb.x, surface_y(pb.x, pb.y) + 0.06, pb.y))
				t += dash + gap
	if any:
		im.surface_end()
	_claim_mesh.mesh = im
