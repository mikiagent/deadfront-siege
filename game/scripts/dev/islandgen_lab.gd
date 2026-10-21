extends Node3D
## ISLANDGEN measuring lab (windowed; needs a renderer for the shots).
## Loads every island in turn and prints one machine-readable line per island:
##   [islandgen] id=<id> land=<m2> bbox=<w>x<h> aspect=<a> peninsulas=<n> coast_ratio=<P/sqrtA>
##               cliff_cells=<n> river_to_sea=<true|false> build_ms=<ms> nodes=<n> crest=<m> ...
## and (with --shot-dir=<dir>) saves a top-down orthographic shot per island.
## Run:
##   Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- \
##     --lab=islandgen_lab --shot-dir=/tmp/isg_shots
## Optional: --ids=a,b (default: all), --no-shots.

var _args := {}
var _shot_dir := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_shot_dir = str(_args.get("shot-dir", ""))
	Game.debug_overlay = false
	Game.shot_path = ""  # the lab saves its own shots
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run() -> void:
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
	var ids: Array = []
	if _args.has("ids"):
		for s in str(_args["ids"]).split(",", false):
			ids.append(StringName(s))
	else:
		ids = World.islands.keys()
		ids.sort()
	# A bare host with one player and one light: no HUD, no lab floor, so the fps and the node
	# count are the island's own.
	var host := Node3D.new()
	host.name = "IslandgenLab"
	add_child(host)
	WorldLighting.install(host, "temperate")
	for id in ids:
		var t0 := Time.get_ticks_usec()
		World.load_island(host, StringName(str(id)), Vector3(0, 1, 0), false)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		await _frames(3)
		var rt: IslandRuntime = World.runtime
		# Top-down shots are judged on shape and relief: the island's fog and haze wash them grey.
		if rt != null and rt.world_env != null and rt.world_env.environment != null:
			var env := rt.world_env.environment
			env.fog_enabled = false
			env.tonemap_exposure = maxf(1.0, env.tonemap_exposure)
		if rt == null:
			print("[islandgen] id=%s ERROR no runtime" % id)
			continue
		var m: Dictionary = IslandShape.coast_metrics(rt)
		var bbox: Vector2 = m["bbox"]
		var crest := 0.0
		for h in rt._heights:
			crest = maxf(crest, h)
		var nodes := rt.harvest_count
		var scene_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var dry_unwalk := _dry_outside_path(rt)
		print("[islandgen] id=%s land=%d bbox=%.0fx%.0f aspect=%.2f peninsulas=%d solidity=%.2f coast_ratio=%.2f cliff_cells=%d river_to_sea=%s waterfall=%s build_ms=%.0f nodes=%d scene_nodes=%d crest=%.1f dry_unwalkable=%d ford=%s" % [
			id, int(m["land"]), bbox.x, bbox.y, float(m["aspect"]), int(m["peninsulas"]),
			float(m["solidity"]), float(m["coast_ratio"]), int(m["cliff_cells"]), "true" if _river_sea(rt) else "false",
			"true" if rt._shape != null and rt._shape.waterfall != Vector3.ZERO else "false",
			ms, nodes, scene_nodes, crest, dry_unwalk,
			str(rt._shape.ford.snapped(Vector2.ONE)) if rt._shape != null else "none",
		])
		var arr: Vector3 = rt.arrival_point()
		print("[islandgen-harbour] id=%s harbour=[%.1f, 0, %.1f]" % [id, arr.x, arr.z])
		if _args.has("pens"):
			for p in m["pen_details"]:
				print("[islandgen-pen] %s len=%.0f width=%.0f angle=%.0f ratio=%.2f" % [id, float(p["length"]), float(p["width"]), float(p.get("angle", 0.0)), float(p["ratio"])])
		if _args.has("probe") and str(id) == str(_args["probe"]):
			await _probe(rt)
		if _shot_dir != "" and not _args.has("no-shots"):
			await _shot(str(id), rt, bbox)
		if _shot_dir != "" and _args.has("river-shot") and rt._shape != null and rt._shape.river.size() > 0:
			var mid: Vector2 = rt._shape.river[rt._shape.river.size() / 2]
			await _shot_at(str(id) + "_river", Vector3(mid.x, rt.surface_y(mid.x, mid.y), mid.y), rt)
		if _shot_dir != "" and _args.has("iso-shots"):
			await _iso_shot(str(id), rt)
	# Let the last island settle before quitting (the shot already awaited a frame).
	await _frames(2)
	get_tree().quit(0)

