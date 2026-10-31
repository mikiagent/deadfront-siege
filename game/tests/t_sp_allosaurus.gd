extends SceneTree
## SP-ALLOSAURUS: the allosaurus draws its rigged Tripo model (no box placeholder) with every listed clip, it is 6.5 m
## tall and 14 m long, its feet stay on the floor in the standing clips, each hit's part is out in front at its hit frame,
## the TacticalBrain picks the shoulder ram for prey under its chin and the grab or hatchet in front, the hatchet bite
## lands and bleeds (the snap bite does not), the grab pins the survivor and both bites land before it lets go, the ram
## throws her back, a pair surrounds her from opposite sides, and the spawn rows (pairs) are on its islands.
## Run: Godot --headless --path game --script res://tests/t_sp_allosaurus.gd  -> "[t_sp_allosaurus] PASS", exit 0.

const ID := &"allosaurus"
const TOES := ["Toe.L", "Toe.R"]  ## Toe head = the heel/ball on the floor (rig_biped: the whole sole is Toe)
const GROUND_TOL := 0.12  ## m on a 6.5 m animal: the lowest Toe head stays this close to its rest height
## clip -> [hit frac, bone, min metres ahead of the centre]: anim_events hit fracs and pipeline.hit_parts
const HITS := {&"attack_primary": [0.42, "Jaw", 6.0], &"attack_heavy": [0.72, "Head", 5.0], &"grab_bite": [0.3, "Hand.R", 4.5], &"kick": [0.45, "Chest", 2.5],
	&"claw_rake": [0.5, "Hand.L", 3.5], &"slash_bite": [0.42, "Jaw", 5.0]}
## ALLOFEEL (owner 2026-10-31: "the arms should be moving as part of the attack animation and add more attacks"): every
## attack clip -> its hit frac. From the clip's first frame to its hit frame the leading claw tip (the Hand bone's tip, in
## the Chest bone's frame: the arm's own motion, not the body carrying it) travels more than ARM_TRAVEL_M, the other more
## than 0.4 of that, and the elbow and the wrist each bend through more than ARM_BEND_DEG.
const ARM_HITS := {&"attack_primary": 0.42, &"attack_heavy": 0.72, &"grab_bite": 0.3, &"kick": 0.45, &"claw_rake": 0.5,
	&"slash_bite": 0.42, &"check_left": 0.45, &"check_right": 0.45, &"bite_combo": 0.815}
