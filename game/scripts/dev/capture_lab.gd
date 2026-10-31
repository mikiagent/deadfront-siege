extends Node3D
## Field tame (M9b) + pen tame, end to end, plus the spec 09 capture rule (capture09):
## stunned at ANY HP or HP <= 30 %. Wears animals down, checks the rule and the net chance on live
## creatures, completes one field tame and one net -> pen tame, checks the technique lock, prints
## '[capture] PASS bonded+=2' and exits 0, else prints the failures and exits 1. F8 time_scale x60.
## Windowed with --shot-dir=DIR it saves PNGs and prints one
## "[capture09] RESULT k=v ..." line, every number measured from the live scene, then quits.

var _player: Player
var _cam: Camera3D
var _fails: Array[String] = []
var _out := ""
var _shot_n := 0
var _m: Dictionary = {}

func _ready() -> void:
	CreatureDef.allow_placeholder = true  # NOBOXES: this lab may show model-less species as boxes
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
		Game.debug_overlay = false  # the perf/debug label collided with the vitals card in shots
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
	var visual := Game.shot_path != "" or _out != ""
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
	# Spec 09 rule, measured on live creatures in this scene (not on constants).
	await _rule_checks()
	if visual:
		await _shots(a, cat)
		return
	if shot:
		# Leave berries so the plate shows Tame 0/3; the cat's plate shows the technique lock.
		return
	_check(a.health.fraction() < FieldTame.CAPTURE_HEALTH_FRAC and FieldTame.can_attempt(a), "compsognathus down below 30 %% HP (%.0f%%)" % (100.0 * a.health.fraction()))
	# Technique lock: a tier-5 smilodon refuses food without Capture Technique V.
	LabKit.give(_player, &"raw_meat", 3)
	var hint := FieldTame.plate_hint(cat, _player.inventory)
	_check(str(hint.get("text", "")) == "Needs Capture Technique 5" and not FieldTame.apply_feed(_player, cat, &"raw_meat"), "smilodon refused: '%s'" % str(hint.get("text", "")))
	# Field tame: three preferred berries. _complete overwrites a.level, so read it first.
	var wild_a := a.level
	for _i in 3:
		FieldTame.apply_feed(_player, a, &"berry")
		await get_tree().create_timer(0.05).timeout
	var field_rec: PetRecord = _player.bonded[-1] if _player.bonded.size() > bonded_before else null
	_check(field_rec != null and a.is_pet and field_rec.origin == &"tame" and field_rec.uid != "" and field_rec.level == clampi(wild_a, 1, 60), "field tame bonded %s" % _describe(field_rec))
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
	var visual := Game.shot_path != "" or _out != ""
	if _fails.is_empty():
		print("[capture] PASS bonded+=2")
	else:
		print("[capture] FAIL %s" % "; ".join(PackedStringArray(_fails)))
	if visual:
		_report()
		return
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		await get_tree().create_timer(0.15).timeout
		get_tree().quit(0 if _fails.is_empty() else 1)

# ---------------------------------------------------------------- spec 09, measured

