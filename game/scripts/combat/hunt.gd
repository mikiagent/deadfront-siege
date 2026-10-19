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
var _swing_pending := false
var _los_notice_s := -99.0
var player: Player
## Last refusal or warning shown to the player (labs and tests read it).
var last_notice: String = ""

func setup(p: Player) -> void:
	player = p

func start(t: Creature) -> void:
	if t == null or t.health.dead or t.is_pet:
		return  # F / retaliation / taps never turn the survivor on his own pet
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
			if target and target.capturable() and _net_health_ok() and _best_net_ok():
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
	var ranged_weapon := _weapon()
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
	if _swing_cd > 0.0 or _swing_pending:
		return
	if not MeleeQuery.clear(player, target):
		return  # a wall or a ridge between: no swing through it
	begin_swing()

## Start a swing now; damage lands at the swing's hit fraction (pc-combat-03), not on the press.
## The basic swing/punch is free: stamina only pays for sprint, roll, tackle and kick.
func begin_swing() -> void:
	var w := _weapon()
	var def := w.def() if w else null
	var rate := def.attack_rate if def and def.attack_rate > 0.0 else 1.0
	if w == null:
		player.play_punch()
	else:
		player.play_attack(def != null and def.damage_type == &"blunt" and _swing_damage(w) > CombatTuning.num("player_melee", "heavy_swing_min_damage", 10.0))
	_swing_cd = 1.0 / maxf(0.2, rate)
	var forward := target.global_position - player.global_position
	forward.y = 0.0
	_swing_pending = true
	get_tree().create_timer(hit_delay(w)).timeout.connect(_on_swing_hit.bind(weakref(target), w, forward.normalized()), CONNECT_ONE_SHOT)

## Seconds from the swing press to contact. The survivor clip is rescaled to swing_seconds/rate
## (player_anim._play), so contact sits at hit_frac of that.
# ASSUMPTION: contact at 60 % of the visible swing until W2-PANIM authors clip hit events.
static func hit_delay(w: ItemStack) -> float:
	var def := w.def() if w else null
	var rate := def.attack_rate if def and def.attack_rate > 0.0 else 1.0
	var t := CombatTuning.section("player_melee")
	return float(t.get("hit_frac", 0.6)) * float(t.get("swing_seconds", 0.65)) / maxf(0.2, rate)

func _on_swing_hit(ref: WeakRef, w: ItemStack, forward: Vector3) -> void:
	_swing_pending = false
	var t := ref.get_ref() as Creature
	if t == null or t.health.dead or player == null or player.dead:
		return
	if player.rolling or player.statuses.has_flag(&"cannot_act"):
		return  # knocked down or rolled out mid-swing: the swing is lost
	var offset := t.global_position - player.global_position
	offset.y = 0.0
	var tune := CombatTuning.section("player_melee")
	if offset.length() > melee_reach(t) + float(tune.get("hit_reach_slack_m", 0.3)):
		return  # it stepped out of the swing
	if forward != Vector3.ZERO and offset.normalized().dot(forward) < float(tune.get("hit_arc_min_dot", 0.0)):
		return  # it got behind the swing
	if not MeleeQuery.clear(player, t):
		return
	land_hit(t, w)

## Survivor swing chance: accuracy x status accuracy_mult against dodge + evasion_add.
func hit_chance(t: Creature) -> float:
	var acc := CombatTuning.num("player_melee", "base_accuracy", 1.0) * player.statuses.accuracy_mult()
	var dodge := t.dodge_chance() + t.statuses.evasion_add() * CombatTuning.top("evasion_add_scale", 0.01)
	return CombatTuning.hit_chance(acc, dodge)

func _swing_damage(w: ItemStack) -> float:
	var tune := CombatTuning.section("player_melee")
	if w == null:
		return float(tune.get("unarmed_damage", 8.0))
	var dmg := w.scaled_damage()
	if w.def() and w.def().is_work_tool:
		dmg *= float(tune.get("work_tool_mult", 0.45))
	return dmg

