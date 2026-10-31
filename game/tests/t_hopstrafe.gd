extends SceneTree
## HOPSTRAFE (owner 2026-10-31): "velociraptor seems too small or something. it should also use arms in attacks. the
## strafe is too small of a step because it's so small it looks like twinkletoes or like an agility drill. new general
## rule: smaller animals hop around more than they strafe, big and heavy dinosaurs strafe more than they hop".
## Checks:
##  - styles from the body (TacticalBrain.reposition_style): compsognathus, velociraptor, coelophysis hop; triceratops
##    and stegosaurus strafe;
##  - live fights against a stationary survivor: the small species start more bounds than strafes (TacticalBrain
##    .reposition signal, ratio); a triceratops strafes and never bounds; a stegosaurus never leaves the ground;
##  - every side bound of a small species covers at least 0.9 of its body length (measured on the body);
##  - feet planted on landing: once a side bound has landed (the body still, the clip finishing), the toes do not slide;
##  - velociraptor: its arms (FrontUpLeg / FrontFoot) swing through the attacks; it stands 1.3 m or taller.
## Usage: godot --headless --path game --script res://tests/t_hopstrafe.gd  -> "[t_hopstrafe] PASS"

const HOPPERS: Array[StringName] = [&"velociraptor", &"compsognathus", &"coelophysis"]
const MIN_HOP_SHARE := 0.6  # of the repositions a small species starts, at least this share are bounds
const MIN_BODY_LENGTHS := 0.9
## The toe joint (BackFoot.*_end) rolls a little about the planted toe tip as the heel lifts in the landing squash, so it
## may move this share of the body's height; a sliding landing moves it far more (the old transferred clips: 30 cm).
const LAND_SLIDE_FRAC := 0.05
const BOUNDS: Array[StringName] = [&"dodge_left", &"dodge_right", &"hop_back", &"leap_back", &"pounce"]

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D
var player: Node
var TB: Script

func _process(_delta: float) -> bool:
	if _started or get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	get_root().get_node("Game").debug_overlay = false
	get_root().get_node("Game").god_mode = true  # the stationary survivor never goes down between fights
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_hopstrafe] %s %s" % ["ok  " if ok else "FAIL", msg])

func _run() -> void:
	seed(20261031)
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261031
	Engine.max_physics_steps_per_frame = 1000
	TB = load("res://scripts/creatures/brains/tactical_brain.gd")
	host = Node3D.new()
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 160)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	_test_styles()
	_test_arms()
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED  # a stationary target
	for sp in HOPPERS:
		await _test_fight(sp, 30.0)
	await _test_fight(&"triceratops", 30.0)
	await _test_fight(&"stegosaurus", 20.0)
	if failures.is_empty():
		print("[t_hopstrafe] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_hopstrafe] FAIL " + f)
		quit(1)

func _test_styles() -> void:
	for sp in HOPPERS:
		_expect(TB.reposition_style(data.creature(sp)) == &"hop", "%s hops (bulk %.1f)" % [sp, _bulk(sp)])
	for sp in [&"triceratops", &"stegosaurus", &"tyrannosaurus"]:
		_expect(TB.reposition_style(data.creature(sp)) == &"strafe", "%s strafes (bulk %.1f)" % [sp, _bulk(sp)])
	for sp in [&"deinonychus", &"raptor"]:
		_expect(TB.reposition_style(data.creature(sp)) == &"mixed", "%s keeps its authored mix (bulk %.1f)" % [sp, _bulk(sp)])
	# SP-GALLIMIMUS: a light runner, set to hop by its own tactics (bulk 45.6 would make it a strafer)
	_expect(TB.reposition_style(data.creature(&"gallimimus")) == &"hop", "gallimimus hops by override (bulk %.1f)" % _bulk(&"gallimimus"))
	var v = data.creature(&"velociraptor")
	_expect(v.height_meters >= 1.3, "velociraptor stands %.2f m (>= 1.3, raised from 1.06)" % v.height_meters)

func _bulk(sp: StringName) -> float:
	var d = data.creature(sp)
	return d.real_length_m * d.height_meters

func _spawn(sp: StringName, at: Vector3, live: bool) -> Node:
	var c: Node = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(sp), &"", 0, null, 0, &"aggressive")
	if live:
		c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	else:
		c.set_physics_process(false)
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return c

func _bone_world(c, bone: String) -> Transform3D:
	var skel: Skeleton3D = c.view.rig.skeleton
	var i := skel.find_bone(bone)
	return skel.global_transform * skel.get_bone_global_pose(i) if i >= 0 else Transform3D()

