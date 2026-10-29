extends SceneTree
## Creature lab spawner (LabSpawnPanel): lists every species in a dropdown, spawns the chosen species, count,
## nature and alpha in front of the survivor through its own buttons, and CLEAR ALL removes them.
## Usage: godot --headless --path game --script res://tests/t_labspawn.gd  -> "[t_labspawn] PASS"

var failures: Array[String] = []
var _started := false

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("[t_labspawn] FAIL %s" % msg)
	else:
		print("[t_labspawn] ok %s" % msg)

func _wild() -> Array:
	var out: Array = []
	for n in get_root().get_tree().get_nodes_in_group("creatures"):
		if not n.is_pet and not n.is_queued_for_deletion():
			out.append(n)
	return out

func _run() -> void:
	var host := Node3D.new()
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	var PANEL = load("res://scripts/dev/lab_spawn_panel.gd")
	var ids: Array = PANEL.all_species()
	_expect(ids.size() == get_root().get_node("Data").creatures.size() and ids.has(&"compsognathus") and ids.has(&"zebraceratops"), "the selector covers every species (%d of %d)" % [ids.size(), get_root().get_node("Data").creatures.size()])
	var layer := CanvasLayer.new()
	get_root().add_child(layer)
	var panel = PANEL.new()
	layer.add_child(panel)
	panel.setup(player)
	var toggle: Button = panel.get_node("SpawnToggle")
	_expect(toggle.custom_minimum_size.y >= 64.0, "the SPAWN button is a 64 px tap target")
	toggle.pressed.emit()
	_expect(panel.get_node("SpawnPanel").visible, "SPAWN opens the selector")
	var opt: OptionButton = panel.get_node("SpawnPanel").find_child("SpeciesPicker", true, false)
	_expect(opt != null and opt.item_count == ids.size() and opt.custom_minimum_size.y >= 64.0, "the species picker is a 64 px dropdown with every species")
	var stand_ins := 0
	for i in opt.item_count:
		if opt.get_item_text(i).ends_with("(stand-in)"):
			stand_ins += 1
			_expect(not PANEL.has_model(ids[i]), "%s is marked stand-in only when it has no model" % ids[i])
	print("[t_labspawn] %d stand-ins of %d" % [stand_ins, ids.size()])
	opt.select(ids.find(&"zebraceratops"))
	opt.item_selected.emit(ids.find(&"zebraceratops"))
	_expect(panel.species_id == &"zebraceratops", "picking a dropdown row selects that species")
	# Every species spawns (stand-ins included) and clears.
	var all_ok := true
	for id in ids:
		var one: Array = panel.spawn(id, 1)
		if one.size() != 1 or one[0].def.id != id:
			all_ok = false
			print("[t_labspawn] FAIL could not spawn %s" % id)
		panel.clear_all()
		await physics_frame
	_expect(all_ok, "every species spawns from the lab")
	# Through the panel's own controls: species, count 4, a nature, Alpha on, then SPAWN.
	panel._pick_species(&"compsognathus")
	panel.set_count(4)
	while panel.nature != &"timid":
		panel._next_nature()
	if panel._alpha.visible:
		panel._alpha.pressed.emit()
	(panel.get_node("SpawnPanel").find_child("SpawnGo", true, false) as Button).pressed.emit()
	await physics_frame
	var made := _wild()
	var ok := made.size() == 4
	for c in made:
		ok = ok and c.def.id == &"compsognathus" and c.nature == &"timid" and c.pack_id > 0
	_expect(ok, "spawns 4 timid compsognathus as one pack (%d)" % made.size())
	if panel.alpha:
		_expect(made.any(func(c): return c.genetics.alpha), "Alpha on: the pack's first member is an alpha")
	var near := true
	for c in made:
		near = near and c.global_position.distance_to(player.global_position) < 14.0
	_expect(near, "they spawn in front of the survivor")
	panel.set_count(99)
	_expect(panel.count == 6, "the count stops at 6")
	(panel.get_node("SpawnPanel").find_child("ClearAll", true, false) as Button).pressed.emit()
	await physics_frame
	await physics_frame
	_expect(_wild().is_empty(), "CLEAR ALL removes every wild animal")
	var two: Array = panel.spawn(&"deinonychus", 2, &"", false)
	_expect(two.size() == 2 and two[0].def.id == &"deinonychus", "spawn() takes any species")
	panel.clear_all()
	if failures.is_empty():
		print("[t_labspawn] PASS")
		quit(0)
	else:
		print("[t_labspawn] FAIL %d" % failures.size())
		quit(1)
