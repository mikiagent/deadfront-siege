class_name Hunt
extends Node
## Auto-attack overlay plus Body Tackle / Kick / Roll / Net.

signal started(target: Creature)
signal ended
## A swing started / a melee hit landed on its target (labs and tests count these).
signal swing_started
signal hit_landed(target: Creature)

var target: Creature
var hold: bool = false
## A ground tap during the fight (Player.move_order; owner: "pathfind to where I want to walk and then
## re-engage"): the hunt keeps its target but neither chases, swings nor faces until the order ends, then
## re-engages. A hit ends the order and Player.receive_creature_hit retargets (start() clears this).
var _resume_after_move: bool = false
var auto: bool = true  # HUD Auto hexagon: auto-attack when in range
## AUTO-ABILITY (owner: on by default): with a target and any auto-castable ability ready, cast the
## most powerful one instead of the next basic swing. The HUD hex toggles it; the picker is
## scripts/combat/auto_ability.gd over data/combat_tuning.json "auto_ability".
var auto_ability: bool = true
## The ability id the last auto-cast chose ("tackle" / "kick"), for tests and the HUD row. "" = none.
var last_auto_cast: StringName = &""
var _ring: MeshInstance3D
var _ranged_pending := false
var _swing_cd: float = 0.0
var _tackle_cd: float = 0.0
var _kick_cd: float = 0.0
var _net_cd: float = 0.0
var _tactic_lock: float = 0.0
var _swing_pending := false
var _notice_s: Dictionary = {}  ## notice text -> last shown (each message throttles on its own)
const NOTICE_THROTTLE_S := 3.0
var player: Player
## Last refusal or warning shown to the player (labs and tests read it).
var last_notice: String = ""
## Spec 09: one "stun it" hint per creature, when a tameable wild animal under the hunt drops to
## <= 50 % HP and is not stunned. Keyed by instance id so a second animal gets its own hint.
const STUN_HINT := "Weaken and sedate the dinosaur to capture it."
const STUN_HINT_FRAC := 0.50  ## the early tutorial target the spec names (not a hard capture rule)
const TRANQ_DART := &"tranquilizer_dart"
const CAPTURE_REFUSAL := "Weaken it and sedate it until it is knocked out to capture it."
var _stun_hinted: Dictionary = {}

func setup(p: Player) -> void:
	player = p

func start(t: Creature) -> void:
	if t == null or t.health.dead or t.is_pet:
		return  # F / retaliation / taps never turn the survivor on his own pet
	if t != target:
		aim_section = &""
		SectionHighlight.show_on(t, &"")
	target = t
	_resume_after_move = false
	_attach_ring(t)
	started.emit(t)
	print("[combat] hunt start %s" % t.def.id)

func stop() -> void:
	target = null
	_resume_after_move = false
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
			# Spec 07 §8: the HUD shows the roll's cooldown, so a chained press reads why it is refused.
			var left: float = player.sim.roll_cooldown_left() if player and player.sim else 0.0
			return "Roll" if left <= 0.0 else "Roll %.0f" % ceilf(left)
		4:
			if target and _net_health_ok() and _best_net_ok():
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
	if player.move_order:
		_resume_after_move = _resume_after_move or target != null
		return  # [owner 2026-10-28] a click-to-move order outranks combat: no chase, swing or facing
	if _resume_after_move:
		_resume_after_move = false
		if target == null or not is_instance_valid(target) or target.health.dead \
				or player.global_position.distance_to(target.global_position) > 28.0:
			var near := player.actions.nearest_creature(PlayerActions.ATTACK_SEEK_RANGE, false)
			if near:
				start(near)  # her target is gone: the nearest animal, as ATTACK picks
			else:
				stop()
			return
	if target == null or not is_instance_valid(target) or target.health.dead:
		if target:
			stop()
		return
	_maybe_stun_hint()
	if not auto:
		return  # Auto off: only F / pad X / a tap swings (swing_now)
	if not hold and player.global_position.distance_to(target.global_position) > 28.0:
		stop()
		return
	if player.sim.input_vector().length_squared() > 0.0:
		return  # the stick owns her: no chase, no swing; she re-engages when it lets go
	# AUTO-ABILITY before the swing: a ready ability outranks the basic attack. A click-to-move order
	# (checked again inside _auto_attack) still outranks everything.
	last_auto_cast = &""
	if _swing_cd <= 0.0 and not _swing_pending and AutoAbility.try_cast(self):
		return
	_auto_attack()  # facing the target is PlayerSim.face_tick's (physics), not a _process write