const ARM_TRAVEL_M := 1.0
const ARM_BEND_DEG := 25.0
const HAND_M := 0.64  ## the Hand bone's length at size 1: hitboxes.json's ClawTip offset

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
	print("[t_sp_allosaurus] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_arms()
	_test_spawns()
	await _test_choice()
	await _test_hatchet()
	await _test_grab()
	await _test_ram()
	await _test_pair()
	await _test_new_moves()
	await _test_carno_kit()
	if failures.is_empty():
		print("[t_sp_allosaurus] PASS")
		quit(0)
	else:
		print("[t_sp_allosaurus] FAIL %d" % failures.size())
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
	_expect(def != null and ResourceLoader.exists("res://assets/creatures/allosaurus/allosaurus.glb"), "allosaurus data and GLB exist")
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
	_expect(clips.size() >= 16, "species lists its clips (%d)" % clips.size())
	for clip in clips:
		var authored := ResourceLoader.exists("res://assets/creatures/allosaurus/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Chest", "Hand.L", "Hand.R", "Tail6"] + TOES:
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
	_expect(absf(aabb.size.y - def.height_meters) < 0.3, "height %.2f m (data %.2f)" % [aabb.size.y, def.height_meters])
	_expect(long_side > 13.0 and long_side < 15.5, "14 m long (9 m real x 1.6): %.1f m" % long_side)
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in TOES:
		rest = minf(rest, _bone_pos(sk, b, true).y)
	for clip in [&"idle", &"walk", &"run", &"strafe_left", &"walk_back", &"attack_primary", &"attack_heavy", &"grab_bite", &"kick", &"hit_react", &"alert", &"feed"]:
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
		var worst: float = offs[int(offs.size() * 0.8) - 1] if clip == &"run" else offs[-1]  # the run has a flight phase
		_expect(worst <= GROUND_TOL, "%s: a foot stays on the floor (worst %.3f m off rest)" % [clip, worst])
	# Each hit's part, at its hit frame, is out in front of the body.
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
		_expect(ahead > float(HITS[clip][2]), "%s: %s %.2f m ahead of the body centre at the hit frame" % [clip, HITS[clip][1], ahead])
		if clip == &"attack_heavy":
			_expect(p.y < head_rest.y - 2.5, "hatchet: the skull is chopped down (head %.2f m, rest %.2f m)" % [p.y, head_rest.y])
	view.free()

## ALLOFEEL: the arms move in every attack (see ARM_HITS), and the ClawTip offset is the claw tip (along the hand).
func _test_arms() -> void:
	var view = CV.new()
	root.add_child(view)
	view.setup(data.creature(ID))
	var sk: Skeleton3D = view.rig.skeleton
	var ap: AnimationPlayer = view.rig.anim_player
	var s := sk.global_basis.get_scale().x
	sk.reset_bone_poses()
	var hand := sk.get_bone_global_rest(sk.find_bone("Hand.L"))
	var fore := sk.get_bone_global_rest(sk.find_bone("Forearm.L"))
	var tip := hand.origin + hand.basis.orthonormalized() * Vector3(0, HAND_M / s, 0)
	_expect(tip.distance_to(fore.origin) > hand.origin.distance_to(fore.origin) + 0.1 / s and tip.y < hand.origin.y,
		"ClawTip offset runs out along the hand, down from the wrist (tip %.2f m from the wrist)" % ((tip - hand.origin).length() * s))
	for clip in ARM_HITS:
		if not ap.has_animation(clip):
			_expect(false, "%s clip loaded" % clip)
			continue
		var a := ap.get_animation(clip)
		var n := 24
		var hit_k := int(round(float(ARM_HITS[clip]) * n))
		var tips := {"L": [], "R": []}
		var el := {"L": [], "R": []}
		var wr := {"L": [], "R": []}
		for k in hit_k + 1:
			sk.reset_bone_poses()
			ap.play(clip)
			ap.seek(a.length * float(k) / n, true)
			var chest := sk.get_bone_global_pose(sk.find_bone("Chest")).affine_inverse()
			for sd in ["L", "R"]:
				var up := sk.get_bone_global_pose(sk.find_bone("Arm." + sd))
				var fo := sk.get_bone_global_pose(sk.find_bone("Forearm." + sd))
				var ha := sk.get_bone_global_pose(sk.find_bone("Hand." + sd))
				tips[sd].append(chest * (ha.origin + ha.basis.orthonormalized() * Vector3(0, HAND_M / s, 0)) * s)
				el[sd].append(rad_to_deg(up.basis.y.angle_to(fo.basis.y)))
				wr[sd].append(rad_to_deg(fo.basis.y.angle_to(ha.basis.y)))
		var trav := []
		var bend := []
		for sd in ["L", "R"]:
			var t := 0.0
			for p in tips[sd]:
				t = maxf(t, (p as Vector3).distance_to(tips[sd][0]))
			trav.append(t)
			bend.append([(el[sd] as Array).max() - (el[sd] as Array).min(), (wr[sd] as Array).max() - (wr[sd] as Array).min()])
		var lead := 0 if trav[0] >= trav[1] else 1
		_expect(trav[lead] > ARM_TRAVEL_M and trav[1 - lead] > ARM_TRAVEL_M * 0.4,
			"%s: the claw tips travel %.2f / %.2f m against the chest from the start to the hit" % [clip, trav[0], trav[1]])
		_expect(bend[lead][0] > ARM_BEND_DEG and bend[lead][1] > ARM_BEND_DEG,
			"%s: the leading elbow bends %.0f deg and the wrist %.0f deg (claws spread and curl)" % [clip, bend[lead][0], bend[lead][1]])
		# where the claws are at the hit (for the hitbox ranges in tactics.moves)
		sk.reset_bone_poses()
		ap.play(clip)
		ap.seek(a.length * float(ARM_HITS[clip]), true)
		var line := ""
		for sd in ["L", "R"]:
			var ha := sk.get_bone_global_pose(sk.find_bone("Hand." + sd))
			line += " %s %s" % [sd, sk.global_transform * (ha.origin + ha.basis.orthonormalized() * Vector3(0, HAND_M / s, 0))]
		print("[t_sp_allosaurus] info %s claw tips at the hit:%s" % [clip, line])
	view.free()

## islands.json rows: pairs, on its own islands; the model means nothing falls through to another species.
func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var rows := []
	_find_rows(raw, rows)
	_expect(rows.size() >= 2, "allosaurus spawn rows in islands.json (%d)" % rows.size())
	for r in rows:
		_expect(int((r as Dictionary).get("count", 0)) == 2, "a row spawns a pair (count %s)" % (r as Dictionary).get("count"))
	var cdef: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(cdef.has_model(ID), "has_model(allosaurus): spawns no longer fall through")
	_expect(cdef.eligible(ID, [ID, &"gallimimus"]) == ID, "eligible(allosaurus) is allosaurus itself")

func _find_rows(n: Variant, out: Array) -> void:
	if n is Dictionary:
		if str((n as Dictionary).get("species", "")) == str(ID):
			out.append(n)
		for k in n:
			_find_rows(n[k], out)
	elif n is Array:
		for x in n:
			_find_rows(x, out)

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

func _allo(host: Node3D, at: Vector3, pack: int = 0) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID), &"", pack)
	c.set_meta(&"thero_roar_at", Time.get_ticks_msec() * 0.001)  # THERO-ROAR: no spot roar; the moves under test come at once
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

