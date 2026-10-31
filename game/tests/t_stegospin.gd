extends SceneTree
## STEGOSPIN (owner 2026-10-31: "Stego needs a stronger twist attack, tackle attack, etc. it should be spinning a lot, anky
## and stego are similar" / "also needs stomp attacks" / "for both stegos"; on the ankylosaurus: "don't have the
## ankylosaurus back himself into me for an attack, he should also joust and be able to hit you with his tail from the
## front by spinning and smacking you with the tail"). Real animals (ClubTailBrain) and the survivor in GOD mode.
## Stegosaurus, both looks (graded, ochre: one rig and clip set):
## 1. spins: with her round its rear for 20 s it spins at least MIN_SPINS times by more than 180 deg each, a spin lands on her
##    with a knockback of at least 3 m and a knockdown, and every planted toe stays put in the world through each turn
##    (the code turn and the clip's counter-turn agree: no foot slides);
## 2. stomps: STOMP and REAR SLAM land on her in front, HIND STOMP beside each flank, each with the body standing still;
## 3. close moves: SHOVE beside each shoulder (pushing her off that side), TACKLE in front past the stomp's reach.
## Ankylosaurus:
## 4. TAIL SPIN from the front lands on her (a turn of more than 180 deg, the club and tail swept through the front);
## 5. no back-in: with her behind it past the club's reach, it never moves toward her tail first; it turns head first;
## 6. joust: from 18 m it charges past her (well beyond where she stood), comes round on the run gait (no hop clip) and
##    charges again; the first pass lands on her.
## Run: Godot --headless --path game --script res://tests/t_stegospin.gd  -> "[t_stegospin] PASS", exit 0.

const DT := 1.0 / 60.0
const MIN_SPINS := 3
## ASSUMPTION: a planted toe may drift this much (m) over one planted stretch (a frame of physics/pose lag at most).
const TOE_SLIDE_MAX := 0.15
const TOES := {&"stegosaurus": ["front_toe_L", "front_toe_R", "hind_toe_L", "hind_toe_R"],
	&"ankylosaurus": ["FrontFoot.L", "FrontFoot.R", "BackFoot.L", "BackFoot.R"]}

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D
var player: Node3D
var _hits: Array = []  # [move, target, kind, t]
var _t := 0.0
var _watch := 0.0

func _process(delta: float) -> bool:
	if _started:
		_watch += delta
		if _watch > 600.0:
			print("[t_stegospin] FAIL watchdog")
			quit(1)
		return false
	if root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_stegospin] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	root.get_node("Game").god_mode = true
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	host = Node3D.new()
	host.name = "TStegoSpinHost"
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 120.0)
	player = kit["player"]
	for i in 10:
		await physics_frame
	for v in ([] if OS.get_cmdline_user_args().has("joust") else ([&"graded"] if OS.get_cmdline_user_args().has("quick") else [&"graded", &"ochre"])):
		await _test_spins(v)
		await _test_double_and_pivot(v)
		await _test_close(v, &"stomp", Vector3(-0.6, 0, -2.6))
		await _test_close(v, &"rear_slam", Vector3(0, 0, -2.6))
		await _test_close(v, &"hind_stomp_right", Vector3(2.0, 0, 2.0))
		await _test_close(v, &"hind_stomp_left", Vector3(-2.0, 0, 2.0))
		await _test_close(v, &"shove_right", Vector3(1.5, 0, -1.5))
		await _test_close(v, &"shove_left", Vector3(-1.5, 0, -1.5))
		await _test_close(v, &"tackle", Vector3(0, 0, -9.5))
	if not OS.get_cmdline_user_args().has("joust"):
		await _test_anky_front_spin()
		await _test_anky_no_backin()
	await _test_anky_joust()
	root.get_node("Game").god_mode = false
	if failures.is_empty():
		print("[t_stegospin] PASS")
		quit(0)
	else:
		print("[t_stegospin] FAIL %d" % failures.size())
		quit(1)

