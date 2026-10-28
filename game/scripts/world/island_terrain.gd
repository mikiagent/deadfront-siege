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
	_refine(rt)
	_build_height_texture(rt)
	PerfTrace.mark("terrain.tex")
	_build_tile_types(rt, climate)
	PerfTrace.mark("terrain.tiles")
	_build_mesh(rt, size, size / float(rt._res - 1), climate)
	PerfTrace.mark("terrain.mesh")
	_sea(rt, size)
	PerfTrace.mark("terrain.sea")

## The rendered surface: the data grid refined 2x (cells 1.3 m) by a separable cubic midpoint rule
## (-1, 9, 9, -1)/16, each midpoint clamped between its two neighbours so cliffs and the shore never
## overshoot into ridges or dips. Grid nodes keep their exact heights. Mesh, collision, the water's
## height texture and surface_y (IslandRuntime) all read this one array, so what the survivor stands
## on is drawn.
static func _refine(rt: IslandRuntime) -> void:
	var r := rt._res
	var f := 2 * (r - 1) + 1
	var src := rt._heights
	# Pass 1: rows of the data grid refined along x (r rows x f columns).
	var rows := PackedFloat32Array()
	rows.resize(r * f)
	for z in r:
		var o := z * r
		var fo := z * f
		for x in r - 1:
			var h1 := src[o + x]
			var h2 := src[o + x + 1]
			var h0 := src[o + maxi(x - 1, 0)]
			var h3 := src[o + mini(x + 2, r - 1)]
			rows[fo + 2 * x] = h1
			rows[fo + 2 * x + 1] = clampf((9.0 * (h1 + h2) - h0 - h3) * 0.0625, minf(h1, h2), maxf(h1, h2))
		rows[fo + f - 1] = src[o + r - 1]
	# Pass 2: the same rule down each refined column.
	var out := PackedFloat32Array()
	out.resize(f * f)
	for z in r:
		var a := z * f
		var b := 2 * z * f
		for x in f:
			out[b + x] = rows[a + x]
	for z in r - 1:
		var i0 := maxi(z - 1, 0) * f
		var i1 := z * f
		var i2 := (z + 1) * f
		var i3 := mini(z + 2, r - 1) * f
		var d := (2 * z + 1) * f
		for x in f:
			var h1 := rows[i1 + x]
			var h2 := rows[i2 + x]
			out[d + x] = clampf((9.0 * (h1 + h2) - rows[i0 + x] - rows[i3 + x]) * 0.0625, minf(h1, h2), maxf(h1, h2))
	rt._surf = out
	rt._surf_res = f

static func _build_mesh(rt: IslandRuntime, size: float, cell: float, climate: String) -> void:
	rt._palette = _palette_for(climate)
	rt._terrain_mat = _terrain_material(rt)
	var body := StaticBody3D.new()
	body.name = "Floor"
	var tiles := 8 if rt._res >= 129 else 4
	var fres := rt._surf_res
	var fcell := size / float(fres - 1)
	var fspan := int((fres - 1) / tiles)
	var span := int((rt._res - 1) / tiles)
	var indices := _chunk_indices(fspan)
	for tz in tiles:
		for tx in tiles:
			var mi := MeshInstance3D.new()
			mi.name = "TerrainMesh_%d_%d" % [tx, tz]
			mi.mesh = _chunk_mesh(rt, fcell, tx * fspan, tz * fspan, fspan, indices)
			mi.material_override = rt._terrain_mat
			mi.extra_cull_margin = 80.0
			body.add_child(mi)
			var x1 := rt._res - 1 if tx == tiles - 1 else (tx + 1) * span
			var z1 := rt._res - 1 if tz == tiles - 1 else (tz + 1) * span
			var nav_mesh := _nav_chunk(rt, size, cell, tx * span, tz * span, x1, z1)
			if nav_mesh:
				var nav_src := MeshInstance3D.new()
				nav_src.name = "TerrainNav_%d_%d" % [tx, tz]
				nav_src.mesh = nav_mesh
				nav_src.visible = false
				body.add_child(nav_src)
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = fres
	hs.map_depth = fres
	hs.map_data = rt._surf
	cs.shape = hs
	cs.position = Vector3.ZERO
	cs.scale = Vector3(fcell, 1, fcell)
	body.add_child(cs)
	rt.add_child(body)

