class_name BiomeDress
extends Node3D
## BIOMEDRESS: per-zone scenery dressing from the owner's 2D concept art (spec 26-28,
## docs/reference/biome-concept-*.webp). BiomeZones paints a zone byte per tile; this reads it and
## scatters that zone's painted card kinds (data/world/biome_dress.json) in clumps, so a canyon grows
## rock chunks and blue crystals, a savanna grows straw clumps/termite mounds/aloes, a volcanic basalt
## field grows black basalt and obsidian, wetlands grow reed beds and lily pads along the water, and
## tropical forest grows ferns, bromeliads and young palms.
##
## The cards go through the same per-32-m-cell MultiMesh + atlas path GroundCover uses (one draw call
## per cell, camera-facing quads, sway shader, no shadows), so the dressing is a look, not props:
## nothing here collides, and nothing is ever placed on a claimed tile (the owner's rule) or outside
## the zone a kind belongs to (wrong_biome stays 0).

const DATA_PATH := "res://data/world/biome_dress.json"
const MANIFEST_PATH := "res://data/world/sprites2d.json"
const SHADER_PATH := "res://shaders/ground_cover.gdshader"
const CELL_M := 32.0
## How far cells draw from the focus (the ground visible at the widest zoom, plus a cell diagonal,
## VegBatch's reasoning).
## ASSUMPTION: 110 m, the same reach GROUND2D uses.
const FAR_M := 110.0
## Placement retries per wanted spot and per clump member.
const SPOT_TRIES := 14
const MEMBER_TRIES := 4
## Water margin inspected for "edge" and "coast" kinds (tiles either side).
const MARGIN_TILES := 3
## Per-instance tint brightness band, so no card is a black or white stamp.
const TINT_MIN := 0.9
const TINT_MAX := 1.1
## Atlas tile edge and transparent gutter (GROUND2D's numbers: no mipmap bleed between sprites).
const TILE_PX := 256
const GUTTER_PX := 8
## Water cards float on the water plane instead of the (submerged) river bed.
const WATER_Y := 0.06

static var _json: Dictionary = {}
static var _manifest: Dictionary = {}

var _rt: IslandRuntime
var _seed := 0
var _cells: Dictionary = {}   # Vector2i -> MultiMeshInstance3D
var _tiles: Dictionary = {}   # Vector2i -> Array[Vector2i], tile of each instance slot
var _keys: Array[Vector2i] = []
var _points: PackedVector3Array = PackedVector3Array()
var _kinds: Array[String] = []
var _zones: Array[String] = []
## The kind and sprite of each placed instance by slot (parallel to _points), for the
## wrong-biome check and the lab's per-zone sprite-kind count.
var _rec_kinds: PackedStringArray = PackedStringArray()
var _rec_sprites: PackedStringArray = PackedStringArray()
var _missing := 0
var _mat: ShaderMaterial

# ---------------------------------------------------------------- data

static func data() -> Dictionary:
	if _json.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f == null:
			push_error("[biomedress] cannot read %s" % DATA_PATH)
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_json = parsed
	return _json

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if f == null:
			push_error("[biomedress] cannot read %s" % MANIFEST_PATH)
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_manifest = parsed
	return _manifest

static func sprite(ref: String) -> Dictionary:
	var rows: Variant = manifest().get("sprites", [])
	if not rows is Array:
		return {}
	for row in rows:
		if row is Dictionary and str((row as Dictionary).get("id", "")) == ref:
			return row
	for row in rows:
		if row is Dictionary and str((row as Dictionary).get("name", "")) == ref:
			return row
	return {}

static func kind_data(id: String) -> Dictionary:
	var kinds: Variant = data().get("kinds", {})
	if kinds is Dictionary:
		var row: Variant = (kinds as Dictionary).get(id, {})
		if row is Dictionary:
			return row
	return {}