func _spawn(id: StringName, variant: StringName = &""):
	_place(Vector3(40, 0, 40))  # out of the way: a body spawned on top of her throws her into the sky
	for i in 3:
		await physics_frame
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = Vector3.ZERO
	c.spawn(data.creature(id), variant)
	c.look_at(Vector3(0, 0, -10), Vector3.UP)  # faces -Z: +X is its right
	c.brain._roam_pause = 999.0
	_hits.clear()
	c.brain.club_hit.connect(func(mv: StringName, t: Node3D, kind: StringName) -> void:
		_hits.append([mv, t, kind, _t]))
	return c

func _provoke(c) -> void:
	var b = c.brain
	b.attack_target = player
	b._provoked_until = b._now_s() + 600.0
	b._set_state(&"approach")

func _place(p: Vector3) -> void:
	player.global_position = Vector3(p.x, 0.0, p.z)
	player.velocity = Vector3.ZERO

func _toe_world(c, bone: String) -> Variant:
	var sk: Skeleton3D = c.view.rig.skeleton
	var i := sk.find_bone(bone)
	return sk.global_transform * sk.get_bone_global_pose(i).origin if i >= 0 else null

## Planted-toe tracker: per toe, the drift (m, ground plane) inside each planted stretch (down for 5 frames or more; its
## first and last two frames are the foot settling and lifting, interpolated between 24 fps keys, so they are left out).
class ToeTrack:
	var low := {}   # bone -> lowest height seen (standing)
	var run := {}   # bone -> Array of positions of the current planted stretch
	var worst := 0.0
	var worst_at := ""
	func sample(c, bones: Array, world: Callable, on: bool, tag: String) -> void:
		for bn in bones:
			var p: Variant = world.call(c, bn)
			if p == null:
				continue
			var h: float = (p as Vector3).y - c.global_position.y
			low[bn] = minf(float(low.get(bn, h)), h)
			if on and h <= float(low[bn]) + 0.03:
				if not run.has(bn):
					run[bn] = []
				(run[bn] as Array).append(p)
			else:
				_close(bn, tag)
	func _close(bn, tag: String) -> void:
		var pts: Array = run.get(bn, [])
		run.erase(bn)
		if pts.size() < 5:
			return
		var a: Vector3 = pts[2]
		for i in range(2, pts.size() - 2):
			var q: Vector3 = pts[i]
			var d := Vector2(q.x - a.x, q.z - a.z).length()
			if d > worst:
				worst = d
				worst_at = "%s %s" % [tag, bn]

## 1. Spins: she keeps coming back to its rear (behind-left, 6 m), standing; 20 s.
func _test_spins(v: StringName) -> void:
	var c = await _spawn(&"stegosaurus", v)
	await physics_frame
	var b = c.brain
	_provoke(c)
	var toes := ToeTrack.new()
	var spins: Array = []   # |turn| of each finished spin
	var pivots := 0
	var all_moves: Array = []
	var cur := &""
	var cur_turn := 0.0
	var last_mt := 0.0
	var spin_hit := false
	var push := 0.0
	var hit_from := Vector3.ZERO
	var settle := 0
	var n_hits := 0
	var down_seen := false
	var placed := false
	_t = 0.0
	for f in 20 * 60:
		if not placed and b.move_id == &"" and not player.statuses.has(&"knockdown") and settle == 0:
			placed = true  # once, and again each time she is back up after a hit
			var back: Vector3 = c.global_basis.z  # its rear
			var left: Vector3 = -c.global_basis.x
			_place(c.global_position + (back * 0.85 + left * 0.5).normalized() * 7.5)  # past the flank stomp, in the spin's reach
		await physics_frame
		_t += DT
		player.hunt.stop()  # she stands: no retaliation walk-in
		var mid: StringName = b.move_id
		# a move ends, or a new one (the double spin) restarts the clock
		if cur != &"" and (mid != cur or b.move_t < last_mt):
			if str(cur).begins_with("spin"):
				spins.append(absf(cur_turn))
			cur = &""
		if mid != &"" and cur == &"":
			cur = mid
			all_moves.append("%s@%.1f" % [mid, _t])
			if b.pivots.has(mid):
				pivots += 1
		cur_turn = b.turn_applied if cur != &"" else 0.0
		last_mt = b.move_t
		var turning: bool = cur != &"" and b.moves[cur].has("turn_deg")
		toes.sample(c, TOES[&"stegosaurus"], _toe_world, turning, str(cur))
		if _hits.size() > n_hits:
			n_hits = _hits.size()
			var h: Array = _hits[-1]
			if str(h[0]).begins_with("spin") and h[1] == player and not spin_hit:
				spin_hit = true
				hit_from = player.global_position
				settle = 45
		if settle > 0:
			down_seen = down_seen or player.statuses.has(&"knockdown")
			settle -= 1
			if settle == 0:
				push = Vector2(player.global_position.x - hit_from.x, player.global_position.z - hit_from.z).length()
				player.statuses.clear_all()
		if n_hits > 0 and not player.statuses.has(&"knockdown") and settle == 0 and b.move_id == &"" and _hits.size() == n_hits:
			placed = false
	var big := spins.filter(func(x: float) -> bool: return x > 180.0)
	_expect(big.size() >= MIN_SPINS, "%s: %d spins past 180 deg in 20 s (all spins %s, pivots %d; moves %s)" % [v, big.size(), str(spins.map(func(x: float) -> int: return int(x))), pivots, str(all_moves)])
	_expect(spin_hit and push >= 3.0 and down_seen, "%s: a spin lands on her, knocks her %.1f m and down (%s)" % [v, push, down_seen])
	_expect(toes.worst <= TOE_SLIDE_MAX, "%s: planted toes stay put through every turn (worst %.3f m, %s)" % [v, toes.worst, toes.worst_at])
	player.statuses.clear_all()
	c.queue_free()
	await physics_frame

