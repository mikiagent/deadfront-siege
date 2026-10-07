class_name Hunt
extends Node
## Auto-attack overlay plus Body Tackle / Kick / Roll / Net.

signal started(target: Creature)
signal ended

var target: Creature
var hold: bool = false
var auto: bool = true  # HUD Auto hexagon: auto-attack when in range
var _ring: MeshInstance3D
var _ranged_pending := false
var _swing_cd: float = 0.0
var _tackle_cd: float = 0.0
var _kick_cd: float = 0.0
var _net_cd: float = 0.0
var _tactic_lock: float = 0.0
var player: Player

func setup(p: Player) -> void:
	player = p

func start(t: Creature) -> void:
	if t == null or t.health.dead:
		return
	target = t
	_attach_ring(t)
	started.emit(t)
	print("[combat] hunt start %s" % t.def.id)

func stop() -> void:
	target = null
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
	ended.emit()

## Red ground ring on the target's tile (combat reference).
func _attach_ring(t: Creature) -> void:
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	var PV := load("res://scripts/world/prop_visuals.gd") as GDScript
	_ring = MeshInstance3D.new()
	_ring.name = "TargetRing"
	_ring.mesh = PV.make_disc_mesh(1.15, 32)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.12, 0.1, 0.45)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.add_child(_ring)
	_ring.position = Vector3(0, 0.06, 0)

func tactic_label(slot: int) -> String:
	match slot:
		1:
			return "Tackle" if _tackle_cd <= 0.0 else "Tackle %.0f" % _tackle_cd
		2:
			return "Kick" if _kick_cd <= 0.0 else "Kick %.0f" % _kick_cd
		3:
			return "Roll"
		4:
			if target and target.capturable() and _best_net_ok():
				return "Net"
			return "—"
		_:
			return ""

func _process(delta: float) -> void:
	_swing_cd = maxf(0.0, _swing_cd - delta)
	_tackle_cd = maxf(0.0, _tackle_cd - delta)
	_kick_cd = maxf(0.0, _kick_cd - delta)
	_net_cd = maxf(0.0, _net_cd - delta)
	_tactic_lock = maxf(0.0, _tactic_lock - delta)
	if target == null or not is_instance_valid(target) or target.health.dead:
		if target:
			stop()
		return
	if hold or not auto:
		return
	if player.global_position.distance_to(target.global_position) > 28.0:
		stop()
		return
	# Square up to the target while close and not walking, so swings and punches land facing it.
	if not player.nav_active and player.global_position.distance_to(target.global_position) <= 4.0:
		player.face_world_smooth(target.global_position, delta)
	_auto_attack()

## Keep small-creature reach unchanged, but strike the edge of large collision bodies.
## T-rex radius2.88m previously made the fixed2.1m center distance unreachable.
static func melee_reach(creature: Creature) -> float:
	if creature == null or creature.def == null:
		return 2.1
	return maxf(2.1, maxf(0.18, creature.def.real_length_m * 0.12) + 0.65)