## Keep small-creature reach unchanged, but strike the edge of large collision bodies.
## T-rex radius2.88m previously made the fixed2.1m center distance unreachable.
static func melee_reach(creature: Creature) -> float:
	if creature == null or creature.def == null:
		return 2.1
	return maxf(2.1, creature.body_radius() + 0.65)  # body_radius carries the genome size

## HITBOXES: in swing reach when the swing she would play (swing_move) sweeps its weapon through one of
## the target's hurtboxes from where she stands, turned to face it (the flank, legs, head or tail of a
## big body included). Bodies without a skeleton keep BIGREACH's rule below: the centre rule (small
## bodies), or her body edge within edge_reach_m of the target's visible footprint.
func in_reach(t: Creature, slack: float = 0.0) -> bool:
	if Hitbox.applies(player, t):
		if MeleeQuery.surface_gap(player, t) > PREVIEW_GAP_M + slack:
			return false  # nothing she holds reaches that far: skip the sweep
		var mv := swing_move(_weapon())
		# With room to spare (SWING_MARGIN_M) unless its collider already stops her: the swing lands
		# hit_delay later, and an animal backing off at a walk would have left a swing judged at the edge.
		var margin := SWING_MARGIN_M if MeleeQuery.surface_gap(player, t) > 0.05 else 0.0
		return not Hitbox.strike(player, mv[0], t, 0, mv[1], true, aim_point(t) - player.global_position, maxf(0.0, margin - slack)).is_empty()
	var off := t.global_position - player.global_position
	if Vector2(off.x, off.z).length() <= melee_reach(t) + slack:
		return true
	return MeleeQuery.surface_gap(player, t) <= CombatTuning.num("player_melee", "edge_reach_m", 0.5) + slack

const PREVIEW_GAP_M := 2.0  ## no survivor swing reaches past this body-edge gap (blade ~1.8 m from her centre)
const REACH_UP_M := 2.2  ## the highest a swing (aimed up) reaches above her feet
const SWING_MARGIN_M := 0.35  ## she starts a swing this far inside its reach (the hit lands ~0.4 s later)

## HITBOXES: [move, weapon class] of the swing she plays next (data/creatures/hitboxes.json survivor):
## punch bare-handed, heavy for a heavy blunt weapon, else swing; the class picks the blade's length.
func swing_move(w: ItemStack) -> Array:
	if w == null:
		return [&"punch", &""]
	var def := w.def()
	var ch := chain_of(def)
	if not ch.is_empty():
		if Time.get_ticks_msec() * 0.001 - _chain_at > CHAIN_RESET_S:
			_chain_i = 0  # a pause starts the combo again
		return [StringName(str(ch[_chain_i % ch.size()])), weapon_class(def)]
	var heavy := def != null and def.damage_type == &"blunt" and _swing_damage(w) > CombatTuning.num("player_melee", "heavy_swing_min_damage", 10.0)
	return [&"heavy" if heavy else &"swing", weapon_class(def)]

## HEAVY BLADES: a weapon row with a "chain" plays its own moves in order (hitboxes.json survivor.weapons.<class>.chain,
## each a survivor.moves row with its clip, hit windows, channels and damage_mult): the one-hander's cross-slash
## combo, impale and chop, the two-hander's overhead slam and bat sweep. [] for every other weapon.
static func chain_of(def: ItemDef) -> Array:
	if def == null:
		return []
	return ((Hitbox.data().get("survivor", {}) as Dictionary).get("weapons", {}).get(str(def.tool_class), {}) as Dictionary).get("chain", [])

static func move_row(move: StringName) -> Dictionary:
	return ((Hitbox.data().get("survivor", {}) as Dictionary).get("moves", {}) as Dictionary).get(str(move), {})

## ASSUMPTION (PC9): a chain restarts at its first move after this long without a swing.
const CHAIN_RESET_S := 2.5
var _chain_i := 0
var _chain_at := -99.0

## The weapons row the swing takes its blade from: the tool class when the data has one, else the damage type.
static func weapon_class(def: ItemDef) -> StringName:
	if def == null:
		return &""
	var rows: Dictionary = (Hitbox.data().get("survivor", {}) as Dictionary).get("weapons", {})
	return def.tool_class if rows.has(str(def.tool_class)) else def.damage_type

