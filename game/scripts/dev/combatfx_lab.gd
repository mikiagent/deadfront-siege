extends Node3D
## COMBATFX lab (spec 24, damage numbers): the survivor fights a Stegosaurus on a temperate island and
## every beat goes through the real hit path: Hunt.land_hit for melee, Hunt.fire_ranged (the
## slingshot's StoneProjectile, the shot a bow will use; there is no bow item yet) and
## CreatureAttack._deal_damage for the stego's bite on the survivor.
##   beats: hit (stone knife), big (raid maul, over a tenth of its HP), crit (knife crit), bow, bow_crit,
##          taken, taken_crit, flurry (10 hits/s), then the crit at ages 0.03-0.65 s (seq_*)
## Headless: Godot --headless --path game res://scenes/dev/combatfx_lab.tscn -- --lab=combatfx_lab
##   prints "[combatfx] beat=... tier=... text=..." per beat and "[combatfx] PASS" (exit 0) or FAIL (exit 1)
## Shots: Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility]
##   res://scenes/dev/combatfx_lab.tscn -- --lab=combatfx_lab --shot-dir=DIR   (also 844x390)
##   saves <beat>_<w>x<h>.png with the numbers frozen at the beat's age.
## --species=<id> stages the beats on another creature (default stegosaurus).
## Perf: add --fx=stress: 3 s phases (no hits, 10 hits/s with numbers, 10 hits/s numbers off), frame times.
## Runs on the base too (no CombatFx then: the shots are the old numbers, the check fails).

## Iso yaw 45 deg: screen right and screen up on the ground.
const RIGHT := Vector3(0.70710678, 0, -0.70710678)
const UP := Vector3(-0.70710678, 0, -0.70710678)
## Staged HP (the reference plate reads 2689 at Lv. 20): a knife hit is ~1 %, the maul ~11 %.
const STEGO_HP := 1500.0