## 1b. Double spin and pivots: she stands behind-left in reach; during the first spin she steps in by its pivot foot (inside
## the sweep, so it misses) and stays: it spins again at once. Then she stands 14 m straight behind it: it pivots round
## (90 deg turns on a front foot) to come at her head first, planted toes holding through the pivots.
func _test_double_and_pivot(v: StringName) -> void:
	var c = await _spawn(&"stegosaurus", v)
	await physics_frame
	var b = c.brain
	_provoke(c)
	_place(c.global_transform * Vector3(-4.0, 0, 6.0))
	var starts: Array = []  # [move, t]
	var ends: Array = []
	var cur := &""
	var last_mt := 0.0
	_t = 0.0
	for f in 12 * 60:
		await physics_frame
		_t += DT
		player.hunt.stop()
		var mid: StringName = b.move_id
		if cur != &"" and (mid != cur or b.move_t < last_mt):
			ends.append([cur, _t])
			cur = &""
		if mid != &"" and cur == &"":
			cur = mid
			starts.append([mid, _t])
		last_mt = b.move_t
		if str(mid).begins_with("spin"):
			_place(c.global_transform * b._turn_pivot + (c.global_transform.basis.z * 0.0))  # by the pivot foot: inside the sweep
			player.statuses.clear_all()
		if starts.size() >= 2:
			break
	var spins := starts.filter(func(x: Array) -> bool: return str(x[0]).begins_with("spin"))
	var gap: float = float(spins[1][1]) - float(ends[0][1]) if spins.size() >= 2 and not ends.is_empty() else INF
	_expect(spins.size() >= 2 and gap <= 0.1, "%s: with her still in reach it spins again at once (%s, gap %.2f s)" % [v, str(starts), gap])
	# pivots
	while b.move_id != &"":
		await physics_frame
	var toes := ToeTrack.new()
	var pivots := 0
	var was := &""
	_place(c.global_transform * Vector3(0, 0, 14.0))
	for f in 8 * 60:
		await physics_frame
		player.hunt.stop()
		if b.move_id != was and b.pivots.has(b.move_id):
			pivots += 1
		was = b.move_id
		toes.sample(c, TOES[&"stegosaurus"], _toe_world, b.move_id != &"" and b.moves[b.move_id].has("turn_deg"), str(b.move_id))
		if absf(b.bearing_of(player.global_position)) < 30.0:
			break
	_expect(pivots >= 1 and absf(b.bearing_of(player.global_position)) < 60.0, "%s: from 14 m behind it pivots round to face her (%d pivots, bearing %.0f)" % [v, pivots, b.bearing_of(player.global_position)])
	_expect(toes.worst <= TOE_SLIDE_MAX, "%s: planted toes stay put through the pivots (worst %.3f m, %s)" % [v, toes.worst, toes.worst_at])
	player.statuses.clear_all()
	c.queue_free()
	await physics_frame