## Where she walks to and swings at: the nearest point of its visible body (its centre once she is inside).
## HITBOXES: with hurtboxes, the nearest hurtbox she can reach from the ground (a leg under a high belly,
## a tail hanging low); else BIGREACH's footprint.
func aim_point(t: Creature) -> Vector3:
	var hb := Hurtboxes.of(t) if Hitbox.applies(player, t) else null
	var p := MeleeQuery.footprint_point(t, player.global_position)
	if hb:
		var feet := MeleeQuery.feet_y(player)
		p = hb.nearest_point(Vector3(player.global_position.x, feet + 1.0, player.global_position.z), feet - 0.1, feet + REACH_UP_M)
		# PARTCOMBAT focus: she walks to and swings at the focused section when it comes into her reach band.
		var focus := focus_point(t, feet)
		if focus != Vector3.INF:
			p = focus
		p.y = t.global_position.y
	return p if Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() > 0.3 else t.global_position

## PARTCOMBAT: the body section the player picked (the target card's picker or a tap on the animal's body), "" = none.
## Melee steers its swings at it where it can reach it; ranged shots aim at it (BodySections.aim_point).
var aim_section: StringName = &""

func set_aim_section(section: StringName) -> void:
	aim_section = section
	SectionHighlight.show_on(target, section)

## The point of the focused section nearest her, among its capsules inside her reach band; INF when none reaches it.
func focus_point(t: Creature, feet: float) -> Vector3:
	if aim_section == &"" or t == null:
		return Vector3.INF
	var at := Vector3(player.global_position.x, feet + 1.0, player.global_position.z)
	var best := Vector3.INF
	var best_d := INF
	for cap in BodySections.caps_of(t, aim_section):
		var a: Vector3 = cap["wa"]
		var b: Vector3 = cap["wb"]
		var r := float(cap["wr"])
		if minf(a.y, b.y) - r > feet + REACH_UP_M or maxf(a.y, b.y) + r < feet - 0.1:
			continue
		var q := Geometry3D.get_closest_point_to_segment(at, a, b)
		if q.distance_to(at) < best_d:
			best_d = q.distance_to(at)
			best = q + (at - q).normalized() * r
	return best

func _auto_attack() -> void:
	# A click-to-move order outranks the auto-attack: she keeps her own path to the clicked point.
	if player.move_order:
		return
	# An attended siege platform never fires or chases automatically.
	var platform := player._nearest_group("catapult") as FieldCatapult
	if platform and player.global_position.distance_to(platform.global_position) <= 3.0:
		return
	if player.statuses.has_flag(&"cannot_act") or player.statuses.has_flag(&"no_attack"):
		return  # knocked down, or Winded (KNOCKDOWN): no swings
	if player.rolling or _tactic_lock > 0.0 or (player.sim and player.sim._stagger_left > 0.0):
		return  # a hurt stun is a hard stun: no swings either
	var ranged_weapon := _weapon()
	if ranged_weapon and ranged_weapon.def() and ranged_weapon.def().range_m > 0.0:
		if player.global_position.distance_to(target.global_position) > ranged_weapon.def().range_m and not hold:
			player.nav_to(target.global_position)
		else:
			fire_ranged()
		return
	if not in_reach(target):
		if MeleeQuery.surface_gap(player, target) <= PREVIEW_GAP_M and not MeleeQuery.clear(player, target):
			say_throttled("Something is in the way.")
			return  # a wall or a ridge between: no walking into it either
		if not hold:
			player.nav_to(aim_point(target))  # its body edge: its centre sits inside its collider
		return
	player.clear_nav()
	if _swing_cd > 0.0 or _swing_pending:
		return
	if not MeleeQuery.clear(player, target):
		say_throttled("Something is in the way.")
		return  # a wall or a ridge between: no swing through it
	begin_swing()

## Manual swing (F, pad X, a tap on the target): swings now when the target is in reach and the
## last swing has recovered, with Auto off or on HOLD too. False = nothing started (out of reach,
## cooling down, rolling); auto-attack still walks over when Auto is on and HOLD is off.
func swing_now() -> bool:
	if target == null or player.move_order or player.rolling or _tactic_lock > 0.0 or _swing_cd > 0.0 or _swing_pending \
			or player.statuses.has_flag(&"cannot_act") or player.statuses.has_flag(&"no_attack"):
		return false
	var w := _weapon()
	if w and w.def() and w.def().range_m > 0.0:
		return fire_ranged()
	if not in_reach(target) or not MeleeQuery.clear(player, target):
		return false
	player.clear_nav()
	player.face_world(aim_point(target))
	begin_swing()
	return true

