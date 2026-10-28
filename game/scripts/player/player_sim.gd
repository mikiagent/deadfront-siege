class_name PlayerSim
extends RefCounted
## Survivor movement and physics: walking, tap-to-walk routes, roll, stagger, sleep, and the
## guards that keep the body on the island. Player._physics_process calls tick() once a frame.

## ROLL: length, speed curve, opening invulnerable window, cost and cooldown all live in
## data/combat_tuning.json "roll" and are timed by RollRules (the server reads the same rules).
## The front-loaded curve carries her ~10.9 m in 0.55 s; a wall still stops her where a walk would.
## The v2 roll clip tumbles and stands back up over ~1.9 s; played over the dash so the visible
## roll ends with it instead of locking the survivor for the whole clip (pc-combat-01).

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
## Seconds since this roll began (the i-frame clock) and the cooldown left after it ends.
var _roll_elapsed: float = 0.0
var _roll_cd_left: float = 0.0
## Stagger: a short unmovable hurt window after a hit (0.35 s), at most once every 1.5 s.
var _stagger_left: float = 0.0
var _stagger_immune_until: float = -1.0
var _wet_acc: float = 0.0
var _swim_damage_acc: float = 0.0
var _survival_acc: float = 0.0

## Seconds spent in the wake pose; a guard in tick() releases the player if the clip never ends.
var _wake_elapsed: float = 0.0
var _sleep_spot: Node3D
var _sleep_dur := 0.0 ## the spot's full sleep duration, stored for the gradual-onset payout
var _sleep_drained := 0.0 ## exhaustion already paid out of this sleep
var _sleep_f0 := 0.0 ## fatigue when she lay down: what the sleep removed sizes Well Rested
## A sleep spot the survivor is walking to; sleep starts when the route ends.
var _sleep_pending: Node3D
## Capsule-centre height above the ground the survivor had when they lay down (the sleep pose moves
## the visual, not the body), reused so waking puts them back on their feet at the same height.
var _stand_offset: float = 0.9
var _autofeed_cd: float = 0.0
## Sitting down to rest (the Rest hex, the X key): RestState.
var rest: RestState

