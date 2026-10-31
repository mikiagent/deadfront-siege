class_name CaptureSystem
extends RefCounted
## Knockdown window → net chance → captured_animal stack (a pen turns it into a bonded pet).

const TIER_BASE := {1: 0.35, 2: 0.45, 3: 0.55, 4: 0.65, 5: 0.75} ## ASSUMPTION: tool-tier bases.

## Chance for one throw. With a survivor (`player`) this is the taming S-curve, TamingOdds.odds_for:
## one number that the plate SHOWS and attempt() ROLLS, so the odds on screen are the odds taken.
## Without a survivor (labs, server callers holding no skills) the curve has no level gap to read, so
## the spec-09 shape (base x (1.5 - HP fraction)) on the animal's ACTUAL HP is kept; spec 09: never
## substitute the 30 % threshold for the real health.
static func chance_for(creature: Creature, net_tier: int, player = null) -> float:
	if creature == null or creature.health == null:
		return 0.0
	if player == null:
		var base := float(TIER_BASE.get(net_tier, 0.35))
		return clampf(base * (1.5 - creature.health.fraction()), 0.05, 0.90)
	return TamingOdds.odds_for(creature, player, net_tier)

## Returns true when the animal went into the bag. `rng` makes the roll repeatable (a seeded test or
## a replay); with none the global generator is used.
static func attempt(player: Player, creature: Creature, force_result: int = 0, rng: RandomNumberGenerator = null) -> bool:
	# ALPHATAG (owner 2026-10-29): an alpha is never capturable; say so instead of the stun hint.
	if FieldTame.is_alpha(creature):
		if player != null:
			player.notice(FieldTame.ALPHA_REFUSAL)
		print("[capture] refused: %s" % FieldTame.ALPHA_REFUSAL)
		return false
	# Spec 09 §1, the one rule: stunned at any HP, or HP <= 30 % (FieldTame.capture_window).
	if creature == null or not FieldTame.capture_window(creature):
		if creature != null and creature.def != null and creature.health != null and not creature.health.dead:
			print("[capture] refused: %s at %.0f%% HP and not stunned; stun it or weaken it to %.0f%%" % [creature.def.id, 100.0 * creature.health.fraction(), 100.0 * FieldTame.CAPTURE_HEALTH_FRAC])
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
	var chance := chance_for(creature, ndef.capture_tier, player)
	var ok := TamingOdds.succeeds(chance, rng)
	if force_result > 0:
		ok = true
	elif force_result < 0:
		ok = false
	print("[capture] %s attempt p=%.2f → %s" % [creature.def.id, chance, "success" if ok else "fail"])
	if ok:
		var stack := ItemStack.make(&"captured_animal", 1, {
			"species": str(creature.def.id),
			"variant": str(creature.variant),
			"level": creature.level,
			"genetics": creature.genetics.to_dict(),
			"nature": str(creature.nature_id()),  # NATURES: the netted animal keeps its nature
		})
		var left := player.inventory.add(stack)
		if left > 0:
			print("[capture] inventory full, creature stays")
			return false
		player.inventory.consume(net.def_id, 1)
		creature.captured.emit()
		Tasks.note(&"capture")  # FACTIONS: capture missions
		creature.queue_free()
		return true
	else:
		creature.statuses.clear_id(&"knockdown")
		creature.anim.release_knockdown()
		creature.is_capturable = false
		creature.statuses.apply(&"enraged", player)
	return false

static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]