func _auto_attack() -> void:
	# An attended siege platform never fires or chases automatically.
	var platform := player._nearest_group("catapult") as FieldCatapult
	if platform and player.global_position.distance_to(platform.global_position) <= 3.0:
		return
	if player.statuses.has_flag(&"cannot_act"):
		return
	if player.rolling or _tactic_lock > 0.0:
		return
	var ranged_weapon := player.inventory.equipped_weapon()
	if ranged_weapon and ranged_weapon.def() and ranged_weapon.def().range_m > 0.0:
		if player.global_position.distance_to(target.global_position) > ranged_weapon.def().range_m and not hold:
			player.nav_to(target.global_position)
		else:
			fire_ranged()
		return
	var offset := player.global_position - target.global_position
	var dist := Vector2(offset.x, offset.z).length()
	if dist > melee_reach(target):
		if not hold:
			player.nav_to(target.global_position)
		return
	player.clear_nav()
	player.face_world(target.global_position)
	if _swing_cd > 0.0:
		return
	var w := player.inventory.equipped_weapon()
	var def := w.def() if w else null
	# The basic swing/punch is free: stamina only pays for sprint, roll, tackle and kick, so the
	# survivor always keeps fighting.
	var rate := def.attack_rate if def and def.attack_rate > 0.0 else 1.0
	var dmg := w.scaled_damage() if w else 8.0
	var dtype := def.damage_type if def else &"blunt"
	if def and def.is_work_tool:
		dmg *= 0.45
	if w == null:
		player.play_punch()
	else:
		player.play_attack(dtype == &"blunt" and dmg > 10.0)
	var defense := target.defense_for(false) * target.statuses.defense_mult()
	var raw: float = dmg - defense * 0.5
	var dealt: float = maxf(dmg * 0.05, raw)
	if randf() < target.dodge_chance():
		target.combat_float.emit(0.0, &"dodge")
		_swing_cd = 1.0 / maxf(0.2, rate)
		return
	var behind := _is_behind()
	if behind:
		dealt *= 1.25
	var melee_lv := player.skills.level_of("melee") if player.skills else 0
	if player.skills:
		dealt *= 1.0 + 0.01 * float(melee_lv)  # ASSUMPTION +1 % per Melee level
	# Data-driven combat matchup, then a crit roll
	# (x1.75 red): 8 % base, +20 % from behind, +0.2 % per Melee level.
	var kind := effectiveness(target, dtype)
	dealt *= CombatCounters.multiplier(target.def.archetype, dtype)
	var crit_chance := 0.08 + (0.20 if behind else 0.0) + 0.002 * float(melee_lv)
	if randf() < crit_chance:
		dealt *= 1.75
		kind = &"crit"
	target.next_hit_kind = kind
	target.health.take_damage(dealt, player)
	if player.skills:
		player.skills.add_xp("melee", 2)
	print("[combat] player hit %s dmg=%.1f type=%s kind=%s" % [target.def.id, dealt, dtype, kind])
	apply_counter_hit(w, target)
	if dtype == &"blunt" and randf() < 0.35:
		target.statuses.apply(&"groggy", player)
	_swing_cd = 1.0 / maxf(0.2, rate)

## Chart feedback: strong above1, weak below1, otherwise neutral hit.
static func effectiveness(c: Creature, dtype: StringName) -> StringName:
	if c == null or c.def == null or dtype == &"":
		return &"hit"
	var value := CombatCounters.multiplier(c.def.archetype, dtype)
	if value > 1.0: return &"strong"
	if value < 1.0: return &"weak"
	return &"hit"

func _can_start_tactic() -> bool:
	if player == null or player.rolling or player.statuses.has_flag(&"cannot_act"):
		return false
	if player.anim and player.anim._busy:
		return false
	return _tactic_lock <= 0.0

## Body tackle: lunge into the target, groggy (then knockdown on the next hit), 6 damage.
func use_tackle() -> void:
	if target == null or not _can_start_tactic():
		return
	if _tackle_cd > 0.0:
		player.notice("Tackle ready in %.0fs" % ceil(_tackle_cd))
		return
	if player.global_position.distance_to(target.global_position) > 3.2:
		player.notice("Too far to tackle: get closer.")
		return
	if not player.vitals.spend_energy(15.0):
		player.notice("Out of stamina.")
		return
	player.clear_nav()
	player.face_world(target.global_position)
	var to := target.global_position - player.global_position
	to.y = 0.0
	if to.length() > 0.8:
		# Move the body now. The attack animation marks the player busy and the normal player
		# loop zeroes velocity, so the old velocity-only lunge never actually happened.
		var lunge_distance := minf(1.0, maxf(0.0, to.length() - 0.8))
		player.move_and_collide(to.normalized() * lunge_distance)
	target.statuses.apply(&"groggy", player)
	target.next_hit_kind = &"strong"
	target.health.take_damage(6.0, player)
	target.status_float.emit(&"tackle")
	_tackle_cd = 8.0
	_tactic_lock = 0.55
	_swing_cd = maxf(_swing_cd, _tactic_lock)
	player.play_attack(true)
	print("[combat] body tackle %s" % target.def.id)

