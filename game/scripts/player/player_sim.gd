class_name PlayerSim
extends RefCounted
## Survivor movement and physics: walking, tap-to-walk routes, roll, stagger, sleep, and the
## guards that keep the body on the island. Player._physics_process calls tick() once a frame.

const ROLL_SPEED := 13.0
const ROLL_SECONDS := 0.45  # ~5.9 m
const ROLL_BUFFER := 0.2
const ROLL_COST := 12.0
## The v2 roll clip tumbles and stands back up over ~1.9 s; played faster so the visible roll ends
## with the dash instead of locking the survivor for the whole clip (pc-combat-01).
const ROLL_CLIP_SECONDS := 0.45

var p: Player
## Tap-run or sprint this frame; the anim tick and footsteps read it.
var running: bool = false
var _path_points := PackedVector3Array()
var _path_index: int = 0
var _path_replan_left: float = 0.0
var _path_anchor := Vector3.ZERO
var _path_blocked_left: float = 0.0
var _stall_pos := Vector3.ZERO
var _path_stuck: float = 0.0  ## cumulative seconds the survivor has not moved while routed
var _unreachable_said: bool = false
var _roll_left: float = 0.0
var _roll_direction := Vector3.ZERO
var _roll_through: Array[Creature] = []
var _roll_buffer_left: float = 0.0
var _roll_buffer_dir := Vector3.ZERO
## Stagger: a short unmovable hurt window after a hit (0.35 s), at most once every 1.5 s.
var _stagger_left: float = 0.0
var _stagger_immune_until: float = -1.0
var _wet_acc: float = 0.0
var _survival_acc: float = 0.0
var _shoreline_logged: bool = false
var _sleep_spot: Node3D

func _init(player: Player) -> void:
	p = player

## Dead: no input, only gravity.
func hold_still(delta: float) -> void:
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	if not p.is_on_floor():
		p.velocity += p.get_gravity() * delta
	p.move_and_slide()

func tick_survival_xp(delta: float) -> void:
	_survival_acc += delta
	if _survival_acc >= 60.0 and p.skills:
		_survival_acc -= 60.0
		p.skills.add_xp("survival", 1)

func tick(delta: float) -> void:
	var anim := p.anim
	if p._sleep_left > 0.0 and p.statuses != null and p.vitals != null:
		_tick_sleep(delta)
		return
	if anim and anim._waking:
		hold_still(delta)
		return
	if p.statuses == null or p.vitals == null:
		p.move_and_slide()
		return
	if not p.is_on_floor() and p.mounted_on == null:
		p.velocity += p.get_gravity() * delta
	if _roll_left > 0.0:
		_roll_left -= delta
		if _roll_left <= 0.0:
			_end_roll()
	if _roll_buffer_left > 0.0:
		_roll_buffer_left -= delta
		if not p.rolling:
			try_roll(_roll_buffer_dir)
	# Fight or move, not both: no walking while a swing or punch plays.
	if anim and anim._busy and anim.current_clip in [&"attack_primary", &"attack_heavy", &"punch"]:
		p.velocity.x = 0.0
		p.velocity.z = 0.0
		p.move_and_slide()
		return
	if _stagger_left > 0.0:
		_stagger_left -= delta
		p.velocity.x = 0.0
		p.velocity.z = 0.0
		p.move_and_slide()
		if anim:
			anim._physics_tick(0.0)
		return
	if p.rolling:
		# Committed dash: constant speed, ignores input and nav, slips through creatures.
		p.velocity.x = _roll_direction.x * ROLL_SPEED
		p.velocity.z = _roll_direction.z * ROLL_SPEED
		p.move_and_slide()
		shoreline_guard()
		return
	if p.mounted_on and is_instance_valid(p.mounted_on):
		p.pets.mounted_move(delta)
		p.controls.sync_touch_context()
		return
	if p.statuses.has_flag(&"cannot_act"):
		p.velocity.x = 0.0
		p.velocity.z = 0.0
		p.move_and_slide()
		if anim:
			anim._physics_tick(0.0)
		p.controls.sync_touch_context()
		return
	_walk(delta)
	p.controls.sync_touch_context()

