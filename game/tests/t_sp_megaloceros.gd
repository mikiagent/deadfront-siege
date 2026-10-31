extends SceneTree
## SP-MEGALOCEROS: both sexes draw their own rigged Tripo body (stag with Blender-built antlers on Head, doe without)
## with every clip, the feet stay on the floor in the standing clips, the signature moves put the hooves/antlers
## where the hit lands (rear-up stomp: forehooves down ahead of the chest; rear kick: hind hooves up and far behind;
## stag hook and charge: head low and forward), the brain fires them on a survivor and they damage her, the doe's
## charge is a straight tackle (MEGAJOUST; it was a homing run into a forehoof strike), and tundra_30 spawns both sexes.
## Run: Godot --headless --path game --script res://tests/t_sp_megaloceros.gd -> "[t_sp_megaloceros] PASS", 0/1.

const ID := &"megaloceros"
const FEET := ["BackFoot.L", "BackFoot.R", "FrontFoot.L", "FrontFoot.R"]
const GROUND_TOL := 0.06

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
	print("[t_sp_megaloceros] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	for v in [&"stag", &"doe"]:
		_test_view(v)
	await _test_moves(&"stag", [&"heavy", &"kick", &"charge", &"bite"])
	await _test_moves(&"doe", [&"heavy", &"kick", &"charge", &"bite"])
	await _test_spawns()
	if failures.is_empty():
		print("[t_sp_megaloceros] PASS")
		quit(0)
	else:
		print("[t_sp_megaloceros] FAIL %d" % failures.size())
		quit(1)

func _boxes(n: Node) -> int:
	var c := 0
	var mi := n as MeshInstance3D
	if mi and (mi.mesh is BoxMesh or mi.mesh is CylinderMesh):
		c += 1
	for ch in n.get_children():
		c += _boxes(ch)
	return c

## A bone's position in the view's frame: x right, y up, -z forward (the creature faces -Z).
func _local(sk: Skeleton3D, view: Node3D, b: String, rest: bool = false) -> Vector3:
	var i := sk.find_bone(b)
	var t := sk.get_bone_global_rest(i) if rest else sk.get_bone_global_pose(i)
	return view.global_transform.affine_inverse() * (sk.global_transform * t).origin

func _test_view(v: StringName) -> void:
	var def = data.creature(ID)
	var view = CV.new()
	root.add_child(view)
	view.setup(def, v)
	view.apply_coloration(load("res://scripts/creatures/creature_coloration.gd").neutral())
	_expect(view.using_glb and view.rig != null, "%s draws its rigged GLB" % v)
	_expect(_boxes(view) == 0, "%s: no box/cylinder placeholder meshes" % v)
	if view.rig == null:
		view.free()
		return
	var clips: Array = def.pipeline.get("clips", [])
	for clip in clips:
		_expect(view.rig.has_clip(StringName(clip)), "%s clip %s loaded" % [v, clip])  # MEGAJOUST: the doe's charge is her tackle
	var sk: Skeleton3D = view.rig.skeleton
	_expect(sk.find_bone("Jaw") >= 0 and sk.find_bone("HindCannon.L") >= 0, "%s: deer skeleton with Jaw and cannon bones" % v)
	var antlers: Array = view.rig.mesh_root.find_children("Antlers*", "MeshInstance3D", true, false)
	_expect((antlers.size() > 0) == (v == &"stag"), "%s: antlers %s" % [v, "on" if v == &"stag" else "off"])
	sk.reset_bone_poses()
	var withers := _local(sk, view, "FrontScapula.L", true).y
	_expect((v == &"stag" and withers > 3.0 and withers < 3.6) or (v == &"doe" and withers > 2.4 and withers < 3.0),
		"%s withers %.2f m (survivor 1.78 m)" % [v, withers])
	var ap: AnimationPlayer = view.rig.anim_player
	var rest := INF
	for b in FEET:
		rest = minf(rest, _local(sk, view, b, true).y)
	for clip in [&"idle", &"walk", &"strafe_left", &"walk_back", &"alert", &"feed", &"hit_react", &"attack_primary", &"kick"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		for k in 13:
			ap.seek(a.length * float(k) / 12.0, true)
			var lo := INF
			for b in FEET:
				lo = minf(lo, _local(sk, view, b).y)
			worst = maxf(worst, absf(lo - rest))
		_expect(worst <= GROUND_TOL, "%s %s: a hoof stays planted (worst %.3f m off rest)" % [v, clip, worst])
	# where the hits land, at anim_events.json hit_frac
	var body_y := _local(sk, view, "Body", true)
	var front0 := _local(sk, view, "FrontFoot.L", true)
	var hind0 := _local(sk, view, "BackFoot.L", true)
	_seek(ap, sk, &"attack_heavy", 0.72)
	var fl := _local(sk, view, "FrontFoot.L"); var fr := _local(sk, view, "FrontFoot.R")
	_expect(maxf(fl.y, fr.y) < 0.6 and minf(fl.z, fr.z) < front0.z - 0.6,
		"%s rear-up stomp: forehooves down (%.2f m) and %.2f m ahead of their stance at the hit" % [v, maxf(fl.y, fr.y), front0.z - minf(fl.z, fr.z)])
	_seek(ap, sk, &"attack_heavy", 0.42)
	_expect(_local(sk, view, "FrontFoot.L").y > 1.2, "%s rear-up: forehooves high in the tell (%.2f m)" % [v, _local(sk, view, "FrontFoot.L").y])
	_seek(ap, sk, &"kick", 0.45)
	var hl := _local(sk, view, "BackFoot.L")
	_expect(hl.z > hind0.z + 1.2 and hl.y > 0.9, "%s rear kick: hind hoof %.2f m behind its stance, %.2f m up at the hit" % [v, hl.z - hind0.z, hl.y])
	var head0 := _local(sk, view, "Head", true)
	if v == &"stag":
		_seek(ap, sk, &"charge", 0.5)
		_expect(_local(sk, view, "Head").y < head0.y - 0.8, "stag charge: head down %.2f m (antlers forward)" % (head0.y - _local(sk, view, "Head").y))
		_seek(ap, sk, &"attack_primary", 0.3)
		_expect(_local(sk, view, "Head").y < head0.y - 0.8, "stag hook: head dropped before the hit (%.2f m)" % (head0.y - _local(sk, view, "Head").y))
	else:
		_seek(ap, sk, &"attack_primary", 0.3)
		_expect(_local(sk, view, "FrontFoot.R").y > 0.6, "doe strike: forehoof raised before the hit (%.2f m)" % _local(sk, view, "FrontFoot.R").y)
	view.free()

func _seek(ap: AnimationPlayer, sk: Skeleton3D, clip: StringName, frac: float) -> void:
	sk.reset_bone_poses()
	ap.play(clip)
	ap.seek(ap.get_animation(clip).length * frac, true)

## The brain's own move starters on a provoked animal facing a survivor: each fires and lands.
func _test_moves(v: StringName, moves: Array) -> void:
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
	for move in moves:
		var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
		player.position = Vector3(0, 0.9, 0)
		host.add_child(player)
		await physics_frame
		player.process_mode = Node.PROCESS_MODE_DISABLED
		var c = load("res://scenes/creatures/creature.tscn").instantiate()
		host.add_child(c)
		var behind: bool = move == &"kick"
		var dist := 9.0 if move == &"charge" else 3.0
		c.global_position = Vector3(0, 0.1, -dist)
		c.spawn(data.creature(ID), v, 0, null, 0, &"brave")  # brave stands its ground (skittish would bolt mid-test)
		_expect(c.variant == v and c.brain.has_method("pick_sequence"), "%s spawns as a %s with the tactical brain" % [v, v])
		c.look_at(Vector3(0, 0.1, -2.0 * dist) if behind else Vector3(0, 0.1, 0), Vector3.UP)
		c.brain.attack_target = player
		c.brain._provoked_until = c.brain._now_s() + 30.0
		var hp0: float = player.vitals.health
		var hits := [0]
		c.brain.tactic_hit.connect(func(_clip: StringName, _i: int, _m: float) -> void: hits[0] += 1)
		match move:
			&"heavy": c.brain._heavy()
			&"kick": c.brain._kick()
			&"charge": c.brain._start_charge()
			&"bite": c.brain._bite()
		for _f in 200:
			await physics_frame
			if hits[0] > 0 and player.vitals.health < hp0:
				break
		_expect(hits[0] > 0 and player.vitals.health < hp0, "%s %s lands on the survivor (hits %d, hp %.0f -> %.0f, clip %s, dist %.2f)" % [v, move, hits[0], hp0, player.vitals.health, c.anim.current_clip, Vector2(c.global_position.x, c.global_position.z).length()])
		if v == &"doe":
			_expect(c.brain.tac.get("charge_straight", false), "doe: her charge is a straight tackle (MEGAJOUST)")
		c.free()
		player.free()
	host.free()

## tundra_30's tables name the megaloceros: it spawns with its model, and sex is picked per animal.
func _test_spawns() -> void:
	var W: Node = root.get_node("World")
	W.creation_pending = true
	var host := Node3D.new()
	root.add_child(host)
	(load("res://scripts/dev/lab_kit.gd") as GDScript).build(host)
	W.load_island(host, &"tundra_30", Vector3(0, 1, 12), false)
	await process_frame
	var seen := {}
	for c in get_nodes_in_group("creatures"):
		if not c.is_queued_for_deletion() and c.def and c.def.id == ID:
			seen[c.variant] = int(seen.get(c.variant, 0)) + 1
			_expect(c.view.using_glb and c.view._body == null, "tundra_30 megaloceros (%s) draws its GLB" % c.variant)
	_expect(not seen.is_empty(), "tundra_30 spawns megaloceros %s" % seen)
	# 50/50 by spawn spot: over many spots both sexes come up
	var def = data.creature(ID)
	var n := {&"stag": 0, &"doe": 0}
	for i in 40:
		n[CV.pick_variant(def, "megaloceros@(%d, 0, %d)" % [i * 7, i * 3])] += 1
	_expect(n[&"stag"] > 8 and n[&"doe"] > 8, "sex picked per animal: %s" % n)
	host.free()
