extends SceneTree
## EYETRAILS acceptance: the fading motion ribbon behind the glowing eyes.
##  - one ImmediateMesh ribbon per creature holding both eyes' trails (additive, unshaded, no shadow);
##  - a still head draws nothing (length 0, alpha 0, no surface, node hidden), a fast head draws a
##    ribbon whose length and alpha grow with speed and whose alpha fades to 0 within ~0.3 s of stopping;
##  - the ring buffer never holds more than the cap for one eye;
##  - nothing is drawn while the eyes do not glow (day, dead, asleep) or the animal is far from the camera;
##  - twenty animals cost twenty trail meshes and no more;
##  - round 2: a flame shader tears the strands; the low-quality path (web renderer, phones) draws one
##    strand per eye and one noise tap; nothing is allocated per frame in script.
## Run: Godot --headless --path game --script res://tests/t_eyetrails.gd -> "[t_eyetrails] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const SPECIES: Array[StringName] = [&"tyrannosaurus", &"utahraptor", &"compsognathus"]
const DT := 1.0 / 60.0
## Owner: the ribbon "shows when the head moves fast ... and is barely visible at idle".
const FAST_MPS := 4.2
const IDLE_MPS := 0.02
## ASSUMPTION (owner gave 0.15-0.3 s): a full ribbon is gone within this long after the head stops.
const GONE_S := 0.45

var _fails: PackedStringArray = []
var _started := false
var EYES: GDScript
var TRAIL: GDScript
var WL: GDScript
var DD: Node
var _creatures: Array[Node] = []

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_eyetrails] FAIL %s" % what)

func _run() -> void:
	# Optional look at the flame (never used by the gate, which runs without user args): a windowed
	# run with `-- --shot-dir=DIR` renders a running animal and saves three PNGs for eyeballing.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			await _shot_pass(a.substr(11))
			return
	create_timer(60.0).timeout.connect(func() -> void:
		print("[t_eyetrails] FAIL watchdog")
		quit(1))
	DD = root.get_node("Data")
	EYES = load("res://scripts/creatures/creature_eyes.gd")
	TRAIL = load("res://scripts/creatures/eye_trail.gd")
	WL = load("res://scripts/world/world_lighting.gd")
	_expect(TRAIL != null, "eye_trail.gd loads")
	_expect(EYES != null, "creature_eyes.gd loads")
	if TRAIL == null or EYES == null:
		_finish()
		return
	var cap := int(TRAIL.get_script_constant_map().get("MAX_SAMPLES", 0))
	_expect(cap > 1 and cap <= 12, "the sample cap is small (MAX_SAMPLES=%d)" % cap)
	for id in SPECIES:
		await _test_species(id, cap)
	await _test_flame()
	await _test_shape()
	await _test_knobs()
	await _test_quality_and_alloc()
	for id: StringName in [&"deinonychus", &"tyrannosaurus"]:
		await _test_hidden_eye(id)
	await _test_cost_and_cull()
	for c in _creatures:
		if is_instance_valid(c):
			c.queue_free()
	_creatures.clear()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_eyetrails] PASS")
		quit(0)
	else:
		for f in _fails:
			print("[t_eyetrails] FAIL %s" % f)
		quit(1)

func _spawn(id: StringName) -> Node:
	var c: Node = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	root.add_child(c)
	c.spawn(DD.creature(id))
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.anim.set_physics_process(false)
	_creatures.append(c)
	return c

## The trail node of a spawned animal, with its own _process off: this test drives tick() with a
## fixed dt so the numbers do not depend on the headless frame rate.
func _trail_of(c: Node) -> Node:
	var eyes = c.view.get_node_or_null("Eyes")
	if eyes == null:
		return null
	eyes.set_process(false)
	return eyes.trail

## Moves the animal (and so the head and both dots) this many metres this tick, then ticks the trail.
func _move(c: Node, trail: Node, by: Vector3) -> void:
	c.global_position = c.global_position + by
	trail.tick(DT)

