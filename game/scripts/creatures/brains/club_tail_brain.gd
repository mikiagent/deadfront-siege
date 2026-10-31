class_name ClubTailBrain
extends CreatureBrain
## ANKYLOAI (owner 2026-10-31: "it hits too often. I want it to hit HARD ... smashing that tail around"; "keeps feet
## planted or steps in the direction for the swing"). The ankylosaurus turns its tail toward the threat until the target
## stands where the next move's club will pass (ai.json club_tail.club_moves: target_bearing_deg / target_dist_m), then
## swings. While a move plays it neither moves nor turns in code; the clip's own steps carry the body (a TURN move is the
## one exception, below). The hit is a sphere round the club (or, with line_bone, the rear body and tail as a line from
## that bone to the club), tested every physics frame of the move's strike window, so the snout is safe.
## HITBOXES: the club is the Tail5_end part of data/creatures/hitboxes.json (its radius), swept from last frame to
## this one against the target's hurtboxes (Hitbox.touch); it must have touched her body before the closest-pass
## timing below lands it (a line_bone move judges the rear body and tail line on the ground plane, as before).
## Moves (club_sequence order, CLUB SWEEP when two threats are close): TAIL WHIP (attack_primary, knockback),
## TAIL SMASH (attack_heavy, overhead slam: knockdown on the club, a shockwave round it), CLUB SWEEP (tail_swipe, a
## long arc through straight behind). Each shows a ring where the club will pass and its name for the whole wind-up.
## ANKYLOCLOSE (owner 2026-10-31: "hardly fighting back ... a stomp attack, a shove attack, a tackle attack ... I should not
## be able to punch it over and over up close without consequence"): a target in front or beside it at close range
## (close_zone) draws a close move instead of the tail, on its own short cooldown: STOMP and TACKLE in front, SHOVE on her
## side; with close_zone.flank_back_m, a HIND STOMP beside the hips.
## STEGOSPIN (owner 2026-10-31: "Stego needs a stronger twist attack, tackle attack, etc. it should be spinning a lot, anky
## and stego are similar" / "also needs stomp attacks"; "don't have the ankylosaurus back himself into me for an attack,
## he should also joust and be able to hit you with his tail from the front by spinning"): the stegosaurus runs this brain
## too (ai.json spiked_tail). TURN moves (turn_deg, turn [a, b], pivot_gltf): TAIL SPIN and the 90 deg PIVOT turn the
## animal in code about a planted front foot, in step with the clip (the clip keys the motion counter-rotated, so the
## feet stay planted in the world; tools/gait/make_stego_moves.py, make_tail_club.py). A spin repeats once at once while
## she stays in reach. It never walks backwards into her to bring the tail round: out of reach it pivots and comes head
## first, and with a joust profile (the ankylosaurus) it charges past her from far off, arcs round and charges again.
## STEGOSPIN port (owner 2026-10-31): TACKLE is a run-up at the run gait, then a leap (leap_clip) that carries the body
## lunge_m, landing through the leap's hitbox parts. The ankylosaurus RUSHES in head first at the run gait (rush_min_m),
## and a front_sequence "tail" entry ABOUT-FACES (about_left / about_right, a 180 deg turn on the spot about a point just
## ahead of its origin, every foot stepping round it) when she is inside tail_radius_m, so the tail moves take her
## behind it as usual: "it just rotates to hit me".

signal club_hit(move: StringName, target: Node3D, kind: StringName)  ## kind: &"club", &"shock", &"close" or &"joust"

## ASSUMPTION: how close to the move's spot is close enough to swing (the club sphere covers the rest); per move
## aim_tol_deg / range_tol_m override.
const AIM_TOL_DEG := 18.0
const RANGE_TOL_M := 0.8
## The sidestep goal while it lines its tail up: past the nav agent's arrival distance (creature.gd target_desired_distance).
const SIDESTEP_M := 2.0
## ASSUMPTION: two threats within this many metres draw the CLUB SWEEP.
const SURROUND_M := 6.0
## ASSUMPTION: the move order while it faces one threat (owner: "tail whip, tail smash, etc"); profile club_sequence overrides.
const SEQUENCE: Array[StringName] = [&"whip", &"whip", &"smash", &"whip", &"sweep"]
## The club: Tail5's tip (Tail5_end, or this far along Tail5 when the rig has no end bone), in skeleton units.
const CLUB_ALONG := 1.0
## ASSUMPTION: the front-arc order (owner: "a stomp attack, a shove attack, a tackle attack, etc"); profile front_sequence overrides.
const FRONT_SEQUENCE: Array[StringName] = [&"stomp", &"tackle"]
## Stepping clips: a move never starts out of one. Their feet are mid-stride, and the cross-fade into a move keyed from
## the idle stance would slide the planted feet (STEGOSPIN port: 0.2 m toe slide at a spin's start out of the walk).
const STEPPING: Array[StringName] = [&"walk", &"lope", &"run", &"sprint", &"strafe_left", &"strafe_right", &"walk_back"]

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
var _club_prev := Vector3.ZERO
var _touched: Dictionary = {}  ## target -> the hurtbox the club touched this move (Hitbox.touch result)
var _aim: Node3D
var telegraph: Telegraph
var close_moves: Dictionary = {}
var close_zone: Dictionary = {}
var club_sequence: Array = []
var front_sequence: Array = []
var pivots: Dictionary = {}
var joust: Dictionary = {}
var _close_cd := 0.0
var _pivot_cd := 0.0
var _front_n := 0
var _lunge_left := -1.0  ## >= 0 while the tackle's run is on (metres still to go)
var _lunge_from := Vector3.ZERO
var _lunge_dir := Vector3.ZERO
var _leap_t := -1.0  ## >= 0 while the tackle's leap plays (seconds into it)
var _leap_len := 1.0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _leap_air := Vector2(0.0, 1.0)
var _leap_clip: StringName = &""
var _part_prev: Array = []  ## the leap's hit parts' world positions last frame
## TURN moves: the turn put on the view so far (deg, + = left), about _turn_pivot (body-local).
var _turn_on := false
var turn_applied := 0.0
var _turn_pivot := Vector3.ZERO
var _body_base := Transform3D.IDENTITY  ## the body's transform when the turn began
var _clip_length := 1.0
var _spun := 0  ## spins in the current chain (a spin repeats once while she stays in reach)
var _still_t := 0.0  ## seconds since the last stepping clip: a move starts once its stance has blended in
## JOUST: &"run" (a straight charge past her) or &"arc" (swinging round to face her again), &"" when off.
var joust_phase: StringName = &""
var _joust_cd := 0.0
var _joust_passes := 0
var _joust_t := 0.0
var _joust_from := Vector3.ZERO
var _joust_dir := Vector3.ZERO
var _joust_len := 0.0
var _joust_hit: Array[Node3D] = []
var _joust_best := 0.0  ## furthest along the run so far, and when it last got further (a run blocked by a body ends)
var _joust_best_t := 0.0

