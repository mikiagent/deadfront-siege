extends SceneTree
## ANKYLOAI (owner 2026-10-31: "ankylosaurus is doing the rush and tackle strategy, it hits too often. I want it to hit
## HARD ... smashing that tail around"; "keeps feet planted or steps in the direction for the swing ... the tail doesn't
## even look like its hitting me"). A real ankylosaurus (ClubTailBrain) next to a live survivor in GOD mode:
## 1. per move (TAIL WHIP / TAIL SMASH / CLUB SWEEP): the club bone passes within the move's hit radius of the spot the
##    brain aims the target at (ai.json club_moves) and never near a survivor at the snout;
## 2. per move, survivor on that spot: the body neither turns nor slides in code while the clip plays; the ring and the move's name are up from the first frame, the hit lands no
##    earlier than the wind-up (strike window start) and from the club (club sphere at the hit); a survivor at the snout
##    is never hit; the smash hits a survivor straight behind it and knocks her down;
## 3. a roll pressed just before the whip's hit (the telegraph) takes no hit;
## 4. a 40 s fight from 9 m: it never runs or charges, never closes within 2 m, starts every move with the survivor on
##    its tail side (near the move's aim bearing), and hits at most once every MIN_HIT_GAP_S.
## Run: Godot --headless --path game --script res://tests/t_ankyloai.gd  -> "[t_ankyloai] PASS", exit 0.

const ID := &"ankylosaurus"
const MOVES: Array[StringName] = [&"whip", &"smash", &"sweep"]
const SURVIVOR_R := 0.35
## ASSUMPTION (Open Questions): at most one club hit every this many seconds on one survivor.
const MIN_HIT_GAP_S := 3.0
const DT := 1.0 / 60.0

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D
var player: Node3D
var _hits: Array = []  # [move, target, kind, move_t, club]
var _watch := 0.0

func _process(delta: float) -> bool:
	if _started:
		_watch += delta
		if _watch > 240.0:
			print("[t_ankyloai] FAIL watchdog")
			quit(1)
		return false
	if root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_ankyloai] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	root.get_node("Game").god_mode = true  # hits land (club_hit, flinch) but cost no health: she lives through all of it
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	host = Node3D.new()
	host.name = "TAnkyloAIHost"
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 80.0)
	player = kit["player"]
	for i in 10:
		await physics_frame
	await _test_club_paths()
	await _test_moves()
	await _test_roll()
	await _test_fight()
	root.get_node("Game").god_mode = false
	if failures.is_empty():
		print("[t_ankyloai] PASS")
		quit(0)
	else:
		print("[t_ankyloai] FAIL %d" % failures.size())
		quit(1)

func _spawn(at: Vector3, face: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID))
	c.look_at(Vector3(face.x, at.y, face.z), Vector3.UP)
	c.brain.club_hit.connect(func(mv: StringName, t: Node3D, kind: StringName) -> void:
		_hits.append([mv, t, kind, c.brain.move_t, c.brain.club_position()]))
	return c

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _place(p: Vector3) -> void:
	player.global_position = Vector3(p.x, player.global_position.y, p.z)
	player.velocity = Vector3.ZERO
	player.statuses.clear_all()

func _move(c, id: StringName) -> Dictionary:
	return c.brain.moves[id]

## 1. The club bone's path through each strike window (seeked on the creature's own AnimationPlayer, brain paused).
func _test_club_paths() -> void:
	var c = _spawn(Vector3(20, 0, 20), Vector3(20, 0, 0))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	var ap: AnimationPlayer = c.view.rig.anim_player
	var tree := c.anim.tree as AnimationTree
	if tree:
		tree.active = false
	var sk: Skeleton3D = c.view.rig.skeleton
	var snout: Vector3 = c.global_position + (-c.global_basis.z) * 4.5  # ~1 m ahead of the head
	for id in MOVES:
		var mv := _move(c, id)
		var clip := StringName(mv["clip"])
		var spot: Vector3 = c.brain.strike_spot(id)
		var a := ap.get_animation(clip)
		var near_spot := INF
		var near_snout := INF
		sk.reset_bone_poses()
		ap.play(clip)
		for k in 25:
			var u: float = lerpf(float(mv["strike"][0]), float(mv["strike"][1]), float(k) / 24.0)
			ap.seek(a.length * u, true)
			var club: Vector3 = c.brain.club_position()
			near_spot = minf(near_spot, _flat(club, spot))
			near_snout = minf(near_snout, _flat(club, snout))
		var r := float(mv["hit_radius_m"])
		_expect(near_spot <= r - SURVIVOR_R, "%s: the club passes %.2f m from its aim spot (%.0f deg, %.1f m) in the strike window (radius %.2f)" % [id, near_spot, mv["target_bearing_deg"], mv["target_dist_m"], r - SURVIVOR_R])
		_expect(near_snout > r + SURVIVOR_R, "%s: the club stays %.2f m from a survivor at the snout" % [id, near_snout])
	if tree:
		tree.active = true
	c.queue_free()
	await physics_frame

