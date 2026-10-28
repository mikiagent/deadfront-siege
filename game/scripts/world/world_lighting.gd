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
## Golden hour (80c3c3a6): the sun, the fog and the sky horizon warm toward amber on the way down,
## before night turns them blue. The warmth ramps in over golden_start..golden_full in the profile
## (below) and holds to NIGHT, so a climate can move it (snow at 0.56, desert can start earlier).
## ASSUMPTION: the exact ramp is visual tuning the owner judges.
const GOLDEN_START := 0.56
const GOLDEN_FULL := 0.64
## The sky and fog colours update only on steps at least this large (half a second of a 720 s
## day): every write to the sky colours forces a sky radiance update. The lights update every frame.
const TOD_STEP := 1.0 / 1440.0

## Used when lighting.json is missing or malformed, so a bad edit dims nothing to black.
## It carries the colour keys too: without them _c() returns WHITE, which washed the night fog
## and the whole sky out instead of only losing the tuned values.
const FALLBACK := {"sun_energy": 2.2, "sun_warm_energy_scale": 0.8, "sun_max_elevation_deg": 58.0,
	"moon_energy": 1.1, "moon_energy_compat": 2.0, "moon_elevation_deg": 55.0, "moon_yaw_deg": -70.0, "ambient_energy": 0.3,
	"ambient_night_energy": 0.4, "exposure": 1.0, "exposure_compat": 1.0, "exposure_scale": 1.0,
	"saturation": 1.1, "saturation_compat": 1.1, "glow_intensity": 0.3, "fog_density": 0.0022, "fog_night_density": 0.004,
	"contrast": 1.08, "glow_strength": 0.9, "glow_bloom": 0.04, "glow_hdr_threshold": 1.0,
	"golden_start": 0.56, "golden_full": 0.64,
	"sun_color": [1.0, 0.95, 0.86], "sun_warm_color": [1.0, 0.68, 0.42], "moon_color": [0.52, 0.64, 1.0],
	"fog_color": [0.62, 0.72, 0.82], "fog_dusk_color": [0.74, 0.6, 0.52], "fog_night_color": [0.04, 0.06, 0.11],
	"sky_top": [0.2, 0.42, 0.66], "sky_horizon": [0.66, 0.78, 0.92],
	"sky_dusk_top": [0.22, 0.3, 0.52], "sky_dusk_horizon": [0.88, 0.66, 0.5],
	"sky_night_top": [0.03, 0.05, 0.12], "sky_night_horizon": [0.08, 0.11, 0.2],
	"ground_horizon": [0.24, 0.29, 0.34], "ground_bottom": [0.06, 0.08, 0.1],
	"sun_yaw_deg": [-35.0, -85.0], "fog_sun_scatter": 0.15}

static var _profiles: Dictionary = {}
## 0 by day, 1 at full night (drive() writes it every call). Creature eyeshine scales by it.
static var night: float = 0.0

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var world_env: WorldEnvironment
var profile: Dictionary = {}
var _sky_mat: ProceduralSkyMaterial
var _compat := false
## gl_compatibility only (the web build); _compat also covers the mobile renderer.
var _gl := false
var _last_tod := -1.0
var _fit_key := Vector4.ZERO
## Fog density from the profile and time of day, and the camera's scale on it (fit_shadows).
var _fog_density := 0.0
var _fog_scale := 1.0

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
			push_error("[lighting] %s missing or invalid; using built-in defaults" % PROFILES_PATH)
			_profiles = {"default": FALLBACK}
	var out: Dictionary = (_profiles.get("default", {}) as Dictionary).duplicate()
	out.merge(_profiles.get(climate, {}) as Dictionary, true)
	return out

func _process(_delta: float) -> void:
	# The lights move every frame so the sun and its shadows glide; the sky and fog colours, whose
	# writes force a sky radiance update, still change only once per TOD_STEP.
	drive(Game.time_of_day, absf(Game.time_of_day - _last_tod) >= TOD_STEP)
	fit_shadows(get_viewport().get_camera_3d())

