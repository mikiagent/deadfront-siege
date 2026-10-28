class_name EyeTrail
extends MeshInstance3D
## The glowing eyes' bloom and trails (owner: "also add trails to the glowing eyes", "a flame in the
## wind", then "creepy, deadly and cinematic ... not 2 misplaced candles ... emanate from the eye outwards").
##
## Three parts in one ArrayMesh, one surface, one draw call per creature:
##  - per eye a hot core in the socket and a soft bloom spreading outward from it and dimming (rings of
##    falling alpha). The anatomical dot is 1-5 cm, 1-3 px from the game camera (190 m out, 4.3 deg
##    lens), so core and bloom have screen-pixel floors: this is the eye the player actually sees;
##  - while the head moves fast, a fan of thin flame strands from each eye streaming back along the
##    motion: a Catmull-Rom curve through the eye's recent positions, each strand tapering to a point,
##    feathered (alpha 0 at both edges), fanning out from the eye with its own flowing value noise on
##    alpha and lateral offset, the older part dragged slightly downwind. The flame shader (FLAME_SHADER)
##    then tears each strand with a scrolling noise texture, more towards the tip and the edges, so it
##    flickers and breaks into licks like a flame in wind (round 2, owner: not "2 misplaced candles");
##  - embers: small sparks shed along the wisp that twinkle and drift as they age.
## The skull rim light around the eyes is CreatureEyes' own (one OmniLight3D per eye).
## Width has a floor in screen pixels so the streak reads at the game camera and stays slim close up.
##
## Quality: `low_quality` (web renderer, phones) drops the glow strand, draws fewer rows, takes one noise
## tap in the shader and half the embers. Nothing is allocated per frame in script: every buffer is sized once.
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
const SAMPLE_DT := 0.03
## ASSUMPTION: below this head speed there is no streak (idle, a head bob, a slow walk stay clean).
const MIN_SPEED_MPS := 1.6
## ASSUMPTION: head speed at which the streak reaches full strength (a run or a snap turn).
const FULL_SPEED_MPS := 4.5
## How fast the strength falls once the head slows (per second): the flame dies down, it is not cut.
const STRENGTH_DECAY := 5.0
const MIN_STEP_M := 0.004
## A move this long samples at once (snap turns stay smooth); never shorter than max_length_m /
## (max_samples - 1), or at 120 fps the sample cap, not the fade, would cut the flame short.
const FORCE_STEP_M := 0.035
## Head speed is smoothed over about 1 / SPEED_SMOOTH s: at 120 fps the bone moves on 60 Hz physics
## frames only, and the raw per-frame speed alternated 0 / 2x and lit a flame on an idle head.
const SPEED_SMOOTH := 25.0
## A jump this large is a teleport/spawn, not motion: the buffer is dropped instead of smeared.
const RESET_JUMP_M := 2.0
## ASSUMPTION: longest streak in metres along the curve, for a head whose eyes sit LENGTH_REF_SEPARATION_M
## apart (deinonychus); other heads scale it by their eye separation within LENGTH_SCALE_MIN..MAX, so a
## T. rex burns a longer flame and a compy a shorter one.
const MAX_LENGTH_M := 3.2
const LENGTH_REF_SEPARATION_M := 0.35
const LENGTH_SCALE_MIN := 0.6
const LENGTH_SCALE_MAX := 2.2
## Half-width of the wisp's base, as a multiple of the dot's world radius (the body swells a little a
## fifth of the way out, see _draw_streak)...
const WIDTH_PER_RADIUS := 0.9
## ...nor thinner than this many pixels (half-width) on screen.
const MIN_HALF_WIDTH_PX := 2.6
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
## UV of everything the shader must not tear (bloom, core, embers).
const HALO_UV := Vector2(0.5, -1.0)
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
const TIP_POW := 0.9
## How white-hot the core burns at the eye end.
const HOT_HEAD := 0.25
## Smooth curve: rows per eye (high / low quality), and bloom slices.
const SEGMENTS := 10
const SEGMENTS_LOW := 7
const HALO_SLICES := 8
## Across the width each strand row is three vertices: transparent edge, core, transparent edge
## (feathered); the shader tears the rest.
## ASSUMPTION: the strands per eye. Strand 0 is the main tongue; 1 and 2 are shorter and thinner and
## fan out to either side (STRAND_FAN half-widths at their tip, FAN_SPREAD scales it), so the flame
## emanates outward from the eye instead of running as one bar; 3 is a wide, faint, barely torn glow
## under them in the eye colour (no white core), which is what still reads from 190 m.
## STRAND_SET / STRAND_SET_LOW: which strands each quality draws.
const STRAND_LENGTH: Array[float] = [1.0, 0.78, 0.62, 0.85]
const STRAND_WIDTH: Array[float] = [1.0, 0.7, 0.6, 2.8]
const STRAND_FAN: Array[float] = [0.0, -1.0, 1.0, 0.0]
const STRAND_ALPHA: Array[float] = [1.0, 0.85, 0.8, 0.18]
const STRAND_HOT: Array[float] = [1.0, 0.6, 0.5, 0.0]
const STRAND_SET: Array[int] = [3, 0, 1, 2]
const STRAND_SET_LOW: Array[int] = [0, 1, 2]
const STRANDS := 4
const STRANDS_LOW := 3
const FAN_SPREAD := 4.5
const STRAND_NOISE_SHIFT := 3
## Indexed vertices per eye: the bloom (a centre and three rings) and the core (a centre and a ring).
const HALO_VERTS := 1 + 3 * HALO_SLICES + 1 + HALO_SLICES
## Vertices one creature draws (both eyes: strands of three columns per row, embers of five, halo). The
## index buffer is fixed per quality, so this is also the size of every buffer.
const MAX_VERTICES := 2 * (STRANDS * (SEGMENTS + 1) * 3 + (MAX_SAMPLES / 2) * 5 + HALO_VERTS)
## Flame shader: strands carry UV.x across (0..1) and UV.y = along (0 eye .. 1 tip) + 2 x strand index;
## the bloom, core and embers carry UV.y = -1 and are not torn. Erosion: a scrolling noise texture
## must beat a threshold that rises towards the tip and the edges, so the strand breaks into licks.
const FLAME_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
%s
uniform sampler2D flame_noise : repeat_enable, filter_linear_mipmap;
uniform float energy = 2.2;
uniform float flow = 1.7;
uniform float tear = 0.7;
void fragment() {
	float a = COLOR.a;
	float heat = 1.0;
	if (UV.y >= 0.0) {
		float sid = floor(UV.y * 0.5);
		float t = UV.y - 2.0 * sid;
		float across = abs(UV.x * 2.0 - 1.0);
		vec2 q = vec2(UV.x * 0.3 + sid * 0.37, t * 1.4 + sid * 0.29 - TIME * flow);
		float n = texture(flame_noise, q).r;
#ifndef LOW
		n = n * 0.6 + 0.4 * texture(flame_noise, q * vec2(2.1, 2.7) + vec2(0.53, -TIME * flow * 0.8)).r;
#endif
		// Strand 3 is the soft glow: torn far less than the tongues.
		float thr = (sid > 2.5 ? tear * 0.4 : tear) * (pow(t, 0.8) * 0.9 + across * 0.4) - 0.12;
		a *= smoothstep(thr, thr + 0.2, n);
		// Hotter at the eye, cooler and deeper towards the tip; noise peaks flare.
		heat = (0.65 + 0.7 * n) * (1.15 - 0.55 * t);
	}
	ALBEDO = COLOR.rgb * energy * heat;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Cheaper path for the web renderer (gl_compatibility) and phones; read by setup(), so set it before
## creatures spawn. Same split as WorldLighting._compat and ProcessFx.
static var low_quality: bool = _default_low_quality()
## 256 hashed lattice values for _vnoise (a table lookup instead of two sin() per sample).
static var _lattice: PackedFloat32Array = _make_lattice()
static var _materials: Dictionary = {}
static var _noise: Texture2D

var _eyes: CreatureEyes
var _dots: Array[MeshInstance3D] = []
var _radius := 0.01
var _clear_m := 0.0
var _colour := Color.WHITE
var _mesh := ArrayMesh.new()
var _arrays: Array = []
var _low := false
var _strands := STRANDS
var _set: Array[int] = STRAND_SET
var _segments := SEGMENTS
var _ember_step := 2
var _ember_slots := MAX_SAMPLES / 2
## Vertices per eye's ribbon block (strands + embers), where the halos start, and the total drawn.
var _block := 0
var _ribbon_end := 0
var _vcount := 0
var _ribbon_dirty := true
## Per eye: oldest -> newest past positions, the age (s) and strength of each.
var _pts: Array = []
var _ages: Array = []
var _sstr: Array = []
var _str: Array[float] = []
var _prev: Array = []
var _since: Array[float] = []
var _speed: Array[float] = []
var _force_step := FORCE_STEP_M
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
## Fixed-size buffers, written by index; the index buffer and the UVs never change after setup().
## A ribbon block with nothing to draw is collapsed to one point (degenerate, no fragments).
var _verts := PackedVector3Array()
var _cols := PackedColorArray()
var _uvs := PackedVector2Array()
var _idx := PackedInt32Array()
var _n := 0
## Per-frame scratch, sized once in setup(): the sample chain and the curve rows shared by the strands.
var _chain := PackedVector3Array()
var _cage := PackedFloat32Array()
var _cstr := PackedFloat32Array()
var _rp := PackedVector3Array()
var _rs := PackedVector3Array()
var _rfade := PackedFloat32Array()
var _rw := PackedFloat32Array()
## Flowing noise along the rows, two channels (alpha, lateral); a strand reads it STRAND_NOISE_SHIFT
## rows further along per index, so the strands flicker apart for the cost of one noise sweep.
var _rna := PackedFloat32Array()
var _rnl := PackedFloat32Array()
var _dirs := PackedVector3Array()
var _cos := PackedFloat32Array()
var _sin := PackedFloat32Array()
## Per strand and row, computed once from the knobs: the shape of the flame.
var _tab_alpha := PackedFloat32Array()
var _tab_namp := PackedFloat32Array()
var _tab_body := PackedFloat32Array()
var _tab_hot := PackedFloat32Array()
var _tab_fan := PackedFloat32Array()
var _tab_flut := PackedFloat32Array()
var _edge_col := Color.TRANSPARENT

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

func setup(eyes: CreatureEyes, dots: Array[MeshInstance3D], radius_world: float, colour: Color,
		block: Dictionary = {}) -> void:
	_eyes = eyes
	_dots = dots
	_radius = maxf(radius_world, 0.002)
	_colour = colour
	var sep := dots[0].global_position.distance_to(dots[1].global_position) if dots.size() >= 2 else 0.0
	_clear_m = sep * CLEAR_PER_SEPARATION
	_apply_knobs(block, MAX_LENGTH_M * clampf(sep / LENGTH_REF_SEPARATION_M, LENGTH_SCALE_MIN, LENGTH_SCALE_MAX))
	_low = low_quality
	_strands = STRANDS_LOW if _low else STRANDS
	_set = STRAND_SET_LOW if _low else STRAND_SET
	_segments = SEGMENTS_LOW if _low else SEGMENTS
	_ember_step = 4 if _low else 2
	_ember_slots = ceili(float(MAX_SAMPLES) / float(_ember_step))
	material_override = material_for(colour, energy, _low)
	_edge_col = Color(_colour, 0.0)
	_chain.resize(MAX_SAMPLES + 1)
	_cage.resize(MAX_SAMPLES + 1)
	_cstr.resize(MAX_SAMPLES + 1)
	_rp.resize(SEGMENTS + 1)
	_rs.resize(SEGMENTS + 1)
	_rfade.resize(SEGMENTS + 1)
	_rw.resize(SEGMENTS + 1)
	_rna.resize(SEGMENTS + 1 + STRAND_NOISE_SHIFT * STRANDS)
	_rnl.resize(SEGMENTS + 1 + STRAND_NOISE_SHIFT * STRANDS)
	_dirs.resize(HALO_SLICES)
	_cos.resize(HALO_SLICES)
	_sin.resize(HALO_SLICES)
	for s in HALO_SLICES:
		_cos[s] = cos(TAU * float(s) / float(HALO_SLICES))
		_sin[s] = sin(TAU * float(s) / float(HALO_SLICES))
	_build_tables()
	_build_layout()
	global_transform = Transform3D.IDENTITY
	for _i in dots.size():
		_pts.append([])
		_ages.append([])
		_sstr.append([])
		_str.append(0.0)
		_prev.append(Vector3.INF)
		_since.append(0.0)
		_speed.append(0.0)

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
	_force_step = maxf(FORCE_STEP_M, max_length_m / float(max_samples - 1))

## The flame's shape per strand and row (row j runs from the tail, t = 1, to the eye, t = 0), from the
## strand constants and the knobs: none of it changes per frame.
func _build_tables() -> void:
	var rows := _segments + 1
	var size := _set.size() * rows
	for tab: PackedFloat32Array in [_tab_alpha, _tab_namp, _tab_body, _tab_hot, _tab_fan, _tab_flut]:
		tab.resize(size)
	for si in _set.size():
		var s := _set[si]
		for j in rows:
			var q := si * rows + j
			var ts := minf((1.0 - float(j) / float(_segments)) / STRAND_LENGTH[s], 1.0)
			_tab_alpha[q] = STRAND_ALPHA[s] * pow(1.0 - ts, 0.75)
			# Alpha flicker deepens towards the tip, where it breaks the flame into licks.
			_tab_namp[q] = 0.5 + 1.6 * ts
			# Narrow at the eye, swelling a quarter of the way out, then a point (taper = tip fraction).
			_tab_body[q] = STRAND_WIDTH[s] * maxf(pow(1.0 - ts, 1.3) * (0.75 + 1.3 * sqrt(ts)), taper)
			_tab_hot[q] = STRAND_HOT[s] * hot_head * pow(1.0 - ts, 1.2)
			_tab_fan[q] = STRAND_FAN[s] * FAN_SPREAD * pow(ts, 0.8)
			_tab_flut[q] = 4.0 * pow(ts, 1.2)

## The fixed vertex layout and its index buffer: per eye a ribbon block (each strand rows x 3 columns,
## then the ember diamonds), then per eye the halo (bloom centre + 3 rings, core centre + ring). The UVs
## and the always-transparent colours are written here once.
func _build_layout() -> void:
	var rows := _segments + 1
	_block = _set.size() * rows * 3 + _ember_slots * 5
	_ribbon_end = 2 * _block
	_vcount = _ribbon_end + 2 * HALO_VERTS
	assert(_vcount <= MAX_VERTICES)
	_verts.resize(_vcount)
	_cols.resize(_vcount)
	_uvs.resize(_vcount)
	_verts.fill(Vector3.ZERO)
	_cols.fill(_edge_col)
	_uvs.fill(HALO_UV)
	_idx.clear()
	var base := 0
	for _i in 2:
		for si in _set.size():
			for j in rows:
				var uvy := minf((1.0 - float(j) / float(_segments)) / STRAND_LENGTH[_set[si]], 1.0) + 2.0 * float(_set[si])
				for c in 3:
					_uvs[base + j * 3 + c] = Vector2(0.5 * float(c), uvy)
			for j in _segments:
				for c in 2:
					var a0 := base + j * 3 + c
					_idx.append_array([a0, a0 + 1, a0 + 4, a0, a0 + 4, a0 + 3])
			base += rows * 3
		for _e in _ember_slots:
			for q in 4:
				_idx.append_array([base, base + 1 + q, base + 1 + (q + 1) % 4])
			base += 5
	var h := HALO_SLICES
	for _i in 2:
		for s in h:
			_idx.append_array([base, base + 1 + s, base + 1 + (s + 1) % h])
		for ring in 2:
			var r0 := base + 1 + ring * h
			for s in h:
				var s1 := (s + 1) % h
				_idx.append_array([r0 + s, r0 + h + s, r0 + h + s1, r0 + s, r0 + h + s1, r0 + s1])
		base += 1 + 3 * h
		for s in h:
			_idx.append_array([base, base + 1 + s, base + 1 + (s + 1) % h])
		base += 1 + h
	assert(base == _vcount)
	_arrays.resize(Mesh.ARRAY_MAX)
	_arrays[Mesh.ARRAY_TEX_UV] = _uvs
	_arrays[Mesh.ARRAY_INDEX] = _idx

static func _make_lattice() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(256)
	for k in 256:
		out[k] = _hash(float(k))
	return out

static func _default_low_quality() -> bool:
	return RenderingServer.get_current_rendering_method() != "forward_plus" or OS.has_feature("web") \
		or OS.has_feature("mobile")

## One flame material per energy level and quality (the colour is in the vertices), shared by every animal.
## Light, not geometry: additive, unshaded, no depth write, no shadows, no fog dimming it 190 m out.
static func material_for(_col: Color, level: float = ENERGY, low: bool = false) -> ShaderMaterial:
	var key := "%.2f@%s" % [level, low]
	var have: ShaderMaterial = _materials.get(key)
	if have != null:
		return have
	var sh := Shader.new()
	sh.code = FLAME_SHADER % ("#define LOW" if low else "")
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"energy", level)
	m.set_shader_parameter(&"flame_noise", _flame_noise())
	_materials[key] = m
	return m