## Resolve one swing that reached the target. Returns whether it landed. Statuses, wear, XP
## and the tyrant counter happen only on a landed hit.
func land_hit(t: Creature, w: ItemStack) -> bool:
	if not CombatTuning.roll(hit_chance(t)):
		t.combat_float.emit(0.0, &"dodge")
		return false
	var tune := CombatTuning.section("player_melee")
	var def := w.def() if w else null
	var dmg := _swing_damage(w)
	var dtype := def.damage_type if def else &"blunt"
	var defense := t.defense_for(false) * t.statuses.defense_mult()
	var dealt: float = maxf(dmg * float(tune.get("min_damage_frac", 0.05)), dmg - defense * float(tune.get("defense_factor", 0.5)))
	var behind := _is_behind_of(t)
	if behind:
		dealt *= float(tune.get("behind_mult", 1.25))
	var melee_lv := player.skills.level_of("melee") if player.skills else 0
	dealt *= 1.0 + float(tune.get("damage_per_melee_level", 0.01)) * float(melee_lv)  # ASSUMPTION +1 % per Melee level
	# Data-driven combat matchup, then a crit roll (x1.75 red): 8 % base, +20 % from behind,
	# +0.2 % per Melee level.
	var kind := effectiveness(t, dtype)
	dealt *= CombatCounters.multiplier(t.def.archetype, dtype)
	var crit_chance := float(tune.get("crit_base", 0.08)) + (float(tune.get("crit_behind", 0.2)) if behind else 0.0) + float(tune.get("crit_per_melee_level", 0.002)) * float(melee_lv)
	if CombatTuning.roll(crit_chance):
		dealt *= float(tune.get("crit_mult", 1.75))
		kind = &"crit"
	t.next_hit_kind = kind
	t.health.take_damage(dealt, player)
	if player.skills:
		player.skills.add_xp("melee", int(tune.get("xp_per_hit", 2)))
	print("[combat] player hit %s dmg=%.1f type=%s kind=%s" % [t.def.id, dealt, dtype, kind])
	wear_weapon(w)
	apply_counter_hit(w, t)
	if dtype == &"blunt" and t.brain is TyrantBrain: (t.brain as TyrantBrain).blunt_counter()
	if dtype == &"blunt" and not t.health.dead and CombatTuning.roll(float(tune.get("blunt_groggy_chance", 0.35))):
		t.statuses.apply(&"groggy", player)
	if kind == &"crit" or (dtype == &"blunt" and dmg > float(tune.get("heavy_swing_min_damage", 10.0))):
		IsoCamera.shake(player, CombatTuning.num("camera", "player_heavy_swing", 0.25))
	return true

## Weapons wear on every landed hit (durability-01: the market needs an item sink).
func wear_weapon(w: ItemStack) -> void:
	if w == null or w.max_durability <= 0:
		return
	if not w.wear(int(CombatTuning.top("weapon_wear_per_hit", 1))):
		print("[item] %s broke" % w.def_id)
		_say("%s broke." % (w.def().display_name if w.def() else str(w.def_id)))
	player.inventory.changed.emit()

## The equipped weapon, or null when it is broken (a broken weapon fights as bare hands).
func _weapon() -> ItemStack:
	var w := player.inventory.equipped_weapon()
	return null if w == null or w.is_broken() else w

func _say(text: String) -> void:
	last_notice = text
	player.notice(text)

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

## Shared gate for Tackle and Kick: reach is measured body edge to body edge, so a T. rex at
## contact range is in reach (its centre is 3+ m away), and a wall between refuses the move.
func _tactic_reach_ok(verb: String, tune: Dictionary) -> bool:
	if MeleeQuery.surface_gap(player, target) > float(tune.get("surface_reach_m", 2.4)):
		_say("Too far to %s: get closer." % verb)
		return false
	if not MeleeQuery.clear(player, target):
		_say("Something is in the way.")
		return false
	return true

## Body tackle: lunge into the target, groggy (then knockdown on the next hit), 6 damage.
func use_tackle() -> void:
	if target == null or not _can_start_tactic():
		return
	if _tackle_cd > 0.0:
		_say("Tackle ready in %.0fs" % ceil(_tackle_cd))
		return
	var tune := CombatTuning.section("tackle")
	if not _tactic_reach_ok("tackle", tune):
		return
	if not player.vitals.spend_energy(float(tune.get("stamina", 15.0))):
		_say("Out of stamina.")
		return
	player.clear_nav()
	player.face_world(target.global_position)
	var to := target.global_position - player.global_position
	to.y = 0.0
	var lunge_distance := minf(float(tune.get("lunge_max_m", 1.0)), maxf(0.0, MeleeQuery.surface_gap(player, target) - 0.1))
	if lunge_distance > 0.0 and to.length_squared() > 0.0001:
		# Move the body now. The attack animation marks the player busy and the normal player
		# loop zeroes velocity, so a velocity-only lunge never actually happened.
		player.move_and_collide(to.normalized() * lunge_distance)
	target.statuses.apply(&"groggy", player)
	target.next_hit_kind = &"strong"
	target.health.take_damage(float(tune.get("damage", 6.0)), player)
	target.status_float.emit(&"tackle")
	_tackle_cd = float(tune.get("cooldown", 8.0))
	_tactic_lock = float(tune.get("lock", 0.55))
	_swing_cd = maxf(_swing_cd, _tactic_lock)
	player.play_attack(true)
	print("[combat] body tackle %s" % target.def.id)

