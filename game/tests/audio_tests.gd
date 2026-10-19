extends RefCounted
## Audio layer checks. run_all.gd calls run() once the autoloads exist.

const REQUIRED_BUSES := ["Master", "Music", "Ambience", "SFX", "Creatures", "UI"]
const NOT_SPECIES := ["ai.json", "anim_events.json"]

var failures: Array[String] = []

func run(tree: SceneTree) -> Array[String]:
	var raw := AudioDirector._read_json(AudioDirector.EVENTS_PATH)
	var events: Dictionary = raw.get("events", {})
	_expect(events.size() > 50, "audio: events.json has only %d events" % events.size())
	_test_voice_cap(tree, events)  # first: the file checks below give the mixer time to release the burst's voices
	_test_event_files(events)
	_test_species(events)
	_test_gather_and_steps(events)
	_test_credits(events)
	_test_buses()
	_test_music_hysteresis()
	_test_button_words()
	_test_near_field(events)
	_test_raptor_sources()
	_test_step_phase()
	_test_bus_defaults(tree)
	_test_beds_release(tree)
	_test_live(tree)
	return failures

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _test_event_files(events: Dictionary) -> void:
	for name in events:
		var files: Array = (events[name] as Dictionary).get("files", [])
		_expect(not files.is_empty(), "audio: %s has no files" % name)
		for f in files:
			_expect(str(f).ends_with(".ogg"), "audio: %s file %s is not .ogg" % [name, f])
			_expect(ResourceLoader.exists(AudioDirector.AUDIO_ROOT + str(f)), "audio: %s missing %s" % [name, f])
		_expect(str((events[name] as Dictionary).get("bus", "")) in REQUIRED_BUSES, "audio: %s bad bus" % name)

func _test_species(events: Dictionary) -> void:
	var voices := AudioDirector._read_json(AudioDirector.VOICES_PATH)
	var species: Dictionary = voices.get("species", {})
	var sets: Dictionary = voices.get("sets", {})
	var kinds: Array = voices.get("kinds", [])
	_expect(kinds.size() >= 5, "audio: creature voice kinds missing")
	for size in ["small", "medium", "large", "huge"]:
		for diet in ["herbivore", "carnivore"]:
			var found := false
			for s in sets:
				found = found or ((sets[s] as Dictionary).get("size") == size and (sets[s] as Dictionary).get("diet") == diet)
			_expect(found, "audio: no %s %s voice set" % [size, diet])
	var seen: Dictionary = {}
	var dir := DirAccess.open("res://data/creatures")
	for file in dir.get_files():
		if not file.ends_with(".json") or file in NOT_SPECIES:
			continue
		var d := AudioDirector._read_json("res://data/creatures/" + file)
		if not d.has("species"):
			continue
		var id := file.get_basename()
		var v: Dictionary = species.get(id, {})
		_expect(not v.is_empty(), "audio: species %s has no voice" % id)
		if v.is_empty():
			continue
		_expect(sets.has(str(v.get("set", ""))), "audio: species %s voice set %s unknown" % [id, v.get("set")])
		for kind in kinds:
			var ev := "cv_%s_%s_%s" % [v.get("set"), v.get("colour"), kind]
			_expect(events.has(ev), "audio: species %s missing event %s" % [id, ev])
		var key := "%s/%s/%.2f" % [v.get("set"), v.get("colour"), float(v.get("pitch", 1.0))]
		_expect(not seen.has(key), "audio: %s sounds identical to %s" % [id, seen.get(key, "")])
		seen[key] = id

func _test_gather_and_steps(events: Dictionary) -> void:
	var hooks := AudioHooks.new()
	var kinds: Array[StringName] = []
	for clip in PlayerAnim.GATHER_CLIPS:
		kinds.append(hooks.work_event(clip))
	kinds.append_array([&"gather_dig", &"gather_butcher", &"survivor_eat"])
	for ev in kinds:
		_expect(events.has(str(ev)) and ((events[str(ev)] as Dictionary).get("files", []) as Array).size() >= 3, "audio: gather %s needs 3+ variations" % ev)
	for ev in ["node_depleted_tree", "node_depleted_rock", "node_depleted_bush"]:
		_expect(events.has(ev), "audio: %s missing" % ev)
	for tile in range(11):
		for snowy in [false, true]:
			var ev := "step_%s" % AudioHooks.surface_for_tile(tile, snowy)
			_expect(events.has(ev) and ((events[ev] as Dictionary).get("files", []) as Array).size() >= 4, "audio: footstep %s needs 4+ variations" % ev)
	_expect(events.has("step_wood") and events.has("step_water"), "audio: wood/water footsteps missing")
	hooks.free()

