extends Node3D
## Field tame (M9b) + legacy pen flow. F8 time_scale x60.

var _player: Player
var _cam: Camera3D

func _ready() -> void:
	var kit := LabKit.build(self)
	_player = kit["player"]
	_cam = kit.get("cam", null) as Camera3D
	LabKit.give(_player, &"club", 1)
	LabKit.give(_player, &"capture_net_i", 3)
	LabKit.give(_player, &"capture_net_ii", 3)
	LabKit.give(_player, &"branch", 12)
	LabKit.give(_player, &"twine", 6)
	LabKit.give(_player, &"raptor_meat", 6)
	LabKit.give(_player, &"berry", 6)
	Data.set_survival_unlocked(&"capture_technique_I", true)
	Data.set_survival_unlocked(&"capture_technique_II", true)
	Data.set_survival_unlocked(&"animal_management_I", true)
	var pack := Spawner.new()
	pack.species = &"velociraptor"
	pack.count = 2
	pack.radius = 3.0
	pack.as_pack = true
	pack.position = Vector3(10, 0, 6)
	add_child(pack)
	pack.spawn_now()
	_spawn_comps(&"comp_a", Vector3(3.2, 0, 1.5))
	_spawn_comps(&"comp_b", Vector3(5.0, 0, 2.2))
	print("[boot] lab=capture_lab")
	if DisplayServer.get_name() == "headless" or Game.shot_path != "":
		get_tree().create_timer(0.35).timeout.connect(_demo)

func _spawn_comps(node_name: StringName, at: Vector3) -> Creature:
	var def := Data.creature(&"compsognathus")
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	c.name = String(node_name)
	add_child(c)
	c.global_position = at
	c.spawn(def)
	return c

func _demo() -> void:
	var shot := Game.shot_path != ""
	var a := _find_comps("comp_a")
	var b := _find_comps("comp_b")
	if a == null or b == null:
		print("[tame] lab missing compsognathus")
		return
	_player.global_position = Vector3(2.0, 0.0, 1.0)
	if _cam:
		_cam.global_position = Vector3(2.5, 10.0, 8.0)
		_cam.look_at(a.global_position + Vector3(0, 0.4, 0), Vector3.UP)
		if _cam is Camera3D:
			(_cam as Camera3D).size = 9.0
	# Down both for plate / refusal; keep knockdown long for the shot.
	_knock_down(a)
	_knock_down(b)
	a.statuses.extend(&"knockdown", 30.0)
	if Game and Game.has_method("reveal_creature_plate"):
		Game.reveal_creature_plate(a, 8.0)
	if shot:
		# Leave berries so the plate shows Tame 0/3 with food icon.
		return
	# Successful field tame: three preferred berries.
	for _i in 3:
		FieldTame.apply_feed(_player, a, &"berry")
		await get_tree().create_timer(0.05).timeout
	# Refusal: strip food, tap second downed animal.
	while _player.inventory.find_first(&"berry") >= 0:
		_player.inventory.remove_at(_player.inventory.find_first(&"berry"), 99)
	while _player.inventory.find_first(&"herb_leaf") >= 0:
		_player.inventory.remove_at(_player.inventory.find_first(&"herb_leaf"), 99)
	while _player.inventory.find_first(&"fibre_stalk") >= 0:
		_player.inventory.remove_at(_player.inventory.find_first(&"fibre_stalk"), 99)
	while _player.inventory.find_first(&"raw_meat") >= 0:
		_player.inventory.remove_at(_player.inventory.find_first(&"raw_meat"), 99)
	_player._begin_field_tame(b)
	await get_tree().create_timer(0.1).timeout
	# Corpse despawn line (force empty lifetime).
	var victim := _spawn_comps(&"comp_dead", Vector3(7.0, 0, 3.0))
	victim.health.take_damage(victim.health.max_hp + 10.0, _player)
	await get_tree().create_timer(0.15).timeout
	var corpse: Corpse = null
	for n in get_tree().get_nodes_in_group("corpse"):
		var body := n as Corpse
		if body and body.species == &"compsognathus":
			corpse = body
			break
	if corpse:
		for i in corpse.loot.slot_count:
			if corpse.loot.slots[i] != null:
				corpse.loot.remove_at(i, 99)
		corpse._emptied = true
		corpse._expires_left = 0.05
		await get_tree().create_timer(0.25).timeout
	# Legacy pen path still exercised briefly.
	await _legacy_pen_demo()
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		await get_tree().create_timer(0.15).timeout
		get_tree().quit(0)

func _knock_down(c: Creature) -> void:
	c.statuses.apply(&"groggy", _player)
	c.statuses.apply(&"knockdown", _player)
	c.anim.play_clip(&"knockdown")
	c.is_capturable = true
	FieldTame.begin_window(c)

func _find_comps(node_name: String) -> Creature:
	var n := get_node_or_null(node_name)
	return n as Creature

func _legacy_pen_demo() -> void:
	var raptor: Creature = null
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and c.def.id == &"velociraptor" and not c.is_pet:
			raptor = c
			break
	if raptor and raptor.capturable():
		CaptureSystem.attempt(_player, raptor, 1)
	var pen := TamingPen.new()
	pen.position = Vector3(-2, 0, 2)
	add_child(pen)
	if _player.inventory.find_first(&"captured_animal") < 0:
		_player.inventory.add(ItemStack.make(&"captured_animal", 1, {"species": "velociraptor", "grade_seed": 2}))
	pen.force_result = 1
	pen.try_insert(_player)
	Game.time_scale = 60.0
	pen.remaining = 0.15
	pen.feed(_player)
	await get_tree().create_timer(0.2).timeout

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F8:
			Game.time_scale = 60.0 if Game.time_scale < 2.0 else 1.0
			print("[capture] time_scale=%s" % Game.time_scale)
		elif event.physical_keycode == KEY_F9:
			_player.bond_from_inventory()
		elif event.physical_keycode == KEY_F10:
			_player.summon_pet()
		elif event.physical_keycode == KEY_K:
			# Lab key: knock nearest compsognathus down.
			var best: Creature = null
			var best_d := 999.0
			for n in get_tree().get_nodes_in_group("creatures"):
				var c := n as Creature
				if c == null or c.def.id != &"compsognathus" or c.health.dead:
					continue
				var d := c.global_position.distance_to(_player.global_position)
				if d < best_d:
					best_d = d
					best = c
			if best:
				_knock_down(best)
				print("[tame] lab knockdown %s" % best.def.id)