## A small tileable noise texture, built once and synchronously (NoiseTexture2D bakes on a thread and
## would draw the first frames untorn).
static func _flame_noise() -> Texture2D:
	if _noise == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.07
		fn.fractal_octaves = 2
		fn.seed = 7
		var img := fn.get_seamless_image(64, 64)
		img.generate_mipmaps()
		_noise = ImageTexture.create_from_image(img)
	return _noise

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
	for i in _dots.size():
		_track(i, step, _dots[i].global_position, glow)
	_build(cam, glow)

func _in_view(cam: Camera3D) -> bool:
	if cam == null:
		return true
	var at := _eyes.global_position
	return cam.global_position.distance_to(at) <= max_distance_m and cam.is_position_in_frustum(at)

func _glow_fraction() -> float:
	return lerpf(CreatureEyes.day_fraction, 1.0, clampf(WorldLighting.night, 0.0, 1.0))

func _track(i: int, step: float, p: Vector3, glow: float) -> void:
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
		_speed[i] = 0.0
		return
	for k in ages.size():
		ages[k] = float(ages[k]) + step
	while not ages.is_empty() and float(ages[0]) > fade_s:
		_drop_oldest(i)
	var raw := p.distance_to(prev) / step if prev != Vector3.INF else 0.0
	_speed[i] = lerpf(_speed[i], raw, 1.0 - exp(-SPEED_SMOOTH * step))
	var speed := _speed[i]
	var target := clampf((speed - min_speed_mps) / (full_speed_mps - min_speed_mps), 0.0, 1.0) * glow
	_str[i] = maxf(target, _str[i] - STRENGTH_DECAY * step)
	if target <= 0.0:
		return
	_since[i] += step
	if not pts.is_empty():
		var moved := p.distance_to(pts[pts.size() - 1])
		if moved < MIN_STEP_M or (_since[i] < SAMPLE_DT and moved < _force_step):
			return
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

