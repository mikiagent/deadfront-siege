extends SceneTree
## MAPLAB acceptance: the map document the map lab paints and exports (MapDoc).
##   - painting cells changes the grid (brush, sea clears the other layers, fill);
##   - undo/redo restore the exact state;
##   - export -> import -> export is identical (JSON text and every layer), sample.map.json included;
##   - the validator catches no land, a dock off the coast, a marker in the sea, an unknown species,
##     a bad level and a river with no outlet, and passes the sample with no errors;
##   - markers keep their properties through edits, undo and the round trip;
##   - the importer builds a real IslandRuntime from the sample: land where the map has land, sea
##     where it has sea, painted zones in the zone map, the dock and spawns from the markers.
## Run: Godot --headless --path game --script res://tests/t_maplab.gd -> "[t_maplab] PASS", 0/1.

var _fails: PackedStringArray = []
var _started := false

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_maplab] FAIL %s" % what)

func _run() -> void:
	var MD := load("res://scripts/world/map_doc.gd") as GDScript
	_paint(MD)
	_history(MD)
	_round_trip(MD)
	_validator(MD)
	await _lab_ui()
	await _importer(MD)
	if _fails.is_empty():
		print("[t_maplab] PASS")
		quit(0)
	else:
		print("[t_maplab] FAIL count=%d" % _fails.size())
		quit(1)

func _paint(MD: GDScript) -> void:
	var d = MD.make(128.0, 4.0)
	_expect(d.cells == 32 and d.count("land", 1) == 0, "a new 128 m map is 32 x 32 cells of sea")
	d.paint("land", 16, 16, 3.0, 1)
	var n: int = d.count("land", 1)
	_expect(n == 29, "a radius-3 land brush paints 29 cells (got %d)" % n)
	d.paint("zone", 30, 30, 1.0, 2)
	_expect(d.get_cell("zone", 30, 30) == 0, "a zone brush on the sea paints nothing")
	d.paint("zone", 16, 16, 1.0, 2)
	d.paint("height", 16, 16, 0.0, 2)
	_expect(d.get_cell("zone", 16, 16) == 2 and d.get_cell("height", 16, 16) == 2, "zone and height paint on land")
	d.paint("land", 16, 16, 0.0, 0)
	_expect(not d.is_land(16, 16) and d.get_cell("zone", 16, 16) == 0 and d.get_cell("height", 16, 16) == 0, "painting sea clears the cell's other layers")
	d.paint("land", 16, 16, 0.0, 1)
	d.fill("zone", 13, 16, 4)
	_expect(d.count("zone", 4) == d.count("land", 1) - 5, "fill paints the connected unzoned land (not the 4 forest cells or the cell they wall in) (%d of %d)" % [d.count("zone", 4), d.count("land", 1)])
	d.fill("land", 0, 0, 1)
	_expect(d.count("land", 1) == 32 * 32, "a land fill from the sea fills all the connected sea")

func _history(MD: GDScript) -> void:
	var d = MD.make(128.0, 4.0)
	d.begin_edit()
	d.paint("land", 10, 10, 2.0, 1)
	var after: Dictionary = d.to_json()
	d.begin_edit()
	var m: Dictionary = d.add_marker("spawn", 0.0, 0.0, {"species": "zebraceratops", "level": 7})
	d.begin_edit()
	m["props"]["count"] = 5
	_expect(d.undo() and int(d.marker(int(m["id"]))["props"]["count"]) == 2, "undo restores a marker's property")
	_expect(d.undo() and d.markers.is_empty(), "undo removes the added marker")
	_expect(JSON.stringify(d.to_json()) == JSON.stringify(after), "after two undos the map is the painted one")
	_expect(d.undo() and d.count("land", 1) == 0, "undo of the stroke leaves a blank map")
	_expect(not d.undo(), "nothing left to undo")
	_expect(d.redo() and d.count("land", 1) == 13, "redo repaints the stroke")
	_expect(d.redo() and d.redo() and int(d.markers[0]["props"]["count"]) == 5 and str(d.markers[0]["props"]["species"]) == "zebraceratops",
		"redo brings the marker back with its properties")
	_expect(not d.redo(), "nothing left to redo")
	d.begin_edit()
	d.resize(256.0, 8.0)
	_expect(d.undo() and d.cells == 32 and is_equal_approx(d.size_m, 128.0), "undo restores the map size")

