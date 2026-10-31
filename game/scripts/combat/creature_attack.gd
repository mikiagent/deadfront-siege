class_name CreatureAttack
extends RefCounted
## One creature contact attack: reach check, hit roll, damage, then species statuses.
## Statuses ride on the hit, so a dodge, a miss or a wall in between applies nothing.

## Returns whether the attack landed (callers play hit reactions only when it did).
## mult scales the damage (TACTICS: the combo's rising bites, the pounce).
static func apply_for(attacker: Creature, clip: StringName, target: Node, mult: float = 1.0) -> bool:
	if attacker == null or attacker.def == null or target == null:
		return false
	# A structure is the obstacle itself (and stands on its own foundation), so only reach applies.
	if target is Node3D and not StructureHealth.is_structure(target) and not MeleeQuery.clear(attacker, target as Node3D):
		print("[combat] %s %s blocked: no clear reach to %s" % [attacker.def.id, clip, target.name])
		return false
	if not _deal_damage(attacker, target, clip, mult):
		return false
	if (clip == &"attack_heavy" or clip == &"attack_primary" or clip == &"grab_bite") and not _target_dead(target):  # grab_bite: the bite with arms (UTAHARMS)
		for tok in attacker.def.status_applied:
			_apply_token(tok, clip, target, attacker)
	return true

static func _target_dead(target: Node) -> bool:
	if target is Player:
		return (target as Player).dead
	if target is Creature:
		return (target as Creature).health.dead
	if target is TribeMember:
		return (target as TribeMember).health.dead
	return false

static func _apply_token(tok: StringName, clip: StringName, target: Node, source: Creature) -> void:
	var parsed := StatusEffects.parse_token(tok)
	var id: StringName = parsed["id"]
	# pipeline.status_clips {status: [clips]}: a status only rides on those clips (the ceratosaurus' slashing bite bleeds, its gore does not).
	var only: Variant = (source.def.pipeline.get("status_clips", {}) as Dictionary).get(str(id)) if source.def.pipeline.get("status_clips") is Dictionary else null
	if only is Array and not (only as Array).has(str(clip)):
		return
	# Velociraptor: pounce (heavy) applies knockdown + bleed x2; primary is just contact damage.
	if source.def.id == &"velociraptor" and clip != &"attack_heavy" and (id == &"knockdown" or id == &"bleed"):
		return
	# PINFEEL fairness: a predator that pins with its foot (pin_foot) pins only with its telegraphed heavy (the
	# T. rex stomp: the foot hauled up and held through a 1.2 s STOMP windup), never off a bite.
	var foot_pin := id == &"pinned" and source.anim != null and source.anim.has_state(&"pin_foot")
	if foot_pin and clip != &"attack_heavy":
		return
	if target is Creature:
		(target as Creature).statuses.apply(id, source, int(parsed["stacks"]))
		if id == &"knockdown":
			(target as Creature).anim.play_clip(&"knockdown")
		if foot_pin and (target as Creature).statuses.has(&"pinned"):
			source.start_pin(target as Creature)
	elif target is Player:
		# The reinforced full kit keeps the tyrant's first hit from permanently removing
		# dodge/agency. Deafened and damage still land; incomplete/low-level kits do not help.
		if source.def.id == &"tyrannosaurus" and id in [&"fracture", &"pinned"] and (target as Player).inventory.has_raid_protection():
			return
		(target as Player).statuses.apply(id, source, int(parsed["stacks"]))
		if foot_pin and (target as Player).statuses.has(&"pinned"):
			source.start_pin(target as Player)

## Chance this attacker's swing connects with that target (accuracy x status accuracy_mult,
## against the target's dodge plus status evasion_add).
static func hit_chance(attacker: Creature, target: Node) -> float:
	var ad := _acc_dodge(attacker, target)
	return CombatTuning.hit_chance(ad.x, ad.y)

## One roll of this swing: &"" hit, &"dodge" or &"miss" (CombatTuning.swing_outcome, the same odds).
static func outcome(attacker: Creature, target: Node) -> StringName:
	var ad := _acc_dodge(attacker, target)
	return CombatTuning.swing_outcome(ad.x, ad.y)

static func _acc_dodge(attacker: Creature, target: Node) -> Vector2:
	var acc := attacker.accuracy_chance() * attacker.statuses.accuracy_mult()
	var dodge := 0.0  # the survivor's only dodge is the roll, checked against the telegraph
	if target is Creature:
		var cr := target as Creature
		dodge = cr.pet_record.dodge_chance(cr.def) if cr.is_pet and cr.pet_record else cr.dodge_chance()
		dodge += cr.statuses.evasion_add() * CombatTuning.top("evasion_add_scale", 0.01)
	elif target is Player:
		dodge = (target as Player).statuses.evasion_add() * CombatTuning.top("evasion_add_scale", 0.01)
	return Vector2(acc, dodge)

