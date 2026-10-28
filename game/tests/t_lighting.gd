extends SceneTree
## W1-LIGHT checks on the shared WorldLighting and the rain layer. Headless-safe: it inspects
## light and environment state, not pixels (lighting_lab measures pixels). Prints
## "[t_light] PASS" or one FAIL line per broken check; exits 0 / 1.

var failures: Array[String] = []
var _done := false
# Loaded on the first frame, not named: `godot --script` compiles this file before the
# autoloads exist, and these scripts reference Game and Data.
var WL: GDScript

## WorldLighting.install reads Game and the profiles; autoloads exist only from the first frame.
func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("Game") == null:
		return false
	_done = true
	WL = load("res://scripts/world/world_lighting.gd")
	var host := Node3D.new()
	get_root().add_child(host)
	var wl = WL.install(host, "temperate")
	_test_environment(wl)
	_test_night(wl)
	_test_warm_dawn_dusk(wl)
	_test_moon_shadow_only_at_night(wl)
	_test_shadow_fit(wl)
	_test_shadow_fit_perspective(wl)
	_test_key_light_never_from_below(wl)
	_test_phase_thresholds()
	_test_profiles()
	_test_fallback_colours()
	_test_rain_streaks()
	_test_env_reused(host, wl)
	_test_sun_moves_every_frame(wl)
	# Both tags: t_light.gd is an alias that extends this file, and the gates grep for the running
	# file's name (job confs use both TEST=t_lighting and RELATED="t_light").
	if failures.is_empty():
		print("[t_light] PASS")
		print("[t_lighting] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_light] FAIL %s" % f)
		quit(1)
	return true

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)

func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

func _test_environment(wl) -> void:
	var e: Environment = wl.world_env.environment
	_check(e.tonemap_mode == Environment.TONE_MAPPER_AGX, "tonemap is not AgX")
	_check(e.glow_enabled, "glow off")
	_check(e.ambient_light_source == Environment.AMBIENT_SOURCE_SKY, "ambient is not sky-sourced")
	_check((wl.sun as DirectionalLight3D).directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "sun shadows are not PSSM4")
	_check((wl.sun as DirectionalLight3D).shadow_normal_bias <= 1.0, "sun normal bias above 1.0 erases thin casters' shadows")

func _test_night(wl) -> void:
	wl.drive(0.0)
	var fog: Color = wl.world_env.environment.fog_light_color
	_check(_lum(fog) <= 0.15, "night fog luminance %.3f > 0.15" % _lum(fog))
	_check(wl.moon.visible and wl.moon.light_energy > 0.0, "no active moon at tod 0.0")
	_check(not wl.sun.visible, "sun still lit at tod 0.0")

func _test_warm_dawn_dusk(wl) -> void:
	for tod in [0.27, 0.73]:
		wl.drive(tod)
		var c: Color = wl.sun.light_color
		_check(wl.sun.visible and c.r / maxf(c.b, 0.001) >= 1.3, "sun R/B %.2f < 1.3 at tod %.2f" % [c.r / maxf(c.b, 0.001), tod])
	# The whole day phase is neutral: warmth must not leak past DAY or before DUSK.
	var neutral: Color = wl._c("sun_color")
	for tod in [WL.DAY, WL.DAY + 0.02, 0.5, WL.DUSK - 0.02, WL.DUSK]:
		wl.drive(tod)
		_check((wl.sun.light_color as Color).is_equal_approx(neutral), "sun is warm at day-phase tod %.2f" % tod)

## Only one directional light renders shadows at a time (the atlas and passes are shared).
func _test_moon_shadow_only_at_night(wl) -> void:
	for tod in [0.0, 0.2, 0.23, 0.42, 0.79, 0.85]:
		wl.drive(tod)
		_check(not (wl.sun.visible and wl.moon.visible and wl.moon.shadow_enabled), "sun and moon both cast shadows at tod %.2f" % tod)
	wl.drive(0.0)
	_check(wl.moon.shadow_enabled, "moon casts no shadow at night")

## An iso camera with Godot's default far (4000 m) must still get splits around the 20-60 m it
## sees: before the fit the first split ran 0-400 m and thin casters lost their shadows.
func _test_shadow_fit(wl) -> void:
	var cam: Camera3D = load("res://scripts/camera/iso_camera.gd").new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 15.0
	cam.set("distance", 40.0)
	cam.far = 4000.0
	wl.fit_shadows(cam)
	var s: DirectionalLight3D = wl.sun
	var m := [s.directional_shadow_split_1 * cam.far, s.directional_shadow_split_2 * cam.far, s.directional_shadow_split_3 * cam.far]
	_check(m[0] > 20.0 and m[0] < 40.0 and m[1] > 40.0 and m[1] < 50.0 and m[2] > 50.0 and m[2] < 70.0,
		"shadow splits at %.0f / %.0f / %.0f m, not fitted to the iso band 20-70 m" % m)
	cam.free()