func _test_species(id: StringName, cap: int) -> void:
	var had_night: float = WL.night
	var c := _spawn(id)
	await process_frame
	await process_frame
	var eyes = c.view.get_node_or_null("Eyes")
	_expect(eyes != null, "%s has an Eyes node" % id)
	if eyes == null:
		return
	var trail = _trail_of(c)
	_expect(trail != null, "%s has a trail node" % id)
	if trail == null:
		return
	_expect(trail is MeshInstance3D and trail.mesh is ArrayMesh, "%s trail is one mesh" % id)
	_expect((trail as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"%s trail casts no shadow" % id)
	# The flame shader: its render modes carry what the StandardMaterial used to.
	var mat := (trail as MeshInstance3D).material_override as ShaderMaterial
	var code: String = mat.shader.code if mat != null and mat.shader != null else ""
	for mode in ["unshaded", "blend_add", "depth_draw_never", "fog_disabled", "shadows_disabled"]:
		_expect(code.contains(mode), "%s trail shader is %s" % [id, mode])
	_expect(mat != null and mat.get_shader_parameter(&"flame_noise") is Texture2D,
		"%s trail shader has its noise texture" % id)
	_expect(trail.top_level, "%s trail vertices are in world space, not riding the head bone" % id)
	# Night: the ribbon may show.
	WL.night = 1.0
	# Idle first: a still head leaves nothing behind.
	for _i in 90:
		trail.tick(DT)
	_expect(trail.sample_count() == 0, "%s still head keeps no samples (%d)" % [id, trail.sample_count()])
	_expect(trail.ribbon_length() == 0.0 and trail.trail_alpha() == 0.0,
		"%s still head draws nothing" % id)
	_expect(trail.ribbon_vertex_count() == 0 and trail.vertex_count() > 0,
		"%s still head at night: the eye halo glows, no streak (%d streak verts)" % [id, trail.ribbon_vertex_count()])
	# A slow drift stays dark.
	var step_slow := Vector3(0, 0, IDLE_MPS * DT)
	for _i in 60:
		_move(c, trail, step_slow)
		_expect(trail.sample_count() <= cap, "%s slow drift stays under the sample cap" % id)
	_expect(trail.trail_alpha() == 0.0 and trail.ribbon_length() == 0.0,
		"%s a slow drift draws nothing (alpha %.3f)" % [id, trail.trail_alpha()])
	# Fast: a run (here along +X, the head and both dots translate with the body).
	var step_fast := Vector3(FAST_MPS * DT, 0, 0)
	var peak_len := 0.0
	var peak_alpha := 0.0
	var worst_samples := 0
	var kept_under_cap := true
	for _i in 90:
		_move(c, trail, step_fast)
		worst_samples = maxi(worst_samples, trail.total_samples())
		kept_under_cap = kept_under_cap and trail.sample_count() <= cap
		peak_len = maxf(peak_len, trail.ribbon_length())
		peak_alpha = maxf(peak_alpha, trail.trail_alpha())
	_expect(kept_under_cap, "%s sample count never passes the cap %d (worst eye %d)" % [id, cap, trail.sample_count()])
	_expect(worst_samples <= cap * 2, "%s both eyes together stay under 2x the cap (%d)" % [id, worst_samples])
	_expect(peak_len > 0.15, "%s a fast head leaves a ribbon (%.2f m)" % [id, peak_len])
	_expect(peak_alpha > 0.2, "%s the fast ribbon is visible (peak alpha %.2f)" % [id, peak_alpha])
	_expect(trail.surface_count() == 1 and (trail as Node3D).visible,
		"%s fast ribbon is one drawn surface" % id)
	_expect(trail.ribbon_vertex_count() > 0, "%s fast ribbon has geometry" % id)
	# Fade: stop dead and the ribbon is gone inside the documented 0.15-0.3 s window (plus slack).
	var gone_at := -1.0
	var t := 0.0
	for _i in int(ceil(GONE_S / DT)) + 2:
		trail.tick(DT)
		t += DT
		if gone_at < 0.0 and trail.ribbon_vertex_count() == 0:
			gone_at = t
	_expect(gone_at > 0.0 and gone_at <= GONE_S, "%s ribbon fades out after stopping (%.3f s)" % [id, gone_at])
	_expect(trail.ribbon_length() == 0.0 or trail.sample_count() == 0,
		"%s a stopped head keeps no ribbon" % id)
	# Day: the eyes barely glow, so no ribbon.
	WL.night = 0.0
	for _i in 60:
		_move(c, trail, step_fast)
	_expect(trail.sample_count() == 0 and trail.surface_count() == 0,
		"%s no ribbon while the eyes do not glow by day" % id)
	# Night again, build a ribbon, then kill the animal: the dots hide and so must the ribbon.
	WL.night = 1.0
	for _i in 30:
		_move(c, trail, step_fast)
	_expect(trail.surface_count() == 1, "%s ribbon is back at night" % id)
	c.health.dead = true
	trail.tick(DT)
	_expect(trail.sample_count() == 0 and trail.surface_count() == 0,
		"%s ribbon hides when the dead animal's eyes stop glowing" % id)
	c.health.dead = false
	# Asleep is the other half of the eyeshine rule.
	c.brain.state = &"sleep"
	for _i in 30:
		_move(c, trail, step_fast)
	_expect(trail.sample_count() == 0 and trail.surface_count() == 0,
		"%s ribbon hides while the animal sleeps" % id)
	c.brain.state = &"roam"
	WL.night = had_night
	c.queue_free()
	await process_frame

## The owner's refinement: "a FLAME IN THE WIND ... a streak that lags behind ... tapering, with a
## little flicker/turbulence". While the head keeps moving at a constant speed, the drawn width and
## alpha must vary from frame to frame (flicker) and the tail must stream upward (drift); with the
## flicker knob at 0 the same motion must come out steady, so the wobble is the knob and not the motion.
func _test_flame() -> void:
	var had_night: float = WL.night
	WL.night = 1.0
	var c := _spawn(&"tyrannosaurus")
	await process_frame
	await process_frame
	var trail = _trail_of(c)
	_expect(trail != null, "flame test has a trail")
	if trail == null:
		return
	_expect(trail.flicker > 0.0 and trail.drift_mps > 0.0 and trail.taper < 1.0,
		"the flame knobs are on (flicker %.2f, drift %.2f m/s, taper %.2f)" % [trail.flicker, trail.drift_mps, trail.taper])
	var widths := _run_fast(c, trail, 60)
	var alphas := _run_alphas(c, trail, 60)
	var spread := _rel_spread(widths)
	print("[t_eyetrails] flame width spread %.3f (min %.4f m, max %.4f m) over %d frames" % [spread,
		_arr_min(widths), _arr_max(widths), widths.size()])
	_expect(spread > 0.04, "the ribbon width flickers frame to frame (relative spread %.3f)" % spread)
	_expect(_rel_spread(alphas) > 0.02, "the ribbon alpha flickers frame to frame (relative spread %.3f)" % _rel_spread(alphas))
	_expect(trail.ribbon_rise() > 0.0, "the flame's tail streams upward (%.3f m)" % trail.ribbon_rise())
	_expect(trail.max_quad_width() > 0.0 and trail.width_spread() > 0.0,
		"the ribbon tapers and wobbles along its length (width spread %.4f m)" % trail.width_spread())
	# Same motion, flicker off: the width no longer wobbles with time.
	var steady: MeshInstance3D = TRAIL.new()
	root.add_child(steady)
	steady.setup(trail.get("_eyes"), trail.get("_dots"), 0.02, Color.WHITE, {"trail": {"flicker": 0.0}})
	steady.max_distance_m = 1.0e6
	_expect(steady.flicker == 0.0, "the flicker knob can be turned off from data")
	var flat := _run_fast(c, steady, 60)
	var flat_spread := _rel_spread(flat)
	_expect(flat_spread < spread * 0.35, "flicker 0 steadies the ribbon (%.4f vs %.4f)" % [flat_spread, spread])
	# The flame knobs are data: one small table, not scattered magic numbers.
	for key in ["FLICKER", "FLICKER_HZ", "DRIFT_MPS", "TAPER"]:
		_expect(TRAIL.get_script_constant_map().has(key), "flame knob %s is a named constant" % key)
	steady.queue_free()
	WL.night = had_night
	await process_frame

## The candle-flame shape, measured on the built mesh (owner: "trails that look like a flame in the
## wind"): it tapers (tail narrower than the eye end), its edges are feathered (edge vertex alpha 0
## while the core burns), and from the real game camera (4.3 deg lens, 14 m zoom, ~190 m out) it is
## several pixels wide, so it can actually be seen; the eye halo it starts from is drawn too.
func _test_shape() -> void:
	var had_night: float = WL.night
	WL.night = 1.0
	var c := _spawn(&"deinonychus")
	await process_frame
	await process_frame
	var trail = _trail_of(c)
	_expect(trail != null, "shape test has a trail")
	if trail == null:
		return
	var iso: GDScript = load("res://scripts/camera/iso_camera.gd")
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = float(iso.get_script_constant_map().get("FOV_DEG", 4.3))
	cam.basis = iso.view_basis()
	var eyes = c.view.get_node_or_null("Eyes")
	var eye: Vector3 = (eyes.dots[0] as Node3D).global_position
	cam.global_position = eye + cam.global_basis.z * float(iso.distance_for(14.0))
	cam.current = true
	await process_frame
	# Still: the halo alone.
	for _i in 30:
		trail.tick(DT)
	_expect(trail.vertex_count() > 0 and trail.ribbon_vertex_count() == 0 and trail.ribbon_length() == 0.0,
		"a still head at the game camera shows the glowing eye and no streak")
	# Run sideways across the screen.
	var right: Vector3 = cam.global_basis.x
	for _i in 30:
		c.global_position = c.global_position + right * (FAST_MPS * 1.5 * DT)
		trail.tick(DT)
	_expect(trail.tail_width() < trail.head_width() * 0.5,
		"the flame tapers to a point (tail %.4f m, eye end %.4f m)" % [trail.tail_width(), trail.head_width()])
	_expect(trail.max_quad_width() > trail.head_width(),
		"the flame body swells past its base (%.4f vs %.4f m)" % [trail.max_quad_width(), trail.head_width()])
	_expect(trail.trail_alpha() > 0.5 and trail.edge_alpha_ratio() < 0.05,
		"the flame edges are feathered (edge/core alpha %.3f, core %.2f)" % [trail.edge_alpha_ratio(), trail.trail_alpha()])
	# Feathering checked on the actual vertex colours too: some streak vertices are fully transparent.
	var cols: PackedColorArray = trail.get("_cols")
	var lo := 1.0
	var hi := 0.0
	for k in trail.ribbon_vertex_count():
		lo = minf(lo, cols[k].a)
		hi = maxf(hi, cols[k].a)
	_expect(lo < 0.01 and hi > 0.5, "streak vertex alpha runs from the transparent edge to the core (%.3f..%.2f)" % [lo, hi])
	var at: Vector3 = (eyes.dots[0] as Node3D).global_position
	var px_eye := cam.unproject_position(at).distance_to(cam.unproject_position(at + right * trail.head_width() * 2.0))
	var px_body := cam.unproject_position(at).distance_to(cam.unproject_position(at + right * trail.max_quad_width() * 2.0))
	print("[t_eyetrails] game camera: flame %.1f px wide at the eye, %.1f px at its widest" % [px_eye, px_body])
	# Round 2 made the strands thinner on purpose (owner: thinner, longer); the fan of strands and the
	# glow under them carry the width, so the main strand only needs to stay a few pixels wide.
	_expect(px_eye >= 3.5 and px_body >= 5.0,
		"the flame is visible from the game camera (%.1f px at the eye, %.1f px widest)" % [px_eye, px_body])
	var len_px := cam.unproject_position(at).distance_to(cam.unproject_position(trail.world_tail()))
	_expect(len_px >= 60.0, "the flame is long enough to read from the game camera (%.0f px)" % len_px)
	cam.queue_free()
	c.queue_free()
	WL.night = had_night
	await process_frame

## Moves the animal at a constant fast speed and collects the widest quad per frame, once the streak
## has reached its full length (the first WARM frames grow it from nothing, which is not flicker).
const WARM := 20
func _run_fast(c: Node, trail: Node, frames: int) -> Array[float]:
	var out: Array[float] = []
	for f in frames + WARM:
		c.global_position = c.global_position + Vector3(FAST_MPS * DT, 0, 0)
		trail.tick(DT)
		if f >= WARM and trail.ribbon_vertex_count() > 0:
			out.append(trail.max_quad_width())
	return out

## Same run, collecting the brightest quad alpha per frame.
func _run_alphas(c: Node, trail: Node, frames: int) -> Array[float]:
	var out: Array[float] = []
	for _i in frames:
		c.global_position = c.global_position + Vector3(FAST_MPS * DT, 0, 0)
		trail.tick(DT)
		if trail.surface_count() > 0:
			out.append(trail.alpha_spread())
	return out

func _arr_min(v: Array[float]) -> float:
	var m := INF
	for x in v:
		m = minf(m, x)
	return m

func _arr_max(v: Array[float]) -> float:
	var m := 0.0
	for x in v:
		m = maxf(m, x)
	return m

## (max - min) / mean over the collected numbers; 0 when there is nothing to compare.
func _rel_spread(v: Array[float]) -> float:
	if v.size() < 2:
		return 0.0
	var lo := _arr_min(v)
	var hi := _arr_max(v)
	var acc := 0.0
	for x in v:
		acc += x
	var mean := acc / float(v.size())
	return (hi - lo) / mean if mean > 1e-6 else 0.0

## The knobs: one small table, read from the species' eyes block, clamped, and honoured by the ribbon
## (a shorter fade drops samples sooner; a tiny max_samples caps the buffer; a never-moving animal is
## still the same object, so nothing is allocated per frame).
func _test_knobs() -> void:
	var had_night: float = WL.night
	WL.night = 1.0
	var c := _spawn(&"tyrannosaurus")
	await process_frame
	await process_frame
	var trail = _trail_of(c)
	_expect(trail != null, "knob test has a trail")
	if trail == null:
		return
	var constants: Dictionary = TRAIL.get_script_constant_map()
	for key in ["MAX_SAMPLES", "FADE_S", "MIN_SPEED_MPS", "FULL_SPEED_MPS", "WIDTH_PER_RADIUS",
			"ENERGY", "MAX_CAMERA_DISTANCE_M"]:
		_expect(constants.has(key) and float(constants[key]) > 0.0, "trail knob %s is a positive constant" % key)
	var fade := float(constants.get("FADE_S", 0.0))
	_expect(fade >= 0.15 and fade <= 0.3, "the fade sits in the owner's 0.15-0.3 s band (%.2f s)" % fade)
	# A shorter fade must empty the buffer sooner: re-set up the same trail with a small fade knob.
	var tight: MeshInstance3D = TRAIL.new()
	root.add_child(tight)
	tight.setup(trail.get("_eyes"), trail.get("_dots"), 0.02, Color.WHITE, {"trail": {
		"fade_s": 0.06, "max_samples": 4, "min_speed_mps": 0.5}})
	_expect(is_equal_approx(tight.fade_s, 0.06) and tight.max_samples == 4,
		"the eyes block's trail table overrides the knobs (fade %.2f, samples %d)" % [tight.fade_s, tight.max_samples])
	tight.max_distance_m = 1.0e6
	for _i in 40:
		c.global_position = c.global_position + Vector3(FAST_MPS * DT, 0, 0)
		tight.tick(DT)
	_expect(tight.sample_count() <= 4, "the overridden cap holds (%d)" % tight.sample_count())
	var at_stop: int = tight.sample_count()
	for _i in int(ceil(0.12 / DT)):
		tight.tick(DT)
	_expect(at_stop > 0 and tight.sample_count() == 0 and tight.ribbon_vertex_count() == 0,
		"the overridden fade empties the ribbon in %.2f s (was %d samples)" % [0.12, at_stop])
	# A bad table cannot spin the buffer or paint the world.
	var wild: MeshInstance3D = TRAIL.new()
	root.add_child(wild)
	wild.setup(trail.get("_eyes"), trail.get("_dots"), 0.02, Color.WHITE, {"trail": {
		"fade_s": 99.0, "max_samples": 999, "min_speed_mps": -5.0, "energy": 1.0e6}})
	_expect(wild.max_samples <= int(constants.get("MAX_SAMPLES", 12)) and wild.fade_s <= 0.6,
		"a nonsense trail table is clamped (%d samples, %.2f s)" % [wild.max_samples, wild.fade_s])
	# The length knob: even a sprint far faster than any gait may not draw a streak across the screen.
	var short: MeshInstance3D = TRAIL.new()
	root.add_child(short)
	short.setup(trail.get("_eyes"), trail.get("_dots"), 0.02, Color.WHITE, {"trail": {
		"max_length_m": 0.25, "max_distance_m": 1.0e6}})
	_expect(is_equal_approx(short.max_length_m, 0.25), "the length knob comes from data (%.2f m)" % short.max_length_m)
	var longest := 0.0
	for _i in 60:
		c.global_position = c.global_position + Vector3(12.0 * DT, 0, 0)
		short.tick(DT)
		longest = maxf(longest, short.ribbon_length())
	_expect(longest > 0.0 and longest <= 0.30, "the ribbon honours its length cap at 12 m/s (%.2f m <= 0.25 m)" % longest)
	short.queue_free()
	wild.queue_free()
	tight.queue_free()
	WL.night = had_night
	await process_frame

## Round 3 (owner: "when the enemy is facing you such that you should only see one eye, you see both"):
## from a 90 deg profile at the iso camera's 35 deg elevation the far eye's core and bloom contribute
## ~0 while the near one is full; head-on both are full. The far eye's flame is hidden at the eye and
## shows again once it has streamed out past the skull.
func _test_hidden_eye(id: StringName) -> void:
	var had_night: float = WL.night
	WL.night = 1.0
	var c := _spawn(id)
	await process_frame
	await process_frame
	var trail = _trail_of(c)
	var eyes = c.view.get_node_or_null("Eyes")
	if trail == null or eyes == null:
		_expect(false, "%s hidden-eye test has a trail" % id)
		return
	var p0: Vector3 = (eyes.dots[0] as Node3D).global_position
	var p1: Vector3 = (eyes.dots[1] as Node3D).global_position
	var mid := (p0 + p1) * 0.5
	var out := Vector3(p0.x - p1.x, 0.0, p0.z - p1.z).normalized()
	var sk: Skeleton3D = c.view.rig.skeleton
	var head := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin
	var fwd := Vector3(mid.x - head.x, 0.0, mid.z - head.z)
	fwd = (fwd - out * fwd.dot(out)).normalized()
	var cam := Camera3D.new()
	# A teleported camera must not be interpolated towards its new place over the physics ticks.
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(cam)
	cam.fov = 4.3
	cam.current = true
	var elev := deg_to_rad(35.0)
	var dist := 190.0
	var got := {}
	for view in ["profile", "head_on"]:
		var horiz: Vector3 = out if view == "profile" else fwd
		cam.global_position = mid + (horiz * cos(elev) + Vector3.UP * sin(elev)) * dist
		cam.look_at(mid, Vector3.UP)
		await process_frame
		for _i in 10:
			trail.tick(DT)
		got[view] = Vector2(trail.halo_alpha(0), trail.halo_alpha(1))
	var pr: Vector2 = got["profile"]
	var ho: Vector2 = got["head_on"]
	print("[t_eyetrails] %s halo alpha near/far: profile %.3f / %.3f, head-on %.3f / %.3f" % [id, pr.x, pr.y, ho.x, ho.y])
	_expect(pr.x > 0.5 and pr.y <= 0.02 * pr.x, "%s profile: the far eye's core is hidden (%.3f vs near %.3f)" % [id, pr.y, pr.x])
	_expect(minf(ho.x, ho.y) >= 0.9 * maxf(ho.x, ho.y) and ho.x > 0.5, "%s head-on: both eyes glow (%.3f / %.3f)" % [id, ho.x, ho.y])
	# The far eye's flame in profile: nothing at the eye, all of it past the skull.
	cam.global_position = mid + (out * cos(elev) + Vector3.UP * sin(elev)) * dist
	cam.look_at(mid, Vector3.UP)
	await process_frame
	trail.tick(DT)
	var sep := p0.distance_to(p1)
	print("[t_eyetrails] %s past skull: far at eye %.3f, far at 2 sep %.3f, near at eye %.3f" % [id,
		trail.call("_past_skull", 1, 0.0), trail.call("_past_skull", 1, 2.0 * sep), trail.call("_past_skull", 0, 0.0)])
	_expect(trail.call("_past_skull", 1, 0.0) <= 0.02 and is_equal_approx(trail.call("_past_skull", 1, 2.0 * sep), 1.0)
		and is_equal_approx(trail.call("_past_skull", 0, 0.0), 1.0),
		"%s profile: the far flame starts past the skull, the near one at the eye" % id)
	cam.queue_free()
	c.queue_free()
	WL.night = had_night
	await process_frame

## Forces the dots' global transforms up to date (outside any timer).
func _settle(trail: Node) -> void:
	for d: Node3D in trail.get("_dots"):
		var _p := d.global_position

## Round 2: the quality toggle and the no-allocation rule.
## High: STRANDS strands per eye, two noise taps. Low (EyeTrail.low_quality, on for gl_compatibility and
## phones): one strand, fewer rows, one noise tap, so it draws fewer vertices and costs less script.
## No per-frame allocation: the vertex buffers keep their fixed size, no Object is created per tick, the
## static memory does not grow, and the tick-path functions contain no allocating construct.
func _test_quality_and_alloc() -> void:
	var had_night: float = WL.night
	var had_low: bool = TRAIL.get("low_quality")
	WL.night = 1.0
	var verts := {}
	var cost := {}
	for low in [false, true]:
		TRAIL.set("low_quality", low)
		var c := _spawn(&"deinonychus")
		await process_frame
		await process_frame
		var trail = _trail_of(c)
		if trail == null:
			_expect(false, "quality test has a trail")
			return
		var mat := (trail as MeshInstance3D).material_override as ShaderMaterial
		var tag := "low" if low else "high"
		_expect(trail.is_low_quality() == low, "%s: the trail took the quality toggle" % tag)
		_expect(mat.shader.code.contains("#define LOW") == low, "%s: the shader variant matches (one noise tap when low)" % tag)
		_expect(trail.strand_count() == (int(TRAIL.get_script_constant_map()["STRANDS_LOW"]) if low
			else int(TRAIL.get_script_constant_map()["STRANDS"])), "%s: %d strands per eye" % [tag, trail.strand_count()])
		var worst := 0
		for _i in 40:
			_move(c, trail, Vector3(FAST_MPS * DT, 0, 0))
			worst = maxi(worst, trail.vertex_count())
		_expect(trail.trail_alpha() > 0.2 and trail.ribbon_vertex_count() > 0, "%s: the flame draws" % tag)
		verts[low] = worst
		# Allocation checks on the warmed-up trail.
		var buf: int = (trail.get("_verts") as PackedVector3Array).size()
		var objs := Performance.get_monitor(Performance.OBJECT_COUNT)
		var mem := OS.get_static_memory_usage()
		# Best of three batches of 120 ticks, so a scheduler hiccup does not decide the comparison.
		var best := INF
		for _b in 3:
			var spent := 0
			for _i in 120:
				c.global_position = c.global_position + Vector3(FAST_MPS * DT, 0, 0)
				_settle(trail)
				var t0 := Time.get_ticks_usec()
				trail.tick(DT)
				spent += Time.get_ticks_usec() - t0
			best = minf(best, float(spent) / 120.0)
		cost[low] = best
		var grew := OS.get_static_memory_usage() - mem
		_expect((trail.get("_verts") as PackedVector3Array).size() == buf and buf == trail.vertex_count()
			and buf <= int(TRAIL.get_script_constant_map()["MAX_VERTICES"]),
			"%s: the vertex buffer keeps its fixed size (%d)" % [tag, buf])
		_expect(Performance.get_monitor(Performance.OBJECT_COUNT) == objs,
			"%s: no Object is created per tick (%d -> %d)" % [tag, objs, Performance.get_monitor(Performance.OBJECT_COUNT)])
		_expect(grew < 4096, "%s: static memory does not grow over 360 ticks (%d bytes)" % [tag, grew])
		c.queue_free()
		await process_frame
	print("[t_eyetrails] quality: high %d verts %.1f us/tick, low %d verts %.1f us/tick" % [verts[false], cost[false],
		verts[true], cost[true]])
	_expect(verts[true] < verts[false] * 0.7, "low quality draws far fewer vertices (%d vs %d)" % [verts[true], verts[false]])
	_expect(cost[true] < cost[false] * 0.9, "low quality costs less script (%.1f vs %.1f us)" % [cost[true], cost[false]])
	# The tick path builds no arrays, objects or strings: every buffer is sized once in setup().
	var src: String = TRAIL.source_code
	for fn in ["tick", "_track", "_build", "_collapse", "_draw_streak", "_draw_embers", "_draw_halo",
			"_m_per_px", "_facing", "_past_skull", "_catmull", "_vnoise"]:
		var at := src.find("\nfunc %s(" % fn)
		if at < 0:
			at = src.find("\nstatic func %s(" % fn)
		_expect(at >= 0, "tick-path function %s exists" % fn)
		var stop := src.find("\nfunc ", at + 1)
		var stop2 := src.find("\nstatic func ", at + 1)
		if stop2 >= 0 and (stop < 0 or stop2 < stop):
			stop = stop2
		var body := src.substr(at, (stop - at) if stop > 0 else -1)
		for bad in ["[]", ".new(", "Array(", ".resize(", ".duplicate(", "{}", "\" %"]:
			_expect(not body.contains(bad), "tick-path %s allocates nothing (found `%s`)" % [fn, bad])
	TRAIL.set("low_quality", had_low)
	WL.night = had_night

## Look pass (never part of the gate): a night island stand-in (ground, WorldLighting at midnight, the
## real IsoCamera at its default zoom) with an animal standing, running a curve and snapping round.
## Saves 800x450 crops of the game-camera frame around the head (same pixels, not rescaled),
## then quits; prints "[t_eyetrails] shots DIR".
## Extra user args: --shot-species=a,b  --shot-zoom=<m> (default 14, the game's default zoom)
## --shot-tod=<0..1> (default 0 = midnight; 0.79 is dusk).
func _shot_pass(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	# A phone or browser frame rate, not the 120-280 fps an idle lab window runs at.
	Engine.max_fps = 60
	WL = load("res://scripts/world/world_lighting.gd")
	DD = root.get_node("Data")
	var species: PackedStringArray = ["deinonychus", "tyrannosaurus"]
	var zoom := 14.0
	var tod := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-tod="):
			tod = float(a.substr(11))
		elif a.begins_with("--shot-species="):
			species = a.substr(15).split(",")
		elif a.begins_with("--shot-zoom="):
			zoom = float(a.substr(12))
	var game := root.get_node("Game")
	# A T. rex stands 8 m: at the default 14 m zoom its head leaves the frame, so it gets the max zoom.
	var zooms := {&"tyrannosaurus": maxf(zoom, 18.0)}
	game.set("time_of_day", tod)
	var host := Node3D.new()
	root.add_child(host)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22, 0.3, 0.16)
	ground.material_override = gm
	host.add_child(ground)
	WL.install(host)
	var cam_script: GDScript = load("res://scripts/camera/iso_camera.gd")
	var cam: Camera3D = cam_script.new()
	cam.size = zoom
	host.add_child(cam)
	cam.current = true
	for id in species:
		cam.size = float(zooms.get(StringName(id), zoom))
		await _shot_species(StringName(id), dir, cam)
	print("[t_eyetrails] shots %s (tod %.2f, night %.2f, %s)" % [dir, tod, WL.night, RenderingServer.get_current_rendering_method()])
	quit(0)

func _shot_species(id: StringName, dir: String, cam: Camera3D) -> void:
	var c := _spawn(id)
	c.global_position = Vector3.ZERO
	c.anim.set_physics_process(true)
	if c.label:
		c.label.visible = false
	# The game camera follows the player, not the animal: frame a point at the animal's mid-height so the
	# whole body stays in shot, and let the camera's own follow lag do the rest.
	var focus := Node3D.new()
	root.add_child(focus)
	cam.set("_target", focus)
	var dt := 1.0 / 60.0
	var speed := 8.0
	# Start running along the camera's screen-right (yaw -45 deg), so the streak lies across the screen.
	var yaw := deg_to_rad(-45.0)
	c.rotation.y = yaw
	var t := 0.0
	var idle_peak := 0.0
	# Standing first in profile (side on to the camera, the far eye behind the skull), then turned to
	# face the camera head-on, then the run.
	var cam_fwd := -cam.global_basis.z
	var head_on_yaw := atan2(cam_fwd.x, cam_fwd.z)
	var shots := {0.45: "profile", 0.95: "head_on", 1.5: "run_a", 1.75: "run_b", 2.0: "run_c", 2.45: "turn"}
	while t < 2.6:
		await process_frame
		# Real frame time, the same the trail ticks with: a slow windowed frame must not slow the run.
		dt = clampf(root.get_process_delta_time(), 0.001, 0.05)
		var was := t
		t += dt
		if t > 0.5 and t <= 1.0:
			c.rotation.y = head_on_yaw
		elif t > 1.0 and t <= 1.0 + dt * 1.5:
			c.rotation.y = yaw
		if t > 1.0 and t < 2.1:
			# Run a gentle left-hand curve, 30 m radius, facing the way it goes (forward is -Z).
			yaw += speed / 30.0 * dt
			var vel := Vector3(-sin(yaw), 0.0, -cos(yaw)) * speed
			c.global_position += vel * dt
			c.rotation.y = yaw
			c.anim.set_move_speed(speed)
		elif t >= 2.1:
			# Stop and snap the head round: 150 degrees in a quarter second.
			c.anim.set_move_speed(0.0)
			if t < 2.35:
				yaw += deg_to_rad(150.0) / 0.25 * dt
				c.rotation.y = yaw
		if t > 0.5 and t < 1.0:
			idle_peak = maxf(idle_peak, _trail_alpha_of(c))
		focus.global_position = c.global_position + Vector3(0.0, float(c.def.height_meters) * 0.5, 0.0)
		for at: float in shots.keys():
			if was < at and at <= t:
				await RenderingServer.frame_post_draw
				_save_crop(cam, c, "%s/%s_%s.png" % [dir, id, shots[at]])
				var eyes = c.view.get_node_or_null("Eyes")
				if eyes and eyes.trail:
					var e0: Vector3 = (eyes.dots[0] as Node3D).global_position
					print("[t_eyetrails] %s %s streak %.2f m (%.0f px on screen) alpha %.2f head half-width %.3f m" % [id,
						shots[at], eyes.trail.ribbon_length(), cam.unproject_position(e0).distance_to(
						cam.unproject_position(eyes.trail.world_tail())), eyes.trail.trail_alpha(), eyes.trail.head_width() if eyes.trail.has_method("head_width") else 0.0])
					print("  eye %s tail %s" % [e0, eyes.trail.world_tail()])
	print("[t_eyetrails] %s idle streak alpha peak %.3f (%.0f fps)" % [id, idle_peak, Engine.get_frames_per_second()])
	c.queue_free()
	focus.queue_free()
	await process_frame

func _trail_alpha_of(c: Node) -> float:
	var eyes = c.view.get_node_or_null("Eyes")
	return eyes.trail.trail_alpha() if eyes and eyes.trail else 0.0

## An 800x450 crop of the frame around the animal's eye (the game camera's pixels, not rescaled).
func _save_crop(cam: Camera3D, c: Node, path: String) -> void:
	var img := root.get_texture().get_image()
	var eyes = c.view.get_node_or_null("Eyes")
	var at := cam.unproject_position((eyes.dots[0] as Node3D).global_position if eyes else _head_of(c))
	var w := mini(800, img.get_width())
	var h := mini(450, img.get_height())
	var x := clampi(int(at.x) - w / 2, 0, img.get_width() - w)
	var y := clampi(int(at.y) - h / 2, 0, img.get_height() - h)
	img.get_region(Rect2i(x, y, w, h)).save_png(path)

## World head position of a spawned animal.
func _head_of(c: Node) -> Vector3:
	var sk: Skeleton3D = c.view.rig.skeleton
	var i := sk.find_bone("Head")
	if i < 0:
		return c.global_position + Vector3(0, 1.0, 0)
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin

## Twenty animals: one trail mesh each, no particle nodes, no extra meshes, a bounded frame cost; and
## an animal far from the camera builds no ribbon at all.
func _test_cost_and_cull() -> void:
	var had_night: float = WL.night
	WL.night = 1.0
	var ids: Array[StringName] = []
	var dir := DirAccess.open("res://data/creatures")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var row: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/creatures/" + f))
		if row is Dictionary and (row as Dictionary).has("eyes"):
			ids.append(StringName(f.get_basename()))
	ids.sort()
	var spawned: Array[Node] = []
	if ids.is_empty():
		_expect(false, "no species carries an eyes block")
		return
	for i in 20:
		var c := _spawn(ids[i % ids.size()])
		c.global_position = Vector3(float(i % 5) * 3.0, 0.0, float(i / 5) * 3.0)
		spawned.append(c)
	await process_frame
	await process_frame
	var trails: Array[Node] = []
	var trail_owner: Array[Node] = []
	var eyed := 0
	var eye_meshes := 0
	var trail_meshes := 0
	var particles := 0
	for c in spawned:
		var eyes = c.view.get_node_or_null("Eyes")
		if eyes == null:
			# t_eyeglow owns whether a species' rig can host the dots; a species without them has no
			# eyeshine to leave a trail.
			print("[t_eyetrails] note: %s has no Eyes node, skipped" % c.def.id)
			continue
		eyed += 1
		# The dots hang off the Head bone's BoneAttachment3D and the ribbon off the Eyes node, so the
		# whole animal is walked: the point is that the trail added no mesh per sample.
		for n in c.find_children("*", "MeshInstance3D", true, false):
			if (n as Node).has_meta(&"creature_eyeshine"):
				eye_meshes += 1
			elif (n as Node).has_meta(&"creature_eyetrail"):
				trail_meshes += 1
		# The drip FX on some animals are the creature's own; the trail must add no particle node of
		# its own and no child node at all (one mesh, one surface, no per-sample nodes).
		for n in eyes.find_children("*", "GPUParticles3D", true, false):
			particles += 1
		var trail = _trail_of(c)
		if trail != null:
			_expect((trail as Node).get_child_count() == 0, "%s trail adds no child nodes" % c.def.id)
			trails.append(trail)
			trail_owner.append(c)
	_expect(eyed > 0 and trail_meshes == eyed,
		"one trail mesh per eyed animal (%d trails for %d eyed of %d)" % [trail_meshes, eyed, spawned.size()])
	_expect(eye_meshes == eyed * 2, "the trails did not add eye meshes (%d dots for %d animals)" % [eye_meshes, eyed])
	_expect(particles == 0, "the trails created no particle nodes (%d)" % particles)
	# Every animal runs fast for a second: one mesh and one surface each, never a mesh per sample.
	var worst_vertices := 0
	for _i in 60:
		for k in trails.size():
			var body: Node3D = trail_owner[k]
			body.global_position = body.global_position + Vector3(FAST_MPS * DT, 0, 0)
			trails[k].tick(DT)
	for trail in trails:
		worst_vertices = maxi(worst_vertices, trail.vertex_count())
		_expect(trail.surface_count() <= 1, "each creature keeps one ribbon surface (%d)" % trail.surface_count())
	# Both eyes: a fixed number of curve rows x vertex columns, plus the two halos.
	var budget := int(TRAIL.get_script_constant_map().get("MAX_VERTICES", 0))
	_expect(worst_vertices <= budget, "per-creature ribbon stays small (%d vertices, budget %d)" % [worst_vertices, budget])
	_expect(trails.size() == eyed, "%d eyed animals, %d trails" % [eyed, trails.size()])
	_expect(trails.size() >= 17, "%d of 20 animals carry a trail" % trails.size())
	# Frame cost, measured (not assumed): 20 animals kept running at full flame strength for 240 frames.
	# Only tick() is timed; moving the body (and the bone transforms that follows) is the engine's cost
	# with or without eyes, so the dots' transforms are settled before the clock starts.
	var spent := 0
	var frames := 240
	for _f in frames:
		for k in trails.size():
			var body: Node3D = trail_owner[k]
			body.global_position = body.global_position + Vector3(FAST_MPS * DT, 0, 0)
			_settle(trails[k])
			var t0 := Time.get_ticks_usec()
			trails[k].tick(DT)
			spent += Time.get_ticks_usec() - t0
	var per_frame_ms := float(spent) / 1000.0 / float(frames)
	_expect(trails[0].ribbon_vertex_count() > 0, "the cost run measured drawn flames, not bare halos")
	print("[t_eyetrails] %d ribbons at full strength cost %.3f ms per frame of tick work" % [trails.size(), per_frame_ms])
	_expect(per_frame_ms < 2.0, "20 ribbons cost under 2 ms of script per frame (%.3f ms)" % per_frame_ms)
	# Distance cull: the trail stops being built once the animal is beyond the trail's range.
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3.ZERO
	cam.current = true
	await process_frame
	var far_trail = trails[0] if not trails.is_empty() else null
	if far_trail != null:
		var animal: Node3D = trail_owner[0]
		var range_m := float(far_trail.max_distance_m)
		animal.global_position = Vector3(0, 0, range_m + 12.0)
		var builds_before: int = far_trail.build_count()
		for _i in 40:
			animal.global_position = animal.global_position + Vector3(FAST_MPS * DT, 0, 0)
			far_trail.tick(DT)
		_expect(far_trail.build_count() == builds_before,
			"a culled trail stops rebuilding entirely (%d builds)" % (far_trail.build_count() - builds_before))
		_expect(far_trail.sample_count() == 0 and far_trail.surface_count() == 0,
			"an animal beyond the camera range builds no ribbon (%.0f m out)" % range_m)
		# In front of the camera this time (it looks down -Z): the frustum cull lets it draw.
		animal.global_position = Vector3(0, -2.0, -14.0)
		for _i in 40:
			animal.global_position = animal.global_position + Vector3(FAST_MPS * DT, 0, 0)
			far_trail.tick(DT)
		_expect(far_trail.surface_count() == 1, "the same animal draws again once it is near the camera")
	cam.queue_free()
	for c in spawned:
		c.queue_free()
	WL.night = had_night
	await process_frame
