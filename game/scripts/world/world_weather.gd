class_name WorldWeather
extends RefCounted
## Island weather (WEATHER, owner 2026-10-28: rain; rain and lightning, infrequent, the ground shaking when
## the thunder arrives after the flash; heat with an orange edge, a shimmer and a slight shake; cold with a
## blue-white edge, frost around the outside and infrequent shivers when getting cold and defrosting;
## rain in three modes, drizzle / rain / pouring; real lightning strikes whose distance sets the thunder gap).
## This holds the state: rain spells in a mode (particles, splashes, the Wet status, wet ground), storms
## (pouring plus lightning: a bolt at a world position, then thunder after the sound's travel time to the
## survivor), and the heat / cold she feels, from the same unmet climate resistance that climate fatigue
## charges. WeatherFx draws the screen side. The per-frame climate and level-gap fatigue feed for the player
## rides the same tick. Numbers: data/world/rules.json "weather".

## Sound hooks (no audio assets exist yet): a strike at a world position, its thunder distance / sound_mps
## later, and the rain's mode (&"" when it stops).
signal lightning(position: Vector3, distance_m: float)
signal thunder(distance_m: float)
signal rain_mode_changed(mode: StringName)

const STATES: Array[StringName] = [&"clear", &"drizzle", &"rain", &"pour", &"storm", &"heat", &"cold"]
const RAIN_MODES: Array[StringName] = [&"drizzle", &"rain", &"pour"]
const MAX_BOLTS := 3
## Rain particles at amount_ratio 1 (pour); a mode's "amount" is its share.
const RAIN_PARTICLES := 900
## --weather=drizzle|rain|pour|storm|heat|cold|clear holds that state (labs, shots, tests); &"" lets the
## climate roll.
static var forced: StringName = &""

var raining: bool = false
var storm: bool = false
## &"drizzle" | &"rain" | &"pour" while raining, else &"". The day/night dial reads it (rain_level()).
var rain_mode: StringName = &""
var _rain_left: float = 0.0
var _rain_cd: float = 40.0
var _wet_refresh: float = 0.0
var _rain_fx: GPUParticles3D
var _splash_fx: GPUParticles3D
var _rain_mat: ParticleProcessMaterial
var _drop: QuadMesh
var _rt: IslandRuntime
var _climate := "grassland"
var _cfg: Dictionary = {}
var _flash_cd := 3.0
var _flash_t := -1.0
var _flash_peak := 0.0
## 0..1 lightning brightness this frame: a double flicker that dies in about half a second.
var flash := 0.0
## [seconds left, distance m] per thunder clap still on its way.
var pending: Array = []
## 0..1 rumble of the latest thunder (bigger the nearer the strike), gone in 1.5 s.
var rumble := 0.0
## 0..1, eased: the grey wash and sun dimming of the rain's mode (pour and storm 1).
var rain_amount := 0.0
## 0..1, eased: how wet the ground looks (global shader parameter weather_wet, the terrain reads it).
var wet_ground := 0.0
var heat := 0.0
var cold := 0.0
## Creeps in behind cold (about 8 s) and melts a little faster.
var frost := 0.0
## 0..1 shiver burst (getting cold, defrosting, and now and then while cold).
var shiver := 0.0
var _chilled := false
var _shiver_cd := 0.0
var fx: WeatherFx
## The latest strike's ground point, and the visuals of strikes still showing (LightningBolt).
var last_strike := Vector3.ZERO
var bolts: Array[LightningBolt] = []
## Lights the scene from the latest strike's direction while it flashes (no shadows).
var light: DirectionalLight3D

