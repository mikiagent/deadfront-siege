class_name CreatureBrain
extends Node
## Archetype-driven roam / alert / approach / attack / retreat / flee / disengage.

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
var _disengage_left: float = 0.0
var _retreat_left: float = 0.0
var _damage_window: Array[Dictionary] = []
var _primary_chain: int = 0
var _target_prev: Vector3 = Vector3.ZERO
var _target_still_left: float = 0.0
var _flank_sign: float = 1.0
var _last_flank_log_s: float = -999.0
var _combat_memory_left: float = 0.0
## Herbivores flee, but after PROVOKE_HITS hits within a short window they turn and fight for
## PROVOKE_SECONDS (a cornered/provoked grazer bites back), then go back to fleeing.
const PROVOKE_HITS := 3
const PROVOKE_SECONDS := 15.0
var _hits_taken: int = 0
var _last_hit_s: float = -999.0
var _provoked_until: float = -1.0

func _provoked() -> bool:
	return _now_s() < _provoked_until

static var _pack_cooldown_until: Dictionary = {} ## pack_id -> unix seconds

func setup(c: Creature) -> void:
	creature = c
	profile = _profile(c.def.archetype)
	perception = float(profile.get("perception_base", 8.0)) + float(c.def.tier) * float(profile.get("perception_tier_mult", 0.15))
	_flank_sign = -1.0 if int(c.get_instance_id()) % 2 == 0 else 1.0
	# Start walking promptly. The old full roam delay made newly spawned dinosaurs look frozen.
	_roam_cd = randf_range(0.1, 0.6)


## The player stays on the ground until respawn. Relocate every dinosaur that was fighting
## them so the camp/respawn point cannot become a permanent death trap.
func on_player_killed(at: Vector3) -> void:
	if creature == null or creature.health.dead or creature.is_pet:
		return
	var was_hunting := attack_target is Player or state in [&"alert", &"approach", &"attack", &"retreat"]
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
	_disengage_left = 0.0
	_hits_taken = 0
	_provoked_until = -1.0
	# Make the retreat destination the new local home so idle roam does not walk straight back.
	creature.spawn_home = destination
	_set_state(&"disengage")
	creature.move_to(destination)
	print("[ai] %s post-kill retreat %.1fm" % [creature.def.id, creature.global_position.distance_to(destination)])

func _effective_perception() -> float:
	var p := perception
	if Game.phase_name() == &"night" and bool(profile.get("night_predator_bonus", true)) and not _is_herbivore():
		p *= 1.0 + float(Data.world_rules.get("night_predator_perception_bonus", 0.5))
	return p

func _is_herbivore() -> bool:
	return bool(profile.get("is_herbivore", false))

## Leash radius: past this the chase ends at once (see _disengage_track). Drawn as the red
## dotted ring while the creature is on the survivor.
func aggro_radius() -> float:
	return _effective_perception() * float(profile.get("leash_mult", 2.2))

## True while this creature is actively on the survivor (ring shown).
func hunting_player() -> bool:
	if attack_target == null or not is_instance_valid(attack_target):
		return false
	var on_player := attack_target is Player and not (attack_target as Player).dead
	var on_pet := attack_target is Creature and (attack_target as Creature).is_pet and not (attack_target as Creature).health.dead
	if not (on_player or on_pet):
		return false
	return state in [&"alert", &"approach", &"attack", &"retreat"]

func _physics_process(delta: float) -> void:
	if creature == null or creature.health.dead:
		_set_state(&"dead")
		return
	if creature.statuses.has(&"knockdown") or not creature.statuses.can_act():
		_set_state(&"downed")
		creature.stop_move()
		return
	_think(delta)
	creature.brain_state = state

var _retarget_cd: float = 0.0

## Hit by someone other than the current target (a pet biting while it chases the survivor):
## turn on the attacker. Fight what fights you; no running past a biter to reach the survivor.
func on_aggro(who: Node) -> void:
	if who is Node3D:
		if attack_target != null and attack_target != who and _valid_target() and _now_s() >= _retarget_cd:
			attack_target = who as Node3D
			_retarget_cd = _now_s() + 2.5
			if state == &"approach" or state == &"attack":
				print("[ai] %s turns on %s" % [creature.def.id, who.name])
				creature.mark_aggro_now()
				return
		attack_target = who as Node3D
		_combat_memory_left = 4.0
		creature.mark_aggro_now()
		# Do not downgrade combat states (retreat/flee/approach/attack) back to alert.
		if state == &"roam" or state == &"sleep" or state == &"disengage" or state == &"downed":
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
	if _is_herbivore() and _hits_taken >= PROVOKE_HITS and not _provoked():
		_provoked_until = now + PROVOKE_SECONDS
		print("[ai] %s provoked: fights back for %.0fs" % [creature.def.id, PROVOKE_SECONDS])
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
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_combat_memory_left = maxf(0.0, _combat_memory_left - delta)
	# A dead pet is one target, not the end of the hunt. Keep the pack together and immediately
	# select another live pet or the survivor instead of every dinosaur walking home.
	if not _valid_target() and _combat_memory_left > 0.0:
		attack_target = _nearest_live_prey(_effective_perception() * float(profile.get("leash_mult", 2.2)))
		if attack_target:
			_set_state(&"approach")
	_disengage_track(delta)
	if _is_herbivore() and Game.phase_name() == &"night" and not _valid_target():
		_set_state(&"sleep")
		creature.stop_move()
		return
	match state:
		&"roam":
			_roam(delta)
			_scan()
		&"alert":
			# Do not call _scan here: refreshing alert_left every frame trapped
			# creatures in alert and blocked approach / flee transitions.
			_alert_left = maxf(0.0, _alert_left - delta)
			if attack_target:
				creature.face_towards(attack_target.global_position, delta)
			if _alert_left <= 0.0:
				_set_state(&"flee" if (_is_herbivore() and not _provoked()) else &"approach")
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
			_flee(delta)
		&"disengage":
			_walk_home(delta)

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