func setup(c: Creature) -> void:
	super.setup(c)
	close_moves = profile.get("close_moves", {})
	close_zone = profile.get("close_zone", {})
	club_sequence = profile.get("club_sequence", SEQUENCE)
	front_sequence = profile.get("front_sequence", FRONT_SEQUENCE)
	pivots = profile.get("pivots", {})
	joust = profile.get("joust", {})
	moves = (profile.get("club_moves", {}) as Dictionary).merged(close_moves).merged(pivots)
	_aim = Node3D.new()
	_aim.name = "TailAim"
	add_child(_aim)  # the brain is a plain Node, so the marker's position is global
	if creature.anim and creature.anim.tree:
		creature.anim.tree.mixer_applied.connect(_on_pose_applied)  # after CreatureAnim's own (it set _os_t first)

func _skeleton() -> Skeleton3D:
	return creature.view.rig.skeleton if creature.view and creature.view.rig else null

## A bone's head in the world, or null.
func _bone_world(bone: String) -> Variant:
	var sk := _skeleton()
	var i := sk.find_bone(bone) if sk else -1
	return sk.global_transform * sk.get_bone_global_pose(i).origin if i >= 0 else null

## The live club position (world), or the creature's position when it has no rig.
func club_position() -> Vector3:
	var sk := _skeleton()
	if sk == null:
		return creature.global_position
	var bone := str(profile.get("club_bone", ""))
	if bone != "":
		var bi := sk.find_bone(bone)
		if bi >= 0:
			var p := sk.get_bone_global_pose(bi)
			return sk.global_transform * (p.origin + p.basis.y.normalized() * float(profile.get("club_along_m", 0.0)))
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

## Where t stands round the body for a close move: &"front", &"left", &"right", &"flank_left", &"flank_right" (beside
## the hips, with close_zone.flank_back_m) or &"" (behind it or out of reach).
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
	if absf(right) > float(z.get("side_max_m", 4.4)) or fwd > float(z.get("side_front_m", 3.8)):
		return &""
	var side := &"right" if right > 0.0 else &"left"
	if fwd >= float(z.get("side_back_m", -1.0)):
		return side
	if z.has("flank_back_m") and fwd >= float(z["flank_back_m"]):
		return StringName("flank_" + side)
	return &""

## A sequence entry to a move id: &"spin" picks the spin whose tail swings round to her side first.
func _resolve(id: StringName, t: Node3D) -> StringName:
	if id == &"tail":  # ABOUT-FACE, then the tail moves take her behind it
		return &"about_left" if bearing_of(t.global_position) < 0.0 else &"about_right"
	if id != &"spin":
		return id
	return &"spin_right" if bearing_of(t.global_position) < 0.0 else &"spin_left"

func _front_entry() -> StringName:
	return StringName(front_sequence[_front_n % front_sequence.size()])

## The close move for where t stands, or &"" (then the tail).
func _close_move(t: Node3D) -> StringName:
	var side := close_side(t)
	if side == &"":
		return &""
	var id: StringName
	if side == &"front":
		id = _resolve(_front_entry(), t)
		# Out past the stomp's reach (knocked back, or stepping off): the tackle runs her down.
		var st: Dictionary = close_moves.get(&"stomp", {})
		if close_moves.has(&"tackle") and _flat_dist(t) > (float(st.get("target_dist_m", 4.4)) + float(st.get("hit_radius_m", 2.0))) * creature.size_scale():
			id = &"tackle"
		# ASSUMPTION (tail_radius_m): past the tail's reach once it has turned, the about-face would whiff: the tackle.
		elif str(id).begins_with("about") and _flat_dist(t) > float(close_zone.get("tail_radius_m", 4.6)) * creature.size_scale():
			id = &"tackle" if close_moves.has(&"tackle") else &"stomp"
	elif str(side).begins_with("flank_"):
		id = StringName("hind_stomp_" + str(side).trim_prefix("flank_"))
	else:
		id = StringName("shove_%s" % side)
	return id if moves.has(id) else &""

func _full_rate() -> bool:
	return move_id != &"" or joust_phase != &""

## Turn toward the threat only while sizing it up; in a fight the tail, not the head, is aimed.
func _face_target(delta: float) -> void:
	if state == &"alert" and _valid_target():
		creature.face_towards(attack_target.global_position, delta)

