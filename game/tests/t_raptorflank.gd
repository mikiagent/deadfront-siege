extends SceneTree
## RAPTORFLANK (owner 2026-10-31 on the slate Raptor: "needs to be moving its arms as part of the attack ... the pounce
## and pin is awesome. I think the animations are weird on this one. There should be a move that's like run past, turn,
## strafe, attack from behind"; "all Raptors have the same problem (same model)").
## Checks:
##  - arms: in every Raptor attack clip (bite, combo, sickle slash, pounce, pin bites, flank rake) the arm bones turn
##    more than ARM_MIN_DEG from their first-frame pose, on two colour morphs (one mesh, so every morph);
##  - the flank: in a live fight (seeded, survivor in GOD mode, the full raptor tactics) the raptor runs past, skid-turns,
##    strafes on the strafe clips, gets more than 120 deg round from the survivor's facing before it leaps, and the rake
##    lands (tactic_hit flank_rake);
##  - the strafes are baked (natural_speeds) so the sidestep is stride-matched;
##  - utahraptor (owner: "it just needs to use its arms in the attacks too sometimes"): its arm-grab attacks move the arms.
## Run: Godot --headless --path game --script res://tests/t_raptorflank.gd  -> "[t_raptorflank] PASS", exit 0.

## The arm's own joints (upper arm, forearm, hand), not FrontLeg (the shoulder root also carries the chest glue).
## Measured on the rigs: the transferred deinonychus clips peak at 34 deg (pounce 0), the reworked ones 52-63.
const ARM_MIN_DEG := 45.0
const ARMS := ["FrontUpLeg.L", "FrontLowLeg.L", "FrontFoot.L", "FrontUpLeg.R", "FrontLowLeg.R", "FrontFoot.R"]
const RAPTOR_ATTACKS: Array[StringName] = [&"attack_primary", &"bite_combo", &"attack_heavy", &"pounce", &"pin_stab", &"flank_rake"]
const UTAH_ATTACKS: Array[StringName] = [&"arm_bite", &"bite_combo"]
const BEHIND_MIN := 120.0

var failures: Array[String] = []
var _started := false
var data: Node

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_raptorflank] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	for morph in [&"black_gold", &"slate"]:
		await _test_arms(&"raptor", RAPTOR_ATTACKS, morph)
	await _test_arms(&"utahraptor", UTAH_ATTACKS, &"")
	_test_speeds()
	await _test_utah_bites()
	await _test_flank_fight()
	if failures.is_empty():
		print("[t_raptorflank] PASS")
		quit(0)
	else:
		print("[t_raptorflank] FAIL %d" % failures.size())
		quit(1)

## Largest turn (deg) of any arm bone from its pose at the clip's first frame, sampled over the clip.
func _arm_swing(view: Node, clip: StringName) -> float:
	var ap: AnimationPlayer = view.rig.anim_player
	var sk: Skeleton3D = view.rig.skeleton
	var idx: Array[int] = []
	for b in ARMS:
		var i := sk.find_bone(b)
		if i >= 0:
			idx.append(i)
	if idx.is_empty() or not ap.has_animation(clip):
		return -1.0
	var length := ap.get_animation(clip).length
	var first: Array[Quaternion] = []
	var best := 0.0
	for k in 25:
		sk.reset_bone_poses()
		ap.play(clip)
		ap.seek(length * k / 24.0, true)
		ap.pause()
		for j in idx.size():
			var q := sk.get_bone_pose_rotation(idx[j])
			if k == 0:
				first.append(q)
			else:
				best = maxf(best, rad_to_deg(first[j].angle_to(q)))
	return best

func _test_arms(id: StringName, clips: Array[StringName], morph: StringName) -> void:
	var def = data.creature(id)
	var view = (load("res://scripts/creatures/creature_view.gd") as GDScript).new()
	root.add_child(view)
	view.setup(def, morph)
	await process_frame
	_expect(view.rig != null, "%s %s draws its rig" % [id, morph])
	if view.rig == null:
		view.free()
		return
	for clip in clips:
		var deg := _arm_swing(view, clip)
		_expect(deg > ARM_MIN_DEG, "%s%s %s: the arms move (%.0f deg > %.0f)" % [id, (" " + str(morph)) if morph != &"" else "", clip, deg, ARM_MIN_DEG])
	view.free()

