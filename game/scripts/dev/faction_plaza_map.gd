extends SceneTree
## FACTIONS headless check (no window): builds the tutorial island and writes a top-down footprint map
## of the Faction Hall plaza from data (1 px = 0.2 m, 60 m round the camp): land green, roads brown,
## town footprints red (soft = orange), camp pieces yellow, the hall desk white, each faction board in
## its faction colour (general boards grey), townsfolk cyan dots, walkers' paths cyan lines, the dock
## arrival a white ring. Prints the plaza pieces, node counts and the dock -> desk path length.
## Run: Godot --headless --path game --script res://scripts/dev/faction_plaza_map.gd -- --out=<png>

const R := 60.0
const PX := 5.0  ## pixels per metre

var _started := false
var _colours := {}  ## faction id -> banner colour (read from data: no class refs before the autoloads exist)

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _run() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var fj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/factions.json"))
	for k in fj:
		if fj[k] is Dictionary and (fj[k] as Dictionary).has("colour"):
			_colours[k] = fj[k]["colour"]
	var host := Node3D.new()
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 4.0)
	(kit["nav"] as Node).queue_free()
	await process_frame
	var W := root.get_node("World")
	W.load_island(host, &"tutorial_isle", Vector3(0, 1, 0), false)
	await process_frame
	await process_frame
	var rt = W.runtime
	var town = rt.get_node_or_null("TownDress")
	var camp: Vector3 = rt._camp_pos
	var dock: Vector3 = rt.arrival_point()
	var ticking := 0
	for n in root.find_children("*", "", true, false):
		if n.is_processing() or n.is_physics_processing():
			ticking += 1
	print("[plaza-map] scene_nodes=%d ticking=%d town=%s" % [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), ticking, town.stats if town else {}])
	var desk := Vector3.INF
	for n in rt.get_tree().get_nodes_in_group("town_building"):
		var r := Vector2((n as Node3D).global_position.x - camp.x, (n as Node3D).global_position.z - camp.z).length()
		print("[plaza-map] %s role=%s faction=%s r=%.1f" % [n.name, n.get("role"), n.get("faction"), r])
		if n.get("role") == &"guild":
			desk = (n as Node3D).global_position
	var res: Dictionary = rt.pathing.path_result(dock, desk, 0)
	print("[plaza-map] dock -> hall desk reachable=%s" % res.get("reachable"))
	if out != "":
		_png(rt, town, out, camp)
		print("[plaza-map] wrote %s" % out)
	quit(0)

func _png(rt, town, path: String, c: Vector3) -> void:
	var S := int(R * 2.0 * PX)
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var occ: Dictionary = rt.build_grid._occupied
	for y in S:
		for x in S:
			var p := c + Vector3(float(x) / PX - R, 0, float(y) / PX - R)
			var col := Color(0.15, 0.3, 0.6)
			if rt.is_dry(p):
				col = Color(0.3, clampf(0.45 + rt.surface_y(p.x, p.z) * 0.015, 0.3, 0.8), 0.25)
			var t := Vector2i(floori(p.x), floori(p.z))
			if town:
				if town.road_tiles.has(t):
					col = Color(0.6, 0.47, 0.3)
				if town.cells.has(t):
					col = Color(0.85, 0.5, 0.15) if town.soft_cells.has(t) else Color(0.8, 0.18, 0.15)
			if occ.has(t) and (town == null or occ[t] != town):
				var o: Node = occ[t]
				col = Color(1, 0.9, 0.2)
				if o.get("role") == &"guild":
					col = Color.WHITE
				elif o.get("role") == &"faction_board":
					var fid := str(o.get("faction"))
					col = Color(str(_colours.get(fid, "#9a9a9a")))
					if fid == "committee":
						col = Color(0.55, 0.1, 0.15)  # black reads as nothing on the map: its crimson trim
			img.set_pixel(x, y, col)
	var dot := func (p: Vector3, col: Color, rad: int) -> void:
		var px := int((p.x - c.x + R) * PX)
		var py := int((p.z - c.z + R) * PX)
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if px + dx >= 0 and py + dy >= 0 and px + dx < S and py + dy < S and dx * dx + dy * dy <= rad * rad:
					img.set_pixel(px + dx, py + dy, col)
	if town:
		for n in town.npcs:
			var w: Variant = (n as Node).get_meta(&"walk", null)
			if w is Array:
				for k in 60:
					dot.call((w[0] as Vector3).lerp(w[1] as Vector3, float(k) / 59.0), Color(0.3, 0.9, 1.0), 1)
			dot.call((n as Node3D).global_position, Color(0.3, 0.9, 1.0), 4)
	for n in rt.get_tree().get_nodes_in_group("town_building"):
		var role: StringName = n.get("role")
		if role == &"faction_board":
			dot.call((n as Node3D).global_position, Color.BLACK, 9)
			dot.call((n as Node3D).global_position, Color(str(_colours.get(str(n.get("faction")), "#9a9a9a"))), 7)
		elif role == &"guild":
			dot.call((n as Node3D).global_position, Color.BLACK, 11)
			dot.call((n as Node3D).global_position, Color.WHITE, 9)
	var a := rt.arrival_point() as Vector3
	for k in 48:
		var ang := TAU * float(k) / 48.0
		dot.call(a + Vector3(cos(ang), 0, sin(ang)) * 2.0, Color.WHITE, 1)
	img.save_png(path)
