extends SceneTree
## ISLANDPICK acceptance (spec 29 section 4, PRD 4.2, docs/reference/durango-domain-tamed-island-select.webp):
## five Tamed Island shapes, one top-down preview each, one permanent pick, persisted through
## save/load; an old save keeps the island it had and is never asked again; a second pick is refused.
## Run: Godot --headless --path game --script res://tests/t_islandpick.gd -> "[t_islandpick] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const RUN_DIR := "user://runs/t_islandpick"
const FIX := "res://tests/fixtures/"
const TARGET_MIN := 44.0 ## UiTokens.TARGET_MIN; the 64 px gate is measured on the phone lab

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _world: Node
var _player: Node
var _sg: GDScript
var _pick: GDScript
var _shape: GDScript
var _forest_seed := 0

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_islandpick] FAIL %s" % what)

func _run() -> void:
	# A --script test must load every game script on its first frame (see t_domain.gd).
	_sg = load("res://scripts/core/save_game.gd")
	_pick = load("res://scripts/ui/island_pick.gd")
	_shape = load("res://scripts/world/island_shape.gd")
	var watchdog := create_timer(180.0)
	watchdog.timeout.connect(func () -> void: quit(2))
	_world = root.get_node("World")
	_world.set("creation_pending", false)
	for n in get_nodes_in_group(&"character_creation"):
		n.free()
	for n in get_nodes_in_group(&"island_pick"):
		n.free()
	_clean()
	_host = Node3D.new()
	_host.name = "TIslandPickHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	_world.set("home_shape", &"")
	_world.set("home_terrain", &"")
	_test_catalogue()
	await _test_previews_and_screen()
	await _test_debounce()
	await _test_pick_persists()
	await _test_five_shapes()
	await _test_sanitizer()
	await _test_old_save()
	_clean()
	_finish()

## Five shapes, each its own landmass seed and its own home scatter row.
func _test_catalogue() -> void:
	var shapes: Array = _world.get("home_shapes")
	_expect(shapes.size() == 5, "island_shapes.json holds five shapes (got %d)" % shapes.size())
	var seeds := {}
	var terrains := {}
	var ids: Array = _world.call("shape_ids")
	for id in ids:
		var s: Dictionary = _world.call("shape_def", StringName(id))
		seeds[int(s.get("seed", 0))] = true
		terrains[str(s.get("terrain", ""))] = true
		_expect(str(s.get("display_name", "")) != "", "shape %s has a display name" % id)
		_expect(_world.call("shape_def", StringName(id)).get("accent", "") != "", "shape %s has a preview tint" % id)
	_expect(seeds.size() == 5, "the five shapes use five distinct seeds (got %d)" % seeds.size())
	_expect(terrains.size() == 5, "the five shapes use five distinct terrains (got %d)" % terrains.size())
	var terrain_rows: Array = (_world.get("islands") as Dictionary)["home_grassland"].get("terrains", {}).keys()
	for t in terrains:
		_expect(terrain_rows.has(t), "shape terrain '%s' is a home scatter row" % t)
	# The first row is the pre-ISLANDPICK island, so meadow and an old save build the same ground.
	var first: Dictionary = _world.call("shape_def", &"meadow")
	_expect(int(first.get("seed", 0)) == 17, "the meadow shape is the stock seed 17 island (got %s)" % first.get("seed"))