## One index buffer shared by every chunk (all chunks are n x n cells): two triangles per cell,
## (x,z)(x+1,z)(x,z+1) and (x+1,z)(x+1,z+1)(x,z+1), the winding and diagonal surface_y assumes.
static func _chunk_indices(n: int) -> PackedInt32Array:
	var w := n + 1
	var idx := PackedInt32Array()
	idx.resize(n * n * 6)
	var k := 0
	for z in n:
		for x in n:
			var a := x + z * w
			idx[k] = a
			idx[k + 1] = a + 1
			idx[k + 2] = a + w
			idx[k + 3] = a + 1
			idx[k + 4] = a + w + 1
			idx[k + 5] = a + w
			k += 6
	return idx

## One indexed chunk of the refined surface with smooth normals from central differences over the
## whole grid, so neighbouring chunks share their edge normals (no seams, no flat facets).
static func _chunk_mesh(rt: IslandRuntime, fcell: float, x0: int, z0: int, n: int, indices: PackedInt32Array) -> ArrayMesh:
	var res := rt._surf_res
	var h := rt._surf
	var half := rt._size * 0.5
	var w := n + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(w * w)
	norms.resize(w * w)
	cols.resize(w * w)
	cols.fill(Color(1, 1, 1))
	var two_c := 2.0 * fcell
	var camp := rt._camp_hint
	var crater := rt._crater_hint
	var k := 0
	for zz in w:
		var z := z0 + zz
		var zm := maxi(z - 1, 0) * res
		var zp := mini(z + 1, res - 1) * res
		var wz := -half + float(z) * fcell
		for xx in w:
			var x := x0 + xx
			var row := z * res
			var p := Vector3(-half + float(x) * fcell, h[x + row], wz)
			verts[k] = p
			norms[k] = Vector3(h[maxi(x - 1, 0) + row] - h[mini(x + 1, res - 1) + row], two_c, h[x + zm] - h[x + zp]).normalized()
			# Only the camp clearing and the crater tint the ground; skip the colour maths elsewhere.
			if (absf(p.x - camp.x) < 18.0 and absf(p.z - camp.z) < 18.0) or (crater != Vector3.ZERO and absf(p.x - crater.x) < 15.0 and absf(p.z - crater.z) < 15.0):
				cols[k] = _terrain_color(rt, p)
			k += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## The nav bake's source for one chunk: the data grid's triangles (as before the refinement), minus
## the ones under the sea. Returns null when the whole chunk is sea.
static func _nav_chunk(rt: IslandRuntime, size: float, cell: float, x0: int, z0: int, x1: int, z1: int) -> ArrayMesh:
	var tris := PackedVector3Array()
	for z in range(z0, z1):
		for x in range(x0, x1):
			_nav_tri(tris, _vpos(rt, size, cell, x, z), _vpos(rt, size, cell, x + 1, z), _vpos(rt, size, cell, x, z + 1))
			_nav_tri(tris, _vpos(rt, size, cell, x + 1, z), _vpos(rt, size, cell, x + 1, z + 1), _vpos(rt, size, cell, x, z + 1))
	if tris.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = tris
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

static func _vpos(rt: IslandRuntime, size: float, cell: float, x: int, z: int) -> Vector3:
	var wx := -size * 0.5 + float(x) * cell
	var wz := -size * 0.5 + float(z) * cell
	return Vector3(wx, rt._heights[x + z * rt._res], wz)

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

