class_name EyeTrail
extends MeshInstance3D
## Motion trail behind the glowing eyes (owner: "also add trails to the glowing eyes").
##
## A short fading ribbon hangs off each eye dot while the head moves fast (a lunge, a quick turn, a
## run) and is gone at idle. Geometry: one ImmediateMesh with one surface holding both eyes' ribbons,
## built from a small ring buffer of the dots' recent world positions. Two eyes x at most
## max_samples points is at most 22 quads per creature and one draw call, which the web Compatibility
## renderer handles; nothing runs per particle and no particle node exists.
##
## Visibility follows the eyeshine exactly: the dots' own rule (awake, not asleep, not dead) and the
## same day/night glow fraction, so a ribbon never hangs where no eye glows. Beyond max_distance_m
## from the camera the ribbon is not built at all (the iso camera sits 40 m out).
##
## Knobs: the defaults below, overridable per species from the optional "trail" object inside the
## existing "eyes" block of data/creatures/<id>.json. There is deliberately no new JSON file under
## data/creatures/: Data._load_creatures reads every *.json in that folder as a species and would log
## a malformed-creature error for it, and data.gd is not this task's file.
## ASSUMPTION: every number below is absent from the docs; they are picked to read at the gameplay
## camera (1600x900, 15 m of screen height, 40 m out).

## Past positions kept per eye. The oldest is dropped beyond this.
const MAX_SAMPLES := 12
## ASSUMPTION: how long one past position is drawn for. The owner asked for 0.15-0.3 s.
const FADE_S := 0.22
## Newest sample cadence; a fast move (FORCE_STEP_M in one frame) samples every frame regardless.
const SAMPLE_DT := 0.02
## ASSUMPTION: below this head speed there is no trail (idle and a head bob stay dark).
const MIN_SPEED_MPS := 0.9
## ASSUMPTION: head speed at which the ribbon reaches full strength (a lunge is 4+ m/s).
const FULL_SPEED_MPS := 3.2
## A sample is only taken once the eye has moved this far, so a still head never fills the buffer.
const MIN_STEP_M := 0.004
## A frame that moves the eye this far samples immediately (a lunge must not skip its own trail).
const FORCE_STEP_M := 0.035
## A jump this large is a teleport/spawn, not motion: the buffer is dropped instead of smeared.
const RESET_JUMP_M := 2.0
## ASSUMPTION: longest ribbon in metres, measured along the streak. A lunge faster than this at full
## fade would otherwise draw a streak several metres long across the screen. It also bounds the buffer
## on a very fast head, so the length knob is one number in the same table as the rest.
const MAX_LENGTH_M := 0.9
## Ribbon width as a multiple of the eye dot's world radius.
const WIDTH_PER_RADIUS := 1.9
## Trail brightness relative to the eye dot's own HDR level (the ribbon must not outshine the eye).
const ENERGY := 2.2
## ASSUMPTION: farther than this from the camera the trail is not built. The iso camera is 40 m out
## and a full 1600x900 frame spans ~20 m, so a drawn creature is always inside this.
const MAX_CAMERA_DISTANCE_M := 55.0
## Floor of the eyeshine's own brightness for a trail: a faint day glint (day_fraction, 0.01) has no
## motion smear, so the ribbon only exists once the glow is real.
const MIN_GLOW := 0.02
## Below this peak alpha the ribbon is hidden outright (no geometry, no draw).
const MIN_ALPHA := 0.004
## ASSUMPTION (owner: "flame in the wind ... a little flicker/turbulence"): how deep the width and
## alpha wobble, as a fraction of their value, and how fast that wobble flows down the ribbon.
const FLICKER := 0.45
const FLICKER_HZ := 13.0
## ASSUMPTION: how far the tail drifts up and sideways per second of age, in metres (a flame streams
## up and tugs sideways; a straight clean line would read as a rubber band).
const DRIFT_MPS := 0.55
## ASSUMPTION: width at the very tail as a fraction of the width at the head.
const TAPER := 0.16
## ASSUMPTION: the tail fades faster than it narrows (a flame tip dissolves, it does not get cut off).
const TIP_POW := 1.8
## ASSUMPTION: how white-hot the head of the streak burns against the eye's own colour.
const HOT_HEAD := 0.30

static var _materials: Dictionary = {}