## The perspective IsoCamera (CAMERA package) stands ~150 m back with a 4.3 deg lens. The fit uses one
## shadow map from the camera's near plane to just past the ground's top edge (not Godot's 100 m default,
## which is nearer than the ground: no shadows at all), fades only past that edge, and goes back to PSSM4
## for an orthographic camera. Fog thins by 40 m / distance.
func _test_shadow_fit_perspective(wl) -> void:
	var cam = load("res://scripts/camera/iso_camera.gd").new()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 4.3
	cam.size = 11.0
	cam.rotation_degrees = Vector3(-38.7, 45.0, 0.0)
	cam._apply_zoom()
	wl.drive(0.5)
	wl.fit_shadows(cam)
	var s: DirectionalLight3D = wl.sun
	var d: float = cam.distance
	var g: float = cam.ground_half_depth()
	var mx := s.directional_shadow_max_distance
	_check(d > 120.0 and d < 170.0 and cam.near > 90.0 and cam.near < d - g - 20.0 and cam.far > d + g + 20.0,
		"perspective camera at %.0f m, near %.0f far %.0f: not a tight band around the focus" % [d, cam.near, cam.far])
	_check(s.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL and (wl.moon as DirectionalLight3D).directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL,
		"perspective shadows are not one map (gl_compatibility drew no split shadows this far out)")
	_check(mx > d + g and mx < d + g + 15.0, "perspective shadows end at %.0f m, not just past the ground's top edge (%.0f m)" % [mx, d + g])
	_check(s.directional_shadow_fade_start * mx >= d + g, "perspective shadows fade from %.0f m, on screen (ground ends %.0f m)" % [s.directional_shadow_fade_start * mx, d + g])
	var e: Environment = wl.world_env.environment
	var want: float = lerpf(wl._f("fog_density"), wl._f("fog_night_density"), 0.0) * 40.0 / d
	_check(absf(e.fog_density - want) < 1e-6, "perspective fog %.5f, not the profile's thinned by 40 m / %.0f m (%.5f)" % [e.fog_density, d, want])
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	wl.fit_shadows(cam)
	_check(s.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "an orthographic camera does not get PSSM4 back")
	_check(absf(e.fog_density - lerpf(wl._f("fog_density"), wl._f("fog_night_density"), 0.0)) < 1e-6, "fog does not return to the profile's density for an orthographic camera")
	cam.free()

## Every lit directional light points down (its -Z has a negative y) at every time of day.
func _test_key_light_never_from_below(wl) -> void:
	for i in 201:
		var tod := float(i) / 200.0
		wl.drive(tod)
		for l in [wl.sun, wl.moon]:
			var light := l as DirectionalLight3D
			if light.visible and light.light_energy > 0.0 and (-light.global_basis.z).y >= 0.0:
				failures.append("%s points up at tod %.3f" % [light.name, tod])
				return

## WorldLighting's dawn/dusk keys must match Game.phase_name(), which owns the thresholds.
func _test_phase_thresholds() -> void:
	var game := get_root().get_node("Game")
	var keep: float = game.time_of_day
	var want := {WL.DAWN - 0.001: &"night", WL.DAWN: &"dawn", 0.27: &"dawn",
		WL.DAY: &"day", WL.DUSK: &"dusk", 0.73: &"dusk", WL.NIGHT: &"night"}
	for tod in want:
		game.time_of_day = tod
		_check(game.phase_name() == want[tod], "phase at %.3f is %s, lighting expects %s" % [tod, game.phase_name(), want[tod]])
	game.time_of_day = keep

## Every climate has its own profile, and day keeps sun 2.0-2.5 against ambient 0.25-0.35.
func _test_profiles() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(WL.PROFILES_PATH))
	_check(raw is Dictionary, "lighting.json does not parse")
	if not raw is Dictionary:
		return
	var data := get_root().get_node("Data")
	for climate in data.world_climates:
		if str(climate).begins_with("_"):
			continue
		_check((raw as Dictionary).has(climate), "lighting.json has no profile for climate %s" % climate)
		var p: Dictionary = WL.profile_for(str(climate))
		var sun := float(p.get("sun_energy", 0.0))
		var amb := float(p.get("ambient_energy", 0.0))
		_check(sun >= 2.0 and sun <= 2.5 and amb >= 0.25 and amb <= 0.35, "%s sun %.2f / ambient %.2f out of band" % [climate, sun, amb])

