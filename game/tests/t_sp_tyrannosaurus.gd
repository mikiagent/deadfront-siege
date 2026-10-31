extends SceneTree
## SP-TYRANNOSAURUS (owner: remodel the T. rex with a real jaw): the v2 open-mouth model draws with every clip, the
## Jaw opens the mouth in the roar and the bite, the lying clips put her down on her belly and knockdown gets her
## back up, the feet stay on the floor in the standing clips, the signature moves fire through TyrantBrain and land
## (bite and shake: damage + pinned; battle roar: small creatures and the survivor stagger, a big one does not),
## an Alpha wears the armoured skin, and the island table still spawns her (far shore).
## Run: Godot --headless --path game --script res://tests/t_sp_tyrannosaurus.gd  -> "[t_sp_tyrannosaurus] PASS"

const ID := &"tyrannosaurus"
const FEET := ["Toe.L", "Toe.R"]
const STANDING: Array[StringName] = [&"idle", &"alert", &"attack_primary", &"attack_heavy", &"bite_shake", &"tail_swipe", &"hit_react", &"feed"]
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
	print("[t_sp_tyrannosaurus] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_model()
	await _test_moves()
	_test_alpha_and_spawn()
	if failures.is_empty():
		print("[t_sp_tyrannosaurus] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_sp_tyrannosaurus] FAIL " + f)
		quit(1)

func _y(sk: Skeleton3D, view: Node3D, bone: String) -> float:
	return view.to_local(sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin).y

func _test_model() -> void:
	var def = data.creature(ID)
	var view = CV.new()
	root.add_child(view)
	view.setup(def)
	_expect(view.using_glb and view.rig != null, "draws the rigged v2 GLB")
	if view.rig == null:
		view.free()
		return
	for clip in def.pipeline.get("clips", []):
		_expect(view.rig.has_clip(StringName(clip)), "clip %s loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	_expect(sk.find_bone("Jaw") >= 0 and sk.get_bone_parent(sk.find_bone("Jaw")) == sk.find_bone("Head"), "a real Jaw bone under Head")
	var aabb := AABB()
	var first := true
	for mi in view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var box: AABB = m.global_transform * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	_expect(absf(aabb.size.y - 8.0) < 0.3 and maxf(aabb.size.x, aabb.size.z) > 15.0, "8 m tall, %.1f m long" % maxf(aabb.size.x, aabb.size.z))
	var ap: AnimationPlayer = view.rig.anim_player
	var jaw := sk.find_bone("Jaw")
	sk.reset_bone_poses()
	var jaw_rest := sk.get_bone_pose_rotation(jaw)
	for c in [[&"alert", 0.55], [&"attack_primary", 0.32], [&"bite_shake", 0.24]]:
		sk.reset_bone_poses()
		ap.play(c[0])
		ap.seek(ap.get_animation(c[0]).length * float(c[1]), true)
		var deg := rad_to_deg(jaw_rest.angle_to(sk.get_bone_pose_rotation(jaw)))
		_expect(deg > 20.0 and deg < 40.0, "%s: the jaw opens %.0f deg (inside the modelled gape)" % [c[0], deg])
	# standing clips: the lowest toe stays on the floor
	sk.reset_bone_poses()
	var rest := minf(_y(sk, view, FEET[0]), _y(sk, view, FEET[1]))
	var hips_rest := _y(sk, view, "Hips")
	for clip in STANDING:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		for k in 25:
			ap.seek(a.length * float(k) / 24.0, true)
			worst = maxf(worst, absf(minf(_y(sk, view, FEET[0]), _y(sk, view, FEET[1])) - rest))
		_expect(worst <= GROUND_TOL, "%s: lowest foot on the floor (worst %.3f m)" % [clip, worst])
	# lying: down on the belly (hips about 3 m lower), knockdown back up at the end
	for c in [[&"sleep", 0.0, true], [&"death", 1.0, true], [&"knockdown", 0.5, true], [&"knockdown", 1.0, false]]:
		sk.reset_bone_poses()
		ap.play(c[0])
		ap.seek(ap.get_animation(c[0]).length * float(c[1]), true)
		var drop: float = hips_rest - _y(sk, view, "Hips")
		_expect(drop > 1.4 if c[2] else absf(drop) < 0.1, "%s at %.0f%%: hips %.2f m below standing" % [c[0], float(c[1]) * 100.0, drop])
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
	return [host, player]

func _creature(host: Node3D, id: StringName, at: Vector3):
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id))
	return c

