class_name SkyShadows
extends Node
## SKYSHADOWS (owner 2026-10-28, polish and performance patch): soft cloud shadows drifting across
## the island with the wind, a small dip in the sun while a cloud covers the survivor, and the
## shadows of 1-3 pteranodons gliding in wide circles overhead with an occasional flap.
##
## Nothing is drawn in the sky. The IsoCamera's 4.3 deg lens sees a ~40 x 22 m patch of ground, so a
## 6 m flyer inside the frustum would span a sixth of the screen in its middle, not glimpse past an
## edge: only the shadows are shown. They are a darkening term (shaders/sky/sky_shadow.gdshaderinc)
## in the terrain, grass, ground-cover and card shaders, driven by six global shader parameters this
## node writes once a frame. No nodes, meshes or decals per flyer or cloud, so it works the same on
## the web Compatibility renderer and on phones.
##
## Quality: `enabled` is off on a phone browser (the lowest tier) and with --skyshadows=off;
## set_enabled() flips it at runtime. Off writes zero strengths, so every shader falls through.
## Per-climate density lives in data/world/sky.json.

const CONFIG_PATH := "res://data/world/sky.json"
## Must match SKY_CLOUD_TILE_M and SKY_CLOUD_SOFT in sky_shadow.gdshaderinc.
const CLOUD_TILE_M := 240.0
const CLOUD_SOFT := 0.08
const CLOUD_PX := 256
const MAX_FLYERS := 3
const FLYER_PARAMS: Array[StringName] = [&"sky_flyer_0", &"sky_flyer_1", &"sky_flyer_2"]
## ASSUMPTION: the circles sit 14-30 m around a point that trails the survivor by ~12 s and wanders
## 10 m, so a shadow crosses the ~25 x 20 m view every few circles instead of never or constantly.
const RADIUS_M := 14.0
const RADIUS_STEP_M := 8.0
const WANDER_M := 10.0
const ANCHOR_LAG_S := 12.0
## A flap: two wing beats over FLAP_S once every FLAP_EVERY_S, the span folding to 72 % on each.
const FLAP_S := 1.4
const FLAP_EVERY_S := 9.0
const FLAP_FOLD := 0.28

static var enabled: bool = enabled_for(OS.has_feature("web_android") or OS.has_feature("web_ios"),
	OS.get_cmdline_user_args())
static var _cfg_all: Dictionary = {}
## One cloud image and texture for every island: rebuilding them per travel would leak GL textures
## on the web renderer like the old per-install Sky did (WorldLighting._take_over).
static var _cloud_img: Image
static var _cloud_tex: ImageTexture

var lighting: WorldLighting
var cloud_threshold := 0.5
var cloud_strength := 0.0
var wind := Vector2.ZERO
var sun_dip := 0.0
var flyer_count := 0
var flyer_strength := 0.0
var glide_mps := 9.0
## What the last frame wrote (the headless test reads these; the dummy renderer keeps no globals).
var last_cloud := Vector4.ZERO
var last_flyers := PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])
var last_wing := Vector4(1, 1, 1, 0)
## Smoothed cloud cover over the survivor, 0..1, and the sun multiplier it applied last frame.
var cover_here := 0.0
var sun_scale := 1.0
var _t := 0.0
var _cloud_off := Vector2.ZERO
var _anchor := Vector2.ZERO
var _anchored := false

## Off on a phone browser (ASSUMPTION: the lowest web/mobile tier; native phones and desktop web
## keep it) unless --skyshadows=on; --skyshadows=off (or --no-skyshadows) turns it off anywhere.
static func enabled_for(web_phone: bool, args: PackedStringArray) -> bool:
	if "--skyshadows=off" in args or "--no-skyshadows" in args:
		return false
	if "--skyshadows=on" in args:
		return true
	return not web_phone

static func install(host: Node, climate: String, wl: WorldLighting) -> SkyShadows:
	var s := SkyShadows.new()
	s.name = "SkyShadows"
	s.lighting = wl
	s.configure(config_for(climate))
	host.add_child(s)
	return s

## default merged with the climate's overrides.
static func config_for(climate: String) -> Dictionary:
	if _cfg_all.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		_cfg_all = parsed if parsed is Dictionary else {"default": {}}
		if not parsed is Dictionary:
			push_error("[sky] %s missing or invalid; sky shadows use built-in defaults" % CONFIG_PATH)
	var out: Dictionary = (_cfg_all.get("default", {}) as Dictionary).duplicate()
	out.merge(_cfg_all.get(climate, {}) as Dictionary, true)
	return out

static func set_enabled(on: bool, tree: SceneTree) -> void:
	enabled = on
	print("[sky] shadows %s" % ("on" if on else "off"))
	for n in tree.get_nodes_in_group(&"sky_shadows"):
		(n as SkyShadows)._apply_enabled()

func configure(cfg: Dictionary) -> void:
	_ensure_cloud()
	cloud_threshold = _threshold_for(clampf(float(cfg.get("cloud_cover", 0.4)), 0.0, 1.0))
	cloud_strength = float(cfg.get("cloud_strength", 0.6))
	var w: Variant = cfg.get("wind_mps", [1.8, 0.8])
	wind = Vector2(float(w[0]), float(w[1])) if w is Array and (w as Array).size() >= 2 else Vector2(1.8, 0.8)
	sun_dip = clampf(float(cfg.get("sun_dip", 0.22)), 0.0, 0.9)
	flyer_count = clampi(int(cfg.get("flyers", 2)), 0, MAX_FLYERS)
	flyer_strength = float(cfg.get("flyer_strength", 0.75))
	# The web renderer's tonemap leaves the same albedo cut about a third darker (lighting.json keeps
	# *_compat values for the same reason).
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		var k := float(cfg.get("compat_scale", 0.7))
		cloud_strength *= k
		flyer_strength *= k
	glide_mps = maxf(1.0, float(cfg.get("glide_mps", 9.0)))