## Velociraptor arms: the upper arm and the hand swing through each attack (angle from the clip's first frame).
func _test_arms() -> void:
	var c = _spawn(&"velociraptor", Vector3(50, 0, 50), false)
	var skel: Skeleton3D = c.view.rig.skeleton
	for clip in [&"attack_primary", &"attack_heavy", &"bite_combo", &"pounce"]:
		c.anim.play_clip(clip, true)
		var dt := 1.0 / 120.0
		c.anim.tree.advance(0.0)
		var len: float = c.anim.player.get_animation(clip).length / maxf(0.01, c.anim.cadence(clip))
		var q0: Dictionary = {}
		var worst: Dictionary = {}
		for k in int(len / dt):
			c.anim.tree.advance(dt)
			for b in ["FrontUpLeg.L", "FrontUpLeg.R", "FrontFoot.L"]:
				# the arm against the body, so a whole-body lunge does not count as arm use
				var q: Quaternion = skel.get_bone_global_pose(skel.find_bone(b)).basis.get_rotation_quaternion()
				var body: Quaternion = skel.get_bone_global_pose(skel.find_bone("Body")).basis.get_rotation_quaternion()
				var rel := body.inverse() * q
				if k == 2:
					q0[b] = rel
				elif k > 2:
					worst[b] = maxf(float(worst.get(b, 0.0)), rad_to_deg((q0[b] as Quaternion).angle_to(rel)))
		_expect(float(worst.get("FrontUpLeg.L", 0.0)) >= 40.0 and float(worst.get("FrontUpLeg.R", 0.0)) >= 40.0 and float(worst.get("FrontFoot.L", 0.0)) >= 40.0,
			"velociraptor %s uses its arms: upper arms swing %.0f / %.0f deg, hand %.0f deg against the body (>= 40)"
			% [clip, worst.get("FrontUpLeg.L", 0.0), worst.get("FrontUpLeg.R", 0.0), worst.get("FrontFoot.L", 0.0)])
	c.free()

func _toes(c) -> Array[Vector3]:
	return [_bone_world(c, "BackFoot.L_end").origin, _bone_world(c, "BackFoot.R_end").origin]

func _test_fight(sp: StringName, secs: float) -> void:
	var c = _spawn(sp, Vector3(0, 0.1, -8.0), true)
	await physics_frame
	if c.brain.get("rng") is RandomNumberGenerator:
		c.brain.rng.seed = 20261031
	var kinds: Dictionary = {&"hop": 0, &"strafe": 0}
	if c.brain.has_signal(&"reposition"):
		c.brain.reposition.connect(func(k: StringName) -> void: kinds[k] = int(kinds.get(k, 0)) + 1)
	c.brain.on_aggro(player)
	c.brain._provoked_until = 1e9  # a grazer fights only provoked
	var hz := float(Engine.physics_ticks_per_second)
	# on screen 0.8 x real_length_m (RAPTORSCALE), times this animal's genetic size
	var body_len: float = c.def.real_length_m * 0.8 * c.size_scale()
	var side_bounds := 0
	var short_bounds: Array[String] = []
	var land_slide := 0.0
	var land_frames := 0
	var airborne := 0
	var bound_from := Vector3.INF
	var land_toes: Array = []
	var prev: Vector3 = c.global_position
	var prev_clip: StringName = &""
	for k in int(secs * hz):
		await physics_frame
		player.vitals.health = player.vitals.effective_max_health()
		if not is_instance_valid(c) or c.health.dead:
			break
		var pos: Vector3 = c.global_position
		var mps := Vector2(pos.x - prev.x, pos.z - prev.z).length() * hz
		prev = pos
		var clip: StringName = c.anim.current_clip
		if c.view.position.y > 0.05 or clip in BOUNDS:
			airborne += 1
		var side := clip in [&"dodge_left", &"dodge_right", &"hop_back"]
		if side and prev_clip != clip:
			bound_from = pos
			land_toes = []
		if side and bound_from != Vector3.INF and mps < 0.01 and Vector2(pos.x - bound_from.x, pos.z - bound_from.z).length() > 0.5:
			# landed: the body is still while the clip finishes; the planted toes must stay on their prints
			var t := _toes(c)
			if land_toes.is_empty():
				land_toes = t
			for j in t.size():
				land_slide = maxf(land_slide, Vector2(t[j].x - land_toes[j].x, t[j].z - land_toes[j].z).length())
			land_frames += 1
		if prev_clip in [&"dodge_left", &"dodge_right", &"hop_back"] and clip != prev_clip and bound_from != Vector3.INF:
			var dist := Vector2(pos.x - bound_from.x, pos.z - bound_from.z).length()
			side_bounds += 1 if prev_clip != &"hop_back" else 0
			if prev_clip != &"hop_back" and dist < MIN_BODY_LENGTHS * body_len:
				short_bounds.append("%.2f" % dist)
			bound_from = Vector3.INF
		prev_clip = clip
	var hops := int(kinds[&"hop"])
	var strafes := int(kinds[&"strafe"])
	if sp in HOPPERS:
		var share := float(hops) / maxf(1.0, float(hops + strafes))
		_expect(hops + strafes >= 6 and share >= MIN_HOP_SHARE, "%s repositions in bounds: %d hops vs %d strafes (%.0f%% >= %.0f%%)" % [sp, hops, strafes, share * 100.0, MIN_HOP_SHARE * 100.0])
		_expect(side_bounds >= 2 and short_bounds.is_empty(), "%s side bounds cover a body length: %d bounds, all >= %.2f m (short: %s)" % [sp, side_bounds, MIN_BODY_LENGTHS * body_len, short_bounds])
		var lim: float = LAND_SLIDE_FRAC * c.def.height_meters * c.size_scale()
		_expect(land_frames >= 3 and land_slide <= lim, "%s lands planted: toes move %.1f cm over %d landed frames (<= %.1f cm)" % [sp, land_slide * 100.0, land_frames, lim * 100.0])
	elif sp == &"triceratops":
		# MEGAJOUST: the triceratops runs the JoustBrain (wheels and charges, no strafes); it still never bounds.
		_expect(hops == 0 and airborne == 0, "triceratops never bounds: %d strafes, %d hops, %d airborne frames" % [strafes, hops, airborne])
	else:
		_expect(hops == 0 and airborne == 0, "%s never leaves the ground: %d hops, %d airborne frames" % [sp, hops, airborne])
	c.queue_free()
	await physics_frame
