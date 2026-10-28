extends SceneTree
## ISLANDGEN / roadmap "shape-consumers" acceptance plus ISLANDS2 (owner 2026-10-27: "islands looks
## too square/circular ... make more islands that look like Japan, Croatia ... long islands, with
## boundaries that look more like countries. They should be bigger also. The player island
## shouldn't be too large"). Measured on the built island, on EVERY island in the data - the home
## island with each of the five Tamed Island shapes, and every other island - on the coast
## generator a new world builds (IslandShape.GEN_CURRENT):
##   - 0 dry (land) tiles outside the walkable TilePath grid; islet tiles are never dry;
##   - camp-to-dock distance <= 40 m (<= 70 m on the home island), measured camp -> dock arrival;
##   - the river is connected hill-to-sea: the ground around its spring stands >= 2 m (the hill),
##     one channel (samples <= 4 m apart), wet along its whole polyline, mouth in the sea;
##   - the main landmass's box along its principal axes within +-10 % of the island's target
##     (the home: its east-west frame, and never above today's 375 x 300 m + 10 %);
##   - non-home islands: long (spines aspect <= 0.50, the rest <= 0.70), a country-like border
##     (solidity <= 0.80), bigger than generator 1 (long axis >= 1.25 x the old tier box, mainland
##     area >= 1.10 x generator 1's measured area), archipelagos with >= 3 islets;
##   - variety and count: every type on >= 2 islands, >= 18 voyage islands.
## Every island is built through the game's own path (World.load_island -> IslandRuntime.build:
## IslandShape, IslandTerrain, HarbourSite, TilePath); nothing is re-implemented here.
## Env: SG_ONLY=id,id,home (subset), SG_PNG_DIR=dir (top-down silhouettes), SG_GEN=1 (build the old
## generator for comparison; the gates then fail by design).
## Run: Godot --headless --path game --script res://tests/t_shapegates.gd
##   -> one "[t_shapegates] <island> dry_outside=N camp_dock_m=X river_ok=B size_err=P" line per
##      island, then "[t_shapegates] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

## Watchdog: 24 islands build (3-6 s each) plus the measurement passes; 420 s is a hard stop.
const WATCHDOG_MS := 420000
## Gate limits (plan P3 ISLANDGEN "Verify:"). Not tuned here.
## The size gate's target is IslandShape.target (the island's own shape block, data/islands/*.json).
const CAMP_DOCK_MAX_M := 40.0
const CAMP_DOCK_HOME_MAX_M := 70.0
const SIZE_ERR_MAX := 0.10
## ASSUMPTION: "hill" = the ground around the channel's head stands at least 2 m above the water
## plane. The plan puts the source on the plateau; a sea-level start is not a river. (The WIP gate
## measured the channel centre itself, which can never be both wet and 2 m up: one water plane.)
const RIVER_HEAD_MIN_H := 2.0
## The polyline is 72 samples over >= half the long axis; a step above 4 m means the stored river
## is not one channel but stitched pieces.
const RIVER_STEP_MAX_M := 4.0
## The channel must be wet at nearly every sample (the ford is shallow but at/below the plane).
const RIVER_WET_MIN := 0.95
## IslandTerrain's water plane (HarbourSite.WATER_Y).
const WATER_Y := -0.05
## ISLANDS2 (owner 2026-10-27: long, country-like, bigger islands; a modest starter island).
## Aspect = short / long of the main landmass along its principal axes.
const ASPECT_SPINE_MAX := 0.50
const ASPECT_MAX := 0.70
## Generator 1's main landmass (m2, land tiles above the water plane), measured by this test with
## SG_GEN=1 on 2026-10-27 before ISLANDS2. A new island compares with its tier band's mean.
const GEN1_AREA := {"savannah_15": 45922, "temperate_20": 47698, "temperate_25": 43344, "tropical_25": 45341,
	"tundra_30": 57000, "desert_35": 69056, "temperate_35": 67381, "tropical_40": 64432, "savannah_45": 65083,
	"temperate_45": 59338, "desert_50": 78768, "swamp_55": 70007, "tundra_55": 78699, "volcanic_60": 76408}