## The tyrant's rotation (bite, BITE AND SHAKE, stomp) and the battle roar, through the real brain on a real survivor.
func _test_moves() -> void:
	var a := _arena()
	var host: Node3D = a[0]
	var player = a[1]
	await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var rex = _creature(host, ID, Vector3(0, 0.1, -3.0))
	rex.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	var brain = rex.brain
	brain.process_mode = Node.PROCESS_MODE_DISABLED  # driven by hand below
	rex.anim.end_timed_attack()
	rex.anim._busy = false
	brain.roar_ready_at = INF  # the roar is checked on its own below
	brain.attack_target = player
	brain.attack_number = 1
	brain._do_attack()
	_expect(brain.windup_clip == &"bite_shake" and brain.phase == &"windup", "second attack on a survivor is the bite and shake (%s)" % brain.windup_clip)
	player.vitals.max_health = 100000.0  # a raid-sized pool: the shake must land without killing her
	player.vitals.health = 100000.0
	var hp0: float = player.vitals.health
	brain.phase_left = 0.0
	brain._think(1.0 / 60.0)
	_expect(player.vitals.health < hp0, "the bite and shake lands (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	_expect(player.statuses.has(&"pinned"), "the survivor is pinned in the jaws")
	_expect(brain.phase == &"recovery" and brain.phase_left > 1.5, "the shake and fling play out as recovery (%.2f s)" % brain.phase_left)
	brain._end_phase()
	# a big target can't be lifted: the second attack stays a plain bite
	_expect(not brain.can_grab(rex) and brain.can_grab(player), "only a survivor or a small creature can be grabbed")
	# battle roar
	player.statuses.clear_all()
	var small = _creature(host, &"compsognathus", Vector3(6, 0.1, -6))
	var big = _creature(host, &"stegosaurus", Vector3(-10, 0.1, -6))
	var far = _creature(host, &"compsognathus", Vector3(40, 0.1, 30))
	for c in [small, big, far]:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	brain.attack_target = player
	rex.anim._busy = false
	brain.roar_ready_at = 0.0
	brain._do_attack()
	_expect(brain.windup_clip == &"alert" and brain.phase == &"windup", "mid-fight she stops to roar (%s)" % brain.windup_clip)
	brain.phase_left = 0.0
	brain._think(1.0 / 60.0)
	_expect(small.statuses.has(&"groggy"), "the roar staggers a small creature nearby")
	_expect(not big.statuses.has(&"groggy"), "a big animal stands its ground")
	_expect(not far.statuses.has(&"groggy"), "out of earshot nothing happens")
	_expect(player.statuses.has(&"groggy"), "the survivor staggers (groggy)")
	_expect(brain.roar_ready_at > Time.get_ticks_msec() * 0.001 + 10.0, "the roar goes on cooldown")
	host.free()

func _test_alpha_and_spawn() -> void:
	var def = data.creature(ID)
	_expect(CV.pick_variant(def, "tyrannosaurus@(1, 2, 3)") == &"", "a normal rex keeps the olive hide")
	var host := Node3D.new()
	root.add_child(host)
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.alpha_spawn = true
	c.spawn(def)
	_expect(c.is_alpha() and c.variant == &"alpha" and c.view.variant == &"alpha", "an Alpha wears the armoured skin (%s)" % c.view.variant)
	var tex_ok := false
	for mi in c.view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var mat := m.get_active_material(0) as ShaderMaterial
		var tex: Texture2D = mat.get_shader_parameter("albedo_tex") if mat else null
		tex_ok = tex_ok or (tex != null and tex.resource_path.ends_with("tyrannosaurus_alpha_albedo.jpg"))
	_expect(tex_ok, "the Alpha's surfaces sample tyrannosaurus_alpha_albedo.jpg")
	host.free()
	var isl: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	_expect(JSON.stringify(isl).contains("\"species\":\"tyrannosaurus\""), "an island spawn table still lists the tyrannosaurus")
