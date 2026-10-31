extends SceneTree
## ANKYLOCLOSE (owner 2026-10-31: "ankylosaurus is hardly fighting back. have it do a stomp attack, a shove attack, a
## tackle attack, etc. I should not be able to punch it over and over up close without consequence"). A real ankylosaurus
## (ClubTailBrain), not provoked by hand, and the survivor in GOD mode punching it from where she stands:
## 1. in front of its head: it reacts within REACT_S of her first punch that lands, lands close hits (STOMP / TACKLE)
##    from the front, at least one knocks her down, and both front moves show within the fight;
## 2. beside its shoulder (right, then left): it shoves her to that side (SHOVE, knockback away from its flank);
## 3. behind it, in the club's reach: the tail, and no back-in (STEGOSPIN).
## STEGOSPIN port (owner 2026-10-31):
## 4. "tackle should be legs moving fast, then a jump/lunge that goes kind of far": the tackle runs up, then its leap
##    carries the body at least lunge_m (x size; it was a 2.5 m run) and lands on her with a knockdown;
## 5. "rush me by turning and walking toward me but when it gets to me it rotates 180 for a massive tail whip and tail
##    smash": with her in front inside tail_radius_m it about-faces and the TAIL WHIP lands, and (planned) the TAIL SMASH;
## 7. "the shove attack on the ankylosaurus needs more range ... throw the ankys body weight at the player": with her
##    standing 5 m off its flank the SHOULDER SLAM starts, throws the body at least SLAM_CARRY_M at her and lands;
## 6. it never moves backwards toward her: while it closes on her (no move playing), its step along its own facing is
##    never negative.
## Run: Godot --headless --path game --script res://tests/t_ankyloclose.gd  -> "[t_ankyloclose] PASS", exit 0.

const ID := &"ankylosaurus"
## ASSUMPTION (owner: "within ~1 s"): from her first punch that lands to the start of its first close move.
const REACT_S := 1.0
const FIGHT_S := 10.0
## ASSUMPTION: the longest a close move's cooldown (tackle 1.8 s) plus a think and a flinch may leave her unanswered.
const IDLE_MAX_S := 2.5
const DT := 1.0 / 60.0
## ASSUMPTION: about a body length (snout to hips, ~3.5 m on an adult): how far the slam must throw the body.
const SLAM_CARRY_M := 3.0

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
		if _watch > 180.0:
			print("[t_ankyloclose] FAIL watchdog")
			quit(1)
		return false
	if root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_ankyloclose] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	root.get_node("Game").god_mode = true  # her hits and its hits land, she never dies
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	host = Node3D.new()
	host.name = "TAnkyloCloseHost"
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 80.0)
	player = kit["player"]
	for i in 10:
		await physics_frame
	await _test_front()
	await _test_side(1.0)
	await _test_side(-1.0)
	await _test_behind()
	await _test_tackle_leap()
	await _test_tail_front(0, &"attack_primary")
	await _test_tail_front(2, &"attack_heavy")
	await _test_no_backwards()
	await _test_slam_range(1.0)
	await _test_slam_range(-1.0)
	root.get_node("Game").god_mode = false
	if failures.is_empty():
		print("[t_ankyloclose] PASS")
		quit(0)
	else:
		print("[t_ankyloclose] FAIL %d" % failures.size())
		quit(1)

func _spawn():
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = Vector3.ZERO
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, 0, -10), Vector3.UP)  # faces -Z: + X is its right
	c.brain._roam_pause = 999.0  # a grazer standing where it is until she starts on it (no random wander first)
	c.brain.club_hit.connect(func(mv: StringName, t: Node3D, kind: StringName) -> void:
		_hits.append([mv, t, kind, _t]))
	return c

func _place(p: Vector3) -> void:
	player.global_position = Vector3(p.x, player.global_position.y, p.z)
	player.velocity = Vector3.ZERO

