extends SceneTree
## SP-SMILODON: the smilodon draws its rigged Tripo model (no box placeholder) with every listed clip, it is about 2 m
## tall, its feet stay on the floor in the standing clips, the jaw and sabre (Head) bones exist, each hit comes from its
## part (the swiping paw, the sabres) at the hit frame, the brain stalks in, pounces, pins and stabs a survivor, the
## swipe misses a survivor the paw cannot reach (centre reach would have hit), an alpha wears the brown skin, and the
## spawn tables put it on tundra islands with nothing falling through.
## SMILOFEEL (owner 2026-10-31: "make smilodon bigger and give it more maul style attacks, pin attacks, large leap
## attacks"; "it shouldn't follow so closely, it should just jump towards the player and bound toward them. burst
## movement"): it is 2.5 m tall (+25 %); a fleeing survivor is chased in pulses (bounds with planted pauses, never a steady
## run at her heels inside PULSE_NEAR_M for over PULSE_TRAIL_S); the long leap covers LONG_LEAP_M or more, airborne with the
## forepaws thrown forward, lands on her and pins her (PinHold, slid at most pin_slide_mps a second) into the maul; a pin
## only follows a leap that landed; the maul's bite and both worries land with the hind paws planted.
## Run: Godot --headless --path game --script res://tests/t_sp_smilodon.gd  -> "[t_sp_smilodon] PASS", exit 0.

const ID := &"smilodon"
const FEET := ["BackFoot.L", "BackFoot.R", "FrontFoot.L", "FrontFoot.R"]
## The cat stands on its toes: the Foot bones run hock/wrist -> toe tips, so ground contact is the Foot_end (toe tip).
const TOES := ["BackFoot.L_end", "BackFoot.R_end", "FrontFoot.L_end", "FrontFoot.R_end"]
const GROUND_TOL := 0.06  ## m: the lowest toe tip stays this close to its rest height in standing clips
## clip -> [hit frac, bone]: anim_events hit fracs and pipeline.hit_parts
const HITS := {&"attack_primary": [0.42, "FrontFoot.R"], &"attack_heavy": [0.72, "Head"], &"pounce": [0.7, "Head"], &"pin_stab": [0.38, "Head"],
	&"long_leap": [0.74, "Head"], &"maul_bite": [0.24, "Head"]}
const HEIGHT_M := 2.5  ## SMILOFEEL: 2.0 x 1.25
const PULSE_NEAR_M := 5.0  ## a chase never runs steadily (over 3 m/s) this close to her ...
const PULSE_TRAIL_S := 1.0  ## ... for longer than this
const LONG_LEAP_M := 8.5  ## the long leap's flight covers at least this

