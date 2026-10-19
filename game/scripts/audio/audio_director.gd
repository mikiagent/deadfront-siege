class_name AudioDirector
extends Node
## Every sound in the game goes through play(event): data/audio/events.json picks the files,
## bus, pitch range, 2D/3D, per-event instance cap and cooldown; a pooled voice manager holds
## the global cap. Lives at Game.audio (made on first use, no autoload). AudioBeds runs the
## ambience and music; AudioHooks turns game signals into events.

const EVENTS_PATH := "res://data/audio/events.json"
const VOICES_PATH := "res://data/audio/creature_voices.json"
const AUDIO_ROOT := "res://assets/audio/"
## Simultaneous one-shot voices across 2D and 3D. Loops (beds, music, fires) are not counted.
const VOICE_CAP := 32
const POOL_2D := 12
const POOL_3D := 32
const BUSES: Array[StringName] = [&"Master", &"Music", &"Ambience", &"SFX", &"Creatures", &"UI"]
## The iso camera sits 40 m from the survivor (IsoCamera.distance), so the camera is a poor ear:
## everything on screen would sound equally far. The listener rides on the survivor instead,
## turned like the camera so screen-left is ear-left; this softens the side-to-side pan.
const PANNING := 0.55

var events: Dictionary = {}
var ambience_cfg: Dictionary = {}
var music_cfg: Dictionary = {}
var creature_voices: Dictionary = {}
var listener: AudioListener3D
var beds: AudioBeds
var hooks: AudioHooks
## event -> plays since start (audio lab coverage).
var played_count: Dictionary = {}
## -- --audio-log prints every event that gets a voice: the only way an agent can "hear" a run.
var log_events: bool = "--audio-log" in OS.get_cmdline_user_args()

var _voices: Array[Dictionary] = []  # {node, is3d, event, prio, t, follow}
var _last_play: Dictionary = {}       # event -> msec
var _last_file: Dictionary = {}       # event -> index, so a variation never repeats twice in a row
var _streams: Dictionary = {}         # path -> AudioStream (one-shots; loops load on demand)
var _bus_default_db: Dictionary = {}
var _warned: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_tables()
	_init_buses()
	listener = AudioListener3D.new()
	listener.name = "Listener"
	add_child(listener)
	listener.make_current()
	beds = AudioBeds.new()
	beds.name = "Beds"
	beds.director = self
	add_child(beds)
	hooks = AudioHooks.new()
	hooks.name = "Hooks"
	hooks.director = self
	add_child(hooks)
	print("[audio] director ready events=%d species=%d" % [events.size(), (creature_voices.get("species", {}) as Dictionary).size()])

func _load_tables() -> void:
	var raw: Dictionary = _read_json(EVENTS_PATH)
	events = raw.get("events", {})
	ambience_cfg = raw.get("ambience", {})
	music_cfg = raw.get("music", {})
	creature_voices = _read_json(VOICES_PATH)

