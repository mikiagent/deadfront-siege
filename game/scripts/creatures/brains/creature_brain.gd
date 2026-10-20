class_name CreatureBrain
extends Node
## Archetype-driven roam / alert / approach / attack / retreat / flee / disengage / sleep.
## Brains think at 10 Hz (staggered across frames) and freeze while idle farther than
## LOD_RADIUS from every player. Species overrides replace _think only; the shared rules
## (leash, sleep, walk home, timers) run first in _pre_think so no override can skip them.

## Every state transition, exactly once (creature voices and plates hook here).
signal state_changed(prev: StringName, next: StringName)

const THINK_HZ := 10
## Idle brains farther than this from every player stop thinking (AI LOD, see BrainRest).
const LOD_RADIUS := BrainRest.LOD_RADIUS
## Reach numbers were tuned against the survivor capsule (player.tscn radius 0.35); bigger
## bodies add their extra radius so pets and wild animals can reach a giant's flank.
const SURVIVOR_RADIUS := 0.35
## Herbivores flee, but after provoke_hits hits (ai.json temperament) within a short window
## they turn and fight for PROVOKE_SECONDS, then go back to their temperament.
const PROVOKE_HITS := 3
const PROVOKE_SECONDS := 15.0
## Calm states: a hit, a sighting or a herd alarm pulls an animal out of these into alert.
const CALM_STATES: Array[StringName] = [&"roam", &"sleep", &"disengage", &"eat_corpse", &"graze", &"drink", &"warn"]
## On the survivor or a pet (aggro ring, post-kill retreat).
const HUNT_STATES: Array[StringName] = [&"alert", &"approach", &"attack", &"retreat", &"siege", &"spit", &"charge", &"tail_sweep", &"lunge", &"roar"]

static var _pack_cooldown_until: Dictionary = {} ## pack_id -> seconds

var creature: Creature
var state: StringName = &"roam"
var attack_target: Node3D
var perception: float = 12.0
var profile: Dictionary = {}
var _roam_cd: float = 0.0
var _roam_pause: float = 0.0
var _roam_target: Vector3 = Vector3.ZERO
var _attack_cd: float = 0.0
var _alert_left: float = 0.0
var _retreat_left: float = 0.0
var _damage_window: Array[Dictionary] = []
var _primary_chain: int = 0
var _target_prev: Vector3 = Vector3.ZERO
var _target_still_left: float = 0.0
var _flank_sign: float = 1.0
var _last_flank_log_s: float = -999.0
var _combat_memory_left: float = 0.0
var _hits_taken: int = 0
var _last_hit_s: float = -999.0
var _provoked_until: float = -1.0
var _retarget_cd: float = 0.0
var _think_phase: int = 0
var _think_dt: float = 0.0
var _dt: float = 0.0
var _awake_until: float = -1.0
## Flight, leash and temporary home (see BrainFlight).
var flight := BrainFlight.new(self)
## W2-ECO layers: hunger/thirst errands, sight and hearing, species attack moves, structures.
var needs := EcoNeeds.new(self)
var sense := EcoSense.new(self)
var kit := AttackKit.new(self)
var siege := BrainSiege.new(self)
## The structure a siege is breaking (null when none).
var siege_target: Node3D:
	get:
		return siege.target

func _provoked() -> bool:
	return _now_s() < _provoked_until

func setup(c: Creature) -> void:
	creature = c
	profile = _profile(c.def.ai_archetype())
	profile.merge(c.def.eco(), true)  # the species row (diet, schedule, attacks) wins
	perception = float(profile.get("perception_base", 8.0)) + float(c.def.tier) * float(profile.get("perception_tier_mult", 0.15))
	_flank_sign = -1.0 if int(c.get_instance_id()) % 2 == 0 else 1.0
	# Start walking promptly. The old full roam delay made newly spawned dinosaurs look frozen.
	_roam_cd = randf_range(0.1, 0.6)
	_think_phase = randi() % _think_every()
	if not c.is_pet:
		kit.setup()
		siege.setup()