## Subtractive armour with a floor, today's model (armor-01 / pc-balance-01 wait on the owner).
static func mitigated(atk: float, defense: float) -> float:
	var t := CombatTuning.section("creature_melee")
	return maxf(atk * float(t.get("min_damage_frac", 0.05)), atk - defense * float(t.get("defense_factor", 0.5)))

static func _deal_damage(attacker: Creature, target: Node, clip: StringName = &"attack_primary", mult: float = 1.0) -> bool:
	var atk := attacker.attack_for(false) * attacker.statuses.attack_mult() * mult
	# Every structure (modular piece, catapult, kit) takes creature damage only through its
	# StructureHealth, which applies the tier's creature multiplier and destroys it at 0.
	var structure := StructureHealth.of(target, true)
	if structure:
		structure.take_damage(atk, attacker)
		return true
	if attacker.is_pet and attacker.pet_record:
		atk = attacker.pet_record.stat_value(&"melee_attack") * attacker.statuses.attack_mult() * mult
	var crit_mult := CombatTuning.num("creature_melee", "crit_mult", 1.5)
	if target is Player:
		var survivor := target as Player
		if survivor.dead:
			return false
		var how := outcome(attacker, survivor)
		var lands := how == &""
		# The roll's opening window (RollRules.iframes_s(), the same rule the server times): a hit
		# that reaches her inside it is dodged outright, before any damage, stagger or status.
		if survivor.sim != null and survivor.sim.roll_invulnerable():
			survivor.roll_dodge(clip, attacker, lands)
			return false
		if Telegraph.player_dodged(attacker):
			# Stepping out of a telegraphed attack trains Defense only when it would have landed.
			CombatAvoid.avoided(survivor, attacker, &"dodge", lands)
			return false
		if not lands:
			CombatAvoid.avoided(survivor, attacker, how, false)  # a passive dodge-chance or plain miss: no Defense XP
			return false
		survivor.refresh_equipment_vitals()
		var defn := (CombatTuning.num("creature_melee", "player_base_defense", 20.0) + survivor.inventory.equipped_armor()) * survivor.statuses.defense_mult()
		var dealt := mitigated(atk, defn)
		if CombatTuning.roll(attacker.crit_chance()):
			dealt *= crit_mult
			attacker.combat_float.emit(dealt, &"crit")
		survivor.vitals.take_damage(dealt)
		if dealt > 0.0:  # P1 WEAR: a damaging hit wears one worn armor piece
			var inv := survivor.inventory
			if Inventory.wear_armor_piece([inv.equipped_in(&"head"), inv.equipped_in(&"body"), inv.equipped_in(&"arms"), inv.equipped_in(&"legs")], CombatTuning.rng):
				inv.changed.emit()
		survivor.take_hit_fx(dealt, clip == &"attack_heavy")
		IsoCamera.shake(survivor, CombatTuning.num("camera", "heavy_hit" if clip == &"attack_heavy" else "player_hit", 0.35))
		print("[combat] %s hit player dmg=%.1f clip=%s x%.2f" % [attacker.def.id, dealt, attacker.anim.current_clip, mult])
		return true
	if target is Creature:
		var cr := target as Creature
		var how := outcome(attacker, cr)
		if how != &"":
			CombatAvoid.avoided(cr, attacker, how)
			return false
		var defn := (cr.pet_record.stat_value(&"melee_defense") if cr.is_pet and cr.pet_record else cr.defense_for(false)) * cr.statuses.defense_mult()
		var dealt := mitigated(atk, defn)
		if CombatTuning.roll(attacker.crit_chance()):
			dealt *= crit_mult
			cr.next_hit_kind = &"crit"
		cr.health.take_damage(dealt, attacker)
		if attacker.is_pet and attacker.pet_record and not cr.is_pet:
			if attacker.pet_record.add_xp(1.0) > 0:
				attacker.level = attacker.pet_record.level
				attacker.health.max_hp = attacker.pet_record.hp
				attacker.combat_float.emit(attacker.pet_record.level, &"xp")
		return true
	if target is TribeMember:  # TRIBE M1: a member a creature turned on (it hit the creature)
		var tm := target as TribeMember
		if tm.health.dead or not CombatTuning.roll(hit_chance(attacker, tm)):
			return false
		return tm.take_creature_hit(attacker, atk)
	return false