var failures: Array[String] = []
var _started := false
var data: Node
var CV: GDScript

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = OS.get_environment("SMILO_TRACE") != ""
	CV = load("res://scripts/creatures/creature_view.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_sp_smilodon] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_swipe_part()
	await _test_pounce_pin()
	await _test_stalk()
	await _test_alpha()
	await _test_burst_chase()
	await _test_long_leap()
	await _test_pin_needs_landing()
	await _test_maul()
	if failures.is_empty():
		print("[t_sp_smilodon] PASS")
		quit(0)
	else:
		print("[t_sp_smilodon] FAIL %d" % failures.size())
		quit(1)

func _boxes(n: Node) -> int:
	var c := 0
	var mi := n as MeshInstance3D
	if mi and (mi.mesh is BoxMesh or mi.mesh is CylinderMesh):
		c += 1
	for ch in n.get_children():
		c += _boxes(ch)
	return c

func _bone_pos(sk: Skeleton3D, b: String, rest: bool = false) -> Vector3:
	var i := sk.find_bone(b)
	return sk.global_transform * (sk.get_bone_global_rest(i) if rest else sk.get_bone_global_pose(i)).origin

func _test_view() -> void:
	var def = data.creature(ID)
	_expect(def != null and ResourceLoader.exists("res://assets/creatures/smilodon/smilodon.glb"), "smilodon data and GLB exist")
	var view = CV.new()
	root.add_child(view)
	view.setup(def)
	view.apply_coloration(load("res://scripts/creatures/creature_coloration.gd").neutral())
	_expect(view.using_glb and view.rig != null, "draws the rigged GLB")
	_expect(_boxes(view) == 0, "no box/cylinder placeholder meshes")
	if view.rig == null:
		view.free()
		return
	var clips: Array = def.pipeline.get("clips", [])
	_expect(clips.size() >= 17, "species lists its clips (%d)" % clips.size())
	for clip in clips:
		var authored := ResourceLoader.exists("res://assets/creatures/smilodon/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Tail5"] + FEET:
		_expect(sk.find_bone(b) >= 0, "bone %s in the rig" % b)
	var aabb := AABB()
	var first := true
	for mi in view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var box: AABB = m.global_transform * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	var long_side := maxf(aabb.size.x, aabb.size.z)
	_expect(absf(aabb.size.y - def.height_meters) < 0.15, "height %.2f m (data %.2f)" % [aabb.size.y, def.height_meters])
	_expect(is_equal_approx(def.height_meters, HEIGHT_M) and absf(aabb.size.y - HEIGHT_M) < 0.15, "SMILOFEEL: 25 %% bigger, %.2f m tall (was 2.0)" % aabb.size.y)
	_expect(long_side > 1.5 * aabb.size.y and long_side < 2.5 * aabb.size.y, "a cat's proportions: %.1f m long, %.1f m tall" % [long_side, aabb.size.y])
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in TOES:
		rest = minf(rest, _bone_pos(sk, b, true).y)
	# SMILORUN: the run is a bound with a long flight; t_smilorun checks its flight, back flex and paw contact instead.
	for clip in [&"idle", &"walk", &"stalk", &"strafe_left", &"walk_back", &"attack_primary", &"attack_heavy", &"pin_stab", &"hit_react", &"alert", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var offs: Array[float] = []
		for k in 24:
			ap.seek(a.length * float(k) / 24.0, true)
			var lo := INF
			for b in TOES:
				lo = minf(lo, _bone_pos(sk, b).y)
			offs.append(absf(lo - rest))
		offs.sort()
		var worst: float = offs[-1]
		_expect(worst <= GROUND_TOL, "%s: a toe stays on the floor (worst %.3f m off rest)" % [clip, worst])
	# Each hit's part, at its hit frame, is out in front of the body (the paw raked forward, the sabres driven down).
	var origin: Vector3 = (view as Node3D).global_position
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	sk.reset_bone_poses()
	var head_rest := _bone_pos(sk, "Head", true)
	for clip in HITS:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		ap.seek(a.length * float(HITS[clip][0]), true)
		var p := _bone_pos(sk, str(HITS[clip][1]))
		var ahead: float = (p - origin).dot(fwd)
		_expect(ahead > 1.2, "%s: %s %.2f m ahead of the body centre at the hit frame" % [clip, HITS[clip][1], ahead])
		if HITS[clip][1] == "Head":
			_expect(p.y < head_rest.y - 0.2, "%s: the sabres are driven down (head %.2f m, rest %.2f m)" % [clip, p.y, head_rest.y])
	view.free()

## The species' rows in islands.json: tundra islands, and the model means nothing falls through to another species.
func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var islands := []
	_find_rows(raw, islands, "")
	_expect(islands.size() >= 3, "smilodon spawn rows in islands.json (%d)" % islands.size())
	var cdef: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(cdef.has_model(ID), "has_model(smilodon): spawns no longer fall through")
	_expect(cdef.eligible(ID, [ID, &"megaloceros"]) == ID, "eligible(smilodon) is smilodon itself")
	_expect(str(data.creature(ID).climate) == "tundra", "climate tundra")

func _find_rows(n: Variant, out: Array, island: String) -> void:
	if n is Dictionary:
		var d := n as Dictionary
		var here := str(d.get("id", island))
		if str(d.get("species", "")) == str(ID):
			out.append(island)
		for k in d:
			_find_rows(d[k], out, here)
	elif n is Array:
		for x in n:
			_find_rows(x, out, island)

func _arena() -> Array:
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	var host := Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	return [host, player]

func _cat(host: Node3D, at: Vector3, alpha: bool = false) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	c.alpha_spawn = alpha
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

## The swipe lands from the paw: in front of the paw it hits; beside the hindquarters (inside the old centre reach,
## out of the paw's) it misses.
func _test_swipe_part() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cat(host, Vector3(0, 0.1, -2.6))
	_expect(c.brain != null and str(c.brain.get_script().resource_path).ends_with("tactical_brain.gd"), "a smilodon runs the TacticalBrain (saber_cat tactics)")
	c.brain.attack_target = player
	c.brain._set_state(&"attack")  # mid-swing: the brain waits for the clip instead of alerting and charging
	var hp0: float = player.vitals.health
	var parts: Array = []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append(c.part_hit(clip, player)))
	c.anim.play_clip(&"attack_primary")
	for _f in 90:
		await physics_frame
	_expect(player.vitals.health < hp0, "the forepaw swipe lands in front (hp %.0f -> %.0f, paw %s)" % [hp0, player.vitals.health, parts])
	# Beside the rump: 2.3 m from the centre (centre reach would hit), 3 m from the swiping paw.
	var back: Vector3 = c.global_transform.basis.z.normalized()
	var right: Vector3 = c.global_transform.basis.x.normalized()
	player.global_position = c.global_position + back * 1.4 + right * 1.8 + Vector3(0, 0.8, 0)
	var flat: float = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length()
	_expect(flat < c.brain.reach_to(player), "the rump spot is inside the centre reach (%.2f < %.2f m)" % [flat, c.brain.reach_to(player)])
	var hp1: float = player.vitals.health
	for _f in 10:
		await physics_frame
	c.brain._set_state(&"attack")
	c.anim.play_clip(&"attack_primary")
	for _f in 90:
		await physics_frame
	_expect(is_equal_approx(player.vitals.health, hp1), "the swipe misses a survivor beside the rump: the paw does not reach (hp %.0f -> %.0f)" % [hp1, player.vitals.health])
	host.free()

## Pounce from 7 m: it leaps, lands, pins (Pinned: PINFEEL lays her down, held in front), stabs twice, then lets go.
func _test_pounce_pin() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = _cat(host, Vector3(0, 0.1, -7.0))
	var b = c.brain
	b.tac = b.tac.duplicate()
	b.tac["pounce_overshoot_chance"] = 0.0  # the 15 % sail-past miss is its own (random) branch
	b.attack_target = player
	b._combat_memory_left = 30.0
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var stabs := [0]
	var pinned_seen := [false]
	var held_d := [99.0]
	var down := [false]
	c.anim.attack_hit.connect(func(clip: StringName) -> void:
		if clip == &"pin_stab":
			stabs[0] += 1)
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: landed[clip] = int(landed.get(clip, 0)) + 1)
	root.get_node("Game").god_mode = true  # a 100 HP survivor dies to the pounce alone; the pin needs her alive
	b._start_pounce()
	_expect(b.state == &"pounce", "the pounce starts (state %s)" % b.state)
	for _f in 420:
		await physics_frame
		if player.statuses.has(&"pinned"):
			pinned_seen[0] = true
			down[0] = down[0] or player.anim.current_clip in [&"knockdown", &"pinned"]
			held_d[0] = minf(held_d[0], Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length())
		if seen.has(&"pin") and b.state != &"pin" and stabs[0] >= 2:
			break
	_expect(seen.has(&"leap"), "it leaps")
	_expect(seen.has(&"pin"), "a landed pounce pins the survivor")
	_expect(pinned_seen[0], "the survivor is Pinned")
	_expect(down[0], "she goes down into the pinned pose (PINFEEL)")
	_expect(held_d[0] < 3.0, "she is held under the forepaws (%.2f m from its centre)" % held_d[0])
	_expect(stabs[0] == 2, "pin_stab drives the sabres in twice (%d)" % stabs[0])
	_expect(int(landed.get(&"pounce", 0)) == 1 and int(landed.get(&"pin_stab", 0)) == 2, "the pounce and both stabs land from the Head bone (%s)" % landed)
	_expect(not player.statuses.has(&"pinned") and b.state != &"pin", "it lets go when the stabs are done (state %s)" % b.state)
	root.get_node("Game").god_mode = false
	host.free()