## The player stays on the ground until respawn. Relocate every dinosaur that was fighting
## them so the camp/respawn point cannot become a permanent death trap.
func on_player_killed(at: Vector3) -> void:
	if creature == null or creature.health.dead or creature.is_pet:
		return
	var was_hunting := attack_target is Player or state in HUNT_STATES
	if not was_hunting:
		return
	var away := creature.global_position - at
	away.y = 0.0
	if away.length_squared() <= 0.001:
		away = Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	var distance := maxf(14.0, aggro_radius() + 4.0)
	var destination := creature.global_position + away.normalized() * distance
	var rt := World.runtime if World else null
	if rt and rt.has_method("spawn_ok"):
		var found := false
		for shorten in [1.0, 0.8, 0.6, 0.4]:
			for angle in [0.0, 0.45, -0.45, 0.9, -0.9]:
				var probe: Vector3 = creature.global_position + away.normalized().rotated(Vector3.UP, angle) * distance * shorten
				probe.y = rt.surface_y(probe.x, probe.z) + 0.3 if rt.has_method("surface_y") else creature.global_position.y
				if rt.spawn_ok(probe, false):
					destination = probe
					found = true
					break
			if found:
				break
	attack_target = null
	_combat_memory_left = 0.0
	_hits_taken = 0
	_provoked_until = -1.0
	# The retreat spot is home for a while so idle roam does not walk straight back to camp.
	flight.set_temp_home(destination)
	_set_state(&"disengage")
	creature.move_to(destination)
	_log("[ai] %s post-kill retreat %.1fm" % [creature.def.id, creature.global_position.distance_to(destination)])

func _effective_perception() -> float:
	var p := perception
	if Game.phase_name() == &"night" and bool(profile.get("night_predator_bonus", true)) and not _is_herbivore():
		p *= 1.0 + float(Data.world_rules.get("night_predator_perception_bonus", 0.5))
	return p

func _is_herbivore() -> bool:
	return bool(profile.get("is_herbivore", false))

func _flees_on_sight() -> bool:
	return _is_herbivore() and bool(profile.get("flee_on_sight", true))

## Leash radius: past this the chase ends at once (see BrainFlight.track). Drawn as the red
## dotted ring while the creature is on the survivor. A pack shares its alpha's leash.
func aggro_radius() -> float:
	var leader := _pack_leader()
	var src: CreatureBrain = leader.brain if leader and leader != creature and leader.brain else self
	return maxf(26.0 if attack_target is FieldCatapult else 0.0, src._effective_perception() * float(src.profile.get("leash_mult", 2.2)))

## True while this creature is actively on the survivor (ring shown).
func hunting_player() -> bool:
	if attack_target == null or not is_instance_valid(attack_target):
		return false
	var on_player := attack_target is Player and not (attack_target as Player).dead
	var on_pet := attack_target is Creature and (attack_target as Creature).is_pet and not (attack_target as Creature).health.dead
	var on_siege := attack_target is FieldCatapult and (attack_target as FieldCatapult).hp > 0
	if not (on_player or on_pet or on_siege):
		return false
	return state in HUNT_STATES

func _physics_process(delta: float) -> void:
	if creature == null or creature.health.dead:
		_set_state(&"dead")
		return
	if creature.statuses.has(&"knockdown") or not creature.statuses.can_act():
		_set_state(&"downed")
		creature.stop_move()
		return
	_think_dt += delta
	_face_target(delta)
	if not _should_think(Engine.get_physics_frames()):
		return
	var dt := _think_dt
	_think_dt = 0.0
	if _lod_frozen():
		return
	tick(dt)

## Standing combat states turn every physics frame; thinking at 10 Hz made them snap. The turn
## rates match the old every-frame calls (face_towards(p, delta) and face_towards(p, 0.05) at 60 Hz).
func _face_target(delta: float) -> void:
	if (state == &"alert" or state == &"attack") and not _full_rate() and _valid_target():
		creature.face_towards(attack_target.global_position, delta if state == &"alert" else delta * 3.0)