## Godot ignores directional_shadow_max_distance for orthographic cameras and spreads the
## splits over the camera's whole near..far (4000 m by default), so the iso view at 20-60 m
## sat in a 400 m first split: 80 cm texels on the 1024 mobile atlas, shadows of a survivor
## or a pole gone. Splits are fractions of far, so we place them in metres around the
## depth band the camera actually sees (audit: box ratio 0.98 -> 0.48 at atlas 1024).
## A perspective IsoCamera (CAMERA package) stands 90-430 m back with a 4.3 deg lens: Godot honours
## directional_shadow_max_distance there and starts the shadow at the camera's near plane, which
## IsoCamera._apply_zoom keeps close to the focus (_fit_perspective).
## Fog is depth-based, so it thins by the same factor the camera stands further back than the old
## 40 m: the ground at the focus keeps the fog it had.
func fit_shadows(cam: Camera3D) -> void:
	if cam == null or sun == null:
		return
	if cam.projection == Camera3D.PROJECTION_PERSPECTIVE and cam is IsoCamera:
		_fit_perspective(cam as IsoCamera)
		return
	_set_fog_scale(1.0)
	if cam.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return
	# ASSUMPTION: a non-iso orthographic camera looks at ground about 40 m away, as IsoCamera does.
	var depth: float = (cam as IsoCamera).distance if cam is IsoCamera else 40.0
	var key := Vector4(cam.far, cam.size, depth, 0.0)
	if key == _fit_key:
		return
	_fit_key = key
	# Ground at the screen's top and bottom edges is about 0.71 * size nearer / farther than
	# the centre at the iso pitch; 0.75 leaves a margin for tall props and terrain relief.
	var half := 0.75 * cam.size
	var far := maxf(cam.far, depth + half + 10.0)
	for l in [sun, moon]:
		var light := l as DirectionalLight3D
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		light.directional_shadow_split_1 = maxf(depth - half * 0.4, 1.0) / far
		light.directional_shadow_split_2 = (depth + half * 0.3) / far
		light.directional_shadow_split_3 = (depth + half + 5.0) / far
		light.directional_shadow_fade_start = 0.8

## One shadow map over near..end (DirectionalLight3D SHADOW_ORTHOGONAL), end just past the ground at the
## screen's top edge and near (IsoCamera._apply_zoom) just before the crowns at its bottom edge. Measured in
## camera_lab: with near ~105-145 m, gl_compatibility drew no shadows at all from PSSM2/PSSM4 splits at the
## default zoom (Forward+ did, with the splits as fractions of the max distance), and the single map drew
## in both. The 4.3 deg lens keeps the slice's cross-section about the view's size, so one map of a ~60 m
## slice gives 1.6 cm texels on the 4096 desktop atlas and 6.4 cm on the 1024 mobile one, in one pass
## instead of four.
func _fit_perspective(cam: IsoCamera) -> void:
	_set_fog_scale(IsoCamera.ORTHO_DISTANCE / maxf(cam.distance, 1.0))
	var d := cam.distance
	var g := cam.ground_half_depth()
	var key := Vector4(cam.near, cam.far, d, g)
	if key == _fit_key:
		return
	_fit_key = key
	var end := minf(d + g + 6.0, cam.far)
	for l in [sun, moon]:
		var light := l as DirectionalLight3D
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		light.directional_shadow_max_distance = end
		# The fade runs from fade_start * end (metres from the camera) to end: keep it past the
		# screen's top edge (the default 0.8 would fade every shadow on screen at this distance).
		light.directional_shadow_fade_start = clampf((end - 3.0) / end, 0.8, 0.999)

func _set_fog_scale(s: float) -> void:
	if is_equal_approx(s, _fog_scale):
		return
	_fog_scale = s
	var e := world_env.environment if world_env else null
	if e:
		e.fog_density = _fog_density * _fog_scale