## The pick screen: five previews of the real coastline, the final warning, 44 px+ targets at this
## canvas (64 is gated on the 844x390 lab).
func _test_previews_and_screen() -> void:
	var pick: Node = _pick.call("instance_on", _host)
	_expect(pick != null, "the island pick layer instantiates")
	if pick == null:
		return
	pick.call("open")
	await process_frame
	await process_frame
	var shown := int(pick.call("preview_count"))
	_expect(shown == 5, "five previews drawn from the shape data (got %d)" % shown)
	_expect(bool(pick.call("warning_visible")), "the screen shows the final-selection warning")
	var targets := {}
	for c in _controls(pick):
		if c is Button:
			targets[str(c.name)] = c.get_global_rect()
	_expect(targets.size() == 6, "five shape cards plus SELECT AND MOVE (got %d buttons)" % targets.size())
	var lo := INF
	for key in targets:
		var r: Rect2 = targets[key]
		lo = minf(lo, minf(r.size.x, r.size.y))
		_expect(r.size.x >= TARGET_MIN and r.size.y >= TARGET_MIN, "%s is at least %.0f px (%s)" % [key, TARGET_MIN, r.size])
	_expect(lo >= TARGET_MIN, "every pick target is >= %.0f px (smallest %.0f)" % [TARGET_MIN, lo])
	print("[t_islandpick] screen previews=%d targets=%d min_px=%.0f" % [shown, targets.size(), lo])
	# Every preview is the shape's own coastline: the five images differ.
	var hashes := {}
	for id in _world.call("shape_ids"):
		var tex: Texture2D = pick.get("_previews").get(str(id))
		_expect(tex != null, "shape %s has a preview texture" % id)
		if tex:
			hashes[hash(tex.get_image().get_data())] = true
	_expect(hashes.size() == 5, "the five previews are five different maps (got %d)" % hashes.size())
	# Drive the real flow: tap a card, tap SELECT AND MOVE.
	var card := pick.find_child("Shape_forest", true, false) as Button
	_expect(card != null, "the forest card exists")
	if card:
		card.pressed.emit()
	var go := pick.find_child("SelectAndMove", true, false) as Button
	_expect(go != null and not go.disabled, "SELECT AND MOVE is enabled once a shape is selected")
	var got: Array = []
	pick.connect("picked", func (id: StringName) -> void: got.append(id))
	if go:
		go.pressed.emit()
	await process_frame
	_expect(got.size() == 1 and StringName(got[0]) == &"forest", "the screen hands back the tapped shape (%s)" % [got])