## A broken lighting.json falls back to FALLBACK: that profile must still give a dark night fog
## and a sky, not _c()'s WHITE for every missing colour.
func _test_fallback_colours() -> void:
	var host := Node3D.new()
	get_root().add_child(host)
	var saved: Dictionary = WL._profiles
	WL._profiles = {"default": WL.FALLBACK.duplicate()}
	# install() reuses the viewport's environment and nulls the previous owners: put it back after.
	var keep_env: Environment = null
	for we in get_root().find_children("*", "WorldEnvironment", true, false):
		if (we as WorldEnvironment).environment != null:
			keep_env = (we as WorldEnvironment).environment
			break
	var wl = WL.install(host, "temperate")
	wl.drive(0.0)
	var e: Environment = wl.world_env.environment
	var fog_l: float = _lum(e.fog_light_color)
	var sky: Color = wl._sky_mat.sky_top_color
	print("[t_light] fallback: night fog lum=%.3f sky_night_top=%s fog=%s" % [fog_l, sky, e.fog_light_color])
	_check(WL.FALLBACK.has("saturation_compat") and WL.FALLBACK.has("saturation"), "FALLBACK carries both saturation keys")
	_check(fog_l <= 0.15, "FALLBACK night fog luminance %.3f > 0.15" % fog_l)
	_check(sky.r + sky.g + sky.b < 0.5, "FALLBACK night sky is not white (%s)" % sky)
	WL._profiles = saved
	# install() took over the viewport's environment and the test host owns this one: hand the
	# original back before the host (and its WorldEnvironment) is freed.
	for we in get_root().find_children("*", "WorldEnvironment", true, false):
		if (we as WorldEnvironment).environment == null:
			(we as WorldEnvironment).environment = keep_env
			break
	wl.set_process(false)
	host.free()

func _test_rain_streaks() -> void:
	var rt: Node3D = load("res://scripts/world/island_runtime.gd").new()
	get_root().add_child(rt)
	var weather = load("res://scripts/world/world_weather.gd").new()
	weather.install(rt)
	var fx := rt.find_children("*", "GPUParticles3D", false, false)
	_check(fx.size() == 1, "rain layer missing")
	if fx.is_empty():
		return
	var rain := fx[0] as GPUParticles3D
	var mat := (rain.draw_pass_1 as PrimitiveMesh).material as StandardMaterial3D if rain.draw_pass_1 is PrimitiveMesh else null
	_check(mat != null and mat.vertex_color_use_as_albedo, "rain draw pass material ignores particle colour")
	_check(rain.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "rain casts shadows")
	_check(rain.draw_pass_1.get_faces().size() / 3 <= 2, "rain drop mesh has %d triangles" % (rain.draw_pass_1.get_faces().size() / 3))

## A second install (lab kit, then island) reuses the Environment and Sky instead of leaking
## new GL sky textures on the web renderer.
func _test_env_reused(host: Node3D, wl) -> void:
	var env: Environment = wl.world_env.environment
	var sky: Sky = env.sky
	var wl2 = WL.install(host, "temperate")
	_check(wl2.world_env.environment == env and wl2.world_env.environment.sky == sky, "second install built a new Environment or Sky")

## Owner 2026-10-21: the sun ticked in half-second steps instead of gliding. A time step far below
## TOD_STEP must still move the sun on the next frame, while the sky colours wait for a full step.
func _test_sun_moves_every_frame(wl) -> void:
	var game: Node = get_root().get_node("Game")
	wl.drive(0.4)
	var before: Vector3 = (wl.sun as DirectionalLight3D).rotation_degrees
	var sky_before: Color = wl._sky_mat.sky_top_color
	game.time_of_day = 0.4 + WL.TOD_STEP * 0.1
	wl._process(0.016)
	var after: Vector3 = (wl.sun as DirectionalLight3D).rotation_degrees
	_check(not after.is_equal_approx(before), "sun did not move on a sub-step frame (it ticks every TOD_STEP)")
	_check(wl._sky_mat.sky_top_color == sky_before, "sky colours rewritten on a sub-step frame (sky radiance update every frame)")