## One think step: the shared rules, then the species think.
func tick(dt: float) -> void:
	_dt = dt
	if not _pre_think(dt) and not _eco_tick(dt):
		_think(dt)
	creature.brain_state = state

## Layers every wild brain runs before its species think: a special move in progress or one
## that fits, a structure in the way, the needs errands. True when one handled the tick.
func _eco_tick(dt: float) -> bool:
	if creature.is_pet:
		return false
	return kit.tick(dt) or siege.tick(dt) or needs.tick(dt)

## THINK_HZ, staggered by _think_phase; a timed move (_full_rate) thinks every frame.
func _should_think(frame: int) -> bool:
	return _full_rate() or (frame + _think_phase) % _think_every() == 0

## True while a timed move must resolve every physics frame (overrides add their own).
func _full_rate() -> bool:
	return kit.busy()

func _think_every() -> int:
	return maxi(1, int(Engine.physics_ticks_per_second / THINK_HZ))

func _lod_frozen() -> bool:
	return BrainRest.lod_frozen(self)

## Rules every wild brain obeys before its species think: timers, the leash, night sleep and the
## walk home. Returns true when it handled this tick.
func _pre_think(dt: float) -> bool:
	if creature.is_pet:
		return false
	_attack_cd = maxf(0.0, _attack_cd - dt)
	_combat_memory_left = maxf(0.0, _combat_memory_left - dt)
	needs.drain(dt)
	flight.tick_home()
	if state == &"downed":
		_set_state(&"alert" if _valid_target() else &"roam")
	flight.track(dt)
	if state == &"sleep":
		BrainRest.sleep_tick(self)
		return state == &"sleep"
	if BrainRest.should_sleep(self):
		_set_state(&"sleep")
		creature.stop_move()
		return true
	if state == &"disengage":
		flight.walk_home()
		return true
	return false

## Hit by someone other than the current target (a pet biting while it chases the survivor):
## turn on the attacker. Fight what fights you; no running past a biter to reach the survivor.
## attack_target is therefore always the last damage source, which is what flight runs from.
func on_aggro(who: Node) -> void:
	if who is Node3D:
		if attack_target != null and attack_target != who and _valid_target() and _now_s() >= _retarget_cd:
			attack_target = who as Node3D
			_retarget_cd = _now_s() + 2.5
			if state == &"approach" or state == &"attack":
				_log("[ai] %s turns on %s" % [creature.def.id, who.name])
				creature.mark_aggro_now()
				return
		attack_target = who as Node3D
		_combat_memory_left = 4.0
		creature.mark_aggro_now()
		if BrainRest.sleeper(self):
			BrainRest.keep_awake(self)  # hurt animals do not doze off at the leash edge
		# Do not downgrade combat states (retreat/flee/approach/attack) back to alert.
		if state in CALM_STATES or state == &"downed":
			_set_state(&"alert")
			_alert_left = 0.6
			_propagate_alert(who as Node3D)
		elif state == &"alert":
			_alert_left = maxf(_alert_left, 0.35)
			_propagate_alert(who as Node3D)

func note_damage(amount: float) -> void:
	if creature == null or creature.health.dead:
		return
	var now := _now_s()
	if now - _last_hit_s > 8.0:
		_hits_taken = 0
	_last_hit_s = now
	_hits_taken += 1
	if _is_herbivore() and _hits_taken >= int(profile.get("provoke_hits", PROVOKE_HITS)) and not _provoked():
		_provoked_until = now + PROVOKE_SECONDS
		_log("[ai] %s provoked: fights back for %.0fs" % [creature.def.id, PROVOKE_SECONDS])
		if _valid_target():
			_set_state(&"approach")
			creature.anim.play_clip(&"alert")
	_damage_window.append({"t": now, "a": amount})
	var total := 0.0
	for i in range(_damage_window.size() - 1, -1, -1):
		var row := _damage_window[i]
		if now - float(row.get("t", now)) > 2.0:
			_damage_window.remove_at(i)
			continue
		total += float(row.get("a", 0.0))
	var trigger := creature.health.max_hp * float(profile.get("retreat_threshold_frac", 0.3))
	if total >= trigger:
		if _is_herbivore():
			if not _provoked():
				_set_state(&"flee")
		else:
			_set_state(&"retreat")
			_retreat_left = 1.2

