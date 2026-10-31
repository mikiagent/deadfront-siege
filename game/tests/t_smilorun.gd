extends SceneTree
## SMILORUN (owner 2026-10-31: "the smilodon run should be more cat-like, more of a leaping run", then "jumping, leaping,
## bounding movement abilities that make it very hard to escape ... its agro ring could be lower"):
## - the run (and the sprint) is a bound: every paw off the ground for part of the stride, the back flexes, and a paw on
##   the ground moves back at one speed that matches natural_speeds (no slide, no moonwalk); the lope and sprint gaits
##   are on the gait ladder;
## - a survivor just outside the smaller detection ring is ignored, a survivor sprinting away from inside it is caught;
## - a survivor running across its path gets the cut-off leap, landing ahead of her on her line;
## - a bound lands on top of a raised step (no clipping into it), and a chase stuck at a step hops onto it.
## Run: Godot --headless --path game --script res://tests/t_smilorun.gd  -> "[t_smilorun] PASS", exit 0.

const ID := &"smilodon"
const TOES := ["BackFoot.L_end", "BackFoot.R_end", "FrontFoot.L_end", "FrontFoot.R_end"]
## The toe tips in glTF model space (smilodon_rig.py's *_end bone tails, Blender (x, y, z) -> (x, z, -y)): the planted
## point is the TIP; the bone's head (the ball) rolls about it as the heel peels, which is not a slide.
const TIP := {"BackFoot.L_end": Vector3(0.05, 0.016, 0.043), "BackFoot.R_end": Vector3(-0.05, 0.016, 0.043),
	"FrontFoot.L_end": Vector3(0.06, 0.011, 0.455), "FrontFoot.R_end": Vector3(-0.06, 0.011, 0.455)}
const N := 48  ## samples per gait cycle
const CATCH_S := 8.0  ## a full-sprint survivor is caught within this many seconds

var failures: Array[String] = []
var _started := false
var data: Node

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = OS.get_environment("SMILO_TRACE") != ""
	root.get_node("Game").time_of_day = 0.5  # midday: no night perception bonus
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_smilorun] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_gaits()
	await _test_ignored()
	await _test_catch()
	await _test_cutoff()
	await _test_bound_onto_step()
	await _test_step_hop()
	if failures.is_empty():
		print("[t_smilorun] PASS")
		quit(0)
	else:
		print("[t_smilorun] FAIL %d" % failures.size())
		quit(1)

func _tip(sk: Skeleton3D, b: String, rest: bool = false) -> Vector3:
	var i := sk.find_bone(b)
	var local: Vector3 = sk.get_bone_global_rest(i).affine_inverse() * (TIP[b] as Vector3)
	return sk.global_transform * ((sk.get_bone_global_rest(i) if rest else sk.get_bone_global_pose(i)) * local)

func _bone(sk: Skeleton3D, b: String, rest: bool = false) -> Transform3D:
	var i := sk.find_bone(b)
	return sk.global_transform * (sk.get_bone_global_rest(i) if rest else sk.get_bone_global_pose(i))

## Pitch (deg) of a bone's long axis in the side plane, nose-up positive (the view faces -Z).
func _pitch(t: Transform3D) -> float:
	var y := t.basis.y.normalized()
	return rad_to_deg(atan2(y.y, -y.z))

