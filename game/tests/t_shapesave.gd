extends SceneTree
## ISLANDS2 saves gate: generator 2 (the country coasts) moves land, so a save made on generator 1
## keeps generator 1 for the islands its buildings stand on.
##   - control: every building cell in the fixture is dry on generator 1 and NOT dry on generator 2
##     (so the fixture really holds buildings the new coast would drown);
##   - an old save (no shape_gen stamp) standing on temperate_25 loads that island on generator 1 with
##     every away basket rebuilt on dry land and nothing refunded; it re-saves with shape_gen 1;
##   - going home, the old home builds on generator 1 and its baskets stand on dry land too;
##   - a new voyage from there lands on generator 2; a generator-2 save reloads as generator 2;
##   - forged stamps are clamped to a generator this build has.
## Fixture: res://tests/fixtures/save_islands_gen1.json, written from save_v3_away_golden.json by
##   Godot --headless --path game --script res://tests/t_shapesave.gd -- --write-fixture
## Run: Godot --headless --path game --script res://tests/t_shapesave.gd -> "[t_shapesave] PASS", 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const FIX := "res://tests/fixtures/save_islands_gen1.json"
const BASE := "res://tests/fixtures/save_v3_away_golden.json"
const AWAY := &"temperate_25"
const HOME := &"home_grassland"
## The fixture's added baskets carry this text; the golden's own camp rows stand on land either way.
const MARK := "islands2-moved-land"

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var W: Node
var SG: GDScript
var SR: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_shapesave] FAIL %s" % what)

