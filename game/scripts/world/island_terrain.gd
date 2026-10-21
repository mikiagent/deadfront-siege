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
}

static func build(rt: IslandRuntime, size: float, climate: String) -> void:
	rt._size = size
	rt._res = 129 if size >= 200.0 else 65
	# Fill locals and assign once: writing a packed array through rt.<field> copies it per write.
	var heights := PackedFloat32Array()
	heights.resize(rt._res * rt._res)
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
	rt._ridge_dir = Vector2(cos(ridge_ang), sin(ridge_ang)).normalized()
	var cell := size / float(rt._res - 1)
	# Durango ground is flat: gentle undulation only, a low ridge far inland, and a wide
	# gradual shore (dry sand -> wet sand -> shallow -> deep over 20-30 m) whose waterline
	# wanders with noise so it never reads as a ring.
	var shore0 := size * 0.36
	var shore1 := size * 0.47
	for z in rt._res:
		for x in rt._res:
			var wx := -size * 0.5 + float(x) * cell
			var wz := -size * 0.5 + float(z) * cell
			var h := 1.1
			h += n0.get_noise_2d(wx, wz) * 0.45
			h += n1.get_noise_2d(wx, wz) * 0.18
			h += n2.get_noise_2d(wx, wz) * 0.06
			var rad := Vector2(wx, wz).length()
			if rad > size * 0.14 and rad < shore0:
				var dir := Vector2(wx, wz).normalized()
				var along := maxf(0.0, dir.dot(rt._ridge_dir))
				var cross := absf(dir.dot(Vector2(-rt._ridge_dir.y, rt._ridge_dir.x)))
				var width := clampf(1.0 - cross / 0.5, 0.0, 1.0)
				var inland := clampf((rad - size * 0.14) / (shore0 - size * 0.14), 0.0, 1.0)
				h += 2.0 * along * width * sin(inland * PI)
			var river_center := sin(wx * 0.018 + float(seed) * 0.13) * (size * 0.085)
			var river := absf(wz - river_center)
			if river < 6.0 and rad > size * 0.16 and rad < size * 0.42:
				var carve := clampf(1.0 - river / 6.0, 0.0, 1.0)
				carve = carve * carve * (3.0 - 2.0 * carve)
				h = lerpf(h, -0.35, carve)
			if rt._crater_hint != Vector3.ZERO:
				var dc := Vector2(wx - rt._crater_hint.x, wz - rt._crater_hint.z).length()
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
			if rt._camp_hint != Vector3.ZERO:
				var camp_d := Vector2(wx - rt._camp_hint.x, wz - rt._camp_hint.z).length()
				if camp_d < 16.0:
					var s := clampf(1.0 - camp_d / 16.0, 0.0, 1.0)
					h = lerpf(h, 1.1, s * 0.6)
			heights[x + z * rt._res] = h
	rt._heights = heights
	_build_height_texture(rt)
	_build_tile_types(rt, climate)
	_build_mesh(rt, size, cell, climate)
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
	dplane.size = Vector2(size * 1.8, size * 1.8)
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
	plane.size = Vector2(size * 1.6, size * 1.6)
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
	var img := Image.create(rt._res, rt._res, false, Image.FORMAT_RF)
	for z in rt._res:
		for x in rt._res:
			img.set_pixel(x, z, Color(rt._heights[x + z * rt._res], 0.0, 0.0))
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

static func _build_tile_types(rt: IslandRuntime, climate: String) -> void:
	rt._tile_span = maxi(1, int(round(rt._size)))
	var types := PackedByteArray()
	types.resize(rt._tile_span * rt._tile_span)
	var fresh := PackedByteArray()
	fresh.resize(types.size())
	rt._tile_map_image = Image.create(rt._tile_span, rt._tile_span, false, Image.FORMAT_R8)
	rt._tile_map_image.fill(Color.BLACK)
	var has_ash := _climate_has_material(climate, "ash")
	for z in rt._tile_span:
		for x in rt._tile_span:
			var wx := -rt._size * 0.5 + float(x) + 0.5
			var wz := -rt._size * 0.5 + float(z) + 0.5
			var h := rt.surface_y(wx, wz)
			var slope := slope_deg(rt, wx, wz)
			var rad := Vector2(wx, wz).length()
			var t := TileType.GRASS
			if h < -0.6:
				t = TileType.DEEP
			elif h < -0.05:
				t = TileType.SHALLOW
			elif h < 0.15:
				t = TileType.WET
			elif h < 0.45 or rad > rt.land_radius() + 2.0:
				t = TileType.SAND
			elif slope > 40.0 or h > 5.5:
				t = TileType.ROCK
			elif slope > 28.0:
				t = TileType.DRY
			if has_ash and h > 4.8 and t == TileType.ROCK:
				t = TileType.ASH
			var river_center := sin(wx * 0.018 + float(25 if climate == "temperate" else 17) * 0.13) * (rt._size * 0.085)
			var river := absf(wz - river_center)
			if river < 2.4 and h > -0.5 and h < 0.4:
				t = TileType.MUD
			var cdist := Vector2(wx - rt._crater_hint.x, wz - rt._crater_hint.z).length()
			if rt._crater_hint != Vector3.ZERO and cdist < 8.5 and h > -0.2:
				t = TileType.DIRT
			var idx := x + z * rt._tile_span
			types[idx] = t
			fresh[idx] = 1 if t == TileType.MUD else 0
			rt._tile_map_image.set_pixel(x, z, Color(float(t) / 255.0, 0.0, 0.0))
	rt.tile_types = types
	rt.fresh_water = fresh
	rt._tile_map_tex = ImageTexture.create_from_image(rt._tile_map_image)

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
		rt._tile_map_image.set_pixel(tx, tz, Color(float(tile_type) / 255.0, 0.0, 0.0))
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
