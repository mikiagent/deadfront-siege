class_name IslandTerrain
extends RefCounted
## Island ground: heightmap, terrain mesh and collision, sea, nav bake and the
## per-tile type map. Static helpers over IslandRuntime state, so the runtime's public fields
## (tile_types, _size, _tile_span...) stay where map, HUD and save code already read them.

const TERRAIN_SHADER: Shader = preload("res://scripts/world/terrain_tiles.gdshader")
const WATER_SHADER: Shader = preload("res://scripts/world/water.gdshader")
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
	## Cliff faces (escarpment risers, the mesa rim): impassable, never scattered on, so the props
	## job can dress them with cliff rocks. Painted as grass by _shader_id: the terrain shader
	## already renders steep ground as rock from the vertex normal.
	CLIFF = 11,
}

## Builds the ground from IslandShape: heightmap, effective radius, river distance and slope
## grids, then the height texture, the tile map, the mesh and the sea. `shape` is the shared
## generator instance so is_dry, the tile loop and the scatter all read one coastline.
static func build(rt: IslandRuntime, size: float, climate: String, shape: IslandShape) -> void:
	rt._size = size
	# 160 divides into the 8 mesh chunks; cells 2.3-2.9 m so hills and cliffs do not facet badly.
	rt._res = 161
	rt._shape = shape
	rt._rad = shape.rads
	rt._river_d = shape.river_d
	rt._vslope = shape.vslope
	rt._heights = shape.heights
	rt._ridge_dir = shape.ridge_dir
	_build_height_texture(rt)
	_build_tile_types(rt, climate)
	_build_mesh(rt, size, size / float(rt._res - 1), climate)
	_sea(rt, size)

static func _build_mesh(rt: IslandRuntime, size: float, cell: float, climate: String) -> void:
	rt._palette = _palette_for(climate)
	rt._terrain_mat = _terrain_material(rt)
	var body := StaticBody3D.new()
	body.name = "Floor"
	var tiles := 8 if rt._res >= 129 else 4
	var span := int((rt._res - 1) / tiles)
	for tz in tiles:
		for tx in tiles:
			var st := SurfaceTool.new()
			var nav_st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			nav_st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_smooth_group(0)
			var x0 := tx * span
			var z0 := tz * span
			var x1 := rt._res - 1 if tx == tiles - 1 else (tx + 1) * span
			var z1 := rt._res - 1 if tz == tiles - 1 else (tz + 1) * span
			for z in range(z0, z1):
				for x in range(x0, x1):
					_tri(rt, st, nav_st, size, cell, x, z)
					_tri2(rt, st, nav_st, size, cell, x, z)
			st.generate_normals()
			st.generate_tangents()
			var mi := MeshInstance3D.new()
			mi.name = "TerrainMesh_%d_%d" % [tx, tz]
			mi.mesh = st.commit()
			mi.material_override = rt._terrain_mat
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
	hs.map_width = rt._res
	hs.map_depth = rt._res
	hs.map_data = rt._heights
	cs.shape = hs
	cs.position = Vector3.ZERO
	cs.scale = Vector3(cell, 1, cell)
	body.add_child(cs)
	rt.add_child(body)

static func _tri(rt: IslandRuntime, st: SurfaceTool, nav_st: SurfaceTool, size: float, cell: float, x: int, z: int) -> void:
	var p0 := _vpos(rt, size, cell, x, z)
	var p1 := _vpos(rt, size, cell, x + 1, z)
	var p2 := _vpos(rt, size, cell, x, z + 1)
	_v(rt, st, p0)
	_v(rt, st, p1)
	_v(rt, st, p2)
	_nav_tri(nav_st, p0, p1, p2)

static func _tri2(rt: IslandRuntime, st: SurfaceTool, nav_st: SurfaceTool, size: float, cell: float, x: int, z: int) -> void:
	var p0 := _vpos(rt, size, cell, x + 1, z)
	var p1 := _vpos(rt, size, cell, x + 1, z + 1)
	var p2 := _vpos(rt, size, cell, x, z + 1)
	_v(rt, st, p0)
	_v(rt, st, p1)
	_v(rt, st, p2)
	_nav_tri(nav_st, p0, p1, p2)

