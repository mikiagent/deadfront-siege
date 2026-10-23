class_name CreatureAttack
extends RefCounted
## One creature contact attack: reach check, hit roll, damage, then species statuses.
## Statuses ride on the hit, so a dodge, a miss or a wall in between applies nothing.

## Returns whether the attack landed (callers play hit reactions only when it did).
static func apply_for(attacker: Creature, clip: StringName, target: Node) -> bool:
	if attacker == null or attacker.def == null or target == null:
		return false
	# A structure is the obstacle itself (and stands on its own foundation), so only reach applies.
	if target is Node3D and not StructureHealth.is_structure(target) and not MeleeQuery.clear(attacker, target as Node3D):
		print("[combat] %s %s blocked: no clear reach to %s" % [attacker.def.id, clip, target.name])
		return false
	if not _deal_damage(attacker, target, clip):
		return false
	if (clip == &"attack_heavy" or clip == &"attack_primary") and not _target_dead(target):
		for tok in attacker.def.status_applied:
			_apply_token(tok, clip, target, attacker)
	return true

static func _target_dead(target: Node) -> bool:
	if target is Player:
		return (target as Player).dead
	if target is Creature:
		return (target as Creature).health.dead
	return false

static func _apply_token(tok: StringName, clip: StringName, target: Node, source: Creature) -> void:
	var parsed := StatusEffects.parse_token(tok)
	var id: StringName = parsed["id"]
	# Velociraptor: pounce (heavy) applies knockdown + bleed x2; primary is just contact damage.
	if source.def.id == &"velociraptor" and clip != &"attack_heavy" and (id == &"knockdown" or id == &"bleed"):
		return
	if target is Creature:
		(target as Creature).statuses.apply(id, source, int(parsed["stacks"]))
		if id == &"knockdown":
			(target as Creature).anim.play_clip(&"knockdown")
	elif target is Player:
		# The reinforced full kit keeps the tyrant's first hit from permanently removing
		# dodge/agency. Deafened and damage still land; incomplete/low-level kits do not help.
		if source.def.id == &"tyrannosaurus" and id in [&"fracture", &"pinned"] and (target as Player).inventory.has_raid_protection():
			return
		(target as Player).statuses.apply(id, source, int(parsed["stacks"]))

## Chance this attacker's swing connects with that target (accuracy x status accuracy_mult,
## against the target's dodge plus status evasion_add).
static func hit_chance(attacker: Creature, target: Node) -> float:
	var acc := attacker.accuracy_chance() * attacker.statuses.accuracy_mult()
	var dodge := 0.0  # the survivor's only dodge is the roll, checked against the telegraph
	if target is Creature:
		var cr := target as Creature
		dodge = cr.pet_record.dodge_chance(cr.def) if cr.is_pet and cr.pet_record else cr.dodge_chance()
		dodge += cr.statuses.evasion_add() * CombatTuning.top("evasion_add_scale", 0.01)
	elif target is Player:
		dodge = (target as Player).statuses.evasion_add() * CombatTuning.top("evasion_add_scale", 0.01)
	return CombatTuning.hit_chance(acc, dodge)

## Subtractive armour with a floor, today's model (armor-01 / pc-balance-01 wait on the owner).
static func mitigated(atk: float, defense: float) -> float:
	var t := CombatTuning.section("creature_melee")
	return maxf(atk * float(t.get("min_damage_frac", 0.05)), atk - defense * float(t.get("defense_factor", 0.5)))

static func _deal_damage(attacker: Creature, target: Node, clip: StringName = &"attack_primary") -> bool:
	var atk := attacker.attack_for(false) * attacker.statuses.attack_mult()
	# Every structure (modular piece, catapult, kit) takes creature damage only through its
	# StructureHealth, which applies the tier's creature multiplier and destroys it at 0.
	var structure := StructureHealth.of(target, true)
	if structure:
		structure.take_damage(atk, attacker)
		return true
	if attacker.is_pet and attacker.pet_record:
		atk = attacker.pet_record.stat_value(&"melee_attack") * attacker.statuses.attack_mult()
	var crit_mult := CombatTuning.num("creature_melee", "crit_mult", 1.5)
	if target is Player:
		var survivor := target as Player
		if survivor.dead:
			return false
		if Telegraph.player_dodged(attacker) or not CombatTuning.roll(hit_chance(attacker, survivor)):
			print("[combat] dodged %s %s" % [attacker.def.id, attacker.anim.current_clip])
			return false
		survivor.refresh_equipment_vitals()
		var defn := (CombatTuning.num("creature_melee", "player_base_defense", 20.0) + survivor.inventory.equipped_armor()) * survivor.statuses.defense_mult()
		var dealt := mitigated(atk, defn)
		if CombatTuning.roll(attacker.crit_chance()):
			dealt *= crit_mult
			attacker.combat_float.emit(dealt, &"crit")
		survivor.vitals.take_damage(dealt)
		survivor.take_hit_fx(dealt, clip == &"attack_heavy")
		IsoCamera.shake(survivor, CombatTuning.num("camera", "heavy_hit" if clip == &"attack_heavy" else "player_hit", 0.35))
		print("[combat] %s hit player dmg=%.1f clip=%s" % [attacker.def.id, dealt, attacker.anim.current_clip])
		return true
	if target is Creature:
		var cr := target as Creature
		if not CombatTuning.roll(hit_chance(attacker, cr)):
			cr.combat_float.emit(0.0, &"dodge")
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
	return false