static func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("[audio] missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

# ---------------------------------------------------------------- buses + settings

func _init_buses() -> void:
	for bus in BUSES:
		var idx := AudioServer.get_bus_index(bus)
		if idx < 0:
			push_warning("[audio] bus %s missing from default_bus_layout.tres" % bus)
			continue
		_bus_default_db[bus] = AudioServer.get_bus_volume_db(idx)
		_apply_bus(bus, bus_volume(bus))

## linear 0..1 scales the bus around its designed mix level (1.0 = the default layout volume).
## Persisted in user://settings.cfg for the settings screen.
func set_bus_volume(bus: StringName, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_apply_bus(bus, linear)
	Settings.set_value("audio", str(bus), linear)

func bus_volume(bus: StringName) -> float:
	return clampf(float(Settings.get_value("audio", str(bus), 1.0)), 0.0, 1.0)

func _apply_bus(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, float(_bus_default_db.get(bus, 0.0)) + linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)

## Weather layer for the beds: kind rain | storm | wind | snow | sandstorm | ash_storm | clear,
## intensity 0..1. &"auto" hands control back to the island's own rain.
func set_weather(kind: StringName, intensity: float = 1.0) -> void:
	if beds:
		beds.set_weather(kind, intensity)

# ---------------------------------------------------------------- events

## Play a sound event. at = Vector3.INF plays it 2D. params: pitch (multiplier), volume_db (added),
## delay (seconds), follow (Node3D the voice tracks while it plays). Returns the voice or null.
func play(event: StringName, at: Vector3 = Vector3.INF, params: Dictionary = {}) -> Node:
	var e: Dictionary = events.get(event, {})
	if e.is_empty():
		if not _warned.has(event):
			_warned[event] = true
			push_warning("[audio] unknown event %s" % event)
		return null
	var now := Time.get_ticks_msec()
	var cd := int(float(e.get("cooldown", 0.0)) * 1000.0)
	if cd > 0 and now - int(_last_play.get(event, -1000000)) < cd:
		return null
	var is3d := str(e.get("mode", "2d")) == "3d" and at != Vector3.INF
	if is3d and listener and listener.global_position.distance_to(at) > float(e.get("max_distance", 40.0)) * 1.05:
		return null  # out of earshot: never spend a voice on it
	_last_play[event] = now
	var delay := float(params.get("delay", 0.0))
	if delay > 0.0 and is_inside_tree():
		get_tree().create_timer(delay).timeout.connect(func () -> void: _start(event, e, at, is3d, params))
		return null
	return _start(event, e, at, is3d, params)

func _start(event: StringName, e: Dictionary, at: Vector3, is3d: bool, params: Dictionary) -> Node:
	var stream := _pick_stream(event, e)
	if stream == null:
		return null
	var v := _acquire(event, e, is3d)
	if v.is_empty():
		return null
	var p: Node = v["node"]
	var pr: Array = e.get("pitch", [1.0, 1.0])
	var pitch := randf_range(float(pr[0]), float(pr[1])) * float(params.get("pitch", 1.0))
	var vol := float(e.get("volume_db", 0.0)) + float(params.get("volume_db", 0.0))
	if is3d:
		var p3 := p as AudioStreamPlayer3D
		p3.stream = stream
		p3.bus = StringName(str(e.get("bus", "SFX")))
		p3.volume_db = vol
		p3.pitch_scale = clampf(pitch, 0.25, 4.0)
		p3.unit_size = float(e.get("unit_size", 8.0))
		p3.max_distance = float(e.get("max_distance", 40.0))
		p3.global_position = at
		p3.play()
	else:
		var p2 := p as AudioStreamPlayer
		p2.stream = stream
		p2.bus = StringName(str(e.get("bus", "UI")))
		p2.volume_db = vol
		p2.pitch_scale = clampf(pitch, 0.25, 4.0)
		p2.play()
	v["event"] = event
	v["prio"] = int(e.get("priority", 50))
	v["t"] = Time.get_ticks_msec()
	v["follow"] = params.get("follow", null)
	played_count[event] = int(played_count.get(event, 0)) + 1
	if log_events:
		print("[audio] play %s%s pitch=%.2f" % [event, (" at %.1f,%.1f,%.1f" % [at.x, at.y, at.z]) if is3d else "", pitch])
	return p

func _pick_stream(event: StringName, e: Dictionary) -> AudioStream:
	var files: Array = e.get("files", [])
	if files.is_empty():
		return null
	var i := randi() % files.size()
	if files.size() > 1 and i == int(_last_file.get(event, -1)):
		i = (i + 1 + randi() % (files.size() - 1)) % files.size()
	_last_file[event] = i
	return load_stream(str(files[i]), bool(e.get("loop", false)), bool(e.get("loop", false)))

## rel is relative to res://assets/audio/. Loops are not kept in the one-shot cache so a bed or
## track that stops playing can be freed (web sample playback keeps decoded PCM per stream).
func load_stream(rel: String, looped: bool = false, uncached: bool = false) -> AudioStream:
	var path := AUDIO_ROOT + rel
	if not uncached and _streams.has(path):
		return _streams[path]
	if not ResourceLoader.exists(path):
		if not _warned.has(path):
			_warned[path] = true
			push_warning("[audio] missing file %s" % path)
		return null
	# Uncached loads bypass the resource cache so a bed or track is truly gone once it fades.
	var s := (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) if uncached else load(path)) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = looped
	if not uncached and s:
		_streams[path] = s
	return s

# ---------------------------------------------------------------- voice pool

func _is_busy(v: Dictionary) -> bool:
	var n: Node = v["node"]
	return n.playing if n is AudioStreamPlayer3D or n is AudioStreamPlayer else false

func active_voices() -> int:
	var n := 0
	for v in _voices:
		if _is_busy(v):
			n += 1
	return n

func pool_size(is3d: bool) -> int:
	var n := 0
	for v in _voices:
		if bool(v["is3d"]) == is3d:
			n += 1
	return n

## Free voice of the right kind, else steal: the oldest instance of the same event when that
## event is at its own cap, otherwise the oldest lowest-priority voice not above the new one.
func _acquire(event: StringName, e: Dictionary, is3d: bool) -> Dictionary:
	var prio := int(e.get("priority", 50))
	var max_inst := maxi(1, int(e.get("max_instances", 4)))
	var same: Array[Dictionary] = []
	var free: Dictionary = {}
	var busy := 0
	for v in _voices:
		if _is_busy(v):
			busy += 1
			if v["event"] == event:
				same.append(v)
		elif free.is_empty() and bool(v["is3d"]) == is3d:
			free = v
	if same.size() >= max_inst:
		var oldest := same[0]
		for v in same:
			if int(v["t"]) < int(oldest["t"]):
				oldest = v
		if bool(oldest["is3d"]) == is3d:
			_stop(oldest)
			return oldest
		_stop(oldest)
		busy -= 1
	if busy < VOICE_CAP:
		if not free.is_empty():
			return free
		if pool_size(is3d) < (POOL_3D if is3d else POOL_2D):
			return _new_voice(is3d)
	var victim: Dictionary = {}
	for v in _voices:
		if not _is_busy(v) or int(v["prio"]) > prio:
			continue
		if victim.is_empty() or int(v["prio"]) < int(victim["prio"]) or (int(v["prio"]) == int(victim["prio"]) and int(v["t"]) < int(victim["t"])):
			victim = v
	if victim.is_empty():
		return {}
	_stop(victim)
	if bool(victim["is3d"]) == is3d:
		return victim
	for v in _voices:  # the victim was the other kind: its slot frees a voice of ours
		if not _is_busy(v) and bool(v["is3d"]) == is3d:
			return v
	if pool_size(is3d) < (POOL_3D if is3d else POOL_2D):
		return _new_voice(is3d)
	return {}

func _stop(v: Dictionary) -> void:
	var n: Node = v["node"]
	if n is AudioStreamPlayer3D:
		(n as AudioStreamPlayer3D).stop()
	elif n is AudioStreamPlayer:
		(n as AudioStreamPlayer).stop()
	v["follow"] = null

func _new_voice(is3d: bool) -> Dictionary:
	var n: Node
	if is3d:
		var p3 := AudioStreamPlayer3D.new()
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.panning_strength = PANNING
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p3.max_db = 3.0
		n = p3
	else:
		n = AudioStreamPlayer.new()
	n.name = "Voice%d" % _voices.size()
	add_child(n)
	var v := {"node": n, "is3d": is3d, "event": &"", "prio": 0, "t": 0, "follow": null}
	_voices.append(v)
	return v

## A looping 3D emitter owned by `host` (a campfire); freed with it, outside the voice cap.
func attach_loop(event: StringName, host: Node3D, offset: Vector3 = Vector3(0, 0.6, 0)) -> AudioStreamPlayer3D:
	var e: Dictionary = events.get(event, {})
	var files: Array = e.get("files", [])
	if files.is_empty() or host == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = "AudioLoop"
	p.stream = load_stream(str(files[0]), true)
	p.bus = StringName(str(e.get("bus", "Ambience")))
	p.volume_db = float(e.get("volume_db", 0.0))
	p.unit_size = float(e.get("unit_size", 3.0))
	p.max_distance = float(e.get("max_distance", 18.0))
	p.panning_strength = PANNING
	p.position = offset
	p.autoplay = true
	host.add_child(p)
	return p

# ---------------------------------------------------------------- creatures

func creature_voice(species: StringName) -> Dictionary:
	var sp: Dictionary = creature_voices.get("species", {})
	return sp.get(str(species), {})

func creature_size(species: StringName) -> StringName:
	var v := creature_voice(species)
	var sets: Dictionary = creature_voices.get("sets", {})
	return StringName(str((sets.get(str(v.get("set", "")), {}) as Dictionary).get("size", "medium")))

func creature_event(species: StringName, kind: StringName) -> StringName:
	var v := creature_voice(species)
	if v.is_empty():
		return &""
	return StringName("cv_%s_%s_%s" % [v.get("set", ""), v.get("colour", "neutral"), kind])

## kind: idle | alert | attack | hurt | death. pitch multiplies the species pitch.
func play_creature(c: Node3D, species: StringName, kind: StringName, pitch: float = 1.0) -> Node:
	var ev := creature_event(species, kind)
	if ev == &"" or c == null:
		return null
	var p := {"pitch": float(creature_voice(species).get("pitch", 1.0)) * pitch, "follow": c}
	return play(ev, c.global_position + Vector3.UP, p)

# ---------------------------------------------------------------- per frame

## Stop explicitly on quit: a voice still playing at exit pins its stream in the AudioServer (leak report).
func _exit_tree() -> void:
	for v in _voices:
		_stop(v)

func _process(_delta: float) -> void:
	_place_listener()
	for v in _voices:
		var f: Variant = v["follow"]
		if f == null:
			continue
		if not is_instance_valid(f) or not _is_busy(v):
			v["follow"] = null
			continue
		(v["node"] as AudioStreamPlayer3D).global_position = (f as Node3D).global_position + Vector3.UP

func _place_listener() -> void:
	if listener == null:
		return
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var p := hooks.player if hooks else null
	if p and is_instance_valid(p) and p.is_inside_tree():
		var basis := cam.global_basis if cam else Basis()
		listener.global_transform = Transform3D(basis, p.global_position + Vector3.UP * 1.2)
	elif cam:
		listener.global_transform = cam.global_transform