## Spec 09 §1 on live creatures: stun at any HP, or HP <= 30 %. Fills `_m` from what the scene does.
## Every number printed in the RESULT line is read here, never copied from a constant.
func _rule_checks() -> void:
	var arena := Node3D.new()
	arena.name = "RuleArena"
	add_child(arena)
	arena.position = Vector3(-8, 0, 6)
	var stun_high := _spawn(&"compsognathus", &"rule_stun80", arena.position + Vector3(0, 0, 0))
	var hp_30 := _spawn(&"compsognathus", &"rule_30", arena.position + Vector3(2, 0, 0))
	var hp_31 := _spawn(&"compsognathus", &"rule_31", arena.position + Vector3(4, 0, 0))
	var dot_high := _spawn(&"compsognathus", &"rule_dot80", arena.position + Vector3(6, 0, 0))
	var hint_fodder := _spawn(&"compsognathus", &"rule_hint45", arena.position + Vector3(8, 0, 0))
	for c in [stun_high, hp_30, hp_31, dot_high, hint_fodder]:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	stun_high.health.hp = stun_high.health.max_hp * 0.80
	stun_high.statuses.apply(&"knockdown", _player)
	hp_30.health.hp = hp_30.health.max_hp * 0.30
	hp_31.health.hp = hp_31.health.max_hp * 0.31
	dot_high.health.hp = dot_high.health.max_hp * 0.80
	hint_fodder.health.hp = hint_fodder.health.max_hp * 0.45
	for c in [stun_high, hp_30, hp_31]:
		c.torpor = c.torpor_max()  # FOODTORPOR: the window also needs torpor past the threshold
	await get_tree().process_frame

	_m["window_stun80"] = 1 if FieldTame.capture_window(stun_high) else 0
	_m["window_hp30"] = 1 if FieldTame.capture_window(hp_30) else 0
	_m["window_hp31"] = 1 if FieldTame.capture_window(hp_31) else 0
	_m["hp_stun80"] = int(round(100.0 * stun_high.health.fraction()))
	_m["hp_hp30"] = int(round(100.0 * hp_30.health.fraction()))
	_m["hp_hp31"] = int(round(100.0 * hp_31.health.fraction()))
	_m["chance_stun80"] = snappedf(CaptureSystem.chance_for(stun_high, 1), 0.01)
	hp_31.health.hp = hp_31.health.max_hp * 0.20
	_m["chance_hp20"] = snappedf(CaptureSystem.chance_for(hp_31, 1), 0.01)
	hp_31.health.hp = hp_31.health.max_hp * 0.31

	# Never force damage onto a capturable animal: a bleed on a stunned 80 % animal does nothing.
	dot_high.statuses.apply(&"knockdown", _player)
	dot_high.statuses.apply(&"bleeding_target", _player)
	var before_dot := dot_high.health.hp
	var inst: StatusInstance = dot_high.statuses.get_instance(&"bleeding_target")
	for _i in 4:
		dot_high.statuses._dot(inst)
	_m["dot_skips_stun80"] = 1 if is_equal_approx(dot_high.health.hp, before_dot) else 0

	# The hunt: the Net tactic is offered on the stunned animal, and the 50 % hint fires once.
	_player.hunt.auto = false
	_player.global_position = stun_high.global_position + Vector3(0, 0.9, 2.0)
	_player.hunt.start(stun_high)
	await get_tree().process_frame
	_m["net_label"] = 1 if _player.hunt.tactic_label(4) == "Net" else 0
	_player.hunt.stop()
	_player.hunt._stun_hinted.clear()
	_player.global_position = hint_fodder.global_position + Vector3(0, 0.9, 2.0)
	_player.hunt.start(hint_fodder)
	await get_tree().process_frame
	for _i in 3:
		_player.hunt._maybe_stun_hint()
	_m["hint_fires"] = _player.hunt._stun_hinted.size()
	_m["hint_text"] = 1 if _player.hunt.last_notice == Hunt.STUN_HINT else 0
	hint_fodder.health.hp = hint_fodder.health.max_hp * 0.60
	_player.hunt._stun_hinted.clear()
	_player.hunt._maybe_stun_hint()
	_m["hint_above50"] = 0 if _player.hunt._stun_hinted.is_empty() else 1
	_player.hunt.stop()
	_check(int(_m.get("window_stun80", 0)) == 1 and int(_m.get("window_hp30", 0)) == 1 and int(_m.get("window_hp31", 0)) == 0, "spec 09 window: stun@%d%%=%d hp%d%%=%d hp%d%%=%d" % [_m["hp_stun80"], _m["window_stun80"], _m["hp_hp30"], _m["window_hp30"], _m["hp_hp31"], _m["window_hp31"]])
	_check(float(_m.get("chance_stun80", 1.0)) < float(_m.get("chance_hp20", 0.0)), "chance uses actual HP (%.2f at %d%% < %.2f at 20%%)" % [float(_m["chance_stun80"]), int(_m["hp_stun80"]), float(_m["chance_hp20"])])
	_check(int(_m.get("dot_skips_stun80", 0)) == 1, "bleed skips a stunned 80 %% animal")
	_check(int(_m.get("net_label", 0)) == 1, "the Net tactic is offered on a stunned 80 %% animal")
	_check(int(_m.get("hint_fires", 0)) == 1 and int(_m.get("hint_text", 0)) == 1 and int(_m.get("hint_above50", 0)) == 0, "the stun hint fires once, at <= 50 %% only")
	for c in [stun_high, hp_30, hp_31, dot_high, hint_fodder]:
		c.queue_free()
	arena.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- shots + RESULT