## The pick is permanent: the second call is refused, and it survives a save + load with the right
## landmass (the shape's seed drives the generated island). It also lands the survivor at the chosen
## island's harbour and opens the arrival flow, exactly as the old terrain sheet did.
func _test_pick_persists() -> void:
	_forest_seed = int((_world.call("shape_def", &"forest") as Dictionary).get("seed", 0))
	var ok: bool = _world.call("pick_shape", &"forest")
	_expect(ok, "pick_shape(forest) is accepted on a fresh world")
	_expect(_world.get("home_shape") == &"forest", "home_shape is forest (got '%s')" % _world.get("home_shape"))
	_expect(_world.get("home_terrain") == &"forest", "the pick sets the home scatter terrain (got '%s')" % _world.get("home_terrain"))
	var again: bool = _world.call("pick_shape", &"rocky")
	_expect(not again, "a second pick is refused: the choice is final")
	_expect(_world.get("home_shape") == &"forest", "a refused pick leaves the held shape (got '%s')" % _world.get("home_shape"))
	_expect(not bool(_world.call("pick_shape", &"nonsense")), "an unknown shape id is refused")
	# The real flow from the pick screen: build, land at the harbour, finish creation, save, welcome.
	_world.set("creation_pending", false)
	_world.call("load_island", _host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	await process_frame
	var rt: Node3D = _world.get("runtime")
	_expect(rt != null, "the home island built")
	if rt:
		var sh = rt.get("_shape")
		_expect(sh != null and sh.seed == _forest_seed, "the home landmass uses the forest seed %d (got %s)" % [_forest_seed, sh.seed if sh else -1])
	_expect(str((_world.get("island_def") as Dictionary).get("seed", 0)) == str(_forest_seed), "the home island def carries the shape seed")
	# Save, wipe the in-memory choice, load: the same island comes back.
	_expect(bool(_sg.call("save_now")), "the world saves after the pick")
	var bytes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_sg.get("path")))
	_expect(str(((bytes.get("home", {}) as Dictionary).get("shape", ""))) == "forest", "the save stores home.shape=forest")
	_world.set("home_shape", &"")
	_world.set("home_terrain", &"")
	_world.set("runtime", null)
	_sg.call("load_now", _host)
	await process_frame
	await process_frame
	_expect(_world.get("home_shape") == &"forest", "the loaded save restores the forest pick (got '%s')" % _world.get("home_shape"))
	_expect(not bool(_world.call("pick_shape", &"coastal")), "a loaded survivor cannot change the pick either")
	var rt2: Node3D = _world.get("runtime")
	if rt2:
		var sh2 = rt2.get("_shape")
		_expect(sh2 != null and sh2.seed == _forest_seed, "the reloaded island is the same landmass (seed %s)" % (sh2.seed if sh2 else -1))
	# The arrival: complete_pick is the path the screen's SELECT AND MOVE takes. From a fresh world it
	# must put the survivor on the harbour arrival point and raise the existing arrival welcome.
	_world.set("home_shape", &"")
	_world.set("home_terrain", &"")
	_world.set("creation_pending", true)
	for n in root.find_children("ArrivalWelcome", "CanvasLayer", true, false):
		n.free()
	_world.set("runtime", null)
	var landed: bool = _world.call("complete_pick", _host, &"coastal")
	_expect(landed, "complete_pick(coastal) accepts the first pick")
	var rt3: Node3D = _world.get("runtime")
	_expect(rt3 != null, "complete_pick built the home island")
	var arrived := Vector3.ZERO
	if rt3:
		arrived = rt3.call("arrival_point")
		_expect(Vector2(arrived.x, arrived.z).length() > 20.0, "the coastal island has a harbour arrival away from the origin (%s)" % arrived)
		var at: Vector3 = _player.global_position
		_expect(Vector2(at.x - arrived.x, at.z - arrived.z).length() < 2.0 and absf(at.y - (rt3.call("surface_y", arrived.x, arrived.z) + 1.0)) < 1.0,
			"the survivor lands on the chosen island's harbour arrival point (%s vs %s)" % [at, arrived])
		_expect(rt3.call("is_dry", arrived), "the harbour arrival is dry ground")
	await process_frame
	await process_frame
	var welcome: Array[Node] = root.find_children("ArrivalWelcome", "CanvasLayer", true, false)
	_expect(welcome.size() == 1, "the arrival welcome is up after the pick (got %d)" % welcome.size())
	var go_text := ""
	if not welcome.is_empty():
		for l in welcome[0].find_children("*", "Label", true, false):
			if (l as Label).text == "YOU MADE IT":
				go_text = "YOU MADE IT"
		_expect(go_text != "", "the arrival welcome carries the YOU MADE IT flow")
		welcome[0].free()
	# Double taps: the same complete_pick twice builds and saves once - the second call is refused.
	_world.set("home_shape", &"")
	_world.set("home_terrain", &"")
	_world.set("creation_pending", true)
	_world.set("runtime", null)
	for n in root.find_children("ArrivalWelcome", "CanvasLayer", true, false):
		n.free()
	var first: bool = _world.call("complete_pick", _host, &"rocky")
	var second: bool = _world.call("complete_pick", _host, &"rocky")
	_expect(first and not second, "a repeated complete_pick is refused (first=%s second=%s)" % [first, second])
	_expect(root.find_children("ArrivalWelcome", "CanvasLayer", true, false).size() == 1, "one arrival welcome, not two")
	for n in root.find_children("ArrivalWelcome", "CanvasLayer", true, false):
		n.free()

## Every shape builds for real (not just its preview): harbour site on a legal coast, dry camp, dry
## arrival, walkable spawn rules and a camp -> arrival path.
func _test_five_shapes() -> void:
	for id in _world.call("shape_ids"):
		_clean()
		_world.set("home_shape", &"")
		_world.set("home_terrain", &"")
		_world.set("creation_pending", true)
		_world.set("runtime", null)
		var ok: bool = _world.call("complete_pick", _host, StringName(id))
		_expect(ok, "shape %s is pickable" % id)
		var rt: Node3D = _world.get("runtime")
		_expect(rt != null, "shape %s built a runtime" % id)
		if rt == null:
			continue
		var sh = rt.get("_shape")
		var want_seed := int((_world.call("shape_def", StringName(id)) as Dictionary).get("seed", 0))
		_expect(sh != null and int(sh.seed) == want_seed, "shape %s built its own landmass seed %d (got %s)" % [id, want_seed, sh.seed if sh else -1])
		_expect(rt.get("harbour") != null, "shape %s found a harbour site on its coast" % id)
		var arrival: Vector3 = rt.call("arrival_point")
		var camp: Vector3 = rt.get("_camp_pos")
		_expect(rt.call("is_dry", camp), "shape %s camp is dry (%s)" % [id, camp])
		_expect(arrival.y > -0.05 and bool(rt.call("on_harbour_approach", arrival)), "shape %s harbour arrival is the approach sand behind the dock (%s)" % [id, arrival])
		_expect(rt.call("spawn_ok", camp, false), "shape %s camp passes the spawn rules" % id)
		_expect(rt.call("spawn_ok", arrival, false), "shape %s arrival passes the spawn rules" % id)
		_expect(float(rt.call("surface_y", camp.x, camp.z)) > 0.0, "shape %s camp sits above the waterline (%.2f)" % [id, rt.call("surface_y", camp.x, camp.z)])
		var pts: PackedVector3Array = rt.get("pathing").path(camp, arrival, 0)
		_expect(pts.size() > 0 and bool(rt.get("pathing").last_reachable), "shape %s camp reaches the harbour on foot (%d points)" % [id, pts.size()])
		var def: Dictionary = _world.get("island_def")
		_expect(float(def.get("size_m", 0.0)) > 0.0, "shape %s island def has a size" % id)
		print("[t_islandpick] shape=%s seed=%d camp=%s arrival=%s path=%d" % [id, want_seed, camp.snapped(Vector3.ONE), arrival.snapped(Vector3.ONE), pts.size()])
		for n in root.find_children("ArrivalWelcome", "CanvasLayer", true, false):
			n.free()

