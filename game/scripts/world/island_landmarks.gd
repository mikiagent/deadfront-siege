class_name IslandLandmarks
extends RefCounted
## LANDMARKS M1 (design docs/design/island-resources.md section 5.1, approved 2026-10-29): the named
## sites an island is scouted for. One pass during the island build:
##   1. read the island's landmark budget (data/world/landmarks.json budgets, or the island row's
##      "landmark_budget") and the climate's site rows;
##   2. draw rows by weight, without repeating one past its "max", the climate's "must" rows first;
##   3. sample candidate tiles that pass the type's terrain tokens, score them (ring band, spacing,
##      zone), reject anything failing the validation rules of doc section 3.3;
##   4. plant the row's node group around the centre (rings of 6-12 m), level = tier + 5 (cap 60);
##   5. record the site in rt.landmarks (id, type, display, x/z, discovery radius, gold) for the map,
##      the discovery pass (M2) and the save.
## Authored maps: a map-lab "landmark" marker with a "type" prop places that type exactly there; an
## island row's authored crater (today temperate_25) becomes one landmark of the mapped type. The
## tutorial island keeps its hand-tuned layout (no generated sites).
## Every number is # ASSUMPTION: see data/world/landmarks.json and the M1 report.

const DATA_PATH := "res://data/world/landmarks.json"
## Rings the node group grows on: a tight ring for small groups, a wider one for large.
const RING_M := [7.0, 9.5]

## The parsed data file (one read per process; the file is small).
static var _data: Dictionary = {}
static var _data_loaded := false

static func data() -> Dictionary:
	if _data_loaded:
		return _data
	_data_loaded = true
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("[landmarks] cannot open %s" % DATA_PATH)
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	_data = v as Dictionary if v is Dictionary else {}
	return _data

static func rules() -> Dictionary:
	return data().get("rules", {})

static func known_types() -> Array:
	var t: Dictionary = data().get("types", {})
	return t.keys()

## The [min, max] landmark count for an island row (doc section 5.1's budget table).
static func budget_for(def: Dictionary) -> Vector2i:
	var own: Variant = def.get("landmark_budget", null)
	if own is Array and (own as Array).size() >= 2:
		return Vector2i(int(own[0]), int(own[1]))
	var b: Dictionary = data().get("budgets", {})
	var kind := str(def.get("kind", "unstable"))
	if kind == "tutorial":
		var tut: Variant = b.get("tutorial", [6, 8])
		return Vector2i(int(tut[0]), int(tut[1]))
	if kind == "private":
		var priv: Variant = b.get("private", [2, 3])
		return Vector2i(int(priv[0]), int(priv[1]))
	var tier := int(def.get("tier", 25))
	for row in b.get("unstable", []):
		if row is Array and (row as Array).size() >= 4 and tier >= int(row[0]) and tier <= int(row[1]):
			return Vector2i(int(row[2]), int(row[3]))
	# Above the last band: its top. ASSUMPTION: no island row is outside the table.
	var rows: Array = b.get("unstable", [])
	if not rows.is_empty():
		var last: Array = rows[rows.size() - 1]
		return Vector2i(int(last[2]), int(last[3]))
	return Vector2i(4, 6)

# ------------------------------------------------------------------------------------ the build pass

## Places this island's landmarks (called once per build, after the scatter's family passes and before
## its top-up). Returns {placed, skipped, types, sites}.
static func build(rt: IslandRuntime, def: Dictionary) -> Dictionary:
	rt.landmarks.clear()
	var stats := {"placed": 0, "skipped": 0, "types": PackedStringArray()}
	if str(def.get("kind", "")) == "tutorial":
		# The tutorial island is hand-tuned (its town, its safe ring): no generated sites.
		_print_line(rt, def, stats)
		return stats
	var planned := plan(rt, def)
	var placed := 0
	for site in planned["sites"]:
		if apply_site(rt, def, site):
			placed += 1
			rt.landmarks.append(site)
			var t := str(site.get("display", site.get("type", "")))
			if not stats["types"].has(t):
				stats["types"].append(t)
	stats["placed"] = placed
	stats["skipped"] = int(planned["skipped"]) + (planned["sites"].size() - placed)
	_print_line(rt, def, stats)
	return stats