const GEN1_AREA_BAND := {15: 45576, 30: 63718, 50: 75971}
const LONG_GROWTH_MIN := 1.25
const AREA_GROWTH_MIN := 1.10
## Mainland area / its convex hull's area.
const SOLIDITY_MAX := 0.80

var _fails: PackedStringArray = []
var _started := false
var _t0 := 0
var _host: Node3D
var _world: Node
var _IS: GDScript

func _process(_delta: float) -> bool:
	if _t0 == 0:
		_t0 = Time.get_ticks_msec()
	if Time.get_ticks_msec() - _t0 > WATCHDOG_MS:
		print("[t_shapegates] FAIL watchdog: no result after %d s" % int(WATCHDOG_MS / 1000))
		quit(1)
		return true
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_shapegates] FAIL %s" % what)

func _run() -> void:
	_IS = load("res://scripts/world/island_shape.gd")
	_host = Node3D.new()
	_host.name = "TShapegates"
	root.add_child(_host)
	_world = root.get_node("World")
	var old_shape: StringName = _world.home_shape
	var old_terrain: StringName = _world.home_terrain
	var old_home_gen: int = _world.home_gen
	var old_away_gen: int = _world.away_gen
	# What a new world builds (World.start_new): the current coast generator for home and voyages.
	_world.home_gen = _IS.GEN_CURRENT
	_world.away_gen = _IS.GEN_CURRENT
	# SG_GEN=1 builds generator 1 instead (the before/after perf and silhouette comparison; the
	# gates are generator 2's and fail there by design).
	if OS.get_environment("SG_GEN") != "":
		_world.home_gen = int(OS.get_environment("SG_GEN"))
		_world.away_gen = int(OS.get_environment("SG_GEN"))
	var only := OS.get_environment("SG_ONLY").split(",", false)
	_world.camp_layout.erase("Harbour")  # every island at its data pose, not a moved dock
	# The home island with each of the five Tamed Island shapes, the way complete_pick() sets it.
	for row in _world.home_shapes:
		if not row is Dictionary:
			continue
		var sid := str((row as Dictionary).get("id", ""))
		if sid == "" or (not only.is_empty() and not only.has("home")):
			continue
		_world.home_shape = StringName(sid)
		_world.home_terrain = StringName(str((row as Dictionary).get("terrain", sid)))
		await _measure("home_grassland@%s" % sid, &"home_grassland", true)
	_world.home_shape = &""
	_world.home_terrain = old_terrain
	var ids: Array = _world.islands.keys()
	ids.sort()
	for id in ids:
		if str(id) == "home_grassland" or (not only.is_empty() and not only.has(str(id))):
			continue  # covered above by its five shapes (meadow is the seed-17 legacy core)
		await _measure(str(id), StringName(str(id)), str(_world.def_of(StringName(str(id))).get("kind", "")) == "private")
	if only.is_empty():
		# Variety (owner: "not every island the same type"): every type on at least two islands.
		for t in ["spine", "archipelago", "compact"]:
			_expect(int(_types.get(t, 0)) >= 2, "at least two non-home islands are '%s' (%d)" % [t, int(_types.get(t, 0))])
		# More islands than the 14 voyages before ISLANDS2.
		_expect(_voyages >= 18, "the catalogue has >= 18 voyage islands (%d)" % _voyages)
	_world.home_shape = old_shape
	_world.home_terrain = old_terrain
	_world.home_gen = old_home_gen
	_world.away_gen = old_away_gen
	_world.camp_layout.erase("Harbour")
	if _fails.is_empty():
		print("[t_shapegates] PASS")
		quit(0)
	else:
		print("[t_shapegates] FAIL count=%d" % _fails.size())
		quit(1)

var _types := {}
var _voyages := 0