static func _vpos(rt: IslandRuntime, size: float, cell: float, x: int, z: int) -> Vector3:
	var wx := -size * 0.5 + float(x) * cell
	var wz := -size * 0.5 + float(z) * cell
	return Vector3(wx, rt._heights[x + z * rt._res], wz)

static func _v(rt: IslandRuntime, st: SurfaceTool, p: Vector3) -> void:
	st.set_smooth_group(0)
	st.set_color(_terrain_color(rt, p))
	st.set_uv(Vector2(p.x, p.z) / 6.0)
	st.add_vertex(p)

static func _terrain_color(rt: IslandRuntime, p: Vector3) -> Color:
	var col := Color(1, 1, 1)  # vertex colour is a multiplier on the shader's albedo
	var camp_d := Vector2(p.x - rt._camp_hint.x, p.z - rt._camp_hint.z).length()
	if camp_d < 18.0:
		# A warm, trampled clearing frames the opening camp against the surrounding grass.
		# The broad feathered edge reads as terrain variation, not a UI boundary ring.
		var inner := 1.0 - smoothstep(7.0, 18.0, camp_d)
		var path_band := 1.0 - smoothstep(2.0, 5.5, absf(p.x - rt._camp_hint.x))
		var warmth := maxf(inner * 0.55, path_band * inner * 0.22)
		col = col.lerp(Color(0.88, 0.78, 0.57), warmth)
	var crater_d := Vector2(p.x - rt._crater_hint.x, p.z - rt._crater_hint.z).length()
	if rt._crater_hint != Vector3.ZERO and crater_d < 14.0:
		var bowl := clampf(1.0 - crater_d / 14.0, 0.0, 1.0)
		col = col.lerp(Color(0.55, 0.48, 0.42), bowl * 0.85)
	if rt._crater_hint != Vector3.ZERO:
		var rim := clampf(1.0 - absf(crater_d - 11.0) / 4.0, 0.0, 1.0)
		if rim > 0.0:
			col = col.lerp(Color(0.66, 0.58, 0.52), rim * 0.65)
	return col

static func _tile_color(rt: IslandRuntime, tile_type: int) -> Color:
	match tile_type:
		TileType.DRY:
			return rt._palette.get("dry", Color(0.58, 0.56, 0.34))
		TileType.DIRT:
			return rt._palette.get("dirt", Color(0.40, 0.32, 0.22))
		TileType.SAND:
			return rt._palette.get("sand", Color(0.79, 0.72, 0.54))
		TileType.WET:
			return Color(0.55, 0.49, 0.38)
		TileType.SHALLOW:
			return Color(0.60, 0.78, 0.84)
		TileType.DEEP:
			return Color(0.22, 0.39, 0.56)
		TileType.ROCK:
			return rt._palette.get("rock", Color(0.46, 0.45, 0.44))
		TileType.MUD:
			return Color(0.34, 0.27, 0.20)
		TileType.BARE:
			return Color(0.44, 0.33, 0.23)
		TileType.ASH:
			return Color(0.34, 0.33, 0.33)
		TileType.CLIFF:
			# The map/HUD colour: cliff faces read as rock on the atlas and the minimap.
			return rt._palette.get("rock", Color(0.46, 0.45, 0.44)) * 0.9
		_:
			return rt._palette.get("grass", Color(0.42, 0.62, 0.32))