## Point-blank choice: prey pressed under its chin gets the shoulder ram (not the jaws); in front at jaw range the grab.
func _test_choice() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _allo(host, Vector3(0, 0.1, -3.0))
	var b = c.brain
	_expect(str(b.get_script().resource_path).ends_with("tactical_brain.gd"), "an allosaurus runs the TacticalBrain")
	b.attack_target = player
	_expect(b.attack_available(&"kick", 3.0) and not b.attack_available(&"grab", 3.0), "under its chin (3 m): shoulder ram, no grab")
	c.global_position = Vector3(0, 0.1, -6.2)
	_expect(b.attack_available(&"grab", 6.2) and not b.attack_available(&"kick", 6.2), "in front at jaw range (6.2 m): grab, no ram")
	_expect(b.attack_available(&"heavy", 6.2), "the hatchet bite is available in front at jaw range")
	_expect(not b.attack_available(&"pounce", 6.2), "no pounce: a 14 m animal does not leap")
	host.free()

func _bleeds(p) -> bool:
	return p.statuses.has(&"deep_bleed") or p.statuses.has(&"bleed")

## The hatchet bite lands from the skull at its chop and applies Bleed; the snap bite lands without it.
func _test_hatchet() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.get_node("Game").god_mode = true
	var c = _allo(host, Vector3(0, 0.1, -6.4))
	c.brain.attack_target = player
	c.brain._set_state(&"attack")
	var hits := []
	c.brain.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: hits.append(clip))
	c.anim.play_clip(&"attack_primary")
	for _f in 70:
		await physics_frame
	_expect(&"attack_primary" in hits, "the snap bite lands in front (%s)" % [hits])
	_expect(not _bleeds(player), "the snap bite applies no bleed")
	c.global_position = Vector3(0, 0.1, -6.4)
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	c.brain._set_state(&"attack")
	c.brain._heavy()
	for _f in 120:
		await physics_frame
	_expect(&"attack_heavy" in hits, "the hatchet bite lands (%s)" % [hits])
	_expect(_bleeds(player), "the hatchet bite applies Bleed")
	root.get_node("Game").god_mode = false
	host.free()

