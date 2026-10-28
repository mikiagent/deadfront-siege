class_name BiomeZones
extends RefCounted
## Biome zones painted per tile (data in data/world/biomes.json).
##
## Eight zones, one byte id per tile, stored per island and written into the G channel of the tile
## map image. The zone is picked from what the land is doing there - beach on the low fringe behind
## the sand, wetland along the river, the climate's rock zone on steep or high ground - and otherwise
## from a moisture noise through the climate's own zone weights, so every island has several patches
## and no two climates share a table. The terrain shader and the minimap read the same id.
##
## Density multipliers (node_mult/prop_mult) are exposed for the scatter/props jobs; nothing here
## moves a node.

const ZONE_NAMES: Array[String] = ["meadow", "forest", "savanna", "canyon", "basalt", "wetland", "beach", "rocky"]

## Default zone when a climate has no row (should not happen: t_biomes checks every climate).
const FALLBACK_ROW := {"base": "meadow", "lush": "forest", "dry": "savanna", "rock": "rocky"}

## ASSUMPTION: every distance/height below is ours. The plan fixes the order of the rules
## (coast, river, slope/high ground, then moisture) but not the numbers; the plan's dev log has
## "coast < 14 m" and "river < 12 m" for a 416 m home island, so those are kept where they fit and
## the beach becomes a height band because a 14 m coastal ring covers most of a 120 m island.
const DEFAULT_RULES := {
	"beach_share": 0.5,
	"beach_width_m": [4.0, 10.0],
	"beach_max_slope": 0.45,
	"beach_max_h": 2.0,
	"river_m": 12.0,
	"rock_slope_deg": 27.0,
	"high_fraction": 0.85,
	"moist_hi": 0.62,
	"moist_lo": 0.35,
	"camp_radius_m": 60.0,
	"filter_radius_tiles": 2,
	"min_region_tiles": 400,
}

static var _tables: Dictionary = {}

static func table() -> Dictionary:
	if _tables.is_empty():
		_tables = BiomeMaterial.rows()
	return _tables

static func zones() -> Dictionary:
	var z: Variant = table().get("zones", {})
	return z if z is Dictionary else {}

static func rules() -> Dictionary:
	var out := DEFAULT_RULES.duplicate()
	var r: Variant = table().get("zone_rules", {})
	if r is Dictionary:
		for k in r:
			out[str(k)] = r[k]
	return out

static func zone_count() -> int:
	return ZONE_NAMES.size()

static func zone_id(zone: String) -> int:
	return ZONE_NAMES.find(zone)

static func zone_name(id: int) -> String:
	if id < 0 or id >= ZONE_NAMES.size():
		return "none"
	return ZONE_NAMES[id]

static func zone_row(id: int) -> Dictionary:
	var z := zones()
	var key := zone_name(id)
	var row: Variant = z.get(key, {})
	return row if row is Dictionary else {}

static func row_of(zone: String) -> Dictionary:
	var z := zones()
	var row: Variant = z.get(zone, {})
	return row if row is Dictionary else {}

## Climate row: {base,lush,dry,rock,weights,tints} with every zone name checked against ZONE_NAMES.
static func climate_row(climate: String) -> Dictionary:
	var b := BiomeMaterial.row(climate)
	var from_file: Dictionary = {}
	var z: Variant = b.get("zones", {})
	if z is Dictionary:
		from_file = z
	var out := {
		"base": str(from_file.get("base", FALLBACK_ROW["base"])),
		"lush": str(from_file.get("lush", FALLBACK_ROW["lush"])),
		"dry": str(from_file.get("dry", FALLBACK_ROW["dry"])),
		"rock": str(from_file.get("rock", from_file.get("dry", FALLBACK_ROW["rock"]))),
		"weights": {},
		"tints": {},
	}
	for key in ["base", "lush", "dry", "rock"]:
		if not str(out[key]) in ZONE_NAMES:
			out[key] = FALLBACK_ROW[key]
	var w: Variant = from_file.get("weights", {})
	if w is Dictionary:
		out["weights"] = w
	var t: Variant = from_file.get("tints", {})
	if t is Dictionary:
		out["tints"] = t
	return out

## A zone's ground tint on this climate: its own row colour, overridden per climate where the
## climate's baked ground must not wear another biome's hue (tundra and snowfield never go golden).
static func zone_tint(zone: int, climate: String) -> Color:
	var override: Variant = climate_row(climate)["tints"].get(zone_name(zone), null)
	if override is String:
		return Color.from_string(str(override), Color.WHITE)
	return Color.from_string(str(zone_row(zone).get("tint", "#ffffff")), Color.WHITE)

