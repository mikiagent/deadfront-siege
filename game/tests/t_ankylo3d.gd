extends SceneTree
## ANKYLO3D: the ankylosaurus draws its rigged Tripo model (no box placeholder) with every listed clip plus the
## strafes and walk_back, it stands about survivor-shoulder high, the feet stay on the floor in the standing clips,
## the jaw bone exists, and a spawned one runs ClubTailBrain (ANKYLOAI): its attack_primary, played with a survivor at
## its snout, does not hurt her (the club, not reach from the centre, is the hit; t_ankyloai tests the hits themselves).
## Run: Godot --headless --path game --script res://tests/t_ankylo3d.gd  -> "[t_ankylo3d] PASS", exit 0.

const ID := &"ankylosaurus"
const EXTRA_CLIPS: Array[StringName] = [&"walk_back", &"strafe_left", &"strafe_right"]
const FEET := ["BackFoot.L", "BackFoot.R", "FrontFoot.L", "FrontFoot.R"]
const GROUND_TOL := 0.06  ## m: the lowest foot bone stays this close to its rest height in standing clips

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
	print("[t_ankylo3d] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	await _test_hit()
	if failures.is_empty():
		print("[t_ankylo3d] PASS")
		quit(0)
	else:
		print("[t_ankylo3d] FAIL %d" % failures.size())
		quit(1)

func _boxes(n: Node) -> int:
	var c := 0
	var mi := n as MeshInstance3D
	if mi and (mi.mesh is BoxMesh or mi.mesh is CylinderMesh):
		c += 1
	for ch in n.get_children():
		c += _boxes(ch)
	return c

func _bone_y(sk: Skeleton3D, view: Node3D, b: String, rest: bool = false) -> float:
	var i := sk.find_bone(b)
	var t := sk.get_bone_global_rest(i) if rest else sk.get_bone_global_pose(i)
	return (sk.global_transform * t).origin.y - view.global_position.y

func _test_view() -> void:
	var def = data.creature(ID)
	_expect(ResourceLoader.exists("res://assets/creatures/ankylosaurus/ankylosaurus.glb"), "ankylosaurus GLB exists")
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
	_expect(clips.size() >= 11, "species lists its clips (%d)" % clips.size())
	for clip in clips + EXTRA_CLIPS:
		var authored := ResourceLoader.exists("res://assets/creatures/ankylosaurus/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	_expect(sk.find_bone("Jaw") >= 0, "Jaw bone in the rig")
	for t in ["Tail1", "Tail2", "Tail3", "Tail4", "Tail5"]:
		_expect(sk.find_bone(t) >= 0, "tail chain bone %s" % t)
	# Size: the survivor (1.78 m) reaches about its shoulder; the body is low and long.
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
	_expect(absf(aabb.size.y - def.height_meters) < 0.15 and def.height_meters > 1.9 and def.height_meters < 2.6,
		"height %.2f m (shell over the shoulders at survivor head height)" % aabb.size.y)
	_expect(long_side > 2.8 * aabb.size.y, "low and long: %.1f m long, %.1f m tall" % [long_side, aabb.size.y])
	# Standing clips keep the feet on the floor.
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in FEET:
		rest = minf(rest, _bone_y(sk, view, b, true))
	for clip in [&"idle", &"walk", &"run", &"attack_primary", &"attack_heavy", &"hit_react", &"alert", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		for k in 13:
			ap.seek(a.length * float(k) / 12.0, true)
			var lo := INF
			for b in FEET:
				lo = minf(lo, _bone_y(sk, view, b))
			worst = maxf(worst, absf(lo - rest))
		_expect(worst <= GROUND_TOL, "%s: lowest foot stays on the floor (worst %.3f m off rest)" % [clip, worst])
	# ANKYLOAI: where and when the club hits is t_ankyloai (club sphere in each move's strike window).
	view.free()

## A real ankylosaurus runs ClubTailBrain; its tail whip played at a survivor in front of its snout does not reach her.
func _test_hit() -> void:
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	var host := Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = Vector3(0, 0.1, -2.6)
	c.spawn(data.creature(ID))
	_expect(c.view.using_glb and _boxes(c.view) == 0, "a spawned ankylosaurus draws the GLB, no boxes")
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	c.brain.attack_target = player
	if "_provoked_until" in c.brain:
		c.brain._provoked_until = c.brain._now_s() + 30.0
	var hits := [0]
	c.anim.attack_hit.connect(func(clip: StringName) -> void:
		if clip == &"attack_primary":
			hits[0] += 1)
	var hp0: float = player.vitals.health
	c.anim.play_clip(&"attack_primary")
	for _f in 120:
		await physics_frame
	_expect(c.brain.get_script().get_global_name() == &"ClubTailBrain", "a wild ankylosaurus runs ClubTailBrain")
	_expect(hits[0] == 1, "attack_primary reaches its hit frame once (%d)" % hits[0])
	_expect(is_equal_approx(player.vitals.health, hp0), "the old reach-from-centre hit is gone: a survivor at the snout keeps hp %.0f -> %.0f" % [hp0, player.vitals.health])
	host.free()
