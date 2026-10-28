class_name EyeTrail
extends MeshInstance3D
## The glowing eyes' bloom and trails (owner: "also add trails to the glowing eyes", "a flame in the
## wind", then "creepy, deadly and cinematic ... not 2 misplaced candles ... emanate from the eye outwards").
##
## Three parts in one ImmediateMesh, one surface, one draw call per creature:
##  - per eye a hot core in the socket and a soft bloom spreading outward from it and dimming (rings of
##    falling alpha). The anatomical dot is 1-5 cm, 1-3 px from the game camera (190 m out, 4.3 deg
##    lens), so core and bloom have screen-pixel floors: this is the eye the player actually sees;
##  - while the head moves fast, a wisp from each eye streaming back along the motion: a Catmull-Rom
##    curve through the eye's recent positions, hot core with feathered edges (five vertex columns,
##    alpha 0 at both edges), long and thin, tapering to a point and fading out, with flowing value noise
##    on width, alpha and lateral offset, and the older part dragged slightly downwind;
##  - embers: small sparks shed along the wisp that twinkle and drift as they age.
## The skull rim light around the eyes is CreatureEyes' own (one OmniLight3D per eye).
## Width has a floor in screen pixels so the streak reads at the game camera and stays slim close up.
##
## Visibility follows the eyeshine exactly (awake, not asleep, not dead; same day/night glow factor).
## Off-screen or beyond max_distance_m nothing is built. Knobs: the constants below, overridable per
## species from the optional "trail" object inside the "eyes" block of data/creatures/<id>.json.
## ASSUMPTION: every number below is absent from the docs; they are picked by looking at the game camera.

## Past positions kept per eye.
const MAX_SAMPLES := 12
## ASSUMPTION: how long one past position is drawn for (owner earlier: 0.15-0.3 s).
const FADE_S := 0.3
## Newest sample cadence; a fast move (FORCE_STEP_M in one frame) samples every frame regardless.
const SAMPLE_DT := 0.02
## ASSUMPTION: below this head speed there is no streak (idle, a head bob, a slow walk stay clean).
const MIN_SPEED_MPS := 1.6
## ASSUMPTION: head speed at which the streak reaches full strength (a run or a snap turn).
const FULL_SPEED_MPS := 4.5
## How fast the strength falls once the head slows (per second): the flame dies down, it is not cut.
const STRENGTH_DECAY := 5.0
const MIN_STEP_M := 0.004
const FORCE_STEP_M := 0.035
## A jump this large is a teleport/spawn, not motion: the buffer is dropped instead of smeared.
const RESET_JUMP_M := 2.0
## ASSUMPTION: longest streak in metres along the curve, for a head whose eyes sit LENGTH_REF_SEPARATION_M
## apart (deinonychus); other heads scale it by their eye separation within LENGTH_SCALE_MIN..MAX, so a
## T. rex burns a longer flame and a compy a shorter one.
const MAX_LENGTH_M := 1.6
const LENGTH_REF_SEPARATION_M := 0.35
const LENGTH_SCALE_MIN := 0.5
const LENGTH_SCALE_MAX := 2.2
## Half-width of the wisp's base, as a multiple of the dot's world radius (the body swells a little a
## fifth of the way out, see _draw_streak)...
const WIDTH_PER_RADIUS := 1.4
## ...and never thinner than ASPECT x its own length (wispy, not a thread)...
const ASPECT := 0.035
## ...nor than this many pixels (half-width) on screen.
const MIN_HALF_WIDTH_PX := 4.0
## The hot core in the socket: radius in dot radii, with a pixel floor.
const CORE_PER_RADIUS := 1.1
const MIN_CORE_PX := 2.5
## The bloom around it: radius in dot radii, with a pixel floor; alpha falls ring by ring to 0.
const BLOOM_PER_RADIUS := 5.0
const MIN_BLOOM_PX := 9.0
const BLOOM_RING: Array[float] = [0.0, 0.25, 0.55, 1.0]
const BLOOM_ALPHA: Array[float] = [0.32, 0.13, 0.035, 0.0]
## Embers shed along the wisp: size in base half-widths, and how far they drift off it per second.
const EMBER_SIZE := 0.55
const EMBER_DRIFT_MPS := 0.5
## Halo pulled this many dot radii towards the camera, so the skull it sits on does not clip it.
const HALO_PUSH := 3.0
## The streak runs back along the head the eye sits in, so it is pulled towards the camera by this
## fraction of the eye separation: clear of the near half of the skull, the far eye's streak still
## mostly behind it. Along the view ray, so it does not move on screen.
const CLEAR_PER_SEPARATION := 1.5
## Brightness multiplier on the eye colour (vertex colours carry the shape, this the HDR level).
const ENERGY := 2.2
## ASSUMPTION: beyond this from the camera nothing is built (the game camera stands 90-430 m back).
const MAX_CAMERA_DISTANCE_M := 600.0
## The eyeshine's own glow below which nothing is drawn (the faint day glint, 0.01, has no flame).
const MIN_GLOW := 0.02
const MIN_ALPHA := 0.004
## ASSUMPTION: flame flicker: depth of the width/alpha/sideways wobble and how fast it flows (Hz).
const FLICKER := 0.4
const FLICKER_HZ := 9.0
## ASSUMPTION: how far the older part is dragged downwind (and a little up) per second of age, metres.
const DRIFT_MPS := 0.5
## World wind the flame leans with (ASSUMPTION: no wind system exists; one fixed breeze).
const WIND := Vector3(0.8, 0.0, 0.6)
## Tip width as a fraction of the width at the eye (0 = a point).
const TAPER := 0.0
## Alpha falls as fade^TIP_POW along the age: the tip dissolves rather than stops dead.
const TIP_POW := 1.6
## How white-hot the core burns at the eye end.
const HOT_HEAD := 0.45
## Smooth curve: rows per eye wisp, and bloom slices.
const SEGMENTS := 12
const HALO_SLICES := 8
## Across the width: offset (in half-widths) and alpha weight per vertex column. Edges are 0: feathered.
const COLUMN_OFFSET: Array[float] = [-1.0, -0.45, 0.0, 0.45, 1.0]
const COLUMN_ALPHA: Array[float] = [0.0, 0.55, 1.0, 0.55, 0.0]
## Most vertices one creature can emit in a frame (both eyes: wisp + embers + core + bloom).
const MAX_VERTICES := 2 * (SEGMENTS * 4 * 6 + (MAX_SAMPLES + 2) * 6 + HALO_SLICES * 3 + HALO_SLICES * (3 + 2 * 6))