func _pre_think(dt: float) -> bool:
	var handled := super._pre_think(dt)
	if handled or not _valid_target():
		if move_id != &"":
			_end_move()
		if joust_phase != &"":
			_end_joust()
	return handled

func _think(delta: float) -> void:
	_still_t = 0.0 if creature.anim.current_clip in STEPPING else _still_t + delta
	_close_cd = maxf(0.0, _close_cd - delta)
	_pivot_cd = maxf(0.0, _pivot_cd - delta)
	_joust_cd = maxf(0.0, _joust_cd - delta)
	if move_id != &"":
		_tick_move(delta)
		return
	if joust_phase != &"":
		_tick_joust(delta)
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
		_planned = StringName(club_sequence[_move_n % club_sequence.size()])
	var id := _resolve(_planned, attack_target)
	return id if moves.has(id) else StringName((profile.get("club_moves", {}) as Dictionary).keys()[0])

## Close in front or beside it: a close move. Else the tail: in reach and aimed, it swings; in reach but badly aimed, it
## pivots (or sidesteps) on the spot; out of reach, it comes head first (or jousts from far off). It never walks
## backwards into her to bring the tail round (owner 2026-10-31).
func _position() -> void:
	if not _valid_target():
		_disengage()
		return
	if _is_herbivore() and not _provoked():
		_disengage()  # a calm grazer that was not provoked does not start a fight
		return
	_combat_memory_left = 4.0
	var close := _close_move(attack_target)
	if close != &"":
		creature.stop_move()
		strafe_face = null
		speed_override = -1.0
		_set_state(&"attack")
		# ASSUMPTION: it lets a knocked-down survivor get up before the next one (no hits on the floor).
		if _close_cd <= 0.0 and not _target_down() and creature.stagger_left <= 0.0 and not creature.anim.current_clip in CreatureAnim.ATTACKS:
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
	var b := bearing_of(attack_target.global_position)
	var want_b := float(mv.get("target_bearing_deg", 180.0))
	var want_d := float(mv.get("target_dist_m", 3.0)) + _size_excess(attack_target)
	var delta_deg := rad_to_deg(angle_difference(deg_to_rad(b), deg_to_rad(want_b)))
	if dist <= want_d + float(mv.get("range_tol_m", RANGE_TOL_M)):
		# In reach (closer is fine: nothing walks back into her).
		if _aimed(mv, b):
			creature.stop_move()
			strafe_face = null
			speed_override = -1.0
			_set_state(&"attack")
			if _attack_cd <= 0.0 and not creature.anim._busy and creature.stagger_left <= 0.0:
				_start(id)
			return
		_set_state(&"hold")
		if _try_pivot(delta_deg):
			return
		# A sidestep, so the turn is carried by the strafe clip's steps (never toward her). ANKYLOOPEN (owner 2026-10-31:
		# "gets stuck in hold/idle animation when the player initially attacks"): the goal was 0.8 m off, inside the nav
		# agent's 0.9 m arrival distance, so it never stepped and so never turned: it stood in hold. The goal is re-set
		# every think and it stops as soon as it is lined up, so a goal well past the arrival distance only keeps it moving.
		_aim.global_position = creature.global_position + dir.rotated(Vector3.UP, deg_to_rad(want_b)) * 6.0
		strafe_face = _aim
		var step_walk := CreatureClips.natural_speed(creature.def, &"walk")
		speed_override = step_walk if step_walk > 0.0 else 1.0
		creature.move_to(creature.global_position + creature.global_basis.x * (SIDESTEP_M if delta_deg > 0.0 else -SIDESTEP_M))
		return
	# Out of reach: from far off, the joust; else turn head first to her (pivot) and walk in, so the front moves take over.
	_set_state(&"approach")
	if _try_joust(dist, b):
		return
	if absf(b) > 100.0 and _try_pivot(-b):
		return
	strafe_face = null
	var walk := CreatureClips.natural_speed(creature.def, &"walk")
	speed_override = walk if walk > 0.0 else 1.0
	# RUSH (owner 2026-10-31: "try to rush me by turning and walking toward me"): head first at the run gait while far.
	var run := CreatureClips.natural_speed(creature.def, &"run")
	if profile.has("rush_min_m") and run > 0.0 and dist > float(profile["rush_min_m"]) * creature.size_scale():
		speed_override = run
	creature.move_to(attack_target.global_position)

## Lined up for mv with her at bearing b: within aim_tol_deg of its target bearing, or, for a club that sweeps an arc
## through straight behind (sweep_arc_deg [from, to]: the arc's ends a little inside where the club passes, e.g. the whip
## from behind its left round to its right flank), anywhere on that arc.
func _aimed(mv: Dictionary, b: float) -> bool:
	if mv.get("sweep_arc_deg") is Array:
		var arc: Array = mv["sweep_arc_deg"]
		if b <= float(arc[0]) or b >= float(arc[1]):
			return true
	return absf(rad_to_deg(angle_difference(deg_to_rad(b), deg_to_rad(float(mv.get("target_bearing_deg", 180.0)))))) <= float(mv.get("aim_tol_deg", AIM_TOL_DEG))

func _target_down() -> bool:
	return attack_target is Player and (attack_target as Player).statuses.has(&"knockdown")

