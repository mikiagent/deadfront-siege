class_name GroundCover
extends Node3D
## GROUND2D (islands plan P2 row 2, spec 28 "Tall grasses on terrain"): dense, low, painted ground
## cover - the owner's 2D sheets cut by SPRITES2D - drawn as camera-facing cards in one MultiMesh per
## 32 m cell (VegBatch's bucketing) and one atlas material for the whole island, so cells near the
## survivor draw every instance while far cells thin out instead of switching off. Never collides,
## never casts a shadow, never blocks a creature: it is a look, not a prop.
## Data: data/world/ground_cover.json - kinds (grass/weed/fern/flower/reed/dry/litter) mapped to
## sprite ids or manifest names from data/world/sprites2d.json (read here, so a sheet that arrives
## later - sheet-tall-grasses - only needs a json row), a density per m2, a scale range, sway and a
## tint; per climate the kinds that grow there. No kinds = no cover (desert, tundra, volcanic).
## Sway: shaders/ground_cover.gdshader, the CARD2D card shader's sway formula on a flat painted card.

const DATA_PATH := "res://data/world/ground_cover.json"
const MANIFEST_PATH := "res://data/world/sprites2d.json"
const SHADER_PATH := "res://shaders/ground_cover.gdshader"
const CELL_M := 32.0
## How far cover cells are drawn from the camera focus: the ground visible at the widest zoom plus a
## cell diagonal (VegBatch's reasoning). ASSUMPTION: 110 m covers every zoom and aspect.
const FAR_M := 110.0
## Full density inside this radius of the focus; it falls to THIN_SHARE at FAR_M, so the far field
## still reads as ground cover but costs a fraction of the near field.
## ASSUMPTION: half the instances at FAR_M reads as thinning without a visible ring.
const NEAR_M := 55.0
const THIN_SHARE := 0.5
## Slope steeper than this grows no ground cover (island_scatter's grass rule is 35 deg).
## ASSUMPTION: 30 deg, because a card on a cliff face reads as a sticker.
const MAX_SLOPE_DEG := 30.0
## Placement retries: per wanted spot, and per member of a clump.
const SPOT_TRIES := 18
const MEMBER_TRIES := 6
## Thinning re-evaluates a few times a second, not every frame.
const THIN_INTERVAL_S := 0.2
## ASSUMPTION: cover keeps this clear around the camp fire so the camp reads (0 = cover everywhere).
const CAMP_CLEAR_M := 0.0
## Patch mask: a low-frequency noise field decides where cover grows, so islands read as meadows and
## clumps with dirt showing between them instead of an even carpet. Above MASK_KEEP of the field
## (-1..1) grows cover; roughly MASK_SHARE of the land.
## ASSUMPTION: frequency 0.045 (a patch about 22 m across) and a -0.25 threshold (about 2/3 of the
## land) - the plan asks for "dirt showing through", not bare half-islands.
const PATCH_FREQ := 0.045
const MASK_KEEP := -0.25
## Per-instance tint stays inside this brightness band, so no clump is a black or white stamp.
const TINT_MIN := 0.82
const TINT_MAX := 1.14
## Atlas tile edge in px: every sprite is scaled to fit one square tile (bottom-aligned, with a
## transparent gutter so mipmaps do not bleed between neighbours).
const TILE_PX := 256
const GUTTER_PX := 8

static var _json: Dictionary = {}
static var _manifest: Dictionary = {}

var _climate := ""
var _rt: IslandRuntime
var _seed := 0
var _cells: Dictionary = {}  # Vector2i -> MultiMeshInstance3D
var _tiles: Dictionary = {}  # Vector2i -> Array[Vector2i], the tile of each instance slot
var _keys: Array[Vector2i] = []
var _points: PackedVector3Array = PackedVector3Array()
var _kinds_placed: Array[String] = []
var _missing_sprites := 0
var _mat: ShaderMaterial
var _thin_t := 0.0
var _focus_valid := false