static var _materials: Dictionary = {}

var _eyes: CreatureEyes
var _dots: Array[MeshInstance3D] = []
var _radius := 0.01
var _clear_m := 0.0
var _colour := Color.WHITE
var _mesh := ImmediateMesh.new()
## Per eye: oldest -> newest past positions, the age (s) and strength of each.
var _pts: Array = []
var _ages: Array = []
var _sstr: Array = []
var _str: Array[float] = []
var _prev: Array = []
var _since: Array[float] = []
## Peak streak alpha of the last build (0 = no streak drawn; the halo does not count).
var _alpha := 0.0
var _builds := 0
var _time := 0.0
## Measured on the last build, so tests read the shape instead of trusting it.
var _w_min := INF
var _w_max := 0.0
var _a_min := INF
var _a_max := 0.0
var _head_w := 0.0
var _tail_w := 0.0
var _edge_a := 0.0
var _core_a := 0.0
var _ribbon_verts := 0
var _verts := PackedVector3Array()
var _cols := PackedColorArray()

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
	# World-space vertices: the streak must trail behind a moving head, not ride its bone.
	top_level = true
	visible = false

## ALPHAS: a stronger eyeshine. The halo and streak get `mult` x the energy and a sqrt(mult) wider
## bloom, relative to what setup() built.
func boost(mult: float) -> void:
	energy = clampf(energy * mult, 0.1, 12.0 * mult)
	_radius *= sqrt(maxf(mult, 0.01))
	material_override = material_for(_colour, energy)

func setup(eyes: CreatureEyes, dots: Array[MeshInstance3D], radius_world: float, colour: Color,
		block: Dictionary = {}) -> void:
	_eyes = eyes
	_dots = dots
	_radius = maxf(radius_world, 0.002)
	_colour = colour
	var sep := dots[0].global_position.distance_to(dots[1].global_position) if dots.size() >= 2 else 0.0
	_clear_m = sep * CLEAR_PER_SEPARATION
	_apply_knobs(block, MAX_LENGTH_M * clampf(sep / LENGTH_REF_SEPARATION_M, LENGTH_SCALE_MIN, LENGTH_SCALE_MAX))
	material_override = material_for(colour, energy)
	global_transform = Transform3D.IDENTITY
	for _i in dots.size():
		_pts.append([])
		_ages.append([])
		_sstr.append([])
		_str.append(0.0)
		_prev.append(Vector3.INF)
		_since.append(0.0)

