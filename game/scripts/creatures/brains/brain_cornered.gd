class_name BrainCornered
extends RefCounted
## CORNERED (owner 2026-10-31: "Animals that run away from you should get territorial and attack you if you
## chase them"). Chase pressure, owned by one CreatureBrain (brain.cornered) so every brain that flees gets it.
## While the animal flees, a threat that keeps after it (inside radius_m and moving at it, or hitting it) builds
## pressure; at pressure_s seconds, or chase_m metres of pursuit, it turns, makes its threat display and fights
## with its own attacks for fight_s. Under weak_frac HP it runs again. Thresholds: ai.json default.cornered,
## overridden per species or archetype by a "cornered" block in the tactics profile.

var cfg: Dictionary = {}
var pressure := 0.0  ## seconds of pursuit (hits add hit_s)
var chased_m := 0.0  ## metres the threat covered while pressing
var fight_until := -1.0
var _last_press := -INF  ## when the threat last pressed it (carry_s)
var _b: CreatureBrain
var _prev := Vector3.INF

func _init(brain: CreatureBrain) -> void:
	_b = brain

func setup() -> void:
	cfg = (_b.profile.get("cornered", {}) as Dictionary).duplicate()
	var over: Variant = TacticalBrain.tactics_for_def(_b.creature.def).get("cornered", {})
	if over is Dictionary:
		cfg.merge(over as Dictionary, true)

func _f(key: String, fallback: float) -> float:
	return float(cfg.get(key, fallback))

func fighting() -> bool:
	return _b._now_s() < fight_until

func _weak() -> bool:
	return _b.creature.health.fraction() < _f("weak_frac", 0.3)

## A hit while it runs is pursuit too.
func on_hit() -> void:
	if _b.state == &"flee":
		pressure += _f("hit_s", 1.5)

func tick(dt: float) -> void:
	if cfg.is_empty() or not bool(cfg.get("enabled", true)):
		return
	if fighting():
		if _weak():
			# Badly hurt: the fight is over, it runs again (and must be chased again to turn).
			fight_until = -1.0
			_b._provoked_until = -1.0
			if _b._valid_target():
				_b._set_state(&"flee")
		return
	# Tactical flights (a swarm's hurt run, a packmate's death) and a Timid rage come back on their own.
	if _b.state != &"flee" or not _b._valid_target() or _b._holds_flee() or _b._enrage_fled:
		_reset()
		return
	var threat := _b.attack_target
	var here := threat.global_position
	var pressing := false
	if _prev != Vector3.INF and dt > 0.0:
		var moved := Vector2(here.x - _prev.x, here.z - _prev.z)
		var to_me := Vector2(_b.creature.global_position.x - here.x, _b.creature.global_position.z - here.z).normalized()
		pressing = _b._flat_dist(threat) <= _f("radius_m", 10.0) and moved.dot(to_me) / dt >= _f("pursuit_mps", 1.5)
		if pressing:
			chased_m += moved.length()
	_prev = here
	if pressing:
		pressure += dt
		_last_press = _b._now_s()
	else:
		pressure = maxf(0.0, pressure - dt * _f("decay", 0.5))
	if (pressure >= _f("pressure_s", 3.0) or chased_m >= _f("chase_m", 20.0)) and not _weak():
		_turn(threat)

## carry_s (SP-GALLIMIMUS): a runner fast enough to outrun every chase in one burst stops, is caught up with and bolts
## again; its pressure and metres carry over between those flights while the last press is under carry_s old.
func _reset() -> void:
	_prev = Vector3.INF
	if _b._now_s() - _last_press < _f("carry_s", 0.0):
		return
	pressure = 0.0
	chased_m = 0.0

## Stop, face the threat in the display clip, then the provoked fight (alert -> approach) runs on the brain's
## own attacks. fight_s is a provocation, so every existing "provoked" rule (stand down, flee again) applies.
func _turn(threat: Node3D) -> void:
	_last_press = -INF
	_reset()
	fight_until = _b._now_s() + _f("fight_s", 12.0)
	_b._provoked_until = maxf(_b._provoked_until, fight_until)
	_b.attack_target = threat
	_b._combat_memory_left = 4.0
	_b.creature.stop_move()
	_b._set_state(&"alert")
	_b._alert_left = _f("display_s", 0.8)
	for clip in cfg.get("display_clips", ["alert"]):
		if _b.creature.anim.has_state(StringName(clip)):
			_b.creature.anim.play_clip(StringName(clip))
			break
	_b._log("[ai] %s cornered: turns on its chaser for %.0fs" % [_b.creature.def.id, _f("fight_s", 12.0)])
	if _b is TacticalBrain:
		(_b as TacticalBrain)._seq = []
		(_b as TacticalBrain).tactic.emit(&"cornered")