## She starts at `at` in its frame (x = its right, -z = ahead of it) and hunts it as auto-attack does, punches only (no
## auto tackle or kick: those stagger it): she walks back into reach after every knockback and punches whenever she
## can, for `secs`. Returns the moves it started (with the time), her first landed punch time, where each hit sent her,
## and the longest stretch it stood idle with her up and inside its close zone.
func _fight(c, at: Vector3, secs: float) -> Dictionary:
	_place(c.global_transform * at)
	player.sim.knock.cancel()  # KNOCKDOWN: no knockdown or throw still running from the last fight
	player.statuses.clear_all()
	_hits.clear()
	_t = 0.0
	player.hunt.start(c)
	player.hunt.auto = false
	var b = c.brain
	var out := {"starts": [], "first_punch": -1.0, "pushed": [], "idle": 0.0}
	var idle := 0.0
	var punched := [-1.0]
	c.health.damaged.connect(func(_a: float, src: Node) -> void:
		if src == player and punched[0] < 0.0:
			punched[0] = _t)
	var was := &""
	var n_hits := 0
	var hit_from := Vector3.ZERO
	var settle := 0
	for f in int(secs * 60.0):
		await physics_frame
		_t += DT
		if b.move_id != was and b.move_id != &"":
			out["starts"].append([b.move_id, _t])
		was = b.move_id
		if _hits.size() > n_hits:
			n_hits = _hits.size()
			hit_from = player.global_position
			settle = 40
		if settle > 0:
			settle -= 1
			if settle == 0:
				out["pushed"].append(player.global_position - hit_from)
		if player.hunt.target != c:
			player.hunt.start(c)
			player.hunt.auto = false
		player.hunt._auto_attack()
		var up: bool = not player.statuses.has(&"knockdown")
		idle = idle + DT if up and b.move_id == &"" and b.close_side(player) != &"" else 0.0
		out["idle"] = maxf(float(out["idle"]), idle)
	out["first_punch"] = punched[0]
	player.hunt.stop()
	player.sim.knock.cancel()  # KNOCKDOWN: no knockdown or throw still running from the last fight
	player.statuses.clear_all()
	return out

func _of(starts: Array, ids: Array) -> Array:
	return starts.filter(func(s: Array) -> bool: return s[0] in ids)

## 1. In front of its head, punching.
func _test_front() -> void:
	var c = _spawn()
	await physics_frame
	var r := await _fight(c, Vector3(0, 0, -4.2), FIGHT_S)
	var punch := float(r["first_punch"])
	_expect(punch >= 0.0, "her punches land on it from in front of its head (first at %.2f s)" % punch)
	var close: Array = _of(r["starts"], [&"stomp", &"tackle"])
	var first := float(close[0][1]) if not close.is_empty() else INF
	_expect(first - punch <= REACT_S, "it answers her first punch within %.1f s (%.2f s; moves %s)" % [REACT_S, first - punch, str(r["starts"])])
	var landed := _hits.filter(func(h: Array) -> bool: return h[1] == player and h[2] == &"close")
	_expect(landed.size() >= 2, "close hits land on her in %.0f s (%d: %s)" % [FIGHT_S, landed.size(), landed.map(func(h: Array) -> String: return "%s@%.1f" % [h[0], h[3]])])
	_expect(landed.size() >= 1 and float(landed[0][3]) <= 3.0, "the first close hit lands within 3 s (%.2f s)" % (float(landed[0][3]) if not landed.is_empty() else INF))
	var ids := landed.map(func(h: Array) -> StringName: return h[0])
	_expect(&"stomp" in ids and &"tackle" in ids, "both front moves land: stomp and tackle (%s)" % str(ids))
	# STEGOSPIN port: a tail move at her in front only ever comes out of an about-face (never a back-in).
	var st: Array = r["starts"]
	var bad := []
	for i in st.size():
		if st[i][0] in [&"whip", &"smash", &"sweep"] and (i == 0 or not str(st[i - 1][0]).begins_with("about")):
			bad.append(st[i])
	_expect(bad.is_empty(), "no tail move at a survivor in front of it but out of an about-face (%s)" % str(r["starts"]))
	_expect(float(r["idle"]) <= IDLE_MAX_S, "no long idle gap: with her up and close it stands idle at most %.2f s (limit %.1f)" % [r["idle"], IDLE_MAX_S])
	c.queue_free()
	await physics_frame

