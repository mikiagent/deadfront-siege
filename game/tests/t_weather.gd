extends SceneTree
## WEATHER acceptance on the home island (headless, simulated time):
##   each forced state (--weather= / WorldWeather.forced) sets the right overlay and params; thunder lands
##   distance / sound_mps after its lightning, which lands at a world point with a bolt; the shake falls with
##   distance; rain modes are ordered drizzle < rain < pour; heat shows the
##   shimmer only on high quality; cold grows frost and shivers getting cold and defrosting; the camera
##   offset stays under shake_m.max and is zero with reduce-shake (combat trauma too); the layer sits under
##   the HUD; a red-edge status halves the weather edges; heat / cold follow the climate's unmet resistance
##   and day phase; dry climates never roll rain; no node growth over 2 simulated minutes of storm.
## Usage: godot --headless --path game --script res://tests/t_weather.gd -> "[t_weather] PASS", exit 0/1.

const DT := 0.05

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var _rt
var _w
var _fx

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_weather] %s %s" % ["ok" if ok else "FAIL", what])

## Simulated seconds: the weather and its layer only, so the test sets the clock.
func _sim(secs: float) -> float:
	var top := 0.0
	var n := int(round(secs / DT))
	for i in n:
		_w.tick(_rt, DT)
		_fx._process(DT)
		top = maxf(top, _fx.shake.length())
	return top

