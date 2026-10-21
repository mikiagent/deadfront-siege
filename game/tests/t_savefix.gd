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
##  3. Fatigue rose too fast (the "energy drain": 67/103, 69/106, 65/100 are 0.65 x max, the stamina
##     cap at fatigue 50-74 % — spec 01 keeps stamina's rapid regen). A status's fatigue_per_min was
##     charged x100 (Wet alone: 30/min, and in rain it never stopped), so the log blamed the rain;
##     Wet now adds no fatigue of its own (PRD :284: it changes climate fatigue only) and every
##     fatigue_per_min is charged on the 0-100 scale.
## Ten minutes of walking must end no worse than the docs allow (below TIRED, and the stamina cap
## whole), and no status may charge 100x its data rate: the playtest's 67/103 was the stamina cap at
## fatigue 50-74 %, not a regen bug. Prints "[t_savefix] PASS" (or FAIL lines) and exits 0/1.
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
	await _test_autosave_gate()
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
	# A real survivor is in the scene (the boot Player): on the old code the 60 s autosave wrote him
	# out mid-creation, which is exactly the bug.
	var p: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(p)
	W.runtime = null
	W.player_name = ""
	W.occupation = ""
	W.home_terrain = &""
	W.set("creation_pending", true)
	_wipe_saves()
	W._save_acc = 0.0
	W._process(61.0)
	_expect(W.last_save_unix == 0 and not SG.exists(), "the autosave timer writes nothing while creation is open")
	_expect(not SG.save_now() and not SG.exists(), "a save asked for during creation is refused too")
	# The terrain pick is still open: same gate.
	W._save_acc = 0.0
	W._process(61.0)
	_expect(not SG.exists(), "the autosave timer writes nothing while the first island pick is open")
	# The pick's own panel keeps coming back until one is chosen (WorldUI._process): a survivor made
	# this session cannot reach the world without picking, so nothing exists to save either way.
	var ui = (load("res://scripts/ui/world_ui.gd") as GDScript).instance_on(host)
	await _frames(3)
	_expect(ui != null and str(ui.get("_mode")) == "terrain" and ui.get("_panel").visible, "the island pick is on screen while creation has not finished (mode '%s')" % [ui.get("_mode") if ui else "-"])
	_expect(not SG.exists(), "nothing was saved while the pick was on screen")
	# Both done on the home island: the timer ticks again and a save is allowed (it is not off for good).
	W.home_terrain = &"meadow"
	var can_finish: bool = W.has_method("finish_creation")
	_expect(can_finish, "World.finish_creation exists (creation and the pick are done)")
	if can_finish:
		W.finish_creation()
	W._save_acc = 0.0
	W._process(61.0)
	_expect(W.last_save_unix > 0 and SG.exists(), "after creation + island pick the autosave writes the world")

# ---------------------------------------------------------------- 1b. a pre-creation save loads into creation

