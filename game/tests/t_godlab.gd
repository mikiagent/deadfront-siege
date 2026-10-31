extends SceneTree
## FIGHT LAB (GODLAB): GOD mode keeps the survivor alive through a T. rex bite chain at full health and is
## off unless a lab asks; NEXT cycles every modelled species, one model each.
## Usage: godot --headless --path game --script res://tests/t_godlab.gd  -> "[t_godlab] PASS"

var failures: Array[String] = []
var _started := false

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("[t_godlab] FAIL %s" % msg)
	else:
		print("[t_godlab] ok %s" % msg)

func _run() -> void:
	var game := get_root().get_node("Game")
	var G: GDScript = load("res://scripts/core/game.gd")
	_expect(not game.god_mode, "GOD is off at boot without --god")
	_expect(not G.god_from_args(PackedStringArray(["--god"])), "--god alone (no lab) does nothing")
	_expect(not G.god_from_args(PackedStringArray(["--lab=creature_lab"])), "a lab without --god stays mortal")
	_expect(not G.god_from_args(PackedStringArray(["--lab=tutorial", "--god"])), "the tutorial (real new game) ignores --god")
	_expect(G.god_from_args(PackedStringArray(["--lab=creature_lab", "--god", "--skip-charcreate"])), "--lab= with --god turns it on")
	var host := Node3D.new()
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, -1.5)
	host.add_child(player)
	await physics_frame
	var CA: GDScript = load("res://scripts/combat/creature_attack.gd")
	var rex = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	rex.position = Vector3(0, 0, 1.5)
	host.add_child(rex)
	rex.spawn(get_root().get_node("Data").creature(&"tyrannosaurus"))
	rex.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
	var v = player.vitals
	var full: float = v.effective_max_health()
	# Control: one bite hurts a mortal survivor (the chain below is a real threat).
	CA.apply_for(rex, &"attack_primary", player)
	_expect(v.health < full, "GOD off: a T. rex bite hurts (%.0f of %.0f)" % [v.health, full])
	v.dead = false
	player.dead = false
	v.health = full
	game.god_mode = true
	var landed := 0
	for i in 12:
		if CA.apply_for(rex, &"attack_primary" if i % 3 != 2 else &"attack_heavy", player):
			landed += 1
	_expect(landed > 0 and not v.dead and is_equal_approx(v.health, full), "GOD on: %d T. rex bites land, survivor at full health (%.0f)" % [landed, v.health])
	var e: float = v.energy
	_expect(v.spend_energy(e + 50.0) and is_equal_approx(v.energy, e) and v.drain_energy(1000.0, 1.0), "GOD on: energy never runs out")
	var f: float = v.fatigue
	v.add_fatigue(500.0, &"combat")
	_expect(is_equal_approx(v.fatigue, f), "GOD on: no fatigue (%.1f -> %.1f)" % [f, v.fatigue])
	rex.queue_free()
	# NEXT cycles every modelled species, one Aggressive animal each, its own model.
	var PANEL = load("res://scripts/dev/lab_spawn_panel.gd")
	var layer := CanvasLayer.new()
	get_root().add_child(layer)
	var panel = PANEL.new()
	layer.add_child(panel)
	panel.setup(player)
	var modelled: Array = []
	for id in PANEL.all_species():
		if CreatureDef.has_model(id):
			modelled.append(id)
	var opt: OptionButton = panel.get_node("SpawnPanel").find_child("SpeciesPicker", true, false)
	_expect(opt.item_count == modelled.size() and modelled.size() > 0, "the list shows the %d modelled species only (%d rows)" % [modelled.size(), opt.item_count])
	(panel.get_node("SpawnPanel").find_child("StandIns", true, false) as Button).pressed.emit()
	_expect(opt.item_count == PANEL.all_species().size(), "Stand-ins: on lists every species")
	(panel.get_node("SpawnPanel").find_child("StandIns", true, false) as Button).pressed.emit()
	for b in ["GodToggle", "NextSpecies"]:
		_expect((panel.get_node(b) as Button).custom_minimum_size.y >= 64.0, "%s is a 64 px tap target" % b)
	# a species with several bodies (megaloceros stag, doe) comes up once per body
	var bodies: Array = []
	for id in modelled:
		var vs: Array = PANEL.variants_of(id)
		for vid in (vs if not vs.is_empty() else [""]):
			bodies.append([id, StringName(vid)])
	var want: Array = bodies.map(func(b: Array) -> StringName: return b[0])
	var seen: Array = []
	var all_ok := true
	for k in bodies.size():
		(panel.get_node("NextSpecies") as Button).pressed.emit()
		await physics_frame
		var wild: Array = []
		for n in get_root().get_tree().get_nodes_in_group("creatures"):
			if not n.is_pet and not n.is_queued_for_deletion():
				wild.append(n)
		var c = wild[0] if wild.size() == 1 else null
		var ok: bool = c != null and c.def.id == want[k] and (bodies[k][1] == &"" or c.variant == bodies[k][1]) and c.view.rig != null and c.nature == &"aggressive" and c.brain.attack_target == player
		var line: String = panel.info.text
		ok = ok and line.contains(str(want[k]).capitalize()) and line.contains("clips:")
		if not ok:
			all_ok = false
			print("[t_godlab] FAIL NEXT #%d want %s got %s (wild %d) info '%s'" % [k, bodies[k], c.def.id if c else "-", wild.size(), line])
		else:
			print("[t_godlab] %s" % line)
		seen.append(c.def.id if c else &"")
	_expect(all_ok and seen == want, "NEXT cycles all %d modelled species (%d bodies), one aggressive model each" % [modelled.size(), bodies.size()])
	(panel.get_node("GodToggle") as Button).pressed.emit()
	_expect(not game.god_mode, "the GOD button turns it off")
	print("[t_godlab] %s" % ("PASS" if failures.is_empty() else "FAIL %d" % failures.size()))
	quit(0 if failures.is_empty() else 1)