func _run() -> void:
	_host = Node3D.new()
	_host.name = "TWeatherHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("hands_spot"):
			_hud = c
	root.get_node("World").load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_rt = root.get_node("World").runtime
	_w = _rt.weather
	_fx = _w.fx
	for n in get_nodes_in_group("creature"):
		n.queue_free()
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_rt.set_process(false)
	_fx.set_process(false)
	var game: Node = root.get_node("Game")
	game.set_process(false)
	game.time_of_day = 0.5
	var WW: GDScript = _w.get_script()
	var Cam: GDScript = load("res://scripts/camera/iso_camera.gd")
	var cfg: Dictionary = root.get_node("Data").world_rules["weather"]
	var max_m := float(cfg["shake_m"]["max"])
	_expect(_fx.layer < (kit["ui"] as CanvasLayer).layer, "the weather layer (%d) draws under the HUD's (%d), so HUD rects and the red edge stay on top" % [_fx.layer, (kit["ui"] as CanvasLayer).layer])
	var top := 0.0

	WW.forced = &"clear"
	top = maxf(top, _sim(8.0))
	_expect(not _w.raining and not _fx.edge.visible and not _fx.shimmer.visible, "clear: no rain, no edge, no shimmer")

	WW.forced = &"rain"
	top = maxf(top, _sim(4.0))
	var m: ShaderMaterial = _fx.edge.material
	_expect(_w.raining and not _w.storm and _fx.edge.visible and float(m.get_shader_parameter("rain")) > 0.5, "rain: raining, edge on with the grey wash (rain=%.2f)" % float(m.get_shader_parameter("rain")))
	_expect(_player.statuses.has(&"wet"), "rain: Wet")
	_expect(float(m.get_shader_parameter("heat")) == 0.0 and float(m.get_shader_parameter("cold")) == 0.0 and _w.pending.is_empty(), "rain: no heat, cold or lightning")

	_test_rain_modes(WW)

	WW.forced = &"storm"
	var flashes: Array = []
	var claps: Array = []
	var clock := [0.0]
	var where_ok := [true]
	var on_l := func (pos: Vector3, d: float) -> void:
		flashes.append([clock[0], d])
		var me: Vector3 = _player.global_position
		var b = _w.bolts.back() if not _w.bolts.is_empty() else null
		where_ok[0] = where_ok[0] and absf(Vector2(pos.x - me.x, pos.z - me.z).length() - d) < 0.01 and b != null and b.is_inside_tree() and b.global_position.distance_to(pos) < 0.01 and b.get_node("Bolt").visible
	var on_t := func (d: float) -> void: claps.append([clock[0], d])
	_w.lightning.connect(on_l)
	_w.thunder.connect(on_t)
	await process_frame
	var nodes0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var lit := false
	var near_n := 0
	var far_n := 0
	var n := int(120.0 / DT)
	for i in n:
		clock[0] += DT
		_w.tick(_rt, DT)
		_fx._process(DT)
		top = maxf(top, _fx.shake.length())
		if _w.flash > 0.3:
			lit = lit or (float(m.get_shader_parameter("flash")) > 0.3 and _w.light.visible and _w.light.light_energy > 0.7)
		if i % 20 == 0:
			await process_frame  # let freed bolts go
	for f in flashes:
		near_n += 1 if float(f[1]) < 40.0 else 0
		far_n += 1 if float(f[1]) > 700.0 else 0
	_expect(_w.storm and _w.rain_mode == &"pour" and flashes.size() >= 4 and flashes.size() <= 16, "storm: pouring, %d strikes in 2 min (gap %s s)" % [flashes.size(), cfg["lightning_gap_s"]])
	_expect(where_ok[0], "storm: each strike's distance is its ground point to the survivor, with a visible bolt node there")
	_expect(lit, "storm: a strike lights the edge's flash and the lightning light")
	var lag_ok := claps.size() >= flashes.size() - 1 and claps.size() > 0
	for k in claps.size():
		var want: float = flashes[k][0] + float(flashes[k][1]) / float(cfg["sound_mps"])
		lag_ok = lag_ok and absf(float(claps[k][0]) - want) <= DT * 1.5 and is_equal_approx(float(claps[k][1]), float(flashes[k][1]))
	_expect(lag_ok, "storm: every thunder lands its strike's distance / %.0f m/s after the flash (%d strikes: %s)" % [float(cfg["sound_mps"]), flashes.size(), flashes.map(func (f: Array) -> String: return "%.0fm" % f[1])])
	_w.lightning.disconnect(on_l)
	_w.thunder.disconnect(on_t)
	# The same strike near and far: the far one claps later and shakes less.
	var shake_at := {}
	for d in [12.0, 300.0, 2000.0]:
		_w._flash_cd = 1.0e9
		var gap := [0.0, -1.0]
		var on_c := func (_d: float) -> void: gap[1] = gap[0]
		_w.thunder.connect(on_c)
		_w.strike(d)
		var peak := 0.0
		for i in int(8.0 / DT):
			_w.tick(_rt, DT)
			_fx._process(DT)
			gap[0] += DT
			peak = maxf(peak, _fx.shake.length())
		_w.thunder.disconnect(on_c)
		shake_at[d] = [gap[1], peak]
	print("[t_weather] strike distance -> [thunder gap s, peak shake m]: %s" % shake_at)
	_expect(shake_at[12.0][0] < 0.1 and absf(shake_at[300.0][0] - 300.0 / 343.0) <= DT * 1.5 and absf(shake_at[2000.0][0] - 2000.0 / 343.0) <= DT * 1.5, "near strike: thunder at once; far: 5.8 s later")
	_expect(shake_at[12.0][1] > shake_at[300.0][1] and shake_at[300.0][1] > shake_at[2000.0][1] and shake_at[2000.0][1] > 0.0 and shake_at[12.0][1] <= max_m + 0.0001, "the shake falls with distance and stays <= %.2f m" % max_m)
	WW.forced = &"clear"
	_sim(7.0)
	await process_frame
	await process_frame
	var nodes1 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_expect(_w.bolts.is_empty() and nodes1 <= nodes0, "every bolt freed after its %.0f s; no node growth over the storm (%d -> %d)" % [6.0, nodes0, nodes1])
	WW.forced = &"storm"

	WW.forced = &"heat"
	_set_quality(true)
	top = maxf(top, _sim(6.0))
	_expect(_w.heat > 0.99 and _fx.edge.visible and float(m.get_shader_parameter("heat")) > 0.99 and _fx.shimmer.visible, "heat: heat 1, orange edge on, shimmer on (high quality)")
	_expect(not _w.raining and _w.cold == 0.0 and _w.flash == 0.0, "heat: no rain, cold or flash")
	_expect(_fx.shake.length() > 0.0 and _fx.shake.length() <= float(cfg["shake_m"]["heat"]) * 1.6, "heat: a slight sway (%.4f m)" % _fx.shake.length())
	_set_quality(false)
	_sim(0.1)
	_expect(not _fx.shimmer.visible and _fx.edge.visible, "heat, low quality: no shimmer, the edge stays")
	_set_quality(true)

	WW.forced = &"cold"
	var shivers := 0
	var was := 0.0
	for i in int(14.0 / DT):
		_w.tick(_rt, DT)
		_fx._process(DT)
		top = maxf(top, _fx.shake.length())
		if _w.shiver > was + 0.5:
			shivers += 1
		was = _w.shiver
	_expect(_w.cold > 0.99 and _w.frost > 0.9 and _w.heat < 0.01 and float(m.get_shader_parameter("frost")) > 0.9 and not _fx.shimmer.visible, "cold: cold 1, frost %.2f crept in, no shimmer" % _w.frost)
	_expect(shivers >= 1, "cold: a shiver on getting cold (%d)" % shivers)
	WW.forced = &"clear"
	var thaw := 0
	_w._shiver_cd = 1.0e9  # only the defrost shiver counts here, not a periodic one
	for i in int(10.0 / DT):
		_w.tick(_rt, DT)
		_fx._process(DT)
		if _w.shiver > was + 0.5:
			thaw += 1
		was = _w.shiver
	_expect(thaw == 1 and _w.frost < 0.05, "cold -> clear: one shiver on defrosting, frost gone (%.2f)" % _w.frost)
	_expect(top <= max_m + 0.0001, "every state: weather shake <= %.2f m (top %.3f)" % [max_m, top])

	WW.forced = &"storm"
	Cam.reduce_shake = true
	_w.strike(400.0)
	var reduced := _sim(3.0)
	var cam = _host.get_node("IsoCamera")
	cam.trauma = 0.0
	cam.add_trauma(0.8)
	_expect(reduced == 0.0 and cam.trauma == 0.0, "reduce-shake: no weather offset, no combat trauma")
	Cam.reduce_shake = false

	WW.forced = &"heat"
	_sim(1.0)
	_expect(_fx.edge_scale == 1.0, "no fight: weather edges at full")
	_player.statuses.apply(&"bleed", null)
	_sim(0.1)
	_expect(_fx.edge_scale == _fx.COMBAT_EDGE_SCALE and float(m.get_shader_parameter("edge_scale")) == _fx.COMBAT_EDGE_SCALE, "bleeding (the red edge): weather edges at %.1f" % _fx.COMBAT_EDGE_SCALE)
	_player.statuses.from_array([])

	# The climate drives it when nothing is forced.
	WW.forced = &""
	var d_day: Vector2 = WW.temp_targets(_player, "desert", &"day")
	var d_night: Vector2 = WW.temp_targets(_player, "desert", &"night")
	var t_day: Vector2 = WW.temp_targets(_player, "tundra", &"day")
	var t_night: Vector2 = WW.temp_targets(_player, "tundra", &"night")
	var g: Vector2 = WW.temp_targets(_player, "grassland", &"day")
	var s_day: Vector2 = WW.temp_targets(_player, "savannah", &"day")
	_expect(d_day.x > 0.95 and d_night == Vector2.ZERO, "desert: hot by day (%.2f), nothing at night" % d_day.x)
	_expect(s_day.x > 0.0 and s_day.x < d_day.x, "savannah heat %.2f is milder than the desert's" % s_day.x)
	_expect(t_day.y > 0.0 and t_night.y > t_day.y and t_day.x == 0.0, "tundra: cold by day %.2f, colder at night %.2f" % [t_day.y, t_night.y])
	_expect(g == Vector2.ZERO, "home grassland: neither hot nor cold")
	_expect(_w.chance("desert", "rain") == 0.0 and _w.chance("grassland", "rain") > 0.0 and _w.chance("tropical", "storm") > _w.chance("grassland", "storm"), "rain chance per climate: none in the desert, storms likelier in the tropics")
	_w._climate = "desert"
	_w.raining = false
	var rained := false
	for i in 40:
		_w._rain_cd = 0.0
		_w.tick(_rt, DT)
		rained = rained or _w.raining
	_expect(not rained, "desert: 40 weather checks, no rain")
	_test_mood_idles(WW)
	WW.forced = &""
	if _fails.is_empty():
		print("[t_weather] PASS")
		quit(0)
	else:
		print("[t_weather] FAIL count=%d" % _fails.size())
		quit(1)