func _ogg_files(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".ogg"):
			out.append((path + "/" + f).trim_prefix(AudioDirector.AUDIO_ROOT))
	for d in dir.get_directories():
		_ogg_files(path + "/" + d, out)

func _test_credits(events: Dictionary) -> void:
	var credits := AudioDirector._read_json("res://data/audio/credits.json")
	var files: Dictionary = credits.get("files", {})
	var allowed: Array = credits.get("allowed_licences", [])
	_expect(allowed.size() > 0 and allowed.all(func (l: String) -> bool: return l in ["CC0-1.0", "Public Domain"]), "audio: credits allow a licence outside CC0/PD")
	var shipped: Array[String] = []
	_ogg_files(AudioDirector.AUDIO_ROOT.trim_suffix("/"), shipped)
	_expect(shipped.size() > 100, "audio: only %d shipped .ogg files" % shipped.size())
	for f in shipped:
		var row: Dictionary = files.get(f, {})
		_expect(not row.is_empty(), "audio: %s not in credits.json" % f)
		var sources: Array = row.get("sources", [])
		_expect(not sources.is_empty(), "audio: %s has no sources" % f)
		for s in sources:
			var src: Dictionary = s
			_expect(str(src.get("licence", "")) in allowed, "audio: %s licence %s not allowed" % [f, src.get("licence")])
			_expect(str(src.get("url", "")).begins_with("https://") and str(src.get("author", "")) != "", "audio: %s source lacks url/author" % f)
			if src.get("collection") == "Wikimedia Commons":
				_expect(str(src.get("url")).begins_with("https://commons.wikimedia.org/wiki/File:") and str(src.get("download", "")).begins_with("https://upload.wikimedia.org/"),
					"audio: %s Commons credit needs the File: page (licence) and the download url" % f)
		# Vorbis and inter-sample peaks overshoot a sample-peak limiter; the build measures the .ogg itself.
		_expect(row.has("true_peak_db") and float(row.get("true_peak_db", 0.0)) <= -1.0, "audio: %s true peak %s dBTP is above -1" % [f, row.get("true_peak_db")])
	for name in events:
		for f in (events[name] as Dictionary).get("files", []):
			_expect(files.has(str(f)), "audio: %s file %s not credited" % [name, f])

func _test_buses() -> void:
	if AudioServer.get_bus_index(&"Music") < 0:
		AudioServer.set_bus_layout(load("res://default_bus_layout.tres") as AudioBusLayout)
	for b in REQUIRED_BUSES:
		var idx := AudioServer.get_bus_index(StringName(b))
		_expect(idx >= 0, "audio: bus %s missing" % b)
		if idx > 0:
			_expect(AudioServer.get_bus_send(idx) == &"Master", "audio: bus %s does not send to Master" % b)
	var limiter := false
	for i in AudioServer.get_bus_effect_count(0):
		limiter = limiter or AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter
	_expect(limiter, "audio: Master has no limiter")

func _test_music_hysteresis() -> void:
	var m := MusicState.new()
	var dt := 0.05
	for i in 40:
		m.update(dt, false, false)
	_expect(m.state == &"explore", "audio: calm day should be explore")
	var flicker_combat := false
	for i in 200:  # threat blinking 0.3 s on / 0.3 s off never starts combat
		m.update(dt, (i / 6) % 2 == 0, false)
		flicker_combat = flicker_combat or m.state == &"combat"
	_expect(not flicker_combat, "audio: a flickering threat started combat music")
	for i in 20:
		m.update(dt, true, false)
	_expect(m.state == &"combat", "audio: 1 s of threat should start combat")
	var dropped := false
	for i in 400:  # brief calm gaps between hits keep combat
		m.update(dt, i % 60 == 0, false)
		dropped = dropped or m.state != &"combat"
	_expect(not dropped, "audio: combat music dropped during short lulls")
	m.update(dt, true, false)  # last hit, then the calm countdown starts
	for i in 196:  # 9.8 s calm: still combat
		m.update(dt, false, true)
	_expect(m.state == &"combat", "audio: combat ended before the 10 s calm")
	for i in 10:
		m.update(dt, false, true)
	_expect(m.state == &"night", "audio: calm night after combat should be night, got %s" % m.state)
	m.update(dt, false, true, true)
	_expect(m.state == &"combat", "audio: taking damage should force combat")

