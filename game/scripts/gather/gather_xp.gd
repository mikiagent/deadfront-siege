class_name GatherXp
extends RefCounted
## The one place W2-GATHER pays its rare-result bonus XP (gather_rules.json xp): into the survivor's
## skill tree like the base +2 gathering / +3 butchering, or player XP when there is no tree.
## The old set_sink hook for W2-SKILLS is gone: W2-SKILLS kept SkillState.add_xp as the XP door.

static func award(player: Player, category: String, amount: float) -> void:
	if player == null or amount <= 0.0:
		return
	if player.skills:
		player.skills.add_xp(category, amount)
	else:
		World.add_xp(int(amount))