## Start a swing now; damage lands at the swing's hit fraction (pc-combat-03), not on the press.
## The basic swing/punch is free: stamina only pays for sprint, roll, tackle and kick.
func begin_swing() -> void:
	var w := _weapon()
	var def := w.def() if w else null
	var rate := def.attack_rate if def and def.attack_rate > 0.0 else 1.0
	var mv := swing_move(w)
	var row := move_row(mv[0]) if not chain_of(def).is_empty() else {}
	var forward := aim_point(target) - player.global_position
	forward.y = 0.0
	if not row.is_empty():
		# A chain move: its own clip at its own pace; each hit window lands at its end (the sweep's out and back).
		var clip := StringName(str(row.get("clip", mv[0])))
		player.anim.play_clip(clip)
		var length := player.rig.anim_player.get_animation(clip).length if player.rig and player.rig.has_clip(clip) else 1.0
		_swing_cd = maxf(length * float(row.get("recover", 1.0)), CombatTuning.num("player_melee", "basic_cooldown_s", 0.8))
		_chain_i += 1
		_chain_at = Time.get_ticks_msec() * 0.001 + length
		_swing_pending = true
		swing_started.emit()
		var hits: Array = row.get("hits", [[0.4, 0.6]])
		for i in hits.size():
			get_tree().create_timer(float(hits[i][1]) * length, false).timeout.connect(_on_swing_hit.bind(weakref(target), w, forward.normalized(), mv, i, i == hits.size() - 1), CONNECT_ONE_SHOT)
		return
	if w == null:
		player.play_punch()
	else:
		player.play_attack(mv[0] == &"heavy")
	# Basic attack cooldown (owner: no basic spam): the weapon's cadence, never under basic_cooldown_s.
	_swing_cd = maxf(1.0 / maxf(0.2, rate), CombatTuning.num("player_melee", "basic_cooldown_s", 0.8))
	_swing_pending = true
	swing_started.emit()
	get_tree().create_timer(hit_delay(w), false).timeout.connect(_on_swing_hit.bind(weakref(target), w, forward.normalized(), mv), CONNECT_ONE_SHOT)

## Seconds from the swing press to contact. The survivor clip is rescaled to swing_seconds/rate
## (player_anim._play), so contact sits at hit_frac of that.
# ASSUMPTION: contact at 60 % of the visible swing until W2-PANIM authors clip hit events.
static func hit_delay(w: ItemStack) -> float:
	var def := w.def() if w else null
	var rate := def.attack_rate if def and def.attack_rate > 0.0 else 1.0
	var t := CombatTuning.section("player_melee")
	return float(t.get("hit_frac", 0.6)) * float(t.get("swing_seconds", 0.65)) / maxf(0.2, rate)

func _on_swing_hit(ref: WeakRef, w: ItemStack, forward: Vector3, mv: Array = [], hit_index: int = 0, last: bool = true) -> void:
	if last:
		_swing_pending = false
	var t := ref.get_ref() as Creature
	if t == null or t != target or t.health.dead or player == null or player.dead:
		return  # hunt stopped or retargeted mid-swing: the swing is lost, not landed on the old target
	if player.rolling or player.statuses.has_flag(&"cannot_act"):
		return  # knocked down or rolled out mid-swing: the swing is lost
	if Hitbox.applies(player, t):
		# HITBOXES: the swing's fist or blade, swept through the clip's window where she stands now.
		if mv.is_empty():
			mv = swing_move(w)
		# Judged facing where the swing was aimed when it started (the reach test's direction), else where
		# she has turned since (PlayerSim.face_tick tracks the nearest part, which can flip mid-swing).
		var hit := Hitbox.strike(player, mv[0], t, hit_index, mv[1], false, forward)
		if hit.is_empty():
			hit = Hitbox.strike(player, mv[0], t, hit_index, mv[1], false, aim_point(t) - player.global_position)
		if hit.is_empty():
			CombatAvoid.avoided(t, player, &"miss")
			return  # it stepped out of the swing
		if not MeleeQuery.clear(player, t):
			return
		Hitbox.mark(t, hit)
		hit["move"] = mv[0]
		land_hit(t, w, hit.get("spot", {}), hit)
		return
	var offset := aim_point(t) - player.global_position
	offset.y = 0.0
	var tune := CombatTuning.section("player_melee")
	if not in_reach(t, float(tune.get("hit_reach_slack_m", 0.3))):
		CombatAvoid.avoided(t, player, &"miss")
		return  # it stepped out of the swing
	if forward != Vector3.ZERO and offset.normalized().dot(forward) < float(tune.get("hit_arc_min_dot", 0.0)):
		CombatAvoid.avoided(t, player, &"miss")
		return  # it got behind the swing
	if not MeleeQuery.clear(player, t):
		return
	land_hit(t, w)