## 2-3. One close move from where she stands (body frame: +x its right, -z ahead), standing; it must land within 6 s,
## with the body neither moving nor turning (except the tackle's run) until the hit.
func _test_close(v: StringName, want: StringName, at: Vector3) -> void:
	var c = await _spawn(&"stegosaurus", v)
	await physics_frame
	var b = c.brain
	if want == &"rear_slam":
		b._front_n = 1  # the front order is stomp, rear slam: start on the slam
	_provoke(c)
	# STEGOSPIN port: she stands on the move's spot (ai.json target_bearing_deg / target_dist_m x body size: where the
	# clip puts the stomping foot or the slamming shoulder at the hit frame); `at` only for the tackle's run.
	_place(c.global_transform * at if want == &"tackle" else b.strike_spot(want))
	var from: Vector3 = player.global_position
	var start: Vector3 = c.global_position
	var yaw0: float = c.rotation.y
	var moved := 0.0
	var landed := false
	var push := Vector3.ZERO
	var started: Array = []
	var leap_from := Vector3.INF
	var leap := 0.0
	_t = 0.0
	for f in 6 * 60:
		await physics_frame
		_t += DT
		player.hunt.stop()  # she stands: no retaliation walk-in
		if b.move_id != &"" and (started.is_empty() or started[-1] != b.move_id):
			started.append(b.move_id)
		if b._leap_t >= 0.0:  # the tackle's leap: how far it carries the body
			if leap_from == Vector3.INF:
				leap_from = c.global_position
			leap = maxf(leap, Vector2(c.global_position.x - leap_from.x, c.global_position.z - leap_from.z).length())
		if b.move_id == want and want != &"tackle":
			moved = maxf(moved, (c.global_position - start).length() + absf(angle_difference(c.rotation.y, yaw0)) * 3.0)
		var hit := _hits.filter(func(h: Array) -> bool: return h[0] == want and h[1] == player)
		if not hit.is_empty():
			landed = true
			for k in 40:
				await physics_frame
				if b._leap_t >= 0.0 and leap_from != Vector3.INF:  # the leap is committed: it carries on past the hit
					leap = maxf(leap, Vector2(c.global_position.x - leap_from.x, c.global_position.z - leap_from.z).length())
			push = player.global_position - from
			break
	var side: float = c.global_basis.x.dot(push)
	_expect(landed, "%s: %s lands on her (moves %s)" % [v, want, str(started)])
	if want.begins_with("shove") or want.begins_with("hind_stomp"):
		var s := 1.0 if want.ends_with("right") else -1.0
		_expect(side * s >= 1.0, "%s: %s sends her off its %s side (%.1f m)" % [v, want, "right" if s > 0 else "left", side * s])
	if want == &"tackle":
		# owner 2026-10-31: "a jump/lunge that goes kind of far": the leap covers its lunge_m (it was a 3.5 m run).
		var need: float = float(b.close_moves[&"tackle"]["lunge_m"]) * c.size_scale() * 0.95
		_expect(leap >= need, "%s: the tackle's leap covers %.1f m (at least %.1f)" % [v, leap, need])
	if want != &"tackle":
		_expect(moved <= 0.05, "%s: %s plays on the spot (body moved/turned %.3f)" % [v, want, moved])
	player.statuses.clear_all()
	c.queue_free()
	await physics_frame