static func _nav_tri(tris: PackedVector3Array, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	var c := (p0 + p1 + p2) / 3.0
	if c.y < -0.3:
		return
	tris.append(p0)
	tris.append(p1)
	tris.append(p2)

static func _sea(rt: IslandRuntime, size: float) -> void:
	var deep := MeshInstance3D.new()
	var dplane := PlaneMesh.new()
	# The sea reaches far past the grid: a 4x plane keeps its edge out of any camp, shore or
	# overview shot (the 1.6x plane's edge showed as a dark band at the horizon on 400 m islands).
	dplane.size = Vector2(size * 4.0, size * 4.0)
	deep.mesh = dplane
	# 0.15 m under the seabed floor (IslandShape clamps it at -2.6): at the same height the two
	# z-fought into blocky dark-blue patches offshore. Visual only; the water plane stays at -0.05.
	deep.position.y = -2.75
	deep.extra_cull_margin = 320.0
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.09, 0.19, 0.28, 1.0)
	dmat.roughness = 0.95
	deep.material_override = dmat
	rt.add_child(deep)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size * 3.2, size * 3.2)
	plane.subdivide_width = SeaWaves.subdivisions(plane.size.x)
	plane.subdivide_depth = plane.subdivide_width
	water.mesh = plane
	water.position.y = -0.05
	water.extra_cull_margin = 300.0
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rt._water_mat = ShaderMaterial.new()
	rt._water_mat.shader = WATER_SHADER
	rt._water_mat.set_shader_parameter("height_tex", rt._height_tex)
	rt._water_mat.set_shader_parameter("noise_tex", noise_tex())
	rt._water_mat.set_shader_parameter("map_size", size)
	rt._water_mat.set_shader_parameter("height_res", float(rt._surf_res))
	rt._water_mat.set_shader_parameter("water_y", -0.05)
	water.material_override = rt._water_mat
	rt.add_child(water)
	SeaWaves.attach(rt, rt._water_mat)

static func _build_height_texture(rt: IslandRuntime) -> void:
	# Heights straight from the float array (little-endian Float32 = FORMAT_RF): one memcpy
	# instead of 26k set_pixel calls (it was ~40 % of the home build).
	var img := Image.create_from_data(rt._surf_res, rt._surf_res, false, Image.FORMAT_RF, rt._surf.to_byte_array())
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

## Height and slope (deg) at a world point in one call, for the placement loops that ask for both at
## 90k+ spots: the same arithmetic as surface_y + slope_deg (five bilinear reads, the four slope ones
## at +-0.75 m), inlined over the packed height array so the two helpers' call, empty-check and
## clamping repeats go away. Returns Vector2(height, slope_deg): height is exactly surface_y(x, z) and
## the slope is exactly slope_deg(x, z). Once the refined surface exists (TERRAINSMOOTH) they call those.
const SLOPE_D := 0.75

## Surface height and slope in degrees from one grid read set (the fused form of surface_y +
## slope_deg: same samples, same arithmetic, one pass over the height array).
static func height_and_slope(rt: IslandRuntime, x: float, z: float) -> Vector2:
	if not rt._surf.is_empty():  # TERRAINSMOOTH: the drawn (refined) surface, surface_y's triangle rule
		return Vector2(rt.surface_y(x, z), slope_deg(rt, x, z))
	var arr := rt._heights
	if arr.is_empty():
		return Vector2.ZERO
	var res := rt._res
	var cell := rt._size / float(res - 1)
	var half := rt._size * 0.5
	var last := float(res - 1)
	var u := clampf((x + half) / cell, 0.0, last)
	var v := clampf((z + half) / cell, 0.0, last)
	var h0 := _bil_at(arr, res, u, v)
	var h1 := _bil_at(arr, res, clampf((x - SLOPE_D + half) / cell, 0.0, last), v)
	var h2 := _bil_at(arr, res, clampf((x + SLOPE_D + half) / cell, 0.0, last), v)
	var h3 := _bil_at(arr, res, u, clampf((z - SLOPE_D + half) / cell, 0.0, last))
	var h4 := _bil_at(arr, res, u, clampf((z + SLOPE_D + half) / cell, 0.0, last))
	return Vector2(h0, _slope_deg_of(h1, h2, h3, h4))