func _walk(delta: float) -> void:
	var input := input_vector()
	if input.length_squared() > 0.0:
		p.clear_nav()
		p.view.clear_ground_marker()
		p.actions.cancel_work()
	var dir := cam_dir(input)
	var can_sprint := Input.is_action_pressed("sprint") and not p.statuses.has_flag(&"no_sprint")
	running = can_sprint or (p.nav_active and not p.statuses.has_flag(&"no_sprint"))
	# Stamina: sprint 9/s, tap-run 3/s; empty -> walk until it refills.
	p.vitals.in_combat = (p.hunt != null and p.hunt.target != null) or (Time.get_ticks_msec() * 0.001 - p._last_hit_taken_s) < 5.0
	if running and p.velocity.length_squared() > 0.5:
		if not p.vitals.drain_energy(9.0 if can_sprint else 3.0, delta):
			running = false
			can_sprint = false
	elif running and p.vitals.energy <= 0.0:
		running = false
		can_sprint = false
	var target_speed := p.sprint_speed if can_sprint else (p.run_speed if running else p.walk_speed)
	target_speed *= p.statuses.move_mult()
	if p.nav_active:
		dir = _nav_dir(delta, dir)
	var horizontal := Vector3(p.velocity.x, 0.0, p.velocity.z)
	horizontal = horizontal.move_toward(dir * target_speed, p.accel * delta)
	p.velocity.x = horizontal.x
	p.velocity.z = horizontal.z
	if dir.length_squared() > 0.0:
		var target_yaw := atan2(-dir.x, -dir.z)  # RiggedModel faces -Z (the old capsule faced +Z)
		p.visual.rotation.y = lerp_angle(p.visual.rotation.y, target_yaw, p.turn_speed * delta)
		# ASSUMPTION: walking 0.05/s, tap-running 0.09/s, sprint 0.2/s (was 0.25-0.8/s, which
		# filled the bar in a few minutes and then blocked gathering).
		p.vitals.add_fatigue(delta * (0.2 if can_sprint else (0.09 if running else 0.05)), &"walk")
	p.vitals.fatigue_gain_mult = 0.5 if _in_coziness() else 1.0
	if p.in_water:
		_wet_acc += delta
		var need := float(Data.world_rules.get("wet_after_seconds_in_water", 5))
		if _wet_acc >= need:
			p.statuses.apply(&"wet", null)
			_wet_acc = need - 1.0  # keep refreshing while in water, once a second rather than every frame
	else:
		_wet_acc = 0.0
	p.actions.tick_work(delta)
	var y0 := p.global_position.y
	p.move_and_slide()
	_no_creature_climb(y0)
	shoreline_guard()
	if p.anim:
		p.anim._physics_tick(Vector2(p.velocity.x, p.velocity.z).length(), running)

## Steering while routed. Neither router promises a walkable answer: the tile graph returns a
## degenerate route when the goal tile is occupied (a bush and its collider sit on it), and
## NavigationAgent3D does the same when its map is not ready. Walk straight at the goal in both
## cases, and give up rather than freeze.
func _nav_dir(delta: float, dir: Vector3) -> Vector3:
	var next_dir := Vector3.ZERO
	var finished := false
	if use_tile_path():
		next_dir = _tile_nav_dir(delta)
		finished = next_dir.length_squared() <= 0.0
	elif not p.agent.is_navigation_finished():
		var to := p.agent.get_next_path_position() - p.global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			next_dir = to.normalized()
	else:
		finished = true
	var remain := p._path_goal - p.global_position
	remain.y = 0.0
	# A router with no direction (map not ready) also falls back; it used to creep one frame per
	# 1.2 s stall because moving reset the stall timer.
	var stalled := _stalled(delta)
	if remain.length() > _arrive_tolerance() and (finished or stalled or next_dir == Vector3.ZERO):
		if _path_stuck > 5.0:
			print("[path] abandoned route to %.0f,%.0f after %.1fs stuck" % [p._path_goal.x, p._path_goal.z, _path_stuck])
			_path_stuck = 0.0
		else:
			finished = false
			next_dir = remain.normalized()
			# Full speed into a static body and still not moving: wedged in geometry.
			if _path_stuck > 2.0:
				unstick(next_dir)
	if finished:
		p.nav_active = false
		p.actions.on_arrived()
		return Vector3.ZERO
	return next_dir if next_dir.length_squared() > 0.0 else dir