## home.shape is part of the save's trust boundary: SaveSanitizer.clean keeps every catalogue id and
## erases anything else (wrong type, unknown id, empty) before the loader sees it. The world then
## holds the stock island, keeps an old save without the row compatible, and a survivor that does not
## exist yet may still pick once.
func _test_sanitizer() -> void:
	var ss := load("res://scripts/core/save_sanitizer.gd") as GDScript
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "save_v0.json"))
	# The allowlist comes from the catalogue the sanitizer reads itself (no autoload needed).
	var ids: PackedStringArray = ss.call("shape_ids")
	_expect(ids.size() == 5, "the sanitizer knows the five catalogue ids (got %d)" % ids.size())
	for id in _world.call("shape_ids"):
		_expect(ids.has(id), "the sanitizer allowlist has %s" % id)
		var good := base.duplicate(true)
		(good["home"] as Dictionary)["shape"] = id
		var clean: Dictionary = ss.call("clean", good)
		_expect(str((clean["home"] as Dictionary).get("shape", "")) == id, "clean() preserves the catalogue shape %s" % id)
	# A forged row never reaches the loader: the wrong type is erased by the shape pass, an unknown or
	# empty id by the allowlist, and the row is simply absent afterwards (old saves look the same).
	for bad in ["volcano", "", "Forest", " forest", ["forest"], 42, null, {"id": "forest"}]:
		var d := base.duplicate(true)
		(d["home"] as Dictionary)["shape"] = bad
		var clean: Dictionary = ss.call("clean", d)
		var kept: Variant = (clean["home"] as Dictionary).get("shape", null)
		_expect(kept == null, "clean() removes the forged home.shape %s (kept %s)" % [bad, kept])
	# An old save without the row stays compatible and gains nothing.
	var old := base.duplicate(true)
	(old["home"] as Dictionary).erase("shape")
	var old_clean: Dictionary = ss.call("clean", old)
	_expect(not (old_clean["home"] as Dictionary).has("shape"), "clean() leaves an old save without home.shape alone")
	# The real load path runs the sanitizer first: forge the file, load, fall back safely.
	for bad in ["volcano", "", 42, null, ["forest"], {"id": "forest"}]:
		_clean()
		var forged := base.duplicate(true)
		(forged["home"] as Dictionary)["shape"] = bad
		_put(JSON.stringify(forged)) # raw, exactly as a tampered file would be: SaveMigrations.read cleans it
		_world.set("home_shape", &"")
		_world.set("home_terrain", &"")
		_world.set("runtime", null)
		_sg.call("load_now", _host)
		await process_frame
		await process_frame
		_expect(str(_sg.get("blocked_reason")) == "", "forged shape %s does not block the save" % [bad])
		_expect(_world.get("home_shape") == &"", "forged shape %s falls back to no choice (got '%s')" % [bad, _world.get("home_shape")])
		var rt: Node3D = _world.get("runtime")
		if rt:
			var sh = rt.get("_shape")
			_expect(sh != null and int(sh.seed) == 17, "forged shape %s builds the stock island (seed %s)" % [bad, sh.seed if sh else -1])
	# The fallback must not permanently prevent a choice: with no shape held, a pick still works.
	var picked: bool = _world.call("pick_shape", &"riverside")
	_expect(picked and _world.get("home_shape") == &"riverside", "a save with a dropped shape can still make the pick")
	_world.set("home_shape", &"")
	_world.call("finish_creation")
	_expect(bool(_sg.call("save_now")), "the fallback world saves")
	var bytes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_sg.get("path")))
	_expect(str(((bytes.get("home", {}) as Dictionary).get("shape", "x"))) == "", "the re-save holds no forged shape")

