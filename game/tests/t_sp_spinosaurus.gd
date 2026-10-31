extends SceneTree
## SP-SPINOSAURUS: the spinosaurus draws its rigged Tripo model (sail included, no box placeholder) with every listed
## clip and a Jaw, it is 9 m tall and ~21.6 m long, its feet stay on their prints in the standing clips, each hit comes
## from its part at the hit frame (jaws, claws, tail), and in a live fight: the croc snap lands from the jaws; the claw
## rake lands from the claws on her close under its chest, makes her bleed and shoves her; the snap-and-shake clamps
## her in the jaws, carries her off the ground through the thrash and flings her clear; the tail swipe is picked and
## lands when she is behind it; the sail-flare display (alert) leads into a charge; from a water's edge it ambushes with
## the lunge and lands it, and away from water it does not lurk. The shared big-dinosaur stomp hook is in its tactics
## and harmless until that move exists. The spawn tables put it on the far shores of swamp_55 and tropical_40.
## Run: Godot --headless --path game --script res://tests/t_sp_spinosaurus.gd  -> "[t_sp_spinosaurus] PASS", exit 0.

const ID := &"spinosaurus"
const TOES := ["Toe.L", "Toe.R"]
const GROUND_TOL := 0.18  ## m (9 m animal): the lowest toe stays this close to its rest height in standing clips
## clip -> [hit frac, bone, min metres ahead of the body centre]
const HITS := {&"attack_primary": [0.42, "Jaw", 8.0], &"bite_shake": [0.30, "Jaw", 8.0], &"attack_heavy": [0.72, "Hand.L", 5.0], &"pounce": [0.7, "Jaw", 7.0]}

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
	CV = load("res://scripts/creatures/creature_view.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_sp_spinosaurus] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_snap()
	await _test_claw_rake()
	await _test_snap_and_shake()
	await _test_tail_swipe()
	await _test_sail_flare()
	await _test_water_lunge()
	_test_stomp_hook()
	if failures.is_empty():
		print("[t_sp_spinosaurus] PASS")
		quit(0)
	else:
		print("[t_sp_spinosaurus] FAIL %d" % failures.size())
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
	_expect(def != null and ResourceLoader.exists("res://assets/creatures/spinosaurus/spinosaurus.glb"), "spinosaurus data and GLB exist")
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
	_expect(clips.size() >= 18, "species lists its clips (%d)" % clips.size())
	for clip in clips:
		var authored := ResourceLoader.exists("res://assets/creatures/spinosaurus/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Tail6", "Metatarsal.L", "Toe.R", "Hand.L", "Hand.R"]:
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
	_expect(absf(aabb.size.y - def.height_meters) < 0.2, "height %.2f m (data %.2f)" % [aabb.size.y, def.height_meters])
	_expect(long_side > 20.0 and long_side < 23.5, "%.1f m nose to tail (a ~14 m animal at the house 1.6x)" % long_side)
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in TOES:
		rest = minf(rest, _bone_pos(sk, b, true).y)
	for clip in [&"idle", &"walk", &"stalk", &"strafe_left", &"walk_back", &"alert", &"attack_primary", &"attack_heavy", &"bite_shake", &"kick", &"hit_react", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		for k in 24:
			ap.seek(a.length * float(k) / 24.0, true)
			var lo := INF
			for b in TOES:
				lo = minf(lo, _bone_pos(sk, b).y)
			worst = maxf(worst, absf(lo - rest))
		_expect(worst <= GROUND_TOL, "%s: a foot stays on the floor (worst %.3f m off rest)" % [clip, worst])
	var origin: Vector3 = (view as Node3D).global_position
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	for clip in HITS:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		ap.seek(a.length * float(HITS[clip][0]), true)
		var ahead: float = (_bone_pos(sk, str(HITS[clip][1])) - origin).dot(fwd)
		_expect(ahead > float(HITS[clip][2]), "%s: %s %.2f m ahead of the body centre at the hit frame" % [clip, HITS[clip][1], ahead])
	# The tail swipe: at its hit frame the tail sweeps across behind it (fast sideways, still out behind).
	sk.reset_bone_poses()
	ap.play(&"kick")
	var kl := ap.get_animation(&"kick").length
	var side_x: Vector3 = (view as Node3D).global_transform.basis.x
	ap.seek(kl * 0.40, true)
	var s0: float = (_bone_pos(sk, "Tail5") - origin).dot(side_x)
	ap.seek(kl * 0.45, true)
	var p1 := _bone_pos(sk, "Tail5") - origin
	var sweep: float = absf(p1.dot(side_x) - s0) / (kl * 0.05)
	_expect(sweep > 6.0 and -p1.dot(fwd) > 4.0, "kick: the tail sweeps across behind it at the hit (%.1f m/s sideways, %.2f m behind)" % [sweep, -p1.dot(fwd)])
	view.free()

## The species' rows in islands.json: the far shores (coast) of the swamp and tropical islands, and the model means
## nothing falls through.
func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var islands := []
	_find_rows(raw, islands, "")
	_expect("swamp_55" in islands and "tropical_40" in islands, "spinosaurus spawn rows on swamp_55 and tropical_40 (%s)" % [islands])
	var raw_d := raw as Dictionary
	for isl in ["swamp_55", "tropical_40"]:
		var rows: Array = ((raw_d[isl] as Dictionary)["spawns"] as Dictionary)["far_shore"]
		_expect(rows.any(func(r: Dictionary) -> bool: return str(r.get("species", "")) == str(ID)), "%s: it spawns on the far shore (the coast)" % isl)
	var cdef: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(cdef.has_model(ID), "has_model(spinosaurus): spawns do not fall through")
	_expect(cdef.eligible(ID, [ID, &"deinonychus"]) == ID, "eligible(spinosaurus) is spinosaurus itself")
	_expect(str(data.creature(ID).climate) == "swamp", "climate swamp")
	var lab: GDScript = load("res://scripts/dev/lab_spawn_panel.gd")
	_expect(ID in lab.all_species(), "the creature lab's SPAWN list has it")

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

func _spino(host: Node3D, at: Vector3) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

func _setup_fight(dist: float, live_player: bool = false) -> Array:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	if not live_player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _spino(host, Vector3(0, 0.1, -dist))
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	await physics_frame
	c.anim.release_oneshot()  # THERO-ROAR: spotting her it rears and roars first; the move under test comes after it
	return [host, player, c, b]

## At the jaws' reach in front: the croc snap lands from the jaws.
func _test_snap() -> void:
	var f := await _setup_fight(9.0)
	var host: Node3D = f[0]
	var player = f[1]
	var c = f[2]
	var b = f[3]
	_expect(c.brain != null and str(c.brain.get_script().resource_path).ends_with("tactical_brain.gd"), "a spinosaurus runs the TacticalBrain (its own tactics block)")
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, m: float) -> void: landed[clip] = m)
	var parts := []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append([clip, c.part_hit(clip, player)]))
	b._beat_since_basic = true
	var hp0: float = player.vitals.health
	_expect(b._strike(b._flat_dist(player), ["bite"]), "the croc snap is available at 9 m in front")
	for _f in 80:
		await physics_frame
	_expect(parts.size() > 0 and parts[0][1], "the jaws reach her at the snap (%s)" % [parts])
	_expect(landed.has(&"attack_primary") and player.vitals.health < hp0, "the croc snap lands (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	host.free()

## Close under its chest (6.5 m): the point-blank order skips the tail and the jaws and rakes with the claws; it lands
## from the hands, she bleeds and is shoved back.
func _test_claw_rake() -> void:
	var f := await _setup_fight(6.5)
	var host: Node3D = f[0]
	var player = f[1]
	var c = f[2]
	var b = f[3]
	root.get_node("Game").god_mode = true  # one rake kills a fresh survivor; god mode keeps her up so the bleed and shove show
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, m: float) -> void: landed[clip] = m)
	var parts := []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append([clip, c.part_hit(clip, player)]))
	_expect(b._strike(b._flat_dist(player), b.tac["point_blank"]), "point blank in front picks a move")
	_expect(c.anim.current_clip == &"attack_heavy", "close under its chest it rakes with the claws (%s)" % c.anim.current_clip)
	player.process_mode = Node.PROCESS_MODE_INHERIT  # the shove moves her
	var p0: Vector3 = player.global_position
	for _f in 140:
		await physics_frame
	_expect(parts.size() > 0 and parts[0][0] == &"attack_heavy" and parts[0][1], "the claws reach her at the rake's hit (%s)" % [parts])
	_expect(landed.has(&"attack_heavy"), "the claw rake lands (x%.1f)" % float(landed.get(&"attack_heavy", 0.0)))
	_expect(player.statuses.has(&"bleed"), "the claw rake makes her bleed")
	_expect(seen.has(&"heavy_shove") and Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length() > 1.0, "the rake shoves her back (%.1f m)" % Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length())
	root.get_node("Game").god_mode = false
	host.free()