## Build one island through World.load_island and measure the gates on the live scene.
func _measure(label: String, id: StringName, is_home: bool) -> void:
	var mem0 := OS.get_static_memory_usage()
	var t0 := Time.get_ticks_usec()
	_world.load_island(_host, id, Vector3(0, 1, 0), false)
	var build_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	await process_frame
	var rt = _world.runtime
	if rt == null or rt._shape == null or rt.pathing == null:
		_expect(false, "%s built a runtime with a shape and TilePath" % label)
		return
	var mem_mb := float(OS.get_static_memory_usage() - mem0) / 1048576.0
	print("[t_shapegates-perf] %s build_ms=%.0f scene_nodes=%d harvest=%d creatures=%d mem_mb=%.1f size=%.0f" % [
		label, build_ms, _count_nodes(rt), int(rt.harvest_count), int(rt.creature_count), mem_mb, float(rt._size)])
	var png_dir := OS.get_environment("SG_PNG_DIR")
	if png_dir != "":
		_save_png(rt, png_dir.path_join("%s.png" % label))
	var sh = rt._shape
	_expect(int(sh.gen) == int(_IS.GEN_CURRENT), "%s builds on the current coast generator (gen %d)" % [label, int(sh.gen)])
	# --- gate 1: dry land outside the walkable grid -------------------------------------------
	var span: int = rt._tile_span
	var half: float = rt._size * 0.5
	var region: Rect2i = rt.pathing._region
	var dry_out := 0
	var dry_total := 0
	var dry_blocked := 0
	var first_out := Vector2.ZERO
	for z in span:
		for x in span:
			var wx := -half + float(x) + 0.5
			var wz := -half + float(z) + 0.5
			if not rt.is_dry(Vector3(wx, 0.0, wz)):
				continue
			dry_total += 1
			var t := Vector2i(floori(wx), floori(wz))
			if not region.has_point(t):
				if dry_out == 0:
					first_out = Vector2(wx, wz)
				dry_out += 1
			elif not rt.pathing.is_walkable(t):
				dry_blocked += 1  # inside the grid, solid from a prop/building: not this gate
	_expect(dry_out == 0, "%s dry_outside=%d dry tiles outside the TilePath grid %s (region %s)" % [
		label, dry_out, first_out, region])
	# --- gate 2: camp-to-dock -----------------------------------------------------------------
	var arrive: Vector3 = rt.arrival_point()
	var camp: Vector3 = rt._camp_pos
	var camp_dock := Vector2(camp.x - arrive.x, camp.z - arrive.z).length()
	var limit := CAMP_DOCK_HOME_MAX_M if is_home else CAMP_DOCK_MAX_M
	_expect(camp_dock <= limit, "%s camp_dock_m=%.1f <= %.0f" % [label, camp_dock, limit])
	# --- gate 3: river connected hill-to-sea --------------------------------------------------
	var river: Dictionary = _river_gate(rt)
	_expect(bool(river["ok"]), "%s river_ok=false %s" % [label, str(river)])
	# --- gate 4: land size, shape and coast ---------------------------------------------------
	var g := _land_geometry(rt, is_home)
	var target: Vector2 = sh.target
	var err_long := (float(g["long"]) - target.x) / maxf(1.0, target.x)
	var err_short := (float(g["short"]) - target.y) / maxf(1.0, target.y)
	var size_err := maxf(absf(err_long), absf(err_short))
	_expect(size_err <= SIZE_ERR_MAX, "%s size_err=%.3f (long %.0f vs %.0f, short %.0f vs %.0f, along the land's own axes)" % [
		label, size_err, float(g["long"]), target.x, float(g["short"]), target.y])
	var aspect := float(g["short"]) / maxf(1.0, float(g["long"]))
	var stype := str(sh.stype)
	if is_home:
		# The starter island keeps its size (owner: "shouldn't be too large"): today's 375 x 300 box.
		_expect(float(g["long"]) <= 375.0 * 1.10 and float(g["short"]) <= 300.0 * 1.10, "%s home is no bigger than 375 x 300 (+10 %%): %.0f x %.0f" % [label, float(g["long"]), float(g["short"])])
	else:
		_voyages += 1
		_types[stype] = int(_types.get(stype, 0)) + 1
		# Owner: long islands, not square/circular ones. Spines are Japan-like (<= 0.50), the rest
		# still clearly elongated (<= 0.70; the old generator made 0.70-0.90).
		var amax := ASPECT_SPINE_MAX if stype == "spine" else ASPECT_MAX
		_expect(aspect <= amax, "%s (%s) aspect %.2f <= %.2f" % [label, stype, aspect, amax])
		# Bigger than before: the long axis and the land area grow over generator 1's tier box.
		var tier := int(_world.def_of(id).get("tier", 25))
		var old_long: float = _IS.target_long(tier)
		var band := 15 if tier < 30 else (30 if tier < 50 else 50)
		var old_area := float(GEN1_AREA.get(str(id), GEN1_AREA_BAND[band]))
		_expect(float(g["long"]) >= old_long * LONG_GROWTH_MIN, "%s long axis %.0f m >= %.2f x generator 1's %.0f m" % [label, float(g["long"]), LONG_GROWTH_MIN, old_long])
		_expect(float(g["area"]) >= old_area * AREA_GROWTH_MIN, "%s mainland %.0f m2 >= %.2f x generator 1's %.0f m2" % [label, float(g["area"]), AREA_GROWTH_MIN, old_area])
		# A country-like border: bays and capes take a real share out of the land's convex hull (a
		# disc or an ellipse is ~1.0; generator 1 measured 0.80-0.92 by the plan's figure).
		_expect(float(g["solidity"]) <= SOLIDITY_MAX, "%s solidity %.2f <= %.2f (bays and capes, not a blob)" % [label, float(g["solidity"]), SOLIDITY_MAX])
		if stype == "archipelago":
			_expect(int(g["islets"]) >= 3, "%s (archipelago) has >= 3 offshore islets (%d)" % [label, int(g["islets"])])
	# Islets are scenery: never dry (no scatter, spawns or building), so never outside the grid.
	_expect(int(g["islet_dry"]) == 0, "%s islet tiles are never dry/walkable (%d)" % [label, int(g["islet_dry"])])
	print("[t_shapegates] %s dry_outside=%d camp_dock_m=%.1f river_ok=%s size_err=%.3f" % [
		label, dry_out, camp_dock, "true" if bool(river["ok"]) else "false", size_err])
	print("[t_shapegates-geo] %s type=%s land=%.0fx%.0f target=%.0fx%.0f aspect=%.2f area=%.0f solidity=%.2f coast_ratio=%.2f islets=%d size=%.0f" % [
		label, stype, float(g["long"]), float(g["short"]), target.x, target.y, aspect, float(g["area"]),
		float(g["solidity"]), float(g["coast_ratio"]), int(g["islets"]), float(rt._size)])
	print("[t_shapegates-diag] %s dry_tiles=%d dry_blocked=%d region=%s camp=[%.1f, %.1f] arrival=[%.1f, %.1f] river_n=%d head_bank=%.2f wet=%.2f mouth_h=%.2f step_max=%.1f mouth_sea=%s why=%s" % [
		label, dry_total, dry_blocked, region, camp.x, camp.z, arrive.x, arrive.z,
		int(river["n"]), float(river["head_bank"]), float(river["wet"]), float(river["mouth_h"]), float(river["step_max"]), river["mouth_sea"], river["why"]])

