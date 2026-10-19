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