var _eyes: CreatureEyes
var _dots: Array[MeshInstance3D] = []
var _radius := 0.01
var _colour := Color.WHITE
var _mesh := ImmediateMesh.new()
## Per eye: oldest -> newest past positions, the age of each (s) and its strength when recorded.
var _pts: Array = []
var _ages: Array = []
var _str: Array[float] = []
var _prev: Array = []
var _since: Array[float] = []
## Peak vertex alpha of the last build (0 = nothing drawn).
var _alpha := 0.0
## Frames in which a ribbon was actually rebuilt. While the trail is hidden (day, dead, asleep, far)
## this must stay flat: a pooled animal that is nowhere near the screen costs nothing.
var _builds := 0
## Seconds since this trail was set up: the phase of the flicker, so the wobble flows with time.
var _time := 0.0
## Width and alpha range of the quads in the last build (the flicker, measured rather than assumed).
var _w_min := 0.0
var _w_max := 0.0
var _a_min := 0.0
var _a_max := 0.0
## The frame's geometry, built before any surface exists: an empty build must not call
## surface_end (Godot errors with "No vertices were added").
var _verts := PackedVector3Array()
var _cols := PackedColorArray()

# Knobs, from the constants above unless the species' eyes block overrides them.
var max_samples := MAX_SAMPLES
var fade_s := FADE_S
var min_speed_mps := MIN_SPEED_MPS
var full_speed_mps := FULL_SPEED_MPS
var width_per_radius := WIDTH_PER_RADIUS
var energy := ENERGY
var max_distance_m := MAX_CAMERA_DISTANCE_M
var max_length_m := MAX_LENGTH_M
var flicker := FLICKER
var flicker_hz := FLICKER_HZ
var drift_mps := DRIFT_MPS
var taper := TAPER
var tip_pow := TIP_POW
var hot_head := HOT_HEAD

func _init() -> void:
	mesh = _mesh
	set_meta(&"creature_eyetrail", true)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Vertices are world positions: the ribbon must trail behind a moving head, not ride its bone.
	top_level = true
	visible = false

## Builds the ribbon for one creature. eyes owns the dots and the awake/night rule; block is that
## species' "eyes" object, whose optional "trail" table tweaks the knobs.
func setup(eyes: CreatureEyes, dots: Array[MeshInstance3D], radius_world: float, colour: Color,
		block: Dictionary = {}) -> void:
	_eyes = eyes
	_dots = dots
	_radius = maxf(radius_world, 0.002)
	_colour = colour
	_apply_knobs(block)
	material_override = material_for(colour)
	global_transform = Transform3D.IDENTITY
	for _i in dots.size():
		_pts.append([])
		_ages.append([])
		_str.append(0.0)
		_prev.append(Vector3.INF)
		_since.append(0.0)

## Reads the optional per-species overrides. Everything is clamped to a sane band, so a typo in a
## species file can neither spin the buffer nor paint the world.
func _apply_knobs(block: Dictionary) -> void:
	var raw: Variant = block.get("trail", {})
	var t: Dictionary = raw if raw is Dictionary else {}
	max_samples = clampi(int(t.get("max_samples", MAX_SAMPLES)), 2, MAX_SAMPLES)
	fade_s = clampf(float(t.get("fade_s", FADE_S)), 0.05, 0.6)
	min_speed_mps = maxf(float(t.get("min_speed_mps", MIN_SPEED_MPS)), 0.0)
	full_speed_mps = maxf(float(t.get("full_speed_mps", FULL_SPEED_MPS)), min_speed_mps + 0.05)
	width_per_radius = clampf(float(t.get("width_per_radius", WIDTH_PER_RADIUS)), 0.5, 6.0)
	energy = clampf(float(t.get("energy", ENERGY)), 0.1, 12.0)
	max_distance_m = maxf(float(t.get("max_distance_m", MAX_CAMERA_DISTANCE_M)), 1.0)
	max_length_m = clampf(float(t.get("max_length_m", MAX_LENGTH_M)), 0.02, 6.0)
	flicker = clampf(float(t.get("flicker", FLICKER)), 0.0, 1.0)
	flicker_hz = clampf(float(t.get("flicker_hz", FLICKER_HZ)), 0.5, 60.0)
	drift_mps = clampf(float(t.get("drift_mps", DRIFT_MPS)), 0.0, 2.0)
	taper = clampf(float(t.get("taper", TAPER)), 0.0, 1.0)
	tip_pow = clampf(float(t.get("tip_pow", TIP_POW)), 0.2, 6.0)
	hot_head = clampf(float(t.get("hot_head", HOT_HEAD)), 0.0, 1.0)

