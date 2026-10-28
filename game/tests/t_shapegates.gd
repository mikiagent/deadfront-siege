extends SceneTree
## ISLANDGEN / roadmap "shape-consumers" acceptance: the FOUR consumer gates the P3 package
## (docs/design/islands-and-loop-plan.md, "Verify:") measures on the built island, on EVERY island
## in the data - the home island with each of the five Tamed Island shapes, and every unstable /
## other island:
##   - 0 dry (land) tiles outside the walkable TilePath grid;
##   - camp-to-dock distance <= 40 m (<= 70 m on the home island), measured camp -> dock arrival;
##   - the river, where the island has one, is connected hill-to-sea: head on high ground, an
##     unbroken wet channel along its polyline, mouth in the sea;
##   - land long/short axes within +-10 % of IslandShape.target_long/target_short for the tier.
## Every island is built through the game's own path (World.load_island -> IslandRuntime.build:
## IslandShape, IslandTerrain, HarbourSite, TilePath); nothing is re-implemented here. The art
## gates (heightmap variety, look) are t_islandgen's and the lab's, not this test's.
## Run: Godot --headless --path game --script res://tests/t_shapegates.gd
##   -> one "[t_shapegates] <island> dry_outside=N camp_dock_m=X river_ok=B size_err=P" line per
##      island, then "[t_shapegates] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

## Watchdog: 20 islands build (2-4 s each) plus the measurement passes; 300 s is a hard stop.
const WATCHDOG_MS := 300000
## Gate limits (plan P3 ISLANDGEN "Verify:"). Not tuned here.
const CAMP_DOCK_MAX_M := 40.0
const CAMP_DOCK_HOME_MAX_M := 70.0
const SIZE_ERR_MAX := 0.10
## ASSUMPTION: "hill" = the channel's head stands at least 2 m above the water plane. The plan
## puts the source on the plateau on the highland flank; a sea-level start is not a river.
const RIVER_HEAD_MIN_H := 2.0
## The polyline is 72 samples over >= half the long axis; a step above 4 m means the stored river
## is not one channel but stitched pieces.
const RIVER_STEP_MAX_M := 4.0
## The channel must be wet at nearly every sample (the ford is shallow but at/below the plane).
const RIVER_WET_MIN := 0.95
## IslandTerrain's water plane (HarbourSite.WATER_Y).
const WATER_Y := -0.05

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
	_world.camp_layout.erase("Harbour")  # every island at its data pose, not a moved dock
	# The home island with each of the five Tamed Island shapes, the way complete_pick() sets it.
	for row in _world.home_shapes:
		if not row is Dictionary:
			continue
		var sid := str((row as Dictionary).get("id", ""))
		if sid == "":
			continue
		_world.home_shape = StringName(sid)
		_world.home_terrain = StringName(str((row as Dictionary).get("terrain", sid)))
		await _measure("home_grassland@%s" % sid, &"home_grassland", true)
	_world.home_shape = &""
	_world.home_terrain = old_terrain
	var ids: Array = _world.islands.keys()
	ids.sort()
	for id in ids:
		if str(id) == "home_grassland":
			continue  # covered above by its five shapes (meadow is the seed-17 legacy core)
		await _measure(str(id), StringName(str(id)), str(_world.def_of(StringName(str(id))).get("kind", "")) == "private")
	_world.home_shape = old_shape
	_world.home_terrain = old_terrain
	_world.camp_layout.erase("Harbour")
	if _fails.is_empty():
		print("[t_shapegates] PASS")
		quit(0)
	else:
		print("[t_shapegates] FAIL count=%d" % _fails.size())
		quit(1)

## Build one island through World.load_island and measure the four gates on the live scene.
func _measure(label: String, id: StringName, is_home: bool) -> void:
	_world.load_island(_host, id, Vector3(0, 1, 0), false)
	await process_frame
	var rt = _world.runtime
	if rt == null or rt._shape == null or rt.pathing == null:
		_expect(false, "%s built a runtime with a shape and TilePath" % label)
		return
	var def: Dictionary = _world.def_of(id)
	var tier := int(def.get("tier", 10))
	var target_long: float = _IS.target_long(tier)
	var target_short: float = _IS.target_short(tier)
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
	if OS.get_environment("SG_PROBE") == "1":
		_probe(label, rt)
	var river: Dictionary = _river_gate(rt)
	_expect(bool(river["ok"]), "%s river_ok=false %s" % [label, str(river)])
	# --- gate 4: land size --------------------------------------------------------------------
	var m: Dictionary = _IS.coast_metrics(rt)
	var bbox: Vector2 = m["bbox"]
	var land_long := maxf(bbox.x, bbox.y)
	var land_short := minf(bbox.x, bbox.y)
	var err_long := (land_long - target_long) / maxf(1.0, target_long)
	var err_short := (land_short - target_short) / maxf(1.0, target_short)
	var size_err := maxf(absf(err_long), absf(err_short))
	_expect(size_err <= SIZE_ERR_MAX, "%s size_err=%.3f (long %.0f vs %.0f, short %.0f vs %.0f)" % [
		label, size_err, land_long, target_long, land_short, target_short])
	print("[t_shapegates] %s dry_outside=%d camp_dock_m=%.1f river_ok=%s size_err=%.3f" % [
		label, dry_out, camp_dock, "true" if bool(river["ok"]) else "false", size_err])
	print("[t_shapegates-diag] %s tier=%d dry_tiles=%d dry_blocked=%d region=%s camp=[%.1f, %.1f] arrival=[%.1f, %.1f] land=%.0fx%.0f target=%.0fx%.0f river_n=%d head_h=%.2f wet=%.2f mouth_h=%.2f step_max=%.1f mouth_sea=%s" % [
		label, tier, dry_total, dry_blocked, region, camp.x, camp.z, arrive.x, arrive.z,
		bbox.x, bbox.y, target_long, target_short, int(river["n"]), float(river["head_h"]),
		float(river["wet"]), float(river["mouth_h"]), float(river["step_max"]), river["mouth_sea"]])

## River gate. Islans without a river pass ("where an island has one"); a river fails unless its
## head stands on high ground, the stored polyline is one channel, the channel is wet along the
## whole line (measured on the built heightmap) and its mouth is in the sea.
func _river_gate(rt) -> Dictionary:
	var sh = rt._shape
	var out := {"ok": true, "n": 0, "head_h": 0.0, "wet": 0.0, "mouth_h": 0.0, "step_max": 0.0,
		"mouth_sea": "false", "why": "none"}
	if sh.river.size() < 2:
		out["why"] = "no_river"
		return out
	var n: int = sh.river.size()
	out["n"] = n
	var head: Vector2 = sh.river[0]
	var mouth: Vector2 = sh.river[n - 1]
	var head_h: float = rt.surface_y(head.x, head.y)
	var mouth_h: float = rt.surface_y(mouth.x, mouth.y)
	out["head_h"] = head_h
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
	var ok := step_max <= RIVER_STEP_MAX_M and head_h >= RIVER_HEAD_MIN_H and wet_frac >= RIVER_WET_MIN and mouth_sea
	out["ok"] = ok
	if not ok:
		var why := PackedStringArray()
		if step_max > RIVER_STEP_MAX_M:
			why.append("polyline_gap")
		if head_h < RIVER_HEAD_MIN_H:
			why.append("head_not_on_hill")
		if wet_frac < RIVER_WET_MIN:
			why.append("channel_dry")
		if not mouth_sea:
			why.append("mouth_not_in_sea")
		out["why"] = ",".join(why)
	return out