static func _nav_tri(nav_st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	var c := (p0 + p1 + p2) / 3.0
	if c.y < -0.3:
		return
	nav_st.add_vertex(p0)
	nav_st.add_vertex(p1)
	nav_st.add_vertex(p2)

static func _sea(rt: IslandRuntime, size: float) -> void:
	var deep := MeshInstance3D.new()
	var dplane := PlaneMesh.new()
	# The sea reaches far past the grid: a 4x plane keeps its edge out of any camp, shore or
	# overview shot (the 1.6x plane's edge showed as a dark band at the horizon on 400 m islands).
	dplane.size = Vector2(size * 4.0, size * 4.0)
	deep.mesh = dplane
	deep.position.y = -2.6
	deep.extra_cull_margin = 320.0
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.09, 0.19, 0.28, 1.0)
	dmat.roughness = 0.95
	deep.material_override = dmat
	rt.add_child(deep)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size * 3.2, size * 3.2)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	water.mesh = plane
	water.position.y = -0.05
	water.extra_cull_margin = 300.0
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rt._water_mat = ShaderMaterial.new()
	rt._water_mat.shader = WATER_SHADER
	rt._water_mat.set_shader_parameter("height_tex", rt._height_tex)
	rt._water_mat.set_shader_parameter("noise_tex", noise_tex())
	rt._water_mat.set_shader_parameter("map_size", size)
	rt._water_mat.set_shader_parameter("height_res", float(rt._res))
	rt._water_mat.set_shader_parameter("water_y", -0.05)
	water.material_override = rt._water_mat
	rt.add_child(water)

static func _build_height_texture(rt: IslandRuntime) -> void:
	# Heights straight from the float array (little-endian Float32 = FORMAT_RF): one memcpy
	# instead of 26k set_pixel calls (it was ~40 % of the home build).
	var img := Image.create_from_data(rt._res, rt._res, false, Image.FORMAT_RF, rt._heights.to_byte_array())
	rt._height_tex = ImageTexture.create_from_image(img)

static func bake_nav(rt: IslandRuntime) -> void:
	var nav := NavigationRegion3D.new()
	nav.name = "Nav"
	var nmesh := NavigationMesh.new()
	nmesh.agent_radius = 0.5
	nmesh.agent_max_climb = 1.25
	nmesh.agent_max_slope = 45.0
	nav.navigation_mesh = nmesh
	rt.add_child(nav)
	var floor := rt.get_node_or_null("Floor")
	if floor:
		for c in floor.get_children():
			if c is MeshInstance3D and String(c.name).begins_with("TerrainNav_"):
				var dup: Node = c.duplicate()
				dup.name = String(c.name) + "_nav"
				nav.add_child(dup)
	nav.bake_navigation_mesh(true)

static func normal_at(rt: IslandRuntime, x: float, z: float) -> Vector3:
	var d := 0.75
	var h0 := rt.surface_y(x - d, z)
	var h1 := rt.surface_y(x + d, z)
	var h2 := rt.surface_y(x, z - d)
	var h3 := rt.surface_y(x, z + d)
	return Vector3(h0 - h1, 2.0 * d, h2 - h3).normalized()

static func slope_deg(rt: IslandRuntime, x: float, z: float) -> float:
	var d := 0.75
	var dx := (rt.surface_y(x + d, z) - rt.surface_y(x - d, z)) / (2.0 * d)
	var dz := (rt.surface_y(x, z + d) - rt.surface_y(x, z - d)) / (2.0 * d)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz)))

static func _palette_for(climate: String) -> Dictionary:
	return ClimatePalette.resolve(Data.world_climates.get(climate, {}))