## One material per eye colour, shared by every animal that uses it; the vertex colour carries the
## taper, so there is nothing per instance to animate but visibility.
static func material_for(col: Color) -> StandardMaterial3D:
	var key := col.to_html(false)
	var have: StandardMaterial3D = _materials.get(key)
	if have != null:
		return have
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	# Same convention as the eye dots: authored sRGB components go straight into the albedo slot, so
	# the ribbon matches the dot's colour instead of coming out darker.
	m.vertex_color_is_srgb = false
	m.albedo_color = Color(ENERGY, ENERGY, ENERGY, 1.0)
	# Light, not geometry: never write depth, never sort against itself, never cast/receive shadows.
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_receive_shadows = true
	_materials[key] = m
	return m

## Advances the ring buffer and rebuilds the ribbon. dt is the frame time from CreatureEyes._process.
func tick(dt: float) -> void:
	if _dots.size() < 2 or _eyes == null:
		return
	var step := clampf(dt, 0.0001, 0.1)
	# The flame only turns while it is on screen: a hidden trail costs no phase work either.
	_time += step
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var near := cam == null or cam.global_position.distance_to(_eyes.global_position) <= max_distance_m
	var glow := _glow_fraction()
	if not _eyes.is_awake() or not near or glow < MIN_GLOW:
		# Nothing glows (or the animal is too far to be seen): drop the history and stop building.
		_clear()
		return
	var head: Array[Vector3] = []
	for i in _dots.size():
		head.append(_dots[i].global_position)
	_track(step, head, glow)
	_build(head, cam)

## Same visibility rule as the eyeshine: the shared night factor, scaled exactly like the dot's
## albedo (a faint day glint by day, full strength at night).
func _glow_fraction() -> float:
	return lerpf(CreatureEyes.day_fraction, 1.0, clampf(WorldLighting.night, 0.0, 1.0))

func _track(step: float, head: Array[Vector3], glow: float) -> void:
	for i in head.size():
		var p: Vector3 = head[i]
		var prev: Vector3 = _prev[i]
		_prev[i] = p
		var ages: Array = _ages[i]
		var pts: Array = _pts[i]
		if prev != Vector3.INF and p.distance_to(prev) > RESET_JUMP_M:
			# A spawn, a teleport or a hitch: smearing across it would draw a bar across the map.
			pts.clear()
			ages.clear()
			_str[i] = 0.0
			_since[i] = 0.0
			continue
		for k in ages.size():
			ages[k] = float(ages[k]) + step
		while not ages.is_empty() and float(ages[0]) > fade_s:
			ages.pop_front()
			pts.pop_front()
		var speed := 0.0
		if prev != Vector3.INF:
			speed = p.distance_to(prev) / step
		var strength := clampf((speed - min_speed_mps) / (full_speed_mps - min_speed_mps), 0.0, 1.0) * glow
		_str[i] = strength
		if pts.is_empty():
			# The first sample of a burst is taken at once: a lunge that starts and stops inside one
			# SAMPLE_DT would otherwise leave no ribbon at all.
			if strength > 0.0:
				pts.append(p)
				ages.append(0.0)
				_since[i] = 0.0
			continue
		_since[i] = float(_since[i]) + step
		var moved_now := p.distance_to(pts[pts.size() - 1])
		if moved_now < MIN_STEP_M:
			continue
		if float(_since[i]) < SAMPLE_DT and moved_now < FORCE_STEP_M:
			continue
		pts.append(p)
		ages.append(0.0)
		_since[i] = 0.0
		while pts.size() > max_samples:
			pts.pop_front()
			ages.pop_front()
		# Length knob: the streak may not run longer than max_length_m, however fast the head goes.
		while pts.size() > 1 and (pts[pts.size() - 1] as Vector3).distance_to(pts[0]) > max_length_m:
			pts.pop_front()
			ages.pop_front()

## Rebuilds the whole ribbon as one surface (one draw call per creature while it shows).
func _build(head: Array[Vector3], cam: Camera3D) -> void:
	_alpha = 0.0
	for i in head.size():
		var ages: Array = _ages[i]
		_alpha = maxf(_alpha, _str[i])
		for k in ages.size():
			_alpha = maxf(_alpha, float(_str[i]) * clampf(1.0 - float(ages[k]) / fade_s, 0.0, 1.0))
	if _alpha <= MIN_ALPHA:
		_hide()
		return
	_verts.clear()
	_cols.clear()
	_w_min = INF
	_w_max = 0.0
	_a_min = INF
	_a_max = 0.0
	for i in head.size():
		_draw_eye(i, head[i], cam)
	if _w_min == INF:
		_w_min = 0.0
	if _a_min == INF:
		_a_min = 0.0
	if _verts.is_empty():
		_hide()
		return
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in _verts.size():
		_mesh.surface_set_color(_cols[k])
		_mesh.surface_add_vertex(_verts[k])
	_mesh.surface_end()
	_builds += 1
	visible = true

