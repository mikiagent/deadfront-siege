class_name JoustBrain
extends TacticalBrain
## JOUST (MEGAJOUST, owner 2026-10-31: "a deer would normally charge and do a circle and charge again. Like a joust";
## "the jousting brain is good for many of the four legged animals"). Any quadruped opts in with a "joust" block in
## its tactics profile (Creature._make_brain). No strafe, no side jumps, no back-leaps: the fight is a loop of passes.
##   tell    charge_crouch where the rig has it (else the run starts at once), body still, turning to the threat
##   pass    the straight charge (TacticalBrain._charge) through the threat and overshoot_m past it; contact is the
##           ram impact (hit_mult, shove_m: PlayerSim.shove, so a heavy shove knocks down where that is built)
##   run off (run_off_s, the megaloceros doe's desperate flight) straight on away from the threat
##   wheel   a wide turn at the run on run_turn_left/right where the rig has them (planted hooves follow the arc: the
##           clips are authored on turn_radius_m), else the run, until it faces the threat from min_run_m; then the tell
## The wheel lives in the circle state (TacticalBrain's dispatch reaches it as _circle). Point blank (the threat walked
## up during the tell or after a pass) the profile's point_blank moves still go. Tame and ride use PetBrain.
## joust keys (every number an ASSUMPTION per species): turn_radius_m, overshoot_m, min_run_m, align_deg, wheel_max_s,
## run_off_s, display (open a fight with the display), display_after_s, charge_max_s, hit_mult, shove_m, toss_deg.
## A variant's tactics.joust merges over the species' (megaloceros doe).

## Passes run (tests, labs) and the joust beat now: &"run_off" or &"wheel".
var passes := 0
var phase: StringName = &""
var joust: Dictionary = {}
var _heading := Vector3.FORWARD
var _turn_sign := 1.0  ## +1 wheels to its left
var _last_pass_s := -999.0
## A point on the heading the body faces while it wheels (strafe_face): the velocity-following yaw lags a turn by
## ~10 deg (Creature FACE_VEL_TAU_S), a crab that slid planted hooves ~25 cm sideways per stance.
var _aim := Node3D.new()

static func wants(def: CreatureDef) -> bool:
	return def != null and TacticalBrain.tactics_for_def(def).get("joust") is Dictionary

func setup(c: Creature) -> void:
	super.setup(c)
	add_child(_aim)
	joust = (TacticalBrain.tactics_for_def(c.def).get("joust", {}) as Dictionary).duplicate()
	var over: Variant = (CreatureView.variant_row(c.def, c.variant).get("tactics", {}) as Dictionary).get("joust")
	if over is Dictionary:
		joust.merge(over, true)
	# the pass is TacticalBrain's straight charge, driven by these keys
	tac = tac.duplicate(true)
	tac["charge_straight"] = true
	for pair in [["overshoot_m", "charge_through_m"], ["charge_max_s", "charge_max_s"], ["hit_mult", "charge_mult"], ["shove_m", "charge_shove_m"], ["toss_deg", "charge_toss_deg"]]:
		if joust.has(pair[0]):
			tac[pair[1]] = joust[pair[0]]
	# The pass goes through her: the hit throws her off the line (carnotaurus' charge_toss_deg) so the runner carries on
	# past instead of stopping dead against her body (the lab: a survivor standing in the line held it for the whole
	# charge_max_s). ASSUMPTION 30 deg unless the profile says.
	if not tac.has("charge_toss_deg"):
		tac["charge_toss_deg"] = 30.0
	# a grazer defends guard_m round home; the joust carries the fight an overshoot and a wheel further out
	if tac.has("guard_m"):
		tac["guard_m"] = float(tac["guard_m"]) + 2.0 * _j("turn_radius_m", 9.0) + _j("overshoot_m", float(tac.get("charge_through_m", 2.5)))

## A fight in progress holds out to where a joust goes: a run off, an overshoot, a full wheel and the run-up to the
## next pass (the leash and the far-give-up, BrainFlight.track). Spotting prey (no target yet) keeps the normal radius.
func _jousting() -> bool:
	return attack_target != null and state in [&"circle", &"charge", &"approach", &"display", &"attack"]

func _joust_reach() -> float:
	return _j("run_off_s", 0.0) * creature.move_speed_mps() + _j("overshoot_m", 2.5) \
		+ 2.0 * _j("turn_radius_m", 9.0) * creature.size_scale() + _j("min_run_m", 8.0) + 5.0

func aggro_radius() -> float:
	return maxf(super.aggro_radius(), _joust_reach()) if _jousting() else super.aggro_radius()

func _effective_perception() -> float:
	return maxf(super._effective_perception(), _joust_reach() / 1.2) if _jousting() else super._effective_perception()

func _j(key: String, fallback: float) -> float:
	return float(joust.get(key, fallback))