## Optional per-species overrides, clamped so a typo can neither spin the buffer nor paint the world.
func _apply_knobs(block: Dictionary, length_m: float = MAX_LENGTH_M) -> void:
	var raw: Variant = block.get("trail", {})
	var t: Dictionary = raw if raw is Dictionary else {}
	max_samples = clampi(int(t.get("max_samples", MAX_SAMPLES)), 2, MAX_SAMPLES)
	fade_s = clampf(float(t.get("fade_s", FADE_S)), 0.05, 0.6)
	min_speed_mps = maxf(float(t.get("min_speed_mps", MIN_SPEED_MPS)), 0.0)
	full_speed_mps = maxf(float(t.get("full_speed_mps", FULL_SPEED_MPS)), min_speed_mps + 0.05)
	width_per_radius = clampf(float(t.get("width_per_radius", WIDTH_PER_RADIUS)), 0.5, 6.0)
	energy = clampf(float(t.get("energy", ENERGY)), 0.1, 12.0)
	max_distance_m = maxf(float(t.get("max_distance_m", MAX_CAMERA_DISTANCE_M)), 1.0)
	max_length_m = clampf(float(t.get("max_length_m", length_m)), 0.02, 6.0)
	flicker = clampf(float(t.get("flicker", FLICKER)), 0.0, 1.0)
	flicker_hz = clampf(float(t.get("flicker_hz", FLICKER_HZ)), 0.5, 60.0)
	drift_mps = clampf(float(t.get("drift_mps", DRIFT_MPS)), 0.0, 2.0)
	taper = clampf(float(t.get("taper", TAPER)), 0.0, 1.0)
	tip_pow = clampf(float(t.get("tip_pow", TIP_POW)), 0.2, 6.0)
	hot_head = clampf(float(t.get("hot_head", HOT_HEAD)), 0.0, 1.0)

## One material per eye colour and energy, shared by every animal that uses it.
static func material_for(col: Color, level: float = ENERGY) -> StandardMaterial3D:
	var key := "%s@%.2f" % [col.to_html(false), level]
	var have: StandardMaterial3D = _materials.get(key)
	if have != null:
		return have
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	m.albedo_color = Color(level, level, level, 1.0)
	# Light, not geometry: no depth write, no shadows, and no night fog dimming it 190 m from the lens.
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_receive_shadows = true
	m.disable_fog = true
	_materials[key] = m
	return m

## Advances the sample buffers and rebuilds the mesh. dt is the frame time from CreatureEyes._process.
func tick(dt: float) -> void:
	if _dots.size() < 2 or _eyes == null:
		return
	var step := clampf(dt, 0.0001, 0.1)
	_time += step
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var glow := _glow_fraction()
	if not _eyes.is_awake() or glow < MIN_GLOW or not _in_view(cam):
		_clear()
		return
	var head: Array[Vector3] = []
	for i in _dots.size():
		head.append(_dots[i].global_position)
	_track(step, head, glow)
	_build(head, cam, glow)

func _in_view(cam: Camera3D) -> bool:
	if cam == null:
		return true
	var at := _eyes.global_position
	return cam.global_position.distance_to(at) <= max_distance_m and cam.is_position_in_frustum(at)

func _glow_fraction() -> float:
	return lerpf(CreatureEyes.day_fraction, 1.0, clampf(WorldLighting.night, 0.0, 1.0))

