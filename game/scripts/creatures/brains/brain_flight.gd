class_name BrainFlight
extends RefCounted
## Flight, the leash and the temporary home, owned by one CreatureBrain (brain.flight).
## Kept out of creature_brain.gd so the state machine file stays about choosing a state.

## After a leash break nobody in the pack may re-acquire for this long (no flicker on the line).
const REACQUIRE_HOLD_S := 0.5
## ASSUMPTION: the post-kill / post-flight temporary home lasts two minutes, then the real one returns.
const TEMP_HOME_S := 120.0
## A grazer hit in the last FRESH_HIT_S keeps fleeing even past the leash: a shot from beyond the
## ring is still a reason to run, not to walk home.
const FRESH_HIT_S := 3.0

var reacquire_at: float = -1.0
var home_until: float = 0.0
var _b: CreatureBrain
var _disengage_left: float = 0.0
var _true_home: Vector3 = Vector3.ZERO

func _init(brain: CreatureBrain) -> void:
	_b = brain

func can_reacquire() -> bool:
	return _b._now_s() >= reacquire_at

## The temporary home ran out: the real one returns.
func tick_home() -> void:
	if home_until > 0.0 and _b._now_s() >= home_until:
		_b.creature.spawn_home = _true_home
		home_until = 0.0

func set_temp_home(pos: Vector3) -> void:
	if home_until <= 0.0:
		_true_home = _b.creature.spawn_home
	_b.creature.spawn_home = pos
	home_until = _b._now_s() + TEMP_HOME_S

## Aggro leash: beyond aggro_radius the chase ends at once; beyond 1.2 x perception it ends
## after disengage_seconds. Running far enough away always works.
func track(delta: float) -> void:
	if not _b._valid_target():
		_disengage_left = 0.0
		return
	var dist := _b._flat_dist(_b.attack_target)
	if dist > _b.aggro_radius() and not fresh():
		_b._log("[ai] %s disengage (left aggro radius)" % _b.creature.def.id)
		leash_break()
		return
	# A fleeing animal runs until the threat is past the leash; the slow give-up is for chasers.
	var far := dist > _b._effective_perception() * 1.2 and not _b.attack_target is FieldCatapult and _b.state != &"flee"
	if far:
		_disengage_left += delta
		if _disengage_left >= float(_b.profile.get("disengage_seconds", 3.0)):
			end()
	else:
		_disengage_left = 0.0

## A grazer that was just hit runs from the hit, wherever the shooter stands.
func fresh() -> bool:
	return _b._is_herbivore() and (_b.state == &"alert" or _b.state == &"flee") and _b._now_s() - _b._last_hit_s < FRESH_HIT_S

## The target crossed the pack's one leash: everyone on that target lets go together and none
## re-acquires for REACQUIRE_HOLD_S. Per-member breaks made followers flicker on the line.
func leash_break() -> void:
	var lost := _b.attack_target
	let_go()
	for c in _b._pack_members():
		if c != _b.creature and c.brain and c.brain.attack_target == lost:
			c.brain.flight.let_go()

## Leaving the visible combat radius is an immediate de-aggro, not a walk-home chase.
## Clear target/memory now so neither this animal nor pack retention reacquires the runner.
func let_go() -> void:
	_b.attack_target = null
	_b._combat_memory_left = 0.0
	_disengage_left = 0.0
	reacquire_at = _b._now_s() + REACQUIRE_HOLD_S
	_b.creature.mark_aggro_now()
	end()

## End a fight or a flight. A fleeing animal stops where it is and treats that spot as home for
## a while instead of walking back past the threat; everyone else walks home.
func end() -> void:
	if _b.state == &"flee":
		set_temp_home(_b.creature.global_position)
		_b.attack_target = null
		_b.creature.stop_move()
		_b._set_state(&"roam")
	else:
		_b._set_state(&"disengage")

func walk_home() -> void:
	var c := _b.creature
	c.move_to(c.spawn_home)
	if _b._flat_dist_to(c.spawn_home) <= 1.0:  # flat: a home's y can sit off the terrain
		_b._set_state(&"roam")
		_b.attack_target = null
		_disengage_left = 0.0
		_b._hits_taken = 0
		_b._provoked_until = -1.0

## Run from the last damage source (or whatever was spotted), straight away from it. The
## target point comes from our own position, not the herd centre, so nothing clamps the run.
func flee() -> void:
	if not _b._valid_target():
		end()
		return
	if _b._provoked() and not _b._holds_flee():
		_b._set_state(&"approach")
		return
	var here := _b.creature.global_position
	var away := here - _b.attack_target.global_position
	away.y = 0.0
	if away.length_squared() <= 0.001:
		away = Vector3.BACK
	var flee_dist := float(_b.profile.get("flee_tiles", 8.0))
	var picked := _b._walkable_probe(here, here + away.normalized() * flee_dist, int(flee_dist) + 4)
	if picked == here and _b._cornered():
		_b._set_state(&"attack")
		return
	_b.creature.move_to(picked)