## Diagnostics: camp->arrival pathing, a moved-harbour hint, the river's block, the region.
func _probe(rt: IslandRuntime) -> void:
	var arrive: Vector3 = rt.arrival_point()
	var pts: PackedVector3Array = rt.pathing.path(rt._camp_pos, arrive, 0)
	print("[islandgen-probe] %s region=%s reachable=%s points=%d camp=%s arrive=%s" % [
		rt.name, rt.pathing._region, rt.pathing.last_reachable, pts.size(), rt._camp_pos, arrive])
	var lane := 0
	for z in rt._tile_span:
		var row_dry := 0
		for x in rt._tile_span:
			var wx := -rt._size * 0.5 + float(x) + 0.5
			var wz := -rt._size * 0.5 + float(z) + 0.5
			if rt.is_dry(Vector3(wx, 0.0, wz)):
				row_dry += 1
		if row_dry == 0:
			lane += 1
	print("[islandgen-probe] rows_with_no_dry=%d of %d tile rows" % [lane, rt._tile_span])
	print("[islandgen-probe] %s" % _connectivity(rt))
	if _args.has("coast"):
		# How many bearings give a legal dock pose, and where the refusals are.
		var ok := 0
		var why := {}
		var half := rt._size * 0.5 - 1.0
		for i in 72:
			var ang := TAU * float(i) / 72.0
			var dir := Vector2(cos(ang), sin(ang))
			var r := half
			while r > 0.0 and rt.surface_y(dir.x * r, dir.y * r) <= HarbourSite.WATER_Y:
				r -= 0.5
			var rot := HarbourSite.rot_toward(dir)
			var code := "no_land"
			for back in 4:
				var cell := HarbourSite.cell_for_base(dir * r - HarbourSite.seaward(rot) * float(back), rot)
				var c := HarbourSite.check(rt, cell, rot)
				if c == "":
					code = "ok" if HarbourSite._reaches_dry(rt, cell, rot) else "no_dry_reach"
					if code == "ok":
						ok += 1
					break
				code = c
			why[code] = int(why.get(code, 0)) + 1
			if _args.has("coastlines") and code != "ok":
				var hr := ""
				for k in 10:
					hr += "%.2f " % rt.surface_y(dir.x * (r + float(k)), dir.y * (r + float(k)))
				print("[islandgen-probe] bearing %d r=%.1f rot=%d %s out: %s" % [i, r, rot, code, hr])
		print("[islandgen-probe] legal coast bearings %d/72 %s" % [ok, why])
	if _args.has("riverprobe"):
		var sh: IslandShape = rt._shape
		print("[islandgen-probe] shore0=%.1f centre=%s" % [sh.shore0, sh.centre])
		for i in range(0, sh.river.size(), 6):
			var q: Vector2 = sh.river[i]
			print("[islandgen-probe] river %d at %s h=%.2f tile=%d w=%.1f d=%.1f rad=%.1f" % [i, q.snapped(Vector2.ONE * 0.1), rt.surface_y(q.x, q.y), rt._tile_type_at_world(q.x, q.y), sh.river_w[i], sh.river_dist(q.x, q.y), sh.rad(q.x, q.y)])
	if _args.has("seaprobe"):
		var kit := LabKit.build(self, 4.0)
		var pl: Player = kit["player"]
		for spot in [Vector3(-11.5, 0.0, 72.0), Vector3(-40.0, 0.0, 80.0)]:
			pl.velocity = Vector3.ZERO
			pl.global_position = Vector3(spot.x, rt.surface_y(spot.x, spot.z) + 0.1, spot.z)
			for i in 10:
				await get_tree().physics_frame
			print("[islandgen-probe] seat %s -> pos=%s surf=%.2f in_water=%s tile=%d" % [spot, pl.global_position, rt.surface_y(pl.global_position.x, pl.global_position.z), pl.in_water, rt._tile_type_at_world(pl.global_position.x, pl.global_position.z)])
	if _args.has("layout"):
		var lp := str(_args["layout"]).split(",")
		World.camp_layout["Harbour"] = {"cell": [int(lp[0]), int(lp[1])], "rot": int(lp[2])}
		print("[islandgen-probe] layout set: %s" % str(World.camp_layout))
		World.load_island(host_get(), rt_id(rt), Vector3.ZERO, false)
		await get_tree().process_frame
		var rt2: IslandRuntime = World.runtime
		print("[islandgen-probe] layout load: cell=%s rot=%d arrival=%s json=%s" % [
			rt2.harbour.build_cell, rt2.harbour.build_rot, rt2.arrival_point(),
			str(World.islands.get(str(World.island_id), {}).get("harbour", []))])
		World.camp_layout.erase("Harbour")
	if _args.has("hint"):
		var hp := str(_args["hint"]).split(",")
		var site: Dictionary = HarbourSite.find(rt, Vector2(float(hp[0]), float(hp[1])))
		print("[islandgen-probe] find(hint %s) -> %s" % [_args["hint"], site])