## Survivor swing chance: accuracy x status accuracy_mult against dodge + evasion_add.
func hit_chance(t: Creature) -> float:
	var acc := CombatTuning.num("player_melee", "base_accuracy", 1.0) * player.statuses.accuracy_mult()
	var dodge := t.dodge_chance() + t.statuses.evasion_add() * CombatTuning.top("evasion_add_scale", 0.01)
	return CombatTuning.hit_chance(acc, dodge)

## One roll of a swing on it: &"" hit, &"dodge" (its dodge) or &"miss" (her accuracy).
func swing_outcome(t: Creature) -> StringName:
	var acc := CombatTuning.num("player_melee", "base_accuracy", 1.0) * player.statuses.accuracy_mult()
	return CombatTuning.swing_outcome(acc, t.dodge_chance() + t.statuses.evasion_add() * CombatTuning.top("evasion_add_scale", 0.01))

func _swing_damage(w: ItemStack) -> float:
	var tune := CombatTuning.section("player_melee")
	if w == null:
		return float(tune.get("unarmed_damage", 8.0))
	var dmg := w.scaled_damage()
	if w.def() and w.def().is_work_tool:
		dmg *= float(tune.get("work_tool_mult", 0.45))
	return dmg

## Resolve one swing that reached the target. Returns whether it landed. Statuses, wear, XP
## and the tyrant counter happen only on a landed hit. spot: the crit spot its hitbox passed through (Hitbox.strike).
## hit: the Hitbox.strike result ({part, surface}): its body section takes armour, Wounds and build-up (BodyWounds).
func land_hit(t: Creature, w: ItemStack, spot: Dictionary = {}, hit: Dictionary = {}) -> bool:
	var how := swing_outcome(t)
	if how != &"":
		CombatAvoid.avoided(t, player, how)
		return false
	var tune := CombatTuning.section("player_melee")
	var def := w.def() if w else null
	var dmg := _swing_damage(w) * float(move_row(hit.get("move", &"")).get("damage_mult", 1.0))
	var dtype := def.damage_type if def else &"blunt"
	var defense := t.defense_for(false) * t.statuses.defense_mult()
	var dealt: float = maxf(dmg * float(tune.get("min_damage_frac", 0.05)), dmg - defense * float(tune.get("defense_factor", 0.5)))
	var behind := _is_behind_of(t)
	if behind:
		dealt *= float(tune.get("behind_mult", 1.25))
	# Bonuses count from Lv. 1 (W2-SKILLS: trees start at 1), so a new survivor hits as before.
	var melee_lv := maxi(0, player.skills.level_of("melee") - SkillState.MIN_LEVEL) if player.skills else 0
	dealt *= 1.0 + float(tune.get("damage_per_melee_level", 0.01)) * float(melee_lv)  # ASSUMPTION +1 % per Melee level
	# Data-driven combat matchup, then a crit roll (x1.75 red): 8 % base, +20 % from behind,
	# +0.2 % per Melee level.
	var kind := effectiveness(t, dtype)
	dealt *= CombatCounters.multiplier(t.def.archetype, dtype)
	# BODY SECTIONS: unbroken armour on the section takes a cut of the hit; a Wound there crits like a crit spot.
	var section: StringName = BodySections.of_hit(t, hit["part"], hit.get("surface", hit.get("at", t.global_position))) if hit.has("part") else &""
	var armour := BodyWounds.damage_mult(t, section)
	dealt *= armour
	if armour < 1.0:
		kind = &"armoured"
	var wound := BodyWounds.wound_spot(t, section, hit.get("surface", Vector3.ZERO)) if spot.is_empty() else {}
	var crit_chance := float(tune.get("crit_base", 0.08)) + (float(tune.get("crit_behind", 0.2)) if behind else 0.0) + float(tune.get("crit_per_melee_level", 0.002)) * float(melee_lv)
	# WEAK SPOTS: a hit in a crit spot is a sure crit at the spot's multiplier; any other hit rolls the chance crit.
	var spot_mult := CritSpots.land(t, spot, player)
	if spot_mult > 0.0:
		dealt *= spot_mult
		kind = CritSpots.KIND
	elif not wound.is_empty():
		dealt *= float(wound["mult"])
		kind = &"wound"
		t.hit_burst(BodyWounds.GASH, 0.18, 18, 0.4, wound["centre"])
	elif CombatTuning.roll(crit_chance):
		dealt *= float(tune.get("crit_mult", 1.75))
		kind = &"crit"
	t.next_hit_kind = kind
	t.health.take_damage(dealt, player)
	if section != &"":
		var chans: Array = move_row(hit.get("move", &"")).get("channels", BodyWounds.channels(def))
		BodyWounds.register(t, section, chans, hit.get("surface", hit.get("at", t.global_position)), hit["part"], player)
	hit_landed.emit(t)
	if player.skills:
		player.skills.add_xp("melee", int(tune.get("xp_per_hit", 2)))
	print("[combat] player hit %s dmg=%.1f type=%s kind=%s section=%s" % [t.def.id, dealt, dtype, kind, section])
	wear_weapon(w)
	apply_counter_hit(w, t)
	if dtype == &"blunt" and t.brain is TyrantBrain: (t.brain as TyrantBrain).blunt_counter()
	if dtype == &"blunt":
		t.add_torpor(CombatTuning.num("torpor", "blunt", 6.0), player)
	if dtype == &"blunt" and not t.health.dead and CombatTuning.roll(float(tune.get("blunt_groggy_chance", 0.35))):
		t.statuses.apply(&"groggy", player)
	if kind == &"crit" or (kind != CritSpots.KIND and dtype == &"blunt" and dmg > float(tune.get("heavy_swing_min_damage", 10.0))):
		IsoCamera.shake(player, CombatTuning.num("camera", "player_heavy_swing", 0.25))
	return true

