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
	var watchdog := create_timer(60.0)
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
	await _test_pick_persists()
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
## landmass (the shape's seed drives the generated island).
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
	# Build the island the pick describes and check the landmass is that shape's.
	_world.call("finish_creation")
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