func _build(cam: Camera3D, glow: float) -> void:
	_alpha = 0.0
	_w_min = INF
	_w_max = 0.0
	_a_min = INF
	_a_max = 0.0
	_head_w = 0.0
	_tail_w = 0.0
	_edge_a = 0.0
	var any := false
	for i in _dots.size():
		any = any or not (_pts[i] as Array).is_empty()
	if any or _ribbon_dirty:
		for i in 2:
			_n = i * _block
			if not any or not _draw_streak(i, _dots[i].global_position, cam):
				_collapse(i)
		_ribbon_dirty = any
	_core_a = _alpha
	_ribbon_verts = _ribbon_end if _alpha > 0.0 else 0
	for i in 2:
		_n = _ribbon_end + i * HALO_VERTS
		_draw_halo(i, _dots[i].global_position, cam, glow)
	# One upload of the fixed-size buffers; the references are dropped again right after, so the next
	# frame's index writes do not copy the arrays. UVs and indices never change, so they stay put.
	_mesh.clear_surfaces()
	_arrays[Mesh.ARRAY_VERTEX] = _verts
	_arrays[Mesh.ARRAY_COLOR] = _cols
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	_arrays[Mesh.ARRAY_VERTEX] = null
	_arrays[Mesh.ARRAY_COLOR] = null
	# Collapsed blocks sit at the world origin: cull and sort by the real reach around the eyes instead.
	var reach := Vector3.ONE * (max_length_m + _clear_m + 1.0)
	_mesh.custom_aabb = AABB(_eyes.global_position - reach, reach * 2.0)
	_builds += 1
	visible = true