## Pushing into a dinosaur slides the round capsule up its back (phys-climb-01). A rise that only a
## creature caused is undone; terrain and floors still carry her up slopes.
func _no_creature_climb(y0: float) -> void:
	if p.global_position.y <= y0 + 0.001:
		return
	var by_creature := false
	for i in p.get_slide_collision_count():
		if p.get_slide_collision(i).get_collider() is Creature:
			by_creature = true
			break
	if not by_creature:
		return
	var limit := y0
	var rt := World.runtime
	if rt and rt.has_method("surface_y"):
		limit = maxf(y0, rt.surface_y(p.global_position.x, p.global_position.z) + p.half_height() + 0.05)
	if p.global_position.y > limit:
		p.global_position.y = limit
		p.velocity.y = minf(p.velocity.y, 0.0)

func input_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func cam_dir(input: Vector2) -> Vector3:
	var cam := p.get_viewport().get_camera_3d()
	var dir := Vector3.ZERO
	if cam and input.length_squared() > 0.0:
		var fwd := -cam.global_basis.z
		fwd.y = 0.0
		var right := cam.global_basis.x
		right.y = 0.0
		dir = (right.normalized() * input.x + fwd.normalized() * -input.y).normalized()
	return dir

# ---------------------------------------------------------------- roll and stagger

## Roll toward `dir` (camera-relative input; zero = where she faces). Cancels a swing, a flinch (and
## its stagger) or a work clip, buffers ROLL_BUFFER s while another roll finishes, says why when refused.
func try_roll(dir: Vector3 = Vector3.ZERO) -> bool:
	var why := roll_refusal()
	if why == "busy":
		_roll_buffer_left = ROLL_BUFFER
		_roll_buffer_dir = dir
		return false
	_roll_buffer_left = 0.0
	if why != "":
		if why != "dead":
			p.notice(why)
		return false
	if not p.vitals.spend_energy(ROLL_COST):
		p.notice("Out of stamina.")
		return false
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = -p.visual.global_basis.z
		dir.y = 0.0
	_roll_direction = dir.normalized()
	p.visual.rotation.y = atan2(-_roll_direction.x, -_roll_direction.z)
	p.rolling = true
	_roll_left = ROLL_SECONDS
	_stagger_left = 0.0
	p.clear_nav()
	p.actions.cancel_work()  # a swing in flight is lost: Hunt checks rolling when it would land
	p.velocity.x = _roll_direction.x * ROLL_SPEED
	p.velocity.z = _roll_direction.z * ROLL_SPEED
	# Roll through creatures: collision exceptions with everything close, restored at the end.
	for n in p.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and p.global_position.distance_to(c.global_position) < 8.0:
			p.add_collision_exception_with(c)
			_roll_through.append(c)
	if p.anim:
		p.anim.on_roll()
		var ap := p.rig.anim_player if p.rig else null
		if ap and ap.has_animation(&"roll"):
			ap.speed_scale = maxf(1.0, ap.get_animation(&"roll").length / ROLL_CLIP_SECONDS)
	print("[combat] roll")
	return true

## "" = she can roll now, "busy" = buffer the press, "dead" = silent, else the reason to show.
func roll_refusal() -> String:
	if p.dead:
		return "dead"
	if p.rolling:
		return "busy"
	if p.mounted_on:
		return "Dismount to roll."
	if p._sleep_left > 0.0 or (p.anim and (p.anim._sleeping or p.anim._waking)):
		return "Can't roll while resting."
	if p.statuses.has_flag(&"cannot_act") or (p.anim and p.anim._busy and p.anim.current_clip == &"knockdown"):
		return "Can't roll while knocked down."
	if p.statuses.has_flag(&"no_roll"):
		return "Too hampered to roll."
	return ""

func roll_left() -> float:
	return _roll_left

func _end_roll() -> void:
	p.rolling = false
	for c in _roll_through:
		if c and is_instance_valid(c):
			p.remove_collision_exception_with(c)
	_roll_through.clear()
	p.velocity.x *= 0.3
	p.velocity.z *= 0.3
	# The dash is over, so is the oneshot: idle is not a busy clip, the next tick picks locomotion.
	if p.anim and p.anim.current_clip == &"roll":
		p.anim.play_clip(&"idle")

func on_hit() -> void:
	var now_s := Time.get_ticks_msec() * 0.001
	if not p.rolling and now_s >= _stagger_immune_until:
		_stagger_left = 0.35
		_stagger_immune_until = now_s + 1.5
		p.clear_nav()

# ---------------------------------------------------------------- tap-to-walk routes