## Kick: shove the target back 3.5 m with 4 damage and a burst; buys room to run or net.
func use_kick() -> void:
	if target == null or not _can_start_tactic():
		return
	if _kick_cd > 0.0:
		player.notice("Kick ready in %.0fs" % ceil(_kick_cd))
		return
	if player.global_position.distance_to(target.global_position) > 3.2:
		player.notice("Too far to kick: get closer.")
		return
	if not player.vitals.spend_energy(10.0):
		player.notice("Out of stamina.")
		return
	player.clear_nav()
	player.face_world(target.global_position)
	player.play_attack(false)
	var away := (target.global_position - player.global_position).normalized() * 3.5
	# Respect walls, props and terrain instead of teleporting the target through geometry.
	target.move_and_collide(Vector3(away.x, 0, away.z))
	target.next_hit_kind = &"hit"
	target.health.take_damage(4.0, player)
	target.status_float.emit(&"kick")
	_kick_cd = 6.0
	_tactic_lock = 0.45
	_swing_cd = maxf(_swing_cd, _tactic_lock)
	print("[combat] kick %s" % target.def.id)

func use_net() -> void:
	if target == null or not target.capturable():
		return
	CaptureSystem.attempt(player, target)

func _best_net_ok() -> bool:
	var net := player.inventory.best_capture_net()
	if net == null:
		return false
	var d := net.def()
	return d != null and d.capture_tier >= target.def.capture_tier and Data.has_capture_technique(target.def.capture_tier)

func _is_behind() -> bool:
	var to_player := player.global_position - target.global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.001:
		return false
	return to_player.normalized().dot(target.global_basis.z) > 0.35

## Called only after a landed melee hit, never on dodge/out-of-range attempts.
func apply_counter_hit(w: ItemStack, victim: Creature) -> void:
	if victim == null: return
	var def := w.def() if w else null
	if w and def and def.bleed_every_hits > 0:
		var hits := int(w.attributes.get("barbed_hits", 0)) + 1
		w.attributes["barbed_hits"] = hits % def.bleed_every_hits
		player.inventory.changed.emit()
		if hits >= def.bleed_every_hits and not victim.health.dead:
			victim.statuses.apply(&"bleeding_target", player)
	elif def and def.damage_type == &"slashing" and not victim.health.dead and randf() < 0.25:
		victim.statuses.apply(&"bleeding_target", player)
	if w and int(w.attributes.get("toxin_hits", 0)) > 0:
		w.attributes["toxin_hits"] = int(w.attributes["toxin_hits"]) - 1
		if not victim.health.dead: victim.statuses.apply(&"poisoned_target", player)
		player.inventory.changed.emit()

## Fixed aim at launch, real projectile collision. Auto and Fire context share this action.
func fire_ranged() -> bool:
	if target == null or not is_instance_valid(target) or target.health.dead: return false
	var weapon := player.inventory.equipped_weapon()
	var def := weapon.def() if weapon else null
	if def == null or def.range_m <= 0.0: return false
	if _ranged_pending or _swing_cd > 0 or player.dead or player.rolling or player.anim._busy or player.statuses.has_flag(&"cannot_act"): return false
	var origin := player.global_position + Vector3(0,0.3,0)
	var aim := target.global_position + Vector3(0, minf(1.0, target.def.height_meters * 0.4),0)
	var offset := aim-origin
	if offset.length() > def.range_m or offset.length() < 0.1: return false
	var query := PhysicsRayQueryParameters3D.create(origin, aim)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") != target: return false
	if player.inventory.count_of(def.ammo_id) < 1:
		player.notice("Need stone shot")
		_swing_cd = 1.0
		return false
	player.clear_nav()
	player.face_world(target.global_position)
	player.play_attack(false)
	_ranged_pending = true
	_swing_cd = 1.0 / maxf(0.2, def.attack_rate)
	var runtime := World.runtime
	# Snapshot aim at button press, not a homing shot after windup.
	player.get_tree().create_timer(0.25).timeout.connect(func () -> void:
		_ranged_pending = false
		if not is_instance_valid(player) or player.dead or player.rolling or player.inventory.equipped_weapon() != weapon or not is_instance_valid(runtime) or runtime != World.runtime or player.anim.current_clip != &"attack_primary": return
		if not player.inventory.consume(def.ammo_id, 1): return
		var shot := StoneProjectile.new()
		shot.source = player
		shot.weapon = weapon
		shot.direction = offset.normalized()
		shot.damage = weapon.scaled_damage()
		shot.range_left = def.range_m
		shot.skill_level = player.skills.level_of("ranged") if player.skills else 0
		runtime.add_child(shot)
		shot.global_position = origin
	)
	return true