var _player: Player
var _cam: IsoCamera
var _stego: Creature
var _out := ""
var _mode := "check"
var _species := &"stegosaurus"
var _fails: Array[String] = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--fx="):
			_mode = a.substr(5)
		elif a.begins_with("--species="):
			_species = StringName(a.substr(10))  # shots against another body while a model is broken
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	DisplayMode.install(get_tree().root)  # the game's canvas fit (main.gd): 1:1 on a 844x390 phone
	DisplayMode.install_theme()
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	_cam = kit["cam"]
	CombatTuning.rng.seed = 20261021
	seed(20261021)
	Game.max_creatures_per_island = 0
	World.harvested.clear()
	World.load_island(self, &"temperate_25", Vector3(0, 1, 12), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	if _out != "":
		TouchControls.visible = false
		TouchControls.enabled = false
	for id in [&"stone_knife", &"raid_maul", &"slingshot"]:
		LabKit.give(_player, id, 1)
	LabKit.give(_player, &"stone_shot", 60)
	_player.vitals.max_health = 1000.0  # the stego's bites must not end the lab
	_player.vitals.health = 1000.0
	print("[boot] lab=combatfx_lab mode=%s" % _mode)
	_run.call_deferred()

func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout

## CombatFx when the build has it (untyped: the lab also runs on the base, which has none).
func _fx() -> Object:
	return Game.creature_ui.get("fx") if is_instance_valid(Game.creature_ui) else null

func _run() -> void:
	await _secs(0.8)
	Game.time_of_day = 0.45  # midday light
	var spawner := Spawner.new()
	spawner.species = _species
	spawner.count = 1
	spawner.position = _player.global_position - RIGHT * 16.0 + UP * 4.0  # open meadow, clear of the camp
	World.runtime.add_child(spawner)
	_stego = spawner.spawn_now()[0]
	_stego.brain.process_mode = Node.PROCESS_MODE_DISABLED
	_stego.look_at(_stego.global_position - RIGHT, Vector3.UP)  # side-on, head toward the survivor
	var d := _stego.def.duplicate() as CreatureDef
	d.defense = 0.0  # staged so the numbers read like the reference's
	_stego.def = d
	_stego.level = 20
	_stego.health.setup(STEGO_HP)
	CombatTuning.force_accuracy = 1.0
	CombatTuning.force_dodge = 0.0
	_place(false)
	await _secs(0.8)
	_player.hunt.start(_stego)
	_player.hunt.auto = false
	_player.hunt.hold = true
	print("[combatfx] %s hp=%.0f survivor hp=%.0f renderer=%s view=%s" % [_species, _stego.health.max_hp, _player.vitals.max_health,
		RenderingServer.get_current_rendering_method(), get_viewport().get_visible_rect().size])
	if _mode == "stress":
		await _stress()
		return
	await _beat("hit", func () -> void: await _swing(&"stone_knife", false), _stego, "normal")
	await _beat("big", func () -> void: await _swing(&"raid_maul", false), _stego, "big")
	await _beat("crit", func () -> void: await _swing(&"stone_knife", true), _stego, "crit")
	_place(true)
	await _secs(0.4)
	await _beat("bow", func () -> void: await _shoot(false), _stego, "normal")
	await _beat("bow_crit", func () -> void: await _shoot(true), _stego, "crit")
	_place(false)
	await _secs(0.4)
	await _beat("taken", func () -> void: _bite(false), _player, "")
	await _beat("taken_crit", func () -> void: _bite(true), _player, "crit")
	await _flurry()
	for age in [0.03, 0.08, 0.2, 0.35, 0.5, 0.65]:
		await _beat("seq_%03d" % int(round(age * 1000.0)), func () -> void: await _swing(&"stone_knife", true), _stego, "crit", age)
	CombatTuning.reset_overrides()
	if _fails.is_empty():
		print("[combatfx] PASS")
		get_tree().quit(0)
	else:
		print("[combatfx] FAIL count=%d %s" % [_fails.size(), _fails])
		get_tree().quit(1)

## Melee beats stand the survivor at the stego's flank; ranged ones ~11 m off, zoomed out for both.
func _place(ranged: bool) -> void:
	var c := _stego.global_position
	var at := c - RIGHT * 11.0 - UP * 1.0 if ranged else c - UP * 3.2 - RIGHT * 2.0
	at.y = World.runtime.surface_y(at.x, at.z) + 1.0
	_player.global_position = at
	_player.reset_physics_interpolation()
	_player.face_world(c)
	_player.inventory.equip(&"weapon", &"slingshot" if ranged else &"stone_knife")
	_cam.size = 26.0 if ranged else 20.0
	_cam._snap()

## Survivor crits come from data (crit_base 1.0 always, -1.0 never), on the base too.
func _player_crits(on: bool) -> void:
	CombatTuning.section("player_melee")["crit_base"] = 1.0 if on else -1.0
	CombatTuning.section("ranged")["crit_base"] = 1.0 if on else -1.0

func _swing(id: StringName, crit: bool) -> void:
	_player_crits(crit)
	_player.inventory.equip(&"weapon", id)
	var w := _player.inventory.equipped_weapon()
	_player.face_world(_stego.global_position)
	_player.play_attack(id == &"raid_maul")
	await _secs(Hunt.hit_delay(w))
	_stego.health.hp = _stego.health.max_hp
	_player.hunt.land_hit(_stego, w)

func _shoot(crit: bool) -> void:
	_player_crits(crit)
	_stego.health.hp = _stego.health.max_hp
	for i in 30:  # the swing cooldown or the attack clip may still hold the trigger
		if _player.hunt.fire_ranged():
			return
		await _secs(0.1)
	print("[combatfx] fire_ranged refused: %s" % _player.hunt.last_notice)

## The stego's bite on the survivor; the combat RNG is seeded so its crit roll lands or not.
func _bite(crit: bool) -> void:
	_player.vitals.health = _player.vitals.max_health
	var chance := _stego.crit_chance()
	for s in 100000:
		CombatTuning.rng.seed = s
		CombatTuning.rng.randf()
		if (CombatTuning.rng.randf() < chance) == crit:
			CombatTuning.rng.seed = s
			break
	CreatureAttack._deal_damage(_stego, _player)

## Runs one beat, waits for its number, freezes it at `age` for the shot, and checks its tier.
func _beat(name: String, act: Callable, anchor: Node3D, want_tier: String, age: float = 0.15) -> void:
	var fx := _fx()
	for r in _stego.statuses.to_array():  # a status tick's number is not the beat's hit
		_stego.statuses.clear_id(StringName(str(r["id"])))
	await act.call()
	var f := {}
	var waited := 0.0
	while waited < 2.5:
		f = _newest(anchor)  # the last beat's numbers are gone, so any is this beat's
		if not f.is_empty():
			break
		await get_tree().process_frame
		waited += get_process_delta_time()
	if fx and not f.is_empty():
		while float(f["age"]) < age:
			await get_tree().process_frame
	elif fx == null:
		await _secs(age)  # the base: no ages to read, so time it
	var tier := str(f.get("tier", "none"))
	var ok := fx != null and not f.is_empty() and (want_tier == "" or tier == want_tier)
	print("[combatfx] beat=%s tier=%s text=%s age=%.3f %s" % [name, tier, f.get("text", "?"), float(f.get("age", -1.0)), "ok" if ok else "FAIL"])
	if not ok:
		_fails.append(name)
	if _out != "":
		if fx:
			fx.process_mode = Node.PROCESS_MODE_DISABLED
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
		img.save_png(path)
		print("[combatfx] shot %s" % path)
		if fx:
			fx.process_mode = Node.PROCESS_MODE_INHERIT
	await _secs(0.9)  # every number of this beat is gone before the next

func _newest(anchor: Node3D) -> Dictionary:
	var fx := _fx()
	if fx == null:
		return {"text": "(base: no CombatFx)"} if anchor == _player or _stego.health.hp < _stego.health.max_hp else {}
	for i in range(fx.floats.size() - 1, -1, -1):
		var f: Dictionary = fx.floats[i]
		if int(f["target"]) == anchor.get_instance_id() and str(f["kind"]) in ["hit", "weak", "strong", "crit"]:
			return f  # a bleed tick or a status word is not the beat's hit
	return {}

## Ten knife hits a second for 1.2 s, one crit in five, then the shot.
func _flurry() -> void:
	var fx := _fx()
	_player.inventory.equip(&"weapon", &"stone_knife")
	for i in 12:
		_player_crits(i % 5 == 2)
		_stego.health.hp = _stego.health.max_hp
		_player.hunt.land_hit(_stego, _player.inventory.equipped_weapon())
		await _secs(0.1)
	var readable := 0
	if fx:
		for f in fx.floats:
			readable += 1 if int(f["target"]) == _stego.get_instance_id() and fx.alpha_at(f, float(f["age"])) >= 0.3 else 0
	print("[combatfx] beat=flurry live=%d readable=%d" % [fx.floats.size() if fx else -1, readable])
	if _out != "":
		if fx:
			fx.process_mode = Node.PROCESS_MODE_DISABLED
		await RenderingServer.frame_post_draw
		var path := _out.path_join("flurry_%dx%d.png" % [get_tree().root.size.x, get_tree().root.size.y])
		get_viewport().get_texture().get_image().save_png(path)
		print("[combatfx] shot %s" % path)
		if fx:
			fx.process_mode = Node.PROCESS_MODE_INHERIT
	await _secs(0.9)

## Frame cost: 3 s phases, vsync off. The hit work (flash, burst, plate) runs in both hit phases, so
## their difference is the numbers' own cost.
func _stress() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await _secs(1.0)
	var fx := _fx()
	# gl_compatibility compiles the hit's particle shaders on first use: warm them up so the hitch
	# does not land in the first measured hit phase.
	await _phase("warm-up", true)
	await _phase("no hits", false)
	await _phase("10 hits/s", true)
	if fx:
		fx.process_mode = Node.PROCESS_MODE_DISABLED
		fx.visible = false
		fx.floats.clear()
	await _phase("10 hits/s fx off", true)
	print("[combatfx] stress done")
	get_tree().quit(0)

func _phase(label: String, hits: bool) -> void:
	var vp := get_viewport().get_viewport_rid()
	var frames: Array[float] = []
	var gpu := 0.0
	var cpu := 0.0
	var t := 0.0
	var next := 0.0
	var n := 0
	var spawn_max := 0
	while t < 3.0:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		frames.append(dt * 1000.0)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		if hits and t >= next:
			next += 0.1
			_player_crits(n % 5 == 0)
			_stego.health.hp = _stego.health.max_hp
			var t0 := Time.get_ticks_usec()
			_player.hunt.land_hit(_stego, _player.inventory.equipped_weapon())
			spawn_max = maxi(spawn_max, Time.get_ticks_usec() - t0)
			n += 1
	frames.sort()
	var avg := 0.0
	for ms in frames:
		avg += ms
	avg /= maxf(1.0, float(frames.size()))
	var k := maxf(1.0, float(frames.size()))
	print("[combatfx] perf %-17s frames=%d avg=%.2f ms p95=%.2f ms max=%.2f ms render_cpu=%.2f ms render_gpu=%.2f ms hits=%d hit_call_max=%d us" % [
		label, frames.size(), avg, frames[int(frames.size() * 0.95)], frames[-1], cpu / k, gpu / k, n, spawn_max])