func _init(player: Player) -> void:
	p = player
	rest = RestState.new(player)

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
	if p.statuses != null and p.vitals != null:
		# Before any branch returns, so mounted, rolling and staggered survivors see current statuses.
		p.vitals.fatigue_gain_mult = (0.5 if _in_coziness() else 1.0) * p.statuses.fatigue_mult()
	p.in_water = WaterAccess.in_water(p.global_position)
	p.swimming = p.in_water and WaterAccess.is_swimming(p.global_position)
	_tick_swimming(delta)
	if _sleep_pending != null:
		# Walking to the bedding: finish on arrival even if the route stalls at the tent's edge, and
		# drop the errand if the bedding vanished (its last use spent elsewhere) .
		if not is_instance_valid(_sleep_pending) or int(_sleep_pending.get("sleeps_left")) == 0:
			_sleep_pending = null
			clear_nav()
		else:
			var anchor: Vector3 = _sleep_pending.sleep_anchor() if _sleep_pending.has_method("sleep_anchor") else _sleep_pending.global_position
			if p.global_position.distance_to(anchor) <= SLEEP_REACH:
				clear_nav()
				var spot := _sleep_pending
				_sleep_pending = null
				start_sleep(spot)
				return
	if p._sleep_left > 0.0 and p.statuses != null and p.vitals != null:
		_tick_sleep(delta)
		return
	if rest.tick(delta):
		return
	if anim and anim._waking:
		_wake_elapsed += delta
		# The wake clip is ~1 s. If its finished signal never arrives (a clip that failed to load, a
		# paused player), the survivor would hold still forever; release them instead. Give playback a
		# few frames to start before treating "not playing" as a dead clip.
		var ap: AnimationPlayer = anim.rig.anim_player if anim.rig else null
		if _wake_elapsed > 3.0 or (_wake_elapsed > 0.25 and (ap == null or not ap.is_playing())):
			anim.force_awake()
			_wake_elapsed = 0.0
		hold_still(delta)
		return
	_wake_elapsed = 0.0
	if p.statuses == null or p.vitals == null:
		p.move_and_slide()
		return
	if not p.is_on_floor() and p.mounted_on == null and not p.swimming:
		p.velocity += p.get_gravity() * delta
	_roll_cd_left = maxf(0.0, _roll_cd_left - delta)
	if _roll_left > 0.0:
		_roll_left -= delta
		_roll_elapsed += delta
		if _roll_left <= 0.0:
			_end_roll()
	if _roll_buffer_left > 0.0:
		_roll_buffer_left -= delta
		# A buffered press fires the moment the dash ends; if the cooldown is still running (the
		# buffer outlived the roll, e.g. a lagging frame) it is dropped silently instead of the
		# "on cooldown" notice firing every frame.
		if not p.rolling:
			_roll_buffer_left = 0.0
			if _roll_cd_left <= 0.0:
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
		if _stagger_left <= 0.0 and anim:
			anim.end_hurt()  # the stun is over: locomotion takes the body back this frame
		elif anim:
			anim._physics_tick(0.0)
		return
	if p.rolling:
		# Committed dash: RollRules' front-loaded curve, ignores input and nav, slips through
		# creatures but never through walls (move_and_slide stops her like a walk would).
		var speed := RollRules.speed_at(_roll_elapsed)
		p.velocity.x = _roll_direction.x * speed
		p.velocity.z = _roll_direction.z * speed
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
	if p.sprint_toggled and (p.vitals.energy <= 0.0 or p.statuses.has_flag(&"no_sprint")):
		p.sprint_toggled = false
	var can_sprint := wants_sprint()
	# A tap route uses the same mode as direct movement. Sprint off means walk; Sprint on or held
	# means sprint. The old nav_active branch silently forced every screen click into a run.
	running = can_sprint
	# Stamina: sprint 9/s; empty -> walk until it refills.
	p.vitals.in_combat = (p.hunt != null and p.hunt.target != null) or (Time.get_ticks_msec() * 0.001 - p._last_hit_taken_s) < 5.0
	if running and p.velocity.length_squared() > 0.5:
		if not p.vitals.drain_energy((9.0 if can_sprint else 3.0) * CombatTuning.num("movement", "run_stamina_mult", 1.0), delta):
			running = false
			can_sprint = false
	elif running and p.vitals.energy <= 0.0:
		running = false
		can_sprint = false
	var target_speed := p.sprint_speed if can_sprint else (p.run_speed if running else p.walk_speed)
	target_speed *= p.statuses.move_mult() * WaterAccess.movement_speed_multiplier(p.global_position)
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

func wants_sprint() -> bool:
	return (Input.is_action_pressed("sprint") or p.sprint_toggled) \
		and not p.statuses.has_flag(&"no_sprint") and not p.in_water

## Buoyancy, continuous swimming stamina, and the exhausted-swimming health consequence.
## ASSUMPTION: swimming costs 6 Energy/s and drowning strain deals 5 Health once per second.
func _tick_swimming(delta: float) -> void:
	if not p.swimming or p.vitals == null:
		_swim_damage_acc = 0.0
		return
	p.velocity.y = 0.0
	var ground_y: float = World.runtime.surface_y(p.global_position.x, p.global_position.z) if World.runtime else -INF
	var float_y := maxf(HarbourSite.WATER_Y + 0.08, ground_y + p.half_height() + 0.05)
	p.global_position.y = move_toward(p.global_position.y, float_y, 4.0 * delta)
	if p.vitals.drain_energy(6.0, delta):
		_swim_damage_acc = 0.0
		return
	_swim_damage_acc += delta
	while _swim_damage_acc >= 1.0:
		_swim_damage_acc -= 1.0
		p.vitals.take_damage(5.0)