func _test_gaits() -> void:
	var def = data.creature(ID)
	var view = load("res://scripts/creatures/creature_view.gd").new()
	root.add_child(view)
	view.setup(def)
	var sk: Skeleton3D = view.rig.skeleton
	var ap: AnimationPlayer = view.rig.anim_player
	var row: Dictionary = (data.anim_events.get("natural_speeds", {}) as Dictionary).get(str(ID), {})
	sk.reset_bone_poses()
	var rest := INF
	var tip0 := {}
	for b in TOES:
		rest = minf(rest, _tip(sk, b, true).y)
		tip0[b] = _tip(sk, b, true).y
	var ball := sk.get_bone_global_rest(sk.find_bone("BackFoot.L_end")).origin
	_expect(ball.distance_to(Vector3(0.05, 0.012, -0.105)) < 0.01, "the rig is in glTF model space (BackFoot.L_end at %s)" % ball)
	for clip in [&"run", &"sprint", &"lope"]:
		_expect(ap.has_animation(clip), "%s authored and loaded" % clip)
		if not ap.has_animation(clip):
			continue
		var a := ap.get_animation(clip)
		var dt := a.length / N
		var air := 0
		var bends: Array[float] = []
		var toes: Array = []  # per sample: [height above rest per toe], [z per toe]
		for k in N + 1:
			sk.reset_bone_poses()
			ap.play(clip)
			ap.seek(dt * k, true)
			var h: Array[float] = []  # toe tip off its own rest height
			var z: Array[float] = []
			var up := INF  # lowest paw ball (the _end bone's head) over the floor
			for b in TOES:
				var p := _tip(sk, b)
				h.append(p.y - float(tip0[b]))
				z.append(p.z)
				up = minf(up, _bone(sk, b).origin.y - rest)
			toes.append([h, z])
			if up > 0.05:
				air += 1
			bends.append(_pitch(_bone(sk, "Shoulders")) - _pitch(_bone(sk, "Back")))
		var bend: float = bends.max() - bends.min()
		# Planted: a toe tip within 1 cm of its rest height for three samples running and level (a swinging paw only passes
		# through that band, rising or falling); it must travel back (+Z) at the gait's speed.
		var speeds: Array[float] = []
		for k in range(1, N):
			for i in TOES.size():
				var hk: Array = [toes[k - 1][0][i], toes[k][0][i], toes[k + 1][0][i]]
				if absf(hk[0]) < 0.01 and absf(hk[1]) < 0.01 and absf(hk[2]) < 0.01 and absf(hk[2] - hk[0]) < 0.008:
					speeds.append((toes[k + 1][1][i] - toes[k][1][i]) / dt)
		speeds.sort()
		var med: float = speeds[speeds.size() / 2] if not speeds.is_empty() else 0.0
		var slip := 0.0
		for v in speeds:
			slip = maxf(slip, absf(v - med))
		var nat: float = float(row.get(str(clip), 0.0)) * def.height_meters / float(row.get("height_m", def.height_meters))  # baked at height_m, scaled with the body (SMILOFEEL: 2.5 m)
		print("[t_smilorun] %s: %d/%d samples airborne, back flex %.1f deg, planted paws %.2f m/s (data %.2f), worst slip %.2f m/s" % [clip, air, N + 1, bend, med, nat, slip])
		if clip != &"lope":
			_expect(air >= 4, "%s has a flight phase: all four paws up in %d of %d samples" % [clip, air, N + 1])
		_expect(bend >= (12.0 if clip != &"lope" else 8.0), "%s flexes the back %.1f deg (gathered to stretched)" % [clip, bend])
		_expect(not speeds.is_empty() and med > 0.0, "%s planted paws travel backwards (no moonwalk, %.2f m/s)" % [clip, med])
		_expect(nat > 0.0 and absf(med - nat) < nat * 0.08, "%s stride matches natural_speeds: %.2f vs %.2f m/s" % [clip, med, nat])
		_expect(slip < 0.75, "%s planted paws do not slide (worst %.2f m/s off the ground speed)" % [clip, slip])
	var anim = load("res://scripts/creatures/creature_anim.gd")
	_expect(&"lope" in anim.GAITS and &"sprint" in anim.GAITS and &"leap" in anim.LEAPS, "lope and sprint are on the gait ladder, leap is a leap")
	view.free()

func _arena(step_h: float = 0.0, step_z: float = 0.0) -> Array:
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	var host := Node3D.new()
	root.add_child(host)
	_box(host, Vector3(200, 1, 200), Vector3(0, -0.5, 0))
	if step_h > 0.0:  # a raised shelf: everything at z > step_z is step_h higher
		_box(host, Vector3(200, step_h, 100), Vector3(0, step_h / 2.0, step_z + 50.0))
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED  # the test drives her (a scripted runner)
	await physics_frame
	return [host, player]

func _box(host: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	body.position = at
	host.add_child(body)

func _cat(host: Node3D, at: Vector3, face: Vector3) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID))
	c.look_at(Vector3(face.x, at.y, face.z), Vector3.UP)
	return c

## Move the scripted survivor one physics frame at `vel` (and report it as her velocity, as a real run would).
func _step(player: Node3D, vel: Vector3) -> void:
	player.velocity = vel
	player.global_position += vel / float(Engine.physics_ticks_per_second)

## The smaller ring: a survivor standing just outside its detection range is ignored; the ring is smaller than the
## default carnivore's (perception 8 + tier x 0.15, leash x 1.5).
func _test_ignored() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = _cat(host, Vector3(0, 0.1, -30), Vector3.ZERO)
	var b = c.brain
	b.profile = b.profile.duplicate()
	b.profile["roam_tiles"] = 0.0  # it stays put: the distance is the test
	var per: float = b._effective_perception()
	var old_per: float = (8.0 + float(c.def.tier) * 0.15) * c.nature_knob("aggro_radius_mult", 1.0)  # same nature, old ring
	_expect(per < old_per * 0.8, "detection %.1f m, well under the default %.1f m" % [per, old_per])
	_expect(b.aggro_radius() < old_per * 1.5 * 0.7, "aggro ring %.1f m, was %.1f m" % [b.aggro_radius(), old_per * 1.5])
	player.global_position = c.global_position + Vector3(0, 0.8, per + 1.5)
	for _f in 180:
		await physics_frame
	_expect(b.attack_target == null, "a survivor %.1f m off (outside the ring, inside the old one) is ignored (target %s)" % [per + 1.5, b.attack_target])
	host.free()