## Weapons wear on every landed hit (durability-01: the market needs an item sink).
func wear_weapon(w: ItemStack) -> void:
	if w == null or w.is_broken():
		return  # stones still in flight after the snare broke it must not repeat "X broke."
	if w.max_durability <= 0:
		return
	if not w.wear(int(CombatTuning.top("weapon_wear_per_hit", 1))):
		print("[item] %s broke" % w.def_id)
		say("%s broke." % (w.def().display_name if w.def() else str(w.def_id)))
	player.inventory.changed.emit()

## The equipped weapon, or null when it is broken (a broken weapon fights as bare hands).
func _weapon() -> ItemStack:
	var w := player.inventory.equipped_weapon()
	return null if w == null or w.is_broken() else w

func say(text: String) -> void:
	last_notice = text
	player.notice(text)

## Auto-attack retries every frame; tell the player once every few seconds, not silently.
## Per text: one shared timestamp let a "No clear shot" swallow a later "Something is in the way".
func say_throttled(text: String) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_notice_s.get(text, -99.0)) > NOTICE_THROTTLE_S:
		_notice_s[text] = now
		say(text)

## Chart feedback: strong above1, weak below1, otherwise neutral hit.
static func effectiveness(c: Creature, dtype: StringName) -> StringName:
	if c == null or c.def == null or dtype == &"":
		return &"hit"
	var value := CombatCounters.multiplier(c.def.archetype, dtype)
	if value > 1.0: return &"strong"
	if value < 1.0: return &"weak"
	return &"hit"

## Tackle and Kick may cut the auto-attack's own swing short (it was always busy mid-fight, so both
## refused silently); a roll, a hurt stun, a knockdown or the previous tactic's lock still block them.
func can_start_tactic() -> bool:
	if player == null or player.rolling or player.statuses.has_flag(&"cannot_act") or player.statuses.has_flag(&"no_attack"):
		return false
	if player.anim and player.anim._busy and not (player.anim.current_clip in [&"attack_primary", &"attack_heavy", &"punch"] or PlayerAnim.is_weapon_move(player.anim.current_clip)):
		return false
	if player.sim and player.sim._stagger_left > 0.0:
		return false
	return _tactic_lock <= 0.0

## CombatTactics goes through these two; the fields stay because hunt_hud reads them.
func cooldown_left(kind: StringName) -> float:
	return _tackle_cd if kind == &"tackle" else _kick_cd

func commit_tactic(kind: StringName, cooldown: float, lock: float) -> void:
	if kind == &"tackle":
		_tackle_cd = cooldown
	else:
		_kick_cd = cooldown
	_tactic_lock = lock
	_swing_cd = maxf(_swing_cd, lock)