## The manifest rows a kind draws from; unknown or missing files are skipped, never fatal.
static func sprites_of(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ref in kind_data(id).get("sprites", []):
		var row := sprite(str(ref))
		if not row.is_empty() and ResourceLoader.exists(str(row.get("file", ""))):
			out.append(row)
	return out

## The kind ids a zone's dressing set lists, in data order, keeping only those that resolve to a
## sprite and that declare this zone (a kind never grows outside its list).
static func zone_kinds(zone: String) -> Array[String]:
	var out: Array[String] = []
	var z: Variant = (data().get("zones", {}) as Dictionary).get(zone, {})
	if not z is Dictionary:
		return out
	var list: Variant = (z as Dictionary).get("kinds", [])
	if not list is Array:
		return out
	for e in list:
		if not e is Dictionary:
			continue
		var id := str((e as Dictionary).get("id", ""))
		var row := kind_data(id)
		if row.is_empty() or not (row.get("zones", []) as Array).has(zone):
			continue
		if not sprites_of(id).is_empty() and not out.has(id):
			out.append(id)
	return out

static func density_of(zone: String, id: String) -> float:
	var z: Variant = (data().get("zones", {}) as Dictionary).get(zone, {})
	if z is Dictionary:
		for e in (z as Dictionary).get("kinds", []):
			if e is Dictionary and str((e as Dictionary).get("id", "")) == id:
				return maxf(0.0, float((e as Dictionary).get("density", 0.0)))
	return 0.0

static func min_zone_tiles() -> int:
	return maxi(1, int(data().get("min_zone_tiles", 40)))

# ---------------------------------------------------------------- placement (pure, testable)

## Deterministic dressing for one island: a flat list of {kind, zone, sprite, pos, scale, w, h,
## pivot, tint, lean}. Kinds clump (each spot plants 1-6 cards within a metre or two), zones are
## picked tile by tile so a kind can only ever land inside its own zone, and claimed tiles, water
## for land kinds, land for water kinds and steep faces are refused.
static func plan(rt: IslandRuntime, seed_value: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var zones_arr := BiomeZones.biome_types(rt)
	if rt == null or zones_arr.is_empty() or rt.tile_types.size() < zones_arr.size():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Land tiles per zone (water tiles excluded: they only feed the water/edge filters).
	var by_zone: Dictionary = {}
	for i in zones_arr.size():
		var t := int(rt.tile_types[i])
		if t == IslandTerrain.TileType.DEEP or t == IslandTerrain.TileType.SHALLOW:
			continue
		var z := int(zones_arr[i])
		if not by_zone.has(z):
			by_zone[z] = PackedInt32Array()
		var arr: PackedInt32Array = by_zone[z]
		arr.append(i)
		by_zone[z] = arr
	var span := rt._tile_span
	var half := rt._size * 0.5
	var zone_count := BiomeZones.zone_count()
	for z in range(zone_count):
		if not by_zone.has(z):
			continue
		var tiles: PackedInt32Array = by_zone[z]
		if tiles.size() < min_zone_tiles():
			continue
		var zone := BiomeZones.zone_name(z)
		for id in zone_kinds(zone):
			var rows := sprites_of(id)
			var want := maxi(2, int(round(density_of(zone, id) * float(tiles.size()))))
			var made := 0
			for _spot in want:
				if made >= want:
					break
				var centre := Vector3.INF
				for _try in SPOT_TRIES:
					var idx := tiles[rng.randi_range(0, tiles.size() - 1)]
					var tx := idx % span
					var tz := idx / span
					var wx := -half + float(tx) + 0.5 + rng.randf_range(-0.45, 0.45)
					var wz := -half + float(tz) + 0.5 + rng.randf_range(-0.45, 0.45)
					var p := spot_ok(rt, zone, id, wx, wz)
					if p != Vector3.INF:
						centre = p
						break
				if centre == Vector3.INF:
					continue
				var counts: Variant = kind_data(id).get("clump", [1, 2])
				var lo := 1
				var hi := 2
				if counts is Array and (counts as Array).size() >= 2:
					lo = maxi(1, int((counts as Array)[0]))
					hi = maxi(lo, int((counts as Array)[1]))
				var members := rng.randi_range(lo, hi)
				var spread := float(kind_data(id).get("spread", 1.0))
				for m in members:
					if made >= want:
						break
					var p := centre
					if m > 0:
						p = Vector3.INF
						for _mtry in MEMBER_TRIES:
							var ox := rng.randf_range(-spread, spread)
							var oz := rng.randf_range(-spread, spread)
							var q := spot_ok(rt, zone, id, centre.x + ox, centre.z + oz)
							if q != Vector3.INF:
								p = q
								break
						if p == Vector3.INF:
							continue
					var item := _instance_of(id, zone, rows[rng.randi_range(0, rows.size() - 1)], p, rng)
					if item.is_empty():
						continue
					out.append(item)
					made += 1
	return out

## Whether `id` (of `zone`) may stand at (x, z), and the ground point if so.
static func spot_ok(rt: IslandRuntime, zone: String, id: String, x: float, z: float) -> Vector3:
	var row := kind_data(id)
	if row.is_empty() or not (row.get("zones", []) as Array).has(zone):
		return Vector3.INF
	if rt == null or not rt.is_dry(Vector3(x, 0.0, z)) and not _wet(rt, x, z):
		return Vector3.INF
	# The zone is re-read at the exact point: a jittered or clumped member never leaks across a border.
	if BiomeZones.zone_name(BiomeZones.biome_at(rt, x, z)) != zone:
		return Vector3.INF
	var tile := BuildGrid.tile_of(Vector3(x, 0.0, z))
	if IslandClaims.is_claimed(rt, tile):
		return Vector3.INF
	var t := IslandTerrain.tile_type_at_world(rt, x, z)
	var where := str(row.get("where", "ground"))
	match where:
		"water":
			if not (t == IslandTerrain.TileType.MUD or t == IslandTerrain.TileType.SHALLOW
					or t == IslandTerrain.TileType.WET):
				return Vector3.INF
			return Vector3(x, WATER_Y, z)
		"edge":
			if t == IslandTerrain.TileType.DEEP or t == IslandTerrain.TileType.SHALLOW:
				return Vector3.INF
			if not _near_water(rt, x, z):
				return Vector3.INF
		"coast":
			if not _near_sand(rt, x, z):
				return Vector3.INF
		"ground":
			if not soil(t):
				return Vector3.INF
		"any":
			pass
	if IslandTerrain.slope_deg(rt, x, z) > 30.0:
		return Vector3.INF
	var y := rt.surface_y(x, z)
	if y < 0.2:
		return Vector3.INF
	return Vector3(x, y, z)

static func soil(t: int) -> bool:
	return t == IslandTerrain.TileType.GRASS or t == IslandTerrain.TileType.DRY \
		or t == IslandTerrain.TileType.DIRT or t == IslandTerrain.TileType.MUD \
		or t == IslandTerrain.TileType.BARE

static func _wet(rt: IslandRuntime, x: float, z: float) -> bool:
	var t := IslandTerrain.tile_type_at_world(rt, x, z)
	return t == IslandTerrain.TileType.MUD or t == IslandTerrain.TileType.SHALLOW \
		or t == IslandTerrain.TileType.WET

## Fresh or still water within MARGIN_TILES metres (the reed beds hug the river and ponds).
static func _near_water(rt: IslandRuntime, x: float, z: float) -> bool:
	for dz in range(-MARGIN_TILES, MARGIN_TILES + 1):
		for dx in range(-MARGIN_TILES, MARGIN_TILES + 1):
			if dx * dx + dz * dz > MARGIN_TILES * MARGIN_TILES:
				continue
			if _wet(rt, x + float(dx), z + float(dz)):
				return true
			if IslandTerrain.fresh_water_at_world(rt, x + float(dx), z + float(dz)):
				return true
	return false

## Sand or the sea within MARGIN_TILES metres (shells and driftwood lie on the beach band).
static func _near_sand(rt: IslandRuntime, x: float, z: float) -> bool:
	for dz in range(-MARGIN_TILES, MARGIN_TILES + 1):
		for dx in range(-MARGIN_TILES, MARGIN_TILES + 1):
			if dx * dx + dz * dz > MARGIN_TILES * MARGIN_TILES:
				continue
			var t := IslandTerrain.tile_type_at_world(rt, x + float(dx), z + float(dz))
			if t == IslandTerrain.TileType.SAND or t == IslandTerrain.TileType.SHALLOW:
				return true
	return false

static func _instance_of(id: String, zone: String, row: Dictionary, spot: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var px: Variant = row.get("px", [])
	var pivot: Variant = row.get("pivot", [])
	if not px is Array or (px as Array).size() < 2:
		return {}
	var pw := maxf(1.0, float((px as Array)[0]))
	var ph := maxf(1.0, float((px as Array)[1]))
	var base_h := maxf(0.08, float(row.get("height_m", 0.8))) * float(kind_data(id).get("height", 1.0))
	var span: Variant = kind_data(id).get("scale", [0.8, 1.2])
	var lo := 0.8
	var hi := 1.2
	if span is Array and (span as Array).size() >= 2:
		lo = float((span as Array)[0])
		hi = float((span as Array)[1])
	var sc := rng.randf_range(lo, hi)
	var h := base_h * sc
	var wide := rng.randf_range(0.86, 1.18)
	var pv := Vector2(0.5, 1.0)
	if pivot is Array and (pivot as Array).size() >= 2:
		pv = Vector2(float((pivot as Array)[0]) / pw, float((pivot as Array)[1]) / ph)
	return {
		"kind": id,
		"zone": zone,
		"sprite": str(row.get("id", "")),
		"pos": spot,
		"scale": sc,
		"tint": _tint(id, rng),
		"w": h * pw / ph * wide,
		"h": h,
		"pivot": pv,
		"lean": rng.randf_range(-9.0, 9.0),
	}

static func _tint(id: String, rng: RandomNumberGenerator) -> Color:
	var base: Variant = kind_data(id).get("tint", [1.0, 1.0, 1.0])
	var c := Color(1.0, 1.0, 1.0)
	if base is Array and (base as Array).size() >= 3:
		c = Color(float((base as Array)[0]), float((base as Array)[1]), float((base as Array)[2]))
	var b := rng.randf_range(TINT_MIN, TINT_MAX)
	return Color(c.r * b * rng.randf_range(0.97, 1.03), c.g * b, c.b * b * rng.randf_range(0.97, 1.03), 1.0)

# ---------------------------------------------------------------- build

## Builds the dressing for a built island and returns the node (empty node when no zone qualifies).
static func install(rt: IslandRuntime, seed_value: int = 0) -> BiomeDress:
	var bd := BiomeDress.new()
	bd.name = "BiomeDress"
	bd._rt = rt
	bd._seed = seed_value
	rt.add_child(bd)
	bd.build(rt, seed_value)
	return bd

func build(rt: IslandRuntime, seed_value: int) -> void:
	var items := plan(rt, seed_value)
	_points = PackedVector3Array()
	_kinds.clear()
	_zones.clear()
	_rec_kinds = PackedStringArray()
	_rec_sprites = PackedStringArray()
	if items.is_empty():
		return
	var atlas := _build_atlas(items)
	if atlas.is_empty():
		return
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH) as Shader
	_mat.set_shader_parameter("atlas", atlas["texture"])
	_mat.set_shader_parameter("tiles", atlas["tiles"])
	_mat.set_shader_parameter("sway_speed", 1.2)
	var view := IsoCamera.view_basis().orthonormalized()
	var groups: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x2545f491
	for it in items:
		var pos: Vector3 = it["pos"]
		var key := Vector2i(floori(pos.x / CELL_M), floori(pos.z / CELL_M))
		var centre := Vector3((float(key.x) + 0.5) * CELL_M, 0.0, (float(key.y) + 0.5) * CELL_M)
		var w := float(it["w"])
		var h := float(it["h"])
		var pv: Vector2 = it["pivot"]
		var tile: Dictionary = atlas["rects"].get(str(it["sprite"]), {})
		if tile.is_empty():
			_missing += 1
			continue
		var basis := Basis(view.x * w, view.y * h, view.z)
		var lean := float(it.get("lean", 0.0))
		if lean != 0.0:
			basis = basis.rotated(view.z, deg_to_rad(lean))
		var origin := pos + view.x * ((0.5 - pv.x) * w) + view.y * ((pv.y - 0.5) * h)
		_points.append(pos)
		_rec_kinds.append(str(it["kind"]))
		_rec_sprites.append(str(it["sprite"]))
		if not _kinds.has(str(it["kind"])):
			_kinds.append(str(it["kind"]))
		if not _zones.has(str(it["zone"])):
			_zones.append(str(it["zone"]))
		if not groups.has(key):
			groups[key] = []
		var list: Array = groups[key]
		var sway := float(kind_data(str(it["kind"])).get("sway", 0.04)) / maxf(0.05, h)
		list.append({
			"xf": Transform3D(basis, origin - centre),
			"colour": it["tint"],
			"custom": Color(float(tile["offset"].x), float(tile["offset"].y), rng.randf(), sway),
			"tile": BuildGrid.tile_of(pos),
		})
	for key: Vector2i in groups.keys():
		_commit_cell(key, groups[key])

func _commit_cell(key: Vector2i, list: Array) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "bd_%d_%d" % [key.x, key.y]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _quad()
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i]["xf"])
		mm.set_instance_color(i, list[i]["colour"])
		mm.set_instance_custom_data(i, list[i]["custom"])
	mmi.multimesh = mm
	mmi.position = Vector3((float(key.x) + 0.5) * CELL_M, 0.0, (float(key.y) + 0.5) * CELL_M)
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = IsoCamera.cull_range(FAR_M + CELL_M)
	add_child(mmi)
	_cells[key] = mmi
	_tiles[key] = list.map(func (it: Dictionary) -> Vector2i: return it["tile"])
	_keys.append(key)