## A 90 deg PIVOT toward closing delta_deg (+ = the body turns left), when the rig has one; true when it started (or waits).
func _try_pivot(delta_deg: float) -> bool:
	if pivots.is_empty() or _pivot_cd > 0.0 or absf(delta_deg) < float(profile.get("pivot_min_deg", 55.0)):
		return false
	var id := &"pivot_left" if delta_deg > 0.0 else &"pivot_right"
	if not moves.has(id) or not creature.anim.has_state(StringName(str(moves[id].get("clip", id)))):
		return false
	if creature.anim._busy or creature.stagger_left > 0.0:
		creature.stop_move()
		return true  # let the clip in hand finish, then turn
	_start(id)
	return true

func _start(id: StringName) -> void:
	if _still_t < CreatureAnim.XFADE * 2.0:
		creature.stop_move()  # stand first: the stance blends in, then the move starts from planted feet
		return
	move_id = id
	move = moves[id]
	if not close_moves.has(id) and not pivots.has(id):
		_planned = &""
	move_t = 0.0
	_struck.clear()
	_near.clear()
	_touched.clear()
	_slammed = false
	_club_prev = club_position()
	creature.stop_move()
	strafe_face = null
	speed_override = -1.0
	var clip := StringName(str(move.get("clip", "attack_primary")))
	creature.anim.play_clip(clip)
	var ap := creature.anim.player
	_clip_length = ap.get_animation(clip).length if ap and ap.has_animation(clip) else 1.0
	move_len = _clip_length / maxf(0.01, creature.anim.cadence(clip))
	if move.has("turn_deg"):
		_turn_begin()
	if move.has("carry_m"):
		_start_carry()
	if _turn_only(move):
		_log("[ai] %s %s" % [creature.def.id, id])
		return
	var strike: Array = move.get("strike", [0.5, 0.6])
	var shock := float(move.get("shock_radius_m", 0.0))
	var ring_s := float(strike[1]) * move_len + float(move.get("run_m", 0.0)) / maxf(0.1, float(move.get("run_mps", 1.0)))
	var hint := "ROLL AWAY" if close_moves.has(id) else "ROLL OR GET TO ITS HEAD"
	var spot := strike_spot(id)
	var radius := maxf(float(move.get("hit_radius_m", 1.1)), shock) * _close_scale(id)
	if move.has("ring_radius_m"):
		spot = creature.global_transform * _turn_pivot  # the spin: everything round the pivot foot out to the club
		radius = float(move["ring_radius_m"]) * creature.size_scale()
	telegraph = Telegraph.show_club(creature, spot, radius, ring_s, "%s - %s" % [str(move.get("label", id)).to_upper(), hint])
	_log("[ai] %s %s (wind-up %.1fs)" % [creature.def.id, id, float(strike[0]) * move_len])

## A PIVOT or ABOUT-FACE: a turn with no hit of its own.
static func _turn_only(mv: Dictionary) -> bool:
	return mv.has("turn_deg") and not mv.has("strike")

## TURN: the turn at clip fraction u, as the clip was keyed (turn_deg * smoothstep over [a, b]).
func turn_at(u: float) -> float:
	var w: Array = move.get("turn", [0.0, 1.0])
	return float(move.get("turn_deg", 0.0)) * smoothstep(float(w[0]), float(w[1]), u)

func _turn_begin() -> void:
	_turn_commit()
	var sk := _skeleton()
	if sk == null or creature.view == null:
		return
	var pv: Array = move.get("pivot_gltf", [0.0, 0.0])
	var pw := sk.global_transform * Vector3(float(pv[0]), 0.0, float(pv[1]))
	_turn_pivot = creature.global_transform.affine_inverse() * pw
	_turn_pivot.y = 0.0
	_body_base = creature.global_transform
	creature.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # turned with the pose, every frame
	turn_applied = 0.0
	_turn_on = true

## After every pose: the body turns with the clip about the pivot, so the frame shows the planted feet where they were.
## ANKYNOTELEPORT (owner: animals never teleport): the body itself goes round the arc a frame at a time. It used to stay
## put while only the view turned, then jump to the end of the arc at once (3.9 m on an ankylosaurus pivot).
func _on_pose_applied() -> void:
	if not _turn_on:
		return
	var clip := StringName(str(move.get("clip", "")))
	var anim := creature.anim
	if anim.current_clip == clip and anim._os_state == clip:
		_set_turn(turn_at(anim._os_t / maxf(0.001, _clip_length)))
	elif anim.current_clip in CreatureAnim.HUBS or anim.current_clip == clip:
		_set_turn(turn_at(1.0))  # played out (the turn ends before the clip does): the whole turn
		_turn_commit()
	else:
		_turn_commit()  # cut off (a flinch, a knockdown): keep the turn it got to

func _set_turn(deg: float) -> void:
	turn_applied = deg
	var b := Basis(Vector3.UP, deg_to_rad(deg))
	var pw := _body_base * _turn_pivot
	var gt := _body_base
	gt.basis = b * _body_base.basis
	gt.origin = pw + b * (_body_base.origin - pw)
	gt.origin.y = creature.global_position.y  # the ground keeps the height
	creature.global_transform = gt

## The turn is over (played out or cut off): the body is already where the turn left it.
func _turn_commit() -> void:
	if not _turn_on:
		return
	_turn_on = false
	if not is_instance_valid(creature):
		return
	creature.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	creature.reset_physics_interpolation()