func _track(step: float, head: Array[Vector3], glow: float) -> void:
	for i in head.size():
		var p: Vector3 = head[i]
		var prev: Vector3 = _prev[i]
		_prev[i] = p
		var pts: Array = _pts[i]
		var ages: Array = _ages[i]
		var strs: Array = _sstr[i]
		if prev != Vector3.INF and p.distance_to(prev) > RESET_JUMP_M:
			pts.clear()
			ages.clear()
			strs.clear()
			_str[i] = 0.0
			continue
		for k in ages.size():
			ages[k] = float(ages[k]) + step
		while not ages.is_empty() and float(ages[0]) > fade_s:
			_drop_oldest(i)
		var speed := p.distance_to(prev) / step if prev != Vector3.INF else 0.0
		var target := clampf((speed - min_speed_mps) / (full_speed_mps - min_speed_mps), 0.0, 1.0) * glow
		_str[i] = maxf(target, _str[i] - STRENGTH_DECAY * step)
		if target <= 0.0:
			continue
		_since[i] += step
		if not pts.is_empty():
			var moved := p.distance_to(pts[pts.size() - 1])
			if moved < MIN_STEP_M or (_since[i] < SAMPLE_DT and moved < FORCE_STEP_M):
				continue
		pts.append(p)
		ages.append(0.0)
		strs.append(_str[i])
		_since[i] = 0.0
		while pts.size() > max_samples:
			_drop_oldest(i)
		while pts.size() > 1 and _path_length(pts) > max_length_m:
			_drop_oldest(i)

func _drop_oldest(i: int) -> void:
	(_pts[i] as Array).pop_front()
	(_ages[i] as Array).pop_front()
	(_sstr[i] as Array).pop_front()

static func _path_length(pts: Array) -> float:
	var l := 0.0
	for k in pts.size() - 1:
		l += (pts[k] as Vector3).distance_to(pts[k + 1])
	return l

func _build(head: Array[Vector3], cam: Camera3D, glow: float) -> void:
	_verts.clear()
	_cols.clear()
	_alpha = 0.0
	_w_min = INF
	_w_max = 0.0
	_a_min = INF
	_a_max = 0.0
	_head_w = 0.0
	_tail_w = 0.0
	_edge_a = 0.0
	_core_a = 0.0
	for i in head.size():
		_draw_streak(i, head[i], cam)
	_ribbon_verts = _verts.size()
	for i in head.size():
		_draw_halo(i, head[i], cam, glow)
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

## Metres per screen pixel at `at` for this camera (KEEP_HEIGHT). 0 without a camera.
func _m_per_px(cam: Camera3D, at: Vector3) -> float:
	if cam == null or not is_inside_tree():
		return 0.0
	var vh := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return cam.size / vh
	var depth := maxf((at - cam.global_position).dot(-cam.global_basis.z), 0.01)
	return 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5) / vh

## Half-width of the streak at the eye in metres: the dot's size, or the screen floor if wider.
func _base_half_width(cam: Camera3D, at: Vector3) -> float:
	return maxf(_radius * width_per_radius, MIN_HALF_WIDTH_PX * _m_per_px(cam, at))

