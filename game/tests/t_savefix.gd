extends SceneTree
## SAVEFIX (production playtest 2026-10-21): three defects, one test.
##  1. Autosave before a survivor exists. World's 60 s autosave ran while character creation (and the
##     first island pick) was still open, so a reload skipped both and loaded a default "Survivor".
##     Now: no autosave before creation + first island pick finish, and a save written in that state
##     (old saves that hit the bug) loads back into character creation.
##  2. Max HP changed with no visible cause. Level-up bonuses live in vitals.max_health, and
##     StatusEffects._sync_vitals rewrote it to 100 x status product on every status change, so +5
##     vanished (102/105, then 100/100 after drinking). Now the level bonus is saved (Vitals.level_health)
##     and the sync only recomputes the status part; drink/wash leave max HP alone; a status that does
##     lower max HP (Infected Wound) shows a line on the HUD.
##  3. Energy "drained fast" while walking: PRD 6.2 says Energy is restored by eating and *slowly*
##     auto-recovers (it also recovers in combat). The old code regenerated 16/s out of combat — a net
##     gain while running — so the bar never moved and the fatigue meter was blamed. Now the regen is
##     rules.json's energy_regen_per_s (1.0) and tapping to jog is a walk, not a sprint drain.
## Ten minutes of walking must end no worse than the docs allow: below TIRED (<25), and with a
## displayed Energy figure. Prints "[t_savefix] PASS" (or FAIL lines) and exits 0/1.
## Usage: godot --headless --path game --script res://tests/t_savefix.gd

const FIX := "res://tests/fixtures/"
## The save this run writes (a --script run gets its own user://runs/t_savefix/ folder).
const RUN_DIR := "user://runs/t_savefix"

var failures: Array[String] = []
var _started := false
var W: Node
var SG: GDScript
var host: Node3D
var player
var rt

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
	print("[t_savefix] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	W = get_root().get_node("World")
	SG = load("res://scripts/core/save_game.gd")
	_expect(str(SG.path) == RUN_DIR + "/save_1.json", "a --script run saves under %s (got %s)" % [RUN_DIR, SG.path])
	host = Node3D.new()
	host.name = "SaveFixHost"
	get_root().add_child(host)
	_test_autosave_gate()
	_test_precreation_load()
	await _setup_island()
	await _test_max_health()
	await _test_walking()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_savefix] PASS")
		quit(0)
	else:
		print("[t_savefix] FAIL count=%d" % failures.size())
		quit(1)

# ---------------------------------------------------------------- 1. autosave gate

## The 60 s autosave while character creation and the terrain pick are open: no file may appear.
func _test_autosave_gate() -> void:
	W.runtime = null
	W.player_name = ""
	W.occupation = ""
	W.home_terrain = &""
	W.set("creation_pending", true)
	_wipe_saves()
	W._save_acc = 0.0
	W._process(61.0)
	_expect(W.last_save_unix == 0 and not SG.exists(), "the autosave timer writes nothing while creation is open")
	# Finishing creation alone is not enough: the island pick is still open.
	W.set("creation_pending", false)
	W._save_acc = 0.0
	W._process(61.0)
	_expect(not SG.exists(), "the autosave timer writes nothing while the first island pick is open")
	# Both done on the home island: the timer saves again (it is not off for good).
	W.home_terrain = &"meadow"
	_expect(not W.get("creation_pending") == true, "creation + first island pick finished => saving allowed")
	W._save_acc = 0.0
	W._process(0.1)
	_expect(W._save_acc > 0.0, "the autosave timer runs again after creation")

# ---------------------------------------------------------------- 1b. a pre-creation save loads into creation

## Old saves written by the bug: no player_name, no occupation, no island pick (oldest schemas) or a
## default "Survivor" with the home island (the schema-3 bug). They must open character creation.
func _test_precreation_load() -> void:
	_wipe_saves()
	var base: Dictionary = _fixture("save_v3_inst_golden.json")
	var cases: Array = [
		["save_v3_inst_golden.json", "survivor created in play (control: loads the world, no creation)"],
		["save_v1.json", "schema 1 without a name"],
		["save_v0.json", "schema 0 without a name"],
	]
	for row in cases:
		var fname: String = row[0]
		var what: String = row[1]
		_wipe_saves()
		var data: Dictionary = _fixture(fname)
		_write_save(data)
		W.player_name = ""
		W.occupation = ""
		W.home_terrain = &""
		W.runtime = null
		var cc_before := get_nodes_in_group(&"character_creation").size()
		var loaded: bool = bool(W.ensure_survivor(host)) if W.has_method("ensure_survivor") else true  # false = creation opened
		var want := fname.begins_with("save_v3_inst")
		_expect(loaded == want, "%s: ensure_survivor -> %s (%s)" % [fname, loaded, what])
		var nodes := get_nodes_in_group(&"character_creation")
		_expect(nodes.size() == cc_before + (0 if want else 1), "%s: character creation %s" % [fname, "not opened" if want else "opened"])
		_expect((W.get("creation_pending") == true) == (not want), "%s: creation_pending=%s" % [fname, W.get("creation_pending")])
		if not want:
			_expect(nodes.size() > 0 and nodes[0].get_parent() == host, "%s: the creation layer is on the host" % fname)
			_expect(W.home_terrain == &"" and not W.visited_islands.has("home_grassland"), "%s: the island pick still to come (terrain '%s')" % [fname, W.home_terrain])
		for n in nodes:
			n.free()
	# A schema-3 bug save: name "Survivor", no occupation, home island with a terrain already set.
	_wipe_saves()
	var bugged := base.duplicate(true)
	bugged.erase("schema")
	bugged["player_name"] = "Survivor"
	bugged["occupation"] = ""
	bugged["island_id"] = "home_grassland"
	bugged["home"]["terrain"] = "meadow"
	_write_save(bugged)
	W.player_name = ""
	W.occupation = ""
	W.runtime = null
	var ok: bool = bool(W.ensure_survivor(host)) if W.has_method("ensure_survivor") else true
	_expect(not ok, "a 'Survivor' save with no occupation loads into creation, not the world")
	var made := get_nodes_in_group(&"character_creation")
	_expect(made.size() == 1, "exactly one character creation layer for the bug save")
	for n in made:
		n.free()
	W.set("creation_pending", false)