## The pick screen confirms once: the confirm button dies on the first tap and a second tap emits
## nothing, so a double tap cannot build and save the island twice. A refused pick re-arms it.
func _test_debounce() -> void:
	for n in get_nodes_in_group(&"island_pick"):
		n.free()
	var pick: Node = _pick.call("instance_on", _host)
	pick.call("open")
	await process_frame
	await process_frame
	var got: Array = []
	pick.connect("picked", func (id: StringName) -> void: got.append(id))
	var card := pick.find_child("Shape_forest", true, false) as Button
	card.pressed.emit()
	var go := pick.find_child("SelectAndMove", true, false) as Button
	go.pressed.emit()
	go.pressed.emit()
	await process_frame
	_expect(got.size() == 1, "two taps on SELECT AND MOVE emit one pick (got %d)" % got.size())
	_expect(bool(pick.call("is_confirmed")), "the screen is marked confirmed")
	_expect(go.disabled, "the confirm button is dead while the island builds")
	_expect(card.disabled, "the shape cards are dead while the island builds")
	# The world refused this pick (it was never applied): failed() must let the player try again.
	pick.call("failed")
	_expect(not bool(pick.call("is_confirmed")) and not go.disabled, "a refused pick re-arms the screen")
	pick.queue_free()
	await process_frame

## An old save has no shape row: it loads the island it always had (seed 17, legacy core), is not
## sent back to the pick, and re-saves with an empty shape so nothing about it moves.
func _test_old_save() -> void:
	_clean()
	_put(FileAccess.get_file_as_string(FIX + "save_v0.json"))
	_world.set("home_shape", &"")
	_world.set("home_terrain", &"")
	_world.set("runtime", null)
	_sg.call("load_now", _host)
	await process_frame
	await process_frame
	_expect(_sg.get("blocked_reason") == "", "an old save loads cleanly")
	_expect(_world.get("home_shape") == &"", "an old save holds no shape (got '%s')" % _world.get("home_shape"))
	var rt: Node3D = _world.get("runtime")
	_expect(rt != null, "the old save's home island built")
	if rt:
		var sh = rt.get("_shape")
		_expect(sh != null and sh.seed == 17 and sh.legacy, "an old save keeps the stock seed-17 island (seed %s legacy %s)" % [sh.seed if sh else -1, sh.legacy if sh else false])
	_expect(get_nodes_in_group(&"island_pick").is_empty(), "an old save is never shown the pick")
	# Its ground is unchanged: the old fixtures' save path already round-trips; here we only assert
	# the shape row is empty, which is what a re-save by this build adds.
	_world.call("finish_creation")
	_expect(bool(_sg.call("save_now")), "the old save re-saves")
	var bytes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_sg.get("path")))
	_expect(str(((bytes.get("home", {}) as Dictionary).get("shape", "x"))) == "", "the old save re-saves with an empty shape")

func _controls(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	if node is Control and (node as Control).is_visible_in_tree():
		out.append(node as Control)
	for c in node.get_children():
		out.append_array(_controls(c))
	return out

func _clean() -> void:
	_sg.set("blocked_reason", "")
	var dir := ProjectSettings.globalize_path(RUN_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))

func _put(text: String) -> void:
	var f := FileAccess.open(_sg.get("path"), FileAccess.WRITE)
	_expect(f != null, "the test save slot opens for writing")
	if f:
		f.store_string(text)
		f.close()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_islandpick] PASS")
		quit(0)
	else:
		print("[t_islandpick] FAIL count=%d" % _fails.size())
		quit(1)