func _fwd() -> Vector3:
	var f := -creature.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD

## Every way back into the fight (the ring reached, a display or hold over, a sequence done) lands here.
func _enter_circle(_hold: float = -1.0) -> void:
	if not _valid_target():
		_set_state(&"roam")
		return
	var d := _flat_dist(attack_target)
	if d <= reach_to(attack_target) and _strike(d, tac.get("point_blank", [])):
		return
	# A fresh fight opens with the display (the stag's rut roar), then the first pass.
	if joust.get("display", false) and _now_s() - _last_pass_s > _j("display_after_s", 20.0) and state != &"display" \
			and creature.anim.has_state(&"alert"):
		_last_pass_s = _now_s()
		_seq = ["display", "charge"]
		_seq_i = 0
		_seq_next()
		return
	if d >= _j("min_run_m", 8.0) and _fwd().dot(-_to_me()) >= cos(deg_to_rad(_j("align_deg", 25.0))):
		_pass()
		return
	_start_wheel(false)

func _pass() -> void:
	_last_pass_s = _now_s()
	phase = &""
	_start_charge()  # the charge_crouch tell where the rig has it, then the locked line
	tactic.emit(&"joust_pass")

## run_off: a flight straight on first (run_off_s), else straight into the wheel.
func _start_wheel(run_off: bool) -> void:
	_set_state(&"circle")
	_circle_t = 0.0
	_seq = []
	phase = &"run_off" if run_off and _j("run_off_s", 0.0) > 0.0 else &"wheel"
	_heading = _to_me() if phase == &"run_off" else _fwd()
	var right := Vector3(-_heading.z, 0.0, _heading.x)
	var side := right.dot(-_to_me())
	_turn_sign = -1.0 if side > 0.1 else (1.0 if side < -0.1 else _circle_sign)  # wheel towards the threat's side
	tactic.emit(StringName("joust_" + str(phase)))

func _circle(delta: float) -> void:
	if not _valid_target():
		_set_state(&"roam")
		return
	_circle_t += delta
	var v := creature.move_speed_mps()
	speed_override = v
	var ahead := maxf(4.0, v * 0.6)  # a near carrot: direct steering works without a navmesh (Creature, 12 m)
	if phase == &"run_off":
		gait_clip = &"run"
		if _circle_t < _j("run_off_s", 0.0):
			_steer(ahead)
			return
		phase = &"wheel"
		_circle_t = 0.0
		tactic.emit(&"joust_wheel")
	var r := _j("turn_radius_m", 9.0) * creature.size_scale()
	_heading = _heading.rotated(Vector3.UP, _turn_sign * v / r * delta).normalized()
	gait_clip = &"run_turn_left" if _turn_sign > 0.0 else &"run_turn_right"  # a rig without them runs (set_gait_clip)
	_steer(ahead)
	var lined_up := _heading.dot(-_to_me()) >= cos(deg_to_rad(_j("align_deg", 25.0)))
	# A threat that follows it round stays close (or inside the wheel, never lined up): lined up after half the wheel
	# time it passes from wherever it is, and after wheel_max_s it passes anyway (the tell turns it to face her first).
	var wmax := _j("wheel_max_s", 9.0)
	if (lined_up and (_flat_dist(attack_target) >= _j("min_run_m", 8.0) or _circle_t >= 0.5 * wmax)) or _circle_t >= wmax:
		_pass()

func _steer(ahead: float) -> void:
	creature.move_to(creature.global_position + _heading * ahead)
	_aim.global_position = creature.global_position + _heading * 30.0
	strafe_face = _aim

## End of the line, hit or miss: no stagger, no hold, no back-leap; it runs on and wheels for the next pass.
func _charge_end() -> void:
	passes += 1
	if not _charge_hit:
		tactic.emit(&"charge_miss")
	_start_wheel(true)

## After a point-blank strike: away on the wheel, not a hop back.
func _back_off() -> void:
	if _prey_leaving():
		_set_state(&"approach")
	else:
		_start_wheel(true)

func _start_dodge(_side: float) -> void:
	_beat()
	if _seq.is_empty():
		_start_wheel(false)
	else:
		_seq_next()

func _start_hop(then: StringName = &"circle", _long: bool = false, _dist_mult: float = 1.0) -> void:
	if then == &"seq" and not _seq.is_empty():
		_seq_next()
	else:
		_start_wheel(then == &"retreat")

func _start_feint() -> void:
	_start_wheel(false)

func _start_retreat(_seconds: float) -> void:
	_retreat_cd = _t("retreat_cd", 10.0)
	_start_wheel(true)

## The wheel runs away from the threat half the time: that is the joust, not the threat leaving.
func _prey_leaving() -> bool:
	return false if state == &"circle" else super._prey_leaving()
