class_name AudioBeds
extends Node
## Looping layers that crossfade instead of cutting: the climate bed (day/night), shore surf by
## distance to the sea, the weather layer, and the music score driven by MusicState.

const BED_FADE_S := 6.0
const MUSIC_IN_S := 3.0
const COMBAT_IN_S := 1.2
const MUSIC_OUT_S := 4.0
const FIRST_TRACK_S := 3.0
const TRACK_GAP_S := Vector2(40.0, 90.0)  # silence between calm tracks so the score breathes

var director: AudioDirector
var music := MusicState.new()
## Labs drive the slots by hand (preview); the climate, weather and music ticks stand down.
var manual: bool = false
## slot -> {player, event, gain, target, fade}; replaced layers fade out from _dying.
var _layers: Dictionary = {}
var _dying: Array[Dictionary] = []
var _weather_kind: StringName = &"auto"
var _weather_intensity: float = 1.0
var _weather_now: StringName = &"clear"  # what _effective_weather said at the last ambience tick
var _thunder_left: float = 20.0
var _tick_left: float = 0.0
var _music_mood: StringName = &""
var _music_gap: float = FIRST_TRACK_S

func set_weather(kind: StringName, intensity: float = 1.0) -> void:
	_weather_kind = kind
	_weather_intensity = clampf(intensity, 0.0, 1.0)
	_tick_left = 0.0

## Current event per slot (bed, shore, weather, music); &"" when silent. Labs and tests read it.
func slot_event(slot: StringName) -> StringName:
	var l: Dictionary = _layers.get(slot, {})
	return l.get("event", &"") if not l.is_empty() and float(l.get("target", 0.0)) > 0.0 else &""

## Put one event in a slot now (audio lab); target 0 fades the slot out.
func preview(slot: StringName, event: StringName, target: float = 1.0, fade: float = 0.5) -> void:
	_set_layer(slot, event, target, fade, true)

func _process(delta: float) -> void:
	if not manual:
		_tick_left -= delta
		if _tick_left <= 0.0:
			_tick_left = 0.5
			_tick_ambience()
		_tick_music(delta)
		_tick_thunder(delta)
	_fade(delta)

# ---------------------------------------------------------------- ambience

func _climate() -> String:
	var c := str(World.island_def.get("climate", "")) if World else ""
	var table: Dictionary = director.ambience_cfg.get("climates", {})
	return c if table.has(c) else str(director.ambience_cfg.get("default", "grassland"))

func _tick_ambience() -> void:
	var table: Dictionary = director.ambience_cfg.get("climates", {})
	var row: Dictionary = table.get(_climate(), {})
	var night := Game.phase_name() == &"night"
	var kind := _effective_weather()
	_weather_now = kind
	var wet := kind in [&"rain", &"storm"]
	var bed := StringName(str(row.get("night" if night else "day", "")))
	if bed != &"":
		_set_layer(&"bed", bed, 0.65 if wet else 1.0, BED_FADE_S)
	_set_layer(&"shore", StringName(str(director.ambience_cfg.get("shore", ""))), _shore_gain(), 2.0)
	var wev := &""
	match kind:
		&"rain":
			wev = StringName(str(director.ambience_cfg.get("rain_light" if _weather_intensity < 0.6 else "rain_heavy", "")))
		&"storm":
			wev = StringName(str(director.ambience_cfg.get("rain_heavy", "")))
		&"wind", &"snow", &"sandstorm", &"ash_storm":
			wev = StringName(str(director.ambience_cfg.get("wind", "")))
	if wev == &"":
		_set_layer(&"weather", slot_event(&"weather"), 0.0, 3.0)
	else:
		_set_layer(&"weather", wev, lerpf(0.5, 1.0, _weather_intensity), 3.0)

## The island's own rain (island_runtime.raining) unless a caller forced a kind.
func _effective_weather() -> StringName:
	if _weather_kind != &"auto":
		return _weather_kind
	var rt := World.runtime if World else null
	if rt == null or not is_instance_valid(rt) or not bool(rt.get("raining")):
		return &"clear"
	var kinds: Array = (Data.world_climates.get(_climate(), {}) as Dictionary).get("weather", [])
	_weather_intensity = 1.0 if "storm" in kinds else 0.5
	return &"storm" if "storm" in kinds else &"rain"

## Islands are round: surf rises over the last 30 m before the shoreline.
func _shore_gain() -> float:
	var rt := World.runtime if World else null
	var p := director.hooks.player if director.hooks else null
	if rt == null or not is_instance_valid(rt) or p == null or not is_instance_valid(p) or not rt.has_method("land_radius"):
		return 0.0
	var off := p.global_position - (rt as Node3D).global_position
	var d := Vector2(off.x, off.z).length()
	var shore := float(rt.call("land_radius"))
	return clampf((d - (shore - 30.0)) / 30.0, 0.0, 1.0) * 0.9