## Steering while routed. Neither router promises a walkable answer: the tile graph returns a
## degenerate route when the goal tile is occupied (a bush and its collider sit on it), and
## NavigationAgent3D does the same when its map is not ready. Walk straight at the goal in both
## cases, and give up rather than freeze.
func _nav_dir(delta: float, dir: Vector3) -> Vector3:
	if p.swimming or WaterAccess.in_water(p._path_goal):
		var water_remain := p._path_goal - p.global_position
		water_remain.y = 0.0
		if water_remain.length() <= _arrive_tolerance():
			p.nav_active = false
			p.actions.on_arrived()
			return Vector3.ZERO
		return water_remain.normalized()
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
		if _sleep_pending != null:
			var spot := _sleep_pending
			_sleep_pending = null
			start_sleep(spot)
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
	# Typing in a text field (the pet Rename) must not walk her: the field takes the keys, polling still sees them.
	if p.get_viewport().gui_get_focus_owner() is LineEdit:
		return Vector2.ZERO
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
## its stagger) or a work clip, buffers RollRules.buffer_s() while another roll finishes, says why
## when refused.
func try_roll(dir: Vector3 = Vector3.ZERO) -> bool:
	var why := roll_refusal()
	if why == "busy":
		# A press while another roll is in flight waits RollRules.buffer_s() for it to finish.
		_roll_buffer_left = RollRules.buffer_s()
		_roll_buffer_dir = dir
		return false
	_roll_buffer_left = 0.0
	if why != "":
		if why != "dead":
			p.notice(why)
		return false
	if not p.vitals.spend_energy(RollRules.stamina()):
		p.notice("Out of stamina.")
		return false
	dir.y = 0.0
	# OWNER RULE 2026-10-28: the roll is directional. Held input rolls that way; with no direction
	# she rolls BACKWARD, away from where she faces, and keeps her facing (the body moves back, she
	# does not spin round first). There is no dedicated back-roll clip, so the roll clip plays as is.
	roll_backward = dir.length_squared() < 0.0001
	if roll_backward:
		dir = p.visual.global_basis.z
		dir.y = 0.0
	_roll_direction = dir.normalized()
	if not roll_backward:
		p.visual.rotation.y = atan2(-_roll_direction.x, -_roll_direction.z)
	p.rolling = true
	_roll_left = RollRules.seconds()
	_roll_elapsed = 0.0
	_roll_cd_left = RollRules.cooldown_s()  # counted from the press: no chaining after the dash
	_stagger_left = 0.0
	p.clear_nav()
	p.actions.cancel_work()  # a swing in flight is lost: Hunt checks rolling when it would land
	var speed := RollRules.speed_at(0.0)
	p.velocity.x = _roll_direction.x * speed
	p.velocity.z = _roll_direction.z * speed
	# Roll through creatures: collision exceptions with everything close, restored at the end.
	for n in p.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and p.global_position.distance_to(c.global_position) < 8.0:
			p.add_collision_exception_with(c)
			_roll_through.append(c)
	if p.anim:
		p.anim.on_roll()
		var ap := p.rig.anim_player if p.rig else null
		var rc: StringName = p.anim.current_clip if p.anim.current_clip in [&"roll", &"roll_back"] else &"roll"
		if ap and ap.has_animation(rc):
			ap.speed_scale = maxf(1.0, ap.get_animation(rc).length / RollRules.seconds())
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
	if _roll_cd_left > 0.0:
		return "Roll on cooldown (%.1fs)." % _roll_cd_left
	if p.statuses.has_flag(&"no_roll"):
		return "Too hampered to roll."
	return ""

func roll_left() -> float:
	return _roll_left

## True when the current (or last) roll was the no-input backward roll: the facing stays put.
var roll_backward: bool = false

## Seconds since this roll began; the opening RollRules.iframes_s() of it dodge creature hits.
func roll_elapsed() -> float:
	return _roll_elapsed if p.rolling else -1.0

## True while a creature hit landing now would be dodged (the live dash, never a stale one).
func roll_invulnerable() -> bool:
	return p.rolling and RollRules.invulnerable_at(_roll_elapsed)

## Seconds until another roll is allowed, counted from the press (RollRules.cooldown_s()).
func roll_cooldown_left() -> float:
	return _roll_cd_left

func _end_roll() -> void:
	p.rolling = false
	for c in _roll_through:
		if c and is_instance_valid(c):
			p.remove_collision_exception_with(c)
	_roll_through.clear()
	p.velocity.x *= 0.3
	p.velocity.z *= 0.3
	# The dash is over, so is the oneshot: idle is not a busy clip, the next tick picks locomotion.
	if p.anim and p.anim.current_clip in [&"roll", &"roll_back"]:
		p.anim.play_clip(&"idle")

