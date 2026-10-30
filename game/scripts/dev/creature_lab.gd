extends Node3D
## Pack of 3 velociraptors, one deinonychus, one utahraptor. Keys 1-9 force clips; F deals 100.
## The survivor cannot die, tire or exhaust here (god mode, this lab only) so clips can be watched up close.
## --species=deinonychus[,velociraptor...] spawns only those (one each) instead of the default roster.
## --ride=deinonychus spawns that species as a saddled pet and puts the survivor on it.
## The SPAWN button (left) opens a selector: a dropdown of every species (model-less ones as stand-ins), count 1-6, nature or Random, Alpha;
## SPAWN drops them in front of the survivor, CLEAR ALL removes every wild animal.
## Key N (or --enrage) enrages the nearest wild creature.
## Key 0 plays bite_combo (chomp, Chomp, CHOMP) on the mount, or else the nearest creature that has one.
## Wild deinonychus fight with TacticalBrain (circle, feint, lunge, pounce, combo); F3 prints each move.
## --seq=DIR saves a frame every 0.25 s for 25 s (named by the nearest creature's brain state), then quits;
## a lurking ambusher is stepped into its ambush radius after a second so the capture shows the fight.
## --clipshots=DIR (with --species=X): the selector shows X picked, then that creature plays each clip of CLIPSHOTS
## with its brain off, side-on beside the survivor, 6 frames per clip saved as DIR/<clip>_<k>.png, then the lab quits.

var _player: Player
## The on-screen SPAWN selector (species, count 1-6, nature, Alpha; Spawn / Clear all).
var spawn_panel: LabSpawnPanel
var _seq_dir := ""
var _seq_t := 0.0
var _seq_n := 0
const CLIPSHOTS: Array[StringName] = [&"idle", &"walk", &"run", &"alert", &"attack_primary", &"attack_heavy", &"tail_swipe"]

func _ready() -> void:
	Game.lab_force_clips = true
	Game.lab_flat_attack = true
	_player = LabKit.build(self)["player"] as Player
	_obstacle(Vector3(6, 1, 0))
	_obstacle(Vector3(-8, 1, 5))
	_obstacle(Vector3(3, 1, -10))
	LabKit.bake(self)  # the crates carve the navmesh, so ground taps route around them
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	spawn_panel = LabSpawnPanel.new()
	layer.add_child(spawn_panel)
	spawn_panel.setup(_player)
	var only := ""
	var ride := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--species="):
			only = a.substr(10)
		elif a.begins_with("--ride="):
			ride = a.substr(7)
		elif a.begins_with("--seq="):
			_seq_dir = a.substr(6)
		elif a == "--spawn-open":
			(func() -> void: spawn_panel.get_node("SpawnPanel").visible = true).call_deferred()
		elif a.begins_with("--clipshots="):
			_clipshots.call_deferred(a.substr(12), StringName(only.get_slice(",", 0)))
		elif a == "--enrage":
			get_tree().create_timer(1.0).timeout.connect(_enrage_nearest)
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
	if _seq_dir != "":
		_seq_t += _dt
		if _seq_t >= 1.5 + 0.25 * _seq_n:
			var c: Creature = _player.actions.nearest_creature(9999.0, true)
			var tag := str(c.brain_state) if c else "none"
			if _seq_n == 4 and c and c.brain is TacticalBrain and (c.brain as TacticalBrain).lurking:
				# An ambusher lurks until prey comes close: step it into the ambush radius for the capture.
				var away := c.global_position - _player.global_position
				away.y = 0.0
				c.global_position = _player.global_position + away.normalized() * 5.0
			get_viewport().get_texture().get_image().save_png("%s/f%03d_%s.png" % [_seq_dir, _seq_n, tag])
			_seq_n += 1
			if _seq_n >= 100:
				get_tree().quit()
	if _player and _player.vitals:  # a pool no single hit can empty, refilled every frame
		_player.vitals.max_health = maxf(_player.vitals.max_health, 1000000.0)
		_player.vitals.health = _player.vitals.effective_max_health()
		_player.vitals.energy = _player.vitals.effective_max_energy()
		_player.vitals.fatigue = 0.0
		_player.vitals.exhausted = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:
		_enrage_nearest()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_0:
		var c: Creature = _player.mounted_on if _player.mounted_on else _player.actions.nearest_creature(9999.0, true)
		if c:
			_play_combo(c)

## N (or --enrage at start): enrage the nearest wild creature (blood fx, the enraged tactics, Timid runs).
func _enrage_nearest() -> void:
	var c: Creature = _player.actions.nearest_creature(9999.0, true)
	if c:
		c.statuses.apply(&"enraged", _player)
		print("[creature_lab] %s enraged (%s)" % [c.def.id, c.nature])

func _play_combo(c: Creature) -> void:
	if not c.anim.has_state(&"bite_combo"):
		print("[creature_lab] %s has no bite_combo" % c.def.id)
		return
	c.anim.play_clip(&"bite_combo")

func _ride(id: StringName) -> void:
	var def := Data.creature(id)
	if def == null or not def.tameable:
		push_warning("creature_lab: %s is not a tameable species" % id)
		return
	var rec := PetRecord.from_def(def, &"A")
	rec.fit_saddle()  # SADDLES: riding needs one
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	_player.get_parent().add_child(c)
	c.is_pet = true
	c.pet_record = rec
	c.spawn(def, rec.variant)
	c.global_position = _player.global_position + Vector3(3, 0.2, 0)
	await get_tree().create_timer(0.4).timeout
	_player.mount(c)

func _clipshots(dir: String, id: StringName) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	spawn_panel.get_node("SpawnPanel").visible = true
	spawn_panel._pick_species(id)
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("%s/selector.png" % dir)
	spawn_panel.get_node("SpawnPanel").visible = false
	var c: Creature = null
	for n in get_tree().get_nodes_in_group("creatures"):
		if n is Creature and (n as Creature).def.id == id:
			c = n
	if c == null:
		push_error("[clipshots] no %s spawned" % id)
		get_tree().quit(1)
		return
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.set_physics_process(false)
	c.global_position = Vector3(-18, 0, -24)  # clear of the lab crates
	c.rotation.y = -PI / 2.0  # faces +X: side-on to the camera
	_player.global_position = c.global_position + Vector3(c.def.height_meters * 1.3, 0.1, 2.0)
	_player.rotation.y = -PI / 2.0  # faces the snout
	var h := c.def.height_meters
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40.0
	cam.global_position = c.global_position + Vector3(h * 0.4, h * 0.6, h * 4.4)
	cam.look_at(c.global_position + Vector3(h * 0.4, h * 0.45, 0.0))
	cam.current = true
	for clip in CLIPSHOTS:
		if not c.anim.has_state(clip):
			continue
		c.anim.play_clip(clip, true)
		var dur: float = c.anim.player.get_animation(clip).length if c.anim.player.has_animation(clip) else 1.0
		for k in 6:
			await get_tree().create_timer(dur / 6.0).timeout
			get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [dir, clip, k])
		c.anim.play_idle()
		await get_tree().create_timer(0.4).timeout
	print("[clipshots] wrote %s" % dir)
	get_tree().quit()

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
