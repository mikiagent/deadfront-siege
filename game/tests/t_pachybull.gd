extends SceneTree
## PACHYBULL (owner 2026-10-31, fight lab: "Pachy is teleporting or something, not sure why. its actually kind of a
## success. instead of it walking back slowly, have it jump backwards and wind up like a bull, huff huff, and then
## charge") and PACHYFEEL (owner, same day: "pachy behavior is really good, just give it more backstep charges and make
## some charges go really far and some go shorter depending on the wind up", "make it less passive aggressive", "might
## have a walking backwards bug hard to tell"). Two fights in a lab world with a baked navmesh, the survivor in GOD mode.
## 1. She stands still; the pachycephalosaurus charges until each windup tier has run CHARGES_PER_TIER charges:
##   - no physics frame moves its body, or its hips within the body, more than its top speed (run x the fastest tier's
##     charge_speed_mult) x dt x 3 (the teleport was the survivor's kick moving it 3.46 m in one frame);
##   - every charge after the first comes out of the bull reset: hop_back, then the windup (display), then the charge;
##     every hop plays hop_back and every windup one of the bull_windup tier clips; walk_back never plays;
##   - a long windup's charge runs more than TIER_GAP_M farther than a short one's (mean of each).
## 2. She fights back (Hunt with Auto and Auto-ability on, as the fight lab's auto-attack does) for FIGHT_S:
##   - at least BACKSTEP_FLOOR of its charges are backstep charges (a hop back, then the windup, then the charge);
##   - the mean gap between its attack starts is under OLD_MEAN_GAP_S, the value measured before PACHYFEEL, and it
##     never stands down mid-fight.
## In both, every frame it moves (> 0.5 m/s, not shoved): a forward clip (walk, run, charge) means its velocity points
## ahead of its facing, a back clip (walk_back, hop_back, leap_back) behind it (the moonwalk check).
## Run: Godot --headless --path game --script res://tests/t_pachybull.gd  -> "[t_pachybull] PASS", exit 0.

const CHARGES_PER_TIER := 3
const MAX_S := 120.0
const FIGHT_S := 60.0
## ASSUMPTION (PACHYFEEL gates): before the change, the same 60 s fight measured a mean gap of 4.84 s between attack
## starts and 83 % backstep charges, with five hop_back frames moving forward (canon 30e08c30).
const OLD_MEAN_GAP_S := 4.84
const BACKSTEP_FLOOR := 0.85
const TIER_GAP_M := 5.0
const FWD: Array[StringName] = [&"walk", &"lope", &"run", &"sprint", &"charge"]
const BACK: Array[StringName] = [&"walk_back", &"hop_back", &"leap_back"]
const STARTS: Array[StringName] = [&"charge", &"kick", &"heavy", &"bite", &"lunge", &"combo"]

var failures: Array[String] = []
var _started := false
var player: Node3D
var host: Node3D

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
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261031
	Engine.max_physics_steps_per_frame = 1000
	var game := root.get_node("Game")
	game.debug_overlay = false
	game.god_mode = true
	host = Node3D.new()
	root.add_child(host)
	var LK = load("res://scripts/dev/lab_kit.gd")
	player = LK.build(host, 120.0)["player"]
	LK.bake(host)
	for i in 10:
		await physics_frame
	await _standing()
	await _fighting()
	if failures.is_empty():
		print("[t_pachybull] PASS")
		quit(0)
	else:
		print("[t_pachybull] FAIL %d" % failures.size())
		quit(1)

func _spawn() -> Node3D:
	player.global_position = Vector3(0, player.global_position.y, 0)
	player.velocity = Vector3.ZERO
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = Vector3(0, 0, -8)  # before add_child: added at the origin it would carry her off as a platform
	host.add_child(c)
	c.spawn(root.get_node("Data").creature(&"pachycephalosaurus"), &"", 0, null, 0, &"aggressive")
	return c

## The moonwalk check for one frame's motion v: true = the clip disagrees with the travel. The clip at the start and at
## the end of the frame must both disagree (the frame a brain swaps the clip, the body still carries the last step).
static func moonwalk(clip: StringName, prev_clip: StringName, v: Vector3, basis: Basis) -> bool:
	if Vector2(v.x, v.z).length() <= 0.5:
		return false
	var cosv := Vector3(v.x, 0.0, v.z).normalized().dot(-basis.z)
	var bad := func(k: StringName) -> bool: return (k in FWD and cosv < -0.2) or (k in BACK and cosv > 0.2)
	return bad.call(clip) and bad.call(prev_clip)