## Body mass stand-in for shoves.
# ASSUMPTION: creature JSON has no mass, so length x height ranks bodies (compy 3.6, raptor 14,
# triceratops 108, T. rex 192).
static func mass_proxy(c: Creature) -> float:
	if c == null or c.def == null:
		return 1.0
	return maxf(0.1, c.def.real_length_m * c.def.height_meters)

## Shove distance for this body: full push up to ref_mass, falling off with mass, 0 for giants.
static func kick_push(c: Creature) -> float:
	var tune := CombatTuning.section("kick")
	var mass := mass_proxy(c)
	if mass >= float(tune.get("giant_mass", 60.0)):
		return 0.0
	var push := float(tune.get("push_m", 3.5)) * clampf(float(tune.get("ref_mass", 8.0)) / mass, 0.0, 1.0)
	return push if push >= float(tune.get("min_push_m", 0.3)) else 0.0

## Kick: shove the target back (scaled by its mass; giants do not budge) with 4 damage.
func use_kick() -> void:
	if target == null or not _can_start_tactic():
		return
	if _kick_cd > 0.0:
		_say("Kick ready in %.0fs" % ceil(_kick_cd))
		return
	var tune := CombatTuning.section("kick")
	if not _tactic_reach_ok("kick", tune):
		return
	if not player.vitals.spend_energy(float(tune.get("stamina", 10.0))):
		_say("Out of stamina.")
		return
	player.clear_nav()
	player.face_world(target.global_position)
	player.play_attack(false)
	var push := kick_push(target)
	if push <= 0.0:
		_say("Too heavy to shove: it barely feels the kick.")
	else:
		var away := target.global_position - player.global_position
		away.y = 0.0
		# Respect walls, props and terrain instead of teleporting the target through geometry.
		target.move_and_collide(away.normalized() * push)
	target.next_hit_kind = &"hit"
	target.health.take_damage(float(tune.get("damage", 4.0)), player)
	target.status_float.emit(&"kick")
	_kick_cd = float(tune.get("cooldown", 6.0))
	_tactic_lock = float(tune.get("lock", 0.45))
	_swing_cd = maxf(_swing_cd, _tactic_lock)
	print("[combat] kick %s push=%.2f" % [target.def.id, push])

## Nets follow the capture rule: knocked out and under 30 % health (HANDOFF section 8).
func use_net() -> void:
	if target == null or not target.capturable():
		return
	if not _net_health_ok():
		_say("Weaken it below 30% health before netting it.")
		return
	CaptureSystem.attempt(player, target)

func _net_health_ok() -> bool:
	return target != null and FieldTame.health_allows_capture(target.health.fraction())

func _best_net_ok() -> bool:
	var net := player.inventory.best_capture_net()
	if net == null:
		return false
	var d := net.def()
	return d != null and d.capture_tier >= target.def.capture_tier and Data.has_capture_technique(target.def.capture_tier)

func _is_behind_of(t: Creature) -> bool:
	var to_player := player.global_position - t.global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.001:
		return false
	return to_player.normalized().dot(t.global_basis.z) > CombatTuning.num("player_melee", "behind_dot", 0.35)

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
	elif def and def.damage_type == &"slashing" and not victim.health.dead and CombatTuning.roll(CombatTuning.num("player_melee", "slashing_bleed_chance", 0.25)):
		victim.statuses.apply(&"bleeding_target", player)
	if w and int(w.attributes.get("toxin_hits", 0)) > 0:
		w.attributes["toxin_hits"] = int(w.attributes["toxin_hits"]) - 1
		if not victim.health.dead: victim.statuses.apply(&"poisoned_target", player)
		player.inventory.changed.emit()

## Fixed aim at launch, real projectile collision. Auto and Fire context share this action.
func fire_ranged() -> bool:
	if target == null or not is_instance_valid(target) or target.health.dead: return false
	var weapon := _weapon()
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
	if not hit.is_empty() and hit.get("collider") != target:
		# Auto-attack retries every frame; tell the player once every few seconds, not silently.
		var now := Time.get_ticks_msec() * 0.001
		if now - _los_notice_s > 3.0:
			_los_notice_s = now
			_say("No clear shot: something is in the way.")
		return false
	if player.inventory.count_of(def.ammo_id) < 1:
		_say("Need stone shot")
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
		shot.velocity = StoneProjectile.launch_velocity(offset)
		shot.damage = weapon.scaled_damage()
		shot.range_left = def.range_m * 1.5  # the arc is longer than the straight line
		shot.skill_level = player.skills.level_of("ranged") if player.skills else 0
		runtime.add_child(shot)
		shot.global_position = origin
	)
	return true