func _draw_streak(i: int, now: Vector3, cam: Camera3D) -> void:
	var pts: Array = _pts[i]
	if pts.is_empty():
		return
	var ages: Array = _ages[i]
	var strs: Array = _sstr[i]
	# Chain oldest -> newest, ending at the live eye.
	var chain: Array[Vector3] = []
	var c_age: Array[float] = []
	var c_str: Array[float] = []
	for k in pts.size():
		chain.append(pts[k])
		c_age.append(float(ages[k]))
		c_str.append(float(strs[k]))
	if chain[chain.size() - 1].distance_squared_to(now) > 1e-8:
		chain.append(now)
		c_age.append(0.0)
		c_str.append(maxf(_str[i], c_str[c_str.size() - 1] * 0.6))
	var m := chain.size()
	if m < 2:
		return
	var cam_at := cam.global_position if cam != null else now + Vector3(0.0, 0.0, 10.0)
	var cam_right := cam.global_basis.x if cam != null else Vector3.RIGHT
	# A candle flame is ~5x as long as it is wide: a long streak swells with its length.
	var w0 := maxf(_base_half_width(cam, now), _path_length(chain) * ASPECT)
	var wind := WIND.normalized()
	var phase0 := float(i) * 17.3
	var flow := _time * flicker_hz
	# Rows from tail (j = 0, t = 1) to eye (j = SEGMENTS, t = 0) along a Catmull-Rom curve.
	var pos: Array[Vector3] = []
	var wid: Array[float] = []
	var alp: Array[float] = []
	var hot: Array[float] = []
	var ts: Array[float] = []
	for j in SEGMENTS + 1:
		var u := float(j) / float(SEGMENTS) * float(m - 1)
		var k := mini(int(u), m - 2)
		var f := u - float(k)
		var p := _catmull(chain[maxi(k - 1, 0)], chain[k], chain[k + 1], chain[mini(k + 2, m - 1)], f)
		var age := lerpf(c_age[k], c_age[k + 1], f)
		var strength := lerpf(c_str[k], c_str[k + 1], f)
		var t := 1.0 - float(j) / float(SEGMENTS)
		# Noise flows from the eye to the tip: sample it at (position along - time).
		var nw := _vnoise(t * 7.0 - flow + phase0)
		var na := _vnoise(t * 6.0 - flow * 1.4 + phase0 + 40.0)
		var drift := drift_mps * age
		# Plus a lift that grows towards the tip, so the streak curls up off the head like a flame
		# blown back, even when the length cap keeps the samples young.
		# Dragged downwind with a slight rise: the wisp streams back along the motion, it does not stand
		# up off the head like a candle.
		p += (wind + Vector3.UP * 0.35) * (drift * (0.6 + 0.4 * _vnoise(t * 2.0 - flow * 0.5 + phase0 + 80.0)))
		pos.append(p)
		var fade := clampf(1.0 - age / fade_s, 0.0, 1.0)
		# Alpha flicker deepens towards the tip, where it can break the flame into licks.
		# It also thins out along its length, so the far half reads as smoke-thin wisp, not a bar.
		alp.append(maxf(0.0, strength * pow(fade, tip_pow) * pow(1.0 - t, 1.1) * (1.0 + flicker * na * (0.5 + 1.6 * t))))
		# Flame body: narrow at the eye, swelling a quarter of the way out, then a point (taper = tip
		# fraction). The flicker eats more of the thin tip than of the base.
		var body := pow(1.0 - t, 1.3) * (0.75 + 1.3 * sqrt(t))
		wid.append(w0 * maxf(body, taper) * maxf(0.0, 1.0 + flicker * nw * (0.3 + 0.9 * t)))
		hot.append(hot_head * pow(1.0 - t, 1.2))
		ts.append(t)
	_head_w = maxf(_head_w, wid[SEGMENTS])
	_tail_w = maxf(_tail_w, wid[0])
	# Sideways (camera-facing) axis per row, then a lateral flutter that grows towards the tip.
	var sides: Array[Vector3] = []
	for j in SEGMENTS + 1:
		var d := pos[mini(j + 1, SEGMENTS)] - pos[maxi(j - 1, 0)]
		var s := d.cross(cam_at - pos[j])
		if s.length_squared() < 1e-12:
			s = cam_right
		sides.append(s.normalized())
	for j in SEGMENTS + 1:
		var nl := _vnoise(ts[j] * 3.5 - flow * 0.9 + phase0 + 120.0)
		pos[j] += sides[j] * (nl * flicker * w0 * 4.0 * pow(ts[j], 1.2)) + (cam_at - pos[j]).normalized() * _clear_m
	var cols := COLUMN_OFFSET.size()
	for j in SEGMENTS:
		if alp[j] <= 0.0 and alp[j + 1] <= 0.0:
			continue
		_measure(wid[j], wid[j + 1], alp[j], alp[j + 1])
		for c in cols - 1:
			var a0 := pos[j] + sides[j] * (wid[j] * COLUMN_OFFSET[c])
			var b0 := pos[j] + sides[j] * (wid[j] * COLUMN_OFFSET[c + 1])
			var a1 := pos[j + 1] + sides[j + 1] * (wid[j + 1] * COLUMN_OFFSET[c])
			var b1 := pos[j + 1] + sides[j + 1] * (wid[j + 1] * COLUMN_OFFSET[c + 1])
			var ca0 := _flame_colour(hot[j], alp[j], COLUMN_ALPHA[c])
			var cb0 := _flame_colour(hot[j], alp[j], COLUMN_ALPHA[c + 1])
			var ca1 := _flame_colour(hot[j + 1], alp[j + 1], COLUMN_ALPHA[c])
			var cb1 := _flame_colour(hot[j + 1], alp[j + 1], COLUMN_ALPHA[c + 1])
			_vert(a0, ca0)
			_vert(b0, cb0)
			_vert(b1, cb1)
			_vert(a0, ca0)
			_vert(b1, cb1)
			_vert(a1, ca1)

	_draw_embers(i, chain, c_age, c_str, cam_at, cam_right, w0, wind)