func _shot(step: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_shot_n += 1
	var img := get_viewport().get_texture().get_image()
	if img == null:
		_fails.append("no viewport image for %s" % step)
		return
	if _out == "":
		return
	var path := _out.path_join("capture09_%02d_%s_%dx%d.png" % [_shot_n, step, get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y])
	img.save_png(path)
	print("[capture09] shot %s" % path)

## The same scene a player sees: a stunned animal at high HP with its plate and the Net hex ready.
func _shots(a: Creature, cat: Creature) -> void:
	var stunned := _spawn(&"velociraptor", &"shot_stun80", _player.global_position + Vector3(1.6, 0, -1.2))
	stunned.brain.process_mode = Node.PROCESS_MODE_DISABLED
	var full := stunned.health.max_hp
	stunned.health.hp = full * 0.82
	stunned.statuses.apply(&"knockdown", _player)
	stunned.torpor = stunned.torpor_max()
	stunned.anim.play_clip(&"knockdown")
	_m["shot_hp"] = int(round(100.0 * stunned.health.fraction()))
	_m["shot_window"] = 1 if FieldTame.capture_window(stunned) else 0
	_player.global_position = stunned.global_position + Vector3(-1.2, 0.9, 1.6)
	_player.hunt.auto = false
	_player.hunt.start(stunned)
	if _cam:
		_cam.global_position = _player.global_position + Vector3(0.5, 7.5, 6.0)
		_cam.look_at(stunned.global_position + Vector3(0, 0.6, 0), Vector3.UP)
		_cam.size = 8.0
	Game.reveal_creature_plate(stunned, 8.0)
	Game.reveal_creature_plate(a, 8.0)
	Game.reveal_creature_plate(cat, 8.0)
	# Drop the notices the rule checks just printed, so the shot shows only this state.
	var hud := get_tree().get_first_node_in_group("hud") as HuntHud
	if hud:
		hud._events.notices.clear()
	_m["net_label"] = 1 if _player.hunt.tactic_label(4) == "Net" else 0
	_m["ui_min_px"] = _min_hex_px()
	await get_tree().create_timer(0.5).timeout
	await _shot("stunned_80_hp_net_ready")
	# The refusal message, on the same HUD, for a healthy unstunned animal.
	for inst in stunned.statuses.instances().duplicate():
		stunned.statuses.clear_id(inst.id)
	stunned.health.hp = full * 0.70
	_player.hunt.use_net()
	_m["refusal_text"] = 1 if _player.hunt.last_notice == FieldTame.refusal(stunned) else 0
	await get_tree().create_timer(0.3).timeout
	await _shot("refused_unstunned")
	_check(int(_m.get("shot_window", 0)) == 1 and int(_m.get("net_label", 0)) == 1 and int(_m.get("refusal_text", 0)) == 1, "windowed: stun@%d%% opens the net, unstunned @70%% refuses" % int(_m.get("shot_hp", 0)))
	_finish()

## Smallest combat hex on screen, measured (the 64 px touch target rule).
func _min_hex_px() -> int:
	var hud := get_tree().get_first_node_in_group("hud") as HuntHud
	if hud == null:
		return 0
	var smallest := 999
	for b in hud._skill_hexes:
		smallest = mini(smallest, mini(int(b.size.x), int(b.size.y)))
	return 0 if smallest == 999 else smallest

func _report() -> void:
	var keys := ["window_stun80", "window_hp30", "window_hp31", "hp_stun80", "hp_hp30", "hp_hp31",
		"chance_stun80", "chance_hp20", "dot_skips_stun80", "net_label", "hint_fires",
		"hint_text", "hint_above50", "shot_hp", "shot_window", "refusal_text", "ui_min_px", "shots"]
	_m["shots"] = _shot_n
	var parts: PackedStringArray = []
	for k in keys:
		parts.append("%s=%s" % [k, str(_m.get(k, 0))])
	print("[capture09] RESULT %s" % " ".join(parts))
	if _fails.is_empty():
		print("[capture09] PASS shots=%d dir=%s" % [_shot_n, _out])
	else:
		print("[capture09] FAIL count=%d: %s" % [_fails.size(), ", ".join(_fails)])
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
	pen.claim(_player) # PENCLAIM: the tame waits in the pen until Bond
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