## Flood fill the dry tiles 4-connected: how many land regions, and is the arrival reachable
## on foot from the camp (the two numbers the harbour test cares about).
func _connectivity(rt: IslandRuntime) -> String:
	var span: int = rt._tile_span
	var seen := PackedByteArray()
	seen.resize(span * span)
	var regions := 0
	var biggest := 0
	for i in span * span:
		if rt.dry_walk[i] == 0 or seen[i] == 1:
			continue
		regions += 1
		var size := 0
		var stack: Array[int] = [i]
		seen[i] = 1
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			size += 1
			var cx: int = cur % span
			var cz: int = cur / span
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = cx + (d as Vector2i).x
				var nz: int = cz + (d as Vector2i).y
				if nx < 0 or nz < 0 or nx >= span or nz >= span:
					continue
				var ni: int = nx + nz * span
				if seen[ni] == 0 and rt.dry_walk[ni] == 1:
					seen[ni] = 1
					stack.append(ni)
		biggest = maxi(biggest, size)
	var camp_i: int = _tile_index(rt, rt._camp_pos)
	var arr: Vector3 = rt.arrival_point()
	# The arrival sits on the beach (not dry_walk); walk inland from it to the first dry tile.
	var arr_dry := -1
	var arr_t := Vector2i(floori(arr.x + rt._size * 0.5), floori(arr.z + rt._size * 0.5))
	for k in 40:
		for d in [Vector2i(0, k), Vector2i(k, 0), Vector2i(0, -k), Vector2i(-k, 0), Vector2i(k, k), Vector2i(-k, k), Vector2i(k, -k), Vector2i(-k, -k)]:
			var t: Vector2i = arr_t + (d as Vector2i)
			if t.x >= 0 and t.y >= 0 and t.x < span and t.y < span and rt.dry_walk[t.x + t.y * span] == 1:
				arr_dry = t.x + t.y * span
				break
		if arr_dry >= 0:
			break
	return "land_regions=%d biggest=%d camp_dry=%d camp_ok=%s arrival_dry=%d same_region=%s" % [
		regions, biggest, camp_i, str(camp_i >= 0 and camp_i < span * span and rt.dry_walk[camp_i] == 1), arr_dry,
		str(arr_dry >= 0 and _same_region(rt, camp_i, arr_dry))]