## The same pair from grid coordinates (u, v), for a caller that already has them (the tile loops).
static func height_and_slope_grid(rt: IslandRuntime, u: float, v: float, cell: float) -> Vector2:
	if not rt._surf.is_empty():
		return height_and_slope(rt, u * cell - rt._size * 0.5, v * cell - rt._size * 0.5)
	var arr := rt._heights
	if arr.is_empty():
		return Vector2.ZERO
	var res := rt._res
	var last := float(res - 1)
	var d := SLOPE_D / cell
	var h0 := _bil_at(arr, res, u, v)
	var h1 := _bil_at(arr, res, clampf(u - d, 0.0, last), v)
	var h2 := _bil_at(arr, res, clampf(u + d, 0.0, last), v)
	var h3 := _bil_at(arr, res, u, clampf(v - d, 0.0, last))
	var h4 := _bil_at(arr, res, u, clampf(v + d, 0.0, last))
	return Vector2(h0, _slope_deg_of(h1, h2, h3, h4))

static func _slope_deg_of(h1: float, h2: float, h3: float, h4: float) -> float:
	var dx := (h2 - h1) / (2.0 * SLOPE_D)
	var dz := (h4 - h3) / (2.0 * SLOPE_D)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz)))

## The point sample alone (surface_y's rule) for callers that do not need the slope.
static func height_at(rt: IslandRuntime, x: float, z: float) -> float:
	if not rt._surf.is_empty():
		return rt.surface_y(x, z)
	var arr := rt._heights
	if arr.is_empty():
		return 0.0
	var res := rt._res
	return _bil_at(arr, res, clampf((x + rt._size * 0.5) / (rt._size / float(res - 1)), 0.0, float(res - 1)),
		clampf((z + rt._size * 0.5) / (rt._size / float(res - 1)), 0.0, float(res - 1)))

## slope_deg's rule on the height array: +-SLOPE_D in x and z, in degrees.
static func slope_at(rt: IslandRuntime, x: float, z: float) -> float:
	if not rt._surf.is_empty():
		return slope_deg(rt, x, z)
	var arr := rt._heights
	if arr.is_empty():
		return 0.0
	var res := rt._res
	var cell := rt._size / float(res - 1)
	var half := rt._size * 0.5
	var last := float(res - 1)
	var u := clampf((x + half) / cell, 0.0, last)
	var v := clampf((z + half) / cell, 0.0, last)
	var h1 := _bil_at(arr, res, clampf((x - SLOPE_D + half) / cell, 0.0, last), v)
	var h2 := _bil_at(arr, res, clampf((x + SLOPE_D + half) / cell, 0.0, last), v)
	var h3 := _bil_at(arr, res, u, clampf((z - SLOPE_D + half) / cell, 0.0, last))
	var h4 := _bil_at(arr, res, u, clampf((z + SLOPE_D + half) / cell, 0.0, last))
	return _slope_deg_of(h1, h2, h3, h4)