## One eye's ribbon: a camera-facing strip of quads through the recorded positions. It is shaped like a
## flame in the wind, not a clean ribbon: the tail streams up and sideways as it ages (drift), the width
## tapers to nothing, and both width and alpha wobble with time and along the streak (flicker).
func _draw_eye(i: int, now: Vector3, cam: Camera3D) -> void:
	var pts: Array = _pts[i]
	var ages: Array = _ages[i]
	if pts.is_empty():
		return
	var cam_at := cam.global_position if cam != null else now + Vector3(0.0, 0.0, 1.0)
	var cam_right := cam.global_basis.x.normalized() if cam != null else Vector3.RIGHT
	var side_axis := cam_right.cross(Vector3.UP)
	if side_axis.length_squared() < 1e-6:
		side_axis = Vector3.RIGHT
	side_axis = side_axis.normalized()
	var chain: Array[Vector3] = []
	var alphas: Array[float] = []
	var widths: Array[float] = []
	var heats: Array[float] = []
	var base_w := _radius * width_per_radius
	var n_pts := pts.size()
	for k in n_pts:
		var age := float(ages[k])
		var pos: Vector3 = pts[k]
		# The buffer runs oldest -> newest, so t is 1 at the tail (oldest) and 0 at the head.
		var t := 1.0 - float(k) / float(maxi(1, n_pts - 1))
		var phase := _time * TAU * flicker_hz + t * 7.0 + float(i) * 3.7
		var n := _flame_noise(phase)
		# Drift: a flame streams up and tugs to the side as it ages, the older the sample the further.
		var drift := drift_mps * age
		pos += Vector3.UP * (drift * (0.7 + 0.3 * n)) + side_axis * (drift * 0.55 * _flame_noise(phase * 0.7 + 2.1))
		chain.append(pos)
		var fade := clampf(1.0 - age / fade_s, 0.0, 1.0)
		# Tip: alpha falls faster than width, so the streak dissolves instead of stopping dead.
		var tip := pow(fade, tip_pow)
		alphas.append(float(_str[i]) * tip * (1.0 + flicker * 0.6 * n))
		widths.append(base_w * lerpf(taper, 1.0, 1.0 - t) * (1.0 + flicker * n))
		heats.append(hot_head * pow(1.0 - t, 3.0))
	# The live head end: full strength, no fade, no drift yet.
	if (chain[chain.size() - 1] as Vector3).distance_squared_to(now) > 1e-8:
		chain.append(now)
		alphas.append(float(_str[i]))
		widths.append(base_w)
		heats.append(hot_head)
	var n2 := chain.size()
	if n2 < 2:
		return
	for k in n2 - 1:
		var a: Vector3 = chain[k]
		var b: Vector3 = chain[k + 1]
		var d := b - a
		if d.length_squared() < 1e-10:
			continue
		var side := d.cross(cam_at - (a + b) * 0.5)
		if side.length_squared() < 1e-10:
			side = d.cross(Vector3.UP)
		if side.length_squared() < 1e-10:
			continue
		side = side.normalized()
		var w0 := maxf(widths[k], 0.0)
		var w1 := maxf(widths[k + 1], 0.0)
		var a0 := clampf(alphas[k], 0.0, 4.0)
		var a1 := clampf(alphas[k + 1], 0.0, 4.0)
		if a0 <= 0.0 and a1 <= 0.0:
			continue
		_measure(w0, w1, a0, a1)
		# White-hot at the head, the eye's own colour down the tail: what makes it read as fire.
		var c0 := _flame_colour(heats[k], a0)
		var c1 := _flame_colour(heats[k + 1], a1)
		var l := a - side * w0
		var r := a + side * w0
		var l2 := b - side * w1
		var r2 := b + side * w1
		_vert(l, c0)
		_vert(r, c0)
		_vert(r2, c1)
		_vert(l, c0)
		_vert(r2, c1)
		_vert(l2, c1)

