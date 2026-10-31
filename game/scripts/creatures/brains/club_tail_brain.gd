class_name ClubTailBrain
extends CreatureBrain
## ANKYLOAI (owner 2026-10-31: "it hits too often. I want it to hit HARD ... smashing that tail around"; "keeps feet
## planted or steps in the direction for the swing"). The ankylosaurus never rushes or tackles: it shuffles at a walk
## (strafe / walk_back clips, never a run) and turns its tail toward the threat until the target stands where the next
## move's club will pass (ai.json club_tail.club_moves: target_bearing_deg / target_dist_m), then swings. While a move
## plays it neither moves nor turns in code; the clip's own steps carry the body. The hit is a sphere round the Tail5
## club, tested every physics frame of the move's strike window, so the snout is safe and behind / beside is not.
## Moves (sequence in club_moves order, CLUB SWEEP when two threats are close): TAIL WHIP (attack_primary, knockback),
## TAIL SMASH (attack_heavy, overhead slam: knockdown on the club, a shockwave round it), CLUB SWEEP (tail_swipe, a
## long arc through straight behind). Each shows a ring where the club will pass and its name for the whole wind-up.
## ANKYLOCLOSE (owner 2026-10-31: "hardly fighting back ... a stomp attack, a shove attack, a tackle attack ... I should not
## be able to punch it over and over up close without consequence"): a target in front or beside it at close range
## (ai.json club_tail.close_zone) draws a close move instead of the tail, on its own short cooldown: STOMP (a forefoot
## slammed down, an area in front, knockdown) and TACKLE (a coil, then a 2-3 m run into her, knockdown) in front, SHOVE
## (head and shoulders swung into her, knockback sideways) on her side. Behind it or out of reach, the tail as before.

signal club_hit(move: StringName, target: Node3D, kind: StringName)  ## kind: &"club", &"shock" or &"close" (stomp, shove, tackle)

## ASSUMPTION: how close to the move's spot is close enough to swing (the club sphere covers the rest).
const AIM_TOL_DEG := 18.0
const RANGE_TOL_M := 0.8
## ASSUMPTION: two threats within this many metres draw the CLUB SWEEP.
const SURROUND_M := 6.0
## ASSUMPTION: the move order while it faces one threat (owner: "tail whip, tail smash, etc").
const SEQUENCE: Array[StringName] = [&"whip", &"whip", &"smash", &"whip", &"sweep"]
## The club: Tail5's tip (Tail5_end, or this far along Tail5 when the rig has no end bone), in skeleton units.
const CLUB_ALONG := 1.0
## ASSUMPTION: the front-arc order (owner: "a stomp attack, a shove attack, a tackle attack, etc").
const FRONT_SEQUENCE: Array[StringName] = [&"stomp", &"tackle"]

var moves: Dictionary = {}
var move_id: StringName = &""
var move: Dictionary = {}
var move_t := 0.0      ## seconds into the move
var move_len := 0.0    ## the clip's length at its play speed
var last_hit_s := -999.0
var _planned: StringName = &""
var _move_n := 0
var _struck: Array[Node3D] = []
var _near: Dictionary = {}  ## target -> club distance last frame (the strike lands at the club's closest pass)
var _slammed := false
var _aim: Node3D
var telegraph: Telegraph
var close_moves: Dictionary = {}
var close_zone: Dictionary = {}
var _close_cd := 0.0
var _front_n := 0
var _lunge_left := -1.0  ## >= 0 while the tackle's run is on (metres still to go)
var _lunge_from := Vector3.ZERO
var _lunge_dir := Vector3.ZERO

func setup(c: Creature) -> void:
	super.setup(c)
	close_moves = profile.get("close_moves", {})
	close_zone = profile.get("close_zone", {})
	moves = (profile.get("club_moves", {}) as Dictionary).merged(close_moves)
	_aim = Node3D.new()
	_aim.name = "TailAim"
	add_child(_aim)  # the brain is a plain Node, so the marker's position is global

## The live club position (world), or the creature's position when it has no rig.
func club_position() -> Vector3:
	var sk: Skeleton3D = creature.view.rig.skeleton if creature.view and creature.view.rig else null
	if sk == null:
		return creature.global_position
	var end := sk.find_bone("Tail5_end")
	if end >= 0:
		return (sk.global_transform * sk.get_bone_global_pose(end)).origin
	var t5 := sk.find_bone("Tail5")
	if t5 < 0:
		return creature.global_position
	var pose := sk.get_bone_global_pose(t5)
	return sk.global_transform * (pose.origin + pose.basis.y * CLUB_ALONG * 0.08)

