extends SceneTree
## SP-MEGATHERIUM: the giant ground sloth draws its rigged Tripo model with every clip, stands 3.39 m, keeps its hind
## feet on the floor (the tripod rears on them), its signature moves reach with the fore-claws at their hit frames
## (hook, overhead swipe, bear hug, crush), the hits are judged at the claws (the swipe misses a survivor behind its
## rump), the hook drags her in, the swipe bleeds, the display -> bear hug pins and crushes her, the lumbering advance
## shrugs off hits and topples onto her, and the temperate spawn tables and the lab list it.
## Run: Godot --headless --path game --script res://tests/t_sp_megatherium.gd  -> "[t_sp_megatherium] PASS", exit 0.

const ID := &"megatherium"
const FEET := ["BackFoot.L", "BackFoot.R", "FrontFoot.L", "FrontFoot.R"]
const GROUND_TOL := 0.08  ## m: the lowest foot bone stays this close to its rest height in standing clips

var failures: Array[String] = []
var _started := false
var data: Node
var CV: GDScript

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	root.get_node("Game").time_of_day = 0.4  # daytime: a grazer asleep at night would not fight
	CV = load("res://scripts/creatures/creature_view.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_sp_megatherium] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_data()
	_test_view()
	await _test_hits()
	await _test_hug()
	await _test_advance()
	await _test_peaceful()
	if failures.is_empty():
		print("[t_sp_megatherium] PASS")
		quit(0)
	else:
		print("[t_sp_megatherium] FAIL %d" % failures.size())
		quit(1)

func _boxes(n: Node) -> int:
	var c := 0
	var mi := n as MeshInstance3D
	if mi and (mi.mesh is BoxMesh or mi.mesh is CylinderMesh):
		c += 1
	for ch in n.get_children():
		c += _boxes(ch)
	return c

func _test_data() -> void:
	var def = data.creature(ID)
	_expect(def != null and def.tameable and def.climate == &"temperate", "species loads: tameable, temperate")
	_expect(def != null and &"bleed" in def.status_applied, "the swipe's bleed rides on its hits")
	var TB: GDScript = load("res://scripts/creatures/brains/tactical_brain.gd")
	var tac: Dictionary = TB.tactics_for_def(def)
	var steps: Array = []
	for q in tac.get("sequences", []):
		steps.append(",".join((q as Dictionary).get("steps", [])))
	_expect("display,pounce" in steps and "display,charge" in steps and tac.get("pin", false) and tac.get("charge_armor", false) \
		and str(tac.get("pounce_windup_clip", "")) == "grab", "tactics: display -> bear hug (grab windup, pin) and display -> armoured advance (%s)" % [steps])
	var isl: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	for id in ["temperate_35", "temperate_45"]:
		var found := false
		for where in (isl[id]["spawns"] as Dictionary).values():
			for row in where:
				found = found or str((row as Dictionary).get("species", "")) == str(ID)
		_expect(found and str(isl[id]["climate"]) == "temperate", "%s spawn table has megatherium" % id)
	_expect(ResourceLoader.exists("res://assets/creatures/megatherium/megatherium.glb"), "model exists (spawns, not a fallthrough)")
	var panel: GDScript = load("res://scripts/dev/lab_spawn_panel.gd")
	_expect(ID in panel.listed_species(false), "creature lab dropdown lists it")

func _test_view() -> void:
	var def = data.creature(ID)
	var view = CV.new()
	root.add_child(view)
	view.setup(def)
	view.apply_coloration(load("res://scripts/creatures/creature_coloration.gd").neutral())
	_expect(view.using_glb and view.rig != null and _boxes(view) == 0, "draws the rigged GLB, no boxes")
	if view.rig == null:
		view.free()
		return
	for clip in def.pipeline.get("clips", []):
		var authored := ResourceLoader.exists("res://assets/creatures/megatherium/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "ClawTip.L", "ClawTip.R", "Tail1", "Tail2", "Tail3"] + FEET:
		_expect(sk.find_bone(b) >= 0, "bone %s" % b)
	var aabb := AABB()
	var first := true
	for mi in view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var box: AABB = m.global_transform * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	_expect(absf(aabb.size.y - 3.39) < 0.15, "stands %.2f m (1.75 m withers x1.6, head top)" % aabb.size.y)
	_expect(maxf(aabb.size.x, aabb.size.z) > 7.0, "%.1f m nose to tail" % maxf(aabb.size.x, aabb.size.z))
	var ap: AnimationPlayer = view.rig.anim_player
	var vp: Vector3 = (view as Node3D).global_position
	sk.reset_bone_poses()
	var rest := INF
	for b in FEET:
		rest = minf(rest, (sk.global_transform * sk.get_bone_global_rest(sk.find_bone(b))).origin.y - vp.y)
	for clip in [&"idle", &"walk", &"run", &"charge", &"strafe_left", &"walk_back", &"alert", &"attack_primary", &"attack_heavy", &"grab", &"pounce", &"pin_stab", &"toss", &"hit_react", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		for k in 13:
			ap.seek(a.length * float(k) / 12.0, true)
			var lo := INF
			for b in FEET:
				lo = minf(lo, (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b))).origin.y - vp.y)
			worst = maxf(worst, absf(lo - rest))
		# the plantigrade gaits roll the heel high and the upright advance's root is lifted so the heel skin clears the
		# floor (tools/gait/check_megatherium.py gates the skin itself): looser bone tolerances there
		var tol: float = {&"walk": 0.12, &"run": 0.14, &"strafe_left": 0.12, &"walk_back": 0.12, &"charge": 0.26}.get(clip, GROUND_TOL)
		_expect(worst <= tol, "%s: a foot stays planted (worst %.3f m off the floor, tol %.2f)" % [clip, worst, tol])
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var at := func(clip: StringName, bone: String, frac: float, dt: float) -> Array:
		sk.reset_bone_poses()
		ap.play(clip)
		var t: float = ap.get_animation(clip).length * frac
		ap.seek(maxf(0.0, t - dt), true)
		var b := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone))).origin
		ap.seek(t, true)
		return [(sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone))).origin, b]
	var hf := func(clip: StringName) -> float: return float((data.anim_events["clips"][str(clip)] as Dictionary)["hit_frac"])
	# The tripod: the alert display rears the head past 5 m.
	var peak := 0.0
	for k in 13:
		peak = maxf(peak, (at.call(&"alert", "Head", float(k) / 12.0, 0.0)[0] as Vector3).y - vp.y)
	_expect(peak > 5.0, "tripod display: the head rears to %.1f m" % peak)
	var sw: Array = at.call(&"attack_heavy", "ClawTip.L", hf.call(&"attack_heavy"), 0.1)
	var down: float = ((sw[1] as Vector3).y - (sw[0] as Vector3).y) / 0.1
	_expect(down > 4.0 and ((sw[0] as Vector3) - vp).dot(fwd) > 3.0, "overhead swipe: the claws come down at %.1f m/s, %.1f m ahead" % [down, ((sw[0] as Vector3) - vp).dot(fwd)])
	var hk: Array = at.call(&"attack_primary", "ClawTip.R", hf.call(&"attack_primary"), 0.0)
	_expect(((hk[0] as Vector3) - vp).dot(fwd) > 3.4, "hook: the right claw reaches %.1f m ahead" % ((hk[0] as Vector3) - vp).dot(fwd))
	var hl: Array = at.call(&"pounce", "ClawTip.L", hf.call(&"pounce"), 0.0)
	var hr: Array = at.call(&"pounce", "ClawTip.R", hf.call(&"pounce"), 0.0)
	_expect(absf(((hl[0] as Vector3) - vp).dot(right)) < 1.3 and absf(((hr[0] as Vector3) - vp).dot(right)) < 1.3, "bear hug: both arms close in front at the hit")
	view.free()

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
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	return [host, player, c]

