class_name CaptureSystem
extends RefCounted
## Knockdown window → net chance → captured_animal stack.

const TIER_BASE := {1: 0.35, 2: 0.45, 3: 0.55, 4: 0.65, 5: 0.75} ## ASSUMPTION: tool-tier bases.

static func attempt(player: Player, creature: Creature, force_result: int = 0) -> void:
	if creature == null or not creature.capturable():
		return
	var net := player.inventory.best_capture_net()
	if net == null:
		print("[capture] no net")
		return
	var ndef := net.def()
	if ndef.capture_tier < creature.def.capture_tier:
		print("[capture] net tier %d < species %d" % [ndef.capture_tier, creature.def.capture_tier])
		return
	if not Data.has_capture_technique(creature.def.capture_tier):
		print("[capture] missing capture_technique_%s" % _roman(creature.def.capture_tier))
		return
	var base := float(TIER_BASE.get(ndef.capture_tier, 0.35))
	var chance := clampf(base * (1.5 - creature.health.fraction()), 0.05, 0.90)
	var ok := randf() < chance
	if force_result > 0:
		ok = true
	elif force_result < 0:
		ok = false
	print("[capture] %s attempt p=%.2f → %s" % [creature.def.id, chance, "success" if ok else "fail"])
	if ok:
		var stack := ItemStack.make(&"captured_animal", 1, {
			"species": str(creature.def.id),
			"variant": str(creature.variant),
			"grade_seed": randi(),
		})
		var left := player.inventory.add(stack)
		if left > 0:
			print("[capture] inventory full, creature stays")
			return
		player.inventory.consume(net.def_id, 1)
		creature.captured.emit()
		creature.queue_free()
	else:
		creature.statuses.clear_id(&"knockdown")
		creature.anim.release_knockdown()
		creature.is_capturable = false
		creature.statuses.apply(&"enraged", player)

static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]