## Hurt (owner 2026-10-28): a hit stuns her for exactly the hurt clip's length, then she is free to
## walk/run; for HIT_STUN_IMMUNE_S after that, further hits (the combo's 2nd and 3rd bites) still
## damage but cannot stun again, so nothing can chain-stun her. Returns true when this hit stunned.
# ASSUMPTION: 0.8 s of stun immunity after the stun ends.
const HIT_STUN_IMMUNE_S := 0.8

func on_hit() -> bool:
	var now_s := Time.get_ticks_msec() * 0.001
	if p.rolling or now_s < _stagger_immune_until:
		return false
	_stagger_left = hurt_stun_seconds()
	_stagger_immune_until = now_s + _stagger_left + HIT_STUN_IMMUNE_S
	p.clear_nav()
	return true

## The hurt clip's length as PlayerAnim plays it (speed 1); 0.35 s without a rig or clip.
func hurt_stun_seconds() -> float:
	var ap: AnimationPlayer = p.rig.anim_player if p.rig else null
	return ap.get_animation(&"hit_react").length if ap and ap.has_animation(&"hit_react") else 0.35

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
	if WaterAccess.in_water(pos):
		_path_points = PackedVector3Array()
	elif use_tile_path():
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
	_path_points = pathing.path(p.global_position, p._path_goal, 96, true)  # the owner walks through its own walls (HANDOFF 8)
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
## spends a use. No time skip; an interrupted sleep keeps the exhaustion already
## paid out (the restore drains gradually, owner 2026-10-27 — the HUD treadmill
## should run left through the whole sleep, not snap at wake).
## While asleep she also heals at the shelter rest rate (data/rest.json, RestState.heal);
## exhaustion moves only by the sleep's own drain above, never by the rest rate too.
func _tick_sleep(delta: float) -> void:
	var hurt := (Time.get_ticks_msec() * 0.001 - p._last_hit_taken_s) < 1.0
	if input_vector().length_squared() > 0.04 or p.nav_active or p.vitals.in_combat or hurt or p.dead \
			or not is_instance_valid(_sleep_spot) or p.global_position.distance_to(_sleep_spot.global_position) > 3.2:
		var slept := _sleep_dur - p._sleep_left
		p._sleep_left = 0.0
		_sleep_drained = 0.0
		var left := _sleep_spot
		_sleep_spot = null
		_wake_at(left)
		if p.anim:
			p.anim.wake_from_sleep()
		p.notice("Sleep interrupted")
		if not (p.vitals.in_combat or hurt or p.dead):  # got up on purpose: a long enough nap still counts
			rest.grant_well_rested(_sleep_f0 - p.vitals.fatigue, slept)
		return
	# Payout across the duration: every tick eases exhaustion linearly, so a straw
	# roll (65 pts / 12 s) drops ~5.4 pts per second and the belt reads the slope
	# directly. A completed sleep lands the tiny float remainder exactly.
	var spot: Node3D = _sleep_spot
	if _sleep_dur > 0.0 and _sleep_drained < spot.sleep_restore():
		var step: float = spot.sleep_restore() * delta / _sleep_dur
		p.vitals.rest(step)
		_sleep_drained += step
	p._sleep_left = maxf(0.0, p._sleep_left - delta)
	rest.heal(&"shelter", delta)
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	p.move_and_slide()
	if p._sleep_left <= 0.0:
		_sleep_spot = null
		_wake_at(spot)
		p.vitals.rest(maxf(0.0, spot.sleep_restore() - _sleep_drained))
		_sleep_drained = 0.0
		spot.complete_sleep()
		if p.anim:
			p.anim.wake_from_sleep()
		p.notice("Rested")
		rest.grant_well_rested(_sleep_f0 - p.vitals.fatigue, _sleep_dur)

## The running sleep's exhaustion drain per minute (restore / duration), for the HUD; 0 when awake.
func sleep_fatigue_per_min() -> float:
	if p._sleep_left <= 0.0 or not is_instance_valid(_sleep_spot) or _sleep_dur <= 0.0:
		return 0.0
	return float(_sleep_spot.sleep_restore()) / _sleep_dur * 60.0

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