func _build_atlas(items: Array[Dictionary]) -> Dictionary:
	var ids: Array[String] = []
	for it in items:
		var sid := str(it["sprite"])
		if not ids.has(sid):
			ids.append(sid)
	if ids.is_empty():
		return {}
	var cols := int(ceil(sqrt(float(ids.size()))))
	var rows := int(ceil(float(ids.size()) / float(cols)))
	var img := Image.create(TILE_PX * cols, TILE_PX * rows, false, Image.FORMAT_RGBA8)
	var rects: Dictionary = {}
	for i in ids.size():
		var row := sprite(ids[i])
		var path := str(row.get("file", ""))
		if not ResourceLoader.exists(path):
			_missing += 1
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			_missing += 1
			continue
		var src := tex.get_image()
		if src == null or src.is_empty():
			_missing += 1
			continue
		var px: Variant = row.get("px", [src.get_width(), src.get_height()])
		var piv: Variant = row.get("pivot", [src.get_width() * 0.5, src.get_height()])
		var pw := maxf(1.0, float((px as Array)[0]))
		var ph := maxf(1.0, float((px as Array)[1]))
		var inner := TILE_PX - 2 * GUTTER_PX
		var sc := inner / maxf(pw, ph)
		var dw := maxi(1, int(round(pw * sc)))
		var dh := maxi(1, int(round(ph * sc)))
		var small := src.duplicate() as Image
		if small.is_compressed():
			small.decompress()
		small.resize(dw, dh, Image.INTERPOLATE_LANCZOS)
		small.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i(i % cols, i / cols)
		var origin := Vector2i(cell.x * TILE_PX + (TILE_PX - dw) / 2, cell.y * TILE_PX + TILE_PX - GUTTER_PX - dh)
		img.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), origin)
		var pv := Vector2(float((piv as Array)[0]) / pw, float((piv as Array)[1]) / ph)
		rects[ids[i]] = {
			"offset": Vector2(float(cell.x) / float(cols), float(cell.y) / float(rows)),
			"pivot": pv,
		}
	img.generate_mipmaps()
	return {
		"texture": ImageTexture.create_from_image(img),
		"tiles": Vector2(1.0 / float(cols), 1.0 / float(rows)),
		"rects": rects,
	}

