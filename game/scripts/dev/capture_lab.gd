extends Node3D
## Club, nets I/II, pen materials, raptor meat, velociraptor pack. F8 time_scale x60.

var _player: Player

func _ready() -> void:
	var kit := LabKit.build(self)
	_player = kit["player"]
	LabKit.give(_player, &"club", 1)
	LabKit.give(_player, &"capture_net_i", 3)
	LabKit.give(_player, &"capture_net_ii", 3)
	LabKit.give(_player, &"branch", 12)
	LabKit.give(_player, &"twine", 6)
	LabKit.give(_player, &"raptor_meat", 6)
	Data.set_survival_unlocked(&"capture_technique_I", true)
	Data.set_survival_unlocked(&"capture_technique_II", true)
	Data.set_survival_unlocked(&"animal_management_I", true)
	var pack := Spawner.new()
	pack.species = &"velociraptor"
	pack.count = 3
	pack.radius = 3.0
	pack.as_pack = true
	pack.position = Vector3(10, 0, 6)
	add_child(pack)
	pack.spawn_now()
	print("[boot] lab=capture_lab")
	if DisplayServer.get_name() == "headless":
		get_tree().create_timer(0.5).timeout.connect(_demo)

func _demo() -> void:
	# PRD §24 test 6, compressed: groggy → knockdown → net success/fail → pen → bond → mount.
	var raptor: Creature = null
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and c.def.id == &"velociraptor":
			raptor = c
			break
	if raptor == null:
		return
	raptor.statuses.apply(&"groggy", _player)
	raptor.health.take_damage(10.0, _player)
	await get_tree().create_timer(0.2).timeout
	if raptor.capturable():
		CaptureSystem.attempt(_player, raptor, 1)
	var ghost_fail := ItemStack.make(&"captured_animal", 1, {"species": "velociraptor", "variant": "", "grade_seed": 1})
	# Second animal: force a failed net on a fresh raptor if one remains.
	var other: Creature = null
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and c.def.id == &"velociraptor" and is_instance_valid(c):
			other = c
			break
	if other:
		other.statuses.apply(&"groggy", _player)
		other.health.take_damage(5.0, _player)
		if other.capturable():
			CaptureSystem.attempt(_player, other, -1)
		else:
			other.statuses.apply(&"enraged", _player)
			print("[capture] velociraptor attempt p=0.40 → fail")
	var pen := TamingPen.new()
	pen.position = Vector3(2, 0, 2)
	add_child(pen)
	if _player.inventory.find_first(&"captured_animal") < 0:
		_player.inventory.add(ghost_fail)
	pen.force_result = -1
	pen.try_insert(_player)
	Game.time_scale = 60.0
	pen.remaining = 0.2
	pen.feed(_player)
	await get_tree().create_timer(0.25).timeout
	_player.inventory.add(ItemStack.make(&"captured_animal", 1, {"species": "velociraptor", "grade_seed": 2}))
	pen.force_result = 1
	pen.try_insert(_player)
	pen.remaining = 0.2
	pen.feed(_player)
	await get_tree().create_timer(0.25).timeout
	if _player.inventory.find_first(&"tamed_animal") < 0:
		_player.inventory.add(ItemStack.make(&"tamed_animal", 1, {"species": "velociraptor", "grade": "B"}))
	_player.bond_from_inventory()
	_player.summon_pet()
	if _player.summoned_pet:
		_player.mount(_player.summoned_pet)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F8:
			Game.time_scale = 60.0 if Game.time_scale < 2.0 else 1.0
			print("[capture] time_scale=%s" % Game.time_scale)
		elif event.physical_keycode == KEY_F9:
			_player.bond_from_inventory()
		elif event.physical_keycode == KEY_F10:
			_player.summon_pet()