func _think(delta: float) -> void:
	# A dead pet is one target, not the end of the hunt. Keep the pack together and immediately
	# select another live pet or the survivor instead of every dinosaur walking home.
	if not _is_herbivore() and not _valid_target() and _combat_memory_left > 0.0 and flight.can_reacquire():
		attack_target = _nearest_live_prey(aggro_radius())
		if attack_target:
			_set_state(&"approach")
	match state:
		&"roam":
			_roam(delta)
			_scan()
		&"alert":
			# Do not call _scan here: refreshing alert_left every frame trapped
			# creatures in alert and blocked approach / flee transitions.
			_alert_left = maxf(0.0, _alert_left - delta)
			if _alert_left <= 0.0:
				if not _is_herbivore() or _provoked():
					_set_state(&"approach")
				elif _flees_on_sight():
					_set_state(&"flee")
				else:
					attack_target = null  # a calm grazer had a look and goes back to grazing
					_set_state(&"roam")
		&"approach":
			if not _valid_target():
				_disengage()
				return
			_approach(delta)
		&"attack":
			_do_attack()
		&"retreat":
			_retreat(delta)
		&"flee":
			flight.flee()
		&"warn":
			_warn_tick()

func _roam(delta: float) -> void:
	# Pack members travel behind their alpha while idle. Only the alpha chooses the roaming path;
	# this keeps a hunting group visibly together instead of several independent random walkers.
	var leader := _pack_leader()
	if leader and leader != creature:
		var slot := _idle_pack_slot(leader)
		if creature.global_position.distance_to(slot) > 1.4:
			creature.move_to(slot)
		else:
			creature.stop_move()
		return
	if _roam_pause > 0.0:
		_roam_pause -= delta
		creature.stop_move()
		return
	if _roam_target != Vector3.ZERO:
		if creature.global_position.distance_to(_roam_target) <= 0.8:
			_roam_target = Vector3.ZERO
			_roam_pause = randf_range(0.25, 0.7)
			_roam_cd = randf_range(0.15, 0.55)
			creature.stop_move()
		return
	_roam_cd -= delta
	if _roam_cd > 0.0:
		return
	var center := _herd_center() if _is_herbivore() else creature.spawn_home
	var roam_tiles := float(profile.get("roam_tiles", 6.0))
	var p := center + Vector3(randf_range(-roam_tiles, roam_tiles), 0.0, randf_range(-roam_tiles, roam_tiles))
	p = _walkable_probe(center, p, int(roam_tiles) + 3)
	_roam_target = p
	creature.move_to(p)
	_roam_cd = randf_range(float(profile.get("roam_delay_min", 3.0)), float(profile.get("roam_delay_max", 6.0)))

## Idle slot around the alpha, spaced by real body radii: clear of the alpha's body and of the
## neighbouring slot (the old fixed 1.8-2.15 m ring let big packmates interpenetrate).
func _idle_pack_slot(leader: Creature) -> Vector3:
	var members := _pack_members()
	var index := members.find(creature)
	var others := maxi(1, members.size() - 1)
	var angle := TAU * float(maxi(0, index - 1)) / float(others)
	var widest := 0.0
	for m in members:
		if m != leader:
			widest = maxf(widest, m.body_radius())
	var radius := leader.body_radius() + widest + 0.6
	if others > 1:
		radius = maxf(radius, (2.0 * widest + 0.6) / (2.0 * sin(PI / float(others))))
	radius += 0.35 * float(index % 2)
	return leader.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius

