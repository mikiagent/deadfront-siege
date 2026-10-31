extends SceneTree
## ANKYLO3D: the ankylosaurus draws its rigged Tripo model (no box placeholder) with every listed clip plus the
## strafes and walk_back, it stands about survivor-shoulder high, the feet stay on the floor in the standing clips,
## the jaw bone exists, the tail-club attack swings the club out to the side at its hit frame, and an
## attack_primary started by the brain lands on a survivor in reach.
## Run: Godot --headless --path game --script res://tests/t_ankylo3d.gd  -> "[t_ankylo3d] PASS", exit 0.

const ID := &"ankylosaurus"
const EXTRA_CLIPS: Array[StringName] = [&"walk_back", &"strafe_left", &"strafe_right"]
const FEET := ["BackFoot.L", "BackFoot.R", "FrontFoot.L", "FrontFoot.R"]
const GROUND_TOL := 0.06  ## m: the lowest foot bone stays this close to its rest height in standing clips
const HIT := {&"attack_primary": 0.42, &"attack_heavy": 0.72}  ## anim_events.json hit_frac

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
	# The club is the hit: at the hit frame the tail tip is out to the side of the body and moving fast.
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var tip := sk.find_bone("Tail5")
	for clip in HIT:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var at: float = a.length * float(HIT[clip])
		ap.seek(at - 0.1, true)
		var before := (sk.global_transform * sk.get_bone_global_pose(tip)).origin
		ap.seek(at, true)
		var p := (sk.global_transform * sk.get_bone_global_pose(tip)).origin
		var side: float = (p - (view as Node3D).global_position).dot(right)
		var speed := p.distance_to(before) / 0.1
		_expect(absf(side) > 1.5 and speed > 4.0, "%s: club %.2f m to the side at the hit, %.1f m/s" % [clip, side, speed])
	view.free()

## A real ankylosaurus, provoked, swings attack_primary at a survivor in reach and the hit lands.
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
	_expect(hits[0] == 1, "attack_primary reaches its hit frame once (%d)" % hits[0])
	_expect(player.vitals.health < hp0, "the club lands on the survivor (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	host.free()