func _run() -> void:
	var watchdog := create_timer(240.0)
	watchdog.timeout.connect(func () -> void:
		print("[t_shapesave] FAIL watchdog")
		quit(2))
	W = root.get_node("World")
	SG = load("res://scripts/core/save_game.gd")
	SR = load("res://scripts/core/save_restore.gd")
	_host = Node3D.new()
	_host.name = "TShapeSaveHost"
	root.add_child(_host)
	(load("res://scripts/dev/lab_kit.gd") as GDScript).build(_host)
	W.home_terrain = &"meadow"
	W.home_shape = &""
	if "--write-fixture" in OS.get_cmdline_user_args():
		await _write_fixture()
		quit(0)
		return
	var fix: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX))
	var away_rows: Array = ((fix.get("away", {}) as Dictionary).get("buildings", []) as Array).filter(func (r: Variant) -> bool: return r is Dictionary and str(r.get("text", "")) == MARK)
	var home_rows: Array = ((fix.get("home", {}) as Dictionary).get("buildings", []) as Array).filter(func (r: Variant) -> bool: return r is Dictionary and str(r.get("text", "")) == MARK)
	var away_all: int = ((fix.get("away", {}) as Dictionary).get("buildings", []) as Array).size()
	_expect(not (fix.get("away", {}) as Dictionary).has("shape_gen") and not (fix.get("home", {}) as Dictionary).has("shape_gen"),
		"the fixture is an old save (no shape_gen stamp)")
	await _control(AWAY, away_rows)
	await _control(HOME, home_rows)
	# --- the old save loads on generator 1 ----------------------------------------------------
	W.home_gen = 2
	W.away_gen = 2
	_clean()
	_put(FileAccess.get_file_as_string(FIX))
	SG.load_now(_host)
	await process_frame
	_expect(SG.blocked_reason == "", "the fixture loads (%s)" % SG.blocked_reason)
	_expect(W.island_id == AWAY, "the save stands on %s (got %s)" % [AWAY, W.island_id])
	_expect(int(W.runtime._shape.gen) == 1, "an unstamped save builds its island on generator 1 (got %d)" % int(W.runtime._shape.gen))
	_expect(W.home_gen == 1 and W.away_gen == 1, "an unstamped save keeps generator 1 for home and away (%d/%d)" % [W.home_gen, W.away_gen])
	_expect(SR.pending_refunds.is_empty(), "nothing was refunded or held back (%d rows)" % SR.pending_refunds.size())
	_check_rows("away", away_rows)
	SG.save_now()
	var s1: Dictionary = _saved()
	_expect(int((s1.get("away", {}) as Dictionary).get("shape_gen", 0)) == 1, "the re-save stamps away.shape_gen 1")
	_expect(int((s1.get("home", {}) as Dictionary).get("shape_gen", 0)) == 1, "the re-save stamps home.shape_gen 1")
	_expect(((s1.get("away", {}) as Dictionary).get("buildings", []) as Array).size() == away_all, "the re-save keeps every away building")
	SG.load_now(_host)
	await process_frame
	_expect(int(W.runtime._shape.gen) == 1, "the stamped re-save reloads on generator 1")
	_check_rows("away (reload)", away_rows)
	# --- home: the old home keeps generator 1 ---------------------------------------------------
	W.load_island(_host, HOME, Vector3(0, 1, 12), false)
	SG._restore_buildings(W._home_buildings_cache, SaveMigrations.CURRENT_SCHEMA)
	await process_frame
	_expect(int(W.runtime._shape.gen) == 1, "the old home builds on generator 1")
	_check_rows("home", home_rows)
	# --- a new voyage lands on the current generator ------------------------------------------
	W.away_gen = W.SHAPE_GEN_CURRENT  # what World.travel sets before it builds the destination
	W.load_island(_host, AWAY, Vector3(0, 1, 0), false)
	await process_frame
	_expect(int(W.runtime._shape.gen) == 2, "a new voyage builds generator 2 (got %d)" % int(W.runtime._shape.gen))
	_expect(_travel_resets_gen(), "World.travel sets away_gen to the current generator before it builds")
	# --- a generator-2 world round-trips as generator 2 ----------------------------------------
	W.home_gen = 2
	W.load_island(_host, HOME, Vector3(0, 1, 12), false)
	await process_frame
	_expect(int(W.runtime._shape.gen) == 2, "a generator-2 home builds generator 2")
	SG.save_now()
	_expect(int((_saved().get("home", {}) as Dictionary).get("shape_gen", 0)) == 2, "a generator-2 save stamps home.shape_gen 2")
	W.home_gen = 1
	SG.load_now(_host)
	await process_frame
	_expect(W.home_gen == 2 and int(W.runtime._shape.gen) == 2, "a generator-2 save reloads on generator 2")
	# --- forged stamps ------------------------------------------------------------------------
	for forged in [99, -4, "two", {}]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX))
		d["home"]["shape_gen"] = forged
		d["away"]["shape_gen"] = forged
		_clean()
		_put(JSON.stringify(d))
		SG.load_now(_host)
		await process_frame
		_expect(SG.blocked_reason == "", "a forged shape_gen %s still loads" % str(forged))
		_expect(W.home_gen >= 1 and W.home_gen <= W.SHAPE_GEN_CURRENT and W.away_gen >= 1 and W.away_gen <= W.SHAPE_GEN_CURRENT,
			"a forged shape_gen %s is clamped to a real generator (%d/%d)" % [str(forged), W.home_gen, W.away_gen])
	W.home_gen = 1
	W.away_gen = 2
	_clean()
	if _fails.is_empty():
		print("[t_shapesave] PASS away=%d home=%d buildings on generator-1 land" % [away_rows.size(), home_rows.size()])
		quit(0)
	else:
		print("[t_shapesave] FAIL count=%d" % _fails.size())
		quit(1)

## Every fixture building cell is dry on generator 1 and not dry on generator 2.
func _control(id: StringName, rows: Array) -> void:
	_expect(rows.size() >= 2, "%s fixture holds >= 2 buildings (%d)" % [id, rows.size()])
	for gen in [1, 2]:
		if id == HOME:
			W.home_gen = gen
		else:
			W.away_gen = gen
		W.load_island(_host, id, Vector3(0, 1, 0), false)
		await process_frame
		for row in rows:
			var p := Vector3(float(row["x"]), 0.0, float(row["z"]))
			var dry: bool = W.runtime.is_dry(p)
			if gen == 1:
				_expect(dry, "%s %s is dry on generator 1" % [id, p])
			else:
				_expect(not dry, "control: %s %s is NOT dry on generator 2 (the fixture tests a real move)" % [id, p])
		print("[t_shapesave] control %s gen %d checked %d cells" % [id, gen, rows.size()])