func _scan() -> void:
	if not (state == &"roam" or needs.busy()) or not flight.can_reacquire():
		return
	# Followers let the alpha acquire prey and path behind it. If prey reaches a follower first,
	# it still alerts the whole pack through on_aggro.
	var leader := _pack_leader()
	if leader and leader != creature:
		if leader.brain and leader.brain._valid_target():
			if _is_herbivore():
				_spot(leader.brain.attack_target)
			else:
				attack_target = leader.brain.attack_target
				_combat_memory_left = 4.0
				_set_state(&"approach")
		return
	var best := _nearest_live_prey(_effective_perception(), true)
	if best:
		_spot(best)

## A survivor or pet is in sight (or woke us). Predators and territorial grazers come at it,
## skittish grazers start and then flee, defensive grazers keep grazing until they are hit.
func _spot(who: Node3D) -> void:
	if _is_herbivore() and not _flees_on_sight():
		var territory := float(profile.get("territory_m", 0.0))
		if territory <= 0.0:
			return
		if _surface_dist(who) > territory:
			if _surface_dist(who) <= float(profile.get("warn_m", 0.0)) and state != &"warn":
				attack_target = who
				_warn_left = 0.0
				_set_state(&"warn")
			return
		_provoked_until = maxf(_provoked_until, _now_s() + PROVOKE_SECONDS)
	attack_target = who
	_combat_memory_left = 4.0
	_set_state(&"alert")
	_alert_left = maxf(_alert_left, 0.6)
	creature.mark_aggro_now()
	creature.anim.play_clip(&"alert")
	_propagate_alert(who)

## The survivor or a live pet within radius. sensed: only one this animal sees or hears (a
## first sighting); combat memory and waking skip the sight ray.
func _nearest_live_prey(radius: float, sensed: bool = false) -> Node3D:
	var player := creature.get_tree().get_first_node_in_group("player") as Player
	var best: Node3D = null
	var best_d := radius
	if player and not player.dead:
		var d := creature.global_position.distance_to(player.global_position)
		if d <= best_d and (not sensed or sense.detects(player, d)):
			best = player
			best_d = d
		for pet in player.live_pets():
			if pet == null or pet.health.dead:
				continue
			d = creature.global_position.distance_to(pet.global_position)
			if d < best_d and (not sensed or sense.detects(pet, d)):
				best = pet
				best_d = d
	return best

## A hungry carnivore commits to wild prey (its pack joins); the prey bolts only if it senses it.
func hunt_prey(prey: Creature) -> void:
	attack_target = prey
	_combat_memory_left = 4.0
	_set_state(&"approach")
	_propagate_alert(prey)
	if prey.brain and prey.brain.state in CALM_STATES and prey.brain.sense.detects(creature, _flat_dist(prey)):
		prey.brain._spot(creature)
	_log("[ai] %s hunts %s" % [creature.def.id, prey.def.id])

## Territory warning: stand, face the intruder and call every 2.5 s. Inside territory_m it
## comes at them; past warn_m + 1 it goes back to grazing.
var _warn_left: float = 0.0

func _warn_tick() -> void:
	if not _valid_target():
		_set_state(&"roam")
		return
	creature.stop_move()
	creature.face_towards(attack_target.global_position, _dt * 3.0)
	var d := _surface_dist(attack_target)
	if d <= float(profile.get("territory_m", 0.0)):
		var who := attack_target
		_set_state(&"roam")
		_spot(who)
		return
	if d > float(profile.get("warn_m", 0.0)) + 1.0:
		attack_target = null
		_set_state(&"roam")
		return
	_warn_left -= _dt
	if _warn_left <= 0.0:
		_warn_left = 2.5
		creature.anim.play_clip(&"alert")
		creature.status_float.emit(&"warning")

