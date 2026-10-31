extends SceneTree
## NOBOXES (owner 2026-10-30: "remove the blocky stegosaurus and never show me that again", every species):
##   - every roster island, the tutorial island and a few unstable isles build with creatures, and no
##     creature or creature view in the tree is a box placeholder;
##   - a model-less spawn row falls back to the next species with a model in its table;
##   - a model-less species becomes eligible once its model is present (faked).
## Run: Godot --headless --path game --script res://tests/t_noboxes.gd -> "[t_noboxes] PASS", 0/1.

var _fails: PackedStringArray = []
var _started := false
var W: Node
var host: Node3D
var CD: GDScript  # CreatureDef, loaded after the autoloads exist (class names do not compile before them)

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_noboxes] FAIL %s" % what)

func _run() -> void:
	W = root.get_node("World")
	CD = load("res://scripts/creatures/creature_def.gd")
	W.creation_pending = true
	host = Node3D.new()
	host.name = "NoBoxesHost"
	root.add_child(host)
	(load("res://scripts/dev/lab_kit.gd") as GDScript).build(host)
	W.home_terrain = &"meadow"
	_list_species()
	_test_eligible()
	var ids: Array = []
	for id in W.islands:
		var row: Variant = W.islands[id]
		if row is Dictionary and not bool((row as Dictionary).get("generated", false)) and str(id) != "tutorial_isle":
			ids.append(StringName(str(id)))
	for id in ids:
		await _check_island(id)
	await _check_tutorial()
	for k in 3:
		W.drift = {}
		var id: String = W.roll_drift(4242 + k * 7919, [20, 35, 55][k])
		_expect(id != "", "unstable seed #%d rolls" % k)
		if id != "":
			await _check_island(StringName(id))
			W._erase_drift(id)
	if _fails.is_empty():
		print("[t_noboxes] PASS")
		quit(0)
	else:
		print("[t_noboxes] FAIL count=%d" % _fails.size())
		quit(1)

func _list_species() -> void:
	var data: Node = root.get_node("Data")
	var ids: Array = data.creatures.keys()
	ids.sort()
	for id in ids:
		print("[t_noboxes] species %s model=%s" % [id, CD.has_model(id)])

func _test_eligible() -> void:
	_expect(not CD.allow_placeholder, "normal play starts with placeholders off")
	var fake := &"noboxes_fake_species"
	_expect(not CD.has_model(fake), "a species with no GLB has no model")
	var table := [&"compsognathus", fake, &"zebraceratops"]
	_expect(CD.eligible(fake, table) == &"zebraceratops", "a model-less row takes the next species in its table")
	_expect(CD.eligible(fake, [fake, &"compsognathus"]) == &"compsognathus", "the table wraps")
	_expect(CD.eligible(fake, [fake], [&"velociraptor"]) == &"velociraptor", "an all-model-less table falls back to the island pool")
	_expect(CD.eligible(fake, [fake]) == &"", "nothing eligible -> no spawn")
	_expect(CD.eligible(&"compsognathus", table) == &"compsognathus", "a species with a model keeps its row")
	CD.fake_models[fake] = true
	_expect(CD.eligible(fake, table) == fake, "a model-less species is eligible once its model lands (faked)")
	CD.fake_models.erase(fake)
	# The spawner itself refuses a model-less species (the last guard before Creature.spawn).
	var missing := &""
	for id in root.get_node("Data").creatures:
		if not CD.has_model(id):
			missing = id
			break
	if missing != &"":
		var sp: Node3D = (load("res://scripts/world/spawner.gd") as GDScript).new()
		sp.species = missing
		host.add_child(sp)
		_expect(sp.spawn_now().is_empty(), "Spawner refuses model-less %s" % missing)
		sp.queue_free()

func _check_island(id: StringName) -> void:
	W.load_island(host, id, Vector3(0, 1, 12), false)
	await process_frame
	var n := get_nodes_in_group("creatures").size()
	_expect(n > 0, "%s has creatures (%d)" % [id, n])
	_check_no_boxes(str(id))

func _check_tutorial() -> void:
	W.load_island(host, &"tutorial_isle", Vector3(0, 1, 12), false)
	await process_frame
	var rt: Node = W.runtime
	var zones: Array = []
	for c in rt.get_children():
		if c.get_script() == load("res://scripts/world/zone_spawner.gd"):
			zones.append(c)
	_expect(zones.size() > 0, "tutorial_isle has wild zones")
	for z in zones:
		_expect(CD.has_model(z.species), "tutorial zone %s has a model" % z.species)
	for z in zones.slice(0, 4):
		z._wake()
	await process_frame
	_expect(get_nodes_in_group("creatures").size() > 0, "tutorial_isle zones wake creatures")
	_check_no_boxes("tutorial_isle")

func _check_no_boxes(tag: String) -> void:
	for c in get_nodes_in_group("creatures"):
		var cr: Node = c
		if cr.is_queued_for_deletion() or not "view" in cr:
			continue
		_expect(cr.view != null and cr.view.using_glb, "%s: %s draws its model, not boxes" % [tag, cr.def.id if cr.def else &"?"])
	var view_gd := load("res://scripts/creatures/creature_view.gd")
	for v in root.find_children("*", "Node3D", true, false):
		if v.get_script() == view_gd and not (v as Node).is_queued_for_deletion():
			_expect(v._body == null, "%s: view %s has no box placeholder" % [tag, (v as Node).name])