func _round_trip(MD: GDScript) -> void:
	var lab := load("res://scripts/dev/map_lab.gd") as GDScript
	var d = lab.build_sample()
	var a := JSON.stringify(d.to_json(), "\t")
	var errs: Array = []
	var back = MD.from_json(JSON.parse_string(a), errs)
	_expect(back != null, "the sample re-imports (%s)" % "; ".join(errs))
	if back == null:
		return
	_expect(JSON.stringify(back.to_json(), "\t") == a, "export -> import -> export is identical")
	for l in MD.LAYERS:
		_expect(back.layers[l] == d.layers[l], "layer %s round-trips" % l)
	var spawn: Dictionary = {}
	for m in back.markers:
		if str(m["kind"]) == "spawn" and str(m["props"]["species"]) == "zebraceratops":
			spawn = m
	_expect(not spawn.is_empty() and int(spawn["props"]["level"]) == 3 and int(spawn["props"]["count"]) == 3 and is_equal_approx(float(spawn["props"]["radius_m"]), 24.0),
		"a spawn marker keeps species, level, count and radius")
	var guild_ok: bool = back.markers.any(func(m: Dictionary) -> bool: return str(m["kind"]) == "guild" and str(m["props"]["name"]) == "Adventurer's Guild")
	_expect(guild_ok, "the guild keeps its name")
	# The committed sample is the one build_sample paints (re-run --make-sample after changing it).
	var disk = MD.load_file("res://data/maps/sample.map.json", errs)
	_expect(disk != null and JSON.stringify(disk.to_json(), "\t") == a, "game/data/maps/sample.map.json matches build_sample()")
	_expect(MD.from_json({"format": "wildlands.map", "version": 2}, []) == null, "a future version is refused")
	var bad: Dictionary = d.to_json()
	(bad["layers"]["land"] as Array)[3] = "x".repeat(d.cells)
	var e2: Array = []
	_expect(MD.from_json(bad, e2) == null and str(e2).contains("unknown character"), "a bad layer character is refused with a message")

func _codes(d) -> Array:
	return d.issues().map(func(i: Dictionary) -> String: return str(i["code"]))

func _validator(MD: GDScript) -> void:
	var lab := load("res://scripts/dev/map_lab.gd") as GDScript
	var s = lab.build_sample()
	_expect(s.errors().is_empty() and s.issues().is_empty(), "the sample has no issues (%s)" % str(_codes(s)))
	var empty = MD.make(128.0, 4.0)
	_expect(_codes(empty).has("no_land"), "a blank map reports no_land")
	var d = MD.make(256.0, 4.0)
	d.paint("land", 32, 32, 12.0, 1)
	d.add_marker("dock", 0.0, 0.0)  # the middle of the island
	_expect(_codes(d).has("dock_not_coast"), "a dock inland reports dock_not_coast")
	var coast: Vector2 = d.cell_centre(32, 44)
	d.markers.clear()
	d.add_marker("dock", coast.x, coast.y)
	_expect(not _codes(d).has("dock_not_coast"), "a dock at the coast passes (%s)" % str(_codes(d)))
	d.add_marker("town", -120.0, -120.0)
	_expect(_codes(d).has("marker_in_sea"), "a town in the sea reports marker_in_sea")
	d.markers.pop_back()
	d.add_marker("spawn", 0.0, 0.0, {"species": "dragon", "level": 99})
	var c: Array = _codes(d)
	_expect(c.has("unknown_species") and c.has("bad_level"), "an unknown species and level 99 are caught (%s)" % str(c))
	d.markers.pop_back()
	d.add_marker("resource", 0.0, 0.0, {"resource": "gold"})
	_expect(_codes(d).has("unknown_resource"), "an unknown resource group is caught")
	d.markers.pop_back()
	d.paint("water", 32, 32, 1.0, 1)  # a river puddle in the middle of the land
	_expect(_codes(d).has("river_no_outlet"), "a river that reaches nothing is reported")
	for r in range(32, 46):
		d.paint("water", 32, r, 0.0, 1)
	_expect(not _codes(d).has("river_no_outlet"), "a river to the sea passes")
	d.climate = "atlantis"
	_expect(_codes(d).has("unknown_climate"), "an unknown climate is caught")
	d.climate = "grassland"
	d.paint("land", 1, 1, 0.0, 1)
	_expect(_codes(d).has("land_at_edge"), "land at the map edge is reported")