func install(rt: IslandRuntime) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weather="):
			forced = StringName(a.substr(10))
	_rt = rt
	_climate = rt._climate
	_cfg = Data.world_rules.get("weather", {}) as Dictionary
	_rain_cd = float(_cfg.get("first_check_s", 40.0))
	_rain_fx = GPUParticles3D.new()
	_rain_fx.name = "Rain"
	_rain_fx.emitting = false
	_rain_fx.amount = RAIN_PARTICLES
	_rain_fx.lifetime = 0.9
	_rain_fx.visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 20, 80))
	_rain_mat = ParticleProcessMaterial.new()
	_rain_mat.direction = Vector3(0, -1, 0)
	_rain_mat.spread = 4.0
	_rain_mat.gravity = Vector3(0, -14, 0)
	_rain_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_mat.emission_box_extents = Vector3(18, 0.2, 18)
	_rain_mat.color = Color(0.65, 0.75, 0.9, 0.7)
	_rain_fx.process_material = _rain_mat
	# A 2-triangle streak whose material takes the particle colour; without vertex_color_use_as_albedo
	# every drop rendered plain white.
	_drop = QuadMesh.new()
	_drop.size = Vector2(0.025, 0.5)
	_drop.material = _streak_mat()
	_rain_fx.draw_pass_1 = _drop
	_rain_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rt.add_child(_rain_fx)
	_splash_fx = _make_splash()
	rt.add_child(_splash_fx)
	light = DirectionalLight3D.new()
	light.name = "LightningLight"
	light.light_color = Color(0.78, 0.86, 1.0)
	light.shadow_enabled = false
	light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	light.visible = false
	rt.add_child(light)
	_apply_mode(&"rain")
	fx = WeatherFx.new()
	fx.weather = self
	rt.add_child(fx)

static func _streak_mat() -> StandardMaterial3D:
	var streak := StandardMaterial3D.new()
	streak.vertex_color_use_as_albedo = true
	streak.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	streak.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return streak

## Pouring rain's splashes: short white flecks hopping off the ground around her.
func _make_splash() -> GPUParticles3D:
	var s := GPUParticles3D.new()
	s.name = "RainSplash"
	s.emitting = false
	s.amount = 160
	s.lifetime = 0.3
	s.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 6, 40))
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 60.0
	m.initial_velocity_min = 0.8
	m.initial_velocity_max = 1.6
	m.gravity = Vector3(0, -9, 0)
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(12, 0.05, 12)
	m.color = Color(0.85, 0.9, 1.0, 0.55)
	s.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	q.material = _streak_mat()
	s.draw_pass_1 = q
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s

## The mode's row in rules.json weather.rain_modes.
func mode_cfg(mode: StringName) -> Dictionary:
	return ((_cfg.get("rain_modes", {}) as Dictionary).get(str(mode), {}) as Dictionary)

## 0 dry, 1 drizzle, 2 rain, 3 pour (and storm).
func rain_level() -> int:
	return RAIN_MODES.find(rain_mode) + 1 if raining else 0

func _apply_mode(mode: StringName) -> void:
	var c := mode_cfg(mode)
	if _rain_fx == null or c.is_empty():
		return
	_rain_fx.amount_ratio = float(c.get("amount", 0.6))
	_drop.size = Vector2(float(c.get("drop_w", 0.025)), float(c.get("drop_len", 0.5)))
	var v := float(c.get("speed", 11.0))
	_rain_mat.initial_velocity_min = v * 0.8
	_rain_mat.initial_velocity_max = v * 1.1

func _set_mode(mode: StringName) -> void:
	if mode == rain_mode:
		return
	rain_mode = mode
	if mode != &"":
		_apply_mode(mode)
	rain_mode_changed.emit(mode)

func tick(rt: IslandRuntime, delta: float) -> void:
	var p := PlayerRegistry.local()
	_tick_sky(delta)
	_set_mode((&"pour" if storm else (rain_mode if rain_mode != &"" else &"rain")) if raining else &"")
	if raining and p:
		# Refresh once a second, not every frame, so the status log and its bookkeeping stay quiet.
		_wet_refresh -= delta
		if _wet_refresh <= 0.0 or not p.statuses.has(&"wet"):
			soak(p, rain_level())
			_wet_refresh = 1.0
	elif p:
		dry(p, delta, heat)
	if _rain_fx:
		if raining and p:
			_rain_fx.global_position = p.global_position + Vector3(0, 10, 0)
			_splash_fx.global_position = p.global_position + Vector3(0, 0.1, 0)
		_rain_fx.emitting = raining
		_splash_fx.emitting = raining and bool(mode_cfg(rain_mode).get("splash", false))
	var mc := mode_cfg(rain_mode)
	rain_amount = move_toward(rain_amount, float(mc.get("dark", 0.7)) if raining else 0.0, delta / 3.0)
	wet_ground = move_toward(wet_ground, float(mc.get("wet", 0.8)) if raining else 0.0, delta / (6.0 if raining else 40.0))
	RenderingServer.global_shader_parameter_set(&"weather_wet", wet_ground)
	_tick_storm(delta)
	_tick_temp(p, delta)
	if p:
		p.tick_climate_fatigue(delta, rt._climate)
		if p.vitals:
			var char_level := p.skills.character_level() if p.skills else 1
			var zone_level := rt.material_level(p.global_position, rt._tier)
			p.vitals.gap_zone_level = zone_level
			p.vitals.gap_char_level = char_level
			var fatigue_cfg: Dictionary = Data.world_rules.get("fatigue", {}) as Dictionary
			p.vitals.breakdown_window_s = float(fatigue_cfg.get("breakdown_window_s", 180.0))
			p.vitals.level_gap_mult = ProgressionScaling.fatigue_level_factor(zone_level, char_level, fatigue_cfg)