## From inside the ring a survivor at full sprint straight away is caught (hit or pinned) within CATCH_S.
func _test_catch() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = _cat(host, Vector3(0, 0.1, -48), Vector3(0, 0, 100))
	var b = c.brain
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = int(seen.get(k, 0)) + 1)
	player.global_position = c.global_position + Vector3(0, 0.8, 8.0)
	var hp0: float = player.vitals.health
	var sprint: float = player.sprint_speed
	var caught := -1.0
	var top := 0.0
	var t := 0.0
	while t < CATCH_S:
		_step(player, Vector3(0, 0, sprint))
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
		top = maxf(top, Vector2(c.get_real_velocity().x, c.get_real_velocity().z).length())
		if OS.get_environment("SMILO_TRACE") != "" and int(t * 60) % 15 == 0:
			print("TRACE t=%.2f state=%s target=%s d=%.1f v=%.1f clip=%s e=%.0f" % [t, b.state, b.attack_target != null, Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length(), Vector2(c.get_real_velocity().x, c.get_real_velocity().z).length(), c.anim.current_clip, c.energy])
		if player.vitals.health < hp0 or player.statuses.has(&"pinned"):
			caught = t
			break
	print("[t_smilorun] catch: survivor sprints %.1f m/s; caught at %.2f s; cat top speed %.1f m/s; tactics %s" % [sprint, caught, top, seen])
	_expect(caught > 0.0, "a survivor sprinting away at %.1f m/s from 8 m is caught within %.0f s (%.2f s)" % [sprint, CATCH_S, caught])
	_expect(seen.has(&"burst") or seen.has(&"bound"), "it ran her down with a burst or a bound (%s)" % seen)
	host.free()

## Running across its path she gets the cut-off leap: it lands ahead of her on her own line.
func _test_cutoff() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = _cat(host, Vector3(-7, 0.1, -40), Vector3(0, 0, -40))
	var b = c.brain
	player.global_position = Vector3(0, 0.9, -40)
	b.attack_target = player
	b._combat_memory_left = 30.0
	b._set_state(&"approach")
	var vel := Vector3(0, 0, 8.0)  # she runs along +Z, square across the line from the cat
	var landed := []
	b.tactic.connect(func(k: StringName) -> void:
		if k == &"cutoff":
			landed.append([b._j_to, player.global_position]))
	for _f in 60:
		_step(player, vel + Vector3(2.0, 0, 0))  # mostly across, a little away (prey leaving)
		await physics_frame
		if not landed.is_empty():
			break
	_expect(not landed.is_empty(), "a survivor running across its line gets the cut-off leap")
	if not landed.is_empty():
		var to: Vector3 = landed[0][0]
		var her: Vector3 = landed[0][1]
		_expect(to.z > her.z + 1.0, "the cut-off lands ahead of her on her escape line (landing z %.1f, she was at %.1f)" % [to.z, her.z])
	host.free()

## A bound onto a 1 m shelf lands on top of it: never inside the step, standing on the floor after.
func _test_bound_onto_step() -> void:
	var a := await _arena(1.0, -32.0)
	var host: Node3D = a[0]
	var player = a[1]
	var c = _cat(host, Vector3(0, 0.1, -40), Vector3(0, 0, 0))
	var b = c.brain
	player.global_position = Vector3(0, 1.9, -30)
	b.attack_target = player
	b._combat_memory_left = 30.0
	b._start_bound()
	var lowest_on_shelf := INF
	for _f in 90:
		_step(player, Vector3.ZERO)
		await physics_frame
		if c.global_position.z > -32.0 + 0.6:  # over the shelf: the body's feet must be at or above its top
			lowest_on_shelf = minf(lowest_on_shelf, c.global_position.y)
		if b.state != &"bound":
			break
	for _f in 20:
		await physics_frame
	_expect(c.global_position.z > -32.0, "the bound carried it onto the shelf (z %.2f)" % c.global_position.z)
	_expect(lowest_on_shelf >= 1.0 - 0.05, "over the shelf it never dips into it (lowest %.2f m, top 1.0)" % lowest_on_shelf)
	_expect(absf(c.global_position.y - 1.0) < 0.15 and c.is_on_floor(), "it lands standing on the shelf (y %.2f, on floor %s)" % [c.global_position.y, c.is_on_floor()])
	host.free()

## Chasing her up a 0.9 m step it cannot walk, it hops onto it.
func _test_step_hop() -> void:
	var a := await _arena(0.9, -38.0)
	var host: Node3D = a[0]
	var player = a[1]
	var c = _cat(host, Vector3(0, 0.1, -41), Vector3(0, 0, 0))
	var b = c.brain
	b.tac = b.tac.duplicate(true)
	(b.tac["bound"] as Dictionary)["min_m"] = 99.0  # no long bound: only the stuck hop can get it up
	player.global_position = Vector3(0, 1.8, -36)
	b.attack_target = player
	b._combat_memory_left = 30.0
	b._set_state(&"approach")
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	for _f in 240:
		_step(player, Vector3(0, 0, 3.0))
		await physics_frame
		if c.global_position.y > 0.8 and c.global_position.z > -38.0:
			break
	_expect(seen.has(&"step_hop"), "stuck at the step it hops (%s)" % seen)
	_expect(c.global_position.y > 0.8 and c.global_position.z > -38.0, "it is up on the step (y %.2f, z %.2f)" % [c.global_position.y, c.global_position.z])
	host.free()