## Coming in from far off it creeps on the stalk clip, slower than its walk.
func _test_stalk() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cat(host, Vector3(0, 0.1, -12.0))  # SMILORUN: inside the smaller leash (13.4 m)
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	b._cd[&"long_leap"] = 99.0  # SMILOFEEL: from 9-16 m it would open with the long leap; this checks the creep
	b._set_state(&"approach")
	var stalked := [0]
	var speeds: Array[float] = []
	for _f in 120:
		await physics_frame
		if c.anim.current_clip == &"stalk":
			stalked[0] += 1
			speeds.append(Vector2(c.velocity.x, c.velocity.z).length())
	_expect(stalked[0] > 30, "it approaches on the stalk clip (%d frames)" % stalked[0])
	var mean := 0.0
	for s in speeds:
		mean += s / maxf(1.0, speeds.size())
	_expect(mean > 0.2 and mean < c.walk_mps(c.move_speed_mps()), "stalk speed %.2f m/s, under its walk %.2f m/s" % [mean, c.walk_mps(c.move_speed_mps())])
	host.free()

## An alpha wears the brown-maned skin; a regular animal keeps the GLB's.
func _test_alpha() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var reg = _cat(host, Vector3(10, 0.1, 0))
	var alp = _cat(host, Vector3(-10, 0.1, 0), true)
	_expect(alp.is_alpha() and alp.variant == &"alpha", "an alpha spawns with the alpha variant (%s)" % alp.variant)
	_expect(reg.variant != &"alpha", "a regular smilodon is not given the alpha skin (%s)" % reg.variant)
	var tex := _albedo(alp.view)
	_expect(tex != null and tex.resource_path.ends_with("smilodon_alpha_albedo.jpg"), "the alpha draws smilodon_alpha_albedo.jpg (%s)" % (tex.resource_path if tex else "none"))
	var rtex := _albedo(reg.view)
	_expect(rtex != null and not rtex.resource_path.ends_with("smilodon_alpha_albedo.jpg"), "the regular draws its own albedo")
	host.free()

