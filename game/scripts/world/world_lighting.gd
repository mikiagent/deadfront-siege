class_name WorldLighting
extends Node
## The one lighting builder for islands and labs: sun, moon, sky-lit ambient, AgX exposure,
## fog and glow from a per-climate profile in data/world/lighting.json, driven by time of day.

const PROFILES_PATH := "res://data/world/lighting.json"
## Mirrors Game.phase_name(): dawn starts, day starts, dusk starts, night starts.
const DAWN := 0.22
const DAY := 0.30
const DUSK := 0.72
const NIGHT := 0.80
## The key light never drops below this, so it never points up from under the horizon.
const MIN_ELEVATION_DEG := 6.0

static var _profiles: Dictionary = {}

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var world_env: WorldEnvironment
var profile: Dictionary = {}
var _sky_mat: ProceduralSkyMaterial
var _compat := false

## Takes over the scene's lighting under host for climate; the node then drives day/night.
static func install(host: Node, climate: String = "temperate") -> WorldLighting:
	var wl := WorldLighting.new()
	wl.name = "WorldLighting"
	wl.profile = profile_for(climate)
	host.add_child(wl)
	wl._take_over()
	return wl

## default merged with the climate's overrides; unknown climates get default.
static func profile_for(climate: String) -> Dictionary:
	if _profiles.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILES_PATH))
		if parsed is Dictionary:
			_profiles = parsed
		else:
			push_error("[lighting] %s missing or invalid" % PROFILES_PATH)
	var out: Dictionary = (_profiles.get("default", {}) as Dictionary).duplicate()
	out.merge(_profiles.get(climate, {}) as Dictionary, true)
	return out

func _process(_delta: float) -> void:
	drive(Game.time_of_day)

func _take_over() -> void:
	# One driver at a time: a lab kit's lighting yields to the island's when one loads.
	for other in get_tree().get_nodes_in_group(&"world_lighting"):
		if other != self:
			other.set_process(false)
			other.queue_free()
	add_to_group(&"world_lighting")
	# Every other directional light (main scene, an earlier driver) goes dark, and every
	# WorldEnvironment but the first is emptied: the first one in the tree is the one Godot
	# renders with, so reusing it is the only way our Environment is the one on screen.
	var root := get_tree().root
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		(l as DirectionalLight3D).visible = false
	var envs := root.find_children("*", "WorldEnvironment", true, false)
	for i in envs.size():
		var we := envs[i] as WorldEnvironment
		if i == 0:
			world_env = we
		else:
			we.environment = null
	if world_env == null:
		world_env = WorldEnvironment.new()
		add_child(world_env)
	_compat = RenderingServer.get_current_rendering_method() != "forward_plus"
	world_env.environment = _make_env()
	sun = _make_light("Sun")
	moon = _make_light("Moon")
	moon.light_color = _c("moon_color")
	moon.rotation_degrees = Vector3(-_f("moon_elevation_deg"), _f("moon_yaw_deg"), 0.0)
	drive(Game.time_of_day)

func _make_env() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	# Sky-lit ambient: shade faces get sky blue from above and dark ground bounce from below,
	# instead of the old flat 0.75 grey-blue fill that washed every frame out.
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = _f("exposure_compat" if _compat else "exposure") * _f("exposure_scale")
	e.glow_enabled = true
	e.glow_intensity = _f("glow_intensity")
	e.glow_hdr_threshold = 1.0
	e.adjustment_enabled = true
	e.adjustment_saturation = _f("saturation")
	e.fog_enabled = true
	e.fog_sun_scatter = _f("fog_sun_scatter")
	e.fog_aerial_perspective = 0.2
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.ground_bottom_color = _c("ground_bottom")
	_sky_mat.ground_horizon_color = _c("ground_horizon")
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	e.sky = sky
	return e

func _make_light(light_name: String) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = light_name
	l.shadow_enabled = true
	# PSSM, not orthogonal: one orthogonal map stretched over 60 m left every caster's shadow
	# a faint smear (audit verifier: box shadow ratio 0.989 -> 0.694 with 4 splits).
	# Four splits on every renderer: with two, everything the iso camera sees (20-60 m away)
	# landed in one 10-100 m split and the web renderer drew blocky, striped shadows.
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	l.directional_shadow_max_distance = 100.0
	l.directional_shadow_blend_splits = not _compat
	l.shadow_bias = 0.1
	# Godot's default normal bias: 1.0 striped the low dusk sun across the terrain on the web renderer.
	l.shadow_normal_bias = 2.0
	add_child(l)
	return l

## Sun path, colour and energy, the moon, ambient, fog and sky for tod (0 = midnight).
func drive(tod: float) -> void:
	if sun == null:
		return
	var day_t := clampf((tod - DAWN) / (NIGHT - DAWN), 0.0, 1.0)
	var sun_up := smoothstep(DAWN - 0.02, DAWN + 0.03, tod) * (1.0 - smoothstep(NIGHT - 0.03, NIGHT + 0.02, tod))
	# Warm through dawn and dusk, neutral from shortly after DAY until shortly before DUSK.
	var warm := maxf(1.0 - smoothstep(DAY, DAY + 0.08, tod), smoothstep(DUSK - 0.08, DUSK, tod))
	var night := 1.0 - sun_up
	var elevation := maxf(MIN_ELEVATION_DEG, _f("sun_max_elevation_deg") * sin(PI * day_t))
	# The iso camera looks down yaw 45; a sun near that axis hides each shadow behind its
	# caster. The yaw band keeps the sun 80-130 deg off it while it crosses the sky.
	var yaw_band: Array = profile.get("sun_yaw_deg", [-35.0, -85.0])
	sun.rotation_degrees = Vector3(-elevation, lerpf(float(yaw_band[0]), float(yaw_band[1]), day_t), 0.0)
	sun.light_color = _c("sun_color").lerp(_c("sun_warm_color"), warm)
	sun.light_energy = _f("sun_energy") * lerpf(1.0, _f("sun_warm_energy_scale"), warm) * sun_up
	sun.visible = sun_up > 0.001
	moon.light_energy = _f("moon_energy") * night
	moon.visible = night > 0.001
	var e := world_env.environment if world_env else null
	if e == null:
		return
	var dusk_w := warm * sun_up
	e.ambient_light_energy = lerpf(_f("ambient_energy"), _f("ambient_night_energy"), night)
	e.fog_light_color = _c("fog_color").lerp(_c("fog_dusk_color"), dusk_w).lerp(_c("fog_night_color"), night)
	e.fog_density = lerpf(_f("fog_density"), _f("fog_night_density"), night)
	_sky_mat.sky_top_color = _c("sky_top").lerp(_c("sky_dusk_top"), dusk_w).lerp(_c("sky_night_top"), night)
	_sky_mat.sky_horizon_color = _c("sky_horizon").lerp(_c("sky_dusk_horizon"), dusk_w).lerp(_c("sky_night_horizon"), night)

func _f(key: String) -> float:
	return float(profile.get(key, 0.0))

func _c(key: String) -> Color:
	var a: Variant = profile.get(key, [1.0, 1.0, 1.0])
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return Color.WHITE
