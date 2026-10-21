class_name RouteWalker
extends RefCounted
## Follows a TilePath route for the survivor (tap-to-walk and walks to a target). PlayerSim asks
## steer() once a physics frame while routed and multiplies the answer by the speed.
## - The route is string-pulled with CLEARANCE, and while walking the survivor heads for the furthest
##   waypoint she can reach on a line with the same clearance, so corners are cut only where nothing
##   is in the way and the walk has no zig-zag.
## - The route is planned once. It is planned again when the grid changes (a building placed or taken
##   away, a gate shut or opened), when the survivor is pushed off it and when she makes no headway.
##   Not on a timer: re-planning from the current tile turned her back and forth.
## - The last metre eases off (v = sqrt(2 a d)), so she stops on the spot instead of sliding past it, and
##   sharp corners are taken slower, so she does not swing wide into what the corner goes round.
## - Stuck: no headway for STALL_REPLAN s plans again around what blocks; GIVE_UP s with none at all
##   stops the route and says so. She never hops.

const CLEARANCE := 0.4        ## m from any blocked tile: the capsule's 0.35 plus a little
const ARRIVE := 0.25          ## m, a plain move
const ARRIVE_TARGET := 1.5    ## m, a walk to something to work on (it stands on its own tile)
const PASS := 0.25            ## m from a waypoint counts as passing it
const STALL_SPEED := 0.45     ## m/s: slower than this is no headway
const STALL_REPLAN := 0.35
const GIVE_UP := 1.5
const OFF_ROUTE := 1.5        ## m from the current leg: pushed off, plan again
const LOOK_AHEAD := 6.0       ## m: waypoints further than this are not tested for a shortcut
const SWING := 0.2            ## m a sharp corner may swing her wide (the clearance leaves 0.05 + the tile's own margin)
const BRAKE_LOOK := 8.0       ## m of route ahead that can slow her (8.5 m/s stops in under 4 m)

var p: Player
var points := PackedVector3Array()
var index: int = 0
## Set by steer() on the frame the route ends: arrived (true) or gave up (false).
var arrived: bool = false
var gave_up: bool = false
var _pathing  ## the island's TilePath (untyped as IslandRuntime.pathing is; clear_line/revision come with its hook)
var _revision: int = -1
var _partial: bool = false       ## a walk to a target whose route ends out of reach of it
var _stall: float = 0.0
var _stall_total: float = 0.0
var _best_left: float = INF      ## the shortest route left so far: only beating it pays stalls back
var _last_pos := Vector3.ZERO
var _leg_from := Vector3.ZERO    ## where the survivor was when she took up the current waypoint
var _unreachable_said: bool = false

func _init(player: Player) -> void:
	p = player

func start(pathing: TilePath) -> void:
	_pathing = pathing
	_stall = 0.0
	_stall_total = 0.0
	_best_left = INF
	_unreachable_said = false
	arrived = false
	gave_up = false
	_last_pos = p.global_position
	plan()

func clear() -> void:
	points = PackedVector3Array()
	index = 0
	_pathing = null

func tolerance() -> float:
	return ARRIVE_TARGET if p.actions.has_target() else ARRIVE

func plan() -> void:
	if _pathing == null:
		return
	# The whole route (0 = no prefix): A* searches it all anyway, and a prefix ended mid-island.
	points = _pathing.path(p.global_position, p._path_goal, 0, CLEARANCE)
	_revision = _pathing.revision
	index = 0
	_leg_from = p.global_position
	var reachable: bool = _pathing.last_reachable
	var end := points[points.size() - 1] if not points.is_empty() else p._path_goal
	_partial = false
	if p.actions.has_target():
		_partial = _flat(end).distance_to(_flat(p._path_goal)) > tolerance()  # it keeps its own goal
	elif not points.is_empty():
		# A plain ground move ends on the walkable tile nearest the tap. When nothing reaches it, the
		# closest reachable tile, and she says so (phys-path-01).
		if not reachable and _flat(end).distance_to(_flat(p._path_goal)) > 2.5 and not _unreachable_said:
			_unreachable_said = true
			p.notice("Can't get all the way there.")
		p._path_goal = end
	# The route starts on the centre of her tile: skip it when she can head on from where she stands
	# (walking back to it turned her round, and against a blocker the grid does not know it made her
	# rock back and forth without ever counting as stuck).
	if points.size() >= 2 and _pathing.clear_line(p.global_position, points[1], CLEARANCE):
		index = 1
	_shortcut()