## 4. The ankylosaurus' front spin: she stands in front of its head, the next front move is the spin.
func _test_anky_front_spin() -> void:
	var c = await _spawn(&"ankylosaurus")
	await physics_frame
	var b = c.brain
	b._front_n = 3  # front order stomp, tackle, tail, spin
	_provoke(c)
	_place(Vector3(0.6, 0, -4.4))
	var toes := ToeTrack.new()
	var max_turn := 0.0
	var landed := false
	var first := &""
	_t = 0.0
	for f in 6 * 60:
		await physics_frame
		_t += DT
		player.hunt.stop()  # she stands: no retaliation walk-in
		if first == &"" and b.move_id != &"":
			first = b.move_id
		if str(b.move_id).begins_with("spin"):
			max_turn = maxf(max_turn, absf(b.turn_applied))
		toes.sample(c, TOES[&"ankylosaurus"], _toe_world, b.move_id != &"" and b.moves[b.move_id].has("turn_deg"), str(b.move_id))
		if not _hits.filter(func(h: Array) -> bool: return str(h[0]).begins_with("spin") and h[1] == player).is_empty():
			landed = true
		if landed and b.move_id == &"":
			break
	_expect(str(first).begins_with("spin"), "anky: the front move is the tail spin (%s)" % first)
	_expect(landed, "anky: the tail spin lands on her in front of it")
	_expect(max_turn > 180.0, "anky: the spin turns it %.0f deg (> 180)" % max_turn)
	_expect(toes.worst <= TOE_SLIDE_MAX, "anky: planted feet stay put through the spin (worst %.3f m, %s)" % [toes.worst, toes.worst_at])
	player.statuses.clear_all()
	c.queue_free()
	await physics_frame

## 5. No back-in: she stands 6 m behind it (past the club's reach); for 8 s it may turn and come head first, never tail first.
func _test_anky_no_backin() -> void:
	var c = await _spawn(&"ankylosaurus")
	await physics_frame
	var b = c.brain
	_provoke(c)
	_place(Vector3(0, 0, 6.0))
	var back_in := 0.0
	var faced := false
	var prev: Vector3 = c.global_position
	for f in 8 * 60:
		await physics_frame
		var to: Vector3 = player.global_position - c.global_position
		to.y = 0.0
		var step: Vector3 = c.global_position - prev
		prev = c.global_position
		if absf(b.bearing_of(player.global_position)) > 100.0 and b.move_id == &"":
			back_in += maxf(0.0, step.dot(to.normalized()))
		faced = faced or absf(b.bearing_of(player.global_position)) < 45.0
		if not _hits.is_empty():
			break
	_expect(back_in <= 0.3, "anky: never closes on her tail first (%.2f m toward her while she was behind it)" % back_in)
	_expect(faced, "anky: it turns to face her (head first)")
	player.statuses.clear_all()
	c.queue_free()
	await physics_frame

## 6. Joust from 18 m ahead: past her, round, and again; the first pass lands.
func _test_anky_joust() -> void:
	var c = await _spawn(&"ankylosaurus")
	await physics_frame
	var b = c.brain
	_provoke(c)
	var spot := Vector3(0, 0, -18.0)
	_place(spot)
	var runs := 0
	var was := &""
	var beyond := 0.0
	var hopped := 0
	var arc_seen := false
	var hit := false
	var line := Vector3(0, 0, -1)
	print("[t_stegospin] anky aggro radius %.1f m" % b.aggro_radius())
	for f in 22 * 60:
		await physics_frame
		player.hunt.stop()
		if b.joust_phase != was:
			print("[t_stegospin] joust %s -> %s at %.1f m from her, state %s" % [was, b.joust_phase, b._flat_dist(player), b.state])
		if b.joust_phase == &"run" and was != &"run":
			runs += 1
		if b.joust_phase == &"arc":
			arc_seen = true
		was = b.joust_phase
		if runs == 1:
			beyond = maxf(beyond, (c.global_position - spot).dot(line))
		if c.anim.current_clip in [&"hop_back", &"leap_back", &"pounce", &"dodge_left", &"dodge_right"]:
			hopped += 1
		if not hit and not _hits.filter(func(h: Array) -> bool: return h[0] == &"joust" and h[1] == player).is_empty():
			hit = true
		if player.statuses.has(&"knockdown") and b.joust_phase == &"":
			player.statuses.clear_all()
		if runs >= 2 and b.joust_phase == &"":
			break
	_expect(hit, "anky joust: the charge lands on her")
	_expect(beyond >= 3.0, "anky joust: it runs on past where she stood (%.1f m beyond)" % beyond)
	_expect(arc_seen and runs >= 2, "anky joust: it comes round and charges again (%d runs, arc %s)" % [runs, arc_seen])
	_expect(hopped == 0, "anky joust: no hop clip (big and heavy: %d frames)" % hopped)
	player.statuses.clear_all()
	c.queue_free()
	await physics_frame