## The snap-and-shake at 9 m: the windup ring, the clamp from the jaws, she is carried off the ground in the jaws through
## the thrash (no control), then flung clear to its side.
func _test_snap_and_shake() -> void:
	var f := await _setup_fight(9.0, true)
	var host: Node3D = f[0]
	var player = f[1]
	var c = f[2]
	var b = f[3]
	root.get_node("Game").god_mode = true
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	_expect(b.attack_available(&"grab", b._flat_dist(player)), "the snap-and-shake is available at 9 m in front (reach %.1f, state %s)" % [b.reach_to(player), b.state])
	_expect(b._strike(b._flat_dist(player), ["grab"]), "it starts the snap-and-shake")
	_expect(c.anim.current_clip == &"bite_shake" and b.state == &"grab", "it plays bite_shake in the grab state (%s, %s)" % [c.anim.current_clip, b.state])
	_expect(is_instance_valid(b._telegraph), "the windup shows the ground ring on her")
	var caught_at := Vector3.INF
	var max_up := 0.0
	var max_jaw_gap := 0.0
	var flung_from := Vector3.INF
	for _f in 200:
		await physics_frame
		if b._held != null:
			if caught_at == Vector3.INF:
				caught_at = player.global_position
			max_up = maxf(max_up, player.global_position.y)
			max_jaw_gap = maxf(max_jaw_gap, Vector2(player.global_position.x - b.grab_point().x, player.global_position.z - b.grab_point().z).length())
		if seen.has(&"grab_fling") and flung_from == Vector3.INF:
			flung_from = player.global_position
		if b.state != &"grab" and seen.has(&"grab_fling"):
			break
	_expect(seen.has(&"grab_hit"), "the jaws clamp on her (gap %.2f m, %s)" % [b.grab_gap, seen.keys()])
	_expect(caught_at != Vector3.INF, "she is held in the jaws")
	_expect(max_up > 1.5, "the head lifts her off the ground through the thrash (%.2f m up)" % max_up)
	_expect(max_jaw_gap < 0.2, "she stays between the jaws while held (%.2f m)" % max_jaw_gap)
	_expect(seen.has(&"grab_fling") and b._held == null, "it flings her at the release")
	for _f in 90:
		await physics_frame
	var thrown := Vector2(player.global_position.x - flung_from.x, player.global_position.z - flung_from.z).length() if flung_from != Vector3.INF else 0.0
	_expect(thrown > 2.5, "the fling throws her clear (%.1f m)" % thrown)
	_expect(player.global_position.y < 1.5, "she lands back on the floor (y %.2f)" % player.global_position.y)
	root.get_node("Game").god_mode = false
	host.free()