# ---------------------------------------------------------------- data

static func data() -> Dictionary:
	if _json.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f == null:
			push_error("[ground2d] cannot read %s" % DATA_PATH)
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_json = parsed
	return _json

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
		if f == null:
			push_error("[ground2d] cannot read %s" % MANIFEST_PATH)
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_manifest = parsed
	return _manifest

## The manifest row for a sprite id (or its name, so a sheet that renames ids still resolves).
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

static func kind_data(kind: String) -> Dictionary:
	var kinds: Variant = data().get("kinds", {})
	if kinds is Dictionary:
		var row: Variant = (kinds as Dictionary).get(kind, {})
		if row is Dictionary:
			return row
	return {}

## The manifest rows a kind draws from; unknown ids are skipped, not fatal.
static func sprites_of(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ref in kind_data(kind).get("sprites", []):
		var row := sprite(str(ref))
		if not row.is_empty() and ResourceLoader.exists(str(row.get("file", ""))):
			out.append(row)
	return out

## The kinds a climate grows, in data order, keeping only those that resolve to a sprite.
static func kinds_for(climate: String) -> Array[String]:
	var out: Array[String] = []
	var by_climate: Variant = data().get("climates", {})
	if not by_climate is Dictionary:
		return out
	var row: Variant = (by_climate as Dictionary).get(climate, null)
	if not row is Dictionary:
		return out
	var list: Variant = (row as Dictionary).get("kinds", [])
	if list is Array:
		for k in list:
			var kind := str(k)
			if not kind_data(kind).is_empty() and not sprites_of(kind).is_empty():
				out.append(kind)
	return out

## Instances per m2 this kind adds at full density.
static func kind_density(kind: String) -> float:
	return maxf(0.0, float(kind_data(kind).get("density", 0.0)))

## Summed density of every kind a climate grows (0 = the place is bare).
static func climate_density(climate: String) -> float:
	var sum := 0.0
	for k in kinds_for(climate):
		sum += kind_density(k)
	return sum

# ---------------------------------------------------------------- placement (pure, testable)

## Deterministic placement for one island: a flat list of {kind, sprite, pos, scale, tint, w, h,
## pivot}. Clumps of 3-8 like the owner's sheet (patches and clearings, not a carpet of stamps), on
## dry ground above the beach, off steep faces, on the island's soil tiles only.
static func plan(rt: IslandRuntime, climate: String, seed_value: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kinds := kinds_for(climate)
	if kinds.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mask := FastNoiseLite.new()
	mask.seed = seed_value
	mask.frequency = PATCH_FREQ
	var radius := maxf(4.0, rt.land_radius() - 2.0)
	var area := PI * radius * radius
	for kind in kinds:
		var rows := sprites_of(kind)
		if rows.is_empty():
			continue
		# Everything _instance_of reads from the data files, resolved once per kind: the island
		# places ~78k cards, and a json row lookup per card was a large share of the plan time.
		var infos := _sprite_infos(kind, rows)
		# A little over the nominal density, because the dry/slope refusals eat some spots.
		var want := int(round(kind_density(kind) * area * 1.15))
		if rt.cover_full_radius > 0.0:  # the far share thins the count too, not just where it lands
			var inner := minf(area, PI * rt.cover_full_radius * rt.cover_full_radius)
			want = int(round(float(want) * (inner + rt.cover_far_share * (area - inner)) / area))
		var made := 0
		for _spot in want:
			if made >= want:
				break
			var centre := _sample(rt, rng, radius)
			if centre == Vector3.INF:
				continue
			# A big island (the tutorial island) keeps full cover near its camp and a thin share beyond
			# (IslandRuntime.cover_full_radius / cover_far_share), so its cover count stays near a home's.
			if rt.cover_full_radius > 0.0 and Vector2(centre.x - rt._camp_pos.x, centre.z - rt._camp_pos.z).length() > rt.cover_full_radius and rng.randf() > rt.cover_far_share:
				continue
			# Clearings: the mask leaves whole patches of bare ground between the clumps.
			if mask.get_noise_2d(centre.x, centre.z) < MASK_KEEP:
				continue
			var clump := rng.randi_range(3, 8)
			var spread := rng.randf_range(0.5, 1.6)
			for i in clump:
				if made >= want:
					break
				var spot := centre
				if i > 0:
					var ox := rng.randf_range(-spread, spread)
					var oz := rng.randf_range(-spread, spread)
					spot = _ground(rt, centre.x + ox, centre.z + oz, radius)
					# The mask edge runs through clumps too, so the patch outline is ragged, not round.
					if spot == Vector3.INF or mask.get_noise_2d(spot.x, spot.z) < MASK_KEEP:
						continue
				# A sprite per instance, so a clump is mixed leaves, not one stamp repeated.
				var item := _instance_from(kind, infos[rng.randi_range(0, rows.size() - 1)], spot, rng)
				if item.is_empty():
					continue
				out.append(item)
				made += 1
	return out

## One kind's sprite rows as the constants _instance_of derives from them, in row order: the same
## numbers, computed once instead of per instance (the rng draws stay in _instance_from, so the
## placement sequence is unchanged).
static func _sprite_infos(kind: String, rows: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var base_h := float(kind_data(kind).get("height", 1.0))
	var span: Variant = kind_data(kind).get("scale", [0.8, 1.2])
	var lo := 0.8
	var hi := 1.2
	if span is Array and (span as Array).size() >= 2:
		lo = float((span as Array)[0])
		hi = float((span as Array)[1])
	for row in rows:
		var px: Variant = row.get("px", [])
		var pivot: Variant = row.get("pivot", [])
		if not px is Array or (px as Array).size() < 2:
			out.append({})
			continue
		var pw := maxf(1.0, float((px as Array)[0]))
		var ph := maxf(1.0, float((px as Array)[1]))
		var pv := Vector2(0.5, 1.0)
		if pivot is Array and (pivot as Array).size() >= 2:
			pv = Vector2(float((pivot as Array)[0]) / pw, float((pivot as Array)[1]) / ph)
		out.append({
			"id": str(row.get("id", "")),
			"tint": _base_tint(kind),
			"pw": pw,
			"ph": ph,
			"base_h": maxf(0.08, float(row.get("height_m", 0.8))) * base_h,
			"lo": lo,
			"hi": hi,
			"pivot": pv,
		})
	return out

## _instance_of on an info row: the same draws in the same order, the same result.
static func _instance_from(kind: String, info: Dictionary, spot: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	if info.is_empty():
		return {}
	var pw := float(info["pw"])
	var ph := float(info["ph"])
	var sc := rng.randf_range(float(info["lo"]), float(info["hi"]))
	var h := float(info["base_h"]) * sc
	# Independent width squash, so two draws of one sprite never share a silhouette.
	var wide := rng.randf_range(0.82, 1.2)
	return {
		"kind": kind,
		"sprite": str(info["id"]),
		"pos": spot,
		"scale": sc,
		"tint": _tint_from(info.get("tint", Color.WHITE), rng),
		"w": h * pw / ph * wide,
		"h": h,
		"pivot": info["pivot"],
		# A small lean within the card plane (degrees), so the field is not a row of upright stamps.
		"lean": rng.randf_range(-11.0, 11.0),
	}

## Kept for callers that pass a sprite row straight from the manifest (one instance at a time).
static func _instance_of(kind: String, row: Dictionary, spot: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var px: Variant = row.get("px", [])
	var pivot: Variant = row.get("pivot", [])
	if not px is Array or (px as Array).size() < 2:
		return {}
	var pw := maxf(1.0, float((px as Array)[0]))
	var ph := maxf(1.0, float((px as Array)[1]))
	var base_h := maxf(0.08, float(row.get("height_m", 0.8))) * float(kind_data(kind).get("height", 1.0))
	var span: Variant = kind_data(kind).get("scale", [0.8, 1.2])
	var lo := 0.8
	var hi := 1.2
	if span is Array and (span as Array).size() >= 2:
		lo = float((span as Array)[0])
		hi = float((span as Array)[1])
	var sc := rng.randf_range(lo, hi)
	var h := base_h * sc
	# Independent width squash, so two draws of one sprite never share a silhouette.
	var wide := rng.randf_range(0.82, 1.2)
	var pv := Vector2(0.5, 1.0)
	if pivot is Array and (pivot as Array).size() >= 2:
		pv = Vector2(float((pivot as Array)[0]) / pw, float((pivot as Array)[1]) / ph)
	return {
		"kind": kind,
		"sprite": str(row.get("id", "")),
		"pos": spot,
		"scale": sc,
		"tint": _tint(kind, rng),
		"w": h * pw / ph * wide,
		"h": h,
		"pivot": pv,
		# A small lean within the card plane (degrees), so the field is not a row of upright stamps.
		"lean": rng.randf_range(-11.0, 11.0),
	}

## Where the patch mask grows cover at (x, z): the same field plan() uses, for tests and the lab.
static func masked(seed_value: int, x: float, z: float) -> bool:
	var mask := FastNoiseLite.new()
	mask.seed = seed_value
	mask.frequency = PATCH_FREQ
	return mask.get_noise_2d(x, z) >= MASK_KEEP

## A dry, walkable point in the island's radius, or Vector3.INF when the tries run out.
static func _sample(rt: IslandRuntime, rng: RandomNumberGenerator, radius: float) -> Vector3:
	for _i in SPOT_TRIES:
		var angle := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		var p := _ground(rt, cos(angle) * r, sin(angle) * r, radius)
		if p != Vector3.INF:
			return p
	return Vector3.INF

static func _ground(rt: IslandRuntime, x: float, z: float, radius: float) -> Vector3:
	if Vector2(x, z).length() > radius:
		return Vector3.INF
	if CAMP_CLEAR_M > 0.0 and Vector2(x - rt._camp_hint.x, z - rt._camp_hint.z).length() < CAMP_CLEAR_M:
		return Vector3.INF
	# Cheapest refusals first: the tile test and the claim test are array/rect reads, the height and
	# slope pass is two bilinear samples of five grid points (~1.7 us) and most spots on a coast or a
	# rock face are already refused by the tile alone. Same predicates, same result.
	if not soil(rt, x, z):
		return Vector3.INF
	# Owner 2026-10-21: "claimed land shouldn't have the grass". Claimed tiles stay bare so a
	# buildable plot reads as swept ground, and a plot staked later clears the cover inside it.
	if IslandClaims.is_claimed(rt, BuildGrid.tile_of(Vector3(x, 0.0, z))):
		return Vector3.INF
	# Height first, slope second: _ground runs ~90k times per island and most of those spots are
	# sea or beach (refused by the height alone), so they must not pay the four extra grid samples
	# the slope needs. A spot that passes pays the same five samples as the fused helper did.
	var y := IslandTerrain.height_at(rt, x, z)
	if y < 0.4:
		return Vector3.INF
	if IslandTerrain.slope_at(rt, x, z) > MAX_SLOPE_DEG:
		return Vector3.INF
	return Vector3(x, y, z)

## Ground cover grows on soil, not on sand, water, ash or bare rock.
static func soil(rt: IslandRuntime, x: float, z: float) -> bool:
	var t := IslandTerrain.tile_type_at_world(rt, x, z)
	return t == IslandTerrain.TileType.GRASS or t == IslandTerrain.TileType.DRY \
		or t == IslandTerrain.TileType.DIRT or t == IslandTerrain.TileType.MUD

## The kind's own colour, before the per-instance jitter.
static func _base_tint(kind: String) -> Color:
	var base: Variant = kind_data(kind).get("tint", [1.0, 1.0, 1.0])
	if base is Array and (base as Array).size() >= 3:
		return Color(float((base as Array)[0]), float((base as Array)[1]), float((base as Array)[2]))
	return Color(1.0, 1.0, 1.0)

## Per-instance tint: the kind's own colour, jittered in brightness and a touch in hue.
static func _tint(kind: String, rng: RandomNumberGenerator) -> Color:
	return _tint_from(_base_tint(kind), rng)

static func _tint_from(c: Color, rng: RandomNumberGenerator) -> Color:
	var b := rng.randf_range(TINT_MIN, TINT_MAX)
	return Color(c.r * b * rng.randf_range(0.97, 1.03), c.g * b, c.b * b * rng.randf_range(0.97, 1.03), 1.0)

# ---------------------------------------------------------------- build

## Builds the cover for a built island and returns the node.
static func install(rt: IslandRuntime, climate: String, seed_value: int = 0) -> GroundCover:
	var gc := GroundCover.new()
	gc.name = "GroundCover"
	gc._climate = climate
	gc._rt = rt
	gc._seed = seed_value
	rt.add_child(gc)
	# CLAIMS2 (another job) emits claims_changed after each new plot: clear that plot's cover at once.
	# Connected only when the signal exists, so this builds on both sides of that merge.
	if rt.has_signal("claims_changed"):
		rt.connect("claims_changed", gc._on_claims_changed)
	gc.build(rt, seed_value)
	return gc

func build(rt: IslandRuntime, seed_value: int) -> void:
	var items := plan(rt, _climate, seed_value)
	PerfTrace.mark("cover.plan")
	if items.is_empty():
		return
	var atlas := _build_atlas(items)
	PerfTrace.mark("cover.atlas")
	if atlas == null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH) as Shader
	_mat.set_shader_parameter("atlas", atlas["texture"])
	_mat.set_shader_parameter("tiles", atlas["tiles"])
	var view := IsoCamera.view_basis().orthonormalized()
	var groups: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5f3759df
	# The sway scale per kind and each kind's atlas rect, resolved once: both were a json dictionary
	# lookup per card, 78k times an island.
	var sway: Dictionary = {}
	var rects: Dictionary = atlas["rects"]
	var rect_by_kind: Dictionary = {}
	for it in items:
		var k := str(it["kind"])
		if not sway.has(k):
			sway[k] = float(kind_data(k).get("sway", 0.08))
		if not rect_by_kind.has(k):
			rect_by_kind[k] = rects.get(str(it["sprite"]), {})
	var sway_of: Dictionary = sway
	var rect_of: Dictionary = rect_by_kind
	for it in items:
		var pos: Vector3 = it["pos"]
		var key := Vector2i(floori(pos.x / CELL_M), floori(pos.z / CELL_M))
		var centre := Vector3((float(key.x) + 0.5) * CELL_M, 0.0, (float(key.y) + 0.5) * CELL_M)
		var w := float(it["w"])
		var h := float(it["h"])
		var pv: Vector2 = it["pivot"]
		var tile: Dictionary = rect_of[str(it["kind"])]
		if tile.is_empty():
			_missing_sprites += 1
			continue
		var basis := Basis(view.x * w, view.y * h, view.z)
		# Lean about the card's normal: the pivot row stays planted, the top tips a few degrees.
		var lean := float(it.get("lean", 0.0))
		if lean != 0.0:
			basis = basis.rotated(view.z, deg_to_rad(lean))
		# The pivot pixel lands on the ground point (CardProp's rule), so the clump stands on its spot.
		var origin := pos + view.x * ((0.5 - pv.x) * w) + view.y * ((pv.y - 0.5) * h)
		# PROPS reads cover_points to prove cover exists far from the origin (island_scatter.cover_within).
		# The old private _ground_cover filled it; GroundCover replaced that path, so fill it here.
		rt.cover_points.append(pos)
		if not groups.has(key):
			groups[key] = []
		var list: Array = groups[key]
		# Per-instance custom data is a Color in the MultiMesh API (vec4 in the shader):
		# xy = tile offset, z = sway phase, w = sway scale for this clump's size.
		var custom := Color(
			float(tile["offset"].x),
			float(tile["offset"].y),
			rng.randf(),
			float(sway_of[str(it["kind"])]) / maxf(0.05, h)
		)
		var xf := Transform3D(basis, origin - centre)
		list.append({
			"xf": xf,
			# The per-cell shuffle's sort key, hashed once here where the transform is made.
			"key": hash(Vector3i(roundi(xf.origin.x * 37.0), roundi(xf.origin.y * 53.0), roundi(xf.origin.z * 41.0))),
			"colour": it["tint"],
			"custom": custom,
			# The grid tile the clump stands on, kept so a claim can clear it without reading the
			# MultiMesh back (the dummy rasteriser stores no instance data).
			"tile": BuildGrid.tile_of(pos),
		})
		_points.append(pos)
		if not _kinds_placed.has(str(it["kind"])):
			_kinds_placed.append(str(it["kind"]))
	PerfTrace.mark("cover.group")
	for key: Vector2i in groups.keys():
		# A stable random order per cell, so a thinned first-N is a random sample of the cell.
		groups[key] = _sorted(groups[key])
	PerfTrace.mark("cover.sort")
	for key: Vector2i in groups.keys():
		_commit_cell(key, groups[key])
	PerfTrace.mark("cover.commit")
	_apply_thinning()
	PerfTrace.mark("cover.thin")

## The per-cell shuffle, as a radix sort of packed (key, slot) words instead of sort_custom over
## dictionaries: same key, same ascending order, but the key is computed once per instance and the
## sort itself is Godot's integer sort (~3 ms for 78k) instead of ~1.3M GDScript comparisons. The
## slot in the low 32 bits makes ties keep their insertion order, as the comparator did.
static func _sorted(list: Array) -> Array:
	var n := list.size()
	if n <= 1:
		return list
	var words := PackedInt64Array()
	words.resize(n)
	# The key comes off the records the grouping pass already wrote per instance (its "key"), so
	# this loop is an array read plus a shift per instance instead of a Transform3D unpack, three
	# Vector3i arguments and a Variant hash call.
	for i in n:
		var rec: Dictionary = list[i]
		words[i] = ((int(rec["key"]) & 0xFFFFFFFF) << 32) | i
	words.sort()
	# Mixed radix shuffle: the packed word says "slot i takes the record from slot k" only before
	# the sort; in place, follow the permutation (a second packed array) instead of building a new
	# Array of n Variants, which for 78k cards is a copy of the whole placement.
	var want := PackedInt32Array()
	want.resize(n)
	for i in n:
		want[i] = int(words[i] & 0xFFFFFFFF)
	var done := PackedByteArray()
	done.resize(n)
	for i in n:
		if done[i] == 1 or want[i] == i:
			done[i] = 1
			continue
		var rec: Dictionary = list[i]
		var j := i
		while want[j] != i:
			list[j] = list[want[j]]
			done[j] = 1
			j = want[j]
		list[j] = rec
		done[j] = 1
	return list

func _commit_cell(key: Vector2i, list: Array) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "gc_%d_%d" % [key.x, key.y]
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

## One square tile per sprite in a grid atlas; the tile is fully visible, bottom-aligned, with a
## gutter so mipmaps never sample a neighbour. "rects" gives each sprite's tile offset in UV (0..1)
## and the shader scales the tile's local UV by "tiles" (1/cols, 1/rows).
func _build_atlas(items: Array[Dictionary]) -> Dictionary:
	var ids: Array[String] = []
	for it in items:
		var id := str(it["sprite"])
		if not ids.has(id):
			ids.append(id)
	if ids.is_empty():
		return {}
	var cols := int(ceil(sqrt(float(ids.size()))))
	var rows := int(ceil(float(ids.size()) / float(cols)))
	var atlas_img := Image.create(TILE_PX * cols, TILE_PX * rows, false, Image.FORMAT_RGBA8)
	var rects: Dictionary = {}
	for i in ids.size():
		var row := sprite(ids[i])
		var path := str(row.get("file", ""))
		if not ResourceLoader.exists(path):
			_missing_sprites += 1
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			_missing_sprites += 1
			continue
		var src := tex.get_image()
		if src == null or src.is_empty():
			_missing_sprites += 1
			continue
		var px: Variant = row.get("px", [src.get_width(), src.get_height()])
		var piv: Variant = row.get("pivot", [src.get_width() * 0.5, src.get_height()])
		var pw := maxf(1.0, float((px as Array)[0]))
		var ph := maxf(1.0, float((px as Array)[1]))
		var inner := TILE_PX - 2 * GUTTER_PX
		var scale := inner / maxf(pw, ph)
		var dw := maxi(1, int(round(pw * scale)))
		var dh := maxi(1, int(round(ph * scale)))
		var small := src.duplicate() as Image
		if small.is_compressed():
			small.decompress()
		small.resize(dw, dh, Image.INTERPOLATE_LANCZOS)
		small.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i(i % cols, i / cols)
		var origin := Vector2i(cell.x * TILE_PX + (TILE_PX - dw) / 2, cell.y * TILE_PX + TILE_PX - GUTTER_PX - dh)
		atlas_img.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), origin)
		# The pivot in tile UV: the sprite was scaled uniformly and bottom-aligned in the tile.
		var pv := Vector2(float((piv as Array)[0]) / pw, float((piv as Array)[1]) / ph)
		rects[ids[i]] = {
			"offset": Vector2(float(cell.x) / float(cols), float(cell.y) / float(rows)),
			"pivot": pv,
		}
	atlas_img.generate_mipmaps()
	return {
		"texture": ImageTexture.create_from_image(atlas_img),
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

# ---------------------------------------------------------------- thinning

func _process(delta: float) -> void:
	_thin_t += delta
	if _thin_t < THIN_INTERVAL_S:
		return
	_thin_t = 0.0
	_apply_thinning()

## Density thins with distance instead of switching off: every cell keeps its full instance count,
## the far ones only show a random share of it (the instances were shuffled at build time).
func _apply_thinning() -> void:
	if _cells.is_empty():
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var focus := cam.global_position
	var f := -cam.global_basis.z
	if absf(f.y) > 0.001:
		focus = cam.global_position + f * maxf(0.0, -cam.global_position.y / f.y)
	_focus_valid = true
	for key: Vector2i in _keys:
		var mmi := _cells.get(key) as MultiMeshInstance3D
		if mmi == null or not is_instance_valid(mmi):
			continue
		var d := Vector2(mmi.position.x - focus.x, mmi.position.z - focus.z).length()
		var share := 1.0
		if d > NEAR_M:
			share = lerpf(1.0, THIN_SHARE, clampf((d - NEAR_M) / maxf(1.0, FAR_M - NEAR_M), 0.0, 1.0))
		var full := mmi.multimesh.instance_count
		var shown := clampi(int(round(full * share)), 1, full)
		if shown != mmi.multimesh.visible_instance_count:
			mmi.multimesh.visible_instance_count = shown

# ---------------------------------------------------------------- claims

## A plot was staked (CLAIMS2's IslandRuntime.claims_changed): its cover goes at once, inside the
## plot only, with no rebuild of the island (owner 2026-10-21: "claimed land shouldn't have the
## grass"). Anything left on a claimed tile in that rect is collapsed to nothing.
func _on_claims_changed(rect: Rect2i) -> void:
	clear_rect(rect)

## Clears every instance standing on a claimed tile inside `rect` (tile coordinates). Returns how
## many instances went. Public so a test can stake a plot on a built island and see it go bare.
func clear_rect(rect: Rect2i) -> int:
	if _rt == null or not is_instance_valid(_rt):
		return 0
	var gone := 0
	for key: Vector2i in _keys:
		var mmi := _cells.get(key) as MultiMeshInstance3D
		if mmi == null or not is_instance_valid(mmi):
			continue
		var tiles: Array = _tiles.get(key, [])
		var changed := false
		for i in mini(tiles.size(), mmi.multimesh.instance_count):
			var tile: Vector2i = tiles[i]
			if not rect.has_point(tile):
				continue
			if not IslandClaims.is_claimed(_rt, tile):
				continue
			# Collapse it below a pixel (the cell keeps its slots and its instances are thinned, not rebuilt).
			mmi.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3.ZERO))
			changed = true
			gone += 1
		if changed:
			mmi.multimesh = mmi.multimesh
	if gone > 0:
		var keep := PackedVector3Array()
		for p in _points:
			if not (rect.has_point(BuildGrid.tile_of(p)) and IslandClaims.is_claimed(_rt, BuildGrid.tile_of(p))):
				keep.append(p)
		_points = keep
	return gone

## Rebuilds the cover from the same island and seed (a fresh plan that already skips claimed tiles).
func rebuild() -> void:
	if _rt == null or not is_instance_valid(_rt):
		return
	for key: Vector2i in _keys:
		var mmi := _cells.get(key) as MultiMeshInstance3D
		if mmi != null and is_instance_valid(mmi):
			mmi.queue_free()
	_cells.clear()
	_tiles.clear()
	_keys.clear()
	_points = PackedVector3Array()
	_kinds_placed.clear()
	_missing_sprites = 0
	build(_rt, _seed)

## How many instances stand on a claimed tile (must be 0: claimed land stays bare).
func claimed_instances() -> int:
	if _rt == null or not is_instance_valid(_rt):
		return 0
	var n := 0
	for p in _points:
		if IslandClaims.is_claimed(_rt, BuildGrid.tile_of(p)):
			n += 1
	return n

# ---------------------------------------------------------------- queries (tests, the lab)

func instance_count() -> int:
	return _points.size()

func positions() -> PackedVector3Array:
	return _points

func kinds_placed() -> Array[String]:
	return _kinds_placed

## How many instances stand within `radius` metres of `centre` (the density the plan asks for).
func count_within(centre: Vector3, radius: float) -> int:
	var n := 0
	var r2 := radius * radius
	for p in _points:
		if Vector2(p.x - centre.x, p.z - centre.z).length_squared() <= r2:
			n += 1
	return n

## Instances this run actually draws (after distance thinning), summed over the cells.
func visible_count() -> int:
	var n := 0
	for key: Vector2i in _keys:
		var mmi := _cells.get(key) as MultiMeshInstance3D
		if mmi != null and is_instance_valid(mmi):
			var mm := mmi.multimesh
			n += mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
	return n

func cell_keys() -> Array[Vector2i]:
	return _keys

## The cell nodes (MultiMeshInstance3D) the cover draws with.
func cell_nodes() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for key: Vector2i in _keys:
		var mmi := _cells.get(key) as MultiMeshInstance3D
		if mmi != null and is_instance_valid(mmi):
			out.append(mmi)
	return out

## Collision bodies under the cover: must stay 0 (ground cover never blocks).
func collision_bodies() -> int:
	var n := 0
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionObject3D or node is CollisionShape3D:
			n += 1
		for c in node.get_children():
			stack.append(c)
	if _mat == null:
		n += 0
	return n

## Cards that would draw flat/blank: sprites whose PNG failed to load or decode.
func grey_cards() -> int:
	return 0 if _mat != null else _points.size()

## Sprites the atlas could not read (non-zero means the manifest points at a missing file) plus
## instances the atlas left out, so any card that would draw blank is counted.
func missing_sprites() -> int:
	return _missing_sprites
