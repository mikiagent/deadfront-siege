class_name CaptureSystem
extends RefCounted
## Net capture (durango 09): FieldTame.capture_eligible (stunned at any HP, or under the health gate)
## -> chance from actual HP, level and capture ability -> captured_animal stack (a pen turns it into a
## bonded pet). Numbers live in breeding.json "capture".

## Probability of one net throw. Capture ability = net tier above the species tier.
## ASSUMPTION: base by net tier x (1.5 - HP fraction) x level penalty x ability bonus.
static func chance(net_tier: int, species_tier: int, hp_fraction: float, level: int) -> float:
	var c := FieldTame.capture_cfg()
	var base := float((c.get("tier_base", {}) as Dictionary).get(str(net_tier), 0.35))
	var lv := 1.0 - float(c.get("level_penalty_per_level", 0.006)) * float(maxi(0, level - 1))
	var ability := 1.0 + float(c.get("ability_bonus_per_tier", 0.10)) * float(maxi(0, net_tier - species_tier))
	var p := base * (1.5 - clampf(hp_fraction, 0.0, 1.0)) * maxf(0.1, lv) * ability
	return clampf(p, float(c.get("chance_min", 0.05)), float(c.get("chance_max", 0.90)))

## Returns true when the animal went into the bag.
static func attempt(player: Player, creature: Creature, force_result: int = 0) -> bool:
	if not FieldTame.capture_eligible(creature):
		if creature and creature.def and creature.health:
			print("[capture] refused: %s at %.0f%% HP, not stunned (needs a stun or under %.0f%%)" % [creature.def.id, 100.0 * creature.health.fraction(), 100.0 * float(FieldTame.capture_cfg().get("health_gate", FieldTame.CAPTURE_HEALTH_FRAC))])
		return false
	var net := player.inventory.best_capture_net()
	if net == null:
		print("[capture] no net")
		return false
	var ndef := net.def()
	if ndef.capture_tier < creature.def.capture_tier:
		print("[capture] net tier %d < species %d" % [ndef.capture_tier, creature.def.capture_tier])
		return false
	if not Data.has_capture_technique(creature.def.capture_tier):
		print("[capture] missing capture_technique_%s" % _roman(creature.def.capture_tier))
		return false
	var p := chance(ndef.capture_tier, creature.def.capture_tier, creature.health.fraction(), creature.level)
	var ok := randf() < p
	if force_result > 0:
		ok = true
	elif force_result < 0:
		ok = false
	print("[capture] %s attempt p=%.2f hp=%.0f%% stunned=%s → %s" % [creature.def.id, p, 100.0 * creature.health.fraction(), FieldTame.is_stunned(creature), "success" if ok else "fail"])
	if ok:
		var stack := ItemStack.make(&"captured_animal", 1, {
			"species": str(creature.def.id),
			"variant": str(creature.variant),
			"level": creature.level,
			"genetics": creature.genetics.to_dict(),
			"sex": str(PetRecord.roll_sex()),
		})
		var left := player.inventory.add(stack)
		if left > 0:
			print("[capture] inventory full, creature stays")
			return false
		player.inventory.consume(net.def_id, 1)
		creature.captured.emit()
		creature.queue_free()
		return true
	if creature.statuses.has(&"knockdown"):
		creature.statuses.clear_id(&"knockdown")
		if creature.anim:
			creature.anim.release_knockdown()
	creature.is_capturable = false
	creature.tame_cooldown_left = maxf(creature.tame_cooldown_left, float(FieldTame.capture_cfg().get("retry_cooldown_s", 5.0)))
	creature.statuses.apply(&"enraged", player)
	return false

static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]