## 2. Beside its shoulder: shoved off to that side. side +1 = its right (+X).
func _test_side(side: float) -> void:
	var c = _spawn()
	await physics_frame
	var r := await _fight(c, Vector3(2.3 * side, 0, -2.0), 6.0)  # beside the shoulder, where the SHOULDER SLAM reaches
	var want := &"shove_right" if side > 0.0 else &"shove_left"
	var landed := _hits.filter(func(h: Array) -> bool: return h[1] == player and h[0] == want)
	_expect(landed.size() >= 1, "%s lands on her beside it (%d; moves %s)" % [want, landed.size(), str(r["starts"])])
	var push: Array = r["pushed"]
	_expect(not push.is_empty() and float((push[0] as Vector3).x) * side >= 1.0, "%s sends her off its flank (%s)" % [want, str(push)])
	c.queue_free()
	await physics_frame

## 3. Behind it, in the club's reach (standing still 3 m behind where it started, not punching): the tail's side, no close
## move, and it swings the tail without moving. STEGOSPIN (owner 2026-10-31: "don't have the ankylosaurus back himself into me
## for an attack"): at 4.5 m behind (past the club's reach) it used to walk backwards into her; it now never closes on her
## tail first: it pivots and comes head first (t_stegospin covers that), so this case moved in to 3 m.
func _test_behind() -> void:
	var c = _spawn()
	await physics_frame
	var b = c.brain
	b.attack_target = player
	b._provoked_until = b._now_s() + 60.0
	b._set_state(&"approach")
	var starts: Array = []
	var was := &""
	var start: Vector3 = c.global_position
	var moved := 0.0
	for f in 5 * 60:
		if b.move_id == &"" and starts.is_empty():
			_place(Vector3(0, 0, 3.0))  # she stands her ground behind where it started
		await physics_frame
		if b.move_id != was and b.move_id != &"":
			starts.append(b.move_id)
		was = b.move_id
		if starts.is_empty():
			moved = maxf(moved, (c.global_position - start).dot(Vector3(0, 0, 1)))  # toward her (she is at +z); a sidestep is fine
	_expect(starts.filter(func(m: StringName) -> bool: return b.close_moves.has(m)).is_empty() or not b.close_moves.has(starts[0]), "no close move first at a survivor behind it (%s)" % str(starts))
	_expect(not starts.is_empty() and not b.close_moves.has(starts[0]) and not b.pivots.has(starts[0]), "it swings its tail at her behind it, first (%s)" % str(starts))
	_expect(moved <= 0.3, "it does not back into her before the swing (%.2f m toward her)" % moved)
	c.queue_free()
	await physics_frame

## 4. The tackle from 6.5 m in front (past the stomp's reach): a run-up, then the leap carries it at least lunge_m.
func _test_tackle_leap() -> void:
	var c = _spawn()
	await physics_frame
	var b = c.brain
	b.attack_target = player
	b._provoked_until = b._now_s() + 60.0
	b._set_state(&"approach")
	_place(c.global_transform * Vector3(0, 0, -6.5))
	_hits.clear()
	var leap_from := Vector3.INF
	var leap := 0.0
	var started := []
	for f in 6 * 60:
		await physics_frame
		player.hunt.stop()
		if b.move_id != &"" and (started.is_empty() or started[-1] != b.move_id):
			started.append(b.move_id)
		if b._leap_t >= 0.0:
			if leap_from == Vector3.INF:
				leap_from = c.global_position
			leap = maxf(leap, Vector2(c.global_position.x - leap_from.x, c.global_position.z - leap_from.z).length())
		if leap_from != Vector3.INF and b.move_id == &"":
			break
	var need: float = float(b.close_moves[&"tackle"]["lunge_m"]) * c.size_scale() * 0.95
	_expect(leap >= need, "the tackle's leap covers %.1f m (at least %.1f; moves %s)" % [leap, need, str(started)])
	var landed := _hits.filter(func(h: Array) -> bool: return h[0] == &"tackle" and h[1] == player)
	_expect(not landed.is_empty() and player.statuses.has(&"knockdown"), "the tackle's leap lands on her and knocks her down (%d)" % landed.size())
	player.sim.knock.cancel()
	player.statuses.clear_all()
	c.queue_free()
	await physics_frame

