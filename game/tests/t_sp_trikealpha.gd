extends SceneTree
## SP-TRIKEALPHA: the Alpha triceratops (the owner's "bulky triceratops with the bull horns") is its own model on the
## regular's rig layout: an alpha spawn draws alpha/triceratops_alpha.glb with all 16 clips, its own saddle and hit
## parts, stands at the species height, keeps its feet planted; its signature toss twists the head to its right at the
## hit; a charge that lands plays the toss and throws the survivor sideways (to the Alpha's right) and up; a regular
## spawn keeps the regular body; the lab's Body pick never offers the Alpha body (the Alpha toggle does).
## Run: Godot --headless --path game --script res://tests/t_sp_trikealpha.gd  -> "[t_sp_trikealpha] PASS", exit 0.

const ID := &"triceratops"
const FEET := ["Finger.L", "Finger.R", "Toe.L", "Toe.R"]
const GROUND_TOL := 0.08
const CLIPS := ["idle", "walk", "run", "attack_primary", "attack_heavy", "hit_react", "knockdown", "death", "alert",
	"walk_back", "strafe_left", "strafe_right", "charge", "feed", "sleep", "toss"]

var failures: Array[String] = []
var _started := false
var data: Node
var CV: GDScript  ## loaded at run time: the class needs the autoloads

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	root.get_node("Game").time_of_day = 0.4
	CV = load("res://scripts/creatures/creature_view.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_sp_trikealpha] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_data()
	_test_view()
	await _test_spawns()
	await _test_toss()
	if failures.is_empty():
		print("[t_sp_trikealpha] PASS")
		quit(0)
	else:
		print("[t_sp_trikealpha] FAIL %d" % failures.size())
		quit(1)

func _test_data() -> void:
	var def = data.creature(ID)
	var row: Dictionary = CV.variant_row(def, &"alpha")
	_expect(str(row.get("model", "")) == "alpha/triceratops_alpha.glb" and ResourceLoader.exists("res://assets/creatures/triceratops/alpha/triceratops_alpha.glb"),
		"model_variants.alpha has its own GLB")
	_expect(FileAccess.file_exists("res://assets/creatures/triceratops/alpha/mount/mount.json") and ResourceLoader.exists("res://assets/creatures/triceratops/alpha/mount/saddle.glb"),
		"the Alpha has its own saddle (alpha/mount)")
	_expect(float((row.get("tactics", {}) as Dictionary).get("toss_side_m", 0.0)) > 0.0, "the Alpha's tactics carry the sideways toss")
	var panel: GDScript = load("res://scripts/dev/lab_spawn_panel.gd")
	_expect(panel.variants_of(ID).is_empty(), "the lab Body pick does not offer the Alpha body (%s)" % [panel.variants_of(ID)])
	_expect(ID in panel.listed_species(false), "creature lab dropdown lists the triceratops")

func _test_view() -> void:
	var def = data.creature(ID)
	var view = CV.new()
	root.add_child(view)
	view.setup(def, &"alpha")
	view.apply_coloration(load("res://scripts/creatures/creature_coloration.gd").neutral())
	_expect(view.using_glb and view.rig != null, "the Alpha body loads")
	if view.rig == null:
		view.free()
		return
	for clip in CLIPS:
		_expect(ResourceLoader.exists("res://assets/creatures/triceratops/alpha/anim/%s.glb" % clip) and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Neck1", "Spine1", "Tail6"] + FEET:
		_expect(sk.find_bone(b) >= 0, "bone %s (the regular's layout)" % b)
	var aabb := AABB()
	var first := true
	for mi in view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var box: AABB = m.global_transform * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	_expect(absf(aabb.size.y - def.height_meters) < 0.2, "stands %.2f m (species %.2f)" % [aabb.size.y, def.height_meters])
	_expect(maxf(aabb.size.x, aabb.size.z) > 10.0, "%.1f m beak to tail (longer than the regular's 9 m)" % maxf(aabb.size.x, aabb.size.z))
	var ap: AnimationPlayer = view.rig.anim_player
	var vp: Vector3 = (view as Node3D).global_position
	sk.reset_bone_poses()
	var rest := INF
	for b in FEET:
		rest = minf(rest, (sk.global_transform * sk.get_bone_global_rest(sk.find_bone(b))).origin.y - vp.y)
	for clip in ["idle", "walk", "run", "charge", "strafe_left", "strafe_right", "walk_back", "alert", "attack_primary", "attack_heavy", "toss", "hit_react", "feed"]:
		sk.reset_bone_poses()
		ap.play(StringName(clip))
		var a := ap.get_animation(StringName(clip))
		var worst := 0.0
		for k in 13:
			ap.seek(a.length * float(k) / 12.0, true)
			var lo := INF
			for b in FEET:
				lo = minf(lo, (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b))).origin.y - vp.y)
			worst = maxf(worst, absf(lo - rest))
		_expect(worst <= GROUND_TOL, "%s: a foot stays planted (worst %.3f m off)" % [clip, worst])
	# The toss: between its start and just after the hit the head swings to the Alpha's right.
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var head := sk.find_bone("Head")
	var tip_at := func(t: float) -> Vector3:
		sk.reset_bone_poses()
		ap.play(&"toss")
		ap.seek(t, true)
		var g := sk.global_transform * sk.get_bone_global_pose(head)
		return g * Vector3(0, 1.6, 0)  # 1.6 m along the head bone: the brow-horn region
	var L := ap.get_animation(&"toss").length
	var hit_t := L * float((data.anim_events["clips"]["toss"] as Dictionary)["hit_frac"])
	var p0: Vector3 = tip_at.call(0.0)
	var p1: Vector3 = tip_at.call(minf(L, hit_t + 0.25))
	_expect((p1 - p0).dot(right) > 0.8, "toss: the horns swing %.2f m to its right after the hit" % (p1 - p0).dot(right))
	view.free()

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
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	return [host, player, c]

