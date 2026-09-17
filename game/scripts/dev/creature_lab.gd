extends Node3D
## Pack of 3 velociraptors, one deinonychus, one utahraptor. Keys 1-9 force clips; F deals 100.

func _ready() -> void:
	Game.lab_force_clips = true
	Game.lab_flat_attack = true
	LabKit.build(self)
	_obstacle(Vector3(6, 1, 0))
	_obstacle(Vector3(-8, 1, 5))
	_obstacle(Vector3(3, 1, -10))
	_spawn(&"velociraptor", 3, Vector3(8, 0, 8), 3.0, true)
	_spawn(&"deinonychus", 1, Vector3(-10, 0, 6), 1.0, false)
	_spawn(&"utahraptor", 1, Vector3(12, 0, -8), 1.0, false)
	print("[boot] lab=creature_lab")

func _spawn(species: StringName, count: int, pos: Vector3, radius: float, pack: bool) -> void:
	var s := Spawner.new()
	s.species = species
	s.count = count
	s.radius = radius
	s.as_pack = pack
	s.position = pos
	add_child(s)
	s.spawn_now()

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