func _take_over() -> void:
	# One driver at a time: a lab kit's lighting yields to the island's when one loads.
	var dying: Array[Node] = []
	for other in get_tree().get_nodes_in_group(&"world_lighting"):
		if other != self:
			other.set_process(false)
			other.queue_free()
			dying.append(other)
	add_to_group(&"world_lighting")
	# Every other directional light (main scene, an earlier driver) goes dark, and every
	# WorldEnvironment but the first is emptied: the first one in the tree is the one Godot
	# renders with, so reusing it is the only way our Environment is the one on screen.
	var root := get_tree().root
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		(l as DirectionalLight3D).visible = false
	# Reuse an Environment an earlier driver built: a new Sky per install leaked ~350 KB of GL
	# textures each time on the web renderer (every island travel).
	var reuse: Environment = null
	var envs: Array[WorldEnvironment] = []
	for n in root.find_children("*", "WorldEnvironment", true, false):
		var we := n as WorldEnvironment
		if reuse == null and we.environment != null and we.environment.has_meta(&"world_lighting"):
			reuse = we.environment
		if dying.any(func(d: Node) -> bool: return d.is_ancestor_of(we)):
			we.environment = null
		else:
			envs.append(we)
	for i in envs.size():
		if i == 0:
			world_env = envs[i]
		else:
			envs[i].environment = null
	if world_env == null:
		world_env = WorldEnvironment.new()
		add_child(world_env)
	_compat = RenderingServer.get_current_rendering_method() != "forward_plus"
	_gl = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	world_env.environment = _make_env(reuse)
	sun = _make_light("Sun")
	moon = _make_light("Moon")
	moon.light_color = _c("moon_color")
	moon.rotation_degrees = Vector3(-_f("moon_elevation_deg"), _f("moon_yaw_deg"), 0.0)
	drive(Game.time_of_day)

func _make_env(reuse: Environment = null) -> Environment:
	var e := reuse if reuse != null else Environment.new()
	e.set_meta(&"world_lighting", true)
	e.background_mode = Environment.BG_SKY
	# Sky-lit ambient: shade faces get sky blue from above and dark ground bounce from below,
	# instead of the old flat 0.75 grey-blue fill that washed every frame out.
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = _f("exposure_compat" if _compat else "exposure") * _f("exposure_scale")
	# Colour grade (80c3c3a6, ASSUMPTION values): a little contrast and a soft glow so fire and the
	# sky bloom without the sun clipping. AgX already saturates; the profile's saturation is reused.
	e.glow_enabled = true
	e.glow_intensity = _f("glow_intensity")
	e.glow_strength = _f("glow_strength", 0.9)
	e.glow_bloom = _f("glow_bloom", 0.04)
	e.glow_hdr_threshold = _f("glow_hdr_threshold", 1.0)
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_contrast = _f("contrast", 1.08)
	e.adjustment_saturation = _f("saturation_compat" if _gl else "saturation")  # web renderer only, like moon_energy_compat
	e.fog_enabled = true
	e.fog_sun_scatter = _f("fog_sun_scatter")
	e.fog_aerial_perspective = 0.2
	if e.sky == null:
		e.sky = Sky.new()
	_sky_mat = e.sky.sky_material as ProceduralSkyMaterial
	if _sky_mat == null:
		_sky_mat = ProceduralSkyMaterial.new()
		e.sky.sky_material = _sky_mat
	_sky_mat.ground_bottom_color = _c("ground_bottom")
	_sky_mat.ground_horizon_color = _c("ground_horizon")
	return e

func _make_light(light_name: String) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = light_name
	l.shadow_enabled = true
	# PSSM4 with splits fitted to the iso camera's depth band (fit_shadows); max_distance only
	# applies to perspective cameras.
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	l.directional_shadow_max_distance = 100.0
	l.directional_shadow_blend_splits = not _compat
	l.shadow_bias = 0.1
	# Godot's default. Once the splits fit, texels are 2-7 cm and 1.0 no longer stripes the dusk
	# terrain (the old 2.0 was hiding 80 cm texels, and erased every thin caster's shadow).
	l.shadow_normal_bias = 1.0
	add_child(l)
	return l