## Bilinear sample at raw grid coordinates (u, v).
static func _bil_at(arr: PackedFloat32Array, res: int, u: float, v: float) -> float:
	var x0 := int(u)
	var z0 := int(v)
	var x1 := mini(x0 + 1, res - 1)
	var z1 := mini(z0 + 1, res - 1)
	var tx := u - float(x0)
	var tz := v - float(z0)
	return lerpf(lerpf(arr[x0 + z0 * res], arr[x1 + z0 * res], tx), lerpf(arr[x0 + z1 * res], arr[x1 + z1 * res], tx), tz)

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
	var soft := PackedByteArray()
	soft.resize(types.size() * 4)
	# The generated camp clearing is the home island's; elsewhere the zone map keeps its own field.
	var camp: Vector3 = rt._camp_hint if _camp_active(rt) else Vector3.ZERO
	PerfTrace.mark("tiles.ctx")
	var bctx := BiomeZones.context(rt, climate, camp, _layout_seed(rt, climate))
	var bstate := BiomeZones.fast_state(bctx)
	PerfTrace.mark("tiles.ctx2")
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
	var beach := _beach_plan(rt, climate)
	var beach_on := PackedByteArray()
	beach_on.resize(types.size())
	var bw_tab: PackedFloat32Array = beach.get("width", PackedFloat32Array())
	var b_slope := float(beach.get("max_slope", 0.45))
	var b_maxh := float(beach.get("max_h", 2.0))
	var b_jit: FastNoiseLite = beach.get("jitter", null)
	var b_reach := float(beach.get("reach", 10.0)) + 4.0
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
			var rd := lerpf(lerpf(darr[i00], darr[i10], tx), lerpf(darr[i01], darr[i11], tx), tz)
			# The slope and the river half-width are read on the land band only (h >= 0.45), and the
			# half-width again on the wet/low band the MUD override covers. Everything seaward and
			# beachward of that is decided by height and radius alone and never looks at either, and
			# the zone of a tile below beach height always answers "beach" before it reads the
			# slope. Skipping those reads is worth ~15 % of this loop (home is ~60 % water+beach).
			var slope := 0.0
			var hw := 4.0
			if h >= 0.45:
				# The steepest corner: a riser is one cell wide, so a bilinear average would hide it.
				slope = maxf(maxf(sarr[i00], sarr[i10]), maxf(sarr[i01], sarr[i11]))
			if (h >= 0.45 or (h > -0.6 and h < 0.22)) and not warr.is_empty():
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
			# The crater is only on some islands: test for it before measuring the distance, so the
			# common island does not build a Vector2 per tile (173k of them on the big ones).
			var cdist := INF
			if rt._crater_hint != Vector3.ZERO:
				cdist = Vector2(wx - rt._crater_hint.x, wz - rt._crater_hint.z).length()
				if cdist < 8.5 and h > -0.2:
					t = TileType.DIRT
			var idx := x + z * span
			# Sandy beach: on this bearing's stretch of coast, within its width of the waterline, on a
			# gentle shore, clear of the river mouth, the camp and the crater. Cliffs and rock stay.
			if (t == TileType.GRASS or t == TileType.DRY) and not bw_tab.is_empty() and rad > land_r - b_reach \
					and h < b_maxh and rd > hw + 4.0 and (rt._crater_hint == Vector3.ZERO or cdist > 12.0) \
					and Vector2(wx - rt._camp_hint.x, wz - rt._camp_hint.z).length() > 18.0:
				# The tile's own (bilinear) slope: the steepest-corner one also sees the shore drop.
				var bsl := lerpf(lerpf(sarr[i00], sarr[i10], tx), lerpf(sarr[i01], sarr[i11], tx), tz)
				var bin := int((atan2(wz - shape.centre.y, wx - shape.centre.x) + PI) / TAU * float(bw_tab.size())) % bw_tab.size()
				var w := bw_tab[bin] * clampf(1.3 - bsl / b_slope, 0.0, 1.0)
				# Inland distance from the waterline (IslandShape's shore profile reaches h = 0 about
				# 1.33 m seaward of shore0, moved by the same shore wander noise).
				var din := shape.shore0 + 1.33 - (rad + shape._nshore.get_noise_2d(wx, wz) * shape.size * 0.010)
				if w > 0.0 and din + b_jit.get_noise_2d(wx, wz) * 1.5 < w:
					t = TileType.SAND
					beach_on[idx] = 1
			var b := BiomeZones.zone_of_state(bstate, wx, wz, h, slope, rd)
			types[idx] = t
			biomes[idx] = b
			fresh[idx] = 1 if t == TileType.MUD else 0
			if t == TileType.ROCK:
				soft[idx * 4] = 255
			elif t == TileType.ASH:
				soft[idx * 4 + 1] = 255
			elif t == TileType.MUD:
				soft[idx * 4 + 2] = 255
			elif t == TileType.DIRT:
				soft[idx * 4 + 3] = 255
			# The dry/walkable mask, precomputed once: is_dry (TilePath, build checks, spawn probes)
			# is then one array lookup instead of four grid samples per call.
			walk[idx] = 1 if (t == TileType.GRASS or t == TileType.DRY or t == TileType.DIRT or t == TileType.SAND \
				or t == TileType.ROCK or t == TileType.ASH) and h >= 0.25 and rad <= land_r - 0.5 else 0
	# Cliffs stay rock: a beach tile beside a cliff face goes back to grass (the faces are only known
	# once the whole loop has run).
	for i in beach_on.size():
		if beach_on[i] == 0:
			continue
		var bx := i % span
		var bz := i / span
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var j := clampi(bx + dx, 0, span - 1) + clampi(bz + dz, 0, span - 1) * span
				if types[j] == TileType.CLIFF:
					beach_on[i] = 0
		if beach_on[i] == 0:
			types[i] = TileType.GRASS
	rt.tile_types = types
	PerfTrace.mark("tiles.loop")
	BiomeZones.install(rt, biomes)
	rt.fresh_water = fresh
	rt.dry_walk = walk
	BiomeZones.smooth(rt)
	# The sandy beaches keep the beach zone after smoothing (a 4-10 m strip would erode in the filter).
	var bio := BiomeZones.biome_types(rt)
	var beach_id := BiomeZones.zone_id("beach")
	for i in beach_on.size():
		if beach_on[i] == 1:
			bio[i] = beach_id
	BiomeZones.install(rt, bio)
	PerfTrace.mark("tiles.smooth")
	_write_tile_image(rt)
	rt._tile_map_tex = ImageTexture.create_from_image(rt._tile_map_image)
	PerfTrace.mark("tiles.image")
	_build_zone_tex(rt)
	var soft_img := Image.create_from_data(span, span, false, Image.FORMAT_RGBA8, soft)
	soft_img.generate_mipmaps()
	rt._soft_tex = ImageTexture.create_from_image(soft_img)