func _set_quality(high: bool) -> void:
	_fx.get_script().high_quality = high

## Mood idles: exhausted > cold / heat > tired > idle, each only when its clip exists; moving and busy clips win.
func _test_mood_idles(WW: GDScript) -> void:
	var PA: GDScript = load("res://scripts/player/player_anim.gd")
	var all := func (_c: StringName) -> bool: return true
	var none := func (_c: StringName) -> bool: return false
	var only_idle_tired := func (c: StringName) -> bool: return c == &"idle_tired"
	_expect(PA.pick_idle(all, 0.8, 0.9, 0.0) == &"idle_exhausted", "exhausted beats cold")
	_expect(PA.pick_idle(all, 0.6, 0.9, 0.0) == &"idle_cold" and PA.pick_idle(all, 0.6, 0.0, 0.7) == &"idle_heat", "cold / heat beat tired")
	_expect(PA.pick_idle(all, 0.6, 0.2, 0.1) == &"idle_tired" and PA.pick_idle(all, 0.1, 0.2, 0.1) == &"idle", "tired, then plain idle")
	_expect(PA.pick_idle(none, 0.9, 1.0, 0.0) == &"idle", "every mood clip missing: plain idle")
	_expect(PA.pick_idle(only_idle_tired, 0.9, 1.0, 0.0) == &"idle_tired", "a missing clip falls to the next in line")
	var anim = _player.anim
	var rig = anim.rig
	if rig == null or not rig.has_clip(&"idle"):
		_expect(false, "the survivor rig has an idle clip")
		return
	for c in [&"idle_cold", &"idle_heat", &"idle_tired", &"idle_exhausted"]:
		var clip: Animation = rig.library.get_animation(c) if rig.has_clip(c) else null
		_expect(clip != null and clip.loop_mode == Animation.LOOP_LINEAR, "survivor clip %s loaded and looping" % c)
	var v = _player.vitals
	var cases := [[&"cold", 0.0, &"idle_cold"], [&"heat", 0.0, &"idle_heat"], [&"clear", 0.6, &"idle_tired"], [&"cold", 0.8, &"idle_exhausted"]]
	for k in cases:
		WW.forced = k[0]
		v.fatigue = v.effective_max_fatigue() * float(k[1])
		_sim(8.0)
		anim.play_locomotion(0.0)
		var ap: AnimationPlayer = rig.anim_player
		var t0 := ap.current_animation_position
		var len := ap.current_animation_length
		ap.advance(len * 1.25)
		var wrapped := ap.is_playing() and ap.current_animation == str(k[2])
		_expect(anim.current_clip == k[2] and wrapped, "%s, fatigue %.0f%%: %s plays and keeps playing past its end (%s, %.2f s of %.2f)" % [k[0], float(k[1]) * 100.0, k[2], ap.current_animation, t0, len])
	WW.forced = &"cold"
	v.fatigue = 0.0
	anim.play_locomotion(0.0)
	anim.play_locomotion(2.0)
	_expect(anim.current_clip == &"walk", "moving overrides the mood idle (%s)" % anim.current_clip)
	anim.play_clip(&"roll")
	anim.play_locomotion(0.0)
	_expect(anim.current_clip == &"roll", "a busy clip (roll) is not interrupted (%s)" % anim.current_clip)
	anim._busy = false
	var cold_clip: Animation = rig.library.get_animation(&"idle_cold")
	rig.library.remove_animation(&"idle_cold")
	anim.play_locomotion(0.0)
	_expect(anim.current_clip == &"idle", "idle_cold missing: plain idle (%s)" % anim.current_clip)
	rig.library.add_animation(&"idle_cold", cold_clip)
	WW.forced = &"clear"
	_sim(12.0)