## Sparks shed along the wisp: one per second stored sample, drifting off it with age and twinkling.
func _draw_embers(i: int, chain: Array[Vector3], ages: Array[float], strs: Array[float], cam_at: Vector3,
		cam_right: Vector3, w0: float, wind: Vector3) -> void:
	for k in range(0, chain.size() - 1, 2):
		var age := ages[k]
		var fade := clampf(1.0 - age / fade_s, 0.0, 1.0)
		var key := float(k + int(_time * 7.0)) * 3.17 + float(i) * 11.0
		var twinkle := _vnoise(_time * flicker_hz * 1.7 + key)
		var a := strs[k] * fade * clampf(twinkle * 2.0, 0.0, 1.0)
		if a <= 0.02:
			continue
		var to_cam := (cam_at - chain[k]).normalized()
		var side := to_cam.cross(Vector3.UP)
		if side.length_squared() < 1e-6:
			side = cam_right
		side = side.normalized()
		var up := side.cross(to_cam).normalized()
		var off := side * (_vnoise(key + 50.0) * 1.5) + up * (0.5 + 0.5 * _vnoise(key + 90.0))
		var at := chain[k] + (off + wind * 0.5) * (EMBER_DRIFT_MPS * age) + to_cam * _clear_m
		var r := w0 * EMBER_SIZE * (0.5 + 0.5 * fade)
		var c := _flame_colour(hot_head * 0.6, a, 1.0)
		var rim := _flame_colour(0.0, 0.0, 0.0)
		# A small diamond: bright centre, transparent tips.
		var pts: Array[Vector3] = [at + side * r, at + up * r, at - side * r, at - up * r]
		for q in 4:
			_vert(at, c)
			_vert(pts[q], rim)
			_vert(pts[(q + 1) % 4], rim)

## The glowing eye: a hot core in the socket and a bloom spreading outward from it, dimming ring by
## ring to nothing. Pulled towards the camera along the view ray only, so it sits on the eye on screen.
func _draw_halo(i: int, eye: Vector3, cam: Camera3D, glow: float) -> void:
	var to_cam := (cam.global_position - eye).normalized() if cam != null else Vector3.BACK
	var right := cam.global_basis.x if cam != null else Vector3.RIGHT
	var up := cam.global_basis.y if cam != null else Vector3.UP
	var centre := eye + to_cam * maxf(_radius * HALO_PUSH, _clear_m * 0.5)
	var mpp := _m_per_px(cam, eye)
	var shimmer := 1.0 + 0.1 * flicker * _vnoise(_time * flicker_hz * 0.7 + float(i) * 9.1)
	# A moving eye burns hotter: the bloom brightens with the wisp.
	var a := glow * minf(1.0, (0.8 + 0.2 * _str[i]) * shimmer)
	var bloom_r := maxf(_radius * BLOOM_PER_RADIUS, MIN_BLOOM_PX * mpp)
	var dirs: Array[Vector3] = []
	for s in HALO_SLICES + 1:
		var ang := TAU * float(s) / float(HALO_SLICES)
		dirs.append(right * cos(ang) + up * sin(ang))
	# Bloom: a centre fan, then rings, alpha falling outward.
	for s in HALO_SLICES:
		for ring in BLOOM_RING.size() - 1:
			var r0 := BLOOM_RING[ring] * bloom_r
			var r1 := BLOOM_RING[ring + 1] * bloom_r
			var c0 := _flame_colour(hot_head * (1.0 - BLOOM_RING[ring]), a * BLOOM_ALPHA[ring], 1.0)
			var c1 := _flame_colour(hot_head * (1.0 - BLOOM_RING[ring + 1]), a * BLOOM_ALPHA[ring + 1], 1.0)
			if ring == 0:
				_vert(centre, c0)
				_vert(centre + dirs[s] * r1, c1)
				_vert(centre + dirs[s + 1] * r1, c1)
				continue
			_vert(centre + dirs[s] * r0, c0)
			_vert(centre + dirs[s] * r1, c1)
			_vert(centre + dirs[s + 1] * r1, c1)
			_vert(centre + dirs[s] * r0, c0)
			_vert(centre + dirs[s + 1] * r1, c1)
			_vert(centre + dirs[s + 1] * r0, c0)
	# Core: small, white-hot, on top of the bloom.
	var core_r := maxf(_radius * CORE_PER_RADIUS, MIN_CORE_PX * mpp)
	var hot := _flame_colour(1.0, a, 1.0)
	var edge := _flame_colour(0.5, 0.0, 1.0)
	for s in HALO_SLICES:
		_vert(centre, hot)
		_vert(centre + dirs[s] * core_r, edge)
		_vert(centre + dirs[s + 1] * core_r, edge)