## The main landmass along its own principal axes (PCA of its land tiles; the home: east-west), its area, its coast
## per root area, and the islets (land not in the main mass) counted as 4-connected tile groups.
func _land_geometry(rt, east_west: bool = false) -> Dictionary:
	var sh = rt._shape
	var span: int = rt._tile_span
	var half: float = rt._size * 0.5
	var pts := PackedVector2Array()
	var coast := PackedVector2Array()
	var islet := PackedByteArray()
	islet.resize(span * span)
	var islet_dry := 0
	var per := 0
	var mean := Vector2.ZERO
	for z in span:
		for x in span:
			var wx := -half + float(x) + 0.5
			var wz := -half + float(z) + 0.5
			if rt.surface_y(wx, wz) <= WATER_Y:
				continue
			if not sh.on_mainland(wx, wz):
				islet[x + z * span] = 1
				if rt.is_dry(Vector3(wx, 0.0, wz)):
					islet_dry += 1
				continue
			pts.append(Vector2(wx, wz))
			mean += Vector2(wx, wz)
			if rt.surface_y(wx + 1.0, wz) <= WATER_Y or rt.surface_y(wx - 1.0, wz) <= WATER_Y \
					or rt.surface_y(wx, wz + 1.0) <= WATER_Y or rt.surface_y(wx, wz - 1.0) <= WATER_Y:
				per += 1
				coast.append(Vector2(wx, wz))
	var n := maxi(1, pts.size())
	mean /= float(n)
	var cxx := 0.0
	var cxz := 0.0
	var czz := 0.0
	for p in pts:
		var d := p - mean
		cxx += d.x * d.x
		cxz += d.x * d.y
		czz += d.y * d.y
	# The home's box is its east-west frame (where its target, camp and cove are laid out).
	var ang := 0.0 if east_west else 0.5 * atan2(2.0 * cxz, cxx - czz)
	var ax := Vector2(cos(ang), sin(ang))
	var ay := Vector2(-ax.y, ax.x)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		var d := p - mean
		var q := Vector2(d.dot(ax), d.dot(ay))
		lo = lo.min(q)
		hi = hi.max(q)
	var ext := hi - lo + Vector2.ONE
	var hull := Geometry2D.convex_hull(coast)
	var hull_area := 0.0
	for i in hull.size():
		var p0 := hull[i]
		var p1 := hull[(i + 1) % hull.size()]
		hull_area += p0.x * p1.y - p1.x * p0.y
	hull_area = absf(hull_area) * 0.5
	var islets := 0
	var seen := PackedByteArray()
	seen.resize(span * span)
	for i in span * span:
		if islet[i] == 0 or seen[i] == 1:
			continue
		var stack := PackedInt32Array([i])
		seen[i] = 1
		var cnt := 0
		while not stack.is_empty():
			var j := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			cnt += 1
			for k in [j - 1, j + 1, j - span, j + span]:
				if k < 0 or k >= span * span or (absi(k - j) == 1 and k / span != j / span):
					continue
				if islet[k] == 1 and seen[k] == 0:
					seen[k] = 1
					stack.append(k)
		if cnt >= 40:  # an islet you can see: 40 m2 and up
			islets += 1
	return {"long": maxf(ext.x, ext.y), "short": minf(ext.x, ext.y), "area": float(pts.size()),
		"coast_ratio": float(per) / sqrt(maxf(1.0, float(pts.size()))), "islets": islets, "islet_dry": islet_dry,
		"solidity": float(pts.size()) / maxf(1.0, hull_area)}