## Wet her to `level` stacks (drizzle 1, rain 2, pour or water 3): never drier than she is, timer full.
static func soak(p: Player, level: int) -> void:
	if p == null or p.statuses == null or level <= 0:
		return
	var inst := p.statuses.get_instance(&"wet")
	if inst == null:
		p.statuses.apply(&"wet", null, mini(level, 3))
		return
	inst.stacks = maxi(inst.stacks, mini(level, 3))
	inst.time_left = Data.status(&"wet").duration

## Out of the rain she dries a stack per Wet duration (the status's own timer), faster within
## drying.fire_m of a burning fire and in heat; the last stack's end clears it.
func dry(p: Player, delta: float, heat_now: float) -> void:
	var inst := p.statuses.get_instance(&"wet") if p.statuses else null
	if inst == null:
		return
	var mult := drying_mult(p, heat_now)
	inst.time_left -= delta * (mult - 1.0)  # StatusEffects already takes delta off
	if inst.time_left <= 0.5 + delta * mult and inst.stacks > 1:  # before StatusEffects ends the whole instance
		inst.stacks -= 1
		inst.time_left = Data.status(&"wet").duration

## How many times faster than in the open she dries now (rules.json weather.drying).
func drying_mult(p: Player, heat_now: float) -> float:
	var d: Dictionary = _cfg.get("drying", {}) as Dictionary
	var m := 1.0 + float(d.get("heat_mult", 3.0)) * clampf(heat_now, 0.0, 1.0)
	var reach := float(d.get("fire_m", 4.0))
	for n in p.get_tree().get_nodes_in_group("bonfire"):
		if n is Bonfire and (n as Bonfire).burning() and (n as Node3D).global_position.distance_to(p.global_position) <= reach:
			m += float(d.get("fire_mult", 4.0))
			break
	return m

## The climate's chance of `kind` ("rain" per check, "storm" per rain spell), 0 when it lists none.
func chance(climate: String, kind: String) -> float:
	return float(_climate_cfg(climate).get(kind, 0.0))

func _climate_cfg(climate: String) -> Dictionary:
	return ((_cfg.get("climates", {}) as Dictionary).get(climate, {}) as Dictionary)

## A rain spell's mode by the climate's weights (rules.json climates.<id>.modes, else default_modes).
func roll_mode(climate: String) -> StringName:
	var w: Dictionary = _climate_cfg(climate).get("modes", _cfg.get("default_modes", {"rain": 1.0})) as Dictionary
	var total := 0.0
	for m in RAIN_MODES:
		total += float(w.get(str(m), 0.0))
	var r := randf() * total
	for m in RAIN_MODES:
		r -= float(w.get(str(m), 0.0))
		if r < 0.0:
			return m
	return &"rain"

func _range(key: String, fallback: Vector2) -> float:
	var r: Variant = _cfg.get(key, [fallback.x, fallback.y])
	return randf_range(float(r[0]), float(r[1])) if r is Array and (r as Array).size() == 2 else fallback.x