func _idle_pack_slot(leader: Creature) -> Vector3:
	var members := _pack_members()
	var index := members.find(creature)
	var angle := TAU * float(maxi(0, index - 1)) / float(maxi(1, members.size() - 1))
	var radius := 1.8 + 0.35 * float(index % 2)
	return leader.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius

func _scan() -> void:
	if state != &"roam" and state != &"sleep":
		return
	# Followers let the alpha acquire prey and path behind it. If prey reaches a follower first,
	# it still alerts the whole pack through on_aggro.
	var leader := _pack_leader()
	if leader and leader != creature:
		if leader.brain and leader.brain._valid_target():
			attack_target = leader.brain.attack_target
			_combat_memory_left = 4.0
			_set_state(&"approach")
		return
	var best := _nearest_live_prey(_effective_perception())
	if best:
		attack_target = best
		_combat_memory_left = 4.0
		_set_state(&"alert")
		_alert_left = maxf(_alert_left, 0.6)
		creature.mark_aggro_now()
		creature.anim.play_clip(&"alert")
		_propagate_alert(best)

func _nearest_live_prey(radius: float) -> Node3D:
	var player := creature.get_tree().get_first_node_in_group("player") as Player
	var best: Node3D = null
	var best_d := radius
	if player and not player.dead:
		var d := creature.global_position.distance_to(player.global_position)
		if d <= best_d:
			best = player
			best_d = d
		for pet in player.live_pets():
			if pet == null or pet.health.dead:
				continue
			d = creature.global_position.distance_to(pet.global_position)
			if d < best_d:
				best = pet
				best_d = d
	return best

func _valid_target() -> bool:
	if attack_target == null or not is_instance_valid(attack_target):
		return false
	if attack_target is Player and (attack_target as Player).dead:
		return false  # a survivor on the floor is not prey; wander off
	if attack_target is Creature and (attack_target as Creature).health.dead:
		return false
	return true

func _approach(delta: float) -> void:
	if not _valid_target():
		_disengage()
		return
	var want := _approach_slot()
	creature.move_to(want)
	creature.face_towards(attack_target.global_position, delta)
	var dist := creature.global_position.distance_to(attack_target.global_position)
	if dist <= maxf(1.0, float(profile.get("attack_range", 1.8)) + 0.2):
		if _is_herbivore() and not _cornered() and not _provoked():
			_set_state(&"flee")
		else:
			_set_state(&"attack")

func _do_attack() -> void:
	if _valid_target():
		_combat_memory_left = 4.0
	if not _valid_target():
		_disengage()
		return
	var range_max := maxf(1.0, float(profile.get("attack_range", 1.8)) + 0.4)
	if creature.global_position.distance_to(attack_target.global_position) > range_max:
		_set_state(&"approach")
		return
	creature.stop_move()
	creature.face_towards(attack_target.global_position, 0.05)
	if _attack_cd > 0.0 or creature.anim._busy or creature.stagger_left > 0.0:
		return
	if _is_pack_member() and not _pack_ready():
		return
	var clip := &"attack_primary"
	if _should_heavy():
		clip = &"attack_heavy"
		_primary_chain = 0
	else:
		_primary_chain += 1
	creature.anim.play_clip(clip)
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

func _flee(_delta: float) -> void:
	var player := creature.get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		_set_state(&"roam")
		return
	if _provoked() and _valid_target():
		_set_state(&"approach")
		return
	var center := _herd_center()
	var away := creature.global_position - player.global_position
	away.y = 0.0
	if away.length_squared() <= 0.001:
		away = Vector3.BACK
	var flee_dist := float(profile.get("flee_tiles", 8.0))
	var want := center + away.normalized() * flee_dist
	var picked := _walkable_probe(center, want, int(flee_dist) + 4)
	if picked == center and _cornered():
		_set_state(&"attack")
		return
	creature.move_to(picked)