static func _print_line(rt: IslandRuntime, def: Dictionary, stats: Dictionary) -> void:
	print("[landmarks] island=%s placed=%d skipped=%d types=%s" % [
		def.get("id", rt.name), int(stats["placed"]), int(stats["skipped"]),
		",".join(stats["types"]) if not stats["types"].is_empty() else "-"])

## The deterministic plan: the sites this island would place, with their families and node counts.
## Pure placement (no nodes): t_landmarks uses it to check the other four seeds on one build.
static func plan(rt: IslandRuntime, def: Dictionary) -> Dictionary:
	var r := rules()
	var climate := str(def.get("climate", "temperate"))
	var id := str(def.get("id", "island"))
	var rng := RandomNumberGenerator.new()
	# The island seed and generation: home and tutorial keep generation 0 (doc section 3.2).
	rng.seed = hash("%s|%d|landmarks" % [id, int(def.get("seed", 17))])
	var b := budget_for(def)
	var want := rng.randi_range(b.x, b.y)
	var rows: Array = (data().get("climates", {}) as Dictionary).get(climate, [])
	var sites: Array[Dictionary] = []
	var skipped := 0
	var landmark_ctx := _context(rt, def)
	# Authored points first: an island row's crater and a map's typed landmark markers.
	var authored := _authored(rt, def, climate)
	for site in authored:
		if _validate(rt, landmark_ctx, site, sites):
			sites.append(site)
		else:
			skipped += 1
	# Draw the climate's rows: the "must" rows first, then weighted without replacement past "max".
	var order := _draw_order(rows, want, rng)
	var used := {}
	for row in order:
		if sites.size() >= want:
			break
		var key := "%s:%s" % [str(row.get("type", "")), str(row.get("display", ""))]
		var cap := int(row.get("max", 99))
		if int(used.get(key, 0)) >= cap:
			continue
		var site := _try_place(rt, landmark_ctx, climate, row, sites, rng, false)
		if site.is_empty():
			skipped += 1
			continue
		used[key] = int(used.get(key, 0)) + 1
		sites.append(site)
	# Doc section 3.3: at least one site within near_landing_m of the landing. Move the last site whose
	# ring band reaches into that zone, or add one when the budget has room.
	if not _has_near(sites, landmark_ctx):
		var moved := false
		for i in range(sites.size() - 1, -1, -1):
			if not sites[i].get("authored", false):
				sites.remove_at(i)
				var row := _row_for(rows, str(sites[i].get("type", "")), str(sites[i].get("display", "")))
				var near := _try_place(rt, landmark_ctx, climate, row, sites, rng, true) if not row.is_empty() else {}
				if not near.is_empty():
					sites.append(near)
					moved = true
				break
		if not moved:
			# No drawn row reaches in: add the climate's shortest-band row inside the band.
			for row in rows:
				var band: Array = (data().get("types", {}) as Dictionary).get(str(row.get("type", "")), {}).get("ring", [0, 0])
				if band.size() >= 2 and float(band[1]) > 0.0:
					var near := _try_place(rt, landmark_ctx, climate, row, sites, rng, true)
					if not near.is_empty():
						sites.append(near)
						break
	return {"sites": sites, "skipped": skipped, "budget": b}

static func _has_near(sites: Array, ctx: Dictionary) -> bool:
	var near_m := float(rules().get("near_landing_m", 140))
	for s in sites:
		if float(s.get("dist_landing", 9999.0)) <= near_m:
			return true
	return false

static func _row_for(rows: Array, type: String, display: String) -> Dictionary:
	for row in rows:
		if str(row.get("type", "")) == type and str(row.get("display", "")) == display:
			return row
	return {}