func _test_button_words() -> void:
	var b := Button.new()
	for row in [["Close", &"ui_cancel"], ["Craft", &"ui_confirm"], ["BAG", &"ui_click"]]:
		b.text = row[0]
		_expect(AudioHooks.button_event(b) == row[1], "audio: button %s should play %s" % row)
	b.free()

func _test_voice_cap(tree: SceneTree, events: Dictionary) -> void:
	var d := AudioDirector.new()
	tree.root.add_child(d)
	d.beds.manual = true
	var one_shots: Array[StringName] = []
	for n in events:
		if not bool((events[n] as Dictionary).get("loop", false)):
			one_shots.append(StringName(n))
	var peak := 0
	var over := false
	for i in 500:
		var ev := one_shots[i % one_shots.size()]
		d._last_play.erase(ev)  # defeat cooldowns: this is a worst-case burst
		d.play(ev, Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)) if i % 3 else Vector3.INF)
		var active := d.active_voices()
		peak = maxi(peak, active)
		over = over or active > AudioDirector.VOICE_CAP or d.pool_size(true) > AudioDirector.POOL_3D or d.pool_size(false) > AudioDirector.POOL_2D
	_expect(not over, "audio: voice pool exceeded the cap (peak %d)" % peak)
	_expect(peak >= AudioDirector.VOICE_CAP - 4, "audio: burst never filled the pool (peak %d), cap untested" % peak)
	d.events["_burst"] = {"files": ["ui/click_01.ogg"], "bus": "SFX", "mode": "3d", "max_instances": 2, "cooldown": 0.0, "priority": 100, "max_distance": 40.0}
	for i in 20:
		d.play(&"_burst", Vector3.ZERO)
	var same := 0
	for v in d._voices:
		if v["event"] == &"_burst" and d._is_busy(v):
			same += 1
	_expect(same <= 2, "audio: per-event cap ignored (%d instances)" % same)
	for v in d._voices:
		d._stop(v)
	tree.root.remove_child(d)
	d.free()

## Godot's AudioStreamPlayer3D inverse-distance gain: volume_db is added first, then clamped to max_db.
static func _att_db(unit: float, dist: float, vol: float) -> float:
	return minf(linear_to_db(unit / dist) + vol, AudioDirector.MAX_DB)

## Next to the survivor the clamp must not swallow the event table: walk steps play 2 dB under run
## steps and a strong hit adds impact_bone at -4 dB, so an event at its table level must sit at or
## under max_db and 2 dB less must still be 2 dB less at the ear.
func _test_near_field(events: Dictionary) -> void:
	_expect(AudioDirector.MAX_DB <= 0.0, "audio: 3D voices may boost above file level (no limiter on web)")
	for ev in ["step_dirt", "step_sand", "step_water", "survivor_hurt", "swing_light", "impact_flesh_medium", "impact_bone", "armour_hit", "gather_chop"]:
		var e: Dictionary = events.get(ev, {})
		var u := float(e.get("unit_size", 8.0))
		var v := float(e.get("volume_db", 0.0))
		var near := _att_db(u, AudioDirector.LISTENER_HEIGHT, v)
		_expect(near - _att_db(u, AudioDirector.LISTENER_HEIGHT, v - 2.0) > 1.9, "audio: %s is pinned at max_db at the survivor, its volume_db does nothing" % ev)