## Sun path, colour and energy, the moon, ambient, fog and sky for tod (0 = midnight).
## sky=false moves only the lights (per frame); the environment and sky follow on the next step.
func drive(tod: float, sky: bool = true) -> void:
	if sun == null:
		return
	if sky:
		_last_tod = tod
	var day_t := clampf((tod - DAWN) / (NIGHT - DAWN), 0.0, 1.0)
	var sun_up := smoothstep(DAWN - 0.02, DAWN + 0.03, tod) * (1.0 - smoothstep(NIGHT - 0.03, NIGHT + 0.02, tod))
	# Warm inside the dawn and dusk phases only: it fades out over the last 0.04 of dawn and in
	# over the first 0.02 of dusk, so the whole day phase (DAY..DUSK) is neutral.
	var warm := maxf(1.0 - smoothstep(DAY - 0.04, DAY, tod), smoothstep(DUSK, DUSK + 0.02, tod))
	# Golden hour before night (80c3c3a6): the low sun, the fog and the sky horizon warm toward the
	# profile's dusk colours while it is still up, then the night lerp takes them blue.
	var golden := smoothstep(_f("golden_start", GOLDEN_START), _f("golden_full", GOLDEN_FULL), tod) * (1.0 - smoothstep(NIGHT - 0.04, NIGHT - 0.01, tod))
	var night := 1.0 - sun_up
	WorldLighting.night = night
	var elevation := maxf(MIN_ELEVATION_DEG, _f("sun_max_elevation_deg") * sin(PI * day_t))
	# The iso camera looks down yaw 45; a sun near that axis hides each shadow behind its
	# caster. The yaw band keeps the sun 80-130 deg off it while it crosses the sky.
	var yaw_band: Array = profile.get("sun_yaw_deg", [-35.0, -85.0])
	sun.rotation_degrees = Vector3(-elevation, lerpf(float(yaw_band[0]), float(yaw_band[1]), day_t), 0.0)
	# Dawn, golden hour and dusk all use the profile's warm sun; the stronger of the two ramps wins.
	var warmth := maxf(warm, golden)
	sun.light_color = _c("sun_color").lerp(_c("sun_warm_color"), warmth)
	sun.light_energy = _f("sun_energy") * lerpf(1.0, _f("sun_warm_energy_scale"), warmth) * sun_up
	sun.visible = sun_up > 0.001
	# The web renderer's night came out a third as bright (lighting_lab night_lum 0.033 vs 0.10).
	moon.light_energy = _f("moon_energy_compat" if _gl else "moon_energy") * night
	moon.visible = night > 0.001
	# One shadowed light at a time: two would halve the atlas each and double the shadow passes
	# through dawn and dusk; the moon casts once the sun has set.
	moon.shadow_enabled = not sun.visible
	var e := world_env.environment if world_env else null
	if e == null or not sky:
		return
	# Dusk and the golden hour are the same intent (an amber sky while the sun is low); dusk only
	# adds the part of the ramp that runs after DUSK. Take the stronger of the two, never their sum.
	var dusk_w := maxf(warm * sun_up, golden)
	e.ambient_light_energy = lerpf(_f("ambient_energy"), _f("ambient_night_energy"), night)
	e.fog_light_color = _c("fog_color").lerp(_c("fog_dusk_color"), dusk_w).lerp(_c("fog_night_color"), night)
	_fog_density = lerpf(_f("fog_density"), _f("fog_night_density"), night)
	e.fog_density = _fog_density * _fog_scale
	_sky_mat.sky_top_color = _c("sky_top").lerp(_c("sky_dusk_top"), dusk_w).lerp(_c("sky_night_top"), night)
	_sky_mat.sky_horizon_color = _c("sky_horizon").lerp(_c("sky_dusk_horizon"), dusk_w).lerp(_c("sky_night_horizon"), night)

func _f(key: String, dflt: float = 0.0) -> float:
	return float(profile.get(key, dflt))

func _c(key: String) -> Color:
	var a: Variant = profile.get(key, [1.0, 1.0, 1.0])
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return Color.WHITE