## Bearing of a point from the snout, degrees, + = to the right.
func bearing_of(p: Vector3) -> float:
	var to := p - creature.global_position
	to.y = 0.0
	var f := -creature.global_basis.z
	f.y = 0.0
	var r := f.cross(Vector3.UP)
	return rad_to_deg(atan2(to.dot(r), to.dot(f)))

## Where move id's club passes (world, on the ground), from the creature's current pose.
func strike_spot(id: StringName) -> Vector3:
	var mv: Dictionary = moves.get(id, {})
	var f := -creature.global_basis.z
	f.y = 0.0
	var dir := f.normalized().rotated(Vector3.UP, -deg_to_rad(float(mv.get("target_bearing_deg", 180.0))))
	return creature.global_position + dir * float(mv.get("target_dist_m", 3.0)) * _close_scale(id)

## Close moves scale with the animal (an alpha's head is further out); the club moves follow the live club.
func _close_scale(id: StringName) -> float:
	return creature.size_scale() if close_moves.has(id) else 1.0

## Where t stands round the body for a close move: &"front", &"left", &"right", or &"" (behind it or out of reach).
func close_side(t: Node3D) -> StringName:
	if close_zone.is_empty() or t == null:
		return &""
	var k := creature.size_scale()
	var to := t.global_position - creature.global_position
	var f := -creature.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var fwd := to.dot(f) / k
	var right := to.dot(f.cross(Vector3.UP)) / k
	var z := close_zone
	if fwd >= float(z.get("front_min_m", 2.4)) and fwd <= float(z.get("front_max_m", 6.0)) and absf(right) <= float(z.get("front_half_w_m", 2.0)):
		return &"front"
	if fwd >= float(z.get("side_back_m", -1.0)) and fwd <= float(z.get("side_front_m", 3.8)) and absf(right) <= float(z.get("side_max_m", 4.4)):
		return &"right" if right > 0.0 else &"left"
	return &""

## The close move for where t stands, or &"" (then the tail).
func _close_move(t: Node3D) -> StringName:
	var side := close_side(t)
	if side == &"":
		return &""
	var id: StringName = FRONT_SEQUENCE[_front_n % FRONT_SEQUENCE.size()] if side == &"front" else StringName("shove_%s" % side)
	# Out past the stomp's reach (knocked back, or stepping off): the tackle runs her down.
	var st: Dictionary = close_moves.get(&"stomp", {})
	if side == &"front" and close_moves.has(&"tackle") and _flat_dist(t) > (float(st.get("target_dist_m", 4.4)) + float(st.get("hit_radius_m", 2.0))) * creature.size_scale():
		id = &"tackle"
	return id if close_moves.has(id) else &""

func _full_rate() -> bool:
	return move_id != &""

## Turn toward the threat only while sizing it up; in a fight the tail, not the head, is aimed.
func _face_target(delta: float) -> void:
	if state == &"alert" and _valid_target():
		creature.face_towards(attack_target.global_position, delta)

func _pre_think(dt: float) -> bool:
	var handled := super._pre_think(dt)
	if move_id != &"" and (handled or not _valid_target()):
		_end_move()
	return handled

func _think(delta: float) -> void:
	_close_cd = maxf(0.0, _close_cd - delta)
	if move_id != &"":
		_tick_move(delta)
		return
	if state in [&"approach", &"hold", &"attack"]:
		_position()
		return
	strafe_face = null
	speed_override = -1.0
	super._think(delta)

func _disengage() -> void:
	strafe_face = null
	speed_override = -1.0
	super._disengage()

func _threats() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _valid_target():
		out.append(attack_target)
	for p in PlayerRegistry.all():
		if not p.dead and not out.has(p) and _flat_dist(p) <= SURROUND_M + 2.0:
			out.append(p)
	return out

func _next_move() -> StringName:
	var near := 0
	for t in _threats():
		if _flat_dist(t) <= SURROUND_M:
			near += 1
	if near >= 2 and moves.has(&"sweep"):
		return &"sweep"
	if _planned == &"":
		_planned = SEQUENCE[_move_n % SEQUENCE.size()]
	return _planned if moves.has(_planned) else StringName(moves.keys()[0])