func _tick_thunder(delta: float) -> void:
	if _weather_now != &"storm":
		return
	_thunder_left -= delta
	if _thunder_left <= 0.0:
		_thunder_left = randf_range(12.0, 35.0) / maxf(0.3, _weather_intensity)
		director.play(StringName(str(director.ambience_cfg.get("thunder", "thunder"))), Vector3.INF, {"volume_db": randf_range(-6.0, 0.0)})

# ---------------------------------------------------------------- music

func _tick_music(delta: float) -> void:
	var hooks := director.hooks
	var threat := hooks.threat if hooks else false
	var force := hooks.consume_force_combat() if hooks else false
	var mood := music.update(delta, threat, Game.phase_name() == &"night", force)
	var ev := StringName(str(director.music_cfg.get(str(mood), "")))
	if mood != _music_mood:
		var was_combat := _music_mood == &"combat"
		_music_mood = mood
		if mood == &"combat":
			_set_layer(&"music", ev, 1.0, COMBAT_IN_S, true)
		else:
			_set_layer(&"music", slot_event(&"music"), 0.0, MUSIC_OUT_S)
			_music_gap = 6.0 if was_combat else minf(_music_gap, FIRST_TRACK_S)
		return
	if mood == &"combat" or ev == &"":
		return
	var cur: Dictionary = _layers.get(&"music", {})
	var busy := not cur.is_empty() and float(cur["target"]) > 0.0 and (cur["player"] as AudioStreamPlayer).playing
	if busy:
		return
	_music_gap -= delta
	if _music_gap <= 0.0:
		_music_gap = randf_range(TRACK_GAP_S.x, TRACK_GAP_S.y)
		_set_layer(&"music", ev, 1.0, MUSIC_IN_S, true)

# ---------------------------------------------------------------- layers

## restart: start a fresh variation even if the slot already plays this event (next track).
func _set_layer(slot: StringName, event: StringName, target: float, fade: float, restart: bool = false) -> void:
	var cur: Dictionary = _layers.get(slot, {})
	if not cur.is_empty() and cur["event"] == event and not restart:
		cur["target"] = target
		cur["fade"] = fade
		return
	if event == &"" or target <= 0.0:
		if not cur.is_empty():
			cur["target"] = 0.0
			cur["fade"] = fade
		return
	if not cur.is_empty():
		cur["target"] = 0.0
		cur["fade"] = fade
		_dying.append(cur)
		_layers.erase(slot)
	var e: Dictionary = director.events.get(event, {})
	var files: Array = e.get("files", [])
	if files.is_empty():
		return
	var looped := bool(e.get("loop", false))
	var stream := director.load_stream(str(files[randi() % files.size()]), looped, true)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.name = "Layer_%s" % slot
	p.stream = stream
	p.bus = StringName(str(e.get("bus", "Ambience")))
	p.volume_db = -80.0
	add_child(p)
	p.play()
	if director.log_events:
		print("[audio] layer %s -> %s" % [slot, event])
	_layers[slot] = {"player": p, "event": event, "gain": 0.0, "target": target, "fade": fade, "base_db": float(e.get("volume_db", 0.0))}

## A slot faded to silence is freed, not left playing at -80 dB: web Sample playback keeps its
## decoded PCM (about 15 MB for a 40 s stereo bed) alive while the player exists.
func _fade(delta: float) -> void:
	for slot in _layers.keys():
		var l: Dictionary = _layers[slot]
		_step(l, delta)
		if float(l["gain"]) <= 0.0 and float(l["target"]) <= 0.0:
			(l["player"] as Node).queue_free()
			_layers.erase(slot)
	for i in range(_dying.size() - 1, -1, -1):
		var l := _dying[i]
		_step(l, delta)
		if float(l["gain"]) <= 0.0:
			(l["player"] as Node).queue_free()
			_dying.remove_at(i)

func _step(l: Dictionary, delta: float) -> void:
	var g := move_toward(float(l["gain"]), float(l["target"]), delta / maxf(0.05, float(l["fade"])))
	l["gain"] = g
	(l["player"] as AudioStreamPlayer).volume_db = float(l["base_db"]) + linear_to_db(maxf(g, 0.0001))

## Stop explicitly on quit: a bed still playing at exit pins its stream in the AudioServer (leak report).
func _exit_tree() -> void:
	for slot in _layers:
		(_layers[slot]["player"] as AudioStreamPlayer).stop()