func _same_region(rt: IslandRuntime, a: int, b: int) -> bool:
	if a < 0 or b < 0:
		return false
	var span: int = rt._tile_span
	var stack: Array[int] = [a]
	var seen := {a: true}
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		if cur == b:
			return true
		var cx: int = cur % span
		var cz: int = cur / span
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = cx + (d as Vector2i).x
			var nz: int = cz + (d as Vector2i).y
			if nx < 0 or nz < 0 or nx >= span or nz >= span:
				continue
			var ni: int = nx + nz * span
			if not seen.has(ni) and rt.dry_walk[ni] == 1:
				seen[ni] = true
				stack.append(ni)
	return false

## Tile-map index of a world position (the tile loop indexes 0..span from -size/2).
func _tile_index(rt: IslandRuntime, p: Vector3) -> int:
	var tx := clampi(int(floor(p.x + rt._size * 0.5)), 0, rt._tile_span - 1)
	var tz := clampi(int(floor(p.z + rt._size * 0.5)), 0, rt._tile_span - 1)
	return tx + tz * rt._tile_span

func host_get() -> Node:
	return get_node_or_null("IslandgenLab")

func rt_id(rt: IslandRuntime) -> StringName:
	return World.island_id

## Dry land that TilePath cannot reach (the scout measured 333 such tiles on the prototype).
func _dry_outside_path(rt: IslandRuntime) -> int:
	if rt.pathing == null:
		return -1
	var n := 0
	var span: int = rt._tile_span
	for z in span:
		for x in span:
			var wx := -rt._size * 0.5 + float(x) + 0.5
			var wz := -rt._size * 0.5 + float(z) + 0.5
			if rt.is_dry(Vector3(wx, 0.0, wz)) and not rt.pathing.is_walkable(Vector2i(floori(wx), floori(wz))):
				n += 1
	return n

func _river_sea(rt: IslandRuntime) -> bool:
	# The same predicate t_islandgen asserts (IslandShape.river_to_sea: the last sample is at or past
	# the coastline).
	return rt._shape != null and rt._shape.river_to_sea()

## A close three-quarter view of a point (the river, a cliff).
func _shot_at(tag: String, at: Vector3, rt: IslandRuntime) -> void:
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.far = rt._size * 4.0
	# Straight down from 70 m: the channel's shape and its water are judged without foreshortening.
	cam.position = at + Vector3(0.0, 70.0, 0.0)
	cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	cam.far = rt._size * 4.0
	add_child(cam)
	cam.make_current()
	for cl in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img:
		var out := "%s/%s.png" % [_shot_dir, tag]
		img.save_png(out)
		print("[islandgen-shot] %s %dx%d" % [out, img.get_width(), img.get_height()])
	cam.queue_free()
	await _frames(1)

## A three-quarter view over the camp (what the player sees): relief, cliffs and the river read.
func _iso_shot(id: String, rt: IslandRuntime) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 42.0
	cam.far = rt._size * 4.0
	var c: Vector3 = rt._camp_pos
	# Close over the camp looking inland at the highland (the gameplay view, no sea edge in frame).
	cam.position = c + Vector3(-60.0, 60.0, 80.0)
	cam.look_at(c + Vector3(10.0, 3.0, -60.0))
	add_child(cam)
	cam.make_current()
	for cl in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img:
		var out := "%s/%s_iso.png" % [_shot_dir, id]
		img.save_png(out)
		print("[islandgen-shot] %s %dx%d" % [out, img.get_width(), img.get_height()])
	cam.queue_free()
	await _frames(1)

## Top-down orthographic shot of the whole grid square, HUD hidden.
func _shot(id: String, rt: IslandRuntime, bbox: Vector2) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rt._size * 1.02
	cam.far = rt._size * 3.0
	cam.position = Vector3(0.0, rt._size * 1.5, 0.0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	add_child(cam)
	cam.make_current()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img:
		var out := "%s/%s_top.png" % [_shot_dir, id]
		img.save_png(out)
		print("[islandgen-shot] %s %dx%d" % [out, img.get_width(), img.get_height()])
	cam.queue_free()
	await _frames(1)
