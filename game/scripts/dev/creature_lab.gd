extends Node3D
## Pack of 3 velociraptors, one deinonychus, one utahraptor. Keys 1-9 force clips; F deals 100.
## The survivor cannot die, tire or exhaust here (god mode, this lab only) so clips can be watched up close.
## --species=deinonychus[,velociraptor...] spawns only those (one each) instead of the default roster.
## --ride=deinonychus spawns that species as a saddled pet and puts the survivor on it.
## Key 0 plays bite_combo (chomp, Chomp, CHOMP) on the mount, or else the nearest creature that has one. The game
## does not load that clip yet, so the lab plays it straight from the GLB with the creature's tree paused.

var _player: Player

func _ready() -> void:
	Game.lab_force_clips = true
	Game.lab_flat_attack = true
	_player = LabKit.build(self)["player"] as Player
	_obstacle(Vector3(6, 1, 0))
	_obstacle(Vector3(-8, 1, 5))
	_obstacle(Vector3(3, 1, -10))
	var only := ""
	var ride := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--species="):
			only = a.substr(10)
		elif a.begins_with("--ride="):
			ride = a.substr(7)
	if ride != "":
		_ride.call_deferred(StringName(ride))
		if only == "":
			return
	if only != "":
		var spots := [Vector3(-8, 0, 6), Vector3(8, 0, 8), Vector3(12, 0, -8), Vector3(-6, 0, -8)]
		var ids := only.split(",")
		for i in ids.size():
			_spawn(StringName(ids[i]), 1, spots[i % spots.size()], 1.0, false)
	else:
		_spawn(&"velociraptor", 3, Vector3(8, 0, 8), 3.0, true)
		_spawn(&"deinonychus", 1, Vector3(-10, 0, 6), 1.0, false)
		_spawn(&"utahraptor", 1, Vector3(12, 0, -8), 1.0, false)
		_spawn(&"protoceratops", 1, Vector3(-6, 0, -8), 1.0, false)
	print("[boot] lab=creature_lab")

func _process(_dt: float) -> void:
	if _player and _player.vitals:  # a pool no single hit can empty, refilled every frame
		_player.vitals.max_health = maxf(_player.vitals.max_health, 1000000.0)
		_player.vitals.health = _player.vitals.effective_max_health()
		_player.vitals.energy = _player.vitals.effective_max_energy()
		_player.vitals.fatigue = 0.0
		_player.vitals.exhausted = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_0:
		var c: Creature = _player.mounted_on if _player.mounted_on else _player.actions.nearest_creature(9999.0, true)
		if c:
			_play_combo(c)

func _play_combo(c: Creature) -> void:
	var path := "res://assets/creatures/%s/anim/bite_combo.glb" % c.def.id
	if not ResourceLoader.exists(path):
		print("[creature_lab] %s has no bite_combo" % c.def.id)
		return
	var lib := c.anim.player.get_animation_library("")
	if not lib.has_animation(&"bite_combo"):
		var anim := CreatureClips._from_glb(path, c.view, c.anim.player, &"bite_combo")
		if anim == null:
			return
		lib.add_animation(&"bite_combo", anim)
	c.anim.tree.active = false
	c.anim.player.play(&"bite_combo")
	await get_tree().create_timer(lib.get_animation(&"bite_combo").length).timeout
	if is_instance_valid(c):
		c.anim.player.stop()
		c.anim.tree.active = true

func _ride(id: StringName) -> void:
	var def := Data.creature(id)
	if def == null or not def.tameable:
		push_warning("creature_lab: %s is not a tameable species" % id)
		return
	var rec := PetRecord.from_def(def, &"A")
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	_player.get_parent().add_child(c)
	c.is_pet = true
	c.pet_record = rec
	c.spawn(def, rec.variant)
	c.global_position = _player.global_position + Vector3(3, 0.2, 0)
	await get_tree().create_timer(0.4).timeout
	_player.mount(c)

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