func nav_to(pos: Vector3) -> void:
	if p.nav_active and p._path_goal.distance_to(pos) <= 0.3:
		return
	p.nav_active = true
	p._path_goal = pos
	_path_replan_left = 0.0
	_path_anchor = p.global_position
	_stall_pos = p.global_position
	_path_blocked_left = 0.0
	_path_stuck = 0.0
	_unreachable_said = false
	if use_tile_path():
		_request_tile_path()
	else:
		p.agent.target_position = pos

func clear_nav() -> void:
	p.nav_active = false
	_path_points = PackedVector3Array()
	_path_index = 0
	p.agent.target_position = p.global_position

func path_points() -> PackedVector3Array:
	return _path_points

func path_index() -> int:
	return _path_index

func use_tile_path() -> bool:
	return World.runtime != null and World.runtime.get("pathing") != null and p.get_parent() == World.runtime

func closest_nav_point(pos: Vector3) -> Vector3:
	if use_tile_path():
		return BuildGrid.tile_centre(BuildGrid.tile_of(pos), World.runtime)
	var map := p.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return pos
	return NavigationServer3D.map_get_closest_point(map, pos)

func _request_tile_path() -> void:
	if not use_tile_path():
		return
	var pathing: Variant = World.runtime.get("pathing")
	if pathing == null:
		return
	_path_points = pathing.path(p.global_position, p._path_goal, 96)
	_path_index = 0
	# A plain ground move to a tile nothing reaches stops at the closest reachable tile and says
	# so, instead of pressing into the wall for 10 s (phys-path-01). Targets keep their own goal.
	var end := _path_points[_path_points.size() - 1] if not _path_points.is_empty() else p._path_goal
	if not bool(pathing.get("last_reachable")) and not p.actions.has_target() and end.distance_to(p._path_goal) > 2.5:
		p._path_goal = end
		if not _unreachable_said:
			_unreachable_said = true
			p.notice("Can't get all the way there.")
	# Skip waypoints already behind us (a re-plan starts at the current tile's centre, which
	# would otherwise make the survivor step back to it and jitter).
	while _path_points.size() > _path_index + 1:
		var p0 := _path_points[_path_index]
		var seg := _path_points[_path_index + 1] - p0
		seg.y = 0.0
		var rel := p.global_position - p0
		rel.y = 0.0
		if seg.dot(rel) > 0.0 and rel.length() < 1.5:
			_path_index += 1
		else:
			break

func _tile_nav_dir(delta: float) -> Vector3:
	_path_replan_left -= delta
	if _path_points.is_empty() or _path_replan_left <= 0.0:
		_request_tile_path()
		_path_replan_left = 1.5
	if _path_points.is_empty():
		return Vector3.ZERO
	while _path_index < _path_points.size():
		var to := _path_points[_path_index] - p.global_position
		to.y = 0.0
		var last := _path_index == _path_points.size() - 1
		# The last waypoint is the target's own tile centre; bushes, corpses and animals have
		# colliders there, so the survivor stops short. Count that as arrived within reach.
		if to.length() <= (_arrive_tolerance() if last else 0.25):
			_path_index += 1
			continue
		if _track_tile_blocked(delta) and last and to.length() <= 2.2:
			_path_index += 1  # pushed up against something at the goal: close enough
			continue
		return to.normalized()
	return Vector3.ZERO

func _arrive_tolerance() -> float:
	return 1.5 if p.actions.has_target() else 0.25

## Free a survivor wedged against static geometry: one step along the ground to a spot the capsule
## fits, tested before moving. Never into or onto a creature (that hop is how she ended up riding
## compys, phys-climb-01), never through a wall.
func unstick(towards: Vector3) -> bool:
	var step := p.global_position + towards * 0.45
	var rt := World.runtime
	if rt and rt.has_method("surface_y"):
		step.y = rt.surface_y(step.x, step.z) + p.half_height() + 0.2  # origin is the capsule centre
	else:
		step.y = p.global_position.y + 0.1
	var shape := p.get_node("Shape") as CollisionShape3D
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape.shape
	q.transform = Transform3D(p.global_basis, step) * shape.transform
	q.exclude = [p.get_rid()]
	if not p.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		return false
	p.global_position = step
	return true

## True once a routed survivor has stood still for 1.2 s. Drives the straight-line fallback.
func _stalled(delta: float) -> bool:
	var displacement := p.global_position - _stall_pos
	displacement.y = 0
	_stall_pos = p.global_position
	if displacement.length() / maxf(delta, 0.0001) > 0.45:
		_path_stuck = 0.0
		return false
	_path_stuck += delta
	return _path_stuck > 1.2