## Shuffle (walk, strafe, walk_back) and turn until the target stands on the next move's spot, then swing.
func _position() -> void:
	if not _valid_target():
		_disengage()
		return
	if _is_herbivore() and not _provoked():
		_disengage()  # a calm grazer that was not provoked does not start a fight
		return
	_combat_memory_left = 4.0
	# Close in front or beside it: stomp, tackle or shove, on their own short cooldown (they cut an alert or a flinch).
	var close := _close_move(attack_target)
	if close != &"":
		creature.stop_move()
		strafe_face = null
		speed_override = -1.0
		_set_state(&"attack")
		# ASSUMPTION: it lets a knocked-down survivor get up before the next one (no hits on the floor).
		var down := attack_target is Player and (attack_target as Player).statuses.has(&"knockdown")
		if _close_cd <= 0.0 and not down and creature.stagger_left <= 0.0 and not creature.anim.current_clip in CreatureAnim.ATTACKS:
			_start(close)
		return
	if moves.is_empty():
		return
	var id := _next_move()
	var mv: Dictionary = moves[id]
	var to := attack_target.global_position - creature.global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		to = creature.global_basis.z
	var dist := to.length()
	var dir := to.normalized()
	var want_b := float(mv.get("target_bearing_deg", 180.0))
	var want_d := float(mv.get("target_dist_m", 3.0)) + _size_excess(attack_target)
	var err := absf(angle_difference(deg_to_rad(bearing_of(attack_target.global_position)), deg_to_rad(want_b)))
	# The heading that puts the target at want_b: the tail, not the head, turns toward it.
	_aim.global_position = creature.global_position + dir.rotated(Vector3.UP, deg_to_rad(want_b)) * 6.0
	strafe_face = _aim
	if rad_to_deg(err) <= AIM_TOL_DEG and absf(dist - want_d) <= RANGE_TOL_M:
		creature.stop_move()
		_set_state(&"attack")
		if _attack_cd <= 0.0 and not creature.anim._busy and creature.stagger_left <= 0.0:
			_start(id)
		return
	_set_state(&"hold")
	# ASSUMPTION: it shuffles at its planted-foot walk speed; it never runs at a threat.
	var walk := CreatureClips.natural_speed(creature.def, &"walk")
	speed_override = walk if walk > 0.0 else 1.0
	var spot := attack_target.global_position - dir * want_d
	if creature.global_position.distance_to(spot) < 0.5:
		# In range but not yet turned: a small sidestep, so the turn is carried by the strafe clip's steps.
		spot = creature.global_position + creature.global_basis.x * (0.8 if angle_difference(deg_to_rad(bearing_of(attack_target.global_position)), deg_to_rad(want_b)) > 0.0 else -0.8)
	creature.move_to(spot)

func _start(id: StringName) -> void:
	move_id = id
	move = moves[id]
	if not close_moves.has(id):
		_planned = &""
	move_t = 0.0
	_struck.clear()
	_near.clear()
	_slammed = false
	creature.stop_move()
	strafe_face = null
	speed_override = -1.0
	var clip := StringName(str(move.get("clip", "attack_primary")))
	creature.anim.play_clip(clip)
	var ap := creature.anim.player
	var length := ap.get_animation(clip).length if ap and ap.has_animation(clip) else 1.0
	move_len = length / maxf(0.01, creature.anim.cadence(clip))
	var strike: Array = move.get("strike", [0.5, 0.6])
	var shock := float(move.get("shock_radius_m", 0.0))
	var ring_s := float(strike[1]) * move_len + float(move.get("lunge_m", 0.0)) / maxf(0.1, float(move.get("lunge_mps", 1.0)))
	var hint := "ROLL AWAY" if close_moves.has(id) else "ROLL OR GET TO ITS HEAD"
	telegraph = Telegraph.show_club(creature, strike_spot(id), maxf(float(move.get("hit_radius_m", 1.1)), shock) * _close_scale(id),
		ring_s, "%s - %s" % [str(move.get("label", id)).to_upper(), hint])
	_log("[ai] ankylo %s (wind-up %.1fs)" % [id, float(strike[0]) * move_len])