func _tick_move(delta: float) -> void:
	move_t += delta
	if _lunge_left >= 0.0:
		_tick_lunge(delta)
		return
	creature.stop_move()  # no slide in code while the clip's feet carry the body (a TURN move turns in _on_pose_applied)
	var clip := StringName(str(move.get("clip", "")))
	var u := move_t / maxf(0.01, move_len)
	# (the last frames: the clip may hand back to idle a frame before move_t gets there)
	if (creature.anim.current_clip != clip and u < 0.97) or creature.health.dead:
		_end_move()  # knocked down, killed or otherwise cut off
		return
	if _turn_only(move):
		if u >= 1.0:
			_end_move()
		return
	var strike: Array = move.get("strike", [0.5, 0.6])
	var club := club_position()
	var club_from := _club_prev
	_club_prev = club
	if close_moves.has(move_id) and not move.has("line_bone"):
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
		_sweep_club(clip, club_from, club)
		if bool(move.get("slam", false)):
			# Impact on the frame the club comes down to the ground (or the window's end), not on a fixed fraction:
			# the tree's crossfade can land the slam a few frames off the authored timing.
			var low := club.y - creature.global_position.y <= float(move.get("slam_height_m", 0.9))
			if not _slammed and (low or u + delta / maxf(0.01, move_len) > float(strike[1])):
				_slammed = true
				_slam(club, clip)
		else:
			var r := float(move.get("hit_radius_m", 1.1))
			var last := u + delta / maxf(0.01, move_len) > float(strike[1])
			var from: Variant = _bone_world(str(move["line_bone"])) if move.has("line_bone") else null
			for t in _threats():
				if _struck.has(t):
					continue
				# Land where the club passes through her: once it is inside the sphere, at its closest point (the
				# frame it starts to move away, it is well inside, or the window ends), not at the sphere's edge.
				# A line move (the spin): her distance to the swept rear body and tail, line_bone to the club, lands at once.
				var d := _flat_seg_dist(t.global_position, (from as Vector3) if from != null else club, club) - _size_excess(t)
				var was: float = _near.get(t, INF)
				_near[t] = d
				# HITBOXES: the club must have touched her hurtboxes (_sweep_club); a line move lands on the line's reach.
				if (d <= r if from != null else _touched.has(t)) and (d >= was or d <= r * 0.5 or last or from != null):
					_strike(t, float(move.get("damage_mult", 1.0)), float(move.get("knockback_m", 0.0)), bool(move.get("knockdown", false)), &"club")
	if u >= 1.0:
		_end_move()