func _tick_sky(delta: float) -> void:
	if forced in RAIN_MODES or forced == &"storm":
		if not storm and forced == &"storm":
			_flash_cd = 2.0
		raining = true
		storm = forced == &"storm"
		if not storm:
			_set_mode(forced)
		return
	if forced != &"":
		raining = false
		storm = false
		return
	if raining:
		_rain_left -= delta
		if _rain_left <= 0.0:
			raining = false
			storm = false
			_rain_cd = _range("rain_check_s", Vector2(50, 90))
		return
	_rain_cd -= delta
	if _rain_cd > 0.0:
		return
	_rain_cd = _range("rain_check_s", Vector2(50, 90))
	if randf() >= chance(_climate, "rain"):
		return
	raining = true
	storm = randf() < chance(_climate, "storm")
	_set_mode(&"pour" if storm else roll_mode(_climate))
	_rain_left = _range("storm_len_s" if storm else "rain_len_s", Vector2(18, 30))
	_flash_cd = 3.0
	print("[world] rain mode=%s storm=%s" % [rain_mode, storm])

func _tick_storm(delta: float) -> void:
	if storm:
		_flash_cd -= delta
		if _flash_cd <= 0.0:
			strike(pick_distance())
	if _flash_t >= 0.0:
		_flash_t += delta
		flash = _flash_peak * flash_curve(_flash_t)
		if _flash_t > 1.0:
			_flash_t = -1.0
			flash = 0.0
	for i in range(pending.size() - 1, -1, -1):
		pending[i][0] -= delta
		if pending[i][0] <= 0.0:
			var d: float = pending[i][1]
			pending.remove_at(i)
			rumble = maxf(rumble, 0.15 + 0.85 * near(d))
			thunder.emit(d)
	rumble = move_toward(rumble, 0.0, delta / 1.5)
	for i in range(bolts.size() - 1, -1, -1):
		var b := bolts[i]
		if not is_instance_valid(b):
			bolts.remove_at(i)
			continue
		b.age += delta
		if b.done():
			b.queue_free()
			bolts.remove_at(i)
		else:
			b.update()
	if light:
		light.visible = flash > 0.002
		light.light_energy = flash * float(_cfg.get("lightning_light_energy", 2.5))

## A strike distance from the climate-free bands: some close, most mid, some far (rules.json
## lightning_bands [share, min m, max m]).
func pick_distance() -> float:
	var bands: Array = _cfg.get("lightning_bands", [[1.0, 400.0, 3000.0]]) as Array
	var r := randf()
	for b in bands:
		r -= float(b[0])
		if r < 0.0:
			return randf_range(float(b[1]), float(b[2]))
	var last: Array = bands.back()
	return randf_range(float(last[1]), float(last[2]))

## A strike `distance_m` from the survivor on a random bearing (strike_at does the work).
func strike(distance_m: float) -> void:
	var p := PlayerRegistry.local()
	var at := p.global_position if p else Vector3.ZERO
	var ang := randf() * TAU
	strike_at(at + Vector3(cos(ang), 0.0, sin(ang)) * distance_m)

## A lightning strike at `pos` (x, z; y snaps to the ground): a bolt there, the flash now and a light from
## its direction, its thunder (horizontal distance to the survivor) / sound_mps later. Damages nothing.
func strike_at(pos: Vector3) -> void:
	var p := PlayerRegistry.local()
	var me := p.global_position if p else Vector3.ZERO
	if _rt and is_instance_valid(_rt):
		pos.y = _rt.surface_y(pos.x, pos.z)
	var d := Vector2(pos.x - me.x, pos.z - me.z).length()
	last_strike = pos
	_flash_t = 0.0
	_flash_peak = 0.45 + 0.55 * near(d)
	flash = _flash_peak
	_flash_cd = _range("lightning_gap_s", Vector2(8, 20))
	pending.append([thunder_delay(d), d])
	if _rt and is_instance_valid(_rt):
		if bolts.size() >= MAX_BOLTS:
			bolts.pop_front().queue_free()
		var b := LightningBolt.make(pos, randi())
		_rt.add_child(b)
		bolts.append(b)
	if light:
		var from := pos + Vector3(0.0, LightningBolt.HEIGHT * 0.6, 0.0)
		var dir := (me - from).normalized()
		if dir.length() > 0.5:
			light.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	lightning.emit(pos, d)

func thunder_delay(distance_m: float) -> float:
	return distance_m / float(_cfg.get("sound_mps", 343.0))