## Locomotion speed for the current state; creature.gd asks every physics frame (wild only).
func move_speed(base: float, slow: float) -> float:
	match state:
		&"approach", &"attack":
			# Wild prey gets the full hunt speed; the survivor chase stays at the owner-pending 0.7.
			var key := "hunt_speed_mult" if attack_target is Creature and not (attack_target as Creature).is_pet else "chase_speed_mult"
			return base * float(profile.get(key, 0.7))
		&"flee":
			# flee_min_mps: a low-IV grazer still outruns a walking survivor (traps and statuses still slow it).
			return maxf(base * float(profile.get("flee_speed_mult", 1.0)), float(profile.get("flee_min_mps", 0.0)) * slow)
	return kit.move_speed(base)

## A bite, telegraphed (pc-ai-01) so the survivor can read it and roll.
func _play_attack(clip: StringName) -> void:
	if clip == &"attack_primary" and not creature.is_pet and bool(profile.get("telegraph_primary", true)):
		Telegraph.show_for(creature, clip)
	creature.anim.play_clip(clip)

## A point on the target's reach circle, circle_deg round from where this animal stands; the
## side flips with every bite.
func _orbit_slot(deg: float) -> Vector3:
	var to_me := creature.global_position - attack_target.global_position
	to_me.y = 0.0
	if to_me.length_squared() <= 0.001:
		to_me = Vector3.BACK
	var side := (1.0 if _primary_chain % 2 == 0 else -1.0) * _flank_sign
	return attack_target.global_position + to_me.normalized().rotated(Vector3.UP, deg_to_rad(deg) * side) * maxf(0.8, reach_to(attack_target) - 0.4)

func _valid_target() -> bool:
	if attack_target == null or not is_instance_valid(attack_target):
		return false
	if attack_target is FieldCatapult and (attack_target as FieldCatapult).hp <= 0:
		return false
	if attack_target is Player and (attack_target as Player).dead:
		return false  # a survivor on the floor is not prey; wander off
	if attack_target is Creature and (attack_target as Creature).health.dead:
		return false
	return true

## Both sides can contact a giant's body edge without body overlap or safe-edge cheese.
## Measured centre to centre against a survivor-sized target; see reach_to for others.
func contact_reach() -> float:
	return maxf(float(profile.get("attack_range", 1.8)) + 0.3, creature.body_radius() + 0.75)

## Centre-to-centre reach against this target: a bigger body is reached at its own surface.
func reach_to(target: Node3D) -> float:
	return contact_reach() + _size_excess(target)

## Extra radius of the target over the survivor capsule the reach numbers were tuned on.
static func _size_excess(target: Node3D) -> float:
	if target is Creature and (target as Creature).def:
		return maxf(0.0, (target as Creature).body_radius() - SURVIVOR_RADIUS)
	return 0.0

func _surface_dist(who: Node3D) -> float:
	var r := (who as Creature).body_radius() if who is Creature and (who as Creature).def else SURVIVOR_RADIUS
	return _flat_dist(who) - creature.body_radius() - r

func _flat_dist(who: Node3D) -> float:
	return _flat_dist_to(who.global_position)

func _flat_dist_to(p: Vector3) -> float:
	return Vector2(creature.global_position.x - p.x, creature.global_position.z - p.z).length()

func _approach(delta: float) -> void:
	if not _valid_target():
		_disengage()
		return
	var want := _approach_slot()
	creature.move_to(want)
	creature.face_towards(attack_target.global_position, delta)
	if _flat_dist(attack_target) <= reach_to(attack_target) - 0.1:
		if _is_herbivore() and not _provoked():
			if not _flees_on_sight():
				_disengage()  # provocation is over: a calm grazer stops fighting
			elif _cornered():
				_set_state(&"attack")
			else:
				_set_state(&"flee")
		else:
			_set_state(&"attack")

