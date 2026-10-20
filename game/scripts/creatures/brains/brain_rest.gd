class_name BrainRest
extends RefCounted
## The quiet half of CreatureBrain: night sleep, waking, and the AI LOD freeze. Static helpers
## on the brain so the state machine file stays about fighting and fleeing.

## Idle brains farther than this from every player stop thinking (AI LOD).
const LOD_RADIUS := 60.0

## Idle and nobody within LOD_RADIUS: skip the think. Combat, flight and pets never freeze, and
## a scene with no player at all keeps thinking (tests, tools).
static func lod_frozen(b: CreatureBrain) -> bool:
	var c := b.creature
	if c.is_pet or not (b.state == &"roam" or b.state == &"sleep") or b._valid_target():
		return false
	var players := c.get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	for p in players:
		if p is Node3D and (p as Node3D).global_position.distance_squared_to(c.global_position) <= LOD_RADIUS * LOD_RADIUS:
			return false
	return true

## ai.json schedule: diurnal sleeps at night, nocturnal sleeps by day, cathemeral never sleeps.
## ASSUMPTION: without a schedule grazers are diurnal and predators cathemeral (the old rule).
static func schedule(b: CreatureBrain) -> StringName:
	return StringName(str(b.profile.get("schedule", "diurnal" if b._is_herbivore() else "cathemeral")))

static func sleeper(b: CreatureBrain) -> bool:
	return schedule(b) != &"cathemeral"

## Its rest time now. Dawn and dusk are awake for everyone (twilight is when both hunt).
static func resting_now(b: CreatureBrain) -> bool:
	match schedule(b):
		&"diurnal":
			return Game.phase_name() == &"night"
		&"nocturnal":
			return Game.phase_name() == &"day"
	return false

static func should_sleep(b: CreatureBrain) -> bool:
	return resting_now(b) and b._now_s() >= b._awake_until \
		and not b._valid_target() and (b.state == &"roam" or b.state == &"disengage")

## Asleep: stay put. The end of its rest time wakes it; a survivor or pet within wake_m of the
## body wakes this one (a skittish grazer bolts, a predator comes at it).
static func sleep_tick(b: CreatureBrain) -> void:
	b.creature.stop_move()
	if not resting_now(b):
		wake(b, null)
		return
	var near := b._nearest_live_prey(float(b.profile.get("wake_m", 3.0)) + b.creature.body_radius())
	if near:
		wake(b, near)

static func wake(b: CreatureBrain, who: Node3D) -> void:
	keep_awake(b)
	b._roam_target = Vector3.ZERO
	b._roam_cd = randf_range(0.1, 0.6)
	b._set_state(&"roam")
	if who:
		b._spot(who)

## Woken, or hurt: no dozing off again for woken_awake_s.
static func keep_awake(b: CreatureBrain) -> void:
	b._awake_until = maxf(b._awake_until, b._now_s() + float(b.profile.get("woken_awake_s", 30.0)))