func _albedo(v: Node) -> Texture2D:
	for mi in v.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var mat := m.get_active_material(0)
		if mat is ShaderMaterial:
			return (mat as ShaderMaterial).get_shader_parameter("albedo_tex") as Texture2D
		if mat is StandardMaterial3D:
			return (mat as StandardMaterial3D).albedo_texture
	return null

## A scripted survivor: one physics frame at vel, reported as her velocity (the real run would set it).
func _step(player: Node3D, vel: Vector3) -> void:
	player.velocity = vel
	player.global_position += vel / float(Engine.physics_ticks_per_second)

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## SMILOFEEL burst chase: she sprints straight away for 8 s (its strikes are held off, so the chase never ends). Its
## speed comes in pulses (bounds, then planted pauses) and it never runs steadily at her heels.
func _test_burst_chase() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cat(host, Vector3(0, 0.1, -50.0))
	c.look_at(Vector3(0, 0.1, 100), Vector3.UP)
	var b = c.brain
	b.tac = b.tac.duplicate(true)
	(b.tac["bound"] as Dictionary)["strike"] = false  # the landing would pin her: here the chase itself is the test
	for k in [&"pounce", &"long_leap", &"maul", &"bite", &"heavy"]:
		b._cd[k] = 999.0
	b.tac["pounce_cd"] = 999.0
	b.tac["long_leap_cd"] = 999.0
	player.global_position = c.global_position + Vector3(0, 0.8, 8.0)
	var sprint: float = player.sprint_speed
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = int(seen.get(k, 0)) + 1)
	var hz := float(Engine.physics_ticks_per_second)
	var speeds: Array[float] = []
	var trail := 0.0
	var worst_trail := 0.0
	var dmax := 0.0
	var prev: Vector3 = c.global_position
	for f in int(8.0 * hz):
		_step(player, Vector3(0, 0, sprint))
		await physics_frame
		var v := _flat(c.global_position, prev) * hz
		prev = c.global_position
		speeds.append(v)
		var d := _flat(c.global_position, player.global_position)
		dmax = maxf(dmax, d) if f > hz else dmax
		trail = trail + 1.0 / hz if d < PULSE_NEAR_M and v > 3.0 else 0.0
		worst_trail = maxf(worst_trail, trail)
	# Pulses: the flat speed rises over 12 m/s (a bound) from under 3 m/s (a pause) again and again.
	var pulses := 0
	var low := true
	var slow_frames := 0
	for v in speeds:
		if v < 3.0:
			low = true
			slow_frames += 1
		elif v > 12.0 and low:
			pulses += 1
			low = false
	print("[t_sp_smilodon] burst chase: %d pulses, %d of %d frames under 3 m/s, longest steady trail within %.0f m %.2f s, farthest %.1f m, tactics %s" % [pulses, slow_frames, speeds.size(), PULSE_NEAR_M, worst_trail, dmax, seen])
	_expect(pulses >= 4, "the chase comes in pulses: %d bursts of speed from a near stop in 8 s" % pulses)
	_expect(slow_frames > speeds.size() / 8, "it pauses between them (%d of %d frames under 3 m/s)" % [slow_frames, speeds.size()])
	_expect(worst_trail <= PULSE_TRAIL_S, "never a steady run at her heels: longest %.2f s moving within %.0f m (limit %.1f s)" % [worst_trail, PULSE_NEAR_M, PULSE_TRAIL_S])
	_expect(int(seen.get(&"bound", 0)) >= 4, "it bounds at her again and again (%d bounds)" % int(seen.get(&"bound", 0)))
	_expect(dmax < 20.0, "a %.1f m/s sprint never gets clear: farthest %.1f m" % [sprint, dmax])
	host.free()