## Direction to walk this frame (its length is the share of `top_speed` to walk at), or ZERO when
## the route ended (`arrived` or `gave_up` says which).
func steer(delta: float, top_speed: float) -> Vector3:
	if _pathing == null:
		return _end(false)
	if _pathing.revision != _revision:
		plan()  # a building placed or taken away, a gate shut or opened: one A* finds the way now
	var pos := p.global_position
	if _flat(pos).distance_to(_flat(p._path_goal)) <= tolerance():
		return _end(true)
	if _progress(delta, _left(pos)):
		return _end(false)
	if points.is_empty():
		return _end(false)
	while index < points.size() and _flat(points[index]).distance_to(_flat(pos)) <= PASS:
		index += 1
		_leg_from = pos
	_shortcut()
	if index >= points.size():
		if _partial:
			plan()  # out of reach at the end: one more plan from here, then say so
			if points.is_empty() or _flat(points[points.size() - 1]).distance_to(_flat(pos)) <= PASS:
				return _end(false)
			return Vector3.ZERO
		return _end(true)
	if _off_route(pos):
		plan()
		if points.is_empty():
			return _end(false)
	var to := points[index] - pos
	to.y = 0.0
	if to.length_squared() < 0.000001:
		return Vector3.ZERO
	return to.normalized() * _ease(pos, top_speed)

## Skip ahead to the furthest waypoint within LOOK_AHEAD that a clear line reaches from here.
func _shortcut() -> void:
	var pos := p.global_position
	while index + 1 < points.size():
		var nxt := points[index + 1]
		if _flat(nxt).distance_to(_flat(pos)) > LOOK_AHEAD or not _pathing.clear_line(pos, nxt, CLEARANCE):
			break
		index += 1
		_leg_from = pos

## Speed share for this frame. She brakes (at 0.8 of her acceleration) so that she stops where the route
## ends (v = sqrt(2 a d)) and takes each sharp corner slowly enough not to swing wide into what it goes
## round: turning by an angle at speed v swings her about v^2 sin(angle/2) / a past the corner.
func _ease(pos: Vector3, top_speed: float) -> float:
	if top_speed <= 0.0:
		return 1.0
	var brake := p.accel * 0.8
	var allow := top_speed
	var d := 0.0
	var from := _flat(pos)
	for k in range(index, points.size()):
		var at := _flat(points[k])
		d += from.distance_to(at)
		if d > BRAKE_LOOK:
			break
		if k + 1 < points.size():
			var turn := absf((at - from).angle_to(_flat(points[k + 1]) - at))
			if turn > 0.35:
				var corner := sqrt(SWING * p.accel / sin(turn * 0.5))
				allow = minf(allow, sqrt(corner * corner + 2.0 * brake * d))
		elif not _partial:
			var stop := d - maxf(0.0, tolerance() - at.distance_to(_flat(p._path_goal))) - ARRIVE * 0.5
			allow = minf(allow, sqrt(2.0 * brake * maxf(stop, 0.0)))
		from = at
	return clampf(allow / top_speed, 0.2, 1.0)

## Metres of route left from `pos`.
func _left(pos: Vector3) -> float:
	if index >= points.size():
		return _flat(pos).distance_to(_flat(p._path_goal))
	var left := _flat(pos).distance_to(_flat(points[index]))
	for k in range(index + 1, points.size()):
		left += _flat(points[k - 1]).distance_to(_flat(points[k]))
	return left

## Headway: re-plan after STALL_REPLAN s without it, give up after GIVE_UP s of it in all. Time stalled
## is paid back only by getting nearer the goal than ever before, so rocking in place adds up.
## True = give up.
func _progress(delta: float, left: float) -> bool:
	var pos := p.global_position
	var moved := _flat(pos).distance_to(_flat(_last_pos))
	_last_pos = pos
	if left < _best_left - 0.2:
		_best_left = left
		_stall_total = maxf(0.0, _stall_total - delta)
	if moved / maxf(delta, 0.0001) >= STALL_SPEED:
		_stall = 0.0
		return false
	_stall += delta
	_stall_total += delta
	if _stall_total >= GIVE_UP:
		return true
	if _stall >= STALL_REPLAN:
		_stall = 0.0
		plan()
	return false

func _off_route(pos: Vector3) -> bool:
	var a := _flat(_leg_from)
	var b := _flat(points[index])
	var q := _flat(pos)
	var ab := b - a
	var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return q.distance_to(a + ab * t) > OFF_ROUTE

func _end(ok: bool) -> Vector3:
	arrived = ok
	gave_up = not ok
	if not ok:
		p.notice("Can't get there.")
		print("[path] gave up on the route to %.0f,%.0f" % [p._path_goal.x, p._path_goal.z])
	return Vector3.ZERO

static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)
