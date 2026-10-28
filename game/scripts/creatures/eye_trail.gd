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
## Ribbon width as a multiple of the eye dot's world radius.
const WIDTH_PER_RADIUS := 2.4
## Trail brightness relative to the eye dot's own HDR level (the ribbon must not outshine the eye).
const ENERGY := 2.5
## ASSUMPTION: farther than this from the camera the trail is not built. The iso camera is 40 m out
## and a full 1600x900 frame spans ~20 m, so a drawn creature is always inside this.
const MAX_CAMERA_DISTANCE_M := 55.0
## Floor of the eyeshine's own brightness for a trail: a faint day glint (day_fraction, 0.01) has no
## motion smear, so the ribbon only exists once the glow is real.
const MIN_GLOW := 0.02
## Below this peak alpha the ribbon is hidden outright (no geometry, no draw).
const MIN_ALPHA := 0.004

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
	for i in head.size():
		_draw_eye(i, head[i], cam)
	if _verts.is_empty():
		_hide()
		return
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in _verts.size():
		_mesh.surface_set_color(_cols[k])
		_mesh.surface_add_vertex(_verts[k])
	_mesh.surface_end()
	visible = true

## One eye's ribbon: a camera-facing strip of quads through the recorded positions, tapering in width
## and alpha to nothing at the tail.
func _draw_eye(i: int, now: Vector3, cam: Camera3D) -> void:
	var pts: Array = _pts[i]
	var ages: Array = _ages[i]
	if pts.is_empty():
		return
	var chain: Array[Vector3] = []
	var alphas: Array[float] = []
	for k in pts.size():
		chain.append(pts[k])
		alphas.append(float(_str[i]) * clampf(1.0 - float(ages[k]) / fade_s, 0.0, 1.0))
	# A repeat of the newest sample adds nothing (and makes a degenerate quad): skip the duplicate.
	if (chain[chain.size() - 1] as Vector3).distance_squared_to(now) > 1e-8:
		chain.append(now)
		alphas.append(float(_str[i]))
	var n := chain.size()
	if n < 2:
		return
	var cam_at := cam.global_position if cam != null else now + Vector3(0.0, 0.0, 1.0)
	var w := _radius * width_per_radius
	for k in n - 1:
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
		# t: 0 at the head end, 1 at the tail. Width and alpha taper to nothing at the tail.
		var t0 := 1.0 - float(k + 1) / float(n - 1)
		var t1 := 1.0 - float(k) / float(n - 1)
		var w0 := w * lerpf(0.18, 1.0, t0)
		var w1 := w * lerpf(0.18, 1.0, t1)
		var a0 := alphas[k] * lerpf(0.18, 1.0, t0)
		var a1 := alphas[k + 1] * lerpf(0.18, 1.0, t1)
		if a0 <= 0.0 and a1 <= 0.0:
			continue
		var c0 := Color(_colour.r, _colour.g, _colour.b, a0)
		var c1 := Color(_colour.r, _colour.g, _colour.b, a1)
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