static var _quad_mesh: PlaneMesh
static func _quad() -> PlaneMesh:
	if _quad_mesh == null:
		_quad_mesh = PlaneMesh.new()
		_quad_mesh.orientation = PlaneMesh.FACE_Z
		_quad_mesh.size = Vector2.ONE
	return _quad_mesh

# ---------------------------------------------------------------- queries (tests, the lab)

func instance_count() -> int:
	return _points.size()

func positions() -> PackedVector3Array:
	return _points

func kinds_placed() -> Array[String]:
	return _kinds

func zones_placed() -> Array[String]:
	return _zones

## How many instances stand on a claimed tile (must be 0: claimed land stays bare).
func claimed_instances() -> int:
	if _rt == null or not is_instance_valid(_rt):
		return 0
	var n := 0
	for p in _points:
		if IslandClaims.is_claimed(_rt, BuildGrid.tile_of(p)):
			n += 1
	return n

## Instances of a kind standing outside the zones the kind lists (must be 0: wrong_biome). The
## instance's own kind is kept per slot, and the zone is re-read live from the tile map, so a kind
## that leaked across a zone border (or into a zone its row does not list) is counted here.
func wrong_biome_instances() -> int:
	if _rt == null or not is_instance_valid(_rt):
		return 0
	var n := 0
	for i in mini(_points.size(), _rec_kinds.size()):
		var p := _points[i]
		var zone := BiomeZones.zone_name(BiomeZones.biome_at(_rt, p.x, p.z))
		if not (kind_data(str(_rec_kinds[i])).get("zones", []) as Array).has(zone):
			n += 1
	return n