func _track_tile_blocked(delta: float) -> bool:
	if p.global_position.distance_to(_path_anchor) > 0.06:
		_path_anchor = p.global_position
		_path_blocked_left = 0.0
		return false
	_path_blocked_left += delta
	if _path_blocked_left >= 0.35:
		_request_tile_path()
		_path_blocked_left = 0.0
		_path_anchor = p.global_position
		return true
	return false

# ---------------------------------------------------------------- sleep

## ASSUMPTION: straw rolls take 12 seconds and restore 65 exhaustion once;
## tents take 10 seconds and restore 100. Only a completed, uninterrupted sleep
## spends a use. No time skip, no partial restoration on interruption.
func _tick_sleep(delta: float) -> void:
	var hurt := (Time.get_ticks_msec() * 0.001 - p._last_hit_taken_s) < 1.0
	if input_vector().length_squared() > 0.04 or p.nav_active or p.vitals.in_combat or hurt or p.dead \
			or not is_instance_valid(_sleep_spot) or p.global_position.distance_to(_sleep_spot.global_position) > 3.2:
		p._sleep_left = 0.0
		_sleep_spot = null
		if p.anim:
			p.anim.wake_from_sleep()
		p.notice("Sleep interrupted")
		return
	p._sleep_left = maxf(0.0, p._sleep_left - delta)
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	p.move_and_slide()
	if p._sleep_left <= 0.0:
		var spot := _sleep_spot
		_sleep_spot = null
		p.vitals.rest(spot.sleep_restore())
		spot.complete_sleep()
		if p.anim:
			p.anim.wake_from_sleep()
		p.notice("Rested")

func nearest_sleep_spot() -> Node3D:
	var best: Node3D = null
	var best_d := 3.2
	for node in p.get_tree().get_nodes_in_group("sleep_spot"):
		var n := node as Node3D
		if n == null or not is_instance_valid(n) or int(n.get("sleeps_left")) == 0:
			continue
		var d := p.global_position.distance_to(n.global_position)
		if d < best_d:
			best = n
			best_d = d
	return best

func start_sleep(spot: Node3D = null) -> void:
	if spot == null:
		spot = nearest_sleep_spot()
	if spot == null or not is_instance_valid(spot) or not spot.is_in_group("sleep_spot") or int(spot.get("sleeps_left")) == 0:
		return
	if p.global_position.distance_to(spot.global_position) > 3.2:
		p.notice("Move closer to sleep")
		return
	if p.vitals.in_combat or (Time.get_ticks_msec() * 0.001 - p._last_hit_taken_s) < 5.0 or p.dead:
		p.notice("Can't sleep in combat")
		return
	if p.vitals.fatigue < 1.0:
		p.notice("Already rested")
		return
	p.clear_nav()
	p.actions.cancel_work()
	_sleep_spot = spot
	p._sleep_left = spot.sleep_duration()
	if p.anim:
		p.anim.start_sleep()
	p.notice("Sleeping - move to wake")

func interrupt_sleep() -> void:
	p._sleep_left = 0.0
	_sleep_spot = null

# ---------------------------------------------------------------- guards

func _in_coziness() -> bool:
	if not p.is_inside_tree():
		return false
	for n in p.get_tree().get_nodes_in_group("coziness"):
		var a := n as Area3D
		if a and a.overlaps_body(p):
			return true
	return false

func fall_guard() -> void:
	# Never let the player fall out of the world: below -15 m, put her back on the surface.
	if p.global_position.y > -15.0:
		return
	var y := 1.0
	if World.runtime and World.runtime.has_method("surface_y"):
		y = World.runtime.surface_y(p.global_position.x, p.global_position.z) + 1.0
	p.velocity = Vector3.ZERO
	p.global_position.y = y
	print("[player] fell out of the world; re-seated at y=%.2f" % y)

func shoreline_guard() -> void:
	if World.runtime == null or not World.runtime.has_method("surface_y"):
		return
	if World.runtime.surface_y(p.global_position.x, p.global_position.z) >= -0.40:
		return  # ankle-deep wading is fine (reference); deeper is blocked
	var out := Vector2(p.global_position.x, p.global_position.z)
	if out.length_squared() < 0.0001:
		out = Vector2(0.0, 1.0)
	var inward := -out.normalized()
	p.global_position.x += inward.x * 0.55
	p.global_position.z += inward.y * 0.55
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	if not _shoreline_logged and Game.debug_overlay:
		_shoreline_logged = true
		print("[world] shoreline blocked")
