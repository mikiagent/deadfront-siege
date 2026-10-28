class_name WorldWeather
extends RefCounted
## Island weather (WEATHER, owner 2026-10-28: rain; rain and lightning, infrequent, the ground shaking when
## the thunder arrives after the flash; heat with an orange edge, a shimmer and a slight shake; cold with a
## blue-white edge, frost around the outside and infrequent shivers when getting cold and defrosting).
## This holds the state: rain spells (particles, the Wet status), storms (lightning, then thunder after the
## sound's travel time), and the heat / cold the survivor feels, from the same unmet climate resistance
## that climate fatigue charges. WeatherFx draws it. The per-frame climate and level-gap fatigue feed for
## the player rides the same tick. Numbers: data/world/rules.json "weather".

## Sound hooks (no audio assets exist yet): a strike, and its thunder distance / sound_mps later.
signal lightning(distance_m: float)
signal thunder(distance_m: float)

const STATES: Array[StringName] = [&"clear", &"rain", &"storm", &"heat", &"cold"]
## --weather=rain|storm|heat|cold|clear holds that state (labs, shots, tests); &"" lets the climate roll.
static var forced: StringName = &""

var raining: bool = false
var storm: bool = false
var _rain_left: float = 0.0
var _rain_cd: float = 40.0
var _wet_refresh: float = 0.0
var _rain_fx: GPUParticles3D
var _climate := "grassland"
var _cfg: Dictionary = {}
var _flash_cd := 3.0
var _flash_t := -1.0
var _flash_peak := 0.0
## 0..1 lightning brightness this frame: a double flicker that dies in about half a second.
var flash := 0.0
## [seconds left, distance m] per thunder clap still on its way.
var pending: Array = []
## 0..1 rumble of the latest thunder, gone in 1.5 s.
var rumble := 0.0
## 0..1, eased: the grey wash and sun dimming of rain (1 in a storm).
var rain_amount := 0.0
var heat := 0.0
var cold := 0.0
## Creeps in behind cold (about 8 s) and melts a little faster.
var frost := 0.0
## 0..1 shiver burst (getting cold, defrosting, and now and then while cold).
var shiver := 0.0
var _chilled := false
var _shiver_cd := 0.0
var fx: WeatherFx

func install(rt: IslandRuntime) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weather="):
			forced = StringName(a.substr(10))
	_climate = rt._climate
	_cfg = Data.world_rules.get("weather", {}) as Dictionary
	_rain_cd = float(_cfg.get("first_check_s", 40.0))
	_rain_fx = GPUParticles3D.new()
	_rain_fx.emitting = false
	_rain_fx.amount = 400
	_rain_fx.lifetime = 0.9
	_rain_fx.visibility_aabb = AABB(Vector3(-40, -4, -40), Vector3(80, 20, 80))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 4.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -14, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(18, 0.2, 18)
	mat.color = Color(0.65, 0.75, 0.9, 0.7)
	_rain_fx.process_material = mat
	# A 2-triangle streak (was a 4,224-triangle sphere) whose material takes the particle colour;
	# without vertex_color_use_as_albedo every drop rendered plain white.
	var draw := QuadMesh.new()
	draw.size = Vector2(0.025, 0.5)
	var streak := StandardMaterial3D.new()
	streak.vertex_color_use_as_albedo = true
	streak.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	streak.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw.material = streak
	_rain_fx.draw_pass_1 = draw
	_rain_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rt.add_child(_rain_fx)
	fx = WeatherFx.new()
	fx.weather = self
	rt.add_child(fx)

func tick(rt: IslandRuntime, delta: float) -> void:
	var p := PlayerRegistry.local()
	_tick_sky(delta)
	if raining and p:
		# Refresh once a second, not every frame, so the status log and its bookkeeping stay quiet.
		_wet_refresh -= delta
		if _wet_refresh <= 0.0 or not p.statuses.has(&"wet"):
			p.statuses.apply(&"wet", null)
			_wet_refresh = 1.0
	if _rain_fx:
		if raining and p:
			_rain_fx.global_position = p.global_position + Vector3(0, 10, 0)
		_rain_fx.emitting = raining
		_rain_fx.amount_ratio = 1.0 if storm else 0.6
	rain_amount = move_toward(rain_amount, (1.0 if storm else 0.7) if raining else 0.0, delta / 3.0)
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

## The climate's chance of `kind` ("rain" per check, "storm" per rain spell), 0 when it lists none.
func chance(climate: String, kind: String) -> float:
	return float(((_cfg.get("climates", {}) as Dictionary).get(climate, {}) as Dictionary).get(kind, 0.0))

func _range(key: String, fallback: Vector2) -> float:
	var r: Variant = _cfg.get(key, [fallback.x, fallback.y])
	return randf_range(float(r[0]), float(r[1])) if r is Array and (r as Array).size() == 2 else fallback.x

func _tick_sky(delta: float) -> void:
	if forced == &"rain" or forced == &"storm":
		if not storm and forced == &"storm":
			_flash_cd = 2.0
		raining = true
		storm = forced == &"storm"
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
	_rain_left = _range("storm_len_s" if storm else "rain_len_s", Vector2(18, 30))
	_flash_cd = 3.0
	print("[world] rain storm=%s" % storm)

func _tick_storm(delta: float) -> void:
	if storm:
		_flash_cd -= delta
		if _flash_cd <= 0.0:
			strike(_range("lightning_m", Vector2(400, 3000)))
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
			rumble = maxf(rumble, 0.35 + 0.65 * _near(d))
			thunder.emit(d)
	rumble = move_toward(rumble, 0.0, delta / 1.5)

## A lightning strike `distance_m` away: the flash now, its thunder distance / sound_mps later.
func strike(distance_m: float) -> void:
	_flash_t = 0.0
	_flash_peak = 0.55 + 0.45 * _near(distance_m)
	flash = _flash_peak
	_flash_cd = _range("lightning_gap_s", Vector2(8, 20))
	pending.append([thunder_delay(distance_m), distance_m])
	lightning.emit(distance_m)

func thunder_delay(distance_m: float) -> float:
	return distance_m / float(_cfg.get("sound_mps", 343.0))

## 1 at the nearest strike distance, 0 at the farthest.
func _near(distance_m: float) -> float:
	var r: Variant = _cfg.get("lightning_m", [400.0, 3000.0])
	return 1.0 - clampf((distance_m - float(r[0])) / maxf(1.0, float(r[1]) - float(r[0])), 0.0, 1.0)

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
## Wet / Quenched cool the heat and sitting by a fire warms the cold, as they scale the fatigue.
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
	return Vector2(clampf(h, 0.0, 1.0), clampf(c, 0.0, 1.0))

## The camera offset the weather asks for at time t (metres): thunder's rumble, heat's slow sway, a
## shiver's fast tremble. Never longer than shake_m.max; zero with IsoCamera.reduce_shake.
func shake_offset(t: float) -> Vector2:
	if IsoCamera.reduce_shake:
		return Vector2.ZERO
	var m: Dictionary = _cfg.get("shake_m", {}) as Dictionary
	var o := Vector2(sin(t * 31.0) + 0.5 * sin(t * 53.0), sin(t * 23.0 + 1.7)) * pow(rumble, 1.5) * float(m.get("thunder", 0.12))
	o += Vector2(sin(t * 2.3) + 0.5 * sin(t * 5.1), sin(t * 1.7 + 0.4)) * heat * float(m.get("heat", 0.012))
	o += Vector2(sin(t * 47.0), sin(t * 39.0 + 0.6)) * shiver * float(m.get("shiver", 0.05))
	return o.limit_length(float(m.get("max", 0.15)))
