extends Node3D
## Pack of 3 velociraptors, one deinonychus, one utahraptor. Keys 1-9 force clips; F deals 100.
## FIGHT LAB: GOD mode (Game.god_mode, checked in Vitals) is on by default here: no damage, no death, energy and
## fatigue never run out, cooldowns as in play. GOD button or key G toggles it; it is switched off when the lab exits.
## With --god (tools/fight_lab.command) F is the real attack (hunt, 1-4 tactics) instead of the flat 100.
## NEXT (or key T) clears and spawns the next modelled species, one Aggressive animal, and prints its moves.
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
## (or --clips=a,b,...) with its brain off, side-on beside the survivor, 6 frames per clip saved as DIR/<clip>_<k>.png,
## and an attack's hit frame (the attack_hit event) as DIR/<clip>_hit.png, then the lab quits.
## --clipsheet=DIR [--clips=investigate,sniff]: contact sheets of the first creature's clips (8 frames, front
## three-quarter row over a side row) to DIR/<species>_<clip>.png, then quits. Brain off, tree stepped by hand.
## --lineup=DIR [--species=a,b,c]: those species (default the three raptors) side-on in a row at body size 1.0
## beside the survivor, each mesh's measured length and height printed, DIR/lineup.png saved, then quits.

var _player: Player
## The on-screen SPAWN selector (species, count 1-6, nature, Alpha; Spawn / Clear all).
var spawn_panel: LabSpawnPanel
var _seq_dir := ""
var _seq_t := 0.0
var _seq_n := 0
const CLIPSHOTS: Array[StringName] = [&"idle", &"walk", &"run", &"alert", &"attack_primary", &"attack_heavy", &"tail_swipe"]
var _sheet_dir := ""
var _sheet_clips: Array[StringName] = [&"investigate", &"sniff"]
var _clips_given := false

func _ready() -> void:
	CreatureDef.allow_placeholder = true  # NOBOXES: this lab may show model-less species as boxes
	Game.lab_force_clips = true
	Game.lab_flat_attack = not ("--god" in OS.get_cmdline_user_args())  # the fight lab (--god) swings for real: hunt, tactics, damage
	Game.god_mode = true  # FIGHT LAB default; the GOD button turns it off
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
		elif a.begins_with("--clipsheet="):
			_sheet_dir = a.substr(12)
		elif a.begins_with("--clips="):
			_clips_given = true
			_sheet_clips.clear()
			for n in a.substr(8).split(","):
				_sheet_clips.append(StringName(n))
		elif a == "--spawn-open":
			(func() -> void: spawn_panel.get_node("SpawnPanel").visible = true).call_deferred()
		elif a.begins_with("--lineup="):
			_lineup.call_deferred(a.substr(9), only)
			return
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
		_spawn(&"zebraceratops", 1, Vector3(-6, 0, -8), 1.0, false)
	print("[boot] lab=creature_lab")
	if _sheet_dir != "":
		_clip_sheets.call_deferred()