## Run one move against the survivor at `at`; returns [hits on her, telegraph up at t=0, telegraph up at the hit].
func _run_move(id: StringName, at: Vector3, roll_at: float = -1.0) -> Dictionary:
	var c = _spawn(Vector3.ZERO, Vector3(0, 0, -10))
	await physics_frame
	await physics_frame
	var b = c.brain
	b.attack_target = player
	b._provoked_until = b._now_s() + 120.0
	_place(at)
	_hits.clear()
	b._start(id)
	var ring_start := is_instance_valid(b.telegraph) and b.telegraph.get_parent() != null
	var out := {"ring_start": ring_start, "ring_at_hit": false, "hit_t": -1.0, "len": b.move_len, "club_d": INF, "rolled": false,
		"label": (b.telegraph.get_child(1) as Label3D).text if ring_start and b.telegraph.get_child_count() > 1 else ""}
	var yaw0: float = c.rotation.y
	var pos0: Vector3 = c.global_position
	var guard := 0
	while b.move_id != &"" and guard < 600:
		if roll_at >= 0.0 and not out["rolled"] and b.move_t >= roll_at:
			out["rolled"] = player.sim.try_roll(Vector3(1, 0, 0))
		var n := _hits.size()
		await physics_frame
		guard += 1
		_place_hold(at, roll_at)
		if _hits.size() > n and out["hit_t"] < 0.0:
			out["hit_t"] = float(_hits[n][3])
			out["ring_at_hit"] = is_instance_valid(b.telegraph)
			out["club_d"] = _flat(_hits[n][4], player.global_position)
			out["kind"] = _hits[n][2]
			out["knockdown"] = player.statuses.has(&"knockdown")
	out["turned"] = absf(angle_difference(yaw0, c.rotation.y))
	out["slid"] = _flat(pos0, c.global_position)
	out["hits"] = _hits.filter(func(h: Array) -> bool: return h[1] == player).size()
	c.queue_free()
	await physics_frame
	player.statuses.clear_all()
	return out

## Keep a non-rolling survivor on her spot (the knockback would carry her off it before a later frame).
func _place_hold(at: Vector3, roll_at: float) -> void:
	if roll_at < 0.0 and _hits.is_empty():
		player.global_position = Vector3(at.x, player.global_position.y, at.z)

## 2. Each move on the survivor at its aim spot, at the snout, and (smash) straight behind.
func _test_moves() -> void:
	var probe = _spawn(Vector3(40, 0, 40), Vector3(40, 0, 30))
	probe.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	for id in MOVES:
		var mv := _move(probe, id)
		var b := deg_to_rad(float(mv["target_bearing_deg"]))
		var spot := Vector3(sin(b), 0, -cos(b)) * float(mv["target_dist_m"])  # spawned at the origin facing -Z, + = right (+X)
		var r := await _run_move(id, spot)
		var windup := float(mv["strike"][0]) * float(r["len"])
		_expect(r["ring_start"] and str(r["label"]).begins_with(str(mv["label"])), "%s: ring and name up from the first frame (\"%s\")" % [id, r["label"]])
		_expect(int(r["hits"]) == 1, "%s: one hit on a survivor at its aim spot (%d)" % [id, r["hits"]])
		_expect(float(r["hit_t"]) >= windup - DT, "%s: the hit lands at %.2f s, after a %.2f s wind-up" % [id, r["hit_t"], windup])
		_expect(r["ring_at_hit"], "%s: the ring is still up when the club lands" % id)
		_expect(float(r["club_d"]) <= float(mv["hit_radius_m"]) + 0.01, "%s: the hit comes from the club, %.2f m from her at the hit" % [id, r["club_d"]])
		_expect(float(r["turned"]) < 0.001 and float(r["slid"]) < 0.01, "%s: no turn and no slide in code while the clip plays (%.4f rad, %.3f m)" % [id, r["turned"], r["slid"]])
		if id == &"smash":
			_expect(r.get("kind", &"") == &"club" and r.get("knockdown", false), "smash: the club itself lands (not the shockwave) and knocks her down")
		var head := await _run_move(id, Vector3(0, 0, -4.5))
		_expect(int(head["hits"]) == 0, "%s: a survivor at the snout is not hit (%d)" % [id, head["hits"]])
	var behind := await _run_move(&"smash", Vector3(0, 0, 3.0))
	_expect(int(behind["hits"]) == 1, "smash: a survivor straight behind at 3 m is hit (%d)" % behind["hits"])
	probe.queue_free()
	await physics_frame