func _tier_clips() -> Array[StringName]:
	var out: Array[StringName] = []
	for row in (root.get_node("Data").creature_ai.get("bull_windup", {}) as Dictionary).get("tiers", []):
		out.append(StringName(str(row["clip"])))
	return out

func _standing() -> void:
	var c = _spawn()
	await physics_frame
	await physics_frame
	var tiers := _tier_clips()
	var have := tiers.all(func(k: StringName) -> bool: return c.anim.has_state(k))
	_expect(c.anim.has_state(&"hop_back") and have and tiers.size() >= 2, "the rig has hop_back and the windup tiers %s" % str(tiers))
	_expect(str(c.brain.tac.get("charge_reset", "")) == "bull" and str(c.brain.tac.get("backoff", "")) == "leap", "species tactics: bull reset after a charge, leap back-offs (no scurry)")
	c.brain.on_aggro(player)
	var log: Array[StringName] = []
	c.brain.tactic.connect(func(k: StringName) -> void:
		if k in [&"charge", &"hop", &"display"]:
			log.append(k))
	var sk: Skeleton3D = c.view.find_children("*", "Skeleton3D", true, false)[0]
	var hips := sk.find_bone("Hips")
	var hz := float(Engine.physics_ticks_per_second)
	var fastest := float(c.brain.tac.get("charge_speed_mult", 1.5))
	for row in (root.get_node("Data").creature_ai.get("bull_windup", {}) as Dictionary).get("tiers", []):
		fastest = maxf(fastest, float(row.get("charge_speed_mult", 1.5)))
	var top: float = c.move_speed_mps() * c.run_speed_mult() * fastest
	var lim := top / hz * 3.0
	var worst := 0.0
	var worst_at := ""
	var prev: Vector3 = c.global_position
	var prevh: Vector3 = c.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(hips)).origin
	var prev_clip: StringName = c.anim.current_clip
	var walk_back := 0
	var moon: Array[String] = []
	var hop_clip_ok := true
	var windup_ok := true
	var windup := &""
	var from := Vector3.INF
	var dist := {}  # tier clip -> [charge distances]
	for k in tiers:
		dist[k] = []
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
		var clip: StringName = c.anim.current_clip
		if c.stagger_left <= 0.0 and moonwalk(clip, prev_clip, (pos - prev) * hz, c.global_basis) and moon.size() < 8:
			moon.append("f%d %s/%s" % [f, c.brain.state, clip])
		prev = pos
		prevh = h
		prev_clip = clip
		var st: StringName = c.brain.state
		charging = charging or st == &"charge"
		if charging and clip == &"walk_back":
			walk_back += 1
		if st == &"hop" and not c.brain._hop_turn and c.brain._j_t > 0.05 and clip != &"hop_back":
			hop_clip_ok = false
		if st == &"display" and c.brain._left > 0.02:  # the clip's last frame may hand back to idle as the timer runs out
			windup_ok = windup_ok and clip in tiers
			windup = clip
		if st == &"charge" and from == Vector3.INF:
			from = pos
		elif st != &"charge" and from != Vector3.INF:
			if windup in dist:
				(dist[windup] as Array).append(Vector2(pos.x - from.x, pos.z - from.z).length())
			from = Vector3.INF
			windup = &""
		if tiers.all(func(k: StringName) -> bool: return (dist[k] as Array).size() >= CHARGES_PER_TIER):
			break
	_expect(worst <= lim, "no teleport: worst frame step %.2f m <= %.2f m (top %.1f m/s x dt x 3) at %s" % [worst, lim, top, worst_at])
	# From the first charge on, every charge comes out of the bull reset: hop, display, charge.
	var first := log.find(&"charge")
	var reset_ok := first >= 0
	for i in range(first + 1, log.size()):
		if log[i] == &"charge":
			reset_ok = reset_ok and i >= 2 and log[i - 1] == &"display" and log[i - 2] == &"hop"
	_expect(reset_ok and log.count(&"charge") > tiers.size(), "every charge after the first is hop_back -> windup -> charge (%s)" % str(log.slice(maxi(0, first))))
	_expect(walk_back == 0, "no walk-back once the charges start (%d frames)" % walk_back)
	_expect(hop_clip_ok, "every hop plays hop_back")
	_expect(windup_ok, "every windup plays a bull_windup tier clip")
	_expect(moon.is_empty(), "standing: no frame moves against its clip (%s)" % str(moon))
	var mean := {}
	for k in tiers:
		var a: Array = dist[k]
		mean[k] = a.reduce(func(s: float, x: float) -> float: return s + x, 0.0) / maxf(1, a.size())
		print("[t_pachybull]   %s (%.2f s windup): charges %s, mean %.1f m" % [k, c.brain._clip_len(k, 0.0), str(a.map(func(x): return snappedf(x, 0.1))), mean[k]])
	var short: StringName = tiers[0]
	var long: StringName = tiers[-1]
	_expect(c.brain._clip_len(long, 0.0) > c.brain._clip_len(short, 0.0) * 2.0, "the long windup is over twice the short one (%.2f s vs %.2f s)" % [c.brain._clip_len(long, 0.0), c.brain._clip_len(short, 0.0)])
	_expect((dist[short] as Array).size() >= CHARGES_PER_TIER and (dist[long] as Array).size() >= CHARGES_PER_TIER and float(mean[long]) - float(mean[short]) > TIER_GAP_M,
		"a long windup's charge runs > %.0f m farther than a short one's (%.1f m vs %.1f m)" % [TIER_GAP_M, mean[long], mean[short]])
	c.queue_free()
	for i in 5:
		await physics_frame

