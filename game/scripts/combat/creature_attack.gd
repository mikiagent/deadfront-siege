class_name CreatureAttack
extends RefCounted
## Maps clip + species status_applied onto the target.

static func apply_for(attacker: Creature, clip: StringName, target: Node) -> void:
	if attacker == null or attacker.def == null or target == null:
		return
	var tokens := attacker.def.status_applied
	if clip == &"attack_heavy" or clip == &"attack_primary":
		for tok in tokens:
			_apply_token(tok, clip, target, attacker)
	_deal_damage(attacker, target, clip)

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
		(target as Player).statuses.apply(id, source, int(parsed["stacks"]))

static func _deal_damage(attacker: Creature, target: Node, clip: StringName = &"attack_primary") -> void:
	var atk := attacker.attack_for(false) * attacker.statuses.attack_mult()
	if attacker.is_pet and attacker.pet_record:
		atk = attacker.pet_record.stat_value(&"melee_attack") * attacker.statuses.attack_mult()
	var defn := 0.0
	if target is Player:
		if (target as Player).dead:
			return
		defn = 20.0 * (target as Player).statuses.defense_mult()
		var raw: float = atk - defn * 0.5
		var dealt: float = maxf(atk * 0.05, raw)
		if Telegraph.player_dodged(attacker) or randf() > attacker.accuracy_chance():
			print("[combat] dodged %s %s" % [attacker.def.id, attacker.anim.current_clip])
			return
		if randf() < attacker.crit_chance():
			dealt *= 1.5
			(attacker as Creature).combat_float.emit(dealt, &"crit")
		(target as Player).vitals.take_damage(dealt)
		if (target as Player).has_method("take_hit_fx"):
			(target as Player).take_hit_fx(dealt, clip == &"attack_heavy")
		print("[combat] %s hit player dmg=%.1f clip=%s" % [attacker.def.id, dealt, attacker.anim.current_clip])
	elif target is Creature:
		var cr := target as Creature
		var dodge := cr.pet_record.dodge_chance(cr.def) if cr.is_pet and cr.pet_record else cr.dodge_chance()
		if randf() > attacker.accuracy_chance() or randf() < dodge:
			cr.combat_float.emit(0.0, &"dodge")
			return
		defn = (cr.pet_record.stat_value(&"melee_defense") if cr.is_pet and cr.pet_record else cr.defense_for(false)) * cr.statuses.defense_mult()
		var raw: float = atk - defn * 0.5
		var dealt: float = maxf(atk * 0.05, raw)
		if randf() < attacker.crit_chance():
			dealt *= 1.5
			cr.next_hit_kind = &"crit"
		cr.health.take_damage(dealt, attacker)
		if attacker.is_pet and attacker.pet_record and not cr.is_pet:
			if attacker.pet_record.add_xp(1.0) > 0:
				attacker.level = attacker.pet_record.level
				attacker.health.max_hp = attacker.pet_record.hp
				attacker.combat_float.emit(attacker.pet_record.level, &"xp")
