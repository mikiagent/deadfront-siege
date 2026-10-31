extends SceneTree
## MEGAREX (owner 2026-10-31: the v2 open-mouth rex becomes its own boss, "MegaRex"): the model draws 1.3x the T. rex
## with every clip, the Jaw opens the mouth inside the modelled gape, the lying clips put her on her belly and
## knockdown gets her back up, the feet stay on the floor in the standing clips; the boss brain runs its phases
## (1: bite, bite, stomp, no tail whip; 2: bite and shake + tail whip, shorter windups; 3: enraged roar that staggers
## the survivor and small creatures, not big ones, faster still); the HUD's boss bar picks her up while she fights the
## survivor; she can't be tamed, drops alpha loot, spawns at most one per island on the top-tier islands; and the
## regular tyrannosaurus is untouched (its own model, its TyrantBrain).
## Run: Godot --headless --path game --script res://tests/t_sp_megarex.gd  -> "[t_sp_megarex] PASS"

const ID := &"megarex"
const FEET := ["Toe.L", "Toe.R"]
const STANDING: Array[StringName] = [&"idle", &"alert", &"attack_primary", &"attack_heavy", &"bite_shake", &"tail_swipe", &"hit_react", &"feed"]
const GROUND_TOL := 0.08

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
	print("[t_sp_megarex] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_model()
	await _test_phases()
	_test_data()
	if failures.is_empty():
		print("[t_sp_megarex] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_sp_megarex] FAIL " + f)
		quit(1)

func _y(sk: Skeleton3D, view: Node3D, bone: String) -> float:
	return view.to_local(sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin).y

func _test_model() -> void:
	var def = data.creature(ID)
	var view = CV.new()
	root.add_child(view)
	view.setup(def)
	_expect(view.using_glb and view.rig != null, "draws the rigged MegaRex GLB")
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
	_expect(absf(aabb.size.y - 10.4) < 0.4 and maxf(aabb.size.x, aabb.size.z) > 19.0, "10.4 m tall (1.3x the T. rex), %.1f m long" % maxf(aabb.size.x, aabb.size.z))
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
	for c in [[&"sleep", 0.0, true], [&"death", 1.0, true], [&"knockdown", 0.5, true], [&"knockdown", 1.0, false]]:
		sk.reset_bone_poses()
		ap.play(c[0])
		ap.seek(ap.get_animation(c[0]).length * float(c[1]), true)
		var drop: float = hips_rest - _y(sk, view, "Hips")
		_expect(drop > 1.8 if c[2] else absf(drop) < 0.13, "%s at %.0f%%: hips %.2f m below standing" % [c[0], float(c[1]) * 100.0, drop])
	view.free()

func _creature(host: Node3D, id: StringName, at: Vector3):
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id))
	return c

func _attack(rex, brain) -> void:
	brain._end_phase()
	rex.anim._busy = false
	brain._do_attack()