## The grab: the hands clamp (Pinned, held in front), both bites land, then it lets go.
func _test_grab() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	root.get_node("Game").god_mode = true
	var c = _allo(host, Vector3(0, 0.1, -6.2))
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var landed := []
	b.tactic_hit.connect(func(clip: StringName, i: int, _m: float) -> void: landed.append("%s%d" % [clip, i]))
	var pinned_seen := [false]
	var held := [99.0]
	b._grab_hands()  # SP-SPINOSAURUS merge: the spinosaurus owns _grab(delta), the grab state
	for _f in 240:
		await physics_frame
		if player.statuses.has(&"pinned"):
			pinned_seen[0] = true
			held[0] = minf(held[0], Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length())
		if seen.has(&"grabbed") and b.state != &"pin":
			break
	_expect(seen.has(&"grab") and seen.has(&"grabbed"), "the grab clamps her (%s)" % [seen.keys()])
	_expect(pinned_seen[0], "the survivor is Pinned by the hands")
	_expect(held[0] < 7.5, "she is held in front of the chest (%.2f m from its centre)" % held[0])
	_expect(landed == ["grab_bite0", "grab_bite1", "grab_bite2"], "the clamp and both bites land (%s)" % [landed])
	_expect(not player.statuses.has(&"pinned") and b.state != &"pin", "it lets go after the bites (state %s)" % b.state)
	root.get_node("Game").god_mode = false
	host.free()

## The shoulder ram lands from the chest and throws her back.
func _test_ram() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	root.get_node("Game").god_mode = true
	var c = _allo(host, Vector3(0, 0.1, -3.2))
	var b = c.brain
	b.attack_target = player
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var d0: float = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length()
	_expect(b._strike(d0, ["kick"]), "the ram is picked at %.1f m" % d0)
	for _f in 90:
		await physics_frame
	var d1: float = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length()
	_expect(seen.has(&"kick_shove"), "the shoulder ram lands and shoves (%s)" % [seen.keys()])
	_expect(d1 > d0 + 2.5, "she is thrown back (%.1f -> %.1f m)" % [d0, d1])
	root.get_node("Game").god_mode = false
	host.free()

