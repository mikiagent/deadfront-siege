extends Node3D
## Knife, bandages, bonfire, raptor pack, distant utahraptor. F5 cap test, F6 heal.

var _player: Player

func _ready() -> void:
	var kit := LabKit.build(self, 100.0)
	_player = kit["player"]
	LabKit.give(_player, &"stone_knife", 1)
	LabKit.give(_player, &"bandage", 3)
	LabKit.give(_player, &"pressure_dressing", 1)
	var fire := Bonfire.new()
	fire.position = Vector3(3, 0, 3)
	add_child(fire)
	var pack := Spawner.new()
	pack.species = &"velociraptor"
	pack.count = 3
	pack.radius = 3.0
	pack.as_pack = true
	pack.position = Vector3(10, 0, 8)
	add_child(pack)
	pack.spawn_now()
	var apex := Spawner.new()
	apex.species = &"utahraptor"
	apex.count = 1
	apex.as_pack = false
	apex.position = Vector3(40, 0, 8)
	add_child(apex)
	apex.spawn_now()
	print("[boot] lab=hunt_lab")
	if DisplayServer.get_name() == "headless" or Game.shot_path != "":
		get_tree().create_timer(0.4).timeout.connect(_demo)

func _demo() -> void:
	if Game.shot_path == "":
		_player.statuses.apply(&"groggy")
		_player.statuses.apply(&"dizziness")
		_player.statuses.apply(&"bleed")
		_player.statuses.apply(&"venom")
	var pack: Creature = null
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and c.def.id == &"velociraptor":
			pack = c
			break
	if pack:
		if Game.shot_path != "":
			_player.global_position = pack.global_position + Vector3(-1.7, 0, 0.2)
			_player.face_world(pack.global_position)
		_player.hunt.start(pack)
		_player.play_attack(false)
		pack.health.take_damage(40.0, _player)
		pack.anim.play_clip(&"attack_heavy")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F5:
			_player.statuses.apply(&"groggy")
			_player.statuses.apply(&"dizziness")
			_player.statuses.apply(&"bleed")
			_player.statuses.apply(&"venom")
		elif event.physical_keycode == KEY_F6:
			_player.vitals.heal(80.0)
			print("[combat] F6 heal")