## Old saves written by the bug: no player_name, no occupation, no island pick (oldest schemas) or a
## default "Survivor" with the home island (the schema-3 bug). They must open character creation.
func _test_precreation_load() -> void:
	_wipe_saves()
	var base: Dictionary = _fixture("save_v3_inst_golden.json")
	var cases: Array = [
		["save_v3_inst_golden.json", "survivor created in play (control: loads the world, no creation)"],
		["save_v1.json", "schema 1 without a name (a real old save: it loads)"],
		["save_v0.json", "schema 0 without a name (a real old save: it loads)"],
	]
	var has_gate: bool = W.has_method("ensure_survivor") and W.get("creation_pending") != null
	_expect(has_gate, "World.ensure_survivor exists (boot asks whether a survivor exists)")
	if not has_gate:
		return
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
		var want := true  # every real fixture has a survivor: only the bug save below opens creation
		_expect(loaded == want, "%s: ensure_survivor -> %s (%s)" % [fname, loaded, what])
		var nodes := get_nodes_in_group(&"character_creation")
		_expect(nodes.size() == cc_before + (0 if want else 1), "%s: character creation %s" % [fname, "not opened" if want else "opened"])
		_expect((W.get("creation_pending") == true) == (not want), "%s: creation_pending=%s (a loaded survivor may save)" % [fname, W.get("creation_pending")])
		if not want:
			_expect(nodes.size() > 0 and nodes[0].get_parent() == host, "%s: the creation layer is on the host" % fname)
			_expect(W.home_terrain == &"" and not W.visited_islands.has("home_grassland"), "%s: the island pick still to come (terrain '%s')" % [fname, W.home_terrain])
		for n in nodes:
			n.free()
	# A schema-3 bug save: name "Survivor", no occupation, home island with a terrain already set.
	_wipe_saves()
	var bugged := base.duplicate(true)
	bugged["schema"] = 3
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
	# A reload of a world made this session (the bug path): an old-schema save put back after a new
	# game leaves the flag up -> nothing would ever save again. A real save clears it.
	_wipe_saves()
	_write_save(_fixture("save_v1.json"))
	var reloaded: bool = W.ensure_survivor(host)
	_expect(reloaded and bool(W.get("creation_pending")) == false, "a real old save also lifts the 'creation pending' flag (would block every later save)")
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
	var keeps_levels: bool = v.has_method("grant_level_bonus") and v.get("level_health") != null
	_expect(keeps_levels, "Vitals keeps the level-up bonus apart from statuses (level_health)")
	v.max_health = 100.0
	if keeps_levels:
		v.set("level_health", 0.0)
	v.health = 100.0
	player.statuses.from_array([])
	var base_max: float = v.effective_max_health()
	_expect(is_equal_approx(base_max, 100.0), "a new survivor has 100 max HP (%.1f)" % base_max)
	# The HUD's level-up handler pays the pioneer_levels.json bonus per level.
	var gains: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/pioneer_levels.json")) as Dictionary).get("per_level", {})
	var per_hp := float(gains.get("max_health", 5))
	for i in 2:
		if keeps_levels:
			v.grant_level_bonus(per_hp, float(gains.get("max_energy", 3)))
		else:
			v.max_health += per_hp
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
	if keeps_levels:
		v.set("level_health", 0.0)
	v.from_dict(raw.get("player", {}).get("vitals", {}))
	player.statuses.from_array(raw.get("player", {}).get("statuses", []))
	_expect(is_equal_approx(v.effective_max_health(), before_save), "a reload restores %.1f max HP (got %.1f)" % [before_save, v.effective_max_health()])
	# The one status that does lower max HP must say so on the HUD (no invisible change).
	player.statuses.apply(&"infected_wound")
	var hurt: float = v.effective_max_health()
	_expect(hurt < before_save, "Infected Wound lowers max HP (%.1f -> %.1f)" % [before_save, hurt])
	var has_note: bool = player.statuses.has_method("max_health_note")
	var note: String = str(player.statuses.max_health_note()) if has_note else ""
	_expect(has_note and note.contains("max HP"), "the HUD has a line that explains the max-HP change: '%s'" % note)
	player.statuses.from_array([])
	_expect(is_equal_approx(v.effective_max_health(), before_save), "curing it gives the max back (%.1f)" % v.effective_max_health())
	_expect(has_note and str(player.statuses.max_health_note()) == "", "no note when nothing changes max HP")
	if keeps_levels:
		v.set("level_health", 0.0)
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
	var t := 0.0
	# The survivor walks on flat harbour ground: no climate charge (home is grass with no resist), no
	# level gap, no rain. The walk's fatigue rate is what is measured.
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
	var proj_fatigue: float = f0 + fat_rate * WALK_S
	var strain := proj_fatigue / maxf(1.0, v.max_fatigue)
	var stamina_end: float = v.energy
	print("[t_savefix] walk sample %.1fs: fatigue %.1f/min, stamina %.0f -> %.0f, %.2f m/s, %d frames" % [
		t, fat_rate * 60.0, e0, stamina_end, Vector2(player.velocity.x, player.velocity.z).length(), walked])
	print("[t_savefix] 10 min walk: fatigue=%.1f (%.0f%%, %s)" % [
		proj_fatigue, strain * 100.0, _stage(proj_fatigue)])
	# Docs (spec 01): 0-24 rested, 25-49 slightly tired, 50-74 tired, 75-99 exhausted. Ten minutes
	# of walking must not reach the docs' "tired" (50) and the HUD must show the docs' word.
	_expect(proj_fatigue < 50.0, "ten minutes of walking stays below tired (<50): %.1f" % proj_fatigue)
	_expect(_stage(proj_fatigue) != "TIRED" and _stage(proj_fatigue) != "EXHAUSTED", "the HUD's word after ten minutes is at most WORN (%s)" % _stage(proj_fatigue))
	# Spec 01: stamina regens rapidly (16/s calm); what lowers its cap is fatigue's own stage. Ten
	# minutes of walking at the docs' rate may reach "slightly tired" (25-49, cap 0.85) but not
	# "tired" (50, cap 0.65) — the playtest's 67/103.
	var cap_at_end: float = v.max_energy * v.stamina_cap_mult()
	var cap_frac := cap_at_end / maxf(1.0, v.max_energy)
	print("[t_savefix] after ten minutes the stamina cap is %.0f/%.0f (x%.2f)" % [cap_at_end, v.max_energy, cap_frac])
	_expect(cap_frac >= 0.85, "ten minutes of walking leaves the stamina cap at slightly-tired or better (x%.2f, not the playtest's x0.65)" % cap_frac)
	# The playtest's 67/103, 69/106, 65/100 are 0.65 x max: stamina_cap_mult() at fatigue 50-74 %.
	# Spec 01 keeps stamina's rapid regen (STAMINA_REGEN_CALM 16/s out of combat), so the bar was
	# capped because FATIGUE rose too fast. Rain on, and the fatigue log says who charged.
	v.set_process(false)
	v.fatigue = 0.0
	v.fatigue_log.clear()
	var weather = W.runtime.get("weather")
	weather.raining = true
	weather._rain_left = 600.0
	var rain_t := 0.0
	Input.action_press(&"move_right")
	while rain_t < 20.0:
		await physics_frame
		rain_t += 1.0 / float(Engine.physics_ticks_per_second)
	Input.action_release(&"move_right")
	weather.raining = false
	weather._rain_cd = 1.0e9
	var wet_on: bool = player.statuses.has(&"wet")
	var log_rows: Dictionary = v.fatigue_log.duplicate()
	print("[t_savefix] 20 s in rain: wet=%s fatigue %.1f -> %.1f (%.1f/min) log=%s" % [wet_on, 0.0, v.fatigue, v.fatigue / rain_t * 60.0, log_rows])
	_expect(wet_on, "20 s in the rain gives Wet")
	var wet_charge := float(log_rows.get("wet", 0.0))
	_expect(wet_charge < 0.5, "Wet adds (almost) no fatigue of its own, %.2f in %.0f s (PRD :284: Wet changes climate fatigue)" % [wet_charge, rain_t])
	# The rate a status can charge is on the 0-100 fatigue scale: a 0.5/min status costs at most
	# 0.5 x the 0.5 accumulation multiplier in a minute, not 100x that (the wet bug was x100).
	v.fatigue = 0.0
	v.fatigue_log.clear()
	player.statuses.apply(&"tastes_bad")
	player.statuses.set_process(false)  # the status clock is stepped by hand: 120 ticks = one minute
	var bad := 0.0
	for i in 120:
		var before_tick: float = v.fatigue
		player.statuses._process(0.5)
		bad += v.fatigue - before_tick
	print("[t_savefix] Tastes Bad one minute: fatigue +%.2f (data 0.5/min x the 0.5 accumulation)" % bad)
	_expect(bad > 0.0 and bad <= 0.6, "a fatigue_per_min status charges its data rate on the 0-100 scale (+%.2f/min, data 0.5; the wet bug paid x100)" % bad)
	player.statuses.clear_id(&"tastes_bad")
	player.statuses.from_array([])
	v.set_process(true)
	game.set_process(true)

## The HUD's own word for a strain (HuntHud._draw vitals), kept in step by hand.
func _stage(fatigue: float) -> String:
	var strain := clampf(fatigue / 100.0, 0.0, 1.0)
	return "RESTED" if strain < 0.25 else ("WORN" if strain < 0.5 else ("TIRED" if strain < 0.75 else "EXHAUSTED"))
