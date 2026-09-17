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
	_deal_damage(attacker, target)

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

static func _deal_damage(attacker: Creature, target: Node) -> void:
	var atk := attacker.def.attack * attacker.statuses.attack_mult()
	var defn := 0.0
	if target is Player:
		defn = 20.0 * (target as Player).statuses.defense_mult()
		var raw: float = atk - defn * 0.5
		var dealt: float = maxf(atk * 0.05, raw)
		if Telegraph.player_dodged(attacker):
			print("[combat] dodged %s %s" % [attacker.def.id, attacker.anim.current_clip])
			return
		(target as Player).vitals.take_damage(dealt)
		print("[combat] %s hit player dmg=%.1f clip=%s" % [attacker.def.id, dealt, attacker.anim.current_clip])
	elif target is Creature:
		var cr := target as Creature
		defn = cr.def.defense * cr.statuses.defense_mult()
		var raw: float = atk - defn * 0.5
		var dealt: float = maxf(atk * 0.05, raw)
		cr.health.take_damage(dealt, attacker)
