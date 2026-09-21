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
	_roam_cd = randf_range(float(profile.get("roam_delay_min", 3.0)), float(profile.get("roam_delay_max", 6.0)))

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

func on_aggro(who: Node) -> void:
	if who is Node3D:
		attack_target = who as Node3D
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
	if _roam_pause > 0.0:
		_roam_pause -= delta
		creature.stop_move()
		return
	_roam_cd -= delta
	if _roam_cd > 0.0:
		if _roam_target != Vector3.ZERO and creature.global_position.distance_to(_roam_target) <= 0.8:
			_roam_target = Vector3.ZERO
			_roam_pause = randf_range(0.4, 0.9)
		return
	var center := _herd_center() if _is_herbivore() else creature.spawn_home
	var roam_tiles := float(profile.get("roam_tiles", 6.0))
	var p := center + Vector3(randf_range(-roam_tiles, roam_tiles), 0.0, randf_range(-roam_tiles, roam_tiles))
	p = _walkable_probe(center, p, int(roam_tiles) + 3)
	_roam_target = p
	creature.move_to(p)
	_roam_cd = randf_range(float(profile.get("roam_delay_min", 3.0)), float(profile.get("roam_delay_max", 6.0)))

func _scan() -> void:
	if state != &"roam" and state != &"sleep":
		return
	var player := creature.get_tree().get_first_node_in_group("player") as Node3D
	if player is Player and (player as Player).dead:
		return
	# Nearest of the survivor and her pets inside perception: wild animals go for pets too.
	var best: Node3D = null
	var best_d := _effective_perception()
	if player and creature.global_position.distance_to(player.global_position) <= best_d:
		best = player
		best_d = creature.global_position.distance_to(player.global_position)
	if player is Player:
		for p in (player as Player).live_pets():
			var d := creature.global_position.distance_to(p.global_position)
			if d < best_d:
				best = p
				best_d = d
	if best:
		attack_target = best
		_set_state(&"alert")
		_alert_left = maxf(_alert_left, 0.6)
		creature.mark_aggro_now()
		creature.anim.play_clip(&"alert")
		_propagate_alert(player)

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
	if dist > _effective_perception() * float(profile.get("leash_mult", 2.2)):
		print("[ai] %s disengage (leash)" % creature.def.id)
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
	if creature == null:
		return null
	var best: Creature = creature
	for n in creature.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.pack_id != creature.pack_id or c.health.dead:
			continue
		if c.get_instance_id() < best.get_instance_id():
			best = c
	return best

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