## Every saved basket stands rebuilt at its cell, on dry land.
func _check_rows(label: String, rows: Array) -> void:
	var found := 0
	for row in rows:
		var want := Vector2(float(row["x"]), float(row["z"]))
		var hit := false
		for b in get_nodes_in_group("basket"):
			if b.is_queued_for_deletion() or bool(b.get("is_cargo")) or not W.runtime.is_ancestor_of(b):
				continue
			var p: Vector3 = (b as Node3D).global_position
			if Vector2(p.x, p.z).distance_to(want) < 1.0:
				hit = true
				_expect(W.runtime.is_dry(p), "%s basket at %s stands on dry land" % [label, want])
				break
		if hit:
			found += 1
	_expect(found == rows.size(), "%s: every saved basket is rebuilt (%d of %d)" % [label, found, rows.size()])

func _travel_resets_gen() -> bool:
	var src := FileAccess.get_file_as_string("res://scripts/core/world.gd")
	var at := src.find("func travel(")
	var load_at := src.find("load_island(host, to_id", at)
	var reset_at := src.find("away_gen = SHAPE_GEN_CURRENT", at)
	return at >= 0 and reset_at > at and reset_at < load_at

## Writes the fixture: the v3 away golden (an old save on temperate_25) plus baskets, each on its
## own claim, on generator-1 land that generator 2 turns to sea, on temperate_25 and on the home.
func _write_fixture() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE))
	var away_pts := await _moved_cells(AWAY, 3)
	var home_pts := await _moved_cells(HOME, 2)
	var away: Dictionary = d["away"]
	var home: Dictionary = d["home"]
	for p in away_pts:
		(away["buildings"] as Array).append(_basket(p))
		(away["claims"] as Array).append([p.x - 3, p.y - 3, 7, 7])
	for p in home_pts:
		(home["buildings"] as Array).append(_basket(p))
		(home["claims"] as Array).append([p.x - 3, p.y - 3, 7, 7])
	var f := FileAccess.open(FIX, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "  ", false))
	f.close()
	print("[t_shapesave] wrote %s away=%s home=%s" % [FIX, away_pts, home_pts])

func _basket(t: Vector2i) -> Dictionary:
	return {"cargo": false, "cell": [t.x, t.y], "contents": [], "kind": "basket", "rot": 0, "sleeps_left": -1,
		"text": MARK, "x": float(t.x) + 0.5, "z": float(t.y) + 0.5}

## `n` tiles, 40 m apart, that are dry, flat buildable ground on generator 1 (and away from its camp
## and dock) but not dry on generator 2.
func _moved_cells(id: StringName, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if id == HOME:
		W.home_gen = 2
	else:
		W.away_gen = 2
	W.load_island(_host, id, Vector3(0, 1, 0), false)
	await process_frame
	var rt2 = W.runtime
	var wet2 := {}
	var half: float = rt2._size * 0.5
	for z in range(-int(half), int(half), 3):
		for x in range(-int(half), int(half), 3):
			if not rt2.is_dry(Vector3(float(x) + 0.5, 0.0, float(z) + 0.5)):
				wet2[Vector2i(x, z)] = true
	if id == HOME:
		W.home_gen = 1
	else:
		W.away_gen = 1
	W.load_island(_host, id, Vector3(0, 1, 0), false)
	await process_frame
	var rt = W.runtime
	var camp: Vector3 = rt._camp_pos
	var dock: Vector3 = rt.arrival_point()
	for t: Vector2i in wet2.keys():
		var p := Vector3(float(t.x) + 0.5, 0.0, float(t.y) + 0.5)
		if not rt.is_dry(p) or rt.slope_at(p.x, p.z) > 0.3:
			continue
		if Vector2(p.x - camp.x, p.z - camp.z).length() < 40.0 or Vector2(p.x - dock.x, p.z - dock.z).length() < 40.0:
			continue
		var ok := true
		for q in out:
			if Vector2(q).distance_to(Vector2(t)) < 40.0:
				ok = false
		# The 7 x 7 claim around it must be dry too (a claim cell needs land).
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				if not rt.is_dry(Vector3(p.x + dx, 0.0, p.z + dz)):
					ok = false
		if ok:
			out.append(t)
		if out.size() >= n:
			break
	return out

func _clean() -> void:
	SG.blocked_reason = ""
	var dir := ProjectSettings.globalize_path(str(SG.path).get_base_dir())
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))

func _put(text: String) -> void:
	var f := FileAccess.open(SG.path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _saved() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	return parsed as Dictionary if parsed is Dictionary else {}