## The minimap/atlas colour for a zone on this climate (same per-climate override, flattened).
static func map_color(zone: int, climate: String) -> Color:
	var override: Variant = climate_row(climate)["tints"].get(zone_name(zone), null)
	if override is String:
		return Color.from_string(str(override), Color(0.36, 0.52, 0.28)) * 0.88
	return Color.from_string(str(zone_row(zone).get("map", "#7fa156")), Color(0.36, 0.52, 0.28))

## Density multiplier for one family group ("tree", "bush", "rock", "plant") in a zone.
static func density(zone: int, group: String) -> float:
	var mult: Variant = zone_row(zone).get("node_mult", {})
	if mult is Dictionary:
		return float((mult as Dictionary).get(group, 1.0))
	return 1.0

## Ground-cover (grass/flower props) multiplier for a zone.
static func prop_density(zone: int, group: String) -> float:
	var mult: Variant = zone_row(zone).get("prop_mult", {})
	if mult is Dictionary:
		return float((mult as Dictionary).get(group, 1.0))
	return 1.0

## The per-tile zone array. island_runtime.gd is another job's file, so until its one-line
## `var biome_types: PackedByteArray` lands (docs/orchestration/reports/dsc-biomezones-hooks.patch)
## the array lives in the runtime's metadata; every reader goes through this pair.
static func biome_types(rt: IslandRuntime) -> PackedByteArray:
	if rt == null:
		return PackedByteArray()
	var v: Variant = rt.get_meta("biome_types", null)
	return v if v is PackedByteArray else PackedByteArray()

static func install(rt: IslandRuntime, zones: PackedByteArray) -> void:
	rt.set_meta("biome_types", zones)

## The zone at a world position (no map reads as meadow).
static func biome_at(rt: IslandRuntime, x: float, z: float) -> int:
	var arr := biome_types(rt)
	if rt == null or arr.is_empty() or rt._tile_span <= 0:
		return 0
	var tx := clampi(int(floor(x + rt._size * 0.5)), 0, rt._tile_span - 1)
	var tz := clampi(int(floor(z + rt._size * 0.5)), 0, rt._tile_span - 1)
	var b := int(arr[tx + tz * rt._tile_span])
	return b if b < ZONE_NAMES.size() else 0

## Everything the per-tile assignment needs, built once per island.
## high_h is the height that the top (1 - high_fraction) of dry land sits above.
## seed comes from the island (its layout seed), not the climate: two grassland islands must not
## share a moisture field.
static func context(rt: IslandRuntime, climate: String, camp: Vector3, seed: int) -> Dictionary:
	var clim := climate_row(climate)
	var dry: Array[float] = []
	var step := maxi(1, int(rt._res / 40))  # sample the heightmap, not every cell
	for z in range(0, rt._res, step):
		for x in range(0, rt._res, step):
			var h := rt._heights[x + z * rt._res]
			if h > 0.55:
				dry.append(h)
	dry.sort()
	var frac := float(rules()["high_fraction"])
	var high_h := 99.0
	if not dry.is_empty():
		high_h = dry[clampi(int(float(dry.size()) * frac), 0, dry.size() - 1)]
	var moist := FastNoiseLite.new()
	moist.seed = seed + 733
	moist.frequency = 0.0095  # ASSUMPTION: 60-90 m patches, the plan's moisture scale
	moist.fractal_octaves = 2
	var pick := FastNoiseLite.new()
	pick.seed = seed + 1777
	pick.frequency = 0.006
	# Zones reachable by the moisture pick: every weighted zone that is not painted geographically.
	var geo := ["beach", "wetland", str(clim["rock"])]
	var veg: Array[int] = []
	var cum := PackedFloat32Array([0.0])
	var total := 0.0
	var weights: Dictionary = clim["weights"]
	for zname in weights:
		if str(zname) in geo or not str(zname) in ZONE_NAMES:
			continue
		var w := maxf(0.0, float(weights[zname]))
		if w <= 0.0:
			continue
		veg.append(zone_id(str(zname)))
		total += w
		cum.append(total)
	if veg.is_empty():
		veg = [zone_id(str(clim["base"])), zone_id(str(clim["lush"]))]
		cum = PackedFloat32Array([0.0, 1.0, 2.0])
		total = 2.0
	for i in cum.size():
		cum[i] = cum[i] / maxf(0.001, total)
	return {
		"climate": climate,
		"rules": rules(),
		"base": zone_id(str(clim["base"])),
		"lush": zone_id(str(clim["lush"])),
		"dry": zone_id(str(clim["dry"])),
		"rock": zone_id(str(clim["rock"])),
		"veg": veg,
		"cum": cum,
		"high_h": high_h,
		"land_radius": rt.land_radius(),
		"camp": camp,
		"moist": moist,
		"pick": pick,
	}