## Raptors must not be the smilodon's cat recordings: no raptor variation may lead with a source the
## cat set uses at all, or with a BigSoundBank domestic-cat recording.
func _test_raptor_sources() -> void:
	var files: Dictionary = AudioDirector._read_json("res://data/audio/credits.json").get("files", {})
	var cat_urls := {}
	for f in files:
		if str(f).begins_with("creatures/mammal_cat/"):
			for src in (files[f] as Dictionary).get("sources", []):
				cat_urls[str((src as Dictionary).get("url"))] = true
	var raptor := 0
	for f in files:
		if not str(f).begins_with("creatures/carn_medium/"):
			continue
		raptor += 1
		var lead := str((files[f] as Dictionary).get("lead", ""))
		_expect(lead != "" and not cat_urls.has(lead), "audio: %s leads with a smilodon source %s" % [f, lead])
		_expect(not ("cat-roar" in lead or "growling-cat" in lead), "audio: %s leads with a domestic cat %s" % [f, lead])
	_expect(raptor >= 13, "audio: carn_medium voice files missing (%d)" % raptor)

func _test_step_phase() -> void:
	_expect(AudioHooks.step_crossed(0.2, 0.3, [0.28]), "audio: a foot strike inside one frame was missed")
	_expect(AudioHooks.step_crossed(0.95, 0.05, [0.02]), "audio: a foot strike across the loop point was missed")
	_expect(not AudioHooks.step_crossed(0.3, 0.7, [0.28, 0.76]), "audio: a step fired between foot strikes")
	var n := 0
	var ph := 0.0
	for i in 640:  # walk.glb is 1.067 s: ten cycles at 60 fps are twenty foot strikes
		var nxt := fmod(ph + (1.0 / 60.0) / 1.0667, 1.0)
		if AudioHooks.step_crossed(ph, nxt, AudioHooks.STEP_PHASES[&"walk"]):
			n += 1
		ph = nxt
	_expect(n == 20, "audio: walk cadence gave %d steps in ten cycles, feet land 20 times" % n)

## The settings volume scales the designed level, so making the director again must not compound it.
func _test_bus_defaults(tree: SceneTree) -> void:
	if AudioServer.get_bus_index(&"Music") < 0:
		AudioServer.set_bus_layout(load("res://default_bus_layout.tres") as AudioBusLayout)
	_expect(is_equal_approx(AudioDirector.designed_bus_db(&"Music"), -7.0), "audio: designed Music level not read from the bus layout")
	for i in 3:
		var d := AudioDirector.new()
		tree.root.add_child(d)
		d.beds.manual = true
		d.set_bus_volume(&"SFX", 0.5)
		tree.root.remove_child(d)
		d.free()
	var d2 := AudioDirector.new()
	tree.root.add_child(d2)
	var want := AudioDirector.designed_bus_db(&"SFX") + linear_to_db(0.5)
	var got := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX"))
	_expect(absf(got - want) < 0.05, "audio: recreating the director compounded SFX to %.1f dB (want %.1f)" % [got, want])
	d2.set_bus_volume(&"SFX", 1.0)
	tree.root.remove_child(d2)
	d2.free()

func _test_beds_release(tree: SceneTree) -> void:
	var d := AudioDirector.new()
	tree.root.add_child(d)
	d.beds.manual = true
	d.beds.preview(&"shore", &"amb_shore", 1.0, 0.1)
	for i in 4:
		d.beds._fade(0.05)
	var layer: Node = (d.beds._layers.get(&"shore", {}) as Dictionary).get("player")
	_expect(layer != null, "audio test: shore bed never started")
	d.beds.preview(&"shore", &"amb_shore", 0.0, 0.1)
	for i in 4:
		d.beds._fade(0.05)
	_expect(not d.beds._layers.has(&"shore") and layer != null and layer.is_queued_for_deletion(), "audio: a faded-out bed slot is kept playing at -80 dB")
	tree.root.remove_child(d)
	d.free()

func _plays(d: AudioDirector, evs: Array) -> int:
	var n := 0
	for ev in evs:
		n += int(d.played_count.get(StringName(ev), 0))
	return n