## The lab itself: a press and drag on the canvas paint with the active tool, a marker tool drops a
## marker with its kind's fields, and Undo takes the drag back.
func _lab_ui() -> void:
	var lab: Node = (load("res://scenes/dev/map_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame
	var canvas: Control = lab.get("_canvas")
	var r: Rect2 = canvas.map_rect()
	_expect(r.size.x >= 600.0, "the map canvas is at least 600 px square at 1600 x 900 (%.0f)" % r.size.x)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = r.position + r.size * 0.5
	canvas._gui_input(down)
	var move := InputEventMouseMotion.new()
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	move.position = r.position + r.size * Vector2(0.7, 0.5)
	canvas._gui_input(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = move.position
	canvas._gui_input(up)
	var doc = lab.get("doc")
	var land: int = doc.count("land", 1)
	_expect(land > 80, "a tap and drag with Land paints a stroke (%d cells)" % land)
	lab.set("tool", "marker:spawn")
	canvas._gui_input(down)
	canvas._gui_input(up)
	_expect(doc.markers.size() == 1 and str(doc.markers[0]["props"].get("species", "")) != "" and int(lab.get("selected")) == int(doc.markers[0]["id"]),
		"the Spawn tool drops a selected spawn marker with its fields")
	lab.call("_undo")
	lab.call("_undo")
	_expect(doc.count("land", 1) == 0 and doc.markers.is_empty(), "two Undo presses take back the marker and the stroke")
	for b in lab.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree() and (b as Button).get_global_rect().size.y > 0.0:
			_expect((b as Button).size.y >= 63.5, "button '%s' is a 64 px tap target (%.0f)" % [(b as Button).text, (b as Button).size.y])
	lab.queue_free()
	await process_frame

func _importer(MD: GDScript) -> void:
	var lab := load("res://scripts/dev/map_lab.gd") as GDScript
	var d = lab.build_sample()
	var host := Node3D.new()
	root.add_child(host)
	var rt = (load("res://scripts/world/island_runtime.gd") as GDScript).new()
	host.add_child(rt)
	var def: Dictionary = d.island_def({"id": "map_sample", "kind": "unstable", "tier": 10, "level_override": 1})
	rt.build(def, &"meadow")
	await process_frame
	var hits := 0
	var total := 0
	var zone_hits := 0
	var zone_total := 0
	var bio: PackedByteArray = rt.get_meta("biome_types", PackedByteArray())
	for r in range(0, d.cells, 3):
		for c in range(0, d.cells, 3):
			var p: Vector2 = d.cell_centre(c, r)
			# Skip the coast's own cells (the coastline runs along cell edges, the ground is smooth).
			var mixed := false
			for dr in range(-1, 2):
				for dc in range(-1, 2):
					if d.is_land(c + dc, r + dr) != d.is_land(c, r):
						mixed = true
			if mixed or d.get_cell("water", c, r) != 0:
				continue
			total += 1
			var dry: bool = rt.surface_y(p.x, p.y) > 0.0
			if dry == d.is_land(c, r):
				hits += 1
			var z: int = d.get_cell("zone", c, r)
			if z > 0 and z != 7:  # the beach strip is re-decided by the sand rule; inland zones must hold
				zone_total += 1
				var span: int = rt._tile_span
				var tx := int(p.x + rt._size * 0.5)
				var tz := int(p.y + rt._size * 0.5)
				if bio[tx + tz * span] == z - 1:
					zone_hits += 1
	_expect(total > 400 and float(hits) / float(total) > 0.98, "the built island has land where the map has land (%d / %d cells)" % [hits, total])
	_expect(zone_total > 100 and float(zone_hits) / float(zone_total) > 0.98, "the painted zones are the island's zones (%d / %d)" % [zone_hits, zone_total])
	var hill: Vector2 = d.cell_centre(70, 27)
	var low: Vector2 = d.cell_centre(48, 56)
	_expect(rt.surface_y(hill.x, hill.y) > rt.surface_y(low.x, low.y) + 4.0, "the painted mountain stands above the meadow (%.1f vs %.1f m)" % [rt.surface_y(hill.x, hill.y), rt.surface_y(low.x, low.y)])
	var dock: Dictionary = d.markers.filter(func(m: Dictionary) -> bool: return str(m["kind"]) == "dock")[0]
	var hp: Vector3 = rt.harbour.global_position
	_expect(Vector2(hp.x, hp.z).distance_to(Vector2(float(dock["x"]), float(dock["z"]))) < 30.0, "the harbour is built at the dock marker (%s)" % hp)
	_expect(int(rt.creature_count) >= 5, "the spawn markers place creatures (%d)" % int(rt.creature_count))
	host.queue_free()
