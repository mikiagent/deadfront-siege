extends Node3D
## Field tame (M9b) + pen tame, end to end. Headless: wears the animals below 30 % HP, completes
## one field tame and one net -> pen tame, checks the technique lock, prints
## '[capture] PASS bonded+=2' and exits 0, else prints the failures and exits 1. F8 time_scale x60.

var _player: Player
var _cam: Camera3D
var _fails: Array[String] = []

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
	_spawn(&"compsognathus", &"comp_a", Vector3(3.2, 0, 1.5))
	_spawn(&"compsognathus", &"comp_b", Vector3(5.0, 0, 2.2))
	_spawn(&"smilodon", &"cat", Vector3(-3.0, 0, -1.5))
	print("[boot] lab=capture_lab")
	if DisplayServer.get_name() == "headless" or Game.shot_path != "":
		get_tree().create_timer(0.35).timeout.connect(_demo)

func _spawn(species: StringName, node_name: StringName, at: Vector3) -> Creature:
	var def := Data.creature(species)
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	c.name = String(node_name)
	add_child(c)
	c.global_position = at
	c.spawn(def)
	return c

func _check(ok: bool, what: String) -> void:
	print("[capture] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _demo() -> void:
	var shot := Game.shot_path != ""
	var a := get_node_or_null("comp_a") as Creature
	var b := get_node_or_null("comp_b") as Creature
	var cat := get_node_or_null("cat") as Creature
	if a == null or b == null or cat == null:
		_check(false, "lab creatures spawned")
		_finish()
		return
	_player.global_position = Vector3(2.0, 0.0, 1.0)
	if _cam:
		_cam.global_position = Vector3(2.5, 10.0, 8.0)
		_cam.look_at(a.global_position + Vector3(0, 0.4, 0), Vector3.UP)
		_cam.size = 9.0
	var bonded_before := _player.bonded.size()
	# Down all three below the 30 % rule; keep the knockdown long for the shot.
	_wear_and_knock_down(a)
	_wear_and_knock_down(b)
	_wear_and_knock_down(cat)
	a.statuses.extend(&"knockdown", 30.0)
	if Game and Game.has_method("reveal_creature_plate"):
		Game.reveal_creature_plate(a, 8.0)
		Game.reveal_creature_plate(cat, 8.0)
	if shot:
		# Leave berries so the plate shows Tame 0/3; the cat's plate shows the technique lock.
		return
	_check(a.health.fraction() < FieldTame.CAPTURE_HEALTH_FRAC and FieldTame.can_attempt(a), "compsognathus down below 30 %% HP (%.0f%%)" % (100.0 * a.health.fraction()))
	# Technique lock: a tier-5 smilodon refuses food without Capture Technique V.
	LabKit.give(_player, &"raw_meat", 3)
	var hint := FieldTame.plate_hint(cat, _player.inventory)
	_check(str(hint.get("text", "")) == "Needs Capture Technique 5" and not FieldTame.apply_feed(_player, cat, &"raw_meat"), "smilodon refused: '%s'" % str(hint.get("text", "")))
	# Field tame: three preferred berries.
	for _i in 3:
		FieldTame.apply_feed(_player, a, &"berry")
		await get_tree().create_timer(0.05).timeout
	var field_rec: PetRecord = _player.bonded[-1] if _player.bonded.size() > bonded_before else null
	_check(field_rec != null and a.is_pet and field_rec.origin == &"tame" and field_rec.uid != "" and field_rec.level == clampi(a.level, 1, 60), "field tame bonded %s" % _describe(field_rec))
	# Refusal: strip food, tap second downed animal.
	for id in [&"berry", &"herb_leaf", &"fibre_stalk", &"raw_meat"]:
		while _player.inventory.find_first(id) >= 0:
			_player.inventory.remove_at(_player.inventory.find_first(id), 99)
	_player._begin_field_tame(b)
	await get_tree().create_timer(0.1).timeout
	_check(not b.is_pet, "no food, no tame")
	# Corpse despawn line (force empty lifetime).
	var victim := _spawn(&"compsognathus", &"comp_dead", Vector3(7.0, 0, 3.0))
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
	await _pen_demo()
	var gained := _player.bonded.size() - bonded_before
	_check(gained == 2, "bonded +%d" % gained)
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[capture] PASS bonded+=2")
	else:
		print("[capture] FAIL %s" % "; ".join(PackedStringArray(_fails)))
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		await get_tree().create_timer(0.15).timeout
		get_tree().quit(0 if _fails.is_empty() else 1)

## The real route to the capture window: groggy, then a hit that leaves it under 30 % HP.
func _wear_and_knock_down(c: Creature) -> void:
	c.statuses.apply(&"groggy", _player)
	c.health.take_damage(c.health.hp - c.health.max_hp * 0.25, _player)
	if not c.statuses.has(&"knockdown"):
		c.statuses.apply(&"knockdown", _player)
		c.anim.play_clip(&"knockdown")
	c.is_capturable = true
	FieldTame.begin_window(c)

func _describe(rec: PetRecord) -> String:
	if rec == null:
		return "(none)"
	return "%s grade=%s lv=%d wild=%d origin=%s uid=%s" % [rec.species, rec.grade, rec.level, rec.wild_level, rec.origin, rec.uid]

## Net a downed raptor, pen it, run the pen to completion: it must land in the roster.
func _pen_demo() -> void:
	var raptor: Creature = null
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and c.def.id == &"velociraptor" and not c.is_pet and not c.health.dead:
			raptor = c
			break
	if raptor == null:
		_check(false, "raptor to net")
		return
	var wild_level := raptor.level
	_wear_and_knock_down(raptor)
	var netted := CaptureSystem.attempt(_player, raptor, 1)
	_check(netted and _player.inventory.find_first(&"captured_animal") >= 0, "raptor netted below 30 % HP")
	var pen := TamingPen.new()
	pen.position = Vector3(-2, 0, 2)
	add_child(pen)
	pen.force_result = 1
	var before := _player.bonded.size()
	_check(pen.try_insert(_player), "captured raptor goes into the pen")
	Game.time_scale = 60.0
	pen.remaining = 0.15
	pen.feed(_player)
	await get_tree().create_timer(0.2).timeout
	Game.time_scale = 1.0
	var rec: PetRecord = _player.bonded[-1] if _player.bonded.size() > before else null
	_check(rec != null and rec.origin == &"capture" and rec.level == clampi(wild_level, 1, 60) and _player.inventory.find_first(&"tamed_animal") < 0, "pen tame bonded %s" % _describe(rec))

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
				_wear_and_knock_down(best)
				print("[tame] lab knockdown %s" % best.def.id)
