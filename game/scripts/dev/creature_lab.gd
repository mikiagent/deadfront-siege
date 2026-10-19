extends Node3D
## Pack of 3 velociraptors, one deinonychus, one utahraptor. Keys 1-9 force clips; F deals 100.
## The survivor cannot die here: it is an art lab, and the raptors used to kill it in ~2 s, so
## every close-up showed YOU DIED. Headless it is a gate: all six spawn, the AI engages and the
## survivor is still standing after 8 s.

const EXPECTED := 6
var _player: Player
var _creatures: Array[Creature] = []

func _ready() -> void:
	Game.lab_force_clips = true
	Game.lab_flat_attack = true
	var kit := LabKit.build(self)
	_player = kit["player"]
	# Heal back inside the damaged signal: Vitals emits it before its death check.
	_player.vitals.damaged.connect(func () -> void: _player.vitals.health = _player.vitals.effective_max_health())
	_obstacle(Vector3(6, 1, 0))
	_obstacle(Vector3(-8, 1, 5))
	_obstacle(Vector3(3, 1, -10))
	_spawn(&"velociraptor", 3, Vector3(8, 0, 8), 3.0, true)
	_spawn(&"deinonychus", 1, Vector3(-10, 0, 6), 1.0, false)
	_spawn(&"utahraptor", 1, Vector3(12, 0, -8), 1.0, false)
	_spawn(&"protoceratops", 1, Vector3(-6, 0, -8), 1.0, false)
	print("[boot] lab=creature_lab")
	if LabResult.headless():
		_gate()

func _gate() -> void:
	var r := LabResult.new("creature_lab")
	r.deadline(get_tree(), 25.0)
	var start: Array[Vector3] = []
	for c in _creatures:
		start.append(c.global_position)
	await get_tree().create_timer(8.0).timeout
	var moved := 0
	for i in _creatures.size():
		if is_instance_valid(_creatures[i]) and _creatures[i].global_position.distance_to(start[i]) > 0.5:
			moved += 1
	r.expect(_creatures.size() == EXPECTED, "spawned %d of %d creatures" % [_creatures.size(), EXPECTED])
	r.expect(moved > 0, "no creature moved in 8 s (AI idle)")
	r.expect(not _player.dead and _player.vitals.health > 0.0, "survivor died in the art lab")
	r.finish(get_tree(), "creatures=%d moved=%d hp=%.0f" % [_creatures.size(), moved, _player.vitals.health])

func _spawn(species: StringName, count: int, pos: Vector3, radius: float, pack: bool) -> void:
	var s := Spawner.new()
	s.species = species
	s.count = count
	s.radius = radius
	s.as_pack = pack
	s.position = pos
	add_child(s)
	_creatures.append_array(s.spawn_now())

func _obstacle(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 2, 1)
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.4, 0.3)
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1, 2, 1)
	cs.shape = sh
	body.add_child(cs)
	add_child(body)