## One loop over the 1 m tile grid: water/beach bands, cliff faces (from the precomputed slope),
## rock, ash, the river channel and banks (MUD, the fresh-water mask t_water reads), the crater.
## Reads only the packed arrays IslandShape precomputed; no noise and no surface_y per tile.
static func _build_tile_types(rt: IslandRuntime, climate: String) -> void:
	rt._tile_span = maxi(1, int(round(rt._size)))
	var span := rt._tile_span
	var types := PackedByteArray()
	types.resize(span * span)
	var fresh := PackedByteArray()
	fresh.resize(types.size())
	var walk := PackedByteArray()
	walk.resize(types.size())
	# RG8: R = tile type, G = biome zone (BiomeZones). The shader reads both.
	rt._tile_map_image = Image.create(span, span, false, Image.FORMAT_RG8)
	rt._tile_map_image.fill(Color.BLACK)
	var biomes := PackedByteArray()
	biomes.resize(types.size())
	# The generated camp clearing is the home island's; elsewhere the zone map keeps its own field.
	var camp: Vector3 = rt._camp_hint if _camp_active(rt) else Vector3.ZERO
	var bctx := BiomeZones.context(rt, climate, camp, _layout_seed(rt, climate))
	var has_ash := _climate_has_material(climate, "ash")
	var half := rt._size * 0.5
	var cell := rt._size / float(rt._res - 1)
	var res := rt._res
	var harr := rt._heights
	var rarr := rt._rad
	var darr := rt._river_d
	var warr := rt._shape.river_w if rt._shape != null else PackedFloat32Array()
	var sarr := rt._vslope
	var land_r := rt.land_radius()
	var shape := rt._shape
	for z in span:
		for x in span:
			var wx := -half + float(x) + 0.5
			var wz := -half + float(z) + 0.5
			# Bilinear height/rad/slope/river distance from the grid (same as surface_y, inline).
			var u := clampf((wx + half) / cell, 0.0, float(res - 1))
			var v := clampf((wz + half) / cell, 0.0, float(res - 1))
			var x0 := int(floor(u))
			var z0 := int(floor(v))
			var x1 := mini(x0 + 1, res - 1)
			var z1 := mini(z0 + 1, res - 1)
			var tx := u - float(x0)
			var tz := v - float(z0)
			var i00 := x0 + z0 * res
			var i10 := x1 + z0 * res
			var i01 := x0 + z1 * res
			var i11 := x1 + z1 * res
			var h := lerpf(lerpf(harr[i00], harr[i10], tx), lerpf(harr[i01], harr[i11], tx), tz)
			var rad := lerpf(lerpf(rarr[i00], rarr[i10], tx), lerpf(rarr[i01], rarr[i11], tx), tz)
			# The steepest corner: a riser is one cell wide, so a bilinear average would hide it.
			var slope := maxf(maxf(sarr[i00], sarr[i10]), maxf(sarr[i01], sarr[i11]))
			var rd := lerpf(lerpf(darr[i00], darr[i10], tx), lerpf(darr[i01], darr[i11], tx), tz)
			var hw := 4.0
			if not warr.is_empty():
				hw = lerpf(lerpf(warr[i00], warr[i10], tx), lerpf(warr[i01], warr[i11], tx), tz)
			# Rock and cliff faces need DRY, INLAND ground at all four grid corners: a bilinear
			# height says nothing about whether the tile is one vertex of a steep beach, and a
			# slope read from the sea apron painted a sawtooth of grey ROCK tiles along home's
			# coast beside the dock (water_lab sea_bank_1m).
			var inland_rock := rad < land_r - 4.0 and minf(minf(harr[i00], harr[i10]), minf(harr[i01], harr[i11])) > 0.45
			var t := TileType.GRASS
			if h < -0.6:
				t = TileType.DEEP
			elif h < -0.05:
				t = TileType.SHALLOW
			elif h < 0.15:
				t = TileType.WET
			elif h < 0.45 or rad > land_r + 2.0:
				t = TileType.SAND
			elif slope > 1.15 and rd > hw + 3.0 and inland_rock:
				# A riser: 1.15 rise/run is about 49 deg, the terrace face (3.2 m over one cell).
				# The river's own banks are steep too; they stay water/bank, never a cliff (a cliff
				# strip along both banks read as black walls in the top-down shot).
				t = TileType.CLIFF
			elif (slope > 0.72 or h > 9.6) and inland_rock:
				t = TileType.ROCK
			elif slope > 0.5:
				t = TileType.DRY
			if has_ash and h > 4.8 and t == TileType.ROCK:
				t = TileType.ASH
			# The river: one continuous channel of MUD (half-width `hw`) with its bed under the
			# -0.05 water plane. The ford is a SHALLOW crossing (bed -0.10 m), not a dry gap: the
			# channel and its fresh-water mask run unbroken through it.
			if rd < hw and h > -0.6 and h < 0.15:
				t = TileType.MUD
			elif rd < hw + 1.0 and h > 0.05 and h < 0.22:
				# A narrow wet bank strip (MUD, so the fresh-water mask covers the edge). Wider or
				# higher than this and it reads as a brown mud wall along the river (NOTES.md).
				t = TileType.MUD
			var cdist := Vector2(wx - rt._crater_hint.x, wz - rt._crater_hint.z).length()
			if rt._crater_hint != Vector3.ZERO and cdist < 8.5 and h > -0.2:
				t = TileType.DIRT
			var idx := x + z * span
			var b := BiomeZones.zone_of(bctx, wx, wz, h, slope, rd)
			types[idx] = t
			biomes[idx] = b
			fresh[idx] = 1 if t == TileType.MUD else 0
			# The dry/walkable mask, precomputed once: is_dry (TilePath, build checks, spawn probes)
			# is then one array lookup instead of four grid samples per call.
			walk[idx] = 1 if (t == TileType.GRASS or t == TileType.DRY or t == TileType.DIRT or t == TileType.SAND \
				or t == TileType.ROCK or t == TileType.ASH) and h >= 0.25 and rad <= land_r - 0.5 else 0
	rt.tile_types = types
	BiomeZones.install(rt, biomes)
	rt.fresh_water = fresh
	rt.dry_walk = walk
	BiomeZones.smooth(rt)
	_write_tile_image(rt)
	rt._tile_map_tex = ImageTexture.create_from_image(rt._tile_map_image)