## The sandy-beach stretches of this island's coast: a width per coast bearing (720 bins around the
## shape centre), 0 off the beaches. A low-frequency noise around the coast picks the stretches; the
## threshold is its (1 - share) quantile, so about `share` of the bearings get sand, and widths taper
## to 0 at the ends. Share and widths are data (biomes.json zone_rules, a climate row's beach_share).
static func _beach_plan(rt: IslandRuntime, climate: String) -> Dictionary:
	var r := BiomeZones.rules()
	var share := clampf(float(BiomeMaterial.row(climate).get("beach_share", r.get("beach_share", 0.5))), 0.0, 1.0)
	var wr: Variant = r.get("beach_width_m", [4.0, 10.0])
	var wmin := float((wr as Array)[0]) if wr is Array else 4.0
	var wmax := float((wr as Array)[1]) if wr is Array else 10.0
	var n := FastNoiseLite.new()
	n.seed = _layout_seed(rt, climate) + 4242
	n.frequency = 0.02
	var bins := 720
	var vals := PackedFloat32Array()
	vals.resize(bins)
	for i in bins:
		var th := TAU * float(i) / float(bins) - PI
		vals[i] = n.get_noise_2d(cos(th) * 60.0, sin(th) * 60.0)
	var sorted := vals.duplicate()
	sorted.sort()
	var thr := sorted[clampi(int(float(bins) * (1.0 - share)), 0, bins - 1)] if share > 0.0 else INF
	var top := maxf(sorted[bins - 1], thr + 0.001)
	var width := PackedFloat32Array()
	width.resize(bins)
	for i in bins:
		var v := vals[i]
		if v >= thr:
			width[i] = lerpf(wmin, wmax, clampf((v - thr) / (top - thr), 0.0, 1.0)) * smoothstep(thr, thr + 0.02, v)
	var jit := FastNoiseLite.new()
	jit.seed = n.seed + 1
	jit.frequency = 0.15
	return {"width": width, "max_slope": float(r.get("beach_max_slope", 0.45)), "max_h": float(r.get("beach_max_h", 2.0)),
		"jitter": jit, "reach": wmax, "share": share}