## ALLOFEEL: the three new moves (tactics.moves). Each is picked only where it reaches (the rake under its chest, the
## slash at jaw range, the shoulder-check at its flank, by side), shows its ring where it lands, and lands: the slash
## bleeds, the rake does not, and the check throws her sideways off its flank.
func _test_new_moves() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _allo(host, Vector3(0, 0.1, -4.6))
	var b = c.brain
	b.attack_target = player
	_expect(b.attack_available(&"rake", 4.6) and not b.attack_available(&"slash", 4.6), "4.6 m in front: the arm rake (not the slash)")
	c.global_position = Vector3(0, 0.1, -6.2)
	_expect(b.attack_available(&"slash", 6.2) and not b.attack_available(&"rake", 6.2), "6.2 m in front: the hatchet slash (not the rake)")
	_expect(not b.attack_available(&"check", 6.2), "no shoulder-check at prey in front")
	c.global_position = Vector3(-2.5, 0.1, 0)
	c.look_at(Vector3(-2.5, 0.1, -10), Vector3.UP)  # she is at its right flank
	_expect(b.attack_available(&"check", 2.5) and b._move_clip(b._move_row(&"check")) == &"check_right", "at its right flank: the shoulder-check to its right")
	_expect(not b.attack_available(&"rake", 2.5) and not b.attack_available(&"grab", 2.5), "at its flank: no rake or grab")
	c.global_position = Vector3(2.5, 0.1, 0)
	_expect(b._move_clip(b._move_row(&"check")) == &"check_left", "at its left flank: the shoulder-check to its left")
	host.free()
	root.get_node("Game").god_mode = true
	# [move, creature spot, look-at, clip]
	for row in [[&"rake", Vector3(0, 0.1, -4.6), Vector3.ZERO, &"claw_rake"], [&"slash", Vector3(0, 0.1, -6.2), Vector3.ZERO, &"slash_bite"],
			[&"check", Vector3(-2.5, 0.1, 0), Vector3(-2.5, 0.1, -10), &"check_right"], [&"check", Vector3(2.5, 0.1, 0), Vector3(2.5, 0.1, -10), &"check_left"]]:
		a = await _arena()
		host = a[0]
		player = a[1]
		c = _allo(host, row[1])
		if row[2] != Vector3.ZERO:
			c.look_at(row[2], Vector3.UP)
		b = c.brain
		b.attack_target = player
		var hits := []
		b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: hits.append(clip))
		var seen := {}
		b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
		var p0: Vector3 = player.global_position
		var d0: float = Vector2(p0.x - c.global_position.x, p0.z - c.global_position.z).length()
		_expect(b._strike(d0, [str(row[0])]), "%s picked at %.1f m" % [row[0], d0])
		_expect(c.anim.current_clip == row[3], "%s plays %s (%s)" % [row[0], row[3], c.anim.current_clip])
		var ring := false
		var TG: GDScript = load("res://scripts/combat/telegraph.gd")  # not the class name: --script compiles before the autoloads
		for _f in 90:
			await physics_frame
			for t in TG.get("_active"):
				if is_instance_valid(t) and t.attacker == c and t.covers(player.global_position):
					ring = true
		_expect(ring, "%s: its ground ring covers her before the hit" % row[3])
		_expect(row[3] in hits, "%s lands (%s)" % [row[3], hits])
		if row[0] == &"slash":
			_expect(_bleeds(player), "the hatchet slash applies Bleed")
		elif row[0] == &"rake":
			_expect(not _bleeds(player), "the arm rake applies no bleed")
		else:
			var p1: Vector3 = player.global_position
			var side: float = (p1 - p0).dot(c.global_basis.x.normalized()) * (1.0 if row[3] == &"check_right" else -1.0)
			_expect(seen.has(&"move_shove") and side > 1.5, "%s throws her off its flank (%.1f m sideways)" % [row[3], side])
		host.free()
	root.get_node("Game").god_mode = false

const TIME_SCALE := 2.0  ## the carno kit's fight runs sped up (t_sp_carnotaurus' harness)

func _sim(player, secs: float) -> void:
	Engine.time_scale = TIME_SCALE
	var step := 1.0 / float(Engine.physics_ticks_per_second) * Engine.time_scale
	var n := maxi(1, int(round(secs / step)))
	var f0 := Engine.get_physics_frames()
	while Engine.get_physics_frames() - f0 < n:
		await physics_frame
		player.vitals.max_health = 1000000.0
		if player.vitals.health < 1000.0:
			player.vitals.health = player.vitals.effective_max_health()
		player.vitals.dead = false
		player.dead = false
	Engine.time_scale = 1.0

## A seeded allosaurus (genetics, body size and brain rolls fixed: t_sp_carnotaurus' harness), aggressive.
func _allo_seeded(host: Node3D, at: Vector3, player) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	var iv := RandomNumberGenerator.new()
	iv.seed = 20261031
	c.genetics = load("res://scripts/creatures/creature_genetics.gd").roll(iv)
	c.spawn(data.creature(ID), &"", 0, null, 0, &"aggressive")
	c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	c.brain.rng.seed = 20261031
	c.set_meta(&"thero_roar_at", Time.get_ticks_msec() * 0.001)  # THERO-ROAR: no spot roar; the moves under test come at once
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	c.brain.attack_target = player
	return c