func _flame_colour(heat: float, a: float) -> Color:
	var h := clampf(heat, 0.0, 1.0)
	return Color(lerpf(_colour.r, 1.0, h), lerpf(_colour.g, 1.0, h), lerpf(_colour.b, 1.0, h), a)

## Two-octave value wobble in [-1, 1]: cheap (two sines, no noise object per creature) and continuous in
## time, which is all a flame flicker needs.
static func _flame_noise(phase: float) -> float:
	return 0.62 * sin(phase) + 0.38 * sin(phase * 2.37 + 1.9)

## Records the width/alpha range of one quad, so a test can measure the flicker instead of trusting it.
func _measure(w0: float, w1: float, a0: float, a1: float) -> void:
	var wl := minf(w0, w1)
	var wh := maxf(w0, w1)
	var al := minf(a0, a1)
	var ah := maxf(a0, a1)
	_w_min = wl if _verts.is_empty() else minf(_w_min, wl)
	_w_max = maxf(_w_max, wh)
	_a_min = al if _verts.is_empty() else minf(_a_min, al)
	_a_max = maxf(_a_max, ah)

func _vert(p: Vector3, c: Color) -> void:
	_verts.append(p)
	_cols.append(c)

func _hide() -> void:
	_verts.clear()
	_cols.clear()
	if _mesh.get_surface_count() > 0:
		_mesh.clear_surfaces()
	visible = false

func _clear() -> void:
	for i in _pts.size():
		(_pts[i] as Array).clear()
		(_ages[i] as Array).clear()
		_str[i] = 0.0
		_since[i] = 0.0
		_prev[i] = Vector3.INF
	_alpha = 0.0
	_hide()

## Longest ribbon across the eyes, in metres: the eye's distance to its oldest live sample.
func ribbon_length() -> float:
	var best := 0.0
	for i in _pts.size():
		var pts: Array = _pts[i]
		if pts.is_empty() or i >= _dots.size() or not is_instance_valid(_dots[i]):
			continue
		best = maxf(best, (_dots[i] as Node3D).global_position.distance_to(pts[0]))
	return best

## Past positions held for the busiest eye (<= max_samples).
func sample_count() -> int:
	var best := 0
	for pts: Array in _pts:
		best = maxi(best, pts.size())
	return best

## Width range (metres) of the quads in the last build: the flicker, measured.
func width_spread() -> float:
	return maxf(0.0, _w_max - _w_min) if _w_min != INF else 0.0

## Alpha range of the quads in the last build.
func alpha_spread() -> float:
	return maxf(0.0, _a_max - _a_min) if _a_min != INF else 0.0

## Width of the widest quad in the last build (metres), for the taper/flame check.
func max_quad_width() -> float:
	return _w_max

## Oldest live sample of the busiest eye (where the flame's tail ends).
func world_tail() -> Vector3:
	var best: Vector3 = Vector3.ZERO
	var dist := -1.0
	for i in _pts.size():
		var pts: Array = _pts[i]
		if pts.is_empty() or i >= _dots.size():
			continue
		var d := (_dots[i] as Node3D).global_position.distance_to(pts[0])
		if d > dist:
			dist = d
			best = pts[0]
	return best

## How far the drawn ribbon rises above the newest eye point (metres): the flame's upward stream.
func ribbon_rise() -> float:
	if _dots.is_empty() or not is_instance_valid(_dots[0]) or _verts.is_empty():
		return 0.0
	var base := (_dots[0] as Node3D).global_position.y
	var top := -INF
	for v in _verts:
		top = maxf(top, v.y)
	return maxf(0.0, top - base)

## How many frames have rebuilt a ribbon since this trail was created.
func build_count() -> int:
	return _builds

## Eyes with a live ribbon right now (2 = both dots draw into the one surface).
func eye_count() -> int:
	var n := 0
	for pts: Array in _pts:
		if not pts.is_empty():
			n += 1
	return n

## Every recorded position across both eyes (the per-creature buffer cost the gate bounds).
func total_samples() -> int:
	var n := 0
	for pts: Array in _pts:
		n += pts.size()
	return n

## Peak vertex alpha of the last build; 0 means nothing was drawn.
func trail_alpha() -> float:
	return _alpha

## Surfaces in the trail mesh (1 while a ribbon is drawn, 0 while hidden).
func surface_count() -> int:
	return _mesh.get_surface_count() if _mesh != null else 0

## Vertices the ribbon costs this frame (6 per quad; the per-creature geometry budget).
func vertex_count() -> int:
	return _verts.size() if visible else 0