## One tile's zone. wx/wz are world metres, h the surface height, slope in degrees,
## river_d the distance to the river centreline.
static func zone_of(ctx: Dictionary, wx: float, wz: float, h: float, slope: float, river_d: float) -> int:
	var r: Dictionary = ctx["rules"]
	# The waterline band is beach everywhere; the sandy beaches behind it are stretches of the coast
	# only (IslandTerrain._beach_plan paints them after the zones are smoothed).
	if h < float(r.get("beach_low_h", 0.55)):
		return zone_id("beach")
	var camp: Vector3 = ctx["camp"]
	# ASSUMPTION: the camp clearing keeps meadow for the inner third of the plan's 60 m core.
	if camp != Vector3.ZERO and Vector2(wx - camp.x, wz - camp.z).length() < float(r["camp_radius_m"]) * 0.35:
		return zone_id("meadow")
	if river_d < float(r["river_m"]):
		return zone_id("wetland")
	if slope > float(r["rock_slope_deg"]) or h > float(ctx["high_h"]):
		return int(ctx["rock"])
	# Moisture decides between this climate's vegetation zones, in its own proportions.
	var moist: FastNoiseLite = ctx["moist"]
	var pick: FastNoiseLite = ctx["pick"]
	var m := moist.get_noise_2d(wx, wz) * 0.6 + pick.get_noise_2d(wx, wz) * 0.4
	var u := clampf(m * 0.9 + 0.5, 0.0, 0.999)  # ASSUMPTION: +-0.56 noise mapped onto 0..1
	var veg: Array[int] = ctx["veg"]
	var cum: PackedFloat32Array = ctx["cum"]
	for i in veg.size():
		if u < cum[i + 1]:
			return veg[i]
	return veg[veg.size() - 1]

## Post-pass on the painted map: a src-to-dst majority filter (so zone edges read as patches, not
## speckle), then regions under min_region_tiles join their largest neighbour. Water tiles keep
## whatever id they had, and are never used as a source.
static func smooth(rt: IslandRuntime, radius: int = -1) -> void:
	var current := biome_types(rt)
	if current.is_empty():
		return
	var span := rt._tile_span
	var types: PackedByteArray = rt.tile_types
	var r := radius
	if r < 0:
		r = int(rules().get("filter_radius_tiles", 2))
	var dst := current.duplicate()
	if r > 0:
		var counts := PackedByteArray()
		counts.resize(zone_count())
		for z in span:
			for x in span:
				var idx := x + z * span
				var t := int(types[idx]) if idx < types.size() else 0
				if _is_water(t):
					continue
				counts.fill(0)
				var best := int(current[idx])
				var best_n := 0
				var sx0 := maxi(0, x - r)
				var sx1 := mini(span - 1, x + r)
				var sz0 := maxi(0, z - r)
				var sz1 := mini(span - 1, z + r)
				for zz in range(sz0, sz1 + 1):
					for xx in range(sx0, sx1 + 1):
						var nidx := xx + zz * span
						var nt := int(types[nidx]) if nidx < types.size() else 0
						if _is_water(nt):
							continue
						var b := int(current[nidx])
						if b < counts.size():
							counts[b] += 1
				for b in counts.size():
					if int(counts[b]) > best_n:
						best_n = int(counts[b])
						best = b
				dst[idx] = best
	_merge_small(rt, dst, int(rules().get("min_region_tiles", 400)))
	install(rt, dst)