## One eye's ribbon block drawn as nothing: every vertex on one point.
func _collapse(i: int) -> void:
	for k in range(i * _block, (i + 1) * _block):
		_verts[k] = Vector3.ZERO

## Metres per screen pixel at `at` for this camera (KEEP_HEIGHT). 0 without a camera.
func _m_per_px(cam: Camera3D, at: Vector3) -> float:
	if cam == null or not is_inside_tree():
		return 0.0
	var vh := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return cam.size / vh
	var depth := maxf((at - cam.global_position).dot(-cam.global_basis.z), 0.01)
	return 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5) / vh

## Half-width of the main strand at the eye in metres: the dot's size, or the screen floor if wider.
func _base_half_width(cam: Camera3D, at: Vector3) -> float:
	return maxf(_radius * width_per_radius, MIN_HALF_WIDTH_PX * _m_per_px(cam, at))

## One eye's flame into its ribbon block: the shared curve rows (position, sideways axis, fade, width
## flicker, flowing noise), then each strand over them, then the embers. False if there is no curve.
func _draw_streak(i: int, now: Vector3, cam: Camera3D) -> bool:
	var pts: Array = _pts[i]
	var m := pts.size()
	if m == 0:
		return false
	var ages: Array = _ages[i]
	var strs: Array = _sstr[i]
	# Chain oldest -> newest, ending at the live eye.
	for k in m:
		_chain[k] = pts[k]
		_cage[k] = float(ages[k])
		_cstr[k] = float(strs[k])
	if _chain[m - 1].distance_squared_to(now) > 1e-8:
		_chain[m] = now
		_cage[m] = 0.0
		_cstr[m] = maxf(_str[i], _cstr[m - 1] * 0.6)
		m += 1
	if m < 2:
		return false
	var cam_at := cam.global_position if cam != null else now + Vector3(0.0, 0.0, 10.0)
	var cam_right := cam.global_basis.x if cam != null else Vector3.RIGHT
	var w0 := _base_half_width(cam, now)
	var wind := WIND.normalized()
	var phase0 := float(i) * 17.3
	var flow := _time * flicker_hz
	var seg := _segments
	var inv_seg := 1.0 / float(seg)
	# Rows from tail (j = 0, t = 1) to eye (j = seg, t = 0) along a Catmull-Rom curve.
	for j in seg + 1:
		var u := float(j) * inv_seg * float(m - 1)
		var k := mini(int(u), m - 2)
		var f := u - float(k)
		var p := _catmull(_chain[maxi(k - 1, 0)], _chain[k], _chain[k + 1], _chain[mini(k + 2, m - 1)], f)
		var age := lerpf(_cage[k], _cage[k + 1], f)
		var t := 1.0 - float(j) * inv_seg
		# Dragged downwind with a slight rise: the flame streams back along the motion.
		p += (wind + Vector3.UP * 0.35) * (drift_mps * age * (0.6 + 0.4 * _vnoise(t * 2.0 - flow * 0.5 + phase0 + 80.0)))
		_rp[j] = p
		_rfade[j] = lerpf(_cstr[k], _cstr[k + 1], f) * pow(clampf(1.0 - age / fade_s, 0.0, 1.0), tip_pow)
		# Width flicker flows from the eye to the tip (noise at position along - time); it eats the tip most.
		_rw[j] = maxf(0.0, 1.0 + flicker * _vnoise(t * 7.0 - flow + phase0) * (0.3 + 0.9 * t))
	# Flowing noise for the strands, a few rows past the curve so each strand reads its own stretch.
	for j in _rna.size():
		var t := 1.0 - float(j) * inv_seg
		_rna[j] = flicker * _vnoise(t * 6.0 - flow * 1.4 + phase0 + 40.0)
		_rnl[j] = flicker * _vnoise(t * 3.5 - flow * 0.9 + phase0 + 120.0)
	# Sideways (camera-facing) axis per row; then pull every row towards the camera to clear the skull.
	for j in seg + 1:
		var sv := (_rp[mini(j + 1, seg)] - _rp[maxi(j - 1, 0)]).cross(cam_at - _rp[j])
		_rs[j] = sv.normalized() if sv.length_squared() > 1e-12 else cam_right
	for j in seg + 1:
		_rp[j] += (cam_at - _rp[j]).normalized() * _clear_m
	# The strands: three vertices per row (transparent edge, core, transparent edge; the edge colours and
	# all UVs were written once in _build_layout). The shader tears them.
	var rows := seg + 1
	var n := _n
	var cr := _colour.r
	var cg := _colour.g
	var cb := _colour.b
	for si in _set.size():
		var shift := si * STRAND_NOISE_SHIFT
		var main := _set[si] == 0
		for j in rows:
			var q := si * rows + j
			var a := maxf(0.0, _rfade[j] * _tab_alpha[q] * (1.0 + _rna[j + shift] * _tab_namp[q]))
			var w := w0 * _tab_body[q] * _rw[j]
			var centre := _rp[j] + _rs[j] * (w0 * (_tab_fan[q] + _rnl[j + shift] * _tab_flut[q]))
			var side := _rs[j] * w
			var h := _tab_hot[q]
			_verts[n] = centre - side
			_verts[n + 1] = centre
			_verts[n + 2] = centre + side
			_cols[n + 1] = Color(cr + (1.0 - cr) * h, cg + (1.0 - cg) * h, cb + (1.0 - cb) * h, minf(a, 1.0))
			n += 3
			if a > 0.0:
				_w_min = minf(_w_min, w)
				_w_max = maxf(_w_max, w)
				_a_min = minf(_a_min, a)
				_a_max = maxf(_a_max, a)
				_alpha = maxf(_alpha, a)
			if main:
				if j == seg:
					_head_w = maxf(_head_w, w)
				elif j == 0:
					_tail_w = maxf(_tail_w, w)
	_n = n
	_draw_embers(i, m, cam_at, cam_right, w0, wind)
	return true