static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)

## Smooth 1D value noise in [-1, 1]: hashed lattice values, smoothstep between them.
static func _vnoise(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_hash(i), _hash(i + 1.0), f)

static func _hash(n: float) -> float:
	var h := sin(n * 127.1 + 311.7) * 43758.5453
	return (h - floorf(h)) * 2.0 - 1.0

func _flame_colour(heat: float, a: float, column: float) -> Color:
	var h := clampf(heat * column, 0.0, 1.0)
	return Color(lerpf(_colour.r, 1.0, h), lerpf(_colour.g, 1.0, h), lerpf(_colour.b, 1.0, h),
		clampf(a * column, 0.0, 1.0))

func _measure(w0: float, w1: float, a0: float, a1: float) -> void:
	_w_min = minf(_w_min, minf(w0, w1))
	_w_max = maxf(_w_max, maxf(w0, w1))
	_a_min = minf(_a_min, minf(a0, a1))
	_a_max = maxf(_a_max, maxf(a0, a1))
	_alpha = maxf(_alpha, maxf(a0, a1))
	_core_a = maxf(_core_a, maxf(a0, a1) * COLUMN_ALPHA[2])
	_edge_a = maxf(_edge_a, maxf(a0, a1) * COLUMN_ALPHA[0])

func _vert(p: Vector3, c: Color) -> void:
	_verts.append(p)
	_cols.append(c)

func _hide() -> void:
	_verts.clear()
	_cols.clear()
	_ribbon_verts = 0
	_alpha = 0.0
	if _mesh.get_surface_count() > 0:
		_mesh.clear_surfaces()
	visible = false

func _clear() -> void:
	for i in _pts.size():
		(_pts[i] as Array).clear()
		(_ages[i] as Array).clear()
		(_sstr[i] as Array).clear()
		_str[i] = 0.0
		_since[i] = 0.0
		_prev[i] = Vector3.INF
	_hide()

## Longest streak across the eyes, in metres: the eye's distance to its oldest live sample.
func ribbon_length() -> float:
	var best := 0.0
	for i in _pts.size():
		var pts: Array = _pts[i]
		if pts.is_empty() or i >= _dots.size() or not is_instance_valid(_dots[i]):
			continue
		best = maxf(best, (_dots[i] as Node3D).global_position.distance_to(pts[0]))
	return best

func sample_count() -> int:
	var best := 0
	for pts: Array in _pts:
		best = maxi(best, pts.size())
	return best

func width_spread() -> float:
	return maxf(0.0, _w_max - _w_min) if _w_min != INF else 0.0

func alpha_spread() -> float:
	return maxf(0.0, _a_max - _a_min) if _a_min != INF else 0.0

func max_quad_width() -> float:
	return _w_max

## Half-width at the eye end and at the tip of the last build (metres): the taper, measured.
func head_width() -> float:
	return _head_w

func tail_width() -> float:
	return _tail_w

## Edge-column alpha over core-column alpha of the last build: 0 = fully feathered edges.
func edge_alpha_ratio() -> float:
	return _edge_a / _core_a if _core_a > 0.0 else 0.0

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

## How far the drawn streak rises above the eye (metres): the flame's upward drift.
func ribbon_rise() -> float:
	if _dots.is_empty() or not is_instance_valid(_dots[0]) or _ribbon_verts == 0:
		return 0.0
	var base := (_dots[0] as Node3D).global_position.y
	var top := -INF
	for k in _ribbon_verts:
		top = maxf(top, _verts[k].y)
	return maxf(0.0, top - base)

func build_count() -> int:
	return _builds

func eye_count() -> int:
	var n := 0
	for pts: Array in _pts:
		if not pts.is_empty():
			n += 1
	return n

func total_samples() -> int:
	var n := 0
	for pts: Array in _pts:
		n += pts.size()
	return n

## Peak streak alpha of the last build; 0 means no streak (the halo alone does not count).
func trail_alpha() -> float:
	return _alpha

func surface_count() -> int:
	return _mesh.get_surface_count() if _mesh != null else 0

## Vertices drawn this frame (streaks + halos) and the streaks' share of them.
func vertex_count() -> int:
	return _verts.size() if visible else 0

func ribbon_vertex_count() -> int:
	return _ribbon_verts if visible else 0