## The moves land through their claws: in front the hook drags her in and the swipe bleeds her; behind the rump, inside
## the old centre reach, the swipe misses.
func _test_hits() -> void:
	for case in [[&"attack_primary", -3.8, true], [&"attack_heavy", -3.8, true], [&"attack_heavy", 3.0, false]]:
		var a: Array = await _arena()
		var host: Node3D = a[0]
		var player = a[1]
		var c = a[2]
		c.global_position = Vector3(0, 0.1, float(case[1]) * -1.0)
		c.spawn(data.creature(ID))
		c.look_at(Vector3(0, 0.1, 0) if case[2] else c.global_position * 2.0 - Vector3(0, 0.1, 0), Vector3.UP)
		c.brain.attack_target = player
		if "_provoked_until" in c.brain:
			c.brain._provoked_until = c.brain._now_s() + 30.0
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		var hits := [0]
		c.anim.attack_hit.connect(func(clip: StringName) -> void:
			if clip == case[0]:
				hits[0] += 1)
		player.vitals.max_health = 1000000.0
		player.vitals.health = player.vitals.effective_max_health()
		var hp0: float = player.vitals.health
		var d0: float = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length()
		c.anim.play_clip(case[0])
		for _f in 150:
			await physics_frame
		var hurt: bool = player.vitals.health < hp0
		_expect(hits[0] == 1 and hurt == case[2], "%s with the survivor %s: hit frame %d, %s (hp %.0f -> %.0f)" % [case[0],
			"in front" if case[2] else "behind the rump", hits[0], "lands" if hurt else "misses", hp0, player.vitals.health])
		var d1: float = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length()
		if case[0] == &"attack_primary":
			_expect(d1 < d0 - 0.5, "the hook drags her in (%.1f -> %.1f m)" % [d0, d1])
		if case[0] == &"attack_heavy" and case[2]:
			_expect(player.statuses.has(&"bleed"), "the overhead swipe bleeds her")
		host.free()