func _clip_sheets() -> void:
	await get_tree().create_timer(1.5).timeout
	var c: Creature = _player.actions.nearest_creature(9999.0, true)
	if c == null:
		push_error("creature_lab: --clipsheet found no creature")
		get_tree().quit(1)
		return
	for n in find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false  # no HUD over the sheet
	c.set_physics_process(false)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.label.visible = false
	c.global_position = _player.global_position + Vector3(0, 0, -6)
	c.rotation.y = 0.0  # faces -Z
	_player.visible = false
	c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var h := c.def.height_meters
	var at := c.global_position
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 32.0
	cam.current = true
	var views := [[Vector3(-1.3, 1.0, -2.9) * h, Vector3(0, 0.62, -0.75) * h], [Vector3(-5.2, 0.5, -0.1) * h, Vector3(0, 0.36, -0.1) * h]]  # head-on three-quarter, side
	DirAccess.make_dir_recursive_absolute(_sheet_dir)
	for clip in _sheet_clips:
		if not c.anim.has_state(clip):
			print("[creature_lab] %s has no %s" % [c.def.id, clip])
			continue
		var length := c.anim.player.get_animation(clip).length
		var tiles: Array[Image] = []
		for v in views:
			cam.look_at_from_position(at + (v[0] as Vector3), at + (v[1] as Vector3))
			await RenderingServer.frame_post_draw
			c.anim.play_idle()
			c.anim.tree.advance(0.5)
			if clip == &"investigate":
				c.anim.play_idle(true)
			else:
				c.anim.play_clip(clip)
			c.anim.tree.advance(0.0)
			for k in 8:
				c.anim.tree.advance(length / 8.0 if k > 0 else 0.25)  # first frame past the cross-fade
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var full := get_viewport().get_texture().get_image()
				var w := int(full.get_height() * 1.2)  # centre crop, a little wider than square
				var img := full.get_region(Rect2i((full.get_width() - w) / 2, 0, w, full.get_height()))
				img.resize(360, 300)
				tiles.append(img)
		var tw := tiles[0].get_width()
		var th := tiles[0].get_height()
		var sheet := Image.create(tw * 8, th * 2, false, tiles[0].get_format())
		for i in tiles.size():
			sheet.blit_rect(tiles[i], Rect2i(0, 0, tw, th), Vector2i((i % 8) * tw, (i / 8) * th))
		var out := "%s/%s_%s.png" % [_sheet_dir, c.def.id, clip]
		sheet.save_png(out)
		print("[creature_lab] sheet %s" % out)
	get_tree().quit()

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

func _exit_tree() -> void:
	Game.god_mode = false  # dev-only: never outlives the lab

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		spawn_panel.toggle_god()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		spawn_panel.next_species()
		return
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
	for n in find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false  # no HUD over the shots
	_player.process_mode = Node.PROCESS_MODE_DISABLED  # her auto-attack flashed the animal red in every frame
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
	var hit_png := [""]
	c.anim.attack_hit.connect(func(_clip: StringName) -> void:
		if hit_png[0] != "":
			get_viewport().get_texture().get_image().save_png(hit_png[0])
			hit_png[0] = "")
	var clips: Array[StringName] = _sheet_clips if _clips_given else CLIPSHOTS
	for clip in clips:
		if not c.anim.has_state(clip):
			continue
		hit_png[0] = "%s/%s_hit.png" % [dir, clip]
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

func _lineup(dir: String, only: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var ids := (only if only != "" else "velociraptor,deinonychus,utahraptor").split(",")
	var x := 3.0
	var tallest := 1.8
	for id in ids:
		var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
		add_child(c)
		c.global_position = Vector3(0, 0, -24)
		c.spawn(Data.creature(StringName(id)))
		c.view.apply_genome(1.0, 1.0)  # species size, no genetic roll
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		c.set_physics_process(false)
		c.rotation.y = -PI / 2.0  # faces +X: side-on to the camera
		await get_tree().process_frame
		var box := AABB()
		var first := true
		for mi in c.view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null or m.has_meta(&"creature_eyeshine"):
				continue
			var b: AABB = m.global_transform * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
		c.global_position.x += x - box.position.x + 1.0
		x += box.size.x + 2.0
		tallest = maxf(tallest, box.size.y)
		print("[lineup] %s length %.2f m height %.2f m (height_meters %.2f, real_length_m %.2f)" % [id, box.size.x, box.size.y, c.def.height_meters, c.def.real_length_m])
	_player.global_position = Vector3(0.0, 0.1, -24)
	_player.rotation.y = -PI / 2.0
	var cam := Camera3D.new()
	add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL  # no perspective: sizes compare 1:1
	cam.size = maxf(x * 0.62, tallest * 1.6)
	cam.global_position = Vector3(x * 0.5, tallest * 0.5, -17.0)  # close in: no lab foliage between
	cam.look_at(Vector3(x * 0.5, tallest * 0.5, -24))
	cam.current = true
	for k in 30:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("%s/lineup.png" % dir)
	print("[lineup] wrote %s/lineup.png" % dir)
	get_tree().quit()