## The distinct sprite ids standing in `zone` (the lab's per-zone sprite-kind count), measured
## from the placed instances, not from the data file.
func sprites_in_zone(zone: String) -> Dictionary:
	var out: Dictionary = {}
	if _rt == null or not is_instance_valid(_rt):
		return out
	for i in mini(_points.size(), _rec_sprites.size()):
		var p := _points[i]
		if BiomeZones.zone_name(BiomeZones.biome_at(_rt, p.x, p.z)) != zone:
			continue
		out[str(_rec_sprites[i])] = true
	return out

## How many cards stand in `zone`, and the point of the card nearest their centroid (a dense
## representative spot for the lab's camera).
func zone_spot(zone: String) -> Dictionary:
	var sum := Vector3.ZERO
	var n := 0
	for i in mini(_points.size(), _rec_kinds.size()):
		var p := _points[i]
		if BiomeZones.zone_name(BiomeZones.biome_at(_rt, p.x, p.z)) != zone:
			continue
		sum += p
		n += 1
	if n == 0:
		return {}
	var centre := sum / float(n)
	var best := Vector3.INF
	var best_d := INF
	for i in mini(_points.size(), _rec_kinds.size()):
		var p := _points[i]
		if BiomeZones.zone_name(BiomeZones.biome_at(_rt, p.x, p.z)) != zone:
			continue
		var d := Vector2(p.x - centre.x, p.z - centre.z).length()
		if d < best_d:
			best_d = d
			best = p
	return {"count": n, "point": best, "centroid": centre}

func cell_nodes() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for key: Vector2i in _keys:
		var mmi := _cells.get(key) as MultiMeshInstance3D
		if mmi != null and is_instance_valid(mmi):
			out.append(mmi)
	return out

func visible_count() -> int:
	var n := 0
	for mmi in cell_nodes():
		var mm := mmi.multimesh
		n += mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
	return n

## Collision bodies under the dressing: must stay 0 (it is a look, never a blocker).
func collision_bodies() -> int:
	var n := 0
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionObject3D or node is CollisionShape3D:
			n += 1
		for c in node.get_children():
			stack.append(c)
	return n

func missing_sprites() -> int:
	return _missing