## The long leap from 11.5 m (inside its ~12 m aggro ring): a crouch, then a flight of LONG_LEAP_M or more with the forepaws thrown out ahead, landing on
## her: the strike lands, she is Pinned (under the paws, slid there, never jumped) and the maul follows.
func _test_long_leap() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cat(host, Vector3(0, 0.1, -11.5))
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	root.get_node("Game").god_mode = true
	var hits := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: hits[clip] = int(hits.get(clip, 0)) + 1)
	var d0: float = _flat(c.global_position, player.global_position)
	_expect(b.attack_available(&"long_leap", d0), "the long leap is ready from %.1f m" % d0)
	_expect(b._strike(d0, ["long_leap"]) and b.state == &"pounce" and b._pounce_clip == &"long_leap", "it springs the long leap (state %s)" % b.state)
	var start: Vector3 = c.global_position
	var sk: Skeleton3D = c.view.rig.skeleton
	var air_top := 0.0
	var paws_ahead := 0.0
	var paws_up := 0.0
	var pinned := false
	var max_step := 0.0
	var prev: Vector3 = player.global_position
	var slide: float = 3.0  # ai.json big_stomp pin_slide_mps
	for _f in 300:
		await physics_frame
		var lift: float = c.view.position.y
		if lift > air_top:
			air_top = lift
			var fwd: Vector3 = -c.global_basis.z
			var pa := INF
			var pu := INF
			for bn in ["FrontFoot.L", "FrontFoot.R"]:
				var p := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bn)).origin
				pa = minf(pa, (p - c.global_position).dot(fwd))
				pu = minf(pu, p.y - start.y)
			paws_ahead = pa
			paws_up = pu
		if player.statuses.has(&"pinned"):
			pinned = true
			max_step = maxf(max_step, _flat(player.global_position, prev))
		prev = player.global_position
		if pinned and b.state != &"pin":
			break
	var flew: float = b.last_leap[0].distance_to(b.last_leap[1]) if b.last_leap.size() == 2 else 0.0
	print("[t_sp_smilodon] long leap: flight %.1f m, top %.2f m, forepaws %.2f m ahead / %.2f m up at the top, hits %s, maul hits %d, pinned slide %.3f m/frame" % [flew, air_top, paws_ahead, paws_up, hits, b.maul_landed, max_step])
	_expect(flew >= LONG_LEAP_M, "the leap covers %.1f m (>= %.0f)" % [flew, LONG_LEAP_M])
	_expect(air_top > 1.0, "clearly airborne: %.2f m off the ground at the top" % air_top)
	_expect(paws_ahead > 1.6 and paws_up > 0.8, "forepaws thrown out ahead in the air (%.2f m ahead, %.2f m up)" % [paws_ahead, paws_up])
	_expect(int(hits.get(&"long_leap", 0)) == 1, "it lands on her: the leap's strike lands (%s)" % hits)
	_expect(pinned, "a landed leap pins her")
	_expect(b.maul_landed >= 2, "the maul follows on the pinned survivor (%d hits landed)" % b.maul_landed)
	_expect(max_step <= slide / 60.0 + 0.01, "held under the paws by a slide, never a jump (%.3f m in one frame)" % max_step)
	root.get_node("Game").god_mode = false
	host.free()