## Ground-plane distance from p to the segment a-b.
static func _flat_seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var ab := Vector2(b.x, b.z) - a2
	var k := clampf((p2 - a2).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p2.distance_to(a2 + ab * k)

## The club's path this frame against every threat's hurtboxes (bodies without a rig: the old flat sphere).
func _sweep_club(clip: StringName, from: Vector3, to: Vector3) -> void:
	var r := Hitbox.part_radius(creature, clip)
	for t in _threats():
		if _touched.has(t):
			continue
		var hit := Hitbox.touch(creature, from, to, r, t) if Hurtboxes.of(t) else ({"part": &""} if _in_sphere(to, t, float(move.get("hit_radius_m", 1.1))) else {})
		if not hit.is_empty():
			_touched[t] = hit

## Height of a bone above the animal's feet (world metres); 0 without a rig or that bone.
func _bone_height(bone: String) -> float:
	var p: Variant = _bone_world(bone)
	return (p as Vector3).y - creature.global_position.y if p != null else 0.0

## STOMP / SHOVE impact: everyone in the sphere round the move's spot (body frame, at this frame) is hit once.
func _impact() -> void:
	if bool(move.get("knockdown", false)):
		IsoCamera.shake(PlayerRegistry.local(), CombatTuning.num("camera", "heavy_hit", 0.6))
	var spot := strike_spot(move_id)
	var clip := StringName(str(move.get("clip", "")))
	for t in _threats():
		# HITBOXES: the stomping foot / the shoving flank (hitboxes.json ankylosaurus.moves.<clip>) must have swept
		# through her hurtboxes over the clip's window; bodies without them keep the sphere round the spot.
		if Hurtboxes.of(t):
			var hit := Hitbox.strike(creature, clip, t)
			if hit.is_empty():
				continue
			_touched[t] = hit
		elif not _in_sphere(spot, t, float(move.get("hit_radius_m", 2.0)) * _close_scale(move_id)):
			continue
		_strike(t, float(move.get("damage_mult", 1.0)), float(move.get("knockback_m", 0.0)), bool(move.get("knockdown", false)), &"close")

## TACKLE (owner 2026-10-31: "tackle should be legs moving fast, then a jump/lunge that goes kind of far"): after the coil
## (the clip), a run-up at run_mps (the stride-matched run gait: legs pumping, no glide) on a line locked now, up to run_m,
## until she is within lunge_m + reach_m; then the LEAP (_start_leap).
func _start_lunge() -> void:
	var k := _close_scale(move_id)
	_lunge_from = creature.global_position
	var f := -creature.global_basis.z
	f.y = 0.0
	f = f.normalized()
	# aim_side_m: it leads with one shoulder, the line set that far to its right of her (the stegosaurus' chest rides over
	# a survivor, so its left foreleg is what bowls her over).
	var aim := attack_target.global_position + f.cross(Vector3.UP) * float(move.get("aim_side_m", 0.0)) * k if _valid_target() else Vector3.ZERO
	var to := aim - creature.global_position if _valid_target() else f
	to.y = 0.0
	# ASSUMPTION: it runs at her when she is within 45 deg of its snout, else straight ahead.
	_lunge_dir = to.normalized() if to.length() > 0.1 and f.dot(to.normalized()) > cos(deg_to_rad(45.0)) else f
	var leap_at := (float(move.get("lunge_m", 4.0)) + float(move.get("reach_m", 2.0))) * k
	_lunge_left = clampf((_flat_dist(attack_target) if _valid_target() else 0.0) - leap_at, 0.0, float(move.get("run_m", 6.0)) * k)
	_leap_t = -1.0
	if _lunge_left <= 0.05:
		_start_leap()

func _tick_lunge(delta: float) -> void:
	if creature.health.dead or creature.statuses.has(&"knockdown"):
		_end_move()
		return
	if _leap_t >= 0.0:
		_tick_leap(delta)
		return
	var k := _close_scale(move_id)
	speed_override = float(move.get("run_mps", 5.0))
	creature.move_to(_lunge_from + _lunge_dir * (_lunge_left + 3.0))  # aim past the end: no slowing into the leap
	var ran := Vector2(creature.global_position.x - _lunge_from.x, creature.global_position.z - _lunge_from.z).length()
	var close := _valid_target() and _flat_dist(attack_target) <= (float(move.get("lunge_m", 4.0)) + float(move.get("reach_m", 2.0))) * k
	var limit_s := _lunge_left / maxf(0.1, float(move.get("run_mps", 5.0))) + 0.8
	if close or ran >= _lunge_left or move_t - move_len > limit_s:
		_start_leap()

## The LEAP: leap_clip plays and the body is carried lunge_m along the run's line inside the clip's airborne window
## (anim_events <leap_clip>.airborne), on an arc of leap_height_m; the feet are off the ground there, planted outside it.
## The hit: the clip's parts (hitboxes.json <leap_clip>) swept frame to frame through her hurtboxes (Hitbox.touch).
func _start_leap() -> void:
	var k := _close_scale(move_id)
	creature.stop_move()
	speed_override = -1.0
	var clip := StringName(str(move.get("leap_clip", "tackle_lunge")))
	if not creature.anim.has_state(clip):
		_end_move()
		return
	creature.look_at(creature.global_position + _lunge_dir, Vector3.UP)  # square to the line (the run-up already faces it)
	creature.anim.play_clip(clip)
	_carry_begin(clip, _lunge_dir * float(move.get("lunge_m", 4.0)) * k)

## Carry the body by `by` (flat, world) inside clip's airborne window (anim_events <clip>.airborne), sweeping the clip's
## hitbox parts live (_tick_leap). The clip is already playing.
func _carry_begin(clip: StringName, by: Vector3) -> void:
	_leap_clip = clip
	_leap_t = 0.0
	_lunge_left = 0.0  # _tick_move hands every frame to _tick_lunge, which runs the carry
	_leap_from = creature.global_position
	_leap_to = _leap_from + Vector3(by.x, 0.0, by.z)
	var ap := creature.anim.player
	_leap_len = (ap.get_animation(clip).length if ap.has_animation(clip) else 1.0) / maxf(0.01, creature.anim.cadence(clip))
	var air: Variant = ((Data.anim_events.get("clips", {}) as Dictionary).get(str(clip), {}) as Dictionary).get("airborne")
	_leap_air = Vector2(float(air[0]), float(air[1])) if air is Array else Vector2(0.15, 0.5)
	_touched.clear()
	_part_prev = _leap_parts()

## SHOULDER SLAM (owner 2026-10-31: "the shove attack on the ankylosaurus needs more range, and I want you to kind of throw
## the ankys body weight at the player"): the body is thrown at her, up to carry_m (x size), so the slamming shoulder
## (slam_point: body-frame x / z of where the clip drives it, metres at size 1) ends at her body; then it lands into her.
func _start_carry() -> void:
	var k := _close_scale(move_id)
	var by := Vector3.ZERO
	if _valid_target():
		var sp: Array = move.get("slam_point", [0.0, 0.0])
		var at := creature.global_transform * (Vector3(float(sp[0]), 0.0, float(sp[1])) * k)
		by = attack_target.global_position - at
		by.y = 0.0
		by = by.normalized() * clampf(by.length() - 0.3, 0.0, float(move["carry_m"]) * k) if by.length() > 0.3 else Vector3.ZERO
	_carry_begin(StringName(str(move.get("clip", ""))), by)

## World positions of the leap's hit parts now: [[a, b, radius], ...].
func _leap_parts() -> Array:
	var clip := _leap_clip
	var spec := Hitbox.move_spec(creature, clip)
	var sk := _skeleton()
	var out := []
	if sk == null:
		return out
	var i := 0
	for part in spec.get("parts", []) as Array:
		var bi := sk.find_bone(str((part as Dictionary).get("bone", "")))
		if bi >= 0:
			var g := sk.global_transform * sk.get_bone_global_pose(bi)
			var ax: Array = (part as Dictionary).get("axis", [0, 1, 0])
			var tip := g.origin + g.basis.orthonormalized() * Vector3(float(ax[0]), float(ax[1]), float(ax[2])).normalized() * float((part as Dictionary).get("length", 0.0)) * creature.size_scale()
			out.append([g.origin, tip, Hitbox.part_radius(creature, clip, i)])
			i += 1
	return out

func _tick_leap(delta: float) -> void:
	_leap_t += delta
	var u := _leap_t / maxf(0.01, _leap_len)
	var clip := _leap_clip
	if creature.anim.current_clip != clip and u < 0.97:
		_end_move()  # cut off
		return
	var f := clampf((u - _leap_air.x) / maxf(0.01, _leap_air.y - _leap_air.x), 0.0, 1.0)
	var step := _leap_from.lerp(_leap_to, f) - creature.global_position
	step.y = 0.0
	creature.move_and_collide(step)
	creature.view.position.y = sin(PI * f) * float(move.get("leap_height_m", 0.5)) * _close_scale(move_id)
	var now := _leap_parts()
	if u >= _leap_air.x and u <= _leap_air.y + 0.08:
		for t in _threats():
			if _struck.has(t):
				continue
			for i in mini(now.size(), _part_prev.size()):
				var hit := {}
				if Hurtboxes.of(t):
					hit = Hitbox.touch(creature, _part_prev[i][0], now[i][0], float(now[i][2]), t)
					if hit.is_empty() and now[i][1] != now[i][0]:
						hit = Hitbox.touch(creature, _part_prev[i][1], now[i][1], float(now[i][2]), t)
				elif _in_sphere(now[i][0], t, float(now[i][2])):
					hit = {"part": &""}
				if not hit.is_empty():
					_touched[t] = hit
					IsoCamera.shake(PlayerRegistry.local(), CombatTuning.num("camera", "heavy_hit", 0.6))
					_strike(t, float(move.get("damage_mult", 1.0)), float(move.get("knockback_m", 0.0)), bool(move.get("knockdown", false)), &"close")
					break
	_part_prev = now
	if u >= 1.0:
		_end_move()

## A body check: everyone not yet in `struck` inside the sphere `dist` ahead of the snout is hit with mv. True on a hit.
func _contact(dist: float, radius: float, mv: Dictionary, kind: StringName, struck: Array[Node3D]) -> bool:
	var f := -creature.global_basis.z
	f.y = 0.0
	var at := creature.global_position + f.normalized() * dist
	var hit := false
	for t in _threats():
		if not struck.has(t) and _in_sphere(at, t, radius):
			IsoCamera.shake(PlayerRegistry.local(), CombatTuning.num("camera", "heavy_hit", 0.6))
			var keep := move
			move = mv
			_strike(t, float(mv.get("damage_mult", 1.0)), float(mv.get("knockback_m", 0.0)), bool(mv.get("knockdown", false)), kind)
			move = keep
			if not struck.has(t):
				struck.append(t)
			hit = true
	return hit

func _in_sphere(club: Vector3, t: Node3D, radius: float) -> bool:
	return Vector2(club.x - t.global_position.x, club.z - t.global_position.z).length() <= radius + _size_excess(t)

## TAIL SMASH impact: the club's own sphere knocks down for full damage, the shockwave round it hits lighter.
func _slam(club: Vector3, _clip: StringName) -> void:
	IsoCamera.shake(PlayerRegistry.local(), CombatTuning.num("camera", "heavy_hit", 0.6))
	for t in _threats():
		if _touched.has(t):
			_strike(t, float(move.get("damage_mult", 1.0)), float(move.get("knockback_m", 0.0)), bool(move.get("knockdown", false)), &"club")
		elif _in_sphere(club, t, float(move.get("shock_radius_m", 0.0))):
			_strike(t, float(move.get("shock_mult", 0.3)), float(move.get("shock_knockback_m", 0.0)), false, &"shock")

func _strike(t: Node3D, mult: float, knock_m: float, knockdown: bool, kind: StringName) -> void:
	_struck.append(t)  # one strike per target per move, landed or dodged
	if t is Player and (t as Player).dead:
		return
	var clip := StringName(str(move.get("clip", "attack_primary")))
	Hitbox.mark(t, _touched.get(t, {}))
	# CreatureAttack: a roll inside its opening window (or out of a live ring) dodges outright, before any damage.
	if not CreatureAttack.apply_for(creature, clip, t, mult):
		return
	last_hit_s = _now_s()
	club_hit.emit(&"joust" if kind == &"joust" else move_id, t, kind)
	var away := t.global_position - creature.global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else -creature.global_basis.z
	if kind == &"joust":
		# ASSUMPTION: a joust throws her off the line, to the side she stood on, so it runs on past her.
		var r := creature.global_basis.x
		r.y = 0.0
		away = (r if away.dot(r) >= 0.0 else -r).normalized()
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
	_turn_commit()
	var id := move_id
	var again := false
	if pivots.has(id):
		_pivot_cd = float(profile.get("pivot_cooldown_s", 0.3))
	elif close_moves.has(id):
		_close_cd = float(move.get("cooldown_s", 1.2)) * _rage_cd()
		if _resolve(_front_entry(), attack_target if _valid_target() else creature) == id or (str(id).begins_with("spin") and _front_entry() == &"spin"):
			_front_n += 1
		_lunge_left = -1.0
		speed_override = -1.0
		if _leap_t >= 0.0:
			_leap_t = -1.0
			creature.view.position.y = 0.0
	else:
		# A spin goes round again at once while she stays in reach and on her feet (owner: "spinning a lot").
		again = bool(move.get("double", false)) and _spun == 0 and _valid_target() and not _target_down() \
			and not creature.health.dead and creature.stagger_left <= 0.0 \
			and _flat_dist(attack_target) <= float(move.get("target_dist_m", 3.0)) + float(move.get("range_tol_m", RANGE_TOL_M)) + _size_excess(attack_target)
		if not again:
			_attack_cd = float(move.get("cooldown_s", 4.0)) * _rage_cd()
			_move_n += 1
	_spun = _spun + 1 if again else 0
	move_id = &""
	if is_instance_valid(telegraph):
		telegraph.queue_free()
	telegraph = null
	if again:
		_start(id)
	elif str(id).begins_with("about") and _valid_target() and not _target_down() and not creature.health.dead and creature.stagger_left <= 0.0:
		_tail_after_about()

## After the ABOUT-FACE she is behind it: the planned tail move at once if she is in its reach and lined up (_aimed);
## else the usual tail positioning takes over (a sidestep).
func _tail_after_about() -> void:
	var id := _next_move()
	var b := bearing_of(attack_target.global_position)
	var mv: Dictionary = moves[id]
	if not _aimed(mv, b):
		return  # the smash lands on one spot: the usual tail positioning lines it up (a sidestep), then it comes down
	if _flat_dist(attack_target) <= float(mv.get("target_dist_m", 3.0)) + float(mv.get("range_tol_m", RANGE_TOL_M)) + _size_excess(attack_target):
		_start(id)

## JOUST (the ankylosaurus, ai.json club_tail.joust; owner 2026-10-31: "he should also joust"): from min_m or more, a
## straight charge on a line locked at its start, past her by past_m, then a wide arc at a run back round to face her,
## and again, `passes` times. A body check on contact (contact_dist_m ahead of the snout) knocks her down. Big and heavy:
## it arcs on the run gait, never hops. shortcut: its own minimal joust; fold onto claude/mmo-megajoust's shared one
## (tactics profile) when that lands.
func _try_joust(dist: float, b: float) -> bool:
	if joust.is_empty() or _joust_cd > 0.0 or dist < float(joust.get("min_m", 11.0)) or dist > float(joust.get("max_m", 26.0)):
		return false
	if absf(b) > float(joust.get("face_tol_deg", 35.0)):
		return _try_pivot(-b)  # face her first
	if creature.anim._busy or creature.stagger_left > 0.0:
		return true
	_joust_passes = 0
	_joust_t = 0.0
	_joust_begin_run()
	return true

func _joust_begin_run() -> void:
	joust_phase = &"run"
	_joust_hit.clear()
	_joust_from = creature.global_position
	var to := attack_target.global_position - creature.global_position
	to.y = 0.0
	_joust_dir = to.normalized() if to.length() > 0.1 else -creature.global_basis.z
	_joust_len = to.length() + float(joust.get("past_m", 7.0))
	_joust_best = 0.0
	_joust_best_t = _joust_t
	strafe_face = null
	speed_override = float(joust.get("run_mps", 6.0))
	if is_instance_valid(telegraph):
		telegraph.queue_free()
	telegraph = Telegraph.show_club(creature, attack_target.global_position, float(joust.get("ring_radius_m", 2.2)),
		_joust_len / maxf(0.1, float(joust.get("run_mps", 6.0))), "%s - ROLL ASIDE" % str(joust.get("label", "JOUST")))
	_log("[ai] %s joust run %d" % [creature.def.id, _joust_passes + 1])

func _tick_joust(delta: float) -> void:
	_joust_t += delta
	_set_state(&"attack")
	if not _valid_target() or _joust_t > float(joust.get("max_s", 14.0)) or creature.health.dead or creature.stagger_left > 0.0:
		_end_joust()
		return
	speed_override = float(joust.get("run_mps", 6.0))
	if joust_phase == &"run":
		creature.move_to(_joust_from + _joust_dir * (_joust_len + 3.0))
		_contact(float(joust.get("contact_dist_m", 3.9)) * creature.size_scale(), float(joust.get("contact_radius_m", 1.0)) * creature.size_scale(), joust, &"joust", _joust_hit)
		var along := (creature.global_position - _joust_from).dot(_joust_dir)
		if along > _joust_best + 0.3:
			_joust_best = along
			_joust_best_t = _joust_t
		if along >= _joust_len or _joust_t - _joust_best_t > 1.0:  # past her, or stopped by something in the way
			_joust_passes += 1
			if _joust_passes >= int(joust.get("passes", 2)):
				_end_joust()
				return
			joust_phase = &"arc"
		return
	# arc: keep running, the heading swung round toward her at arc_turn_deg_s (a wide turn on the run gait, no pivot)
	var to := attack_target.global_position - creature.global_position
	to.y = 0.0
	var err := _joust_dir.signed_angle_to(to.normalized(), Vector3.UP)
	_joust_dir = _joust_dir.rotated(Vector3.UP, clampf(err, -1.0, 1.0) * deg_to_rad(float(joust.get("arc_turn_deg_s", 60.0))) * delta)
	creature.move_to(creature.global_position + _joust_dir * 6.0)
	if absf(rad_to_deg(err)) <= float(joust.get("face_tol_deg", 35.0)):
		if to.length() >= float(joust.get("rerun_min_m", 7.0)):
			_joust_begin_run()
		else:
			_end_joust()  # came round too close for a run: the front moves take her

## A joust's charge is committed: hits do not stagger it out of the run.
func super_armor() -> bool:
	return joust_phase == &"run"

func _end_joust() -> void:
	if joust_phase == &"":
		return
	joust_phase = &""
	_joust_cd = float(joust.get("cooldown_s", 6.0)) * _rage_cd()
	speed_override = -1.0
	creature.stop_move()
	if is_instance_valid(telegraph):
		telegraph.queue_free()
	telegraph = null

## Hit from close in front or beside it: no look-around first (the alert pause), it answers at once.
func on_aggro(who: Node) -> void:
	super.on_aggro(who)
	if state == &"alert" and who == attack_target and _provoked() and _close_move(attack_target) != &"":
		_set_state(&"approach")

func opening_label() -> String:
	if move_id == &"" or pivots.has(move_id):
		return ""
	var strike: Array = move.get("strike", [0.5, 0.6])
	return "%s %.1fs" % [str(move.get("label", move_id)), maxf(0.0, float(strike[0]) * move_len - move_t)]

func on_player_killed(at: Vector3) -> void:
	_end_move()
	_end_joust()
	super.on_player_killed(at)

func _exit_tree() -> void:
	if is_instance_valid(telegraph):
		telegraph.queue_free()
