extends SceneTree
## TUTTOWN headless check (no window): builds the tutorial island, prints the town's numbers, the
## scene / ticking node counts, the dock and camp, the reachability of every order target and wild
## zone, and writes a top-down footprint map PNG from data (1 px = 0.5 m around the town):
## sea blue, dry land green (lighter = higher), roads brown, houses / stalls / pens red, fields and
## workshops orange, camp pieces yellow, harvest nodes dark dots, wild zones purple rings, the safe
## ring white. Also suggests a camp spot inland of the dock (--suggest).
## Run: Godot --headless --path game --script res://scripts/dev/tuttown_map.gd -- [--out=<png>] [--suggest]

var _started := false

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _run() -> void:
	var out := ""
	var suggest := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		suggest = suggest or a == "--suggest"
	var host := Node3D.new()
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 4.0)
	(kit["nav"] as Node).queue_free()
	await process_frame
	var n0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var t0 := Time.get_ticks_msec()
	var W := root.get_node("World")
	W.load_island(host, &"tutorial_isle", Vector3(0, 1, 0), false)
	var ms := Time.get_ticks_msec() - t0
	await process_frame
	await process_frame
	var rt = W.runtime
	var town = rt.get_node_or_null("TownDress")
	var ticking := 0
	for n in rt.find_children("*", "", true, false):
		if n.is_processing() or n.is_physics_processing():
			ticking += 1
	var mmi: Array = rt.find_children("*", "MultiMeshInstance3D", true, false)
	var camp: Vector3 = rt._camp_pos
	var dock: Vector3 = rt.arrival_point()
	print("[tuttown-map] build_ms=%d scene_nodes=%d added=%d ticking=%d mmi=%d dock=%s camp=%s dock_to_camp=%.0f" % [ms,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - n0,
		ticking, mmi.size(), dock.snapped(Vector3.ONE), camp.snapped(Vector3.ONE), Vector2(dock.x - camp.x, dock.z - camp.z).length()])
	if town:
		print("[tuttown-map] town %s refused=%s" % [town.stats, town.refused])
	var bad := []
	var targets := {}
	for z in rt.find_children("WildZone_*", "", false, false):
		targets[str(z.name)] = (z as Node3D).global_position
	for g in ["town_building", "craft_station", "bonfire"]:
		for n in rt.get_tree().get_nodes_in_group(g):
			targets[str(n.name)] = (n as Node3D).global_position
	for k in targets:
		var res: Dictionary = rt.pathing.path_result(dock, targets[k], 0)
		if not bool(res["reachable"]):
			bad.append(k)
	print("[tuttown-map] unreachable from the dock: %s (of %d)" % [bad, targets.size()])
	var water: Variant = load("res://scripts/core/tutorial.gd").call("nearest_fresh_water", camp)
	var sp := {}
	for z in rt.find_children("WildZone_*", "", false, false):
		sp[str(z.get("species"))] = Vector2((z as Node3D).global_position.x - camp.x, (z as Node3D).global_position.z - camp.z).length()
	print("[tuttown-map] fresh water %s (%.0f m) zones %s" % [water, (water as Vector3).distance_to(camp) if water is Vector3 else -1.0, sp])
	if suggest:
		_suggest(rt, dock)
		for r in range(5, 500, 5):
			var hit := Vector3.INF
			for k in maxi(8, int(TAU * r / 5.0)):
				var a := TAU * float(k) / maxf(8.0, floorf(TAU * r / 5.0))
				var q := camp + Vector3(cos(a), 0, sin(a)) * float(r)
				if load("res://scripts/world/island_terrain.gd").call("fresh_water_at_world", rt, q.x, q.z) and rt.surface_y(q.x, q.z) < -0.05:
					hit = q
					break
			if hit != Vector3.INF:
				print("[tuttown-map] nearest river %s at %d m" % [hit.snapped(Vector3.ONE), r])
				break
	if out != "":
		_png(rt, town, out, camp)
		print("[tuttown-map] wrote %s" % out)
	quit(0)

## The flattest dry spot 30-50 m inland of the dock with 60 m of dry land around it.
func _suggest(rt, dock: Vector3) -> void:
	var best := Vector3.INF
	var best_s := INF
	for r in range(28, 52, 4):
		for k in 36:
			var a := TAU * float(k) / 36.0
			var p := dock + Vector3(cos(a), 0, sin(a)) * float(r)
			var dry := 0
			var lo := INF
			var hi := -INF
			for j in 24:
				var b := TAU * float(j) / 24.0
				for rr in [10.0, 25.0, 45.0, 65.0]:
					var q: Vector3 = p + Vector3(cos(b), 0, sin(b)) * rr
					if rt.is_dry(q):
						dry += 1
						if rr <= 25.0:
							lo = minf(lo, rt.surface_y(q.x, q.z))
							hi = maxf(hi, rt.surface_y(q.x, q.z))
			var score: float = -float(dry) + (hi - lo) * 2.0
			if rt.is_dry(p) and score < best_s:
				best_s = score
				best = p
	print("[tuttown-map] suggested camp %s (score %.1f)" % [best.snapped(Vector3.ONE), best_s])

func _png(rt, town, path: String, c: Vector3) -> void:
	var R := 130
	var S := R * 4
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var occ: Dictionary = rt.build_grid._occupied
	for y in S:
		for x in S:
			var p := c + Vector3(float(x) * 0.5 - R, 0, float(y) * 0.5 - R)
			var col := Color(0.15, 0.3, 0.6)
			if rt.is_dry(p):
				var h: float = rt.surface_y(p.x, p.z)
				col = Color(0.3, clampf(0.45 + h * 0.015, 0.3, 0.8), 0.25)
			var t := Vector2i(floori(p.x), floori(p.z))
			if town:
				if town.road_tiles.has(t):
					col = Color(0.6, 0.47, 0.3)
				if town.cells.has(t):
					col = Color(0.85, 0.5, 0.15) if town.soft_cells.has(t) else Color(0.8, 0.18, 0.15)
			if occ.has(t) and (town == null or occ[t] != town):
				col = Color(1, 0.9, 0.2)
			img.set_pixel(x, y, col)
	var dot := func (p: Vector3, col: Color, rad: int) -> void:
		var px := int((p.x - c.x + R) * 2.0)
		var py := int((p.z - c.z + R) * 2.0)
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if px + dx >= 0 and py + dy >= 0 and px + dx < S and py + dy < S and dx * dx + dy * dy <= rad * rad:
					img.set_pixel(px + dx, py + dy, col)
	for n in rt.get_tree().get_nodes_in_group("harvest"):
		dot.call((n as Node3D).global_position, Color(0.1, 0.2, 0.1), 1)
	var safe := float(rt.get_parent().get_node("/root/World").def_of(&"tutorial_isle").get("town_safe_m", 100.0))
	for k in 360:
		var a := TAU * float(k) / 360.0
		dot.call(c + Vector3(cos(a), 0, sin(a)) * safe, Color.WHITE, 0)
	for z in rt.find_children("WildZone_*", "", false, false):
		for k in 24:
			var a := TAU * float(k) / 24.0
			dot.call((z as Node3D).global_position + Vector3(cos(a), 0, sin(a)) * 4.0, Color(0.7, 0.3, 0.9), 1)
	dot.call(rt.arrival_point(), Color(1, 1, 1), 3)
	img.save_png(path)