func _do_attack() -> void:
	if _valid_target():
		_combat_memory_left = 4.0
	if not _valid_target():
		_disengage()
		return
	if _flat_dist(attack_target) > reach_to(attack_target) + 0.1:
		_set_state(&"approach")
		return
	if _attack_cd > 0.0 or creature.anim._busy or creature.stagger_left > 0.0:
		# Solo predators reposition between bites (circle_deg) instead of standing still.
		var circle := float(profile.get("circle_deg", 0.0))
		if circle > 0.0 and not creature.is_pet and _attack_cd > 0.3 and not creature.anim._busy:
			creature.move_to(_orbit_slot(circle))
		else:
			creature.stop_move()
		return
	creature.stop_move()
	if _is_pack_member() and not _pack_ready():
		return
	var clip := &"attack_primary"
	if _should_heavy():
		clip = &"attack_heavy"
		_primary_chain = 0
	else:
		_primary_chain += 1
	_play_attack(clip)
	_attack_cd = 1.2 if clip == &"attack_primary" else 1.8
	if _is_pack_member():
		_pack_cooldown_until[creature.pack_id] = _now_s() + 0.4

func _retreat(delta: float) -> void:
	if not _valid_target():
		_disengage()
		return
	_retreat_left = maxf(0.0, _retreat_left - delta)
	var away := creature.global_position - attack_target.global_position
	away.y = 0.0
	if away.length_squared() <= 0.001:
		away = Vector3.BACK
	var dist := float(profile.get("retreat_tiles", 3.0))
	creature.move_to(creature.global_position + away.normalized() * dist)
	if _retreat_left <= 0.0:
		_set_state(&"approach")

## End a fight or a flight (BrainFlight.end); species brains call this.
func _disengage() -> void:
	flight.end()

func _approach_slot() -> Vector3:
	if attack_target == null:
		return creature.global_position
	var want := attack_target.global_position
	if bool(profile.get("pack_flank", false)) and _is_pack_member():
		var slot := _flank_slot()
		if _now_s() - _last_flank_log_s > 1.0:
			_last_flank_log_s = _now_s()
			_log("[ai] pack flank ±60")
		return slot
	var to_me := creature.global_position - attack_target.global_position
	to_me.y = 0.0
	if to_me.length_squared() <= 0.001:
		to_me = Vector3.BACK
	var reach := maxf(0.6, reach_to(attack_target) - 0.6)
	want += to_me.normalized() * reach
	return want

func _flank_slot() -> Vector3:
	var tgt := attack_target.global_position
	var to_me := creature.global_position - tgt
	to_me.y = 0.0
	if to_me.length_squared() <= 0.001:
		to_me = Vector3.BACK
	var back := to_me.normalized()
	var ang := deg_to_rad(60.0 * _flank_sign)
	var dir := back.rotated(Vector3.UP, ang)
	if _is_pack_leader():
		dir = -back
	return tgt + dir * (2.5 + _size_excess(attack_target))

## A pack of one (spawned alone, or the last survivor) fights like a solo animal.
func _is_pack_member() -> bool:
	return _pack_members().size() > 1

func _is_pack_leader() -> bool:
	return _pack_leader() == creature

func _pack_ready() -> bool:
	if not _is_pack_member():
		return true
	var until := float(_pack_cooldown_until.get(creature.pack_id, 0.0))
	if until > _now_s():
		return false
	if _is_pack_leader():
		return true
	var leader := _pack_leader()
	if leader == null or leader == creature:
		return true
	if attack_target and leader.global_position.distance_to(attack_target.global_position) <= float(profile.get("attack_range", 1.8)) + 0.7:
		return false
	return true

func _pack_leader() -> Creature:
	var members := _pack_members()
	return members[0] if not members.is_empty() else null

## Live wild members of this pack, strongest first (shared, read-only).
func _pack_members() -> Array[Creature]:
	return PackIndex.members(creature)

func _herd_center() -> Vector3:
	var members := _pack_members()
	if members.is_empty():
		return creature.spawn_home
	var sum := Vector3.ZERO
	for c in members:
		sum += c.global_position
	var center := sum / float(members.size())
	var home := creature.spawn_home
	var hold := float(profile.get("herd_hold_radius_tiles", 8.0))
	if home.distance_to(center) <= hold:
		return center
	var pull := (center - home).normalized() * hold
	return home + pull