## ALLOFEEL x CARNOFEEL (owner: "Carnotaurus attacks are welcome on this"): the carnotaurus kit through the allosaurus'
## own tactics and clips. The chomp combo is point blank, opens with its tell (a ring at its jaws, no chomp yet) and lands
## three chomps; the straight charge knocks her down on contact (also when the damage roll misses), runs on through her
## body, wheels round on its wide arc (yaw <= speed / charge_arc_r_m and <= turn_rate, travelling where it faces),
## charges back once, and after its charges land it closes in for the combo.
func _test_carno_kit() -> void:
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	Engine.max_physics_steps_per_frame = 1000
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var TG: GDScript = load("res://scripts/combat/telegraph.gd")
	var tac: Dictionary = data.creature(ID).tactics
	_expect(bool(tac.get("charge_straight", false)) and float(tac.get("charge_arc_r_m", 0.0)) > 0.0 and (tac.get("point_blank", []) as Array).has("combo")
		and (tac.get("charge_follow", []) as Array).has("combo"), "the carnotaurus kit is on in its tactics (straight charge, arc, combo, charge_follow)")
	# 1. the chomp combo (her own swings would stagger it mid-combo: she stands still)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	seed(20261031)
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261031
	var c = _allo_seeded(host, Vector3(0, 0.1, -6.6), player)
	var b = c.brain
	b.attack_target = player
	await _sim(player, 0.05)
	var log: Array = []
	b.tactic.connect(func(k: StringName) -> void: log.append(k))
	var chomps := [0]
	c.anim.attack_hit.connect(func(clip: StringName) -> void:
		if clip == &"bite_combo":
			chomps[0] += 1)
	var hurt := [0]
	player.vitals.damaged.connect(func() -> void: hurt[0] += 1)
	var d: float = b._flat_dist(player)
	_expect(b.attack_available(&"combo", d), "the chomp combo is available point blank (%.1f m)" % d)
	b._strike(d, ["combo"])
	await _sim(player, 0.1)
	_expect(c.anim.current_clip == &"bite_combo" and log.has(&"combo_tell") and TG.live_for(c) >= 1 and chomps[0] == 0, "the combo plays its own clip and opens with its tell (%s)" % [log])
	var t_first := -1.0
	for k in 60:  # the slowed tell (combo_tell_scale) and three chomps: up to 6 s
		await _sim(player, 0.1)
		if chomps[0] >= 1 and t_first < 0.0:
			t_first = 0.1 * (k + 2)
		if chomps[0] >= 3:
			break
	print("[t_sp_allosaurus] info the first chomp lands %.1f s after the combo starts" % t_first)
	_expect(chomps[0] == 3 and hurt[0] == 3, "chomp combo: 3 chomps land on her (hit frames %d, damage events %d)" % [chomps[0], hurt[0]])
	c.queue_free()
	await physics_frame
	# 2. the charge: twice, a landed hit and a damage roll that misses
	for acc in [1.0, 0.0]:
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.sim.knock.cancel()
		player.statuses.clear_all()
		player.anim.release_knockdown()
		player.hunt.stop()  # she auto-hunts what hit her: after the last animal she would walk off after its spot
		player._retaliate_target = null
		player.sim._path_points = PackedVector3Array()
		player.sim._shove = Vector3.ZERO
		player.sim._shove_s = 0.0
		player.global_position = Vector3(0, 0.9, 0)
		player.velocity = Vector3.ZERO
		load("res://scripts/combat/combat_tuning.gd").force_accuracy = acc
		c = _allo_seeded(host, Vector3(0, 0.1, -16.0), player)
		b = c.brain
		b.attack_target = player
		b._combat_memory_left = 60.0
		b.tac = b.tac.duplicate()
		b.tac["charge_through_m"] = 7.0  # keep the line on the test floor
		log = []
		b.tactic.connect(func(k: StringName) -> void: log.append(k))
		await _sim(player, 0.05)
		b._start_charge()
		var knocked := false
		var through := false
		var min_v := INF
		var past := -INF
		var arc := {"max_rate": 0.0, "max_slip": 0.0, "min_r": INF, "frames": 0}
		var prev_yaw: float = c.rotation.y
		var step := TIME_SCALE / float(Engine.physics_ticks_per_second)
		for i in 500:
			await _sim(player, step)
			if player.sim.knock.active() and player.sim.knock.tier in [1, 2]:
				knocked = true
			var first: bool = log.count(&"charge") == 1  # the first line and its arc only (not the brain's own later charges)
			if b.state == &"charge" and not b._charge_return and first:
				through = through or b.passes_through(player)
				if b._charge_hit:
					min_v = minf(min_v, Vector2(c.velocity.x, c.velocity.z).length())
				past = maxf(past, c.global_position.z)
			if b.state == &"charge_arc" and first:
				var v := Vector2(c.velocity.x, c.velocity.z)
				var rate := absf(angle_difference(prev_yaw, c.rotation.y)) / step
				if v.length() > 0.5:
					arc["frames"] += 1
					arc["max_rate"] = maxf(arc["max_rate"], rate)
					var slip := minf(absf(Vector2(-sin(c.rotation.y), -cos(c.rotation.y)).angle_to(v)), absf(Vector2(-sin(prev_yaw), -cos(prev_yaw)).angle_to(v)))
					arc["max_slip"] = maxf(arc["max_slip"], slip)
					if rate > 0.01:
						arc["min_r"] = minf(arc["min_r"], v.length() / rate)
			prev_yaw = c.rotation.y
			if log.has(&"charge_return"):
				break
		var what := "hit" if acc > 0.0 else "damage roll missed"
		_expect(log.has(&"charge_hit") and knocked, "charge contact (%s) knocks her down (%s)" % [what, log])
		if acc > 0.0:
			_expect(not _bleeds(player), "the charge's impact does not bleed (Bleed rides on the hatchet and the slash only)")
		_expect(through and min_v >= 0.6 * c.move_speed_mps() and past >= 7.0 - 1.5,
			"charge (%s) runs on through her: lowest speed after contact %.1f m/s, %.1f m past her" % [what, min_v, past])
		_expect(log.has(&"charge_arc") and int(arc["frames"]) > 10 and float(arc["max_rate"]) <= c.turn_rate() + 0.02
				and float(arc["min_r"]) >= b.arc_radius() - 0.1 and float(arc["max_slip"]) < deg_to_rad(2.0),
			"after the charge (%s) it arcs round wide: yaw %.2f rad/s (turn_rate %.2f), radius >= %.1f m (limit %.1f), slip %.1f deg" % [what, arc["max_rate"], c.turn_rate(), arc["min_r"], b.arc_radius(), rad_to_deg(arc["max_slip"])])
		_expect(log.has(&"charge_return"), "wheeled round, it charges back through her (%s)" % [log])
		if acc > 0.0:
			for i in 240:
				await _sim(player, 0.05)
				if log.has(&"combo"):
					break
			_expect(log.has(&"combo") and log.find(&"combo") > log.rfind(&"charge_arc"), "after its charges land it closes in for the chomp combo (%s)" % [log])
		c.queue_free()
		await physics_frame
		await physics_frame
		_expect(not player.get_collision_exceptions().any(func(x) -> bool: return is_instance_valid(x) and x.is_in_group(&"creatures")), "the pass-through exception is gone once the animal is")
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	host.free()

## A pair (one pack) holds ring slots on opposite sides of the prey (tactics.surround), and both go for her.
## (The slot math, not a walk round the ring: with no navmesh in a test a goal past ~12 m is not steered to.)
func _test_pair() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var one = _allo(host, Vector3(-3, 0.1, -14), 777)
	var two = _allo(host, Vector3(3, 0.1, -14), 777)
	for c in [one, two]:
		c.brain.attack_target = player
		c.brain._combat_memory_left = 60.0
	await physics_frame
	_expect(one.brain._pack_members().size() == 2 and bool(one.brain.tac.get("surround", false)), "the two are one surrounding pack")
	var u: Vector3 = one.brain._surround_slot() - player.global_position
	var v: Vector3 = two.brain._surround_slot() - player.global_position
	u.y = 0.0
	v.y = 0.0
	_expect(absf(rad_to_deg(u.angle_to(v)) - 180.0) < 5.0, "their ring slots are on opposite sides of her (%.0f deg apart, %.1f m out)" % [rad_to_deg(u.angle_to(v)), u.length()])
	host.free()