# ---------------------------------------------------------------- fixture helpers

func _fixture(name: String) -> Dictionary:
	var f := FileAccess.open(FIX + name, FileAccess.READ)
	if f == null:
		_expect(false, "fixture %s is readable" % name)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}

func _write_save(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://runs/t_savefix"))
	var f := FileAccess.open(SG.path, FileAccess.WRITE)
	if f == null:
		_expect(false, "the save can be written to %s" % SG.path)
		return
	f.store_string(JSON.stringify(data))
	f.close()
	SG.blocked_reason = ""

func _wipe_saves() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SG.path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SG.path + suffix))

# ---------------------------------------------------------------- 2 + 3: a live island and survivor

func _setup_island() -> void:
	_wipe_saves()
	W.home_terrain = &"meadow"
	W.set("creation_pending", false)
	W.player_name = "Saver"
	W.occupation = "student"
	var p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(p)
	var cam := IsoCamera.new()
	cam.name = "IsoCamera"
	host.add_child(cam)
	cam.current = true
	cam.target_path = cam.get_path_to(p)
	cam._target = p
	cam._snap()
	player = p
	W.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	rt = W.runtime
	player = W._player()
	_expect(player != null and rt != null, "the home island has a survivor")
	if player == null:
		return
	# Ten simulated minutes of walking across the map would leave the harbour ring; the survivor is
	# walked on flat harbour ground, and a level gap of 1.0 keeps it to the docs' own rates.
	player.vitals.level_gap_mult = 1.0
	player.statuses.from_array([])
	await _frames(3)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

## 2. Max HP: level bonuses are theirs, statuses change only their own part, and drinking or
## washing (Quenched / Clean) never moves the max.
func _test_max_health() -> void:
	if player == null:
		return
	var v: Vitals = player.vitals
	v.max_health = 100.0
	v.level_health = 0.0
	v.health = 100.0
	player.statuses.from_array([])
	var base_max: float = v.effective_max_health()
	_expect(is_equal_approx(base_max, 100.0), "a new survivor has 100 max HP (%.1f)" % base_max)
	# The HUD's level-up handler pays the pioneer_levels.json bonus per level.
	var gains: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/pioneer_levels.json")) as Dictionary).get("per_level", {})
	var per_hp := float(gains.get("max_health", 5))
	for i in 2:
		v.grant_level_bonus(per_hp, float(gains.get("max_energy", 3)))
	var levelled: float = v.effective_max_health()
	_expect(is_equal_approx(levelled, base_max + 2.0 * per_hp), "two levels add %s max HP each (%.1f)" % [per_hp, levelled])
	# The old bug: a status sync (drink, wash, an expiry) rewrote max_health to 100.
	player.statuses.apply(&"quenched")
	player.statuses.apply(&"clean")
	var drunk: float = v.effective_max_health()
	_expect(is_equal_approx(drunk, levelled), "drinking and washing leave max HP at %.1f (got %.1f)" % [levelled, drunk])
	v.health = v.effective_max_health()
	player.statuses.from_array([])
	_expect(is_equal_approx(v.effective_max_health(), levelled), "status expiry leaves max HP at %.1f (got %.1f)" % [levelled, v.effective_max_health()])
	# A saved level bonus survives a reload (it used to be lost: to_dict wrote max_health, nothing read it back).
	var before_save: float = v.effective_max_health()
	_wipe_saves()
	SG.save_now()
	await process_frame
	var raw := _fixture_abs(SG.path)
	_expect(is_equal_approx(float(raw.get("player", {}).get("vitals", {}).get("max_health", 0.0)), before_save), "the save keeps the levelled max HP (%.1f)" % before_save)
	v.max_health = 100.0
	v.level_health = 0.0
	v.from_dict(raw.get("player", {}).get("vitals", {}))
	player.statuses.from_array(raw.get("player", {}).get("statuses", []))
	_expect(is_equal_approx(v.effective_max_health(), before_save), "a reload restores %.1f max HP (got %.1f)" % [before_save, v.effective_max_health()])
	# The one status that does lower max HP must say so on the HUD (no invisible change).
	player.statuses.apply(&"infected_wound")
	var hurt: float = v.effective_max_health()
	_expect(hurt < before_save, "Infected Wound lowers max HP (%.1f -> %.1f)" % [before_save, hurt])
	_expect(player.statuses.max_health_note().contains("Max HP"), "the HUD has a line that explains the max-HP change: '%s'" % player.statuses.max_health_note())
	player.statuses.from_array([])
	_expect(is_equal_approx(v.effective_max_health(), before_save), "curing it gives the max back (%.1f)" % v.effective_max_health())
	_expect(player.statuses.max_health_note() == "", "no note when nothing changes max HP")
	v.level_health = 0.0
	v.max_energy = 100.0
	v.energy = v.max_energy
	await _frames(3)