func _test_phases() -> void:
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
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.vitals.max_health = 100000.0
	player.vitals.health = 100000.0
	var rex = _creature(host, ID, Vector3(0, 0.1, -3.0))
	rex.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	var brain = rex.brain
	_expect(brain.get_script().get_global_name() == &"MegaRexBrain", "MegaRex runs the boss brain (%s)" % brain.get_script().resource_path.get_file())
	brain.process_mode = Node.PROCESS_MODE_DISABLED
	brain.attack_target = player
	var hp: float = rex.health.max_hp
	# phase 1: bite, bite, stomp; no bite and shake, no tail whip, no roar
	brain._update_phase()
	_expect(brain.boss_phase == 1, "full health is phase 1")
	brain.attack_number = 1
	_attack(rex, brain)
	_expect(brain.windup_clip == &"attack_primary", "phase 1: the second attack is a plain bite (%s)" % brain.windup_clip)
	var w1: float = brain.phase_left
	_expect(not brain._tail_ok(), "phase 1: no tail whip")
	_expect(brain.engaged_boss(player) == rex, "the boss bar finds her while she fights the survivor")
	# phase 2
	rex.health.hp = hp * 0.6
	brain._update_phase()
	_expect(brain.boss_phase == 2 and brain._tail_ok(), "below 66 %: phase 2, the tail whip is on")
	# THERO-ROAR: the phase change opens with the rearing roar
	_attack(rex, brain)
	_expect(brain.windup_clip == &"roar", "phase 2 opens with the roar (%s)" % brain.windup_clip)
	brain._end_phase()
	player.statuses.clear_all()
	brain.attack_number = 1
	_attack(rex, brain)
	_expect(brain.windup_clip == &"bite_shake", "phase 2: the second attack on a survivor is the bite and shake (%s)" % brain.windup_clip)
	_expect(absf(brain.phase_left - 0.75 * 0.8) < 0.01, "phase 2: shorter telegraph (%.2f s)" % brain.phase_left)
	var hp0: float = player.vitals.health
	brain.phase_left = 0.0
	brain._think(1.0 / 60.0)
	_expect(player.vitals.health < hp0, "the bite and shake lands")
	_expect(player.statuses.has(&"knockdown") and not player.statuses.has(&"pinned"), "she is flung down (knockdown); Pinned stays the stomp's")
	brain.attack_number = 0
	_attack(rex, brain)
	_expect(brain.windup_clip == &"attack_primary" and brain.phase_left < w1, "phase 2 bites wind up faster (%.2f < %.2f s)" % [brain.phase_left, w1])
	# phase 3: enraged roar
	player.statuses.clear_all()
	var small = _creature(host, &"compsognathus", Vector3(6, 0.1, -6))
	var big = _creature(host, &"stegosaurus", Vector3(-12, 0.1, -6))
	var far = _creature(host, &"compsognathus", Vector3(50, 0.1, 40))
	for c in [small, big, far]:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	rex.health.hp = hp * 0.3
	brain._think(1.0 / 60.0)
	_expect(brain.boss_phase == 3 and rex.statuses.has(&"enraged"), "below 33 %: phase 3, enraged")
	_attack(rex, brain)
	_expect(brain.windup_clip == &"roar", "phase 3 opens with the roar (%s)" % brain.windup_clip)
	brain.phase_left = 0.0
	brain._think(1.0 / 60.0)
	_expect(small.statuses.has(&"groggy"), "the roar staggers a small creature nearby")
	_expect(not big.statuses.has(&"groggy"), "a big animal stands its ground")
	_expect(not far.statuses.has(&"groggy"), "out of earshot nothing happens")
	_expect(player.statuses.has(&"groggy"), "the survivor staggers (groggy)")
	_attack(rex, brain)
	_expect(brain.windup_clip != &"roar", "the roar goes on cooldown (%s next)" % brain.windup_clip)
	_expect(brain.opening_label().begins_with("MEGAREX  PHASE 3  ENRAGED"), "boss bar label: %s" % brain.opening_label())
	var t = _creature(host, &"tyrannosaurus", Vector3(30, 0.1, 30))
	_expect(t.brain.get_script().get_global_name() == &"TyrantBrain" and not t.anim.has_state(&"bite_shake"), "the regular tyrannosaurus keeps its own brain and clips")
	host.free()

func _test_data() -> void:
	var def = data.creature(ID)
	_expect(not def.tameable, "MegaRex can't be tamed or captured")
	_expect(def.height_meters > data.creature(&"tyrannosaurus").height_meters * 1.25, "bigger than the T. rex")
	var lt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/loot_tables.json"))
	_expect((lt["alpha"]["by_species"] as Dictionary).has("megarex"), "alpha loot rows for MegaRex")
	var isl: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var n := 0
	for id in isl:
		if not isl[id] is Dictionary or not (isl[id] as Dictionary).has("spawns"):
			continue
		for zone in isl[id]["spawns"]:
			for row in isl[id]["spawns"][zone]:
				if str(row.get("species", "")) == "megarex":
					n += 1
					_expect(int(isl[id].get("tier", 0)) >= 55 and int(row.get("count", 1)) == 1 and int(row.get("groups", 1)) == 1,
						"%s: one MegaRex at most, on a top-tier island (tier %d)" % [id, int(isl[id].get("tier", 0))])
	_expect(n > 0, "the island tables spawn MegaRex (%d rows)" % n)