func _test_spawns() -> void:
	var a: Array = await _arena()
	var host: Node3D = a[0]
	var c = a[2]
	c.global_position = Vector3(0, 0.1, 20)
	c.alpha_spawn = true
	c.spawn(data.creature(ID))
	_expect(c.is_alpha() and c.variant == &"alpha", "an alpha spawn gets the Alpha body (%s)" % c.variant)
	_expect(c.view.rig != null and c.view.rig.has_clip(&"toss"), "the Alpha's rig has the toss")
	_expect(c.view._mount_dir().ends_with("alpha/mount"), "the Alpha's saddle comes from alpha/mount (%s)" % c.view._mount_dir())
	var c2 = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c2)
	c2.global_position = Vector3(30, 0.1, 0)
	c2.spawn(data.creature(ID))
	_expect(c2.variant == &"" and c2.view.rig != null and not c2.view.rig.has_clip(&"toss"), "a regular spawn keeps the regular body (%s)" % c2.variant)
	host.free()

## The charge lands: the toss plays and she is thrown sideways to the Alpha's right, and lifted.
func _test_toss() -> void:
	var a: Array = await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = a[2]
	c.global_position = Vector3(0, 0.1, 8.0)  # the arena has no navmesh: the direct-steer fallback reaches 12 m
	c.alpha_spawn = true
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	var b = c.brain
	b.attack_target = player
	b._provoked_until = b._now_s() + 60.0
	player.vitals.max_health = 1000000.0
	player.vitals.health = player.vitals.effective_max_health()
	await physics_frame
	var hp0: float = player.vitals.health  # after a frame: vitals clamp to their effective max
	var y0: float = player.global_position.y
	var tossed := [false]
	b.tactic.connect(func(t: StringName) -> void:
		if t == &"toss":
			tossed[0] = true)
	b._start_charge()
	var dir: Vector3 = b._charge_dir
	var right := Vector3(-dir.z, 0.0, dir.x)
	var p_hit := Vector3.INF
	var lift := 0.0
	var side := 0.0
	for _f in 600:
		await physics_frame
		if OS.has_environment("TA_DEBUG") and _f % 15 == 0:
			print("  f%d state=%s clip=%s d=%.2f stag=%.2f" % [_f, b.state, c.anim.current_clip, c.global_position.distance_to(player.global_position), c.stagger_left])
		if tossed[0] and p_hit == Vector3.INF:
			p_hit = player.global_position
		if p_hit != Vector3.INF:
			lift = maxf(lift, player.global_position.y - y0)
			side = maxf(side, (player.global_position - p_hit).dot(right))
			if _f > 0 and c.anim.current_clip != &"toss" and side > 0.5 and lift > 0.3:
				break
	_expect(tossed[0], "the charge lands and plays the toss")
	_expect(player.vitals.health < hp0, "the toss hurts (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	_expect(side > 2.0, "she is thrown %.2f m to the Alpha's right" % side)
	_expect(lift > 0.3, "and off her feet (%.2f m)" % lift)
	host.free()