## Row indices in draw order: every "must" row first (in file order), then a weighted draw of the
## rest. The list is longer than the budget so a row past its "max" can be skipped without starving.
static func _draw_order(rows: Array, want: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var pool: Array = []
	for row in rows:
		if bool((row as Dictionary).get("must", false)):
			out.append(row)
		else:
			pool.append(row)
	# Weighted draw without replacement.
	while not pool.is_empty() and out.size() < want * 3:
		var total := 0.0
		for row in pool:
			total += maxf(0.01, float((row as Dictionary).get("weight", 1)))
		var pick := rng.randf() * total
		var chosen := 0
		for i in pool.size():
			pick -= maxf(0.01, float((pool[i] as Dictionary).get("weight", 1)))
			if pick <= 0.0:
				chosen = i
				break
		out.append(pool[chosen])
		pool.remove_at(chosen)
	return out

# ------------------------------------------------------------------------------------ authored points

## Sites the island row or an authored map pins: the row's crater, and every map-lab "landmark" marker
## with a type (an untyped marker is a named point of interest, not a resource site: doc section 3.2).
static func _authored(rt: IslandRuntime, def: Dictionary, climate: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lv := int(rules().get("level_offset", 5))
	var authored: Dictionary = data().get("authored", {})
	var crater_v: Variant = def.get("crater", null)
	if crater_v is Array and (crater_v as Array).size() >= 3:
		var row: Dictionary = authored.get("%s:crater" % str(def.get("id", "")), {})
		var type := str(row.get("type", "garden"))
		var trow: Dictionary = (data().get("types", {}) as Dictionary).get(type, {})
		out.append({
			"id": str(row.get("id", "crater")),
			"type": type,
			"display": str(row.get("display", trow.get("display", "Crater"))),
			"x": float(crater_v[0]),
			"z": float(crater_v[2]),
			"nodes": (row.get("nodes", {}) as Dictionary).duplicate(true),
			"node_id_pattern": str(row.get("node_ids", "")),
			"level_offset": int(row.get("level_offset", lv)),
			"ring": float(row.get("ring", 9.0)),
			"jitter": 0.0,
			"authored": true,
		})
	if rt != null and rt.map_doc != null:
		for m in rt.map_doc.markers:
			if str(m.get("kind", "")) != "landmark":
				continue
			var props: Dictionary = m.get("props", {}) as Dictionary
			var type := str(props.get("type", ""))
			if type == "":
				continue  # a plain point of interest: no site, no nodes
			var trow: Dictionary = (data().get("types", {}) as Dictionary).get(type, {})
			if trow.is_empty():
				continue
			var nodes: Dictionary = props.get("nodes", {}) as Dictionary
			if nodes.is_empty():
				# The marker names a type only: take the climate's first row of that type.
				for row in (data().get("climates", {}) as Dictionary).get(climate, []):
					if str((row as Dictionary).get("type", "")) == type:
						nodes = ((row as Dictionary).get("nodes", {}) as Dictionary).duplicate(true)
						break
			out.append({
				"id": str(props.get("name", type)).to_lower().validate_filename().replace(" ", "_"),
				"type": type,
				"display": str(props.get("name", trow.get("display", type))),
				"x": float(m.get("x", 0.0)),
				"z": float(m.get("z", 0.0)),
				"nodes": nodes,
				"level_offset": lv,
				"authored": true,
			})
	return out

# ------------------------------------------------------------------------------------ placement

## Per-build placement context: the landing, the camp, the reachable dry component, the no-site zones
## and the spacing. Built once per island (one BFS) so candidate tests are array lookups.
static func _context(rt: IslandRuntime, def: Dictionary) -> Dictionary:
	var r := rules()
	var landing: Vector3 = rt.arrival_point() if rt.harbour != null else rt._camp_pos
	var kind := str(def.get("kind", "unstable"))
	var spacing := float((r.get("spacing_m", {}) as Dictionary).get(kind, 45))
	var safe := float(def.get("town_safe_m", 0.0)) if kind == "tutorial" else 0.0
	var circles: Array = []
	if rt.map_doc != null:
		for m in rt.map_doc.markers:
			if str(m.get("kind", "")) == "claim_free":
				var p: Dictionary = m.get("props", {}) as Dictionary
				circles.append({"x": float(m.get("x", 0.0)), "z": float(m.get("z", 0.0)), "r": float(p.get("radius_m", 30.0))})
	return {
		"landing": Vector2(landing.x, landing.z),
		"camp": Vector2(rt._camp_pos.x, rt._camp_pos.z),
		"spacing": spacing,
		"camp_clear": float(r.get("camp_clear_m", 60)),
		"landing_clear": float(r.get("landing_clear_m", 36)),
		"near": float(r.get("near_landing_m", 140)),
		"safe_ring": safe,
		"circles": circles,
		"reach": _reachable(rt),
		"half": rt._size * 0.5,
		"span": rt._tile_span,
	}

## The dry tiles connected to the camp (and to the landing's inland side): a landmark nobody can walk
## to is the doc's anti-pattern. One 4-neighbour BFS over dry_walk; TilePath is built later in the build,
## so this is the build-time stand-in (t_landmarks re-checks with the real TilePath).
static func _reachable(rt: IslandRuntime) -> PackedByteArray:
	var span := rt._tile_span
	var out := PackedByteArray()
	if span <= 0 or rt.dry_walk.is_empty():
		return out
	out.resize(span * span)
	var half := rt._size * 0.5
	var seeds: Array[int] = []
	for p in [rt._camp_pos, rt.arrival_point() if rt.harbour != null else rt._camp_pos]:
		var t := _tile_of(p, half, span)
		if t >= 0 and int(rt.dry_walk[t]) == 1:
			seeds.append(t)
			continue
		# The arrival sits on the beach: take the nearest dry tile within 8 m.
		var best := -1
		var bestd := 1e9
		var cx := int(floor(p.x + half))
		var cz := int(floor(p.z + half))
		for dz in range(-8, 9):
			for dx in range(-8, 9):
				var x := cx + dx
				var z := cz + dz
				if x < 0 or z < 0 or x >= span or z >= span:
					continue
				var i := x + z * span
				if int(rt.dry_walk[i]) != 1:
					continue
				var d := float(dx * dx + dz * dz)
				if d < bestd:
					bestd = d
					best = i
		if best >= 0:
			seeds.append(best)
	var stack: Array[int] = []
	for s in seeds:
		if int(out[s]) == 0:
			out[s] = 1
			stack.append(s)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % span
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nx := x + d.x
			var nz := i / span + d.y
			if nx < 0 or nz < 0 or nx >= span or nz >= span:
				continue
			var j := nx + nz * span
			if int(out[j]) == 1 or int(rt.dry_walk[j]) != 1:
				continue
			out[j] = 1
			stack.append(j)
	return out

static func _tile_of(p: Vector3, half: float, span: int) -> int:
	var x := int(floor(p.x + half))
	var z := int(floor(p.z + half))
	if x < 0 or z < 0 or x >= span or z >= span:
		return -1
	return x + z * span

## True when the centre is on the reachable dry component and on a walkable tile.
static func _reach_ok(ctx: Dictionary, x: float, z: float) -> bool:
	var reach: PackedByteArray = ctx["reach"]
	if reach.is_empty():
		return true
	var i := _tile_of(Vector3(x, 0, z), float(ctx["half"]), int(ctx["span"]))
	return i >= 0 and int(reach[i]) == 1

## The site's terrain rule (data types.<type>.terrain tokens) at the centre.
static func _terrain_ok(rt: IslandRuntime, type_row: Dictionary, x: float, z: float) -> bool:
	for token_v in type_row.get("terrain", []):
		var token := str(token_v)
		if not _token_ok(rt, token, x, z):
			return false
	return true

static func _token_ok(rt: IslandRuntime, token: String, x: float, z: float) -> bool:
	if token == "flat":
		return IslandTerrain.slope_deg(rt, x, z) <= 14.0
	if token == "dry":
		var t := IslandTerrain.tile_type_at_world(rt, x, z)
		return t == IslandTerrain.TileType.DRY or t == IslandTerrain.TileType.GRASS
	if token == "rock_near":
		for i in 8:
			var a := float(i) * TAU / 8.0
			for d in [4.0, 8.0]:
				var q := Vector3(x + cos(a) * d, 0.0, z + sin(a) * d)
				var t := IslandTerrain.tile_type_at_world(rt, q.x, q.z)
				if t == IslandTerrain.TileType.ROCK or t == IslandTerrain.TileType.CLIFF or t == IslandTerrain.TileType.ASH:
					return true
				var b := IslandProps.biome_of(rt, q.x, q.z)
				if b == "rocky" or b == "canyon" or b == "basalt":
					return true
		return false
	if token == "water_near":
		for i in 8:
			var a := float(i) * TAU / 8.0
			var q := Vector3(x + cos(a) * 9.0, 0.0, z + sin(a) * 9.0)
			var t := IslandTerrain.tile_type_at_world(rt, q.x, q.z)
			if t == IslandTerrain.TileType.MUD or t == IslandTerrain.TileType.WET or t == IslandTerrain.TileType.SHALLOW or t == IslandTerrain.TileType.DEEP:
				return true
		return rt.river_dist_at(x, z) <= 12.0
	if token == "coast":
		for i in 10:
			var a := float(i) * TAU / 10.0
			var q := Vector3(x + cos(a) * 14.0, 0.0, z + sin(a) * 14.0)
			if not rt.is_dry(q):
				return true
		return false
	if token.begins_with("zone:"):
		var b := IslandProps.biome_of(rt, x, z)
		return (token.substr(5) as String).split(",").has(b)
	return false

## A candidate centre: the doc section 3.3 rules, in the cheapest order (distance, then claims, then
## the reachable component, then spacing, then terrain and the node group's fit).
static func _center_ok(rt: IslandRuntime, ctx: Dictionary, site: Dictionary, sites: Array) -> bool:
	var x := float(site["x"])
	var z := float(site["z"])
	var p := Vector2(x, z)
	var landing: Vector2 = ctx["landing"]
	var dl := p.distance_to(landing)
	var dc := p.distance_to(ctx["camp"])
	if dc < float(ctx["camp_clear"]):
		return false
	if dl < float(ctx["landing_clear"]):
		return false
	var safe := float(ctx["safe_ring"])
	if safe > 0.0 and dc < safe:
		return false
	for c in ctx["circles"]:
		var ctr := Vector2(float(c["x"]), float(c["z"]))
		if p.distance_to(ctr) < float(c["r"]):
			return false
	# Claims: the camp's landing claim and every owned cell.
	var tile := BuildGrid.tile_of(Vector3(x, 0.0, z))
	if rt.camp_claim.has_area() and rt.camp_claim.grow(3).has_point(tile):
		return false
	for rect in rt.claims:
		if (rect as Rect2i).grow(3).has_point(tile):
			return false
	if not rt.is_dry(Vector3(x, 0.0, z)):
		return false
	if not _reach_ok(ctx, x, z):
		return false
	for other in sites:
		if p.distance_to(Vector2(float(other["x"]), float(other["z"]))) < float(ctx["spacing"]):
			return false
	var type_row: Dictionary = (data().get("types", {}) as Dictionary).get(str(site.get("type", "")), {})
	if type_row.is_empty():
		return false
	if not site.get("authored", false):
		var band: Array = type_row.get("ring", [0, 0])
		var lo := float(band[0]) if band.size() >= 2 else 0.0
		var hi := float(band[1]) if band.size() >= 2 else 9999.0
		if bool(site.get("near", false)):
			hi = minf(hi, float(ctx["near"]) - 2.0)
			lo = minf(lo, float(ctx["landing_clear"]) + 6.0)
		if dl < lo or dl > hi:
			return false
	if not _terrain_ok(rt, type_row, x, z):
		return false
	return _group_fits(rt, site)


## The node group's ring fits: at least node_fit_share of its positions are dry, unoccupied ground.
static func _group_fits(rt: IslandRuntime, site: Dictionary) -> bool:
	var positions := _node_positions(site)
	if positions.is_empty():
		return true
	var ok := 0
	for p in positions:
		if rt.is_dry(Vector3(p.x, 0.0, p.y)) and not rt._used_tiles.has(BuildGrid.tile_of(Vector3(p.x, 0.0, p.y))):
			ok += 1
	return float(ok) / float(positions.size()) >= float(rules().get("node_fit_share", 0.7))

## Deterministic slot positions for a site's node group: rings of 6-12 m (doc section 3.2 step 5).
static func _node_positions(site: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var nodes: Dictionary = site.get("nodes", {})
	var total := 0
	for fam in nodes.keys():
		var span: Variant = nodes[fam]
		if span is Array and (span as Array).size() >= 2:
			total += int(span[1])
		else:
			total += 1
	var ring: float = float(site.get("ring", RING_M[0] if total <= 6 else RING_M[1]))
	var i := 0
	for fam in nodes.keys():
		var span: Variant = nodes[fam]
		var n := int(span[1]) if span is Array and (span as Array).size() >= 2 else 1
		for _k in n:
			var a := float(i) * TAU / float(maxi(total, 1))
			out.append(Vector2(float(site["x"]) + cos(a) * ring, float(site["z"]) + sin(a) * ring))
			i += 1
	return out

## One drawn row placed: sample candidates until one passes, else {} (the type is skipped, never
## forced onto a bad tile: doc section 3.2 step 4).
static func _try_place(rt: IslandRuntime, ctx: Dictionary, climate: String, row: Dictionary,
		sites: Array, rng: RandomNumberGenerator, near: bool) -> Dictionary:
	if row.is_empty():
		return {}
	var site := _site_from_row(row, climate, rng)
	if site.is_empty():
		return {}
	site["near"] = near
	var half: float = float(ctx["half"]) - 16.0
	var tries := int(rules().get("tries_per_site", 220))
	for _i in tries:
		if near:
			# Sample the near band around the landing directly (a ring sample, not the whole island).
			var lo := float(ctx["landing_clear"]) + 8.0
			var hi := float(ctx["near"]) - 6.0
			var a := rng.randf_range(0.0, TAU)
			var d := rng.randf_range(lo, maxf(lo + 1.0, hi))
			site["x"] = float(ctx["landing"].x) + cos(a) * d
			site["z"] = float(ctx["landing"].y) + sin(a) * d
		else:
			site["x"] = rng.randf_range(-half, half)
			site["z"] = rng.randf_range(-half, half)
		if _center_ok(rt, ctx, site, sites):
			site["dist_landing"] = Vector2(float(site["x"]), float(site["z"])).distance_to(ctx["landing"])
			return site
	return {}

## The site record from a climate row: the node group's family counts, level offset, discovery data.
static func _site_from_row(row: Dictionary, climate: String, rng: RandomNumberGenerator) -> Dictionary:
	var type := str(row.get("type", ""))
	var type_row: Dictionary = (data().get("types", {}) as Dictionary).get(type, {})
	if type_row.is_empty():
		return {}
	var nodes: Dictionary = {}
	for fam in (row.get("nodes", {}) as Dictionary).keys():
		var span: Variant = (row.get("nodes", {}) as Dictionary)[fam]
		if span is Array and (span as Array).size() >= 2:
			nodes[str(fam)] = [int(span[0]), int(span[1])]
		else:
			nodes[str(fam)] = [1, 1]
	var disc: Dictionary = type_row.get("discovery", rules().get("discovery", {}))
	var slug := str(row.get("display", type)).to_lower().replace(" ", "_").replace("'", "")
	return {
		"id": slug,
		"type": type,
		"display": str(row.get("display", type_row.get("display", type))),
		"climate": climate,
		"nodes": nodes,
		"level_offset": int(type_row.get("level_offset", rules().get("level_offset", 5))),
		"discovery_radius": float(disc.get("radius_m", 18)),
		"gold": int(disc.get("gold", 20)),
		"contested": rng.randf() < float((type_row.get("guardians", {}) as Dictionary).get("chance", 0.0)),
		"dormant": rng.randf() < float(type_row.get("dormant_chance", 0.0)),
	}

## An authored site (the crater, a map marker) keeps its exact point: only the hard refusals apply,
## the places the doc forbids a landmark (a claim, a claim_free circle, the tutorial's safe ring, the
## sea, an unreachable pocket). The ring band, the camp clearing and the spacing do not move it.
static func _validate(rt: IslandRuntime, ctx: Dictionary, site: Dictionary, sites: Array) -> bool:
	var x := float(site["x"])
	var z := float(site["z"])
	var p := Vector2(x, z)
	if not rt.is_dry(Vector3(x, 0.0, z)):
		return false
	var dc := p.distance_to(ctx["camp"])
	var safe := float(ctx["safe_ring"])
	if safe > 0.0 and dc < safe:
		return false
	for c in ctx["circles"]:
		if p.distance_to(Vector2(float(c["x"]), float(c["z"]))) < float(c["r"]):
			return false
	var tile := BuildGrid.tile_of(Vector3(x, 0.0, z))
	if rt.camp_claim.has_area() and rt.camp_claim.has_point(tile):
		return false
	for rect in rt.claims:
		if (rect as Rect2i).has_point(tile):
			return false
	if not _reach_ok(ctx, x, z):
		return false
	if not _terrain_ok(rt, (data().get("types", {}) as Dictionary).get(str(site.get("type", "")), {}), x, z):
		return false
	site["dist_landing"] = Vector2(float(site["x"]), float(site["z"])).distance_to(ctx["landing"])
	return true

# ------------------------------------------------------------------------------------ planting

## Plants a planned site's node group. Returns false when nothing could be planted.
static func apply_site(rt: IslandRuntime, def: Dictionary, site: Dictionary) -> bool:
	var climate := str(site.get("climate", def.get("climate", "temperate")))
	var tier := int(def.get("tier", 25))
	var level := clampi(tier + int(site.get("level_offset", 5)), 1, int(rules().get("level_cap", 60)))
	var pattern := str(site.get("node_id_pattern", ""))
	var nodes: Dictionary = site.get("nodes", {})
	var total := 0
	for fam in nodes.keys():
		var span: Variant = nodes[fam]
		total += int(span[1]) if span is Array and (span as Array).size() >= 2 else 1
	var ring: float = float(site.get("ring", RING_M[0] if total <= 6 else RING_M[1]))
	var jitter := float(site.get("jitter", 1.0))
	var idx := 0
	var planted := 0
	var key := str(site.get("id", site.get("type", "site")))
	for fam in nodes.keys():
		var span: Variant = nodes[fam]
		var lo := int(span[0]) if span is Array and (span as Array).size() >= 2 else 1
		var hi := int(span[1]) if span is Array and (span as Array).size() >= 2 else 1
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|%s|%s" % [str(def.get("id", "")), key, str(fam)])
		var n := rng.randi_range(lo, hi)
		var role := str(Data.nature_families.get(str(fam), {}).get("role", "plant"))
		var fallback := _fallback_for(str(fam), role)
		var tool := IslandScatter._family_tool(str(fam))
		for _k in n:
			var a := float(idx) * TAU / float(maxi(total, 1)) + rng.randf_range(-0.12, 0.12) * jitter
			var d := ring + rng.randf_range(-1.5, 1.5) * jitter
			var p := Vector3(float(site["x"]) + cos(a) * d, 0.0, float(site["z"]) + sin(a) * d)
			idx += 1
			if not rt.is_dry(p):
				continue
			var tile := BuildGrid.tile_of(p)
			if rt._used_tiles.has(tile):
				continue
			p.y = rt.surface_y(p.x, p.z)
			var node_id := (pattern % planted) if pattern != "" else "lm_%s_%d" % [key, planted]
			if rt._harvest_nodes.has(node_id):
				continue
			var color := _family_color(str(fam), role)
			planted += IslandScatter.plant_at(rt, str(fam), node_id, p, fallback, tool, climate, level, color)
			rt.harvest_count += 1
	if planted == 0:
		return false
	site["level"] = level
	site["planted"] = planted
	site["node_total"] = total
	site.set("contested", bool(site.get("contested", false)))
	return true

## The fallback yield when the family's manifest harvest names no existing item (plant_at's last
## resort), by role.
static func _fallback_for(family: String, role: String) -> StringName:
	var h: Dictionary = Data.nature_families.get(family, {}).get("harvest", {})
	for k in h.keys():
		if Data.item(StringName(str(k))) != null:
			return StringName(str(k))
	match role:
		"tree", "tree_dead", "prop":
			return &"wood_log"
		"bush", "plant":
			return &"fibre_stalk"
		_:
			return &"stone"

static func _family_color(family: String, role: String) -> Color:
	match role:
		"tree", "tree_dead":
			return Color(0.35, 0.22, 0.1)
		"bush":
			return Color(0.2, 0.45, 0.18)
		"rock":
			return Color(0.5, 0.5, 0.48)
	if family.to_lower().contains("ore") or family.to_lower().contains("node"):
		return Color(0.5, 0.45, 0.42)
	return Color(0.35, 0.55, 0.25)
