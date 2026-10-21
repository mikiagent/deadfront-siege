class_name GatherXp
extends RefCounted
## The one place W2-GATHER pays skill XP, so W2-SKILLS can take it over without touching
## gather code. Contract:
##   GatherXp.set_sink(obj)   # obj has award_gather_xp(player: Player, category: String, amount: float, source: Dictionary)
##   GatherXp.set_sink(null)  # in the owner's _exit_tree
## source = {"verb": "gather"|"butcher", "item": String, "rare": bool, "node_level": int}.
## The sink is held weakly, so a freed owner drops out by itself. It is an object, not a Callable:
## a lambda left in a static var crashed Godot on quit (recursive_mutex lock failed, SIGABRT).
## While no sink is set the XP goes to player.skills.add_xp(category, amount) as before.

const SINK_METHOD := &"award_gather_xp"
static var _sink: WeakRef = null

static func set_sink(obj: Object) -> void:
	_sink = weakref(obj) if obj else null

static func award(player: Player, category: String, amount: float, source: Dictionary) -> void:
	if player == null or amount <= 0.0:
		return
	var s: Object = _sink.get_ref() if _sink else null
	if s and s.has_method(SINK_METHOD):
		s.call(SINK_METHOD, player, category, amount, source)
	elif player.skills:
		player.skills.add_xp(category, amount)
	else:
		World.add_xp(int(amount))