func use_tackle() -> void:
	CombatTactics.tackle(self)

func use_kick() -> void:
	CombatTactics.kick(self)

## Nets follow the one capture rule (FieldTame.capture_window): weak (stunned, or <= 30 %) and torpor
## past the knock-out threshold.
func use_net() -> void:
	if target == null:
		return
	# ALPHATAG (owner 2026-10-29): an alpha cannot be netted; the refusal names the rule, not the HP.
	if FieldTame.is_alpha(target):
		say(FieldTame.ALPHA_REFUSAL)
		return
	if not _net_health_ok():
		say(FieldTame.refusal(target))
		return
	CaptureSystem.attempt(player, target)

func _net_health_ok() -> bool:
	return target != null and FieldTame.capture_window(target)

## Spec 09 §1: a tameable wild animal you are fighting that is unstunned and at or under 50 % HP
## gets one hint per creature, through say() (no new widget).
func _maybe_stun_hint() -> void:
	if player == null or target == null or not is_instance_valid(target):
		return
	if target.def == null or target.health == null or not target.def.tameable or target.is_pet:
		return
	if target.health.dead or target.health.fraction() > STUN_HINT_FRAC:
		return
	if target.statuses != null and target.statuses.has(&"knockdown"):
		return
	var key := target.get_instance_id()
	if _stun_hinted.has(key):
		return
	_stun_hinted[key] = true
	say(STUN_HINT)

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
	if w and int(w.attributes.get("sedative_hits", 0)) > 0:
		w.attributes["sedative_hits"] = int(w.attributes["sedative_hits"]) - 1
		victim.add_torpor(CombatTuning.num("torpor", "sedative", 20.0), player)
		player.inventory.changed.emit()
	if w and int(w.attributes.get("toxin_hits", 0)) > 0:
		w.attributes["toxin_hits"] = int(w.attributes["toxin_hits"]) - 1
		if not victim.health.dead: victim.statuses.apply(&"poisoned_target", player)
		player.inventory.changed.emit()

## Fixed aim at launch, real projectile collision. Auto and Fire context share this action.
## `ammo` overrides the weapon's own ammo (a Tranquilizer Dart from the "Dart" hex).
## PARTCOMBAT: the shot flies at the picked body section (aim_section, else ranged.unaimed_section) where it is when the
## shot leaves, with spread (aimed_shot). A bow draws (wpn_bow_draw), looses at the end of the draw (wpn_bow_release).
func fire_ranged(ammo: StringName = &"") -> bool:
	if target == null or not is_instance_valid(target) or target.health.dead: return false
	var weapon := _weapon()
	var def := weapon.def() if weapon else null
	if def == null or def.range_m <= 0.0: return false
	if _ranged_pending or _swing_cd > 0 or player.dead or player.rolling or player.anim._busy or player.statuses.has_flag(&"cannot_act") or player.statuses.has_flag(&"no_attack"): return false
	var origin := player.global_position + Vector3(0,0.3,0)
	var aim := target.global_position + Vector3(0, minf(1.0, target.def.height_meters * 0.4),0)
	var offset := aim-origin
	if offset.length() > def.range_m or offset.length() < 0.1: return false
	var query := PhysicsRayQueryParameters3D.create(origin, aim)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") != target:
		say_throttled("No clear shot: something is in the way.")
		return false
	var ammo_id := ammo if ammo != &"" else def.ammo_id
	if player.inventory.count_of(ammo_id) < 1:
		say("Need %s" % (Data.item(ammo_id).display_name.to_lower() if Data.item(ammo_id) else str(ammo_id)))
		_swing_cd = 1.0
		return false
	player.clear_nav()
	player.face_world(target.global_position)
	var row := HeldModel.weapon_row(def.id)
	var draw := StringName(str(row.get("draw_clip", "")))
	var wind := 0.25
	var clip := &"attack_primary"
	if draw != &"" and player.rig and player.rig.has_clip(draw):
		clip = draw
		wind = player.rig.anim_player.get_animation(draw).length * 0.9  # looses just before the draw clip ends
		player.anim.play_clip(draw)
	else:
		player.play_attack(false)
	_ranged_pending = true
	_swing_cd = maxf(1.0 / maxf(0.2, def.attack_rate), wind + 0.2)
	swing_started.emit()
	var runtime := World.runtime
	var t := target
	# Aim at the section where it is when the shot leaves, not a homing shot.
	player.get_tree().create_timer(wind).timeout.connect(func () -> void:
		_ranged_pending = false
		if not is_instance_valid(player) or player.dead or player.rolling or player.inventory.equipped_weapon() != weapon or not is_instance_valid(runtime) or runtime != World.runtime: return
		if player.anim.current_clip != clip and player.anim._busy: return  # a hit or a roll cut the draw short
		if not is_instance_valid(t) or t.health.dead: return
		if not player.inventory.consume(ammo_id, 1): return
		var release := StringName(str(row.get("release_clip", "")))
		if release != &"" and player.rig and player.rig.has_clip(release):
			player.anim.play_clip(release)
		var shot := aimed_shot(player, weapon, t, aim_section, ammo_id, runtime)
		if ammo_id == TRANQ_DART:
			shot.damage *= CombatTuning.num("torpor", "dart_damage_mult", 0.25)
			shot.torpor = CombatTuning.num("torpor", "dart", 30.0)
	)
	return true