## Every 4-connected region under min_tiles switches to the zone that most of its border touches.
## ASSUMPTION: 400 m2 is the plan's figure; at 1 m tiles (or 2.5-3.75 m cells) that is 400-3136 tiles.
static func _merge_small(rt: IslandRuntime, zones_arr: PackedByteArray, min_tiles: int) -> void:
	if min_tiles <= 0:
		return
	var span := rt._tile_span
	var types: PackedByteArray = rt.tile_types
	var seen := PackedByteArray()
	seen.resize(span * span)
	var stack := PackedInt32Array()
	var region := PackedInt32Array()
	var border := PackedByteArray()
	border.resize(zone_count())
	for start in span * span:
		if int(seen[start]) == 1:
			continue
		var t0 := int(types[start]) if start < types.size() else 0
		if _is_water(t0):
			seen[start] = 1
			continue
		var zone0 := int(zones_arr[start])
		region.clear()
		stack.clear()
		stack.append(start)
		seen[start] = 1
		border.fill(0)
		while not stack.is_empty():
			var idx := int(stack[stack.size() - 1])
			stack.remove_at(stack.size() - 1)
			region.append(idx)
			var x := idx % span
			var z := idx / span
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var nz := z + d.y
				if nx < 0 or nz < 0 or nx >= span or nz >= span:
					continue
				var nidx := nx + nz * span
				var nt := int(types[nidx]) if nidx < types.size() else 0
				if _is_water(nt):
					continue
				var nz2 := int(zones_arr[nidx])
				if nz2 == zone0:
					if int(seen[nidx]) == 0:
						seen[nidx] = 1
						stack.append(nidx)
				elif nz2 < border.size():
					border[nz2] += 1
		if region.size() >= min_tiles:
			continue
		var best := zone0
		var best_n := 0
		for b in border.size():
			if int(border[b]) > best_n:
				best_n = int(border[b])
				best = b
		if best_n == 0:
			continue  # an island-wide zone (or a lone patch with only water around it): leave it
		for idx in region:
			zones_arr[idx] = best

static func _is_water(t: int) -> bool:
	return t == IslandTerrain.TileType.SHALLOW or t == IslandTerrain.TileType.DEEP

## 8x2 palette for the terrain shader: row 0 = ground tint (per climate, linear so the shader's
## multiply sees the colour the JSON names: a #1a1c1f basalt stays black), row 1 = layer mix
## (R dirt, G sand, B rock, plain multipliers, no colour space).
static func palette_image(climate: String) -> Image:
	var img := Image.create(zone_count(), 2, false, Image.FORMAT_RGB8)
	for id in zone_count():
		img.set_pixel(id, 0, zone_tint(id, climate).srgb_to_linear())
		var mix: Variant = zone_row(id).get("mix", {})
		var m: Dictionary = mix if mix is Dictionary else {}
		img.set_pixel(id, 1, Color(float(m.get("dirt", 0.0)), float(m.get("sand", 0.0)), float(m.get("rock", 0.0))))
	return img

## Zone tile counts over dry land: {zone name: tiles}. The lab turns them into percentages.
static func shares(rt: IslandRuntime, land_only: bool = true) -> Dictionary:
	var counts := {}
	var arr := biome_types(rt)
	if rt == null or arr.is_empty():
		return counts
	for idx in arr.size():
		var t := int(rt.tile_types[idx]) if idx < rt.tile_types.size() else 0
		if land_only and (t == IslandTerrain.TileType.SHALLOW or t == IslandTerrain.TileType.DEEP
				or t == IslandTerrain.TileType.SAND or t == IslandTerrain.TileType.WET):
			continue
		var name := zone_name(int(arr[idx]))
		counts[name] = int(counts.get(name, 0)) + 1
	return counts

## The minimap/atlas image: grass and dry land take the zone's map colour, water, sand, rock and
## the harvest overrides keep their own, as before. One texture feeds the HUD map and the atlas.
static func map_image(rt: IslandRuntime) -> Image:
	var span := rt._tile_span
	var arr := biome_types(rt)
	var climate: String = rt._climate
	var img := Image.create(span, span, false, Image.FORMAT_RGB8)
	for z in span:
		for x in span:
			var idx := x + z * span
			var t := int(rt.tile_types[idx]) if idx < rt.tile_types.size() else 0
			var b := int(arr[idx]) if idx < arr.size() else 0
			var c := map_color(b, climate)
			match t:
				IslandTerrain.TileType.DIRT, IslandTerrain.TileType.BARE:
					c = Color(0.42, 0.32, 0.22)
				IslandTerrain.TileType.SAND:
					c = Color(0.80, 0.72, 0.52)
				IslandTerrain.TileType.WET:
					c = Color(0.62, 0.55, 0.42)
				IslandTerrain.TileType.SHALLOW:
					c = Color(0.55, 0.78, 0.82)
				IslandTerrain.TileType.DEEP:
					c = Color(0.16, 0.30, 0.46)
				IslandTerrain.TileType.ROCK, IslandTerrain.TileType.ASH:
					c = Color(0.45, 0.45, 0.44)
				IslandTerrain.TileType.MUD:
					c = Color(0.36, 0.28, 0.20)
			img.set_pixel(x, z, c)
	return img