## River gate. Islans without a river pass ("where an island has one"); a river fails unless its
## head stands on high ground, the stored polyline is one channel, the channel is wet along the
## whole line (measured on the built heightmap) and its mouth is in the sea.
func _river_gate(rt) -> Dictionary:
	var sh = rt._shape
	var out := {"ok": true, "n": 0, "head_bank": 0.0, "wet": 0.0, "mouth_h": 0.0, "step_max": 0.0,
		"mouth_sea": "false", "why": "none"}
	if sh.river.size() < 2:
		# Generator 2 gives every island a river (t_islandgen asserts one per island): no river is
		# a failed river search, not an island without one.
		out["why"] = "no_river"
		out["ok"] = int(sh.gen) < 2
		return out
	var n: int = sh.river.size()
	out["n"] = n
	var head: Vector2 = sh.river[0]
	var mouth: Vector2 = sh.river[n - 1]
	# "Head on the hill": the ground the spring is cut into. The channel itself is at the water
	# plane along its whole length (the engine has one water plane, -0.05 m), so a wet head is
	# never 2 m up; the hill is the bank around it, sampled just outside the channel.
	var hw0: float = sh.river_w[0] if sh.river_w.size() > 0 else 2.0
	var head_bank := -100.0
	for k in 16:
		var a := TAU * float(k) / 16.0
		var q := head + Vector2(cos(a), sin(a)) * (hw0 * 2.6 + 3.0)
		head_bank = maxf(head_bank, rt.surface_y(q.x, q.y))
	var mouth_h: float = rt.surface_y(mouth.x, mouth.y)
	out["head_bank"] = head_bank
	out["mouth_h"] = mouth_h
	var step_max := 0.0
	for i in n - 1:
		step_max = maxf(step_max, sh.river[i].distance_to(sh.river[i + 1]))
	out["step_max"] = step_max
	# Walk the polyline at ~2 m and look at the lowest ground within 2 m of each point: the
	# channel's bed, which a wet river keeps at or under the water plane (the ford included).
	var wet := 0
	var total := 0
	for i in n - 1:
		var a: Vector2 = sh.river[i]
		var b: Vector2 = sh.river[i + 1]
		var steps := maxi(1, int(ceil(a.distance_to(b) / 2.0)))
		for k in steps:
			var p := a.lerp(b, float(k) / float(steps))
			var lowest := INF
			for oy in [-1.5, 0.0, 1.5]:
				for ox in [-1.5, 0.0, 1.5]:
					lowest = minf(lowest, rt.surface_y(p.x + ox, p.y + oy))
			total += 1
			if lowest <= WATER_Y + 0.05:
				wet += 1
	var wet_frac := float(wet) / float(maxi(1, total))
	out["wet"] = wet_frac
	# The mouth's own few metres must be under water too (the last sample is placed past the coast).
	var mouth_sea := mouth_h <= WATER_Y
	out["mouth_sea"] = "true" if mouth_sea else "false"
	var ok := step_max <= RIVER_STEP_MAX_M and head_bank >= RIVER_HEAD_MIN_H and wet_frac >= RIVER_WET_MIN and mouth_sea
	out["ok"] = ok
	if not ok:
		var why := PackedStringArray()
		if step_max > RIVER_STEP_MAX_M:
			why.append("polyline_gap")
		if head_bank < RIVER_HEAD_MIN_H:
			why.append("head_not_on_hill")
		if wet_frac < RIVER_WET_MIN:
			why.append("channel_dry")
		if not mouth_sea:
			why.append("mouth_not_in_sea")
		out["why"] = ",".join(why)
	return out