## The tile id the shader paints. CLIFF writes NO override: the shader already paints steep
## ground as rock from the vertex normal, and painting rock per 1 m tile turned each face into a
## blocky black patchwork (NOTES.md, top-down shots).
static func _shader_id(t: int) -> int:
	return TileType.GRASS if t == TileType.CLIFF else t

## Copies both channels into the tile image (the shader samples R and G).
static func _write_tile_image(rt: IslandRuntime) -> void:
	var span := rt._tile_span
	if rt._tile_map_image == null or rt._tile_map_image.get_width() != span:
		rt._tile_map_image = Image.create(span, span, false, Image.FORMAT_RG8)
	var bio := BiomeZones.biome_types(rt)
	for z in span:
		for x in span:
			var idx := x + z * span
			var t := int(rt.tile_types[idx]) if idx < rt.tile_types.size() else 0
			var b := int(bio[idx]) if idx < bio.size() else 0
			rt._tile_map_image.set_pixel(x, z, Color(float(_shader_id(t)) / 255.0, float(b) / 255.0, 0.0))

## The camp shape in the heightmap and vertex colours belongs to the home island only: the other
## islands' generated rim must stay untamed.
static func _camp_active(rt: IslandRuntime) -> bool:
	return _island_key(rt) == "home_grassland"

## The island's id: set on the runtime by World.load_island where available, else the current one.
static func _island_key(rt: IslandRuntime) -> String:
	return str(rt.get_meta("island_id", World.island_id))

## Moisture seed: the island's own id, so two grassland islands do not share a zone field.
static func _layout_seed(rt: IslandRuntime, climate: String) -> int:
	var key := _island_key(rt)
	if key == "":
		return 25 if climate == "temperate" else 17
	return 1000 + absi(hash(key)) % 100000

static func _terrain_material(rt: IslandRuntime) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter("map_size", rt._size)
	m.set_shader_parameter("grid_enabled", 1.0 if Game.show_grid else 0.0)
	m.set_shader_parameter("tile_map_tex", rt._tile_map_tex)
	m.set_shader_parameter("grass_tex", _tex_or_fallback(TERRAIN_TEX["grass"], Color(0.45, 0.68, 0.38)))
	m.set_shader_parameter("dirt_tex", _tex_or_fallback(TERRAIN_TEX["dirt"], Color(0.44, 0.34, 0.24)))
	m.set_shader_parameter("sand_tex", _tex_or_fallback(TERRAIN_TEX["sand"], Color(0.82, 0.75, 0.58)))
	m.set_shader_parameter("rock_tex", _tex_or_fallback(TERRAIN_TEX["rock"], Color(0.48, 0.47, 0.45)))
	m.set_shader_parameter("noise_tex", noise_tex())
	m.set_shader_parameter("focus_pos", Vector3.ZERO)
	m.set_shader_parameter("tint_grass", _c3(_tile_color(rt, TileType.GRASS)))
	m.set_shader_parameter("tint_dry", _c3(_tile_color(rt, TileType.DRY)))
	m.set_shader_parameter("tint_dirt", _c3(_tile_color(rt, TileType.DIRT)))
	m.set_shader_parameter("tint_sand", _c3(_tile_color(rt, TileType.SAND)))
	m.set_shader_parameter("tint_shallow", _c3(_tile_color(rt, TileType.SHALLOW)))
	m.set_shader_parameter("tint_wet", _c3(_tile_color(rt, TileType.WET)))
	m.set_shader_parameter("tint_rock", _c3(_tile_color(rt, TileType.ROCK)))
	m.set_shader_parameter("tint_mud", _c3(_tile_color(rt, TileType.MUD)))
	m.set_shader_parameter("tint_bare", _c3(_tile_color(rt, TileType.BARE)))
	m.set_shader_parameter("tint_deep", _c3(_tile_color(rt, TileType.DEEP)))
	m.set_shader_parameter("tint_ash", _c3(_tile_color(rt, TileType.ASH)))
	# W1-BIOME: per-climate baked textures, palette multipliers and the biome shader knobs.
	# The tint_* values above stay as fallbacks if a row is missing one of its textures.
	if not BiomeMaterial.apply_terrain(m, rt._climate):
		push_warning("[biome] no biomes.json row for climate %s; using the fallback ground" % rt._climate)
	m.set_shader_parameter("biome_pal", ImageTexture.create_from_image(BiomeZones.palette_image(rt._climate)))
	m.set_shader_parameter("biome_on", 1.0)
	return m