## Behind it at point blank: the tail swipe is picked and the tail hits her.
func _test_tail_swipe() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _spino(host, Vector3(0, 0.1, 20.0))
	c.look_at(Vector3(0, 0.1, 40.0), Vector3.UP)  # facing away from her
	await physics_frame
	var back: Vector3 = c.global_transform.basis.z.normalized()
	var b = c.brain
	var spot: Vector3 = c.global_position + back * 8.0
	player.global_position = Vector3(spot.x, 0.9, spot.z)
	await physics_frame
	b.attack_target = player
	b._combat_memory_left = 30.0
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, m: float) -> void: landed[clip] = m)
	var parts := []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append([clip, c.part_hit(clip, player)]))
	var hp0: float = player.vitals.health
	_expect(b._strike(b._flat_dist(player), b.tac["point_blank"]), "point blank behind it picks a move")
	_expect(c.anim.current_clip == &"kick", "behind it, it swings the tail (%s)" % c.anim.current_clip)
	for _f in 90:
		await physics_frame
	_expect(landed.has(&"kick"), "the tail swipe lands (parts %s)" % [parts])
	_expect(player.vitals.health < hp0, "the tail hurts (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	host.free()

## The sail-flare sequence: the display step plays the alert clip (broadside sail, roar) for display_s, then it charges.
func _test_sail_flare() -> void:
	var f := await _setup_fight(16.0)
	var host: Node3D = f[0]
	var c = f[2]
	var b = f[3]
	var steps := []
	b.sequence_step.connect(func(s: StringName) -> void: steps.append(s))
	var rows: Array = b.tac["sequences"]
	b.tac = b.tac.duplicate(true)
	b.tac["sequences"] = rows.filter(func(r: Dictionary) -> bool: return str(r["name"]) == "sail_flare_charge")
	_expect(b._start_sequence(b._flat_dist(f[1])), "the sail-flare sequence starts")
	_expect(b.state == &"display" and c.anim.current_clip == &"alert", "it flares the sail (display, alert clip: %s, %s)" % [b.state, c.anim.current_clip])
	var charged := false
	for _f in 150:
		await physics_frame
		charged = charged or b.state == &"charge"
	_expect(charged, "the display leads into the charge (%s)" % [steps])
	host.free()

## Lurking on a bank: she walks within ambush range and it opens with the lunge out of the water's edge, which lands.
## Without water (the lab, no island) it does not ambush.
func _test_water_lunge() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _spino(host, Vector3(0, 0.1, -11.5))
	var b = c.brain
	_expect(not b._ambushes(), "no island water: it does not lurk (hunts in the open)")
	b._water_checked = true
	b.water_cover = c.global_position
	_expect(b._ambushes() and b._find_cover() == c.global_position, "with a water's edge it lurks there")
	b.tac = b.tac.duplicate()
	b.tac["pounce_overshoot_chance"] = 0.0
	b._set_state(&"roam")
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, m: float) -> void: landed[clip] = m)
	root.get_node("Game").god_mode = true
	for _f in 420:
		if b.state == &"roam":
			b._scan()
		await physics_frame
		if landed.has(&"pounce"):
			break
	_expect(seen.has(&"ambush"), "it springs the ambush on her (%s)" % [seen.keys()])
	_expect(seen.has(&"pounce") and seen.has(&"leap"), "it opens with the lunge: windup, then the surge")
	_expect(landed.has(&"pounce"), "the lunge lands from the jaws (x%.1f)" % float(landed.get(&"pounce", 0.0)))
	root.get_node("Game").god_mode = false
	host.free()

## The shared big-dinosaur stomp (claude/mmo-bigstomp) is opted into by data; until that move exists the slot is skipped.
func _test_stomp_hook() -> void:
	var tac: Dictionary = load("res://scripts/creatures/brains/tactical_brain.gd").tactics_for_def(data.creature(ID))
	_expect(bool(tac.get("big_stomp", false)) and "stomp" in (tac["point_blank"] as Array), "tactics opt in to the shared big stomp (big_stomp, 'stomp' in point_blank)")
	_expect(float(tac.get("w_hop", 1.0)) == 0.0 and float(tac.get("w_dodge", 1.0)) == 0.0, "big and heavy: no hop or power-strafe fillers")