func _count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_nodes(ch)
	return c

## Top-down silhouette from the built tile map: sea blue, sand, grass, cliff/rock grey, river
## brown, non-walkable land (islets) olive, camp yellow, dock arrival red.
func _save_png(rt, path: String) -> void:
	var span: int = rt._tile_span
	var img := Image.create(span, span, false, Image.FORMAT_RGB8)
	var cols := {0: Color(0.40, 0.62, 0.30), 1: Color(0.62, 0.62, 0.36), 2: Color(0.5, 0.4, 0.28),
		3: Color(0.86, 0.79, 0.58), 4: Color(0.35, 0.6, 0.8), 5: Color(0.55, 0.55, 0.52), 6: Color(0.45, 0.32, 0.2),
		7: Color(0.5, 0.4, 0.28), 8: Color(0.12, 0.25, 0.45), 9: Color(0.3, 0.3, 0.3), 10: Color(0.7, 0.66, 0.5),
		11: Color(0.15, 0.15, 0.15)}
	for z in span:
		for x in span:
			var idx: int = x + z * span
			var t := int(rt.tile_types[idx])
			var c: Color = cols.get(t, Color.MAGENTA)
			if t != 4 and t != 8 and t != 6 and rt.dry_walk[idx] == 0 and t != 11 and t != 10:
				c = c.lerp(Color(0.35, 0.3, 0.1), 0.5)
			img.set_pixel(x, z, c)
	var half: float = rt._size * 0.5
	var marks := [[rt._camp_pos, Color.YELLOW], [rt.arrival_point(), Color.RED]]
	for m in marks:
		var p: Vector3 = m[0]
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var px := int(p.x + half) + dx
				var pz := int(p.z + half) + dz
				if px >= 0 and pz >= 0 and px < span and pz < span:
					img.set_pixel(px, pz, m[1])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