## 1 at the nearest band's start, 0 at the farthest band's end, falling off with log distance (a strike
## twice as far is a step quieter, not half as loud).
func near(distance_m: float) -> float:
	var bands: Array = _cfg.get("lightning_bands", [[1.0, 400.0, 3000.0]]) as Array
	var lo := maxf(1.0, float(bands[0][1]))
	var hi := maxf(lo + 1.0, float(bands.back()[2]))
	return 1.0 - clampf(log(maxf(distance_m, lo) / lo) / log(hi / lo), 0.0, 1.0)

## Lightning's double flicker: a bright stroke, a dip, a second stroke, then a quick fade.
static func flash_curve(t: float) -> float:
	if t < 0.07:
		return 1.0
	if t < 0.13:
		return 0.25
	if t < 0.2:
		return 0.8
	return 0.8 * exp(-(t - 0.2) * 7.0)

func _tick_temp(p: Player, delta: float) -> void:
	var want := Vector2.ZERO
	if forced == &"heat":
		want = Vector2(1, 0)
	elif forced == &"cold":
		want = Vector2(0, 1)
	elif forced == &"" and p:
		want = temp_targets(p, _climate, Game.phase_name())
	heat = move_toward(heat, want.x, delta / 4.0)
	cold = move_toward(cold, want.y, delta / 4.0)
	frost = move_toward(frost, cold, delta / (8.0 if cold > frost else 5.0))
	if cold >= 0.5 and not _chilled:
		_chilled = true  # getting cold
		_shiver()
	elif _chilled and frost < 0.2:
		_chilled = false  # defrosted
		_shiver()
	elif _chilled:
		_shiver_cd -= delta
		if _shiver_cd <= 0.0:
			_shiver()
	shiver = move_toward(shiver, 0.0, delta / 0.7)

func _shiver() -> void:
	shiver = 1.0
	_shiver_cd = _range("shiver_gap_s", Vector2(14, 28))

## How hot and how cold she feels (0..1 each) in `climate` at `phase`.
## ASSUMPTION: severity = the climate's resistance need / 3 (0.4..1), times 0.4 for being there plus 0.6
## times the unmet share. Heat shows by day only (climate fatigue charges heat by day); cold shows at any
## hour where the climate asks for it, its unmet share only off the day phase (when fatigue charges it).
## Wet / Quenched cool the heat, Wet sharpens the cold and sitting by a fire warms it, as they scale the fatigue.
static func temp_targets(p: Player, climate: String, phase: StringName) -> Vector2:
	var need := p.climate_needs(climate)
	var short := p.climate_shortfall(climate)
	var day := phase == &"day"
	var h := 0.0
	var c := 0.0
	var nh := float(need["heat"])
	var nc := float(need["cold"])
	if day and nh > 0.0:
		h = clampf(nh / 3.0, 0.4, 1.0) * (0.4 + 0.6 * float(short["heat"]) / nh) * p.statuses.heat_fatigue_mult()
	if nc > 0.0:
		c = clampf(nc / 3.0, 0.4, 1.0) * (0.4 + (0.0 if day else 0.6 * float(short["cold"]) / nc))
		c *= p.sim.rest.climate_mult("cold") if p.sim else 1.0
		c *= p.statuses.cold_fatigue_mult()  # Wet: the cold bites harder
	return Vector2(clampf(h, 0.0, 1.0), clampf(c, 0.0, 1.0))

## The camera offset the weather asks for at time t (metres): thunder's rumble (scaled by how near the
## strike was), heat's slow sway, a shiver's fast tremble. Never longer than shake_m.max; zero with
## IsoCamera.reduce_shake.
func shake_offset(t: float) -> Vector2:
	if IsoCamera.reduce_shake:
		return Vector2.ZERO
	var m: Dictionary = _cfg.get("shake_m", {}) as Dictionary
	var o := Vector2(sin(t * 31.0) + 0.5 * sin(t * 53.0), sin(t * 23.0 + 1.7)) * pow(rumble, 1.5) * float(m.get("thunder", 0.12))
	o += Vector2(sin(t * 2.3) + 0.5 * sin(t * 5.1), sin(t * 1.7 + 0.4)) * heat * float(m.get("heat", 0.012))
	o += Vector2(sin(t * 47.0), sin(t * 39.0 + 0.6)) * shiver * float(m.get("shiver", 0.05))
	return o.limit_length(float(m.get("max", 0.15)))