## Display -> bear hug: the grab windup plays under the ring, the hug lurches in and pins her, pin_stab squeezes twice.
func _test_hug() -> void:
	var a: Array = await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = a[2]
	c.global_position = Vector3(0, 0.1, 7.0)
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	var b = c.brain
	_expect((b.get_script() as Script).resource_path.ends_with("tactical_brain.gd"), "a TacticalBrain runs it")
	b.attack_target = player
	b._provoked_until = b._now_s() + 60.0
	root.get_node("Game").god_mode = true  # the hug and two squeezes outlast a fresh survivor's 100 HP: hold her up to count them
	var seen := {}
	var ev := {}
	b.tactic.connect(func(t: StringName) -> void: ev[t] = true)
	var squeezes := [0]
	b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void:
		if clip == &"pin_stab":
			squeezes[0] += 1)
	var pinned := false
	b._seq = [&"pounce"]
	b._start_display()
	_expect(c.anim.current_clip == &"alert", "display plays the tripod alert")
	for _f in 900:
		await physics_frame
		seen[c.anim.current_clip] = true
		pinned = pinned or player.statuses.has(&"pinned")
		if squeezes[0] >= 2 and not player.statuses.has(&"pinned"):
			break
	_expect(seen.has(&"grab") and seen.has(&"pounce"), "the grab windup and the hug play (%s)" % [seen.keys()])
	_expect(ev.has(&"pin") and pinned, "the hug pins her (%s)" % [ev.keys()])
	_expect(seen.has(&"pin_stab") and squeezes[0] == 2, "the crush squeezes twice (%d)" % squeezes[0])
	_expect(ev.has(&"pin") and not player.statuses.has(&"pinned"), "she is let go after the crush")
	root.get_node("Game").god_mode = false
	host.free()

## The lumbering advance: upright on its hind legs, hits do not stop it (super armour), on contact it topples onto her.
func _test_advance() -> void:
	var a: Array = await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = a[2]
	c.global_position = Vector3(0, 0.1, 10.0)
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	var b = c.brain
	b.attack_target = player
	b._provoked_until = b._now_s() + 60.0
	player.vitals.max_health = 1000000.0
	player.vitals.health = player.vitals.effective_max_health()
	var hp0: float = player.vitals.health
	var p0: Vector3 = player.global_position
	var ev := {}
	b.tactic.connect(func(t: StringName) -> void: ev[t] = true)
	b._start_charge()
	var seen := {}
	var armour := false
	for _f in 600:
		await physics_frame
		seen[c.anim.current_clip] = true
		if b.state == &"charge" and c.anim.current_clip == &"charge":
			armour = armour or b.super_armor()
		if ev.has(&"charge_hit") and seen.has(&"toss") and c.anim.current_clip != &"toss":
			break
	_expect(seen.has(&"charge") and armour, "the advance walks upright on the charge clip with super armour")
	_expect(ev.has(&"charge_hit") and seen.has(&"toss"), "it reaches her and topples onto her (%s)" % [ev.keys()])
	_expect(player.vitals.health < hp0 and player.global_position.distance_to(p0) > 1.5, "she is hurt and shoved %.1f m" % player.global_position.distance_to(p0))
	host.free()

## A mostly peaceful browser: a stand-ground nature that sees her close rears into the tripod display instead of
## attacking; it fights once she hits it.
func _test_peaceful() -> void:
	var a: Array = await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = a[2]
	c.global_position = Vector3(0, 0.1, 11.0)
	c.spawn(data.creature(ID), &"", 0, null, 0, &"brave")
	var b = c.brain
	var states := {}
	var hit_before := false
	for _f in 400:
		await physics_frame
		states[b.state] = true
		hit_before = hit_before or b.state in [&"pounce", &"charge", &"attack"]
	print("[t_sp_megatherium] info nature=%s states=%s" % [c.nature_id(), states.keys()])
	_expect(not hit_before, "unprovoked it does not attack her (%s)" % [states.keys()])
	host.free()
