extends SceneTree
## PACHYBULL (owner 2026-10-31, fight lab: "Pachy is teleporting or something, not sure why. its actually kind of a
## success. instead of it walking back slowly, have it jump backwards and wind up like a bull, huff huff, and then
## charge"). A pachycephalosaurus fights the GOD survivor (auto-fighting) in a lab world with a baked navmesh:
## - over 3 charge cycles no physics frame moves its body, or its hips within the body, more than its top speed
##   (run x charge_speed_mult) x dt x 3 (the teleport was the survivor's kick moving it 3.46 m in one frame);
## - every cycle is charge -> hop_back -> hop_back -> bull_windup (display) -> charge, and walk_back never plays;
## - both clips are on the rig, the hops play hop_back and the windup plays bull_windup for its length.
## Run: Godot --headless --path game --script res://tests/t_pachybull.gd  -> "[t_pachybull] PASS", exit 0.

const CYCLES := 3
const MAX_S := 40.0

var failures: Array[String] = []
var _started := false

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_pachybull] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	seed(20261031)
	Engine.max_physics_steps_per_frame = 1000
	var game := root.get_node("Game")
	game.debug_overlay = false
	game.god_mode = true
	var host := Node3D.new()
	root.add_child(host)
	var LK = load("res://scripts/dev/lab_kit.gd")
	var player: Node3D = LK.build(host)["player"]
	LK.bake(host)
	await physics_frame
	await physics_frame
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = player.global_position + Vector3(0, -0.9, -8)
	c.spawn(root.get_node("Data").creature(&"pachycephalosaurus"), &"", 0, null, 0, &"aggressive")
	await physics_frame
	await physics_frame
	_expect(c.anim.has_state(&"hop_back") and c.anim.has_state(&"bull_windup"), "the rig has hop_back and bull_windup")
	_expect(str(c.brain.tac.get("charge_reset", "")) == "bull" and str(c.brain.tac.get("backoff", "")) == "leap", "species tactics: bull reset after a charge, leap back-offs (no scurry)")
	c.brain.on_aggro(player)
	var log: Array[StringName] = []
	c.brain.tactic.connect(func(k: StringName) -> void:
		if k in [&"charge", &"hop", &"display"]:
			log.append(k))
	var sk: Skeleton3D = c.view.find_children("*", "Skeleton3D", true, false)[0]
	var hips := sk.find_bone("Hips")
	var hz := float(Engine.physics_ticks_per_second)
	var top: float = c.move_speed_mps() * c.run_speed_mult() * float(c.brain.tac.get("charge_speed_mult", 1.5))
	var lim := top / hz * 3.0
	var worst := 0.0
	var worst_at := ""
	var prev: Vector3 = c.global_position
	var prevh: Vector3 = c.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(hips)).origin
	var walk_back := 0
	var hop_clip_ok := true
	var windup_frames := 0
	var charging := false
	for f in int(MAX_S * hz):
		await physics_frame
		player.vitals.health = player.vitals.effective_max_health()
		c.brain._provoked_until = c.brain._now_s() + 10.0  # keep it fighting (a skittish grazer stands down)
		var pos: Vector3 = c.global_position
		var h: Vector3 = c.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(hips)).origin
		var d := maxf(Vector2(pos.x - prev.x, pos.z - prev.z).length(), Vector2(h.x - prevh.x, h.z - prevh.z).length())
		if d > worst:
			worst = d
			worst_at = "f%d %s/%s" % [f, c.brain.state, c.anim.current_clip]
		prev = pos
		prevh = h
		charging = charging or c.brain.state == &"charge"
		if charging and c.anim.current_clip == &"walk_back":
			walk_back += 1
		if c.brain.state == &"hop" and c.brain._j_t > 0.05 and c.anim.current_clip != &"hop_back":
			hop_clip_ok = false
		if c.brain.state == &"display" and c.anim.current_clip == &"bull_windup":
			windup_frames += 1
		if log.count(&"charge") > CYCLES:
			break
	_expect(worst <= lim, "no teleport: worst frame step %.2f m <= %.2f m (top %.1f m/s x dt x 3) at %s" % [worst, lim, top, worst_at])
	# From the first charge on, the pattern repeats: charge, hop, hop, display, charge ...
	var from := log.find(&"charge")
	var seq := log.slice(from) if from >= 0 else []
	var want: Array[StringName] = []
	for i in CYCLES:
		want.append_array([&"charge", &"hop", &"hop", &"display"])
	want.append(&"charge")
	_expect(seq == want, "%d cycles of charge -> hop_back -> hop_back -> bull_windup -> charge (%s)" % [CYCLES, seq])
	_expect(walk_back == 0, "no walk-back once the charges start (%d frames)" % walk_back)
	_expect(hop_clip_ok, "every hop plays hop_back")
	var windup_s: float = c.anim.player.get_animation(&"bull_windup").length
	_expect(windup_frames >= int(CYCLES * windup_s * hz * 0.8), "the windup plays bull_windup (%d frames, %.2f s clip)" % [windup_frames, windup_s])
	_expect(windup_s >= 1.0 and windup_s <= 1.5, "the windup is a 1-1.5 s telegraph (%.2f s)" % windup_s)
	if failures.is_empty():
		print("[t_pachybull] PASS")
		quit(0)
	else:
		print("[t_pachybull] FAIL %d" % failures.size())
		quit(1)