## A pin needs the leap to land: she sidesteps 5 m as it takes off, so it lands on nothing and nothing pins her; and a pin
## asked for with her out of the paws' reach does not start (PinHold.can_start).
func _test_pin_needs_landing() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cat(host, Vector3(0, 0.1, -11.5))
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	root.get_node("Game").god_mode = true
	b._strike(_flat(c.global_position, player.global_position), ["long_leap"])
	var moved := false
	var ever := false
	for _f in 200:
		await physics_frame
		if not moved and b._pounce_phase == &"leap":
			player.global_position += Vector3(5.0, 0, 0)  # out of the landing
			moved = true
		ever = ever or player.statuses.has(&"pinned")
	_expect(moved and not ever, "a long leap that lands on nothing never pins her (pinned seen %s)" % ever)
	player.global_position = c.global_position + (-c.global_basis.z) * 6.0
	b.attack_target = player
	_expect(not b._start_pin(&"pin_stab") and not player.statuses.has(&"pinned"), "a pin with her 6 m off (not under the paws) does not start")
	root.get_node("Game").god_mode = false
	host.free()

## The maul point blank: the sabres bite (she is pinned under the paws), two worries land, she is let go; the hind paws
## never leave their prints.
func _test_maul() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cat(host, Vector3(0, 0.1, -2.0))
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	root.get_node("Game").god_mode = true
	await physics_frame
	var sk: Skeleton3D = c.view.rig.skeleton
	var hind := func() -> Array:
		var out := []
		for bn in ["BackFoot.L_end", "BackFoot.R_end"]:
			out.append(sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bn)).origin)
		return out
	var d: float = _flat(c.global_position, player.global_position)
	_expect(b.attack_available(&"maul", d), "the maul is ready point blank (%.1f m)" % d)
	b._strike(d, ["maul"])
	_expect(b.state == &"pin" and c.anim.current_clip == &"maul_bite", "it mauls (state %s, clip %s)" % [b.state, c.anim.current_clip])
	var p0: Array = hind.call()
	var drift := 0.0
	var pinned := false
	var hits := []
	b.tactic_hit.connect(func(clip: StringName, i: int, _m: float) -> void:
		if clip == &"maul_bite":
			hits.append(i))
	for _f in 240:
		await physics_frame
		pinned = pinned or player.statuses.has(&"pinned")
		if b.state != &"pin":
			break  # let go: its next move (a hop back) is not the maul
		var p1: Array = hind.call()
		for i in 2:
			drift = maxf(drift, _flat(p1[i], p0[i]))
	print("[t_sp_smilodon] maul: hits %s landed %d, pinned %s, hind paw drift %.3f m" % [hits, b.maul_landed, pinned, drift])
	_expect(b.maul_landed == 3 and hits == [0, 1, 2], "the bite and both worries land (%d landed, %s)" % [b.maul_landed, hits])
	_expect(pinned, "the bite pins her under the paws")
	_expect(not player.statuses.has(&"pinned") and b.state != &"pin", "it lets go when the jaws open (state %s)" % b.state)
	_expect(drift < 0.05, "the hind paws stay planted through the maul (drift %.3f m)" % drift)
	root.get_node("Game").god_mode = false
	host.free()