## Drizzle < rain < pour in particles, drop size, darkening and wet ground; only pour splashes; the
## mode is exposed for the dial (rain_mode, rain_level).
func _test_rain_modes(WW: GDScript) -> void:
	var rows := {}
	for mode in [&"drizzle", &"rain", &"pour"]:
		WW.forced = mode
		_sim(12.0)
		rows[mode] = [_w._rain_fx.amount_ratio, _w._drop.size.y, _w.rain_amount, _w.wet_ground, _w.rain_level(), _w._splash_fx.emitting]
	print("[t_weather] modes [particles, drop m, dark, wet, level, splash]: %s" % rows)
	var ok := true
	for k in 4:
		ok = ok and float(rows[&"drizzle"][k]) < float(rows[&"rain"][k]) and float(rows[&"rain"][k]) < float(rows[&"pour"][k])
	_expect(ok, "drizzle < rain < pour in particle share, drop length, darkening and wet ground")
	_expect(rows[&"drizzle"][4] == 1 and rows[&"rain"][4] == 2 and rows[&"pour"][4] == 3 and _w.rain_mode == &"pour", "rain_level 1 / 2 / 3 and rain_mode exposed")
	_expect(not rows[&"drizzle"][5] and not rows[&"rain"][5] and rows[&"pour"][5], "only pouring rain splashes")
	_expect(ProjectSettings.has_setting("shader_globals/weather_wet") and "global uniform float weather_wet" in FileAccess.get_file_as_string("res://scripts/world/terrain_tiles.gdshader"), "the terrain reads the ground's wetness (weather_wet global, %.2f in pour)" % _w.wet_ground)
	var counts := {}
	for i in 400:
		var mm: StringName = _w.roll_mode("tropical")
		counts[mm] = int(counts.get(mm, 0)) + 1
	_expect(counts.size() == 3 and int(counts[&"pour"]) > int(counts[&"drizzle"]), "per-climate mode weights: the tropics pour more than they drizzle (%s)" % counts)
