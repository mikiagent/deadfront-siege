class_name CombatAvoid
## The one place an attack is decided avoided: a roll's i-frames, a dodge-chance miss, a block.
## It floats "Dodged" / "Blocked" over the defender (survivor or creature). Anything else that should
## follow an avoided hit (Defense XP from dodges/blocks, claude/mmo-slowlevels) hooks in here.

const TEXT := {&"dodge": "Dodged", &"block": "Blocked"}
const COLOR := Color(0.82, 0.82, 0.82)
const PX := 17  # under a hit's 22 px number: an avoided hit reads quieter than damage

## `how` is &"dodge" or &"block". `attacker` may be null (a projectile whose thrower is gone).
static func avoided(defender: Node, attacker: Node, how: StringName = &"dodge") -> void:
	if defender is Creature:
		(defender as Creature).combat_float.emit(0.0, how)
	elif defender is Player and defender.is_inside_tree():
		var hud := defender.get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("avoid_on_player"):
			hud.avoid_on_player(str(TEXT.get(how, "Dodged")))
	print("[combat] avoided %s by %s from %s" % [how, defender.name, attacker.name if attacker else "?"])