func _walkable_probe(home: Vector3, want: Vector3, radius: int) -> Vector3:
	var rt := World.runtime if World else null
	if rt == null:
		return want
	var tile := BuildGrid.tile_of(want)
	for r in range(0, radius + 1):
		for z in range(-r, r + 1):
			for x in range(-r, r + 1):
				if r > 0 and abs(x) != r and abs(z) != r:
					continue
				var probe := BuildGrid.tile_centre(tile + Vector2i(x, z), rt)
				if not rt.spawn_ok(probe, false):
					continue
				if _is_herbivore() and probe.distance_to(home) > float(profile.get("flee_tiles", 8.0)) + 2.0:
					continue
				return probe
	return home

func _cornered() -> bool:
	var rt := World.runtime if World else null
	if rt == null:
		return false
	var tile := BuildGrid.tile_of(creature.global_position)
	for z in range(-1, 2):
		for x in range(-1, 2):
			if x == 0 and z == 0:
				continue
			var probe := BuildGrid.tile_centre(tile + Vector2i(x, z), rt)
			if rt.spawn_ok(probe, false):
				return false
	return true

func _should_heavy() -> bool:
	if _primary_chain >= int(profile.get("heavy_after_primaries", 3)):
		return true
	if not _valid_target():
		return false
	if _target_prev == Vector3.ZERO:
		_target_prev = attack_target.global_position
		return false
	var moved := attack_target.global_position.distance_to(_target_prev)
	_target_prev = attack_target.global_position
	if moved < 0.15:
		_target_still_left += _dt
	else:
		_target_still_left = 0.0
	return _target_still_left >= 1.5

## Solidarity: hitting one pulls the herd. Calm grazers (defensive, territorial) answer a
## threat to a herdmate by fighting alongside it; skittish ones run with it.
func _propagate_alert(who: Node3D) -> void:
	for c in _pack_members():
		if c == creature or c.brain == null:
			continue
		var b := c.brain
		b.attack_target = who
		c.mark_aggro_now()
		if b._is_herbivore() and not b._flees_on_sight():
			b._provoked_until = maxf(b._provoked_until, _now_s() + PROVOKE_SECONDS)
		# Only wake peaceful packmates; leave retreat/flee/attack alone.
		var st := b.state
		if st in CALM_STATES:
			b._set_state(&"alert")
			b._alert_left = maxf(b._alert_left, 0.35)
		elif st == &"alert":
			b._alert_left = maxf(b._alert_left, 0.35)

## default, then the archetype's temperament block, then the archetype row (ai.json).
func _profile(archetype: StringName) -> Dictionary:
	var out: Dictionary = (Data.creature_ai.get("default", {}) as Dictionary).duplicate()
	var rows: Dictionary = Data.creature_ai.get("archetypes", {})
	var raw: Variant = rows.get(str(archetype), {})
	var row: Dictionary = raw if raw is Dictionary else {}
	var temper: Variant = (Data.creature_ai.get("temperaments", {}) as Dictionary).get(str(row.get("temperament", out.get("temperament", ""))), {})
	if temper is Dictionary:
		out.merge(temper as Dictionary, true)
	out.merge(row, true)
	return out

func _set_state(next: StringName) -> void:
	if state == next:
		return
	var prev := state
	state = next
	if next in HUNT_STATES and BrainRest.sleeper(self):
		BrainRest.keep_awake(self)  # a chase or a fight does not end in an instant nap
	_log("[ai] %s %s" % [creature.def.id if creature and creature.def else "?", next])
	state_changed.emit(prev, next)

## AI chatter prints only with the debug overlay on (F3, or a lab run without --shot).
func _log(msg: String) -> void:
	if Game and Game.debug_overlay:
		print(msg)

func _now_s() -> float:
	return float(Time.get_ticks_msec()) * 0.001

## A fired siege platform is a threat, including to otherwise peaceful herbivores.
func on_siege_fire(platform: FieldCatapult) -> void:
	_provoked_until = _now_s() + PROVOKE_SECONDS
	on_aggro(platform)