## 3. A roll pressed in the telegraph, just before the whip's club arrives, takes no hit.
func _test_roll() -> void:
	var probe = _spawn(Vector3(40, 0, 40), Vector3(40, 0, 30))
	probe.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	var mv := _move(probe, &"whip")
	probe.queue_free()
	var b := deg_to_rad(float(mv["target_bearing_deg"]))
	var spot := Vector3(sin(b), 0, -cos(b)) * float(mv["target_dist_m"])
	var first := await _run_move(&"whip", spot)
	var t_hit := float(first["hit_t"])
	for i in 80:  # roll cooldown and the hit stagger wear off
		await physics_frame
	var rolled := await _run_move(&"whip", spot, maxf(0.0, t_hit - 0.12))
	_expect(rolled["rolled"] and int(rolled["hits"]) == 0, "a roll pressed 0.12 s before the whip lands (in its telegraph) takes no hit (rolled=%s, hits=%d)" % [rolled["rolled"], rolled["hits"]])
	for i in 80:
		await physics_frame

## 4. A whole fight: it shuffles, turns its tail to her and swings rarely.
func _test_fight() -> void:
	_place(Vector3(0, 0, 0))
	var c = _spawn(Vector3(0, 0, -9), Vector3(0, 0, 0))
	await physics_frame
	var b = c.brain
	b.attack_target = player
	b._provoked_until = b._now_s() + 600.0
	b._set_state(&"approach")
	_hits.clear()
	var walk: float = load("res://scripts/creatures/creature_clips.gd").natural_speed(c.def, &"walk")
	var top_speed := 0.0
	var top_at := -1
	var ran := 0
	var min_d := INF
	var starts: Array = []
	var was := &""
	var hit_times: Array[float] = []
	var t := 0.0
	for f in 40 * 60:
		await physics_frame
		t += DT
		if b.move_id == &"":
			player.global_position = Vector3(0, player.global_position.y, 0)  # she stands her ground
		var p: Vector3 = c.global_position
		# Its own locomotion (the survivor's auto-kick shoves it 0.8 m in a frame; that is not the ankylosaurus moving).
		var v := Vector2(c.velocity.x, c.velocity.z).length()
		if v > top_speed:
			top_speed = v
			top_at = f
		if c.anim.current_clip in [&"run", &"charge"]:
			ran += 1
		min_d = minf(min_d, _flat(p, player.global_position))
		if b.move_id != &"" and was == &"":
			starts.append([b.move_id, b.bearing_of(player.global_position), float(b.moves[b.move_id]["target_bearing_deg"])])
		was = b.move_id
		while hit_times.size() < _hits.size():
			hit_times.append(t)
	_expect(ran == 0, "never runs or charges (%d frames on run/charge)" % ran)
	_expect(top_speed <= maxf(walk, 1.0) * 1.6, "shuffles at a walk: top speed %.2f m/s at frame %d (walk %.2f)" % [top_speed, top_at, walk])
	_expect(min_d >= 2.0, "never closes to tackle range: nearest %.2f m centre to centre" % min_d)
	_expect(starts.size() >= 2, "it swings in a 40 s fight (%d moves: %s)" % [starts.size(), starts.map(func(s: Array) -> String: return str(s[0]))])
	for s in starts:
		var err := absf(rad_to_deg(angle_difference(deg_to_rad(float(s[1])), deg_to_rad(float(s[2])))))
		_expect(absf(float(s[1])) >= 90.0 and err <= 25.0, "%s starts with her on its tail side: bearing %+.0f deg (aim %+.0f)" % [s[0], s[1], s[2]])
	_expect(hit_times.size() >= 1, "the club lands at least once (%d)" % hit_times.size())
	var gap := INF
	for i in range(1, hit_times.size()):
		gap = minf(gap, hit_times[i] - hit_times[i - 1])
	_expect(gap >= MIN_HIT_GAP_S, "at most one hit every %.0f s: %d hits in 40 s, closest %.2f s apart" % [MIN_HIT_GAP_S, hit_times.size(), gap])
	c.queue_free()
	await physics_frame