static func _c3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)

static func noise_tex() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = 4121
	n.frequency = 0.09
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	return t

static func _tex_or_fallback(path: String, color: Color) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

static func tile_idx(rt: IslandRuntime, x: int, z: int) -> int:
	return x + z * rt._tile_span

static func tile_type_at_world(rt: IslandRuntime, x: float, z: float) -> int:
	if rt.tile_types.is_empty():
		return TileType.GRASS
	var tx := clampi(int(floor(x + rt._size * 0.5)), 0, rt._tile_span - 1)
	var tz := clampi(int(floor(z + rt._size * 0.5)), 0, rt._tile_span - 1)
	return int(rt.tile_types[tile_idx(rt, tx, tz)])

## River water as built (WaterAccess): a harvested node's BARE tile in the channel stays fresh.
static func fresh_water_at_world(rt: IslandRuntime, x: float, z: float) -> bool:
	if rt.fresh_water.is_empty():
		return false
	var tx := clampi(int(floor(x + rt._size * 0.5)), 0, rt._tile_span - 1)
	var tz := clampi(int(floor(z + rt._size * 0.5)), 0, rt._tile_span - 1)
	return rt.fresh_water[tile_idx(rt, tx, tz)] == 1

static func set_tile_type(rt: IslandRuntime, tile: Vector2i, tile_type: int) -> void:
	if rt.tile_types.is_empty():
		return
	var tx := clampi(tile.x + int(rt._size * 0.5), 0, rt._tile_span - 1)
	var tz := clampi(tile.y + int(rt._size * 0.5), 0, rt._tile_span - 1)
	rt.tile_types[tile_idx(rt, tx, tz)] = tile_type
	if rt._tile_map_image:
		# G keeps the biome zone: harvesting a node must not repaint the ground's biome.
		var b := 0.0
		var bio := BiomeZones.biome_types(rt)
		if not bio.is_empty():
			b = float(bio[tile_idx(rt, tx, tz)]) / 255.0
		rt._tile_map_image.set_pixel(tx, tz, Color(float(_shader_id(tile_type)) / 255.0, b, 0.0))
		if rt._tile_map_tex:
			rt._tile_map_tex.update(rt._tile_map_image)

static func drive_focus(rt: IslandRuntime) -> void:
	if rt._terrain_mat == null:
		return
	var p := PlayerRegistry.local()
	if p:
		rt._terrain_mat.set_shader_parameter("focus_pos", p.global_position)
	rt._terrain_mat.set_shader_parameter("grid_enabled", 1.0 if Game.show_grid else 0.0)

static func _climate_has_material(climate: String, item_id: String) -> bool:
	var row: Dictionary = Data.world_climates.get(climate, {})
	var arr: Array = row.get("materials", [])
	for m in arr:
		if m is Dictionary and str((m as Dictionary).get("id", "")) == item_id:
			return true
	return false