## Sparks shed along the flame: one per _ember_step stored samples, drifting off it with age and
## twinkling; a slot with no spark this frame is collapsed.
func _draw_embers(i: int, m: int, cam_at: Vector3, cam_right: Vector3, w0: float, wind: Vector3) -> void:
	var n := _n
	var hot := hot_head * 0.6
	for slot in _ember_slots:
		var k := slot * _ember_step
		var a := 0.0
		var age := 0.0
		var fade := 0.0
		var key := 0.0
		if k < m - 1:
			age = _cage[k]
			fade = clampf(1.0 - age / fade_s, 0.0, 1.0)
			key = float(k + int(_time * 7.0)) * 3.17 + float(i) * 11.0
			a = _cstr[k] * fade * clampf(_vnoise(_time * flicker_hz * 1.7 + key) * 2.0, 0.0, 1.0)
		if a <= 0.02:
			for v in 5:
				_verts[n + v] = Vector3.ZERO
			n += 5
			continue
		var to_cam := (cam_at - _chain[k]).normalized()
		var side := to_cam.cross(Vector3.UP)
		side = side.normalized() if side.length_squared() > 1e-6 else cam_right
		var up := side.cross(to_cam).normalized()
		var off := side * (_vnoise(key + 50.0) * 1.5) + up * (0.5 + 0.5 * _vnoise(key + 90.0))
		var at := _chain[k] + (off + wind * 0.5) * (EMBER_DRIFT_MPS * age) + to_cam * _clear_m
		var r := w0 * EMBER_SIZE * (0.5 + 0.5 * fade)
		# A small diamond: bright centre, transparent tips.
		_verts[n] = at
		_cols[n] = Color(_colour.r + (1.0 - _colour.r) * hot, _colour.g + (1.0 - _colour.g) * hot,
			_colour.b + (1.0 - _colour.b) * hot, minf(a, 1.0))
		_verts[n + 1] = at + side * r
		_verts[n + 2] = at + up * r
		_verts[n + 3] = at - side * r
		_verts[n + 4] = at - up * r
		n += 5
	_n = n