## 5. She stands in front inside tail_radius_m and the next front move is the tail: it about-faces, then `want` lands.
## move_n picks the planned tail move (club_sequence whip, whip, smash, ...).
func _test_tail_front(move_n: int, want_clip: StringName) -> void:
	var c = _spawn()
	await physics_frame
	var b = c.brain
	b._front_n = b.front_sequence.find("tail")
	b._move_n = move_n
	b.attack_target = player
	b._provoked_until = b._now_s() + 60.0
	b._set_state(&"approach")
	_place(c.global_transform * Vector3(0.3, 0, -3.4))
	_hits.clear()
	var started := []
	var landed: Array = []
	for f in 8 * 60:
		await physics_frame
		player.hunt.stop()
		if b.move_id != &"" and (started.is_empty() or started[-1] != b.move_id):
			started.append(b.move_id)
		landed = _hits.filter(func(h: Array) -> bool: return h[1] == player and h[2] == &"club" and StringName(str(b.moves[h[0]]["clip"])) == want_clip)
		if not landed.is_empty():
			break
	_expect(not started.is_empty() and str(started[0]).begins_with("about"), "tail from the front: it about-faces first (%s)" % str(started))
	_expect(not landed.is_empty(), "tail from the front: the %s lands on her (%s)" % [want_clip, str(started)])
	player.sim.knock.cancel()
	player.statuses.clear_all()
	c.queue_free()
	await physics_frame

## 6. From 9 m behind and 7.6 m off its front right it closes on her (the joust runs count): never a step backwards
## along its own facing.
func _test_no_backwards() -> void:
	for at in [Vector3(0, 0, 9.0), Vector3(7.0, 0, -3.0)]:
		var c = _spawn()
		await physics_frame
		var b = c.brain
		b.attack_target = player
		b._provoked_until = b._now_s() + 60.0
		b._set_state(&"approach")
		_place(c.global_transform * at)
		var prev: Vector3 = c.global_position
		var prev_d: float = b._flat_dist(player)
		var worst := 0.0
		var closed := 0.0
		for f in 8 * 60:
			await physics_frame
			player.hunt.stop()
			var step: Vector3 = c.global_position - prev
			step.y = 0.0
			var d: float = b._flat_dist(player)
			if b.move_id == &"" and d < prev_d:
				var fwd: Vector3 = -c.global_basis.z
				fwd.y = 0.0
				worst = minf(worst, step.dot(fwd.normalized()) / DT)
				closed += prev_d - d
			prev = c.global_position
			prev_d = d
			if b.move_id != &"" and not b.pivots.has(b.move_id):
				break
		_expect(closed > 1.0 and worst >= -0.05, "from %s it closes %.1f m on her, never backwards (worst %.2f m/s along its facing; first move %s)" % [at, closed, worst, b.move_id])
		player.statuses.clear_all()
		c.queue_free()
		await physics_frame

## 7. The SHOULDER SLAM from range: she stands still 5 m off its flank (side +1 = its right).
func _test_slam_range(side: float) -> void:
	var c = _spawn()
	await physics_frame
	var b = c.brain
	b.attack_target = player
	b._provoked_until = b._now_s() + 60.0
	b._set_state(&"approach")
	_place(c.global_transform * Vector3(5.0 * side, 0, -1.8))
	_hits.clear()
	var want := &"shove_right" if side > 0.0 else &"shove_left"
	var from := Vector3.INF
	var carry := 0.0
	var started := []
	for f in 5 * 60:
		await physics_frame
		player.hunt.stop()
		if b.move_id != &"" and (started.is_empty() or started[-1] != b.move_id):
			started.append(b.move_id)
		if b.move_id == want:
			if from == Vector3.INF:
				from = c.global_position
			carry = maxf(carry, Vector2(c.global_position.x - from.x, c.global_position.z - from.z).length())
		elif from != Vector3.INF:
			break
	var landed := _hits.filter(func(h: Array) -> bool: return h[0] == want and h[1] == player)
	_expect(not started.is_empty() and started[0] == want, "%s starts from 5 m off its flank (%s)" % [want, str(started)])
	_expect(carry >= SLAM_CARRY_M, "%s throws its body %.1f m at her (at least %.1f)" % [want, carry, SLAM_CARRY_M])
	_expect(not landed.is_empty(), "%s lands from that range (%d)" % [want, landed.size()])
	player.sim.knock.cancel()
	player.statuses.clear_all()
	c.queue_free()
	await physics_frame