func _test_speeds() -> void:
	var row: Dictionary = (data.anim_events.get("natural_speeds", {}) as Dictionary).get("raptor", {})
	for c in ["walk", "run", "charge", "strafe_left", "strafe_right", "walk_back"]:
		_expect(float(row.get(c, 0.0)) > 0.0 and row.has(c + "_len"), "raptor %s has a baked natural speed (%s)" % [c, row.get(c)])

## UTAHARMS: about half the utahraptor's bites are the grab-and-bite.
func _test_utah_bites() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = Vector3(0, 0.1, -4.0)
	c.spawn(data.creature(&"utahraptor"))
	var b = c.brain
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.attack_target = player
	b.rng.seed = 3
	var grabs := 0
	for _i in 40:
		c.anim.release_oneshot()
		b._bite()
		grabs += int(c.anim.current_clip == &"arm_bite")
	_expect(grabs >= 12 and grabs <= 28, "about half the utahraptor's bites grab with the arms (%d of 40)" % grabs)
	host.free()

func _arena() -> Array:
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	var host := Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 160)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	return [host, player]

## A live fight with the raptor's full tactics (seeded): the flank happens, it is behind her before the rake, the rake lands.
func _test_flank_fight() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	# She stands her ground without fighting back: a survivor who keeps turning to face it (auto-facing her hunt target)
	# denies her live back by design; the brain then rakes where her back was (TacticalBrain flank).
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = Vector3(0, 0.1, -10.0)
	c.spawn(data.creature(&"raptor"), &"slate")
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	var b = c.brain
	_expect(b.tac.get("flank", false) and (b.tac.get("sequences", []) as Array).any(func(r: Dictionary) -> bool: return r.get("steps") == ["flank"]), "the raptor's tactics carry the flank sequence")
	b.rng.seed = 7
	b.attack_target = player
	b._combat_memory_left = 30.0
	b._enter_circle(0.0)
	root.get_node("Game").god_mode = true
	var order: Array = []
	var behind_at_rake := [-1.0, -1.0]  # the brain's own reading, and this test's from her model's facing
	var strafe_clip := [false]
	var hits := {}
	var phase_strafe := [false]
	b.tactic.connect(func(k: StringName) -> void:
		if str(k).begins_with("flank"):
			order.append(k)
		if k == &"flank_rake" and behind_at_rake[0] < 0.0:
			behind_at_rake[0] = b.flank_behind_deg
			var f: Vector3 = -player.visual.global_basis.z
			var to: Vector3 = c.global_position - player.global_position
			f.y = 0.0
			to.y = 0.0
			behind_at_rake[1] = rad_to_deg(f.angle_to(to)))
	b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: hits[clip] = int(hits.get(clip, 0)) + 1)
	for _f in 60 * 90:
		await physics_frame
		if b.state == &"flank" and b._flank_phase == &"strafe":
			phase_strafe[0] = true
			strafe_clip[0] = strafe_clip[0] or c.anim.current_clip in [&"strafe_left", &"strafe_right"]
		if hits.has(&"flank_rake"):
			break
	print("[t_raptorflank] flank events %s, behind %.0f / %.0f deg, hits %s" % [order, behind_at_rake[0], behind_at_rake[1], hits])
	_expect(order.has(&"flank"), "the raptor flanks in the fight")
	var i_turn := order.find(&"flank_turn")
	var i_strafe := order.find(&"flank_strafe")
	var i_rake := order.find(&"flank_rake")
	_expect(i_turn >= 0 and i_strafe > i_turn and i_rake > i_strafe, "run past, skid-turn, strafe, then the rake (%s)" % [order])
	_expect(phase_strafe[0] and strafe_clip[0], "the strafe phase plays the strafe clips")
	_expect(behind_at_rake[1] > BEHIND_MIN and behind_at_rake[0] > BEHIND_MIN, "it is behind her before it attacks (%.0f deg off her facing, brain %.0f)" % [behind_at_rake[1], behind_at_rake[0]])
	_expect(hits.has(&"flank_rake"), "the rake from behind lands (%s)" % [hits])
	root.get_node("Game").god_mode = false
	host.free()
