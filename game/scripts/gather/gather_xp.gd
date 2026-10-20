class_name GatherXp
extends RefCounted
## The one place W2-GATHER pays skill XP, so W2-SKILLS can take it over without touching
## gather code. Contract:
##   GatherXp.sink = func(player: Player, category: String, amount: float, source: Dictionary) -> void
## source = {"verb": "gather"|"butcher", "item": String, "rare": bool, "node_level": int}.
## While sink is unset the XP goes to player.skills.add_xp(category, amount) as before.

static var sink: Callable

static func award(player: Player, category: String, amount: float, source: Dictionary) -> void:
	if player == null or amount <= 0.0:
		return
	if sink.is_valid():
		sink.call(player, category, amount, source)
	elif player.skills:
		player.skills.add_xp(category, amount)
	else:
		World.add_xp(int(amount))