## The hooks against a real survivor and raptor: DoT ticks stay silent, landed hits and crits sound on
## the right body, footsteps follow the playing clip, and creature state is dropped on despawn.
func _test_live(tree: SceneTree) -> void:
	var d := AudioDirector.new()
	tree.root.add_child(d)
	d.beds.manual = true
	var p := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	tree.root.add_child(p)
	_expect(d.hooks.player == p, "audio test: hooks did not pick up the survivor")
	d._place_listener()
	_expect(is_equal_approx(d.listener.global_position.y, p.global_position.y + AudioDirector.LISTENER_HEIGHT), "audio: listener not at LISTENER_HEIGHT over the survivor")
	p.in_water = true  # no physics frames run here, so stand in for the floor check
	for row in [[&"walk", false, 5.5], [&"run", true, 7.0]]:
		p.velocity = Vector3(float(row[2]), 0.0, 0.0)
		p.anim.play_locomotion(float(row[2]), bool(row[1]))
		var ap := p.anim.rig.anim_player
		_expect(StringName(ap.current_animation) == row[0], "audio test: survivor is not playing %s" % row[0])
		var cycle := ap.current_animation_length / maxf(0.01, ap.speed_scale)
		var s0 := _plays(d, ["step_water"])
		var t := 0.0
		while t < cycle * 4.0 - 0.001:
			ap.advance(1.0 / 60.0)
			d._last_play.erase(&"step_water")
			d.hooks._tick_steps(1.0 / 60.0)
			t += 1.0 / 60.0
		var n := _plays(d, ["step_water"]) - s0
		_expect(absi(n - 8) <= 1, "audio: %s gave %d footsteps over four cycles, the feet land 8 times" % [row[0], n])
	p.in_water = false
	p.velocity = Vector3.ZERO
	var hurt := ["survivor_hurt", "impact_flesh_medium", "armour_hit"]
	var h0 := _plays(d, hurt)
	p.statuses.apply(&"stomachache", p)
	for i in 6:
		p.statuses._process(0.5)
	_expect(p.vitals.health < p.vitals.effective_max_health(), "audio test: stomachache did no damage, so the check proves nothing")
	_expect(_plays(d, hurt) == h0 and not d.hooks._force_combat, "audio: a stomachache tick played hit sounds or forced combat music")
	p.take_hit_fx(8.0, false)
	_expect(_plays(d, ["survivor_hurt"]) > 0, "audio: a landed hit on the survivor is silent")
	_expect(d.hooks.consume_force_combat(), "audio: a landed hit should force combat music")

	var c := (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate() as Creature
	tree.root.add_child(c)
	c.spawn(tree.root.get_node("Data").creature(&"velociraptor"))
	var impacts := ["impact_flesh_small", "impact_flesh_medium", "impact_hide_large", "impact_hide_huge", "impact_crit"]
	d._last_play.clear()
	var i0 := _plays(d, impacts)
	c.statuses.apply(&"bleeding_target", p)
	for i in 4:
		c.statuses._process(0.5)
	_expect(c.health.hp < c.health.max_hp, "audio test: bleed did no damage, so the check proves nothing")
	_expect(_plays(d, impacts) == i0 and not d.hooks._force_combat, "audio: a bleed tick on a creature played an impact or forced combat music")
	c.statuses.clear_id(&"bleeding_target")
	d._last_play.clear()
	c.last_damaged_s = -999.0
	var flesh0 := _plays(d, ["impact_flesh_medium"])
	var crit0 := _plays(d, ["impact_crit"])
	c.combat_float.emit(12.0, &"crit")  # what creature_attack emits on the attacker when it crits the survivor
	_expect(_plays(d, ["impact_flesh_medium"]) == flesh0, "audio: a raptor critting the survivor played a hit on the raptor")
	_expect(_plays(d, ["impact_crit"]) == crit0 + 1, "audio: the survivor's crit crunch did not play")
	d._last_play.clear()
	var hit0 := _plays(d, impacts)
	c.health.take_damage(5.0, p)
	_expect(_plays(d, impacts) > hit0 and d.hooks.consume_force_combat(), "audio: a direct hit on a creature is silent")
	var id := c.get_instance_id()
	_expect(d.hooks._cstate.has(id), "audio test: creature state was never created")
	tree.root.remove_child(c)
	_expect(not d.hooks._cstate.has(id), "audio: a despawned creature's state was kept")
	c.free()

	tree.root.remove_child(p)
	p.queue_free()
	for v in d._voices:
		d._stop(v)
	tree.root.remove_child(d)
	d.free()