func _ready() -> void:
	add_to_group(&"sky_shadows")
	# After WorldLighting (priority 0): it rewrites the sun's energy every frame, the dip scales it.
	process_priority = 10
	RenderingServer.global_shader_parameter_set(&"sky_cloud_tex", _cloud_tex)
	_apply_enabled()

func _exit_tree() -> void:
	_write_off()

func _apply_enabled() -> void:
	set_process(enabled)
	if enabled:
		step(0.0)
	else:
		_write_off()

func _process(delta: float) -> void:
	step(delta)

## One frame of sky: wind, flyers, the sun dip. No allocations (value types and preallocated arrays).
func step(delta: float) -> void:
	_t += delta
	var day := 1.0 - clampf(WorldLighting.night, 0.0, 1.0)
	var p := PlayerRegistry.local()
	if p != null and is_instance_valid(p):
		var here := Vector2(p.global_position.x, p.global_position.z)
		if not _anchored:
			_anchor = here
			_anchored = true
		else:
			_anchor = _anchor.lerp(here, 1.0 - exp(-delta / ANCHOR_LAG_S))
	# Kept inside one tile so the float offset never loses precision over a long session.
	_cloud_off = Vector2(fposmod(_cloud_off.x + wind.x * delta, CLOUD_TILE_M), fposmod(_cloud_off.y + wind.y * delta, CLOUD_TILE_M))
	last_cloud = Vector4(_cloud_off.x, _cloud_off.y, cloud_threshold, cloud_strength * day)
	RenderingServer.global_shader_parameter_set(&"sky_cloud", last_cloud)
	for i in MAX_FLYERS:
		var f := Vector4.ZERO
		var span := 1.0
		if i < flyer_count and day > 0.001:
			var r := RADIUS_M + RADIUS_STEP_M * float(i)
			var dir := 1.0 if i % 2 == 0 else -1.0
			var a := float(i) * 2.4 + dir * glide_mps / r * _t
			var centre := _anchor + Vector2(cos(_t * 0.031 + float(i) * 2.0), sin(_t * 0.023 + float(i) * 1.3)) * WANDER_M
			f = Vector4(centre.x + cos(a) * r, centre.y + sin(a) * r, a + dir * PI * 0.5, flyer_strength * day)
			var cyc := fposmod(_t + float(i) * 3.7, FLAP_EVERY_S)
			if cyc < FLAP_S:
				span = 1.0 - FLAP_FOLD * (0.5 - 0.5 * cos(cyc / FLAP_S * TAU * 2.0))
		last_flyers[i] = f
		last_wing[i] = span
		RenderingServer.global_shader_parameter_set(FLYER_PARAMS[i], f)
	RenderingServer.global_shader_parameter_set(&"sky_flyer_wing", last_wing)
	# The dip: eased so walking under a cloud edge dims over a second, never in a step.
	var target := cover_at(_anchor if p == null else Vector2(p.global_position.x, p.global_position.z))
	cover_here = lerpf(cover_here, target, 1.0 - exp(-delta * 1.5)) if delta > 0.0 else cover_here
	sun_scale = 1.0 - sun_dip * cover_here * day
	if lighting != null and is_instance_valid(lighting) and lighting.sun != null:
		lighting.sun.light_energy *= sun_scale

## Cloud cover 0..1 at a world xz point, the same lookup the shader makes (nearest texel).
func cover_at(xz: Vector2) -> float:
	if _cloud_img == null or cloud_strength <= 0.0:
		return 0.0
	var uv := (xz + _cloud_off) / CLOUD_TILE_M
	var x := posmod(int(floor((uv.x - floor(uv.x)) * CLOUD_PX)), CLOUD_PX)
	var y := posmod(int(floor((uv.y - floor(uv.y)) * CLOUD_PX)), CLOUD_PX)
	return smoothstep(cloud_threshold, cloud_threshold + CLOUD_SOFT, _cloud_img.get_pixel(x, y).r)

func _write_off() -> void:
	last_cloud = Vector4.ZERO
	RenderingServer.global_shader_parameter_set(&"sky_cloud", last_cloud)
	for i in MAX_FLYERS:
		last_flyers[i] = Vector4.ZERO
		RenderingServer.global_shader_parameter_set(FLYER_PARAMS[i], Vector4.ZERO)
	sun_scale = 1.0

## The noise value with `cover` of the tile above the soft edge's midpoint (exact, from a histogram),
## minus half the edge: so cloud_cover in sky.json is the share of the ground in shadow.
func _threshold_for(cover: float) -> float:
	if cover <= 0.0:
		return 2.0  # never reached by an 8-bit texel: no clouds
	var hist := PackedInt32Array()
	hist.resize(256)
	var data := _cloud_img.get_data()
	for b in data:
		hist[b] += 1
	var want := int(cover * float(data.size()))
	var acc := 0
	var v := 255
	while v > 0 and acc + hist[v] < want:
		acc += hist[v]
		v -= 1
	return float(v) / 255.0 - CLOUD_SOFT * 0.5

static func _ensure_cloud() -> void:
	if _cloud_img != null:
		return
	var n := FastNoiseLite.new()
	n.seed = 7
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	# ~3 cloud banks across a 240 m tile: clouds 40-90 m wide, bigger than the view.
	n.frequency = 0.011
	_cloud_img = n.get_seamless_image(CLOUD_PX, CLOUD_PX, false, false, 0.1, true)
	_cloud_img.convert(Image.FORMAT_L8)
	_cloud_tex = ImageTexture.create_from_image(_cloud_img)