func _fighting() -> void:
	var c = _spawn()
	await physics_frame
	c.brain.on_aggro(player)
	player.hunt.auto = true
	player.hunt.auto_ability = true
	player.hunt.start(c)
	var t := [0.0]
	var log: Array = []
	c.brain.tactic.connect(func(k: StringName) -> void: log.append([t[0], k]))
	var hz := float(Engine.physics_ticks_per_second)
	var prev: Vector3 = c.global_position
	var prev_clip: StringName = c.anim.current_clip
	var moon: Array[String] = []
	while t[0] < FIGHT_S:
		await physics_frame
		t[0] += 1.0 / hz
		c.health.hp = c.health.max_hp  # held at full: no capture knockdown, no flight
		player.vitals.health = player.vitals.effective_max_health()
		if player.hunt.target != c:
			player.hunt.start(c)
		var pos: Vector3 = c.global_position
		var clip: StringName = c.anim.current_clip
		if c.stagger_left <= 0.0 and moonwalk(clip, prev_clip, (pos - prev) * hz, c.global_basis) and moon.size() < 8:
			moon.append("t=%.2f %s/%s" % [t[0], c.brain.state, clip])
		prev = pos
		prev_clip = clip
	player.hunt.stop()
	var starts: Array = []
	var charges := 0
	var backstep := 0
	for i in log.size():
		var k: StringName = log[i][1]
		if k in STARTS:
			starts.append(log[i][0])
		if k == &"charge":
			charges += 1
			if i >= 2 and log[i - 1][1] == &"display" and log[i - 2][1] == &"hop":
				backstep += 1
	var gap := 0.0
	for i in range(1, starts.size()):
		gap += (starts[i] - starts[i - 1]) / float(starts.size() - 1)
	var share := float(backstep) / maxf(1.0, charges)
	print("[t_pachybull]   fight %.0f s: attack starts %d, charges %d, backstep charges %d" % [FIGHT_S, starts.size(), charges, backstep])
	_expect(share >= BACKSTEP_FLOOR, "fight: backstep charges %.0f %% >= %.0f %%" % [100.0 * share, 100.0 * BACKSTEP_FLOOR])
	_expect(starts.size() >= 4 and gap < OLD_MEAN_GAP_S, "fight: mean gap between attack starts %.2f s < %.2f s (before PACHYFEEL)" % [gap, OLD_MEAN_GAP_S])
	_expect(not log.any(func(e) -> bool: return e[1] == &"stand_down"), "fight: it never stands down while she fights it")
	_expect(moon.is_empty(), "fight: no frame moves against its clip (%s)" % str(moon))
	c.queue_free()
