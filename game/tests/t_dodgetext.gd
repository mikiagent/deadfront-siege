extends SceneTree
## DODGETEXT acceptance (owner 2026-10-28: "add a dodge damage number for players and enemies where it
## says like "Dodged" or "Blocked" ... the agro range circle ... remove it but keep it in debug mode"):
##   a bite inside the roll's i-frames deals no damage and floats "Dodged" over the survivor; a block
##   floats "Blocked" over her; a survivor swing a creature dodges deals no damage and floats "Dodged"
##   over its plate, a block "Blocked"; the aggro ring is hidden with the debug overlay off and shown
##   with it on. Every avoided hit goes through CombatAvoid.avoided.
## Usage: godot --headless --path game --script res://tests/t_dodgetext.gd -> "[t_dodgetext] PASS".
## Windowed with `-- --shot-dir=<dir>` it also saves dodged.png (the survivor's "Dodged" float).

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var _game: Node
var CA: GDScript
var CT: GDScript
var AV: GDScript

var _watch := 0.0

func _process(delta: float) -> bool:
	if _started:
		_watch += delta
		if _watch > 90.0:
			print("[t_dodgetext] FAIL watchdog")
			quit(1)
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_dodgetext] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _creature(species: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	_host.add_child(c)
	c.spawn(root.get_node("Data").creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _player_texts() -> Array:
	return (_hud.get("_events").player_floats as Array).map(func (e: Dictionary) -> String: return str(e.get("txt", "")))

func _plate_texts(plates: Node, c) -> Array:
	var entry: Dictionary = plates.get("_entries").get(c.get_instance_id(), {})
	var layer := entry.get("floats", null) as Control
	return [] if layer == null else layer.get_children().map(func (l: Node) -> String: return (l as Label).text)

func _run() -> void:
	CA = load("res://scripts/combat/creature_attack.gd")
	CT = load("res://scripts/combat/combat_tuning.gd")
	AV = load("res://scripts/combat/combat_avoid.gd")
	_game = root.get_node("Game")
	_game.debug_overlay = false
	_host = Node3D.new()
	_host.name = "TDodgeTextHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 40.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("avoid_on_player"):
			_hud = c
	var plates: Node = (load("res://scripts/ui/creature_plates.gd") as GDScript).new()
	_host.add_child(plates)
	await _frames(20)
	_player.vitals.max_health = 1000.0
	_player.vitals.health = 1000.0
	var raptor = _creature(&"velociraptor", Vector3(0, 0, -1.6))
	await _frames(5)

	# 1. Survivor: a bite inside the roll's i-frames.
	CT.force_accuracy = 1.0
	CT.force_dodge = 0.0
	var hp0: float = _player.vitals.health
	_player.vitals.energy = _player.vitals.max_energy
	_player.sim.try_roll(Vector3(0, 0, 1))
	for i in 60:
		if _player.sim.roll_elapsed() >= 0.1:
			break
		await physics_frame
	print("[t_dodgetext] roll elapsed=%.2f invulnerable=%s rolling=%s" % [_player.sim.roll_elapsed(), _player.sim.roll_invulnerable(), _player.rolling])
	var landed: bool = CA.apply_for(raptor, &"attack_primary", _player)
	_expect(not landed and is_equal_approx(_player.vitals.health, hp0), "a bite inside the roll's i-frames deals no damage")
	_expect(_player_texts().has("Dodged"), "and floats \"Dodged\" over the survivor (%s)" % [_player_texts()])
	var shot_dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			shot_dir = a.substr(11)
	if shot_dir != "" and DisplayServer.get_name() != "headless":
		await _frames(8)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(shot_dir)
		root.get_texture().get_image().save_png(shot_dir.path_join("dodged.png"))
		print("[t_dodgetext] shot %s" % shot_dir.path_join("dodged.png"))
	AV.avoided(_player, raptor, &"block")
	_expect(_player_texts().has("Blocked"), "a block floats \"Blocked\" over the survivor")
	var f: Dictionary = (_hud.get("_events").player_floats as Array).back()
	_expect(int(f.get("px", 22)) < 22, "the avoid text is smaller than a damage number (%d px)" % int(f.get("px", 22)))

	# 2. Creature: the survivor's swing it dodges.
	plates.reveal_creature(raptor, 30.0)
	CT.force_accuracy = 0.0
	var chp: float = raptor.health.hp
	var hit: bool = _player.hunt.land_hit(raptor, null)
	_expect(not hit and is_equal_approx(raptor.health.hp, chp), "a swing the creature dodges deals no damage")
	_expect(_plate_texts(plates, raptor).has("Dodged"), "and floats \"Dodged\" over its plate (%s)" % [_plate_texts(plates, raptor)])
	AV.avoided(raptor, _player, &"block")
	_expect(_plate_texts(plates, raptor).has("Blocked"), "a creature block floats \"Blocked\" over its plate")
	CT.force_accuracy = -1.0
	CT.force_dodge = -1.0

	# 3. Aggro ring: debug overlay only.
	raptor.brain.attack_target = _player
	raptor.brain.state = &"attack"
	raptor._update_aggro_ring(1.0)
	var ring = raptor.get("_aggro_ring")
	_expect(ring == null or not ring.visible, "the aggro ring is hidden with the debug overlay off")
	_game.debug_overlay = true
	raptor._update_aggro_ring(1.0)
	ring = raptor.get("_aggro_ring")
	_expect(ring != null and ring.visible, "the aggro ring shows with the debug overlay on")
	_game.debug_overlay = false
	raptor._update_aggro_ring(1.0)
	_expect(not ring.visible, "and hides again when the overlay is turned off")

	print("[t_dodgetext] %s" % ("PASS" if _fails.is_empty() else "FAIL %s" % [_fails]))
	quit(0 if _fails.is_empty() else 1)