## The glowing eye: a hot core in the socket and a bloom spreading outward from it, dimming ring by
## ring to nothing. Pulled towards the camera along the view ray only, so it sits on the eye on screen.
func _draw_halo(i: int, eye: Vector3, cam: Camera3D, glow: float) -> void:
	var to_cam := (cam.global_position - eye).normalized() if cam != null else Vector3.BACK
	var right := cam.global_basis.x if cam != null else Vector3.RIGHT
	var up := cam.global_basis.y if cam != null else Vector3.UP
	var centre := eye + to_cam * maxf(_radius * HALO_PUSH, _clear_m * 0.5)
	var mpp := _m_per_px(cam, eye)
	var shimmer := 1.0 + 0.1 * flicker * _vnoise(_time * flicker_hz * 0.7 + float(i) * 9.1)
	# A moving eye burns hotter: the bloom brightens with the flame.
	var a := glow * minf(1.0, (0.8 + 0.2 * _str[i]) * shimmer)
	var bloom_r := maxf(_radius * BLOOM_PER_RADIUS, MIN_BLOOM_PX * mpp)
	for s in HALO_SLICES:
		_dirs[s] = right * _cos[s] + up * _sin[s]
	var n := _n
	# Bloom: a centre and three rings, alpha falling outward.
	for ring in BLOOM_RING.size():
		var h := hot_head * (1.0 - BLOOM_RING[ring])
		var col := Color(_colour.r + (1.0 - _colour.r) * h, _colour.g + (1.0 - _colour.g) * h,
			_colour.b + (1.0 - _colour.b) * h, a * BLOOM_ALPHA[ring])
		if ring == 0:
			_verts[n] = centre
			_cols[n] = col
			n += 1
			continue
		var r := BLOOM_RING[ring] * bloom_r
		for s in HALO_SLICES:
			_verts[n] = centre + _dirs[s] * r
			_cols[n] = col
			n += 1
	# Core: small, white-hot, on top of the bloom.
	var core_r := maxf(_radius * CORE_PER_RADIUS, MIN_CORE_PX * mpp)
	_verts[n] = centre
	_cols[n] = Color(1.0, 1.0, 1.0, minf(a, 1.0))
	n += 1
	var edge := Color(_colour.r + (1.0 - _colour.r) * 0.5, _colour.g + (1.0 - _colour.g) * 0.5,
		_colour.b + (1.0 - _colour.b) * 0.5, 0.0)
	for s in HALO_SLICES:
		_verts[n] = centre + _dirs[s] * core_r
		_cols[n] = edge
		n += 1
	_n = n

static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)

## Smooth 1D value noise in [-1, 1]: lattice values from a table, smoothstep between them.
static func _vnoise(x: float) -> float:
	var i := floori(x)
	var f := x - float(i)
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_lattice[i & 255], _lattice[(i + 1) & 255], f)

static func _hash(n: float) -> float:
	var h := sin(n * 127.1 + 311.7) * 43758.5453
	return (h - floorf(h)) * 2.0 - 1.0

func _hide() -> void:
	_ribbon_verts = 0
	_alpha = 0.0
	_ribbon_dirty = true
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
		_speed[i] = 0.0
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

## Strands drawn per eye (STRANDS, or STRANDS_LOW on the low-quality path).
func strand_count() -> int:
	return _strands

func is_low_quality() -> bool:
	return _low

## Vertices drawn this frame (streaks + halos) and the streaks' share of them.
func vertex_count() -> int:
	return _vcount if visible else 0

func ribbon_vertex_count() -> int:
	return _ribbon_verts if visible else 0
