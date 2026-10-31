extends Node3D
## Island combat lab for M9a creature plates + tile AI/pathing checks. Headless it asserts:
## the survivor is alive at the 3.2 s acceptance-shot beat, and the lead raptor leaves a
## corpse whose loot reaches the bag; any failure exits 1.

var _player: Player
var _cam: IsoCamera
var _raptor_pack: Array[Creature] = []
var _herd: Array[Creature] = []
var _failed := false

func _ready() -> void:
	var kit := LabKit.build(self, 40.0)
	_player = kit["player"]
	_cam = kit["cam"]
	var nav: Node = kit["nav"]
	nav.visible = false
	# The 3.2 s acceptance beat must be one reproducible fight, not a roll of the day: combat
	# rolls go through CombatTuning.rng (survivor HP at the beat ranged 18-80 over six runs).
	CombatTuning.rng.seed = 20261018
	seed(20261018)  # brain jitter, spawn spread and other rolls use the global RNG
	Game.max_creatures_per_island = 0
	World.harvested.clear()
	World.load_island(self, &"temperate_25", Vector3(0, 1, 12), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	if Game.shot_path != "":
		TouchControls.visible = false
		TouchControls.enabled = false
	LabKit.give(_player, &"stone_knife", 1)
	LabKit.give(_player, &"bandage", 3)
	LabKit.give(_player, &"pressure_dressing", 1)
	print("[boot] lab=hunt_lab")
	call_deferred("_spawn_groups")

func _spawn_groups() -> void:
	if World.runtime == null:
		return
	var raptor_spawner := Spawner.new()
	raptor_spawner.species = &"velociraptor"
	# Two, not three: with three starter raptors a fresh survivor ended the 3.2 s beat at 9-74 HP
	# over five runs, so one crit killed him. The assertion below stays live either way.
	raptor_spawner.count = 2
	raptor_spawner.radius = 2.8
	raptor_spawner.as_pack = true
	raptor_spawner.position = Vector3(8.0, 0.0, 14.0)
	World.runtime.add_child(raptor_spawner)
	_raptor_pack = raptor_spawner.spawn_now()
	var herd_spawner := Spawner.new()
	herd_spawner.species = &"zebraceratops"
	herd_spawner.count = 3
	herd_spawner.radius = 2.6
	herd_spawner.as_pack = true
	herd_spawner.position = Vector3(16.0, 0.0, 18.0)
	World.runtime.add_child(herd_spawner)
	_herd = herd_spawner.spawn_now()
	for c in _raptor_pack + _herd:
		_starter_level(c)
	# Game takes the acceptance shot at 3.2 s; the survivor must not be dead in it (pc-lab-01).
	get_tree().create_timer(3.2).timeout.connect(func () -> void:
		print("[hunt_lab] survivor alive=%s hp=%.0f at 3.2 s" % [not _player.dead, _player.vitals.health])
		if _player.dead:
			_fail("survivor dead at the 3.2 s acceptance shot")
	, CONNECT_ONE_SHOT)
	get_tree().create_timer(0.45).timeout.connect(_demo, CONNECT_ONE_SHOT)

## The lab's island level offset made these raptors far above a fresh survivor, who died
## before the shot. Wild stats do not scale with level yet (creature.gd is W1-AI's), so a Lv1
## plate alone changed nothing: rebase each animal's stats to level 1 on the shared level curve.
# ASSUMPTION: species JSON stats are the animal at its tier level; level 1 is those stats /
# ProgressionScaling.level_multiplier(tier) (raptor 640 hp / 95 atk -> 219 / 33). Drop this when
# W1-AI scales wild stats by level.
func _starter_level(c: Creature) -> void:
	if c == null:
		return
	var d := c.def.duplicate() as CreatureDef  # never edit the shared species def
	var k := 1.0 / ProgressionScaling.level_multiplier(d.tier)
	d.hp *= k
	d.attack *= k
	d.defense *= k
	c.def = d
	c.level = 1
	c.genetics = CreatureGenetics.neutral()  # spawn rolled random IVs (a fresh, unseeded RNG)
	c.health.setup(c.stat_value(&"health"))

func _fail(msg: String) -> void:
	print("[hunt_lab] FAIL %s" % msg)
	_failed = true

func _quit_headless() -> void:
	if not _failed:
		print("[hunt_lab] PASS")
	get_tree().quit(1 if _failed else 0)

func _demo() -> void:
	if _raptor_pack.is_empty():
		return
	var lead := _raptor_pack[0]
	if lead == null:
		return
	_player.global_position = lead.global_position + Vector3(-3.0, 0.0, -1.2)
	if World.runtime:
		_player.global_position.y = World.runtime.surface_y(_player.global_position.x, _player.global_position.z) + 1.0
	_player.face_world(lead.global_position)
	_cam.size = 14.0 if Game.shot_path != "" else 17.0
	_cam._snap()
	# Status glyphs + plate reveal before combat states flip.
	lead.statuses.apply(&"bleed", _player)
	if _herd.size() > 0 and _herd[0]:
		_herd[0].statuses.apply(&"groggy", _player)
		_herd[0].brain.on_aggro(_player)
	_tap_creature(lead)
	_player.controls.selection.engage()  # spec 23: the tap selects, the swords start the fight
	_reveal_plates()
	# Let alert (0.6 s) resolve into approach / flee, then force a retreat chunk.
	get_tree().create_timer(0.85).timeout.connect(func () -> void:
		if lead == null or not is_instance_valid(lead):
			return
		lead.health.take_damage(lead.health.max_hp * 0.36, _player)
		get_tree().create_timer(0.25).timeout.connect(func () -> void:
			if lead and is_instance_valid(lead):
				lead.health.take_damage(22.0, _player)
		, CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)
	# Fresh hit shortly before Game's hunt_lab shot (3.2 s) so the white
	# recent-damage chunk is still animating in the acceptance screenshot.
	if Game.shot_path != "":
		get_tree().create_timer(2.55).timeout.connect(func () -> void:
			if lead and is_instance_valid(lead) and not lead.health.dead:
				lead.health.take_damage(18.0, _player)
				_reveal_plates()
		, CONNECT_ONE_SHOT)
		if Game.shot_path.contains("corpse"):
			get_tree().create_timer(1.0).timeout.connect(func () -> void: _corpse_probe(lead, false), CONNECT_ONE_SHOT)
		if Game.shot_path.contains("hud"):
			get_tree().create_timer(1.0).timeout.connect(func () -> void:
				if lead and is_instance_valid(lead) and _player.hunt:
					_player.hunt.hold = true
					_player.hunt.start(lead)
			, CONNECT_ONE_SHOT)
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		get_tree().create_timer(2.6).timeout.connect(func () -> void: _corpse_probe(lead, true), CONNECT_ONE_SHOT)

## Kill the lead raptor, then loot its body through the radial path (M8d Part C).
func _corpse_probe(lead: Creature, headless: bool) -> void:
	if lead == null or not is_instance_valid(lead):
		if headless:
			_fail("lead raptor gone before the corpse probe")
			_quit_headless()
		return
	lead.health.take_damage(99999.0, _player)
	await get_tree().create_timer(0.6).timeout
	var corpse: Corpse = null
	for n in get_tree().get_nodes_in_group("corpse"):
		corpse = n as Corpse
		if corpse:
			break
	if corpse == null:
		print("[item] no corpse spawned")
		if headless:
			_fail("no corpse")
			_quit_headless()
		return
	var dir := _player.global_position - corpse.global_position
	dir.y = 0.0
	if dir.length_squared() <= 0.001:
		dir = Vector3.FORWARD
	_player.global_position = corpse.global_position + dir.normalized() * 2.2
	if World.runtime and World.runtime.has_method("surface_y"):
		_player.global_position.y = World.runtime.surface_y(_player.global_position.x, _player.global_position.z) + 1.0
	_player.hunt.stop()
	if not headless:
		_cam._snap()
		_player._open_corpse_radial(corpse)
		return
	var opts := corpse.loot_options(_player.inventory)
	print("[item] corpse options=%d" % opts.size())
	if opts.is_empty():
		_fail("corpse has no loot")
		_quit_headless()
		return
	var loot_id: StringName = StringName(str(opts[0].get("item", "")))
	var had := _player.inventory.count_of(loot_id) if loot_id != &"" else -1
	_player._begin_corpse_take(corpse, int(opts[0]["slot"]))
	_player._on_arrived()
	await get_tree().create_timer(2.2).timeout
	if loot_id != &"" and _player.inventory.count_of(loot_id) <= had:
		_fail("loot %s never reached the bag" % loot_id)
	_quit_headless()

func _reveal_plates() -> void:
	if Game == null or not Game.has_method("reveal_creature_plate"):
		return
	for c in _raptor_pack:
		if c:
			Game.reveal_creature_plate(c, 5.0)
	for c in _herd:
		if c:
			Game.reveal_creature_plate(c, 5.0)

func _tap_creature(creature: Creature) -> void:
	var screen := _cam.unproject_position(creature.global_position + Vector3(0.0, creature.def.height_meters * 0.8, 0.0))
	_player.debug_tap_screen(screen)

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