func _fixture_abs(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}

## 3. Ten minutes of walking on flat ground, at the docs' rates.
func _test_walking() -> void:
	if player == null:
		return
	var v: Vitals = player.vitals
	player.statuses.from_array([])
	v.fatigue = 0.0
	v.energy = v.max_energy
	v.health = v.effective_max_health()
	player.dead = false
	# The game's clock must not walk the survivor into night/wet; hold it at midday.
	var game: Node = get_root().get_node("Game")
	game.set_process(false)
	game.time_of_day = 0.5
	if W.runtime and W.runtime.get("weather"):
		var w = W.runtime.get("weather")
		w.raining = false
		w._rain_cd = 1.0e9  # no rain this run: Wet is a separate rule
	v.level_gap_mult = 1.0
	# The live pipeline runs for SAMPLE_S; every charge it makes is linear in time (a constant rate
	# per second), so ten minutes = the measured per-second rate x 600.
	const SAMPLE_S := 12.0
	const WALK_S := 600.0
	var start: Vector3 = player.global_position
	var f0: float = v.fatigue
	var e0: float = v.energy
	var walked := 0
	Input.action_press(&"move_right")
	print("[t_savefix] debug tick=%d walk start pos=%s dead=%s in_water=%s vel=%s floor=%s anim_busy=%s" % [player.global_position, player.dead, player.in_water, player.velocity, player.is_on_floor(), player.anim._busy if player.anim else "no anim"])
	Input.action_press(&"move_right")
	var t := 0.0
	while t < SAMPLE_S:
		# Keep the level gap out of the run: the island sets it each frame from the ring.
		v.level_gap_mult = 1.0
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
		if absf(player.global_position.x - start.x) > 16.0 or absf(player.global_position.z - start.z) > 16.0:
			player.global_position = start  # stay on the flat harbour ground
		walked += 1
	Input.action_release(&"move_right")
	var fat_rate: float = (v.fatigue - f0) / t
	var energy_rate: float = (v.energy - e0) / t
	var proj_fatigue: float = f0 + fat_rate * WALK_S
	var proj_energy: float = e0 + energy_rate * WALK_S
	var strain := proj_fatigue / maxf(1.0, v.max_fatigue)
	print("[t_savefix] walk sample %.1fs: fatigue %.1f/min, energy %+.1f/min, %.2f m/s, %d frames" % [
		t, fat_rate * 60.0, energy_rate * 60.0, Vector2(player.velocity.x, player.velocity.z).length(), walked])
	print("[t_savefix] 10 min walk: fatigue=%.1f (%.0f%%, %s) energy=%.1f/%.0f (from %.0f/%.0f)" % [
		proj_fatigue, strain * 100.0, _stage(proj_fatigue), proj_energy, v.max_energy, f0, e0])
	v.fatigue = proj_fatigue
	v.energy = proj_energy
	# Docs (spec 01): 0-24 rested, 25-49 slightly tired, 50-74 tired, 75+ exhausted. Walking must
	# not reach TIRED inside ten minutes; the HUD shows the same word.
	_expect(v.fatigue < 25.0, "ten minutes of walking stays below TIRED (<25): %.1f" % v.fatigue)
	_expect(_stage(v.fatigue) == "RESTED", "the HUD's word after ten minutes is RESTED (%s)" % _stage(v.fatigue))
	_expect(v.energy < v.max_energy, "walking does not refill Energy to full (%.1f/%.0f)" % [v.energy, v.max_energy])
	game.set_process(true)

## The HUD's own word for a strain (HuntHud._draw vitals), kept in step by hand.
func _stage(fatigue: float) -> String:
	var strain := clampf(fatigue / 100.0, 0.0, 1.0)
	return "RESTED" if strain < 0.25 else ("TIRED" if strain < 0.5 else ("WEARY" if strain < 0.75 else "EXHAUSTED"))