func _tick_move(delta: float) -> void:
	move_t += delta
	if _lunge_left >= 0.0:
		_tick_lunge(delta)
		return
	creature.stop_move()  # no slide and no turn in code while the clip's feet carry the body
	var clip := StringName(str(move.get("clip", "")))
	var u := move_t / maxf(0.01, move_len)
	# (the last frames: the clip may hand back to idle a frame before move_t gets there)
	if (creature.anim.current_clip != clip and u < 0.97) or creature.health.dead:
		_end_move()  # knocked down, killed or otherwise cut off
		return
	var strike: Array = move.get("strike", [0.5, 0.6])
	if close_moves.has(move_id):
		if move.has("lunge_m"):
			if u >= 1.0:
				_start_lunge()
			return
		# impact_bone (the stomping foot): on the frame it is back down (the tree's crossfade can land it a few frames off
		# the authored fraction), else at the window's start; the window's end at the latest.
		var bone := str(move.get("impact_bone", ""))
		var down := bone == "" or _bone_height(bone) <= float(move.get("impact_height_m", 0.12))
		if not _slammed and u >= float(strike[0]) and (down or u + delta / maxf(0.01, move_len) > float(strike[1])):
			_slammed = true
			_impact()
		if u >= 1.0:
			_end_move()
		return
	if u >= float(strike[0]) and u <= float(strike[1]) + 0.0001:
		var club := club_position()
		if bool(move.get("slam", false)):
			# Impact on the frame the club comes down to the ground (or the window's end), not on a fixed fraction:
			# the tree's crossfade can land the slam a few frames off the authored timing.
			var low := club.y - creature.global_position.y <= float(move.get("slam_height_m", 0.9))
			if not _slammed and (low or u + delta / maxf(0.01, move_len) > float(strike[1])):
				_slammed = true
				_slam(club)
		else:
			var r := float(move.get("hit_radius_m", 1.1))
			var last := u + delta / maxf(0.01, move_len) > float(strike[1])
			for t in _threats():
				if _struck.has(t):
					continue
				# Land where the club passes through her: once it is inside the sphere, at its closest point (the
				# frame it starts to move away, it is well inside, or the window ends), not at the sphere's edge.
				var d := Vector2(club.x - t.global_position.x, club.z - t.global_position.z).length() - _size_excess(t)
				var was: float = _near.get(t, INF)
				_near[t] = d
				if d <= r and (d >= was or d <= r * 0.5 or last):
					_strike(t, float(move.get("damage_mult", 1.0)), float(move.get("knockback_m", 0.0)), false, &"club")
	if u >= 1.0:
		_end_move()

## Height of a bone above the animal's feet (world metres); 0 without a rig or that bone.
func _bone_height(bone: String) -> float:
	var sk: Skeleton3D = creature.view.rig.skeleton if creature.view and creature.view.rig else null
	var i := sk.find_bone(bone) if sk else -1
	return (sk.global_transform * sk.get_bone_global_pose(i).origin).y - creature.global_position.y if i >= 0 else 0.0

## STOMP / SHOVE impact: everyone in the sphere round the move's spot (body frame, at this frame) is hit once.
func _impact() -> void:
	if bool(move.get("knockdown", false)):
		IsoCamera.shake(PlayerRegistry.local(), CombatTuning.num("camera", "heavy_hit", 0.6))
	var spot := strike_spot(move_id)
	for t in _threats():
		if _in_sphere(spot, t, float(move.get("hit_radius_m", 2.0)) * _close_scale(move_id)):
			_strike(t, float(move.get("damage_mult", 1.0)), float(move.get("knockback_m", 0.0)), bool(move.get("knockdown", false)), &"close")

## TACKLE: after the coil, a run (the stride-matched gait, no glide) on a line locked now, up to lunge_m.
func _start_lunge() -> void:
	var k := _close_scale(move_id)
	_lunge_left = float(move.get("lunge_m", 2.5)) * k
	# ASSUMPTION (KNOCKDOWN merge): the stomp now slides her back as it lays her down, so the tackle runs on to her,
	# up to half again its lunge_m (it still runs its full lunge_m when she is closer).
	if _valid_target():
		_lunge_left = clampf(_flat_dist(attack_target) - float(move.get("contact_dist_m", 4.0)) * k, _lunge_left, _lunge_left * 1.5)
	_lunge_from = creature.global_position
	var f := -creature.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var to := attack_target.global_position - creature.global_position if _valid_target() else f
	to.y = 0.0
	# ASSUMPTION: it runs at her when she is within 45 deg of its snout, else straight ahead.
	_lunge_dir = to.normalized() if to.length() > 0.1 and f.dot(to.normalized()) > cos(deg_to_rad(45.0)) else f