## The zone tint and layer-mix textures, one texel per 2 m (every second tile is plenty under a
## 6-8 m blur), with mipmaps so the shader can read them at the zone edge width.
static func _build_zone_tex(rt: IslandRuntime) -> void:
	var span := rt._tile_span
	var zw := (span + 1) / 2
	var bio := BiomeZones.biome_types(rt)
	var pal := BiomeZones.palette_image(rt._climate)
	var lut := PackedByteArray()
	lut.resize(pal.get_width() * 6)
	for i in pal.get_width():
		var t := pal.get_pixel(i, 0)
		var m := pal.get_pixel(i, 1)
		lut[i * 6] = t.r8
		lut[i * 6 + 1] = t.g8
		lut[i * 6 + 2] = t.b8
		lut[i * 6 + 3] = m.r8
		lut[i * 6 + 4] = m.g8
		lut[i * 6 + 5] = m.b8
	var tint := PackedByteArray()
	tint.resize(zw * zw * 3)
	var mix := PackedByteArray()
	mix.resize(zw * zw * 3)
	var nz := pal.get_width()
	var k := 0
	for zz in zw:
		var row := mini(zz * 2, span - 1) * span
		for zx in zw:
			var idx := row + mini(zx * 2, span - 1)
			var b := int(bio[idx]) if idx < bio.size() else 0
			var o := (b if b < nz else 0) * 6
			tint[k] = lut[o]
			tint[k + 1] = lut[o + 1]
			tint[k + 2] = lut[o + 2]
			mix[k] = lut[o + 3]
			mix[k + 1] = lut[o + 4]
			mix[k + 2] = lut[o + 5]
			k += 3
	var ti := Image.create_from_data(zw, zw, false, Image.FORMAT_RGB8, tint)
	ti.generate_mipmaps()
	rt._zone_tint_tex = ImageTexture.create_from_image(ti)
	var mi := Image.create_from_data(zw, zw, false, Image.FORMAT_RGB8, mix)
	mi.generate_mipmaps()
	rt._zone_mix_tex = ImageTexture.create_from_image(mi)

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
	# One RG8 byte buffer built directly: two byte writes per tile instead of a Color and a
	# set_pixel (0.035 s of the home build). CLIFF keeps writing the GRASS id (see _shader_id).
	var bio := BiomeZones.biome_types(rt)
	var px := PackedByteArray()
	px.resize(span * span * 2)
	var grass := TileType.GRASS
	var tsz := rt.tile_types.size()
	var bsz := bio.size()
	for idx in span * span:
		var t := int(rt.tile_types[idx]) if idx < tsz else 0
		var b := int(bio[idx]) if idx < bsz else 0
		px[idx * 2] = grass if t == TileType.CLIFF else t
		px[idx * 2 + 1] = b
	rt._tile_map_image.set_data(span, span, false, Image.FORMAT_RG8, px)

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
	m.set_shader_parameter("soft_tex", rt._soft_tex)
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
	m.set_shader_parameter("zone_tint_tex", rt._zone_tint_tex)
	m.set_shader_parameter("zone_mix_tex", rt._zone_mix_tex)
	m.set_shader_parameter("zone_texel_m", rt._size / float(rt._zone_tint_tex.get_width()))
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
