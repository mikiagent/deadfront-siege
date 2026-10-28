extends SceneTree
## EYETRAILS acceptance: the fading motion ribbon behind the glowing eyes.
##  - one ImmediateMesh ribbon per creature holding both eyes' trails (additive, unshaded, no shadow);
##  - a still head draws nothing (length 0, alpha 0, no surface, node hidden), a fast head draws a
##    ribbon whose length and alpha grow with speed and whose alpha fades to 0 within ~0.3 s of stopping;
##  - the ring buffer never holds more than the cap for one eye;
##  - nothing is drawn while the eyes do not glow (day, dead, asleep) or the animal is far from the camera;
##  - twenty animals cost twenty trail meshes and no more.
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
	await _test_knobs()
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
	_expect(trail is MeshInstance3D and trail.mesh is ImmediateMesh,
		"%s trail is one ImmediateMesh ribbon" % id)
	_expect((trail as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"%s trail casts no shadow" % id)
	var mat := (trail as MeshInstance3D).material_override as StandardMaterial3D
	_expect(mat != null and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
		"%s trail is unshaded" % id)
	_expect(mat != null and mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD,
		"%s trail blends additively" % id)
	_expect(mat != null and mat.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED,
		"%s trail writes no depth" % id)
	_expect(trail.top_level, "%s trail vertices are in world space, not riding the head bone" % id)
	# Night: the ribbon may show.
	WL.night = 1.0
	# Idle first: a still head leaves nothing behind.
	for _i in 90:
		trail.tick(DT)
	_expect(trail.sample_count() == 0, "%s still head keeps no samples (%d)" % [id, trail.sample_count()])
	_expect(trail.ribbon_length() == 0.0 and trail.trail_alpha() == 0.0,
		"%s still head draws nothing" % id)
	_expect(not (trail as Node3D).visible and trail.surface_count() == 0,
		"%s still head hides the ribbon mesh" % id)
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
	_expect(trail.vertex_count() > 0, "%s fast ribbon has geometry" % id)
	# Fade: stop dead and the ribbon is gone inside the documented 0.15-0.3 s window (plus slack).
	var gone_at := -1.0
	var t := 0.0
	for _i in int(ceil(GONE_S / DT)) + 2:
		trail.tick(DT)
		t += DT
		if gone_at < 0.0 and trail.surface_count() == 0:
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

## Moves the animal at a constant fast speed and collects the widest quad per frame.
func _run_fast(c: Node, trail: Node, frames: int) -> Array[float]:
	var out: Array[float] = []
	for _i in frames:
		c.global_position = c.global_position + Vector3(FAST_MPS * DT, 0, 0)
		trail.tick(DT)
		if trail.surface_count() > 0:
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
	_expect(at_stop > 0 and tight.sample_count() == 0 and tight.surface_count() == 0,
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

## Renders three frames of a running animal at night so a human can judge the flame. Saves PNGs into
## the given directory and quits; prints "[t_eyetrails] shots DIR".
func _shot_pass(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	WL = load("res://scripts/world/world_lighting.gd")
	DD = root.get_node("Data")
	WL.night = 1.0
	# The shared eye material is only repainted on a night change inside a CreatureEyes tick; a shot pass
	# that switches the clock itself must repaint it or the dots stay at the day glint (black).
	var eyes_script: GDScript = load("res://scripts/creatures/creature_eyes.gd")
	eyes_script.apply_night()
	var host := Node3D.new()
	root.add_child(host)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.0
	host.add_child(cam)
	cam.size = 1.8
	cam.current = true
	var light := DirectionalLight3D.new()
	light.light_energy = 0.25
	light.rotation_degrees = Vector3(-50, 30, 0)
	host.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.03, 0.06)
	env.environment = e
	host.add_child(env)
	var c := _spawn(&"tyrannosaurus")
	c.global_position = Vector3.ZERO
	await process_frame
	await process_frame
	if c.label:
		c.label.visible = false
	var trail = _trail_of(c)
	var eyes = c.view.get_node_or_null("Eyes")
	var eye_at: Vector3 = (eyes.dots[0] as Node3D).global_position
	print("[t_eyetrails] shot eye at %s, head at %s" % [eye_at, _head_of(c)])
	if trail == null:
		print("[t_eyetrails] shots: no trail")
		quit(1)
		return
	for i in 90:
		c.global_position = c.global_position + Vector3(4.0 / 60.0, 0, 0)
		# The camera rides along, framed on the head: the eye stays in shot while the streak trails
		# behind it. (The first attempt framed the feet, which showed nothing.)
		# Side on to the run: the streak trails away along -X in full profile.
		var at := (eyes.dots[0] as Node3D).global_position
		cam.global_position = at + Vector3(0.0, 0.0, 2.2)
		cam.look_at(at, Vector3.UP)
		trail.tick(1.0 / 60.0)
		# Also park the real game camera once: 40 m out, 15 m of screen height, the iso view.
		if i == 79:
			cam.size = 15.0
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.rotation_degrees = Vector3(-35.264, 45.0, 0.0)
			var mid: Vector3 = c.global_position + Vector3(0.0, float(c.def.height_meters) * 0.75, 0.0)
			cam.global_position = mid + cam.global_basis.z * 40.0
			await RenderingServer.frame_post_draw
			var px := cam.unproject_position(trail.world_tail()).distance_to(
				cam.unproject_position((eyes.dots[0] as Node3D).global_position))
			print("[t_eyetrails] game-camera streak is %.1f px long" % px)
			root.get_texture().get_image().save_png("%s/flame_game.png" % dir)
			# And a side close-up of the head, bright enough to judge the flame's shape.
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 2.6
			# Side on: the animal runs along +X, so the streak only reads from Z.
			cam.global_position = (eyes.dots[0] as Node3D).global_position + Vector3(-0.35, 0.1, 1.5)
			cam.look_at((eyes.dots[0] as Node3D).global_position, Vector3.UP)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/flame_head.png" % dir)
		if i % 20 == 19:
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.save_png("%s/flame_%02d.png" % [dir, i])
	print("[t_eyetrails] shots %s" % dir)
	quit(0)

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
	var cap := int(TRAIL.get_script_constant_map().get("MAX_SAMPLES", 12))
	# Both eyes, at most cap + 1 points each, one quad (6 vertices) per pair of neighbours.
	var budget := (cap + 1) * 2 * 6
	_expect(worst_vertices <= budget, "per-creature ribbon stays small (%d vertices, budget %d)" % [worst_vertices, budget])
	_expect(trails.size() == eyed, "%d eyed animals, %d trails" % [eyed, trails.size()])
	_expect(trails.size() >= 17, "%d of 20 animals carry a trail" % trails.size())
	# Frame cost, measured (not assumed): 20 animals already at full ribbon strength, 240 ticks.
	var t0 := Time.get_ticks_usec()
	var frames := 240
	for _f in frames:
		for k in trails.size():
			trails[k].tick(DT)
	var per_frame_ms := float(Time.get_ticks_usec() - t0) / 1000.0 / float(frames)
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
		animal.global_position = Vector3(0, 0, 4.0)
		for _i in 40:
			animal.global_position = animal.global_position + Vector3(FAST_MPS * DT, 0, 0)
			far_trail.tick(DT)
		_expect(far_trail.surface_count() == 1, "the same animal draws again once it is near the camera")
	cam.queue_free()
	for c in spawned:
		c.queue_free()
	WL.night = had_night
	await process_frame