## The shot's spread at the target, metres (a 2D normal's sigma): it grows with distance and the target's speed, and
## shrinks with the projectile's speed. ASSUMPTION (PC6): combat_tuning ranged.sigma_per_m, ref_speed, move_sigma_k.
static func shot_sigma(dist: float, speed: float, target_speed: float) -> float:
	var tune := CombatTuning.section("ranged")
	var flight := dist / maxf(1.0, speed)
	return float(tune.get("sigma_per_m", 0.012)) * dist * float(tune.get("ref_speed", 18.0)) / maxf(1.0, speed) \
		+ float(tune.get("move_sigma_k", 0.35)) * target_speed * flight

static func projectile_speed(ammo_id: StringName) -> float:
	return float((CombatTuning.section("ranged").get("projectile_speed", {}) as Dictionary).get(str(ammo_id), StoneProjectile.SPEED))

## Seeded by tests; the game draws from its own.
static var shot_rng := RandomNumberGenerator.new()

## One aimed shot from her bow or sling at a body section of t, launched now into `parent`: it flies at the section's
## live point (its crit spot, if it holds one) plus a miss drawn from shot_sigma across the line of fire; the target
## keeps moving while it flies. Returns the projectile (tests read its result).
static func aimed_shot(p: Player, weapon: ItemStack, t: Creature, section: StringName, ammo_id: StringName, parent: Node) -> StoneProjectile:
	var origin := p.global_position + Vector3(0, 1.4, 0)
	var sec := section if section != &"" else StringName(str(CombatTuning.section("ranged").get("unaimed_section", "torso")))
	if Hurtboxes.of(t) == null or not sec in BodySections.names(t):
		sec = &""
	var aim := BodySections.aim_point(t, sec) if sec != &"" else t.global_position + Vector3(0, minf(1.0, t.def.height_meters * 0.4), 0)
	var speed := projectile_speed(ammo_id)
	var line := aim - origin
	var tv := Vector3(t.velocity.x, 0.0, t.velocity.z) if "velocity" in t else Vector3.ZERO
	var sigma := shot_sigma(line.length(), speed, tv.length())
	var side := line.cross(Vector3.UP).normalized()
	var up := side.cross(line).normalized()
	# A 2D normal miss (Box-Muller) across the line of fire.
	var r := sigma * sqrt(-2.0 * log(maxf(1e-9, shot_rng.randf())))
	var a := TAU * shot_rng.randf()
	aim += side * r * cos(a) + up * r * sin(a)
	var shot := StoneProjectile.new()
	shot.source = p
	shot.weapon = weapon
	shot.ammo = ammo_id
	shot.aimed_section = sec
	shot.radius = float((CombatTuning.section("ranged").get("shot_radius", {}) as Dictionary).get(str(ammo_id), 0.08))
	shot.velocity = StoneProjectile.launch_velocity(aim - origin, speed)
	shot.damage = weapon.scaled_damage() if weapon else 10.0
	# The arc flies past the weapon's straight range so a lobbed stone can land on a target at
	# the edge; the multiplier is tuning, not code (combat_tuning.json ranged.arc_range_mult).
	var range_m: float = weapon.def().range_m if weapon and weapon.def() else 12.0
	shot.range_left = range_m * float(CombatTuning.section("ranged").get("arc_range_mult", 1.5))
	shot.skill_level = maxi(0, p.skills.level_of("ranged") - SkillState.MIN_LEVEL) if p.skills else 0
	parent.add_child(shot)
	shot.global_position = origin
	return shot