func _tick_lunge(_delta: float) -> void:
	var k := _close_scale(move_id)
	speed_override = float(move.get("lunge_mps", 5.0))
	creature.move_to(_lunge_from + _lunge_dir * (_lunge_left + 2.0))  # aim past the end: no slowing into her
	var f := -creature.global_basis.z
	f.y = 0.0
	var at := creature.global_position + f.normalized() * float(move.get("contact_dist_m", 4.0)) * k
	var hit := false
	for t in _threats():
		if not _struck.has(t) and _in_sphere(at, t, float(move.get("contact_radius_m", 1.3)) * k):
			IsoCamera.shake(PlayerRegistry.local(), CombatTuning.num("camera", "heavy_hit", 0.6))
			_strike(t, float(move.get("damage_mult", 1.0)), float(move.get("knockback_m", 0.0)), bool(move.get("knockdown", false)), &"close")
			hit = true
	var ran := Vector2(creature.global_position.x - _lunge_from.x, creature.global_position.z - _lunge_from.z).length()
	var limit_s := _lunge_left / k / maxf(0.1, float(move.get("lunge_mps", 5.0))) + 0.8
	if hit or ran >= _lunge_left or move_t - move_len > limit_s or creature.health.dead:
		creature.stop_move()
		_end_move()

func _in_sphere(club: Vector3, t: Node3D, radius: float) -> bool:
	return Vector2(club.x - t.global_position.x, club.z - t.global_position.z).length() <= radius + _size_excess(t)

## TAIL SMASH impact: the club's own sphere knocks down for full damage, the shockwave round it hits lighter.
func _slam(club: Vector3) -> void:
	IsoCamera.shake(PlayerRegistry.local(), CombatTuning.num("camera", "heavy_hit", 0.6))
	for t in _threats():
		if _in_sphere(club, t, float(move.get("hit_radius_m", 1.1))):
			_strike(t, float(move.get("damage_mult", 1.0)), float(move.get("knockback_m", 0.0)), bool(move.get("knockdown", false)), &"club")
		elif _in_sphere(club, t, float(move.get("shock_radius_m", 0.0))):
			_strike(t, float(move.get("shock_mult", 0.3)), float(move.get("shock_knockback_m", 0.0)), false, &"shock")

func _strike(t: Node3D, mult: float, knock_m: float, knockdown: bool, kind: StringName) -> void:
	_struck.append(t)  # one strike per target per move, landed or dodged
	if t is Player and (t as Player).dead:
		return
	var clip := StringName(str(move.get("clip", "attack_primary")))
	# CreatureAttack: a roll inside its opening window (or out of a live ring) dodges outright, before any damage.
	if not CreatureAttack.apply_for(creature, clip, t, mult):
		return
	last_hit_s = _now_s()
	club_hit.emit(move_id, t, kind)
	var away := t.global_position - creature.global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else -creature.global_basis.z
	if t is Player:
		var pl := t as Player
		pl.receive_creature_hit(creature, clip)
		if knockdown:
			pl.statuses.apply(&"knockdown", creature, 1)
		if knock_m > 0.0 and pl.sim:
			pl.sim.shove(away * knock_m, 0.6)
	elif t is Creature and knockdown:
		(t as Creature).statuses.apply(&"knockdown", creature, 1)
		(t as Creature).anim.play_clip(&"knockdown")

func _end_move() -> void:
	if move_id == &"":
		return
	if close_moves.has(move_id):
		_close_cd = float(move.get("cooldown_s", 1.2)) * _rage_cd()
		if move_id in FRONT_SEQUENCE:
			_front_n += 1
		_lunge_left = -1.0
		speed_override = -1.0
	else:
		_attack_cd = float(move.get("cooldown_s", 4.0)) * _rage_cd()
		_move_n += 1
	move_id = &""
	if is_instance_valid(telegraph):
		telegraph.queue_free()
	telegraph = null

## Hit from close in front or beside it: no look-around first (the alert pause), it answers at once.
func on_aggro(who: Node) -> void:
	super.on_aggro(who)
	if state == &"alert" and who == attack_target and _provoked() and _close_move(attack_target) != &"":
		_set_state(&"approach")

func opening_label() -> String:
	if move_id == &"":
		return ""
	var strike: Array = move.get("strike", [0.5, 0.6])
	return "%s %.1fs" % [str(move.get("label", move_id)), maxf(0.0, float(strike[0]) * move_len - move_t)]

func on_player_killed(at: Vector3) -> void:
	_end_move()
	super.on_player_killed(at)

func _exit_tree() -> void:
	if is_instance_valid(telegraph):
		telegraph.queue_free()