func _walk_home(_delta: float) -> void:
	creature.move_to(creature.spawn_home)
	if creature.global_position.distance_to(creature.spawn_home) <= 1.0:
		_set_state(&"roam")
		attack_target = null
		_disengage_left = 0.0
		_hits_taken = 0
		_provoked_until = -1.0

func _disengage_track(delta: float) -> void:
	if not _valid_target():
		_disengage_left = 0.0
		return
	var dist := creature.global_position.distance_to(attack_target.global_position)
	# Aggro leash: beyond leash_mult × perception the chase ends at once; beyond 1.5 × it ends
	# after disengage_seconds. Running far enough away always works.
	if dist > aggro_radius():
		print("[ai] %s disengage (left aggro radius)" % creature.def.id)
		# Leaving the visible combat radius is an immediate de-aggro, not a walk-home chase.
		# Clear target/memory now so neither this animal nor pack retention reacquires the runner.
		attack_target = null
		_combat_memory_left = 0.0
		_disengage_left = 0.0
		creature.mark_aggro_now()
		_set_state(&"disengage")
		return
	var far := dist > _effective_perception() * 1.2
	if far:
		_disengage_left += delta
		if _disengage_left >= float(profile.get("disengage_seconds", 3.0)):
			_set_state(&"disengage")
	else:
		_disengage_left = 0.0

func _disengage() -> void:
	_set_state(&"disengage")

func _approach_slot() -> Vector3:
	if attack_target == null:
		return creature.global_position
	var want := attack_target.global_position
	if bool(profile.get("pack_flank", false)) and _is_pack_member():
		var slot := _flank_slot()
		if _now_s() - _last_flank_log_s > 1.0 and Game and (Game.debug_overlay or Game.lab_name != ""):
			_last_flank_log_s = _now_s()
			print("[ai] pack flank ±60")
		return slot
	var to_me := creature.global_position - attack_target.global_position
	to_me.y = 0.0
	if to_me.length_squared() <= 0.001:
		to_me = Vector3.BACK
	var reach := maxf(0.6, float(profile.get("attack_range", 1.8)) - 0.3)
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
	return tgt + dir * 2.5

func _is_pack_member() -> bool:
	return creature.pack_id > 0

func _is_pack_leader() -> bool:
	return _pack_leader() == creature

func _pack_ready() -> bool:
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

func _pack_members() -> Array[Creature]:
	var members: Array[Creature] = []
	if creature == null or creature.pack_id <= 0:
		return members
	for n in creature.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and c.pack_id == creature.pack_id and not c.health.dead and not c.is_pet:
			members.append(c)
	# Alpha means strongest, not first spawned. Tier dominates, then combat stats break ties.
	members.sort_custom(func(a: Creature, b: Creature) -> bool:
		var sa := float(a.def.tier) * 1000000.0 + a.health.max_hp * 100.0 + a.def.attack * 10.0 + a.def.defense
		var sb := float(b.def.tier) * 1000000.0 + b.health.max_hp * 100.0 + b.def.attack * 10.0 + b.def.defense
		if not is_equal_approx(sa, sb):
			return sa > sb
		return a.get_instance_id() < b.get_instance_id()
	)
	return members

func _herd_center() -> Vector3:
	if creature == null or creature.pack_id <= 0:
		return creature.spawn_home
	var sum := Vector3.ZERO
	var count := 0
	for n in creature.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.pack_id != creature.pack_id or c.health.dead:
			continue
		sum += c.global_position
		count += 1
	if count <= 0:
		return creature.spawn_home
	var center := sum / float(count)
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
		_target_still_left += get_physics_process_delta_time()
	else:
		_target_still_left = 0.0
	return _target_still_left >= 1.5

func _propagate_alert(who: Node3D) -> void:
	for n in creature.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c == creature or c.health.dead:
			continue
		if c.pack_id != creature.pack_id or c.pack_id <= 0:
			continue
		if c.brain == null:
			continue
		c.brain.attack_target = who
		c.mark_aggro_now()
		# Only wake peaceful packmates; leave retreat/flee/attack alone.
		var st := c.brain.state
		if st == &"roam" or st == &"sleep" or st == &"disengage":
			c.brain._set_state(&"alert")
			c.brain._alert_left = maxf(c.brain._alert_left, 0.35)
		elif st == &"alert":
			c.brain._alert_left = maxf(c.brain._alert_left, 0.35)

func _profile(archetype: StringName) -> Dictionary:
	var out: Dictionary = {}
	var base: Dictionary = Data.creature_ai.get("default", {})
	for k in base.keys():
		out[k] = base[k]
	var all: Dictionary = Data.creature_ai.get("archetypes", {})
	var row: Variant = all.get(str(archetype), {})
	if row is Dictionary:
		for k in (row as Dictionary).keys():
			out[k] = (row as Dictionary)[k]
	return out

func _set_state(next: StringName) -> void:
	if state == next:
		return
	state = next
	if Game and (Game.debug_overlay or Game.lab_name != ""):
		print("[ai] %s %s" % [creature.def.id, state])

func _now_s() -> float:
	return float(Time.get_ticks_msec()) * 0.001