## How close the survivor must be to the bedding to lie down. The route ends at the tent's collision
## edge, which is ~1.5 m from its centre (2.2 m footprint + capsule radius), so this is a little wider;
## the step onto the anchor below is what actually places them on the bedding.
const SLEEP_REACH := 2.2

func start_sleep(spot: Node3D = null) -> void:
	if spot == null:
		spot = nearest_sleep_spot()
	if spot == null or not is_instance_valid(spot) or not spot.is_in_group("sleep_spot") or int(spot.get("sleeps_left")) == 0:
		return
	var anchor: Vector3 = spot.sleep_anchor() if spot.has_method("sleep_anchor") else spot.global_position
	if p.global_position.distance_to(anchor) > SLEEP_REACH:
		# Sleep from anywhere: walk to the bedding, then lie down (the route ending calls start_sleep).
		_sleep_pending = spot
		p.gather_target = null
		nav_to(anchor)
		p.notice("Walking to sleep")
		return
	_sleep_pending = null
	# Lie IN the bedding: step onto its centre at the survivor's own standing height. The anchor is a
	# GROUND point (a tent's origin is its ground centre), so copying it verbatim drops the capsule
	# through the floor.
	if p.global_position.distance_to(anchor) > 0.15:
		_stand_offset = p.global_position.y - _surface_y(p.global_position)
		p.global_position = Vector3(anchor.x, _surface_y(anchor) + _stand_offset, anchor.z)
	if p.vitals.in_combat or (Time.get_ticks_msec() * 0.001 - p._last_hit_taken_s) < 5.0 or p.dead:
		p.notice("Can't sleep in combat")
		return
	if p.vitals.fatigue < 1.0:
		p.notice("Already rested")
		return
	rest.stop(false)  # from sitting straight to lying down
	p.clear_nav()
	p.actions.cancel_work()
	_sleep_spot = spot
	_sleep_dur = maxf(0.01, spot.sleep_duration())
	_sleep_drained = 0.0
	_sleep_f0 = p.vitals.fatigue
	p._sleep_left = _sleep_dur
	if p.anim:
		p.anim.start_sleep()
	p.notice("Sleeping - move to wake")

func _surface_y(at: Vector3) -> float:
	if World.runtime and World.runtime.has_method("surface_y"):
		return float(World.runtime.surface_y(at.x, at.z))
	return at.y

## Stand up outside the bedding: the tent is too low to stand in, so waking steps the survivor out
## onto the door side before the wake clip plays.
func _wake_at(spot: Node3D) -> void:
	if spot == null or not is_instance_valid(spot):
		return
	var at: Vector3 = spot.wake_anchor() if spot.has_method("wake_anchor") else spot.global_position
	p.global_position = Vector3(at.x, _surface_y(at) + _stand_offset, at.z)

func interrupt_sleep() -> void:
	p._sleep_left = 0.0
	_sleep_spot = null
	_sleep_pending = null
	rest.stop()  # hurt or dead: a rest ends too, with the stand-up

# ---------------------------------------------------------------- autofeed

## Offer quick food when energy is low or exhaustion is high, outside combat.
func tick_autofeed(delta: float) -> void:
	_autofeed_cd = maxf(0.0, _autofeed_cd - delta)
	var v := p.vitals
	if _autofeed_cd > 0.0 or v == null or p._sleep_left > 0.0 or rest.resting or p.dead \
			or (v.energy > v.max_energy * 0.5 and v.fatigue < v.max_fatigue * 0.6):
		return
	if p.eat_session == null or p.eat_session.eating or p.nav_active or p._gathering or Vector2(p.velocity.x, p.velocity.z).length() > 0.3:
		return
	if p.hunt and p.hunt.target:
		return
	for fid in p.inventory.quick_food:
		if str(fid) == "":
			continue
		var idx := p.inventory.find_first(StringName(str(fid)))
		if idx >= 0 and Food.can_eat(p, p.inventory.slots[idx]) == "":
			if p.actions.eat(idx):
				var def := Data.item(StringName(str(fid)))
				p.notice("Auto-eating %s" % (def.display_name if def else str(fid)))
				_autofeed_cd = 12.0
				return
	_autofeed_cd = 3.0

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
	# Kept as a call-site-compatible hook: deep water is now traversable by swimming.
	pass
